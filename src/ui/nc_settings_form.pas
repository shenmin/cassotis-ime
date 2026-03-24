unit nc_settings_form;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.Types,
    System.UITypes,
    Winapi.Windows,
    Winapi.Messages,
    Winapi.ShellAPI,
    Vcl.Forms,
    Vcl.Controls,
    Vcl.StdCtrls,
    Vcl.ComCtrls,
    Vcl.ExtCtrls,
    Vcl.Graphics,
    Vcl.Dialogs,
    Vcl.FileCtrl,
    nc_types,
    nc_config,
    nc_log;

type
    TncModernButtonKind = (
        mbkPrimary,
        mbkSecondary,
        mbkSubtle
    );

    TncModernButton = class(TCustomControl)
    private
        m_kind: TncModernButtonKind;
        m_caption: string;
        m_hot: Boolean;
        m_pressed: Boolean;
        m_default_button: Boolean;
        m_cancel_button: Boolean;
        m_focusable: Boolean;
        procedure set_caption(const value: string);
        procedure set_kind(const value: TncModernButtonKind);
        procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
        procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
        procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    protected
        procedure Paint; override;
        procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer); override;
        procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer); override;
        procedure KeyDown(var Key: Word; Shift: TShiftState); override;
        procedure KeyUp(var Key: Word; Shift: TShiftState); override;
        procedure DoEnter; override;
        procedure DoExit; override;
    public
        constructor Create(AOwner: TComponent); override;
    published
        property Caption: string read m_caption write set_caption;
        property Default: Boolean read m_default_button write m_default_button default False;
        property Cancel: Boolean read m_cancel_button write m_cancel_button default False;
        property Focusable: Boolean read m_focusable write m_focusable default True;
        property VisualKind: TncModernButtonKind read m_kind write set_kind;
        property Align;
        property Anchors;
        property Enabled;
        property Font;
        property ParentFont;
        property ParentShowHint;
        property ShowHint;
        property Hint;
        property Cursor;
        property TabOrder;
        property TabStop;
        property Visible;
        property OnClick;
        property OnMouseDown;
        property OnMouseMove;
        property OnMouseUp;
        property OnMouseEnter;
        property OnMouseLeave;
    end;

    TncModernCheckBox = class(TCustomControl)
    private
        m_caption: string;
        m_checked: Boolean;
        m_hot: Boolean;
        m_pressed: Boolean;
        procedure set_caption(const value: string);
        procedure set_checked(const value: Boolean);
        procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
        procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
        procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    protected
        procedure Paint; override;
        procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer); override;
        procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer); override;
        procedure KeyDown(var Key: Word; Shift: TShiftState); override;
        procedure DoEnter; override;
        procedure DoExit; override;
    public
        constructor Create(AOwner: TComponent); override;
    published
        property Caption: string read m_caption write set_caption;
        property Checked: Boolean read m_checked write set_checked default False;
        property Align;
        property Anchors;
        property Enabled;
        property Font;
        property ParentFont;
        property ParentShowHint;
        property ShowHint;
        property Hint;
        property Cursor;
        property TabOrder;
        property TabStop;
        property Visible;
        property OnClick;
        property OnMouseDown;
        property OnMouseMove;
        property OnMouseUp;
        property OnMouseEnter;
        property OnMouseLeave;
    end;

    TncFlatPageControl = class(TPageControl)
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    end;

    TncApplySettingsProc = reference to procedure(const engine_config: TncEngineConfig;
        const log_config: TncLogConfig; const status_widget_visible: Boolean);

    TncSettingsForm = class(TForm)
    private
        m_page_control: TncFlatPageControl;
        m_tab_general: TTabSheet;
        m_tab_logging: TTabSheet;
        m_tab_advanced: TTabSheet;
        m_btn_reset: TncModernButton;
        m_btn_apply: TncModernButton;
        m_btn_ok: TncModernButton;
        m_btn_cancel: TncModernButton;
        m_combo_input_mode: TComboBox;
        m_combo_punctuation_mode: TComboBox;
        m_chk_full_width_mode: TncModernCheckBox;
        m_chk_show_status_widget: TncModernCheckBox;
        m_chk_log_enabled: TncModernCheckBox;
        m_combo_log_level: TComboBox;
        m_edit_log_max_size_kb: TEdit;
        m_edit_log_path: TEdit;
        m_btn_log_path: TncModernButton;
        m_btn_open_log_folder: TncModernButton;
        m_btn_log_defaults: TncModernButton;
        m_chk_debug_mode: TncModernCheckBox;
        m_btn_open_config_folder: TncModernButton;
        m_btn_open_config_file: TncModernButton;
        m_hint_advanced: TLabel;
        m_engine_config: TncEngineConfig;
        m_log_config: TncLogConfig;
        m_status_widget_visible: Boolean;
        m_apply_proc: TncApplySettingsProc;
        m_dirty: Boolean;
        m_applied: Boolean;
        procedure configure_form;
        procedure configure_tabs;
        procedure configure_buttons;
        procedure update_dialog_height_for_content;
        procedure add_general_controls;
        procedure add_logging_controls;
        procedure add_advanced_controls;
        procedure update_scaled_control_metrics;
        procedure mark_dirty(Sender: TObject);
        procedure update_apply_button;
        procedure update_logging_controls;
        procedure load_defaults;
        procedure load_from_config;
        function browse_for_save_file(const title: string; const filter: string; const default_ext: string;
            var path: string): Boolean;
        procedure assign_path_edit(const edit: TEdit; const path: string);
        procedure configure_numeric_edit(const edit: TEdit; const hint: string);
        procedure configure_path_edit(const edit: TEdit; const hint: string);
        function open_folder_for_path(const path_text: string; const caption: string): Boolean;
        function read_integer_setting(const edit: TEdit; const default_value: Integer;
            const min_value: Integer; const max_value: Integer; const setting_name: string;
            out value: Integer; out error_text: string): Boolean;
        function build_config_from_controls(out next_config: TncEngineConfig; out next_log_config: TncLogConfig;
            out next_status_widget_visible: Boolean; out error_text: string): Boolean;
        procedure on_browse_log_path(Sender: TObject);
        procedure on_open_log_folder(Sender: TObject);
        procedure on_log_defaults_click(Sender: TObject);
        procedure on_open_config_folder(Sender: TObject);
        procedure on_open_config_file(Sender: TObject);
        procedure on_reset_click(Sender: TObject);
        procedure apply_changes;
        procedure on_apply_click(Sender: TObject);
        procedure on_ok_click(Sender: TObject);
        procedure on_cancel_click(Sender: TObject);
        procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    protected
        procedure DoShow; override;
    public
        constructor Create(AOwner: TComponent); override;
        class function ExecuteDialog(const owner: TComponent; var config: TncEngineConfig; var log_config: TncLogConfig;
            var status_widget_visible: Boolean; const on_apply: TncApplySettingsProc): Boolean; static;
    end;

implementation

const
    c_dialog_width = 596;
    c_dialog_height = 452;
    c_page_margin = 10;
    c_footer_height = 50;
    c_section_left = 12;
    c_section_width = c_dialog_width - 62;
    c_section_gap = 12;
    c_section_inner_top = 34;
    c_label_left = 18;
    c_control_left = 148;
    c_row_height = 30;
    c_row_gap = 10;
    c_edit_width = 120;
    c_combo_width = 172;
    c_path_edit_width = 248;
    c_browse_button_gap = 8;
    c_browse_button_width = 60;
    c_action_button_width = 104;
    c_button_height = 26;
    c_footer_button_height = 30;
    c_check_width = c_section_width - c_label_left - 20;
    c_hint_width = c_section_width - (c_label_left * 2);
    c_general_row_gap = 8;

resourcestring
    SSettingsTitle = 'Cassotis 设置';
    STabGeneral = '常规';
    STabLogging = '日志';
    STabAdvanced = '高级';
    SButtonBrowse = '浏览';
    SButtonDefaults = '恢复默认';
    SButtonApply = '应用';
    SButtonOK = '确定';
    SButtonCancel = '取消';
    SGroupDefaultBehavior = '输入';
    SGroupAppearance = '外观';
    SGroupLogging = '记录策略';
    SGroupLogFiles = '文件位置';
    SGroupDebug = '调试';
    SGroupDictionaryPaths = '词库路径';
    SGroupConfigTools = '配置工具';
    SLabelInputMode = '语言';
    SOptionChinese = '中文';
    SOptionEnglish = '英文';
    SOptionSimplifiedChineseInput = '简体中文输入';
    SOptionTraditionalChineseInput = '繁体中文输入';
    SOptionEnglishInput = '英文输入';
    SLabelPunctuationMode = '标点';
    SCheckFullWidthMode = '使用全角输入';
    SCheckShowStatusWidget = '显示状态浮窗';
    SCheckEnableLogging = '启用日志';
    SLabelLogLevel = '日志级别';
    SOptionLogDebug = '调试';
    SOptionLogInfo = '信息';
    SOptionLogWarn = '警告';
    SOptionLogError = '错误';
    SLabelMaxLogSize = '日志大小上限（KB）';
    SLabelLogPath = '日志路径';
    SButtonOpenLogFolder = '打开日志目录';
    SButtonUseDefaultLogging = '恢复默认日志';
    SCheckEnableDebugMode = '启用调试模式';
    SHintDebugMode = '开启后，候选栏中的候选词和单字将显示权重信息，仅用于调试和问题排查。';
    SLabelSimplifiedDictionary = '简体词库';
    SLabelTraditionalDictionary = '繁体词库';
    SLabelUserDictionary = '用户词库';
    SButtonUseDefaultDictionaries = '恢复默认词库路径';
    SButtonOpenDictionaryFolder = '打开词库目录';
    SButtonOpenConfigFolder = '打开配置目录';
    SButtonOpenConfigFile = '打开配置文件';
    SHintAdvanced = '可直接打开配置目录和当前配置文件。';
    SPathEditHint = '留空表示使用内置默认路径。';
    SPathEmpty = '%s为空。';
    SPathMissing = '%s不存在。';
    SConfigFolderMissing = '配置目录不存在。';
    SConfigFileMissing = '配置文件尚不存在。';
    SConfirmRestoreDefaults = '要恢复默认设置吗？';
    SSettingMaxLogSize = '日志大小上限';
    SErrorValueTooSmall = '%s不能小于 %d。';
    SErrorValueTooLarge = '%s不能大于 %d。';
    SDialogSelectLogFile = '选择日志文件';
    SDialogSelectSimplifiedDictionary = '选择简体词库';
    SDialogSelectTraditionalDictionary = '选择繁体词库';
    SDialogSelectUserDictionary = '选择用户词库文件';
    SFilterLogFiles = '日志文件|*.log;*.txt|所有文件|*.*';
    SFilterDictionaryFiles = '词库文件|*.db;*.sqlite|所有文件|*.*';
    SFilterDatabaseFiles = '数据库文件|*.db;*.sqlite|所有文件|*.*';
    SCurrentLogFolder = '当前日志目录';
    SCurrentDictionaryPath = '当前词库路径';

function get_ui_scale_dpi: Integer; forward;
function scale_ui(const value: Integer): Integer; forward;
function measure_font_height(const font: TFont): Integer; forward;
function calculate_checkbox_height(const font: TFont): Integer; forward;
function get_window_dpi(const wnd: HWND): Integer; forward;
function get_control_scale_dpi(const control: TControl): Integer; forward;
function scale_ui_for_dpi(const value: Integer; const dpi: Integer): Integer; forward;
function calculate_checkbox_height_for_dpi(const font: TFont; const dpi: Integer): Integer; forward;

constructor TncModernButton.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    m_kind := mbkSecondary;
    m_caption := '';
    m_focusable := True;
    ParentFont := True;
    Font.Name := 'Microsoft YaHei UI';
    Font.Size := 9;
    Height := c_button_height;
    Width := 80;
    TabStop := True;
    DoubleBuffered := True;
end;

procedure TncModernButton.set_caption(const value: string);
begin
    if m_caption = value then
    begin
        Exit;
    end;
    m_caption := value;
    Invalidate;
end;

procedure TncModernButton.set_kind(const value: TncModernButtonKind);
begin
    if m_kind = value then
    begin
        Exit;
    end;
    m_kind := value;
    Invalidate;
end;

procedure TncModernButton.CMMouseEnter(var Message: TMessage);
begin
    inherited;
    m_hot := True;
    Invalidate;
end;

procedure TncModernButton.CMMouseLeave(var Message: TMessage);
begin
    inherited;
    m_hot := False;
    Invalidate;
end;

procedure TncModernButton.CMEnabledChanged(var Message: TMessage);
begin
    inherited;
    Invalidate;
end;

procedure TncModernButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
begin
    inherited;
    if Button = mbLeft then
    begin
        if m_focusable then
        begin
            SetFocus;
        end;
        m_pressed := True;
    end;
    Invalidate;
end;

procedure TncModernButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
begin
    inherited;
    if Button = mbLeft then
    begin
        m_pressed := False;
        if PtInRect(ClientRect, Point(X, Y)) and Enabled then
        begin
            Click;
        end;
    end;
    Invalidate;
end;

procedure TncModernButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
    inherited;
    if (Key = VK_SPACE) or (Key = VK_RETURN) then
    begin
        m_pressed := True;
        Invalidate;
    end;
end;

procedure TncModernButton.KeyUp(var Key: Word; Shift: TShiftState);
begin
    inherited;
    if ((Key = VK_SPACE) or (Key = VK_RETURN)) and Enabled then
    begin
        m_pressed := False;
        Invalidate;
        Click;
    end;
end;

procedure TncModernButton.DoEnter;
begin
    inherited;
    Invalidate;
end;

procedure TncModernButton.DoExit;
begin
    inherited;
    m_pressed := False;
    Invalidate;
end;

procedure TncModernButton.Paint;
var
    draw_rect: TRect;
    text_rect: TRect;
    background_color: TColor;
    border_color: TColor;
    text_color: TColor;
    border_width: Integer;
    is_disabled: Boolean;
    corner_size: Integer;
begin
    is_disabled := not Enabled;

    case m_kind of
        mbkPrimary:
            begin
                background_color := RGB(50, 118, 255);
                border_color := RGB(50, 118, 255);
                text_color := clWhite;
                if m_hot then
                begin
                    background_color := RGB(35, 104, 245);
                    border_color := background_color;
                end;
                if m_pressed then
                begin
                    background_color := RGB(28, 93, 224);
                    border_color := background_color;
                end;
                if is_disabled then
                begin
                    background_color := RGB(202, 216, 241);
                    border_color := RGB(202, 216, 241);
                    text_color := RGB(244, 247, 253);
                end;
            end;
        mbkSubtle:
            begin
                background_color := RGB(245, 247, 250);
                border_color := RGB(220, 225, 232);
                text_color := RGB(70, 78, 90);
                if m_hot then
                begin
                    background_color := RGB(236, 241, 249);
                    border_color := RGB(200, 210, 224);
                end;
                if m_pressed then
                begin
                    background_color := RGB(226, 232, 242);
                    border_color := RGB(184, 195, 211);
                end;
                if is_disabled then
                begin
                    background_color := RGB(248, 249, 251);
                    border_color := RGB(230, 234, 239);
                    text_color := RGB(180, 186, 194);
                end;
            end;
    else
        begin
            background_color := clWhite;
            border_color := RGB(208, 215, 226);
            text_color := RGB(48, 55, 66);
            if m_hot then
            begin
                background_color := RGB(244, 248, 255);
                border_color := RGB(120, 159, 232);
                text_color := RGB(32, 80, 168);
            end;
            if m_pressed then
            begin
                background_color := RGB(232, 240, 254);
                border_color := RGB(92, 136, 219);
                text_color := RGB(24, 72, 156);
            end;
            if is_disabled then
            begin
                background_color := RGB(250, 251, 252);
                border_color := RGB(228, 232, 238);
                text_color := RGB(186, 191, 198);
            end;
        end;
    end;

    border_width := 1;
    corner_size := 10;
    if m_default_button and (not is_disabled) then
    begin
        border_width := 2;
    end;

    draw_rect := ClientRect;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := background_color;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := border_color;
    Canvas.Pen.Width := border_width;
    Canvas.RoundRect(draw_rect.Left, draw_rect.Top, draw_rect.Right, draw_rect.Bottom, corner_size, corner_size);

    text_rect := draw_rect;
    if m_pressed then
    begin
        OffsetRect(text_rect, 0, 1);
    end;

    Canvas.Brush.Style := bsClear;
    Canvas.Font.Assign(Font);
    Canvas.Font.Color := text_color;
    DrawText(
        Canvas.Handle,
        PChar(m_caption),
        Length(m_caption),
        text_rect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX
    );

    if m_focusable and Focused and (not is_disabled) then
    begin
        InflateRect(draw_rect, -4, -4);
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Style := psDot;
        Canvas.Pen.Width := 1;
        Canvas.Pen.Color := RGB(132, 146, 166);
        Canvas.RoundRect(draw_rect.Left, draw_rect.Top, draw_rect.Right, draw_rect.Bottom, 6, 6);
    end;
end;

constructor TncModernCheckBox.Create(AOwner: TComponent);
begin
    inherited Create(AOwner);
    m_caption := '';
    m_checked := False;
    ParentFont := True;
    Font.Name := 'Microsoft YaHei UI';
    Font.Size := 9;
    Width := c_check_width;
    Height := 24;
    TabStop := True;
    DoubleBuffered := True;
    Cursor := crHandPoint;
end;

procedure TncModernCheckBox.set_caption(const value: string);
begin
    if m_caption = value then
    begin
        Exit;
    end;
    m_caption := value;
    Invalidate;
end;

procedure TncModernCheckBox.set_checked(const value: Boolean);
begin
    if m_checked = value then
    begin
        Exit;
    end;
    m_checked := value;
    Invalidate;
end;

procedure TncModernCheckBox.CMMouseEnter(var Message: TMessage);
begin
    inherited;
    m_hot := True;
    Invalidate;
end;

procedure TncModernCheckBox.CMMouseLeave(var Message: TMessage);
begin
    inherited;
    m_hot := False;
    Invalidate;
end;

procedure TncModernCheckBox.CMEnabledChanged(var Message: TMessage);
begin
    inherited;
    Invalidate;
end;

procedure TncModernCheckBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
begin
    inherited;
    if Button = mbLeft then
    begin
        SetFocus;
        m_pressed := True;
        Invalidate;
    end;
end;

procedure TncModernCheckBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer);
begin
    inherited;
    if Button = mbLeft then
    begin
        if m_pressed and PtInRect(ClientRect, Point(X, Y)) and Enabled then
        begin
            m_checked := not m_checked;
            Click;
        end;
        m_pressed := False;
        Invalidate;
    end;
end;

procedure TncModernCheckBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
    inherited;
    if (Key = VK_SPACE) and Enabled then
    begin
        m_checked := not m_checked;
        Click;
        Invalidate;
        Key := 0;
    end;
end;

procedure TncModernCheckBox.DoEnter;
begin
    inherited;
    Invalidate;
end;

procedure TncModernCheckBox.DoExit;
begin
    inherited;
    m_pressed := False;
    Invalidate;
end;

procedure TncModernCheckBox.Paint;
var
    draw_rect: TRect;
    glyph_rect: TRect;
    text_rect: TRect;
    focus_rect: TRect;
    dpi: Integer;
    box_size: Integer;
    glyph_width: Integer;
    glyph_text: string;
    text_color: TColor;
    glyph_color: TColor;
    glyph_font: TFont;
begin
    draw_rect := ClientRect;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(draw_rect);

    dpi := get_control_scale_dpi(Self);
    box_size := scale_ui_for_dpi(16, dpi);
    if box_size < 16 then
    begin
        box_size := 16;
    end;
    glyph_width := box_size + scale_ui_for_dpi(6, dpi);

    if not Enabled then
    begin
        text_color := RGB(171, 176, 184);
        glyph_color := RGB(171, 176, 184);
    end
    else if m_checked then
    begin
        text_color := RGB(44, 50, 59);
        glyph_color := RGB(50, 118, 255);
        if m_hot then
        begin
            glyph_color := RGB(35, 104, 245);
        end;
    end
    else
    begin
        text_color := RGB(44, 50, 59);
        glyph_color := RGB(112, 122, 136);
        if m_hot then
        begin
            glyph_color := RGB(90, 129, 212);
        end;
    end;

    if m_pressed and Enabled then
    begin
        if m_checked then
        begin
            glyph_color := RGB(28, 93, 224);
        end
        else
        begin
            glyph_color := RGB(84, 122, 204);
        end;
    end;

    glyph_text := '☐';
    if m_checked then
    begin
        glyph_text := '☑';
    end;

    glyph_rect := Rect(0, 0, glyph_width, Height);
    Canvas.Brush.Style := bsClear;
    glyph_font := TFont.Create;
    try
        glyph_font.Assign(Font);
        glyph_font.Name := 'Segoe UI Symbol';
        glyph_font.Height := -scale_ui_for_dpi(18, dpi);
        Canvas.Font.Assign(glyph_font);
        Canvas.Font.Color := glyph_color;
        DrawText(Canvas.Handle, PChar(glyph_text), Length(glyph_text), glyph_rect,
            DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    finally
        glyph_font.Free;
    end;

    text_rect := Rect(glyph_rect.Right + scale_ui_for_dpi(4, dpi), 0, Width, Height);
    Canvas.Font.Assign(Font);
    Canvas.Font.Color := text_color;
    DrawText(Canvas.Handle, PChar(m_caption), Length(m_caption), text_rect, DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

    if Focused and Enabled then
    begin
        focus_rect := Rect(
            glyph_rect.Right + scale_ui_for_dpi(2, dpi),
            scale_ui_for_dpi(2, dpi),
            Width - scale_ui_for_dpi(2, dpi),
            Height - scale_ui_for_dpi(2, dpi)
        );
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Style := psDot;
        Canvas.Pen.Width := 1;
        Canvas.Pen.Color := RGB(132, 146, 166);
        Canvas.RoundRect(
            focus_rect.Left,
            focus_rect.Top,
            focus_rect.Right,
            focus_rect.Bottom,
            scale_ui_for_dpi(4, dpi),
            scale_ui_for_dpi(4, dpi)
        );
    end;
end;

procedure TncFlatPageControl.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);
    Params.ExStyle := Params.ExStyle and (not WS_EX_CLIENTEDGE);
end;

function create_label(const owner: TComponent; const parent: TWinControl; const caption: string;
    const top: Integer): TLabel;
begin
    Result := TLabel.Create(owner);
    Result.Parent := parent;
    Result.Left := c_label_left;
    Result.Top := top + 4;
    Result.Caption := caption;
end;

function create_section_group(const owner: TComponent; const parent: TWinControl; const caption: string;
    const top: Integer; const height: Integer): TPanel;
var
    accent: TPanel;
    title_label: TLabel;
    section_width: Integer;
begin
    section_width := c_section_width;
    if (parent <> nil) and (parent.ClientWidth > (c_section_left * 2)) then
    begin
        section_width := parent.ClientWidth - (c_section_left * 2);
    end;

    Result := TPanel.Create(owner);
    Result.Parent := parent;
    Result.Left := c_section_left;
    Result.Top := top;
    Result.Width := section_width;
    Result.Height := height;
    Result.BevelOuter := bvNone;
    Result.ParentBackground := False;
    Result.Color := clWhite;
    Result.ParentFont := True;
    Result.Anchors := [akLeft, akTop, akRight];

    accent := TPanel.Create(Result);
    accent.Parent := Result;
    accent.Align := alTop;
    accent.Height := 3;
    accent.BevelOuter := bvNone;
    accent.ParentBackground := False;
    accent.Color := RGB(50, 118, 255);

    title_label := TLabel.Create(Result);
    title_label.Parent := Result;
    title_label.Left := c_label_left;
    title_label.Top := 10;
    title_label.Caption := caption;
    title_label.Font.Style := [fsBold];
    title_label.Font.Color := RGB(34, 39, 46);
end;

function measure_wrapped_label_height(const font: TFont; const text: string; const width: Integer): Integer;
var
    dc: HDC;
    old_font: HGDIOBJ;
    calc_rect: TRect;
begin
    Result := 20;
    if (font = nil) or (width <= 0) or (text = '') then
    begin
        Exit;
    end;

    dc := GetDC(0);
    if dc = 0 then
    begin
        Exit;
    end;
    try
        old_font := SelectObject(dc, font.Handle);
        try
            calc_rect := Rect(0, 0, width, 0);
            DrawText(dc, PChar(text), Length(text), calc_rect, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
            Result := calc_rect.Bottom - calc_rect.Top + 4;
            if Result < 20 then
            begin
                Result := 20;
            end;
        finally
            SelectObject(dc, old_font);
        end;
    finally
        ReleaseDC(0, dc);
    end;
end;

function create_hint_label(const owner: TComponent; const parent: TWinControl; const caption: string;
    const left: Integer; const top: Integer; const width: Integer): TLabel;
begin
    Result := TLabel.Create(owner);
    Result.Parent := parent;
    Result.Left := left;
    Result.Top := top;
    Result.AutoSize := False;
    Result.WordWrap := True;
    Result.Width := width;
    Result.Height := measure_wrapped_label_height(Result.Font, caption, width);
    Result.Caption := caption;
    Result.Font.Color := clGrayText;
end;

function get_ui_scale_dpi: Integer;
begin
    Result := Screen.PixelsPerInch;
    if Result <= 0 then
    begin
        Result := 96;
    end;
end;

function scale_ui(const value: Integer): Integer;
begin
    Result := MulDiv(value, get_ui_scale_dpi, 96);
end;

function get_window_dpi(const wnd: HWND): Integer;
begin
    Result := 96;
    if wnd <> 0 then
    begin
        Result := GetDpiForWindow(wnd);
    end;
    if Result <= 0 then
    begin
        Result := get_ui_scale_dpi;
    end;
end;

function get_control_scale_dpi(const control: TControl): Integer;
var
    win_control: TWinControl;
begin
    Result := get_ui_scale_dpi;
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

function scale_ui_for_dpi(const value: Integer; const dpi: Integer): Integer;
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

function measure_font_height(const font: TFont): Integer;
var
    dc: HDC;
    old_font: HGDIOBJ;
    metrics: TTextMetric;
begin
    Result := 12;
    if font = nil then
    begin
        Exit;
    end;

    dc := GetDC(0);
    if dc = 0 then
    begin
        Exit;
    end;
    try
        old_font := SelectObject(dc, font.Handle);
        try
            if GetTextMetrics(dc, metrics) then
            begin
                Result := metrics.tmHeight;
            end;
        finally
            SelectObject(dc, old_font);
        end;
    finally
        ReleaseDC(0, dc);
    end;
end;

function calculate_checkbox_height(const font: TFont): Integer;
begin
    Result := calculate_checkbox_height_for_dpi(font, get_ui_scale_dpi);
end;

function calculate_checkbox_height_for_dpi(const font: TFont; const dpi: Integer): Integer;
var
    min_height: Integer;
begin
    min_height := scale_ui_for_dpi(24, dpi);
    Result := measure_font_height(font) + scale_ui_for_dpi(10, dpi);
    if Result < min_height then
    begin
        Result := min_height;
    end;
end;

function create_check_box(const owner: TComponent; const parent: TWinControl; const top: Integer;
    const caption: string; const on_click: TNotifyEvent): TncModernCheckBox;
begin
    Result := TncModernCheckBox.Create(owner);
    Result.Parent := parent;
    Result.ParentFont := True;
    Result.Left := c_label_left;
    Result.Top := top;
    Result.Width := c_check_width;
    if (parent <> nil) and (parent.ClientWidth > (c_label_left * 2)) then
    begin
        Result.Width := parent.ClientWidth - (c_label_left * 2);
    end;
    Result.Height := calculate_checkbox_height_for_dpi(Result.Font, get_control_scale_dpi(parent));
    if parent is TPanel then
    begin
        Result.Color := TPanel(parent).Color;
    end
    else
    begin
        Result.Color := clWhite;
    end;
    Result.Caption := caption;
    Result.OnClick := on_click;
end;

function create_browse_button(const owner: TComponent; const parent: TWinControl; const top: Integer;
    const on_click: TNotifyEvent): TncModernButton;
begin
    Result := TncModernButton.Create(owner);
    Result.Parent := parent;
    Result.Left := c_control_left + c_path_edit_width + c_browse_button_gap;
    Result.Top := top - 1;
    Result.Width := c_browse_button_width;
    Result.Height := c_button_height;
    Result.Caption := SButtonBrowse;
    Result.OnClick := on_click;
    Result.VisualKind := mbkSecondary;
end;

function create_action_button(const owner: TComponent; const parent: TWinControl; const left: Integer;
    const top: Integer; const caption: string; const on_click: TNotifyEvent): TncModernButton;
begin
    Result := TncModernButton.Create(owner);
    Result.Parent := parent;
    Result.Left := left;
    Result.Top := top;
    Result.Width := c_action_button_width;
    Result.Height := c_button_height;
    Result.Caption := caption;
    Result.OnClick := on_click;
    Result.VisualKind := mbkSubtle;
end;

function normalize_path_override(const edit_text: string; const default_path: string): string;
begin
    Result := Trim(edit_text);
    if Result = '' then
    begin
        Result := default_path;
    end;
end;

function build_default_engine_config_value: TncEngineConfig;
begin
    Result.input_mode := im_chinese;
    Result.max_candidates := 9;
    Result.enable_ctrl_space_toggle := False;
    Result.enable_shift_space_full_width_toggle := True;
    Result.enable_ctrl_period_punct_toggle := True;
    Result.full_width_mode := False;
    Result.punctuation_full_width := True;
    Result.enable_segment_candidates := True;
    Result.segment_head_only_multi_syllable := True;
    Result.debug_mode := False;
    Result.dictionary_variant := dv_simplified;
end;

function build_default_log_config_value: TncLogConfig;
begin
    Result.enabled := False;
    Result.level := ll_info;
    Result.max_size_kb := 1024;
    Result.log_path := get_default_log_path;
end;

constructor TncSettingsForm.Create(AOwner: TComponent);
begin
    inherited CreateNew(AOwner);
    m_dirty := False;
    m_applied := False;
    configure_form;
    configure_tabs;
    configure_buttons;
    add_general_controls;
    add_logging_controls;
    add_advanced_controls;
    load_from_config;
end;

class function TncSettingsForm.ExecuteDialog(const owner: TComponent; var config: TncEngineConfig;
    var log_config: TncLogConfig; var status_widget_visible: Boolean; const on_apply: TncApplySettingsProc): Boolean;
var
    form: TncSettingsForm;
begin
    form := TncSettingsForm.Create(owner);
    try
        form.m_engine_config := config;
        form.m_log_config := log_config;
        form.m_status_widget_visible := status_widget_visible;
        form.m_apply_proc := on_apply;
        form.load_from_config;
        form.ShowModal;
        config := form.m_engine_config;
        log_config := form.m_log_config;
        status_widget_visible := form.m_status_widget_visible;
        Result := form.m_applied;
    finally
        form.Free;
    end;
end;

procedure TncSettingsForm.configure_form;
begin
    BorderStyle := bsDialog;
    BorderIcons := [biSystemMenu];
    Caption := SSettingsTitle;
    ClientWidth := c_dialog_width;
    ClientHeight := c_dialog_height;
    Position := poScreenCenter;
    Font.Name := 'Microsoft YaHei UI';
    Font.Size := 9;
    Color := RGB(245, 247, 250);
end;

procedure TncSettingsForm.update_dialog_height_for_content;
var
    tab_sheet: TTabSheet;
    control: TControl;
    display_rect: TRect;
    tab_index: Integer;
    control_index: Integer;
    max_content_bottom: Integer;
    tab_strip_height: Integer;
    desired_page_client_height: Integer;
    desired_client_height: Integer;
begin
    if m_page_control = nil then
    begin
        Exit;
    end;

    m_page_control.HandleNeeded;
    display_rect := m_page_control.DisplayRect;
    tab_strip_height := m_page_control.Height - (display_rect.Bottom - display_rect.Top);
    if tab_strip_height < 0 then
    begin
        tab_strip_height := 0;
    end;

    max_content_bottom := 0;
    for tab_index := 0 to m_page_control.PageCount - 1 do
    begin
        tab_sheet := m_page_control.Pages[tab_index];
        if tab_sheet = nil then
        begin
            Continue;
        end;

        for control_index := 0 to tab_sheet.ControlCount - 1 do
        begin
            control := tab_sheet.Controls[control_index];
            if (control <> nil) and control.Visible then
            begin
                if (control.Top + control.Height) > max_content_bottom then
                begin
                    max_content_bottom := control.Top + control.Height;
                end;
            end;
        end;
    end;

    desired_page_client_height := max_content_bottom + 18;
    desired_client_height := c_page_margin + tab_strip_height + desired_page_client_height + c_footer_height;
    if desired_client_height < (c_footer_height + 220) then
    begin
        desired_client_height := c_footer_height + 220;
    end;

    if ClientHeight <> desired_client_height then
    begin
        ClientHeight := desired_client_height;
    end;
end;

procedure TncSettingsForm.DoShow;
begin
    inherited;
    HandleNeeded;
    update_scaled_control_metrics;
    update_dialog_height_for_content;
    SetWindowPos(
        Handle,
        HWND_TOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOOWNERZORDER or SWP_SHOWWINDOW
    );
    SetWindowPos(
        Handle,
        HWND_NOTOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOOWNERZORDER
    );
    BringWindowToTop(Handle);
    SetForegroundWindow(Handle);
    SetActiveWindow(Handle);
end;

procedure TncSettingsForm.update_scaled_control_metrics;
var
    dpi: Integer;

    procedure update_check_box_metrics(const control: TncModernCheckBox);
    begin
        if control = nil then
        begin
            Exit;
        end;
        control.Height := calculate_checkbox_height_for_dpi(control.Font, dpi);
        control.Invalidate;
    end;
begin
    dpi := get_window_dpi(Handle);
    update_check_box_metrics(m_chk_full_width_mode);
    update_check_box_metrics(m_chk_show_status_widget);
    update_check_box_metrics(m_chk_log_enabled);
    update_check_box_metrics(m_chk_debug_mode);
end;

procedure TncSettingsForm.CMDialogKey(var Message: TCMDialogKey);
begin
    if (Message.CharCode = VK_RETURN) and (GetKeyState(VK_CONTROL) >= 0) and (GetKeyState(VK_MENU) >= 0) then
    begin
        if (m_btn_ok <> nil) and m_btn_ok.Enabled then
        begin
            m_btn_ok.Click;
            Message.Result := 1;
            Exit;
        end;
    end;

    if Message.CharCode = VK_ESCAPE then
    begin
        if (m_btn_cancel <> nil) and m_btn_cancel.Enabled then
        begin
            m_btn_cancel.Click;
            Message.Result := 1;
            Exit;
        end;
    end;

    inherited;
end;

procedure TncSettingsForm.configure_tabs;
begin
    m_page_control := TncFlatPageControl.Create(Self);
    m_page_control.Parent := Self;
    m_page_control.Align := alClient;
    m_page_control.AlignWithMargins := True;
    m_page_control.Margins.Left := c_page_margin;
    m_page_control.Margins.Top := c_page_margin;
    m_page_control.Margins.Right := c_page_margin;
    m_page_control.Margins.Bottom := 0;
    m_page_control.Style := tsFlatButtons;
    m_page_control.HotTrack := True;

    m_tab_general := TTabSheet.Create(m_page_control);
    m_tab_general.PageControl := m_page_control;
    m_tab_general.Caption := STabGeneral;

    m_tab_logging := TTabSheet.Create(m_page_control);
    m_tab_logging.PageControl := m_page_control;
    m_tab_logging.Caption := STabLogging;

    m_tab_advanced := TTabSheet.Create(m_page_control);
    m_tab_advanced.PageControl := m_page_control;
    m_tab_advanced.Caption := STabAdvanced;
end;

procedure TncSettingsForm.configure_buttons;
var
    footer_panel: TPanel;
    footer_line: TBevel;
begin
    footer_panel := TPanel.Create(Self);
    footer_panel.Parent := Self;
    footer_panel.Align := alBottom;
    footer_panel.Height := c_footer_height;
    footer_panel.BevelOuter := bvNone;
    footer_panel.ParentBackground := False;
    footer_panel.Color := RGB(250, 251, 252);

    footer_line := TBevel.Create(footer_panel);
    footer_line.Parent := footer_panel;
    footer_line.Align := alTop;
    footer_line.Shape := bsTopLine;
    footer_line.Height := 2;

    m_btn_reset := TncModernButton.Create(Self);
    m_btn_reset.Parent := footer_panel;
    m_btn_reset.Left := 18;
    m_btn_reset.Top := 10;
    m_btn_reset.Width := 96;
    m_btn_reset.Height := c_footer_button_height;
    m_btn_reset.Caption := SButtonDefaults;
    m_btn_reset.OnClick := on_reset_click;
    m_btn_reset.VisualKind := mbkSubtle;

    m_btn_apply := TncModernButton.Create(Self);
    m_btn_apply.Parent := footer_panel;
    m_btn_apply.Left := ClientWidth - 272;
    m_btn_apply.Top := 10;
    m_btn_apply.Width := 78;
    m_btn_apply.Height := c_footer_button_height;
    m_btn_apply.Caption := SButtonApply;
    m_btn_apply.OnClick := on_apply_click;
    m_btn_apply.VisualKind := mbkSecondary;

    m_btn_ok := TncModernButton.Create(Self);
    m_btn_ok.Parent := footer_panel;
    m_btn_ok.Left := ClientWidth - 184;
    m_btn_ok.Top := 10;
    m_btn_ok.Width := 78;
    m_btn_ok.Height := c_footer_button_height;
    m_btn_ok.Caption := SButtonOK;
    m_btn_ok.Default := True;
    m_btn_ok.OnClick := on_ok_click;
    m_btn_ok.VisualKind := mbkPrimary;

    m_btn_cancel := TncModernButton.Create(Self);
    m_btn_cancel.Parent := footer_panel;
    m_btn_cancel.Left := ClientWidth - 96;
    m_btn_cancel.Top := 10;
    m_btn_cancel.Width := 78;
    m_btn_cancel.Height := c_footer_button_height;
    m_btn_cancel.Caption := SButtonCancel;
    m_btn_cancel.Cancel := True;
    m_btn_cancel.OnClick := on_cancel_click;
    m_btn_cancel.VisualKind := mbkSecondary;
end;

procedure TncSettingsForm.add_general_controls;
var
    top: Integer;
    section_top: Integer;
    defaults_group: TPanel;
    appearance_group: TPanel;
begin
    section_top := 18;
    defaults_group := create_section_group(Self, m_tab_general, SGroupDefaultBehavior, section_top, 158);

    top := c_section_inner_top;
    create_label(Self, defaults_group, SLabelInputMode, top);
    m_combo_input_mode := TComboBox.Create(Self);
    m_combo_input_mode.Parent := defaults_group;
    m_combo_input_mode.Left := c_control_left;
    m_combo_input_mode.Top := top;
    m_combo_input_mode.Width := c_combo_width;
    m_combo_input_mode.Style := csDropDownList;
    m_combo_input_mode.Items.Add(SOptionSimplifiedChineseInput);
    m_combo_input_mode.Items.Add(SOptionTraditionalChineseInput);
    m_combo_input_mode.Items.Add(SOptionEnglishInput);
    m_combo_input_mode.OnChange := mark_dirty;

    Inc(top, c_row_height + c_general_row_gap);
    create_label(Self, defaults_group, SLabelPunctuationMode, top);
    m_combo_punctuation_mode := TComboBox.Create(Self);
    m_combo_punctuation_mode.Parent := defaults_group;
    m_combo_punctuation_mode.Left := c_control_left;
    m_combo_punctuation_mode.Top := top;
    m_combo_punctuation_mode.Width := c_combo_width;
    m_combo_punctuation_mode.Style := csDropDownList;
    m_combo_punctuation_mode.Items.Add(SOptionChinese);
    m_combo_punctuation_mode.Items.Add(SOptionEnglish);
    m_combo_punctuation_mode.OnChange := mark_dirty;

    Inc(top, c_row_height + c_general_row_gap);
    m_chk_full_width_mode := create_check_box(Self, defaults_group, top, SCheckFullWidthMode, mark_dirty);

    section_top := defaults_group.Top + defaults_group.Height + 10;
    appearance_group := create_section_group(Self, m_tab_general, SGroupAppearance, section_top, 76);

    top := c_section_inner_top;
    m_chk_show_status_widget := create_check_box(Self, appearance_group, top, SCheckShowStatusWidget, mark_dirty);
end;

procedure TncSettingsForm.add_logging_controls;
var
    top: Integer;
    section_top: Integer;
    logging_group: TPanel;
    files_group: TPanel;
begin
    section_top := 18;
    logging_group := create_section_group(Self, m_tab_logging, SGroupLogging, section_top, 152);

    top := c_section_inner_top;
    m_chk_log_enabled := create_check_box(Self, logging_group, top, SCheckEnableLogging, mark_dirty);

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, logging_group, SLabelLogLevel, top);
    m_combo_log_level := TComboBox.Create(Self);
    m_combo_log_level.Parent := logging_group;
    m_combo_log_level.Left := c_control_left;
    m_combo_log_level.Top := top;
    m_combo_log_level.Width := c_combo_width;
    m_combo_log_level.Style := csDropDownList;
    m_combo_log_level.Items.Add(SOptionLogDebug);
    m_combo_log_level.Items.Add(SOptionLogInfo);
    m_combo_log_level.Items.Add(SOptionLogWarn);
    m_combo_log_level.Items.Add(SOptionLogError);
    m_combo_log_level.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, logging_group, SLabelMaxLogSize, top);
    m_edit_log_max_size_kb := TEdit.Create(Self);
    m_edit_log_max_size_kb.Parent := logging_group;
    m_edit_log_max_size_kb.Left := c_control_left;
    m_edit_log_max_size_kb.Top := top;
    m_edit_log_max_size_kb.Width := c_edit_width;
    configure_numeric_edit(m_edit_log_max_size_kb, '64..1048576');
    m_edit_log_max_size_kb.OnChange := mark_dirty;

    section_top := logging_group.Top + logging_group.Height + c_section_gap;
    files_group := create_section_group(Self, m_tab_logging, SGroupLogFiles, section_top, 108);

    top := c_section_inner_top;
    create_label(Self, files_group, SLabelLogPath, top);
    m_edit_log_path := TEdit.Create(Self);
    m_edit_log_path.Parent := files_group;
    m_edit_log_path.Left := c_control_left;
    m_edit_log_path.Top := top;
    m_edit_log_path.Width := c_path_edit_width;
    configure_path_edit(m_edit_log_path, get_default_log_path);
    m_edit_log_path.OnChange := mark_dirty;
    m_btn_log_path := create_browse_button(Self, files_group, top, on_browse_log_path);

    Inc(top, c_row_height + 2);
    m_btn_open_log_folder := create_action_button(Self, files_group, c_control_left, top,
        SButtonOpenLogFolder, on_open_log_folder);
    m_btn_log_defaults := create_action_button(Self, files_group, c_control_left + c_action_button_width + 12, top,
        SButtonUseDefaultLogging, on_log_defaults_click);

end;

procedure TncSettingsForm.add_advanced_controls;
var
    top: Integer;
    section_top: Integer;
    debug_group: TPanel;
    tools_group: TPanel;
begin
    section_top := 18;
    debug_group := create_section_group(Self, m_tab_advanced, SGroupDebug, section_top, 116);

    top := c_section_inner_top;
    m_chk_debug_mode := create_check_box(Self, debug_group, top, SCheckEnableDebugMode, mark_dirty);
    create_hint_label(Self, debug_group, SHintDebugMode, c_label_left, top + c_row_height + 4, c_hint_width);

    section_top := debug_group.Top + debug_group.Height + c_section_gap;
    tools_group := create_section_group(Self, m_tab_advanced, SGroupConfigTools, section_top, 134);

    top := c_section_inner_top;
    m_btn_open_config_folder := create_action_button(Self, tools_group, c_label_left, top,
        SButtonOpenConfigFolder, on_open_config_folder);
    m_btn_open_config_file := create_action_button(Self, tools_group, c_label_left + c_action_button_width + 12, top,
        SButtonOpenConfigFile, on_open_config_file);

    m_hint_advanced := create_hint_label(Self, tools_group, SHintAdvanced, c_label_left, top + c_row_height + 8, c_hint_width);
end;

procedure TncSettingsForm.mark_dirty(Sender: TObject);
begin
    m_dirty := True;
    update_logging_controls;
    update_apply_button;
end;

procedure TncSettingsForm.update_apply_button;
begin
    if m_btn_apply <> nil then
    begin
        m_btn_apply.Enabled := m_dirty;
    end;
end;

procedure TncSettingsForm.update_logging_controls;
var
    enabled: Boolean;
begin
    enabled := (m_chk_log_enabled <> nil) and m_chk_log_enabled.Checked;
    if m_combo_log_level <> nil then
    begin
        m_combo_log_level.Enabled := enabled;
    end;
    if m_edit_log_max_size_kb <> nil then
    begin
        m_edit_log_max_size_kb.Enabled := enabled;
    end;
    if m_edit_log_path <> nil then
    begin
        m_edit_log_path.Enabled := enabled;
    end;
    if m_btn_log_path <> nil then
    begin
        m_btn_log_path.Enabled := enabled;
    end;
    if m_btn_open_log_folder <> nil then
    begin
        m_btn_open_log_folder.Enabled := True;
    end;
    if m_btn_log_defaults <> nil then
    begin
        m_btn_log_defaults.Enabled := True;
    end;
end;

procedure TncSettingsForm.load_defaults;
begin
    m_engine_config := build_default_engine_config_value;
    m_log_config := build_default_log_config_value;
    m_status_widget_visible := True;
    load_from_config;
    m_dirty := True;
    update_apply_button;
end;

function TncSettingsForm.browse_for_save_file(const title: string; const filter: string; const default_ext: string;
    var path: string): Boolean;
var
    dialog: TSaveDialog;
begin
    dialog := TSaveDialog.Create(Self);
    try
        dialog.Title := title;
        dialog.Filter := filter;
        dialog.DefaultExt := default_ext;
        dialog.Options := [ofPathMustExist, ofEnableSizing, ofOverwritePrompt];
        if Trim(path) <> '' then
        begin
            dialog.FileName := path;
            dialog.InitialDir := ExtractFileDir(path);
        end;
        Result := dialog.Execute;
        if Result then
        begin
            path := dialog.FileName;
        end;
    finally
        dialog.Free;
    end;
end;

procedure TncSettingsForm.assign_path_edit(const edit: TEdit; const path: string);
begin
    if edit = nil then
    begin
        Exit;
    end;
    edit.Text := path;
    mark_dirty(edit);
end;

procedure TncSettingsForm.configure_numeric_edit(const edit: TEdit; const hint: string);
begin
    if edit = nil then
    begin
        Exit;
    end;

    edit.NumbersOnly := True;
    edit.TextHint := hint;
end;

procedure TncSettingsForm.configure_path_edit(const edit: TEdit; const hint: string);
begin
    if edit = nil then
    begin
        Exit;
    end;

    edit.TextHint := hint;
    edit.ParentShowHint := False;
    edit.ShowHint := True;
    edit.Hint := SPathEditHint;
end;

function TncSettingsForm.open_folder_for_path(const path_text: string; const caption: string): Boolean;
var
    resolved_path: string;
    folder_path: string;
begin
    Result := False;
    resolved_path := Trim(path_text);
    if resolved_path = '' then
    begin
        MessageDlg(Format(SPathEmpty, [caption]), mtWarning, [mbOK], 0);
        Exit;
    end;

    if TDirectory.Exists(resolved_path) then
    begin
        folder_path := resolved_path;
    end
    else
    begin
        folder_path := ExtractFileDir(resolved_path);
    end;

    if (folder_path = '') or (not TDirectory.Exists(folder_path)) then
    begin
        MessageDlg(Format(SPathMissing, [caption]), mtWarning, [mbOK], 0);
        Exit;
    end;

    ShellExecute(Handle, 'open', PChar(folder_path), nil, nil, SW_SHOWNORMAL);
    Result := True;
end;

procedure TncSettingsForm.load_from_config;
begin
    if m_combo_input_mode <> nil then
    begin
        if m_engine_config.input_mode = im_english then
        begin
            m_combo_input_mode.ItemIndex := 2;
        end
        else if m_engine_config.dictionary_variant = dv_traditional then
        begin
            m_combo_input_mode.ItemIndex := 1;
        end
        else
        begin
            m_combo_input_mode.ItemIndex := 0;
        end;
    end;

    if m_chk_full_width_mode <> nil then
    begin
        m_chk_full_width_mode.Checked := m_engine_config.full_width_mode;
    end;
    if m_combo_punctuation_mode <> nil then
    begin
        if m_engine_config.punctuation_full_width then
        begin
            m_combo_punctuation_mode.ItemIndex := 0;
        end
        else
        begin
            m_combo_punctuation_mode.ItemIndex := 1;
        end;
    end;
    if m_chk_show_status_widget <> nil then
    begin
        m_chk_show_status_widget.Checked := m_status_widget_visible;
    end;
    if m_chk_log_enabled <> nil then
    begin
        m_chk_log_enabled.Checked := m_log_config.enabled;
    end;
    if m_combo_log_level <> nil then
    begin
        case m_log_config.level of
            ll_debug:
                m_combo_log_level.ItemIndex := 0;
            ll_warn:
                m_combo_log_level.ItemIndex := 2;
            ll_error:
                m_combo_log_level.ItemIndex := 3;
        else
            m_combo_log_level.ItemIndex := 1;
        end;
    end;
    if m_edit_log_max_size_kb <> nil then
    begin
        m_edit_log_max_size_kb.Text := IntToStr(m_log_config.max_size_kb);
    end;
    if m_edit_log_path <> nil then
    begin
        m_edit_log_path.Text := m_log_config.log_path;
    end;
    if m_chk_debug_mode <> nil then
    begin
        m_chk_debug_mode.Checked := m_engine_config.debug_mode;
    end;
    m_dirty := False;
    update_logging_controls;
    update_apply_button;
end;

function TncSettingsForm.read_integer_setting(const edit: TEdit; const default_value: Integer;
    const min_value: Integer; const max_value: Integer; const setting_name: string; out value: Integer;
    out error_text: string): Boolean;
begin
    value := StrToIntDef(Trim(edit.Text), default_value);
    if value < min_value then
    begin
        error_text := Format(SErrorValueTooSmall, [setting_name, min_value]);
        Result := False;
        Exit;
    end;
    if value > max_value then
    begin
        error_text := Format(SErrorValueTooLarge, [setting_name, max_value]);
        Result := False;
        Exit;
    end;
    Result := True;
end;

function TncSettingsForm.build_config_from_controls(out next_config: TncEngineConfig; out next_log_config: TncLogConfig;
    out next_status_widget_visible: Boolean; out error_text: string): Boolean;
var
    log_max_size_kb: Integer;
begin
    next_config := m_engine_config;
    next_log_config := m_log_config;
    next_status_widget_visible := m_status_widget_visible;
    error_text := '';

    next_config.max_candidates := 9;

    if not read_integer_setting(m_edit_log_max_size_kb, m_log_config.max_size_kb, 64, 1024 * 1024,
        SSettingMaxLogSize, log_max_size_kb, error_text) then
    begin
        Result := False;
        Exit;
    end;
    next_log_config.max_size_kb := log_max_size_kb;

    case m_combo_input_mode.ItemIndex of
        1:
            begin
                next_config.input_mode := im_chinese;
                next_config.dictionary_variant := dv_traditional;
            end;
        2:
            begin
                next_config.input_mode := im_english;
            end;
    else
        begin
            next_config.input_mode := im_chinese;
            next_config.dictionary_variant := dv_simplified;
        end;
    end;

    next_config.full_width_mode := m_chk_full_width_mode.Checked;
    next_config.punctuation_full_width := m_combo_punctuation_mode.ItemIndex <> 1;
    next_config.enable_segment_candidates := True;
    next_config.segment_head_only_multi_syllable := True;
    next_config.enable_ctrl_space_toggle := False;
    next_config.enable_shift_space_full_width_toggle := True;
    next_config.enable_ctrl_period_punct_toggle := True;
    next_status_widget_visible := m_chk_show_status_widget.Checked;
    next_log_config.enabled := m_chk_log_enabled.Checked;
    next_log_config.log_path := normalize_path_override(m_edit_log_path.Text, get_default_log_path);
    case m_combo_log_level.ItemIndex of
        0:
            next_log_config.level := ll_debug;
        2:
            next_log_config.level := ll_warn;
        3:
            next_log_config.level := ll_error;
    else
        next_log_config.level := ll_info;
    end;
    next_config.debug_mode := m_chk_debug_mode.Checked;

    Result := True;
end;

procedure TncSettingsForm.on_browse_log_path(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_log_path.Text);
    if browse_for_save_file(SDialogSelectLogFile, SFilterLogFiles, 'log', path) then
    begin
        assign_path_edit(m_edit_log_path, path);
    end;
end;

procedure TncSettingsForm.on_open_log_folder(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_log_path.Text);
    if path = '' then
    begin
        path := get_default_log_path;
    end;
    open_folder_for_path(path, SCurrentLogFolder);
end;

procedure TncSettingsForm.on_log_defaults_click(Sender: TObject);
var
    default_log_config: TncLogConfig;
begin
    default_log_config := build_default_log_config_value;
    if m_chk_log_enabled <> nil then
    begin
        m_chk_log_enabled.Checked := default_log_config.enabled;
    end;
    if m_combo_log_level <> nil then
    begin
        case default_log_config.level of
            ll_debug:
                m_combo_log_level.ItemIndex := 0;
            ll_warn:
                m_combo_log_level.ItemIndex := 2;
            ll_error:
                m_combo_log_level.ItemIndex := 3;
        else
            m_combo_log_level.ItemIndex := 1;
        end;
    end;
    if m_edit_log_max_size_kb <> nil then
    begin
        m_edit_log_max_size_kb.Text := IntToStr(default_log_config.max_size_kb);
    end;
    assign_path_edit(m_edit_log_path, default_log_config.log_path);
end;

procedure TncSettingsForm.on_open_config_folder(Sender: TObject);
var
    folder_path: string;
begin
    folder_path := ExtractFileDir(get_default_config_path);
    if (folder_path = '') or (not TDirectory.Exists(folder_path)) then
    begin
        MessageDlg(SConfigFolderMissing, mtWarning, [mbOK], 0);
        Exit;
    end;
    ShellExecute(Handle, 'open', PChar(folder_path), nil, nil, SW_SHOWNORMAL);
end;

procedure TncSettingsForm.on_open_config_file(Sender: TObject);
var
    config_path: string;
begin
    config_path := get_default_config_path;
    if (config_path = '') or (not FileExists(config_path)) then
    begin
        MessageDlg(SConfigFileMissing, mtWarning, [mbOK], 0);
        Exit;
    end;
    ShellExecute(Handle, 'open', PChar(config_path), nil, nil, SW_SHOWNORMAL);
end;

procedure TncSettingsForm.on_reset_click(Sender: TObject);
begin
    if Application.MessageBox(PChar(SConfirmRestoreDefaults), PChar(SSettingsTitle),
        MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
        load_defaults;
    end;
end;

procedure TncSettingsForm.apply_changes;
var
    next_config: TncEngineConfig;
    next_log_config: TncLogConfig;
    next_status_widget_visible: Boolean;
    error_text: string;
begin
    if not build_config_from_controls(next_config, next_log_config, next_status_widget_visible, error_text) then
    begin
        Application.MessageBox(PChar(error_text), PChar(SSettingsTitle), MB_OK or MB_ICONWARNING);
        Exit;
    end;

    m_engine_config := next_config;
    m_log_config := next_log_config;
    m_status_widget_visible := next_status_widget_visible;
    if Assigned(m_apply_proc) then
    begin
        m_apply_proc(m_engine_config, m_log_config, m_status_widget_visible);
    end;
    m_dirty := False;
    m_applied := True;
    update_apply_button;
end;

procedure TncSettingsForm.on_apply_click(Sender: TObject);
begin
    apply_changes;
end;

procedure TncSettingsForm.on_ok_click(Sender: TObject);
begin
    if m_dirty then
    begin
        apply_changes;
        if m_dirty then
        begin
            Exit;
        end;
    end;
    ModalResult := mrOk;
end;

procedure TncSettingsForm.on_cancel_click(Sender: TObject);
begin
    ModalResult := mrCancel;
end;

end.
