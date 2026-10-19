unit nc_char_lm_traditional;

{ The character LM in the traditional variant. The model was trained on
  simplified text: it scores a character that only traditional text writes
  (鬆, 裡, 於) low, and without a context its choice took a word without one
  (仿宋 for "fangsong" above 放鬆 at a weight of 818 against 49, 加利 above
  家裡). The traditional variant hands the model the simplified characters of
  every text and context, and shows a character the model writes (the Tab
  area's next characters and extensions) in traditional; one that
  traditional text writes as well beside other forms (后: 後 or 后) ends what
  the model writes there. The engine's own tables write simplified
  characters too (对, 从, 让 for "dui", "cong", "rang"): nc_simplified_to_traditional
  turns every character traditional text never writes into its traditional
  form before a page or a commit leaves the engine. The tables are OpenCC's
  (nc_traditional_chars.inc, tools/build_traditional_chars.py). }

interface

uses
    System.SysUtils,
    System.Math,
    nc_char_lm;

function nc_traditional_to_simplified(const text: string): string;
{ Every character traditional text never writes in its traditional form (the
  first of several: 發 for 发); the others as they are. }
function nc_simplified_to_traditional(const text: string): string;
{ The traditional form of a character the LM wrote: as in
  nc_simplified_to_traditional, but '' for one that traditional text writes
  as well beside other forms (后: 後 or 后). }
function nc_simplified_char_to_traditional(const ch: Char): string;
{ model as the traditional variant uses it (nil stays nil). }
function nc_traditional_char_lm(const model: IncCharLm): IncCharLm;

implementation

{$I nc_traditional_chars.inc}

type
    TncTraditionalCharLm = class(TInterfacedObject, IncCharLm, IncCharLmNext, IncCharLmContinue)
    private
        m_model: IncCharLm;
    public
        constructor Create(const model: IncCharLm);
        function char_lm_ready: Boolean;
        function score_texts(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_next(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        function continue_text(const context, text: string; const max_chars: Integer;
            out chars: TArray<string>; out logp: TArray<Single>): Integer;
    end;

function find_code(const codes: array of Word; const code: Word): Integer;
var
    first, last, middle: Integer;
begin
    first := 0;
    last := High(codes);
    while first <= last do
    begin
        middle := (first + last) div 2;
        if codes[middle] = code then
            Exit(middle);
        if codes[middle] < code then
            first := middle + 1
        else
            last := middle - 1;
    end;
    Result := -1;
end;

function nc_traditional_to_simplified(const text: string): string;
var
    idx, found: Integer;
begin
    Result := text;
    for idx := 1 to Length(Result) do
    begin
        found := find_code(c_traditional_chars, Word(Result[idx]));
        if found >= 0 then
            Result[idx] := Char(c_traditional_simplified[found]);
    end;
end;

function nc_simplified_to_traditional(const text: string): string;
var
    idx, found: Integer;
begin
    Result := text;
    for idx := 1 to Length(Result) do
    begin
        found := find_code(c_simplified_chars, Word(Result[idx]));
        if found >= 0 then
            Result[idx] := Char(c_simplified_traditional[found]);
    end;
end;

function nc_simplified_char_to_traditional(const ch: Char): string;
var
    found: Integer;
begin
    if find_code(c_simplified_ambiguous, Word(ch)) >= 0 then
        Exit('');
    found := find_code(c_simplified_chars, Word(ch));
    if found >= 0 then
        Result := Char(c_simplified_traditional[found])
    else
        Result := ch;
end;

function written_to_traditional(const text: string): string;
var
    idx: Integer;
    converted: string;
begin
    Result := '';
    for idx := 1 to Length(text) do
    begin
        converted := nc_simplified_char_to_traditional(text[idx]);
        if converted = '' then
            Exit('');
        Result := Result + converted;
    end;
end;

function convert_texts(const texts: TArray<string>): TArray<string>;
var
    idx: Integer;
begin
    SetLength(Result, Length(texts));
    for idx := 0 to High(texts) do
        Result[idx] := nc_traditional_to_simplified(texts[idx]);
end;

constructor TncTraditionalCharLm.Create(const model: IncCharLm);
begin
    inherited Create;
    m_model := model;
end;

function TncTraditionalCharLm.char_lm_ready: Boolean;
begin
    Result := m_model.char_lm_ready;
end;

function TncTraditionalCharLm.score_texts(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
begin
    Result := m_model.score_texts(nc_traditional_to_simplified(context), convert_texts(texts),
        min_count, max_nodes, logp);
end;

function TncTraditionalCharLm.score_texts_next(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
    const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
    out next_logp: TArray<Single>): Integer;
var
    next_model: IncCharLmNext;
    idx: Integer;
begin
    if not Supports(m_model, IncCharLmNext, next_model) then
    begin
        Result := score_texts(context, texts, min_count, max_nodes, logp);
        SetLength(next_chars, Length(next_texts) * top_k);
        SetLength(next_logp, Length(next_texts) * top_k);
        Exit;
    end;
    Result := next_model.score_texts_next(nc_traditional_to_simplified(context),
        convert_texts(texts), min_count, max_nodes, next_texts, top_k, logp, next_chars,
        next_logp);
    for idx := 0 to High(next_chars) do
        next_chars[idx] := written_to_traditional(next_chars[idx]);
end;

function TncTraditionalCharLm.continue_text(const context, text: string; const max_chars: Integer;
    out chars: TArray<string>; out logp: TArray<Single>): Integer;
var
    continuer: IncCharLmContinue;
    idx: Integer;
begin
    SetLength(chars, 0);
    SetLength(logp, 0);
    if not Supports(m_model, IncCharLmContinue, continuer) then
        Exit(-1);
    Result := continuer.continue_text(nc_traditional_to_simplified(context),
        nc_traditional_to_simplified(text), max_chars, chars, logp);
    for idx := 0 to Min(Result, Length(chars)) - 1 do
    begin
        chars[idx] := written_to_traditional(chars[idx]);
        if chars[idx] = '' then
        begin
            Result := idx;
            Break;
        end;
    end;
end;

function nc_traditional_char_lm(const model: IncCharLm): IncCharLm;
begin
    if model = nil then
        Result := nil
    else
        Result := TncTraditionalCharLm.Create(model);
end;

end.
