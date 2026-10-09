{ Files of a runtime that a running application still has open: moved aside
  by an upgrade, left behind by an uninstall. Shared with the test harness
  tests/installer_uninstall_harness.iss. }
{ A NULL new name (0) registers the path for deletion at the next restart. }
function MoveFileExDelete(ExistingName: string; NewName: Cardinal; Flags: DWORD): BOOL;
external 'MoveFileExW@kernel32.dll stdcall';

const
    c_movefile_delay_until_reboot = $4;

var
    RetiredTrashDir: string;
    RetiredTrashCount: Integer;

function RetiredTrashRoot: string;
begin
    Result := ExpandConstant('{app}\runtime-retired');
end;

procedure DeleteAtRestart(const Path: string);
begin
    if MoveFileExDelete(Path, 0, c_movefile_delay_until_reboot) then
    begin
        Log('Scheduled for deletion at the next restart: ' + Path);
    end
    else
    begin
        Log(Format('Could not schedule deletion at restart (error %d): %s', [DLLGetLastError, Path]));
    end;
end;

{ A file still loaded by a running application cannot be deleted, but it can be
  renamed on the same volume. It moves to a per-install directory under
  runtime-retired and only that path is scheduled for deletion at the next
  restart: those paths are never reused, so reinstalling the version that owned
  the file before the restart cannot lose its new copy. A file that cannot be
  moved stays where it is until a later install. }
procedure RetireLockedFile(const Path: string);
var
    Target: string;
begin
    if RetiredTrashDir = '' then
    begin
        RetiredTrashDir := AddBackslash(RetiredTrashRoot) +
            GetDateTimeString('yyyymmddhhnnsszzz', #0, #0);
    end;
    if not ForceDirectories(RetiredTrashDir) then
    begin
        Log('Retired runtime file kept until a later install: ' + Path);
        Exit;
    end;
    RetiredTrashCount := RetiredTrashCount + 1;
    Target := AddBackslash(RetiredTrashDir) + IntToStr(RetiredTrashCount) + '_' + ExtractFileName(Path);
    if RenameFile(Path, Target) then
    begin
        DeleteAtRestart(Target);
    end
    else
    begin
        Log('Retired runtime file kept until a later install: ' + Path);
    end;
end;

procedure RetireLockedTree(const Path: string);
var
    FindRec: TFindRec;
begin
    if FindFirst(AddBackslash(Path) + '*', FindRec) then
    begin
        try
            repeat
                if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
                begin
                    if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
                    begin
                        RetireLockedTree(AddBackslash(Path) + FindRec.Name);
                    end
                    else
                    begin
                        RetireLockedFile(AddBackslash(Path) + FindRec.Name);
                    end;
                end;
            until not FindNext(FindRec);
        finally
            FindClose(FindRec);
        end;
    end;
end;

procedure DeleteRetiredRuntime(const Path: string);
begin
    if DelTree(Path, True, True, True) then
    begin
        Log('Removed retired runtime: ' + Path);
        Exit;
    end;
    { Move the files still in use out of the way; the emptied tree then goes now. }
    Log('Retired runtime partly in use: ' + Path);
    RetireLockedTree(Path);
    if DelTree(Path, True, True, True) then
    begin
        Log('Removed retired runtime: ' + Path);
    end
    else
    begin
        Log('Retired runtime kept until a later install: ' + Path);
    end;
end;

{ Files moved away by an earlier install are gone once Windows restarted; their
  emptied directories (and anything not yet restarted away) are retried here. }
procedure CleanRetiredTrash;
var
    FindRec: TFindRec;
begin
    if not DirExists(RetiredTrashRoot) then
    begin
        Exit;
    end;
    if FindFirst(AddBackslash(RetiredTrashRoot) + '*', FindRec) then
    begin
        try
            repeat
                if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
                    (FindRec.Name <> '.') and (FindRec.Name <> '..') then
                begin
                    DelTree(AddBackslash(RetiredTrashRoot) + FindRec.Name, True, True, True);
                end;
            until not FindNext(FindRec);
        finally
            FindClose(FindRec);
        end;
    end;
    RemoveDir(RetiredTrashRoot);
end;

var
    RuntimeLeftoversChecked: Boolean;
    RuntimeLeftoversInUse: Boolean;

{ An uninstall closes no application, and a text service module stays loaded
  in every application the input method was used in until that application
  exits. What the uninstall therefore could not delete is moved to
  runtime-retired, as an upgrade does, and goes at the next restart. Only the
  moved files are named for it: their paths are never used again, so
  installing again before the restart loses nothing. A directory named for it
  goes only if it is empty by then. }
procedure RemoveRuntimeLeftovers;
var
    RuntimeRoot: string;
    FindRec: TFindRec;
begin
    if RuntimeLeftoversChecked then
    begin
        Exit;
    end;
    RuntimeLeftoversChecked := True;
    RuntimeRoot := ExpandConstant('{app}\runtime');
    if FindFirst(AddBackslash(RuntimeRoot) + '*', FindRec) then
    begin
        try
            repeat
                if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
                    (FindRec.Name <> '.') and (FindRec.Name <> '..') then
                begin
                    DeleteRetiredRuntime(AddBackslash(RuntimeRoot) + FindRec.Name);
                end;
            until not FindNext(FindRec);
        finally
            FindClose(FindRec);
        end;
    end;
    RemoveDir(RuntimeRoot);
    CleanRetiredTrash;
    RuntimeLeftoversInUse := DirExists(RuntimeRoot) or DirExists(RetiredTrashRoot);
    if not RuntimeLeftoversInUse then
    begin
        Exit;
    end;
    Log('Runtime files are still in use; they go at the next restart.');
    if FindFirst(AddBackslash(RetiredTrashRoot) + '*', FindRec) then
    begin
        try
            repeat
                if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
                    (FindRec.Name <> '.') and (FindRec.Name <> '..') then
                begin
                    DeleteAtRestart(AddBackslash(RetiredTrashRoot) + FindRec.Name);
                end;
            until not FindNext(FindRec);
        finally
            FindClose(FindRec);
        end;
    end;
    if DirExists(RetiredTrashRoot) then
    begin
        DeleteAtRestart(RetiredTrashRoot);
    end;
    DeleteAtRestart(ExpandConstant('{app}'));
end;

{ Asked once the uninstall has deleted what it could. A silent uninstall
  would restart Windows without asking, so it leaves the files to whichever
  restart comes next. }
function UninstallNeedRestart: Boolean;
begin
    RemoveRuntimeLeftovers;
    Result := RuntimeLeftoversInUse and not UninstallSilent;
    if RuntimeLeftoversInUse and UninstallSilent then
    begin
        Log('Silent uninstall: not asking for the restart.');
    end;
end;
