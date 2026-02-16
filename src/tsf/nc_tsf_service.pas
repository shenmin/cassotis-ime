unit nc_tsf_service;

interface

uses
    Winapi.Windows,
    Winapi.ActiveX,
    Winapi.Msctf,
    System.SysUtils,
    System.IOUtils,
    System.Types,
    System.Variants,
    ComObj,
    nc_config,
    nc_types,
    nc_log,
    nc_tsf_guids,
    nc_tsf_compartments,
    nc_tsf_display_attr,
    nc_tsf_edit_session,
    nc_ipc_client;

type
    TncTextService = class(TComObject, ITfTextInputProcessor, ITfTextInputProcessorEx,
        ITfKeyEventSink, ITfCompositionSink, ITfContextOwnerCompositionSink, ITfDisplayAttributeProvider,
        ITfThreadMgrEventSink, ITfTextEditSink, ITfTextLayoutSink, ITfCompartmentEventSink)
    private
        m_thread_mgr: ITfThreadMgr;
        m_thread_mgr_source: ITfSource;
        m_thread_mgr_event_cookie: DWORD;
        m_compartment_mgr: ITfCompartmentMgr;
        m_openclose_compartment: ITfCompartment;
        m_openclose_source: ITfSource;
        m_openclose_cookie: DWORD;
        m_conversion_compartment: ITfCompartment;
        m_conversion_source: ITfSource;
        m_conversion_cookie: DWORD;
        m_compartment_update_depth: Integer;
        m_last_input_mode: TncInputMode;
        m_last_full_width_mode: Boolean;
        m_last_punctuation_full_width: Boolean;
        m_compartment_state_inited: Boolean;
        m_client_id: TfClientId;
        m_keystroke_mgr: ITfKeystrokeMgr;
        m_key_event_advised: Boolean;
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
        m_last_config_write: TDateTime;
        m_log_config: TncLogConfig;
        m_logger: TncLogger;
        m_last_caret_point: TPoint;
        m_has_caret_point: Boolean;
        m_last_ipc_error: DWORD;
        m_pending_caret_update: Boolean;
        procedure clear_state;
        procedure unadvise_thread_mgr_sink;
        procedure advise_thread_mgr_sink;
        procedure unadvise_compartment_sinks;
        procedure advise_compartment_sinks;
        function read_compartment_dword(const compartment: ITfCompartment; out value: DWORD): Boolean;
        function write_compartment_dword(const compartment: ITfCompartment; const value: DWORD): Boolean;
        procedure apply_engine_state_to_compartments(const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean);
        function thread_mgr_on_set_focus(const pdimFocus: ITfDocumentMgr; const pdimPrevFocus: ITfDocumentMgr): HResult; stdcall;
        function ITfThreadMgrEventSink.OnSetFocus = thread_mgr_on_set_focus;
        procedure unadvise_context_sinks;
        procedure advise_context_sinks(const context: ITfContext);
        procedure ensure_active_context(const context: ITfContext);
        procedure cancel_composition;
        procedure init_display_attribute_atom;
        procedure free_logger;
        function build_key_state: TncKeyState;
        function get_config_write_time: TDateTime;
        procedure load_engine_config(out config: TncEngineConfig);
        procedure apply_log_config;
        procedure reload_config_if_needed;
        function get_candidate_point(out point: TPoint): Boolean;
        function request_text_ext_update(const context: ITfContext): Boolean;
        function request_surrounding_text(const context: ITfContext; out left_text: string): Boolean;
        procedure update_surrounding_text(const context: ITfContext);
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

function nc_get_gui_thread_info(const thread_id: DWORD; var gui_info: TncGuiThreadInfo): BOOL; stdcall;
    external 'user32.dll' name 'GetGUIThreadInfo';

type
    TncLogicalToPhysicalPoint = function(hwnd: HWND; var point: TPoint): BOOL; stdcall;

var
    g_logical_to_physical: TncLogicalToPhysicalPoint = nil;
    g_logical_to_physical_ready: Boolean = False;

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

const
    TF_ES_ASYNCDONTCARE = $0;
    TF_ES_SYNC = $1;
    TF_ES_READ = $2;
    TF_ES_READWRITE = $6;
    TF_ES_ASYNC = $8;
    c_edit_session_flags = TF_ES_READWRITE or TF_ES_ASYNCDONTCARE;

procedure TncTextService.Initialize;
var
    guid: TGUID;
begin
    inherited Initialize;
    m_ipc_client := TncIpcClient.create(True);
    clear_state;
    if CreateGUID(guid) = S_OK then
    begin
        m_session_id := GUIDToString(guid);
    end;
end;

destructor TncTextService.Destroy;
begin
    free_logger;
    if m_ipc_client <> nil then
    begin
        m_ipc_client.Free;
        m_ipc_client := nil;
    end;
    clear_state;
    inherited Destroy;
end;

procedure TncTextService.clear_state;
begin
    m_thread_mgr := nil;
    m_thread_mgr_source := nil;
    m_thread_mgr_event_cookie := 0;
    m_compartment_mgr := nil;
    m_openclose_compartment := nil;
    m_openclose_source := nil;
    m_openclose_cookie := 0;
    m_conversion_compartment := nil;
    m_conversion_source := nil;
    m_conversion_cookie := 0;
    m_compartment_update_depth := 0;
    m_last_input_mode := im_chinese;
    m_last_full_width_mode := False;
    m_last_punctuation_full_width := False;
    m_compartment_state_inited := False;
    m_client_id := 0;
    m_keystroke_mgr := nil;
    m_key_event_advised := False;
    m_doc_mgr := nil;
    m_context_source := nil;
    m_text_edit_cookie := 0;
    m_text_layout_cookie := 0;
    m_context := nil;
    m_composition := nil;
    m_composition_context := nil;
    m_session_id := '';
    m_attr_input_atom := TF_INVALID_GUIDATOM;
    m_display_attribute_provider := nil;
    m_config_path := '';
    m_last_config_write := 0;
    m_log_config.enabled := False;
    m_log_config.level := ll_info;
    m_log_config.max_size_kb := 1024;
    m_log_config.log_path := '';
    m_logger := nil;
    m_last_caret_point := Point(0, 0);
    m_has_caret_point := False;
    m_last_ipc_error := 0;
    m_pending_caret_update := False;
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
    if (m_thread_mgr_source <> nil) and (m_thread_mgr_event_cookie <> 0) then
    begin
        m_thread_mgr_source.UnadviseSink(m_thread_mgr_event_cookie);
    end;
    m_thread_mgr_event_cookie := 0;
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
            m_thread_mgr_event_cookie := 0;
        end;
    end;
end;

procedure TncTextService.unadvise_compartment_sinks;
begin
    if (m_openclose_source <> nil) and (m_openclose_cookie <> 0) then
    begin
        m_openclose_source.UnadviseSink(m_openclose_cookie);
    end;
    if (m_conversion_source <> nil) and (m_conversion_cookie <> 0) then
    begin
        m_conversion_source.UnadviseSink(m_conversion_cookie);
    end;

    m_openclose_cookie := 0;
    m_openclose_source := nil;
    m_openclose_compartment := nil;

    m_conversion_cookie := 0;
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
            m_openclose_cookie := 0;
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
            m_conversion_cookie := 0;
        end;
    end;
end;

function TncTextService.read_compartment_dword(const compartment: ITfCompartment; out value: DWORD): Boolean;
var
    var_value: OleVariant;
    int_value: Integer;
begin
    value := 0;
    Result := False;
    if compartment = nil then
    begin
        Exit;
    end;

    var_value := Unassigned;
    if compartment.GetValue(var_value) <> S_OK then
    begin
        Exit;
    end;

    if VarIsEmpty(var_value) or VarIsNull(var_value) then
    begin
        Exit;
    end;

    try
        int_value := var_value;
    except
        Exit;
    end;

    if int_value < 0 then
    begin
        int_value := 0;
    end;
    value := DWORD(int_value);
    Result := True;
end;

function TncTextService.write_compartment_dword(const compartment: ITfCompartment; const value: DWORD): Boolean;
var
    var_value: OleVariant;
begin
    Result := False;
    if (compartment = nil) or (m_client_id = 0) then
    begin
        Exit;
    end;

    var_value := Integer(value);
    Result := compartment.SetValue(m_client_id, var_value) = S_OK;
end;

procedure TncTextService.apply_engine_state_to_compartments(const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean);
var
    openclose_value: DWORD;
    conversion_value: DWORD;
begin
    if (m_openclose_compartment = nil) or (m_conversion_compartment = nil) then
    begin
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
    if punctuation_full_width then
    begin
        conversion_value := conversion_value or TF_CONVERSIONMODE_SYMBOL;
    end;

    Inc(m_compartment_update_depth);
    try
        write_compartment_dword(m_openclose_compartment, openclose_value);
        write_compartment_dword(m_conversion_compartment, conversion_value);
    finally
        Dec(m_compartment_update_depth);
    end;

    m_last_input_mode := input_mode;
    m_last_full_width_mode := full_width_mode;
    m_last_punctuation_full_width := punctuation_full_width;
    m_compartment_state_inited := True;
end;

procedure TncTextService.unadvise_context_sinks;
begin
    if m_context_source <> nil then
    begin
        if m_text_edit_cookie <> 0 then
        begin
            m_context_source.UnadviseSink(m_text_edit_cookie);
        end;
        if m_text_layout_cookie <> 0 then
        begin
            m_context_source.UnadviseSink(m_text_layout_cookie);
        end;
    end;

    m_text_edit_cookie := 0;
    m_text_layout_cookie := 0;
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
        cookie := 0;
        iid := IID_ITfTextEditSink;
        hr := source.AdviseSink(iid, Self as ITfTextEditSink, cookie);
        if hr = S_OK then
        begin
            m_text_edit_cookie := cookie;
        end;

        cookie := 0;
        iid := IID_ITfTextLayoutSink;
        hr := source.AdviseSink(iid, Self as ITfTextLayoutSink, cookie);
        if hr = S_OK then
        begin
            m_text_layout_cookie := cookie;
        end;

        if (m_text_edit_cookie <> 0) or (m_text_layout_cookie <> 0) then
        begin
            m_context_source := source;
        end;
    end;
end;

procedure TncTextService.cancel_composition;
var
    context: ITfContext;
begin
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
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        m_ipc_client.reset_session(m_session_id);
    end;
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

    m_context := context;
    m_has_caret_point := False;
    m_pending_caret_update := False;
    advise_context_sinks(context);
end;

function TncTextService.Activate(const thread_mgr: ITfThreadMgr; client_id: TfClientId): HResult;
var
    keystroke_mgr: ITfKeystrokeMgr;
    hr: HRESULT;
    engine_config: TncEngineConfig;
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    guid: TGUID;
begin
    m_thread_mgr := thread_mgr;
    m_client_id := client_id;

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
    advise_compartment_sinks;
    m_doc_mgr := nil;
    if (m_thread_mgr <> nil) and (m_thread_mgr.GetFocus(m_doc_mgr) = S_OK) and (m_doc_mgr <> nil) then
    begin
        m_context := nil;
        if m_doc_mgr.GetTop(m_context) = S_OK then
        begin
            advise_context_sinks(m_context);
        end;
    end;

    m_config_path := get_default_config_path;
    load_engine_config(engine_config);
    if m_session_id = '' then
    begin
        if CreateGUID(guid) = S_OK then
        begin
            m_session_id := GUIDToString(guid);
        end;
    end;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        m_ipc_client.reset_session(m_session_id);
        if m_ipc_client.get_state(m_session_id, input_mode, full_width_mode, punctuation_full_width) then
        begin
            apply_engine_state_to_compartments(input_mode, full_width_mode, punctuation_full_width);
        end
        else
        begin
            apply_engine_state_to_compartments(engine_config.input_mode, engine_config.full_width_mode,
                engine_config.punctuation_full_width);
        end;
    end
    else
    begin
        apply_engine_state_to_compartments(engine_config.input_mode, engine_config.full_width_mode,
            engine_config.punctuation_full_width);
    end;
    if m_display_attribute_provider = nil then
    begin
        m_display_attribute_provider := TncDisplayAttributeProvider.create(
            TncDisplayAttributeInfo.create(GUID_NcDisplayAttributeInput));
    end;
    init_display_attribute_atom;

    if m_logger <> nil then
    begin
        m_logger.info('TSF activate');
    end;

    Result := S_OK;
end;

function TncTextService.Deactivate: HResult;
begin
    if m_key_event_advised and (m_keystroke_mgr <> nil) then
    begin
        m_keystroke_mgr.UnadviseKeyEventSink(m_client_id);
    end;
    m_key_event_advised := False;
    m_keystroke_mgr := nil;

    unadvise_context_sinks;
    unadvise_compartment_sinks;
    unadvise_thread_mgr_sink;

    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        m_ipc_client.reset_session(m_session_id);
    end;
    if m_logger <> nil then
    begin
        m_logger.info('TSF deactivate');
    end;
    free_logger;
    clear_state;
    Result := S_OK;
end;

function TncTextService.ActivateEx(const thread_mgr: ITfThreadMgr; client_id: TfClientId; flags: DWORD): HResult;
begin
    Result := Activate(thread_mgr, client_id);
end;

function TncTextService.OnSetFocus(focus: Integer): HResult;
begin
    if focus = 0 then
    begin
        cancel_composition;
        unadvise_context_sinks;
        m_doc_mgr := nil;
        m_context := nil;
    end;

    Result := S_OK;
end;

function TncTextService.OnTestKeyDown(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
var
    handled: Boolean;
    key_state: TncKeyState;
begin
    eaten := 0;
    reload_config_if_needed;
    key_state := build_key_state;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('TestKeyDown session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
            [m_session_id, Word(wParam), Ord(key_state.shift_down), Ord(key_state.ctrl_down),
            Ord(key_state.alt_down), Ord(key_state.caps_lock)]));
    end;
    if (m_composition <> nil) and (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        case wParam of
            VK_ESCAPE,
            VK_ADD,
            VK_SUBTRACT,
            VK_OEM_PLUS,
            VK_OEM_MINUS,
            VK_PRIOR,
            VK_NEXT:
                begin
                    eaten := 1;
                    Result := S_OK;
                    Exit;
                end;
        end;
    end;
    handled := False;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        if m_ipc_client.test_key(m_session_id, Word(wParam), key_state, handled) then
        begin
            if handled then
            begin
                eaten := 1;
            end;
        end;
        if (not handled) and (m_logger <> nil) and (m_ipc_client.last_error <> 0)
            and (m_ipc_client.last_error <> m_last_ipc_error) then
        begin
            m_last_ipc_error := m_ipc_client.last_error;
            m_logger.info(Format('IPC test_key failed err=%d', [m_last_ipc_error]));
        end;
    end;
    Result := S_OK;
end;

function TncTextService.OnKeyDown(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
var
    handled: Boolean;
    commit_text: string;
    display_text: string;
    input_mode: TncInputMode;
    full_width_mode: Boolean;
    punctuation_full_width: Boolean;
    point: TPoint;
    key_state: TncKeyState;
    key_code: Word;
begin
    ensure_active_context(context);
    eaten := 0;
    reload_config_if_needed;
    update_surrounding_text(context);
    handled := False;
    commit_text := '';
    display_text := '';
    key_state := build_key_state;
    key_code := Word(wParam);
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('KeyDown session=%s key=%d shift=%d ctrl=%d alt=%d caps=%d',
            [m_session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down), Ord(key_state.alt_down),
            Ord(key_state.caps_lock)]));
    end;
    if (m_composition <> nil) and (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        case key_code of
            VK_OEM_PLUS, VK_ADD:
                key_code := VK_NEXT;
            VK_OEM_MINUS, VK_SUBTRACT:
                key_code := VK_PRIOR;
            VK_ESCAPE:
                begin
                    cancel_composition;
                    eaten := 1;
                    Result := S_OK;
                    Exit;
                end;
        end;
    end;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        if m_ipc_client.process_key(m_session_id, key_code, key_state, handled, commit_text, display_text,
            input_mode, full_width_mode, punctuation_full_width) then
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
                    if update_composition(context, display_text) then
                    begin
                        if get_candidate_point(point) then
                        begin
                            m_ipc_client.set_caret(m_session_id, point, m_has_caret_point);
                            m_pending_caret_update := False;
                            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
                            begin
                                m_logger.debug(Format('Caret point set x=%d y=%d has=%d',
                                    [point.X, point.Y, Ord(m_has_caret_point)]));
                            end;
                        end
                        else
                        begin
                            m_pending_caret_update := True;
                            if (m_logger <> nil) and (m_logger.level <= ll_debug) then
                            begin
                                m_logger.debug('Caret point unavailable, defer candidate positioning');
                            end;
                        end;
                    end
                    else
                    begin
                        end_composition(context);
                    end;
                end
                else
                begin
                    end_composition(context);
                end;
            end;
        end;
        if (not handled) and (m_logger <> nil) and (m_ipc_client.last_error <> 0)
            and (m_ipc_client.last_error <> m_last_ipc_error) then
        begin
            m_last_ipc_error := m_ipc_client.last_error;
            m_logger.info(Format('IPC process_key failed err=%d', [m_last_ipc_error]));
        end;
    end;

    Result := S_OK;
end;

function TncTextService.OnTestKeyUp(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
end;

function TncTextService.OnKeyUp(const context: ITfContext; wParam: WPARAM; lParam: LPARAM; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
end;

function TncTextService.OnPreservedKey(const context: ITfContext; var rguid: TGUID; out eaten: Integer): HResult;
begin
    eaten := 0;
    Result := S_OK;
end;

function TncTextService.OnCompositionTerminated(ecWrite: TfEditCookie; const composition: ITfComposition): HResult;
begin
    m_composition := nil;
    m_composition_context := nil;
    m_has_caret_point := False;
    m_pending_caret_update := False;
    if (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        m_ipc_client.reset_session(m_session_id);
    end;

    Result := S_OK;
end;

function TncTextService.OnStartComposition(const composition: ITfCompositionView; out ok: Integer): HResult;
begin
    ok := 1;
    Result := S_OK;
end;

function TncTextService.OnUpdateComposition(const composition: ITfCompositionView; const rangeNew: ITfRange): HResult;
var
    point: TPoint;
begin
    if m_pending_caret_update and m_has_caret_point and (m_ipc_client <> nil) and (m_session_id <> '') then
    begin
        point := m_last_caret_point;
        m_ipc_client.set_caret(m_session_id, point, True);
        m_pending_caret_update := False;
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('Caret point deferred x=%d y=%d', [point.X, point.Y]));
        end;
    end;
    Result := S_OK;
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
    if (pdim <> nil) and (m_doc_mgr <> nil) and (pdim = m_doc_mgr) then
    begin
        cancel_composition;
        unadvise_context_sinks;
        m_doc_mgr := nil;
        m_context := nil;
    end;
    Result := S_OK;
end;

function TncTextService.thread_mgr_on_set_focus(const pdimFocus: ITfDocumentMgr;
    const pdimPrevFocus: ITfDocumentMgr): HResult;
begin
    if pdimFocus <> m_doc_mgr then
    begin
        cancel_composition;
        unadvise_context_sinks;
        m_doc_mgr := pdimFocus;
        m_context := nil;
        if (m_doc_mgr <> nil) and (m_doc_mgr.GetTop(m_context) = S_OK) then
        begin
            advise_context_sinks(m_context);
        end;
    end;
    Result := S_OK;
end;

function TncTextService.OnPushContext(const pic: ITfContext): HResult;
begin
    ensure_active_context(pic);
    Result := S_OK;
end;

function TncTextService.OnPopContext(const pic: ITfContext): HResult;
var
    focus_doc: ITfDocumentMgr;
    next_context: ITfContext;
begin
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
    Result := S_OK;
end;

function TncTextService.OnEndEdit(const pic: ITfContext; ecReadOnly: TfEditCookie; const pEditRecord: ITfEditRecord): HResult;
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

function TncTextService.OnLayoutChange(const pic: ITfContext; lcode: TfLayoutCode; const pView: ITfContextView): HResult;
var
    point: TPoint;
begin
    Result := S_OK;
    if (pic = nil) or (m_composition = nil) or (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    ensure_active_context(pic);
    request_text_ext_update(pic);
    if get_candidate_point(point) then
    begin
        m_ipc_client.set_caret(m_session_id, point, m_has_caret_point);
    end;
end;

function TncTextService.OnChange(var rguid: TGUID): HResult;
var
    openclose_value: DWORD;
    conversion_value: DWORD;
    has_openclose: Boolean;
    has_conversion: Boolean;
    next_input_mode: TncInputMode;
    next_full_width: Boolean;
    next_punctuation_full_width: Boolean;
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

    has_openclose := read_compartment_dword(m_openclose_compartment, openclose_value);
    has_conversion := read_compartment_dword(m_conversion_compartment, conversion_value);
    if (not has_openclose) and (not has_conversion) then
    begin
        Result := S_OK;
        Exit;
    end;

    next_input_mode := m_last_input_mode;
    if has_openclose then
    begin
        if openclose_value <> 0 then
        begin
            next_input_mode := im_chinese;
        end
        else
        begin
            next_input_mode := im_english;
        end;
    end
    else if has_conversion then
    begin
        if (conversion_value and TF_CONVERSIONMODE_NATIVE) <> 0 then
        begin
            next_input_mode := im_chinese;
        end
        else
        begin
            next_input_mode := im_english;
        end;
    end;

    next_full_width := m_last_full_width_mode;
    next_punctuation_full_width := m_last_punctuation_full_width;
    if has_conversion then
    begin
        next_full_width := (conversion_value and TF_CONVERSIONMODE_FULLSHAPE) <> 0;
        next_punctuation_full_width := (conversion_value and TF_CONVERSIONMODE_SYMBOL) <> 0;
    end;

    if m_ipc_client.set_state(m_session_id, next_input_mode, next_full_width, next_punctuation_full_width) then
    begin
        m_last_input_mode := next_input_mode;
        m_last_full_width_mode := next_full_width;
        m_last_punctuation_full_width := next_punctuation_full_width;
        m_compartment_state_inited := True;

        if next_input_mode = im_english then
        begin
            cancel_composition;
        end;
    end;

    Result := S_OK;
end;

function TncTextService.EnumDisplayAttributeInfo(out ppenum: IEnumTfDisplayAttributeInfo): HResult;
begin
    if m_display_attribute_provider = nil then
    begin
        ppenum := nil;
        Result := E_FAIL;
        Exit;
    end;

    Result := m_display_attribute_provider.EnumDisplayAttributeInfo(ppenum);
end;

function TncTextService.GetDisplayAttributeInfo(var GUID: TGUID; out ppInfo: ITfDisplayAttributeInfo): HResult;
begin
    if m_display_attribute_provider = nil then
    begin
        ppInfo := nil;
        Result := E_FAIL;
        Exit;
    end;

    Result := m_display_attribute_provider.GetDisplayAttributeInfo(GUID, ppInfo);
end;

function TncTextService.build_key_state: TncKeyState;
begin
    Result.shift_down := (GetKeyState(VK_SHIFT) and $8000) <> 0;
    Result.ctrl_down := (GetKeyState(VK_CONTROL) and $8000) <> 0;
    Result.alt_down := (GetKeyState(VK_MENU) and $8000) <> 0;
    Result.caps_lock := (GetKeyState(VK_CAPITAL) and 1) <> 0;
end;

function TncTextService.get_config_write_time: TDateTime;
begin
    Result := 0;
    if (m_config_path <> '') and FileExists(m_config_path) then
    begin
        Result := TFile.GetLastWriteTime(m_config_path);
    end;
end;

procedure TncTextService.load_engine_config(out config: TncEngineConfig);
var
    config_manager: TncConfigManager;
begin
    config_manager := TncConfigManager.create(m_config_path);
    try
        config := config_manager.load_engine_config;
        if not config.enable_ctrl_space_toggle then
        begin
            // Avoid being stuck in English when IME toggle is disabled.
            config.input_mode := im_chinese;
        end;
        m_log_config := config_manager.load_log_config;
    finally
        config_manager.Free;
    end;

    m_last_config_write := get_config_write_time;
    apply_log_config;
end;

procedure TncTextService.apply_log_config;
begin
    if not m_log_config.enabled then
    begin
        free_logger;
        Exit;
    end;

    if (m_logger <> nil) and (m_logger.log_path <> m_log_config.log_path) then
    begin
        free_logger;
    end;

    if m_logger = nil then
    begin
        m_logger := TncLogger.create(m_log_config.log_path, m_log_config.max_size_kb);
    end;
    m_logger.set_level(m_log_config.level);
end;

procedure TncTextService.reload_config_if_needed;
var
    current_write_time: TDateTime;
    engine_config: TncEngineConfig;
begin
    if m_config_path = '' then
    begin
        Exit;
    end;

    current_write_time := get_config_write_time;
    if current_write_time <= m_last_config_write then
    begin
        Exit;
    end;

    load_engine_config(engine_config);
end;

function TncTextService.get_candidate_point(out point: TPoint): Boolean;
var
    caret_point: TPoint;
    gui_point: TPoint;
    hwnd: Winapi.Windows.HWND;
    foreground_hwnd: Winapi.Windows.HWND;
    context_hwnd: Winapi.Windows.HWND;
    tsf_point: TPoint;
    tsf_point_valid: Boolean;
    caret_point_valid: Boolean;
    gui_point_valid: Boolean;
    delta_x: Integer;
    delta_y: Integer;
    max_delta: Integer;
    virtual_left: Integer;
    virtual_top: Integer;
    virtual_right: Integer;
    virtual_bottom: Integer;
    gui_info: TncGuiThreadInfo;
    gui_thread_id: DWORD;
    foreground_rect: TRect;
    has_foreground_rect: Boolean;
    context_rect: TRect;
    has_context_rect: Boolean;
    view: ITfContextView;

    function point_in_virtual_screen(const candidate: TPoint): Boolean;
    const
        c_margin = 200;
    begin
        Result := (candidate.X >= virtual_left - c_margin) and (candidate.X <= virtual_right + c_margin) and
            (candidate.Y >= virtual_top - c_margin) and (candidate.Y <= virtual_bottom + c_margin);
    end;

    function point_in_foreground(const candidate: TPoint): Boolean;
    const
        c_margin = 200;
    begin
        if has_context_rect then
        begin
            Result := (candidate.X >= context_rect.Left - c_margin) and (candidate.X <= context_rect.Right + c_margin) and
                (candidate.Y >= context_rect.Top - c_margin) and (candidate.Y <= context_rect.Bottom + c_margin);
            Exit;
        end;

        if not has_foreground_rect then
        begin
            Result := True;
            Exit;
        end;

        Result := (candidate.X >= foreground_rect.Left - c_margin) and (candidate.X <= foreground_rect.Right + c_margin) and
            (candidate.Y >= foreground_rect.Top - c_margin) and (candidate.Y <= foreground_rect.Bottom + c_margin);
    end;

    function try_get_gui_caret_point(const thread_id: DWORD; out candidate: TPoint): Boolean;
    begin
        candidate := System.Types.Point(0, 0);
        FillChar(gui_info, SizeOf(gui_info), 0);
        gui_info.cbSize := SizeOf(gui_info);
        if not nc_get_gui_thread_info(thread_id, gui_info) then
        begin
            Result := False;
            Exit;
        end;
        if gui_info.hwndCaret = 0 then
        begin
            Result := False;
            Exit;
        end;

        candidate := System.Types.Point(gui_info.rcCaret.Left, gui_info.rcCaret.Bottom);
        if not ClientToScreen(gui_info.hwndCaret, candidate) then
        begin
            Result := False;
            Exit;
        end;

        try_logical_to_physical(gui_info.hwndCaret, candidate);
        Result := point_in_virtual_screen(candidate) and point_in_foreground(candidate);
        if (not Result) and (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('GUI caret outside foreground point=(%d,%d) rect=(%d,%d,%d,%d)',
                [candidate.X, candidate.Y, foreground_rect.Left, foreground_rect.Top, foreground_rect.Right,
                foreground_rect.Bottom]));
        end;
    end;
begin
    point := System.Types.Point(0, 0);
    virtual_left := GetSystemMetrics(SM_XVIRTUALSCREEN);
    virtual_top := GetSystemMetrics(SM_YVIRTUALSCREEN);
    virtual_right := virtual_left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
    virtual_bottom := virtual_top + GetSystemMetrics(SM_CYVIRTUALSCREEN);

    tsf_point := m_last_caret_point;
    tsf_point_valid := m_has_caret_point and point_in_virtual_screen(tsf_point);

    gui_point_valid := False;
    gui_thread_id := 0;
    context_hwnd := 0;
    has_context_rect := False;
    if (m_context <> nil) and (m_context.GetActiveView(view) = S_OK) and (view <> nil) then
    begin
        if view.GetWnd(context_hwnd) = S_OK then
        begin
            has_context_rect := GetWindowRect(context_hwnd, context_rect);
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
    if foreground_hwnd <> 0 then
    begin
        has_foreground_rect := GetWindowRect(foreground_hwnd, foreground_rect);
    end;

    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('Caret hwnd context=%d focus=%d foreground=%d thread=%d',
            [context_hwnd, hwnd, foreground_hwnd, gui_thread_id]));
        if has_context_rect then
        begin
            m_logger.debug(Format('Caret context rect=(%d,%d,%d,%d)',
                [context_rect.Left, context_rect.Top, context_rect.Right, context_rect.Bottom]));
        end;
        if has_foreground_rect then
        begin
            m_logger.debug(Format('Caret foreground rect=(%d,%d,%d,%d)',
                [foreground_rect.Left, foreground_rect.Top, foreground_rect.Right, foreground_rect.Bottom]));
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
    if GetCaretPos(caret_point) then
    begin
        if hwnd <> 0 then
        begin
            ClientToScreen(hwnd, caret_point);
            try_logical_to_physical(hwnd, caret_point);
        end;
        caret_point_valid := point_in_virtual_screen(caret_point) and point_in_foreground(caret_point);
        if (not caret_point_valid) and (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('CaretPos outside foreground point=(%d,%d) rect=(%d,%d,%d,%d)',
                [caret_point.X, caret_point.Y, foreground_rect.Left, foreground_rect.Top, foreground_rect.Right,
                foreground_rect.Bottom]));
        end;
    end;

    if gui_point_valid then
    begin
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('GUI caret thread=%d point=(%d,%d)', [gui_thread_id, gui_point.X, gui_point.Y]));
        end;
        if tsf_point_valid then
        begin
            max_delta := 400;
            delta_x := Abs(tsf_point.X - gui_point.X);
            delta_y := Abs(tsf_point.Y - gui_point.Y);
            if (delta_x > max_delta) or (delta_y > max_delta) then
            begin
                if (m_logger <> nil) and (m_logger.level <= ll_debug) then
                begin
                    m_logger.debug(Format('Caret delta too large tsf=(%d,%d) gui=(%d,%d)',
                        [tsf_point.X, tsf_point.Y, gui_point.X, gui_point.Y]));
                end;
            end;
        end;

        point := gui_point;
        Result := True;
        Exit;
    end;

    if caret_point_valid then
    begin
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('CaretPos point=(%d,%d)', [caret_point.X, caret_point.Y]));
        end;
        if tsf_point_valid then
        begin
            max_delta := 400;
            delta_x := Abs(tsf_point.X - caret_point.X);
            delta_y := Abs(tsf_point.Y - caret_point.Y);
            if (delta_x > max_delta) or (delta_y > max_delta) then
            begin
                if (m_logger <> nil) and (m_logger.level <= ll_debug) then
                begin
                    m_logger.debug(Format('Caret delta too large tsf=(%d,%d) caret=(%d,%d)',
                        [tsf_point.X, tsf_point.Y, caret_point.X, caret_point.Y]));
                end;
                point := caret_point;
                Result := True;
                Exit;
            end;
        end;

        point := caret_point;
        Result := True;
        Exit;
    end;

    if tsf_point_valid and point_in_foreground(tsf_point) then
    begin
        if (m_logger <> nil) and (m_logger.level <= ll_debug) then
        begin
            m_logger.debug(Format('TSF caret point=(%d,%d)', [tsf_point.X, tsf_point.Y]));
        end;
        point := tsf_point;
        Result := True;
        Exit;
    end;

    if GetCursorPos(point) then
    begin
        Result := True;
        Exit;
    end;

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

    edit_session := TncCaretEditSession.create(context, @m_composition, @m_last_caret_point, @m_has_caret_point);
    hr := context.RequestEditSession(m_client_id, edit_session, TF_ES_READ or TF_ES_ASYNCDONTCARE, session_hr);
    if hr = S_OK then
    begin
        Result := session_hr = S_OK;
        Exit;
    end;
    Result := hr = TF_S_ASYNC;
end;

function TncTextService.request_surrounding_text(const context: ITfContext; out left_text: string): Boolean;
const
    c_surrounding_max_chars = 20;
var
    edit_session: ITfEditSession;
    session_hr: HRESULT;
    hr: HRESULT;
begin
    left_text := '';
    Result := False;
    if (context = nil) or (m_client_id = 0) then
    begin
        Exit;
    end;

    edit_session := TncSurroundingTextEditSession.create(context, @m_composition, c_surrounding_max_chars, @left_text);
    hr := context.RequestEditSession(m_client_id, edit_session, TF_ES_READ or TF_ES_SYNC, session_hr);
    Result := (hr = S_OK) and (session_hr = S_OK);
end;

procedure TncTextService.update_surrounding_text(const context: ITfContext);
var
    left_text: string;
begin
    if (context = nil) or (m_ipc_client = nil) or (m_session_id = '') then
    begin
        Exit;
    end;

    left_text := '';
    if request_surrounding_text(context, left_text) then
    begin
        m_ipc_client.set_surrounding(m_session_id, left_text);
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
        @m_last_caret_point, @m_has_caret_point, confirmed_length, m_attr_input_atom);
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
        @m_last_caret_point, @m_has_caret_point, 0, m_attr_input_atom);
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
        Result := session_hr = S_OK;
        Exit;
    end;
    if (m_logger <> nil) and (m_logger.level <= ll_debug) then
    begin
        m_logger.debug(Format('Commit hr=0x%.8x async=%d text=%s',
            [hr, Ord(hr = TF_S_ASYNC), text]));
    end;
    Result := hr = TF_S_ASYNC;
end;

end.
