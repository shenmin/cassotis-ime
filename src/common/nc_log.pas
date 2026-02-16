unit nc_log;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    Winapi.Windows,
    nc_types;

type
    TncLogger = class
    private
        m_log_path: string;
        m_level: TncLogLevel;
        m_max_size_kb: Integer;
        procedure write_line(const level: TncLogLevel; const msg: string);
        function level_to_text(const level: TncLogLevel): string;
    public
        constructor create(const log_path: string); overload;
        constructor create(const log_path: string; const max_size_kb: Integer); overload;
        procedure set_level(const level: TncLogLevel);
        procedure debug(const msg: string);
        procedure info(const msg: string);
        procedure warn(const msg: string);
        procedure error(const msg: string);
        property log_path: string read m_log_path;
        property level: TncLogLevel read m_level write m_level;
    end;

function get_default_log_path: string;

implementation

function get_module_directory: string;
var
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
begin
    path_len := GetModuleFileName(HInstance, path_buffer, Length(path_buffer));
    if path_len = 0 then
    begin
        Result := '';
        Exit;
    end;

    Result := ExtractFileDir(path_buffer);
end;

function get_file_size(const path: string): Int64;
var
    stream: TFileStream;
begin
    Result := 0;
    if path = '' then
    begin
        Exit;
    end;

    try
        stream := TFileStream.Create(path, fmOpenRead or fmShareDenyNone);
        try
            Result := stream.Size;
        finally
            stream.Free;
        end;
    except
        Result := 0;
    end;
end;

constructor TncLogger.create(const log_path: string);
begin
    create(log_path, 1024);
end;

constructor TncLogger.create(const log_path: string; const max_size_kb: Integer);
begin
    inherited create;
    m_log_path := log_path;
    m_level := ll_info;
    m_max_size_kb := max_size_kb;
end;

procedure TncLogger.set_level(const level: TncLogLevel);
begin
    m_level := level;
end;

function TncLogger.level_to_text(const level: TncLogLevel): string;
begin
    case level of
        ll_debug:
            Result := 'DEBUG';
        ll_info:
            Result := 'INFO';
        ll_warn:
            Result := 'WARN';
        ll_error:
            Result := 'ERROR';
    else
        Result := 'INFO';
    end;
end;

procedure TncLogger.write_line(const level: TncLogLevel; const msg: string);
var
    line: string;
    dir_path: string;
    rotated_path: string;
    current_size: Int64;
begin
    if level < m_level then
    begin
        Exit;
    end;

    dir_path := ExtractFileDir(m_log_path);
    if dir_path <> '' then
    begin
        ForceDirectories(dir_path);
    end;

    if (m_max_size_kb > 0) and FileExists(m_log_path) then
    begin
        current_size := get_file_size(m_log_path);
        if current_size > Int64(m_max_size_kb) * 1024 then
        begin
            rotated_path := m_log_path + '.1';
            if FileExists(rotated_path) then
            begin
                TFile.Delete(rotated_path);
            end;

            TFile.Move(m_log_path, rotated_path);
        end;
    end;

    line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [' + level_to_text(level) + '] ' + msg + sLineBreak;
    TFile.AppendAllText(m_log_path, line, TEncoding.UTF8);
end;

procedure TncLogger.debug(const msg: string);
begin
    write_line(ll_debug, msg);
end;

procedure TncLogger.info(const msg: string);
begin
    write_line(ll_info, msg);
end;

procedure TncLogger.warn(const msg: string);
begin
    write_line(ll_warn, msg);
end;

procedure TncLogger.error(const msg: string);
begin
    write_line(ll_error, msg);
end;

function get_default_log_path: string;
var
    module_dir: string;
begin
    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := 'logs\\cassotis_ime.log';
        Exit;
    end;

    Result := IncludeTrailingPathDelimiter(module_dir) + 'logs\\cassotis_ime.log';
end;

end.
