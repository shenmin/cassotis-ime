unit nc_tsf_display_attr;

interface

uses
    Winapi.Windows,
    Winapi.ActiveX,
    Winapi.Msctf;

type
    TncDisplayAttributeInfo = class(TInterfacedObject, ITfDisplayAttributeInfo)
    private
        m_guid: TGUID;
        m_attr: TF_DISPLAYATTRIBUTE;
        m_description: WideString;
        procedure init_default_attr;
    public
        constructor create(const guid: TGUID; const description: WideString = 'Cassotis IME Preedit');
        function GetGUID(out pguid: TGUID): HResult; stdcall;
        function GetDescription(out pbstrDesc: WideString): HResult; stdcall;
        function GetAttributeInfo(out pda: TF_DISPLAYATTRIBUTE): HResult; stdcall;
        function SetAttributeInfo(var pda: TF_DISPLAYATTRIBUTE): HResult; stdcall;
        function Reset: HResult; stdcall;
    end;

    TncEnumDisplayAttributeInfo = class(TInterfacedObject, IEnumTfDisplayAttributeInfo)
    private
        m_items: TArray<ITfDisplayAttributeInfo>;
        m_index: Integer;
    public
        constructor create(const items: TArray<ITfDisplayAttributeInfo>);
        function Clone(out ppenum: IEnumTfDisplayAttributeInfo): HResult; stdcall;
        function Next(ulCount: LongWord; out rgInfo: ITfDisplayAttributeInfo; out pcFetched: LongWord): HResult; stdcall;
        function Reset: HResult; stdcall;
        function Skip(ulCount: LongWord): HResult; stdcall;
    end;

    TncDisplayAttributeProvider = class(TInterfacedObject, ITfDisplayAttributeProvider)
    private
        m_info: ITfDisplayAttributeInfo;
    public
        constructor create(const info: ITfDisplayAttributeInfo);
        function EnumDisplayAttributeInfo(out ppenum: IEnumTfDisplayAttributeInfo): HResult; stdcall;
        function GetDisplayAttributeInfo(var GUID: TGUID; out ppInfo: ITfDisplayAttributeInfo): HResult; stdcall;
    end;

implementation

constructor TncDisplayAttributeInfo.create(const guid: TGUID; const description: WideString);
begin
    inherited create;
    m_guid := guid;
    m_description := description;
    init_default_attr;
end;

procedure TncDisplayAttributeInfo.init_default_attr;
begin
    FillChar(m_attr, SizeOf(m_attr), 0);
    m_attr.crText.type_ := TF_CT_NONE;
    m_attr.crBk.type_ := TF_CT_NONE;
    m_attr.crLine.type_ := TF_CT_SYSCOLOR;
    m_attr.crLine.nIndex := COLOR_WINDOWTEXT;
    m_attr.lsStyle := TF_LS_DOT;
    m_attr.fBoldLine := 0;
    m_attr.bAttr := TF_ATTR_TARGET_NOTCONVERTED;
end;

function TncDisplayAttributeInfo.GetGUID(out pguid: TGUID): HResult;
begin
    pguid := m_guid;
    Result := S_OK;
end;

function TncDisplayAttributeInfo.GetDescription(out pbstrDesc: WideString): HResult;
begin
    pbstrDesc := m_description;
    Result := S_OK;
end;

function TncDisplayAttributeInfo.GetAttributeInfo(out pda: TF_DISPLAYATTRIBUTE): HResult;
begin
    pda := m_attr;
    Result := S_OK;
end;

function TncDisplayAttributeInfo.SetAttributeInfo(var pda: TF_DISPLAYATTRIBUTE): HResult;
begin
    m_attr := pda;
    Result := S_OK;
end;

function TncDisplayAttributeInfo.Reset: HResult;
begin
    init_default_attr;
    Result := S_OK;
end;

constructor TncEnumDisplayAttributeInfo.create(const items: TArray<ITfDisplayAttributeInfo>);
begin
    inherited create;
    m_items := items;
    m_index := 0;
end;

function TncEnumDisplayAttributeInfo.Clone(out ppenum: IEnumTfDisplayAttributeInfo): HResult;
var
    clone: TncEnumDisplayAttributeInfo;
begin
    clone := TncEnumDisplayAttributeInfo.create(m_items);
    clone.m_index := m_index;
    ppenum := clone;
    Result := S_OK;
end;

function TncEnumDisplayAttributeInfo.Next(ulCount: LongWord; out rgInfo: ITfDisplayAttributeInfo;
    out pcFetched: LongWord): HResult;
begin
    pcFetched := 0;
    rgInfo := nil;
    if ulCount <> 1 then
    begin
        Result := E_INVALIDARG;
        Exit;
    end;

    if m_index >= Length(m_items) then
    begin
        Result := S_FALSE;
        Exit;
    end;

    rgInfo := m_items[m_index];
    Inc(m_index);
    pcFetched := 1;
    Result := S_OK;
end;

function TncEnumDisplayAttributeInfo.Reset: HResult;
begin
    m_index := 0;
    Result := S_OK;
end;

function TncEnumDisplayAttributeInfo.Skip(ulCount: LongWord): HResult;
begin
    if ulCount = 0 then
    begin
        Result := S_OK;
        Exit;
    end;

    if m_index + Integer(ulCount) > Length(m_items) then
    begin
        m_index := Length(m_items);
        Result := S_FALSE;
        Exit;
    end;

    Inc(m_index, Integer(ulCount));
    Result := S_OK;
end;

constructor TncDisplayAttributeProvider.create(const info: ITfDisplayAttributeInfo);
begin
    inherited create;
    m_info := info;
end;

function TncDisplayAttributeProvider.EnumDisplayAttributeInfo(out ppenum: IEnumTfDisplayAttributeInfo): HResult;
var
    items: TArray<ITfDisplayAttributeInfo>;
begin
    SetLength(items, 1);
    items[0] := m_info;
    ppenum := TncEnumDisplayAttributeInfo.create(items);
    Result := S_OK;
end;

function TncDisplayAttributeProvider.GetDisplayAttributeInfo(var GUID: TGUID;
    out ppInfo: ITfDisplayAttributeInfo): HResult;
var
    info_guid: TGUID;
begin
    ppInfo := nil;
    if m_info = nil then
    begin
        Result := E_FAIL;
        Exit;
    end;

    info_guid := GUID_NULL;
    if m_info.GetGUID(info_guid) <> S_OK then
    begin
        Result := E_FAIL;
        Exit;
    end;

    if IsEqualGUID(GUID, info_guid) then
    begin
        ppInfo := m_info;
        Result := S_OK;
    end
    else
    begin
        Result := E_INVALIDARG;
    end;
end;

end.
