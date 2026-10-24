unit nc_user_word_import;

{ Reads a list of the user's own words with how often they typed them, as
  other input methods export it, for the user dictionary. Two forms:
  - "1. text <dash> 2392 <times> <dash> pinyin", one word a line, the dash
    U+2014 (an export of one's own typing statistics);
  - tab-separated fields holding the text, its pinyin and optionally the
    count, in any order (the pinyin is the field of Latin letters, the count
    the field of digits).
  Blank lines and lines starting with # are no entries; any other line that
  is not one counts as skipped. }

interface

uses
    System.SysUtils, System.Math;

type
    TncUserWordImportEntry = record
        pinyin: string;
        text: string;
        count: Integer;
    end;

    TncUserWordImportEntries = TArray<TncUserWordImportEntry>;

function nc_parse_user_word_import(const content: string;
    out entries: TncUserWordImportEntries; out skipped: Integer): Boolean;

{ The text of such a file: by its byte order mark, else UTF-8 when the bytes
  are valid UTF-8, else the system code page (GBK on a Chinese system). }
function nc_read_user_word_import_file(const path: string; out content: string): Boolean;

implementation

uses
    System.Classes, System.IOUtils, Winapi.Windows;

const
    c_dash = #$2014;
    c_times = #$6B21;

function normalize_pinyin(const value: string; out pinyin: string): Boolean;
var
    ch: Char;
begin
    pinyin := '';
    for ch in LowerCase(Trim(value)) do
    begin
        if CharInSet(ch, ['a'..'z', '''']) then
            pinyin := pinyin + ch
        else if ch <> ' ' then
            Exit(False);
    end;
    while (pinyin <> '') and (pinyin[1] = '''') do
        Delete(pinyin, 1, 1);
    while (pinyin <> '') and (pinyin[Length(pinyin)] = '''') do
        Delete(pinyin, Length(pinyin), 1);
    Result := pinyin <> '';
end;

function parse_count(const value: string; out count: Integer): Boolean;
var
    digits: string;
begin
    digits := Trim(value);
    if (digits <> '') and (digits[Length(digits)] = c_times) then
        digits := Trim(Copy(digits, 1, Length(digits) - 1));
    Result := TryStrToInt(digits, count) and (count > 0);
end;

function has_latin_letter(const value: string): Boolean;
var
    ch: Char;
begin
    for ch in value do
        if CharInSet(ch, ['a'..'z', 'A'..'Z']) then
            Exit(True);
    Result := False;
end;

// "N. text": the leading ordinal and its dot go.
function strip_ordinal(const value: string): string;
var
    idx: Integer;
begin
    Result := Trim(value);
    idx := 1;
    while (idx <= Length(Result)) and CharInSet(Result[idx], ['0'..'9']) do
        Inc(idx);
    if (idx > 1) and (idx <= Length(Result)) and (Result[idx] = '.') then
        Result := Trim(Copy(Result, idx + 1, MaxInt));
end;

function parse_dashed(const line: string; out entry: TncUserWordImportEntry): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    parts := line.Split([c_dash]);
    if Length(parts) <> 3 then
        Exit;
    entry.text := strip_ordinal(parts[0]);
    Result := (entry.text <> '') and (not has_latin_letter(entry.text)) and
        parse_count(parts[1], entry.count) and normalize_pinyin(parts[2], entry.pinyin);
end;

function parse_tabbed(const line: string; out entry: TncUserWordImportEntry): Boolean;
var
    field, pinyin: string;
    count: Integer;
begin
    Result := False;
    entry := Default(TncUserWordImportEntry);
    entry.count := 0;
    for field in line.Split([#9]) do
    begin
        if Trim(field) = '' then
            Continue;
        if (entry.count = 0) and parse_count(field, count) then
            entry.count := count
        else if (entry.pinyin = '') and has_latin_letter(field) and normalize_pinyin(field, pinyin) then
            entry.pinyin := pinyin
        else if (entry.text = '') and not has_latin_letter(field) then
            entry.text := Trim(field)
        else
            Exit;
    end;
    if entry.count = 0 then
        entry.count := 1;
    Result := (entry.text <> '') and (entry.pinyin <> '');
end;

function nc_parse_user_word_import(const content: string;
    out entries: TncUserWordImportEntries; out skipped: Integer): Boolean;
var
    line, trimmed: string;
    entry: TncUserWordImportEntry;
    count: Integer;
    parsed: Boolean;
begin
    entries := nil;
    skipped := 0;
    count := 0;
    for line in content.Replace(#13#10, #10).Replace(#13, #10).Split([#10]) do
    begin
        trimmed := Trim(line);
        if (trimmed <> '') and (trimmed[1] = #$FEFF) then
            trimmed := Trim(Copy(trimmed, 2, MaxInt));
        if (trimmed = '') or (trimmed[1] = '#') then
            Continue;
        parsed := ((Pos(c_dash, trimmed) > 0) and parse_dashed(trimmed, entry)) or
            ((Pos(#9, trimmed) > 0) and parse_tabbed(trimmed, entry));
        if not parsed then
        begin
            Inc(skipped);
            Continue;
        end;
        if count = Length(entries) then
            SetLength(entries, Max(64, count * 2));
        entries[count] := entry;
        Inc(count);
    end;
    SetLength(entries, count);
    Result := count > 0;
end;

function nc_read_user_word_import_file(const path: string; out content: string): Boolean;
var
    bytes: TBytes;
    encoding: TEncoding;
    offset: Integer;
begin
    content := '';
    Result := False;
    try
        bytes := TFile.ReadAllBytes(path);
    except
        Exit;
    end;
    encoding := nil;
    offset := TEncoding.GetBufferEncoding(bytes, encoding);
    if offset > 0 then
        content := encoding.GetString(bytes, offset, Length(bytes) - offset)
    else if (Length(bytes) = 0) or (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
        PAnsiChar(@bytes[0]), Length(bytes), nil, 0) > 0) then
        content := TEncoding.UTF8.GetString(bytes)
    else
        content := TEncoding.Default.GetString(bytes);
    Result := True;
end;

end.
