unit nc_english_input;

interface

// Lexical or conservative spelling evidence; invalid pinyin alone is not enough.
function nc_is_english_word(const text: string): Boolean;

implementation

uses System.SysUtils, System.Generics.Collections,
    nc_pinyin_parser, nc_shuangpin_decoder;

{$I nc_english_words.inc}

var g_pinyin_prefixes: TDictionary<string, Boolean>;

function plausible_pinyin(const text: string; const allow_abbreviation: Boolean): Boolean;
var reached: array[0..32, 0..1] of Boolean; start, size, abbreviated: Integer; part: string;
    complete: Boolean;
begin
    FillChar(reached, SizeOf(reached), 0);
    reached[0, 0] := True;
    for start := 0 to Length(text) - 1 do
        for abbreviated := 0 to Ord(allow_abbreviation) do
            if reached[start, abbreviated] then
                for size := 1 to 6 do
                begin
                    if start + size > Length(text) then Break;
                    part := Copy(text, start + 1, size);
                    if g_pinyin_prefixes.TryGetValue(part, complete) then
                    begin
                        if complete then reached[start + size, abbreviated] := True;
                        if start + size = Length(text) then Exit(True);
                    end;
                    if allow_abbreviation and (abbreviated = 0) and
                        (((size = 1) and CharInSet(part[1],
                            ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h',
                             'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w'])) or
                         (part = 'zh') or (part = 'ch') or (part = 'sh')) then
                        reached[start + size, 1] := True;
                end;
    Result := reached[Length(text), 0] or reached[Length(text), 1];
end;

function known_word(const text: string): Boolean;
var first, last, middle, comparison: Integer;
begin
    first := Low(c_english_words);
    last := High(c_english_words);
    while first <= last do
    begin
        middle := first + (last - first) div 2;
        comparison := CompareStr(text, string(c_english_words[middle]));
        if comparison = 0 then Exit(True);
        if comparison < 0 then last := middle - 1 else first := middle + 1;
    end;
    Result := False;
end;

function known_inflection(const key: string): Boolean;
var stem: string;
begin
    Result := False;
    if known_word(key) then Exit(True);
    // Common inflections are checked against the same dictionary, never guessed.
    if key.EndsWith('s') and known_word(Copy(key, 1, Length(key) - 1)) then Exit(True);
    if key.EndsWith('es') and known_word(Copy(key, 1, Length(key) - 2)) then Exit(True);
    if key.EndsWith('ies') and known_word(Copy(key, 1, Length(key) - 3) + 'y') then Exit(True);
    if key.EndsWith('ing') then stem := Copy(key, 1, Length(key) - 3)
    else if key.EndsWith('ed') then stem := Copy(key, 1, Length(key) - 2)
    else Exit;
    Result := known_word(stem) or known_word(stem + 'e');
    if (not Result) and (Length(stem) > 2) and
        (stem[Length(stem)] = stem[Length(stem) - 1]) then
        Result := known_word(Copy(stem, 1, Length(stem) - 1));
end;

function plausible_english_spelling(const key: string): Boolean;
var padded: string; idx, gram, vowel_count, supported: Integer;
begin
    Result := False;
    vowel_count := 0;
    for idx := 1 to Length(key) do
    begin
        if CharInSet(key[idx], ['a', 'e', 'i', 'o', 'u']) then Inc(vowel_count);
        if (idx > 2) and (key[idx] = key[idx - 1]) and
            (key[idx] = key[idx - 2]) then Exit;
    end;
    if vowel_count < 2 then Exit;
    padded := '{' + key + '{';
    supported := 0;
    for idx := 1 to Length(padded) - 1 do
    begin
        gram := (Ord(padded[idx]) - Ord('a')) * 27 + Ord(padded[idx + 1]) - Ord('a');
        if (c_english_spelling_2grams[gram div 32] and
            (Cardinal(1) shl (gram mod 32))) = 0 then Exit;
        if idx < Length(padded) - 1 then
        begin
            gram := gram * 27 + Ord(padded[idx + 2]) - Ord('a');
            if (c_english_spelling_3grams[gram div 32] and
                (Cardinal(1) shl (gram mod 32))) <> 0 then Inc(supported);
        end;
    end;
    // All pairs and at least 80% of triples need independent lexical support,
    // including the boundaries. No name or brand is special-cased here.
    Result := supported * 5 >= Length(key) * 4;
end;

function nc_is_english_word(const text: string): Boolean;
var key: string; ch: Char; has_vowel, lexical: Boolean;
begin
    Result := False;
    if (Length(text) < 4) or (Length(text) > 32) then Exit;
    key := LowerCase(text);
    has_vowel := False;
    for ch in key do
    begin
        if not CharInSet(ch, ['a'..'z']) then Exit;
        has_vowel := has_vowel or CharInSet(ch, ['a', 'e', 'i', 'o', 'u', 'v']);
    end;
    if not has_vowel then Exit;
    lexical := known_inflection(key);
    if (not lexical) and (not plausible_english_spelling(key)) then Exit;
    // Unknown names get stronger Chinese protection: one abbreviated syllable
    // may precede a complete or unfinished pinyin tail. The engine separately
    // protects dictionary/user matches with any number of abbreviations.
    Result := not plausible_pinyin(nc_normalize_umlaut_spelling(key), not lexical);
end;

procedure initialize_prefixes;
var syllable: string; count: Integer;
begin
    g_pinyin_prefixes := TDictionary<string, Boolean>.Create;
    for syllable in nc_get_shuangpin_syllables do
    begin
        for count := 1 to Length(syllable) do
            if not g_pinyin_prefixes.ContainsKey(Copy(syllable, 1, count)) then
                g_pinyin_prefixes.Add(Copy(syllable, 1, count), False);
        g_pinyin_prefixes.AddOrSetValue(syllable, True);
    end;
end;

initialization
    initialize_prefixes;
finalization
    g_pinyin_prefixes.Free;
end.
