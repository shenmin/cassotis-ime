#define MyAppId "{{E6C79C57-16F6-4DD3-8C29-7FD2D3F57B2B}"
#define MyAppName "Cassotis IME－言泉输入法"
#define MyAppPublisher "Cassotis"
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef SourceRoot
  #define SourceRoot ".."
#endif
#define RuntimeDir SourceRoot + "\out"
#ifndef RuntimeDataSourceDir
  #define RuntimeDataSourceDir GetEnv("LOCALAPPDATA") + "\CassotisIme\data"
#endif
#define RuntimeRoot "{localappdata}\CassotisIme"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Cassotis IME
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
UsedUserAreasWarning=no
WizardStyle=modern
Compression=lzma2
SolidCompression=no
OutputDir={#SourceRoot}\out
OutputBaseFilename=cassotis_ime_setup_{#AppVersion}
SetupIconFile={#SourceRoot}\cassotis_ime_yanquan.ico
UninstallDisplayIcon={app}\cassotis_ime_tray_host.exe
CloseApplications=no
RestartApplications=no

[Languages]
Name: "chs"; MessagesFile: "compiler:ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{localappdata}\CassotisIme"
Name: "{localappdata}\CassotisIme\data"
Name: "{localappdata}\CassotisIme\logs"

[InstallDelete]
Type: filesandordirs; Name: "{app}\out"

[Files]
Source: "{#RuntimeDir}\cassotis_ime_host.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_tray_host.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_svr.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_svr32.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_profile_reg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_profile_reg.exe"; Flags: dontcopy
Source: "{#RuntimeDir}\sqlite3_64.dll"; DestDir: "{app}"; Flags: ignoreversion

Source: "{#RuntimeDataSourceDir}\dict_sc.db"; DestDir: "{localappdata}\CassotisIme\data"; DestName: "dict_sc.db"; Flags: ignoreversion
Source: "{#RuntimeDataSourceDir}\dict_tc.db"; DestDir: "{localappdata}\CassotisIme\data"; DestName: "dict_tc.db"; Flags: ignoreversion
[Run]
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "stop -force_kill -dll_path ""{app}\cassotis_ime_svr.dll"""; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Stopping Text Services..."
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "register_tsf -dll_path ""{app}\cassotis_ime_svr.dll"" -skip_profile"; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Registering Cassotis IME components..."
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "register"; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Registering Cassotis IME profile..."
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "start -restart -ctfmon_only"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    StatusMsg: "Preparing text service session..."
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "register"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    StatusMsg: "Registering Cassotis IME profile for current user..."
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "start -restart"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    StatusMsg: "Starting Cassotis IME..."
Filename: "{sys}\cmd.exe"; \
    Parameters: "/c start """" explorer.exe"; \
    Flags: runhidden nowait runasoriginaluser; \
    Check: ShouldRestartExplorer; \
    StatusMsg: "Restarting Windows shell..."

[UninstallRun]
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "stop -force_kill -dll_path ""{app}\cassotis_ime_svr.dll"""; \
    Flags: runhidden waituntilterminated skipifdoesntexist; \
    RunOnceId: "StopTSF"
Filename: "{app}\cassotis_ime_profile_reg.exe"; \
    Parameters: "unregister_tsf -dll_path ""{app}\cassotis_ime_svr.dll"""; \
    Flags: runhidden waituntilterminated skipifdoesntexist; \
    RunOnceId: "UnregisterTSF"

[CustomMessages]
chs.PreparingStopRuntime=正在停止旧版本输入法...
chs.PreparingUnregisterRuntime=正在停用旧版本输入法组件...
chs.PreparingForceCloseRuntime=正在关闭占用旧版本文件的程序...
chs.PreparingWaitRuntime=正在等待旧版本文件释放...
chs.RuntimeReleaseFailed=旧版本文件仍被占用，安装程序已停止。请关闭仍在使用 Cassotis IME 的应用后重新运行安装包。
chs.ForceCloseRuntimePrompt=为完成升级安装，安装程序将自动关闭以下正在占用旧版本文件的进程：
chs.ForceCloseRuntimeContinue=点击“确定”继续，点击“取消”中止安装。
chs.ForceCloseRuntimeCanceled=用户取消了升级安装。
english.PreparingStopRuntime=Stopping existing Cassotis IME runtime...
english.PreparingUnregisterRuntime=Disabling existing Cassotis IME components...
english.PreparingForceCloseRuntime=Closing applications still using existing runtime files...
english.PreparingWaitRuntime=Waiting for existing runtime files to be released...
english.RuntimeReleaseFailed=Setup could not release the files used by the existing Cassotis IME runtime. Please close applications still using Cassotis IME and run Setup again.
english.ForceCloseRuntimePrompt=To continue the upgrade, Setup will automatically close the following processes that are still using existing runtime files:
english.ForceCloseRuntimeContinue=Click OK to continue, or Cancel to abort Setup.
english.ForceCloseRuntimeCanceled=Upgrade canceled by user.

[Code]
const
    c_generic_read = $80000000;
    c_generic_write = $40000000;
    c_open_existing = 3;
    c_file_attribute_normal = $00000080;
    c_invalid_handle_value = -1;
    c_runtime_unlock_wait_attempts = 40;
    c_runtime_unlock_wait_ms = 250;
    c_runtime_retry_force_stop_attempt = 20;

var
    RuntimePrepPage: TOutputProgressWizardPage;
    InstallerProfileRegPath: string;
    ForceStopTargetsPath: string;
    ForceStopApprovalGranted: Boolean;
    ExplorerRestartNeeded: Boolean;

function CreateFileW(lpFileName: string; dwDesiredAccess, dwShareMode: Cardinal;
    lpSecurityAttributes: Integer; dwCreationDisposition, dwFlagsAndAttributes: Cardinal;
    hTemplateFile: Integer): Integer;
external 'CreateFileW@kernel32.dll stdcall';
function CloseHandle(hObject: Integer): Boolean;
external 'CloseHandle@kernel32.dll stdcall';

function GetRuntimeRoot: string;
begin
    Result := ExpandConstant('{localappdata}\CassotisIme');
end;

function GetRuntimeDataDir: string;
begin
    Result := AddBackslash(GetRuntimeRoot) + 'data';
end;

procedure HidePreparingStatus; forward;

procedure InitializeWizard;
begin
    RuntimePrepPage := CreateOutputProgressPage(
        ExpandConstant('{#MyAppName}'),
        ExpandConstant('{cm:PreparingStopRuntime}')
    );
    InstallerProfileRegPath := '';
    ForceStopTargetsPath := ExpandConstant('{tmp}\cassotis_force_stop_targets.txt');
    ForceStopApprovalGranted := False;
    ExplorerRestartNeeded := False;
end;

procedure UpdateExplorerRestartNeeded(const TargetsText: string);
begin
    if Pos(LowerCase('explorer.exe'), LowerCase(TargetsText)) > 0 then
    begin
        ExplorerRestartNeeded := True;
    end;
end;

function GetInstallerProfileRegPath: string;
begin
    if InstallerProfileRegPath <> '' then
    begin
        Result := InstallerProfileRegPath;
        Exit;
    end;

    ExtractTemporaryFile('cassotis_ime_profile_reg.exe');
    InstallerProfileRegPath := ExpandConstant('{tmp}\cassotis_ime_profile_reg.exe');
    Result := InstallerProfileRegPath;
end;

function GetForceStopTargetsText(const RuntimeDir: string): string;
var
    ProfileRegPath: string;
    ResultCode: Integer;
    LoadedLines: TArrayOfString;
    Index: Integer;
begin
    Result := '';
    if RuntimeDir = '' then
    begin
        Exit;
    end;

    ProfileRegPath := GetInstallerProfileRegPath;
    DeleteFile(ForceStopTargetsPath);
    if not Exec(
        ProfileRegPath,
        'list_force_stop_targets -runtime_dir "' + RuntimeDir + '" -data_dir "' + GetRuntimeDataDir +
            '" -output_path "' + ForceStopTargetsPath + '"',
        '',
        SW_HIDE,
        ewWaitUntilTerminated,
        ResultCode
    ) then
    begin
        Exit;
    end;

    if not LoadStringsFromFile(ForceStopTargetsPath, LoadedLines) then
    begin
        Result := '';
        Log('Force-stop target list was not created by helper script.');
    end
    else
    begin
        for Index := 0 to GetArrayLength(LoadedLines) - 1 do
        begin
            if Trim(LoadedLines[Index]) = '' then
            begin
                continue;
            end;
            if Result <> '' then
            begin
                Result := Result + #13#10;
            end;
            Result := Result + LoadedLines[Index];
        end;
        Result := Trim(Result);
        if Result <> '' then
        begin
            Log('Force-stop target list:' + #13#10 + Result);
            UpdateExplorerRestartNeeded(Result);
        end
        else
        begin
            Log('Force-stop target list is empty.');
        end;
    end;
end;

function ShouldRestartExplorer: Boolean;
begin
    Result := ExplorerRestartNeeded;
end;

function ConfirmForceStopProcesses(const RuntimeDir: string): Boolean;
var
    TargetsText: string;
    PromptText: string;
begin
    if ForceStopApprovalGranted then
    begin
        Result := True;
        Exit;
    end;

    TargetsText := GetForceStopTargetsText(RuntimeDir);
    if TargetsText = '' then
    begin
        Result := True;
        Exit;
    end;

    HidePreparingStatus;
    PromptText :=
        ExpandConstant('{cm:ForceCloseRuntimePrompt}') + #13#10#13#10 +
        TargetsText + #13#10#13#10 +
        ExpandConstant('{cm:ForceCloseRuntimeContinue}');
    Result := MsgBox(PromptText, mbConfirmation, MB_OKCANCEL or MB_DEFBUTTON1) = IDOK;
    if Result then
    begin
        ForceStopApprovalGranted := True;
    end;
end;

procedure UpdatePreparingStatus(const StatusText: string; const DetailText: string;
    const ProgressPosition: Integer; const ProgressMax: Integer);
begin
    if RuntimePrepPage = nil then
    begin
        Exit;
    end;

    RuntimePrepPage.SetText(StatusText, DetailText);
    RuntimePrepPage.SetProgress(ProgressPosition, ProgressMax);
    RuntimePrepPage.Show;
    WizardForm.Refresh;
end;

procedure HidePreparingStatus;
begin
    if RuntimePrepPage = nil then
    begin
        Exit;
    end;

    RuntimePrepPage.Hide;
end;

function TryOpenFileExclusive(const FilePath: string): Boolean;
var
    Handle: Integer;
begin
    if not FileExists(FilePath) then
    begin
        Result := True;
        Exit;
    end;

    Handle := CreateFileW(
        FilePath,
        c_generic_read or c_generic_write,
        0,
        0,
        c_open_existing,
        c_file_attribute_normal,
        0
    );
    if Handle = c_invalid_handle_value then
    begin
        Result := False;
        Exit;
    end;

    CloseHandle(Handle);
    Result := True;
end;

function RuntimeFilesReleased(const RuntimeDir: string; out LockedFile: string): Boolean;
var
    Files: array[0..7] of string;
    Index: Integer;
begin
    LockedFile := '';
    if RuntimeDir = '' then
    begin
        Result := True;
        Exit;
    end;

    Files[0] := AddBackslash(RuntimeDir) + 'cassotis_ime_host.exe';
    Files[1] := AddBackslash(RuntimeDir) + 'cassotis_ime_tray_host.exe';
    Files[2] := AddBackslash(RuntimeDir) + 'cassotis_ime_svr.dll';
    Files[3] := AddBackslash(RuntimeDir) + 'cassotis_ime_svr32.dll';
    Files[4] := AddBackslash(RuntimeDir) + 'cassotis_ime_profile_reg.exe';
    Files[5] := AddBackslash(RuntimeDir) + 'sqlite3_64.dll';
    Files[6] := AddBackslash(GetRuntimeDataDir) + 'dict_sc.db';
    Files[7] := AddBackslash(GetRuntimeDataDir) + 'dict_tc.db';

    for Index := 0 to GetArrayLength(Files) - 1 do
    begin
        if not TryOpenFileExclusive(Files[Index]) then
        begin
            LockedFile := Files[Index];
            Result := False;
            Exit;
        end;
    end;

    Result := True;
end;

function RuntimeDirHasManagedFiles(const RuntimeDir: string): Boolean;
begin
    Result :=
        FileExists(AddBackslash(RuntimeDir) + 'cassotis_ime_host.exe') or
        FileExists(AddBackslash(RuntimeDir) + 'cassotis_ime_tray_host.exe') or
        FileExists(AddBackslash(RuntimeDir) + 'cassotis_ime_svr.dll') or
        FileExists(AddBackslash(RuntimeDir) + 'cassotis_ime_svr32.dll') or
        FileExists(AddBackslash(RuntimeDir) + 'cassotis_ime_profile_reg.exe') or
        FileExists(AddBackslash(RuntimeDir) + 'sqlite3_64.dll');
end;

procedure TryStopExistingRuntime(const RuntimeDir: string);
var
    ProfileRegPath: string;
    DllPath: string;
    ResultCode: Integer;
begin
    if RuntimeDir = '' then
    begin
        Exit;
    end;
    if not RuntimeDirHasManagedFiles(RuntimeDir) then
    begin
        Exit;
    end;

    UpdatePreparingStatus(
        ExpandConstant('{cm:PreparingStopRuntime}'),
        RuntimeDir,
        0,
        0
    );

    ProfileRegPath := GetInstallerProfileRegPath;
    if not FileExists(ProfileRegPath) then
    begin
        Exit;
    end;

    DllPath := AddBackslash(RuntimeDir) + 'cassotis_ime_svr.dll';
    Log(Format('Stopping existing Cassotis IME runtime from "%s".', [RuntimeDir]));
    if Exec(
        ProfileRegPath,
        Format('stop -force_kill -dll_path "%s"', [DllPath]),
        '',
        SW_HIDE,
        ewWaitUntilTerminated,
        ResultCode
    ) then
    begin
        Log(Format('Existing runtime stop exit code: %d', [ResultCode]));
    end
    else
    begin
        Log(Format('Failed to launch existing runtime stop helper: %s', [ProfileRegPath]));
    end;
end;

function TryUnregisterExistingRuntime(const RuntimeDir: string): Boolean;
var
    ProfileRegPath: string;
    DllPath: string;
    ResultCode: Integer;
begin
    Result := True;
    if RuntimeDir = '' then
    begin
        Exit;
    end;
    if not RuntimeDirHasManagedFiles(RuntimeDir) then
    begin
        Exit;
    end;

    UpdatePreparingStatus(
        ExpandConstant('{cm:PreparingUnregisterRuntime}'),
        RuntimeDir,
        0,
        0
    );

    ProfileRegPath := GetInstallerProfileRegPath;
    if not FileExists(ProfileRegPath) then
    begin
        Result := False;
        Exit;
    end;

    DllPath := AddBackslash(RuntimeDir) + 'cassotis_ime_svr.dll';
    if not FileExists(DllPath) then
    begin
        Exit;
    end;

    Log(Format('Unregistering existing Cassotis IME TSF from "%s".', [RuntimeDir]));
    if Exec(
        ProfileRegPath,
        Format('unregister_tsf -dll_path "%s"', [DllPath]),
        '',
        SW_HIDE,
        ewWaitUntilTerminated,
        ResultCode
    ) then
    begin
        Log(Format('Existing runtime unregister_tsf exit code: %d', [ResultCode]));
        Result := ResultCode = 0;
    end
    else
    begin
        Log(Format('Failed to launch existing runtime unregister helper: %s', [ProfileRegPath]));
        Result := False;
    end;
end;

procedure TryForceStopProcessesUsingImeModules(const RuntimeDir: string);
var
    ProfileRegPath: string;
    ResultCode: Integer;
begin
    if RuntimeDir = '' then
    begin
        Exit;
    end;
    if not RuntimeDirHasManagedFiles(RuntimeDir) then
    begin
        Exit;
    end;

    UpdatePreparingStatus(
        ExpandConstant('{cm:PreparingForceCloseRuntime}'),
        RuntimeDir,
        0,
        0
    );

    ProfileRegPath := GetInstallerProfileRegPath;
    Log('Running installer-side force-stop pass for processes using IME runtime files.');
    if Exec(
        ProfileRegPath,
        'force_stop_runtime -runtime_dir "' + RuntimeDir + '" -data_dir "' + GetRuntimeDataDir + '"',
        '',
        SW_HIDE,
        ewWaitUntilTerminated,
        ResultCode
    ) then
    begin
        Log(Format('Installer-side force-stop pass exit code: %d', [ResultCode]));
    end
    else
    begin
        Log('Failed to launch installer-side force-stop pass.');
    end;
end;

function WaitForRuntimeRelease(const RuntimeDir: string): Boolean;
var
    Attempt: Integer;
    LockedFile: string;
begin
    Result := True;
    if RuntimeDir = '' then
    begin
        Exit;
    end;
    if not RuntimeDirHasManagedFiles(RuntimeDir) then
    begin
        Exit;
    end;

    for Attempt := 1 to c_runtime_unlock_wait_attempts do
    begin
        if (Attempt = 1) or ((Attempt mod 4) = 0) then
        begin
            UpdatePreparingStatus(
                ExpandConstant('{cm:PreparingWaitRuntime}'),
                RuntimeDir + ' (' + IntToStr(Attempt) + '/' + IntToStr(c_runtime_unlock_wait_attempts) + ')',
                Attempt,
                c_runtime_unlock_wait_attempts
            );
        end;

        if RuntimeFilesReleased(RuntimeDir, LockedFile) then
        begin
            if Attempt > 1 then
            begin
                Log(Format('Runtime files released after %d wait attempts: %s', [Attempt, RuntimeDir]));
            end;
            Result := True;
            Exit;
        end;
        if (Attempt = 1) or ((Attempt mod 4) = 0) then
        begin
            Log(Format('Waiting for locked file to be released: %s', [LockedFile]));
        end;
        if Attempt = c_runtime_retry_force_stop_attempt then
        begin
            Log(Format('Retrying cleanup while waiting for runtime release: %s', [RuntimeDir]));
            TryForceStopProcessesUsingImeModules(RuntimeDir);
            if not TryUnregisterExistingRuntime(RuntimeDir) then
            begin
                Log(Format('Retry unregister_tsf did not fully succeed while waiting: %s', [RuntimeDir]));
            end;
            TryStopExistingRuntime(RuntimeDir);
        end;
        Sleep(c_runtime_unlock_wait_ms);
    end;

    Log(Format('Runtime files still locked after waiting: %s (%s)', [RuntimeDir, LockedFile]));
    Result := False;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
    RootRuntimeDir: string;
    LegacyRuntimeDir: string;
    ActiveRuntimeDir: string;
begin
    NeedsRestart := False;
    RootRuntimeDir := ExpandConstant('{app}');
    LegacyRuntimeDir := ExpandConstant('{app}\out');
    ActiveRuntimeDir := '';
    if RuntimeDirHasManagedFiles(RootRuntimeDir) then
    begin
        ActiveRuntimeDir := RootRuntimeDir;
    end
    else if (CompareText(LegacyRuntimeDir, RootRuntimeDir) <> 0) and RuntimeDirHasManagedFiles(LegacyRuntimeDir) then
    begin
        ActiveRuntimeDir := LegacyRuntimeDir;
    end;

    if ActiveRuntimeDir = '' then
    begin
        HidePreparingStatus;
        Result := '';
        Exit;
    end;

    UpdatePreparingStatus(
        ExpandConstant('{cm:PreparingStopRuntime}'),
        ActiveRuntimeDir,
        0,
        0
    );
    if not ConfirmForceStopProcesses(ActiveRuntimeDir) then
    begin
        Result := ExpandConstant('{cm:ForceCloseRuntimeCanceled}');
        Exit;
    end;
    TryForceStopProcessesUsingImeModules(ActiveRuntimeDir);
    TryStopExistingRuntime(ActiveRuntimeDir);
    if not TryUnregisterExistingRuntime(ActiveRuntimeDir) then
    begin
        Log(Format('Initial unregister_tsf did not fully succeed: %s', [ActiveRuntimeDir]));
    end;
    TryStopExistingRuntime(ActiveRuntimeDir);
    if not WaitForRuntimeRelease(ActiveRuntimeDir) then
    begin
        HidePreparingStatus;
        Result := ExpandConstant('{cm:RuntimeReleaseFailed}');
        Exit;
    end;

    HidePreparingStatus;
    Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
    if CurUninstallStep <> usPostUninstall then
    begin
        Exit;
    end;

    if not DirExists(GetRuntimeRoot) then
    begin
        Exit;
    end;

    if MsgBox(
        'Remove user data under "%LOCALAPPDATA%\CassotisIme"?' + #13#10 +
        'This includes config, dictionaries, user dictionary, and logs.',
        mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    begin
        DelTree(GetRuntimeRoot, True, True, True);
    end;
end;
