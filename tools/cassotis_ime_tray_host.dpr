program cassotis_ime_tray_host;

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Forms,
  nc_tray_host in '..\src\ui\nc_tray_host.pas',
  nc_config in '..\src\common\nc_config.pas',
  nc_log in '..\src\common\nc_log.pas',
  nc_sqlite in '..\src\common\nc_sqlite.pas',
  nc_types in '..\src\common\nc_types.pas',
  nc_ipc_common in '..\src\common\nc_ipc_common.pas';

{$R 'cassotis_ime_tray_host.res'}
{$R 'cassotis_ime_tray_host_mark.res'}

var
    tray_host: TncTrayHost;
    tray_mutex: THandle;
    open_settings_requested: Boolean;

procedure try_enable_per_monitor_dpi;
type
    Tset_process_dpi_awareness_context = function(const value: THandle): BOOL; stdcall;
    Tset_process_dpi_awareness = function(const value: Integer): HRESULT; stdcall;
const
    c_dpi_awareness_per_monitor = 2;
    c_dpi_awareness_context_per_monitor_v2 = THandle(-4);
var
    user32: HMODULE;
    shcore: HMODULE;
    set_context: Tset_process_dpi_awareness_context;
    set_awareness: Tset_process_dpi_awareness;
begin
    user32 := GetModuleHandle('user32.dll');
    if user32 <> 0 then
    begin
        set_context := Tset_process_dpi_awareness_context(GetProcAddress(user32, 'SetProcessDpiAwarenessContext'));
        if Assigned(set_context) then
        begin
            set_context(c_dpi_awareness_context_per_monitor_v2);
            Exit;
        end;
    end;

    shcore := LoadLibrary('shcore.dll');
    if shcore = 0 then
    begin
        Exit;
    end;

    try
        set_awareness := Tset_process_dpi_awareness(GetProcAddress(shcore, 'SetProcessDpiAwareness'));
        if Assigned(set_awareness) then
        begin
            set_awareness(c_dpi_awareness_per_monitor);
        end;
    finally
        FreeLibrary(shcore);
    end;
end;

procedure enforce_application_toolwindow_style;
var
    ex_style: NativeInt;
begin
    if Application = nil then
    begin
        Exit;
    end;
    ex_style := GetWindowLongPtr(Application.Handle, GWL_EXSTYLE);
    ex_style := (ex_style or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
    SetWindowLongPtr(Application.Handle, GWL_EXSTYLE, ex_style);
    SetWindowPos(
        Application.Handle,
        HWND_TOP,
        0,
        0,
        0,
        0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_FRAMECHANGED
    );
end;

function acquire_tray_mutex: Boolean;
var
    session_id: DWORD;
    mutex_name: string;
    last_error: DWORD;
begin
    Result := False;
    session_id := 0;
    if not ProcessIdToSessionId(GetCurrentProcessId, session_id) then
    begin
        session_id := 0;
    end;

    mutex_name := Format('Local\cassotis_ime_tray_host_v1_s%d', [session_id]);
    tray_mutex := CreateMutex(nil, True, PChar(mutex_name));
    if tray_mutex = 0 then
    begin
        Exit;
    end;

    last_error := GetLastError;
    if (last_error = ERROR_ALREADY_EXISTS) or (last_error = ERROR_ACCESS_DENIED) then
    begin
        CloseHandle(tray_mutex);
        tray_mutex := 0;
        Exit;
    end;
    Result := True;
end;

procedure notify_existing_tray_to_open_settings;
var
    tray_window: HWND;
    open_settings_message: Cardinal;
begin
    open_settings_message := get_nc_open_settings_message;
    tray_window := FindWindow('TncTrayHost', nil);
    if tray_window <> 0 then
    begin
        PostMessage(tray_window, open_settings_message, 0, 0);
    end
    else
    begin
        PostMessage(HWND_BROADCAST, open_settings_message, 0, 0);
    end;
end;

begin
    tray_mutex := 0;
    open_settings_requested := FindCmdLineSwitch('settings', ['-', '/'], True);
    if not acquire_tray_mutex then
    begin
        if open_settings_requested then
        begin
            notify_existing_tray_to_open_settings;
        end;
        Exit;
    end;

    try_enable_per_monitor_dpi;
    Application.Initialize;
    Application.MainFormOnTaskbar := False;
    Application.ShowMainForm := False;
    enforce_application_toolwindow_style;
    Application.CreateForm(TncTrayHost, tray_host);
    if open_settings_requested then
    begin
        PostMessage(tray_host.Handle, WM_NC_OPEN_SETTINGS, 0, 0);
    end;
    try
        Application.Run;
    finally
        if tray_mutex <> 0 then
        begin
            ReleaseMutex(tray_mutex);
            CloseHandle(tray_mutex);
            tray_mutex := 0;
        end;
    end;
end.
