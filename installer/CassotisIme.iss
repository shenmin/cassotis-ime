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
#define RuntimeDataDir RuntimeDir + "\data"
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
OutputDir={#SourceRoot}\installer\dist
OutputBaseFilename=CassotisIME-Setup-{#AppVersion}
SetupIconFile={#SourceRoot}\cassotis_ime_yanquan.ico
UninstallDisplayIcon={app}\out\cassotis_ime_tray_host.exe
CloseApplications=yes
RestartApplications=no
CloseApplicationsFilter=cassotis_ime_host.exe,cassotis_ime_tray_host.exe,ctfmon.exe

[Languages]
Name: "chs"; MessagesFile: "compiler:ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "startime"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: checkedonce

[Dirs]
Name: "{localappdata}\CassotisIme"
Name: "{localappdata}\CassotisIme\data"
Name: "{localappdata}\CassotisIme\logs"

[Files]
Source: "{#SourceRoot}\cassotis_ime_yanquan.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\version.props"; DestDir: "{app}"; Flags: ignoreversion

Source: "{#RuntimeDir}\cassotis_ime_host.exe"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_tray_host.exe"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_svr.dll"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_svr32.dll"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_profile_reg.exe"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\cassotis_ime_dict_init.exe"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\sqlite3_64.dll"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\register_tsf.ps1"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\unregister_tsf.ps1"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\start_tsf.ps1"; DestDir: "{app}\out"; Flags: ignoreversion
Source: "{#RuntimeDir}\stop_tsf.ps1"; DestDir: "{app}\out"; Flags: ignoreversion

Source: "{#RuntimeDataDir}\dict_sc.db"; DestDir: "{localappdata}\CassotisIme\data"; DestName: "dict_sc.db"; Flags: ignoreversion
Source: "{#RuntimeDataDir}\dict_tc.db"; DestDir: "{localappdata}\CassotisIme\data"; DestName: "dict_tc.db"; Flags: ignoreversion
[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\out\stop_tsf.ps1"" -force_kill"; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Stopping Text Services..."
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\out\register_tsf.ps1"" -dll_path ""{app}\out\cassotis_ime_svr.dll"""; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Registering Cassotis IME..."
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\out\start_tsf.ps1"" -restart"; \
    Tasks: startime; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Starting Cassotis IME..."

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\out\stop_tsf.ps1"" -force_kill"; \
    Flags: runhidden waituntilterminated skipifdoesntexist; \
    RunOnceId: "StopTSF"
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\out\unregister_tsf.ps1"" -dll_path ""{app}\out\cassotis_ime_svr.dll"""; \
    Flags: runhidden waituntilterminated skipifdoesntexist; \
    RunOnceId: "UnregisterTSF"

[Code]
function GetRuntimeRoot: string;
begin
    Result := ExpandConstant('{localappdata}\CassotisIme');
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

