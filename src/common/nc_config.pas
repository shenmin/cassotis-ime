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
function get_default_dictionary_path_simplified: string;
function get_default_dictionary_path_traditional: string;
function get_default_user_dictionary_path: string;

implementation

const
    c_config_version = 5;
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
        Result := 'llama\\win64';
{$ELSE}
        Result := 'llama\\win32';
{$ENDIF}
        Exit;
    end;

{$IFDEF WIN64}
    Result := IncludeTrailingPathDelimiter(module_dir) + 'llama\\win64';
{$ELSE}
    Result := IncludeTrailingPathDelimiter(module_dir) + 'llama\\win32';
{$ENDIF}
end;

function get_default_ai_llama_runtime_dir_cuda: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'llama\\win64-cuda';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'llama\\win64-cuda';
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
    Result.dictionary_variant := dv_simplified;
    Result.dictionary_path_simplified := get_default_dictionary_path_simplified;
    Result.dictionary_path_traditional := get_default_dictionary_path_traditional;
    Result.user_dictionary_path := get_default_user_dictionary_path;
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

        Result.max_candidates := ini.ReadInteger('engine', 'max_candidates', 9);
        Result.enable_ai := ini.ReadBool('engine', 'enable_ai', False);
        Result.enable_ctrl_space_toggle := ini.ReadBool('engine', 'enable_ctrl_space_toggle', False);
        Result.enable_shift_space_full_width_toggle := ini.ReadBool('engine', 'enable_shift_space_full_width_toggle', True);
        Result.enable_ctrl_period_punct_toggle := ini.ReadBool('engine', 'enable_ctrl_period_punct_toggle', True);
        Result.full_width_mode := ini.ReadBool('engine', 'full_width_mode', False);
        Result.punctuation_full_width := ini.ReadBool('engine', 'punctuation_full_width', True);
        Result.enable_segment_candidates := ini.ReadBool('engine', 'enable_segment_candidates', True);
        variant_text := ini.ReadString('dictionary', 'variant', 'simplified');
        Result.dictionary_variant := parse_variant_text(variant_text);
        Result.dictionary_path_simplified := ini.ReadString('dictionary', 'db_path_sc', '');
        if Result.dictionary_path_simplified = '' then
        begin
            legacy_dict_path := ini.ReadString('dictionary', 'db_path', '');
            if legacy_dict_path <> '' then
            begin
                Result.dictionary_path_simplified := legacy_dict_path;
            end
            else
            begin
                Result.dictionary_path_simplified := get_default_dictionary_path_simplified;
            end;
        end;
        Result.dictionary_path_traditional := ini.ReadString('dictionary', 'db_path_tc',
            get_default_dictionary_path_traditional);
        Result.user_dictionary_path := ini.ReadString('dictionary', 'user_db_path', get_default_user_dictionary_path);
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
    finally
        ini.Free;
    end;

    Result.dictionary_path_simplified := resolve_runtime_path(Result.dictionary_path_simplified);
    Result.dictionary_path_traditional := resolve_runtime_path(Result.dictionary_path_traditional);
    Result.user_dictionary_path := resolve_runtime_path(Result.user_dictionary_path);
    Result.ai_llama_runtime_dir_cpu := resolve_runtime_path(Result.ai_llama_runtime_dir_cpu);
    Result.ai_llama_runtime_dir_cuda := resolve_runtime_path(Result.ai_llama_runtime_dir_cuda);
    Result.ai_llama_model_path := resolve_runtime_path(Result.ai_llama_model_path);

    if config_version < c_config_version then
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
        ini.WriteInteger('engine', 'max_candidates', config.max_candidates);
        ini.WriteBool('engine', 'enable_ai', config.enable_ai);
        ini.WriteBool('engine', 'enable_ctrl_space_toggle', config.enable_ctrl_space_toggle);
        ini.WriteBool('engine', 'enable_shift_space_full_width_toggle', config.enable_shift_space_full_width_toggle);
        ini.WriteBool('engine', 'enable_ctrl_period_punct_toggle', config.enable_ctrl_period_punct_toggle);
        ini.WriteBool('engine', 'full_width_mode', config.full_width_mode);
        ini.WriteBool('engine', 'punctuation_full_width', config.punctuation_full_width);
        ini.WriteBool('engine', 'enable_segment_candidates', config.enable_segment_candidates);
        ini.WriteString('dictionary', 'variant', variant_to_text(config.dictionary_variant));
        ini.WriteString('dictionary', 'db_path_sc', config.dictionary_path_simplified);
        ini.WriteString('dictionary', 'db_path_tc', config.dictionary_path_traditional);
        ini.WriteString('dictionary', 'user_db_path', config.user_dictionary_path);
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
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'cassotis_ime.ini';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'config\\cassotis_ime.ini';
end;

function get_default_dictionary_path_simplified: string;
var
    module_dir: string;
    data_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'dict_sc.db';
        Exit;
    end;

    data_dir := IncludeTrailingPathDelimiter(module_dir) + 'data';
    ForceDirectories(data_dir);
    Result := IncludeTrailingPathDelimiter(data_dir) + 'dict_sc.db';
end;

function get_default_dictionary_path_traditional: string;
var
    module_dir: string;
    data_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'dict_tc.db';
        Exit;
    end;

    data_dir := IncludeTrailingPathDelimiter(module_dir) + 'data';
    ForceDirectories(data_dir);
    Result := IncludeTrailingPathDelimiter(data_dir) + 'dict_tc.db';
end;

function get_default_user_dictionary_path: string;
var
    module_dir: string;
    config_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'user_dict.db';
        Exit;
    end;

    config_dir := IncludeTrailingPathDelimiter(module_dir) + 'config';
    ForceDirectories(config_dir);
    Result := IncludeTrailingPathDelimiter(config_dir) + 'user_dict.db';
end;

end.
