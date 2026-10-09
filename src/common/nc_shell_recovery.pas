unit nc_shell_recovery;

interface

uses
    Winapi.Windows,
    nc_shell_upgrade;

type
    TncDesktopState = (ds_missing, ds_ready, ds_unverified);

    IncShellRecoveryMonitor = interface
        ['{73C3CD26-BB88-4637-AEC8-19F96F5E4C57}']
        function NowMs: UInt64;
        function DesktopState: TncDesktopState;
        function OriginalExited: Boolean;
        function Finished: Boolean;
        function StopAbandonedExplorer: DWORD;
        // beside_original: the original is still running without a desktop
        // and could not be stopped.
        function StartExplorer(const beside_original: Boolean): DWORD;
        procedure Pause(const milliseconds: DWORD);
    end;

    TncExplorerRecovery = class
    private
        m_ready, m_done, m_watcher: THandle;
        m_caller: TncShellIdentity;
        m_log_path: string;
    public
        destructor Destroy; override;
        function Arm(const expected_shell: TncShellIdentity): DWORD;
        function Verify: DWORD;
        procedure Finish;
        property LogPath: string read m_log_path;
    end;

function nc_desktop_state(const caller: TncShellIdentity;
    out shell: TncShellIdentity): TncDesktopState;
function nc_abandoned_shell_stop_allowed(const original, current, caller: TncShellIdentity;
    const windows_dir: string; const desktop: TncDesktopState;
    const handoff_finished, has_visible_windows: Boolean): Boolean;
function nc_shell_watcher_status(const watcher: THandle): string;
function nc_monitor_shell_recovery(const monitor: IncShellRecoveryMonitor;
    out detail: string): DWORD;
function nc_run_shell_recovery(const parent_pid, shell_pid: DWORD;
    const shell_created: TFileTime; const ready_name, done_name, log_path: string): DWORD;

implementation

uses
    Winapi.Messages,
    System.SysUtils,
    System.IOUtils;

type
    TncNativeRecoveryMonitor = class(TInterfacedObject, IncShellRecoveryMonitor)
    public
        caller, original_shell: TncShellIdentity;
        parent, shell, done, primary_token: THandle;
        log_path: string;
        function NowMs: UInt64;
        function DesktopState: TncDesktopState;
        function OriginalExited: Boolean;
        function Finished: Boolean;
        function StopAbandonedExplorer: DWORD;
        function StartExplorer(const beside_original: Boolean): DWORD;
        procedure Pause(const milliseconds: DWORD);
    end;

    PncVisibleWindowQuery = ^TncVisibleWindowQuery;
    TncVisibleWindowQuery = record
        pid: DWORD;
        found: Boolean;
    end;

function nc_create_process_with_token(token: THandle; logon_flags: DWORD;
    application_name, command_line: PWideChar; creation_flags: DWORD;
    environment: Pointer; current_directory: PWideChar;
    var startup_info: TStartupInfo; var process_info: TProcessInformation): BOOL;
    stdcall; external 'advapi32.dll' name 'CreateProcessWithTokenW';
function GetShellWindow: HWND; stdcall; external 'user32.dll';

procedure trace(const path, text: string);
begin
    if path = '' then
        Exit;
    try
        TFile.AppendAllText(path, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            ' ' + text + sLineBreak, TEncoding.UTF8);
    except
        // A diagnostic write must never prevent desktop recovery.
    end;
end;

function nc_desktop_state(const caller: TncShellIdentity;
    out shell: TncShellIdentity): TncDesktopState;
var
    desktop, tray: HWND;
    desktop_pid, tray_pid: DWORD;
    process: THandle;
    windows_dir: array[0..MAX_PATH] of Char;
    count: UINT;
    response: DWORD_PTR;
begin
    Result := ds_unverified;
    shell := Default(TncShellIdentity);
    desktop := GetShellWindow;
    tray := FindWindow('Shell_TrayWnd', nil);
    if (desktop = 0) and (tray = 0) then
        Exit(ds_missing);
    if (desktop = 0) or (tray = 0) then
        Exit;
    if not IsWindowVisible(tray) then
        Exit;
    GetWindowThreadProcessId(desktop, @desktop_pid);
    GetWindowThreadProcessId(tray, @tray_pid);
    if (desktop_pid = 0) or (desktop_pid <> tray_pid) then
        Exit;
    process := OpenProcess($1000 or SYNCHRONIZE, False, desktop_pid);
    if process = 0 then
        Exit;
    try
        if not nc_read_shell_identity(process, shell) or
            (WaitForSingleObject(process, 0) <> WAIT_TIMEOUT) then
            Exit;
        count := GetWindowsDirectory(@windows_dir[0], Length(windows_dir));
        if (count = 0) or (count >= UINT(Length(windows_dir))) or
            (nc_shell_kind(shell.image_path, string(windows_dir)) <> sk_explorer) or
            (shell.owner_sid <> caller.owner_sid) or
            (shell.session_id <> caller.session_id) or shell.elevated then
            Exit;
        // Process existence (including Explorer folder servers) is not a desktop.
        if SendMessageTimeout(tray, WM_NULL, 0, 0, SMTO_ABORTIFHUNG or SMTO_BLOCK,
            100, @response) = 0 then
            Exit;
        Result := ds_ready;
    finally
        CloseHandle(process);
    end;
end;

function nc_monitor_shell_recovery(const monitor: IncShellRecoveryMonitor;
    out detail: string): DWORD;
const
    c_handoff_timeout_ms = 120000;
    c_recovery_timeout_ms = 60000;
    c_missing_grace_ms = 2000;
    c_abandoned_grace_ms = 5000;
    // How long an original that was not stopped may keep the desktop away
    // before a new Explorer is started beside it: briefly when the stop was
    // refused or withheld (it will not exit), longer when it was accepted
    // (the process is on its way out).
    c_beside_refused_ms = 5000;
    c_beside_accepted_ms = 15000;
    c_retry_ms = 8000;
    c_max_launches = 4;
var
    started, recovery_started, missing_since, last_launch, stopped_at, now_ms: UInt64;
    missing_seen, recovery_seen, finished, original_exited, beside_original: Boolean;
    attempts, stop_attempts: Integer;
    last_error, stop_error: DWORD;
    state: TncDesktopState;
begin
    started := monitor.NowMs;
    recovery_started := 0;
    recovery_seen := False;
    missing_since := 0;
    last_launch := 0;
    stopped_at := 0;
    missing_seen := False;
    attempts := 0;
    stop_attempts := 0;
    last_error := ERROR_SUCCESS;
    stop_error := ERROR_SUCCESS;
    repeat
        now_ms := monitor.NowMs;
        finished := monitor.Finished;
        original_exited := monitor.OriginalExited;
        // RM shutdown/restart may itself take longer than the recovery budget.
        if not recovery_seen and (finished or original_exited) then
        begin
            recovery_seen := True;
            recovery_started := now_ms;
        end;
        state := monitor.DesktopState;
        if state = ds_ready then
        begin
            missing_seen := False;
            if finished then
            begin
                detail := Format('Desktop and taskbar ready; fallback attempts=%d stop_attempts=%d',
                    [attempts, stop_attempts]);
                Exit(ERROR_SUCCESS);
            end;
        end
        else if state = ds_missing then
        begin
            if not missing_seen then
            begin
                missing_seen := True;
                missing_since := now_ms;
            end;
            // Only recover an abandoned original after RM has returned (or its
            // caller exited). Never race an in-progress graceful shutdown.
            if not original_exited and finished and (stop_attempts = 0) and
                (now_ms - missing_since >= c_abandoned_grace_ms) then
            begin
                stop_error := monitor.StopAbandonedExplorer;
                Inc(stop_attempts);
                stopped_at := now_ms;
                original_exited := monitor.OriginalExited;
            end;
            // An original that stays (a folder window or a dialog is still
            // open, or the stop was refused) must not keep the desktop away:
            // without a shell window a new Explorer becomes the shell, and
            // the old process keeps what it shows.
            beside_original := not original_exited and finished and (stop_attempts > 0);
            if beside_original then
            begin
                if (stop_error = ERROR_SUCCESS) or (stop_error = ERROR_TIMEOUT) then
                    beside_original := now_ms - stopped_at >= c_beside_accepted_ms
                else
                    beside_original := now_ms - stopped_at >= c_beside_refused_ms;
            end;
            if (original_exited or beside_original) and
                (now_ms - missing_since >= c_missing_grace_ms) and
                (attempts < c_max_launches) and
                ((attempts = 0) or (now_ms - last_launch >= c_retry_ms)) then
            begin
                last_error := monitor.StartExplorer(not original_exited);
                Inc(attempts);
                last_launch := now_ms;
            end;
        end
        else
            missing_seen := False;
        now_ms := monitor.NowMs;
        if (recovery_seen and (now_ms - recovery_started >= c_recovery_timeout_ms)) or
            (not recovery_seen and (now_ms - started >= c_handoff_timeout_ms)) then
            Break;
        monitor.Pause(200);
    until False;
    detail := Format('Recovery deadline; desktop=%d attempts=%d launch_error=%d ' +
        'stop_attempts=%d stop_error=%d original_exited=%d handoff_finished=%d',
        [Ord(state), attempts, last_error, stop_attempts, stop_error,
         Ord(monitor.OriginalExited), Ord(monitor.Finished)]);
    if state = ds_ready then
        Result := ERROR_SUCCESS
    else
        Result := ERROR_TIMEOUT;
end;

function TncNativeRecoveryMonitor.NowMs: UInt64;
begin
    Result := GetTickCount64;
end;

function TncNativeRecoveryMonitor.DesktopState: TncDesktopState;
var
    current_shell: TncShellIdentity;
begin
    Result := nc_desktop_state(caller, current_shell);
end;

function TncNativeRecoveryMonitor.OriginalExited: Boolean;
begin
    Result := WaitForSingleObject(shell, 0) = WAIT_OBJECT_0;
end;

function TncNativeRecoveryMonitor.Finished: Boolean;
begin
    Result := (WaitForSingleObject(parent, 0) = WAIT_OBJECT_0) or
        (WaitForSingleObject(done, 0) = WAIT_OBJECT_0);
end;

function nc_abandoned_shell_stop_allowed(const original, current, caller: TncShellIdentity;
    const windows_dir: string; const desktop: TncDesktopState;
    const handoff_finished, has_visible_windows: Boolean): Boolean;
begin
    Result := handoff_finished and (desktop = ds_missing) and not has_visible_windows and
        nc_same_shell_instance(original, current) and
        (nc_shell_kind(current.image_path, windows_dir) = sk_explorer) and
        (current.pid <> 0) and (current.pid <> caller.pid) and
        ((current.created.dwLowDateTime <> 0) or (current.created.dwHighDateTime <> 0)) and
        (current.session_id <> 0) and (current.session_id = caller.session_id) and
        (current.owner_sid <> '') and (current.owner_sid = caller.owner_sid) and
        not current.elevated;
end;

function find_visible_process_window(window: HWND; parameter: LPARAM): BOOL; stdcall;
var
    query: PncVisibleWindowQuery;
    pid: DWORD;
begin
    query := PncVisibleWindowQuery(parameter);
    pid := 0;
    GetWindowThreadProcessId(window, @pid);
    if (pid = query.pid) and IsWindowVisible(window) then
        query.found := True;
    Result := not query.found;
end;

function TncNativeRecoveryMonitor.StopAbandonedExplorer: DWORD;
var
    current: TncShellIdentity;
    query: TncVisibleWindowQuery;
    windows_dir: array[0..MAX_PATH] of Char;
    count: UINT;
begin
    Result := ERROR_NOT_READY;
    try
        if OriginalExited then
            Exit(ERROR_SUCCESS);
        if not Finished or not nc_read_shell_identity(shell, current) then
            Exit;
        count := GetWindowsDirectory(@windows_dir[0], Length(windows_dir));
        if (count = 0) or (count >= UINT(Length(windows_dir))) then
            Exit;
        query := Default(TncVisibleWindowQuery);
        query.pid := current.pid;
        // Do not kill Explorer folders or file-operation dialogs left open.
        if not EnumWindows(@find_visible_process_window, LPARAM(@query)) and not query.found then
            Exit;
        if not nc_abandoned_shell_stop_allowed(original_shell, current, caller,
            string(windows_dir), DesktopState, Finished, query.found) then
        begin
            trace(log_path, Format('Abandoned stop withheld; same_instance=%d visible_windows=%d ' +
                'desktop=%d handoff_finished=%d', [Ord(nc_same_shell_instance(original_shell, current)),
                Ord(query.found), Ord(DesktopState), Ord(Finished)]));
            Exit;
        end;
        if OriginalExited then
            Exit(ERROR_SUCCESS);
        // This retained handle identifies the verified original, not a new
        // Explorer that might have reused its PID or already restored the shell.
        if not TerminateProcess(shell, 0) then
        begin
            Result := GetLastError;
            if OriginalExited then
                Result := ERROR_SUCCESS;
            Exit;
        end;
        if WaitForSingleObject(shell, 2000) <> WAIT_OBJECT_0 then
            Exit(ERROR_TIMEOUT);
        Result := ERROR_SUCCESS;
    finally
        trace(log_path, Format('Abandoned original Explorer stop=%d pid=%d exited=%d',
            [Result, original_shell.pid, Ord(OriginalExited)]));
    end;
end;

function TncNativeRecoveryMonitor.StartExplorer(const beside_original: Boolean): DWORD;
var
    startup: TStartupInfo;
    process: TProcessInformation;
    command, directory: string;
    launched: BOOL;
begin
    // Windows may have restored the desktop since the monitor's last check.
    if (DesktopState <> ds_missing) or not (OriginalExited or beside_original) then
        Exit(ERROR_NOT_READY);
    FillChar(startup, SizeOf(startup), 0);
    startup.cb := SizeOf(startup);
    startup.lpDesktop := 'winsta0\default';
    FillChar(process, SizeOf(process), 0);
    command := '"' + original_shell.image_path + '"';
    UniqueString(command);
    directory := ExtractFileDir(original_shell.image_path);
    if caller.elevated then
        launched := nc_create_process_with_token(primary_token, 0,
            PChar(original_shell.image_path), PChar(command), 0, nil,
            PChar(directory), startup, process)
    else
        launched := CreateProcess(PChar(original_shell.image_path), PChar(command), nil,
            nil, False, 0, nil, PChar(directory), startup, process);
    if not launched then
        Result := GetLastError
    else
    begin
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
        Result := ERROR_SUCCESS;
    end;
    trace(log_path, Format('Fallback Explorer launch=%d (original user token) beside_original=%d',
        [Result, Ord(not OriginalExited)]));
end;

procedure TncNativeRecoveryMonitor.Pause(const milliseconds: DWORD);
begin
    Sleep(milliseconds);
end;

function capture_original_token(const shell_process: THandle; out primary: THandle): DWORD;
var
    token, caller_token: THandle;
    privileges: TPrivilegeSet;
    allowed: BOOL;
begin
    primary := 0;
    if not OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, caller_token) then
        Exit(GetLastError);
    try
        FillChar(privileges, SizeOf(privileges), 0);
        privileges.PrivilegeCount := 1;
        privileges.Control := PRIVILEGE_SET_ALL_NECESSARY;
        privileges.Privilege[0].Attributes := SE_PRIVILEGE_ENABLED;
        if not LookupPrivilegeValue(nil, 'SeImpersonatePrivilege', privileges.Privilege[0].Luid) or
            not PrivilegeCheck(caller_token, privileges, allowed) then
            Exit(GetLastError);
        if not allowed then
            Exit(ERROR_PRIVILEGE_NOT_HELD);
    finally
        CloseHandle(caller_token);
    end;
    if not OpenProcessToken(shell_process, TOKEN_QUERY or TOKEN_DUPLICATE, token) then
        Exit(GetLastError);
    try
        if not DuplicateTokenEx(token, TOKEN_QUERY or TOKEN_DUPLICATE or TOKEN_ASSIGN_PRIMARY,
            nil, SecurityImpersonation, TokenPrimary, primary) then
            Exit(GetLastError);
        Result := ERROR_SUCCESS;
    finally
        CloseHandle(token);
    end;
end;

function nc_run_shell_recovery(const parent_pid, shell_pid: DWORD;
    const shell_created: TFileTime; const ready_name, done_name, log_path: string): DWORD;
var
    parent, shell, ready, done, primary: THandle;
    caller, parent_identity, shell_identity: TncShellIdentity;
    native: TncNativeRecoveryMonitor;
    monitor: IncShellRecoveryMonitor;
    detail: string;
begin
    Result := ERROR_INVALID_PARAMETER;
    if (parent_pid = 0) or (shell_pid = 0) or (ready_name = '') or (done_name = '') then
        Exit;
    parent := 0;
    shell := 0;
    ready := 0;
    done := 0;
    primary := 0;
    try
        if not nc_read_shell_identity(GetCurrentProcess, caller) then
            Exit(ERROR_ACCESS_DENIED);
        parent := OpenProcess($1000 or SYNCHRONIZE, False, parent_pid);
        // Obtain recovery rights before allowing the original desktop to close.
        shell := OpenProcess($1000 or SYNCHRONIZE or PROCESS_TERMINATE, False, shell_pid);
        if (parent = 0) or (shell = 0) then
            Exit(GetLastError);
        if not nc_read_shell_identity(parent, parent_identity) or
            (parent_identity.owner_sid <> caller.owner_sid) or
            (parent_identity.session_id <> caller.session_id) or
            not SameText(parent_identity.image_path, caller.image_path) or
            (WaitForSingleObject(parent, 0) <> WAIT_TIMEOUT) then
            Exit(ERROR_ACCESS_DENIED);
        if (nc_desktop_state(caller, shell_identity) <> ds_ready) or
            (shell_identity.pid <> shell_pid) or
            (CompareFileTime(shell_identity.created, shell_created) <> 0) then
            Exit(ERROR_NOT_READY);
        if caller.elevated then
        begin
            Result := capture_original_token(shell, primary);
            if Result <> ERROR_SUCCESS then
                Exit;
        end;
        ready := OpenEvent(EVENT_MODIFY_STATE, False, PChar(ready_name));
        done := OpenEvent(SYNCHRONIZE, False, PChar(done_name));
        if (ready = 0) or (done = 0) then
            Exit(GetLastError);
        native := TncNativeRecoveryMonitor.Create;
        monitor := native;
        native.caller := caller;
        native.original_shell := shell_identity;
        native.parent := parent;
        native.shell := shell;
        native.done := done;
        native.primary_token := primary;
        native.log_path := log_path;
        trace(log_path, Format('Recovery armed; parent=%d original_shell=%d', [parent_pid, shell_pid]));
        if not SetEvent(ready) then
            Exit(GetLastError);
        Result := nc_monitor_shell_recovery(monitor, detail);
        trace(log_path, detail);
    finally
        monitor := nil;
        if primary <> 0 then CloseHandle(primary);
        if done <> 0 then CloseHandle(done);
        if ready <> 0 then CloseHandle(ready);
        if shell <> 0 then CloseHandle(shell);
        if parent <> 0 then CloseHandle(parent);
    end;
end;

destructor TncExplorerRecovery.Destroy;
begin
    Finish;
    inherited;
end;

function TncExplorerRecovery.Arm(const expected_shell: TncShellIdentity): DWORD;
var
    shell: TncShellIdentity;
    id: TGUID;
    ready_name, done_name, command: string;
    startup: TStartupInfo;
    process: TProcessInformation;
    handles: array[0..1] of THandle;
    wait_result: DWORD;
begin
    if (expected_shell.pid = 0) or
        not nc_read_shell_identity(GetCurrentProcess, m_caller) or
        (nc_desktop_state(m_caller, shell) <> ds_ready) or
        not nc_same_shell_instance(expected_shell, shell) then
        Exit(ERROR_NOT_READY);
    CreateGUID(id);
    ready_name := 'Local\CassotisIme.ShellRecovery.' + GUIDToString(id) + '.ready';
    done_name := 'Local\CassotisIme.ShellRecovery.' + GUIDToString(id) + '.done';
    m_log_path := TPath.Combine(TPath.GetTempPath, 'CassotisIme-shell-recovery-' + GUIDToString(id) + '.log');
    m_ready := CreateEvent(nil, True, False, PChar(ready_name));
    m_done := CreateEvent(nil, True, False, PChar(done_name));
    if (m_ready = 0) or (m_done = 0) then
        Exit(GetLastError);
    command := Format('"%s" watch_shell_restart -parent_pid %d -shell_pid %d ' +
        '-shell_created_low %u -shell_created_high %u -ready_event "%s" -done_event "%s" -log_path "%s"',
        [m_caller.image_path, m_caller.pid, shell.pid, shell.created.dwLowDateTime,
         shell.created.dwHighDateTime, ready_name, done_name, m_log_path]);
    UniqueString(command);
    FillChar(startup, SizeOf(startup), 0);
    startup.cb := SizeOf(startup);
    startup.dwFlags := STARTF_USESHOWWINDOW;
    startup.wShowWindow := SW_HIDE;
    FillChar(process, SizeOf(process), 0);
    if not CreateProcess(PChar(m_caller.image_path), PChar(command), nil, nil, False,
        CREATE_NO_WINDOW, nil, nil, startup, process) then
        Exit(GetLastError);
    CloseHandle(process.hThread);
    m_watcher := process.hProcess;
    handles[0] := m_ready;
    handles[1] := m_watcher;
    wait_result := WaitForMultipleObjects(2, @handles[0], False, 5000);
    if wait_result <> WAIT_OBJECT_0 then
    begin
        trace(m_log_path, Format('Recovery not ready; wait=%d; Explorer will not be closed', [wait_result]));
        Exit(ERROR_NOT_READY);
    end;
    Result := ERROR_SUCCESS;
end;

function TncExplorerRecovery.Verify: DWORD;
var
    shell: TncShellIdentity;
    started: UInt64;
begin
    // Both RM calls have returned. The watcher may now recover a verified
    // original that lost its desktop windows without finishing process exit.
    if (m_done = 0) or not SetEvent(m_done) then
    begin
        trace(m_log_path, 'Cannot notify recovery watcher that shell handoff completed');
        Exit(ERROR_NOT_READY);
    end;
    trace(m_log_path, 'Shell handoff completed; verifying desktop recovery');
    started := GetTickCount64;
    repeat
        if nc_desktop_state(m_caller, shell) = ds_ready then
        begin
            trace(m_log_path, Format('Desktop verified; shell PID=%d', [shell.pid]));
            Exit(ERROR_SUCCESS);
        end;
        Sleep(200);
    until GetTickCount64 - started >= 30000;
    trace(m_log_path, 'Desktop verification timed out; recovery watcher ' +
        nc_shell_watcher_status(m_watcher));
    Result := ERROR_TIMEOUT;
end;

function nc_shell_watcher_status(const watcher: THandle): string;
var
    wait_result, exit_code: DWORD;
begin
    if watcher = 0 then
        Exit('not started');
    wait_result := WaitForSingleObject(watcher, 0);
    if wait_result = WAIT_TIMEOUT then
        Exit('running');
    if wait_result = WAIT_OBJECT_0 then
    begin
        if GetExitCodeProcess(watcher, exit_code) then
            Exit(Format('exited, code=%d', [exit_code]));
    end;
    Result := Format('state unavailable, error=%d', [GetLastError]);
end;

procedure TncExplorerRecovery.Finish;
begin
    if m_done <> 0 then
    begin
        SetEvent(m_done);
        CloseHandle(m_done);
        m_done := 0;
    end;
    if m_ready <> 0 then
    begin
        CloseHandle(m_ready);
        m_ready := 0;
    end;
    if m_watcher <> 0 then
    begin
        // The independent watcher must survive us if the desktop is still missing.
        CloseHandle(m_watcher);
        m_watcher := 0;
    end;
end;

end.
