library cassotis_ime_svr;

{$R 'cassotis_ime_svr.res'}

uses
    System.SysUtils,
    System.Classes,
    ComServ,
    nc_tsf_factory in 'nc_tsf_factory.pas';

exports
    DllGetClassObject,
    DllCanUnloadNow,
    DllRegisterServer,
    DllUnregisterServer;

begin
end.
