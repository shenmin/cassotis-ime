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
    g_scope_suffix := Format('_s%d', [session_id]);
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
