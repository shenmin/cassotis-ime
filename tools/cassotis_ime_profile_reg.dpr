program cassotis_ime_profile_reg;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    System.Classes,
    System.StrUtils,
    System.IOUtils,
    System.Generics.Collections,
    System.Win.Registry,
    Winapi.Windows,
    Winapi.ShellAPI,
    Winapi.TlHelp32,
    Winapi.ActiveX,
    Winapi.Msctf,
    ComObj,
    nc_tsf_guids in '..\src\tsf\nc_tsf_guids.pas';

const
    TF_E_ALREADY_EXISTS = HRESULT($80005006);

type
    TncProcessInfo = record
        name: string;
        pid: Cardinal;
    end;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_profile_reg register|unregister|register_tsf|unregister_tsf|start|stop');
end;

function hr_succeeded(const hr: HRESULT): Boolean;
begin
    Result := hr >= 0;
end;

function hr_ok_or_exists(const hr: HRESULT): Boolean;
begin
    Result := hr_succeeded(hr) or (hr = TF_E_ALREADY_EXISTS);
end;

function quote_command_arg(const value: string): string;
begin
    if value = '' then
    begin
        Exit('""');
    end;

    if (Pos(' ', value) > 0) or (Pos(#9, value) > 0) or (Pos('"', value) > 0) then
    begin
        Result := '"' + StringReplace(value, '"', '\"', [rfReplaceAll]) + '"';
    end
    else
    begin
        Result := value;
    end;
end;

function build_command_line(const file_path: string; const arguments: array of string): string;
var
    idx: Integer;
begin
    Result := quote_command_arg(file_path);
    for idx := Low(arguments) to High(arguments) do
    begin
        Result := Result + ' ' + quote_command_arg(arguments[idx]);
    end;
end;

function execute_process_hidden(const file_path: string; const arguments: array of string;
    const wait: Boolean; out exit_code: Cardinal; const current_directory: string = ''): Boolean;
var
    startup_info: TStartupInfo;
    process_info: TProcessInformation;
    command_line: string;
    working_dir: PChar;
begin
    Result := False;
    exit_code := Cardinal(-1);
    FillChar(startup_info, SizeOf(startup_info), 0);
    startup_info.cb := SizeOf(startup_info);
    startup_info.dwFlags := STARTF_USESHOWWINDOW;
    startup_info.wShowWindow := SW_HIDE;
    FillChar(process_info, SizeOf(process_info), 0);

    command_line := build_command_line(file_path, arguments);
    UniqueString(command_line);
    if current_directory <> '' then
    begin
        working_dir := PChar(current_directory);
    end
    else
    begin
        working_dir := nil;
    end;
    if not CreateProcess(PChar(file_path), PChar(command_line), nil, nil, False,
        CREATE_NO_WINDOW, nil, working_dir, startup_info, process_info) then
    begin
        Exit;
    end;

    CloseHandle(process_info.hThread);
    try
        if wait then
        begin
            WaitForSingleObject(process_info.hProcess, INFINITE);
            GetExitCodeProcess(process_info.hProcess, exit_code);
        end
        else
        begin
            exit_code := 0;
        end;
        Result := True;
    finally
        CloseHandle(process_info.hProcess);
    end;
end;

function execute_process_capture_stdout(const file_path: string; const arguments: array of string;
    out output_text: string; out exit_code: Cardinal): Boolean;
var
    startup_info: TStartupInfo;
    process_info: TProcessInformation;
    security_attr: TSecurityAttributes;
    read_pipe: THandle;
    write_pipe: THandle;
    command_line: string;
    buffer: array[0..4095] of Byte;
    bytes_read: DWORD;
    stream: TBytesStream;
begin
    Result := False;
    output_text := '';
    exit_code := Cardinal(-1);
    read_pipe := 0;
    write_pipe := 0;
    stream := nil;
    FillChar(security_attr, SizeOf(security_attr), 0);
    security_attr.nLength := SizeOf(security_attr);
    security_attr.bInheritHandle := True;
    if not CreatePipe(read_pipe, write_pipe, @security_attr, 0) then
    begin
        Exit;
    end;

    try
        SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);
        FillChar(startup_info, SizeOf(startup_info), 0);
        startup_info.cb := SizeOf(startup_info);
        startup_info.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
        startup_info.wShowWindow := SW_HIDE;
        startup_info.hStdOutput := write_pipe;
        startup_info.hStdError := write_pipe;
        startup_info.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
        FillChar(process_info, SizeOf(process_info), 0);

        command_line := build_command_line(file_path, arguments);
        UniqueString(command_line);
        if not CreateProcess(PChar(file_path), PChar(command_line), nil, nil, True,
            CREATE_NO_WINDOW, nil, nil, startup_info, process_info) then
        begin
            Exit;
        end;

        CloseHandle(process_info.hThread);
        CloseHandle(write_pipe);
        write_pipe := 0;

        try
            WaitForSingleObject(process_info.hProcess, INFINITE);
            GetExitCodeProcess(process_info.hProcess, exit_code);
        finally
            CloseHandle(process_info.hProcess);
        end;

        stream := TBytesStream.Create;
        while ReadFile(read_pipe, buffer, SizeOf(buffer), bytes_read, nil) and
            (bytes_read > 0) do
        begin
            stream.WriteBuffer(buffer, bytes_read);
        end;
        output_text := TEncoding.Default.GetString(stream.Bytes, 0, stream.Size);
        Result := True;
    finally
        stream.Free;
        if write_pipe <> 0 then
        begin
            CloseHandle(write_pipe);
        end;
        if read_pipe <> 0 then
        begin
            CloseHandle(read_pipe);
        end;
    end;
end;

function get_param_value(const name: string; out value: string): Boolean;
var
    idx: Integer;
    current: string;
begin
    Result := False;
    value := '';
    for idx := 2 to ParamCount do
    begin
        current := ParamStr(idx);
        if SameText(current, '-' + name) or SameText(current, '/' + name) then
        begin
            if idx < ParamCount then
            begin
                value := ParamStr(idx + 1);
                Exit(True);
            end;
            Exit(False);
        end;
        if StartsText('-' + name + '=', current) then
        begin
            value := Copy(current, Length(name) + 3, MaxInt);
            Exit(True);
        end;
        if StartsText('/' + name + '=', current) then
        begin
            value := Copy(current, Length(name) + 3, MaxInt);
            Exit(True);
        end;
    end;
end;

function has_switch(const name: string): Boolean;
var
    idx: Integer;
    current: string;
begin
    Result := False;
    for idx := 2 to ParamCount do
    begin
        current := ParamStr(idx);
        if SameText(current, '-' + name) or SameText(current, '/' + name) then
        begin
            Exit(True);
        end;
    end;
end;

function is_running_as_admin: Boolean;
var
    token: THandle;
    elevation: TOKEN_ELEVATION;
    return_length: DWORD;
begin
    Result := False;
    token := 0;
    if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, token) then
    begin
        try
            return_length := 0;
            if GetTokenInformation(token, TokenElevation, @elevation, SizeOf(elevation),
                return_length) then
            begin
                Exit(elevation.TokenIsElevated <> 0);
            end;
        finally
            CloseHandle(token);
        end;
    end;
end;

function get_pe_machine(const path: string; out machine: Word): Boolean;
var
    stream: TFileStream;
    mz: Word;
    pe_offset: Cardinal;
    pe_sig: Cardinal;
begin
    Result := False;
    machine := 0;
    if not FileExists(path) then
    begin
        Exit;
    end;

    stream := TFileStream.Create(path, fmOpenRead or fmShareDenyNone);
    try
        if stream.Read(mz, SizeOf(mz)) <> SizeOf(mz) then
        begin
            Exit;
        end;
        if mz <> $5A4D then
        begin
            Exit;
        end;

        stream.Position := $3C;
        if stream.Read(pe_offset, SizeOf(pe_offset)) <> SizeOf(pe_offset) then
        begin
            Exit;
        end;

        stream.Position := pe_offset;
        if stream.Read(pe_sig, SizeOf(pe_sig)) <> SizeOf(pe_sig) then
        begin
            Exit;
        end;
        if pe_sig <> $00004550 then
        begin
            Exit;
        end;

        if stream.Read(machine, SizeOf(machine)) <> SizeOf(machine) then
        begin
            machine := 0;
            Exit;
        end;
        Result := True;
    finally
        stream.Free;
    end;
end;

function test_expected_machine(const path: string; const machine: Word): Boolean;
var
    name: string;
begin
    name := LowerCase(ExtractFileName(path));
    if name = 'cassotis_ime_svr.dll' then
    begin
        Exit(machine = $8664);
    end;
    if name = 'cassotis_ime_svr32.dll' then
    begin
        Exit(machine = $014C);
    end;
    Result := True;
end;

function get_regsvr32_path(const path: string; out machine: Word): string;
begin
    machine := 0;
    if not get_pe_machine(path, machine) then
    begin
        Exit('');
    end;

    Result := TPath.Combine(GetEnvironmentVariable('WINDIR'), 'System32\regsvr32.exe');
    if machine = $014C then
    begin
        if FileExists(TPath.Combine(GetEnvironmentVariable('WINDIR'), 'SysWOW64\regsvr32.exe')) then
        begin
            Result := TPath.Combine(GetEnvironmentVariable('WINDIR'), 'SysWOW64\regsvr32.exe');
        end;
    end;
end;

function registry_access_for_machine(const machine: Word): LongWord;
begin
    if machine = $014C then
    begin
        Result := KEY_READ or KEY_WOW64_32KEY;
    end
    else
    begin
        Result := KEY_READ or KEY_WOW64_64KEY;
    end;
end;

function get_inproc_server_path(const clsid_text: string; const root_key: HKEY;
    const machine: Word): string;
var
    reg: TRegistry;
    key_path: string;
begin
    Result := '';
    reg := TRegistry.Create(registry_access_for_machine(machine));
    try
        reg.RootKey := root_key;
        if root_key = HKEY_CLASSES_ROOT then
        begin
            key_path := 'CLSID\' + clsid_text + '\InprocServer32';
        end
        else
        begin
            key_path := 'Software\Classes\CLSID\' + clsid_text + '\InprocServer32';
        end;
        if reg.OpenKeyReadOnly(key_path) then
        begin
            try
                Result := reg.ReadString('');
            finally
                reg.CloseKey;
            end;
        end;
    finally
        reg.Free;
    end;
end;

function normalize_compare_path(const value: string): string;
begin
    Result := Trim(value).Trim(['"']);
    if Result = '' then
    begin
        Exit('');
    end;
    try
        Result := LowerCase(TPath.GetFullPath(Result));
    except
        Result := LowerCase(Result);
    end;
end;

function is_com_registered_for_target(const clsid_text: string; const target_path: string;
    const machine: Word): Boolean;
var
    expected_path: string;
    expected_name: string;
    actual_path: string;
    root_key: HKEY;
begin
    Result := False;
    expected_path := normalize_compare_path(target_path);
    expected_name := LowerCase(ExtractFileName(target_path));
    for root_key in [HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE, HKEY_CLASSES_ROOT] do
    begin
        actual_path := get_inproc_server_path(clsid_text, root_key, machine);
        if actual_path = '' then
        begin
            Continue;
        end;
        actual_path := normalize_compare_path(actual_path);
        if (actual_path = expected_path) or
            (LowerCase(ExtractFileName(actual_path)) = expected_name) then
        begin
            Exit(True);
        end;
    end;
end;

function resolve_target_paths(const input_path: string; const single_mode: Boolean): TArray<string>;
var
    resolved: string;
    dir: string;
    name: string;
    other: string;
    items: TList<string>;
begin
    items := TList<string>.Create;
    try
        resolved := TPath.GetFullPath(input_path);
        items.Add(resolved);
        if not single_mode then
        begin
            dir := ExtractFileDir(resolved);
            name := LowerCase(ExtractFileName(resolved));
            if name = 'cassotis_ime_svr.dll' then
            begin
                other := TPath.Combine(dir, 'cassotis_ime_svr32.dll');
                if FileExists(other) then
                begin
                    items.Add(other);
                end;
            end
            else if name = 'cassotis_ime_svr32.dll' then
            begin
                other := TPath.Combine(dir, 'cassotis_ime_svr.dll');
                if FileExists(other) then
                begin
                    items.Add(other);
                end;
            end;
        end;
        Result := items.ToArray;
    finally
        items.Free;
    end;
end;

function get_default_dll_path: string;
begin
    Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'cassotis_ime_svr.dll');
end;

function process_name_matches(const process_name: string; const expected_name: string): Boolean;
begin
    Result := SameText(process_name, expected_name) or
        SameText(ChangeFileExt(process_name, ''), expected_name) or
        SameText(process_name, expected_name + '.exe');
end;

function enumerate_processes_by_name(const expected_name: string): TArray<TncProcessInfo>;
var
    snapshot: THandle;
    entry: TProcessEntry32;
    list: TList<TncProcessInfo>;
    info: TncProcessInfo;
begin
    list := TList<TncProcessInfo>.Create;
    try
        snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if snapshot = INVALID_HANDLE_VALUE then
        begin
            Exit(list.ToArray);
        end;
        try
            FillChar(entry, SizeOf(entry), 0);
            entry.dwSize := SizeOf(entry);
            if Process32First(snapshot, entry) then
            begin
                repeat
                    if process_name_matches(entry.szExeFile, expected_name) then
                    begin
                        info.name := string(entry.szExeFile);
                        info.pid := entry.th32ProcessID;
                        list.Add(info);
                    end;
                until not Process32Next(snapshot, entry);
            end;
        finally
            CloseHandle(snapshot);
        end;
        Result := list.ToArray;
    finally
        list.Free;
    end;
end;

function terminate_process_id(const process_id: Cardinal): Boolean;
var
    process_handle: THandle;
begin
    Result := False;
    process_handle := OpenProcess(PROCESS_TERMINATE or SYNCHRONIZE, False, process_id);
    if process_handle = 0 then
    begin
        Exit;
    end;
    try
        if TerminateProcess(process_handle, 0) then
        begin
            WaitForSingleObject(process_handle, 5000);
            Result := True;
        end;
    finally
        CloseHandle(process_handle);
    end;
end;

function is_process_running(const expected_name: string): Boolean;
begin
    Result := Length(enumerate_processes_by_name(expected_name)) > 0;
end;

function stop_named_processes(const expected_name: string): Boolean;
var
    processes: TArray<TncProcessInfo>;
    idx: Integer;
begin
    Result := True;
    processes := enumerate_processes_by_name(expected_name);
    for idx := 0 to High(processes) do
    begin
        if terminate_process_id(processes[idx].pid) then
        begin
            Writeln(Format('Stopped %s (PID %d)', [expected_name, processes[idx].pid]));
        end
        else
        begin
            Writeln(Format('Failed to stop %s (PID %d)', [expected_name, processes[idx].pid]));
            Result := False;
        end;
    end;
end;

function parse_csv_fields(const line: string): TArray<string>;
var
    idx: Integer;
    in_quotes: Boolean;
    current: string;
    list: TList<string>;
begin
    list := TList<string>.Create;
    try
        in_quotes := False;
        current := '';
        idx := 1;
        while idx <= Length(line) do
        begin
            if line[idx] = '"' then
            begin
                if in_quotes and (idx < Length(line)) and (line[idx + 1] = '"') then
                begin
                    current := current + '"';
                    Inc(idx);
                end
                else
                begin
                    in_quotes := not in_quotes;
                end;
            end
            else if (line[idx] = ',') and (not in_quotes) then
            begin
                list.Add(current);
                current := '';
            end
            else
            begin
                current := current + line[idx];
            end;
            Inc(idx);
        end;
        list.Add(current);
        Result := list.ToArray;
    finally
        list.Free;
    end;
end;

function get_processes_using_dll(const dll_name: string): TArray<TncProcessInfo>;
var
    output_text: string;
    exit_code: Cardinal;
    lines: TStringList;
    idx: Integer;
    line: string;
    fields: TArray<string>;
    list: TList<TncProcessInfo>;
    seen: TDictionary<Cardinal, Boolean>;
    info: TncProcessInfo;
begin
    list := TList<TncProcessInfo>.Create;
    seen := TDictionary<Cardinal, Boolean>.Create;
    lines := TStringList.Create;
    try
        if not execute_process_capture_stdout('tasklist.exe',
            ['/m', dll_name, '/fo', 'csv', '/nh'], output_text, exit_code) then
        begin
            Exit(list.ToArray);
        end;
        if exit_code <> 0 then
        begin
            Exit(list.ToArray);
        end;

        lines.Text := output_text;
        for idx := 0 to lines.Count - 1 do
        begin
            line := Trim(lines[idx]);
            if line = '' then
            begin
                Continue;
            end;
            fields := parse_csv_fields(line);
            if Length(fields) < 2 then
            begin
                Continue;
            end;
            if not TryStrToUInt(Trim(fields[1]), info.pid) then
            begin
                Continue;
            end;
            if seen.ContainsKey(info.pid) then
            begin
                Continue;
            end;
            info.name := Trim(fields[0]);
            list.Add(info);
            seen.Add(info.pid, True);
        end;
        Result := list.ToArray;
    finally
        lines.Free;
        seen.Free;
        list.Free;
    end;
end;

function stop_processes_using_dlls(const dll_path: string; const force_kill: Boolean): Boolean;
var
    dll_names: TList<string>;
    processes: TDictionary<Cardinal, string>;
    found: TArray<TncProcessInfo>;
    idx: Integer;
    peer_name: string;
    dir: string;
    name: string;
    process_id: Cardinal;
    answer: string;
    found_idx: Integer;
begin
    Result := True;
    dll_names := TList<string>.Create;
    processes := TDictionary<Cardinal, string>.Create;
    try
        name := ExtractFileName(dll_path);
        if name <> '' then
        begin
            dll_names.Add(name);
        end;
        dir := ExtractFileDir(dll_path);
        if SameText(name, 'cassotis_ime_svr.dll') then
        begin
            peer_name := 'cassotis_ime_svr32.dll';
        end
        else if SameText(name, 'cassotis_ime_svr32.dll') then
        begin
            peer_name := 'cassotis_ime_svr.dll';
        end
        else
        begin
            peer_name := '';
        end;
        if (peer_name <> '') and FileExists(TPath.Combine(dir, peer_name)) then
        begin
            dll_names.Add(peer_name);
        end;

        for idx := 0 to dll_names.Count - 1 do
        begin
            found := get_processes_using_dll(dll_names[idx]);
            for found_idx := 0 to High(found) do
            begin
                if not processes.ContainsKey(found[found_idx].pid) then
                begin
                    processes.Add(found[found_idx].pid, found[found_idx].name);
                end;
            end;
        end;

        if processes.Count = 0 then
        begin
            Exit(True);
        end;

        Writeln('Processes using IME DLLs:');
        for process_id in processes.Keys do
        begin
            Writeln(Format('  %s (PID %d)', [processes[process_id], process_id]));
        end;

        if not force_kill then
        begin
            Write('Terminate these processes? (y/N): ');
            Readln(answer);
            if not SameText(answer, 'y') and not SameText(answer, 'yes') then
            begin
                Exit(False);
            end;
        end;

        for process_id in processes.Keys do
        begin
            if not terminate_process_id(process_id) then
            begin
                Result := False;
            end;
        end;
    finally
        processes.Free;
        dll_names.Free;
    end;
end;

function start_one_process_if_missing(const file_path: string; const process_name: string): Boolean;
var
    exec_result: HINST;
begin
    if not FileExists(file_path) then
    begin
        Exit(True);
    end;
    if is_process_running(process_name) then
    begin
        Exit(True);
    end;
    Writeln('Starting ' + process_name + '...');
    exec_result := ShellExecute(0, 'open', PChar(file_path), nil, PChar(ExtractFileDir(file_path)),
        SW_SHOWNORMAL);
    Result := NativeUInt(exec_result) > 32;
end;

function register_profile: Boolean; forward;
function unregister_profile: Boolean; forward;

function register_one_dll(const target_path: string; const clsid_text_service: string): Boolean;
var
    regsvr32_path: string;
    machine: Word;
    exit_code: Cardinal;
begin
    Result := False;
    regsvr32_path := get_regsvr32_path(target_path, machine);
    if machine = 0 then
    begin
        Writeln('Invalid PE file: ' + target_path);
        Exit;
    end;
    if not test_expected_machine(target_path, machine) then
    begin
        Writeln(Format('Architecture mismatch for file name: %s (machine=0x%.4x)',
            [target_path, machine]));
        Exit;
    end;

    Writeln(Format('regsvr32: %s (machine=0x%.4x)', [regsvr32_path, machine]));
    if not execute_process_hidden(regsvr32_path, ['/s', target_path], True, exit_code) then
    begin
        Writeln('Failed to launch regsvr32.');
        Exit;
    end;
    if exit_code <> 0 then
    begin
        Writeln('regsvr32 /s failed with exit code ' + IntToStr(exit_code));
    end;

    Result := is_com_registered_for_target(clsid_text_service, target_path, machine);
    if Result then
    begin
        Writeln('COM registered: ' + target_path);
    end
    else
    begin
        Writeln('COM registration not found after regsvr32: ' + target_path);
    end;
end;

function unregister_one_dll(const target_path: string; const clsid_text_service: string): Boolean;
var
    regsvr32_path: string;
    machine: Word;
    exit_code: Cardinal;
begin
    Result := False;
    regsvr32_path := get_regsvr32_path(target_path, machine);
    if machine = 0 then
    begin
        Writeln('Invalid PE file: ' + target_path);
        Exit;
    end;
    if not test_expected_machine(target_path, machine) then
    begin
        Writeln(Format('Architecture mismatch for file name: %s (machine=0x%.4x)',
            [target_path, machine]));
        Exit;
    end;

    Writeln(Format('regsvr32: %s (machine=0x%.4x)', [regsvr32_path, machine]));
    if not execute_process_hidden(regsvr32_path, ['/u', '/s', target_path], True, exit_code) then
    begin
        Writeln('Failed to launch regsvr32.');
        Exit;
    end;
    if exit_code <> 0 then
    begin
        Writeln('regsvr32 /u /s failed with exit code ' + IntToStr(exit_code));
    end;

    Result := not is_com_registered_for_target(clsid_text_service, target_path, machine);
    if Result then
    begin
        Writeln('COM unregistered: ' + target_path);
    end
    else
    begin
        Writeln('COM registration still present after regsvr32 /u: ' + target_path);
    end;
end;

function run_register_tsf: Boolean;
var
    dll_path: string;
    target_paths: TArray<string>;
    idx: Integer;
    has_error: Boolean;
    clsid_text_service: string;
begin
    dll_path := get_default_dll_path;
    if get_param_value('dll_path', dll_path) and (dll_path <> '') then
    begin
        dll_path := TPath.GetFullPath(dll_path);
    end;
    if not FileExists(dll_path) then
    begin
        Writeln('DLL not found: ' + dll_path);
        Exit(False);
    end;
    if not is_running_as_admin then
    begin
        Writeln('Warning: not running as Administrator. Registration may fail with access denied.');
    end;

    target_paths := resolve_target_paths(dll_path, has_switch('single'));
    Writeln(Format('Register targets (%d):', [Length(target_paths)]));
    for idx := 0 to High(target_paths) do
    begin
        Writeln('  ' + target_paths[idx]);
    end;

    clsid_text_service := GUIDToString(CLSID_NcTextService);
    has_error := False;
    for idx := 0 to High(target_paths) do
    begin
        if not register_one_dll(target_paths[idx], clsid_text_service) then
        begin
            has_error := True;
        end;
    end;
    if has_error then
    begin
        Exit(False);
    end;

    Result := register_profile;
end;

function run_unregister_tsf: Boolean;
var
    dll_path: string;
    target_paths: TArray<string>;
    idx: Integer;
    has_error: Boolean;
    clsid_text_service: string;
begin
    dll_path := get_default_dll_path;
    if get_param_value('dll_path', dll_path) and (dll_path <> '') then
    begin
        dll_path := TPath.GetFullPath(dll_path);
    end;
    if not FileExists(dll_path) then
    begin
        Writeln('DLL not found: ' + dll_path);
        Exit(False);
    end;
    if not is_running_as_admin then
    begin
        Writeln('Warning: not running as Administrator. Unregistration may fail with access denied.');
    end;

    target_paths := resolve_target_paths(dll_path, has_switch('single'));
    Writeln(Format('Unregister targets (%d):', [Length(target_paths)]));
    for idx := 0 to High(target_paths) do
    begin
        Writeln('  ' + target_paths[idx]);
    end;

    has_error := not unregister_profile;
    clsid_text_service := GUIDToString(CLSID_NcTextService);
    for idx := 0 to High(target_paths) do
    begin
        if not unregister_one_dll(target_paths[idx], clsid_text_service) then
        begin
            has_error := True;
        end;
    end;

    Result := not has_error;
end;

function run_start_action: Boolean;
var
    windir: string;
    ctfmon_path: string;
    base_dir: string;
begin
    windir := GetEnvironmentVariable('WINDIR');
    if windir = '' then
    begin
        windir := TPath.GetDirectoryName(GetEnvironmentVariable('COMSPEC'));
        if SameText(ExtractFileName(windir), 'System32') then
        begin
            windir := TPath.GetDirectoryName(windir);
        end;
    end;
    ctfmon_path := TPath.Combine(windir, 'System32\ctfmon.exe');

    if has_switch('restart') then
    begin
        Writeln('Stopping ctfmon...');
        stop_named_processes('ctfmon');
        Sleep(300);
    end;

    Writeln('Starting ctfmon...');
    if not start_one_process_if_missing(ctfmon_path, 'ctfmon') then
    begin
        Exit(False);
    end;

    base_dir := ExtractFilePath(ParamStr(0));
    if not start_one_process_if_missing(TPath.Combine(base_dir, 'cassotis_ime_host.exe'),
        'cassotis_ime_host') then
    begin
        Exit(False);
    end;
    Result := start_one_process_if_missing(TPath.Combine(base_dir, 'cassotis_ime_tray_host.exe'),
        'cassotis_ime_tray_host');
end;

function run_stop_action: Boolean;
var
    dll_path: string;
    force_kill: Boolean;
begin
    Writeln('Stopping ctfmon...');
    Result := stop_named_processes('ctfmon');

    Writeln('Stopping host process: cassotis_ime_host');
    Result := stop_named_processes('cassotis_ime_host') and Result;

    Writeln('Stopping tray process: cassotis_ime_tray_host');
    Result := stop_named_processes('cassotis_ime_tray_host') and Result;

    dll_path := get_default_dll_path;
    if get_param_value('dll_path', dll_path) and (dll_path <> '') then
    begin
        dll_path := TPath.GetFullPath(dll_path);
    end;
    force_kill := has_switch('force_kill');
    if FileExists(dll_path) then
    begin
        Result := stop_processes_using_dlls(dll_path, force_kill) and Result;
    end;
end;

function category_category_key_path(const service_clsid: TGUID; const category_guid: TGUID): string;
begin
    Result := Format('Software\Microsoft\CTF\TIP\%s\Category\Category\%s\%s',
        [GUIDToString(service_clsid), GUIDToString(category_guid), GUIDToString(service_clsid)]);
end;

function category_item_key_path(const service_clsid: TGUID; const category_guid: TGUID): string;
begin
    Result := Format('Software\Microsoft\CTF\TIP\%s\Category\Item\%s\%s',
        [GUIDToString(service_clsid), GUIDToString(service_clsid), GUIDToString(category_guid)]);
end;

function language_profile_key_path(const service_clsid: TGUID; const profile_guid: TGUID;
    const lang_id: Cardinal): string;
begin
    Result := Format('Software\Microsoft\CTF\TIP\%s\LanguageProfile\0x%s\%s',
        [GUIDToString(service_clsid), IntToHex(lang_id, 8), GUIDToString(profile_guid)]);
end;

function registry_key_exists(const root_key: HKEY; const key_path: string): Boolean;
var
    reg: TRegistry;
begin
    reg := TRegistry.Create(KEY_READ);
    try
        reg.RootKey := root_key;
        Result := reg.KeyExists(key_path);
    finally
        reg.Free;
    end;
end;

function category_registered(const service_clsid: TGUID; const category_guid: TGUID): Boolean;
var
    category_path: string;
    item_path: string;
begin
    category_path := category_category_key_path(service_clsid, category_guid);
    item_path := category_item_key_path(service_clsid, category_guid);
    Result :=
        (registry_key_exists(HKEY_CURRENT_USER, category_path) and
        registry_key_exists(HKEY_CURRENT_USER, item_path)) or
        (registry_key_exists(HKEY_LOCAL_MACHINE, category_path) and
        registry_key_exists(HKEY_LOCAL_MACHINE, item_path));
end;

function registry_create_key(const root_key: HKEY; const key_path: string): Boolean;
var
    reg: TRegistry;
begin
    reg := TRegistry.Create(KEY_WRITE);
    try
        reg.RootKey := root_key;
        Result := reg.OpenKey(key_path, True);
        if Result then
        begin
            reg.CloseKey;
        end;
    except
        Result := False;
    end;
    reg.Free;
end;

function ensure_category_registry(const service_clsid: TGUID; const category_guid: TGUID): Boolean;
var
    category_path: string;
    item_path: string;
begin
    if category_registered(service_clsid, category_guid) then
    begin
        Result := True;
        Exit;
    end;

    category_path := category_category_key_path(service_clsid, category_guid);
    item_path := category_item_key_path(service_clsid, category_guid);

    // User-level registry fallback for non-admin registration.
    registry_create_key(HKEY_CURRENT_USER, category_path);
    registry_create_key(HKEY_CURRENT_USER, item_path);
    if category_registered(service_clsid, category_guid) then
    begin
        Result := True;
        Exit;
    end;

    // Try machine-level as a best effort when elevated.
    registry_create_key(HKEY_LOCAL_MACHINE, category_path);
    registry_create_key(HKEY_LOCAL_MACHINE, item_path);
    Result := category_registered(service_clsid, category_guid);
end;

procedure remove_category_registry(const service_clsid: TGUID; const category_guid: TGUID);
var
    reg: TRegistry;
    category_path: string;
    item_path: string;
begin
    category_path := category_category_key_path(service_clsid, category_guid);
    item_path := category_item_key_path(service_clsid, category_guid);

    reg := TRegistry.Create(KEY_WRITE);
    try
        reg.RootKey := HKEY_CURRENT_USER;
        reg.DeleteKey(category_path);
        reg.DeleteKey(item_path);

        reg.RootKey := HKEY_LOCAL_MACHINE;
        reg.DeleteKey(category_path);
        reg.DeleteKey(item_path);
    finally
        reg.Free;
    end;
end;

procedure print_hresult(const action: string; hr: HRESULT);
begin
    if hr = TF_E_ALREADY_EXISTS then
    begin
        Writeln(action + ' already exists: 0x' + IntToHex(hr, 8));
        Exit;
    end;

    if hr_succeeded(hr) then
    begin
        Writeln(action + ' ok: 0x' + IntToHex(hr, 8));
        Exit;
    end;

    Writeln(action + ' failed: 0x' + IntToHex(hr, 8));
end;

procedure upsert_profile_registry(const root_key: HKEY; const key_path: string;
    const desc: WideString; const icon_path: WideString);
var
    reg: TRegistry;
begin
    reg := TRegistry.Create(KEY_WRITE);
    try
        reg.RootKey := root_key;
        if reg.OpenKey(key_path, True) then
        begin
            reg.WriteString('Description', string(desc));
            reg.WriteInteger('Enable', 1);
            if icon_path <> '' then
            begin
                reg.WriteString('IconFile', string(icon_path));
                reg.WriteInteger('IconIndex', 0);
            end;
            reg.CloseKey;
        end;
    except
        // Best-effort only. Machine hive may fail when not elevated.
    end;
    reg.Free;
end;

function register_categories(const service_clsid: TGUID): Boolean;
var
    category_mgr: ITfCategoryMgr;
    hr: HRESULT;
    service_guid: TGUID;
    category_guid: TGUID;

    function register_one(const category: TGUID; const name: string): Boolean;
    begin
        category_guid := category;
        hr := category_mgr.RegisterCategory(service_guid, category_guid, service_guid);
        print_hresult('RegisterCategory ' + name, hr);
        if hr_ok_or_exists(hr) then
        begin
            Result := True;
            Exit;
        end;

        if category_registered(service_guid, category_guid) then
        begin
            Writeln('RegisterCategory ' + name + ' exists in registry.');
            Result := True;
            Exit;
        end;

        if ensure_category_registry(service_guid, category_guid) then
        begin
            Writeln('RegisterCategory ' + name + ' written via registry fallback.');
            Result := True;
            Exit;
        end;

        Result := category_registered(service_guid, category_guid);
    end;
begin
    Result := False;
    category_mgr := nil;
    hr := TF_CreateCategoryMgr(PPTfCategoryMgr(@category_mgr));
    print_hresult('CreateCategoryMgr', hr);
    if (not hr_succeeded(hr)) or (category_mgr = nil) then
    begin
        Exit;
    end;

    service_guid := service_clsid;
    if not register_one(GUID_TFCAT_TIP_KEYBOARD, 'TIP_KEYBOARD') then
    begin
        Exit;
    end;

    if not register_one(GUID_TFCAT_TIPCAP_UIELEMENTENABLED, 'UIELEMENTENABLED') then
    begin
        Exit;
    end;

    if not register_one(GUID_TFCAT_TIPCAP_INPUTMODECOMPARTMENT, 'INPUTMODECOMPARTMENT') then
    begin
        Exit;
    end;

    if not register_one(GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT, 'IMMERSIVESUPPORT') then
    begin
        Exit;
    end;

    if not register_one(GUID_TFCAT_TIPCAP_SYSTRAYSUPPORT, 'SYSTRAYSUPPORT') then
    begin
        Exit;
    end;

    if not register_one(GUID_TFCAT_DISPLAYATTRIBUTEPROVIDER, 'DISPLAYATTRIBUTEPROVIDER') then
    begin
        Exit;
    end;

    Result := True;
end;

procedure unregister_categories(const service_clsid: TGUID);
var
    category_mgr: ITfCategoryMgr;
    hr: HRESULT;
    service_guid: TGUID;
    category_guid: TGUID;
begin
    category_mgr := nil;
    hr := TF_CreateCategoryMgr(PPTfCategoryMgr(@category_mgr));
    print_hresult('CreateCategoryMgr', hr);
    if (not hr_succeeded(hr)) or (category_mgr = nil) then
    begin
        Exit;
    end;

    service_guid := service_clsid;
    category_guid := GUID_TFCAT_DISPLAYATTRIBUTEPROVIDER;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory DISPLAYATTRIBUTEPROVIDER', hr);
    remove_category_registry(service_guid, category_guid);
    category_guid := GUID_TFCAT_TIPCAP_SYSTRAYSUPPORT;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory SYSTRAYSUPPORT', hr);
    remove_category_registry(service_guid, category_guid);
    category_guid := GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory IMMERSIVESUPPORT', hr);
    remove_category_registry(service_guid, category_guid);
    category_guid := GUID_TFCAT_TIPCAP_UIELEMENTENABLED;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory UIELEMENTENABLED', hr);
    remove_category_registry(service_guid, category_guid);
    category_guid := GUID_TFCAT_TIPCAP_INPUTMODECOMPARTMENT;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory INPUTMODECOMPARTMENT', hr);
    remove_category_registry(service_guid, category_guid);
    category_guid := GUID_TFCAT_TIP_KEYBOARD;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory TIP_KEYBOARD', hr);
    remove_category_registry(service_guid, category_guid);
end;

function register_profile: Boolean;
var
    profiles: ITfInputProcessorProfiles;
    hr: HRESULT;
    desc: WideString;
    icon_path: WideString;
    icon_ptr: PWideChar;
    icon_len: Cardinal;
    service_clsid: TGUID;
    profile_guid: TGUID;
    profile_key: string;
    module_path: array[0..MAX_PATH - 1] of Char;
    module_len: Cardinal;
    base_dir: string;
    candidate: string;

    function resolve_profile_icon_path: WideString;
    begin
        Result := '';

        module_len := GetModuleFileName(0, module_path, MAX_PATH);
        if module_len = 0 then
        begin
            Exit;
        end;

        base_dir := IncludeTrailingPathDelimiter(ExtractFilePath(module_path));

        // Prefer tray host icon first so profile branding is consistent with
        // the user-facing app icon in taskbar/tray.
        candidate := base_dir + 'cassotis_ime_tray_host.exe';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;

        // Fallbacks in the same deployment folder.
        candidate := base_dir + 'cassotis_ime_host.exe';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;

        candidate := base_dir + 'cassotis_ime_svr.dll';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;
    end;
begin
    Result := False;
    profiles := nil;
    hr := TF_CreateInputProcessorProfiles(PPTfInputProcessorProfiles(@profiles));
    print_hresult('CreateInputProcessorProfiles', hr);
    if (not hr_succeeded(hr)) or (profiles = nil) then
    begin
        Exit;
    end;

    service_clsid := CLSID_NcTextService;
    profile_guid := GUID_NcTextServiceProfile;
    hr := profiles.Register(service_clsid);
    print_hresult('Register text service', hr);
    if not hr_ok_or_exists(hr) then
    begin
        Writeln('Register text service failed, continue with profile/category update.');
    end;

    // Display name encoded via code points to avoid source-encoding issues.
    desc := WideString('Cassotis ' + #$8A00#$6CC9#$62FC#$97F3#$8F93#$5165#$6CD5);
    icon_path := resolve_profile_icon_path;
    if icon_path <> '' then
    begin
        icon_ptr := PWideChar(icon_path);
        icon_len := Length(icon_path);
        Writeln('Profile icon: ' + string(icon_path));
    end
    else
    begin
        icon_ptr := nil;
        icon_len := 0;
        Writeln('Profile icon: <none> (system default)');
    end;

    hr := profiles.AddLanguageProfile(service_clsid, NC_LANG_ID_ZH_CN,
        profile_guid, PWideChar(desc), Length(desc), icon_ptr, icon_len, 0);
    print_hresult('Add language profile', hr);
    if not hr_ok_or_exists(hr) then
    begin
        Writeln('Add language profile failed, continue with category update.');
    end;

    hr := profiles.EnableLanguageProfile(service_clsid, NC_LANG_ID_ZH_CN,
        profile_guid, 1);
    print_hresult('Enable language profile', hr);
    if not hr_succeeded(hr) then
    begin
        Writeln('Enable language profile failed, continue with category update.');
    end;

    // Best-effort registry hints so non-admin installs can still surface
    // profile name/icon in the current user context.
    profile_key := language_profile_key_path(service_clsid, profile_guid, NC_LANG_ID_ZH_CN);
    upsert_profile_registry(HKEY_CURRENT_USER, profile_key, desc, icon_path);
    upsert_profile_registry(HKEY_LOCAL_MACHINE, profile_key, desc, icon_path);

    if not register_categories(service_clsid) then
    begin
        Exit;
    end;

    Result := True;
end;

function unregister_profile: Boolean;
var
    profiles: ITfInputProcessorProfiles;
    hr: HRESULT;
    service_clsid: TGUID;
    profile_guid: TGUID;
begin
    Result := False;
    profiles := nil;
    hr := TF_CreateInputProcessorProfiles(PPTfInputProcessorProfiles(@profiles));
    print_hresult('CreateInputProcessorProfiles', hr);
    if (not hr_succeeded(hr)) or (profiles = nil) then
    begin
        Exit;
    end;

    service_clsid := CLSID_NcTextService;
    profile_guid := GUID_NcTextServiceProfile;
    hr := profiles.RemoveLanguageProfile(service_clsid, NC_LANG_ID_ZH_CN, profile_guid);
    print_hresult('Remove language profile', hr);
    if Failed(hr) then
    begin
        Exit;
    end;

    hr := profiles.Unregister(service_clsid);
    print_hresult('Unregister text service', hr);
    unregister_categories(service_clsid);
    Result := not Failed(hr);
end;

function run_action: Boolean;
var
    action: string;
begin
    Result := False;
    if ParamCount < 1 then
    begin
        print_usage;
        Exit;
    end;

    action := LowerCase(ParamStr(1));
    if action = 'register' then
    begin
        Result := register_profile;
        Exit;
    end;

    if action = 'unregister' then
    begin
        Result := unregister_profile;
        Exit;
    end;

    if action = 'register_tsf' then
    begin
        Result := run_register_tsf;
        Exit;
    end;

    if action = 'unregister_tsf' then
    begin
        Result := run_unregister_tsf;
        Exit;
    end;

    if action = 'start' then
    begin
        Result := run_start_action;
        Exit;
    end;

    if action = 'stop' then
    begin
        Result := run_stop_action;
        Exit;
    end;

    print_usage;
end;

var
    hr: HRESULT;
    ok: Boolean;
begin
    hr := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
    if Failed(hr) then
    begin
        Writeln('CoInitializeEx failed: ' + IntToHex(hr, 8));
        Halt(1);
    end;

    try
        ok := run_action;
    finally
        CoUninitialize;
    end;

    if not ok then
    begin
        Halt(1);
    end;
end.
