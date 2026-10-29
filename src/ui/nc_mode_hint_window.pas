unit nc_mode_hint_window;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    Winapi.MultiMon,
    Winapi.ActiveX,
    Winapi.GDIPAPI,
    Winapi.GDIPOBJ,
    System.SysUtils,
    System.Types,
    System.Classes,
    System.Math,
    Vcl.Graphics,
    nc_types,
    nc_dpi_scale,
    nc_candidate_theme,
    nc_mode_hint_policy;

type
    // The label beside the caret that names the input mode: the brand mark and
    // 中 or 英 in the candidate window's colors. A layered window that takes
    // neither the focus nor the mouse; it fades in, holds and fades out. Lives
    // on the host's UI thread.
    TncModeHintWindow = class
    private
        m_handle: HWND;
        m_surface_dc: HDC;
        m_surface_bitmap: HBITMAP;
        m_surface_old_bitmap: HGDIOBJ;
        m_size: TSize;
        m_position: TPoint;
        m_shown_tick: UInt64;
        m_hold_ms: Cardinal;
        m_visible: Boolean;
        procedure ensure_handle;
        procedure free_surface;
        function build_surface(const mode: TncInputMode; const color_scheme: Integer;
            const dpi: Integer): Boolean;
        procedure present(const alpha: Byte);
        procedure advance;
        procedure hide_now;
    public
        constructor create;
        destructor Destroy; override;
        // anchor: the caret's left and the bottom of its line, in physical
        // screen coordinates (as the candidate window receives them).
        procedure show_hint(const anchor: TPoint; const line_height: Integer;
            const mode: TncInputMode; const color_scheme: Integer; const hold_ms: Cardinal);
        procedure dismiss;
        property visible: Boolean read m_visible;
    end;

implementation

const
    c_mode_hint_class_name = 'CassotisImeModeHint';
    c_mode_hint_timer_id = 1;
    c_mode_hint_timer_ms = 15;
    c_mode_hint_fade_in_ms = 120;
    c_mode_hint_fade_out_ms = 220;
    // Sizes at 96 DPI.
    c_mode_hint_height = 32;
    c_mode_hint_padding = 9;
    c_mode_hint_mark_size = 16;
    c_mode_hint_mark_gap = 5;
    c_mode_hint_text_px = 15;
    c_mode_hint_radius = 6;
    c_mode_hint_caret_gap = 4;
    c_mode_hint_font_name = 'Microsoft YaHei UI';
    c_mode_hint_fallback_font_name = 'Microsoft YaHei';
    c_mode_hint_mark_resource = 'YANQUAN_MARK_PNG';
    // 中 and 英.
    c_mode_hint_chinese = WideChar($4E2D);
    c_mode_hint_english = WideChar($82F1);

var
    g_mode_hint_class_registered: Boolean = False;

function mode_hint_window_proc(window: HWND; message: UINT; w_param: WPARAM;
    l_param: LPARAM): LRESULT; stdcall;
var
    owner: TncModeHintWindow;
begin
    case message of
        WM_NCCREATE:
            SetWindowLongPtr(window, GWLP_USERDATA,
                LONG_PTR(PCreateStruct(l_param)^.lpCreateParams));
        WM_TIMER:
            if w_param = c_mode_hint_timer_id then
            begin
                owner := TncModeHintWindow(GetWindowLongPtr(window, GWLP_USERDATA));
                if owner <> nil then
                    owner.advance;
                Exit(0);
            end;
        WM_MOUSEACTIVATE:
            Exit(MA_NOACTIVATE);
        WM_NCHITTEST:
            Exit(HTTRANSPARENT);
    end;
    Result := DefWindowProc(window, message, w_param, l_param);
end;

function monitor_dpi(const anchor: TPoint): Integer;
type
    TGetDpiForMonitor = function(monitor: HMONITOR; dpi_type: Integer; out dpi_x: UINT;
        out dpi_y: UINT): HRESULT; stdcall;
var
    module: HMODULE;
    get_dpi: TGetDpiForMonitor;
    dpi_x, dpi_y: UINT;
begin
    Result := 0;
    module := GetModuleHandle('Shcore.dll');
    if module = 0 then
        module := LoadLibrary('Shcore.dll');
    if module <> 0 then
    begin
        get_dpi := TGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
        if Assigned(get_dpi) and (get_dpi(MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST),
            0, dpi_x, dpi_y) = S_OK) then
            Result := dpi_x;
    end;
    Result := nc_normalize_dpi(Result);
end;

function monitor_work_area(const anchor: TPoint): TRect;
var
    info: TMonitorInfo;
begin
    info.cbSize := SizeOf(info);
    if GetMonitorInfo(MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST), @info) then
        Result := info.rcWork
    else if not SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0) then
        Result := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
end;

function opaque_color(const color: TColor): ARGB;
var
    value: COLORREF;
begin
    value := ColorToRGB(color);
    Result := MakeColor(255, GetRValue(value), GetGValue(value), GetBValue(value));
end;

function load_mark_bitmap: TGPBitmap;
var
    stream: TResourceStream;
    adapter: IStream;
    source: TGPBitmap;
begin
    Result := nil;
    if FindResource(HInstance, c_mode_hint_mark_resource, RT_RCDATA) = 0 then
        Exit;
    stream := TResourceStream.Create(HInstance, c_mode_hint_mark_resource, RT_RCDATA);
    try
        adapter := TStreamAdapter.Create(stream, soReference) as IStream;
        source := TGPBitmap.Create(adapter);
        try
            if source.GetLastStatus = Ok then
            begin
                // A copy: the stream goes when this returns.
                Result := source.Clone(0, 0, source.GetWidth, source.GetHeight,
                    PixelFormat32bppPARGB);
            end;
        finally
            source.Free;
        end;
        adapter := nil;
    finally
        stream.Free;
    end;
end;

constructor TncModeHintWindow.create;
begin
    inherited create;
    m_handle := 0;
    m_surface_dc := 0;
    m_surface_bitmap := 0;
    m_surface_old_bitmap := 0;
    m_visible := False;
end;

destructor TncModeHintWindow.Destroy;
begin
    if m_handle <> 0 then
    begin
        KillTimer(m_handle, c_mode_hint_timer_id);
        DestroyWindow(m_handle);
        m_handle := 0;
    end;
    free_surface;
    inherited Destroy;
end;

procedure TncModeHintWindow.ensure_handle;
var
    window_class: TWndClassEx;
begin
    if m_handle <> 0 then
        Exit;
    if not g_mode_hint_class_registered then
    begin
        FillChar(window_class, SizeOf(window_class), 0);
        window_class.cbSize := SizeOf(window_class);
        window_class.lpfnWndProc := @mode_hint_window_proc;
        window_class.hInstance := HInstance;
        window_class.lpszClassName := c_mode_hint_class_name;
        g_mode_hint_class_registered := RegisterClassEx(window_class) <> 0;
    end;
    m_handle := CreateWindowEx(WS_EX_LAYERED or WS_EX_TRANSPARENT or WS_EX_NOACTIVATE or
        WS_EX_TOOLWINDOW or WS_EX_TOPMOST, c_mode_hint_class_name, '', WS_POPUP,
        0, 0, 0, 0, 0, 0, HInstance, Pointer(Self));
end;

procedure TncModeHintWindow.free_surface;
begin
    if m_surface_dc <> 0 then
    begin
        if m_surface_old_bitmap <> 0 then
            SelectObject(m_surface_dc, m_surface_old_bitmap);
        DeleteDC(m_surface_dc);
        m_surface_dc := 0;
    end;
    m_surface_old_bitmap := 0;
    if m_surface_bitmap <> 0 then
    begin
        DeleteObject(m_surface_bitmap);
        m_surface_bitmap := 0;
    end;
end;

function TncModeHintWindow.build_surface(const mode: TncInputMode;
    const color_scheme: Integer; const dpi: Integer): Boolean;
var
    theme: TncCandidateColorTheme;
    info: TBitmapInfo;
    bits: Pointer;
    surface: TGPBitmap;
    graphics: TGPGraphics;
    path: TGPGraphicsPath;
    brush: TGPSolidBrush;
    pen: TGPPen;
    font: TGPFont;
    format: TGPStringFormat;
    mark: TGPBitmap;
    padding, mark_size, mark_gap, text_px, radius, text_left: Integer;
    diameter: Single;
    text: string;
begin
    Result := False;
    free_surface;
    theme := nc_candidate_color_theme(color_scheme);
    padding := nc_scale_for_dpi(c_mode_hint_padding, dpi);
    mark_size := nc_scale_for_dpi(c_mode_hint_mark_size, dpi);
    mark_gap := nc_scale_for_dpi(c_mode_hint_mark_gap, dpi);
    text_px := nc_scale_for_dpi(c_mode_hint_text_px, dpi);
    radius := nc_scale_for_dpi(c_mode_hint_radius, dpi);
    mark := load_mark_bitmap;
    try
        // A CJK character is one em wide.
        if mark <> nil then
            m_size.cx := padding + mark_size + mark_gap + text_px + padding
        else
            m_size.cx := padding + text_px + padding;
        m_size.cy := nc_scale_for_dpi(c_mode_hint_height, dpi);

        FillChar(info, SizeOf(info), 0);
        info.bmiHeader.biSize := SizeOf(info.bmiHeader);
        info.bmiHeader.biWidth := m_size.cx;
        info.bmiHeader.biHeight := -m_size.cy;
        info.bmiHeader.biPlanes := 1;
        info.bmiHeader.biBitCount := 32;
        info.bmiHeader.biCompression := BI_RGB;
        bits := nil;
        m_surface_bitmap := CreateDIBSection(0, info, DIB_RGB_COLORS, bits, 0, 0);
        if (m_surface_bitmap = 0) or (bits = nil) then
        begin
            free_surface;
            Exit;
        end;
        m_surface_dc := CreateCompatibleDC(0);
        m_surface_old_bitmap := SelectObject(m_surface_dc, m_surface_bitmap);

        surface := TGPBitmap.Create(m_size.cx, m_size.cy, m_size.cx * 4,
            PixelFormat32bppPARGB, bits);
        graphics := TGPGraphics.Create(surface);
        path := TGPGraphicsPath.Create;
        brush := TGPSolidBrush.Create(opaque_color(theme.background_color));
        pen := TGPPen.Create(opaque_color(theme.border_color), 1);
        font := TGPFont.Create(c_mode_hint_font_name, text_px, FontStyleRegular, UnitPixel);
        if font.GetLastStatus <> Ok then
        begin
            font.Free;
            font := TGPFont.Create(c_mode_hint_fallback_font_name, text_px, FontStyleRegular,
                UnitPixel);
        end;
        format := TGPStringFormat.Create(TGPStringFormat.GenericTypographic);
        try
            graphics.Clear(MakeColor(0, 0, 0, 0));
            graphics.SetSmoothingMode(SmoothingModeAntiAlias);
            graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
            graphics.SetInterpolationMode(InterpolationModeHighQualityBicubic);
            graphics.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);

            diameter := radius * 2;
            path.AddArc(0.5, 0.5, diameter, diameter, 180, 90);
            path.AddArc(m_size.cx - 0.5 - diameter, 0.5, diameter, diameter, 270, 90);
            path.AddArc(m_size.cx - 0.5 - diameter, m_size.cy - 0.5 - diameter,
                diameter, diameter, 0, 90);
            path.AddArc(0.5, m_size.cy - 0.5 - diameter, diameter, diameter, 90, 90);
            path.CloseFigure;
            graphics.FillPath(brush, path);
            graphics.DrawPath(pen, path);

            text_left := padding;
            if mark <> nil then
            begin
                graphics.DrawImage(mark, padding, (m_size.cy - mark_size) div 2,
                    mark_size, mark_size);
                text_left := padding + mark_size + mark_gap;
            end;
            if mode = im_english then
                text := c_mode_hint_english
            else
                text := c_mode_hint_chinese;
            brush.SetColor(opaque_color(theme.text_color));
            format.SetAlignment(StringAlignmentNear);
            format.SetLineAlignment(StringAlignmentCenter);
            graphics.DrawString(text, Length(text), font,
                MakeRect(text_left * 1.0, 0.0, (m_size.cx - text_left) * 1.0, m_size.cy * 1.0),
                format, brush);
            Result := True;
        finally
            format.Free;
            font.Free;
            pen.Free;
            brush.Free;
            path.Free;
            graphics.Free;
            surface.Free;
        end;
    finally
        mark.Free;
    end;
end;

procedure TncModeHintWindow.present(const alpha: Byte);
var
    blend: TBlendFunction;
    source_origin: TPoint;
    screen_dc: HDC;
begin
    if (m_handle = 0) or (m_surface_dc = 0) then
        Exit;
    blend.BlendOp := AC_SRC_OVER;
    blend.BlendFlags := 0;
    blend.SourceConstantAlpha := alpha;
    blend.AlphaFormat := AC_SRC_ALPHA;
    source_origin := Point(0, 0);
    screen_dc := GetDC(0);
    try
        UpdateLayeredWindow(m_handle, screen_dc, @m_position, @m_size, m_surface_dc,
            @source_origin, 0, @blend, ULW_ALPHA);
    finally
        ReleaseDC(0, screen_dc);
    end;
end;

procedure TncModeHintWindow.advance;
var
    elapsed: UInt64;
    alpha: Integer;
begin
    if not m_visible then
    begin
        KillTimer(m_handle, c_mode_hint_timer_id);
        Exit;
    end;
    elapsed := GetTickCount64 - m_shown_tick;
    if elapsed < c_mode_hint_fade_in_ms then
        alpha := Integer(elapsed * 255 div c_mode_hint_fade_in_ms)
    else if elapsed < c_mode_hint_fade_in_ms + m_hold_ms then
        alpha := 255
    else if elapsed < c_mode_hint_fade_in_ms + m_hold_ms + c_mode_hint_fade_out_ms then
        alpha := 255 - Integer((elapsed - c_mode_hint_fade_in_ms - m_hold_ms) * 255 div
            c_mode_hint_fade_out_ms)
    else
    begin
        hide_now;
        Exit;
    end;
    present(Byte(EnsureRange(alpha, 0, 255)));
end;

procedure TncModeHintWindow.hide_now;
begin
    m_visible := False;
    if m_handle <> 0 then
    begin
        KillTimer(m_handle, c_mode_hint_timer_id);
        ShowWindow(m_handle, SW_HIDE);
    end;
end;

procedure TncModeHintWindow.show_hint(const anchor: TPoint; const line_height: Integer;
    const mode: TncInputMode; const color_scheme: Integer; const hold_ms: Cardinal);
var
    dpi: Integer;
begin
    ensure_handle;
    if m_handle = 0 then
        Exit;
    dpi := monitor_dpi(anchor);
    if not build_surface(mode, color_scheme, dpi) then
    begin
        hide_now;
        Exit;
    end;
    m_position := nc_mode_hint_placement(anchor, line_height, m_size,
        nc_scale_for_dpi(c_mode_hint_caret_gap, dpi), monitor_work_area(anchor));
    m_hold_ms := hold_ms;
    m_shown_tick := GetTickCount64;
    m_visible := True;
    present(0);
    SetWindowPos(m_handle, HWND_TOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_SHOWWINDOW);
    SetTimer(m_handle, c_mode_hint_timer_id, c_mode_hint_timer_ms, nil);
end;

procedure TncModeHintWindow.dismiss;
begin
    if m_visible then
        hide_now;
end;

end.
