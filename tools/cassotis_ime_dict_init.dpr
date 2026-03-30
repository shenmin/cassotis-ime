program cassotis_ime_dict_init;

{$APPTYPE CONSOLE}
{$R 'cassotis_ime_dict_init.res'}

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.Generics.Collections,
    nc_pinyin_parser in '..\src\engine\nc_pinyin_parser.pas',
    nc_sqlite in '..\src\common\nc_sqlite.pas';

type
    TncImportMode = (imBaseDict, imQueryPathPrior);

const
    c_segment_path_separator = #3;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_dict_init <db_path> <schema_path> [import_path] [base|query_path]');
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

function split_query_path_line(const line: string; out query_pinyin: string;
    out path_text: string; out weight: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    query_pinyin := '';
    path_text := '';
    weight := 0;

    parts := line.Split([#9]);
    if Length(parts) < 2 then
    begin
        Exit;
    end;

    query_pinyin := Trim(parts[0]);
    path_text := Trim(parts[1]);
    if Length(parts) >= 3 then
    begin
        weight := StrToIntDef(Trim(parts[2]), 0);
    end;

    Result := (query_pinyin <> '') and (path_text <> '');
end;

function normalize_pinyin_key(const value: string): string;
begin
    Result := LowerCase(Trim(value));
    Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
    Result := StringReplace(Result, '''', '', [rfReplaceAll]);
{$IF FALSE}
    Result := StringReplace(Result, '’', '', [rfReplaceAll]);
end;
{$ENDIF}
end;

function normalize_query_path_text(const value: string): string;
var
    idx: Integer;
    ch: Char;
    builder: TStringBuilder;
    last_was_separator: Boolean;
begin
    builder := TStringBuilder.Create;
    try
        last_was_separator := False;
        for idx := 1 to Length(value) do
        begin
            ch := value[idx];
            if CharInSet(ch, ['|', '/', #3]) then
            begin
                if not last_was_separator then
                begin
                    builder.Append(c_segment_path_separator);
                    last_was_separator := True;
                end;
                Continue;
            end;

            if not CharInSet(ch, [#9, #10, #13, ' ']) then
            begin
                builder.Append(ch);
                last_was_separator := False;
            end;
        end;

        Result := builder.ToString;
        while (Result <> '') and (Result[1] = c_segment_path_separator) do
        begin
            Delete(Result, 1, 1);
        end;
        while (Result <> '') and (Result[Length(Result)] = c_segment_path_separator) do
        begin
            Delete(Result, Length(Result), 1);
        end;
    finally
        builder.Free;
    end;
end;

function get_query_path_segment_count(const encoded_path: string): Integer;
var
    idx: Integer;
begin
    Result := 0;
    if encoded_path = '' then
    begin
        Exit;
    end;

    Result := 1;
    for idx := 1 to Length(encoded_path) do
    begin
        if encoded_path[idx] = c_segment_path_separator then
        begin
            Inc(Result);
        end;
    end;
end;

function parse_import_mode(const value: string; const import_path: string): TncImportMode;
var
    normalized: string;
begin
    normalized := LowerCase(Trim(value));
    if normalized = '' then
    begin
        normalized := LowerCase(ExtractFileName(import_path));
        if Pos('query_path', normalized) > 0 then
        begin
            Exit(imQueryPathPrior);
        end;
        Exit(imBaseDict);
    end;

    if (normalized = 'query_path') or (normalized = 'query-path') or
        (normalized = 'path') or (normalized = 'querypath') then
    begin
        Exit(imQueryPathPrior);
    end;

    Result := imBaseDict;
end;

function is_ascii_lower_text(const value: string): Boolean;
var
    i: Integer;
    ch: Char;
begin
    Result := value <> '';
    if not Result then
    begin
        Exit;
    end;

    for i := 1 to Length(value) do
    begin
        ch := value[i];
        if (ch < 'a') or (ch > 'z') then
        begin
            Result := False;
            Exit;
        end;
    end;
end;

function is_valid_parsed_syllable(const syllable: string): Boolean;
begin
    if not is_ascii_lower_text(syllable) then
    begin
        Result := False;
        Exit;
    end;

    if Length(syllable) = 1 then
    begin
        Result := (syllable = 'a') or (syllable = 'e') or (syllable = 'o');
        Exit;
    end;

    Result := True;
end;

function build_jianpin_variants(const pinyin: string; out variants: TArray<string>): Boolean;
const
    c_jianpin_variant_limit = 64;
type
    TncJianpinPart = record
        short_key: string;
        full_key: string;
    end;
var
    parser: TncPinyinParser;
    parsed: TncPinyinParseResult;
    normalized: string;
    parts: TArray<TncJianpinPart>;
    variant_list: TList<string>;
    dedup: TDictionary<string, Boolean>;
    i: Integer;
    syllable: string;
    part: TncJianpinPart;

    procedure append_unique_variant(const value: string);
    begin
        if (value = '') or dedup.ContainsKey(value) then
        begin
            Exit;
        end;

        dedup.Add(value, True);
        variant_list.Add(value);
    end;

    procedure expand_variants(const index: Integer; const prefix: string);
    begin
        if variant_list.Count >= c_jianpin_variant_limit then
        begin
            Exit;
        end;

        if index >= Length(parts) then
        begin
            append_unique_variant(prefix);
            Exit;
        end;

        expand_variants(index + 1, prefix + parts[index].short_key);
        if (parts[index].full_key <> parts[index].short_key) and
            (variant_list.Count < c_jianpin_variant_limit) then
        begin
            expand_variants(index + 1, prefix + parts[index].full_key);
        end;
    end;
begin
    SetLength(variants, 0);
    normalized := normalize_pinyin_key(pinyin);
    if normalized = '' then
    begin
        Result := False;
        Exit;
    end;

    parser := TncPinyinParser.Create;
    try
        parsed := parser.parse(normalized);
    finally
        parser.Free;
    end;

    if Length(parsed) < 2 then
    begin
        Result := False;
        Exit;
    end;

    SetLength(parts, Length(parsed));
    for i := 0 to High(parsed) do
    begin
        syllable := parsed[i].text;
        if not is_valid_parsed_syllable(syllable) then
        begin
            Result := False;
            Exit;
        end;

        part.short_key := Copy(syllable, 1, 1);
        part.full_key := part.short_key;
        if syllable.StartsWith('zh') then
        begin
            part.full_key := 'zh';
        end
        else if syllable.StartsWith('ch') then
        begin
            part.full_key := 'ch';
        end
        else if syllable.StartsWith('sh') then
        begin
            part.full_key := 'sh';
        end;
        parts[i] := part;
    end;

    variant_list := TList<string>.Create;
    dedup := TDictionary<string, Boolean>.Create;
    try
        expand_variants(0, '');
        if variant_list.Count <= 0 then
        begin
            Result := False;
            Exit;
        end;

        SetLength(variants, variant_list.Count);
        for i := 0 to variant_list.Count - 1 do
        begin
            variants[i] := variant_list[i];
        end;
    finally
        variant_list.Free;
        dedup.Free;
    end;

    Result := Length(variants) > 0;
end;

function import_data(const conn: TncSqliteConnection; const import_path: string;
    const import_mode: TncImportMode): Boolean;
const
    insert_base_sql = 'INSERT INTO dict_base(pinyin, text, weight) VALUES (?1, ?2, ?3);';
    insert_jianpin_sql = 'INSERT OR IGNORE INTO dict_jianpin(word_id, jianpin, weight) VALUES (?1, ?2, ?3);';
    select_last_rowid_sql = 'SELECT last_insert_rowid()';
    insert_query_path_sql =
        'INSERT OR REPLACE INTO dict_base_query_path(query_pinyin, path_text, weight) VALUES (?1, ?2, ?3);';
var
    reader: TStreamReader;
    stmt_base: Psqlite3_stmt;
    stmt_jianpin: Psqlite3_stmt;
    stmt_last_rowid: Psqlite3_stmt;
    stmt_query_path: Psqlite3_stmt;
    line: string;
    pinyin: string;
    text: string;
    weight: Integer;
    word_id: Integer;
    rc: Integer;
    has_error: Boolean;
    line_count: Integer;
    inserted: Integer;
    inserted_jianpin: Integer;
    inserted_query_paths: Integer;
    jianpin_variants: TArray<string>;
    jianpin_value: string;
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
    stmt_base := nil;
    stmt_jianpin := nil;
    stmt_last_rowid := nil;
    stmt_query_path := nil;
    has_error := False;
    line_count := 0;
    inserted := 0;
    inserted_jianpin := 0;
    inserted_query_paths := 0;
    try
        if import_mode = imQueryPathPrior then
        begin
            if not conn.prepare(insert_query_path_sql, stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if not conn.prepare(insert_base_sql, stmt_base) or
            (not conn.prepare(insert_jianpin_sql, stmt_jianpin)) or
            (not conn.prepare(select_last_rowid_sql, stmt_last_rowid)) then
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

            if import_mode = imQueryPathPrior then
            begin
                if not split_query_path_line(line, pinyin, text, weight) then
                begin
                    Continue;
                end;

                pinyin := normalize_pinyin_key(pinyin);
                text := normalize_query_path_text(text);
                if (pinyin = '') or (text = '') or
                    (get_query_path_segment_count(text) <= 1) or (weight <= 0) then
                begin
                    Continue;
                end;

                if (not conn.bind_text(stmt_query_path, 1, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 2, text)) or
                    (not conn.bind_int(stmt_query_path, 3, weight)) then
                begin
                    has_error := True;
                    Break;
                end;

                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;

                Inc(inserted_query_paths);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if not split_line(line, pinyin, text, weight) then
            begin
                Continue;
            end;

            pinyin := normalize_pinyin_key(pinyin);
            if pinyin = '' then
            begin
                Continue;
            end;

            if not conn.bind_text(stmt_base, 1, pinyin) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_text(stmt_base, 2, text) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_int(stmt_base, 3, weight) then
            begin
                has_error := True;
                Break;
            end;

            rc := conn.step(stmt_base);
            if rc <> SQLITE_DONE then
            begin
                has_error := True;
                Break;
            end;

            if (not conn.reset(stmt_base)) or (not conn.clear_bindings(stmt_base)) then
            begin
                has_error := True;
                Break;
            end;

            rc := conn.step(stmt_last_rowid);
            if rc <> SQLITE_ROW then
            begin
                has_error := True;
                Break;
            end;
            word_id := conn.column_int(stmt_last_rowid, 0);
            if (not conn.reset(stmt_last_rowid)) or (not conn.clear_bindings(stmt_last_rowid)) then
            begin
                has_error := True;
                Break;
            end;
            if word_id <= 0 then
            begin
                has_error := True;
                Break;
            end;

            if build_jianpin_variants(pinyin, jianpin_variants) then
            begin
                for jianpin_value in jianpin_variants do
                begin
                    if (not conn.bind_int(stmt_jianpin, 1, word_id)) or
                        (not conn.bind_text(stmt_jianpin, 2, jianpin_value)) or
                        (not conn.bind_int(stmt_jianpin, 3, weight)) then
                    begin
                        has_error := True;
                        Break;
                    end;

                    rc := conn.step(stmt_jianpin);
                    if rc <> SQLITE_DONE then
                    begin
                        has_error := True;
                        Break;
                    end;

                    Inc(inserted_jianpin);
                    if (not conn.reset(stmt_jianpin)) or (not conn.clear_bindings(stmt_jianpin)) then
                    begin
                        has_error := True;
                        Break;
                    end;
                end;
            end;
            if has_error then
            begin
                Break;
            end;

            Inc(inserted);
        end;
    finally
        if stmt_base <> nil then
        begin
            conn.finalize(stmt_base);
        end;
        if stmt_jianpin <> nil then
        begin
            conn.finalize(stmt_jianpin);
        end;
        if stmt_last_rowid <> nil then
        begin
            conn.finalize(stmt_last_rowid);
        end;
        if stmt_query_path <> nil then
        begin
            conn.finalize(stmt_query_path);
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
        if import_mode = imQueryPathPrior then
        begin
            Writeln(Format('Imported %d query-path prior rows from %d lines.',
                [inserted_query_paths, line_count]));
        end
        else
        begin
            Writeln(Format('Imported %d entries (%d jianpin rows) from %d lines.',
                [inserted, inserted_jianpin, line_count]));
        end;
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
    import_mode: TncImportMode;
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
    if ParamCount >= 4 then
    begin
        import_mode := parse_import_mode(ParamStr(4), import_path);
    end
    else
    begin
        import_mode := parse_import_mode('', import_path);
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
            if not import_data(conn, import_path, import_mode) then
            begin
                Writeln('Import failed: ' + conn.errmsg);
                Halt(1);
            end;
        end;
    finally
        conn.Free;
    end;
end.
