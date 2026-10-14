unit nc_shell_upgrade;

interface

uses
    Winapi.Windows,
    nc_tsf_upgrade_scan;

type
    TncShellKind = (sk_none, sk_explorer, sk_search);

    TncShellIdentity = record
        pid, session_id: DWORD;
        created: TFileTime;
        image_path, owner_sid: string;
        elevated: Boolean;
    end;

    IncShellRestartBackend = interface
        ['{270B6001-536E-4509-A9A0-4C6FA005A001}']
        function PrepareExplorer: DWORD;
        function ArmExplorerRecovery: DWORD;
        function ShutdownExplorer: DWORD;
        function RestartExplorer: DWORD;
        function VerifyExplorerRecovery: DWORD;
        function RecoveryLogPath: string;
        procedure FinishExplorer;
        function StopSearch: DWORD;
    end;

function nc_shell_kind(const image_path, windows_dir: string): TncShellKind;
function nc_shell_restart_allowed(const target, caller: TncShellIdentity;
    const windows_dir: string; const modules_verified: Boolean;
    const comparison: TncTsfModuleComparison): Boolean;
function nc_same_shell_instance(const before, after: TncShellIdentity): Boolean;
function nc_read_shell_identity(const process_handle: THandle;
    out identity: TncShellIdentity): Boolean;
function nc_execute_shell_restart(const kind: TncShellKind;
    const backend: IncShellRestartBackend; out detail: string): Boolean;
function nc_native_shell_backend(const process_handle: THandle;
    const identity: TncShellIdentity): IncShellRestartBackend;

implementation

uses
    System.SysUtils,
    nc_shell_recovery;

type
    TncRmProcess = record
        pid: DWORD;
        created: TFileTime;
    end;

    TncRmProcessInfo = record
        process: TncRmProcess;
        app_name: array[0..255] of WideChar;
        service_name: array[0..63] of WideChar;
        app_type, app_status, session_id: DWORD;
        restartable: BOOL;
    end;

    TncNativeShellBackend = class(TInterfacedObject, IncShellRestartBackend)
    private
        m_process: THandle;
        m_identity: TncShellIdentity;
        m_session: DWORD;
        m_session_open: Boolean;
        m_recovery: TncExplorerRecovery;
    public
        constructor Create(const process_handle: THandle; const identity: TncShellIdentity);
        destructor Destroy; override;
        function PrepareExplorer: DWORD;
        function ArmExplorerRecovery: DWORD;
        function ShutdownExplorer: DWORD;
        function RestartExplorer: DWORD;
        function VerifyExplorerRecovery: DWORD;
        function RecoveryLogPath: string;
        procedure FinishExplorer;
        function StopSearch: DWORD;
    end;

function RmStartSession(out session: DWORD; flags: DWORD; key: PWideChar): DWORD;
    stdcall; external 'rstrtmgr.dll';
function RmEndSession(session: DWORD): DWORD; stdcall; external 'rstrtmgr.dll';
function RmRegisterResources(session: DWORD; file_count: UINT; files: Pointer;
    app_count: UINT; apps: Pointer; service_count: UINT; services: Pointer): DWORD;
    stdcall; external 'rstrtmgr.dll';
function RmGetList(session: DWORD; out needed: UINT; var count: UINT;
    processes: Pointer; var reboot_reasons: DWORD): DWORD;
    stdcall; external 'rstrtmgr.dll';
function RmShutdown(session, flags: DWORD; callback: Pointer): DWORD;
    stdcall; external 'rstrtmgr.dll';
function RmRestart(session, flags: DWORD; callback: Pointer): DWORD;
    stdcall; external 'rstrtmgr.dll';
function QueryFullProcessImageNameW(process: THandle; flags: DWORD;
    path: PWideChar; var count: DWORD): BOOL; stdcall; external 'kernel32.dll';
function GetProcessId(process: THandle): DWORD; stdcall; external 'kernel32.dll';
function ConvertSidToStringSidW(sid: PSID; out text: PWideChar): BOOL;
    stdcall; external 'advapi32.dll';

function nc_shell_kind(const image_path, windows_dir: string): TncShellKind;
var
    root: string;
begin
    Result := sk_none;
    if (image_path = '') or (windows_dir = '') then
        Exit;
    root := IncludeTrailingPathDelimiter(windows_dir);
    // Search is SearchHost.exe on Windows 11 and SearchApp.exe on Windows 10
    // (from version 2004); both are started again by Windows on demand.
    if SameText(image_path, root + 'explorer.exe') then
        Result := sk_explorer
    else if SameText(image_path, root +
        'SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\SearchHost.exe') or
        SameText(image_path, root +
        'SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\SearchApp.exe') then
        Result := sk_search;
end;

function nc_shell_restart_allowed(const target, caller: TncShellIdentity;
    const windows_dir: string; const modules_verified: Boolean;
    const comparison: TncTsfModuleComparison): Boolean;
begin
    Result := modules_verified and (comparison = tmc_changed) and
        (nc_shell_kind(target.image_path, windows_dir) <> sk_none) and
        (target.pid <> 0) and (target.pid <> caller.pid) and
        ((target.created.dwLowDateTime <> 0) or (target.created.dwHighDateTime <> 0)) and
        (target.session_id <> 0) and (target.session_id = caller.session_id) and
        (target.owner_sid <> '') and (target.owner_sid = caller.owner_sid) and
        not target.elevated;
end;

function nc_same_shell_instance(const before, after: TncShellIdentity): Boolean;
begin
    Result := (before.pid = after.pid) and (before.session_id = after.session_id) and
        (before.owner_sid = after.owner_sid) and (before.elevated = after.elevated) and
        SameText(before.image_path, after.image_path) and
        (CompareFileTime(before.created, after.created) = 0);
end;

function nc_read_shell_identity(const process_handle: THandle;
    out identity: TncShellIdentity): Boolean;
var
    token: THandle;
    count, size, elevation: DWORD;
    buffer: TArray<Char>;
    user: TBytes;
    sid_text: PWideChar;
    exited, kernel, user_time: TFileTime;
begin
    identity := Default(TncShellIdentity);
    Result := False;
    identity.pid := GetProcessId(process_handle);
    if (identity.pid = 0) or not GetProcessTimes(process_handle, identity.created,
        exited, kernel, user_time) then
        Exit;
    SetLength(buffer, 32768);
    count := Length(buffer);
    if not QueryFullProcessImageNameW(process_handle, 0, @buffer[0], count) then
        Exit;
    SetString(identity.image_path, PChar(@buffer[0]), count);
    count := GetLongPathName(PChar(identity.image_path), @buffer[0], Length(buffer));
    if (count = 0) or (count >= DWORD(Length(buffer))) then
        Exit;
    SetString(identity.image_path, PChar(@buffer[0]), count);
    if not OpenProcessToken(process_handle, TOKEN_QUERY, token) then
        Exit;
    try
        if not GetTokenInformation(token, TokenSessionId, @identity.session_id,
            SizeOf(identity.session_id), size) or
            not GetTokenInformation(token, TokenElevation, @elevation, SizeOf(elevation), size) then
            Exit;
        identity.elevated := elevation <> 0;
        size := 0;
        GetTokenInformation(token, TokenUser, nil, 0, size);
        if (size = 0) or (size > 65536) then
            Exit;
        SetLength(user, size);
        if not GetTokenInformation(token, TokenUser, @user[0], size, size) then
            Exit;
        sid_text := nil;
        if not ConvertSidToStringSidW(PTokenUser(@user[0]).User.Sid, sid_text) then
            Exit;
        try
            identity.owner_sid := string(sid_text);
        finally
            LocalFree(HLOCAL(sid_text));
        end;
        Result := True;
    finally
        CloseHandle(token);
    end;
end;

function nc_execute_shell_restart(const kind: TncShellKind;
    const backend: IncShellRestartBackend; out detail: string): Boolean;
var
    prepared, armed, stopped, restarted, recovered: DWORD;
begin
    Result := False;
    detail := 'Not an eligible shell process';
    if kind = sk_search then
    begin
        stopped := backend.StopSearch;
        detail := Format('Search stop=%d; Windows restarts Search on demand', [stopped]);
        Exit(stopped = ERROR_SUCCESS);
    end;
    if kind <> sk_explorer then
        Exit;
    try
        prepared := backend.PrepareExplorer;
        detail := Format('Explorer prepare=%d', [prepared]);
        if prepared <> ERROR_SUCCESS then
            Exit;
        armed := backend.ArmExplorerRecovery;
        detail := Format('Explorer recovery guard=%d', [armed]);
        if armed <> ERROR_SUCCESS then
            Exit;
        try
            stopped := backend.ShutdownExplorer;
        finally
            // RM can close some windows even when shutdown reports a failure.
            try
                restarted := backend.RestartExplorer;
            finally
                recovered := backend.VerifyExplorerRecovery;
            end;
        end;
        detail := Format('Explorer graceful shutdown=%d restart=%d desktop_verified=%d',
            [stopped, restarted, recovered]);
        // Restart Manager's results beside the watcher's lines: the recovery
        // log is the file users send, and Setup's log has them elsewhere.
        nc_shell_recovery_note(backend.RecoveryLogPath, detail);
        Result := (stopped = ERROR_SUCCESS) and (recovered = ERROR_SUCCESS);
    finally
        if backend.RecoveryLogPath <> '' then
            detail := detail + '; recovery_log=' + backend.RecoveryLogPath;
        backend.FinishExplorer;
    end;
end;

constructor TncNativeShellBackend.Create(const process_handle: THandle;
    const identity: TncShellIdentity);
begin
    inherited Create;
    m_process := process_handle;
    m_identity := identity;
end;

destructor TncNativeShellBackend.Destroy;
begin
    FinishExplorer;
    inherited;
end;

function TncNativeShellBackend.PrepareExplorer: DWORD;
var
    key: array[0..32] of WideChar;
    process: TncRmProcess;
    info: TncRmProcessInfo;
    needed, count, reasons: UINT;
begin
    FillChar(key, SizeOf(key), 0);
    Result := RmStartSession(m_session, 0, @key[0]);
    if Result <> ERROR_SUCCESS then
        Exit;
    m_session_open := True;
    process.pid := m_identity.pid;
    process.created := m_identity.created;
    // Register this process instance, never a DLL shared by other applications.
    Result := RmRegisterResources(m_session, 0, nil, 1, @process, 0, nil);
    if Result <> ERROR_SUCCESS then
        Exit;
    FillChar(info, SizeOf(info), 0);
    count := 1;
    needed := 0;
    reasons := 0;
    Result := RmGetList(m_session, needed, count, @info, reasons);
    if Result <> ERROR_SUCCESS then
        Exit;
    if (count <> 1) or (reasons <> 0) or not info.restartable or
        (info.process.pid <> process.pid) or
        (CompareFileTime(info.process.created, process.created) <> 0) or
        (info.session_id <> m_identity.session_id) then
        Result := ERROR_NOT_SUPPORTED;
end;

function TncNativeShellBackend.ShutdownExplorer: DWORD;
const
    RmShutdownOnlyRegistered = $10;
begin
    Result := RmShutdown(m_session, RmShutdownOnlyRegistered, nil);
end;

function TncNativeShellBackend.ArmExplorerRecovery: DWORD;
begin
    m_recovery := TncExplorerRecovery.Create;
    Result := m_recovery.Arm(m_identity);
end;

function TncNativeShellBackend.RestartExplorer: DWORD;
begin
    Result := RmRestart(m_session, 0, nil);
end;

function TncNativeShellBackend.VerifyExplorerRecovery: DWORD;
begin
    if m_recovery = nil then
        Exit(ERROR_NOT_READY);
    Result := m_recovery.Verify;
end;

function TncNativeShellBackend.RecoveryLogPath: string;
begin
    if m_recovery = nil then
        Result := ''
    else
        Result := m_recovery.LogPath;
end;

procedure TncNativeShellBackend.FinishExplorer;
begin
    FreeAndNil(m_recovery);
    if m_session_open then
    begin
        m_session_open := False;
        RmEndSession(m_session);
    end;
end;

function TncNativeShellBackend.StopSearch: DWORD;
begin
    // The caller retains the verified process handle, so PID reuse is harmless.
    if not TerminateProcess(m_process, 0) then
        Exit(GetLastError);
    if WaitForSingleObject(m_process, 2000) <> WAIT_OBJECT_0 then
        Exit(ERROR_TIMEOUT);
    Result := ERROR_SUCCESS;
end;

function nc_native_shell_backend(const process_handle: THandle;
    const identity: TncShellIdentity): IncShellRestartBackend;
begin
    Result := TncNativeShellBackend.Create(process_handle, identity);
end;

end.
