program cassotis_ime_thuocl_import;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.Generics.Collections,
    System.Character;

type
    TncPinyinMap = TDictionary<Integer, TStringList>;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_thuocl_import <thuocl_path> <unihan_readings_path> <output_path> [min_len]');
end;

function parse_codepoint(const token: string; out codepoint: Integer): Boolean;
var
    hex: string;
begin
    codepoint := 0;
    if (token = '') or (not token.StartsWith('U+')) then
    begin
        Result := False;
        Exit;
    end;

    hex := Copy(token, 3, Length(token) - 2);
    Result := TryStrToInt('$' + hex, codepoint);
end;

function is_han_codepoint(const codepoint: Integer): Boolean;
begin
    Result :=
        ((codepoint >= $3400) and (codepoint <= $4DBF)) or
        ((codepoint >= $4E00) and (codepoint <= $9FFF)) or
        ((codepoint >= $F900) and (codepoint <= $FAFF)) or
        ((codepoint >= $20000) and (codepoint <= $2A6DF)) or
        ((codepoint >= $2A700) and (codepoint <= $2B73F)) or
        ((codepoint >= $2B740) and (codepoint <= $2B81F)) or
        ((codepoint >= $2B820) and (codepoint <= $2CEAF)) or
        ((codepoint >= $2CEB0) and (codepoint <= $2EBEF)) or
        ((codepoint >= $2F800) and (codepoint <= $2FA1F)) or
        ((codepoint >= $30000) and (codepoint <= $3134F)) or
        ((codepoint >= $31350) and (codepoint <= $323AF));
end;

function map_pinyin_char(const ch: Char; out normalized: Char): Boolean;
begin
    case ch of
        'a'..'z':
            begin
                normalized := ch;
                Result := True;
            end;
        #$0101, #$00E1, #$01CE, #$00E0:
            begin
                normalized := 'a';
                Result := True;
            end;
        #$0113, #$00E9, #$011B, #$00E8, #$00EA:
            begin
                normalized := 'e';
                Result := True;
            end;
        #$012B, #$00ED, #$01D0, #$00EC:
            begin
                normalized := 'i';
                Result := True;
            end;
        #$014D, #$00F3, #$01D2, #$00F2:
            begin
                normalized := 'o';
                Result := True;
            end;
        #$016B, #$00FA, #$01D4, #$00F9:
            begin
                normalized := 'u';
                Result := True;
            end;
        #$01D6, #$01D8, #$01DA, #$01DC, #$00FC:
            begin
                normalized := 'v';
                Result := True;
            end;
        #$0144, #$0148, #$01F9:
            begin
                normalized := 'n';
                Result := True;
            end;
        #$1E3F:
            begin
                normalized := 'm';
                Result := True;
            end;
    else
        Result := False;
    end;
end;

function normalize_pinyin_token(const token: string): string;
var
    value: string;
    builder: TStringBuilder;
    i: Integer;
    ch: Char;
    normalized: Char;
begin
    Result := '';
    if token = '' then
    begin
        Exit;
    end;

    value := LowerCase(Trim(token));
    value := StringReplace(value, 'u:', 'v', [rfReplaceAll]);
    value := StringReplace(value, #$00FC, 'v', [rfReplaceAll]);

    builder := TStringBuilder.Create;
    try
        for i := 1 to Length(value) do
        begin
            ch := value[i];
            if (ch >= '1') and (ch <= '5') then
            begin
                Continue;
            end;

            if map_pinyin_char(ch, normalized) then
            begin
                builder.Append(normalized);
            end;
        end;
        Result := builder.ToString;
    finally
        builder.Free;
    end;
end;

function parse_pinlu_token(const token: string; out pinyin: string): Boolean;
var
    value: string;
    left_pos: Integer;
begin
    pinyin := '';
    value := Trim(token);
    if value = '' then
    begin
        Result := False;
        Exit;
    end;

    left_pos := Pos('(', value);
    if left_pos > 0 then
    begin
        pinyin := Copy(value, 1, left_pos - 1);
    end
    else
    begin
        pinyin := value;
    end;

    pinyin := normalize_pinyin_token(pinyin);
    Result := pinyin <> '';
end;

function get_pinyin_list(const map: TncPinyinMap; const codepoint: Integer): TStringList;
begin
    if not map.TryGetValue(codepoint, Result) then
    begin
        Result := TStringList.Create;
        Result.Sorted := True;
        Result.Duplicates := dupIgnore;
        map.Add(codepoint, Result);
    end;
end;

procedure add_pinyin(const map: TncPinyinMap; const codepoint: Integer; const pinyin: string);
var
    list: TStringList;
begin
    if pinyin = '' then
    begin
        Exit;
    end;

    list := get_pinyin_list(map, codepoint);
    list.Add(pinyin);
end;

procedure free_pinyin_map(var map: TncPinyinMap);
var
    pair: TPair<Integer, TStringList>;
begin
    if map = nil then
    begin
        Exit;
    end;

    for pair in map do
    begin
        pair.Value.Free;
    end;
    map.Free;
    map := nil;
end;

function load_unihan_readings(const readings_path: string; const map: TncPinyinMap): Boolean;
var
    reader: TStreamReader;
    line: string;
    fields: TArray<string>;
    codepoint: Integer;
    tag: string;
    value: string;
    tokens: TArray<string>;
    part: string;
    idx: Integer;
    rest: string;
    pinyin: string;
    pinlu_seen: TDictionary<Integer, Boolean>;
    list: TStringList;
begin
    Result := False;
    if not FileExists(readings_path) then
    begin
        Exit;
    end;

    reader := TStreamReader.Create(readings_path, TEncoding.UTF8);
    pinlu_seen := TDictionary<Integer, Boolean>.Create;
    try
        while not reader.EndOfStream do
        begin
            line := reader.ReadLine;
            if line = '' then
            begin
                Continue;
            end;

            if line[1] = '#' then
            begin
                Continue;
            end;

            fields := line.Split([#9]);
            if Length(fields) < 3 then
            begin
                Continue;
            end;

            if not parse_codepoint(fields[0], codepoint) then
            begin
                Continue;
            end;

            if not is_han_codepoint(codepoint) then
            begin
                Continue;
            end;

            tag := fields[1];
            value := fields[2];
            if (tag <> 'kMandarin') and (tag <> 'kHanyuPinyin') and (tag <> 'kHanyuPinlu') then
            begin
                Continue;
            end;

            if tag = 'kMandarin' then
            begin
                if pinlu_seen.ContainsKey(codepoint) then
                begin
                    Continue;
                end;

                tokens := value.Split([' '], TStringSplitOptions.ExcludeEmpty);
                for part in tokens do
                begin
                    pinyin := normalize_pinyin_token(part);
                    add_pinyin(map, codepoint, pinyin);
                end;
            end
            else if tag = 'kHanyuPinyin' then
            begin
                if pinlu_seen.ContainsKey(codepoint) then
                begin
                    Continue;
                end;

                value := value.Replace(';', ' ');
                tokens := value.Split([' '], TStringSplitOptions.ExcludeEmpty);
                for part in tokens do
                begin
                    idx := LastDelimiter(':', part);
                    if idx > 0 then
                    begin
                        rest := Copy(part, idx + 1, Length(part) - idx);
                    end
                    else
                    begin
                        rest := part;
                    end;

                    if rest = '' then
                    begin
                        Continue;
                    end;

                    for pinyin in rest.Split([','], TStringSplitOptions.ExcludeEmpty) do
                    begin
                        add_pinyin(map, codepoint, normalize_pinyin_token(pinyin));
                    end;
                end;
            end
            else
            begin
                if not pinlu_seen.ContainsKey(codepoint) then
                begin
                    pinlu_seen.Add(codepoint, True);
                    list := get_pinyin_list(map, codepoint);
                    list.Clear;
                end;

                tokens := value.Split([' '], TStringSplitOptions.ExcludeEmpty);
                for part in tokens do
                begin
                    if parse_pinlu_token(part, pinyin) then
                    begin
                        add_pinyin(map, codepoint, pinyin);
                    end;
                end;
            end;
        end;
        Result := True;
    finally
        pinlu_seen.Free;
        reader.Free;
    end;
end;

function get_word_weight(const freq: Integer): Integer;
begin
    if freq > 0 then
    begin
        Result := freq;
    end
    else
    begin
        Result := 100;
    end;
end;

function build_word_pinyin(const word: string; const map: TncPinyinMap; out pinyin: string): Boolean;
var
    builder: TStringBuilder;
    idx: Integer;
    codepoint: Integer;
    list: TStringList;
begin
    Result := False;
    pinyin := '';
    if word = '' then
    begin
        Exit;
    end;

    builder := TStringBuilder.Create;
    try
        idx := 1;
        while idx <= Length(word) do
        begin
            if Char.IsSurrogatePair(word, idx) then
            begin
                codepoint := Char.ConvertToUtf32(word, idx);
                Inc(idx, 2);
            end
            else
            begin
                codepoint := Ord(word[idx]);
                Inc(idx);
            end;

            if not is_han_codepoint(codepoint) then
            begin
                Exit;
            end;

            if not map.TryGetValue(codepoint, list) then
            begin
                Exit;
            end;

            if (list = nil) or (list.Count = 0) then
            begin
                Exit;
            end;

            builder.Append(list[0]);
        end;

        pinyin := builder.ToString;
        Result := pinyin <> '';
    finally
        builder.Free;
    end;
end;

procedure collect_files(const thuocl_path: string; const files: TList<string>);
var
    item: string;
    list: TStringList;
begin
    files.Clear;
    if FileExists(thuocl_path) then
    begin
        files.Add(thuocl_path);
        Exit;
    end;

    if DirectoryExists(thuocl_path) then
    begin
        list := TStringList.Create;
        try
            for item in TDirectory.GetFiles(thuocl_path, '*.txt', TSearchOption.soAllDirectories) do
            begin
                list.Add(item);
            end;
            list.Sort;
            for item in list do
            begin
                files.Add(item);
            end;
        finally
            list.Free;
        end;
    end;
end;

function import_thuocl(const thuocl_path: string; const map: TncPinyinMap; const output_path: string;
    const min_len: Integer): Boolean;
var
    files: TList<string>;
    file_path: string;
    reader: TStreamReader;
    line: string;
    parts: TArray<string>;
    word: string;
    pinyin: string;
    freq: Integer;
    weight: Integer;
    writer: TStreamWriter;
    seen: TDictionary<string, Boolean>;
    key: string;
    total_lines: Integer;
    saved_lines: Integer;
begin
    Result := False;
    files := TList<string>.Create;
    seen := TDictionary<string, Boolean>.Create;
    writer := nil;
    total_lines := 0;
    saved_lines := 0;
    try
        collect_files(thuocl_path, files);
        if files.Count = 0 then
        begin
            Exit;
        end;

        writer := TStreamWriter.Create(output_path, False, TEncoding.UTF8);
        for file_path in files do
        begin
            reader := TStreamReader.Create(file_path, TEncoding.UTF8);
            try
                while not reader.EndOfStream do
                begin
                    line := Trim(reader.ReadLine);
                    Inc(total_lines);
                    if line = '' then
                    begin
                        Continue;
                    end;

                    if line[1] = '#' then
                    begin
                        Continue;
                    end;

                    parts := line.Split([#9, ' '], TStringSplitOptions.ExcludeEmpty);
                    if Length(parts) < 1 then
                    begin
                        Continue;
                    end;

                    word := Trim(parts[0]);
                    if word = '' then
                    begin
                        Continue;
                    end;

                    if Length(word) < min_len then
                    begin
                        Continue;
                    end;

                    freq := 0;
                    if Length(parts) >= 2 then
                    begin
                        freq := StrToIntDef(Trim(parts[1]), 0);
                    end;

                    if not build_word_pinyin(word, map, pinyin) then
                    begin
                        Continue;
                    end;

                    key := pinyin + #1 + word;
                    if seen.ContainsKey(key) then
                    begin
                        Continue;
                    end;
                    seen.Add(key, True);

                    weight := get_word_weight(freq);
                    writer.WriteLine(pinyin + #9 + word + #9 + IntToStr(weight));
                    Inc(saved_lines);
                end;
            finally
                reader.Free;
            end;
        end;

        Writeln(Format('Processed %d lines, saved %d entries.', [total_lines, saved_lines]));
        Result := True;
    finally
        if writer <> nil then
        begin
            writer.Free;
        end;
        seen.Free;
        files.Free;
    end;
end;

var
    thuocl_path: string;
    unihan_path: string;
    output_path: string;
    min_len: Integer;
    map: TncPinyinMap;
begin
    if ParamCount < 3 then
    begin
        print_usage;
        Halt(1);
    end;

    thuocl_path := ParamStr(1);
    unihan_path := ParamStr(2);
    output_path := ParamStr(3);
    if ParamCount >= 4 then
    begin
        min_len := StrToIntDef(ParamStr(4), 2);
    end
    else
    begin
        min_len := 2;
    end;

    if min_len < 1 then
    begin
        min_len := 1;
    end;

    map := TncPinyinMap.Create;
    try
        if not load_unihan_readings(unihan_path, map) then
        begin
            Writeln('Load Unihan readings failed.');
            Halt(1);
        end;

        if import_thuocl(thuocl_path, map, output_path, min_len) then
        begin
            Writeln('Output saved: ' + output_path);
        end
        else
        begin
            Writeln('Import failed.');
            Halt(1);
        end;
    finally
        free_pinyin_map(map);
    end;
end.
