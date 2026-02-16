unit nc_ai_text_utils;

interface

uses
    System.SysUtils,
    System.Classes,
    nc_types,
    nc_ai_intf;

function nc_ai_clamp_int(const value: Integer; const min_value: Integer; const max_value: Integer): Integer;
function nc_ai_contains_cjk(const text: string): Boolean;
function nc_ai_sanitize_single_line(const value: string): string;
function nc_ai_tail_text(const value: string; const max_len: Integer): string;
function nc_ai_normalize_candidate_line(const raw_line: string): string;
function nc_ai_build_prompt(const request: TncAiRequest): string;
function nc_ai_get_generation_tokens(const max_suggestions: Integer): Integer;
procedure nc_ai_parse_generated_candidates(const generated_text: string; const max_suggestions: Integer;
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

function nc_ai_normalize_candidate_line(const raw_line: string): string;
var
    text: string;
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

    if Pos(' ', text) > 0 then
    begin
        Result := '';
        Exit;
    end;

    if Length(text) > 16 then
    begin
        SetLength(text, 16);
    end;

    if not nc_ai_contains_cjk(text) then
    begin
        Result := '';
        Exit;
    end;

    Result := text;
end;

function nc_ai_build_prompt(const request: TncAiRequest): string;
var
    left_context: string;
    composition: string;
begin
    left_context := nc_ai_tail_text(nc_ai_sanitize_single_line(request.context.left_context), 32);
    composition := nc_ai_sanitize_single_line(request.context.composition_text);
    if left_context = '' then
    begin
        left_context := '<empty>';
    end;

    Result :=
        'You are a Chinese IME candidate generator.' + sLineBreak +
        'Convert pinyin to Chinese candidates with the given left context.' + sLineBreak +
        'Output rules:' + sLineBreak +
        '1) Output only candidate text, one per line.' + sLineBreak +
        '2) No numbering, no explanation.' + sLineBreak +
        '3) Keep candidates short.' + sLineBreak +
        'LeftContext: ' + left_context + sLineBreak +
        'Pinyin: ' + composition + sLineBreak +
        'Candidates:' + sLineBreak;
end;

function nc_ai_get_generation_tokens(const max_suggestions: Integer): Integer;
begin
    Result := max_suggestions * 10;
    Result := nc_ai_clamp_int(Result, 16, 96);
end;

procedure nc_ai_parse_generated_candidates(const generated_text: string; const max_suggestions: Integer;
    out candidates: TncCandidateList);
var
    lines: TStringList;
    seen: TStringList;
    i: Integer;
    candidate_text: string;
    candidate_count: Integer;
begin
    SetLength(candidates, 0);
    if generated_text = '' then
    begin
        Exit;
    end;

    lines := TStringList.Create;
    seen := TStringList.Create;
    try
        lines.Text := StringReplace(generated_text, #13, '', [rfReplaceAll]);
        seen.CaseSensitive := False;

        for i := 0 to lines.Count - 1 do
        begin
            candidate_text := nc_ai_normalize_candidate_line(lines[i]);
            if candidate_text = '' then
            begin
                Continue;
            end;

            if seen.IndexOf(candidate_text) >= 0 then
            begin
                Continue;
            end;
            seen.Add(candidate_text);

            candidate_count := Length(candidates);
            SetLength(candidates, candidate_count + 1);
            candidates[candidate_count].text := candidate_text;
            candidates[candidate_count].comment := '';
            candidates[candidate_count].score := 1000 - candidate_count;
            candidates[candidate_count].source := cs_ai;

            if Length(candidates) >= max_suggestions then
            begin
                Break;
            end;
        end;
    finally
        seen.Free;
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
