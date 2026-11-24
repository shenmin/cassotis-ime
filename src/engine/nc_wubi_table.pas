unit nc_wubi_table;

{ The Wubi 86 code table of the Wubi/pinyin mixed scheme: the lexicon's
  data/generated/wubi86_table.txt, from SUN Haifeng's tables (BSD-3-Clause).
  It is read only in that scheme and has nothing to do with the pinyin
  dictionaries. Rows are code, text, kind, rank within the code and, for a
  word, its score in the general text (100 * log10(1 + occurrences)). }

interface

uses
    System.SysUtils, System.Classes, System.Generics.Collections;

type
    // The kinds of the table file (its column 3).
    TncWubiEntryKind = (
        wek_none,
        // A common character: before the words of its code.
        wek_common_char,
        wek_word,
        // Any other character: after the words of its code.
        wek_char,
        // A character under its 86 tolerant code, on a code Haifeng leaves empty.
        wek_tolerant,
        // A dictionary word coded by the word-code rule, on a code Haifeng
        // leaves empty. It never commits itself.
        wek_lexicon_word
    );

    TncWubiEntry = record
        code: string;
        text: string;
        kind: TncWubiEntryKind;
        score: Integer;
    end;
    TncWubiEntries = TArray<TncWubiEntry>;

    TncWubiTable = class
    private
        m_codes: TArray<string>;
        // Entries of m_codes[i] are m_first[i] .. m_first[i + 1] - 1.
        m_first: TArray<Integer>;
        m_texts: TArray<string>;
        m_kinds: TArray<TncWubiEntryKind>;
        m_scores: TArray<Integer>;
        m_full_codes: TDictionary<string, string>;
        m_shortest_codes: TDictionary<string, string>;
        function lower_bound(const code: string): Integer;
        function find_code(const code: string): Integer;
        function entry_at(const code_index: Integer; const entry_index: Integer): TncWubiEntry;
    public
        constructor Create;
        destructor Destroy; override;
        procedure load_from_lines(const lines: TStrings);
        function load_from_file(const path: string): Boolean;
        function code_count: Integer;
        function entry_count: Integer;
        // The entries of a code in the table's order.
        function lookup(const code: string): TncWubiEntries;
        function entry_total(const code: string): Integer;
        // The entries of every code that begins with prefix and is longer.
        function lookup_longer(const prefix: string): TncWubiEntries;
        // A character's 86 full code (its longest code that is no tolerant
        // code) and its shortest code; '' for a character the table lacks.
        function full_code(const ch: string): string;
        function shortest_code(const ch: string): string;
        // The 86 word-code rule from the characters' full codes: two
        // characters take two keys of each, three the first key of the first
        // two and two keys of the last, four or more the first key of the
        // first three and of the last. '' for a single character or when a
        // character has no code.
        function word_code(const text: string): string;
    end;

function nc_is_wubi_key(const ch: Char): Boolean;
// One to four of the keys a to y.
function nc_is_wubi_code_text(const text: string): Boolean;
function nc_wubi_text_chars(const text: string): TArray<string>;
// One table a path for the whole process, read when first asked for; nil
// when the file cannot be read.
function nc_wubi_shared_table(const path: string): TncWubiTable;

implementation

uses
    System.SyncObjs, System.Generics.Defaults;

type
    TncWubiRow = record
        code: string;
        text: string;
        kind: TncWubiEntryKind;
        rank: Integer;
        score: Integer;
    end;

var
    g_shared_lock: TCriticalSection;
    g_shared_tables: TObjectDictionary<string, TncWubiTable>;

function nc_is_wubi_key(const ch: Char): Boolean;
begin
    Result := (ch >= 'a') and (ch <= 'y');
end;

function nc_is_wubi_code_text(const text: string): Boolean;
var
    idx: Integer;
begin
    Result := (Length(text) >= 1) and (Length(text) <= 4);
    if not Result then Exit;
    for idx := 1 to Length(text) do
        if not nc_is_wubi_key(text[idx]) then Exit(False);
end;

function nc_wubi_text_chars(const text: string): TArray<string>;
var
    idx, count: Integer;
begin
    SetLength(Result, Length(text));
    count := 0;
    idx := 1;
    while idx <= Length(text) do
    begin
        if (text[idx] >= #$D800) and (text[idx] <= #$DBFF) and (idx < Length(text)) and
            (text[idx + 1] >= #$DC00) and (text[idx + 1] <= #$DFFF) then
        begin
            Result[count] := Copy(text, idx, 2);
            Inc(idx, 2);
        end
        else
        begin
            Result[count] := text[idx];
            Inc(idx);
        end;
        Inc(count);
    end;
    SetLength(Result, count);
end;

constructor TncWubiTable.Create;
begin
    inherited Create;
    m_full_codes := TDictionary<string, string>.Create;
    m_shortest_codes := TDictionary<string, string>.Create;
end;

destructor TncWubiTable.Destroy;
begin
    m_full_codes.Free;
    m_shortest_codes.Free;
    inherited Destroy;
end;

procedure TncWubiTable.load_from_lines(const lines: TStrings);
var
    rows: TArray<TncWubiRow>;
    count, idx, code_idx, kind_value: Integer;
    line: string;
    fields: TArray<string>;
    row: TncWubiRow;
    known: string;
begin
    SetLength(rows, lines.Count);
    count := 0;
    for idx := 0 to lines.Count - 1 do
    begin
        line := lines[idx];
        if (line = '') or (line[1] = '#') then Continue;
        fields := line.Split([#9]);
        if Length(fields) < 4 then Continue;
        row.code := fields[0];
        row.text := fields[1];
        kind_value := StrToIntDef(fields[2], 0);
        if (not nc_is_wubi_code_text(row.code)) or (row.text = '') or
            (kind_value < Ord(wek_common_char)) or (kind_value > Ord(High(TncWubiEntryKind))) then
            Continue;
        row.kind := TncWubiEntryKind(kind_value);
        row.rank := StrToIntDef(fields[3], MaxInt);
        if Length(fields) >= 5 then
            row.score := StrToIntDef(fields[4], 0)
        else
            row.score := 0;
        rows[count] := row;
        Inc(count);
    end;
    SetLength(rows, count);
    TArray.Sort<TncWubiRow>(rows, TComparer<TncWubiRow>.Construct(
        function(const left, right: TncWubiRow): Integer
        begin
            Result := CompareStr(left.code, right.code);
            if Result = 0 then
                Result := left.rank - right.rank;
        end));

    SetLength(m_texts, count);
    SetLength(m_kinds, count);
    SetLength(m_scores, count);
    SetLength(m_codes, count);
    SetLength(m_first, count + 1);
    m_full_codes.Clear;
    m_shortest_codes.Clear;
    code_idx := -1;
    for idx := 0 to count - 1 do
    begin
        row := rows[idx];
        if (code_idx < 0) or (m_codes[code_idx] <> row.code) then
        begin
            Inc(code_idx);
            m_codes[code_idx] := row.code;
            m_first[code_idx] := idx;
        end;
        m_texts[idx] := row.text;
        m_kinds[idx] := row.kind;
        m_scores[idx] := row.score;
        if (row.kind in [wek_common_char, wek_char]) and
            (Length(nc_wubi_text_chars(row.text)) = 1) then
        begin
            if (not m_full_codes.TryGetValue(row.text, known)) or
                (Length(row.code) > Length(known)) then
                m_full_codes.AddOrSetValue(row.text, row.code);
            if (not m_shortest_codes.TryGetValue(row.text, known)) or
                (Length(row.code) < Length(known)) then
                m_shortest_codes.AddOrSetValue(row.text, row.code);
        end;
    end;
    SetLength(m_codes, code_idx + 1);
    SetLength(m_first, code_idx + 2);
    m_first[code_idx + 1] := count;
end;

function TncWubiTable.load_from_file(const path: string): Boolean;
var
    lines: TStringList;
begin
    Result := False;
    if (path = '') or not FileExists(path) then Exit;
    lines := TStringList.Create;
    try
        try
            lines.LoadFromFile(path, TEncoding.UTF8);
        except
            Exit;
        end;
        load_from_lines(lines);
        Result := Length(m_codes) > 0;
    finally
        lines.Free;
    end;
end;

function TncWubiTable.code_count: Integer;
begin
    Result := Length(m_codes);
end;

function TncWubiTable.entry_count: Integer;
begin
    Result := Length(m_texts);
end;

function TncWubiTable.lower_bound(const code: string): Integer;
var
    low, high, mid: Integer;
begin
    low := 0;
    high := Length(m_codes);
    while low < high do
    begin
        mid := (low + high) div 2;
        if CompareStr(m_codes[mid], code) < 0 then
            low := mid + 1
        else
            high := mid;
    end;
    Result := low;
end;

function TncWubiTable.find_code(const code: string): Integer;
begin
    Result := lower_bound(code);
    if (Result >= Length(m_codes)) or (m_codes[Result] <> code) then
        Result := -1;
end;

function TncWubiTable.entry_at(const code_index: Integer; const entry_index: Integer): TncWubiEntry;
begin
    Result.code := m_codes[code_index];
    Result.text := m_texts[entry_index];
    Result.kind := m_kinds[entry_index];
    Result.score := m_scores[entry_index];
end;

function TncWubiTable.lookup(const code: string): TncWubiEntries;
var
    code_idx, idx: Integer;
begin
    Result := nil;
    code_idx := find_code(code);
    if code_idx < 0 then Exit;
    SetLength(Result, m_first[code_idx + 1] - m_first[code_idx]);
    for idx := m_first[code_idx] to m_first[code_idx + 1] - 1 do
        Result[idx - m_first[code_idx]] := entry_at(code_idx, idx);
end;

function TncWubiTable.entry_total(const code: string): Integer;
var
    code_idx: Integer;
begin
    code_idx := find_code(code);
    if code_idx < 0 then
        Result := 0
    else
        Result := m_first[code_idx + 1] - m_first[code_idx];
end;

function TncWubiTable.lookup_longer(const prefix: string): TncWubiEntries;
var
    code_idx, idx, count: Integer;
begin
    Result := nil;
    if prefix = '' then Exit;
    count := 0;
    code_idx := lower_bound(prefix);
    while (code_idx < Length(m_codes)) and
        (Copy(m_codes[code_idx], 1, Length(prefix)) = prefix) do
    begin
        if Length(m_codes[code_idx]) > Length(prefix) then
            for idx := m_first[code_idx] to m_first[code_idx + 1] - 1 do
            begin
                if count >= Length(Result) then
                    SetLength(Result, Length(Result) * 2 + 16);
                Result[count] := entry_at(code_idx, idx);
                Inc(count);
            end;
        Inc(code_idx);
    end;
    SetLength(Result, count);
end;

function TncWubiTable.full_code(const ch: string): string;
begin
    if not m_full_codes.TryGetValue(ch, Result) then
        Result := '';
end;

function TncWubiTable.shortest_code(const ch: string): string;
begin
    if not m_shortest_codes.TryGetValue(ch, Result) then
        Result := '';
end;

function TncWubiTable.word_code(const text: string): string;
var
    chars: TArray<string>;
    codes: TArray<string>;
    idx: Integer;
begin
    Result := '';
    chars := nc_wubi_text_chars(text);
    if Length(chars) < 2 then Exit;
    SetLength(codes, Length(chars));
    for idx := 0 to High(chars) do
    begin
        codes[idx] := full_code(chars[idx]);
        if codes[idx] = '' then Exit;
    end;
    case Length(chars) of
        2: Result := Copy(codes[0], 1, 2) + Copy(codes[1], 1, 2);
        3: Result := Copy(codes[0], 1, 1) + Copy(codes[1], 1, 1) + Copy(codes[2], 1, 2);
    else
        Result := Copy(codes[0], 1, 1) + Copy(codes[1], 1, 1) + Copy(codes[2], 1, 1) +
            Copy(codes[High(codes)], 1, 1);
    end;
end;

function nc_wubi_shared_table(const path: string): TncWubiTable;
var
    key: string;
    table: TncWubiTable;
begin
    Result := nil;
    if path = '' then Exit;
    key := LowerCase(ExpandFileName(path));
    g_shared_lock.Enter;
    try
        if g_shared_tables.TryGetValue(key, Result) then Exit;
        table := TncWubiTable.Create;
        if table.load_from_file(path) then
        begin
            g_shared_tables.Add(key, table);
            Result := table;
        end
        else
            table.Free;
    finally
        g_shared_lock.Leave;
    end;
end;

initialization
    g_shared_lock := TCriticalSection.Create;
    g_shared_tables := TObjectDictionary<string, TncWubiTable>.Create([doOwnsValues]);

finalization
    g_shared_tables.Free;
    g_shared_lock.Free;

end.
