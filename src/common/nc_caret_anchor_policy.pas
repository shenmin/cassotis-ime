unit nc_caret_anchor_policy;

interface

uses
    System.Types;

type
    TncCaretAnchorSource = (casTsf, casGui, casCaretPos, casLastSent, casCursor);

    TncCaretAnchorObservation = record
        source: TncCaretAnchorSource;
        point: TPoint;
        valid: Boolean;
    end;

    TncCaretAnchorContext = record
        has_composition: Boolean;
        terminal_like_target: Boolean;
        has_context_rect: Boolean;
        context_rect: TRect;
        has_foreground_rect: Boolean;
        foreground_rect: TRect;
        cursor_point_valid: Boolean;
        cursor_point: TPoint;
        last_stable_valid: Boolean;
        last_stable_point: TPoint;
    end;

function anchor_source_name(const source: TncCaretAnchorSource): string;
function points_are_close(const left_point: TPoint; const right_point: TPoint; const max_delta: Integer): Boolean;
function anchor_looks_like_window_origin(const candidate: TPoint; const base_rect: TRect;
    const has_base_rect: Boolean): Boolean;
function is_origin_anchor_suspicious(const candidate: TPoint; const base_rect: TRect; const has_base_rect: Boolean;
    const cursor_point: TPoint; const cursor_point_valid: Boolean; const terminal_like_target: Boolean;
    const has_composition: Boolean): Boolean;
function should_relax_terminal_tsf_suspicion(const tsf_point: TPoint; const tsf_valid: Boolean;
    const gui_point: TPoint; const gui_valid: Boolean; const caret_point: TPoint; const caret_valid: Boolean;
    const base_rect: TRect; const has_base_rect: Boolean; const cursor_point: TPoint;
    const cursor_point_valid: Boolean; const terminal_like_target: Boolean; const has_composition: Boolean): Boolean;
function should_reject_top_band_point(const candidate: TPoint; const candidate_valid: Boolean;
    const reference_point: TPoint; const reference_valid: Boolean; const base_rect: TRect;
    const has_base_rect: Boolean): Boolean;
function try_choose_best_anchor_scored(const observations: array of TncCaretAnchorObservation;
    const context: TncCaretAnchorContext; out best_point: TPoint; out best_source: TncCaretAnchorSource;
    out best_score: Integer): Boolean;
function try_choose_best_anchor(const observations: array of TncCaretAnchorObservation;
    const context: TncCaretAnchorContext; out best_point: TPoint; out best_source: TncCaretAnchorSource): Boolean;

implementation

uses
    System.Math,
    System.SysUtils;

function anchor_source_name(const source: TncCaretAnchorSource): string;
begin
    case source of
        casTsf:
            Result := 'tsf';
        casGui:
            Result := 'gui';
        casCaretPos:
            Result := 'caret';
        casLastSent:
            Result := 'last_sent';
        casCursor:
            Result := 'cursor';
    else
        Result := 'unknown';
    end;
end;

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
    if not has_composition then
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

function should_relax_terminal_tsf_suspicion(const tsf_point: TPoint; const tsf_valid: Boolean;
    const gui_point: TPoint; const gui_valid: Boolean; const caret_point: TPoint; const caret_valid: Boolean;
    const base_rect: TRect; const has_base_rect: Boolean; const cursor_point: TPoint;
    const cursor_point_valid: Boolean; const terminal_like_target: Boolean; const has_composition: Boolean): Boolean;
const
    c_pair_agree_delta = 96;
    c_deeper_x = 120;
    c_deeper_y = 72;
var
    gui_suspicious: Boolean;
    caret_suspicious: Boolean;
    pair_max_x: Integer;
    pair_max_y: Integer;
begin
    Result := False;
    if (not terminal_like_target) or (not has_composition) or (not tsf_valid) then
    begin
        Exit;
    end;
    if not is_origin_anchor_suspicious(tsf_point, base_rect, has_base_rect, cursor_point,
        cursor_point_valid, terminal_like_target, has_composition) then
    begin
        Exit;
    end;
    if (not gui_valid) or (not caret_valid) or (not points_are_close(gui_point, caret_point, c_pair_agree_delta)) then
    begin
        Exit;
    end;

    gui_suspicious := is_origin_anchor_suspicious(gui_point, base_rect, has_base_rect, cursor_point,
        cursor_point_valid, terminal_like_target, has_composition);
    caret_suspicious := is_origin_anchor_suspicious(caret_point, base_rect, has_base_rect, cursor_point,
        cursor_point_valid, terminal_like_target, has_composition);
    if (not gui_suspicious) or (not caret_suspicious) then
    begin
        Exit;
    end;

    pair_max_x := Max(gui_point.X, caret_point.X);
    pair_max_y := Max(gui_point.Y, caret_point.Y);
    Result := (tsf_point.X >= pair_max_x + c_deeper_x) or
        (tsf_point.Y >= pair_max_y + c_deeper_y);
end;

function should_reject_top_band_point(const candidate: TPoint; const candidate_valid: Boolean;
    const reference_point: TPoint; const reference_valid: Boolean; const base_rect: TRect;
    const has_base_rect: Boolean): Boolean;
var
    top_band_limit_y: Integer;
begin
    Result := False;
    if (not candidate_valid) or (not reference_valid) or (not has_base_rect) then
    begin
        Exit;
    end;

    top_band_limit_y := base_rect.Top + 180;
    Result := (candidate.Y <= top_band_limit_y) and (reference_point.Y > top_band_limit_y + 32);
end;

function try_choose_best_anchor_scored(const observations: array of TncCaretAnchorObservation;
    const context: TncCaretAnchorContext; out best_point: TPoint; out best_source: TncCaretAnchorSource;
    out best_score: Integer): Boolean;
const
    c_compose_tsf_delta = 140;
    c_pair_agree_delta = 96;
    c_last_stable_delta = 96;
    c_pair_lag_x = 160;
    c_pair_lag_y = 120;
var
    base_rect: TRect;
    has_base_rect: Boolean;
    tsf_point: TPoint;
    gui_point: TPoint;
    caret_point: TPoint;
    tsf_valid: Boolean;
    gui_valid: Boolean;
    caret_valid: Boolean;
    tsf_suspicious: Boolean;
    pair_agrees: Boolean;
    pair_far_from_tsf: Boolean;
    pair_lagging_tsf: Boolean;
    pair_backed_by_last_stable: Boolean;
    last_stable_suspicious: Boolean;
    compose_delta: Integer;
    best_priority: Integer;
    score: Integer;
    priority: Integer;
    i: Integer;
    candidate: TncCaretAnchorObservation;
    reference_point: TPoint;

    function choose_base_rect(out candidate_rect: TRect): Boolean;
    begin
        if context.has_context_rect then
        begin
            candidate_rect := context.context_rect;
            Result := True;
            Exit;
        end;
        if context.has_foreground_rect then
        begin
            candidate_rect := context.foreground_rect;
            Result := True;
            Exit;
        end;
        candidate_rect := System.Types.Rect(0, 0, 0, 0);
        Result := False;
    end;

    procedure remember_points;
    var
        index: Integer;
    begin
        tsf_valid := False;
        gui_valid := False;
        caret_valid := False;
        for index := Low(observations) to High(observations) do
        begin
            if not observations[index].valid then
            begin
                Continue;
            end;
            case observations[index].source of
                casTsf:
                    begin
                        tsf_point := observations[index].point;
                        tsf_valid := True;
                    end;
                casGui:
                    begin
                        gui_point := observations[index].point;
                        gui_valid := True;
                    end;
                casCaretPos:
                    begin
                        caret_point := observations[index].point;
                        caret_valid := True;
                    end;
                casLastSent:
                    begin
                    end;
            end;
        end;
    end;

    function source_base_score(const source: TncCaretAnchorSource): Integer;
    begin
        if context.has_composition then
        begin
            case source of
                casTsf:
                    Result := 320;
                casGui:
                    Result := 250;
                casCaretPos:
                    Result := 245;
                casLastSent:
                    Result := 165;
                casCursor:
                    Result := 80;
            else
                Result := 0;
            end;
            Exit;
        end;

        case source of
            casGui:
                Result := 300;
            casCaretPos:
                Result := 295;
            casTsf:
                Result := 255;
            casLastSent:
                Result := 185;
            casCursor:
                Result := 120;
        else
            Result := 0;
        end;
    end;

    function source_priority(const source: TncCaretAnchorSource): Integer;
    begin
        if context.has_composition then
        begin
            case source of
                casTsf:
                    Result := 5;
                casGui:
                    Result := 4;
                casCaretPos:
                    Result := 3;
                casLastSent:
                    Result := 2;
                casCursor:
                    Result := 1;
            else
                Result := 0;
            end;
            Exit;
        end;

        case source of
            casGui:
                Result := 5;
            casCaretPos:
                Result := 4;
            casTsf:
                Result := 3;
            casLastSent:
                Result := 2;
            casCursor:
                Result := 1;
        else
            Result := 0;
        end;
    end;

    function find_top_band_reference(const source: TncCaretAnchorSource; out candidate_point: TPoint): Boolean;
    var
        index: Integer;
        observation: TncCaretAnchorObservation;
        observation_suspicious: Boolean;
        reference_set: Boolean;
    begin
        Result := False;
        candidate_point := System.Types.Point(0, 0);
        if not has_base_rect then
        begin
            Exit;
        end;
        reference_set := False;
        for index := Low(observations) to High(observations) do
        begin
            observation := observations[index];
            if (not observation.valid) or (observation.source = source) or (observation.source = casCursor) then
            begin
                Continue;
            end;
            observation_suspicious := is_origin_anchor_suspicious(observation.point, base_rect, has_base_rect,
                context.cursor_point, context.cursor_point_valid, context.terminal_like_target, context.has_composition);
            if observation_suspicious then
            begin
                Continue;
            end;
            if (not reference_set) or (observation.point.Y > candidate_point.Y) then
            begin
                candidate_point := observation.point;
                reference_set := True;
            end;
        end;
        Result := reference_set;
    end;

    function score_observation(const observation: TncCaretAnchorObservation; out candidate_score: Integer): Boolean;
    var
        raw_candidate_suspicious: Boolean;
        candidate_suspicious: Boolean;
        candidate_has_pair_support: Boolean;
        candidate_has_last_stable_support: Boolean;
    begin
        Result := False;
        candidate_score := 0;
        if not observation.valid then
        begin
            Exit;
        end;
        if (observation.source = casCursor) and context.has_composition and (not context.terminal_like_target) then
        begin
            Exit;
        end;

        candidate_score := source_base_score(observation.source);
        raw_candidate_suspicious := is_origin_anchor_suspicious(observation.point, base_rect, has_base_rect,
            context.cursor_point, context.cursor_point_valid, context.terminal_like_target, context.has_composition);
        candidate_suspicious := raw_candidate_suspicious;
        if (observation.source = casTsf) and candidate_suspicious and
            should_relax_terminal_tsf_suspicion(observation.point, True, gui_point, gui_valid,
            caret_point, caret_valid, base_rect, has_base_rect, context.cursor_point,
            context.cursor_point_valid, context.terminal_like_target, context.has_composition) then
        begin
            candidate_suspicious := False;
        end;
        candidate_has_pair_support := False;
        candidate_has_last_stable_support := context.last_stable_valid and (not last_stable_suspicious) and
            points_are_close(observation.point, context.last_stable_point, c_last_stable_delta);
        if observation.source = casGui then
        begin
            candidate_has_pair_support := caret_valid and points_are_close(observation.point, caret_point, c_pair_agree_delta);
        end
        else if observation.source = casCaretPos then
        begin
            candidate_has_pair_support := gui_valid and points_are_close(observation.point, gui_point, c_pair_agree_delta);
        end;
        if candidate_has_pair_support and (observation.source in [casGui, casCaretPos]) then
        begin
            if (not raw_candidate_suspicious) or candidate_has_last_stable_support then
            begin
                candidate_suspicious := False;
            end;
        end;

        if candidate_suspicious then
        begin
            Dec(candidate_score, 220);
        end;

        if ((not candidate_has_pair_support) or candidate_suspicious) and
            find_top_band_reference(observation.source, reference_point) then
        begin
            if should_reject_top_band_point(observation.point, True, reference_point, True, base_rect, has_base_rect) then
            begin
                Dec(candidate_score, 180);
            end;
        end;

        if context.last_stable_valid and (not last_stable_suspicious) and
            points_are_close(observation.point, context.last_stable_point, c_last_stable_delta) then
        begin
            Inc(candidate_score, 30);
        end;

        if context.has_composition then
        begin
            if observation.source = casTsf then
            begin
                if not candidate_suspicious then
                begin
                    Inc(candidate_score, 55);
                end;
                if pair_backed_by_last_stable and pair_far_from_tsf and (not context.terminal_like_target) then
                begin
                    Dec(candidate_score, 220);
                end;
                if pair_lagging_tsf then
                begin
                    Inc(candidate_score, 45);
                end
                else if pair_agrees and pair_far_from_tsf then
                begin
                    Dec(candidate_score, 120);
                end;
            end
            else if observation.source in [casGui, casCaretPos] then
            begin
                if pair_agrees and (not candidate_suspicious) and (not pair_lagging_tsf) then
                begin
                    Inc(candidate_score, 80);
                    if pair_far_from_tsf then
                    begin
                        Inc(candidate_score, 35);
                    end;
                end;
                if tsf_valid then
                begin
                    if points_are_close(observation.point, tsf_point, c_compose_tsf_delta) then
                    begin
                        Inc(candidate_score, 12);
                    end
                    else if not tsf_suspicious then
                    begin
                        Dec(candidate_score, 55);
                    end
                    else
                    begin
                        Inc(candidate_score, 45);
                    end;
                end;
                if pair_lagging_tsf and tsf_valid and (not tsf_suspicious) then
                begin
                    Dec(candidate_score, 160);
                end;
            end
            else if observation.source = casLastSent then
            begin
                Dec(candidate_score, 20);
                if context.terminal_like_target then
                begin
                    if raw_candidate_suspicious then
                    begin
                        Dec(candidate_score, 80);
                    end;
                    if tsf_valid and (not tsf_suspicious) then
                    begin
                        if points_are_close(observation.point, tsf_point, c_compose_tsf_delta) then
                        begin
                            Dec(candidate_score, 60);
                        end
                        else
                        begin
                            // In terminal-like hosts, a stale last-sent caret should not outrank
                            // a deeper, currently valid TSF anchor.
                            Dec(candidate_score, 220);
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if observation.source in [casGui, casCaretPos] then
            begin
                Inc(candidate_score, 25);
            end;
            if pair_agrees and (observation.source in [casGui, casCaretPos]) then
            begin
                Inc(candidate_score, 25);
            end;
        end;

        Result := True;
    end;

begin
    best_point := System.Types.Point(0, 0);
    best_source := casCursor;
    best_score := Low(Integer);
    Result := False;
    if Length(observations) = 0 then
    begin
        Exit;
    end;

    has_base_rect := choose_base_rect(base_rect);
    remember_points;
    last_stable_suspicious := context.last_stable_valid and
        is_origin_anchor_suspicious(context.last_stable_point, base_rect, has_base_rect,
        context.cursor_point, context.cursor_point_valid, context.terminal_like_target, context.has_composition);
    tsf_suspicious := tsf_valid and is_origin_anchor_suspicious(tsf_point, base_rect, has_base_rect,
        context.cursor_point, context.cursor_point_valid, context.terminal_like_target, context.has_composition);
    if tsf_suspicious and should_relax_terminal_tsf_suspicion(tsf_point, tsf_valid, gui_point, gui_valid,
        caret_point, caret_valid, base_rect, has_base_rect, context.cursor_point,
        context.cursor_point_valid, context.terminal_like_target, context.has_composition) then
    begin
        tsf_suspicious := False;
    end;

    pair_agrees := gui_valid and caret_valid and points_are_close(gui_point, caret_point, c_pair_agree_delta);
    pair_far_from_tsf := False;
    pair_lagging_tsf := False;
    pair_backed_by_last_stable := False;
    if pair_agrees and tsf_valid then
    begin
        compose_delta := c_compose_tsf_delta;
        pair_far_from_tsf := (not points_are_close(gui_point, tsf_point, compose_delta)) and
            (not points_are_close(caret_point, tsf_point, compose_delta));
        if context.last_stable_valid and (not last_stable_suspicious) then
        begin
            pair_backed_by_last_stable :=
                points_are_close(context.last_stable_point, gui_point, c_last_stable_delta) or
                points_are_close(context.last_stable_point, caret_point, c_last_stable_delta);
        end;
        if pair_far_from_tsf and (not tsf_suspicious) and (not pair_backed_by_last_stable) then
        begin
            pair_lagging_tsf := (Max(gui_point.X, caret_point.X) <= tsf_point.X - c_pair_lag_x) and
                (Max(gui_point.Y, caret_point.Y) <= tsf_point.Y - c_pair_lag_y);
        end;
    end;

    best_priority := Low(Integer);
    for i := Low(observations) to High(observations) do
    begin
        candidate := observations[i];
        if not score_observation(candidate, score) then
        begin
            Continue;
        end;
        priority := source_priority(candidate.source);
        if (score > best_score) or ((score = best_score) and (priority > best_priority)) then
        begin
            best_score := score;
            best_priority := priority;
            best_point := candidate.point;
            best_source := candidate.source;
            Result := True;
        end;
    end;
end;

function try_choose_best_anchor(const observations: array of TncCaretAnchorObservation;
    const context: TncCaretAnchorContext; out best_point: TPoint; out best_source: TncCaretAnchorSource): Boolean;
var
    ignored_score: Integer;
begin
    Result := try_choose_best_anchor_scored(observations, context, best_point, best_source, ignored_score);
end;

end.
