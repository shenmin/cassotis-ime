unit nc_shortcut;

interface

uses
    Winapi.Windows,
    nc_types;

const
    c_nc_shortcut_config_signature = $4E435348;

type
    TncShortcutValidationIssue = (
        svi_none,
        svi_missing_key,
        svi_invalid_modifier_key,
        svi_unmodified_regular_key
    );

function nc_make_shortcut(const key_code: Word; const shift_down: Boolean = False;
    const ctrl_down: Boolean = False; const alt_down: Boolean = False): TncShortcut;
function nc_default_shortcut(const action: TncShortcutAction): TncShortcut;
function nc_default_shortcut_config: TncShortcutConfig;
procedure nc_normalize_shortcut_config(var config: TncShortcutConfig);
function nc_shortcut_for_action(const config: TncShortcutConfig;
    const action: TncShortcutAction): TncShortcut;
procedure nc_set_shortcut_for_action(var config: TncShortcutConfig;
    const action: TncShortcutAction; const shortcut: TncShortcut);
function nc_shortcut_equal(const left_value: TncShortcut;
    const right_value: TncShortcut): Boolean;
function nc_shortcut_config_has_duplicates(const config: TncShortcutConfig): Boolean;
function nc_shortcut_matches(const shortcut: TncShortcut; const key_code: Word;
    const key_state: TncKeyState): Boolean;
function nc_find_shortcut_action(const config: TncShortcutConfig; const key_code: Word;
    const key_state: TncKeyState; out action: TncShortcutAction): Boolean;
function nc_shortcut_is_modifier_only(const shortcut: TncShortcut): Boolean;
function nc_get_shortcut_validation_issue(const shortcut: TncShortcut): TncShortcutValidationIssue;
function nc_shortcut_is_valid(const shortcut: TncShortcut): Boolean;
function nc_shortcut_to_text(const shortcut: TncShortcut): string;
function nc_try_parse_shortcut(const value: string; out shortcut: TncShortcut): Boolean;
function nc_shortcut_key_name(const key_code: Word): string;
function nc_normalize_shortcut_key_code(const key_code: Word): Word;

implementation

uses
    System.SysUtils,
    System.Classes;

function normalize_key_code(const key_code: Word): Word;
begin
    case key_code of
        VK_LSHIFT, VK_RSHIFT:
            Result := VK_SHIFT;
        VK_LCONTROL, VK_RCONTROL:
            Result := VK_CONTROL;
        VK_LMENU, VK_RMENU:
            Result := VK_MENU;
    else
        Result := key_code;
    end;
end;

function nc_normalize_shortcut_key_code(const key_code: Word): Word;
begin
    Result := normalize_key_code(key_code);
end;

function nc_make_shortcut(const key_code: Word; const shift_down: Boolean;
    const ctrl_down: Boolean; const alt_down: Boolean): TncShortcut;
begin
    Result.key_code := normalize_key_code(key_code);
    Result.shift_down := shift_down;
    Result.ctrl_down := ctrl_down;
    Result.alt_down := alt_down;
end;

function nc_default_shortcut(const action: TncShortcutAction): TncShortcut;
begin
    case action of
        sa_input_mode_toggle:
            Result := nc_make_shortcut(VK_SHIFT);
        sa_punctuation_toggle:
            Result := nc_make_shortcut(VK_OEM_PERIOD, False, True, False);
        sa_dictionary_variant_toggle:
            Result := nc_make_shortcut(Ord('T'), True, True, False);
        sa_full_width_toggle:
            Result := nc_make_shortcut(VK_SPACE, True, False, False);
        sa_open_settings:
            Result := nc_make_shortcut(VK_F10, True, True, False);
    else
        Result := nc_make_shortcut(0);
    end;
end;

function nc_default_shortcut_config: TncShortcutConfig;
begin
    Result.signature := c_nc_shortcut_config_signature;
    Result.input_mode_toggle := nc_default_shortcut(sa_input_mode_toggle);
    Result.punctuation_toggle := nc_default_shortcut(sa_punctuation_toggle);
    Result.dictionary_variant_toggle := nc_default_shortcut(sa_dictionary_variant_toggle);
    Result.full_width_toggle := nc_default_shortcut(sa_full_width_toggle);
    Result.open_settings := nc_default_shortcut(sa_open_settings);
end;

function nc_shortcut_for_action(const config: TncShortcutConfig;
    const action: TncShortcutAction): TncShortcut;
begin
    case action of
        sa_input_mode_toggle:
            Result := config.input_mode_toggle;
        sa_punctuation_toggle:
            Result := config.punctuation_toggle;
        sa_dictionary_variant_toggle:
            Result := config.dictionary_variant_toggle;
        sa_full_width_toggle:
            Result := config.full_width_toggle;
        sa_open_settings:
            Result := config.open_settings;
    else
        Result := nc_make_shortcut(0);
    end;
end;

procedure nc_set_shortcut_for_action(var config: TncShortcutConfig;
    const action: TncShortcutAction; const shortcut: TncShortcut);
begin
    case action of
        sa_input_mode_toggle:
            config.input_mode_toggle := shortcut;
        sa_punctuation_toggle:
            config.punctuation_toggle := shortcut;
        sa_dictionary_variant_toggle:
            config.dictionary_variant_toggle := shortcut;
        sa_full_width_toggle:
            config.full_width_toggle := shortcut;
        sa_open_settings:
            config.open_settings := shortcut;
    end;
end;

function nc_shortcut_equal(const left_value: TncShortcut;
    const right_value: TncShortcut): Boolean;
begin
    Result := (normalize_key_code(left_value.key_code) = normalize_key_code(right_value.key_code)) and
        (left_value.shift_down = right_value.shift_down) and
        (left_value.ctrl_down = right_value.ctrl_down) and
        (left_value.alt_down = right_value.alt_down);
end;

function nc_shortcut_config_has_duplicates(const config: TncShortcutConfig): Boolean;
var
    first_index: Integer;
    second_index: Integer;
    first_action: TncShortcutAction;
    second_action: TncShortcutAction;
begin
    Result := False;
    for first_index := Ord(Low(TncShortcutAction)) to Ord(High(TncShortcutAction)) - 1 do
    begin
        first_action := TncShortcutAction(first_index);
        for second_index := first_index + 1 to Ord(High(TncShortcutAction)) do
        begin
            second_action := TncShortcutAction(second_index);
            if nc_shortcut_equal(nc_shortcut_for_action(config, first_action),
                nc_shortcut_for_action(config, second_action)) then
            begin
                Exit(True);
            end;
        end;
    end;
end;

function nc_shortcut_is_modifier_only(const shortcut: TncShortcut): Boolean;
var
    normalized_key: Word;
begin
    normalized_key := normalize_key_code(shortcut.key_code);
    Result := (normalized_key = VK_SHIFT) or (normalized_key = VK_CONTROL) or
        (normalized_key = VK_MENU);
end;

function nc_get_shortcut_validation_issue(const shortcut: TncShortcut): TncShortcutValidationIssue;
var
    normalized_key: Word;
begin
    normalized_key := normalize_key_code(shortcut.key_code);
    if normalized_key = 0 then
    begin
        Exit(svi_missing_key);
    end;

    if nc_shortcut_is_modifier_only(shortcut) then
    begin
        if (normalized_key = VK_SHIFT) and (not shortcut.shift_down) and
            (not shortcut.ctrl_down) and (not shortcut.alt_down) then
        begin
            Exit(svi_none);
        end;
        Result := svi_invalid_modifier_key;
        Exit;
    end;

    if shortcut.shift_down or shortcut.ctrl_down or shortcut.alt_down then
    begin
        Exit(svi_none);
    end;

    if (normalized_key >= VK_F1) and (normalized_key <= VK_F24) then
    begin
        Exit(svi_none);
    end;
    Result := svi_unmodified_regular_key;
end;

function nc_shortcut_is_valid(const shortcut: TncShortcut): Boolean;
begin
    Result := nc_get_shortcut_validation_issue(shortcut) = svi_none;
end;

procedure nc_normalize_shortcut_config(var config: TncShortcutConfig);
var
    action: TncShortcutAction;
    shortcut: TncShortcut;
begin
    if config.signature <> c_nc_shortcut_config_signature then
    begin
        config := nc_default_shortcut_config;
        Exit;
    end;

    for action := Low(TncShortcutAction) to High(TncShortcutAction) do
    begin
        shortcut := nc_shortcut_for_action(config, action);
        if not nc_shortcut_is_valid(shortcut) then
        begin
            nc_set_shortcut_for_action(config, action, nc_default_shortcut(action));
        end;
    end;

    if nc_shortcut_config_has_duplicates(config) then
    begin
        config := nc_default_shortcut_config;
    end;
end;

function nc_shortcut_matches(const shortcut: TncShortcut; const key_code: Word;
    const key_state: TncKeyState): Boolean;
var
    normalized_key: Word;
    actual_shift_down: Boolean;
    actual_ctrl_down: Boolean;
    actual_alt_down: Boolean;
begin
    Result := False;
    if not nc_shortcut_is_valid(shortcut) then
    begin
        Exit;
    end;

    normalized_key := normalize_key_code(key_code);
    if normalize_key_code(shortcut.key_code) <> normalized_key then
    begin
        Exit;
    end;

    actual_shift_down := key_state.shift_down;
    actual_ctrl_down := key_state.ctrl_down;
    actual_alt_down := key_state.alt_down;
    if normalized_key = VK_SHIFT then
    begin
        actual_shift_down := False;
    end
    else if normalized_key = VK_CONTROL then
    begin
        actual_ctrl_down := False;
    end
    else if normalized_key = VK_MENU then
    begin
        actual_alt_down := False;
    end;

    Result := (shortcut.shift_down = actual_shift_down) and
        (shortcut.ctrl_down = actual_ctrl_down) and
        (shortcut.alt_down = actual_alt_down);
end;

function nc_find_shortcut_action(const config: TncShortcutConfig; const key_code: Word;
    const key_state: TncKeyState; out action: TncShortcutAction): Boolean;
var
    candidate_action: TncShortcutAction;
begin
    for candidate_action := Low(TncShortcutAction) to High(TncShortcutAction) do
    begin
        if nc_shortcut_matches(nc_shortcut_for_action(config, candidate_action), key_code, key_state) then
        begin
            action := candidate_action;
            Exit(True);
        end;
    end;
    action := Low(TncShortcutAction);
    Result := False;
end;

function nc_shortcut_key_name(const key_code: Word): string;
var
    normalized_key: Word;
begin
    normalized_key := normalize_key_code(key_code);
    if (normalized_key >= Ord('A')) and (normalized_key <= Ord('Z')) then
    begin
        Exit(Char(normalized_key));
    end;
    if (normalized_key >= Ord('0')) and (normalized_key <= Ord('9')) then
    begin
        Exit(Char(normalized_key));
    end;
    if (normalized_key >= VK_F1) and (normalized_key <= VK_F24) then
    begin
        Exit('F' + IntToStr(normalized_key - VK_F1 + 1));
    end;

    case normalized_key of
        VK_SHIFT: Result := 'Shift';
        VK_CONTROL: Result := 'Ctrl';
        VK_MENU: Result := 'Alt';
        VK_SPACE: Result := 'Space';
        VK_TAB: Result := 'Tab';
        VK_RETURN: Result := 'Enter';
        VK_ESCAPE: Result := 'Esc';
        VK_BACK: Result := 'Backspace';
        VK_PRIOR: Result := 'PageUp';
        VK_NEXT: Result := 'PageDown';
        VK_HOME: Result := 'Home';
        VK_END: Result := 'End';
        VK_LEFT: Result := 'Left';
        VK_RIGHT: Result := 'Right';
        VK_UP: Result := 'Up';
        VK_DOWN: Result := 'Down';
        VK_INSERT: Result := 'Insert';
        VK_DELETE: Result := 'Delete';
        VK_OEM_COMMA: Result := ',';
        VK_OEM_PERIOD: Result := '.';
        VK_OEM_1: Result := ';';
        VK_OEM_2: Result := '/';
        VK_OEM_3: Result := '`';
        VK_OEM_4: Result := '[';
        VK_OEM_5: Result := '\';
        VK_OEM_6: Result := ']';
        VK_OEM_7: Result := '''';
        VK_OEM_MINUS: Result := '-';
        VK_OEM_PLUS: Result := 'Equal';
        VK_ADD: Result := 'NumpadPlus';
        VK_SUBTRACT: Result := 'NumpadMinus';
        VK_MULTIPLY: Result := 'NumpadMultiply';
        VK_DIVIDE: Result := 'NumpadDivide';
        VK_DECIMAL: Result := 'NumpadDecimal';
    else
        Result := '';
    end;
end;

function nc_shortcut_to_text(const shortcut: TncShortcut): string;
var
    key_name: string;
begin
    key_name := nc_shortcut_key_name(shortcut.key_code);
    if key_name = '' then
    begin
        Exit('');
    end;

    Result := '';
    if shortcut.ctrl_down then
    begin
        Result := 'Ctrl+';
    end;
    if shortcut.shift_down then
    begin
        Result := Result + 'Shift+';
    end;
    if shortcut.alt_down then
    begin
        Result := Result + 'Alt+';
    end;
    Result := Result + key_name;
end;

function try_parse_key_name(const value: string; out key_code: Word): Boolean;
var
    normalized_value: string;
    function try_parse_function_key: Boolean;
    var
        function_index: Integer;
    begin
        Result := False;
        if (Length(normalized_value) < 2) or (normalized_value[1] <> 'F') or
            (not TryStrToInt(Copy(normalized_value, 2, MaxInt), function_index)) or
            (function_index < 1) or (function_index > 24) then
        begin
            Exit;
        end;
        key_code := VK_F1 + function_index - 1;
        Result := True;
    end;
begin
    key_code := 0;
    normalized_value := UpperCase(Trim(value));
    if Length(normalized_value) = 1 then
    begin
        if ((normalized_value[1] >= 'A') and (normalized_value[1] <= 'Z')) or
            ((normalized_value[1] >= '0') and (normalized_value[1] <= '9')) then
        begin
            key_code := Ord(normalized_value[1]);
            Exit(True);
        end;
    end;
    if try_parse_function_key then
    begin
        Exit(True);
    end;

    if normalized_value = 'SHIFT' then key_code := VK_SHIFT
    else if (normalized_value = 'CTRL') or (normalized_value = 'CONTROL') then key_code := VK_CONTROL
    else if normalized_value = 'ALT' then key_code := VK_MENU
    else if normalized_value = 'SPACE' then key_code := VK_SPACE
    else if normalized_value = 'TAB' then key_code := VK_TAB
    else if normalized_value = 'ENTER' then key_code := VK_RETURN
    else if (normalized_value = 'ESC') or (normalized_value = 'ESCAPE') then key_code := VK_ESCAPE
    else if normalized_value = 'BACKSPACE' then key_code := VK_BACK
    else if normalized_value = 'PAGEUP' then key_code := VK_PRIOR
    else if normalized_value = 'PAGEDOWN' then key_code := VK_NEXT
    else if normalized_value = 'HOME' then key_code := VK_HOME
    else if normalized_value = 'END' then key_code := VK_END
    else if normalized_value = 'LEFT' then key_code := VK_LEFT
    else if normalized_value = 'RIGHT' then key_code := VK_RIGHT
    else if normalized_value = 'UP' then key_code := VK_UP
    else if normalized_value = 'DOWN' then key_code := VK_DOWN
    else if normalized_value = 'INSERT' then key_code := VK_INSERT
    else if normalized_value = 'DELETE' then key_code := VK_DELETE
    else if normalized_value = ',' then key_code := VK_OEM_COMMA
    else if normalized_value = '.' then key_code := VK_OEM_PERIOD
    else if normalized_value = ';' then key_code := VK_OEM_1
    else if normalized_value = '/' then key_code := VK_OEM_2
    else if normalized_value = '`' then key_code := VK_OEM_3
    else if normalized_value = '[' then key_code := VK_OEM_4
    else if normalized_value = '\' then key_code := VK_OEM_5
    else if normalized_value = ']' then key_code := VK_OEM_6
    else if normalized_value = '''' then key_code := VK_OEM_7
    else if normalized_value = '-' then key_code := VK_OEM_MINUS
    else if normalized_value = 'EQUAL' then key_code := VK_OEM_PLUS
    else if normalized_value = 'NUMPADPLUS' then key_code := VK_ADD
    else if normalized_value = 'NUMPADMINUS' then key_code := VK_SUBTRACT
    else if normalized_value = 'NUMPADMULTIPLY' then key_code := VK_MULTIPLY
    else if normalized_value = 'NUMPADDIVIDE' then key_code := VK_DIVIDE
    else if normalized_value = 'NUMPADDECIMAL' then key_code := VK_DECIMAL;
    Result := key_code <> 0;
end;

function nc_try_parse_shortcut(const value: string; out shortcut: TncShortcut): Boolean;
var
    parts: TStringList;
    part_index: Integer;
    token: string;
    key_code: Word;
    has_key: Boolean;
    shift_down: Boolean;
    ctrl_down: Boolean;
    alt_down: Boolean;
begin
    shortcut := nc_make_shortcut(0);
    parts := TStringList.Create;
    try
        parts.StrictDelimiter := True;
        parts.Delimiter := '+';
        parts.DelimitedText := Trim(value);
        has_key := False;
        shift_down := False;
        ctrl_down := False;
        alt_down := False;
        for part_index := 0 to parts.Count - 1 do
        begin
            token := Trim(parts[part_index]);
            if token = '' then
            begin
                Exit(False);
            end;
            if SameText(token, 'Ctrl') or SameText(token, 'Control') then
            begin
                if has_key or ctrl_down then
                begin
                    Exit(False);
                end;
                ctrl_down := True;
            end
            else if SameText(token, 'Shift') then
            begin
                if (parts.Count = 1) then
                begin
                    key_code := VK_SHIFT;
                    has_key := True;
                end
                else
                begin
                    if has_key or shift_down then
                    begin
                        Exit(False);
                    end;
                    shift_down := True;
                end;
            end
            else if SameText(token, 'Alt') then
            begin
                if has_key or alt_down then
                begin
                    Exit(False);
                end;
                alt_down := True;
            end
            else
            begin
                if has_key or (not try_parse_key_name(token, key_code)) then
                begin
                    Exit(False);
                end;
                has_key := True;
            end;
        end;

        if not has_key then
        begin
            Exit(False);
        end;
        shortcut := nc_make_shortcut(key_code, shift_down, ctrl_down, alt_down);
        Result := nc_shortcut_is_valid(shortcut);
    finally
        parts.Free;
    end;
end;

end.
