unit nc_tsf_edit_session;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    Winapi.ActiveX,
    Winapi.Msctf,
    Winapi.MultiMon,
    System.Math,
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
        m_line_height_ref: PInteger;
        function update_text_ext(const ec: TfEditCookie): Boolean;
    public
        constructor create(const context: ITfContext; const composition_ref: PITfComposition; const point_ref: PPoint;
            const point_valid_ref: PBoolean; const line_height_ref: PInteger = nil);
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
        m_line_height_ref: PInteger;
        function start_composition(const ec: TfEditCookie): Boolean;
        function update_composition_text(const ec: TfEditCookie): Boolean;
        function end_composition(const ec: TfEditCookie): Boolean;
        function update_text_ext(const ec: TfEditCookie): Boolean;
        procedure apply_display_attributes(const ec: TfEditCookie; const range: ITfRange);
    public
        constructor create(const context: ITfContext; const sink: ITfCompositionSink;
            const composition_ref: PITfComposition; const text: string; const point_ref: PPoint;
            const point_valid_ref: PBoolean; const line_height_ref: PInteger; const confirmed_length: Integer;
            const attr_input_atom: TfGuidAtom);
        function DoEditSession(ec: TfEditCookie): HResult; stdcall;
    end;

implementation

const
    c_guid_prop_attribute: TGUID = '{34B45670-7526-11D2-A147-00105A2799B5}';
    c_guid_prop_composing: TGUID = '{E12AC060-AF15-11D0-97F0-00C04FD9C1B6}';

type
    TncLogicalToPhysicalPoint = function(hwnd: HWND; var point: TPoint): BOOL; stdcall;
    TncGetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer; out dpiX: UINT;
        out dpiY: UINT): HRESULT; stdcall;
    TDpiAwarenessContext = THandle;
    TncGetWindowDpiAwarenessContext = function(hwnd: HWND): TDpiAwarenessContext; stdcall;
    TncGetAwarenessFromDpiAwarenessContext = function(value: TDpiAwarenessContext): Integer; stdcall;
    TncGetDpiForSystem = function: UINT; stdcall;
    TncGetDpiForWindow = function(hwnd: HWND): UINT; stdcall;

var
    g_logical_to_physical: TncLogicalToPhysicalPoint = nil;
    g_logical_to_physical_ready: Boolean = False;
    g_get_dpi_for_monitor: TncGetDpiForMonitor = nil;
    g_get_dpi_for_monitor_ready: Boolean = False;
    g_get_window_dpi_awareness_context: TncGetWindowDpiAwarenessContext = nil;
    g_get_awareness_from_dpi_awareness_context: TncGetAwarenessFromDpiAwarenessContext = nil;
    g_get_dpi_for_system: TncGetDpiForSystem = nil;
    g_get_dpi_for_window: TncGetDpiForWindow = nil;
    g_dpi_awareness_ready: Boolean = False;

function try_logical_to_physical(const hwnd: HWND; var point: TPoint): Boolean;
var
    module: HMODULE;
begin
    if not g_logical_to_physical_ready then
    begin
        module := GetModuleHandle('user32.dll');
        if module = 0 then
        begin
            module := LoadLibrary('user32.dll');
        end;
        if module <> 0 then
        begin
            g_logical_to_physical := TncLogicalToPhysicalPoint(
                GetProcAddress(module, 'LogicalToPhysicalPointForPerMonitorDPI'));
        end;
        g_logical_to_physical_ready := True;
    end;

    Result := Assigned(g_logical_to_physical) and (hwnd <> 0) and g_logical_to_physical(hwnd, point);
end;

function try_get_dpi_for_monitor(const monitor: HMONITOR; out dpi: Integer): Boolean;
const
    MDT_EFFECTIVE_DPI = 0;
var
    module: HMODULE;
    dpi_x: UINT;
    dpi_y: UINT;
begin
    if not g_get_dpi_for_monitor_ready then
    begin
        module := GetModuleHandle('Shcore.dll');
        if module = 0 then
        begin
            module := LoadLibrary('Shcore.dll');
        end;
        if module <> 0 then
        begin
            g_get_dpi_for_monitor := TncGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
        end;
        g_get_dpi_for_monitor_ready := True;
    end;

    dpi := 0;
    Result := Assigned(g_get_dpi_for_monitor) and (monitor <> 0) and
        (g_get_dpi_for_monitor(monitor, MDT_EFFECTIVE_DPI, dpi_x, dpi_y) = S_OK);
    if Result then
    begin
        dpi := dpi_x;
    end;
end;

function ensure_dpi_awareness_api: Boolean;
var
    module: HMODULE;
begin
    if not g_dpi_awareness_ready then
    begin
        module := GetModuleHandle('user32.dll');
        if module = 0 then
        begin
            module := LoadLibrary('user32.dll');
        end;
        if module <> 0 then
        begin
            g_get_window_dpi_awareness_context := TncGetWindowDpiAwarenessContext(
                GetProcAddress(module, 'GetWindowDpiAwarenessContext'));
            g_get_awareness_from_dpi_awareness_context := TncGetAwarenessFromDpiAwarenessContext(
                GetProcAddress(module, 'GetAwarenessFromDpiAwarenessContext'));
            g_get_dpi_for_system := TncGetDpiForSystem(GetProcAddress(module, 'GetDpiForSystem'));
            g_get_dpi_for_window := TncGetDpiForWindow(GetProcAddress(module, 'GetDpiForWindow'));
        end;
        g_dpi_awareness_ready := True;
    end;

    Result := Assigned(g_get_window_dpi_awareness_context) and Assigned(g_get_awareness_from_dpi_awareness_context);
end;

function try_get_logical_screen_source_dpi(const hwnd: HWND; const monitor_dpi: Integer; out source_dpi: Integer): Boolean;
const
    c_dpi_awareness_system_aware = 1;
var
    awareness: Integer;
    system_dpi: UINT;
    window_dpi: UINT;
begin
    source_dpi := 0;
    if (hwnd = 0) or (monitor_dpi <= 96) then
    begin
        Result := False;
        Exit;
    end;

    if ensure_dpi_awareness_api then
    begin
        awareness := g_get_awareness_from_dpi_awareness_context(g_get_window_dpi_awareness_context(hwnd));
        if awareness <= c_dpi_awareness_system_aware then
        begin
            if Assigned(g_get_dpi_for_system) then
            begin
                system_dpi := g_get_dpi_for_system();
                if system_dpi > 0 then
                begin
                    source_dpi := Integer(system_dpi);
                    Result := Abs(source_dpi - monitor_dpi) >= 12;
                    Exit;
                end;
            end;

            source_dpi := 96;
            Result := Abs(source_dpi - monitor_dpi) >= 12;
            Exit;
        end;
    end;

    if Assigned(g_get_dpi_for_window) then
    begin
        window_dpi := g_get_dpi_for_window(hwnd);
    end
    else
    begin
        window_dpi := 0;
    end;
    if (window_dpi > 0) and (Abs(Integer(window_dpi) - monitor_dpi) >= 12) then
    begin
        source_dpi := Integer(window_dpi);
        Result := True;
        Exit;
    end;

    Result := False;
end;

function try_scale_screen_rect_between_dpi(const source_rect: Winapi.Windows.TRect; const monitor_rect: Winapi.Windows.TRect;
    const source_dpi: Integer; const target_dpi: Integer; out converted_rect: Winapi.Windows.TRect): Boolean;
begin
    converted_rect := source_rect;
    if (source_dpi <= 0) or (target_dpi <= 0) or (source_dpi = target_dpi) then
    begin
        Result := False;
        Exit;
    end;

    converted_rect.Left := monitor_rect.Left + MulDiv(source_rect.Left - monitor_rect.Left, target_dpi, source_dpi);
    converted_rect.Top := monitor_rect.Top + MulDiv(source_rect.Top - monitor_rect.Top, target_dpi, source_dpi);
    converted_rect.Right := monitor_rect.Left + MulDiv(source_rect.Right - monitor_rect.Left, target_dpi, source_dpi);
    converted_rect.Bottom := monitor_rect.Top + MulDiv(source_rect.Bottom - monitor_rect.Top, target_dpi, source_dpi);
    Result := True;
end;

function try_convert_screen_rect_for_monitor_dpi(const hwnd: HWND; const source_rect: Winapi.Windows.TRect;
    out converted_rect: Winapi.Windows.TRect): Boolean;
var
    monitor: HMONITOR;
    monitor_info: MONITORINFO;
    monitor_dpi: Integer;
    source_dpi: Integer;
    anchor: TPoint;
begin
    converted_rect := source_rect;
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    anchor := Point(source_rect.Right, source_rect.Bottom);
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor = 0 then
    begin
        Result := False;
        Exit;
    end;

    monitor_info.cbSize := SizeOf(monitor_info);
    if not GetMonitorInfo(monitor, @monitor_info) then
    begin
        Result := False;
        Exit;
    end;

    if not try_get_dpi_for_monitor(monitor, monitor_dpi) then
    begin
        Result := False;
        Exit;
    end;

    if not try_get_logical_screen_source_dpi(hwnd, monitor_dpi, source_dpi) then
    begin
        Result := False;
        Exit;
    end;

    Result := try_scale_screen_rect_between_dpi(source_rect, monitor_info.rcMonitor, source_dpi, monitor_dpi,
        converted_rect);
end;

function try_client_point_to_screen(const hwnd: HWND; var point: TPoint): Boolean;
begin
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    Result := ClientToScreen(hwnd, point);
end;

function try_client_rect_to_screen(const hwnd: HWND; var rect: Winapi.Windows.TRect): Boolean;
var
    top_left: TPoint;
    bottom_right: TPoint;
begin
    top_left := Point(rect.Left, rect.Top);
    bottom_right := Point(rect.Right, rect.Bottom);
    if not try_client_point_to_screen(hwnd, top_left) then
    begin
        Result := False;
        Exit;
    end;
    if not try_client_point_to_screen(hwnd, bottom_right) then
    begin
        Result := False;
        Exit;
    end;

    rect := System.Types.Rect(top_left.X, top_left.Y, bottom_right.X, bottom_right.Y);
    Result := True;
end;

function try_client_point_to_screen_physical(const hwnd: HWND; var point: TPoint): Boolean;
begin
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    Result := ClientToScreen(hwnd, point);
    if Result then
    begin
        try_logical_to_physical(hwnd, point);
    end;
end;

function try_client_rect_to_screen_physical(const hwnd: HWND; var rect: Winapi.Windows.TRect): Boolean;
var
    top_left: TPoint;
    bottom_right: TPoint;
begin
    top_left := Point(rect.Left, rect.Top);
    bottom_right := Point(rect.Right, rect.Bottom);
    if not try_client_point_to_screen_physical(hwnd, top_left) then
    begin
        Result := False;
        Exit;
    end;
    if not try_client_point_to_screen_physical(hwnd, bottom_right) then
    begin
        Result := False;
        Exit;
    end;

    rect := System.Types.Rect(top_left.X, top_left.Y, bottom_right.X, bottom_right.Y);
    Result := True;
end;

function try_screen_rect_to_physical(const hwnd: HWND; const source_rect: Winapi.Windows.TRect;
    out converted_rect: Winapi.Windows.TRect): Boolean;
var
    top_left: TPoint;
    bottom_right: TPoint;
begin
    converted_rect := source_rect;
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    top_left := Point(source_rect.Left, source_rect.Top);
    bottom_right := Point(source_rect.Right, source_rect.Bottom);
    if not try_logical_to_physical(hwnd, top_left) then
    begin
        Result := False;
        Exit;
    end;
    if not try_logical_to_physical(hwnd, bottom_right) then
    begin
        Result := False;
        Exit;
    end;

    converted_rect := System.Types.Rect(top_left.X, top_left.Y, bottom_right.X, bottom_right.Y);
    Result := True;
end;

function choose_text_ext_anchor_point(const source_rect: Winapi.Windows.TRect; const line_height: Integer): TPoint;
var
    rect_width: Integer;
    anchor_x: Integer;
    width_threshold: Integer;
begin
    rect_width := source_rect.Right - source_rect.Left;
    if rect_width < 0 then
    begin
        rect_width := 0;
    end;

    width_threshold := Max(24, line_height * 3);
    if rect_width <= width_threshold then
    begin
        anchor_x := source_rect.Left;
    end
    else
    begin
        anchor_x := source_rect.Right;
    end;

    Result := Point(anchor_x, source_rect.Bottom);
end;

function get_window_class_name(const window_handle: Winapi.Windows.HWND): string;
var
    class_buffer: array[0..255] of Char;
    class_len: Integer;
begin
    Result := '';
    if window_handle = 0 then
    begin
        Exit;
    end;

    class_len := GetClassName(window_handle, class_buffer, Length(class_buffer));
    if class_len > 0 then
    begin
        SetString(Result, class_buffer, class_len);
    end;
end;

procedure clear_composing_property(const context: ITfContext; const ec: TfEditCookie; const range: ITfRange);
var
    prop: ITfProperty;
    guid: TGUID;
begin
    if (context = nil) or (range = nil) then
    begin
        Exit;
    end;

    prop := nil;
    guid := c_guid_prop_composing;
    if context.GetProperty(guid, prop) = S_OK then
    begin
        prop.Clear(ec, range);
    end;
end;

function is_terminal_like_class(const class_name: string): Boolean;
var
    class_lower: string;
begin
    if class_name = '' then
    begin
        Result := False;
        Exit;
    end;

    class_lower := LowerCase(class_name);
    Result := (Pos('consolewindowclass', class_lower) > 0) or
        (Pos('cascadia_hosting_window_class', class_lower) > 0) or
        (Pos('terminal', class_lower) > 0) or
        (Pos('pseudoconsole', class_lower) > 0);
end;

function is_terminal_like_view(const view: ITfContextView): Boolean;
var
    view_hwnd: Winapi.Windows.HWND;
begin
    Result := False;
    view_hwnd := 0;
    if (view = nil) or (view.GetWnd(view_hwnd) <> S_OK) or (view_hwnd = 0) then
    begin
        Exit;
    end;

    Result := is_terminal_like_class(get_window_class_name(view_hwnd));
end;

constructor TncCommitEditSession.create(const context: ITfContext; const composition_ref: PITfComposition;
    const text: string);
begin
    inherited create;
    m_context := context;
    m_composition_ref := composition_ref;
    m_text := text;
end;

constructor TncCaretEditSession.create(const context: ITfContext; const composition_ref: PITfComposition; const point_ref: PPoint;
    const point_valid_ref: PBoolean; const line_height_ref: PInteger);
begin
    inherited create;
    m_context := context;
    m_composition_ref := composition_ref;
    m_point_ref := point_ref;
    m_point_valid_ref := point_valid_ref;
    m_line_height_ref := line_height_ref;
end;

function TncCaretEditSession.update_text_ext(const ec: TfEditCookie): Boolean;
var
    view: ITfContextView;
    range: ITfRange;
    selection: TF_SELECTION;
    fetched: ULONG;
    hr: HRESULT;
    best_rect: Winapi.Windows.TRect;
    candidate_rect: Winapi.Windows.TRect;
    best_line_height: Integer;
    candidate_line_height: Integer;
    best_score: Integer;
    candidate_score: Integer;
    best_found: Boolean;
    collapsed_rect: Winapi.Windows.TRect;
    collapsed_line_height: Integer;
    collapsed_found: Boolean;
    full_rect: Winapi.Windows.TRect;
    full_line_height: Integer;
    full_found: Boolean;

    function rect_in_screen(const candidate: Winapi.Windows.TRect;
        const screen_bounds: Winapi.Windows.TRect): Boolean;
    const
        // Keep tolerance small so client-relative (0,0)-like coordinates
        // can still be recognized and converted to screen coordinates.
        c_screen_margin = 16;
    begin
        Result := (candidate.Left >= screen_bounds.Left - c_screen_margin) and
            (candidate.Left <= screen_bounds.Right + c_screen_margin) and
            (candidate.Top >= screen_bounds.Top - c_screen_margin) and
            (candidate.Top <= screen_bounds.Bottom + c_screen_margin);
    end;

    function rect_fully_in_screen(const candidate: Winapi.Windows.TRect;
        const screen_bounds: Winapi.Windows.TRect): Boolean;
    const
        c_screen_margin = 16;
    begin
        Result := (candidate.Left >= screen_bounds.Left - c_screen_margin) and
            (candidate.Top >= screen_bounds.Top - c_screen_margin) and
            (candidate.Right <= screen_bounds.Right + c_screen_margin) and
            (candidate.Bottom <= screen_bounds.Bottom + c_screen_margin);
    end;

    function rect_looks_like_client_origin(const candidate: Winapi.Windows.TRect): Boolean;
    var
        width: Integer;
        height: Integer;
    begin
        width := candidate.Right - candidate.Left;
        if width < 0 then
        begin
            width := 0;
        end;
        height := candidate.Bottom - candidate.Top;
        if height < 0 then
        begin
            height := 0;
        end;

        Result := (candidate.Left >= -32) and (candidate.Left <= 48) and
            (candidate.Top >= -32) and (candidate.Top <= 48) and
            (width <= Max(16, height * 3));
    end;

    function try_convert_with_view_hwnd(const source_rect: Winapi.Windows.TRect;
        const use_physical: Boolean; out converted_rect: Winapi.Windows.TRect): Boolean;
    var
        view_hwnd: Winapi.Windows.HWND;
        client_rect: Winapi.Windows.TRect;
        client_like: Boolean;
    begin
        Result := False;
        converted_rect := source_rect;
        view_hwnd := 0;
        if (view = nil) or (view.GetWnd(view_hwnd) <> S_OK) or (view_hwnd = 0) then
        begin
            Exit;
        end;

        if not GetClientRect(view_hwnd, client_rect) then
        begin
            Exit;
        end;

        client_like := (source_rect.Left >= client_rect.Left - 32) and
            (source_rect.Left <= client_rect.Right + 32) and
            (source_rect.Top >= client_rect.Top - 32) and
            (source_rect.Top <= client_rect.Bottom + 32) and
            (source_rect.Right >= client_rect.Left - 32) and
            (source_rect.Right <= client_rect.Right + 32) and
            (source_rect.Bottom >= client_rect.Top - 32) and
            (source_rect.Bottom <= client_rect.Bottom + 32);
        if not client_like then
        begin
            Exit;
        end;

        if use_physical then
        begin
            Result := try_client_rect_to_screen_physical(view_hwnd, converted_rect);
        end
        else
        begin
            Result := try_client_rect_to_screen(view_hwnd, converted_rect);
        end;
    end;

    function score_text_ext_rect(const candidate: Winapi.Windows.TRect; const screen_bounds: Winapi.Windows.TRect;
        const has_screen_bounds: Boolean; const prefer_end_anchor: Boolean): Integer;
    var
        width: Integer;
        height: Integer;
        anchor: TPoint;
    begin
        width := candidate.Right - candidate.Left;
        if width < 0 then
        begin
            width := 0;
        end;
        height := candidate.Bottom - candidate.Top;
        if height < 0 then
        begin
            height := 0;
        end;

        anchor := Point(candidate.Right, candidate.Bottom);
        Result := 0;
        if has_screen_bounds then
        begin
            if rect_in_screen(candidate, screen_bounds) then
            begin
                Inc(Result, 80);
            end;

            // Many broken TSF implementations report a zero-width rect
            // parked at the view origin instead of the live caret.
            if (Abs(candidate.Left - screen_bounds.Left) <= 4) and (width <= Max(4, height * 2)) then
            begin
                Dec(Result, 90);
            end;
            if Abs(anchor.Y - screen_bounds.Top) <= Max(8, height + 4) then
            begin
                Dec(Result, 60);
            end;
            if anchor.Y > screen_bounds.Top + Max(24, height * 2) then
            begin
                Inc(Result, 20);
            end;
            if anchor.X > screen_bounds.Left + Max(24, height) then
            begin
                Inc(Result, 10);
            end;
        end
        else if (anchor.X <> 0) or (anchor.Y <> 0) then
        begin
            Inc(Result, 20);
        end;

        if width = 0 then
        begin
            Inc(Result, 25);
        end
        else if width <= Max(16, height * 3) then
        begin
            Inc(Result, 15);
        end
        else if width > Max(48, height * 6) then
        begin
            Dec(Result, 30);
        end;

        if height > 0 then
        begin
            Inc(Result, Min(height, 32));
        end;

        if prefer_end_anchor then
        begin
            Inc(Result, 10);
        end;
    end;

    function rect_looks_like_range_start(const primary_rect: Winapi.Windows.TRect;
        const alternate_rect: Winapi.Windows.TRect; const line_height: Integer): Boolean;
    var
        horizontal_gap: Integer;
        vertical_tolerance: Integer;
    begin
        horizontal_gap := Max(24, line_height * 2);
        vertical_tolerance := Max(12, line_height);
        Result := (alternate_rect.Right >= primary_rect.Right + horizontal_gap) and
            (Abs(alternate_rect.Bottom - primary_rect.Bottom) <= vertical_tolerance) and
            (alternate_rect.Left <= primary_rect.Left + Max(16, line_height));
    end;

    function rect_has_weak_tail(const candidate_rect: Winapi.Windows.TRect; const line_height: Integer): Boolean;
    var
        rect_width: Integer;
    begin
        rect_width := candidate_rect.Right - candidate_rect.Left;
        if rect_width < 0 then
        begin
            rect_width := 0;
        end;
        Result := rect_width <= Max(8, line_height);
    end;

    function try_estimate_tail_rect_from_text(const start_rect: Winapi.Windows.TRect;
        const line_height: Integer; out estimated_rect: Winapi.Windows.TRect): Boolean;
    var
        view_hwnd: Winapi.Windows.HWND;
        dc_hwnd: Winapi.Windows.HWND;
        window_dc: Winapi.Windows.HDC;
        font_handle: Winapi.Windows.HFONT;
        previous_font: Winapi.Windows.HGDIOBJ;
        text_extent: Winapi.Windows.TSize;
        display_text: string;
        fallback_char_width: Integer;
        fallback_width: Integer;
    begin
        Result := False;
        estimated_rect := start_rect;
        if m_composition_ref = nil then
        begin
            Exit;
        end;
        if (m_composition_ref^ = nil) then
        begin
            Exit;
        end;

        display_text := '';
        if range <> nil then
        begin
            SetLength(display_text, 64);
            if range.GetText(ec, 0, PWideChar(display_text), Length(display_text), ULONG(fallback_width)) = S_OK then
            begin
                SetLength(display_text, fallback_width);
            end
            else
            begin
                display_text := '';
            end;
        end;
        if display_text = '' then
        begin
            Exit;
        end;

        view_hwnd := 0;
        if view <> nil then
        begin
            view.GetWnd(view_hwnd);
        end;

        window_dc := 0;
        dc_hwnd := 0;
        if view_hwnd <> 0 then
        begin
            window_dc := GetDC(view_hwnd);
            dc_hwnd := view_hwnd;
        end;
        if window_dc = 0 then
        begin
            window_dc := GetDC(0);
            dc_hwnd := 0;
        end;
        if window_dc = 0 then
        begin
            Exit;
        end;
        try
            font_handle := 0;
            if view_hwnd <> 0 then
            begin
                font_handle := Winapi.Windows.HFONT(SendMessage(view_hwnd, WM_GETFONT, 0, 0));
            end;
            if font_handle = 0 then
            begin
                font_handle := Winapi.Windows.HFONT(GetStockObject(DEFAULT_GUI_FONT));
            end;
            previous_font := 0;
            if font_handle <> 0 then
            begin
                previous_font := SelectObject(window_dc, font_handle);
            end;
            try
                FillChar(text_extent, SizeOf(text_extent), 0);
                GetTextExtentPoint32W(window_dc, PWideChar(display_text), Length(display_text), text_extent);
            finally
                if previous_font <> 0 then
                begin
                    SelectObject(window_dc, previous_font);
                end;
            end;
        finally
            ReleaseDC(dc_hwnd, window_dc);
        end;

        fallback_char_width := Max(8, Max(line_height, start_rect.Bottom - start_rect.Top));
        fallback_width := Length(display_text) * fallback_char_width;
        if fallback_width > 0 then
        begin
            if text_extent.cx < fallback_width then
            begin
                text_extent.cx := fallback_width;
            end;
        end;
        if text_extent.cx <= 0 then
        begin
            Exit;
        end;

        estimated_rect.Right := Max(start_rect.Right, start_rect.Left + text_extent.cx);
        if line_height > 0 then
        begin
            estimated_rect.Bottom := estimated_rect.Top + line_height;
        end;
        Result := estimated_rect.Right > start_rect.Right;
    end;

    procedure try_promote_estimated_tail(const base_rect: Winapi.Windows.TRect; const base_line_height: Integer);
    begin
        if not try_estimate_tail_rect_from_text(base_rect, base_line_height, candidate_rect) then
        begin
            Exit;
        end;

        if (not best_found) or rect_has_weak_tail(best_rect, best_line_height) or
            rect_looks_like_range_start(best_rect, candidate_rect, Max(best_line_height, base_line_height)) or
            (candidate_rect.Right > best_rect.Right + Max(16, base_line_height)) then
        begin
            best_rect := candidate_rect;
            if best_line_height = 0 then
            begin
                best_line_height := base_line_height;
            end
            else
            begin
                best_line_height := Max(best_line_height, base_line_height);
            end;
            best_found := True;
        end;
    end;

    function try_get_range_rect(const source_range: ITfRange; const collapse_to_end: Boolean;
        out out_rect: Winapi.Windows.TRect; out out_line_height: Integer; out out_score: Integer): Boolean;
    var
        query_range: ITfRange;
        local_rect: Winapi.Windows.TRect;
        local_screen_rect: Winapi.Windows.TRect;
        raw_rect: Winapi.Windows.TRect;
        local_rect_adjusted: Winapi.Windows.TRect;
        best_candidate_rect: Winapi.Windows.TRect;
        local_clipped: Integer;
        local_hr: HRESULT;
        local_screen_ok: Boolean;
        best_candidate_score: Integer;
        candidate_candidate_score: Integer;
        raw_looks_like_client_origin: Boolean;
        raw_already_screen_like: Boolean;
        view_hwnd: Winapi.Windows.HWND;
    begin
        Result := False;
        out_rect := System.Types.Rect(0, 0, 0, 0);
        out_line_height := 0;
        out_score := Low(Integer);
        if source_range = nil then
        begin
            Exit;
        end;

        query_range := source_range;
        if collapse_to_end then
        begin
            query_range := nil;
            if (source_range.Clone(query_range) <> S_OK) or (query_range = nil) then
            begin
                Exit;
            end;
            query_range.Collapse(ec, TF_ANCHOR_END);
        end;

        local_hr := view.GetTextExt(ec, query_range, local_rect, local_clipped);
        if local_hr <> S_OK then
        begin
            Exit;
        end;

        local_screen_ok := view.GetScreenExt(local_screen_rect) = S_OK;
        raw_rect := local_rect;
        best_candidate_rect := raw_rect;
        best_candidate_score := score_text_ext_rect(raw_rect, local_screen_rect, local_screen_ok, collapse_to_end);
        raw_looks_like_client_origin := rect_looks_like_client_origin(raw_rect);
        raw_already_screen_like := local_screen_ok and rect_in_screen(raw_rect, local_screen_rect) and
            (not raw_looks_like_client_origin);
        view_hwnd := 0;
        if view <> nil then
        begin
            view.GetWnd(view_hwnd);
        end;

        if local_screen_ok and raw_looks_like_client_origin then
        begin
            local_rect_adjusted := raw_rect;
            OffsetRect(local_rect_adjusted, local_screen_rect.Left, local_screen_rect.Top);
            candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                collapse_to_end);
            if candidate_candidate_score > best_candidate_score then
            begin
                best_candidate_rect := local_rect_adjusted;
                best_candidate_score := candidate_candidate_score;
            end;
        end;

        if raw_already_screen_like and try_convert_screen_rect_for_monitor_dpi(view_hwnd, raw_rect, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    collapse_to_end);
                Inc(candidate_candidate_score, 60);
                best_candidate_rect := local_rect_adjusted;
                best_candidate_score := candidate_candidate_score;
            end;
        end;

        if raw_already_screen_like and try_screen_rect_to_physical(view_hwnd, raw_rect, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    collapse_to_end);
                Inc(candidate_candidate_score, 90);
                best_candidate_rect := local_rect_adjusted;
                best_candidate_score := candidate_candidate_score;
            end;
        end;

        if (not raw_already_screen_like) and try_convert_with_view_hwnd(raw_rect, False, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    collapse_to_end);
                if candidate_candidate_score > best_candidate_score then
                begin
                    best_candidate_rect := local_rect_adjusted;
                    best_candidate_score := candidate_candidate_score;
                end;
            end;
        end;

        if (not raw_already_screen_like) and try_convert_with_view_hwnd(raw_rect, True, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    collapse_to_end);
                if candidate_candidate_score > best_candidate_score then
                begin
                    best_candidate_rect := local_rect_adjusted;
                    best_candidate_score := candidate_candidate_score;
                end;
            end;
        end;

        local_rect := best_candidate_rect;

        out_rect := local_rect;
        out_line_height := out_rect.Bottom - out_rect.Top;
        if out_line_height < 0 then
        begin
            out_line_height := 0;
        end;
        out_score := best_candidate_score;
        Result := True;
    end;
begin
    Result := False;
    if (m_context = nil) or (m_point_ref = nil) or (m_point_valid_ref = nil) then
    begin
        Exit;
    end;

    m_point_valid_ref^ := False;
    if m_line_height_ref <> nil then
    begin
        m_line_height_ref^ := 0;
    end;

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

    best_found := False;
    best_score := Low(Integer);
    best_line_height := 0;
    collapsed_found := False;
    full_found := False;
    collapsed_line_height := 0;
    full_line_height := 0;

    if try_get_range_rect(range, True, candidate_rect, candidate_line_height, candidate_score) then
    begin
        collapsed_rect := candidate_rect;
        collapsed_line_height := candidate_line_height;
        collapsed_found := True;
        best_rect := candidate_rect;
        best_line_height := candidate_line_height;
        best_score := candidate_score;
        best_found := True;
    end;

    if ((m_composition_ref <> nil) and (m_composition_ref^ <> nil)) and
        try_get_range_rect(range, False, candidate_rect, candidate_line_height, candidate_score) then
    begin
        full_rect := candidate_rect;
        full_line_height := candidate_line_height;
        full_found := True;
        if (not best_found) or (candidate_score > best_score) then
        begin
            best_rect := candidate_rect;
            best_line_height := candidate_line_height;
            best_found := True;
        end;
    end;

    if collapsed_found and best_found and EqualRect(best_rect, collapsed_rect) then
    begin
        if full_found and rect_looks_like_range_start(collapsed_rect, full_rect, collapsed_line_height) then
        begin
            best_rect := full_rect;
            best_line_height := full_line_height;
        end;
    end;

    if collapsed_found and best_found then
    begin
        try_promote_estimated_tail(collapsed_rect, collapsed_line_height);
    end
    else if full_found then
    begin
        try_promote_estimated_tail(full_rect, full_line_height);
    end;

    if best_found then
    begin
        m_point_ref^ := choose_text_ext_anchor_point(best_rect, best_line_height);
        if m_line_height_ref <> nil then
        begin
            m_line_height_ref^ := best_line_height;
        end;
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
            clear_composing_property(m_context, ec, range);
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
    const point_valid_ref: PBoolean; const line_height_ref: PInteger; const confirmed_length: Integer;
    const attr_input_atom: TfGuidAtom);
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
    m_line_height_ref := line_height_ref;
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
        clear_composing_property(m_context, ec, range);
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
    hr: HRESULT;
    best_rect: Winapi.Windows.TRect;
    candidate_rect: Winapi.Windows.TRect;
    best_line_height: Integer;
    candidate_line_height: Integer;
    best_score: Integer;
    candidate_score: Integer;
    best_found: Boolean;
    collapsed_rect: Winapi.Windows.TRect;
    collapsed_line_height: Integer;
    collapsed_found: Boolean;
    tail_rect: Winapi.Windows.TRect;
    tail_line_height: Integer;
    tail_found: Boolean;
    full_rect: Winapi.Windows.TRect;
    full_line_height: Integer;
    full_found: Boolean;
const
    c_query_collapsed_end = 0;
    c_query_full_range = 1;
    c_query_tail_char = 2;

    function rect_in_screen(const candidate: Winapi.Windows.TRect;
        const screen_bounds: Winapi.Windows.TRect): Boolean;
    const
        // Keep tolerance small so client-relative (0,0)-like coordinates
        // can still be recognized and converted to screen coordinates.
        c_screen_margin = 16;
    begin
        Result := (candidate.Left >= screen_bounds.Left - c_screen_margin) and
            (candidate.Left <= screen_bounds.Right + c_screen_margin) and
            (candidate.Top >= screen_bounds.Top - c_screen_margin) and
            (candidate.Top <= screen_bounds.Bottom + c_screen_margin);
    end;

    function rect_fully_in_screen(const candidate: Winapi.Windows.TRect;
        const screen_bounds: Winapi.Windows.TRect): Boolean;
    const
        c_screen_margin = 16;
    begin
        Result := (candidate.Left >= screen_bounds.Left - c_screen_margin) and
            (candidate.Top >= screen_bounds.Top - c_screen_margin) and
            (candidate.Right <= screen_bounds.Right + c_screen_margin) and
            (candidate.Bottom <= screen_bounds.Bottom + c_screen_margin);
    end;

    function rect_looks_like_client_origin(const candidate: Winapi.Windows.TRect): Boolean;
    var
        width: Integer;
        height: Integer;
    begin
        width := candidate.Right - candidate.Left;
        if width < 0 then
        begin
            width := 0;
        end;
        height := candidate.Bottom - candidate.Top;
        if height < 0 then
        begin
            height := 0;
        end;

        Result := (candidate.Left >= -32) and (candidate.Left <= 48) and
            (candidate.Top >= -32) and (candidate.Top <= 48) and
            (width <= Max(16, height * 3));
    end;

    function try_convert_with_view_hwnd(const source_rect: Winapi.Windows.TRect;
        const use_physical: Boolean; out converted_rect: Winapi.Windows.TRect): Boolean;
    var
        view_hwnd: Winapi.Windows.HWND;
        client_rect: Winapi.Windows.TRect;
        client_like: Boolean;
    begin
        Result := False;
        converted_rect := source_rect;
        view_hwnd := 0;
        if (view = nil) or (view.GetWnd(view_hwnd) <> S_OK) or (view_hwnd = 0) then
        begin
            Exit;
        end;

        if not GetClientRect(view_hwnd, client_rect) then
        begin
            Exit;
        end;

        client_like := (source_rect.Left >= client_rect.Left - 32) and
            (source_rect.Left <= client_rect.Right + 32) and
            (source_rect.Top >= client_rect.Top - 32) and
            (source_rect.Top <= client_rect.Bottom + 32) and
            (source_rect.Right >= client_rect.Left - 32) and
            (source_rect.Right <= client_rect.Right + 32) and
            (source_rect.Bottom >= client_rect.Top - 32) and
            (source_rect.Bottom <= client_rect.Bottom + 32);
        if not client_like then
        begin
            Exit;
        end;

        if use_physical then
        begin
            Result := try_client_rect_to_screen_physical(view_hwnd, converted_rect);
        end
        else
        begin
            Result := try_client_rect_to_screen(view_hwnd, converted_rect);
        end;
    end;

    function score_text_ext_rect(const candidate: Winapi.Windows.TRect; const screen_bounds: Winapi.Windows.TRect;
        const has_screen_bounds: Boolean; const prefer_end_anchor: Boolean): Integer;
    var
        width: Integer;
        height: Integer;
        anchor: TPoint;
    begin
        width := candidate.Right - candidate.Left;
        if width < 0 then
        begin
            width := 0;
        end;
        height := candidate.Bottom - candidate.Top;
        if height < 0 then
        begin
            height := 0;
        end;

        anchor := Point(candidate.Right, candidate.Bottom);
        Result := 0;
        if has_screen_bounds then
        begin
            if rect_in_screen(candidate, screen_bounds) then
            begin
                Inc(Result, 80);
            end;

            if (Abs(candidate.Left - screen_bounds.Left) <= 4) and (width <= Max(4, height * 2)) then
            begin
                Dec(Result, 90);
            end;
            if Abs(anchor.Y - screen_bounds.Top) <= Max(8, height + 4) then
            begin
                Dec(Result, 60);
            end;
            if anchor.Y > screen_bounds.Top + Max(24, height * 2) then
            begin
                Inc(Result, 20);
            end;
            if anchor.X > screen_bounds.Left + Max(24, height) then
            begin
                Inc(Result, 10);
            end;
        end
        else if (anchor.X <> 0) or (anchor.Y <> 0) then
        begin
            Inc(Result, 20);
        end;

        if width = 0 then
        begin
            Inc(Result, 25);
        end
        else if width <= Max(16, height * 3) then
        begin
            Inc(Result, 15);
        end
        else if width > Max(48, height * 6) then
        begin
            Dec(Result, 30);
        end;

        if height > 0 then
        begin
            Inc(Result, Min(height, 32));
        end;

        if prefer_end_anchor then
        begin
            Inc(Result, 10);
        end;
    end;

    function rect_looks_like_range_start(const primary_rect: Winapi.Windows.TRect;
        const alternate_rect: Winapi.Windows.TRect; const line_height: Integer): Boolean;
    var
        horizontal_gap: Integer;
        vertical_tolerance: Integer;
    begin
        horizontal_gap := Max(24, line_height * 2);
        vertical_tolerance := Max(12, line_height);
        Result := (alternate_rect.Right >= primary_rect.Right + horizontal_gap) and
            (Abs(alternate_rect.Bottom - primary_rect.Bottom) <= vertical_tolerance) and
            (alternate_rect.Left <= primary_rect.Left + Max(16, line_height));
    end;

    function rect_has_weak_tail(const candidate_rect: Winapi.Windows.TRect; const line_height: Integer): Boolean;
    var
        rect_width: Integer;
    begin
        rect_width := candidate_rect.Right - candidate_rect.Left;
        if rect_width < 0 then
        begin
            rect_width := 0;
        end;
        Result := rect_width <= Max(8, line_height);
    end;

    function try_estimate_tail_rect_from_text(const start_rect: Winapi.Windows.TRect;
        const line_height: Integer; out estimated_rect: Winapi.Windows.TRect): Boolean;
    var
        view_hwnd: Winapi.Windows.HWND;
        dc_hwnd: Winapi.Windows.HWND;
        window_dc: Winapi.Windows.HDC;
        font_handle: Winapi.Windows.HFONT;
        previous_font: Winapi.Windows.HGDIOBJ;
        text_extent: Winapi.Windows.TSize;
        display_text: string;
        fallback_char_width: Integer;
        fallback_width: Integer;
    begin
        Result := False;
        estimated_rect := start_rect;
        if m_text = '' then
        begin
            Exit;
        end;

        display_text := m_text;
        if (m_confirmed_length > 0) and (m_confirmed_length < Length(display_text)) then
        begin
            display_text := Copy(display_text, m_confirmed_length + 1, MaxInt);
        end;
        if display_text = '' then
        begin
            Exit;
        end;

        view_hwnd := 0;
        if view <> nil then
        begin
            view.GetWnd(view_hwnd);
        end;

        window_dc := 0;
        dc_hwnd := 0;
        if view_hwnd <> 0 then
        begin
            window_dc := GetDC(view_hwnd);
            dc_hwnd := view_hwnd;
        end;
        if window_dc = 0 then
        begin
            window_dc := GetDC(0);
            dc_hwnd := 0;
        end;
        if window_dc = 0 then
        begin
            Exit;
        end;
        try
            font_handle := 0;
            if view_hwnd <> 0 then
            begin
                font_handle := Winapi.Windows.HFONT(SendMessage(view_hwnd, WM_GETFONT, 0, 0));
            end;
            if font_handle = 0 then
            begin
                font_handle := Winapi.Windows.HFONT(GetStockObject(DEFAULT_GUI_FONT));
            end;
            previous_font := 0;
            if font_handle <> 0 then
            begin
                previous_font := SelectObject(window_dc, font_handle);
            end;
            try
                FillChar(text_extent, SizeOf(text_extent), 0);
                GetTextExtentPoint32W(window_dc, PWideChar(display_text), Length(display_text), text_extent);
            finally
                if previous_font <> 0 then
                begin
                    SelectObject(window_dc, previous_font);
                end;
            end;
        finally
            ReleaseDC(dc_hwnd, window_dc);
        end;

        fallback_char_width := Max(8, Max(line_height, start_rect.Bottom - start_rect.Top));
        fallback_width := Length(display_text) * fallback_char_width;
        if fallback_width > 0 then
        begin
            if text_extent.cx < fallback_width then
            begin
                text_extent.cx := fallback_width;
            end;
        end;

        if text_extent.cx <= 0 then
        begin
            Exit;
        end;

        estimated_rect.Right := Max(start_rect.Right, start_rect.Left + text_extent.cx);
        if line_height > 0 then
        begin
            estimated_rect.Bottom := estimated_rect.Top + line_height;
        end;
        Result := estimated_rect.Right > start_rect.Right;
    end;

    procedure try_promote_estimated_tail(const base_rect: Winapi.Windows.TRect; const base_line_height: Integer);
    begin
        if not try_estimate_tail_rect_from_text(base_rect, base_line_height, candidate_rect) then
        begin
            Exit;
        end;

        if (not best_found) or rect_has_weak_tail(best_rect, best_line_height) or
            rect_looks_like_range_start(best_rect, candidate_rect, Max(best_line_height, base_line_height)) or
            (candidate_rect.Right > best_rect.Right + Max(16, base_line_height)) then
        begin
            best_rect := candidate_rect;
            if best_line_height = 0 then
            begin
                best_line_height := base_line_height;
            end
            else
            begin
                best_line_height := Max(best_line_height, base_line_height);
            end;
            best_found := True;
        end;
    end;

    function try_get_range_rect(const source_range: ITfRange; const query_mode: Integer;
        out out_rect: Winapi.Windows.TRect; out out_line_height: Integer; out out_score: Integer): Boolean;
    var
        query_range: ITfRange;
        local_rect: Winapi.Windows.TRect;
        local_screen_rect: Winapi.Windows.TRect;
        raw_rect: Winapi.Windows.TRect;
        local_rect_adjusted: Winapi.Windows.TRect;
        best_candidate_rect: Winapi.Windows.TRect;
        local_clipped: Integer;
        local_hr: HRESULT;
        local_screen_ok: Boolean;
        local_halt: TF_HALTCOND;
        local_shifted: Integer;
        prefer_end_anchor: Boolean;
        best_candidate_score: Integer;
        candidate_candidate_score: Integer;
        raw_looks_like_client_origin: Boolean;
        raw_already_screen_like: Boolean;
        view_hwnd: Winapi.Windows.HWND;
    begin
        Result := False;
        out_rect := System.Types.Rect(0, 0, 0, 0);
        out_line_height := 0;
        out_score := Low(Integer);
        if source_range = nil then
        begin
            Exit;
        end;

        query_range := source_range;
        prefer_end_anchor := query_mode <> c_query_full_range;
        if query_mode <> c_query_full_range then
        begin
            query_range := nil;
            if (source_range.Clone(query_range) <> S_OK) or (query_range = nil) then
            begin
                Exit;
            end;
            query_range.Collapse(ec, TF_ANCHOR_END);
            if query_mode = c_query_tail_char then
            begin
                FillChar(local_halt, SizeOf(local_halt), 0);
                local_shifted := 0;
                query_range.ShiftStart(ec, -1, local_shifted, local_halt);
                if local_shifted = 0 then
                begin
                    Exit;
                end;
            end;
        end;

        local_hr := view.GetTextExt(ec, query_range, local_rect, local_clipped);
        if local_hr <> S_OK then
        begin
            Exit;
        end;

        local_screen_ok := view.GetScreenExt(local_screen_rect) = S_OK;
        raw_rect := local_rect;
        best_candidate_rect := raw_rect;
        best_candidate_score := score_text_ext_rect(raw_rect, local_screen_rect, local_screen_ok, prefer_end_anchor);
        raw_looks_like_client_origin := rect_looks_like_client_origin(raw_rect);
        raw_already_screen_like := local_screen_ok and rect_in_screen(raw_rect, local_screen_rect) and
            (not raw_looks_like_client_origin);
        view_hwnd := 0;
        if view <> nil then
        begin
            view.GetWnd(view_hwnd);
        end;

        if local_screen_ok and raw_looks_like_client_origin then
        begin
            local_rect_adjusted := raw_rect;
            OffsetRect(local_rect_adjusted, local_screen_rect.Left, local_screen_rect.Top);
            candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                prefer_end_anchor);
            if candidate_candidate_score > best_candidate_score then
            begin
                best_candidate_rect := local_rect_adjusted;
                best_candidate_score := candidate_candidate_score;
            end;
        end;

        if raw_already_screen_like and try_convert_screen_rect_for_monitor_dpi(view_hwnd, raw_rect, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    prefer_end_anchor);
                Inc(candidate_candidate_score, 60);
                best_candidate_rect := local_rect_adjusted;
                best_candidate_score := candidate_candidate_score;
            end;
        end;

        if raw_already_screen_like and try_screen_rect_to_physical(view_hwnd, raw_rect, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    prefer_end_anchor);
                Inc(candidate_candidate_score, 90);
                best_candidate_rect := local_rect_adjusted;
                best_candidate_score := candidate_candidate_score;
            end;
        end;

        if (not raw_already_screen_like) and try_convert_with_view_hwnd(raw_rect, False, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    prefer_end_anchor);
                if candidate_candidate_score > best_candidate_score then
                begin
                    best_candidate_rect := local_rect_adjusted;
                    best_candidate_score := candidate_candidate_score;
                end;
            end;
        end;

        if (not raw_already_screen_like) and try_convert_with_view_hwnd(raw_rect, True, local_rect_adjusted) then
        begin
            if (not local_screen_ok) or rect_fully_in_screen(local_rect_adjusted, local_screen_rect) then
            begin
                candidate_candidate_score := score_text_ext_rect(local_rect_adjusted, local_screen_rect, local_screen_ok,
                    prefer_end_anchor);
                if candidate_candidate_score > best_candidate_score then
                begin
                    best_candidate_rect := local_rect_adjusted;
                    best_candidate_score := candidate_candidate_score;
                end;
            end;
        end;

        local_rect := best_candidate_rect;

        out_rect := local_rect;
        out_line_height := out_rect.Bottom - out_rect.Top;
        if out_line_height < 0 then
        begin
            out_line_height := 0;
        end;
        out_score := best_candidate_score;
        if query_mode = c_query_tail_char then
        begin
            Inc(out_score, 12);
        end;
        Result := True;
    end;
begin
    Result := False;
    if (m_point_ref = nil) or (m_point_valid_ref = nil) then
    begin
        Exit;
    end;

    m_point_valid_ref^ := False;
    if m_line_height_ref <> nil then
    begin
        m_line_height_ref^ := 0;
    end;
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

    best_found := False;
    best_score := Low(Integer);
    best_line_height := 0;
    collapsed_line_height := 0;
    tail_line_height := 0;
    full_line_height := 0;

    collapsed_found := try_get_range_rect(range, c_query_collapsed_end, candidate_rect, candidate_line_height,
        candidate_score);
    if collapsed_found then
    begin
        collapsed_rect := candidate_rect;
        collapsed_line_height := candidate_line_height;
        best_rect := candidate_rect;
        best_line_height := candidate_line_height;
        best_score := candidate_score;
        best_found := True;
    end;

    tail_found := try_get_range_rect(range, c_query_tail_char, candidate_rect, candidate_line_height,
        candidate_score);
    if tail_found then
    begin
        tail_rect := candidate_rect;
        tail_line_height := candidate_line_height;
        if (not best_found) or (candidate_score > best_score) then
        begin
            best_rect := candidate_rect;
            best_line_height := candidate_line_height;
            best_score := candidate_score;
            best_found := True;
        end;
    end;

    full_found := try_get_range_rect(range, c_query_full_range, candidate_rect, candidate_line_height,
        candidate_score);
    if full_found then
    begin
        full_rect := candidate_rect;
        full_line_height := candidate_line_height;
        if (not best_found) or (candidate_score > best_score) then
        begin
            best_rect := candidate_rect;
            best_line_height := candidate_line_height;
            best_found := True;
        end;
    end;

    if collapsed_found and best_found and EqualRect(best_rect, collapsed_rect) then
    begin
        if tail_found and rect_looks_like_range_start(collapsed_rect, tail_rect, collapsed_line_height) then
        begin
            best_rect := tail_rect;
            best_line_height := tail_line_height;
        end
        else if full_found and rect_looks_like_range_start(collapsed_rect, full_rect, collapsed_line_height) then
        begin
            best_rect := full_rect;
            best_line_height := full_line_height;
        end;
    end;

    if collapsed_found and best_found and EqualRect(best_rect, collapsed_rect) then
    begin
        if try_estimate_tail_rect_from_text(collapsed_rect, collapsed_line_height, candidate_rect) then
        begin
            best_rect := candidate_rect;
            best_line_height := collapsed_line_height;
        end;
    end;

    if collapsed_found then
    begin
        try_promote_estimated_tail(collapsed_rect, collapsed_line_height);
    end
    else if tail_found then
    begin
        try_promote_estimated_tail(tail_rect, tail_line_height);
    end
    else if full_found then
    begin
        try_promote_estimated_tail(full_rect, full_line_height);
    end;

    if best_found then
    begin
        m_point_ref^ := choose_text_ext_anchor_point(best_rect, best_line_height);
        if m_line_height_ref <> nil then
        begin
            m_line_height_ref^ := best_line_height;
        end;
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

    // Do not force a custom display-attribute property here.
    // Some app controls (notably certain WeChat editors) may render composition
    // text with reverse-video when GUID_PROP_ATTRIBUTE is present, even if the
    // attribute itself is neutral. We keep only COMPOSING state.

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
