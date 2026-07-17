unit nc_config;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IniFiles,
    System.IOUtils,
    Winapi.Windows,
    Winapi.ShlObj,
    Winapi.KnownFolders,
    Winapi.ActiveX,
    nc_types,
    nc_log;

type
    TncConfigManager = class
    private
        m_config_path: string;
        m_config_mutex: THandle;
        m_config_mutex_owned: Boolean;
        procedure acquire_config_mutex;
        procedure release_config_mutex;
        procedure ensure_config_directory;
        procedure write_config_version(const ini: TMemIniFile;
            const candidate_font_size_migrated: Boolean = False);
    public
        constructor create(const config_path: string);
        destructor Destroy; override;
        function load_engine_config: TncEngineConfig;
        function load_log_config: TncLogConfig;
        procedure save_engine_config(const config: TncEngineConfig);
        procedure save_engine_state_config(const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean);
        procedure save_dictionary_variant_config(const variant: TncDictionaryVariant);
        procedure save_log_config(const config: TncLogConfig);
        property config_path: string read m_config_path;
    end;

function get_default_config_path: string;
function get_runtime_data_directory: string;
function get_default_dictionary_path_simplified: string;
function get_default_dictionary_path_traditional: string;
function get_default_user_dictionary_path: string;
function nc_create_utf8_ini_file(const config_path: string): TMemIniFile;

implementation

const
    c_config_version = 12;
    c_font_name_utf8_migration_version = 11;
    c_candidate_font_size_config_version = 2;
    c_config_mutex_name = 'Local\CassotisIme_Config_v1';
    c_config_mutex_timeout_ms = 30000;

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

function try_extract_ini_section_name(const line_text: string; out section_name: string): Boolean;
var
    normalized_text: string;
begin
    Result := False;
    section_name := '';
    normalized_text := Trim(line_text);
    if (Length(normalized_text) < 3) or (normalized_text[1] <> '[') or
        (normalized_text[Length(normalized_text)] <> ']') then
    begin
        Exit;
    end;

    section_name := Trim(Copy(normalized_text, 2, Length(normalized_text) - 2));
    Result := section_name <> '';
end;

function try_extract_ini_key_name(const line_text: string; out key_name: string): Boolean;
var
    normalized_text: string;
    equal_pos: Integer;
begin
    Result := False;
    key_name := '';
    normalized_text := Trim(line_text);
    if normalized_text = '' then
    begin
        Exit;
    end;
    if (normalized_text[1] = ';') or (normalized_text[1] = '#') or
        (normalized_text[1] = '[') then
    begin
        Exit;
    end;

    equal_pos := Pos('=', normalized_text);
    if equal_pos <= 1 then
    begin
        Exit;
    end;

    key_name := Trim(Copy(normalized_text, 1, equal_pos - 1));
    Result := key_name <> '';
end;

function normalize_duplicate_ini_keys(const config_path: string): Boolean;
var
    lines: TArray<string>;
    line_sections: TArray<string>;
    keep_lines: TArray<Boolean>;
    output_lines: TStringList;
    seen_keys: TStringList;
    current_section: string;
    section_name: string;
    key_name: string;
    section_key: string;
    line_index: Integer;
begin
    Result := False;
    if (config_path = '') or (not FileExists(config_path)) then
    begin
        Exit;
    end;

    try
        lines := TFile.ReadAllLines(config_path, TEncoding.UTF8);
    except
        Exit;
    end;

    SetLength(line_sections, Length(lines));
    current_section := '';
    for line_index := 0 to High(lines) do
    begin
        if try_extract_ini_section_name(lines[line_index], section_name) then
        begin
            current_section := section_name;
        end;
        line_sections[line_index] := current_section;
    end;

    SetLength(keep_lines, Length(lines));
    seen_keys := TStringList.Create;
    try
        seen_keys.CaseSensitive := False;
        for line_index := High(lines) downto 0 do
        begin
            keep_lines[line_index] := True;
            if try_extract_ini_key_name(lines[line_index], key_name) then
            begin
                section_key := LowerCase(line_sections[line_index]) + #1 + LowerCase(key_name);
                if seen_keys.IndexOf(section_key) >= 0 then
                begin
                    keep_lines[line_index] := False;
                    Result := True;
                end
                else
                begin
                    seen_keys.Add(section_key);
                end;
            end;
        end;
    finally
        seen_keys.Free;
    end;

    if not Result then
    begin
        Exit;
    end;

    output_lines := TStringList.Create;
    try
        for line_index := 0 to High(lines) do
        begin
            if keep_lines[line_index] then
            begin
                output_lines.Add(lines[line_index]);
            end;
        end;
        try
            output_lines.SaveToFile(config_path, TEncoding.UTF8);
        except
            Result := False;
        end;
    finally
        output_lines.Free;
    end;
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

function clamp_candidate_font_size(const value: Integer): Integer;
begin
    Result := value;
    if Result < c_min_candidate_font_size then
    begin
        Result := c_min_candidate_font_size;
    end
    else if Result > c_max_candidate_font_size then
    begin
        Result := c_max_candidate_font_size;
    end;
end;

function clamp_candidate_color_scheme(const value: Integer): Integer;
begin
    Result := value;
    if (Result < c_min_candidate_color_scheme) or (Result > c_max_candidate_color_scheme) then
    begin
        Result := c_default_candidate_color_scheme;
    end;
end;

function candidate_color_scheme_to_text(const value: Integer): string;
begin
    case clamp_candidate_color_scheme(value) of
        1:
            Result := 'moon-white';
        2:
            Result := 'celadon';
        3:
            Result := 'clear-blue';
        4:
            Result := 'pine-ink';
        5:
            Result := 'indigo-night';
    else
        Result := 'clear-white';
    end;
end;

function parse_candidate_color_scheme_text(const value: string; const default_value: Integer): Integer;
var
    numeric_value: Integer;
    normalized_value: string;
begin
    normalized_value := Trim(value);
    if normalized_value = '' then
    begin
        Result := clamp_candidate_color_scheme(default_value);
        Exit;
    end;

    if TryStrToInt(normalized_value, numeric_value) then
    begin
        Result := clamp_candidate_color_scheme(numeric_value);
        Exit;
    end;

    if SameText(normalized_value, 'moon-white') then
    begin
        Result := 1;
    end
    else if SameText(normalized_value, 'celadon') then
    begin
        Result := 2;
    end
    else if SameText(normalized_value, 'clear-blue') then
    begin
        Result := 3;
    end
    else if SameText(normalized_value, 'pine-ink') then
    begin
        Result := 4;
    end
    else if SameText(normalized_value, 'indigo-night') then
    begin
        Result := 5;
    end
    else if SameText(normalized_value, 'clear-white') then
    begin
        Result := 0;
    end
    else
    begin
        Result := clamp_candidate_color_scheme(default_value);
    end;
end;

function contains_damaged_text_marker(const value: string): Boolean;
var
    replacement_mojibake: string;
begin
    replacement_mojibake := string(WideChar($00EF)) + string(WideChar($00BF)) + string(WideChar($00BD));
    Result := (Pos(string(WideChar($FFFD)), value) > 0) or
        (Pos(replacement_mojibake, value) > 0) or
        (Pos('?', value) > 0);
end;

procedure move_damaged_ini_aside(const config_path: string);
var
    guid: TGUID;
    backup_path: string;
begin
    if (config_path = '') or (not FileExists(config_path)) then
    begin
        Exit;
    end;

    CreateGUID(guid);
    backup_path := config_path + '.invalid.' + GUIDToString(guid);
    try
        TFile.Move(config_path, backup_path);
    except
        try
            TFile.Copy(config_path, backup_path, True);
            TFile.Delete(config_path);
        except
            // If the damaged file cannot be moved, keep it and let callers use defaults.
        end;
    end;
end;

function nc_create_utf8_ini_file(const config_path: string): TMemIniFile;
begin
    Result := nil;
    if config_path = '' then
    begin
        Exit;
    end;

    try
        Result := TMemIniFile.Create(config_path, TEncoding.UTF8);
        Exit;
    except
    end;

    move_damaged_ini_aside(config_path);
    try
        Result := TMemIniFile.Create(config_path, TEncoding.UTF8);
    except
        Result := nil;
    end;
end;

function is_reasonable_candidate_font_name(const value: string): Boolean;
var
    i: Integer;
    code_point: Integer;
begin
    Result := Trim(value) <> '';
    if not Result then
    begin
        Exit;
    end;

    for i := 1 to Length(value) do
    begin
        code_point := Ord(value[i]);
        if ((code_point >= 32) and (code_point <= 126)) or
            ((code_point >= $3400) and (code_point <= $9FFF)) or
            ((code_point >= $F900) and (code_point <= $FAFF)) then
        begin
            Continue;
        end;

        Result := False;
        Exit;
    end;
end;

function is_ascii_text(const value: string): Boolean;
var
    i: Integer;
begin
    Result := True;
    for i := 1 to Length(value) do
    begin
        if Ord(value[i]) > 126 then
        begin
            Result := False;
            Exit;
        end;
    end;
end;

function read_legacy_ini_string(const config_path: string; const section: string; const ident: string): string;
var
    ini: TIniFile;
begin
    Result := '';
    if not FileExists(config_path) then
    begin
        Exit;
    end;

    ini := nil;
    try
        ini := TIniFile.Create(config_path);
        if ini <> nil then
        begin
            Result := ini.ReadString(section, ident, '');
        end;
    except
        Result := '';
    end;
    if ini <> nil then
    begin
        try
            ini.Free;
        except
            // Ignore legacy INI cleanup failures. The caller can keep defaults.
        end;
    end;
end;

function safe_ini_read_string(const ini: TMemIniFile; const section: string; const ident: string;
    const default_value: string): string;
begin
    Result := default_value;
    if ini = nil then
    begin
        Exit;
    end;

    try
        Result := ini.ReadString(section, ident, default_value);
    except
        Result := default_value;
    end;
end;

function safe_ini_read_integer(const ini: TMemIniFile; const section: string; const ident: string;
    const default_value: Integer): Integer;
begin
    Result := default_value;
    if ini = nil then
    begin
        Exit;
    end;

    try
        Result := ini.ReadInteger(section, ident, default_value);
    except
        Result := default_value;
    end;
end;

function safe_ini_read_bool(const ini: TMemIniFile; const section: string; const ident: string;
    const default_value: Boolean): Boolean;
begin
    Result := default_value;
    if ini = nil then
    begin
        Exit;
    end;

    try
        Result := ini.ReadBool(section, ident, default_value);
    except
        Result := default_value;
    end;
end;

function safe_ini_value_exists(const ini: TMemIniFile; const section: string; const ident: string): Boolean;
begin
    Result := False;
    if ini = nil then
    begin
        Exit;
    end;

    try
        Result := ini.ValueExists(section, ident);
    except
        Result := False;
    end;
end;

function normalize_filesystem_path_text(const path_text: string): string;
var
    prefix: string;
begin
    Result := Trim(path_text);
    if Result = '' then
    begin
        Exit;
    end;

    if Copy(Result, 1, 4) = '\\?\' then
    begin
        Exit;
    end;

    prefix := '';
    if Copy(Result, 1, 2) = '\\' then
    begin
        prefix := '\\';
        Delete(Result, 1, 2);
    end
    else if (Length(Result) >= 3) and (Result[2] = ':') and (Result[3] = '\') then
    begin
        prefix := Copy(Result, 1, 3);
        Delete(Result, 1, 3);
    end;

    while Pos('\\', Result) > 0 do
    begin
        Result := StringReplace(Result, '\\', '\', [rfReplaceAll]);
    end;

    Result := prefix + Result;
end;

function resolve_runtime_path(const path_text: string): string;
var
    module_dir: string;
begin
    Result := normalize_filesystem_path_text(path_text);
    if Result = '' then
    begin
        Exit;
    end;

    if TPath.IsPathRooted(Result) then
    begin
        Result := normalize_filesystem_path_text(ExpandFileName(Result));
        Exit;
    end;

    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := normalize_filesystem_path_text(ExpandFileName(Result));
        Exit;
    end;

    Result := ExpandFileName(IncludeTrailingPathDelimiter(module_dir) + Result);
    Result := normalize_filesystem_path_text(Result);
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

function get_known_local_app_data_directory: string;
var
    path_ptr: PWideChar;
begin
    Result := '';
    path_ptr := nil;
    if Succeeded(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, 0, path_ptr)) and (path_ptr <> nil) then
    begin
        try
            Result := Trim(string(path_ptr));
        finally
            CoTaskMemFree(path_ptr);
        end;
    end;
end;

function get_local_app_data_directory: string;
begin
    // Do not rely on LOCALAPPDATA: TSF can be hosted by packaged apps whose
    // environment points to a package-local cache, splitting the user dictionary.
    Result := get_known_local_app_data_directory;
    if Result = '' then
    begin
        Result := Trim(GetEnvironmentVariable('LOCALAPPDATA'));
        if Result = '' then
        begin
            Result := TPath.GetHomePath;
        end;
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

constructor TncConfigManager.create(const config_path: string);
begin
    inherited create;
    m_config_mutex := 0;
    m_config_mutex_owned := False;
    if config_path = '' then
    begin
        m_config_path := get_default_config_path;
    end
    else
    begin
        m_config_path := config_path;
    end;
    acquire_config_mutex;
end;

destructor TncConfigManager.Destroy;
begin
    release_config_mutex;
    inherited Destroy;
end;

procedure TncConfigManager.acquire_config_mutex;
var
    wait_result: DWORD;
begin
    m_config_mutex := CreateMutex(nil, False, c_config_mutex_name);
    if m_config_mutex = 0 then
    begin
        RaiseLastOSError;
    end;

    wait_result := WaitForSingleObject(m_config_mutex, c_config_mutex_timeout_ms);
    if (wait_result = WAIT_OBJECT_0) or (wait_result = WAIT_ABANDONED) then
    begin
        m_config_mutex_owned := True;
        Exit;
    end;

    CloseHandle(m_config_mutex);
    m_config_mutex := 0;
    if wait_result = WAIT_TIMEOUT then
    begin
        raise Exception.Create('Timed out waiting for the Cassotis IME configuration lock');
    end;
    RaiseLastOSError;
end;

procedure TncConfigManager.release_config_mutex;
begin
    if m_config_mutex_owned and (m_config_mutex <> 0) then
    begin
        ReleaseMutex(m_config_mutex);
        m_config_mutex_owned := False;
    end;
    if m_config_mutex <> 0 then
    begin
        CloseHandle(m_config_mutex);
        m_config_mutex := 0;
    end;
end;

procedure TncConfigManager.write_config_version(const ini: TMemIniFile;
    const candidate_font_size_migrated: Boolean = False);
begin
    if ini = nil then
    begin
        Exit;
    end;

    ini.WriteInteger('meta', 'version', c_config_version);
    if candidate_font_size_migrated then
    begin
        ini.WriteInteger('meta', 'candidate_font_size_version', c_candidate_font_size_config_version);
    end;
end;

function TncConfigManager.load_engine_config: TncEngineConfig;
var
    ini: TMemIniFile;
    input_mode_value: Integer;
    config_version: Integer;
    candidate_font_size_version: Integer;
    log_config: TncLogConfig;
    variant_text: string;
    legacy_dict_path: string;
    needs_full_write: Boolean;
    legacy_sc_path: string;
    legacy_tc_path: string;
    legacy_user_path: string;
    legacy_font_name: string;
    stored_candidate_font_size: Integer;
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
    Result.candidate_font_name := c_default_candidate_font_name;
    Result.candidate_font_size := c_default_candidate_font_size;
    Result.candidate_color_scheme := c_default_candidate_color_scheme;
    Result.debug_mode := False;
    Result.dictionary_variant := dv_simplified;

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

    needs_full_write := normalize_duplicate_ini_keys(m_config_path);
    ini := nc_create_utf8_ini_file(m_config_path);
    try
        config_version := safe_ini_read_integer(ini, 'meta', 'version', 0);
        candidate_font_size_version := safe_ini_read_integer(ini, 'meta',
            'candidate_font_size_version', 1);
        input_mode_value := safe_ini_read_integer(ini, 'engine', 'input_mode', Ord(im_chinese));
        if input_mode_value = Ord(im_english) then
        begin
            Result.input_mode := im_english;
        end
        else
        begin
            Result.input_mode := im_chinese;
        end;

        Result.max_candidates := 9;
        Result.enable_ctrl_space_toggle := False;
        Result.enable_shift_space_full_width_toggle := True;
        Result.enable_ctrl_period_punct_toggle := True;
        Result.full_width_mode := safe_ini_read_bool(ini, 'engine', 'full_width_mode', False);
        Result.punctuation_full_width := safe_ini_read_bool(ini, 'engine', 'punctuation_full_width', True);
        Result.enable_segment_candidates := True;
        Result.segment_head_only_multi_syllable := True;
        Result.candidate_font_name := Trim(safe_ini_read_string(ini, 'appearance', 'candidate_font_name',
            c_default_candidate_font_name));
        if config_version < c_font_name_utf8_migration_version then
        begin
            legacy_font_name := Trim(read_legacy_ini_string(m_config_path, 'appearance',
                'candidate_font_name'));
            if (legacy_font_name <> '') and is_reasonable_candidate_font_name(legacy_font_name) and
                (not contains_damaged_text_marker(legacy_font_name)) then
            begin
                Result.candidate_font_name := legacy_font_name;
            end;
        end;
        if Result.candidate_font_name = '' then
        begin
            Result.candidate_font_name := c_default_candidate_font_name;
        end;
        if (config_version < c_font_name_utf8_migration_version) and
            (not is_ascii_text(Result.candidate_font_name)) then
        begin
            Result.candidate_font_name := c_default_candidate_font_name;
        end;
        if contains_damaged_text_marker(Result.candidate_font_name) or
            (not is_reasonable_candidate_font_name(Result.candidate_font_name)) then
        begin
            Result.candidate_font_name := c_default_candidate_font_name;
        end;
        stored_candidate_font_size := safe_ini_read_integer(ini, 'appearance',
            'candidate_font_size', c_default_candidate_font_size);
        if (candidate_font_size_version < c_candidate_font_size_config_version) and
            safe_ini_value_exists(ini, 'appearance', 'candidate_font_size') then
        begin
            Inc(stored_candidate_font_size);
        end;
        Result.candidate_font_size := clamp_candidate_font_size(stored_candidate_font_size);
        Result.candidate_color_scheme := parse_candidate_color_scheme_text(safe_ini_read_string(ini, 'appearance',
            'candidate_color_scheme', candidate_color_scheme_to_text(c_default_candidate_color_scheme)),
            c_default_candidate_color_scheme);
        Result.debug_mode := safe_ini_read_integer(ini, 'engine', 'debug', 0) <> 0;
        variant_text := safe_ini_read_string(ini, 'dictionary', 'variant', 'simplified');
        Result.dictionary_variant := parse_variant_text(variant_text);
        legacy_sc_path := safe_ini_read_string(ini, 'dictionary', 'db_path_sc', '');
        if legacy_sc_path = '' then
        begin
            legacy_dict_path := safe_ini_read_string(ini, 'dictionary', 'db_path', '');
            if legacy_dict_path <> '' then
            begin
                legacy_sc_path := legacy_dict_path;
            end
            else
            begin
                legacy_sc_path := get_legacy_dictionary_path_simplified;
            end;
        end;
        legacy_tc_path := safe_ini_read_string(ini, 'dictionary', 'db_path_tc', get_legacy_dictionary_path_traditional);
        legacy_user_path := safe_ini_read_string(ini, 'dictionary', 'user_db_path', get_legacy_user_dictionary_path);

        needs_full_write := needs_full_write or
            not safe_ini_value_exists(ini, 'engine', 'input_mode') or
            safe_ini_value_exists(ini, 'engine', 'max_candidates') or
            safe_ini_value_exists(ini, 'engine', 'enable_ctrl_space_toggle') or
            safe_ini_value_exists(ini, 'engine', 'enable_shift_space_full_width_toggle') or
            safe_ini_value_exists(ini, 'engine', 'enable_ctrl_period_punct_toggle') or
            safe_ini_value_exists(ini, 'engine', 'enable_segment_candidates') or
            safe_ini_value_exists(ini, 'engine', 'segment_head_only_multi_syllable') or
            safe_ini_value_exists(ini, 'engine', 'suppress_nonlexicon_complete_long_candidates') or
            not safe_ini_value_exists(ini, 'appearance', 'candidate_font_name') or
            not safe_ini_value_exists(ini, 'appearance', 'candidate_font_size') or
            not safe_ini_value_exists(ini, 'appearance', 'candidate_color_scheme') or
            not safe_ini_value_exists(ini, 'engine', 'debug') or
            not safe_ini_value_exists(ini, 'dictionary', 'variant') or
            safe_ini_value_exists(ini, 'dictionary', 'db_path') or
            safe_ini_value_exists(ini, 'dictionary', 'db_path_sc') or
            safe_ini_value_exists(ini, 'dictionary', 'db_path_tc') or
            safe_ini_value_exists(ini, 'dictionary', 'user_db_path');
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

    if (config_version < c_config_version) or
        (candidate_font_size_version < c_candidate_font_size_config_version) or needs_full_write then
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
    ini: TMemIniFile;
    candidate_font_name: string;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    ensure_config_directory;
    ini := nc_create_utf8_ini_file(m_config_path);
    if ini = nil then
    begin
        Exit;
    end;
    try
        ini.EraseSection('engine');
        ini.EraseSection('appearance');
        ini.EraseSection('dictionary');
        ini.WriteInteger('engine', 'input_mode', Ord(config.input_mode));
        ini.WriteBool('engine', 'full_width_mode', config.full_width_mode);
        ini.WriteBool('engine', 'punctuation_full_width', config.punctuation_full_width);
        ini.WriteInteger('engine', 'debug', Ord(config.debug_mode));
        candidate_font_name := Trim(config.candidate_font_name);
        if candidate_font_name = '' then
        begin
            candidate_font_name := c_default_candidate_font_name;
        end;
        ini.WriteString('appearance', 'candidate_font_name', candidate_font_name);
        ini.WriteInteger('appearance', 'candidate_font_size',
            clamp_candidate_font_size(config.candidate_font_size));
        ini.WriteString('appearance', 'candidate_color_scheme',
            candidate_color_scheme_to_text(config.candidate_color_scheme));
        ini.WriteString('dictionary', 'variant', variant_to_text(config.dictionary_variant));
        write_config_version(ini, True);
        ini.UpdateFile;
    finally
        ini.Free;
    end;
end;

procedure TncConfigManager.save_engine_state_config(const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean);
var
    ini: TMemIniFile;
    debug_mode: Boolean;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    ensure_config_directory;
    normalize_duplicate_ini_keys(m_config_path);
    ini := nc_create_utf8_ini_file(m_config_path);
    if ini = nil then
    begin
        Exit;
    end;
    try
        debug_mode := safe_ini_read_bool(ini, 'engine', 'debug', False);
        ini.EraseSection('engine');
        ini.WriteInteger('engine', 'input_mode', Ord(input_mode));
        ini.WriteBool('engine', 'full_width_mode', full_width_mode);
        ini.WriteBool('engine', 'punctuation_full_width', punctuation_full_width);
        ini.WriteInteger('engine', 'debug', Ord(debug_mode));
        write_config_version(ini);
        ini.UpdateFile;
    finally
        ini.Free;
    end;
    normalize_duplicate_ini_keys(m_config_path);
end;

procedure TncConfigManager.save_dictionary_variant_config(const variant: TncDictionaryVariant);
var
    ini: TMemIniFile;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    ensure_config_directory;
    normalize_duplicate_ini_keys(m_config_path);
    ini := nc_create_utf8_ini_file(m_config_path);
    if ini = nil then
    begin
        Exit;
    end;
    try
        ini.EraseSection('dictionary');
        ini.WriteString('dictionary', 'variant', variant_to_text(variant));
        write_config_version(ini);
        ini.UpdateFile;
    finally
        ini.Free;
    end;
    normalize_duplicate_ini_keys(m_config_path);
end;

function TncConfigManager.load_log_config: TncLogConfig;
var
    ini: TMemIniFile;
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

    normalize_duplicate_ini_keys(m_config_path);
    ini := nc_create_utf8_ini_file(m_config_path);
    try
        Result.enabled := safe_ini_read_bool(ini, 'log', 'enabled', Result.enabled);
        level_value := safe_ini_read_integer(ini, 'log', 'level', Ord(Result.level));
        if (level_value >= Ord(Low(TncLogLevel))) and (level_value <= Ord(High(TncLogLevel))) then
        begin
            Result.level := TncLogLevel(level_value);
        end;
        Result.max_size_kb := safe_ini_read_integer(ini, 'log', 'max_size_kb', Result.max_size_kb);
        Result.log_path := normalize_filesystem_path_text(safe_ini_read_string(ini, 'log', 'log_path',
            Result.log_path));
    finally
        ini.Free;
    end;
end;

procedure TncConfigManager.save_log_config(const config: TncLogConfig);
var
    ini: TMemIniFile;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    ensure_config_directory;
    ini := nc_create_utf8_ini_file(m_config_path);
    if ini = nil then
    begin
        Exit;
    end;
    try
        ini.EraseSection('log');
        ini.WriteBool('log', 'enabled', config.enabled);
        ini.WriteInteger('log', 'level', Ord(config.level));
        ini.WriteInteger('log', 'max_size_kb', config.max_size_kb);
        ini.WriteString('log', 'log_path', normalize_filesystem_path_text(config.log_path));
        write_config_version(ini);
        ini.UpdateFile;
    finally
        ini.Free;
    end;
end;

function get_default_config_path: string;
begin
    Result := IncludeTrailingPathDelimiter(get_runtime_root_directory) + 'cassotis_ime.ini';
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
