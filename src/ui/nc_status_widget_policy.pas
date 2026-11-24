unit nc_status_widget_policy;

interface

uses
    nc_types;

type
    TncStatusWidgetControl = (
        swc_input_mode,
        swc_dictionary_variant,
        swc_pinyin_scheme,
        swc_full_width,
        swc_punctuation,
        swc_settings
    );

// The Wubi/pinyin mixed scheme types simplified Chinese only: no variant to
// switch to.
function nc_status_widget_control_enabled(const input_mode: TncInputMode;
    const control: TncStatusWidgetControl; const wubi_mixed: Boolean = False): Boolean;

implementation

function nc_status_widget_control_enabled(const input_mode: TncInputMode;
    const control: TncStatusWidgetControl; const wubi_mixed: Boolean): Boolean;
begin
    case control of
        swc_dictionary_variant:
            Result := (input_mode <> im_english) and not wubi_mixed;
        swc_pinyin_scheme,
        swc_punctuation:
            Result := input_mode <> im_english;
    else
        Result := True;
    end;
end;

end.
