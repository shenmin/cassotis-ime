unit nc_settings_form;

interface

uses
    System.SysUtils,
    System.Classes,
    Winapi.Windows,
    Vcl.Forms,
    Vcl.Controls,
    Vcl.StdCtrls,
    Vcl.ComCtrls,
    Vcl.ExtCtrls,
    Vcl.Graphics,
    Vcl.Dialogs,
    Vcl.FileCtrl,
    nc_types;

type
    TncApplySettingsProc = reference to procedure(const engine_config: TncEngineConfig;
        const log_config: TncLogConfig; const status_widget_visible: Boolean);

    TncSettingsForm = class(TForm)
    private
        m_page_control: TPageControl;
        m_tab_general: TTabSheet;
        m_tab_candidate: TTabSheet;
        m_tab_hotkeys: TTabSheet;
        m_tab_appearance: TTabSheet;
        m_tab_ai: TTabSheet;
        m_tab_logging: TTabSheet;
        m_tab_advanced: TTabSheet;
        m_btn_apply: TButton;
        m_btn_ok: TButton;
        m_btn_cancel: TButton;
        m_combo_input_mode: TComboBox;
        m_edit_max_candidates: TEdit;
        m_combo_variant: TComboBox;
        m_chk_full_width_mode: TCheckBox;
        m_chk_punctuation_full_width: TCheckBox;
        m_chk_enable_segment_candidates: TCheckBox;
        m_chk_segment_head_only: TCheckBox;
        m_chk_enable_ctrl_space_toggle: TCheckBox;
        m_chk_enable_shift_space_toggle: TCheckBox;
        m_chk_enable_ctrl_period_toggle: TCheckBox;
        m_chk_show_status_widget: TCheckBox;
        m_chk_enable_ai: TCheckBox;
        m_combo_ai_backend: TComboBox;
        m_edit_ai_timeout_ms: TEdit;
        m_edit_ai_runtime_dir_cpu: TEdit;
        m_edit_ai_runtime_dir_cuda: TEdit;
        m_edit_ai_model_path: TEdit;
        m_btn_ai_runtime_dir_cpu: TButton;
        m_btn_ai_runtime_dir_cuda: TButton;
        m_btn_ai_model_path: TButton;
        m_chk_log_enabled: TCheckBox;
        m_combo_log_level: TComboBox;
        m_edit_log_max_size_kb: TEdit;
        m_edit_log_path: TEdit;
        m_btn_log_path: TButton;
        m_hint_logging: TLabel;
        m_chk_debug_mode: TCheckBox;
        m_edit_dict_path_sc: TEdit;
        m_edit_dict_path_tc: TEdit;
        m_edit_user_dict_path: TEdit;
        m_btn_dict_path_sc: TButton;
        m_btn_dict_path_tc: TButton;
        m_btn_user_dict_path: TButton;
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
        procedure add_general_controls;
        procedure add_candidate_controls;
        procedure add_hotkey_controls;
        procedure add_appearance_controls;
        procedure add_ai_controls;
        procedure add_logging_controls;
        procedure add_advanced_controls;
        procedure mark_dirty(Sender: TObject);
        procedure update_apply_button;
        procedure update_ai_controls;
        procedure update_logging_controls;
        procedure load_from_config;
        function browse_for_directory(const title: string; var path: string): Boolean;
        function browse_for_open_file(const title: string; const filter: string; var path: string): Boolean;
        function browse_for_save_file(const title: string; const filter: string; const default_ext: string;
            var path: string): Boolean;
        procedure assign_path_edit(const edit: TEdit; const path: string);
        function read_integer_setting(const edit: TEdit; const default_value: Integer;
            const min_value: Integer; const max_value: Integer; const setting_name: string;
            out value: Integer; out error_text: string): Boolean;
        function build_config_from_controls(out next_config: TncEngineConfig; out next_log_config: TncLogConfig;
            out next_status_widget_visible: Boolean; out error_text: string): Boolean;
        procedure on_browse_ai_runtime_dir_cpu(Sender: TObject);
        procedure on_browse_ai_runtime_dir_cuda(Sender: TObject);
        procedure on_browse_ai_model_path(Sender: TObject);
        procedure on_browse_log_path(Sender: TObject);
        procedure on_browse_dict_path_sc(Sender: TObject);
        procedure on_browse_dict_path_tc(Sender: TObject);
        procedure on_browse_user_dict_path(Sender: TObject);
        procedure apply_changes;
        procedure on_apply_click(Sender: TObject);
        procedure on_ok_click(Sender: TObject);
        procedure on_cancel_click(Sender: TObject);
    public
        constructor Create(AOwner: TComponent); override;
        class function ExecuteDialog(const owner: TComponent; var config: TncEngineConfig; var log_config: TncLogConfig;
            var status_widget_visible: Boolean; const on_apply: TncApplySettingsProc): Boolean; static;
    end;

implementation

const
    c_dialog_width = 700;
    c_dialog_height = 500;
    c_label_left = 20;
    c_control_left = 190;
    c_row_height = 32;
    c_row_gap = 10;
    c_edit_width = 120;
    c_combo_width = 160;
    c_path_edit_width = 390;
    c_browse_button_gap = 8;
    c_browse_button_width = 72;

function create_label(const owner: TComponent; const parent: TWinControl; const caption: string;
    const top: Integer): TLabel;
begin
    Result := TLabel.Create(owner);
    Result.Parent := parent;
    Result.Left := c_label_left;
    Result.Top := top + 4;
    Result.Caption := caption;
end;

function create_browse_button(const owner: TComponent; const parent: TWinControl; const top: Integer;
    const on_click: TNotifyEvent): TButton;
begin
    Result := TButton.Create(owner);
    Result.Parent := parent;
    Result.Left := c_control_left + c_path_edit_width + c_browse_button_gap;
    Result.Top := top - 1;
    Result.Width := c_browse_button_width;
    Result.Caption := 'Browse';
    Result.OnClick := on_click;
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
    add_candidate_controls;
    add_hotkey_controls;
    add_appearance_controls;
    add_ai_controls;
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
    Caption := 'Cassotis Settings';
    ClientWidth := c_dialog_width;
    ClientHeight := c_dialog_height;
    Position := poScreenCenter;
    Font.Name := 'Microsoft YaHei UI';
    Font.Size := 9;
end;

procedure TncSettingsForm.configure_tabs;
begin
    m_page_control := TPageControl.Create(Self);
    m_page_control.Parent := Self;
    m_page_control.Align := alTop;
    m_page_control.Height := 410;

    m_tab_general := TTabSheet.Create(m_page_control);
    m_tab_general.PageControl := m_page_control;
    m_tab_general.Caption := 'General';

    m_tab_candidate := TTabSheet.Create(m_page_control);
    m_tab_candidate.PageControl := m_page_control;
    m_tab_candidate.Caption := 'Candidates';

    m_tab_hotkeys := TTabSheet.Create(m_page_control);
    m_tab_hotkeys.PageControl := m_page_control;
    m_tab_hotkeys.Caption := 'Hotkeys';

    m_tab_appearance := TTabSheet.Create(m_page_control);
    m_tab_appearance.PageControl := m_page_control;
    m_tab_appearance.Caption := 'Appearance';

    m_tab_ai := TTabSheet.Create(m_page_control);
    m_tab_ai.PageControl := m_page_control;
    m_tab_ai.Caption := 'AI';

    m_tab_logging := TTabSheet.Create(m_page_control);
    m_tab_logging.PageControl := m_page_control;
    m_tab_logging.Caption := 'Logging';

    m_tab_advanced := TTabSheet.Create(m_page_control);
    m_tab_advanced.PageControl := m_page_control;
    m_tab_advanced.Caption := 'Advanced';
end;

procedure TncSettingsForm.configure_buttons;
begin
    m_btn_apply := TButton.Create(Self);
    m_btn_apply.Parent := Self;
    m_btn_apply.Left := ClientWidth - 270;
    m_btn_apply.Top := 436;
    m_btn_apply.Width := 80;
    m_btn_apply.Caption := 'Apply';
    m_btn_apply.OnClick := on_apply_click;

    m_btn_ok := TButton.Create(Self);
    m_btn_ok.Parent := Self;
    m_btn_ok.Left := ClientWidth - 180;
    m_btn_ok.Top := 436;
    m_btn_ok.Width := 80;
    m_btn_ok.Caption := 'OK';
    m_btn_ok.Default := True;
    m_btn_ok.OnClick := on_ok_click;

    m_btn_cancel := TButton.Create(Self);
    m_btn_cancel.Parent := Self;
    m_btn_cancel.Left := ClientWidth - 90;
    m_btn_cancel.Top := 436;
    m_btn_cancel.Width := 80;
    m_btn_cancel.Caption := 'Cancel';
    m_btn_cancel.Cancel := True;
    m_btn_cancel.OnClick := on_cancel_click;
end;

procedure TncSettingsForm.add_general_controls;
var
    top: Integer;
begin
    top := 24;
    create_label(Self, m_tab_general, 'Input mode', top);
    m_combo_input_mode := TComboBox.Create(Self);
    m_combo_input_mode.Parent := m_tab_general;
    m_combo_input_mode.Left := c_control_left;
    m_combo_input_mode.Top := top;
    m_combo_input_mode.Width := c_combo_width;
    m_combo_input_mode.Style := csDropDownList;
    m_combo_input_mode.Items.Add('Chinese');
    m_combo_input_mode.Items.Add('English');
    m_combo_input_mode.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_general, 'Max candidates', top);
    m_edit_max_candidates := TEdit.Create(Self);
    m_edit_max_candidates.Parent := m_tab_general;
    m_edit_max_candidates.Left := c_control_left;
    m_edit_max_candidates.Top := top;
    m_edit_max_candidates.Width := c_edit_width;
    m_edit_max_candidates.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_general, 'Dictionary variant', top);
    m_combo_variant := TComboBox.Create(Self);
    m_combo_variant.Parent := m_tab_general;
    m_combo_variant.Left := c_control_left;
    m_combo_variant.Top := top;
    m_combo_variant.Width := c_combo_width;
    m_combo_variant.Style := csDropDownList;
    m_combo_variant.Items.Add('Simplified Chinese');
    m_combo_variant.Items.Add('Traditional Chinese');
    m_combo_variant.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    m_chk_full_width_mode := TCheckBox.Create(Self);
    m_chk_full_width_mode.Parent := m_tab_general;
    m_chk_full_width_mode.Left := c_label_left;
    m_chk_full_width_mode.Top := top;
    m_chk_full_width_mode.Width := 420;
    m_chk_full_width_mode.Caption := 'Use full-width characters';
    m_chk_full_width_mode.OnClick := mark_dirty;

    Inc(top, c_row_height);
    m_chk_punctuation_full_width := TCheckBox.Create(Self);
    m_chk_punctuation_full_width.Parent := m_tab_general;
    m_chk_punctuation_full_width.Left := c_label_left;
    m_chk_punctuation_full_width.Top := top;
    m_chk_punctuation_full_width.Width := 420;
    m_chk_punctuation_full_width.Caption := 'Use full-width punctuation';
    m_chk_punctuation_full_width.OnClick := mark_dirty;
end;

procedure TncSettingsForm.add_candidate_controls;
var
    top: Integer;
begin
    top := 24;
    m_chk_enable_segment_candidates := TCheckBox.Create(Self);
    m_chk_enable_segment_candidates.Parent := m_tab_candidate;
    m_chk_enable_segment_candidates.Left := c_label_left;
    m_chk_enable_segment_candidates.Top := top;
    m_chk_enable_segment_candidates.Width := 420;
    m_chk_enable_segment_candidates.Caption := 'Enable segmented candidates';
    m_chk_enable_segment_candidates.OnClick := mark_dirty;

    Inc(top, c_row_height);
    m_chk_segment_head_only := TCheckBox.Create(Self);
    m_chk_segment_head_only.Parent := m_tab_candidate;
    m_chk_segment_head_only.Left := c_label_left;
    m_chk_segment_head_only.Top := top;
    m_chk_segment_head_only.Width := 460;
    m_chk_segment_head_only.Caption := 'Prefer only the head segment for multi-syllable splitting';
    m_chk_segment_head_only.OnClick := mark_dirty;
end;

procedure TncSettingsForm.add_hotkey_controls;
var
    top: Integer;
begin
    top := 24;
    m_chk_enable_ctrl_space_toggle := TCheckBox.Create(Self);
    m_chk_enable_ctrl_space_toggle.Parent := m_tab_hotkeys;
    m_chk_enable_ctrl_space_toggle.Left := c_label_left;
    m_chk_enable_ctrl_space_toggle.Top := top;
    m_chk_enable_ctrl_space_toggle.Width := 420;
    m_chk_enable_ctrl_space_toggle.Caption := 'Enable Ctrl+Space to toggle Chinese/English';
    m_chk_enable_ctrl_space_toggle.OnClick := mark_dirty;

    Inc(top, c_row_height);
    m_chk_enable_shift_space_toggle := TCheckBox.Create(Self);
    m_chk_enable_shift_space_toggle.Parent := m_tab_hotkeys;
    m_chk_enable_shift_space_toggle.Left := c_label_left;
    m_chk_enable_shift_space_toggle.Top := top;
    m_chk_enable_shift_space_toggle.Width := 420;
    m_chk_enable_shift_space_toggle.Caption := 'Enable Shift+Space to toggle full-width';
    m_chk_enable_shift_space_toggle.OnClick := mark_dirty;

    Inc(top, c_row_height);
    m_chk_enable_ctrl_period_toggle := TCheckBox.Create(Self);
    m_chk_enable_ctrl_period_toggle.Parent := m_tab_hotkeys;
    m_chk_enable_ctrl_period_toggle.Left := c_label_left;
    m_chk_enable_ctrl_period_toggle.Top := top;
    m_chk_enable_ctrl_period_toggle.Width := 420;
    m_chk_enable_ctrl_period_toggle.Caption := 'Enable Ctrl+. to toggle punctuation width';
    m_chk_enable_ctrl_period_toggle.OnClick := mark_dirty;
end;

procedure TncSettingsForm.add_appearance_controls;
begin
    m_chk_show_status_widget := TCheckBox.Create(Self);
    m_chk_show_status_widget.Parent := m_tab_appearance;
    m_chk_show_status_widget.Left := c_label_left;
    m_chk_show_status_widget.Top := 24;
    m_chk_show_status_widget.Width := 420;
    m_chk_show_status_widget.Caption := 'Show the status floating window when Cassotis is active';
    m_chk_show_status_widget.OnClick := mark_dirty;
end;

procedure TncSettingsForm.add_ai_controls;
var
    top: Integer;
begin
    top := 24;
    m_chk_enable_ai := TCheckBox.Create(Self);
    m_chk_enable_ai.Parent := m_tab_ai;
    m_chk_enable_ai.Left := c_label_left;
    m_chk_enable_ai.Top := top;
    m_chk_enable_ai.Width := 420;
    m_chk_enable_ai.Caption := 'Enable AI candidate enhancement';
    m_chk_enable_ai.OnClick := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_ai, 'AI backend', top);
    m_combo_ai_backend := TComboBox.Create(Self);
    m_combo_ai_backend.Parent := m_tab_ai;
    m_combo_ai_backend.Left := c_control_left;
    m_combo_ai_backend.Top := top;
    m_combo_ai_backend.Width := c_combo_width;
    m_combo_ai_backend.Style := csDropDownList;
    m_combo_ai_backend.Items.Add('Auto');
    m_combo_ai_backend.Items.Add('CPU');
    m_combo_ai_backend.Items.Add('CUDA');
    m_combo_ai_backend.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_ai, 'Request timeout (ms)', top);
    m_edit_ai_timeout_ms := TEdit.Create(Self);
    m_edit_ai_timeout_ms.Parent := m_tab_ai;
    m_edit_ai_timeout_ms.Left := c_control_left;
    m_edit_ai_timeout_ms.Top := top;
    m_edit_ai_timeout_ms.Width := c_edit_width;
    m_edit_ai_timeout_ms.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_ai, 'CPU runtime dir', top);
    m_edit_ai_runtime_dir_cpu := TEdit.Create(Self);
    m_edit_ai_runtime_dir_cpu.Parent := m_tab_ai;
    m_edit_ai_runtime_dir_cpu.Left := c_control_left;
    m_edit_ai_runtime_dir_cpu.Top := top;
    m_edit_ai_runtime_dir_cpu.Width := c_path_edit_width;
    m_edit_ai_runtime_dir_cpu.OnChange := mark_dirty;
    m_btn_ai_runtime_dir_cpu := create_browse_button(Self, m_tab_ai, top, on_browse_ai_runtime_dir_cpu);

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_ai, 'CUDA runtime dir', top);
    m_edit_ai_runtime_dir_cuda := TEdit.Create(Self);
    m_edit_ai_runtime_dir_cuda.Parent := m_tab_ai;
    m_edit_ai_runtime_dir_cuda.Left := c_control_left;
    m_edit_ai_runtime_dir_cuda.Top := top;
    m_edit_ai_runtime_dir_cuda.Width := c_path_edit_width;
    m_edit_ai_runtime_dir_cuda.OnChange := mark_dirty;
    m_btn_ai_runtime_dir_cuda := create_browse_button(Self, m_tab_ai, top, on_browse_ai_runtime_dir_cuda);

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_ai, 'Model path', top);
    m_edit_ai_model_path := TEdit.Create(Self);
    m_edit_ai_model_path.Parent := m_tab_ai;
    m_edit_ai_model_path.Left := c_control_left;
    m_edit_ai_model_path.Top := top;
    m_edit_ai_model_path.Width := c_path_edit_width;
    m_edit_ai_model_path.OnChange := mark_dirty;
    m_btn_ai_model_path := create_browse_button(Self, m_tab_ai, top, on_browse_ai_model_path);
end;

procedure TncSettingsForm.add_logging_controls;
var
    top: Integer;
begin
    top := 24;
    m_chk_log_enabled := TCheckBox.Create(Self);
    m_chk_log_enabled.Parent := m_tab_logging;
    m_chk_log_enabled.Left := c_label_left;
    m_chk_log_enabled.Top := top;
    m_chk_log_enabled.Width := 420;
    m_chk_log_enabled.Caption := 'Enable logging';
    m_chk_log_enabled.OnClick := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_logging, 'Log level', top);
    m_combo_log_level := TComboBox.Create(Self);
    m_combo_log_level.Parent := m_tab_logging;
    m_combo_log_level.Left := c_control_left;
    m_combo_log_level.Top := top;
    m_combo_log_level.Width := c_combo_width;
    m_combo_log_level.Style := csDropDownList;
    m_combo_log_level.Items.Add('Debug');
    m_combo_log_level.Items.Add('Info');
    m_combo_log_level.Items.Add('Warn');
    m_combo_log_level.Items.Add('Error');
    m_combo_log_level.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_logging, 'Max log size (KB)', top);
    m_edit_log_max_size_kb := TEdit.Create(Self);
    m_edit_log_max_size_kb.Parent := m_tab_logging;
    m_edit_log_max_size_kb.Left := c_control_left;
    m_edit_log_max_size_kb.Top := top;
    m_edit_log_max_size_kb.Width := c_edit_width;
    m_edit_log_max_size_kb.OnChange := mark_dirty;

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_logging, 'Log path', top);
    m_edit_log_path := TEdit.Create(Self);
    m_edit_log_path.Parent := m_tab_logging;
    m_edit_log_path.Left := c_control_left;
    m_edit_log_path.Top := top;
    m_edit_log_path.Width := c_path_edit_width;
    m_edit_log_path.OnChange := mark_dirty;
    m_btn_log_path := create_browse_button(Self, m_tab_logging, top, on_browse_log_path);

    m_hint_logging := TLabel.Create(Self);
    m_hint_logging.Parent := m_tab_logging;
    m_hint_logging.Left := c_label_left;
    m_hint_logging.Top := top + c_row_height + 8;
    m_hint_logging.Width := 620;
    m_hint_logging.WordWrap := True;
    m_hint_logging.Caption :=
        'Changes are written back to the ini file immediately. Host-side logging ' +
        'reloads at once; TSF-side logging follows the existing config reload path.';
    m_hint_logging.Font.Color := clGrayText;
end;

procedure TncSettingsForm.add_advanced_controls;
var
    top: Integer;
begin
    top := 24;
    m_chk_debug_mode := TCheckBox.Create(Self);
    m_chk_debug_mode.Parent := m_tab_advanced;
    m_chk_debug_mode.Left := c_label_left;
    m_chk_debug_mode.Top := top;
    m_chk_debug_mode.Width := 420;
    m_chk_debug_mode.Caption := 'Enable debug mode';
    m_chk_debug_mode.OnClick := mark_dirty;

    Inc(top, c_row_height + c_row_gap + 4);
    create_label(Self, m_tab_advanced, 'Simplified dictionary', top);
    m_edit_dict_path_sc := TEdit.Create(Self);
    m_edit_dict_path_sc.Parent := m_tab_advanced;
    m_edit_dict_path_sc.Left := c_control_left;
    m_edit_dict_path_sc.Top := top;
    m_edit_dict_path_sc.Width := c_path_edit_width;
    m_edit_dict_path_sc.OnChange := mark_dirty;
    m_btn_dict_path_sc := create_browse_button(Self, m_tab_advanced, top, on_browse_dict_path_sc);

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_advanced, 'Traditional dictionary', top);
    m_edit_dict_path_tc := TEdit.Create(Self);
    m_edit_dict_path_tc.Parent := m_tab_advanced;
    m_edit_dict_path_tc.Left := c_control_left;
    m_edit_dict_path_tc.Top := top;
    m_edit_dict_path_tc.Width := c_path_edit_width;
    m_edit_dict_path_tc.OnChange := mark_dirty;
    m_btn_dict_path_tc := create_browse_button(Self, m_tab_advanced, top, on_browse_dict_path_tc);

    Inc(top, c_row_height + c_row_gap);
    create_label(Self, m_tab_advanced, 'User dictionary', top);
    m_edit_user_dict_path := TEdit.Create(Self);
    m_edit_user_dict_path.Parent := m_tab_advanced;
    m_edit_user_dict_path.Left := c_control_left;
    m_edit_user_dict_path.Top := top;
    m_edit_user_dict_path.Width := c_path_edit_width;
    m_edit_user_dict_path.OnChange := mark_dirty;
    m_btn_user_dict_path := create_browse_button(Self, m_tab_advanced, top, on_browse_user_dict_path);

    m_hint_advanced := TLabel.Create(Self);
    m_hint_advanced.Parent := m_tab_advanced;
    m_hint_advanced.Left := c_label_left;
    m_hint_advanced.Top := top + c_row_height + 8;
    m_hint_advanced.Width := 620;
    m_hint_advanced.WordWrap := True;
    m_hint_advanced.Caption :=
        'Dictionary and model paths are written back to the ini file and reloaded immediately. ' +
        'Use existing valid paths to avoid breaking runtime assets.';
    m_hint_advanced.Font.Color := clGrayText;
end;

procedure TncSettingsForm.mark_dirty(Sender: TObject);
begin
    m_dirty := True;
    update_ai_controls;
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

procedure TncSettingsForm.update_ai_controls;
var
    enabled: Boolean;
begin
    enabled := (m_chk_enable_ai <> nil) and m_chk_enable_ai.Checked;
    if m_combo_ai_backend <> nil then
    begin
        m_combo_ai_backend.Enabled := enabled;
    end;
    if m_edit_ai_timeout_ms <> nil then
    begin
        m_edit_ai_timeout_ms.Enabled := enabled;
    end;
    if m_edit_ai_runtime_dir_cpu <> nil then
    begin
        m_edit_ai_runtime_dir_cpu.Enabled := enabled;
    end;
    if m_btn_ai_runtime_dir_cpu <> nil then
    begin
        m_btn_ai_runtime_dir_cpu.Enabled := enabled;
    end;
    if m_edit_ai_runtime_dir_cuda <> nil then
    begin
        m_edit_ai_runtime_dir_cuda.Enabled := enabled;
    end;
    if m_btn_ai_runtime_dir_cuda <> nil then
    begin
        m_btn_ai_runtime_dir_cuda.Enabled := enabled;
    end;
    if m_edit_ai_model_path <> nil then
    begin
        m_edit_ai_model_path.Enabled := enabled;
    end;
    if m_btn_ai_model_path <> nil then
    begin
        m_btn_ai_model_path.Enabled := enabled;
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
end;

function TncSettingsForm.browse_for_directory(const title: string; var path: string): Boolean;
var
    selected_path: string;
begin
    selected_path := path;
    Result := SelectDirectory(title, '', selected_path);
    if Result then
    begin
        path := selected_path;
    end;
end;

function TncSettingsForm.browse_for_open_file(const title: string; const filter: string; var path: string): Boolean;
var
    dialog: TOpenDialog;
begin
    dialog := TOpenDialog.Create(Self);
    try
        dialog.Title := title;
        dialog.Filter := filter;
        dialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
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

procedure TncSettingsForm.load_from_config;
begin
    if m_edit_max_candidates <> nil then
    begin
        m_edit_max_candidates.Text := IntToStr(m_engine_config.max_candidates);
    end;
    if m_combo_input_mode <> nil then
    begin
        if m_engine_config.input_mode = im_english then
        begin
            m_combo_input_mode.ItemIndex := 1;
        end
        else
        begin
            m_combo_input_mode.ItemIndex := 0;
        end;
    end;
    if m_combo_variant <> nil then
    begin
        if m_engine_config.dictionary_variant = dv_traditional then
        begin
            m_combo_variant.ItemIndex := 1;
        end
        else
        begin
            m_combo_variant.ItemIndex := 0;
        end;
    end;

    if m_chk_enable_segment_candidates <> nil then
    begin
        m_chk_enable_segment_candidates.Checked := m_engine_config.enable_segment_candidates;
    end;
    if m_chk_full_width_mode <> nil then
    begin
        m_chk_full_width_mode.Checked := m_engine_config.full_width_mode;
    end;
    if m_chk_punctuation_full_width <> nil then
    begin
        m_chk_punctuation_full_width.Checked := m_engine_config.punctuation_full_width;
    end;
    if m_chk_segment_head_only <> nil then
    begin
        m_chk_segment_head_only.Checked := m_engine_config.segment_head_only_multi_syllable;
    end;
    if m_chk_enable_ctrl_space_toggle <> nil then
    begin
        m_chk_enable_ctrl_space_toggle.Checked := m_engine_config.enable_ctrl_space_toggle;
    end;
    if m_chk_enable_shift_space_toggle <> nil then
    begin
        m_chk_enable_shift_space_toggle.Checked := m_engine_config.enable_shift_space_full_width_toggle;
    end;
    if m_chk_enable_ctrl_period_toggle <> nil then
    begin
        m_chk_enable_ctrl_period_toggle.Checked := m_engine_config.enable_ctrl_period_punct_toggle;
    end;
    if m_chk_show_status_widget <> nil then
    begin
        m_chk_show_status_widget.Checked := m_status_widget_visible;
    end;
    if m_chk_enable_ai <> nil then
    begin
        m_chk_enable_ai.Checked := m_engine_config.enable_ai;
    end;
    if m_combo_ai_backend <> nil then
    begin
        case m_engine_config.ai_llama_backend of
            lb_cpu:
                m_combo_ai_backend.ItemIndex := 1;
            lb_cuda:
                m_combo_ai_backend.ItemIndex := 2;
        else
            m_combo_ai_backend.ItemIndex := 0;
        end;
    end;
    if m_edit_ai_timeout_ms <> nil then
    begin
        m_edit_ai_timeout_ms.Text := IntToStr(m_engine_config.ai_request_timeout_ms);
    end;
    if m_edit_ai_runtime_dir_cpu <> nil then
    begin
        m_edit_ai_runtime_dir_cpu.Text := m_engine_config.ai_llama_runtime_dir_cpu;
    end;
    if m_edit_ai_runtime_dir_cuda <> nil then
    begin
        m_edit_ai_runtime_dir_cuda.Text := m_engine_config.ai_llama_runtime_dir_cuda;
    end;
    if m_edit_ai_model_path <> nil then
    begin
        m_edit_ai_model_path.Text := m_engine_config.ai_llama_model_path;
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
    if m_edit_dict_path_sc <> nil then
    begin
        m_edit_dict_path_sc.Text := m_engine_config.dictionary_path_simplified;
    end;
    if m_edit_dict_path_tc <> nil then
    begin
        m_edit_dict_path_tc.Text := m_engine_config.dictionary_path_traditional;
    end;
    if m_edit_user_dict_path <> nil then
    begin
        m_edit_user_dict_path.Text := m_engine_config.user_dictionary_path;
    end;

    m_dirty := False;
    update_ai_controls;
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
        error_text := Format('%s must be at least %d.', [setting_name, min_value]);
        Result := False;
        Exit;
    end;
    if value > max_value then
    begin
        error_text := Format('%s must be at most %d.', [setting_name, max_value]);
        Result := False;
        Exit;
    end;
    Result := True;
end;

function TncSettingsForm.build_config_from_controls(out next_config: TncEngineConfig; out next_log_config: TncLogConfig;
    out next_status_widget_visible: Boolean; out error_text: string): Boolean;
var
    max_candidates: Integer;
    timeout_ms: Integer;
    log_max_size_kb: Integer;
begin
    next_config := m_engine_config;
    next_log_config := m_log_config;
    next_status_widget_visible := m_status_widget_visible;
    error_text := '';

    if not read_integer_setting(m_edit_max_candidates, m_engine_config.max_candidates, 1, 20,
        'Max candidates', max_candidates, error_text) then
    begin
        Result := False;
        Exit;
    end;
    next_config.max_candidates := max_candidates;

    if not read_integer_setting(m_edit_ai_timeout_ms, m_engine_config.ai_request_timeout_ms, 100, 10000,
        'AI request timeout', timeout_ms, error_text) then
    begin
        Result := False;
        Exit;
    end;
    next_config.ai_request_timeout_ms := timeout_ms;

    if not read_integer_setting(m_edit_log_max_size_kb, m_log_config.max_size_kb, 64, 1024 * 1024,
        'Max log size', log_max_size_kb, error_text) then
    begin
        Result := False;
        Exit;
    end;
    next_log_config.max_size_kb := log_max_size_kb;

    if m_combo_variant.ItemIndex = 1 then
    begin
        next_config.dictionary_variant := dv_traditional;
    end
    else
    begin
        next_config.dictionary_variant := dv_simplified;
    end;
    if m_combo_input_mode.ItemIndex = 1 then
    begin
        next_config.input_mode := im_english;
    end
    else
    begin
        next_config.input_mode := im_chinese;
    end;

    next_config.full_width_mode := m_chk_full_width_mode.Checked;
    next_config.punctuation_full_width := m_chk_punctuation_full_width.Checked;
    next_config.enable_segment_candidates := m_chk_enable_segment_candidates.Checked;
    next_config.segment_head_only_multi_syllable := m_chk_segment_head_only.Checked;
    next_config.enable_ctrl_space_toggle := m_chk_enable_ctrl_space_toggle.Checked;
    next_config.enable_shift_space_full_width_toggle := m_chk_enable_shift_space_toggle.Checked;
    next_config.enable_ctrl_period_punct_toggle := m_chk_enable_ctrl_period_toggle.Checked;
    next_config.enable_ai := m_chk_enable_ai.Checked;
    next_status_widget_visible := m_chk_show_status_widget.Checked;
    case m_combo_ai_backend.ItemIndex of
        1:
            next_config.ai_llama_backend := lb_cpu;
        2:
            next_config.ai_llama_backend := lb_cuda;
    else
        next_config.ai_llama_backend := lb_auto;
    end;
    next_log_config.enabled := m_chk_log_enabled.Checked;
    if Trim(m_edit_ai_runtime_dir_cpu.Text) <> '' then
    begin
        next_config.ai_llama_runtime_dir_cpu := Trim(m_edit_ai_runtime_dir_cpu.Text);
    end;
    if Trim(m_edit_ai_runtime_dir_cuda.Text) <> '' then
    begin
        next_config.ai_llama_runtime_dir_cuda := Trim(m_edit_ai_runtime_dir_cuda.Text);
    end;
    if Trim(m_edit_ai_model_path.Text) <> '' then
    begin
        next_config.ai_llama_model_path := Trim(m_edit_ai_model_path.Text);
    end;
    if Trim(m_edit_log_path.Text) <> '' then
    begin
        next_log_config.log_path := Trim(m_edit_log_path.Text);
    end;
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
    if Trim(m_edit_dict_path_sc.Text) <> '' then
    begin
        next_config.dictionary_path_simplified := Trim(m_edit_dict_path_sc.Text);
    end;
    if Trim(m_edit_dict_path_tc.Text) <> '' then
    begin
        next_config.dictionary_path_traditional := Trim(m_edit_dict_path_tc.Text);
    end;
    if Trim(m_edit_user_dict_path.Text) <> '' then
    begin
        next_config.user_dictionary_path := Trim(m_edit_user_dict_path.Text);
    end;
    next_config.debug_mode := m_chk_debug_mode.Checked;

    Result := True;
end;

procedure TncSettingsForm.on_browse_ai_runtime_dir_cpu(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_ai_runtime_dir_cpu.Text);
    if browse_for_directory('Select CPU runtime directory', path) then
    begin
        assign_path_edit(m_edit_ai_runtime_dir_cpu, path);
    end;
end;

procedure TncSettingsForm.on_browse_ai_runtime_dir_cuda(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_ai_runtime_dir_cuda.Text);
    if browse_for_directory('Select CUDA runtime directory', path) then
    begin
        assign_path_edit(m_edit_ai_runtime_dir_cuda, path);
    end;
end;

procedure TncSettingsForm.on_browse_ai_model_path(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_ai_model_path.Text);
    if browse_for_open_file('Select model file', 'Model files|*.gguf|All files|*.*', path) then
    begin
        assign_path_edit(m_edit_ai_model_path, path);
    end;
end;

procedure TncSettingsForm.on_browse_log_path(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_log_path.Text);
    if browse_for_save_file('Select log file', 'Log files|*.log;*.txt|All files|*.*', 'log', path) then
    begin
        assign_path_edit(m_edit_log_path, path);
    end;
end;

procedure TncSettingsForm.on_browse_dict_path_sc(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_dict_path_sc.Text);
    if browse_for_open_file('Select simplified dictionary', 'Dictionary files|*.db;*.sqlite|All files|*.*', path) then
    begin
        assign_path_edit(m_edit_dict_path_sc, path);
    end;
end;

procedure TncSettingsForm.on_browse_dict_path_tc(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_dict_path_tc.Text);
    if browse_for_open_file('Select traditional dictionary', 'Dictionary files|*.db;*.sqlite|All files|*.*', path) then
    begin
        assign_path_edit(m_edit_dict_path_tc, path);
    end;
end;

procedure TncSettingsForm.on_browse_user_dict_path(Sender: TObject);
var
    path: string;
begin
    path := Trim(m_edit_user_dict_path.Text);
    if browse_for_save_file('Select user dictionary file', 'Database files|*.db;*.sqlite|All files|*.*', 'db', path) then
    begin
        assign_path_edit(m_edit_user_dict_path, path);
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
        Application.MessageBox(PChar(error_text), 'Cassotis Settings', MB_OK or MB_ICONWARNING);
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
