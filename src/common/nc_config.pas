unit nc_config;

interface

uses
    System.SysUtils,
    System.IniFiles,
    System.IOUtils,
    Winapi.Windows,
    nc_types,
    nc_log;

type
    TncConfigManager = class
    private
        m_config_path: string;
        procedure ensure_config_directory;
        procedure write_config_version(const ini: TIniFile);
    public
        constructor create(const config_path: string);
        function load_engine_config: TncEngineConfig;
        function load_log_config: TncLogConfig;
        procedure save_engine_config(const config: TncEngineConfig);
        procedure save_log_config(const config: TncLogConfig);
        property config_path: string read m_config_path;
    end;

function get_default_config_path: string;
function get_runtime_data_directory: string;
function get_default_dictionary_path_simplified: string;
function get_default_dictionary_path_traditional: string;
function get_default_user_dictionary_path: string;
function get_default_ai_llama_runtime_dir_cpu: string;
function get_default_ai_llama_runtime_dir_cuda: string;
function get_default_ai_llama_model_path: string;

implementation

const
    c_config_version = 8;
    c_default_ai_request_timeout_ms = 1200;

function get_module_directory: string; forward;

function parse_variant_text(const value: string): TncDictionaryVariant;
begin
    if SameText(value, 'traditional') or SameText(value, 'tc') then
    begin
        Result := dv_traditional;
        Exit;
    end;

    Result := dv_simplified;
end;

function variant_to_text(const variant: TncDictionaryVariant): string;
begin
    if variant = dv_traditional then
    begin
        Result := 'traditional';
    end
    else
    begin
        Result := 'simplified';
    end;
end;

function resolve_runtime_path(const path_text: string): string;
var
    module_dir: string;
begin
    Result := Trim(path_text);
    if Result = '' then
    begin
        Exit;
    end;

    if TPath.IsPathRooted(Result) then
    begin
        Result := ExpandFileName(Result);
        Exit;
    end;

    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := ExpandFileName(Result);
        Exit;
    end;

    Result := ExpandFileName(IncludeTrailingPathDelimiter(module_dir) + Result);
end;

function parse_llama_backend_text(const value: string): TncLlamaBackend;
begin
    if SameText(value, 'cpu') then
    begin
        Result := lb_cpu;
        Exit;
    end;

    if SameText(value, 'cuda') or SameText(value, 'gpu') then
    begin
        Result := lb_cuda;
        Exit;
    end;

    Result := lb_auto;
end;

function llama_backend_to_text(const backend: TncLlamaBackend): string;
begin
    case backend of
        lb_cpu:
            Result := 'cpu';
        lb_cuda:
            Result := 'cuda';
    else
        Result := 'auto';
    end;
end;

function get_module_directory: string;
var
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
begin
    path_len := GetModuleFileName(HInstance, path_buffer, Length(path_buffer));
    if path_len = 0 then
    begin
        Result := '';
        Exit;
    end;

    Result := ExtractFileDir(path_buffer);
end;

function get_local_app_data_directory: string;
begin
    Result := Trim(GetEnvironmentVariable('LOCALAPPDATA'));
    if Result = '' then
    begin
        Result := TPath.GetHomePath;
    end;
end;

function get_runtime_root_directory: string;
begin
    Result := IncludeTrailingPathDelimiter(get_local_app_data_directory) + 'CassotisIme';
    ForceDirectories(Result);
end;

function get_runtime_data_directory: string;
begin
    Result := IncludeTrailingPathDelimiter(get_runtime_root_directory) + 'data';
    ForceDirectories(Result);
end;

function get_legacy_dictionary_path_simplified: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'dict_sc.db';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'data\dict_sc.db';
end;

function get_legacy_dictionary_path_traditional: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'dict_tc.db';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'data\dict_tc.db';
end;

function get_legacy_user_dictionary_path: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'user_dict.db';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'data\user_dict.db';
end;

procedure migrate_runtime_dictionary_file(const source_path: string; const target_path: string;
    const move_source: Boolean);
var
    normalized_source: string;
    normalized_target: string;
begin
    normalized_source := Trim(source_path);
    normalized_target := Trim(target_path);
    if (normalized_source = '') or (normalized_target = '') then
    begin
        Exit;
    end;
    if SameText(normalized_source, normalized_target) then
    begin
        Exit;
    end;
    if not FileExists(normalized_source) then
    begin
        Exit;
    end;
    if FileExists(normalized_target) then
    begin
        Exit;
    end;

    ForceDirectories(ExtractFileDir(normalized_target));
    try
        if move_source then
        begin
            TFile.Move(normalized_source, normalized_target);
        end
        else
        begin
            TFile.Copy(normalized_source, normalized_target, False);
        end;
    except
        if move_source and (not FileExists(normalized_target)) then
        begin
            try
                TFile.Copy(normalized_source, normalized_target, False);
            except
                // Ignore migration failure and keep using the source file.
            end;
        end;
    end;
end;

function get_default_log_config: TncLogConfig;
begin
    Result.enabled := False;
    Result.level := ll_info;
    Result.max_size_kb := 1024;
    Result.log_path := get_default_log_path;
end;

function get_default_ai_llama_runtime_dir_cpu: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
{$IFDEF WIN64}
        Result := 'llama\win64';
{$ELSE}
        Result := 'llama\win32';
{$ENDIF}
        Exit;
    end;

{$IFDEF WIN64}
    Result := IncludeTrailingPathDelimiter(module_dir) + 'llama\win64';
{$ELSE}
    Result := IncludeTrailingPathDelimiter(module_dir) + 'llama\win32';
{$ENDIF}
end;

function get_default_ai_llama_runtime_dir_cuda: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'llama\win64-cuda';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'llama\win64-cuda';
end;

function get_default_ai_llama_model_path: string;
var
    module_dir: string;
    model_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := '';
        Exit;
    end;

    model_dir := IncludeTrailingPathDelimiter(module_dir) + 'models';
    ForceDirectories(model_dir);
    Result := IncludeTrailingPathDelimiter(model_dir) + 'llama.gguf';
end;

constructor TncConfigManager.create(const config_path: string);
begin
    inherited create;
    if config_path = '' then
    begin
        m_config_path := get_default_config_path;
    end
    else
    begin
        m_config_path := config_path;
    end;
end;

procedure TncConfigManager.write_config_version(const ini: TIniFile);
begin
    if ini = nil then
    begin
        Exit;
    end;

    ini.WriteInteger('meta', 'version', c_config_version);
end;

function TncConfigManager.load_engine_config: TncEngineConfig;
var
    ini: TIniFile;
    input_mode_value: Integer;
    config_version: Integer;
    log_config: TncLogConfig;
    variant_text: string;
    legacy_dict_path: string;
    needs_full_write: Boolean;
    legacy_sc_path: string;
    legacy_tc_path: string;
    legacy_user_path: string;
begin
    Result.input_mode := im_chinese;
    Result.max_candidates := 9;
    Result.enable_ai := False;
    Result.enable_ctrl_space_toggle := False;
    Result.enable_shift_space_full_width_toggle := True;
    Result.enable_ctrl_period_punct_toggle := True;
    Result.full_width_mode := False;
    Result.punctuation_full_width := True;
    Result.enable_segment_candidates := True;
    Result.segment_head_only_multi_syllable := True;
    Result.debug_mode := False;
    Result.dictionary_variant := dv_simplified;
    Result.ai_llama_backend := lb_auto;
    Result.ai_llama_runtime_dir_cpu := get_default_ai_llama_runtime_dir_cpu;
    Result.ai_llama_runtime_dir_cuda := get_default_ai_llama_runtime_dir_cuda;
    Result.ai_llama_model_path := get_default_ai_llama_model_path;
    Result.ai_request_timeout_ms := c_default_ai_request_timeout_ms;

    if m_config_path = '' then
    begin
        Exit;
    end;

    if not FileExists(m_config_path) then
    begin
        migrate_runtime_dictionary_file(get_legacy_dictionary_path_simplified, get_default_dictionary_path_simplified, False);
        migrate_runtime_dictionary_file(get_legacy_dictionary_path_traditional, get_default_dictionary_path_traditional, False);
        migrate_runtime_dictionary_file(get_legacy_user_dictionary_path, get_default_user_dictionary_path, True);
        migrate_runtime_dictionary_file(resolve_runtime_path('config\user_dict.db'), get_default_user_dictionary_path, True);
        save_engine_config(Result);
        save_log_config(get_default_log_config);
        Exit;
    end;

    ini := TIniFile.Create(m_config_path);
    try
        config_version := ini.ReadInteger('meta', 'version', 0);
        input_mode_value := ini.ReadInteger('engine', 'input_mode', Ord(im_chinese));
        if input_mode_value = Ord(im_english) then
        begin
            Result.input_mode := im_english;
        end
        else
        begin
            Result.input_mode := im_chinese;
        end;

        Result.max_candidates := 9;
        Result.enable_ai := ini.ReadBool('engine', 'enable_ai', False);
        Result.enable_ctrl_space_toggle := False;
        Result.enable_shift_space_full_width_toggle := True;
        Result.enable_ctrl_period_punct_toggle := True;
        Result.full_width_mode := ini.ReadBool('engine', 'full_width_mode', False);
        Result.punctuation_full_width := ini.ReadBool('engine', 'punctuation_full_width', True);
        Result.enable_segment_candidates := True;
        Result.segment_head_only_multi_syllable := True;
        Result.debug_mode := ini.ReadInteger('engine', 'debug', 0) <> 0;
        variant_text := ini.ReadString('dictionary', 'variant', 'simplified');
        Result.dictionary_variant := parse_variant_text(variant_text);
        legacy_sc_path := ini.ReadString('dictionary', 'db_path_sc', '');
        if legacy_sc_path = '' then
        begin
            legacy_dict_path := ini.ReadString('dictionary', 'db_path', '');
            if legacy_dict_path <> '' then
            begin
                legacy_sc_path := legacy_dict_path;
            end
            else
            begin
                legacy_sc_path := get_legacy_dictionary_path_simplified;
            end;
        end;
        legacy_tc_path := ini.ReadString('dictionary', 'db_path_tc', get_legacy_dictionary_path_traditional);
        legacy_user_path := ini.ReadString('dictionary', 'user_db_path', get_legacy_user_dictionary_path);
        Result.ai_llama_backend := parse_llama_backend_text(ini.ReadString('ai', 'llama_backend', 'auto'));
        Result.ai_llama_runtime_dir_cpu := ini.ReadString('ai', 'llama_runtime_dir_cpu',
            get_default_ai_llama_runtime_dir_cpu);
        Result.ai_llama_runtime_dir_cuda := ini.ReadString('ai', 'llama_runtime_dir_cuda',
            get_default_ai_llama_runtime_dir_cuda);
        Result.ai_llama_model_path := ini.ReadString('ai', 'llama_model_path', get_default_ai_llama_model_path);
        Result.ai_request_timeout_ms := ini.ReadInteger('ai', 'request_timeout_ms', c_default_ai_request_timeout_ms);
        if Result.ai_request_timeout_ms <= 0 then
        begin
            Result.ai_request_timeout_ms := c_default_ai_request_timeout_ms;
        end;

        needs_full_write := not ini.ValueExists('engine', 'input_mode') or
            ini.ValueExists('engine', 'max_candidates') or
            not ini.ValueExists('engine', 'enable_ai') or
            ini.ValueExists('engine', 'enable_ctrl_space_toggle') or
            ini.ValueExists('engine', 'enable_shift_space_full_width_toggle') or
            ini.ValueExists('engine', 'enable_ctrl_period_punct_toggle') or
            ini.ValueExists('engine', 'enable_segment_candidates') or
            ini.ValueExists('engine', 'segment_head_only_multi_syllable') or
            ini.ValueExists('engine', 'suppress_nonlexicon_complete_long_candidates') or
            not ini.ValueExists('engine', 'debug') or
            not ini.ValueExists('dictionary', 'variant') or
            ini.ValueExists('dictionary', 'db_path') or
            ini.ValueExists('dictionary', 'db_path_sc') or
            ini.ValueExists('dictionary', 'db_path_tc') or
            ini.ValueExists('dictionary', 'user_db_path') or
            not ini.ValueExists('ai', 'llama_backend') or
            not ini.ValueExists('ai', 'llama_runtime_dir_cpu') or
            not ini.ValueExists('ai', 'llama_runtime_dir_cuda') or
            not ini.ValueExists('ai', 'llama_model_path') or
            not ini.ValueExists('ai', 'request_timeout_ms');
    finally
        ini.Free;
    end;

    legacy_sc_path := resolve_runtime_path(legacy_sc_path);
    legacy_tc_path := resolve_runtime_path(legacy_tc_path);
    legacy_user_path := resolve_runtime_path(legacy_user_path);
    migrate_runtime_dictionary_file(legacy_sc_path, get_default_dictionary_path_simplified, False);
    migrate_runtime_dictionary_file(legacy_tc_path, get_default_dictionary_path_traditional, False);
    migrate_runtime_dictionary_file(legacy_user_path, get_default_user_dictionary_path, True);
    migrate_runtime_dictionary_file(resolve_runtime_path('config\user_dict.db'), get_default_user_dictionary_path, True);
    Result.ai_llama_runtime_dir_cpu := resolve_runtime_path(Result.ai_llama_runtime_dir_cpu);
    Result.ai_llama_runtime_dir_cuda := resolve_runtime_path(Result.ai_llama_runtime_dir_cuda);
    Result.ai_llama_model_path := resolve_runtime_path(Result.ai_llama_model_path);

    if (config_version < c_config_version) or needs_full_write then
    begin
        log_config := load_log_config;
        save_engine_config(Result);
        save_log_config(log_config);
    end;
end;

procedure TncConfigManager.ensure_config_directory;
var
    dir_path: string;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    dir_path := ExtractFileDir(m_config_path);
    if dir_path <> '' then
    begin
        ForceDirectories(dir_path);
    end;
end;

procedure TncConfigManager.save_engine_config(const config: TncEngineConfig);
var
    ini: TIniFile;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    ensure_config_directory;
    ini := TIniFile.Create(m_config_path);
    try
        ini.WriteInteger('engine', 'input_mode', Ord(config.input_mode));
        if ini.ValueExists('engine', 'max_candidates') then
        begin
            ini.DeleteKey('engine', 'max_candidates');
        end;
        if ini.ValueExists('engine', 'enable_segment_candidates') then
        begin
            ini.DeleteKey('engine', 'enable_segment_candidates');
        end;
        if ini.ValueExists('engine', 'segment_head_only_multi_syllable') then
        begin
            ini.DeleteKey('engine', 'segment_head_only_multi_syllable');
        end;
        if ini.ValueExists('engine', 'enable_ctrl_space_toggle') then
        begin
            ini.DeleteKey('engine', 'enable_ctrl_space_toggle');
        end;
        if ini.ValueExists('engine', 'enable_shift_space_full_width_toggle') then
        begin
            ini.DeleteKey('engine', 'enable_shift_space_full_width_toggle');
        end;
        if ini.ValueExists('engine', 'enable_ctrl_period_punct_toggle') then
        begin
            ini.DeleteKey('engine', 'enable_ctrl_period_punct_toggle');
        end;
        if ini.ValueExists('engine', 'suppress_nonlexicon_complete_long_candidates') then
        begin
            ini.DeleteKey('engine', 'suppress_nonlexicon_complete_long_candidates');
        end;
        ini.WriteBool('engine', 'enable_ai', config.enable_ai);
        ini.WriteBool('engine', 'full_width_mode', config.full_width_mode);
        ini.WriteBool('engine', 'punctuation_full_width', config.punctuation_full_width);
        ini.WriteInteger('engine', 'debug', Ord(config.debug_mode));
        ini.WriteString('dictionary', 'variant', variant_to_text(config.dictionary_variant));
        if ini.ValueExists('dictionary', 'db_path') then
        begin
            ini.DeleteKey('dictionary', 'db_path');
        end;
        if ini.ValueExists('dictionary', 'db_path_sc') then
        begin
            ini.DeleteKey('dictionary', 'db_path_sc');
        end;
        if ini.ValueExists('dictionary', 'db_path_tc') then
        begin
            ini.DeleteKey('dictionary', 'db_path_tc');
        end;
        if ini.ValueExists('dictionary', 'user_db_path') then
        begin
            ini.DeleteKey('dictionary', 'user_db_path');
        end;
        ini.WriteString('ai', 'llama_backend', llama_backend_to_text(config.ai_llama_backend));
        ini.WriteString('ai', 'llama_runtime_dir_cpu', config.ai_llama_runtime_dir_cpu);
        ini.WriteString('ai', 'llama_runtime_dir_cuda', config.ai_llama_runtime_dir_cuda);
        ini.WriteString('ai', 'llama_model_path', config.ai_llama_model_path);
        ini.WriteInteger('ai', 'request_timeout_ms', config.ai_request_timeout_ms);
        write_config_version(ini);
    finally
        ini.Free;
    end;
end;

function TncConfigManager.load_log_config: TncLogConfig;
var
    ini: TIniFile;
    level_value: Integer;
begin
    Result := get_default_log_config;
    if m_config_path = '' then
    begin
        Exit;
    end;

    if not FileExists(m_config_path) then
    begin
        save_log_config(Result);
        Exit;
    end;

    ini := TIniFile.Create(m_config_path);
    try
        Result.enabled := ini.ReadBool('log', 'enabled', Result.enabled);
        level_value := ini.ReadInteger('log', 'level', Ord(Result.level));
        if (level_value >= Ord(Low(TncLogLevel))) and (level_value <= Ord(High(TncLogLevel))) then
        begin
            Result.level := TncLogLevel(level_value);
        end;
        Result.max_size_kb := ini.ReadInteger('log', 'max_size_kb', Result.max_size_kb);
        Result.log_path := ini.ReadString('log', 'log_path', Result.log_path);
    finally
        ini.Free;
    end;
end;

procedure TncConfigManager.save_log_config(const config: TncLogConfig);
var
    ini: TIniFile;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    ensure_config_directory;
    ini := TIniFile.Create(m_config_path);
    try
        ini.WriteBool('log', 'enabled', config.enabled);
        ini.WriteInteger('log', 'level', Ord(config.level));
        ini.WriteInteger('log', 'max_size_kb', config.max_size_kb);
        ini.WriteString('log', 'log_path', config.log_path);
        write_config_version(ini);
    finally
        ini.Free;
    end;
end;

function get_default_config_path: string;
var
    legacy_primary_path: string;
    legacy_secondary_path: string;
begin
    Result := IncludeTrailingPathDelimiter(get_runtime_root_directory) + 'cassotis_ime.ini';
    if FileExists(Result) then
    begin
        Exit;
    end;

    legacy_primary_path := resolve_runtime_path('cassotis_ime.ini');
    legacy_secondary_path := resolve_runtime_path('config\cassotis_ime.ini');

    if FileExists(legacy_primary_path) then
    begin
        try
            TFile.Move(legacy_primary_path, Result);
        except
            try
                TFile.Copy(legacy_primary_path, Result, False);
            except
                // Keep using the fixed runtime path even if migration fails.
            end;
        end;
        Exit;
    end;

    if FileExists(legacy_secondary_path) then
    begin
        try
            TFile.Move(legacy_secondary_path, Result);
        except
            try
                TFile.Copy(legacy_secondary_path, Result, False);
            except
                // Keep using the fixed runtime path even if migration fails.
            end;
        end;
    end;
end;

function get_default_dictionary_path_simplified: string;
begin
    Result := IncludeTrailingPathDelimiter(get_runtime_data_directory) + 'dict_sc.db';
end;

function get_default_dictionary_path_traditional: string;
begin
    Result := IncludeTrailingPathDelimiter(get_runtime_data_directory) + 'dict_tc.db';
end;

function get_default_user_dictionary_path: string;
begin
    Result := IncludeTrailingPathDelimiter(get_runtime_data_directory) + 'user_dict.db';
end;

end.
