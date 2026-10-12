unit nc_tray_icon_appearance;

interface

uses
    Winapi.Windows, Vcl.Graphics, Vcl.ExtCtrls;

type
    TncTrayIconAppearance = record
        backplate: Boolean;
        icon_size: Integer;
    end;

    // Sends one Shell_NotifyIcon message for an icon and says whether the shell took it.
    TncTrayNotify = reference to function(const message: DWORD): Boolean;

    TncTrayIconTheme = class
    private
        m_original: TIcon;
        m_icon: TIcon;
        m_instance: HINST;
        m_resource_name: string;
        m_appearance: TncTrayIconAppearance;
        m_ready: Boolean;
    public
        constructor Create(const original: TIcon; const instance: HINST; const resource_name: string);
        destructor Destroy; override;
        function refresh(const appearance: TncTrayIconAppearance): Boolean;
        property icon: TIcon read m_icon;
    end;

function nc_tray_icon_needs_backplate(const system_uses_light_theme: Integer;
    const high_contrast: Boolean; const system_background: COLORREF): Boolean;
function nc_read_tray_icon_appearance: TncTrayIconAppearance;
procedure nc_set_tray_icon(const tray: TTrayIcon; const icon: TIcon);
function nc_publish_notification_icon(const notify: TncTrayNotify): Boolean;
function nc_republish_tray_icon(const tray: TTrayIcon): Boolean;
function nc_create_profile_icon(const instance: HINST; const resource_name: string;
    const size: Integer): TIcon;

implementation

uses
    System.SysUtils, System.Classes, System.Math, Winapi.ActiveX, Winapi.ShellAPI,
    Winapi.GDIPAPI, Winapi.GDIPOBJ;

type
    TncGetDpiForWindow = function(window: HWND): UINT; stdcall;
    TncGetSystemMetricsForDpi = function(index: Integer; dpi: UINT): Integer; stdcall;

    TncTrayIconAccess = class(TTrayIcon);

procedure nc_set_tray_icon(const tray: TTrayIcon; const icon: TIcon);
begin
    if (tray = nil) or (icon = nil) then Exit;
    // The setter updates VCL's FCurrentIcon and NOTIFYICONDATA; Icon.Assign does not.
    tray.Icon := icon;
end;

// An icon that should be shown is modified in place, and added when the shell
// does not have it: Explorer was restarted, or was not up when the icon was
// first added. It is never removed on the way.
function nc_publish_notification_icon(const notify: TncTrayNotify): Boolean;
begin
    Result := Assigned(notify) and (notify(NIM_MODIFY) or notify(NIM_ADD));
end;

// VCL's own way to show an icon again is Visible := False and then True. When
// the shell no longer has the icon the removal fails, VCL raises "Cannot
// remove shell notification icon" and leaves the icon hidden, so that it does
// not come back with the next taskbar either.
function nc_republish_tray_icon(const tray: TTrayIcon): Boolean;
begin
    Result := False;
    if tray = nil then Exit;
    // A hidden icon is added by VCL, which does not say whether that worked.
    if not tray.Visible then tray.Visible := True;
    Result := nc_publish_notification_icon(
        function(const message: DWORD): Boolean
        begin
            Result := TncTrayIconAccess(tray).Refresh(message);
        end);
end;

function nc_tray_icon_needs_backplate(const system_uses_light_theme: Integer;
    const high_contrast: Boolean; const system_background: COLORREF): Boolean;
begin
    if (not high_contrast) and (system_uses_light_theme in [0, 1]) then
        Exit(system_uses_light_theme = 0);
    // Contrast themes override the ordinary light/dark preference.
    Result := (299 * GetRValue(system_background) + 587 * GetGValue(system_background) +
        114 * GetBValue(system_background)) < 128000;
end;

function nc_read_tray_icon_appearance: TncTrayIconAppearance;
const
    c_personalize_key = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';
var
    key: HKEY;
    value, value_type, value_size: DWORD;
    light_theme: Integer;
    contrast: THighContrast;
    high_contrast: Boolean;
    user32: HMODULE;
    taskbar: HWND;
    dpi: UINT;
    get_dpi: TncGetDpiForWindow;
    get_metrics: TncGetSystemMetricsForDpi;
begin
    light_theme := -1;
    if RegOpenKeyEx(HKEY_CURRENT_USER, c_personalize_key, 0, KEY_QUERY_VALUE, key) = ERROR_SUCCESS then
    begin
        try
            value_size := SizeOf(value);
            if (RegQueryValueEx(key, 'SystemUsesLightTheme', nil, @value_type,
                @value, @value_size) = ERROR_SUCCESS) and (value_type = REG_DWORD) and
                (value_size = SizeOf(value)) and (value <= 1) then
                light_theme := Integer(value);
        finally RegCloseKey(key); end;
    end;
    FillChar(contrast, SizeOf(contrast), 0);
    contrast.cbSize := SizeOf(contrast);
    high_contrast := SystemParametersInfo(SPI_GETHIGHCONTRAST, SizeOf(contrast), @contrast, 0) and
        ((contrast.dwFlags and HCF_HIGHCONTRASTON) <> 0);
    Result.backplate := nc_tray_icon_needs_backplate(light_theme, high_contrast,
        GetSysColor(COLOR_BTNFACE));

    Result.icon_size := GetSystemMetrics(SM_CXSMICON);
    user32 := GetModuleHandle('user32.dll');
    get_dpi := TncGetDpiForWindow(GetProcAddress(user32, 'GetDpiForWindow'));
    get_metrics := TncGetSystemMetricsForDpi(GetProcAddress(user32, 'GetSystemMetricsForDpi'));
    taskbar := FindWindow('Shell_TrayWnd', nil);
    if Assigned(get_dpi) and (taskbar <> 0) then
    begin
        dpi := get_dpi(taskbar);
        if dpi > 0 then
        begin
            if Assigned(get_metrics) then
                Result.icon_size := get_metrics(SM_CXSMICON, dpi)
            else
                Result.icon_size := MulDiv(16, dpi, 96);
        end;
    end;
    Result.icon_size := EnsureRange(Result.icon_size, 16, 128);
end;

function create_backplate_icon(const instance: HINST; const resource_name: string;
    const size: Integer; const taskbar_scale, profile_style: Boolean): TIcon;
var
    stream: TResourceStream;
    adapter: IStream;
    source, target, scaled: TGPBitmap;
    graphics: TGPGraphics;
    path: TGPGraphicsPath;
    brush: TGPSolidBrush;
    handle: HICON;
    render_size: Integer;
    edge, diameter, scale, width, height: Single;
begin
    Result := nil;
    stream := nil;
    adapter := nil;
    source := nil;
    target := nil;
    scaled := nil;
    graphics := nil;
    path := nil;
    brush := nil;
    handle := 0;
    render_size := size;
    if taskbar_scale then render_size := size * 2;
    try
        try
            stream := TResourceStream.Create(instance, resource_name, RT_RCDATA);
            adapter := TStreamAdapter.Create(stream, soReference) as IStream;
            source := TGPBitmap.Create(adapter);
            if (source.GetLastStatus <> Ok) or (source.GetWidth = 0) or (source.GetHeight = 0) then Exit;
            target := TGPBitmap.Create(render_size, render_size, PixelFormat32bppPARGB);
            graphics := TGPGraphics.Create(target);
            graphics.Clear(MakeColor(0, 0, 0, 0));
            graphics.SetSmoothingMode(SmoothingModeAntiAlias);
            graphics.SetCompositingQuality(CompositingQualityHighQuality);
            graphics.SetInterpolationMode(InterpolationModeHighQualityBicubic);
            graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
            // Fill the available canvas; only the rounded corners remain transparent.
            edge := 0;
            diameter := Max(7.0, render_size * 0.28);
            if profile_style then diameter := Max(4.0, render_size * 0.18);
            path := TGPGraphicsPath.Create;
            path.AddArc(edge, edge, diameter, diameter, 180, 90);
            path.AddArc(render_size - edge - diameter, edge, diameter, diameter, 270, 90);
            path.AddArc(render_size - edge - diameter, render_size - edge - diameter, diameter, diameter, 0, 90);
            path.AddArc(edge, render_size - edge - diameter, diameter, diameter, 90, 90);
            path.CloseFigure;
            // Share the profile's soft blue; the light-theme tray bypasses this renderer.
            brush := TGPSolidBrush.Create(MakeColor(255, 204, 229, 235));
            if graphics.FillPath(brush, path) <> Ok then Exit;
            // The source already has transparent margins. An extra inset shrinks the mark.
            scale := Min(render_size / source.GetWidth, render_size / source.GetHeight);
            width := source.GetWidth * scale;
            height := source.GetHeight * scale;
            if graphics.DrawImage(source, MakeRect((render_size - width) / 2, (render_size - height) / 2,
                width, height)) <> Ok then Exit;
            FreeAndNil(graphics);
            if taskbar_scale then
            begin
                // Match the language indicator's large-profile-icon downsampling.
                scaled := TGPBitmap.Create(size, size, PixelFormat32bppPARGB);
                graphics := TGPGraphics.Create(scaled);
                graphics.Clear(MakeColor(0, 0, 0, 0));
                graphics.SetInterpolationMode(InterpolationModeBilinear);
                graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
                if graphics.DrawImage(target, MakeRect(0, 0, size, size)) <> Ok then Exit;
                FreeAndNil(graphics);
                target.Free;
                target := scaled;
                scaled := nil;
            end;
            if (target.GetHICON(handle) <> Ok) or (handle = 0) then Exit;
            Result := TIcon.Create;
            Result.Handle := handle;
            handle := 0;
        except
            FreeAndNil(Result);
        end;
    finally
        if handle <> 0 then DestroyIcon(handle);
        brush.Free;
        path.Free;
        graphics.Free;
        target.Free;
        scaled.Free;
        source.Free;
        adapter := nil;
        stream.Free;
    end;
end;

function nc_create_profile_icon(const instance: HINST; const resource_name: string;
    const size: Integer): TIcon;
begin
    Result := create_backplate_icon(instance, resource_name, EnsureRange(size, 16, 128), False, True);
end;

constructor TncTrayIconTheme.Create(const original: TIcon; const instance: HINST;
    const resource_name: string);
begin
    inherited Create;
    m_instance := instance;
    m_resource_name := resource_name;
    m_original := TIcon.Create;
    m_icon := TIcon.Create;
    if original <> nil then m_original.Assign(original);
    m_icon.Assign(m_original);
end;

destructor TncTrayIconTheme.Destroy;
begin
    m_icon.Free;
    m_original.Free;
    inherited;
end;

function TncTrayIconTheme.refresh(const appearance: TncTrayIconAppearance): Boolean;
var
    next: TncTrayIconAppearance;
    rendered: TIcon;
begin
    next := appearance;
    next.icon_size := EnsureRange(next.icon_size, 16, 128);
    Result := (not m_ready) or (m_appearance.backplate <> next.backplate) or
        (m_appearance.icon_size <> next.icon_size);
    if not Result then Exit;
    rendered := nil;
    try
        if next.backplate and not m_original.Empty then
            rendered := create_backplate_icon(m_instance, m_resource_name, next.icon_size, True, False);
        if rendered <> nil then
            m_icon.Assign(rendered)
        else
            m_icon.Assign(m_original);
        m_appearance := next;
        m_ready := True;
    finally rendered.Free; end;
end;

end.
