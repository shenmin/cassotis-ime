unit nc_wubi_input;

{ The rules where Wubi 86 and full pinyin meet in one composition (the
  Wubi/pinyin mixed scheme). Letters that read as full pinyin (syllables with
  a vowel, the last one possibly still being typed) stay open for pinyin: a
  unique code of four keys commits itself only when its letters do not read
  so, and the key after a code of four keys commits its first entry only when
  the five letters do not. Pinyin typed in full is therefore never cut off by
  a Wubi code; a Wubi code that also reads as pinyin waits for the next key
  (out/wubi_lm_20261123, interference.py: such unique codes are 5.9% of the
  codes of four keys in general text and 4.2% in fiction, and 2.6% and 1.5%
  still read as pinyin with the next key). }

interface

type
    TncWubiPinyinReading = (wpr_none, wpr_complete, wpr_in_progress);

// How full pinyin reads the letters: whole syllables, whole syllables and the
// beginning of one more, or neither. A syllable needs a vowel: n, m, ng, hm
// and r alone do not count, or nearly any string of consonants would read.
function nc_wubi_pinyin_reading(const letters: string): TncWubiPinyinReading;
function nc_wubi_reads_full_pinyin(const letters: string): Boolean;
// Letters that are all initials of pinyin, as an abbreviation types them.
function nc_wubi_letters_are_initials(const letters: string): Boolean;

implementation

uses
    System.SysUtils, nc_pinyin_parser;

function has_vowel(const value: string): Boolean;
var
    idx: Integer;
begin
    for idx := 1 to Length(value) do
        if CharInSet(value[idx], ['a', 'e', 'i', 'o', 'u', 'v']) then Exit(True);
    Result := False;
end;

function is_syllable(const value: string): Boolean;
begin
    Result := has_vowel(value) and nc_is_canonical_pinyin_syllable(value);
end;

function nc_wubi_pinyin_reading(const letters: string): TncWubiPinyinReading;
const
    c_max_syllable = 6;
var
    reach: TArray<Boolean>;
    n, i, j: Integer;
begin
    Result := wpr_none;
    n := Length(letters);
    if n = 0 then Exit;
    for i := 1 to n do
        if not CharInSet(letters[i], ['a'..'z']) then Exit;
    SetLength(reach, n + 1);
    reach[0] := True;
    for i := 0 to n - 1 do
    begin
        if not reach[i] then Continue;
        for j := i + 1 to i + c_max_syllable do
        begin
            if j > n then Break;
            if is_syllable(Copy(letters, i + 1, j - i)) then
                reach[j] := True;
        end;
    end;
    if reach[n] then Exit(wpr_complete);
    for i := 0 to n - 1 do
        if reach[i] and (n - i <= c_max_syllable) and
            nc_canonical_pinyin_syllable_begins_with(Copy(letters, i + 1, n - i)) then
            Exit(wpr_in_progress);
end;

function nc_wubi_reads_full_pinyin(const letters: string): Boolean;
begin
    Result := nc_wubi_pinyin_reading(letters) <> wpr_none;
end;

function nc_wubi_letters_are_initials(const letters: string): Boolean;
var
    idx: Integer;
begin
    Result := letters <> '';
    for idx := 1 to Length(letters) do
        if not CharInSet(letters[idx], ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j',
            'q', 'x', 'r', 'z', 'c', 's', 'y', 'w']) then
            Exit(False);
end;

end.
