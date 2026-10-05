unit nc_long_second_slot_recovery_gate_model;

interface

uses
    nc_long_ranker_features;

type
    TncLongSecondSlotRecoveryGateFeatures = record
        challenger_candidate_score: Int64;
        challenger_dict_weight: Int64;
        challenger_has_dict_weight: Int64;
        challenger_source_user: Int64;
        challenger_source_chain: Int64;
        challenger_source_pattern: Int64;
        challenger_source_redup: Int64;
        challenger_source_local_rerank: Int64;
        challenger_source_rule_fallback: Int64;
        challenger_legacy_rank: Int64;
        challenger_legacy_top: Int64;
        challenger_chain_rank: Int64;
        challenger_chain_present: Int64;
        challenger_chain_first_stage_score: Int64;
        challenger_chain_second_stage_score: Int64;
        challenger_chain_score_gap: Int64;
        challenger_complete_match: Int64;
        challenger_partial_match: Int64;
        challenger_text_units: Int64;
        challenger_comment_length: Int64;
        challenger_unit_delta: Int64;
        challenger_path_available: Int64;
        challenger_path_confidence_score: Int64;
        challenger_path_confidence_tier: Int64;
        challenger_path_segments: Int64;
        challenger_path_single_segments: Int64;
        challenger_path_max_segment_units: Int64;
        challenger_char_lm_score: Int64;
        challenger_char_lm_suffix_score: Int64;
        challenger_char_lm_context_score: Int64;
        challenger_char_lm_context_gain: Int64;
        challenger_has_left_context: Int64;
        challenger_query_choice_bonus: Int64;
        challenger_latest_query_choice: Int64;
        challenger_query_path_bonus: Int64;
        challenger_query_path_penalty: Int64;
        challenger_word_lm_bonus: Int64;
        challenger_word_lm_boundary_count: Int64;
        challenger_word_lm_boundary_min: Int64;
        challenger_word_lm_boundary_max: Int64;
        challenger_word_lm_boundary_first: Int64;
        challenger_word_lm_boundary_last: Int64;
        challenger_word_lm_supported_ratio: Int64;
        challenger_word_lm_strong_ratio: Int64;
        challenger_word_lm_trigram_ratio: Int64;
        challenger_word_lm_zero_count: Int64;
        challenger_input_syllable_count: Int64;
        challenger_score_per_unit: Int64;
        challenger_dict_weight_per_unit: Int64;
        challenger_complete_user: Int64;
        challenger_complete_dictionary: Int64;
        challenger_complete_chain: Int64;
        challenger_complete_pool_present: Int64;
        challenger_complete_pool_source_kind: Int64;
        challenger_complete_pool_rank: Int64;
        challenger_complete_pool_seed_rank: Int64;
        challenger_complete_pool_original: Int64;
        challenger_complete_pool_substitutions: Int64;
        challenger_complete_pool_changed_position: Int64;
        challenger_complete_pool_anchor_present: Int64;
        challenger_complete_pool_anchor_start: Int64;
        challenger_complete_pool_anchor_units: Int64;
        challenger_complete_pool_anchor_exact_rank: Int64;
        challenger_complete_pool_anchor_source_weight: Int64;
        challenger_complete_pool_anchor_replacement_weight: Int64;
        challenger_complete_pool_anchor_top_weight: Int64;
        challenger_complete_pool_anchor_weight_gain: Int64;
        challenger_complete_pool_pair_evidence: Int64;
        challenger_complete_pool_proper_name_confidence: Int64;
        challenger_complete_pool_signature_support: Int64;
        challenger_complete_pool_consensus_support: Int64;
        challenger_complete_pool_consensus_seed_count: Int64;
        challenger_complete_pool_consensus_support_mean: Int64;
        challenger_complete_pool_consensus_support_min: Int64;
        challenger_complete_pool_consensus_majority_units: Int64;
        challenger_complete_pool_consensus_unanimous_units: Int64;
        challenger_complete_pool_consensus_nearest_distance: Int64;
        challenger_complete_pool_consensus_mean_distance: Int64;
        challenger_complete_pool_consensus_changed_support: Int64;
        challenger_complete_pool_consensus_changed_top_match: Int64;
        challenger_complete_pool_local_pairwise_score: Int64;
        delta_second_candidate_score: Int64;
        delta_second_dict_weight: Int64;
        delta_second_has_dict_weight: Int64;
        delta_second_source_user: Int64;
        delta_second_source_chain: Int64;
        delta_second_source_pattern: Int64;
        delta_second_source_redup: Int64;
        delta_second_source_local_rerank: Int64;
        delta_second_source_rule_fallback: Int64;
        delta_second_legacy_rank: Int64;
        delta_second_legacy_top: Int64;
        delta_second_chain_rank: Int64;
        delta_second_chain_present: Int64;
        delta_second_chain_first_stage_score: Int64;
        delta_second_chain_second_stage_score: Int64;
        delta_second_chain_score_gap: Int64;
        delta_second_complete_match: Int64;
        delta_second_partial_match: Int64;
        delta_second_text_units: Int64;
        delta_second_comment_length: Int64;
        delta_second_unit_delta: Int64;
        delta_second_path_available: Int64;
        delta_second_path_confidence_score: Int64;
        delta_second_path_confidence_tier: Int64;
        delta_second_path_segments: Int64;
        delta_second_path_single_segments: Int64;
        delta_second_path_max_segment_units: Int64;
        delta_second_char_lm_score: Int64;
        delta_second_char_lm_suffix_score: Int64;
        delta_second_char_lm_context_score: Int64;
        delta_second_char_lm_context_gain: Int64;
        delta_second_has_left_context: Int64;
        delta_second_query_choice_bonus: Int64;
        delta_second_latest_query_choice: Int64;
        delta_second_query_path_bonus: Int64;
        delta_second_query_path_penalty: Int64;
        delta_second_word_lm_bonus: Int64;
        delta_second_word_lm_boundary_count: Int64;
        delta_second_word_lm_boundary_min: Int64;
        delta_second_word_lm_boundary_max: Int64;
        delta_second_word_lm_boundary_first: Int64;
        delta_second_word_lm_boundary_last: Int64;
        delta_second_word_lm_supported_ratio: Int64;
        delta_second_word_lm_strong_ratio: Int64;
        delta_second_word_lm_trigram_ratio: Int64;
        delta_second_word_lm_zero_count: Int64;
        delta_second_input_syllable_count: Int64;
        delta_second_score_per_unit: Int64;
        delta_second_dict_weight_per_unit: Int64;
        delta_second_complete_user: Int64;
        delta_second_complete_dictionary: Int64;
        delta_second_complete_chain: Int64;
        delta_second_complete_pool_present: Int64;
        delta_second_complete_pool_source_kind: Int64;
        delta_second_complete_pool_rank: Int64;
        delta_second_complete_pool_seed_rank: Int64;
        delta_second_complete_pool_original: Int64;
        delta_second_complete_pool_substitutions: Int64;
        delta_second_complete_pool_changed_position: Int64;
        delta_second_complete_pool_anchor_present: Int64;
        delta_second_complete_pool_anchor_start: Int64;
        delta_second_complete_pool_anchor_units: Int64;
        delta_second_complete_pool_anchor_exact_rank: Int64;
        delta_second_complete_pool_anchor_source_weight: Int64;
        delta_second_complete_pool_anchor_replacement_weight: Int64;
        delta_second_complete_pool_anchor_top_weight: Int64;
        delta_second_complete_pool_anchor_weight_gain: Int64;
        delta_second_complete_pool_pair_evidence: Int64;
        delta_second_complete_pool_proper_name_confidence: Int64;
        delta_second_complete_pool_signature_support: Int64;
        delta_second_complete_pool_consensus_support: Int64;
        delta_second_complete_pool_consensus_seed_count: Int64;
        delta_second_complete_pool_consensus_support_mean: Int64;
        delta_second_complete_pool_consensus_support_min: Int64;
        delta_second_complete_pool_consensus_majority_units: Int64;
        delta_second_complete_pool_consensus_unanimous_units: Int64;
        delta_second_complete_pool_consensus_nearest_distance: Int64;
        delta_second_complete_pool_consensus_mean_distance: Int64;
        delta_second_complete_pool_consensus_changed_support: Int64;
        delta_second_complete_pool_consensus_changed_top_match: Int64;
        delta_second_complete_pool_local_pairwise_score: Int64;
        delta_top_candidate_score: Int64;
        delta_top_dict_weight: Int64;
        delta_top_has_dict_weight: Int64;
        delta_top_source_user: Int64;
        delta_top_source_chain: Int64;
        delta_top_source_pattern: Int64;
        delta_top_source_redup: Int64;
        delta_top_source_local_rerank: Int64;
        delta_top_source_rule_fallback: Int64;
        delta_top_legacy_rank: Int64;
        delta_top_legacy_top: Int64;
        delta_top_chain_rank: Int64;
        delta_top_chain_present: Int64;
        delta_top_chain_first_stage_score: Int64;
        delta_top_chain_second_stage_score: Int64;
        delta_top_chain_score_gap: Int64;
        delta_top_complete_match: Int64;
        delta_top_partial_match: Int64;
        delta_top_text_units: Int64;
        delta_top_comment_length: Int64;
        delta_top_unit_delta: Int64;
        delta_top_path_available: Int64;
        delta_top_path_confidence_score: Int64;
        delta_top_path_confidence_tier: Int64;
        delta_top_path_segments: Int64;
        delta_top_path_single_segments: Int64;
        delta_top_path_max_segment_units: Int64;
        delta_top_char_lm_score: Int64;
        delta_top_char_lm_suffix_score: Int64;
        delta_top_char_lm_context_score: Int64;
        delta_top_char_lm_context_gain: Int64;
        delta_top_has_left_context: Int64;
        delta_top_query_choice_bonus: Int64;
        delta_top_latest_query_choice: Int64;
        delta_top_query_path_bonus: Int64;
        delta_top_query_path_penalty: Int64;
        delta_top_word_lm_bonus: Int64;
        delta_top_word_lm_boundary_count: Int64;
        delta_top_word_lm_boundary_min: Int64;
        delta_top_word_lm_boundary_max: Int64;
        delta_top_word_lm_boundary_first: Int64;
        delta_top_word_lm_boundary_last: Int64;
        delta_top_word_lm_supported_ratio: Int64;
        delta_top_word_lm_strong_ratio: Int64;
        delta_top_word_lm_trigram_ratio: Int64;
        delta_top_word_lm_zero_count: Int64;
        delta_top_input_syllable_count: Int64;
        delta_top_score_per_unit: Int64;
        delta_top_dict_weight_per_unit: Int64;
        delta_top_complete_user: Int64;
        delta_top_complete_dictionary: Int64;
        delta_top_complete_chain: Int64;
        delta_top_complete_pool_present: Int64;
        delta_top_complete_pool_source_kind: Int64;
        delta_top_complete_pool_rank: Int64;
        delta_top_complete_pool_seed_rank: Int64;
        delta_top_complete_pool_original: Int64;
        delta_top_complete_pool_substitutions: Int64;
        delta_top_complete_pool_changed_position: Int64;
        delta_top_complete_pool_anchor_present: Int64;
        delta_top_complete_pool_anchor_start: Int64;
        delta_top_complete_pool_anchor_units: Int64;
        delta_top_complete_pool_anchor_exact_rank: Int64;
        delta_top_complete_pool_anchor_source_weight: Int64;
        delta_top_complete_pool_anchor_replacement_weight: Int64;
        delta_top_complete_pool_anchor_top_weight: Int64;
        delta_top_complete_pool_anchor_weight_gain: Int64;
        delta_top_complete_pool_pair_evidence: Int64;
        delta_top_complete_pool_proper_name_confidence: Int64;
        delta_top_complete_pool_signature_support: Int64;
        delta_top_complete_pool_consensus_support: Int64;
        delta_top_complete_pool_consensus_seed_count: Int64;
        delta_top_complete_pool_consensus_support_mean: Int64;
        delta_top_complete_pool_consensus_support_min: Int64;
        delta_top_complete_pool_consensus_majority_units: Int64;
        delta_top_complete_pool_consensus_unanimous_units: Int64;
        delta_top_complete_pool_consensus_nearest_distance: Int64;
        delta_top_complete_pool_consensus_mean_distance: Int64;
        delta_top_complete_pool_consensus_changed_support: Int64;
        delta_top_complete_pool_consensus_changed_top_match: Int64;
        delta_top_complete_pool_local_pairwise_score: Int64;
        challenger_rank: Int64;
        challenger_ranker_score: Int64;
        second_ranker_score: Int64;
        top_ranker_score: Int64;
        challenger_ranker_score_gap: Int64;
        second_top_ranker_score_gap: Int64;
        different_units: Int64;
        different_runs: Int64;
        max_different_run: Int64;
        same_prefix_units: Int64;
        same_suffix_units: Int64;
        difference_span_units: Int64;
    end;

const
    c_long_second_slot_recovery_gate_feature_count: Integer = 255;
    c_long_second_slot_recovery_gate_tree_count: Integer = 96;
    c_long_second_slot_recovery_gate_score_scale: Double = 100000000.0;
    c_long_second_slot_recovery_gate_threshold: Int64 = -200000000;
    c_long_second_slot_recovery_gate_static_gap: Int64 = 22713568;
    c_long_second_slot_recovery_gate_max_candidate_rank: Integer = 32;
    c_long_second_slot_recovery_gate_reference_score: Int64 = -198538585;
    c_long_second_slot_recovery_gate_reference_score_low: Int64 = -181566608;
    c_long_second_slot_recovery_gate_reference_score_high: Int64 = 11792294;
    c_long_second_slot_recovery_gate_reference_score_mixed: Int64 = -158112367;

procedure build_long_second_slot_recovery_gate_features(
    const challenger_features: TncLongFinalRankerFeatures;
    const second_features: TncLongFinalRankerFeatures;
    const top_features: TncLongFinalRankerFeatures;
    const challenger_rank: Integer;
    const challenger_ranker_score: Int64;
    const second_ranker_score: Int64;
    const top_ranker_score: Int64;
    const different_units: Integer;
    const different_runs: Integer;
    const max_different_run: Integer;
    const same_prefix_units: Integer;
    const same_suffix_units: Integer;
    const difference_span_units: Integer;
    out features: TncLongSecondSlotRecoveryGateFeatures);
function long_second_slot_recovery_gate_score(
    const features: TncLongSecondSlotRecoveryGateFeatures): Int64;
function long_second_slot_recovery_gate_self_test: Boolean;

implementation

{ Complete-pool second-slot recovery gate. It can only reject a proposed
  rank-2 replacement and never changes Top1 or candidate recall. }

procedure build_long_second_slot_recovery_gate_features(
    const challenger_features: TncLongFinalRankerFeatures;
    const second_features: TncLongFinalRankerFeatures;
    const top_features: TncLongFinalRankerFeatures;
    const challenger_rank: Integer;
    const challenger_ranker_score: Int64;
    const second_ranker_score: Int64;
    const top_ranker_score: Int64;
    const different_units: Integer;
    const different_runs: Integer;
    const max_different_run: Integer;
    const same_prefix_units: Integer;
    const same_suffix_units: Integer;
    const difference_span_units: Integer;
    out features: TncLongSecondSlotRecoveryGateFeatures);
begin
    features.challenger_candidate_score := challenger_features.candidate_score;
    features.challenger_dict_weight := challenger_features.dict_weight;
    features.challenger_has_dict_weight := Ord(challenger_features.has_dict_weight);
    features.challenger_source_user := Ord(challenger_features.source_user);
    features.challenger_source_chain := Ord(challenger_features.source_chain);
    features.challenger_source_pattern := Ord(challenger_features.source_pattern);
    features.challenger_source_redup := Ord(challenger_features.source_redup);
    features.challenger_source_local_rerank := Ord(challenger_features.source_local_rerank);
    features.challenger_source_rule_fallback := Ord(challenger_features.source_rule_fallback);
    features.challenger_legacy_rank := challenger_features.legacy_rank;
    features.challenger_legacy_top := Ord(challenger_features.legacy_top);
    features.challenger_chain_rank := challenger_features.chain_rank;
    features.challenger_chain_present := Ord(challenger_features.chain_present);
    features.challenger_chain_first_stage_score := challenger_features.chain_first_stage_score;
    features.challenger_chain_second_stage_score := challenger_features.chain_second_stage_score;
    features.challenger_chain_score_gap := challenger_features.chain_score_gap;
    features.challenger_complete_match := Ord(challenger_features.complete_match);
    features.challenger_partial_match := Ord(challenger_features.partial_match);
    features.challenger_text_units := challenger_features.text_units;
    features.challenger_comment_length := challenger_features.comment_length;
    features.challenger_unit_delta := challenger_features.unit_delta;
    features.challenger_path_available := Ord(challenger_features.path_available);
    features.challenger_path_confidence_score := challenger_features.path_confidence_score;
    features.challenger_path_confidence_tier := challenger_features.path_confidence_tier;
    features.challenger_path_segments := challenger_features.path_segments;
    features.challenger_path_single_segments := challenger_features.path_single_segments;
    features.challenger_path_max_segment_units := challenger_features.path_max_segment_units;
    features.challenger_char_lm_score := challenger_features.char_lm_score;
    features.challenger_char_lm_suffix_score := challenger_features.char_lm_suffix_score;
    features.challenger_char_lm_context_score := challenger_features.char_lm_context_score;
    features.challenger_char_lm_context_gain := challenger_features.char_lm_context_gain;
    features.challenger_has_left_context := Ord(challenger_features.has_left_context);
    features.challenger_query_choice_bonus := challenger_features.query_choice_bonus;
    features.challenger_latest_query_choice := Ord(challenger_features.latest_query_choice);
    features.challenger_query_path_bonus := challenger_features.query_path_bonus;
    features.challenger_query_path_penalty := challenger_features.query_path_penalty;
    features.challenger_word_lm_bonus := challenger_features.word_lm_bonus;
    features.challenger_word_lm_boundary_count := challenger_features.word_lm_boundary_count;
    features.challenger_word_lm_boundary_min := challenger_features.word_lm_boundary_min;
    features.challenger_word_lm_boundary_max := challenger_features.word_lm_boundary_max;
    features.challenger_word_lm_boundary_first := challenger_features.word_lm_boundary_first;
    features.challenger_word_lm_boundary_last := challenger_features.word_lm_boundary_last;
    features.challenger_word_lm_supported_ratio := challenger_features.word_lm_supported_ratio;
    features.challenger_word_lm_strong_ratio := challenger_features.word_lm_strong_ratio;
    features.challenger_word_lm_trigram_ratio := challenger_features.word_lm_trigram_ratio;
    features.challenger_word_lm_zero_count := challenger_features.word_lm_zero_count;
    features.challenger_input_syllable_count := challenger_features.input_syllable_count;
    features.challenger_score_per_unit := challenger_features.score_per_unit;
    features.challenger_dict_weight_per_unit := challenger_features.dict_weight_per_unit;
    features.challenger_complete_user := Ord(challenger_features.complete_user);
    features.challenger_complete_dictionary := Ord(challenger_features.complete_dictionary);
    features.challenger_complete_chain := Ord(challenger_features.complete_chain);
    features.challenger_complete_pool_present := Ord(challenger_features.complete_pool_present);
    features.challenger_complete_pool_source_kind := challenger_features.complete_pool_source_kind;
    features.challenger_complete_pool_rank := challenger_features.complete_pool_rank;
    features.challenger_complete_pool_seed_rank := challenger_features.complete_pool_seed_rank;
    features.challenger_complete_pool_original := Ord(challenger_features.complete_pool_original);
    features.challenger_complete_pool_substitutions := challenger_features.complete_pool_substitutions;
    features.challenger_complete_pool_changed_position := challenger_features.complete_pool_changed_position;
    features.challenger_complete_pool_anchor_present := Ord(challenger_features.complete_pool_anchor_present);
    features.challenger_complete_pool_anchor_start := challenger_features.complete_pool_anchor_start;
    features.challenger_complete_pool_anchor_units := challenger_features.complete_pool_anchor_units;
    features.challenger_complete_pool_anchor_exact_rank := challenger_features.complete_pool_anchor_exact_rank;
    features.challenger_complete_pool_anchor_source_weight := challenger_features.complete_pool_anchor_source_weight;
    features.challenger_complete_pool_anchor_replacement_weight := challenger_features.complete_pool_anchor_replacement_weight;
    features.challenger_complete_pool_anchor_top_weight := challenger_features.complete_pool_anchor_top_weight;
    features.challenger_complete_pool_anchor_weight_gain := challenger_features.complete_pool_anchor_weight_gain;
    features.challenger_complete_pool_pair_evidence := challenger_features.complete_pool_pair_evidence;
    features.challenger_complete_pool_proper_name_confidence := challenger_features.complete_pool_proper_name_confidence;
    features.challenger_complete_pool_signature_support := challenger_features.complete_pool_signature_support;
    features.challenger_complete_pool_consensus_support := challenger_features.complete_pool_consensus_support;
    features.challenger_complete_pool_consensus_seed_count := challenger_features.complete_pool_consensus_seed_count;
    features.challenger_complete_pool_consensus_support_mean := challenger_features.complete_pool_consensus_support_mean;
    features.challenger_complete_pool_consensus_support_min := challenger_features.complete_pool_consensus_support_min;
    features.challenger_complete_pool_consensus_majority_units := challenger_features.complete_pool_consensus_majority_units;
    features.challenger_complete_pool_consensus_unanimous_units := challenger_features.complete_pool_consensus_unanimous_units;
    features.challenger_complete_pool_consensus_nearest_distance := challenger_features.complete_pool_consensus_nearest_distance;
    features.challenger_complete_pool_consensus_mean_distance := challenger_features.complete_pool_consensus_mean_distance;
    features.challenger_complete_pool_consensus_changed_support := challenger_features.complete_pool_consensus_changed_support;
    features.challenger_complete_pool_consensus_changed_top_match := Ord(challenger_features.complete_pool_consensus_changed_top_match);
    features.challenger_complete_pool_local_pairwise_score := challenger_features.complete_pool_local_pairwise_score;
    features.delta_second_candidate_score := challenger_features.candidate_score - second_features.candidate_score;
    features.delta_second_dict_weight := challenger_features.dict_weight - second_features.dict_weight;
    features.delta_second_has_dict_weight := Ord(challenger_features.has_dict_weight) - Ord(second_features.has_dict_weight);
    features.delta_second_source_user := Ord(challenger_features.source_user) - Ord(second_features.source_user);
    features.delta_second_source_chain := Ord(challenger_features.source_chain) - Ord(second_features.source_chain);
    features.delta_second_source_pattern := Ord(challenger_features.source_pattern) - Ord(second_features.source_pattern);
    features.delta_second_source_redup := Ord(challenger_features.source_redup) - Ord(second_features.source_redup);
    features.delta_second_source_local_rerank := Ord(challenger_features.source_local_rerank) - Ord(second_features.source_local_rerank);
    features.delta_second_source_rule_fallback := Ord(challenger_features.source_rule_fallback) - Ord(second_features.source_rule_fallback);
    features.delta_second_legacy_rank := challenger_features.legacy_rank - second_features.legacy_rank;
    features.delta_second_legacy_top := Ord(challenger_features.legacy_top) - Ord(second_features.legacy_top);
    features.delta_second_chain_rank := challenger_features.chain_rank - second_features.chain_rank;
    features.delta_second_chain_present := Ord(challenger_features.chain_present) - Ord(second_features.chain_present);
    features.delta_second_chain_first_stage_score := challenger_features.chain_first_stage_score - second_features.chain_first_stage_score;
    features.delta_second_chain_second_stage_score := challenger_features.chain_second_stage_score - second_features.chain_second_stage_score;
    features.delta_second_chain_score_gap := challenger_features.chain_score_gap - second_features.chain_score_gap;
    features.delta_second_complete_match := Ord(challenger_features.complete_match) - Ord(second_features.complete_match);
    features.delta_second_partial_match := Ord(challenger_features.partial_match) - Ord(second_features.partial_match);
    features.delta_second_text_units := challenger_features.text_units - second_features.text_units;
    features.delta_second_comment_length := challenger_features.comment_length - second_features.comment_length;
    features.delta_second_unit_delta := challenger_features.unit_delta - second_features.unit_delta;
    features.delta_second_path_available := Ord(challenger_features.path_available) - Ord(second_features.path_available);
    features.delta_second_path_confidence_score := challenger_features.path_confidence_score - second_features.path_confidence_score;
    features.delta_second_path_confidence_tier := challenger_features.path_confidence_tier - second_features.path_confidence_tier;
    features.delta_second_path_segments := challenger_features.path_segments - second_features.path_segments;
    features.delta_second_path_single_segments := challenger_features.path_single_segments - second_features.path_single_segments;
    features.delta_second_path_max_segment_units := challenger_features.path_max_segment_units - second_features.path_max_segment_units;
    features.delta_second_char_lm_score := challenger_features.char_lm_score - second_features.char_lm_score;
    features.delta_second_char_lm_suffix_score := challenger_features.char_lm_suffix_score - second_features.char_lm_suffix_score;
    features.delta_second_char_lm_context_score := challenger_features.char_lm_context_score - second_features.char_lm_context_score;
    features.delta_second_char_lm_context_gain := challenger_features.char_lm_context_gain - second_features.char_lm_context_gain;
    features.delta_second_has_left_context := Ord(challenger_features.has_left_context) - Ord(second_features.has_left_context);
    features.delta_second_query_choice_bonus := challenger_features.query_choice_bonus - second_features.query_choice_bonus;
    features.delta_second_latest_query_choice := Ord(challenger_features.latest_query_choice) - Ord(second_features.latest_query_choice);
    features.delta_second_query_path_bonus := challenger_features.query_path_bonus - second_features.query_path_bonus;
    features.delta_second_query_path_penalty := challenger_features.query_path_penalty - second_features.query_path_penalty;
    features.delta_second_word_lm_bonus := challenger_features.word_lm_bonus - second_features.word_lm_bonus;
    features.delta_second_word_lm_boundary_count := challenger_features.word_lm_boundary_count - second_features.word_lm_boundary_count;
    features.delta_second_word_lm_boundary_min := challenger_features.word_lm_boundary_min - second_features.word_lm_boundary_min;
    features.delta_second_word_lm_boundary_max := challenger_features.word_lm_boundary_max - second_features.word_lm_boundary_max;
    features.delta_second_word_lm_boundary_first := challenger_features.word_lm_boundary_first - second_features.word_lm_boundary_first;
    features.delta_second_word_lm_boundary_last := challenger_features.word_lm_boundary_last - second_features.word_lm_boundary_last;
    features.delta_second_word_lm_supported_ratio := challenger_features.word_lm_supported_ratio - second_features.word_lm_supported_ratio;
    features.delta_second_word_lm_strong_ratio := challenger_features.word_lm_strong_ratio - second_features.word_lm_strong_ratio;
    features.delta_second_word_lm_trigram_ratio := challenger_features.word_lm_trigram_ratio - second_features.word_lm_trigram_ratio;
    features.delta_second_word_lm_zero_count := challenger_features.word_lm_zero_count - second_features.word_lm_zero_count;
    features.delta_second_input_syllable_count := challenger_features.input_syllable_count - second_features.input_syllable_count;
    features.delta_second_score_per_unit := challenger_features.score_per_unit - second_features.score_per_unit;
    features.delta_second_dict_weight_per_unit := challenger_features.dict_weight_per_unit - second_features.dict_weight_per_unit;
    features.delta_second_complete_user := Ord(challenger_features.complete_user) - Ord(second_features.complete_user);
    features.delta_second_complete_dictionary := Ord(challenger_features.complete_dictionary) - Ord(second_features.complete_dictionary);
    features.delta_second_complete_chain := Ord(challenger_features.complete_chain) - Ord(second_features.complete_chain);
    features.delta_second_complete_pool_present := Ord(challenger_features.complete_pool_present) - Ord(second_features.complete_pool_present);
    features.delta_second_complete_pool_source_kind := challenger_features.complete_pool_source_kind - second_features.complete_pool_source_kind;
    features.delta_second_complete_pool_rank := challenger_features.complete_pool_rank - second_features.complete_pool_rank;
    features.delta_second_complete_pool_seed_rank := challenger_features.complete_pool_seed_rank - second_features.complete_pool_seed_rank;
    features.delta_second_complete_pool_original := Ord(challenger_features.complete_pool_original) - Ord(second_features.complete_pool_original);
    features.delta_second_complete_pool_substitutions := challenger_features.complete_pool_substitutions - second_features.complete_pool_substitutions;
    features.delta_second_complete_pool_changed_position := challenger_features.complete_pool_changed_position - second_features.complete_pool_changed_position;
    features.delta_second_complete_pool_anchor_present := Ord(challenger_features.complete_pool_anchor_present) - Ord(second_features.complete_pool_anchor_present);
    features.delta_second_complete_pool_anchor_start := challenger_features.complete_pool_anchor_start - second_features.complete_pool_anchor_start;
    features.delta_second_complete_pool_anchor_units := challenger_features.complete_pool_anchor_units - second_features.complete_pool_anchor_units;
    features.delta_second_complete_pool_anchor_exact_rank := challenger_features.complete_pool_anchor_exact_rank - second_features.complete_pool_anchor_exact_rank;
    features.delta_second_complete_pool_anchor_source_weight := challenger_features.complete_pool_anchor_source_weight - second_features.complete_pool_anchor_source_weight;
    features.delta_second_complete_pool_anchor_replacement_weight := challenger_features.complete_pool_anchor_replacement_weight - second_features.complete_pool_anchor_replacement_weight;
    features.delta_second_complete_pool_anchor_top_weight := challenger_features.complete_pool_anchor_top_weight - second_features.complete_pool_anchor_top_weight;
    features.delta_second_complete_pool_anchor_weight_gain := challenger_features.complete_pool_anchor_weight_gain - second_features.complete_pool_anchor_weight_gain;
    features.delta_second_complete_pool_pair_evidence := challenger_features.complete_pool_pair_evidence - second_features.complete_pool_pair_evidence;
    features.delta_second_complete_pool_proper_name_confidence := challenger_features.complete_pool_proper_name_confidence - second_features.complete_pool_proper_name_confidence;
    features.delta_second_complete_pool_signature_support := challenger_features.complete_pool_signature_support - second_features.complete_pool_signature_support;
    features.delta_second_complete_pool_consensus_support := challenger_features.complete_pool_consensus_support - second_features.complete_pool_consensus_support;
    features.delta_second_complete_pool_consensus_seed_count := challenger_features.complete_pool_consensus_seed_count - second_features.complete_pool_consensus_seed_count;
    features.delta_second_complete_pool_consensus_support_mean := challenger_features.complete_pool_consensus_support_mean - second_features.complete_pool_consensus_support_mean;
    features.delta_second_complete_pool_consensus_support_min := challenger_features.complete_pool_consensus_support_min - second_features.complete_pool_consensus_support_min;
    features.delta_second_complete_pool_consensus_majority_units := challenger_features.complete_pool_consensus_majority_units - second_features.complete_pool_consensus_majority_units;
    features.delta_second_complete_pool_consensus_unanimous_units := challenger_features.complete_pool_consensus_unanimous_units - second_features.complete_pool_consensus_unanimous_units;
    features.delta_second_complete_pool_consensus_nearest_distance := challenger_features.complete_pool_consensus_nearest_distance - second_features.complete_pool_consensus_nearest_distance;
    features.delta_second_complete_pool_consensus_mean_distance := challenger_features.complete_pool_consensus_mean_distance - second_features.complete_pool_consensus_mean_distance;
    features.delta_second_complete_pool_consensus_changed_support := challenger_features.complete_pool_consensus_changed_support - second_features.complete_pool_consensus_changed_support;
    features.delta_second_complete_pool_consensus_changed_top_match := Ord(challenger_features.complete_pool_consensus_changed_top_match) - Ord(second_features.complete_pool_consensus_changed_top_match);
    features.delta_second_complete_pool_local_pairwise_score := challenger_features.complete_pool_local_pairwise_score - second_features.complete_pool_local_pairwise_score;
    features.delta_top_candidate_score := challenger_features.candidate_score - top_features.candidate_score;
    features.delta_top_dict_weight := challenger_features.dict_weight - top_features.dict_weight;
    features.delta_top_has_dict_weight := Ord(challenger_features.has_dict_weight) - Ord(top_features.has_dict_weight);
    features.delta_top_source_user := Ord(challenger_features.source_user) - Ord(top_features.source_user);
    features.delta_top_source_chain := Ord(challenger_features.source_chain) - Ord(top_features.source_chain);
    features.delta_top_source_pattern := Ord(challenger_features.source_pattern) - Ord(top_features.source_pattern);
    features.delta_top_source_redup := Ord(challenger_features.source_redup) - Ord(top_features.source_redup);
    features.delta_top_source_local_rerank := Ord(challenger_features.source_local_rerank) - Ord(top_features.source_local_rerank);
    features.delta_top_source_rule_fallback := Ord(challenger_features.source_rule_fallback) - Ord(top_features.source_rule_fallback);
    features.delta_top_legacy_rank := challenger_features.legacy_rank - top_features.legacy_rank;
    features.delta_top_legacy_top := Ord(challenger_features.legacy_top) - Ord(top_features.legacy_top);
    features.delta_top_chain_rank := challenger_features.chain_rank - top_features.chain_rank;
    features.delta_top_chain_present := Ord(challenger_features.chain_present) - Ord(top_features.chain_present);
    features.delta_top_chain_first_stage_score := challenger_features.chain_first_stage_score - top_features.chain_first_stage_score;
    features.delta_top_chain_second_stage_score := challenger_features.chain_second_stage_score - top_features.chain_second_stage_score;
    features.delta_top_chain_score_gap := challenger_features.chain_score_gap - top_features.chain_score_gap;
    features.delta_top_complete_match := Ord(challenger_features.complete_match) - Ord(top_features.complete_match);
    features.delta_top_partial_match := Ord(challenger_features.partial_match) - Ord(top_features.partial_match);
    features.delta_top_text_units := challenger_features.text_units - top_features.text_units;
    features.delta_top_comment_length := challenger_features.comment_length - top_features.comment_length;
    features.delta_top_unit_delta := challenger_features.unit_delta - top_features.unit_delta;
    features.delta_top_path_available := Ord(challenger_features.path_available) - Ord(top_features.path_available);
    features.delta_top_path_confidence_score := challenger_features.path_confidence_score - top_features.path_confidence_score;
    features.delta_top_path_confidence_tier := challenger_features.path_confidence_tier - top_features.path_confidence_tier;
    features.delta_top_path_segments := challenger_features.path_segments - top_features.path_segments;
    features.delta_top_path_single_segments := challenger_features.path_single_segments - top_features.path_single_segments;
    features.delta_top_path_max_segment_units := challenger_features.path_max_segment_units - top_features.path_max_segment_units;
    features.delta_top_char_lm_score := challenger_features.char_lm_score - top_features.char_lm_score;
    features.delta_top_char_lm_suffix_score := challenger_features.char_lm_suffix_score - top_features.char_lm_suffix_score;
    features.delta_top_char_lm_context_score := challenger_features.char_lm_context_score - top_features.char_lm_context_score;
    features.delta_top_char_lm_context_gain := challenger_features.char_lm_context_gain - top_features.char_lm_context_gain;
    features.delta_top_has_left_context := Ord(challenger_features.has_left_context) - Ord(top_features.has_left_context);
    features.delta_top_query_choice_bonus := challenger_features.query_choice_bonus - top_features.query_choice_bonus;
    features.delta_top_latest_query_choice := Ord(challenger_features.latest_query_choice) - Ord(top_features.latest_query_choice);
    features.delta_top_query_path_bonus := challenger_features.query_path_bonus - top_features.query_path_bonus;
    features.delta_top_query_path_penalty := challenger_features.query_path_penalty - top_features.query_path_penalty;
    features.delta_top_word_lm_bonus := challenger_features.word_lm_bonus - top_features.word_lm_bonus;
    features.delta_top_word_lm_boundary_count := challenger_features.word_lm_boundary_count - top_features.word_lm_boundary_count;
    features.delta_top_word_lm_boundary_min := challenger_features.word_lm_boundary_min - top_features.word_lm_boundary_min;
    features.delta_top_word_lm_boundary_max := challenger_features.word_lm_boundary_max - top_features.word_lm_boundary_max;
    features.delta_top_word_lm_boundary_first := challenger_features.word_lm_boundary_first - top_features.word_lm_boundary_first;
    features.delta_top_word_lm_boundary_last := challenger_features.word_lm_boundary_last - top_features.word_lm_boundary_last;
    features.delta_top_word_lm_supported_ratio := challenger_features.word_lm_supported_ratio - top_features.word_lm_supported_ratio;
    features.delta_top_word_lm_strong_ratio := challenger_features.word_lm_strong_ratio - top_features.word_lm_strong_ratio;
    features.delta_top_word_lm_trigram_ratio := challenger_features.word_lm_trigram_ratio - top_features.word_lm_trigram_ratio;
    features.delta_top_word_lm_zero_count := challenger_features.word_lm_zero_count - top_features.word_lm_zero_count;
    features.delta_top_input_syllable_count := challenger_features.input_syllable_count - top_features.input_syllable_count;
    features.delta_top_score_per_unit := challenger_features.score_per_unit - top_features.score_per_unit;
    features.delta_top_dict_weight_per_unit := challenger_features.dict_weight_per_unit - top_features.dict_weight_per_unit;
    features.delta_top_complete_user := Ord(challenger_features.complete_user) - Ord(top_features.complete_user);
    features.delta_top_complete_dictionary := Ord(challenger_features.complete_dictionary) - Ord(top_features.complete_dictionary);
    features.delta_top_complete_chain := Ord(challenger_features.complete_chain) - Ord(top_features.complete_chain);
    features.delta_top_complete_pool_present := Ord(challenger_features.complete_pool_present) - Ord(top_features.complete_pool_present);
    features.delta_top_complete_pool_source_kind := challenger_features.complete_pool_source_kind - top_features.complete_pool_source_kind;
    features.delta_top_complete_pool_rank := challenger_features.complete_pool_rank - top_features.complete_pool_rank;
    features.delta_top_complete_pool_seed_rank := challenger_features.complete_pool_seed_rank - top_features.complete_pool_seed_rank;
    features.delta_top_complete_pool_original := Ord(challenger_features.complete_pool_original) - Ord(top_features.complete_pool_original);
    features.delta_top_complete_pool_substitutions := challenger_features.complete_pool_substitutions - top_features.complete_pool_substitutions;
    features.delta_top_complete_pool_changed_position := challenger_features.complete_pool_changed_position - top_features.complete_pool_changed_position;
    features.delta_top_complete_pool_anchor_present := Ord(challenger_features.complete_pool_anchor_present) - Ord(top_features.complete_pool_anchor_present);
    features.delta_top_complete_pool_anchor_start := challenger_features.complete_pool_anchor_start - top_features.complete_pool_anchor_start;
    features.delta_top_complete_pool_anchor_units := challenger_features.complete_pool_anchor_units - top_features.complete_pool_anchor_units;
    features.delta_top_complete_pool_anchor_exact_rank := challenger_features.complete_pool_anchor_exact_rank - top_features.complete_pool_anchor_exact_rank;
    features.delta_top_complete_pool_anchor_source_weight := challenger_features.complete_pool_anchor_source_weight - top_features.complete_pool_anchor_source_weight;
    features.delta_top_complete_pool_anchor_replacement_weight := challenger_features.complete_pool_anchor_replacement_weight - top_features.complete_pool_anchor_replacement_weight;
    features.delta_top_complete_pool_anchor_top_weight := challenger_features.complete_pool_anchor_top_weight - top_features.complete_pool_anchor_top_weight;
    features.delta_top_complete_pool_anchor_weight_gain := challenger_features.complete_pool_anchor_weight_gain - top_features.complete_pool_anchor_weight_gain;
    features.delta_top_complete_pool_pair_evidence := challenger_features.complete_pool_pair_evidence - top_features.complete_pool_pair_evidence;
    features.delta_top_complete_pool_proper_name_confidence := challenger_features.complete_pool_proper_name_confidence - top_features.complete_pool_proper_name_confidence;
    features.delta_top_complete_pool_signature_support := challenger_features.complete_pool_signature_support - top_features.complete_pool_signature_support;
    features.delta_top_complete_pool_consensus_support := challenger_features.complete_pool_consensus_support - top_features.complete_pool_consensus_support;
    features.delta_top_complete_pool_consensus_seed_count := challenger_features.complete_pool_consensus_seed_count - top_features.complete_pool_consensus_seed_count;
    features.delta_top_complete_pool_consensus_support_mean := challenger_features.complete_pool_consensus_support_mean - top_features.complete_pool_consensus_support_mean;
    features.delta_top_complete_pool_consensus_support_min := challenger_features.complete_pool_consensus_support_min - top_features.complete_pool_consensus_support_min;
    features.delta_top_complete_pool_consensus_majority_units := challenger_features.complete_pool_consensus_majority_units - top_features.complete_pool_consensus_majority_units;
    features.delta_top_complete_pool_consensus_unanimous_units := challenger_features.complete_pool_consensus_unanimous_units - top_features.complete_pool_consensus_unanimous_units;
    features.delta_top_complete_pool_consensus_nearest_distance := challenger_features.complete_pool_consensus_nearest_distance - top_features.complete_pool_consensus_nearest_distance;
    features.delta_top_complete_pool_consensus_mean_distance := challenger_features.complete_pool_consensus_mean_distance - top_features.complete_pool_consensus_mean_distance;
    features.delta_top_complete_pool_consensus_changed_support := challenger_features.complete_pool_consensus_changed_support - top_features.complete_pool_consensus_changed_support;
    features.delta_top_complete_pool_consensus_changed_top_match := Ord(challenger_features.complete_pool_consensus_changed_top_match) - Ord(top_features.complete_pool_consensus_changed_top_match);
    features.delta_top_complete_pool_local_pairwise_score := challenger_features.complete_pool_local_pairwise_score - top_features.complete_pool_local_pairwise_score;
    features.challenger_rank := challenger_rank;
    features.challenger_ranker_score := challenger_ranker_score;
    features.second_ranker_score := second_ranker_score;
    features.top_ranker_score := top_ranker_score;
    features.challenger_ranker_score_gap := challenger_ranker_score - second_ranker_score;
    features.second_top_ranker_score_gap := second_ranker_score - top_ranker_score;
    features.different_units := different_units;
    features.different_runs := different_runs;
    features.max_different_run := max_different_run;
    features.same_prefix_units := same_prefix_units;
    features.same_suffix_units := same_suffix_units;
    features.difference_span_units := difference_span_units;
end;

function second_slot_recovery_gate_tree_0(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.55860776855206129;
        end
        else
        begin
            Result := -0.53046056068513803;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 122314460.00000001 then
        begin
            if features.challenger_complete_pool_consensus_mean_distance <= 5562.5000000000009 then
            begin
                Result := -0.53738068224224167;
            end
            else
            begin
                if features.delta_second_word_lm_zero_count <= -1.0000000180025095E-35 then
                begin
                    if features.challenger_rank <= 4.5000000000000009 then
                    begin
                        if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
                        begin
                            Result := -0.53281120437252627;
                        end
                        else
                        begin
                            Result := -0.49865469282174268;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_signature_support <= -5.4999999999999991 then
                        begin
                            Result := -0.50853169769238904;
                        end
                        else
                        begin
                            if features.delta_top_complete_pool_consensus_support_min <= -574.99999999999989 then
                            begin
                                Result := -0.49971794691055393;
                            end
                            else
                            begin
                                Result := -0.45223449338477378;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_support <= 757.50000000000011 then
                    begin
                        Result := -0.53431283761313109;
                    end
                    else
                    begin
                        if features.delta_second_dict_weight <= -102557.49999999999 then
                        begin
                            Result := -0.52273875112810086;
                        end
                        else
                        begin
                            Result := -0.49772116746330725;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 237445520.00000003 then
            begin
                if features.delta_second_word_lm_supported_ratio <= 68.000000000000014 then
                begin
                    if features.delta_top_dict_weight <= -69773.999999999985 then
                    begin
                        Result := -0.47889747926228982;
                    end
                    else
                    begin
                        Result := -0.51453583714559004;
                    end;
                end
                else
                begin
                    Result := -0.4591482704418397;
                end;
            end
            else
            begin
                Result := -0.43706342933535786;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_1(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_suffix_score <= 309.00000000000006 then
        begin
            Result := -0.041094089775765813;
        end
        else
        begin
            Result := -0.012644166700682059;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 122314460.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                if features.challenger_ranker_score_gap <= 77408280.000000015 then
                begin
                    Result := -0.025186559336924239;
                end
                else
                begin
                    Result := -3.9941103905607902E-05;
                end;
            end
            else
            begin
                if features.challenger_path_single_segments <= 4.5000000000000009 then
                begin
                    if features.delta_second_legacy_rank <= 3.5000000000000004 then
                    begin
                        if features.challenger_char_lm_suffix_score <= -6454.4999999999991 then
                        begin
                            Result := 0.024075658296770761;
                        end
                        else
                        begin
                            Result := -0.0044892125434002044;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_word_lm_supported_ratio <= 45.000000000000007 then
                        begin
                            if features.challenger_char_lm_score <= -5448.9999999999991 then
                            begin
                                Result := 0.040124979399002711;
                            end
                            else
                            begin
                                Result := 0.0045174057032595525;
                            end;
                        end
                        else
                        begin
                            Result := 0.057392289082044259;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.012710920042242469;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 243601632.00000003 then
            begin
                if features.challenger_chain_score_gap <= -18008201.999999996 then
                begin
                    Result := -0.0030902938889227176;
                end
                else
                begin
                    if features.delta_second_word_lm_strong_ratio <= 55.500000000000007 then
                    begin
                        if features.delta_second_complete_pool_signature_support <= 5.5000000000000009 then
                        begin
                            Result := 0.034536720649558289;
                        end
                        else
                        begin
                            Result := -0.0017269411435499389;
                        end;
                    end
                    else
                    begin
                        Result := 0.059177447863621141;
                    end;
                end;
            end
            else
            begin
                Result := 0.075817952615014894;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_2(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.04250700002532487;
        end
        else
        begin
            Result := -0.013150573374920657;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 122314460.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                if features.delta_top_char_lm_score <= -105.49999999999999 then
                begin
                    Result := -0.030942136674097235;
                end
                else
                begin
                    Result := 0.00054886160643848676;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 1.0000000180025095E-35 then
                begin
                    if features.delta_top_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.014763215435088012;
                    end
                    else
                    begin
                        Result := 0.01111600875570839;
                    end;
                end
                else
                begin
                    if features.delta_second_word_lm_boundary_max <= 24.000000000000004 then
                    begin
                        if features.challenger_word_lm_boundary_last <= 1282.5000000000002 then
                        begin
                            Result := 0.06152607346675687;
                        end
                        else
                        begin
                            Result := 0.015094197714376414;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_word_lm_zero_count <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.027379152904519748;
                        end
                        else
                        begin
                            Result := -0.0068688469437062109;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_chain_score_gap <= -18810906.999999996 then
            begin
                Result := 0.0073826145810727386;
            end
            else
            begin
                if features.challenger_ranker_score_gap <= 256098640.00000003 then
                begin
                    if features.delta_second_word_lm_strong_ratio <= 55.500000000000007 then
                    begin
                        if features.delta_top_dict_weight <= -116496.49999999999 then
                        begin
                            Result := 0.048914042046873905;
                        end
                        else
                        begin
                            Result := 0.014074717098500606;
                        end;
                    end
                    else
                    begin
                        Result := 0.058948613192354789;
                    end;
                end
                else
                begin
                    Result := 0.073766079622192546;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_3(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.041081980066712237;
        end
        else
        begin
            Result := -0.015299107903090546;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 120454796.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                Result := -0.019884314225348376;
            end
            else
            begin
                if features.challenger_char_lm_suffix_score <= -6454.4999999999991 then
                begin
                    if features.difference_span_units <= 2.5000000000000004 then
                    begin
                        Result := 4.0130054394470424E-05;
                    end
                    else
                    begin
                        if features.challenger_path_single_segments <= 2.5000000000000004 then
                        begin
                            Result := 0.060303121368168545;
                        end
                        else
                        begin
                            Result := 0.010808593245093765;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_dict_weight_per_unit <= -10462.999999999998 then
                    begin
                        Result := -0.0195554512542194;
                    end
                    else
                    begin
                        if features.delta_top_word_lm_bonus <= 22.000000000000004 then
                        begin
                            if features.delta_second_char_lm_score <= 371.50000000000006 then
                            begin
                                Result := -0.013464716721827912;
                            end
                            else
                            begin
                                Result := 0.020861875906465033;
                            end;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_pair_evidence <= 2520.0000000000005 then
                            begin
                                Result := 0.0052783838834138857;
                            end
                            else
                            begin
                                Result := 0.055760940078258957;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -372362463.99999994 then
            begin
                Result := 0.067868117529556349;
            end
            else
            begin
                if features.challenger_word_lm_supported_ratio <= 256.50000000000006 then
                begin
                    if features.delta_top_char_lm_suffix_score <= -131.49999999999997 then
                    begin
                        Result := -0.010594074812058782;
                    end
                    else
                    begin
                        Result := 0.023938739323869394;
                    end;
                end
                else
                begin
                    Result := 0.052811633307685374;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_4(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_suffix_score <= 214.50000000000003 then
        begin
            Result := -0.039383887706576755;
        end
        else
        begin
            Result := -0.016762144068779489;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_second_legacy_rank <= 3.5000000000000004 then
            begin
                if features.delta_second_char_lm_score <= 221.50000000000003 then
                begin
                    if features.delta_second_word_lm_supported_ratio <= 142.50000000000003 then
                    begin
                        Result := -0.024803826298533043;
                    end
                    else
                    begin
                        Result := -0.0015178744790389639;
                    end;
                end
                else
                begin
                    if features.delta_top_path_single_segments <= 1.5000000000000002 then
                    begin
                        Result := -0.0036708794610236148;
                    end
                    else
                    begin
                        Result := 0.030305600390354993;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_path_single_segments <= 1.5000000000000002 then
                begin
                    if features.difference_span_units <= 1.5000000000000002 then
                    begin
                        Result := 0.0041094496487815062;
                    end
                    else
                    begin
                        if features.delta_top_legacy_rank <= 7.5000000000000009 then
                        begin
                            Result := 0.013442516172382887;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_anchor_replacement_weight <= 540.50000000000011 then
                            begin
                                Result := 0.066635669836604516;
                            end
                            else
                            begin
                                Result := 0.01492143718708344;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.01171993144982573;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 237445520.00000003 then
            begin
                if features.challenger_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                begin
                    Result := -0.0041724146554409734;
                end
                else
                begin
                    if features.delta_second_word_lm_supported_ratio <= 68.000000000000014 then
                    begin
                        Result := 0.022391450498266314;
                    end
                    else
                    begin
                        Result := 0.054759615959182516;
                    end;
                end;
            end
            else
            begin
                Result := 0.064459141450604676;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_5(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.039092823724483243;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 65333888.000000007 then
            begin
                Result := -0.031828660043628783;
            end
            else
            begin
                Result := -0.00012679812379354241;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.challenger_score_per_unit <= 4517.5000000000009 then
                begin
                    if features.delta_second_legacy_rank <= 1.5000000000000002 then
                    begin
                        Result := -0.011517202333661306;
                    end
                    else
                    begin
                        if features.challenger_word_lm_supported_ratio <= 207.00000000000003 then
                        begin
                            Result := 0.039943612117321114;
                        end
                        else
                        begin
                            Result := 0.0056786790435598379;
                        end;
                    end;
                end
                else
                begin
                    if features.challenger_ranker_score_gap <= 89379856.000000015 then
                    begin
                        Result := -0.018287664481699321;
                    end
                    else
                    begin
                        Result := 0.006825497518910555;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_dict_weight_per_unit <= -10529.499999999998 then
                begin
                    Result := -0.007440411683863446;
                end
                else
                begin
                    if features.delta_second_char_lm_score <= 210.50000000000003 then
                    begin
                        Result := 0.0083809490322504909;
                    end
                    else
                    begin
                        Result := 0.045409948322792125;
                    end;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -372362463.99999994 then
            begin
                Result := 0.0610164923460512;
            end
            else
            begin
                if features.delta_second_complete_pool_source_kind <= 1.0000000180025095E-35 then
                begin
                    Result := -0.0042850109538891418;
                end
                else
                begin
                    if features.challenger_word_lm_bonus <= 357.50000000000006 then
                    begin
                        Result := 0.02242268556372963;
                    end
                    else
                    begin
                        Result := 0.049430159584954614;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_6(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 285.50000000000006 then
        begin
            Result := -0.037262966064084996;
        end
        else
        begin
            Result := -0.010153862016361429;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                if features.delta_top_char_lm_score <= -105.49999999999999 then
                begin
                    Result := -0.029868866984319675;
                end
                else
                begin
                    Result := -0.0031859742594470544;
                end;
            end
            else
            begin
                if features.delta_top_word_lm_bonus <= 1.0000000180025095E-35 then
                begin
                    if features.delta_top_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_second_char_lm_score <= 221.50000000000003 then
                        begin
                            Result := -0.0088342589155433835;
                        end
                        else
                        begin
                            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.036183758856612597;
                            end
                            else
                            begin
                                Result := -0.0039137998114230806;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.022256691505429579;
                    end;
                end
                else
                begin
                    if features.delta_top_word_lm_boundary_count <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.041005982962181067;
                    end
                    else
                    begin
                        Result := 0.0;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 269634064.00000006 then
            begin
                if features.challenger_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                begin
                    Result := -0.0024804543417328985;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -126509.49999999999 then
                    begin
                        Result := 0.062360293981846768;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_strong_ratio <= 55.500000000000007 then
                        begin
                            Result := 0.011257428667170378;
                        end
                        else
                        begin
                            Result := 0.04501111544963951;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.062975046171884166;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_7(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.038119179247468576;
        end
        else
        begin
            Result := -0.014290375621462488;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.delta_top_dict_weight <= -101029.49999999999 then
                begin
                    if features.delta_second_legacy_rank <= 1.5000000000000002 then
                    begin
                        Result := -0.012496438262958086;
                    end
                    else
                    begin
                        if features.challenger_complete_pool_pair_evidence <= 1558.5000000000002 then
                        begin
                            if features.delta_second_char_lm_score <= 180.50000000000003 then
                            begin
                                Result := 0.0036385490738994916;
                            end
                            else
                            begin
                                Result := 0.047654399548993059;
                            end;
                        end
                        else
                        begin
                            Result := -0.0085006903829219927;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_top_char_lm_score <= 127.50000000000001 then
                    begin
                        Result := -0.018174153144773782;
                    end
                    else
                    begin
                        Result := 0.013320780491344338;
                    end;
                end;
            end
            else
            begin
                if features.challenger_word_lm_boundary_max <= 1441.5000000000002 then
                begin
                    Result := 0.0022080199318693524;
                end
                else
                begin
                    Result := 0.035831004094235369;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 237445520.00000003 then
            begin
                if features.challenger_word_lm_bonus <= 357.50000000000006 then
                begin
                    if features.delta_top_dict_weight <= -135963.49999999997 then
                    begin
                        Result := 0.037399941279581142;
                    end
                    else
                    begin
                        if features.delta_second_legacy_rank <= 2.5000000000000004 then
                        begin
                            Result := -0.012825880895267939;
                        end
                        else
                        begin
                            Result := 0.01972232220607717;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.041304742404559731;
                end;
            end
            else
            begin
                Result := 0.059522032951859663;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_8(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_suffix_score <= 127.50000000000001 then
        begin
            Result := -0.03711463419629632;
        end
        else
        begin
            Result := -0.014596878659911135;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_score <= 517.00000000000011 then
        begin
            if features.delta_second_legacy_rank <= 3.5000000000000004 then
            begin
                if features.delta_second_word_lm_supported_ratio <= 142.50000000000003 then
                begin
                    if features.challenger_score_per_unit <= 4378.5000000000009 then
                    begin
                        Result := -0.0023649252347114364;
                    end
                    else
                    begin
                        Result := -0.023802288778184102;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_pair_evidence <= 2416.5000000000005 then
                    begin
                        Result := 0.027698887222565239;
                    end
                    else
                    begin
                        Result := -0.0075884182659667482;
                    end;
                end;
            end
            else
            begin
                if features.max_different_run <= 1.5000000000000002 then
                begin
                    if features.delta_second_word_lm_bonus <= 4.5000000000000009 then
                    begin
                        Result := -0.020608235775749894;
                    end
                    else
                    begin
                        Result := 0.023973615165475009;
                    end;
                end
                else
                begin
                    if features.challenger_path_single_segments <= 3.5000000000000004 then
                    begin
                        Result := 0.051285511294275457;
                    end
                    else
                    begin
                        Result := 0.0050393214308173829;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_supported_ratio <= 68.000000000000014 then
            begin
                if features.delta_second_dict_weight_per_unit <= -10886.499999999998 then
                begin
                    if features.second_ranker_score <= -28149598.999999996 then
                    begin
                        Result := 0.013328408480759514;
                    end
                    else
                    begin
                        Result := -0.023657715012453302;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_unanimous_units <= 4.5000000000000009 then
                    begin
                        Result := 0.010956820591200813;
                    end
                    else
                    begin
                        Result := 0.047080499785152177;
                    end;
                end;
            end
            else
            begin
                Result := 0.047237109081042311;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_9(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.035641225530957568;
        end
        else
        begin
            if features.delta_second_complete_pool_anchor_replacement_weight <= -229.49999999999997 then
            begin
                Result := 0.0033055095280044096;
            end
            else
            begin
                Result := -0.030367890671052514;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 120454796.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                if features.delta_top_char_lm_score <= -105.49999999999999 then
                begin
                    Result := -0.026581935526223059;
                end
                else
                begin
                    Result := -0.0048188185081363038;
                end;
            end
            else
            begin
                if features.challenger_path_single_segments <= 4.5000000000000009 then
                begin
                    if features.difference_span_units <= 2.5000000000000004 then
                    begin
                        if features.delta_top_char_lm_score <= 72.500000000000014 then
                        begin
                            if features.delta_second_complete_pool_consensus_nearest_distance <= 6.5000000000000009 then
                            begin
                                Result := -0.017510863499004402;
                            end
                            else
                            begin
                                Result := 0.0083021279237364114;
                            end;
                        end
                        else
                        begin
                            Result := 0.027798747721252539;
                        end;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -6337.9999999999991 then
                        begin
                            Result := 0.050718596572097784;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_nearest_distance <= 8.5000000000000018 then
                            begin
                                Result := -0.0039205229873613325;
                            end
                            else
                            begin
                                Result := 0.031860330921097059;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.01392504596779481;
                end;
            end;
        end
        else
        begin
            if features.challenger_chain_score_gap <= -18810906.999999996 then
            begin
                Result := 0.002368132902770249;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= -52.499999999999993 then
                begin
                    Result := 0.0030601915813027823;
                end
                else
                begin
                    Result := 0.047964669091042279;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_10(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 185.00000000000003 then
        begin
            Result := -0.03617751430234202;
        end
        else
        begin
            Result := -0.011766537869716404;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 122314460.00000001 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.challenger_score_per_unit <= 4485.5000000000009 then
                begin
                    if features.delta_top_char_lm_context_score <= 253.50000000000003 then
                    begin
                        if features.delta_top_char_lm_score <= -125.49999999999999 then
                        begin
                            Result := -0.0018936840550669131;
                        end
                        else
                        begin
                            Result := 0.037838295643989418;
                        end;
                    end
                    else
                    begin
                        Result := -0.013968163199287544;
                    end;
                end
                else
                begin
                    if features.delta_second_word_lm_strong_ratio <= 195.50000000000003 then
                    begin
                        if features.delta_top_dict_weight <= -116496.49999999999 then
                        begin
                            Result := 0.0018924835468969465;
                        end
                        else
                        begin
                            Result := -0.023304760636704506;
                        end;
                    end
                    else
                    begin
                        Result := 0.0076765069077727082;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_word_lm_strong_ratio <= -35.999999999999993 then
                begin
                    Result := -0.0068106041724308045;
                end
                else
                begin
                    Result := 0.029300873865491156;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 256098640.00000003 then
            begin
                if features.challenger_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                begin
                    Result := -0.0017762657766655034;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -137868.49999999997 then
                    begin
                        Result := 0.056131504490316862;
                    end
                    else
                    begin
                        if features.delta_second_legacy_rank <= 2.5000000000000004 then
                        begin
                            Result := 0.0069003597648762899;
                        end
                        else
                        begin
                            Result := 0.033735677685653664;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.057032913328471629;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_11(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_suffix_score <= 127.50000000000001 then
        begin
            Result := -0.035604001683832133;
        end
        else
        begin
            Result := -0.012969867304801846;
        end;
    end
    else
    begin
        if features.second_top_ranker_score_gap <= -386976639.99999994 then
        begin
            if features.delta_second_chain_first_stage_score <= -71003.499999999985 then
            begin
                Result := -0.0057618537954911668;
            end
            else
            begin
                Result := 0.052543980331693198;
            end;
        end
        else
        begin
            if features.delta_top_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
            begin
                Result := -0.016392807830496167;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 44.500000000000007 then
                begin
                    if features.challenger_score_per_unit <= 4457.5000000000009 then
                    begin
                        Result := 0.015836407706382394;
                    end
                    else
                    begin
                        if features.delta_top_dict_weight <= -118397.99999999999 then
                        begin
                            Result := 0.011489530088574285;
                        end
                        else
                        begin
                            if features.delta_second_path_single_segments <= 1.5000000000000002 then
                            begin
                                if features.challenger_rank <= 6.5000000000000009 then
                                begin
                                    Result := -0.015725644023978528;
                                end
                                else
                                begin
                                    Result := 0.019626639756171956;
                                end;
                            end
                            else
                            begin
                                Result := -0.028052956522242097;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_char_lm_score <= -97.499999999999986 then
                    begin
                        Result := -0.0016523352776726852;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                        begin
                            Result := 0.0049726513842229805;
                        end
                        else
                        begin
                            if features.delta_second_word_lm_boundary_max <= 160.50000000000003 then
                            begin
                                Result := 0.053385483865855211;
                            end
                            else
                            begin
                                if features.delta_second_score_per_unit <= -7754.9999999999991 then
                                begin
                                    Result := 0.051044732081412025;
                                end
                                else
                                begin
                                    Result := 0.0017309733463080172;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_12(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.033761638790212406;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 65333888.000000007 then
            begin
                Result := -0.029404181393906451;
            end
            else
            begin
                Result := 0.00056762494842087208;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 120454796.00000001 then
        begin
            if features.challenger_rank <= 4.5000000000000009 then
            begin
                Result := -0.010415145396185948;
            end
            else
            begin
                if features.delta_second_path_single_segments <= 1.5000000000000002 then
                begin
                    if features.delta_second_word_lm_supported_ratio <= 41.500000000000007 then
                    begin
                        Result := 0.0073294276977387872;
                    end
                    else
                    begin
                        if features.delta_top_complete_pool_consensus_support_min <= -574.99999999999989 then
                        begin
                            Result := 0.011415031650212931;
                        end
                        else
                        begin
                            Result := 0.060642906255158432;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_complete_pool_consensus_support_min <= -279.49999999999994 then
                    begin
                        Result := 0.0070319672903701481;
                    end
                    else
                    begin
                        Result := -0.024189048568214216;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_chain_score_gap <= -18810906.999999996 then
            begin
                Result := 0.00018193024331943677;
            end
            else
            begin
                if features.challenger_ranker_score_gap <= 256098640.00000003 then
                begin
                    if features.delta_top_dict_weight <= -137868.49999999997 then
                    begin
                        Result := 0.053650119906038955;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_strong_ratio <= 55.500000000000007 then
                        begin
                            if features.delta_second_path_max_segment_units <= -1.0000000180025095E-35 then
                            begin
                                Result := -0.015629362820455919;
                            end
                            else
                            begin
                                Result := 0.02118671393460133;
                            end;
                        end
                        else
                        begin
                            Result := 0.03588892374307593;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.053455030129972818;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_13(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        if features.second_top_ranker_score_gap <= -359600175.99999994 then
        begin
            Result := 0.032203556110124175;
        end
        else
        begin
            if features.delta_second_complete_pool_anchor_weight_gain <= -251.49999999999997 then
            begin
                if features.delta_top_char_lm_score <= 118.50000000000001 then
                begin
                    Result := -0.017729819511053273;
                end
                else
                begin
                    Result := 0.016506118344424718;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_supported_ratio <= 198.00000000000003 then
                begin
                    Result := -0.031191975135874083;
                end
                else
                begin
                    Result := -0.0047010801416527363;
                end;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                if features.delta_top_legacy_rank <= 6.5000000000000009 then
                begin
                    if features.challenger_ranker_score_gap <= 54531776.000000007 then
                    begin
                        if features.delta_second_complete_pool_consensus_support <= -70.499999999999986 then
                        begin
                            Result := -0.027828008402352788;
                        end
                        else
                        begin
                            Result := 0.0060399286591078143;
                        end;
                    end
                    else
                    begin
                        Result := 0.012099274163668497;
                    end;
                end
                else
                begin
                    if features.delta_top_complete_pool_anchor_replacement_weight <= 579.50000000000011 then
                    begin
                        Result := 0.042712658714474543;
                    end
                    else
                    begin
                        Result := -0.0015310219208798303;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_char_lm_score <= -8.4999999999999982 then
                begin
                    Result := -0.022881648538140807;
                end
                else
                begin
                    Result := 0.010187217488794514;
                end;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_supported_ratio <= 51.500000000000007 then
            begin
                if features.delta_second_complete_pool_signature_support <= 5.5000000000000009 then
                begin
                    Result := 0.030009596450856702;
                end
                else
                begin
                    Result := -0.0027012574224685522;
                end;
            end
            else
            begin
                Result := 0.050087398185718911;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_14(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.033791065288385096;
        end
        else
        begin
            Result := -0.0095446184737844383;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                if features.delta_top_char_lm_score <= -105.49999999999999 then
                begin
                    Result := -0.02685869439500007;
                end
                else
                begin
                    Result := 0.0;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 1.0000000180025095E-35 then
                begin
                    if features.challenger_char_lm_suffix_score <= -6378.9999999999991 then
                    begin
                        Result := 0.0087360352165518785;
                    end
                    else
                    begin
                        Result := -0.013510524980588598;
                    end;
                end
                else
                begin
                    if features.delta_top_word_lm_boundary_count <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_top_word_lm_supported_ratio <= 34.500000000000007 then
                        begin
                            if features.delta_second_word_lm_bonus <= 295.50000000000006 then
                            begin
                                Result := 0.031020966194238768;
                            end
                            else
                            begin
                                Result := -0.0061684287432156046;
                            end;
                        end
                        else
                        begin
                            Result := 0.050010683693036462;
                        end;
                    end
                    else
                    begin
                        Result := -0.0013740560427706523;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 237445520.00000003 then
            begin
                if features.challenger_word_lm_bonus <= 357.50000000000006 then
                begin
                    if features.delta_top_score_per_unit <= -13898.999999999998 then
                    begin
                        Result := 0.02460511393709678;
                    end
                    else
                    begin
                        if features.delta_second_legacy_rank <= 5.5000000000000009 then
                        begin
                            Result := -0.017062203360230597;
                        end
                        else
                        begin
                            Result := 0.013621926232658075;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.035898580911836092;
                end;
            end
            else
            begin
                Result := 0.04822309726831895;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_15(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -251.49999999999997 then
        begin
            Result := -0.010752508028573837;
        end
        else
        begin
            Result := -0.032123252576705265;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 122314460.00000001 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.delta_second_complete_pool_consensus_mean_distance <= 1646.0000000000002 then
                begin
                    Result := -0.020558637994730383;
                end
                else
                begin
                    if features.challenger_ranker_score_gap <= 89379856.000000015 then
                    begin
                        if features.challenger_char_lm_context_score <= -7183.4999999999991 then
                        begin
                            Result := 0.020458673499323926;
                        end
                        else
                        begin
                            if features.delta_second_path_single_segments <= 1.5000000000000002 then
                            begin
                                Result := -0.0040686064843998317;
                            end
                            else
                            begin
                                Result := -0.024916183946309452;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_dict_weight <= -40264.499999999993 then
                        begin
                            Result := 0.032866144279666179;
                        end
                        else
                        begin
                            Result := -0.00502356197145481;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_chain_second_stage_score <= -97987363.999999985 then
                begin
                    Result := -0.0048130310121644289;
                end
                else
                begin
                    if features.delta_second_chain_first_stage_score <= -105351.99999999999 then
                    begin
                        Result := 0.0030640031891910877;
                    end
                    else
                    begin
                        Result := 0.040695360466866767;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 237445520.00000003 then
            begin
                if features.challenger_rank <= 3.5000000000000004 then
                begin
                    Result := -0.0016815837818899848;
                end
                else
                begin
                    if features.challenger_word_lm_strong_ratio <= 226.00000000000003 then
                    begin
                        Result := 0.014387935106317175;
                    end
                    else
                    begin
                        Result := 0.043328427611585868;
                    end;
                end;
            end
            else
            begin
                Result := 0.050731186487533178;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_16(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 333.00000000000006 then
        begin
            Result := -0.030595228447870371;
        end
        else
        begin
            Result := -0.0038397022811834649;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 105403524.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4291.5000000000009 then
            begin
                Result := -0.015039609966905565;
            end
            else
            begin
                if features.challenger_path_single_segments <= 4.5000000000000009 then
                begin
                    if features.difference_span_units <= 2.5000000000000004 then
                    begin
                        if features.delta_top_chain_first_stage_score <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.013124964015743767;
                        end
                        else
                        begin
                            Result := -0.012120803513659005;
                        end;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -6337.9999999999991 then
                        begin
                            Result := 0.039886942953308677;
                        end
                        else
                        begin
                            if features.challenger_text_units <= 10.500000000000002 then
                            begin
                                Result := -0.0065600932635665361;
                            end
                            else
                            begin
                                Result := 0.024196180927387539;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.015390747807792274;
                end;
            end;
        end
        else
        begin
            if features.challenger_chain_score_gap <= -16220831.999999998 then
            begin
                if features.challenger_ranker_score <= -8011565.9999999991 then
                begin
                    Result := -0.012326105127012163;
                end
                else
                begin
                    Result := 0.022322926293842534;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= -52.499999999999993 then
                begin
                    Result := -0.00032827698595993984;
                end
                else
                begin
                    if features.second_top_ranker_score_gap <= -372362463.99999994 then
                    begin
                        Result := 0.048198720534143397;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_supported_ratio <= 68.000000000000014 then
                        begin
                            Result := 0.011851989708422559;
                        end
                        else
                        begin
                            Result := 0.040997260019452711;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_17(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.031730785331994145;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 65333888.000000007 then
            begin
                Result := -0.026964900605970794;
            end
            else
            begin
                Result := 0.0025533356016604241;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 107590816.00000001 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                if features.delta_second_legacy_rank <= 3.5000000000000004 then
                begin
                    if features.challenger_ranker_score_gap <= 77408280.000000015 then
                    begin
                        Result := -0.0089027260988898422;
                    end
                    else
                    begin
                        Result := 0.013821307294554417;
                    end;
                end
                else
                begin
                    Result := 0.023628619554004589;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    if features.delta_top_char_lm_score <= -105.49999999999999 then
                    begin
                        Result := -0.01068507855802025;
                    end
                    else
                    begin
                        Result := 0.024012570762934223;
                    end;
                end
                else
                begin
                    Result := -0.025979103939098521;
                end;
            end;
        end
        else
        begin
            if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
            begin
                Result := -0.00030888012411503578;
            end
            else
            begin
                if features.challenger_ranker_score_gap <= 243601632.00000003 then
                begin
                    if features.delta_top_dict_weight <= -137868.49999999997 then
                    begin
                        Result := 0.045187852814195253;
                    end
                    else
                    begin
                        if features.challenger_word_lm_strong_ratio <= 379.50000000000006 then
                        begin
                            if features.challenger_score_per_unit <= 4766.5000000000009 then
                            begin
                                Result := 0.025983854033278179;
                            end
                            else
                            begin
                                Result := -0.0057606157063997219;
                            end;
                        end
                        else
                        begin
                            Result := 0.042129369371994616;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.048541201325722969;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_18(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.030517296197436736;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 65333888.000000007 then
            begin
                Result := -0.026903689677179064;
            end
            else
            begin
                Result := 0.00417026801259215;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 122314460.00000001 then
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 4062.5000000000005 then
            begin
                Result := -0.015907375818276646;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 1.0000000180025095E-35 then
                begin
                    if features.delta_top_dict_weight_per_unit <= -5238.4999999999991 then
                    begin
                        if features.challenger_score_per_unit <= 4254.5000000000009 then
                        begin
                            Result := 0.022840380054535904;
                        end
                        else
                        begin
                            if features.delta_second_char_lm_score <= 258.50000000000006 then
                            begin
                                Result := -0.020711793086516751;
                            end
                            else
                            begin
                                Result := 0.011425129977930736;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.016093210703609556;
                    end;
                end
                else
                begin
                    if features.challenger_rank <= 4.5000000000000009 then
                    begin
                        if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
                        begin
                            Result := -0.016059008686984292;
                        end
                        else
                        begin
                            Result := 0.015814201624770381;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_candidate_score <= -50884.999999999993 then
                        begin
                            Result := 0.011963432801016858;
                        end
                        else
                        begin
                            Result := 0.04935152407515337;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 269634064.00000006 then
            begin
                if features.challenger_chain_score_gap <= -10125606.999999998 then
                begin
                    Result := -0.0055918534995392372;
                end
                else
                begin
                    Result := 0.025489231361748108;
                end;
            end
            else
            begin
                Result := 0.047924837315747787;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_19(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        if features.challenger_complete_pool_consensus_mean_distance <= 4708.5000000000009 then
        begin
            Result := -0.0302887833845338;
        end
        else
        begin
            Result := -0.011541836404831069;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 105403524.00000001 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.challenger_complete_pool_anchor_top_weight <= 707.50000000000011 then
                begin
                    if features.delta_second_char_lm_score <= -219.99999999999997 then
                    begin
                        Result := -0.010004860624302876;
                    end
                    else
                    begin
                        if features.delta_top_dict_weight <= -40264.499999999993 then
                        begin
                            if features.challenger_chain_first_stage_score <= 60828.000000000007 then
                            begin
                                Result := 0.033307747910324141;
                            end
                            else
                            begin
                                Result := 0.0036500906369366639;
                            end;
                        end
                        else
                        begin
                            if features.delta_top_word_lm_supported_ratio <= 45.000000000000007 then
                            begin
                                Result := -0.016205237558809552;
                            end
                            else
                            begin
                                Result := 0.020945755835873808;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.01605719680491114;
                end;
            end
            else
            begin
                Result := -0.016203086155542036;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_strong_ratio <= 51.500000000000007 then
            begin
                if features.delta_second_char_lm_suffix_score <= 252.00000000000003 then
                begin
                    Result := -0.011663946296924226;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_mean_distance <= 15708.500000000002 then
                    begin
                        Result := 0.0043393511768619651;
                    end
                    else
                    begin
                        if features.max_different_run <= 2.5000000000000004 then
                        begin
                            Result := 0.037522003049144007;
                        end
                        else
                        begin
                            Result := -0.0005154527317173754;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_anchor_top_weight <= -537.49999999999989 then
                begin
                    Result := 0.00049037466256712391;
                end
                else
                begin
                    Result := 0.042273139133677202;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_20(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.03121184294960638;
        end
        else
        begin
            if features.delta_second_complete_pool_anchor_replacement_weight <= -229.49999999999997 then
            begin
                Result := 0.0054681966230608007;
            end
            else
            begin
                Result := -0.026030088406105455;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 230236536.00000003 then
        begin
            if features.challenger_rank <= 3.5000000000000004 then
            begin
                if features.delta_second_path_segments <= 2.5000000000000004 then
                begin
                    Result := -0.016686752730388877;
                end
                else
                begin
                    Result := 0.0095363260489855061;
                end;
            end
            else
            begin
                if features.challenger_ranker_score_gap <= 92833636.000000015 then
                begin
                    if features.delta_second_path_single_segments <= 1.5000000000000002 then
                    begin
                        if features.delta_second_char_lm_score <= 139.50000000000003 then
                        begin
                            if features.delta_top_candidate_score <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.011503226868434295;
                            end
                            else
                            begin
                                Result := -0.018163424725445167;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_consensus_support <= -76.499999999999986 then
                            begin
                                Result := 0.0;
                            end
                            else
                            begin
                                Result := 0.032285418094418518;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.017452471169460877;
                    end;
                end
                else
                begin
                    if features.delta_second_word_lm_bonus <= 4.5000000000000009 then
                    begin
                        if features.delta_second_char_lm_score <= 332.50000000000006 then
                        begin
                            Result := -0.018584791865561081;
                        end
                        else
                        begin
                            Result := 0.02293093861905407;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_boundary_max <= 1510.5000000000002 then
                        begin
                            Result := 0.041270351314843842;
                        end
                        else
                        begin
                            Result := -0.0027643390869293944;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.039816517068735832;
        end;
    end;
end;

function second_slot_recovery_gate_tree_21(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.028801183841133619;
        end
        else
        begin
            Result := -0.0040223979496140146;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 118963224.00000001 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                if features.challenger_rank <= 3.5000000000000004 then
                begin
                    Result := -0.013553645017703366;
                end
                else
                begin
                    if features.delta_second_char_lm_score <= 139.50000000000003 then
                    begin
                        if features.delta_top_candidate_score <= -1.0000000180025095E-35 then
                        begin
                            if features.delta_top_complete_pool_consensus_nearest_distance <= 6.5000000000000009 then
                            begin
                                Result := -0.0015834524395218186;
                            end
                            else
                            begin
                                Result := 0.032329017638424266;
                            end;
                        end
                        else
                        begin
                            Result := -0.018770252250009341;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_zero_count <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.039496213448153961;
                        end
                        else
                        begin
                            Result := 0.010064688698599913;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    if features.delta_top_char_lm_suffix_score <= -4.4999999999999991 then
                    begin
                        Result := -0.0044139583085795039;
                    end
                    else
                    begin
                        Result := 0.029149774087709253;
                    end;
                end
                else
                begin
                    Result := -0.025752162699580299;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -391502447.99999994 then
            begin
                Result := 0.04081767530986595;
            end
            else
            begin
                if features.challenger_word_lm_supported_ratio <= 256.50000000000006 then
                begin
                    if features.delta_top_char_lm_score <= -154.49999999999997 then
                    begin
                        Result := -0.014391890662033214;
                    end
                    else
                    begin
                        Result := 0.01288933627359923;
                    end;
                end
                else
                begin
                    Result := 0.026976130626448481;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_22(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
        begin
            if features.different_units <= 1.5000000000000002 then
            begin
                Result := -0.011616482551254565;
            end
            else
            begin
                Result := -0.032801660415923341;
            end;
        end
        else
        begin
            Result := 0.0014544495319255661;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.challenger_score_per_unit <= 4485.5000000000009 then
                begin
                    Result := 0.0061433004014013288;
                end
                else
                begin
                    Result := -0.013950022631981208;
                end;
            end
            else
            begin
                if features.challenger_word_lm_boundary_max <= 1453.5000000000002 then
                begin
                    Result := -0.0060841217592687308;
                end
                else
                begin
                    Result := 0.027731428596986997;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -391502447.99999994 then
            begin
                if features.delta_top_chain_second_stage_score <= -289062255.99999994 then
                begin
                    Result := 0.006686221117101941;
                end
                else
                begin
                    Result := 0.048790762398755495;
                end;
            end
            else
            begin
                if features.challenger_word_lm_bonus <= 489.50000000000006 then
                begin
                    if features.delta_top_path_segments <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_second_legacy_rank <= 1.5000000000000002 then
                        begin
                            Result := -0.022068007209644223;
                        end
                        else
                        begin
                            if features.same_suffix_units <= 1.5000000000000002 then
                            begin
                                Result := 0.023611206097386647;
                            end
                            else
                            begin
                                Result := -0.0071171694998499778;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.same_suffix_units <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.003874843970745564;
                        end
                        else
                        begin
                            Result := 0.043264051857312469;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.034823958438091288;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_23(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_consensus_changed_support <= -161.49999999999997 then
        begin
            Result := 0.0032934691936387225;
        end
        else
        begin
            Result := -0.026772280724573137;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 97751588.000000015 then
        begin
            if features.delta_top_complete_pool_rank <= 7.5000000000000009 then
            begin
                if features.challenger_char_lm_score <= -6216.4999999999991 then
                begin
                    Result := 0.011973739450485984;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_support_min <= 266.00000000000006 then
                    begin
                        Result := -0.0061537835259569962;
                    end
                    else
                    begin
                        Result := -0.024701688664081504;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    Result := 0.036517461532869389;
                end
                else
                begin
                    if features.challenger_text_units <= 10.500000000000002 then
                    begin
                        Result := -0.013000583975578258;
                    end
                    else
                    begin
                        Result := 0.01830398505133915;
                    end;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -391502447.99999994 then
            begin
                Result := 0.039582435183872604;
            end
            else
            begin
                if features.delta_second_dict_weight <= 11387.500000000002 then
                begin
                    if features.delta_second_word_lm_strong_ratio <= 51.500000000000007 then
                    begin
                        if features.challenger_word_lm_zero_count <= 4.5000000000000009 then
                        begin
                            if features.second_top_ranker_score_gap <= -243603095.99999997 then
                            begin
                                Result := -0.014367392224433883;
                            end
                            else
                            begin
                                Result := 0.022251039484801956;
                            end;
                        end
                        else
                        begin
                            Result := 0.026855890247929601;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_boundary_max <= 1510.5000000000002 then
                        begin
                            Result := 0.038487688863437293;
                        end
                        else
                        begin
                            Result := 0.0015713739043436664;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.01886258082536672;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_24(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 127.50000000000001 then
        begin
            Result := -0.028615405328094042;
        end
        else
        begin
            Result := -0.0075621423475812112;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 105403524.00000001 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                if features.delta_top_legacy_rank <= 7.5000000000000009 then
                begin
                    Result := -0.0033736668379504213;
                end
                else
                begin
                    if features.delta_top_candidate_score <= -10589.499999999998 then
                    begin
                        Result := 0.042232885173258218;
                    end
                    else
                    begin
                        Result := 0.0045297663382204492;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    if features.delta_top_char_lm_score <= -105.49999999999999 then
                    begin
                        Result := -0.014633791448109165;
                    end
                    else
                    begin
                        Result := 0.0207284029894984;
                    end;
                end
                else
                begin
                    Result := -0.025151499897737579;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 269634064.00000006 then
            begin
                if features.challenger_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                begin
                    Result := -0.0071307674009501122;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -137868.49999999997 then
                    begin
                        Result := 0.037263295660722666;
                    end
                    else
                    begin
                        if features.challenger_word_lm_bonus <= 520.50000000000011 then
                        begin
                            if features.delta_second_complete_pool_signature_support <= 2.5000000000000004 then
                            begin
                                if features.delta_second_legacy_rank <= 3.5000000000000004 then
                                begin
                                    Result := 0.0022980520440005095;
                                end
                                else
                                begin
                                    Result := 0.037827450917669113;
                                end;
                            end
                            else
                            begin
                                Result := -0.0086943033887797797;
                            end;
                        end
                        else
                        begin
                            Result := 0.03329594149042378;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.041071970490228198;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_25(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.delta_second_word_lm_supported_ratio <= 159.00000000000003 then
        begin
            Result := -0.025279093298493645;
        end
        else
        begin
            Result := -0.0022297434064993994;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 134569208.00000003 then
        begin
            if features.delta_second_legacy_rank <= 3.5000000000000004 then
            begin
                if features.challenger_complete_pool_seed_rank <= 2.5000000000000004 then
                begin
                    Result := -0.015235559269488776;
                end
                else
                begin
                    if features.delta_top_char_lm_score <= -291.49999999999994 then
                    begin
                        Result := -0.012057047816255361;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -5637.4999999999991 then
                        begin
                            if features.challenger_char_lm_suffix_score <= -6172.4999999999991 then
                            begin
                                Result := 0.016837008429087003;
                            end
                            else
                            begin
                                Result := -0.011466669133104202;
                            end;
                        end
                        else
                        begin
                            Result := 0.033733792325952729;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_path_single_segments <= 3.5000000000000004 then
                begin
                    if features.different_units <= 1.5000000000000002 then
                    begin
                        Result := -0.0024581682879174904;
                    end
                    else
                    begin
                        if features.delta_second_dict_weight_per_unit <= -10886.499999999998 then
                        begin
                            Result := -0.0020516091739796842;
                        end
                        else
                        begin
                            Result := 0.036874940889351004;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.016332070157768611;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -303703871.99999994 then
            begin
                Result := 0.033452932047703665;
            end
            else
            begin
                if features.delta_second_char_lm_context_score <= 951.50000000000011 then
                begin
                    if features.delta_second_char_lm_context_score <= 252.00000000000003 then
                    begin
                        Result := 0.0007664727741580232;
                    end
                    else
                    begin
                        Result := 0.033266409304816419;
                    end;
                end
                else
                begin
                    Result := -0.012688584022183881;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_26(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -251.49999999999997 then
        begin
            Result := 0.0;
        end
        else
        begin
            Result := -0.024308190307588101;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 134569208.00000003 then
        begin
            if features.delta_second_word_lm_bonus <= 1.0000000180025095E-35 then
            begin
                if features.challenger_score_per_unit <= 4733.5000000000009 then
                begin
                    if features.challenger_complete_pool_consensus_unanimous_units <= 4.5000000000000009 then
                    begin
                        if features.delta_top_dict_weight_per_unit <= -2409.4999999999995 then
                        begin
                            Result := 0.037195802679704411;
                        end
                        else
                        begin
                            Result := -0.0027395406478695683;
                        end;
                    end
                    else
                    begin
                        Result := -0.0074959297131533585;
                    end;
                end
                else
                begin
                    Result := -0.013979034090821432;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                begin
                    Result := -0.008453944919711711;
                end
                else
                begin
                    if features.delta_second_word_lm_boundary_max <= 47.500000000000007 then
                    begin
                        if features.delta_top_chain_second_stage_score <= -93962795.999999985 then
                        begin
                            Result := 0.0066746177295166683;
                        end
                        else
                        begin
                            Result := 0.043501124604706946;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_score_per_unit <= -7012.9999999999991 then
                        begin
                            Result := 0.025385519659080504;
                        end
                        else
                        begin
                            Result := -0.0064999391211687041;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_second_char_lm_score <= 258.50000000000006 then
            begin
                Result := -0.0015121057521081873;
            end
            else
            begin
                if features.challenger_complete_pool_signature_support <= 22.500000000000004 then
                begin
                    if features.challenger_char_lm_context_score <= -6600.4999999999991 then
                    begin
                        Result := 0.013314549134704354;
                    end
                    else
                    begin
                        Result := 0.03821432320717922;
                    end;
                end
                else
                begin
                    Result := 0.0012570249828142781;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_27(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.delta_second_word_lm_strong_ratio <= -38.999999999999993 then
        begin
            Result := -0.033540535814539918;
        end
        else
        begin
            Result := -0.015157634795220074;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_score <= 517.00000000000011 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.delta_top_word_lm_strong_ratio <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_char_lm_score <= -17.499999999999996 then
                    begin
                        if features.delta_second_word_lm_bonus <= 67.500000000000014 then
                        begin
                            Result := -0.0037423992639726076;
                        end
                        else
                        begin
                            Result := -0.031602473395500853;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_bonus <= 59.500000000000007 then
                        begin
                            Result := -0.0039530425089289627;
                        end
                        else
                        begin
                            Result := 0.030095975770739386;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_top_chain_first_stage_score <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.0473983797763717;
                    end
                    else
                    begin
                        Result := 0.012756940381601392;
                    end;
                end;
            end
            else
            begin
                Result := -0.01859538551540163;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -338938623.99999994 then
            begin
                if features.delta_second_word_lm_zero_count <= 1.0000000180025095E-35 then
                begin
                    Result := 0.038195471787948562;
                end
                else
                begin
                    Result := 0.0032546122504789748;
                end;
            end
            else
            begin
                if features.delta_top_dict_weight <= -63405.499999999993 then
                begin
                    Result := 0.025490985047584042;
                end
                else
                begin
                    if features.challenger_rank <= 3.5000000000000004 then
                    begin
                        Result := -0.021211674756659277;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_pair_evidence <= 1.0000000180025095E-35 then
                        begin
                            Result := -0.0029081660220143485;
                        end
                        else
                        begin
                            Result := 0.032629968651891522;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_28(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_consensus_changed_support <= -175.49999999999997 then
        begin
            Result := 0.0071796731989221063;
        end
        else
        begin
            Result := -0.024605384177675806;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_score <= 221.50000000000003 then
        begin
            if features.delta_second_legacy_rank <= 3.5000000000000004 then
            begin
                if features.delta_second_word_lm_supported_ratio <= 142.50000000000003 then
                begin
                    Result := -0.017413778389251181;
                end
                else
                begin
                    Result := 0.0060304711952100278;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support <= -20.499999999999996 then
                begin
                    Result := 0.03114131385612914;
                end
                else
                begin
                    Result := -0.0081860063268392406;
                end;
            end;
        end
        else
        begin
            if features.delta_top_char_lm_score <= -307.99999999999994 then
            begin
                if features.delta_second_chain_first_stage_score <= -209.49999999999997 then
                begin
                    Result := -0.025894953420152564;
                end
                else
                begin
                    Result := 0.013288413525063894;
                end;
            end
            else
            begin
                if features.challenger_word_lm_boundary_max <= 1396.5000000000002 then
                begin
                    if features.delta_top_dict_weight_per_unit <= -17311.999999999996 then
                    begin
                        if features.second_ranker_score <= -71821815.999999985 then
                        begin
                            Result := 0.04553492411589484;
                        end
                        else
                        begin
                            Result := 0.0;
                        end;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -7061.4999999999991 then
                        begin
                            Result := 0.030610295585986009;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_support <= 765.50000000000011 then
                            begin
                                Result := -0.015912462935803902;
                            end
                            else
                            begin
                                Result := 0.01250484438772346;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_dict_weight_per_unit <= -11538.499999999998 then
                    begin
                        Result := 0.0049376188512713108;
                    end
                    else
                    begin
                        Result := 0.037056752439198523;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_29(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        if features.top_ranker_score <= -127955103.99999999 then
        begin
            Result := 6.6698921277747128E-05;
        end
        else
        begin
            Result := -0.023817377353208508;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_score <= 341.50000000000006 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.challenger_complete_pool_anchor_top_weight <= 707.50000000000011 then
                begin
                    if features.delta_second_char_lm_suffix_score <= -287.49999999999994 then
                    begin
                        Result := -0.01640920019114047;
                    end
                    else
                    begin
                        if features.delta_second_char_lm_suffix_score <= 315.50000000000006 then
                        begin
                            if features.delta_top_word_lm_supported_ratio <= 142.50000000000003 then
                            begin
                                if features.same_prefix_units <= 4.5000000000000009 then
                                begin
                                    if features.delta_second_complete_pool_consensus_support <= -20.499999999999996 then
                                    begin
                                        Result := 0.032891231426407812;
                                    end
                                    else
                                    begin
                                        Result := 0.0030950648851904758;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0084919613766474191;
                                end;
                            end
                            else
                            begin
                                Result := 0.036165039318359342;
                            end;
                        end
                        else
                        begin
                            Result := -0.012577689325479634;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.023582067427790926;
                end;
            end
            else
            begin
                Result := -0.024140583464048064;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_strong_ratio <= 47.000000000000007 then
            begin
                if features.delta_top_dict_weight <= -103003.49999999999 then
                begin
                    if features.delta_second_dict_weight_per_unit <= -11016.999999999998 then
                    begin
                        Result := -0.00040436486752491892;
                    end
                    else
                    begin
                        if features.delta_second_legacy_rank <= 1.5000000000000002 then
                        begin
                            Result := 0.0061279063003991429;
                        end
                        else
                        begin
                            Result := 0.04243796665563291;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.00032617126944364702;
                end;
            end
            else
            begin
                Result := 0.031638606839084975;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_30(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 127.50000000000001 then
        begin
            if features.delta_top_complete_pool_consensus_nearest_distance <= 1.5000000000000002 then
            begin
                Result := -0.028063594523844514;
            end
            else
            begin
                Result := -0.0086220498572113415;
            end;
        end
        else
        begin
            Result := -0.0034248165488508721;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 97751588.000000015 then
        begin
            if features.challenger_path_single_segments <= 4.5000000000000009 then
            begin
                if features.delta_second_legacy_rank <= 1.5000000000000002 then
                begin
                    Result := -0.010081957233710725;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -150714.49999999997 then
                    begin
                        Result := 0.027554221321067992;
                    end
                    else
                    begin
                        Result := 0.0054043754516169074;
                    end;
                end;
            end
            else
            begin
                Result := -0.0176409875341807;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_strong_ratio <= 51.500000000000007 then
            begin
                if features.delta_top_path_max_segment_units <= -1.0000000180025095E-35 then
                begin
                    Result := 0.034771295263441943;
                end
                else
                begin
                    if features.delta_second_complete_pool_signature_support <= 1.5000000000000002 then
                    begin
                        if features.second_top_ranker_score_gap <= -353318351.99999994 then
                        begin
                            Result := 0.03466938170551135;
                        end
                        else
                        begin
                            if features.second_top_ranker_score_gap <= -220432527.99999997 then
                            begin
                                Result := -0.011864261801391536;
                            end
                            else
                            begin
                                Result := 0.030266207674372173;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.challenger_char_lm_score <= -5007.4999999999991 then
                        begin
                            Result := -0.022192738418322842;
                        end
                        else
                        begin
                            Result := 0.0067301097611021168;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.same_prefix_units <= 7.5000000000000009 then
                begin
                    Result := 0.035598922049120629;
                end
                else
                begin
                    Result := 0.0023574442404442507;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_31(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -251.49999999999997 then
        begin
            Result := 0.0036725978788109321;
        end
        else
        begin
            if features.delta_second_word_lm_supported_ratio <= 198.00000000000003 then
            begin
                Result := -0.024554761166948904;
            end
            else
            begin
                Result := -0.0026138510635894865;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 91171264.000000015 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
                begin
                    if features.challenger_complete_pool_substitutions <= 1.0000000180025095E-35 then
                    begin
                        if features.challenger_complete_pool_pair_evidence <= 1477.5000000000002 then
                        begin
                            if features.challenger_complete_pool_rank <= 4.5000000000000009 then
                            begin
                                Result := 0.0026736646220945899;
                            end
                            else
                            begin
                                Result := 0.031677806679937012;
                            end;
                        end
                        else
                        begin
                            Result := -0.012538132030355543;
                        end;
                    end
                    else
                    begin
                        Result := -0.017368228108034713;
                    end;
                end
                else
                begin
                    Result := 0.018785589826933072;
                end;
            end
            else
            begin
                Result := -0.017170720244802085;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_strong_ratio <= 55.500000000000007 then
            begin
                if features.challenger_complete_pool_consensus_seed_count <= 2.5000000000000004 then
                begin
                    if features.challenger_char_lm_score <= -4760.9999999999991 then
                    begin
                        Result := 0.0031432353585068595;
                    end
                    else
                    begin
                        Result := 0.039730743760562667;
                    end;
                end
                else
                begin
                    if features.delta_second_chain_first_stage_score <= -13699.999999999998 then
                    begin
                        Result := 0.020609169296308873;
                    end
                    else
                    begin
                        Result := -0.010112075556488419;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_char_lm_suffix_score <= -110.99999999999999 then
                begin
                    Result := -0.00068632377339764722;
                end
                else
                begin
                    Result := 0.033946277382063038;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_32(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.different_units <= 1.5000000000000002 then
        begin
            Result := -0.0073334087755429333;
        end
        else
        begin
            Result := -0.024460318785738178;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
                begin
                    if features.challenger_complete_pool_substitutions <= 1.0000000180025095E-35 then
                    begin
                        if features.challenger_path_segments <= 4.5000000000000009 then
                        begin
                            Result := 0.021859945104150062;
                        end
                        else
                        begin
                            Result := -0.0032040689935118258;
                        end;
                    end
                    else
                    begin
                        Result := -0.017318538902387701;
                    end;
                end
                else
                begin
                    Result := -0.025662924733598932;
                end;
            end
            else
            begin
                if features.delta_second_score_per_unit <= -5342.9999999999991 then
                begin
                    Result := -0.0031800245160621388;
                end
                else
                begin
                    Result := 0.026361260207788301;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -391502447.99999994 then
            begin
                Result := 0.037001006315645922;
            end
            else
            begin
                if features.delta_second_candidate_score <= -11418.499999999998 then
                begin
                    if features.challenger_score_per_unit <= 5738.5000000000009 then
                    begin
                        if features.challenger_score_per_unit <= 2997.0000000000005 then
                        begin
                            Result := 0.009376597774027582;
                        end
                        else
                        begin
                            Result := 0.040365515315216607;
                        end;
                    end
                    else
                    begin
                        Result := -0.0029478898058129168;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_support <= 762.50000000000011 then
                    begin
                        Result := -0.019150521578220926;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_bonus <= 8.5000000000000018 then
                        begin
                            Result := -0.0061566069680783434;
                        end
                        else
                        begin
                            Result := 0.033150424037729519;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_33(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_consensus_changed_support <= -180.99999999999997 then
        begin
            Result := 0.0092363389160635811;
        end
        else
        begin
            Result := -0.023880837568750285;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 269634064.00000006 then
        begin
            if features.delta_second_char_lm_score <= 517.00000000000011 then
            begin
                if features.challenger_path_single_segments <= 4.5000000000000009 then
                begin
                    if features.delta_second_complete_pool_consensus_nearest_distance <= 6.5000000000000009 then
                    begin
                        if features.difference_span_units <= 4.5000000000000009 then
                        begin
                            Result := -0.0088984636786831588;
                        end
                        else
                        begin
                            if features.delta_top_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                            begin
                                Result := -0.0099451688273079156;
                            end
                            else
                            begin
                                Result := 0.032320800327109295;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_word_lm_strong_ratio <= 38.500000000000007 then
                        begin
                            Result := 0.0063132364345300533;
                        end
                        else
                        begin
                            Result := 0.036977081235176526;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.020463787286592417;
                end;
            end
            else
            begin
                if features.delta_second_char_lm_suffix_score <= 703.00000000000011 then
                begin
                    if features.delta_second_complete_pool_rank <= 1.5000000000000002 then
                    begin
                        Result := 0.002212435574960515;
                    end
                    else
                    begin
                        Result := 0.037506684607943104;
                    end;
                end
                else
                begin
                    if features.delta_top_path_segments <= 1.5000000000000002 then
                    begin
                        if features.delta_second_complete_pool_consensus_mean_distance <= 12187.500000000002 then
                        begin
                            Result := -0.016897129033055354;
                        end
                        else
                        begin
                            if features.delta_second_path_segments <= 1.5000000000000002 then
                            begin
                                Result := 0.024506779283539403;
                            end
                            else
                            begin
                                Result := -0.012268863329920342;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.029806700069298097;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.036613368269803367;
        end;
    end;
end;

function second_slot_recovery_gate_tree_34(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 176.50000000000003 then
        begin
            Result := -0.024525404124799977;
        end
        else
        begin
            if features.same_suffix_units <= 2.5000000000000004 then
            begin
                Result := -0.017195479123229988;
            end
            else
            begin
                Result := 0.013727897236610751;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 237445520.00000003 then
        begin
            if features.challenger_rank <= 3.5000000000000004 then
            begin
                Result := -0.010374141055294285;
            end
            else
            begin
                if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_char_lm_score <= 139.50000000000003 then
                    begin
                        if features.delta_top_word_lm_supported_ratio <= 33.000000000000007 then
                        begin
                            Result := -0.011143558778738964;
                        end
                        else
                        begin
                            if features.delta_second_word_lm_boundary_max <= 181.50000000000003 then
                            begin
                                Result := 0.038642415993111447;
                            end
                            else
                            begin
                                Result := -0.002204432489062737;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_pair_evidence <= 123.00000000000001 then
                        begin
                            if features.delta_top_dict_weight <= -137868.49999999997 then
                            begin
                                Result := 0.037393337267571311;
                            end
                            else
                            begin
                                if features.delta_top_chain_first_stage_score <= -199.49999999999997 then
                                begin
                                    Result := 0.022959458237871225;
                                end
                                else
                                begin
                                    Result := -0.0035221575392429295;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.043658179061108277;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_word_lm_bonus <= 93.500000000000014 then
                    begin
                        Result := -0.014291353120941602;
                    end
                    else
                    begin
                        Result := 0.011918815834924629;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_complete_pool_consensus_unanimous_units <= 2.5000000000000004 then
            begin
                Result := 0.00025879783028082262;
            end
            else
            begin
                Result := 0.038133809790414468;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_35(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_legacy_rank <= 2.5000000000000004 then
    begin
        Result := -0.021879395700480836;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 269634064.00000006 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.challenger_char_lm_suffix_score <= -5236.9999999999991 then
                begin
                    if features.delta_top_dict_weight <= -101029.49999999999 then
                    begin
                        if features.delta_top_word_lm_zero_count <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.031602492581714478;
                        end
                        else
                        begin
                            Result := 0.0058393497896423114;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_char_lm_suffix_score <= -560.99999999999989 then
                        begin
                            Result := 0.025139930787337079;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_consensus_support <= 27.500000000000004 then
                            begin
                                if features.delta_second_complete_pool_signature_support <= 3.5000000000000004 then
                                begin
                                    Result := -0.015836492802595019;
                                end
                                else
                                begin
                                    Result := 0.0081358903126936624;
                                end;
                            end
                            else
                            begin
                                Result := 0.015800071485057212;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_complete_pool_consensus_support <= -110.49999999999999 then
                    begin
                        Result := -0.002344860933273735;
                    end
                    else
                    begin
                        if features.delta_top_char_lm_score <= -218.49999999999997 then
                        begin
                            Result := 0.0085001363237303743;
                        end
                        else
                        begin
                            Result := 0.047188782071835751;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_char_lm_context_score <= 427.50000000000006 then
                begin
                    Result := -0.023157745726043982;
                end
                else
                begin
                    if features.delta_top_char_lm_suffix_score <= -163.99999999999997 then
                    begin
                        Result := -0.020584891184073261;
                    end
                    else
                    begin
                        if features.challenger_score_per_unit <= 5738.5000000000009 then
                        begin
                            Result := 0.027608381419110341;
                        end
                        else
                        begin
                            Result := -0.015410042962552219;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.035434010318107396;
        end;
    end;
end;

function second_slot_recovery_gate_tree_36(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        if features.challenger_word_lm_bonus <= 6.5000000000000009 then
        begin
            if features.delta_top_complete_pool_pair_evidence <= -1126.4999999999998 then
            begin
                Result := -0.031893959219002815;
            end
            else
            begin
                Result := 0.00074055584729443671;
            end;
        end
        else
        begin
            Result := -0.024435329424078743;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_score <= 517.00000000000011 then
        begin
            if features.delta_second_word_lm_zero_count <= -1.0000000180025095E-35 then
            begin
                if features.challenger_complete_pool_anchor_top_weight <= 1424.0000000000002 then
                begin
                    if features.delta_second_word_lm_boundary_last <= 1249.5000000000002 then
                    begin
                        if features.delta_second_char_lm_score <= -219.99999999999997 then
                        begin
                            Result := -0.0035212023956571414;
                        end
                        else
                        begin
                            if features.challenger_score_per_unit <= 3592.5000000000005 then
                            begin
                                Result := 0.0;
                            end
                            else
                            begin
                                Result := 0.026323339259780615;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.0090469471544765458;
                    end;
                end
                else
                begin
                    Result := -0.022072371312710511;
                end;
            end
            else
            begin
                Result := -0.011561876637615494;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_strong_ratio <= 68.000000000000014 then
            begin
                if features.challenger_ranker_score_gap <= 54531776.000000007 then
                begin
                    Result := -0.012780946059470827;
                end
                else
                begin
                    if features.delta_top_path_single_segments <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_second_path_segments <= 1.0000000180025095E-35 then
                        begin
                            if features.challenger_complete_pool_consensus_support <= 765.50000000000011 then
                            begin
                                Result := -0.0025482531857880493;
                            end
                            else
                            begin
                                Result := 0.042302803362208187;
                            end;
                        end
                        else
                        begin
                            Result := -0.0090839538179331297;
                        end;
                    end
                    else
                    begin
                        Result := 0.032383161764883914;
                    end;
                end;
            end
            else
            begin
                Result := 0.034169961283836314;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_37(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_top_char_lm_score <= 313.50000000000006 then
        begin
            Result := -0.02288797762152766;
        end
        else
        begin
            Result := 0.0029208355265666511;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 237445520.00000003 then
        begin
            if features.delta_top_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
            begin
                Result := -0.0074484939851252692;
            end
            else
            begin
                if features.challenger_complete_pool_consensus_unanimous_units <= 6.5000000000000009 then
                begin
                    if features.challenger_word_lm_strong_ratio <= 379.50000000000006 then
                    begin
                        if features.delta_top_dict_weight_per_unit <= -21071.499999999996 then
                        begin
                            if features.delta_second_legacy_rank <= 1.5000000000000002 then
                            begin
                                Result := -0.0052718955523903752;
                            end
                            else
                            begin
                                Result := 0.039019435651317484;
                            end;
                        end
                        else
                        begin
                            if features.challenger_score_per_unit <= 4766.5000000000009 then
                            begin
                                if features.challenger_score_per_unit <= 3592.5000000000005 then
                                begin
                                    Result := -0.01034345359096586;
                                end
                                else
                                begin
                                    Result := 0.014225634992833375;
                                end;
                            end
                            else
                            begin
                                if features.delta_second_complete_pool_changed_position <= 4.5000000000000009 then
                                begin
                                    Result := -0.025696375868188393;
                                end
                                else
                                begin
                                    Result := 0.002939145626997468;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_pair_evidence <= 3619.5000000000005 then
                        begin
                            Result := 0.031338591448771103;
                        end
                        else
                        begin
                            Result := -0.0036192390276114472;
                        end;
                    end;
                end
                else
                begin
                    if features.challenger_word_lm_supported_ratio <= 577.00000000000011 then
                    begin
                        Result := 0.027986025541367227;
                    end
                    else
                    begin
                        Result := -0.007856720404918846;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_second_complete_pool_pair_evidence <= 3619.5000000000005 then
            begin
                Result := 0.038568181847836946;
            end
            else
            begin
                Result := 0.0;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_38(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -386976639.99999994 then
    begin
        if features.delta_top_chain_second_stage_score <= -93962795.999999985 then
        begin
            Result := 0.003951778623730441;
        end
        else
        begin
            Result := 0.036881969844710386;
        end;
    end
    else
    begin
        if features.delta_second_legacy_rank <= 1.5000000000000002 then
        begin
            if features.delta_second_word_lm_bonus <= 396.50000000000006 then
            begin
                if features.second_top_ranker_score_gap <= -99625379.999999985 then
                begin
                    Result := -0.020861707064996526;
                end
                else
                begin
                    if features.challenger_ranker_score_gap <= 60807250.000000007 then
                    begin
                        Result := -0.015355841982623729;
                    end
                    else
                    begin
                        Result := 0.025709025783193264;
                    end;
                end;
            end
            else
            begin
                Result := 0.017284610227712677;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 73579340.000000015 then
            begin
                if features.challenger_rank <= 7.5000000000000009 then
                begin
                    Result := -0.010698795699625884;
                end
                else
                begin
                    if features.delta_second_path_single_segments <= 1.5000000000000002 then
                    begin
                        Result := 0.025457346864823028;
                    end
                    else
                    begin
                        Result := -0.015989482453751643;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_word_lm_strong_ratio <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_path_max_segment_units <= -1.0000000180025095E-35 then
                    begin
                        Result := -0.014239240693687958;
                    end
                    else
                    begin
                        if features.delta_second_dict_weight <= -71734.999999999985 then
                        begin
                            Result := 0.035053441274370614;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_signature_support <= 8.5000000000000018 then
                            begin
                                Result := -0.0063149330313807721;
                            end
                            else
                            begin
                                Result := 0.024070303886057756;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_chain_rank <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.0097898405259693282;
                    end
                    else
                    begin
                        Result := 0.040954435154628356;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_39(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_rank <= 1.0000000180025095E-35 then
    begin
        if features.difference_span_units <= 1.5000000000000002 then
        begin
            if features.delta_second_complete_pool_consensus_majority_units <= 1.0000000180025095E-35 then
            begin
                Result := -0.015004307813307839;
            end
            else
            begin
                Result := 0.012128480612098475;
            end;
        end
        else
        begin
            Result := -0.023831783121891915;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 105403524.00000001 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                if features.delta_second_word_lm_supported_ratio <= 41.500000000000007 then
                begin
                    if features.delta_second_complete_pool_signature_support <= -1.4999999999999998 then
                    begin
                        Result := -0.023345748456967148;
                    end
                    else
                    begin
                        if features.delta_second_char_lm_score <= 517.00000000000011 then
                        begin
                            Result := -0.0041425092277935184;
                        end
                        else
                        begin
                            Result := 0.023727649790901504;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_dict_weight <= -56765.499999999993 then
                    begin
                        Result := 0.041248516446969037;
                    end
                    else
                    begin
                        if features.challenger_word_lm_boundary_last <= 1285.5000000000002 then
                        begin
                            Result := 0.016563372590019644;
                        end
                        else
                        begin
                            Result := -0.015743551252045705;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    Result := 0.0032707302884049071;
                end
                else
                begin
                    Result := -0.022538318082090125;
                end;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_bonus <= 6.5000000000000009 then
            begin
                if features.delta_top_char_lm_suffix_score <= -106.49999999999999 then
                begin
                    Result := -0.009136573636041671;
                end
                else
                begin
                    if features.second_top_ranker_score_gap <= -303703871.99999994 then
                    begin
                        Result := 0.033367378211786036;
                    end
                    else
                    begin
                        Result := 0.0034580177446687154;
                    end;
                end;
            end
            else
            begin
                Result := 0.02910164269322095;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_40(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.delta_top_char_lm_score <= 80.500000000000014 then
        begin
            if features.delta_second_word_lm_zero_count <= -1.0000000180025095E-35 then
            begin
                if features.challenger_complete_pool_consensus_support <= 861.50000000000011 then
                begin
                    Result := 0.0086223818773679337;
                end
                else
                begin
                    Result := -0.021942670829958884;
                end;
            end
            else
            begin
                Result := -0.026411037875739354;
            end;
        end
        else
        begin
            Result := -9.8950101452286072E-05;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_top_path_single_segments <= 3.5000000000000004 then
            begin
                if features.delta_second_complete_pool_anchor_top_weight <= 1424.0000000000002 then
                begin
                    Result := 0.0018393267792651742;
                end
                else
                begin
                    Result := -0.022485671742794002;
                end;
            end
            else
            begin
                Result := -0.023023795400603734;
            end;
        end
        else
        begin
            if features.delta_second_char_lm_score <= 332.50000000000006 then
            begin
                if features.delta_top_word_lm_bonus <= -3.4999999999999996 then
                begin
                    Result := -0.020189140758116831;
                end
                else
                begin
                    if features.delta_second_complete_pool_signature_support <= 1.5000000000000002 then
                    begin
                        Result := 0.030438592686160316;
                    end
                    else
                    begin
                        Result := -0.0052530449107780893;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_dict_weight <= -133434.99999999997 then
                begin
                    Result := 0.03844228225493964;
                end
                else
                begin
                    if features.challenger_ranker_score_gap <= 256098640.00000003 then
                    begin
                        if features.delta_second_legacy_rank <= 2.5000000000000004 then
                        begin
                            if features.challenger_complete_pool_consensus_support <= 765.50000000000011 then
                            begin
                                Result := -0.021674769079628863;
                            end
                            else
                            begin
                                Result := 0.018961993194998125;
                            end;
                        end
                        else
                        begin
                            Result := 0.021806576170569605;
                        end;
                    end
                    else
                    begin
                        Result := 0.036019515109179688;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_41(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -442.99999999999994 then
        begin
            Result := 0.0047234828974529446;
        end
        else
        begin
            Result := -0.021657168616569848;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 71505292.000000015 then
        begin
            if features.delta_top_char_lm_score <= -92.499999999999986 then
            begin
                if features.delta_top_complete_pool_consensus_nearest_distance <= 6.5000000000000009 then
                begin
                    Result := -0.020098996959053782;
                end
                else
                begin
                    Result := 0.0015229561974823493;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_consensus_support_min <= 304.50000000000006 then
                begin
                    if features.delta_top_complete_pool_consensus_nearest_distance <= 6.5000000000000009 then
                    begin
                        Result := 0.027241847469589735;
                    end
                    else
                    begin
                        if features.challenger_word_lm_strong_ratio <= 154.00000000000003 then
                        begin
                            Result := -0.021494837849663235;
                        end
                        else
                        begin
                            Result := 0.014780462007441854;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.014633035110299716;
                end;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_bonus <= 4.5000000000000009 then
            begin
                if features.delta_top_char_lm_score <= -191.49999999999997 then
                begin
                    if features.delta_top_score_per_unit <= -12257.499999999998 then
                    begin
                        Result := 0.0082898512255003502;
                    end
                    else
                    begin
                        Result := -0.020956134091131017;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_nearest_distance <= 5.5000000000000009 then
                    begin
                        Result := -0.0053912094155273461;
                    end
                    else
                    begin
                        if features.delta_top_candidate_score <= -109059.99999999999 then
                        begin
                            Result := 0.046210026151537839;
                        end
                        else
                        begin
                            Result := 0.0094688437428187121;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_chain_first_stage_score <= -121038.49999999999 then
                begin
                    Result := 0.0;
                end
                else
                begin
                    Result := 0.026042683027120567;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_42(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.different_units <= 1.5000000000000002 then
        begin
            if features.delta_second_complete_pool_consensus_majority_units <= 1.0000000180025095E-35 then
            begin
                Result := -0.016922284239101072;
            end
            else
            begin
                Result := 0.017335897649119612;
            end;
        end
        else
        begin
            Result := -0.021729607088783357;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 249425984.00000003 then
        begin
            if features.delta_top_dict_weight <= -104175.49999999999 then
            begin
                if features.delta_second_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                begin
                    Result := -0.00045006313610433088;
                end
                else
                begin
                    if features.delta_top_chain_first_stage_score <= -159722.49999999997 then
                    begin
                        Result := -0.0062263902764974075;
                    end
                    else
                    begin
                        if features.delta_top_complete_pool_anchor_top_weight <= 1438.0000000000002 then
                        begin
                            Result := 0.030002749316665848;
                        end
                        else
                        begin
                            Result := -0.0027901428642204862;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support <= 27.500000000000004 then
                begin
                    if features.delta_top_complete_pool_consensus_nearest_distance <= 10.500000000000002 then
                    begin
                        if features.challenger_score_per_unit <= 4517.5000000000009 then
                        begin
                            Result := 0.0040851271489692718;
                        end
                        else
                        begin
                            if features.delta_second_word_lm_supported_ratio <= 159.00000000000003 then
                            begin
                                Result := -0.020090929219145154;
                            end
                            else
                            begin
                                if features.delta_top_dict_weight_per_unit <= -4441.4999999999991 then
                                begin
                                    Result := -0.020986352634420859;
                                end
                                else
                                begin
                                    if features.delta_top_char_lm_score <= -345.99999999999994 then
                                    begin
                                        Result := -0.0037068208248854967;
                                    end
                                    else
                                    begin
                                        Result := 0.033981666109296725;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.015036299859786972;
                    end;
                end
                else
                begin
                    Result := 0.022961280710848308;
                end;
            end;
        end
        else
        begin
            Result := 0.03241413279857934;
        end;
    end;
end;

function second_slot_recovery_gate_tree_43(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_consensus_changed_support <= -180.99999999999997 then
        begin
            Result := 0.012292261177683665;
        end
        else
        begin
            if features.challenger_complete_pool_consensus_majority_units <= 7.5000000000000009 then
            begin
                Result := -0.0064812265679399152;
            end
            else
            begin
                Result := -0.025698233764617856;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 237445520.00000003 then
        begin
            if features.challenger_rank <= 3.5000000000000004 then
            begin
                if features.challenger_complete_pool_consensus_support <= 783.50000000000011 then
                begin
                    Result := -0.015465044867923194;
                end
                else
                begin
                    Result := 0.0018261572563187333;
                end;
            end
            else
            begin
                if features.challenger_path_single_segments <= 3.5000000000000004 then
                begin
                    if features.delta_top_dict_weight <= -104175.49999999999 then
                    begin
                        Result := 0.026195749922217064;
                    end
                    else
                    begin
                        if features.delta_second_char_lm_score <= 332.50000000000006 then
                        begin
                            if features.delta_top_dict_weight <= -20668.499999999996 then
                            begin
                                Result := -0.018172692458082031;
                            end
                            else
                            begin
                                Result := 0.012623476150095597;
                            end;
                        end
                        else
                        begin
                            if features.challenger_word_lm_bonus <= 360.50000000000006 then
                            begin
                                Result := 0.0057424239205433984;
                            end
                            else
                            begin
                                Result := 0.036240948722433795;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_char_lm_score <= 536.50000000000011 then
                    begin
                        Result := -0.014444616153155003;
                    end
                    else
                    begin
                        if features.delta_second_char_lm_suffix_score <= 999.50000000000011 then
                        begin
                            Result := 0.020718033157297675;
                        end
                        else
                        begin
                            Result := -0.013665769284875165;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_complete_pool_consensus_unanimous_units <= 2.5000000000000004 then
            begin
                Result := 0.0;
            end
            else
            begin
                Result := 0.036133541738091135;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_44(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_rank <= 3.5000000000000004 then
    begin
        if features.second_top_ranker_score_gap <= -365725391.99999994 then
        begin
            Result := 0.026317120225195372;
        end
        else
        begin
            if features.top_ranker_score <= -127955103.99999999 then
            begin
                Result := 0.0062746152875405425;
            end
            else
            begin
                Result := -0.016800064257029346;
            end;
        end;
    end
    else
    begin
        if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
        begin
            if features.delta_second_complete_pool_anchor_weight_gain <= 702.00000000000011 then
            begin
                if features.challenger_chain_second_stage_score <= -44485805.999999993 then
                begin
                    Result := -0.0049325886728833106;
                end
                else
                begin
                    if features.delta_second_complete_pool_pair_evidence <= 123.00000000000001 then
                    begin
                        if features.delta_second_word_lm_boundary_max <= 1264.5000000000002 then
                        begin
                            if features.delta_top_dict_weight_per_unit <= -17311.999999999996 then
                            begin
                                Result := 0.034767647766140386;
                            end
                            else
                            begin
                                if features.delta_second_word_lm_supported_ratio <= 34.500000000000007 then
                                begin
                                    if features.delta_top_char_lm_score <= -191.49999999999997 then
                                    begin
                                        Result := -0.013070455769880947;
                                    end
                                    else
                                    begin
                                        Result := 0.011478963265267416;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.033575341814753912;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.019901062433078317;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_char_lm_suffix_score <= -172.49999999999997 then
                        begin
                            Result := -0.0054156198691519856;
                        end
                        else
                        begin
                            Result := 0.039627804876597138;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.016438511801447859;
            end;
        end
        else
        begin
            if features.delta_second_char_lm_suffix_score <= 456.00000000000006 then
            begin
                Result := -0.019708931179744676;
            end
            else
            begin
                if features.delta_second_dict_weight_per_unit <= -10886.499999999998 then
                begin
                    Result := -0.011662859797538916;
                end
                else
                begin
                    Result := 0.019477016186727304;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_45(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        Result := -0.015494656617957117;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 7.5000000000000009 then
            begin
                if features.challenger_path_segments <= 4.5000000000000009 then
                begin
                    if features.challenger_complete_pool_substitutions <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.016450108838214281;
                    end
                    else
                    begin
                        Result := -0.011668992318357883;
                    end;
                end
                else
                begin
                    Result := -0.013020546140771399;
                end;
            end
            else
            begin
                if features.challenger_word_lm_boundary_max <= 1453.5000000000002 then
                begin
                    Result := -0.0053615655577228969;
                end
                else
                begin
                    Result := 0.025324506730957198;
                end;
            end;
        end
        else
        begin
            if features.delta_second_dict_weight <= -120633.99999999999 then
            begin
                Result := 0.03532263973317936;
            end
            else
            begin
                if features.delta_top_dict_weight_per_unit <= -22584.999999999996 then
                begin
                    Result := 0.036060287415445945;
                end
                else
                begin
                    if features.difference_span_units <= 5.5000000000000009 then
                    begin
                        if features.challenger_complete_pool_consensus_support <= 762.50000000000011 then
                        begin
                            if features.delta_top_dict_weight_per_unit <= -14098.499999999998 then
                            begin
                                Result := 0.013293469246915129;
                            end
                            else
                            begin
                                Result := -0.014985427217359012;
                            end;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_support <= 803.50000000000011 then
                            begin
                                Result := 0.032319746285361231;
                            end
                            else
                            begin
                                if features.delta_top_score_per_unit <= -6644.4999999999991 then
                                begin
                                    Result := -0.014798514554799117;
                                end
                                else
                                begin
                                    Result := 0.013579060369892145;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.challenger_word_lm_boundary_max <= 1339.5000000000002 then
                        begin
                            Result := 0.003725840292699476;
                        end
                        else
                        begin
                            Result := 0.040079829512154073;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_46(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_consensus_changed_support <= -175.49999999999997 then
        begin
            Result := 0.012363163710727694;
        end
        else
        begin
            if features.delta_top_char_lm_score <= 127.50000000000001 then
            begin
                Result := -0.024748896053258237;
            end
            else
            begin
                Result := -0.0047166763419414729;
            end;
        end;
    end
    else
    begin
        if features.second_top_ranker_score_gap <= -391502447.99999994 then
        begin
            if features.delta_second_chain_first_stage_score <= -71003.499999999985 then
            begin
                Result := -0.0073086296389849254;
            end
            else
            begin
                Result := 0.033533605798500503;
            end;
        end
        else
        begin
            if features.delta_top_char_lm_score <= -113.49999999999999 then
            begin
                if features.delta_second_word_lm_bonus <= 4.5000000000000009 then
                begin
                    Result := -0.015292791105305356;
                end
                else
                begin
                    if features.delta_top_word_lm_boundary_count <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.011241114091147452;
                    end
                    else
                    begin
                        Result := -0.017375861208968928;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_majority_units <= -1.4999999999999998 then
                begin
                    Result := -0.010091313118697216;
                end
                else
                begin
                    if features.challenger_char_lm_suffix_score <= -7061.4999999999991 then
                    begin
                        Result := 0.036466868974261393;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -5236.9999999999991 then
                        begin
                            if features.challenger_char_lm_score <= -4311.9999999999991 then
                            begin
                                if features.delta_top_complete_pool_consensus_support_min <= -329.49999999999994 then
                                begin
                                    if features.challenger_complete_pool_consensus_mean_distance <= 69687.500000000015 then
                                    begin
                                        Result := 0.023803416977343946;
                                    end
                                    else
                                    begin
                                        Result := -0.0079584334158929564;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.010704349359577352;
                                end;
                            end
                            else
                            begin
                                Result := -0.017423369266868771;
                            end;
                        end
                        else
                        begin
                            Result := 0.032296800851252659;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_47(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -386976639.99999994 then
    begin
        if features.delta_second_chain_first_stage_score <= -71003.499999999985 then
        begin
            Result := -0.017188663215726867;
        end
        else
        begin
            if features.delta_second_path_single_segments <= -1.4999999999999998 then
            begin
                Result := 0.00063205979398963546;
            end
            else
            begin
                Result := 0.038507741933452147;
            end;
        end;
    end
    else
    begin
        if features.challenger_rank <= 3.5000000000000004 then
        begin
            if features.different_units <= 1.5000000000000002 then
            begin
                if features.delta_top_char_lm_suffix_score <= 40.500000000000007 then
                begin
                    Result := -0.011063053976100969;
                end
                else
                begin
                    Result := 0.018021935331912847;
                end;
            end
            else
            begin
                if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
                begin
                    Result := -0.023990634539394231;
                end
                else
                begin
                    if features.challenger_word_lm_bonus <= 344.50000000000006 then
                    begin
                        Result := -0.016178786555689464;
                    end
                    else
                    begin
                        Result := 0.020917977189612143;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_second_chain_second_stage_score <= 123690864.00000001 then
            begin
                if features.challenger_char_lm_score <= -5270.4999999999991 then
                begin
                    if features.challenger_char_lm_score <= -5871.4999999999991 then
                    begin
                        if features.delta_second_complete_pool_signature_support <= 1.5000000000000002 then
                        begin
                            Result := 0.024466233352247454;
                        end
                        else
                        begin
                            Result := -0.011110330832290943;
                        end;
                    end
                    else
                    begin
                        Result := -0.016791683159613172;
                    end;
                end
                else
                begin
                    if features.delta_second_path_max_segment_units <= -1.0000000180025095E-35 then
                    begin
                        if features.challenger_char_lm_score <= -4480.4999999999991 then
                        begin
                            Result := 0.014422872610800878;
                        end
                        else
                        begin
                            Result := -0.022935559187118017;
                        end;
                    end
                    else
                    begin
                        Result := 0.012944957221417532;
                    end;
                end;
            end
            else
            begin
                Result := 0.020140876939503328;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_48(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -391502447.99999994 then
    begin
        if features.delta_second_chain_first_stage_score <= -71003.499999999985 then
        begin
            Result := -0.013206952626175402;
        end
        else
        begin
            Result := 0.029871566093072587;
        end;
    end
    else
    begin
        if features.challenger_rank <= 3.5000000000000004 then
        begin
            if features.delta_top_complete_pool_seed_rank <= 2.5000000000000004 then
            begin
                Result := -0.01517071882616448;
            end
            else
            begin
                Result := 0.010523128123383409;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_strong_ratio <= 18.000000000000004 then
            begin
                if features.delta_second_path_single_segments <= 1.0000000180025095E-35 then
                begin
                    if features.challenger_char_lm_suffix_score <= -5419.4999999999991 then
                    begin
                        if features.different_units <= 2.5000000000000004 then
                        begin
                            if features.challenger_complete_pool_consensus_support <= 815.50000000000011 then
                            begin
                                Result := 0.0012497691110520213;
                            end
                            else
                            begin
                                Result := -0.021971547054320736;
                            end;
                        end
                        else
                        begin
                            Result := 0.023483352848264166;
                        end;
                    end
                    else
                    begin
                        Result := 0.027249398668160712;
                    end;
                end
                else
                begin
                    Result := -0.015655233324148761;
                end;
            end
            else
            begin
                if features.challenger_legacy_rank <= 9.5000000000000018 then
                begin
                    if features.delta_second_chain_second_stage_score <= -74665051.999999985 then
                    begin
                        Result := -0.01534701063272911;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_pair_evidence <= 123.00000000000001 then
                        begin
                            Result := -0.010315673047806269;
                        end
                        else
                        begin
                            if features.delta_second_candidate_score <= -144.99999999999997 then
                            begin
                                if features.challenger_ranker_score_gap <= 60807250.000000007 then
                                begin
                                    Result := 0.0069009423981852861;
                                end
                                else
                                begin
                                    Result := 0.042029030019191088;
                                end;
                            end
                            else
                            begin
                                Result := -0.0013706715423429632;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.029253146008307768;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_49(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -380467919.99999994 then
    begin
        if features.delta_second_dict_weight_per_unit <= -11538.499999999998 then
        begin
            Result := -0.0064207537547030791;
        end
        else
        begin
            Result := 0.030771362451668966;
        end;
    end
    else
    begin
        if features.challenger_rank <= 3.5000000000000004 then
        begin
            if features.top_ranker_score <= -144949263.99999997 then
            begin
                Result := 0.0096631797700737817;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 348.50000000000006 then
                begin
                    Result := -0.018911621328731212;
                end
                else
                begin
                    Result := 0.0063755047155155068;
                end;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_bonus <= 44.500000000000007 then
            begin
                if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
                begin
                    if features.second_top_ranker_score_gap <= -160812047.99999997 then
                    begin
                        Result := -0.0042983412500031959;
                    end
                    else
                    begin
                        Result := 0.016456572067317335;
                    end;
                end
                else
                begin
                    if features.delta_second_char_lm_suffix_score <= 411.00000000000006 then
                    begin
                        Result := -0.036393241287410782;
                    end
                    else
                    begin
                        Result := 0.0;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_char_lm_score <= -97.499999999999986 then
                begin
                    Result := -0.0075956177508199165;
                end
                else
                begin
                    if features.delta_second_word_lm_strong_ratio <= 169.00000000000003 then
                    begin
                        if features.delta_second_word_lm_strong_ratio <= 68.000000000000014 then
                        begin
                            Result := 0.0038672843895330776;
                        end
                        else
                        begin
                            Result := 0.048268138852206918;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_supported_ratio <= 218.50000000000003 then
                        begin
                            Result := -0.010655402169349638;
                        end
                        else
                        begin
                            if features.top_ranker_score <= 168942512.00000003 then
                            begin
                                Result := 0.041390735966194192;
                            end
                            else
                            begin
                                Result := 0.0026069315719369772;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_50(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_legacy_rank <= 1.5000000000000002 then
    begin
        if features.delta_second_complete_pool_anchor_top_weight <= -1749.9999999999998 then
        begin
            Result := 0.0081923822761402754;
        end
        else
        begin
            Result := -0.018282807625231292;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 103446856.00000001 then
        begin
            if features.delta_second_legacy_rank <= 10.500000000000002 then
            begin
                if features.delta_top_complete_pool_anchor_source_weight <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_path_single_segments <= 1.5000000000000002 then
                    begin
                        if features.challenger_char_lm_score <= -3998.9999999999995 then
                        begin
                            if features.delta_top_word_lm_supported_ratio <= 90.500000000000014 then
                            begin
                                if features.delta_top_complete_pool_consensus_support_mean <= -95.499999999999986 then
                                begin
                                    Result := 0.010604118437350015;
                                end
                                else
                                begin
                                    if features.delta_top_chain_first_stage_score <= -1.0000000180025095E-35 then
                                    begin
                                        Result := 0.0010371968131309944;
                                    end
                                    else
                                    begin
                                        Result := -0.024744931880033832;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.019445316099700672;
                            end;
                        end
                        else
                        begin
                            Result := 0.030831224720987559;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                        begin
                            Result := 0.008198866702399275;
                        end
                        else
                        begin
                            Result := -0.021522016823119054;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.017276987750984223;
                end;
            end
            else
            begin
                Result := 0.022851041639678819;
            end;
        end
        else
        begin
            if features.delta_second_complete_pool_signature_support <= -2.4999999999999996 then
            begin
                Result := 0.035072166321195808;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -386976639.99999994 then
                begin
                    Result := 0.027088127753565571;
                end
                else
                begin
                    if features.delta_second_word_lm_strong_ratio <= 60.500000000000007 then
                    begin
                        Result := -0.0043571597440369113;
                    end
                    else
                    begin
                        Result := 0.013537195071133382;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_51(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 60807250.000000007 then
    begin
        if features.delta_second_legacy_rank <= 8.5000000000000018 then
        begin
            if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.019192297508993504;
            end
            else
            begin
                Result := -0.0031494813007442988;
            end;
        end
        else
        begin
            Result := 0.020030573792025018;
        end;
    end
    else
    begin
        if features.delta_second_legacy_rank <= -10.499999999999998 then
        begin
            Result := -0.023181290981489161;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 269634064.00000006 then
            begin
                if features.delta_top_word_lm_zero_count <= -1.0000000180025095E-35 then
                begin
                    if features.delta_top_char_lm_score <= -433.99999999999994 then
                    begin
                        Result := -0.0048027831808827278;
                    end
                    else
                    begin
                        if features.delta_top_complete_pool_consensus_mean_distance <= 2450.0000000000005 then
                        begin
                            Result := -0.0037066255305763297;
                        end
                        else
                        begin
                            Result := 0.033579431897585381;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -103003.49999999999 then
                    begin
                        if features.delta_second_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                        begin
                            if features.challenger_char_lm_suffix_score <= -6402.4999999999991 then
                            begin
                                Result := 0.0099760114411312894;
                            end
                            else
                            begin
                                Result := -0.019093739561569883;
                            end;
                        end
                        else
                        begin
                            Result := 0.026294690357758197;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_char_lm_score <= -35.499999999999993 then
                        begin
                            Result := -0.015214282011191281;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_consensus_support <= 5.5000000000000009 then
                            begin
                                if features.challenger_complete_pool_consensus_support <= 765.50000000000011 then
                                begin
                                    Result := -0.016844296659783656;
                                end
                                else
                                begin
                                    Result := 0.0085022988449568859;
                                end;
                            end
                            else
                            begin
                                Result := 0.028196141465117428;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.029569270967980898;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_52(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -251.49999999999997 then
        begin
            Result := 0.010801267037880148;
        end
        else
        begin
            Result := -0.014817642562089051;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_suffix_score <= 1086.0000000000002 then
        begin
            if features.challenger_complete_pool_consensus_unanimous_units <= 6.5000000000000009 then
            begin
                if features.delta_second_complete_pool_anchor_replacement_weight <= 661.50000000000011 then
                begin
                    if features.delta_top_chain_second_stage_score <= -79850023.999999985 then
                    begin
                        if features.challenger_ranker_score <= 245478344.00000003 then
                        begin
                            Result := -0.018102234510730945;
                        end
                        else
                        begin
                            Result := 0.0065815944041439957;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_score_per_unit <= 627.00000000000011 then
                        begin
                            if features.challenger_complete_pool_consensus_support <= 810.50000000000011 then
                            begin
                                if features.delta_top_char_lm_score <= -345.99999999999994 then
                                begin
                                    if features.challenger_complete_pool_consensus_mean_distance <= 18062.500000000004 then
                                    begin
                                        Result := 0.015071323275662215;
                                    end
                                    else
                                    begin
                                        Result := -0.020491587172415643;
                                    end;
                                end
                                else
                                begin
                                    if features.challenger_complete_pool_consensus_unanimous_units <= 4.5000000000000009 then
                                    begin
                                        Result := 0.035462890294247741;
                                    end
                                    else
                                    begin
                                        Result := 0.0044917424564079062;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.012757118530259808;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_candidate_score <= 57870.500000000007 then
                            begin
                                Result := -0.023402990118954591;
                            end
                            else
                            begin
                                Result := 0.0063556125406406981;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.019858608430164685;
                end;
            end
            else
            begin
                if features.delta_second_char_lm_score <= 221.50000000000003 then
                begin
                    Result := -0.0084856320271005387;
                end
                else
                begin
                    Result := 0.03512596177545535;
                end;
            end;
        end
        else
        begin
            Result := 0.027850752742309099;
        end;
    end;
end;

function second_slot_recovery_gate_tree_53(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        Result := -0.01320111898120562;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 134569208.00000003 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.delta_second_complete_pool_anchor_weight_gain <= 626.50000000000011 then
                begin
                    if features.challenger_char_lm_context_score <= -6496.4999999999991 then
                    begin
                        if features.delta_top_char_lm_suffix_score <= -85.499999999999986 then
                        begin
                            Result := 0.0029642849495539014;
                        end
                        else
                        begin
                            Result := 0.029430265744905777;
                        end;
                    end
                    else
                    begin
                        if features.challenger_char_lm_score <= -5297.4999999999991 then
                        begin
                            Result := -0.01939525153477839;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_anchor_source_weight <= 396.50000000000006 then
                            begin
                                Result := 0.014558081641446445;
                            end
                            else
                            begin
                                Result := -0.0074057605176240373;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0226061805917223;
                end;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -187235135.99999997 then
                begin
                    Result := 0.0037021574416906729;
                end
                else
                begin
                    Result := -0.020437896008387389;
                end;
            end;
        end
        else
        begin
            if features.delta_second_complete_pool_anchor_source_weight <= -354.99999999999994 then
            begin
                Result := -0.014656526226805111;
            end
            else
            begin
                if features.delta_second_word_lm_supported_ratio <= 49.000000000000007 then
                begin
                    if features.delta_second_complete_pool_signature_support <= 5.5000000000000009 then
                    begin
                        if features.delta_second_score_per_unit <= -629.49999999999989 then
                        begin
                            Result := 0.026926460244870512;
                        end
                        else
                        begin
                            Result := -0.004774714484723286;
                        end;
                    end
                    else
                    begin
                        Result := -0.016222456591450371;
                    end;
                end
                else
                begin
                    if features.delta_second_complete_pool_signature_support <= -6.4999999999999991 then
                    begin
                        Result := -0.0007491125619447348;
                    end
                    else
                    begin
                        Result := 0.032739079971292072;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_54(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -353318351.99999994 then
    begin
        if features.delta_second_chain_first_stage_score <= -72175.999999999985 then
        begin
            Result := -0.01795399183529205;
        end
        else
        begin
            if features.delta_top_char_lm_score <= -696.49999999999989 then
            begin
                Result := -0.00606517403486884;
            end
            else
            begin
                if features.max_different_run <= 2.5000000000000004 then
                begin
                    Result := 0.038834448230250382;
                end
                else
                begin
                    Result := 0.0043369786388579952;
                end;
            end;
        end;
    end
    else
    begin
        if features.challenger_complete_pool_seed_rank <= 3.5000000000000004 then
        begin
            if features.delta_second_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
            begin
                if features.delta_second_complete_pool_anchor_weight_gain <= -251.49999999999997 then
                begin
                    Result := 0.0037988397891557113;
                end
                else
                begin
                    Result := -0.019089430160680491;
                end;
            end
            else
            begin
                if features.challenger_char_lm_suffix_score <= -7446.9999999999991 then
                begin
                    Result := 0.021968403579908476;
                end
                else
                begin
                    if features.delta_second_word_lm_strong_ratio <= 18.000000000000004 then
                    begin
                        if features.delta_top_char_lm_score <= -92.499999999999986 then
                        begin
                            Result := -0.022955988066462849;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_mean_distance <= 24562.500000000004 then
                            begin
                                if features.challenger_char_lm_suffix_score <= -5881.4999999999991 then
                                begin
                                    Result := -0.0050566456504772175;
                                end
                                else
                                begin
                                    Result := 0.031514317719404439;
                                end;
                            end
                            else
                            begin
                                Result := -0.015246289704468247;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_complete_pool_consensus_mean_distance <= 24937.500000000004 then
                        begin
                            if features.challenger_char_lm_suffix_score <= -5148.9999999999991 then
                            begin
                                Result := -0.0058821144249459473;
                            end
                            else
                            begin
                                Result := 0.019876271077203817;
                            end;
                        end
                        else
                        begin
                            Result := 0.028122199831289579;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.014952769401971109;
        end;
    end;
end;

function second_slot_recovery_gate_tree_55(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -653.99999999999989 then
        begin
            Result := 0.013263348430838354;
        end
        else
        begin
            Result := -0.015993710816043158;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_top_char_lm_suffix_score <= -476.49999999999994 then
            begin
                Result := 0.01654649095715495;
            end
            else
            begin
                if features.delta_top_char_lm_score <= -395.49999999999994 then
                begin
                    Result := -0.028058837206949832;
                end
                else
                begin
                    if features.delta_top_word_lm_bonus <= 225.50000000000003 then
                    begin
                        Result := -0.0044175342293240553;
                    end
                    else
                    begin
                        Result := 0.020944797706293643;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_dict_weight <= -104175.49999999999 then
            begin
                if features.delta_second_dict_weight <= -164455.49999999997 then
                begin
                    Result := -0.006803406987210556;
                end
                else
                begin
                    if features.delta_top_complete_pool_consensus_support_min <= -692.49999999999989 then
                    begin
                        Result := 0.0067924193681951966;
                    end
                    else
                    begin
                        Result := 0.036914689634772624;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_dict_weight_per_unit <= -9331.4999999999982 then
                begin
                    Result := -0.017967794130729395;
                end
                else
                begin
                    if features.second_top_ranker_score_gap <= -372362463.99999994 then
                    begin
                        Result := 0.032384223193709517;
                    end
                    else
                    begin
                        if features.delta_second_dict_weight <= -92802.999999999985 then
                        begin
                            Result := 0.024861876855455434;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_support <= 757.50000000000011 then
                            begin
                                Result := -0.019187371549098362;
                            end
                            else
                            begin
                                if features.delta_top_char_lm_score <= 56.500000000000007 then
                                begin
                                    Result := -0.0037709568828589498;
                                end
                                else
                                begin
                                    Result := 0.033229255389976065;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_56(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_consensus_mean_distance <= 2562.5000000000005 then
    begin
        if features.max_different_run <= 1.5000000000000002 then
        begin
            if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
            begin
                if features.same_prefix_units <= 2.5000000000000004 then
                begin
                    Result := 0.025003641586657598;
                end
                else
                begin
                    Result := -0.0038922022883685335;
                end;
            end
            else
            begin
                Result := -0.015038174182204342;
            end;
        end
        else
        begin
            Result := -0.022404382157515237;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 230236536.00000003 then
        begin
            if features.delta_second_word_lm_boundary_first <= 1492.5000000000002 then
            begin
                if features.delta_second_legacy_rank <= 3.5000000000000004 then
                begin
                    if features.delta_second_path_segments <= 3.5000000000000004 then
                    begin
                        if features.delta_second_word_lm_supported_ratio <= 301.00000000000006 then
                        begin
                            Result := -0.0083045689527003041;
                        end
                        else
                        begin
                            Result := 0.019022652738973387;
                        end;
                    end
                    else
                    begin
                        Result := 0.020109156461535643;
                    end;
                end
                else
                begin
                    if features.delta_top_word_lm_bonus <= 238.50000000000003 then
                    begin
                        if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
                        begin
                            if features.challenger_complete_pool_consensus_unanimous_units <= 6.5000000000000009 then
                            begin
                                if features.second_top_ranker_score_gap <= -220432527.99999997 then
                                begin
                                    Result := 0.0051830469687740282;
                                end
                                else
                                begin
                                    Result := -0.017119433572082302;
                                end;
                            end
                            else
                            begin
                                Result := 0.024500346994046938;
                            end;
                        end
                        else
                        begin
                            Result := 0.035546134407875594;
                        end;
                    end
                    else
                    begin
                        Result := 0.040826090047718866;
                    end;
                end;
            end
            else
            begin
                Result := -0.0240712376128168;
            end;
        end
        else
        begin
            if features.delta_top_complete_pool_consensus_support_min <= -298.99999999999994 then
            begin
                Result := 0.030911583313804114;
            end
            else
            begin
                Result := -0.0033329741922684471;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_57(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_char_lm_score <= -219.99999999999997 then
        begin
            if features.delta_top_word_lm_strong_ratio <= 66.500000000000014 then
            begin
                Result := -0.020133167597068034;
            end
            else
            begin
                Result := 0.015577042542294932;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -380467919.99999994 then
            begin
                if features.delta_second_chain_second_stage_score <= -3473840.4999999995 then
                begin
                    Result := -0.0087789852329440941;
                end
                else
                begin
                    Result := 0.032714547524606521;
                end;
            end
            else
            begin
                if features.challenger_char_lm_score <= -6022.4999999999991 then
                begin
                    Result := 0.025583343435790447;
                end
                else
                begin
                    if features.challenger_word_lm_supported_ratio <= 289.50000000000006 then
                    begin
                        if features.challenger_complete_pool_signature_support <= 4.5000000000000009 then
                        begin
                            Result := -0.014949904136511481;
                        end
                        else
                        begin
                            Result := 0.0050276577980854949;
                        end;
                    end
                    else
                    begin
                        Result := 0.0097896637889814554;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_suffix_score <= 427.50000000000006 then
        begin
            if features.delta_top_complete_pool_consensus_support <= -28.499999999999996 then
            begin
                Result := -0.025326163214370322;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -133821559.99999999 then
                begin
                    Result := -0.018807512168662291;
                end
                else
                begin
                    Result := 0.013615110031766603;
                end;
            end;
        end
        else
        begin
            if features.delta_top_complete_pool_consensus_mean_distance <= 2562.5000000000005 then
            begin
                Result := -0.023214127886874776;
            end
            else
            begin
                if features.delta_second_chain_second_stage_score <= -15396544.999999998 then
                begin
                    Result := -0.013909700401338234;
                end
                else
                begin
                    if features.delta_second_complete_pool_anchor_source_weight <= 549.50000000000011 then
                    begin
                        Result := 0.036502670780394493;
                    end
                    else
                    begin
                        Result := -0.0078278451553946606;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_58(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.different_units <= 1.5000000000000002 then
        begin
            if features.delta_second_complete_pool_signature_support <= 1.0000000180025095E-35 then
            begin
                Result := 0.012078262828404936;
            end
            else
            begin
                Result := -0.011887395504382548;
            end;
        end
        else
        begin
            Result := -0.017102353616308266;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.challenger_char_lm_context_score <= -6454.4999999999991 then
            begin
                Result := 0.0066922817875208632;
            end
            else
            begin
                Result := -0.0068159193247943521;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_supported_ratio <= 133.50000000000003 then
            begin
                if features.challenger_word_lm_zero_count <= 3.5000000000000004 then
                begin
                    if features.delta_top_complete_pool_consensus_support <= -222.49999999999997 then
                    begin
                        Result := -0.027223300618998018;
                    end
                    else
                    begin
                        if features.challenger_complete_pool_consensus_support_min <= 62.000000000000007 then
                        begin
                            Result := 0.023213135487327358;
                        end
                        else
                        begin
                            Result := -0.020871456481596235;
                        end;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_mean_distance <= 117625.00000000001 then
                    begin
                        if features.same_prefix_units <= 6.5000000000000009 then
                        begin
                            if features.delta_top_char_lm_suffix_score <= -131.49999999999997 then
                            begin
                                Result := 0.0016271902370354851;
                            end
                            else
                            begin
                                Result := 0.038730541488482095;
                            end;
                        end
                        else
                        begin
                            Result := -0.0054217148262683543;
                        end;
                    end
                    else
                    begin
                        Result := -0.01222558106275734;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_chain_first_stage_score <= -51040.999999999993 then
                begin
                    if features.delta_second_word_lm_boundary_max <= 412.50000000000006 then
                    begin
                        Result := 0.020988501615544351;
                    end
                    else
                    begin
                        Result := -0.017039916549244791;
                    end;
                end
                else
                begin
                    Result := 0.030978229265522308;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_59(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.different_units <= 1.5000000000000002 then
        begin
            if features.delta_second_complete_pool_consensus_majority_units <= 1.0000000180025095E-35 then
            begin
                Result := -0.014347563207559878;
            end
            else
            begin
                Result := 0.024721960194802519;
            end;
        end
        else
        begin
            Result := -0.018942792155432289;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 269634064.00000006 then
        begin
            if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
            begin
                if features.delta_top_char_lm_suffix_score <= -214.49999999999997 then
                begin
                    Result := -0.0092652251537725105;
                end
                else
                begin
                    if features.delta_second_legacy_rank <= 6.5000000000000009 then
                    begin
                        if features.delta_second_char_lm_score <= 180.50000000000003 then
                        begin
                            Result := -0.012711879442255469;
                        end
                        else
                        begin
                            if features.delta_top_complete_pool_consensus_support <= -61.499999999999993 then
                            begin
                                if features.delta_second_complete_pool_pair_evidence <= 44.500000000000007 then
                                begin
                                    Result := -0.013975542338527731;
                                end
                                else
                                begin
                                    Result := 0.012991410696802864;
                                end;
                            end
                            else
                            begin
                                Result := 0.01754682692451788;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_path_single_segments <= 3.5000000000000004 then
                        begin
                            if features.challenger_complete_pool_local_pairwise_score <= -5734.9999999999991 then
                            begin
                                Result := -0.0033101385790711294;
                            end
                            else
                            begin
                                Result := 0.034512297973607026;
                            end;
                        end
                        else
                        begin
                            Result := -0.018095556890613314;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -187235135.99999997 then
                begin
                    Result := 0.031533263737693877;
                end
                else
                begin
                    Result := 0.0;
                end;
            end;
        end
        else
        begin
            if features.delta_second_complete_pool_consensus_support <= 84.500000000000014 then
            begin
                Result := 0.033657723822076262;
            end
            else
            begin
                Result := -0.0085978920558179624;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_60(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_mean_distance <= 3775.0000000000005 then
    begin
        if features.delta_second_complete_pool_anchor_weight_gain <= -306.49999999999994 then
        begin
            Result := 0.0095900464782414842;
        end
        else
        begin
            if features.challenger_word_lm_boundary_first <= 41.500000000000007 then
            begin
                Result := -0.019605740147925439;
            end
            else
            begin
                Result := 0.0022752874074053447;
            end;
        end;
    end
    else
    begin
        if features.challenger_char_lm_suffix_score <= -4822.4999999999991 then
        begin
            if features.delta_second_complete_pool_consensus_support_min <= -318.49999999999994 then
            begin
                if features.delta_top_dict_weight <= -81887.999999999985 then
                begin
                    if features.challenger_complete_pool_anchor_present <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.044282702086572208;
                    end
                    else
                    begin
                        Result := -0.0021071234704221706;
                    end;
                end
                else
                begin
                    if features.delta_top_word_lm_bonus <= 74.500000000000014 then
                    begin
                        Result := -0.0043147592740457649;
                    end
                    else
                    begin
                        Result := 0.021665575318928515;
                    end;
                end;
            end
            else
            begin
                if features.difference_span_units <= 7.5000000000000009 then
                begin
                    if features.second_ranker_score <= -183946399.99999997 then
                    begin
                        if features.delta_second_char_lm_suffix_score <= 19.500000000000004 then
                        begin
                            Result := -0.013640821872357904;
                        end
                        else
                        begin
                            if features.delta_second_word_lm_strong_ratio <= 18.000000000000004 then
                            begin
                                Result := 0.0056190811242668847;
                            end
                            else
                            begin
                                Result := 0.031933371454281503;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.challenger_word_lm_boundary_last <= 1396.5000000000002 then
                        begin
                            Result := -0.011569331746883411;
                        end
                        else
                        begin
                            Result := 0.0073205025924753635;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.015914415891711272;
                end;
            end;
        end
        else
        begin
            if features.delta_second_path_segments <= 1.5000000000000002 then
            begin
                Result := 0.039963045638029077;
            end
            else
            begin
                Result := 0.0;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_61(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 57614172.000000007 then
    begin
        if features.delta_top_legacy_rank <= 7.5000000000000009 then
        begin
            if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.018949111929080553;
            end
            else
            begin
                Result := -0.0016202516270102752;
            end;
        end
        else
        begin
            Result := 0.0083690761107023844;
        end;
    end
    else
    begin
        if features.delta_second_word_lm_bonus <= -6.4999999999999991 then
        begin
            Result := -0.011128355008223269;
        end
        else
        begin
            if features.challenger_char_lm_suffix_score <= -4822.4999999999991 then
            begin
                if features.delta_second_candidate_score <= -11418.499999999998 then
                begin
                    if features.challenger_complete_pool_consensus_support_min <= 181.50000000000003 then
                    begin
                        if features.second_ranker_score <= -53865577.999999993 then
                        begin
                            if features.delta_second_char_lm_suffix_score <= 338.50000000000006 then
                            begin
                                Result := 0.010617260944037166;
                            end
                            else
                            begin
                                Result := 0.041183201053962469;
                            end;
                        end
                        else
                        begin
                            Result := 0.0047222010108115969;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_signature_support <= 2.5000000000000004 then
                        begin
                            if features.delta_top_chain_score_gap <= -19629440.999999996 then
                            begin
                                Result := -0.013257569701614165;
                            end
                            else
                            begin
                                Result := 0.031074658409769071;
                            end;
                        end
                        else
                        begin
                            Result := -0.025402662307260782;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_word_lm_boundary_last <= 1234.5000000000002 then
                    begin
                        if features.delta_second_word_lm_supported_ratio <= 100.50000000000001 then
                        begin
                            Result := -0.003099118347442502;
                        end
                        else
                        begin
                            if features.second_ranker_score <= -134990807.99999997 then
                            begin
                                Result := 0.037518335418514084;
                            end
                            else
                            begin
                                Result := -0.0013260721558795562;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.019990495576123694;
                    end;
                end;
            end
            else
            begin
                Result := 0.030957957667568911;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_62(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_complete_pool_consensus_changed_support <= -180.99999999999997 then
        begin
            Result := 0.016446004496591188;
        end
        else
        begin
            if features.delta_top_char_lm_score <= 80.500000000000014 then
            begin
                Result := -0.02143400825527968;
            end
            else
            begin
                if features.same_prefix_units <= 3.5000000000000004 then
                begin
                    Result := 0.014438717253295799;
                end
                else
                begin
                    Result := -0.014447243870978002;
                end;
            end;
        end;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                Result := 0.0022940993965939677;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    Result := 0.0063634244427586105;
                end
                else
                begin
                    Result := -0.022342983094137864;
                end;
            end;
        end
        else
        begin
            if features.delta_top_chain_first_stage_score <= -175334.49999999997 then
            begin
                Result := -0.017949328201872627;
            end
            else
            begin
                if features.challenger_complete_pool_anchor_weight_gain <= -3142.4999999999995 then
                begin
                    Result := -0.0187268149049469;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                    begin
                        Result := -0.0045264746713325468;
                    end
                    else
                    begin
                        if features.delta_top_dict_weight <= -40264.499999999993 then
                        begin
                            if features.challenger_complete_pool_consensus_majority_units <= 6.5000000000000009 then
                            begin
                                if features.delta_top_dict_weight <= -137868.49999999997 then
                                begin
                                    Result := 0.03140080155317878;
                                end
                                else
                                begin
                                    Result := -0.0060888501312413353;
                                end;
                            end
                            else
                            begin
                                Result := 0.036980002383187549;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_dict_weight <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.024413347845534374;
                            end
                            else
                            begin
                                Result := -0.0043828746514669968;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_63(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -353318351.99999994 then
    begin
        if features.delta_top_char_lm_context_score <= -298.49999999999994 then
        begin
            if features.delta_top_complete_pool_consensus_support <= -125.49999999999999 then
            begin
                Result := 0.018812467827755874;
            end
            else
            begin
                Result := -0.015733685852402077;
            end;
        end
        else
        begin
            Result := 0.028056881514781636;
        end;
    end
    else
    begin
        if features.delta_second_word_lm_bonus <= 1.0000000180025095E-35 then
        begin
            if features.top_ranker_score <= -198094111.99999997 then
            begin
                Result := 0.01693352967725879;
            end
            else
            begin
                if features.delta_second_complete_pool_seed_rank <= 1.5000000000000002 then
                begin
                    if features.delta_top_score_per_unit <= 1162.5000000000002 then
                    begin
                        Result := -0.015446376185952636;
                    end
                    else
                    begin
                        if features.delta_top_char_lm_context_score <= -106.49999999999999 then
                        begin
                            Result := -0.015696628025376823;
                        end
                        else
                        begin
                            Result := 0.023609909492172895;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_top_complete_pool_consensus_support <= -90.499999999999986 then
                    begin
                        Result := -0.0052212686943385617;
                    end
                    else
                    begin
                        Result := 0.02455045788461022;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_dict_weight_per_unit <= -10423.999999999998 then
            begin
                if features.delta_second_char_lm_score <= -171.49999999999997 then
                begin
                    Result := -0.0036000493571969852;
                end
                else
                begin
                    Result := 0.025378299155979001;
                end;
            end
            else
            begin
                if features.challenger_char_lm_suffix_score <= -5044.9999999999991 then
                begin
                    if features.delta_top_legacy_rank <= 3.5000000000000004 then
                    begin
                        Result := -0.013810152184064908;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_boundary_last <= 1216.5000000000002 then
                        begin
                            Result := 0.017242485777751976;
                        end
                        else
                        begin
                            Result := -0.014252582730783015;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.027198156042739653;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_64(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
    begin
        if features.second_top_ranker_score_gap <= -372362463.99999994 then
        begin
            if features.delta_top_chain_second_stage_score <= -101399875.99999999 then
            begin
                Result := -0.0058242707056231306;
            end
            else
            begin
                Result := 0.028935614768328125;
            end;
        end
        else
        begin
            if features.delta_second_dict_weight <= -66293.999999999985 then
            begin
                if features.different_units <= 2.5000000000000004 then
                begin
                    Result := 0.0017947453681974551;
                end
                else
                begin
                    Result := 0.031881710046156891;
                end;
            end
            else
            begin
                if features.delta_top_char_lm_score <= -199.49999999999997 then
                begin
                    Result := -0.011221928946680721;
                end
                else
                begin
                    if features.challenger_char_lm_suffix_score <= -5236.9999999999991 then
                    begin
                        if features.challenger_char_lm_suffix_score <= -7061.4999999999991 then
                        begin
                            Result := 0.018739655459258247;
                        end
                        else
                        begin
                            if features.challenger_char_lm_score <= -5312.9999999999991 then
                            begin
                                Result := -0.019449183714058925;
                            end
                            else
                            begin
                                if features.same_prefix_units <= 2.5000000000000004 then
                                begin
                                    if features.delta_second_candidate_score <= -1.0000000180025095E-35 then
                                    begin
                                        Result := 0.034846459050924102;
                                    end
                                    else
                                    begin
                                        Result := -0.0028673741416324638;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0071195695677694973;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.max_different_run <= 1.5000000000000002 then
                        begin
                            Result := 0.039339734046059179;
                        end
                        else
                        begin
                            Result := -0.0038535095571298932;
                        end;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_top_char_lm_score <= 193.50000000000003 then
        begin
            if features.delta_top_score_per_unit <= 1162.5000000000002 then
            begin
                Result := -0.019389469403270816;
            end
            else
            begin
                Result := 0.010750248553170199;
            end;
        end
        else
        begin
            Result := 0.010039304198059065;
        end;
    end;
end;

function second_slot_recovery_gate_tree_65(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_char_lm_score <= -263.99999999999994 then
        begin
            if features.delta_top_complete_pool_signature_support <= -7.4999999999999991 then
            begin
                Result := 0.0096566369457194209;
            end
            else
            begin
                Result := -0.02021808662431801;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_supported_ratio <= 83.500000000000014 then
            begin
                if features.delta_top_path_single_segments <= 1.5000000000000002 then
                begin
                    if features.delta_second_chain_second_stage_score <= 88190484.000000015 then
                    begin
                        if features.challenger_ranker_score <= 252589680.00000003 then
                        begin
                            Result := -0.0077099891334168015;
                        end
                        else
                        begin
                            Result := 0.016761276621190008;
                        end;
                    end
                    else
                    begin
                        Result := 0.013653037642409348;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_anchor_present <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.028799672002728153;
                    end
                    else
                    begin
                        Result := -0.0046025575888434247;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_boundary_last <= 1234.5000000000002 then
                begin
                    if features.same_prefix_units <= 6.5000000000000009 then
                    begin
                        Result := 0.029547388679533867;
                    end
                    else
                    begin
                        Result := -0.001077407408349859;
                    end;
                end
                else
                begin
                    if features.delta_top_char_lm_score <= 63.500000000000007 then
                    begin
                        Result := -0.014486758503662;
                    end
                    else
                    begin
                        Result := 0.018428772063543847;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_second_complete_pool_seed_rank <= 1.5000000000000002 then
        begin
            if features.delta_top_score_per_unit <= 1162.5000000000002 then
            begin
                if features.delta_top_char_lm_score <= 193.50000000000003 then
                begin
                    Result := -0.021829616071196319;
                end
                else
                begin
                    Result := 0.0;
                end;
            end
            else
            begin
                Result := 0.0096042047655033273;
            end;
        end
        else
        begin
            Result := 0.019125658629974313;
        end;
    end;
end;

function second_slot_recovery_gate_tree_66(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 59367604.000000007 then
    begin
        if features.delta_second_legacy_rank <= 8.5000000000000018 then
        begin
            if features.challenger_complete_pool_seed_rank <= 2.5000000000000004 then
            begin
                Result := -0.017297232809255922;
            end
            else
            begin
                Result := -0.00092087030350199953;
            end;
        end
        else
        begin
            Result := 0.019079639078259027;
        end;
    end
    else
    begin
        if features.delta_second_legacy_rank <= -11.499999999999998 then
        begin
            Result := -0.022603164340945184;
        end
        else
        begin
            if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
            begin
                if features.delta_top_char_lm_score <= 13.500000000000002 then
                begin
                    if features.different_runs <= 1.5000000000000002 then
                    begin
                        if features.delta_top_dict_weight <= -116496.49999999999 then
                        begin
                            Result := 0.0083719759380898543;
                        end
                        else
                        begin
                            Result := -0.014857429970229374;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_consensus_nearest_distance <= 1.5000000000000002 then
                        begin
                            Result := -0.0088785340061680543;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_pair_evidence <= -42.499999999999993 then
                            begin
                                Result := -0.0060351855760820521;
                            end
                            else
                            begin
                                Result := 0.021867602749067783;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.second_top_ranker_score_gap <= -147017967.99999997 then
                    begin
                        if features.second_top_ranker_score_gap <= -312877151.99999994 then
                        begin
                            Result := 0.02442892405916329;
                        end
                        else
                        begin
                            if features.delta_second_char_lm_suffix_score <= 999.50000000000011 then
                            begin
                                if features.challenger_complete_pool_seed_rank <= 2.5000000000000004 then
                                begin
                                    Result := -0.0024413010382025777;
                                end
                                else
                                begin
                                    Result := 0.025852511579198649;
                                end;
                            end
                            else
                            begin
                                Result := -0.019061964417192163;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.028215804387548536;
                    end;
                end;
            end
            else
            begin
                Result := 0.024235141514747673;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_67(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_rank <= 2.5000000000000004 then
    begin
        if features.different_units <= 1.5000000000000002 then
        begin
            Result := 0.0018970275206143582;
        end
        else
        begin
            Result := -0.021449005823567159;
        end;
    end
    else
    begin
        if features.challenger_complete_pool_seed_rank <= 3.5000000000000004 then
        begin
            if features.delta_second_complete_pool_anchor_source_weight <= -354.99999999999994 then
            begin
                Result := -0.022707504183094539;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -353318351.99999994 then
                begin
                    if features.delta_second_dict_weight_per_unit <= -10245.999999999998 then
                    begin
                        Result := -0.01296602197337581;
                    end
                    else
                    begin
                        Result := 0.026816219974275763;
                    end;
                end
                else
                begin
                    if features.challenger_char_lm_suffix_score <= -7153.4999999999991 then
                    begin
                        if features.delta_top_complete_pool_consensus_support_min <= -607.99999999999989 then
                        begin
                            Result := -0.001362236323103167;
                        end
                        else
                        begin
                            Result := 0.032468506517026902;
                        end;
                    end
                    else
                    begin
                        if features.second_ranker_score <= -328211647.99999994 then
                        begin
                            Result := -0.030212790474629984;
                        end
                        else
                        begin
                            if features.challenger_candidate_score <= 62315.500000000007 then
                            begin
                                if features.delta_second_word_lm_zero_count <= -1.4999999999999998 then
                                begin
                                    Result := -0.020850611169404312;
                                end
                                else
                                begin
                                    if features.challenger_chain_score_gap <= -56552653.999999993 then
                                    begin
                                        Result := -0.022158925943414464;
                                    end
                                    else
                                    begin
                                        if features.challenger_char_lm_suffix_score <= -5872.4999999999991 then
                                        begin
                                            Result := 0.019772301401339898;
                                        end
                                        else
                                        begin
                                            Result := -0.0057228625043006945;
                                        end;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.0072992895522104662;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_char_lm_score <= -291.49999999999994 then
            begin
                Result := -0.0070646241834110149;
            end
            else
            begin
                Result := 0.022400065634922629;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_68(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_char_lm_score <= -263.99999999999994 then
        begin
            if features.delta_top_complete_pool_signature_support <= -9.4999999999999982 then
            begin
                Result := 0.012348240326250046;
            end
            else
            begin
                Result := -0.019118384436392345;
            end;
        end
        else
        begin
            if features.delta_top_dict_weight <= -96278.499999999985 then
            begin
                if features.delta_top_word_lm_supported_ratio <= -169.49999999999997 then
                begin
                    Result := -0.0073253881908681784;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_support_min <= 306.00000000000006 then
                    begin
                        Result := 0.02211670070094222;
                    end
                    else
                    begin
                        Result := -0.0051157838432768343;
                    end;
                end;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -372362463.99999994 then
                begin
                    Result := 0.029274582367489754;
                end
                else
                begin
                    if features.difference_span_units <= 5.5000000000000009 then
                    begin
                        if features.challenger_char_lm_suffix_score <= -5236.9999999999991 then
                        begin
                            if features.second_top_ranker_score_gap <= -124383515.99999999 then
                            begin
                                Result := -0.016612327064292307;
                            end
                            else
                            begin
                                Result := 0.0086774035533362312;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_consensus_support <= -70.499999999999986 then
                            begin
                                Result := -0.0048567954765706117;
                            end
                            else
                            begin
                                Result := 0.029591890306256866;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.019358076284570098;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_top_score_per_unit <= 1162.5000000000002 then
        begin
            if features.delta_top_char_lm_score <= 193.50000000000003 then
            begin
                if features.challenger_complete_pool_seed_rank <= 2.5000000000000004 then
                begin
                    Result := -0.022332540170986848;
                end
                else
                begin
                    Result := 0.0049003346798504278;
                end;
            end
            else
            begin
                Result := 0.0056983769961661988;
            end;
        end
        else
        begin
            Result := 0.024003813910893027;
        end;
    end;
end;

function second_slot_recovery_gate_tree_69(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 60807250.000000007 then
    begin
        if features.delta_top_legacy_rank <= 7.5000000000000009 then
        begin
            if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                if features.different_units <= 1.5000000000000002 then
                begin
                    Result := -0.0013206930919448425;
                end
                else
                begin
                    Result := -0.023501261759295372;
                end;
            end
            else
            begin
                if features.challenger_ranker_score_gap <= 36192024.000000007 then
                begin
                    Result := 0.014650347658240928;
                end
                else
                begin
                    Result := -0.012197705215142185;
                end;
            end;
        end
        else
        begin
            if features.challenger_path_single_segments <= 3.5000000000000004 then
            begin
                Result := 0.025892044968924992;
            end
            else
            begin
                Result := -0.0038862138430353511;
            end;
        end;
    end
    else
    begin
        if features.delta_top_word_lm_zero_count <= -1.0000000180025095E-35 then
        begin
            if features.delta_top_char_lm_score <= -433.99999999999994 then
            begin
                if features.challenger_complete_pool_consensus_mean_distance <= 15708.500000000002 then
                begin
                    Result := 0.015169145847128765;
                end
                else
                begin
                    Result := -0.021294296575570488;
                end;
            end
            else
            begin
                if features.delta_second_candidate_score <= 3335.0000000000005 then
                begin
                    if features.challenger_char_lm_score <= -4151.4999999999991 then
                    begin
                        Result := 0.041892761616789162;
                    end
                    else
                    begin
                        Result := 0.0058100620715553202;
                    end;
                end
                else
                begin
                    Result := 0.0027458896419845433;
                end;
            end;
        end
        else
        begin
            if features.delta_top_char_lm_score <= -35.499999999999993 then
            begin
                if features.delta_top_dict_weight <= -128823.99999999999 then
                begin
                    Result := 0.0071986562123778266;
                end
                else
                begin
                    Result := -0.015029389649830086;
                end;
            end
            else
            begin
                if features.delta_second_chain_score_gap <= 77207824.000000015 then
                begin
                    Result := 0.0041081357056521623;
                end
                else
                begin
                    Result := 0.030912990535025546;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_70(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
    begin
        if features.second_top_ranker_score_gap <= -94396163.999999985 then
        begin
            Result := -0.013824941294776434;
        end
        else
        begin
            Result := 0.0058199919744574957;
        end;
    end
    else
    begin
        if features.delta_second_char_lm_score <= 517.00000000000011 then
        begin
            if features.delta_top_complete_pool_consensus_support_min <= -718.49999999999989 then
            begin
                Result := -0.01676637991979088;
            end
            else
            begin
                if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
                begin
                    if features.delta_top_word_lm_bonus <= 205.50000000000003 then
                    begin
                        Result := -0.0087275171702572985;
                    end
                    else
                    begin
                        Result := 0.014809534224477542;
                    end;
                end
                else
                begin
                    if features.delta_top_chain_score_gap <= -55636843.999999993 then
                    begin
                        Result := -0.0033203759671624521;
                    end
                    else
                    begin
                        if features.delta_top_char_lm_score <= -83.499999999999986 then
                        begin
                            Result := 0.0050265809263469428;
                        end
                        else
                        begin
                            Result := 0.043881586114522211;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_dict_weight <= -147864.99999999997 then
            begin
                Result := 0.030431276615964269;
            end
            else
            begin
                if features.delta_second_path_max_segment_units <= -1.0000000180025095E-35 then
                begin
                    if features.delta_top_complete_pool_consensus_unanimous_units <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.0086528457575778348;
                    end
                    else
                    begin
                        Result := -0.020052235937548322;
                    end;
                end
                else
                begin
                    if features.challenger_complete_pool_consensus_support <= 773.50000000000011 then
                    begin
                        if features.challenger_word_lm_boundary_first <= 47.500000000000007 then
                        begin
                            if features.delta_second_score_per_unit <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.02851149662637267;
                            end
                            else
                            begin
                                Result := -0.015275306755536207;
                            end;
                        end
                        else
                        begin
                            Result := -0.020342072685839686;
                        end;
                    end
                    else
                    begin
                        Result := 0.028709217010569055;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_71(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_complete_pool_consensus_support_min <= -294.99999999999994 then
    begin
        if features.second_top_ranker_score_gap <= -386976639.99999994 then
        begin
            Result := 0.032896352821482844;
        end
        else
        begin
            if features.challenger_rank <= 5.5000000000000009 then
            begin
                if features.delta_top_char_lm_score <= 46.500000000000007 then
                begin
                    Result := -0.008544083400255989;
                end
                else
                begin
                    Result := 0.013772601862774222;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_local_pairwise_score <= -5085.4999999999991 then
                begin
                    Result := -0.004040383310251759;
                end
                else
                begin
                    Result := 0.034133524400639548;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
        begin
            if features.delta_second_chain_first_stage_score <= -43745.999999999993 then
            begin
                if features.challenger_chain_second_stage_score <= -96689059.999999985 then
                begin
                    Result := -0.0044970085087301659;
                end
                else
                begin
                    Result := 0.029675345662671573;
                end;
            end
            else
            begin
                if features.delta_top_char_lm_score <= -92.499999999999986 then
                begin
                    if features.delta_top_complete_pool_consensus_support <= -54.499999999999993 then
                    begin
                        if features.challenger_chain_rank <= 1.0000000180025095E-35 then
                        begin
                            Result := -0.0079813237200634622;
                        end
                        else
                        begin
                            Result := 0.01963090055743261;
                        end;
                    end
                    else
                    begin
                        Result := -0.018492924536744493;
                    end;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -166954.99999999997 then
                    begin
                        Result := 0.027396256388729889;
                    end
                    else
                    begin
                        if features.delta_top_dict_weight <= -243.99999999999997 then
                        begin
                            if features.challenger_complete_pool_consensus_unanimous_units <= 6.5000000000000009 then
                            begin
                                Result := -0.012306341019282218;
                            end
                            else
                            begin
                                Result := 0.015921590684986588;
                            end;
                        end
                        else
                        begin
                            Result := 0.021165552574205142;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.01233356117758549;
        end;
    end;
end;

function second_slot_recovery_gate_tree_72(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_rank <= 3.5000000000000004 then
    begin
        if features.delta_second_word_lm_supported_ratio <= 281.00000000000006 then
        begin
            if features.second_ranker_score <= -335711071.99999994 then
            begin
                Result := 0.01593005086494188;
            end
            else
            begin
                if features.delta_top_char_lm_suffix_score <= 68.500000000000014 then
                begin
                    Result := -0.016829570874444276;
                end
                else
                begin
                    Result := -0.00012162537651085827;
                end;
            end;
        end
        else
        begin
            Result := 0.016005850646268669;
        end;
    end
    else
    begin
        if features.delta_top_complete_pool_consensus_support_min <= -34.999999999999993 then
        begin
            if features.delta_second_word_lm_strong_ratio <= 47.000000000000007 then
            begin
                if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_dict_weight_per_unit <= -11104.499999999998 then
                    begin
                        Result := -0.01945045711041463;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 177602120.00000003 then
                        begin
                            Result := -0.0094012019284388307;
                        end
                        else
                        begin
                            if features.delta_top_char_lm_score <= -105.49999999999999 then
                            begin
                                Result := -0.0026973870065447438;
                            end
                            else
                            begin
                                Result := 0.029980772293619496;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.018380272832339943;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 268.50000000000006 then
                begin
                    Result := 0.030080086718191533;
                end
                else
                begin
                    if features.delta_second_word_lm_supported_ratio <= 166.50000000000003 then
                    begin
                        Result := -0.026568101059258768;
                    end
                    else
                    begin
                        if features.different_units <= 2.5000000000000004 then
                        begin
                            if features.second_top_ranker_score_gap <= -277168399.99999994 then
                            begin
                                Result := -0.016786916126582438;
                            end
                            else
                            begin
                                Result := 0.0083931258081029053;
                            end;
                        end
                        else
                        begin
                            Result := 0.02014790755198383;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.026707751406356221;
        end;
    end;
end;

function second_slot_recovery_gate_tree_73(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_word_lm_bonus <= -6.4999999999999991 then
    begin
        Result := -0.010944599366029213;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 59367604.000000007 then
        begin
            Result := -0.0066002860207248224;
        end
        else
        begin
            if features.delta_second_complete_pool_signature_support <= 1.5000000000000002 then
            begin
                if features.delta_second_dict_weight <= 2883.5000000000005 then
                begin
                    if features.second_top_ranker_score_gap <= -253435359.99999997 then
                    begin
                        if features.second_top_ranker_score_gap <= -353318351.99999994 then
                        begin
                            if features.challenger_complete_pool_pair_evidence <= 3114.0000000000005 then
                            begin
                                Result := 0.030447981128859519;
                            end
                            else
                            begin
                                Result := -0.014684598429622055;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_word_lm_bonus <= 44.500000000000007 then
                            begin
                                Result := -0.019277298022395823;
                            end
                            else
                            begin
                                Result := 0.017329383266535284;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.challenger_ranker_score_gap <= 71505292.000000015 then
                        begin
                            Result := 0.0037621521516674056;
                        end
                        else
                        begin
                            if features.challenger_text_units <= 9.5000000000000018 then
                            begin
                                Result := 0.044883310673533197;
                            end
                            else
                            begin
                                if features.delta_second_char_lm_score <= 139.50000000000003 then
                                begin
                                    Result := -0.0051834431323696372;
                                end
                                else
                                begin
                                    Result := 0.030515591919402056;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.014479469745693583;
                end;
            end
            else
            begin
                if features.delta_second_path_segments <= 4.5000000000000009 then
                begin
                    if features.challenger_char_lm_score <= -6671.4999999999991 then
                    begin
                        Result := -0.025730107941992132;
                    end
                    else
                    begin
                        if features.second_top_ranker_score_gap <= -288689071.99999994 then
                        begin
                            Result := 0.011813740301358714;
                        end
                        else
                        begin
                            Result := -0.0081145423307268771;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.032820773400654257;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_74(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_rank <= 3.5000000000000004 then
    begin
        if features.challenger_legacy_rank <= 3.5000000000000004 then
        begin
            if features.delta_second_word_lm_supported_ratio <= 263.00000000000006 then
            begin
                if features.top_ranker_score <= -127955103.99999999 then
                begin
                    Result := 0.0095771957652861957;
                end
                else
                begin
                    Result := -0.010686032252514679;
                end;
            end
            else
            begin
                Result := 0.018569664291694415;
            end;
        end
        else
        begin
            Result := -0.032676427282409264;
        end;
    end
    else
    begin
        if features.delta_top_word_lm_zero_count <= -1.0000000180025095E-35 then
        begin
            if features.challenger_complete_pool_anchor_top_weight <= 707.50000000000011 then
            begin
                Result := 0.020428136669717066;
            end
            else
            begin
                Result := -0.014209944374642902;
            end;
        end
        else
        begin
            if features.delta_second_char_lm_score <= 37.500000000000007 then
            begin
                if features.second_top_ranker_score_gap <= -256337959.99999997 then
                begin
                    Result := -0.028426643324937127;
                end
                else
                begin
                    Result := -0.0038157919985647702;
                end;
            end
            else
            begin
                if features.delta_second_word_lm_bonus <= 44.500000000000007 then
                begin
                    if features.delta_top_complete_pool_consensus_mean_distance <= 39770.500000000007 then
                    begin
                        if features.delta_top_complete_pool_consensus_mean_distance <= 8937.5000000000018 then
                        begin
                            Result := -0.0099012464511006801;
                        end
                        else
                        begin
                            if features.delta_second_dict_weight_per_unit <= -6036.4999999999991 then
                            begin
                                Result := 0.0039074558894905053;
                            end
                            else
                            begin
                                Result := 0.03723919977380593;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.012673744614442265;
                    end;
                end
                else
                begin
                    if features.delta_second_word_lm_bonus <= 278.50000000000006 then
                    begin
                        Result := 0.03557358435427501;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_consensus_unanimous_units <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.023632830631908144;
                        end
                        else
                        begin
                            Result := -0.0088884478253716415;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_75(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -457875039.99999994 then
    begin
        if features.top_ranker_score <= 551407904.00000012 then
        begin
            Result := 0.037619780272716792;
        end
        else
        begin
            Result := -0.0050726104550330034;
        end;
    end
    else
    begin
        if features.challenger_rank <= 3.5000000000000004 then
        begin
            Result := -0.0080581683986015295;
        end
        else
        begin
            if features.challenger_path_single_segments <= 4.5000000000000009 then
            begin
                if features.delta_top_legacy_rank <= 2.5000000000000004 then
                begin
                    Result := 0.035407177740153083;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -162072.99999999997 then
                    begin
                        Result := 0.020004002829235781;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_consensus_support_min <= -400.99999999999994 then
                        begin
                            Result := 0.020545198606866752;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_unanimous_units <= 6.5000000000000009 then
                            begin
                                if features.challenger_ranker_score <= 252589680.00000003 then
                                begin
                                    if features.challenger_char_lm_suffix_score <= -6378.9999999999991 then
                                    begin
                                        if features.delta_second_dict_weight <= -66293.999999999985 then
                                        begin
                                            Result := 0.027486699194671695;
                                        end
                                        else
                                        begin
                                            if features.challenger_ranker_score <= -197016047.99999997 then
                                            begin
                                                Result := -0.019846072693822003;
                                            end
                                            else
                                            begin
                                                Result := 0.010614752745721724;
                                            end;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := -0.01762371930666598;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.013133037950867415;
                                end;
                            end
                            else
                            begin
                                if features.delta_second_char_lm_score <= 299.50000000000006 then
                                begin
                                    Result := -0.00098306761818914529;
                                end
                                else
                                begin
                                    Result := 0.031198255822872296;
                                end;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_score_per_unit <= -6291.9999999999991 then
                begin
                    Result := -0.022929360718926879;
                end
                else
                begin
                    Result := 0.00051490904973893988;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_76(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 269634064.00000006 then
    begin
        if features.delta_second_word_lm_boundary_count <= 1.0000000180025095E-35 then
        begin
            if features.top_ranker_score <= -268602783.99999994 then
            begin
                Result := 0.027700450203267283;
            end
            else
            begin
                if features.challenger_char_lm_suffix_score <= -5236.9999999999991 then
                begin
                    if features.challenger_complete_pool_consensus_support_mean <= 708.50000000000011 then
                    begin
                        if features.challenger_complete_pool_anchor_top_weight <= 707.50000000000011 then
                        begin
                            if features.delta_second_char_lm_suffix_score <= 469.50000000000006 then
                            begin
                                Result := 0.033358929309981279;
                            end
                            else
                            begin
                                Result := -5.8507204520214838E-05;
                            end;
                        end
                        else
                        begin
                            Result := -0.011679122369084732;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_boundary_max <= 1510.5000000000002 then
                        begin
                            if features.second_top_ranker_score_gap <= -353318351.99999994 then
                            begin
                                Result := 0.017079237651049965;
                            end
                            else
                            begin
                                if features.delta_top_complete_pool_consensus_support <= -142.49999999999997 then
                                begin
                                    Result := -0.019248219452366093;
                                end
                                else
                                begin
                                    if features.delta_second_complete_pool_consensus_support_mean <= -20.499999999999996 then
                                    begin
                                        Result := 0.0092297248625819069;
                                    end
                                    else
                                    begin
                                        Result := -0.0087395723859171933;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.027597465392137054;
                        end;
                    end;
                end
                else
                begin
                    if features.max_different_run <= 1.5000000000000002 then
                    begin
                        Result := 0.033049942522978125;
                    end
                    else
                    begin
                        Result := -0.0042961062646176204;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_score_per_unit <= 1162.5000000000002 then
            begin
                if features.delta_top_char_lm_suffix_score <= 199.00000000000003 then
                begin
                    Result := -0.017272408963675618;
                end
                else
                begin
                    Result := 0.0047784109387083518;
                end;
            end
            else
            begin
                Result := 0.013519752498872861;
            end;
        end;
    end
    else
    begin
        Result := 0.023385637744335049;
    end;
end;

function second_slot_recovery_gate_tree_77(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= -11.499999999999998 then
    begin
        Result := -0.021163103113596878;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 59367604.000000007 then
        begin
            if features.delta_second_legacy_rank <= 8.5000000000000018 then
            begin
                Result := -0.0088988798457287615;
            end
            else
            begin
                Result := 0.021157508194581499;
            end;
        end
        else
        begin
            if features.difference_span_units <= 4.5000000000000009 then
            begin
                if features.delta_top_chain_second_stage_score <= -72541119.999999985 then
                begin
                    Result := -0.011527716355204181;
                end
                else
                begin
                    if features.delta_top_dict_weight <= -101029.49999999999 then
                    begin
                        if features.challenger_char_lm_score <= -4419.4999999999991 then
                        begin
                            if features.delta_second_complete_pool_signature_support <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.045311624310191076;
                            end
                            else
                            begin
                                Result := 0.0069922820157135241;
                            end;
                        end
                        else
                        begin
                            if features.challenger_ranker_score <= 184954864.00000003 then
                            begin
                                Result := -0.019309352472870182;
                            end
                            else
                            begin
                                Result := 0.016600119568125755;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_score_per_unit <= 1162.5000000000002 then
                        begin
                            Result := -0.0029992180282400679;
                        end
                        else
                        begin
                            Result := 0.019432040768793853;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_signature_support <= 21.500000000000004 then
                begin
                    if features.delta_second_chain_first_stage_score <= -123426.99999999999 then
                    begin
                        Result := -0.0076902699734854099;
                    end
                    else
                    begin
                        if features.challenger_word_lm_boundary_max <= 1399.5000000000002 then
                        begin
                            if features.delta_top_complete_pool_consensus_support_min <= -378.49999999999994 then
                            begin
                                Result := 0.0029735566529445327;
                            end
                            else
                            begin
                                Result := 0.037688598656888263;
                            end;
                        end
                        else
                        begin
                            Result := 0.041060744086052037;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.013491789285557172;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_78(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 107590816.00000001 then
    begin
        if features.challenger_char_lm_suffix_score <= -6454.4999999999991 then
        begin
            if features.delta_second_dict_weight_per_unit <= -7426.9999999999991 then
            begin
                Result := 0.022677548982227531;
            end
            else
            begin
                if features.challenger_complete_pool_consensus_support <= 713.50000000000011 then
                begin
                    Result := 0.01557345101382525;
                end
                else
                begin
                    Result := -0.009548229509948658;
                end;
            end;
        end
        else
        begin
            if features.challenger_char_lm_score <= -5258.4999999999991 then
            begin
                Result := -0.022704873477466223;
            end
            else
            begin
                if features.delta_second_dict_weight_per_unit <= -10462.999999999998 then
                begin
                    Result := -0.014762141094682261;
                end
                else
                begin
                    if features.challenger_rank <= 3.5000000000000004 then
                    begin
                        Result := -0.00707227771124705;
                    end
                    else
                    begin
                        if features.delta_second_path_segments <= 1.5000000000000002 then
                        begin
                            if features.challenger_word_lm_boundary_max <= 1513.5000000000002 then
                            begin
                                Result := 0.0044027669146688283;
                            end
                            else
                            begin
                                Result := 0.034844058156124194;
                            end;
                        end
                        else
                        begin
                            Result := -0.0088279437626998872;
                        end;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        if features.challenger_chain_second_stage_score <= -24979067.999999996 then
        begin
            Result := -0.010868805164395754;
        end
        else
        begin
            if features.delta_second_score_per_unit <= -19104.999999999996 then
            begin
                Result := 0.03314913094223617;
            end
            else
            begin
                if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
                begin
                    if features.challenger_path_segments <= 5.5000000000000009 then
                    begin
                        if features.delta_second_complete_pool_pair_evidence <= 44.500000000000007 then
                        begin
                            Result := -0.013901986595358452;
                        end
                        else
                        begin
                            Result := 0.0090839404377634284;
                        end;
                    end
                    else
                    begin
                        Result := 0.012905007403417396;
                    end;
                end
                else
                begin
                    Result := 0.028524101420749414;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_79(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_source_kind <= 1.0000000180025095E-35 then
    begin
        if features.second_top_ranker_score_gap <= -94396163.999999985 then
        begin
            Result := -0.014710309262477168;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 50205024.000000007 then
            begin
                Result := -0.011274461519813796;
            end
            else
            begin
                Result := 0.017984784428035895;
            end;
        end;
    end
    else
    begin
        if features.second_top_ranker_score_gap <= -483759519.99999994 then
        begin
            if features.top_ranker_score <= 551407904.00000012 then
            begin
                Result := 0.035356942949915371;
            end
            else
            begin
                Result := -0.0041454276975240135;
            end;
        end
        else
        begin
            if features.delta_top_dict_weight <= -105710.99999999999 then
            begin
                if features.delta_second_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                begin
                    Result := -0.0030894938726463267;
                end
                else
                begin
                    if features.challenger_ranker_score_gap <= 71505292.000000015 then
                    begin
                        Result := 0.0015397918720201332;
                    end
                    else
                    begin
                        if features.same_prefix_units <= 6.5000000000000009 then
                        begin
                            Result := 0.031822201442471408;
                        end
                        else
                        begin
                            Result := 0.0;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_top_dict_weight_per_unit <= -9757.4999999999982 then
                begin
                    Result := -0.02024406741312966;
                end
                else
                begin
                    if features.delta_top_candidate_score <= 10377.500000000002 then
                    begin
                        if features.challenger_candidate_score <= 52584.000000000007 then
                        begin
                            if features.delta_second_char_lm_score <= 866.00000000000011 then
                            begin
                                Result := -0.0015068891180159165;
                            end
                            else
                            begin
                                Result := 0.016749320992222656;
                            end;
                        end
                        else
                        begin
                            Result := -0.012847315380735561;
                        end;
                    end
                    else
                    begin
                        if features.challenger_score_per_unit <= 5292.0000000000009 then
                        begin
                            Result := -0.0026099558102745985;
                        end
                        else
                        begin
                            Result := 0.034052969162264482;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_80(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.second_top_ranker_score_gap <= -386976639.99999994 then
    begin
        if features.delta_second_chain_first_stage_score <= -71003.499999999985 then
        begin
            Result := -0.01747759916638756;
        end
        else
        begin
            if features.top_ranker_score <= 639253088.00000012 then
            begin
                Result := 0.030607109985238853;
            end
            else
            begin
                Result := -0.010877964156796269;
            end;
        end;
    end
    else
    begin
        if features.delta_second_legacy_rank <= 3.5000000000000004 then
        begin
            if features.delta_second_word_lm_boundary_first <= 46.500000000000007 then
            begin
                if features.delta_top_char_lm_score <= 72.500000000000014 then
                begin
                    if features.challenger_path_segments <= 6.5000000000000009 then
                    begin
                        if features.max_different_run <= 1.5000000000000002 then
                        begin
                            Result := 0.0031528607584016661;
                        end
                        else
                        begin
                            Result := -0.014028819971470784;
                        end;
                    end
                    else
                    begin
                        Result := -0.019475975033241076;
                    end;
                end
                else
                begin
                    if features.delta_top_dict_weight_per_unit <= -6679.9999999999991 then
                    begin
                        Result := -0.0050576956155588887;
                    end
                    else
                    begin
                        Result := 0.014115049591072435;
                    end;
                end;
            end
            else
            begin
                if features.same_prefix_units <= 3.5000000000000004 then
                begin
                    Result := 0.037231457659987054;
                end
                else
                begin
                    Result := -0.0099400501238504687;
                end;
            end;
        end
        else
        begin
            if features.delta_second_word_lm_boundary_max <= 1363.5000000000002 then
            begin
                if features.delta_second_path_single_segments <= 1.5000000000000002 then
                begin
                    if features.delta_top_complete_pool_consensus_support_min <= -650.99999999999989 then
                    begin
                        Result := 0.00098563217840039077;
                    end
                    else
                    begin
                        if features.challenger_score_per_unit <= 4225.5000000000009 then
                        begin
                            Result := 0.0049134878461755483;
                        end
                        else
                        begin
                            Result := 0.036227262589236704;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0057582488166498342;
                end;
            end
            else
            begin
                Result := -0.015536827824303307;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_81(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
    begin
        if features.delta_second_word_lm_strong_ratio <= -10.499999999999998 then
        begin
            Result := -0.013645851298508375;
        end
        else
        begin
            if features.delta_top_chain_second_stage_score <= 130331164.00000001 then
            begin
                if features.challenger_ranker_score <= 284276224.00000006 then
                begin
                    if features.same_suffix_units <= 8.5000000000000018 then
                    begin
                        if features.second_top_ranker_score_gap <= -433392623.99999994 then
                        begin
                            if features.challenger_ranker_score <= 169136040.00000003 then
                            begin
                                Result := 0.030738782986062814;
                            end
                            else
                            begin
                                Result := -0.013692972329873876;
                            end;
                        end
                        else
                        begin
                            if features.challenger_char_lm_suffix_score <= -6454.4999999999991 then
                            begin
                                if features.delta_second_word_lm_boundary_max <= 1102.5000000000002 then
                                begin
                                    if features.second_top_ranker_score_gap <= -256337959.99999997 then
                                    begin
                                        Result := -0.019241654245043073;
                                    end
                                    else
                                    begin
                                        if features.challenger_score_per_unit <= 4164.0000000000009 then
                                        begin
                                            Result := 0.021408476078616106;
                                        end
                                        else
                                        begin
                                            Result := -0.0063708956789670194;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.023519375421942271;
                                end;
                            end
                            else
                            begin
                                if features.challenger_rank <= 3.5000000000000004 then
                                begin
                                    Result := -0.019146758953925896;
                                end
                                else
                                begin
                                    if features.challenger_char_lm_score <= -5297.4999999999991 then
                                    begin
                                        Result := -0.02067907001296013;
                                    end
                                    else
                                    begin
                                        Result := 0.00098030761138106028;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.01749917918221347;
                    end;
                end
                else
                begin
                    Result := 0.013594848963386997;
                end;
            end
            else
            begin
                Result := 0.024570757796069043;
            end;
        end;
    end
    else
    begin
        if features.challenger_complete_pool_consensus_support_min <= 95.500000000000014 then
        begin
            Result := 0.026380884521168258;
        end
        else
        begin
            Result := 0.0;
        end;
    end;
end;

function second_slot_recovery_gate_tree_82(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_complete_pool_seed_rank <= 3.5000000000000004 then
    begin
        if features.delta_top_score_per_unit <= 1162.5000000000002 then
        begin
            if features.second_top_ranker_score_gap <= -353318351.99999994 then
            begin
                if features.delta_second_chain_first_stage_score <= -72175.999999999985 then
                begin
                    Result := -0.021663175025505847;
                end
                else
                begin
                    if features.delta_second_complete_pool_anchor_top_weight <= -1.0000000180025095E-35 then
                    begin
                        Result := -0.012513829009281214;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -5707.4999999999991 then
                        begin
                            Result := 0.007134018763316618;
                        end
                        else
                        begin
                            Result := 0.038827533353174848;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.challenger_char_lm_suffix_score <= -7183.4999999999991 then
                begin
                    if features.challenger_complete_pool_consensus_seed_count <= 7.5000000000000009 then
                    begin
                        Result := -0.0069838922079724511;
                    end
                    else
                    begin
                        Result := 0.026757743796535154;
                    end;
                end
                else
                begin
                    if features.delta_top_word_lm_bonus <= 125.50000000000001 then
                    begin
                        Result := -0.01260386373118884;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_boundary_max <= 1384.5000000000002 then
                        begin
                            if features.delta_top_complete_pool_consensus_mean_distance <= 3562.5000000000005 then
                            begin
                                Result := -0.0050260776777193818;
                            end
                            else
                            begin
                                Result := 0.027398805912383299;
                            end;
                        end
                        else
                        begin
                            Result := -0.016066016149766205;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_char_lm_score <= -46.499999999999993 then
            begin
                Result := -0.0018231473393237312;
            end
            else
            begin
                Result := 0.03630141511920245;
            end;
        end;
    end
    else
    begin
        if features.delta_top_score_per_unit <= 486.00000000000006 then
        begin
            if features.challenger_candidate_score <= 30318.000000000004 then
            begin
                Result := 0.0051013988016604637;
            end
            else
            begin
                Result := 0.029416841036030802;
            end;
        end
        else
        begin
            Result := -0.010748439417980257;
        end;
    end;
end;

function second_slot_recovery_gate_tree_83(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 60807250.000000007 then
    begin
        if features.delta_second_path_single_segments <= 1.5000000000000002 then
        begin
            if features.delta_top_legacy_rank <= 7.5000000000000009 then
            begin
                Result := -0.0061897051187763024;
            end
            else
            begin
                Result := 0.017808306138274704;
            end;
        end
        else
        begin
            if features.delta_second_complete_pool_consensus_support_min <= -236.49999999999997 then
            begin
                Result := 0.0;
            end
            else
            begin
                Result := -0.028427483304465984;
            end;
        end;
    end
    else
    begin
        if features.second_top_ranker_score_gap <= -127469123.99999999 then
        begin
            if features.delta_second_word_lm_bonus <= -1.0000000180025095E-35 then
            begin
                Result := -0.012589219247843142;
            end
            else
            begin
                if features.second_top_ranker_score_gap <= -433392623.99999994 then
                begin
                    Result := 0.024565436221859017;
                end
                else
                begin
                    if features.challenger_char_lm_suffix_score <= -5236.9999999999991 then
                    begin
                        if features.top_ranker_score <= 164004720.00000003 then
                        begin
                            if features.delta_second_word_lm_bonus <= 319.50000000000006 then
                            begin
                                if features.challenger_ranker_score_gap <= 191175496.00000003 then
                                begin
                                    Result := 0.0045513464172096873;
                                end
                                else
                                begin
                                    Result := -0.017740143302107759;
                                end;
                            end
                            else
                            begin
                                Result := 0.029496683442520231;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_consensus_support_mean <= -73.499999999999986 then
                            begin
                                Result := 0.010919426938463166;
                            end
                            else
                            begin
                                if features.challenger_complete_pool_consensus_support <= 773.50000000000011 then
                                begin
                                    Result := -0.038162989129332268;
                                end
                                else
                                begin
                                    Result := -0.008363033735417566;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.018217474052481145;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_complete_pool_signature_support <= 3.5000000000000004 then
            begin
                Result := 0.038196993254921222;
            end
            else
            begin
                Result := 0.0070137783580314049;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_84(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= -11.499999999999998 then
    begin
        Result := -0.019736365568221181;
    end
    else
    begin
        if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
        begin
            if features.delta_second_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                if features.delta_top_score_per_unit <= 1162.5000000000002 then
                begin
                    if features.delta_second_complete_pool_anchor_weight_gain <= -367.49999999999994 then
                    begin
                        if features.delta_second_complete_pool_anchor_source_weight <= 1734.0000000000002 then
                        begin
                            Result := 0.025362267777691076;
                        end
                        else
                        begin
                            if features.delta_top_dict_weight <= -116496.49999999999 then
                            begin
                                Result := 0.012798826161950272;
                            end
                            else
                            begin
                                Result := -0.014573294516399519;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                        begin
                            if features.top_ranker_score <= -110373499.99999999 then
                            begin
                                Result := 0.0079689956166935222;
                            end
                            else
                            begin
                                Result := -0.016700505383835482;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_score_per_unit <= -9454.9999999999982 then
                            begin
                                Result := 0.014756711145638523;
                            end
                            else
                            begin
                                Result := -0.007200255535879419;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_top_char_lm_score <= -46.499999999999993 then
                    begin
                        Result := -0.0047660253619914196;
                    end
                    else
                    begin
                        Result := 0.035555248138398395;
                    end;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_consensus_seed_count <= 3.5000000000000004 then
                begin
                    Result := 0.0012085980157888864;
                end
                else
                begin
                    if features.delta_second_complete_pool_consensus_support_min <= -83.999999999999986 then
                    begin
                        Result := 0.006148657994407958;
                    end
                    else
                    begin
                        Result := 0.044139070616870522;
                    end;
                end;
            end;
        end
        else
        begin
            if features.challenger_complete_pool_consensus_support_min <= 95.500000000000014 then
            begin
                Result := 0.031933825852039341;
            end
            else
            begin
                Result := 0.00024186604450860885;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_85(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 60807250.000000007 then
    begin
        if features.delta_top_legacy_rank <= 7.5000000000000009 then
        begin
            Result := -0.01203777290607146;
        end
        else
        begin
            if features.delta_second_chain_score_gap <= 31968311.000000004 then
            begin
                Result := 0.022843707305681794;
            end
            else
            begin
                Result := -0.0072583378409304634;
            end;
        end;
    end
    else
    begin
        if features.second_top_ranker_score_gap <= -107380067.99999999 then
        begin
            if features.delta_second_word_lm_bonus <= -6.4999999999999991 then
            begin
                if features.delta_second_char_lm_suffix_score <= 411.00000000000006 then
                begin
                    Result := -0.024602306410817797;
                end
                else
                begin
                    Result := -0.00033943903543825707;
                end;
            end
            else
            begin
                if features.delta_second_candidate_score <= -11418.499999999998 then
                begin
                    if features.challenger_complete_pool_consensus_support_min <= 219.50000000000003 then
                    begin
                        if features.second_ranker_score <= -53865577.999999993 then
                        begin
                            if features.challenger_char_lm_score <= -6624.4999999999991 then
                            begin
                                Result := -0.0045760770344007926;
                            end
                            else
                            begin
                                if features.delta_second_complete_pool_consensus_support_min <= -368.99999999999994 then
                                begin
                                    Result := 0.0003243061990983969;
                                end
                                else
                                begin
                                    Result := 0.039924868091396663;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.00050059625880202112;
                        end;
                    end
                    else
                    begin
                        if features.challenger_complete_pool_pair_evidence <= 1.0000000180025095E-35 then
                        begin
                            Result := -0.025409522701546203;
                        end
                        else
                        begin
                            Result := 0.0094796991988742897;
                        end;
                    end;
                end
                else
                begin
                    if features.challenger_char_lm_suffix_score <= -4949.4999999999991 then
                    begin
                        if features.challenger_char_lm_score <= -4311.9999999999991 then
                        begin
                            Result := 0.0;
                        end
                        else
                        begin
                            Result := -0.022251385902517594;
                        end;
                    end
                    else
                    begin
                        Result := 0.024683461874650103;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.020472382460930489;
        end;
    end;
end;

function second_slot_recovery_gate_tree_86(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= 3.5000000000000004 then
    begin
        if features.delta_top_char_lm_score <= 4.5000000000000009 then
        begin
            if features.delta_second_word_lm_boundary_first <= 66.000000000000014 then
            begin
                if features.delta_top_path_segments <= -1.0000000180025095E-35 then
                begin
                    if features.top_ranker_score <= 156463408.00000003 then
                    begin
                        Result := 0.014235892300302746;
                    end
                    else
                    begin
                        Result := -0.011309960453177422;
                    end;
                end
                else
                begin
                    Result := -0.015135165931827873;
                end;
            end
            else
            begin
                Result := 0.015124559634943328;
            end;
        end
        else
        begin
            if features.delta_top_char_lm_suffix_score <= 330.50000000000006 then
            begin
                if features.delta_second_path_single_segments <= -2.4999999999999996 then
                begin
                    Result := -0.01686835153985362;
                end
                else
                begin
                    if features.challenger_legacy_rank <= 2.5000000000000004 then
                    begin
                        Result := 0.00070571957006528919;
                    end
                    else
                    begin
                        if features.delta_top_complete_pool_consensus_nearest_distance <= 6.5000000000000009 then
                        begin
                            Result := 0.03723411282630236;
                        end
                        else
                        begin
                            Result := 0.0074477016757609066;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_anchor_replacement_weight <= -229.49999999999997 then
                begin
                    Result := 0.010458030736323674;
                end
                else
                begin
                    if features.delta_second_complete_pool_original <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.0050563545303989373;
                    end
                    else
                    begin
                        Result := -0.028354525357167433;
                    end;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_second_path_single_segments <= 2.5000000000000004 then
        begin
            if features.delta_second_word_lm_boundary_max <= 1309.5000000000002 then
            begin
                if features.delta_second_word_lm_bonus <= -156.49999999999997 then
                begin
                    Result := -0.0086425103031006634;
                end
                else
                begin
                    Result := 0.021854158614548109;
                end;
            end
            else
            begin
                Result := -0.010561657750685786;
            end;
        end
        else
        begin
            Result := -0.008119423385528346;
        end;
    end;
end;

function second_slot_recovery_gate_tree_87(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_seed_rank <= -1.0000000180025095E-35 then
    begin
        Result := -0.0174974384182306;
    end
    else
    begin
        if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
        begin
            if features.delta_second_complete_pool_consensus_mean_distance <= 22937.500000000004 then
            begin
                if features.delta_top_chain_first_stage_score <= -133162.49999999997 then
                begin
                    Result := -0.02204562536191319;
                end
                else
                begin
                    if features.delta_second_path_max_segment_units <= -4.4999999999999991 then
                    begin
                        if features.delta_second_complete_pool_consensus_support <= -16.499999999999996 then
                        begin
                            Result := 0.028298113966268947;
                        end
                        else
                        begin
                            Result := -0.0051595690193957187;
                        end;
                    end
                    else
                    begin
                        if features.second_top_ranker_score_gap <= -79523487.999999985 then
                        begin
                            if features.delta_top_chain_second_stage_score <= 23717380.000000004 then
                            begin
                                if features.challenger_char_lm_suffix_score <= -4787.4999999999991 then
                                begin
                                    Result := -0.010151154325329845;
                                end
                                else
                                begin
                                    Result := 0.015686324824110351;
                                end;
                            end
                            else
                            begin
                                Result := 0.019488006264428502;
                            end;
                        end
                        else
                        begin
                            if features.delta_top_char_lm_suffix_score <= 25.500000000000004 then
                            begin
                                Result := -0.0021755614440996962;
                            end
                            else
                            begin
                                Result := 0.030204110048409741;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_anchor_source_weight <= 399.50000000000006 then
                begin
                    Result := 0.026852452346652397;
                end
                else
                begin
                    if features.delta_second_score_per_unit <= 62.500000000000007 then
                    begin
                        if features.challenger_word_lm_boundary_max <= 1294.5000000000002 then
                        begin
                            Result := -0.019722671558807508;
                        end
                        else
                        begin
                            Result := 0.0071273534730275576;
                        end;
                    end
                    else
                    begin
                        Result := 0.021134332495454339;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_complete_pool_consensus_support_min <= -666.49999999999989 then
            begin
                Result := 0.031159338670005091;
            end
            else
            begin
                Result := 0.0033013997053023057;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_88(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= -11.499999999999998 then
    begin
        Result := -0.021787025290963422;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 269634064.00000006 then
        begin
            if features.delta_top_chain_second_stage_score <= 130331164.00000001 then
            begin
                if features.challenger_rank <= 3.5000000000000004 then
                begin
                    Result := -0.0075695380941942338;
                end
                else
                begin
                    if features.delta_second_path_single_segments <= 1.5000000000000002 then
                    begin
                        if features.delta_second_word_lm_boundary_max <= 1344.5000000000002 then
                        begin
                            if features.delta_top_dict_weight_per_unit <= -1411.9999999999998 then
                            begin
                                if features.delta_top_dict_weight_per_unit <= -5238.4999999999991 then
                                begin
                                    if features.delta_second_dict_weight_per_unit <= -10169.999999999998 then
                                    begin
                                        Result := -0.00255027739869152;
                                    end
                                    else
                                    begin
                                        if features.delta_second_char_lm_score <= -144.99999999999997 then
                                        begin
                                            Result := -0.01067243056560265;
                                        end
                                        else
                                        begin
                                            if features.delta_top_char_lm_score <= 185.00000000000003 then
                                            begin
                                                Result := 0.0338423344412375;
                                            end
                                            else
                                            begin
                                                Result := 0.0024205961787135901;
                                            end;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.014211107876849012;
                                end;
                            end
                            else
                            begin
                                Result := 0.024686009474508355;
                            end;
                        end
                        else
                        begin
                            Result := -0.013520058541510767;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_bonus <= 124.00000000000001 then
                        begin
                            Result := -0.013643764634045831;
                        end
                        else
                        begin
                            if features.top_ranker_score <= 267436184.00000003 then
                            begin
                                Result := 0.027708593620290271;
                            end
                            else
                            begin
                                Result := -0.013351036773551192;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.01937879671486167;
            end;
        end
        else
        begin
            if features.delta_second_complete_pool_consensus_support <= 100.50000000000001 then
            begin
                Result := 0.033164507509812521;
            end
            else
            begin
                Result := -0.016667676738351192;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_89(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= -11.499999999999998 then
    begin
        Result := -0.019590144936681153;
    end
    else
    begin
        if features.delta_top_char_lm_score <= -105.49999999999999 then
        begin
            if features.delta_second_word_lm_bonus <= 4.5000000000000009 then
            begin
                Result := -0.010494105420402874;
            end
            else
            begin
                if features.delta_top_word_lm_boundary_count <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_word_lm_boundary_max <= 148.50000000000003 then
                    begin
                        if features.challenger_chain_score_gap <= -19565200.999999996 then
                        begin
                            Result := -0.0059067109949914572;
                        end
                        else
                        begin
                            Result := 0.034007193046683599;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_source_rule_fallback <= 1.0000000180025095E-35 then
                        begin
                            if features.second_top_ranker_score_gap <= -191713159.99999997 then
                            begin
                                Result := 0.037665190153045064;
                            end
                            else
                            begin
                                Result := -0.0085335217575413652;
                            end;
                        end
                        else
                        begin
                            Result := -0.01741612764092499;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.014449795111682819;
                end;
            end;
        end
        else
        begin
            if features.challenger_char_lm_suffix_score <= -4759.4999999999991 then
            begin
                if features.challenger_ranker_score_gap <= 56442360.000000007 then
                begin
                    Result := -0.0060729715831366483;
                end
                else
                begin
                    if features.delta_second_candidate_score <= -9397.9999999999982 then
                    begin
                        if features.challenger_chain_score_gap <= -21591139.999999996 then
                        begin
                            Result := -0.001850121143930329;
                        end
                        else
                        begin
                            Result := 0.02432580908521351;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_candidate_score <= 10377.500000000002 then
                        begin
                            if features.challenger_char_lm_suffix_score <= -6496.4999999999991 then
                            begin
                                Result := 0.0087419994120028436;
                            end
                            else
                            begin
                                Result := -0.015417354249968266;
                            end;
                        end
                        else
                        begin
                            Result := 0.025335552724650528;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.026928052951824887;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_90(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.challenger_ranker_score_gap <= 89379856.000000015 then
    begin
        if features.delta_top_complete_pool_seed_rank <= -1.0000000180025095E-35 then
        begin
            Result := -0.02596165401367739;
        end
        else
        begin
            if features.delta_top_score_per_unit <= 1162.5000000000002 then
            begin
                if features.delta_second_path_single_segments <= 1.5000000000000002 then
                begin
                    if features.delta_second_legacy_rank <= 6.5000000000000009 then
                    begin
                        if features.challenger_complete_pool_consensus_mean_distance <= 14690.500000000002 then
                        begin
                            Result := 0.0014359813725361432;
                        end
                        else
                        begin
                            Result := -0.01977416120759299;
                        end;
                    end
                    else
                    begin
                        Result := 0.015794082656119472;
                    end;
                end
                else
                begin
                    Result := -0.014896412177117043;
                end;
            end
            else
            begin
                Result := 0.011624566424783756;
            end;
        end;
    end
    else
    begin
        if features.delta_second_legacy_rank <= -11.499999999999998 then
        begin
            Result := -0.023034926210441207;
        end
        else
        begin
            if features.delta_top_chain_second_stage_score <= -9183875.9999999981 then
            begin
                if features.delta_second_complete_pool_seed_rank <= 1.5000000000000002 then
                begin
                    Result := -0.0068781287248896672;
                end
                else
                begin
                    Result := 0.021295926605379396;
                end;
            end
            else
            begin
                if features.delta_second_path_single_segments <= 4.5000000000000009 then
                begin
                    if features.delta_top_word_lm_boundary_max <= 1507.5000000000002 then
                    begin
                        if features.delta_second_word_lm_boundary_count <= -2.4999999999999996 then
                        begin
                            Result := -0.0085264868714793312;
                        end
                        else
                        begin
                            if features.same_prefix_units <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.0034839603886503497;
                            end
                            else
                            begin
                                if features.challenger_complete_pool_consensus_mean_distance <= 3562.5000000000005 then
                                begin
                                    Result := 0.0076441716400325131;
                                end
                                else
                                begin
                                    Result := 0.033663199996180775;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.013677187829238572;
                    end;
                end
                else
                begin
                    Result := -0.010267011782517935;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_91(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= -11.499999999999998 then
    begin
        Result := -0.018935197946178275;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 71505292.000000015 then
        begin
            if features.delta_second_path_single_segments <= 1.5000000000000002 then
            begin
                if features.delta_top_complete_pool_consensus_support <= -153.49999999999997 then
                begin
                    Result := -0.01348381152737874;
                end
                else
                begin
                    if features.second_top_ranker_score_gap <= -222150927.99999997 then
                    begin
                        Result := 0.030594313684153007;
                    end
                    else
                    begin
                        if features.delta_top_char_lm_score <= -182.49999999999997 then
                        begin
                            Result := -0.014586313639625263;
                        end
                        else
                        begin
                            if features.second_top_ranker_score_gap <= -86363303.999999985 then
                            begin
                                Result := -0.0028887967187111591;
                            end
                            else
                            begin
                                Result := 0.029503020668786462;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_second_complete_pool_consensus_support_min <= -309.99999999999994 then
                begin
                    Result := 0.0082716075945873536;
                end
                else
                begin
                    Result := -0.023155715603647219;
                end;
            end;
        end
        else
        begin
            if features.second_top_ranker_score_gap <= -127469123.99999999 then
            begin
                if features.delta_second_word_lm_bonus <= -98.999999999999986 then
                begin
                    Result := -0.014641671954165283;
                end
                else
                begin
                    if features.delta_top_chain_first_stage_score <= -175334.49999999997 then
                    begin
                        Result := -0.018642910885375494;
                    end
                    else
                    begin
                        if features.challenger_char_lm_suffix_score <= -5257.4999999999991 then
                        begin
                            if features.delta_top_dict_weight <= -98147.999999999985 then
                            begin
                                Result := 0.013198893430489318;
                            end
                            else
                            begin
                                Result := -0.0040834624203598593;
                            end;
                        end
                        else
                        begin
                            Result := 0.019815704256722824;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_signature_support <= 6.5000000000000009 then
                begin
                    Result := 0.034726804445525637;
                end
                else
                begin
                    Result := 0.0045435295753899606;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_92(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_legacy_rank <= -11.499999999999998 then
    begin
        Result := -0.018305024841354638;
    end
    else
    begin
        if features.challenger_ranker_score_gap <= 92833636.000000015 then
        begin
            if features.delta_top_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.0071944376798993778;
            end
            else
            begin
                if features.challenger_char_lm_suffix_score <= -6496.4999999999991 then
                begin
                    Result := 0.026997821821671836;
                end
                else
                begin
                    if features.challenger_ranker_score <= 131287268.00000001 then
                    begin
                        Result := -0.012851111707877555;
                    end
                    else
                    begin
                        Result := 0.010062023608043367;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_top_chain_first_stage_score <= -175334.49999999997 then
            begin
                Result := -0.016734146188371071;
            end
            else
            begin
                if features.delta_second_word_lm_strong_ratio <= 51.500000000000007 then
                begin
                    if features.challenger_word_lm_zero_count <= 3.5000000000000004 then
                    begin
                        if features.challenger_complete_pool_signature_support <= 3.5000000000000004 then
                        begin
                            Result := 0.0038507080253582407;
                        end
                        else
                        begin
                            Result := -0.018088673508443169;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_path_segments <= 2.5000000000000004 then
                        begin
                            if features.delta_top_word_lm_strong_ratio <= -56.499999999999993 then
                            begin
                                Result := -0.0011224968058372322;
                            end
                            else
                            begin
                                Result := 0.028067993989562511;
                            end;
                        end
                        else
                        begin
                            Result := -0.0075904797965065359;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_candidate_score <= -144.99999999999997 then
                    begin
                        if features.delta_top_word_lm_boundary_max <= 1438.5000000000002 then
                        begin
                            Result := 0.031201341443283022;
                        end
                        else
                        begin
                            Result := -0.00064943667110900808;
                        end;
                    end
                    else
                    begin
                        if features.challenger_candidate_score <= 50360.000000000007 then
                        begin
                            Result := -0.016447577168876411;
                        end
                        else
                        begin
                            Result := 0.014376204828000547;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_93(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_seed_rank <= 2.5000000000000004 then
    begin
        if features.delta_second_path_segments <= 4.5000000000000009 then
        begin
            if features.delta_second_path_single_segments <= 4.5000000000000009 then
            begin
                if features.challenger_char_lm_suffix_score <= -4787.4999999999991 then
                begin
                    if features.delta_second_word_lm_zero_count <= -1.4999999999999998 then
                    begin
                        if features.delta_top_complete_pool_pair_evidence <= 1167.0000000000002 then
                        begin
                            Result := -0.01837792026792652;
                        end
                        else
                        begin
                            Result := 0.0035987652746310795;
                        end;
                    end
                    else
                    begin
                        if features.delta_second_word_lm_bonus <= 25.500000000000004 then
                        begin
                            if features.second_top_ranker_score_gap <= -72524679.999999985 then
                            begin
                                if features.delta_second_score_per_unit <= -14854.999999999998 then
                                begin
                                    if features.challenger_chain_score_gap <= -35859709.999999993 then
                                    begin
                                        Result := -0.0074066629058789557;
                                    end
                                    else
                                    begin
                                        Result := 0.025632632272816185;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.011621886882688883;
                                end;
                            end
                            else
                            begin
                                Result := 0.015532446659851358;
                            end;
                        end
                        else
                        begin
                            if features.delta_top_complete_pool_consensus_support <= -36.499999999999993 then
                            begin
                                if features.challenger_char_lm_score <= -4311.9999999999991 then
                                begin
                                    Result := 0.028088834281400733;
                                end
                                else
                                begin
                                    Result := -0.0052173680587011559;
                                end;
                            end
                            else
                            begin
                                Result := -0.0095010369940872665;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_second_score_per_unit <= -3628.4999999999995 then
                    begin
                        Result := -0.0067372036755350851;
                    end
                    else
                    begin
                        Result := 0.030424605933621823;
                    end;
                end;
            end
            else
            begin
                Result := -0.026406167489391705;
            end;
        end
        else
        begin
            Result := 0.01494124039711898;
        end;
    end
    else
    begin
        if features.delta_top_char_lm_score <= -291.49999999999994 then
        begin
            Result := -0.0059410998032168776;
        end
        else
        begin
            Result := 0.015334617411852904;
        end;
    end;
end;

function second_slot_recovery_gate_tree_94(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
    begin
        if features.challenger_complete_pool_consensus_mean_distance <= 3775.0000000000005 then
        begin
            Result := -0.011098206900698694;
        end
        else
        begin
            if features.challenger_char_lm_suffix_score <= -4787.4999999999991 then
            begin
                if features.delta_top_complete_pool_consensus_support_min <= 1.0000000180025095E-35 then
                begin
                    if features.delta_second_complete_pool_consensus_support_min <= -318.49999999999994 then
                    begin
                        if features.delta_top_dict_weight <= -81887.999999999985 then
                        begin
                            if features.challenger_complete_pool_anchor_start <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.040679641996316643;
                            end
                            else
                            begin
                                Result := -0.008044216981740536;
                            end;
                        end
                        else
                        begin
                            if features.delta_second_complete_pool_pair_evidence <= 1204.5000000000002 then
                            begin
                                if features.challenger_complete_pool_consensus_mean_distance <= 22062.500000000004 then
                                begin
                                    Result := -0.021484223204075493;
                                end
                                else
                                begin
                                    Result := 0.0045634879795864759;
                                end;
                            end
                            else
                            begin
                                Result := 0.017277421645353695;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_top_chain_second_stage_score <= 130331164.00000001 then
                        begin
                            if features.difference_span_units <= 7.5000000000000009 then
                            begin
                                Result := -0.0092411515683669208;
                            end
                            else
                            begin
                                Result := 0.011578951518141051;
                            end;
                        end
                        else
                        begin
                            Result := 0.016171269687534219;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.0224924475291188;
                end;
            end
            else
            begin
                if features.delta_second_path_segments <= 1.5000000000000002 then
                begin
                    Result := 0.046015374618671723;
                end
                else
                begin
                    Result := -0.0059069472734047182;
                end;
            end;
        end;
    end
    else
    begin
        if features.delta_top_complete_pool_consensus_support_min <= -666.49999999999989 then
        begin
            Result := 0.029590672322540448;
        end
        else
        begin
            if features.delta_top_char_lm_suffix_score <= 63.500000000000007 then
            begin
                Result := 0.0131799886931465;
            end
            else
            begin
                Result := -0.012678263652329087;
            end;
        end;
    end;
end;

function second_slot_recovery_gate_tree_95(
    const features: TncLongSecondSlotRecoveryGateFeatures): Double;
begin
    if features.delta_top_complete_pool_seed_rank <= -1.0000000180025095E-35 then
    begin
        Result := -0.018588937975111627;
    end
    else
    begin
        if features.second_top_ranker_score_gap <= -86363303.999999985 then
        begin
            if features.delta_second_path_max_segment_units <= 1.0000000180025095E-35 then
            begin
                if features.delta_second_complete_pool_consensus_nearest_distance <= 2.5000000000000004 then
                begin
                    if features.delta_second_word_lm_supported_ratio <= 301.00000000000006 then
                    begin
                        if features.challenger_score_per_unit <= 19803.000000000004 then
                        begin
                            Result := -0.01455214250186212;
                        end
                        else
                        begin
                            Result := 0.015097343302317176;
                        end;
                    end
                    else
                    begin
                        Result := 0.014131752650111988;
                    end;
                end
                else
                begin
                    if features.delta_second_chain_first_stage_score <= 63296.000000000007 then
                    begin
                        if features.delta_top_dict_weight_per_unit <= -17311.999999999996 then
                        begin
                            if features.delta_second_complete_pool_consensus_support_min <= -273.49999999999994 then
                            begin
                                Result := 0.035761575460433785;
                            end
                            else
                            begin
                                Result := -0.0049012012002009695;
                            end;
                        end
                        else
                        begin
                            if features.challenger_complete_pool_consensus_unanimous_units <= 7.5000000000000009 then
                            begin
                                if features.same_suffix_units <= 1.5000000000000002 then
                                begin
                                    Result := 0.0037451746870056269;
                                end
                                else
                                begin
                                    Result := -0.012740620472359831;
                                end;
                            end
                            else
                            begin
                                Result := 0.015234006650093586;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.027216488663079217;
                    end;
                end;
            end
            else
            begin
                if features.challenger_complete_pool_consensus_support_min <= 95.500000000000014 then
                begin
                    Result := 0.026693354680419532;
                end
                else
                begin
                    Result := -0.00030382149886632354;
                end;
            end;
        end
        else
        begin
            if features.challenger_ranker_score_gap <= 42379616.000000007 then
            begin
                Result := -0.0015899244217276837;
            end
            else
            begin
                if features.challenger_complete_pool_consensus_support_min <= 280.50000000000006 then
                begin
                    Result := 0.043880969001944235;
                end
                else
                begin
                    Result := 0.0021945388890396286;
                end;
            end;
        end;
    end;
end;
function long_second_slot_recovery_gate_score(
    const features: TncLongSecondSlotRecoveryGateFeatures): Int64;
var
    score: Double;
begin
    score := 0.0;
    score := score + second_slot_recovery_gate_tree_0(features);
    score := score + second_slot_recovery_gate_tree_1(features);
    score := score + second_slot_recovery_gate_tree_2(features);
    score := score + second_slot_recovery_gate_tree_3(features);
    score := score + second_slot_recovery_gate_tree_4(features);
    score := score + second_slot_recovery_gate_tree_5(features);
    score := score + second_slot_recovery_gate_tree_6(features);
    score := score + second_slot_recovery_gate_tree_7(features);
    score := score + second_slot_recovery_gate_tree_8(features);
    score := score + second_slot_recovery_gate_tree_9(features);
    score := score + second_slot_recovery_gate_tree_10(features);
    score := score + second_slot_recovery_gate_tree_11(features);
    score := score + second_slot_recovery_gate_tree_12(features);
    score := score + second_slot_recovery_gate_tree_13(features);
    score := score + second_slot_recovery_gate_tree_14(features);
    score := score + second_slot_recovery_gate_tree_15(features);
    score := score + second_slot_recovery_gate_tree_16(features);
    score := score + second_slot_recovery_gate_tree_17(features);
    score := score + second_slot_recovery_gate_tree_18(features);
    score := score + second_slot_recovery_gate_tree_19(features);
    score := score + second_slot_recovery_gate_tree_20(features);
    score := score + second_slot_recovery_gate_tree_21(features);
    score := score + second_slot_recovery_gate_tree_22(features);
    score := score + second_slot_recovery_gate_tree_23(features);
    score := score + second_slot_recovery_gate_tree_24(features);
    score := score + second_slot_recovery_gate_tree_25(features);
    score := score + second_slot_recovery_gate_tree_26(features);
    score := score + second_slot_recovery_gate_tree_27(features);
    score := score + second_slot_recovery_gate_tree_28(features);
    score := score + second_slot_recovery_gate_tree_29(features);
    score := score + second_slot_recovery_gate_tree_30(features);
    score := score + second_slot_recovery_gate_tree_31(features);
    score := score + second_slot_recovery_gate_tree_32(features);
    score := score + second_slot_recovery_gate_tree_33(features);
    score := score + second_slot_recovery_gate_tree_34(features);
    score := score + second_slot_recovery_gate_tree_35(features);
    score := score + second_slot_recovery_gate_tree_36(features);
    score := score + second_slot_recovery_gate_tree_37(features);
    score := score + second_slot_recovery_gate_tree_38(features);
    score := score + second_slot_recovery_gate_tree_39(features);
    score := score + second_slot_recovery_gate_tree_40(features);
    score := score + second_slot_recovery_gate_tree_41(features);
    score := score + second_slot_recovery_gate_tree_42(features);
    score := score + second_slot_recovery_gate_tree_43(features);
    score := score + second_slot_recovery_gate_tree_44(features);
    score := score + second_slot_recovery_gate_tree_45(features);
    score := score + second_slot_recovery_gate_tree_46(features);
    score := score + second_slot_recovery_gate_tree_47(features);
    score := score + second_slot_recovery_gate_tree_48(features);
    score := score + second_slot_recovery_gate_tree_49(features);
    score := score + second_slot_recovery_gate_tree_50(features);
    score := score + second_slot_recovery_gate_tree_51(features);
    score := score + second_slot_recovery_gate_tree_52(features);
    score := score + second_slot_recovery_gate_tree_53(features);
    score := score + second_slot_recovery_gate_tree_54(features);
    score := score + second_slot_recovery_gate_tree_55(features);
    score := score + second_slot_recovery_gate_tree_56(features);
    score := score + second_slot_recovery_gate_tree_57(features);
    score := score + second_slot_recovery_gate_tree_58(features);
    score := score + second_slot_recovery_gate_tree_59(features);
    score := score + second_slot_recovery_gate_tree_60(features);
    score := score + second_slot_recovery_gate_tree_61(features);
    score := score + second_slot_recovery_gate_tree_62(features);
    score := score + second_slot_recovery_gate_tree_63(features);
    score := score + second_slot_recovery_gate_tree_64(features);
    score := score + second_slot_recovery_gate_tree_65(features);
    score := score + second_slot_recovery_gate_tree_66(features);
    score := score + second_slot_recovery_gate_tree_67(features);
    score := score + second_slot_recovery_gate_tree_68(features);
    score := score + second_slot_recovery_gate_tree_69(features);
    score := score + second_slot_recovery_gate_tree_70(features);
    score := score + second_slot_recovery_gate_tree_71(features);
    score := score + second_slot_recovery_gate_tree_72(features);
    score := score + second_slot_recovery_gate_tree_73(features);
    score := score + second_slot_recovery_gate_tree_74(features);
    score := score + second_slot_recovery_gate_tree_75(features);
    score := score + second_slot_recovery_gate_tree_76(features);
    score := score + second_slot_recovery_gate_tree_77(features);
    score := score + second_slot_recovery_gate_tree_78(features);
    score := score + second_slot_recovery_gate_tree_79(features);
    score := score + second_slot_recovery_gate_tree_80(features);
    score := score + second_slot_recovery_gate_tree_81(features);
    score := score + second_slot_recovery_gate_tree_82(features);
    score := score + second_slot_recovery_gate_tree_83(features);
    score := score + second_slot_recovery_gate_tree_84(features);
    score := score + second_slot_recovery_gate_tree_85(features);
    score := score + second_slot_recovery_gate_tree_86(features);
    score := score + second_slot_recovery_gate_tree_87(features);
    score := score + second_slot_recovery_gate_tree_88(features);
    score := score + second_slot_recovery_gate_tree_89(features);
    score := score + second_slot_recovery_gate_tree_90(features);
    score := score + second_slot_recovery_gate_tree_91(features);
    score := score + second_slot_recovery_gate_tree_92(features);
    score := score + second_slot_recovery_gate_tree_93(features);
    score := score + second_slot_recovery_gate_tree_94(features);
    score := score + second_slot_recovery_gate_tree_95(features);
    Result := Trunc(score * c_long_second_slot_recovery_gate_score_scale);
end;

function long_second_slot_recovery_gate_self_test: Boolean;
var
    features: TncLongSecondSlotRecoveryGateFeatures;
begin
    FillChar(features, SizeOf(features), 0);
    if long_second_slot_recovery_gate_score(features) <>
        c_long_second_slot_recovery_gate_reference_score then Exit(False);
    features.challenger_candidate_score := -1000000;
    features.challenger_dict_weight := -1000000;
    features.challenger_has_dict_weight := -1000000;
    features.challenger_source_user := -1000000;
    features.challenger_source_chain := -1000000;
    features.challenger_source_pattern := -1000000;
    features.challenger_source_redup := -1000000;
    features.challenger_source_local_rerank := -1000000;
    features.challenger_source_rule_fallback := -1000000;
    features.challenger_legacy_rank := -1000000;
    features.challenger_legacy_top := -1000000;
    features.challenger_chain_rank := -1000000;
    features.challenger_chain_present := -1000000;
    features.challenger_chain_first_stage_score := -1000000;
    features.challenger_chain_second_stage_score := -1000000;
    features.challenger_chain_score_gap := -1000000;
    features.challenger_complete_match := -1000000;
    features.challenger_partial_match := -1000000;
    features.challenger_text_units := -1000000;
    features.challenger_comment_length := -1000000;
    features.challenger_unit_delta := -1000000;
    features.challenger_path_available := -1000000;
    features.challenger_path_confidence_score := -1000000;
    features.challenger_path_confidence_tier := -1000000;
    features.challenger_path_segments := -1000000;
    features.challenger_path_single_segments := -1000000;
    features.challenger_path_max_segment_units := -1000000;
    features.challenger_char_lm_score := -1000000;
    features.challenger_char_lm_suffix_score := -1000000;
    features.challenger_char_lm_context_score := -1000000;
    features.challenger_char_lm_context_gain := -1000000;
    features.challenger_has_left_context := -1000000;
    features.challenger_query_choice_bonus := -1000000;
    features.challenger_latest_query_choice := -1000000;
    features.challenger_query_path_bonus := -1000000;
    features.challenger_query_path_penalty := -1000000;
    features.challenger_word_lm_bonus := -1000000;
    features.challenger_word_lm_boundary_count := -1000000;
    features.challenger_word_lm_boundary_min := -1000000;
    features.challenger_word_lm_boundary_max := -1000000;
    features.challenger_word_lm_boundary_first := -1000000;
    features.challenger_word_lm_boundary_last := -1000000;
    features.challenger_word_lm_supported_ratio := -1000000;
    features.challenger_word_lm_strong_ratio := -1000000;
    features.challenger_word_lm_trigram_ratio := -1000000;
    features.challenger_word_lm_zero_count := -1000000;
    features.challenger_input_syllable_count := -1000000;
    features.challenger_score_per_unit := -1000000;
    features.challenger_dict_weight_per_unit := -1000000;
    features.challenger_complete_user := -1000000;
    features.challenger_complete_dictionary := -1000000;
    features.challenger_complete_chain := -1000000;
    features.challenger_complete_pool_present := -1000000;
    features.challenger_complete_pool_source_kind := -1000000;
    features.challenger_complete_pool_rank := -1000000;
    features.challenger_complete_pool_seed_rank := -1000000;
    features.challenger_complete_pool_original := -1000000;
    features.challenger_complete_pool_substitutions := -1000000;
    features.challenger_complete_pool_changed_position := -1000000;
    features.challenger_complete_pool_anchor_present := -1000000;
    features.challenger_complete_pool_anchor_start := -1000000;
    features.challenger_complete_pool_anchor_units := -1000000;
    features.challenger_complete_pool_anchor_exact_rank := -1000000;
    features.challenger_complete_pool_anchor_source_weight := -1000000;
    features.challenger_complete_pool_anchor_replacement_weight := -1000000;
    features.challenger_complete_pool_anchor_top_weight := -1000000;
    features.challenger_complete_pool_anchor_weight_gain := -1000000;
    features.challenger_complete_pool_pair_evidence := -1000000;
    features.challenger_complete_pool_proper_name_confidence := -1000000;
    features.challenger_complete_pool_signature_support := -1000000;
    features.challenger_complete_pool_consensus_support := -1000000;
    features.challenger_complete_pool_consensus_seed_count := -1000000;
    features.challenger_complete_pool_consensus_support_mean := -1000000;
    features.challenger_complete_pool_consensus_support_min := -1000000;
    features.challenger_complete_pool_consensus_majority_units := -1000000;
    features.challenger_complete_pool_consensus_unanimous_units := -1000000;
    features.challenger_complete_pool_consensus_nearest_distance := -1000000;
    features.challenger_complete_pool_consensus_mean_distance := -1000000;
    features.challenger_complete_pool_consensus_changed_support := -1000000;
    features.challenger_complete_pool_consensus_changed_top_match := -1000000;
    features.challenger_complete_pool_local_pairwise_score := -1000000;
    features.delta_second_candidate_score := -1000000;
    features.delta_second_dict_weight := -1000000;
    features.delta_second_has_dict_weight := -1000000;
    features.delta_second_source_user := -1000000;
    features.delta_second_source_chain := -1000000;
    features.delta_second_source_pattern := -1000000;
    features.delta_second_source_redup := -1000000;
    features.delta_second_source_local_rerank := -1000000;
    features.delta_second_source_rule_fallback := -1000000;
    features.delta_second_legacy_rank := -1000000;
    features.delta_second_legacy_top := -1000000;
    features.delta_second_chain_rank := -1000000;
    features.delta_second_chain_present := -1000000;
    features.delta_second_chain_first_stage_score := -1000000;
    features.delta_second_chain_second_stage_score := -1000000;
    features.delta_second_chain_score_gap := -1000000;
    features.delta_second_complete_match := -1000000;
    features.delta_second_partial_match := -1000000;
    features.delta_second_text_units := -1000000;
    features.delta_second_comment_length := -1000000;
    features.delta_second_unit_delta := -1000000;
    features.delta_second_path_available := -1000000;
    features.delta_second_path_confidence_score := -1000000;
    features.delta_second_path_confidence_tier := -1000000;
    features.delta_second_path_segments := -1000000;
    features.delta_second_path_single_segments := -1000000;
    features.delta_second_path_max_segment_units := -1000000;
    features.delta_second_char_lm_score := -1000000;
    features.delta_second_char_lm_suffix_score := -1000000;
    features.delta_second_char_lm_context_score := -1000000;
    features.delta_second_char_lm_context_gain := -1000000;
    features.delta_second_has_left_context := -1000000;
    features.delta_second_query_choice_bonus := -1000000;
    features.delta_second_latest_query_choice := -1000000;
    features.delta_second_query_path_bonus := -1000000;
    features.delta_second_query_path_penalty := -1000000;
    features.delta_second_word_lm_bonus := -1000000;
    features.delta_second_word_lm_boundary_count := -1000000;
    features.delta_second_word_lm_boundary_min := -1000000;
    features.delta_second_word_lm_boundary_max := -1000000;
    features.delta_second_word_lm_boundary_first := -1000000;
    features.delta_second_word_lm_boundary_last := -1000000;
    features.delta_second_word_lm_supported_ratio := -1000000;
    features.delta_second_word_lm_strong_ratio := -1000000;
    features.delta_second_word_lm_trigram_ratio := -1000000;
    features.delta_second_word_lm_zero_count := -1000000;
    features.delta_second_input_syllable_count := -1000000;
    features.delta_second_score_per_unit := -1000000;
    features.delta_second_dict_weight_per_unit := -1000000;
    features.delta_second_complete_user := -1000000;
    features.delta_second_complete_dictionary := -1000000;
    features.delta_second_complete_chain := -1000000;
    features.delta_second_complete_pool_present := -1000000;
    features.delta_second_complete_pool_source_kind := -1000000;
    features.delta_second_complete_pool_rank := -1000000;
    features.delta_second_complete_pool_seed_rank := -1000000;
    features.delta_second_complete_pool_original := -1000000;
    features.delta_second_complete_pool_substitutions := -1000000;
    features.delta_second_complete_pool_changed_position := -1000000;
    features.delta_second_complete_pool_anchor_present := -1000000;
    features.delta_second_complete_pool_anchor_start := -1000000;
    features.delta_second_complete_pool_anchor_units := -1000000;
    features.delta_second_complete_pool_anchor_exact_rank := -1000000;
    features.delta_second_complete_pool_anchor_source_weight := -1000000;
    features.delta_second_complete_pool_anchor_replacement_weight := -1000000;
    features.delta_second_complete_pool_anchor_top_weight := -1000000;
    features.delta_second_complete_pool_anchor_weight_gain := -1000000;
    features.delta_second_complete_pool_pair_evidence := -1000000;
    features.delta_second_complete_pool_proper_name_confidence := -1000000;
    features.delta_second_complete_pool_signature_support := -1000000;
    features.delta_second_complete_pool_consensus_support := -1000000;
    features.delta_second_complete_pool_consensus_seed_count := -1000000;
    features.delta_second_complete_pool_consensus_support_mean := -1000000;
    features.delta_second_complete_pool_consensus_support_min := -1000000;
    features.delta_second_complete_pool_consensus_majority_units := -1000000;
    features.delta_second_complete_pool_consensus_unanimous_units := -1000000;
    features.delta_second_complete_pool_consensus_nearest_distance := -1000000;
    features.delta_second_complete_pool_consensus_mean_distance := -1000000;
    features.delta_second_complete_pool_consensus_changed_support := -1000000;
    features.delta_second_complete_pool_consensus_changed_top_match := -1000000;
    features.delta_second_complete_pool_local_pairwise_score := -1000000;
    features.delta_top_candidate_score := -1000000;
    features.delta_top_dict_weight := -1000000;
    features.delta_top_has_dict_weight := -1000000;
    features.delta_top_source_user := -1000000;
    features.delta_top_source_chain := -1000000;
    features.delta_top_source_pattern := -1000000;
    features.delta_top_source_redup := -1000000;
    features.delta_top_source_local_rerank := -1000000;
    features.delta_top_source_rule_fallback := -1000000;
    features.delta_top_legacy_rank := -1000000;
    features.delta_top_legacy_top := -1000000;
    features.delta_top_chain_rank := -1000000;
    features.delta_top_chain_present := -1000000;
    features.delta_top_chain_first_stage_score := -1000000;
    features.delta_top_chain_second_stage_score := -1000000;
    features.delta_top_chain_score_gap := -1000000;
    features.delta_top_complete_match := -1000000;
    features.delta_top_partial_match := -1000000;
    features.delta_top_text_units := -1000000;
    features.delta_top_comment_length := -1000000;
    features.delta_top_unit_delta := -1000000;
    features.delta_top_path_available := -1000000;
    features.delta_top_path_confidence_score := -1000000;
    features.delta_top_path_confidence_tier := -1000000;
    features.delta_top_path_segments := -1000000;
    features.delta_top_path_single_segments := -1000000;
    features.delta_top_path_max_segment_units := -1000000;
    features.delta_top_char_lm_score := -1000000;
    features.delta_top_char_lm_suffix_score := -1000000;
    features.delta_top_char_lm_context_score := -1000000;
    features.delta_top_char_lm_context_gain := -1000000;
    features.delta_top_has_left_context := -1000000;
    features.delta_top_query_choice_bonus := -1000000;
    features.delta_top_latest_query_choice := -1000000;
    features.delta_top_query_path_bonus := -1000000;
    features.delta_top_query_path_penalty := -1000000;
    features.delta_top_word_lm_bonus := -1000000;
    features.delta_top_word_lm_boundary_count := -1000000;
    features.delta_top_word_lm_boundary_min := -1000000;
    features.delta_top_word_lm_boundary_max := -1000000;
    features.delta_top_word_lm_boundary_first := -1000000;
    features.delta_top_word_lm_boundary_last := -1000000;
    features.delta_top_word_lm_supported_ratio := -1000000;
    features.delta_top_word_lm_strong_ratio := -1000000;
    features.delta_top_word_lm_trigram_ratio := -1000000;
    features.delta_top_word_lm_zero_count := -1000000;
    features.delta_top_input_syllable_count := -1000000;
    features.delta_top_score_per_unit := -1000000;
    features.delta_top_dict_weight_per_unit := -1000000;
    features.delta_top_complete_user := -1000000;
    features.delta_top_complete_dictionary := -1000000;
    features.delta_top_complete_chain := -1000000;
    features.delta_top_complete_pool_present := -1000000;
    features.delta_top_complete_pool_source_kind := -1000000;
    features.delta_top_complete_pool_rank := -1000000;
    features.delta_top_complete_pool_seed_rank := -1000000;
    features.delta_top_complete_pool_original := -1000000;
    features.delta_top_complete_pool_substitutions := -1000000;
    features.delta_top_complete_pool_changed_position := -1000000;
    features.delta_top_complete_pool_anchor_present := -1000000;
    features.delta_top_complete_pool_anchor_start := -1000000;
    features.delta_top_complete_pool_anchor_units := -1000000;
    features.delta_top_complete_pool_anchor_exact_rank := -1000000;
    features.delta_top_complete_pool_anchor_source_weight := -1000000;
    features.delta_top_complete_pool_anchor_replacement_weight := -1000000;
    features.delta_top_complete_pool_anchor_top_weight := -1000000;
    features.delta_top_complete_pool_anchor_weight_gain := -1000000;
    features.delta_top_complete_pool_pair_evidence := -1000000;
    features.delta_top_complete_pool_proper_name_confidence := -1000000;
    features.delta_top_complete_pool_signature_support := -1000000;
    features.delta_top_complete_pool_consensus_support := -1000000;
    features.delta_top_complete_pool_consensus_seed_count := -1000000;
    features.delta_top_complete_pool_consensus_support_mean := -1000000;
    features.delta_top_complete_pool_consensus_support_min := -1000000;
    features.delta_top_complete_pool_consensus_majority_units := -1000000;
    features.delta_top_complete_pool_consensus_unanimous_units := -1000000;
    features.delta_top_complete_pool_consensus_nearest_distance := -1000000;
    features.delta_top_complete_pool_consensus_mean_distance := -1000000;
    features.delta_top_complete_pool_consensus_changed_support := -1000000;
    features.delta_top_complete_pool_consensus_changed_top_match := -1000000;
    features.delta_top_complete_pool_local_pairwise_score := -1000000;
    features.challenger_rank := -1000000;
    features.challenger_ranker_score := -1000000;
    features.second_ranker_score := -1000000;
    features.top_ranker_score := -1000000;
    features.challenger_ranker_score_gap := -1000000;
    features.second_top_ranker_score_gap := -1000000;
    features.different_units := -1000000;
    features.different_runs := -1000000;
    features.max_different_run := -1000000;
    features.same_prefix_units := -1000000;
    features.same_suffix_units := -1000000;
    features.difference_span_units := -1000000;
    if long_second_slot_recovery_gate_score(features) <>
        c_long_second_slot_recovery_gate_reference_score_low then Exit(False);
    features.challenger_candidate_score := 1000000;
    features.challenger_dict_weight := 1000000;
    features.challenger_has_dict_weight := 1000000;
    features.challenger_source_user := 1000000;
    features.challenger_source_chain := 1000000;
    features.challenger_source_pattern := 1000000;
    features.challenger_source_redup := 1000000;
    features.challenger_source_local_rerank := 1000000;
    features.challenger_source_rule_fallback := 1000000;
    features.challenger_legacy_rank := 1000000;
    features.challenger_legacy_top := 1000000;
    features.challenger_chain_rank := 1000000;
    features.challenger_chain_present := 1000000;
    features.challenger_chain_first_stage_score := 1000000;
    features.challenger_chain_second_stage_score := 1000000;
    features.challenger_chain_score_gap := 1000000;
    features.challenger_complete_match := 1000000;
    features.challenger_partial_match := 1000000;
    features.challenger_text_units := 1000000;
    features.challenger_comment_length := 1000000;
    features.challenger_unit_delta := 1000000;
    features.challenger_path_available := 1000000;
    features.challenger_path_confidence_score := 1000000;
    features.challenger_path_confidence_tier := 1000000;
    features.challenger_path_segments := 1000000;
    features.challenger_path_single_segments := 1000000;
    features.challenger_path_max_segment_units := 1000000;
    features.challenger_char_lm_score := 1000000;
    features.challenger_char_lm_suffix_score := 1000000;
    features.challenger_char_lm_context_score := 1000000;
    features.challenger_char_lm_context_gain := 1000000;
    features.challenger_has_left_context := 1000000;
    features.challenger_query_choice_bonus := 1000000;
    features.challenger_latest_query_choice := 1000000;
    features.challenger_query_path_bonus := 1000000;
    features.challenger_query_path_penalty := 1000000;
    features.challenger_word_lm_bonus := 1000000;
    features.challenger_word_lm_boundary_count := 1000000;
    features.challenger_word_lm_boundary_min := 1000000;
    features.challenger_word_lm_boundary_max := 1000000;
    features.challenger_word_lm_boundary_first := 1000000;
    features.challenger_word_lm_boundary_last := 1000000;
    features.challenger_word_lm_supported_ratio := 1000000;
    features.challenger_word_lm_strong_ratio := 1000000;
    features.challenger_word_lm_trigram_ratio := 1000000;
    features.challenger_word_lm_zero_count := 1000000;
    features.challenger_input_syllable_count := 1000000;
    features.challenger_score_per_unit := 1000000;
    features.challenger_dict_weight_per_unit := 1000000;
    features.challenger_complete_user := 1000000;
    features.challenger_complete_dictionary := 1000000;
    features.challenger_complete_chain := 1000000;
    features.challenger_complete_pool_present := 1000000;
    features.challenger_complete_pool_source_kind := 1000000;
    features.challenger_complete_pool_rank := 1000000;
    features.challenger_complete_pool_seed_rank := 1000000;
    features.challenger_complete_pool_original := 1000000;
    features.challenger_complete_pool_substitutions := 1000000;
    features.challenger_complete_pool_changed_position := 1000000;
    features.challenger_complete_pool_anchor_present := 1000000;
    features.challenger_complete_pool_anchor_start := 1000000;
    features.challenger_complete_pool_anchor_units := 1000000;
    features.challenger_complete_pool_anchor_exact_rank := 1000000;
    features.challenger_complete_pool_anchor_source_weight := 1000000;
    features.challenger_complete_pool_anchor_replacement_weight := 1000000;
    features.challenger_complete_pool_anchor_top_weight := 1000000;
    features.challenger_complete_pool_anchor_weight_gain := 1000000;
    features.challenger_complete_pool_pair_evidence := 1000000;
    features.challenger_complete_pool_proper_name_confidence := 1000000;
    features.challenger_complete_pool_signature_support := 1000000;
    features.challenger_complete_pool_consensus_support := 1000000;
    features.challenger_complete_pool_consensus_seed_count := 1000000;
    features.challenger_complete_pool_consensus_support_mean := 1000000;
    features.challenger_complete_pool_consensus_support_min := 1000000;
    features.challenger_complete_pool_consensus_majority_units := 1000000;
    features.challenger_complete_pool_consensus_unanimous_units := 1000000;
    features.challenger_complete_pool_consensus_nearest_distance := 1000000;
    features.challenger_complete_pool_consensus_mean_distance := 1000000;
    features.challenger_complete_pool_consensus_changed_support := 1000000;
    features.challenger_complete_pool_consensus_changed_top_match := 1000000;
    features.challenger_complete_pool_local_pairwise_score := 1000000;
    features.delta_second_candidate_score := 1000000;
    features.delta_second_dict_weight := 1000000;
    features.delta_second_has_dict_weight := 1000000;
    features.delta_second_source_user := 1000000;
    features.delta_second_source_chain := 1000000;
    features.delta_second_source_pattern := 1000000;
    features.delta_second_source_redup := 1000000;
    features.delta_second_source_local_rerank := 1000000;
    features.delta_second_source_rule_fallback := 1000000;
    features.delta_second_legacy_rank := 1000000;
    features.delta_second_legacy_top := 1000000;
    features.delta_second_chain_rank := 1000000;
    features.delta_second_chain_present := 1000000;
    features.delta_second_chain_first_stage_score := 1000000;
    features.delta_second_chain_second_stage_score := 1000000;
    features.delta_second_chain_score_gap := 1000000;
    features.delta_second_complete_match := 1000000;
    features.delta_second_partial_match := 1000000;
    features.delta_second_text_units := 1000000;
    features.delta_second_comment_length := 1000000;
    features.delta_second_unit_delta := 1000000;
    features.delta_second_path_available := 1000000;
    features.delta_second_path_confidence_score := 1000000;
    features.delta_second_path_confidence_tier := 1000000;
    features.delta_second_path_segments := 1000000;
    features.delta_second_path_single_segments := 1000000;
    features.delta_second_path_max_segment_units := 1000000;
    features.delta_second_char_lm_score := 1000000;
    features.delta_second_char_lm_suffix_score := 1000000;
    features.delta_second_char_lm_context_score := 1000000;
    features.delta_second_char_lm_context_gain := 1000000;
    features.delta_second_has_left_context := 1000000;
    features.delta_second_query_choice_bonus := 1000000;
    features.delta_second_latest_query_choice := 1000000;
    features.delta_second_query_path_bonus := 1000000;
    features.delta_second_query_path_penalty := 1000000;
    features.delta_second_word_lm_bonus := 1000000;
    features.delta_second_word_lm_boundary_count := 1000000;
    features.delta_second_word_lm_boundary_min := 1000000;
    features.delta_second_word_lm_boundary_max := 1000000;
    features.delta_second_word_lm_boundary_first := 1000000;
    features.delta_second_word_lm_boundary_last := 1000000;
    features.delta_second_word_lm_supported_ratio := 1000000;
    features.delta_second_word_lm_strong_ratio := 1000000;
    features.delta_second_word_lm_trigram_ratio := 1000000;
    features.delta_second_word_lm_zero_count := 1000000;
    features.delta_second_input_syllable_count := 1000000;
    features.delta_second_score_per_unit := 1000000;
    features.delta_second_dict_weight_per_unit := 1000000;
    features.delta_second_complete_user := 1000000;
    features.delta_second_complete_dictionary := 1000000;
    features.delta_second_complete_chain := 1000000;
    features.delta_second_complete_pool_present := 1000000;
    features.delta_second_complete_pool_source_kind := 1000000;
    features.delta_second_complete_pool_rank := 1000000;
    features.delta_second_complete_pool_seed_rank := 1000000;
    features.delta_second_complete_pool_original := 1000000;
    features.delta_second_complete_pool_substitutions := 1000000;
    features.delta_second_complete_pool_changed_position := 1000000;
    features.delta_second_complete_pool_anchor_present := 1000000;
    features.delta_second_complete_pool_anchor_start := 1000000;
    features.delta_second_complete_pool_anchor_units := 1000000;
    features.delta_second_complete_pool_anchor_exact_rank := 1000000;
    features.delta_second_complete_pool_anchor_source_weight := 1000000;
    features.delta_second_complete_pool_anchor_replacement_weight := 1000000;
    features.delta_second_complete_pool_anchor_top_weight := 1000000;
    features.delta_second_complete_pool_anchor_weight_gain := 1000000;
    features.delta_second_complete_pool_pair_evidence := 1000000;
    features.delta_second_complete_pool_proper_name_confidence := 1000000;
    features.delta_second_complete_pool_signature_support := 1000000;
    features.delta_second_complete_pool_consensus_support := 1000000;
    features.delta_second_complete_pool_consensus_seed_count := 1000000;
    features.delta_second_complete_pool_consensus_support_mean := 1000000;
    features.delta_second_complete_pool_consensus_support_min := 1000000;
    features.delta_second_complete_pool_consensus_majority_units := 1000000;
    features.delta_second_complete_pool_consensus_unanimous_units := 1000000;
    features.delta_second_complete_pool_consensus_nearest_distance := 1000000;
    features.delta_second_complete_pool_consensus_mean_distance := 1000000;
    features.delta_second_complete_pool_consensus_changed_support := 1000000;
    features.delta_second_complete_pool_consensus_changed_top_match := 1000000;
    features.delta_second_complete_pool_local_pairwise_score := 1000000;
    features.delta_top_candidate_score := 1000000;
    features.delta_top_dict_weight := 1000000;
    features.delta_top_has_dict_weight := 1000000;
    features.delta_top_source_user := 1000000;
    features.delta_top_source_chain := 1000000;
    features.delta_top_source_pattern := 1000000;
    features.delta_top_source_redup := 1000000;
    features.delta_top_source_local_rerank := 1000000;
    features.delta_top_source_rule_fallback := 1000000;
    features.delta_top_legacy_rank := 1000000;
    features.delta_top_legacy_top := 1000000;
    features.delta_top_chain_rank := 1000000;
    features.delta_top_chain_present := 1000000;
    features.delta_top_chain_first_stage_score := 1000000;
    features.delta_top_chain_second_stage_score := 1000000;
    features.delta_top_chain_score_gap := 1000000;
    features.delta_top_complete_match := 1000000;
    features.delta_top_partial_match := 1000000;
    features.delta_top_text_units := 1000000;
    features.delta_top_comment_length := 1000000;
    features.delta_top_unit_delta := 1000000;
    features.delta_top_path_available := 1000000;
    features.delta_top_path_confidence_score := 1000000;
    features.delta_top_path_confidence_tier := 1000000;
    features.delta_top_path_segments := 1000000;
    features.delta_top_path_single_segments := 1000000;
    features.delta_top_path_max_segment_units := 1000000;
    features.delta_top_char_lm_score := 1000000;
    features.delta_top_char_lm_suffix_score := 1000000;
    features.delta_top_char_lm_context_score := 1000000;
    features.delta_top_char_lm_context_gain := 1000000;
    features.delta_top_has_left_context := 1000000;
    features.delta_top_query_choice_bonus := 1000000;
    features.delta_top_latest_query_choice := 1000000;
    features.delta_top_query_path_bonus := 1000000;
    features.delta_top_query_path_penalty := 1000000;
    features.delta_top_word_lm_bonus := 1000000;
    features.delta_top_word_lm_boundary_count := 1000000;
    features.delta_top_word_lm_boundary_min := 1000000;
    features.delta_top_word_lm_boundary_max := 1000000;
    features.delta_top_word_lm_boundary_first := 1000000;
    features.delta_top_word_lm_boundary_last := 1000000;
    features.delta_top_word_lm_supported_ratio := 1000000;
    features.delta_top_word_lm_strong_ratio := 1000000;
    features.delta_top_word_lm_trigram_ratio := 1000000;
    features.delta_top_word_lm_zero_count := 1000000;
    features.delta_top_input_syllable_count := 1000000;
    features.delta_top_score_per_unit := 1000000;
    features.delta_top_dict_weight_per_unit := 1000000;
    features.delta_top_complete_user := 1000000;
    features.delta_top_complete_dictionary := 1000000;
    features.delta_top_complete_chain := 1000000;
    features.delta_top_complete_pool_present := 1000000;
    features.delta_top_complete_pool_source_kind := 1000000;
    features.delta_top_complete_pool_rank := 1000000;
    features.delta_top_complete_pool_seed_rank := 1000000;
    features.delta_top_complete_pool_original := 1000000;
    features.delta_top_complete_pool_substitutions := 1000000;
    features.delta_top_complete_pool_changed_position := 1000000;
    features.delta_top_complete_pool_anchor_present := 1000000;
    features.delta_top_complete_pool_anchor_start := 1000000;
    features.delta_top_complete_pool_anchor_units := 1000000;
    features.delta_top_complete_pool_anchor_exact_rank := 1000000;
    features.delta_top_complete_pool_anchor_source_weight := 1000000;
    features.delta_top_complete_pool_anchor_replacement_weight := 1000000;
    features.delta_top_complete_pool_anchor_top_weight := 1000000;
    features.delta_top_complete_pool_anchor_weight_gain := 1000000;
    features.delta_top_complete_pool_pair_evidence := 1000000;
    features.delta_top_complete_pool_proper_name_confidence := 1000000;
    features.delta_top_complete_pool_signature_support := 1000000;
    features.delta_top_complete_pool_consensus_support := 1000000;
    features.delta_top_complete_pool_consensus_seed_count := 1000000;
    features.delta_top_complete_pool_consensus_support_mean := 1000000;
    features.delta_top_complete_pool_consensus_support_min := 1000000;
    features.delta_top_complete_pool_consensus_majority_units := 1000000;
    features.delta_top_complete_pool_consensus_unanimous_units := 1000000;
    features.delta_top_complete_pool_consensus_nearest_distance := 1000000;
    features.delta_top_complete_pool_consensus_mean_distance := 1000000;
    features.delta_top_complete_pool_consensus_changed_support := 1000000;
    features.delta_top_complete_pool_consensus_changed_top_match := 1000000;
    features.delta_top_complete_pool_local_pairwise_score := 1000000;
    features.challenger_rank := 1000000;
    features.challenger_ranker_score := 1000000;
    features.second_ranker_score := 1000000;
    features.top_ranker_score := 1000000;
    features.challenger_ranker_score_gap := 1000000;
    features.second_top_ranker_score_gap := 1000000;
    features.different_units := 1000000;
    features.different_runs := 1000000;
    features.max_different_run := 1000000;
    features.same_prefix_units := 1000000;
    features.same_suffix_units := 1000000;
    features.difference_span_units := 1000000;
    if long_second_slot_recovery_gate_score(features) <>
        c_long_second_slot_recovery_gate_reference_score_high then Exit(False);
    features.challenger_candidate_score := 131;
    features.challenger_dict_weight := -262;
    features.challenger_has_dict_weight := 393;
    features.challenger_source_user := -524;
    features.challenger_source_chain := 655;
    features.challenger_source_pattern := -786;
    features.challenger_source_redup := 917;
    features.challenger_source_local_rerank := -1048;
    features.challenger_source_rule_fallback := 1179;
    features.challenger_legacy_rank := -1310;
    features.challenger_legacy_top := 1441;
    features.challenger_chain_rank := -1572;
    features.challenger_chain_present := 1703;
    features.challenger_chain_first_stage_score := -1834;
    features.challenger_chain_second_stage_score := 1965;
    features.challenger_chain_score_gap := -2096;
    features.challenger_complete_match := 2227;
    features.challenger_partial_match := -2358;
    features.challenger_text_units := 2489;
    features.challenger_comment_length := -2620;
    features.challenger_unit_delta := 2751;
    features.challenger_path_available := -2882;
    features.challenger_path_confidence_score := 3013;
    features.challenger_path_confidence_tier := -3144;
    features.challenger_path_segments := 3275;
    features.challenger_path_single_segments := -3406;
    features.challenger_path_max_segment_units := 3537;
    features.challenger_char_lm_score := -3668;
    features.challenger_char_lm_suffix_score := 3799;
    features.challenger_char_lm_context_score := -3930;
    features.challenger_char_lm_context_gain := 4061;
    features.challenger_has_left_context := -4192;
    features.challenger_query_choice_bonus := 4323;
    features.challenger_latest_query_choice := -4454;
    features.challenger_query_path_bonus := 4585;
    features.challenger_query_path_penalty := -4716;
    features.challenger_word_lm_bonus := 4847;
    features.challenger_word_lm_boundary_count := -4978;
    features.challenger_word_lm_boundary_min := 5109;
    features.challenger_word_lm_boundary_max := -5240;
    features.challenger_word_lm_boundary_first := 5371;
    features.challenger_word_lm_boundary_last := -5502;
    features.challenger_word_lm_supported_ratio := 5633;
    features.challenger_word_lm_strong_ratio := -5764;
    features.challenger_word_lm_trigram_ratio := 5895;
    features.challenger_word_lm_zero_count := -6026;
    features.challenger_input_syllable_count := 6157;
    features.challenger_score_per_unit := -6288;
    features.challenger_dict_weight_per_unit := 6419;
    features.challenger_complete_user := -6550;
    features.challenger_complete_dictionary := 6681;
    features.challenger_complete_chain := -6812;
    features.challenger_complete_pool_present := 6943;
    features.challenger_complete_pool_source_kind := -7074;
    features.challenger_complete_pool_rank := 7205;
    features.challenger_complete_pool_seed_rank := -7336;
    features.challenger_complete_pool_original := 7467;
    features.challenger_complete_pool_substitutions := -7598;
    features.challenger_complete_pool_changed_position := 7729;
    features.challenger_complete_pool_anchor_present := -7860;
    features.challenger_complete_pool_anchor_start := 7991;
    features.challenger_complete_pool_anchor_units := -8122;
    features.challenger_complete_pool_anchor_exact_rank := 8253;
    features.challenger_complete_pool_anchor_source_weight := -8384;
    features.challenger_complete_pool_anchor_replacement_weight := 8515;
    features.challenger_complete_pool_anchor_top_weight := -8646;
    features.challenger_complete_pool_anchor_weight_gain := 8777;
    features.challenger_complete_pool_pair_evidence := -8908;
    features.challenger_complete_pool_proper_name_confidence := 9039;
    features.challenger_complete_pool_signature_support := -9170;
    features.challenger_complete_pool_consensus_support := 9301;
    features.challenger_complete_pool_consensus_seed_count := -9432;
    features.challenger_complete_pool_consensus_support_mean := 9563;
    features.challenger_complete_pool_consensus_support_min := -9694;
    features.challenger_complete_pool_consensus_majority_units := 9825;
    features.challenger_complete_pool_consensus_unanimous_units := -9956;
    features.challenger_complete_pool_consensus_nearest_distance := 10087;
    features.challenger_complete_pool_consensus_mean_distance := -10218;
    features.challenger_complete_pool_consensus_changed_support := 10349;
    features.challenger_complete_pool_consensus_changed_top_match := -10480;
    features.challenger_complete_pool_local_pairwise_score := 10611;
    features.delta_second_candidate_score := -10742;
    features.delta_second_dict_weight := 10873;
    features.delta_second_has_dict_weight := -11004;
    features.delta_second_source_user := 11135;
    features.delta_second_source_chain := -11266;
    features.delta_second_source_pattern := 11397;
    features.delta_second_source_redup := -11528;
    features.delta_second_source_local_rerank := 11659;
    features.delta_second_source_rule_fallback := -11790;
    features.delta_second_legacy_rank := 11921;
    features.delta_second_legacy_top := -12052;
    features.delta_second_chain_rank := 12183;
    features.delta_second_chain_present := -12314;
    features.delta_second_chain_first_stage_score := 12445;
    features.delta_second_chain_second_stage_score := -12576;
    features.delta_second_chain_score_gap := 12707;
    features.delta_second_complete_match := -12838;
    features.delta_second_partial_match := 12969;
    features.delta_second_text_units := -13100;
    features.delta_second_comment_length := 13231;
    features.delta_second_unit_delta := -13362;
    features.delta_second_path_available := 13493;
    features.delta_second_path_confidence_score := -13624;
    features.delta_second_path_confidence_tier := 13755;
    features.delta_second_path_segments := -13886;
    features.delta_second_path_single_segments := 14017;
    features.delta_second_path_max_segment_units := -14148;
    features.delta_second_char_lm_score := 14279;
    features.delta_second_char_lm_suffix_score := -14410;
    features.delta_second_char_lm_context_score := 14541;
    features.delta_second_char_lm_context_gain := -14672;
    features.delta_second_has_left_context := 14803;
    features.delta_second_query_choice_bonus := -14934;
    features.delta_second_latest_query_choice := 15065;
    features.delta_second_query_path_bonus := -15196;
    features.delta_second_query_path_penalty := 15327;
    features.delta_second_word_lm_bonus := -15458;
    features.delta_second_word_lm_boundary_count := 15589;
    features.delta_second_word_lm_boundary_min := -15720;
    features.delta_second_word_lm_boundary_max := 15851;
    features.delta_second_word_lm_boundary_first := -15982;
    features.delta_second_word_lm_boundary_last := 16113;
    features.delta_second_word_lm_supported_ratio := -16244;
    features.delta_second_word_lm_strong_ratio := 16375;
    features.delta_second_word_lm_trigram_ratio := -16506;
    features.delta_second_word_lm_zero_count := 16637;
    features.delta_second_input_syllable_count := -16768;
    features.delta_second_score_per_unit := 16899;
    features.delta_second_dict_weight_per_unit := -17030;
    features.delta_second_complete_user := 17161;
    features.delta_second_complete_dictionary := -17292;
    features.delta_second_complete_chain := 17423;
    features.delta_second_complete_pool_present := -17554;
    features.delta_second_complete_pool_source_kind := 17685;
    features.delta_second_complete_pool_rank := -17816;
    features.delta_second_complete_pool_seed_rank := 17947;
    features.delta_second_complete_pool_original := -18078;
    features.delta_second_complete_pool_substitutions := 18209;
    features.delta_second_complete_pool_changed_position := -18340;
    features.delta_second_complete_pool_anchor_present := 18471;
    features.delta_second_complete_pool_anchor_start := -18602;
    features.delta_second_complete_pool_anchor_units := 18733;
    features.delta_second_complete_pool_anchor_exact_rank := -18864;
    features.delta_second_complete_pool_anchor_source_weight := 18995;
    features.delta_second_complete_pool_anchor_replacement_weight := -19126;
    features.delta_second_complete_pool_anchor_top_weight := 19257;
    features.delta_second_complete_pool_anchor_weight_gain := -19388;
    features.delta_second_complete_pool_pair_evidence := 19519;
    features.delta_second_complete_pool_proper_name_confidence := -19650;
    features.delta_second_complete_pool_signature_support := 19781;
    features.delta_second_complete_pool_consensus_support := -19912;
    features.delta_second_complete_pool_consensus_seed_count := 20043;
    features.delta_second_complete_pool_consensus_support_mean := -20174;
    features.delta_second_complete_pool_consensus_support_min := 20305;
    features.delta_second_complete_pool_consensus_majority_units := -20436;
    features.delta_second_complete_pool_consensus_unanimous_units := 20567;
    features.delta_second_complete_pool_consensus_nearest_distance := -20698;
    features.delta_second_complete_pool_consensus_mean_distance := 20829;
    features.delta_second_complete_pool_consensus_changed_support := -20960;
    features.delta_second_complete_pool_consensus_changed_top_match := 21091;
    features.delta_second_complete_pool_local_pairwise_score := -21222;
    features.delta_top_candidate_score := 21353;
    features.delta_top_dict_weight := -21484;
    features.delta_top_has_dict_weight := 21615;
    features.delta_top_source_user := -21746;
    features.delta_top_source_chain := 21877;
    features.delta_top_source_pattern := -22008;
    features.delta_top_source_redup := 22139;
    features.delta_top_source_local_rerank := -22270;
    features.delta_top_source_rule_fallback := 22401;
    features.delta_top_legacy_rank := -22532;
    features.delta_top_legacy_top := 22663;
    features.delta_top_chain_rank := -22794;
    features.delta_top_chain_present := 22925;
    features.delta_top_chain_first_stage_score := -23056;
    features.delta_top_chain_second_stage_score := 23187;
    features.delta_top_chain_score_gap := -23318;
    features.delta_top_complete_match := 23449;
    features.delta_top_partial_match := -23580;
    features.delta_top_text_units := 23711;
    features.delta_top_comment_length := -23842;
    features.delta_top_unit_delta := 23973;
    features.delta_top_path_available := -24104;
    features.delta_top_path_confidence_score := 24235;
    features.delta_top_path_confidence_tier := -24366;
    features.delta_top_path_segments := 24497;
    features.delta_top_path_single_segments := -24628;
    features.delta_top_path_max_segment_units := 24759;
    features.delta_top_char_lm_score := -24890;
    features.delta_top_char_lm_suffix_score := 25021;
    features.delta_top_char_lm_context_score := -25152;
    features.delta_top_char_lm_context_gain := 25283;
    features.delta_top_has_left_context := -25414;
    features.delta_top_query_choice_bonus := 25545;
    features.delta_top_latest_query_choice := -25676;
    features.delta_top_query_path_bonus := 25807;
    features.delta_top_query_path_penalty := -25938;
    features.delta_top_word_lm_bonus := 26069;
    features.delta_top_word_lm_boundary_count := -26200;
    features.delta_top_word_lm_boundary_min := 26331;
    features.delta_top_word_lm_boundary_max := -26462;
    features.delta_top_word_lm_boundary_first := 26593;
    features.delta_top_word_lm_boundary_last := -26724;
    features.delta_top_word_lm_supported_ratio := 26855;
    features.delta_top_word_lm_strong_ratio := -26986;
    features.delta_top_word_lm_trigram_ratio := 27117;
    features.delta_top_word_lm_zero_count := -27248;
    features.delta_top_input_syllable_count := 27379;
    features.delta_top_score_per_unit := -27510;
    features.delta_top_dict_weight_per_unit := 27641;
    features.delta_top_complete_user := -27772;
    features.delta_top_complete_dictionary := 27903;
    features.delta_top_complete_chain := -28034;
    features.delta_top_complete_pool_present := 28165;
    features.delta_top_complete_pool_source_kind := -28296;
    features.delta_top_complete_pool_rank := 28427;
    features.delta_top_complete_pool_seed_rank := -28558;
    features.delta_top_complete_pool_original := 28689;
    features.delta_top_complete_pool_substitutions := -28820;
    features.delta_top_complete_pool_changed_position := 28951;
    features.delta_top_complete_pool_anchor_present := -29082;
    features.delta_top_complete_pool_anchor_start := 29213;
    features.delta_top_complete_pool_anchor_units := -29344;
    features.delta_top_complete_pool_anchor_exact_rank := 29475;
    features.delta_top_complete_pool_anchor_source_weight := -29606;
    features.delta_top_complete_pool_anchor_replacement_weight := 29737;
    features.delta_top_complete_pool_anchor_top_weight := -29868;
    features.delta_top_complete_pool_anchor_weight_gain := 29999;
    features.delta_top_complete_pool_pair_evidence := -30130;
    features.delta_top_complete_pool_proper_name_confidence := 30261;
    features.delta_top_complete_pool_signature_support := -30392;
    features.delta_top_complete_pool_consensus_support := 30523;
    features.delta_top_complete_pool_consensus_seed_count := -30654;
    features.delta_top_complete_pool_consensus_support_mean := 30785;
    features.delta_top_complete_pool_consensus_support_min := -30916;
    features.delta_top_complete_pool_consensus_majority_units := 31047;
    features.delta_top_complete_pool_consensus_unanimous_units := -31178;
    features.delta_top_complete_pool_consensus_nearest_distance := 31309;
    features.delta_top_complete_pool_consensus_mean_distance := -31440;
    features.delta_top_complete_pool_consensus_changed_support := 31571;
    features.delta_top_complete_pool_consensus_changed_top_match := -31702;
    features.delta_top_complete_pool_local_pairwise_score := 31833;
    features.challenger_rank := -31964;
    features.challenger_ranker_score := 32095;
    features.second_ranker_score := -32226;
    features.top_ranker_score := 32357;
    features.challenger_ranker_score_gap := -32488;
    features.second_top_ranker_score_gap := 32619;
    features.different_units := -32750;
    features.different_runs := 32881;
    features.max_different_run := -33012;
    features.same_prefix_units := 33143;
    features.same_suffix_units := -33274;
    features.difference_span_units := 33405;
    Result := long_second_slot_recovery_gate_score(features) =
        c_long_second_slot_recovery_gate_reference_score_mixed;
end;

end.
