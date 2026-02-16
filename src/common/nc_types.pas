unit nc_types;

interface

type
    TncCandidateSource = (cs_rule, cs_user, cs_ai);
    TncLogLevel = (ll_debug, ll_info, ll_warn, ll_error);

    TncCandidate = record
        text: string;
        comment: string;
        score: Integer;
        source: TncCandidateSource;
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
    TncLlamaBackend = (lb_auto, lb_cpu, lb_cuda);

    TncEngineConfig = record
        input_mode: TncInputMode;
        max_candidates: Integer;
        enable_ai: Boolean;
        enable_ctrl_space_toggle: Boolean;
        enable_shift_space_full_width_toggle: Boolean;
        enable_ctrl_period_punct_toggle: Boolean;
        full_width_mode: Boolean;
        punctuation_full_width: Boolean;
        enable_segment_candidates: Boolean;
        dictionary_variant: TncDictionaryVariant;
        dictionary_path_simplified: string;
        dictionary_path_traditional: string;
        user_dictionary_path: string;
        ai_llama_backend: TncLlamaBackend;
        ai_llama_runtime_dir_cpu: string;
        ai_llama_runtime_dir_cuda: string;
        ai_llama_model_path: string;
        ai_request_timeout_ms: Integer;
    end;

implementation

end.
