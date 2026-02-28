unit nc_engine_host;

interface

uses
    Winapi.Windows,
    Winapi.MultiMon,
    System.SysUtils,
    System.Types,
    System.Classes,
    System.SyncObjs,
    System.Generics.Collections,
    System.IOUtils,
    nc_types,
    nc_engine_intf,
    nc_candidate_window,
    nc_config,
    nc_ipc_common;

type
    TncEngineHost = class;

    TncHostSession = class
    private
        m_owner: TncEngineHost;
        m_session_id: string;
        m_engine: TncEngine;
        m_candidate_window: TncCandidateWindow;
        m_last_caret: TPoint;
        m_has_caret: Boolean;
        m_candidates: TncCandidateList;
        m_page_index: Integer;
        m_page_count: Integer;
        m_selected_index: Integer;
        m_preedit_text: string;
        m_candidate_dirty: Boolean;
        procedure ensure_candidate_window;
        procedure handle_remove_user_candidate(const candidate_index: Integer);
    public
        constructor create(const owner: TncEngineHost; const session_id: string; const config: TncEngineConfig);
        destructor Destroy; override;
        procedure update_config(const config: TncEngineConfig);
        procedure set_caret(const point: TPoint; const has_caret: Boolean);
        function needs_candidate_refresh(const point: TPoint; const has_caret: Boolean): Boolean;
        procedure store_candidates(const candidates: TncCandidateList; const page_index: Integer;
            const page_count: Integer; const selected_index: Integer; const preedit_text: string);
        procedure clear_candidates;
        function has_candidates: Boolean;
        procedure apply_candidate_state(const caret: TPoint; const has_caret: Boolean);
        procedure hide_candidate_window;
        property engine: TncEngine read m_engine;
        property last_caret: TPoint read m_last_caret;
        property has_caret: Boolean read m_has_caret;
    end;

    TncEngineHost = class
    private
        m_sessions: TObjectDictionary<string, TncHostSession>;
        m_active_sessions: TDictionary<string, Byte>;
        m_recent_active_sessions: TDictionary<string, DWORD>;
        m_shift_toggle_ticks: TDictionary<string, DWORD>;
        m_lock: TCriticalSection;
        m_ai_refresh_thread: TThread;
        m_config_path: string;
        m_last_config_write: TDateTime;
        m_config: TncEngineConfig;
        function get_config_write_time: TDateTime;
        procedure persist_engine_config(const config: TncEngineConfig);
        procedure reload_config_if_needed;
        function get_or_create_session(const session_id: string): TncHostSession;
        procedure apply_global_engine_config_locked(const config: TncEngineConfig);
        procedure touch_session_activity(const session_id: string);
        procedure set_session_active(const session_id: string; const active: Boolean);
        function has_active_session: Boolean;
        procedure remove_user_candidate(const session_id: string; const candidate_index: Integer);
        procedure refresh_ai_candidates;
    public
        constructor create;
        destructor Destroy; override;
        function test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean): Boolean;
        function process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
            out full_width_mode: Boolean; out punctuation_full_width: Boolean): Boolean;
        function get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
            out punctuation_full_width: Boolean): Boolean;
        function set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean): Boolean;
        function get_active(out active: Boolean): Boolean;
        function set_active(const session_id: string; const active: Boolean): Boolean;
        procedure update_caret(const session_id: string; const point: TPoint; const has_caret: Boolean);
        procedure update_surrounding(const session_id: string; const left_context: string);
        procedure reset_session(const session_id: string);
    end;

    TncPipeServerThread = class(TThread)
    private
        m_host: TncEngineHost;
        m_pipe_name: string;
        function handle_request(const request_text: string): string;
    protected
        procedure Execute; override;
    public
        constructor create(const host: TncEngineHost; const pipe_name: string);
        property pipe_name: string read m_pipe_name;
    end;

    TncAiRefreshThread = class(TThread)
    private
        m_host: TncEngineHost;
    protected
        procedure Execute; override;
    public
        constructor create(const host: TncEngineHost);
    end;

implementation

const
    c_pipe_in_buffer = 65536;
    c_pipe_out_buffer = 65536;
    c_default_offset = 20;
    c_text_ext_offset = 2;
    c_ai_refresh_poll_ms = 120;
    c_recent_active_ttl_ms = 320;
    c_shift_toggle_dedupe_ms = 90;
    c_tray_host_mutex_name_format = 'Local\cassotis_ime_tray_host_v1_s%d';
    c_tray_host_restart_min_interval_ms = 800;
    c_ipc_security_sddl = 'D:(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;OW)(A;;GRGW;;;AU)S:(ML;;NW;;;LW)';

var
    g_host_log_path: string = '';
    g_host_log_enabled: Boolean = False;
    g_host_log_inited: Boolean = False;
    g_last_tray_host_start_tick: DWORD = 0;

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

function get_host_log_path: string;
var
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
    config_path: string;
    config_manager: TncConfigManager;
    log_config: TncLogConfig;
begin
    if g_host_log_inited then
    begin
        Result := g_host_log_path;
        Exit;
    end;

    g_host_log_inited := True;
    g_host_log_path := '';
    g_host_log_enabled := False;

    config_path := get_default_config_path;
    if config_path <> '' then
    begin
        config_manager := TncConfigManager.create(config_path);
        try
            log_config := config_manager.load_log_config;
            g_host_log_enabled := log_config.enabled;
            if g_host_log_enabled then
            begin
                g_host_log_path := Trim(log_config.log_path);
            end;
        finally
            config_manager.Free;
        end;
    end;

    if not g_host_log_enabled then
    begin
        Result := '';
        Exit;
    end;

    if g_host_log_path = '' then
    begin
        path_len := GetModuleFileName(HInstance, path_buffer, Length(path_buffer));
        if path_len = 0 then
        begin
            g_host_log_path := 'logs\\engine_host.log';
        end
        else
        begin
            g_host_log_path := IncludeTrailingPathDelimiter(ExtractFileDir(path_buffer)) + 'logs\\engine_host.log';
        end;
    end;

    Result := g_host_log_path;
end;

function sanitize_log_text(const value: string): string;
var
    text_value: string;
begin
    text_value := value;
    text_value := StringReplace(text_value, #13, '\r', [rfReplaceAll]);
    text_value := StringReplace(text_value, #10, '\n', [rfReplaceAll]);
    text_value := StringReplace(text_value, #9, '\t', [rfReplaceAll]);
    Result := text_value;
end;

function is_shift_key(const key_code: Word): Boolean;
begin
    // Keep literal VK values as fallback for hosts that report generic/side-specific Shift differently.
    Result := (key_code = VK_SHIFT) or (key_code = VK_LSHIFT) or (key_code = VK_RSHIFT) or
        (key_code = $10) or (key_code = $A0) or (key_code = $A1);
end;

procedure host_log(const text: string);
var
    line: string;
    log_path: string;
begin
    log_path := get_host_log_path;
    line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + text + sLineBreak;
    if log_path = '' then
    begin
        Exit;
    end;

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
    now_tick: DWORD;
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
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

    now_tick := GetTickCount;
    if (g_last_tray_host_start_tick <> 0) and
        (DWORD(now_tick - g_last_tray_host_start_tick) < c_tray_host_restart_min_interval_ms) then
    begin
        Exit;
    end;
    g_last_tray_host_start_tick := now_tick;

    path_len := GetModuleFileName(HInstance, path_buffer, Length(path_buffer));
    if path_len = 0 then
    begin
        Exit;
    end;

    module_dir := ExtractFileDir(path_buffer);
    tray_host_path := IncludeTrailingPathDelimiter(module_dir) + 'cassotis_ime_tray_host.exe';
    if not FileExists(tray_host_path) then
    begin
        host_log('tray host not found, skip auto-restart');
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
        host_log('tray host auto-restart requested');
    end
    else
    begin
        host_log(Format('tray host auto-restart failed err=%d', [GetLastError]));
    end;
end;

constructor TncHostSession.create(const owner: TncEngineHost; const session_id: string; const config: TncEngineConfig);
begin
    inherited create;
    m_owner := owner;
    m_session_id := session_id;
    m_engine := TncEngine.create(config);
    m_candidate_window := nil;
    m_last_caret := Point(0, 0);
    m_has_caret := False;
    SetLength(m_candidates, 0);
    m_page_index := 0;
    m_page_count := 0;
    m_selected_index := 0;
    m_preedit_text := '';
    m_candidate_dirty := True;
end;

destructor TncHostSession.Destroy;
begin
    if m_candidate_window <> nil then
    begin
        m_candidate_window.Free;
        m_candidate_window := nil;
    end;
    if m_engine <> nil then
    begin
        m_engine.Free;
        m_engine := nil;
    end;
    inherited Destroy;
end;

procedure TncHostSession.ensure_candidate_window;
begin
    if m_candidate_window = nil then
    begin
        m_candidate_window := TncCandidateWindow.create;
        m_candidate_window.on_remove_user_candidate := handle_remove_user_candidate;
    end;
end;

procedure TncHostSession.handle_remove_user_candidate(const candidate_index: Integer);
begin
    if m_owner <> nil then
    begin
        m_owner.remove_user_candidate(m_session_id, candidate_index);
    end;
end;

procedure TncHostSession.update_config(const config: TncEngineConfig);
begin
    if m_engine <> nil then
    begin
        m_engine.update_config(config);
    end;
end;

procedure TncHostSession.set_caret(const point: TPoint; const has_caret: Boolean);
begin
    m_last_caret := point;
    m_has_caret := has_caret;
end;

function TncHostSession.needs_candidate_refresh(const point: TPoint; const has_caret: Boolean): Boolean;
begin
    Result := m_candidate_dirty;
    if Result then
    begin
        Exit;
    end;

    if m_last_caret.X <> point.X then
    begin
        Result := True;
        Exit;
    end;

    if m_last_caret.Y <> point.Y then
    begin
        Result := True;
        Exit;
    end;

    Result := m_has_caret <> has_caret;
end;

procedure TncHostSession.store_candidates(const candidates: TncCandidateList; const page_index: Integer;
    const page_count: Integer; const selected_index: Integer; const preedit_text: string);
begin
    m_candidates := candidates;
    m_page_index := page_index;
    m_page_count := page_count;
    m_selected_index := selected_index;
    m_preedit_text := preedit_text;
    m_candidate_dirty := True;
end;

procedure TncHostSession.clear_candidates;
begin
    SetLength(m_candidates, 0);
    m_page_index := 0;
    m_page_count := 0;
    m_selected_index := 0;
    m_preedit_text := '';
    m_candidate_dirty := True;
end;

function TncHostSession.has_candidates: Boolean;
begin
    Result := Length(m_candidates) > 0;
end;

procedure TncHostSession.hide_candidate_window;
begin
    if m_candidate_window <> nil then
    begin
        m_candidate_window.hide_window;
    end;
end;

procedure TncHostSession.apply_candidate_state(const caret: TPoint; const has_caret: Boolean);
var
    y_offset: Integer;
    target_point: TPoint;
    window_rect: TRect;
    monitor_info: TMonitorInfo;
    monitor_handle: HMONITOR;
begin
    if Length(m_candidates) = 0 then
    begin
        hide_candidate_window;
        m_candidate_dirty := False;
        Exit;
    end;

    ensure_candidate_window;
    m_candidate_window.update_candidates(m_candidates, m_page_index, m_page_count, m_selected_index, m_preedit_text);

    if has_caret then
    begin
        y_offset := c_text_ext_offset;
    end
    else
    begin
        y_offset := c_default_offset;
    end;

    target_point := caret;
    if (target_point.X = 0) and (target_point.Y = 0) then
    begin
        m_candidate_window.show_at(200, 200);
    end
    else
    begin
        m_candidate_window.show_at(target_point.X, target_point.Y + y_offset);
    end;

    if m_candidate_window.HandleAllocated then
    begin
        if GetWindowRect(m_candidate_window.Handle, window_rect) then
        begin
            monitor_info.cbSize := SizeOf(monitor_info);
            monitor_handle := MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
            if (monitor_handle <> 0) and GetMonitorInfo(monitor_handle, @monitor_info) then
            begin
                host_log(Format('candidate anchor=(%d,%d) rect=(%d,%d,%d,%d) work=(%d,%d,%d,%d)',
                    [target_point.X, target_point.Y, window_rect.Left, window_rect.Top, window_rect.Right,
                    window_rect.Bottom, monitor_info.rcWork.Left, monitor_info.rcWork.Top,
                    monitor_info.rcWork.Right, monitor_info.rcWork.Bottom]));
            end
            else
            begin
                host_log(Format('candidate anchor=(%d,%d) rect=(%d,%d,%d,%d)',
                    [target_point.X, target_point.Y, window_rect.Left, window_rect.Top, window_rect.Right,
                    window_rect.Bottom]));
            end;
        end;
    end;
    m_candidate_dirty := False;
end;

procedure run_on_ui_thread(const action: TThreadProcedure);
begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
    begin
        action;
    end
    else
    begin
        TThread.Synchronize(nil, action);
    end;
end;

constructor TncEngineHost.create;
begin
    inherited create;
    m_sessions := TObjectDictionary<string, TncHostSession>.Create([doOwnsValues]);
    m_active_sessions := TDictionary<string, Byte>.Create;
    m_recent_active_sessions := TDictionary<string, DWORD>.Create;
    m_shift_toggle_ticks := TDictionary<string, DWORD>.Create;
    m_lock := TCriticalSection.Create;
    m_ai_refresh_thread := nil;
    m_config_path := get_default_config_path;
    m_last_config_write := 0;
    with TncConfigManager.create(m_config_path) do
    try
        m_config := load_engine_config;
    finally
        Free;
    end;
    // Always start a fresh TSF runtime in Chinese mode.
    m_config.input_mode := im_chinese;
    m_last_config_write := get_config_write_time;
    m_ai_refresh_thread := TncAiRefreshThread.create(Self);
end;

destructor TncEngineHost.Destroy;
begin
    if m_ai_refresh_thread <> nil then
    begin
        m_ai_refresh_thread.Terminate;
        WaitForSingleObject(m_ai_refresh_thread.Handle, 1500);
        m_ai_refresh_thread.Free;
        m_ai_refresh_thread := nil;
    end;
    if m_lock <> nil then
    begin
        m_lock.Free;
        m_lock := nil;
    end;
    if m_sessions <> nil then
    begin
        m_sessions.Free;
        m_sessions := nil;
    end;
    if m_active_sessions <> nil then
    begin
        m_active_sessions.Free;
        m_active_sessions := nil;
    end;
    if m_recent_active_sessions <> nil then
    begin
        m_recent_active_sessions.Free;
        m_recent_active_sessions := nil;
    end;
    if m_shift_toggle_ticks <> nil then
    begin
        m_shift_toggle_ticks.Free;
        m_shift_toggle_ticks := nil;
    end;
    inherited Destroy;
end;

procedure TncEngineHost.refresh_ai_candidates;
var
    session: TncHostSession;
    refresh_sessions: TList<TncHostSession>;
    candidates: TncCandidateList;
    page_index: Integer;
    page_count: Integer;
    selected_index: Integer;
    preedit_text: string;
    caret_point: TPoint;
    has_caret: Boolean;
begin
    refresh_sessions := TList<TncHostSession>.Create;
    try
        m_lock.Acquire;
        try
            for session in m_sessions.Values do
            begin
                if not session.engine.refresh_ai_candidates_if_ready(candidates, page_index, page_count, selected_index,
                    preedit_text) then
                begin
                    Continue;
                end;

                session.store_candidates(candidates, page_index, page_count, selected_index, preedit_text);
                refresh_sessions.Add(session);
            end;
        finally
            m_lock.Release;
        end;

        for session in refresh_sessions do
        begin
            caret_point := session.last_caret;
            has_caret := session.has_caret;
            run_on_ui_thread(
                procedure
                begin
                    session.apply_candidate_state(caret_point, has_caret);
                end);
        end;
        if refresh_sessions.Count > 0 then
        begin
            host_log(Format('[DEBUG] AI refresh applied sessions=%d', [refresh_sessions.Count]));
        end;
    finally
        refresh_sessions.Free;
    end;
end;

function TncEngineHost.get_config_write_time: TDateTime;
begin
    Result := 0;
    if (m_config_path <> '') and FileExists(m_config_path) then
    begin
        Result := TFile.GetLastWriteTime(m_config_path);
    end;
end;

procedure TncEngineHost.persist_engine_config(const config: TncEngineConfig);
var
    manager: TncConfigManager;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    manager := TncConfigManager.create(m_config_path);
    try
        manager.save_engine_config(config);
    finally
        manager.Free;
    end;
    m_last_config_write := get_config_write_time;
end;

procedure TncEngineHost.reload_config_if_needed;
var
    current_write: TDateTime;
    manager: TncConfigManager;
    session: TncHostSession;
begin
    current_write := get_config_write_time;
    if current_write <= m_last_config_write then
    begin
        Exit;
    end;

    manager := TncConfigManager.create(m_config_path);
    try
        m_config := manager.load_engine_config;
    finally
        manager.Free;
    end;
    m_lock.Acquire;
    try
        for session in m_sessions.Values do
        begin
            session.update_config(m_config);
        end;
    finally
        m_lock.Release;
    end;

    m_last_config_write := current_write;
end;

procedure TncEngineHost.apply_global_engine_config_locked(const config: TncEngineConfig);
var
    session: TncHostSession;
begin
    for session in m_sessions.Values do
    begin
        session.update_config(config);
    end;
end;

function TncEngineHost.get_or_create_session(const session_id: string): TncHostSession;
begin
    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, Result) then
        begin
            Result := TncHostSession.create(Self, session_id, m_config);
            m_sessions.Add(session_id, Result);
            host_log('Dictionary ' + Result.engine.get_dictionary_debug_info);
        end;
    finally
        m_lock.Release;
    end;
end;

procedure TncEngineHost.set_session_active(const session_id: string; const active: Boolean);
begin
    if session_id = '' then
    begin
        Exit;
    end;

    m_lock.Acquire;
    try
        if active then
        begin
            if not m_active_sessions.ContainsKey(session_id) then
            begin
                m_active_sessions.Add(session_id, 1);
            end;
            m_recent_active_sessions.AddOrSetValue(session_id, GetTickCount);
        end
        else
        begin
            m_active_sessions.Remove(session_id);
            m_recent_active_sessions.Remove(session_id);
            m_shift_toggle_ticks.Remove(session_id);
        end;
    finally
        m_lock.Release;
    end;
end;

procedure TncEngineHost.touch_session_activity(const session_id: string);
begin
    if session_id = '' then
    begin
        Exit;
    end;
    if m_active_sessions.ContainsKey(session_id) then
    begin
        m_recent_active_sessions.AddOrSetValue(session_id, GetTickCount);
    end;
end;

function TncEngineHost.has_active_session: Boolean;
var
    keys: TArray<string>;
    key: string;
    tick: DWORD;
    now_tick: DWORD;
begin
    m_lock.Acquire;
    try
        if m_active_sessions.Count > 0 then
        begin
            Result := True;
            Exit;
        end;

        now_tick := GetTickCount;
        keys := m_recent_active_sessions.Keys.ToArray;
        Result := False;
        for key in keys do
        begin
            if not m_recent_active_sessions.TryGetValue(key, tick) then
            begin
                Continue;
            end;
            if DWORD(now_tick - tick) <= c_recent_active_ttl_ms then
            begin
                Result := True;
                Exit;
            end;
            m_recent_active_sessions.Remove(key);
        end;
    finally
        m_lock.Release;
    end;
end;

function TncEngineHost.test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
    out handled: Boolean): Boolean;
var
    session: TncHostSession;
    input_mode: TncInputMode;
    next_input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    now_tick: DWORD;
    last_tick: DWORD;
    has_last_tick: Boolean;
begin
    handled := False;
    if session_id = '' then
    begin
        Result := False;
        Exit;
    end;

    reload_config_if_needed;
    m_lock.Acquire;
    try
        touch_session_activity(session_id);
    finally
        m_lock.Release;
    end;

    if is_shift_key(key_code) and (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        now_tick := GetTickCount;
        m_lock.Acquire;
        try
            has_last_tick := m_shift_toggle_ticks.TryGetValue(session_id, last_tick);
        finally
            m_lock.Release;
        end;

        if has_last_tick and (DWORD(now_tick - last_tick) <= c_shift_toggle_dedupe_ms) then
        begin
            handled := True;
            Result := True;
            Exit;
        end;

        if get_state(session_id, input_mode, full_width_mode, punctuation_full_width) then
        begin
            if input_mode = im_chinese then
            begin
                next_input_mode := im_english;
            end
            else
            begin
                next_input_mode := im_chinese;
            end;

            if set_state(session_id, next_input_mode, full_width_mode, punctuation_full_width) then
            begin
                m_lock.Acquire;
                try
                    m_shift_toggle_ticks.AddOrSetValue(session_id, now_tick);
                finally
                    m_lock.Release;
                end;

                host_log(Format('[DEBUG] Shift toggled input mode -> %d source=host(test_key) session=%s',
                    [Ord(next_input_mode), session_id]));
                handled := True;
                Result := True;
                Exit;
            end;
        end;
    end;

    session := get_or_create_session(session_id);
    m_lock.Acquire;
    try
        handled := session.engine.should_handle_key(key_code, key_state);
    finally
        m_lock.Release;
    end;
    Result := True;
end;

function TncEngineHost.process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
    out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
    out full_width_mode: Boolean; out punctuation_full_width: Boolean): Boolean;
var
    session: TncHostSession;
    candidates: TncCandidateList;
    page_index: Integer;
    page_count: Integer;
    selected_index: Integer;
    preedit_text: string;
    config: TncEngineConfig;
    should_hide_candidates: Boolean;
    has_result: Boolean;
    global_state_changed: Boolean;
    config_to_save: TncEngineConfig;
begin
    handled := False;
    commit_text := '';
    display_text := '';
    input_mode := im_chinese;
    full_width_mode := False;
    punctuation_full_width := False;
    if session_id = '' then
    begin
        Result := False;
        Exit;
    end;

    reload_config_if_needed;
    session := get_or_create_session(session_id);
    should_hide_candidates := False;
    has_result := True;
    m_lock.Acquire;
    try
        touch_session_activity(session_id);
        session.engine.reload_dictionary_if_needed;
        handled := session.engine.process_key(key_code, key_state);

        config := session.engine.config;
        input_mode := config.input_mode;
        full_width_mode := config.full_width_mode;
        punctuation_full_width := config.punctuation_full_width;
        global_state_changed := (m_config.input_mode <> config.input_mode) or
            (m_config.full_width_mode <> config.full_width_mode) or
            (m_config.punctuation_full_width <> config.punctuation_full_width);
        if global_state_changed then
        begin
            m_config.input_mode := config.input_mode;
            m_config.full_width_mode := config.full_width_mode;
            m_config.punctuation_full_width := config.punctuation_full_width;
            apply_global_engine_config_locked(m_config);
            config_to_save := m_config;
        end;

        if not handled then
        begin
            has_result := True;
        end;

        if handled and session.engine.commit_text(commit_text) then
        begin
            host_log(Format('engine key=%d handled=%d commit=[%s] display=[] comp=[] confirmed=%d',
                [key_code, Ord(handled), sanitize_log_text(commit_text), session.engine.get_confirmed_length]));
            display_text := '';
            session.clear_candidates;
            should_hide_candidates := True;
        end;

        if handled and (commit_text = '') then
        begin
            display_text := session.engine.get_display_text;
            candidates := session.engine.get_candidates;
            page_index := session.engine.get_page_index;
            page_count := session.engine.get_page_count;
            selected_index := session.engine.get_selected_index;
            preedit_text := session.engine.get_composition_text;
            host_log(Format('engine key=%d handled=%d commit=[%s] display=[%s] comp=[%s] confirmed=%d candidates=%d page=%d/%d selected=%d',
                [key_code, Ord(handled), sanitize_log_text(commit_text), sanitize_log_text(display_text),
                sanitize_log_text(preedit_text), session.engine.get_confirmed_length, Length(candidates), page_index + 1,
                page_count, selected_index + 1]));

            if Length(candidates) = 0 then
            begin
                session.clear_candidates;
                should_hide_candidates := True;
            end
            else
            begin
                session.store_candidates(candidates, page_index, page_count, selected_index, preedit_text);
            end;
        end;
    finally
        m_lock.Release;
    end;

    if should_hide_candidates then
    begin
        run_on_ui_thread(
            procedure
            begin
                session.hide_candidate_window;
            end);
    end;

    if global_state_changed then
    begin
        persist_engine_config(config_to_save);
    end;

    Result := has_result;
end;

function TncEngineHost.get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
    out punctuation_full_width: Boolean): Boolean;
begin
    input_mode := im_chinese;
    full_width_mode := False;
    punctuation_full_width := False;
    if session_id = '' then
    begin
        Result := False;
        Exit;
    end;

    reload_config_if_needed;
    m_lock.Acquire;
    try
        input_mode := m_config.input_mode;
        full_width_mode := m_config.full_width_mode;
        punctuation_full_width := m_config.punctuation_full_width;
    finally
        m_lock.Release;
    end;
    Result := True;
end;

function TncEngineHost.set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean): Boolean;
var
    session: TncHostSession;
    next_config: TncEngineConfig;
    input_mode_changed: Boolean;
    global_state_changed: Boolean;
    config_to_save: TncEngineConfig;
begin
    Result := False;
    if session_id = '' then
    begin
        Exit;
    end;

    reload_config_if_needed;
    session := get_or_create_session(session_id);
    m_lock.Acquire;
    try
        next_config := session.engine.config;
        input_mode_changed := next_config.input_mode <> input_mode;
        next_config.input_mode := input_mode;
        next_config.full_width_mode := full_width_mode;
        next_config.punctuation_full_width := punctuation_full_width;
        session.engine.update_config(next_config);

        if input_mode_changed then
        begin
            session.engine.reset;
            session.clear_candidates;
        end;

        global_state_changed := (m_config.input_mode <> input_mode) or (m_config.full_width_mode <> full_width_mode) or
            (m_config.punctuation_full_width <> punctuation_full_width);
        if global_state_changed then
        begin
            m_config.input_mode := input_mode;
            m_config.full_width_mode := full_width_mode;
            m_config.punctuation_full_width := punctuation_full_width;
            apply_global_engine_config_locked(m_config);
            config_to_save := m_config;
        end;
    finally
        m_lock.Release;
    end;

    if global_state_changed then
    begin
        persist_engine_config(config_to_save);
    end;

    if input_mode_changed then
    begin
        run_on_ui_thread(
            procedure
            begin
                session.hide_candidate_window;
            end);
    end;

    Result := True;
end;

function TncEngineHost.get_active(out active: Boolean): Boolean;
begin
    active := has_active_session;
    Result := True;
end;

function TncEngineHost.set_active(const session_id: string; const active: Boolean): Boolean;
begin
    if session_id = '' then
    begin
        Result := False;
        Exit;
    end;

    set_session_active(session_id, active);
    Result := True;
end;

procedure TncEngineHost.update_caret(const session_id: string; const point: TPoint; const has_caret: Boolean);
var
    session: TncHostSession;
    should_apply: Boolean;
begin
    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        should_apply := session.has_candidates and session.needs_candidate_refresh(point, has_caret);
        session.set_caret(point, has_caret);
    finally
        m_lock.Release;
    end;

    if should_apply then
    begin
        run_on_ui_thread(
            procedure
            begin
                session.apply_candidate_state(point, has_caret);
            end);
    end;
end;

procedure TncEngineHost.update_surrounding(const session_id: string; const left_context: string);
var
    session: TncHostSession;
begin
    m_lock.Acquire;
    try
        touch_session_activity(session_id);
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        session.engine.set_external_left_context(left_context);
    finally
        m_lock.Release;
    end;
end;

procedure TncEngineHost.remove_user_candidate(const session_id: string; const candidate_index: Integer);
var
    session: TncHostSession;
    candidate_text: string;
    pinyin_key: string;
    candidates: TncCandidateList;
    page_index: Integer;
    page_count: Integer;
    selected_index: Integer;
    preedit_text: string;
    should_refresh: Boolean;
    should_hide: Boolean;
    caret_point: TPoint;
    has_caret: Boolean;
begin
    if session_id = '' then
    begin
        Exit;
    end;

    host_log(Format('[DEBUG] remove user candidate session=%s index=%d', [session_id, candidate_index]));

    should_refresh := False;
    should_hide := False;
    caret_point := Point(0, 0);
    has_caret := False;
    session := nil;

    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;

        if (candidate_index < 0) or (candidate_index >= Length(session.m_candidates)) then
        begin
            host_log(Format('[DEBUG] remove user candidate skipped: index out of range count=%d',
                [Length(session.m_candidates)]));
            Exit;
        end;

        if session.m_candidates[candidate_index].source <> cs_user then
        begin
            host_log('[DEBUG] remove user candidate skipped: source is not cs_user');
            Exit;
        end;

        candidate_text := session.m_candidates[candidate_index].text;
        pinyin_key := session.m_preedit_text;
        if pinyin_key = '' then
        begin
            pinyin_key := session.engine.get_composition_text;
        end;

        if not session.engine.remove_user_candidate(pinyin_key, candidate_text) then
        begin
            host_log('[WARN] remove user candidate failed in engine');
            Exit;
        end;

        host_log(Format('[INFO] removed user candidate text=%s pinyin=%s', [candidate_text, pinyin_key]));

        candidates := session.engine.get_candidates;
        page_index := session.engine.get_page_index;
        page_count := session.engine.get_page_count;
        selected_index := session.engine.get_selected_index;
        preedit_text := session.engine.get_composition_text;
        if Length(candidates) = 0 then
        begin
            session.clear_candidates;
            should_hide := True;
        end
        else
        begin
            session.store_candidates(candidates, page_index, page_count, selected_index, preedit_text);
            should_refresh := True;
        end;

        caret_point := session.last_caret;
        has_caret := session.has_caret;
    finally
        m_lock.Release;
    end;

    if (session = nil) or (not should_refresh and not should_hide) then
    begin
        Exit;
    end;

    run_on_ui_thread(
        procedure
        begin
            if should_hide then
            begin
                session.hide_candidate_window;
            end
            else
            begin
                session.apply_candidate_state(caret_point, has_caret);
            end;
        end);
end;

procedure TncEngineHost.reset_session(const session_id: string);
var
    session: TncHostSession;
begin
    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        session.engine.reset;
        session.set_caret(Point(0, 0), False);
        session.clear_candidates;
    finally
        m_lock.Release;
    end;

    run_on_ui_thread(
        procedure
        begin
            session.hide_candidate_window;
        end);
end;

constructor TncPipeServerThread.create(const host: TncEngineHost; const pipe_name: string);
begin
    inherited create(False);
    FreeOnTerminate := False;
    m_host := host;
    if pipe_name <> '' then
    begin
        m_pipe_name := pipe_name;
    end
    else
    begin
        m_pipe_name := get_nc_pipe_name;
    end;
end;

constructor TncAiRefreshThread.create(const host: TncEngineHost);
begin
    inherited create(False);
    FreeOnTerminate := False;
    m_host := host;
end;

procedure TncAiRefreshThread.Execute;
begin
    while not Terminated do
    begin
        Sleep(c_ai_refresh_poll_ms);
        if Terminated then
        begin
            Break;
        end;

        try
            m_host.refresh_ai_candidates;
        except
            on e: Exception do
            begin
                host_log(Format('[WARN] AI refresh exception %s: %s', [e.ClassName, e.Message]));
            end;
        end;
    end;
end;

function TncPipeServerThread.handle_request(const request_text: string): string;
var
    fields: TArray<string>;
    cmd: string;
    session_id: string;
    key_code: Integer;
    key_state: TncKeyState;
    handled: Boolean;
    commit_text: string;
    display_text: string;
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    mode_value: Integer;
    x: Integer;
    y: Integer;
    has_caret: Boolean;
    active_flag: Boolean;
begin
    Result := 'ERROR'#9'bad_request';
    try
        if request_text = '' then
        begin
            host_log('request empty');
            Exit;
        end;

        fields := request_text.Split([#9], TStringSplitOptions.None);
        if Length(fields) = 0 then
        begin
            Exit;
        end;

        cmd := fields[0];
        if Length(fields) >= 2 then
        begin
            session_id := fields[1];
        end
        else
        begin
            session_id := '';
        end;
        if not SameText(cmd, 'GET_ACTIVE') then
        begin
            host_log(Format('request cmd=%s session=%s', [cmd, session_id]));
        end;

        if SameText(cmd, 'RESET') then
        begin
            m_host.reset_session(session_id);
            Result := 'OK';
            Exit;
        end;

        if SameText(cmd, 'PING') then
        begin
            Result := 'OK';
            Exit;
        end;

        if SameText(cmd, 'SET_CARET') then
        begin
            x := 0;
            y := 0;
            has_caret := False;
            if Length(fields) >= 4 then
            begin
                x := StrToIntDef(fields[2], 0);
                y := StrToIntDef(fields[3], 0);
            end;
            if Length(fields) >= 5 then
            begin
                has_caret := flag_to_bool(fields[4]);
            end;

            m_host.update_caret(session_id, Point(x, y), has_caret);
            Result := 'OK';
            Exit;
        end;

        if SameText(cmd, 'SET_SURROUNDING') then
        begin
            if Length(fields) >= 3 then
            begin
                m_host.update_surrounding(session_id, decode_ipc_text(fields[2]));
            end
            else
            begin
                m_host.update_surrounding(session_id, '');
            end;
            Result := 'OK';
            Exit;
        end;

        if SameText(cmd, 'GET_STATE') then
        begin
            if m_host.get_state(session_id, input_mode, full_width_mode, punctuation_full_width) then
            begin
                Result := 'OK'#9 + IntToStr(Ord(input_mode)) + #9 + bool_to_flag(full_width_mode) + #9 +
                    bool_to_flag(punctuation_full_width);
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
            Exit;
        end;

        if SameText(cmd, 'GET_ACTIVE') then
        begin
            if m_host.get_active(active_flag) then
            begin
                Result := 'OK'#9 + bool_to_flag(active_flag);
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
            Exit;
        end;

        if SameText(cmd, 'SET_ACTIVE') then
        begin
            if Length(fields) < 3 then
            begin
                Result := 'ERROR'#9'bad_args';
                Exit;
            end;

            active_flag := flag_to_bool(fields[2]);
            if active_flag then
            begin
                ensure_tray_host_running;
            end;
            if m_host.set_active(session_id, active_flag) then
            begin
                Result := 'OK';
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
            Exit;
        end;

        if SameText(cmd, 'SET_STATE') then
        begin
            if Length(fields) < 5 then
            begin
                Result := 'ERROR'#9'bad_args';
                Exit;
            end;

            mode_value := StrToIntDef(fields[2], Ord(im_chinese));
            if (mode_value < Ord(Low(TncInputMode))) or (mode_value > Ord(High(TncInputMode))) then
            begin
                mode_value := Ord(im_chinese);
            end;
            input_mode := TncInputMode(mode_value);
            full_width_mode := flag_to_bool(fields[3]);
            punctuation_full_width := flag_to_bool(fields[4]);
            if m_host.set_state(session_id, input_mode, full_width_mode, punctuation_full_width) then
            begin
                Result := 'OK';
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
            Exit;
        end;

        if SameText(cmd, 'TEST_KEY') then
        begin
            if Length(fields) < 7 then
            begin
                Result := 'ERROR'#9'bad_args';
                Exit;
            end;

            ensure_tray_host_running;
            key_code := StrToIntDef(fields[2], 0);
            key_state.shift_down := flag_to_bool(fields[3]);
            key_state.ctrl_down := flag_to_bool(fields[4]);
            key_state.alt_down := flag_to_bool(fields[5]);
            key_state.caps_lock := flag_to_bool(fields[6]);
            host_log(Format('test_key session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
                [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down), Ord(key_state.alt_down),
                Ord(key_state.caps_lock)]));
            if m_host.test_key(session_id, Word(key_code), key_state, handled) then
            begin
                Result := 'OK'#9 + bool_to_flag(handled);
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
            Exit;
        end;

        if SameText(cmd, 'PROCESS_KEY') then
        begin
            if Length(fields) < 7 then
            begin
                Result := 'ERROR'#9'bad_args';
                Exit;
            end;

            ensure_tray_host_running;
            key_code := StrToIntDef(fields[2], 0);
            key_state.shift_down := flag_to_bool(fields[3]);
            key_state.ctrl_down := flag_to_bool(fields[4]);
            key_state.alt_down := flag_to_bool(fields[5]);
            key_state.caps_lock := flag_to_bool(fields[6]);
            host_log(Format('process_key session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
                [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down), Ord(key_state.alt_down),
                Ord(key_state.caps_lock)]));
            if m_host.process_key(session_id, Word(key_code), key_state, handled, commit_text, display_text, input_mode,
                full_width_mode, punctuation_full_width) then
            begin
                Result := 'OK'#9 + bool_to_flag(handled) + #9 + encode_ipc_text(commit_text) + #9 +
                    encode_ipc_text(display_text) + #9 + IntToStr(Ord(input_mode)) + #9 + bool_to_flag(full_width_mode) +
                    #9 + bool_to_flag(punctuation_full_width);
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
            Exit;
        end;
    except
        on e: Exception do
        begin
            host_log(Format('handle_request exception %s: %s', [e.ClassName, e.Message]));
            Result := 'ERROR'#9'exception';
        end;
    end;
end;

procedure TncPipeServerThread.Execute;
var
    pipe_handle: THandle;
    connected: Boolean;
    bytes_read: DWORD;
    bytes_written: DWORD;
    request_bytes: TBytes;
    response_bytes: TBytes;
    request_text: string;
    response_text: string;
    err: DWORD;
    last_error: DWORD;
    pipe_name: string;
    security_attributes: TSecurityAttributes;
    security_descriptor: Pointer;
    security_attributes_ptr: PSecurityAttributes;
begin
    last_error := 0;
    pipe_name := m_pipe_name;
    security_descriptor := nil;
    security_attributes_ptr := nil;
    if build_ipc_security_attributes(security_attributes, security_descriptor) then
    begin
        security_attributes_ptr := @security_attributes;
    end;
    host_log('pipe thread start name=' + pipe_name);
    try
        while not Terminated do
        begin
            pipe_handle := CreateNamedPipe(PChar(pipe_name), PIPE_ACCESS_DUPLEX,
                PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
                PIPE_UNLIMITED_INSTANCES, c_pipe_out_buffer, c_pipe_in_buffer, 0, security_attributes_ptr);
            if pipe_handle = INVALID_HANDLE_VALUE then
            begin
                err := GetLastError;
                if err <> last_error then
                begin
                    last_error := err;
                    host_log(Format('CreateNamedPipe failed err=%d', [err]));
                end;
                Sleep(200);
                Continue;
            end;

            last_error := 0;
            connected := ConnectNamedPipe(pipe_handle, nil);
            if not connected then
            begin
                err := GetLastError;
                if err = ERROR_PIPE_CONNECTED then
                begin
                    connected := True;
                end
                else
                begin
                    host_log(Format('ConnectNamedPipe failed err=%d', [err]));
                end;
            end;

            if connected then
            begin
                SetLength(request_bytes, c_pipe_in_buffer);
                if ReadFile(pipe_handle, request_bytes[0], Length(request_bytes), bytes_read, nil) then
                begin
                    request_text := TEncoding.UTF8.GetString(request_bytes, 0, bytes_read);
                    response_text := handle_request(request_text);
                    response_bytes := TEncoding.UTF8.GetBytes(response_text);
                    WriteFile(pipe_handle, response_bytes[0], Length(response_bytes), bytes_written, nil);
                    FlushFileBuffers(pipe_handle);
                end
                else
                begin
                    err := GetLastError;
                    host_log(Format('ReadFile failed err=%d', [err]));
                end;
            end;

            DisconnectNamedPipe(pipe_handle);
            CloseHandle(pipe_handle);
        end;
    except
        on e: Exception do
        begin
            host_log(Format('pipe thread exception %s: %s', [e.ClassName, e.Message]));
        end;
    end;
    if security_descriptor <> nil then
    begin
        LocalFree(HLOCAL(security_descriptor));
        security_descriptor := nil;
    end;
    host_log('pipe thread end name=' + pipe_name);
end;

end.
