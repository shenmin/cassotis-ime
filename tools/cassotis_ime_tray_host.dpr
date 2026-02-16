program cassotis_ime_tray_host;

uses
  Vcl.Forms,
  nc_tray_host in '..\src\ui\nc_tray_host.pas',
  nc_config in '..\src\common\nc_config.pas',
  nc_log in '..\src\common\nc_log.pas',
  nc_sqlite in '..\src\common\nc_sqlite.pas',
  nc_types in '..\src\common\nc_types.pas';

{$R 'cassotis_ime_tray_host.res'}

var
    tray_host: TncTrayHost;

begin
    Application.Initialize;
    Application.MainFormOnTaskbar := False;
    Application.ShowMainForm := False;
    tray_host := TncTrayHost.create;
    Application.Run;
    tray_host.Free;
end.
