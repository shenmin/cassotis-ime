program cassotis_ime_host;

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    Vcl.Forms,
    nc_engine_host_app in '..\src\host\nc_engine_host_app.pas',
    nc_engine_host in '..\src\host\nc_engine_host.pas',
    nc_engine_intf in '..\src\engine\nc_engine_intf.pas',
    nc_candidate_fusion in '..\src\engine\nc_candidate_fusion.pas',
    nc_dictionary_intf in '..\src\engine\nc_dictionary_intf.pas',
    nc_dictionary_sqlite in '..\src\engine\nc_dictionary_sqlite.pas',
    nc_pinyin_parser in '..\src\engine\nc_pinyin_parser.pas',
    nc_config in '..\src\common\nc_config.pas',
    nc_types in '..\src\common\nc_types.pas',
    nc_log in '..\src\common\nc_log.pas',
    nc_sqlite in '..\src\common\nc_sqlite.pas',
    nc_ipc_common in '..\src\common\nc_ipc_common.pas';

{$R 'cassotis_ime_host.res'}

var
    host_app: TncEngineHostApp;
    log_path: string;
    log_enabled: Boolean;
    host_mutex: THandle;
const
    c_tray_host_mutex_name_format = 'Local\cassotis_ime_tray_host_v1_s%d';

procedure append_log(const text: string); forward;

procedure enforce_window_toolwindow_style(window_handle: HWND);
var
    ex_style: NativeInt;
begin
    if window_handle = 0 then
    begin
        Exit;
    end;

    ex_style := GetWindowLongPtr(window_handle, GWL_EXSTYLE);
    ex_style := (ex_style or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
    SetWindowLongPtr(window_handle, GWL_EXSTYLE, ex_style);
    SetWindowPos(
        window_handle,
        0,
        0,
        0,
        0,
        0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER or SWP_FRAMECHANGED
    );
end;

procedure enforce_application_toolwindow_style;
begin
    if Application = nil then
    begin
        Exit;
    end;
    enforce_window_toolwindow_style(Application.Handle);
end;

const
    c_ipc_security_sddl = 'D:(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;OW)(A;;GRGW;;;AU)S:(ML;;NW;;;LW)';

function ConvertStringSecurityDescriptorToSecurityDescriptorW(
    StringSecurityDescriptor: LPCWSTR; StringSDRevision: DWORD;
    var SecurityDescriptor: Pointer; SecurityDescriptorSize: PDWORD): BOOL; stdcall;
    external advapi32 name 'ConvertStringSecurityDescriptorToSecurityDescriptorW';

function build_ipc_security_attributes(out security_attributes: TSecurityAttributes;
    out security_descriptor: Pointer): Boolean;
begin
    FillChar(security_attributes, SizeOf(security_attributes), 0);
    security_descriptor := nil;
    Result := ConvertStringSecurityDescriptorToSecurityDescriptorW(
        PChar(c_ipc_security_sddl), 1, security_descriptor, nil);
    if Result then
    begin
        security_attributes.nLength := SizeOf(security_attributes);
        security_attributes.lpSecurityDescriptor := security_descriptor;
        security_attributes.bInheritHandle := False;
    end;
end;

function acquire_host_mutex: Boolean;
var
    mutex_handle: THandle;
    err: DWORD;
    security_attributes: TSecurityAttributes;
    security_descriptor: Pointer;
    security_attributes_ptr: PSecurityAttributes;
begin
    Result := False;
    security_descriptor := nil;
    security_attributes_ptr := nil;
    if build_ipc_security_attributes(security_attributes, security_descriptor) then
    begin
        security_attributes_ptr := @security_attributes;
    end;

    mutex_handle := CreateMutex(security_attributes_ptr, True, PChar(get_nc_host_mutex));
    if security_descriptor <> nil then
    begin
        LocalFree(HLOCAL(security_descriptor));
        security_descriptor := nil;
    end;
    if mutex_handle = 0 then
    begin
        err := GetLastError;
        if err = ERROR_ACCESS_DENIED then
        begin
            append_log('mutex access denied, host instance already exists');
            Exit;
        end;
        append_log(Format('CreateMutex failed err=%d', [err]));
        Exit;
    end;

    err := GetLastError;
    if err = ERROR_ALREADY_EXISTS then
    begin
        CloseHandle(mutex_handle);
        append_log('mutex already exists, abort start');
        Exit;
    end;

    host_mutex := mutex_handle;
    Result := True;
end;

function tray_host_mutex_exists: Boolean;
var
    session_id: DWORD;
    mutex_name: string;
    mutex_handle: THandle;
    err: DWORD;
begin
    session_id := 0;
    if not ProcessIdToSessionId(GetCurrentProcessId, session_id) then
    begin
        session_id := 0;
    end;

    mutex_name := Format(c_tray_host_mutex_name_format, [session_id]);
    mutex_handle := OpenMutex(SYNCHRONIZE, False, PChar(mutex_name));
    if mutex_handle <> 0 then
    begin
        CloseHandle(mutex_handle);
        Result := True;
        Exit;
    end;

    err := GetLastError;
    Result := err = ERROR_ACCESS_DENIED;
end;

procedure ensure_tray_host_running;
var
    module_dir: string;
    tray_host_path: string;
    command_line: string;
    start_info: TStartupInfo;
    proc_info: TProcessInformation;
begin
    if tray_host_mutex_exists then
    begin
        Exit;
    end;

    module_dir := ExtractFileDir(ParamStr(0));
    tray_host_path := IncludeTrailingPathDelimiter(module_dir) + 'cassotis_ime_tray_host.exe';
    if not FileExists(tray_host_path) then
    begin
        append_log('tray host not found, skip start');
        Exit;
    end;

    FillChar(start_info, SizeOf(start_info), 0);
    start_info.cb := SizeOf(start_info);
    FillChar(proc_info, SizeOf(proc_info), 0);
    command_line := '"' + tray_host_path + '"';
    if CreateProcess(PChar(tray_host_path), PChar(command_line), nil, nil, False, CREATE_NO_WINDOW, nil,
        PChar(module_dir), start_info, proc_info) then
    begin
        CloseHandle(proc_info.hProcess);
        CloseHandle(proc_info.hThread);
        append_log('tray host start requested');
    end
    else
    begin
        append_log(Format('tray host start failed err=%d', [GetLastError]));
    end;
end;

function resolve_log_path: string;
var
    config_path: string;
    config_manager: TncConfigManager;
    log_config: TncLogConfig;
    module_dir: string;
begin
    Result := '';
    log_enabled := False;
    config_path := get_default_config_path;
    if config_path <> '' then
    begin
        config_manager := TncConfigManager.create(config_path);
        try
            log_config := config_manager.load_log_config;
            log_enabled := log_config.enabled;
            if log_enabled then
            begin
                Result := Trim(log_config.log_path);
            end;
        finally
            config_manager.Free;
        end;
    end;

    if not log_enabled then
    begin
        Exit;
    end;

    if Result <> '' then
    begin
        Exit;
    end;

    module_dir := ExtractFileDir(ParamStr(0));
    if module_dir = '' then
    begin
        Result := 'logs\\engine_host.log';
    end
    else
    begin
        Result := IncludeTrailingPathDelimiter(module_dir) + 'logs\\engine_host.log';
    end;
end;

procedure append_log(const text: string);
var
    line: string;
begin
    if (not log_enabled) or (log_path = '') then
    begin
        Exit;
    end;

    line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + text + sLineBreak;
    ForceDirectories(ExtractFileDir(log_path));
    if FileExists(log_path) then
    begin
        TFile.AppendAllText(log_path, line, TEncoding.UTF8);
    end
    else
    begin
        TFile.WriteAllText(log_path, line, TEncoding.UTF8);
    end;
end;

procedure try_enable_per_monitor_dpi;
type
    Tset_process_dpi_awareness_context = function(const value: THandle): BOOL; stdcall;
    Tset_process_dpi_awareness = function(const value: Integer): HRESULT; stdcall;
const
    c_dpi_awareness_per_monitor = 2;
    c_dpi_awareness_context_per_monitor_v2 = THandle(-4);
var
    user32: HMODULE;
    shcore: HMODULE;
    set_context: Tset_process_dpi_awareness_context;
    set_awareness: Tset_process_dpi_awareness;
begin
    user32 := GetModuleHandle('user32.dll');
    if user32 <> 0 then
    begin
        set_context := Tset_process_dpi_awareness_context(GetProcAddress(user32, 'SetProcessDpiAwarenessContext'));
        if Assigned(set_context) then
        begin
            set_context(c_dpi_awareness_context_per_monitor_v2);
            Exit;
        end;
    end;

    shcore := LoadLibrary('shcore.dll');
    if shcore = 0 then
    begin
        Exit;
    end;

    try
        set_awareness := Tset_process_dpi_awareness(GetProcAddress(shcore, 'SetProcessDpiAwareness'));
        if Assigned(set_awareness) then
        begin
            set_awareness(c_dpi_awareness_per_monitor);
        end;
    finally
        FreeLibrary(shcore);
    end;
end;

begin
    host_mutex := 0;
    log_enabled := False;
    log_path := resolve_log_path;
    if not acquire_host_mutex then
    begin
        append_log('host already running');
        Halt(0);
    end;
    try
        try
            append_log('host start');
            ensure_tray_host_running;
            try_enable_per_monitor_dpi;
            Application.Initialize;
            Application.MainFormOnTaskbar := False;
            Application.ShowMainForm := False;
            enforce_application_toolwindow_style;
            Application.CreateForm(TncEngineHostApp, host_app);
            if host_app <> nil then
            begin
                enforce_window_toolwindow_style(host_app.Handle);
            end;
            enforce_application_toolwindow_style;
            append_log('host form created');
            Application.Run;
            append_log('host run ended');
        except
            on e: Exception do
            begin
                append_log(Format('exception %s: %s', [e.ClassName, e.Message]));
                raise;
            end;
        end;
    finally
        if host_mutex <> 0 then
        begin
            CloseHandle(host_mutex);
            host_mutex := 0;
        end;
    end;
end.
