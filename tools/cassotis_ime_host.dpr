program cassotis_ime_host;

uses
    Winapi.Windows,
    Winapi.TlHelp32,
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

procedure append_log(const text: string); forward;

function elapsed_since(const start_tick: DWORD; const elapsed_ms: DWORD): Boolean;
begin
    Result := DWORD(GetTickCount - start_tick) >= elapsed_ms;
end;

function has_other_host_process: Boolean;
var
    snapshot: THandle;
    process_entry: TProcessEntry32;
    exe_name: string;
begin
    Result := False;
    snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if snapshot = INVALID_HANDLE_VALUE then
    begin
        Exit;
    end;

    try
        process_entry.dwSize := SizeOf(process_entry);
        if Process32First(snapshot, process_entry) then
        begin
            repeat
                if process_entry.th32ProcessID <> GetCurrentProcessId then
                begin
                    exe_name := string(process_entry.szExeFile);
                    if SameText(exe_name, 'cassotis_ime_host.exe') then
                    begin
                        Result := True;
                        Break;
                    end;
                end;
            until not Process32Next(snapshot, process_entry);
        end;
    finally
        CloseHandle(snapshot);
    end;
end;

function is_existing_host_responsive: Boolean;
var
    request_bytes: TBytes;
    response_bytes: TBytes;
    bytes_read: DWORD;
    response_text: string;
    call_ok: Boolean;
    pipe_name: string;
begin
    Result := False;
    pipe_name := get_nc_pipe_name;
    request_bytes := TEncoding.UTF8.GetBytes('PING');
    SetLength(response_bytes, 32);
    bytes_read := 0;

    call_ok := CallNamedPipe(PChar(pipe_name), @request_bytes[0], Length(request_bytes),
        @response_bytes[0], Length(response_bytes), bytes_read, 120);
    if not call_ok then
    begin
        if GetLastError = ERROR_PIPE_BUSY then
        begin
            if WaitNamedPipe(PChar(pipe_name), 120) then
            begin
                call_ok := CallNamedPipe(PChar(pipe_name), @request_bytes[0], Length(request_bytes),
                    @response_bytes[0], Length(response_bytes), bytes_read, 120);
            end;
        end;
    end;

    if not call_ok then
    begin
        Exit;
    end;

    if bytes_read <= 0 then
    begin
        Exit;
    end;

    response_text := TEncoding.UTF8.GetString(response_bytes, 0, bytes_read);
    Result := SameText(Trim(response_text), 'OK');
end;

function wait_existing_host_ready(const timeout_ms: DWORD): Boolean;
var
    start_tick: DWORD;
begin
    Result := False;
    start_tick := GetTickCount;
    repeat
        if is_existing_host_responsive then
        begin
            Result := True;
            Exit;
        end;
        Sleep(80);
    until elapsed_since(start_tick, timeout_ms);
end;

function acquire_host_mutex: Boolean;
var
    mutex_handle: THandle;
    err: DWORD;
begin
    Result := False;
    mutex_handle := CreateMutex(nil, True, PChar(get_nc_host_mutex));
    if mutex_handle = 0 then
    begin
        err := GetLastError;
        if err = ERROR_ACCESS_DENIED then
        begin
            if wait_existing_host_ready(1500) then
            begin
                Exit;
            end;
            append_log('mutex access denied and host not responsive, abort start');
            Exit;
        end;
        append_log(Format('CreateMutex failed err=%d', [err]));
        Exit;
    end;

    err := GetLastError;
    if err = ERROR_ALREADY_EXISTS then
    begin
        if has_other_host_process then
        begin
            if wait_existing_host_ready(1500) then
            begin
                CloseHandle(mutex_handle);
                Exit;
            end;
            append_log('existing host process detected but not responsive, abort start');
            CloseHandle(mutex_handle);
            Exit;
        end;
        append_log('recover stale host mutex');
    end;

    host_mutex := mutex_handle;
    Result := True;
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
            try_enable_per_monitor_dpi;
            Application.Initialize;
            Application.ShowMainForm := False;
            Application.CreateForm(TncEngineHostApp, host_app);
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
