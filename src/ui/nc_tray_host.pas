unit nc_tray_host;

interface

uses
    System.SysUtils,
    System.IOUtils,
    Winapi.Windows,
    Winapi.ShellAPI,
    Vcl.Forms,
    Vcl.Menus,
    Vcl.ExtCtrls,
    nc_config,
    nc_types;

type
    TncTrayHost = class(TForm)
    private
        m_tray_icon: TTrayIcon;
        m_menu: TPopupMenu;
        m_item_input_mode: TMenuItem;
        m_item_dictionary_variant: TMenuItem;
        m_item_full_width: TMenuItem;
        m_item_punct_mode: TMenuItem;
        m_item_open_config: TMenuItem;
        m_item_reload: TMenuItem;
        m_item_exit: TMenuItem;
        m_timer: TTimer;
        m_config_path: string;
        m_last_write_time: TDateTime;
        m_engine_config: TncEngineConfig;
        procedure configure_tray;
        procedure configure_menu;
        function get_config_write_time: TDateTime;
        procedure load_config;
        procedure save_config;
        procedure update_menu;
        procedure on_input_mode_click(Sender: TObject);
        procedure on_dictionary_variant_click(Sender: TObject);
        procedure on_full_width_click(Sender: TObject);
        procedure on_punct_click(Sender: TObject);
        procedure on_open_config_click(Sender: TObject);
        procedure on_reload_click(Sender: TObject);
        procedure on_exit_click(Sender: TObject);
        procedure on_timer(Sender: TObject);
    public
        constructor create; reintroduce;
    end;

implementation

constructor TncTrayHost.create;
begin
    inherited CreateNew(nil);
    m_config_path := get_default_config_path;
    m_last_write_time := 0;
    configure_tray;
    configure_menu;
    load_config;
end;

procedure TncTrayHost.configure_tray;
begin
    BorderStyle := bsNone;
    Visible := False;

    m_tray_icon := TTrayIcon.Create(Self);
    m_tray_icon.Visible := True;
    m_tray_icon.Hint := 'Cassotis IME';
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
    m_timer.Interval := 2000;
    m_timer.OnTimer := on_timer;
    m_timer.Enabled := True;
end;

function TncTrayHost.get_config_write_time: TDateTime;
begin
    Result := 0;
    if (m_config_path <> '') and FileExists(m_config_path) then
    begin
        Result := TFile.GetLastWriteTime(m_config_path);
    end;
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
begin
    if m_engine_config.input_mode = im_chinese then
    begin
        m_item_input_mode.Caption := '输入模式：中文';
    end
    else
    begin
        m_item_input_mode.Caption := '输入模式：英文';
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
    Close;
    Application.Terminate;
end;

procedure TncTrayHost.on_timer(Sender: TObject);
var
    current_write_time: TDateTime;
begin
    current_write_time := get_config_write_time;
    if current_write_time > m_last_write_time then
    begin
        load_config;
    end;
end;

end.
