unit nc_mode_hint_policy;

interface

uses
    System.Types,
    nc_types;

type
    // Why the label beside the caret is asked for: a field took the keyboard
    // focus (or the input method became active in it), or the user switched
    // between Chinese and English.
    TncModeHintReason = (mhr_focus, mhr_toggle);

    // The field a focus hint was asked for: its document manager and window.
    TncModeHintTarget = record
        document: NativeUInt;
        window: NativeUInt;
    end;

const
    // A field that takes the focus again within this long gets no new hint.
    c_mode_hint_repeat_ms = 3000;
    // How long the label stays fully visible after fading in, before it fades
    // out: a reminder on focus a little longer than the answer to a switch.
    c_mode_hint_focus_hold_ms = 1300;
    c_mode_hint_toggle_hold_ms = 800;

// A switch always shows the new mode; a focus only reminds of English, the
// mode that types letters without any sign of the input method.
function nc_mode_hint_should_show(const enabled: Boolean;
    const reason: TncModeHintReason; const input_mode: TncInputMode): Boolean;
function nc_mode_hint_hold_ms(const reason: TncModeHintReason): Cardinal;
function nc_mode_hint_focus_is_repeat(const previous, target: TncModeHintTarget;
    const previous_tick, now_tick: UInt64): Boolean;
// Top left of a label of the given size for a caret whose line ends at
// anchor.Y (anchor.X its left): above the line, below it where the work area
// has no room above, kept inside the work area.
function nc_mode_hint_placement(const anchor: TPoint; const line_height: Integer;
    const size: TSize; const gap: Integer; const work_area: TRect): TPoint;
function nc_mode_hint_reason_to_text(const reason: TncModeHintReason): string;
function nc_try_parse_mode_hint_reason(const text: string;
    out reason: TncModeHintReason): Boolean;

implementation

uses
    System.SysUtils;

function nc_mode_hint_should_show(const enabled: Boolean;
    const reason: TncModeHintReason; const input_mode: TncInputMode): Boolean;
begin
    Result := enabled and ((reason = mhr_toggle) or (input_mode = im_english));
end;

function nc_mode_hint_hold_ms(const reason: TncModeHintReason): Cardinal;
begin
    if reason = mhr_toggle then
        Result := c_mode_hint_toggle_hold_ms
    else
        Result := c_mode_hint_focus_hold_ms;
end;

function nc_mode_hint_focus_is_repeat(const previous, target: TncModeHintTarget;
    const previous_tick, now_tick: UInt64): Boolean;
begin
    Result := (previous_tick <> 0) and (now_tick >= previous_tick) and
        (now_tick - previous_tick < c_mode_hint_repeat_ms) and
        (previous.document = target.document) and (previous.window = target.window);
end;

function nc_mode_hint_placement(const anchor: TPoint; const line_height: Integer;
    const size: TSize; const gap: Integer; const work_area: TRect): TPoint;
var
    line_top: Integer;
begin
    // Without a line height the label's own height stands for the line.
    if line_height > 0 then
        line_top := anchor.Y - line_height
    else
        line_top := anchor.Y - size.cy;
    Result.Y := line_top - gap - size.cy;
    if Result.Y < work_area.Top then
        Result.Y := anchor.Y + gap;
    if Result.Y + size.cy > work_area.Bottom then
        Result.Y := work_area.Bottom - size.cy;
    if Result.Y < work_area.Top then
        Result.Y := work_area.Top;
    Result.X := anchor.X;
    if Result.X + size.cx > work_area.Right then
        Result.X := work_area.Right - size.cx;
    if Result.X < work_area.Left then
        Result.X := work_area.Left;
end;

function nc_mode_hint_reason_to_text(const reason: TncModeHintReason): string;
begin
    if reason = mhr_toggle then
        Result := 'toggle'
    else
        Result := 'focus';
end;

function nc_try_parse_mode_hint_reason(const text: string;
    out reason: TncModeHintReason): Boolean;
begin
    Result := True;
    if SameText(text, 'toggle') then
        reason := mhr_toggle
    else if SameText(text, 'focus') then
        reason := mhr_focus
    else
    begin
        reason := mhr_focus;
        Result := False;
    end;
end;

end.
