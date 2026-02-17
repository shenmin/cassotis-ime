unit nc_ai_text_utils;

interface

uses
    System.SysUtils,
    System.Classes,
    Winapi.Windows,
    nc_types,
    nc_ai_intf,
    nc_pinyin_parser;

function nc_ai_clamp_int(const value: Integer; const min_value: Integer; const max_value: Integer): Integer;
function nc_ai_contains_cjk(const text: string): Boolean;
function nc_ai_sanitize_single_line(const value: string): string;
function nc_ai_tail_text(const value: string; const max_len: Integer): string;
function nc_ai_normalize_candidate_line(const raw_line: string): string;
function nc_ai_build_prompt(const request: TncAiRequest): string;
function nc_ai_get_generation_tokens(const max_suggestions: Integer): Integer;
procedure nc_ai_parse_generated_candidates(const generated_text: string; const composition_text: string;
    const max_suggestions: Integer;
    out candidates: TncCandidateList);
function nc_ai_build_request_signature(const request: TncAiRequest): string;

implementation

function nc_ai_clamp_int(const value: Integer; const min_value: Integer; const max_value: Integer): Integer;
begin
    Result := value;
    if Result < min_value then
    begin
        Result := min_value;
    end;
    if Result > max_value then
    begin
        Result := max_value;
    end;
end;

function is_high_surrogate(const ch: Char): Boolean;
begin
    Result := (Ord(ch) >= $D800) and (Ord(ch) <= $DBFF);
end;

function is_low_surrogate(const ch: Char): Boolean;
begin
    Result := (Ord(ch) >= $DC00) and (Ord(ch) <= $DFFF);
end;

function nc_ai_contains_cjk(const text: string): Boolean;
var
    i: Integer;
    code: Integer;
    hi: Integer;
    lo: Integer;
begin
    Result := False;
    i := 1;
    while i <= Length(text) do
    begin
        code := Ord(text[i]);
        if ((code >= $3400) and (code <= $9FFF)) or ((code >= $F900) and (code <= $FAFF)) then
        begin
            Result := True;
            Exit;
        end;

        if (i < Length(text)) and is_high_surrogate(text[i]) and is_low_surrogate(text[i + 1]) then
        begin
            hi := Ord(text[i]) - $D800;
            lo := Ord(text[i + 1]) - $DC00;
            code := ((hi shl 10) or lo) + $10000;
            if (code >= $20000) and (code <= $2EBEF) then
            begin
                Result := True;
                Exit;
            end;
            Inc(i);
        end;

        Inc(i);
    end;
end;

function nc_ai_sanitize_single_line(const value: string): string;
begin
    Result := value;
    Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
    Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
    Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
    Result := Trim(Result);
end;

function nc_ai_tail_text(const value: string; const max_len: Integer): string;
begin
    Result := value;
    if Length(Result) > max_len then
    begin
        Result := Copy(Result, Length(Result) - max_len + 1, max_len);
    end;
end;

function nc_ai_extract_cjk_only(const value: string): string;
var
    i: Integer;
    code: Integer;
    hi: Integer;
    lo: Integer;
begin
    Result := '';
    i := 1;
    while i <= Length(value) do
    begin
        code := Ord(value[i]);
        if (i < Length(value)) and is_high_surrogate(value[i]) and is_low_surrogate(value[i + 1]) then
        begin
            hi := Ord(value[i]) - $D800;
            lo := Ord(value[i + 1]) - $DC00;
            code := ((hi shl 10) or lo) + $10000;
            if (code >= $20000) and (code <= $2EBEF) then
            begin
                Result := Result + value[i] + value[i + 1];
            end;
            Inc(i, 2);
            Continue;
        end;

        if ((code >= $3400) and (code <= $9FFF)) or ((code >= $F900) and (code <= $FAFF)) then
        begin
            Result := Result + value[i];
        end;

        Inc(i);
    end;
end;

function nc_ai_decode_utf8_lossy(const bytes: TBytes): string;
var
    required_chars: Integer;
    written_chars: Integer;
begin
    Result := '';
    if Length(bytes) <= 0 then
    begin
        Exit;
    end;

    required_chars := MultiByteToWideChar(CP_UTF8, 0, PAnsiChar(@bytes[0]), Length(bytes), nil, 0);
    if required_chars <= 0 then
    begin
        Exit;
    end;

    SetLength(Result, required_chars);
    written_chars := MultiByteToWideChar(CP_UTF8, 0, PAnsiChar(@bytes[0]), Length(bytes), PWideChar(Result), required_chars);
    if written_chars <= 0 then
    begin
        Result := '';
        Exit;
    end;
    if written_chars <> required_chars then
    begin
        SetLength(Result, written_chars);
    end;
end;

function nc_ai_try_fix_gbk_utf8_mojibake(const value: string; out fixed_value: string): Boolean;
var
    bytes: TBytes;
    converted: string;
begin
    fixed_value := value;
    Result := False;
    if value = '' then
    begin
        Exit;
    end;

    if not nc_ai_contains_cjk(value) then
    begin
        Exit;
    end;

    try
        bytes := TEncoding.GetEncoding(936).GetBytes(value);
        converted := nc_ai_decode_utf8_lossy(bytes);
    except
        Exit;
    end;

    converted := Trim(converted);
    if (converted = '') or SameText(converted, value) then
    begin
        Exit;
    end;

    if not nc_ai_contains_cjk(converted) then
    begin
        Exit;
    end;

    fixed_value := converted;
    Result := True;
end;

function nc_ai_normalize_candidate_line(const raw_line: string): string;
var
    text: string;
    fixed_text: string;
    idx: Integer;
    first_char: Char;
    last_char: Char;
begin
    text := nc_ai_sanitize_single_line(raw_line);
    if text = '' then
    begin
        Result := '';
        Exit;
    end;

    while (text <> '') and CharInSet(text[1], ['-', '*', '>', '.']) do
    begin
        Delete(text, 1, 1);
        text := TrimLeft(text);
    end;

    idx := 1;
    while (idx <= Length(text)) and CharInSet(text[idx], ['0'..'9']) do
    begin
        Inc(idx);
    end;
    if idx > 1 then
    begin
        while (idx <= Length(text)) and CharInSet(text[idx], ['.', ':', ')', ']', '-', ' ']) do
        begin
            Inc(idx);
        end;
        text := Trim(Copy(text, idx, MaxInt));
    end;

    if text = '' then
    begin
        Result := '';
        Exit;
    end;

    first_char := text[1];
    last_char := text[Length(text)];
    if ((first_char = '"') and (last_char = '"')) or ((first_char = '''') and (last_char = '''')) then
    begin
        if Length(text) > 2 then
        begin
            text := Copy(text, 2, Length(text) - 2);
        end
        else
        begin
            text := '';
        end;
    end;

    text := Trim(text);
    if text = '' then
    begin
        Result := '';
        Exit;
    end;

    if (Pos('Pinyin', text) > 0) or (Pos('Candidate', text) > 0) or (Pos('Context', text) > 0) then
    begin
        Result := '';
        Exit;
    end;

    if nc_ai_try_fix_gbk_utf8_mojibake(text, fixed_text) then
    begin
        text := fixed_text;
    end;

    text := nc_ai_extract_cjk_only(text);
    if text = '' then
    begin
        Result := '';
        Exit;
    end;

    if nc_ai_try_fix_gbk_utf8_mojibake(text, fixed_text) then
    begin
        text := nc_ai_extract_cjk_only(fixed_text);
        if text = '' then
        begin
            Result := '';
            Exit;
        end;
    end;

    if Length(text) > 12 then
    begin
        SetLength(text, 12);
    end;

    Result := text;
end;

procedure nc_ai_expand_line_to_chunks(const raw_line: string; const chunks: TStrings);
var
    text: string;
begin
    text := raw_line;
    text := StringReplace(text, #9, #10, [rfReplaceAll]);
    text := StringReplace(text, ',', #10, [rfReplaceAll]);
    text := StringReplace(text, string(WideChar($FF0C)), #10, [rfReplaceAll]);
    text := StringReplace(text, string(WideChar($3001)), #10, [rfReplaceAll]);
    text := StringReplace(text, ';', #10, [rfReplaceAll]);
    text := StringReplace(text, string(WideChar($FF1B)), #10, [rfReplaceAll]);
    text := StringReplace(text, '|', #10, [rfReplaceAll]);
    text := StringReplace(text, '/', #10, [rfReplaceAll]);
    text := StringReplace(text, '\', #10, [rfReplaceAll]);
    text := StringReplace(text, string(WideChar($3000)), #10, [rfReplaceAll]);
    text := StringReplace(text, ' ', #10, [rfReplaceAll]);
    chunks.Text := text;
end;

function nc_ai_build_prompt(const request: TncAiRequest): string;
var
    left_context: string;
    composition: string;
    segmented_pinyin: string;
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    normalized_composition: string;
    i: Integer;
begin
    left_context := nc_ai_tail_text(nc_ai_sanitize_single_line(request.context.left_context), 32);
    composition := nc_ai_sanitize_single_line(request.context.composition_text);
    normalized_composition := LowerCase(composition);
    normalized_composition := StringReplace(normalized_composition, ' ', '', [rfReplaceAll]);
    segmented_pinyin := '';
    if normalized_composition <> '' then
    begin
        parser := TncPinyinParser.Create;
        try
            syllables := parser.parse(normalized_composition);
        finally
            parser.Free;
        end;

        for i := 0 to High(syllables) do
        begin
            if syllables[i].text = '' then
            begin
                Continue;
            end;
            if segmented_pinyin <> '' then
            begin
                segmented_pinyin := segmented_pinyin + ' ';
            end;
            segmented_pinyin := segmented_pinyin + syllables[i].text;
        end;
    end;

    if left_context = '' then
    begin
        left_context := '<empty>';
    end;
    if segmented_pinyin = '' then
    begin
        segmented_pinyin := '<unparsed>';
    end;

    Result :=
        '/no_think' + sLineBreak +
        'You are a Chinese IME candidate generator.' + sLineBreak +
        'Given pinyin and left context, generate Chinese candidates for IME selection.' + sLineBreak +
        'Rules:' + sLineBreak +
        '1) One candidate per line.' + sLineBreak +
        '2) Output only Chinese Han characters. No pinyin, English, digits, punctuation, explanations, or numbering.' + sLineBreak +
        '3) Each candidate must match the FULL input pinyin pronunciation (all syllables), not partial pinyin.' + sLineBreak +
        '3.1) Follow the provided syllable boundaries exactly. Do not replace any syllable with a similar-sounding one.' + sLineBreak +
        '4) Prefer common modern Chinese words/phrases and common proper nouns with real usage.' + sLineBreak +
        '5) Avoid fabricated, archaic, or extremely rare words unless they are commonly used today.' + sLineBreak +
        '6) Rank candidates by likely real-world usage frequency under the given context.' + sLineBreak +
        '7) If context is empty, rank by general usage frequency.' + sLineBreak +
        '8) Return up to 9 distinct candidates; prefer 6-9 when possible.' + sLineBreak +
        '9) Do not output thinking process.' + sLineBreak +
        'LeftContext: ' + left_context + sLineBreak +
        'PinyinRaw: ' + composition + sLineBreak +
        'PinyinSyllables: ' + segmented_pinyin + sLineBreak +
        'Candidates:' + sLineBreak;
end;

function nc_ai_get_generation_tokens(const max_suggestions: Integer): Integer;
begin
    Result := max_suggestions * 10;
    Result := nc_ai_clamp_int(Result, 16, 96);
end;

procedure nc_ai_parse_generated_candidates(const generated_text: string; const composition_text: string;
    const max_suggestions: Integer;
    out candidates: TncCandidateList);
var
    lines: TStringList;
    chunks: TStringList;
    seen: TStringList;
    source_text: string;
    lower_text: string;
    think_end_pos: Integer;
    composition_len: Integer;
    min_candidate_len: Integer;
    i: Integer;
    j: Integer;

    procedure append_candidate_from_raw(const raw_value: string);
    var
        candidate_text: string;
        candidate_count: Integer;
    begin
        candidate_text := nc_ai_normalize_candidate_line(raw_value);
        if candidate_text = '' then
        begin
            Exit;
        end;
        if Length(candidate_text) < min_candidate_len then
        begin
            Exit;
        end;

        if seen.IndexOf(candidate_text) >= 0 then
        begin
            Exit;
        end;
        seen.Add(candidate_text);

        candidate_count := Length(candidates);
        SetLength(candidates, candidate_count + 1);
        candidates[candidate_count].text := candidate_text;
        candidates[candidate_count].comment := '';
        candidates[candidate_count].score := 1000 - candidate_count;
        candidates[candidate_count].source := cs_ai;
    end;
begin
    SetLength(candidates, 0);
    if generated_text = '' then
    begin
        Exit;
    end;
    composition_len := Length(nc_ai_sanitize_single_line(composition_text));
    min_candidate_len := 1;
    if composition_len >= 6 then
    begin
        // Long pinyin inputs should not be replaced by single-character AI noise.
        min_candidate_len := 2;
    end;

    lines := TStringList.Create;
    chunks := TStringList.Create;
    seen := TStringList.Create;
    try
        source_text := StringReplace(generated_text, #13, '', [rfReplaceAll]);
        lower_text := LowerCase(source_text);
        think_end_pos := Pos('</think>', lower_text);
        if think_end_pos > 0 then
        begin
            source_text := Copy(source_text, think_end_pos + Length('</think>'), MaxInt);
        end;
        lines.Text := source_text;
        seen.CaseSensitive := False;

        for i := 0 to lines.Count - 1 do
        begin
            nc_ai_expand_line_to_chunks(lines[i], chunks);
            if chunks.Count = 0 then
            begin
                append_candidate_from_raw(lines[i]);
            end
            else
            begin
                for j := 0 to chunks.Count - 1 do
                begin
                    append_candidate_from_raw(chunks[j]);
                    if Length(candidates) >= max_suggestions then
                    begin
                        Break;
                    end;
                end;
            end;

            if Length(candidates) >= max_suggestions then
            begin
                Break;
            end;
        end;
    finally
        seen.Free;
        chunks.Free;
        lines.Free;
    end;
end;

function nc_ai_build_request_signature(const request: TncAiRequest): string;
var
    left_context: string;
    composition: string;
    max_count: Integer;
begin
    left_context := nc_ai_tail_text(nc_ai_sanitize_single_line(request.context.left_context), 32);
    composition := LowerCase(nc_ai_sanitize_single_line(request.context.composition_text));
    max_count := nc_ai_clamp_int(request.max_suggestions, 1, 15);
    Result := composition + #1 + left_context + #1 + IntToStr(max_count);
end;

end.
