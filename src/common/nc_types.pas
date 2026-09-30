unit nc_types;

interface

const
    c_default_candidate_font_name = 'Microsoft YaHei UI';
    c_min_candidate_font_size = 7;
    c_default_candidate_font_size = 12;
    c_max_candidate_font_size = 18;
    c_candidate_font_layout_reference_size = 10;
    c_candidate_font_size_level_count = 11;
    c_default_candidate_font_size_level = 5;
    // Preserve every legacy 7..13 value while extending the top end by four steps.
    c_candidate_font_size_levels: array[0..c_candidate_font_size_level_count - 1]
        of Integer = (7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18);
    c_default_candidate_page_size = 9;
    c_min_candidate_page_size = 3;
    c_max_candidate_page_size = 9;
    c_default_candidate_color_scheme = 0;
    c_min_candidate_color_scheme = 0;
    c_max_candidate_color_scheme = 5;
    // Catalogue coverage is selectable by exact input, not predictive evidence.
    c_completion_layer_exact_only_specialist = 4;

type
    TncFuzzyPinyinRule = (
        fpr_z_zh,
        fpr_c_ch,
        fpr_s_sh,
        fpr_l_n,
        fpr_f_h,
        fpr_r_l,
        fpr_an_ang,
        fpr_en_eng,
        fpr_in_ing,
        fpr_ian_iang,
        fpr_uan_uang
    );
    TncFuzzyPinyinRules = set of TncFuzzyPinyinRule;

    TncCandidateSource = (cs_rule, cs_user);
    TncCandidateDisplayKind = (cdk_default, cdk_lm_compound, cdk_sentence_prefix);
    TncLogLevel = (ll_debug, ll_info, ll_warn, ll_error);

    TncCandidate = record
        text: string;
        comment: string;
        score: Integer;
        source: TncCandidateSource;
        has_dict_weight: Boolean;
        dict_weight: Integer;
        fuzzy_cost: Integer;
        fuzzy_rules: TncFuzzyPinyinRules;
        display_kind: TncCandidateDisplayKind;
    end;

    TncCandidateList = array of TncCandidate;

    TncOneKeyCompletionSource = (
        okcs_none,
        okcs_user_exact,
        okcs_base_exact,
        okcs_transition,
        okcs_long_transition,
        okcs_long_neural,
        okcs_document_copy,
        okcs_exact_tail_fallback
    );

    TncOneKeyCompletion = record
        text: string;
        full_pinyin: string;
        path_text: string;
        weight: Integer;
        popularity_prior: Integer;
        corpus_score: Integer;
        document_score: Integer;
        source_count: Integer;
        path_score: Integer;
        vertical_penalty: Integer;
        vertical_layer_kind: Integer;
        has_popularity_prior: Boolean;
        feedback_count: Integer;
        feedback_reject_count: Integer;
        prefix_anchored: Boolean;
        anchor_text: string;
        suffix_text: string;
        anchor_path: string;
        source: TncOneKeyCompletionSource;
    end;

    TncOneKeyCompletionList = array of TncOneKeyCompletion;

    TncLongOneKeyCompletion = record
        anchor_text: string;
        anchor_path: string;
        suffix_pinyin: string;
        suffix_text: string;
        suffix_path: string;
        evidence: Integer;
        source_count: Integer;
        feedback_count: Integer;
        feedback_reject_count: Integer;
    end;

    TncLongOneKeyCompletionList = array of TncLongOneKeyCompletion;

    TncExactTextPath = record
        valid: Boolean;
        text: string;
        full_pinyin: string;
        path_text: string;
        weight: Integer;
        segment_count: Integer;
        unit_count: Integer;
    end;

    TncOneKeyCompletionCompetitionEvidence = record
        context_width: Integer;
        text: string;
        full_pinyin: string;
        evidence_score: Integer;
        occurrence_count: Integer;
        source_count: Integer;
    end;

    TncOneKeyCompletionCompetitionEvidenceList =
        array of TncOneKeyCompletionCompetitionEvidence;

    TncOneKeyCompletionPairAudit = record
        available: Boolean;
        context_width: Integer;
        decision: Integer;
        keep_count: Integer;
        switch_count: Integer;
        confidence_milli: Integer;
    end;

    TncPairPathEvidence = record
        encoded_path: string;
        query_path_weight: Integer;
        lm_transition_weight: Integer;
    end;

    TncPairPathEvidenceList = array of TncPairPathEvidence;

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
    TncPinyinInputScheme = (
        pis_full_pinyin,
        pis_microsoft_shuangpin,
        pis_xiaohe_shuangpin,
        pis_ziranma_shuangpin,
        pis_sogou_shuangpin,
        pis_ziguang_shuangpin,
        pis_pinyinjiajia_shuangpin
    );
    TncDictionaryVariant = (dv_simplified, dv_traditional);
    TncCandidatePageKeyScheme = (
        cpks_minus_plus,
        cpks_brackets,
        cpks_comma_period,
        cpks_shift_tab
    );
    TncOneKeyCompletionKey = (
        ock_tab,
        ock_backtick
    );

    TncShortcutAction = (
        sa_input_mode_toggle,
        sa_punctuation_toggle,
        sa_dictionary_variant_toggle,
        sa_full_width_toggle,
        sa_open_settings
    );

    TncShortcut = record
        key_code: Word;
        shift_down: Boolean;
        ctrl_down: Boolean;
        alt_down: Boolean;
        disabled: Boolean;
    end;

    TncShortcutConfig = record
        signature: Cardinal;
        input_mode_toggle: TncShortcut;
        punctuation_toggle: TncShortcut;
        dictionary_variant_toggle: TncShortcut;
        full_width_toggle: TncShortcut;
        open_settings: TncShortcut;
    end;

    TncEngineConfig = record
        input_mode: TncInputMode;
        pinyin_input_scheme: TncPinyinInputScheme;
        fuzzy_pinyin_enabled: Boolean;
        fuzzy_pinyin_rules: TncFuzzyPinyinRules;
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
        candidate_page_size: Integer;
        candidate_expand_on_paging: Boolean;
        candidate_page_key_scheme: TncCandidatePageKeyScheme;
        one_key_completion_key: TncOneKeyCompletionKey;
        candidate_color_scheme: Integer;
        debug_mode: Boolean;
        dictionary_variant: TncDictionaryVariant;
        shortcuts: TncShortcutConfig;
    end;

implementation

end.
