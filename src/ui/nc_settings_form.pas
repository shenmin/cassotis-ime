unit nc_settings_form;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.Math,
    System.Types,
    System.UITypes,
    Winapi.Windows,
    Winapi.Messages,
    Winapi.MultiMon,
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
    nc_shortcut,
    nc_dpi_scale,
    nc_version_info,
    nc_config,
    nc_candidate_theme,
    nc_candidate_window,
    nc_log;

type
    TncModernButtonKind = (
        mbkPrimary,
        mbkSecondary,
        mbkSubtle,
        mbkGhost
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
        m_ghost_background_color: TColor;
        procedure set_caption(const value: string);
        procedure set_kind(const value: TncModernButtonKind);
        procedure set_ghost_background_color(const value: TColor);
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
        property GhostBackgroundColor: TColor read m_ghost_background_color write set_ghost_background_color default clBtnFace;
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
        const log_config: TncLogConfig; const status_widget_visible: Boolean;
        const status_widget_transparency: Integer);
    TncPreviewStatusWidgetProc = reference to procedure(const transparency: Integer;
        const preview_visible: Boolean);
    TncClearUserDictionaryProc = reference to function: Boolean;

    TncSettingsForm = class(TForm)
    private
        m_scaled_dpi: Integer;
        m_page_control: TncFlatPageControl;
        m_tab_general: TTabSheet;
        m_tab_appearance: TTabSheet;
        m_tab_fuzzy_pinyin: TTabSheet;
        m_tab_shortcuts: TTabSheet;
        m_tab_logging: TTabSheet;
        m_tab_advanced: TTabSheet;
        m_scroll_general: TScrollBox;
        m_scroll_appearance: TScrollBox;
        m_scroll_fuzzy_pinyin: TScrollBox;
        m_scroll_shortcuts: TScrollBox;
        m_scroll_logging: TScrollBox;
        m_scroll_advanced: TScrollBox;
        m_label_website: TLabel;
        m_btn_reset: TncModernButton;
        m_btn_apply: TncModernButton;
        m_btn_ok: TncModernButton;
        m_btn_cancel: TncModernButton;
        m_combo_input_mode: TComboBox;
        m_combo_pinyin_input_scheme: TComboBox;
        m_chk_fuzzy_pinyin_enabled: TncModernCheckBox;
        m_chk_fuzzy_pinyin_rules:
            array[TncFuzzyPinyinRule] of TncModernCheckBox;
        m_combo_punctuation_mode: TComboBox;
        m_chk_full_width_mode: TncModernCheckBox;
        m_chk_show_status_widget: TncModernCheckBox;
        m_track_status_widget_transparency: TTrackBar;
        m_label_status_widget_transparency: TLabel;
        m_combo_candidate_font: TComboBox;
        m_track_candidate_font_size: TTrackBar;
        m_candidate_font_size_labels:
            array[0..c_candidate_font_size_level_count - 1] of TLabel;
        m_combo_candidate_page_size: TComboBox;
        m_chk_candidate_expand_on_paging: TncModernCheckBox;
        m_combo_candidate_color_scheme: TComboBox;
        m_candidate_preview: TPaintBox;
        m_candidate_preview_window: TncCandidateWindow;
        m_combo_shortcut_modifiers: array[TncShortcutAction] of TComboBox;
        m_chk_shortcut_enabled: array[TncShortcutAction] of TncModernCheckBox;
        m_combo_shortcut_keys: array[TncShortcutAction] of TComboBox;
        m_combo_candidate_page_keys: TComboBox;
        m_combo_one_key_completion_key: TComboBox;
        m_panel_candidate_page_previous_key: TPanel;
        m_panel_candidate_page_next_key: TPanel;
        m_chk_log_enabled: TncModernCheckBox;
        m_combo_log_level: TComboBox;
        m_edit_log_max_size_kb: TEdit;
        m_edit_log_path: TEdit;
        m_btn_log_path: TncModernButton;
        m_btn_open_log_folder: TncModernButton;
        m_btn_log_defaults: TncModernButton;
        m_chk_debug_mode: TncModernCheckBox;
        m_btn_clear_user_dictionary: TncModernButton;
        m_btn_open_config_folder: TncModernButton;
        m_btn_open_config_file: TncModernButton;
        m_hint_advanced: TLabel;
        m_engine_config: TncEngineConfig;
        m_log_config: TncLogConfig;
        m_status_widget_visible: Boolean;
        m_status_widget_transparency: Integer;
        m_loading_controls: Boolean;
        m_preview_status_widget_proc: TncPreviewStatusWidgetProc;
        m_apply_proc: TncApplySettingsProc;
        m_clear_user_dictionary_proc: TncClearUserDictionaryProc;
        m_dirty: Boolean;
        m_applied: Boolean;
        procedure configure_form;
        procedure configure_tabs;
        procedure configure_buttons;
        procedure update_website_link_layout;
        procedure normalize_dialog_client_width_for_dpi(const dpi: Integer);
        procedure update_dialog_height_for_content;
        procedure add_general_controls;
        procedure add_appearance_controls;
        procedure add_fuzzy_pinyin_controls;
        procedure add_shortcut_controls;
        procedure add_logging_controls;
        procedure add_advanced_controls;
        procedure update_scaled_control_metrics;
        procedure mark_dirty(Sender: TObject);
        procedure on_status_widget_transparency_change(Sender: TObject);
        procedure on_page_change(Sender: TObject);
        procedure preview_status_widget;
        procedure update_apply_button;
        procedure update_logging_controls;
        procedure update_fuzzy_pinyin_controls;
        procedure on_fuzzy_pinyin_enabled_click(Sender: TObject);
        procedure restore_current_page_defaults;
        procedure load_from_config;
        procedure populate_candidate_font_combo;
        procedure populate_candidate_page_size_combo;
        procedure populate_candidate_color_scheme_combo;
        procedure populate_shortcut_modifier_combo(const combo: TComboBox);
        procedure populate_shortcut_key_combo(const combo: TComboBox);
        procedure populate_candidate_page_key_scheme_combo;
        procedure populate_one_key_completion_key_combo;
        procedure update_candidate_page_key_scheme_preview;
        procedure candidate_page_key_scheme_changed(Sender: TObject);
        procedure one_key_completion_key_changed(Sender: TObject);
        function shortcut_action_caption(const action: TncShortcutAction): string;
        function shortcut_from_controls(const action: TncShortcutAction): TncShortcut;
        procedure set_shortcut_controls(const action: TncShortcutAction; const shortcut: TncShortcut);
        procedure load_shortcut_controls(const config: TncShortcutConfig);
        procedure shortcut_enabled_changed(Sender: TObject);
        function get_candidate_font_size_from_slider: Integer;
        procedure set_candidate_font_size_slider(const font_size: Integer);
        function get_selected_candidate_font_name: string;
        function get_selected_candidate_page_size: Integer;
        procedure set_candidate_page_size_combo(const page_size: Integer);
        function get_selected_candidate_page_key_scheme: TncCandidatePageKeyScheme;
        procedure set_candidate_page_key_scheme_combo(
            const scheme: TncCandidatePageKeyScheme);
        function get_selected_one_key_completion_key: TncOneKeyCompletionKey;
        procedure set_one_key_completion_key_combo(
            const completion_key: TncOneKeyCompletionKey);
        function get_selected_candidate_color_scheme: Integer;
        procedure set_candidate_color_scheme_combo(const color_scheme: Integer);
        procedure update_candidate_preview;
        procedure on_candidate_appearance_change(Sender: TObject);
        procedure on_candidate_preview_paint(Sender: TObject);
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
        procedure on_clear_user_dictionary_click(Sender: TObject);
        procedure on_open_config_folder(Sender: TObject);
        procedure on_open_config_file(Sender: TObject);
        procedure on_website_link_click(Sender: TObject);
        procedure on_reset_click(Sender: TObject);
        procedure apply_changes;
        procedure on_apply_click(Sender: TObject);
        procedure on_ok_click(Sender: TObject);
        procedure on_cancel_click(Sender: TObject);
        procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    protected
        procedure CreateParams(var Params: TCreateParams); override;
        procedure DoShow; override;
        procedure WMDpiChanged(var Message: TMessage); message WM_DPICHANGED;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
        class function ExecuteDialog(const owner: TComponent; var config: TncEngineConfig; var log_config: TncLogConfig;
            var status_widget_visible: Boolean; var status_widget_transparency: Integer;
            const on_apply: TncApplySettingsProc;
            const on_clear_user_dictionary: TncClearUserDictionaryProc;
            const on_preview_status_widget: TncPreviewStatusWidgetProc): Boolean; static;
    end;

implementation

uses
    nc_status_widget_appearance;

const
    c_dialog_width = 596;
    c_dialog_height = 452;
    c_page_margin = 10;
    c_footer_height = 50;
    c_section_left = 12;
    c_section_width = c_dialog_width - 62;
    c_section_gap = 12;
    c_section_inner_top = 34;
    c_untitled_section_inner_top = 12;
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
    c_candidate_preview_height = 152;
    c_appearance_group_height = 446;
    c_tbm_get_channel_rect = WM_USER + 26;
    c_official_website_url = 'https://www.yanquan.org';

resourcestring
    SSettingsTitle = '言泉输入法 - 设置';
    SSettingsVersionedTitle = '言泉输入法 (v%s) - 设置';
    STabGeneral = '常规';
    STabAppearance = '外观';
    STabFuzzyPinyin = '模糊拼音';
    STabShortcuts = '快捷键';
    STabLogging = '日志';
    STabAdvanced = '高级';
    SButtonBrowse = '浏览';
    SButtonDefaults = '恢复默认';
    SButtonApply = '应用';
    SButtonOK = '确定';
    SButtonCancel = '取消';
    SGroupDefaultBehavior = '输入';
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
    SLabelPinyinInputScheme = '拼音方案';
    SOptionFullPinyin = '全拼';
    SOptionMicrosoftShuangpin = '微软双拼';
    SOptionXiaoheShuangpin = '小鹤双拼';
    SOptionZiranmaShuangpin = '自然码双拼';
    SOptionSogouShuangpin = '搜狗双拼';
    SOptionZiguangShuangpin = '紫光双拼';
    SOptionPinyinJiajiaShuangpin = '拼音加加';
    SCheckEnableFuzzyPinyin = '启用模糊拼音';
    SLabelPunctuationMode = '标点';
    SCheckFullWidthMode = '使用全角输入';
    SCheckShowStatusWidget = '显示状态浮窗';
    SLabelStatusWidgetTransparency = '浮窗透明度';
    SLabelCandidateFont = '候选字体';
    SLabelCandidateSize = '大小';
    SLabelCandidatePageSize = '每页候选';
    SCheckCandidateExpandOnPaging = '翻页时展开多行候选';
    SCandidatePageSizeItem = '%d 项';
    SLabelCandidateColorScheme = '配色';
    SLabelCandidatePreview = '预览';
    SLabelShortcutAction = '功能';
    SLabelShortcutModifier = '修饰键';
    SLabelShortcutKey = '按键';
    SShortcutInputMode = '中英文状态切换';
    SShortcutPunctuation = '中英文标点切换';
    SShortcutDictionaryVariant = '简繁体切换';
    SShortcutFullWidth = '全角/半角切换';
    SShortcutOpenSettings = '打开设置';
    SShortcutNoModifier = '无';
    SGroupCandidatePaging = '候选翻页';
    SLabelCandidatePageKeys = '按键组合';
    SLabelCandidatePagePrevious = '向上翻';
    SLabelCandidatePageNext = '向下翻';
    SPageKeysMinusPlus = '减号等号';
    SPageKeysBrackets = '左右中括号';
    SPageKeysCommaPeriod = '逗号句号';
    SPageKeysShiftTab = 'Shift+Tab / Tab';
    SCandidatePageKeysHint = '仅在候选窗口打开时生效。';
    SGroupOneKeyCompletion = '一键补全';
    SLabelOneKeyCompletionKey = '触发按键';
    SOneKeyCompletionHint = '输入至少两个完整音节，并存在可继续补全的精确词库词时生效。';
    SShortcutMissingKey = '“%s”尚未选择按键。';
    SShortcutInvalidModifierKey = '“%s”的快捷键无效：单独的修饰键仅支持 Shift，且不能再叠加其他修饰键。';
    SShortcutNeedsModifier = '“%s”不能使用未带修饰键的 %s，因为这会占用正常输入。请添加 Ctrl、Shift 或 Alt；无修饰键时仅支持 Shift 或 F1-F24。';
    SShortcutInvalid = '“%s”的快捷键无效，请选择其他组合。';
    SShortcutConflict = '“%s”和“%s”都使用了 %s。每个功能必须使用不同的快捷键。';
    SSizeMinimum = '最小';
    SSizeDefault = '默认';
    SSizeMaximum = '最大';
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
    SButtonClearUserDictionary = '清空用户词库';
    SConfirmClearUserDictionary = '确定要清空用户词库吗？此操作将删除此前记住的本地用户词和相关学习记录，且无法撤销。';
    SClearUserDictionarySucceeded = '用户词库已清空，并已立即生效。';
    SClearUserDictionaryFailed = '清空用户词库失败，请稍后重试。';
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
    SConfirmRestoreDefaults = '要恢复“%s”页的默认设置吗？';
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

function get_settings_window_title: string;
var
    product_version: string;
begin
    Result := SSettingsTitle;
    product_version := Trim(nc_get_current_exe_display_version);
    if product_version <> '' then
    begin
        Result := Format(SSettingsVersionedTitle, [product_version]);
    end;
end;

type
    TGetDpiForWindow = function(hwnd: HWND): UINT; stdcall;
    TGetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer;
        out dpiX: UINT; out dpiY: UINT): HRESULT; stdcall;

var
    g_get_dpi_for_window: TGetDpiForWindow = nil;
    g_get_dpi_for_window_ready: Boolean = False;
    g_get_dpi_for_monitor: TGetDpiForMonitor = nil;
    g_get_dpi_for_monitor_ready: Boolean = False;

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
        module := GetModuleHandle('shcore.dll');
        if module = 0 then
        begin
            module := LoadLibrary('shcore.dll');
        end;
        if module <> 0 then
        begin
            g_get_dpi_for_monitor := TGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
        end;
        g_get_dpi_for_monitor_ready := True;
    end;

    dpi := 0;
    Result := Assigned(g_get_dpi_for_monitor) and (monitor <> 0);
    if Result then
    begin
        dpi_x := 0;
        dpi_y := 0;
        Result := Succeeded(g_get_dpi_for_monitor(monitor, MDT_EFFECTIVE_DPI, dpi_x, dpi_y));
        if Result then
        begin
            dpi := Integer(dpi_x);
            Result := dpi > 0;
        end;
    end;
end;

function try_get_monitor_dpi_for_window(const wnd: HWND; out dpi: Integer): Boolean;
var
    monitor: HMONITOR;
begin
    dpi := 0;
    if wnd = 0 then
    begin
        Exit(False);
    end;
    monitor := MonitorFromWindow(wnd, MONITOR_DEFAULTTONEAREST);
    Result := try_get_dpi_for_monitor(monitor, dpi);
end;

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
    ControlStyle := ControlStyle - [csClickEvents];
    m_kind := mbkSecondary;
    m_caption := '';
    m_focusable := True;
    m_ghost_background_color := clBtnFace;
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

procedure TncModernButton.set_ghost_background_color(const value: TColor);
begin
    if m_ghost_background_color = value then
    begin
        Exit;
    end;
    m_ghost_background_color := value;
    if m_kind = mbkGhost then
    begin
        Invalidate;
    end;
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
        mbkGhost:
            begin
                background_color := m_ghost_background_color;
                border_color := m_ghost_background_color;
                text_color := RGB(70, 78, 90);
                if m_hot then
                begin
                    text_color := RGB(32, 80, 168);
                end;
                if m_pressed then
                begin
                    text_color := RGB(24, 72, 156);
                end;
                if is_disabled then
                begin
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
    ControlStyle := ControlStyle - [csClickEvents];
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

procedure TncSettingsForm.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);
    Params.ExStyle := (Params.ExStyle or WS_EX_APPWINDOW) and (not WS_EX_TOOLWINDOW);
    Params.WndParent := 0;
end;

function create_label(const owner: TComponent; const parent: TWinControl; const caption: string;
    const top: Integer): TLabel;
begin
    Result := TLabel.Create(owner);
    Result.Parent := parent;
    Result.Left := scale_ui(c_label_left);
    Result.Top := top + scale_ui(4);
    Result.Caption := caption;
end;

function create_section_group(const owner: TComponent; const parent: TWinControl; const caption: string;
    const top: Integer; const height: Integer): TPanel;
var
    accent: TPanel;
    title_label: TLabel;
    section_width: Integer;
begin
    section_width := scale_ui(c_section_width);
    if (parent <> nil) and (parent.ClientWidth > (scale_ui(c_section_left) * 2)) then
    begin
        section_width := parent.ClientWidth - (scale_ui(c_section_left) * 2);
    end;

    Result := TPanel.Create(owner);
    Result.Parent := parent;
    Result.Left := scale_ui(c_section_left);
    Result.Top := top;
    Result.Width := section_width;
    Result.Height := scale_ui(height);
    Result.BevelOuter := bvNone;
    Result.ParentBackground := False;
    Result.Color := clWhite;
    Result.ParentFont := True;
    Result.Anchors := [akLeft, akTop, akRight];

    accent := TPanel.Create(Result);
    accent.Parent := Result;
    accent.Align := alTop;
    accent.Height := scale_ui(3);
    accent.BevelOuter := bvNone;
    accent.ParentBackground := False;
    accent.Color := RGB(50, 118, 255);

    if caption <> '' then
    begin
        title_label := TLabel.Create(Result);
        title_label.Parent := Result;
        title_label.Left := scale_ui(c_label_left);
        title_label.Top := scale_ui(10);
        title_label.Caption := caption;
        title_label.Font.Style := [fsBold];
        title_label.Font.Color := RGB(34, 39, 46);
    end;
end;

function create_page_scroll_box(const owner: TComponent;
    const tab_sheet: TTabSheet): TScrollBox;
begin
    Result := TScrollBox.Create(owner);
    Result.Parent := tab_sheet;
    Result.Align := alClient;
    Result.BorderStyle := bsNone;
    Result.AutoScroll := True;
    Result.HorzScrollBar.Visible := False;
    Result.VertScrollBar.Tracking := True;
    Result.ParentColor := True;
    Result.TabStop := False;
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
        Result := c_nc_base_dpi;
    end;
end;

function scale_ui(const value: Integer): Integer;
begin
    Result := nc_scale_for_dpi(value, get_ui_scale_dpi);
end;

function get_window_dpi(const wnd: HWND): Integer;
begin
    Result := c_nc_base_dpi;
    if not try_get_dpi_for_window(wnd, Result) then
    begin
        if not try_get_monitor_dpi_for_window(wnd, Result) then
        begin
            Result := c_nc_base_dpi;
        end;
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
begin
    Result := nc_scale_for_dpi(value, dpi);
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
    Result.Left := scale_ui(c_label_left);
    Result.Top := top;
    Result.Width := scale_ui(c_check_width);
    if (parent <> nil) and (parent.ClientWidth > (scale_ui(c_label_left) * 2)) then
    begin
        Result.Width := parent.ClientWidth - (scale_ui(c_label_left) * 2);
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
    Result.Left := scale_ui(c_control_left + c_path_edit_width + c_browse_button_gap);
    Result.Top := top - scale_ui(1);
    Result.Width := scale_ui(c_browse_button_width);
    Result.Height := scale_ui(c_button_height);
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
    Result.Width := scale_ui(c_action_button_width);
    Result.Height := scale_ui(c_button_height);
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
    Result.pinyin_input_scheme := pis_full_pinyin;
    Result.fuzzy_pinyin_enabled := False;
    Result.fuzzy_pinyin_rules := [];
    Result.max_candidates := 9;
    Result.enable_ctrl_space_toggle := False;
    Result.enable_shift_space_full_width_toggle := True;
    Result.enable_ctrl_period_punct_toggle := True;
    Result.full_width_mode := False;
    Result.punctuation_full_width := True;
    Result.enable_segment_candidates := True;
    Result.segment_head_only_multi_syllable := True;
    Result.candidate_font_name := c_default_candidate_font_name;
    Result.candidate_font_size := c_default_candidate_font_size;
    Result.candidate_page_size := c_default_candidate_page_size;
    Result.candidate_expand_on_paging := False;
    Result.candidate_page_key_scheme := cpks_minus_plus;
    Result.one_key_completion_key := ock_tab;
    Result.candidate_color_scheme := c_default_candidate_color_scheme;
    Result.debug_mode := False;
    Result.dictionary_variant := dv_simplified;
    Result.shortcuts := nc_default_shortcut_config;
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
    m_candidate_preview_window := nil;
    m_dirty := False;
    m_applied := False;
    m_scaled_dpi := get_ui_scale_dpi;
    m_engine_config := build_default_engine_config_value;
    m_log_config := build_default_log_config_value;
    m_status_widget_visible := True;
    m_status_widget_transparency := c_default_status_widget_transparency;
    configure_form;
    configure_tabs;
    configure_buttons;
    add_general_controls;
    add_appearance_controls;
    add_fuzzy_pinyin_controls;
    add_shortcut_controls;
    add_logging_controls;
    add_advanced_controls;
    load_from_config;
end;

destructor TncSettingsForm.Destroy;
begin
    FreeAndNil(m_candidate_preview_window);
    inherited Destroy;
end;

class function TncSettingsForm.ExecuteDialog(const owner: TComponent; var config: TncEngineConfig;
    var log_config: TncLogConfig; var status_widget_visible: Boolean; var status_widget_transparency: Integer;
    const on_apply: TncApplySettingsProc; const on_clear_user_dictionary: TncClearUserDictionaryProc;
    const on_preview_status_widget: TncPreviewStatusWidgetProc): Boolean;
var
    form: TncSettingsForm;
begin
    form := TncSettingsForm.Create(owner);
    try
        form.m_engine_config := config;
        form.m_log_config := log_config;
        form.m_status_widget_visible := status_widget_visible;
        form.m_status_widget_transparency := nc_clamp_status_widget_transparency(status_widget_transparency);
        form.m_preview_status_widget_proc := on_preview_status_widget;
        form.m_apply_proc := on_apply;
        form.m_clear_user_dictionary_proc := on_clear_user_dictionary;
        form.load_from_config;
        form.ShowModal;
        config := form.m_engine_config;
        log_config := form.m_log_config;
        status_widget_visible := form.m_status_widget_visible;
        status_widget_transparency := form.m_status_widget_transparency;
        Result := form.m_applied;
    finally
        try
            // Cancel, Esc, close and exceptions all restore the last applied value.
            if Assigned(on_preview_status_widget) then
                on_preview_status_widget(form.m_status_widget_transparency, False);
        finally
            form.Free;
        end;
    end;
end;

procedure TncSettingsForm.configure_form;
begin
    BorderStyle := bsDialog;
    BorderIcons := [biSystemMenu];
    Caption := get_settings_window_title;
    ClientWidth := scale_ui(c_dialog_width);
    ClientHeight := scale_ui(c_dialog_height);
    Position := poScreenCenter;
    if (Application.Icon <> nil) and (Application.Icon.Handle <> 0) then
    begin
        Icon.Assign(Application.Icon);
    end;
    Font.Name := 'Microsoft YaHei UI';
    Font.Size := 9;
    Color := RGB(245, 247, 250);
end;

procedure TncSettingsForm.update_dialog_height_for_content;
var
    tab_sheet: TTabSheet;
    content_parent: TWinControl;
    control: TControl;
    display_rect: TRect;
    work_area: TRect;
    monitor_info: TMonitorInfo;
    monitor_handle: HMONITOR;
    tab_index: Integer;
    control_index: Integer;
    max_content_bottom: Integer;
    max_content_right: Integer;
    tab_strip_height: Integer;
    page_nonclient_width: Integer;
    desired_page_client_height: Integer;
    desired_page_client_width: Integer;
    desired_client_height: Integer;
    desired_client_width: Integer;
    max_client_height: Integer;
    max_client_width: Integer;
    nonclient_height: Integer;
    nonclient_width: Integer;
    work_area_margin: Integer;
    target_left: Integer;
    target_top: Integer;
    dpi: Integer;
begin
    if m_page_control = nil then
    begin
        Exit;
    end;

    m_page_control.HandleNeeded;
    dpi := get_window_dpi(Handle);
    if dpi <= 0 then
    begin
        dpi := c_nc_base_dpi;
    end;
    display_rect := m_page_control.DisplayRect;
    tab_strip_height := m_page_control.Height - (display_rect.Bottom - display_rect.Top);
    if tab_strip_height < 0 then
    begin
        tab_strip_height := 0;
    end;
    page_nonclient_width := m_page_control.Width - (display_rect.Right - display_rect.Left);
    if page_nonclient_width < 0 then
    begin
        page_nonclient_width := 0;
    end;

    max_content_bottom := 0;
    max_content_right := 0;
    for tab_index := 0 to m_page_control.PageCount - 1 do
    begin
        tab_sheet := m_page_control.Pages[tab_index];
        if tab_sheet = nil then
        begin
            Continue;
        end;

        content_parent := tab_sheet;
        if (tab_sheet.ControlCount = 1) and
            (tab_sheet.Controls[0] is TScrollBox) then
        begin
            content_parent := TScrollBox(tab_sheet.Controls[0]);
        end;

        for control_index := 0 to content_parent.ControlCount - 1 do
        begin
            control := content_parent.Controls[control_index];
            if (control <> nil) and control.Visible then
            begin
                if (control.Top + control.Height) > max_content_bottom then
                begin
                    max_content_bottom := control.Top + control.Height;
                end;
                if (control.Left + control.Width) > max_content_right then
                begin
                    max_content_right := control.Left + control.Width;
                end;
            end;
        end;
    end;

    desired_page_client_height := max_content_bottom + scale_ui_for_dpi(18, dpi);
    desired_page_client_width := max_content_right + scale_ui_for_dpi(18, dpi);
    desired_client_width := scale_ui_for_dpi(c_page_margin, dpi) * 2 + page_nonclient_width + desired_page_client_width;
    desired_client_height := scale_ui_for_dpi(c_page_margin, dpi) + tab_strip_height + desired_page_client_height + scale_ui_for_dpi(c_footer_height, dpi);
    if desired_client_width < scale_ui_for_dpi(c_dialog_width, dpi) then
    begin
        desired_client_width := scale_ui_for_dpi(c_dialog_width, dpi);
    end;
    if desired_client_height < (scale_ui_for_dpi(c_footer_height, dpi) + scale_ui_for_dpi(220, dpi)) then
    begin
        desired_client_height := scale_ui_for_dpi(c_footer_height, dpi) + scale_ui_for_dpi(220, dpi);
    end;

    work_area_margin := scale_ui_for_dpi(8, dpi);
    work_area := Rect(0, 0, Screen.Width, Screen.Height);
    monitor_handle := MonitorFromWindow(Handle, MONITOR_DEFAULTTONEAREST);
    FillChar(monitor_info, SizeOf(monitor_info), 0);
    monitor_info.cbSize := SizeOf(monitor_info);
    if (monitor_handle <> 0) and GetMonitorInfo(monitor_handle, @monitor_info) then
    begin
        work_area := monitor_info.rcWork;
    end;

    nonclient_width := Max(0, Width - ClientWidth);
    nonclient_height := Max(0, Height - ClientHeight);
    max_client_width := (work_area.Right - work_area.Left) -
        nonclient_width - (work_area_margin * 2);
    max_client_height := (work_area.Bottom - work_area.Top) -
        nonclient_height - (work_area_margin * 2);
    if max_client_width > 0 then
    begin
        desired_client_width := Min(desired_client_width, max_client_width);
    end;
    if max_client_height > 0 then
    begin
        desired_client_height := Min(desired_client_height, max_client_height);
    end;

    if ClientWidth <> desired_client_width then
    begin
        ClientWidth := desired_client_width;
    end;
    if ClientHeight <> desired_client_height then
    begin
        ClientHeight := desired_client_height;
    end;

    target_left := Left;
    target_top := Top;
    if target_left < (work_area.Left + work_area_margin) then
    begin
        target_left := work_area.Left + work_area_margin;
    end;
    if (target_left + Width) > (work_area.Right - work_area_margin) then
    begin
        target_left := work_area.Right - work_area_margin - Width;
    end;
    if target_top < (work_area.Top + work_area_margin) then
    begin
        target_top := work_area.Top + work_area_margin;
    end;
    if (target_top + Height) > (work_area.Bottom - work_area_margin) then
    begin
        target_top := work_area.Bottom - work_area_margin - Height;
    end;
    if (Left <> target_left) or (Top <> target_top) then
    begin
        SetBounds(target_left, target_top, Width, Height);
    end;
    update_website_link_layout;
end;

procedure TncSettingsForm.normalize_dialog_client_width_for_dpi(const dpi: Integer);
var
    desired_client_width: Integer;
begin
    desired_client_width := scale_ui_for_dpi(c_dialog_width, dpi);
    if desired_client_width <= 0 then
    begin
        Exit;
    end;
    if ClientWidth <> desired_client_width then
    begin
        ClientWidth := desired_client_width;
    end;
end;

procedure TncSettingsForm.DoShow;
var
    dpi: Integer;
begin
    inherited;
    HandleNeeded;
    dpi := get_window_dpi(Handle);
    if dpi <= 0 then
    begin
        dpi := c_nc_base_dpi;
    end;
    if m_scaled_dpi <> dpi then
    begin
        ScaleForPPI(dpi);
        m_scaled_dpi := dpi;
    end;
    normalize_dialog_client_width_for_dpi(dpi);
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
    preview_status_widget;
end;

procedure TncSettingsForm.WMDpiChanged(var Message: TMessage);
var
    dpi: Integer;
begin
    inherited;
    dpi := Integer(Message.WParam) and $FFFF;
    if dpi <= 0 then
    begin
        dpi := get_window_dpi(Handle);
    end;
    if dpi <= 0 then
    begin
        dpi := c_nc_base_dpi;
    end;

    m_scaled_dpi := dpi;
    normalize_dialog_client_width_for_dpi(dpi);
    update_scaled_control_metrics;
    update_dialog_height_for_content;
    update_candidate_preview;
end;

procedure TncSettingsForm.update_scaled_control_metrics;
var
    dpi: Integer;
    fuzzy_rule: TncFuzzyPinyinRule;
    action: TncShortcutAction;

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
    if dpi <= 0 then
    begin
        dpi := c_nc_base_dpi;
    end;
    m_scaled_dpi := dpi;
    update_check_box_metrics(m_chk_full_width_mode);
    update_check_box_metrics(m_chk_fuzzy_pinyin_enabled);
    for fuzzy_rule := Low(TncFuzzyPinyinRule) to
        High(TncFuzzyPinyinRule) do
    begin
        update_check_box_metrics(m_chk_fuzzy_pinyin_rules[fuzzy_rule]);
    end;
    update_check_box_metrics(m_chk_show_status_widget);
    for action := Low(TncShortcutAction) to High(TncShortcutAction) do
        update_check_box_metrics(m_chk_shortcut_enabled[action]);
    update_check_box_metrics(m_chk_log_enabled);
    update_check_box_metrics(m_chk_debug_mode);
    if m_candidate_preview <> nil then
    begin
        m_candidate_preview.Height := scale_ui_for_dpi(
            c_candidate_preview_height, dpi);
        if m_candidate_preview.Parent <> nil then
        begin
            m_candidate_preview.Parent.Height := Max(m_candidate_preview.Parent.Height,
                m_candidate_preview.Top + m_candidate_preview.Height + scale_ui_for_dpi(18, dpi));
        end;
        m_candidate_preview.Invalidate;
    end;
    update_website_link_layout;
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
    m_page_control.Margins.Left := scale_ui(c_page_margin);
    m_page_control.Margins.Top := scale_ui(c_page_margin);
    m_page_control.Margins.Right := scale_ui(c_page_margin);
    m_page_control.Margins.Bottom := 0;
    m_page_control.Style := tsFlatButtons;
    m_page_control.HotTrack := True;
    m_page_control.OnChange := on_page_change;

    m_tab_general := TTabSheet.Create(m_page_control);
    m_tab_general.PageControl := m_page_control;
    m_tab_general.Caption := STabGeneral;

    m_tab_appearance := TTabSheet.Create(m_page_control);
    m_tab_appearance.PageControl := m_page_control;
    m_tab_appearance.Caption := STabAppearance;

    m_tab_fuzzy_pinyin := TTabSheet.Create(m_page_control);
    m_tab_fuzzy_pinyin.PageControl := m_page_control;
    m_tab_fuzzy_pinyin.Caption := STabFuzzyPinyin;

    m_tab_shortcuts := TTabSheet.Create(m_page_control);
    m_tab_shortcuts.PageControl := m_page_control;
    m_tab_shortcuts.Caption := STabShortcuts;

    m_tab_logging := TTabSheet.Create(m_page_control);
    m_tab_logging.PageControl := m_page_control;
    m_tab_logging.Caption := STabLogging;

    m_tab_advanced := TTabSheet.Create(m_page_control);
    m_tab_advanced.PageControl := m_page_control;
    m_tab_advanced.Caption := STabAdvanced;

    m_scroll_general := create_page_scroll_box(Self, m_tab_general);
    m_scroll_appearance := create_page_scroll_box(Self, m_tab_appearance);
    m_scroll_fuzzy_pinyin := create_page_scroll_box(Self, m_tab_fuzzy_pinyin);
    m_scroll_shortcuts := create_page_scroll_box(Self, m_tab_shortcuts);
    m_scroll_logging := create_page_scroll_box(Self, m_tab_logging);
    m_scroll_advanced := create_page_scroll_box(Self, m_tab_advanced);

    m_label_website := TLabel.Create(Self);
    m_label_website.Parent := m_page_control;
    m_label_website.Caption := c_official_website_url;
    m_label_website.Font.Color := RGB(50, 118, 255);
    m_label_website.Font.Style := [fsUnderline];
    m_label_website.Cursor := crHandPoint;
    m_label_website.Hint := c_official_website_url;
    m_label_website.ShowHint := True;
    m_label_website.OnClick := on_website_link_click;
    m_label_website.Anchors := [akTop, akRight];
    update_website_link_layout;
end;

procedure TncSettingsForm.update_website_link_layout;
var
    dpi: Integer;
    tab_strip_height: Integer;
begin
    if (m_page_control = nil) or (m_label_website = nil) then
    begin
        Exit;
    end;

    m_page_control.HandleNeeded;
    dpi := get_window_dpi(Handle);
    if dpi <= 0 then
    begin
        dpi := c_nc_base_dpi;
    end;

    tab_strip_height := m_page_control.DisplayRect.Top;
    m_label_website.Left := m_page_control.ClientWidth - m_label_website.Width - scale_ui_for_dpi(12, dpi);
    m_label_website.Top := Max(0, (tab_strip_height - m_label_website.Height) div 2);
    m_label_website.BringToFront;
end;

procedure TncSettingsForm.configure_buttons;
var
    footer_panel: TPanel;
    footer_line: TBevel;
begin
    footer_panel := TPanel.Create(Self);
    footer_panel.Parent := Self;
    footer_panel.Align := alBottom;
    footer_panel.Height := scale_ui(c_footer_height);
    footer_panel.BevelOuter := bvNone;
    footer_panel.ParentBackground := False;
    footer_panel.Color := RGB(250, 251, 252);

    footer_line := TBevel.Create(footer_panel);
    footer_line.Parent := footer_panel;
    footer_line.Align := alTop;
    footer_line.Shape := bsTopLine;
    footer_line.Height := scale_ui(2);

    m_btn_reset := TncModernButton.Create(Self);
    m_btn_reset.Parent := footer_panel;
    m_btn_reset.Left := scale_ui(18);
    m_btn_reset.Top := scale_ui(10);
    m_btn_reset.Width := scale_ui(96);
    m_btn_reset.Height := scale_ui(c_footer_button_height);
    m_btn_reset.Anchors := [akLeft, akTop];
    m_btn_reset.Caption := SButtonDefaults;
    m_btn_reset.OnClick := on_reset_click;
    m_btn_reset.VisualKind := mbkSubtle;

    m_btn_apply := TncModernButton.Create(Self);
    m_btn_apply.Parent := footer_panel;
    m_btn_apply.Left := ClientWidth - scale_ui(272);
    m_btn_apply.Top := scale_ui(10);
    m_btn_apply.Width := scale_ui(78);
    m_btn_apply.Height := scale_ui(c_footer_button_height);
    m_btn_apply.Anchors := [akTop, akRight];
    m_btn_apply.Caption := SButtonApply;
    m_btn_apply.OnClick := on_apply_click;
    m_btn_apply.VisualKind := mbkSecondary;

    m_btn_ok := TncModernButton.Create(Self);
    m_btn_ok.Parent := footer_panel;
    m_btn_ok.Left := ClientWidth - scale_ui(184);
    m_btn_ok.Top := scale_ui(10);
    m_btn_ok.Width := scale_ui(78);
    m_btn_ok.Height := scale_ui(c_footer_button_height);
    m_btn_ok.Anchors := [akTop, akRight];
    m_btn_ok.Caption := SButtonOK;
    m_btn_ok.Default := True;
    m_btn_ok.OnClick := on_ok_click;
    m_btn_ok.VisualKind := mbkPrimary;

    m_btn_cancel := TncModernButton.Create(Self);
    m_btn_cancel.Parent := footer_panel;
    m_btn_cancel.Left := ClientWidth - scale_ui(96);
    m_btn_cancel.Top := scale_ui(10);
    m_btn_cancel.Width := scale_ui(78);
    m_btn_cancel.Height := scale_ui(c_footer_button_height);
    m_btn_cancel.Anchors := [akTop, akRight];
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
begin
    section_top := scale_ui(18);
    defaults_group := create_section_group(Self, m_scroll_general, SGroupDefaultBehavior, section_top, 194);

    top := scale_ui(c_section_inner_top);
    create_label(Self, defaults_group, SLabelInputMode, top);
    m_combo_input_mode := TComboBox.Create(Self);
    m_combo_input_mode.Parent := defaults_group;
    m_combo_input_mode.Left := scale_ui(c_control_left);
    m_combo_input_mode.Top := top;
    m_combo_input_mode.Width := scale_ui(c_combo_width);
    m_combo_input_mode.Style := csDropDownList;
    m_combo_input_mode.Items.Add(SOptionSimplifiedChineseInput);
    m_combo_input_mode.Items.Add(SOptionTraditionalChineseInput);
    m_combo_input_mode.Items.Add(SOptionEnglishInput);
    m_combo_input_mode.OnChange := mark_dirty;

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, defaults_group, SLabelPinyinInputScheme, top);
    m_combo_pinyin_input_scheme := TComboBox.Create(Self);
    m_combo_pinyin_input_scheme.Parent := defaults_group;
    m_combo_pinyin_input_scheme.Left := scale_ui(c_control_left);
    m_combo_pinyin_input_scheme.Top := top;
    m_combo_pinyin_input_scheme.Width := scale_ui(c_combo_width);
    m_combo_pinyin_input_scheme.Style := csDropDownList;
    m_combo_pinyin_input_scheme.Items.Add(SOptionFullPinyin);
    m_combo_pinyin_input_scheme.Items.Add(SOptionMicrosoftShuangpin);
    m_combo_pinyin_input_scheme.Items.Add(SOptionXiaoheShuangpin);
    m_combo_pinyin_input_scheme.Items.Add(SOptionZiranmaShuangpin);
    m_combo_pinyin_input_scheme.Items.Add(SOptionSogouShuangpin);
    m_combo_pinyin_input_scheme.Items.Add(SOptionZiguangShuangpin);
    m_combo_pinyin_input_scheme.Items.Add(SOptionPinyinJiajiaShuangpin);
    m_combo_pinyin_input_scheme.OnChange := mark_dirty;

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, defaults_group, SLabelPunctuationMode, top);
    m_combo_punctuation_mode := TComboBox.Create(Self);
    m_combo_punctuation_mode.Parent := defaults_group;
    m_combo_punctuation_mode.Left := scale_ui(c_control_left);
    m_combo_punctuation_mode.Top := top;
    m_combo_punctuation_mode.Width := scale_ui(c_combo_width);
    m_combo_punctuation_mode.Style := csDropDownList;
    m_combo_punctuation_mode.Items.Add(SOptionChinese);
    m_combo_punctuation_mode.Items.Add(SOptionEnglish);
    m_combo_punctuation_mode.OnChange := mark_dirty;

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    m_chk_full_width_mode := create_check_box(Self, defaults_group, top, SCheckFullWidthMode, mark_dirty);
end;

procedure TncSettingsForm.add_fuzzy_pinyin_controls;
var
    top: Integer;
    fuzzy_group: TPanel;
    fuzzy_rule: TncFuzzyPinyinRule;
    rule_index: Integer;
    rule_column: Integer;
    rule_row: Integer;
    rule_left: Integer;
    rule_width: Integer;
const
    c_fuzzy_rule_captions: array[TncFuzzyPinyinRule] of string = (
        'z / zh', 'c / ch', 's / sh', 'l / n', 'f / h', 'r / l',
        'an / ang', 'en / eng', 'in / ing', 'ian / iang', 'uan / uang'
    );
begin
    fuzzy_group := create_section_group(Self, m_scroll_fuzzy_pinyin, '',
        scale_ui(18), 158);
    top := scale_ui(c_untitled_section_inner_top);
    m_chk_fuzzy_pinyin_enabled := create_check_box(Self, fuzzy_group, top,
        SCheckEnableFuzzyPinyin, on_fuzzy_pinyin_enabled_click);

    rule_width := (fuzzy_group.ClientWidth - scale_ui(c_label_left * 2)) div 3;
    for fuzzy_rule := Low(TncFuzzyPinyinRule) to High(TncFuzzyPinyinRule) do
    begin
        rule_index := Ord(fuzzy_rule) - Ord(Low(TncFuzzyPinyinRule));
        rule_column := rule_index mod 3;
        rule_row := rule_index div 3;
        rule_left := scale_ui(c_label_left) + (rule_column * rule_width);
        m_chk_fuzzy_pinyin_rules[fuzzy_rule] := create_check_box(Self,
            fuzzy_group, top + scale_ui(28 + (rule_row * 25)),
            c_fuzzy_rule_captions[fuzzy_rule], mark_dirty);
        m_chk_fuzzy_pinyin_rules[fuzzy_rule].Left := rule_left;
        m_chk_fuzzy_pinyin_rules[fuzzy_rule].Width := rule_width;
    end;
    update_fuzzy_pinyin_controls;
end;

procedure TncSettingsForm.add_appearance_controls;
var
    top: Integer;
    section_top: Integer;
    appearance_group: TPanel;
    label_index: Integer;
    size_label_texts: array[0..c_candidate_font_size_level_count - 1] of string;
    candidate_control_width: Integer;
    label_width: Integer;
    tick_center: Integer;
    track_channel_rect: TRect;
    track_channel_left: Integer;
    track_channel_right_inset: Integer;
    track_channel_width: Integer;
    track_label_left: Integer;
begin
    for label_index := Low(size_label_texts) to High(size_label_texts) do
    begin
        size_label_texts[label_index] := '';
    end;
    size_label_texts[Low(size_label_texts)] := SSizeMinimum;
    size_label_texts[c_default_candidate_font_size_level] := SSizeDefault;
    size_label_texts[High(size_label_texts)] := SSizeMaximum;

    section_top := scale_ui(18);
    appearance_group := create_section_group(Self, m_scroll_appearance, '',
        section_top, c_appearance_group_height);

    top := scale_ui(c_untitled_section_inner_top);
    m_chk_show_status_widget := create_check_box(Self, appearance_group, top, SCheckShowStatusWidget, mark_dirty);

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, appearance_group, SLabelStatusWidgetTransparency, top);
    m_track_status_widget_transparency := TTrackBar.Create(Self);
    m_track_status_widget_transparency.Name := 'StatusWidgetTransparency';
    m_track_status_widget_transparency.Parent := appearance_group;
    m_track_status_widget_transparency.SetBounds(scale_ui(c_control_left - 10),
        top - scale_ui(3), scale_ui(280), scale_ui(30));
    m_track_status_widget_transparency.Min := 0;
    m_track_status_widget_transparency.Max := c_max_status_widget_transparency;
    m_track_status_widget_transparency.LineSize := 1;
    m_track_status_widget_transparency.PageSize := 10;
    m_track_status_widget_transparency.TickStyle := tsNone;
    m_label_status_widget_transparency := TLabel.Create(Self);
    m_label_status_widget_transparency.Name := 'StatusWidgetTransparencyValue';
    m_label_status_widget_transparency.Parent := appearance_group;
    m_label_status_widget_transparency.SetBounds(scale_ui(c_control_left + 284),
        top + scale_ui(4), scale_ui(48), scale_ui(24));
    m_label_status_widget_transparency.AutoSize := False;
    m_label_status_widget_transparency.Caption := '0%';
    m_label_status_widget_transparency.Font.Color := RGB(90, 100, 115);
    m_track_status_widget_transparency.OnChange := on_status_widget_transparency_change;

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, appearance_group, SLabelCandidateFont, top);
    candidate_control_width := scale_ui(260);
    m_combo_candidate_font := TComboBox.Create(Self);
    m_combo_candidate_font.Parent := appearance_group;
    m_combo_candidate_font.Left := scale_ui(c_control_left);
    m_combo_candidate_font.Top := top;
    m_combo_candidate_font.Width := candidate_control_width;
    m_combo_candidate_font.Style := csDropDownList;
    populate_candidate_font_combo;
    m_combo_candidate_font.OnChange := on_candidate_appearance_change;

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, appearance_group, SLabelCandidateSize, top);
    m_track_candidate_font_size := TTrackBar.Create(Self);
    m_track_candidate_font_size.Parent := appearance_group;
    m_track_candidate_font_size.Left := scale_ui(c_control_left);
    m_track_candidate_font_size.Top := top - scale_ui(3);
    m_track_candidate_font_size.Width := candidate_control_width;
    m_track_candidate_font_size.Height := scale_ui(34);
    m_track_candidate_font_size.Min := 0;
    m_track_candidate_font_size.Max := High(c_candidate_font_size_levels);
    m_track_candidate_font_size.Frequency := 1;
    m_track_candidate_font_size.LineSize := 1;
    m_track_candidate_font_size.PageSize := 1;
    m_track_candidate_font_size.TickMarks := tmBottomRight;
    m_track_candidate_font_size.TickStyle := tsAuto;
    m_track_candidate_font_size.Position := c_default_candidate_font_size_level;
    m_track_candidate_font_size.OnChange := on_candidate_appearance_change;

    track_channel_rect := Rect(0, 0, m_track_candidate_font_size.Width, 0);
    m_track_candidate_font_size.HandleNeeded;
    SendMessage(m_track_candidate_font_size.Handle, c_tbm_get_channel_rect, 0, LPARAM(@track_channel_rect));
    track_channel_width := track_channel_rect.Right - track_channel_rect.Left;
    if track_channel_width > 0 then
    begin
        track_channel_right_inset := m_track_candidate_font_size.Width - track_channel_rect.Right;
        if track_channel_right_inset < 0 then
        begin
            track_channel_right_inset := 0;
        end;
        m_track_candidate_font_size.Left := m_combo_candidate_font.Left - track_channel_rect.Left;
        m_track_candidate_font_size.Width := candidate_control_width + track_channel_rect.Left +
            track_channel_right_inset;

        track_channel_rect := Rect(0, 0, m_track_candidate_font_size.Width, 0);
        SendMessage(m_track_candidate_font_size.Handle, c_tbm_get_channel_rect, 0, LPARAM(@track_channel_rect));
    end;
    track_channel_left := track_channel_rect.Left;
    track_channel_width := track_channel_rect.Right - track_channel_rect.Left;
    if track_channel_width <= 0 then
    begin
        track_channel_left := 0;
        track_channel_width := m_track_candidate_font_size.Width;
    end;

    label_width := scale_ui(40);
    for label_index := Low(m_candidate_font_size_labels) to High(m_candidate_font_size_labels) do
    begin
        m_candidate_font_size_labels[label_index] := TLabel.Create(Self);
        m_candidate_font_size_labels[label_index].Parent := appearance_group;
        m_candidate_font_size_labels[label_index].Top := top + scale_ui(32);
        m_candidate_font_size_labels[label_index].AutoSize := False;
        m_candidate_font_size_labels[label_index].Width := label_width;
        tick_center := m_track_candidate_font_size.Left + track_channel_left +
            MulDiv(label_index, track_channel_width,
                High(m_candidate_font_size_labels));
        track_label_left := tick_center - (label_width div 2);
        m_candidate_font_size_labels[label_index].Left := track_label_left;
        m_candidate_font_size_labels[label_index].Alignment := taCenter;
        m_candidate_font_size_labels[label_index].Font.Color := RGB(90, 100, 115);
        m_candidate_font_size_labels[label_index].Caption := size_label_texts[label_index];
    end;

    Inc(top, scale_ui(c_row_height + c_general_row_gap + 32));
    create_label(Self, appearance_group, SLabelCandidatePageSize, top);
    m_combo_candidate_page_size := TComboBox.Create(Self);
    m_combo_candidate_page_size.Parent := appearance_group;
    m_combo_candidate_page_size.Left := scale_ui(c_control_left);
    m_combo_candidate_page_size.Top := top;
    m_combo_candidate_page_size.Width := scale_ui(132);
    m_combo_candidate_page_size.Style := csDropDownList;
    populate_candidate_page_size_combo;
    m_combo_candidate_page_size.OnChange := mark_dirty;
    m_chk_candidate_expand_on_paging := create_check_box(Self,
        appearance_group, top, SCheckCandidateExpandOnPaging, mark_dirty);
    m_chk_candidate_expand_on_paging.Left := scale_ui(c_control_left + 148);
    m_chk_candidate_expand_on_paging.Width := scale_ui(230);
    m_chk_candidate_expand_on_paging.Name := 'CandidateExpandOnPaging';

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, appearance_group, SLabelCandidateColorScheme, top);
    m_combo_candidate_color_scheme := TComboBox.Create(Self);
    m_combo_candidate_color_scheme.Parent := appearance_group;
    m_combo_candidate_color_scheme.Left := scale_ui(c_control_left);
    m_combo_candidate_color_scheme.Top := top;
    m_combo_candidate_color_scheme.Width := candidate_control_width;
    m_combo_candidate_color_scheme.Style := csDropDownList;
    populate_candidate_color_scheme_combo;
    m_combo_candidate_color_scheme.OnChange := on_candidate_appearance_change;

    Inc(top, scale_ui(c_row_height + c_general_row_gap));
    create_label(Self, appearance_group, SLabelCandidatePreview, top + scale_ui(12));
    m_candidate_preview := TPaintBox.Create(Self);
    m_candidate_preview.Parent := appearance_group;
    m_candidate_preview.Left := scale_ui(c_control_left);
    m_candidate_preview.Top := top;
    m_candidate_preview.Width := appearance_group.Width - scale_ui(c_control_left + c_label_left);
    m_candidate_preview.Height := scale_ui(c_candidate_preview_height);
    m_candidate_preview.Anchors := [akLeft, akTop, akRight];
    m_candidate_preview.OnPaint := on_candidate_preview_paint;
end;

function TncSettingsForm.shortcut_action_caption(const action: TncShortcutAction): string;
begin
    case action of
        sa_input_mode_toggle:
            Result := SShortcutInputMode;
        sa_punctuation_toggle:
            Result := SShortcutPunctuation;
        sa_dictionary_variant_toggle:
            Result := SShortcutDictionaryVariant;
        sa_full_width_toggle:
            Result := SShortcutFullWidth;
        sa_open_settings:
            Result := SShortcutOpenSettings;
    else
        Result := '';
    end;
end;

procedure TncSettingsForm.populate_shortcut_modifier_combo(const combo: TComboBox);
begin
    if combo = nil then
    begin
        Exit;
    end;
    combo.Items.Clear;
    combo.Items.Add(SShortcutNoModifier);
    combo.Items.Add('Shift');
    combo.Items.Add('Ctrl');
    combo.Items.Add('Alt');
    combo.Items.Add('Ctrl + Shift');
    combo.Items.Add('Ctrl + Alt');
    combo.Items.Add('Shift + Alt');
    combo.Items.Add('Ctrl + Shift + Alt');
end;

procedure TncSettingsForm.populate_shortcut_key_combo(const combo: TComboBox);
var
    key_code: Integer;

    procedure add_key(const value: Word);
    var
        key_name: string;
    begin
        key_name := nc_shortcut_key_name(value);
        if key_name <> '' then
        begin
            combo.Items.AddObject(key_name, TObject(NativeInt(value)));
        end;
    end;
begin
    if combo = nil then
    begin
        Exit;
    end;
    combo.Items.Clear;
    add_key(VK_SHIFT);
    add_key(VK_SPACE);
    add_key(VK_TAB);
    add_key(VK_RETURN);
    add_key(VK_ESCAPE);
    add_key(VK_BACK);
    add_key(VK_PRIOR);
    add_key(VK_NEXT);
    add_key(VK_HOME);
    add_key(VK_END);
    add_key(VK_LEFT);
    add_key(VK_RIGHT);
    add_key(VK_UP);
    add_key(VK_DOWN);
    add_key(VK_INSERT);
    add_key(VK_DELETE);
    for key_code := Ord('A') to Ord('Z') do
    begin
        add_key(key_code);
    end;
    for key_code := Ord('0') to Ord('9') do
    begin
        add_key(key_code);
    end;
    for key_code := VK_F1 to VK_F24 do
    begin
        add_key(key_code);
    end;
    add_key(VK_OEM_COMMA);
    add_key(VK_OEM_PERIOD);
    add_key(VK_OEM_1);
    add_key(VK_OEM_2);
    add_key(VK_OEM_3);
    add_key(VK_OEM_4);
    add_key(VK_OEM_5);
    add_key(VK_OEM_6);
    add_key(VK_OEM_7);
    add_key(VK_OEM_MINUS);
    add_key(VK_OEM_PLUS);
    add_key(VK_ADD);
    add_key(VK_SUBTRACT);
    add_key(VK_MULTIPLY);
    add_key(VK_DIVIDE);
    add_key(VK_DECIMAL);
end;

procedure TncSettingsForm.add_shortcut_controls;
var
    action: TncShortcutAction;
    top: Integer;
    section_top: Integer;
    shortcut_group: TPanel;
    paging_group: TPanel;
    completion_group: TPanel;
    header_label: TLabel;
begin
    section_top := scale_ui(18);
    shortcut_group := create_section_group(Self, m_scroll_shortcuts, '', section_top, 232);

    top := scale_ui(c_untitled_section_inner_top);
    header_label := create_label(Self, shortcut_group, SLabelShortcutAction, top);
    header_label.Font.Style := [fsBold];
    header_label.Font.Color := RGB(90, 100, 115);

    header_label := TLabel.Create(Self);
    header_label.Parent := shortcut_group;
    header_label.Left := scale_ui(c_control_left);
    header_label.Top := top + scale_ui(4);
    header_label.Caption := SLabelShortcutModifier;
    header_label.Font.Style := [fsBold];
    header_label.Font.Color := RGB(90, 100, 115);

    header_label := TLabel.Create(Self);
    header_label.Parent := shortcut_group;
    header_label.Left := scale_ui(c_control_left + 142);
    header_label.Top := top + scale_ui(4);
    header_label.Caption := SLabelShortcutKey;
    header_label.Font.Style := [fsBold];
    header_label.Font.Color := RGB(90, 100, 115);

    Inc(top, scale_ui(28));
    for action := Low(TncShortcutAction) to High(TncShortcutAction) do
    begin
        m_chk_shortcut_enabled[action] := create_check_box(Self, shortcut_group,
            top, shortcut_action_caption(action), shortcut_enabled_changed);
        m_chk_shortcut_enabled[action].Width := scale_ui(c_control_left - c_label_left - 10);
        m_chk_shortcut_enabled[action].Checked := True;

        m_combo_shortcut_modifiers[action] := TComboBox.Create(Self);
        m_combo_shortcut_modifiers[action].Parent := shortcut_group;
        m_combo_shortcut_modifiers[action].Left := scale_ui(c_control_left);
        m_combo_shortcut_modifiers[action].Top := top;
        m_combo_shortcut_modifiers[action].Width := scale_ui(130);
        m_combo_shortcut_modifiers[action].Style := csDropDownList;
        populate_shortcut_modifier_combo(m_combo_shortcut_modifiers[action]);
        m_combo_shortcut_modifiers[action].OnChange := mark_dirty;

        m_combo_shortcut_keys[action] := TComboBox.Create(Self);
        m_combo_shortcut_keys[action].Parent := shortcut_group;
        m_combo_shortcut_keys[action].Left := scale_ui(c_control_left + 142);
        m_combo_shortcut_keys[action].Top := top;
        m_combo_shortcut_keys[action].Width := scale_ui(150);
        m_combo_shortcut_keys[action].Style := csDropDownList;
        populate_shortcut_key_combo(m_combo_shortcut_keys[action]);
        m_combo_shortcut_keys[action].OnChange := mark_dirty;

        Inc(top, scale_ui(36));
    end;

    section_top := shortcut_group.Top + shortcut_group.Height + scale_ui(c_section_gap);
    paging_group := create_section_group(Self, m_scroll_shortcuts,
        SGroupCandidatePaging, section_top, 90);
    top := scale_ui(54);
    create_label(Self, paging_group, SLabelCandidatePageKeys, top);

    header_label := TLabel.Create(Self);
    header_label.Parent := paging_group;
    header_label.AutoSize := False;
    header_label.Left := scale_ui(c_control_left + 172);
    header_label.Top := scale_ui(31);
    header_label.Width := scale_ui(76);
    header_label.Alignment := taCenter;
    header_label.Caption := SLabelCandidatePagePrevious;
    header_label.Font.Color := RGB(90, 100, 115);

    header_label := TLabel.Create(Self);
    header_label.Parent := paging_group;
    header_label.AutoSize := False;
    header_label.Left := scale_ui(c_control_left + 260);
    header_label.Top := scale_ui(31);
    header_label.Width := scale_ui(76);
    header_label.Alignment := taCenter;
    header_label.Caption := SLabelCandidatePageNext;
    header_label.Font.Color := RGB(90, 100, 115);

    m_combo_candidate_page_keys := TComboBox.Create(Self);
    m_combo_candidate_page_keys.Parent := paging_group;
    m_combo_candidate_page_keys.Left := scale_ui(c_control_left);
    m_combo_candidate_page_keys.Top := top;
    m_combo_candidate_page_keys.Width := scale_ui(160);
    m_combo_candidate_page_keys.Style := csDropDownList;
    m_combo_candidate_page_keys.Hint := SCandidatePageKeysHint;
    m_combo_candidate_page_keys.ShowHint := True;
    populate_candidate_page_key_scheme_combo;

    m_panel_candidate_page_previous_key := TPanel.Create(Self);
    m_panel_candidate_page_previous_key.Parent := paging_group;
    m_panel_candidate_page_previous_key.Left := scale_ui(c_control_left + 172);
    m_panel_candidate_page_previous_key.Top := top;
    m_panel_candidate_page_previous_key.Width := scale_ui(76);
    m_panel_candidate_page_previous_key.Height := scale_ui(24);
    m_panel_candidate_page_previous_key.BevelOuter := bvNone;
    m_panel_candidate_page_previous_key.ParentBackground := False;
    m_panel_candidate_page_previous_key.Color := RGB(238, 240, 244);
    m_panel_candidate_page_previous_key.Font.Color := RGB(50, 56, 66);

    m_panel_candidate_page_next_key := TPanel.Create(Self);
    m_panel_candidate_page_next_key.Parent := paging_group;
    m_panel_candidate_page_next_key.Left := scale_ui(c_control_left + 260);
    m_panel_candidate_page_next_key.Top := top;
    m_panel_candidate_page_next_key.Width := scale_ui(76);
    m_panel_candidate_page_next_key.Height := scale_ui(24);
    m_panel_candidate_page_next_key.BevelOuter := bvNone;
    m_panel_candidate_page_next_key.ParentBackground := False;
    m_panel_candidate_page_next_key.Color := RGB(238, 240, 244);
    m_panel_candidate_page_next_key.Font.Color := RGB(50, 56, 66);

    m_combo_candidate_page_keys.OnChange := candidate_page_key_scheme_changed;
    update_candidate_page_key_scheme_preview;

    section_top := paging_group.Top + paging_group.Height + scale_ui(c_section_gap);
    completion_group := create_section_group(Self, m_scroll_shortcuts,
        SGroupOneKeyCompletion, section_top, 90);
    top := scale_ui(54);
    create_label(Self, completion_group, SLabelOneKeyCompletionKey, top);

    m_combo_one_key_completion_key := TComboBox.Create(Self);
    m_combo_one_key_completion_key.Parent := completion_group;
    m_combo_one_key_completion_key.Left := scale_ui(c_control_left);
    m_combo_one_key_completion_key.Top := top;
    m_combo_one_key_completion_key.Width := scale_ui(160);
    m_combo_one_key_completion_key.Style := csDropDownList;
    m_combo_one_key_completion_key.Hint := SOneKeyCompletionHint;
    m_combo_one_key_completion_key.ShowHint := True;
    populate_one_key_completion_key_combo;
    m_combo_one_key_completion_key.ItemIndex := Ord(ock_tab);
    m_combo_one_key_completion_key.OnChange := one_key_completion_key_changed;
end;

procedure TncSettingsForm.populate_candidate_page_key_scheme_combo;
var
    selected_scheme: TncCandidatePageKeyScheme;
begin
    if m_combo_candidate_page_keys = nil then
    begin
        Exit;
    end;

    selected_scheme := get_selected_candidate_page_key_scheme;
    selected_scheme := nc_resolve_candidate_page_key_scheme(selected_scheme,
        get_selected_one_key_completion_key);
    m_combo_candidate_page_keys.Items.BeginUpdate;
    try
        m_combo_candidate_page_keys.Items.Clear;
        m_combo_candidate_page_keys.Items.Add(SPageKeysMinusPlus);
        m_combo_candidate_page_keys.Items.Add(SPageKeysBrackets);
        m_combo_candidate_page_keys.Items.Add(SPageKeysCommaPeriod);
        if get_selected_one_key_completion_key <> ock_tab then
        begin
            m_combo_candidate_page_keys.Items.Add(SPageKeysShiftTab);
        end;
    finally
        m_combo_candidate_page_keys.Items.EndUpdate;
    end;
    m_combo_candidate_page_keys.ItemIndex := Ord(selected_scheme);
end;

procedure TncSettingsForm.populate_one_key_completion_key_combo;
begin
    if m_combo_one_key_completion_key = nil then
    begin
        Exit;
    end;

    m_combo_one_key_completion_key.Items.BeginUpdate;
    try
        m_combo_one_key_completion_key.Items.Clear;
        m_combo_one_key_completion_key.Items.Add('Tab');
        m_combo_one_key_completion_key.Items.Add('`');
    finally
        m_combo_one_key_completion_key.Items.EndUpdate;
    end;
end;

procedure TncSettingsForm.update_candidate_page_key_scheme_preview;
var
    previous_key: string;
    next_key: string;
begin
    if (m_panel_candidate_page_previous_key = nil) or
        (m_panel_candidate_page_next_key = nil) then
    begin
        Exit;
    end;

    case get_selected_candidate_page_key_scheme of
        cpks_brackets:
            begin
                previous_key := '[';
                next_key := ']';
            end;
        cpks_comma_period:
            begin
                previous_key := ',';
                next_key := '.';
            end;
        cpks_shift_tab:
            begin
                previous_key := 'Shift+Tab';
                next_key := 'Tab';
            end;
    else
        previous_key := '-';
        next_key := '=';
    end;

    m_panel_candidate_page_previous_key.Caption := previous_key;
    m_panel_candidate_page_next_key.Caption := next_key;
end;

procedure TncSettingsForm.candidate_page_key_scheme_changed(Sender: TObject);
begin
    update_candidate_page_key_scheme_preview;
    mark_dirty(Sender);
end;

procedure TncSettingsForm.one_key_completion_key_changed(Sender: TObject);
begin
    populate_candidate_page_key_scheme_combo;
    update_candidate_page_key_scheme_preview;
    update_candidate_preview;
    mark_dirty(Sender);
end;

function TncSettingsForm.get_selected_candidate_page_key_scheme:
    TncCandidatePageKeyScheme;
begin
    Result := cpks_minus_plus;
    if (m_combo_candidate_page_keys <> nil) and
        (m_combo_candidate_page_keys.ItemIndex >= Ord(Low(TncCandidatePageKeyScheme))) and
        (m_combo_candidate_page_keys.ItemIndex <= Ord(High(TncCandidatePageKeyScheme))) then
    begin
        Result := TncCandidatePageKeyScheme(
            m_combo_candidate_page_keys.ItemIndex);
    end;
end;

procedure TncSettingsForm.set_candidate_page_key_scheme_combo(
    const scheme: TncCandidatePageKeyScheme);
var
    resolved_scheme: TncCandidatePageKeyScheme;
begin
    if m_combo_candidate_page_keys = nil then
    begin
        Exit;
    end;
    resolved_scheme := nc_resolve_candidate_page_key_scheme(scheme,
        get_selected_one_key_completion_key);
    m_combo_candidate_page_keys.ItemIndex := Ord(resolved_scheme);
    update_candidate_page_key_scheme_preview;
end;

function TncSettingsForm.get_selected_one_key_completion_key:
    TncOneKeyCompletionKey;
begin
    Result := ock_tab;
    if (m_combo_one_key_completion_key <> nil) and
        (m_combo_one_key_completion_key.ItemIndex >=
        Ord(Low(TncOneKeyCompletionKey))) and
        (m_combo_one_key_completion_key.ItemIndex <=
        Ord(High(TncOneKeyCompletionKey))) then
    begin
        Result := TncOneKeyCompletionKey(
            m_combo_one_key_completion_key.ItemIndex);
    end;
end;

procedure TncSettingsForm.set_one_key_completion_key_combo(
    const completion_key: TncOneKeyCompletionKey);
begin
    if m_combo_one_key_completion_key = nil then
    begin
        Exit;
    end;
    m_combo_one_key_completion_key.ItemIndex := Ord(
        nc_normalize_one_key_completion_key(completion_key));
    populate_candidate_page_key_scheme_combo;
    update_candidate_page_key_scheme_preview;
end;

function TncSettingsForm.shortcut_from_controls(const action: TncShortcutAction): TncShortcut;
var
    modifier_index: Integer;
    key_index: Integer;
    key_code: Word;
    shift_down: Boolean;
    ctrl_down: Boolean;
    alt_down: Boolean;
begin
    modifier_index := m_combo_shortcut_modifiers[action].ItemIndex;
    key_index := m_combo_shortcut_keys[action].ItemIndex;
    key_code := 0;
    if key_index >= 0 then
    begin
        key_code := Word(NativeInt(m_combo_shortcut_keys[action].Items.Objects[key_index]));
    end;

    shift_down := modifier_index in [1, 4, 6, 7];
    ctrl_down := modifier_index in [2, 4, 5, 7];
    alt_down := modifier_index in [3, 5, 6, 7];
    Result := nc_make_shortcut(key_code, shift_down, ctrl_down, alt_down);
    Result.disabled := not m_chk_shortcut_enabled[action].Checked;
end;

procedure TncSettingsForm.set_shortcut_controls(const action: TncShortcutAction;
    const shortcut: TncShortcut);
var
    modifier_index: Integer;
    item_index: Integer;
    key_code: Word;
begin
    modifier_index := 0;
    if shortcut.ctrl_down and shortcut.shift_down and shortcut.alt_down then
    begin
        modifier_index := 7;
    end
    else if shortcut.shift_down and shortcut.alt_down then
    begin
        modifier_index := 6;
    end
    else if shortcut.ctrl_down and shortcut.alt_down then
    begin
        modifier_index := 5;
    end
    else if shortcut.ctrl_down and shortcut.shift_down then
    begin
        modifier_index := 4;
    end
    else if shortcut.alt_down then
    begin
        modifier_index := 3;
    end
    else if shortcut.ctrl_down then
    begin
        modifier_index := 2;
    end
    else if shortcut.shift_down then
    begin
        modifier_index := 1;
    end;
    m_combo_shortcut_modifiers[action].ItemIndex := modifier_index;
    m_chk_shortcut_enabled[action].Checked := not shortcut.disabled;
    m_combo_shortcut_modifiers[action].Enabled := not shortcut.disabled;
    m_combo_shortcut_keys[action].Enabled := not shortcut.disabled;

    key_code := shortcut.key_code;
    m_combo_shortcut_keys[action].ItemIndex := -1;
    for item_index := 0 to m_combo_shortcut_keys[action].Items.Count - 1 do
    begin
        if Word(NativeInt(m_combo_shortcut_keys[action].Items.Objects[item_index])) = key_code then
        begin
            m_combo_shortcut_keys[action].ItemIndex := item_index;
            Break;
        end;
    end;
end;

procedure TncSettingsForm.shortcut_enabled_changed(Sender: TObject);
var
    action: TncShortcutAction;
begin
    for action := Low(TncShortcutAction) to High(TncShortcutAction) do
    begin
        m_combo_shortcut_modifiers[action].Enabled := m_chk_shortcut_enabled[action].Checked;
        m_combo_shortcut_keys[action].Enabled := m_chk_shortcut_enabled[action].Checked;
    end;
    mark_dirty(Sender);
end;

procedure TncSettingsForm.load_shortcut_controls(const config: TncShortcutConfig);
var
    normalized_config: TncShortcutConfig;
    action: TncShortcutAction;
begin
    normalized_config := config;
    nc_normalize_shortcut_config(normalized_config);
    for action := Low(TncShortcutAction) to High(TncShortcutAction) do
    begin
        set_shortcut_controls(action, nc_shortcut_for_action(normalized_config, action));
    end;
end;

procedure TncSettingsForm.add_logging_controls;
var
    top: Integer;
    section_top: Integer;
    logging_group: TPanel;
    files_group: TPanel;
begin
    section_top := scale_ui(18);
    logging_group := create_section_group(Self, m_scroll_logging, SGroupLogging, section_top, 152);

    top := scale_ui(c_section_inner_top);
    m_chk_log_enabled := create_check_box(Self, logging_group, top, SCheckEnableLogging, mark_dirty);

    Inc(top, scale_ui(c_row_height + c_row_gap));
    create_label(Self, logging_group, SLabelLogLevel, top);
    m_combo_log_level := TComboBox.Create(Self);
    m_combo_log_level.Parent := logging_group;
    m_combo_log_level.Left := scale_ui(c_control_left);
    m_combo_log_level.Top := top;
    m_combo_log_level.Width := scale_ui(c_combo_width);
    m_combo_log_level.Style := csDropDownList;
    m_combo_log_level.Items.Add(SOptionLogDebug);
    m_combo_log_level.Items.Add(SOptionLogInfo);
    m_combo_log_level.Items.Add(SOptionLogWarn);
    m_combo_log_level.Items.Add(SOptionLogError);
    m_combo_log_level.OnChange := mark_dirty;

    Inc(top, scale_ui(c_row_height + c_row_gap));
    create_label(Self, logging_group, SLabelMaxLogSize, top);
    m_edit_log_max_size_kb := TEdit.Create(Self);
    m_edit_log_max_size_kb.Parent := logging_group;
    m_edit_log_max_size_kb.Left := scale_ui(c_control_left);
    m_edit_log_max_size_kb.Top := top;
    m_edit_log_max_size_kb.Width := scale_ui(c_edit_width);
    configure_numeric_edit(m_edit_log_max_size_kb, '64..1048576');
    m_edit_log_max_size_kb.OnChange := mark_dirty;

    section_top := logging_group.Top + logging_group.Height + scale_ui(c_section_gap);
    files_group := create_section_group(Self, m_scroll_logging, SGroupLogFiles, section_top, 108);

    top := scale_ui(c_section_inner_top);
    create_label(Self, files_group, SLabelLogPath, top);
    m_edit_log_path := TEdit.Create(Self);
    m_edit_log_path.Parent := files_group;
    m_edit_log_path.Left := scale_ui(c_control_left);
    m_edit_log_path.Top := top;
    m_edit_log_path.Width := scale_ui(c_path_edit_width);
    configure_path_edit(m_edit_log_path, get_default_log_path);
    m_edit_log_path.OnChange := mark_dirty;
    m_btn_log_path := create_browse_button(Self, files_group, top, on_browse_log_path);

    Inc(top, scale_ui(c_row_height + 2));
    m_btn_open_log_folder := create_action_button(Self, files_group, scale_ui(c_control_left), top,
        SButtonOpenLogFolder, on_open_log_folder);
    m_btn_log_defaults := create_action_button(Self, files_group, scale_ui(c_control_left + c_action_button_width + 12), top,
        SButtonUseDefaultLogging, on_log_defaults_click);

end;

procedure TncSettingsForm.add_advanced_controls;
var
    top: Integer;
    section_top: Integer;
    debug_group: TPanel;
    tools_group: TPanel;
    debug_hint: TLabel;
begin
    section_top := scale_ui(18);
    debug_group := create_section_group(Self, m_scroll_advanced, SGroupDebug, section_top, 154);

    top := scale_ui(c_section_inner_top);
    m_chk_debug_mode := create_check_box(Self, debug_group, top, SCheckEnableDebugMode, mark_dirty);
    debug_hint := create_hint_label(Self, debug_group, SHintDebugMode, scale_ui(c_label_left),
        top + scale_ui(c_row_height + 4), scale_ui(c_hint_width));
    top := debug_hint.Top + debug_hint.Height + scale_ui(8);
    m_btn_clear_user_dictionary := create_action_button(Self, debug_group, scale_ui(c_label_left), top,
        SButtonClearUserDictionary, on_clear_user_dictionary_click);
    debug_group.Height := Max(debug_group.Height,
        m_btn_clear_user_dictionary.Top + m_btn_clear_user_dictionary.Height + scale_ui(14));

    section_top := debug_group.Top + debug_group.Height + scale_ui(c_section_gap);
    tools_group := create_section_group(Self, m_scroll_advanced, SGroupConfigTools, section_top, 134);

    top := scale_ui(c_section_inner_top);
    m_btn_open_config_folder := create_action_button(Self, tools_group, scale_ui(c_label_left), top,
        SButtonOpenConfigFolder, on_open_config_folder);
    m_btn_open_config_file := create_action_button(Self, tools_group, scale_ui(c_label_left + c_action_button_width + 12), top,
        SButtonOpenConfigFile, on_open_config_file);

    m_hint_advanced := create_hint_label(Self, tools_group, SHintAdvanced, scale_ui(c_label_left), top + scale_ui(c_row_height + 8), scale_ui(c_hint_width));
end;

procedure TncSettingsForm.on_clear_user_dictionary_click(Sender: TObject);
begin
    if MessageBox(Handle, PChar(SConfirmClearUserDictionary), PChar(Caption),
        MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) <> IDYES then
    begin
        Exit;
    end;

    if (not Assigned(m_clear_user_dictionary_proc)) or
        (not m_clear_user_dictionary_proc()) then
    begin
        MessageBox(Handle, PChar(SClearUserDictionaryFailed), PChar(Caption),
            MB_OK or MB_ICONERROR);
        Exit;
    end;

    MessageBox(Handle, PChar(SClearUserDictionarySucceeded), PChar(Caption),
        MB_OK or MB_ICONINFORMATION);
end;

procedure TncSettingsForm.mark_dirty(Sender: TObject);
begin
    m_dirty := True;
    update_logging_controls;
    update_apply_button;
end;

procedure TncSettingsForm.on_status_widget_transparency_change(Sender: TObject);
begin
    m_label_status_widget_transparency.Caption :=
        IntToStr(m_track_status_widget_transparency.Position) + '%';
    if m_loading_controls then Exit;
    mark_dirty(Sender);
    preview_status_widget;
end;

procedure TncSettingsForm.on_page_change(Sender: TObject);
begin
    preview_status_widget;
end;

procedure TncSettingsForm.preview_status_widget;
begin
    if m_loading_controls or (m_track_status_widget_transparency = nil) or
        not Assigned(m_preview_status_widget_proc) then Exit;
    m_preview_status_widget_proc(m_track_status_widget_transparency.Position,
        Visible and (m_page_control.ActivePage = m_tab_appearance));
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

procedure TncSettingsForm.update_fuzzy_pinyin_controls;
var
    enabled: Boolean;
    rule: TncFuzzyPinyinRule;
begin
    enabled := (m_chk_fuzzy_pinyin_enabled <> nil) and
        m_chk_fuzzy_pinyin_enabled.Checked;
    for rule := Low(TncFuzzyPinyinRule) to High(TncFuzzyPinyinRule) do
    begin
        if m_chk_fuzzy_pinyin_rules[rule] <> nil then
        begin
            m_chk_fuzzy_pinyin_rules[rule].Enabled := enabled;
        end;
    end;
end;

procedure TncSettingsForm.on_fuzzy_pinyin_enabled_click(Sender: TObject);
begin
    update_fuzzy_pinyin_controls;
    mark_dirty(Sender);
end;

procedure TncSettingsForm.restore_current_page_defaults;
var
    default_engine_config: TncEngineConfig;
    default_log_config: TncLogConfig;
    candidate_font_name: string;
    fuzzy_rule: TncFuzzyPinyinRule;
    restored: Boolean;
begin
    default_engine_config := build_default_engine_config_value;
    default_log_config := build_default_log_config_value;
    restored := True;

    if m_page_control.ActivePage = m_tab_general then
    begin
        if default_engine_config.input_mode = im_english then
        begin
            m_combo_input_mode.ItemIndex := 2;
        end
        else if default_engine_config.dictionary_variant = dv_traditional then
        begin
            m_combo_input_mode.ItemIndex := 1;
        end
        else
        begin
            m_combo_input_mode.ItemIndex := 0;
        end;
        m_combo_pinyin_input_scheme.ItemIndex := Ord(default_engine_config.pinyin_input_scheme);
        m_combo_punctuation_mode.ItemIndex := Ord(not default_engine_config.punctuation_full_width);
        m_chk_full_width_mode.Checked := default_engine_config.full_width_mode;
    end
    else if m_page_control.ActivePage = m_tab_appearance then
    begin
        m_chk_show_status_widget.Checked := True;
        m_track_status_widget_transparency.Position := c_default_status_widget_transparency;
        candidate_font_name := Trim(default_engine_config.candidate_font_name);
        if candidate_font_name = '' then
        begin
            candidate_font_name := c_default_candidate_font_name;
        end;
        m_combo_candidate_font.ItemIndex := m_combo_candidate_font.Items.IndexOf(candidate_font_name);
        if (m_combo_candidate_font.ItemIndex < 0) and (m_combo_candidate_font.Items.Count > 0) then
        begin
            m_combo_candidate_font.ItemIndex := 0;
        end;
        set_candidate_font_size_slider(default_engine_config.candidate_font_size);
        set_candidate_page_size_combo(default_engine_config.candidate_page_size);
        m_chk_candidate_expand_on_paging.Checked :=
            default_engine_config.candidate_expand_on_paging;
        set_candidate_color_scheme_combo(default_engine_config.candidate_color_scheme);
    end
    else if m_page_control.ActivePage = m_tab_fuzzy_pinyin then
    begin
        m_chk_fuzzy_pinyin_enabled.Checked :=
            default_engine_config.fuzzy_pinyin_enabled;
        for fuzzy_rule := Low(TncFuzzyPinyinRule) to
            High(TncFuzzyPinyinRule) do
        begin
            m_chk_fuzzy_pinyin_rules[fuzzy_rule].Checked :=
                fuzzy_rule in default_engine_config.fuzzy_pinyin_rules;
        end;
    end
    else if m_page_control.ActivePage = m_tab_shortcuts then
    begin
        load_shortcut_controls(default_engine_config.shortcuts);
        set_one_key_completion_key_combo(
            default_engine_config.one_key_completion_key);
        set_candidate_page_key_scheme_combo(
            default_engine_config.candidate_page_key_scheme);
    end
    else if m_page_control.ActivePage = m_tab_logging then
    begin
        m_chk_log_enabled.Checked := default_log_config.enabled;
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
        m_edit_log_max_size_kb.Text := IntToStr(default_log_config.max_size_kb);
        m_edit_log_path.Text := default_log_config.log_path;
    end
    else if m_page_control.ActivePage = m_tab_advanced then
    begin
        m_chk_debug_mode.Checked := default_engine_config.debug_mode;
    end
    else
    begin
        restored := False;
    end;

    if not restored then
    begin
        Exit;
    end;

    m_dirty := True;
    update_logging_controls;
    update_fuzzy_pinyin_controls;
    update_candidate_preview;
    update_apply_button;
end;

function settings_font_can_render_chinese(const font_name: string): Boolean;
const
    c_chinese_sample = '中文候选你好世界输入法';
    c_missing_glyph = WORD($FFFF);
var
    bitmap: TBitmap;
    glyphs: TArray<WORD>;
    glyph_count: DWORD;
    old_font: HGDIOBJ;
    glyph_index: Integer;
begin
    Result := False;
    if Trim(font_name) = '' then
    begin
        Exit;
    end;
    if Trim(font_name)[1] = '@' then
    begin
        Exit;
    end;

    bitmap := TBitmap.Create;
    try
        bitmap.SetSize(1, 1);
        bitmap.Canvas.Font.Name := font_name;
        bitmap.Canvas.Font.Charset := DEFAULT_CHARSET;
        bitmap.Canvas.Font.Height := -12;

        SetLength(glyphs, Length(c_chinese_sample));
        old_font := SelectObject(bitmap.Canvas.Handle, bitmap.Canvas.Font.Handle);
        try
            glyph_count := GetGlyphIndicesW(bitmap.Canvas.Handle, PWideChar(c_chinese_sample),
                Length(c_chinese_sample), @glyphs[0], GGI_MARK_NONEXISTING_GLYPHS);
            if glyph_count = GDI_ERROR then
            begin
                Exit;
            end;

            for glyph_index := 0 to High(glyphs) do
            begin
                if glyphs[glyph_index] = c_missing_glyph then
                begin
                    Exit;
                end;
            end;

            Result := True;
        finally
            if (old_font <> 0) and (old_font <> HGDIOBJ(GDI_ERROR)) then
            begin
                SelectObject(bitmap.Canvas.Handle, old_font);
            end;
        end;
    finally
        bitmap.Free;
    end;
end;

procedure TncSettingsForm.populate_candidate_font_combo;
var
    font_index: Integer;
    font_name: string;
begin
    if m_combo_candidate_font = nil then
    begin
        Exit;
    end;

    m_combo_candidate_font.Items.BeginUpdate;
    try
        m_combo_candidate_font.Items.Clear;
        m_combo_candidate_font.Sorted := True;
        for font_index := 0 to Screen.Fonts.Count - 1 do
        begin
            font_name := Screen.Fonts[font_index];
            if settings_font_can_render_chinese(font_name) then
            begin
                m_combo_candidate_font.Items.Add(font_name);
            end;
        end;
        if m_combo_candidate_font.Items.IndexOf(c_default_candidate_font_name) < 0 then
        begin
            m_combo_candidate_font.Items.Add(c_default_candidate_font_name);
        end;
    finally
        m_combo_candidate_font.Items.EndUpdate;
    end;
end;

procedure TncSettingsForm.populate_candidate_color_scheme_combo;
var
    color_scheme: Integer;
    theme: TncCandidateColorTheme;
begin
    if m_combo_candidate_color_scheme = nil then
    begin
        Exit;
    end;

    m_combo_candidate_color_scheme.Items.BeginUpdate;
    try
        m_combo_candidate_color_scheme.Items.Clear;
        for color_scheme := c_min_candidate_color_scheme to c_max_candidate_color_scheme do
        begin
            theme := nc_candidate_color_theme(color_scheme);
            m_combo_candidate_color_scheme.Items.Add(theme.name);
        end;
    finally
        m_combo_candidate_color_scheme.Items.EndUpdate;
    end;
end;

procedure TncSettingsForm.populate_candidate_page_size_combo;
var
    page_size: Integer;
begin
    if m_combo_candidate_page_size = nil then
    begin
        Exit;
    end;

    m_combo_candidate_page_size.Items.BeginUpdate;
    try
        m_combo_candidate_page_size.Items.Clear;
        for page_size := c_min_candidate_page_size to c_max_candidate_page_size do
        begin
            m_combo_candidate_page_size.Items.Add(
                Format(SCandidatePageSizeItem, [page_size]));
        end;
    finally
        m_combo_candidate_page_size.Items.EndUpdate;
    end;
end;

function TncSettingsForm.get_candidate_font_size_from_slider: Integer;
var
    level_index: Integer;
begin
    Result := c_default_candidate_font_size;
    if m_track_candidate_font_size <> nil then
    begin
        level_index := m_track_candidate_font_size.Position;
        if level_index < Low(c_candidate_font_size_levels) then
        begin
            level_index := Low(c_candidate_font_size_levels);
        end
        else if level_index > High(c_candidate_font_size_levels) then
        begin
            level_index := High(c_candidate_font_size_levels);
        end;
        Result := c_candidate_font_size_levels[level_index];
    end;
end;

procedure TncSettingsForm.set_candidate_font_size_slider(const font_size: Integer);
var
    effective_size: Integer;
    level_index: Integer;
    best_level_index: Integer;
    best_distance: Integer;
    distance: Integer;
begin
    if m_track_candidate_font_size = nil then
    begin
        Exit;
    end;

    effective_size := font_size;
    if effective_size < c_min_candidate_font_size then
    begin
        effective_size := c_min_candidate_font_size;
    end
    else if effective_size > c_max_candidate_font_size then
    begin
        effective_size := c_max_candidate_font_size;
    end;
    best_level_index := Low(c_candidate_font_size_levels);
    best_distance := MaxInt;
    for level_index := Low(c_candidate_font_size_levels) to
        High(c_candidate_font_size_levels) do
    begin
        distance := Abs(c_candidate_font_size_levels[level_index] -
            effective_size);
        if distance < best_distance then
        begin
            best_distance := distance;
            best_level_index := level_index;
        end;
    end;
    m_track_candidate_font_size.Position := best_level_index;
end;

function TncSettingsForm.get_selected_candidate_page_size: Integer;
begin
    Result := c_default_candidate_page_size;
    if (m_combo_candidate_page_size <> nil) and
        (m_combo_candidate_page_size.ItemIndex >= 0) then
    begin
        Result := c_min_candidate_page_size +
            m_combo_candidate_page_size.ItemIndex;
    end;

    if (Result < c_min_candidate_page_size) or
        (Result > c_max_candidate_page_size) then
    begin
        Result := c_default_candidate_page_size;
    end;
end;

procedure TncSettingsForm.set_candidate_page_size_combo(
    const page_size: Integer);
var
    effective_page_size: Integer;
    item_index: Integer;
begin
    if m_combo_candidate_page_size = nil then
    begin
        Exit;
    end;

    effective_page_size := page_size;
    if (effective_page_size < c_min_candidate_page_size) or
        (effective_page_size > c_max_candidate_page_size) then
    begin
        effective_page_size := c_default_candidate_page_size;
    end;
    item_index := effective_page_size - c_min_candidate_page_size;
    if (item_index >= 0) and
        (item_index < m_combo_candidate_page_size.Items.Count) then
    begin
        m_combo_candidate_page_size.ItemIndex := item_index;
    end;
end;

function TncSettingsForm.get_selected_candidate_font_name: string;
begin
    Result := c_default_candidate_font_name;
    if m_combo_candidate_font <> nil then
    begin
        Result := Trim(m_combo_candidate_font.Text);
        if Result = '' then
        begin
            Result := c_default_candidate_font_name;
        end;
    end;
end;

function TncSettingsForm.get_selected_candidate_color_scheme: Integer;
begin
    Result := c_default_candidate_color_scheme;
    if (m_combo_candidate_color_scheme <> nil) and
        (m_combo_candidate_color_scheme.ItemIndex >= 0) then
    begin
        Result := nc_normalize_candidate_color_scheme(m_combo_candidate_color_scheme.ItemIndex +
            c_min_candidate_color_scheme);
    end;
end;

procedure TncSettingsForm.set_candidate_color_scheme_combo(const color_scheme: Integer);
var
    normalized_scheme: Integer;
    item_index: Integer;
begin
    if m_combo_candidate_color_scheme = nil then
    begin
        Exit;
    end;

    normalized_scheme := nc_normalize_candidate_color_scheme(color_scheme);
    item_index := normalized_scheme - c_min_candidate_color_scheme;
    if (item_index >= 0) and (item_index < m_combo_candidate_color_scheme.Items.Count) then
    begin
        m_combo_candidate_color_scheme.ItemIndex := item_index;
    end
    else if m_combo_candidate_color_scheme.Items.Count > 0 then
    begin
        m_combo_candidate_color_scheme.ItemIndex := c_default_candidate_color_scheme -
            c_min_candidate_color_scheme;
    end;
end;

procedure TncSettingsForm.update_candidate_preview;
begin
    if m_candidate_preview <> nil then
    begin
        m_candidate_preview.Invalidate;
    end;
end;

procedure TncSettingsForm.on_candidate_appearance_change(Sender: TObject);
begin
    update_candidate_preview;
    mark_dirty(Sender);
end;

procedure TncSettingsForm.on_candidate_preview_paint(Sender: TObject);
const
    c_preview_preedit_text = 'luoxiayu';
    c_preview_candidate_texts: array[0..2] of string = (
        '落霞', '落下', '落');
    c_preview_completion_text = '落霞与孤鹜齐飞';
var
    paint_box: TPaintBox;
    canvas: TCanvas;
    bounds: TRect;
    candidates: TncCandidateList;
    completion: TncOneKeyCompletion;
    item_index: Integer;
    font_size: Integer;
    dpi: Integer;
begin
    if not (Sender is TPaintBox) then
    begin
        Exit;
    end;

    paint_box := TPaintBox(Sender);
    canvas := paint_box.Canvas;
    bounds := paint_box.ClientRect;
    canvas.Brush.Color := clWhite;
    canvas.FillRect(bounds);

    font_size := get_candidate_font_size_from_slider;
    dpi := get_control_scale_dpi(paint_box);
    if dpi <= 0 then
    begin
        dpi := m_scaled_dpi;
    end;
    if dpi <= 0 then
    begin
        dpi := c_nc_base_dpi;
    end;

    if m_candidate_preview_window = nil then
    begin
        m_candidate_preview_window := TncCandidateWindow.create;
    end;

    SetLength(candidates, Length(c_preview_candidate_texts));
    for item_index := Low(c_preview_candidate_texts) to
        High(c_preview_candidate_texts) do
    begin
        candidates[item_index].text := c_preview_candidate_texts[item_index];
        candidates[item_index].source := cs_rule;
        candidates[item_index].display_kind := cdk_default;
    end;

    completion := Default(TncOneKeyCompletion);
    completion.text := c_preview_completion_text;
    completion.full_pinyin := 'luoxiayuguwuqifei';

    m_candidate_preview_window.apply_appearance(
        get_selected_candidate_font_name, font_size,
        get_selected_candidate_color_scheme);
    m_candidate_preview_window.prepare_preview(dpi,
        bounds.Right - bounds.Left);
    m_candidate_preview_window.update_candidates(candidates, 0, 1, 0,
        c_preview_preedit_text, completion,
        get_selected_one_key_completion_key, False);
    m_candidate_preview_window.PaintTo(canvas.Handle, bounds.Left, bounds.Top);
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
var
    candidate_font_name: string;
    fuzzy_rule: TncFuzzyPinyinRule;
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
    if m_combo_pinyin_input_scheme <> nil then
    begin
        m_combo_pinyin_input_scheme.ItemIndex := Ord(m_engine_config.pinyin_input_scheme);
        if (m_combo_pinyin_input_scheme.ItemIndex < 0) or
            (m_combo_pinyin_input_scheme.ItemIndex >= m_combo_pinyin_input_scheme.Items.Count) then
        begin
            m_combo_pinyin_input_scheme.ItemIndex := Ord(pis_full_pinyin);
        end;
    end;
    if m_chk_fuzzy_pinyin_enabled <> nil then
    begin
        m_chk_fuzzy_pinyin_enabled.Checked :=
            m_engine_config.fuzzy_pinyin_enabled;
    end;
    for fuzzy_rule := Low(TncFuzzyPinyinRule) to
        High(TncFuzzyPinyinRule) do
    begin
        if m_chk_fuzzy_pinyin_rules[fuzzy_rule] <> nil then
        begin
            m_chk_fuzzy_pinyin_rules[fuzzy_rule].Checked :=
                fuzzy_rule in m_engine_config.fuzzy_pinyin_rules;
        end;
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
    if m_track_status_widget_transparency <> nil then
    begin
        m_loading_controls := True;
        try
            m_track_status_widget_transparency.Position := m_status_widget_transparency;
            m_label_status_widget_transparency.Caption := IntToStr(m_status_widget_transparency) + '%';
        finally
            m_loading_controls := False;
        end;
    end;
    if m_combo_candidate_font <> nil then
    begin
        candidate_font_name := Trim(m_engine_config.candidate_font_name);
        if candidate_font_name = '' then
        begin
            candidate_font_name := c_default_candidate_font_name;
        end;
        m_combo_candidate_font.ItemIndex := m_combo_candidate_font.Items.IndexOf(candidate_font_name);
        if m_combo_candidate_font.ItemIndex < 0 then
        begin
            // Font capability probing is conservative and can reject valid
            // third-party CJK faces. Preserve the configured font so applying
            // an unrelated setting never silently replaces it.
            m_combo_candidate_font.ItemIndex :=
                m_combo_candidate_font.Items.Add(candidate_font_name);
        end;
    end;
    set_candidate_font_size_slider(m_engine_config.candidate_font_size);
    set_candidate_page_size_combo(m_engine_config.candidate_page_size);
    m_chk_candidate_expand_on_paging.Checked :=
        m_engine_config.candidate_expand_on_paging;
    set_candidate_color_scheme_combo(m_engine_config.candidate_color_scheme);
    load_shortcut_controls(m_engine_config.shortcuts);
    set_one_key_completion_key_combo(
        m_engine_config.one_key_completion_key);
    set_candidate_page_key_scheme_combo(
        m_engine_config.candidate_page_key_scheme);
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
    update_fuzzy_pinyin_controls;
    update_candidate_preview;
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
    shortcut_config: TncShortcutConfig;
    shortcut_value: TncShortcut;
    shortcut_issue: TncShortcutValidationIssue;
    shortcut_key_name: string;
    action_index: Integer;
    other_index: Integer;
    action: TncShortcutAction;
    other_action: TncShortcutAction;
    fuzzy_rule: TncFuzzyPinyinRule;
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

    case m_combo_pinyin_input_scheme.ItemIndex of
        Ord(pis_microsoft_shuangpin):
            next_config.pinyin_input_scheme := pis_microsoft_shuangpin;
        Ord(pis_xiaohe_shuangpin):
            next_config.pinyin_input_scheme := pis_xiaohe_shuangpin;
        Ord(pis_ziranma_shuangpin):
            next_config.pinyin_input_scheme := pis_ziranma_shuangpin;
        Ord(pis_sogou_shuangpin):
            next_config.pinyin_input_scheme := pis_sogou_shuangpin;
        Ord(pis_ziguang_shuangpin):
            next_config.pinyin_input_scheme := pis_ziguang_shuangpin;
        Ord(pis_pinyinjiajia_shuangpin):
            next_config.pinyin_input_scheme := pis_pinyinjiajia_shuangpin;
    else
        next_config.pinyin_input_scheme := pis_full_pinyin;
    end;

    next_config.fuzzy_pinyin_enabled :=
        m_chk_fuzzy_pinyin_enabled.Checked;
    next_config.fuzzy_pinyin_rules := [];
    for fuzzy_rule := Low(TncFuzzyPinyinRule) to
        High(TncFuzzyPinyinRule) do
    begin
        if m_chk_fuzzy_pinyin_rules[fuzzy_rule].Checked then
        begin
            Include(next_config.fuzzy_pinyin_rules, fuzzy_rule);
        end;
    end;

    next_config.full_width_mode := m_chk_full_width_mode.Checked;
    next_config.punctuation_full_width := m_combo_punctuation_mode.ItemIndex <> 1;
    next_config.enable_segment_candidates := True;
    next_config.segment_head_only_multi_syllable := True;
    next_config.enable_ctrl_space_toggle := False;
    next_config.enable_shift_space_full_width_toggle := True;
    next_config.enable_ctrl_period_punct_toggle := True;
    next_config.candidate_font_name := get_selected_candidate_font_name;
    next_config.candidate_font_size := get_candidate_font_size_from_slider;
    next_config.candidate_page_size := get_selected_candidate_page_size;
    next_config.candidate_expand_on_paging :=
        m_chk_candidate_expand_on_paging.Checked;
    next_config.one_key_completion_key :=
        get_selected_one_key_completion_key;
    next_config.candidate_page_key_scheme :=
        nc_resolve_candidate_page_key_scheme(
        get_selected_candidate_page_key_scheme,
        next_config.one_key_completion_key);
    next_config.candidate_color_scheme := get_selected_candidate_color_scheme;
    shortcut_config := nc_default_shortcut_config;
    for action_index := Ord(Low(TncShortcutAction)) to Ord(High(TncShortcutAction)) do
    begin
        action := TncShortcutAction(action_index);
        shortcut_value := shortcut_from_controls(action);
        shortcut_issue := nc_get_shortcut_validation_issue(shortcut_value);
        if (not shortcut_value.disabled) and (shortcut_issue <> svi_none) then
        begin
            case shortcut_issue of
                svi_missing_key:
                    error_text := Format(SShortcutMissingKey, [shortcut_action_caption(action)]);
                svi_invalid_modifier_key:
                    error_text := Format(SShortcutInvalidModifierKey, [shortcut_action_caption(action)]);
                svi_unmodified_regular_key:
                    begin
                        shortcut_key_name := nc_shortcut_key_name(shortcut_value.key_code);
                        if shortcut_key_name = '' then
                        begin
                            shortcut_key_name := '该按键';
                        end;
                        error_text := Format(SShortcutNeedsModifier,
                            [shortcut_action_caption(action), shortcut_key_name]);
                    end;
            else
                error_text := Format(SShortcutInvalid, [shortcut_action_caption(action)]);
            end;
            Result := False;
            Exit;
        end;
        nc_set_shortcut_for_action(shortcut_config, action, shortcut_value);
    end;
    for action_index := Ord(Low(TncShortcutAction)) to Ord(High(TncShortcutAction)) - 1 do
    begin
        action := TncShortcutAction(action_index);
        if nc_shortcut_for_action(shortcut_config, action).disabled then Continue;
        for other_index := action_index + 1 to Ord(High(TncShortcutAction)) do
        begin
            other_action := TncShortcutAction(other_index);
            if nc_shortcut_for_action(shortcut_config, other_action).disabled then Continue;
            if nc_shortcut_equal(nc_shortcut_for_action(shortcut_config, action),
                nc_shortcut_for_action(shortcut_config, other_action)) then
            begin
                error_text := Format(SShortcutConflict, [shortcut_action_caption(action),
                    shortcut_action_caption(other_action),
                    nc_shortcut_to_text(nc_shortcut_for_action(shortcut_config, action))]);
                Result := False;
                Exit;
            end;
        end;
    end;
    next_config.shortcuts := shortcut_config;
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

procedure TncSettingsForm.on_website_link_click(Sender: TObject);
begin
    ShellExecute(Handle, 'open', PChar(c_official_website_url), nil, nil, SW_SHOWNORMAL);
end;

procedure TncSettingsForm.on_reset_click(Sender: TObject);
var
    active_page_caption: string;
begin
    if (m_page_control = nil) or (m_page_control.ActivePage = nil) then
    begin
        Exit;
    end;

    active_page_caption := m_page_control.ActivePage.Caption;
    if Application.MessageBox(PChar(Format(SConfirmRestoreDefaults, [active_page_caption])),
        PChar(get_settings_window_title),
        MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
        restore_current_page_defaults;
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
        Application.MessageBox(PChar(error_text), PChar(get_settings_window_title),
            MB_OK or MB_ICONWARNING);
        Exit;
    end;

    m_engine_config := next_config;
    m_log_config := next_log_config;
    m_status_widget_visible := next_status_widget_visible;
    m_status_widget_transparency := m_track_status_widget_transparency.Position;
    if Assigned(m_apply_proc) then
    begin
        m_apply_proc(m_engine_config, m_log_config, m_status_widget_visible, m_status_widget_transparency);
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
