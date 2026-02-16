unit nc_dictionary_sqlite;

interface

uses
    System.SysUtils,
    System.Generics.Collections,
    System.Character,
    System.IOUtils,
    Winapi.Windows,
    nc_types,
    nc_dictionary_intf,
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
        'INSERT OR IGNORE INTO meta(key, value) VALUES(''schema_version'', ''1'');' + sLineBreak +
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
        'CREATE TABLE IF NOT EXISTS dict_user (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    UNIQUE(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_pinyin ON dict_user(pinyin);' + sLineBreak;

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

    if not get_schema_version(connection, schema_version) then
    begin
        set_schema_version(connection, 1);
        Result := True;
        Exit;
    end;

    if schema_version < 1 then
    begin
        set_schema_version(connection, 1);
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

        Inc(idx);
    end;

    Result := True;
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
    base_sql = 'SELECT text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
var
    stmt: Psqlite3_stmt;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Boolean>;
    step_result: Integer;
    item: TncCandidate;
    text_value: string;
    comment_value: string;
    score_value: Integer;
    i: Integer;
    key: string;

    procedure append_candidate(const text: string; const comment: string; const score: Integer;
        const source: TncCandidateSource);
    begin
        if text = '' then
        begin
            Exit;
        end;

        key := text;
        if seen.ContainsKey(key) then
        begin
            Exit;
        end;

        item.text := text;
        item.comment := comment;
        item.score := score;
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

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Boolean>.Create;
    try
        if m_user_ready then
        begin
            stmt := nil;
            try
                if m_user_connection.prepare(user_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, pinyin) and
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
                    m_base_connection.bind_text(stmt, 1, pinyin) and
                    m_base_connection.bind_int(stmt, 2, m_limit) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        text_value := m_base_connection.column_text(stmt, 0);
                        comment_value := m_base_connection.column_text(stmt, 1);
                        score_value := m_base_connection.column_int(stmt, 2);
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
        list.Free;
        seen.Free;
    end;
end;

procedure TncSqliteDictionary.record_commit(const pinyin: string; const text: string);
const
    update_sql = 'UPDATE dict_user SET weight = weight + 1, last_used = strftime(''%s'',''now'') ' +
        'WHERE pinyin = ?1 AND text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user(pinyin, text, weight, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
var
    stmt: Psqlite3_stmt;
begin
    if (pinyin = '') or not is_valid_user_text(text) or not ensure_open or (not m_user_ready) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin) and m_user_connection.bind_text(stmt, 2, text) then
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
            if m_user_connection.bind_text(stmt, 1, pinyin) and m_user_connection.bind_text(stmt, 2, text) then
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
