unit nc_english_input;

interface

type
    // What the letters say for and against an English word. The engine weighs
    // it against the Chinese candidates; none of it decides alone.
    TncEnglishEvidence = record
        // A word of the lexicon, or a regular inflection of one.
        listed: Boolean;
        // How frequent the listed word is inside Chinese text: 0 (app, the)
        // to 3 (in the word list only); -1 when not listed.
        band: Integer;
        // A word of the general English dictionary, not only an abbreviation
        // or a name counted in Chinese text.
        dictionary: Boolean;
        // Not listed, but spelled like English throughout (names, brands).
        spelled: Boolean;
        // The letters also read as pinyin: complete syllables with the last
        // one possibly unfinished; for an unlisted spelling one abbreviated
        // syllable may come before them.
        pinyin_like: Boolean;
        // The letters are pinyin a user may still be typing: complete
        // syllables, the last one possibly unfinished, nothing abbreviated.
        in_progress: Boolean;
        // Complete syllables throughout.
        complete: Boolean;
    end;

function nc_english_evidence(const text: string): TncEnglishEvidence;
// One pinyin syllable, complete or still being typed.
function nc_is_pinyin_syllable_prefix(const lower_text: string): Boolean;

var
    // CASSOTIS_ENGLISH_TRACE=1 (development): the engine compares every
    // letter input with its Chinese readings and reports it, whatever the
    // decision needs.
    nc_english_trace: Boolean = False;

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

function complete_pinyin(const text: string): Boolean;
var reached: array[0..32] of Boolean; start, size: Integer; complete: Boolean;
begin
    FillChar(reached, SizeOf(reached), 0);
    reached[0] := True;
    for start := 0 to Length(text) - 1 do
        if reached[start] then
            for size := 1 to 6 do
            begin
                if start + size > Length(text) then Break;
                if g_pinyin_prefixes.TryGetValue(Copy(text, start + 1, size), complete) and
                    complete then reached[start + size] := True;
            end;
    Result := reached[Length(text)];
end;

// The band of a listed word, 4 added for a word of the general dictionary;
// -1 when not listed.
function word_band(const text: string): Integer;
var first, last, middle, comparison: Integer;
begin
    first := Low(c_english_words);
    last := High(c_english_words);
    while first <= last do
    begin
        middle := first + (last - first) div 2;
        comparison := CompareStr(text, string(c_english_words[middle]));
        if comparison = 0 then Exit(c_english_word_bands[middle]);
        if comparison < 0 then last := middle - 1 else first := middle + 1;
    end;
    Result := -1;
end;

function inflection_band(const key: string): Integer;
const c_vowels = ['a', 'e', 'i', 'o', 'u'];
var stem: string;

    function stem_band(const value: string): Integer;
    begin
        // A stem shorter than three letters makes too many accidental words.
        if Length(value) < 3 then Exit(-1);
        Result := word_band(value);
    end;

    // A stem of one vowel that ends in vowel and consonant doubles the
    // consonant: "tabbing", and "tabing" is the beginning of pinyin.
    function doubles_consonant(const value: string): Boolean;
    var idx, vowels: Integer;
    begin
        vowels := 0;
        for idx := 1 to Length(value) do
            if CharInSet(value[idx], c_vowels) then Inc(vowels);
        Result := (vowels = 1) and (Length(value) >= 2) and
            CharInSet(value[Length(value) - 1], c_vowels) and
            not CharInSet(value[Length(value)], c_vowels + ['w', 'x', 'y']);
    end;
begin
    Result := word_band(key);
    if Result >= 0 then Exit;
    // Common inflections are checked against the same lexicon, never guessed.
    if key.EndsWith('s') then Result := stem_band(Copy(key, 1, Length(key) - 1));
    if (Result < 0) and key.EndsWith('es') then
    begin
        // Only after a sibilant or an o: boxes, wishes, goes.
        stem := Copy(key, 1, Length(key) - 2);
        if stem.EndsWith('s') or stem.EndsWith('x') or stem.EndsWith('z') or
            stem.EndsWith('ch') or stem.EndsWith('sh') or stem.EndsWith('o') then
            Result := stem_band(stem);
    end;
    if (Result < 0) and key.EndsWith('ies') then
        Result := stem_band(Copy(key, 1, Length(key) - 3) + 'y');
    if Result >= 0 then Exit;
    if key.EndsWith('ing') then stem := Copy(key, 1, Length(key) - 3)
    else if key.EndsWith('ed') then stem := Copy(key, 1, Length(key) - 2)
    else Exit;
    if not doubles_consonant(stem) then Result := stem_band(stem);
    if Result < 0 then Result := stem_band(stem + 'e');
    if (Result < 0) and (Length(stem) > 2) and
        (stem[Length(stem)] = stem[Length(stem) - 1]) then
        Result := stem_band(Copy(stem, 1, Length(stem) - 1));
end;

function plausible_english_spelling(const key: string): Boolean;
var padded: string; idx, gram, vowel_count, supported: Integer;
begin
    Result := False;
    if Length(key) < 4 then Exit;
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

function nc_english_evidence(const text: string): TncEnglishEvidence;
var key: string; ch: Char;
begin
    Result.listed := False;
    Result.band := -1;
    Result.spelled := False;
    Result.pinyin_like := False;
    Result.in_progress := False;
    Result.dictionary := False;
    Result.complete := False;
    if (Length(text) < 2) or (Length(text) > 32) then Exit;
    key := LowerCase(text);
    for ch in key do
        if not CharInSet(ch, ['a'..'z']) then Exit;
    Result.band := inflection_band(key);
    Result.listed := Result.band >= 0;
    if Result.listed then
    begin
        Result.dictionary := (Result.band and 4) <> 0;
        Result.band := Result.band and 3;
    end;
    Result.complete := complete_pinyin(nc_normalize_umlaut_spelling(key));
    Result.spelled := (not Result.listed) and plausible_english_spelling(key);
    // Unknown names get stronger Chinese protection: one abbreviated syllable
    // may precede a complete or unfinished pinyin tail.
    Result.in_progress := plausible_pinyin(nc_normalize_umlaut_spelling(key), False);
    Result.pinyin_like := Result.in_progress or ((not Result.listed) and
        plausible_pinyin(nc_normalize_umlaut_spelling(key), True));
end;

function nc_is_pinyin_syllable_prefix(const lower_text: string): Boolean;
begin
    Result := g_pinyin_prefixes.ContainsKey(nc_normalize_umlaut_spelling(lower_text));
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
    nc_english_trace := GetEnvironmentVariable('CASSOTIS_ENGLISH_TRACE') = '1';
finalization
    g_pinyin_prefixes.Free;
end.
