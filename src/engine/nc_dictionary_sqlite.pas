unit nc_dictionary_sqlite;

interface

uses
    System.SysUtils,
    System.Math,
    System.DateUtils,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.Character,
    System.IOUtils,
    Winapi.Windows,
    nc_types,
    nc_dictionary_intf,
    nc_pinyin_parser,
    nc_sqlite;

type
    TncSqliteDictionary = class(TncDictionaryProvider)
    private
        m_base_db_path: string;
        m_user_db_path: string;
        m_ready: Boolean;
        m_base_ready: Boolean;
        m_user_ready: Boolean;
        m_limit: Integer;
        m_bigram_prune_countdown: Integer;
        m_trigram_prune_countdown: Integer;
        m_query_path_prune_countdown: Integer;
        m_query_path_penalty_prune_countdown: Integer;
        m_write_batch_depth: Integer;
        m_base_connection: TncSqliteConnection;
        m_user_connection: TncSqliteConnection;
        m_contains_popularity_cache: TDictionary<string, Integer>;
        m_prefix_popularity_cache: TDictionary<string, Integer>;
        m_pinyin_followup_popularity_cache: TDictionary<string, Integer>;
        m_base_text_prefix_bonus_cache: TDictionary<string, Integer>;
        m_single_char_weight_cache: TDictionary<string, Integer>;
        m_query_choice_bonus_cache: TDictionary<string, Integer>;
        m_query_latest_choice_text_cache: TDictionary<string, string>;
        m_stmt_context_bonus: Psqlite3_stmt;
        m_stmt_context_trigram_bonus: Psqlite3_stmt;
        m_stmt_base_query_path_bonus: Psqlite3_stmt;
        m_stmt_prefix_popularity: Psqlite3_stmt;
        m_stmt_pinyin_followup_popularity: Psqlite3_stmt;
        m_stmt_base_text_prefix_bonus: Psqlite3_stmt;
        m_stmt_single_char_exact_weight: Psqlite3_stmt;
        m_stmt_query_choice_bonus: Psqlite3_stmt;
        m_stmt_query_latest_choice_text: Psqlite3_stmt;
        m_stmt_query_path_bonus: Psqlite3_stmt;
        m_stmt_query_path_penalty: Psqlite3_stmt;
        m_stmt_candidate_penalty: Psqlite3_stmt;
        m_stmt_record_context_pair_update: Psqlite3_stmt;
        m_stmt_record_context_pair_insert: Psqlite3_stmt;
        m_stmt_record_context_trigram_update: Psqlite3_stmt;
        m_stmt_record_context_trigram_insert: Psqlite3_stmt;
        m_stmt_record_query_path_update: Psqlite3_stmt;
        m_stmt_record_query_path_insert: Psqlite3_stmt;
        m_query_path_penalty_cache: TDictionary<string, Integer>;
        m_candidate_penalty_cache: TDictionary<string, Integer>;
        m_debug_mode: Boolean;
        m_last_lookup_debug_hint: string;
        m_short_lookup_cache_prewarmed: Boolean;
        function ensure_open: Boolean;
        function get_module_dir: string;
        function find_schema_path: string;
        function load_schema_text(out schema_text: string): Boolean;
        function ensure_schema(const connection: TncSqliteConnection): Boolean;
        function get_schema_version(const connection: TncSqliteConnection; out version: Integer): Boolean;
        procedure set_schema_version(const connection: TncSqliteConnection; const version: Integer);
        function get_valid_cjk_codepoint_count(const text: string): Integer;
        function is_valid_learning_text(const text: string): Boolean;
        function is_valid_user_text(const text: string): Boolean;
        function is_valid_learning_path(const encoded_path: string): Boolean;
        function get_contains_popularity_score(const token: string): Integer;
        function get_prefix_popularity_score(const prefix: string): Integer;
        function get_pinyin_followup_popularity_score(const pinyin: string): Integer;
        procedure populate_prefix_popularity_scores(const prefixes: TArray<string>;
            const target_scores: TDictionary<string, Integer>);
        procedure populate_pinyin_followup_popularity_scores(const pinyin_keys: TArray<string>;
            const target_scores: TDictionary<string, Integer>);
        function get_single_char_exact_weight(const pinyin: string; const text_unit: string): Integer;
        function get_user_entry_count(const connection: TncSqliteConnection; out count: Integer): Boolean;
        procedure migrate_user_entries;
        function exact_base_entry_exists(const pinyin: string; const text: string): Boolean;
        function normalized_base_entry_exists(const pinyin: string; const text: string): Boolean;
        function has_any_base_phrase_for_pinyin(const pinyin: string): Boolean;
        function explicit_user_entry_exists(const pinyin: string; const text: string): Boolean;
        function split_full_pinyin_syllables(const pinyin: string): TArray<string>;
        function is_whitelisted_constructed_phrase(const pinyin: string; const text: string): Boolean;
        function is_nonbase_multi_segment_composed_exact_phrase(const pinyin: string;
            const text: string): Boolean;
        function is_suppressible_nonbase_exact_phrase(const pinyin: string; const text: string): Boolean;
        function is_likely_noisy_constructed_phrase(const pinyin: string; const text: string;
            const commit_count: Integer = 0; const user_weight: Integer = 0): Boolean;
        function should_suppress_constructed_user_phrase(const pinyin: string; const text: string;
            const commit_count: Integer = 0; const user_weight: Integer = 0): Boolean;
        procedure configure_user_connection;
        procedure purge_user_entry_internal(const pinyin: string; const text: string;
            const apply_penalty: Boolean; const purge_all_by_text: Boolean);
        procedure prune_user_entries_existing_in_base;
        procedure prune_suspicious_user_entries;
        procedure prune_bigram_rows_if_needed(const force: Boolean);
        procedure prune_trigram_rows_if_needed(const force: Boolean);
        procedure prune_query_path_rows_if_needed(const force: Boolean);
        procedure prune_query_path_penalty_rows_if_needed(const force: Boolean);
        procedure clear_cached_user_statements;
    public
        constructor create(const base_db_path: string; const user_db_path: string);
        destructor Destroy; override;
        function open: Boolean;
        procedure close;
        procedure prewarm_short_lookup_caches;
        function get_prefix_popularity_hint(const prefix: string): Integer;
        function get_base_text_prefix_bonus(const prefix_text: string): Integer; override;
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; override;
        function lookup_exact_full_pinyin(const pinyin: string;
            out results: TncCandidateList): Boolean; override;
        function lookup_full_pinyin_prefix(const pinyin_prefix: string;
            out results: TncCandidateList): Boolean; override;
        function single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean; override;
        procedure begin_learning_batch; override;
        procedure commit_learning_batch; override;
        procedure rollback_learning_batch; override;
        procedure set_debug_mode(const enabled: Boolean); override;
        procedure record_commit(const pinyin: string; const text: string); override;
        procedure record_context_pair(const left_text: string; const committed_text: string); override;
        procedure record_context_trigram(const prev_prev_text: string; const prev_text: string;
            const committed_text: string); override;
        procedure record_query_segment_path(const query_key: string; const encoded_path: string); override;
        procedure record_query_segment_path_penalty(const query_key: string; const encoded_path: string); override;
        procedure record_candidate_penalty(const pinyin: string; const text: string); override;
        function get_context_bonus(const left_text: string; const candidate_text: string): Integer; override;
        function get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
            const candidate_text: string): Integer; override;
        function get_query_choice_bonus(const query_key: string; const candidate_text: string): Integer; override;
        function get_query_latest_choice_text(const query_key: string): string; override;
        function get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer; override;
        function get_query_segment_path_penalty(const query_key: string; const encoded_path: string): Integer; override;
        function should_suppress_exact_query_learning(const pinyin: string; const text: string): Boolean; override;
        procedure remove_user_entry(const pinyin: string; const text: string); override;
        function get_candidate_penalty(const pinyin: string; const text: string): Integer; override;
        function get_last_lookup_debug_hint: string;
        property db_path: string read m_base_db_path;
        property user_db_path: string read m_user_db_path;
        property base_ready: Boolean read m_base_ready;
        property user_ready: Boolean read m_user_ready;
        property ready: Boolean read m_ready;
    end;

implementation

const
    default_schema_sql =
        'CREATE TABLE IF NOT EXISTS meta (' + sLineBreak +
        '    key TEXT PRIMARY KEY,' + sLineBreak +
        '    value TEXT NOT NULL' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'INSERT OR IGNORE INTO meta(key, value) VALUES(''schema_version'', ''10'');' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    comment TEXT DEFAULT ''''' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin ON dict_base(pinyin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_weight ON dict_base(pinyin, weight);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_text_weight ON dict_base(text, weight);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_jianpin (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    word_id INTEGER NOT NULL,' + sLineBreak +
        '    jianpin TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    UNIQUE(word_id, jianpin),' + sLineBreak +
        '    FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key ON dict_jianpin(jianpin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key_weight_word ON dict_jianpin(jianpin, weight DESC, word_id);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    UNIQUE(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_pinyin ON dict_user(pinyin);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_stats (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_stats_text ON dict_user_stats(text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_query_latest (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL PRIMARY KEY,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_latest_text ON dict_user_query_latest(text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_penalty (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    penalty INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_penalty_pinyin ON dict_user_penalty(pinyin);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_bigram (' + sLineBreak +
        '    left_text TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(left_text, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_bigram_left_text ON dict_user_bigram(left_text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_trigram (' + sLineBreak +
        '    prev_prev_text TEXT NOT NULL,' + sLineBreak +
        '    prev_text TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(prev_prev_text, prev_text, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_trigram_prev_pair ON dict_user_trigram(prev_prev_text, prev_text);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_query_path (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_query ON dict_user_query_path(query_pinyin);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_query_path_penalty (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    penalty INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_penalty_query ON dict_user_query_path_penalty(query_pinyin);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_query_path (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_query_path_query ON dict_base_query_path(query_pinyin);' +
        sLineBreak;

type
    TncMixedQueryTokenKind = (mqt_full, mqt_initial);
    TncMixedQueryToken = record
        kind: TncMixedQueryTokenKind;
        text: string;
    end;
    TncMixedQueryTokenList = array of TncMixedQueryToken;

function should_try_jianpin_lookup(const value: string): Boolean;
const
    c_jianpin_query_len_min = 2;
    c_jianpin_query_len_max = 16;
var
    i: Integer;
    ch: Char;
begin
    Result := False;
    if (Length(value) < c_jianpin_query_len_min) or (Length(value) > c_jianpin_query_len_max) then
    begin
        Exit;
    end;

    for i := 1 to Length(value) do
    begin
        ch := value[i];
        if (ch < 'a') or (ch > 'z') then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function is_initial_letter(const ch: Char): Boolean;
begin
    Result := CharInSet(ch, ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x',
        'r', 'z', 'c', 's', 'y', 'w']);
end;

function extract_syllable_initial(const syllable: string): string; forward;
function is_valid_candidate_syllable(const syllable: string): Boolean; forward;

function get_unix_time_now: Int64;
begin
    Result := DateTimeToUnix(Now, False);
end;

function build_prefix_upper_bound(const prefix: string): string;
begin
    if prefix = '' then
    begin
        Result := '';
        Exit;
    end;
    Result := prefix + WideChar($FFFF);
end;

function get_text_unit_count_local(const text: string): Integer;
var
    idx: Integer;
    codepoint: Integer;
begin
    Result := 0;
    if text = '' then
    begin
        Exit;
    end;

    idx := 1;
    while idx <= Length(text) do
    begin
        codepoint := Ord(text[idx]);
        if (codepoint >= $D800) and (codepoint <= $DBFF) and (idx < Length(text)) then
        begin
            if (Ord(text[idx + 1]) >= $DC00) and (Ord(text[idx + 1]) <= $DFFF) then
            begin
                Inc(idx);
            end;
        end;
        Inc(Result);
        Inc(idx);
    end;
end;

function copy_first_text_units(const text: string; const max_units: Integer): string;
var
    idx: Integer;
    unit_count: Integer;
    codepoint: Integer;
begin
    Result := '';
    if (text = '') or (max_units <= 0) then
    begin
        Exit;
    end;

    idx := 1;
    unit_count := 0;
    while idx <= Length(text) do
    begin
        if unit_count >= max_units then
        begin
            Break;
        end;

        codepoint := Ord(text[idx]);
        if (codepoint >= $D800) and (codepoint <= $DBFF) and (idx < Length(text)) and
            (Ord(text[idx + 1]) >= $DC00) and (Ord(text[idx + 1]) <= $DFFF) then
        begin
            Result := Result + text[idx] + text[idx + 1];
            Inc(idx, 2);
        end
        else
        begin
            Result := Result + text[idx];
            Inc(idx);
        end;

        Inc(unit_count);
    end;
end;

function calc_learning_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_freq_bonus_factor = 136.0;
    c_freq_bonus_max = 820;
    c_recent_bonus_1d = 260;
    c_recent_bonus_3d = 190;
    c_recent_bonus_7d = 135;
    c_recent_bonus_30d = 72;
    c_recent_bonus_90d = 28;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_week = 7 * c_sec_per_day;
    c_sec_per_14_days = 14 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
    c_recent_burst_bonus_1d = 88;
    c_recent_burst_bonus_3d = 52;
    c_recent_stable_bonus_7d = 46;
    c_recent_stable_bonus_30d = 28;
    c_stale_once_penalty_14d = 96;
    c_stale_once_penalty_30d = 168;
    c_stale_twice_penalty_90d = 84;
    c_stale_light_penalty_180d = 52;
var
    freq_bonus: Integer;
    recency_bonus: Integer;
    quick_bonus: Integer;
    maturity_bonus: Integer;
    age_seconds: Int64;
    stale_penalty: Integer;
begin
    if commit_count <= 0 then
    begin
        Result := 0;
        Exit;
    end;

    freq_bonus := Round(Ln(1.0 + commit_count) * c_freq_bonus_factor);
    if freq_bonus > c_freq_bonus_max then
    begin
        freq_bonus := c_freq_bonus_max;
    end;

    quick_bonus := 0;
    if commit_count >= 2 then
    begin
        quick_bonus := 120;
        if commit_count >= 3 then
        begin
            quick_bonus := 220;
        end;
        if commit_count >= 4 then
        begin
            quick_bonus := 300;
        end;
        if commit_count >= 5 then
        begin
            quick_bonus := 360 + Min(180, (commit_count - 5) * 24);
        end;
    end;

    maturity_bonus := 0;
    if commit_count >= 8 then
    begin
        maturity_bonus := 72;
        if commit_count >= 12 then
        begin
            maturity_bonus := 128;
        end;
        if commit_count >= 20 then
        begin
            maturity_bonus := 196;
        end;
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix > 0) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds < 0 then
        begin
            age_seconds := 0;
        end;

        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := c_recent_bonus_1d;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := c_recent_bonus_3d;
        end
        else if age_seconds <= c_sec_per_week then
        begin
            recency_bonus := c_recent_bonus_7d;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := c_recent_bonus_30d;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := c_recent_bonus_90d;
        end;

        if commit_count = 1 then
        begin
            recency_bonus := recency_bonus div 2;
        end
        else if commit_count >= 4 then
        begin
            Inc(recency_bonus, recency_bonus div 5);
        end;

        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(recency_bonus, c_recent_burst_bonus_1d);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(recency_bonus, c_recent_burst_bonus_3d);
            end;
        end;

        if commit_count >= 6 then
        begin
            if age_seconds <= c_sec_per_week then
            begin
                Inc(maturity_bonus, c_recent_stable_bonus_7d);
            end
            else if age_seconds <= c_sec_per_30_days then
            begin
                Inc(maturity_bonus, c_recent_stable_bonus_30d);
            end;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end
            else if age_seconds > c_sec_per_14_days then
            begin
                stale_penalty := c_stale_once_penalty_14d;
            end;
        end
        else if commit_count = 2 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_twice_penalty_90d;
            end;
        end
        else if (commit_count <= 4) and (age_seconds > c_sec_per_180_days) then
        begin
            stale_penalty := c_stale_light_penalty_180d;
        end;
    end;

    Result := freq_bonus + quick_bonus + maturity_bonus + recency_bonus;
    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;
end;

function calc_text_learning_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_text_bonus_max = 700;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
var
    age_seconds: Int64;
begin
    Result := (calc_learning_bonus(commit_count, last_used_unix, now_unix) * 2) div 3;
    if commit_count >= 2 then
    begin
        Inc(Result, 80);
    end;
    if commit_count >= 3 then
    begin
        Inc(Result, 68);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 56);
    end;
    if commit_count >= 6 then
    begin
        Inc(Result, 40);
    end;
    if (last_used_unix > 0) and (now_unix > 0) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds < 0 then
        begin
            age_seconds := 0;
        end;
        if age_seconds <= c_sec_per_day then
        begin
            Inc(Result, 54);
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            Inc(Result, 28);
        end;
        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(Result, 42);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(Result, 20);
            end;
        end;
    end;
    if Result > c_text_bonus_max then
    begin
        Result := c_text_bonus_max;
    end;
end;

function calc_context_bigram_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_bigram_bonus_cap = 620;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
    c_recent_pair_bonus_1d = 56;
    c_recent_pair_bonus_3d = 28;
    c_stale_once_penalty_30d = 88;
    c_stale_once_penalty_90d = 132;
    c_stale_twice_penalty_90d = 82;
    c_stale_light_penalty_180d = 52;
var
    recency_bonus: Integer;
    age_seconds: Int64;
    stale_penalty: Integer;
begin
    Result := 0;
    if commit_count <= 0 then
    begin
        Exit;
    end;

    Result := commit_count * 96;
    if commit_count >= 2 then
    begin
        Inc(Result, 46);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 38);
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := 90;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := 74;
        end
        else if age_seconds <= c_sec_per_7_days then
        begin
            recency_bonus := 60;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := 30;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := 14;
        end;

        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(recency_bonus, c_recent_pair_bonus_1d);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(recency_bonus, c_recent_pair_bonus_3d);
            end;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_once_penalty_90d;
            end
            else if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end;
        end
        else if (commit_count = 2) and (age_seconds > c_sec_per_90_days) then
        begin
            stale_penalty := c_stale_twice_penalty_90d;
        end
        else if (commit_count <= 4) and (age_seconds > c_sec_per_180_days) then
        begin
            stale_penalty := c_stale_light_penalty_180d;
        end;
    end;
    Inc(Result, recency_bonus);

    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;

    if Result > c_bigram_bonus_cap then
    begin
        Result := c_bigram_bonus_cap;
    end;
end;

function calc_context_trigram_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_trigram_bonus_cap = 480;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_recent_bonus_1d = 84;
    c_recent_bonus_3d = 52;
    c_stale_once_penalty_30d = 64;
    c_stale_once_penalty_90d = 96;
    c_stale_twice_penalty_90d = 58;
var
    recency_bonus: Integer;
    stale_penalty: Integer;
    age_seconds: Int64;
begin
    Result := 0;
    if commit_count <= 0 then
    begin
        Exit;
    end;

    Result := commit_count * 78;
    if commit_count >= 2 then
    begin
        Inc(Result, 40);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 30);
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := 92;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := 72;
        end
        else if age_seconds <= c_sec_per_7_days then
        begin
            recency_bonus := 48;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := 22;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := 8;
        end;

        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(recency_bonus, c_recent_bonus_1d);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(recency_bonus, c_recent_bonus_3d);
            end;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_once_penalty_90d;
            end
            else if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end;
        end
        else if (commit_count = 2) and (age_seconds > c_sec_per_90_days) then
        begin
            stale_penalty := c_stale_twice_penalty_90d;
        end;
    end;

    Inc(Result, recency_bonus);
    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;

    if Result > c_trigram_bonus_cap then
    begin
        Result := c_trigram_bonus_cap;
    end;
end;

function calc_query_segment_path_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_query_path_bonus_cap = 760;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_recent_bonus_1d = 108;
    c_recent_bonus_3d = 72;
    c_recent_bonus_7d = 44;
    c_stale_once_penalty_30d = 86;
    c_stale_once_penalty_90d = 136;
    c_stale_twice_penalty_90d = 74;
var
    recency_bonus: Integer;
    stale_penalty: Integer;
    age_seconds: Int64;
begin
    Result := 0;
    if commit_count <= 0 then
    begin
        Exit;
    end;

    Result := commit_count * 112;
    if commit_count >= 2 then
    begin
        Inc(Result, 64);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 44);
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := c_recent_bonus_1d;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := c_recent_bonus_3d;
        end
        else if age_seconds <= c_sec_per_7_days then
        begin
            recency_bonus := c_recent_bonus_7d;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := 18;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := 6;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_once_penalty_90d;
            end
            else if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end;
        end
        else if (commit_count = 2) and (age_seconds > c_sec_per_90_days) then
        begin
            stale_penalty := c_stale_twice_penalty_90d;
        end;
    end;

    Inc(Result, recency_bonus);
    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;

    if Result > c_query_path_bonus_cap then
    begin
        Result := c_query_path_bonus_cap;
    end;
end;

function calc_base_query_segment_path_bonus(const weight: Integer): Integer;
const
    c_base_query_path_bonus_cap = 420;
begin
    Result := 0;
    if weight <= 0 then
    begin
        Exit;
    end;

    Result := (weight * 3) div 5;
    if weight >= 420 then
    begin
        Inc(Result, 28);
    end;
    if weight >= 620 then
    begin
        Inc(Result, 42);
    end;
    if weight >= 820 then
    begin
        Inc(Result, 54);
    end;

    if Result > c_base_query_path_bonus_cap then
    begin
        Result := c_base_query_path_bonus_cap;
    end;
end;

function calc_query_segment_path_penalty_value(const penalty_value: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
var
    age_seconds: Int64;
begin
    Result := penalty_value;
    if Result <= 0 then
    begin
        Exit(0);
    end;

    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds > c_sec_per_180_days then
        begin
            Result := (Result * 20) div 100;
        end
        else if age_seconds > c_sec_per_90_days then
        begin
            Result := (Result * 40) div 100;
        end
        else if age_seconds > c_sec_per_30_days then
        begin
            Result := (Result * 65) div 100;
        end
        else if age_seconds > c_sec_per_7_days then
        begin
            Result := (Result * 85) div 100;
        end;
    end;

    if Result < 0 then
    begin
        Result := 0;
    end;
end;

function calc_candidate_penalty_value(const penalty_value: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
var
    age_seconds: Int64;
begin
    Result := penalty_value;
    if Result <= 0 then
    begin
        Exit(0);
    end;

    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds > c_sec_per_180_days then
        begin
            Result := (Result * 20) div 100;
        end
        else if age_seconds > c_sec_per_90_days then
        begin
            Result := (Result * 40) div 100;
        end
        else if age_seconds > c_sec_per_30_days then
        begin
            Result := (Result * 65) div 100;
        end
        else if age_seconds > c_sec_per_7_days then
        begin
            Result := (Result * 85) div 100;
        end;
    end;

    if Result < 0 then
    begin
        Result := 0;
    end;
end;

function get_encoded_path_segment_count(const encoded_path: string): Integer;
var
    idx: Integer;
    normalized_path: string;
const
    c_segment_path_separator = #3;
begin
    normalized_path := Trim(encoded_path);
    if normalized_path = '' then
    begin
        Exit(0);
    end;

    Result := 1;
    for idx := 1 to Length(normalized_path) do
    begin
        if normalized_path[idx] = c_segment_path_separator then
        begin
            Inc(Result);
        end;
    end;
end;

function split_text_units_local(const input_text: string): TArray<string>;
var
    idx: Integer;
    unit_text: string;
begin
    SetLength(Result, 0);
    idx := 1;
    while idx <= Length(input_text) do
    begin
        if (Ord(input_text[idx]) >= $D800) and (Ord(input_text[idx]) <= $DBFF) and
            (idx < Length(input_text)) and
            (Ord(input_text[idx + 1]) >= $DC00) and (Ord(input_text[idx + 1]) <= $DFFF) then
        begin
            unit_text := input_text[idx] + input_text[idx + 1];
            Inc(idx, 2);
        end
        else
        begin
            unit_text := input_text[idx];
            Inc(idx);
        end;

        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := unit_text;
    end;
end;

function build_context_variants_local(const context_text: string): TArray<string>;
var
    context_units: TArray<string>;
    seen: TDictionary<string, Boolean>;
    variant_text: string;
    idx: Integer;
    start_idx: Integer;
    min_start_idx: Integer;
begin
    SetLength(Result, 0);
    variant_text := Trim(context_text);
    if variant_text = '' then
    begin
        Exit;
    end;

    seen := TDictionary<string, Boolean>.Create;
    try
        SetLength(Result, 1);
        Result[0] := variant_text;
        seen.Add(variant_text, True);

        context_units := split_text_units_local(variant_text);
        if Length(context_units) <= 1 then
        begin
            Exit;
        end;

        min_start_idx := Max(0, Length(context_units) - 4);
        for start_idx := min_start_idx to Length(context_units) - 1 do
        begin
            variant_text := '';
            for idx := start_idx to High(context_units) do
            begin
                variant_text := variant_text + context_units[idx];
            end;
            variant_text := Trim(variant_text);
            if (variant_text = '') or seen.ContainsKey(variant_text) then
            begin
                Continue;
            end;
            seen.Add(variant_text, True);
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := variant_text;
        end;
    finally
        seen.Free;
    end;
end;

function parse_mixed_jianpin_query(const query_key: string; out full_prefix: string; out jianpin_key: string;
    out tokens: TncMixedQueryTokenList): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    has_full: Boolean;
    has_initial: Boolean;
    reconstructed: string;
    initial_value: string;
    syllable_text: string;
    prefix_closed: Boolean;
begin
    Result := False;
    full_prefix := '';
    jianpin_key := '';
    SetLength(tokens, 0);
    if query_key = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(query_key);
    finally
        parser.Free;
    end;

    if Length(syllables) < 2 then
    begin
        Exit;
    end;

    SetLength(tokens, Length(syllables));
    reconstructed := '';
    has_full := False;
    has_initial := False;
    prefix_closed := False;
    for idx := 0 to High(syllables) do
    begin
        syllable_text := syllables[idx].text;
        reconstructed := reconstructed + syllable_text;

        if is_valid_candidate_syllable(syllable_text) then
        begin
            tokens[idx].kind := mqt_full;
            tokens[idx].text := syllable_text;
            has_full := True;
            if not prefix_closed then
            begin
                full_prefix := full_prefix + syllable_text;
            end;
            Continue;
        end;

        if (Length(syllable_text) = 1) and is_initial_letter(syllable_text[1]) then
        begin
            tokens[idx].kind := mqt_initial;
            tokens[idx].text := syllable_text;
            has_initial := True;
            prefix_closed := True;
            Continue;
        end;

        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    if not SameText(reconstructed, query_key) then
    begin
        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    // Mixed mode requires at least one full syllable and at least one initial.
    if (not has_full) or (not has_initial) then
    begin
        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    jianpin_key := '';
    for idx := 0 to High(tokens) do
    begin
        if tokens[idx].kind = mqt_full then
        begin
            initial_value := extract_syllable_initial(tokens[idx].text);
            if initial_value <> '' then
            begin
                jianpin_key := jianpin_key + initial_value[1];
            end
            else
            begin
                jianpin_key := jianpin_key + tokens[idx].text[1];
            end;
        end
        else
        begin
            jianpin_key := jianpin_key + tokens[idx].text[1];
        end;
    end;

    if jianpin_key = '' then
    begin
        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    Result := True;
end;

function extract_syllable_initial(const syllable: string): string;
var
    head2: string;
    head1: Char;
begin
    Result := '';
    if syllable = '' then
    begin
        Exit;
    end;

    if Length(syllable) >= 2 then
    begin
        head2 := Copy(syllable, 1, 2);
        if (head2 = 'zh') or (head2 = 'ch') or (head2 = 'sh') then
        begin
            Result := head2;
            Exit;
        end;
    end;

    head1 := syllable[1];
    if CharInSet(head1, ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x',
        'r', 'z', 'c', 's', 'y', 'w']) then
    begin
        Result := head1;
    end;
end;

function is_valid_candidate_syllable(const syllable: string): Boolean;
var
    ch: Char;
begin
    Result := False;
    if syllable = '' then
    begin
        Exit;
    end;

    // Single-letter syllables are only valid for standalone finals.
    if Length(syllable) = 1 then
    begin
        Result := CharInSet(syllable[1], ['a', 'e', 'o']);
        Exit;
    end;

    for ch in syllable do
    begin
        if CharInSet(ch, ['a', 'e', 'i', 'o', 'u', 'v']) then
        begin
            Result := True;
            Exit;
        end;
    end;
end;

function is_full_pinyin_key(const value: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    reconstructed: string;
begin
    Result := False;
    if value = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(value);
    finally
        parser.Free;
    end;

    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    reconstructed := '';
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
    end;

    Result := SameText(reconstructed, value);
end;

function normalize_compact_pinyin_key(const value: string): string;
var
    i: Integer;
    ch: Char;
begin
    Result := '';
    for i := 1 to Length(value) do
    begin
        ch := value[i];
        if CharInSet(ch, ['A' .. 'Z']) then
        begin
            ch := Chr(Ord(ch) + 32);
        end;
        if CharInSet(ch, ['a' .. 'z']) then
        begin
            Result := Result + ch;
        end;
    end;
end;

function same_normalized_pinyin_key(const left_value: string; const right_value: string): Boolean;
begin
    Result := SameText(normalize_compact_pinyin_key(left_value), normalize_compact_pinyin_key(right_value));
end;

function build_jianpin_key_from_full_pinyin(const value: string): string;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
    reconstructed: string;
begin
    Result := '';
    if value = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(value);
    finally
        parser.Free;
    end;

    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    reconstructed := '';
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Result := '';
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
        initial_value := extract_syllable_initial(syllables[idx].text);
        if initial_value <> '' then
        begin
            // Keep jianpin key shape aligned with dict_jianpin schema:
            // one letter per syllable (zh/ch/sh collapse to z/c/s).
            Result := Result + initial_value[1];
        end
        else if syllables[idx].text <> '' then
        begin
            Result := Result + syllables[idx].text[1];
        end;
    end;

    if not SameText(reconstructed, value) then
    begin
        Result := '';
    end;
end;

function is_single_syllable_full_pinyin_key(const value: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
begin
    Result := False;
    if value = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(value);
    finally
        parser.Free;
    end;

    if Length(syllables) <> 1 then
    begin
        Exit;
    end;

    if not is_valid_candidate_syllable(syllables[0].text) then
    begin
        Exit;
    end;

    Result := SameText(syllables[0].text, value);
end;

function mixed_initial_matches(const query_initial: Char; const syllable_initial: string): Boolean;
begin
    if syllable_initial = '' then
    begin
        Result := False;
        Exit;
    end;

    case query_initial of
        'z':
            Result := (syllable_initial = 'z') or (syllable_initial = 'zh');
        'c':
            Result := (syllable_initial = 'c') or (syllable_initial = 'ch');
        's':
            Result := (syllable_initial = 's') or (syllable_initial = 'sh');
    else
        Result := syllable_initial = query_initial;
    end;
end;

function candidate_matches_mixed_jianpin(const parser: TncPinyinParser; const candidate_pinyin: string;
    const query_tokens: TncMixedQueryTokenList): Boolean;
var
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (Length(query_tokens) = 0) then
    begin
        Exit;
    end;

    syllables := parser.parse(candidate_pinyin);
    if Length(syllables) <> Length(query_tokens) then
    begin
        Exit;
    end;

    for idx := 0 to High(query_tokens) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;

        if query_tokens[idx].kind = mqt_full then
        begin
            if not SameText(syllables[idx].text, query_tokens[idx].text) then
            begin
                Exit;
            end;
            Continue;
        end;

        if query_tokens[idx].text = '' then
        begin
            Exit;
        end;

        initial_value := extract_syllable_initial(syllables[idx].text);
        if (initial_value = '') and (syllables[idx].text <> '') then
        begin
            initial_value := LowerCase(Copy(syllables[idx].text, 1, 1));
        end;
        if not mixed_initial_matches(query_tokens[idx].text[1], initial_value) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function candidate_matches_jianpin_key(const parser: TncPinyinParser; const candidate_pinyin: string;
    const query_jianpin_key: string): Boolean;
var
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
    candidate_key: string;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (query_jianpin_key = '') then
    begin
        Exit;
    end;

    syllables := parser.parse(candidate_pinyin);
    if Length(syllables) <> Length(query_jianpin_key) then
    begin
        Exit;
    end;

    candidate_key := '';
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;

        initial_value := extract_syllable_initial(syllables[idx].text);
        if (initial_value = '') and (syllables[idx].text <> '') then
        begin
            initial_value := LowerCase(Copy(syllables[idx].text, 1, 1));
        end;
        if initial_value = '' then
        begin
            Exit;
        end;

        candidate_key := candidate_key + initial_value[1];
    end;

    Result := SameText(candidate_key, query_jianpin_key);
end;

function candidate_matches_any_jianpin_key(const parser: TncPinyinParser; const candidate_pinyin: string;
    const query_jianpin_keys: TArray<string>): Boolean;
var
    idx: Integer;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (Length(query_jianpin_keys) = 0) then
    begin
        Exit;
    end;

    for idx := 0 to High(query_jianpin_keys) do
    begin
        if (query_jianpin_keys[idx] <> '') and
            candidate_matches_jianpin_key(parser, candidate_pinyin, query_jianpin_keys[idx]) then
        begin
            Result := True;
            Exit;
        end;
    end;
end;

function build_jianpin_query_variants(const value: string): TArray<string>;
var
    list: TList<string>;
    seen: TDictionary<string, Boolean>;
    normalized_value: string;
    i: Integer;

    procedure add_variant(const variant_value: string);
    begin
        if variant_value = '' then
        begin
            Exit;
        end;
        if seen.ContainsKey(variant_value) then
        begin
            Exit;
        end;

        seen.Add(variant_value, True);
        list.Add(variant_value);
    end;

    procedure expand_variants(const rest_value: string; const prefix_value: string);
    var
        pair_value: string;
    begin
        if rest_value = '' then
        begin
            add_variant(prefix_value);
            Exit;
        end;

        if Length(rest_value) >= 2 then
        begin
            pair_value := Copy(rest_value, 1, 2);
            if (pair_value = 'zh') or (pair_value = 'ch') or (pair_value = 'sh') then
            begin
                // Keep both interpretations:
                // - pair as two initials (z+h / c+h / s+h)
                // - pair collapsed as one retroflex initial (zh/ch/sh -> z/c/s)
                expand_variants(Copy(rest_value, 3, MaxInt), prefix_value + pair_value);
                expand_variants(Copy(rest_value, 3, MaxInt), prefix_value + pair_value[1]);
                Exit;
            end;
        end;

        expand_variants(Copy(rest_value, 2, MaxInt), prefix_value + rest_value[1]);
    end;
begin
    SetLength(Result, 0);
    if value = '' then
    begin
        Exit;
    end;

    normalized_value := LowerCase(value);
    list := TList<string>.Create;
    seen := TDictionary<string, Boolean>.Create;
    try
        expand_variants(normalized_value, '');
        if list.Count = 0 then
        begin
            add_variant(normalized_value);
        end;

        SetLength(Result, list.Count);
        for i := 0 to list.Count - 1 do
        begin
            Result[i] := list[i];
        end;
    finally
        seen.Free;
        list.Free;
    end;
end;

function count_retroflex_pairs_in_compact_key(const value: string): Integer;
var
    idx: Integer;
    pair_value: string;
begin
    Result := 0;
    idx := 1;
    while idx < Length(value) do
    begin
        pair_value := Copy(value, idx, 2);
        if (pair_value = 'zh') or (pair_value = 'ch') or (pair_value = 'sh') then
        begin
            Inc(Result);
            Inc(idx, 2);
        end
        else
        begin
            Inc(idx);
        end;
    end;
end;

function collapse_retroflex_pairs_in_compact_key(const value: string): string;
var
    idx: Integer;
    pair_value: string;
begin
    Result := '';
    idx := 1;
    while idx <= Length(value) do
    begin
        if idx < Length(value) then
        begin
            pair_value := Copy(value, idx, 2);
            if (pair_value = 'zh') or (pair_value = 'ch') or (pair_value = 'sh') then
            begin
                Result := Result + pair_value[1];
                Inc(idx, 2);
                Continue;
            end;
        end;

        Result := Result + value[idx];
        Inc(idx);
    end;
end;

function is_retroflex_collapsed_fallback_key(const original_key: string; const variant_key: string): Boolean;
var
    collapsed_key: string;
begin
    Result := False;
    if (original_key = '') or (variant_key = '') then
    begin
        Exit;
    end;

    collapsed_key := collapse_retroflex_pairs_in_compact_key(original_key);
    Result := (collapsed_key <> '') and (not SameText(collapsed_key, original_key)) and SameText(collapsed_key, variant_key);
end;

function is_bare_retroflex_pair_key(const value: string): Boolean;
begin
    Result := (Length(value) = 2) and CharInSet(value[1], ['z', 'c', 's']) and (value[2] = 'h');
end;

constructor TncSqliteDictionary.create(const base_db_path: string; const user_db_path: string);
begin
    inherited create;
    m_base_db_path := base_db_path;
    m_user_db_path := user_db_path;
    m_ready := False;
    m_base_ready := False;
    m_user_ready := False;
    m_limit := 256;
    m_bigram_prune_countdown := 64;
    m_trigram_prune_countdown := 64;
    m_query_path_prune_countdown := 64;
    m_query_path_penalty_prune_countdown := 64;
    m_write_batch_depth := 0;
    m_stmt_context_bonus := nil;
    m_stmt_context_trigram_bonus := nil;
    m_stmt_base_query_path_bonus := nil;
    m_stmt_prefix_popularity := nil;
    m_stmt_pinyin_followup_popularity := nil;
    m_stmt_base_text_prefix_bonus := nil;
    m_stmt_single_char_exact_weight := nil;
    m_stmt_query_choice_bonus := nil;
    m_stmt_query_latest_choice_text := nil;
    m_stmt_query_path_bonus := nil;
    m_stmt_query_path_penalty := nil;
    m_stmt_candidate_penalty := nil;
    m_stmt_record_context_pair_update := nil;
    m_stmt_record_context_pair_insert := nil;
    m_stmt_record_context_trigram_update := nil;
    m_stmt_record_context_trigram_insert := nil;
    m_stmt_record_query_path_update := nil;
    m_stmt_record_query_path_insert := nil;
    m_base_connection := nil;
    m_user_connection := nil;
    m_contains_popularity_cache := TDictionary<string, Integer>.Create;
    m_prefix_popularity_cache := TDictionary<string, Integer>.Create;
    m_pinyin_followup_popularity_cache := TDictionary<string, Integer>.Create;
    m_base_text_prefix_bonus_cache := TDictionary<string, Integer>.Create;
    m_single_char_weight_cache := TDictionary<string, Integer>.Create;
    m_query_choice_bonus_cache := TDictionary<string, Integer>.Create;
    m_query_latest_choice_text_cache := TDictionary<string, string>.Create;
    m_query_path_penalty_cache := TDictionary<string, Integer>.Create;
    m_candidate_penalty_cache := TDictionary<string, Integer>.Create;
    m_debug_mode := False;
    m_last_lookup_debug_hint := '';
    m_short_lookup_cache_prewarmed := False;
end;

destructor TncSqliteDictionary.Destroy;
begin
    close;
    if m_base_connection <> nil then
    begin
        m_base_connection.Free;
        m_base_connection := nil;
    end;
    if m_user_connection <> nil then
    begin
        m_user_connection.Free;
        m_user_connection := nil;
    end;
    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.Free;
        m_contains_popularity_cache := nil;
    end;
    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.Free;
        m_prefix_popularity_cache := nil;
    end;
    if m_pinyin_followup_popularity_cache <> nil then
    begin
        m_pinyin_followup_popularity_cache.Free;
        m_pinyin_followup_popularity_cache := nil;
    end;
    if m_base_text_prefix_bonus_cache <> nil then
    begin
        m_base_text_prefix_bonus_cache.Free;
        m_base_text_prefix_bonus_cache := nil;
    end;
    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.Free;
        m_single_char_weight_cache := nil;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Free;
        m_query_choice_bonus_cache := nil;
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Free;
        m_query_latest_choice_text_cache := nil;
    end;
    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Free;
        m_candidate_penalty_cache := nil;
    end;
    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Free;
        m_query_path_penalty_cache := nil;
    end;

    inherited Destroy;
end;

function TncSqliteDictionary.get_last_lookup_debug_hint: string;
begin
    Result := m_last_lookup_debug_hint;
end;

function TncSqliteDictionary.get_prefix_popularity_hint(const prefix: string): Integer;
begin
    Result := get_prefix_popularity_score(Trim(prefix));
end;

function TncSqliteDictionary.get_base_text_prefix_bonus(const prefix_text: string): Integer;
var
    normalized_prefix: string;
    prefix_score: Integer;
    contains_score: Integer;
begin
    Result := 0;
    normalized_prefix := Trim(prefix_text);
    if (normalized_prefix = '') or (Length(normalized_prefix) < 2) or
        (Length(normalized_prefix) > 6) or (not ensure_open) or
        (not m_base_ready) then
    begin
        Exit;
    end;

    prefix_score := get_prefix_popularity_score(normalized_prefix);
    contains_score := get_contains_popularity_score(normalized_prefix);
    Result := Min(6400, (prefix_score div 16) + (contains_score div 32));
end;

function TncSqliteDictionary.lookup_full_pinyin_prefix(const pinyin_prefix: string;
    out results: TncCandidateList): Boolean;
const
    base_prefix_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY pinyin ASC, weight DESC, text ASC LIMIT ?3';
    user_prefix_sql =
        'SELECT pinyin, text, weight, last_used FROM dict_user ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?3';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    item: TncCandidate;
    limit_value: Integer;
    normalized_prefix: string;
    upper_bound: string;
    seen: TDictionary<string, Boolean>;
    candidate_pinyin: string;
    candidate_text: string;
    candidate_comment: string;
    seen_key: string;
begin
    SetLength(results, 0);
    Result := False;
    if pinyin_prefix = '' then
    begin
        Exit;
    end;
    if not ensure_open or (not m_base_ready) then
    begin
        Exit;
    end;

    normalized_prefix := LowerCase(Trim(pinyin_prefix));
    if normalized_prefix = '' then
    begin
        Exit;
    end;

    if Length(normalized_prefix) >= 12 then
    begin
        limit_value := 16;
    end
    else if Length(normalized_prefix) >= 8 then
    begin
        limit_value := 24;
    end
    else
    begin
        limit_value := Max(m_limit * 2, 16);
        if limit_value > 48 then
        begin
            limit_value := 48;
        end;
    end;

    upper_bound := build_prefix_upper_bound(normalized_prefix);
    if upper_bound = '' then
    begin
        Exit;
    end;

    stmt := nil;
    seen := TDictionary<string, Boolean>.Create;
    try
        try
            if not m_base_connection.prepare(base_prefix_sql, stmt) or
                (not m_base_connection.bind_text(stmt, 1, normalized_prefix)) or
                (not m_base_connection.bind_text(stmt, 2, upper_bound)) or
                (not m_base_connection.bind_int(stmt, 3, limit_value)) then
            begin
                Exit;
            end;

            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                candidate_text := m_base_connection.column_text(stmt, 1);
                candidate_comment := m_base_connection.column_text(stmt, 2);
                seen_key := candidate_pinyin + #0 + candidate_text + #0 + candidate_comment;
                if seen.ContainsKey(seen_key) then
                begin
                    step_result := m_base_connection.step(stmt);
                    Continue;
                end;
                seen.Add(seen_key, True);
                item.text := candidate_text;
                item.comment := candidate_comment;
                item.dict_weight := m_base_connection.column_int(stmt, 3);
                item.score := item.dict_weight;
                item.source := cs_rule;
                item.has_dict_weight := True;
                SetLength(results, Length(results) + 1);
                results[High(results)] := item;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
            stmt := nil;
        end;

        if m_user_ready then
        begin
            try
                if m_user_connection.prepare(user_prefix_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, normalized_prefix) and
                    m_user_connection.bind_text(stmt, 2, upper_bound) and
                    m_user_connection.bind_int(stmt, 3, limit_value) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_user_connection.column_text(stmt, 0);
                        candidate_text := m_user_connection.column_text(stmt, 1);
                        seen_key := candidate_pinyin + #0 + candidate_text + #0;
                        if seen.ContainsKey(seen_key) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        seen.Add(seen_key, True);
                        item.text := candidate_text;
                        item.comment := '';
                        item.dict_weight := m_user_connection.column_int(stmt, 2);
                        item.score := item.dict_weight;
                        item.source := cs_user;
                        item.has_dict_weight := False;
                        SetLength(results, Length(results) + 1);
                        results[High(results)] := item;
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;
    finally
        seen.Free;
    end;

    Result := Length(results) > 0;
end;

procedure TncSqliteDictionary.set_debug_mode(const enabled: Boolean);
begin
    m_debug_mode := enabled;
    if not m_debug_mode then
    begin
        m_last_lookup_debug_hint := '';
    end;
end;

function TncSqliteDictionary.ensure_open: Boolean;
begin
    if m_ready then
    begin
        if ((m_base_db_path = '') or m_base_ready) and ((m_user_db_path = '') or m_user_ready) then
        begin
            Result := True;
            Exit;
        end;
    end;

    Result := open;
end;

procedure TncSqliteDictionary.configure_user_connection;
begin
    if m_user_connection = nil then
    begin
        Exit;
    end;

    m_user_connection.exec('PRAGMA journal_mode=WAL;');
    m_user_connection.exec('PRAGMA synchronous=NORMAL;');
    m_user_connection.exec('PRAGMA temp_store=MEMORY;');
    m_user_connection.exec('PRAGMA busy_timeout=1000;');
end;

procedure TncSqliteDictionary.begin_learning_batch;
begin
    if (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    if m_write_batch_depth = 0 then
    begin
        if not m_user_connection.exec('BEGIN IMMEDIATE TRANSACTION;') then
        begin
            Exit;
        end;
    end;
    Inc(m_write_batch_depth);
end;

procedure TncSqliteDictionary.commit_learning_batch;
begin
    if m_write_batch_depth <= 0 then
    begin
        Exit;
    end;

    Dec(m_write_batch_depth);
    if m_write_batch_depth = 0 then
    begin
        if not m_user_connection.exec('COMMIT;') then
        begin
            m_user_connection.exec('ROLLBACK;');
        end;
    end;
end;

procedure TncSqliteDictionary.rollback_learning_batch;
begin
    if m_write_batch_depth <= 0 then
    begin
        Exit;
    end;

    m_write_batch_depth := 0;
    if m_user_connection <> nil then
    begin
        m_user_connection.exec('ROLLBACK;');
    end;
end;

function TncSqliteDictionary.get_module_dir: string;
var
    buffer: array[0..MAX_PATH] of Char;
    len: Cardinal;
begin
    Result := '';
    len := GetModuleFileName(HInstance, buffer, MAX_PATH);
    if len > 0 then
    begin
        Result := ExtractFilePath(buffer);
    end;
end;

function TncSqliteDictionary.find_schema_path: string;
var
    base_dir: string;
    candidate: string;
begin
    Result := '';
    base_dir := get_module_dir;

    if base_dir <> '' then
    begin
        candidate := IncludeTrailingPathDelimiter(base_dir) + 'schema.sql';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;

        candidate := IncludeTrailingPathDelimiter(base_dir) + 'data\\schema.sql';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;

        candidate := ExpandFileName(IncludeTrailingPathDelimiter(base_dir) + '..\\data\\schema.sql');
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;
    end;

    candidate := ExpandFileName('data\\schema.sql');
    if FileExists(candidate) then
    begin
        Result := candidate;
    end;
end;

function TncSqliteDictionary.load_schema_text(out schema_text: string): Boolean;
var
    schema_path: string;
begin
    schema_text := '';
    schema_path := find_schema_path;
    if schema_path = '' then
    begin
        Result := False;
        Exit;
    end;

    schema_text := TFile.ReadAllText(schema_path, TEncoding.ASCII);
    Result := schema_text <> '';
end;

function TncSqliteDictionary.ensure_schema(const connection: TncSqliteConnection): Boolean;
var
    schema_text: string;
    schema_version: Integer;
begin
    if connection = nil then
    begin
        Result := False;
        Exit;
    end;

    if not load_schema_text(schema_text) then
    begin
        schema_text := default_schema_sql;
    end;

    if not connection.exec(schema_text) then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_jianpin (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        'word_id INTEGER NOT NULL,' +
        'jianpin TEXT NOT NULL,' +
        'weight INTEGER DEFAULT 0,' +
        'UNIQUE(word_id, jianpin),' +
        'FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key ON dict_jianpin(jianpin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_weight ON dict_base(pinyin, weight);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_base_text_weight ON dict_base(text, weight);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key_weight_word ' +
        'ON dict_jianpin(jianpin, weight DESC, word_id);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_stats (' +
        'pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_stats_text ON dict_user_stats(text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_query_latest (' +
        'query_pinyin TEXT NOT NULL PRIMARY KEY,' +
        'text TEXT NOT NULL,' +
        'last_used INTEGER DEFAULT 0' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_latest_text ON dict_user_query_latest(text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_penalty (' +
        'pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'penalty INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_penalty_pinyin ON dict_user_penalty(pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_bigram (' +
        'left_text TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(left_text, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_bigram_left_text ON dict_user_bigram(left_text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_trigram (' +
        'prev_prev_text TEXT NOT NULL,' +
        'prev_text TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(prev_prev_text, prev_text, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_trigram_prev_pair ON dict_user_trigram(prev_prev_text, prev_text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_query_path (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_query ON dict_user_query_path(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_query_path_penalty (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'penalty INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_penalty_query ' +
        'ON dict_user_query_path_penalty(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_query_path (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'weight INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_query_path_query ' +
        'ON dict_base_query_path(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not get_schema_version(connection, schema_version) then
    begin
        set_schema_version(connection, 10);
        Result := True;
        Exit;
    end;

    if schema_version < 1 then
    begin
        set_schema_version(connection, 1);
    end;

    if schema_version < 2 then
    begin
        set_schema_version(connection, 2);
    end;

    if schema_version < 3 then
    begin
        set_schema_version(connection, 3);
    end;

    if schema_version < 4 then
    begin
        set_schema_version(connection, 4);
    end;

    if schema_version < 5 then
    begin
        set_schema_version(connection, 5);
    end;

    if schema_version < 6 then
    begin
        set_schema_version(connection, 6);
    end;

    if schema_version < 7 then
    begin
        set_schema_version(connection, 7);
    end;

    if schema_version < 8 then
    begin
        set_schema_version(connection, 8);
    end;

    if schema_version < 9 then
    begin
        set_schema_version(connection, 9);
    end;

    if schema_version < 10 then
    begin
        set_schema_version(connection, 10);
    end;

    Result := True;
end;

function TncSqliteDictionary.get_schema_version(const connection: TncSqliteConnection; out version: Integer): Boolean;
const
    sql_text = 'SELECT value FROM meta WHERE key = ''schema_version'' LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    value_text: string;
begin
    version := 0;
    if (connection = nil) or not connection.opened then
    begin
        Result := False;
        Exit;
    end;

    stmt := nil;
    try
        if not connection.prepare(sql_text, stmt) then
        begin
            Result := False;
            Exit;
        end;

        step_result := connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            value_text := connection.column_text(stmt, 0);
            version := StrToIntDef(value_text, 0);
            Result := True;
            Exit;
        end;
    finally
        if stmt <> nil then
        begin
            connection.finalize(stmt);
        end;
    end;

    Result := False;
end;

procedure TncSqliteDictionary.set_schema_version(const connection: TncSqliteConnection; const version: Integer);
const
    sql_text = 'INSERT OR REPLACE INTO meta(key, value) VALUES(''schema_version'', ?1)';
var
    stmt: Psqlite3_stmt;
begin
    if (connection = nil) or not connection.opened then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not connection.prepare(sql_text, stmt) then
        begin
            Exit;
        end;

        if connection.bind_text(stmt, 1, IntToStr(version)) then
        begin
            connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.get_valid_cjk_codepoint_count(const text: string): Integer;
var
    idx: Integer;
    codepoint_count: Integer;
    codepoint: Integer;
    high_surrogate: Integer;
    low_surrogate: Integer;

    function is_cjk_codepoint(const value: Integer): Boolean;
    begin
        Result :=
            ((value >= $4E00) and (value <= $9FFF)) or
            ((value >= $3400) and (value <= $4DBF)) or
            ((value >= $F900) and (value <= $FAFF)) or
            ((value >= $2F800) and (value <= $2FA1F)) or
            ((value >= $20000) and (value <= $2A6DF)) or
            ((value >= $2A700) and (value <= $2B73F)) or
            ((value >= $2B740) and (value <= $2B81F)) or
            ((value >= $2B820) and (value <= $2CEAF)) or
            ((value >= $2CEB0) and (value <= $2EBEF)) or
            ((value >= $30000) and (value <= $3134F));
    end;
begin
    Result := -1;
    if text = '' then
    begin
        Exit;
    end;

    if Pos('`', text) > 0 then
    begin
        Exit;
    end;

    idx := 1;
    codepoint_count := 0;
    while idx <= Length(text) do
    begin
        codepoint := Ord(text[idx]);
        if (codepoint >= $D800) and (codepoint <= $DBFF) then
        begin
            if idx >= Length(text) then
            begin
                Exit;
            end;

            high_surrogate := codepoint;
            low_surrogate := Ord(text[idx + 1]);
            if (low_surrogate < $DC00) or (low_surrogate > $DFFF) then
            begin
                Exit;
            end;

            codepoint := ((high_surrogate - $D800) shl 10) + (low_surrogate - $DC00) + $10000;
            Inc(idx);
        end;

        if not is_cjk_codepoint(codepoint) then
        begin
            Exit;
        end;

        Inc(codepoint_count);
        Inc(idx);
    end;

    Result := codepoint_count;
end;

function is_windows_supported_ime_text(const text: string): Boolean;
var
    idx: Integer;
    codepoint: Integer;
begin
    Result := False;
    if text = '' then
    begin
        Exit;
    end;

    idx := 1;
    while idx <= Length(text) do
    begin
        codepoint := Ord(text[idx]);
        // Reject supplementary-plane characters (surrogate pairs). A subset of
        // these Unihan codepoints still cannot be reliably committed/rendered
        // in common Windows text controls.
        if (codepoint >= $D800) and (codepoint <= $DFFF) then
        begin
            Exit;
        end;

        if not (
            ((codepoint >= $4E00) and (codepoint <= $9FFF)) or
            ((codepoint >= $3400) and (codepoint <= $4DBF)) or
            ((codepoint >= $F900) and (codepoint <= $FAFF))
            ) then
        begin
            Exit;
        end;

        Inc(idx);
    end;

    Result := True;
end;

function TncSqliteDictionary.is_valid_learning_text(const text: string): Boolean;
const
    c_learning_text_max_codepoints = 10;
var
    codepoint_count: Integer;
begin
    // Persistent learning should stay on pure CJK text and avoid sentence-like
    // long tails. Longer committed phrases still participate in immediate
    // session behavior, but should not be written into the user DB.
    codepoint_count := get_valid_cjk_codepoint_count(text);
    Result := (codepoint_count >= 1) and (codepoint_count <= c_learning_text_max_codepoints);
end;

function TncSqliteDictionary.is_valid_user_text(const text: string): Boolean;
var
    codepoint_count: Integer;
begin
    codepoint_count := get_valid_cjk_codepoint_count(text);
    // User dictionary should store phrase learning only, not single-character commits.
    Result := (codepoint_count >= 2) and (codepoint_count <= 10);
end;

function TncSqliteDictionary.is_valid_learning_path(const encoded_path: string): Boolean;
const
    c_learning_path_separator = #3;
var
    idx: Integer;
    segment_start: Integer;
    segment_text: string;
    total_count: Integer;
    segment_count: Integer;
begin
    Result := False;
    if Trim(encoded_path) = '' then
    begin
        Exit;
    end;

    total_count := 0;
    segment_count := 0;
    segment_start := 1;
    for idx := 1 to Length(encoded_path) + 1 do
    begin
        if (idx <= Length(encoded_path)) and (encoded_path[idx] <> c_learning_path_separator) then
        begin
            Continue;
        end;

        segment_text := Trim(Copy(encoded_path, segment_start, idx - segment_start));
        segment_start := idx + 1;
        if segment_text = '' then
        begin
            Continue;
        end;

        if not is_valid_learning_text(segment_text) then
        begin
            Exit;
        end;

        Inc(segment_count);
        Inc(total_count, get_valid_cjk_codepoint_count(segment_text));
        if total_count > 10 then
        begin
            Exit;
        end;
    end;

    Result := segment_count > 1;
end;

function TncSqliteDictionary.exact_base_entry_exists(const pinyin: string; const text: string): Boolean;
const
    base_exists_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_base_connection.prepare(base_exists_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, pinyin_key) and
            m_base_connection.bind_text(stmt, 2, text_key) then
        begin
            step_result := m_base_connection.step(stmt);
            Result := step_result = SQLITE_ROW;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.normalized_base_entry_exists(const pinyin: string; const text: string): Boolean;
const
    base_text_sql = 'SELECT pinyin FROM dict_base WHERE text = ?1 LIMIT 64';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
    candidate_pinyin: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    if exact_base_entry_exists(pinyin_key, text_key) then
    begin
        Result := True;
        Exit;
    end;

    stmt := nil;
    try
        if not (m_base_connection.prepare(base_text_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, text_key)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            candidate_pinyin := m_base_connection.column_text(stmt, 0);
            if same_normalized_pinyin_key(candidate_pinyin, pinyin_key) then
            begin
                Result := True;
                Exit;
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.has_any_base_phrase_for_pinyin(const pinyin: string): Boolean;
const
    base_phrase_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND length(text) >= 2 LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    if (pinyin_key = '') or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_base_connection.prepare(base_phrase_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, pinyin_key) then
        begin
            step_result := m_base_connection.step(stmt);
            Result := step_result = SQLITE_ROW;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.explicit_user_entry_exists(const pinyin: string; const text: string): Boolean;
const
    user_phrase_sql = 'SELECT 1 FROM dict_user WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(user_phrase_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) then
        begin
            step_result := m_user_connection.step(stmt);
            Result := step_result = SQLITE_ROW;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.is_suppressible_nonbase_exact_phrase(const pinyin: string;
    const text: string): Boolean;
const
    c_suppressible_phrase_min_units = 2;
    c_suppressible_phrase_max_units = 4;
    c_suppressible_long_phrase_min_units = 5;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    idx: Integer;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if (not is_full_pinyin_key(pinyin_key)) or (not is_valid_user_text(text_key)) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) then
    begin
        Exit;
    end;

    text_units := split_text_units_local(text_key);
    if (Length(text_units) < c_suppressible_phrase_min_units) then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    if Length(syllables) <> Length(text_units) then
    begin
        Exit;
    end;

    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;

    if Length(text_units) >= c_suppressible_long_phrase_min_units then
    begin
        for idx := 0 to High(text_units) do
        begin
            if not single_char_matches_pinyin(syllables[idx], text_units[idx]) then
            begin
                Exit;
            end;
        end;
        Exit(True);
    end;

    if Length(text_units) > c_suppressible_phrase_max_units then
    begin
        Exit;
    end;

    for idx := 0 to High(text_units) do
    begin
        if not single_char_matches_pinyin(syllables[idx], text_units[idx]) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function TncSqliteDictionary.split_full_pinyin_syllables(const pinyin: string): TArray<string>;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    reconstructed: string;
    pinyin_key: string;
begin
    SetLength(Result, 0);
    pinyin_key := LowerCase(Trim(pinyin));
    if pinyin_key = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(pinyin_key);
    finally
        parser.Free;
    end;

    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    reconstructed := '';
    SetLength(Result, Length(syllables));
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            SetLength(Result, 0);
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
        Result[idx] := syllables[idx].text;
    end;

    if not SameText(reconstructed, pinyin_key) then
    begin
        SetLength(Result, 0);
    end;
end;

function TncSqliteDictionary.is_whitelisted_constructed_phrase(const pinyin: string; const text: string): Boolean;

    function matches_expected_phrase(const expected_pinyin: string; const expected_text: string): Boolean;
    begin
        Result := SameText(pinyin, expected_pinyin) and SameText(text, expected_text);
    end;

var
    syllables: TArray<string>;
    text_units: TArray<string>;
begin
    Result := False;
    if (pinyin = '') or (text = '') then
    begin
        Exit;
    end;

    if matches_expected_phrase('zhege', string(Char($8FD9)) + string(Char($4E2A))) or
        matches_expected_phrase('nage', string(Char($90A3)) + string(Char($4E2A))) or
        matches_expected_phrase('neige', string(Char($90A3)) + string(Char($4E2A))) or
        matches_expected_phrase('yige', string(Char($4E00)) + string(Char($4E2A))) or
        matches_expected_phrase('liangge', string(Char($4E24)) + string(Char($4E2A))) or
        matches_expected_phrase('jige', string(Char($51E0)) + string(Char($4E2A))) or
        matches_expected_phrase('meige', string(Char($6BCF)) + string(Char($4E2A))) or
        matches_expected_phrase('sange', string(Char($4E09)) + string(Char($4E2A))) or
        matches_expected_phrase('sige', string(Char($56DB)) + string(Char($4E2A))) or
        matches_expected_phrase('wuge', string(Char($4E94)) + string(Char($4E2A))) or
        matches_expected_phrase('liuge', string(Char($516D)) + string(Char($4E2A))) or
        matches_expected_phrase('qige', string(Char($4E03)) + string(Char($4E2A))) or
        matches_expected_phrase('bage', string(Char($516B)) + string(Char($4E2A))) or
        matches_expected_phrase('jiuge', string(Char($4E5D)) + string(Char($4E2A))) or
        matches_expected_phrase('shige', string(Char($5341)) + string(Char($4E2A))) or
        matches_expected_phrase('zhexie', string(Char($8FD9)) + string(Char($4E9B))) or
        matches_expected_phrase('naxie', string(Char($90A3)) + string(Char($4E9B))) or
        matches_expected_phrase('neixie', string(Char($90A3)) + string(Char($4E9B))) or
        matches_expected_phrase('yixie', string(Char($4E00)) + string(Char($4E9B))) or
        matches_expected_phrase('zheyang', string(Char($8FD9)) + string(Char($6837))) or
        matches_expected_phrase('nayang', string(Char($90A3)) + string(Char($6837))) or
        matches_expected_phrase('neiyang', string(Char($90A3)) + string(Char($6837))) or
        matches_expected_phrase('zheme', string(Char($8FD9)) + string(Char($4E48))) or
        matches_expected_phrase('name', string(Char($90A3)) + string(Char($4E48))) or
        matches_expected_phrase('neime', string(Char($90A3)) + string(Char($4E48))) or
        matches_expected_phrase('zenme', string(Char($600E)) + string(Char($4E48))) or
        matches_expected_phrase('youdian', string(Char($6709)) + string(Char($70B9))) then
    begin
        Result := True;
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin);
    text_units := split_text_units_local(Trim(text));
    if (Length(syllables) = 2) and (Length(text_units) = 2) and
        SameText(syllables[0], syllables[1]) and SameText(text_units[0], text_units[1]) then
    begin
        Result := True;
    end;
end;

function TncSqliteDictionary.is_nonbase_multi_segment_composed_exact_phrase(const pinyin: string;
    const text: string): Boolean;
const
    c_composed_exact_phrase_min_units = 6;
    c_composed_exact_phrase_min_segments = 3;
    c_composed_exact_phrase_segment_max_syllables = 8;
    c_composed_exact_phrase_segment_max_units = 4;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    segment_exists_cache: TDictionary<string, Boolean>;
    compose_cache: TDictionary<string, Boolean>;

    function build_range_key(const start_syllable: Integer; const end_syllable: Integer;
        const start_unit: Integer; const end_unit: Integer): string;
    begin
        Result := IntToStr(start_syllable) + ':' + IntToStr(end_syllable) + '|' +
            IntToStr(start_unit) + ':' + IntToStr(end_unit);
    end;

    function build_compose_key(const start_syllable: Integer; const start_unit: Integer;
        const min_segments_remaining: Integer): string;
    begin
        Result := IntToStr(start_syllable) + '|' + IntToStr(start_unit) + '|' +
            IntToStr(min_segments_remaining);
    end;

    function join_syllable_slice(const start_idx: Integer; const end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + syllables[idx];
        end;
    end;

    function join_text_unit_slice(const start_idx: Integer; const end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + text_units[idx];
        end;
    end;

    function segment_exists(const start_syllable: Integer; const end_syllable: Integer;
        const start_unit: Integer; const end_unit: Integer): Boolean;
    var
        cache_key: string;
        segment_pinyin: string;
        segment_text: string;
    begin
        Result := False;
        if (start_syllable > end_syllable) or (start_unit > end_unit) then
        begin
            Exit;
        end;

        cache_key := build_range_key(start_syllable, end_syllable, start_unit, end_unit);
        if segment_exists_cache.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        segment_pinyin := join_syllable_slice(start_syllable, end_syllable);
        segment_text := join_text_unit_slice(start_unit, end_unit);
        Result := normalized_base_entry_exists(segment_pinyin, segment_text);
        segment_exists_cache.AddOrSetValue(cache_key, Result);
    end;

    function can_compose_from(const start_syllable: Integer; const start_unit: Integer;
        const min_segments_remaining: Integer): Boolean;
    var
        cache_key: string;
        end_syllable: Integer;
        end_unit: Integer;
        max_end_syllable: Integer;
        max_end_unit: Integer;
        next_required_segments: Integer;
    begin
        if (start_syllable = Length(syllables)) and (start_unit = Length(text_units)) then
        begin
            Exit(min_segments_remaining <= 0);
        end;
        if (start_syllable >= Length(syllables)) or (start_unit >= Length(text_units)) then
        begin
            Exit(False);
        end;

        cache_key := build_compose_key(start_syllable, start_unit, min_segments_remaining);
        if compose_cache.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        Result := False;
        max_end_syllable := Min(High(syllables),
            start_syllable + c_composed_exact_phrase_segment_max_syllables - 1);
        max_end_unit := Min(High(text_units),
            start_unit + c_composed_exact_phrase_segment_max_units - 1);
        for end_syllable := start_syllable to max_end_syllable do
        begin
            for end_unit := start_unit to max_end_unit do
            begin
                if not segment_exists(start_syllable, end_syllable, start_unit, end_unit) then
                begin
                    Continue;
                end;

                next_required_segments := Max(min_segments_remaining - 1, 0);
                if can_compose_from(end_syllable + 1, end_unit + 1, next_required_segments) then
                begin
                    Result := True;
                    compose_cache.AddOrSetValue(cache_key, Result);
                    Exit;
                end;
            end;
        end;

        compose_cache.AddOrSetValue(cache_key, Result);
    end;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if (not is_full_pinyin_key(pinyin_key)) or (not is_valid_user_text(text_key)) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) then
    begin
        Exit;
    end;
    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;

    text_units := split_text_units_local(text_key);
    if Length(text_units) < c_composed_exact_phrase_min_units then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    segment_exists_cache := TDictionary<string, Boolean>.Create;
    compose_cache := TDictionary<string, Boolean>.Create;
    try
        Result := can_compose_from(0, 0, c_composed_exact_phrase_min_segments);
    finally
        compose_cache.Free;
        segment_exists_cache.Free;
    end;
end;

function TncSqliteDictionary.should_suppress_exact_query_learning(const pinyin: string;
    const text: string): Boolean;
begin
    Result := is_nonbase_multi_segment_composed_exact_phrase(pinyin, text);
end;

function TncSqliteDictionary.is_likely_noisy_constructed_phrase(const pinyin: string; const text: string;
    const commit_count: Integer; const user_weight: Integer): Boolean;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    idx: Integer;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if (not is_full_pinyin_key(pinyin_key)) or (not is_valid_user_text(text_key)) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) then
    begin
        Exit;
    end;
    if not has_any_base_phrase_for_pinyin(pinyin_key) then
    begin
        Exit;
    end;
    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;
    if (commit_count > 1) or (user_weight > 1) then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    text_units := split_text_units_local(text_key);
    if (Length(syllables) <> Length(text_units)) or (Length(text_units) < 2) or (Length(text_units) > 4) then
    begin
        Exit;
    end;

    for idx := 0 to High(text_units) do
    begin
        if not single_char_matches_pinyin(syllables[idx], text_units[idx]) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function TncSqliteDictionary.should_suppress_constructed_user_phrase(const pinyin: string;
    const text: string; const commit_count: Integer; const user_weight: Integer): Boolean;
const
    c_constructed_phrase_commit_trust_min = 3;
    c_constructed_phrase_weight_trust_min = 3;
begin
    Result := False;
    if should_suppress_exact_query_learning(pinyin, text) then
    begin
        Exit(True);
    end;

    if not is_suppressible_nonbase_exact_phrase(pinyin, text) then
    begin
        Exit;
    end;

    if user_weight > 0 then
    begin
        // dict_user rows represent explicit user-word confirmations. Do not
        // treat them as weak constructed pollution.
        Exit(False);
    end;

    // Treat one-off or low-support non-base full-pinyin chains as polluted
    // user learning, but still allow genuinely repeated explicit selections
    // to surface after enough confirmations.
    if (commit_count >= c_constructed_phrase_commit_trust_min) or
        (user_weight >= c_constructed_phrase_weight_trust_min) then
    begin
        Exit(False);
    end;

    Result := True;
end;

function TncSqliteDictionary.get_contains_popularity_score(const token: string): Integer;
const
    query_sql = 'SELECT COALESCE(SUM(weight), 0) FROM dict_base WHERE instr(text, ?1) > 0';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    Result := 0;
    if (token = '') or (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if (m_contains_popularity_cache <> nil) and m_contains_popularity_cache.TryGetValue(token, Result) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;
        if not m_base_connection.bind_text(stmt, 1, token) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(stmt, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.AddOrSetValue(token, Result);
    end;
end;

function TncSqliteDictionary.get_prefix_popularity_score(const prefix: string): Integer;
const
    query_sql = 'SELECT COALESCE(SUM(weight), 0) FROM dict_base WHERE text >= ?1 AND text < ?2';
var
    step_result: Integer;
    upper_bound: string;
begin
    Result := 0;
    if (prefix = '') or (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if (m_prefix_popularity_cache <> nil) and m_prefix_popularity_cache.TryGetValue(prefix, Result) then
    begin
        Exit;
    end;
    upper_bound := build_prefix_upper_bound(prefix);

    try
        if m_stmt_prefix_popularity = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_prefix_popularity) then
            begin
                Exit;
            end;
        end;
        if (not m_base_connection.reset(m_stmt_prefix_popularity)) or
            (not m_base_connection.clear_bindings(m_stmt_prefix_popularity)) or
            (not m_base_connection.bind_text(m_stmt_prefix_popularity, 1, prefix)) or
            (not m_base_connection.bind_text(m_stmt_prefix_popularity, 2, upper_bound)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_prefix_popularity);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(m_stmt_prefix_popularity, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if m_stmt_prefix_popularity <> nil then
        begin
            m_base_connection.reset(m_stmt_prefix_popularity);
            m_base_connection.clear_bindings(m_stmt_prefix_popularity);
        end;
    end;

    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.AddOrSetValue(prefix, Result);
    end;
end;

function TncSqliteDictionary.get_pinyin_followup_popularity_score(const pinyin: string): Integer;
const
    query_sql =
        'SELECT COALESCE(SUM(weight), 0) FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND pinyin <> ?1';
var
    step_result: Integer;
    normalized: string;
    upper_bound: string;
begin
    Result := 0;
    normalized := normalize_compact_pinyin_key(pinyin);
    if (normalized = '') or (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if (m_pinyin_followup_popularity_cache <> nil) and
        m_pinyin_followup_popularity_cache.TryGetValue(normalized, Result) then
    begin
        Exit;
    end;
    upper_bound := build_prefix_upper_bound(normalized);

    try
        if m_stmt_pinyin_followup_popularity = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_pinyin_followup_popularity) then
            begin
                Exit;
            end;
        end;
        if (not m_base_connection.reset(m_stmt_pinyin_followup_popularity)) or
            (not m_base_connection.clear_bindings(m_stmt_pinyin_followup_popularity)) or
            (not m_base_connection.bind_text(m_stmt_pinyin_followup_popularity, 1, normalized)) or
            (not m_base_connection.bind_text(m_stmt_pinyin_followup_popularity, 2, upper_bound)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_pinyin_followup_popularity);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(m_stmt_pinyin_followup_popularity, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if m_stmt_pinyin_followup_popularity <> nil then
        begin
            m_base_connection.reset(m_stmt_pinyin_followup_popularity);
            m_base_connection.clear_bindings(m_stmt_pinyin_followup_popularity);
        end;
    end;

    if m_pinyin_followup_popularity_cache <> nil then
    begin
        m_pinyin_followup_popularity_cache.AddOrSetValue(normalized, Result);
    end;
end;

procedure TncSqliteDictionary.populate_prefix_popularity_scores(const prefixes: TArray<string>;
    const target_scores: TDictionary<string, Integer>);
var
    pending_keys: TList<string>;
    prefix_value: string;
    cached_score: Integer;
    idx: Integer;
begin
    if target_scores = nil then
    begin
        Exit;
    end;

    pending_keys := TList<string>.Create;
    try
        for idx := 0 to High(prefixes) do
        begin
            prefix_value := Trim(prefixes[idx]);
            if prefix_value = '' then
            begin
                Continue;
            end;

            if target_scores.ContainsKey(prefix_value) then
            begin
                Continue;
            end;
            if (m_prefix_popularity_cache <> nil) and
                m_prefix_popularity_cache.TryGetValue(prefix_value, cached_score) then
            begin
                target_scores.AddOrSetValue(prefix_value, cached_score);
                Continue;
            end;
            if pending_keys.IndexOf(prefix_value) < 0 then
            begin
                pending_keys.Add(prefix_value);
            end;
        end;

        if (pending_keys.Count <= 0) or (not ensure_open) or (not m_base_ready) then
        begin
            Exit;
        end;
        for idx := 0 to pending_keys.Count - 1 do
        begin
            target_scores.AddOrSetValue(pending_keys[idx], get_prefix_popularity_score(pending_keys[idx]));
        end;
    finally
        pending_keys.Free;
    end;
end;

procedure TncSqliteDictionary.populate_pinyin_followup_popularity_scores(const pinyin_keys: TArray<string>;
    const target_scores: TDictionary<string, Integer>);
var
    pending_keys: TList<string>;
    normalized_value: string;
    cached_score: Integer;
    idx: Integer;
begin
    if target_scores = nil then
    begin
        Exit;
    end;

    pending_keys := TList<string>.Create;
    try
        for idx := 0 to High(pinyin_keys) do
        begin
            normalized_value := normalize_compact_pinyin_key(pinyin_keys[idx]);
            if normalized_value = '' then
            begin
                Continue;
            end;

            if target_scores.ContainsKey(normalized_value) then
            begin
                Continue;
            end;
            if (m_pinyin_followup_popularity_cache <> nil) and
                m_pinyin_followup_popularity_cache.TryGetValue(normalized_value, cached_score) then
            begin
                target_scores.AddOrSetValue(normalized_value, cached_score);
                Continue;
            end;
            if pending_keys.IndexOf(normalized_value) < 0 then
            begin
                pending_keys.Add(normalized_value);
            end;
        end;

        if (pending_keys.Count <= 0) or (not ensure_open) or (not m_base_ready) then
        begin
            Exit;
        end;
        for idx := 0 to pending_keys.Count - 1 do
        begin
            target_scores.AddOrSetValue(pending_keys[idx],
                get_pinyin_followup_popularity_score(pending_keys[idx]));
        end;
    finally
        pending_keys.Free;
    end;
end;

function TncSqliteDictionary.get_single_char_exact_weight(const pinyin: string; const text_unit: string): Integer;
const
    query_sql =
        'SELECT COALESCE(MAX(weight), 0) FROM dict_base ' +
        'WHERE pinyin = ?1 AND text = ?2 AND length(text) = 1';
var
    step_result: Integer;
    normalized_pinyin: string;
    cache_key: string;
begin
    Result := 0;
    normalized_pinyin := normalize_compact_pinyin_key(pinyin);
    if (normalized_pinyin = '') or (text_unit = '') or (Length(text_unit) <> 1) or
        (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    cache_key := normalized_pinyin + #9 + text_unit;
    if (m_single_char_weight_cache <> nil) and
        m_single_char_weight_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if m_stmt_single_char_exact_weight = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_single_char_exact_weight) then
            begin
                Exit;
            end;
        end;
        if (not m_base_connection.reset(m_stmt_single_char_exact_weight)) or
            (not m_base_connection.clear_bindings(m_stmt_single_char_exact_weight)) or
            (not m_base_connection.bind_text(m_stmt_single_char_exact_weight, 1, normalized_pinyin)) or
            (not m_base_connection.bind_text(m_stmt_single_char_exact_weight, 2, text_unit)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_single_char_exact_weight);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(m_stmt_single_char_exact_weight, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if m_stmt_single_char_exact_weight <> nil then
        begin
            m_base_connection.reset(m_stmt_single_char_exact_weight);
            m_base_connection.clear_bindings(m_stmt_single_char_exact_weight);
        end;
    end;

    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_user_entry_count(const connection: TncSqliteConnection; out count: Integer): Boolean;
const
    sql_text = 'SELECT COUNT(1) FROM dict_user';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    count := 0;
    if (connection = nil) or not connection.opened then
    begin
        Result := False;
        Exit;
    end;

    stmt := nil;
    try
        if not connection.prepare(sql_text, stmt) then
        begin
            Result := False;
            Exit;
        end;

        step_result := connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            count := connection.column_int(stmt, 0);
            Result := True;
            Exit;
        end;
    finally
        if stmt <> nil then
        begin
            connection.finalize(stmt);
        end;
    end;

    Result := False;
end;

procedure TncSqliteDictionary.migrate_user_entries;
const
    select_sql = 'SELECT pinyin, text, weight, last_used FROM dict_user';
    insert_sql = 'INSERT OR IGNORE INTO dict_user(pinyin, text, weight, last_used) VALUES (?1, ?2, ?3, ?4)';
var
    user_count: Integer;
    stmt_select: Psqlite3_stmt;
    stmt_insert: Psqlite3_stmt;
    step_result: Integer;
    pinyin: string;
    text_value: string;
    weight_value: Integer;
    last_used_value: Integer;
begin
    if (not m_base_ready) or (not m_user_ready) then
    begin
        Exit;
    end;

    if not get_user_entry_count(m_user_connection, user_count) then
    begin
        Exit;
    end;

    if user_count > 0 then
    begin
        Exit;
    end;

    stmt_select := nil;
    stmt_insert := nil;
    try
        if not m_base_connection.prepare(select_sql, stmt_select) then
        begin
            Exit;
        end;
        if not m_user_connection.prepare(insert_sql, stmt_insert) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt_select);
        while step_result = SQLITE_ROW do
        begin
            pinyin := m_base_connection.column_text(stmt_select, 0);
            text_value := m_base_connection.column_text(stmt_select, 1);
            if (pinyin <> '') and is_valid_user_text(text_value) then
            begin
                weight_value := m_base_connection.column_int(stmt_select, 2);
                last_used_value := m_base_connection.column_int(stmt_select, 3);
                m_user_connection.reset(stmt_insert);
                m_user_connection.clear_bindings(stmt_insert);
                if m_user_connection.bind_text(stmt_insert, 1, pinyin) and
                    m_user_connection.bind_text(stmt_insert, 2, text_value) and
                    m_user_connection.bind_int(stmt_insert, 3, weight_value) and
                    m_user_connection.bind_int(stmt_insert, 4, last_used_value) then
                begin
                    m_user_connection.step(stmt_insert);
                end;
            end;

            step_result := m_base_connection.step(stmt_select);
        end;
    finally
        if stmt_select <> nil then
        begin
            m_base_connection.finalize(stmt_select);
        end;
        if stmt_insert <> nil then
        begin
            m_user_connection.finalize(stmt_insert);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_user_entries_existing_in_base;
const
    select_user_sql = 'SELECT pinyin, text FROM dict_user';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
var
    stmt_select: Psqlite3_stmt;
    stmt_delete: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    keys_to_delete: TList<string>;
    key_value: string;
    sep_index: Integer;
begin
    if (not m_base_ready) or (not m_user_ready) then
    begin
        Exit;
    end;

    keys_to_delete := TList<string>.Create;
    stmt_select := nil;
    try
        if not m_user_connection.prepare(select_user_sql, stmt_select) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt_select);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := m_user_connection.column_text(stmt_select, 0);
            text_value := m_user_connection.column_text(stmt_select, 1);
            if (pinyin_value <> '') and (text_value <> '') then
            begin
                if normalized_base_entry_exists(pinyin_value, text_value) then
                begin
                    keys_to_delete.Add(pinyin_value + #1 + text_value);
                end;
            end;

            step_result := m_user_connection.step(stmt_select);
        end;
    finally
        if stmt_select <> nil then
        begin
            m_user_connection.finalize(stmt_select);
        end;
    end;

    if keys_to_delete.Count = 0 then
    begin
        keys_to_delete.Free;
        Exit;
    end;

    stmt_delete := nil;
    try
        if not m_user_connection.prepare(delete_user_sql, stmt_delete) then
        begin
            Exit;
        end;

        for key_value in keys_to_delete do
        begin
            sep_index := Pos(#1, key_value);
            if sep_index <= 0 then
            begin
                Continue;
            end;

            pinyin_value := Copy(key_value, 1, sep_index - 1);
            text_value := Copy(key_value, sep_index + 1, MaxInt);
            if (pinyin_value = '') or (text_value = '') then
            begin
                Continue;
            end;

            if m_user_connection.reset(stmt_delete) and
                m_user_connection.clear_bindings(stmt_delete) and
                m_user_connection.bind_text(stmt_delete, 1, pinyin_value) and
                m_user_connection.bind_text(stmt_delete, 2, text_value) then
            begin
                m_user_connection.step(stmt_delete);
            end;
        end;
    finally
        keys_to_delete.Free;
        if stmt_delete <> nil then
        begin
            m_user_connection.finalize(stmt_delete);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_bigram_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_bigram';
    delete_sql =
        'DELETE FROM dict_user_bigram WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_bigram ' +
        'ORDER BY last_used ASC, commit_count ASC, left_text ASC, text ASC LIMIT ?1)';
    c_bigram_prune_interval = 64;
    c_bigram_max_rows = 50000;
    c_bigram_target_rows = 45000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (m_user_connection = nil) or (not m_user_ready) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_bigram_prune_countdown);
        if m_bigram_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;
    m_bigram_prune_countdown := c_bigram_prune_interval;

    row_count := 0;
    stmt := nil;
    try
        if m_user_connection.prepare(count_sql, stmt) then
        begin
            step_result := m_user_connection.step(stmt);
            if step_result = SQLITE_ROW then
            begin
                row_count := m_user_connection.column_int(stmt, 0);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_bigram_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_bigram_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(delete_sql, stmt) and
            m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

end;

procedure TncSqliteDictionary.prune_trigram_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_trigram';
    delete_sql =
        'DELETE FROM dict_user_trigram WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_trigram ' +
        'ORDER BY last_used ASC, commit_count ASC, prev_prev_text ASC, prev_text ASC, text ASC LIMIT ?1)';
    c_trigram_prune_interval = 64;
    c_trigram_max_rows = 80000;
    c_trigram_target_rows = 70000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (m_user_connection = nil) or (not m_user_ready) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_trigram_prune_countdown);
        if m_trigram_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;
    m_trigram_prune_countdown := c_trigram_prune_interval;

    row_count := 0;
    stmt := nil;
    try
        if m_user_connection.prepare(count_sql, stmt) then
        begin
            step_result := m_user_connection.step(stmt);
            if step_result = SQLITE_ROW then
            begin
                row_count := m_user_connection.column_int(stmt, 0);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_trigram_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_trigram_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(delete_sql, stmt) and
            m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_query_path_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_query_path';
    delete_sql =
        'DELETE FROM dict_user_query_path WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_query_path ' +
        'ORDER BY last_used ASC, commit_count ASC LIMIT ?1)';
    c_query_path_prune_interval = 64;
    c_query_path_max_rows = 60000;
    c_query_path_target_rows = 52000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_query_path_prune_countdown);
        if m_query_path_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;

    m_query_path_prune_countdown := c_query_path_prune_interval;
    stmt := nil;
    row_count := 0;
    try
        if not m_user_connection.prepare(count_sql, stmt) then
        begin
            Exit;
        end;
        step_result := m_user_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            row_count := m_user_connection.column_int(stmt, 0);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_query_path_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_query_path_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(delete_sql, stmt) then
        begin
            Exit;
        end;
        if not m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            Exit;
        end;
        m_user_connection.step(stmt);
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_query_path_penalty_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_query_path_penalty';
    delete_sql =
        'DELETE FROM dict_user_query_path_penalty WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_query_path_penalty ' +
        'ORDER BY last_used ASC, penalty ASC LIMIT ?1)';
    c_query_path_penalty_prune_interval = 64;
    c_query_path_penalty_max_rows = 60000;
    c_query_path_penalty_target_rows = 52000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_query_path_penalty_prune_countdown);
        if m_query_path_penalty_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;

    m_query_path_penalty_prune_countdown := c_query_path_penalty_prune_interval;
    stmt := nil;
    row_count := 0;
    try
        if not m_user_connection.prepare(count_sql, stmt) then
        begin
            Exit;
        end;
        step_result := m_user_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            row_count := m_user_connection.column_int(stmt, 0);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_query_path_penalty_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_query_path_penalty_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(delete_sql, stmt) then
        begin
            Exit;
        end;
        if not m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            Exit;
        end;
        m_user_connection.step(stmt);
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.open: Boolean;
begin
    m_ready := False;
    m_base_ready := False;
    m_user_ready := False;
    Result := False;

    if (m_base_db_path = '') and (m_user_db_path = '') then
    begin
        Exit;
    end;

    if m_base_db_path <> '' then
    begin
        if m_base_connection = nil then
        begin
            m_base_connection := TncSqliteConnection.create(m_base_db_path);
        end;

        m_base_ready := m_base_connection.open(SQLITE_OPEN_READONLY);
        if not m_base_ready then
        begin
            m_base_ready := m_base_connection.open(SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE);
            if m_base_ready then
            begin
                ensure_schema(m_base_connection);
            end;
        end;
    end;

    if m_user_db_path <> '' then
    begin
        if m_user_connection = nil then
        begin
            m_user_connection := TncSqliteConnection.create(m_user_db_path);
        end;

        m_user_ready := m_user_connection.open(SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE);
        if m_user_ready then
        begin
            m_user_ready := ensure_schema(m_user_connection);
            if m_user_ready then
            begin
                configure_user_connection;
                prune_bigram_rows_if_needed(True);
                prune_trigram_rows_if_needed(True);
                prune_query_path_rows_if_needed(True);
                prune_query_path_penalty_rows_if_needed(True);
            end;
        end;
    end;

    if m_base_ready and m_user_ready then
    begin
        migrate_user_entries;
        prune_user_entries_existing_in_base;
        prune_suspicious_user_entries;
    end;

    m_ready := m_base_ready or m_user_ready;
    Result := m_ready;
end;

procedure TncSqliteDictionary.close;
begin
    clear_cached_user_statements;
    if (m_stmt_base_query_path_bonus <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_base_query_path_bonus);
        m_stmt_base_query_path_bonus := nil;
    end;
    if (m_stmt_prefix_popularity <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_prefix_popularity);
        m_stmt_prefix_popularity := nil;
    end;
    if (m_stmt_pinyin_followup_popularity <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_pinyin_followup_popularity);
        m_stmt_pinyin_followup_popularity := nil;
    end;
    if (m_stmt_base_text_prefix_bonus <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_base_text_prefix_bonus);
        m_stmt_base_text_prefix_bonus := nil;
    end;
    if (m_stmt_single_char_exact_weight <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_single_char_exact_weight);
        m_stmt_single_char_exact_weight := nil;
    end;
    if m_base_connection <> nil then
    begin
        m_base_connection.close;
    end;
    if m_user_connection <> nil then
    begin
        m_user_connection.close;
    end;
    m_write_batch_depth := 0;

    m_ready := False;
    m_base_ready := False;
    m_user_ready := False;
    m_short_lookup_cache_prewarmed := False;
    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.Clear;
    end;
    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.Clear;
    end;
    if m_pinyin_followup_popularity_cache <> nil then
    begin
        m_pinyin_followup_popularity_cache.Clear;
    end;
    if m_base_text_prefix_bonus_cache <> nil then
    begin
        m_base_text_prefix_bonus_cache.Clear;
    end;
    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Clear;
    end;
    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Clear;
    end;
end;

procedure TncSqliteDictionary.clear_cached_user_statements;
begin
    if (m_stmt_query_choice_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_choice_bonus);
        m_stmt_query_choice_bonus := nil;
    end;
    if (m_stmt_query_latest_choice_text <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_latest_choice_text);
        m_stmt_query_latest_choice_text := nil;
    end;
    if (m_stmt_context_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_context_bonus);
        m_stmt_context_bonus := nil;
    end;
    if (m_stmt_context_trigram_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_context_trigram_bonus);
        m_stmt_context_trigram_bonus := nil;
    end;
    if (m_stmt_query_path_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_path_bonus);
        m_stmt_query_path_bonus := nil;
    end;
    if (m_stmt_query_path_penalty <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_path_penalty);
        m_stmt_query_path_penalty := nil;
    end;
    if (m_stmt_candidate_penalty <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_candidate_penalty);
        m_stmt_candidate_penalty := nil;
    end;
    if (m_stmt_record_context_pair_update <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_pair_update);
        m_stmt_record_context_pair_update := nil;
    end;
    if (m_stmt_record_context_pair_insert <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_pair_insert);
        m_stmt_record_context_pair_insert := nil;
    end;
    if (m_stmt_record_context_trigram_update <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_trigram_update);
        m_stmt_record_context_trigram_update := nil;
    end;
    if (m_stmt_record_context_trigram_insert <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_trigram_insert);
        m_stmt_record_context_trigram_insert := nil;
    end;
    if (m_stmt_record_query_path_update <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_query_path_update);
        m_stmt_record_query_path_update := nil;
    end;
    if (m_stmt_record_query_path_insert <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_query_path_insert);
        m_stmt_record_query_path_insert := nil;
    end;
end;

procedure TncSqliteDictionary.prewarm_short_lookup_caches;
const
    single_char_sql =
        'SELECT pinyin, text, MAX(weight) FROM dict_base ' +
        'WHERE length(text) = 1 GROUP BY pinyin, text';
    followup_sql =
        'SELECT COALESCE(SUM(weight), 0) FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND pinyin <> ?1';
    prefix_sql =
        'SELECT COALESCE(SUM(weight), 0) FROM dict_base WHERE text >= ?1 AND text < ?2';
    exact_weight_sql =
        'SELECT COALESCE(MAX(weight), 0) FROM dict_base ' +
        'WHERE pinyin = ?1 AND text = ?2 AND length(text) = 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    cache_key: string;
    weight_value: Integer;
begin
    if m_short_lookup_cache_prewarmed then
    begin
        Exit;
    end;
    if (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if m_stmt_prefix_popularity = nil then
    begin
        m_base_connection.prepare(prefix_sql, m_stmt_prefix_popularity);
    end;
    if m_stmt_pinyin_followup_popularity = nil then
    begin
        m_base_connection.prepare(followup_sql, m_stmt_pinyin_followup_popularity);
    end;
    if m_stmt_single_char_exact_weight = nil then
    begin
        m_base_connection.prepare(exact_weight_sql, m_stmt_single_char_exact_weight);
    end;

    stmt := nil;
    try
        if not m_base_connection.prepare(single_char_sql, stmt) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := normalize_compact_pinyin_key(m_base_connection.column_text(stmt, 0));
            text_value := Trim(m_base_connection.column_text(stmt, 1));
            weight_value := m_base_connection.column_int(stmt, 2);
            if weight_value < 0 then
            begin
                weight_value := 0;
            end;

            if (pinyin_value <> '') and (Length(text_value) = 1) and
                (m_single_char_weight_cache <> nil) then
            begin
                cache_key := pinyin_value + #9 + text_value;
                m_single_char_weight_cache.AddOrSetValue(cache_key, weight_value);
            end;
            step_result := m_base_connection.step(stmt);
        end;
        m_short_lookup_cache_prewarmed := True;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.lookup_exact_full_pinyin(const pinyin: string;
    out results: TncCandidateList): Boolean;
const
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
var
    stmt: Psqlite3_stmt;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Integer>;
    step_result: Integer;
    item: TncCandidate;
    query_key: string;
    limit_value: Integer;
    idx: Integer;
    key: string;
    text_value: string;
    comment_value: string;
    score_value: Integer;

    procedure add_or_merge_candidate(const candidate_text: string; const candidate_comment: string;
        const candidate_score: Integer; const candidate_source: TncCandidateSource);
    var
        local_idx: Integer;
        local_item: TncCandidate;
    begin
        key := Trim(candidate_text);
        if key = '' then
        begin
            Exit;
        end;

        if seen.TryGetValue(key, local_idx) then
        begin
            local_item := list[local_idx];
            if candidate_comment <> '' then
            begin
                local_item.comment := candidate_comment;
            end;
            if candidate_score > local_item.score then
            begin
                local_item.score := candidate_score;
            end;
            if (candidate_source = cs_user) or (local_item.source = cs_user) then
            begin
                local_item.source := cs_user;
            end;
            if candidate_score > local_item.dict_weight then
            begin
                local_item.dict_weight := candidate_score;
            end;
            local_item.has_dict_weight := True;
            list[local_idx] := local_item;
            Exit;
        end;

        item.text := key;
        item.comment := candidate_comment;
        item.score := candidate_score;
        item.source := candidate_source;
        item.has_dict_weight := True;
        item.dict_weight := candidate_score;
        seen.Add(key, list.Count);
        list.Add(item);
    end;

    function compare_candidate(const left: TncCandidate; const right: TncCandidate): Integer;
    begin
        if left.score <> right.score then
        begin
            Exit(right.score - left.score);
        end;
        if left.source <> right.source then
        begin
            if left.source = cs_user then
            begin
                Exit(-1);
            end;
            if right.source = cs_user then
            begin
                Exit(1);
            end;
        end;
        if left.dict_weight <> right.dict_weight then
        begin
            Exit(right.dict_weight - left.dict_weight);
        end;
        Result := CompareText(left.text, right.text);
    end;

    procedure sort_results;
    var
        left_idx: Integer;
        right_idx: Integer;
        temp: TncCandidate;
    begin
        if Length(results) <= 1 then
        begin
            Exit;
        end;

        for left_idx := 0 to High(results) - 1 do
        begin
            for right_idx := left_idx + 1 to High(results) do
            begin
                if compare_candidate(results[left_idx], results[right_idx]) > 0 then
                begin
                    temp := results[left_idx];
                    results[left_idx] := results[right_idx];
                    results[right_idx] := temp;
                end;
            end;
        end;
    end;
begin
    SetLength(results, 0);
    Result := False;
    query_key := normalize_compact_pinyin_key(Trim(pinyin));
    if query_key = '' then
    begin
        Exit;
    end;
    if not is_full_pinyin_key(query_key) then
    begin
        Exit(lookup(query_key, results));
    end;
    if not ensure_open then
    begin
        Exit;
    end;

    limit_value := Max(m_limit * 3, 24);
    if limit_value > 96 then
    begin
        limit_value := 96;
    end;

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Integer>.Create;
    try
        if m_user_ready then
        begin
            stmt := nil;
            if m_user_connection.prepare(user_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, query_key) and
                m_user_connection.bind_int(stmt, 2, limit_value) then
            begin
                repeat
                    step_result := m_user_connection.step(stmt);
                    if step_result = SQLITE_ROW then
                    begin
                        text_value := Trim(m_user_connection.column_text(stmt, 0));
                        score_value := m_user_connection.column_int(stmt, 1);
                        if should_suppress_constructed_user_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Continue;
                        end;
                        add_or_merge_candidate(text_value, '', score_value, cs_user);
                    end;
                until step_result <> SQLITE_ROW;
            end;
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        if m_base_ready then
        begin
            stmt := nil;
            if m_base_connection.prepare(base_sql, stmt) and
                m_base_connection.bind_text(stmt, 1, query_key) and
                m_base_connection.bind_int(stmt, 2, limit_value) then
            begin
                repeat
                    step_result := m_base_connection.step(stmt);
                    if step_result = SQLITE_ROW then
                    begin
                        text_value := Trim(m_base_connection.column_text(stmt, 1));
                        comment_value := Trim(m_base_connection.column_text(stmt, 2));
                        score_value := m_base_connection.column_int(stmt, 3);
                        add_or_merge_candidate(text_value, comment_value, score_value, cs_rule);
                    end;
                until step_result <> SQLITE_ROW;
            end;
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;

        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            results[idx] := list[idx];
        end;
        sort_results;
        Result := Length(results) > 0;
    finally
        seen.Free;
        list.Free;
    end;
end;

function TncSqliteDictionary.lookup(const pinyin: string; out results: TncCandidateList): Boolean;
const
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_exact_entry_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    base_typo_prefix_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin LIKE ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_single_char_exact_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 AND length(text) = 1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_jianpin_sql =
        'SELECT b.pinyin, b.text, b.comment, j.weight ' +
        'FROM (SELECT word_id, weight FROM dict_jianpin WHERE jianpin = ?1 ' +
        'ORDER BY weight DESC LIMIT ?2) j ' +
        'INNER JOIN dict_base b ON b.id = j.word_id ' +
        'ORDER BY j.weight DESC, b.weight DESC, b.text ASC LIMIT ?3';
    base_jianpin_prefixed_sql =
        'SELECT b.pinyin, b.text, b.comment, j.weight ' +
        'FROM (SELECT word_id, weight FROM dict_jianpin WHERE jianpin = ?1 ' +
        'ORDER BY weight DESC LIMIT ?2) j ' +
        'INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE b.pinyin LIKE ?3 ' +
        'ORDER BY j.weight DESC, b.weight DESC, b.text ASC LIMIT ?4';
    base_mixed_pattern_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_base b WHERE b.pinyin LIKE ?1 ' +
        'ORDER BY b.weight DESC, b.text ASC LIMIT ?2';
    base_initial_single_char_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_base b WHERE b.pinyin LIKE ?1 AND length(b.text) = 1 ' +
        'ORDER BY b.weight DESC, b.text ASC LIMIT ?2';
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
    user_nonfull_sql = 'SELECT pinyin, text, weight, last_used FROM dict_user WHERE pinyin LIKE ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
    stats_sql = 'SELECT text, commit_count, last_used FROM dict_user_stats WHERE pinyin = ?1';
    text_stats_sql =
        'SELECT COALESCE(SUM(commit_count), 0), COALESCE(MAX(last_used), 0) ' +
        'FROM dict_user_stats WHERE text = ?1';
    c_jianpin_score_penalty = 30;
    c_nonfull_exact_penalty = 100;
    c_initial_single_char_penalty = 120;
    c_single_letter_full_query_extra_penalty = 120;
    c_single_letter_full_query_cap_margin = 8;
    c_typo_transpose_penalty = 80;
    // For malformed non-full keys (e.g. "chagn"), adjacent-swap fallback
    // should stay conservative because earlier normalization already handles
    // the highest-value short typos.
    c_typo_min_query_len_nonfull = 6;
    // Full pinyin adjacent-swap probing is only worth trying on longer inputs;
    // keep short exact full keys strict to avoid polluting common lookups.
    c_typo_min_query_len_full = 7;
    c_typo_prefix_min_query_len_nonfull = 7;
    c_typo_prefix_min_query_len_full = 8;
    c_typo_probe_limit = 18;
    c_typo_max_added = 12;
    c_typo_prefix_probe_limit = 6;
    c_typo_prefix_extra_penalty = 120;
    c_full_query_dual_jianpin_len_min = 2;
    c_full_query_dual_jianpin_len_max = 4;
    c_full_query_dual_jianpin_penalty = 20;
    // Runtime homophone bonus currently relies on expensive full-table scans
    // (text contains/prefix aggregate), which can add noticeable input latency
    // on common keys like "shi"/"de". Keep this disabled by default.
    c_enable_runtime_homophone_bonus = False;
var
    stmt: Psqlite3_stmt;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Boolean>;
    candidate_pinyin_map: TDictionary<string, string>;
    candidate_score_cap_map: TDictionary<string, Integer>;
    learning_bonus_map: TDictionary<string, Integer>;
    text_learning_bonus_cache: TDictionary<string, Integer>;
    step_result: Integer;
    item: TncCandidate;
    text_value: string;
    comment_value: string;
    score_value: Integer;
    dict_weight_value: Integer;
    score_with_bonus: Integer;
    commit_count: Integer;
    last_used_value: Int64;
    learning_bonus: Integer;
    now_unix: Int64;
    i: Integer;
    key: string;
    query_key: string;
    candidate_pinyin: string;
    candidate_score_cap: Integer;
    mixed_full_prefix: string;
    mixed_jianpin_key: string;
    effective_jianpin_key: string;
    full_query_jianpin_key: string;
    jianpin_query_keys: TArray<string>;
    matching_jianpin_query_keys: TArray<string>;
    mixed_tokens: TncMixedQueryTokenList;
    mixed_mode: Boolean;
    full_pinyin_query: Boolean;
    allow_full_query_jianpin_fallback: Boolean;
    full_query_dual_jianpin_mode: Boolean;
    single_letter_query: Boolean;
    mixed_parser: TncPinyinParser;
    mixed_like_pattern: string;
    jianpin_score_penalty: Integer;
    single_letter_cap_score: Integer;
    single_letter_has_cap: Boolean;
    single_syllable_full_query: Boolean;
    full_query_syllable_count: Integer;
    single_char_probe_limit: Integer;
    user_nonfull_lookup: Boolean;
    user_like_pattern: string;
    user_probe_limit: Integer;
    base_jianpin_probe_limit: Integer;
    query_key_idx: Integer;
    exact_base_hit: Boolean;
    typo_fallback_used: Boolean;
    force_noisy_reset_before_typo: Boolean;
    normalized_query_key: string;
    full_query_dual_jianpin_cap_score: Integer;
    full_query_dual_jianpin_has_cap: Boolean;
    disable_long_full_query_jianpin: Boolean;
    applied_learning_bonus_count: Integer;
    applied_text_learning_bonus_count: Integer;
    skipped_single_char_mismatch_count: Integer;
    skipped_noisy_user_count: Integer;
    skipped_base_dup_user_count: Integer;
    injected_learned_base_count: Integer;

    function build_mixed_like_pattern(const token_list: TncMixedQueryTokenList): string; forward;
    function is_compact_ascii_query(const value: string): Boolean; forward;
    procedure add_jianpin_query_key(var target_keys: TArray<string>; const key_value: string); forward;
    procedure append_jianpin_query_key_variants(var target_keys: TArray<string>; const key_value: string;
        const allow_short_retroflex_expansion: Boolean); forward;

    function mixed_query_has_internal_dangling_initial(const token_list: TncMixedQueryTokenList): Boolean;
    var
        token_idx: Integer;
    begin
        Result := False;
        if Length(token_list) <= 1 then
        begin
            Exit;
        end;

        // Pattern like "cha + g + n" often means a malformed compact input.
        // Prefer typo recovery over mixed/jianpin expansion in this case.
        for token_idx := 0 to High(token_list) - 1 do
        begin
            if token_list[token_idx].kind = mqt_initial then
            begin
                Result := True;
                Exit;
            end;
        end;
    end;

    function normalize_adjacent_swap_to_full_pinyin(const value: string): string;
    var
        swap_idx: Integer;
        swap_value: string;
        swap_char: Char;
    begin
        Result := '';
        if (Length(value) < c_typo_min_query_len_nonfull) or (not is_compact_ascii_query(value)) then
        begin
            Exit;
        end;

        // Prefer right-most swaps first: tail errors like "...gn" -> "...ng" are common.
        for swap_idx := Length(value) - 1 downto 1 do
        begin
            if value[swap_idx] = value[swap_idx + 1] then
            begin
                Continue;
            end;

            swap_value := value;
            swap_char := swap_value[swap_idx];
            swap_value[swap_idx] := swap_value[swap_idx + 1];
            swap_value[swap_idx + 1] := swap_char;
            if is_full_pinyin_key(swap_value) then
            begin
                Result := swap_value;
                Exit;
            end;
        end;
    end;

    procedure add_jianpin_query_key(var target_keys: TArray<string>; const key_value: string);
    var
        idx: Integer;
    begin
        if key_value = '' then
        begin
            Exit;
        end;

        for idx := 0 to High(target_keys) do
        begin
            if SameText(target_keys[idx], key_value) then
            begin
                Exit;
            end;
        end;

        SetLength(target_keys, Length(target_keys) + 1);
        target_keys[High(target_keys)] := key_value;
    end;

    procedure append_jianpin_query_key_variants(var target_keys: TArray<string>; const key_value: string;
        const allow_short_retroflex_expansion: Boolean);
    const
        c_jianpin_variant_full_expand_pair_limit = 1;
        c_jianpin_variant_full_expand_len_max = 5;
        c_jianpin_collapsed_fallback_len_min = 5;
    var
        variants: TArray<string>;
        idx: Integer;
        retroflex_pair_count: Integer;
        collapsed_value: string;
    begin
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(key_value);
        if retroflex_pair_count <= 0 then
        begin
            add_jianpin_query_key(target_keys, key_value);
            Exit;
        end;

        add_jianpin_query_key(target_keys, key_value);
        if Length(key_value) >= c_jianpin_collapsed_fallback_len_min then
        begin
            collapsed_value := collapse_retroflex_pairs_in_compact_key(key_value);
            if collapsed_value <> '' then
            begin
                add_jianpin_query_key(target_keys, collapsed_value);
            end;
        end;

        if (not allow_short_retroflex_expansion) and (Length(key_value) <= 4) then
        begin
            Exit;
        end;

        if (retroflex_pair_count > c_jianpin_variant_full_expand_pair_limit) or
            (Length(key_value) > c_jianpin_variant_full_expand_len_max) then
        begin
            Exit;
        end;

        variants := build_jianpin_query_variants(key_value);
        for idx := 0 to High(variants) do
        begin
            add_jianpin_query_key(target_keys, variants[idx]);
        end;
    end;

    function get_jianpin_probe_limit_for_key(const base_key_value: string; const current_key_value: string): Integer;
    var
        retroflex_pair_count: Integer;
    begin
        Result := base_jianpin_probe_limit;
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(base_key_value);
        if SameText(base_key_value, current_key_value) and is_bare_retroflex_pair_key(base_key_value) then
        begin
            Result := Min(Result, 128);
        end
        else if SameText(base_key_value, current_key_value) and (retroflex_pair_count > 0) and
            (Length(base_key_value) <= 4) then
        begin
            if Length(base_key_value) <= 3 then
            begin
                Result := Min(Result, 96);
            end
            else
            begin
                Result := Min(Result, 128);
            end;
        end
        else if is_retroflex_collapsed_fallback_key(base_key_value, current_key_value) then
        begin
            if is_bare_retroflex_pair_key(base_key_value) then
            begin
                Result := Min(Result, 64);
            end
            else if (retroflex_pair_count > 0) and (Length(base_key_value) <= 4) then
            begin
                if Length(base_key_value) <= 3 then
                begin
                    Result := Min(Result, 32);
                end
                else
                begin
                    Result := Min(Result, 48);
                end;
            end
            else if Length(base_key_value) <= 2 then
            begin
                Result := Min(Result, 192);
            end
            else if Length(base_key_value) = 3 then
            begin
                Result := Min(Result, 160);
            end
            else
            begin
                Result := Min(Result, 128);
            end;
        end;
    end;

    function get_jianpin_inner_probe_limit_for_key(const base_key_value: string;
        const current_key_value: string; const prefixed_query: Boolean): Integer;
    var
        outer_limit: Integer;
        retroflex_pair_count: Integer;
    begin
        outer_limit := get_jianpin_probe_limit_for_key(base_key_value, current_key_value);
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(base_key_value);
        if SameText(base_key_value, current_key_value) and (retroflex_pair_count > 0) and
            (Length(base_key_value) <= 4) then
        begin
            if prefixed_query then
            begin
                Result := Min(Max(outer_limit * 2, 128), 192);
            end
            else
            begin
                Result := Min(Max(outer_limit * 2, 128), 160);
            end;
        end
        else if (retroflex_pair_count > 0) and (Length(base_key_value) <= 4) and
            is_retroflex_collapsed_fallback_key(base_key_value, current_key_value) then
        begin
            if prefixed_query then
            begin
                Result := Min(Max(outer_limit * 2, 64), 96);
            end
            else
            begin
                Result := Min(Max(outer_limit * 2, 64), 96);
            end;
        end
        else if prefixed_query then
        begin
            Result := Max(outer_limit * 4, 256);
        end
        else
        begin
            Result := Max(outer_limit * 3, 192);
        end;
    end;

    function should_skip_deferred_jianpin_variant(const base_key_value: string;
        const current_key_value: string; const current_result_count: Integer): Boolean;
    var
        retroflex_pair_count: Integer;
        min_results_before_fallback: Integer;
    begin
        Result := False;
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(base_key_value);
        if retroflex_pair_count <= 0 then
        begin
            Exit;
        end;
        if not is_retroflex_collapsed_fallback_key(base_key_value, current_key_value) then
        begin
            Exit;
        end;
        if is_bare_retroflex_pair_key(base_key_value) then
        begin
            min_results_before_fallback := 8;
        end
        else if Length(base_key_value) <= 4 then
        begin
            min_results_before_fallback := 6;
        end
        else
        begin
            min_results_before_fallback := 12;
        end;
        Result := current_result_count >= min_results_before_fallback;
    end;

    procedure rebuild_query_mode_state;
    var
        query_parser: TncPinyinParser;
        query_syllables: TncPinyinParseResult;
    begin
        mixed_full_prefix := '';
        mixed_jianpin_key := query_key;
        SetLength(mixed_tokens, 0);
        mixed_mode := parse_mixed_jianpin_query(query_key, mixed_full_prefix, mixed_jianpin_key, mixed_tokens);
        if mixed_jianpin_key = '' then
        begin
            mixed_jianpin_key := query_key;
        end;

        effective_jianpin_key := mixed_jianpin_key;
        full_pinyin_query := is_full_pinyin_key(query_key);
        full_query_jianpin_key := '';
        allow_full_query_jianpin_fallback := False;
        full_query_dual_jianpin_mode := False;
        single_syllable_full_query := False;
        full_query_syllable_count := 0;
        disable_long_full_query_jianpin := False;
        full_query_dual_jianpin_cap_score := 0;
        full_query_dual_jianpin_has_cap := False;
        if full_pinyin_query then
        begin
            single_syllable_full_query := is_single_syllable_full_pinyin_key(query_key);
            if single_syllable_full_query then
            begin
                full_query_syllable_count := 1;
            end
            else
            begin
                query_parser := TncPinyinParser.Create;
                try
                    query_syllables := query_parser.parse(query_key);
                finally
                    query_parser.Free;
                end;
                full_query_syllable_count := Length(query_syllables);
                if full_query_syllable_count <= 0 then
                begin
                    full_query_syllable_count := 1;
                end;
            end;
            disable_long_full_query_jianpin := (full_query_syllable_count >= 3);
            full_query_jianpin_key := build_jianpin_key_from_full_pinyin(query_key);
            if (not disable_long_full_query_jianpin) and
                (full_query_jianpin_key <> '') and
                (not SameText(full_query_jianpin_key, query_key)) then
            begin
                effective_jianpin_key := full_query_jianpin_key;
                allow_full_query_jianpin_fallback := True;
            end;

            if single_syllable_full_query and
                (Length(query_key) >= c_full_query_dual_jianpin_len_min) and
                (Length(query_key) <= c_full_query_dual_jianpin_len_max) and
                should_try_jianpin_lookup(query_key) then
            begin
                // For ambiguous keys like "en": keep full-pinyin hits, and also
                // surface common jianpin words under the same key.
                full_query_dual_jianpin_mode := True;
                effective_jianpin_key := query_key;
                allow_full_query_jianpin_fallback := True;
            end;
        end;

        SetLength(jianpin_query_keys, 0);
        append_jianpin_query_key_variants(jianpin_query_keys, effective_jianpin_key, False);
        if Length(jianpin_query_keys) = 0 then
        begin
            add_jianpin_query_key(jianpin_query_keys, effective_jianpin_key);
        end;

        SetLength(matching_jianpin_query_keys, 0);
        append_jianpin_query_key_variants(matching_jianpin_query_keys, effective_jianpin_key, True);
        if Length(matching_jianpin_query_keys) = 0 then
        begin
            add_jianpin_query_key(matching_jianpin_query_keys, effective_jianpin_key);
        end;

        jianpin_score_penalty := c_jianpin_score_penalty;
        if not full_pinyin_query then
        begin
            // For non-full inputs (especially jianpin), do not down-rank jianpin hits.
            jianpin_score_penalty := 0;
        end;

        mixed_like_pattern := '';
        if mixed_mode then
        begin
            mixed_like_pattern := build_mixed_like_pattern(mixed_tokens);
        end;

        force_noisy_reset_before_typo := mixed_mode and
            mixed_query_has_internal_dangling_initial(mixed_tokens);

        user_nonfull_lookup := m_user_ready and (not full_pinyin_query) and should_try_jianpin_lookup(query_key);
        user_like_pattern := '';
        if user_nonfull_lookup then
        begin
            if mixed_mode and (mixed_full_prefix <> '') then
            begin
                user_like_pattern := mixed_full_prefix + '%';
            end
            else
            begin
                user_like_pattern := query_key[1] + '%';
            end;
        end;

        base_jianpin_probe_limit := m_limit;
        if (not full_pinyin_query) and should_try_jianpin_lookup(query_key) then
        begin
            if Length(query_key) <= 2 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 6, 1024);
            end
            else if Length(query_key) = 3 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 4, 768);
            end
            else if Length(query_key) = 4 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 3, 512);
            end
            else if Length(query_key) <= 6 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 2, 384);
            end;

            if (count_retroflex_pairs_in_compact_key(effective_jianpin_key) > 0) and
                (Length(effective_jianpin_key) <= 4) then
            begin
                if Length(effective_jianpin_key) <= 3 then
                begin
                    base_jianpin_probe_limit := Min(base_jianpin_probe_limit, 96);
                end
                else
                begin
                    base_jianpin_probe_limit := Min(base_jianpin_probe_limit, 128);
                end;
            end;
        end;
    end;

    procedure append_candidate(const text: string; const comment: string; const score: Integer;
        const source: TncCandidateSource; const has_dict_weight: Boolean = False;
        const dict_weight: Integer = 0; const candidate_pinyin_key: string = '';
        const max_final_score: Integer = MaxInt);
    begin
        if text = '' then
        begin
            Exit;
        end;
        if not is_windows_supported_ime_text(text) then
        begin
            Exit;
        end;
        if (source = cs_user) and (not is_valid_user_text(text)) then
        begin
            Exit;
        end;

        key := text;
        if seen.ContainsKey(key) then
        begin
            Exit;
        end;

        score_with_bonus := score;
        if learning_bonus_map.TryGetValue(text, learning_bonus) then
        begin
            Inc(score_with_bonus, learning_bonus);
            Inc(applied_learning_bonus_count);
        end;
        if score_with_bonus > max_final_score then
        begin
            score_with_bonus := max_final_score;
        end;

        item.text := text;
        item.comment := comment;
        item.score := score_with_bonus;
        item.source := source;
        item.has_dict_weight := (source = cs_rule) and has_dict_weight;
        item.dict_weight := dict_weight;
        list.Add(item);
        seen.Add(key, True);
        if (candidate_pinyin_key <> '') and (candidate_pinyin_map <> nil) then
        begin
            candidate_pinyin_map.AddOrSetValue(key, candidate_pinyin_key);
        end;
        if (candidate_score_cap_map <> nil) and (max_final_score < MaxInt) then
        begin
            candidate_score_cap_map.AddOrSetValue(key, max_final_score);
        end;
    end;

    procedure apply_short_jianpin_commonness_rerank;
    const
        c_short_jianpin_query_len_max = 3;
        c_short_jianpin_expensive_rerank_limit = 160;
        c_short_jianpin_retroflex_expensive_rerank_limit = 24;
        c_len2_followup_rerank_limit = 40;
        c_len2_prefix_factor = 18.0;
        c_len2_prefix_bonus_cap = 220;
        c_len2_log_weight_factor = 68.0;
        c_len3_log_weight_factor = 88.0;
        c_len2_followup_factor = 20.0;
        c_len3_followup_factor = 28.0;
        c_len2_followup_bonus_cap = 180;
        c_len3_followup_bonus_cap = 200;
        c_exact_syllable_bonus = 18;
        c_len2_constituent_factor = 0.50;
        c_len3_constituent_factor = 0.32;
        c_len2_constituent_bonus_cap = 420;
        c_len3_constituent_bonus_cap = 300;
        c_len2_weak_unit_penalty_floor = 350;
        c_len2_weak_unit_penalty_factor = 3.0;
        c_len2_weak_unit_penalty_cap = 200;
        c_len2_prefix_ratio_penalty_threshold = 2.4;
        c_len2_prefix_ratio_penalty_factor = 92.0;
        c_len2_prefix_ratio_penalty_cap = 180;
    var
        candidate_item: TncCandidate;
        candidate_pinyin_key: string;
        candidate_syllables: TArray<string>;
        candidate_text_units: TArray<string>;
        candidate_unit_count: Integer;
        query_unit_count: Integer;
        idx: Integer;
        followup_score: Integer;
        prefix_score: Integer;
        reranked_score: Integer;
        should_run_expensive_rerank: Boolean;
        len2_followup_indexes: TList<Integer>;
        len2_followup_texts: TArray<string>;
        len2_followup_pinyins: TArray<string>;
        len2_prefix_scores: TDictionary<string, Integer>;
        len2_followup_scores: TDictionary<string, Integer>;
        weight_factor: Double;
        followup_factor: Double;
        followup_bonus_cap: Integer;
        constituent_factor: Double;
        constituent_bonus_cap: Integer;
        constituent_weight_sum: Integer;
        min_constituent_weight: Integer;
        unit_weight_value: Integer;
        unit_idx: Integer;
        expensive_rerank_limit: Integer;
        retroflex_pair_count: Integer;
        prefix_productivity_ratio: Double;
    begin
        if full_pinyin_query or mixed_mode or
            (Length(query_key) < 2) or
            (Length(query_key) > c_short_jianpin_query_len_max) or
            (list.Count <= 1) then
        begin
            Exit;
        end;
        if not should_try_jianpin_lookup(query_key) then
        begin
            Exit;
        end;

        query_unit_count := Length(query_key);
        if query_unit_count <= 0 then
        begin
            Exit;
        end;

        if query_unit_count <= 2 then
        begin
            weight_factor := c_len2_log_weight_factor;
            followup_factor := c_len2_followup_factor;
            followup_bonus_cap := c_len2_followup_bonus_cap;
            constituent_factor := c_len2_constituent_factor;
            constituent_bonus_cap := c_len2_constituent_bonus_cap;
        end
        else
        begin
            weight_factor := c_len3_log_weight_factor;
            followup_factor := c_len3_followup_factor;
            followup_bonus_cap := c_len3_followup_bonus_cap;
            constituent_factor := c_len3_constituent_factor;
            constituent_bonus_cap := c_len3_constituent_bonus_cap;
        end;

        retroflex_pair_count := count_retroflex_pairs_in_compact_key(query_key);
        if retroflex_pair_count > 0 then
        begin
            expensive_rerank_limit := c_short_jianpin_retroflex_expensive_rerank_limit;
        end
        else
        begin
            expensive_rerank_limit := c_short_jianpin_expensive_rerank_limit;
        end;

        len2_followup_indexes := nil;
        if (retroflex_pair_count = 0) and (query_unit_count <= 2) then
        begin
            len2_followup_indexes := TList<Integer>.Create;
        end;
        try
            for idx := 0 to list.Count - 1 do
            begin
                candidate_item := list[idx];
                if (candidate_item.source <> cs_rule) or
                    (candidate_item.comment <> '') or
                    (not candidate_item.has_dict_weight) or
                    (candidate_item.dict_weight <= 0) then
                begin
                    Continue;
                end;

                if (candidate_pinyin_map = nil) or
                    (not candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) then
                begin
                    Continue;
                end;
                if (candidate_pinyin_key = '') or (not is_full_pinyin_key(candidate_pinyin_key)) then
                begin
                    Continue;
                end;

                candidate_unit_count := get_text_unit_count_local(candidate_item.text);
                if candidate_unit_count < 2 then
                begin
                    Continue;
                end;

                reranked_score := Round(Ln(1.0 + candidate_item.dict_weight) * weight_factor);
                candidate_syllables := split_full_pinyin_syllables(candidate_pinyin_key);
                if Length(candidate_syllables) <= 0 then
                begin
                    candidate_item.score := reranked_score;
                    list[idx] := candidate_item;
                    Continue;
                end;

                if Length(candidate_syllables) = query_unit_count then
                begin
                    Inc(reranked_score, c_exact_syllable_bonus);
                end;

                if (candidate_unit_count = query_unit_count) and
                    (Length(candidate_syllables) = candidate_unit_count) then
                begin
                    candidate_text_units := split_text_units_local(Trim(candidate_item.text));
                    if Length(candidate_text_units) = candidate_unit_count then
                    begin
                        constituent_weight_sum := 0;
                        min_constituent_weight := MaxInt;
                        for unit_idx := 0 to candidate_unit_count - 1 do
                        begin
                            unit_weight_value := get_single_char_exact_weight(candidate_syllables[unit_idx],
                                candidate_text_units[unit_idx]);
                            Inc(constituent_weight_sum, unit_weight_value);
                            if unit_weight_value < min_constituent_weight then
                            begin
                                min_constituent_weight := unit_weight_value;
                            end;
                        end;
                        if constituent_weight_sum > 0 then
                        begin
                            Inc(reranked_score, Min(constituent_bonus_cap,
                                Round(constituent_weight_sum * constituent_factor)));
                        end;
                        if (query_unit_count <= 2) and (min_constituent_weight <> MaxInt) and
                            (min_constituent_weight < c_len2_weak_unit_penalty_floor) then
                        begin
                            Dec(reranked_score, Min(c_len2_weak_unit_penalty_cap,
                                Round((c_len2_weak_unit_penalty_floor - min_constituent_weight) *
                                    c_len2_weak_unit_penalty_factor)));
                        end;
                    end;
                end;

                candidate_item.score := reranked_score;
                list[idx] := candidate_item;

                if len2_followup_indexes <> nil then
                begin
                    if Length(candidate_syllables) = query_unit_count then
                    begin
                        len2_followup_indexes.Add(idx);
                    end;
                    Continue;
                end;

                should_run_expensive_rerank := idx < expensive_rerank_limit;
                if not should_run_expensive_rerank then
                begin
                    Continue;
                end;

                followup_score := get_pinyin_followup_popularity_score(candidate_pinyin_key);
                if followup_score > 0 then
                begin
                    Inc(candidate_item.score, Min(followup_bonus_cap,
                        Round(Ln(1.0 + followup_score) * followup_factor)));
                    list[idx] := candidate_item;
                end;
            end;

            if (len2_followup_indexes <> nil) and (len2_followup_indexes.Count > 1) then
            begin
                len2_followup_indexes.Sort(TComparer<Integer>.Construct(
                    function(const left, right: Integer): Integer
                    begin
                        Result := list[right].score - list[left].score;
                        if Result <> 0 then
                        begin
                            Exit;
                        end;
                        Result := left - right;
                    end));
            end;

            if len2_followup_indexes <> nil then
            begin
                SetLength(len2_followup_texts, Min(c_len2_followup_rerank_limit, len2_followup_indexes.Count));
                SetLength(len2_followup_pinyins, Length(len2_followup_texts));
                for idx := 0 to High(len2_followup_texts) do
                begin
                    candidate_item := list[len2_followup_indexes[idx]];
                    len2_followup_texts[idx] := candidate_item.text;
                    if (candidate_pinyin_map <> nil) and
                        candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key) then
                    begin
                        len2_followup_pinyins[idx] := candidate_pinyin_key;
                    end
                    else
                    begin
                        len2_followup_pinyins[idx] := '';
                    end;
                end;

                len2_prefix_scores := TDictionary<string, Integer>.Create;
                len2_followup_scores := TDictionary<string, Integer>.Create;
                try
                    populate_prefix_popularity_scores(len2_followup_texts, len2_prefix_scores);
                    populate_pinyin_followup_popularity_scores(len2_followup_pinyins, len2_followup_scores);

                    for idx := 0 to High(len2_followup_texts) do
                    begin
                        candidate_item := list[len2_followup_indexes[idx]];
                        if len2_prefix_scores.TryGetValue(candidate_item.text, prefix_score) and
                            (prefix_score > 0) then
                        begin
                            Inc(candidate_item.score, Min(c_len2_prefix_bonus_cap,
                                Round(Ln(1.0 + prefix_score) * c_len2_prefix_factor)));
                            if candidate_item.dict_weight > 0 then
                            begin
                                prefix_productivity_ratio := prefix_score / candidate_item.dict_weight;
                                if prefix_productivity_ratio > c_len2_prefix_ratio_penalty_threshold then
                                begin
                                    Dec(candidate_item.score, Min(c_len2_prefix_ratio_penalty_cap,
                                        Round(Ln(prefix_productivity_ratio /
                                            c_len2_prefix_ratio_penalty_threshold) *
                                            c_len2_prefix_ratio_penalty_factor)));
                                end;
                            end;
                        end;

                        if len2_followup_scores.TryGetValue(len2_followup_pinyins[idx], followup_score) and
                            (followup_score > 0) then
                        begin
                            Inc(candidate_item.score, Min(followup_bonus_cap,
                                Round(Ln(1.0 + followup_score) * followup_factor)));
                        end;
                        list[len2_followup_indexes[idx]] := candidate_item;
                    end;
                finally
                    len2_followup_scores.Free;
                    len2_prefix_scores.Free;
                end;
            end;
        finally
            if len2_followup_indexes <> nil then
            begin
                len2_followup_indexes.Free;
            end;
        end;
    end;

    procedure sort_candidate_list_by_score;
    begin
        if list.Count <= 1 then
        begin
            Exit;
        end;

        list.Sort(TComparer<TncCandidate>.Construct(
            function(const left, right: TncCandidate): Integer
            begin
                Result := right.score - left.score;
                if Result <> 0 then
                begin
                    Exit;
                end;

                case left.source of
                    cs_user:
                        Result := 0;
                    cs_rule:
                        Result := 1;
                else
                    Result := 2;
                end;
                case right.source of
                    cs_user:
                        Dec(Result, 0);
                    cs_rule:
                        Dec(Result, 1);
                else
                    Dec(Result, 2);
                end;
                if Result <> 0 then
                begin
                    Exit;
                end;

                if (left.comment = '') and (right.comment <> '') then
                begin
                    Result := -1;
                    Exit;
                end;
                if (right.comment = '') and (left.comment <> '') then
                begin
                    Result := 1;
                    Exit;
                end;

                Result := Length(left.text) - Length(right.text);
                if Result <> 0 then
                begin
                    Exit;
                end;

                Result := CompareText(left.text, right.text);
                if Result <> 0 then
                begin
                    Exit;
                end;

                Result := CompareText(left.comment, right.comment);
            end));
    end;

    procedure apply_text_learning_bonus;
    var
        bonus_value: Integer;
        candidate_item: TncCandidate;
        idx: Integer;
        stmt_text_stats: Psqlite3_stmt;
        text_commit_count: Integer;
        text_last_used_value: Int64;
        text_step_result: Integer;
    begin
        if (not m_user_ready) or (list.Count <= 0) then
        begin
            Exit;
        end;

        stmt_text_stats := nil;
        try
            if not m_user_connection.prepare(text_stats_sql, stmt_text_stats) then
            begin
                Exit;
            end;

            for idx := 0 to list.Count - 1 do
            begin
                candidate_item := list[idx];
                if (candidate_item.text = '') or (candidate_item.source <> cs_rule) then
                begin
                    Continue;
                end;
                if learning_bonus_map.ContainsKey(candidate_item.text) then
                begin
                    Continue;
                end;

                if not text_learning_bonus_cache.TryGetValue(candidate_item.text, bonus_value) then
                begin
                    bonus_value := 0;
                    if m_user_connection.bind_text(stmt_text_stats, 1, candidate_item.text) then
                    begin
                        text_step_result := m_user_connection.step(stmt_text_stats);
                        if text_step_result = SQLITE_ROW then
                        begin
                            text_commit_count := m_user_connection.column_int(stmt_text_stats, 0);
                            text_last_used_value := m_user_connection.column_int(stmt_text_stats, 1);
                            bonus_value := calc_text_learning_bonus(
                                text_commit_count,
                                text_last_used_value,
                                now_unix);
                        end;
                    end;
                    m_user_connection.reset(stmt_text_stats);
                    m_user_connection.clear_bindings(stmt_text_stats);
                    text_learning_bonus_cache.AddOrSetValue(candidate_item.text, bonus_value);
                end;

                if bonus_value <= 0 then
                begin
                    Continue;
                end;

                if candidate_item.comment <> '' then
                begin
                    bonus_value := bonus_value div 2;
                end;
                if bonus_value <= 0 then
                begin
                    Continue;
                end;

                candidate_item.score := candidate_item.score + bonus_value;
                if candidate_score_cap_map.TryGetValue(candidate_item.text, candidate_score_cap) and
                    (candidate_item.score > candidate_score_cap) then
                begin
                    candidate_item.score := candidate_score_cap;
                end;
                list[idx] := candidate_item;
                Inc(applied_text_learning_bonus_count);
            end;
        finally
            if stmt_text_stats <> nil then
            begin
                m_user_connection.finalize(stmt_text_stats);
            end;
        end;
    end;

    function get_single_letter_full_query_spoken_bonus(const text_value_local: string): Integer;
    begin
        Result := 0;
        if (not single_letter_query) or (Length(query_key) <> 1) or (text_value_local = '') then
        begin
            Exit;
        end;

        case query_key[1] of
            'a':
                begin
                    if text_value_local = string(Char($554A)) then      // 啊
                    begin
                        Result := 220;
                    end
                    else if text_value_local = string(Char($963F)) then // 阿
                    begin
                        Result := 80;
                    end
                    else if text_value_local = string(Char($5475)) then // 呵
                    begin
                        Result := 60;
                    end
                    else if text_value_local = string(Char($5416)) then // 吖
                    begin
                        Result := 40;
                    end;
                end;
            'e':
                begin
                    if text_value_local = string(Char($5443)) then      // 呃
                    begin
                        Result := 240;
                    end
                    else if text_value_local = string(Char($8BE6)) then // 诶
                    begin
                        Result := 180;
                    end
                    else if text_value_local = string(Char($6B38)) then // 欸
                    begin
                        Result := 160;
                    end
                    else if text_value_local = string(Char($997F)) then // 饿
                    begin
                        Result := 80;
                    end
                    else if text_value_local = string(Char($54E6)) then // 哦
                    begin
                        Result := 60;
                    end;
                end;
            'o':
                begin
                    if text_value_local = string(Char($54E6)) then      // 哦
                    begin
                        Result := 240;
                    end
                    else if text_value_local = string(Char($5662)) then // 噢
                    begin
                        Result := 220;
                    end
                    else if text_value_local = string(Char($5594)) then // 喔
                    begin
                        Result := 160;
                    end;
                end;
        end;
    end;

    procedure apply_single_letter_full_query_standalone_rerank;
    const
        c_prefix_penalty_factor = 20.0;
        c_prefix_penalty_cap = 140;
    var
        candidate_item: TncCandidate;
        idx: Integer;
        prefix_score: Integer;
        penalty_value: Integer;
        text_value_local: string;
    begin
        if (not full_pinyin_query) or (not single_letter_query) or (list.Count <= 1) then
        begin
            Exit;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if (candidate_item.source <> cs_rule) or (candidate_item.comment <> '') then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            prefix_score := get_prefix_popularity_score(text_value_local);
            if prefix_score <= 0 then
            begin
                Continue;
            end;

            penalty_value := Round(Ln(1.0 + prefix_score) * c_prefix_penalty_factor);
            if penalty_value > c_prefix_penalty_cap then
            begin
                penalty_value := c_prefix_penalty_cap;
            end;
            if penalty_value <= 0 then
            begin
                Continue;
            end;

            Dec(candidate_item.score, penalty_value);
            list[idx] := candidate_item;
        end;
    end;

    procedure apply_single_letter_full_query_spoken_bonus;
    var
        candidate_item: TncCandidate;
        idx: Integer;
        spoken_bonus: Integer;
        text_value_local: string;
    begin
        if (not full_pinyin_query) or (not single_letter_query) or (list.Count <= 1) then
        begin
            Exit;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if (candidate_item.source <> cs_rule) or (candidate_item.comment <> '') then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            spoken_bonus := get_single_letter_full_query_spoken_bonus(text_value_local);
            if spoken_bonus <= 0 then
            begin
                Continue;
            end;

            Inc(candidate_item.score, spoken_bonus);
            list[idx] := candidate_item;
        end;
    end;

    procedure enforce_single_letter_exact_group_priority;
    var
        candidate_item: TncCandidate;
        idx: Integer;
        exact_group_floor: Integer;
        candidate_pinyin_key: string;
        text_value_local: string;
        has_exact_group: Boolean;
    begin
        if (not full_pinyin_query) or (not single_letter_query) or (list.Count <= 1) or
            (candidate_pinyin_map = nil) then
        begin
            Exit;
        end;

        exact_group_floor := MaxInt;
        has_exact_group := False;
        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if candidate_item.comment <> '' then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            if (not candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) or
                (not SameText(candidate_pinyin_key, query_key)) then
            begin
                Continue;
            end;

            has_exact_group := True;
            if candidate_item.score < exact_group_floor then
            begin
                exact_group_floor := candidate_item.score;
            end;
        end;

        if (not has_exact_group) or (exact_group_floor = MaxInt) then
        begin
            Exit;
        end;

        Dec(exact_group_floor);
        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if candidate_item.comment <> '' then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            if (candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) and
                SameText(candidate_pinyin_key, query_key) then
            begin
                Continue;
            end;

            if candidate_item.score > exact_group_floor then
            begin
                candidate_item.score := exact_group_floor;
                list[idx] := candidate_item;
            end;
        end;
    end;

    procedure apply_candidate_score_caps;
    var
        candidate_item: TncCandidate;
        idx: Integer;
    begin
        if (candidate_score_cap_map = nil) or (candidate_score_cap_map.Count <= 0) then
        begin
            Exit;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if candidate_score_cap_map.TryGetValue(candidate_item.text, candidate_score_cap) and
                (candidate_item.score > candidate_score_cap) then
            begin
                candidate_item.score := candidate_score_cap;
                list[idx] := candidate_item;
            end;
        end;
    end;

    procedure append_learned_exact_base_candidates;
    var
        learned_stmt: Psqlite3_stmt;
        learned_pair: TPair<string, Integer>;
        learned_text: string;
        learned_comment: string;
        learned_weight: Integer;
        learned_step_result: Integer;
    begin
        if (not full_pinyin_query) or (not m_base_ready) or (learning_bonus_map.Count <= 0) then
        begin
            Exit;
        end;

        learned_stmt := nil;
        try
            if not m_base_connection.prepare(base_exact_entry_sql, learned_stmt) then
            begin
                Exit;
            end;

            for learned_pair in learning_bonus_map do
            begin
                if seen.ContainsKey(learned_pair.Key) then
                begin
                    Continue;
                end;

                if not m_base_connection.bind_text(learned_stmt, 1, query_key) or
                    not m_base_connection.bind_text(learned_stmt, 2, learned_pair.Key) then
                begin
                    m_base_connection.reset(learned_stmt);
                    m_base_connection.clear_bindings(learned_stmt);
                    Continue;
                end;

                learned_step_result := m_base_connection.step(learned_stmt);
                if learned_step_result = SQLITE_ROW then
                begin
                    learned_text := m_base_connection.column_text(learned_stmt, 1);
                    learned_comment := m_base_connection.column_text(learned_stmt, 2);
                    learned_weight := m_base_connection.column_int(learned_stmt, 3);
                    append_candidate(learned_text, learned_comment, learned_weight, cs_rule, True,
                        learned_weight, query_key);
                    exact_base_hit := True;
                    Inc(injected_learned_base_count);
                end;

                m_base_connection.reset(learned_stmt);
                m_base_connection.clear_bindings(learned_stmt);
            end;
        finally
            if learned_stmt <> nil then
            begin
                m_base_connection.finalize(learned_stmt);
            end;
        end;
    end;

    procedure apply_homophone_commonness_bonus;
    const
        c_single_char_factor = 190.0;
        c_single_char_min_base_score = 260;
        c_single_prefix_metric_weight = 0.05;
        c_phrase_factor = 1400.0;
        c_phrase_bonus_cap = 2200;
    var
        metrics: TArray<Double>;
        unit_counts: TArray<Integer>;
        candidate_item: TncCandidate;
        has_single: Boolean;
        has_phrase: Boolean;
        min_single: Double;
        min_phrase: Double;
        metric: Double;
        delta: Double;
        bonus: Integer;
        text_value_local: string;
        idx: Integer;
        prefix_two_units: string;
    begin
        if (not full_pinyin_query) or (list.Count <= 1) then
        begin
            Exit;
        end;

        SetLength(metrics, list.Count);
        SetLength(unit_counts, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            metrics[idx] := -1.0;
            unit_counts[idx] := 0;
        end;

        has_single := False;
        has_phrase := False;
        min_single := 0.0;
        min_phrase := 0.0;

        for idx := 0 to list.Count - 1 do
        begin
            if list[idx].source <> cs_rule then
            begin
                Continue;
            end;
            if list[idx].comment <> '' then
            begin
                Continue;
            end;

            text_value_local := Trim(list[idx].text);
            if text_value_local = '' then
            begin
                Continue;
            end;

            unit_counts[idx] := get_text_unit_count_local(text_value_local);
            if unit_counts[idx] <= 0 then
            begin
                Continue;
            end;

            if unit_counts[idx] = 1 then
            begin
                if list[idx].score < c_single_char_min_base_score then
                begin
                    Continue;
                end;

                metric := Ln(1.0 + get_contains_popularity_score(text_value_local)) +
                    (Ln(1.0 + get_prefix_popularity_score(text_value_local)) *
                    c_single_prefix_metric_weight);
                metrics[idx] := metric;
                if not has_single or (metric < min_single) then
                begin
                    min_single := metric;
                    has_single := True;
                end;
            end
            else
            begin
                prefix_two_units := copy_first_text_units(text_value_local, 2);
                if prefix_two_units = '' then
                begin
                    Continue;
                end;

                metric := Ln(1.0 + get_prefix_popularity_score(prefix_two_units));
                metrics[idx] := metric;

                if not has_phrase or (metric < min_phrase) then
                begin
                    min_phrase := metric;
                    has_phrase := True;
                end;
            end;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            if metrics[idx] < 0 then
            begin
                Continue;
            end;

            if unit_counts[idx] = 1 then
            begin
                if not has_single then
                begin
                    Continue;
                end;
                delta := metrics[idx] - min_single;
                if delta <= 0 then
                begin
                    Continue;
                end;
                bonus := Round(delta * c_single_char_factor);
            end
            else
            begin
                if not has_phrase then
                begin
                    Continue;
                end;
                delta := metrics[idx] - min_phrase;
                if delta <= 0 then
                begin
                    Continue;
                end;
                bonus := Round(delta * c_phrase_factor);
                if bonus > c_phrase_bonus_cap then
                begin
                    bonus := c_phrase_bonus_cap;
                end;
            end;

            candidate_item := list[idx];
            candidate_item.score := candidate_item.score + bonus;
            list[idx] := candidate_item;
        end;
    end;

    function build_mixed_like_pattern(const token_list: TncMixedQueryTokenList): string;
    var
        pattern_idx: Integer;
    begin
        Result := '';
        if Length(token_list) = 0 then
        begin
            Exit;
        end;

        for pattern_idx := 0 to High(token_list) do
        begin
            if token_list[pattern_idx].text = '' then
            begin
                Continue;
            end;

            if token_list[pattern_idx].kind = mqt_full then
            begin
                Result := Result + token_list[pattern_idx].text;
            end
            else
            begin
                Result := Result + token_list[pattern_idx].text + '%';
            end;
        end;

        if Result <> '' then
        begin
            Result := Result + '%';
        end;
    end;

    function is_compact_ascii_query(const value: string): Boolean;
    var
        value_idx: Integer;
    begin
        Result := value <> '';
        if not Result then
        begin
            Exit;
        end;

        for value_idx := 1 to Length(value) do
        begin
            if not CharInSet(value[value_idx], ['a' .. 'z']) then
            begin
                Result := False;
                Exit;
            end;
        end;
    end;

    function append_adjacent_transposition_typo_candidates: Boolean;
    var
        swap_idx: Integer;
        swap_key: string;
        typo_stmt: Psqlite3_stmt;
        prefix_stmt: Psqlite3_stmt;
        swap_seen: TDictionary<string, Boolean>;
        before_count: Integer;
        before_swap_added: Integer;
        typo_added: Integer;
        swap_char: Char;
        existing_idx: Integer;
        has_user_existing: Boolean;
        typo_min_query_len: Integer;
    begin
        Result := False;
        if not m_base_ready then
        begin
            Exit;
        end;
        // Keep strict exact-match priority only for full-pinyin queries.
        // Non-full inputs may still be user typos (e.g. "chagn" -> "chang").
        if exact_base_hit and full_pinyin_query then
        begin
            Exit;
        end;
        // Adjacent-swap typo recovery is intentionally limited to malformed/non-full
        // inputs. For valid full-pinyin keys like "zuoshen", forcing swapped exact
        // words such as "zoushen" is more harmful than helpful.
        if full_pinyin_query then
        begin
            Exit;
        end
        else
        begin
            typo_min_query_len := c_typo_min_query_len_nonfull;
        end;
        if Length(query_key) < typo_min_query_len then
        begin
            Exit;
        end;
        if not is_compact_ascii_query(query_key) then
        begin
            Exit;
        end;
        if (not full_pinyin_query) and (not mixed_mode) and (Length(query_key) <= 6) and
            (list.Count > 0) then
        begin
            // Keep short non-full inputs conservative: if they already produced
            // direct results, avoid over-eager adjacent-swap typo recovery.
            Exit;
        end;

        // Mixed/non-full probing may already have filled list with noisy rule candidates.
        // If no user hit is present, clear them so transposition recovery can surface.
        if (not full_pinyin_query) and (list.Count > 0) then
        begin
            if force_noisy_reset_before_typo then
            begin
                list.Clear;
                seen.Clear;
                candidate_pinyin_map.Clear;
            end
            else
            begin
                has_user_existing := False;
                for existing_idx := 0 to list.Count - 1 do
                begin
                    if list[existing_idx].source = cs_user then
                    begin
                        has_user_existing := True;
                        Break;
                    end;
                end;

                if not has_user_existing then
                begin
                    list.Clear;
                    seen.Clear;
                    candidate_pinyin_map.Clear;
                end;
            end;
        end;

        swap_seen := TDictionary<string, Boolean>.Create;
        try
            typo_added := 0;
            for swap_idx := 1 to Length(query_key) - 1 do
            begin
                if query_key[swap_idx] = query_key[swap_idx + 1] then
                begin
                    Continue;
                end;

                swap_key := query_key;
                swap_char := swap_key[swap_idx];
                swap_key[swap_idx] := swap_key[swap_idx + 1];
                swap_key[swap_idx + 1] := swap_char;

                if swap_seen.ContainsKey(swap_key) then
                begin
                    Continue;
                end;
                swap_seen.Add(swap_key, True);

                if not is_full_pinyin_key(swap_key) then
                begin
                    Continue;
                end;

                before_swap_added := typo_added;
                typo_stmt := nil;
                try
                    if m_base_connection.prepare(base_sql, typo_stmt) and
                        m_base_connection.bind_text(typo_stmt, 1, swap_key) and
                        m_base_connection.bind_int(typo_stmt, 2, c_typo_probe_limit) then
                    begin
                        step_result := m_base_connection.step(typo_stmt);
                        while step_result = SQLITE_ROW do
                        begin
                            text_value := m_base_connection.column_text(typo_stmt, 1);
                            comment_value := m_base_connection.column_text(typo_stmt, 2);
                            dict_weight_value := m_base_connection.column_int(typo_stmt, 3);
                            score_value := dict_weight_value - c_typo_transpose_penalty;
                            before_count := list.Count;
                            append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                dict_weight_value, swap_key);
                            if list.Count > before_count then
                            begin
                                Inc(typo_added);
                                if typo_added >= c_typo_max_added then
                                begin
                                    Break;
                                end;
                            end;
                            step_result := m_base_connection.step(typo_stmt);
                        end;
                    end;
                finally
                    if typo_stmt <> nil then
                    begin
                        m_base_connection.finalize(typo_stmt);
                    end;
                end;

                // If exact swapped-key rows are absent, probe a small prefix window
                // (e.g. "chang%") so typo correction still surfaces meaningful heads.
                if (((full_pinyin_query and (Length(swap_key) >= c_typo_prefix_min_query_len_full)) or
                    ((not full_pinyin_query) and (Length(swap_key) >= c_typo_prefix_min_query_len_nonfull))) and
                    (typo_added = before_swap_added)) then
                begin
                    prefix_stmt := nil;
                    try
                        if m_base_connection.prepare(base_typo_prefix_sql, prefix_stmt) and
                            m_base_connection.bind_text(prefix_stmt, 1, swap_key + '%') and
                            m_base_connection.bind_int(prefix_stmt, 2, c_typo_prefix_probe_limit) then
                        begin
                            step_result := m_base_connection.step(prefix_stmt);
                            while step_result = SQLITE_ROW do
                            begin
                                text_value := m_base_connection.column_text(prefix_stmt, 1);
                                comment_value := m_base_connection.column_text(prefix_stmt, 2);
                                dict_weight_value := m_base_connection.column_int(prefix_stmt, 3);
                                score_value := dict_weight_value -
                                    c_typo_transpose_penalty - c_typo_prefix_extra_penalty;
                                before_count := list.Count;
                                append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                    dict_weight_value, swap_key);
                                if list.Count > before_count then
                                begin
                                    Inc(typo_added);
                                    if typo_added >= c_typo_max_added then
                                    begin
                                        Break;
                                    end;
                                end;
                                step_result := m_base_connection.step(prefix_stmt);
                            end;
                        end;
                    finally
                        if prefix_stmt <> nil then
                        begin
                            m_base_connection.finalize(prefix_stmt);
                        end;
                    end;
                end;

                if typo_added >= c_typo_max_added then
                begin
                    Break;
                end;
            end;
            Result := typo_added > 0;
        finally
            swap_seen.Free;
        end;
    end;
begin
    SetLength(results, 0);
    m_last_lookup_debug_hint := '';
    applied_learning_bonus_count := 0;
    applied_text_learning_bonus_count := 0;
    skipped_single_char_mismatch_count := 0;
    skipped_noisy_user_count := 0;
    skipped_base_dup_user_count := 0;
    injected_learned_base_count := 0;
    single_letter_cap_score := 0;
    single_letter_has_cap := False;
    if (pinyin = '') or not ensure_open then
    begin
        Result := False;
        Exit;
    end;
    query_key := LowerCase(pinyin);
    now_unix := get_unix_time_now;
    rebuild_query_mode_state;

    // For compact malformed inputs like "chagn", prefer a deterministic
    // adjacent-swap normalization to full pinyin (e.g. "chang") before lookup.
    // Apply this to all non-full queries (not only mixed dangling-initial cases)
    // so common adjacent transposition typos are corrected earlier and stably.
    if not full_pinyin_query then
    begin
        normalized_query_key := normalize_adjacent_swap_to_full_pinyin(query_key);
        if (normalized_query_key <> '') and (not SameText(normalized_query_key, query_key)) then
        begin
            query_key := normalized_query_key;
            rebuild_query_mode_state;
        end;
    end;

    single_letter_query := (Length(query_key) = 1) and CharInSet(query_key[1], ['a' .. 'z']);

    if mixed_mode or user_nonfull_lookup then
    begin
        mixed_parser := TncPinyinParser.create;
    end
    else
    begin
        mixed_parser := nil;
    end;

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Boolean>.Create;
    candidate_pinyin_map := TDictionary<string, string>.Create;
    candidate_score_cap_map := TDictionary<string, Integer>.Create;
    learning_bonus_map := TDictionary<string, Integer>.Create;
    text_learning_bonus_cache := TDictionary<string, Integer>.Create;
    exact_base_hit := False;
    typo_fallback_used := False;
    try
        if m_user_ready then
        begin
            stmt := nil;
            try
                if m_user_connection.prepare(stats_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, query_key) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        text_value := m_user_connection.column_text(stmt, 0);
                        commit_count := m_user_connection.column_int(stmt, 1);
                        last_used_value := m_user_connection.column_int(stmt, 2);
                        if full_pinyin_query and
                            (get_valid_cjk_codepoint_count(text_value) = 1) and
                            (not single_char_matches_pinyin(query_key, text_value)) then
                        begin
                            Inc(skipped_single_char_mismatch_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if should_suppress_constructed_user_phrase(query_key, text_value, commit_count, 0) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if is_likely_noisy_constructed_phrase(query_key, text_value, commit_count, 0) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        learning_bonus := calc_learning_bonus(commit_count, last_used_value, now_unix);
                        if (text_value <> '') and (learning_bonus > 0) then
                        begin
                            learning_bonus_map.AddOrSetValue(text_value, learning_bonus);
                        end;
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;

        if m_user_ready and full_pinyin_query then
        begin
            stmt := nil;
            try
                if m_user_connection.prepare(user_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, query_key) and
                    m_user_connection.bind_int(stmt, 2, m_limit) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        text_value := m_user_connection.column_text(stmt, 0);
                        last_used_value := m_user_connection.column_int(stmt, 2);
                        if full_pinyin_query and
                            (get_valid_cjk_codepoint_count(text_value) = 1) and
                            (not single_char_matches_pinyin(query_key, text_value)) then
                        begin
                            Inc(skipped_single_char_mismatch_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if normalized_base_entry_exists(query_key, text_value) then
                        begin
                            Inc(skipped_base_dup_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        score_value := m_user_connection.column_int(stmt, 1);
                        if should_suppress_constructed_user_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if (last_used_value <= 0) and
                            is_likely_noisy_constructed_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        append_candidate(text_value, '', score_value, cs_user, False, 0, query_key);
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;

        if user_nonfull_lookup then
        begin
            user_probe_limit := Max(m_limit * 8, m_limit);
            stmt := nil;
            try
                if m_user_connection.prepare(user_nonfull_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, user_like_pattern) and
                    m_user_connection.bind_int(stmt, 2, user_probe_limit) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_user_connection.column_text(stmt, 0);
                        if mixed_mode then
                        begin
                            if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_tokens) then
                            begin
                                step_result := m_user_connection.step(stmt);
                                Continue;
                            end;
                        end
                        else if not candidate_matches_any_jianpin_key(mixed_parser, candidate_pinyin,
                            matching_jianpin_query_keys) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_user_connection.column_text(stmt, 1);
                        score_value := m_user_connection.column_int(stmt, 2);
                        last_used_value := m_user_connection.column_int(stmt, 3);
                        if normalized_base_entry_exists(candidate_pinyin, text_value) then
                        begin
                            Inc(skipped_base_dup_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if should_suppress_constructed_user_phrase(candidate_pinyin, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if (last_used_value <= 0) and
                            is_likely_noisy_constructed_phrase(candidate_pinyin, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        append_candidate(text_value, '', score_value, cs_user, False, 0, candidate_pinyin);
                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;

        if m_base_ready then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, query_key) and
                    m_base_connection.bind_int(stmt, 2, m_limit) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        if mixed_mode and SameText(candidate_pinyin, query_key) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        if mixed_mode and (not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin,
                            mixed_tokens)) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value;
                        if not full_pinyin_query then
                        begin
                            // Non-full exact pinyin rows are often noisy; let jianpin candidates lead.
                            Dec(score_value, c_nonfull_exact_penalty);
                        end;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin,
                            IfThen((full_pinyin_query and single_letter_has_cap), single_letter_cap_score, MaxInt));
                        exact_base_hit := True;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;

            // Single-syllable full pinyin queries (e.g. "hai") are used by segment fallback;
            // probe extra exact single-char rows so common characters are not dropped by strict LIMIT.
            if single_syllable_full_query then
            begin
                // Keep a wide probe window for one-syllable inputs so common single-char
                // fallbacks (for segment composition) are not starved by phrase-heavy rows.
                single_char_probe_limit := Max(m_limit * 24, 256);
                if single_char_probe_limit > 512 then
                begin
                    single_char_probe_limit := 512;
                end;

                stmt := nil;
                try
                    if m_base_connection.prepare(base_single_char_exact_sql, stmt) and
                        m_base_connection.bind_text(stmt, 1, query_key) and
                        m_base_connection.bind_int(stmt, 2, single_char_probe_limit) then
                    begin
                        step_result := m_base_connection.step(stmt);
                        while step_result = SQLITE_ROW do
                        begin
                            text_value := m_base_connection.column_text(stmt, 1);
                            comment_value := m_base_connection.column_text(stmt, 2);
                            dict_weight_value := m_base_connection.column_int(stmt, 3);
                            score_value := dict_weight_value;
                            append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                dict_weight_value, query_key);
                            step_result := m_base_connection.step(stmt);
                        end;
                    end;
                finally
                    if stmt <> nil then
                    begin
                        m_base_connection.finalize(stmt);
                    end;
                end;
            end;
        end;

        append_learned_exact_base_candidates;

        if full_query_dual_jianpin_mode and (list.Count > 0) then
        begin
            full_query_dual_jianpin_cap_score := list[0].score - 1;
            for i := 1 to list.Count - 1 do
            begin
                if list[i].score - 1 < full_query_dual_jianpin_cap_score then
                begin
                    full_query_dual_jianpin_cap_score := list[i].score - 1;
                end;
            end;
            full_query_dual_jianpin_has_cap := True;
        end;

        if m_base_ready and should_try_jianpin_lookup(effective_jianpin_key) and
            ((not disable_long_full_query_jianpin) or allow_full_query_jianpin_fallback) and
            ((list.Count = 0) or mixed_mode or (not full_pinyin_query) or
            full_query_dual_jianpin_mode or
            allow_full_query_jianpin_fallback) then
        begin
            typo_fallback_used := append_adjacent_transposition_typo_candidates;
            if (not typo_fallback_used) and mixed_mode and (mixed_full_prefix <> '') then
            begin
                for query_key_idx := 0 to High(jianpin_query_keys) do
                begin
                    if jianpin_query_keys[query_key_idx] = '' then
                    begin
                        Continue;
                    end;
                    if should_skip_deferred_jianpin_variant(effective_jianpin_key,
                        jianpin_query_keys[query_key_idx], list.Count) then
                    begin
                        Continue;
                    end;
                    stmt := nil;
                    try
                        if m_base_connection.prepare(base_jianpin_prefixed_sql, stmt) and
                            m_base_connection.bind_text(stmt, 1, jianpin_query_keys[query_key_idx]) and
                            m_base_connection.bind_int(stmt, 2,
                                get_jianpin_inner_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx], True)) and
                            m_base_connection.bind_text(stmt, 3, mixed_full_prefix + '%') and
                            m_base_connection.bind_int(stmt, 4,
                                get_jianpin_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx])) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            while step_result = SQLITE_ROW do
                            begin
                                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                                if mixed_mode and SameText(candidate_pinyin, query_key) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_tokens) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;
                                if full_pinyin_query and (not full_query_dual_jianpin_mode) and
                                    (not same_normalized_pinyin_key(candidate_pinyin, query_key)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                text_value := m_base_connection.column_text(stmt, 1);
                                comment_value := m_base_connection.column_text(stmt, 2);
                                dict_weight_value := m_base_connection.column_int(stmt, 3);
                                score_value := dict_weight_value - jianpin_score_penalty;
                                if full_query_dual_jianpin_mode and
                                    (not same_normalized_pinyin_key(candidate_pinyin, query_key)) then
                                begin
                                    Dec(score_value, c_full_query_dual_jianpin_penalty);
                                    if full_query_dual_jianpin_has_cap and
                                        (score_value > full_query_dual_jianpin_cap_score) then
                                    begin
                                        score_value := full_query_dual_jianpin_cap_score;
                                    end;
                                end;
                                append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                    dict_weight_value, candidate_pinyin);
                                step_result := m_base_connection.step(stmt);
                            end;
                        end;
                    finally
                        if stmt <> nil then
                        begin
                            m_base_connection.finalize(stmt);
                        end;
                    end;
                end;
            end;

            if (not typo_fallback_used) and ((list.Count = 0) or (not full_pinyin_query) or
                allow_full_query_jianpin_fallback) then
            begin
                for query_key_idx := 0 to High(jianpin_query_keys) do
                begin
                    if jianpin_query_keys[query_key_idx] = '' then
                    begin
                        Continue;
                    end;
                    if should_skip_deferred_jianpin_variant(effective_jianpin_key,
                        jianpin_query_keys[query_key_idx], list.Count) then
                    begin
                        Continue;
                    end;
                    stmt := nil;
                    try
                        if m_base_connection.prepare(base_jianpin_sql, stmt) and
                            m_base_connection.bind_text(stmt, 1, jianpin_query_keys[query_key_idx]) and
                            m_base_connection.bind_int(stmt, 2,
                                get_jianpin_inner_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx], False)) and
                            m_base_connection.bind_int(stmt, 3,
                                get_jianpin_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx])) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            while step_result = SQLITE_ROW do
                            begin
                                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                                if mixed_mode and SameText(candidate_pinyin, query_key) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                if mixed_mode and (not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin,
                                    mixed_tokens)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;
                                if full_pinyin_query and (not full_query_dual_jianpin_mode) and
                                    (not same_normalized_pinyin_key(candidate_pinyin, query_key)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                text_value := m_base_connection.column_text(stmt, 1);
                                comment_value := m_base_connection.column_text(stmt, 2);
                                dict_weight_value := m_base_connection.column_int(stmt, 3);
                                score_value := dict_weight_value - jianpin_score_penalty;
                                if full_query_dual_jianpin_mode and
                                    (not same_normalized_pinyin_key(candidate_pinyin, query_key)) then
                                begin
                                    Dec(score_value, c_full_query_dual_jianpin_penalty);
                                    if full_query_dual_jianpin_has_cap and
                                        (score_value > full_query_dual_jianpin_cap_score) then
                                    begin
                                        score_value := full_query_dual_jianpin_cap_score;
                                    end;
                                end;
                                append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                    dict_weight_value, candidate_pinyin);
                                step_result := m_base_connection.step(stmt);
                            end;
                        end;
                    finally
                        if stmt <> nil then
                        begin
                            m_base_connection.finalize(stmt);
                        end;
                    end;
                end;
            end;
        end;

        if (not typo_fallback_used) and mixed_mode and m_base_ready and (mixed_like_pattern <> '') and
            (list.Count < m_limit) then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_mixed_pattern_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, mixed_like_pattern) and
                    m_base_connection.bind_int(stmt, 2, m_limit) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        if mixed_mode and SameText(candidate_pinyin, query_key) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_tokens) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - jianpin_score_penalty;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin);
                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        // Single-letter queries should still surface useful single-character candidates.
        // For full one-syllable queries (e.g. "e"), keep exact pinyin candidates ahead.
        if m_base_ready and single_letter_query and (list.Count < m_limit) then
        begin
            single_letter_cap_score := 0;
            single_letter_has_cap := False;
            if full_pinyin_query and (list.Count > 0) then
            begin
                single_letter_cap_score := list[0].score - c_single_letter_full_query_cap_margin;
                for i := 1 to list.Count - 1 do
                begin
                    if list[i].score - c_single_letter_full_query_cap_margin < single_letter_cap_score then
                    begin
                        single_letter_cap_score := list[i].score - c_single_letter_full_query_cap_margin;
                    end;
                end;
                single_letter_has_cap := True;
            end;

            stmt := nil;
            try
                if m_base_connection.prepare(base_initial_single_char_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, query_key + '%') and
                    m_base_connection.bind_int(stmt, 2, Min(24, m_limit)) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        if full_pinyin_query and SameText(candidate_pinyin, query_key) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - c_initial_single_char_penalty;
                        if full_pinyin_query then
                        begin
                            Dec(score_value, c_single_letter_full_query_extra_penalty);
                            if single_letter_has_cap and (score_value > single_letter_cap_score) then
                            begin
                                score_value := single_letter_cap_score;
                            end;
                        end;

                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin);
                        if full_pinyin_query and single_letter_has_cap then
                        begin
                            single_letter_cap_score := (single_letter_cap_score - 1);
                        end;

                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        // For mixed inputs like "hha", mainstream IMEs still show high-frequency
        // single-character candidates under the leading initial.
        if mixed_mode and m_base_ready and (Length(mixed_tokens) > 0) and
            (mixed_tokens[0].kind = mqt_initial) and (list.Count < m_limit) then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_initial_single_char_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, mixed_tokens[0].text + '%') and
                    m_base_connection.bind_int(stmt, 2, Min(24, m_limit)) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - c_initial_single_char_penalty;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin);
                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        apply_short_jianpin_commonness_rerank;

        if c_enable_runtime_homophone_bonus then
        begin
            apply_homophone_commonness_bonus;
        end;

        apply_text_learning_bonus;
        apply_single_letter_full_query_standalone_rerank;
        apply_single_letter_full_query_spoken_bonus;
        enforce_single_letter_exact_group_priority;
        apply_candidate_score_caps;
        sort_candidate_list_by_score;

        if list.Count > 0 then
        begin
            SetLength(results, list.Count);
            for i := 0 to list.Count - 1 do
            begin
                results[i] := list[i];
            end;
        end;

        if m_debug_mode then
        begin
            m_last_lookup_debug_hint := Format(
                'dict=[full=%d mixed=%d user_nf=%d exact=%d typo=%d dual_jp=%d long_jp_off=%d learn=%d text=%d sc_bad=%d noise=%d dup=%d inj=%d n=%d]',
                [Ord(full_pinyin_query), Ord(mixed_mode), Ord(user_nonfull_lookup), Ord(exact_base_hit),
                Ord(typo_fallback_used), Ord(full_query_dual_jianpin_mode),
                Ord(disable_long_full_query_jianpin), applied_learning_bonus_count,
                applied_text_learning_bonus_count, skipped_single_char_mismatch_count,
                skipped_noisy_user_count, skipped_base_dup_user_count,
                injected_learned_base_count, list.Count]);
        end
        else
        begin
            m_last_lookup_debug_hint := '';
        end;
        Result := list.Count > 0;
    finally
        if mixed_parser <> nil then
        begin
            mixed_parser.Free;
        end;
        candidate_score_cap_map.Free;
        candidate_pinyin_map.Free;
        text_learning_bonus_cache.Free;
        learning_bonus_map.Free;
        list.Free;
        seen.Free;
    end;
end;

function TncSqliteDictionary.single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean;
var
    pinyin_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text_unit);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if not is_full_pinyin_key(pinyin_key) then
    begin
        Exit;
    end;
    if get_valid_cjk_codepoint_count(text_key) <> 1 then
    begin
        Exit;
    end;
    if (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    // Reuse the same normalized base-entry check as phrase validation. Some
    // single characters participate in exact lookup/ranking through normalized
    // pinyin aliases or merged lexicon rows, so an exact dict_base(pinyin,text)
    // probe is too narrow and can wrongly purge valid learned selections such
    // as "ci -> 词" across host restarts.
    Result := normalized_base_entry_exists(pinyin_key, text_key);
end;

procedure TncSqliteDictionary.prune_suspicious_user_entries;
const
    select_entries_sql =
        'SELECT pinyin, text, MAX(user_weight), MAX(commit_count), MAX(last_used) FROM (' +
        'SELECT pinyin, text, weight AS user_weight, 0 AS commit_count, last_used FROM dict_user ' +
        'UNION ALL ' +
        'SELECT pinyin, text, 0 AS user_weight, commit_count, last_used FROM dict_user_stats' +
        ') GROUP BY pinyin, text';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    text_unit_count: Integer;
    user_weight: Integer;
    commit_count: Integer;
    last_used_value: Int64;
begin
    if not m_user_ready then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(select_entries_sql, stmt) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := m_user_connection.column_text(stmt, 0);
            text_value := m_user_connection.column_text(stmt, 1);
            user_weight := m_user_connection.column_int(stmt, 2);
            commit_count := m_user_connection.column_int(stmt, 3);
            last_used_value := m_user_connection.column_int(stmt, 4);
            text_unit_count := get_valid_cjk_codepoint_count(text_value);

            if (pinyin_value <> '') and (text_unit_count = 1) and is_full_pinyin_key(pinyin_value) and
                (not single_char_matches_pinyin(pinyin_value, text_value)) then
            begin
                // Lookup already ignores mismatched single-char user rows.
                // Avoid destructive cleanup here so a provider reload cannot
                // erase a valid recent choice due to transient validation
                // disagreement or lexicon normalization differences.
            end
            else if should_suppress_constructed_user_phrase(pinyin_value, text_value,
                commit_count, user_weight) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, False);
            end
            else if (last_used_value <= 0) and
                is_likely_noisy_constructed_phrase(pinyin_value, text_value, commit_count, user_weight) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, True);
            end;

            step_result := m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.record_commit(const pinyin: string; const text: string);
const
    update_stats_sql = 'UPDATE dict_user_stats SET commit_count = commit_count + 1, ' +
        'last_used = strftime(''%s'',''now'') WHERE pinyin = ?1 AND text = ?2';
    insert_stats_sql = 'INSERT OR IGNORE INTO dict_user_stats(pinyin, text, commit_count, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
    update_latest_sql = 'UPDATE dict_user_query_latest SET text = ?2, ' +
        'last_used = strftime(''%s'',''now'') WHERE query_pinyin = ?1';
    insert_latest_sql = 'INSERT OR IGNORE INTO dict_user_query_latest(query_pinyin, text, last_used) ' +
        'VALUES (?1, ?2, strftime(''%s'',''now''))';
    update_sql = 'UPDATE dict_user SET weight = weight + 1, last_used = strftime(''%s'',''now'') ' +
        'WHERE pinyin = ?1 AND text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user(pinyin, text, weight, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
    delete_penalty_sql = 'DELETE FROM dict_user_penalty WHERE pinyin = ?1 AND text = ?2';
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    cache_key: string;
    full_pinyin_input: Boolean;
    base_entry_exists: Boolean;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    cache_key := pinyin_key + #1 + Trim(text);
    if (pinyin_key = '') or (text = '') or (not is_valid_learning_text(text)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Remove(cache_key);
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Remove(pinyin_key);
    end;
    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Remove(cache_key);
    end;

    full_pinyin_input := is_full_pinyin_key(pinyin_key);
    if full_pinyin_input and (get_valid_cjk_codepoint_count(text) = 1) and
        (not single_char_matches_pinyin(pinyin_key, text)) then
    begin
        // Ignore invalid single-char learning, but do not erase any existing
        // persisted choice here. Runtime lookup already filters mismatched
        // single-char rows, so destructive purge is unnecessary.
        Exit;
    end;

    base_entry_exists := normalized_base_entry_exists(pinyin_key, text);
    if full_pinyin_input and should_suppress_exact_query_learning(pinyin_key, text) then
    begin
        purge_user_entry_internal(pinyin_key, text, False, False);
        Exit;
    end;

    // A positive explicit selection for the same query/text pair should
    // cancel any earlier "remove candidate" feedback for that exact pair.
    stmt := nil;
    try
        if m_user_connection.prepare(delete_penalty_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_stats_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_stats_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_latest_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_latest_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if not is_valid_user_text(text) then
    begin
        // Keep learning stats for single-char commits, but never keep them as user words.
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) then
            begin
                if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, text) then
                begin
                    m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
        Exit;
    end;

    if not full_pinyin_input then
    begin
        // Keep stats learning, but do not keep dedicated user-word rows for
        // non-full-pinyin commits.
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) then
            begin
                if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, text) then
                begin
                    m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
        Exit;
    end;

    if base_entry_exists then
    begin
        // Base-dictionary entries should learn through stats-driven re-ranking,
        // not by duplicating the same entry into dict_user.
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) then
            begin
                if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                    m_user_connection.bind_text(stmt, 2, text) then
                begin
                    m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.record_context_pair(const left_text: string; const committed_text: string);
const
    update_sql = 'UPDATE dict_user_bigram SET commit_count = commit_count + 1, ' +
        'last_used = strftime(''%s'',''now'') WHERE left_text = ?1 AND text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user_bigram(left_text, text, commit_count, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
var
    stmt_update: Psqlite3_stmt;
    stmt_insert: Psqlite3_stmt;
    left_key: string;
    text_key: string;
    context_variants: TArray<string>;
    variant_idx: Integer;
begin
    left_key := Trim(left_text);
    text_key := Trim(committed_text);
    if (left_key = '') or (text_key = '') or
        (not is_valid_learning_text(left_key)) or (not is_valid_learning_text(text_key)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    context_variants := build_context_variants_local(left_key);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    stmt_update := m_stmt_record_context_pair_update;
    stmt_insert := m_stmt_record_context_pair_insert;
    if (stmt_update = nil) and (not m_user_connection.prepare(update_sql, stmt_update)) then
    begin
        Exit;
    end;
    if (stmt_insert = nil) and (not m_user_connection.prepare(insert_sql, stmt_insert)) then
    begin
        if (m_stmt_record_context_pair_update = nil) and (stmt_update <> nil) then
        begin
            m_user_connection.finalize(stmt_update);
        end;
        Exit;
    end;
    m_stmt_record_context_pair_update := stmt_update;
    m_stmt_record_context_pair_insert := stmt_insert;

    for variant_idx := 0 to High(context_variants) do
    begin
        if m_user_connection.reset(stmt_update) and
            m_user_connection.clear_bindings(stmt_update) and
            m_user_connection.bind_text(stmt_update, 1, context_variants[variant_idx]) and
            m_user_connection.bind_text(stmt_update, 2, text_key) then
        begin
            m_user_connection.step(stmt_update);
        end;

        if m_user_connection.reset(stmt_insert) and
            m_user_connection.clear_bindings(stmt_insert) and
            m_user_connection.bind_text(stmt_insert, 1, context_variants[variant_idx]) and
            m_user_connection.bind_text(stmt_insert, 2, text_key) then
        begin
            m_user_connection.step(stmt_insert);
        end;
    end;

    prune_bigram_rows_if_needed(False);
end;

procedure TncSqliteDictionary.record_context_trigram(const prev_prev_text: string; const prev_text: string;
    const committed_text: string);
const
    update_sql = 'UPDATE dict_user_trigram SET commit_count = commit_count + 1, ' +
        'last_used = strftime(''%s'',''now'') WHERE prev_prev_text = ?1 AND prev_text = ?2 AND text = ?3';
    insert_sql = 'INSERT OR IGNORE INTO dict_user_trigram(prev_prev_text, prev_text, text, commit_count, last_used) ' +
        'VALUES (?1, ?2, ?3, 1, strftime(''%s'',''now''))';
var
    stmt_update: Psqlite3_stmt;
    stmt_insert: Psqlite3_stmt;
    prev_prev_key: string;
    prev_key: string;
    text_key: string;
begin
    prev_prev_key := Trim(prev_prev_text);
    prev_key := Trim(prev_text);
    text_key := Trim(committed_text);
    if (prev_prev_key = '') or (prev_key = '') or (text_key = '') or
        (not is_valid_learning_text(prev_prev_key)) or
        (not is_valid_learning_text(prev_key)) or
        (not is_valid_learning_text(text_key)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    stmt_update := m_stmt_record_context_trigram_update;
    stmt_insert := m_stmt_record_context_trigram_insert;
    if (stmt_update = nil) and (not m_user_connection.prepare(update_sql, stmt_update)) then
    begin
        Exit;
    end;
    if (stmt_insert = nil) and (not m_user_connection.prepare(insert_sql, stmt_insert)) then
    begin
        if (m_stmt_record_context_trigram_update = nil) and (stmt_update <> nil) then
        begin
            m_user_connection.finalize(stmt_update);
        end;
        Exit;
    end;
    m_stmt_record_context_trigram_update := stmt_update;
    m_stmt_record_context_trigram_insert := stmt_insert;

    if m_user_connection.reset(stmt_update) and
        m_user_connection.clear_bindings(stmt_update) and
        m_user_connection.bind_text(stmt_update, 1, prev_prev_key) and
        m_user_connection.bind_text(stmt_update, 2, prev_key) and
        m_user_connection.bind_text(stmt_update, 3, text_key) then
    begin
        m_user_connection.step(stmt_update);
    end;

    if m_user_connection.reset(stmt_insert) and
        m_user_connection.clear_bindings(stmt_insert) and
        m_user_connection.bind_text(stmt_insert, 1, prev_prev_key) and
        m_user_connection.bind_text(stmt_insert, 2, prev_key) and
        m_user_connection.bind_text(stmt_insert, 3, text_key) then
    begin
        m_user_connection.step(stmt_insert);
    end;

    prune_trigram_rows_if_needed(False);
end;

procedure TncSqliteDictionary.record_query_segment_path(const query_key: string; const encoded_path: string);
const
    update_sql = 'UPDATE dict_user_query_path SET commit_count = commit_count + 1, ' +
        'last_used = strftime(''%s'',''now'') WHERE query_pinyin = ?1 AND path_text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user_query_path(query_pinyin, path_text, commit_count, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
var
    stmt_update: Psqlite3_stmt;
    stmt_insert: Psqlite3_stmt;
    normalized_query: string;
    normalized_path: string;
begin
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not is_valid_learning_path(normalized_path)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    stmt_update := m_stmt_record_query_path_update;
    stmt_insert := m_stmt_record_query_path_insert;
    if (stmt_update = nil) and (not m_user_connection.prepare(update_sql, stmt_update)) then
    begin
        Exit;
    end;
    if (stmt_insert = nil) and (not m_user_connection.prepare(insert_sql, stmt_insert)) then
    begin
        if (m_stmt_record_query_path_update = nil) and (stmt_update <> nil) then
        begin
            m_user_connection.finalize(stmt_update);
        end;
        Exit;
    end;
    m_stmt_record_query_path_update := stmt_update;
    m_stmt_record_query_path_insert := stmt_insert;

    if m_user_connection.reset(stmt_update) and
        m_user_connection.clear_bindings(stmt_update) and
        m_user_connection.bind_text(stmt_update, 1, normalized_query) and
        m_user_connection.bind_text(stmt_update, 2, normalized_path) then
    begin
        m_user_connection.step(stmt_update);
    end;

    if m_user_connection.reset(stmt_insert) and
        m_user_connection.clear_bindings(stmt_insert) and
        m_user_connection.bind_text(stmt_insert, 1, normalized_query) and
        m_user_connection.bind_text(stmt_insert, 2, normalized_path) then
    begin
        m_user_connection.step(stmt_insert);
    end;

    prune_query_path_rows_if_needed(False);
end;

procedure TncSqliteDictionary.record_query_segment_path_penalty(const query_key: string;
    const encoded_path: string);
const
    update_sql = 'UPDATE dict_user_query_path_penalty SET penalty = MIN(penalty + ?3, ?4), ' +
        'last_used = strftime(''%s'',''now'') WHERE query_pinyin = ?1 AND path_text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user_query_path_penalty(query_pinyin, path_text, penalty, last_used) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
    c_penalty_step = 96;
    c_penalty_max = 480;
var
    stmt: Psqlite3_stmt;
    normalized_query: string;
    normalized_path: string;
begin
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not is_valid_learning_path(normalized_path)) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Clear;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, normalized_query) and
            m_user_connection.bind_text(stmt, 2, normalized_path) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) and
            m_user_connection.bind_int(stmt, 4, c_penalty_max) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, normalized_query) and
            m_user_connection.bind_text(stmt, 2, normalized_path) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    prune_query_path_penalty_rows_if_needed(False);
end;

function TncSqliteDictionary.get_context_bonus(const left_text: string; const candidate_text: string): Integer;
const
    query_sql = 'SELECT commit_count, last_used FROM dict_user_bigram WHERE left_text = ?1 AND text = ?2 LIMIT 1';
var
    step_result: Integer;
    left_key: string;
    text_key: string;
    commit_count: Integer;
    last_used_unix: Int64;
begin
    Result := 0;
    left_key := Trim(left_text);
    text_key := Trim(candidate_text);
    if (left_key = '') or (text_key = '') or (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    try
        if m_stmt_context_bonus = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_context_bonus) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_context_bonus)) or
            (not m_user_connection.clear_bindings(m_stmt_context_bonus)) or
            (not m_user_connection.bind_text(m_stmt_context_bonus, 1, left_key)) or
            (not m_user_connection.bind_text(m_stmt_context_bonus, 2, text_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_context_bonus);
        if step_result <> SQLITE_ROW then
        begin
            Exit;
        end;

        commit_count := m_user_connection.column_int(m_stmt_context_bonus, 0);
        if commit_count <= 0 then
        begin
            Exit;
        end;

        last_used_unix := m_user_connection.column_int(m_stmt_context_bonus, 1);
        Result := calc_context_bigram_bonus(commit_count, last_used_unix, get_unix_time_now);
    finally
        if m_stmt_context_bonus <> nil then
        begin
            m_user_connection.reset(m_stmt_context_bonus);
            m_user_connection.clear_bindings(m_stmt_context_bonus);
        end;
    end;
end;

function TncSqliteDictionary.get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
    const candidate_text: string): Integer;
const
    query_sql =
        'SELECT commit_count, last_used FROM dict_user_trigram ' +
        'WHERE prev_prev_text = ?1 AND prev_text = ?2 AND text = ?3 LIMIT 1';
var
    step_result: Integer;
    prev_prev_key: string;
    prev_key: string;
    text_key: string;
    commit_count: Integer;
    last_used_unix: Int64;
begin
    Result := 0;
    prev_prev_key := Trim(prev_prev_text);
    prev_key := Trim(prev_text);
    text_key := Trim(candidate_text);
    if (prev_prev_key = '') or (prev_key = '') or (text_key = '') or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    try
        if m_stmt_context_trigram_bonus = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_context_trigram_bonus) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_context_trigram_bonus)) or
            (not m_user_connection.clear_bindings(m_stmt_context_trigram_bonus)) or
            (not m_user_connection.bind_text(m_stmt_context_trigram_bonus, 1, prev_prev_key)) or
            (not m_user_connection.bind_text(m_stmt_context_trigram_bonus, 2, prev_key)) or
            (not m_user_connection.bind_text(m_stmt_context_trigram_bonus, 3, text_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_context_trigram_bonus);
        if step_result <> SQLITE_ROW then
        begin
            Exit;
        end;

        commit_count := m_user_connection.column_int(m_stmt_context_trigram_bonus, 0);
        if commit_count <= 0 then
        begin
            Exit;
        end;

        last_used_unix := m_user_connection.column_int(m_stmt_context_trigram_bonus, 1);
        Result := calc_context_trigram_bonus(commit_count, last_used_unix, get_unix_time_now);
    finally
        if m_stmt_context_trigram_bonus <> nil then
        begin
            m_user_connection.reset(m_stmt_context_trigram_bonus);
            m_user_connection.clear_bindings(m_stmt_context_trigram_bonus);
        end;
    end;
end;

function TncSqliteDictionary.get_query_choice_bonus(const query_key: string;
    const candidate_text: string): Integer;
const
    query_sql = 'SELECT commit_count, last_used FROM dict_user_stats WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    c_single_query_base = 44;
    c_single_query_step = 34;
    c_single_query_cap = 520;
    c_multi_query_base = 96;
    c_multi_query_step = 56;
    c_multi_query_cap = 640;
    c_recent_bonus_1d = 220;
    c_recent_bonus_3d = 120;
    c_recent_bonus_7d = 64;
    c_recent_bonus_30d = 28;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_week = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
var
    step_result: Integer;
    normalized_query: string;
    text_key: string;
    cache_key: string;
    commit_count: Integer;
    last_used_unix: Int64;
    units: Integer;
    now_unix: Int64;
    age_seconds: Int64;
    recent_bonus: Integer;
    session_like_bonus: Integer;
    learning_floor_bonus: Integer;
begin
    Result := 0;
    normalized_query := LowerCase(Trim(query_key));
    text_key := Trim(candidate_text);
    if (normalized_query = '') or (text_key = '') or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    cache_key := normalized_query + #1 + text_key;
    if (m_query_choice_bonus_cache <> nil) and m_query_choice_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    if get_candidate_penalty(normalized_query, text_key) > 0 then
    begin
        Exit;
    end;

    try
        if m_stmt_query_choice_bonus = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_query_choice_bonus) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_choice_bonus)) or
            (not m_user_connection.clear_bindings(m_stmt_query_choice_bonus)) or
            (not m_user_connection.bind_text(m_stmt_query_choice_bonus, 1, normalized_query)) or
            (not m_user_connection.bind_text(m_stmt_query_choice_bonus, 2, text_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_query_choice_bonus);
        if step_result <> SQLITE_ROW then
        begin
            Exit;
        end;

        commit_count := m_user_connection.column_int(m_stmt_query_choice_bonus, 0);
        if commit_count <= 0 then
        begin
            Exit;
        end;

        if should_suppress_exact_query_learning(normalized_query, text_key) then
        begin
            Exit;
        end;

        if should_suppress_constructed_user_phrase(normalized_query, text_key, commit_count, 0) and
            (not explicit_user_entry_exists(normalized_query, text_key)) then
        begin
            Exit;
        end;

        last_used_unix := m_user_connection.column_int(m_stmt_query_choice_bonus, 1);
        now_unix := get_unix_time_now;
        recent_bonus := 0;
        if (last_used_unix > 0) and (now_unix > 0) then
        begin
            age_seconds := now_unix - last_used_unix;
            if age_seconds < 0 then
            begin
                age_seconds := 0;
            end;

            if age_seconds <= c_sec_per_day then
            begin
                recent_bonus := c_recent_bonus_1d;
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                recent_bonus := c_recent_bonus_3d;
            end
            else if age_seconds <= c_sec_per_week then
            begin
                recent_bonus := c_recent_bonus_7d;
            end
            else if age_seconds <= c_sec_per_30_days then
            begin
                recent_bonus := c_recent_bonus_30d;
            end;
        end;

        units := get_valid_cjk_codepoint_count(text_key);
        if units <= 1 then
        begin
            session_like_bonus := c_single_query_base + ((commit_count - 1) * c_single_query_step) +
                recent_bonus;
            if commit_count >= 2 then
            begin
                Inc(session_like_bonus, 18);
            end;
            if commit_count >= 4 then
            begin
                Inc(session_like_bonus, 28);
            end;
            learning_floor_bonus := calc_learning_bonus(commit_count, last_used_unix, now_unix) div 2;
            Result := Max(session_like_bonus, learning_floor_bonus);
            if Result > c_single_query_cap then
            begin
                Result := c_single_query_cap;
            end;
        end
        else
        begin
            session_like_bonus := c_multi_query_base + ((commit_count - 1) * c_multi_query_step) +
                recent_bonus;
            if (commit_count >= 2) and (recent_bonus >= c_recent_bonus_3d) then
            begin
                Inc(session_like_bonus, 56);
            end;
            if (commit_count >= 3) and (recent_bonus >= c_recent_bonus_7d) then
            begin
                Inc(session_like_bonus, 32);
            end;
            learning_floor_bonus := calc_learning_bonus(commit_count, last_used_unix, now_unix) div 3;
            Result := Max(session_like_bonus, learning_floor_bonus);
            if Result > c_multi_query_cap then
            begin
                Result := c_multi_query_cap;
            end;
        end;

        if Result < 0 then
        begin
            Result := 0;
        end;
    finally
        if m_stmt_query_choice_bonus <> nil then
        begin
            m_user_connection.reset(m_stmt_query_choice_bonus);
            m_user_connection.clear_bindings(m_stmt_query_choice_bonus);
        end;
    end;

    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_query_latest_choice_text(const query_key: string): string;
const
    query_sql =
        'SELECT text, last_used FROM dict_user_query_latest WHERE query_pinyin = ?1 LIMIT 1';
    fallback_query_sql =
        'SELECT text, commit_count, last_used FROM dict_user_stats ' +
        'WHERE pinyin = ?1 ORDER BY last_used DESC, commit_count DESC LIMIT 16';
    c_sec_per_180_days = 180 * 24 * 60 * 60;
var
    normalized_query: string;
    step_result: Integer;
    stmt: Psqlite3_stmt;
    candidate_text: string;
    commit_count: Integer;
    last_used_unix: Int64;
    now_unix: Int64;
    age_seconds: Int64;
    use_fallback_scan: Boolean;
begin
    Result := '';
    normalized_query := LowerCase(Trim(query_key));
    if (normalized_query = '') or (not ensure_open) or (not m_user_ready) or
        (m_user_connection = nil) then
    begin
        Exit;
    end;

    if (m_query_latest_choice_text_cache <> nil) and
        m_query_latest_choice_text_cache.TryGetValue(normalized_query, Result) then
    begin
        Exit;
    end;

    use_fallback_scan := False;

    try
        if m_stmt_query_latest_choice_text = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_query_latest_choice_text) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_latest_choice_text)) or
            (not m_user_connection.clear_bindings(m_stmt_query_latest_choice_text)) or
            (not m_user_connection.bind_text(m_stmt_query_latest_choice_text, 1, normalized_query)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_query_latest_choice_text);
        if step_result <> SQLITE_ROW then
        begin
            use_fallback_scan := True;
        end;
        if not use_fallback_scan then
        begin
            candidate_text := Trim(m_user_connection.column_text(m_stmt_query_latest_choice_text, 0));
            last_used_unix := m_user_connection.column_int(m_stmt_query_latest_choice_text, 1);
            if last_used_unix > 0 then
            begin
                now_unix := get_unix_time_now;
                if now_unix > 0 then
                begin
                    age_seconds := now_unix - last_used_unix;
                    if age_seconds < 0 then
                    begin
                        age_seconds := 0;
                    end;
                    if age_seconds > c_sec_per_180_days then
                    begin
                        use_fallback_scan := True;
                    end;
                end;
            end;

            if (not use_fallback_scan) and
                ((candidate_text = '') or
                (should_suppress_exact_query_learning(normalized_query, candidate_text)) or
                ((is_suppressible_nonbase_exact_phrase(normalized_query, candidate_text)) and
                (not explicit_user_entry_exists(normalized_query, candidate_text))) or
                (get_candidate_penalty(normalized_query, candidate_text) > 0)) then
            begin
                use_fallback_scan := True;
            end;

            if not use_fallback_scan then
            begin
                Result := candidate_text;
            end;
        end;
    finally
        if m_stmt_query_latest_choice_text <> nil then
        begin
            m_user_connection.reset(m_stmt_query_latest_choice_text);
            m_user_connection.clear_bindings(m_stmt_query_latest_choice_text);
        end;
    end;

    if use_fallback_scan then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(fallback_query_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, normalized_query) then
            begin
                step_result := m_user_connection.step(stmt);
                while step_result = SQLITE_ROW do
                begin
                    candidate_text := Trim(m_user_connection.column_text(stmt, 0));
                    if candidate_text <> '' then
                    begin
                        commit_count := m_user_connection.column_int(stmt, 1);
                        last_used_unix := m_user_connection.column_int(stmt, 2);
                        if last_used_unix > 0 then
                        begin
                            now_unix := get_unix_time_now;
                            if now_unix > 0 then
                            begin
                                age_seconds := now_unix - last_used_unix;
                                if age_seconds < 0 then
                                begin
                                    age_seconds := 0;
                                end;
                                if age_seconds > c_sec_per_180_days then
                                begin
                                    Break;
                                end;
                            end;
                        end;

                        if should_suppress_exact_query_learning(normalized_query, candidate_text) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;

                        if should_suppress_constructed_user_phrase(normalized_query,
                            candidate_text, commit_count, 0) and
                            (not explicit_user_entry_exists(normalized_query, candidate_text)) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;

                        if get_candidate_penalty(normalized_query, candidate_text) <= 0 then
                        begin
                            Result := candidate_text;
                            Break;
                        end;
                    end;
                    step_result := m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.AddOrSetValue(normalized_query, Result);
    end;
end;

function TncSqliteDictionary.get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer;
const
    user_query_sql =
        'SELECT commit_count, last_used FROM dict_user_query_path ' +
        'WHERE query_pinyin = ?1 AND path_text = ?2 LIMIT 1';
    base_query_sql =
        'SELECT weight FROM dict_base_query_path ' +
        'WHERE query_pinyin = ?1 AND path_text = ?2 LIMIT 1';
var
    step_result: Integer;
    normalized_query: string;
    normalized_path: string;
    commit_count: Integer;
    last_used_unix: Int64;
    base_weight: Integer;
    can_query_base: Boolean;
begin
    Result := 0;
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not ensure_open) or ((not m_base_ready) and (not m_user_ready)) then
    begin
        Exit;
    end;

    if m_base_ready and (m_base_connection <> nil) then
    begin
        try
            can_query_base := False;
            if m_stmt_base_query_path_bonus = nil then
            begin
                if not m_base_connection.prepare(base_query_sql, m_stmt_base_query_path_bonus) then
                begin
                    m_stmt_base_query_path_bonus := nil;
                end;
            end;
            if m_stmt_base_query_path_bonus <> nil then
            begin
                can_query_base := m_base_connection.reset(m_stmt_base_query_path_bonus) and
                    m_base_connection.clear_bindings(m_stmt_base_query_path_bonus) and
                    m_base_connection.bind_text(m_stmt_base_query_path_bonus, 1, normalized_query) and
                    m_base_connection.bind_text(m_stmt_base_query_path_bonus, 2, normalized_path);
                if not can_query_base then
                begin
                    m_base_connection.reset(m_stmt_base_query_path_bonus);
                    m_base_connection.clear_bindings(m_stmt_base_query_path_bonus);
                end;
            end;

            if can_query_base and (m_stmt_base_query_path_bonus <> nil) then
            begin
                step_result := m_base_connection.step(m_stmt_base_query_path_bonus);
                if step_result = SQLITE_ROW then
                begin
                    base_weight := m_base_connection.column_int(m_stmt_base_query_path_bonus, 0);
                    if base_weight > 0 then
                    begin
                        Result := calc_base_query_segment_path_bonus(base_weight);
                    end;
                end;
            end;
        finally
            if m_stmt_base_query_path_bonus <> nil then
            begin
                m_base_connection.reset(m_stmt_base_query_path_bonus);
                m_base_connection.clear_bindings(m_stmt_base_query_path_bonus);
            end;
        end;
    end;

    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    try
        if m_stmt_query_path_bonus = nil then
        begin
            if not m_user_connection.prepare(user_query_sql, m_stmt_query_path_bonus) then
            begin
                Exit(Result);
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_path_bonus)) or
            (not m_user_connection.clear_bindings(m_stmt_query_path_bonus)) or
            (not m_user_connection.bind_text(m_stmt_query_path_bonus, 1, normalized_query)) or
            (not m_user_connection.bind_text(m_stmt_query_path_bonus, 2, normalized_path)) then
        begin
            Exit(Result);
        end;

        step_result := m_user_connection.step(m_stmt_query_path_bonus);
        if step_result <> SQLITE_ROW then
        begin
            Exit(Result);
        end;

        commit_count := m_user_connection.column_int(m_stmt_query_path_bonus, 0);
        if commit_count <= 0 then
        begin
            Exit(Result);
        end;

        last_used_unix := m_user_connection.column_int(m_stmt_query_path_bonus, 1);
        Inc(Result, calc_query_segment_path_bonus(commit_count, last_used_unix, get_unix_time_now));
    finally
        if m_stmt_query_path_bonus <> nil then
        begin
            m_user_connection.reset(m_stmt_query_path_bonus);
            m_user_connection.clear_bindings(m_stmt_query_path_bonus);
        end;
    end;
end;

function TncSqliteDictionary.get_query_segment_path_penalty(const query_key: string;
    const encoded_path: string): Integer;
const
    query_sql =
        'SELECT penalty, last_used FROM dict_user_query_path_penalty ' +
        'WHERE query_pinyin = ?1 AND path_text = ?2 LIMIT 1';
var
    step_result: Integer;
    normalized_query: string;
    normalized_path: string;
    cache_key: string;
    last_used_unix: Int64;
begin
    Result := 0;
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    cache_key := normalized_query + #1 + normalized_path;
    if (m_query_path_penalty_cache <> nil) and
        m_query_path_penalty_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if m_stmt_query_path_penalty = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_query_path_penalty) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_path_penalty)) or
            (not m_user_connection.clear_bindings(m_stmt_query_path_penalty)) or
            (not m_user_connection.bind_text(m_stmt_query_path_penalty, 1, normalized_query)) or
            (not m_user_connection.bind_text(m_stmt_query_path_penalty, 2, normalized_path)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_query_path_penalty);
        if step_result = SQLITE_ROW then
        begin
            last_used_unix := m_user_connection.column_int(m_stmt_query_path_penalty, 1);
            Result := calc_query_segment_path_penalty_value(
                m_user_connection.column_int(m_stmt_query_path_penalty, 0),
                last_used_unix,
                get_unix_time_now);
        end;

        if m_query_path_penalty_cache <> nil then
        begin
            m_query_path_penalty_cache.AddOrSetValue(cache_key, Result);
        end;
    finally
        if m_stmt_query_path_penalty <> nil then
        begin
            m_user_connection.reset(m_stmt_query_path_penalty);
            m_user_connection.clear_bindings(m_stmt_query_path_penalty);
        end;
    end;
end;

function TncSqliteDictionary.get_candidate_penalty(const pinyin: string; const text: string): Integer;
const
    query_penalty_sql = 'SELECT penalty, last_used FROM dict_user_penalty WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
var
    pinyin_key: string;
    text_key: string;
    cache_key: string;
    step_result: Integer;
    last_used_unix: Int64;
begin
    Result := 0;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    cache_key := pinyin_key + #1 + text_key;
    if (m_candidate_penalty_cache <> nil) and
        m_candidate_penalty_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if m_stmt_candidate_penalty = nil then
        begin
            if not m_user_connection.prepare(query_penalty_sql, m_stmt_candidate_penalty) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_candidate_penalty)) or
            (not m_user_connection.clear_bindings(m_stmt_candidate_penalty)) or
            (not m_user_connection.bind_text(m_stmt_candidate_penalty, 1, pinyin_key)) or
            (not m_user_connection.bind_text(m_stmt_candidate_penalty, 2, text_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_candidate_penalty);
        if step_result = SQLITE_ROW then
        begin
            last_used_unix := m_user_connection.column_int(m_stmt_candidate_penalty, 1);
            Result := calc_candidate_penalty_value(
                m_user_connection.column_int(m_stmt_candidate_penalty, 0),
                last_used_unix,
                get_unix_time_now);
        end;

        if m_candidate_penalty_cache <> nil then
        begin
            m_candidate_penalty_cache.AddOrSetValue(cache_key, Result);
        end;
    finally
        if m_stmt_candidate_penalty <> nil then
        begin
            m_user_connection.reset(m_stmt_candidate_penalty);
            m_user_connection.clear_bindings(m_stmt_candidate_penalty);
        end;
    end;
end;

procedure TncSqliteDictionary.record_candidate_penalty(const pinyin: string; const text: string);
const
    delete_latest_sql = 'DELETE FROM dict_user_query_latest WHERE query_pinyin = ?1 AND text = ?2';
    update_penalty_sql = 'UPDATE dict_user_penalty SET penalty = MIN(penalty + ?3, ?4), ' +
        'last_used = strftime(''%s'',''now'') WHERE pinyin = ?1 AND text = ?2';
    insert_penalty_sql = 'INSERT OR IGNORE INTO dict_user_penalty(pinyin, text, penalty, last_used) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
    c_penalty_step = 24;
    c_penalty_max = 120;
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    text_key: string;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Remove(pinyin_key + #1 + text_key);
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Remove(pinyin_key);
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(delete_latest_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_penalty_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) and
            m_user_connection.bind_int(stmt, 4, c_penalty_max) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_penalty_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.purge_user_entry_internal(const pinyin: string; const text: string;
    const apply_penalty: Boolean; const purge_all_by_text: Boolean);
const
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
    delete_stats_sql = 'DELETE FROM dict_user_stats WHERE pinyin = ?1 AND text = ?2';
    delete_latest_sql = 'DELETE FROM dict_user_query_latest WHERE query_pinyin = ?1 AND text = ?2';
    delete_user_by_text_sql = 'DELETE FROM dict_user WHERE text = ?1';
    delete_stats_by_text_sql = 'DELETE FROM dict_user_stats WHERE text = ?1';
    delete_latest_by_text_sql = 'DELETE FROM dict_user_query_latest WHERE text = ?1';
    delete_bigram_by_text_sql = 'DELETE FROM dict_user_bigram WHERE text = ?1';
    delete_bigram_by_left_sql = 'DELETE FROM dict_user_bigram WHERE left_text = ?1';
    delete_trigram_by_text_sql = 'DELETE FROM dict_user_trigram WHERE text = ?1';
    delete_trigram_by_prev_sql = 'DELETE FROM dict_user_trigram WHERE prev_text = ?1';
    delete_trigram_by_prev_prev_sql = 'DELETE FROM dict_user_trigram WHERE prev_prev_text = ?1';
    update_penalty_sql = 'UPDATE dict_user_penalty SET penalty = MIN(penalty + ?3, ?4), ' +
        'last_used = strftime(''%s'',''now'') WHERE pinyin = ?1 AND text = ?2';
    insert_penalty_sql = 'INSERT OR IGNORE INTO dict_user_penalty(pinyin, text, penalty, last_used) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
    c_remove_penalty_step = 80;
    c_remove_penalty_max = 360;
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    text_key: string;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (text_key = '') or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        if purge_all_by_text then
        begin
            m_query_choice_bonus_cache.Clear;
        end
        else if pinyin_key <> '' then
        begin
            m_query_choice_bonus_cache.Remove(pinyin_key + #1 + text_key);
        end
        else
        begin
            m_query_choice_bonus_cache.Clear;
        end;
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        if purge_all_by_text then
        begin
            m_query_latest_choice_text_cache.Clear;
        end
        else if pinyin_key <> '' then
        begin
            m_query_latest_choice_text_cache.Remove(pinyin_key);
        end
        else
        begin
            m_query_latest_choice_text_cache.Clear;
        end;
    end;

    // Prefer exact pinyin+text removal when key is available, but do not require it.
    if pinyin_key <> '' then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_stats_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_latest_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if purge_all_by_text then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_stats_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_latest_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_bigram_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_bigram_by_left_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_trigram_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_trigram_by_prev_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_trigram_by_prev_prev_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if apply_penalty and (pinyin_key <> '') and is_valid_user_text(text_key) then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(update_penalty_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) and
                m_user_connection.bind_int(stmt, 3, c_remove_penalty_step) and
                m_user_connection.bind_int(stmt, 4, c_remove_penalty_max) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(insert_penalty_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) and
                m_user_connection.bind_int(stmt, 3, c_remove_penalty_step) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
end;

procedure TncSqliteDictionary.remove_user_entry(const pinyin: string; const text: string);
begin
    // Prefer exact pinyin+text removal when key is available, but also clear
    // all rows by phrase text so legacy polluted variants are removed together.
    purge_user_entry_internal(pinyin, text, True, True);
end;

end.
