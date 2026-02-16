program cassotis_ime_unihan_import;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    System.Classes,
    System.Generics.Collections,
    System.Character;

type
    TncPinyinMap = TDictionary<Integer, TStringList>;
    TncReadingSourceMap = TDictionary<string, Integer>;

const
    c_source_hanyu_extra = 1;
    c_source_mandarin = 2;
    c_source_pinlu = 3;
    c_hanyu_extra_weight_cap = 160;

function make_reading_key(const codepoint: Integer; const pinyin: string): string;
begin
    Result := IntToHex(codepoint, 6) + ':' + pinyin;
end;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_unihan_import <readings_path> <output_path> [dictlike_path]');
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

function parse_pinlu_token(const token: string; out pinyin: string; out count: Integer): Boolean;
var
    value: string;
    left_pos: Integer;
    right_pos: Integer;
    count_text: string;
begin
    pinyin := '';
    count := 0;
    value := Trim(token);
    if value = '' then
    begin
        Result := False;
        Exit;
    end;

    left_pos := Pos('(', value);
    right_pos := Pos(')', value);
    if (left_pos > 0) and (right_pos > left_pos) then
    begin
        pinyin := Copy(value, 1, left_pos - 1);
        count_text := Copy(value, left_pos + 1, right_pos - left_pos - 1);
        count := StrToIntDef(count_text, 0);
    end
    else
    begin
        pinyin := value;
        count := 0;
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

procedure add_pinyin(const map: TncPinyinMap; const source_map: TncReadingSourceMap;
    const codepoint: Integer; const pinyin: string; const source_rank: Integer);
var
    list: TStringList;
    key: string;
    existing_rank: Integer;
begin
    if pinyin = '' then
    begin
        Exit;
    end;

    list := get_pinyin_list(map, codepoint);
    list.Add(pinyin);

    if source_map <> nil then
    begin
        key := make_reading_key(codepoint, pinyin);
        if source_map.TryGetValue(key, existing_rank) then
        begin
            if source_rank > existing_rank then
            begin
                source_map[key] := source_rank;
            end;
        end
        else
        begin
            source_map.Add(key, source_rank);
        end;
    end;
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

function load_unihan_readings(const readings_path: string; const map: TncPinyinMap;
    const pinlu_map: TDictionary<Integer, Integer>;
    const source_map: TncReadingSourceMap): Boolean;
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
    pinlu_count: Integer;
    current_pinlu: Integer;
    pinlu_seen: TDictionary<Integer, Boolean>;
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
                    add_pinyin(map, source_map, codepoint, pinyin, c_source_mandarin);
                end;
            end
            else if tag = 'kHanyuPinyin' then
            begin
                // Keep secondary readings from kHanyuPinyin even if kHanyuPinlu
                // exists, because Pinlu often only keeps dominant pronunciations.
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
                        add_pinyin(map, source_map, codepoint, normalize_pinyin_token(pinyin), c_source_hanyu_extra);
                    end;
                end;
            end
            else
            begin
                if not pinlu_seen.ContainsKey(codepoint) then
                begin
                    pinlu_seen.Add(codepoint, True);
                end;

                tokens := value.Split([' '], TStringSplitOptions.ExcludeEmpty);
                for part in tokens do
                begin
                    if parse_pinlu_token(part, pinyin, pinlu_count) then
                    begin
                        add_pinyin(map, source_map, codepoint, pinyin, c_source_pinlu);
                        if (pinlu_map <> nil) and (pinlu_count > 0) then
                        begin
                            if pinlu_map.TryGetValue(codepoint, current_pinlu) then
                            begin
                                if pinlu_count > current_pinlu then
                                begin
                                    pinlu_map[codepoint] := pinlu_count;
                                end;
                            end
                            else
                            begin
                                pinlu_map.Add(codepoint, pinlu_count);
                            end;
                        end;
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

procedure apply_manual_overrides(const map: TncPinyinMap; const source_map: TncReadingSourceMap);
const
    c_codepoint_um = $55EF;
begin
    if map = nil then
    begin
        Exit;
    end;

    // Keep a minimal pragmatic override for common IME behavior.
    add_pinyin(map, source_map, c_codepoint_um, 'en', c_source_pinlu);
end;

function load_unihan_frequency(const dictlike_path: string;
    const freq_map: TDictionary<Integer, Integer>;
    const grade_map: TDictionary<Integer, Integer>;
    const core_map: TDictionary<Integer, Integer>): Boolean;
var
    reader: TStreamReader;
    line: string;
    fields: TArray<string>;
    codepoint: Integer;
    tag: string;
    freq_value: Integer;
    grade_value: Integer;
    core_value: string;
    core_coverage: Integer;
    idx: Integer;
begin
    Result := False;
    if (dictlike_path = '') or (not FileExists(dictlike_path)) then
    begin
        Exit;
    end;

    reader := TStreamReader.Create(dictlike_path, TEncoding.UTF8);
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
            if tag = 'kFrequency' then
            begin
                freq_value := StrToIntDef(Trim(fields[2]), 0);
                if freq_value <= 0 then
                begin
                    Continue;
                end;

                if freq_map <> nil then
                begin
                    freq_map.AddOrSetValue(codepoint, freq_value);
                end;
            end
            else if tag = 'kGradeLevel' then
            begin
                grade_value := StrToIntDef(Trim(fields[2]), 0);
                if grade_value <= 0 then
                begin
                    Continue;
                end;

                if grade_map <> nil then
                begin
                    grade_map.AddOrSetValue(codepoint, grade_value);
                end;
            end
            else if tag = 'kUnihanCore2020' then
            begin
                core_value := Trim(fields[2]);
                core_coverage := 0;
                for idx := 1 to Length(core_value) do
                begin
                    if CharInSet(core_value[idx], ['A'..'Z', 'a'..'z']) then
                    begin
                        Inc(core_coverage);
                    end;
                end;

                if (core_coverage > 0) and (core_map <> nil) then
                begin
                    core_map.AddOrSetValue(codepoint, core_coverage);
                end;
            end;
        end;
        Result := True;
    finally
        reader.Free;
    end;
end;

function get_weight(const freq: Integer): Integer;
begin
    case freq of
        1: Result := 500;
        2: Result := 400;
        3: Result := 300;
        4: Result := 200;
        5: Result := 120;
    else
        Result := 80;
    end;
end;

function get_weight_from_pinlu(const freq: Integer): Integer;
begin
    if freq >= 20000 then
    begin
        Result := 600;
    end
    else if freq >= 10000 then
    begin
        Result := 520;
    end
    else if freq >= 5000 then
    begin
        Result := 460;
    end
    else if freq >= 2000 then
    begin
        Result := 400;
    end
    else if freq >= 1000 then
    begin
        Result := 320;
    end
    else if freq >= 500 then
    begin
        Result := 260;
    end
    else if freq >= 200 then
    begin
        Result := 220;
    end
    else if freq >= 100 then
    begin
        Result := 180;
    end
    else if freq >= 50 then
    begin
        Result := 150;
    end
    else if freq >= 20 then
    begin
        Result := 120;
    end
    else if freq >= 10 then
    begin
        Result := 100;
    end
    else
    begin
        Result := 80;
    end;
end;

function get_weight_from_grade(const grade: Integer): Integer;
begin
    case grade of
        1: Result := 360;
        2: Result := 330;
        3: Result := 300;
        4: Result := 270;
        5: Result := 240;
        6: Result := 210;
    else
        Result := 0;
    end;
end;

function get_weight_from_core(const coverage: Integer): Integer;
var
    capped_coverage: Integer;
begin
    if coverage <= 0 then
    begin
        Result := 0;
        Exit;
    end;

    capped_coverage := coverage;
    if capped_coverage > 7 then
    begin
        capped_coverage := 7;
    end;

    Result := 120 + (capped_coverage * 20);
end;

function write_output(const output_path: string; const map: TncPinyinMap;
    const freq_map: TDictionary<Integer, Integer>;
    const pinlu_map: TDictionary<Integer, Integer>;
    const grade_map: TDictionary<Integer, Integer>;
    const core_map: TDictionary<Integer, Integer>;
    const source_map: TncReadingSourceMap): Boolean;
var
    writer: TStreamWriter;
    keys: TList<Integer>;
    codepoint: Integer;
    list: TStringList;
    pinyin: string;
    text: string;
    freq: Integer;
    pinlu_freq: Integer;
    grade_level: Integer;
    core_coverage: Integer;
    weight: Integer;
    candidate_weight: Integer;
    output_weight: Integer;
    reading_source: Integer;
begin
    Result := False;
    if map = nil then
    begin
        Exit;
    end;

    keys := TList<Integer>.Create;
    writer := nil;
    try
        for codepoint in map.Keys do
        begin
            keys.Add(codepoint);
        end;
        keys.Sort;

        writer := TStreamWriter.Create(output_path, False, TEncoding.UTF8);
        for codepoint in keys do
        begin
            if not map.TryGetValue(codepoint, list) then
            begin
                Continue;
            end;

            text := Char.ConvertFromUtf32(codepoint);
            freq := 0;
            pinlu_freq := 0;
            grade_level := 0;
            core_coverage := 0;
            weight := get_weight(0);

            if (pinlu_map <> nil) and pinlu_map.TryGetValue(codepoint, pinlu_freq) then
            begin
                candidate_weight := get_weight_from_pinlu(pinlu_freq);
                if candidate_weight > weight then
                begin
                    weight := candidate_weight;
                end;
            end;

            if (freq_map <> nil) and freq_map.TryGetValue(codepoint, freq) then
            begin
                candidate_weight := get_weight(freq);
                if candidate_weight > weight then
                begin
                    weight := candidate_weight;
                end;
            end;

            if (grade_map <> nil) and grade_map.TryGetValue(codepoint, grade_level) then
            begin
                candidate_weight := get_weight_from_grade(grade_level);
                if candidate_weight > weight then
                begin
                    weight := candidate_weight;
                end;
            end;

            if (core_map <> nil) and core_map.TryGetValue(codepoint, core_coverage) then
            begin
                candidate_weight := get_weight_from_core(core_coverage);
                if candidate_weight > weight then
                begin
                    weight := candidate_weight;
                end;
            end;

            for pinyin in list do
            begin
                if pinyin <> '' then
                begin
                    output_weight := weight;
                    reading_source := c_source_mandarin;
                    if source_map <> nil then
                    begin
                        source_map.TryGetValue(make_reading_key(codepoint, pinyin), reading_source);
                    end;

                    // Keep HanyuPinyin-only readings, but lower their rank so
                    // modern/common Mandarin readings come first.
                    if reading_source <= c_source_hanyu_extra then
                    begin
                        if output_weight > c_hanyu_extra_weight_cap then
                        begin
                            output_weight := c_hanyu_extra_weight_cap;
                        end;
                    end;

                    writer.WriteLine(pinyin + #9 + text + #9 + IntToStr(output_weight));
                end;
            end;
        end;

        Result := True;
    finally
        if writer <> nil then
        begin
            writer.Free;
        end;
        keys.Free;
    end;
end;

var
    readings_path: string;
    dictlike_path: string;
    output_path: string;
    pinyin_map: TncPinyinMap;
    freq_map: TDictionary<Integer, Integer>;
    pinlu_map: TDictionary<Integer, Integer>;
    grade_map: TDictionary<Integer, Integer>;
    core_map: TDictionary<Integer, Integer>;
    source_map: TncReadingSourceMap;
    total_chars: Integer;
begin
    if ParamCount < 2 then
    begin
        print_usage;
        Halt(1);
    end;

    readings_path := ParamStr(1);
    output_path := ParamStr(2);
    if ParamCount >= 3 then
    begin
        dictlike_path := ParamStr(3);
    end
    else
    begin
        dictlike_path := '';
    end;

    pinyin_map := TncPinyinMap.Create;
    freq_map := TDictionary<Integer, Integer>.Create;
    pinlu_map := TDictionary<Integer, Integer>.Create;
    grade_map := TDictionary<Integer, Integer>.Create;
    core_map := TDictionary<Integer, Integer>.Create;
    source_map := TncReadingSourceMap.Create;
    try
        if not load_unihan_readings(readings_path, pinyin_map, pinlu_map, source_map) then
        begin
            Writeln('Load Unihan readings failed.');
            Halt(1);
        end;
        apply_manual_overrides(pinyin_map, source_map);

        if dictlike_path <> '' then
        begin
            if not load_unihan_frequency(dictlike_path, freq_map, grade_map, core_map) then
            begin
                Writeln('Load Unihan frequency failed.');
            end;
        end;

        total_chars := pinyin_map.Count;
        Writeln(Format('Loaded %d characters.', [total_chars]));
        if write_output(output_path, pinyin_map, freq_map, pinlu_map, grade_map, core_map, source_map) then
        begin
            Writeln('Output saved: ' + output_path);
        end
        else
        begin
            Writeln('Output failed.');
            Halt(1);
        end;
    finally
        free_pinyin_map(pinyin_map);
        freq_map.Free;
        pinlu_map.Free;
        grade_map.Free;
        core_map.Free;
        source_map.Free;
    end;
end.
