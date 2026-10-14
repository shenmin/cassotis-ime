unit nc_custom_phrases;

interface

uses System.SysUtils, System.JSON, System.Generics.Collections, nc_types;

const
    c_custom_phrase_max_count = 1024;
    c_custom_phrase_max_shortcut = 32;
    c_custom_phrase_max_text = 4096;

function nc_custom_phrase_key(const value: string): string;
function nc_custom_phrase_text_valid(const value: string): Boolean;
function nc_custom_phrases_equal(const left, right: TncCustomPhraseList): Boolean;
function nc_custom_phrases_to_json(const phrases: TncCustomPhraseList): string;
function nc_parse_custom_phrases(const value: string;
    out phrases: TncCustomPhraseList): Boolean;
function nc_custom_phrase_preview(const value: string): string;

implementation

function nc_custom_phrase_key(const value: string): string;
var ch: Char;
begin
    Result := LowerCase(Trim(value));
    if (Length(Result) = 0) or (Length(Result) > c_custom_phrase_max_shortcut) then
        Exit('');
    for ch in Result do
        if not CharInSet(ch, ['a'..'z']) then Exit('');
end;

function nc_custom_phrase_text_valid(const value: string): Boolean;
var ch: Char;
begin
    Result := (Trim(value) <> '') and (Length(value) <= c_custom_phrase_max_text);
    if not Result then Exit;
    for ch in value do
        if (Ord(ch) < 32) and not CharInSet(ch, [#9, #10, #13]) then Exit(False);
end;

function nc_custom_phrases_equal(const left, right: TncCustomPhraseList): Boolean;
var idx: Integer;
begin
    if Length(left) <> Length(right) then Exit(False);
    for idx := 0 to High(left) do
        if (left[idx].shortcut <> right[idx].shortcut) or
            (left[idx].text <> right[idx].text) then Exit(False);
    Result := True;
end;

function nc_custom_phrases_to_json(const phrases: TncCustomPhraseList): string;
var rows, row: TJSONArray; phrase: TncCustomPhrase;
begin
    rows := TJSONArray.Create;
    try
        for phrase in phrases do
        begin
            row := TJSONArray.Create;
            rows.AddElement(row);
            row.Add(phrase.shortcut);
            row.Add(phrase.text);
        end;
        Result := rows.ToJSON;
    finally
        rows.Free;
    end;
end;

function nc_parse_custom_phrases(const value: string;
    out phrases: TncCustomPhraseList): Boolean;
var json: TJSONValue; rows, row: TJSONArray;
    parsed: TncCustomPhraseList; idx: Integer;
begin
    phrases := nil;
    if Trim(value) = '' then Exit(True);
    json := TJSONObject.ParseJSONValue(value);
    try
        if not (json is TJSONArray) then Exit(False);
        rows := TJSONArray(json);
        if rows.Count > c_custom_phrase_max_count then Exit(False);
        SetLength(parsed, rows.Count);
        for idx := 0 to rows.Count - 1 do
        begin
            if not (rows.Items[idx] is TJSONArray) then Exit(False);
            row := TJSONArray(rows.Items[idx]);
            if (row.Count <> 2) or (row.Items[0].ClassType <> TJSONString) or
                (row.Items[1].ClassType <> TJSONString) then Exit(False);
            parsed[idx].shortcut := nc_custom_phrase_key(row.Items[0].Value);
            parsed[idx].text := row.Items[1].Value;
            if (parsed[idx].shortcut = '') or
                not nc_custom_phrase_text_valid(parsed[idx].text) then Exit(False);
        end;
        phrases := parsed;
        Result := True;
    finally
        json.Free;
    end;
end;

function nc_custom_phrase_preview(const value: string): string;
var idx, count: Integer;
begin
    count := Length(value);
    if count > 120 then
    begin
        count := 120;
        if (Ord(value[count]) >= $D800) and (Ord(value[count]) <= $DBFF) then
            Dec(count);
    end;
    Result := Copy(value, 1, count);
    for idx := 1 to Length(Result) do
        if CharInSet(Result[idx], [#9, #10, #13]) then Result[idx] := ' ';
    if count < Length(value) then Result := Result + '...';
end;

end.
