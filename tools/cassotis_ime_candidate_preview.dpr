program cassotis_ime_candidate_preview;

{$APPTYPE CONSOLE}

uses
    System.SysUtils,
    Winapi.Windows,
    Vcl.Forms,
    nc_candidate_window in '..\src\ui\nc_candidate_window.pas',
    nc_types in '..\src\common\nc_types.pas';

procedure fill_candidates(out candidates: TncCandidateList);
begin
    SetLength(candidates, 5);

    candidates[0].text := 'nihao';
    candidates[0].comment := 'ni hao';
    candidates[0].score := 100;
    candidates[0].source := cs_rule;

    candidates[1].text := 'nihaoya';
    candidates[1].comment := '';
    candidates[1].score := 90;
    candidates[1].source := cs_rule;

    candidates[2].text := 'nihaoshijie';
    candidates[2].comment := 'demo';
    candidates[2].score := 80;
    candidates[2].source := cs_ai;

    candidates[3].text := 'nihaoma';
    candidates[3].comment := '';
    candidates[3].score := 70;
    candidates[3].source := cs_user;

    candidates[4].text := 'nihaopengyou';
    candidates[4].comment := '';
    candidates[4].score := 60;
    candidates[4].source := cs_rule;
end;

var
    window: TncCandidateWindow;
    candidates: TncCandidateList;
    msg: TMsg;
    start_tick: Cardinal;
begin
    Application.Initialize;
    Application.ShowMainForm := False;

    window := TncCandidateWindow.create;
    try
        fill_candidates(candidates);
        window.update_candidates(candidates, 0, 2, 1, 'nihao');
        window.show_at(200, 200);

        start_tick := GetTickCount;
        while GetTickCount - start_tick < 5000 do
        begin
            if PeekMessage(msg, 0, 0, 0, PM_REMOVE) then
            begin
                TranslateMessage(msg);
                DispatchMessage(msg);
            end;
            Sleep(10);
        end;
    finally
        window.Free;
    end;
end.
