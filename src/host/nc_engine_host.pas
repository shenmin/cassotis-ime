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
    nc_shortcut,
    nc_engine_intf,
    nc_candidate_window,
    nc_candidate_paging,
    nc_config,
    nc_ipc_common,
    nc_caret_anchor_policy,
    nc_input_epoch,
    nc_local_completion_host,
    nc_one_key_rerank_host,
    nc_char_lm,
    nc_char_lm_host;

type
    TncEngineHost = class;

    TncHostSession = class
    private
        m_owner: TncEngineHost;
        m_session_id: string;
        m_instance_id: UInt64;
        m_last_activity_tick: UInt64;
        m_release_requested: Boolean;
        m_engine: TncEngine;
        m_candidate_window: TncCandidateWindow;
        m_last_caret: TPoint;
        m_has_caret: Boolean;
        m_caret_line_height: Integer;
        m_terminal_like_target: Boolean;
        m_comless_target: Boolean;
        m_candidates: TncCandidateList;
        m_candidate_pages: TncCandidatePages;
        m_candidate_viewport: TncCandidateViewport;
        m_one_key_completion: TncOneKeyCompletion;
        m_page_index: Integer;
        m_page_count: Integer;
        m_selected_index: Integer;
        m_preedit_text: string;
        m_candidate_dirty: Boolean;
        m_candidate_generation: UInt64;
        m_pending_candidate_caret: TPoint;
        m_pending_candidate_has_caret: Boolean;
        m_pending_candidate_line_height: Integer;
        m_pending_candidate_terminal_like_target: Boolean;
        m_pending_candidate_comless_target: Boolean;
        m_pending_candidate_source: TncCaretAnchorSource;
        m_pending_candidate_score: Integer;
        m_pending_candidate_generation: UInt64;
        m_candidate_apply_queued: Boolean;
        m_last_candidate_source: TncCaretAnchorSource;
        m_last_candidate_score: Integer;
        m_last_candidate_apply_tick: DWORD;
        m_last_candidate_debug_mode: Boolean;
        procedure ensure_candidate_window;
        procedure handle_remove_user_candidate(const candidate_index: Integer);
        function handle_prepare_candidate(const page_index, candidate_index: Integer;
            const generation: UInt64): Boolean;
        procedure refresh_candidate_pages(const input_changed: Boolean);
    public
        constructor create(const owner: TncEngineHost; const session_id: string; const instance_id: UInt64;
            const config: TncEngineConfig;
            const defer_optional_dictionary_models: Boolean = False;
            const owned_engine: TncEngine = nil);
        destructor Destroy; override;
        procedure adopt_session_id(const session_id: string);
        procedure touch;
        procedure reactivate;
        procedure request_release;
        procedure update_config(const config: TncEngineConfig);
        procedure warm_candidate_window;
        procedure set_caret(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const comless_target: Boolean);
        function needs_candidate_refresh(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const comless_target: Boolean): Boolean;
        function candidate_generation: UInt64;
        procedure store_candidates(const candidates: TncCandidateList; const page_index: Integer;
            const page_count: Integer; const selected_index: Integer;
            const preedit_text: string;
            const one_key_completion: TncOneKeyCompletion);
        procedure clear_candidates;
        function prepare_candidate_selection(const page_index, candidate_index: Integer;
            const generation: UInt64): Boolean;
        function apply_one_key_rerank(const task: TncOneKeyRerankTask;
            const chosen: Integer; out new_generation: UInt64): Boolean;
        function apply_long_neural_completion(
            const task: TncLocalCompletionTask;
            const completion_result: TncLongNeuralCompletionResult;
            out new_generation: UInt64): Boolean;
        function has_candidates: Boolean;
        function has_dirty_candidates: Boolean;
        procedure apply_candidate_content_only(const candidate_generation: UInt64);
        procedure apply_candidate_state(const caret: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const comless_target: Boolean;
            const source: TncCaretAnchorSource; const anchor_score: Integer; const candidate_generation: UInt64);
        procedure stage_candidate_apply(const caret: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const comless_target: Boolean;
            const source: TncCaretAnchorSource; const anchor_score: Integer; out should_queue: Boolean);
        function consume_pending_candidate_apply(out caret: TPoint; out has_caret: Boolean;
            out line_height: Integer; out terminal_like_target: Boolean; out comless_target: Boolean;
            out source: TncCaretAnchorSource; out anchor_score: Integer;
            out candidate_generation: UInt64): Boolean;
        procedure hide_candidate_window;
        property engine: TncEngine read m_engine;
        property instance_id: UInt64 read m_instance_id;
        property last_activity_tick: UInt64 read m_last_activity_tick;
        property release_requested: Boolean read m_release_requested;
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
        m_session_prewarm_queue: TQueue<string>;
        m_session_prewarm_pending: TDictionary<string, Byte>;
        m_lock: TCriticalSection;
        m_session_create_lock: TCriticalSection;
        m_standby_session: TncHostSession;
        m_standby_building: Boolean;
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
        m_next_session_instance_id: UInt64;
        m_config: TncEngineConfig;
        m_long_neural_reranker: IncLongNeuralReranker;
        m_local_completion_host: TncLocalCompletionHost;
        m_one_key_rerank_host: TncOneKeyRerankHost;
        // One shared character LM session (loaded on first use). The engine
        // sessions use it directly; the Tab worker through background_view.
        m_char_lm_host: TncCharLmHost;
        m_char_lm: IncCharLm;
        m_last_lookup_perf_info: string;
        m_input_epochs: TncInputEpochs;
        function admit_input_epoch_locked(const session_id: string; const input_epoch: UInt64;
            const command: string): TncInputEpochDecision;
        function admit_reset_locked(const session_id: string; const input_epoch: UInt64): Boolean;
        procedure trim_input_epochs_locked;
        function process_key_admitted(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
            out full_width_mode: Boolean; out punctuation_full_width: Boolean;
            const input_epoch: UInt64): Boolean;
        procedure reset_session_admitted(const session_id: string;
            const preserve_document_context: Boolean; const input_epoch: UInt64);
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
        procedure ensure_standby_session;
        procedure reclaim_inactive_sessions;
        function reclaim_session_on_ui_thread(const session_id: string; const instance_id: UInt64;
            const expected_activity_tick: UInt64; const reason: string): Boolean;
        procedure remove_session_prewarm_locked(const session_id: string);
        procedure remove_user_candidate(const session_id: string; const candidate_index: Integer);
        procedure queue_long_neural_completion(
            const session: TncHostSession);
        procedure prefetch_long_neural_completion(const session: TncHostSession);
        procedure handle_long_neural_completion(
            const task: TncLocalCompletionTask;
            const completion_result: TncLongNeuralCompletionResult);
        procedure queue_one_key_rerank(const session: TncHostSession);
        procedure handle_one_key_rerank(const task: TncOneKeyRerankTask;
            const chosen: Integer);
    public
        constructor create;
        destructor Destroy; override;
        function test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean): Boolean;
        function process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
            out full_width_mode: Boolean; out punctuation_full_width: Boolean;
            const input_epoch: UInt64 = 0): Boolean;
        function get_last_lookup_perf_info: string;
        function get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
            out punctuation_full_width: Boolean): Boolean;
        function get_shortcut_config(const session_id: string;
            out shortcut_config: TncShortcutConfig): Boolean;
        function get_dictionary_variant(const session_id: string; out dictionary_variant: TncDictionaryVariant): Boolean;
        function set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean; const state_source: string = ''): Boolean;
        function set_dictionary_variant(const session_id: string; const dictionary_variant: TncDictionaryVariant): Boolean;
        function get_active(out active: Boolean): Boolean;
        function set_active(const session_id: string; const active: Boolean): Boolean;
        function release_session(const session_id: string): Boolean;
        function reload_config_now: Boolean;
        function clear_user_dictionary(const session_id: string): Boolean;
        procedure update_caret(const session_id: string; const point: TPoint; const has_caret: Boolean;
            const line_height: Integer; const terminal_like_target: Boolean; const comless_target: Boolean;
            const source: TncCaretAnchorSource; const anchor_score: Integer);
        procedure update_surrounding(const session_id: string;
            const left_context: string; const document_key: string = '';
            const document_snapshot: string = '');
        procedure reset_session(const session_id: string;
            const preserve_document_context: Boolean = False;
            const input_epoch: UInt64 = 0);
    end;

    TncPipeServerThread = class(TThread)
    private
        m_host: TncEngineHost;
        m_pipe_name: string;
        function handle_request(const request_text: string): string;
        function wait_for_client(const pipe_handle: THandle; const io_event: THandle): Boolean;
        function serve_client(const pipe_handle: THandle; const io_event: THandle): Boolean;
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
    nc_dictionary_intf,
    nc_sqlite,
    nc_log,
    nc_pinyin_transformer_host;

type
    TncHostSessionRef = record
        session_id: string;
        instance_id: UInt64;
    end;

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
    // Each warm session owns two dictionary providers and their language-model
    // caches. Keep a small LRU-style pool and reclaim abandoned TSF instances.
    c_session_cache_limit = 4;
    c_session_capacity_grace_ms = 1000;
    c_session_release_grace_ms = 250;
    c_session_idle_reclaim_ms = 5 * 60 * 1000;
    c_candidate_apply_merge_ms = 35;
    c_cold_start_foreground_grace_ms = 120;
    c_dictionary_upgrade_idle_ms = 90;
    c_user_dict_checkpoint_idle_ms = 5000;
    c_user_dict_checkpoint_retry_ms = 5000;
    c_tray_host_mutex_name_format = 'Local\cassotis_ime_tray_host_v1_s%d';
    c_tray_host_restart_min_interval_ms = 800;
    // Windows shell search surfaces run with AppContainer-style tokens; AC/S-1-15-2-2 keep IPC reachable there.
    c_ipc_security_sddl = 'D:(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;OW)(A;;GRGW;;;AU)(A;;GRGW;;;AC)(A;;GRGW;;;S-1-15-2-2)S:(ML;;NW;;;LW)';

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
        casImm:
            Result := 7;
        casComlessFallback:
            Result := 6;
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
        // Same writable directory as the shared log (per-user when installed).
        g_host_log_path := IncludeTrailingPathDelimiter(ExtractFileDir(get_default_log_path)) +
            'engine_host.log';
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
            (left_candidates[i].dict_weight <> right_candidates[i].dict_weight) or
            (left_candidates[i].fuzzy_cost <> right_candidates[i].fuzzy_cost) or
            (left_candidates[i].fuzzy_rules <> right_candidates[i].fuzzy_rules) or
            (left_candidates[i].display_kind <> right_candidates[i].display_kind) then
        begin
            Result := False;
            Exit;
        end;
    end;
end;

function one_key_completions_equal(const left_value: TncOneKeyCompletion;
    const right_value: TncOneKeyCompletion): Boolean;
begin
    Result := (left_value.text = right_value.text) and
        (left_value.full_pinyin = right_value.full_pinyin) and
        (left_value.anchor_text = right_value.anchor_text) and
        (left_value.suffix_text = right_value.suffix_text) and
        (left_value.anchor_path = right_value.anchor_path) and
        (left_value.weight = right_value.weight) and
        (left_value.source = right_value.source);
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

constructor TncHostSession.create(const owner: TncEngineHost; const session_id: string; const instance_id: UInt64;
    const config: TncEngineConfig;
    const defer_optional_dictionary_models: Boolean = False;
    const owned_engine: TncEngine = nil);
begin
    inherited create;
    m_owner := owner;
    m_session_id := session_id;
    m_instance_id := instance_id;
    m_last_activity_tick := GetTickCount64;
    m_release_requested := False;
    // The session owns injected engines too, allowing isolated session replay.
    m_engine := owned_engine;
    if m_engine = nil then
        m_engine := TncEngine.create(config, defer_optional_dictionary_models);
    if owner <> nil then
    begin
        m_engine.set_long_neural_reranker(owner.m_long_neural_reranker);
        m_engine.set_char_lm(owner.m_char_lm, True, True);
    end;
    m_candidate_window := nil;
    m_last_caret := Point(0, 0);
    m_has_caret := False;
    m_caret_line_height := 0;
    m_terminal_like_target := False;
    m_comless_target := False;
    SetLength(m_candidates, 0);
    m_one_key_completion := Default(TncOneKeyCompletion);
    m_page_index := 0;
    m_page_count := 0;
    m_selected_index := 0;
    m_preedit_text := '';
    m_candidate_dirty := True;
    m_candidate_generation := 0;
    m_pending_candidate_caret := Point(0, 0);
    m_pending_candidate_has_caret := False;
    m_pending_candidate_line_height := 0;
    m_pending_candidate_terminal_like_target := False;
    m_pending_candidate_comless_target := False;
    m_pending_candidate_source := casCursor;
    m_pending_candidate_score := Low(Integer);
    m_pending_candidate_generation := 0;
    m_candidate_apply_queued := False;
    m_last_candidate_source := casCursor;
    m_last_candidate_score := Low(Integer);
    m_last_candidate_apply_tick := 0;
    m_last_candidate_debug_mode := config.debug_mode;
end;

procedure TncHostSession.touch;
begin
    // RELEASE_SESSION is sticky: delayed IPC may refresh activity but must
    // not revive a TSF instance whose owner has already been destroyed.
    m_last_activity_tick := GetTickCount64;
end;

procedure TncHostSession.reactivate;
begin
    m_last_activity_tick := GetTickCount64;
    m_release_requested := False;
end;

procedure TncHostSession.request_release;
begin
    m_last_activity_tick := GetTickCount64;
    m_release_requested := True;
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

procedure TncHostSession.adopt_session_id(const session_id: string);
begin
    m_session_id := session_id;
    m_last_activity_tick := GetTickCount64;
    m_release_requested := False;
end;

procedure TncHostSession.ensure_candidate_window;
begin
    if m_candidate_window = nil then
    begin
        m_candidate_window := TncCandidateWindow.create;
        m_candidate_window.on_remove_user_candidate := handle_remove_user_candidate;
        m_candidate_window.on_prepare_candidate := handle_prepare_candidate;
    end;
    if m_engine <> nil then
    begin
        m_candidate_window.apply_appearance(m_engine.config.candidate_font_name,
            m_engine.config.candidate_font_size, m_engine.config.candidate_color_scheme);
    end;
end;

procedure TncHostSession.handle_remove_user_candidate(const candidate_index: Integer);
begin
    if m_owner <> nil then
    begin
        m_owner.remove_user_candidate(m_session_id, candidate_index);
    end;
end;

procedure TncHostSession.refresh_candidate_pages(const input_changed: Boolean);
var row, page: Integer;
begin
    m_candidate_viewport.update(m_engine.config.candidate_expand_on_paging,
        input_changed, m_page_index, m_page_count, m_engine.candidate_paging_expanded);
    m_candidate_pages := nil;
    m_engine.set_candidate_paging_expanded(False);
    if not m_candidate_viewport.expanded then Exit;
    SetLength(m_candidate_pages, m_candidate_viewport.row_count);
    for row := 0 to High(m_candidate_pages) do
    begin
        page := m_candidate_viewport.first_page + row;
        m_candidate_pages[row].page_index := page;
        if page = m_page_index then
            m_candidate_pages[row].candidates := Copy(m_candidates)
        else
            m_candidate_pages[row].candidates := m_engine.get_candidate_page_snapshot(page);
        // Never display guessed/raw candidates when a final page is unavailable.
        if Length(m_candidate_pages[row].candidates) = 0 then
        begin
            m_candidate_pages := nil;
            Exit;
        end;
    end;
    m_engine.set_candidate_paging_expanded(Length(m_candidate_pages) > 1);
end;

function TncHostSession.prepare_candidate_selection(const page_index,
    candidate_index: Integer; const generation: UInt64): Boolean;
var row: Integer; expected, current: TncCandidateList;
begin
    Result := False;
    if (generation <> m_candidate_generation) or m_release_requested then Exit;
    expected := nil;
    if page_index = m_page_index then expected := m_candidates
    else
        for row := 0 to High(m_candidate_pages) do
            if m_candidate_pages[row].page_index = page_index then
                expected := m_candidate_pages[row].candidates;
    if (candidate_index < 0) or (candidate_index >= Length(expected)) then Exit;
    current := m_engine.get_candidate_page_snapshot(page_index);
    if not candidates_equal(expected, current) then Exit;
    if not m_engine.activate_candidate_page(page_index, candidate_index) then Exit;
    m_candidates := Copy(current);
    m_page_index := page_index;
    m_selected_index := candidate_index;
    m_candidate_dirty := True;
    Inc(m_candidate_generation);
    refresh_candidate_pages(False);
    Result := True;
end;

function TncHostSession.handle_prepare_candidate(const page_index,
    candidate_index: Integer; const generation: UInt64): Boolean;
begin
    Result := False;
    if m_owner = nil then Exit;
    m_owner.m_lock.Acquire;
    try
        Result := prepare_candidate_selection(page_index, candidate_index, generation);
    finally
        m_owner.m_lock.Release;
    end;
end;

procedure TncHostSession.update_config(const config: TncEngineConfig);
var paging_changed: Boolean;
begin
    if m_engine <> nil then
    begin
        paging_changed := (m_engine.config.candidate_expand_on_paging <>
            config.candidate_expand_on_paging) or
            (m_engine.config.candidate_page_size <> config.candidate_page_size);
        m_engine.update_config(config);
        if paging_changed then
        begin
            m_candidate_viewport := Default(TncCandidateViewport);
            m_candidate_pages := nil;
            Inc(m_candidate_generation);
        end;
    end;
    if m_candidate_window <> nil then
    begin
        m_candidate_window.apply_appearance(config.candidate_font_name, config.candidate_font_size,
            config.candidate_color_scheme);
        m_candidate_dirty := True;
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
    const terminal_like_target: Boolean; const comless_target: Boolean);
begin
    m_last_caret := point;
    m_has_caret := has_caret;
    m_caret_line_height := line_height;
    m_terminal_like_target := terminal_like_target;
    m_comless_target := comless_target;
end;

function TncHostSession.needs_candidate_refresh(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
    const terminal_like_target: Boolean; const comless_target: Boolean): Boolean;
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

    Result := (m_terminal_like_target <> terminal_like_target) or
        (m_comless_target <> comless_target);
end;

function TncHostSession.candidate_generation: UInt64;
begin
    Result := m_candidate_generation;
end;

procedure TncHostSession.store_candidates(const candidates: TncCandidateList; const page_index: Integer;
    const page_count: Integer; const selected_index: Integer;
    const preedit_text: string;
    const one_key_completion: TncOneKeyCompletion);
var
    changed: Boolean;
    input_changed: Boolean;
    previous_visible_rows: Integer;
begin
    previous_visible_rows := Length(m_candidate_pages);
    input_changed := m_preedit_text <> preedit_text;
    changed := (m_page_index <> page_index) or
        (m_page_count <> page_count) or
        (m_selected_index <> selected_index) or
        (m_preedit_text <> preedit_text) or
        (not one_key_completions_equal(m_one_key_completion,
        one_key_completion)) or
        (not candidates_equal(m_candidates, candidates));
    // Async UI generations must own their snapshot, not the producer's array.
    m_candidates := Copy(candidates);
    m_one_key_completion := one_key_completion;
    m_page_index := page_index;
    m_page_count := page_count;
    m_selected_index := selected_index;
    m_preedit_text := preedit_text;
    refresh_candidate_pages(input_changed);
    // Expanding at the first row does not change the page or selected item.
    changed := changed or (previous_visible_rows <> Length(m_candidate_pages));
    if changed then
    begin
        Inc(m_candidate_generation);
        m_candidate_dirty := True;
    end;
    // The engine owns eligibility, including guarded static long-hint challenges.
    // An empty-only gate here would diverge from the benchmark/runtime contract.
    if changed and (m_owner <> nil) then
    begin
        m_owner.queue_long_neural_completion(Self);
        m_owner.queue_one_key_rerank(Self);
    end;
end;

procedure TncHostSession.clear_candidates;
begin
    SetLength(m_candidates, 0);
    m_candidate_pages := nil;
    m_candidate_viewport := Default(TncCandidateViewport);
    if m_engine <> nil then m_engine.set_candidate_paging_expanded(False);
    m_one_key_completion := Default(TncOneKeyCompletion);
    m_page_index := 0;
    m_page_count := 0;
    m_selected_index := 0;
    m_preedit_text := '';
    Inc(m_candidate_generation);
    m_candidate_dirty := True;
end;

function TncHostSession.apply_one_key_rerank(const task: TncOneKeyRerankTask;
    const chosen: Integer; out new_generation: UInt64): Boolean;
begin
    new_generation := m_candidate_generation;
    Result := (task.session_instance_id = m_instance_id) and
        (task.candidate_generation = m_candidate_generation) and
        (not m_release_requested) and (m_engine <> nil) and
        m_engine.apply_one_key_rerank(task.request, chosen);
    if not Result then
    begin
        Exit;
    end;
    m_one_key_completion := m_engine.get_one_key_completion;
    Inc(m_candidate_generation);
    new_generation := m_candidate_generation;
    m_candidate_dirty := True;
end;

function TncHostSession.apply_long_neural_completion(
    const task: TncLocalCompletionTask;
    const completion_result: TncLongNeuralCompletionResult;
    out new_generation: UInt64): Boolean;
begin
    new_generation := m_candidate_generation;
    Result := (task.session_instance_id = m_instance_id) and
        (task.candidate_generation = m_candidate_generation) and
        (not m_release_requested) and (m_engine <> nil) and
        m_engine.apply_long_neural_completion(task.request,
        completion_result);
    if not Result then
    begin
        Exit;
    end;
    m_one_key_completion := m_engine.get_one_key_completion;
    Inc(m_candidate_generation);
    new_generation := m_candidate_generation;
    m_candidate_dirty := True;
end;

function TncHostSession.has_candidates: Boolean;
begin
    Result := (Length(m_candidates) > 0) or
        (m_one_key_completion.text <> '');
end;

function TncHostSession.has_dirty_candidates: Boolean;
begin
    Result := m_candidate_dirty;
end;

procedure TncHostSession.apply_candidate_content_only(const candidate_generation: UInt64);
begin
    if not has_candidates then
    begin
        hide_candidate_window;
        if candidate_generation = m_candidate_generation then
        begin
            m_candidate_dirty := False;
        end;
        Exit;
    end;

    ensure_candidate_window;
    if m_candidate_dirty or (m_last_candidate_debug_mode <> m_engine.config.debug_mode) then
    begin
        m_candidate_window.update_candidates(m_candidates, m_page_index, m_page_count, m_selected_index,
            m_preedit_text, m_one_key_completion,
            m_engine.config.one_key_completion_key,
            m_engine.config.debug_mode, m_engine.config.pinyin_input_scheme,
            m_candidate_pages, m_candidate_generation);
        m_last_candidate_debug_mode := m_engine.config.debug_mode;
    end;
    if candidate_generation = m_candidate_generation then
    begin
        m_candidate_dirty := False;
    end;
end;

procedure TncHostSession.hide_candidate_window;
begin
    if m_candidate_window <> nil then
    begin
        m_candidate_window.hide_window;
    end;
end;

procedure TncHostSession.apply_candidate_state(const caret: TPoint; const has_caret: Boolean; const line_height: Integer;
    const terminal_like_target: Boolean; const comless_target: Boolean;
    const source: TncCaretAnchorSource; const anchor_score: Integer; const candidate_generation: UInt64);
var
    y_offset: Integer;
    comless_clearance: Integer;
    max_comless_clearance: Integer;
    target_point: TPoint;
    window_rect: TRect;
    monitor_info: TMonitorInfo;
    monitor_handle: HMONITOR;
    debug_logging: Boolean;
begin
    if not has_candidates then
    begin
        hide_candidate_window;
        if candidate_generation = m_candidate_generation then
        begin
            m_candidate_dirty := False;
        end;
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
            m_preedit_text, m_one_key_completion,
            m_engine.config.one_key_completion_key,
            m_engine.config.debug_mode, m_engine.config.pinyin_input_scheme,
            m_candidate_pages, m_candidate_generation);
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
        if should_use_comless_legacy_placement(comless_target, source) then
        begin
            comless_clearance := scale_candidate_offset(c_default_offset,
                target_point);
            max_comless_clearance := scale_candidate_offset(64,
                target_point);
            if line_height > comless_clearance then
            begin
                comless_clearance := line_height;
            end;
            if comless_clearance > max_comless_clearance then
            begin
                comless_clearance := max_comless_clearance;
            end;
            m_candidate_window.show_at(target_point.X, target_point.Y,
                True, comless_clearance);
        end
        else
        begin
            m_candidate_window.show_at(target_point.X,
                target_point.Y + y_offset);
        end;
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
                    host_log_debug(Format('[DEBUG] candidate metrics line_height=%d y_offset=%d comless=%d',
                        [line_height, y_offset, Ord(comless_target)]));
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
                    host_log_debug(Format('[DEBUG] candidate metrics line_height=%d y_offset=%d comless=%d',
                        [line_height, y_offset, Ord(comless_target)]));
                end;
            end;
        end;
    end;
    m_last_candidate_source := source;
    m_last_candidate_score := anchor_score;
    m_last_candidate_apply_tick := GetTickCount;
    if candidate_generation = m_candidate_generation then
    begin
        m_candidate_dirty := False;
    end;
end;

procedure TncHostSession.stage_candidate_apply(const caret: TPoint; const has_caret: Boolean;
    const line_height: Integer; const terminal_like_target: Boolean; const comless_target: Boolean;
    const source: TncCaretAnchorSource; const anchor_score: Integer;
    out should_queue: Boolean);
var
    now_tick: DWORD;
    replace_pending: Boolean;
begin
    should_queue := False;

    if m_candidate_apply_queued then
    begin
        if m_candidate_dirty then
        begin
            m_pending_candidate_generation := m_candidate_generation;
        end;
        replace_pending := (anchor_score > m_pending_candidate_score) or
            ((anchor_score = m_pending_candidate_score) and
            (caret_source_priority(source) >= caret_source_priority(m_pending_candidate_source)));
        if replace_pending then
        begin
            m_pending_candidate_caret := caret;
            m_pending_candidate_has_caret := has_caret;
            m_pending_candidate_line_height := line_height;
            m_pending_candidate_terminal_like_target := terminal_like_target;
            m_pending_candidate_comless_target := comless_target;
            m_pending_candidate_source := source;
            m_pending_candidate_score := anchor_score;
            m_pending_candidate_generation := m_candidate_generation;
        end;
        Exit;
    end;

    if m_candidate_dirty then
    begin
        m_pending_candidate_caret := caret;
        m_pending_candidate_has_caret := has_caret;
        m_pending_candidate_line_height := line_height;
        m_pending_candidate_terminal_like_target := terminal_like_target;
        m_pending_candidate_comless_target := comless_target;
        m_pending_candidate_source := source;
        m_pending_candidate_score := anchor_score;
        m_pending_candidate_generation := m_candidate_generation;
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
    m_pending_candidate_comless_target := comless_target;
    m_pending_candidate_source := source;
    m_pending_candidate_score := anchor_score;
    m_pending_candidate_generation := m_candidate_generation;
    should_queue := True;
    if should_queue then
    begin
        m_candidate_apply_queued := True;
    end;
end;

function TncHostSession.consume_pending_candidate_apply(out caret: TPoint; out has_caret: Boolean;
    out line_height: Integer; out terminal_like_target: Boolean; out comless_target: Boolean;
    out source: TncCaretAnchorSource; out anchor_score: Integer; out candidate_generation: UInt64): Boolean;
begin
    if not m_candidate_apply_queued then
    begin
        caret := Point(0, 0);
        has_caret := False;
        line_height := 0;
        terminal_like_target := False;
        comless_target := False;
        source := casCursor;
        anchor_score := 0;
        candidate_generation := m_candidate_generation;
        Result := False;
        Exit;
    end;

    caret := m_pending_candidate_caret;
    has_caret := m_pending_candidate_has_caret;
    line_height := m_pending_candidate_line_height;
    terminal_like_target := m_pending_candidate_terminal_like_target;
    comless_target := m_pending_candidate_comless_target;
    source := m_pending_candidate_source;
    anchor_score := m_pending_candidate_score;
    candidate_generation := m_pending_candidate_generation;
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

procedure TncEngineHost.queue_long_neural_completion(
    const session: TncHostSession);
var
    task: TncLocalCompletionTask;
begin
    if (session = nil) or (session.engine = nil) or
        (m_local_completion_host = nil) then
    begin
        Exit;
    end;
    task := Default(TncLocalCompletionTask);
    if not session.engine.get_long_neural_completion_request(
        task.request) then
    begin
        Exit;
    end;
    task.session_id := session.m_session_id;
    task.session_instance_id := session.instance_id;
    task.candidate_generation := session.candidate_generation;
    m_local_completion_host.enqueue(task);
end;

procedure TncEngineHost.prefetch_long_neural_completion(const session: TncHostSession);
var task: TncLocalCompletionTask;
begin
    if (session = nil) or (session.engine = nil) or
        (m_local_completion_host = nil) then Exit;
    if session.engine.get_composition_text = session.m_preedit_text then Exit;
    task := Default(TncLocalCompletionTask);
    if not session.engine.get_prefetch_long_neural_completion_request(task.request) then Exit;
    task.session_id := session.m_session_id;
    task.session_instance_id := session.instance_id;
    m_local_completion_host.prefetch(task);
end;

procedure TncEngineHost.queue_one_key_rerank(const session: TncHostSession);
var
    task: TncOneKeyRerankTask;
begin
    if (session = nil) or (session.engine = nil) or
        (m_one_key_rerank_host = nil) then
    begin
        Exit;
    end;
    task := Default(TncOneKeyRerankTask);
    if not session.engine.get_one_key_rerank_request(task.request) then
    begin
        Exit;
    end;
    task.session_id := session.m_session_id;
    task.session_instance_id := session.instance_id;
    task.candidate_generation := session.candidate_generation;
    m_one_key_rerank_host.enqueue(task);
end;

procedure TncEngineHost.handle_one_key_rerank(const task: TncOneKeyRerankTask;
    const chosen: Integer);
var
    session: TncHostSession;
    new_generation: UInt64;
begin
    m_lock.Acquire;
    try
        if (not m_sessions.TryGetValue(task.session_id, session)) or
            (not m_active_sessions.ContainsKey(task.session_id)) or
            (session.instance_id <> task.session_instance_id) or
            (not session.apply_one_key_rerank(task, chosen, new_generation)) then
        begin
            Exit;
        end;
        session.apply_candidate_content_only(new_generation);
    finally
        m_lock.Release;
    end;
end;

procedure TncEngineHost.handle_long_neural_completion(
    const task: TncLocalCompletionTask;
    const completion_result: TncLongNeuralCompletionResult);
var
    session: TncHostSession;
    new_generation: UInt64;
begin
    m_lock.Acquire;
    try
        if (not m_sessions.TryGetValue(task.session_id, session)) or
            (not m_active_sessions.ContainsKey(task.session_id)) or
            (session.instance_id <> task.session_instance_id) or
            (not session.apply_long_neural_completion(task,
            completion_result, new_generation)) then
        begin
            Exit;
        end;
        session.apply_candidate_content_only(new_generation);
    finally
        m_lock.Release;
    end;
end;

constructor TncEngineHost.create;
begin
    inherited create;
    m_sessions := TObjectDictionary<string, TncHostSession>.Create([doOwnsValues]);
    m_active_sessions := TDictionary<string, Byte>.Create;
    m_recent_active_sessions := TDictionary<string, DWORD>.Create;
    m_active_owner_session_id := '';
    m_session_prewarm_queue := TQueue<string>.Create;
    m_session_prewarm_pending := TDictionary<string, Byte>.Create;
    m_lock := TCriticalSection.Create;
    m_session_create_lock := TCriticalSection.Create;
    m_input_epochs := TncInputEpochs.create;
    m_standby_session := nil;
    m_standby_building := False;
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
    m_next_session_instance_id := 0;
    m_long_neural_reranker := TncPinyinTransformerHostReranker.create(
        ExtractFileDir(ParamStr(0)), True);
    m_local_completion_host := TncLocalCompletionHost.create(
        ExtractFileDir(ParamStr(0)),
        procedure(const task: TncLocalCompletionTask;
            const completion_result: TncLongNeuralCompletionResult)
        begin
            handle_long_neural_completion(task, completion_result);
        end);
    m_char_lm_host := TncCharLmHost.Create(ExtractFileDir(ParamStr(0)), True);
    m_char_lm := m_char_lm_host;
    if m_local_completion_host <> nil then
    begin
        m_local_completion_host.set_char_lm(m_char_lm_host.background_view);
    end;
    m_one_key_rerank_host := TncOneKeyRerankHost.create(
        procedure(const task: TncOneKeyRerankTask; const chosen: Integer)
        begin
            handle_one_key_rerank(task, chosen);
        end);
    m_one_key_rerank_host.set_char_lm(m_char_lm_host.background_view);
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
    if m_local_completion_host <> nil then
    begin
        m_local_completion_host.Free;
        m_local_completion_host := nil;
    end;
    if m_one_key_rerank_host <> nil then
    begin
        m_one_key_rerank_host.Free;
        m_one_key_rerank_host := nil;
    end;
    if m_standby_session <> nil then
    begin
        m_standby_session.Free;
        m_standby_session := nil;
    end;
    if m_session_create_lock <> nil then
    begin
        m_session_create_lock.Free;
        m_session_create_lock := nil;
    end;
    FreeAndNil(m_input_epochs);
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
    m_long_neural_reranker := nil;
    // Sessions and the Tab worker are gone; release the last LM reference.
    m_char_lm_host := nil;
    m_char_lm := nil;
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
        if (m_config.punctuation_full_width <> next_config.punctuation_full_width) and
            host_log_enabled_for(ll_debug) then
            host_log_debug(Format(
                'punctuation_change source=config_reload previous=%d current=%d mode=%d shortcut_disabled=%d',
                [Ord(m_config.punctuation_full_width), Ord(next_config.punctuation_full_width),
                Ord(next_config.input_mode), Ord(next_config.shortcuts.punctuation_toggle.disabled)]));
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
    if m_standby_session <> nil then
    begin
        m_standby_session.update_config(config);
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
    adopted_standby: Boolean;
    instance_id: UInt64;
begin
    Result := nil;
    created_session := nil;
    instance_id := 0;
    m_lock.Acquire;
    try
        config_snapshot := m_config;
        if m_sessions.TryGetValue(session_id, Result) then
        begin
            Result.touch;
            Exit;
        end;
    finally
        m_lock.Release;
    end;

    // SET_ACTIVE and the first key can arrive on different pipe workers. Keep
    // cold engine construction single-flight so they never build and discard
    // duplicate dictionary/LM instances for the same session.
    m_session_create_lock.Acquire;
    try
        added_session := False;
        adopted_standby := False;

        m_lock.Acquire;
        try
            if m_sessions.TryGetValue(session_id, Result) then
            begin
                Result.touch;
                Exit;
            end;

            if m_standby_session <> nil then
            begin
                Result := m_standby_session;
                m_standby_session := nil;
                Result.adopt_session_id(session_id);
                sync_session_config_locked(Result);
                m_sessions.Add(session_id, Result);
                added_session := True;
                adopted_standby := True;
            end
            else
            begin
                config_snapshot := m_config;
                Inc(m_next_session_instance_id);
                instance_id := m_next_session_instance_id;
            end;
        finally
            m_lock.Release;
        end;

        if not added_session then
        begin
            created_session := TncHostSession.create(Self, session_id, instance_id,
                config_snapshot, True);
            m_lock.Acquire;
            try
                created_session.update_config(m_config);
                m_sessions.Add(session_id, created_session);
                Result := created_session;
                created_session := nil;
                added_session := True;
            finally
                m_lock.Release;
            end;
        end;

        Result.touch;
        if added_session and host_log_enabled_for(ll_info) then
        begin
            if adopted_standby then
            begin
                host_log('Dictionary standby adopted ' + Result.engine.get_dictionary_debug_info);
            end
            else
            begin
                host_log('Dictionary fast-start ' +
                    Result.engine.get_dictionary_debug_info);
            end;
        end;
    finally
        created_session.Free;
        m_session_create_lock.Release;
    end;

    if m_maintenance_wakeup <> nil then
    begin
        m_maintenance_wakeup.SetEvent;
    end;
end;

procedure TncEngineHost.set_session_active(const session_id: string; const active: Boolean);
var
    session: TncHostSession;
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
            m_last_user_activity_tick := GetTickCount64;
            if m_sessions.TryGetValue(session_id, session) then
            begin
                session.reactivate;
            end;
        end
        else
        begin
            if SameText(m_active_owner_session_id, session_id) then
            begin
                m_active_owner_session_id := '';
                m_active_sessions.Clear;
                m_recent_active_sessions.Clear;
            end
            else
            begin
                m_active_sessions.Remove(session_id);
                m_recent_active_sessions.Remove(session_id);
            end;
            if m_sessions.TryGetValue(session_id, session) then
            begin
                session.touch;
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
var
    session: TncHostSession;
begin
    if session_id = '' then
    begin
        Exit;
    end;
    if m_active_sessions.ContainsKey(session_id) then
    begin
        m_recent_active_sessions.AddOrSetValue(session_id, GetTickCount);
    end;
    if m_sessions.TryGetValue(session_id, session) then
    begin
        session.touch;
    end;
    m_last_user_activity_tick := GetTickCount64;
end;

procedure TncEngineHost.queue_session_prewarm(const session_id: string);
var
    session: TncHostSession;
begin
    if session_id = '' then
    begin
        Exit;
    end;

    m_lock.Acquire;
    try
        if (not m_sessions.TryGetValue(session_id, session)) or
            (not m_active_sessions.ContainsKey(session_id)) or session.release_requested then
        begin
            Exit;
        end;
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

procedure TncEngineHost.remove_session_prewarm_locked(const session_id: string);
var
    queue_count: Integer;
    queue_index: Integer;
    queued_session_id: string;
begin
    if (m_session_prewarm_queue <> nil) and (m_session_prewarm_queue.Count > 0) then
    begin
        queue_count := m_session_prewarm_queue.Count;
        for queue_index := 1 to queue_count do
        begin
            queued_session_id := m_session_prewarm_queue.Dequeue;
            if not SameText(queued_session_id, session_id) then
            begin
                m_session_prewarm_queue.Enqueue(queued_session_id);
            end;
        end;
    end;
    if m_session_prewarm_pending <> nil then
    begin
        m_session_prewarm_pending.Remove(session_id);
    end;
end;

function TncEngineHost.reclaim_session_on_ui_thread(const session_id: string; const instance_id: UInt64;
    const expected_activity_tick: UInt64; const reason: string): Boolean;
var
    reclaimed: Boolean;
    remaining_count: Integer;
begin
    reclaimed := False;
    remaining_count := 0;
    run_on_ui_thread(
        procedure
        var
            current_session: TncHostSession;
            extracted_pair: TPair<string, TncHostSession>;
            reclaimed_session: TncHostSession;
        begin
            m_lock.Acquire;
            try
                if (not m_sessions.TryGetValue(session_id, current_session)) or
                    (current_session.instance_id <> instance_id) or
                    (current_session.last_activity_tick <> expected_activity_tick) or
                    m_active_sessions.ContainsKey(session_id) then
                begin
                    Exit;
                end;

                extracted_pair := m_sessions.ExtractPair(session_id);
                reclaimed_session := extracted_pair.Value;
                m_active_sessions.Remove(session_id);
                m_recent_active_sessions.Remove(session_id);
                if SameText(m_active_owner_session_id, session_id) then
                begin
                    m_active_owner_session_id := '';
                end;
                remove_session_prewarm_locked(session_id);
                remaining_count := m_sessions.Count;
                reclaimed := reclaimed_session <> nil;
            finally
                m_lock.Release;
            end;

            reclaimed_session.Free;
        end);

    if reclaimed then
    begin
        host_log(Format('[INFO] session reclaimed session=%s reason=%s remaining=%d',
            [session_id, reason, remaining_count]));
    end;
    Result := reclaimed;
end;

procedure TncEngineHost.reclaim_inactive_sessions;
var
    session_pair: TPair<string, TncHostSession>;
    session: TncHostSession;
    candidate_session_id: string;
    candidate_instance_id: UInt64;
    candidate_activity_tick: UInt64;
    candidate_priority: Integer;
    priority: Integer;
    reason: string;
    candidate_reason: string;
    now_tick: UInt64;
    idle_ms: UInt64;
    over_capacity: Boolean;
begin
    while True do
    begin
        candidate_session_id := '';
        candidate_instance_id := 0;
        candidate_activity_tick := 0;
        candidate_priority := 0;
        candidate_reason := '';

        m_lock.Acquire;
        try
            now_tick := GetTickCount64;
            over_capacity := m_sessions.Count > c_session_cache_limit;
            for session_pair in m_sessions do
            begin
                session := session_pair.Value;
                if (session = nil) or m_active_sessions.ContainsKey(session_pair.Key) then
                begin
                    Continue;
                end;

                idle_ms := now_tick - session.last_activity_tick;
                priority := 0;
                reason := '';
                if session.release_requested and (idle_ms >= c_session_release_grace_ms) then
                begin
                    priority := 3;
                    reason := 'released';
                end
                else if idle_ms >= c_session_idle_reclaim_ms then
                begin
                    priority := 2;
                    reason := 'idle';
                end
                else if over_capacity and (idle_ms >= c_session_capacity_grace_ms) then
                begin
                    priority := 1;
                    reason := 'capacity';
                end;

                if (priority > candidate_priority) or
                    ((priority = candidate_priority) and (priority > 0) and
                    ((candidate_session_id = '') or (session.last_activity_tick < candidate_activity_tick))) then
                begin
                    candidate_session_id := session_pair.Key;
                    candidate_instance_id := session.instance_id;
                    candidate_activity_tick := session.last_activity_tick;
                    candidate_priority := priority;
                    candidate_reason := reason;
                end;
            end;
        finally
            m_lock.Release;
        end;

        if candidate_session_id = '' then
        begin
            Break;
        end;
        reclaim_session_on_ui_thread(candidate_session_id, candidate_instance_id,
            candidate_activity_tick, candidate_reason);
    end;
end;

procedure TncEngineHost.perform_session_prewarm;
var
    session_id: string;
    session: TncHostSession;
    warmed_session: TncHostSession;
    create_start_tick: UInt64;
    total_elapsed_ms: Int64;
    should_requeue: Boolean;
    instance_id: UInt64;
    refreshed_candidates: Boolean;
    upgraded_dictionary: Boolean;
    candidates_rebuilt: Boolean;
    refresh_generation: UInt64;
    candidates: TncCandidateList;
    one_key_completion: TncOneKeyCompletion;
    page_index: Integer;
    page_count: Integer;
    selected_index: Integer;
    preedit_text: string;
begin
    session_id := '';
    session := nil;
    warmed_session := nil;
    should_requeue := False;
    instance_id := 0;
    refreshed_candidates := False;
    upgraded_dictionary := False;
    refresh_generation := 0;

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

        if not m_session_create_lock.TryEnter then
        begin
            should_requeue := True;
            Exit;
        end;
        try
            if not m_lock.TryEnter then
            begin
                should_requeue := True;
                Exit;
            end;
            try
                if m_sessions.TryGetValue(session_id, session) and
                    m_active_sessions.ContainsKey(session_id) and
                    (not session.release_requested) then
                begin
                    instance_id := session.instance_id;
                    if session.engine.dictionary_models_deferred then
                    begin
                        if m_standby_session = nil then
                        begin
                            should_requeue := True;
                            Exit;
                        end;
                        if (session.engine.get_composition_text <> '') and
                            ((GetTickCount64 - session.last_activity_tick) <
                            c_dictionary_upgrade_idle_ms) then
                        begin
                            should_requeue := True;
                            Exit;
                        end;

                        warmed_session := m_standby_session;
                        m_standby_session := nil;
                        if not session.engine.try_upgrade_dictionary_from(
                            warmed_session.engine, candidates_rebuilt) then
                        begin
                            m_standby_session := warmed_session;
                            warmed_session := nil;
                            should_requeue := True;
                            Exit;
                        end;
                        upgraded_dictionary := True;

                        if candidates_rebuilt then
                        begin
                            prefetch_long_neural_completion(session);
                            candidates := session.engine.get_candidates;
                            one_key_completion :=
                                session.engine.get_one_key_completion;
                            page_index := session.engine.get_page_index;
                            page_count := session.engine.get_page_count;
                            selected_index := session.engine.get_selected_index;
                            preedit_text := session.engine.get_composition_text;
                            session.store_candidates(candidates, page_index,
                                page_count, selected_index, preedit_text,
                                one_key_completion);
                            refreshed_candidates := True;
                            refresh_generation := session.candidate_generation;
                        end;
                    end
                    else
                    begin
                        session.engine.reload_dictionary_if_needed;
                    end;
                end
                else
                begin
                    session := nil;
                end;
            finally
                m_lock.Release;
            end;
        finally
            m_session_create_lock.Release;
        end;

        total_elapsed_ms := Int64(GetTickCount64 - create_start_tick);
        if upgraded_dictionary and host_log_enabled_for(ll_info) then
        begin
            host_log(Format('Dictionary full model adopted session=%s total=%d',
                [session_id, total_elapsed_ms]));
        end;
        if refreshed_candidates then
        begin
            TThread.Queue(nil,
                procedure
                var
                    queued_session: TncHostSession;
                begin
                    m_lock.Acquire;
                    try
                        if (not m_sessions.TryGetValue(session_id,
                            queued_session)) or
                            (not m_active_sessions.ContainsKey(session_id)) or
                            (queued_session.instance_id <> instance_id) then
                        begin
                            Exit;
                        end;
                    finally
                        m_lock.Release;
                    end;
                    queued_session.apply_candidate_content_only(
                        refresh_generation);
                end);
        end;
        if session <> nil then
        begin
            TThread.Queue(nil,
                procedure
                var
                    queued_session: TncHostSession;
                begin
                    m_lock.Acquire;
                    try
                        if (not m_sessions.TryGetValue(session_id, queued_session)) or
                            (not m_active_sessions.ContainsKey(session_id)) or
                            (queued_session.instance_id <> instance_id) then
                        begin
                            Exit;
                        end;
                    finally
                        m_lock.Release;
                    end;
                    queued_session.warm_candidate_window;
                end);
        end;

        if host_log_enabled_for(ll_debug) then
        begin
            host_log_debug(Format(
                '[DEBUG] session prewarm session=%s upgraded=%d total=%d',
                [session_id, Ord(upgraded_dictionary), total_elapsed_ms]));
        end;
    finally
        warmed_session.Free;
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

procedure TncEngineHost.ensure_standby_session;
var
    config_snapshot: TncEngineConfig;
    created_session: TncHostSession;
    instance_id: UInt64;
    create_start_tick: UInt64;
    create_elapsed_ms: Int64;
    installed: Boolean;
begin
    if (m_session_create_lock = nil) or (m_lock = nil) then
    begin
        Exit;
    end;

    // Reserve the standby slot under the short creation lock, then release it
    // before opening SQLite and loading model tables. Foreground activation can
    // therefore create a deferred session instead of waiting for this work.
    if not m_session_create_lock.TryEnter then
    begin
        Exit;
    end;

    installed := False;
    create_start_tick := GetTickCount64;
    try
        m_lock.Acquire;
        try
            if m_standby_building or (m_standby_session <> nil) or
                (m_sessions.Count >= c_session_cache_limit) then
            begin
                Exit;
            end;
            if (m_last_user_activity_tick <> 0) and
                ((GetTickCount64 - m_last_user_activity_tick) <
                c_cold_start_foreground_grace_ms) then
            begin
                Exit;
            end;
            m_standby_building := True;
            config_snapshot := m_config;
            Inc(m_next_session_instance_id);
            instance_id := m_next_session_instance_id;
        finally
            m_lock.Release;
        end;
    finally
        m_session_create_lock.Release;
    end;

    try
        created_session := TncHostSession.create(Self, '', instance_id,
            config_snapshot, False);
        try
            m_session_create_lock.Acquire;
            try
                m_lock.Acquire;
                try
                    if (m_standby_session = nil) and
                        (m_sessions.Count < c_session_cache_limit) and
                        (m_config.dictionary_variant = config_snapshot.dictionary_variant) then
                    begin
                        created_session.update_config(m_config);
                        m_standby_session := created_session;
                        created_session := nil;
                        installed := True;
                    end;
                    m_standby_building := False;
                finally
                    m_lock.Release;
                end;
            finally
                m_session_create_lock.Release;
            end;
        finally
            created_session.Free;
        end;
    except
        m_lock.Acquire;
        try
            m_standby_building := False;
        finally
            m_lock.Release;
        end;
        raise;
    end;

    create_elapsed_ms := Int64(GetTickCount64 - create_start_tick);
    if installed and host_log_enabled_for(ll_debug) then
    begin
        host_log_debug(Format('[DEBUG] standby session ready create=%d',
            [create_elapsed_ms]));
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

    if key_state.ctrl_down or key_state.alt_down then
    begin
        if nc_shortcut_matches(m_config.shortcuts.input_mode_toggle, key_code, key_state) or
            nc_shortcut_matches(m_config.shortcuts.full_width_toggle, key_code, key_state) or
            nc_shortcut_matches(m_config.shortcuts.punctuation_toggle, key_code, key_state) then
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

procedure TncEngineHost.trim_input_epochs_locked;
const
    c_input_epoch_capacity = 1024;
begin
    // Floors of sessions with requests in flight are kept by the table itself.
    m_input_epochs.trim(c_input_epoch_capacity,
        function(live_session_id: string): Boolean
        begin
            Result := m_sessions.ContainsKey(live_session_id);
        end);
end;

function TncEngineHost.admit_input_epoch_locked(const session_id: string; const input_epoch: UInt64;
    const command: string): TncInputEpochDecision;
begin
    Result := m_input_epochs.admit(session_id, input_epoch);
    if Result = ied_stale then
    begin
        host_log_at(ll_warn, Format('[WARN] dropped late %s session=%s epoch=%s floor=%s',
            [command, session_id, UIntToStr(input_epoch), UIntToStr(m_input_epochs.floor(session_id))]));
    end
    else if Result = ied_advanced then
    begin
        trim_input_epochs_locked;
    end;
end;

function TncEngineHost.admit_reset_locked(const session_id: string; const input_epoch: UInt64): Boolean;
var
    stale: Boolean;
begin
    Result := m_input_epochs.admit_reset(session_id, input_epoch, stale);
    if stale then
    begin
        host_log_at(ll_warn, Format('[WARN] dropped late RESET session=%s epoch=%s floor=%s',
            [session_id, UIntToStr(input_epoch), UIntToStr(m_input_epochs.floor(session_id))]));
    end
    else if Result and (input_epoch <> 0) then
    begin
        trim_input_epochs_locked;
    end;
end;

function TncEngineHost.process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
    out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
    out full_width_mode: Boolean; out punctuation_full_width: Boolean;
    const input_epoch: UInt64): Boolean;
begin
    // Registered before config reload and session creation, where a request
    // can stall past its client timeout, so its epoch floor is not trimmed.
    m_input_epochs.enter(session_id);
    try
        Result := process_key_admitted(session_id, key_code, key_state, handled, commit_text,
            display_text, input_mode, full_width_mode, punctuation_full_width, input_epoch);
    finally
        m_input_epochs.leave(session_id);
    end;
end;

function TncEngineHost.process_key_admitted(const session_id: string; const key_code: Word;
    const key_state: TncKeyState; out handled: Boolean; out commit_text: string; out display_text: string;
    out input_mode: TncInputMode; out full_width_mode: Boolean; out punctuation_full_width: Boolean;
    const input_epoch: UInt64): Boolean;
const
    c_slow_host_process_key_ms = 12;
var
    session: TncHostSession;
    candidates: TncCandidateList;
    one_key_completion: TncOneKeyCompletion;
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
    caret_point: TPoint;
    has_caret: Boolean;
    caret_line_height: Integer;
    candidate_terminal_like_target: Boolean;
    candidate_comless_target: Boolean;
    candidate_source: TncCaretAnchorSource;
    candidate_score: Integer;
    queue_candidate_apply: Boolean;
    queue_candidate_content_update: Boolean;
    candidate_content_generation: UInt64;
    has_candidate_anchor: Boolean;
    session_instance_id: UInt64;
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
        if nc_shortcut_matches(m_config.shortcuts.input_mode_toggle, key_code, key_state) or
            nc_shortcut_matches(m_config.shortcuts.full_width_toggle, key_code, key_state) or
            nc_shortcut_matches(m_config.shortcuts.punctuation_toggle, key_code, key_state) then
        begin
            // fall through
        end
        else
        begin
            // A rejected modifier chord still has to return the current mode
            // state. Leaving the out parameters at their defaults makes the
            // TSF side write "Chinese / half-width / English punctuation"
            // back to the compartments merely because Ctrl was pressed.
            m_lock.Acquire;
            try
                input_mode := m_config.input_mode;
                full_width_mode := m_config.full_width_mode;
                punctuation_full_width := m_config.punctuation_full_width;
            finally
                m_lock.Release;
            end;
            Result := True;
            Exit;
        end;
    end;

    session := get_or_create_session(session_id);
    session_instance_id := session.instance_id;
    should_hide_candidates := False;
    has_result := True;
    debug_logging := host_log_enabled_for(ll_debug);
    total_start_tick := GetTickCount64;
    readback_elapsed_ms := 0;
    total_elapsed_ms := 0;
    lookup_perf_info := '';
    caret_point := Point(0, 0);
    queue_candidate_apply := False;
    queue_candidate_content_update := False;
    candidate_content_generation := 0;
    m_lock.Acquire;
    try
        // Decide under the lock that also serializes RESET, right before the
        // engine changes: earlier stages (config reload, session creation) may
        // have stalled this request past the client's timeout and its RESET.
        case admit_input_epoch_locked(session_id, input_epoch, 'PROCESS_KEY') of
            ied_stale:
                begin
                    input_mode := m_config.input_mode;
                    full_width_mode := m_config.full_width_mode;
                    punctuation_full_width := m_config.punctuation_full_width;
                    Result := False;
                    Exit;
                end;
            ied_advanced:
                begin
                    // The client started a new epoch; its RESET may be lost.
                    session.engine.reset(True);
                    session.clear_candidates;
                end;
        end;
        touch_session_activity(session_id);
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
            readback_start_tick := GetTickCount64;
            prefetch_long_neural_completion(session);
            candidates := session.engine.get_candidates;
            one_key_completion := session.engine.get_one_key_completion;
            display_text := session.engine.get_display_text;
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

            if debug_logging then
            begin
                host_log_debug(Format('engine key=%d handled=%d commit=[%s] display=[%s] comp=[%s] confirmed=%d candidates=%d page=%d/%d selected=%d %s',
                    [key_code, Ord(handled), sanitize_log_text(commit_text), sanitize_log_text(display_text),
                    sanitize_log_text(preedit_text), session.engine.get_confirmed_length, Length(candidates),
                    page_index + 1, page_count, selected_index + 1, sanitize_log_text(lookup_debug_info)]));
            end;

            if (Length(candidates) = 0) and
                (one_key_completion.text = '') then
            begin
                session.clear_candidates;
                should_hide_candidates := True;
            end
            else
            begin
                session.store_candidates(candidates, page_index, page_count,
                    selected_index, preedit_text, one_key_completion);
                caret_point := session.last_caret;
                has_caret := session.has_caret;
                caret_line_height := session.caret_line_height;
                candidate_terminal_like_target := session.m_terminal_like_target;
                candidate_comless_target := session.m_comless_target;
                candidate_source := session.m_last_candidate_source;
                candidate_score := session.m_last_candidate_score;
                has_candidate_anchor := has_caret or (caret_point.X <> 0) or (caret_point.Y <> 0);
                if has_candidate_anchor and session.needs_candidate_refresh(caret_point, has_caret, caret_line_height,
                    candidate_terminal_like_target, candidate_comless_target) then
                begin
                    session.stage_candidate_apply(caret_point, has_caret, caret_line_height,
                        candidate_terminal_like_target, candidate_comless_target,
                        candidate_source, candidate_score, queue_candidate_apply);
                end;
                if (not has_candidate_anchor) and session.has_dirty_candidates then
                begin
                    queue_candidate_content_update := True;
                    candidate_content_generation := session.candidate_generation;
                end;
            end;
        end;

        if handled and (commit_text = '') then
        begin
            readback_start_tick := GetTickCount64;
            prefetch_long_neural_completion(session);
            candidates := session.engine.get_candidates;
            one_key_completion := session.engine.get_one_key_completion;
            display_text := session.engine.get_display_text;
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

            if (Length(candidates) = 0) and
                (one_key_completion.text = '') then
            begin
                session.clear_candidates;
                should_hide_candidates := True;
            end
            else
            begin
                session.store_candidates(candidates, page_index, page_count,
                    selected_index, preedit_text, one_key_completion);
                caret_point := session.last_caret;
                has_caret := session.has_caret;
                caret_line_height := session.caret_line_height;
                candidate_terminal_like_target := session.m_terminal_like_target;
                candidate_comless_target := session.m_comless_target;
                candidate_source := session.m_last_candidate_source;
                candidate_score := session.m_last_candidate_score;
                has_candidate_anchor := has_caret or (caret_point.X <> 0) or (caret_point.Y <> 0);
                if has_candidate_anchor and session.needs_candidate_refresh(caret_point, has_caret, caret_line_height,
                    candidate_terminal_like_target, candidate_comless_target) then
                begin
                    session.stage_candidate_apply(caret_point, has_caret, caret_line_height,
                        candidate_terminal_like_target, candidate_comless_target,
                        candidate_source, candidate_score, queue_candidate_apply);
                end;
                if (not has_candidate_anchor) and session.has_dirty_candidates then
                begin
                    queue_candidate_content_update := True;
                    candidate_content_generation := session.candidate_generation;
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
            var
                queued_session: TncHostSession;
            begin
                m_lock.Acquire;
                try
                    if (not m_sessions.TryGetValue(session_id, queued_session)) or
                        (queued_session.instance_id <> session_instance_id) then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.hide_candidate_window;
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
                queued_comless_target: Boolean;
                queued_source: TncCaretAnchorSource;
                queued_score: Integer;
                queued_generation: UInt64;
            begin
                m_lock.Acquire;
                try
                    if not m_sessions.TryGetValue(session_id, queued_session) then
                    begin
                        Exit;
                    end;
                    if queued_session.instance_id <> session_instance_id then
                    begin
                        Exit;
                    end;
                    if not queued_session.consume_pending_candidate_apply(queued_point, queued_has_caret,
                        queued_line_height, queued_terminal_like_target, queued_comless_target,
                        queued_source, queued_score,
                        queued_generation) then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.apply_candidate_state(queued_point, queued_has_caret, queued_line_height,
                    queued_terminal_like_target, queued_comless_target,
                    queued_source, queued_score, queued_generation);
            end);
    end;
    if queue_candidate_content_update and (not queue_candidate_apply) then
    begin
        TThread.Queue(nil,
            procedure
            var
                queued_session: TncHostSession;
            begin
                m_lock.Acquire;
                try
                    if not m_sessions.TryGetValue(session_id, queued_session) then
                    begin
                        Exit;
                    end;
                    if queued_session.instance_id <> session_instance_id then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.apply_candidate_content_only(candidate_content_generation);
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

function TncEngineHost.get_shortcut_config(const session_id: string;
    out shortcut_config: TncShortcutConfig): Boolean;
begin
    shortcut_config := nc_default_shortcut_config;
    if session_id = '' then
    begin
        Exit(False);
    end;

    reload_config_if_needed;
    m_lock.Acquire;
    try
        shortcut_config := m_config.shortcuts;
    finally
        m_lock.Release;
    end;
    nc_normalize_shortcut_config(shortcut_config);
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
    const punctuation_full_width: Boolean; const state_source: string): Boolean;
var
    session: TncHostSession;
    iter_session: TncHostSession;
    next_config: TncEngineConfig;
    input_mode_changed: Boolean;
    global_state_changed: Boolean;
    global_input_mode_changed: Boolean;
    config_to_save: TncEngineConfig;
    sessions_to_hide: TList<TncHostSessionRef>;
    session_ref: TncHostSessionRef;
begin
    Result := False;
    if session_id = '' then
    begin
        Exit;
    end;

    sessions_to_hide := nil;
    try
        sessions_to_hide := TList<TncHostSessionRef>.Create;
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
                session_ref.session_id := session.m_session_id;
                session_ref.instance_id := session.instance_id;
                sessions_to_hide.Add(session_ref);
            end;

            global_state_changed := (m_config.input_mode <> input_mode) or (m_config.full_width_mode <> full_width_mode) or
                (m_config.punctuation_full_width <> punctuation_full_width);
            if global_state_changed then
            begin
                if (m_config.punctuation_full_width <> punctuation_full_width) and
                    host_log_enabled_for(ll_debug) then
                    host_log_debug(Format(
                        'punctuation_change session=%s source=%s previous=%d current=%d mode=%d shortcut_disabled=%d',
                        [session_id, state_source, Ord(m_config.punctuation_full_width),
                        Ord(punctuation_full_width), Ord(input_mode),
                        Ord(m_config.shortcuts.punctuation_toggle.disabled)]));
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
                        session_ref.session_id := iter_session.m_session_id;
                        session_ref.instance_id := iter_session.instance_id;
                        sessions_to_hide.Add(session_ref);
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
                    hide_ref: TncHostSessionRef;
                    hide_session: TncHostSession;
                begin
                    for hide_ref in sessions_to_hide do
                    begin
                        m_lock.Acquire;
                        try
                            if (not m_sessions.TryGetValue(hide_ref.session_id, hide_session)) or
                                (hide_session.instance_id <> hide_ref.instance_id) then
                            begin
                                Continue;
                            end;
                        finally
                            m_lock.Release;
                        end;
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
    sessions_to_hide: TList<TncHostSessionRef>;
    session_ref: TncHostSessionRef;
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
        sessions_to_hide := TList<TncHostSessionRef>.Create;
        reload_config_if_needed;
        session := get_or_create_session(session_id);
        m_lock.Acquire;
        try
            global_variant_changed := m_config.dictionary_variant <> dictionary_variant;
            if global_variant_changed then
            begin
                m_config.dictionary_variant := dictionary_variant;
                sync_start_tick := GetTickCount64;
                // Keep the dictionary-variant shortcut responsive: only the current foreground
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
                    session_ref.session_id := iter_session.m_session_id;
                    session_ref.instance_id := iter_session.instance_id;
                    sessions_to_hide.Add(session_ref);
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
                    hide_ref: TncHostSessionRef;
                    hide_session: TncHostSession;
                begin
                    for hide_ref in sessions_to_hide do
                    begin
                        m_lock.Acquire;
                        try
                            if (not m_sessions.TryGetValue(hide_ref.session_id, hide_session)) or
                                (hide_session.instance_id <> hide_ref.instance_id) then
                            begin
                                Continue;
                            end;
                        finally
                            m_lock.Release;
                        end;
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
    session_instance_id: UInt64;
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
        session_instance_id := session.instance_id;
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
    end;

    set_session_active(session_id, active);
    if active then
    begin
        // Candidate-window/VCL initialization is independent from dictionary
        // model loading. Queue it immediately so a first key only has to paint
        // content, even when the full ranking model is still warming.
        TThread.Queue(nil,
            procedure
            var
                queued_session: TncHostSession;
            begin
                m_lock.Acquire;
                try
                    if (not m_sessions.TryGetValue(session_id,
                        queued_session)) or
                        (not m_active_sessions.ContainsKey(session_id)) or
                        (queued_session.instance_id <> session_instance_id) then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.warm_candidate_window;
            end);
        queue_session_prewarm(session_id);
    end;
    Result := True;
end;

function TncEngineHost.release_session(const session_id: string): Boolean;
var
    session: TncHostSession;
begin
    Result := False;
    if session_id = '' then
    begin
        Exit;
    end;

    set_session_active(session_id, False);
    m_lock.Acquire;
    try
        if m_sessions.TryGetValue(session_id, session) then
        begin
            session.request_release;
            remove_session_prewarm_locked(session_id);
        end;
        Result := True;
    finally
        m_lock.Release;
    end;

    if m_maintenance_wakeup <> nil then
    begin
        m_maintenance_wakeup.SetEvent;
    end;
end;

function TncEngineHost.reload_config_now: Boolean;
begin
    Result := reload_config(True);
end;

function TncEngineHost.clear_user_dictionary(const session_id: string): Boolean;
var
    initiating_session: TncHostSession;
    current_session: TncHostSession;
    sessions_to_hide: TArray<TncHostSessionRef>;
    session_index: Integer;
begin
    Result := False;
    if session_id = '' then
    begin
        Exit;
    end;

    initiating_session := get_or_create_session(session_id);
    SetLength(sessions_to_hide, 0);
    m_lock.Acquire;
    try
        if (initiating_session = nil) or
            (not m_sessions.TryGetValue(session_id, initiating_session)) then
        begin
            Exit;
        end;

        Result := initiating_session.engine.clear_user_dictionary;
        if not Result then
        begin
            Exit;
        end;

        SetLength(sessions_to_hide, m_sessions.Count);
        session_index := 0;
        for current_session in m_sessions.Values do
        begin
            if current_session <> initiating_session then
            begin
                current_session.engine.notify_user_dictionary_cleared;
            end;
            current_session.clear_candidates;
            sessions_to_hide[session_index].session_id := current_session.m_session_id;
            sessions_to_hide[session_index].instance_id := current_session.instance_id;
            Inc(session_index);
        end;
        m_last_user_activity_tick := GetTickCount64;
    finally
        m_lock.Release;
    end;

    host_log('[INFO] user dictionary cleared');
    run_on_ui_thread(
        procedure
        var
            hide_index: Integer;
            hide_session: TncHostSession;
        begin
            for hide_index := 0 to High(sessions_to_hide) do
            begin
                m_lock.Acquire;
                try
                    if (not m_sessions.TryGetValue(sessions_to_hide[hide_index].session_id, hide_session)) or
                        (hide_session.instance_id <> sessions_to_hide[hide_index].instance_id) then
                    begin
                        Continue;
                    end;
                finally
                    m_lock.Release;
                end;
                if hide_session <> nil then
                begin
                    hide_session.hide_candidate_window;
                end;
            end;
        end);
end;

procedure TncEngineHost.update_caret(const session_id: string; const point: TPoint; const has_caret: Boolean;
    const line_height: Integer; const terminal_like_target: Boolean; const comless_target: Boolean;
    const source: TncCaretAnchorSource; const anchor_score: Integer);
var
    session: TncHostSession;
    should_apply: Boolean;
    should_queue: Boolean;
    session_instance_id: UInt64;
begin
    should_queue := False;
    session_instance_id := 0;
    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        session_instance_id := session.instance_id;
        should_apply := session.has_candidates and
            session.needs_candidate_refresh(point, has_caret, line_height,
            terminal_like_target, comless_target);
        session.set_caret(point, has_caret, line_height, terminal_like_target,
            comless_target);
        if should_apply then
        begin
            session.stage_candidate_apply(point, has_caret, line_height,
                terminal_like_target, comless_target, source, anchor_score, should_queue);
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
                queued_comless_target: Boolean;
                queued_source: TncCaretAnchorSource;
                queued_score: Integer;
                queued_generation: UInt64;
            begin
                m_lock.Acquire;
                try
                    if not m_sessions.TryGetValue(session_id, queued_session) then
                    begin
                        Exit;
                    end;
                    if queued_session.instance_id <> session_instance_id then
                    begin
                        Exit;
                    end;
                    if not queued_session.consume_pending_candidate_apply(queued_point, queued_has_caret,
                        queued_line_height, queued_terminal_like_target, queued_comless_target,
                        queued_source, queued_score,
                        queued_generation) then
                    begin
                        Exit;
                    end;
                finally
                    m_lock.Release;
                end;
                queued_session.apply_candidate_state(queued_point, queued_has_caret, queued_line_height,
                    queued_terminal_like_target, queued_comless_target,
                    queued_source, queued_score, queued_generation);
            end);
    end;
end;

procedure TncEngineHost.update_surrounding(const session_id: string;
    const left_context: string; const document_key: string;
    const document_snapshot: string);
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
        session.engine.set_external_left_context(left_context, document_key,
            document_snapshot);
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
    one_key_completion: TncOneKeyCompletion;
    page_index: Integer;
    page_count: Integer;
    selected_index: Integer;
    preedit_text: string;
    should_refresh: Boolean;
    should_hide: Boolean;
    caret_point: TPoint;
    has_caret: Boolean;
    refresh_generation: UInt64;
    preserved_candidate: TncCandidate;
    preserve_candidate_after_remove: Boolean;
    preserved_selected_index: Integer;
    session_instance_id: UInt64;

    function candidate_has_pinyin_tail(const candidate: TncCandidate): Boolean;
    var
        text_value: string;
        idx: Integer;
        has_tail: Boolean;
    begin
        Result := False;
        if Trim(candidate.comment) <> '' then
        begin
            Result := True;
            Exit;
        end;

        text_value := Trim(candidate.text);
        if text_value = '' then
        begin
            Exit;
        end;

        has_tail := False;
        idx := Length(text_value);
        while idx > 0 do
        begin
            if not CharInSet(text_value[idx], ['a' .. 'z', 'A' .. 'Z']) then
            begin
                Break;
            end;
            has_tail := True;
            Dec(idx);
        end;

        Result := has_tail and (idx > 0);
    end;

    function candidate_can_remove(const candidate: TncCandidate): Boolean;
    begin
        Result := (candidate.source = cs_user) and (Trim(candidate.text) <> '') and
            (not candidate_has_pinyin_tail(candidate));
    end;
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
    refresh_generation := 0;
    preserved_candidate.text := '';
    preserved_candidate.comment := '';
    preserved_candidate.score := 0;
    preserved_candidate.source := cs_rule;
    preserved_candidate.has_dict_weight := False;
    preserved_candidate.dict_weight := 0;
    preserved_candidate.fuzzy_cost := 0;
    preserved_candidate.fuzzy_rules := [];
    session := nil;
    session_instance_id := 0;

    m_lock.Acquire;
    try
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        session_instance_id := session.instance_id;

        if (candidate_index < 0) or (candidate_index >= Length(session.m_candidates)) then
        begin
            host_log_debug(Format('[DEBUG] remove user candidate skipped: index out of range count=%d',
                [Length(session.m_candidates)]));
            Exit;
        end;

        if not candidate_can_remove(session.m_candidates[candidate_index]) then
        begin
            host_log_debug('[DEBUG] remove user candidate skipped: candidate is not removable');
            Exit;
        end;

        candidate_text := session.m_candidates[candidate_index].text;
        preserve_candidate_after_remove := False;
        preserved_selected_index := session.m_selected_index;
        if (preserved_selected_index < 0) or (preserved_selected_index >= Length(session.m_candidates)) then
        begin
            preserved_selected_index := 0;
        end;
        if (preserved_selected_index >= 0) and (preserved_selected_index < Length(session.m_candidates)) and
            (preserved_selected_index <> candidate_index) then
        begin
            preserved_candidate := session.m_candidates[preserved_selected_index];
            preserve_candidate_after_remove := (Trim(preserved_candidate.text) <> '') and
                (not SameText(Trim(preserved_candidate.text), Trim(candidate_text)));
        end;

        pinyin_key := session.engine.get_last_lookup_key;
        if pinyin_key = '' then
        begin
            pinyin_key := session.m_preedit_text;
        end;
        if pinyin_key = '' then
        begin
            pinyin_key := session.engine.get_composition_text;
        end;

        if not session.engine.remove_user_candidate(pinyin_key, candidate_text, preserved_candidate,
            preserve_candidate_after_remove) then
        begin
            host_log('[WARN] remove user candidate failed in engine');
            Exit;
        end;

        host_log(Format('[INFO] removed user candidate text=%s pinyin=%s', [candidate_text, pinyin_key]));

        prefetch_long_neural_completion(session);
        candidates := session.engine.get_candidates;
        one_key_completion := session.engine.get_one_key_completion;
        page_index := session.engine.get_page_index;
        page_count := session.engine.get_page_count;
        selected_index := session.engine.get_selected_index;
        preedit_text := session.engine.get_composition_text;
        if (Length(candidates) = 0) and
            (one_key_completion.text = '') then
        begin
            session.clear_candidates;
            should_hide := True;
        end
        else
        begin
            session.store_candidates(candidates, page_index, page_count,
                selected_index, preedit_text, one_key_completion);
            refresh_generation := session.candidate_generation;
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
        var
            queued_session: TncHostSession;
        begin
            m_lock.Acquire;
            try
                if (not m_sessions.TryGetValue(session_id, queued_session)) or
                    (queued_session.instance_id <> session_instance_id) then
                begin
                    Exit;
                end;
            finally
                m_lock.Release;
            end;
            if should_hide then
            begin
                queued_session.hide_candidate_window;
            end
            else
            begin
                queued_session.apply_candidate_state(caret_point, has_caret, queued_session.caret_line_height,
                    queued_session.m_terminal_like_target, queued_session.m_comless_target,
                    queued_session.m_last_candidate_source,
                    queued_session.m_last_candidate_score, refresh_generation);
            end;
        end);
end;

procedure TncEngineHost.reset_session(const session_id: string;
    const preserve_document_context: Boolean; const input_epoch: UInt64);
begin
    m_input_epochs.enter(session_id);
    try
        reset_session_admitted(session_id, preserve_document_context, input_epoch);
    finally
        m_input_epochs.leave(session_id);
    end;
end;

procedure TncEngineHost.reset_session_admitted(const session_id: string;
    const preserve_document_context: Boolean; const input_epoch: UInt64);
var
    session: TncHostSession;
    session_instance_id: UInt64;
begin
    session_instance_id := 0;
    m_lock.Acquire;
    try
        // Recorded even when the session does not exist yet, so a PROCESS_KEY
        // still creating it cannot apply its older key afterwards. A RESET
        // resets only when it opens its epoch: a late copy of an older epoch,
        // or one whose epoch its first key already opened, must not wipe input.
        if not admit_reset_locked(session_id, input_epoch) then
        begin
            Exit;
        end;
        if not m_sessions.TryGetValue(session_id, session) then
        begin
            Exit;
        end;
        session_instance_id := session.instance_id;
        session.engine.reset(preserve_document_context);
        session.set_caret(Point(0, 0), False, 0, False, False);
        session.clear_candidates;
    finally
        m_lock.Release;
    end;

    run_on_ui_thread(
        procedure
        var
            queued_session: TncHostSession;
        begin
            m_lock.Acquire;
            try
                if (not m_sessions.TryGetValue(session_id, queued_session)) or
                    (queued_session.instance_id <> session_instance_id) then
                begin
                    Exit;
                end;
            finally
                m_lock.Release;
            end;
            queued_session.hide_candidate_window;
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
    // TThread starts from AfterConstruction when Create(False) is used, so
    // these fields are initialized before Execute can run. Calling Start from
    // inside this constructor bypasses that RTL lifecycle and fails on some
    // Windows/Delphi runtime combinations.
    inherited create(False);
    FreeOnTerminate := False;
    m_host := host;
    Priority := tpLower;
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
            host.ensure_standby_session;
            host.perform_session_prewarm;
            host.reclaim_inactive_sessions;
            host.maybe_checkpoint_user_dictionary;
        except
            on e: Exception do
            begin
                host_log(Format('[WARN] maintenance exception %s: %s', [e.ClassName, e.Message]));
            end;
        end;
    end;
end;

// Optional trailing field; absent or malformed means a client without epochs.
function parse_input_epoch(const value: string): UInt64;
var
    parsed: Int64;
begin
    parsed := StrToInt64Def(Trim(value), 0);
    if parsed < 0 then
    begin
        parsed := 0;
    end;
    Result := UInt64(parsed);
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
    caret_comless_target: Boolean;
    caret_source_value: Integer;
    caret_source: TncCaretAnchorSource;
    caret_score: Integer;
    active_flag: Boolean;
    shortcut_config: TncShortcutConfig;
    state_source: string;
    input_epoch: UInt64;
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

        if SameText(cmd, 'RESET') or
            SameText(cmd, 'RESET_KEEP_DOCUMENT') then
        begin
            input_epoch := 0;
            if Length(fields) >= 3 then
            begin
                input_epoch := parse_input_epoch(fields[2]);
            end;
            m_host.reset_session(session_id,
                SameText(cmd, 'RESET_KEEP_DOCUMENT'), input_epoch);
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
            caret_comless_target := False;
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
            if Length(fields) >= 10 then
            begin
                caret_comless_target := flag_to_bool(fields[9]);
            end;

            m_host.update_caret(session_id, Point(x, y), has_caret,
                line_height, caret_terminal_like_target, caret_comless_target,
                caret_source, caret_score);
            Result := 'OK';
            Exit;
        end;

        if SameText(cmd, 'SET_SURROUNDING') then
        begin
            if Length(fields) >= 5 then
            begin
                m_host.update_surrounding(session_id,
                    decode_ipc_text(fields[3]), decode_ipc_text(fields[2]),
                    decode_ipc_text(fields[4]));
            end
            else if Length(fields) >= 4 then
            begin
                m_host.update_surrounding(session_id,
                    decode_ipc_text(fields[3]), decode_ipc_text(fields[2]));
            end
            else if Length(fields) >= 3 then
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

        if SameText(cmd, 'CLEAR_USER_DICTIONARY') then
        begin
            if m_host.clear_user_dictionary(session_id) then
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

        if SameText(cmd, 'GET_SHORTCUTS') then
        begin
            if m_host.get_shortcut_config(session_id, shortcut_config) then
            begin
                Result := 'OK'#9 +
                    nc_shortcut_to_text(shortcut_config.input_mode_toggle) + #9 +
                    nc_shortcut_to_text(shortcut_config.punctuation_toggle) + #9 +
                    nc_shortcut_to_text(shortcut_config.dictionary_variant_toggle) + #9 +
                    nc_shortcut_to_text(shortcut_config.full_width_toggle) + #9 +
                    nc_shortcut_to_text(shortcut_config.open_settings);
                if host_log_enabled_for(ll_debug) then
                begin
                    host_log_debug(Format(
                        'shortcut_config session=%s input_mode=%s',
                        [session_id,
                        nc_shortcut_to_text(shortcut_config.input_mode_toggle)]));
                end;
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

        if SameText(cmd, 'RELEASE_SESSION') then
        begin
            if Length(fields) < 2 then
            begin
                Result := 'ERROR'#9'bad_args';
                Exit;
            end;
            if m_host.release_session(session_id) then
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
            state_source := '';
            if Length(fields) >= 6 then
            begin
                state_source := decode_ipc_text(fields[5]);
            end;
            if host_log_enabled_for(ll_debug) then
            begin
                host_log_debug(Format(
                    'set_state session=%s mode=%d full=%d punctuation=%d source=%s',
                    [session_id, Ord(input_mode), Ord(full_width_mode),
                    Ord(punctuation_full_width), state_source]));
            end;
            if m_host.set_state(session_id, input_mode, full_width_mode,
                punctuation_full_width, state_source) then
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
            input_epoch := 0;
            if Length(fields) >= 8 then
            begin
                input_epoch := parse_input_epoch(fields[7]);
            end;
            if host_log_enabled_for(ll_debug) then
            begin
                host_log_debug(Format('process_key session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
                    [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down),
                    Ord(key_state.alt_down), Ord(key_state.caps_lock)]));
            end;
            if m_host.process_key(session_id, Word(key_code), key_state, handled, commit_text, display_text, input_mode,
                full_width_mode, punctuation_full_width, input_epoch) then
            begin
                if host_log_enabled_for(ll_debug) then
                begin
                    host_log_debug(Format(
                        'process_key result session=%s handled=%d mode=%d full=%d punctuation=%d',
                        [session_id, Ord(handled), Ord(input_mode),
                        Ord(full_width_mode), Ord(punctuation_full_width)]));
                end;
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

type
    TncPipeIoResult = (pio_completed, pio_failed, pio_timed_out);

const
    // Clients send one short request right after connecting and close their
    // handle as soon as the reply is read (CallNamedPipe). Windows suspends
    // shell and AppContainer clients (SearchHost, TextInputHost, UWP apps)
    // at arbitrary points, so no worker may wait on a client without a bound.
    c_pipe_request_timeout_ms = 1000;
    c_pipe_reply_timeout_ms = 1000;
    c_pipe_drain_timeout_ms = 1000;
    c_pipe_connect_poll_ms = 250;
    c_pipe_slow_request_ms = 1000;
    c_process_query_limited_information = $1000;

function query_full_process_image_name(process: THandle; flags: DWORD; exe_name: PWideChar;
    var size: DWORD): BOOL; stdcall; external kernel32 name 'QueryFullProcessImageNameW';

// Completes an overlapped pipe call. On timeout the operation is cancelled
// and its completion awaited, so the caller's buffers can be released.
function finish_pipe_io(const pipe_handle: THandle; var overlapped: TOverlapped;
    const call_ok: Boolean; const timeout_ms: DWORD; out bytes: DWORD; out err: DWORD): TncPipeIoResult;
begin
    bytes := 0;
    err := ERROR_SUCCESS;
    if not call_ok then
    begin
        err := GetLastError;
        if err <> ERROR_IO_PENDING then
        begin
            Exit(pio_failed);
        end;
    end;
    if WaitForSingleObject(overlapped.hEvent, timeout_ms) <> WAIT_OBJECT_0 then
    begin
        CancelIoEx(pipe_handle, @overlapped);
        if GetOverlappedResult(pipe_handle, overlapped, bytes, True) then
        begin
            // Completed just before the cancellation took effect.
            Exit(pio_completed);
        end;
        err := GetLastError;
        if err = ERROR_OPERATION_ABORTED then
        begin
            err := ERROR_TIMEOUT;
            Exit(pio_timed_out);
        end;
        Exit(pio_failed);
    end;
    if GetOverlappedResult(pipe_handle, overlapped, bytes, False) then
    begin
        Exit(pio_completed);
    end;
    err := GetLastError;
    Result := pio_failed;
end;

function describe_pipe_client(const pipe_handle: THandle): string;
var
    process_id: ULONG;
    process_handle: THandle;
    image_path: array[0..MAX_PATH - 1] of WideChar;
    image_length: DWORD;
    image_name: string;
begin
    process_id := 0;
    try
        if not GetNamedPipeClientProcessId(pipe_handle, process_id) then
        begin
            Exit('client=unknown');
        end;
    except
        Exit('client=unknown');
    end;
    image_name := '?';
    process_handle := OpenProcess(c_process_query_limited_information, False, process_id);
    if process_handle <> 0 then
    begin
        try
            image_length := Length(image_path);
            if query_full_process_image_name(process_handle, 0, @image_path[0], image_length) then
            begin
                SetString(image_name, PWideChar(@image_path[0]), image_length);
                image_name := ExtractFileName(image_name);
            end;
        finally
            CloseHandle(process_handle);
        end;
    end;
    Result := Format('client_pid=%d client=%s', [process_id, image_name]);
end;

// Only the command name is logged; requests carry typed text and context.
function pipe_request_command(const request_text: string): string;
var
    separator: Integer;
begin
    separator := Pos(#9, request_text);
    if separator > 0 then
    begin
        Result := Copy(request_text, 1, separator - 1);
    end
    else
    begin
        Result := Copy(request_text, 1, 32);
    end;
    if Length(Result) > 32 then
    begin
        Result := Copy(Result, 1, 32);
    end;
end;

function TncPipeServerThread.wait_for_client(const pipe_handle: THandle; const io_event: THandle): Boolean;
var
    overlapped: TOverlapped;
    bytes: DWORD;
    err: DWORD;
begin
    FillChar(overlapped, SizeOf(overlapped), 0);
    overlapped.hEvent := io_event;
    if ConnectNamedPipe(pipe_handle, @overlapped) then
    begin
        Exit(True);
    end;
    err := GetLastError;
    if err = ERROR_PIPE_CONNECTED then
    begin
        Exit(True);
    end;
    if err <> ERROR_IO_PENDING then
    begin
        host_log(Format('ConnectNamedPipe failed err=%d', [err]));
        Exit(False);
    end;
    // Idle workers poll Terminated, so shutdown no longer depends on a wake-up
    // connection reaching every worker.
    while WaitForSingleObject(io_event, c_pipe_connect_poll_ms) <> WAIT_OBJECT_0 do
    begin
        if Terminated then
        begin
            CancelIoEx(pipe_handle, @overlapped);
            GetOverlappedResult(pipe_handle, overlapped, bytes, True);
            Exit(False);
        end;
    end;
    Result := GetOverlappedResult(pipe_handle, overlapped, bytes, False);
    if not Result then
    begin
        host_log(Format('ConnectNamedPipe failed err=%d', [GetLastError]));
    end;
end;

// Returns False when the client stalled while its reply was pending; the
// caller then closes without DisconnectNamedPipe, which would discard a reply
// that a resumed (typically suspended shell/AppContainer) client can still read.
function TncPipeServerThread.serve_client(const pipe_handle: THandle; const io_event: THandle): Boolean;
var
    overlapped: TOverlapped;
    request_bytes: TBytes;
    response_bytes: TBytes;
    drain_byte: Byte;
    bytes: DWORD;
    err: DWORD;
    io: TncPipeIoResult;
    request_text: string;
    response_text: string;
    handle_start_tick: UInt64;
    handle_elapsed_ms: UInt64;
    phase: string;
    phase_timeout_ms: DWORD;
begin
    Result := True;
    SetLength(request_bytes, c_pipe_in_buffer);
    FillChar(overlapped, SizeOf(overlapped), 0);
    overlapped.hEvent := io_event;
    io := finish_pipe_io(pipe_handle, overlapped,
        ReadFile(pipe_handle, request_bytes[0], Length(request_bytes), bytes, @overlapped),
        c_pipe_request_timeout_ms, bytes, err);
    if io <> pio_completed then
    begin
        if io = pio_timed_out then
        begin
            host_log_at(ll_warn, Format('[WARN] pipe request not received within %d ms from %s; releasing worker',
                [c_pipe_request_timeout_ms, describe_pipe_client(pipe_handle)]));
        end
        else
        begin
            host_log(Format('ReadFile failed err=%d', [err]));
        end;
        Exit;
    end;

    request_text := TEncoding.UTF8.GetString(request_bytes, 0, bytes);
    handle_start_tick := GetTickCount64;
    response_text := handle_request(request_text);
    handle_elapsed_ms := GetTickCount64 - handle_start_tick;
    if handle_elapsed_ms >= c_pipe_slow_request_ms then
    begin
        host_log_at(ll_warn, Format('[WARN] slow pipe request cmd=%s elapsed=%d ms',
            [pipe_request_command(request_text), handle_elapsed_ms]));
    end;

    response_bytes := TEncoding.UTF8.GetBytes(response_text);
    io := pio_completed;
    phase := '';
    phase_timeout_ms := 0;
    if Length(response_bytes) > 0 then
    begin
        FillChar(overlapped, SizeOf(overlapped), 0);
        overlapped.hEvent := io_event;
        io := finish_pipe_io(pipe_handle, overlapped,
            WriteFile(pipe_handle, response_bytes[0], Length(response_bytes), bytes, @overlapped),
            c_pipe_reply_timeout_ms, bytes, err);
        phase := 'accept the reply';
        phase_timeout_ms := c_pipe_reply_timeout_ms;
    end;
    if io = pio_completed then
    begin
        // Replaces FlushFileBuffers, which waits without limit for the client
        // to read. CallNamedPipe closes its handle right after reading, which
        // completes this read with ERROR_BROKEN_PIPE.
        FillChar(overlapped, SizeOf(overlapped), 0);
        overlapped.hEvent := io_event;
        io := finish_pipe_io(pipe_handle, overlapped,
            ReadFile(pipe_handle, drain_byte, 1, bytes, @overlapped),
            c_pipe_drain_timeout_ms, bytes, err);
        phase := 'read the reply';
        phase_timeout_ms := c_pipe_drain_timeout_ms;
        if io = pio_failed then
        begin
            io := pio_completed;
        end;
    end;
    if io = pio_timed_out then
    begin
        host_log_at(ll_warn, Format('[WARN] pipe client did not %s within %d ms cmd=%s %s; releasing worker',
            [phase, phase_timeout_ms, pipe_request_command(request_text),
            describe_pipe_client(pipe_handle)]));
        Result := False;
    end;
end;

procedure TncPipeServerThread.Execute;
var
    pipe_handle: THandle;
    io_event: THandle;
    disconnect: Boolean;
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
    io_event := CreateEvent(nil, True, False, nil);
    if io_event = 0 then
    begin
        host_log(Format('pipe thread event creation failed err=%d', [GetLastError]));
    end
    else
    try
        while not Terminated do
        begin
            // Overlapped I/O bounds every wait on a client; a worker blocked
            // by one frozen client used to stall all applications.
            pipe_handle := CreateNamedPipe(PChar(pipe_name), PIPE_ACCESS_DUPLEX or FILE_FLAG_OVERLAPPED,
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
            disconnect := True;
            try
                if wait_for_client(pipe_handle, io_event) then
                begin
                    disconnect := serve_client(pipe_handle, io_event);
                end;
            except
                on e: Exception do
                begin
                    // One failed request must not retire this worker.
                    host_log_at(ll_error, Format('pipe request exception %s: %s', [e.ClassName, e.Message]));
                end;
            end;
            if disconnect then
            begin
                DisconnectNamedPipe(pipe_handle);
            end;
            CloseHandle(pipe_handle);
        end;
    except
        on e: Exception do
        begin
            host_log(Format('pipe thread exception %s: %s', [e.ClassName, e.Message]));
        end;
    end;
    if io_event <> 0 then
    begin
        CloseHandle(io_event);
    end;
    if security_descriptor <> nil then
    begin
        LocalFree(HLOCAL(security_descriptor));
        security_descriptor := nil;
    end;
    host_log('pipe thread end name=' + pipe_name);
end;

end.
