unit nc_pinyin_parser;

interface

uses
    System.SysUtils;

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

function match_prefix(const input_text: string; const start_index: Integer; const values: array of string): string;
var
    i: Integer;
    pos_index: Integer;
    candidate: string;
begin
    Result := '';
    pos_index := start_index + 1;
    for i := Low(values) to High(values) do
    begin
        candidate := values[i];
        if candidate = '' then
        begin
            Continue;
        end;

        if pos_index + Length(candidate) - 1 > Length(input_text) then
        begin
            Continue;
        end;

        if Copy(input_text, pos_index, Length(candidate)) = candidate then
        begin
            Result := candidate;
            Exit;
        end;
    end;
end;

function TncPinyinParser.parse(const input_text: string): TncPinyinParseResult; 
var
    cursor: Integer;
    text_length: Integer;
    initial: string;
    final: string;
    syllable_text: string;
    syllable_length: Integer;
    result_list: TncPinyinParseResult;

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
begin
    SetLength(result_list, 0);
    if input_text = '' then
    begin
        Result := result_list;
        Exit;
    end;

    cursor := 0;
    text_length := Length(input_text);
    while cursor < text_length do
    begin
        if input_text[cursor + 1] = '''' then
        begin
            Inc(cursor);
            Continue;
        end;

        initial := match_prefix(input_text, cursor, c_initials);
        if initial <> '' then
        begin
            final := match_prefix(input_text, cursor + Length(initial), c_finals);
            if final = '' then
            begin
                append_syllable(input_text[cursor + 1], cursor, 1);
                Inc(cursor);
                Continue;
            end;
        end
        else
        begin
            final := match_prefix(input_text, cursor, c_finals);
        end;

        if final = '' then
        begin
            append_syllable(input_text[cursor + 1], cursor, 1);
            Inc(cursor);
            Continue;
        end;

        syllable_text := initial + final;
        syllable_length := Length(syllable_text);
        append_syllable(syllable_text, cursor, syllable_length);
        Inc(cursor, syllable_length);
    end;

    Result := result_list;
end;

end.
