unit nc_ipc_common;

interface

const
    c_nc_pipe_base = '\\.\pipe\cassotis_ime_engine_v2';
    c_nc_host_mutex_base = 'Local\cassotis_ime_engine_host_v2';

function encode_ipc_text(const value: string): string;
function decode_ipc_text(const value: string): string;
function bool_to_flag(const value: Boolean): string;
function flag_to_bool(const value: string): Boolean;
function get_nc_pipe_name: string;
function get_nc_host_mutex: string;

implementation

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    System.NetEncoding;

var
    g_scope_suffix: string = '';
    g_scope_ready: Boolean = False;

function get_process_scope_suffix: string;
var
    session_id: DWORD;
    token_handle: THandle;
    elevation: TOKEN_ELEVATION;
    return_size: DWORD;
    level_tag: string;
begin
    if g_scope_ready then
    begin
        Result := g_scope_suffix;
        Exit;
    end;

    session_id := 0;
    if not ProcessIdToSessionId(GetCurrentProcessId, session_id) then
    begin
        session_id := 0;
    end;

    level_tag := 'user';
    token_handle := 0;
    if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, token_handle) then
    begin
        FillChar(elevation, SizeOf(elevation), 0);
        return_size := 0;
        if GetTokenInformation(token_handle, TokenElevation, @elevation, SizeOf(elevation), return_size) then
        begin
            if elevation.TokenIsElevated <> 0 then
            begin
                level_tag := 'admin';
            end;
        end;
        CloseHandle(token_handle);
    end;

    g_scope_suffix := Format('_s%d_%s', [session_id, level_tag]);
    g_scope_ready := True;
    Result := g_scope_suffix;
end;

function get_nc_pipe_name: string;
begin
    Result := c_nc_pipe_base + get_process_scope_suffix;
end;

function get_nc_host_mutex: string;
begin
    Result := c_nc_host_mutex_base + get_process_scope_suffix;
end;

function encode_ipc_text(const value: string): string;
begin
    if value = '' then
    begin
        Result := '';
        Exit;
    end;

    Result := TNetEncoding.Base64.EncodeBytesToString(TEncoding.UTF8.GetBytes(value));
end;

function decode_ipc_text(const value: string): string;
begin
    if value = '' then
    begin
        Result := '';
        Exit;
    end;

    Result := TEncoding.UTF8.GetString(TNetEncoding.Base64.DecodeStringToBytes(value));
end;

function bool_to_flag(const value: Boolean): string;
begin
    if value then
    begin
        Result := '1';
    end
    else
    begin
        Result := '0';
    end;
end;

function flag_to_bool(const value: string): Boolean;
begin
    Result := (value = '1') or SameText(value, 'true') or SameText(value, 'yes');
end;

end.
