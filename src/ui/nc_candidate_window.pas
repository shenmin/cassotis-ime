unit nc_candidate_window;

interface

uses
    System.SysUtils,
    System.Types,
    System.Math,
    Classes,
    Vcl.Forms,
    Vcl.StdCtrls,
    Vcl.Controls,
    Vcl.Graphics,
    Winapi.Windows,
    Winapi.Messages,
    Winapi.MultiMon,
    Winapi.TlHelp32,
    Winapi.ActiveX,
    Winapi.GDIPAPI,
    Winapi.GDIPOBJ,
    nc_types,
    nc_shortcut,
    nc_dpi_scale,
    nc_version_info,
    nc_candidate_theme,
    nc_candidate_paging,
    nc_pinyin_input_diagnostics;

type
    TncCandidateRemoveEvent = procedure(const candidate_index: Integer) of object;
    TncCandidateClickResult = (ccr_rejected, ccr_prepared, ccr_dispatched);
    TncCandidatePrepareEvent = function(const page_index, candidate_index: Integer;
        const generation: UInt64): TncCandidateClickResult of object;

    TncCandidateWindow = class(TForm)
    private
        m_candidate_lines: TStringList;
        m_candidate_weight_lines: TStringList;
        m_candidate_sources: TArray<TncCandidateSource>;
        m_candidate_display_kinds: TArray<TncCandidateDisplayKind>;
        m_candidate_is_user: TArray<Boolean>;
        m_candidate_show_weight: TArray<Boolean>;
        m_candidate_widths: TArray<Integer>;
        m_candidate_number_widths: TArray<Integer>;
        m_candidate_offsets: TArray<Integer>;
        m_candidate_rows: TArray<Integer>;
        m_candidate_pages: TArray<Integer>;
        m_candidate_slots: TArray<Integer>;
        m_candidate_selection_keys: string;
        m_row_count: Integer;
        m_active_page_index: Integer;
        m_horizontal_placement: TncCandidateHorizontalPlacement;
        m_generation: UInt64;
        m_remove_button_rects: TArray<TRect>;
        m_selected_index: Integer;
        m_list_font: TFont;
        m_weight_font: TFont;
        m_brand_font: TFont;
        m_brand_icon: TIcon;
        m_brand_bitmap: TGPBitmap;
        m_brand_text: string;
        m_page_label: TLabel;
        m_preedit_label: TLabel;
        m_preedit_diagnostics: TncPinyinInputDiagnostics;
        m_preedit_spans: TncPinyinDiagnosticSpans;
        m_border_color: TColor;
        m_color_scheme: Integer;
        m_color_theme: TncCandidateColorTheme;
        m_debug_mode: Boolean;
        m_show_weight_row: Boolean;
        m_base_item_height: Integer;
        m_base_list_font_size: Integer;
        m_base_weight_font_size: Integer;
        m_base_weight_gap: Integer;
        m_base_label_font_size: Integer;
        m_base_label_height: Integer;
        m_base_preedit_font_size: Integer;
        m_base_preedit_height: Integer;
        m_base_item_gap: Integer;
        m_item_gap: Integer;
        m_base_list_padding: Integer;
        m_brand_icon_size: Integer;
        m_current_dpi: Integer;
        m_layout_dpi: Integer;
        m_layout_list_font_height: Integer;
        m_preview_minimum_client_width: Integer;
        m_list_item_height: Integer;
        m_list_rect: TRect;
        m_one_key_completion_rect: TRect;
        m_one_key_completion_text: string;
        m_one_key_completion_source: TncOneKeyCompletionSource;
        m_one_key_completion_key: TncOneKeyCompletionKey;
        m_preedit_rect: TRect;
        m_page_rect: TRect;
        m_list_padding: Integer;
        m_show_page_text: Boolean;
        m_show_preedit_text: Boolean;
        m_base_remove_button_size: Integer;
        m_base_remove_button_gap: Integer;
        m_remove_button_size: Integer;
        m_remove_button_gap: Integer;
        m_base_remove_hit_padding: Integer;
        m_remove_hit_padding: Integer;
        m_weight_gap: Integer;
        m_swallow_next_button_up: Boolean;
        m_on_remove_user_candidate: TncCandidateRemoveEvent;
        m_on_prepare_candidate: TncCandidatePrepareEvent;
        procedure configure_form;
        procedure configure_page_label;
        procedure configure_preedit_label;
        function create_brand_bitmap_from_resource(
            const target_size: Integer): TGPBitmap;
        procedure rebuild_brand_bitmap;
        procedure apply_current_dpi;
        procedure apply_dpi(const dpi: Integer);
        function get_target_dpi(const anchor: TPoint): Integer;
        function get_work_area(const anchor: TPoint; out work_area: TRect): Boolean;
        function get_shell_search_overlay_rect(out overlay_rect: TRect): Boolean;
        function format_candidate_text(const candidate: TncCandidate): string;
        function candidate_has_pinyin_tail(const candidate: TncCandidate): Boolean;
        function candidate_can_remove(const candidate: TncCandidate): Boolean;
        function get_candidate_text_color(const source: TncCandidateSource;
            const display_kind: TncCandidateDisplayKind): TColor;
        function get_selected_candidate_text_color(const source: TncCandidateSource;
            const display_kind: TncCandidateDisplayKind): TColor;
        function canvas_font_can_render_text(const text: string): Boolean;
        procedure assign_list_font_for_text(const text: string; const font_color: TColor);
        function hit_test_candidate_index(const point: TPoint): Integer;
        function hit_test_remove_candidate_index(const point: TPoint): Integer;
        procedure recompute_remove_button_rects;
        procedure draw_remove_button(const bounds: TRect; const selected: Boolean);
        procedure send_prepared_selection_key;
        function format_page_text(const page_index: Integer; const page_count: Integer): string;
        procedure update_size;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
        procedure WMMouseActivate(var Message: TMessage); message WM_MOUSEACTIVATE;
        procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
        procedure WMDpiChanged(var Message: TMessage); message WM_DPICHANGED;
        procedure WMNCHitTest(var Message: TMessage); message WM_NCHITTEST;
        procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
        procedure WMLButtonUp(var Message: TWMLButtonUp); message WM_LBUTTONUP;
        procedure Paint; override;
    public
        constructor create; reintroduce;
        procedure prepare_for_anchor(const anchor: TPoint);
        destructor Destroy; override;
        procedure apply_appearance(const font_name: string; const font_size: Integer;
            const color_scheme: Integer);
        procedure prepare_preview(const dpi: Integer;
            const minimum_client_width: Integer = 0);
        procedure update_candidates(const candidates: TncCandidateList; const page_index: Integer; const page_count: Integer;
            const selected_index: Integer; const preedit_text: string;
            const one_key_completion: TncOneKeyCompletion;
            const one_key_completion_key: TncOneKeyCompletionKey;
            const debug_mode: Boolean;
            const pinyin_scheme: TncPinyinInputScheme = pis_full_pinyin;
            const pages: TncCandidatePages = nil; const generation: UInt64 = 0;
            const quick_input_active: Boolean = False;
            const selection_keys: string = '123456789');
        function candidate_selection_label(const candidate_index: Integer): string;
        procedure show_at(const x: Integer; const y: Integer;
            const prefer_above: Boolean = False; const clearance: Integer = 0);
        procedure hide_window;
        property candidate_area: TRect read m_list_rect;
        property completion_area: TRect read m_one_key_completion_rect;
        property on_remove_user_candidate: TncCandidateRemoveEvent read m_on_remove_user_candidate
            write m_on_remove_user_candidate;
        property on_prepare_candidate: TncCandidatePrepareEvent read m_on_prepare_candidate
            write m_on_prepare_candidate;
    end;

function nc_calculate_candidate_top(const anchor_y: Integer;
    const candidate_height: Integer; const gap: Integer;
    const clearance: Integer; const work_area: TRect;
    const prefer_above: Boolean): Integer;

implementation

uses
    nc_preedit_renderer;

type
    TGetDpiForWindow = function(hwnd: HWND): UINT; stdcall;

var
    g_vcl_initialized: Boolean = False;
    g_get_dpi_for_window_ready: Boolean = False;
    g_get_dpi_for_window: TGetDpiForWindow = nil;
    g_shell_overlay_cache_hwnd: HWND = 0;
    g_shell_overlay_cache_tick: DWORD = 0;
    g_shell_overlay_cache_is_shell: Boolean = False;
    g_shell_overlay_cache_has_rect: Boolean = False;
    g_shell_overlay_cache_rect: TRect = (Left: 0; Top: 0; Right: 0; Bottom: 0);

const
    c_candidate_text_height_sample = 'Hg' + WideChar($56FD);
    c_candidate_brand_font_name = 'Microsoft YaHei UI';
    c_candidate_brand_font_size = 8;
    c_candidate_brand_icon_size = 18;
    c_candidate_brand_icon_gap = 6;
    c_candidate_brand_resource_name = 'YANQUAN_MARK_PNG';

function font_family_available(const font_name: string): Boolean;
begin
    Result := (Trim(font_name) <> '') and (Screen.Fonts.IndexOf(font_name) >= 0);
end;

function resolve_candidate_font_name(const font_name: string): string;
var
    requested_name: string;
begin
    requested_name := Trim(font_name);
    if requested_name = '' then
    begin
        requested_name := c_default_candidate_font_name;
    end;

    if SameText(requested_name, '霞鹜文楷') and font_family_available('LXGW WenKai') then
    begin
        Result := 'LXGW WenKai';
        Exit;
    end;

    if font_family_available(requested_name) then
    begin
        Result := requested_name;
        Exit;
    end;

    Result := c_default_candidate_font_name;
end;

function get_window_process_image_name(const hwnd: HWND): string;
var
    process_id: DWORD;
    snapshot: THandle;
    entry: TProcessEntry32;
begin
    Result := '';
    if hwnd = 0 then
    begin
        Exit;
    end;

    process_id := 0;
    GetWindowThreadProcessId(hwnd, @process_id);
    if process_id = 0 then
    begin
        Exit;
    end;

    snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if snapshot = INVALID_HANDLE_VALUE then
    begin
        Exit;
    end;
    try
        ZeroMemory(@entry, SizeOf(entry));
        entry.dwSize := SizeOf(entry);
        if Process32First(snapshot, entry) then
        begin
            repeat
                if entry.th32ProcessID = process_id then
                begin
                    Result := LowerCase(string(entry.szExeFile));
                    Exit;
                end;
            until not Process32Next(snapshot, entry);
        end;
    finally
        CloseHandle(snapshot);
    end;
end;

function is_shell_search_surface_process(const process_name: string): Boolean;
begin
    Result := SameText(process_name, 'searchhost.exe') or
        SameText(process_name, 'searchapp.exe') or
        SameText(process_name, 'startmenuexperiencehost.exe') or
        SameText(process_name, 'shellexperiencehost.exe') or
        SameText(process_name, 'textinputhost.exe');
end;

function rects_overlap(const left_rect: TRect; const right_rect: TRect): Boolean;
var
    intersection: TRect;
begin
    Result := IntersectRect(intersection, left_rect, right_rect);
end;

function draw_canvas_text(const canvas: TCanvas; const text: string; var bounds: TRect; const flags: UINT): Integer;
var
    old_font: HGDIOBJ;
begin
    Result := 0;
    if canvas = nil then
    begin
        Exit;
    end;

    old_font := SelectObject(canvas.Handle, canvas.Font.Handle);
    try
        SetBkMode(canvas.Handle, TRANSPARENT);
        SetTextColor(canvas.Handle, ColorToRGB(canvas.Font.Color));
        Result := DrawTextW(canvas.Handle, PWideChar(text), Length(text), bounds, flags);
    finally
        if (old_font <> 0) and (old_font <> HGDIOBJ(GDI_ERROR)) then
        begin
            SelectObject(canvas.Handle, old_font);
        end;
    end;
end;

procedure draw_outlined_canvas_text(const canvas: TCanvas;
    const text: string; const bounds: TRect; const flags: UINT;
    const outline_color: TColor; const text_color: TColor);
var
    original_color: TColor;

    procedure draw_offset(const offset_x, offset_y: Integer);
    var
        shifted_bounds: TRect;
    begin
        shifted_bounds := bounds;
        OffsetRect(shifted_bounds, offset_x, offset_y);
        draw_canvas_text(canvas, text, shifted_bounds, flags);
    end;
begin
    if (canvas = nil) or (text = '') then
    begin
        Exit;
    end;

    original_color := canvas.Font.Color;
    try
        canvas.Font.Color := outline_color;
        draw_offset(-1, -1);
        draw_offset(0, -1);
        draw_offset(1, -1);
        draw_offset(-1, 0);
        draw_offset(1, 0);
        draw_offset(-1, 1);
        draw_offset(0, 1);
        draw_offset(1, 1);

        canvas.Font.Color := text_color;
        draw_offset(0, 0);
    finally
        canvas.Font.Color := original_color;
    end;
end;

function candidate_brand_outline_color(
    const background_color: TColor): TColor;
var
    rgb_color: COLORREF;
    red_value: Integer;
    green_value: Integer;
    blue_value: Integer;
    luminance: Integer;
begin
    rgb_color := ColorToRGB(background_color);
    red_value := GetRValue(rgb_color);
    green_value := GetGValue(rgb_color);
    blue_value := GetBValue(rgb_color);
    luminance := ((red_value * 299) + (green_value * 587) +
        (blue_value * 114)) div 1000;
    if luminance < 128 then
    begin
        Result := RGB(red_value div 3, green_value div 3,
            blue_value div 3);
    end
    else
    begin
        Result := clWhite;
    end;
end;

function try_get_dpi_for_window(const wnd: HWND; out dpi: Integer): Boolean;
var
    module: HMODULE;
begin
    if not g_get_dpi_for_window_ready then
    begin
        module := GetModuleHandle('user32.dll');
        if module = 0 then
        begin
            module := LoadLibrary('user32.dll');
        end;
        if module <> 0 then
        begin
            g_get_dpi_for_window := TGetDpiForWindow(GetProcAddress(module, 'GetDpiForWindow'));
        end;
        g_get_dpi_for_window_ready := True;
    end;

    dpi := 0;
    Result := Assigned(g_get_dpi_for_window) and (wnd <> 0);
    if Result then
    begin
        dpi := Integer(g_get_dpi_for_window(wnd));
        Result := dpi > 0;
    end;
end;

procedure ensure_vcl_initialized;
begin
    if g_vcl_initialized then
    begin
        Exit;
    end;

    if Application.Handle <> 0 then
    begin
        g_vcl_initialized := True;
        Exit;
    end;

    Application.Initialize;
    Application.ShowMainForm := False;
    g_vcl_initialized := True;
end;

function TncCandidateWindow.create_brand_bitmap_from_resource(
    const target_size: Integer): TGPBitmap;
var
    resource_stream: TResourceStream;
    resource_adapter: IStream;
    source_bitmap: TGPBitmap;
    graphics: TGPGraphics;
begin
    Result := nil;
    if target_size < 1 then
    begin
        Exit;
    end;

    resource_stream := nil;
    resource_adapter := nil;
    source_bitmap := nil;
    try
        resource_stream := TResourceStream.Create(HInstance,
            c_candidate_brand_resource_name, RT_RCDATA);
        resource_adapter := TStreamAdapter.Create(resource_stream,
            soReference) as IStream;
        source_bitmap := TGPBitmap.Create(resource_adapter);
        Result := TGPBitmap.Create(target_size, target_size,
            PixelFormat32bppPARGB);
        graphics := TGPGraphics.Create(Result);
        try
            graphics.Clear(MakeColor(0, 0, 0, 0));
            graphics.SetCompositingQuality(CompositingQualityHighQuality);
            graphics.SetInterpolationMode(InterpolationModeHighQualityBicubic);
            graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
            graphics.SetSmoothingMode(SmoothingModeHighQuality);
            graphics.DrawImage(source_bitmap, 0, 0, target_size,
                target_size);
        finally
            graphics.Free;
        end;
    except
        if Result <> nil then
        begin
            Result.Free;
            Result := nil;
        end;
    end;
    source_bitmap.Free;
    resource_adapter := nil;
    resource_stream.Free;
end;

procedure TncCandidateWindow.rebuild_brand_bitmap;
begin
    if m_brand_bitmap <> nil then
    begin
        m_brand_bitmap.Free;
        m_brand_bitmap := nil;
    end;
    m_brand_bitmap := create_brand_bitmap_from_resource(m_brand_icon_size);
end;

constructor TncCandidateWindow.create;
var
    product_version: string;
begin
    ensure_vcl_initialized;
    inherited CreateNew(nil);
    m_candidate_lines := TStringList.Create;
    m_candidate_weight_lines := TStringList.Create;
    m_list_font := TFont.Create;
    m_weight_font := TFont.Create;
    m_brand_font := TFont.Create;
    m_brand_icon := TIcon.Create;
    m_brand_bitmap := nil;
    if (Application.Icon <> nil) and (not Application.Icon.Empty) then
    begin
        m_brand_icon.Assign(Application.Icon);
    end;
    m_brand_text := '';
    product_version := Trim(nc_get_current_exe_display_version);
    if product_version <> '' then
    begin
        m_brand_text := '(v' + product_version + ')';
    end;
    m_color_scheme := c_default_candidate_color_scheme;
    m_color_theme := nc_candidate_color_theme(m_color_scheme);
    m_border_color := m_color_theme.border_color;
    m_debug_mode := False;
    m_show_weight_row := False;
    m_base_item_height := 20;
    m_base_list_font_size := c_default_candidate_font_size;
    m_base_weight_font_size := Max(6, c_default_candidate_font_size - 2);
    m_base_weight_gap := 1;
    m_base_label_font_size := 8;
    m_base_label_height := 18;
    m_base_preedit_font_size := c_default_candidate_font_size;
    m_base_preedit_height := 20;
    m_base_item_gap := 12;
    m_item_gap := m_base_item_gap;
    m_base_list_padding := 6;
    m_brand_icon_size := c_candidate_brand_icon_size;
    m_current_dpi := 0;
    m_layout_dpi := 0;
    m_layout_list_font_height := 0;
    m_preview_minimum_client_width := 0;
    m_list_item_height := m_base_item_height;
    m_list_rect := Rect(0, 0, 0, 0);
    m_one_key_completion_rect := Rect(0, 0, 0, 0);
    m_one_key_completion_text := '';
    m_one_key_completion_source := okcs_none;
    m_one_key_completion_key := ock_tab;
    m_preedit_rect := Rect(0, 0, 0, 0);
    m_page_rect := Rect(0, 0, 0, 0);
    m_list_padding := m_base_list_padding;
    m_show_page_text := False;
    m_show_preedit_text := False;
    m_preedit_diagnostics := TncPinyinInputDiagnostics.Create;
    m_base_remove_button_size := 14;
    m_base_remove_button_gap := 5;
    m_remove_button_size := m_base_remove_button_size;
    m_remove_button_gap := m_base_remove_button_gap;
    m_base_remove_hit_padding := 8;
    m_remove_hit_padding := m_base_remove_hit_padding;
    m_weight_gap := m_base_weight_gap;
    m_swallow_next_button_up := False;
    m_selected_index := 0;
    SetLength(m_candidate_sources, 0);
    SetLength(m_candidate_display_kinds, 0);
    SetLength(m_candidate_is_user, 0);
    SetLength(m_candidate_show_weight, 0);
    SetLength(m_candidate_widths, 0);
    SetLength(m_candidate_offsets, 0);
    SetLength(m_remove_button_rects, 0);
    m_on_remove_user_candidate := nil;
    configure_form;
    configure_preedit_label;
    configure_page_label;

    m_list_font.Name := c_default_candidate_font_name;
    m_list_font.Charset := DEFAULT_CHARSET;
    m_list_font.Height := nc_font_height_for_dpi(m_base_list_font_size, c_nc_base_dpi);
    m_list_font.Color := m_color_theme.text_color;

    m_weight_font.Name := c_default_candidate_font_name;
    m_weight_font.Charset := DEFAULT_CHARSET;
    m_weight_font.Height := nc_font_height_for_dpi(m_base_weight_font_size, c_nc_base_dpi);
    m_weight_font.Color := m_color_theme.weight_text_color;

    m_brand_font.Name := c_candidate_brand_font_name;
    m_brand_font.Charset := DEFAULT_CHARSET;
    m_brand_font.Height := nc_font_height_for_dpi(
        c_candidate_brand_font_size, c_nc_base_dpi);
    m_brand_font.Color := m_color_theme.muted_text_color;
    rebuild_brand_bitmap;
end;

destructor TncCandidateWindow.Destroy;
begin
    m_preedit_diagnostics.Free;
    if m_candidate_weight_lines <> nil then
    begin
        m_candidate_weight_lines.Free;
        m_candidate_weight_lines := nil;
    end;

    if m_candidate_lines <> nil then
    begin
        m_candidate_lines.Free;
        m_candidate_lines := nil;
    end;

    if m_list_font <> nil then
    begin
        m_list_font.Free;
        m_list_font := nil;
    end;

    if m_weight_font <> nil then
    begin
        m_weight_font.Free;
        m_weight_font := nil;
    end;

    if m_brand_font <> nil then
    begin
        m_brand_font.Free;
        m_brand_font := nil;
    end;

    if m_brand_icon <> nil then
    begin
        m_brand_icon.Free;
        m_brand_icon := nil;
    end;

    if m_brand_bitmap <> nil then
    begin
        m_brand_bitmap.Free;
        m_brand_bitmap := nil;
    end;

    inherited Destroy;
end;

procedure TncCandidateWindow.configure_form;
begin
    BorderStyle := bsNone;
    FormStyle := fsStayOnTop;
    Position := poDesigned;
    Scaled := False;
    DoubleBuffered := True;
    Color := m_color_theme.background_color;
    Padding.Left := 1;
    Padding.Top := 1;
    Padding.Right := 1;
    Padding.Bottom := 1;
    Visible := False;
end;

procedure TncCandidateWindow.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);
    Params.ExStyle := Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOOLWINDOW or WS_EX_TOPMOST;
end;

procedure TncCandidateWindow.WMMouseActivate(var Message: TMessage);
begin
    // Keep editor focus on target app while still receiving mouse click.
    Message.Result := MA_NOACTIVATE;
end;

procedure TncCandidateWindow.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
    // A per-monitor DPI move can discard the old backing surface before the
    // next WM_PAINT. Clear it explicitly so no pixels from the previous size
    // or monitor survive the first frame.
    FillRect(Message.DC, ClientRect, Brush.Handle);
    Message.Result := 1;
end;

procedure TncCandidateWindow.WMDpiChanged(var Message: TMessage);
var
    dpi: Integer;
begin
    inherited;
    dpi := Integer(Message.WParam) and $FFFF;
    if dpi <= 0 then
    begin
        if not try_get_dpi_for_window(Handle, dpi) then
        begin
            dpi := c_nc_base_dpi;
        end;
    end;

    if dpi <> m_current_dpi then
    begin
        apply_dpi(dpi);
        if (m_candidate_lines.Count > 0) or
            (m_one_key_completion_text <> '') then
        begin
            update_size;
        end;
        Invalidate;
    end;
end;

procedure TncCandidateWindow.WMNCHitTest(var Message: TMessage);
begin
    // Candidate window is interactive (click-to-select), but should not activate.
    Message.Result := HTCLIENT;
end;

function TncCandidateWindow.hit_test_candidate_index(const point: TPoint): Integer;
var
    i: Integer;
    edge_padding: Integer;
    item_left: Integer;
    item_right: Integer;
    user_candidate: Boolean;
begin
    Result := -1;
    if (point.Y < m_list_rect.Top) or (point.Y >= m_list_rect.Bottom) then
    begin
        Exit;
    end;

    edge_padding := m_list_padding;
    for i := 0 to m_candidate_lines.Count - 1 do
    begin
        if (i >= Length(m_candidate_offsets)) or (i >= Length(m_candidate_widths)) then
        begin
            Continue;
        end;

        item_left := m_list_rect.Left + edge_padding + m_candidate_offsets[i];
        item_right := item_left + m_candidate_widths[i];
        user_candidate := (i < Length(m_candidate_is_user)) and m_candidate_is_user[i];
        if user_candidate then
        begin
            Dec(item_right, m_remove_button_size + m_remove_button_gap + m_list_padding);
        end;
        if item_right <= item_left then
        begin
            Continue;
        end;
        if (point.X >= item_left) and (point.X < item_right) and
            ((point.Y - m_list_rect.Top) div m_list_item_height = m_candidate_rows[i]) then
        begin
            Result := i;
            Exit;
        end;
    end;
end;

function TncCandidateWindow.hit_test_remove_candidate_index(const point: TPoint): Integer;
var
    i: Integer;
    hit_rect: TRect;
begin
    Result := -1;
    for i := 0 to High(m_remove_button_rects) do
    begin
        hit_rect := m_remove_button_rects[i];
        if not IsRectEmpty(hit_rect) then
        begin
            InflateRect(hit_rect, m_remove_hit_padding, m_remove_hit_padding);
        end;
        if PtInRect(hit_rect, point) then
        begin
            Result := i;
            Exit;
        end;
    end;
end;

procedure TncCandidateWindow.recompute_remove_button_rects;
var
    i: Integer;
    edge_padding: Integer;
    item_left: Integer;
    item_right: Integer;
    button_left: Integer;
    button_top: Integer;
begin
    SetLength(m_remove_button_rects, m_candidate_lines.Count);
    for i := 0 to High(m_remove_button_rects) do
    begin
        m_remove_button_rects[i] := Rect(0, 0, 0, 0);
    end;

    if m_candidate_lines.Count = 0 then
    begin
        Exit;
    end;

    edge_padding := m_list_padding;
    for i := 0 to m_candidate_lines.Count - 1 do
    begin
        if (i >= Length(m_candidate_is_user)) or (not m_candidate_is_user[i]) then
        begin
            Continue;
        end;
        if m_candidate_pages[i] <> m_active_page_index then Continue;
        if (i >= Length(m_candidate_offsets)) or (i >= Length(m_candidate_widths)) then
        begin
            Continue;
        end;

        item_left := m_list_rect.Left + edge_padding + m_candidate_offsets[i];
        item_right := item_left + m_candidate_widths[i];
        button_left := item_right - m_list_padding - m_remove_button_size;
        button_top := m_list_rect.Top + m_candidate_rows[i] * m_list_item_height +
            ((m_list_item_height - m_remove_button_size) div 2);
        m_remove_button_rects[i] := Rect(button_left, button_top, button_left + m_remove_button_size,
            button_top + m_remove_button_size);
    end;
end;

procedure TncCandidateWindow.draw_remove_button(const bounds: TRect; const selected: Boolean);
var
    stroke_color: TColor;
    fill_color: TColor;
    line_color: TColor;
    radius: Integer;
    inset: Integer;
begin
    if IsRectEmpty(bounds) then
    begin
        Exit;
    end;

    if selected then
    begin
        fill_color := TColor(RGB(255, 237, 238));
        stroke_color := TColor(RGB(229, 115, 115));
        line_color := TColor(RGB(183, 28, 28));
    end
    else
    begin
        fill_color := TColor(RGB(250, 250, 250));
        stroke_color := TColor(RGB(207, 216, 220));
        line_color := TColor(RGB(136, 146, 156));
    end;

    radius := nc_scale_for_dpi(4, m_current_dpi);
    if radius < 2 then
    begin
        radius := 2;
    end;

    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := fill_color;
    Canvas.Pen.Color := stroke_color;
    Canvas.RoundRect(bounds.Left, bounds.Top, bounds.Right, bounds.Bottom, radius, radius);

    inset := Max(2, bounds.Width div 3);
    Canvas.Pen.Color := line_color;
    Canvas.MoveTo(bounds.Left + inset, bounds.Top + inset);
    Canvas.LineTo(bounds.Right - inset, bounds.Bottom - inset);
    Canvas.MoveTo(bounds.Right - inset, bounds.Top + inset);
    Canvas.LineTo(bounds.Left + inset, bounds.Bottom - inset);
end;

procedure TncCandidateWindow.send_prepared_selection_key;
var
    key_code: Word;
    input_events: array[0..1] of TInput;
begin
    // Compatibility with an already loaded older TSF DLL: the host has
    // selected the item. Space cannot be mistaken for numeric-mode input.
    key_code := VK_SPACE;
    ZeroMemory(@input_events, SizeOf(input_events));

    input_events[0].Itype := INPUT_KEYBOARD;
    input_events[0].ki.wVk := key_code;
    input_events[0].ki.wScan := MapVirtualKey(key_code, MAPVK_VK_TO_VSC);
    input_events[0].ki.dwFlags := 0;

    input_events[1].Itype := INPUT_KEYBOARD;
    input_events[1].ki.wVk := key_code;
    input_events[1].ki.wScan := MapVirtualKey(key_code, MAPVK_VK_TO_VSC);
    input_events[1].ki.dwFlags := KEYEVENTF_KEYUP;

    SendInput(Length(input_events), input_events[0], SizeOf(TInput));
end;

procedure TncCandidateWindow.WMLButtonDown(var Message: TWMLButtonDown);
var
    remove_index: Integer;
begin
    remove_index := hit_test_remove_candidate_index(Point(Message.XPos, Message.YPos));
    if remove_index >= 0 then
    begin
        if Assigned(m_on_remove_user_candidate) then
        begin
            m_on_remove_user_candidate(m_candidate_slots[remove_index]);
        end;
        m_swallow_next_button_up := True;
        Message.Result := 0;
        Exit;
    end;

    m_swallow_next_button_up := False;
    inherited;
end;

procedure TncCandidateWindow.WMLButtonUp(var Message: TWMLButtonUp);
var
    remove_index: Integer;
    click_index: Integer;
begin
    if m_swallow_next_button_up then
    begin
        m_swallow_next_button_up := False;
        Message.Result := 0;
        Exit;
    end;

    remove_index := hit_test_remove_candidate_index(Point(Message.XPos, Message.YPos));
    if remove_index >= 0 then
    begin
        if Assigned(m_on_remove_user_candidate) then
        begin
            m_on_remove_user_candidate(m_candidate_slots[remove_index]);
        end;
        Message.Result := 0;
        Exit;
    end;

    click_index := hit_test_candidate_index(Point(Message.XPos, Message.YPos));
    if click_index >= 0 then
    begin
        if (not Assigned(m_on_prepare_candidate)) or
            (m_on_prepare_candidate(m_candidate_pages[click_index],
                m_candidate_slots[click_index], m_generation) <> ccr_prepared) then
        begin
            Message.Result := 0;
            Exit;
        end;
        m_selected_index := click_index;
        Invalidate;
        send_prepared_selection_key;
    end;

    Message.Result := 0;
end;

procedure TncCandidateWindow.configure_preedit_label;
begin
    m_preedit_label := TLabel.Create(Self);
    m_preedit_label.Parent := Self;
    m_preedit_label.Align := alNone;
    m_preedit_label.AutoSize := False;
    m_preedit_label.ParentFont := False;
    m_preedit_label.Height := m_base_preedit_height;
    m_preedit_label.Alignment := taLeftJustify;
    m_preedit_label.Layout := tlCenter;
    m_preedit_label.Font.Name := c_default_candidate_font_name;
    m_preedit_label.Font.Charset := DEFAULT_CHARSET;
    m_preedit_label.Font.Height := nc_font_height_for_dpi(m_base_preedit_font_size, c_nc_base_dpi);
    m_preedit_label.Font.Color := m_color_theme.muted_text_color;
    m_preedit_label.Transparent := False;
    m_preedit_label.Color := Color;
    m_preedit_label.Visible := False;
end;

procedure TncCandidateWindow.configure_page_label;
begin
    m_page_label := TLabel.Create(Self);
    m_page_label.Parent := Self;
    m_page_label.Align := alNone;
    m_page_label.AutoSize := False;
    m_page_label.ParentFont := False;
    m_page_label.Height := m_base_label_height;
    m_page_label.Alignment := taRightJustify;
    m_page_label.Layout := tlCenter;
    m_page_label.Font.Name := c_default_candidate_font_name;
    m_page_label.Font.Charset := DEFAULT_CHARSET;
    m_page_label.Font.Height := nc_font_height_for_dpi(m_base_label_font_size, c_nc_base_dpi);
    m_page_label.Font.Color := m_color_theme.muted_text_color;
    m_page_label.Transparent := False;
    m_page_label.Color := Color;
    m_page_label.Visible := False;
end;

procedure TncCandidateWindow.apply_current_dpi;
var
    dpi: Integer;
begin
    HandleNeeded;
    if not try_get_dpi_for_window(Handle, dpi) then
    begin
        dpi := c_nc_base_dpi;
    end;

    apply_dpi(dpi);
end;

procedure TncCandidateWindow.prepare_for_anchor(const anchor: TPoint);
var
    dpi: Integer;
begin
    HandleNeeded;
    dpi := get_target_dpi(anchor);
    if dpi <> m_current_dpi then
    begin
        apply_dpi(dpi);
    end;
end;

procedure TncCandidateWindow.apply_dpi(const dpi: Integer);
begin
    if dpi <= 0 then
    begin
        Exit;
    end;

    m_current_dpi := dpi;
    m_list_font.Height := nc_font_height_for_dpi(m_base_list_font_size, dpi);
    m_weight_font.Height := nc_font_height_for_dpi(m_base_weight_font_size, dpi);
    m_brand_font.Height := nc_font_height_for_dpi(
        c_candidate_brand_font_size, dpi);
    m_list_item_height := nc_scale_for_dpi(m_base_item_height, dpi);
    m_page_label.Font.Height := nc_font_height_for_dpi(m_base_label_font_size, dpi);
    m_page_label.Height := nc_scale_for_dpi(m_base_label_height, dpi);
    m_preedit_label.Font.Height := nc_font_height_for_dpi(m_base_preedit_font_size, dpi);
    m_preedit_label.Height := nc_scale_for_dpi(m_base_preedit_height, dpi);
    m_item_gap := nc_scale_for_dpi(m_base_item_gap, dpi);
    m_list_padding := nc_scale_for_dpi(m_base_list_padding, dpi);
    m_brand_icon_size := nc_scale_for_dpi(c_candidate_brand_icon_size, dpi);
    rebuild_brand_bitmap;
    m_weight_gap := nc_scale_for_dpi(m_base_weight_gap, dpi);
    m_remove_button_size := nc_scale_for_dpi(m_base_remove_button_size, dpi);
    m_remove_button_gap := nc_scale_for_dpi(m_base_remove_button_gap, dpi);
    m_remove_hit_padding := nc_scale_for_dpi(m_base_remove_hit_padding, dpi);
    if m_remove_hit_padding < 2 then
    begin
        m_remove_hit_padding := 2;
    end;
end;

procedure TncCandidateWindow.apply_appearance(const font_name: string; const font_size: Integer;
    const color_scheme: Integer);
var
    effective_font_name: string;
    effective_font_size: Integer;
    effective_color_scheme: Integer;
    effective_color_theme: TncCandidateColorTheme;
begin
    effective_font_name := resolve_candidate_font_name(font_name);
    effective_color_scheme := nc_normalize_candidate_color_scheme(color_scheme);
    effective_color_theme := nc_candidate_color_theme(effective_color_scheme);

    effective_font_size := font_size;
    if effective_font_size < c_min_candidate_font_size then
    begin
        effective_font_size := c_min_candidate_font_size;
    end
    else if effective_font_size > c_max_candidate_font_size then
    begin
        effective_font_size := c_max_candidate_font_size;
    end;

    if SameText(m_list_font.Name, effective_font_name) and (m_base_list_font_size = effective_font_size) and
        (m_color_scheme = effective_color_scheme) and
        (Color = effective_color_theme.background_color) and
        (m_border_color = effective_color_theme.border_color) and
        (m_list_font.Color = effective_color_theme.text_color) and
        (m_weight_font.Color = effective_color_theme.weight_text_color) and
        (m_brand_font.Color = effective_color_theme.muted_text_color) then
    begin
        Exit;
    end;

    m_color_scheme := effective_color_scheme;
    m_color_theme := effective_color_theme;
    m_border_color := m_color_theme.border_color;
    Color := m_color_theme.background_color;

    m_base_list_font_size := effective_font_size;
    m_base_preedit_font_size := effective_font_size;
    m_base_label_font_size := Max(7, effective_font_size - 1);
    m_base_weight_font_size := Max(6, effective_font_size - 2);

    m_list_font.Name := effective_font_name;
    m_list_font.Charset := DEFAULT_CHARSET;
    m_list_font.Color := m_color_theme.text_color;
    m_weight_font.Name := effective_font_name;
    m_weight_font.Charset := DEFAULT_CHARSET;
    m_weight_font.Color := m_color_theme.weight_text_color;
    m_brand_font.Color := m_color_theme.muted_text_color;
    if m_preedit_label <> nil then
    begin
        m_preedit_label.Font.Name := effective_font_name;
        m_preedit_label.Font.Charset := DEFAULT_CHARSET;
        m_preedit_label.Font.Color := m_color_theme.muted_text_color;
        m_preedit_label.Color := Color;
    end;
    if m_page_label <> nil then
    begin
        m_page_label.Font.Name := effective_font_name;
        m_page_label.Font.Charset := DEFAULT_CHARSET;
        m_page_label.Font.Color := m_color_theme.muted_text_color;
        m_page_label.Color := Color;
    end;

    if m_current_dpi > 0 then
    begin
        apply_dpi(m_current_dpi);
    end
    else
    begin
        apply_dpi(c_nc_base_dpi);
    end;
    update_size;
    Invalidate;
end;

procedure TncCandidateWindow.prepare_preview(const dpi: Integer;
    const minimum_client_width: Integer);
begin
    m_preview_minimum_client_width := Max(0, minimum_client_width);
    apply_dpi(nc_normalize_dpi(dpi));
    if (m_candidate_lines.Count > 0) or
        (m_one_key_completion_text <> '') then
    begin
        update_size;
    end;
    Invalidate;
end;

function TncCandidateWindow.get_target_dpi(const anchor: TPoint): Integer;
type
    TGetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer; out dpiX: UINT;
        out dpiY: UINT): HRESULT; stdcall;
const
    MDT_EFFECTIVE_DPI = 0;
var
    monitor: HMONITOR;
    module: HMODULE;
    get_dpi: TGetDpiForMonitor;
    dpi_x: UINT;
    dpi_y: UINT;
begin
    Result := 0;
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor <> 0 then
    begin
        module := GetModuleHandle('Shcore.dll');
        if module = 0 then
        begin
            module := LoadLibrary('Shcore.dll');
        end;
        if module <> 0 then
        begin
            get_dpi := TGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
            if Assigned(get_dpi) and (get_dpi(monitor, MDT_EFFECTIVE_DPI, dpi_x, dpi_y) = S_OK) then
            begin
                Result := dpi_x;
            end;
        end;
    end;

    if Result <= 0 then
    begin
        if not try_get_dpi_for_window(Handle, Result) then
        begin
            Result := 0;
        end;
    end;
    if Result <= 0 then
    begin
        Result := c_nc_base_dpi;
    end;
end;

function TncCandidateWindow.get_work_area(const anchor: TPoint; out work_area: TRect): Boolean;
var
    monitor: HMONITOR;
    info: TMonitorInfo;
begin
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor <> 0 then
    begin
        info.cbSize := SizeOf(info);
        if GetMonitorInfo(monitor, @info) then
        begin
            work_area := info.rcWork;
            Result := True;
            Exit;
        end;
    end;

    Result := SystemParametersInfo(SPI_GETWORKAREA, 0, @work_area, 0);
end;

function TncCandidateWindow.get_shell_search_overlay_rect(out overlay_rect: TRect): Boolean;
var
    foreground_hwnd: HWND;
    process_name: string;
    now_tick: DWORD;
begin
    Result := False;
    foreground_hwnd := GetForegroundWindow;
    if foreground_hwnd = 0 then
    begin
        Exit;
    end;

    foreground_hwnd := GetAncestor(foreground_hwnd, GA_ROOT);
    if foreground_hwnd = 0 then
    begin
        Exit;
    end;

    now_tick := GetTickCount;
    if (foreground_hwnd = g_shell_overlay_cache_hwnd) and
        (DWORD(now_tick - g_shell_overlay_cache_tick) < 250) then
    begin
        if g_shell_overlay_cache_is_shell and g_shell_overlay_cache_has_rect then
        begin
            overlay_rect := g_shell_overlay_cache_rect;
            Result := True;
        end;
        Exit;
    end;

    g_shell_overlay_cache_hwnd := foreground_hwnd;
    g_shell_overlay_cache_tick := now_tick;
    g_shell_overlay_cache_is_shell := False;
    g_shell_overlay_cache_has_rect := False;
    g_shell_overlay_cache_rect := Rect(0, 0, 0, 0);

    process_name := get_window_process_image_name(foreground_hwnd);
    g_shell_overlay_cache_is_shell := is_shell_search_surface_process(process_name);
    if (not g_shell_overlay_cache_is_shell) or (not IsWindowVisible(foreground_hwnd)) or
        (not GetWindowRect(foreground_hwnd, overlay_rect)) then
    begin
        Exit;
    end;

    Result := (overlay_rect.Right > overlay_rect.Left) and (overlay_rect.Bottom > overlay_rect.Top);
    g_shell_overlay_cache_has_rect := Result;
    if Result then
    begin
        g_shell_overlay_cache_rect := overlay_rect;
    end;
end;

function TncCandidateWindow.format_candidate_text(const candidate: TncCandidate): string;
var
    suffix: string;
    comment_text: string;
    i: Integer;
    is_pinyin_tail: Boolean;
begin
    suffix := candidate.text;
    comment_text := Trim(candidate.comment);
    is_pinyin_tail := comment_text <> '';
    if is_pinyin_tail then
    begin
        for i := 1 to Length(comment_text) do
        begin
            if not CharInSet(comment_text[i], ['a' .. 'z', 'A' .. 'Z', '''']) then
            begin
                is_pinyin_tail := False;
                Break;
            end;
        end;
    end;

    // Hide trailing unmatched pinyin in candidate UI (e.g. "你好  ma").
    // The engine still keeps candidate.comment for partial-commit behavior.
    if (comment_text <> '') and (not is_pinyin_tail) then
    begin
        suffix := suffix + '  ' + comment_text;
    end;

    Result := suffix;
end;

function TncCandidateWindow.candidate_has_pinyin_tail(const candidate: TncCandidate): Boolean;
var
    text_value: string;
    idx: Integer;
    has_tail: Boolean;
begin
    Result := False;
    if Trim(candidate.comment) <> '' then
    begin
        Result := True;
        Exit;
    end;

    text_value := Trim(candidate.text);
    if text_value = '' then
    begin
        Exit;
    end;

    has_tail := False;
    idx := Length(text_value);
    while idx > 0 do
    begin
        if not CharInSet(text_value[idx], ['a' .. 'z', 'A' .. 'Z']) then
        begin
            Break;
        end;
        has_tail := True;
        Dec(idx);
    end;

    Result := has_tail and (idx > 0);
end;

function TncCandidateWindow.candidate_can_remove(const candidate: TncCandidate): Boolean;
begin
    Result := (candidate.source = cs_user) and (Trim(candidate.text) <> '') and
        (not candidate_has_pinyin_tail(candidate));
end;

function TncCandidateWindow.get_candidate_text_color(const source: TncCandidateSource;
    const display_kind: TncCandidateDisplayKind): TColor;
begin
    if source = cs_user then
    begin
        Result := m_color_theme.user_text_color;
    end
    else if display_kind = cdk_lm_compound then
    begin
        Result := m_color_theme.lm_compound_text_color;
    end
    else
    begin
        Result := m_color_theme.text_color;
    end;
end;

function TncCandidateWindow.get_selected_candidate_text_color(const source: TncCandidateSource;
    const display_kind: TncCandidateDisplayKind): TColor;
begin
    if source = cs_user then
    begin
        Result := m_color_theme.selected_user_text_color;
    end
    else if display_kind = cdk_lm_compound then
    begin
        Result := m_color_theme.selected_lm_compound_text_color;
    end
    else
    begin
        Result := m_color_theme.selected_text_color;
    end;
end;

function TncCandidateWindow.canvas_font_can_render_text(const text: string): Boolean;
const
    c_missing_glyph = WORD($FFFF);
var
    glyphs: TArray<WORD>;
    glyph_count: DWORD;
    idx: Integer;
    old_font: HGDIOBJ;
begin
    Result := True;
    if text = '' then
    begin
        Exit;
    end;

    SetLength(glyphs, Length(text));
    if Length(glyphs) = 0 then
    begin
        Exit;
    end;

    old_font := SelectObject(Canvas.Handle, Canvas.Font.Handle);
    try
        glyph_count := GetGlyphIndicesW(Canvas.Handle, PWideChar(text), Length(text),
            @glyphs[0], GGI_MARK_NONEXISTING_GLYPHS);
        if glyph_count = GDI_ERROR then
        begin
            Result := False;
            Exit;
        end;

        for idx := 0 to High(glyphs) do
        begin
            if glyphs[idx] = c_missing_glyph then
            begin
                Result := False;
                Exit;
            end;
        end;
    finally
        if (old_font <> 0) and (old_font <> HGDIOBJ(GDI_ERROR)) then
        begin
            SelectObject(Canvas.Handle, old_font);
        end;
    end;
end;

procedure TncCandidateWindow.assign_list_font_for_text(const text: string; const font_color: TColor);
begin
    Canvas.Font.Assign(m_list_font);
    Canvas.Font.Color := font_color;
    SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
    if canvas_font_can_render_text(text) then
    begin
        Exit;
    end;

    // Some localized or user-selected font face names can fail GDI glyph lookup
    // during the first host paint. Fall back to the built-in CJK-capable face.
    Canvas.Font.Assign(m_list_font);
    Canvas.Font.Name := c_default_candidate_font_name;
    Canvas.Font.Charset := DEFAULT_CHARSET;
    Canvas.Font.Color := font_color;
    SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
end;

function TncCandidateWindow.format_page_text(const page_index: Integer; const page_count: Integer): string;
var
    current_page: Integer;
begin
    if page_count <= 0 then
    begin
        Result := '';
        Exit;
    end;

    current_page := page_index + 1;
    Result := 'Page ' + IntToStr(current_page) + '/' + IntToStr(page_count);
end;

procedure TncCandidateWindow.update_size;
var
    i: Integer;
    text_width: Integer;
    main_text_width: Integer;
    weight_text_width: Integer;
    max_width: Integer;
    item_count: Integer;
    label_height: Integer;
    preedit_height: Integer;
    list_height: Integer;
    row_width: Integer;
    inner_left: Integer;
    inner_top: Integer;
    inner_width: Integer;
    current_top: Integer;
    edge_padding: Integer;
    main_text_height: Integer;
    weight_text_height: Integer;
    dynamic_item_height: Integer;
    meta_text_height: Integer;
    meta_vertical_padding: Integer;
    meta_horizontal_padding: Integer;
    list_vertical_padding: Integer;
    font_size_delta: Integer;
    completion_height: Integer;
    completion_width: Integer;
    completion_key_text: string;
    completion_key_width: Integer;
    completion_gap: Integer;
    completion_text_width: Integer;
    brand_width: Integer;
    brand_gap: Integer;
    brand_icon_width: Integer;
    brand_icon_gap: Integer;
begin
    item_count := m_candidate_lines.Count;
    if (item_count = 0) and (m_one_key_completion_text = '') then
    begin
        Exit;
    end;

    assign_list_font_for_text(c_candidate_text_height_sample, m_list_font.Color);
    main_text_height := Canvas.TextHeight(c_candidate_text_height_sample);
    Canvas.Font.Assign(m_weight_font);
    weight_text_height := Canvas.TextHeight(c_candidate_text_height_sample);

    font_size_delta := m_base_list_font_size -
        c_candidate_font_layout_reference_size;
    if font_size_delta < 0 then
    begin
        font_size_delta := 0;
    end;
    list_vertical_padding := nc_scale_for_dpi(4 + (font_size_delta * 2), m_current_dpi);
    if list_vertical_padding < 4 then
    begin
        list_vertical_padding := 4;
    end;

    dynamic_item_height := nc_scale_for_dpi(m_base_item_height, m_current_dpi);
    dynamic_item_height := Max(dynamic_item_height, main_text_height + list_vertical_padding);
    if m_show_weight_row then
    begin
        dynamic_item_height := Max(dynamic_item_height, main_text_height + m_weight_gap + weight_text_height +
            list_vertical_padding);
    end;
    m_list_item_height := dynamic_item_height;

    row_width := 0;
    SetLength(m_candidate_widths, item_count);
    SetLength(m_candidate_number_widths, item_count);
    SetLength(m_candidate_offsets, item_count);
    for i := 0 to item_count - 1 do
    begin
        assign_list_font_for_text(m_candidate_lines[i], m_list_font.Color);
        // Reserve numbering on every row so changing the active page cannot shift text.
        m_candidate_number_widths[i] := Canvas.TextWidth(candidate_selection_label(i));
        main_text_width := m_candidate_number_widths[i] + Canvas.TextWidth(m_candidate_lines[i]);
        weight_text_width := 0;
        if m_show_weight_row and (i < Length(m_candidate_show_weight)) and m_candidate_show_weight[i] then
        begin
            Canvas.Font.Assign(m_weight_font);
            weight_text_width := Canvas.TextWidth(m_candidate_weight_lines[i]);
        end;

        text_width := Max(main_text_width, weight_text_width) + (m_list_padding * 2);
        if (i < Length(m_candidate_is_user)) and m_candidate_is_user[i] then
        begin
            Inc(text_width, m_remove_button_gap + m_remove_button_size + m_list_padding);
        end;
        m_candidate_widths[i] := text_width;
        if (i = 0) or (m_candidate_rows[i] <> m_candidate_rows[i - 1]) then
        begin
            m_candidate_offsets[i] := 0;
        end
        else
        begin
            m_candidate_offsets[i] := m_candidate_offsets[i - 1] + m_candidate_widths[i - 1] + m_item_gap;
        end;
        row_width := Max(row_width, m_candidate_offsets[i] + m_candidate_widths[i]);
    end;
    if item_count > 0 then
    begin
        row_width := Max(row_width,
            m_candidate_offsets[item_count - 1] + m_candidate_widths[item_count - 1]);
    end;
    if (item_count > 0) and
        (row_width < nc_scale_for_dpi(120, m_current_dpi)) then
    begin
        row_width := nc_scale_for_dpi(120, m_current_dpi);
    end;
    edge_padding := m_list_padding;
    max_width := row_width + (edge_padding * 2);
    meta_vertical_padding := nc_scale_for_dpi(8, m_current_dpi);
    meta_horizontal_padding := nc_scale_for_dpi(16, m_current_dpi);
    if meta_vertical_padding < 4 then
    begin
        meta_vertical_padding := 4;
    end;
    if meta_horizontal_padding < 8 then
    begin
        meta_horizontal_padding := 8;
    end;

    // Reserve the completion row for the lifetime of the candidate window so
    // suggestions can appear or disappear without moving the window anchor.
    completion_height := Max(m_list_item_height,
        main_text_height + list_vertical_padding) + 1;
    Canvas.Font.Assign(m_brand_font);
    brand_width := Canvas.TextWidth(m_brand_text);
    brand_icon_width := 0;
    brand_icon_gap := 0;
    if (m_brand_bitmap <> nil) or
        ((m_brand_icon <> nil) and (not m_brand_icon.Empty) and
        (m_brand_icon.Handle <> 0)) then
    begin
        brand_icon_width := m_brand_icon_size;
        if m_brand_text <> '' then
        begin
            brand_icon_gap := nc_scale_for_dpi(
                c_candidate_brand_icon_gap, m_current_dpi);
        end;
    end;
    brand_width := brand_icon_width + brand_icon_gap + brand_width + 2;
    brand_gap := nc_scale_for_dpi(12, m_current_dpi);
    completion_width := (m_list_padding * 2) + brand_width;
    if m_one_key_completion_text <> '' then
    begin
        completion_key_text := 'Tab';
        if m_one_key_completion_key = ock_backtick then
        begin
            completion_key_text := '`';
        end;
        Canvas.Font.Assign(m_weight_font);
        completion_key_width := Canvas.TextWidth(completion_key_text);
        assign_list_font_for_text(m_one_key_completion_text,
            nc_completion_text_color(m_color_theme, m_one_key_completion_source));
        completion_text_width := Canvas.TextWidth(m_one_key_completion_text);
        completion_gap := nc_scale_for_dpi(8, m_current_dpi);
        completion_width := (m_list_padding * 2) + completion_key_width +
            completion_gap + completion_text_width +
            brand_gap + brand_width;
    end;
    if completion_width > max_width then
    begin
        max_width := completion_width;
    end;
    if m_preview_minimum_client_width > 0 then
    begin
        max_width := Max(max_width, m_preview_minimum_client_width -
            Padding.Left - Padding.Right);
    end;

    label_height := 0;
    if m_show_page_text then
    begin
        Canvas.Font.Assign(m_page_label.Font);
        meta_text_height := Canvas.TextHeight('Hg');
        text_width := Canvas.TextWidth(m_page_label.Caption) + meta_horizontal_padding;
        if text_width > max_width then
        begin
            max_width := text_width;
        end;
        label_height := meta_text_height + meta_vertical_padding;
    end;

    preedit_height := 0;
    if m_show_preedit_text then
    begin
        Canvas.Font.Assign(m_preedit_label.Font);
        meta_text_height := Canvas.TextHeight('Hg');
        text_width := Canvas.TextWidth(m_preedit_label.Caption) + meta_horizontal_padding;
        if text_width > max_width then
        begin
            max_width := text_width;
        end;
        preedit_height := meta_text_height + meta_vertical_padding;
    end;

    if item_count > 0 then
    begin
        list_height := m_list_item_height * m_row_count;
    end
    else
    begin
        list_height := 0;
    end;
    ClientWidth := max_width + Padding.Left + Padding.Right;
    ClientHeight := preedit_height + list_height + completion_height +
        label_height + Padding.Top + Padding.Bottom;

    inner_left := Padding.Left;
    inner_top := Padding.Top;
    inner_width := ClientWidth - Padding.Left - Padding.Right;
    current_top := inner_top;
    m_preedit_rect := Rect(0, 0, 0, 0);
    m_page_rect := Rect(0, 0, 0, 0);
    m_list_rect := Rect(0, 0, 0, 0);
    m_one_key_completion_rect := Rect(0, 0, 0, 0);

    if m_show_preedit_text then
    begin
        m_preedit_rect := Rect(inner_left, current_top, inner_left + inner_width, current_top + preedit_height);
        current_top := current_top + preedit_height;
    end;

    if list_height > 0 then
    begin
        m_list_rect := Rect(inner_left, current_top,
            inner_left + inner_width, current_top + list_height);
        current_top := current_top + list_height;
    end;

    if completion_height > 0 then
    begin
        m_one_key_completion_rect := Rect(inner_left, current_top,
            inner_left + inner_width, current_top + completion_height);
        current_top := current_top + completion_height;
    end;

    if m_show_page_text then
    begin
        m_page_rect := Rect(inner_left, current_top, inner_left + inner_width, current_top + label_height);
    end;

    recompute_remove_button_rects;
    m_layout_dpi := m_current_dpi;
    m_layout_list_font_height := m_list_font.Height;
end;

procedure TncCandidateWindow.Paint;
var
    i: Integer;
    line_height: Integer;
    main_text_height: Integer;
    weight_text_height: Integer;
    content_height: Integer;
    main_text_top: Integer;
    weight_text_top: Integer;
    y: Integer;
    x: Integer;
    item_left: Integer;
    item_right: Integer;
    candidate_right: Integer;
    line_rect: TRect;
    candidate_source: TncCandidateSource;
    candidate_display_kind: TncCandidateDisplayKind;
    remove_rect: TRect;
    text_right: Integer;
    user_candidate: Boolean;
    text_rect: TRect;
    number_rect: TRect;
    weight_text_rect: TRect;
    corner_radius: Integer;
    edge_padding: Integer;
    active_row: Integer;
    active_row_rect: TRect;
    indicator_rect: TRect;
    indicator_width: Integer;
    indicator_height: Integer;
    preedit_rect: TRect;
    page_rect: TRect;
    completion_rect: TRect;
    completion_key_rect: TRect;
    completion_text_rect: TRect;
    brand_rect: TRect;
    brand_icon_rect: TRect;
    brand_text_rect: TRect;
    completion_key_text: string;
    completion_key_width: Integer;
    brand_text_width: Integer;
    brand_gap: Integer;
    brand_icon_width: Integer;
    brand_icon_gap: Integer;
    brand_graphics: TGPGraphics;
begin
    inherited;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(ClientRect);

    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := m_border_color;
    Canvas.Rectangle(0, 0, Width, Height);

    if (m_layout_dpi <> m_current_dpi) or
        (m_layout_list_font_height <> m_list_font.Height) then
    begin
        update_size;
    end;

    if m_show_preedit_text and (m_preedit_label.Caption <> '') and (not IsRectEmpty(m_preedit_rect)) then
    begin
        preedit_rect := m_preedit_rect;
        InflateRect(preedit_rect, -nc_scale_for_dpi(8, m_current_dpi), 0);
        Canvas.Font.Assign(m_preedit_label.Font);
        Canvas.Font.Color := m_preedit_label.Font.Color;
        SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
        nc_draw_preedit_text(Canvas, m_preedit_label.Caption, preedit_rect,
            m_preedit_spans, nc_preedit_warning_color(m_color_theme.background_color));
    end;

    if m_show_page_text and (m_page_label.Caption <> '') and (not IsRectEmpty(m_page_rect)) then
    begin
        page_rect := m_page_rect;
        InflateRect(page_rect, -nc_scale_for_dpi(8, m_current_dpi), 0);
        Canvas.Font.Assign(m_page_label.Font);
        Canvas.Font.Color := m_page_label.Font.Color;
        SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
        draw_canvas_text(Canvas, m_page_label.Caption, page_rect,
            DT_RIGHT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
    end;

    if not IsRectEmpty(m_one_key_completion_rect) then
    begin
        completion_rect := m_one_key_completion_rect;
        Canvas.Font.Assign(m_brand_font);
        brand_text_width := Canvas.TextWidth(m_brand_text);
        brand_icon_width := 0;
        brand_icon_gap := 0;
        if (m_brand_bitmap <> nil) or
            ((m_brand_icon <> nil) and (not m_brand_icon.Empty) and
            (m_brand_icon.Handle <> 0)) then
        begin
            brand_icon_width := m_brand_icon_size;
            if m_brand_text <> '' then
            begin
                brand_icon_gap := nc_scale_for_dpi(
                    c_candidate_brand_icon_gap, m_current_dpi);
            end;
        end;
        brand_rect := completion_rect;
        brand_rect.Right := completion_rect.Right - m_list_padding - 1;
        brand_rect.Left := brand_rect.Right - brand_icon_width -
            brand_icon_gap - brand_text_width;
        brand_gap := nc_scale_for_dpi(12, m_current_dpi);

        if m_one_key_completion_text <> '' then
        begin
            Canvas.Pen.Color := m_border_color;
            Canvas.MoveTo(completion_rect.Left + m_list_padding,
                completion_rect.Top);
            Canvas.LineTo(completion_rect.Right - m_list_padding,
                completion_rect.Top);

            completion_key_text := 'Tab';
            if m_one_key_completion_key = ock_backtick then
            begin
                completion_key_text := '`';
            end;
            Canvas.Font.Assign(m_weight_font);
            Canvas.Font.Color := m_color_theme.muted_text_color;
            completion_key_width := Canvas.TextWidth(completion_key_text);
            completion_key_rect := completion_rect;
            completion_key_rect.Left := completion_rect.Left + m_list_padding;
            completion_key_rect.Right := completion_key_rect.Left +
                completion_key_width;
            draw_canvas_text(Canvas, completion_key_text,
                completion_key_rect, DT_LEFT or DT_VCENTER or DT_SINGLELINE or
                DT_NOPREFIX);

            completion_text_rect := completion_rect;
            completion_text_rect.Left := completion_key_rect.Right +
                nc_scale_for_dpi(8, m_current_dpi);
            completion_text_rect.Right := brand_rect.Left - brand_gap;
            assign_list_font_for_text(m_one_key_completion_text,
                nc_completion_text_color(m_color_theme, m_one_key_completion_source));
            draw_canvas_text(Canvas, m_one_key_completion_text,
                completion_text_rect,
                DT_LEFT or DT_VCENTER or DT_SINGLELINE or
                DT_END_ELLIPSIS or DT_NOPREFIX);
        end;

        brand_text_rect := brand_rect;
        if brand_icon_width > 0 then
        begin
            brand_icon_rect := brand_rect;
            brand_icon_rect.Right := brand_icon_rect.Left + brand_icon_width;
            brand_icon_rect.Top := completion_rect.Top +
                ((completion_rect.Height - m_brand_icon_size) div 2);
            brand_icon_rect.Bottom := brand_icon_rect.Top + m_brand_icon_size;
            if m_brand_bitmap <> nil then
            begin
                brand_graphics := TGPGraphics.Create(Canvas.Handle);
                try
                    brand_graphics.SetCompositingQuality(
                        CompositingQualityHighQuality);
                    brand_graphics.DrawImage(m_brand_bitmap,
                        brand_icon_rect.Left, brand_icon_rect.Top);
                finally
                    brand_graphics.Free;
                end;
            end
            else
            begin
                DrawIconEx(Canvas.Handle, brand_icon_rect.Left,
                    brand_icon_rect.Top, m_brand_icon.Handle,
                    brand_icon_rect.Width, brand_icon_rect.Height, 0, 0,
                    DI_NORMAL);
            end;
            brand_text_rect.Left := brand_icon_rect.Right + brand_icon_gap;
        end;
        if m_brand_text <> '' then
        begin
            Canvas.Font.Assign(m_brand_font);
            draw_outlined_canvas_text(Canvas, m_brand_text, brand_text_rect,
                DT_RIGHT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX,
                candidate_brand_outline_color(Color), m_brand_font.Color);
        end;
    end;

    if (m_candidate_lines = nil) or (m_candidate_lines.Count = 0) then
    begin
        Exit;
    end;

    SetBkMode(Canvas.Handle, TRANSPARENT);
    line_height := m_list_item_height;
    assign_list_font_for_text('Hg', m_list_font.Color);
    main_text_height := Canvas.TextHeight('Hg');
    Canvas.Font.Assign(m_weight_font);
    weight_text_height := Canvas.TextHeight('Hg');
    content_height := main_text_height;
    if m_show_weight_row then
    begin
        content_height := content_height + m_weight_gap + weight_text_height;
    end;
    corner_radius := nc_scale_for_dpi(6, m_current_dpi);
    edge_padding := m_list_padding;
    active_row := -1;
    if (m_row_count > 1) and (m_selected_index >= 0) and
        (m_selected_index < Length(m_candidate_rows)) then
    begin
        active_row := m_candidate_rows[m_selected_index];
        active_row_rect := m_list_rect;
        active_row_rect.Top := m_list_rect.Top + active_row * line_height;
        active_row_rect.Bottom := active_row_rect.Top + line_height;
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := m_color_theme.active_row_background_color;
        Canvas.FillRect(active_row_rect);

        // Use the existing left gutter without shifting text or hit targets.
        indicator_width := nc_scale_for_dpi(2, m_current_dpi);
        indicator_height := Min(main_text_height,
            line_height - nc_scale_for_dpi(8, m_current_dpi));
        indicator_rect.Left := active_row_rect.Left + nc_scale_for_dpi(1, m_current_dpi);
        indicator_rect.Right := indicator_rect.Left + indicator_width;
        indicator_rect.Top := active_row_rect.Top + (line_height - indicator_height) div 2;
        indicator_rect.Bottom := indicator_rect.Top + indicator_height;
        Canvas.Brush.Color := m_color_theme.active_row_indicator_color;
        Canvas.Pen.Color := m_color_theme.active_row_indicator_color;
        Canvas.RoundRect(indicator_rect.Left, indicator_rect.Top,
            indicator_rect.Right, indicator_rect.Bottom, indicator_width, indicator_width);
    end;
    for i := 0 to m_candidate_lines.Count - 1 do
    begin
        if (i >= Length(m_candidate_offsets)) or (i >= Length(m_candidate_widths)) then
        begin
            Continue;
        end;

        item_left := m_list_rect.Left + edge_padding + m_candidate_offsets[i];
        item_right := item_left + m_candidate_widths[i];
        candidate_right := item_right;
        y := m_list_rect.Top + m_candidate_rows[i] * line_height;
        x := item_left + m_list_padding;
        candidate_source := cs_rule;
        if i < Length(m_candidate_sources) then
        begin
            candidate_source := m_candidate_sources[i];
        end;
        candidate_display_kind := cdk_default;
        if i < Length(m_candidate_display_kinds) then
        begin
            candidate_display_kind := m_candidate_display_kinds[i];
        end;
        user_candidate := (i < Length(m_candidate_is_user)) and m_candidate_is_user[i];
        if user_candidate then
        begin
            Dec(candidate_right, m_remove_button_size + m_remove_button_gap + m_list_padding);
            if candidate_right <= item_left then
            begin
                candidate_right := item_left;
            end;
        end;
        line_rect := Rect(item_left, y, candidate_right, y + line_height);
        remove_rect := Rect(0, 0, 0, 0);
        if (i < Length(m_remove_button_rects)) and user_candidate then
        begin
            remove_rect := m_remove_button_rects[i];
        end;
        Canvas.Brush.Style := bsSolid;
        if i = m_selected_index then
        begin
            Canvas.Brush.Color := m_color_theme.selected_background_color;
            Canvas.Pen.Color := m_color_theme.selected_border_color;
            Canvas.RoundRect(item_left, y + 1, item_right, y + line_height - 1, corner_radius, corner_radius);
            Canvas.Font.Color := get_selected_candidate_text_color(
                candidate_source, candidate_display_kind);
            SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
        end
        else
        begin
            if m_candidate_rows[i] = active_row then
                Canvas.Brush.Color := m_color_theme.active_row_background_color
            else
                Canvas.Brush.Color := Color;
            Canvas.FillRect(line_rect);
            Canvas.Font.Color := get_candidate_text_color(candidate_source,
                candidate_display_kind);
            SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
        end;

        text_right := candidate_right - m_list_padding;
        if text_right <= x then
        begin
            text_right := candidate_right;
        end;

        main_text_top := y + 1;
        if line_height > content_height then
        begin
            main_text_top := y + ((line_height - content_height) div 2);
        end;

        if i = m_selected_index then
        begin
            assign_list_font_for_text(m_candidate_lines[i],
                get_selected_candidate_text_color(candidate_source,
                candidate_display_kind));
        end
        else
        begin
            assign_list_font_for_text(m_candidate_lines[i],
                get_candidate_text_color(candidate_source,
                candidate_display_kind));
        end;
        text_rect := Rect(x, main_text_top, text_right, main_text_top + main_text_height);
        number_rect := text_rect;
        number_rect.Right := number_rect.Left + m_candidate_number_widths[i];
        if m_candidate_pages[i] = m_active_page_index then
            draw_canvas_text(Canvas, candidate_selection_label(i), number_rect,
                DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
        text_rect.Left := number_rect.Right;
        draw_canvas_text(Canvas, m_candidate_lines[i], text_rect,
            DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

        if m_show_weight_row and (i < Length(m_candidate_show_weight)) and m_candidate_show_weight[i] then
        begin
            Canvas.Font.Assign(m_weight_font);
            if i = m_selected_index then
            begin
                Canvas.Font.Color := m_color_theme.selected_weight_text_color;
            end
            else
            begin
                Canvas.Font.Color := m_weight_font.Color;
            end;
            SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
            weight_text_top := main_text_top + main_text_height + m_weight_gap;
            weight_text_rect := Rect(x + nc_scale_for_dpi(2, m_current_dpi), weight_text_top, text_right,
                weight_text_top + weight_text_height);
            draw_canvas_text(Canvas, m_candidate_weight_lines[i], weight_text_rect,
                DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
        end;

        if not IsRectEmpty(remove_rect) then
        begin
            draw_remove_button(remove_rect, i = m_selected_index);
        end;
    end;
end;

function TncCandidateWindow.candidate_selection_label(const candidate_index: Integer): string;
var key_index: Integer;
begin
    Result := '';
    if (candidate_index < 0) or (candidate_index >= Length(m_candidate_slots)) then Exit;
    key_index := m_candidate_slots[candidate_index] + 1;
    if (key_index >= 1) and (key_index <= Length(m_candidate_selection_keys)) then
        Result := m_candidate_selection_keys[key_index] + '. ';
end;

procedure TncCandidateWindow.update_candidates(const candidates: TncCandidateList; const page_index: Integer;
    const page_count: Integer; const selected_index: Integer;
    const preedit_text: string;
    const one_key_completion: TncOneKeyCompletion;
    const one_key_completion_key: TncOneKeyCompletionKey;
    const debug_mode: Boolean;
    const pinyin_scheme: TncPinyinInputScheme;
    const pages: TncCandidatePages; const generation: UInt64;
    const quick_input_active: Boolean; const selection_keys: string);
const
    c_show_page_label = False;
var
    i: Integer;
    count: Integer;
    row, slot, offset, active_slot: Integer;
    displayed: TncCandidateList;
begin
    m_generation := generation;
    m_candidate_selection_keys := selection_keys;
    if (m_preedit_label.Caption <> preedit_text) or (Length(pages) <= 1) then
        m_horizontal_placement := Default(TncCandidateHorizontalPlacement);
    m_active_page_index := page_index;
    m_debug_mode := debug_mode;
    m_one_key_completion_text := Trim(one_key_completion.text);
    m_one_key_completion_source := one_key_completion.source;
    m_one_key_completion_key := nc_normalize_one_key_completion_key(
        one_key_completion_key);
    m_candidate_lines.BeginUpdate;
    m_candidate_weight_lines.BeginUpdate;
    try
        m_candidate_lines.Clear;
        m_candidate_weight_lines.Clear;
        m_row_count := 1;
        if Length(pages) > 0 then m_row_count := Min(c_candidate_viewport_rows, Length(pages));
        count := Length(candidates);
        if Length(pages) > 0 then
        begin
            count := 0;
            for row := 0 to m_row_count - 1 do Inc(count, Length(pages[row].candidates));
        end;
        SetLength(displayed, count);
        SetLength(m_candidate_rows, count);
        SetLength(m_candidate_pages, count);
        SetLength(m_candidate_slots, count);
        m_selected_index := -1;
        offset := 0;
        active_slot := Max(0, selected_index);
        for row := 0 to m_row_count - 1 do
        begin
            if Length(pages) > 0 then
            begin
                for slot := 0 to High(pages[row].candidates) do
                begin
                    displayed[offset] := pages[row].candidates[slot];
                    m_candidate_rows[offset] := row;
                    m_candidate_pages[offset] := pages[row].page_index;
                    m_candidate_slots[offset] := slot;
                    if (pages[row].page_index = page_index) and
                        (slot = Min(active_slot, High(pages[row].candidates))) then
                        m_selected_index := offset;
                    Inc(offset);
                end;
            end
            else
                for slot := 0 to High(candidates) do
                begin
                    displayed[slot] := candidates[slot];
                    m_candidate_rows[slot] := 0;
                    m_candidate_pages[slot] := page_index;
                    m_candidate_slots[slot] := slot;
                    if slot = Min(active_slot, High(candidates)) then m_selected_index := slot;
                end;
        end;
        if (m_selected_index < 0) and (count > 0) then
            for i := 0 to count - 1 do
                if m_candidate_pages[i] = page_index then
                begin
                    m_selected_index := i;
                    Break;
                end;
        m_show_weight_row := m_debug_mode and (count > 0);
        SetLength(m_candidate_sources, count);
        SetLength(m_candidate_display_kinds, count);
        SetLength(m_candidate_is_user, count);
        SetLength(m_candidate_show_weight, count);

        for i := 0 to count - 1 do
        begin
            if candidate_has_pinyin_tail(displayed[i]) then
            begin
                // A partial candidate is only an anchor for the remaining pinyin.
                // Do not present it as a removable user word, but retain an LM
                // compound marker on the generated Chinese prefix.
                m_candidate_sources[i] := cs_rule;
                m_candidate_display_kinds[i] := displayed[i].display_kind;
            end
            else
            begin
                m_candidate_sources[i] := displayed[i].source;
                m_candidate_display_kinds[i] := displayed[i].display_kind;
            end;
            m_candidate_is_user[i] := candidate_can_remove(displayed[i]);
            m_candidate_show_weight[i] := m_debug_mode and displayed[i].has_dict_weight;
            if m_candidate_show_weight[i] then
            begin
                m_candidate_weight_lines.Add(IntToStr(displayed[i].dict_weight));
            end
            else
            begin
                m_candidate_weight_lines.Add('');
            end;
            m_candidate_lines.Add(format_candidate_text(displayed[i]));
        end;
    finally
        m_candidate_weight_lines.EndUpdate;
        m_candidate_lines.EndUpdate;
    end;

    if c_show_page_label and (page_count > 1) then
    begin
        m_page_label.Caption := format_page_text(page_index, page_count);
        m_show_page_text := True;
    end
    else
    begin
        m_page_label.Caption := '';
        m_show_page_text := False;
    end;
    m_page_label.Visible := False;

    m_preedit_spans := m_preedit_diagnostics.check(preedit_text, pinyin_scheme, quick_input_active);
    if preedit_text <> '' then
    begin
        m_preedit_label.Caption := preedit_text;
        m_show_preedit_text := True;
    end
    else
    begin
        m_preedit_label.Caption := '';
        m_show_preedit_text := False;
    end;
    m_preedit_label.Visible := False;

    if (m_candidate_lines.Count = 0) and
        (m_one_key_completion_text = '') then
    begin
        hide_window;
        Exit;
    end;

    if m_current_dpi <= 0 then
    begin
        apply_current_dpi;
    end;
    update_size;
    Invalidate;
end;

function nc_calculate_candidate_top(const anchor_y: Integer;
    const candidate_height: Integer; const gap: Integer;
    const clearance: Integer; const work_area: TRect;
    const prefer_above: Boolean): Integer;
var
    effective_clearance: Integer;
begin
    effective_clearance := clearance;
    if effective_clearance < gap then
    begin
        effective_clearance := gap;
    end;

    Result := anchor_y;
    if prefer_above then
    begin
        Result := anchor_y - candidate_height - effective_clearance;
        if Result < work_area.Top then
        begin
            Result := anchor_y + effective_clearance;
        end;
    end
    else if Result + candidate_height > work_area.Bottom then
    begin
        Result := anchor_y - candidate_height - gap;
    end;

    if Result < work_area.Top then
    begin
        Result := work_area.Top;
    end
    else if Result + candidate_height > work_area.Bottom then
    begin
        Result := work_area.Bottom - candidate_height;
    end;
end;

procedure TncCandidateWindow.show_at(const x: Integer; const y: Integer;
    const prefer_above: Boolean; const clearance: Integer);
var
    flags: UINT;
    anchor: TPoint;
    work_area: TRect;
    target_x: Integer;
    target_y: Integer;
    dpi: Integer;
    gap: Integer;
    overlay_rect: TRect;
    candidate_rect: TRect;
    target_window: HWND;
    target_rect: TRect;
begin
    HandleNeeded;
    anchor := Point(x, y);
    dpi := m_current_dpi;
    prepare_for_anchor(anchor);
    if dpi <> m_current_dpi then
    begin
        update_size;
        Invalidate;
    end;

    if not get_work_area(anchor, work_area) then
    begin
        work_area := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
    end;

    gap := nc_scale_for_dpi(4, m_current_dpi);
    target_y := nc_calculate_candidate_top(y, Height, gap, clearance,
        work_area, prefer_above);

    target_window := GetForegroundWindow;
    target_rect := Rect(0, 0, 0, 0);
    if (target_window = 0) or (target_window = Handle) or
        IsIconic(target_window) or (not GetWindowRect(target_window, target_rect)) then
    begin
        target_window := 0;
        target_rect := Rect(0, 0, 0, 0);
    end;
    target_x := m_horizontal_placement.update(m_row_count > 1, anchor,
        Width, m_current_dpi, work_area, NativeUInt(target_window), target_rect);

    if get_shell_search_overlay_rect(overlay_rect) then
    begin
        candidate_rect := Rect(target_x, target_y, target_x + Width, target_y + Height);
        if rects_overlap(candidate_rect, overlay_rect) then
        begin
            if overlay_rect.Top - Height - gap >= work_area.Top then
            begin
                target_y := overlay_rect.Top - Height - gap;
            end
            else if overlay_rect.Bottom + gap + Height <= work_area.Bottom then
            begin
                target_y := overlay_rect.Bottom + gap;
            end
            else if overlay_rect.Left - Width - gap >= work_area.Left then
            begin
                target_x := overlay_rect.Left - Width - gap;
                target_y := Max(work_area.Top, Min(target_y, work_area.Bottom - Height));
            end
            else if overlay_rect.Right + gap + Width <= work_area.Right then
            begin
                target_x := overlay_rect.Right + gap;
                target_y := Max(work_area.Top, Min(target_y, work_area.Bottom - Height));
            end;
        end;
    end;

    m_horizontal_placement.left := target_x;

    // Position, size and show atomically. SWP_NOCOPYBITS is important when a
    // hidden 96-DPI surface is first presented on a high-DPI monitor: copying
    // the old client bits can leave stale text at the previous window bounds.
    flags := SWP_NOACTIVATE or SWP_SHOWWINDOW or SWP_NOCOPYBITS;
    SetWindowPos(Handle, HWND_TOPMOST, target_x, target_y, Width, Height, flags);
    RedrawWindow(Handle, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or
        RDW_ALLCHILDREN or RDW_UPDATENOW);
end;

procedure TncCandidateWindow.hide_window;
begin
    m_horizontal_placement := Default(TncCandidateHorizontalPlacement);
    if HandleAllocated then
    begin
        ShowWindow(Handle, SW_HIDE);
        Exit;
    end;

    if Visible then
    begin
        Hide;
    end;
end;

end.
