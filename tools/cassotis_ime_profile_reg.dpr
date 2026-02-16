program cassotis_ime_profile_reg;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    Winapi.Windows,
    Winapi.ActiveX,
    Winapi.Msctf,
    ComObj,
    nc_tsf_guids in '..\src\tsf\nc_tsf_guids.pas';

const
    TF_E_ALREADY_EXISTS = HRESULT($80005006);

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_profile_reg register|unregister');
end;

function hr_succeeded(const hr: HRESULT): Boolean;
begin
    Result := hr >= 0;
end;

function hr_ok_or_exists(const hr: HRESULT): Boolean;
begin
    Result := hr_succeeded(hr) or (hr = TF_E_ALREADY_EXISTS);
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

function register_categories(const service_clsid: TGUID): Boolean;
var
    category_mgr: ITfCategoryMgr;
    hr: HRESULT;
    service_guid: TGUID;
    category_guid: TGUID;
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
    category_guid := GUID_TFCAT_TIP_KEYBOARD;
    hr := category_mgr.RegisterCategory(service_guid, category_guid, service_guid);
    print_hresult('RegisterCategory TIP_KEYBOARD', hr);
    if not hr_ok_or_exists(hr) then
    begin
        Exit;
    end;

    category_guid := GUID_TFCAT_TIPCAP_UIELEMENTENABLED;
    hr := category_mgr.RegisterCategory(service_guid, category_guid, service_guid);
    print_hresult('RegisterCategory UIELEMENTENABLED', hr);
    if not hr_ok_or_exists(hr) then
    begin
        Exit;
    end;

    category_guid := GUID_TFCAT_DISPLAYATTRIBUTEPROVIDER;
    hr := category_mgr.RegisterCategory(service_guid, category_guid, service_guid);
    print_hresult('RegisterCategory DISPLAYATTRIBUTEPROVIDER', hr);
    if not hr_ok_or_exists(hr) then
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
    category_guid := GUID_TFCAT_TIPCAP_UIELEMENTENABLED;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory UIELEMENTENABLED', hr);
    category_guid := GUID_TFCAT_TIP_KEYBOARD;
    hr := category_mgr.UnregisterCategory(service_guid, category_guid, service_guid);
    print_hresult('UnregisterCategory TIP_KEYBOARD', hr);
end;

function register_profile: Boolean;
var
    profiles: ITfInputProcessorProfiles;
    hr: HRESULT;
    desc: WideString;
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
    hr := profiles.Register(service_clsid);
    print_hresult('Register text service', hr);
    if not hr_ok_or_exists(hr) then
    begin
        Exit;
    end;

    desc := 'Cassotis IME';
    hr := profiles.AddLanguageProfile(service_clsid, NC_LANG_ID_ZH_CN,
        profile_guid, PWideChar(desc), Length(desc), nil, 0, 0);
    print_hresult('Add language profile', hr);
    if not hr_ok_or_exists(hr) then
    begin
        Exit;
    end;

    hr := profiles.EnableLanguageProfile(service_clsid, NC_LANG_ID_ZH_CN,
        profile_guid, 1);
    print_hresult('Enable language profile', hr);
    if not hr_succeeded(hr) then
    begin
        Exit;
    end;

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
