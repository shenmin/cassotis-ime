unit nc_caret_anchor_policy;

interface

uses
    System.Types;

function points_are_close(const left_point: TPoint; const right_point: TPoint; const max_delta: Integer): Boolean;
function anchor_looks_like_window_origin(const candidate: TPoint; const base_rect: TRect;
    const has_base_rect: Boolean): Boolean;
function is_origin_anchor_suspicious(const candidate: TPoint; const base_rect: TRect; const has_base_rect: Boolean;
    const cursor_point: TPoint; const cursor_point_valid: Boolean; const terminal_like_target: Boolean;
    const has_composition: Boolean): Boolean;
function should_reject_chromium_top_band_point(const candidate: TPoint; const candidate_valid: Boolean;
    const tsf_point: TPoint; const tsf_point_valid: Boolean; const chromium_like_target: Boolean;
    const foreground_rect: TRect; const has_foreground_rect: Boolean): Boolean;

implementation

function points_are_close(const left_point: TPoint; const right_point: TPoint; const max_delta: Integer): Boolean;
begin
    Result := (Abs(left_point.X - right_point.X) <= max_delta) and
        (Abs(left_point.Y - right_point.Y) <= max_delta);
end;

function anchor_looks_like_window_origin(const candidate: TPoint; const base_rect: TRect;
    const has_base_rect: Boolean): Boolean;
const
    c_left_range = 220;
    c_top_range = 180;
begin
    if not has_base_rect then
    begin
        Result := False;
        Exit;
    end;

    // Some mixed-DPI apps can report TSF TextExt near the top-left of window
    // while real caret is much deeper in client area.
    Result := (candidate.X >= base_rect.Left - 48) and
        (candidate.X <= base_rect.Left + c_left_range) and
        (candidate.Y >= base_rect.Top - 48) and
        (candidate.Y <= base_rect.Top + c_top_range);
end;

function is_origin_anchor_suspicious(const candidate: TPoint; const base_rect: TRect; const has_base_rect: Boolean;
    const cursor_point: TPoint; const cursor_point_valid: Boolean; const terminal_like_target: Boolean;
    const has_composition: Boolean): Boolean;
const
    c_cursor_close_delta = 180;
begin
    Result := False;
    if terminal_like_target or (not has_composition) then
    begin
        Exit;
    end;
    if not anchor_looks_like_window_origin(candidate, base_rect, has_base_rect) then
    begin
        Exit;
    end;
    if cursor_point_valid and points_are_close(candidate, cursor_point, c_cursor_close_delta) then
    begin
        Exit;
    end;
    Result := True;
end;

function should_reject_chromium_top_band_point(const candidate: TPoint; const candidate_valid: Boolean;
    const tsf_point: TPoint; const tsf_point_valid: Boolean; const chromium_like_target: Boolean;
    const foreground_rect: TRect; const has_foreground_rect: Boolean): Boolean;
var
    top_band_limit_y: Integer;
begin
    Result := False;
    if (not chromium_like_target) or (not candidate_valid) or (not tsf_point_valid) or
        (not has_foreground_rect) then
    begin
        Exit;
    end;

    top_band_limit_y := foreground_rect.Top + 180;

    Result := (candidate.Y <= top_band_limit_y) and (tsf_point.Y > top_band_limit_y);
end;

end.
