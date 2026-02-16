unit nc_sqlite;

interface

uses
    System.SysUtils,
    Winapi.Windows;

type
    Psqlite3 = Pointer;
    Psqlite3_stmt = Pointer;

    Tsqlite3_open_v2 = function(filename: PAnsiChar; out db: Psqlite3; flags: Integer; vfs: PAnsiChar): Integer; cdecl;
    Tsqlite3_close = function(db: Psqlite3): Integer; cdecl;
    Tsqlite3_prepare_v2 = function(db: Psqlite3; sql: PAnsiChar; nbyte: Integer; out stmt: Psqlite3_stmt; tail: PPAnsiChar): Integer; cdecl;
    Tsqlite3_step = function(stmt: Psqlite3_stmt): Integer; cdecl;
    Tsqlite3_finalize = function(stmt: Psqlite3_stmt): Integer; cdecl;
    Tsqlite3_bind_text = function(stmt: Psqlite3_stmt; idx: Integer; text: PAnsiChar; n: Integer; dest: Pointer): Integer; cdecl;
    Tsqlite3_bind_int = function(stmt: Psqlite3_stmt; idx: Integer; value: Integer): Integer; cdecl;
    Tsqlite3_column_text = function(stmt: Psqlite3_stmt; idx: Integer): PAnsiChar; cdecl;
    Tsqlite3_column_int = function(stmt: Psqlite3_stmt; idx: Integer): Integer; cdecl;
    Tsqlite3_reset = function(stmt: Psqlite3_stmt): Integer; cdecl;
    Tsqlite3_clear_bindings = function(stmt: Psqlite3_stmt): Integer; cdecl;
    Tsqlite3_errmsg = function(db: Psqlite3): PAnsiChar; cdecl;
    Tsqlite3_exec = function(db: Psqlite3; sql: PAnsiChar; callback: Pointer; arg: Pointer; errmsg: PPAnsiChar): Integer; cdecl;

    TncSqliteLib = class
    private
        m_lib_handle: HMODULE;
        m_loaded: Boolean;
        m_open_v2: Tsqlite3_open_v2;
        m_close: Tsqlite3_close;
        m_prepare_v2: Tsqlite3_prepare_v2;
        m_step: Tsqlite3_step;
        m_finalize: Tsqlite3_finalize;
        m_bind_text: Tsqlite3_bind_text;
        m_bind_int: Tsqlite3_bind_int;
        m_column_text: Tsqlite3_column_text;
        m_column_int: Tsqlite3_column_int;
        m_reset: Tsqlite3_reset;
        m_clear_bindings: Tsqlite3_clear_bindings;
        m_errmsg: Tsqlite3_errmsg;
        m_exec: Tsqlite3_exec;
        function load_proc(const name: PAnsiChar): Pointer;
        procedure reset_procs;
    public
        constructor create;
        destructor Destroy; override;
        function load(const dll_name: string): Boolean;
        procedure unload;
        function open(const file_path: string; out db: Psqlite3; const flags: Integer): Integer;
        function close(const db: Psqlite3): Integer;
        function prepare(const db: Psqlite3; const sql: string; out stmt: Psqlite3_stmt): Integer;
        function step(const stmt: Psqlite3_stmt): Integer;
        function finalize(const stmt: Psqlite3_stmt): Integer;
        function bind_text(const stmt: Psqlite3_stmt; const index: Integer; const text: string): Integer;
        function bind_int(const stmt: Psqlite3_stmt; const index: Integer; const value: Integer): Integer;
        function column_text(const stmt: Psqlite3_stmt; const index: Integer): string;
        function column_int(const stmt: Psqlite3_stmt; const index: Integer): Integer;
        function reset(const stmt: Psqlite3_stmt): Integer;
        function clear_bindings(const stmt: Psqlite3_stmt): Integer;
        function errmsg(const db: Psqlite3): string;
        function exec(const db: Psqlite3; const sql: string): Integer;
        property loaded: Boolean read m_loaded;
    end;

    TncSqliteConnection = class
    private
        m_lib: TncSqliteLib;
        m_db: Psqlite3;
        m_db_path: string;
        m_opened: Boolean;
        function ensure_opened: Boolean;
    public
        constructor create(const db_path: string);
        destructor Destroy; override;
        function open: Boolean; overload;
        function open(const flags: Integer): Boolean; overload;
        procedure close;
        function prepare(const sql: string; out stmt: Psqlite3_stmt): Boolean;
        function step(const stmt: Psqlite3_stmt): Integer;
        function finalize(const stmt: Psqlite3_stmt): Boolean;
        function bind_text(const stmt: Psqlite3_stmt; const index: Integer; const text: string): Boolean;
        function bind_int(const stmt: Psqlite3_stmt; const index: Integer; const value: Integer): Boolean;
        function column_text(const stmt: Psqlite3_stmt; const index: Integer): string;
        function column_int(const stmt: Psqlite3_stmt; const index: Integer): Integer;
        function reset(const stmt: Psqlite3_stmt): Boolean;
        function clear_bindings(const stmt: Psqlite3_stmt): Boolean;
        function errmsg: string;
        function exec(const sql: string): Boolean;
        property db_path: string read m_db_path;
        property opened: Boolean read m_opened;
    end;

const
    SQLITE_OK = 0;
    SQLITE_ERROR = 1;
    SQLITE_ROW = 100;
    SQLITE_DONE = 101;
    SQLITE_OPEN_READONLY = $00000001;
    SQLITE_OPEN_READWRITE = $00000002;
    SQLITE_OPEN_CREATE = $00000004;
    SQLITE_TRANSIENT = Pointer(-1);

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

function get_sqlite_dll_candidates: TArray<string>;
var
    module_dir: string;
    count_value: Integer;

    procedure add_candidate(const candidate_path: string);
    begin
        if candidate_path = '' then
        begin
            Exit;
        end;

        count_value := Length(Result);
        SetLength(Result, count_value + 1);
        Result[count_value] := candidate_path;
    end;
begin
    SetLength(Result, 0);
    module_dir := get_module_directory;
    if module_dir <> '' then
    begin
{$IFDEF WIN32}
        add_candidate(IncludeTrailingPathDelimiter(module_dir) + 'sqlite3_32.dll');
        add_candidate(IncludeTrailingPathDelimiter(module_dir) + 'sqlite\win32\sqlite3.dll');
{$ELSE}
        add_candidate(IncludeTrailingPathDelimiter(module_dir) + 'sqlite3_64.dll');
        add_candidate(IncludeTrailingPathDelimiter(module_dir) + 'sqlite\win64\sqlite3.dll');
{$ENDIF}
        add_candidate(IncludeTrailingPathDelimiter(module_dir) + 'sqlite3.dll');
    end;

    add_candidate('sqlite3.dll');
end;

constructor TncSqliteLib.create;
begin
    inherited create;
    m_lib_handle := 0;
    m_loaded := False;
    reset_procs;
end;

destructor TncSqliteLib.Destroy;
begin
    unload;
    inherited Destroy;
end;

procedure TncSqliteLib.reset_procs;
begin
    m_open_v2 := nil;
    m_close := nil;
    m_prepare_v2 := nil;
    m_step := nil;
    m_finalize := nil;
    m_bind_text := nil;
    m_bind_int := nil;
    m_column_text := nil;
    m_column_int := nil;
    m_reset := nil;
    m_clear_bindings := nil;
    m_errmsg := nil;
    m_exec := nil;
end;

function TncSqliteLib.load_proc(const name: PAnsiChar): Pointer;
begin
    Result := GetProcAddress(m_lib_handle, name);
end;

function TncSqliteLib.load(const dll_name: string): Boolean;
begin
    if m_loaded then
    begin
        Result := True;
        Exit;
    end;

    m_lib_handle := LoadLibrary(PChar(dll_name));
    if m_lib_handle = 0 then
    begin
        Result := False;
        Exit;
    end;

    m_open_v2 := Tsqlite3_open_v2(load_proc('sqlite3_open_v2'));
    m_close := Tsqlite3_close(load_proc('sqlite3_close'));
    m_prepare_v2 := Tsqlite3_prepare_v2(load_proc('sqlite3_prepare_v2'));
    m_step := Tsqlite3_step(load_proc('sqlite3_step'));
    m_finalize := Tsqlite3_finalize(load_proc('sqlite3_finalize'));
    m_bind_text := Tsqlite3_bind_text(load_proc('sqlite3_bind_text'));
    m_bind_int := Tsqlite3_bind_int(load_proc('sqlite3_bind_int'));
    m_column_text := Tsqlite3_column_text(load_proc('sqlite3_column_text'));
    m_column_int := Tsqlite3_column_int(load_proc('sqlite3_column_int'));
    m_reset := Tsqlite3_reset(load_proc('sqlite3_reset'));
    m_clear_bindings := Tsqlite3_clear_bindings(load_proc('sqlite3_clear_bindings'));
    m_errmsg := Tsqlite3_errmsg(load_proc('sqlite3_errmsg'));
    m_exec := Tsqlite3_exec(load_proc('sqlite3_exec'));

    if (not Assigned(m_open_v2)) or (not Assigned(m_close)) or (not Assigned(m_prepare_v2)) or
        (not Assigned(m_step)) or (not Assigned(m_finalize)) or (not Assigned(m_bind_text)) or
        (not Assigned(m_bind_int)) or (not Assigned(m_column_text)) or (not Assigned(m_column_int)) or
        (not Assigned(m_reset)) or (not Assigned(m_clear_bindings)) or (not Assigned(m_errmsg)) or
        (not Assigned(m_exec)) then
    begin
        unload;
        Result := False;
        Exit;
    end;

    m_loaded := True;
    Result := True;
end;

procedure TncSqliteLib.unload;
begin
    if m_lib_handle <> 0 then
    begin
        FreeLibrary(m_lib_handle);
    end;

    m_lib_handle := 0;
    m_loaded := False;
    reset_procs;
end;

function TncSqliteLib.open(const file_path: string; out db: Psqlite3; const flags: Integer): Integer;
var
    utf8: UTF8String;
begin
    db := nil;
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    utf8 := UTF8String(file_path);
    Result := m_open_v2(PAnsiChar(utf8), db, flags, nil);
end;

function TncSqliteLib.close(const db: Psqlite3): Integer;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_close(db);
end;

function TncSqliteLib.prepare(const db: Psqlite3; const sql: string; out stmt: Psqlite3_stmt): Integer;
var
    utf8: UTF8String;
begin
    stmt := nil;
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    utf8 := UTF8String(sql);
    Result := m_prepare_v2(db, PAnsiChar(utf8), Length(utf8), stmt, nil);
end;

function TncSqliteLib.step(const stmt: Psqlite3_stmt): Integer;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_step(stmt);
end;

function TncSqliteLib.finalize(const stmt: Psqlite3_stmt): Integer;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_finalize(stmt);
end;

function TncSqliteLib.bind_text(const stmt: Psqlite3_stmt; const index: Integer; const text: string): Integer;
var
    utf8: UTF8String;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    utf8 := UTF8String(text);
    Result := m_bind_text(stmt, index, PAnsiChar(utf8), Length(utf8), SQLITE_TRANSIENT);
end;

function TncSqliteLib.bind_int(const stmt: Psqlite3_stmt; const index: Integer; const value: Integer): Integer;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_bind_int(stmt, index, value);
end;

function TncSqliteLib.column_text(const stmt: Psqlite3_stmt; const index: Integer): string;
var
    ptr: PAnsiChar;
begin
    Result := '';
    if not m_loaded then
    begin
        Exit;
    end;

    ptr := m_column_text(stmt, index);
    if ptr <> nil then
    begin
        Result := UTF8ToString(ptr);
    end;
end;

function TncSqliteLib.column_int(const stmt: Psqlite3_stmt; const index: Integer): Integer;
begin
    Result := 0;
    if not m_loaded then
    begin
        Exit;
    end;

    Result := m_column_int(stmt, index);
end;

function TncSqliteLib.reset(const stmt: Psqlite3_stmt): Integer;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_reset(stmt);
end;

function TncSqliteLib.clear_bindings(const stmt: Psqlite3_stmt): Integer;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_clear_bindings(stmt);
end;

function TncSqliteLib.errmsg(const db: Psqlite3): string;
var
    ptr: PAnsiChar;
begin
    Result := '';
    if not m_loaded then
    begin
        Exit;
    end;

    ptr := m_errmsg(db);
    if ptr <> nil then
    begin
        Result := UTF8ToString(ptr);
    end;
end;

function TncSqliteLib.exec(const db: Psqlite3; const sql: string): Integer;
var
    utf8: UTF8String;
begin
    if not m_loaded then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    utf8 := UTF8String(sql);
    Result := m_exec(db, PAnsiChar(utf8), nil, nil, nil);
end;

constructor TncSqliteConnection.create(const db_path: string);
begin
    inherited create;
    m_db_path := db_path;
    m_db := nil;
    m_opened := False;
    m_lib := TncSqliteLib.create;
end;

destructor TncSqliteConnection.Destroy;
begin
    close;
    m_lib.Free;
    inherited Destroy;
end;

function TncSqliteConnection.ensure_opened: Boolean;
begin
    if m_opened then
    begin
        Result := True;
        Exit;
    end;

    Result := open;
end;

function TncSqliteConnection.open: Boolean;
begin
    Result := open(SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE);
end;

function TncSqliteConnection.open(const flags: Integer): Boolean;
var
    rc: Integer;
    sqlite_paths: TArray<string>;
    sqlite_path: string;
    path_index: Integer;
    loaded: Boolean;
begin
    Result := False;
    if m_opened then
    begin
        Result := True;
        Exit;
    end;

    if m_db_path = '' then
    begin
        Exit;
    end;

    sqlite_paths := get_sqlite_dll_candidates;
    loaded := False;
    for path_index := 0 to High(sqlite_paths) do
    begin
        sqlite_path := sqlite_paths[path_index];
        if m_lib.load(sqlite_path) then
        begin
            loaded := True;
            Break;
        end;
    end;
    if not loaded then
    begin
        Exit;
    end;

    rc := m_lib.open(m_db_path, m_db, flags);
    if rc <> SQLITE_OK then
    begin
        m_db := nil;
        Exit;
    end;

    m_opened := True;
    Result := True;
end;

procedure TncSqliteConnection.close;
begin
    if m_opened and (m_db <> nil) then
    begin
        m_lib.close(m_db);
    end;

    m_db := nil;
    m_opened := False;
end;

function TncSqliteConnection.prepare(const sql: string; out stmt: Psqlite3_stmt): Boolean;
var
    rc: Integer;
begin
    stmt := nil;
    if not ensure_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.prepare(m_db, sql, stmt);
    Result := rc = SQLITE_OK;
end;

function TncSqliteConnection.step(const stmt: Psqlite3_stmt): Integer;
begin
    if not m_opened then
    begin
        Result := SQLITE_ERROR;
        Exit;
    end;

    Result := m_lib.step(stmt);
end;

function TncSqliteConnection.finalize(const stmt: Psqlite3_stmt): Boolean;
var
    rc: Integer;
begin
    if not m_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.finalize(stmt);
    Result := rc = SQLITE_OK;
end;

function TncSqliteConnection.bind_text(const stmt: Psqlite3_stmt; const index: Integer; const text: string): Boolean;
var
    rc: Integer;
begin
    if not m_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.bind_text(stmt, index, text);
    Result := rc = SQLITE_OK;
end;

function TncSqliteConnection.bind_int(const stmt: Psqlite3_stmt; const index: Integer; const value: Integer): Boolean;
var
    rc: Integer;
begin
    if not m_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.bind_int(stmt, index, value);
    Result := rc = SQLITE_OK;
end;

function TncSqliteConnection.column_text(const stmt: Psqlite3_stmt; const index: Integer): string;
begin
    if not m_opened then
    begin
        Result := '';
        Exit;
    end;

    Result := m_lib.column_text(stmt, index);
end;

function TncSqliteConnection.column_int(const stmt: Psqlite3_stmt; const index: Integer): Integer;
begin
    if not m_opened then
    begin
        Result := 0;
        Exit;
    end;

    Result := m_lib.column_int(stmt, index);
end;

function TncSqliteConnection.reset(const stmt: Psqlite3_stmt): Boolean;
var
    rc: Integer;
begin
    if not m_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.reset(stmt);
    Result := rc = SQLITE_OK;
end;

function TncSqliteConnection.clear_bindings(const stmt: Psqlite3_stmt): Boolean;
var
    rc: Integer;
begin
    if not m_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.clear_bindings(stmt);
    Result := rc = SQLITE_OK;
end;

function TncSqliteConnection.errmsg: string;
begin
    if not m_opened then
    begin
        Result := 'sqlite not open';
        Exit;
    end;

    Result := m_lib.errmsg(m_db);
end;

function TncSqliteConnection.exec(const sql: string): Boolean;
var
    rc: Integer;
begin
    if not ensure_opened then
    begin
        Result := False;
        Exit;
    end;

    rc := m_lib.exec(m_db, sql);
    Result := rc = SQLITE_OK;
end;

end.
