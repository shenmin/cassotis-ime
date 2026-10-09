unit nc_tsf_service;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    Winapi.ActiveX,
    Winapi.Imm,
    Winapi.Msctf,
    Winapi.ShellAPI,
    Winapi.MultiMon,
    System.Classes,
    System.SyncObjs,
    System.SysUtils,
    System.IOUtils,
    System.Types,
    System.Variants,
    ComObj,
    nc_config,
    nc_types,
    nc_shortcut,
    nc_log,
    nc_tsf_guids,
    nc_tsf_lifecycle,
    nc_tsf_compartments,
    nc_tsf_display_attr,
    nc_tsf_edit_session,
    nc_caret_anchor_policy,
    nc_ipc_client,
    nc_ipc_common,
    nc_ipc_health;

type
    TncTextService = class(TComObject, ITfTextInputProcessor, ITfTextInputProcessorEx,
        ITfKeyEventSink, ITfKeyTraceEventSink, ITfCompositionSink,
        ITfContextOwnerCompositionSink, ITfDisplayAttributeProvider,
        ITfThreadMgrEventSink, ITfTextEditSink, ITfTextLayoutSink, ITfCompartmentEventSink)
    private
        m_thread_mgr: ITfThreadMgr;
        m_thread_mgr_source: ITfSource;
        m_thread_mgr_event_cookie: DWORD;
        m_key_trace_source: ITfSource;
        m_key_trace_cookie: DWORD;
        m_compartment_mgr: ITfCompartmentMgr;
        m_openclose_compartment: ITfCompartment;
        m_openclose_source: ITfSource;
        m_openclose_cookie: DWORD;
        m_conversion_compartment: ITfCompartment;
        m_conversion_source: ITfSource;
        m_conversion_cookie: DWORD;
        m_compartment_update_depth: Integer;
        m_compartment_deferred: TncTsfDeferredCompartmentSync;
        m_last_input_mode: TncInputMode;
        m_last_full_width_mode: Boolean;
        m_last_punctuation_full_width: Boolean;
        m_compartment_state_inited: Boolean;
        m_client_id: TfClientId;
        m_activation_flags: DWORD;
        m_keystroke_mgr: ITfKeystrokeMgr;
        m_key_event_advised: Boolean;
        m_preserved_input_mode_owner: TncTsfPreservedKeyOwner;
        m_preserved_input_mode_key: TF_PRESERVEDKEY;
        m_windows_ctrl_space_hotkey: Boolean;
        m_doc_mgr: ITfDocumentMgr;
        m_context_source: ITfSource;
        m_text_edit_cookie: DWORD;
        m_text_layout_cookie: DWORD;
        m_context: ITfContext;
        m_composition: ITfComposition;
        m_composition_context: ITfContext;
        m_ipc_client: TncIpcClient;
        m_session_id: string;
        m_attr_input_atom: TfGuidAtom;
        m_display_attribute_provider: ITfDisplayAttributeProvider;
        m_config_path: string;
        m_loaded_config_write_time: TDateTime;
        m_last_config_check_tick: UInt64;
        m_log_config: TncLogConfig;
        m_logger: TncLogger;
        m_last_caret_debug_tick: UInt64;
        // Caret edit sessions normalize TSF rectangles to physical screen coordinates.
        m_last_caret_point: TPoint;
        m_has_caret_point: Boolean;
        m_last_caret_line_height: Integer;
        m_last_ipc_error: DWORD;
        m_ipc_health: TncIpcHealth;
        m_host_resync_pending: Boolean;
        // Current input epoch of this session; see nc_input_epoch on the host.
        m_input_epoch: UInt64;
        m_pending_caret_update: Boolean;
        m_pending_canvas_caret: Boolean;
        m_session_dirty: Boolean;
        // Host caret coordinates are also stored in physical screen coordinates.
        m_last_sent_caret_point: TPoint;
        m_last_sent_has_caret: Boolean;
        m_last_sent_caret_valid: Boolean;
        m_last_sent_caret_line_height: Integer;
        m_last_sent_caret_tick: DWORD;
        m_last_sent_surrounding_text: string;
        m_last_sent_document_key: string;
        m_last_sent_surrounding_valid: Boolean;
        m_document_context_serial: UInt64;
        m_read_lock_surrounding_text: string;
        m_read_lock_document_key: string;
        m_read_lock_surrounding_valid: Boolean;
        m_last_read_lock_capture_tick: UInt64;
        m_last_surrounding_request_tick: UInt64;
        m_last_context_activate_tick: UInt64;
        m_surrounding_needs_refresh: Boolean;
        m_active_state_lock: TCriticalSection;
        m_active_state_event: TEvent;
        m_active_state_thread: TThread;
        m_active_state_shutdown: Boolean;
        m_active_state_pending: Boolean;
        m_pending_active_session_id: string;
        m_pending_active_value: Boolean;
        m_last_reported_active_session_id: string;
        m_last_reported_active: Boolean;
        m_active_state_synced: Boolean;
        m_shortcut_config: TncShortcutConfig;
        m_modifier_shortcut_pending: Boolean;
        m_modifier_shortcut_canceled: Boolean;
        m_modifier_shortcut_action: TncShortcutAction;
        m_modifier_shortcut_key_code: Word;
        m_chord_shortcut_pending: Boolean;
        m_chord_shortcut_action: TncShortcutAction;
        m_chord_shortcut_key_code: Word;
        m_chord_shortcut_tick: UInt64;
        m_chord_shortcut_source: TncTsfShortcutEventSource;
        m_external_input_mode_transition_pending: Boolean;
        m_external_input_mode_target: TncInputMode;
        m_external_input_mode_transition_tick: UInt64;
        m_system_input_mode_prefix_pending: Boolean;
        m_system_input_mode_prefix_tick: UInt64;
        m_rejected_modifier_transition_pending: Boolean;
        m_rejected_modifier_transition_tick: UInt64;
        m_unconfigured_ctrl_space_pending: Boolean;
        m_terminal_ctrl_space_hook: HHOOK;
        m_terminal_ctrl_space_window: HWND;
        m_terminal_ctrl_space_key_down: Boolean;
        m_langbar_icon: HICON;
        procedure clear_state;
        procedure unpreserve_input_mode_shortcut;
        procedure refresh_preserved_input_mode_shortcut;
        function read_host_input_mode_or_cached(out input_mode: TncInputMode;
            out full_width: Boolean; out punctuation_full_width: Boolean): Boolean;
        function begin_chord_shortcut(const action: TncShortcutAction;
            const key_code: Word;
            const source: TncTsfShortcutEventSource = tses_key_sink;
            const key_down_is_repeat: Boolean = False): Boolean;
        procedure rollback_activation;
        function activate_core(const thread_mgr: ITfThreadMgr;
            client_id: TfClientId; const activation_flags: DWORD): HResult;
        procedure deactivate_core;
        procedure mark_session_dirty;
        procedure reset_session_if_needed(const force: Boolean = False);
        procedure note_ipc_result(const operation: string; const ok: Boolean);
        procedure resync_host_session_after_timeout;
        function process_key_on_host(const operation: string; const key_code: Word;
            const key_state: TncKeyState; out handled: Boolean; out commit_text: string;
            out display_text: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
            out punctuation_full_width: Boolean; out lookup_perf_info: string): Boolean;
        function send_state_to_host(const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean; const source: string): Boolean;
        procedure invalidate_sent_caret;
        procedure refresh_pending_canvas_caret;
        procedure start_active_state_worker;
        procedure stop_active_state_worker;
        procedure queue_active_state_update(const active: Boolean);
        procedure push_caret_to_host(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
            const terminal_like_target: Boolean; const source: TncCaretAnchorSource = casCursor;
            const anchor_score: Integer = 0; const force: Boolean = False);
        procedure unadvise_thread_mgr_sink;
        procedure advise_thread_mgr_sink;
        procedure unadvise_key_trace_sink;
        procedure advise_key_trace_sink;
        procedure unadvise_compartment_sinks;
        procedure advise_compartment_sinks;
        procedure apply_engine_state_to_compartments(const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean);
        procedure flush_deferred_compartment_state;
        procedure log_activation_identity;
        function thread_mgr_on_set_focus(const pdimFocus: ITfDocumentMgr; const pdimPrevFocus: ITfDocumentMgr): HResult; stdcall;
        function ITfThreadMgrEventSink.OnSetFocus = thread_mgr_on_set_focus;
        procedure unadvise_context_sinks;
        procedure advise_context_sinks(const context: ITfContext);
        procedure ensure_active_context(const context: ITfContext);
        procedure cancel_composition;
        procedure init_display_attribute_atom;
        procedure free_logger;
        function build_key_state: TncKeyState;
        function is_safe_composition_fast_key(const key_code: Word; const key_state: TncKeyState): Boolean;
        function get_config_write_time: TDateTime;
        procedure load_engine_config(out config: TncEngineConfig);
        procedure apply_shortcut_config(const config: TncShortcutConfig);
        procedure apply_log_config;
        procedure reload_config_if_needed(const force_check: Boolean = False);
        procedure save_engine_state_to_config(const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean);
        procedure update_active_state(const active: Boolean);
        function commit_pending_raw_text_before_mode_switch: Boolean;
        procedure execute_shortcut_action(const action: TncShortcutAction);
        procedure update_system_input_mode_shortcut_prefix(
            const key_code: Word; const key_state: TncKeyState);
        procedure clear_system_input_mode_shortcut_prefix;
        function consume_system_input_mode_shortcut_prefix: Boolean;
        procedure clear_rejected_modifier_transition;
        function rejected_modifier_transition_active: Boolean;
        function current_process_is_terminal_compatibility_host: Boolean;
        function current_target_is_terminal_compatibility_host: Boolean;
        procedure refresh_terminal_ctrl_space_hook;
        procedure remove_terminal_ctrl_space_hook;
        function handle_terminal_ctrl_space_hook_event(
            const message_id: WPARAM; const key_code: Word;
            const injected: Boolean): Boolean;
        procedure terminal_ctrl_space_window_proc(var message: TMessage);
        procedure handle_external_input_mode_shortcut;
        function external_input_mode_transition_active: Boolean;
        procedure toggle_input_mode_by_shortcut;
        procedure toggle_full_width_mode_by_shortcut;
        procedure toggle_punctuation_mode_by_shortcut;
        procedure toggle_dictionary_variant_by_shortcut;
        procedure open_settings_by_shortcut;
        procedure configure_system_input_mode_icon;
        function on_test_key_down_core(const context: ITfContext; wParam: WPARAM;
            lParam: LPARAM; out eaten: Integer): HResult;
        function on_key_down_core(const context: ITfContext; wParam: WPARAM;
            lParam: LPARAM; out eaten: Integer): HResult;
        function on_test_key_up_core(const context: ITfContext; wParam: WPARAM;
            lParam: LPARAM; out eaten: Integer): HResult;
        function on_key_up_core(const context: ITfContext; wParam: WPARAM;
            lParam: LPARAM; out eaten: Integer): HResult;
        function on_end_edit_core(const pic: ITfContext; ecReadOnly: TfEditCookie;
            const pEditRecord: ITfEditRecord): HResult;
        function on_layout_change_core(const pic: ITfContext; lcode: TfLayoutCode;
            const pView: ITfContextView): HResult;
        function on_compartment_change_core(var rguid: TGUID): HResult;
        function get_candidate_point(out point: TPoint; out placement_line_height: Integer;
            out terminal_like_target: Boolean; out chosen_source: TncCaretAnchorSource;
            out chosen_score: Integer): Boolean;
        function request_text_ext_update(const context: ITfContext): Boolean;
        function request_surrounding_text(const context: ITfContext; out left_text: string): Boolean;
        function current_document_context_key: string;
        procedure rotate_document_context;
        function is_password_window_context(const context: ITfContext): Boolean;
        function is_protected_input_scope(const context: ITfContext;
            const ec: TfEditCookie): Boolean;
        procedure capture_surrounding_text_under_lock(const context: ITfContext;
            const ec: TfEditCookie);
        function maybe_update_surrounding_text(const context: ITfContext; const force: Boolean = False): Boolean;
        function update_surrounding_text(const context: ITfContext): Boolean;
        function update_composition(const context: ITfContext; const text: string): Boolean;
        function end_composition(const context: ITfContext): Boolean;
        function request_commit(const context: ITfContext; const text: string): Boolean;
    public
        procedure Initialize; override;
        destructor Destroy; override;

        function Activate(const thread_mgr: ITfThreadMgr; client_id: TfClientId): HResult; stdcall;
        function Deactivate: HResult; stdcall;

        function ActivateEx(const thread_mgr: ITfThreadMgr; client_id: TfClientId; flags: DWORD): HResult; stdcall;

        function OnSetFocus(focus: Integer): HResult; stdcall;
        function OnTestKeyDown(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult; stdcall;
        function OnKeyDown(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult; stdcall;
        function OnTestKeyUp(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult; stdcall;
        function OnKeyUp(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult; stdcall;
        function OnPreservedKey(const context: ITfContext; var rguid: TGUID; out eaten: Integer): HResult; stdcall;
        function OnKeyTraceDown(wParam: WPARAM; lParam: LPARAM): HResult; stdcall;
        function OnKeyTraceUp(wParam: WPARAM; lParam: LPARAM): HResult; stdcall;

        function OnCompositionTerminated(ecWrite: TfEditCookie; const composition: ITfComposition): HResult; stdcall;

        function OnStartComposition(const composition: ITfCompositionView; out ok: Integer): HResult; stdcall;
        function OnUpdateComposition(const composition: ITfCompositionView; const rangeNew: ITfRange): HResult; stdcall;
        function OnEndComposition(const composition: ITfCompositionView): HResult; stdcall;

        function OnInitDocumentMgr(const pdim: ITfDocumentMgr): HResult; stdcall;
        function OnUninitDocumentMgr(const pdim: ITfDocumentMgr): HResult; stdcall;
        function OnPushContext(const pic: ITfContext): HResult; stdcall;
        function OnPopContext(const pic: ITfContext): HResult; stdcall;

        function OnEndEdit(const pic: ITfContext; ecReadOnly: TfEditCookie; const pEditRecord: ITfEditRecord): HResult; stdcall;
        function OnLayoutChange(const pic: ITfContext; lcode: TfLayoutCode; const pView: ITfContextView): HResult; stdcall;
        function OnChange(var rguid: TGUID): HResult; stdcall;

        function EnumDisplayAttributeInfo(out ppenum: IEnumTfDisplayAttributeInfo): HResult; stdcall;
        function GetDisplayAttributeInfo(var GUID: TGUID; out ppInfo: ITfDisplayAttributeInfo): HResult; stdcall;
    end;

implementation

uses
    nc_version_info, nc_profile_icon, nc_tsf_config_actions,
    nc_imm_caret_query;

procedure signal_tray_profile_event(const active: Boolean); forward;
function next_input_epoch: UInt64; forward;
procedure log_tsf_boundary_exception(const operation: string); forward;

type
    PncLowLevelKeyboardHookData = ^TncLowLevelKeyboardHookData;
    TncLowLevelKeyboardHookData = record
        virtual_key: DWORD;
        scan_code: DWORD;
        flags: DWORD;
        timestamp: DWORD;
        extra_info: ULONG_PTR;
    end;

const
    c_nc_terminal_ctrl_space_message = WM_APP + 311;
    c_nc_low_level_keyboard_injected = $00000010;

threadvar
    g_terminal_ctrl_space_service: TncTextService;

function nc_terminal_ctrl_space_keyboard_hook(code: Integer; wParam: WPARAM;
    lParam: LPARAM): LRESULT; stdcall;
var
    hook_data: PncLowLevelKeyboardHookData;
    service: TncTextService;
begin
    service := g_terminal_ctrl_space_service;
    try
        if (code = HC_ACTION) and (service <> nil) and (lParam <> 0) then
        begin
            hook_data := PncLowLevelKeyboardHookData(lParam);
            if service.handle_terminal_ctrl_space_hook_event(wParam,
                Word(hook_data^.virtual_key),
                (hook_data^.flags and c_nc_low_level_keyboard_injected) <> 0) then
            begin
                Exit(1);
            end;
        end;
    except
        log_tsf_boundary_exception('TerminalCtrlSpaceKeyboardHook');
    end;
    if service <> nil then
    begin
        Result := CallNextHookEx(service.m_terminal_ctrl_space_hook, code,
            wParam, lParam);
    end
    else
    begin
        Result := CallNextHookEx(0, code, wParam, lParam);
    end;
end;

function nc_imm_get_hot_key(const hot_key_id: DWORD; out modifiers: UINT;
    out virtual_key: UINT; out keyboard_layout: HKL): BOOL; stdcall;
    external 'imm32.dll' name 'ImmGetHotKey';

function nc_windows_ime_toggle_owns_shortcut(
    const shortcut: TncShortcut): Boolean;
    function hot_key_matches(const hot_key_id: DWORD): Boolean;
    var
        modifiers: UINT;
        virtual_key: UINT;
        keyboard_layout: HKL;
    begin
        modifiers := 0;
        virtual_key := 0;
        keyboard_layout := 0;
        Result := nc_imm_get_hot_key(hot_key_id, modifiers, virtual_key,
            keyboard_layout) and
            nc_tsf_shortcut_matches_system_hotkey(shortcut, virtual_key,
                modifiers);
    end;
begin
    try
        Result := hot_key_matches(IME_CHOTKEY_IME_NONIME_TOGGLE) or
            hot_key_matches(IME_THOTKEY_IME_NONIME_TOGGLE);
    except
        Result := False;
    end;
end;

type
    TncGuiThreadInfo = record
        cbSize: DWORD;
        flags: DWORD;
        hwndActive: HWND;
        hwndFocus: HWND;
        hwndCapture: HWND;
        hwndMenuOwner: HWND;
        hwndMoveSize: HWND;
        hwndCaret: HWND;
        rcCaret: TRect;
    end;

type
    TF_LANGBARITEMINFO = record
        clsidService: TGUID;
        guidItem: TGUID;
        dwStyle: DWORD;
        ulSort: ULONG;
        szDescription: array [0 .. 31] of WideChar;
    end;

    ITfLangBarItem = interface(IUnknown)
        ['{73540D69-EDEB-4EE9-96C9-23AA30B25916}']
        function GetInfo(out pInfo: TF_LANGBARITEMINFO): HResult; stdcall;
        function GetStatus(out pdwStatus: DWORD): HResult; stdcall;
        function Show(fShow: BOOL): HResult; stdcall;
        function GetTooltipString(out pbstrToolTip: WideString): HResult; stdcall;
    end;

    IEnumTfLangBarItems = interface(IUnknown)
        ['{583F34D0-DE25-11D2-AFDD-00105A2799B5}']
        function Clone(out ppEnum: IEnumTfLangBarItems): HResult; stdcall;
        function Next(ulCount: ULONG; out ppItem: ITfLangBarItem; pcFetched: PULONG): HResult; stdcall;
        function Reset: HResult; stdcall;
        function Skip(ulCount: ULONG): HResult; stdcall;
    end;

    ITfLangBarItemMgr = interface(IUnknown)
        ['{BA468C55-9956-4FB1-A59D-52A7DD7CC6AA}']
        function EnumItems(out ppEnum: IEnumTfLangBarItems): HResult; stdcall;
    end;

    ITfSystemDeviceTypeLangBarItem = interface(IUnknown)
        ['{45672EB9-9059-46A2-838D-4530355F6A77}']
        function SetIconMode(dwFlags: DWORD): HResult; stdcall;
        function GetIconMode(out pdwFlags: DWORD): HResult; stdcall;
    end;

    ITfSystemLangBarItem = interface(IUnknown)
        ['{1E13E9EC-6B33-4D4A-B5EB-8A92F029F356}']
        function SetIcon(hIcon: HICON): HResult; stdcall;
        function SetTooltipString(pchToolTip: PWideChar; cch: ULONG): HResult; stdcall;
    end;

    ITfSystemLangBarItemText = interface(IUnknown)
        ['{5C4CE0E5-BA49-4B52-AC6B-3B397B4F701F}']
        function SetItemText(pch: PWideChar; cch: ULONG): HResult; stdcall;
        function GetItemText(out pbstrText: WideString): HResult; stdcall;
    end;

function nc_get_gui_thread_info(const thread_id: DWORD; var gui_info: TncGuiThreadInfo): BOOL; stdcall;
    external 'user32.dll' name 'GetGUIThreadInfo';

function TF_CreateLangBarItemMgr(out pplbim: ITfLangBarItemMgr): HRESULT; stdcall;
    external 'msctf.dll' name 'TF_CreateLangBarItemMgr';

type
    TncLogicalToPhysicalPoint = function(hwnd: HWND; var point: TPoint): BOOL; stdcall;
    TncGetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer; out dpiX: UINT;
        out dpiY: UINT): HRESULT; stdcall;
    TDpiAwarenessContext = THandle;
    TncGetWindowDpiAwarenessContext = function(hwnd: HWND): TDpiAwarenessContext; stdcall;
    TncGetAwarenessFromDpiAwarenessContext = function(value: TDpiAwarenessContext): Integer; stdcall;
    TncGetDpiForSystem = function: UINT; stdcall;
    TncGetDpiForWindow = function(hwnd: HWND): UINT; stdcall;

var
    g_logical_to_physical: TncLogicalToPhysicalPoint = nil;
    g_logical_to_physical_ready: Boolean = False;
    g_get_dpi_for_monitor: TncGetDpiForMonitor = nil;
    g_get_dpi_for_monitor_ready: Boolean = False;
    g_get_window_dpi_awareness_context: TncGetWindowDpiAwarenessContext = nil;
    g_get_awareness_from_dpi_awareness_context: TncGetAwarenessFromDpiAwarenessContext = nil;
    g_get_dpi_for_system: TncGetDpiForSystem = nil;
    g_get_dpi_for_window: TncGetDpiForWindow = nil;
    g_dpi_awareness_ready: Boolean = False;

function try_logical_to_physical(const hwnd: HWND; var point: TPoint): Boolean;
var
    module: HMODULE;
begin
    if not g_logical_to_physical_ready then
    begin
        module := GetModuleHandle('user32.dll');
        if module = 0 then
        begin
            module := LoadLibrary('user32.dll');
        end;
        if module <> 0 then
        begin
            g_logical_to_physical := TncLogicalToPhysicalPoint(
                GetProcAddress(module, 'LogicalToPhysicalPointForPerMonitorDPI'));
        end;
        g_logical_to_physical_ready := True;
    end;

    Result := Assigned(g_logical_to_physical) and (hwnd <> 0) and g_logical_to_physical(hwnd, point);
end;

function try_get_dpi_for_monitor(const monitor: HMONITOR; out dpi: Integer): Boolean;
const
    MDT_EFFECTIVE_DPI = 0;
var
    module: HMODULE;
    dpi_x: UINT;
    dpi_y: UINT;
begin
    if not g_get_dpi_for_monitor_ready then
    begin
        module := GetModuleHandle('Shcore.dll');
        if module = 0 then
        begin
            module := LoadLibrary('Shcore.dll');
        end;
        if module <> 0 then
        begin
            g_get_dpi_for_monitor := TncGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
        end;
        g_get_dpi_for_monitor_ready := True;
    end;

    dpi := 0;
    Result := Assigned(g_get_dpi_for_monitor) and (monitor <> 0) and
        (g_get_dpi_for_monitor(monitor, MDT_EFFECTIVE_DPI, dpi_x, dpi_y) = S_OK);
    if Result then
    begin
        dpi := dpi_x;
    end;
end;

function ensure_dpi_awareness_api: Boolean;
var
    module: HMODULE;
begin
    if not g_dpi_awareness_ready then
    begin
        module := GetModuleHandle('user32.dll');
        if module = 0 then
        begin
            module := LoadLibrary('user32.dll');
        end;
        if module <> 0 then
        begin
            g_get_window_dpi_awareness_context := TncGetWindowDpiAwarenessContext(
                GetProcAddress(module, 'GetWindowDpiAwarenessContext'));
            g_get_awareness_from_dpi_awareness_context := TncGetAwarenessFromDpiAwarenessContext(
                GetProcAddress(module, 'GetAwarenessFromDpiAwarenessContext'));
            g_get_dpi_for_system := TncGetDpiForSystem(GetProcAddress(module, 'GetDpiForSystem'));
            g_get_dpi_for_window := TncGetDpiForWindow(GetProcAddress(module, 'GetDpiForWindow'));
        end;
        g_dpi_awareness_ready := True;
    end;

    Result := Assigned(g_get_window_dpi_awareness_context) and Assigned(g_get_awareness_from_dpi_awareness_context);
end;

function try_get_logical_screen_source_dpi(const hwnd: HWND; const monitor_dpi: Integer; out source_dpi: Integer): Boolean;
const
    c_dpi_awareness_system_aware = 1;
var
    awareness: Integer;
    system_dpi: UINT;
    window_dpi: UINT;
begin
    source_dpi := 0;
    if (hwnd = 0) or (monitor_dpi <= 96) then
    begin
        Result := False;
        Exit;
    end;

    if ensure_dpi_awareness_api then
    begin
        awareness := g_get_awareness_from_dpi_awareness_context(g_get_window_dpi_awareness_context(hwnd));
        if awareness <= c_dpi_awareness_system_aware then
        begin
            if Assigned(g_get_dpi_for_system) then
            begin
                system_dpi := g_get_dpi_for_system();
                if system_dpi > 0 then
                begin
                    source_dpi := Integer(system_dpi);
                    Result := Abs(source_dpi - monitor_dpi) >= 12;
                    Exit;
                end;
            end;

            source_dpi := 96;
            Result := Abs(source_dpi - monitor_dpi) >= 12;
            Exit;
        end;
    end;

    if Assigned(g_get_dpi_for_window) then
    begin
        window_dpi := g_get_dpi_for_window(hwnd);
    end
    else
    begin
        window_dpi := 0;
    end;
    if (window_dpi > 0) and (Abs(Integer(window_dpi) - monitor_dpi) >= 12) then
    begin
        source_dpi := Integer(window_dpi);
        Result := True;
        Exit;
    end;

    Result := False;
end;

function try_scale_screen_rect_between_dpi(const source_rect: Winapi.Windows.TRect; const monitor_rect: Winapi.Windows.TRect;
    const source_dpi: Integer; const target_dpi: Integer; out converted_rect: Winapi.Windows.TRect): Boolean;
begin
    converted_rect := source_rect;
    if (source_dpi <= 0) or (target_dpi <= 0) or (source_dpi = target_dpi) then
    begin
        Result := False;
        Exit;
    end;

    converted_rect.Left := monitor_rect.Left + MulDiv(source_rect.Left - monitor_rect.Left, target_dpi, source_dpi);
    converted_rect.Top := monitor_rect.Top + MulDiv(source_rect.Top - monitor_rect.Top, target_dpi, source_dpi);
    converted_rect.Right := monitor_rect.Left + MulDiv(source_rect.Right - monitor_rect.Left, target_dpi, source_dpi);
    converted_rect.Bottom := monitor_rect.Top + MulDiv(source_rect.Bottom - monitor_rect.Top, target_dpi, source_dpi);
    Result := True;
end;

function try_convert_screen_rect_for_monitor_dpi(const hwnd: HWND; const source_rect: Winapi.Windows.TRect;
    out converted_rect: Winapi.Windows.TRect): Boolean;
var
    monitor: HMONITOR;
    monitor_info: MONITORINFO;
    monitor_dpi: Integer;
    source_dpi: Integer;
    anchor: TPoint;
begin
    converted_rect := source_rect;
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    anchor := Point(source_rect.Right, source_rect.Bottom);
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor = 0 then
    begin
        Result := False;
        Exit;
    end;

    monitor_info.cbSize := SizeOf(monitor_info);
    if not GetMonitorInfo(monitor, @monitor_info) then
    begin
        Result := False;
        Exit;
    end;

    if not try_get_dpi_for_monitor(monitor, monitor_dpi) then
    begin
        Result := False;
        Exit;
    end;

    if not try_get_logical_screen_source_dpi(hwnd, monitor_dpi, source_dpi) then
    begin
        Result := False;
        Exit;
    end;

    Result := try_scale_screen_rect_between_dpi(source_rect, monitor_info.rcMonitor, source_dpi, monitor_dpi,
        converted_rect);
end;

function try_screen_rect_to_physical(const hwnd: HWND; const source_rect: Winapi.Windows.TRect;
    out converted_rect: Winapi.Windows.TRect): Boolean;
var
    top_left: TPoint;
    bottom_right: TPoint;
begin
    converted_rect := source_rect;
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    top_left := Point(source_rect.Left, source_rect.Top);
    bottom_right := Point(source_rect.Right, source_rect.Bottom);
    if not try_logical_to_physical(hwnd, top_left) then
    begin
        Result := False;
        Exit;
    end;
    if not try_logical_to_physical(hwnd, bottom_right) then
    begin
        Result := False;
        Exit;
    end;

    converted_rect := System.Types.Rect(top_left.X, top_left.Y, bottom_right.X, bottom_right.Y);
    Result := True;
end;

function try_normalize_screen_rect_for_hwnd(const hwnd: HWND; var rect: Winapi.Windows.TRect): Boolean;
var
    converted_rect: Winapi.Windows.TRect;
begin
    converted_rect := rect;
    Result := try_convert_screen_rect_for_monitor_dpi(hwnd, rect, converted_rect);
    if not Result then
    begin
        Result := try_screen_rect_to_physical(hwnd, rect, converted_rect);
    end;
    if Result then
    begin
        rect := converted_rect;
    end;
end;

function try_client_point_to_screen_physical(const hwnd: HWND; var point: TPoint): Boolean;
begin
    if hwnd = 0 then
    begin
        Result := False;
        Exit;
    end;

    Result := ClientToScreen(hwnd, point);
    if Result then
    begin
        try_logical_to_physical(hwnd, point);
    end;
end;

function sanitize_perf_log_text(const value: string): string;
var
    normalized: string;
begin
    normalized := StringReplace(value, #13, ' ', [rfReplaceAll]);
    normalized := StringReplace(normalized, #10, ' ', [rfReplaceAll]);
    normalized := StringReplace(normalized, #9, ' ', [rfReplaceAll]);
    if Length(normalized) > 32 then
    begin
        normalized := Copy(normalized, 1, 32) + '...';
    end;
    Result := normalized;
end;

function sanitize_perf_log_extra_text(const value: string): string;
begin
    Result := StringReplace(value, #13, ' ', [rfReplaceAll]);
    Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
    Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
end;

procedure log_tsf_boundary_exception(const operation: string);
var
    exception_text: string;
    process_path: array[0..MAX_PATH - 1] of Char;
    process_name: string;
    line: string;
begin
    try
        if ExceptObject is Exception then
        begin
            exception_text := ExceptObject.ClassName + ': ' + Exception(ExceptObject).Message;
        end
        else if ExceptObject <> nil then
        begin
            exception_text := ExceptObject.ClassName;
        end
        else
        begin
            exception_text := 'unknown exception';
        end;

        process_name := '';
        if GetModuleFileName(0, process_path, Length(process_path)) > 0 then
        begin
            process_name := ExtractFileName(process_path);
        end;
        line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            Format(' [ERROR] [TSF-BOUNDARY] operation=%s process=%s pid=%d tid=%d address=0x%s error=%s',
            [operation, process_name, GetCurrentProcessId, GetCurrentThreadId,
            IntToHex(UInt64(NativeUInt(ExceptAddr)), SizeOf(Pointer) * 2), exception_text]) + sLineBreak;
        OutputDebugString(PChar(TrimRight(line)));
        append_log_line_shared(get_default_log_path, line, 1024);
    except
        // Exception reporting must never escape an in-proc TSF callback.
    end;
end;

const
    TF_ES_ASYNCDONTCARE = $0;
    TF_ES_SYNC = $1;
    TF_ES_READ = $2;
    TF_ES_READWRITE = $6;
    TF_ES_ASYNC = $8;
    c_edit_session_flags = TF_ES_READWRITE or TF_ES_ASYNCDONTCARE;
    TF_DTLBI_USEPROFILEICON = $00000001;

procedure TncTextService.Initialize;
var
    guid: TGUID;
begin
    try
        inherited Initialize;
        clear_state;
        m_compartment_deferred := TncTsfDeferredCompartmentSync.Create(flush_deferred_compartment_state);
        m_ipc_client := TncIpcClient.create(True);
        m_input_epoch := next_input_epoch;
        m_active_state_lock := TCriticalSection.Create;
        m_active_state_event := TEvent.Create(nil, False, False, '');
        if CreateGUID(guid) = S_OK then
        begin
            m_session_id := GUIDToString(guid);
        end;
    except
        log_tsf_boundary_exception('Initialize');
        if m_active_state_event <> nil then
        begin
            m_active_state_event.Free;
            m_active_state_event := nil;
        end;
        if m_active_state_lock <> nil then
        begin
            m_active_state_lock.Free;
            m_active_state_lock := nil;
        end;
        if m_ipc_client <> nil then
        begin
            m_ipc_client.Free;
            m_ipc_client := nil;
        end;
        FreeAndNil(m_compartment_deferred);
        m_session_id := '';
    end;
end;

procedure TncTextService.rollback_activation;
begin
    remove_terminal_ctrl_space_hook;
    unpreserve_input_mode_shortcut;
    try
        if m_key_event_advised and (m_keystroke_mgr <> nil) then
        begin
            m_keystroke_mgr.UnadviseKeyEventSink(m_client_id);
        end;
    except
        log_tsf_boundary_exception('Rollback.UnadviseKeyEventSink');
    end;
    m_key_event_advised := False;
    m_keystroke_mgr := nil;

    unadvise_context_sinks;
    unadvise_compartment_sinks;
    unadvise_key_trace_sink;
    unadvise_thread_mgr_sink;
    free_logger;
    clear_state;
end;

destructor TncTextService.Destroy;
begin
    if m_compartment_deferred <> nil then
        m_compartment_deferred.Close;
    try
        stop_active_state_worker;
    except
        log_tsf_boundary_exception('Destroy.StopWorker');
    end;
    try
        reset_session_if_needed(True);
    except
        log_tsf_boundary_exception('Destroy.ResetSession');
    end;
    try
        rollback_activation;
    except
        log_tsf_boundary_exception('Destroy.Rollback');
    end;
    if m_ipc_client <> nil then
    begin
        try
            if (m_session_id <> '') and m_ipc_client.is_host_running then
            begin
                m_ipc_client.release_session(m_session_id);
            end;
        except
            log_tsf_boundary_exception('Destroy.ReleaseSession');
        end;
        try
            m_ipc_client.Free;
        except
            log_tsf_boundary_exception('Destroy.FreeIpc');
        end;
        m_ipc_client := nil;
    end;
    FreeAndNil(m_compartment_deferred);
    inherited Destroy;
end;

procedure TncTextService.clear_state;
begin
    if m_compartment_deferred <> nil then
        m_compartment_deferred.Close;
    if m_langbar_icon <> 0 then
    begin
        DestroyIcon(m_langbar_icon);
        m_langbar_icon := 0;
    end;

    m_thread_mgr := nil;
    m_thread_mgr_source := nil;
    m_thread_mgr_event_cookie := c_nc_tsf_invalid_sink_cookie;
    m_key_trace_source := nil;
    m_key_trace_cookie := c_nc_tsf_invalid_sink_cookie;
    m_compartment_mgr := nil;
    m_openclose_compartment := nil;
    m_openclose_source := nil;
    m_openclose_cookie := c_nc_tsf_invalid_sink_cookie;
    m_conversion_compartment := nil;
    m_conversion_source := nil;
    m_conversion_cookie := c_nc_tsf_invalid_sink_cookie;
    m_compartment_update_depth := 0;
    m_last_input_mode := im_chinese;
    m_last_full_width_mode := False;
    m_last_punctuation_full_width := False;
    m_compartment_state_inited := False;
    m_client_id := 0;
    m_activation_flags := 0;
    m_keystroke_mgr := nil;
    m_key_event_advised := False;
    m_preserved_input_mode_owner := tpko_none;
    FillChar(m_preserved_input_mode_key, SizeOf(m_preserved_input_mode_key), 0);
    m_windows_ctrl_space_hotkey := False;
    m_doc_mgr := nil;
    m_context_source := nil;
    m_text_edit_cookie := c_nc_tsf_invalid_sink_cookie;
    m_text_layout_cookie := c_nc_tsf_invalid_sink_cookie;
    m_context := nil;
    m_composition := nil;
    m_composition_context := nil;
    m_attr_input_atom := TF_INVALID_GUIDATOM;
    m_display_attribute_provider := nil;
    m_config_path := '';
    m_loaded_config_write_time := 0;
    m_last_config_check_tick := 0;
    m_log_config.enabled := False;
    m_log_config.level := ll_info;
    m_log_config.max_size_kb := 1024;
    m_log_config.log_path := '';
    m_logger := nil;
    m_last_caret_debug_tick := 0;
    m_last_caret_point := Point(0, 0);
    m_has_caret_point := False;
    m_last_caret_line_height := 0;
    m_last_ipc_error := 0;
    m_ipc_health.reset;
    m_host_resync_pending := False;
    m_pending_caret_update := False;
    m_session_dirty := False;
    m_pending_canvas_caret := False;
    m_last_sent_caret_point := Point(0, 0);
    m_last_sent_has_caret := False;
    m_last_sent_caret_valid := False;
    m_last_sent_caret_line_height := 0;
    m_last_sent_caret_tick := 0;
    m_last_sent_surrounding_text := '';
    m_last_sent_document_key := '';
    m_last_sent_surrounding_valid := False;
    m_document_context_serial := 1;
    m_read_lock_surrounding_text := '';
    m_read_lock_document_key := '';
    m_read_lock_surrounding_valid := False;
    m_last_read_lock_capture_tick := 0;
    m_last_surrounding_request_tick := 0;
    m_last_context_activate_tick := 0;
    m_surrounding_needs_refresh := True;
    m_last_reported_active_session_id := '';
    m_last_reported_active := False;
    m_active_state_synced := False;
    m_shortcut_config := nc_default_shortcut_config;
    m_modifier_shortcut_pending := False;
    m_modifier_shortcut_canceled := False;
    m_modifier_shortcut_action := Low(TncShortcutAction);
    m_modifier_shortcut_key_code := 0;
    m_chord_shortcut_pending := False;
    m_chord_shortcut_action := Low(TncShortcutAction);
    m_chord_shortcut_key_code := 0;
    m_chord_shortcut_tick := 0;
    m_chord_shortcut_source := tses_key_sink;
    m_external_input_mode_transition_pending := False;
    m_external_input_mode_target := im_chinese;
    m_external_input_mode_transition_tick := 0;
    m_system_input_mode_prefix_pending := False;
    m_system_input_mode_prefix_tick := 0;
    m_rejected_modifier_transition_pending := False;
    m_rejected_modifier_transition_tick := 0;
    m_unconfigured_ctrl_space_pending := False;
    m_terminal_ctrl_space_hook := 0;
    m_terminal_ctrl_space_window := 0;
    m_terminal_ctrl_space_key_down := False;
end;

procedure TncTextService.unpreserve_input_mode_shortcut;
var
    preserved_owner: TncTsfPreservedKeyOwner;
    preserved_guid: TGUID;
    preserved_key: TF_PRESERVEDKEY;
    hr: HRESULT;
begin
    preserved_owner := m_preserved_input_mode_owner;
    if preserved_owner = tpko_none then
    begin
        Exit;
    end;

    preserved_guid := GUID_NcPreservedKeyInputModeToggle;
    preserved_key := m_preserved_input_mode_key;
    m_preserved_input_mode_owner := tpko_none;
    FillChar(m_preserved_input_mode_key, SizeOf(m_preserved_input_mode_key), 0);
    if (preserved_owner <> tpko_text_service) or (m_keystroke_mgr = nil) then
    begin
        Exit;
    end;

    try
        hr := m_keystroke_mgr.UnpreserveKey(preserved_guid, preserved_key);
        if Failed(hr) and (m_logger <> nil) then
        begin
            m_logger.warn(Format('Unpreserve input-mode shortcut failed hr=0x%s',
                [IntToHex(Cardinal(hr), 8)]));
        end;
    except
        log_tsf_boundary_exception('UnpreserveInputModeShortcut');
    end;
end;

procedure TncTextService.refresh_preserved_input_mode_shortcut;
var
    shortcut: TncShortcut;
    preserved_guid: TGUID;
    preserved_key: TF_PRESERVEDKEY;
    description: UnicodeString;
    windows_hotkey_match: Boolean;
    hr: HRESULT;
begin
    shortcut := m_shortcut_config.input_mode_toggle;
    m_windows_ctrl_space_hotkey := nc_windows_ime_toggle_owns_shortcut(
        nc_make_shortcut(VK_SPACE, False, True, False));
    if not nc_tsf_shortcut_to_preserved_key(shortcut, preserved_key) then
    begin
        clear_system_input_mode_shortcut_prefix;
        unpreserve_input_mode_shortcut;
        Exit;
    end;

    windows_hotkey_match := nc_windows_ime_toggle_owns_shortcut(shortcut);

    if (m_preserved_input_mode_owner <> tpko_none) and
        (m_preserved_input_mode_key.uVKey = preserved_key.uVKey) and
        (m_preserved_input_mode_key.uModifiers = preserved_key.uModifiers) then
    begin
        Exit;
    end;

    unpreserve_input_mode_shortcut;
    if m_keystroke_mgr = nil then
    begin
        Exit;
    end;

    preserved_guid := GUID_NcPreservedKeyInputModeToggle;
    description := 'Cassotis IME input mode toggle';
    try
        // A Windows IMM hot key and a TSF preserved key are separate
        // registrations. Try to claim the chord for this text service first;
        // otherwise Chrome and console hosts can apply the legacy Ctrl+Space
        // transition before ITfKeyEventSink ever sees Space.
        hr := m_keystroke_mgr.PreserveKey(m_client_id, preserved_guid,
            preserved_key, PWideChar(description), Length(description));
        m_preserved_input_mode_owner := nc_tsf_resolve_preserved_key_owner(
            hr, windows_hotkey_match);
        if m_preserved_input_mode_owner <> tpko_none then
        begin
            m_preserved_input_mode_key := preserved_key;
        end;
        if m_preserved_input_mode_owner = tpko_text_service then
        begin
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(Format('Preserved input-mode shortcut=%s key=%d modifiers=0x%s',
                    [nc_shortcut_to_text(shortcut), preserved_key.uVKey,
                    IntToHex(preserved_key.uModifiers, 4)]));
            end;
        end
        else if m_preserved_input_mode_owner = tpko_external then
        begin
            if m_logger <> nil then
            begin
                m_logger.info(Format(
                    'Input-mode shortcut=%s could not be preserved hr=0x%s windows_hotkey=%d; using key-trace/compartment fallback',
                    [nc_shortcut_to_text(shortcut),
                    IntToHex(Cardinal(hr), 8), Ord(windows_hotkey_match)]));
            end;
        end
        else if m_logger <> nil then
        begin
            m_logger.warn(Format('Preserve input-mode shortcut=%s failed hr=0x%s; using key sink fallback',
                [nc_shortcut_to_text(shortcut), IntToHex(Cardinal(hr), 8)]));
        end;
    except
        log_tsf_boundary_exception('PreserveInputModeShortcut');
    end;
end;

function TncTextService.read_host_input_mode_or_cached(
    out input_mode: TncInputMode; out full_width: Boolean;
    out punctuation_full_width: Boolean): Boolean;
begin
    Result := (m_ipc_client <> nil) and (m_session_id <> '') and
        m_ipc_client.get_state(m_session_id, input_mode, full_width,
            punctuation_full_width);
    if not Result then
    begin
        // GET_STATE initializes its out parameters even on timeout. Those
        // defaults must never become a mode change or erase Chinese punctuation.
        input_mode := m_last_input_mode;
        full_width := m_last_full_width_mode;
        punctuation_full_width := m_last_punctuation_full_width;
    end;
end;

function TncTextService.begin_chord_shortcut(const action: TncShortcutAction;
    const key_code: Word; const source: TncTsfShortcutEventSource;
    const key_down_is_repeat: Boolean): Boolean;
var
    elapsed_ms: UInt64;
    normalized_key_code: Word;
    now_tick: UInt64;
    same_chord: Boolean;
begin
    normalized_key_code := nc_normalize_shortcut_key_code(key_code);
    now_tick := GetTickCount64;
    same_chord := m_chord_shortcut_pending and
        (m_chord_shortcut_action = action) and
        (m_chord_shortcut_key_code = normalized_key_code);
    if m_chord_shortcut_tick = 0 then
    begin
        elapsed_ms := High(UInt64);
    end
    else
    begin
        elapsed_ms := now_tick - m_chord_shortcut_tick;
    end;
    Result := nc_tsf_should_execute_chord_shortcut(source,
        m_chord_shortcut_pending, m_chord_shortcut_source, same_chord,
        elapsed_ms, key_down_is_repeat);
    m_chord_shortcut_pending := True;
    m_chord_shortcut_action := action;
    m_chord_shortcut_key_code := normalized_key_code;
    m_chord_shortcut_tick := now_tick;
    m_chord_shortcut_source := source;
end;

procedure TncTextService.mark_session_dirty;
begin
    if m_session_id <> '' then
    begin
        m_session_dirty := True;
    end;
end;

procedure TncTextService.invalidate_sent_caret;
begin
    m_pending_canvas_caret := False;
    m_last_sent_caret_point := Point(0, 0);
    m_last_sent_has_caret := False;
    m_last_sent_caret_valid := False;
    m_last_sent_caret_line_height := 0;
    m_last_sent_caret_tick := 0;
end;

procedure TncTextService.refresh_pending_canvas_caret;
var
    point: TPoint;
    line_height: Integer;
    terminal_like: Boolean;
    source: TncCaretAnchorSource;
    score: Integer;
begin
    if not m_pending_canvas_caret then
        Exit;
    m_pending_canvas_caret := False;
    if (m_composition = nil) or (m_ipc_client = nil) or (m_session_id = '') then
        Exit;
    // A key-up/trace callback runs after the application has handled the
    // composition update. Retry once without eating keys or pumping messages.
    if get_candidate_point(point, line_height, terminal_like, source, score) and
        (source in [casTsf, casGui, casCaretPos, casImm]) then
    begin
        push_caret_to_host(point, True, line_height, terminal_like, source, score);
        m_pending_caret_update := False;
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            m_logger.debug(Format('Canvas caret refreshed on key-up source=%s point=(%d,%d)',
                [anchor_source_name(source), point.X, point.Y]));
    end;
end;

procedure TncTextService.reset_session_if_needed(const force: Boolean);
begin
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    if (not force) and (not m_session_dirty) then
    begin
        Exit;
    end;

    // Starting a new epoch fences requests that outlived a client timeout and
    // are still running on the host. The host also resets the session at the
    // first request of the new epoch if this RESET does not arrive.
    m_input_epoch := next_input_epoch;
    if m_ipc_client.reset_session(m_session_id, not force, m_input_epoch) then
    begin
        m_session_dirty := False;
        m_last_ipc_error := 0;
        invalidate_sent_caret;
        m_last_sent_surrounding_text := '';
        m_last_sent_document_key := '';
        m_last_sent_surrounding_valid := False;
        m_last_surrounding_request_tick := 0;
        m_last_context_activate_tick := 0;
        m_surrounding_needs_refresh := True;
    end;
end;

procedure TncTextService.note_ipc_result(const operation: string; const ok: Boolean);
var
    error: DWORD;
    report: TncIpcHealthReport;
begin
    error := ERROR_SUCCESS;
    if not ok then
    begin
        error := m_ipc_client.last_error;
        if error = ERROR_SUCCESS then
        begin
            // The host answered with a malformed or failed reply.
            error := ERROR_INVALID_DATA;
        end;
    end;
    report := m_ipc_health.note(ok, error, GetTickCount64);
    if m_logger = nil then
    begin
        Exit;
    end;
    case report.event of
        ihe_failure, ihe_still_failing:
            m_logger.warn(Format('IPC %s failed err=%d (%s) failures=%d outage_ms=%d session=%s startup=[%s]',
                [operation, report.error, SysErrorMessage(report.error), report.failures,
                report.duration_ms, m_session_id, m_ipc_client.last_start_detail]));
        ihe_recovered:
            m_logger.warn(Format('IPC %s recovered after %d failed calls in %d ms (last err=%d) session=%s',
                [operation, report.failures, report.duration_ms, report.error, m_session_id]));
    end;
end;

procedure TncTextService.resync_host_session_after_timeout;
begin
    // A timed-out PROCESS_KEY may have been applied, or may still be applied
    // later, by the host while the application received the key unprocessed.
    // Cancel the composition and start a new input epoch: the host rejects the
    // older request and resets the session at the first new-epoch request,
    // even if this RESET is not confirmed.
    mark_session_dirty;
    cancel_composition;
    m_host_resync_pending := False;
    if m_logger <> nil then
    begin
        m_logger.warn(Format('IPC session resynchronized after a timed-out key session=%s epoch=%s reset_confirmed=%d',
            [m_session_id, UIntToStr(m_input_epoch), Ord(not m_session_dirty)]));
    end;
end;

// The only route for PROCESS_KEY: every key carries the session's input epoch,
// so a copy that outlives its timeout is fenced on the host after a resync.
function TncTextService.process_key_on_host(const operation: string; const key_code: Word;
    const key_state: TncKeyState; out handled: Boolean; out commit_text: string;
    out display_text: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
    out punctuation_full_width: Boolean; out lookup_perf_info: string): Boolean;
begin
    Result := m_ipc_client.process_key(m_session_id, key_code, key_state, handled, commit_text,
        display_text, input_mode, full_width_mode, punctuation_full_width, lookup_perf_info,
        m_input_epoch);
    note_ipc_result(operation, Result);
    if (not Result) and (m_ipc_client.last_error = ERROR_TIMEOUT) then
    begin
        m_host_resync_pending := True;
    end;
end;

function TncTextService.send_state_to_host(const input_mode: TncInputMode;
    const full_width_mode: Boolean; const punctuation_full_width: Boolean;
    const source: string): Boolean;
begin
    Result := False;
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;
    // Mode toggles update the Windows indicator locally even when the host is
    // unreachable; record the failure instead of letting it pass unnoticed.
    Result := m_ipc_client.set_state(m_session_id, input_mode, full_width_mode,
        punctuation_full_width, source);
    note_ipc_result('set_state/' + source, Result);
    if Result then
    begin
        mark_session_dirty;
    end;
end;

procedure TncTextService.start_active_state_worker;
begin
    if (m_active_state_thread <> nil) or (m_active_state_lock = nil) or (m_active_state_event = nil) then
    begin
        Exit;
    end;

    m_active_state_shutdown := False;
    m_active_state_pending := False;
    m_pending_active_session_id := '';
    m_pending_active_value := False;
    try
        m_active_state_thread := TThread.CreateAnonymousThread(
            procedure
            var
                ipc_client: TncIpcClient;
                session_id: string;
                active_value: Boolean;
                has_work: Boolean;
                request_ok: Boolean;
            begin
                try
                    // Off the application's UI thread; SET_ACTIVE may build a cold session.
                    ipc_client := TncIpcClient.Create(True, c_nc_ipc_background_transaction_timeout_ms);
                    try
                        while True do
                        begin
                            if m_active_state_event.WaitFor(INFINITE) <> wrSignaled then
                            begin
                                Continue;
                            end;

                            while True do
                            begin
                                m_active_state_lock.Acquire;
                                try
                                    if m_active_state_shutdown then
                                    begin
                                        Exit;
                                    end;
                                    has_work := m_active_state_pending and (m_pending_active_session_id <> '');
                                    session_id := m_pending_active_session_id;
                                    active_value := m_pending_active_value;
                                    m_active_state_pending := False;
                                    m_pending_active_session_id := '';
                                finally
                                    m_active_state_lock.Release;
                                end;

                                if not has_work then
                                begin
                                    Break;
                                end;

                                if active_value then
                                begin
                                    request_ok := ipc_client.set_active(session_id, True);
                                end
                                else if ipc_client.is_host_running then
                                begin
                                    request_ok := ipc_client.set_active(session_id, False);
                                end
                                else
                                begin
                                    request_ok := True;
                                end;

                                m_active_state_lock.Acquire;
                                try
                                    if m_active_state_shutdown then
                                    begin
                                        Exit;
                                    end;

                                    if not m_active_state_pending then
                                    begin
                                        if request_ok then
                                        begin
                                            m_last_reported_active_session_id := session_id;
                                            m_last_reported_active := active_value;
                                            m_active_state_synced := True;
                                        end
                                        else
                                        begin
                                            m_active_state_synced := False;
                                        end;
                                    end;
                                finally
                                    m_active_state_lock.Release;
                                end;
                            end;
                        end;
                    finally
                        ipc_client.Free;
                    end;
                except
                    log_tsf_boundary_exception('ActiveStateWorker');
                end;
            end);
        m_active_state_thread.FreeOnTerminate := False;
        m_active_state_thread.Start;
    except
        log_tsf_boundary_exception('StartActiveStateWorker');
        if m_active_state_thread <> nil then
        begin
            m_active_state_thread.Free;
            m_active_state_thread := nil;
        end;
    end;
end;

procedure TncTextService.stop_active_state_worker;
begin
    if m_active_state_lock <> nil then
    begin
        m_active_state_lock.Acquire;
        try
            m_active_state_shutdown := True;
            if m_active_state_event <> nil then
            begin
                m_active_state_event.SetEvent;
            end;
        finally
            m_active_state_lock.Release;
        end;
    end;

    if m_active_state_thread <> nil then
    begin
        m_active_state_thread.WaitFor;
        m_active_state_thread.Free;
        m_active_state_thread := nil;
    end;

    if m_active_state_event <> nil then
    begin
        m_active_state_event.Free;
        m_active_state_event := nil;
    end;

    if m_active_state_lock <> nil then
    begin
        m_active_state_lock.Free;
        m_active_state_lock := nil;
    end;
end;

procedure TncTextService.queue_active_state_update(const active: Boolean);
begin
    if m_active_state_thread = nil then
    begin
        start_active_state_worker;
    end;
    if (m_active_state_thread = nil) or (m_active_state_lock = nil) or
        (m_active_state_event = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    m_active_state_lock.Acquire;
    try
        if m_active_state_shutdown then
        begin
            Exit;
        end;

        if m_active_state_synced and SameText(m_last_reported_active_session_id, m_session_id) and
            (m_last_reported_active = active) and (not m_active_state_pending) then
        begin
            Exit;
        end;

        if m_active_state_pending and SameText(m_pending_active_session_id, m_session_id) and
            (m_pending_active_value = active) then
        begin
            Exit;
        end;

        m_pending_active_session_id := m_session_id;
        m_pending_active_value := active;
        m_active_state_pending := True;
        m_active_state_synced := False;
        m_active_state_event.SetEvent;
    finally
        m_active_state_lock.Release;
    end;
end;

procedure TncTextService.push_caret_to_host(const point: TPoint; const has_caret: Boolean; const line_height: Integer;
    const terminal_like_target: Boolean; const source: TncCaretAnchorSource; const anchor_score: Integer;
    const force: Boolean);
const
    c_caret_resend_ms = 120;
var
    same_caret: Boolean;
    now_tick: DWORD;
begin
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    same_caret := m_last_sent_caret_valid and (m_last_sent_has_caret = has_caret) and
        (m_last_sent_caret_point.X = point.X) and (m_last_sent_caret_point.Y = point.Y) and
        (m_last_sent_caret_line_height = line_height);
    if same_caret and (not force) then
    begin
        now_tick := GetTickCount;
        if DWORD(now_tick - m_last_sent_caret_tick) < c_caret_resend_ms then
        begin
            Exit;
        end;
    end;

    if m_ipc_client.set_caret(m_session_id, point, has_caret, line_height, source, anchor_score,
        terminal_like_target, (m_activation_flags and TF_TMAE_COMLESS) <> 0) then
    begin
        m_last_sent_caret_point := point;
        m_last_sent_has_caret := has_caret;
        m_last_sent_caret_valid := True;
        m_last_sent_caret_line_height := line_height;
        m_last_sent_caret_tick := GetTickCount;
    end;
end;

procedure TncTextService.init_display_attribute_atom;
var
    category_mgr: ITfCategoryMgr;
    guid: TGUID;
    hr: HRESULT;
begin
    m_attr_input_atom := TF_INVALID_GUIDATOM;
    hr := TF_CreateCategoryMgr(PPTfCategoryMgr(@category_mgr));
    if (hr <> S_OK) or (category_mgr = nil) then
    begin
        Exit;
    end;

    guid := GUID_NcDisplayAttributeInput;
    if category_mgr.RegisterGUID(guid, m_attr_input_atom) <> S_OK then
    begin
        m_attr_input_atom := TF_INVALID_GUIDATOM;
    end;
end;

procedure TncTextService.free_logger;
begin
    if m_logger <> nil then
    begin
        m_logger.Free;
        m_logger := nil;
    end;
end;

procedure TncTextService.unadvise_thread_mgr_sink;
begin
    if not nc_tsf_try_unadvise_sink(m_thread_mgr_source, m_thread_mgr_event_cookie) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Failed to unadvise thread manager sink');
        end;
    end;
    m_thread_mgr_source := nil;
end;

procedure TncTextService.advise_thread_mgr_sink;
var
    source: ITfSource;
    iid: TGUID;
    hr: HRESULT;
begin
    unadvise_thread_mgr_sink;
    if m_thread_mgr = nil then
    begin
        Exit;
    end;

    if Supports(m_thread_mgr, ITfSource, source) then
    begin
        iid := IID_ITfThreadMgrEventSink;
        hr := source.AdviseSink(iid, Self as ITfThreadMgrEventSink, m_thread_mgr_event_cookie);
        if hr = S_OK then
        begin
            m_thread_mgr_source := source;
        end
        else
        begin
            m_thread_mgr_event_cookie := c_nc_tsf_invalid_sink_cookie;
        end;
    end;
end;

procedure TncTextService.unadvise_key_trace_sink;
begin
    if not nc_tsf_try_unadvise_sink(m_key_trace_source, m_key_trace_cookie) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Failed to unadvise key trace sink');
        end;
    end;
    m_key_trace_source := nil;
end;

procedure TncTextService.advise_key_trace_sink;
var
    source: ITfSource;
    iid: TGUID;
    hr: HRESULT;
begin
    unadvise_key_trace_sink;
    if m_thread_mgr = nil then
    begin
        Exit;
    end;

    if Supports(m_thread_mgr, ITfSource, source) then
    begin
        iid := IID_ITfKeyTraceEventSink;
        hr := source.AdviseSink(iid, Self as ITfKeyTraceEventSink,
            m_key_trace_cookie);
        if hr = S_OK then
        begin
            m_key_trace_source := source;
        end
        else
        begin
            m_key_trace_cookie := c_nc_tsf_invalid_sink_cookie;
        end;
    end;
end;

procedure TncTextService.unadvise_compartment_sinks;
begin
    if m_compartment_deferred <> nil then
        m_compartment_deferred.Cancel;
    if not nc_tsf_try_unadvise_sink(m_openclose_source, m_openclose_cookie) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Failed to unadvise open/close compartment sink');
        end;
    end;
    if not nc_tsf_try_unadvise_sink(m_conversion_source, m_conversion_cookie) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Failed to unadvise conversion compartment sink');
        end;
    end;

    m_openclose_source := nil;
    m_openclose_compartment := nil;

    m_conversion_source := nil;
    m_conversion_compartment := nil;

    m_compartment_mgr := nil;
end;

procedure TncTextService.advise_compartment_sinks;
var
    iid: TGUID;
    source: ITfSource;
    hr: HRESULT;
    guid: TGUID;
begin
    unadvise_compartment_sinks;
    if m_thread_mgr = nil then
    begin
        Exit;
    end;

    if not Supports(m_thread_mgr, ITfCompartmentMgr, m_compartment_mgr) then
    begin
        Exit;
    end;

    iid := IID_ITfCompartmentEventSink;
    guid := GUID_COMPARTMENT_KEYBOARD_OPENCLOSE;
    if (m_compartment_mgr.GetCompartment(guid, m_openclose_compartment) = S_OK) and
        (m_openclose_compartment <> nil) and Supports(m_openclose_compartment, ITfSource, source) then
    begin
        hr := source.AdviseSink(iid, Self as ITfCompartmentEventSink, m_openclose_cookie);
        if hr = S_OK then
        begin
            m_openclose_source := source;
        end
        else
        begin
            m_openclose_cookie := c_nc_tsf_invalid_sink_cookie;
        end;
    end;

    guid := GUID_COMPARTMENT_KEYBOARD_INPUTMODE_CONVERSION;
    if (m_compartment_mgr.GetCompartment(guid, m_conversion_compartment) = S_OK) and
        (m_conversion_compartment <> nil) and Supports(m_conversion_compartment, ITfSource, source) then
    begin
        hr := source.AdviseSink(iid, Self as ITfCompartmentEventSink, m_conversion_cookie);
        if hr = S_OK then
        begin
            m_conversion_source := source;
        end
        else
        begin
            m_conversion_cookie := c_nc_tsf_invalid_sink_cookie;
        end;
    end;
end;

procedure TncTextService.flush_deferred_compartment_state;
begin
    try
        if (m_thread_mgr = nil) or (m_client_id = 0) then
            Exit;
        // Coalesced state is the latest host-authorized target, not the value
        // captured by the first of several split Windows notifications.
        m_compartment_state_inited := False;
        apply_engine_state_to_compartments(m_last_input_mode,
            m_last_full_width_mode, m_last_punctuation_full_width);
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            m_logger.debug(Format(
                'Compartment deferred sync pid=%d tid=%d synced=%d state=%d/%d/%d',
                [GetCurrentProcessId, GetCurrentThreadId, Ord(m_compartment_state_inited),
                Ord(m_last_input_mode), Ord(m_last_full_width_mode),
                Ord(m_last_punctuation_full_width)]));
    except
        m_compartment_state_inited := False;
        log_tsf_boundary_exception('DeferredCompartmentSync');
    end;
end;

procedure TncTextService.apply_engine_state_to_compartments(const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean);
var
    openclose_value: DWORD;
    conversion_value: DWORD;
    openclose_written: Boolean;
    conversion_written: Boolean;
    open_status, conversion_status: HRESULT;
begin
    if (punctuation_full_width <> m_last_punctuation_full_width) and
        (m_logger <> nil) and (m_logger.level <= ll_debug) then
        m_logger.debug(Format(
            'Engine punctuation observed session=%s previous=%d current=%d mode=%d pid=%d tid=%d',
            [m_session_id, Ord(m_last_punctuation_full_width), Ord(punctuation_full_width),
            Ord(input_mode), GetCurrentProcessId, GetCurrentThreadId]));
    if (m_compartment_deferred <> nil) and m_compartment_deferred.notifying then
    begin
        // TSF forbids SetValue during OnChange (E_UNEXPECTED). A process-local
        // posted message restores the state after the notification returns.
        m_last_input_mode := input_mode;
        m_last_full_width_mode := full_width_mode;
        m_last_punctuation_full_width := punctuation_full_width;
        m_compartment_state_inited := False;
        m_compartment_deferred.Request;
        Exit;
    end;
    if m_compartment_deferred <> nil then
        m_compartment_deferred.Cancel;
    if (m_openclose_compartment = nil) or (m_conversion_compartment = nil) then
    begin
        m_last_input_mode := input_mode;
        m_last_full_width_mode := full_width_mode;
        m_last_punctuation_full_width := punctuation_full_width;
        m_compartment_state_inited := False;
        Exit;
    end;

    if m_compartment_state_inited and (input_mode = m_last_input_mode) and (full_width_mode = m_last_full_width_mode) and
        (punctuation_full_width = m_last_punctuation_full_width) then
    begin
        Exit;
    end;

    openclose_value := 0;
    if input_mode = im_chinese then
    begin
        openclose_value := 1;
    end;

    conversion_value := TF_CONVERSIONMODE_ALPHANUMERIC;
    if input_mode = im_chinese then
    begin
        conversion_value := conversion_value or TF_CONVERSIONMODE_NATIVE;
    end;
    if full_width_mode then
    begin
        conversion_value := conversion_value or TF_CONVERSIONMODE_FULLSHAPE;
    end;
    if (input_mode <> im_english) and punctuation_full_width then
    begin
        conversion_value := conversion_value or TF_CONVERSIONMODE_SYMBOL;
    end;

    Inc(m_compartment_update_depth);
    try
        openclose_written := nc_write_compartment_dword(m_openclose_compartment,
            m_client_id, openclose_value, open_status);
        conversion_written := nc_write_compartment_dword(m_conversion_compartment,
            m_client_id, conversion_value, conversion_status);
        if (m_thread_mgr <> nil) and nc_compartments_need_rebind(open_status, conversion_status) then
        begin
            // A cleared compartment object stays invalid even after OnChange.
            // Reacquire/advise once, outside notifications; never spin on failure.
            if m_logger <> nil then
                m_logger.info(Format('Compartment rebind open_hr=0x%s conversion_hr=0x%s',
                    [IntToHex(Cardinal(open_status), 8), IntToHex(Cardinal(conversion_status), 8)]));
            advise_compartment_sinks;
            openclose_written := nc_write_compartment_dword(m_openclose_compartment,
                m_client_id, openclose_value, open_status);
            conversion_written := nc_write_compartment_dword(m_conversion_compartment,
                m_client_id, conversion_value, conversion_status);
        end;
    finally
        Dec(m_compartment_update_depth);
    end;

    m_last_input_mode := input_mode;
    m_last_full_width_mode := full_width_mode;
    m_last_punctuation_full_width := punctuation_full_width;
    m_compartment_state_inited := openclose_written and conversion_written;
    if (not m_compartment_state_inited) and (m_logger <> nil) then
    begin
        m_logger.info(Format(
            'Input-mode compartment sync incomplete open=%d conversion=%d state=%d/%d/%d open_hr=0x%s conversion_hr=0x%s pid=%d tid=%d',
            [Ord(openclose_written), Ord(conversion_written), Ord(input_mode),
            Ord(full_width_mode), Ord(punctuation_full_width),
            IntToHex(Cardinal(open_status), 8), IntToHex(Cardinal(conversion_status), 8),
            GetCurrentProcessId, GetCurrentThreadId]));
    end;
end;

procedure TncTextService.unadvise_context_sinks;
begin
    if not nc_tsf_try_unadvise_sink(m_context_source, m_text_edit_cookie) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Failed to unadvise text edit sink');
        end;
    end;
    if not nc_tsf_try_unadvise_sink(m_context_source, m_text_layout_cookie) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Failed to unadvise text layout sink');
        end;
    end;

    m_context_source := nil;
end;

procedure TncTextService.advise_context_sinks(const context: ITfContext);
var
    source: ITfSource;
    iid: TGUID;
    cookie: DWORD;
    hr: HRESULT;
begin
    unadvise_context_sinks;
    if context = nil then
    begin
        Exit;
    end;

    if Supports(context, ITfSource, source) then
    begin
        cookie := c_nc_tsf_invalid_sink_cookie;
        iid := IID_ITfTextEditSink;
        hr := source.AdviseSink(iid, Self as ITfTextEditSink, cookie);
        if hr = S_OK then
        begin
            m_text_edit_cookie := cookie;
        end;

        cookie := c_nc_tsf_invalid_sink_cookie;
        iid := IID_ITfTextLayoutSink;
        hr := source.AdviseSink(iid, Self as ITfTextLayoutSink, cookie);
        if hr = S_OK then
        begin
            m_text_layout_cookie := cookie;
        end;

        if nc_tsf_sink_cookie_is_valid(m_text_edit_cookie) or
            nc_tsf_sink_cookie_is_valid(m_text_layout_cookie) then
        begin
            m_context_source := source;
        end;
    end;
end;

procedure TncTextService.cancel_composition;
var
    context: ITfContext;
    had_runtime_state: Boolean;
begin
    had_runtime_state := (m_composition <> nil) or m_pending_caret_update or m_has_caret_point;
    context := nil;
    if m_composition_context <> nil then
    begin
        context := m_composition_context;
    end
    else if m_context <> nil then
    begin
        context := m_context;
    end;

    if (m_composition <> nil) and (context <> nil) then
    begin
        end_composition(context);
    end;

    if m_composition = nil then
    begin
        m_composition_context := nil;
    end;
    m_has_caret_point := False;
    m_pending_caret_update := False;
    invalidate_sent_caret;
    if had_runtime_state then
    begin
        mark_session_dirty;
    end;
    reset_session_if_needed(False);
end;

procedure TncTextService.ensure_active_context(const context: ITfContext);
begin
    if context = nil then
    begin
        Exit;
    end;

    if m_context = context then
    begin
        Exit;
    end;

    if (m_composition <> nil) and (m_composition_context <> nil) and (m_composition_context <> context) then
    begin
        cancel_composition;
    end;

    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        mark_session_dirty;
        reset_session_if_needed(True);
    end;

    m_context := context;
    rotate_document_context;
    m_has_caret_point := False;
    m_pending_caret_update := False;
    invalidate_sent_caret;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        push_caret_to_host(Point(0, 0), False, 0, False, casCursor, 0, True);
    end;
    m_last_surrounding_request_tick := 0;
    m_last_context_activate_tick := GetTickCount64;
    m_surrounding_needs_refresh := True;
    advise_context_sinks(context);
end;

procedure TncTextService.log_activation_identity;
var
    buffer: array[0..32767] of Char;
    path_length: DWORD;
    module_path: string;
begin
    if m_logger = nil then
        Exit;
    path_length := GetModuleFileName(HInstance, buffer, Length(buffer));
    module_path := '';
    if (path_length > 0) and (path_length < DWORD(Length(buffer))) then
        SetString(module_path, buffer, path_length);
    m_logger.info(Format(
        'TSF identity code=host-startup-20260909 pid=%d tid=%d process=%s module=%s file_version=%s shortcut=%s disabled=%d preferences_policy=20260916',
        [GetCurrentProcessId, GetCurrentThreadId, ParamStr(0), module_path,
        nc_get_display_version_from_exe_file(module_path),
        nc_shortcut_to_text(m_shortcut_config.input_mode_toggle),
        Ord(m_shortcut_config.input_mode_toggle.disabled)]));
end;

function TncTextService.activate_core(const thread_mgr: ITfThreadMgr;
    client_id: TfClientId; const activation_flags: DWORD): HResult;
var
    keystroke_mgr: ITfKeystrokeMgr;
    hr: HRESULT;
    engine_config: TncEngineConfig;
    guid: TGUID;
begin
    m_thread_mgr := thread_mgr;
    m_client_id := client_id;
    m_activation_flags := activation_flags;

    m_keystroke_mgr := nil;
    m_key_event_advised := False;
    if Supports(m_thread_mgr, ITfKeystrokeMgr, keystroke_mgr) then
    begin
        hr := keystroke_mgr.AdviseKeyEventSink(m_client_id, Self as ITfKeyEventSink, 1);
        if not Failed(hr) then
        begin
            m_keystroke_mgr := keystroke_mgr;
            m_key_event_advised := True;
        end;
    end;

    advise_thread_mgr_sink;
    advise_key_trace_sink;
    advise_compartment_sinks;
    m_doc_mgr := nil;
    if (m_thread_mgr <> nil) and (m_thread_mgr.GetFocus(m_doc_mgr) = S_OK) and (m_doc_mgr <> nil) then
    begin
        m_context := nil;
        if m_doc_mgr.GetTop(m_context) = S_OK then
        begin
            rotate_document_context;
            m_last_surrounding_request_tick := 0;
            m_last_context_activate_tick := GetTickCount64;
            m_surrounding_needs_refresh := True;
            advise_context_sinks(m_context);
        end;
    end;

    m_config_path := get_default_config_path_read_only;
    load_engine_config(engine_config);
    try
        configure_system_input_mode_icon;
    except
        log_tsf_boundary_exception('ConfigureSystemInputModeIcon');
    end;
    if m_session_id = '' then
    begin
        if CreateGUID(guid) = S_OK then
        begin
            m_session_id := GUIDToString(guid);
        end;
    end;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        signal_tray_profile_event(True);
        update_active_state(True);
        m_last_surrounding_request_tick := 0;
        m_surrounding_needs_refresh := True;
    end;
    apply_engine_state_to_compartments(engine_config.input_mode, engine_config.full_width_mode,
        engine_config.punctuation_full_width);
    if m_display_attribute_provider = nil then
    begin
        m_display_attribute_provider := TncDisplayAttributeProvider.create(
            TncDisplayAttributeInfo.create(GUID_NcDisplayAttributeInput));
    end;
    init_display_attribute_atom;

    if m_logger <> nil then
    begin
        log_activation_identity;
        m_logger.info(Format('TSF activate flags=0x%.8x comless=%d',
            [m_activation_flags, Ord((m_activation_flags and TF_TMAE_COMLESS) <> 0)]));
        if m_key_trace_source = nil then
        begin
            m_logger.warn('TSF key trace sink unavailable; system-owned shortcuts may use compartment fallback');
        end;
    end;

    Result := S_OK;
end;

function TncTextService.Activate(const thread_mgr: ITfThreadMgr;
    client_id: TfClientId): HResult;
begin
    if thread_mgr = nil then
    begin
        Result := E_INVALIDARG;
        Exit;
    end;

    try
        Result := activate_core(thread_mgr, client_id, 0);
    except
        log_tsf_boundary_exception('Activate');
        try
            rollback_activation;
        except
            log_tsf_boundary_exception('Activate.Rollback');
        end;
        Result := E_FAIL;
    end;
end;

procedure TncTextService.deactivate_core;
begin
    remove_terminal_ctrl_space_hook;
    unpreserve_input_mode_shortcut;
    if m_key_event_advised and (m_keystroke_mgr <> nil) then
    begin
        m_keystroke_mgr.UnadviseKeyEventSink(m_client_id);
    end;
    m_key_event_advised := False;
    m_keystroke_mgr := nil;

    unadvise_context_sinks;
    unadvise_compartment_sinks;
    unadvise_key_trace_sink;
    unadvise_thread_mgr_sink;

    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        signal_tray_profile_event(False);
        update_active_state(False);
        mark_session_dirty;
        reset_session_if_needed(True);
    end;
    if m_logger <> nil then
    begin
        m_logger.info('TSF deactivate');
    end;
    free_logger;
    clear_state;
end;

function TncTextService.Deactivate: HResult;
begin
    try
        deactivate_core;
    except
        log_tsf_boundary_exception('Deactivate');
        try
            rollback_activation;
        except
            log_tsf_boundary_exception('Deactivate.Rollback');
        end;
    end;
    Result := S_OK;
end;

function TncTextService.ActivateEx(const thread_mgr: ITfThreadMgr; client_id: TfClientId; flags: DWORD): HResult;
begin
    if thread_mgr = nil then
    begin
        Result := E_INVALIDARG;
        Exit;
    end;

    try
        Result := activate_core(thread_mgr, client_id, flags);
    except
        log_tsf_boundary_exception('ActivateEx');
        try
            rollback_activation;
        except
            log_tsf_boundary_exception('ActivateEx.Rollback');
        end;
        Result := E_FAIL;
    end;
end;

function TncTextService.OnSetFocus(focus: Integer): HResult;
begin
    Result := S_OK;
    try
        if focus = 0 then
        begin
            if m_compartment_deferred <> nil then
                m_compartment_deferred.Cancel;
            cancel_composition;
            if (m_ipc_client <> nil) and (m_session_id <> '') then
            begin
                signal_tray_profile_event(False);
                update_active_state(False);
                mark_session_dirty;
                reset_session_if_needed(True);
            end;
            unadvise_context_sinks;
            m_doc_mgr := nil;
            m_context := nil;
            rotate_document_context;
            m_modifier_shortcut_pending := False;
            m_modifier_shortcut_canceled := False;
            m_modifier_shortcut_key_code := 0;
            m_chord_shortcut_pending := False;
            m_chord_shortcut_key_code := 0;
            m_chord_shortcut_tick := 0;
            m_chord_shortcut_source := tses_key_sink;
            m_external_input_mode_transition_pending := False;
            m_external_input_mode_transition_tick := 0;
            clear_system_input_mode_shortcut_prefix;
            clear_rejected_modifier_transition;
            m_unconfigured_ctrl_space_pending := False;
        end;
        if focus <> 0 then
        begin
            // Settings are edited in the tray process. Refresh on focus regain
            // so an already loaded client cannot keep its previous shortcut.
            reload_config_if_needed(True);
        end;
    except
        log_tsf_boundary_exception('KeyEventSink.OnSetFocus');
    end;
end;

function TncTextService.on_test_key_down_core(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
const
    c_slow_test_key_ms = 8;
var
    handled: Boolean;
    ipc_ok: Boolean;
    key_state: TncKeyState;
    key_code: Word;
    total_start_tick: UInt64;
    total_elapsed_ms: Int64;
    ipc_start_tick: UInt64;
    ipc_elapsed_ms: Int64;
    shortcut_action: TncShortcutAction;
    normalized_key_code: Word;
begin
    eaten := 0;
    if nc_tsf_is_shell_key(Word(wParam)) then
    begin
        m_modifier_shortcut_canceled := True;
        m_chord_shortcut_pending := False;
        clear_system_input_mode_shortcut_prefix;
        Result := S_OK;
        Exit;
    end;
    total_start_tick := GetTickCount64;
    ipc_elapsed_ms := 0;
    reload_config_if_needed;
    key_state := build_key_state;
    key_code := Word(wParam);
    update_system_input_mode_shortcut_prefix(key_code, key_state);
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('TestKeyDown session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
            [m_session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down),
            Ord(key_state.alt_down), Ord(key_state.caps_lock)]));
    end;

    normalized_key_code := nc_normalize_shortcut_key_code(key_code);
    if m_modifier_shortcut_pending and
        (normalized_key_code <> m_modifier_shortcut_key_code) then
    begin
        m_modifier_shortcut_canceled := True;
    end;
    if m_chord_shortcut_pending and
        (normalized_key_code <> m_chord_shortcut_key_code) then
    begin
        m_chord_shortcut_pending := False;
        m_chord_shortcut_key_code := 0;
        m_chord_shortcut_tick := 0;
        m_chord_shortcut_source := tses_key_sink;
    end;

    if nc_find_shortcut_action(m_shortcut_config, key_code, key_state, shortcut_action) then
    begin
        // A stale modifier-only binding must not execute once after Apply. A
        // forced host refresh also updates the preserved-key registration.
        reload_config_if_needed(True);
        if not nc_find_shortcut_action(m_shortcut_config, key_code, key_state,
            shortcut_action) then
        begin
            Result := S_OK;
            Exit;
        end;
        if (shortcut_action = sa_input_mode_toggle) and
            nc_tsf_should_defer_input_mode_shortcut(
                m_preserved_input_mode_owner) then
        begin
            // The trace sink coordinates the engine state and Windows updates
            // the TSF compartments. Do not also consume the chord here.
            eaten := 0;
            Result := S_OK;
            Exit;
        end;
        eaten := 1;
        Result := S_OK;
        Exit;
    end;

    if (m_composition <> nil) and (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        case key_code of
            VK_ESCAPE,
            VK_PRIOR,
            VK_NEXT:
                begin
                    eaten := 1;
                    Result := S_OK;
                    Exit;
                end;
        end;
    end;

    if is_safe_composition_fast_key(key_code, key_state) then
    begin
        eaten := 1;
        Result := S_OK;
        Exit;
    end;

    handled := False;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        ipc_start_tick := GetTickCount64;
        ipc_ok := m_ipc_client.test_key(m_session_id, key_code, key_state, handled);
        ipc_elapsed_ms := Int64(GetTickCount64 - ipc_start_tick);
        if ipc_ok then
        begin
            if handled then
            begin
                eaten := 1;
            end;
        end;
        note_ipc_result('test_key', ipc_ok);
    end;
    total_elapsed_ms := Int64(GetTickCount64 - total_start_tick);
    if (m_logger <> nil) and ((m_logger.level <= ll_debug) or (total_elapsed_ms >= c_slow_test_key_ms)) then
    begin
        if m_logger.level <= ll_debug then
        begin
            m_logger.debug(Format('Perf TestKeyDown session=%s key=%d ipc=%d total=%d handled=%d',
                [m_session_id, key_code, ipc_elapsed_ms, total_elapsed_ms, Ord(handled)]));
        end
        else
        begin
            m_logger.info(Format('[PERF] TestKeyDown session=%s key=%d ipc=%d total=%d handled=%d',
                [m_session_id, key_code, ipc_elapsed_ms, total_elapsed_ms, Ord(handled)]));
        end;
    end;
    Result := S_OK;
end;

function TncTextService.OnTestKeyDown(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
    try
        Result := on_test_key_down_core(context, wParam, lParam, eaten);
    except
        eaten := 0;
        log_tsf_boundary_exception('KeyEventSink.OnTestKeyDown');
    end;
end;

function TncTextService.on_key_down_core(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
const
    c_slow_keydown_ms = 12;
var
    handled: Boolean;
    ipc_ok: Boolean;
    commit_text: string;
    display_text: string;
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    point: TPoint;
    placement_line_height: Integer;
    terminal_like_target: Boolean;
    chosen_source: TncCaretAnchorSource;
    chosen_score: Integer;
    key_state: TncKeyState;
    key_code: Word;
    had_existing_composition: Boolean;
    total_start_tick: UInt64;
    total_elapsed_ms: Int64;
    surrounding_start_tick: UInt64;
    surrounding_elapsed_ms: Int64;
    process_start_tick: UInt64;
    process_elapsed_ms: Int64;
    composition_start_tick: UInt64;
    composition_elapsed_ms: Int64;
    candidate_point_start_tick: UInt64;
    candidate_point_elapsed_ms: Int64;
    caret_push_start_tick: UInt64;
    caret_push_elapsed_ms: Int64;
    surrounding_sent: Boolean;
    lookup_perf_info: string;
    shortcut_action: TncShortcutAction;
    shortcut_value: TncShortcut;
    normalized_key_code: Word;
begin
    eaten := 0;
    // Shell keys must not start/wait for the engine or trigger context IPC.
    if nc_tsf_is_shell_key(Word(wParam)) then
    begin
        m_modifier_shortcut_canceled := True;
        m_chord_shortcut_pending := False;
        clear_system_input_mode_shortcut_prefix;
        Result := S_OK;
        Exit;
    end;
    ensure_active_context(context);
    total_start_tick := GetTickCount64;
    process_elapsed_ms := 0;
    composition_elapsed_ms := 0;
    candidate_point_elapsed_ms := 0;
    caret_push_elapsed_ms := 0;
    lookup_perf_info := '';
    reload_config_if_needed;
    if m_host_resync_pending then
    begin
        resync_host_session_after_timeout;
    end;
    surrounding_start_tick := GetTickCount64;
    surrounding_sent := maybe_update_surrounding_text(context);
    surrounding_elapsed_ms := Int64(GetTickCount64 - surrounding_start_tick);
    handled := False;
    commit_text := '';
    display_text := '';
    key_state := build_key_state;
    key_code := Word(wParam);
    had_existing_composition := m_composition <> nil;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('KeyDown session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
            [m_session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down), Ord(key_state.alt_down),
            Ord(key_state.caps_lock)]));
    end;

    update_system_input_mode_shortcut_prefix(key_code, key_state);

    normalized_key_code := nc_normalize_shortcut_key_code(key_code);
    if m_modifier_shortcut_pending and
        (normalized_key_code <> m_modifier_shortcut_key_code) then
    begin
        m_modifier_shortcut_canceled := True;
    end;
    if m_chord_shortcut_pending and
        (normalized_key_code <> m_chord_shortcut_key_code) then
    begin
        m_chord_shortcut_pending := False;
        m_chord_shortcut_key_code := 0;
        m_chord_shortcut_tick := 0;
        m_chord_shortcut_source := tses_key_sink;
    end;

    if nc_find_shortcut_action(m_shortcut_config, key_code, key_state, shortcut_action) then
    begin
        reload_config_if_needed(True);
        if not nc_find_shortcut_action(m_shortcut_config, key_code, key_state,
            shortcut_action) then
        begin
            Result := S_OK;
            Exit;
        end;
        if (shortcut_action = sa_input_mode_toggle) and
            nc_tsf_should_defer_input_mode_shortcut(
                m_preserved_input_mode_owner) then
        begin
            eaten := 0;
            Result := S_OK;
            Exit;
        end;
        shortcut_value := nc_shortcut_for_action(m_shortcut_config, shortcut_action);
        if shortcut_action = sa_input_mode_toggle then
        begin
            clear_system_input_mode_shortcut_prefix;
        end;
        if nc_shortcut_is_modifier_only(shortcut_value) then
        begin
            m_modifier_shortcut_pending := True;
            m_modifier_shortcut_canceled := False;
            m_modifier_shortcut_action := shortcut_action;
            m_modifier_shortcut_key_code := normalized_key_code;
        end
        else
        begin
            if begin_chord_shortcut(shortcut_action, normalized_key_code) then
            begin
                execute_shortcut_action(shortcut_action);
            end;
        end;
        eaten := 1;
        Result := S_OK;
        Exit;
    end;

    if (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        case key_code of
            VK_ESCAPE:
                begin
                    if m_composition <> nil then
                    begin
                        cancel_composition;
                        eaten := 1;
                        Result := S_OK;
                        Exit;
                    end;
                end;
        end;
    end;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        mark_session_dirty;
        process_start_tick := GetTickCount64;
        ipc_ok := process_key_on_host('process_key', key_code, key_state, handled, commit_text,
            display_text, input_mode, full_width_mode, punctuation_full_width, lookup_perf_info);
        process_elapsed_ms := Int64(GetTickCount64 - process_start_tick);
        if ipc_ok then
        begin
            apply_engine_state_to_compartments(input_mode, full_width_mode, punctuation_full_width);
            if handled then
            begin
                eaten := 1;
                if commit_text <> '' then
                begin
                    request_commit(context, commit_text);
                end
                else if display_text <> '' then
                begin
                    if not had_existing_composition then
                    begin
                        invalidate_sent_caret;
                    end;
                    composition_start_tick := GetTickCount64;
                    if update_composition(context, display_text) then
                    begin
                        composition_elapsed_ms := Int64(GetTickCount64 - composition_start_tick);
                        candidate_point_start_tick := GetTickCount64;
                        if get_candidate_point(point, placement_line_height, terminal_like_target, chosen_source,
                            chosen_score) then
                        begin
                            candidate_point_elapsed_ms := Int64(GetTickCount64 - candidate_point_start_tick);
                            caret_push_start_tick := GetTickCount64;
                            push_caret_to_host(point, True, placement_line_height,
                                terminal_like_target, chosen_source, chosen_score, not had_existing_composition);
                            caret_push_elapsed_ms := Int64(GetTickCount64 - caret_push_start_tick);
                            m_pending_caret_update := False;
                            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
                            begin
                                m_logger.debug(Format('Caret point set x=%d y=%d has=1',
                                    [point.X, point.Y]));
                            end;
                        end
                        else
                        begin
                            candidate_point_elapsed_ms := Int64(GetTickCount64 - candidate_point_start_tick);
                            m_pending_caret_update := True;
                            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
                            begin
                                m_logger.debug('Caret point unavailable, defer candidate positioning');
                            end;
                        end;
                    end
                    else
                    begin
                        composition_elapsed_ms := Int64(GetTickCount64 - composition_start_tick);
                        end_composition(context);
                    end;
                end
                else
                begin
                    end_composition(context);
                end;
            end;
        end;
    end;
    total_elapsed_ms := Int64(GetTickCount64 - total_start_tick);
    if (m_logger <> nil) and ((m_logger.level <= ll_debug) or (total_elapsed_ms >= c_slow_keydown_ms)) then
    begin
        if m_logger.level <= ll_debug then
        begin
            m_logger.debug(Format(
                'Perf KeyDown session=%s key=%d sur=%d sent=%d ipc=%d comp=%d anchor=%d caret=%d total=%d handled=%d commit=%d display=%d text=[%s]',
                [m_session_id, key_code, surrounding_elapsed_ms, Ord(surrounding_sent), process_elapsed_ms,
                composition_elapsed_ms, candidate_point_elapsed_ms, caret_push_elapsed_ms, total_elapsed_ms,
                Ord(handled), Length(commit_text), Length(display_text), sanitize_perf_log_text(display_text)]));
        end
        else
        begin
            m_logger.info(Format(
                '[PERF] KeyDown session=%s key=%d sur=%d sent=%d ipc=%d comp=%d anchor=%d caret=%d total=%d handled=%d commit=%d display=%d text=[%s] %s',
                [m_session_id, key_code, surrounding_elapsed_ms, Ord(surrounding_sent), process_elapsed_ms,
                composition_elapsed_ms, candidate_point_elapsed_ms, caret_push_elapsed_ms, total_elapsed_ms,
                Ord(handled), Length(commit_text), Length(display_text), sanitize_perf_log_text(display_text),
                sanitize_perf_log_extra_text(lookup_perf_info)]));
        end;
    end;

    Result := S_OK;
end;

function TncTextService.OnKeyDown(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
    try
        Result := on_key_down_core(context, wParam, lParam, eaten);
    except
        eaten := 0;
        log_tsf_boundary_exception('KeyEventSink.OnKeyDown');
    end;
end;

function TncTextService.on_test_key_up_core(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
var
    key_code: Word;
    normalized_key_code: Word;
begin
    key_code := Word(wParam);
    normalized_key_code := nc_normalize_shortcut_key_code(key_code);
    eaten := 0;
    if m_modifier_shortcut_pending and
        (normalized_key_code = m_modifier_shortcut_key_code) then
    begin
        eaten := 1;
        Result := S_OK;
        Exit;
    end;

    if m_chord_shortcut_pending and
        (normalized_key_code = m_chord_shortcut_key_code) then
    begin
        eaten := 1;
        Result := S_OK;
        Exit;
    end;
    Result := S_OK;
end;

function TncTextService.OnTestKeyUp(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
    try
        Result := on_test_key_up_core(context, wParam, lParam, eaten);
    except
        eaten := 0;
        log_tsf_boundary_exception('KeyEventSink.OnTestKeyUp');
    end;
end;

function TncTextService.on_key_up_core(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
var
    key_code: Word;
    normalized_key_code: Word;
begin
    eaten := 0;
    key_code := Word(wParam);
    normalized_key_code := nc_normalize_shortcut_key_code(key_code);
    if m_modifier_shortcut_pending and
        (normalized_key_code = m_modifier_shortcut_key_code) then
    begin
        eaten := 1;
        if not m_modifier_shortcut_canceled then
        begin
            execute_shortcut_action(m_modifier_shortcut_action);
        end;
        m_modifier_shortcut_pending := False;
        m_modifier_shortcut_canceled := False;
        m_modifier_shortcut_key_code := 0;
        Result := S_OK;
        Exit;
    end;

    if m_chord_shortcut_pending and
        (normalized_key_code = m_chord_shortcut_key_code) then
    begin
        m_chord_shortcut_pending := False;
        m_chord_shortcut_key_code := 0;
        m_chord_shortcut_tick := 0;
        m_chord_shortcut_source := tses_key_sink;
        eaten := 1;
        Result := S_OK;
        Exit;
    end;

    refresh_pending_canvas_caret;
    Result := S_OK;
end;

function TncTextService.OnKeyUp(const context: ITfContext;
    wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
    try
        Result := on_key_up_core(context, wParam, lParam, eaten);
    except
        eaten := 0;
        log_tsf_boundary_exception('KeyEventSink.OnKeyUp');
    end;
end;

function TncTextService.commit_pending_raw_text_before_mode_switch: Boolean;
var
    handled: Boolean;
    commit_text: string;
    display_text: string;
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    lookup_perf_info: string;
    key_state: TncKeyState;
    context: ITfContext;
begin
    Result := False;
    if (m_composition = nil) or (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    handled := False;
    commit_text := '';
    display_text := '';
    input_mode := m_last_input_mode;
    full_width_mode := m_last_full_width_mode;
    punctuation_full_width := m_last_punctuation_full_width;
    lookup_perf_info := '';
    FillChar(key_state, SizeOf(key_state), 0);
    // Switching to English follows Enter semantics: preserve what the user
    // typed instead of implicitly choosing the current Chinese candidate.
    if not process_key_on_host('process_key/mode_switch_enter', VK_RETURN, key_state, handled,
        commit_text, display_text, input_mode, full_width_mode, punctuation_full_width,
        lookup_perf_info) then
    begin
        Exit;
    end;

    if not handled then
    begin
        Exit;
    end;
    if commit_text = '' then
    begin
        commit_text := display_text;
    end;
    if commit_text = '' then
    begin
        Exit;
    end;

    context := m_composition_context;
    if context = nil then
    begin
        context := m_context;
    end;
    if context = nil then
    begin
        Exit;
    end;

    Result := request_commit(context, commit_text);
    if Result and (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('Raw-commit-before-switch text=%s', [commit_text]));
    end;
end;

procedure TncTextService.execute_shortcut_action(const action: TncShortcutAction);
begin
    case action of
        sa_input_mode_toggle:
            toggle_input_mode_by_shortcut;
        sa_punctuation_toggle:
            toggle_punctuation_mode_by_shortcut;
        sa_dictionary_variant_toggle:
            toggle_dictionary_variant_by_shortcut;
        sa_full_width_toggle:
            toggle_full_width_mode_by_shortcut;
        sa_open_settings:
            open_settings_by_shortcut;
    end;
end;

procedure TncTextService.clear_system_input_mode_shortcut_prefix;
begin
    m_system_input_mode_prefix_pending := False;
    m_system_input_mode_prefix_tick := 0;
end;

procedure TncTextService.update_system_input_mode_shortcut_prefix(
    const key_code: Word; const key_state: TncKeyState);
var
    normalized_key_code: Word;
begin
    normalized_key_code := nc_normalize_shortcut_key_code(key_code);
    m_unconfigured_ctrl_space_pending := nc_tsf_ctrl_space_rejection_for_key(
        m_shortcut_config.input_mode_toggle, key_code, key_state);
    if nc_tsf_is_unconfigured_shift_toggle(
        m_shortcut_config.input_mode_toggle, key_code, key_state) then
    begin
        clear_system_input_mode_shortcut_prefix;
        m_rejected_modifier_transition_pending := True;
        m_rejected_modifier_transition_tick := GetTickCount64;
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug('Unconfigured Shift input-mode transition armed for rejection');
        end;
        Exit;
    end;

    if normalized_key_code = VK_SHIFT then
    begin
        clear_rejected_modifier_transition;
    end
    else if m_rejected_modifier_transition_pending then
    begin
        clear_rejected_modifier_transition;
    end;

    if not m_windows_ctrl_space_hotkey then
    begin
        clear_system_input_mode_shortcut_prefix;
        Exit;
    end;

    if (normalized_key_code = VK_CONTROL) and key_state.ctrl_down and
        (not key_state.shift_down) and (not key_state.alt_down) then
    begin
        m_system_input_mode_prefix_pending := True;
        m_system_input_mode_prefix_tick := GetTickCount64;
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug('System input-mode shortcut prefix armed');
        end;
        Exit;
    end;

    // Space can be consumed by the Windows IME hotkey before it reaches the
    // TSF key sink. Any other key proves that the Ctrl press belongs to a
    // different shortcut, such as Ctrl+C.
    if m_system_input_mode_prefix_pending and
        (normalized_key_code <> VK_SPACE) then
    begin
        clear_system_input_mode_shortcut_prefix;
    end;
end;

function TncTextService.consume_system_input_mode_shortcut_prefix: Boolean;
var
    elapsed_ms: UInt64;
begin
    if m_system_input_mode_prefix_tick = 0 then
    begin
        elapsed_ms := High(UInt64);
    end
    else
    begin
        elapsed_ms := GetTickCount64 - m_system_input_mode_prefix_tick;
    end;
    Result := m_windows_ctrl_space_hotkey and
        nc_tsf_system_shortcut_prefix_is_active(
            m_system_input_mode_prefix_pending, elapsed_ms);
    clear_system_input_mode_shortcut_prefix;
end;

procedure TncTextService.clear_rejected_modifier_transition;
begin
    m_rejected_modifier_transition_pending := False;
    m_rejected_modifier_transition_tick := 0;
end;

function TncTextService.rejected_modifier_transition_active: Boolean;
var
    elapsed_ms: UInt64;
begin
    if (not m_rejected_modifier_transition_pending) or
        (m_rejected_modifier_transition_tick = 0) then
    begin
        Result := False;
        Exit;
    end;

    elapsed_ms := GetTickCount64 - m_rejected_modifier_transition_tick;
    Result := nc_tsf_rejected_modifier_transition_is_active(True, elapsed_ms);
    if not Result then
    begin
        clear_rejected_modifier_transition;
    end;
end;

function TncTextService.current_process_is_terminal_compatibility_host: Boolean;
var
    process_path_buffer: array[0..MAX_PATH - 1] of Char;
    process_path: string;
    path_length: DWORD;
begin
    process_path := '';
    path_length := GetModuleFileName(0, process_path_buffer,
        Length(process_path_buffer));
    if path_length > 0 then
    begin
        SetString(process_path, process_path_buffer, path_length);
    end;
    Result := nc_tsf_is_terminal_compatibility_identity(process_path, '');
end;

function TncTextService.current_target_is_terminal_compatibility_host: Boolean;
var
    class_name_buffer: array[0..255] of Char;
    class_name: string;
    class_length: Integer;
    window_handle: Winapi.Windows.HWND;
    view: ITfContextView;

    function window_is_terminal_compatibility_host(
        const candidate_window: Winapi.Windows.HWND): Boolean;
    begin
        Result := False;
        if candidate_window = 0 then
        begin
            Exit;
        end;
        class_length := GetClassName(candidate_window, class_name_buffer,
            Length(class_name_buffer));
        if class_length <= 0 then
        begin
            Exit;
        end;
        SetString(class_name, class_name_buffer, class_length);
        Result := nc_tsf_is_terminal_compatibility_identity('', class_name);
    end;
begin
    Result := current_process_is_terminal_compatibility_host;
    if Result then
    begin
        Exit;
    end;

    if window_is_terminal_compatibility_host(GetForegroundWindow) then
    begin
        Result := True;
        Exit;
    end;

    window_handle := 0;
    view := nil;
    if (m_context <> nil) and (m_context.GetActiveView(view) = S_OK) and
        (view <> nil) and (view.GetWnd(window_handle) = S_OK) then
    begin
        Result := window_is_terminal_compatibility_host(window_handle);
    end;
end;

procedure TncTextService.remove_terminal_ctrl_space_hook;
begin
    if g_terminal_ctrl_space_service = Self then
    begin
        g_terminal_ctrl_space_service := nil;
    end;
    if m_terminal_ctrl_space_hook <> 0 then
    begin
        UnhookWindowsHookEx(m_terminal_ctrl_space_hook);
        m_terminal_ctrl_space_hook := 0;
    end;
    if m_terminal_ctrl_space_window <> 0 then
    begin
        DeallocateHWnd(m_terminal_ctrl_space_window);
        m_terminal_ctrl_space_window := 0;
    end;
    m_terminal_ctrl_space_key_down := False;
end;

procedure TncTextService.refresh_terminal_ctrl_space_hook;
var
    hook_error: DWORD;
begin
    if ((not nc_tsf_shortcut_is_ctrl_space(
        m_shortcut_config.input_mode_toggle)) and
        (not m_windows_ctrl_space_hotkey)) or
        (not current_process_is_terminal_compatibility_host) then
    begin
        remove_terminal_ctrl_space_hook;
        Exit;
    end;

    if (m_terminal_ctrl_space_hook <> 0) and
        (m_terminal_ctrl_space_window <> 0) and
        (g_terminal_ctrl_space_service = Self) then
    begin
        Exit;
    end;

    remove_terminal_ctrl_space_hook;
    try
        m_terminal_ctrl_space_window := AllocateHWnd(
            terminal_ctrl_space_window_proc);
        if m_terminal_ctrl_space_window = 0 then
        begin
            Exit;
        end;

        g_terminal_ctrl_space_service := Self;
        SetLastError(ERROR_SUCCESS);
        m_terminal_ctrl_space_hook := SetWindowsHookEx(WH_KEYBOARD_LL,
            @nc_terminal_ctrl_space_keyboard_hook, HInstance, 0);
        if m_terminal_ctrl_space_hook = 0 then
        begin
            hook_error := GetLastError;
            g_terminal_ctrl_space_service := nil;
            DeallocateHWnd(m_terminal_ctrl_space_window);
            m_terminal_ctrl_space_window := 0;
            if m_logger <> nil then
            begin
                m_logger.warn(Format(
                    'Terminal Ctrl+Space compatibility hook unavailable error=%d',
                    [hook_error]));
            end;
            Exit;
        end;

        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug('Terminal Ctrl+Space compatibility hook installed');
        end;
    except
        remove_terminal_ctrl_space_hook;
        log_tsf_boundary_exception('RefreshTerminalCtrlSpaceHook');
    end;
end;

function TncTextService.handle_terminal_ctrl_space_hook_event(
    const message_id: WPARAM; const key_code: Word;
    const injected: Boolean): Boolean;
const
    c_chord_consumed = WPARAM(1);
var
    foreground_process_id: DWORD;
    foreground_window: HWND;
    key_state: TncKeyState;
    key_is_down: Boolean;
    key_is_up: Boolean;
    hook_disposition: TncTsfTerminalCtrlSpaceDisposition;
begin
    Result := False;
    if injected or (m_terminal_ctrl_space_hook = 0) or
        (m_terminal_ctrl_space_window = 0) or
        (nc_normalize_shortcut_key_code(key_code) <> VK_SPACE) then
    begin
        Exit;
    end;

    key_is_down := (message_id = WM_KEYDOWN) or
        (message_id = WM_SYSKEYDOWN);
    key_is_up := (message_id = WM_KEYUP) or
        (message_id = WM_SYSKEYUP);
    if not (key_is_down or key_is_up) then
    begin
        Exit;
    end;

    foreground_window := GetForegroundWindow;
    foreground_process_id := 0;
    if foreground_window <> 0 then
    begin
        GetWindowThreadProcessId(foreground_window, @foreground_process_id);
    end;

    // A consumed down must have its matching up consumed even if Ctrl was
    // released first. If focus moved away meanwhile, clear the edge state but
    // do not swallow a key-up belonging to another process.
    if key_is_up and m_terminal_ctrl_space_key_down then
    begin
        m_terminal_ctrl_space_key_down := False;
        Exit(foreground_process_id = GetCurrentProcessId);
    end;
    if not key_is_down then
    begin
        Exit;
    end;

    if foreground_process_id <> GetCurrentProcessId then
    begin
        Exit;
    end;

    key_state := build_key_state;
    hook_disposition := nc_tsf_terminal_ctrl_space_disposition(
        m_shortcut_config.input_mode_toggle, m_windows_ctrl_space_hotkey,
        True, key_code, key_state);
    if hook_disposition = tcsd_ignore then
    begin
        Exit;
    end;

    if hook_disposition = tcsd_pass_through then
    begin
        // Observe but do not swallow an unconfigured Ctrl+Space. This marker
        // lets the compartment sink reject Windows' legacy IME toggle, while
        // still allowing tools such as HotkeyP to remap the physical chord to
        // Win+Space.
        m_unconfigured_ctrl_space_pending := True;
        m_system_input_mode_prefix_pending := True;
        m_system_input_mode_prefix_tick := GetTickCount64;
        PostMessage(m_terminal_ctrl_space_window,
            c_nc_terminal_ctrl_space_message, 0, 0);
        Exit;
    end;

    // Suppress keyboard auto-repeat while Space remains physically down, but
    // allow each new Space edge while Ctrl remains held.
    Result := True;
    if m_terminal_ctrl_space_key_down then
    begin
        Exit;
    end;
    m_terminal_ctrl_space_key_down := True;

    // Always defer the decision to the hidden-window callback. Settings may
    // have changed since this hook was installed, and doing file or IPC work
    // synchronously inside WH_KEYBOARD_LL would stall the keyboard globally.
    if not PostMessage(m_terminal_ctrl_space_window,
        c_nc_terminal_ctrl_space_message, c_chord_consumed, 0) then
    begin
        m_terminal_ctrl_space_key_down := False;
        Result := False;
    end;
end;

procedure TncTextService.terminal_ctrl_space_window_proc(var message: TMessage);
var
    chord_was_consumed: Boolean;
    pass_through_prefix_pending: Boolean;
    pass_through_prefix_tick: UInt64;
begin
    if message.Msg <> c_nc_terminal_ctrl_space_message then
    begin
        message.Result := DefWindowProc(m_terminal_ctrl_space_window,
            message.Msg, message.WParam, message.LParam);
        Exit;
    end;

    message.Result := 0;
    try
        chord_was_consumed := message.WParam <> 0;
        pass_through_prefix_pending := (not chord_was_consumed) and
            m_system_input_mode_prefix_pending;
        pass_through_prefix_tick := m_system_input_mode_prefix_tick;
        // The low-level hook bypasses the normal TSF key callbacks, so it must
        // explicitly refresh before deciding whether this chord is still the
        // configured shortcut.
        reload_config_if_needed(True);
        if not chord_was_consumed then
        begin
            m_unconfigured_ctrl_space_pending := not nc_tsf_shortcut_is_ctrl_space(
                m_shortcut_config.input_mode_toggle);
            // A config refresh clears transient shortcut state. Restore this
            // marker until Windows either reports its legacy toggle or the
            // bounded prefix timeout expires.
            if pass_through_prefix_pending then
            begin
                m_system_input_mode_prefix_pending := True;
                m_system_input_mode_prefix_tick := pass_through_prefix_tick;
            end;
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(
                    'Unconfigured terminal Ctrl+Space passed through for remapping');
            end;
            Exit;
        end;
        if (m_terminal_ctrl_space_hook = 0) or
            (not nc_tsf_shortcut_is_ctrl_space(
                m_shortcut_config.input_mode_toggle)) then
        begin
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(
                    'Unconfigured terminal Ctrl+Space shortcut suppressed');
            end;
            Exit;
        end;

        clear_system_input_mode_shortcut_prefix;
        m_chord_shortcut_pending := False;
        m_chord_shortcut_key_code := 0;
        m_chord_shortcut_tick := 0;
        m_chord_shortcut_source := tses_key_sink;
        toggle_input_mode_by_shortcut;
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug('Terminal Ctrl+Space compatibility hook handled fresh Space edge');
        end;
    except
        log_tsf_boundary_exception('TerminalCtrlSpaceWindowProc');
    end;
end;

function TncTextService.external_input_mode_transition_active: Boolean;
var
    elapsed_ms: UInt64;
begin
    if m_shortcut_config.input_mode_toggle.disabled then
    begin
        m_external_input_mode_transition_pending := False;
        m_external_input_mode_transition_tick := 0;
        Exit(False);
    end;
    if (not m_external_input_mode_transition_pending) or
        (m_external_input_mode_transition_tick = 0) then
    begin
        Result := False;
        Exit;
    end;

    elapsed_ms := GetTickCount64 - m_external_input_mode_transition_tick;
    Result := nc_tsf_external_transition_is_active(True, elapsed_ms);
    if not Result then
    begin
        m_external_input_mode_transition_pending := False;
        m_external_input_mode_transition_tick := 0;
    end;
end;

procedure TncTextService.handle_external_input_mode_shortcut;
var
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    next_input_mode: TncInputMode;
    got_state_from_host: Boolean;
    state_source: string;
begin
    if m_shortcut_config.input_mode_toggle.disabled then
    begin
        Exit;
    end;
    got_state_from_host := read_host_input_mode_or_cached(input_mode,
        full_width_mode, punctuation_full_width);

    if input_mode = im_chinese then
    begin
        next_input_mode := im_english;
    end
    else
    begin
        next_input_mode := im_chinese;
    end;

    if next_input_mode = im_english then
    begin
        commit_pending_raw_text_before_mode_switch;
    end;

    // Ctrl+Space is a Windows IME/non-IME hotkey on many systems. The trace
    // sink sees it before Windows consumes Space. Update the engine now, but
    // let Windows perform its own compartment transition; writing the
    // compartments here would make the system toggle the state a second time.
    m_external_input_mode_transition_pending := True;
    m_external_input_mode_target := next_input_mode;
    m_external_input_mode_transition_tick := GetTickCount64;
    send_state_to_host(next_input_mode, full_width_mode, punctuation_full_width, 'key_trace');

    m_last_input_mode := next_input_mode;
    m_last_full_width_mode := full_width_mode;
    m_last_punctuation_full_width := punctuation_full_width;
    // The next ordinary key will normalize the compartments after Windows has
    // completed the system-hotkey dispatch.
    m_compartment_state_inited := False;
    save_engine_state_to_config(next_input_mode, full_width_mode,
        punctuation_full_width);

    if next_input_mode = im_english then
    begin
        cancel_composition;
    end;

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        if got_state_from_host then
        begin
            state_source := 'host';
        end
        else
        begin
            state_source := 'local';
        end;
        m_logger.debug(Format(
            'KeyTrace input-mode shortcut=%s target=%d source=%s',
            [nc_shortcut_to_text(m_shortcut_config.input_mode_toggle),
            Ord(next_input_mode), state_source]));
    end;
end;

procedure TncTextService.toggle_input_mode_by_shortcut;
var
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    next_input_mode: TncInputMode;
    got_state_from_host: Boolean;
    state_source: string;
begin
    if m_shortcut_config.input_mode_toggle.disabled then
    begin
        Exit;
    end;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('Input-mode shortcut trigger shortcut=%s session=%s',
            [nc_shortcut_to_text(m_shortcut_config.input_mode_toggle), m_session_id]));
    end;

    got_state_from_host := read_host_input_mode_or_cached(input_mode,
        full_width_mode, punctuation_full_width);

    if input_mode = im_chinese then
    begin
        next_input_mode := im_english;
    end
    else
    begin
        next_input_mode := im_chinese;
    end;

    if next_input_mode = im_english then
    begin
        commit_pending_raw_text_before_mode_switch;
    end;

    send_state_to_host(next_input_mode, full_width_mode, punctuation_full_width, 'shortcut');

    apply_engine_state_to_compartments(next_input_mode, full_width_mode, punctuation_full_width);
    save_engine_state_to_config(next_input_mode, full_width_mode, punctuation_full_width);

    if next_input_mode = im_english then
    begin
        cancel_composition;
    end;

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        if got_state_from_host then
        begin
            state_source := 'host';
        end
        else
        begin
            state_source := 'local';
        end;
        m_logger.debug(Format('Shortcut %s toggled input mode -> %d source=%s',
            [nc_shortcut_to_text(m_shortcut_config.input_mode_toggle), Ord(next_input_mode), state_source]));
    end;

end;

procedure TncTextService.toggle_full_width_mode_by_shortcut;
var
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    got_state_from_host: Boolean;
    state_source: string;
begin
    if m_shortcut_config.full_width_toggle.disabled then Exit;
    got_state_from_host := False;
    input_mode := m_last_input_mode;
    full_width_mode := m_last_full_width_mode;
    punctuation_full_width := m_last_punctuation_full_width;

    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        got_state_from_host := m_ipc_client.get_state(m_session_id, input_mode, full_width_mode, punctuation_full_width);
    end;

    full_width_mode := not full_width_mode;
    send_state_to_host(input_mode, full_width_mode, punctuation_full_width, 'shortcut_full_width');

    apply_engine_state_to_compartments(input_mode, full_width_mode, punctuation_full_width);
    save_engine_state_to_config(input_mode, full_width_mode, punctuation_full_width);

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        if got_state_from_host then
        begin
            state_source := 'host';
        end
        else
        begin
            state_source := 'local';
        end;
        m_logger.debug(Format('Shortcut %s toggled full_width -> %d source=%s',
            [nc_shortcut_to_text(m_shortcut_config.full_width_toggle), Ord(full_width_mode), state_source]));
    end;
end;

procedure TncTextService.toggle_punctuation_mode_by_shortcut;
var
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    got_state_from_host: Boolean;
    state_source: string;
begin
    if m_shortcut_config.punctuation_toggle.disabled then Exit;
    got_state_from_host := False;
    input_mode := m_last_input_mode;
    full_width_mode := m_last_full_width_mode;
    punctuation_full_width := m_last_punctuation_full_width;

    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        got_state_from_host := m_ipc_client.get_state(m_session_id, input_mode, full_width_mode, punctuation_full_width);
    end;

    punctuation_full_width := not punctuation_full_width;
    send_state_to_host(input_mode, full_width_mode, punctuation_full_width, 'shortcut_punctuation');

    apply_engine_state_to_compartments(input_mode, full_width_mode, punctuation_full_width);
    save_engine_state_to_config(input_mode, full_width_mode, punctuation_full_width);

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        if got_state_from_host then
        begin
            state_source := 'host';
        end
        else
        begin
            state_source := 'local';
        end;
        m_logger.debug(Format('Shortcut %s toggled punctuation_full_width -> %d source=%s',
            [nc_shortcut_to_text(m_shortcut_config.punctuation_toggle), Ord(punctuation_full_width), state_source]));
    end;
end;

procedure TncTextService.toggle_dictionary_variant_by_shortcut;
var
    variant: TncDictionaryVariant;
    variant_text: string;
    variant_applied: Boolean;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    try
        variant_applied := nc_tsf_toggle_dictionary_variant(m_config_path,
            function(next_variant: TncDictionaryVariant): Boolean
            begin
                Result := (m_ipc_client <> nil) and
                    m_ipc_client.set_dictionary_variant(m_session_id, next_variant);
            end,
            function: Boolean
            begin
                Result := (m_ipc_client <> nil) and
                    m_ipc_client.reload_config(m_session_id);
            end,
            variant,
            function(out current_variant: TncDictionaryVariant): Boolean
            begin
                Result := (m_ipc_client <> nil) and
                    m_ipc_client.get_dictionary_variant(m_session_id, current_variant);
            end);
    except
        log_tsf_boundary_exception('ToggleDictionaryVariant');
        Exit;
    end;

    cancel_composition;

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        if variant = dv_traditional then
            variant_text := 'traditional'
        else
            variant_text := 'simplified';
        m_logger.debug(Format('Shortcut %s toggled dictionary variant -> %s host_applied=%d',
            [nc_shortcut_to_text(m_shortcut_config.dictionary_variant_toggle),
            variant_text, Ord(variant_applied)]));
    end;
end;

procedure TncTextService.open_settings_by_shortcut;
var
    module_path: array[0..MAX_PATH - 1] of Char;
    module_len: Cardinal;
    base_dir: string;
    tray_host_path: string;
    shell_result: HINST;
begin
    module_len := GetModuleFileName(HInstance, module_path, MAX_PATH);
    if module_len = 0 then
    begin
        Exit;
    end;

    base_dir := IncludeTrailingPathDelimiter(ExtractFilePath(module_path));
    tray_host_path := base_dir + 'cassotis_ime_tray_host.exe';
    if not FileExists(tray_host_path) then
    begin
        if m_logger <> nil then
        begin
            m_logger.warn('Open-settings shortcut failed: tray host executable not found.');
        end;
        Exit;
    end;

    cancel_composition;
    shell_result := ShellExecute(0, 'open', PChar(tray_host_path), '/settings',
        PChar(base_dir), SW_SHOWNORMAL);
    if (NativeInt(shell_result) <= 32) and (m_logger <> nil) then
    begin
        m_logger.warn(Format('Open-settings shortcut failed: ShellExecute=%d',
            [NativeInt(shell_result)]));
    end;
end;

procedure TncTextService.configure_system_input_mode_icon;
var
    langbar_item_mgr: ITfLangBarItemMgr;
    item_enum: IEnumTfLangBarItems;
    langbar_item: ITfLangBarItem;
    system_item: ITfSystemLangBarItem;
    system_text_item: ITfSystemLangBarItemText;
    device_item: ITfSystemDeviceTypeLangBarItem;
    hr: HRESULT;
    fetched: ULONG;
    icon_mode_seen_count: Integer;
    icon_mode_applied_count: Integer;
    icon_applied_count: Integer;
    text_applied_count: Integer;
    system_item_seen_count: Integer;
    module_path: array[0..MAX_PATH - 1] of Char;
    module_len: Cardinal;
    icon_path: string;
    large_icon: HICON;
    small_icon: HICON;
    display_text: WideString;
    tooltip_text: WideString;
    item_info: TF_LANGBARITEMINFO;
    item_info_hr: HRESULT;
    set_icon_hr: HRESULT;
    set_text_hr: HRESULT;
    set_icon_mode_hr: HRESULT;
begin
    icon_mode_seen_count := 0;
    icon_mode_applied_count := 0;
    icon_applied_count := 0;
    text_applied_count := 0;
    system_item_seen_count := 0;
    icon_path := '';
    large_icon := 0;
    small_icon := 0;
    display_text := WideString(#$8A00#$6CC9);
    tooltip_text := WideString('Cassotis ' + #$8A00#$6CC9#$62FC#$97F3#$8F93#$5165#$6CD5);

    if m_langbar_icon <> 0 then
    begin
        DestroyIcon(m_langbar_icon);
        m_langbar_icon := 0;
    end;

    // In an in-proc TSF DLL, module 0 is host app exe; use this module first.
    module_len := GetModuleFileName(HInstance, module_path, MAX_PATH);
    if module_len = 0 then
    begin
        module_len := GetModuleFileName(0, module_path, MAX_PATH);
    end;
    if module_len > 0 then
    begin
        icon_path := nc_resolve_profile_icon_path(string(module_path));
    end;

    if icon_path <> '' then
    begin
        if ExtractIconEx(PChar(icon_path), 0, large_icon, small_icon, 1) > 0 then
        begin
            if small_icon <> 0 then
            begin
                m_langbar_icon := small_icon;
            end
            else if large_icon <> 0 then
            begin
                m_langbar_icon := large_icon;
            end;

            if (large_icon <> 0) and (large_icon <> m_langbar_icon) then
            begin
                DestroyIcon(large_icon);
            end;
            if (small_icon <> 0) and (small_icon <> m_langbar_icon) then
            begin
                DestroyIcon(small_icon);
            end;
        end;
    end;

    langbar_item_mgr := nil;
    hr := TF_CreateLangBarItemMgr(langbar_item_mgr);
    if Failed(hr) or (langbar_item_mgr = nil) then
    begin
        Exit;
    end;

    item_enum := nil;
    hr := langbar_item_mgr.EnumItems(item_enum);
    if Failed(hr) or (item_enum = nil) then
    begin
        Exit;
    end;

    while True do
    begin
        langbar_item := nil;
        fetched := 0;
        hr := item_enum.Next(1, langbar_item, @fetched);
        if (hr <> S_OK) or (fetched = 0) then
        begin
            Break;
        end;

        try
            FillChar(item_info, SizeOf(item_info), 0);
            item_info_hr := E_NOTIMPL;
            if m_logger <> nil then
            begin
                item_info_hr := langbar_item.GetInfo(item_info);
            end;
            set_icon_hr := E_FAIL;

            if (langbar_item <> nil) and Supports(langbar_item, ITfSystemLangBarItem, system_item) then
            begin
                Inc(system_item_seen_count);
                if m_langbar_icon <> 0 then
                begin
                    set_icon_hr := system_item.SetIcon(m_langbar_icon);
                    if not Failed(set_icon_hr) then
                    begin
                        Inc(icon_applied_count);
                    end;
                end;
                if m_langbar_icon = 0 then
                begin
                    set_icon_hr := HRESULT($80070002); // ERROR_FILE_NOT_FOUND mapped to HRESULT
                end;
                system_item.SetTooltipString(PWideChar(tooltip_text), Length(tooltip_text));
            end
            else
            begin
                set_icon_hr := E_NOINTERFACE;
            end;

            if (langbar_item <> nil) and Supports(langbar_item, ITfSystemLangBarItemText, system_text_item) then
            begin
                set_text_hr := system_text_item.SetItemText(PWideChar(display_text), Length(display_text));
                if not Failed(set_text_hr) then
                begin
                    Inc(text_applied_count);
                end;
            end
            else
            begin
                set_text_hr := E_NOINTERFACE;
            end;

            if (langbar_item <> nil) and Supports(langbar_item, ITfSystemDeviceTypeLangBarItem, device_item) then
            begin
                Inc(icon_mode_seen_count);
                set_icon_mode_hr := device_item.SetIconMode(TF_DTLBI_USEPROFILEICON);
                if not Failed(set_icon_mode_hr) then
                begin
                    Inc(icon_mode_applied_count);
                end;
            end
            else
            begin
                set_icon_mode_hr := E_NOINTERFACE;
            end;

            if m_logger <> nil then
            begin
                m_logger.info(Format(
                    'LangBar item guid=%s style=0x%s info_hr=0x%s set_icon=0x%s set_text=0x%s set_icon_mode=0x%s',
                    [GUIDToString(item_info.guidItem), IntToHex(item_info.dwStyle, 8),
                    IntToHex(Cardinal(item_info_hr), 8), IntToHex(Cardinal(set_icon_hr), 8),
                    IntToHex(Cardinal(set_text_hr), 8),
                    IntToHex(Cardinal(set_icon_mode_hr), 8)]));
            end;
        except
            log_tsf_boundary_exception('ConfigureSystemInputModeIcon.Item');
        end;
    end;

    if m_logger <> nil then
    begin
        m_logger.info(Format(
            'LangBar branding icon_mode=%d/%d icon=%d/%d text=%d icon_source=%s',
            [icon_mode_applied_count, icon_mode_seen_count,
            icon_applied_count, system_item_seen_count, text_applied_count, icon_path]));
    end;
end;

function TncTextService.OnPreservedKey(const context: ITfContext; var rguid: TGUID; out eaten: Integer): HResult;
var
    invoked_key: TF_PRESERVEDKEY;
    had_registration: Boolean;
    shortcut: TncShortcut;
begin
    eaten := 0;
    Result := S_OK;
    try
        had_registration :=
            m_preserved_input_mode_owner = tpko_text_service;
        invoked_key := m_preserved_input_mode_key;
        reload_config_if_needed(True);
        if had_registration and
            (m_preserved_input_mode_owner = tpko_text_service) and
            (invoked_key.uVKey = m_preserved_input_mode_key.uVKey) and
            (invoked_key.uModifiers = m_preserved_input_mode_key.uModifiers) and
            IsEqualGUID(rguid, GUID_NcPreservedKeyInputModeToggle) then
        begin
            ensure_active_context(context);
            clear_system_input_mode_shortcut_prefix;
            shortcut := m_shortcut_config.input_mode_toggle;
            if begin_chord_shortcut(sa_input_mode_toggle, shortcut.key_code,
                tses_preserved_key) then
            begin
                execute_shortcut_action(sa_input_mode_toggle);
            end;
            eaten := 1;
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(Format('Preserved input-mode shortcut handled session=%s',
                    [m_session_id]));
            end;
        end;
    except
        eaten := 0;
        log_tsf_boundary_exception('KeyEventSink.OnPreservedKey');
    end;
end;

function TncTextService.OnKeyTraceDown(wParam: WPARAM;
    lParam: LPARAM): HResult;
var
    key_code: Word;
    key_state: TncKeyState;
    key_down_is_repeat: Boolean;
    shortcut_action: TncShortcutAction;
begin
    Result := S_OK;
    try
        reload_config_if_needed;
        key_code := Word(wParam);
        key_state := build_key_state;
        key_down_is_repeat := nc_tsf_key_down_is_repeat(lParam);
        update_system_input_mode_shortcut_prefix(key_code, key_state);
        if (m_logger <> nil) and (m_logger.level <= ll_debug) and
            (nc_normalize_shortcut_key_code(key_code) in [VK_CONTROL, VK_SPACE]) then
        begin
            m_logger.debug(Format(
                'KeyTraceDown session=%s key=%d ctrl=%d repeat=%d lparam=0x%s',
                [m_session_id, key_code, Ord(key_state.ctrl_down),
                Ord(key_down_is_repeat), IntToHex(NativeUInt(lParam),
                SizeOf(LPARAM) * 2)]));
        end;
        if (m_preserved_input_mode_owner <> tpko_external) or
            (not nc_windows_ime_toggle_owns_shortcut(
                m_shortcut_config.input_mode_toggle)) then
        begin
            Exit;
        end;

        if nc_find_shortcut_action(m_shortcut_config, key_code, key_state,
            shortcut_action) and
            (shortcut_action = sa_input_mode_toggle) and
            begin_chord_shortcut(shortcut_action, key_code, tses_key_trace,
                key_down_is_repeat) then
        begin
            clear_system_input_mode_shortcut_prefix;
            handle_external_input_mode_shortcut;
        end;
    except
        log_tsf_boundary_exception('KeyTraceEventSink.OnKeyTraceDown');
    end;
end;

function TncTextService.OnKeyTraceUp(wParam: WPARAM;
    lParam: LPARAM): HResult;
var
    normalized_key_code: Word;
begin
    Result := S_OK;
    try
        normalized_key_code := nc_normalize_shortcut_key_code(Word(wParam));
        if (m_logger <> nil) and (m_logger.level <= ll_debug) and
            (normalized_key_code in [VK_CONTROL, VK_SPACE]) then
        begin
            m_logger.debug(Format(
                'KeyTraceUp session=%s key=%d lparam=0x%s',
                [m_session_id, Word(wParam), IntToHex(NativeUInt(lParam),
                SizeOf(LPARAM) * 2)]));
        end;
        if m_chord_shortcut_pending and
            (m_chord_shortcut_source = tses_key_trace) and
            (normalized_key_code = m_chord_shortcut_key_code) then
        begin
            m_chord_shortcut_pending := False;
            m_chord_shortcut_key_code := 0;
            m_chord_shortcut_tick := 0;
            m_chord_shortcut_source := tses_key_sink;
        end;
        refresh_pending_canvas_caret;
    except
        log_tsf_boundary_exception('KeyTraceEventSink.OnKeyTraceUp');
    end;
end;

function TncTextService.OnCompositionTerminated(ecWrite: TfEditCookie; const composition: ITfComposition): HResult;
begin
    Result := S_OK;
    try
        m_composition := nil;
        m_composition_context := nil;
        m_has_caret_point := False;
        m_pending_caret_update := False;
        m_pending_canvas_caret := False;
        mark_session_dirty;
        reset_session_if_needed(False);
    except
        log_tsf_boundary_exception('CompositionSink.OnCompositionTerminated');
    end;
end;

function TncTextService.OnStartComposition(const composition: ITfCompositionView; out ok: Integer): HResult;
begin
    ok := 1;
    Result := S_OK;
end;

function TncTextService.OnUpdateComposition(const composition: ITfCompositionView; const rangeNew: ITfRange): HResult;
var
    point: TPoint;
    placement_line_height: Integer;
    terminal_like_target: Boolean;
    chosen_source: TncCaretAnchorSource;
    chosen_score: Integer;
begin
    Result := S_OK;
    try
        if m_pending_caret_update and (m_ipc_client <> nil) and (m_session_id <> '') then
        begin
            if not get_candidate_point(point, placement_line_height, terminal_like_target, chosen_source,
                chosen_score) then
            begin
                Exit;
            end;
            push_caret_to_host(point, True, placement_line_height, terminal_like_target, chosen_source, chosen_score);
            m_pending_caret_update := False;
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(Format('Caret point deferred x=%d y=%d', [point.X, point.Y]));
            end;
        end;
    except
        log_tsf_boundary_exception('CompositionSink.OnUpdateComposition');
    end;
end;

function TncTextService.OnEndComposition(const composition: ITfCompositionView): HResult;
begin
    Result := S_OK;
end;

function TncTextService.OnInitDocumentMgr(const pdim: ITfDocumentMgr): HResult;
begin
    Result := S_OK;
end;

function TncTextService.OnUninitDocumentMgr(const pdim: ITfDocumentMgr): HResult;
begin
    Result := S_OK;
    try
        if (pdim <> nil) and (m_doc_mgr <> nil) and (pdim = m_doc_mgr) then
        begin
            cancel_composition;
            if (m_ipc_client <> nil) and (m_session_id <> '') then
            begin
                mark_session_dirty;
                reset_session_if_needed(True);
            end;
            unadvise_context_sinks;
            m_doc_mgr := nil;
            m_context := nil;
        end;
    except
        log_tsf_boundary_exception('ThreadMgrEventSink.OnUninitDocumentMgr');
    end;
end;

function TncTextService.thread_mgr_on_set_focus(const pdimFocus: ITfDocumentMgr;
    const pdimPrevFocus: ITfDocumentMgr): HResult;
begin
    Result := S_OK;
    try
        if pdimFocus <> m_doc_mgr then
        begin
            if m_compartment_deferred <> nil then
                m_compartment_deferred.Cancel;
            cancel_composition;
            if (m_ipc_client <> nil) and (m_session_id <> '') then
            begin
                mark_session_dirty;
                reset_session_if_needed(True);
            end;
            unadvise_context_sinks;
            m_doc_mgr := pdimFocus;
            m_context := nil;
            if (m_doc_mgr <> nil) and (m_doc_mgr.GetTop(m_context) = S_OK) then
            begin
                advise_context_sinks(m_context);
            end;
            rotate_document_context;
        end;
        // Keep active state aligned to document focus changes.
        // We do not use OnSetFocus callback for active toggles to avoid per-key
        // focus jitter in some apps.
        update_active_state(pdimFocus <> nil);
        if (pdimFocus <> nil) and (m_context <> nil) then
        begin
            m_last_surrounding_request_tick := 0;
            m_surrounding_needs_refresh := True;
        end;
    except
        log_tsf_boundary_exception('ThreadMgrEventSink.OnSetFocus');
    end;
end;

function TncTextService.OnPushContext(const pic: ITfContext): HResult;
begin
    Result := S_OK;
    try
        ensure_active_context(pic);
    except
        log_tsf_boundary_exception('ThreadMgrEventSink.OnPushContext');
    end;
end;

function TncTextService.OnPopContext(const pic: ITfContext): HResult;
var
    focus_doc: ITfDocumentMgr;
    next_context: ITfContext;
begin
    Result := S_OK;
    try
        focus_doc := nil;
        next_context := nil;
        if (m_thread_mgr <> nil) and (m_thread_mgr.GetFocus(focus_doc) = S_OK) and (focus_doc <> nil) then
        begin
            m_doc_mgr := focus_doc;
            if focus_doc.GetTop(next_context) = S_OK then
            begin
                ensure_active_context(next_context);
            end;
        end;
    except
        log_tsf_boundary_exception('ThreadMgrEventSink.OnPopContext');
    end;
end;

function TncTextService.on_end_edit_core(const pic: ITfContext;
    ecReadOnly: TfEditCookie; const pEditRecord: ITfEditRecord): HResult;
var
    selection_changed: Integer;
    selection: TF_SELECTION;
    fetched: ULONG;
    comp_range: ITfRange;
    comp_start: ITfRange;
    comp_end: ITfRange;
    sel_start: ITfRange;
    sel_end: ITfRange;
    cmp_start: Integer;
    cmp_end: Integer;
begin
    Result := S_OK;
    if (pic = nil) or (pEditRecord = nil) then
    begin
        Exit;
    end;

    capture_surrounding_text_under_lock(pic, ecReadOnly);

    if m_composition = nil then
    begin
        Exit;
    end;

    selection_changed := 0;
    if pEditRecord.GetSelectionStatus(selection_changed) <> S_OK then
    begin
        Exit;
    end;

    if selection_changed = 0 then
    begin
        Exit;
    end;

    comp_range := nil;
    if (m_composition.GetRange(comp_range) <> S_OK) or (comp_range = nil) then
    begin
        Exit;
    end;

    comp_end := nil;
    if (comp_range.Clone(comp_end) <> S_OK) or (comp_end = nil) then
    begin
        Exit;
    end;
    comp_end.Collapse(ecReadOnly, TF_ANCHOR_END);

    comp_start := nil;
    if (comp_range.Clone(comp_start) <> S_OK) or (comp_start = nil) then
    begin
        Exit;
    end;
    comp_start.Collapse(ecReadOnly, TF_ANCHOR_START);

    FillChar(selection, SizeOf(selection), 0);
    fetched := 0;
    if (pic.GetSelection(ecReadOnly, 0, 1, selection, fetched) <> S_OK) or (fetched = 0) or (selection.range = nil) then
    begin
        Exit;
    end;

    sel_start := nil;
    if (selection.range.Clone(sel_start) <> S_OK) or (sel_start = nil) then
    begin
        Exit;
    end;
    sel_start.Collapse(ecReadOnly, TF_ANCHOR_START);

    sel_end := nil;
    if (selection.range.Clone(sel_end) <> S_OK) or (sel_end = nil) then
    begin
        Exit;
    end;
    sel_end.Collapse(ecReadOnly, TF_ANCHOR_END);

    cmp_start := 0;
    cmp_end := 0;
    if (sel_start.CompareStart(ecReadOnly, comp_start, TF_ANCHOR_START, cmp_start) = S_OK) and
        (sel_end.CompareStart(ecReadOnly, comp_end, TF_ANCHOR_START, cmp_end) = S_OK) then
    begin
        if (cmp_start < 0) or (cmp_end > 0) then
        begin
            ensure_active_context(pic);
            cancel_composition;
        end;
    end;
end;

function TncTextService.OnEndEdit(const pic: ITfContext;
    ecReadOnly: TfEditCookie; const pEditRecord: ITfEditRecord): HResult;
begin
    Result := S_OK;
    try
        Result := on_end_edit_core(pic, ecReadOnly, pEditRecord);
    except
        log_tsf_boundary_exception('TextEditSink.OnEndEdit');
    end;
end;

function TncTextService.on_layout_change_core(const pic: ITfContext;
    lcode: TfLayoutCode; const pView: ITfContextView): HResult;
var
    point: TPoint;
    placement_line_height: Integer;
    terminal_like_target: Boolean;
    chosen_source: TncCaretAnchorSource;
    chosen_score: Integer;
begin
    Result := S_OK;
    if (pic = nil) or (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    ensure_active_context(pic);
    request_text_ext_update(pic);
    if m_composition = nil then
    begin
        Exit;
    end;
    if get_candidate_point(point, placement_line_height, terminal_like_target, chosen_source, chosen_score) then
    begin
        push_caret_to_host(point, True, placement_line_height, terminal_like_target, chosen_source,
            chosen_score);
    end;
end;

function TncTextService.OnLayoutChange(const pic: ITfContext;
    lcode: TfLayoutCode; const pView: ITfContextView): HResult;
begin
    Result := S_OK;
    try
        Result := on_layout_change_core(pic, lcode, pView);
    except
        log_tsf_boundary_exception('TextLayoutSink.OnLayoutChange');
    end;
end;

function TncTextService.on_compartment_change_core(var rguid: TGUID): HResult;
var
    openclose_value: DWORD;
    conversion_value: DWORD;
    has_openclose: Boolean;
    has_conversion: Boolean;
    change_source: TncTsfCompartmentChangeSource;
    external_transition: Boolean;
    external_transition_settled: Boolean;
    rejected_transition: Boolean;
    terminal_compatibility_target: Boolean;
    host_state_available: Boolean;
    host_state_matches_proposed: Boolean;
    previous_input_mode: TncInputMode;
    previous_full_width: Boolean;
    previous_punctuation_full_width: Boolean;
    next_input_mode: TncInputMode;
    proposed_input_mode: TncInputMode;
    next_full_width: Boolean;
    next_punctuation_full_width: Boolean;
    state_changed: Boolean;
    state_synced: Boolean;
    host_input_mode: TncInputMode;
    host_full_width: Boolean;
    host_punctuation_full_width: Boolean;
    system_shortcut_prefix_consumed: Boolean;
    host_shortcuts: TncShortcutConfig;
    input_shortcut_changed: Boolean;
    key_state: TncKeyState;
    ctrl_space_rejected: Boolean;
    guard_unconfigured_mode: Boolean;
    restore_conversion_preferences: Boolean;
    open_read_status, conversion_read_status: HRESULT;
begin
    if m_compartment_update_depth > 0 then
    begin
        Result := S_OK;
        Exit;
    end;

    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Result := S_OK;
        Exit;
    end;

    // A Windows IMM toggle can bypass all key sinks. Refresh the host-owned
    // binding here too, so Apply/Disable does not wait for the next traced key.
    Inc(m_compartment_update_depth);
    try
        if m_ipc_client.get_shortcut_config(m_session_id, host_shortcuts) then
        begin
            input_shortcut_changed := not nc_shortcut_equal(
                m_shortcut_config.input_mode_toggle,
                host_shortcuts.input_mode_toggle);
            apply_shortcut_config(host_shortcuts);
            if input_shortcut_changed then
            begin
                refresh_preserved_input_mode_shortcut;
                refresh_terminal_ctrl_space_hook;
            end;
        end;
    finally
        Dec(m_compartment_update_depth);
    end;

    key_state := build_key_state;
    ctrl_space_rejected := nc_tsf_ctrl_space_rejection_is_active(
        m_shortcut_config.input_mode_toggle,
        m_unconfigured_ctrl_space_pending, key_state);
    // Also retain evidence when Windows delivered no key trace at all.
    m_unconfigured_ctrl_space_pending := ctrl_space_rejected;
    guard_unconfigured_mode := m_shortcut_config.input_mode_toggle.disabled or
        ctrl_space_rejected;

    openclose_value := 0;
    conversion_value := 0;
    has_openclose := nc_read_compartment_dword(m_openclose_compartment,
        openclose_value, open_read_status);
    has_conversion := nc_read_compartment_dword(m_conversion_compartment,
        conversion_value, conversion_read_status);
    if nc_compartments_need_rebind(open_read_status, conversion_read_status) then
    begin
        m_compartment_state_inited := False;
        m_compartment_deferred.Request;
    end;
    if (not has_openclose) and (not has_conversion) then
    begin
        if m_logger <> nil then
            m_logger.info(Format('Compartment values unavailable open_hr=0x%s conversion_hr=0x%s deferred=%d',
                [IntToHex(Cardinal(open_read_status), 8), IntToHex(Cardinal(conversion_read_status), 8),
                Ord(m_compartment_deferred.pending)]));
        Result := S_OK;
        Exit;
    end;

    change_source := tccs_unknown;
    if IsEqualGUID(rguid, GUID_COMPARTMENT_KEYBOARD_OPENCLOSE) then
    begin
        change_source := tccs_openclose;
    end
    else if IsEqualGUID(rguid, GUID_COMPARTMENT_KEYBOARD_INPUTMODE_CONVERSION) then
    begin
        change_source := tccs_conversion;
    end;
    system_shortcut_prefix_consumed :=
        (change_source in [tccs_openclose, tccs_conversion]) and
        consume_system_input_mode_shortcut_prefix;
    if system_shortcut_prefix_consumed then
    begin
        if ctrl_space_rejected or nc_tsf_should_reject_unconfigured_ctrl_space_toggle(
            m_shortcut_config.input_mode_toggle,
            m_windows_ctrl_space_hotkey,
            system_shortcut_prefix_consumed) then
        begin
            m_rejected_modifier_transition_pending := True;
            m_rejected_modifier_transition_tick := GetTickCount64;
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(
                    'Unconfigured system Ctrl+Space transition armed for rejection');
            end;
        end
        else
        begin
            // Chromium and some console hosts consume Space as the legacy
            // Windows IME hotkey before TSF dispatches OnPreservedKey. Toggle
            // once from the engine state instead of trusting that stale value.
            handle_external_input_mode_shortcut;
            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
            begin
                m_logger.debug(
                    'System input-mode shortcut inferred from compartment change');
            end;
        end;
    end;
    previous_input_mode := m_last_input_mode;
    previous_full_width := m_last_full_width_mode;
    previous_punctuation_full_width := m_last_punctuation_full_width;
    external_transition := external_input_mode_transition_active;
    proposed_input_mode := nc_tsf_resolve_input_mode(previous_input_mode,
        change_source, has_openclose, openclose_value, has_conversion,
        conversion_value);
    external_transition_settled :=
        nc_tsf_external_transition_should_settle(external_transition,
            m_external_input_mode_target, proposed_input_mode);
    terminal_compatibility_target := False;
    host_input_mode := previous_input_mode;
    host_full_width := previous_full_width;
    host_punctuation_full_width := previous_punctuation_full_width;
    host_state_available := m_ipc_client.get_state(m_session_id,
        host_input_mode, host_full_width, host_punctuation_full_width);
    host_state_matches_proposed := False;
    if guard_unconfigured_mode or
        ((not external_transition) and
        (proposed_input_mode <> previous_input_mode)) then
    begin
        terminal_compatibility_target :=
            current_target_is_terminal_compatibility_host;
        if terminal_compatibility_target or guard_unconfigured_mode then
        begin
            host_state_matches_proposed := host_state_available and
                (host_input_mode = proposed_input_mode);
        end;
    end;
    rejected_transition := (not external_transition) and
        (not host_state_matches_proposed) and
        rejected_modifier_transition_active;
    if (not rejected_transition) and
        nc_tsf_should_reject_unconfigured_mode_change(
            m_shortcut_config.input_mode_toggle,
            terminal_compatibility_target, external_transition,
            proposed_input_mode <> previous_input_mode,
            host_state_matches_proposed, ctrl_space_rejected) then
    begin
        rejected_transition := True;
    end;
    if rejected_transition then
    begin
        // Windows can still apply a legacy Shift or Ctrl+Space IME hotkey
        // even when Cassotis is bound to another shortcut. Keep the configured
        // state and restore both compartments without forwarding that
        // transition to the host.
        next_input_mode := previous_input_mode;
        if guard_unconfigured_mode and host_state_available then
        begin
            next_input_mode := host_input_mode;
        end;
    end
    else if guard_unconfigured_mode then
    begin
        // Mouse/UI changes and other configured actions update the host first.
        // An unconfigured legacy chord cannot write mode/punctuation behind
        // that state, including delayed and split notifications.
        if host_state_available then
        begin
            next_input_mode := host_input_mode;
        end
        else
        begin
            next_input_mode := previous_input_mode;
        end;
    end
    else if external_transition then
    begin
        // The trace sink already selected the target state. Split system
        // notifications must not undo it or overwrite the saved Chinese
        // punctuation preference with the temporary English conversion bits.
        next_input_mode := m_external_input_mode_target;
    end
    else
    begin
        next_input_mode := proposed_input_mode;
    end;

    // Other documents and the status UI share the host's preferences. Never
    // publish this DLL instance's stale punctuation while changing only mode.
    next_full_width := previous_full_width;
    next_punctuation_full_width := previous_punctuation_full_width;
    if host_state_available then
    begin
        next_full_width := host_full_width;
        next_punctuation_full_width := host_punctuation_full_width;
    end;
    if not (rejected_transition or guard_unconfigured_mode or external_transition) then
        nc_tsf_resolve_conversion_preferences(previous_input_mode, next_input_mode,
            change_source, has_conversion, conversion_value, m_shortcut_config,
            next_full_width, next_punctuation_full_width);
    restore_conversion_preferences := (not external_transition) and has_conversion and
        (not nc_tsf_conversion_preferences_match(next_input_mode, next_full_width,
            next_punctuation_full_width, conversion_value));

    state_changed := (next_input_mode <> previous_input_mode) or
        (next_full_width <> previous_full_width) or
        (next_punctuation_full_width <> previous_punctuation_full_width);
    state_synced := not state_changed;
    if rejected_transition or guard_unconfigured_mode then
    begin
        m_compartment_state_inited := False;
        apply_engine_state_to_compartments(next_input_mode,
            next_full_width, next_punctuation_full_width);
        state_synced := True;
    end
    else if state_changed then
    begin
        state_synced := send_state_to_host(next_input_mode, next_full_width,
            next_punctuation_full_width, 'compartment');
    end;

    if state_synced then
    begin
        m_last_input_mode := next_input_mode;
        m_last_full_width_mode := next_full_width;
        m_last_punctuation_full_width := next_punctuation_full_width;
        if restore_conversion_preferences and
            (not (rejected_transition or guard_unconfigured_mode)) then
        begin
            m_compartment_state_inited := False;
            apply_engine_state_to_compartments(next_input_mode, next_full_width,
                next_punctuation_full_width);
        end;
        if not (rejected_transition or guard_unconfigured_mode) then
        begin
            // Trace-assisted shortcuts are normalized on the next ordinary key.
            // A queued restoration has not synchronized Windows state yet.
            m_compartment_state_inited := (not external_transition) and
                has_openclose and has_conversion and
                (not m_compartment_deferred.pending);
        end;
        if state_changed and (not guard_unconfigured_mode) then
        begin
            save_engine_state_to_config(next_input_mode, next_full_width,
                next_punctuation_full_width);
        end;
        if next_input_mode = im_english then
        begin
            cancel_composition;
        end;
        if external_transition_settled then
        begin
            m_external_input_mode_transition_pending := False;
            m_external_input_mode_transition_tick := 0;
        end;
    end;

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format(
            'Compartment change source=%d open=%d/%d conversion=%d/0x%s pending=%d settled=%d rejected=%d ' +
            'terminal=%d host=%d/%d target=%d state=%d/%d/%d changed=%d host_synced=%d compartment_synced=%d ' +
            'deferred=%d disabled=%d shortcut=%s ctrl=%d ctrl_guard=%d pid=%d tid=%d open_read_hr=0x%s conversion_read_hr=0x%s ' +
            'previous=%d/%d/%d host_preferences=%d/%d punctuation_disabled=%d full_width_disabled=%d preferences_restore=%d',
            [Ord(change_source), Ord(has_openclose), openclose_value,
            Ord(has_conversion), IntToHex(conversion_value, 8),
            Ord(external_transition), Ord(external_transition_settled),
            Ord(rejected_transition),
            Ord(terminal_compatibility_target), Ord(host_state_available),
            Ord(host_state_matches_proposed),
            Ord(m_external_input_mode_target),
            Ord(next_input_mode), Ord(next_full_width),
            Ord(next_punctuation_full_width), Ord(state_changed),
            Ord(state_synced), Ord(m_compartment_state_inited),
            Ord((m_compartment_deferred <> nil) and m_compartment_deferred.pending),
            Ord(m_shortcut_config.input_mode_toggle.disabled),
            nc_shortcut_to_text(m_shortcut_config.input_mode_toggle),
            Ord(key_state.ctrl_down), Ord(ctrl_space_rejected),
            GetCurrentProcessId, GetCurrentThreadId,
            IntToHex(Cardinal(open_read_status), 8), IntToHex(Cardinal(conversion_read_status), 8),
            Ord(previous_input_mode), Ord(previous_full_width), Ord(previous_punctuation_full_width),
            Ord(host_full_width), Ord(host_punctuation_full_width),
            Ord(m_shortcut_config.punctuation_toggle.disabled),
            Ord(m_shortcut_config.full_width_toggle.disabled), Ord(restore_conversion_preferences)]));
    end;

    Result := S_OK;
end;

function TncTextService.OnChange(var rguid: TGUID): HResult;
begin
    Result := S_OK;
    try
        if m_compartment_deferred = nil then
            m_compartment_deferred := TncTsfDeferredCompartmentSync.Create(flush_deferred_compartment_state);
        m_compartment_deferred.BeginNotification;
        try
            Result := on_compartment_change_core(rguid);
        finally
            if not m_compartment_deferred.EndNotification and (m_logger <> nil) then
                m_logger.warn(Format('Compartment deferred sync post failed error=%d',
                    [m_compartment_deferred.last_error]));
        end;
    except
        log_tsf_boundary_exception('CompartmentEventSink.OnChange');
    end;
end;

function TncTextService.EnumDisplayAttributeInfo(out ppenum: IEnumTfDisplayAttributeInfo): HResult;
begin
    ppenum := nil;
    Result := E_FAIL;
    try
        if m_display_attribute_provider <> nil then
        begin
            Result := m_display_attribute_provider.EnumDisplayAttributeInfo(ppenum);
        end;
    except
        ppenum := nil;
        log_tsf_boundary_exception('DisplayAttributeProvider.EnumDisplayAttributeInfo');
    end;
end;

function TncTextService.GetDisplayAttributeInfo(var GUID: TGUID; out ppInfo: ITfDisplayAttributeInfo): HResult;
begin
    ppInfo := nil;
    Result := E_FAIL;
    try
        if m_display_attribute_provider <> nil then
        begin
            Result := m_display_attribute_provider.GetDisplayAttributeInfo(GUID, ppInfo);
        end;
    except
        ppInfo := nil;
        log_tsf_boundary_exception('DisplayAttributeProvider.GetDisplayAttributeInfo');
    end;
end;

function TncTextService.build_key_state: TncKeyState;
    function modifier_is_down(const generic_key: Integer; const left_key: Integer;
        const right_key: Integer): Boolean;
    var
        key_bits: Word;
    begin
        key_bits := Word(GetKeyState(generic_key)) or Word(GetAsyncKeyState(generic_key)) or
            Word(GetKeyState(left_key)) or Word(GetAsyncKeyState(left_key)) or
            Word(GetKeyState(right_key)) or Word(GetAsyncKeyState(right_key));
        Result := (key_bits and $8000) <> 0;
    end;
begin
    Result.shift_down := modifier_is_down(VK_SHIFT, VK_LSHIFT, VK_RSHIFT);
    Result.ctrl_down := modifier_is_down(VK_CONTROL, VK_LCONTROL, VK_RCONTROL);
    Result.alt_down := modifier_is_down(VK_MENU, VK_LMENU, VK_RMENU);
    Result.caps_lock := (GetKeyState(VK_CAPITAL) and 1) <> 0;
end;

function TncTextService.is_safe_composition_fast_key(const key_code: Word;
    const key_state: TncKeyState): Boolean;
begin
    Result := False;
    if (m_composition = nil) or key_state.shift_down or key_state.ctrl_down or key_state.alt_down then
    begin
        Exit;
    end;

    Result := ((key_code >= Ord('A')) and (key_code <= Ord('Z'))) or
        ((key_code >= Ord('0')) and (key_code <= Ord('9'))) or
        (key_code = VK_OEM_7) or
        (key_code = VK_BACK) or
        (key_code = VK_SPACE) or
        (key_code = VK_RETURN) or
        // Do not drop a paging key merely because TEST_KEY cannot reach the
        // cold/warming host. PROCESS_KEY remains authoritative for the action.
        nc_composition_navigation_skips_host_test(key_code, key_state);
end;

function TncTextService.get_config_write_time: TDateTime;
begin
    Result := 0;
    try
        if (m_config_path <> '') and FileExists(m_config_path) then
        begin
            Result := TFile.GetLastWriteTime(m_config_path);
        end;
    except
        Result := 0;
    end;
end;

procedure TncTextService.load_engine_config(out config: TncEngineConfig);
var
    config_manager: TncConfigManager;
    host_shortcut_config: TncShortcutConfig;
    host_input_mode: TncInputMode;
    host_full_width_mode: Boolean;
    host_punctuation_full_width: Boolean;
    host_sync_error: DWORD;
begin
    host_sync_error := ERROR_SUCCESS;
    config := nc_default_engine_config;
    config_manager := nil;
    try
        try
            // TSF runs in arbitrary client processes, including sandboxed ones.
            // Reading config must not create a named kernel object or rewrite files.
            config_manager := TncConfigManager.create(m_config_path, clmReadOnly);
            config := config_manager.load_engine_config;
            m_log_config := config_manager.load_log_config;
        finally
            config_manager.Free;
        end;
    except
        log_tsf_boundary_exception('LoadEngineConfig');
        config := nc_default_engine_config;
        m_log_config.enabled := False;
        m_log_config.level := ll_info;
        m_log_config.max_size_kb := 1024;
        m_log_config.log_path := '';
    end;

    // TMemIniFile can silently return defaults when a packaged client can see
    // the shared path metadata but cannot open its contents. The host process
    // therefore remains authoritative even when FileExists returned true.
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        if m_ipc_client.get_shortcut_config(m_session_id,
            host_shortcut_config) then
        begin
            config.shortcuts := host_shortcut_config;
        end;
        if m_ipc_client.get_state(m_session_id, host_input_mode,
            host_full_width_mode, host_punctuation_full_width) then
        begin
            config.input_mode := host_input_mode;
            config.full_width_mode := host_full_width_mode;
            config.punctuation_full_width := host_punctuation_full_width;
        end;
        host_sync_error := m_ipc_client.last_error;
    end;

    apply_shortcut_config(config.shortcuts);
    m_loaded_config_write_time := get_config_write_time;
    m_last_config_check_tick := GetTickCount64;
    try
        apply_log_config;
    except
        log_tsf_boundary_exception('ApplyLogConfig');
        free_logger;
    end;
    if (host_sync_error <> ERROR_SUCCESS) and (m_logger <> nil) and
        (host_sync_error <> m_last_ipc_error) then
    begin
        m_last_ipc_error := host_sync_error;
        m_logger.warn(Format('TSF host sync unavailable err=%d (%s) startup=[%s]',
            [host_sync_error, SysErrorMessage(host_sync_error), m_ipc_client.last_start_detail]));
    end;
    refresh_preserved_input_mode_shortcut;
    refresh_terminal_ctrl_space_hook;
end;

procedure TncTextService.apply_shortcut_config(const config: TncShortcutConfig);
var
    normalized: TncShortcutConfig;
begin
    normalized := config;
    nc_normalize_shortcut_config(normalized);
    if not nc_shortcut_equal(m_shortcut_config.input_mode_toggle,
        normalized.input_mode_toggle) then
    begin
        // An in-flight preserved/legacy callback belongs to the old binding.
        // Do not let it authorize a toggle after Apply or after Disable.
        m_modifier_shortcut_pending := False;
        m_modifier_shortcut_canceled := False;
        m_modifier_shortcut_key_code := 0;
        m_chord_shortcut_pending := False;
        m_chord_shortcut_key_code := 0;
        m_chord_shortcut_tick := 0;
        m_chord_shortcut_source := tses_key_sink;
        m_external_input_mode_transition_pending := False;
        m_external_input_mode_transition_tick := 0;
        clear_system_input_mode_shortcut_prefix;
        clear_rejected_modifier_transition;
        m_unconfigured_ctrl_space_pending := False;
    end;
    m_shortcut_config := normalized;
end;

procedure TncTextService.apply_log_config;
var
    resolved_log_path: string;
begin
    if not m_log_config.enabled then
    begin
        free_logger;
        Exit;
    end;

    resolved_log_path := Trim(m_log_config.log_path);
    if resolved_log_path = '' then
    begin
        resolved_log_path := get_default_log_path;
    end;

    if (m_logger <> nil) and (m_logger.log_path <> resolved_log_path) then
    begin
        free_logger;
    end;

    if m_logger = nil then
    begin
        m_logger := TncLogger.create(resolved_log_path, m_log_config.max_size_kb);
    end;
    m_logger.set_level(m_log_config.level);
end;

procedure TncTextService.reload_config_if_needed(const force_check: Boolean);
const
    c_config_reload_check_interval_ms = 1000;
var
    current_write_time: TDateTime;
    engine_config: TncEngineConfig;
    now_tick: UInt64;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    // A forced refresh is used when a key matches the cached shortcut or when
    // Terminal's low-level compatibility hook fires. Read the host-owned
    // shortcut state even when the file timestamp has not advanced yet.
    if force_check then
    begin
        load_engine_config(engine_config);
        Exit;
    end;

    now_tick := GetTickCount64;
    if (m_last_config_check_tick <> 0) and
        ((now_tick - m_last_config_check_tick) < c_config_reload_check_interval_ms) then
    begin
        Exit;
    end;
    m_last_config_check_tick := now_tick;

    current_write_time := get_config_write_time;
    if current_write_time = 0 then
    begin
        Exit;
    end;
    if current_write_time = m_loaded_config_write_time then
    begin
        Exit;
    end;

    load_engine_config(engine_config);
end;

procedure TncTextService.save_engine_state_to_config(const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean);
var
    config_manager: TncConfigManager;
    engine_config: TncEngineConfig;
    changed: Boolean;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    config_manager := nil;
    try
        try
            config_manager := TncConfigManager.create(m_config_path, clmBestEffort);
            engine_config := config_manager.load_engine_config;
            changed := (engine_config.input_mode <> input_mode) or
                (engine_config.full_width_mode <> full_width_mode) or
                (engine_config.punctuation_full_width <> punctuation_full_width);
            if changed then
            begin
                engine_config.input_mode := input_mode;
                engine_config.full_width_mode := full_width_mode;
                engine_config.punctuation_full_width := punctuation_full_width;
                config_manager.save_engine_state_config(input_mode, full_width_mode,
                    punctuation_full_width);
                // Do not advance m_loaded_config_write_time here. This write only
                // persists runtime state; treating it as a complete config
                // reload can permanently hide shortcut changes made by the
                // settings process immediately beforehand.
            end;
        finally
            config_manager.Free;
        end;
    except
        log_tsf_boundary_exception('SaveEngineState');
    end;
end;

var
    g_input_epoch_counter: Int64 = 0;

// Process-wide and monotonic, so the epochs of every session only increase.
function next_input_epoch: UInt64;
begin
    Result := UInt64(AtomicIncrement(g_input_epoch_counter));
end;

procedure signal_tray_profile_event(const active: Boolean);
var
    event_handle: THandle;
    event_name: string;
begin
    if active then
    begin
        event_name := get_nc_active_event;
    end
    else
    begin
        event_name := get_nc_inactive_event;
    end;

    event_handle := CreateEvent(nil, False, False, PChar(event_name));
    if event_handle <> 0 then
    begin
        try
            SetEvent(event_handle);
        finally
            CloseHandle(event_handle);
        end;
    end;
end;

procedure TncTextService.update_active_state(const active: Boolean);
begin
    if (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;
    // SET_ACTIVE creates and prewarms a cold host session. Never perform that
    // work on the application's TSF activation/focus callback thread.
    queue_active_state_update(active);
end;

function TncTextService.get_candidate_point(out point: TPoint; out placement_line_height: Integer;
    out terminal_like_target: Boolean; out chosen_source: TncCaretAnchorSource; out chosen_score: Integer): Boolean;
var
    caret_point: TPoint;
    gui_point: TPoint;
    imm_point: TPoint;
    comless_fallback_point: TPoint;
    converted_tsf_point: TPoint;
    last_sent_point: TPoint;
    hwnd: Winapi.Windows.HWND;
    foreground_hwnd: Winapi.Windows.HWND;
    context_hwnd: Winapi.Windows.HWND;
    tsf_point: TPoint;
    tsf_point_valid: Boolean;
    caret_point_valid: Boolean;
    gui_point_valid: Boolean;
    imm_point_valid: Boolean;
    virtual_left: Integer;
    virtual_top: Integer;
    virtual_right: Integer;
    virtual_bottom: Integer;
    gui_info: TncGuiThreadInfo;
    gui_thread_id: DWORD;
    gui_caret_hwnd: Winapi.Windows.HWND;
    foreground_rect: TRect;
    has_foreground_rect: Boolean;
    context_rect: TRect;
    has_context_rect: Boolean;
    view: ITfContextView;
    context_class_name: string;
    foreground_class_name: string;
    terminal_like_context: Boolean;
    terminal_like_foreground: Boolean;
    focus_outside_context: Boolean;
    cursor_point: TPoint;
    cursor_point_valid: Boolean;
    last_sent_point_valid: Boolean;
    observations: array[0..5] of TncCaretAnchorObservation;
    observation_count: Integer;
    anchor_context: TncCaretAnchorContext;
    tsf_suspicious: Boolean;
    gui_suspicious: Boolean;
    caret_suspicious: Boolean;
    last_suspicious: Boolean;
    gui_caret_pair: Boolean;
    gui_far_from_tsf: Boolean;
    comless_target: Boolean;
    photoshop_canvas_target: Boolean;
    probe_imm: Boolean;
    suspicion_rect: TRect;
    has_suspicion_rect: Boolean;
    imm_line_height: Integer;
    imm_anchor_hwnd: Winapi.Windows.HWND;
    imm_anchor_kind: string;
    caret_debug_logging: Boolean;
    current_tick: UInt64;

    function point_in_virtual_screen(const candidate: TPoint): Boolean;
    const
        c_margin = 200;
    begin
        Result := (candidate.X >= virtual_left - c_margin) and (candidate.X <= virtual_right + c_margin) and
            (candidate.Y >= virtual_top - c_margin) and (candidate.Y <= virtual_bottom + c_margin);
    end;

    function point_in_foreground(const candidate: TPoint): Boolean;
    const
        c_margin_terminal = 200;
        c_margin_normal = 96;
    begin
        if terminal_like_target and has_foreground_rect then
        begin
            Result := (candidate.X >= foreground_rect.Left - c_margin_terminal) and
                (candidate.X <= foreground_rect.Right + c_margin_terminal) and
                (candidate.Y >= foreground_rect.Top - c_margin_terminal) and
                (candidate.Y <= foreground_rect.Bottom + c_margin_terminal);
            Exit;
        end;

        if has_context_rect then
        begin
            Result := (candidate.X >= context_rect.Left - c_margin_normal) and
                (candidate.X <= context_rect.Right + c_margin_normal) and
                (candidate.Y >= context_rect.Top - c_margin_normal) and
                (candidate.Y <= context_rect.Bottom + c_margin_normal);
            Exit;
        end;

        if not has_foreground_rect then
        begin
            Result := True;
            Exit;
        end;

        Result := (candidate.X >= foreground_rect.Left - c_margin_normal) and
            (candidate.X <= foreground_rect.Right + c_margin_normal) and
            (candidate.Y >= foreground_rect.Top - c_margin_normal) and
            (candidate.Y <= foreground_rect.Bottom + c_margin_normal);
    end;

    function point_in_rect(const candidate: TPoint; const bounds: TRect; const margin: Integer): Boolean;
    begin
        Result := (candidate.X >= bounds.Left - margin) and (candidate.X <= bounds.Right + margin) and
            (candidate.Y >= bounds.Top - margin) and (candidate.Y <= bounds.Bottom + margin);
    end;

    function try_normalize_anchor_point(const source_hwnd: Winapi.Windows.HWND; var candidate: TPoint): Boolean;
    var
        client_rect: TRect;
        window_rect: TRect;
        adjusted: TPoint;
        has_window_rect: Boolean;
    begin
        Result := False;
        if source_hwnd = 0 then
        begin
            Exit;
        end;

        has_window_rect := GetWindowRect(source_hwnd, window_rect);
        if has_window_rect then
        begin
            try_normalize_screen_rect_for_hwnd(source_hwnd, window_rect);
        end;
        if has_window_rect and point_in_rect(candidate, window_rect, 64) then
        begin
            Result := point_in_virtual_screen(candidate);
            Exit;
        end;

        if has_context_rect and point_in_rect(candidate, context_rect, 64) then
        begin
            Result := point_in_virtual_screen(candidate);
            Exit;
        end;

        if has_foreground_rect and point_in_rect(candidate, foreground_rect, 64) then
        begin
            Result := point_in_virtual_screen(candidate);
            Exit;
        end;

        if not GetClientRect(source_hwnd, client_rect) then
        begin
            Exit;
        end;

        if point_in_rect(candidate, client_rect, 32) then
        begin
            adjusted := candidate;
            if try_client_point_to_screen_physical(source_hwnd, adjusted) then
            begin
                candidate := adjusted;
                Result := point_in_virtual_screen(candidate);
                Exit;
            end;
        end;

        adjusted := candidate;
        if try_client_point_to_screen_physical(source_hwnd, adjusted) then
        begin
            if (not has_window_rect) or point_in_rect(adjusted, window_rect, 200) then
            begin
                candidate := adjusted;
                Result := point_in_virtual_screen(candidate);
                Exit;
            end;
        end;
    end;

    function try_adjust_terminal_client_point(var candidate: TPoint): Boolean;
    var
        base_rect: TRect;
        adjusted: TPoint;
        has_base_rect: Boolean;
        base_hwnd: Winapi.Windows.HWND;
    begin
        Result := False;
        if not terminal_like_target then
        begin
            Exit;
        end;

        has_base_rect := False;
        base_hwnd := 0;
        if has_foreground_rect then
        begin
            base_rect := foreground_rect;
            has_base_rect := True;
            base_hwnd := foreground_hwnd;
        end
        else if has_context_rect then
        begin
            base_rect := context_rect;
            has_base_rect := True;
            base_hwnd := context_hwnd;
        end;
        if not has_base_rect then
        begin
            Exit;
        end;

        // Already looks like screen coordinates around target window.
        if point_in_rect(candidate, base_rect, 32) then
        begin
            Exit;
        end;

        // Treat as client-relative and map to screen.
        adjusted := candidate;
        if not try_client_point_to_screen_physical(base_hwnd, adjusted) then
        begin
            Exit;
        end;
        if point_in_rect(adjusted, base_rect, 200) and point_in_virtual_screen(adjusted) then
        begin
            candidate := adjusted;
            Result := True;
        end;
    end;

    function get_window_class_name(const window_handle: Winapi.Windows.HWND): string;
    var
        class_buffer: array[0..255] of Char;
        class_len: Integer;
    begin
        Result := '';
        if window_handle = 0 then
        begin
            Exit;
        end;

        class_len := GetClassName(window_handle, class_buffer, Length(class_buffer));
        if class_len > 0 then
        begin
            SetString(Result, class_buffer, class_len);
        end;
    end;

    function is_terminal_like_class(const class_name: string): Boolean;
    var
        class_lower: string;
    begin
        if class_name = '' then
        begin
            Result := False;
            Exit;
        end;

        class_lower := LowerCase(class_name);
        Result := (Pos('consolewindowclass', class_lower) > 0) or
            (Pos('cascadia_hosting_window_class', class_lower) > 0) or
            (Pos('terminal', class_lower) > 0) or
            (Pos('pseudoconsole', class_lower) > 0);
    end;

    function try_get_imm_anchor_point(const source_hwnd: Winapi.Windows.HWND;
        out candidate: TPoint; out candidate_line_height: Integer;
        out anchor_kind: string): Boolean;
    var
        input_context: HIMC;
        composition_form: TCompositionForm;
        candidate_form: TCandidateForm;
        candidate_index: Integer;
        best_score: Integer;
        client_rect: TRect;
        has_client_rect: Boolean;

        procedure consider_local_anchor(const local_point: TPoint;
            const local_line_height: Integer; const local_score: Integer;
            const local_kind: string);
        var
            screen_point: TPoint;
        begin
            if imm_anchor_is_placeholder(local_point, client_rect,
                has_client_rect, comless_target) then
            begin
                Exit;
            end;

            screen_point := local_point;
            if not try_client_point_to_screen_physical(source_hwnd, screen_point) then
            begin
                Exit;
            end;
            if (not point_in_virtual_screen(screen_point)) or
                (not point_in_foreground(screen_point)) then
            begin
                Exit;
            end;
            if local_score <= best_score then
            begin
                Exit;
            end;

            best_score := local_score;
            candidate := screen_point;
            candidate_line_height := local_line_height;
            anchor_kind := local_kind;
        end;

        function rect_line_height(const bounds: TRect): Integer;
        begin
            Result := bounds.Bottom - bounds.Top;
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;

        function rect_has_area(const bounds: TRect): Boolean;
        begin
            Result := (bounds.Right > bounds.Left) and
                (bounds.Bottom > bounds.Top);
        end;
    begin
        candidate := System.Types.Point(0, 0);
        candidate_line_height := 0;
        anchor_kind := '';
        best_score := Low(Integer);
        has_client_rect := GetClientRect(source_hwnd, client_rect);
        Result := False;
        if source_hwnd = 0 then
        begin
            Exit;
        end;

        input_context := ImmGetContext(source_hwnd);
        if input_context = 0 then
        begin
            if caret_debug_logging then
            begin
                m_logger.debug(Format('IMM probe hwnd=%d context=none', [source_hwnd]));
            end;
            Exit;
        end;
        try
            FillChar(composition_form, SizeOf(composition_form), 0);
            if ImmGetCompositionWindow(input_context, @composition_form) then
            begin
                if caret_debug_logging then
                begin
                    m_logger.debug(Format('IMM composition hwnd=%d style=%d point=(%d,%d) area=(%d,%d,%d,%d)',
                        [source_hwnd, composition_form.dwStyle,
                        composition_form.ptCurrentPos.X, composition_form.ptCurrentPos.Y,
                        composition_form.rcArea.Left, composition_form.rcArea.Top,
                        composition_form.rcArea.Right, composition_form.rcArea.Bottom]));
                end;
                case composition_form.dwStyle of
                    CFS_FORCE_POSITION:
                        consider_local_anchor(composition_form.ptCurrentPos,
                            0, 420, 'composition-force');
                    CFS_POINT:
                        consider_local_anchor(composition_form.ptCurrentPos,
                            0, 400, 'composition-point');
                    CFS_RECT:
                        if rect_has_area(composition_form.rcArea) then
                        begin
                            consider_local_anchor(System.Types.Point(
                                composition_form.rcArea.Left,
                                composition_form.rcArea.Bottom),
                                rect_line_height(composition_form.rcArea),
                                340, 'composition-rect');
                        end;
                end;
            end;

            for candidate_index := 0 to 3 do
            begin
                FillChar(candidate_form, SizeOf(candidate_form), 0);
                candidate_form.dwIndex := candidate_index;
                if not ImmGetCandidateWindow(input_context,
                    candidate_index, @candidate_form) then
                begin
                    Continue;
                end;
                if caret_debug_logging then
                begin
                    m_logger.debug(Format('IMM candidate hwnd=%d index=%d style=%d point=(%d,%d) area=(%d,%d,%d,%d)',
                        [source_hwnd, candidate_index, candidate_form.dwStyle,
                        candidate_form.ptCurrentPos.X, candidate_form.ptCurrentPos.Y,
                        candidate_form.rcArea.Left, candidate_form.rcArea.Top,
                        candidate_form.rcArea.Right, candidate_form.rcArea.Bottom]));
                end;
                case candidate_form.dwStyle of
                    CFS_EXCLUDE:
                        begin
                            consider_local_anchor(candidate_form.ptCurrentPos,
                                rect_line_height(candidate_form.rcArea),
                                460, 'candidate-exclude');
                            if imm_anchor_is_placeholder(
                                candidate_form.ptCurrentPos, client_rect,
                                has_client_rect, comless_target) and
                                rect_has_area(candidate_form.rcArea) then
                            begin
                                consider_local_anchor(System.Types.Point(
                                    candidate_form.rcArea.Left,
                                    candidate_form.rcArea.Bottom),
                                    rect_line_height(candidate_form.rcArea),
                                    440, 'candidate-exclude-rect');
                            end;
                        end;
                    CFS_CANDIDATEPOS:
                        consider_local_anchor(candidate_form.ptCurrentPos,
                            0, 450, 'candidate-position');
                end;
            end;
        finally
            ImmReleaseContext(source_hwnd, input_context);
        end;
        Result := best_score > Low(Integer);
    end;

    function format_anchor_point(const candidate: TPoint; const valid: Boolean): string;
    begin
        if valid then
        begin
            Result := Format('(%d,%d)', [candidate.X, candidate.Y]);
        end
        else
        begin
            Result := 'invalid';
        end;
    end;

    function try_get_canvas_character_point(out candidate: TPoint;
        out candidate_line_height: Integer): Boolean;
    var
        position: TncImeCharPosition;
        query_result: TncImeCharPositionResult;
        caret_rect: TRect;
        document_serial: UInt64;
    begin
        Result := False;
        candidate := System.Types.Point(0, 0);
        candidate_line_height := 0;
        // Photoshop's canvas may expose neither a TSF text rectangle nor a
        // Win32 caret, but implements IMR_QUERYCHARPOSITION for its text tool.
        // Keep this compatibility fallback out of standard edits and games.
        if not photoshop_canvas_target or (m_composition = nil) then
        begin
            Exit;
        end;
        document_serial := m_document_context_serial;
        query_result := query_ime_char_position(hwnd, position,
            icpp_photoshop_canvas);
        if caret_debug_logging then
        begin
            m_logger.debug(Format(
                'IMM char-position hwnd=%d result=%s point=(%d,%d) line=%d document=(%d,%d,%d,%d)',
                [hwnd, ime_char_position_result_name(query_result),
                position.point.X, position.point.Y, position.line_height,
                position.document_rect.Left, position.document_rect.Top,
                position.document_rect.Right, position.document_rect.Bottom]));
        end;
        if (m_composition = nil) or
            (document_serial <> m_document_context_serial) or
            (GetFocus <> hwnd) or (GetForegroundWindow <> foreground_hwnd) then
        begin
            Exit;
        end;
        if not (query_result in [icpr_success, icpr_success_compat]) then
        begin
            m_pending_canvas_caret := query_result in [icpr_unsupported, icpr_invalid];
            Exit;
        end;
        if not ime_char_position_rect(position, caret_rect,
            icpp_photoshop_canvas) then
            Exit;
        // This API already returns screen coordinates, unlike CANDIDATEFORM.
        // Normalize DPI once; do not apply ClientToScreen a second time.
        try_normalize_screen_rect_for_hwnd(hwnd, caret_rect);
        candidate := System.Types.Point(caret_rect.Left, caret_rect.Bottom);
        candidate_line_height := caret_rect.Bottom - caret_rect.Top;
        Result := point_in_virtual_screen(candidate) and
            point_in_foreground(candidate);
    end;

    function try_get_gui_caret_point(const thread_id: DWORD; out candidate: TPoint): Boolean;
    var
        caret_hwnd: Winapi.Windows.HWND;
    begin
        candidate := System.Types.Point(0, 0);
        gui_caret_hwnd := 0;
        FillChar(gui_info, SizeOf(gui_info), 0);
        gui_info.cbSize := SizeOf(gui_info);
        if not nc_get_gui_thread_info(thread_id, gui_info) then
        begin
            Result := False;
            Exit;
        end;
        if caret_debug_logging then
        begin
            m_logger.debug(Format('GUI caret raw thread=%d hwnd=%d focus=%d rect=(%d,%d,%d,%d)',
                [thread_id, gui_info.hwndCaret, gui_info.hwndFocus,
                gui_info.rcCaret.Left, gui_info.rcCaret.Top,
                gui_info.rcCaret.Right, gui_info.rcCaret.Bottom]));
        end;
        if not gui_caret_rect_is_usable(gui_info.rcCaret) then
        begin
            Result := False;
            Exit;
        end;
        caret_hwnd := gui_info.hwndCaret;
        if caret_hwnd = 0 then
        begin
            // Terminal/ConPTY hosts may not expose hwndCaret, but rcCaret can
            // still be relative to focused window.
            caret_hwnd := gui_info.hwndFocus;
        end;
        if caret_hwnd = 0 then
        begin
            Result := False;
            Exit;
        end;
        gui_caret_hwnd := caret_hwnd;

        candidate := System.Types.Point(gui_info.rcCaret.Left, gui_info.rcCaret.Bottom);
        // GUITHREADINFO.rcCaret is client-relative to hwndCaret/hwndFocus.
        if not try_client_point_to_screen_physical(caret_hwnd, candidate) then
        begin
            if not try_normalize_anchor_point(caret_hwnd, candidate) then
            begin
                Result := False;
                Exit;
            end;
        end;
        Result := point_in_virtual_screen(candidate) and point_in_foreground(candidate);
        if (not Result) and caret_debug_logging then
        begin
            m_logger.debug(Format('GUI caret outside foreground point=(%d,%d) rect=(%d,%d,%d,%d)',
                [candidate.X, candidate.Y, foreground_rect.Left, foreground_rect.Top, foreground_rect.Right,
                foreground_rect.Bottom]));
        end;
    end;

    procedure add_observation(const source: TncCaretAnchorSource; const candidate: TPoint; const valid: Boolean);
    begin
        if observation_count >= Length(observations) then
        begin
            Exit;
        end;
        observations[observation_count].source := source;
        observations[observation_count].point := candidate;
        observations[observation_count].valid := valid;
        Inc(observation_count);
    end;
begin
    point := System.Types.Point(0, 0);
    m_pending_canvas_caret := False;
    current_tick := GetTickCount64;
    caret_debug_logging := (m_logger <> nil) and (m_logger.level <= ll_debug) and
        ((m_last_caret_debug_tick = 0) or
        (current_tick - m_last_caret_debug_tick >= 250));
    if caret_debug_logging then
    begin
        m_last_caret_debug_tick := current_tick;
    end;
    terminal_like_target := False;
    comless_target := (m_activation_flags and TF_TMAE_COMLESS) <> 0;
    chosen_source := casCursor;
    chosen_score := 0;
    virtual_left := GetSystemMetrics(SM_XVIRTUALSCREEN);
    virtual_top := GetSystemMetrics(SM_YVIRTUALSCREEN);
    virtual_right := virtual_left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
    virtual_bottom := virtual_top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
    placement_line_height := m_last_caret_line_height;
    tsf_point := m_last_caret_point;
    tsf_point_valid := m_has_caret_point;
    last_sent_point := m_last_sent_caret_point;

    gui_point_valid := False;
    gui_thread_id := 0;
    gui_caret_hwnd := 0;
    context_hwnd := 0;
    has_context_rect := False;
    context_rect := System.Types.Rect(0, 0, 0, 0);
    if (m_context <> nil) and (m_context.GetActiveView(view) = S_OK) and (view <> nil) then
    begin
        if view.GetWnd(context_hwnd) = S_OK then
        begin
            has_context_rect := GetWindowRect(context_hwnd, context_rect);
            if has_context_rect then
            begin
                try_normalize_screen_rect_for_hwnd(context_hwnd, context_rect);
                // An input site without an area bounds nothing: the
                // foreground window does (context_rect_bounds_caret).
                has_context_rect := context_rect_bounds_caret(context_rect);
            end;
        end;
    end;

    hwnd := GetFocus;
    foreground_hwnd := GetForegroundWindow;
    if context_hwnd <> 0 then
    begin
        gui_thread_id := GetWindowThreadProcessId(context_hwnd, nil);
    end
    else if hwnd <> 0 then
    begin
        gui_thread_id := GetWindowThreadProcessId(hwnd, nil);
    end
    else if foreground_hwnd <> 0 then
    begin
        gui_thread_id := GetWindowThreadProcessId(foreground_hwnd, nil);
    end;

    has_foreground_rect := False;
    foreground_rect := System.Types.Rect(0, 0, 0, 0);
    if foreground_hwnd <> 0 then
    begin
        has_foreground_rect := GetWindowRect(foreground_hwnd, foreground_rect);
        if has_foreground_rect then
        begin
            try_normalize_screen_rect_for_hwnd(foreground_hwnd, foreground_rect);
        end;
    end;

    context_class_name := get_window_class_name(context_hwnd);
    foreground_class_name := get_window_class_name(foreground_hwnd);
    photoshop_canvas_target := not comless_target and (hwnd <> 0) and
        (hwnd = context_hwnd) and SameText(context_class_name, 'PSViewC') and
        SameText(foreground_class_name, 'Photoshop');
    terminal_like_context := is_terminal_like_class(context_class_name);
    terminal_like_foreground := is_terminal_like_class(foreground_class_name);
    terminal_like_target := terminal_like_context or terminal_like_foreground;
    focus_outside_context := (context_hwnd <> 0) and (hwnd <> 0) and (hwnd <> context_hwnd) and
        (not IsChild(context_hwnd, hwnd));
    cursor_point := System.Types.Point(0, 0);
    cursor_point_valid := GetCursorPos(cursor_point) and point_in_virtual_screen(cursor_point) and
        point_in_foreground(cursor_point);
    if tsf_point_valid and terminal_like_target then
    begin
        converted_tsf_point := tsf_point;
        if try_adjust_terminal_client_point(converted_tsf_point) then
        begin
            if caret_debug_logging and
                ((converted_tsf_point.X <> tsf_point.X) or (converted_tsf_point.Y <> tsf_point.Y)) then
            begin
                m_logger.debug(Format('Terminal TSF point client-adjust (%d,%d)->(%d,%d)',
                    [tsf_point.X, tsf_point.Y, converted_tsf_point.X, converted_tsf_point.Y]));
            end;
            tsf_point := converted_tsf_point;
        end;
    end;
    tsf_point_valid := tsf_point_valid and point_in_virtual_screen(tsf_point);

    if caret_debug_logging then
    begin
        m_logger.debug(Format('Caret hwnd context=%d focus=%d foreground=%d thread=%d',
            [context_hwnd, hwnd, foreground_hwnd, gui_thread_id]));
        if context_class_name <> '' then
        begin
            m_logger.debug(Format('Caret context class=%s terminal=%d', [context_class_name, Ord(terminal_like_context)]));
        end;
        if foreground_class_name <> '' then
        begin
            m_logger.debug(Format('Caret foreground class=%s terminal=%d',
                [foreground_class_name, Ord(terminal_like_foreground)]));
        end;
        if has_context_rect then
        begin
            m_logger.debug(Format('Caret context rect=(%d,%d,%d,%d)',
                [context_rect.Left, context_rect.Top, context_rect.Right, context_rect.Bottom]));
        end
        else if context_hwnd <> 0 then
        begin
            m_logger.debug(Format('Caret context rect=(%d,%d,%d,%d) has no area, not a bound',
                [context_rect.Left, context_rect.Top, context_rect.Right, context_rect.Bottom]));
        end;
        if has_foreground_rect then
        begin
            m_logger.debug(Format('Caret foreground rect=(%d,%d,%d,%d)',
                [foreground_rect.Left, foreground_rect.Top, foreground_rect.Right, foreground_rect.Bottom]));
        end;
        if focus_outside_context then
        begin
            m_logger.debug(Format('Caret focus outside context focus=%d context=%d', [hwnd, context_hwnd]));
        end;
    end;

    if gui_thread_id <> 0 then
    begin
        gui_point_valid := try_get_gui_caret_point(gui_thread_id, gui_point);
    end;

    if not gui_point_valid then
    begin
        if try_get_gui_caret_point(0, gui_point) then
        begin
            gui_point_valid := True;
            gui_thread_id := 0;
        end;
    end;
    caret_point_valid := False;
    // GetCaretPos can succeed with a stale point even when no caret exists.
    // It belongs to the calling thread's caret owner, not necessarily GetFocus.
    if (gui_caret_hwnd <> 0) and
        (GetWindowThreadProcessId(gui_caret_hwnd, nil) = GetCurrentThreadId) and
        GetCaretPos(caret_point) then
    begin
        if not try_client_point_to_screen_physical(gui_caret_hwnd, caret_point) then
        begin
            try_normalize_anchor_point(gui_caret_hwnd, caret_point);
        end;
        if terminal_like_target then
        begin
            try_adjust_terminal_client_point(caret_point);
        end;
        caret_point_valid := point_in_virtual_screen(caret_point) and point_in_foreground(caret_point);
        if (not caret_point_valid) and caret_debug_logging then
        begin
            m_logger.debug(Format('CaretPos outside foreground point=(%d,%d) rect=(%d,%d,%d,%d)',
                [caret_point.X, caret_point.Y, foreground_rect.Left, foreground_rect.Top, foreground_rect.Right,
                foreground_rect.Bottom]));
        end;
    end;

    tsf_point_valid := tsf_point_valid and point_in_foreground(tsf_point);
    last_sent_point_valid := m_last_sent_caret_valid and m_last_sent_has_caret and
        (m_composition <> nil) and point_in_virtual_screen(last_sent_point) and
        point_in_foreground(last_sent_point);
    if focus_outside_context and (not terminal_like_target) then
    begin
        tsf_point_valid := False;
        last_sent_point_valid := False;
    end;

    if tsf_point_valid and caret_debug_logging then
    begin
        m_logger.debug(Format('TSF caret point=(%d,%d) composition=%d', [tsf_point.X, tsf_point.Y,
            Ord(m_composition <> nil)]));
    end;
    if gui_point_valid and caret_debug_logging then
    begin
        m_logger.debug(Format('GUI caret thread=%d point=(%d,%d)', [gui_thread_id, gui_point.X, gui_point.Y]));
    end;
    if caret_point_valid and caret_debug_logging then
    begin
        m_logger.debug(Format('CaretPos point=(%d,%d)', [caret_point.X, caret_point.Y]));
    end;

    imm_point_valid := False;
    imm_point := System.Types.Point(0, 0);
    imm_line_height := 0;
    imm_anchor_hwnd := 0;
    imm_anchor_kind := '';
    suspicion_rect := foreground_rect;
    has_suspicion_rect := has_foreground_rect;
    if has_context_rect then
    begin
        suspicion_rect := context_rect;
        has_suspicion_rect := True;
    end;
    gui_suspicious := gui_point_valid and is_origin_anchor_suspicious(
        gui_point, suspicion_rect, has_suspicion_rect, cursor_point,
        cursor_point_valid, terminal_like_target, m_composition <> nil);
    caret_suspicious := caret_point_valid and is_origin_anchor_suspicious(
        caret_point, suspicion_rect, has_suspicion_rect, cursor_point,
        cursor_point_valid, terminal_like_target, m_composition <> nil);
    probe_imm := should_probe_imm_anchor(comless_target, tsf_point_valid,
        gui_point_valid and not gui_suspicious,
        caret_point_valid and not caret_suspicious);
    if probe_imm then
    begin
        if try_get_imm_anchor_point(hwnd, imm_point, imm_line_height,
            imm_anchor_kind) then
        begin
            imm_point_valid := True;
            imm_anchor_hwnd := hwnd;
        end
        else if (context_hwnd <> hwnd) and
            try_get_imm_anchor_point(context_hwnd, imm_point, imm_line_height,
            imm_anchor_kind) then
        begin
            imm_point_valid := True;
            imm_anchor_hwnd := context_hwnd;
        end
        else if (foreground_hwnd <> hwnd) and (foreground_hwnd <> context_hwnd) and
            try_get_imm_anchor_point(foreground_hwnd, imm_point, imm_line_height,
            imm_anchor_kind) then
        begin
            imm_point_valid := True;
            imm_anchor_hwnd := foreground_hwnd;
        end;
        if not imm_point_valid and
            try_get_canvas_character_point(imm_point, imm_line_height) then
        begin
            imm_point_valid := True;
            imm_anchor_hwnd := hwnd;
            imm_anchor_kind := 'query-character';
        end;
    end;
    if imm_point_valid and caret_debug_logging then
    begin
        m_logger.debug(Format('IMM caret hwnd=%d kind=%s point=(%d,%d)',
            [imm_anchor_hwnd, imm_anchor_kind, imm_point.X, imm_point.Y]));
    end;
    if last_sent_point_valid and caret_debug_logging then
    begin
        m_logger.debug(Format('Last sent caret point=(%d,%d)', [last_sent_point.X, last_sent_point.Y]));
    end;

    observation_count := 0;
    add_observation(casTsf, tsf_point, tsf_point_valid);
    add_observation(casImm, imm_point, imm_point_valid);
    add_observation(casGui, gui_point, gui_point_valid);
    add_observation(casCaretPos, caret_point, caret_point_valid);
    add_observation(casLastSent, last_sent_point, last_sent_point_valid);
    add_observation(casCursor, cursor_point, cursor_point_valid);

    FillChar(anchor_context, SizeOf(anchor_context), 0);
    anchor_context.has_composition := m_composition <> nil;
    anchor_context.terminal_like_target := terminal_like_target;
    anchor_context.has_context_rect := has_context_rect;
    anchor_context.context_rect := context_rect;
    anchor_context.has_foreground_rect := has_foreground_rect;
    anchor_context.foreground_rect := foreground_rect;
    anchor_context.cursor_point_valid := cursor_point_valid;
    anchor_context.cursor_point := cursor_point;
    anchor_context.last_stable_valid := last_sent_point_valid;
    anchor_context.last_stable_point := last_sent_point;
    // Never track a mouse elsewhere on screen. Once sent, this fallback is
    // retained as last_sent during composition until a live caret is available.
    anchor_context.allow_cursor_fallback := probe_imm and not imm_point_valid and
        not comless_target and not photoshop_canvas_target and has_context_rect and
        PtInRect(context_rect, cursor_point);
    tsf_suspicious := tsf_point_valid and is_origin_anchor_suspicious(tsf_point, foreground_rect, has_foreground_rect,
        cursor_point, cursor_point_valid, terminal_like_target, anchor_context.has_composition);
    if tsf_suspicious and should_relax_terminal_tsf_suspicion(tsf_point, tsf_point_valid, gui_point, gui_point_valid,
        caret_point, caret_point_valid, foreground_rect, has_foreground_rect, cursor_point,
        cursor_point_valid, terminal_like_target, anchor_context.has_composition) then
    begin
        tsf_suspicious := False;
    end;
    gui_suspicious := gui_point_valid and is_origin_anchor_suspicious(gui_point, foreground_rect, has_foreground_rect,
        cursor_point, cursor_point_valid, terminal_like_target, anchor_context.has_composition);
    caret_suspicious := caret_point_valid and is_origin_anchor_suspicious(caret_point, foreground_rect, has_foreground_rect,
        cursor_point, cursor_point_valid, terminal_like_target, anchor_context.has_composition);
    last_suspicious := last_sent_point_valid and is_origin_anchor_suspicious(last_sent_point, foreground_rect,
        has_foreground_rect, cursor_point, cursor_point_valid, terminal_like_target, anchor_context.has_composition);
    gui_caret_pair := gui_point_valid and caret_point_valid and points_are_close(gui_point, caret_point, 96);
    gui_far_from_tsf := gui_caret_pair and tsf_point_valid and
        (not points_are_close(gui_point, tsf_point, 140)) and (not points_are_close(caret_point, tsf_point, 140));

    if caret_debug_logging then
    begin
        m_logger.debug(Format(
            'CaretObs term=%d comless=%d tsf=%s imm=%s gui=%s caret=%s last=%s cursor=%s line=%d',
            [Ord(terminal_like_target), Ord(comless_target),
            format_anchor_point(tsf_point, tsf_point_valid),
            format_anchor_point(imm_point, imm_point_valid),
            format_anchor_point(gui_point, gui_point_valid),
            format_anchor_point(caret_point, caret_point_valid),
            format_anchor_point(last_sent_point, last_sent_point_valid),
            format_anchor_point(cursor_point, cursor_point_valid),
            placement_line_height]));
        m_logger.debug(Format(
            'CaretFlags term=%d tsf_s=%d gui_s=%d caret_s=%d last_s=%d pair=%d far=%d',
            [Ord(terminal_like_target),
            Ord(tsf_suspicious), Ord(gui_suspicious), Ord(caret_suspicious), Ord(last_suspicious),
            Ord(gui_caret_pair), Ord(gui_far_from_tsf)]));
    end;

    if try_choose_best_anchor_scored(Slice(observations, observation_count), anchor_context, point, chosen_source,
        chosen_score) then
    begin
        if chosen_source = casImm then
        begin
            placement_line_height := imm_line_height;
        end;
        if comless_target and
            (((not imm_point_valid) and ((chosen_source = casCursor) or
            anchor_looks_like_window_origin(point, foreground_rect,
            has_foreground_rect))) or
            anchor_looks_like_window_bottom_right(point, foreground_rect,
            has_foreground_rect) or
            anchor_looks_like_window_bottom_right(point, context_rect,
            has_context_rect)) and
            (try_get_comless_fallback_anchor(foreground_rect,
            has_foreground_rect, comless_fallback_point) or
            try_get_comless_fallback_anchor(context_rect,
            has_context_rect, comless_fallback_point)) then
        begin
            point := comless_fallback_point;
            placement_line_height := 0;
            chosen_source := casComlessFallback;
            chosen_score := 180;
        end;
        if caret_debug_logging then
        begin
            m_logger.debug(Format('Caret choose=%s point=(%d,%d)', [anchor_source_name(chosen_source), point.X, point.Y]));
            if placement_line_height <> m_last_caret_line_height then
            begin
                m_logger.debug(Format('Caret placement line_height raw=%d effective=%d source=%s',
                    [m_last_caret_line_height, placement_line_height, anchor_source_name(chosen_source)]));
            end;
        end;
        if caret_debug_logging then
        begin
            m_logger.debug(Format('CaretChoose term=%d source=%s score=%d point=(%d,%d) line=%d policy=20260917',
                [Ord(terminal_like_target), anchor_source_name(chosen_source), chosen_score,
                point.X, point.Y, placement_line_height]));
        end;
        Result := True;
        Exit;
    end;

    if comless_target and
        (try_get_comless_fallback_anchor(foreground_rect,
        has_foreground_rect, comless_fallback_point) or
        try_get_comless_fallback_anchor(context_rect,
        has_context_rect, comless_fallback_point)) then
    begin
        point := comless_fallback_point;
        placement_line_height := 0;
        chosen_source := casComlessFallback;
        chosen_score := 180;
        Result := True;
        Exit;
    end;

    chosen_score := 0;
    Result := False;
end;

function TncTextService.request_text_ext_update(const context: ITfContext): Boolean;
var
    edit_session: ITfEditSession;
    session_hr: HRESULT;
    hr: HRESULT;
begin
    Result := False;
    if (context = nil) or (m_client_id = 0) then
    begin
        Exit;
    end;

    edit_session := TncCaretEditSession.create(context, @m_composition, @m_last_caret_point, @m_has_caret_point,
        @m_last_caret_line_height);
    hr := context.RequestEditSession(m_client_id, edit_session, TF_ES_READ or TF_ES_ASYNCDONTCARE, session_hr);
    if hr = S_OK then
    begin
        Result := session_hr = S_OK;
        Exit;
    end;
    Result := hr = TF_S_ASYNC;
end;

function TncTextService.request_surrounding_text(const context: ITfContext; out left_text: string): Boolean;
begin
    left_text := '';
    Result := False;
    if (context = nil) or (m_client_id = 0) then
    begin
        Exit;
    end;
    if is_password_window_context(context) then
    begin
        Result := True;
        Exit;
    end;
    if m_read_lock_surrounding_valid and
        SameText(m_read_lock_document_key, current_document_context_key) then
    begin
        left_text := m_read_lock_surrounding_text;
        Result := True;
        Exit;
    end;

    { Never request a synchronous document scan from the key path. The cache
      is refreshed only while TSF has already granted a read lock. }
end;

function TncTextService.current_document_context_key: string;
begin
    if m_session_id = '' then
    begin
        Result := '';
        Exit;
    end;
    Result := m_session_id + ':' + IntToStr(Int64(m_document_context_serial));
end;

procedure TncTextService.rotate_document_context;
begin
    Inc(m_document_context_serial);
    if m_document_context_serial = 0 then
    begin
        m_document_context_serial := 1;
    end;
    m_last_sent_surrounding_text := '';
    m_last_sent_document_key := '';
    m_last_sent_surrounding_valid := False;
    m_read_lock_surrounding_text := '';
    m_read_lock_document_key := '';
    m_read_lock_surrounding_valid := False;
    m_last_read_lock_capture_tick := 0;
    m_last_surrounding_request_tick := 0;
    m_surrounding_needs_refresh := True;
end;

procedure TncTextService.capture_surrounding_text_under_lock(
    const context: ITfContext; const ec: TfEditCookie);
const
    c_surrounding_max_chars = 1024;
    c_capture_interval_ms = 120;
var
    now_tick: UInt64;
    captured_text: string;
    reader: TncSurroundingTextEditSession;

    procedure clear_cached_snapshot;
    begin
        m_read_lock_surrounding_text := '';
        m_read_lock_document_key := current_document_context_key;
        m_read_lock_surrounding_valid := True;
        m_surrounding_needs_refresh := True;
    end;

begin
    if context = nil then
    begin
        Exit;
    end;
    if is_password_window_context(context) or
        is_protected_input_scope(context, ec) then
    begin
        clear_cached_snapshot;
        Exit;
    end;
    now_tick := GetTickCount64;
    if (m_last_read_lock_capture_tick <> 0) and
        (now_tick - m_last_read_lock_capture_tick < c_capture_interval_ms) then
    begin
        Exit;
    end;
    m_last_read_lock_capture_tick := now_tick;
    captured_text := '';
    reader := TncSurroundingTextEditSession.create(context, @m_composition,
        c_surrounding_max_chars, @captured_text);
    try
        try
            if not reader.read_left_text(ec) then
            begin
                clear_cached_snapshot;
                Exit;
            end;
        except
            clear_cached_snapshot;
            Exit;
        end;
    finally
        reader.Free;
    end;
    m_read_lock_surrounding_text := captured_text;
    m_read_lock_document_key := current_document_context_key;
    m_read_lock_surrounding_valid := True;
    m_surrounding_needs_refresh := True;
end;

function TncTextService.is_protected_input_scope(
    const context: ITfContext; const ec: TfEditCookie): Boolean;
const
    c_input_scope_private = 61;
    c_input_scope_numeric_password = 63;
    c_input_scope_numeric_pin = 64;
    c_input_scope_alphanumeric_pin = 65;
    c_input_scope_alphanumeric_pin_set = 66;
var
    prop: ITfReadOnlyProperty;
    selection: TF_SELECTION;
    fetched: ULONG;
    value: OleVariant;
    unknown_value: IUnknown;
    input_scope: ITfInputScope;
    scopes: PInputScope;
    scope_count: UINT;
    idx: UINT;
    guid: TGUID;
    scope_value: Integer;
begin
    Result := False;
    if context = nil then
    begin
        Exit;
    end;

    FillChar(selection, SizeOf(selection), 0);
    fetched := 0;
    if (context.GetSelection(ec, 0, 1, selection, fetched) <> S_OK) or
        (fetched = 0) or (selection.range = nil) then
    begin
        Exit;
    end;

    prop := nil;
    guid := GUID_PROP_INPUTSCOPE;
    if (context.GetAppProperty(guid, prop) <> S_OK) or (prop = nil) then
    begin
        Exit;
    end;

    value := Unassigned;
    if prop.GetValue(ec, selection.range, value) <> S_OK then
    begin
        Exit;
    end;
    try
        if VarType(value) <> varUnknown then
        begin
            Exit;
        end;
        unknown_value := IUnknown(value);
        if (unknown_value = nil) or
            (not Supports(unknown_value, ITfInputScope, input_scope)) then
        begin
            Exit;
        end;

        scopes := nil;
        scope_count := 0;
        if input_scope.GetInputScopes(@scopes, @scope_count) <> S_OK then
        begin
            Exit;
        end;
        try
            if scope_count = 0 then
            begin
                Exit;
            end;
            for idx := 0 to scope_count - 1 do
            begin
                scope_value := Integer(PInputScope(NativeUInt(scopes) +
                    (NativeUInt(idx) * SizeOf(TInputScope)))^);
                if (scope_value = Integer(IS_PASSWORD)) or
                    (scope_value = c_input_scope_private) or
                    (scope_value = c_input_scope_numeric_password) or
                    (scope_value = c_input_scope_numeric_pin) or
                    (scope_value = c_input_scope_alphanumeric_pin) or
                    (scope_value = c_input_scope_alphanumeric_pin_set) then
                begin
                    Result := True;
                    Exit;
                end;
            end;
        finally
            if scopes <> nil then
            begin
                CoTaskMemFree(scopes);
            end;
        end;
    finally
        VarClear(value);
    end;
end;

function TncTextService.is_password_window_context(
    const context: ITfContext): Boolean;
const
    c_edit_password_style = $0020;
var
    view: ITfContextView;
    window_handle: Winapi.Windows.HWND;
    style: NativeInt;
begin
    Result := False;
    if (context = nil) or (context.GetActiveView(view) <> S_OK) or
        (view = nil) then
    begin
        Exit;
    end;
    window_handle := 0;
    if (view.GetWnd(window_handle) <> S_OK) or (window_handle = 0) then
    begin
        Exit;
    end;
    style := GetWindowLongPtr(window_handle, GWL_STYLE);
    Result := (style and c_edit_password_style) <> 0;
end;

function TncTextService.maybe_update_surrounding_text(const context: ITfContext; const force: Boolean): Boolean;
const
    c_surrounding_retry_interval_ms = 120;
var
    now_tick: UInt64;
begin
    Result := False;
    if context = nil then
    begin
        Exit;
    end;

    if (not force) and (m_composition <> nil) and (not m_surrounding_needs_refresh) then
    begin
        Exit;
    end;

    if (not force) and (not m_surrounding_needs_refresh) then
    begin
        Exit;
    end;

    now_tick := GetTickCount64;
    if (not force) and (m_last_surrounding_request_tick <> 0) and
        ((now_tick - m_last_surrounding_request_tick) < c_surrounding_retry_interval_ms) then
    begin
        Exit;
    end;

    m_last_surrounding_request_tick := now_tick;
    Result := update_surrounding_text(context);
end;

function TncTextService.update_surrounding_text(const context: ITfContext): Boolean;
var
    left_text: string;
    document_key: string;
begin
    Result := False;
    if (context = nil) or (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    left_text := '';
    if request_surrounding_text(context, left_text) then
    begin
        document_key := current_document_context_key;
        if m_last_sent_surrounding_valid and
            (m_last_sent_document_key = document_key) and
            (m_last_sent_surrounding_text = left_text) then
        begin
            m_surrounding_needs_refresh := False;
            Exit;
        end;

        if m_ipc_client.set_surrounding(m_session_id, left_text,
            document_key, left_text) then
        begin
            m_last_sent_surrounding_text := left_text;
            m_last_sent_document_key := document_key;
            m_last_sent_surrounding_valid := True;
            m_surrounding_needs_refresh := False;
            mark_session_dirty;
            Result := True;
        end;
    end;
end;

function TncTextService.update_composition(const context: ITfContext; const text: string): Boolean;
var
    edit_session: ITfEditSession;
    session_hr: HRESULT;
    hr: HRESULT;
    confirmed_length: Integer;
begin
    if (context = nil) or (text = '') then
    begin
        Result := False;
        Exit;
    end;

    confirmed_length := 0;
    m_composition_context := context;

    edit_session := TncCompositionEditSession.create(context, Self as ITfCompositionSink, @m_composition, text,
        @m_last_caret_point, @m_has_caret_point, @m_last_caret_line_height, confirmed_length, m_attr_input_atom);
    session_hr := E_FAIL;
    hr := context.RequestEditSession(m_client_id, edit_session, TF_ES_READWRITE or TF_ES_SYNC, session_hr);
    if hr <> S_OK then
    begin
        hr := context.RequestEditSession(m_client_id, edit_session, c_edit_session_flags, session_hr);
    end;
    if hr = S_OK then
    begin
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('UpdateComposition hr=0x%.8x session=0x%.8x text=%s',
                [hr, session_hr, text]));
            m_logger.debug(Format('TextExt point=(%d,%d) valid=%d',
                [m_last_caret_point.X, m_last_caret_point.Y, Ord(m_has_caret_point)]));
            m_logger.debug(Format('TextExt line_height=%d', [m_last_caret_line_height]));
        end;
        Result := session_hr = S_OK;
        Exit;
    end;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('UpdateComposition hr=0x%.8x async=%d text=%s',
            [hr, Ord(hr = TF_S_ASYNC), text]));
    end;
    Result := hr = TF_S_ASYNC;
end;

function TncTextService.end_composition(const context: ITfContext): Boolean;
var
    edit_session: ITfEditSession;
    session_hr: HRESULT;
    hr: HRESULT;
begin
    if context = nil then
    begin
        Result := False;
        Exit;
    end;

    m_composition_context := context;
    edit_session := TncCompositionEditSession.create(context, Self as ITfCompositionSink, @m_composition, '',
        @m_last_caret_point, @m_has_caret_point, @m_last_caret_line_height, 0, m_attr_input_atom);
    session_hr := E_FAIL;
    hr := context.RequestEditSession(m_client_id, edit_session, TF_ES_READWRITE or TF_ES_SYNC, session_hr);
    if hr <> S_OK then
    begin
        hr := context.RequestEditSession(m_client_id, edit_session, c_edit_session_flags, session_hr);
    end;
    if hr = S_OK then
    begin
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('EndComposition hr=0x%.8x session=0x%.8x',
                [hr, session_hr]));
        end;
        Result := session_hr = S_OK;
        Exit;
    end;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('EndComposition hr=0x%.8x async=%d',
            [hr, Ord(hr = TF_S_ASYNC)]));
    end;
    Result := hr = TF_S_ASYNC;
end;

function TncTextService.request_commit(const context: ITfContext; const text: string): Boolean;
var
    edit_session: ITfEditSession;
    session_hr: HRESULT;
    hr: HRESULT;
begin
    if (context = nil) or (text = '') then
    begin
        Result := False;
        Exit;
    end;

    m_composition_context := context;
    edit_session := TncCommitEditSession.create(context, @m_composition, text);
    session_hr := E_FAIL;
    hr := context.RequestEditSession(m_client_id, edit_session, TF_ES_READWRITE or TF_ES_SYNC, session_hr);
    if hr <> S_OK then
    begin
        hr := context.RequestEditSession(m_client_id, edit_session, c_edit_session_flags, session_hr);
    end;
    if hr = S_OK then
    begin
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('Commit hr=0x%.8x session=0x%.8x text=%s',
                [hr, session_hr, text]));
        end;
        m_surrounding_needs_refresh := True;
        m_last_surrounding_request_tick := 0;
        Result := session_hr = S_OK;
        Exit;
    end;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('Commit hr=0x%.8x async=%d text=%s',
            [hr, Ord(hr = TF_S_ASYNC), text]));
    end;
    if hr = TF_S_ASYNC then
    begin
        m_surrounding_needs_refresh := True;
        m_last_surrounding_request_tick := 0;
    end;
    Result := hr = TF_S_ASYNC;
end;

end.
