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
        m_write_batch_depth: Integer;
        m_base_connection: TncSqliteConnection;
        m_user_connection: TncSqliteConnection;
        m_contains_popularity_cache: TDictionary<string, Integer>;
        m_prefix_popularity_cache: TDictionary<string, Integer>;
        m_stmt_context_bonus: Psqlite3_stmt;
        m_last_lookup_debug_hint: string;
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
        function get_contains_popularity_score(const token: string): Integer;
        function get_prefix_popularity_score(const prefix: string): Integer;
        function get_user_entry_count(const connection: TncSqliteConnection; out count: Integer): Boolean;
        procedure migrate_user_entries;
        function exact_base_entry_exists(const pinyin: string; const text: string): Boolean;
        function normalized_base_entry_exists(const pinyin: string; const text: string): Boolean;
        function has_any_base_phrase_for_pinyin(const pinyin: string): Boolean;
        function split_full_pinyin_syllables(const pinyin: string): TArray<string>;
        function is_whitelisted_constructed_phrase(const pinyin: string; const text: string): Boolean;
        function is_likely_noisy_constructed_phrase(const pinyin: string; const text: string;
            const commit_count: Integer = 0; const user_weight: Integer = 0): Boolean;
        procedure configure_user_connection;
        procedure purge_user_entry_internal(const pinyin: string; const text: string;
            const apply_penalty: Boolean; const purge_all_by_text: Boolean);
        procedure prune_user_entries_existing_in_base;
        procedure prune_suspicious_user_entries;
        procedure prune_bigram_rows_if_needed(const force: Boolean);
        procedure clear_cached_user_statements;
    public
        constructor create(const base_db_path: string; const user_db_path: string);
        destructor Destroy; override;
        function open: Boolean;
        procedure close;
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; override;
        function single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean;
        procedure begin_learning_batch; override;
        procedure commit_learning_batch; override;
        procedure rollback_learning_batch; override;
        procedure record_commit(const pinyin: string; const text: string); override;
        procedure record_context_pair(const left_text: string; const committed_text: string); override;
        function get_context_bonus(const left_text: string; const candidate_text: string): Integer; override;
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
        'INSERT OR IGNORE INTO meta(key, value) VALUES(''schema_version'', ''5'');' + sLineBreak +
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
        'CREATE INDEX IF NOT EXISTS idx_dict_user_bigram_left_text ON dict_user_bigram(left_text);' + sLineBreak;

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
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
var
    freq_bonus: Integer;
    recency_bonus: Integer;
    quick_bonus: Integer;
    maturity_bonus: Integer;
    age_seconds: Int64;
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
    end;

    Result := freq_bonus + quick_bonus + maturity_bonus + recency_bonus;
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
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
var
    recency_bonus: Integer;
    age_seconds: Int64;
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
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := 90;
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
    end;
    Inc(Result, recency_bonus);

    if Result > c_bigram_bonus_cap then
    begin
        Result := c_bigram_bonus_cap;
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
    m_write_batch_depth := 0;
    m_stmt_context_bonus := nil;
    m_base_connection := nil;
    m_user_connection := nil;
    m_contains_popularity_cache := TDictionary<string, Integer>.Create;
    m_prefix_popularity_cache := TDictionary<string, Integer>.Create;
    m_last_lookup_debug_hint := '';
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

    inherited Destroy;
end;

function TncSqliteDictionary.get_last_lookup_debug_hint: string;
begin
    Result := m_last_lookup_debug_hint;
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

    if not get_schema_version(connection, schema_version) then
    begin
        set_schema_version(connection, 5);
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
begin
    // Learning stats should include both single-character and phrase commits.
    Result := get_valid_cjk_codepoint_count(text) >= 1;
end;

function TncSqliteDictionary.is_valid_user_text(const text: string): Boolean;
var
    codepoint_count: Integer;
begin
    codepoint_count := get_valid_cjk_codepoint_count(text);
    // User dictionary should store phrase learning only, not single-character commits.
    Result := codepoint_count >= 2;
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
    query_sql = 'SELECT COALESCE(SUM(weight), 0) FROM dict_base WHERE text LIKE ?1 || ''%''';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
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

    stmt := nil;
    try
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;
        if not m_base_connection.bind_text(stmt, 1, prefix) then
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

    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.AddOrSetValue(prefix, Result);
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
    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.Clear;
    end;
    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.Clear;
    end;
end;

procedure TncSqliteDictionary.clear_cached_user_statements;
begin
    if (m_stmt_context_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_context_bonus);
        m_stmt_context_bonus := nil;
    end;
end;

function TncSqliteDictionary.lookup(const pinyin: string; out results: TncCandidateList): Boolean;
const
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_typo_prefix_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin LIKE ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_single_char_exact_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 AND length(text) = 1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_jianpin_sql =
        'SELECT b.pinyin, b.text, b.comment, j.weight ' +
        'FROM dict_jianpin j INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE j.jianpin = ?1 ' +
        'ORDER BY j.weight DESC, b.weight DESC, b.text ASC LIMIT ?2';
    base_jianpin_prefixed_sql =
        'SELECT b.pinyin, b.text, b.comment, j.weight ' +
        'FROM dict_jianpin j INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE j.jianpin = ?1 AND b.pinyin LIKE ?2 ' +
        'ORDER BY j.weight DESC, b.weight DESC, b.text ASC LIMIT ?3';
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
    mixed_full_prefix: string;
    mixed_jianpin_key: string;
    effective_jianpin_key: string;
    full_query_jianpin_key: string;
    jianpin_query_keys: TArray<string>;
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

    function build_mixed_like_pattern(const token_list: TncMixedQueryTokenList): string; forward;
    function is_compact_ascii_query(const value: string): Boolean; forward;
    procedure add_jianpin_query_key(const key_value: string); forward;
    procedure append_jianpin_query_key_variants(const key_value: string); forward;

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

    procedure add_jianpin_query_key(const key_value: string);
    var
        idx: Integer;
    begin
        if key_value = '' then
        begin
            Exit;
        end;

        for idx := 0 to High(jianpin_query_keys) do
        begin
            if SameText(jianpin_query_keys[idx], key_value) then
            begin
                Exit;
            end;
        end;

        SetLength(jianpin_query_keys, Length(jianpin_query_keys) + 1);
        jianpin_query_keys[High(jianpin_query_keys)] := key_value;
    end;

    procedure append_jianpin_query_key_variants(const key_value: string);
    var
        variants: TArray<string>;
        idx: Integer;
    begin
        variants := build_jianpin_query_variants(key_value);
        if Length(variants) = 0 then
        begin
            add_jianpin_query_key(key_value);
            Exit;
        end;

        for idx := 0 to High(variants) do
        begin
            add_jianpin_query_key(variants[idx]);
        end;
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
            if (full_query_jianpin_key <> '') and
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
        append_jianpin_query_key_variants(effective_jianpin_key);
        if Length(jianpin_query_keys) = 0 then
        begin
            add_jianpin_query_key(effective_jianpin_key);
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
    end;

    procedure append_candidate(const text: string; const comment: string; const score: Integer;
        const source: TncCandidateSource; const has_dict_weight: Boolean = False;
        const dict_weight: Integer = 0);
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

        item.text := text;
        item.comment := comment;
        item.score := score_with_bonus;
        item.source := source;
        item.has_dict_weight := (source = cs_rule) and has_dict_weight;
        item.dict_weight := dict_weight;
        list.Add(item);
        seen.Add(key, True);
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
                    cs_ai:
                        Result := 2;
                else
                    Result := 3;
                end;
                case right.source of
                    cs_user:
                        Dec(Result, 0);
                    cs_rule:
                        Dec(Result, 1);
                    cs_ai:
                        Dec(Result, 2);
                else
                    Dec(Result, 3);
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
        if full_pinyin_query then
        begin
            typo_min_query_len := c_typo_min_query_len_full;
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
                            append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                                append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                        if is_likely_noisy_constructed_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        append_candidate(text_value, '', score_value, cs_user);
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
                            jianpin_query_keys) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_user_connection.column_text(stmt, 1);
                        score_value := m_user_connection.column_int(stmt, 2);
                        if normalized_base_entry_exists(candidate_pinyin, text_value) then
                        begin
                            Inc(skipped_base_dup_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if is_likely_noisy_constructed_phrase(candidate_pinyin, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        append_candidate(text_value, '', score_value, cs_user);
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
                        append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                            append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                    stmt := nil;
                    try
                        if m_base_connection.prepare(base_jianpin_prefixed_sql, stmt) and
                            m_base_connection.bind_text(stmt, 1, jianpin_query_keys[query_key_idx]) and
                            m_base_connection.bind_text(stmt, 2, mixed_full_prefix + '%') and
                            m_base_connection.bind_int(stmt, 3, m_limit) then
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
                                append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                    stmt := nil;
                    try
                        if m_base_connection.prepare(base_jianpin_sql, stmt) and
                            m_base_connection.bind_text(stmt, 1, jianpin_query_keys[query_key_idx]) and
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
                                append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                        append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                single_letter_cap_score := list[0].score - 1;
                for i := 1 to list.Count - 1 do
                begin
                    if list[i].score - 1 < single_letter_cap_score then
                    begin
                        single_letter_cap_score := list[i].score - 1;
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

                        append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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
                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - c_initial_single_char_penalty;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True, dict_weight_value);
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

        if c_enable_runtime_homophone_bonus then
        begin
            apply_homophone_commonness_bonus;
        end;

        apply_text_learning_bonus;
        sort_candidate_list_by_score;

        if list.Count > 0 then
        begin
            SetLength(results, list.Count);
            for i := 0 to list.Count - 1 do
            begin
                results[i] := list[i];
            end;
        end;

        m_last_lookup_debug_hint := Format(
            'dict=[full=%d mixed=%d user_nf=%d exact=%d typo=%d dual_jp=%d long_jp_off=%d learn=%d text=%d sc_bad=%d noise=%d dup=%d n=%d]',
            [Ord(full_pinyin_query), Ord(mixed_mode), Ord(user_nonfull_lookup), Ord(exact_base_hit),
            Ord(typo_fallback_used), Ord(full_query_dual_jianpin_mode),
            Ord(disable_long_full_query_jianpin), applied_learning_bonus_count,
            applied_text_learning_bonus_count, skipped_single_char_mismatch_count,
            skipped_noisy_user_count, skipped_base_dup_user_count, list.Count]);
        Result := list.Count > 0;
    finally
        if mixed_parser <> nil then
        begin
            mixed_parser.Free;
        end;
        text_learning_bonus_cache.Free;
        learning_bonus_map.Free;
        list.Free;
        seen.Free;
    end;
end;

function TncSqliteDictionary.single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean;
const
    base_exists_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
var
    pinyin_key: string;
    text_key: string;
    stmt: Psqlite3_stmt;
    step_result: Integer;
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

    stmt := nil;
    try
        if m_base_ready and m_base_connection.prepare(base_exists_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, pinyin_key) and
            m_base_connection.bind_text(stmt, 2, text_key) then
        begin
            step_result := m_base_connection.step(stmt);
            if step_result = SQLITE_ROW then
            begin
                Result := True;
                Exit;
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
            stmt := nil;
        end;
    end;
end;

procedure TncSqliteDictionary.prune_suspicious_user_entries;
const
    select_entries_sql =
        'SELECT pinyin, text, MAX(user_weight), MAX(commit_count) FROM (' +
        'SELECT pinyin, text, weight AS user_weight, 0 AS commit_count FROM dict_user ' +
        'UNION ALL ' +
        'SELECT pinyin, text, 0 AS user_weight, commit_count FROM dict_user_stats' +
        ') GROUP BY pinyin, text';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    text_unit_count: Integer;
    user_weight: Integer;
    commit_count: Integer;
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
            text_unit_count := get_valid_cjk_codepoint_count(text_value);

            if (pinyin_value <> '') and (text_unit_count = 1) and is_full_pinyin_key(pinyin_value) and
                (not single_char_matches_pinyin(pinyin_value, text_value)) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, False);
            end
            else if is_likely_noisy_constructed_phrase(pinyin_value, text_value, commit_count, user_weight) then
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
    update_sql = 'UPDATE dict_user SET weight = weight + 1, last_used = strftime(''%s'',''now'') ' +
        'WHERE pinyin = ?1 AND text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user(pinyin, text, weight, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    full_pinyin_input: Boolean;
    base_entry_exists: Boolean;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    if (pinyin_key = '') or (text = '') or (not is_valid_learning_text(text)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    full_pinyin_input := is_full_pinyin_key(pinyin_key);
    if full_pinyin_input and (get_valid_cjk_codepoint_count(text) = 1) and
        (not single_char_matches_pinyin(pinyin_key, text)) then
    begin
        purge_user_entry_internal(pinyin_key, text, False, False);
        Exit;
    end;

    base_entry_exists := normalized_base_entry_exists(pinyin_key, text);

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
    if (left_key = '') or (text_key = '') or (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    context_variants := build_context_variants_local(left_key);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    stmt_update := nil;
    stmt_insert := nil;
    try
        if not m_user_connection.prepare(update_sql, stmt_update) then
        begin
            Exit;
        end;
        if not m_user_connection.prepare(insert_sql, stmt_insert) then
        begin
            Exit;
        end;

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
    finally
        if stmt_update <> nil then
        begin
            m_user_connection.finalize(stmt_update);
        end;
        if stmt_insert <> nil then
        begin
            m_user_connection.finalize(stmt_insert);
        end;
    end;

    prune_bigram_rows_if_needed(False);
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

function TncSqliteDictionary.get_candidate_penalty(const pinyin: string; const text: string): Integer;
const
    query_penalty_sql = 'SELECT penalty FROM dict_user_penalty WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
begin
    Result := 0;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(query_penalty_sql, stmt) then
        begin
            Exit;
        end;
        if (not m_user_connection.bind_text(stmt, 1, pinyin_key)) or
            (not m_user_connection.bind_text(stmt, 2, text_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            Result := m_user_connection.column_int(stmt, 0);
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
    delete_user_by_text_sql = 'DELETE FROM dict_user WHERE text = ?1';
    delete_stats_by_text_sql = 'DELETE FROM dict_user_stats WHERE text = ?1';
    delete_bigram_by_text_sql = 'DELETE FROM dict_user_bigram WHERE text = ?1';
    delete_bigram_by_left_sql = 'DELETE FROM dict_user_bigram WHERE left_text = ?1';
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
