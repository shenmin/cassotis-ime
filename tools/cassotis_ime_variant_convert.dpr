program cassotis_ime_variant_convert;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    System.Classes,
    System.Generics.Collections,
    System.Character;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_variant_convert <variants_path> <input_path> <output_path> [mode]');
    Writeln('  mode: s2t (default), t2s, filter_sc, filter_tc');
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

function strip_variant_token(const token: string): string;
var
    cut_pos: Integer;
begin
    Result := Trim(token);
    cut_pos := Pos('<', Result);
    if cut_pos > 0 then
    begin
        Result := Copy(Result, 1, cut_pos - 1);
    end;
end;

function load_variant_map(const variants_path: string; const mode: string;
    const map: TDictionary<Integer, Integer>): Boolean;
var
    reader: TStreamReader;
    line: string;
    fields: TArray<string>;
    codepoint: Integer;
    tag: string;
    value: string;
    tokens: TArray<string>;
    token: string;
    target_codepoint: Integer;
    target_token: string;
    distinct_target: Integer;
    use_s2t: Boolean;
    use_t2s: Boolean;
begin
    Result := False;
    if not FileExists(variants_path) then
    begin
        Exit;
    end;

    use_s2t := SameText(mode, 's2t') or (mode = '');
    use_t2s := SameText(mode, 't2s');

    reader := TStreamReader.Create(variants_path, TEncoding.UTF8);
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

            tag := fields[1];
            if use_s2t and (tag <> 'kTraditionalVariant') then
            begin
                Continue;
            end;

            if use_t2s and (tag <> 'kSimplifiedVariant') then
            begin
                Continue;
            end;

            value := fields[2];
            tokens := value.Split([' ']);
            distinct_target := 0;
            for token in tokens do
            begin
                target_token := strip_variant_token(token);
                if parse_codepoint(target_token, target_codepoint) then
                begin
                    if target_codepoint <> codepoint then
                    begin
                        distinct_target := target_codepoint;
                        Break;
                    end;
                end;
            end;

            if (distinct_target <> 0) and (not map.ContainsKey(codepoint)) then
            begin
                map.Add(codepoint, distinct_target);
            end;
        end;
    finally
        reader.Free;
    end;

    Result := map.Count > 0;
end;

function load_exclude_set(const variants_path: string; const mode: string;
    const exclude: TDictionary<Integer, Boolean>): Boolean;
var
    reader: TStreamReader;
    line: string;
    fields: TArray<string>;
    codepoint: Integer;
    tag: string;
    value: string;
    tokens: TArray<string>;
    token: string;
    target_token: string;
    target_codepoint: Integer;
    has_distinct_variant: Boolean;
    use_filter_sc: Boolean;
    use_filter_tc: Boolean;
begin
    Result := False;
    if not FileExists(variants_path) then
    begin
        Exit;
    end;

    use_filter_sc := SameText(mode, 'filter_sc') or SameText(mode, 'sc');
    use_filter_tc := SameText(mode, 'filter_tc') or SameText(mode, 'tc');
    if not (use_filter_sc or use_filter_tc) then
    begin
        Exit;
    end;

    reader := TStreamReader.Create(variants_path, TEncoding.UTF8);
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

            tag := fields[1];
            if use_filter_sc and (tag <> 'kSimplifiedVariant') then
            begin
                Continue;
            end;

            if use_filter_tc and (tag <> 'kTraditionalVariant') then
            begin
                Continue;
            end;

            value := fields[2];
            tokens := value.Split([' '], TStringSplitOptions.ExcludeEmpty);
            has_distinct_variant := False;
            for token in tokens do
            begin
                target_token := strip_variant_token(token);
                if parse_codepoint(target_token, target_codepoint) then
                begin
                    if target_codepoint <> codepoint then
                    begin
                        has_distinct_variant := True;
                        Break;
                    end;
                end;
            end;

            if not has_distinct_variant then
            begin
                Continue;
            end;

            if not exclude.ContainsKey(codepoint) then
            begin
                exclude.Add(codepoint, True);
            end;
        end;
    finally
        reader.Free;
    end;

    Result := exclude.Count > 0;
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

function is_surrogate_char(const value: Char): Boolean;
var
    code: Integer;
begin
    code := Ord(value);
    Result := (code >= $D800) and (code <= $DFFF);
end;

function try_read_codepoint(const input_text: string; var idx: Integer; out codepoint: Integer): Boolean;
var
    high_surrogate: Integer;
    low_surrogate: Integer;
begin
    Result := False;
    codepoint := 0;
    if (idx < 1) or (idx > Length(input_text)) then
    begin
        Exit;
    end;

    codepoint := Ord(input_text[idx]);
    if (codepoint >= $D800) and (codepoint <= $DBFF) then
    begin
        if idx >= Length(input_text) then
        begin
            Exit(False);
        end;

        high_surrogate := codepoint;
        low_surrogate := Ord(input_text[idx + 1]);
        if (low_surrogate < $DC00) or (low_surrogate > $DFFF) then
        begin
            Exit(False);
        end;

        codepoint := ((high_surrogate - $D800) shl 10) + (low_surrogate - $DC00) + $10000;
        Inc(idx, 2);
        Result := True;
        Exit;
    end;

    if (codepoint >= $DC00) and (codepoint <= $DFFF) then
    begin
        Exit(False);
    end;

    Inc(idx);
    Result := True;
end;

function should_keep_text(const input_text: string; const exclude: TDictionary<Integer, Boolean>): Boolean;
var
    idx: Integer;
    codepoint: Integer;
begin
    Result := True;
    if (exclude = nil) or (input_text = '') then
    begin
        Exit;
    end;

    idx := 1;
    while idx <= Length(input_text) do
    begin
        if not try_read_codepoint(input_text, idx, codepoint) then
        begin
            Exit(False);
        end;

        if exclude.ContainsKey(codepoint) then
        begin
            Exit(False);
        end;
    end;
end;

function convert_text(const input_text: string; const map: TDictionary<Integer, Integer>): string;
var
    idx: Integer;
    codepoint: Integer;
    mapped: Integer;
    builder: TStringBuilder;
    ch: Char;
begin
    builder := TStringBuilder.Create;
    try
        idx := 1;
        while idx <= Length(input_text) do
        begin
            ch := input_text[idx];
            if not try_read_codepoint(input_text, idx, codepoint) then
            begin
                // Preserve invalid standalone surrogate as-is.
                builder.Append(ch);
                Inc(idx);
                Continue;
            end;

            if map.TryGetValue(codepoint, mapped) then
            begin
                codepoint := mapped;
            end;

            if codepoint <= $FFFF then
            begin
                builder.Append(Char(codepoint));
            end
            else
            begin
                builder.Append(Char.ConvertFromUtf32(codepoint));
            end;
        end;
        Result := builder.ToString;
    finally
        builder.Free;
    end;
end;

var
    variants_path: string;
    input_path: string;
    output_path: string;
    mode: string;
    reader: TStreamReader;
    writer: TStreamWriter;
    line: string;
    pinyin: string;
    text: string;
    weight: Integer;
    map: TDictionary<Integer, Integer>;
    exclude: TDictionary<Integer, Boolean>;
    output_rows: TDictionary<string, Integer>;
    output_keys: TList<string>;
    converted_text: string;
    do_convert: Boolean;
    do_filter: Boolean;
    use_filter_sc: Boolean;
    use_filter_tc: Boolean;
    key: string;
    existing_weight: Integer;
begin
    if ParamCount < 3 then
    begin
        print_usage;
        Halt(1);
    end;

    variants_path := ParamStr(1);
    input_path := ParamStr(2);
    output_path := ParamStr(3);
    if ParamCount >= 4 then
    begin
        mode := ParamStr(4);
    end
    else
    begin
        mode := 's2t';
    end;

    if not FileExists(input_path) then
    begin
        Writeln('Input file not found.');
        Halt(1);
    end;

    map := TDictionary<Integer, Integer>.Create;
    exclude := TDictionary<Integer, Boolean>.Create;
    output_rows := TDictionary<string, Integer>.Create;
    try
        use_filter_sc := SameText(mode, 'filter_sc') or SameText(mode, 'sc');
        use_filter_tc := SameText(mode, 'filter_tc') or SameText(mode, 'tc');
        do_filter := use_filter_sc or use_filter_tc;
        do_convert := not do_filter;

        if do_convert then
        begin
            if not load_variant_map(variants_path, mode, map) then
            begin
                Writeln('Variant map not found or empty.');
                Halt(1);
            end;
        end
        else
        begin
            if not load_exclude_set(variants_path, mode, exclude) then
            begin
                Writeln('Variant exclude set not found or empty.');
                Halt(1);
            end;

            // In filter mode, also load conversion map so we can merge variant
            // weights into the kept script form (e.g. 語 -> 语).
            if use_filter_sc then
            begin
                load_variant_map(variants_path, 't2s', map);
            end
            else if use_filter_tc then
            begin
                load_variant_map(variants_path, 's2t', map);
            end;
        end;

        reader := TStreamReader.Create(input_path, TEncoding.UTF8);
        try
            while not reader.EndOfStream do
            begin
                line := Trim(reader.ReadLine);
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

                converted_text := text;
                if do_filter then
                begin
                    if should_keep_text(text, exclude) then
                    begin
                        if map.Count > 0 then
                        begin
                            converted_text := convert_text(text, map);
                        end;
                    end
                    else
                    begin
                        if map.Count = 0 then
                        begin
                            Continue;
                        end;
                        converted_text := convert_text(text, map);
                    end;
                end
                else if do_convert then
                begin
                    converted_text := convert_text(text, map);
                end;

                if converted_text = '' then
                begin
                    Continue;
                end;

                key := pinyin + #9 + converted_text;
                if output_rows.TryGetValue(key, existing_weight) then
                begin
                    if weight > existing_weight then
                    begin
                        output_rows[key] := weight;
                    end;
                end
                else
                begin
                    output_rows.Add(key, weight);
                end;
            end;
        finally
            reader.Free;
        end;

        writer := TStreamWriter.Create(output_path, False, TEncoding.UTF8);
        output_keys := TList<string>.Create;
        try
            for key in output_rows.Keys do
            begin
                output_keys.Add(key);
            end;
            output_keys.Sort;

            for key in output_keys do
            begin
                writer.WriteLine(key + #9 + IntToStr(output_rows[key]));
            end;
        finally
            writer.Free;
            output_keys.Free;
        end;
    finally
        output_rows.Free;
        map.Free;
        exclude.Free;
    end;
end.
