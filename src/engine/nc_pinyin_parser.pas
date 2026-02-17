unit nc_pinyin_parser;

interface

uses
    System.SysUtils,
    System.Generics.Collections;

type
    TncPinyinSyllable = record
        text: string;
        start_index: Integer;
        length: Integer;
    end;

    TncPinyinParseResult = array of TncPinyinSyllable;

    TncPinyinParser = class
    public
        function parse(const input_text: string): TncPinyinParseResult;
    end;

implementation

const
    c_initials: array[0..22] of string = (
        'zh', 'ch', 'sh',
        'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h',
        'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w'
    );
    c_finals: array[0..35] of string = (
        'iang', 'iong', 'uang',
        'uai', 'uan', 'iao', 'ian', 'ing', 'ang', 'eng', 'ong',
        'ai', 'an', 'ao', 'ei', 'en', 'er', 'ou',
        'ia', 'ie', 'in', 'iu', 'ua', 'ui', 'un', 'uo',
        've', 'van', 'vn', 'ue',
        'a', 'e', 'i', 'o', 'u', 'v'
    );
    // Finals allowed when there is no explicit initial.
    // Keep this conservative to avoid incorrect greedy splits like:
    // "danian" -> "dan + ian" (expected "da + nian").
    c_finals_no_initial: array[0..11] of string = (
        'ang', 'eng',
        'ai', 'an', 'ao', 'ei', 'en', 'er', 'ou',
        'a', 'e', 'o'
    );

function TncPinyinParser.parse(const input_text: string): TncPinyinParseResult; 
var
    lower_text: string;
    cursor: Integer;
    text_length: Integer;
    result_list: TncPinyinParseResult;
    memo_score: TArray<Integer>;
    memo_next: TArray<Integer>;
    memo_text: TArray<string>;
    memo_len: TArray<Integer>;
    memo_done: TArray<Boolean>;

    function has_prefix(const source: string; const start_index: Integer; const value: string): Boolean;
    begin
        if value = '' then
        begin
            Exit(False);
        end;

        if start_index + Length(value) > Length(source) then
        begin
            Exit(False);
        end;

        Result := Copy(source, start_index + 1, Length(value)) = value;
    end;

    procedure append_syllable(const text: string; const start_index: Integer; const len: Integer);
    var
        idx: Integer;
    begin
        idx := Length(result_list);
        SetLength(result_list, idx + 1);
        result_list[idx].text := text;
        result_list[idx].start_index := start_index;
        result_list[idx].length := len;
    end;

    function solve(const start_index: Integer): Integer;
    var
        best_score: Integer;
        best_next: Integer;
        best_text: string;
        best_len: Integer;
        score_value: Integer;
        next_index: Integer;
        initial_idx: Integer;
        final_idx: Integer;
        initial_value: string;
        final_value: string;
        token_text: string;
        token_len: Integer;
    begin
        if start_index >= text_length then
        begin
            Result := 0;
            Exit;
        end;

        if memo_done[start_index] then
        begin
            Result := memo_score[start_index];
            Exit;
        end;

        // Apostrophe is an explicit boundary marker and should be skipped.
        if lower_text[start_index + 1] = '''' then
        begin
            memo_done[start_index] := True;
            memo_text[start_index] := '';
            memo_len[start_index] := 0;
            memo_next[start_index] := start_index + 1;
            memo_score[start_index] := solve(start_index + 1);
            Result := memo_score[start_index];
            Exit;
        end;

        best_score := Low(Integer) div 2;
        best_next := start_index + 1;
        best_text := Copy(lower_text, start_index + 1, 1);
        best_len := 1;

        // Try all "initial + final" syllables.
        for initial_idx := Low(c_initials) to High(c_initials) do
        begin
            initial_value := c_initials[initial_idx];
            if not has_prefix(lower_text, start_index, initial_value) then
            begin
                Continue;
            end;

            for final_idx := Low(c_finals) to High(c_finals) do
            begin
                final_value := c_finals[final_idx];
                if not has_prefix(lower_text, start_index + Length(initial_value), final_value) then
                begin
                    Continue;
                end;

                token_text := initial_value + final_value;
                token_len := Length(token_text);
                next_index := start_index + token_len;
                score_value := solve(next_index) + (token_len * token_len * 10);
                if score_value > best_score then
                begin
                    best_score := score_value;
                    best_next := next_index;
                    best_text := token_text;
                    best_len := token_len;
                end;
            end;
        end;

        // Try no-initial finals.
        for final_idx := Low(c_finals_no_initial) to High(c_finals_no_initial) do
        begin
            final_value := c_finals_no_initial[final_idx];
            if not has_prefix(lower_text, start_index, final_value) then
            begin
                Continue;
            end;

            token_text := final_value;
            token_len := Length(token_text);
            next_index := start_index + token_len;
            score_value := solve(next_index) + (token_len * token_len * 10);
            if score_value > best_score then
            begin
                best_score := score_value;
                best_next := next_index;
                best_text := token_text;
                best_len := token_len;
            end;
        end;

        // Fallback: consume one character as an unknown token.
        score_value := solve(start_index + 1) - 1000;
        if score_value > best_score then
        begin
            best_score := score_value;
            best_next := start_index + 1;
            best_text := Copy(lower_text, start_index + 1, 1);
            best_len := 1;
        end;

        memo_done[start_index] := True;
        memo_score[start_index] := best_score;
        memo_next[start_index] := best_next;
        memo_text[start_index] := best_text;
        memo_len[start_index] := best_len;
        Result := best_score;
    end;
begin
    SetLength(result_list, 0);
    if input_text = '' then
    begin
        Result := result_list;
        Exit;
    end;

    lower_text := LowerCase(input_text);
    cursor := 0;
    text_length := Length(lower_text);

    SetLength(memo_score, text_length + 1);
    SetLength(memo_next, text_length + 1);
    SetLength(memo_text, text_length + 1);
    SetLength(memo_len, text_length + 1);
    SetLength(memo_done, text_length + 1);
    solve(0);

    while cursor < text_length do
    begin
        if lower_text[cursor + 1] = '''' then
        begin
            Inc(cursor);
            Continue;
        end;

        if (not memo_done[cursor]) or (memo_next[cursor] <= cursor) or (memo_len[cursor] <= 0) or
            (memo_text[cursor] = '') then
        begin
            append_syllable(Copy(lower_text, cursor + 1, 1), cursor, 1);
            Inc(cursor);
            Continue;
        end
        else
        begin
            append_syllable(memo_text[cursor], cursor, memo_len[cursor]);
            cursor := memo_next[cursor];
        end;
    end;

    Result := result_list;
end;

end.
