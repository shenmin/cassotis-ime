unit nc_tray_menu;

interface

uses
    System.Classes, System.Types, Winapi.Windows, Vcl.Menus;

type
    TncTrayMenuTrace = procedure(const detail: string) of object;

    // What the low-level hooks are handed (winuser.h; Winapi.Windows has no such records).
    TncMouseHookData = record
        pt: TPoint;
        mouse_data: DWORD;
        flags: DWORD;
        time: DWORD;
        extra_info: ULONG_PTR;
    end;
    PncMouseHookData = ^TncMouseHookData;

    TncKeyHookData = record
        vk_code: DWORD;
        scan_code: DWORD;
        flags: DWORD;
        time: DWORD;
        extra_info: ULONG_PTR;
    end;
    PncKeyHookData = ^TncKeyHookData;

    TncTrayPopupMenu = class(TPopupMenu)
    private
        m_popup_owner: HWND;
        m_tracking: Boolean;
        m_on_closed: TNotifyEvent;
        m_on_trace: TncTrayMenuTrace;
        procedure trace(const detail: string);
        procedure run_menu(const x, y: Integer; const over_application: Boolean);
        function track_with_foreground(const x, y: Integer): Cardinal;
        function track_over_application(const x, y: Integer): Cardinal;
    protected
        function track_menu(const x, y: Integer): Cardinal; virtual;
        function foreground_window: HWND; virtual;
        function set_foreground_window(const window: HWND): Boolean; virtual;
    public
        procedure Popup(X, Y: Integer); override;
        // For a menu opened from over an application, not from the taskbar: the
        // application keeps the foreground and the focus while it is open, so
        // pinyin being typed stays. The system closes such a menu neither on a
        // click outside it nor on a key, so the hooks below do while it is open.
        // A command that opens a dialog takes the foreground (from the click on
        // the menu); it goes back after the command has run, unless the user or
        // that command has put another window there.
        procedure PopupOverApplication(X, Y: Integer);
        property PopupOwner: HWND read m_popup_owner write m_popup_owner;
        property Tracking: Boolean read m_tracking;
        property OnClosed: TNotifyEvent read m_on_closed write m_on_closed;
        property OnTrace: TncTrayMenuTrace read m_on_trace write m_on_trace;
    end;

// A button down outside the menu closes it, and the click goes on to the window
// under it. Any key closes it and goes on to the application, which is still
// typing; Esc is for the menu alone. In the interface for the tests.
function nc_tray_menu_mouse_hook(code: Integer; message_id: WPARAM; data: LPARAM): LRESULT; stdcall;
function nc_tray_menu_key_hook(code: Integer; message_id: WPARAM; data: LPARAM): LRESULT; stdcall;

implementation

uses
    System.SysUtils, Winapi.Messages;

function point_on_menu(const point: TPoint): Boolean;
var
    window: HWND;
    class_name: array[0..15] of Char;
begin
    window := WindowFromPoint(point);
    Result := (window <> 0) and (GetWindowThreadProcessId(window, nil) = GetCurrentThreadId) and
        (GetClassName(window, class_name, Length(class_name)) > 0) and
        (string(class_name) = '#32768');
end;

function nc_tray_menu_mouse_hook(code: Integer; message_id: WPARAM; data: LPARAM): LRESULT; stdcall;
begin
    if code = HC_ACTION then
    begin
        case message_id of
            WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_XBUTTONDOWN:
                if not point_on_menu(PncMouseHookData(data)^.pt) then EndMenu;
        end;
    end;
    Result := CallNextHookEx(0, code, message_id, data);
end;

function nc_tray_menu_key_hook(code: Integer; message_id: WPARAM; data: LPARAM): LRESULT; stdcall;
begin
    if (code = HC_ACTION) and ((message_id = WM_KEYDOWN) or (message_id = WM_SYSKEYDOWN)) then
    begin
        EndMenu;
        if PncKeyHookData(data)^.vk_code = VK_ESCAPE then Exit(1);
    end;
    Result := CallNextHookEx(0, code, message_id, data);
end;

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

function TncTrayPopupMenu.track_with_foreground(const x, y: Integer): Cardinal;
var
    foreground_set: Boolean;
begin
    foreground_set := set_foreground_window(m_popup_owner);
    trace(Format('open x=%d y=%d foreground_set=%d owner=%s foreground=%s',
        [x, y, Ord(foreground_set), IntToHex(m_popup_owner, SizeOf(HWND) * 2),
         IntToHex(foreground_window, SizeOf(HWND) * 2)]));
    Result := track_menu(x, y);
end;

function TncTrayPopupMenu.track_over_application(const x, y: Integer): Cardinal;
var
    mouse_hook, key_hook: HHOOK;
begin
    mouse_hook := SetWindowsHookEx(WH_MOUSE_LL, nc_tray_menu_mouse_hook, HInstance, 0);
    key_hook := SetWindowsHookEx(WH_KEYBOARD_LL, nc_tray_menu_key_hook, HInstance, 0);
    try
        // Without the hooks only the foreground can close the menu.
        if (mouse_hook = 0) or (key_hook = 0) then
        begin
            trace(Format('no hooks err=%d', [GetLastError]));
            Exit(track_with_foreground(x, y));
        end;
        trace(Format('open over application x=%d y=%d owner=%s foreground=%s',
            [x, y, IntToHex(m_popup_owner, SizeOf(HWND) * 2),
             IntToHex(foreground_window, SizeOf(HWND) * 2)]));
        Result := track_menu(x, y);
    finally
        // Before the command runs: a dialog stays open for as long as the user likes.
        if key_hook <> 0 then UnhookWindowsHookEx(key_hook);
        if mouse_hook <> 0 then UnhookWindowsHookEx(mouse_hook);
    end;
end;

procedure TncTrayPopupMenu.run_menu(const x, y: Integer; const over_application: Boolean);
var
    command_id: Cardinal;
    item: TMenuItem;
begin
    if m_tracking or (m_popup_owner = 0) or not IsWindow(m_popup_owner) then Exit;
    // Focus changes can synchronously deliver profile notifications, before a
    // native menu window exists. Guard the whole call, not FindWindow('#32768').
    m_tracking := True;
    try
        try
            SetPopupPoint(Point(x, y));
            DoPopup(Self);
            trace(Format('begin x=%d y=%d capture=%s',
                [x, y, IntToHex(GetCapture, SizeOf(HWND) * 2)]));
            if GetCapture <> 0 then ReleaseCapture;
            // This owner is the hidden tray form. Follow the invocation monitor
            // so a menu opened after an RDP/display change uses its current DPI.
            SetWindowPos(m_popup_owner, 0, x, y, 1, 1,
                SWP_NOACTIVATE or SWP_NOZORDER or SWP_NOOWNERZORDER);
            if over_application then
                command_id := track_over_application(x, y)
            else
                command_id := track_with_foreground(x, y);
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

procedure TncTrayPopupMenu.Popup(X, Y: Integer);
begin
    run_menu(X, Y, False);
end;

procedure TncTrayPopupMenu.PopupOverApplication(X, Y: Integer);
var
    application_window: HWND;
    returned: Boolean;
begin
    if m_tracking then Exit;
    application_window := foreground_window;
    try
        run_menu(X, Y, True);
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
