unit nc_types;

interface

const
    c_default_candidate_font_name = 'Microsoft YaHei UI';
    c_default_candidate_font_size = 10;
    c_min_candidate_font_size = c_default_candidate_font_size - 3;
    c_max_candidate_font_size = c_default_candidate_font_size + 3;
    c_default_candidate_color_scheme = 0;
    c_min_candidate_color_scheme = 0;
    c_max_candidate_color_scheme = 5;

type
    TncCandidateSource = (cs_rule, cs_user);
    TncLogLevel = (ll_debug, ll_info, ll_warn, ll_error);

    TncCandidate = record
        text: string;
        comment: string;
        score: Integer;
        source: TncCandidateSource;
        has_dict_weight: Boolean;
        dict_weight: Integer;
    end;

    TncCandidateList = array of TncCandidate;

    TncLogConfig = record
        enabled: Boolean;
        level: TncLogLevel;
        max_size_kb: Integer;
        log_path: string;
    end;

    TncKeyState = record
        shift_down: Boolean;
        ctrl_down: Boolean;
        alt_down: Boolean;
        caps_lock: Boolean;
    end;

    TncInputMode = (im_chinese, im_english);
    TncDictionaryVariant = (dv_simplified, dv_traditional);

    TncEngineConfig = record
        input_mode: TncInputMode;
        max_candidates: Integer;
        enable_ctrl_space_toggle: Boolean;
        enable_shift_space_full_width_toggle: Boolean;
        enable_ctrl_period_punct_toggle: Boolean;
        full_width_mode: Boolean;
        punctuation_full_width: Boolean;
        enable_segment_candidates: Boolean;
        segment_head_only_multi_syllable: Boolean;
        candidate_font_name: string;
        candidate_font_size: Integer;
        candidate_color_scheme: Integer;
        debug_mode: Boolean;
        dictionary_variant: TncDictionaryVariant;
    end;

implementation

end.
