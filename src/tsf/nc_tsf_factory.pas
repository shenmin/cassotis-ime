unit nc_tsf_factory;

interface

procedure register_com_factory;

implementation

uses
    ComObj,
    ComServ,
    nc_tsf_guids,
    nc_tsf_service;

procedure register_com_factory;
begin
    TComObjectFactory.Create(ComServer, TncTextService, CLSID_NcTextService,
        'CassotisImeTextService', 'CassotisImeTextService', ciMultiInstance, tmApartment);
end;

initialization
    // Use machine-wide COM registration so elevated apps (e.g. admin Terminal)
    // can load the TSF service reliably.
    ComServer.PerUserRegistration := False;
    register_com_factory;

end.
