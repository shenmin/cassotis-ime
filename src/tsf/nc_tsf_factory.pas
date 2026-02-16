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
    ComServer.PerUserRegistration := True;
    register_com_factory;

end.
