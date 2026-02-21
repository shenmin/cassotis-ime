program cassotis_ime_profile_reg;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    System.Win.Registry,
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
        Writeln('Register text service failed, continue with profile/category update.');
    end;

    desc := 'Cassotis IME';
    hr := profiles.AddLanguageProfile(service_clsid, NC_LANG_ID_ZH_CN,
        profile_guid, PWideChar(desc), Length(desc), nil, 0, 0);
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
