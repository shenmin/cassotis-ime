unit nc_dictionary_sqlite;

interface

uses
    System.SysUtils,
    System.Math,
    System.DateUtils,
    System.Generics.Collections,
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
        m_base_connection: TncSqliteConnection;
        m_user_connection: TncSqliteConnection;
        function ensure_open: Boolean;
        function get_module_dir: string;
        function find_schema_path: string;
        function load_schema_text(out schema_text: string): Boolean;
        function ensure_schema(const connection: TncSqliteConnection): Boolean;
        function get_schema_version(const connection: TncSqliteConnection; out version: Integer): Boolean;
        procedure set_schema_version(const connection: TncSqliteConnection; const version: Integer);
        function is_valid_user_text(const text: string): Boolean;
        function get_user_entry_count(const connection: TncSqliteConnection; out count: Integer): Boolean;
        procedure migrate_user_entries;
        procedure prune_user_entries_existing_in_base;
    public
        constructor create(const base_db_path: string; const user_db_path: string);
        destructor Destroy; override;
        function open: Boolean;
        procedure close;
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; override;
        procedure record_commit(const pinyin: string; const text: string); override;
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
        'INSERT OR IGNORE INTO meta(key, value) VALUES(''schema_version'', ''3'');' + sLineBreak +
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
        'CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);' + sLineBreak;

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

function get_unix_time_now: Int64;
begin
    Result := DateTimeToUnix(Now, False);
end;

function calc_learning_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_freq_bonus_factor = 80.0;
    c_freq_bonus_max = 500;
    c_recent_bonus_1d = 120;
    c_recent_bonus_7d = 80;
    c_recent_bonus_30d = 40;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_week = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
var
    freq_bonus: Integer;
    recency_bonus: Integer;
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
        else if age_seconds <= c_sec_per_week then
        begin
            recency_bonus := c_recent_bonus_7d;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := c_recent_bonus_30d;
        end;
    end;

    Result := freq_bonus + recency_bonus;
end;

function parse_mixed_jianpin_query(const query_key: string; out full_prefix: string; out suffix_initials: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    has_vowel: Boolean;
    ch: Char;
begin
    Result := False;
    full_prefix := '';
    suffix_initials := '';
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

    full_prefix := syllables[0].text;
    if Length(full_prefix) < 2 then
    begin
        Exit;
    end;

    has_vowel := False;
    for ch in full_prefix do
    begin
        if CharInSet(ch, ['a', 'e', 'i', 'o', 'u', 'v']) then
        begin
            has_vowel := True;
            Break;
        end;
    end;
    if not has_vowel then
    begin
        Exit;
    end;

    for idx := 1 to High(syllables) do
    begin
        if (Length(syllables[idx].text) <> 1) or (not CharInSet(syllables[idx].text[1], ['a'..'z'])) then
        begin
            suffix_initials := '';
            Exit;
        end;
        suffix_initials := suffix_initials + syllables[idx].text[1];
    end;

    if suffix_initials = '' then
    begin
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
    const full_prefix: string; const suffix_initials: string): Boolean;
var
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (full_prefix = '') or (suffix_initials = '') then
    begin
        Exit;
    end;

    syllables := parser.parse(candidate_pinyin);
    if Length(syllables) <> (1 + Length(suffix_initials)) then
    begin
        Exit;
    end;

    if not is_valid_candidate_syllable(syllables[0].text) then
    begin
        Exit;
    end;

    if not SameText(syllables[0].text, full_prefix) then
    begin
        Exit;
    end;

    for idx := 1 to Length(suffix_initials) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;

        initial_value := extract_syllable_initial(syllables[idx].text);
        if not mixed_initial_matches(suffix_initials[idx], initial_value) then
        begin
            Exit;
        end;
    end;

    Result := True;
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
    m_base_connection := nil;
    m_user_connection := nil;
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

    inherited Destroy;
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

    if not get_schema_version(connection, schema_version) then
    begin
        set_schema_version(connection, 3);
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

function TncSqliteDictionary.is_valid_user_text(const text: string): Boolean;
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
    if text = '' then
    begin
        Result := False;
        Exit;
    end;

    if Pos('`', text) > 0 then
    begin
        Result := False;
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
                Result := False;
                Exit;
            end;

            high_surrogate := codepoint;
            low_surrogate := Ord(text[idx + 1]);
            if (low_surrogate < $DC00) or (low_surrogate > $DFFF) then
            begin
                Result := False;
                Exit;
            end;

            codepoint := ((high_surrogate - $D800) shl 10) + (low_surrogate - $DC00) + $10000;
            Inc(idx);
        end;

        if not is_cjk_codepoint(codepoint) then
        begin
            Result := False;
            Exit;
        end;

        Inc(codepoint_count);
        Inc(idx);
    end;

    // User dictionary should store phrase learning only, not single-character commits.
    Result := codepoint_count >= 2;
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
    base_exists_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
var
    stmt_select: Psqlite3_stmt;
    stmt_base: Psqlite3_stmt;
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
    stmt_base := nil;
    try
        if (not m_user_connection.prepare(select_user_sql, stmt_select)) or
            (not m_base_connection.prepare(base_exists_sql, stmt_base)) then
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
                if m_base_connection.reset(stmt_base) and
                    m_base_connection.clear_bindings(stmt_base) and
                    m_base_connection.bind_text(stmt_base, 1, pinyin_value) and
                    m_base_connection.bind_text(stmt_base, 2, text_value) then
                begin
                    if m_base_connection.step(stmt_base) = SQLITE_ROW then
                    begin
                        keys_to_delete.Add(pinyin_value + #1 + text_value);
                    end;
                end;
            end;

            step_result := m_user_connection.step(stmt_select);
        end;
    finally
        if stmt_base <> nil then
        begin
            m_base_connection.finalize(stmt_base);
        end;
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
        end;
    end;

    if m_base_ready and m_user_ready then
    begin
        migrate_user_entries;
        prune_user_entries_existing_in_base;
    end;

    m_ready := m_base_ready or m_user_ready;
    Result := m_ready;
end;

procedure TncSqliteDictionary.close;
begin
    if m_base_connection <> nil then
    begin
        m_base_connection.close;
    end;
    if m_user_connection <> nil then
    begin
        m_user_connection.close;
    end;

    m_ready := False;
    m_base_ready := False;
    m_user_ready := False;
end;

function TncSqliteDictionary.lookup(const pinyin: string; out results: TncCandidateList): Boolean;
const
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
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
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
    stats_sql = 'SELECT text, commit_count, last_used FROM dict_user_stats WHERE pinyin = ?1';
    c_jianpin_score_penalty = 30;
var
    stmt: Psqlite3_stmt;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Boolean>;
    learning_bonus_map: TDictionary<string, Integer>;
    step_result: Integer;
    item: TncCandidate;
    text_value: string;
    comment_value: string;
    score_value: Integer;
    score_with_bonus: Integer;
    commit_count: Integer;
    last_used_value: Int64;
    learning_bonus: Integer;
    now_unix: Int64;
    i: Integer;
    key: string;
    query_key: string;
    candidate_pinyin: string;
    mixed_prefix: string;
    mixed_initials: string;
    mixed_jianpin_key: string;
    mixed_mode: Boolean;
    full_pinyin_query: Boolean;
    mixed_parser: TncPinyinParser;

    procedure append_candidate(const text: string; const comment: string; const score: Integer;
        const source: TncCandidateSource);
    begin
        if text = '' then
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
        end;

        item.text := text;
        item.comment := comment;
        item.score := score_with_bonus;
        item.source := source;
        list.Add(item);
        seen.Add(key, True);
    end;
begin
    SetLength(results, 0);
    if (pinyin = '') or not ensure_open then
    begin
        Result := False;
        Exit;
    end;
    query_key := LowerCase(pinyin);
    now_unix := get_unix_time_now;
    mixed_mode := parse_mixed_jianpin_query(query_key, mixed_prefix, mixed_initials);
    full_pinyin_query := is_full_pinyin_key(query_key);
    mixed_jianpin_key := query_key;
    if mixed_mode and (mixed_prefix <> '') and (mixed_initials <> '') then
    begin
        // dict_jianpin stores initials-style keys (for example pashan -> ps),
        // while query may be mixed form (for example pas = pa + s).
        mixed_jianpin_key := Copy(mixed_prefix, 1, 1) + mixed_initials;
    end;
    if mixed_mode then
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
                        score_value := m_user_connection.column_int(stmt, 1);
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
                            mixed_prefix, mixed_initials)) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        score_value := m_base_connection.column_int(stmt, 3);
                        append_candidate(text_value, comment_value, score_value, cs_rule);
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

        if (list.Count = 0) and m_base_ready and should_try_jianpin_lookup(query_key) then
        begin
            if mixed_mode then
            begin
                stmt := nil;
                try
                    if m_base_connection.prepare(base_jianpin_prefixed_sql, stmt) and
                        m_base_connection.bind_text(stmt, 1, mixed_jianpin_key) and
                        m_base_connection.bind_text(stmt, 2, mixed_prefix + '%') and
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

                            if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_prefix,
                                mixed_initials) then
                            begin
                                step_result := m_base_connection.step(stmt);
                                Continue;
                            end;

                            text_value := m_base_connection.column_text(stmt, 1);
                            comment_value := m_base_connection.column_text(stmt, 2);
                            score_value := m_base_connection.column_int(stmt, 3) - c_jianpin_score_penalty;
                            append_candidate(text_value, comment_value, score_value, cs_rule);
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

            if list.Count = 0 then
            begin
                stmt := nil;
                try
                    if m_base_connection.prepare(base_jianpin_sql, stmt) and
                        m_base_connection.bind_text(stmt, 1, mixed_jianpin_key) and
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
                                mixed_prefix, mixed_initials)) then
                            begin
                                step_result := m_base_connection.step(stmt);
                                Continue;
                            end;

                            text_value := m_base_connection.column_text(stmt, 1);
                            comment_value := m_base_connection.column_text(stmt, 2);
                            score_value := m_base_connection.column_int(stmt, 3) - c_jianpin_score_penalty;
                            append_candidate(text_value, comment_value, score_value, cs_rule);
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

        if list.Count > 0 then
        begin
            SetLength(results, list.Count);
            for i := 0 to list.Count - 1 do
            begin
                results[i] := list[i];
            end;
        end;

        Result := list.Count > 0;
    finally
        if mixed_parser <> nil then
        begin
            mixed_parser.Free;
        end;
        learning_bonus_map.Free;
        list.Free;
        seen.Free;
    end;
end;

procedure TncSqliteDictionary.record_commit(const pinyin: string; const text: string);
const
    base_exists_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    base_jianpin_exists_sql =
        'SELECT 1 FROM dict_jianpin j INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE j.jianpin = ?1 AND b.text = ?2 LIMIT 1';
    base_mixed_jianpin_exists_sql =
        'SELECT 1 FROM dict_jianpin j INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE j.jianpin = ?1 AND b.text = ?2 AND b.pinyin LIKE ?3 LIMIT 1';
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
    base_has_entry: Boolean;
    full_pinyin_input: Boolean;
    mixed_prefix: string;
    mixed_initials: string;
    mixed_mode: Boolean;
    mixed_jianpin_key: string;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    if (pinyin_key = '') or (text = '') or (not is_valid_user_text(text)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    base_has_entry := False;
    full_pinyin_input := is_full_pinyin_key(pinyin_key);
    mixed_prefix := '';
    mixed_initials := '';
    mixed_jianpin_key := '';
    mixed_mode := parse_mixed_jianpin_query(pinyin_key, mixed_prefix, mixed_initials);
    if mixed_mode and (mixed_prefix <> '') and (mixed_initials <> '') then
    begin
        mixed_jianpin_key := Copy(mixed_prefix, 1, 1) + mixed_initials;
    end;

    if m_base_ready then
    begin
        stmt := nil;
        try
            if m_base_connection.prepare(base_exists_sql, stmt) and
                m_base_connection.bind_text(stmt, 1, pinyin_key) and
                m_base_connection.bind_text(stmt, 2, text) then
            begin
                base_has_entry := m_base_connection.step(stmt) = SQLITE_ROW;
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;

        if not base_has_entry then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_jianpin_exists_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, pinyin_key) and
                    m_base_connection.bind_text(stmt, 2, text) then
                begin
                    base_has_entry := m_base_connection.step(stmt) = SQLITE_ROW;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        if (not base_has_entry) and mixed_mode and (mixed_jianpin_key <> '') then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_mixed_jianpin_exists_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, mixed_jianpin_key) and
                    m_base_connection.bind_text(stmt, 2, text) and
                    m_base_connection.bind_text(stmt, 3, mixed_prefix + '%') then
                begin
                    base_has_entry := m_base_connection.step(stmt) = SQLITE_ROW;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
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

    if base_has_entry or (not full_pinyin_input) then
    begin
        // Keep stats learning, but do not keep dedicated user-word rows for
        // base-covered commits or non-full-pinyin commits.
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

end.
