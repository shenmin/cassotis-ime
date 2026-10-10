unit nc_punctuation_key_context;

interface

uses
    Winapi.Windows, Winapi.Msctf, nc_types;

type
    // Only a directly typed digit can arm decimal punctuation. Document text,
    // pasted numbers and numeric candidate selections must not do so.
    TncPunctuationKeyContext = record
    private
        m_digit: Char;
    public
        procedure clear;
        procedure observe_key(const key_code: Word; const state: TncKeyState;
            const handled, composing: Boolean; const translated_char: Char);
        function digit_char: Integer;
        function has_digit: Boolean;
    end;

function nc_edit_record_moves_selection_only(const edit: ITfEditRecord): Boolean;

implementation

function nc_edit_record_moves_selection_only(const edit: ITfEditRecord): Boolean;
const
    c_include_text_updates = 1; // TF_GTP_INCL_TEXT
var
    changed: Integer;
    ranges: IEnumTfRanges;
    range: ITfRange;
    fetched: ULONG;
begin
    Result := False;
    if (edit = nil) or (edit.GetSelectionStatus(changed) <> S_OK) or
        (changed = 0) then Exit;
    if (edit.GetTextAndPropertyUpdates(c_include_text_updates, nil, 0, ranges) <> S_OK) or
        (ranges = nil) then Exit;
    fetched := 0;
    Result := (ranges.Next(1, range, fetched) = S_FALSE) and (fetched = 0);
end;

procedure TncPunctuationKeyContext.clear;
begin
    m_digit := #0;
end;

procedure TncPunctuationKeyContext.observe_key(const key_code: Word;
    const state: TncKeyState; const handled, composing: Boolean;
    const translated_char: Char);
begin
    // TestKeyDown runs before PROCESS_KEY. Do not erase the preceding digit
    // while asking whether the period itself will be handled.
    if handled and (key_code in [VK_OEM_PERIOD, VK_DECIMAL]) and
        not (state.shift_down or state.ctrl_down or state.alt_down) then Exit;
    clear;
    if not handled and not composing and
        not (state.shift_down or state.ctrl_down or state.alt_down) and
        (translated_char >= '0') and (translated_char <= '9') then
        m_digit := translated_char;
end;

function TncPunctuationKeyContext.digit_char: Integer;
begin
    Result := Ord(m_digit);
end;

function TncPunctuationKeyContext.has_digit: Boolean;
begin
    Result := m_digit <> #0;
end;

end.
