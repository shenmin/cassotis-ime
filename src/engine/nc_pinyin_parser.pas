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

{ True when the initial and the final spell a syllable that some character
  reads. }
function nc_is_pinyin_initial_final_compatible(const initial_value: string;
    const final_value: string): Boolean;
function nc_is_canonical_pinyin_syllable(const value: string): Boolean;
function nc_is_pinyin_initial(const value: string): Boolean;
{ The canonical syllables that begin with prefix, all of them for ''
  (the erhua "r" is none). }
function nc_canonical_pinyin_syllables_starting_with(const prefix: string): TArray<string>;
{ True when compact pinyin parses into exactly `units` canonical syllables:
  the rest of a word after typed syllables that end at a syllable boundary. }
function nc_word_completion_remainder_fits(const parser: TncPinyinParser;
    const remainder: string; const units: Integer): Boolean;
{ True when compact pinyin splits into `units` canonical syllables in one way
  only. A word the dictionary stores under such a key reads those syllables,
  whatever the rows of its single characters say (弄堂 under longtang, where
  弄 has only nong); "jianan" also splits as jian an. }
function nc_pinyin_splits_one_way(const value: string; const units: Integer): Boolean;
function nc_normalize_umlaut_spelling(const value: string): string;
{ Split the original keys, not a corrected lookup key. Only a literal suffix
  or one verified adjacent transposition may supply the consumption boundary.
  boundary_swapped: the transposed pair lies across the boundary, so the keys
  the candidate uses are not contiguous. consumed_input then ends with the
  second key of the pair and remaining_input begins with the first: what
  remains is still the keys not consumed, in the order they were typed. }
function nc_try_split_pinyin_input(const input_text, lookup_key,
    remaining_pinyin: string; out consumed_input, remaining_input: string;
    out boundary_swapped: Boolean; const allow_boundary_swap: Boolean = True): Boolean;
procedure nc_merge_abbreviated_retroflex_initials(var syllables: TncPinyinParseResult);

implementation

procedure nc_merge_abbreviated_retroflex_initials(var syllables: TncPinyinParseResult);
var
    read_idx, write_idx: Integer;
begin
    read_idx := 0;
    write_idx := 0;
    while read_idx < Length(syllables) do
    begin
        syllables[write_idx] := syllables[read_idx];
        // Only unresolved, adjacent initials are joined. A full syllable or
        // an explicit apostrophe keeps c+h separate (e.g. c'h or c'ha).
        if (read_idx < High(syllables)) and
            ((syllables[read_idx].text = 'z') or
             (syllables[read_idx].text = 'c') or
             (syllables[read_idx].text = 's')) and
            (syllables[read_idx + 1].text = 'h') and
            (syllables[read_idx].start_index + syllables[read_idx].length =
             syllables[read_idx + 1].start_index) then
        begin
            syllables[write_idx].text := syllables[read_idx].text + 'h';
            Inc(syllables[write_idx].length, syllables[read_idx + 1].length);
            Inc(read_idx);
        end;
        Inc(read_idx);
        Inc(write_idx);
    end;
    SetLength(syllables, write_idx);
end;

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
    c_finals_no_initial: array[0..12] of string = (
        'ang', 'eng',
        'ai', 'an', 'ao', 'ei', 'en', 'er', 'ou',
        'a', 'e', 'o', 'r'
    );

const
    // The initials each final takes in a syllable some character of the
    // lexicon reads (with the colloquial kei, sei, tei, zhei, cei and chei),
    // in the order of c_finals; y and w spell the medials, and "er" takes
    // none. The two tables spell 181 more, and a spelling no character reads
    // stole the keys of two syllables: "xinuaile" read as xi nuai le, not
    // xi nu ai le (喜怒哀乐), "buduangengxin" as bu duang eng xin (不断更新),
    // "dasuangei" as da suang ei (打算给); earlier "bue", "quangao",
    // "zhineng", "dian+geng" and "yu+ai" the same way. Without them 22 of the
    // 16,300 long cases and 4 of the 10,833 short inputs parse as typed, and
    // none parses otherwise.
    c_final_initials: array[Low(c_finals)..High(c_finals)] of string = (
        ' n l j q x ',                                              // iang
        ' j q x ',                                                  // iong
        ' zh ch sh g k h ',                                         // uang
        ' zh ch sh g k h ',                                         // uai
        ' zh ch sh d t n l g k h j q x r z c s y ',                 // uan
        ' b p m f d t n l j q x ',                                  // iao
        ' b p m d t n l j q x ',                                    // ian
        ' b p m d t n l j q x y ',                                  // ing
        ' zh ch sh b p m f d t n l g k h r z c s y w ',             // ang
        ' zh ch sh b p m f d t n l g k h r z c s w ',               // eng
        ' zh ch d t n l g k h r z c s y ',                          // ong
        ' zh ch sh b p m d t n l g k h z c s w ',                   // ai
        ' zh ch sh b p m f d t n l g k h r z c s y w ',             // an
        ' zh ch sh b p m d t n l g k h r z c s y ',                 // ao
        ' zh ch sh b p m f d t n l g k h z c s w ',                 // ei
        ' zh ch sh b p m f d n g k h r z c s w ',                   // en
        '',                                                         // er
        ' zh ch sh p m f d t n l g k h r z c s y ',                 // ou
        ' d l j q x ',                                              // ia
        ' b p m d t n l j q x ',                                    // ie
        ' b p m n l j q x y ',                                      // in
        ' m d n l j q x ',                                          // iu
        ' zh ch sh g k h r ',                                       // ua
        ' zh ch sh d t g k h r z c s ',                             // ui
        ' zh ch sh d t n l g k h j q x r z c s y ',                 // un
        ' zh ch sh d t n l g k h r z c s ',                         // uo
        ' n l j q x ',                                              // ve
        ' n l j q x ',                                              // van
        ' n l j q x ',                                              // vn
        ' n l j q x y ',                                            // ue
        ' zh ch sh b p m f d t n l g k h z c s y w ',               // a
        ' zh ch sh m d t n l g k h r z c s y ',                     // e
        ' zh ch sh b p m d t n l j q x r z c s y ',                 // i
        ' b p m f l y w ',                                          // o
        ' zh ch sh b p m f d t n l g k h j q x r z c s y w ',       // u
        ' n l j q x '                                               // v
    );

function nc_is_pinyin_initial_final_compatible(const initial_value: string;
    const final_value: string): Boolean;
var
    final_idx: Integer;
begin
    for final_idx := Low(c_finals) to High(c_finals) do
    begin
        if c_finals[final_idx] = final_value then
        begin
            Exit(Pos(' ' + initial_value + ' ', c_final_initials[final_idx]) > 0);
        end;
    end;
    Result := False;
end;

var
    // Precomputed nc_is_pinyin_initial_final_compatible over the constant tables;
    // the parser's DP probes every pair at every input position.
    g_initial_final_compatible: array[Low(c_initials)..High(c_initials),
        Low(c_finals)..High(c_finals)] of Boolean;

    g_canonical_syllables: TArray<string>;

procedure build_initial_final_compatibility;
var
    initial_idx: Integer;
    final_idx: Integer;
begin
    for initial_idx := Low(c_initials) to High(c_initials) do
    begin
        for final_idx := Low(c_finals) to High(c_finals) do
        begin
            g_initial_final_compatible[initial_idx, final_idx] :=
                nc_is_pinyin_initial_final_compatible(c_initials[initial_idx],
                c_finals[final_idx]);
            if g_initial_final_compatible[initial_idx, final_idx] then
                g_canonical_syllables := g_canonical_syllables +
                    [c_initials[initial_idx] + c_finals[final_idx]];
        end;
    end;
    for final_idx := Low(c_finals_no_initial) to High(c_finals_no_initial) do
        if c_finals_no_initial[final_idx] <> 'r' then
            g_canonical_syllables := g_canonical_syllables +
                [c_finals_no_initial[final_idx]];
end;

function nc_is_pinyin_initial(const value: string): Boolean;
var
    initial_idx: Integer;
begin
    for initial_idx := Low(c_initials) to High(c_initials) do
        if value = c_initials[initial_idx] then
            Exit(True);
    Result := False;
end;

function nc_canonical_pinyin_syllables_starting_with(const prefix: string): TArray<string>;
var
    syllable: string;
begin
    Result := nil;
    for syllable in g_canonical_syllables do
        if syllable.StartsWith(prefix) then
            Result := Result + [syllable];
end;

function nc_word_completion_remainder_fits(const parser: TncPinyinParser;
    const remainder: string; const units: Integer): Boolean;
var
    parsed: TncPinyinParseResult;
    idx: Integer;
begin
    Result := False;
    if (remainder = '') or (units <= 0) or (parser = nil) then
        Exit;
    parsed := parser.parse(LowerCase(remainder));
    if Length(parsed) <> units then
        Exit;
    for idx := 0 to High(parsed) do
        if not nc_is_canonical_pinyin_syllable(parsed[idx].text) then
            Exit;
    Result := True;
end;

function nc_pinyin_splits_one_way(const value: string; const units: Integer): Boolean;

    // The splits of value from position on into count syllables, up to two.
    function splits(const position, count: Integer): Integer;
    var size: Integer;
        syllable: string;
    begin
        if count = 0 then
        begin
            if position > Length(value) then Exit(1);
            Exit(0);
        end;
        Result := 0;
        for size := 1 to 6 do
        begin
            if position + size - 1 > Length(value) then Break;
            syllable := Copy(value, position, size);
            // The erhua "r" only ends a syllable.
            if (syllable <> 'r') and nc_is_canonical_pinyin_syllable(syllable) then
            begin
                Inc(Result, splits(position + size, count - 1));
                if Result > 1 then Exit;
            end;
        end;
    end;

begin
    Result := (value <> '') and (units > 0) and (splits(1, units) = 1);
end;

function nc_is_canonical_pinyin_syllable(const value: string): Boolean;
var
    normalized: string;
    initial_idx: Integer;
    final_idx: Integer;
    initial_value: string;
    final_value: string;
begin
    normalized := LowerCase(Trim(value));
    if normalized = '' then
    begin
        Exit(False);
    end;

    for final_idx := Low(c_finals_no_initial) to
        High(c_finals_no_initial) do
    begin
        if normalized = c_finals_no_initial[final_idx] then
        begin
            Exit(True);
        end;
    end;

    for initial_idx := Low(c_initials) to High(c_initials) do
    begin
        initial_value := c_initials[initial_idx];
        if Copy(normalized, 1, Length(initial_value)) <> initial_value then
        begin
            Continue;
        end;
        final_value := Copy(normalized, Length(initial_value) + 1, MaxInt);
        for final_idx := Low(c_finals) to High(c_finals) do
        begin
            if (final_value = c_finals[final_idx]) and
                nc_is_pinyin_initial_final_compatible(initial_value,
                final_value) then
            begin
                Exit(True);
            end;
        end;
    end;

    Result := False;
end;

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
    var
        value_length: Integer;
        char_idx: Integer;
    begin
        value_length := Length(value);
        if value_length = 0 then
        begin
            Exit(False);
        end;

        if start_index + value_length > Length(source) then
        begin
            Exit(False);
        end;

        // Same result as comparing Copy(source, start_index + 1, value_length)
        // with value, without allocating a substring for every probe.
        for char_idx := 1 to value_length do
        begin
            if source[start_index + char_idx] <> value[char_idx] then
            begin
                Exit(False);
            end;
        end;
        Result := True;
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

        function get_no_initial_penalty(const final_token: string; const token_start: Integer): Integer;
        begin
            // In the middle of a raw pinyin stream, no-initial syllables are often
            // artifacts of greedy over-merge (e.g. "sange" -> "sang"+"e").
            // Keep them possible, but score them lower so regular initial+final
            // paths win unless no better parse exists.
            if token_start <= 0 then
            begin
                Exit(0);
            end;
            if (token_start > 0) and (lower_text[token_start] = '''') then
            begin
                Exit(0);
            end;

            if (final_token = 'a') or (final_token = 'e') or (final_token = 'o') then
            begin
                Exit(160);
            end;
            if final_token = 'er' then
            begin
                Exit(100);
            end;
            if final_token = 'r' then
            begin
                // Compact erhua input such as "nar" and "yihuir" leaves a
                // trailing r after the base syllable. Treat it as a costly but
                // valid boundary marker instead of an unknown character.
                // Do not let it steal canonical er in inputs like "dierge" or
                // "eryan", where greedy "die+r"/"due+r" breaks normal words.
                if (token_start > 0) and (lower_text[token_start] = 'e') then
                begin
                    Exit(1200);
                end;
                Exit(80);
            end;

            // Multi-letter zero-initial finals (ao/an/ou/...) often occur after
            // n/ng without an apostrophe in real input, e.g. beijing+aoyun.
            // Keep the heavy penalty only for bare a/e/o; otherwise the parser
            // prefers jin+gao over jing+ao and poisons long-sentence paths.
            Result := 20;
        end;
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
                if not g_initial_final_compatible[initial_idx, final_idx] then
                begin
                    Continue;
                end;
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
            score_value := solve(next_index) + (token_len * token_len * 10) -
                get_no_initial_penalty(final_value, start_index);
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

function normalize_umlaut_syllables(const value: string): string;
var
    lower_value: string;
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    syllable: TncPinyinSyllable;
begin
    Result := value;
    lower_value := LowerCase(value);
    // Normalize complete syllables only, never join explicit boundaries.
    // Equal-length aliases preserve raw key offsets for partial commits.
    parser := TncPinyinParser.Create;
    try
        syllables := parser.parse(lower_value);
    finally
        parser.Free;
    end;
    for syllable in syllables do
        if (syllable.text = 'lue') or (syllable.text = 'nue') then
            Result[syllable.start_index + 2] := 'v'
        else if (Length(syllable.text) >= 2) and
            CharInSet(syllable.text[1], ['j', 'q', 'x']) and
            ((Copy(syllable.text, 2, MaxInt) = 'v') or
             (Copy(syllable.text, 2, MaxInt) = 've') or
             (Copy(syllable.text, 2, MaxInt) = 'van') or
             (Copy(syllable.text, 2, MaxInt) = 'vn')) then
            Result[syllable.start_index + 2] := 'u';
end;

function nc_normalize_umlaut_spelling(const value: string): string;
var
    idx: Integer;
    current_char: Char;
    next_char: Char;
begin
    Result := value;
    // Only lue/nue/jv/qv/xv (ASCII case-insensitive, as LowerCase) can change
    // the spelling. Scan once instead of lowering and probing every pattern.
    for idx := 1 to Length(value) - 1 do
    begin
        current_char := value[idx];
        if (current_char >= 'A') and (current_char <= 'Z') then
            current_char := Char(Ord(current_char) + 32);
        next_char := value[idx + 1];
        if (next_char >= 'A') and (next_char <= 'Z') then
            next_char := Char(Ord(next_char) + 32);
        if ((next_char = 'v') and CharInSet(current_char, ['j', 'q', 'x'])) or
            ((next_char = 'u') and CharInSet(current_char, ['l', 'n']) and
             (idx + 2 <= Length(value)) and
             CharInSet(value[idx + 2], ['e', 'E'])) then
        begin
            Result := normalize_umlaut_syllables(value);
            Exit;
        end;
    end;
end;

function nc_try_split_pinyin_input(const input_text, lookup_key,
    remaining_pinyin: string; out consumed_input, remaining_input: string;
    out boundary_swapped: Boolean; const allow_boundary_swap: Boolean): Boolean;
var
    input_key, tail_key, corrected_key, swapped_key: string;
    idx, consumed_letters, boundary, letters, first_key, second_key: Integer;
    ch: Char;

    function compact_key(const value: string): string;
    begin
        Result := LowerCase(nc_normalize_umlaut_spelling(value)).Replace('''', '');
    end;
begin
    Result := False;
    consumed_input := '';
    remaining_input := '';
    boundary_swapped := False;
    input_key := compact_key(input_text);
    tail_key := compact_key(remaining_pinyin);
    if (tail_key = '') or (Length(tail_key) >= Length(input_key)) then Exit;
    for ch in input_key do
        if not CharInSet(ch, ['a'..'z']) then Exit;

    consumed_letters := Length(input_key) - Length(tail_key);
    if Copy(input_key, consumed_letters + 1, MaxInt) <> tail_key then
    begin
        corrected_key := compact_key(lookup_key);
        if (Length(corrected_key) <> Length(input_key)) or
            (Copy(corrected_key, consumed_letters + 1, MaxInt) <> tail_key) then Exit;
        idx := 1;
        while (idx <= Length(input_key)) and
            (input_key[idx] = corrected_key[idx]) do Inc(idx);
        if idx >= Length(input_key) then Exit;
        swapped_key := input_key;
        swapped_key[idx] := input_key[idx + 1];
        swapped_key[idx + 1] := input_key[idx];
        if swapped_key <> corrected_key then Exit;
        if allow_boundary_swap and (idx = consumed_letters) then
        begin
            // The candidate uses the second key of the pair and leaves the
            // first. With a separator between the two the cut below applies.
            letters := 0;
            first_key := 0;
            second_key := 0;
            for boundary := 1 to Length(input_text) do
                if input_text[boundary] <> '''' then
                begin
                    Inc(letters);
                    if letters = idx then first_key := boundary
                    else if letters = idx + 1 then
                    begin
                        second_key := boundary;
                        Break;
                    end;
                end;
            if (first_key > 0) and (second_key = first_key + 1) then
            begin
                consumed_input := Copy(input_text, 1, first_key - 1) + input_text[second_key];
                remaining_input := input_text[first_key] +
                    Copy(input_text, second_key + 1, MaxInt);
                boundary_swapped := True;
                Exit(True);
            end;
        end;
    end;

    boundary := 1;
    while (boundary <= Length(input_text)) and (consumed_letters > 0) do
    begin
        if input_text[boundary] <> '''' then Dec(consumed_letters);
        Inc(boundary);
    end;
    // A separator immediately after the chosen prefix belongs to that prefix;
    // keeping it there also makes Backspace restore the exact original input.
    while (boundary <= Length(input_text)) and (input_text[boundary] = '''') do
        Inc(boundary);
    if boundary > Length(input_text) then Exit;
    consumed_input := Copy(input_text, 1, boundary - 1);
    remaining_input := Copy(input_text, boundary, MaxInt);
    Result := True;
end;

initialization
    build_initial_final_compatibility;

end.
