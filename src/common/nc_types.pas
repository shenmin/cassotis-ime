unit nc_types;

interface

type
    TncCandidateSource = (cs_rule, cs_user);
    TncLogLevel = (ll_debug, ll_info, ll_warn, ll_error);

    TncCandidate = record
        text: string;
        comment: string;
        pinyin: string;
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
        debug_mode: Boolean;
        dictionary_variant: TncDictionaryVariant;
    end;

implementation

end.
