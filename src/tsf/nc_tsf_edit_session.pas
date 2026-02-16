unit nc_tsf_edit_session;

interface

uses
    Winapi.Windows,
    Winapi.ActiveX,
    Winapi.Msctf,
    System.SysUtils,
    System.Types,
    System.Variants;

type
    PITfComposition = ^ITfComposition;

    TncCommitEditSession = class(TInterfacedObject, ITfEditSession)
    private
        m_context: ITfContext;
        m_composition_ref: PITfComposition;
        m_text: string;
    public
        constructor create(const context: ITfContext; const composition_ref: PITfComposition; const text: string);
        function DoEditSession(ec: TfEditCookie): HResult; stdcall;
    end;

    TncCaretEditSession = class(TInterfacedObject, ITfEditSession)
    private
        m_context: ITfContext;
        m_composition_ref: PITfComposition;
        m_point_ref: PPoint;
        m_point_valid_ref: PBoolean;
        function update_text_ext(const ec: TfEditCookie): Boolean;
    public
        constructor create(const context: ITfContext; const composition_ref: PITfComposition; const point_ref: PPoint;
            const point_valid_ref: PBoolean);
        function DoEditSession(ec: TfEditCookie): HResult; stdcall;
    end;

    TncSurroundingTextEditSession = class(TInterfacedObject, ITfEditSession)
    private
        m_context: ITfContext;
        m_composition_ref: PITfComposition;
        m_max_chars: Integer;
        m_out_text: PString;
        function read_left_text(const ec: TfEditCookie): Boolean;
    public
        constructor create(const context: ITfContext; const composition_ref: PITfComposition; const max_chars: Integer;
            const out_text: PString);
        function DoEditSession(ec: TfEditCookie): HResult; stdcall;
    end;

    TncCompositionEditSession = class(TInterfacedObject, ITfEditSession)
    private
        m_context: ITfContext;
        m_sink: ITfCompositionSink;
        m_composition_ref: PITfComposition;
        m_text: string;
        m_confirmed_length: Integer;
        m_attr_input_atom: TfGuidAtom;
        m_point_ref: PPoint;
        m_point_valid_ref: PBoolean;
        function start_composition(const ec: TfEditCookie): Boolean;
        function update_composition_text(const ec: TfEditCookie): Boolean;
        function end_composition(const ec: TfEditCookie): Boolean;
        function update_text_ext(const ec: TfEditCookie): Boolean;
        procedure apply_display_attributes(const ec: TfEditCookie; const range: ITfRange);
    public
        constructor create(const context: ITfContext; const sink: ITfCompositionSink;
            const composition_ref: PITfComposition; const text: string; const point_ref: PPoint;
            const point_valid_ref: PBoolean; const confirmed_length: Integer; const attr_input_atom: TfGuidAtom);
        function DoEditSession(ec: TfEditCookie): HResult; stdcall;
    end;

implementation

const
    c_guid_prop_attribute: TGUID = '{34B45670-7526-11D2-A147-00105A2799B5}';
    c_guid_prop_composing: TGUID = '{E12AC060-AF15-11D0-97F0-00C04FD9C1B6}';

constructor TncCommitEditSession.create(const context: ITfContext; const composition_ref: PITfComposition;
    const text: string);
begin
    inherited create;
    m_context := context;
    m_composition_ref := composition_ref;
    m_text := text;
end;

constructor TncCaretEditSession.create(const context: ITfContext; const composition_ref: PITfComposition; const point_ref: PPoint;
    const point_valid_ref: PBoolean);
begin
    inherited create;
    m_context := context;
    m_composition_ref := composition_ref;
    m_point_ref := point_ref;
    m_point_valid_ref := point_valid_ref;
end;

function TncCaretEditSession.update_text_ext(const ec: TfEditCookie): Boolean;
var
    view: ITfContextView;
    range: ITfRange;
    range_for_ext: ITfRange;
    selection: TF_SELECTION;
    fetched: ULONG;
    rect: Winapi.Windows.TRect;
    screen_rect: Winapi.Windows.TRect;
    rect_adjusted: Winapi.Windows.TRect;
    clipped: Integer;
    hr: HRESULT;
    screen_ok: Boolean;

    function rect_in_screen(const candidate: Winapi.Windows.TRect;
        const screen_bounds: Winapi.Windows.TRect): Boolean;
    const
        c_screen_margin = 200;
    begin
        Result := (candidate.Left >= screen_bounds.Left - c_screen_margin) and
            (candidate.Left <= screen_bounds.Right + c_screen_margin) and
            (candidate.Top >= screen_bounds.Top - c_screen_margin) and
            (candidate.Top <= screen_bounds.Bottom + c_screen_margin);
    end;
begin
    Result := False;
    if (m_context = nil) or (m_point_ref = nil) or (m_point_valid_ref = nil) then
    begin
        Exit;
    end;

    m_point_valid_ref^ := False;

    hr := m_context.GetActiveView(view);
    if (hr <> S_OK) or (view = nil) then
    begin
        Exit;
    end;

    range := nil;
    if (m_composition_ref <> nil) and (m_composition_ref^ <> nil) then
    begin
        hr := m_composition_ref^.GetRange(range);
        if (hr <> S_OK) or (range = nil) then
        begin
            Exit;
        end;
    end
    else
    begin
        FillChar(selection, SizeOf(selection), 0);
        fetched := 0;
        hr := m_context.GetSelection(ec, 0, 1, selection, fetched);
        if (hr <> S_OK) or (fetched = 0) or (selection.range = nil) then
        begin
            Exit;
        end;
        range := selection.range;
    end;

    range_for_ext := range;
    if (range <> nil) and (range.Clone(range_for_ext) = S_OK) and (range_for_ext <> nil) then
    begin
        range_for_ext.Collapse(ec, TF_ANCHOR_END);
    end;

    hr := view.GetTextExt(ec, range_for_ext, rect, clipped);
    if (hr <> S_OK) and (range_for_ext <> range) then
    begin
        hr := view.GetTextExt(ec, range, rect, clipped);
    end;
    if hr = S_OK then
    begin
        screen_ok := view.GetScreenExt(screen_rect) = S_OK;
        if screen_ok then
        begin
            rect_adjusted := rect;
            OffsetRect(rect_adjusted, screen_rect.Left, screen_rect.Top);
            if (not rect_in_screen(rect, screen_rect)) and rect_in_screen(rect_adjusted, screen_rect) then
            begin
                rect := rect_adjusted;
            end;
        end;
        m_point_ref^ := Point(rect.Left, rect.Bottom);
        m_point_valid_ref^ := True;
        Result := True;
    end;
end;

function TncCaretEditSession.DoEditSession(ec: TfEditCookie): HResult;
begin
    if update_text_ext(ec) then
    begin
        Result := S_OK;
    end
    else
    begin
        Result := E_FAIL;
    end;
end;

constructor TncSurroundingTextEditSession.create(const context: ITfContext; const composition_ref: PITfComposition;
    const max_chars: Integer; const out_text: PString);
begin
    inherited create;
    m_context := context;
    m_composition_ref := composition_ref;
    m_max_chars := max_chars;
    m_out_text := out_text;
end;

function TncSurroundingTextEditSession.read_left_text(const ec: TfEditCookie): Boolean;
var
    caret_range: ITfRange;
    range_left: ITfRange;
    selection: TF_SELECTION;
    fetched: ULONG;
    halt: TF_HALTCOND;
    shifted: Integer;
    buffer: array of WideChar;
    chars_read: LongWord;
    text_value: string;
    hr: HRESULT;
begin
    Result := False;
    if (m_context = nil) or (m_out_text = nil) then
    begin
        Exit;
    end;

    m_out_text^ := '';
    if m_max_chars <= 0 then
    begin
        Result := True;
        Exit;
    end;

    caret_range := nil;
    if (m_composition_ref <> nil) and (m_composition_ref^ <> nil) then
    begin
        hr := m_composition_ref^.GetRange(caret_range);
        if (hr <> S_OK) or (caret_range = nil) then
        begin
            Exit;
        end;
        caret_range.Collapse(ec, TF_ANCHOR_START);
    end
    else
    begin
        FillChar(selection, SizeOf(selection), 0);
        fetched := 0;
        hr := m_context.GetSelection(ec, 0, 1, selection, fetched);
        if (hr <> S_OK) or (fetched = 0) or (selection.range = nil) then
        begin
            Exit;
        end;
        caret_range := selection.range;
        caret_range.Collapse(ec, TF_ANCHOR_START);
    end;

    range_left := nil;
    if (caret_range.Clone(range_left) <> S_OK) or (range_left = nil) then
    begin
        Exit;
    end;

    FillChar(halt, SizeOf(halt), 0);
    shifted := 0;
    range_left.ShiftStart(ec, -m_max_chars, shifted, halt);

    SetLength(buffer, m_max_chars + 1);
    if Length(buffer) = 0 then
    begin
        Result := True;
        Exit;
    end;

    buffer[0] := #0;
    chars_read := 0;
    hr := range_left.GetText(ec, 0, @buffer[0], m_max_chars, chars_read);
    if hr <> S_OK then
    begin
        Exit;
    end;

    if chars_read = 0 then
    begin
        m_out_text^ := '';
        Result := True;
        Exit;
    end;

    SetString(text_value, PWideChar(@buffer[0]), chars_read);
    m_out_text^ := text_value;
    Result := True;
end;

function TncSurroundingTextEditSession.DoEditSession(ec: TfEditCookie): HResult;
begin
    if read_left_text(ec) then
    begin
        Result := S_OK;
    end
    else
    begin
        Result := E_FAIL;
    end;
end;

function TncCommitEditSession.DoEditSession(ec: TfEditCookie): HResult;
var
    insert_at_selection: ITfInsertAtSelection;
    range: ITfRange;
    hr: HRESULT;
    selection: TF_SELECTION;
begin
    if (m_context = nil) or (m_text = '') then
    begin
        Result := E_FAIL;
        Exit;
    end;

    if (m_composition_ref <> nil) and (m_composition_ref^ <> nil) then
    begin
        range := nil;
        hr := m_composition_ref^.GetRange(range);
        if (hr = S_OK) and (range <> nil) then
        begin
            hr := range.SetText(ec, 0, PWideChar(m_text), Length(m_text));
            if hr = S_OK then
            begin
                m_composition_ref^.EndComposition(ec);
                m_composition_ref^ := nil;
                range.Collapse(ec, TF_ANCHOR_END);
                FillChar(selection, SizeOf(selection), 0);
                selection.range := range;
                selection.style.ase := TF_AE_NONE;
                selection.style.fInterimChar := 0;
                m_context.SetSelection(ec, 1, selection);
                Result := S_OK;
                Exit;
            end;
        end;
    end;

    if not Supports(m_context, ITfInsertAtSelection, insert_at_selection) then
    begin
        Result := E_NOINTERFACE;
        Exit;
    end;

    Result := insert_at_selection.InsertTextAtSelection(ec, 0, PWideChar(m_text), Length(m_text), range);
    if (Result = S_OK) and (range <> nil) then
    begin
        range.Collapse(ec, TF_ANCHOR_END);
        FillChar(selection, SizeOf(selection), 0);
        selection.range := range;
        selection.style.ase := TF_AE_NONE;
        selection.style.fInterimChar := 0;
        m_context.SetSelection(ec, 1, selection);
    end;
end;

constructor TncCompositionEditSession.create(const context: ITfContext; const sink: ITfCompositionSink;
    const composition_ref: PITfComposition; const text: string; const point_ref: PPoint;
    const point_valid_ref: PBoolean; const confirmed_length: Integer; const attr_input_atom: TfGuidAtom);
begin
    inherited create;
    m_context := context;
    m_sink := sink;
    m_composition_ref := composition_ref;
    m_text := text;
    m_confirmed_length := confirmed_length;
    m_attr_input_atom := attr_input_atom;
    m_point_ref := point_ref;
    m_point_valid_ref := point_valid_ref;
end;

function TncCompositionEditSession.start_composition(const ec: TfEditCookie): Boolean;
var
    context_composition: ITfContextComposition;
    selection: TF_SELECTION;
    fetched: ULONG;
    hr: HRESULT;
begin
    if m_composition_ref = nil then
    begin
        Result := False;
        Exit;
    end;

    if not Supports(m_context, ITfContextComposition, context_composition) then
    begin
        Result := False;
        Exit;
    end;

    FillChar(selection, SizeOf(selection), 0);
    fetched := 0;
    hr := m_context.GetSelection(ec, 0, 1, selection, fetched);
    if (hr <> S_OK) or (fetched = 0) or (selection.range = nil) then
    begin
        Result := False;
        Exit;
    end;

    hr := context_composition.StartComposition(ec, selection.range, m_sink, m_composition_ref^);
    Result := hr = S_OK;
end;

function TncCompositionEditSession.update_composition_text(const ec: TfEditCookie): Boolean;
var
    range: ITfRange;
    range_selection: ITfRange;
    hr: HRESULT;
    selection: TF_SELECTION;
begin
    if (m_composition_ref = nil) or (m_composition_ref^ = nil) then
    begin
        Result := False;
        Exit;
    end;

    range := nil;
    hr := m_composition_ref^.GetRange(range);
    if (hr <> S_OK) or (range = nil) then
    begin
        Result := False;
        Exit;
    end;

    hr := range.SetText(ec, 0, PWideChar(m_text), Length(m_text));
    if hr = S_OK then
    begin
        apply_display_attributes(ec, range);
        range_selection := nil;
        hr := range.Clone(range_selection);
        if (hr = S_OK) and (range_selection <> nil) then
        begin
            range_selection.Collapse(ec, TF_ANCHOR_END);
            FillChar(selection, SizeOf(selection), 0);
            selection.range := range_selection;
            selection.style.ase := TF_AE_NONE;
            selection.style.fInterimChar := 0;
            m_context.SetSelection(ec, 1, selection);
        end;
        Result := True;
    end
    else
    begin
        Result := False;
    end;
end;

function TncCompositionEditSession.end_composition(const ec: TfEditCookie): Boolean;
var
    hr: HRESULT;
    range: ITfRange;
begin
    if (m_composition_ref = nil) or (m_composition_ref^ = nil) then
    begin
        Result := True;
        Exit;
    end;

    range := nil;
    hr := m_composition_ref^.GetRange(range);
    if (hr = S_OK) and (range <> nil) then
    begin
        range.SetText(ec, 0, PWideChar(''), 0);
    end;

    hr := m_composition_ref^.EndComposition(ec);
    m_composition_ref^ := nil;
    Result := hr = S_OK;
end;

function TncCompositionEditSession.update_text_ext(const ec: TfEditCookie): Boolean;
var
    view: ITfContextView;
    range: ITfRange;
    range_for_ext: ITfRange;
    rect: Winapi.Windows.TRect;
    screen_rect: Winapi.Windows.TRect;
    rect_adjusted: Winapi.Windows.TRect;
    clipped: Integer;
    hr: HRESULT;
    screen_ok: Boolean;

    function rect_in_screen(const candidate: Winapi.Windows.TRect;
        const screen_bounds: Winapi.Windows.TRect): Boolean;
    const
        c_screen_margin = 200;
    begin
        Result := (candidate.Left >= screen_bounds.Left - c_screen_margin) and
            (candidate.Left <= screen_bounds.Right + c_screen_margin) and
            (candidate.Top >= screen_bounds.Top - c_screen_margin) and
            (candidate.Top <= screen_bounds.Bottom + c_screen_margin);
    end;
begin
    Result := False;
    if (m_point_ref = nil) or (m_point_valid_ref = nil) then
    begin
        Exit;
    end;

    m_point_valid_ref^ := False;
    if (m_composition_ref = nil) or (m_composition_ref^ = nil) then
    begin
        Exit;
    end;

    hr := m_context.GetActiveView(view);
    if (hr <> S_OK) or (view = nil) then
    begin
        Exit;
    end;

    range := nil;
    hr := m_composition_ref^.GetRange(range);
    if (hr <> S_OK) or (range = nil) then
    begin
        Exit;
    end;

    range_for_ext := range;
    if (range <> nil) and (range.Clone(range_for_ext) = S_OK) and (range_for_ext <> nil) then
    begin
        range_for_ext.Collapse(ec, TF_ANCHOR_END);
    end;

    hr := view.GetTextExt(ec, range_for_ext, rect, clipped);
    if (hr <> S_OK) and (range_for_ext <> range) then
    begin
        hr := view.GetTextExt(ec, range, rect, clipped);
    end;
    if hr = S_OK then
    begin
        screen_ok := view.GetScreenExt(screen_rect) = S_OK;
        if screen_ok then
        begin
            rect_adjusted := rect;
            OffsetRect(rect_adjusted, screen_rect.Left, screen_rect.Top);
            if (not rect_in_screen(rect, screen_rect)) and rect_in_screen(rect_adjusted, screen_rect) then
            begin
                rect := rect_adjusted;
            end;
        end;
        m_point_ref^ := Point(rect.Left, rect.Bottom);
        m_point_valid_ref^ := True;
        Result := True;
    end;
end;

procedure TncCompositionEditSession.apply_display_attributes(const ec: TfEditCookie; const range: ITfRange);
var
    prop: ITfProperty;
    value: OleVariant;
    guid: TGUID;
begin
    if (m_context = nil) or (range = nil) then
    begin
        Exit;
    end;

    prop := nil;
    guid := c_guid_prop_attribute;
    if (m_attr_input_atom <> TF_INVALID_GUIDATOM) and (m_context.GetProperty(guid, prop) = S_OK) then
    begin
        value := Integer(m_attr_input_atom);
        prop.SetValue(ec, range, value);
    end;

    prop := nil;
    guid := c_guid_prop_composing;
    if m_context.GetProperty(guid, prop) = S_OK then
    begin
        value := 1;
        prop.SetValue(ec, range, value);
    end;
end;

function TncCompositionEditSession.DoEditSession(ec: TfEditCookie): HResult;
begin
    if m_context = nil then
    begin
        Result := E_FAIL;
        Exit;
    end;

    if m_text = '' then
    begin
        if m_point_valid_ref <> nil then
        begin
            m_point_valid_ref^ := False;
        end;

        if end_composition(ec) then
        begin
            Result := S_OK;
        end
        else
        begin
            Result := E_FAIL;
        end;
        Exit;
    end;

    if (m_composition_ref <> nil) and (m_composition_ref^ = nil) then
    begin
        if not start_composition(ec) then
        begin
            Result := E_FAIL;
            Exit;
        end;
    end;

    if update_composition_text(ec) then
    begin
        update_text_ext(ec);
        Result := S_OK;
    end
    else
    begin
        Result := E_FAIL;
    end;
end;

end.
