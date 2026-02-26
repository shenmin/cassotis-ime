unit nc_tray_host;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.IniFiles,
    System.Types,
    System.UITypes,
    Winapi.Windows,
    Winapi.ShellAPI,
    Vcl.Forms,
    Vcl.Menus,
    Vcl.Controls,
    Vcl.StdCtrls,
    Vcl.ExtCtrls,
    Vcl.Graphics,
    nc_config,
    nc_ipc_client,
    nc_types;

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
        m_item_exit: TMenuItem;
        m_timer: TTimer;
        m_config_path: string;
        m_last_write_time: TDateTime;
        m_engine_config: TncEngineConfig;
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
        m_status_label_mode: TLabel;
        m_status_label_variant: TLabel;
        m_status_label_punct: TLabel;
        m_status_btn_settings: TButton;
        m_status_hint_window: THintWindow;
        m_status_dragging: Boolean;
        m_status_drag_moved: Boolean;
        m_status_drag_cursor_origin: TPoint;
        m_status_drag_form_origin: TPoint;
        m_status_drag_source: TObject;
        m_engine_active: Boolean;
        m_active_sync_fail_count: Integer;
        function create_mode_icon(const text: string; const background_color: TColor): TIcon;
        function status_point_in_control(const control: TControl; const screen_point: TPoint): Boolean;
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
        procedure enforce_status_form_toolwindow_style;
        procedure apply_status_widget_visibility;
        procedure refresh_state_from_host;
        procedure load_config;
        procedure save_config;
        procedure update_menu;
        procedure status_mouse_down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
        procedure status_mouse_move(Sender: TObject; Shift: TShiftState; X: Integer; Y: Integer);
        procedure status_mouse_up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
        procedure status_form_close(Sender: TObject; var Action: TCloseAction);
        procedure status_label_mouse_enter(Sender: TObject);
        procedure status_label_mouse_leave(Sender: TObject);
        procedure on_status_widget_click(Sender: TObject);
        procedure on_status_settings_click(Sender: TObject);
        procedure on_input_mode_click(Sender: TObject);
        procedure on_dictionary_variant_click(Sender: TObject);
        procedure on_full_width_click(Sender: TObject);
        procedure on_punct_click(Sender: TObject);
        procedure on_open_config_click(Sender: TObject);
        procedure on_reload_click(Sender: TObject);
        procedure on_exit_click(Sender: TObject);
        procedure on_timer(Sender: TObject);
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

implementation

const
    c_ui_section = 'ui';
    c_status_widget_visible_key = 'status_widget_visible';
    c_status_widget_x_key = 'status_widget_x';
    c_status_widget_y_key = 'status_widget_y';
    c_status_widget_default_width = 260;
    c_status_widget_default_height = 38;
    c_active_sync_fail_hide_threshold = 8;

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
    m_status_label_mode := nil;
    m_status_label_variant := nil;
    m_status_label_punct := nil;
    m_status_btn_settings := nil;
    m_status_hint_window := nil;
    m_status_dragging := False;
    m_status_drag_moved := False;
    m_status_drag_cursor_origin := Point(0, 0);
    m_status_drag_form_origin := Point(0, 0);
    m_status_drag_source := nil;
    m_engine_active := False;
    m_active_sync_fail_count := 0;
    enforce_application_toolwindow_style;
    configure_tray;
    configure_menu;
    configure_status_widget;
    load_config;
    load_status_widget_state;
end;

destructor TncTrayHost.Destroy;
begin
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
    m_icon_chinese_simplified.Free;
    m_icon_chinese_traditional.Free;
    m_icon_english.Free;
    if m_status_hint_window <> nil then
    begin
        m_status_hint_window.Free;
        m_status_hint_window := nil;
    end;
    inherited Destroy;
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
        mask.Canvas.Brush.Color := clWhite;
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
begin
    BorderStyle := bsNone;
    Visible := False;
    enforce_host_form_toolwindow_style;

    m_icon_chinese_simplified := create_mode_icon('简', RGB(30, 144, 255));
    m_icon_chinese_traditional := create_mode_icon('繁', RGB(131, 56, 236));
    m_icon_english := create_mode_icon('A', RGB(96, 96, 96));

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
    m_item_open_config.Caption := '打开配置文件';
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

    m_item_exit := TMenuItem.Create(m_menu);
    m_item_exit.Caption := '退出';
    m_item_exit.OnClick := on_exit_click;
    m_menu.Items.Add(m_item_exit);

    m_tray_icon.PopupMenu := m_menu;

    m_timer := TTimer.Create(Self);
    m_timer.Interval := 120;
    m_timer.OnTimer := on_timer;
    m_timer.Enabled := True;
end;

procedure TncTrayHost.configure_status_widget;
begin
    m_status_form := TncStatusForm.CreateNew(Self);
    m_status_form.BorderStyle := bsNone;
    m_status_form.Position := poDesigned;
    m_status_form.FormStyle := fsStayOnTop;
    m_status_form.Width := c_status_widget_default_width;
    m_status_form.Height := c_status_widget_default_height;
    m_status_form.Color := RGB(32, 32, 32);
    m_status_form.AlphaBlend := False;
    m_status_form.KeyPreview := False;
    m_status_form.PopupMode := pmNone;
    m_status_form.PopupParent := nil;
    m_status_form.DoubleBuffered := True;
    m_status_form.OnClose := status_form_close;

    m_status_panel := TPanel.Create(m_status_form);
    m_status_panel.Parent := m_status_form;
    m_status_panel.Align := alClient;
    m_status_panel.BevelOuter := bvNone;
    m_status_panel.Color := RGB(32, 32, 32);
    m_status_panel.Font.Name := 'Microsoft YaHei UI';
    m_status_panel.ParentBackground := False;

    m_status_label_mode := TLabel.Create(m_status_panel);
    m_status_label_mode.Parent := m_status_panel;
    m_status_label_mode.Left := 10;
    m_status_label_mode.Top := 11;
    m_status_label_mode.Width := 52;
    m_status_label_mode.Height := 16;
    m_status_label_mode.AutoSize := False;
    m_status_label_mode.Alignment := taCenter;
    m_status_label_mode.Layout := tlCenter;
    m_status_label_mode.Font.Color := clWhite;
    m_status_label_mode.Font.Style := [fsBold];
    m_status_label_mode.Transparent := True;
    m_status_label_mode.ParentShowHint := False;
    m_status_label_mode.ShowHint := True;
    m_status_label_mode.Hint := '切换中/英（Shift）';
    m_status_label_mode.Cursor := crHandPoint;

    m_status_label_variant := TLabel.Create(m_status_panel);
    m_status_label_variant.Parent := m_status_panel;
    m_status_label_variant.Left := 72;
    m_status_label_variant.Top := 11;
    m_status_label_variant.Width := 60;
    m_status_label_variant.Height := 16;
    m_status_label_variant.AutoSize := False;
    m_status_label_variant.Alignment := taCenter;
    m_status_label_variant.Layout := tlCenter;
    m_status_label_variant.Font.Color := RGB(180, 220, 255);
    m_status_label_variant.Transparent := True;
    m_status_label_variant.ParentShowHint := False;
    m_status_label_variant.ShowHint := True;
    m_status_label_variant.Hint := '切换简/繁（Ctrl+Shift+T）';
    m_status_label_variant.Cursor := crHandPoint;

    m_status_label_punct := TLabel.Create(m_status_panel);
    m_status_label_punct.Parent := m_status_panel;
    m_status_label_punct.Left := 142;
    m_status_label_punct.Top := 11;
    m_status_label_punct.Width := 64;
    m_status_label_punct.Height := 16;
    m_status_label_punct.AutoSize := False;
    m_status_label_punct.Alignment := taCenter;
    m_status_label_punct.Layout := tlCenter;
    m_status_label_punct.Font.Color := RGB(255, 220, 170);
    m_status_label_punct.Transparent := True;
    m_status_label_punct.ParentShowHint := False;
    m_status_label_punct.ShowHint := True;
    m_status_label_punct.Hint := '切换标点（Ctrl+.）';
    m_status_label_punct.Cursor := crHandPoint;

    m_status_btn_settings := TButton.Create(m_status_panel);
    m_status_btn_settings.Parent := m_status_panel;
    m_status_btn_settings.Left := 214;
    m_status_btn_settings.Top := 7;
    m_status_btn_settings.Width := 40;
    m_status_btn_settings.Height := 24;
    m_status_btn_settings.Caption := '设置';
    m_status_btn_settings.OnClick := on_status_settings_click;
    m_status_btn_settings.TabStop := False;

    m_status_form.OnMouseDown := status_mouse_down;
    m_status_form.OnMouseMove := status_mouse_move;
    m_status_form.OnMouseUp := status_mouse_up;

    m_status_panel.OnMouseDown := status_mouse_down;
    m_status_panel.OnMouseMove := status_mouse_move;
    m_status_panel.OnMouseUp := status_mouse_up;

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

    m_status_label_punct.OnMouseDown := status_mouse_down;
    m_status_label_punct.OnMouseMove := status_mouse_move;
    m_status_label_punct.OnMouseUp := status_mouse_up;
    m_status_label_punct.OnMouseEnter := status_label_mouse_enter;
    m_status_label_punct.OnMouseLeave := status_label_mouse_leave;

    enforce_status_form_toolwindow_style;
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

    if x_value < work_area.Left then
    begin
        x_value := work_area.Left;
    end;
    if y_value < work_area.Top then
    begin
        y_value := work_area.Top;
    end;
    if x_value > work_area.Right - m_status_form.Width then
    begin
        x_value := work_area.Right - m_status_form.Width;
    end;
    if y_value > work_area.Bottom - m_status_form.Height then
    begin
        y_value := work_area.Bottom - m_status_form.Height;
    end;

    m_status_form.Left := x_value;
    m_status_form.Top := y_value;
    m_item_status_widget.Checked := visible_value;
    apply_status_widget_visibility;
    update_status_widget;
end;

procedure TncTrayHost.save_status_widget_state;
var
    ini: TIniFile;
begin
    if (m_status_form = nil) or (m_config_path = '') then
    begin
        Exit;
    end;

    ForceDirectories(ExtractFileDir(m_config_path));
    ini := TIniFile.Create(m_config_path);
    try
        if m_item_status_widget <> nil then
        begin
            ini.WriteBool(c_ui_section, c_status_widget_visible_key, m_item_status_widget.Checked);
        end
        else
        begin
            ini.WriteBool(c_ui_section, c_status_widget_visible_key, m_status_form.Visible);
        end;
        ini.WriteInteger(c_ui_section, c_status_widget_x_key, m_status_form.Left);
        ini.WriteInteger(c_ui_section, c_status_widget_y_key, m_status_form.Top);
    finally
        ini.Free;
    end;
    m_last_write_time := get_config_write_time;
end;

procedure TncTrayHost.update_status_widget;
var
    mode_text: string;
    variant_text: string;
    punct_text: string;
begin
    if m_status_form = nil then
    begin
        Exit;
    end;

    if m_engine_config.input_mode = im_chinese then
    begin
        mode_text := '中文';
        if m_engine_config.dictionary_variant = dv_traditional then
        begin
            variant_text := '繁体';
        end
        else
        begin
            variant_text := '简体';
        end;

        if m_engine_config.punctuation_full_width then
        begin
            punct_text := '标点：中文';
        end
        else
        begin
            punct_text := '标点：英文';
        end;
    end
    else
    begin
        mode_text := '英文';
        variant_text := '-';
        punct_text := '标点：英文';
    end;

    m_status_label_mode.Caption := mode_text;
    m_status_label_variant.Caption := variant_text;
    m_status_label_punct.Caption := punct_text;
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

    should_show := m_item_status_widget.Checked and m_engine_active;
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
            enforce_status_form_toolwindow_style;
            m_status_form.Show;
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
        if status_visible then
        begin
            m_status_form.Hide;
        end;
    end;
end;

procedure TncTrayHost.refresh_state_from_host;
var
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    changed: Boolean;
    active_now: Boolean;
begin
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
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

    changed := (m_engine_config.input_mode <> input_mode) or
        (m_engine_config.full_width_mode <> full_width_mode) or
        (m_engine_config.punctuation_full_width <> punctuation_full_width);
    if not changed then
    begin
        Exit;
    end;

    m_engine_config.input_mode := input_mode;
    m_engine_config.full_width_mode := full_width_mode;
    m_engine_config.punctuation_full_width := punctuation_full_width;
    update_menu;
end;

procedure TncTrayHost.load_config;
var
    config_manager: TncConfigManager;
begin
    config_manager := TncConfigManager.create(m_config_path);
    try
        m_engine_config := config_manager.load_engine_config;
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
    finally
        config_manager.Free;
    end;
    m_last_write_time := get_config_write_time;
    update_menu;
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
    m_item_punct_mode.Checked := m_engine_config.punctuation_full_width;

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
    apply_status_widget_visibility;
    save_status_widget_state;
end;

procedure TncTrayHost.on_status_settings_click(Sender: TObject);
begin
    on_open_config_click(Sender);
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
end;

procedure TncTrayHost.on_dictionary_variant_click(Sender: TObject);
begin
    if m_engine_config.dictionary_variant = dv_traditional then
    begin
        m_engine_config.dictionary_variant := dv_simplified;
    end
    else
    begin
        m_engine_config.dictionary_variant := dv_traditional;
    end;
    save_config;
end;

procedure TncTrayHost.on_full_width_click(Sender: TObject);
begin
    m_engine_config.full_width_mode := not m_engine_config.full_width_mode;
    save_config;
end;

procedure TncTrayHost.on_punct_click(Sender: TObject);
begin
    m_engine_config.punctuation_full_width := not m_engine_config.punctuation_full_width;
    save_config;
end;

procedure TncTrayHost.on_open_config_click(Sender: TObject);
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    if not FileExists(m_config_path) then
    begin
        save_config;
    end;

    ShellExecute(0, 'open', PChar(m_config_path), nil, nil, SW_SHOWNORMAL);
end;

procedure TncTrayHost.on_reload_click(Sender: TObject);
begin
    load_config;
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
begin
    enforce_application_toolwindow_style;
    enforce_host_form_toolwindow_style;
    current_write_time := get_config_write_time;
    if current_write_time <> m_last_write_time then
    begin
        load_config;
    end;
    refresh_state_from_host;
    if (m_status_form <> nil) and m_status_form.Visible then
    begin
        enforce_status_form_toolwindow_style;
    end;
end;

end.
