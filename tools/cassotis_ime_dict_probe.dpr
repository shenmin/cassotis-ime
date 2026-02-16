program cassotis_ime_dict_probe;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    nc_sqlite in '..\src\common\nc_sqlite.pas';

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_dict_probe <base_db_path> <pinyin> [user_db_path]');
end;

function probe_entries(const db_path: string; const sql_text: string; const pinyin: string;
    const label_text: string; out count: Integer): Boolean;
var
    conn: TncSqliteConnection;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    item_text: string;
    item_weight: Integer;
begin
    Result := False;
    if (db_path = '') or (pinyin = '') then
    begin
        Exit;
    end;

    conn := TncSqliteConnection.create(db_path);
    try
        if not conn.open then
        begin
            Writeln('Open db failed: ' + conn.errmsg);
            Exit;
        end;

        stmt := nil;
        try
            if not conn.prepare(sql_text, stmt) then
            begin
                Writeln('Prepare failed: ' + conn.errmsg);
                Exit;
            end;

            if not conn.bind_text(stmt, 1, pinyin) then
            begin
                Writeln('Bind failed: ' + conn.errmsg);
                Exit;
            end;

            count := 0;
            Writeln('[' + label_text + ']');
            step_result := conn.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                item_text := conn.column_text(stmt, 0);
                item_weight := conn.column_int(stmt, 1);
                Inc(count);
                Writeln(Format('%d. %s  weight=%d',
                    [count, item_text, item_weight]));
                step_result := conn.step(stmt);
            end;

            if count = 0 then
            begin
                Writeln('No entries found.');
            end;
            Result := True;
        finally
            if stmt <> nil then
            begin
                conn.finalize(stmt);
            end;
        end;
    finally
        conn.Free;
    end;
end;

function probe_dictionary(const base_db_path: string; const pinyin: string; const user_db_path: string): Boolean;
const
    base_sql =
        'SELECT text, weight ' +
        'FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC ' +
        'LIMIT 30';
    user_sql =
        'SELECT text, weight ' +
        'FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC ' +
        'LIMIT 30';
var
    count: Integer;
begin
    Result := False;
    if not probe_entries(base_db_path, base_sql, pinyin, 'base', count) then
    begin
        Exit;
    end;

    if user_db_path <> '' then
    begin
        if not probe_entries(user_db_path, user_sql, pinyin, 'user', count) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

var
    base_db_path: string;
    user_db_path: string;
    pinyin: string;
begin
    if ParamCount < 2 then
    begin
        print_usage;
        Halt(1);
    end;

    base_db_path := ParamStr(1);
    pinyin := ParamStr(2);
    if ParamCount >= 3 then
    begin
        user_db_path := ParamStr(3);
    end
    else
    begin
        user_db_path := '';
    end;

    if not probe_dictionary(base_db_path, pinyin, user_db_path) then
    begin
        Halt(1);
    end;
end.
