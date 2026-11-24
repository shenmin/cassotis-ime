unit nc_candidate_theme;

interface

uses
    Vcl.Graphics, nc_types;

type
    TncCandidateColorTheme = record
        name: string;
        background_color: TColor;
        border_color: TColor;
        text_color: TColor;
        muted_text_color: TColor;
        weight_text_color: TColor;
        user_text_color: TColor;
        lm_compound_text_color: TColor;
        selected_background_color: TColor;
        selected_border_color: TColor;
        active_row_background_color: TColor;
        active_row_indicator_color: TColor;
        selected_text_color: TColor;
        selected_user_text_color: TColor;
        selected_lm_compound_text_color: TColor;
        selected_weight_text_color: TColor;
    end;

function nc_candidate_color_theme_count: Integer;
function nc_normalize_candidate_color_scheme(const value: Integer): Integer;
function nc_candidate_color_theme(const value: Integer): TncCandidateColorTheme;
function nc_completion_text_color(const theme: TncCandidateColorTheme;
    const source: TncOneKeyCompletionSource): TColor;

implementation

uses
    Winapi.Windows;

function nc_completion_text_color(const theme: TncCandidateColorTheme;
    const source: TncOneKeyCompletionSource): TColor;
begin
    if source in [okcs_user_exact, okcs_base_exact, okcs_transition,
        okcs_long_transition, okcs_long_neural, okcs_document_copy, okcs_wubi] then
        Result := theme.lm_compound_text_color
    else
        Result := theme.text_color;
end;

function nc_candidate_color_theme_count: Integer;
begin
    Result := c_max_candidate_color_scheme - c_min_candidate_color_scheme + 1;
end;

function nc_normalize_candidate_color_scheme(const value: Integer): Integer;
begin
    Result := value;
    if Result < c_min_candidate_color_scheme then
    begin
        Result := c_default_candidate_color_scheme;
    end
    else if Result > c_max_candidate_color_scheme then
    begin
        Result := c_default_candidate_color_scheme;
    end;
end;

function blend_theme_colors(const background, foreground: TColor;
    const foreground_percent: Integer): TColor;
var back, front: COLORREF;
begin
    back := ColorToRGB(background);
    front := ColorToRGB(foreground);
    Result := TColor(RGB(
        (GetRValue(back) * (100 - foreground_percent) +
            GetRValue(front) * foreground_percent + 50) div 100,
        (GetGValue(back) * (100 - foreground_percent) +
            GetGValue(front) * foreground_percent + 50) div 100,
        (GetBValue(back) * (100 - foreground_percent) +
            GetBValue(front) * foreground_percent + 50) div 100));
end;

function nc_candidate_color_theme(const value: Integer): TncCandidateColorTheme;
begin
    case nc_normalize_candidate_color_scheme(value) of
        1:
            begin
                Result.name := string(WideChar($6708)) + string(WideChar($767D));
                Result.background_color := TColor(RGB(248, 245, 238));
                Result.border_color := TColor(RGB(224, 216, 202));
                Result.text_color := TColor(RGB(36, 43, 48));
                Result.muted_text_color := TColor(RGB(112, 106, 96));
                Result.weight_text_color := TColor(RGB(120, 114, 104));
                Result.user_text_color := TColor(RGB(71, 128, 83));
                Result.lm_compound_text_color := TColor(RGB(39, 104, 168));
                Result.selected_background_color := TColor(RGB(234, 225, 210));
                Result.selected_border_color := TColor(RGB(204, 190, 169));
                Result.selected_text_color := TColor(RGB(30, 34, 38));
                Result.selected_user_text_color := TColor(RGB(47, 108, 60));
                Result.selected_lm_compound_text_color := TColor(RGB(29, 86, 143));
                Result.selected_weight_text_color := TColor(RGB(95, 88, 78));
            end;
        2:
            begin
                Result.name := string(WideChar($9752)) + string(WideChar($74F7));
                Result.background_color := TColor(RGB(235, 244, 239));
                Result.border_color := TColor(RGB(190, 214, 204));
                Result.text_color := TColor(RGB(30, 58, 50));
                Result.muted_text_color := TColor(RGB(87, 112, 105));
                Result.weight_text_color := TColor(RGB(88, 111, 105));
                Result.user_text_color := TColor(RGB(35, 108, 70));
                Result.lm_compound_text_color := TColor(RGB(23, 111, 159));
                Result.selected_background_color := TColor(RGB(211, 231, 222));
                Result.selected_border_color := TColor(RGB(151, 190, 176));
                Result.selected_text_color := TColor(RGB(22, 48, 41));
                Result.selected_user_text_color := TColor(RGB(25, 91, 57));
                Result.selected_lm_compound_text_color := TColor(RGB(16, 91, 132));
                Result.selected_weight_text_color := TColor(RGB(67, 93, 87));
            end;
        3:
            begin
                Result.name := string(WideChar($6674)) + string(WideChar($84DD));
                Result.background_color := TColor(RGB(231, 243, 249));
                Result.border_color := TColor(RGB(184, 211, 225));
                Result.text_color := TColor(RGB(27, 54, 72));
                Result.muted_text_color := TColor(RGB(86, 116, 135));
                Result.weight_text_color := TColor(RGB(90, 118, 136));
                Result.user_text_color := TColor(RGB(35, 112, 116));
                Result.lm_compound_text_color := TColor(RGB(20, 105, 168));
                Result.selected_background_color := TColor(RGB(213, 232, 241));
                Result.selected_border_color := TColor(RGB(139, 184, 207));
                Result.selected_text_color := TColor(RGB(20, 45, 62));
                Result.selected_user_text_color := TColor(RGB(24, 94, 98));
                Result.selected_lm_compound_text_color := TColor(RGB(14, 84, 137));
                Result.selected_weight_text_color := TColor(RGB(65, 94, 112));
            end;
        4:
            begin
                Result.name := string(WideChar($677E)) + string(WideChar($58A8));
                Result.background_color := TColor(RGB(25, 33, 32));
                Result.border_color := TColor(RGB(71, 88, 82));
                Result.text_color := TColor(RGB(229, 235, 228));
                Result.muted_text_color := TColor(RGB(160, 174, 166));
                Result.weight_text_color := TColor(RGB(147, 161, 153));
                Result.user_text_color := TColor(RGB(133, 216, 152));
                Result.lm_compound_text_color := TColor(RGB(112, 189, 235));
                Result.selected_background_color := TColor(RGB(54, 75, 69));
                Result.selected_border_color := TColor(RGB(94, 128, 116));
                Result.selected_text_color := TColor(RGB(244, 248, 242));
                Result.selected_user_text_color := TColor(RGB(179, 234, 191));
                Result.selected_lm_compound_text_color := TColor(RGB(156, 214, 244));
                Result.selected_weight_text_color := TColor(RGB(187, 200, 193));
            end;
        5:
            begin
                Result.name := string(WideChar($975B)) + string(WideChar($591C));
                Result.background_color := TColor(RGB(26, 34, 56));
                Result.border_color := TColor(RGB(67, 80, 116));
                Result.text_color := TColor(RGB(232, 237, 248));
                Result.muted_text_color := TColor(RGB(166, 176, 204));
                Result.weight_text_color := TColor(RGB(151, 163, 194));
                Result.user_text_color := TColor(RGB(137, 212, 190));
                Result.lm_compound_text_color := TColor(RGB(121, 191, 255));
                Result.selected_background_color := TColor(RGB(48, 65, 103));
                Result.selected_border_color := TColor(RGB(90, 113, 170));
                Result.selected_text_color := TColor(RGB(246, 249, 255));
                Result.selected_user_text_color := TColor(RGB(176, 235, 218));
                Result.selected_lm_compound_text_color := TColor(RGB(171, 216, 255));
                Result.selected_weight_text_color := TColor(RGB(190, 201, 229));
            end;
    else
        begin
            Result.name := string(WideChar($6674)) + string(WideChar($767D));
            Result.background_color := TColor(RGB(252, 253, 255));
            Result.border_color := TColor(RGB(214, 223, 236));
            Result.text_color := TColor(RGB(24, 24, 24));
            Result.muted_text_color := TColor(RGB(98, 112, 128));
            Result.weight_text_color := TColor(RGB(112, 122, 134));
            Result.user_text_color := TColor(RGB(46, 125, 50));
            Result.lm_compound_text_color := TColor(RGB(29, 101, 193));
            Result.selected_background_color := TColor(RGB(232, 240, 254));
            Result.selected_border_color := TColor(RGB(173, 198, 235));
            Result.selected_text_color := TColor(RGB(20, 20, 20));
            Result.selected_user_text_color := TColor(RGB(27, 94, 32));
            Result.selected_lm_compound_text_color := TColor(RGB(23, 79, 154));
            Result.selected_weight_text_color := TColor(RGB(76, 86, 98));
        end;
    end;
    // Keep the row quieter than the selected item in both light and dark themes.
    Result.active_row_background_color := blend_theme_colors(
        Result.background_color, Result.selected_background_color, 40);
    Result.active_row_indicator_color := blend_theme_colors(
        Result.selected_border_color, Result.text_color, 25);
end;

end.
