unit nc_long_ranker_features;

{ Candidate and pool features shared by the long-sentence ranking models.
  The final ranker and abstain trees that once read them directly were
  retired in model consolidation step 8; the records and the default
  profile stay for the models built on the same features. }

interface

type
    TncLongFinalRankerFeatures = record
        candidate_score: Integer;
        dict_weight: Integer;
        has_dict_weight: Boolean;
        source_user: Boolean;
        source_chain: Boolean;
        source_pattern: Boolean;
        source_redup: Boolean;
        source_local_rerank: Boolean;
        source_rule_fallback: Boolean;
        legacy_rank: Integer;
        legacy_top: Boolean;
        chain_rank: Integer;
        chain_present: Boolean;
        chain_first_stage_score: Integer;
        chain_second_stage_score: Int64;
        chain_score_gap: Int64;
        complete_match: Boolean;
        partial_match: Boolean;
        text_units: Integer;
        comment_length: Integer;
        unit_delta: Integer;
        path_available: Boolean;
        path_confidence_score: Integer;
        path_confidence_tier: Integer;
        path_segments: Integer;
        path_single_segments: Integer;
        path_max_segment_units: Integer;
        char_lm_score: Integer;
        char_lm_suffix_score: Integer;
        char_lm_context_score: Integer;
        char_lm_context_gain: Integer;
        has_left_context: Boolean;
        query_choice_bonus: Integer;
        latest_query_choice: Boolean;
        query_path_bonus: Integer;
        query_path_penalty: Integer;
        word_lm_bonus: Integer;
        word_lm_boundary_count: Integer;
        word_lm_boundary_min: Integer;
        word_lm_boundary_max: Integer;
        word_lm_boundary_first: Integer;
        word_lm_boundary_last: Integer;
        word_lm_supported_ratio: Integer;
        word_lm_strong_ratio: Integer;
        word_lm_trigram_ratio: Integer;
        word_lm_zero_count: Integer;
        input_syllable_count: Integer;
        score_per_unit: Integer;
        dict_weight_per_unit: Integer;
        complete_user: Boolean;
        complete_dictionary: Boolean;
        complete_chain: Boolean;
        complete_pool_present: Boolean;
        complete_pool_source_kind: Integer;
        complete_pool_rank: Integer;
        complete_pool_seed_rank: Integer;
        complete_pool_original: Boolean;
        complete_pool_substitutions: Integer;
        complete_pool_changed_position: Integer;
        complete_pool_anchor_present: Boolean;
        complete_pool_anchor_start: Integer;
        complete_pool_anchor_units: Integer;
        complete_pool_anchor_exact_rank: Integer;
        complete_pool_anchor_source_weight: Integer;
        complete_pool_anchor_replacement_weight: Integer;
        complete_pool_anchor_top_weight: Integer;
        complete_pool_anchor_weight_gain: Integer;
        complete_pool_pair_evidence: Integer;
        complete_pool_proper_name_confidence: Integer;
        complete_pool_signature_support: Integer;
        complete_pool_consensus_support: Integer;
        complete_pool_consensus_seed_count: Integer;
        complete_pool_consensus_support_mean: Integer;
        complete_pool_consensus_support_min: Integer;
        complete_pool_consensus_majority_units: Integer;
        complete_pool_consensus_unanimous_units: Integer;
        complete_pool_consensus_nearest_distance: Integer;
        complete_pool_consensus_mean_distance: Integer;
        complete_pool_consensus_changed_support: Integer;
        complete_pool_consensus_changed_top_match: Boolean;
        complete_pool_local_pairwise_score: Integer;
        complete_pool_edge_model_anchor_count: Integer;
        complete_pool_edge_model_score_total: Integer;
        complete_pool_edge_model_score_max: Integer;
        complete_pool_edge_model_word_count: Integer;
        complete_pool_edge_model_word_score_total: Integer;
        complete_pool_edge_model_word_score_min: Integer;
        complete_pool_edge_model_word_score_max: Integer;
        complete_pool_edge_model_word_score_mean: Integer;
    end;

    TncLongFinalAbstainFeatures = record
        candidate_count: Integer;
        complete_count: Integer;
        chain_count: Integer;
        input_syllable_count: Integer;
        has_left_context: Boolean;
        ranker_top_score: Int64;
        ranker_second_score: Int64;
        ranker_third_score: Int64;
        ranker_top_margin: Int64;
        ranker_second_margin: Int64;
        ranker_score_range: Int64;
        ranker_top_legacy_rank: Integer;
        ranker_top_chain_rank: Integer;
        ranker_top_complete: Boolean;
        ranker_top_user: Boolean;
        ranker_top_dictionary: Boolean;
        ranker_top_chain: Boolean;
        legacy_top_ranker_score: Int64;
        ranker_top_over_legacy_margin: Int64;
        ranker_disagrees: Boolean;
        legacy_top_complete: Boolean;
        legacy_top_user: Boolean;
        legacy_top_dictionary: Boolean;
        legacy_top_chain: Boolean;
        legacy_top_chain_rank: Integer;
        ranker_top_char_lm_score: Integer;
        legacy_top_char_lm_score: Integer;
        ranker_top_char_lm_gain: Integer;
        ranker_top_path_confidence: Integer;
        legacy_top_path_confidence: Integer;
        ranker_top_path_confidence_gain: Integer;
        ranker_top_query_choice_bonus: Integer;
        legacy_top_query_choice_bonus: Integer;
        ranker_top_pool_source_kind: Integer;
        legacy_top_pool_source_kind: Integer;
        ranker_top_pool_rank: Integer;
        legacy_top_pool_rank: Integer;
        ranker_top_pair_evidence: Integer;
        legacy_top_pair_evidence: Integer;
        ranker_top_word_lm_bonus: Integer;
        legacy_top_word_lm_bonus: Integer;
        ranker_top_word_lm_gain: Integer;
        ranker_top_consensus_support: Integer;
        legacy_top_consensus_support: Integer;
        ranker_top_consensus_gain: Integer;
        ranker_top_proper_name_confidence: Integer;
        legacy_top_proper_name_confidence: Integer;
        ranker_top_local_pairwise_score: Integer;
        legacy_top_local_pairwise_score: Integer;
        ranker_top_edge_model_anchor_count: Integer;
        legacy_top_edge_model_anchor_count: Integer;
        ranker_top_edge_model_anchor_gain: Integer;
        ranker_top_edge_model_score_total: Integer;
        legacy_top_edge_model_score_total: Integer;
        ranker_top_edge_model_score_total_gain: Integer;
        ranker_top_edge_model_score_max: Integer;
        legacy_top_edge_model_score_max: Integer;
        ranker_top_edge_model_score_max_gain: Integer;
        ranker_top_edge_model_word_count: Integer;
        legacy_top_edge_model_word_count: Integer;
        ranker_top_edge_model_word_count_gain: Integer;
        ranker_top_edge_model_word_score_mean: Integer;
        legacy_top_edge_model_word_score_mean: Integer;
        ranker_top_edge_model_word_score_mean_gain: Integer;
        ranker_top_edge_model_word_score_min: Integer;
        legacy_top_edge_model_word_score_min: Integer;
        ranker_top_edge_model_word_score_min_gain: Integer;
    end;

const
    c_long_final_ranker_default_profile: Integer = 2;

implementation

end.
