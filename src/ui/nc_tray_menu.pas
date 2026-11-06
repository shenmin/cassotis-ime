unit nc_tray_menu;

interface

uses
    System.Classes, Winapi.Windows, Vcl.Menus;

type
    TncTrayMenuTrace = procedure(const detail: string) of object;

    TncTrayPopupMenu = class(TPopupMenu)
    private
        m_popup_owner: HWND;
        m_tracking: Boolean;
        m_on_closed: TNotifyEvent;
        m_on_trace: TncTrayMenuTrace;
        procedure trace(const detail: string);
    protected
        function track_menu(const x, y: Integer): Cardinal; virtual;
        function foreground_window: HWND; virtual;
        function set_foreground_window(const window: HWND): Boolean; virtual;
    public
        procedure Popup(X, Y: Integer); override;
        // For a menu opened from over an application, not from the taskbar: the
        // owner is hidden, and left in the foreground it would keep the keyboard
        // from that application. The foreground goes back once the command has
        // run, so that a dialog it opens can come up first, unless the user or
        // that command has put another window there.
        procedure PopupOverApplication(X, Y: Integer);
        property PopupOwner: HWND read m_popup_owner write m_popup_owner;
        property Tracking: Boolean read m_tracking;
        property OnClosed: TNotifyEvent read m_on_closed write m_on_closed;
        property OnTrace: TncTrayMenuTrace read m_on_trace write m_on_trace;
    end;

implementation

uses
    System.SysUtils, System.Types, Winapi.Messages;

procedure TncTrayPopupMenu.trace(const detail: string);
begin
    if Assigned(m_on_trace) then m_on_trace(detail);
end;

function TncTrayPopupMenu.track_menu(const x, y: Integer): Cardinal;
var
    flags: UINT;
begin
    flags := TPM_RETURNCMD or TPM_NONOTIFY or TPM_RIGHTBUTTON;
    if GetSystemMetrics(SM_MENUDROPALIGNMENT) <> 0 then
        flags := flags or TPM_RIGHTALIGN;
    // Return the command explicitly, using the same owner for focus and tracking.
    Result := Cardinal(TrackPopupMenuEx(Items.Handle, flags, x, y,
        m_popup_owner, nil));
end;

function TncTrayPopupMenu.foreground_window: HWND;
begin
    Result := GetForegroundWindow;
end;

function TncTrayPopupMenu.set_foreground_window(const window: HWND): Boolean;
begin
    Result := SetForegroundWindow(window);
end;

procedure TncTrayPopupMenu.Popup(X, Y: Integer);
var
    command_id: Cardinal;
    item: TMenuItem;
    foreground_set: Boolean;
begin
    if m_tracking or (m_popup_owner = 0) or not IsWindow(m_popup_owner) then Exit;
    // Focus changes can synchronously deliver profile notifications, before a
    // native menu window exists. Guard the whole call, not FindWindow('#32768').
    m_tracking := True;
    try
        try
            SetPopupPoint(Point(X, Y));
            DoPopup(Self);
            trace(Format('begin x=%d y=%d capture=%s',
                [X, Y, IntToHex(GetCapture, SizeOf(HWND) * 2)]));
            if GetCapture <> 0 then ReleaseCapture;
            // This owner is the hidden tray form. Follow the invocation monitor
            // so a menu opened after an RDP/display change uses its current DPI.
            SetWindowPos(m_popup_owner, 0, X, Y, 1, 1,
                SWP_NOACTIVATE or SWP_NOZORDER or SWP_NOOWNERZORDER);
            foreground_set := set_foreground_window(m_popup_owner);
            trace(Format('open x=%d y=%d foreground_set=%d owner=%s foreground=%s',
                [X, Y, Ord(foreground_set), IntToHex(m_popup_owner, SizeOf(HWND) * 2),
                 IntToHex(foreground_window, SizeOf(HWND) * 2)]));
            command_id := track_menu(X, Y);
        finally
            m_tracking := False;
            PostMessage(m_popup_owner, WM_NULL, 0, 0);
        end;
        trace(Format('close command=%d', [command_id]));
        if command_id = 0 then Exit;
        item := FindItem(command_id, fkCommand);
        if (item = nil) or not item.Enabled or not item.Visible or
            item.IsLine then Exit;
        trace(Format('dispatch command=%d caption=%s', [command_id, item.Caption]));
        item.Click;
        trace(Format('complete command=%d', [command_id]));
    finally
        if Assigned(m_on_closed) then m_on_closed(Self);
    end;
end;

procedure TncTrayPopupMenu.PopupOverApplication(X, Y: Integer);
var
    application_window: HWND;
    returned: Boolean;
begin
    if m_tracking then Exit;
    application_window := foreground_window;
    try
        Popup(X, Y);
    finally
        if (application_window <> 0) and (application_window <> m_popup_owner) and
            IsWindow(application_window) and (foreground_window = m_popup_owner) then
        begin
            returned := set_foreground_window(application_window);
            trace(Format('foreground back window=%s returned=%d',
                [IntToHex(application_window, SizeOf(HWND) * 2), Ord(returned)]));
        end;
    end;
end;

end.
