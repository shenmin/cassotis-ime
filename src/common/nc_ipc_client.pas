unit nc_ipc_client;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Types,
    nc_types,
    nc_caret_anchor_policy;

const
    // Upper bound for one request/reply exchange. The pipe availability wait
    // alone never bounded the reply, so a host stuck inside a request (for
    // example on the config mutex) froze the application's UI thread.
    c_nc_ipc_transaction_timeout_ms = 3000;
    // For callers that do not block an application: TSF background worker, tray.
    c_nc_ipc_background_transaction_timeout_ms = 10000;
    // After a timed-out exchange, fail fast for this long instead of stalling
    // every keystroke while the host stays unresponsive.
    c_nc_ipc_unresponsive_backoff_ms = 2000;

type
    TncIpcClient = class
    private
        m_pipe_name: string;
        m_auto_start: Boolean;
        m_last_start_tick: DWORD;
        m_last_start_error: DWORD;
        m_last_start_detail: string;
        m_last_error: DWORD;
        m_transaction_timeout_ms: DWORD;
        m_unresponsive_until_tick: UInt64;
        function transact(const request_bytes: TBytes; var response_bytes: TBytes;
            out bytes_read: DWORD): Boolean;
        function ping_host: Boolean;
        function start_host: Boolean;
        function wait_for_host_ready(const timeout_ms: DWORD): Boolean;
        function host_mutex_exists: Boolean;
        function get_module_directory: string;
    protected
        function call_pipe(const request_text: string; out response_text: string): Boolean; virtual;
    public
        // pipe_name overrides the per-session host pipe (tests only).
        constructor create(const auto_start: Boolean = True;
            const transaction_timeout_ms: DWORD = c_nc_ipc_transaction_timeout_ms;
            const pipe_name: string = '');
        function is_host_running: Boolean;
        function test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean): Boolean;
        // input_epoch orders PROCESS_KEY and RESET per session on the host; 0 omits it.
        function process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
            out full_width_mode: Boolean; out punctuation_full_width: Boolean; out lookup_perf_info: string;
            const input_epoch: UInt64 = 0; const selection_window: HWND = 0;
            const selection_token: Cardinal = 0;
            const candidate_click: Boolean = False;
            const punctuation_preceding_char: Integer = -1): Boolean;
        function get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
            out punctuation_full_width: Boolean): Boolean;
        function get_shortcut_config(const session_id: string;
            out shortcut_config: TncShortcutConfig): Boolean;
        function get_dictionary_variant(const session_id: string; out dictionary_variant: TncDictionaryVariant): Boolean;
        function get_active(const session_id: string; out active: Boolean): Boolean;
        function set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean;
            const source: string = ''): Boolean;
        function set_dictionary_variant(const session_id: string; const dictionary_variant: TncDictionaryVariant): Boolean;
        function set_active(const session_id: string; const active: Boolean): Boolean;
        function release_session(const session_id: string): Boolean;
        function set_caret(const session_id: string; const point: TPoint; const has_caret: Boolean;
            const line_height: Integer = 0; const source: TncCaretAnchorSource = casCursor;
            const anchor_score: Integer = 0; const terminal_like_target: Boolean = False;
            const comless_target: Boolean = False): Boolean;
        function set_surrounding(const session_id: string;
            const left_context: string; const document_key: string = '';
            const document_snapshot: string = ''): Boolean;
        function reload_config(const session_id: string): Boolean;
        function clear_user_dictionary(const session_id: string): Boolean;
        function reset_session(const session_id: string;
            const preserve_document_context: Boolean = False;
            const input_epoch: UInt64 = 0): Boolean;
        property last_error: DWORD read m_last_error;
        property last_start_detail: string read m_last_start_detail;
    end;

function build_set_caret_request(const session_id: string;
    const point: TPoint; const has_caret: Boolean; const line_height: Integer;
    const source: TncCaretAnchorSource; const anchor_score: Integer;
    const terminal_like_target: Boolean; const comless_target: Boolean): string;
function build_set_state_request(const session_id: string;
    const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean; const source: string = ''): string;
function try_parse_shortcut_config_response(const response_text: string;
    out shortcut_config: TncShortcutConfig): Boolean;

implementation

uses
    nc_ipc_common,
    nc_runtime_location,
    nc_shortcut;

const
    c_pipe_timeout_ms = 220;
    c_start_retry_delay_ms = 1500;
    c_start_wait_ms = 1500;
    c_call_retry_max = 3;
    c_call_retry_sleep_ms = 30;
    c_get_module_handle_ex_from_address = $00000004;
    c_get_module_handle_ex_unchanged_refcount = $00000002;
{$IFDEF WIN32}
    c_tsf_module_name = 'cassotis_ime_svr32.dll';
{$ELSE}
    c_tsf_module_name = 'cassotis_ime_svr.dll';
{$ENDIF}

function get_module_handle_ex(const flags: DWORD; const module_name: Pointer; var module_handle: HMODULE): BOOL; stdcall;
    external kernel32 name 'GetModuleHandleExW';

procedure ipc_module_anchor;
begin
end;

function elapsed_since(const start_tick: DWORD; const elapsed_ms: DWORD): Boolean;
begin
    Result := DWORD(GetTickCount - start_tick) >= elapsed_ms;
end;

function is_pipe_waitable_error(const err: DWORD): Boolean;
begin
    case err of
        ERROR_PIPE_BUSY,
        ERROR_SEM_TIMEOUT,
        ERROR_BROKEN_PIPE,
        ERROR_PIPE_NOT_CONNECTED,
        ERROR_NO_DATA:
            Result := True;
    else
        Result := False;
    end;
end;

constructor TncIpcClient.create(const auto_start: Boolean; const transaction_timeout_ms: DWORD;
    const pipe_name: string);
begin
    inherited create;
    if pipe_name <> '' then
    begin
        m_pipe_name := pipe_name;
    end
    else
    begin
        m_pipe_name := get_nc_pipe_name;
    end;
    m_auto_start := auto_start;
    m_transaction_timeout_ms := transaction_timeout_ms;
    m_unresponsive_until_tick := 0;
    m_last_start_tick := 0;
    m_last_start_error := 0;
    m_last_start_detail := '';
    m_last_error := 0;
end;

function TncIpcClient.wait_for_host_ready(const timeout_ms: DWORD): Boolean;
var
    start_tick: DWORD;
begin
    Result := False;
    start_tick := GetTickCount;
    repeat
        if ping_host then
        begin
            Result := True;
            Exit;
        end;
        WaitNamedPipe(PChar(m_pipe_name), c_pipe_timeout_ms div 2);
        Sleep(c_call_retry_sleep_ms);
    until elapsed_since(start_tick, timeout_ms);
end;

function TncIpcClient.transact(const request_bytes: TBytes; var response_bytes: TBytes;
    out bytes_read: DWORD): Boolean;
var
    pipe_handle: THandle;
    io_event: THandle;
    overlapped: TOverlapped;
    mode: DWORD;
    err: DWORD;
    timed_out: Boolean;
begin
    Result := False;
    bytes_read := 0;
    if (m_unresponsive_until_tick <> 0) and (GetTickCount64 < m_unresponsive_until_tick) then
    begin
        m_last_error := ERROR_TIMEOUT;
        Exit;
    end;
    if (Length(request_bytes) = 0) or (Length(response_bytes) = 0) then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Exit;
    end;

    // Same availability semantics as CallNamedPipe: one bounded wait for a
    // free instance, then a second open attempt.
    pipe_handle := CreateFile(PChar(m_pipe_name), GENERIC_READ or GENERIC_WRITE, 0, nil,
        OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0);
    if pipe_handle = INVALID_HANDLE_VALUE then
    begin
        if not WaitNamedPipe(PChar(m_pipe_name), c_pipe_timeout_ms) then
        begin
            m_last_error := GetLastError;
            Exit;
        end;
        pipe_handle := CreateFile(PChar(m_pipe_name), GENERIC_READ or GENERIC_WRITE, 0, nil,
            OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0);
        if pipe_handle = INVALID_HANDLE_VALUE then
        begin
            m_last_error := GetLastError;
            Exit;
        end;
    end;

    io_event := 0;
    try
        mode := PIPE_READMODE_MESSAGE;
        if not SetNamedPipeHandleState(pipe_handle, mode, nil, nil) then
        begin
            m_last_error := GetLastError;
            Exit;
        end;
        io_event := CreateEvent(nil, True, False, nil);
        if io_event = 0 then
        begin
            m_last_error := GetLastError;
            Exit;
        end;
        FillChar(overlapped, SizeOf(overlapped), 0);
        overlapped.hEvent := io_event;
        if not TransactNamedPipe(pipe_handle, @request_bytes[0], Length(request_bytes),
            @response_bytes[0], Length(response_bytes), bytes_read, @overlapped) then
        begin
            err := GetLastError;
            if err <> ERROR_IO_PENDING then
            begin
                m_last_error := err;
                Exit;
            end;
        end;
        timed_out := WaitForSingleObject(io_event, m_transaction_timeout_ms) <> WAIT_OBJECT_0;
        if timed_out then
        begin
            CancelIoEx(pipe_handle, @overlapped);
        end;
        // After a cancellation, wait for completion before the buffers and
        // the OVERLAPPED record go out of scope.
        if not GetOverlappedResult(pipe_handle, overlapped, bytes_read, timed_out) then
        begin
            err := GetLastError;
            if timed_out and (err = ERROR_OPERATION_ABORTED) then
            begin
                // The host may still apply this request; callers must not
                // resend it, and later calls fail fast for a short while.
                m_unresponsive_until_tick := GetTickCount64 + c_nc_ipc_unresponsive_backoff_ms;
                m_last_error := ERROR_TIMEOUT;
            end
            else
            begin
                m_last_error := err;
            end;
            Exit;
        end;
        m_unresponsive_until_tick := 0;
        m_last_error := ERROR_SUCCESS;
        Result := True;
    finally
        if io_event <> 0 then
        begin
            CloseHandle(io_event);
        end;
        CloseHandle(pipe_handle);
    end;
end;

function TncIpcClient.ping_host: Boolean;
var
    request_bytes: TBytes;
    response_bytes: TBytes;
    bytes_read: DWORD;
    response_text: string;
    call_ok: Boolean;
begin
    Result := False;
    request_bytes := TEncoding.UTF8.GetBytes('PING');
    SetLength(response_bytes, 32);
    bytes_read := 0;

    call_ok := transact(request_bytes, response_bytes, bytes_read);
    if (not call_ok) and is_pipe_waitable_error(m_last_error) then
    begin
        if WaitNamedPipe(PChar(m_pipe_name), c_pipe_timeout_ms) then
        begin
            call_ok := transact(request_bytes, response_bytes, bytes_read);
        end;
    end;

    if not call_ok then
    begin
        Exit;
    end;

    response_text := TEncoding.UTF8.GetString(response_bytes, 0, bytes_read);
    Result := SameText(Trim(response_text), 'OK');
    if Result then
    begin
        m_last_error := 0;
    end
    else
    begin
        m_last_error := ERROR_INVALID_DATA;
    end;
end;

function TncIpcClient.get_module_directory: string;
var
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
    module_handle: HMODULE;
begin
    module_handle := GetModuleHandle(c_tsf_module_name);
    if module_handle = 0 then
    begin
        if not get_module_handle_ex(c_get_module_handle_ex_from_address or c_get_module_handle_ex_unchanged_refcount,
            @ipc_module_anchor, module_handle) then
        begin
            module_handle := HInstance;
        end;
    end;

    path_len := GetModuleFileName(module_handle, path_buffer, Length(path_buffer));
    if path_len = 0 then
    begin
        Result := '';
        Exit;
    end;

    Result := ExtractFileDir(path_buffer);
end;

function TncIpcClient.start_host: Boolean;
var
    exe_path: string;
    start_info: TStartupInfo;
    proc_info: TProcessInformation;
    command_line: string;
    now_tick: DWORD;
    module_dir: string;
    resolution_detail: string;
    resolved: Boolean;
begin
    Result := False;
    now_tick := GetTickCount;
    if is_host_running then
    begin
        m_last_start_tick := now_tick;
        m_last_error := 0;
        m_last_start_error := 0;
        m_last_start_detail := 'host already responding';
        Result := True;
        Exit;
    end;
    if host_mutex_exists then
    begin
        // Another instance is already starting/running; do not spawn again.
        m_last_start_tick := now_tick;
        m_last_error := 0;
        m_last_start_error := 0;
        m_last_start_detail := 'host startup mutex exists; waiting for pipe';
        Result := True;
        Exit;
    end;
    if (m_last_start_tick <> 0) and (now_tick - m_last_start_tick < c_start_retry_delay_ms) then
    begin
        m_last_error := m_last_start_error;
        if m_last_error = ERROR_SUCCESS then
            m_last_error := ERROR_RETRY;
        Exit;
    end;

    // Failed starts need the same backoff as successful ones. Preserve the
    // actual failure instead of replacing it with a later missing-pipe error.
    m_last_start_tick := now_tick;
    module_dir := get_module_directory;
    m_last_start_detail := 'resolve_host module_dir=' + module_dir;
    resolved := nc_resolve_runtime_host(module_dir, exe_path, m_last_error, resolution_detail);
    m_last_start_detail := m_last_start_detail + ' ' + resolution_detail;
    if not resolved then
    begin
        m_last_start_error := m_last_error;
        Exit;
    end;
    m_last_start_detail := 'CreateProcess host_path=' + exe_path;

    FillChar(start_info, SizeOf(start_info), 0);
    start_info.cb := SizeOf(start_info);
    FillChar(proc_info, SizeOf(proc_info), 0);

    command_line := '"' + exe_path + '"';
    if CreateProcess(PChar(exe_path), PChar(command_line), nil, nil, False, CREATE_NO_WINDOW, nil,
        PChar(ExtractFileDir(exe_path)), start_info,
        proc_info) then
    begin
        m_last_start_detail := Format('started host_path=%s pid=%d',
            [exe_path, proc_info.dwProcessId]);
        CloseHandle(proc_info.hProcess);
        CloseHandle(proc_info.hThread);
        m_last_start_tick := now_tick;
        m_last_error := 0;
        m_last_start_error := 0;
        Result := True;
        Exit;
    end;

    m_last_error := GetLastError;
    m_last_start_error := m_last_error;
end;

function TncIpcClient.is_host_running: Boolean;
begin
    Result := ping_host;
end;

function TncIpcClient.host_mutex_exists: Boolean;
var
    mutex_handle: THandle;
    err: DWORD;
begin
    mutex_handle := OpenMutex(SYNCHRONIZE, False, PChar(get_nc_host_mutex));
    if mutex_handle <> 0 then
    begin
        CloseHandle(mutex_handle);
        Result := True;
        Exit;
    end;

    err := GetLastError;
    Result := err = ERROR_ACCESS_DENIED;
end;

function TncIpcClient.call_pipe(const request_text: string; out response_text: string): Boolean;
var
    request_bytes: TBytes;
    response_bytes: TBytes;
    bytes_read: DWORD;
    err: DWORD;
    retry_count: Integer;
    started_host: Boolean;
begin
    response_text := '';
    if request_text = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    request_bytes := TEncoding.UTF8.GetBytes(request_text);
    SetLength(response_bytes, 65536);
    started_host := False;
    for retry_count := 0 to c_call_retry_max - 1 do
    begin
        Result := transact(request_bytes, response_bytes, bytes_read);
        if Result then
        begin
            response_text := TEncoding.UTF8.GetString(response_bytes, 0, bytes_read);
            Exit;
        end;

        err := m_last_error;
        if err = ERROR_TIMEOUT then
        begin
            // The request may be in progress on the host; never resend it.
            Break;
        end;

        if (err = ERROR_FILE_NOT_FOUND) and m_auto_start and (not started_host) then
        begin
            started_host := True;
            if not start_host then
            begin
                // There is no process to wait for. In-proc callers must return
                // immediately, with the resolver/CreateProcess error intact.
                Result := False;
                Exit;
            end;
            if wait_for_host_ready(c_start_wait_ms) then
            begin
                Continue;
            end;
        end;

        if is_pipe_waitable_error(err) then
        begin
            WaitNamedPipe(PChar(m_pipe_name), c_pipe_timeout_ms);
            Sleep(c_call_retry_sleep_ms);
            Continue;
        end;

        if (err = ERROR_FILE_NOT_FOUND) or (err = ERROR_ACCESS_DENIED) then
        begin
            Sleep(c_call_retry_sleep_ms);
            Continue;
        end;

        Break;
    end;
end;

function TncIpcClient.test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
    out handled: Boolean): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    handled := False;
    request_text := Format('TEST_KEY'#9'%s'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d',
        [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down),
        Ord(key_state.alt_down), Ord(key_state.caps_lock)]);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    if (Length(fields) >= 2) and SameText(fields[0], 'OK') then
    begin
        handled := flag_to_bool(fields[1]);
        Result := True;
    end
    else
    begin
        Result := False;
    end;
end;

function TncIpcClient.process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
    out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
    out full_width_mode: Boolean; out punctuation_full_width: Boolean; out lookup_perf_info: string;
    const input_epoch: UInt64; const selection_window: HWND;
    const selection_token: Cardinal; const candidate_click: Boolean;
    const punctuation_preceding_char: Integer): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
    mode_value: Integer;
begin
    handled := False;
    commit_text := '';
    display_text := '';
    input_mode := im_chinese;
    full_width_mode := False;
    punctuation_full_width := False;
    lookup_perf_info := '';
    // Invalid clicks must never degrade into PROCESS_KEY (in particular Space).
    if (candidate_click and ((selection_token = 0) or (selection_window = 0))) or
        ((not candidate_click) and (selection_token <> 0)) or
        (punctuation_preceding_char < -1) or
        (punctuation_preceding_char > High(Word)) then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Exit(False);
    end;
    request_text := Format('PROCESS_KEY'#9'%s'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d',
        [session_id, key_code, Ord(key_state.shift_down), Ord(key_state.ctrl_down),
        Ord(key_state.alt_down), Ord(key_state.caps_lock)]);
    if (input_epoch <> 0) or (selection_window <> 0) or (selection_token <> 0) or
        (punctuation_preceding_char >= 0) then
    begin
        // Older hosts ignore the extra field.
        request_text := request_text + #9 + UIntToStr(input_epoch);
    end;
    if (selection_window <> 0) or (selection_token <> 0) or
        (punctuation_preceding_char >= 0) then
        request_text := request_text + #9 + UIntToStr(selection_window);
    if candidate_click then
    begin
        // A separate command prevents an old host from interpreting a click
        // as an ordinary key after ignoring the new fields.
        request_text := 'SELECT_CANDIDATE' + Copy(request_text, Length('PROCESS_KEY') + 1, MaxInt);
        request_text := request_text + #9 + UIntToStr(selection_token);
    end;
    if punctuation_preceding_char >= 0 then
    begin
        if not candidate_click then request_text := request_text + #9'0';
        request_text := request_text + #9 + IntToStr(punctuation_preceding_char);
    end;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    if (Length(fields) >= 2) and SameText(fields[0], 'OK') then
    begin
        handled := flag_to_bool(fields[1]);
        if Length(fields) >= 3 then
        begin
            commit_text := decode_ipc_text(fields[2]);
        end;
        if Length(fields) >= 4 then
        begin
            display_text := decode_ipc_text(fields[3]);
        end;
        if Length(fields) >= 5 then
        begin
            mode_value := StrToIntDef(fields[4], Ord(im_chinese));
            if (mode_value < Ord(Low(TncInputMode))) or (mode_value > Ord(High(TncInputMode))) then
            begin
                mode_value := Ord(im_chinese);
            end;
            input_mode := TncInputMode(mode_value);
        end;
        if Length(fields) >= 6 then
        begin
            full_width_mode := flag_to_bool(fields[5]);
        end;
        if Length(fields) >= 7 then
        begin
            punctuation_full_width := flag_to_bool(fields[6]);
        end;
        if Length(fields) >= 8 then
        begin
            lookup_perf_info := decode_ipc_text(fields[7]);
        end;
        Result := True;
    end
    else
    begin
        Result := False;
    end;
end;

function TncIpcClient.get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
    out punctuation_full_width: Boolean): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
    mode_value: Integer;
begin
    input_mode := im_chinese;
    full_width_mode := False;
    punctuation_full_width := False;

    request_text := 'GET_STATE'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    if (Length(fields) >= 4) and SameText(fields[0], 'OK') then
    begin
        mode_value := StrToIntDef(fields[1], Ord(im_chinese));
        if (mode_value < Ord(Low(TncInputMode))) or (mode_value > Ord(High(TncInputMode))) then
        begin
            mode_value := Ord(im_chinese);
        end;
        input_mode := TncInputMode(mode_value);
        full_width_mode := flag_to_bool(fields[2]);
        punctuation_full_width := flag_to_bool(fields[3]);
        Result := True;
        Exit;
    end;

    Result := False;
end;

function try_parse_shortcut_config_response(const response_text: string;
    out shortcut_config: TncShortcutConfig): Boolean;
var
    fields: TArray<string>;
    parsed_config: TncShortcutConfig;
begin
    shortcut_config := nc_default_shortcut_config;
    fields := response_text.Split([#9], TStringSplitOptions.None);
    if (Length(fields) < 6) or (not SameText(fields[0], 'OK')) then
    begin
        Exit(False);
    end;

    parsed_config.signature := c_nc_shortcut_config_signature;
    if (not nc_try_parse_shortcut(fields[1], parsed_config.input_mode_toggle)) or
        (not nc_try_parse_shortcut(fields[2], parsed_config.punctuation_toggle)) or
        (not nc_try_parse_shortcut(fields[3], parsed_config.dictionary_variant_toggle)) or
        (not nc_try_parse_shortcut(fields[4], parsed_config.full_width_toggle)) or
        (not nc_try_parse_shortcut(fields[5], parsed_config.open_settings)) or
        nc_shortcut_config_has_duplicates(parsed_config) then
    begin
        Exit(False);
    end;

    shortcut_config := parsed_config;
    Result := True;
end;

function TncIpcClient.get_shortcut_config(const session_id: string;
    out shortcut_config: TncShortcutConfig): Boolean;
var
    request_text: string;
    response_text: string;
begin
    shortcut_config := nc_default_shortcut_config;
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Exit(False);
    end;

    request_text := 'GET_SHORTCUTS'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Exit(False);
    end;

    Result := try_parse_shortcut_config_response(response_text,
        shortcut_config);
end;

function TncIpcClient.get_dictionary_variant(const session_id: string; out dictionary_variant: TncDictionaryVariant): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
    variant_value: Integer;
begin
    dictionary_variant := dv_simplified;
    request_text := 'GET_VARIANT'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    if (Length(fields) >= 2) and SameText(fields[0], 'OK') then
    begin
        variant_value := StrToIntDef(fields[1], Ord(dv_simplified));
        if (variant_value < Ord(Low(TncDictionaryVariant))) or
            (variant_value > Ord(High(TncDictionaryVariant))) then
        begin
            variant_value := Ord(dv_simplified);
        end;
        dictionary_variant := TncDictionaryVariant(variant_value);
        Result := True;
        Exit;
    end;

    Result := False;
end;

function TncIpcClient.get_active(const session_id: string; out active: Boolean): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    active := False;
    request_text := 'GET_ACTIVE'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    if (Length(fields) >= 2) and SameText(fields[0], 'OK') then
    begin
        active := flag_to_bool(fields[1]);
        Result := True;
        Exit;
    end;

    Result := False;
end;

function TncIpcClient.set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean; const source: string): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    request_text := build_set_state_request(session_id, input_mode,
        full_width_mode, punctuation_full_width, source);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function build_set_state_request(const session_id: string;
    const input_mode: TncInputMode; const full_width_mode: Boolean;
    const punctuation_full_width: Boolean; const source: string): string;
begin
    Result := Format('SET_STATE'#9'%s'#9'%d'#9'%d'#9'%d',
        [session_id, Ord(input_mode), Ord(full_width_mode),
        Ord(punctuation_full_width)]);
    if source <> '' then
    begin
        Result := Result + #9 + encode_ipc_text(source);
    end;
end;

function TncIpcClient.set_dictionary_variant(const session_id: string;
    const dictionary_variant: TncDictionaryVariant): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    request_text := Format('SET_VARIANT'#9'%s'#9'%d', [session_id, Ord(dictionary_variant)]);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.set_active(const session_id: string; const active: Boolean): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    request_text := Format('SET_ACTIVE'#9'%s'#9'%d', [session_id, Ord(active)]);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.release_session(const session_id: string): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    request_text := 'RELEASE_SESSION'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.set_caret(const session_id: string; const point: TPoint; const has_caret: Boolean;
    const line_height: Integer; const source: TncCaretAnchorSource; const anchor_score: Integer;
    const terminal_like_target: Boolean; const comless_target: Boolean): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    request_text := build_set_caret_request(session_id, point, has_caret,
        line_height, source, anchor_score, terminal_like_target, comless_target);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function build_set_caret_request(const session_id: string;
    const point: TPoint; const has_caret: Boolean; const line_height: Integer;
    const source: TncCaretAnchorSource; const anchor_score: Integer;
    const terminal_like_target: Boolean; const comless_target: Boolean): string;
begin
    Result := Format('SET_CARET'#9'%s'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d',
        [session_id, point.X, point.Y, Ord(has_caret), line_height,
        Ord(source), anchor_score, Ord(terminal_like_target),
        Ord(comless_target)]);
end;

function TncIpcClient.set_surrounding(const session_id: string;
    const left_context: string; const document_key: string;
    const document_snapshot: string): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    if (document_key <> '') and (document_snapshot <> '') then
    begin
        request_text := 'SET_SURROUNDING'#9 + session_id + #9 +
            encode_ipc_text(document_key) + #9 + encode_ipc_text(left_context) +
            #9 + encode_ipc_text(document_snapshot);
    end
    else if document_key <> '' then
    begin
        request_text := 'SET_SURROUNDING'#9 + session_id + #9 +
            encode_ipc_text(document_key) + #9 + encode_ipc_text(left_context);
    end
    else
    begin
        request_text := 'SET_SURROUNDING'#9 + session_id + #9 +
            encode_ipc_text(left_context);
    end;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.reload_config(const session_id: string): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    request_text := 'RELOAD_CONFIG'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.clear_user_dictionary(const session_id: string): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if session_id = '' then
    begin
        m_last_error := ERROR_INVALID_PARAMETER;
        Result := False;
        Exit;
    end;

    request_text := 'CLEAR_USER_DICTIONARY'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.reset_session(const session_id: string;
    const preserve_document_context: Boolean; const input_epoch: UInt64): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    if preserve_document_context then
    begin
        request_text := 'RESET_KEEP_DOCUMENT'#9 + session_id;
    end
    else
    begin
        request_text := 'RESET'#9 + session_id;
    end;
    if input_epoch <> 0 then
    begin
        request_text := request_text + #9 + UIntToStr(input_epoch);
    end;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

end.
