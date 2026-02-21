unit nc_ipc_client;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Types,
    nc_types;

type
    TncIpcClient = class
    private
        m_pipe_name: string;
        m_auto_start: Boolean;
        m_last_start_tick: DWORD;
        m_last_error: DWORD;
        function call_pipe(const request_text: string; out response_text: string): Boolean;
        function ping_host: Boolean;
        function start_host: Boolean;
        function wait_for_host_ready(const timeout_ms: DWORD): Boolean;
        function host_mutex_exists: Boolean;
        function is_host_running: Boolean;
        function get_module_directory: string;
    public
        constructor create(const auto_start: Boolean = True);
        function test_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean): Boolean;
        function process_key(const session_id: string; const key_code: Word; const key_state: TncKeyState;
            out handled: Boolean; out commit_text: string; out display_text: string; out input_mode: TncInputMode;
            out full_width_mode: Boolean; out punctuation_full_width: Boolean): Boolean;
        function get_state(const session_id: string; out input_mode: TncInputMode; out full_width_mode: Boolean;
            out punctuation_full_width: Boolean): Boolean;
        function get_active(const session_id: string; out active: Boolean): Boolean;
        function set_state(const session_id: string; const input_mode: TncInputMode; const full_width_mode: Boolean;
            const punctuation_full_width: Boolean): Boolean;
        function set_active(const session_id: string; const active: Boolean): Boolean;
        function set_caret(const session_id: string; const point: TPoint; const has_caret: Boolean): Boolean;
        function set_surrounding(const session_id: string; const left_context: string): Boolean;
        function reset_session(const session_id: string): Boolean;
        property last_error: DWORD read m_last_error;
    end;

implementation

uses
    nc_ipc_common;

const
    c_pipe_timeout_ms = 220;
    c_start_retry_delay_ms = 1500;
    c_start_wait_ms = 500;
    c_call_retry_max = 3;
    c_call_retry_sleep_ms = 30;
    c_get_module_handle_ex_from_address = $00000004;
    c_get_module_handle_ex_unchanged_refcount = $00000002;
{$IFDEF WIN32}
    c_tsf_module_name = 'cassotis_ime_svr32.dll';
    c_host_exe_prefer = 'cassotis_ime_host.exe';
    c_host_exe_fallback = 'cassotis_ime_host.exe';
{$ELSE}
    c_tsf_module_name = 'cassotis_ime_svr.dll';
    c_host_exe_prefer = 'cassotis_ime_host.exe';
    c_host_exe_fallback = 'cassotis_ime_host.exe';
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

constructor TncIpcClient.create(const auto_start: Boolean);
begin
    inherited create;
    m_pipe_name := get_nc_pipe_name;
    m_auto_start := auto_start;
    m_last_start_tick := 0;
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

function TncIpcClient.ping_host: Boolean;
var
    request_bytes: TBytes;
    response_bytes: TBytes;
    bytes_read: DWORD;
    response_text: string;
    call_ok: Boolean;
    err: DWORD;
begin
    Result := False;
    request_bytes := TEncoding.UTF8.GetBytes('PING');
    SetLength(response_bytes, 32);
    bytes_read := 0;

    call_ok := CallNamedPipe(PChar(m_pipe_name), @request_bytes[0], Length(request_bytes),
        @response_bytes[0], Length(response_bytes), bytes_read, c_pipe_timeout_ms);
    if not call_ok then
    begin
        err := GetLastError;
        m_last_error := err;
        if is_pipe_waitable_error(err) then
        begin
            if WaitNamedPipe(PChar(m_pipe_name), c_pipe_timeout_ms) then
            begin
                call_ok := CallNamedPipe(PChar(m_pipe_name), @request_bytes[0], Length(request_bytes),
                    @response_bytes[0], Length(response_bytes), bytes_read, c_pipe_timeout_ms);
                if not call_ok then
                begin
                    m_last_error := GetLastError;
                end;
            end;
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
    module_dir: string;
    start_info: TStartupInfo;
    proc_info: TProcessInformation;
    command_line: string;
    now_tick: DWORD;
begin
    Result := False;
    now_tick := GetTickCount;
    if is_host_running then
    begin
        m_last_start_tick := now_tick;
        m_last_error := 0;
        Result := True;
        Exit;
    end;
    if host_mutex_exists then
    begin
        // Another instance is already starting/running; do not spawn again.
        m_last_start_tick := now_tick;
        m_last_error := 0;
        Result := True;
        Exit;
    end;
    if (m_last_start_tick <> 0) and (now_tick - m_last_start_tick < c_start_retry_delay_ms) then
    begin
        Exit;
    end;

    module_dir := IncludeTrailingPathDelimiter(get_module_directory);
    exe_path := module_dir + c_host_exe_prefer;
    if not FileExists(exe_path) then
    begin
        exe_path := module_dir + c_host_exe_fallback;
    end;
    if not FileExists(exe_path) then
    begin
        m_last_error := ERROR_FILE_NOT_FOUND;
        Exit;
    end;

    FillChar(start_info, SizeOf(start_info), 0);
    start_info.cb := SizeOf(start_info);
    FillChar(proc_info, SizeOf(proc_info), 0);

    command_line := '"' + exe_path + '"';
    if CreateProcess(PChar(exe_path), PChar(command_line), nil, nil, False, CREATE_NO_WINDOW, nil, nil, start_info,
        proc_info) then
    begin
        CloseHandle(proc_info.hProcess);
        CloseHandle(proc_info.hThread);
        m_last_start_tick := now_tick;
        m_last_error := 0;
        Result := True;
        Exit;
    end;

    m_last_error := GetLastError;
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
        Result := CallNamedPipe(PChar(m_pipe_name), @request_bytes[0], Length(request_bytes),
            @response_bytes[0], Length(response_bytes), bytes_read, c_pipe_timeout_ms);
        if Result then
        begin
            response_text := TEncoding.UTF8.GetString(response_bytes, 0, bytes_read);
            m_last_error := 0;
            Exit;
        end;

        err := GetLastError;
        m_last_error := err;

        if (err = ERROR_FILE_NOT_FOUND) and m_auto_start and (not started_host) then
        begin
            started_host := True;
            start_host;
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
    out full_width_mode: Boolean; out punctuation_full_width: Boolean): Boolean;
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
    request_text := Format('PROCESS_KEY'#9'%s'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d',
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
    const punctuation_full_width: Boolean): Boolean;
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

    request_text := Format('SET_STATE'#9'%s'#9'%d'#9'%d'#9'%d',
        [session_id, Ord(input_mode), Ord(full_width_mode), Ord(punctuation_full_width)]);
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

function TncIpcClient.set_caret(const session_id: string; const point: TPoint; const has_caret: Boolean): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    request_text := Format('SET_CARET'#9'%s'#9'%d'#9'%d'#9'%d',
        [session_id, point.X, point.Y, Ord(has_caret)]);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.set_surrounding(const session_id: string; const left_context: string): Boolean;
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

    request_text := 'SET_SURROUNDING'#9 + session_id + #9 + encode_ipc_text(left_context);
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

function TncIpcClient.reset_session(const session_id: string): Boolean;
var
    request_text: string;
    response_text: string;
    fields: TArray<string>;
begin
    request_text := 'RESET'#9 + session_id;
    if not call_pipe(request_text, response_text) then
    begin
        Result := False;
        Exit;
    end;

    fields := response_text.Split([#9], TStringSplitOptions.None);
    Result := (Length(fields) >= 1) and SameText(fields[0], 'OK');
end;

end.
