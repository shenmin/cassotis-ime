unit nc_engine_host_app;

interface

uses
    System.SysUtils,
    System.Classes,
    System.Generics.Collections,
    Winapi.Windows,
    Vcl.Forms,
    Vcl.Controls,
    nc_engine_host,
    nc_ipc_common;

type
    TncEngineHostApp = class(TForm)
    private
        m_host: TncEngineHost;
        m_server_threads: TObjectList<TncPipeServerThread>;
        procedure add_pipe_thread(const pipe_name: string);
    protected
        procedure CreateParams(var Params: TCreateParams); override;
    public
        constructor Create(AOwner: TComponent); override;
        destructor Destroy; override;
    end;

implementation

procedure TncEngineHostApp.CreateParams(var Params: TCreateParams);
begin
    inherited;
    Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
end;

constructor TncEngineHostApp.Create(AOwner: TComponent);
var
    session_id: DWORD;
    session_suffix: string;
begin
    inherited CreateNew(AOwner);
    BorderStyle := bsNone;
    Visible := False;
    m_host := TncEngineHost.create;
    m_server_threads := TObjectList<TncPipeServerThread>.Create(True);

    // Primary pipe for current clients.
    add_pipe_thread(get_nc_pipe_name);
    // Legacy pipe without session suffix.
    add_pipe_thread(c_nc_pipe_base);

    // Compatibility aliases for older clients that still use integrity suffixes.
    session_id := 0;
    if not ProcessIdToSessionId(GetCurrentProcessId, session_id) then
    begin
        session_id := 0;
    end;
    session_suffix := Format('_s%d', [session_id]);
    add_pipe_thread(c_nc_pipe_base + session_suffix + '_user');
    add_pipe_thread(c_nc_pipe_base + session_suffix + '_admin');
end;

destructor TncEngineHostApp.Destroy;
var
    bytes_read: DWORD;
    response: array[0..15] of Byte;
    ping_text: AnsiString;
    server_thread: TncPipeServerThread;
begin
    if m_server_threads <> nil then
    begin
        for server_thread in m_server_threads do
        begin
            server_thread.Terminate;
        end;
        for server_thread in m_server_threads do
        begin
            bytes_read := 0;
            ping_text := AnsiString('PING');
            CallNamedPipe(PChar(server_thread.pipe_name), PAnsiChar(ping_text), Length(ping_text),
                @response[0], Length(response), bytes_read, 50);
        end;
        for server_thread in m_server_threads do
        begin
            server_thread.WaitFor;
        end;
        m_server_threads.Free;
        m_server_threads := nil;
    end;
    if m_host <> nil then
    begin
        m_host.Free;
        m_host := nil;
    end;
    inherited Destroy;
end;

procedure TncEngineHostApp.add_pipe_thread(const pipe_name: string);
var
    server_thread: TncPipeServerThread;
    existing: TncPipeServerThread;
begin
    if (pipe_name = '') or (m_server_threads = nil) then
    begin
        Exit;
    end;

    for existing in m_server_threads do
    begin
        if SameText(existing.pipe_name, pipe_name) then
        begin
            Exit;
        end;
    end;

    server_thread := TncPipeServerThread.create(m_host, pipe_name);
    server_thread.FreeOnTerminate := False;
    m_server_threads.Add(server_thread);
end;

end.
