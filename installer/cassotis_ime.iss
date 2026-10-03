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
#ifndef RuntimeBuildId
  #define RuntimeBuildId "manual"
#endif
#define RuntimeRoot "{localappdata}\CassotisIme"
#define InstallRuntimeDir "{app}\runtime\" + AppVersion + "_" + RuntimeBuildId

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
UninstallDisplayIcon={#InstallRuntimeDir}\cassotis_ime_tray_host.exe
CloseApplications=no
RestartApplications=no
SetupLogging=yes
SetupMutex=Local\CassotisIme.Setup.Upgrade

[Languages]
Name: "chs"; MessagesFile: "compiler:ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{localappdata}\CassotisIme"
Name: "{localappdata}\CassotisIme\data"
Name: "{localappdata}\CassotisIme\logs"

[InstallDelete]
; The short-word context model (rbt3) is no longer shipped; drop its notices on upgrade.
Type: filesandordirs; Name: "{app}\licenses\rbt3"
; The MacBERT-derived local repair model is replaced by the pinyin-conditioned LM.
Type: filesandordirs; Name: "{app}\licenses\macbert"

[Files]
Source: "{#RuntimeDir}\cassotis_ime_host.exe"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\cassotis_ime_tray_host.exe"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\cassotis_ime_svr.dll"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\cassotis_ime_svr32.dll"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\cassotis_ime_svr.dll"; Flags: dontcopy
Source: "{#RuntimeDir}\cassotis_ime_svr32.dll"; Flags: dontcopy
Source: "{#RuntimeDir}\cassotis_ime_profile_reg.exe"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\cassotis_ime_profile_reg.exe"; Flags: dontcopy
Source: "{#RuntimeDir}\sqlite3_64.dll"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\cassotis_pinyin_transformer_ort.dll"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\onnxruntime.dll"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\onnxruntime_providers_shared.dll"; DestDir: "{#InstallRuntimeDir}"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\char_lm\char_lm.onnx"; DestDir: "{#InstallRuntimeDir}\char_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\char_lm\char_lm_vocab.bin"; DestDir: "{#InstallRuntimeDir}\char_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\char_lm\runtime_manifest.json"; DestDir: "{#InstallRuntimeDir}\char_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\pinyin_lm\char_lm.onnx"; DestDir: "{#InstallRuntimeDir}\pinyin_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\pinyin_lm\char_lm_vocab.bin"; DestDir: "{#InstallRuntimeDir}\pinyin_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\pinyin_lm\pinyin_readings.json"; DestDir: "{#InstallRuntimeDir}\pinyin_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#RuntimeDir}\pinyin_lm\runtime_manifest.json"; DestDir: "{#InstallRuntimeDir}\pinyin_lm"; Flags: ignoreversion onlyifdoesntexist
Source: "{#SourceRoot}\third_party\onnxruntime\LICENSE"; DestDir: "{app}\licenses\onnxruntime"; Flags: ignoreversion
Source: "{#SourceRoot}\third_party\onnxruntime\ThirdPartyNotices.txt"; DestDir: "{app}\licenses\onnxruntime"; Flags: ignoreversion

Source: "{#RuntimeDataSourceDir}\dict_sc.db"; DestDir: "{localappdata}\CassotisIme\data"; DestName: "dict_sc.db"; Flags: ignoreversion; BeforeInstall: BeforeDictionaryInstall
Source: "{#RuntimeDataSourceDir}\dict_tc.db"; DestDir: "{localappdata}\CassotisIme\data"; DestName: "dict_tc.db"; Flags: ignoreversion; BeforeInstall: BeforeDictionaryInstall
[Run]
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "register_tsf -dll_path ""{#InstallRuntimeDir}\cassotis_ime_svr.dll"" -skip_profile"; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Registering Cassotis IME components..."
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "register"; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Registering Cassotis IME profile..."
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "start -restart -ctfmon_only"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    StatusMsg: "Preparing text service session..."
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "register"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    StatusMsg: "Registering Cassotis IME profile for current user..."
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "start -restart"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    BeforeInstall: ReleaseRuntimeUpgradeGuards; \
    StatusMsg: "Starting Cassotis IME..."
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "start"; \
    Flags: runhidden waituntilterminated runasoriginaluser; \
    AfterInstall: RestartTsfShellApplications; \
    StatusMsg: "Verifying Cassotis IME runtime..."
Filename: "{sys}\cmd.exe"; \
    Parameters: "/c start """" explorer.exe"; \
    Flags: runhidden nowait runasoriginaluser; \
    Check: ShouldRestartExplorer; \
    StatusMsg: "Restarting Windows shell..."

[UninstallRun]
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "force_stop_runtime -runtime_dir ""{#InstallRuntimeDir}"" -data_dir ""{localappdata}\CassotisIme\data"" -exclude_pid ""{code:GetCurrentProcessIdText}"""; \
    Flags: runhidden waituntilterminated skipifdoesntexist; \
    RunOnceId: "StopTSF"
Filename: "{#InstallRuntimeDir}\cassotis_ime_profile_reg.exe"; \
    Parameters: "unregister_tsf -dll_path ""{#InstallRuntimeDir}\cassotis_ime_svr.dll"""; \
    Flags: runhidden waituntilterminated skipifdoesntexist; \
    RunOnceId: "UnregisterTSF"

[CustomMessages]
chs.PreparingStopRuntime=正在停止旧版本输入法...
chs.PreparingUnregisterRuntime=正在停用旧版本输入法组件...
chs.PreparingForceCloseRuntime=正在关闭占用旧版本文件的程序...
chs.PreparingWaitRuntime=正在等待旧版本文件释放...
chs.RuntimeReleaseFailed=词库文件仍被占用，无法继续安装。请关闭占用文件的程序后重试。
chs.RuntimeReleaseLockedFile=仍被占用的文件：
chs.RuntimeReleaseProcesses=检测到的相关进程：
chs.RuntimeGuardFailed=无法建立安装期间的后台启动保护，安装已停止。请关闭其他安装程序后重试。
chs.RuntimePreparationFailed=安装准备失败，尚未开始复制文件。请重试；若问题仍然出现，请将安装日志提供给开发者。
chs.RuntimeReleaseRetry=请关闭占用文件的程序后选择“重试”，或选择“取消”中止安装；不会跳过词库更新。
chs.ForceCloseRuntimePrompt=为完成升级安装，安装程序将自动关闭以下正在占用旧版本文件的进程：
chs.ForceCloseRuntimeContinue=点击“确定”继续，点击“取消”中止安装。
chs.ForceCloseRuntimeCanceled=用户取消了升级安装。
chs.TsfUpgradeTitle=部分应用需要重启后才能使用新版输入组件
chs.TsfUpgradeBefore=以下应用仍加载着与新版不同的输入组件。请先保存工作并完整退出这些应用，再选择“重新检查”；也可以稍后重启应用并继续安装。安装程序不会强制关闭这些应用。
chs.TsfUpgradeAfter=新版已安装，但以下应用中的输入组件修复尚未生效。请保存工作并完整退出应用后重新打开；仅关闭窗口可能仍有后台进程。也可注销 Windows 后重新登录。
chs.TsfUpgradeIncomplete=未能完整核实所有相关进程。为确保新版修复生效，请重启使用过输入法的应用，或保存工作后注销 Windows 再登录。
chs.TsfUpgradeUnverified=以下进程无法检查是否仍在使用旧版输入组件（可能受系统或安全软件保护）。它们不一定需要重启；如果输入法在其中某个应用里表现异常，请完整退出并重新打开该应用，或注销 Windows 后重新登录：
chs.TsfUpgradeUnverifiedFinished=安装完成。少数进程未能核实是否已使用新版输入组件，详见下方说明。
chs.TsfUpgradeRecheck=重新检查
chs.TsfUpgradeLater=稍后重启应用，继续安装
chs.TsfUpgradeFinished=安装完成，部分应用仍需重启。相关修复将在这些应用完整退出并重新打开后生效。
chs.TsfUpgradeMore=其余进程见安装日志；安装完成页将再次列出仍需重启的应用。
chs.TsfRestartShell=正在更新 Windows 桌面与搜索组件，任务栏可能短暂消失...
chs.TsfDesktopRecovery=桌面或任务栏尚未确认恢复。可按 Ctrl+Shift+Esc 打开任务管理器，选择“运行新任务”，输入 explorer.exe（不要勾选管理员权限）；若仍未恢复，请保存工作后注销 Windows 并重新登录。
english.PreparingStopRuntime=Stopping existing Cassotis IME runtime...
english.PreparingUnregisterRuntime=Disabling existing Cassotis IME components...
english.PreparingForceCloseRuntime=Closing applications still using existing runtime files...
english.PreparingWaitRuntime=Waiting for existing runtime files to be released...
english.RuntimeReleaseFailed=Dictionary files are still in use. Close the application using them and try again.
english.RuntimeReleaseLockedFile=File still in use:
english.RuntimeReleaseProcesses=Related processes detected:
english.RuntimeGuardFailed=Setup could not prevent the old runtime from restarting. Close other installers and try again.
english.RuntimePreparationFailed=Setup preparation failed. No files have been installed. Retry, or send the Setup log to the developer if the problem persists.
english.RuntimeReleaseRetry=Close the application using this file and choose Retry, or choose Cancel to abort Setup. Dictionary updates will not be skipped.
english.ForceCloseRuntimePrompt=To continue the upgrade, Setup will automatically close the following processes that are still using existing runtime files:
english.ForceCloseRuntimeContinue=Click OK to continue, or Cancel to abort Setup.
english.ForceCloseRuntimeCanceled=Upgrade canceled by user.
english.TsfUpgradeTitle=Some applications need restarting to use the new text service
english.TsfUpgradeBefore=These applications still have different text service code loaded. Save your work, fully exit them and choose Recheck, or continue and restart them later. Setup will not force-close these applications.
english.TsfUpgradeAfter=The new version is installed, but its text service fixes are not yet active in these applications. Save your work, fully exit and reopen them; closing a window may leave a background process running. Alternatively, sign out of Windows and sign back in.
english.TsfUpgradeIncomplete=Some related processes could not be fully verified. Restart applications that have used the input method, or save your work and sign out of Windows, to ensure the new fixes take effect.
english.TsfUpgradeUnverified=Setup could not check whether these processes still use the previous text service (they may be protected by Windows or security software). They do not necessarily need restarting; if the input method misbehaves in one of them, fully exit and reopen it, or sign out of Windows and sign back in:
english.TsfUpgradeUnverifiedFinished=Installation complete. A few processes could not be verified as using the new text service; see the note below.
english.TsfUpgradeRecheck=Recheck
english.TsfUpgradeLater=Restart applications later and continue
english.TsfUpgradeFinished=Installation complete. Some applications still need restarting before the updated text service fixes take effect.
english.TsfUpgradeMore=Additional processes are listed in the Setup log. The finished page will recheck and list applications that still need restarting.
english.TsfRestartShell=Updating the Windows desktop and Search. The taskbar may briefly disappear...
english.TsfDesktopRecovery=The desktop or taskbar has not been verified as restored. Press Ctrl+Shift+Esc, choose Run new task, and enter explorer.exe without administrative privileges. If it still does not recover, save your work and sign out of Windows, then sign back in.

[Code]
#include "runtime_upgrade_guard.iss"
#include "tsf_upgrade_notice.iss"

const
    c_runtime_unlock_wait_attempts = 40;
    c_runtime_unlock_wait_ms = 250;
    c_disable_ime_for_all_process_threads = $FFFFFFFF;
    c_tsf_inproc_registry_path = 'Software\Classes\CLSID\{38D40A05-DCDB-49FB-81A4-C8745882DC21}\InprocServer32';

var
    RuntimePrepPage: TOutputProgressWizardPage;
    InstallerProfileRegPath: string;
    ForceStopTargetsPath: string;
    ForceStopApprovalGranted: Boolean;
    ExplorerRestartNeeded: Boolean;
    PreparedRuntimeDir: string;
    LastRuntimeFileError: Cardinal;
    TsfIncomingExtracted: Boolean;
    TsfUpgradeFinalized: Boolean;
    TsfShellRestartFailed: Boolean;
    TsfDesktopRecoveryRequired: Boolean;
    TsfFinishedMemo: TNewMemo;
    TsfRecheckButton: TNewButton;
    TsfOriginalFinishedText: string;

function GetCurrentProcessId: DWORD;
external 'GetCurrentProcessId@kernel32.dll stdcall';
function ProcessIdToSessionId(ProcessId: DWORD; out SessionId: DWORD): Boolean;
external 'ProcessIdToSessionId@kernel32.dll stdcall';
function ImmDisableIME(ThreadId: DWORD): Boolean;
external 'ImmDisableIME@imm32.dll stdcall';

function GetCurrentProcessIdText(const Param: string): string;
begin
    Result := IntToStr(Integer(GetCurrentProcessId));
end;

function InitializeSetup: Boolean;
begin
    { Inno Setup is a 32-bit process. Disable text services before the wizard
      creates edit controls, otherwise the installed 32-bit TSF DLL can be
      loaded into Setup itself and can never be replaced by that process. }
    if ImmDisableIME(c_disable_ime_for_all_process_threads) then
    begin
        Log('Disabled IME loading in the Setup process before creating the wizard.');
    end
    else
    begin
        Log('ImmDisableIME did not disable IME loading in the Setup process.');
    end;
    Result := True;
end;

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
    PreparedRuntimeDir := '';
    LastRuntimeFileError := 0;
    TsfIncomingExtracted := False;
    TsfUpgradeFinalized := False;
    TsfUpgradeScanComplete := False;
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

procedure ScanTsfUpgradeApplications;
var
    ProfileRegPath, ReportPath: string;
    ResultCode: Integer;
    Lines: TArrayOfString;
begin
    SetArrayLength(Lines, 0);
    ReadTsfUpgradeReport(Lines);
    try
        ProfileRegPath := GetInstallerProfileRegPath;
        if not TsfIncomingExtracted then
        begin
            ExtractTemporaryFile('cassotis_ime_svr.dll');
            ExtractTemporaryFile('cassotis_ime_svr32.dll');
            TsfIncomingExtracted := True;
        end;
        ReportPath := ExpandConstant('{tmp}\cassotis_tsf_upgrade_report.txt');
        DeleteFile(ReportPath);
        if Exec(ProfileRegPath,
            'list_stale_tsf_holders -new_runtime_dir "' + ExpandConstant('{tmp}') +
            '" -output_path "' + ReportPath + '" -exclude_pid "' +
            GetCurrentProcessIdText('') + '"', '', SW_HIDE, ewWaitUntilTerminated,
            ResultCode) and (ResultCode = 0) then
        begin
            if LoadStringsFromFile(ReportPath, Lines) then
                ReadTsfUpgradeReport(Lines);
        end;
    except
        Log('TSF upgrade scan failed: ' + GetExceptionMessage);
    end;
    Log('TSF upgrade scan complete=' + IntToStr(Ord(TsfUpgradeScanComplete)) + #13#10 +
        TsfUpgradeApplications);
    if TsfUpgradeUnverified <> '' then
        Log('TSF upgrade scan could not check:' + #13#10 + TsfUpgradeUnverified);
end;

function GetTsfManualRestartApplications: string;
var
    PlanPath: string;
    Plan: TArrayOfString;
    ResultCode, Index: Integer;
begin
    Result := TsfUpgradeApplications;
    try
        PlanPath := ExpandConstant('{tmp}\cassotis_tsf_shell_plan.txt');
        DeleteFile(PlanPath);
        { Plan as the desktop owner, not the elevated installer account. }
        if ExecAsOriginalUser(GetInstallerProfileRegPath,
            'list_stale_shell_holders -new_runtime_dir "' + ExpandConstant('{tmp}') +
            '" -output_path "' + PlanPath + '"', '', SW_HIDE, ewWaitUntilTerminated,
            ResultCode) and (ResultCode = 0) then
        begin
            if LoadStringsFromFile(PlanPath, Plan) then
            begin
                for Index := 0 to GetArrayLength(Plan) - 1 do
                    Log('TSF shell plan: ' + Plan[Index]);
                Result := TsfManualRestartApplications(Plan);
            end
            else
                Log('TSF shell plan: report not readable: ' + PlanPath);
        end
        else
            Log('TSF shell plan: helper failed, code=' + IntToStr(ResultCode));
    except
        Log('Could not plan automatic shell restart: ' + GetExceptionMessage);
    end;
end;

function ConfirmTsfApplicationRestart: Boolean;
var
    Choice, Index: Integer;
    Text, ManualApplications: string;
    Lines: TStringList;
begin
    Result := False;
    while True do
    begin
        ScanTsfUpgradeApplications;
        ManualApplications := GetTsfManualRestartApplications;
        if ManualApplications = '' then
        begin
            { System shell targets are handled after registration. Any incomplete
              scan is still reported on the finished page, never called clean. }
            Log('No verified applications require a manual pre-install restart.');
            Result := True;
            Exit;
        end;
        if WizardSilent then
        begin
            Log(TsfUpgradeNoticeText(CustomMessage('TsfUpgradeAfter'),
                CustomMessage('TsfUpgradeIncomplete'), CustomMessage('TsfUpgradeUnverified')));
            Result := True;
            Exit;
        end;
        HidePreparingStatus;
        Text := CustomMessage('TsfUpgradeBefore');
        if not TsfUpgradeScanComplete then
            Text := Text + #13#10#13#10 + CustomMessage('TsfUpgradeIncomplete');
        Lines := TStringList.Create;
        try
            Lines.Text := ManualApplications;
            for Index := 0 to Lines.Count - 1 do
            begin
                if Index >= 12 then
                begin
                    Text := Text + #13#10 + CustomMessage('TsfUpgradeMore');
                    Break;
                end;
                Text := Text + #13#10 + Lines[Index];
            end;
        finally
            Lines.Free;
        end;
        Choice := ShowTsfUpgradeRestartDialog(CustomMessage('TsfUpgradeTitle'), Text,
            CustomMessage('TsfUpgradeRecheck'), CustomMessage('TsfUpgradeLater'));
        case Choice of
            IDYES: Continue;
            IDNO:
                begin
                    Log('User deferred restarting applications with old TSF modules.');
                    Result := True;
                    Exit;
                end;
        else
            Exit;
        end;
    end;
end;

procedure UpdateTsfFinishedNotice;
begin
    if TsfFinishedMemo = nil then
        Exit;
    TsfFinishedMemo.Visible := TsfUpgradeNoticeRequired;
    { An empty list with a Recheck button reads as an unfinished demand. }
    TsfRecheckButton.Visible := TsfUpgradeNoticeListsProcesses;
    if TsfUpgradeNoticeRequired then
    begin
        if TsfUpgradeApplications <> '' then
            WizardForm.FinishedLabel.Caption := CustomMessage('TsfUpgradeFinished')
        else
            WizardForm.FinishedLabel.Caption := CustomMessage('TsfUpgradeUnverifiedFinished');
        TsfFinishedMemo.Text := TsfUpgradeNoticeText(CustomMessage('TsfUpgradeAfter'),
            CustomMessage('TsfUpgradeIncomplete'), CustomMessage('TsfUpgradeUnverified'));
        if TsfDesktopRecoveryRequired then
            TsfFinishedMemo.Text := TsfFinishedMemo.Text + #13#10#13#10 +
                CustomMessage('TsfDesktopRecovery');
    end
    else
        WizardForm.FinishedLabel.Caption := TsfOriginalFinishedText;
end;

procedure RecheckTsfApplications(Sender: TObject);
begin
    TsfRecheckButton.Enabled := False;
    try
        ScanTsfUpgradeApplications;
        UpdateTsfFinishedNotice;
    finally
        TsfRecheckButton.Enabled := True;
    end;
end;

procedure FinalizeTsfUpgradeNotice;
begin
    { Inspect again: applications may have survived or started during extraction. }
    ScanTsfUpgradeApplications;
    if TsfShellRestartFailed then
        TsfUpgradeScanComplete := False;
    TsfUpgradeFinalized := True;
    if TsfUpgradeNoticeRequired then
        Log(TsfUpgradeNoticeText(CustomMessage('TsfUpgradeAfter'),
            CustomMessage('TsfUpgradeIncomplete'), CustomMessage('TsfUpgradeUnverified')));
end;

procedure RestartTsfShellApplications;
var
    RuntimeDir, ReportPath: string;
    Lines: TArrayOfString;
    ResultCode, Index: Integer;
begin
    TsfShellRestartFailed := True;
    TsfDesktopRecoveryRequired := False;
    WizardForm.StatusLabel.Caption := CustomMessage('TsfRestartShell');
    try
        RuntimeDir := ExpandConstant('{#InstallRuntimeDir}');
        ReportPath := ExpandConstant('{tmp}\cassotis_tsf_shell_result.txt');
        DeleteFile(ReportPath);
        { Called only after the new components are registered and host started.
          The helper revalidates registration and live process identities. }
        if ExecAsOriginalUser(AddBackslash(RuntimeDir) + 'cassotis_ime_profile_reg.exe',
            'restart_stale_shell_holders -new_runtime_dir "' + RuntimeDir +
            '" -output_path "' + ReportPath + '"', '', SW_HIDE, ewWaitUntilTerminated,
            ResultCode) and (ResultCode = 0) then
        begin
            if LoadStringsFromFile(ReportPath, Lines) then
            begin
                if GetArrayLength(Lines) >= 2 then
                    TsfShellRestartFailed := (Lines[0] <> 'cassotis_tsf_shell_result_v1') or
                        (Lines[1] <> 'complete=1');
                for Index := 0 to GetArrayLength(Lines) - 1 do
                begin
                    Log(Lines[Index]);
                    if Lines[Index] = 'desktop_recovery_required=1' then
                        TsfDesktopRecoveryRequired := True;
                end;
            end;
        end;
    except
        Log('Automatic shell restart failed: ' + GetExceptionMessage);
    end;
    FinalizeTsfUpgradeNotice;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
    if CurPageID <> wpFinished then
        Exit;
    if not TsfUpgradeFinalized then
        FinalizeTsfUpgradeNotice;
    if TsfFinishedMemo = nil then
    begin
        TsfOriginalFinishedText := WizardForm.FinishedLabel.Caption;
        TsfFinishedMemo := TNewMemo.Create(WizardForm);
        TsfFinishedMemo.Parent := WizardForm.FinishedPage;
        TsfFinishedMemo.Left := WizardForm.FinishedLabel.Left;
        TsfFinishedMemo.Top := WizardForm.FinishedLabel.Top + ScaleY(72);
        TsfFinishedMemo.Width := WizardForm.FinishedLabel.Width;
        TsfFinishedMemo.Height := WizardForm.FinishedPage.ClientHeight -
            TsfFinishedMemo.Top - ScaleY(40);
        TsfFinishedMemo.ReadOnly := True;
        TsfFinishedMemo.ScrollBars := ssVertical;
        TsfRecheckButton := TNewButton.Create(WizardForm);
        TsfRecheckButton.Parent := WizardForm.FinishedPage;
        TsfRecheckButton.Left := TsfFinishedMemo.Left;
        TsfRecheckButton.Top := TsfFinishedMemo.Top + TsfFinishedMemo.Height + ScaleY(6);
        TsfRecheckButton.Width := ScaleX(150);
        TsfRecheckButton.Height := ScaleY(25);
        TsfRecheckButton.Caption := CustomMessage('TsfUpgradeRecheck');
        TsfRecheckButton.OnClick := @RecheckTsfApplications;
    end;
    UpdateTsfFinishedNotice;
end;

function GetForceStopTargetsText(const RuntimeDir: string; const ExcludeInstaller: Boolean): string;
var
    ProfileRegPath: string;
    ResultCode: Integer;
    LoadedLines: TArrayOfString;
    Index: Integer;
    InstallerPid: DWORD;
    Arguments: string;
begin
    Result := '';
    ProfileRegPath := GetInstallerProfileRegPath;
    InstallerPid := GetCurrentProcessId;
    Arguments :=
        'list_force_stop_targets -runtime_dir "' + RuntimeDir + '" -data_dir "' + GetRuntimeDataDir +
        '" -output_path "' + ForceStopTargetsPath + '" -skip_dll_holders';
    if ExcludeInstaller then
    begin
        Arguments := Arguments + ' -exclude_pid "' + IntToStr(Integer(InstallerPid)) + '"';
    end;
    DeleteFile(ForceStopTargetsPath);
    if not Exec(
        ProfileRegPath,
        Arguments,
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

    TargetsText := GetForceStopTargetsText(RuntimeDir, True);
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

function RuntimeFilesReleased(const RuntimeDir: string; out LockedFile: string): Boolean;
begin
    { Runtime binaries are installed side by side and are never overwritten.
      Only the shared dictionary snapshots still require exclusive replacement. }
    Result := RuntimeDictionariesReleased(GetRuntimeDataDir, LockedFile, LastRuntimeFileError);
end;

function NormalizeRegisteredDllPath(const Value: string): string;
begin
    Result := Trim(Value);
    if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    begin
        Result := Copy(Result, 2, Length(Result) - 2);
    end;
end;

function GetRegisteredRuntimeDir: string;
var
    RegisteredDllPath: string;
begin
    Result := '';
    RegisteredDllPath := '';
    if not RegQueryStringValue(HKLM64, c_tsf_inproc_registry_path, '', RegisteredDllPath) then
    begin
        if not RegQueryStringValue(HKCU64, c_tsf_inproc_registry_path, '', RegisteredDllPath) then
        begin
            if not RegQueryStringValue(HKLM32, c_tsf_inproc_registry_path, '', RegisteredDllPath) then
            begin
                RegQueryStringValue(HKCU32, c_tsf_inproc_registry_path, '', RegisteredDllPath);
            end;
        end;
    end;

    RegisteredDllPath := NormalizeRegisteredDllPath(RegisteredDllPath);
    if RegisteredDllPath = '' then
    begin
        Log('No existing Cassotis IME COM server path was found in the registry.');
        Exit;
    end;

    Result := ExtractFileDir(RegisteredDllPath);
    Log(Format('Registered Cassotis IME runtime detected: %s', [Result]));
end;

function GetLongPathNameW(ShortPath: string; LongPath: string; Capacity: DWORD): DWORD;
external 'GetLongPathNameW@kernel32.dll stdcall';

function LongPathOf(const Path: string): string;
var
    Buffer: string;
    Length_: DWORD;
begin
    { The COM registration may hold an 8.3 alias of the runtime directory. }
    Result := RemoveBackslashUnlessRoot(Path);
    Buffer := StringOfChar(#0, 1024);
    Length_ := GetLongPathNameW(Result, Buffer, 1024);
    if (Length_ > 0) and (Length_ < 1024) then
    begin
        Result := Copy(Buffer, 1, Length_);
    end;
end;

procedure DeleteRetiredRuntime(const Path: string);
begin
    if DelTree(Path, True, True, True) then
    begin
        Log('Removed retired runtime: ' + Path);
    end
    else
    begin
        Log('Retired runtime still in use; kept its locked files until a later install: ' + Path);
    end;
end;

procedure PruneRetiredRuntimes;
var
    CurrentDir: string;
    RuntimeRoot: string;
    AppDir: string;
    FindRec: TFindRec;
    Name: string;
    I: Integer;
begin
    { Only once the new runtime is the registered one: TSF clients then start the
      host from it, so nothing in an earlier runtime (binaries, retired models)
      is used. A DLL still mapped by a running application cannot be deleted
      and is retried on the next install. }
    CurrentDir := LongPathOf(ExpandConstant('{#InstallRuntimeDir}'));
    if CompareText(LongPathOf(GetRegisteredRuntimeDir), CurrentDir) <> 0 then
    begin
        Log('The new runtime is not the registered one; earlier runtimes are kept.');
        Exit;
    end;
    RuntimeRoot := ExpandConstant('{app}\runtime');
    if FindFirst(AddBackslash(RuntimeRoot) + '*', FindRec) then
    begin
        try
            repeat
                if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
                    (FindRec.Name <> '.') and (FindRec.Name <> '..') and
                    (CompareText(LongPathOf(AddBackslash(RuntimeRoot) + FindRec.Name), CurrentDir) <> 0) then
                begin
                    DeleteRetiredRuntime(AddBackslash(RuntimeRoot) + FindRec.Name);
                end;
            until not FindNext(FindRec);
        finally
            FindClose(FindRec);
        end;
    end;
    // Releases before versioned runtimes installed into the app's out folder or the app folder.
    AppDir := ExpandConstant('{app}');
    if DirExists(AddBackslash(AppDir) + 'out') then
    begin
        DeleteRetiredRuntime(AddBackslash(AppDir) + 'out');
    end;
    for I := 0 to 5 do
    begin
        case I of
            0: Name := 'pinyin_transformer';
            1: Name := 'local_repair';
            2: Name := 'local_completion';
            3: Name := 'short_context';
            4: Name := 'char_lm';
        else
            Name := 'pinyin_lm';
        end;
        if DirExists(AddBackslash(AppDir) + Name) then
        begin
            DeleteRetiredRuntime(AddBackslash(AppDir) + Name);
        end;
    end;
    for I := 0 to 11 do
    begin
        case I of
            0: Name := 'cassotis_ime_host.exe';
            1: Name := 'cassotis_ime_tray_host.exe';
            2: Name := 'cassotis_ime_svr.dll';
            3: Name := 'cassotis_ime_svr32.dll';
            4: Name := 'cassotis_ime_profile_reg.exe';
            5: Name := 'sqlite3_64.dll';
            6: Name := 'cassotis_pinyin_transformer_ort.dll';
            7: Name := 'nc_pinyin_transformer_ort.dll';
            8: Name := 'onnxruntime.dll';
            9: Name := 'onnxruntime_providers_shared.dll';
            10: Name := 'cassotis_onnxruntime.dll';
        else
            Name := 'cassotis_onnxruntime_providers_shared.dll';
        end;
        if FileExists(AddBackslash(AppDir) + Name) and
            not DeleteFile(AddBackslash(AppDir) + Name) then
        begin
            Log('Retired runtime file still in use: ' + AddBackslash(AppDir) + Name);
        end;
    end;
end;

function RuntimeDirHasManagedFiles(const RuntimeDir: string): Boolean;
begin
    if RuntimeDir = '' then
    begin
        Result := False;
        Exit;
    end;
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
    InstallerPid: DWORD;
begin
    UpdatePreparingStatus(
        ExpandConstant('{cm:PreparingForceCloseRuntime}'),
        RuntimeDir,
        0,
        0
    );

    ProfileRegPath := GetInstallerProfileRegPath;
    InstallerPid := GetCurrentProcessId;
    Log('Running installer-side force-stop pass for processes using IME runtime files.');
    if Exec(
        ProfileRegPath,
        'force_stop_runtime -runtime_dir "' + RuntimeDir + '" -data_dir "' + GetRuntimeDataDir +
            '" -exclude_pid "' + IntToStr(Integer(InstallerPid)) + '" -skip_dll_holders',
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

function WaitForRuntimeRelease(const RuntimeDir: string; out LastLockedFile: string): Boolean;
var
    Attempt: Integer;
    LockedFile: string;
begin
    Result := True;
    LastLockedFile := '';

    for Attempt := 1 to c_runtime_unlock_wait_attempts do
    begin
        if (Attempt = 1) or ((Attempt mod 4) = 0) then
        begin
            UpdatePreparingStatus(
                ExpandConstant('{cm:PreparingWaitRuntime}'),
                GetRuntimeDataDir + ' (' + IntToStr(Attempt) + '/' + IntToStr(c_runtime_unlock_wait_attempts) + ')',
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
        LastLockedFile := LockedFile;
        if (Attempt = 1) or ((Attempt mod 4) = 0) then
        begin
            Log(Format('Waiting for locked file to be released: %s (error %d)', [LockedFile, LastRuntimeFileError]));
        end;
        Sleep(c_runtime_unlock_wait_ms);
    end;

    Log(Format('Runtime files still locked after waiting: %s (%s)', [RuntimeDir, LockedFile]));
    Result := False;
end;

function RuntimeReleaseFailureText(const RuntimeDir, LockedFile: string): string;
var
    TargetsText: string;
begin
    Result := ExpandConstant('{cm:RuntimeReleaseFailed}');
    if LockedFile <> '' then
    begin
        Result := Result + #13#10#13#10 +
            ExpandConstant('{cm:RuntimeReleaseLockedFile}') + #13#10 + LockedFile + #13#10 +
            Format('Windows error %d: %s', [LastRuntimeFileError, SysErrorMessage(LastRuntimeFileError)]);
    end;
    TargetsText := GetForceStopTargetsText(RuntimeDir, False);
    if TargetsText <> '' then
    begin
        Result := Result + #13#10#13#10 +
            ExpandConstant('{cm:RuntimeReleaseProcesses}') + #13#10 + TargetsText;
    end;
    Log('Runtime release failure details:' + #13#10 + Result);
end;

procedure BeforeDictionaryInstall;
var
    LockedFile: string;
    FailureText: string;
begin
    if not RuntimeUpgradeGuardsHeld then
    begin
        RaiseException(ExpandConstant('{cm:RuntimeGuardFailed}'));
    end;
    Log('Rechecking dictionary replacement immediately before copying: ' + CurrentFileName);
    try
        while not WaitForRuntimeRelease(PreparedRuntimeDir, LockedFile) do
        begin
            HidePreparingStatus;
            FailureText := RuntimeReleaseFailureText(PreparedRuntimeDir, LockedFile);
            if WizardSilent then
            begin
                RaiseException(FailureText);
            end;
            { A newly arrived holder was not in the original approval dialog.
              Do not silently terminate it or offer to skip either dictionary. }
            if MsgBox(FailureText + #13#10#13#10 +
                ExpandConstant('{cm:RuntimeReleaseRetry}'), mbError,
                MB_RETRYCANCEL or MB_DEFBUTTON2) <> IDRETRY then
            begin
                RaiseException(FailureText);
            end;
        end;
    finally
        HidePreparingStatus;
    end;
end;

function PrepareRuntimeForInstall: String;
var
    RootRuntimeDir: string;
    LegacyRuntimeDir: string;
    ActiveRuntimeDir: string;
    RegisteredRuntimeDir: string;
    LockedFile: string;
    SessionId: DWORD;
    ErrorCode: Cardinal;
begin
    Result := CustomMessage('RuntimePreparationFailed');
    ForceStopApprovalGranted := False;
    Log('Versioned runtime destination: ' + ExpandConstant('{#InstallRuntimeDir}'));
    RootRuntimeDir := ExpandConstant('{app}');
    LegacyRuntimeDir := ExpandConstant('{app}\out');
    ActiveRuntimeDir := '';
    RegisteredRuntimeDir := GetRegisteredRuntimeDir;
    if RuntimeDirHasManagedFiles(RegisteredRuntimeDir) then
    begin
        ActiveRuntimeDir := RegisteredRuntimeDir;
    end
    else if RuntimeDirHasManagedFiles(RootRuntimeDir) then
    begin
        ActiveRuntimeDir := RootRuntimeDir;
    end
    else if (CompareText(LegacyRuntimeDir, RootRuntimeDir) <> 0) and RuntimeDirHasManagedFiles(LegacyRuntimeDir) then
    begin
        ActiveRuntimeDir := LegacyRuntimeDir;
    end;

    PreparedRuntimeDir := ActiveRuntimeDir;
    SessionId := 0;
    if not ProcessIdToSessionId(GetCurrentProcessId, SessionId) then
    begin
        ErrorCode := DLLGetLastError;
        Result := ExpandConstant('{cm:RuntimeGuardFailed}') + #13#10 + SysErrorMessage(ErrorCode);
        Exit;
    end;
    { These names match the existing host, tray and TSF client. Holding a
      reference before stopping them also protects upgrades from older builds. }
    if not AcquireRuntimeUpgradeGuards(
        Format('Local\cassotis_ime_engine_host_v2_s%d', [SessionId]),
        Format('Local\cassotis_ime_tray_host_v1_s%d', [SessionId]), ErrorCode) then
    begin
        Result := ExpandConstant('{cm:RuntimeGuardFailed}') + #13#10 + SysErrorMessage(ErrorCode);
        Exit;
    end;
    UpdatePreparingStatus(
        ExpandConstant('{cm:PreparingStopRuntime}'),
        GetRuntimeDataDir,
        0,
        0
    );
    if (ActiveRuntimeDir <> '') or
        FileExists(AddBackslash(GetRuntimeDataDir) + 'dict_sc.db') or
        FileExists(AddBackslash(GetRuntimeDataDir) + 'dict_tc.db') then
    begin
        if not ConfirmForceStopProcesses(ActiveRuntimeDir) then
        begin
            Result := ExpandConstant('{cm:ForceCloseRuntimeCanceled}');
            Exit;
        end;
        { Keep the old registration intact until the new files are installed.
          Singleton guards prevent old hosts restarting, even with old DLLs. }
        TryForceStopProcessesUsingImeModules(ActiveRuntimeDir);
    end;
    if not WaitForRuntimeRelease(ActiveRuntimeDir, LockedFile) then
    begin
        Result := RuntimeReleaseFailureText(ActiveRuntimeDir, LockedFile);
        Exit;
    end;
    if not ConfirmTsfApplicationRestart then
    begin
        Result := ExpandConstant('{cm:ForceCloseRuntimeCanceled}');
        Exit;
    end;
    Result := '';
end;

#include "runtime_prepare.iss"

procedure CurStepChanged(CurStep: TSetupStep);
begin
    { ssDone follows the [Run] registration and verification steps. }
    if CurStep = ssDone then
    begin
        PruneRetiredRuntimes;
    end;
end;

procedure DeinitializeSetup;
begin
    { Also runs on cancellation/failure. Abrupt process exit closes handles too. }
    ReleaseRuntimeUpgradeGuards;
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
