program cassotis_ime_dict_init;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    nc_sqlite in '..\src\common\nc_sqlite.pas';

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_dict_init <db_path> <schema_path> [import_path]');
end;

function load_schema(const schema_path: string; out schema_text: string): Boolean;
begin
    schema_text := '';
    if not FileExists(schema_path) then
    begin
        Result := False;
        Exit;
    end;

    schema_text := TFile.ReadAllText(schema_path, TEncoding.ASCII);
    Result := schema_text <> '';
end;

function split_line(const line: string; out pinyin: string; out text: string; out weight: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    pinyin := '';
    text := '';
    weight := 0;

    parts := line.Split([#9]);
    if Length(parts) < 2 then
    begin
        parts := line.Split([' ']);
    end;

    if Length(parts) < 2 then
    begin
        Exit;
    end;

    pinyin := Trim(parts[0]);
    text := Trim(parts[1]);
    if Length(parts) >= 3 then
    begin
        weight := StrToIntDef(Trim(parts[2]), 0);
    end;

    Result := (pinyin <> '') and (text <> '');
end;

function import_data(const conn: TncSqliteConnection; const import_path: string): Boolean;
const
    insert_sql = 'INSERT INTO dict_base(pinyin, text, weight) VALUES (?1, ?2, ?3);';
var
    reader: TStreamReader;
    stmt: Psqlite3_stmt;
    line: string;
    pinyin: string;
    text: string;
    weight: Integer;
    rc: Integer;
    has_error: Boolean;
    line_count: Integer;
    inserted: Integer;
begin
    Result := False;
    if not FileExists(import_path) then
    begin
        Exit;
    end;

    if not conn.exec('BEGIN IMMEDIATE;') then
    begin
        Exit;
    end;

    reader := TStreamReader.Create(import_path, TEncoding.UTF8);
    stmt := nil;
    has_error := False;
    line_count := 0;
    inserted := 0;
    try
        if not conn.prepare(insert_sql, stmt) then
        begin
            Exit;
        end;

        while not reader.EndOfStream do
        begin
            line := Trim(reader.ReadLine);
            Inc(line_count);
            if line = '' then
            begin
                Continue;
            end;

            if line[1] = '#' then
            begin
                Continue;
            end;

            if not split_line(line, pinyin, text, weight) then
            begin
                Continue;
            end;

            if not conn.bind_text(stmt, 1, pinyin) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_text(stmt, 2, text) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_int(stmt, 3, weight) then
            begin
                has_error := True;
                Break;
            end;

            rc := conn.step(stmt);
            if rc <> SQLITE_DONE then
            begin
                has_error := True;
                Break;
            end;

            Inc(inserted);
            conn.reset(stmt);
            conn.clear_bindings(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            conn.finalize(stmt);
        end;
        reader.Free;
    end;

    if has_error then
    begin
        conn.exec('ROLLBACK;');
        Exit(False);
    end;

    if conn.exec('COMMIT;') then
    begin
        Writeln(Format('Imported %d entries from %d lines.', [inserted, line_count]));
        Result := True;
    end
    else
    begin
        conn.exec('ROLLBACK;');
    end;
end;

var
    db_path: string;
    schema_path: string;
    import_path: string;
    schema_text: string;
    conn: TncSqliteConnection;
begin
    if ParamCount < 2 then
    begin
        print_usage;
        Halt(1);
    end;

    db_path := ParamStr(1);
    schema_path := ParamStr(2);
    if ParamCount >= 3 then
    begin
        import_path := ParamStr(3);
    end
    else
    begin
        import_path := '';
    end;

    if not load_schema(schema_path, schema_text) then
    begin
        Writeln('Schema not found or empty.');
        Halt(1);
    end;

    conn := TncSqliteConnection.Create(db_path);
    try
        if not conn.open then
        begin
            Writeln('Open db failed.');
            Halt(1);
        end;

        if not conn.exec(schema_text) then
        begin
            Writeln('Apply schema failed: ' + conn.errmsg);
            Halt(1);
        end;

        if import_path <> '' then
        begin
            if not import_data(conn, import_path) then
            begin
                Writeln('Import failed: ' + conn.errmsg);
                Halt(1);
            end;
        end;
    finally
        conn.Free;
    end;
end.
