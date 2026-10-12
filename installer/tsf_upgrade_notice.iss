var
    TsfUpgradeApplications: string;
    // Processes the scan could not check. They are never restart targets, but
    // name what the incomplete-scan warning refers to.
    TsfUpgradeUnverified: string;
    TsfUpgradeScanComplete: Boolean;

procedure AppendTsfUpgradeRow(var Rows: string; const Row: string);
begin
    if Rows <> '' then
        Rows := Rows + #13#10;
    Rows := Rows + Row;
end;

procedure ReadTsfUpgradeReport(const Lines: TArrayOfString);
var
    Index: Integer;
    Row: string;
begin
    TsfUpgradeApplications := '';
    TsfUpgradeUnverified := '';
    TsfUpgradeScanComplete := False;
    if GetArrayLength(Lines) < 2 then
        Exit;
    if (Lines[0] <> 'cassotis_tsf_upgrade_report_v1') or
        ((Lines[1] <> 'complete=0') and (Lines[1] <> 'complete=1')) then
        Exit;
    TsfUpgradeScanComplete := Lines[1] = 'complete=1';
    for Index := 2 to GetArrayLength(Lines) - 1 do
    begin
        Row := Trim(Lines[Index]);
        if Row = '' then
            Continue;
        if Pos('unverified=', Row) = 1 then
            AppendTsfUpgradeRow(TsfUpgradeUnverified, Copy(Row, 12, Length(Row) - 11))
        else
            AppendTsfUpgradeRow(TsfUpgradeApplications, Row);
    end;
end;

function TsfManualRestartApplications(const Plan: TArrayOfString): string;
var
    Applications: TStringList;
    Index, PlanIndex: Integer;
    Automatic: Boolean;
    Row: string;
begin
    Result := TsfUpgradeApplications;
    if GetArrayLength(Plan) < 2 then
        Exit;
    if (Plan[0] <> 'cassotis_tsf_shell_plan_v2') or
        ((Plan[1] <> 'complete=0') and (Plan[1] <> 'complete=1')) then
        Exit;
    { Each auto= entry has passed its own identity and DLL checks. A partial
      scan of a different process must not turn it into a manual-close target. }
    Result := '';
    Applications := TStringList.Create;
    try
        Applications.Text := TsfUpgradeApplications;
        for Index := 0 to Applications.Count - 1 do
        begin
            Row := Applications[Index];
            Automatic := False;
            { Search is SearchHost.exe on Windows 11 and SearchApp.exe on Windows 10. }
            if (Pos('explorer.exe (pid ', LowerCase(Row)) = 1) or
                (Pos('searchhost.exe (pid ', LowerCase(Row)) = 1) or
                (Pos('searchapp.exe (pid ', LowerCase(Row)) = 1) then
                for PlanIndex := 2 to GetArrayLength(Plan) - 1 do
                    if CompareText('auto=' + Row, Plan[PlanIndex]) = 0 then
                        Automatic := True;
            if not Automatic then
            begin
                if Result <> '' then
                    Result := Result + #13#10;
                Result := Result + Row;
            end;
        end;
    finally
        Applications.Free;
    end;
end;

function TsfUpgradeNoticeRequired: Boolean;
begin
    Result := (not TsfUpgradeScanComplete) or (TsfUpgradeApplications <> '');
end;

{ Recheck only helps when the notice lists something that can change. }
function TsfUpgradeNoticeListsProcesses: Boolean;
begin
    Result := TsfUpgradeNoticeRequired and
        ((TsfUpgradeApplications <> '') or (TsfUpgradeUnverified <> ''));
end;

{ RestartText introduces a list of applications to restart and is used only
  when there is one. An incomplete scan without restart targets is described
  by UnverifiedText with the unchecked processes, or by IncompleteText when the
  scan could not even name them - never by an empty "following applications". }
function TsfUpgradeNoticeText(const RestartText, IncompleteText, UnverifiedText: string): string;
begin
    Result := '';
    if not TsfUpgradeNoticeRequired then
        Exit;
    if TsfUpgradeApplications <> '' then
    begin
        Result := RestartText + #13#10#13#10 + TsfUpgradeApplications;
        if TsfUpgradeUnverified <> '' then
            Result := Result + #13#10#13#10 + UnverifiedText + #13#10 + TsfUpgradeUnverified
        else if not TsfUpgradeScanComplete then
            Result := Result + #13#10#13#10 + IncompleteText;
    end
    else if TsfUpgradeUnverified <> '' then
        Result := UnverifiedText + #13#10 + TsfUpgradeUnverified
    else
        Result := IncompleteText;
end;

function ShowTsfUpgradeRestartDialog(const Title, Text, RecheckLabel,
    LaterLabel: string): Integer;
begin
    { Older Inno runtimes accept labels for Yes/No only. Leave Cancel native. }
    Result := TaskDialogMsgBox(Title, Text, mbInformation,
        MB_YESNOCANCEL, [RecheckLabel, LaterLabel], 0);
end;
