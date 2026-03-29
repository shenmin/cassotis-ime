unit nc_tray_host;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.IniFiles,
    System.SyncObjs,
    System.Types,
    System.UITypes,
    Winapi.Windows,
    Winapi.Messages,
    Winapi.GDIPAPI,
    Winapi.GDIPOBJ,
    Vcl.Forms,
    Vcl.Menus,
    Vcl.Controls,
    Vcl.StdCtrls,
    Vcl.ExtCtrls,
    Vcl.Graphics,
    nc_config,
    nc_ipc_common,
    nc_ipc_client,
    nc_log,
    nc_settings_form,
    nc_types;

const
    WM_NC_ACTIVE_STATE_CHANGED = WM_APP + 101;
    WM_NC_INACTIVE_STATE_CHANGED = WM_APP + 102;
    WM_NC_OPEN_SETTINGS = WM_APP + 103;

type
    TncTrayHost = class;

    TncStatusForm = class(TForm)
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    end;

    TncTrayHost = class(TForm)
    private
        m_tray_icon: TTrayIcon;
        m_menu: TPopupMenu;
        m_item_input_mode: TMenuItem;
        m_item_dictionary_variant: TMenuItem;
        m_item_full_width: TMenuItem;
        m_item_punct_mode: TMenuItem;
        m_item_status_widget: TMenuItem;
        m_item_open_config: TMenuItem;
        m_item_reload: TMenuItem;
        m_item_version: TMenuItem;
        m_item_exit: TMenuItem;
        m_timer: TTimer;
        m_config_path: string;
        m_last_write_time: TDateTime;
        m_engine_config: TncEngineConfig;
        m_log_config: TncLogConfig;
        m_ipc_client: TncIpcClient;
        m_session_id: string;
        m_icon_chinese_simplified: TIcon;
        m_icon_chinese_traditional: TIcon;
        m_icon_english: TIcon;
        m_last_tray_mode: TncInputMode;
        m_last_tray_variant: TncDictionaryVariant;
        m_tray_state_inited: Boolean;
        m_status_form: TForm;
        m_status_panel: TPanel;
        m_status_logo: TPaintBox;
        m_status_logo_icon: TIcon;
        m_status_logo_bitmap: TGPBitmap;
        m_status_label_mode: TLabel;
        m_status_label_variant: TLabel;
        m_status_label_full_width: TLabel;
        m_status_label_punct: TPaintBox;
        m_status_btn_settings: TncModernButton;
        m_status_hint_window: THintWindow;
        m_status_dragging: Boolean;
        m_status_drag_moved: Boolean;
        m_status_drag_cursor_origin: TPoint;
        m_status_drag_form_origin: TPoint;
        m_status_saved_origin: TPoint;
        m_status_drag_source: TObject;
        m_settings_dialog_open: Boolean;
        m_engine_active: Boolean;
        m_profile_active: Boolean;
        m_profile_active_pending: Boolean;
        m_profile_event_seen: Boolean;
        m_active_sync_fail_count: Integer;
        m_last_state_poll_tick: UInt64;
        m_last_variant_poll_tick: UInt64;
        m_last_config_poll_tick: UInt64;
        m_last_style_refresh_tick: UInt64;
        m_last_profile_activate_tick: UInt64;
        m_active_state_event: TEvent;
        m_inactive_state_event: TEvent;
        m_active_state_thread: TThread;
        m_active_state_shutdown: Boolean;
        m_product_display_name: string;
        m_product_version: string;
        function create_mode_icon(const text: string; const background_color: TColor): TIcon;
        function status_point_in_control(const control: TControl; const screen_point: TPoint): Boolean;
        function get_version_menu_caption: string;
        function get_status_logo_hint: string;
        procedure load_runtime_identity;
        procedure status_logo_paint(Sender: TObject);
        procedure status_punct_paint(Sender: TObject);
        procedure handle_status_label_click(const source: TObject);
        procedure show_status_hint(const control: TControl);
        procedure hide_status_hint;
        procedure enforce_application_toolwindow_style;
        procedure enforce_host_form_toolwindow_style;
        procedure configure_tray;
        procedure configure_menu;
        procedure configure_status_widget;
        function get_config_write_time: TDateTime;
        procedure load_status_widget_state;
        procedure save_status_widget_state;
        procedure update_status_widget;
        procedure refresh_status_widget_frame;
        procedure enforce_status_form_toolwindow_style;
        procedure apply_status_widget_visibility;
        procedure refresh_state_from_host;
        procedure start_active_state_thread;
        procedure stop_active_state_thread;
        procedure load_config;
        procedure save_config;
        procedure apply_settings(const config: TncEngineConfig; const log_config: TncLogConfig;
            const status_widget_visible: Boolean);
        procedure sync_status_widget_origin_from_window;
        function apply_runtime_state_to_host: Boolean;
        function reload_host_config: Boolean;
        procedure show_settings_dialog;
        procedure update_menu;
        procedure status_mouse_down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
        procedure status_mouse_move(Sender: TObject; Shift: TShiftState; X: Integer; Y: Integer);
        procedure status_mouse_up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
        procedure status_form_close(Sender: TObject; var Action: TCloseAction);
        procedure status_label_mouse_enter(Sender: TObject);
        procedure status_label_mouse_leave(Sender: TObject);
        procedure on_status_widget_click(Sender: TObject);
        procedure on_status_settings_mouse_down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer;
            Y: Integer);
        procedure on_status_settings_mouse_up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer;
            Y: Integer);
        procedure on_input_mode_click(Sender: TObject);
        procedure on_dictionary_variant_click(Sender: TObject);
        procedure on_full_width_click(Sender: TObject);
        procedure on_punct_click(Sender: TObject);
        procedure on_open_config_click(Sender: TObject);
        procedure on_reload_click(Sender: TObject);
        procedure on_exit_click(Sender: TObject);
        procedure on_timer(Sender: TObject);
        procedure WMNcActiveStateChanged(var Message: TMessage); message WM_NC_ACTIVE_STATE_CHANGED;
        procedure WMNcInactiveStateChanged(var Message: TMessage); message WM_NC_INACTIVE_STATE_CHANGED;
        procedure WMNcOpenSettings(var Message: TMessage); message WM_NC_OPEN_SETTINGS;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

implementation

const
    c_product_display_name = 'Cassotis IME－言泉输入法';
    c_ui_section = 'ui';
    c_status_widget_visible_key = 'status_widget_visible';
    c_status_widget_x_key = 'status_widget_x';
    c_status_widget_y_key = 'status_widget_y';
    c_status_widget_default_width = 248;
    c_status_widget_default_height = 40;
    c_active_sync_fail_hide_threshold = 8;
    c_tray_timer_interval_ms = 120;
    c_state_poll_interval_ms = 320;
    c_state_poll_interval_idle_ms = 900;
    c_variant_poll_interval_ms = c_state_poll_interval_ms;
    c_config_poll_interval_ms = 1500;
    c_style_refresh_interval_ms = 1500;
    c_style_refresh_interval_idle_ms = 3000;
    c_profile_activate_debounce_ms = 180;

function get_window_dpi(const wnd: HWND): Integer;
begin
    Result := 96;
    if wnd <> 0 then
    begin
        Result := GetDpiForWindow(wnd);
    end;
    if Result <= 0 then
    begin
        Result := Screen.PixelsPerInch;
    end;
    if Result <= 0 then
    begin
        Result := 96;
    end;
end;

function get_control_dpi(const control: TControl): Integer;
var
    win_control: TWinControl;
begin
    Result := Screen.PixelsPerInch;
    if Result <= 0 then
    begin
        Result := 96;
    end;

    if control = nil then
    begin
        Exit;
    end;

    if control is TWinControl then
    begin
        win_control := TWinControl(control);
        if win_control.HandleAllocated then
        begin
            Result := get_window_dpi(win_control.Handle);
            Exit;
        end;
    end;

    if (control.Parent <> nil) and control.Parent.HandleAllocated then
    begin
        Result := get_window_dpi(control.Parent.Handle);
    end;
end;

function scale_int_for_dpi(const value: Integer; const dpi: Integer): Integer;
var
    effective_dpi: Integer;
begin
    effective_dpi := dpi;
    if effective_dpi <= 0 then
    begin
        effective_dpi := 96;
    end;
    Result := MulDiv(value, effective_dpi, 96);
end;

function scale_float_for_dpi(const value: Single; const dpi: Integer): Single;
var
    effective_dpi: Integer;
begin
    effective_dpi := dpi;
    if effective_dpi <= 0 then
    begin
        effective_dpi := 96;
    end;
    Result := value * effective_dpi / 96.0;
end;

function get_display_version_from_exe_file(const exe_path: string): string;
var
    dummy_handle: DWORD;
    info_size: DWORD;
    info_buffer: TBytes;
    fixed_info: PVSFixedFileInfo;
    fixed_info_len: UINT;
    major_ver: Word;
    minor_ver: Word;
    release_ver: Word;
begin
    Result := '';
    if (exe_path = '') or (not FileExists(exe_path)) then
    begin
        Exit;
    end;

    dummy_handle := 0;
    info_size := GetFileVersionInfoSize(PChar(exe_path), dummy_handle);
    if info_size = 0 then
    begin
        Exit;
    end;

    SetLength(info_buffer, info_size);
    if (Length(info_buffer) = 0) or
       (not GetFileVersionInfo(PChar(exe_path), 0, info_size, @info_buffer[0])) then
    begin
        Exit;
    end;

    fixed_info := nil;
    fixed_info_len := 0;
    if (not VerQueryValue(@info_buffer[0], '\', Pointer(fixed_info), fixed_info_len)) or
       (fixed_info = nil) or
       (fixed_info_len < SizeOf(TVSFixedFileInfo)) then
    begin
        Exit;
    end;

    major_ver := HiWord(fixed_info^.dwFileVersionMS);
    minor_ver := LoWord(fixed_info^.dwFileVersionMS);
    release_ver := HiWord(fixed_info^.dwFileVersionLS);
    Result := Format('%d.%d.%d', [major_ver, minor_ver, release_ver]);
end;

function get_shared_product_version: string;
begin
    Result := get_display_version_from_exe_file(ParamStr(0));
end;

procedure set_canvas_font_point_size_for_dpi(const canvas: TCanvas; const point_size: Integer; const dpi: Integer);
begin
    if canvas = nil then
    begin
        Exit;
    end;
    canvas.Font.Height := -MulDiv(point_size, dpi, 72);
end;

procedure TncStatusForm.CreateParams(var Params: TCreateParams);
begin
    inherited;
    Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE) and (not WS_EX_APPWINDOW);
    if Application <> nil then
    begin
        Params.WndParent := Application.Handle;
    end;
end;

procedure TncTrayHost.CreateParams(var Params: TCreateParams);
begin
    inherited;
    Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
end;

constructor TncTrayHost.Create(AOwner: TComponent);
var
    guid: TGUID;
begin
    inherited CreateNew(AOwner);
    m_config_path := get_default_config_path;
    m_last_write_time := 0;
    m_ipc_client := TncIpcClient.create(False);
    m_session_id := '';
    if CreateGUID(guid) = S_OK then
    begin
        m_session_id := GUIDToString(guid);
    end;
    m_icon_chinese_simplified := nil;
    m_icon_chinese_traditional := nil;
    m_icon_english := nil;
    m_last_tray_mode := im_chinese;
    m_last_tray_variant := dv_simplified;
    m_tray_state_inited := False;
    m_status_form := nil;
    m_status_panel := nil;
    m_status_logo := nil;
    m_status_logo_icon := nil;
    m_status_logo_bitmap := nil;
    m_status_label_mode := nil;
    m_status_label_variant := nil;
    m_status_label_full_width := nil;
    m_status_label_punct := nil;
    m_status_btn_settings := nil;
    m_status_hint_window := nil;
    m_item_version := nil;
    m_status_dragging := False;
    m_status_drag_moved := False;
    m_status_drag_cursor_origin := Point(0, 0);
    m_status_drag_form_origin := Point(0, 0);
    m_status_saved_origin := Point(0, 0);
    m_status_drag_source := nil;
    m_settings_dialog_open := False;
    m_engine_active := False;
    m_profile_active := False;
    m_profile_active_pending := False;
    m_profile_event_seen := False;
    m_active_sync_fail_count := 0;
    m_last_state_poll_tick := 0;
    m_last_variant_poll_tick := 0;
    m_last_config_poll_tick := 0;
    m_last_style_refresh_tick := 0;
    m_last_profile_activate_tick := 0;
    m_active_state_event := TEvent.Create(nil, False, False, get_nc_active_event);
    m_inactive_state_event := TEvent.Create(nil, False, False, get_nc_inactive_event);
    m_active_state_thread := nil;
    m_active_state_shutdown := False;
    m_product_display_name := c_product_display_name;
    m_product_version := '';
    load_runtime_identity;
    enforce_application_toolwindow_style;
    configure_tray;
    configure_menu;
    configure_status_widget;
    load_config;
    load_status_widget_state;
    start_active_state_thread;
end;

procedure TncTrayHost.load_runtime_identity;
begin
    m_product_display_name := c_product_display_name;
    m_product_version := get_shared_product_version;
end;

function TncTrayHost.get_version_menu_caption: string;
begin
    Result := '版本：';
    if Trim(m_product_version) <> '' then
    begin
        Result := Result + m_product_version;
    end
    else
    begin
        Result := Result + '未知';
    end;
end;

function TncTrayHost.get_status_logo_hint: string;
begin
    Result := m_product_display_name;
    if Trim(m_product_version) <> '' then
    begin
        Result := Result + sLineBreak + '版本：' + m_product_version;
    end;
end;

destructor TncTrayHost.Destroy;
begin
    stop_active_state_thread;
    if m_status_form <> nil then
    begin
        m_status_form.Free;
        m_status_form := nil;
    end;
    if m_ipc_client <> nil then
    begin
        m_ipc_client.Free;
        m_ipc_client := nil;
    end;
    if m_status_logo_bitmap <> nil then
    begin
        m_status_logo_bitmap.Free;
        m_status_logo_bitmap := nil;
    end;
    if m_status_logo_icon <> nil then
    begin
        m_status_logo_icon.Free;
        m_status_logo_icon := nil;
    end;
    m_icon_chinese_simplified.Free;
    m_icon_chinese_traditional.Free;
    m_icon_english.Free;
    if m_status_hint_window <> nil then
    begin
        m_status_hint_window.Free;
        m_status_hint_window := nil;
    end;
    if m_active_state_event <> nil then
    begin
        m_active_state_event.Free;
        m_active_state_event := nil;
    end;
    if m_inactive_state_event <> nil then
    begin
        m_inactive_state_event.Free;
        m_inactive_state_event := nil;
    end;
    inherited Destroy;
end;

procedure TncTrayHost.status_logo_paint(Sender: TObject);
var
    paint_box: TPaintBox;
    draw_rect: TRect;
    graphics: TGPGraphics;
begin
    if not (Sender is TPaintBox) then
    begin
        Exit;
    end;

    paint_box := TPaintBox(Sender);
    paint_box.Canvas.Brush.Color := m_status_panel.Color;
    paint_box.Canvas.FillRect(paint_box.ClientRect);
    if m_status_logo_bitmap = nil then
    begin
        Exit;
    end;

    draw_rect := paint_box.ClientRect;
    InflateRect(draw_rect, -1, -1);
    graphics := TGPGraphics.Create(paint_box.Canvas.Handle);
    try
        graphics.SetCompositingQuality(CompositingQualityHighQuality);
        graphics.SetInterpolationMode(InterpolationModeHighQualityBicubic);
        graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
        graphics.SetSmoothingMode(SmoothingModeHighQuality);
        graphics.DrawImage(m_status_logo_bitmap, draw_rect.Left, draw_rect.Top,
            draw_rect.Right - draw_rect.Left, draw_rect.Bottom - draw_rect.Top);
    finally
        graphics.Free;
    end;
end;

procedure TncTrayHost.status_punct_paint(Sender: TObject);
var
    paint_box: TPaintBox;
    top_left_text: string;
    draw_rect: TRect;
    graphics: TGPGraphics;
    pen: TGPPen;
    brush: TGPSolidBrush;
    mark_color: TGPColor;
    period_left: Single;
    period_top: Single;
    period_size: Single;
    dpi: Integer;
    show_full_width_punct: Boolean;
begin
    if not (Sender is TPaintBox) then
    begin
        Exit;
    end;

    paint_box := TPaintBox(Sender);
    paint_box.Canvas.Brush.Color := m_status_panel.Color;
    paint_box.Canvas.FillRect(paint_box.ClientRect);
    paint_box.Canvas.Brush.Style := bsClear;
    paint_box.Canvas.Font.Color := RGB(100, 72, 24);
    SetBkMode(paint_box.Canvas.Handle, TRANSPARENT);
    mark_color := MakeColor(255, 100, 72, 24);
    dpi := get_control_dpi(paint_box);
    show_full_width_punct := (m_engine_config.input_mode <> im_english) and
        m_engine_config.punctuation_full_width;

    if show_full_width_punct then
    begin
        top_left_text := '’';
        paint_box.Canvas.Font.Name := 'SimSun';
        draw_rect := Rect(
            scale_int_for_dpi(7, dpi),
            scale_int_for_dpi(6, dpi),
            scale_int_for_dpi(23, dpi),
            scale_int_for_dpi(20, dpi)
        );
    end
    else
    begin
        top_left_text := '''';
        paint_box.Canvas.Font.Name := 'Segoe UI';
        draw_rect := Rect(
            scale_int_for_dpi(4, dpi),
            scale_int_for_dpi(4, dpi),
            scale_int_for_dpi(20, dpi),
            scale_int_for_dpi(18, dpi)
        );
    end;

    set_canvas_font_point_size_for_dpi(paint_box.Canvas, 13, dpi);
    paint_box.Canvas.Font.Style := [];
    DrawText(paint_box.Canvas.Handle, PChar(top_left_text), Length(top_left_text), draw_rect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

    period_left := scale_float_for_dpi(23.0, dpi);
    period_top := scale_float_for_dpi(12.0, dpi);
    period_size := scale_float_for_dpi(4.0, dpi);
    graphics := TGPGraphics.Create(paint_box.Canvas.Handle);
    try
        graphics.SetSmoothingMode(SmoothingModeHighQuality);
        graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
        if show_full_width_punct then
        begin
            pen := TGPPen.Create(mark_color, 1.0);
            try
                graphics.DrawEllipse(pen, period_left, period_top, period_size, period_size);
            finally
                pen.Free;
            end;
        end
        else
        begin
            brush := TGPSolidBrush.Create(mark_color);
            try
                graphics.FillEllipse(brush, period_left, period_top, period_size, period_size);
            finally
                brush.Free;
            end;
        end;
    finally
        graphics.Free;
    end;
end;

function TncTrayHost.create_mode_icon(const text: string; const background_color: TColor): TIcon;
var
    bmp: TBitmap;
    mask: TBitmap;
    icon_info: TIconInfo;
    icon_size: Integer;
    text_rect: TRect;
begin
    Result := TIcon.Create;
    bmp := TBitmap.Create;
    mask := TBitmap.Create;
    try
        icon_size := GetSystemMetrics(SM_CXSMICON);
        if icon_size <= 0 then
        begin
            icon_size := 16;
        end;

        bmp.PixelFormat := pf32bit;
        bmp.SetSize(icon_size, icon_size);
        bmp.AlphaFormat := afIgnored;
        bmp.Canvas.Brush.Color := background_color;
        bmp.Canvas.FillRect(Rect(0, 0, icon_size, icon_size));

        bmp.Canvas.Brush.Style := bsClear;
        bmp.Canvas.Font.Name := 'Microsoft YaHei UI';
        bmp.Canvas.Font.Style := [fsBold];
        bmp.Canvas.Font.Color := clWhite;
        bmp.Canvas.Font.Size := 9;
        SetBkMode(bmp.Canvas.Handle, TRANSPARENT);
        text_rect := Rect(0, 0, icon_size, icon_size);
        DrawText(bmp.Canvas.Handle, PChar(text), Length(text), text_rect,
            DT_CENTER or DT_VCENTER or DT_SINGLELINE);

        mask.Monochrome := True;
        mask.SetSize(icon_size, icon_size);
        // Monochrome icon mask: black means opaque, white means transparent.
        // Use opaque mask to avoid fully transparent tray icons on some shells.
        mask.Canvas.Brush.Color := clBlack;
        mask.Canvas.FillRect(Rect(0, 0, icon_size, icon_size));

        FillChar(icon_info, SizeOf(icon_info), 0);
        icon_info.fIcon := True;
        icon_info.hbmColor := bmp.Handle;
        icon_info.hbmMask := mask.Handle;
        Result.Handle := CreateIconIndirect(icon_info);
    finally
        mask.Free;
        bmp.Free;
    end;
end;

function TncTrayHost.status_point_in_control(const control: TControl; const screen_point: TPoint): Boolean;
var
    client_point: TPoint;
begin
    Result := False;
    if control = nil then
    begin
        Exit;
    end;

    client_point := control.ScreenToClient(screen_point);
    Result := PtInRect(Rect(0, 0, control.Width, control.Height), client_point);
end;

procedure TncTrayHost.handle_status_label_click(const source: TObject);
var
    cursor_point: TPoint;
begin
    cursor_point := Mouse.CursorPos;

    if (source = m_status_label_mode) and status_point_in_control(m_status_label_mode, cursor_point) then
    begin
        on_input_mode_click(m_status_label_mode);
        Exit;
    end;

    if (source = m_status_label_variant) and status_point_in_control(m_status_label_variant, cursor_point) then
    begin
        on_dictionary_variant_click(m_status_label_variant);
        Exit;
    end;

    if (source = m_status_label_full_width) and status_point_in_control(m_status_label_full_width, cursor_point) then
    begin
        on_full_width_click(m_status_label_full_width);
        Exit;
    end;

    if (source = m_status_label_punct) and status_point_in_control(m_status_label_punct, cursor_point) then
    begin
        on_punct_click(m_status_label_punct);
        Exit;
    end;
end;

procedure TncTrayHost.show_status_hint(const control: TControl);
var
    hint_rect: TRect;
    anchor_point: TPoint;
    hint_text: string;
begin
    if control = nil then
    begin
        Exit;
    end;

    hint_text := Trim(control.Hint);
    if hint_text = '' then
    begin
        Exit;
    end;

    if m_status_hint_window = nil then
    begin
        m_status_hint_window := THintWindow.Create(Self);
        m_status_hint_window.Color := clInfoBk;
    end;

    hint_rect := m_status_hint_window.CalcHintRect(280, hint_text, nil);
    anchor_point := control.ClientToScreen(Point(control.Width div 2, control.Height));
    OffsetRect(
        hint_rect,
        anchor_point.X - ((hint_rect.Right - hint_rect.Left) div 2),
        anchor_point.Y + 6
    );
    m_status_hint_window.ActivateHint(hint_rect, hint_text);
end;

procedure TncTrayHost.hide_status_hint;
begin
    if m_status_hint_window <> nil then
    begin
        m_status_hint_window.ReleaseHandle;
    end;
end;

procedure TncTrayHost.configure_tray;
var
    custom_icon: TIcon;
    icon_handle: HICON;
begin
    BorderStyle := bsNone;
    Visible := False;
    enforce_host_form_toolwindow_style;

    m_icon_chinese_simplified := create_mode_icon('简', RGB(30, 144, 255));
    m_icon_chinese_traditional := create_mode_icon('繁', RGB(131, 56, 236));
    m_icon_english := create_mode_icon('A', RGB(96, 96, 96));
    custom_icon := TIcon.Create;
    try
        if (Application <> nil) and (Application.Icon <> nil) and (Application.Icon.Handle <> 0) then
        begin
            custom_icon.Assign(Application.Icon);
        end
        else
        begin
            icon_handle := HICON(
                LoadImage(
                    HInstance,
                    'MAINICON',
                    IMAGE_ICON,
                    GetSystemMetrics(SM_CXSMICON),
                    GetSystemMetrics(SM_CYSMICON),
                    LR_DEFAULTCOLOR
                )
            );
            if icon_handle <> 0 then
            begin
                custom_icon.Handle := icon_handle;
            end;
        end;

        if custom_icon.Handle <> 0 then
        begin
            m_icon_chinese_simplified.Assign(custom_icon);
            m_icon_chinese_traditional.Assign(custom_icon);
            m_icon_english.Assign(custom_icon);
        end;
    finally
        custom_icon.Free;
    end;

    m_tray_icon := TTrayIcon.Create(Self);
    m_tray_icon.Visible := True;
    if (m_icon_chinese_simplified <> nil) and (m_icon_chinese_simplified.Handle <> 0) then
    begin
        m_tray_icon.Icon.Assign(m_icon_chinese_simplified);
    end;
    m_tray_icon.Hint := 'Cassotis IME (中文)';
end;

procedure TncTrayHost.configure_menu;
var
    separator: TMenuItem;
begin
    m_menu := TPopupMenu.Create(Self);
    m_menu.AutoHotkeys := maManual;

    m_item_input_mode := TMenuItem.Create(m_menu);
    m_item_input_mode.OnClick := on_input_mode_click;
    m_menu.Items.Add(m_item_input_mode);

    m_item_dictionary_variant := TMenuItem.Create(m_menu);
    m_item_dictionary_variant.OnClick := on_dictionary_variant_click;
    m_menu.Items.Add(m_item_dictionary_variant);

    m_item_full_width := TMenuItem.Create(m_menu);
    m_item_full_width.OnClick := on_full_width_click;
    m_menu.Items.Add(m_item_full_width);

    m_item_punct_mode := TMenuItem.Create(m_menu);
    m_item_punct_mode.OnClick := on_punct_click;
    m_menu.Items.Add(m_item_punct_mode);

    m_item_status_widget := TMenuItem.Create(m_menu);
    m_item_status_widget.Caption := '显示状态浮窗';
    m_item_status_widget.Checked := True;
    m_item_status_widget.OnClick := on_status_widget_click;
    m_menu.Items.Add(m_item_status_widget);

    separator := TMenuItem.Create(m_menu);
    separator.Caption := '-';
    separator.Enabled := False;
    m_menu.Items.Add(separator);

    m_item_open_config := TMenuItem.Create(m_menu);
    m_item_open_config.Caption := '设置...';
    m_item_open_config.OnClick := on_open_config_click;
    m_menu.Items.Add(m_item_open_config);

    m_item_reload := TMenuItem.Create(m_menu);
    m_item_reload.Caption := '重新加载配置';
    m_item_reload.OnClick := on_reload_click;
    m_menu.Items.Add(m_item_reload);

    separator := TMenuItem.Create(m_menu);
    separator.Caption := '-';
    separator.Enabled := False;
    m_menu.Items.Add(separator);

    m_item_version := TMenuItem.Create(m_menu);
    m_item_version.AutoHotkeys := maManual;
    m_item_version.Caption := get_version_menu_caption;
    m_item_version.Enabled := False;
    m_menu.Items.Add(m_item_version);

    separator := TMenuItem.Create(m_menu);
    separator.Caption := '-';
    separator.Enabled := False;
    m_menu.Items.Add(separator);

    m_item_exit := TMenuItem.Create(m_menu);
    m_item_exit.Caption := '退出';
    m_item_exit.OnClick := on_exit_click;
    m_menu.Items.Add(m_item_exit);

    m_tray_icon.PopupMenu := m_menu;

    m_timer := TTimer.Create(Self);
    m_timer.Interval := c_tray_timer_interval_ms;
    m_timer.OnTimer := on_timer;
    m_timer.Enabled := True;
end;

procedure TncTrayHost.configure_status_widget;
var
    divider: TBevel;
    icon_path: string;
begin
    m_status_form := TncStatusForm.CreateNew(Self);
    m_status_form.BorderStyle := bsNone;
    m_status_form.Position := poDesigned;
    m_status_form.FormStyle := fsStayOnTop;
    m_status_form.Width := c_status_widget_default_width;
    m_status_form.Height := c_status_widget_default_height;
    m_status_form.Color := RGB(190, 196, 204);
    m_status_form.AlphaBlend := False;
    m_status_form.KeyPreview := False;
    m_status_form.PopupMode := pmNone;
    m_status_form.PopupParent := nil;
    m_status_form.DoubleBuffered := True;
    m_status_form.OnClose := status_form_close;

    m_status_panel := TPanel.Create(m_status_form);
    m_status_panel.Parent := m_status_form;
    m_status_panel.Left := 1;
    m_status_panel.Top := 1;
    m_status_panel.Width := m_status_form.ClientWidth - 2;
    m_status_panel.Height := m_status_form.ClientHeight - 2;
    m_status_panel.Anchors := [akLeft, akTop, akRight, akBottom];
    m_status_panel.BevelOuter := bvNone;
    m_status_panel.Color := RGB(226, 231, 237);
    m_status_panel.Font.Name := 'Microsoft YaHei UI';
    m_status_panel.Font.Size := 9;
    m_status_panel.ParentBackground := False;

    m_status_logo_icon := TIcon.Create;
    m_status_logo_bitmap := nil;
    m_status_logo := TPaintBox.Create(m_status_panel);
    m_status_logo.Parent := m_status_panel;
    m_status_logo.Left := 10;
    m_status_logo.Top := 8;
    m_status_logo.Width := 22;
    m_status_logo.Height := 22;
    m_status_logo.ParentShowHint := False;
    m_status_logo.ShowHint := False;
    m_status_logo.Hint := get_status_logo_hint;
    m_status_logo.OnPaint := status_logo_paint;
    icon_path := TPath.GetFullPath(TPath.Combine(TPath.GetDirectoryName(ParamStr(0)),
        '..\cassotis_ime_yanquan.ico'));
    if FileExists(icon_path) then
    begin
        m_status_logo_bitmap := TGPBitmap.Create(icon_path);
    end
    else if (m_tray_icon <> nil) and (m_tray_icon.Icon <> nil) then
    begin
        m_status_logo_icon.Assign(m_tray_icon.Icon);
        if not m_status_logo_icon.Empty then
        begin
            m_status_logo_bitmap := TGPBitmap.Create(m_status_logo_icon.Handle);
        end;
    end;

    m_status_label_mode := TLabel.Create(m_status_panel);
    m_status_label_mode.Parent := m_status_panel;
    m_status_label_mode.Left := 42;
    m_status_label_mode.Top := 11;
    m_status_label_mode.Width := 28;
    m_status_label_mode.Height := 18;
    m_status_label_mode.AutoSize := False;
    m_status_label_mode.Alignment := taCenter;
    m_status_label_mode.Layout := tlCenter;
    m_status_label_mode.Font.Color := RGB(31, 63, 116);
    m_status_label_mode.Font.Style := [fsBold];
    m_status_label_mode.Transparent := True;
    m_status_label_mode.ParentShowHint := False;
    m_status_label_mode.ShowHint := False;
    m_status_label_mode.Hint := '切换中文/英文（Shift）';
    m_status_label_mode.Cursor := crHandPoint;

    divider := TBevel.Create(m_status_panel);
    divider.Parent := m_status_panel;
    divider.Left := 76;
    divider.Top := 11;
    divider.Width := 2;
    divider.Height := 18;
    divider.Shape := bsLeftLine;

    m_status_label_variant := TLabel.Create(m_status_panel);
    m_status_label_variant.Parent := m_status_panel;
    m_status_label_variant.Left := 84;
    m_status_label_variant.Top := 11;
    m_status_label_variant.Width := 24;
    m_status_label_variant.Height := 18;
    m_status_label_variant.AutoSize := False;
    m_status_label_variant.Alignment := taCenter;
    m_status_label_variant.Layout := tlCenter;
    m_status_label_variant.Font.Color := RGB(70, 78, 92);
    m_status_label_variant.Transparent := True;
    m_status_label_variant.ParentShowHint := False;
    m_status_label_variant.ShowHint := False;
    m_status_label_variant.Hint := '切换简体/繁体（Ctrl+Shift+T）';
    m_status_label_variant.Cursor := crHandPoint;

    divider := TBevel.Create(m_status_panel);
    divider.Parent := m_status_panel;
    divider.Left := 114;
    divider.Top := 11;
    divider.Width := 2;
    divider.Height := 18;
    divider.Shape := bsLeftLine;

    m_status_label_full_width := TLabel.Create(m_status_panel);
    m_status_label_full_width.Parent := m_status_panel;
    m_status_label_full_width.Left := 122;
    m_status_label_full_width.Top := 11;
    m_status_label_full_width.Width := 24;
    m_status_label_full_width.Height := 18;
    m_status_label_full_width.AutoSize := False;
    m_status_label_full_width.Alignment := taCenter;
    m_status_label_full_width.Layout := tlCenter;
    m_status_label_full_width.Font.Color := RGB(84, 70, 40);
    m_status_label_full_width.Transparent := True;
    m_status_label_full_width.ParentShowHint := False;
    m_status_label_full_width.ShowHint := False;
    m_status_label_full_width.Hint := '切换全角/半角（Shift+Space）';
    m_status_label_full_width.Cursor := crHandPoint;

    divider := TBevel.Create(m_status_panel);
    divider.Parent := m_status_panel;
    divider.Left := 152;
    divider.Top := 11;
    divider.Width := 2;
    divider.Height := 18;
    divider.Shape := bsLeftLine;

    m_status_label_punct := TPaintBox.Create(m_status_panel);
    m_status_label_punct.Parent := m_status_panel;
    m_status_label_punct.Left := 160;
    m_status_label_punct.Top := 9;
    m_status_label_punct.Width := 40;
    m_status_label_punct.Height := 20;
    m_status_label_punct.ParentShowHint := False;
    m_status_label_punct.ShowHint := False;
    m_status_label_punct.Hint := '切换中文/英文标点（Ctrl+.）';
    m_status_label_punct.Cursor := crHandPoint;
    m_status_label_punct.OnPaint := status_punct_paint;

    m_status_btn_settings := TncModernButton.Create(m_status_panel);
    m_status_btn_settings.Parent := m_status_panel;
    m_status_btn_settings.Left := 208;
    m_status_btn_settings.Top := 8;
    m_status_btn_settings.Width := 30;
    m_status_btn_settings.Height := 24;
    m_status_btn_settings.Caption := #$E713;
    m_status_btn_settings.Font.Name := 'Segoe MDL2 Assets';
    m_status_btn_settings.Font.Size := 10;
    m_status_btn_settings.VisualKind := mbkGhost;
    m_status_btn_settings.GhostBackgroundColor := m_status_panel.Color;
    m_status_btn_settings.ParentShowHint := False;
    m_status_btn_settings.ShowHint := False;
    m_status_btn_settings.Hint := '设置';
    m_status_btn_settings.Cursor := crHandPoint;
    m_status_btn_settings.OnMouseDown := on_status_settings_mouse_down;
    m_status_btn_settings.OnMouseUp := on_status_settings_mouse_up;
    m_status_btn_settings.OnMouseEnter := status_label_mouse_enter;
    m_status_btn_settings.OnMouseLeave := status_label_mouse_leave;
    m_status_btn_settings.TabStop := False;
    m_status_btn_settings.Focusable := False;

    m_status_form.OnMouseDown := status_mouse_down;
    m_status_form.OnMouseMove := status_mouse_move;
    m_status_form.OnMouseUp := status_mouse_up;

    m_status_panel.OnMouseDown := status_mouse_down;
    m_status_panel.OnMouseMove := status_mouse_move;
    m_status_panel.OnMouseUp := status_mouse_up;

    m_status_logo.OnMouseDown := status_mouse_down;
    m_status_logo.OnMouseMove := status_mouse_move;
    m_status_logo.OnMouseUp := status_mouse_up;
    m_status_logo.OnMouseEnter := status_label_mouse_enter;
    m_status_logo.OnMouseLeave := status_label_mouse_leave;

    m_status_label_mode.OnMouseDown := status_mouse_down;
    m_status_label_mode.OnMouseMove := status_mouse_move;
    m_status_label_mode.OnMouseUp := status_mouse_up;
    m_status_label_mode.OnMouseEnter := status_label_mouse_enter;
    m_status_label_mode.OnMouseLeave := status_label_mouse_leave;

    m_status_label_variant.OnMouseDown := status_mouse_down;
    m_status_label_variant.OnMouseMove := status_mouse_move;
    m_status_label_variant.OnMouseUp := status_mouse_up;
    m_status_label_variant.OnMouseEnter := status_label_mouse_enter;
    m_status_label_variant.OnMouseLeave := status_label_mouse_leave;

    m_status_label_full_width.OnMouseDown := status_mouse_down;
    m_status_label_full_width.OnMouseMove := status_mouse_move;
    m_status_label_full_width.OnMouseUp := status_mouse_up;
    m_status_label_full_width.OnMouseEnter := status_label_mouse_enter;
    m_status_label_full_width.OnMouseLeave := status_label_mouse_leave;

    m_status_label_punct.OnMouseDown := status_mouse_down;
    m_status_label_punct.OnMouseMove := status_mouse_move;
    m_status_label_punct.OnMouseUp := status_mouse_up;
    m_status_label_punct.OnMouseEnter := status_label_mouse_enter;
    m_status_label_punct.OnMouseLeave := status_label_mouse_leave;

    enforce_status_form_toolwindow_style;
    refresh_status_widget_frame;
end;

procedure TncTrayHost.enforce_application_toolwindow_style;
var
    ex_style: NativeInt;
begin
    if Application = nil then
    begin
        Exit;
    end;

    ex_style := GetWindowLongPtr(Application.Handle, GWL_EXSTYLE);
    ex_style := (ex_style or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
    SetWindowLongPtr(Application.Handle, GWL_EXSTYLE, ex_style);
    SetWindowPos(
        Application.Handle,
        0,
        0,
        0,
        0,
        0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER or SWP_FRAMECHANGED
    );
end;

procedure TncTrayHost.enforce_host_form_toolwindow_style;
var
    ex_style: NativeInt;
begin
    HandleNeeded;
    ex_style := GetWindowLongPtr(Handle, GWL_EXSTYLE);
    ex_style := (ex_style or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
    SetWindowLongPtr(Handle, GWL_EXSTYLE, ex_style);
    SetWindowPos(
        Handle,
        HWND_TOP,
        0,
        0,
        0,
        0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_FRAMECHANGED
    );
end;

function TncTrayHost.get_config_write_time: TDateTime;
begin
    Result := 0;
    if (m_config_path <> '') and FileExists(m_config_path) then
    begin
        Result := TFile.GetLastWriteTime(m_config_path);
    end;
end;

procedure TncTrayHost.load_status_widget_state;
var
    ini: TIniFile;
    visible_value: Boolean;
    x_value: Integer;
    y_value: Integer;
    work_area: TRect;
    virtual_rect: TRect;
begin
    if m_status_form = nil then
    begin
        Exit;
    end;

    work_area := Screen.WorkAreaRect;
    x_value := work_area.Right - m_status_form.Width - 12;
    y_value := work_area.Bottom - m_status_form.Height - 12;
    visible_value := True;

    if (m_config_path <> '') and FileExists(m_config_path) then
    begin
        ini := TIniFile.Create(m_config_path);
        try
            visible_value := ini.ReadBool(c_ui_section, c_status_widget_visible_key, True);
            x_value := ini.ReadInteger(c_ui_section, c_status_widget_x_key, x_value);
            y_value := ini.ReadInteger(c_ui_section, c_status_widget_y_key, y_value);
        finally
            ini.Free;
        end;
    end;

    virtual_rect := Rect(
        GetSystemMetrics(SM_XVIRTUALSCREEN),
        GetSystemMetrics(SM_YVIRTUALSCREEN),
        GetSystemMetrics(SM_XVIRTUALSCREEN) + GetSystemMetrics(SM_CXVIRTUALSCREEN),
        GetSystemMetrics(SM_YVIRTUALSCREEN) + GetSystemMetrics(SM_CYVIRTUALSCREEN)
    );
    if (virtual_rect.Right <= virtual_rect.Left) or (virtual_rect.Bottom <= virtual_rect.Top) then
    begin
        virtual_rect := work_area;
    end;

    if x_value < virtual_rect.Left then
    begin
        x_value := virtual_rect.Left;
    end;
    if y_value < virtual_rect.Top then
    begin
        y_value := virtual_rect.Top;
    end;
    if x_value > virtual_rect.Right - m_status_form.Width then
    begin
        x_value := virtual_rect.Right - m_status_form.Width;
    end;
    if y_value > virtual_rect.Bottom - m_status_form.Height then
    begin
        y_value := virtual_rect.Bottom - m_status_form.Height;
    end;

    m_status_form.SetBounds(x_value, y_value, m_status_form.Width, m_status_form.Height);
    refresh_status_widget_frame;
    m_status_saved_origin := Point(x_value, y_value);
    m_item_status_widget.Checked := visible_value;
    apply_status_widget_visibility;
    update_status_widget;
end;

procedure TncTrayHost.sync_status_widget_origin_from_window;
var
    window_rect: TRect;
begin
    if m_status_form = nil then
    begin
        Exit;
    end;

    if (m_status_form.HandleAllocated) and GetWindowRect(m_status_form.Handle, window_rect) then
    begin
        m_status_saved_origin := Point(window_rect.Left, window_rect.Top);
    end
    else
    begin
        m_status_saved_origin := Point(m_status_form.Left, m_status_form.Top);
    end;
end;

procedure TncTrayHost.save_status_widget_state;
var
    ini: TIniFile;
    saved_x: Integer;
    saved_y: Integer;
begin
    if (m_status_form = nil) or (m_config_path = '') then
    begin
        Exit;
    end;

    ForceDirectories(ExtractFileDir(m_config_path));
    ini := TIniFile.Create(m_config_path);
    try
        saved_x := m_status_saved_origin.X;
        saved_y := m_status_saved_origin.Y;

        if m_item_status_widget <> nil then
        begin
            ini.WriteBool(c_ui_section, c_status_widget_visible_key, m_item_status_widget.Checked);
        end
        else
        begin
            ini.WriteBool(c_ui_section, c_status_widget_visible_key, m_status_form.Visible);
        end;
        ini.WriteInteger(c_ui_section, c_status_widget_x_key, saved_x);
        ini.WriteInteger(c_ui_section, c_status_widget_y_key, saved_y);
    finally
        ini.Free;
    end;
    m_last_write_time := get_config_write_time;
end;

procedure TncTrayHost.update_status_widget;
var
    mode_text: string;
    variant_text: string;
    full_width_text: string;
begin
    if m_status_form = nil then
    begin
        Exit;
    end;

    if m_engine_config.input_mode = im_chinese then
    begin
        mode_text := '中';
        if m_engine_config.dictionary_variant = dv_traditional then
        begin
            variant_text := '繁';
        end
        else
        begin
            variant_text := '简';
        end;

    end
    else
    begin
        mode_text := '英';
        variant_text := '-';
    end;

    if m_engine_config.full_width_mode then
    begin
        full_width_text := '全';
    end
    else
    begin
        full_width_text := '半';
    end;

    m_status_label_mode.Caption := mode_text;
    m_status_label_variant.Caption := variant_text;
    m_status_label_full_width.Caption := full_width_text;
    m_status_label_punct.Invalidate;
end;

procedure TncTrayHost.refresh_status_widget_frame;
var
    inset: Integer;
    panel_width: Integer;
    panel_height: Integer;
begin
    if (m_status_form = nil) or (m_status_panel = nil) then
    begin
        Exit;
    end;

    inset := 1;
    panel_width := m_status_form.ClientWidth - inset * 2;
    panel_height := m_status_form.ClientHeight - inset * 2;
    if panel_width < 0 then
    begin
        panel_width := 0;
    end;
    if panel_height < 0 then
    begin
        panel_height := 0;
    end;

    if (m_status_panel.Left <> inset) or
        (m_status_panel.Top <> inset) or
        (m_status_panel.Width <> panel_width) or
        (m_status_panel.Height <> panel_height) then
    begin
        m_status_panel.SetBounds(inset, inset, panel_width, panel_height);
        if m_status_label_punct <> nil then
        begin
            m_status_label_punct.Invalidate;
        end;
    end;
end;

procedure TncTrayHost.enforce_status_form_toolwindow_style;
var
    ex_style: NativeInt;
    desired_ex_style: NativeInt;
    parent_hwnd: HWND;
    style_changed: Boolean;
    parent_changed: Boolean;
begin
    if m_status_form = nil then
    begin
        Exit;
    end;

    m_status_form.HandleNeeded;
    parent_hwnd := GetWindowLongPtr(m_status_form.Handle, GWLP_HWNDPARENT);
    parent_changed := (Application <> nil) and (parent_hwnd <> Application.Handle);
    if Application <> nil then
    begin
        if parent_changed then
        begin
            SetWindowLongPtr(m_status_form.Handle, GWLP_HWNDPARENT, NativeInt(Application.Handle));
        end;
    end;
    ex_style := GetWindowLongPtr(m_status_form.Handle, GWL_EXSTYLE);
    desired_ex_style := (ex_style or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE) and (not WS_EX_APPWINDOW);
    style_changed := ex_style <> desired_ex_style;
    if style_changed then
    begin
        SetWindowLongPtr(m_status_form.Handle, GWL_EXSTYLE, desired_ex_style);
    end;

    if style_changed or parent_changed then
    begin
        SetWindowPos(
            m_status_form.Handle,
            HWND_TOPMOST,
            0,
            0,
            0,
            0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_FRAMECHANGED
        );
    end;
end;

procedure TncTrayHost.apply_status_widget_visibility;
var
    should_show: Boolean;
    status_visible: Boolean;
begin
    if (m_status_form = nil) or (m_item_status_widget = nil) then
    begin
        Exit;
    end;

    if m_status_dragging and ((GetAsyncKeyState(VK_LBUTTON) and $8000) = 0) then
    begin
        m_status_dragging := False;
        if GetCapture = m_status_form.Handle then
        begin
            ReleaseCapture;
        end;
    end;

    should_show := m_item_status_widget.Checked and m_engine_active and m_profile_active;
    if m_settings_dialog_open then
    begin
        should_show := False;
    end;
    if m_status_dragging and m_item_status_widget.Checked then
    begin
        // Do not hide during drag on transient active-state flips.
        should_show := True;
    end;

    status_visible := m_status_form.Visible or IsWindowVisible(m_status_form.Handle);

    if should_show then
    begin
        if not status_visible then
        begin
            m_status_form.SetBounds(m_status_saved_origin.X, m_status_saved_origin.Y, m_status_form.Width, m_status_form.Height);
            enforce_status_form_toolwindow_style;
            refresh_status_widget_frame;
            m_status_form.Show;
            refresh_status_widget_frame;
            m_status_form.Update;
        end;
        SetWindowPos(
            m_status_form.Handle,
            HWND_TOPMOST,
            0,
            0,
            0,
            0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER
        );
    end
    else
    begin
        hide_status_hint;
        if status_visible then
        begin
            save_status_widget_state;
            m_status_form.Hide;
        end;
    end;
end;

procedure TncTrayHost.start_active_state_thread;
begin
    if (m_active_state_thread <> nil) or (m_active_state_event = nil) or (m_inactive_state_event = nil) then
    begin
        Exit;
    end;

    m_active_state_shutdown := False;
    m_active_state_thread := TThread.CreateAnonymousThread(
        procedure
        var
            wait_handles: array[0..1] of THandle;
            wait_result: DWORD;
        begin
            wait_handles[0] := m_active_state_event.Handle;
            wait_handles[1] := m_inactive_state_event.Handle;
            while True do
            begin
                wait_result := WaitForMultipleObjects(Length(wait_handles), @wait_handles[0], False, INFINITE);
                if m_active_state_shutdown then
                begin
                    Exit;
                end;
                if HandleAllocated then
                begin
                    case wait_result of
                        WAIT_OBJECT_0:
                            PostMessage(Handle, WM_NC_ACTIVE_STATE_CHANGED, 0, 0);
                        WAIT_OBJECT_0 + 1:
                            PostMessage(Handle, WM_NC_INACTIVE_STATE_CHANGED, 0, 0);
                    end;
                end;
            end;
        end);
    m_active_state_thread.FreeOnTerminate := False;
    m_active_state_thread.Start;
end;

procedure TncTrayHost.stop_active_state_thread;
begin
    m_active_state_shutdown := True;
    if m_active_state_event <> nil then
    begin
        m_active_state_event.SetEvent;
    end;
    if m_inactive_state_event <> nil then
    begin
        m_inactive_state_event.SetEvent;
    end;
    if m_active_state_thread <> nil then
    begin
        m_active_state_thread.WaitFor;
        m_active_state_thread.Free;
        m_active_state_thread := nil;
    end;
end;

procedure TncTrayHost.refresh_state_from_host;
var
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    dictionary_variant: TncDictionaryVariant;
    changed: Boolean;
    active_now: Boolean;
    current_tick: UInt64;
    should_poll_variant: Boolean;
begin
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    current_tick := GetTickCount64;

    if not m_profile_active then
    begin
        if (not m_profile_event_seen) and m_ipc_client.get_active(m_session_id, active_now) and active_now then
        begin
            m_active_sync_fail_count := 0;
            m_profile_active := True;
            m_profile_active_pending := False;
            m_last_profile_activate_tick := 0;
        end
        else
        begin
            if m_engine_active then
            begin
                m_engine_active := False;
                apply_status_widget_visibility;
            end;
            Exit;
        end;
    end;

    active_now := False;
    if m_ipc_client.get_active(m_session_id, active_now) then
    begin
        m_active_sync_fail_count := 0;
        if m_engine_active <> active_now then
        begin
            m_engine_active := active_now;
            apply_status_widget_visibility;
        end;
    end
    else
    begin
        if m_active_sync_fail_count < MaxInt then
        begin
            Inc(m_active_sync_fail_count);
        end;
        if m_engine_active and (m_active_sync_fail_count >= c_active_sync_fail_hide_threshold) then
        begin
            m_engine_active := False;
            apply_status_widget_visibility;
        end;
        Exit;
    end;

    if not m_engine_active then
    begin
        Exit;
    end;

    if not m_ipc_client.get_state(m_session_id, input_mode, full_width_mode, punctuation_full_width) then
    begin
        Exit;
    end;
    should_poll_variant := (m_last_variant_poll_tick = 0) or
        (current_tick - m_last_variant_poll_tick >= c_variant_poll_interval_ms);
    if should_poll_variant then
    begin
        if not m_ipc_client.get_dictionary_variant(m_session_id, dictionary_variant) then
        begin
            dictionary_variant := m_engine_config.dictionary_variant;
        end;
        m_last_variant_poll_tick := current_tick;
    end
    else
    begin
        dictionary_variant := m_engine_config.dictionary_variant;
    end;

    changed := (m_engine_config.input_mode <> input_mode) or
        (m_engine_config.full_width_mode <> full_width_mode) or
        (m_engine_config.punctuation_full_width <> punctuation_full_width) or
        (m_engine_config.dictionary_variant <> dictionary_variant);
    if not changed then
    begin
        Exit;
    end;

    m_engine_config.input_mode := input_mode;
    m_engine_config.full_width_mode := full_width_mode;
    m_engine_config.punctuation_full_width := punctuation_full_width;
    m_engine_config.dictionary_variant := dictionary_variant;
    update_menu;
end;

procedure TncTrayHost.WMNcActiveStateChanged(var Message: TMessage);
begin
    m_profile_event_seen := True;
    m_profile_active_pending := True;
    m_last_profile_activate_tick := GetTickCount64;
    m_last_variant_poll_tick := 0;
    Message.Result := 0;
end;

procedure TncTrayHost.WMNcInactiveStateChanged(var Message: TMessage);
begin
    m_profile_event_seen := True;
    m_profile_active_pending := False;
    m_last_profile_activate_tick := 0;
    m_profile_active := False;
    m_last_variant_poll_tick := 0;
    if m_engine_active then
    begin
        m_engine_active := False;
        apply_status_widget_visibility;
    end;
    m_last_state_poll_tick := 0;
    Message.Result := 0;
end;

procedure TncTrayHost.WMNcOpenSettings(var Message: TMessage);
begin
    if m_settings_dialog_open then
    begin
        Message.Result := 0;
        Exit;
    end;

    m_settings_dialog_open := True;
    try
        show_settings_dialog;
    finally
        m_settings_dialog_open := False;
        m_last_state_poll_tick := 0;
        refresh_state_from_host;
    end;
    Message.Result := 0;
end;

procedure TncTrayHost.load_config;
var
    config_manager: TncConfigManager;
begin
    config_manager := TncConfigManager.create(m_config_path);
    try
        m_engine_config := config_manager.load_engine_config;
        m_log_config := config_manager.load_log_config;
    finally
        config_manager.Free;
    end;

    // Tray default state should start in Chinese mode before first live sync.
    m_engine_config.input_mode := im_chinese;
    m_last_write_time := get_config_write_time;
    update_menu;
end;

procedure TncTrayHost.save_config;
var
    config_manager: TncConfigManager;
begin
    config_manager := TncConfigManager.create(m_config_path);
    try
        config_manager.save_engine_config(m_engine_config);
        config_manager.save_log_config(m_log_config);
    finally
        config_manager.Free;
    end;
    m_last_write_time := get_config_write_time;
    update_menu;
end;

procedure TncTrayHost.apply_settings(const config: TncEngineConfig; const log_config: TncLogConfig;
    const status_widget_visible: Boolean);
begin
    m_engine_config := config;
    m_log_config := log_config;
    save_config;
    if m_item_status_widget <> nil then
    begin
        m_item_status_widget.Checked := status_widget_visible;
    end;
    apply_status_widget_visibility;
    save_status_widget_state;
    reload_host_config;
    apply_runtime_state_to_host;
    refresh_state_from_host;
end;

function TncTrayHost.apply_runtime_state_to_host: Boolean;
begin
    Result := False;
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    Result := m_ipc_client.set_state(m_session_id, m_engine_config.input_mode, m_engine_config.full_width_mode,
        m_engine_config.punctuation_full_width);
end;

function TncTrayHost.reload_host_config: Boolean;
begin
    Result := False;
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    Result := m_ipc_client.reload_config(m_session_id);
end;

procedure TncTrayHost.show_settings_dialog;
var
    next_config: TncEngineConfig;
    next_log_config: TncLogConfig;
    status_widget_visible: Boolean;
begin
    next_config := m_engine_config;
    next_log_config := m_log_config;
    status_widget_visible := (m_item_status_widget <> nil) and m_item_status_widget.Checked;
    if m_status_form <> nil then
    begin
        hide_status_hint;
    end;
    TncSettingsForm.ExecuteDialog(Self, next_config, next_log_config, status_widget_visible,
        procedure(const config: TncEngineConfig; const log_config: TncLogConfig; const next_status_widget_visible: Boolean)
        begin
            apply_settings(config, log_config, next_status_widget_visible);
        end);
end;

procedure TncTrayHost.update_menu;
var
    mode_text: string;
    target_icon: TIcon;
    should_refresh_icon: Boolean;
begin
    target_icon := nil;
    should_refresh_icon := (not m_tray_state_inited) or (m_last_tray_mode <> m_engine_config.input_mode);
    if m_engine_config.input_mode = im_chinese then
    begin
        should_refresh_icon := should_refresh_icon or (m_last_tray_variant <> m_engine_config.dictionary_variant);
    end;

    if m_engine_config.input_mode = im_chinese then
    begin
        mode_text := '中文';
        m_item_input_mode.Caption := '输入模式：中文';
        if (m_engine_config.dictionary_variant = dv_traditional) and
            (m_icon_chinese_traditional <> nil) and (m_icon_chinese_traditional.Handle <> 0) then
        begin
            target_icon := m_icon_chinese_traditional;
        end
        else if (m_icon_chinese_simplified <> nil) and (m_icon_chinese_simplified.Handle <> 0) then
        begin
            target_icon := m_icon_chinese_simplified;
        end;
    end
    else
    begin
        mode_text := '英文';
        m_item_input_mode.Caption := '输入模式：英文';
        if (m_icon_english <> nil) and (m_icon_english.Handle <> 0) then
        begin
            target_icon := m_icon_english;
        end;
    end;

    // Force a tray refresh. Some shells cache icon handles aggressively and
    // may not repaint on plain Assign().
    if should_refresh_icon and (m_tray_icon <> nil) then
    begin
        m_tray_icon.Visible := False;
        if (target_icon <> nil) and (target_icon.Handle <> 0) then
        begin
            m_tray_icon.Icon.Assign(target_icon);
        end;
        m_tray_icon.Hint := 'Cassotis IME (' + mode_text + ')';
        m_tray_icon.Visible := True;
        m_last_tray_mode := m_engine_config.input_mode;
        m_last_tray_variant := m_engine_config.dictionary_variant;
        m_tray_state_inited := True;
    end
    else if m_tray_icon <> nil then
    begin
        m_tray_icon.Hint := 'Cassotis IME (' + mode_text + ')';
    end;

    if m_engine_config.dictionary_variant = dv_traditional then
    begin
        m_item_dictionary_variant.Caption := '词库：繁体中文';
    end
    else
    begin
        m_item_dictionary_variant.Caption := '词库：简体中文';
    end;

    m_item_full_width.Caption := '全角模式';
    m_item_full_width.Checked := m_engine_config.full_width_mode;

    m_item_punct_mode.Caption := '中文标点';
    m_item_punct_mode.Checked := (m_engine_config.input_mode <> im_english) and
        m_engine_config.punctuation_full_width;
    if m_item_version <> nil then
    begin
        m_item_version.Caption := get_version_menu_caption;
    end;

    update_status_widget;
    apply_status_widget_visibility;
end;

procedure TncTrayHost.status_mouse_down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer;
    Y: Integer);
var
    window_rect: TRect;
begin
    if (Button <> mbLeft) or (m_status_form = nil) then
    begin
        Exit;
    end;

    hide_status_hint;
    m_status_dragging := True;
    m_status_drag_moved := False;
    m_status_drag_source := Sender;
    m_status_drag_cursor_origin := Mouse.CursorPos;
    if GetWindowRect(m_status_form.Handle, window_rect) then
    begin
        m_status_drag_form_origin := Point(window_rect.Left, window_rect.Top);
    end
    else
    begin
        m_status_drag_form_origin := Point(m_status_form.Left, m_status_form.Top);
    end;
    SetCapture(m_status_form.Handle);
end;

procedure TncTrayHost.status_mouse_move(Sender: TObject; Shift: TShiftState; X: Integer; Y: Integer);
var
    cursor_point: TPoint;
    delta_x: Integer;
    delta_y: Integer;
begin
    if (not m_status_dragging) or (m_status_form = nil) then
    begin
        Exit;
    end;

    cursor_point := Mouse.CursorPos;
    delta_x := cursor_point.X - m_status_drag_cursor_origin.X;
    delta_y := cursor_point.Y - m_status_drag_cursor_origin.Y;
    if (Abs(delta_x) >= 2) or (Abs(delta_y) >= 2) then
    begin
        m_status_drag_moved := True;
    end;
    SetWindowPos(
        m_status_form.Handle,
        HWND_TOPMOST,
        m_status_drag_form_origin.X + delta_x,
        m_status_drag_form_origin.Y + delta_y,
        0,
        0,
        SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER
    );
end;

procedure TncTrayHost.status_mouse_up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
begin
    if Button <> mbLeft then
    begin
        Exit;
    end;

    if m_status_dragging then
    begin
        m_status_dragging := False;
        if GetCapture = m_status_form.Handle then
        begin
            ReleaseCapture;
        end;
        sync_status_widget_origin_from_window;
        save_status_widget_state;
        if not m_status_drag_moved then
        begin
            handle_status_label_click(m_status_drag_source);
        end;
    end;
    m_status_drag_moved := False;
    m_status_drag_source := nil;
end;

procedure TncTrayHost.status_form_close(Sender: TObject; var Action: TCloseAction);
begin
    hide_status_hint;
    m_status_dragging := False;
    m_status_drag_moved := False;
    m_status_drag_source := nil;
    if (m_status_form <> nil) and (GetCapture = m_status_form.Handle) then
    begin
        ReleaseCapture;
    end;

    Action := caNone;
    if m_status_form <> nil then
    begin
        sync_status_widget_origin_from_window;
        m_status_form.Hide;
    end;
    if m_item_status_widget <> nil then
    begin
        m_item_status_widget.Checked := False;
    end;
    save_status_widget_state;
end;

procedure TncTrayHost.status_label_mouse_enter(Sender: TObject);
begin
    if Sender is TControl then
    begin
        show_status_hint(TControl(Sender));
    end;
end;

procedure TncTrayHost.status_label_mouse_leave(Sender: TObject);
begin
    hide_status_hint;
end;

procedure TncTrayHost.on_status_widget_click(Sender: TObject);
begin
    if (m_status_form = nil) or (m_item_status_widget = nil) then
    begin
        Exit;
    end;

    m_item_status_widget.Checked := not m_item_status_widget.Checked;
    if (m_status_form <> nil) and m_status_form.Visible then
    begin
        sync_status_widget_origin_from_window;
    end;
    apply_status_widget_visibility;
    save_status_widget_state;
end;

procedure TncTrayHost.on_status_settings_mouse_down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer;
    Y: Integer);
var
    control: TControl;
begin
    if Button <> mbLeft then
    begin
        Exit;
    end;

    hide_status_hint;
    if Sender is TControl then
    begin
        control := TControl(Sender);
        if (control is TWinControl) and TWinControl(control).HandleAllocated then
        begin
            SetCapture(TWinControl(control).Handle);
        end;
    end;
end;

procedure TncTrayHost.on_status_settings_mouse_up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer;
    Y: Integer);
var
    control: TControl;
begin
    if GetCapture <> 0 then
    begin
        ReleaseCapture;
    end;

    if Button <> mbLeft then
    begin
        Exit;
    end;

    if not (Sender is TControl) then
    begin
        Exit;
    end;

    control := TControl(Sender);
    if PtInRect(control.ClientRect, Point(X, Y)) then
    begin
        hide_status_hint;
        PostMessage(Handle, WM_NC_OPEN_SETTINGS, 0, 0);
    end;
end;

procedure TncTrayHost.on_input_mode_click(Sender: TObject);
begin
    if m_engine_config.input_mode = im_chinese then
    begin
        m_engine_config.input_mode := im_english;
    end
    else
    begin
        m_engine_config.input_mode := im_chinese;
    end;
    save_config;
    apply_runtime_state_to_host;
    refresh_state_from_host;
end;

procedure TncTrayHost.on_dictionary_variant_click(Sender: TObject);
var
    next_variant: TncDictionaryVariant;
begin
    if m_engine_config.dictionary_variant = dv_traditional then
    begin
        next_variant := dv_simplified;
    end
    else
    begin
        next_variant := dv_traditional;
    end;
    m_engine_config.dictionary_variant := next_variant;
    update_menu;
    if not m_ipc_client.set_dictionary_variant(m_session_id, next_variant) then
    begin
        save_config;
        reload_host_config;
    end;
    refresh_state_from_host;
end;

procedure TncTrayHost.on_full_width_click(Sender: TObject);
begin
    m_engine_config.full_width_mode := not m_engine_config.full_width_mode;
    save_config;
    apply_runtime_state_to_host;
    refresh_state_from_host;
end;

procedure TncTrayHost.on_punct_click(Sender: TObject);
begin
    m_engine_config.punctuation_full_width := not m_engine_config.punctuation_full_width;
    save_config;
    apply_runtime_state_to_host;
    refresh_state_from_host;
end;

procedure TncTrayHost.on_open_config_click(Sender: TObject);
begin
    show_settings_dialog;
end;

procedure TncTrayHost.on_reload_click(Sender: TObject);
begin
    load_config;
    reload_host_config;
    apply_runtime_state_to_host;
    refresh_state_from_host;
end;

procedure TncTrayHost.on_exit_click(Sender: TObject);
begin
    save_status_widget_state;
    Close;
    Application.Terminate;
end;

procedure TncTrayHost.on_timer(Sender: TObject);
var
    current_write_time: TDateTime;
    now_tick: UInt64;
    state_poll_interval: UInt64;
    style_refresh_interval: UInt64;
begin
    now_tick := GetTickCount64;

    if m_profile_active_pending and (m_last_profile_activate_tick <> 0) and
        (now_tick - m_last_profile_activate_tick >= c_profile_activate_debounce_ms) then
    begin
        m_profile_active_pending := False;
        m_profile_active := True;
        m_last_state_poll_tick := 0;
        refresh_state_from_host;
    end;

    if (m_status_form <> nil) and m_status_form.Visible then
    begin
        state_poll_interval := c_tray_timer_interval_ms;
        style_refresh_interval := c_style_refresh_interval_ms;
    end
    else if m_engine_active then
    begin
        state_poll_interval := c_state_poll_interval_ms;
        style_refresh_interval := c_style_refresh_interval_ms;
    end
    else
    begin
        state_poll_interval := c_state_poll_interval_idle_ms;
        style_refresh_interval := c_style_refresh_interval_idle_ms;
    end;

    if (m_last_style_refresh_tick = 0) or (now_tick - m_last_style_refresh_tick >= style_refresh_interval) then
    begin
        enforce_application_toolwindow_style;
        enforce_host_form_toolwindow_style;
        if (m_status_form <> nil) and m_status_form.Visible then
        begin
            enforce_status_form_toolwindow_style;
            refresh_status_widget_frame;
        end;
        m_last_style_refresh_tick := now_tick;
    end;

    if (m_last_config_poll_tick = 0) or (now_tick - m_last_config_poll_tick >= c_config_poll_interval_ms) then
    begin
        current_write_time := get_config_write_time;
        if current_write_time <> m_last_write_time then
        begin
            load_config;
        end;
        m_last_config_poll_tick := now_tick;
    end;

    if (m_last_state_poll_tick = 0) or (now_tick - m_last_state_poll_tick >= state_poll_interval) then
    begin
        refresh_state_from_host;
        m_last_state_poll_tick := now_tick;
    end;
end;

end.
