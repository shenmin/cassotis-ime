program cassotis_ime_tray_host;

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Forms,
  nc_tray_host in '..\src\ui\nc_tray_host.pas',
  nc_config in '..\src\common\nc_config.pas',
  nc_log in '..\src\common\nc_log.pas',
  nc_sqlite in '..\src\common\nc_sqlite.pas',
  nc_types in '..\src\common\nc_types.pas';

{$R 'cassotis_ime_tray_host.res'}

var
    tray_host: TncTrayHost;
    tray_mutex: THandle;

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

begin
    tray_mutex := 0;
    if not acquire_tray_mutex then
    begin
        Exit;
    end;

    Application.Initialize;
    Application.MainFormOnTaskbar := False;
    Application.ShowMainForm := False;
    enforce_application_toolwindow_style;
    Application.CreateForm(TncTrayHost, tray_host);
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
