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
    nc_ipc_common,
    nc_caret_anchor_policy;

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
        m_caret_line_height: Integer;
        m_terminal_like_target: Boolean;
        m_candidates: TncCandidateList;
        m_page_index: Integer;
        m_page_count: Integer;
        m_selected_index: Integer;
        m_preedit_text: string;
        m_candidate_dirty: Boolean;
        m_pending_candidate_caret: TPoint;
        m_pending_candidate_has_caret: Boolean;
        m_pending_candidate_line_height: Integer;
        m_pending_candidate_terminal_like_target: Boolean;
        m_pending_candidate_source: TncCaretAnchorSource;
        m_pending_candidate_score: Integer;
        m_candidate_apply_queued: Boolean;
        m_last_candidate_source: TncCaretAnchorSource;
        m_last_candidate_score: Integer;
        m_last_candidate_apply_tick: DWORD;
        m_last_candidate_debug_mode: Boolean;
        procedure ensure_candidate_window;
        procedure handle_remove_user_candidate(const candidate_index: Integer);
    public
        constructor create(const owner: TncEngineHost; const session_id: string; const config: TncEngineConfig);
        destructor Destroy; override;
        procedure update_config(const config: TncEngineConfig);
        procedure warm_candidate_window;
        procedure set_caret(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean);
        function needs_candidate_refresh(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean): Boolean;
        procedure store_candidates(const candidates: TncCandidateList; const page_index: Integer;
            const page_count: Integer; const selected_index: Integer; const preedit_text: string);
        procedure clear_candidates;
        function has_candidates: Boolean;
        procedure apply_candidate_state(const caret: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const source: TncCaretAnchorSource; const anchor_score: Integer);
        procedure stage_candidate_apply(const caret: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const source: TncCaretAnchorSource; const anchor_score: Integer;
            out should_queue: Boolean);
        function consume_pending_candidate_apply(out caret: TPoint; out has_caret: Boolean;
            out line_height: Integer; out terminal_like_target: Boolean; out source: TncCaretAnchorSource;
            out anchor_score: Integer): Boolean;
        procedure hide_candidate_window;
        property engine: TncEngine read m_engine;
        property last_caret: TPoint read m_last_caret;
        property has_caret: Boolean read m_has_caret;
        property caret_line_height: Integer read m_caret_line_height;
    end;

    TncEngineHost = class
    private
        m_sessions: TObjectDictionary<string, TncHostSession>;
        m_active_sessions: TDictionary<string, Byte>;
        m_recent_active_sessions: TDictionary<string, DWORD>;
        m_active_owner_session_id: string;
        m_shift_toggle_ticks: TDictionary<string, DWORD>;
        m_session_prewarm_queue: TQueue<string>;
        m_session_prewarm_pending: TDictionary<string, Byte>;
        m_lock: TCriticalSection;
        m_maintenance_wakeup: TEvent;
        m_active_state_event: TEvent;
        m_inactive_state_event: TEvent;
        m_maintenance_thread: TThread;
        m_config_path: string;
        m_last_config_write: TDateTime;
        m_last_config_check_tick: UInt64;
        m_last_user_activity_tick: UInt64;
        m_last_user_dict_checkpoint_attempt_tick: UInt64;
        m_last_user_dict_checkpoint_activity_tick: UInt64;
        m_config: TncEngineConfig;
        m_last_lookup_perf_info: string;
        function get_config_write_time: TDateTime;
        procedure maybe_checkpoint_user_dictionary;
        procedure persist_engine_config(const config: TncEngineConfig);
        function reload_config(const force: Boolean): Boolean;
        procedure reload_config_if_needed;
        function get_or_create_session(const session_id: string): TncHostSession;
        procedure apply_global_engine_config_locked(const config: TncEngineConfig);
        procedure sync_session_config_locked(const session: TncHostSession);
        procedure touch_session_activity(const session_id: string);
        procedure set_session_active(const session_id: string; const active: Boolean);
        function has_active_session: Boolean;
        procedure queue_session_prewarm(const session_id: string);
        procedure perform_session_prewarm;
        procedure remove_user_candidate(const session_id: string; const candidate_index: Integer);
    public
        constructor create;
        destructor Destroy; override;
        function test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean): Boolean;
        function process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
            out full_width_mode: Boolean; out punctuation_full_width: Boolean): Boolean;
        function get_last_lookup_perf_info: string;
        function get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
            out punctuation_full_width: Boolean): Boolean;
        function get_dictionary_variant(const session_id: string; out dictionary_variant: TncDictionaryVariant): Boolean;
        function set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean): Boolean;
        function set_dictionary_variant(const session_id: string; const dictionary_variant: TncDictionaryVariant): Boolean;
        function get_active(out active: Boolean): Boolean;
        function set_active(const session_id: string; const active: Boolean): Boolean;
        function reload_config_now: Boolean;
        procedure update_caret(const session_id: string; const point: TPoint; const has_caret: Boolean;
            const line_height: Integer; const terminal_like_target: Boolean; const source: TncCaretAnchorSource;
            const anchor_score: Integer);
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

    TncMaintenanceThread = class(TThread)
    private
        m_host: TncEngineHost;
    protected
        procedure Execute; override;
    public
        constructor create(const host: TncEngineHost);
        procedure detach_host;
    end;

implementation

uses
    nc_sqlite,
    nc_log;

const
    c_pipe_in_buffer = 65536;
    c_pipe_out_buffer = 65536;
    c_default_offset = 20;
    // Minimum TSF-caret gap expressed in 96-DPI device-independent pixels.
    // This is scaled per monitor so higher-DPI displays preserve the same
    // logical spacing instead of collapsing the candidate window too close
    // to the composing row.
    c_text_ext_offset = 6;
    c_maintenance_poll_ms = 200;
    c_recent_active_ttl_ms = 320;
    c_candidate_apply_merge_ms = 35;
    c_shift_toggle_dedupe_ms = 90;
    c_user_dict_checkpoint_idle_ms = 5000;
    c_user_dict_checkpoint_retry_ms = 5000;
    c_tray_host_mutex_name_format = 'Local\cassotis_ime_tray_host_v1_s%d';
    c_tray_host_restart_min_interval_ms = 800;
    c_ipc_security_sddl = 'D:(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;OW)(A;;GRGW;;;AU)S:(ML;;NW;;;LW)';

var
    g_host_log_path: string = '';
    g_host_log_enabled: Boolean = False;
    g_host_log_inited: Boolean = False;
    g_host_log_level: TncLogLevel = ll_info;
    g_host_log_max_size_kb: Integer = 0;
    g_last_tray_host_start_tick: DWORD = 0;

function caret_source_priority(const source: TncCaretAnchorSource): Integer;
begin
    case source of
        casTsf:
            Result := 5;
        casGui:
            Result := 4;
        casCaretPos:
            Result := 3;
        casLastSent:
            Result := 2;
        casCursor:
            Result := 1;
    else
        Result := 0;
    end;
end;

function get_monitor_dpi(const anchor: TPoint): Integer;
type
    TGetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer; out dpiX: UINT;
        out dpiY: UINT): HRESULT; stdcall;
const
    MDT_EFFECTIVE_DPI = 0;
var
    monitor: HMONITOR;
    module: HMODULE;
    get_dpi: TGetDpiForMonitor;
    dpi_x: UINT;
    dpi_y: UINT;
begin
    Result := 96;
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor = 0 then
    begin
        Exit;
    end;

    module := GetModuleHandle('Shcore.dll');
    if module = 0 then
    begin
        module := LoadLibrary('Shcore.dll');
    end;
    if module = 0 then
    begin
        Exit;
    end;

    get_dpi := TGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
    if Assigned(get_dpi) and (get_dpi(monitor, MDT_EFFECTIVE_DPI, dpi_x, dpi_y) = S_OK) and (dpi_x > 0) then
    begin
        Result := dpi_x;
    end;
end;

function scale_candidate_offset(const base_offset: Integer; const anchor: TPoint): Integer;
begin
    Result := MulDiv(base_offset, get_monitor_dpi(anchor), 96);
    if Result < base_offset then
    begin
        Result := base_offset;
    end;
end;

function calculate_candidate_offset(const base_offset: Integer; const anchor: TPoint; const line_height: Integer;
    const terminal_like_target: Boolean; const source: TncCaretAnchorSource): Integer;
var
    dpi: Integer;
    scaled_base_offset: Integer;
    line_gap: Integer;
    min_gap: Integer;
    max_gap: Integer;
    line_gap_ratio_permille: Integer;
begin
    dpi := get_monitor_dpi(anchor);
    scaled_base_offset := MulDiv(base_offset, dpi, 96);
    if scaled_base_offset < base_offset then
    begin
        scaled_base_offset := base_offset;
    end;
    Result := scaled_base_offset;

    if (line_height > 0) and (source = casTsf) and (not terminal_like_target) then
    begin
        // For normal GUI editors, the TSF anchor is already the caret bottom
        // in screen pixels. Keep only a small post-caret clearance and avoid
        // scaling it linearly with monitor DPI, while still preserving the
        // monitor-scaled baseline gap so higher-DPI TSF anchors do not
        // collapse tighter than the logical 96-DPI spacing.
        line_gap := MulDiv(line_height, 1, 10);
        min_gap := scaled_base_offset;
        max_gap := MulDiv(10, dpi, 96);
        if max_gap < scaled_base_offset then
        begin
            max_gap := scaled_base_offset;
        end;
        if line_gap < min_gap then
        begin
            line_gap := min_gap;
        end;
        if line_gap > max_gap then
        begin
            line_gap := max_gap;
        end;
        Result := line_gap;
        Exit;
    end;

    if (line_height > 0) and (source = casTsf) and terminal_like_target then
    begin
        // The TSF caret line height is already reported in screen pixels.
        // Use it as a lower-bounded layout hint, but never let it shrink
        // below the monitor-scaled base offset. This preserves the recent
        // mixed-DPI fix while keeping enough clearance for taller inline
        // composition rows such as terminal text on higher-DPI monitors.
        if dpi <= 96 then
        begin
            line_gap_ratio_permille := 400;
        end
        else if dpi >= 144 then
        begin
            line_gap_ratio_permille := 1000;
        end
        else
        begin
            line_gap_ratio_permille := 400 + MulDiv(dpi - 96, 600, 48);
        end;
        line_gap := MulDiv(line_height, line_gap_ratio_permille, 1000);
        min_gap := scaled_base_offset;
        max_gap := MulDiv(24, dpi, 96);
        if max_gap < scaled_base_offset then
        begin
            max_gap := scaled_base_offset;
        end;
        if line_gap < min_gap then
        begin
            line_gap := min_gap;
        end;
        if line_gap > max_gap then
        begin
            line_gap := max_gap;
        end;
        Result := line_gap;
    end;
end;

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

function resolve_host_log_path_value(const configured_path: string): string;
begin
    Result := Trim(configured_path);
    if Result = '' then
    begin
        Result := get_default_log_path;
    end;
end;

procedure apply_host_log_config(const log_config: TncLogConfig);
begin
    g_host_log_inited := True;
    g_host_log_enabled := log_config.enabled;
    g_host_log_level := log_config.level;
    g_host_log_max_size_kb := log_config.max_size_kb;
    if g_host_log_enabled then
    begin
        g_host_log_path := resolve_host_log_path_value(log_config.log_path);
    end
    else
    begin
        g_host_log_path := '';
    end;
end;

procedure reload_host_log_config(const config_path: string);
var
    config_manager: TncConfigManager;
    log_config: TncLogConfig;
begin
    g_host_log_path := '';
    g_host_log_enabled := False;
    g_host_log_level := ll_info;
    g_host_log_max_size_kb := 0;

    if config_path <> '' then
    begin
        config_manager := TncConfigManager.create(config_path);
        try
            log_config := config_manager.load_log_config;
            apply_host_log_config(log_config);
        finally
            config_manager.Free;
        end;
    end;
end;

function get_host_log_path: string;
var
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
    config_path: string;
begin
    if g_host_log_inited then
    begin
        Result := g_host_log_path;
        Exit;
    end;

    g_host_log_inited := True;
    config_path := get_default_config_path;
    reload_host_log_config(config_path);

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
            g_host_log_path := 'logs\engine_host.log';
        end
        else
        begin
            g_host_log_path := IncludeTrailingPathDelimiter(ExtractFileDir(path_buffer)) + 'logs\engine_host.log';
        end;
    end;

    Result := g_host_log_path;
end;

function host_log_enabled_for(const level: TncLogLevel): Boolean;
begin
    Result := g_host_log_enabled and (Ord(level) >= Ord(g_host_log_level)) and (get_host_log_path <> '');
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

function candidates_equal(const left_candidates: TncCandidateList; const right_candidates: TncCandidateList): Boolean;
var
    i: Integer;
begin
    Result := Length(left_candidates) = Length(right_candidates);
    if not Result then
    begin
        Exit;
    end;

    for i := 0 to High(left_candidates) do
    begin
        if (left_candidates[i].text <> right_candidates[i].text) or
            (left_candidates[i].comment <> right_candidates[i].comment) or
            (left_candidates[i].score <> right_candidates[i].score) or
            (left_candidates[i].source <> right_candidates[i].source) or
            (left_candidates[i].has_dict_weight <> right_candidates[i].has_dict_weight) or
            (left_candidates[i].dict_weight <> right_candidates[i].dict_weight) then
        begin
            Result := False;
            Exit;
        end;
    end;
end;

procedure host_log_at(const level: TncLogLevel; const text: string);
var
    line: string;
    log_path: string;
begin
    try
        if not host_log_enabled_for(level) then
        begin
            Exit;
        end;
        log_path := get_host_log_path;
        if log_path = '' then
        begin
            Exit;
        end;
        line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + text + sLineBreak;
        append_log_line_shared(log_path, line, g_host_log_max_size_kb);
    except
        // Logging must never block host-side request processing.
    end;
end;

procedure host_log(const text: string);
begin
    host_log_at(ll_info, text);
end;

procedure host_log_debug(const text: string);
begin
    host_log_at(ll_debug, text);
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
    m_caret_line_height := 0;
    m_terminal_like_target := False;
    SetLength(m_candidates, 0);
    m_page_index := 0;
    m_page_count := 0;
    m_selected_index := 0;
    m_preedit_text := '';
    m_candidate_dirty := True;
    m_pending_candidate_caret := Point(0, 0);
    m_pending_candidate_has_caret := False;
    m_pending_candidate_line_height := 0;
    m_pending_candidate_terminal_like_target := False;
    m_pending_candidate_source := casCursor;
    m_pending_candidate_score := Low(Integer);
    m_candidate_apply_queued := False;
    m_last_candidate_source := casCursor;
    m_last_candidate_score := Low(Integer);
    m_last_candidate_apply_tick := 0;
    m_last_candidate_debug_mode := config.debug_mode;
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

procedure TncHostSession.warm_candidate_window;
begin
    ensure_candidate_window;
    if (m_last_caret.X <> 0) or (m_last_caret.Y <> 0) then
    begin
        m_candidate_window.prepare_for_anchor(m_last_caret);
    end;
end;

procedure TncHostSession.set_caret(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
    const terminal_like_target: Boolean);
begin
    m_last_caret := point;
    m_has_caret := has_caret;
    m_caret_line_height := line_height;
    m_terminal_like_target := terminal_like_target;
end;

function TncHostSession.needs_candidate_refresh(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
    const terminal_like_target: Boolean): Boolean;
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

    if m_has_caret <> has_caret then
    begin
        Result := True;
        Exit;
    end;

    if m_caret_line_height <> line_height then
    begin
        Result := True;
        Exit;
    end;

    Result := m_terminal_like_target <> terminal_like_target;
end;

procedure TncHostSession.store_candidates(const candidates: TncCandidateList; const page_index: Integer;
    const page_count: Integer; const selected_index: Integer; const preedit_text: string);
var
    changed: Boolean;
begin
    changed := (m_page_index <> page_index) or
        (m_page_count <> page_count) or
        (m_selected_index <> selected_index) or
        (m_preedit_text <> preedit_text) or
        (not candidates_equal(m_candidates, candidates));
    m_candidates := candidates;
    m_page_index := page_index;
    m_page_count := page_count;
    m_selected_index := selected_index;
    m_preedit_text := preedit_text;
    if changed then
    begin
        m_candidate_dirty := True;
    end;
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

procedure TncHostSession.apply_candidate_state(const caret: TPoint; const has_caret: Boolean; const line_height: Integer;
    const terminal_like_target: Boolean; const source: TncCaretAnchorSource; const anchor_score: Integer);
var
    y_offset: Integer;
    target_point: TPoint;
    window_rect: TRect;
    monitor_info: TMonitorInfo;
    monitor_handle: HMONITOR;
    debug_logging: Boolean;
begin
    if Length(m_candidates) = 0 then
    begin
        hide_candidate_window;
        m_candidate_dirty := False;
        Exit;
    end;

    ensure_candidate_window;
    if (caret.X <> 0) or (caret.Y <> 0) then
    begin
        m_candidate_window.prepare_for_anchor(caret);
    end;
    if m_candidate_dirty or (m_last_candidate_debug_mode <> m_engine.config.debug_mode) then
    begin
        m_candidate_window.update_candidates(m_candidates, m_page_index, m_page_count, m_selected_index,
            m_preedit_text, m_engine.config.debug_mode);
        m_last_candidate_debug_mode := m_engine.config.debug_mode;
    end;

    if has_caret then
    begin
        y_offset := calculate_candidate_offset(c_text_ext_offset, caret, line_height, terminal_like_target, source);
    end
    else
    begin
        y_offset := calculate_candidate_offset(c_default_offset, caret, line_height, terminal_like_target, source);
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
        debug_logging := m_engine.config.debug_mode and host_log_enabled_for(ll_debug);
        if GetWindowRect(m_candidate_window.Handle, window_rect) then
        begin
            monitor_info.cbSize := SizeOf(monitor_info);
            monitor_handle := MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
            if (monitor_handle <> 0) and GetMonitorInfo(monitor_handle, @monitor_info) then
            begin
                if debug_logging then
                begin
                    host_log_debug(Format('candidate anchor=(%d,%d) rect=(%d,%d,%d,%d) work=(%d,%d,%d,%d)',
                        [target_point.X, target_point.Y, window_rect.Left, window_rect.Top, window_rect.Right,
                        window_rect.Bottom, monitor_info.rcWork.Left, monitor_info.rcWork.Top,
                        monitor_info.rcWork.Right, monitor_info.rcWork.Bottom]));
                end;
                if debug_logging then
                begin
                    host_log_debug(Format('[DEBUG] candidate source=%s score=%d',
                        [anchor_source_name(source), anchor_score]));
                end;
                if debug_logging then
                begin
                    host_log_debug(Format('[DEBUG] candidate metrics line_height=%d y_offset=%d',
                        [line_height, y_offset]));
                end;
            end
            else
            begin
                if debug_logging then
                begin
                    host_log_debug(Format('candidate anchor=(%d,%d) rect=(%d,%d,%d,%d)',
                        [target_point.X, target_point.Y, window_rect.Left, window_rect.Top, window_rect.Right,
                        window_rect.Bottom]));
                end;
                if debug_logging then
                begin
                    host_log_debug(Format('[DEBUG] candidate source=%s score=%d',
                        [anchor_source_name(source), anchor_score]));
                end;
                if debug_logging then
                begin
                    host_log_debug(Format('[DEBUG] candidate metrics line_height=%d y_offset=%d',
                        [line_height, y_offset]));
                end;
            end;
        end;
    end;
    m_last_candidate_source := source;
    m_last_candidate_score := anchor_score;
    m_last_candidate_apply_tick := GetTickCount;
    m_candidate_dirty := False;
end;

procedure TncHostSession.stage_candidate_apply(const caret: TPoint; const has_caret: Boolean;
    const line_height: Integer; const terminal_like_target: Boolean; const source: TncCaretAnchorSource;
    const anchor_score: Integer;
    out should_queue: Boolean);
var
    now_tick: DWORD;
    replace_pending: Boolean;
begin
    should_queue := False;

    if m_candidate_apply_queued then
    begin
        replace_pending := (anchor_score > m_pending_candidate_score) or
            ((anchor_score = m_pending_candidate_score) and
            (caret_source_priority(source) >= caret_source_priority(m_pending_candidate_source)));
        if replace_pending then
        begin
            m_pending_candidate_caret := caret;
            m_pending_candidate_has_caret := has_caret;
            m_pending_candidate_line_height := line_height;
            m_pending_candidate_terminal_like_target := terminal_like_target;
            m_pending_candidate_source := source;
            m_pending_candidate_score := anchor_score;
        end;
        Exit;
    end;

    if m_candidate_dirty then
    begin
        m_pending_candidate_caret := caret;
        m_pending_candidate_has_caret := has_caret;
        m_pending_candidate_line_height := line_height;
        m_pending_candidate_terminal_like_target := terminal_like_target;
        m_pending_candidate_source := source;
        m_pending_candidate_score := anchor_score;
        should_queue := True;
        if should_queue then
        begin
            m_candidate_apply_queued := True;
        end;
        Exit;
    end;

    now_tick := GetTickCount;
    if (m_last_candidate_apply_tick <> 0) and
        (DWORD(now_tick - m_last_candidate_apply_tick) <= c_candidate_apply_merge_ms) and
        ((anchor_score < m_last_candidate_score) or
        ((anchor_score = m_last_candidate_score) and
        (caret_source_priority(source) < caret_source_priority(m_last_candidate_source)))) then
    begin
        Exit;
    end;

    m_pending_candidate_caret := caret;
    m_pending_candidate_has_caret := has_caret;
    m_pending_candidate_line_height := line_height;
    m_pending_candidate_terminal_like_target := terminal_like_target;
    m_pending_candidate_source := source;
    m_pending_candidate_score := anchor_score;
    should_queue := True;
    if should_queue then
    begin
        m_candidate_apply_queued := True;
    end;
end;

function TncHostSession.consume_pending_candidate_apply(out caret: TPoint; out has_caret: Boolean;
    out line_height: Integer; out terminal_like_target: Boolean; out source: TncCaretAnchorSource;
    out anchor_score: Integer): Boolean;
begin
    if not m_candidate_apply_queued then
    begin
        caret := Point(0, 0);
        has_caret := False;
        line_height := 0;
        terminal_like_target := False;
        source := casCursor;
        anchor_score := 0;
        Result := False;
        Exit;
    end;

    caret := m_pending_candidate_caret;
    has_caret := m_pending_candidate_has_caret;
    line_height := m_pending_candidate_line_height;
    terminal_like_target := m_pending_candidate_terminal_like_target;
    source := m_pending_candidate_source;
    anchor_score := m_pending_candidate_score;
    m_candidate_apply_queued := False;
    Result := True;
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

function wait_for_thread_exit(const thread: TThread; const timeout_ms: DWORD): Boolean;
var
    start_tick: UInt64;
begin
    if thread = nil then
    begin
        Result := True;
        Exit;
    end;

    start_tick := GetTickCount64;
    repeat
        if WaitForSingleObject(thread.Handle, 50) = WAIT_OBJECT_0 then
        begin
            Result := True;
            Exit;
        end;

        if TThread.CurrentThread.ThreadID = MainThreadID then
        begin
            CheckSynchronize(0);
        end;
    until (GetTickCount64 - start_tick) >= timeout_ms;

    Result := WaitForSingleObject(thread.Handle, 0) = WAIT_OBJECT_0;
    if (not Result) and (TThread.CurrentThread.ThreadID = MainThreadID) then
    begin
        CheckSynchronize(0);
    end;
end;

constructor TncEngineHost.create;
begin
    inherited create;
    m_sessions := TObjectDictionary<string, TncHostSession>.Create([doOwnsValues]);
    m_active_sessions := TDictionary<string, Byte>.Create;
    m_recent_active_sessions := TDictionary<string, DWORD>.Create;
    m_shift_toggle_ticks := TDictionary<string, DWORD>.Create;
    m_active_owner_session_id := '';
    m_session_prewarm_queue := TQueue<string>.Create;
    m_session_prewarm_pending := TDictionary<string, Byte>.Create;
    m_lock := TCriticalSection.Create;
    m_maintenance_wakeup := TEvent.Create(nil, False, False, '');
    m_active_state_event := TEvent.Create(nil, False, False, get_nc_active_event);
    m_inactive_state_event := TEvent.Create(nil, False, False, get_nc_inactive_event);
    m_maintenance_thread := nil;
    m_config_path := get_default_config_path;
    m_last_config_write := 0;
    m_last_config_check_tick := 0;
    m_last_user_activity_tick := 0;
    m_last_user_dict_checkpoint_attempt_tick := 0;
    m_last_user_dict_checkpoint_activity_tick := 0;
    with TncConfigManager.create(m_config_path) do
    try
        m_config := load_engine_config;
    finally
        Free;
    end;
    // Always start a fresh TSF runtime in Chinese mode.
    m_config.input_mode := im_chinese;
    m_last_config_write := get_config_write_time;
    m_last_config_check_tick := GetTickCount64;
    m_maintenance_thread := TncMaintenanceThread.create(Self);
end;

destructor TncEngineHost.Destroy;
begin
    if m_maintenance_thread <> nil then
    begin
        TncMaintenanceThread(m_maintenance_thread).detach_host;
        m_maintenance_thread.Terminate;
        if m_maintenance_wakeup <> nil then
        begin
            m_maintenance_wakeup.SetEvent;
        end;
        if wait_for_thread_exit(m_maintenance_thread, 3000) then
        begin
            m_maintenance_thread.Free;
            m_maintenance_thread := nil;
        end
        else
        begin
            host_log('[WARN] maintenance thread did not exit during destroy; leaving FreeOnTerminate enabled.');
            m_maintenance_thread.FreeOnTerminate := True;
            m_maintenance_thread := nil;
        end;
    end;
    if m_lock <> nil then
    begin
        m_lock.Free;
        m_lock := nil;
    end;
    if m_maintenance_wakeup <> nil then
    begin
        m_maintenance_wakeup.Free;
        m_maintenance_wakeup := nil;
    end;
    if m_active_state_event <> nil then
    begin
        m_active_state_event.Free;
        m_active_state_event := nil;
    end;
    if m_inactive_state_event <> nil then
    begin
        m_inactive_state_event.Free;
        m_inactive_state_event := nil;
    end;
    if m_sessions <> nil then
    begin
        m_sessions.Free;
        m_sessions := nil;
    end;
    if m_session_prewarm_queue <> nil then
    begin
        m_session_prewarm_queue.Free;
        m_session_prewarm_queue := nil;
    end;
    if m_session_prewarm_pending <> nil then
    begin
        m_session_prewarm_pending.Free;
        m_session_prewarm_pending := nil;
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
    m_last_config_check_tick := GetTickCount64;
end;

function TncEngineHost.reload_config(const force: Boolean): Boolean;
var
    now_tick: UInt64;
    current_write: TDateTime;
    manager: TncConfigManager;
    next_config: TncEngineConfig;
    next_log_config: TncLogConfig;
    session: TncHostSession;
begin
    Result := False;
    if m_config_path = '' then
    begin
        Exit;
    end;

    now_tick := GetTickCount64;
    if (not force) and (m_last_config_check_tick <> 0) and (now_tick - m_last_config_check_tick < 1500) then
    begin
        Exit;
    end;
    m_last_config_check_tick := now_tick;

    current_write := get_config_write_time;
    if (not force) and (current_write <= m_last_config_write) then
    begin
        Exit;
    end;

    manager := TncConfigManager.create(m_config_path);
    try
        next_config := manager.load_engine_config;
        next_log_config := manager.load_log_config;
    finally
        manager.Free;
    end;
    m_lock.Acquire;
    try
        m_config := next_config;
        for session in m_sessions.Values do
        begin
            session.update_config(m_config);
        end;
    finally
        m_lock.Release;
    end;

    apply_host_log_config(next_log_config);
    m_last_config_write := current_write;
    Result := True;
end;

procedure TncEngineHost.reload_config_if_needed;
begin
    reload_config(False);
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

procedure TncEngineHost.sync_session_config_locked(const session: TncHostSession);
begin
    if session = nil then
    begin
        Exit;
    end;
    session.update_config(m_config);
end;

function TncEngineHost.get_or_create_session(const session_id: string): TncHostSession;
var
    config_snapshot: TncEngineConfig;
    created_session: TncHostSession;
    added_session: Boolean;
begin
    m_lock.Acquire;
    try
        if m_sessions.TryGetValue(session_id, Result) then
        begin
            Exit;
        end;
        config_snapshot := m_config;
    finally
        m_lock.Release;
    end;

    created_session := TncHostSession.create(Self, session_id, config_snapshot);
    added_session := False;
    try
        m_lock.Acquire;
        try
            if not m_sessions.TryGetValue(session_id, Result) then
            begin
                created_session.update_config(m_config);
                m_sessions.Add(session_id, created_session);
                Result := created_session;
                created_session := nil;
                added_session := True;
            end;
        finally
            m_lock.Release;
        end;

        if added_session then
        begin
            host_log('Dictionary ' + Result.engine.get_dictionary_debug_info);
        end;
    finally
        created_session.Free;
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
            // The IME is globally single-active: stale active sessions should
            // never keep the status widget alive after focus/input-method
            // switches. Keep only the latest active session.
            m_active_owner_session_id := session_id;
            m_active_sessions.Clear;
            m_recent_active_sessions.Clear;
            m_active_sessions.AddOrSetValue(session_id, 1);
            m_recent_active_sessions.AddOrSetValue(session_id, GetTickCount);
        end
        else
        begin
            if SameText(m_active_owner_session_id, session_id) then
            begin
                m_active_owner_session_id := '';
                m_active_sessions.Clear;
                m_recent_active_sessions.Clear;
                m_shift_toggle_ticks.Clear;
            end
            else
            begin
                m_active_sessions.Remove(session_id);
                m_recent_active_sessions.Remove(session_id);
                m_shift_toggle_ticks.Remove(session_id);
            end;
        end;
    finally
        m_lock.Release;
    end;

    if m_maintenance_wakeup <> nil then
    begin
        m_maintenance_wakeup.SetEvent;
    end;
    if m_active_state_event <> nil then
    begin
        m_active_state_event.SetEvent;
    end;
    if (not active) and (m_inactive_state_event <> nil) then
    begin
        m_inactive_state_event.SetEvent;
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
    m_last_user_activity_tick := GetTickCount64;
end;

procedure TncEngineHost.queue_session_prewarm(const session_id: string);
begin
    if session_id = '' then
    begin
        Exit;
    end;

    m_lock.Acquire;
    try
        if m_session_prewarm_pending.ContainsKey(session_id) then
        begin
            Exit;
        end;
        m_session_prewarm_queue.Enqueue(session_id);
        m_session_prewarm_pending.Add(session_id, 1);
    finally
        m_lock.Release;
    end;

    if m_maintenance_wakeup <> nil then
    begin
        m_maintenance_wakeup.SetEvent;
    end;
end;

procedure TncEngineHost.perform_session_prewarm;
var
    session_id: string;
    session: TncHostSession;
    create_start_tick: UInt64;
    create_elapsed_ms: Int64;
    total_elapsed_ms: Int64;
    should_requeue: Boolean;
begin
    session_id := '';
    session := nil;
    should_requeue := False;

    m_lock.Acquire;
    try
        if (m_session_prewarm_queue = nil) or (m_session_prewarm_queue.Count <= 0) then
        begin
            Exit;
        end;
        session_id := m_session_prewarm_queue.Dequeue;
    finally
        m_lock.Release;
    end;

    try
        create_start_tick := GetTickCount64;
        session := get_or_create_session(session_id);
        create_elapsed_ms := Int64(GetTickCount64 - create_start_tick);

        if not m_lock.TryEnter then
        begin
            // Prewarm is best-effort. If foreground input currently owns the
            // host lock, retry on a later maintenance pass instead of blocking
            // the next key.
            should_requeue := True;
            Exit;
        end;
        try
            if m_sessions.TryGetValue(session_id, session) then
            begin
                session.engine.reload_dictionary_if_needed;
                session.engine.prewarm_dictionary_caches;
            end
            else
            begin
                session := nil;
            end;
        finally
            m_lock.Release;
        end;

        total_elapsed_ms := Int64(GetTickCount64 - create_start_tick);
        if session <> nil then
        begin
            TThread.Queue(nil,
                procedure
                begin
                    session.warm_candidate_window;
                end);
        end;

        if host_log_enabled_for(ll_debug) then
        begin
            host_log_debug(Format('[DEBUG] session prewarm session=%s create=%d total=%d',
                [session_id, create_elapsed_ms, total_elapsed_ms]));
        end;
    finally
        m_lock.Acquire;
        try
            if should_requeue and (session_id <> '') and (m_session_prewarm_queue <> nil) then
            begin
                m_session_prewarm_queue.Enqueue(session_id);
            end
            else
            begin
                m_session_prewarm_pending.Remove(session_id);
            end;
        finally
            m_lock.Release;
        end;
    end;
end;

procedure TncEngineHost.maybe_checkpoint_user_dictionary;
const
    c_user_dict_checkpoint_mutex_name = 'Local\CassotisImeUserDictCheckpoint';
var
    user_db_path: string;
    debug_mode: Boolean;
    last_activity_tick: UInt64;
    last_checkpoint_activity_tick: UInt64;
    last_attempt_tick: UInt64;
    now_tick: UInt64;
    busy_frames: Integer;
    log_frames: Integer;
    checkpointed_frames: Integer;
    error_message: string;
    checkpoint_ok: Boolean;
    checkpoint_mutex: THandle;
    wait_result: DWORD;
    checkpoint_mutex_acquired: Boolean;
begin
    m_lock.Acquire;
    try
        user_db_path := get_default_user_dictionary_path;
        debug_mode := m_config.debug_mode;
        last_activity_tick := m_last_user_activity_tick;
        last_checkpoint_activity_tick := m_last_user_dict_checkpoint_activity_tick;
        last_attempt_tick := m_last_user_dict_checkpoint_attempt_tick;
    finally
        m_lock.Release;
    end;

    if (user_db_path = '') or (not TFile.Exists(user_db_path)) or (last_activity_tick = 0) then
    begin
        Exit;
    end;

    now_tick := GetTickCount64;
    if (now_tick - last_activity_tick) < c_user_dict_checkpoint_idle_ms then
    begin
        Exit;
    end;
    if last_activity_tick <= last_checkpoint_activity_tick then
    begin
        Exit;
    end;
    if (last_attempt_tick <> 0) and ((now_tick - last_attempt_tick) < c_user_dict_checkpoint_retry_ms) then
    begin
        Exit;
    end;
    if has_active_session then
    begin
        Exit;
    end;

    checkpoint_mutex := CreateMutex(nil, False, c_user_dict_checkpoint_mutex_name);
    if checkpoint_mutex = 0 then
    begin
        Exit;
    end;
    checkpoint_mutex_acquired := False;
    try
        wait_result := WaitForSingleObject(checkpoint_mutex, 0);
        if (wait_result <> WAIT_OBJECT_0) and (wait_result <> WAIT_ABANDONED) then
        begin
            Exit;
        end;
        checkpoint_mutex_acquired := True;

    m_lock.Acquire;
    try
        m_last_user_dict_checkpoint_attempt_tick := now_tick;
    finally
        m_lock.Release;
    end;

    with TncSqliteConnection.create(user_db_path) do
    try
        if open(SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE) then
        begin
            exec('PRAGMA busy_timeout=250;');
            checkpoint_ok := checkpoint_wal_truncate(busy_frames, log_frames, checkpointed_frames, error_message);
        end
        else
        begin
            checkpoint_ok := False;
            busy_frames := -1;
            log_frames := -1;
            checkpointed_frames := -1;
            error_message := errmsg;
        end;
    finally
        Free;
    end;

    if checkpoint_ok then
    begin
        m_lock.Acquire;
        try
            if m_last_user_dict_checkpoint_activity_tick < last_activity_tick then
            begin
                m_last_user_dict_checkpoint_activity_tick := last_activity_tick;
            end;
        finally
            m_lock.Release;
        end;

        if debug_mode then
        begin
            host_log(Format('[DEBUG] user_dict wal_checkpoint busy=%d log=%d checkpointed=%d idle=%d',
                [busy_frames, log_frames, checkpointed_frames, now_tick - last_activity_tick]));
        end;
        Exit;
    end;

    if debug_mode then
    begin
        host_log(Format('[DEBUG] user_dict wal_checkpoint skipped busy=%d log=%d checkpointed=%d err=%s',
            [busy_frames, log_frames, checkpointed_frames, sanitize_log_text(error_message)]));
    end;
    finally
        if checkpoint_mutex_acquired then
        begin
            ReleaseMutex(checkpoint_mutex);
        end;
        CloseHandle(checkpoint_mutex);
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

    m_last_lookup_perf_info := '';
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

                host_log_debug(Format('[DEBUG] Shift toggled input mode -> %d source=host(test_key) session=%s',
                    [Ord(next_input_mode), session_id]));
                handled := True;
                Result := True;
                Exit;
            end;
        end;
    end;

    if key_state.ctrl_down or key_state.alt_down then
    begin
        if key_state.ctrl_down and (key_code = VK_SPACE) and m_config.enable_ctrl_space_toggle then
        begin
            // fall through
        end
        else if key_state.ctrl_down and (key_code = VK_OEM_PERIOD) and m_config.enable_ctrl_period_punct_toggle then
        begin
            // fall through
        end
        else
        begin
            Result := True;
            Exit;
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
const
    c_slow_host_process_key_ms = 12;
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
    lookup_debug_info: string;
    lookup_perf_info: string;
    total_start_tick: UInt64;
    reload_start_tick: UInt64;
    process_start_tick: UInt64;
    readback_start_tick: UInt64;
    reload_elapsed_ms: Int64;
    process_elapsed_ms: Int64;
    readback_elapsed_ms: Int64;
    total_elapsed_ms: Int64;
    debug_logging: Boolean;
    had_candidates_before: Boolean;
    caret_point: TPoint;
    has_caret: Boolean;
    caret_line_height: Integer;
    candidate_terminal_like_target: Boolean;
    candidate_source: TncCaretAnchorSource;
    candidate_score: Integer;
    queue_candidate_apply: Boolean;
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
    // Do not create a cold session/dictionary just to reject modifier combos.
    // The engine only handles Ctrl/Alt when they are bound to explicit toggles.
    if key_state.ctrl_down or key_state.alt_down then
    begin
        if key_state.ctrl_down and (key_code = VK_SPACE) and m_config.enable_ctrl_space_toggle then
        begin
            // fall through
        end
        else if key_state.ctrl_down and (key_code = VK_OEM_PERIOD) and m_config.enable_ctrl_period_punct_toggle then
        begin
            // fall through
        end
        else
        begin
            Result := True;
            Exit;
        end;
    end;

    session := get_or_create_session(session_id);
    should_hide_candidates := False;
    has_result := True;
    debug_logging := host_log_enabled_for(ll_debug);
    total_start_tick := GetTickCount64;
    readback_elapsed_ms := 0;
    total_elapsed_ms := 0;
    lookup_perf_info := '';
    caret_point := Point(0, 0);
    queue_candidate_apply := False;
    m_lock.Acquire;
    try
        touch_session_activity(session_id);
        had_candidates_before := session.has_candidates;
        sync_session_config_locked(session);
        reload_start_tick := GetTickCount64;
        session.engine.reload_dictionary_if_needed;
        reload_elapsed_ms := Int64(GetTickCount64 - reload_start_tick);
        process_start_tick := GetTickCount64;
        handled := session.engine.process_key(key_code, key_state);
        process_elapsed_ms := Int64(GetTickCount64 - process_start_tick);

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
            if debug_logging then
            begin
                host_log_debug(Format('engine key=%d handled=%d commit=[%s] display=[] comp=[] confirmed=%d',
                    [key_code, Ord(handled), sanitize_log_text(commit_text), session.engine.get_confirmed_length]));
            end;
            display_text := '';
            session.clear_candidates;
            should_hide_candidates := True;
        end;

        if handled and (commit_text = '') then
        begin
            readback_start_tick := GetTickCount64;
            display_text := session.engine.get_display_text;
            candidates := session.engine.get_candidates;
            page_index := session.engine.get_page_index;
            page_count := session.engine.get_page_count;
            selected_index := session.engine.get_selected_index;
            preedit_text := session.engine.get_composition_text;
            lookup_perf_info := session.engine.get_lookup_perf_info;
            m_last_lookup_perf_info := lookup_perf_info;
            if debug_logging then
            begin
                lookup_debug_info := session.engine.get_lookup_debug_info;
            end
            else
            begin
                lookup_debug_info := '';
            end;
            readback_elapsed_ms := Int64(GetTickCount64 - readback_start_tick);
            total_elapsed_ms := Int64(GetTickCount64 - total_start_tick);
            if debug_logging and config.debug_mode then
            begin
                if lookup_debug_info <> '' then
                begin
                    lookup_debug_info := lookup_debug_info + ' ';
                end;
                lookup_debug_info := lookup_debug_info + Format('host=[reload=%d proc=%d read=%d total=%d]',
                    [reload_elapsed_ms, process_elapsed_ms, readback_elapsed_ms, total_elapsed_ms]);
            end;
            if debug_logging then
            begin
                host_log_debug(Format('engine key=%d handled=%d commit=[%s] display=[%s] comp=[%s] confirmed=%d candidates=%d page=%d/%d selected=%d %s',
                    [key_code, Ord(handled), sanitize_log_text(commit_text), sanitize_log_text(display_text),
                    sanitize_log_text(preedit_text), session.engine.get_confirmed_length, Length(candidates),
                    page_index + 1, page_count, selected_index + 1, sanitize_log_text(lookup_debug_info)]));
            end;

            if Length(candidates) = 0 then
            begin
                session.clear_candidates;
                should_hide_candidates := True;
            end
            else
            begin
                session.store_candidates(candidates, page_index, page_count, selected_index, preedit_text);
                if had_candidates_before and session.has_caret then
                begin
                    caret_point := session.last_caret;
                    has_caret := session.has_caret;
                    caret_line_height := session.caret_line_height;
                    candidate_terminal_like_target := session.m_terminal_like_target;
                    candidate_source := session.m_last_candidate_source;
                    candidate_score := session.m_last_candidate_score;
                    if session.needs_candidate_refresh(caret_point, has_caret, caret_line_height,
                        candidate_terminal_like_target) then
                    begin
                        session.stage_candidate_apply(caret_point, has_caret, caret_line_height,
                            candidate_terminal_like_target, candidate_source, candidate_score, queue_candidate_apply);
                    end;
                end;
            end;
        end;
    finally
        m_lock.Release;
    end;

    if should_hide_candidates then
    begin
        TThread.Queue(nil,
            procedure
            begin
                session.hide_candidate_window;
            end);
    end;
    if queue_candidate_apply then
    begin
        TThread.Queue(nil,
            procedure
            var
                queued_session: TncHostSession;
                queued_point: TPoint;
                queued_has_caret: Boolean;
                queued_line_height: Integer;
                queued_terminal_like_target: Boolean;
                queued_source: TncCaretAnchorSource;
                queued_score: Integer;
            begin
                m_lock.Acquire;
                try
                    if not m_sessions.TryGetValue(session_id, queued_session) then
                    begin
                        Exit;
                    end;
                    if not queued_session.consume_pending_candidate_apply(queued_point, queued_has_caret,
                        queued_line_height, queued_terminal_like_target, queued_source, queued_score) then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.apply_candidate_state(queued_point, queued_has_caret, queued_line_height,
                    queued_terminal_like_target, queued_source, queued_score);
            end);
    end;

    if total_elapsed_ms = 0 then
    begin
        total_elapsed_ms := Int64(GetTickCount64 - total_start_tick);
    end;
    if debug_logging then
    begin
        host_log_debug(Format(
            '[DEBUG] perf process_key session=%s key=%d reload=%d proc=%d read=%d total=%d handled=%d commit=%d display=%d hide=%d refresh=%d',
            [session_id, key_code, reload_elapsed_ms, process_elapsed_ms, readback_elapsed_ms, total_elapsed_ms,
            Ord(handled), Length(commit_text), Length(display_text), Ord(should_hide_candidates),
            Ord(queue_candidate_apply)]));
    end
    else if total_elapsed_ms >= c_slow_host_process_key_ms then
    begin
        if lookup_perf_info <> '' then
        begin
            host_log(Format(
                '[PERF] process_key session=%s key=%d reload=%d proc=%d read=%d total=%d handled=%d commit=%d display=%d hide=%d refresh=%d %s',
                [session_id, key_code, reload_elapsed_ms, process_elapsed_ms, readback_elapsed_ms, total_elapsed_ms,
                Ord(handled), Length(commit_text), Length(display_text), Ord(should_hide_candidates),
                Ord(queue_candidate_apply), sanitize_log_text(lookup_perf_info)]));
        end
        else
        begin
            host_log(Format(
                '[PERF] process_key session=%s key=%d reload=%d proc=%d read=%d total=%d handled=%d commit=%d display=%d hide=%d refresh=%d',
                [session_id, key_code, reload_elapsed_ms, process_elapsed_ms, readback_elapsed_ms, total_elapsed_ms,
                Ord(handled), Length(commit_text), Length(display_text), Ord(should_hide_candidates),
                Ord(queue_candidate_apply)]));
        end;
    end;

    if global_state_changed then
    begin
        persist_engine_config(config_to_save);
    end;

    Result := has_result;
end;

function TncEngineHost.get_last_lookup_perf_info: string;
begin
    Result := m_last_lookup_perf_info;
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

function TncEngineHost.get_dictionary_variant(const session_id: string; out dictionary_variant: TncDictionaryVariant): Boolean;
begin
    dictionary_variant := dv_simplified;
    if session_id = '' then
    begin
        Result := False;
        Exit;
    end;

    reload_config_if_needed;
    m_lock.Acquire;
    try
        dictionary_variant := m_config.dictionary_variant;
    finally
        m_lock.Release;
    end;
    Result := True;
end;

function TncEngineHost.set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean): Boolean;
var
    session: TncHostSession;
    iter_session: TncHostSession;
    next_config: TncEngineConfig;
    input_mode_changed: Boolean;
    global_state_changed: Boolean;
    global_input_mode_changed: Boolean;
    config_to_save: TncEngineConfig;
    sessions_to_hide: TList<TncHostSession>;
begin
    Result := False;
    if session_id = '' then
    begin
        Exit;
    end;

    sessions_to_hide := nil;
    try
        sessions_to_hide := TList<TncHostSession>.Create;
        reload_config_if_needed;
        session := get_or_create_session(session_id);
        m_lock.Acquire;
        try
            next_config := m_config;
            input_mode_changed := next_config.input_mode <> input_mode;
            global_input_mode_changed := m_config.input_mode <> input_mode;
            next_config.input_mode := input_mode;
            next_config.full_width_mode := full_width_mode;
            next_config.punctuation_full_width := punctuation_full_width;
            session.engine.update_config(next_config);

            if input_mode_changed and (not global_input_mode_changed) then
            begin
                session.engine.reset;
                session.clear_candidates;
                sessions_to_hide.Add(session);
            end;

            global_state_changed := (m_config.input_mode <> input_mode) or (m_config.full_width_mode <> full_width_mode) or
                (m_config.punctuation_full_width <> punctuation_full_width);
            if global_state_changed then
            begin
                m_config.input_mode := input_mode;
                m_config.full_width_mode := full_width_mode;
                m_config.punctuation_full_width := punctuation_full_width;
                apply_global_engine_config_locked(m_config);
                if global_input_mode_changed then
                begin
                    for iter_session in m_sessions.Values do
                    begin
                        iter_session.engine.reset;
                        iter_session.clear_candidates;
                        sessions_to_hide.Add(iter_session);
                    end;
                end;
                config_to_save := m_config;
            end;
        finally
            m_lock.Release;
        end;

        if global_state_changed then
        begin
            persist_engine_config(config_to_save);
        end;

        if sessions_to_hide.Count > 0 then
        begin
            run_on_ui_thread(
                procedure
                var
                    hide_session: TncHostSession;
                begin
                    for hide_session in sessions_to_hide do
                    begin
                        hide_session.hide_candidate_window;
                    end;
                end);
        end;
    finally
        sessions_to_hide.Free;
    end;

    Result := True;
end;

function TncEngineHost.set_dictionary_variant(const session_id: string;
    const dictionary_variant: TncDictionaryVariant): Boolean;
const
    c_slow_set_variant_ms = 20;
var
    session: TncHostSession;
    iter_session: TncHostSession;
    global_variant_changed: Boolean;
    config_to_save: TncEngineConfig;
    sessions_to_hide: TList<TncHostSession>;
    debug_logging: Boolean;
    total_start_tick: UInt64;
    sync_start_tick: UInt64;
    persist_start_tick: UInt64;
    sync_elapsed_ms: Int64;
    persist_elapsed_ms: Int64;
    total_elapsed_ms: Int64;
begin
    Result := False;
    if session_id = '' then
    begin
        Exit;
    end;

    debug_logging := host_log_enabled_for(ll_debug);
    total_start_tick := GetTickCount64;
    sync_elapsed_ms := 0;
    persist_elapsed_ms := 0;
    sessions_to_hide := nil;
    try
        sessions_to_hide := TList<TncHostSession>.Create;
        reload_config_if_needed;
        session := get_or_create_session(session_id);
        m_lock.Acquire;
        try
            global_variant_changed := m_config.dictionary_variant <> dictionary_variant;
            if global_variant_changed then
            begin
                m_config.dictionary_variant := dictionary_variant;
                sync_start_tick := GetTickCount64;
                // Keep Ctrl+Shift+T responsive: only the current foreground
                // session needs an eager dictionary provider switch. Other
                // sessions inherit m_config and will resync on next activate.
                sync_session_config_locked(session);
                sync_elapsed_ms := Int64(GetTickCount64 - sync_start_tick);
                for iter_session in m_sessions.Values do
                begin
                    if iter_session = session then
                    begin
                        iter_session.engine.reset;
                    end;
                    iter_session.clear_candidates;
                    sessions_to_hide.Add(iter_session);
                end;
                config_to_save := m_config;
            end;
        finally
            m_lock.Release;
        end;

        if global_variant_changed then
        begin
            persist_start_tick := GetTickCount64;
            persist_engine_config(config_to_save);
            persist_elapsed_ms := Int64(GetTickCount64 - persist_start_tick);
            queue_session_prewarm(session_id);
        end;

        if sessions_to_hide.Count > 0 then
        begin
            run_on_ui_thread(
                procedure
                var
                    hide_session: TncHostSession;
                begin
                    for hide_session in sessions_to_hide do
                    begin
                        hide_session.hide_candidate_window;
                    end;
                end);
        end;
    finally
        sessions_to_hide.Free;
    end;

    total_elapsed_ms := Int64(GetTickCount64 - total_start_tick);
    if debug_logging then
    begin
        host_log_debug(Format('[DEBUG] perf set_variant session=%s variant=%d sync=%d persist=%d total=%d changed=%d',
            [session_id, Ord(dictionary_variant), sync_elapsed_ms, persist_elapsed_ms, total_elapsed_ms,
            Ord(global_variant_changed)]));
    end
    else if total_elapsed_ms >= c_slow_set_variant_ms then
    begin
        host_log(Format('[PERF] set_variant session=%s variant=%d sync=%d persist=%d total=%d changed=%d',
            [session_id, Ord(dictionary_variant), sync_elapsed_ms, persist_elapsed_ms, total_elapsed_ms,
            Ord(global_variant_changed)]));
    end;

    Result := True;
end;

function TncEngineHost.get_active(out active: Boolean): Boolean;
begin
    active := has_active_session;
    Result := True;
end;

function TncEngineHost.set_active(const session_id: string; const active: Boolean): Boolean;
var
    session: TncHostSession;
begin
    if session_id = '' then
    begin
        Result := False;
        Exit;
    end;

    if active then
    begin
        ensure_tray_host_running;
        // Shift cold session creation off the first real key. SET_ACTIVE is
        // issued by the TSF active-state worker, so doing the one-time engine
        // bootstrap here avoids a visible first-key stall in the foreground
        // input path.
        session := get_or_create_session(session_id);
        m_lock.Acquire;
        try
            if m_sessions.TryGetValue(session_id, session) then
            begin
                sync_session_config_locked(session);
                session.engine.reload_dictionary_if_needed;
            end;
        finally
            m_lock.Release;
        end;
        queue_session_prewarm(session_id);
    end;

    set_session_active(session_id, active);
    Result := True;
end;

function TncEngineHost.reload_config_now: Boolean;
begin
    Result := reload_config(True);
end;

procedure TncEngineHost.update_caret(const session_id: string; const point: TPoint; const has_caret: Boolean;
    const line_height: Integer; const terminal_like_target: Boolean; const source: TncCaretAnchorSource;
    const anchor_score: Integer);
var
    session: TncHostSession;
    should_apply: Boolean;
    should_queue: Boolean;
begin
    should_queue := False;
    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        should_apply := session.has_candidates and
            session.needs_candidate_refresh(point, has_caret, line_height, terminal_like_target);
        session.set_caret(point, has_caret, line_height, terminal_like_target);
        if should_apply then
        begin
            session.stage_candidate_apply(point, has_caret, line_height, terminal_like_target, source, anchor_score,
                should_queue);
        end;
    finally
        m_lock.Release;
    end;

    if should_queue then
    begin
        TThread.Queue(nil,
            procedure
            var
                queued_session: TncHostSession;
                queued_point: TPoint;
                queued_has_caret: Boolean;
                queued_line_height: Integer;
                queued_terminal_like_target: Boolean;
                queued_source: TncCaretAnchorSource;
                queued_score: Integer;
            begin
                m_lock.Acquire;
                try
                    if not m_sessions.TryGetValue(session_id, queued_session) then
                    begin
                        Exit;
                    end;
                    if not queued_session.consume_pending_candidate_apply(queued_point, queued_has_caret,
                        queued_line_height, queued_terminal_like_target, queued_source, queued_score) then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.apply_candidate_state(queued_point, queued_has_caret, queued_line_height,
                    queued_terminal_like_target, queued_source, queued_score);
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

    host_log_debug(Format('[DEBUG] remove user candidate session=%s index=%d', [session_id, candidate_index]));

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
            host_log_debug(Format('[DEBUG] remove user candidate skipped: index out of range count=%d',
                [Length(session.m_candidates)]));
            Exit;
        end;

        if session.m_candidates[candidate_index].source <> cs_user then
        begin
            host_log_debug('[DEBUG] remove user candidate skipped: source is not cs_user');
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
                session.apply_candidate_state(caret_point, has_caret, session.caret_line_height,
                    session.m_terminal_like_target, session.m_last_candidate_source, session.m_last_candidate_score);
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
        session.set_caret(Point(0, 0), False, 0, False);
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

constructor TncMaintenanceThread.create(const host: TncEngineHost);
begin
    inherited create(False);
    FreeOnTerminate := False;
    m_host := host;
end;

procedure TncMaintenanceThread.detach_host;
begin
    m_host := nil;
end;

procedure TncMaintenanceThread.Execute;
var
    host: TncEngineHost;
    wait_result: TWaitResult;
begin
    while not Terminated do
    begin
        host := m_host;
        if (host <> nil) and (host.m_maintenance_wakeup <> nil) then
        begin
            wait_result := host.m_maintenance_wakeup.WaitFor(c_maintenance_poll_ms);
            if wait_result = wrAbandoned then
            begin
                Break;
            end;
        end
        else
        begin
            Sleep(c_maintenance_poll_ms);
        end;
        if Terminated then
        begin
            Break;
        end;

        try
            host := m_host;
            if host = nil then
            begin
                Break;
            end;
            host.perform_session_prewarm;
            host.maybe_checkpoint_user_dictionary;
        except
            on e: Exception do
            begin
                host_log(Format('[WARN] maintenance exception %s: %s', [e.ClassName, e.Message]));
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
    dictionary_variant: TncDictionaryVariant;
    mode_value: Integer;
    x: Integer;
    y: Integer;
    has_caret: Boolean;
    line_height: Integer;
    caret_terminal_like_target: Boolean;
    caret_source_value: Integer;
    caret_source: TncCaretAnchorSource;
    caret_score: Integer;
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
        if not (SameText(cmd, 'GET_ACTIVE') or SameText(cmd, 'GET_STATE') or SameText(cmd, 'GET_VARIANT') or
            SameText(cmd, 'PING') or SameText(cmd, 'SET_ACTIVE') or SameText(cmd, 'SET_SURROUNDING') or
            SameText(cmd, 'SET_CARET')) then
        begin
            if host_log_enabled_for(ll_debug) then
            begin
                host_log_debug(Format('request cmd=%s session=%s', [cmd, session_id]));
            end;
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
            line_height := 0;
            caret_terminal_like_target := False;
            if Length(fields) >= 4 then
            begin
                x := StrToIntDef(fields[2], 0);
                y := StrToIntDef(fields[3], 0);
            end;
            if Length(fields) >= 5 then
            begin
                has_caret := flag_to_bool(fields[4]);
            end;
            if Length(fields) >= 6 then
            begin
                line_height := StrToIntDef(fields[5], 0);
            end;
            caret_source := casCursor;
            if Length(fields) >= 7 then
            begin
                caret_source_value := StrToIntDef(fields[6], Ord(casCursor));
                if (caret_source_value >= Ord(Low(TncCaretAnchorSource))) and
                    (caret_source_value <= Ord(High(TncCaretAnchorSource))) then
                begin
                    caret_source := TncCaretAnchorSource(caret_source_value);
                end;
            end;
            caret_score := 0;
            if Length(fields) >= 8 then
            begin
                caret_score := StrToIntDef(fields[7], 0);
            end;
            if Length(fields) >= 9 then
            begin
                caret_terminal_like_target := flag_to_bool(fields[8]);
            end;

            m_host.update_caret(session_id, Point(x, y), has_caret, line_height, caret_terminal_like_target,
                caret_source, caret_score);
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

        if SameText(cmd, 'RELOAD_CONFIG') then
        begin
            if m_host.reload_config_now then
            begin
                Result := 'OK';
            end
            else
            begin
                Result := 'ERROR'#9'failed';
            end;
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

        if SameText(cmd, 'GET_VARIANT') then
        begin
            if m_host.get_dictionary_variant(session_id, dictionary_variant) then
            begin
                Result := 'OK'#9 + IntToStr(Ord(dictionary_variant));
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

        if SameText(cmd, 'SET_VARIANT') then
        begin
            if Length(fields) < 3 then
            begin
                Result := 'ERROR'#9'bad_args';
                Exit;
            end;

            mode_value := StrToIntDef(fields[2], Ord(dv_simplified));
            if (mode_value < Ord(Low(TncDictionaryVariant))) or (mode_value > Ord(High(TncDictionaryVariant))) then
            begin
                mode_value := Ord(dv_simplified);
            end;
            if m_host.set_dictionary_variant(session_id, TncDictionaryVariant(mode_value)) then
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

            key_code := StrToIntDef(fields[2], 0);
            key_state.shift_down := flag_to_bool(fields[3]);
            key_state.ctrl_down := flag_to_bool(fields[4]);
            key_state.alt_down := flag_to_bool(fields[5]);
            key_state.caps_lock := flag_to_bool(fields[6]);
            if host_log_enabled_for(ll_debug) then
            begin
                host_log_debug(Format('test_key session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
                    [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down),
                    Ord(key_state.alt_down), Ord(key_state.caps_lock)]));
            end;
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

            key_code := StrToIntDef(fields[2], 0);
            key_state.shift_down := flag_to_bool(fields[3]);
            key_state.ctrl_down := flag_to_bool(fields[4]);
            key_state.alt_down := flag_to_bool(fields[5]);
            key_state.caps_lock := flag_to_bool(fields[6]);
            if host_log_enabled_for(ll_debug) then
            begin
                host_log_debug(Format('process_key session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
                    [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down),
                    Ord(key_state.alt_down), Ord(key_state.caps_lock)]));
            end;
            if m_host.process_key(session_id, Word(key_code), key_state, handled, commit_text, display_text, input_mode,
                full_width_mode, punctuation_full_width) then
            begin
                Result := 'OK'#9 + bool_to_flag(handled) + #9 + encode_ipc_text(commit_text) + #9 +
                    encode_ipc_text(display_text) + #9 + IntToStr(Ord(input_mode)) + #9 + bool_to_flag(full_width_mode) +
                    #9 + bool_to_flag(punctuation_full_width) + #9 + encode_ipc_text(m_host.get_last_lookup_perf_info);
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
