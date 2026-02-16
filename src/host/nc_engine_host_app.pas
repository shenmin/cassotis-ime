unit nc_engine_host_app;

interface

uses
    System.SysUtils,
    System.Classes,
    Winapi.Windows,
    Vcl.Forms,
    nc_engine_host,
    nc_ipc_common;

type
    TncEngineHostApp = class(TForm)
    private
        m_host: TncEngineHost;
        m_server_thread: TncPipeServerThread;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

implementation

constructor TncEngineHostApp.Create(AOwner: TComponent);
begin
    inherited CreateNew(AOwner);
    BorderStyle := bsNone;
    Visible := False;
    m_host := TncEngineHost.create;
    m_server_thread := TncPipeServerThread.create(m_host);
    m_server_thread.FreeOnTerminate := False;
end;

destructor TncEngineHostApp.Destroy;
var
    bytes_read: DWORD;
    response: array[0..15] of Byte;
    ping_text: AnsiString;
begin
    if m_server_thread <> nil then
    begin
        m_server_thread.Terminate;
        bytes_read := 0;
        ping_text := AnsiString('PING');
        CallNamedPipe(PChar(get_nc_pipe_name), PAnsiChar(ping_text), Length(ping_text),
            @response[0], Length(response), bytes_read, 50);
        m_server_thread.WaitFor;
        m_server_thread.Free;
        m_server_thread := nil;
    end;
    if m_host <> nil then
    begin
        m_host.Free;
        m_host := nil;
    end;
    inherited Destroy;
end;

end.
