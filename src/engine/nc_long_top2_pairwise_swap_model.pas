unit nc_long_top2_pairwise_swap_model;

interface

uses
    System.SysUtils,
    System.Math,
    nc_long_ranker_features;

type
    TncLongTop2PairwiseSwapFeatures = record
        candidate_candidate_score: Double;
        candidate_dict_weight: Double;
        candidate_has_dict_weight: Double;
        candidate_source_user: Double;
        candidate_source_chain: Double;
        candidate_source_pattern: Double;
        candidate_source_redup: Double;
        candidate_source_local_rerank: Double;
        candidate_source_rule_fallback: Double;
        candidate_legacy_rank: Double;
        candidate_legacy_top: Double;
        candidate_chain_rank: Double;
        candidate_chain_present: Double;
        candidate_chain_first_stage_score: Double;
        candidate_chain_second_stage_score: Double;
        candidate_chain_score_gap: Double;
        candidate_complete_match: Double;
        candidate_partial_match: Double;
        candidate_text_units: Double;
        candidate_comment_length: Double;
        candidate_unit_delta: Double;
        candidate_path_available: Double;
        candidate_path_confidence_score: Double;
        candidate_path_confidence_tier: Double;
        candidate_path_segments: Double;
        candidate_path_single_segments: Double;
        candidate_path_max_segment_units: Double;
        candidate_char_lm_score: Double;
        candidate_char_lm_suffix_score: Double;
        candidate_char_lm_context_score: Double;
        candidate_char_lm_context_gain: Double;
        candidate_has_left_context: Double;
        candidate_query_choice_bonus: Double;
        candidate_latest_query_choice: Double;
        candidate_query_path_bonus: Double;
        candidate_query_path_penalty: Double;
        candidate_word_lm_bonus: Double;
        candidate_word_lm_boundary_count: Double;
        candidate_word_lm_boundary_min: Double;
        candidate_word_lm_boundary_max: Double;
        candidate_word_lm_boundary_first: Double;
        candidate_word_lm_boundary_last: Double;
        candidate_word_lm_supported_ratio: Double;
        candidate_word_lm_strong_ratio: Double;
        candidate_word_lm_trigram_ratio: Double;
        candidate_word_lm_zero_count: Double;
        candidate_input_syllable_count: Double;
        candidate_score_per_unit: Double;
        candidate_dict_weight_per_unit: Double;
        candidate_complete_user: Double;
        candidate_complete_dictionary: Double;
        candidate_complete_chain: Double;
        candidate_complete_pool_present: Double;
        candidate_complete_pool_source_kind: Double;
        candidate_complete_pool_rank: Double;
        candidate_complete_pool_seed_rank: Double;
        candidate_complete_pool_original: Double;
        candidate_complete_pool_substitutions: Double;
        candidate_complete_pool_changed_position: Double;
        candidate_complete_pool_pair_evidence: Double;
        candidate_complete_pool_proper_name_confidence: Double;
        candidate_complete_pool_signature_support: Double;
        candidate_complete_pool_consensus_support: Double;
        candidate_complete_pool_consensus_seed_count: Double;
        candidate_complete_pool_consensus_support_mean: Double;
        candidate_complete_pool_consensus_support_min: Double;
        candidate_complete_pool_consensus_majority_units: Double;
        candidate_complete_pool_consensus_unanimous_units: Double;
        candidate_complete_pool_consensus_nearest_distance: Double;
        candidate_complete_pool_consensus_mean_distance: Double;
        candidate_complete_pool_consensus_changed_support: Double;
        candidate_complete_pool_consensus_changed_top_match: Double;
        candidate_complete_pool_local_pairwise_score: Double;
        delta_candidate_score: Double;
        delta_dict_weight: Double;
        delta_has_dict_weight: Double;
        delta_source_user: Double;
        delta_source_chain: Double;
        delta_source_pattern: Double;
        delta_source_redup: Double;
        delta_source_local_rerank: Double;
        delta_source_rule_fallback: Double;
        delta_legacy_rank: Double;
        delta_legacy_top: Double;
        delta_chain_rank: Double;
        delta_chain_present: Double;
        delta_chain_first_stage_score: Double;
        delta_chain_second_stage_score: Double;
        delta_chain_score_gap: Double;
        delta_complete_match: Double;
        delta_partial_match: Double;
        delta_text_units: Double;
        delta_comment_length: Double;
        delta_unit_delta: Double;
        delta_path_available: Double;
        delta_path_confidence_score: Double;
        delta_path_confidence_tier: Double;
        delta_path_segments: Double;
        delta_path_single_segments: Double;
        delta_path_max_segment_units: Double;
        delta_char_lm_score: Double;
        delta_char_lm_suffix_score: Double;
        delta_char_lm_context_score: Double;
        delta_char_lm_context_gain: Double;
        delta_has_left_context: Double;
        delta_query_choice_bonus: Double;
        delta_latest_query_choice: Double;
        delta_query_path_bonus: Double;
        delta_query_path_penalty: Double;
        delta_word_lm_bonus: Double;
        delta_word_lm_boundary_count: Double;
        delta_word_lm_boundary_min: Double;
        delta_word_lm_boundary_max: Double;
        delta_word_lm_boundary_first: Double;
        delta_word_lm_boundary_last: Double;
        delta_word_lm_supported_ratio: Double;
        delta_word_lm_strong_ratio: Double;
        delta_word_lm_trigram_ratio: Double;
        delta_word_lm_zero_count: Double;
        delta_input_syllable_count: Double;
        delta_score_per_unit: Double;
        delta_dict_weight_per_unit: Double;
        delta_complete_user: Double;
        delta_complete_dictionary: Double;
        delta_complete_chain: Double;
        delta_complete_pool_present: Double;
        delta_complete_pool_source_kind: Double;
        delta_complete_pool_rank: Double;
        delta_complete_pool_seed_rank: Double;
        delta_complete_pool_original: Double;
        delta_complete_pool_substitutions: Double;
        delta_complete_pool_changed_position: Double;
        delta_complete_pool_pair_evidence: Double;
        delta_complete_pool_proper_name_confidence: Double;
        delta_complete_pool_signature_support: Double;
        delta_complete_pool_consensus_support: Double;
        delta_complete_pool_consensus_seed_count: Double;
        delta_complete_pool_consensus_support_mean: Double;
        delta_complete_pool_consensus_support_min: Double;
        delta_complete_pool_consensus_majority_units: Double;
        delta_complete_pool_consensus_unanimous_units: Double;
        delta_complete_pool_consensus_nearest_distance: Double;
        delta_complete_pool_consensus_mean_distance: Double;
        delta_complete_pool_consensus_changed_support: Double;
        delta_complete_pool_consensus_changed_top_match: Double;
        delta_complete_pool_local_pairwise_score: Double;
        candidate_ranker_score: Double;
        top_ranker_score: Double;
        ranker_score_gap: Double;
        baseline_ranker_applied: Double;
        baseline_abstain_score: Double;
        different_units: Double;
        different_runs: Double;
        max_different_run: Double;
        same_prefix_units: Double;
        same_suffix_units: Double;
        difference_span_units: Double;
        same_segment_path: Double;
        top_local_lm_r0: Double;
        candidate_local_lm_r0: Double;
        delta_local_lm_r0: Double;
        top_local_lm_r1: Double;
        candidate_local_lm_r1: Double;
        delta_local_lm_r1: Double;
        top_local_lm_r2: Double;
        candidate_local_lm_r2: Double;
        delta_local_lm_r2: Double;
        top_local_lm_r3: Double;
        candidate_local_lm_r3: Double;
        delta_local_lm_r3: Double;
        delta_char_lm_per_difference: Double;
        delta_char_suffix_lm_per_difference: Double;
        delta_word_lm_per_boundary: Double;
    end;

const
    c_long_top2_pairwise_swap_feature_count: Integer = 173;
    c_long_top2_pairwise_swap_tree_count: Integer = 160;
    c_long_top2_pairwise_swap_score_scale: Double = 100000000.0;
    c_long_top2_pairwise_swap_promotion_threshold: Int64 = -101870449;
    c_long_top2_pairwise_swap_reference_score: Int64 = -219107158;
    c_long_top2_pairwise_swap_reference_score_low: Int64 = -325544197;
    c_long_top2_pairwise_swap_reference_score_high: Int64 = -225094575;
    c_long_top2_pairwise_swap_reference_score_mixed: Int64 = -249858027;

procedure build_long_top2_pairwise_swap_features(
    const candidate_features: TncLongFinalRankerFeatures;
    const top_features: TncLongFinalRankerFeatures;
    const candidate_ranker_score: Int64;
    const top_ranker_score: Int64;
    const baseline_ranker_applied: Boolean;
    const baseline_abstain_score: Int64;
    const different_units: Integer;
    const different_runs: Integer;
    const max_different_run: Integer;
    const same_prefix_units: Integer;
    const same_suffix_units: Integer;
    const difference_span_units: Integer;
    const same_segment_path: Boolean;
    const top_local_lm_scores: TArray<Integer>;
    const candidate_local_lm_scores: TArray<Integer>;
    out features: TncLongTop2PairwiseSwapFeatures);
function long_top2_pairwise_swap_score(
    const features: TncLongTop2PairwiseSwapFeatures): Int64;
function long_top2_pairwise_swap_self_test: Boolean;

implementation

{ Conservative final Top1/Top2 swap classifier. It never changes the
  candidate set or promotes a candidate below rank two.
  Training report SHA-256: 813573F9548D9D7E6630ADABEC78B271D8C81A006F8F5CE72E19FC7DFE7B19A5
  LightGBM model SHA-256: 71334DEB71031C10D518B5C13A1D1D1D83611D1A32713D24E9B7164D4288F889 }

procedure build_long_top2_pairwise_swap_features(
    const candidate_features: TncLongFinalRankerFeatures;
    const top_features: TncLongFinalRankerFeatures;
    const candidate_ranker_score: Int64;
    const top_ranker_score: Int64;
    const baseline_ranker_applied: Boolean;
    const baseline_abstain_score: Int64;
    const different_units: Integer;
    const different_runs: Integer;
    const max_different_run: Integer;
    const same_prefix_units: Integer;
    const same_suffix_units: Integer;
    const difference_span_units: Integer;
    const same_segment_path: Boolean;
    const top_local_lm_scores: TArray<Integer>;
    const candidate_local_lm_scores: TArray<Integer>;
    out features: TncLongTop2PairwiseSwapFeatures);
begin
    features.candidate_candidate_score := candidate_features.candidate_score;
    features.candidate_dict_weight := candidate_features.dict_weight;
    features.candidate_has_dict_weight := Ord(candidate_features.has_dict_weight);
    features.candidate_source_user := Ord(candidate_features.source_user);
    features.candidate_source_chain := Ord(candidate_features.source_chain);
    features.candidate_source_pattern := Ord(candidate_features.source_pattern);
    features.candidate_source_redup := Ord(candidate_features.source_redup);
    features.candidate_source_local_rerank := Ord(candidate_features.source_local_rerank);
    features.candidate_source_rule_fallback := Ord(candidate_features.source_rule_fallback);
    features.candidate_legacy_rank := candidate_features.legacy_rank;
    features.candidate_legacy_top := Ord(candidate_features.legacy_top);
    features.candidate_chain_rank := candidate_features.chain_rank;
    features.candidate_chain_present := Ord(candidate_features.chain_present);
    features.candidate_chain_first_stage_score := candidate_features.chain_first_stage_score;
    features.candidate_chain_second_stage_score := candidate_features.chain_second_stage_score;
    features.candidate_chain_score_gap := candidate_features.chain_score_gap;
    features.candidate_complete_match := Ord(candidate_features.complete_match);
    features.candidate_partial_match := Ord(candidate_features.partial_match);
    features.candidate_text_units := candidate_features.text_units;
    features.candidate_comment_length := candidate_features.comment_length;
    features.candidate_unit_delta := candidate_features.unit_delta;
    features.candidate_path_available := Ord(candidate_features.path_available);
    features.candidate_path_confidence_score := candidate_features.path_confidence_score;
    features.candidate_path_confidence_tier := candidate_features.path_confidence_tier;
    features.candidate_path_segments := candidate_features.path_segments;
    features.candidate_path_single_segments := candidate_features.path_single_segments;
    features.candidate_path_max_segment_units := candidate_features.path_max_segment_units;
    features.candidate_char_lm_score := candidate_features.char_lm_score;
    features.candidate_char_lm_suffix_score := candidate_features.char_lm_suffix_score;
    features.candidate_char_lm_context_score := candidate_features.char_lm_context_score;
    features.candidate_char_lm_context_gain := candidate_features.char_lm_context_gain;
    features.candidate_has_left_context := Ord(candidate_features.has_left_context);
    features.candidate_query_choice_bonus := candidate_features.query_choice_bonus;
    features.candidate_latest_query_choice := Ord(candidate_features.latest_query_choice);
    features.candidate_query_path_bonus := candidate_features.query_path_bonus;
    features.candidate_query_path_penalty := candidate_features.query_path_penalty;
    features.candidate_word_lm_bonus := candidate_features.word_lm_bonus;
    features.candidate_word_lm_boundary_count := candidate_features.word_lm_boundary_count;
    features.candidate_word_lm_boundary_min := candidate_features.word_lm_boundary_min;
    features.candidate_word_lm_boundary_max := candidate_features.word_lm_boundary_max;
    features.candidate_word_lm_boundary_first := candidate_features.word_lm_boundary_first;
    features.candidate_word_lm_boundary_last := candidate_features.word_lm_boundary_last;
    features.candidate_word_lm_supported_ratio := candidate_features.word_lm_supported_ratio;
    features.candidate_word_lm_strong_ratio := candidate_features.word_lm_strong_ratio;
    features.candidate_word_lm_trigram_ratio := candidate_features.word_lm_trigram_ratio;
    features.candidate_word_lm_zero_count := candidate_features.word_lm_zero_count;
    features.candidate_input_syllable_count := candidate_features.input_syllable_count;
    features.candidate_score_per_unit := candidate_features.score_per_unit;
    features.candidate_dict_weight_per_unit := candidate_features.dict_weight_per_unit;
    features.candidate_complete_user := Ord(candidate_features.complete_user);
    features.candidate_complete_dictionary := Ord(candidate_features.complete_dictionary);
    features.candidate_complete_chain := Ord(candidate_features.complete_chain);
    features.candidate_complete_pool_present := Ord(candidate_features.complete_pool_present);
    features.candidate_complete_pool_source_kind := candidate_features.complete_pool_source_kind;
    features.candidate_complete_pool_rank := candidate_features.complete_pool_rank;
    features.candidate_complete_pool_seed_rank := candidate_features.complete_pool_seed_rank;
    features.candidate_complete_pool_original := Ord(candidate_features.complete_pool_original);
    features.candidate_complete_pool_substitutions := candidate_features.complete_pool_substitutions;
    features.candidate_complete_pool_changed_position := candidate_features.complete_pool_changed_position;
    features.candidate_complete_pool_pair_evidence := candidate_features.complete_pool_pair_evidence;
    features.candidate_complete_pool_proper_name_confidence := candidate_features.complete_pool_proper_name_confidence;
    features.candidate_complete_pool_signature_support := candidate_features.complete_pool_signature_support;
    features.candidate_complete_pool_consensus_support := candidate_features.complete_pool_consensus_support;
    features.candidate_complete_pool_consensus_seed_count := candidate_features.complete_pool_consensus_seed_count;
    features.candidate_complete_pool_consensus_support_mean := candidate_features.complete_pool_consensus_support_mean;
    features.candidate_complete_pool_consensus_support_min := candidate_features.complete_pool_consensus_support_min;
    features.candidate_complete_pool_consensus_majority_units := candidate_features.complete_pool_consensus_majority_units;
    features.candidate_complete_pool_consensus_unanimous_units := candidate_features.complete_pool_consensus_unanimous_units;
    features.candidate_complete_pool_consensus_nearest_distance := candidate_features.complete_pool_consensus_nearest_distance;
    features.candidate_complete_pool_consensus_mean_distance := candidate_features.complete_pool_consensus_mean_distance;
    features.candidate_complete_pool_consensus_changed_support := candidate_features.complete_pool_consensus_changed_support;
    features.candidate_complete_pool_consensus_changed_top_match := Ord(candidate_features.complete_pool_consensus_changed_top_match);
    features.candidate_complete_pool_local_pairwise_score := candidate_features.complete_pool_local_pairwise_score;
    features.delta_candidate_score := candidate_features.candidate_score - top_features.candidate_score;
    features.delta_dict_weight := candidate_features.dict_weight - top_features.dict_weight;
    features.delta_has_dict_weight := Ord(candidate_features.has_dict_weight) - Ord(top_features.has_dict_weight);
    features.delta_source_user := Ord(candidate_features.source_user) - Ord(top_features.source_user);
    features.delta_source_chain := Ord(candidate_features.source_chain) - Ord(top_features.source_chain);
    features.delta_source_pattern := Ord(candidate_features.source_pattern) - Ord(top_features.source_pattern);
    features.delta_source_redup := Ord(candidate_features.source_redup) - Ord(top_features.source_redup);
    features.delta_source_local_rerank := Ord(candidate_features.source_local_rerank) - Ord(top_features.source_local_rerank);
    features.delta_source_rule_fallback := Ord(candidate_features.source_rule_fallback) - Ord(top_features.source_rule_fallback);
    features.delta_legacy_rank := candidate_features.legacy_rank - top_features.legacy_rank;
    features.delta_legacy_top := Ord(candidate_features.legacy_top) - Ord(top_features.legacy_top);
    features.delta_chain_rank := candidate_features.chain_rank - top_features.chain_rank;
    features.delta_chain_present := Ord(candidate_features.chain_present) - Ord(top_features.chain_present);
    features.delta_chain_first_stage_score := candidate_features.chain_first_stage_score - top_features.chain_first_stage_score;
    features.delta_chain_second_stage_score := candidate_features.chain_second_stage_score - top_features.chain_second_stage_score;
    features.delta_chain_score_gap := candidate_features.chain_score_gap - top_features.chain_score_gap;
    features.delta_complete_match := Ord(candidate_features.complete_match) - Ord(top_features.complete_match);
    features.delta_partial_match := Ord(candidate_features.partial_match) - Ord(top_features.partial_match);
    features.delta_text_units := candidate_features.text_units - top_features.text_units;
    features.delta_comment_length := candidate_features.comment_length - top_features.comment_length;
    features.delta_unit_delta := candidate_features.unit_delta - top_features.unit_delta;
    features.delta_path_available := Ord(candidate_features.path_available) - Ord(top_features.path_available);
    features.delta_path_confidence_score := candidate_features.path_confidence_score - top_features.path_confidence_score;
    features.delta_path_confidence_tier := candidate_features.path_confidence_tier - top_features.path_confidence_tier;
    features.delta_path_segments := candidate_features.path_segments - top_features.path_segments;
    features.delta_path_single_segments := candidate_features.path_single_segments - top_features.path_single_segments;
    features.delta_path_max_segment_units := candidate_features.path_max_segment_units - top_features.path_max_segment_units;
    features.delta_char_lm_score := candidate_features.char_lm_score - top_features.char_lm_score;
    features.delta_char_lm_suffix_score := candidate_features.char_lm_suffix_score - top_features.char_lm_suffix_score;
    features.delta_char_lm_context_score := candidate_features.char_lm_context_score - top_features.char_lm_context_score;
    features.delta_char_lm_context_gain := candidate_features.char_lm_context_gain - top_features.char_lm_context_gain;
    features.delta_has_left_context := Ord(candidate_features.has_left_context) - Ord(top_features.has_left_context);
    features.delta_query_choice_bonus := candidate_features.query_choice_bonus - top_features.query_choice_bonus;
    features.delta_latest_query_choice := Ord(candidate_features.latest_query_choice) - Ord(top_features.latest_query_choice);
    features.delta_query_path_bonus := candidate_features.query_path_bonus - top_features.query_path_bonus;
    features.delta_query_path_penalty := candidate_features.query_path_penalty - top_features.query_path_penalty;
    features.delta_word_lm_bonus := candidate_features.word_lm_bonus - top_features.word_lm_bonus;
    features.delta_word_lm_boundary_count := candidate_features.word_lm_boundary_count - top_features.word_lm_boundary_count;
    features.delta_word_lm_boundary_min := candidate_features.word_lm_boundary_min - top_features.word_lm_boundary_min;
    features.delta_word_lm_boundary_max := candidate_features.word_lm_boundary_max - top_features.word_lm_boundary_max;
    features.delta_word_lm_boundary_first := candidate_features.word_lm_boundary_first - top_features.word_lm_boundary_first;
    features.delta_word_lm_boundary_last := candidate_features.word_lm_boundary_last - top_features.word_lm_boundary_last;
    features.delta_word_lm_supported_ratio := candidate_features.word_lm_supported_ratio - top_features.word_lm_supported_ratio;
    features.delta_word_lm_strong_ratio := candidate_features.word_lm_strong_ratio - top_features.word_lm_strong_ratio;
    features.delta_word_lm_trigram_ratio := candidate_features.word_lm_trigram_ratio - top_features.word_lm_trigram_ratio;
    features.delta_word_lm_zero_count := candidate_features.word_lm_zero_count - top_features.word_lm_zero_count;
    features.delta_input_syllable_count := candidate_features.input_syllable_count - top_features.input_syllable_count;
    features.delta_score_per_unit := candidate_features.score_per_unit - top_features.score_per_unit;
    features.delta_dict_weight_per_unit := candidate_features.dict_weight_per_unit - top_features.dict_weight_per_unit;
    features.delta_complete_user := Ord(candidate_features.complete_user) - Ord(top_features.complete_user);
    features.delta_complete_dictionary := Ord(candidate_features.complete_dictionary) - Ord(top_features.complete_dictionary);
    features.delta_complete_chain := Ord(candidate_features.complete_chain) - Ord(top_features.complete_chain);
    features.delta_complete_pool_present := Ord(candidate_features.complete_pool_present) - Ord(top_features.complete_pool_present);
    features.delta_complete_pool_source_kind := candidate_features.complete_pool_source_kind - top_features.complete_pool_source_kind;
    features.delta_complete_pool_rank := candidate_features.complete_pool_rank - top_features.complete_pool_rank;
    features.delta_complete_pool_seed_rank := candidate_features.complete_pool_seed_rank - top_features.complete_pool_seed_rank;
    features.delta_complete_pool_original := Ord(candidate_features.complete_pool_original) - Ord(top_features.complete_pool_original);
    features.delta_complete_pool_substitutions := candidate_features.complete_pool_substitutions - top_features.complete_pool_substitutions;
    features.delta_complete_pool_changed_position := candidate_features.complete_pool_changed_position - top_features.complete_pool_changed_position;
    features.delta_complete_pool_pair_evidence := candidate_features.complete_pool_pair_evidence - top_features.complete_pool_pair_evidence;
    features.delta_complete_pool_proper_name_confidence := candidate_features.complete_pool_proper_name_confidence - top_features.complete_pool_proper_name_confidence;
    features.delta_complete_pool_signature_support := candidate_features.complete_pool_signature_support - top_features.complete_pool_signature_support;
    features.delta_complete_pool_consensus_support := candidate_features.complete_pool_consensus_support - top_features.complete_pool_consensus_support;
    features.delta_complete_pool_consensus_seed_count := candidate_features.complete_pool_consensus_seed_count - top_features.complete_pool_consensus_seed_count;
    features.delta_complete_pool_consensus_support_mean := candidate_features.complete_pool_consensus_support_mean - top_features.complete_pool_consensus_support_mean;
    features.delta_complete_pool_consensus_support_min := candidate_features.complete_pool_consensus_support_min - top_features.complete_pool_consensus_support_min;
    features.delta_complete_pool_consensus_majority_units := candidate_features.complete_pool_consensus_majority_units - top_features.complete_pool_consensus_majority_units;
    features.delta_complete_pool_consensus_unanimous_units := candidate_features.complete_pool_consensus_unanimous_units - top_features.complete_pool_consensus_unanimous_units;
    features.delta_complete_pool_consensus_nearest_distance := candidate_features.complete_pool_consensus_nearest_distance - top_features.complete_pool_consensus_nearest_distance;
    features.delta_complete_pool_consensus_mean_distance := candidate_features.complete_pool_consensus_mean_distance - top_features.complete_pool_consensus_mean_distance;
    features.delta_complete_pool_consensus_changed_support := candidate_features.complete_pool_consensus_changed_support - top_features.complete_pool_consensus_changed_support;
    features.delta_complete_pool_consensus_changed_top_match := Ord(candidate_features.complete_pool_consensus_changed_top_match) - Ord(top_features.complete_pool_consensus_changed_top_match);
    features.delta_complete_pool_local_pairwise_score := candidate_features.complete_pool_local_pairwise_score - top_features.complete_pool_local_pairwise_score;
    features.candidate_ranker_score := candidate_ranker_score;
    features.top_ranker_score := top_ranker_score;
    features.ranker_score_gap := candidate_ranker_score - top_ranker_score;
    features.baseline_ranker_applied := Ord(baseline_ranker_applied);
    features.baseline_abstain_score := baseline_abstain_score;
    features.different_units := different_units;
    features.different_runs := different_runs;
    features.max_different_run := max_different_run;
    features.same_prefix_units := same_prefix_units;
    features.same_suffix_units := same_suffix_units;
    features.difference_span_units := difference_span_units;
    features.same_segment_path := Ord(same_segment_path);
    features.top_local_lm_r0 := top_local_lm_scores[0];
    features.candidate_local_lm_r0 := candidate_local_lm_scores[0];
    features.delta_local_lm_r0 := candidate_local_lm_scores[0] - top_local_lm_scores[0];
    features.top_local_lm_r1 := top_local_lm_scores[1];
    features.candidate_local_lm_r1 := candidate_local_lm_scores[1];
    features.delta_local_lm_r1 := candidate_local_lm_scores[1] - top_local_lm_scores[1];
    features.top_local_lm_r2 := top_local_lm_scores[2];
    features.candidate_local_lm_r2 := candidate_local_lm_scores[2];
    features.delta_local_lm_r2 := candidate_local_lm_scores[2] - top_local_lm_scores[2];
    features.top_local_lm_r3 := top_local_lm_scores[3];
    features.candidate_local_lm_r3 := candidate_local_lm_scores[3];
    features.delta_local_lm_r3 := candidate_local_lm_scores[3] - top_local_lm_scores[3];
    features.delta_char_lm_per_difference :=
        (candidate_features.char_lm_score - top_features.char_lm_score) /
        Max(1, different_units);
    features.delta_char_suffix_lm_per_difference :=
        (candidate_features.char_lm_suffix_score -
        top_features.char_lm_suffix_score) / Max(1, different_units);
    features.delta_word_lm_per_boundary :=
        (candidate_features.word_lm_bonus - top_features.word_lm_bonus) /
        Max(1, candidate_features.word_lm_boundary_count);
end;

function long_top2_pairwise_swap_tree_0(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -160691851.49999997 then
    begin
        if features.ranker_score_gap <= -233163470.49999997 then
        begin
            Result := -3.7160173374159924;
        end
        else
        begin
            Result := -3.6982501462167305;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= 1.0000000180025095E-35 then
        begin
            if features.candidate_char_lm_score <= -5632.4999999999991 then
            begin
                Result := -3.6875052626257943;
            end
            else
            begin
                if features.delta_char_lm_score <= -136.49999999999997 then
                begin
                    if features.baseline_abstain_score <= 32548158.500000004 then
                    begin
                        if features.ranker_score_gap <= -96215340.999999985 then
                        begin
                            Result := -3.6746975400726272;
                        end
                        else
                        begin
                            Result := -3.6495472986084465;
                        end;
                    end
                    else
                    begin
                        Result := -3.7016779444461334;
                    end;
                end
                else
                begin
                    if features.ranker_score_gap <= -66428624.999999993 then
                    begin
                        if features.candidate_local_lm_r0 <= -6232.4999999999991 then
                        begin
                            if features.different_units <= 1.5000000000000002 then
                            begin
                                Result := -3.6554464324345819;
                            end
                            else
                            begin
                                Result := -3.6936037371817778;
                            end;
                        end
                        else
                        begin
                            Result := -3.6368017824176571;
                        end;
                    end
                    else
                    begin
                        if features.candidate_ranker_score <= 208198355.00000003 then
                        begin
                            Result := -3.637752501288726;
                        end
                        else
                        begin
                            Result := -3.5880799627546414;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.top_ranker_score <= -190901634.99999997 then
            begin
                Result := -3.6667939352625916;
            end
            else
            begin
                if features.candidate_complete_pool_signature_support <= 41.500000000000007 then
                begin
                    if features.delta_local_lm_r3 <= 1342.5000000000002 then
                    begin
                        Result := -3.5343408403682495;
                    end
                    else
                    begin
                        Result := -3.6703266167277779;
                    end;
                end
                else
                begin
                    Result := -3.6801762884864813;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_1(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -160691851.49999997 then
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            Result := -0.021465361463935344;
        end
        else
        begin
            Result := -0.0018501021095048264;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= 6483591.5000000009 then
        begin
            if features.candidate_char_lm_score <= -5632.4999999999991 then
            begin
                if features.candidate_ranker_score <= -153101572.49999997 then
                begin
                    Result := -0.0046449247250694775;
                end
                else
                begin
                    Result := 0.015778390053821301;
                end;
            end
            else
            begin
                if features.ranker_score_gap <= -66428624.999999993 then
                begin
                    if features.delta_char_lm_score <= -336.49999999999994 then
                    begin
                        Result := 0.0081205969288696035;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -6201.4999999999991 then
                        begin
                            if features.difference_span_units <= 1.5000000000000002 then
                            begin
                                if features.delta_word_lm_boundary_count <= 3.5000000000000004 then
                                begin
                                    Result := 0.029299156163033069;
                                end
                                else
                                begin
                                    Result := 0.077603413711105212;
                                end;
                            end
                            else
                            begin
                                Result := 0.0039179627024660971;
                            end;
                        end
                        else
                        begin
                            Result := 0.04876662090514116;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= -1.4999999999999998 then
                    begin
                        Result := 0.013347949644632158;
                    end
                    else
                    begin
                        Result := 0.065745155558461221;
                    end;
                end;
            end;
        end
        else
        begin
            if features.top_ranker_score <= -190901634.99999997 then
            begin
                Result := 0.029721324252444906;
            end
            else
            begin
                if features.candidate_complete_pool_signature_support <= 41.500000000000007 then
                begin
                    if features.delta_local_lm_r3 <= 1342.5000000000002 then
                    begin
                        Result := 0.14485676962794111;
                    end
                    else
                    begin
                        Result := 0.017039371066248882;
                    end;
                end
                else
                begin
                    Result := 0.0081287540566975999;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_2(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -160691851.49999997 then
    begin
        if features.ranker_score_gap <= -233163470.49999997 then
        begin
            Result := -0.022034173231415793;
        end
        else
        begin
            Result := -0.0042124244183442908;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= 1.0000000180025095E-35 then
        begin
            if features.candidate_char_lm_score <= -5632.4999999999991 then
            begin
                if features.candidate_ranker_score <= -153101572.49999997 then
                begin
                    Result := -0.0043713855202816478;
                end
                else
                begin
                    Result := 0.01474731851929835;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -136.49999999999997 then
                begin
                    if features.baseline_abstain_score <= 29567009.500000004 then
                    begin
                        if features.ranker_score_gap <= -96215340.999999985 then
                        begin
                            Result := 0.017421003866825262;
                        end
                        else
                        begin
                            Result := 0.039685550872014905;
                        end;
                    end
                    else
                    begin
                        Result := -0.0075803645139012766;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -7357.4999999999991 then
                    begin
                        if features.max_different_run <= 1.5000000000000002 then
                        begin
                            if features.candidate_local_lm_r2 <= -6857.4999999999991 then
                            begin
                                Result := 0.026543047151186668;
                            end
                            else
                            begin
                                Result := 0.054406786061810798;
                            end;
                        end
                        else
                        begin
                            Result := -0.0039770542739349692;
                        end;
                    end
                    else
                    begin
                        if features.ranker_score_gap <= -75646450.999999985 then
                        begin
                            Result := 0.042875546141568827;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_signature_support <= 9.5000000000000018 then
                            begin
                                Result := 0.082194191268127506;
                            end
                            else
                            begin
                                Result := 0.039518998508356308;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.top_ranker_score <= -224645267.49999997 then
            begin
                Result := 0.01684142278100877;
            end
            else
            begin
                Result := 0.1088052309663235;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_3(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -163813990.99999997 then
    begin
        if features.ranker_score_gap <= -233163470.49999997 then
        begin
            Result := -0.02194570200715236;
        end
        else
        begin
            Result := -0.0047051782678798771;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -4991225.9999999991 then
        begin
            if features.candidate_ranker_score <= -65970092.999999993 then
            begin
                Result := 0.002365132694520166;
            end
            else
            begin
                if features.delta_char_lm_score <= -147.49999999999997 then
                begin
                    if features.baseline_abstain_score <= 14005593.000000002 then
                    begin
                        if features.ranker_score_gap <= -96215340.999999985 then
                        begin
                            Result := 0.014522424385560718;
                        end
                        else
                        begin
                            Result := 0.036699599463507634;
                        end;
                    end
                    else
                    begin
                        Result := -0.0065834066111223714;
                    end;
                end
                else
                begin
                    if features.ranker_score_gap <= -63822726.499999993 then
                    begin
                        if features.candidate_ranker_score <= 107133954.50000001 then
                        begin
                            Result := 0.020178308211839933;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= -1528.4999999999998 then
                            begin
                                Result := 0.019221014297009436;
                            end
                            else
                            begin
                                Result := 0.0485666705450883;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.candidate_ranker_score <= 208198355.00000003 then
                        begin
                            Result := 0.045314352513495963;
                        end
                        else
                        begin
                            Result := 0.081568602303262711;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_second_stage_score <= -312610551.99999994 then
            begin
                Result := 0.0055661743561303788;
            end
            else
            begin
                if features.candidate_ranker_score <= 57902221.000000007 then
                begin
                    Result := 0.069027453281339843;
                end
                else
                begin
                    if features.candidate_path_single_segments <= 11.500000000000002 then
                    begin
                        Result := 0.11704123527696864;
                    end
                    else
                    begin
                        Result := 0.0038910179218836251;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_4(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -163813990.99999997 then
    begin
        if features.ranker_score_gap <= -233163470.49999997 then
        begin
            Result := -0.0218562013055696;
        end
        else
        begin
            Result := -0.0046089597188819177;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= 6483591.5000000009 then
        begin
            if features.candidate_char_lm_score <= -5632.4999999999991 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.008103282848616401;
                end
                else
                begin
                    Result := 0.011738935171907827;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -222.49999999999997 then
                begin
                    if features.baseline_abstain_score <= 32548158.500000004 then
                    begin
                        Result := 0.020083569839801984;
                    end
                    else
                    begin
                        Result := -0.0089067190601703154;
                    end;
                end
                else
                begin
                    if features.ranker_score_gap <= -66428624.999999993 then
                    begin
                        if features.delta_local_lm_r0 <= -1255.4999999999998 then
                        begin
                            Result := 0.016019306484018385;
                        end
                        else
                        begin
                            if features.candidate_chain_score_gap <= -59624646.999999993 then
                            begin
                                Result := 0.016413384948444947;
                            end
                            else
                            begin
                                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                                begin
                                    Result := 0.0043524951484242179;
                                end
                                else
                                begin
                                    Result := 0.044495275520274824;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.candidate_ranker_score <= 165786264.50000003 then
                        begin
                            if features.delta_local_lm_r0 <= -2211.4999999999995 then
                            begin
                                Result := 0.0028296216689363343;
                            end
                            else
                            begin
                                Result := 0.046442887703232162;
                            end;
                        end
                        else
                        begin
                            Result := 0.066683446731270704;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.top_ranker_score <= -224645267.49999997 then
            begin
                Result := 0.01831538282027171;
            end
            else
            begin
                Result := 0.09167681169222501;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_5(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -272844600.99999994 then
        begin
            Result := -0.023100804929187271;
        end
        else
        begin
            Result := -0.010161112601947938;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -66428624.999999993 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.011740294531760278;
                end
                else
                begin
                    Result := 0.0069941736114066642;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.00082319066324679701;
                end
                else
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.036246226165337785;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                        begin
                            if features.delta_path_segments <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.022072956514950195;
                            end
                            else
                            begin
                                Result := -0.0012287703914472346;
                            end;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_support <= 904.50000000000011 then
                            begin
                                Result := 0.057302100570671921;
                            end
                            else
                            begin
                                Result := 0.0030383681436925436;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= 6483591.5000000009 then
            begin
                if features.top_ranker_score <= 59337433.500000007 then
                begin
                    Result := 0.020346219010148603;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= -1.4999999999999998 then
                    begin
                        Result := 0.010945720818299368;
                    end
                    else
                    begin
                        Result := 0.053413433694159851;
                    end;
                end;
            end
            else
            begin
                if features.difference_span_units <= 3.5000000000000004 then
                begin
                    Result := 0.080413898056297839;
                end
                else
                begin
                    Result := -0.0016565161582763875;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_6(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -272844600.99999994 then
        begin
            Result := -0.023033316362353107;
        end
        else
        begin
            Result := -0.010005590506438367;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -66428624.999999993 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.011582179459076461;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_support_min <= -183.49999999999997 then
                    begin
                        Result := 0.0138126782567539;
                    end
                    else
                    begin
                        Result := -0.0030946818853383926;
                    end;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.00080376116083729168;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -9446.4999999999982 then
                    begin
                        Result := 7.7028875223053938E-05;
                    end
                    else
                    begin
                        if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.03662078803925449;
                        end
                        else
                        begin
                            if features.ranker_score_gap <= -122124059.99999999 then
                            begin
                                Result := 0.011052034141556252;
                            end
                            else
                            begin
                                Result := 0.030167249166058951;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= 12371962.500000002 then
            begin
                if features.top_ranker_score <= 69943713.500000015 then
                begin
                    Result := 0.020764336233241008;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= -1.4999999999999998 then
                    begin
                        Result := 0.011585620690534133;
                    end
                    else
                    begin
                        Result := 0.051261410500266613;
                    end;
                end;
            end
            else
            begin
                if features.top_ranker_score <= -190901634.99999997 then
                begin
                    Result := 0.0204251138428535;
                end
                else
                begin
                    Result := 0.079658036943957511;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_7(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -272844600.99999994 then
        begin
            Result := -0.022965042058783598;
        end
        else
        begin
            Result := -0.0098510263928943999;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -66428624.999999993 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.011424630971585114;
                end
                else
                begin
                    Result := 0.0065648685738609481;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.00078477895599714383;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -1255.4999999999998 then
                    begin
                        if features.different_units <= 1.5000000000000002 then
                        begin
                            Result := 0.020313217735911018;
                        end
                        else
                        begin
                            Result := -0.010934873390422645;
                        end;
                    end
                    else
                    begin
                        if features.delta_source_rule_fallback <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.022490203740335418;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                            begin
                                Result := 0.0052535484898490019;
                            end
                            else
                            begin
                                Result := 0.042938221283416511;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= 6483591.5000000009 then
            begin
                if features.top_ranker_score <= 59337433.500000007 then
                begin
                    Result := 0.018599300437723006;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= -1.4999999999999998 then
                    begin
                        Result := 0.010213734433078769;
                    end
                    else
                    begin
                        Result := 0.04613257139951793;
                    end;
                end;
            end
            else
            begin
                if features.difference_span_units <= 3.5000000000000004 then
                begin
                    Result := 0.067190020672780557;
                end
                else
                begin
                    Result := -0.0021974564016102849;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_8(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -259.49999999999994 then
    begin
        if features.delta_char_lm_score <= -692.49999999999989 then
        begin
            Result := -0.020008350348792052;
        end
        else
        begin
            if features.delta_candidate_score <= -1.0000000180025095E-35 then
            begin
                Result := -0.014720585966399677;
            end
            else
            begin
                if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
                begin
                    if features.delta_complete_pool_consensus_unanimous_units <= -1.0000000180025095E-35 then
                    begin
                        Result := -0.015085309890618199;
                    end
                    else
                    begin
                        Result := 0.014755622379049461;
                    end;
                end
                else
                begin
                    Result := -0.0089361857150163648;
                end;
            end;
        end;
    end
    else
    begin
        if features.baseline_abstain_score <= -3151780.9999999995 then
        begin
            if features.candidate_ranker_score <= -153101572.49999997 then
            begin
                Result := 0.0085558910076543159;
            end
            else
            begin
                Result := 0.060517357747159932;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -37322218.999999993 then
            begin
                Result := 0.00069386754044468404;
            end
            else
            begin
                if features.delta_chain_score_gap <= -59511678.999999993 then
                begin
                    Result := 0.0062516740330435987;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -1255.4999999999998 then
                    begin
                        Result := 0.016420926860196663;
                    end
                    else
                    begin
                        if features.delta_char_lm_score <= -61.499999999999993 then
                        begin
                            if features.delta_local_lm_r2 <= -99.499999999999986 then
                            begin
                                Result := 0.027703339294203596;
                            end
                            else
                            begin
                                Result := -0.00058681152730442573;
                            end;
                        end
                        else
                        begin
                            if features.candidate_ranker_score <= 107133954.50000001 then
                            begin
                                Result := 0.024993264402027704;
                            end
                            else
                            begin
                                if features.delta_local_lm_r0 <= 1913.5000000000002 then
                                begin
                                    Result := 0.051701031758730122;
                                end
                                else
                                begin
                                    Result := 0.018984886892155592;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_9(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -272844600.99999994 then
        begin
            Result := -0.022842881168032521;
        end
        else
        begin
            Result := -0.009613448385529905;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -66428624.999999993 then
        begin
            if features.delta_char_lm_score <= -259.49999999999994 then
            begin
                if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                begin
                    Result := -0.012245640007476612;
                end
                else
                begin
                    Result := 0.006810542055580804;
                end;
            end
            else
            begin
                if features.candidate_ranker_score <= -112314564.49999999 then
                begin
                    Result := -0.002767945301178481;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -1255.4999999999998 then
                    begin
                        if features.different_units <= 1.5000000000000002 then
                        begin
                            Result := 0.01822897598097897;
                        end
                        else
                        begin
                            Result := -0.011815522847330416;
                        end;
                    end
                    else
                    begin
                        if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.0;
                        end
                        else
                        begin
                            if features.candidate_chain_score_gap <= -56553520.999999993 then
                            begin
                                Result := 0.013746779677956908;
                            end
                            else
                            begin
                                if features.difference_span_units <= 2.5000000000000004 then
                                begin
                                    Result := 0.035298365807857328;
                                end
                                else
                                begin
                                    Result := -0.008419075805057746;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= 12371962.500000002 then
            begin
                if features.top_ranker_score <= 69943713.500000015 then
                begin
                    Result := 0.018376219339798827;
                end
                else
                begin
                    if features.delta_complete_pool_seed_rank <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.0069794438930735492;
                    end
                    else
                    begin
                        Result := 0.042375527563684824;
                    end;
                end;
            end
            else
            begin
                Result := 0.057354519092514912;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_10(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -272844600.99999994 then
        begin
            Result := -0.022772315977305321;
        end
        else
        begin
            Result := -0.0094614859667218956;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -77915697.999999985 then
        begin
            if features.candidate_char_lm_suffix_score <= -5856.4999999999991 then
            begin
                if features.delta_complete_pool_consensus_support_min <= -126.49999999999999 then
                begin
                    if features.candidate_ranker_score <= -214297594.49999997 then
                    begin
                        Result := -0.010191561178378904;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -6066.4999999999991 then
                        begin
                            Result := 0.0092014269689446697;
                        end
                        else
                        begin
                            if features.top_local_lm_r1 <= -6708.4999999999991 then
                            begin
                                if features.same_prefix_units <= 4.5000000000000009 then
                                begin
                                    Result := 0.07487547948994927;
                                end
                                else
                                begin
                                    Result := 0.018485203663468466;
                                end;
                            end
                            else
                            begin
                                Result := 0.00088466811942029475;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0087243505366380158;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.0010216864506606897;
                end
                else
                begin
                    Result := 0.022957236062955692;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= -4991225.9999999991 then
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
                begin
                    Result := 0.0048297380700800356;
                end
                else
                begin
                    if features.top_ranker_score <= -116872239.49999999 then
                    begin
                        Result := 0.00054855795021913414;
                    end
                    else
                    begin
                        Result := 0.033587607117687761;
                    end;
                end;
            end
            else
            begin
                if features.candidate_word_lm_bonus <= 369.50000000000006 then
                begin
                    Result := 0.042473110250655401;
                end
                else
                begin
                    Result := 0.083536109068754735;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_11(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -272844600.99999994 then
        begin
            Result := -0.022700877127686037;
        end
        else
        begin
            Result := -0.0093106052505169332;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -77915697.999999985 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                Result := 0.00024040463905421034;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.0014074525819128558;
                end
                else
                begin
                    if features.candidate_word_lm_supported_ratio <= 151.50000000000003 then
                    begin
                        if features.top_local_lm_r1 <= -4324.4999999999991 then
                        begin
                            if features.candidate_complete_pool_pair_evidence <= 1129.5000000000002 then
                            begin
                                Result := 0.025728344661449257;
                            end
                            else
                            begin
                                Result := 0.050182682155975725;
                            end;
                        end
                        else
                        begin
                            Result := 0.0019459331226704579;
                        end;
                    end
                    else
                    begin
                        Result := 0.015046050334777711;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := 0.0088588629166498501;
            end
            else
            begin
                if features.candidate_complete_pool_pair_evidence <= 1207.5000000000002 then
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        if features.top_local_lm_r2 <= -7323.4999999999991 then
                        begin
                            Result := 0.01581281943308252;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= 177.50000000000003 then
                            begin
                                Result := 0.024822211515084097;
                            end
                            else
                            begin
                                Result := 0.066145359052630665;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.045088855956949281;
                    end;
                end
                else
                begin
                    if features.candidate_word_lm_zero_count <= 8.5000000000000018 then
                    begin
                        Result := 0.051394486048293421;
                    end
                    else
                    begin
                        Result := 0.011289859947326564;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_12(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.023311233458781527;
        end
        else
        begin
            Result := -0.010322795745343224;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -77915697.999999985 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                Result := 0.00023438740890848839;
            end
            else
            begin
                if features.delta_complete_pool_consensus_support_min <= -25.499999999999996 then
                begin
                    if features.delta_complete_pool_signature_support <= -28.499999999999996 then
                    begin
                        Result := -0.0061225154169549751;
                    end
                    else
                    begin
                        if features.delta_candidate_score <= -815.49999999999989 then
                        begin
                            Result := 0.010164662961818326;
                        end
                        else
                        begin
                            if features.top_local_lm_r1 <= -4542.4999999999991 then
                            begin
                                Result := 0.027729436522263132;
                            end
                            else
                            begin
                                Result := 0.0067660258819026058;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.00064412012779124144;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -192673874.99999997 then
            begin
                Result := 2.440955213083174E-05;
            end
            else
            begin
                if features.ranker_score_gap <= -4991225.9999999991 then
                begin
                    if features.delta_complete_pool_consensus_mean_distance <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.0054114864017564858;
                    end
                    else
                    begin
                        if features.delta_local_lm_r0 <= -2211.4999999999995 then
                        begin
                            if features.top_local_lm_r1 <= -8524.4999999999982 then
                            begin
                                Result := -0.010191292348623321;
                            end
                            else
                            begin
                                Result := 0.025964436659075652;
                            end;
                        end
                        else
                        begin
                            Result := 0.032304636470799265;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_word_lm_bonus <= 369.50000000000006 then
                    begin
                        Result := 0.040194100037736213;
                    end
                    else
                    begin
                        Result := 0.074737174271582579;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_13(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.023251233222839736;
        end
        else
        begin
            Result := -0.010166682998220152;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -105509623.49999999 then
        begin
            if features.delta_source_rule_fallback <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r0 <= -6124.4999999999991 then
                begin
                    Result := -0.0018260608398491069;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8683.4999999999982 then
                    begin
                        if features.same_prefix_units <= 4.5000000000000009 then
                        begin
                            Result := 0.079917162829315991;
                        end
                        else
                        begin
                            Result := -0.0025476220166317435;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= -428.83333333333331 then
                        begin
                            Result := -0.016398451479768195;
                        end
                        else
                        begin
                            Result := 0.013195539342756616;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.018047556058678922;
            end;
        end
        else
        begin
            if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
            begin
                Result := 0.0015318461434403435;
            end
            else
            begin
                if features.candidate_ranker_score <= -340253907.49999994 then
                begin
                    Result := -0.0091575632929993753;
                end
                else
                begin
                    if features.ranker_score_gap <= 6483591.5000000009 then
                    begin
                        if features.candidate_ranker_score <= 102045798.00000001 then
                        begin
                            if features.delta_score_per_unit <= 21.500000000000004 then
                            begin
                                Result := 0.017053423205425328;
                            end
                            else
                            begin
                                if features.delta_char_lm_score <= -113.49999999999999 then
                                begin
                                    Result := 0.075982495339728243;
                                end
                                else
                                begin
                                    Result := 0.012678806635447171;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.032813997092977963;
                        end;
                    end
                    else
                    begin
                        Result := 0.044537188502628708;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_14(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -180752811.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.023190495109599484;
        end
        else
        begin
            Result := -0.010011469868856149;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -66428624.999999993 then
        begin
            if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
            begin
                Result := -0.010563024768195343;
            end
            else
            begin
                if features.candidate_ranker_score <= -118248278.99999999 then
                begin
                    Result := -0.0037754879099165528;
                end
                else
                begin
                    if features.ranker_score_gap <= -117092734.49999999 then
                    begin
                        if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.018575854940348101;
                        end
                        else
                        begin
                            Result := 0.0029445960547803476;
                        end;
                    end
                    else
                    begin
                        if features.delta_score_per_unit <= 14.500000000000002 then
                        begin
                            if features.delta_dict_weight_per_unit <= -11618.499999999998 then
                            begin
                                Result := 0.03323484156892146;
                            end
                            else
                            begin
                                Result := 0.015219908349579803;
                            end;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_support <= 861.50000000000011 then
                            begin
                                if features.delta_local_lm_r3 <= -47.499999999999993 then
                                begin
                                    Result := 0.089163586815362073;
                                end
                                else
                                begin
                                    Result := 0.014024969649522524;
                                end;
                            end
                            else
                            begin
                                Result := 0.016060116775072041;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -153101572.49999997 then
            begin
                Result := 0.0045880360191924889;
            end
            else
            begin
                if features.ranker_score_gap <= -4991225.9999999991 then
                begin
                    if features.delta_complete_pool_consensus_mean_distance <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.005750067074700241;
                    end
                    else
                    begin
                        Result := 0.028023748560901326;
                    end;
                end
                else
                begin
                    Result := 0.041463857233787885;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_15(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -187996593.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.023128993880837782;
        end
        else
        begin
            Result := -0.010543389821438339;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -110149538.99999999 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                Result := -0.0035838663556069456;
            end
            else
            begin
                if features.delta_complete_pool_consensus_support_min <= -25.499999999999996 then
                begin
                    if features.delta_word_lm_boundary_count <= 2.5000000000000004 then
                    begin
                        if features.top_local_lm_r1 <= -4915.4999999999991 then
                        begin
                            Result := 0.014964796041045034;
                        end
                        else
                        begin
                            Result := -0.0030923648573474363;
                        end;
                    end
                    else
                    begin
                        Result := 0.02806591574380465;
                    end;
                end
                else
                begin
                    Result := -0.0061996658000334475;
                end;
            end;
        end
        else
        begin
            if features.delta_complete_pool_consensus_mean_distance <= 1.0000000180025095E-35 then
            begin
                Result := 0.0002806916441626353;
            end
            else
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.0016071243241336083;
                end
                else
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        if features.candidate_ranker_score <= 102045798.00000001 then
                        begin
                            if features.delta_score_per_unit <= 21.500000000000004 then
                            begin
                                Result := 0.016048871905906387;
                            end
                            else
                            begin
                                if features.delta_char_lm_score <= 135.50000000000003 then
                                begin
                                    if features.delta_candidate_score <= 32868.500000000007 then
                                    begin
                                        Result := 0.074181705031255721;
                                    end
                                    else
                                    begin
                                        Result := 0.017479954389302756;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0017255967762275809;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.029694566983117739;
                        end;
                    end
                    else
                    begin
                        Result := 0.041642160904784641;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_16(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -187996593.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.023066706394071851;
        end
        else
        begin
            Result := -0.01038638515773696;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -110149538.99999999 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                Result := -0.0035071802314172299;
            end
            else
            begin
                if features.delta_complete_pool_consensus_support_min <= -25.499999999999996 then
                begin
                    Result := 0.014119168456410073;
                end
                else
                begin
                    Result := -0.0060850721590911643;
                end;
            end;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := 0.0026949567126591367;
            end
            else
            begin
                if features.candidate_ranker_score <= -153101572.49999997 then
                begin
                    Result := 0.0024882607100107771;
                end
                else
                begin
                    if features.ranker_score_gap <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_score_per_unit <= 17.500000000000004 then
                        begin
                            if features.candidate_ranker_score <= 165786264.50000003 then
                            begin
                                Result := 0.016698360482072985;
                            end
                            else
                            begin
                                if features.delta_char_suffix_lm_per_difference <= -104.89999999999999 then
                                begin
                                    Result := 0.015018462286182028;
                                end
                                else
                                begin
                                    Result := 0.03349155875235809;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_char_lm_suffix_score <= -135.49999999999997 then
                            begin
                                if features.top_local_lm_r0 <= -5596.4999999999991 then
                                begin
                                    Result := 0.086307867322639995;
                                end
                                else
                                begin
                                    Result := 0.018341883814367681;
                                end;
                            end
                            else
                            begin
                                Result := 0.022068358181245636;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                        begin
                            Result := 0.049910241993019855;
                        end
                        else
                        begin
                            Result := 0.028170634228649474;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_17(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -187996593.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.023003610165661187;
        end
        else
        begin
            Result := -0.010230216136105662;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -84935356.999999985 then
        begin
            if features.delta_complete_pool_consensus_support_min <= 163.50000000000003 then
            begin
                if features.candidate_ranker_score <= -118248278.99999999 then
                begin
                    Result := -0.0055258029138250597;
                end
                else
                begin
                    if features.ranker_score_gap <= -117092734.49999999 then
                    begin
                        if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
                        begin
                            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                            begin
                                Result := -0.006345831973240461;
                            end
                            else
                            begin
                                Result := 0.017749031842635789;
                            end;
                        end
                        else
                        begin
                            Result := 0.0032309462265644423;
                        end;
                    end
                    else
                    begin
                        Result := 0.019569039835217277;
                    end;
                end;
            end
            else
            begin
                Result := -0.010473864337830117;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 57902221.000000007 then
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
                begin
                    Result := -0.006642398777789992;
                end
                else
                begin
                    if features.candidate_ranker_score <= -373347557.99999994 then
                    begin
                        Result := -0.010423625707057257;
                    end
                    else
                    begin
                        Result := 0.01970136954645646;
                    end;
                end;
            end
            else
            begin
                if features.ranker_score_gap <= -23397226.499999996 then
                begin
                    if features.delta_char_suffix_lm_per_difference <= -261.83333333333331 then
                    begin
                        Result := 0.0058634468741168705;
                    end
                    else
                    begin
                        if features.delta_local_lm_r0 <= -1649.4999999999998 then
                        begin
                            Result := 0.01041721572749011;
                        end
                        else
                        begin
                            Result := 0.030447560305696314;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.040408988276007113;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_18(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -403.49999999999994 then
    begin
        if features.delta_candidate_score <= -1.0000000180025095E-35 then
        begin
            Result := -0.020878365336138419;
        end
        else
        begin
            if features.top_local_lm_r1 <= -6350.4999999999991 then
            begin
                if features.candidate_ranker_score <= 111801836.50000001 then
                begin
                    Result := -0.004269838235554377;
                end
                else
                begin
                    Result := 0.014839999034140542;
                end;
            end
            else
            begin
                Result := -0.016355608475462878;
            end;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -118248278.99999999 then
        begin
            Result := -0.0036489399145583669;
        end
        else
        begin
            if features.delta_char_lm_score <= -61.499999999999993 then
            begin
                if features.delta_word_lm_bonus <= -26.499999999999996 then
                begin
                    if features.candidate_word_lm_boundary_max <= 1147.5000000000002 then
                    begin
                        Result := 0.011522225847009583;
                    end
                    else
                    begin
                        Result := -0.0096112955795399895;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                    begin
                        Result := 0.0088114529064014097;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                        begin
                            Result := 0.073292734302065662;
                        end
                        else
                        begin
                            Result := 0.021551731428210055;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.top_local_lm_r2 <= -5644.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_char_suffix_lm_per_difference <= 106.25000000000001 then
                        begin
                            Result := 0.017007600939813721;
                        end
                        else
                        begin
                            Result := 0.031658739882873765;
                        end;
                    end
                    else
                    begin
                        Result := 0.011405806450637287;
                    end;
                end
                else
                begin
                    if features.candidate_char_lm_score <= -3716.4999999999995 then
                    begin
                        Result := 0.024197980730566917;
                    end
                    else
                    begin
                        Result := 0.052011535033179214;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_19(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -187996593.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.022890992042758306;
        end
        else
        begin
            Result := -0.009975785662800378;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -84935356.999999985 then
        begin
            if features.delta_char_lm_score <= -458.49999999999994 then
            begin
                Result := -0.0039675818203702704;
            end
            else
            begin
                if features.candidate_char_lm_score <= -5889.4999999999991 then
                begin
                    Result := -0.0032795910780899448;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -6201.4999999999991 then
                    begin
                        if features.different_units <= 1.5000000000000002 then
                        begin
                            Result := 0.012788971098471472;
                        end
                        else
                        begin
                            Result := -0.0032576651850644727;
                        end;
                    end
                    else
                    begin
                        if features.candidate_path_segments <= 1.5000000000000002 then
                        begin
                            Result := 0.065045733575952572;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_support <= 902.50000000000011 then
                            begin
                                if features.top_local_lm_r1 <= -4915.4999999999991 then
                                begin
                                    Result := 0.027019923010145594;
                                end
                                else
                                begin
                                    Result := 0.0037798915404035614;
                                end;
                            end
                            else
                            begin
                                Result := 0.0004757505042557275;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := 0.005330389610143503;
            end
            else
            begin
                if features.candidate_complete_pool_pair_evidence <= 1207.5000000000002 then
                begin
                    if features.delta_dict_weight_per_unit <= -3331.4999999999995 then
                    begin
                        if features.top_local_lm_r2 <= -7323.4999999999991 then
                        begin
                            Result := 0.019387634548336297;
                        end
                        else
                        begin
                            Result := 0.036686080660276878;
                        end;
                    end
                    else
                    begin
                        Result := 0.012762943911671716;
                    end;
                end
                else
                begin
                    Result := 0.033204353149288671;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_20(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -187996593.49999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.022825550929012881;
        end
        else
        begin
            Result := -0.009822006913201925;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -110149538.99999999 then
        begin
            if features.candidate_char_lm_score <= -5237.4999999999991 then
            begin
                Result := -0.0033625511619029221;
            end
            else
            begin
                if features.delta_complete_pool_consensus_support_min <= -25.499999999999996 then
                begin
                    Result := 0.012319104482213517;
                end
                else
                begin
                    Result := -0.0060420479413124221;
                end;
            end;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := 0.0022108475220153521;
            end
            else
            begin
                if features.candidate_ranker_score <= -340253907.49999994 then
                begin
                    Result := -0.010134230304809679;
                end
                else
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        if features.delta_score_per_unit <= 14.500000000000002 then
                        begin
                            if features.delta_source_rule_fallback <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.01364417311908309;
                            end
                            else
                            begin
                                if features.delta_chain_second_stage_score <= 56269352.500000007 then
                                begin
                                    if features.delta_char_suffix_lm_per_difference <= -5.4166666666666652 then
                                    begin
                                        Result := 0.012277415619212225;
                                    end
                                    else
                                    begin
                                        if features.top_local_lm_r1 <= -7503.4999999999991 then
                                        begin
                                            Result := 0.023952384198670587;
                                        end
                                        else
                                        begin
                                            Result := 0.049405459311850058;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0071242139538842224;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_char_lm_suffix_score <= -135.49999999999997 then
                            begin
                                Result := 0.060643308092245329;
                            end
                            else
                            begin
                                Result := 0.019493419844114165;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.033251348142780406;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_21(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -300941054.49999994 then
        begin
            Result := -0.022908213950530693;
        end
        else
        begin
            Result := -0.012677042407331552;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.010640286996518349;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_mean_distance <= 2535.5000000000005 then
                    begin
                        Result := 0.017442272805121561;
                    end
                    else
                    begin
                        Result := 0.0013903654522738874;
                    end;
                end;
            end
            else
            begin
                Result := -0.002588013245436286;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -214297594.49999997 then
            begin
                Result := -0.0055392332373672736;
            end
            else
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= -1.0000000180025095E-35 then
                begin
                    Result := 0.00056949503554473626;
                end
                else
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        if features.delta_score_per_unit <= 14.500000000000002 then
                        begin
                            if features.candidate_ranker_score <= 159419056.50000003 then
                            begin
                                Result := 0.012984157019067489;
                            end
                            else
                            begin
                                if features.delta_char_suffix_lm_per_difference <= -104.89999999999999 then
                                begin
                                    Result := 0.010046871554964809;
                                end
                                else
                                begin
                                    Result := 0.02675894127429191;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_local_lm_r3 <= 184.50000000000003 then
                            begin
                                if features.delta_chain_second_stage_score <= 16222503.000000002 then
                                begin
                                    Result := 0.050086217995667752;
                                end
                                else
                                begin
                                    Result := 0.013874183139033042;
                                end;
                            end
                            else
                            begin
                                Result := 0.0041276151825951866;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.031732302861433734;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_22(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.023146314695356031;
        end
        else
        begin
            Result := -0.013037064220160093;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.010488276669554807;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_mean_distance <= 2535.5000000000005 then
                    begin
                        Result := 0.016736474126010491;
                    end
                    else
                    begin
                        if features.delta_char_suffix_lm_per_difference <= -96.749999999999986 then
                        begin
                            Result := -0.014989752211903318;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -6597.4999999999991 then
                            begin
                                Result := 0.00094943398357289768;
                            end
                            else
                            begin
                                Result := 0.042922454241438091;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_chain_score_gap <= -191740645.49999997 then
                begin
                    Result := 0.041192975561858775;
                end
                else
                begin
                    Result := -0.0033277858917799587;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -214297594.49999997 then
            begin
                Result := -0.0054333631634781174;
            end
            else
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= -1.0000000180025095E-35 then
                begin
                    Result := 0.00055536565477817997;
                end
                else
                begin
                    if features.ranker_score_gap <= 1.0000000180025095E-35 then
                    begin
                        if features.candidate_ranker_score <= 165786264.50000003 then
                        begin
                            if features.candidate_complete_pool_signature_support <= 18.500000000000004 then
                            begin
                                Result := 0.016073697496279793;
                            end
                            else
                            begin
                                Result := 0.0022428724560049382;
                            end;
                        end
                        else
                        begin
                            Result := 0.022923832578791652;
                        end;
                    end
                    else
                    begin
                        Result := 0.028692783354294905;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_23(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -300941054.49999994 then
        begin
            Result := -0.022779449169930348;
        end
        else
        begin
            Result := -0.012346305611019353;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.010337123383941816;
                end
                else
                begin
                    Result := 0.012104382779943782;
                end;
            end
            else
            begin
                Result := -0.0024674341298859801;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -153101572.49999997 then
            begin
                Result := -0.001465797978487178;
            end
            else
            begin
                if features.delta_char_suffix_lm_per_difference <= -261.83333333333331 then
                begin
                    Result := 0.005615159943641976;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -5596.4999999999991 then
                    begin
                        if features.delta_complete_pool_consensus_nearest_distance <= -1.0000000180025095E-35 then
                        begin
                            Result := -0.0053488918526752053;
                        end
                        else
                        begin
                            Result := 0.018196033424805792;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r0 <= 2033.0000000000002 then
                        begin
                            if features.delta_local_lm_r0 <= 567.50000000000011 then
                            begin
                                Result := 0.01101859081258753;
                            end
                            else
                            begin
                                if features.candidate_candidate_score <= 171529.00000000003 then
                                begin
                                    if features.top_local_lm_r0 <= -6478.4999999999991 then
                                    begin
                                        Result := 0.013705135600182498;
                                    end
                                    else
                                    begin
                                        if features.delta_complete_pool_signature_support <= -32.499999999999993 then
                                        begin
                                            Result := 0.0035140386598500706;
                                        end
                                        else
                                        begin
                                            Result := 0.10222694558197205;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.015886252741897363;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.017868351507090208;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_24(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.023027812392469104;
        end
        else
        begin
            Result := -0.012706868825062612;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -110149538.99999999 then
        begin
            if features.candidate_char_lm_score <= -5343.4999999999991 then
            begin
                Result := -0.0047443690954130056;
            end
            else
            begin
                if features.delta_complete_pool_consensus_support <= -10.499999999999998 then
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.delta_word_lm_boundary_count <= 2.5000000000000004 then
                        begin
                            Result := 0.0064108897541133763;
                        end
                        else
                        begin
                            Result := 0.020853209350058952;
                        end;
                    end
                    else
                    begin
                        Result := 0.048687377517507735;
                    end;
                end
                else
                begin
                    Result := -0.0058629275232604076;
                end;
            end;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := 0.0016724273506757261;
            end
            else
            begin
                if features.top_ranker_score <= -320529509.49999994 then
                begin
                    Result := -0.0087141813947565171;
                end
                else
                begin
                    if features.ranker_score_gap <= -27341488.499999996 then
                    begin
                        if features.delta_candidate_score <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.013440680456434043;
                        end
                        else
                        begin
                            if features.delta_local_lm_r2 <= -61.499999999999993 then
                            begin
                                if features.candidate_score_per_unit <= 10516.500000000002 then
                                begin
                                    Result := 0.021108211765744983;
                                end
                                else
                                begin
                                    Result := 0.059209084472989428;
                                end;
                            end
                            else
                            begin
                                Result := 0.0074987752709867938;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 105286934.50000001 then
                        begin
                            Result := 0.019917504122239249;
                        end
                        else
                        begin
                            Result := 0.036158292591827415;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_25(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -458.49999999999994 then
    begin
        if features.delta_candidate_score <= -1.0000000180025095E-35 then
        begin
            Result := -0.020674478942531091;
        end
        else
        begin
            if features.top_local_lm_r1 <= -6510.4999999999991 then
            begin
                Result := 0.0011224861373746193;
            end
            else
            begin
                Result := -0.016103068231651422;
            end;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -118248278.99999999 then
        begin
            Result := -0.0043642112214458597;
        end
        else
        begin
            if features.delta_char_lm_score <= -61.499999999999993 then
            begin
                if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                begin
                    if features.same_suffix_units <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r3 <= -1145.4999999999998 then
                        begin
                            Result := 0.045249078993581451;
                        end
                        else
                        begin
                            Result := -0.0061896254057100704;
                        end;
                    end
                    else
                    begin
                        Result := 0.015372680850360185;
                    end;
                end
                else
                begin
                    if features.candidate_word_lm_boundary_max <= 1159.5000000000002 then
                    begin
                        Result := 0.0055915637018748889;
                    end
                    else
                    begin
                        Result := -0.011037701388193516;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -6101.4999999999991 then
                begin
                    if features.baseline_abstain_score <= -989920.99999999988 then
                    begin
                        Result := 0.024760312168600616;
                    end
                    else
                    begin
                        Result := 0.010642718319095947;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -210.49999999999997 then
                    begin
                        if features.top_local_lm_r1 <= -4542.4999999999991 then
                        begin
                            Result := 0.024100765305554307;
                        end
                        else
                        begin
                            Result := -0.0065239079334863427;
                        end;
                    end
                    else
                    begin
                        if features.delta_candidate_score <= -101670.99999999999 then
                        begin
                            Result := 0.088543203925292746;
                        end
                        else
                        begin
                            Result := 0.029521353752751368;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_26(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022920719913505444;
        end
        else
        begin
            Result := -0.012441983807153154;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.candidate_dict_weight <= 31305.000000000004 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.0096963340437271183;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -8749.9999999999982 then
                    begin
                        Result := -0.0041473568669002535;
                    end
                    else
                    begin
                        Result := 0.012747172086359594;
                    end;
                end;
            end
            else
            begin
                Result := -0.0030754360089178907;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -214297594.49999997 then
            begin
                Result := -0.0052680438862163087;
            end
            else
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= -1.0000000180025095E-35 then
                begin
                    Result := 0.00052063818852566049;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -6066.4999999999991 then
                    begin
                        if features.top_local_lm_r1 <= -4839.4999999999991 then
                        begin
                            if features.candidate_complete_pool_signature_support <= 31.500000000000004 then
                            begin
                                if features.baseline_abstain_score <= -4917348.9999999991 then
                                begin
                                    if features.candidate_path_max_segment_units <= 2.5000000000000004 then
                                    begin
                                        Result := 0.022573406397717131;
                                    end
                                    else
                                    begin
                                        Result := 0.060160149375524212;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.014576225659940484;
                                end;
                            end
                            else
                            begin
                                Result := 0.00010659859764077201;
                            end;
                        end
                        else
                        begin
                            Result := 0.0010607968025278299;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r1 <= -8780.4999999999982 then
                        begin
                            Result := 0.049631728021586718;
                        end
                        else
                        begin
                            Result := 0.020950682989976703;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_27(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022858299389981147;
        end
        else
        begin
            Result := -0.012280472491440863;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.delta_dict_weight <= 37922.000000000007 then
            begin
                if features.candidate_local_lm_r0 <= -6124.4999999999991 then
                begin
                    if features.candidate_score_per_unit <= 10607.500000000002 then
                    begin
                        Result := -0.00323437510064466;
                    end
                    else
                    begin
                        Result := 0.0090585615133795868;
                    end;
                end
                else
                begin
                    Result := 0.012507569848231613;
                end;
            end
            else
            begin
                Result := -0.0083614000603640191;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -214297594.49999997 then
            begin
                Result := -0.0051661269469035773;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5375.4999999999991 then
                begin
                    if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.0005310750045597355;
                    end
                    else
                    begin
                        if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.019402859793226958;
                        end
                        else
                        begin
                            if features.delta_candidate_score <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.0085221356847327897;
                            end
                            else
                            begin
                                if features.candidate_word_lm_boundary_count <= 4.5000000000000009 then
                                begin
                                    Result := 0.040476110930727657;
                                end
                                else
                                begin
                                    Result := 0.0099527653185891626;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                    begin
                        Result := 0.045090282162935549;
                    end
                    else
                    begin
                        if features.delta_dict_weight <= 42199.500000000007 then
                        begin
                            Result := 0.030491216593509909;
                        end
                        else
                        begin
                            Result := -0.0024651691482092961;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_28(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022794977854277955;
        end
        else
        begin
            Result := -0.012119228882546525;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -63822726.499999993 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.0095901213694754486;
            end
            else
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.012009445678229279;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.ranker_score_gap <= -154834619.99999997 then
                        begin
                            if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.0086183989275371471;
                            end
                            else
                            begin
                                Result := -0.0045100410203359285;
                            end;
                        end
                        else
                        begin
                            Result := 0.010678135394525492;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 8.1250000000000018 then
                        begin
                            Result := 0.081340053179066313;
                        end
                        else
                        begin
                            Result := 0.0035820863351646113;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_local_lm_r0 <= -5295.4999999999991 then
            begin
                if features.top_local_lm_r1 <= -5676.4999999999991 then
                begin
                    if features.candidate_complete_pool_pair_evidence <= 1.0000000180025095E-35 then
                    begin
                        if features.candidate_complete_pool_signature_support <= 9.5000000000000018 then
                        begin
                            Result := 0.017096832946556274;
                        end
                        else
                        begin
                            Result := 0.0038673327562586501;
                        end;
                    end
                    else
                    begin
                        Result := 0.026991548151902151;
                    end;
                end
                else
                begin
                    Result := 0.00040100086954190277;
                end;
            end
            else
            begin
                if features.delta_word_lm_boundary_max <= 1276.5000000000002 then
                begin
                    Result := 0.039790696833724826;
                end
                else
                begin
                    Result := 0.003335969237335595;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_29(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -458.49999999999994 then
    begin
        if features.delta_candidate_score <= -1.0000000180025095E-35 then
        begin
            Result := -0.020291688847151268;
        end
        else
        begin
            if features.top_local_lm_r1 <= -6350.4999999999991 then
            begin
                Result := 0.00071801575868859818;
            end
            else
            begin
                Result := -0.016277614894375455;
            end;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 32608620.500000004 then
        begin
            if features.candidate_ranker_score <= -214297594.49999997 then
            begin
                Result := -0.0098530953461075585;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -6015.4999999999991 then
                begin
                    if features.baseline_abstain_score <= -3151780.9999999995 then
                    begin
                        Result := 0.015421412102366854;
                    end
                    else
                    begin
                        Result := -0.0012822882939607543;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_majority_units <= 8.5000000000000018 then
                    begin
                        Result := 0.031220973350228661;
                    end
                    else
                    begin
                        Result := 0.0030899117462871075;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_char_lm_per_difference <= 73.125000000000014 then
            begin
                if features.delta_score_per_unit <= -29.499999999999996 then
                begin
                    if features.delta_word_lm_boundary_count <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.009790009171779206;
                    end
                    else
                    begin
                        Result := -0.012134792366024964;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8622.4999999999982 then
                    begin
                        Result := 0.023436835410140855;
                    end
                    else
                    begin
                        Result := 0.0094001336443565314;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -2001.4999999999998 then
                begin
                    Result := 0.0036607860736147268;
                end
                else
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.029942829893365986;
                    end
                    else
                    begin
                        Result := 0.011557157794428147;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_30(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022683525383257248;
        end
        else
        begin
            Result := -0.011857889370896782;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -110149538.99999999 then
        begin
            if features.candidate_local_lm_r0 <= -6124.4999999999991 then
            begin
                if features.candidate_char_lm_score <= -5154.4999999999991 then
                begin
                    Result := -0.0065903249704738921;
                end
                else
                begin
                    Result := 0.003709298630612954;
                end;
            end
            else
            begin
                if features.same_prefix_units <= 4.5000000000000009 then
                begin
                    if features.candidate_local_lm_r1 <= -8655.4999999999982 then
                    begin
                        if features.ranker_score_gap <= -199418752.99999997 then
                        begin
                            Result := -0.0010036647895937992;
                        end
                        else
                        begin
                            Result := 0.063803413430525188;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -1136.4999999999998 then
                        begin
                            Result := -0.010682278379746874;
                        end
                        else
                        begin
                            Result := 0.017071593932063606;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0016294477067505487;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 102045798.00000001 then
            begin
                if features.delta_complete_pool_consensus_mean_distance <= 1.0000000180025095E-35 then
                begin
                    Result := -0.0075092466290056087;
                end
                else
                begin
                    if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                    begin
                        Result := 0.015027315125711533;
                    end
                    else
                    begin
                        if features.delta_word_lm_zero_count <= 2.5000000000000004 then
                        begin
                            Result := -0.00047149389009015969;
                        end
                        else
                        begin
                            Result := 0.015056738615642055;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.ranker_score_gap <= -27341488.499999996 then
                begin
                    Result := 0.014465912113038604;
                end
                else
                begin
                    Result := 0.027259001961744519;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_31(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -458.49999999999994 then
    begin
        if features.delta_candidate_score <= -1.0000000180025095E-35 then
        begin
            Result := -0.020088133835899816;
        end
        else
        begin
            if features.top_local_lm_r1 <= -6510.4999999999991 then
            begin
                if features.candidate_text_units <= 8.5000000000000018 then
                begin
                    if features.delta_local_lm_r1 <= -468.49999999999994 then
                    begin
                        Result := 0.0039707877665595441;
                    end
                    else
                    begin
                        Result := 0.031690444339719299;
                    end;
                end
                else
                begin
                    Result := -0.0075919626079340649;
                end;
            end
            else
            begin
                Result := -0.015408898155852772;
            end;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 32608620.500000004 then
        begin
            if features.candidate_ranker_score <= -214297594.49999997 then
            begin
                Result := -0.0096708163921430217;
            end
            else
            begin
                if features.top_ranker_score <= 43198292.000000007 then
                begin
                    Result := 0.010938070747419841;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                    begin
                        Result := -0.0076996547963147435;
                    end
                    else
                    begin
                        Result := 0.0098030599484851613;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_char_lm_score <= -70.499999999999986 then
            begin
                if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                begin
                    if features.same_suffix_units <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.0036469400397033109;
                    end
                    else
                    begin
                        Result := 0.0152946884267686;
                    end;
                end
                else
                begin
                    if features.candidate_word_lm_boundary_max <= 1159.5000000000002 then
                    begin
                        Result := 0.008987354912908729;
                    end
                    else
                    begin
                        Result := -0.0098146040319103955;
                    end;
                end;
            end
            else
            begin
                if features.top_local_lm_r2 <= -5697.4999999999991 then
                begin
                    Result := 0.012745182127555089;
                end
                else
                begin
                    Result := 0.024787182427279741;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_32(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022568382525469211;
        end
        else
        begin
            Result := -0.011581419439736963;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -63822726.499999993 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.0093811313449696995;
            end
            else
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.01157096021618936;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.ranker_score_gap <= -154834619.99999997 then
                        begin
                            if features.candidate_complete_dictionary <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.0078920714253665047;
                            end
                            else
                            begin
                                if features.delta_chain_score_gap <= -191740645.49999997 then
                                begin
                                    Result := 0.034351549577208977;
                                end
                                else
                                begin
                                    Result := -0.0058451093111729618;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.difference_span_units <= 3.5000000000000004 then
                            begin
                                Result := 0.0099006399153398674;
                            end
                            else
                            begin
                                Result := -0.017876571409961791;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 8.1250000000000018 then
                        begin
                            Result := 0.073688987535680678;
                        end
                        else
                        begin
                            Result := 0.0027450090911186678;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_complete_pool_pair_evidence <= 1.0000000180025095E-35 then
            begin
                Result := 0.011700369176779427;
            end
            else
            begin
                if features.top_local_lm_r1 <= -5676.4999999999991 then
                begin
                    if features.candidate_word_lm_zero_count <= 8.5000000000000018 then
                    begin
                        Result := 0.027390299275146052;
                    end
                    else
                    begin
                        Result := 0.00096404011408262723;
                    end;
                end
                else
                begin
                    Result := 0.005753972538469149;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_33(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022500783081259648;
        end
        else
        begin
            Result := -0.011421853663509868;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -84935356.999999985 then
        begin
            if features.delta_complete_pool_consensus_support_min <= -89.499999999999986 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.011717436719578466;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.delta_candidate_score <= -8516.4999999999982 then
                        begin
                            if features.candidate_local_lm_r1 <= -6365.4999999999991 then
                            begin
                                Result := -0.0052119131041545377;
                            end
                            else
                            begin
                                if features.delta_char_suffix_lm_per_difference <= 87.166666666666671 then
                                begin
                                    Result := 0.0054686995022669785;
                                end
                                else
                                begin
                                    Result := 0.070982589423978726;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.top_local_lm_r1 <= -4542.4999999999991 then
                            begin
                                Result := 0.010747357811570234;
                            end
                            else
                            begin
                                Result := -0.0043496706866611948;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 110.25000000000001 then
                        begin
                            if features.top_local_lm_r0 <= -6066.4999999999991 then
                            begin
                                Result := 0.081188540629566208;
                            end
                            else
                            begin
                                Result := 0.0029073872308865685;
                            end;
                        end
                        else
                        begin
                            Result := -0.0062831980750956695;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.005808801386409883;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 57902221.000000007 then
            begin
                Result := 0.0082595580862224929;
            end
            else
            begin
                if features.ranker_score_gap <= -27341488.499999996 then
                begin
                    Result := 0.012825356824480647;
                end
                else
                begin
                    Result := 0.023410313495280166;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_34(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022432171747605659;
        end
        else
        begin
            Result := -0.01126279531184045;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.delta_dict_weight <= 37922.000000000007 then
            begin
                if features.candidate_local_lm_r0 <= -6124.4999999999991 then
                begin
                    if features.candidate_score_per_unit <= 10607.500000000002 then
                    begin
                        Result := -0.0032817684785610654;
                    end
                    else
                    begin
                        Result := 0.0078936400420330684;
                    end;
                end
                else
                begin
                    if features.same_prefix_units <= 4.5000000000000009 then
                    begin
                        if features.top_local_lm_r1 <= -4915.4999999999991 then
                        begin
                            Result := 0.022551956579455523;
                        end
                        else
                        begin
                            Result := -0.0014635487113885512;
                        end;
                    end
                    else
                    begin
                        Result := -0.00034096117249469467;
                    end;
                end;
            end
            else
            begin
                Result := -0.0081143427071408147;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -340253907.49999994 then
            begin
                Result := -0.011337687750809998;
            end
            else
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= -1.0000000180025095E-35 then
                begin
                    Result := -0.00070403287148336003;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -6066.4999999999991 then
                    begin
                        if features.candidate_local_lm_r0 <= -6468.4999999999991 then
                        begin
                            Result := 0.012718376277729688;
                        end
                        else
                        begin
                            Result := 0.0038370845530507607;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r1 <= -8780.4999999999982 then
                        begin
                            if features.candidate_ranker_score <= -85906157.499999985 then
                            begin
                                Result := -0.009957841341750406;
                            end
                            else
                            begin
                                Result := 0.048217225491465371;
                            end;
                        end
                        else
                        begin
                            Result := 0.015866520292214272;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_35(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022362530232567863;
        end
        else
        begin
            Result := -0.011104287442658591;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -63822726.499999993 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.0092444700105480948;
            end
            else
            begin
                if features.candidate_char_lm_score <= -6789.4999999999991 then
                begin
                    Result := -0.012849124810843932;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.ranker_score_gap <= -154834619.99999997 then
                        begin
                            Result := 0.00036943717308250321;
                        end
                        else
                        begin
                            Result := 0.0085585618638339845;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 8.1250000000000018 then
                        begin
                            Result := 0.05763804593649402;
                        end
                        else
                        begin
                            Result := 0.0014800770575471387;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_local_lm_r0 <= -5295.4999999999991 then
            begin
                if features.top_local_lm_r1 <= -5676.4999999999991 then
                begin
                    if features.candidate_complete_pool_pair_evidence <= 1237.5000000000002 then
                    begin
                        Result := 0.010481558176753475;
                    end
                    else
                    begin
                        if features.candidate_path_single_segments <= 8.5000000000000018 then
                        begin
                            Result := 0.025646038407277961;
                        end
                        else
                        begin
                            Result := -0.007962468266401625;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.00094094161961959092;
                end;
            end
            else
            begin
                if features.delta_dict_weight <= 42199.500000000007 then
                begin
                    Result := 0.038000560634449926;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                    begin
                        Result := 0.04258126876063157;
                    end
                    else
                    begin
                        Result := -0.003212292717375359;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_36(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -295020042.99999994 then
        begin
            Result := -0.021726462323368539;
        end
        else
        begin
            Result := -0.010051385092471145;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.delta_dict_weight <= 37922.000000000007 then
            begin
                if features.candidate_local_lm_r0 <= -6124.4999999999991 then
                begin
                    if features.candidate_score_per_unit <= 8820.5000000000018 then
                    begin
                        Result := -0.0043623306583034432;
                    end
                    else
                    begin
                        Result := 0.0061439551175452543;
                    end;
                end
                else
                begin
                    if features.same_prefix_units <= 4.5000000000000009 then
                    begin
                        if features.top_local_lm_r1 <= -4915.4999999999991 then
                        begin
                            Result := 0.021346298077117753;
                        end
                        else
                        begin
                            Result := -0.0015474890830336735;
                        end;
                    end
                    else
                    begin
                        Result := -0.00043793584641402825;
                    end;
                end;
            end
            else
            begin
                Result := -0.008001553732306186;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -340253907.49999994 then
            begin
                Result := -0.011197994694833083;
            end
            else
            begin
                if features.ranker_score_gap <= -23397226.499999996 then
                begin
                    if features.delta_complete_pool_consensus_mean_distance <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.0042036133266068016;
                    end
                    else
                    begin
                        if features.delta_score_per_unit <= 14.500000000000002 then
                        begin
                            Result := 0.0087415490275071003;
                        end
                        else
                        begin
                            if features.delta_local_lm_r2 <= -289.49999999999994 then
                            begin
                                if features.top_local_lm_r1 <= -5787.4999999999991 then
                                begin
                                    Result := 0.044650922724873643;
                                end
                                else
                                begin
                                    Result := -0.0016483222413592421;
                                end;
                            end
                            else
                            begin
                                Result := 0.0099520367503209174;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.016600495218921717;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_37(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022221910297871565;
        end
        else
        begin
            Result := -0.010777820433537935;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -84935356.999999985 then
        begin
            if features.delta_complete_pool_consensus_support_min <= 127.50000000000001 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.012018484213994662;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.delta_word_lm_zero_count <= 3.5000000000000004 then
                        begin
                            if features.candidate_complete_pool_signature_support <= 3.5000000000000004 then
                            begin
                                if features.candidate_text_units <= 12.500000000000002 then
                                begin
                                    if features.candidate_local_lm_r0 <= -6201.4999999999991 then
                                    begin
                                        Result := -0.00049794960383566043;
                                    end
                                    else
                                    begin
                                        if features.delta_char_lm_per_difference <= 100.41666666666667 then
                                        begin
                                            Result := 0.0061318842083936849;
                                        end
                                        else
                                        begin
                                            Result := 0.035270170514059694;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0096923536947121202;
                                end;
                            end
                            else
                            begin
                                Result := 0.0088234001527547935;
                            end;
                        end
                        else
                        begin
                            Result := 0.015445436294401533;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 8.1250000000000018 then
                        begin
                            Result := 0.058084786454138684;
                        end
                        else
                        begin
                            Result := 0.00018728242466375388;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.010356437504975445;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 57902221.000000007 then
            begin
                Result := 0.00701258919273427;
            end
            else
            begin
                if features.ranker_score_gap <= -27341488.499999996 then
                begin
                    Result := 0.011287761217736336;
                end
                else
                begin
                    Result := 0.02064182550094373;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_38(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.022149086208697658;
        end
        else
        begin
            Result := -0.010621270301111539;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -117092734.49999999 then
        begin
            if features.candidate_dict_weight <= 31305.000000000004 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.0091268365584845617;
                end
                else
                begin
                    Result := 0.0077740165376713509;
                end;
            end
            else
            begin
                if features.delta_chain_score_gap <= -191740645.49999997 then
                begin
                    Result := 0.039046252028371781;
                end
                else
                begin
                    Result := -0.003871182139647357;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -340253907.49999994 then
            begin
                Result := -0.011069326135136712;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -6066.4999999999991 then
                begin
                    if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                    begin
                        Result := -0.0025168324675297177;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -6468.4999999999991 then
                        begin
                            if features.candidate_local_lm_r0 <= -7207.4999999999991 then
                            begin
                                Result := 0.0089123998556569963;
                            end
                            else
                            begin
                                Result := 0.01884510189036959;
                            end;
                        end
                        else
                        begin
                            Result := 0.0030363167515793307;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8915.4999999999982 then
                    begin
                        if features.candidate_ranker_score <= -85906157.499999985 then
                        begin
                            Result := -0.010143216314650269;
                        end
                        else
                        begin
                            if features.candidate_word_lm_boundary_max <= 1108.5000000000002 then
                            begin
                                Result := 0.074803803394797003;
                            end
                            else
                            begin
                                Result := 0.021684145843196813;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.013560924625624316;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_39(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -458.49999999999994 then
    begin
        if features.delta_local_lm_r1 <= -2233.4999999999995 then
        begin
            Result := -0.019395847012237084;
        end
        else
        begin
            if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
            begin
                Result := -0.0017830264944224397;
            end
            else
            begin
                Result := -0.015047398872223491;
            end;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 47719473.000000007 then
        begin
            if features.top_ranker_score <= 205282864.00000003 then
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.0090405068044093831;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -6015.4999999999991 then
                    begin
                        if features.top_ranker_score <= 21471460.000000004 then
                        begin
                            Result := 0.0083387683176972052;
                        end
                        else
                        begin
                            Result := -0.0030827443482686987;
                        end;
                    end
                    else
                    begin
                        if features.same_prefix_units <= 4.5000000000000009 then
                        begin
                            Result := 0.028942831329183384;
                        end
                        else
                        begin
                            Result := 0.0025499704774432719;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.015632328714058261;
            end;
        end
        else
        begin
            if features.delta_char_lm_per_difference <= 73.125000000000014 then
            begin
                if features.delta_local_lm_r3 <= 164.50000000000003 then
                begin
                    if features.candidate_text_units <= 12.500000000000002 then
                    begin
                        Result := 0.010986086584448933;
                    end
                    else
                    begin
                        Result := -9.333161832059914E-05;
                    end;
                end
                else
                begin
                    Result := -0.0073539501672226565;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r2 <= -4720.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.018311253211452619;
                    end
                    else
                    begin
                        Result := 0.004583791021898524;
                    end;
                end
                else
                begin
                    Result := 0.050192515220221889;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_40(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.02202131960858068;
        end
        else
        begin
            Result := -0.010358931269440147;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0082683355703404189;
        end
        else
        begin
            if features.ranker_score_gap <= -63822726.499999993 then
            begin
                if features.delta_complete_pool_consensus_support_min <= 274.50000000000006 then
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.delta_score_per_unit <= -29.499999999999996 then
                        begin
                            if features.candidate_local_lm_r1 <= -5965.4999999999991 then
                            begin
                                Result := -0.0027551860289980329;
                            end
                            else
                            begin
                                if features.delta_char_suffix_lm_per_difference <= 87.166666666666671 then
                                begin
                                    Result := 0.0065084347386400523;
                                end
                                else
                                begin
                                    Result := 0.054805175195436651;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.0073693388237938964;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_bonus <= -142.49999999999997 then
                        begin
                            Result := -0.0095478985321504149;
                        end
                        else
                        begin
                            Result := 0.047077820957381042;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.01078125107477265;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.top_local_lm_r1 <= -5676.4999999999991 then
                    begin
                        Result := 0.012403181164843038;
                    end
                    else
                    begin
                        Result := -0.0018427893305921314;
                    end;
                end
                else
                begin
                    if features.delta_dict_weight <= 42199.500000000007 then
                    begin
                        Result := 0.03502445222225916;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                        begin
                            Result := 0.036556471279646494;
                        end
                        else
                        begin
                            Result := -0.0039951005303985477;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_41(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -458.49999999999994 then
    begin
        if features.delta_candidate_score <= -1.0000000180025095E-35 then
        begin
            Result := -0.019078254201762984;
        end
        else
        begin
            if features.top_local_lm_r1 <= -6350.4999999999991 then
            begin
                if features.candidate_text_units <= 8.5000000000000018 then
                begin
                    Result := 0.0085359922377018331;
                end
                else
                begin
                    Result := -0.0065824288082424916;
                end;
            end
            else
            begin
                Result := -0.015013423752059314;
            end;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 32608620.500000004 then
        begin
            if features.top_local_lm_r0 <= -7851.4999999999991 then
            begin
                Result := -0.0054095312213288038;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -732.49999999999989 then
                begin
                    Result := -0.00075865958318428208;
                end
                else
                begin
                    if features.candidate_text_units <= 13.500000000000002 then
                    begin
                        Result := 0.016623138282827386;
                    end
                    else
                    begin
                        Result := -0.0040794316207127734;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_char_lm_per_difference <= 73.125000000000014 then
            begin
                if features.delta_local_lm_r2 <= 137.50000000000003 then
                begin
                    if features.candidate_text_units <= 12.500000000000002 then
                    begin
                        Result := 0.010543901903793673;
                    end
                    else
                    begin
                        Result := 0.0001146724900596822;
                    end;
                end
                else
                begin
                    Result := -0.0041184750563993079;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r2 <= -4720.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= -2001.4999999999998 then
                        begin
                            Result := 0.0;
                        end
                        else
                        begin
                            Result := 0.020899028200803957;
                        end;
                    end
                    else
                    begin
                        Result := 0.0039571244835155664;
                    end;
                end
                else
                begin
                    Result := 0.044992036200401403;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_42(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.021892755647206347;
        end
        else
        begin
            Result := -0.010116746701751609;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -154834619.99999997 then
        begin
            Result := -0.0011420108830872972;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= -2215.4999999999995 then
                        begin
                            Result := -0.00092559287382608282;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 50.166666666666679 then
                            begin
                                Result := 0.00716581066176121;
                            end
                            else
                            begin
                                Result := 0.017858603501032692;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.0063069284722172929;
                        end
                        else
                        begin
                            Result := -0.0048859305553469118;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                    begin
                        if features.candidate_complete_pool_consensus_majority_units <= 10.500000000000002 then
                        begin
                            if features.candidate_local_lm_r3 <= -4684.4999999999991 then
                            begin
                                Result := 0.067363154667018366;
                            end
                            else
                            begin
                                Result := 0.016717415438273403;
                            end;
                        end
                        else
                        begin
                            Result := 0.002117174644243533;
                        end;
                    end
                    else
                    begin
                        if features.different_units <= 1.5000000000000002 then
                        begin
                            Result := 0.0030376584956387643;
                        end
                        else
                        begin
                            if features.same_suffix_units <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.00020618594624738232;
                            end
                            else
                            begin
                                Result := 0.044877285209969989;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.013298389180656983;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_43(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.021814917991256854;
        end
        else
        begin
            Result := -0.0099635465112707881;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0081191761783211674;
        end
        else
        begin
            if features.ranker_score_gap <= -117092734.49999999 then
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
                begin
                    Result := -0.016056998595310464;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        Result := 0.0027787040875725398;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 8.1250000000000018 then
                        begin
                            Result := 0.050250793059453819;
                        end
                        else
                        begin
                            Result := -0.001494178574871988;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5375.4999999999991 then
                begin
                    Result := 0.0080801109863956645;
                end
                else
                begin
                    if features.same_prefix_units <= 1.5000000000000002 then
                    begin
                        if features.delta_dict_weight <= 78979.000000000015 then
                        begin
                            Result := 0.044977059515205371;
                        end
                        else
                        begin
                            Result := 0.00068242874207905273;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                        begin
                            if features.delta_char_lm_per_difference <= -3.8333333333333326 then
                            begin
                                Result := 0.048716498541995591;
                            end
                            else
                            begin
                                Result := 0.010033255840570902;
                            end;
                        end
                        else
                        begin
                            if features.different_units <= 1.5000000000000002 then
                            begin
                                Result := -0.0023159329186105432;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -5421.4999999999991 then
                                begin
                                    Result := 0.045975577720249239;
                                end
                                else
                                begin
                                    Result := 0.00089919022365822748;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_44(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -215623245.99999997 then
    begin
        if features.ranker_score_gap <= -313895743.49999994 then
        begin
            Result := -0.021735898419637849;
        end
        else
        begin
            Result := -0.0098112383015742915;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0079813432603836488;
        end
        else
        begin
            if features.ranker_score_gap <= -23397226.499999996 then
            begin
                if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                begin
                    Result := -0.0058835095768109084;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 4.5000000000000009 then
                    begin
                        if features.ranker_score_gap <= -154834619.99999997 then
                        begin
                            Result := 0.00044876322210290727;
                        end
                        else
                        begin
                            if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                            begin
                                Result := 0.0024683496442311579;
                            end
                            else
                            begin
                                if features.delta_local_lm_r3 <= -228.49999999999997 then
                                begin
                                    if features.candidate_local_lm_r0 <= -5783.4999999999991 then
                                    begin
                                        if features.top_local_lm_r1 <= -5327.4999999999991 then
                                        begin
                                            if features.ranker_score_gap <= -68792707.999999985 then
                                            begin
                                                Result := 0.012798566760374703;
                                            end
                                            else
                                            begin
                                                Result := 0.039016045230095449;
                                            end;
                                        end
                                        else
                                        begin
                                            Result := -0.0033393267315615402;
                                        end;
                                    end
                                    else
                                    begin
                                        if features.candidate_complete_pool_consensus_support <= 870.50000000000011 then
                                        begin
                                            Result := 0.054241072736554666;
                                        end
                                        else
                                        begin
                                            Result := 0.0098948617479307013;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0063587661443512654;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_supported_ratio <= -52.499999999999993 then
                        begin
                            Result := -0.0071143113646380471;
                        end
                        else
                        begin
                            Result := 0.050691673210449012;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := 0.013461375010950636;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_45(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -590.49999999999989 then
    begin
        if features.top_local_lm_r1 <= -6510.4999999999991 then
        begin
            if features.delta_candidate_score <= -1.0000000180025095E-35 then
            begin
                Result := -0.016460185401157807;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -8243.4999999999982 then
                begin
                    Result := -0.0019172501909277843;
                end
                else
                begin
                    Result := 0.022393317402271896;
                end;
            end;
        end
        else
        begin
            Result := -0.019075487422821023;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -37322218.999999993 then
        begin
            Result := -0.0023841497258782615;
        end
        else
        begin
            if features.delta_char_lm_score <= -61.499999999999993 then
            begin
                if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                begin
                    if features.same_suffix_units <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r2 <= -1476.4999999999998 then
                        begin
                            if features.candidate_complete_pool_consensus_majority_units <= 10.500000000000002 then
                            begin
                                Result := 0.065281676972214847;
                            end
                            else
                            begin
                                Result := -0.0071524990436302414;
                            end;
                        end
                        else
                        begin
                            Result := -0.0090293126190474689;
                        end;
                    end
                    else
                    begin
                        Result := 0.0094606359556320858;
                    end;
                end
                else
                begin
                    if features.candidate_word_lm_supported_ratio <= 184.00000000000003 then
                    begin
                        Result := 0.0031837496262320415;
                    end
                    else
                    begin
                        Result := -0.011119570455988367;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -6101.4999999999991 then
                begin
                    if features.top_local_lm_r2 <= -5488.4999999999991 then
                    begin
                        Result := 0.0060303680419759821;
                    end
                    else
                    begin
                        Result := 0.022970254381818305;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_nearest_distance <= 3.5000000000000004 then
                    begin
                        Result := 0.014157859470184862;
                    end
                    else
                    begin
                        Result := 0.057032727874719302;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_46(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -692.49999999999989 then
    begin
        if features.top_local_lm_r1 <= -6510.4999999999991 then
        begin
            if features.delta_candidate_score <= -1.0000000180025095E-35 then
            begin
                Result := -0.018245516029737965;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -8243.4999999999982 then
                begin
                    Result := -0.0028193583812714416;
                end
                else
                begin
                    if features.candidate_ranker_score <= -51572350.999999993 then
                    begin
                        Result := -0.015345556950627927;
                    end
                    else
                    begin
                        Result := 0.04023714106058518;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.019921220269154959;
        end;
    end
    else
    begin
        if features.delta_char_lm_score <= -259.49999999999994 then
        begin
            if features.delta_candidate_score <= -1.0000000180025095E-35 then
            begin
                Result := -0.0097814487950211877;
            end
            else
            begin
                if features.candidate_complete_pool_consensus_majority_units <= 10.500000000000002 then
                begin
                    if features.candidate_local_lm_r1 <= -7532.4999999999991 then
                    begin
                        if features.candidate_ranker_score <= 135129802.00000003 then
                        begin
                            Result := 0.0072161430861645949;
                        end
                        else
                        begin
                            Result := 0.026923437256037405;
                        end;
                    end
                    else
                    begin
                        Result := 0.00033950957656579418;
                    end;
                end
                else
                begin
                    Result := -0.0094501182274377409;
                end;
            end;
        end
        else
        begin
            if features.different_units <= 2.5000000000000004 then
            begin
                if features.candidate_chain_score_gap <= -59624646.999999993 then
                begin
                    Result := 0.00019061495451640469;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -1255.4999999999998 then
                    begin
                        Result := 0.0029203832857344503;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -8968.9999999999982 then
                        begin
                            Result := 0.0011784241726264248;
                        end
                        else
                        begin
                            Result := 0.011897032396652369;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.01143007423913101;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_47(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023620466734277382;
        end
        else
        begin
            Result := -0.012539752112832845;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -154834619.99999997 then
        begin
            Result := -0.0018208950479781272;
        end
        else
        begin
            if features.candidate_local_lm_r0 <= -5295.4999999999991 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.0038273343343432444;
                end
                else
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= -2211.4999999999995 then
                        begin
                            Result := 0.00047213054634620186;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 50.166666666666679 then
                            begin
                                Result := 0.0065678278138029192;
                            end
                            else
                            begin
                                if features.candidate_complete_pool_pair_evidence <= 1.0000000180025095E-35 then
                                begin
                                    Result := 0.012479183710551563;
                                end
                                else
                                begin
                                    Result := 0.027768194584309465;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r2 <= -244.49999999999997 then
                        begin
                            Result := 0.0089707002154084062;
                        end
                        else
                        begin
                            Result := 0.00051043648148858768;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                begin
                    if features.candidate_text_units <= 12.500000000000002 then
                    begin
                        if features.candidate_char_lm_suffix_score <= -4312.4999999999991 then
                        begin
                            Result := 0.052542484260679805;
                        end
                        else
                        begin
                            Result := 0.012213633336687065;
                        end;
                    end
                    else
                    begin
                        Result := -0.0051515206293026375;
                    end;
                end
                else
                begin
                    if features.different_units <= 1.5000000000000002 then
                    begin
                        Result := 0.0023659941602815985;
                    end
                    else
                    begin
                        Result := 0.029753145001256344;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_48(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023577922742154377;
        end
        else
        begin
            Result := -0.012379767043789919;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -154834619.99999997 then
        begin
            Result := -0.001778698240376398;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= -2215.4999999999995 then
                        begin
                            Result := -0.001397739567429408;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 50.166666666666679 then
                            begin
                                Result := 0.0059850551321837227;
                            end
                            else
                            begin
                                if features.delta_word_lm_boundary_last <= -1558.4999999999998 then
                                begin
                                    Result := 0.040348410674771268;
                                end
                                else
                                begin
                                    Result := 0.013826157100680796;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.0034581150562899643;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_majority_units <= 8.5000000000000018 then
                    begin
                        if features.candidate_local_lm_r1 <= -8491.4999999999982 then
                        begin
                            Result := 0.061013380202191825;
                        end
                        else
                        begin
                            if features.delta_char_suffix_lm_per_difference <= -139.87499999999997 then
                            begin
                                Result := 0.00076772871067250377;
                            end
                            else
                            begin
                                if features.top_local_lm_r1 <= -5676.4999999999991 then
                                begin
                                    Result := 0.016380297904619097;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_pair_evidence <= 1408.5000000000002 then
                                    begin
                                        Result := 0.075294784240429402;
                                    end
                                    else
                                    begin
                                        Result := 0.013701996676986848;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.0058440209853365599;
                    end;
                end;
            end
            else
            begin
                Result := -0.013125972788816788;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_49(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023534705151432231;
        end
        else
        begin
            Result := -0.012219961758631586;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -154834619.99999997 then
        begin
            if features.candidate_has_dict_weight <= 1.0000000180025095E-35 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.014054349132987313;
                end
                else
                begin
                    Result := 0.0059669555394625488;
                end;
            end
            else
            begin
                if features.delta_chain_score_gap <= -191740645.49999997 then
                begin
                    Result := 0.027449279497523245;
                end
                else
                begin
                    Result := -0.0077190129283644165;
                end;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.baseline_abstain_score <= 50364912.000000007 then
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        if features.delta_complete_pool_consensus_mean_distance <= 6562.5000000000009 then
                        begin
                            Result := 0.0060714078813770243;
                        end
                        else
                        begin
                            if features.delta_local_lm_r1 <= 1000.5000000000001 then
                            begin
                                Result := 0.009940782222051036;
                            end
                            else
                            begin
                                Result := 0.043863473888532206;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_chain_second_stage_score <= -33125041.499999996 then
                        begin
                            if features.delta_local_lm_r2 <= 1662.5000000000002 then
                            begin
                                if features.candidate_chain_second_stage_score <= -166364389.49999997 then
                                begin
                                    Result := 0.017161131953078543;
                                end
                                else
                                begin
                                    Result := 0.074934927930491113;
                                end;
                            end
                            else
                            begin
                                Result := -0.0081560246281934569;
                            end;
                        end
                        else
                        begin
                            Result := 0.012104034997133587;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0073610117270839232;
                end;
            end
            else
            begin
                Result := -0.012965820655425099;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_50(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023490794804659751;
        end
        else
        begin
            Result := -0.012060382239428322;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0086188431675618196;
        end
        else
        begin
            if features.baseline_abstain_score <= 50364912.000000007 then
            begin
                if features.delta_path_max_segment_units <= 4.5000000000000009 then
                begin
                    if features.ranker_score_gap <= -154834619.99999997 then
                    begin
                        if features.delta_chain_second_stage_score <= -192224348.99999997 then
                        begin
                            Result := 0.014671360859068953;
                        end
                        else
                        begin
                            Result := -0.0023849935177584205;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                        begin
                            Result := 0.006110512001557232;
                        end
                        else
                        begin
                            if features.different_units <= 1.5000000000000002 then
                            begin
                                if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                                begin
                                    if features.candidate_candidate_score <= 174848.50000000003 then
                                    begin
                                        Result := 0.04023100570803869;
                                    end
                                    else
                                    begin
                                        Result := -0.0021339352703242621;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0018786891167318508;
                                end;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -5470.4999999999991 then
                                begin
                                    if features.delta_local_lm_r2 <= 37.500000000000007 then
                                    begin
                                        Result := 0.084361546218599495;
                                    end
                                    else
                                    begin
                                        Result := 0.01786343375680579;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.012079924110855442;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_bonus <= -77.499999999999986 then
                    begin
                        Result := -0.0069003534683405397;
                    end
                    else
                    begin
                        Result := 0.041878021424765599;
                    end;
                end;
            end
            else
            begin
                Result := -0.008682791832999243;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_51(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023446175169045305;
        end
        else
        begin
            Result := -0.011901075038323321;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0084764867557677089;
        end
        else
        begin
            if features.baseline_abstain_score <= 50364912.000000007 then
            begin
                if features.delta_path_max_segment_units <= 5.5000000000000009 then
                begin
                    if features.ranker_score_gap <= -154834619.99999997 then
                    begin
                        Result := -0.00033145892668926013;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                        begin
                            Result := 0.0059342331648682889;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -8528.4999999999982 then
                            begin
                                if features.delta_word_lm_boundary_count <= -1.0000000180025095E-35 then
                                begin
                                    Result := 0.0012146696453065179;
                                end
                                else
                                begin
                                    Result := 0.059846121647501985;
                                end;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                                begin
                                    Result := 0.02440102530575505;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_pair_evidence <= 2947.5000000000005 then
                                    begin
                                        Result := 0.0016727871782450604;
                                    end
                                    else
                                    begin
                                        Result := 0.031025895849398261;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_bonus <= -142.49999999999997 then
                    begin
                        Result := -0.0073931724196019096;
                    end
                    else
                    begin
                        if features.top_local_lm_r1 <= -7810.4999999999991 then
                        begin
                            Result := 0.0070693174643270754;
                        end
                        else
                        begin
                            Result := 0.064903962138044599;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_char_lm_context_score <= -32.499999999999993 then
                begin
                    Result := -0.013003855455336978;
                end
                else
                begin
                    Result := 0.017889401424558558;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_52(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023400827835866066;
        end
        else
        begin
            Result := -0.011742085804970333;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0083354023859195554;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -57678217.499999993 then
                begin
                    Result := -0.0087834270905849648;
                end
                else
                begin
                    Result := 0.0063481488215861442;
                end;
            end
            else
            begin
                if features.delta_path_max_segment_units <= 4.5000000000000009 then
                begin
                    if features.ranker_score_gap <= -110149538.99999999 then
                    begin
                        if features.delta_word_lm_boundary_count <= 2.5000000000000004 then
                        begin
                            if features.top_local_lm_r1 <= -4542.4999999999991 then
                            begin
                                Result := 0.0020373963377033374;
                            end
                            else
                            begin
                                Result := -0.010537251171208685;
                            end;
                        end
                        else
                        begin
                            Result := 0.013031775939842494;
                        end;
                    end
                    else
                    begin
                        if features.delta_candidate_score <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.006882313493816271;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_support <= 859.50000000000011 then
                            begin
                                if features.candidate_score_per_unit <= 8355.0000000000018 then
                                begin
                                    Result := 0.0036722060865884854;
                                end
                                else
                                begin
                                    if features.delta_complete_pool_consensus_support_mean <= -54.499999999999993 then
                                    begin
                                        Result := 0.0095017895389415095;
                                    end
                                    else
                                    begin
                                        if features.candidate_complete_pool_consensus_mean_distance <= 5268.0000000000009 then
                                        begin
                                            Result := 0.069167500068446006;
                                        end
                                        else
                                        begin
                                            Result := 0.0041138174742855948;
                                        end;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.005273830802729515;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.032023065010311595;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_53(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -233163470.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.02335473641147846;
        end
        else
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                Result := -0.012516189065419528;
            end
            else
            begin
                Result := 0.017242690694559668;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -154834619.99999997 then
        begin
            if features.candidate_dict_weight_per_unit <= 4033.0000000000005 then
            begin
                if features.candidate_complete_pool_signature_support <= 3.5000000000000004 then
                begin
                    Result := -0.0019067170806704372;
                end
                else
                begin
                    Result := 0.01245797613255731;
                end;
            end
            else
            begin
                Result := -0.0068769574189945825;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.ranker_score_gap <= -23397226.499999996 then
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.0063487163979133029;
                    end
                    else
                    begin
                        if features.delta_score_per_unit <= 14.500000000000002 then
                        begin
                            if features.delta_word_lm_supported_ratio <= -257.49999999999994 then
                            begin
                                Result := 0.014037986052517866;
                            end
                            else
                            begin
                                if features.delta_complete_pool_consensus_nearest_distance <= 5.5000000000000009 then
                                begin
                                    Result := 0.0033052541875321986;
                                end
                                else
                                begin
                                    Result := 0.019120984594685642;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_majority_units <= 7.5000000000000009 then
                            begin
                                if features.delta_local_lm_r2 <= -222.49999999999997 then
                                begin
                                    Result := 0.043648491695145064;
                                end
                                else
                                begin
                                    Result := 0.0044955326419170707;
                                end;
                            end
                            else
                            begin
                                Result := 0.006710570637755567;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.011288136443434979;
                end;
            end
            else
            begin
                Result := -0.012825054355455355;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_54(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -242531249.49999997 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023307883330865625;
        end
        else
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                Result := -0.012991546992800621;
            end
            else
            begin
                Result := 0.020879912699801998;
            end;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -157813646.99999997 then
        begin
            if features.candidate_complete_pool_consensus_unanimous_units <= 9.5000000000000018 then
            begin
                if features.delta_char_lm_score <= -751.49999999999989 then
                begin
                    Result := -0.011263511610094853;
                end
                else
                begin
                    if features.candidate_candidate_score <= 171529.00000000003 then
                    begin
                        Result := 0.00032960327350265854;
                    end
                    else
                    begin
                        Result := 0.017134313760147173;
                    end;
                end;
            end
            else
            begin
                Result := -0.014870132213707171;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.ranker_score_gap <= 12371962.500000002 then
                begin
                    if features.delta_local_lm_r0 <= -2211.4999999999995 then
                    begin
                        if features.top_local_lm_r1 <= -9109.4999999999982 then
                        begin
                            Result := -0.014337842992611533;
                        end
                        else
                        begin
                            Result := 0.0023584450179269796;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -7851.4999999999991 then
                        begin
                            if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.0075303723119094406;
                            end
                            else
                            begin
                                Result := -0.0026855284727061442;
                            end;
                        end
                        else
                        begin
                            Result := 0.0081432512703108056;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_chain_first_stage_score <= 65885.500000000015 then
                    begin
                        Result := 0.01112230491521022;
                    end
                    else
                    begin
                        Result := 0.03865889040772242;
                    end;
                end;
            end
            else
            begin
                Result := -0.012391859855123234;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_55(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        Result := -0.018863543324520299;
    end
    else
    begin
        if features.ranker_score_gap <= -163813990.99999997 then
        begin
            if features.candidate_text_units <= 10.500000000000002 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.015221879885607806;
                end
                else
                begin
                    Result := 0.0021899098035993415;
                end;
            end
            else
            begin
                Result := -0.0097122637084498011;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                begin
                    if features.delta_local_lm_r0 <= -2215.4999999999995 then
                    begin
                        Result := -0.0011617760488579056;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 50.166666666666679 then
                        begin
                            Result := 0.0057351169655164369;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_pair_evidence <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.010192359733152785;
                            end
                            else
                            begin
                                Result := 0.022055064842483131;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                    begin
                        if features.same_suffix_units <= 1.0000000180025095E-35 then
                        begin
                            if features.candidate_local_lm_r1 <= -10072.499999999998 then
                            begin
                                Result := 0.040024597195102457;
                            end
                            else
                            begin
                                Result := -0.0050829789135680079;
                            end;
                        end
                        else
                        begin
                            if features.delta_local_lm_r1 <= -2233.4999999999995 then
                            begin
                                Result := -0.010391686201633908;
                            end
                            else
                            begin
                                if features.candidate_ranker_score <= 102045798.00000001 then
                                begin
                                    Result := 0.0040560723215765197;
                                end
                                else
                                begin
                                    Result := 0.01229474741325798;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.0045634459988643343;
                    end;
                end;
            end
            else
            begin
                Result := -0.012149306511330841;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_56(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023221044199694164;
        end
        else
        begin
            Result := -0.013634625151815303;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -163813990.99999997 then
        begin
            if features.candidate_text_units <= 10.500000000000002 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.015073874669513945;
                end
                else
                begin
                    if features.candidate_candidate_score <= 172922.50000000003 then
                    begin
                        Result := -0.00015842675589641564;
                    end
                    else
                    begin
                        Result := 0.0160476548720167;
                    end;
                end;
            end
            else
            begin
                Result := -0.0095612176943192916;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.ranker_score_gap <= -23397226.499999996 then
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.0061274660675270367;
                    end
                    else
                    begin
                        if features.delta_complete_pool_consensus_nearest_distance <= 4.5000000000000009 then
                        begin
                            if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                            begin
                                Result := 0.00013506403467709814;
                            end
                            else
                            begin
                                if features.delta_local_lm_r2 <= -222.49999999999997 then
                                begin
                                    if features.top_local_lm_r1 <= -5197.4999999999991 then
                                    begin
                                        Result := 0.015903036529852553;
                                    end
                                    else
                                    begin
                                        Result := -0.0018212279007948945;
                                    end;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_signature_support <= 1.5000000000000002 then
                                    begin
                                        Result := 0.011015666342702976;
                                    end
                                    else
                                    begin
                                        Result := 0.0011504495552364072;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.016992987515114251;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.010358243981673508;
                end;
            end
            else
            begin
                Result := -0.011991121056396263;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_57(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        Result := -0.018618741222177045;
    end
    else
    begin
        if features.ranker_score_gap <= -163813990.99999997 then
        begin
            if features.candidate_text_units <= 10.500000000000002 then
            begin
                Result := 7.6728398284197304E-05;
            end
            else
            begin
                Result := -0.0094112125908175515;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.017943657621783432;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.007369316217598721;
                    end
                    else
                    begin
                        if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                        begin
                            if features.top_local_lm_r1 <= -5619.4999999999991 then
                            begin
                                if features.delta_candidate_score <= 1.0000000180025095E-35 then
                                begin
                                    Result := 0.0037721843908514845;
                                end
                                else
                                begin
                                    Result := 0.01334913004578433;
                                end;
                            end
                            else
                            begin
                                Result := -0.0045632590951305424;
                            end;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -6365.4999999999991 then
                            begin
                                Result := -0.011069262971018417;
                            end
                            else
                            begin
                                if features.candidate_complete_pool_consensus_mean_distance <= 4354.0000000000009 then
                                begin
                                    Result := -0.0011087785202526697;
                                end
                                else
                                begin
                                    Result := 0.036687604221117207;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8528.4999999999982 then
                    begin
                        if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                        begin
                            if features.delta_word_lm_bonus <= 80.500000000000014 then
                            begin
                                Result := 0.056685661906585263;
                            end
                            else
                            begin
                                Result := -9.5843798009847178E-06;
                            end;
                        end
                        else
                        begin
                            Result := -0.0088631653492646772;
                        end;
                    end
                    else
                    begin
                        Result := 0.0089589695746868994;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_58(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_char_lm_score <= -692.49999999999989 then
    begin
        if features.top_local_lm_r1 <= -6510.4999999999991 then
        begin
            if features.delta_candidate_score <= -1.0000000180025095E-35 then
            begin
                Result := -0.016815962227670719;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -8243.4999999999982 then
                begin
                    Result := -0.001311028241873458;
                end
                else
                begin
                    Result := 0.025509336183470229;
                end;
            end;
        end
        else
        begin
            Result := -0.018841109399645624;
        end;
    end
    else
    begin
        if features.delta_char_lm_score <= -259.49999999999994 then
        begin
            if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
            begin
                if features.delta_local_lm_r3 <= -1427.4999999999998 then
                begin
                    if features.same_suffix_units <= 4.5000000000000009 then
                    begin
                        Result := 0.059261373905350682;
                    end
                    else
                    begin
                        Result := -0.010804646324586916;
                    end;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_unanimous_units <= -1.0000000180025095E-35 then
                    begin
                        Result := -0.011299310651670542;
                    end
                    else
                    begin
                        if features.candidate_char_lm_suffix_score <= -5646.4999999999991 then
                        begin
                            if features.candidate_local_lm_r1 <= -7532.4999999999991 then
                            begin
                                if features.candidate_local_lm_r0 <= -5951.4999999999991 then
                                begin
                                    Result := 0.0011003054177373289;
                                end
                                else
                                begin
                                    Result := 0.022804910287677123;
                                end;
                            end
                            else
                            begin
                                Result := -0.010165784857453937;
                            end;
                        end
                        else
                        begin
                            Result := 0.011903587969940203;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.0098110435505240345;
            end;
        end
        else
        begin
            if features.different_units <= 2.5000000000000004 then
            begin
                if features.candidate_local_lm_r0 <= -9566.4999999999982 then
                begin
                    Result := -0.0050487683045751415;
                end
                else
                begin
                    Result := 0.0058646870836799054;
                end;
            end
            else
            begin
                Result := -0.010973381045879386;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_59(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        Result := -0.01840859339228015;
    end
    else
    begin
        if features.ranker_score_gap <= -163813990.99999997 then
        begin
            if features.different_units <= 1.5000000000000002 then
            begin
                if features.top_local_lm_r0 <= -5300.9999999999991 then
                begin
                    if features.candidate_local_lm_r1 <= -5047.4999999999991 then
                    begin
                        if features.candidate_score_per_unit <= 11973.500000000002 then
                        begin
                            Result := -0.0086888166922226666;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r0 <= -8092.4999999999991 then
                            begin
                                Result := 0.0215051249197384;
                            end
                            else
                            begin
                                Result := -0.0030696307545242094;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.031188841843195342;
                    end;
                end
                else
                begin
                    Result := 0.0097578194382454131;
                end;
            end
            else
            begin
                Result := -0.009850775995879045;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.017806161536236206;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.top_local_lm_r1 <= -4757.4999999999991 then
                    begin
                        Result := 0.004956268488886072;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 122.10000000000001 then
                        begin
                            Result := -0.0064393393765560377;
                        end
                        else
                        begin
                            Result := 0.035296368947605329;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_majority_units <= 8.5000000000000018 then
                    begin
                        if features.candidate_local_lm_r1 <= -8655.4999999999982 then
                        begin
                            Result := 0.052119788563315818;
                        end
                        else
                        begin
                            if features.delta_char_suffix_lm_per_difference <= -139.87499999999997 then
                            begin
                                Result := -0.00094113661881243703;
                            end
                            else
                            begin
                                Result := 0.021218130626898469;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.0033639319657617866;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_60(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023056638302637725;
        end
        else
        begin
            Result := -0.012929398978816287;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -163813990.99999997 then
        begin
            if features.candidate_text_units <= 10.500000000000002 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.014780621782153973;
                end
                else
                begin
                    Result := 0.002139760815448353;
                end;
            end
            else
            begin
                Result := -0.0091364426659430505;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.ranker_score_gap <= 12371962.500000002 then
                begin
                    if features.delta_source_rule_fallback <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                        begin
                            if features.delta_local_lm_r3 <= 125.50000000000001 then
                            begin
                                if features.top_local_lm_r1 <= -5885.4999999999991 then
                                begin
                                    Result := 0.0081386294058073128;
                                end
                                else
                                begin
                                    Result := -0.00044154206134278139;
                                end;
                            end
                            else
                            begin
                                Result := -0.0036342239863823567;
                            end;
                        end
                        else
                        begin
                            Result := -0.0049518244893217711;
                        end;
                    end
                    else
                    begin
                        Result := 0.0071394762958641835;
                    end;
                end
                else
                begin
                    if features.delta_chain_second_stage_score <= -33125041.499999996 then
                    begin
                        if features.delta_local_lm_r2 <= 1662.5000000000002 then
                        begin
                            if features.candidate_chain_second_stage_score <= -166364389.49999997 then
                            begin
                                Result := 0.014562773978418148;
                            end
                            else
                            begin
                                Result := 0.066422507042530499;
                            end;
                        end
                        else
                        begin
                            Result := -0.0088997633336812439;
                        end;
                    end
                    else
                    begin
                        Result := 0.0091903657146790736;
                    end;
                end;
            end
            else
            begin
                Result := -0.011767177006462355;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_61(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.023004759138524043;
        end
        else
        begin
            Result := -0.012771268812125973;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.delta_chain_score_gap <= -210851852.49999997 then
            begin
                Result := 0.024306934990154752;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3429.4999999999995 then
                begin
                    Result := -0.0066595281277408262;
                end
                else
                begin
                    Result := 0.010141699859461945;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 111801836.50000001 then
            begin
                if features.different_units <= 2.5000000000000004 then
                begin
                    if features.top_local_lm_r1 <= -4915.4999999999991 then
                    begin
                        if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                        begin
                            if features.candidate_local_lm_r0 <= -7236.4999999999991 then
                            begin
                                if features.baseline_abstain_score <= -10780562.499999998 then
                                begin
                                    Result := 0.018919669804474265;
                                end
                                else
                                begin
                                    Result := -0.0007809593229036086;
                                end;
                            end
                            else
                            begin
                                if features.delta_char_suffix_lm_per_difference <= -389.83333333333331 then
                                begin
                                    Result := -0.0048600244021288035;
                                end
                                else
                                begin
                                    Result := 0.013912511457941002;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.00050466518878269342;
                        end;
                    end
                    else
                    begin
                        Result := -0.0087986038183552658;
                    end;
                end
                else
                begin
                    Result := -0.01066147624168697;
                end;
            end
            else
            begin
                if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
                begin
                    if features.candidate_complete_pool_consensus_support_min <= 423.50000000000006 then
                    begin
                        Result := 0.045441617415518491;
                    end
                    else
                    begin
                        Result := -0.0020833686549035129;
                    end;
                end
                else
                begin
                    Result := 0.0060854441921345953;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_62(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.02295199255749459;
        end
        else
        begin
            Result := -0.012613175655311393;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -157813646.99999997 then
        begin
            if features.candidate_text_units <= 12.500000000000002 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.01427463078640675;
                end
                else
                begin
                    if features.candidate_char_lm_suffix_score <= -5856.4999999999991 then
                    begin
                        Result := -0.0032639927172260358;
                    end
                    else
                    begin
                        Result := 0.0065238748744014642;
                    end;
                end;
            end
            else
            begin
                Result := -0.011257357799398252;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.01750719478599749;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.top_local_lm_r1 <= -4757.4999999999991 then
                    begin
                        Result := 0.0046191002323857262;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -622.49999999999989 then
                        begin
                            Result := -0.013534368001309919;
                        end
                        else
                        begin
                            Result := 0.0034796162486602426;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_majority_units <= 8.5000000000000018 then
                    begin
                        if features.candidate_local_lm_r1 <= -8655.4999999999982 then
                        begin
                            Result := 0.05046557532937599;
                        end
                        else
                        begin
                            if features.delta_char_suffix_lm_per_difference <= -139.87499999999997 then
                            begin
                                Result := -0.00022393483258461753;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r1 <= -4640.4999999999991 then
                                begin
                                    Result := 0.014131603973071819;
                                end
                                else
                                begin
                                    Result := 0.049662549971173163;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.0028724475873506939;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_63(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022898324822299955;
        end
        else
        begin
            Result := -0.012455164787338234;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_local_lm_r3 <= -5328.4999999999991 then
            begin
                Result := -0.0057432428968572239;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -884.49999999999989 then
                begin
                    Result := -0.0091374289236306524;
                end
                else
                begin
                    Result := 0.024417233170761107;
                end;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.candidate_local_lm_r1 <= -5628.4999999999991 then
                        begin
                            if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                            begin
                                Result := 0.0010684831993745922;
                            end
                            else
                            begin
                                Result := 0.0091082450306698929;
                            end;
                        end
                        else
                        begin
                            if features.delta_candidate_score <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.063778179278497507;
                            end
                            else
                            begin
                                Result := 0.014848297405610942;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -7851.4999999999991 then
                        begin
                            Result := -0.0027569678412723685;
                        end
                        else
                        begin
                            if features.top_local_lm_r0 <= -5816.9999999999991 then
                            begin
                                Result := 0.0082090630567481504;
                            end
                            else
                            begin
                                Result := 0.00020613925579138421;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -185.49999999999997 then
                    begin
                        Result := -0.0088483622147743114;
                    end
                    else
                    begin
                        Result := 0.010830151018728369;
                    end;
                end;
            end
            else
            begin
                Result := -0.011357914200258617;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_64(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022843734802790838;
        end
        else
        begin
            Result := -0.012297283061907334;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -154834619.99999997 then
        begin
            if features.candidate_score_per_unit <= 13077.500000000002 then
            begin
                if features.delta_chain_second_stage_score <= -154230565.49999997 then
                begin
                    Result := 0.0053914395100936475;
                end
                else
                begin
                    if features.delta_char_lm_score <= -246.49999999999997 then
                    begin
                        Result := -0.011173243165220767;
                    end
                    else
                    begin
                        Result := -0.0010043727562575545;
                    end;
                end;
            end
            else
            begin
                Result := 0.0050089609273556712;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                    begin
                        Result := -0.0038595493809233184;
                    end
                    else
                    begin
                        Result := 0.004509891442206369;
                    end;
                end
                else
                begin
                    if features.same_prefix_units <= 3.5000000000000004 then
                    begin
                        if features.delta_dict_weight <= 42199.500000000007 then
                        begin
                            if features.delta_word_lm_bonus <= -227.49999999999997 then
                            begin
                                Result := -0.0050387450307104115;
                            end
                            else
                            begin
                                Result := 0.029668984121339476;
                            end;
                        end
                        else
                        begin
                            Result := 0.0025199093865741549;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                        begin
                            if features.candidate_complete_pool_consensus_majority_units <= 10.500000000000002 then
                            begin
                                Result := 0.035214954956550026;
                            end
                            else
                            begin
                                Result := -0.0064285426632908291;
                            end;
                        end
                        else
                        begin
                            Result := -0.0013269926688512905;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.011774595595912693;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_65(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022788210256401778;
        end
        else
        begin
            Result := -0.012139576196108809;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0087229854597833303;
        end
        else
        begin
            if features.delta_path_max_segment_units <= 5.5000000000000009 then
            begin
                if features.ranker_score_gap <= -117092734.49999999 then
                begin
                    if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.012880251677072477;
                    end
                    else
                    begin
                        if features.delta_word_lm_zero_count <= 3.5000000000000004 then
                        begin
                            if features.candidate_text_units <= 8.5000000000000018 then
                            begin
                                Result := 0.0041986136082221423;
                            end
                            else
                            begin
                                Result := -0.0037174104146639542;
                            end;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= -222.49999999999997 then
                            begin
                                Result := 0.036579080396942923;
                            end
                            else
                            begin
                                Result := 0.00680282510099564;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_pair_evidence <= 1246.5000000000002 then
                    begin
                        if features.candidate_word_lm_boundary_max <= 1135.5000000000002 then
                        begin
                            if features.candidate_ranker_score <= 117676590.00000001 then
                            begin
                                Result := 0.0022515397642841463;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -7302.4999999999991 then
                                begin
                                    Result := 0.021537096073833435;
                                end
                                else
                                begin
                                    Result := 0.0063778942501205556;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.00086199710276288531;
                        end;
                    end
                    else
                    begin
                        Result := 0.0086474476621641871;
                    end;
                end;
            end
            else
            begin
                if features.candidate_word_lm_boundary_count <= 7.5000000000000009 then
                begin
                    Result := 0.03660662631833024;
                end
                else
                begin
                    Result := -0.005066514966004531;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_66(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022731731695158443;
        end
        else
        begin
            Result := -0.011982090058995594;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0085797221123472944;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -57678217.499999993 then
                begin
                    Result := -0.0091289698555282045;
                end
                else
                begin
                    Result := 0.0050926584065444664;
                end;
            end
            else
            begin
                if features.delta_path_max_segment_units <= 5.5000000000000009 then
                begin
                    if features.ranker_score_gap <= -41600563.999999993 then
                    begin
                        if features.delta_chain_present <= 1.0000000180025095E-35 then
                        begin
                            if features.delta_score_per_unit <= -25.499999999999996 then
                            begin
                                if features.candidate_local_lm_r1 <= -5965.4999999999991 then
                                begin
                                    Result := -0.0034881692320889984;
                                end
                                else
                                begin
                                    Result := 0.0144488910066958;
                                end;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r2 <= -8162.4999999999991 then
                                begin
                                    Result := 0.013446908054702555;
                                end
                                else
                                begin
                                    Result := 0.0030030999218828161;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0060127690387783012;
                        end;
                    end
                    else
                    begin
                        if features.candidate_complete_pool_pair_evidence <= 1480.5000000000002 then
                        begin
                            if features.candidate_complete_pool_proper_name_confidence <= 820.00000000000011 then
                            begin
                                Result := 0.0044791408327394802;
                            end
                            else
                            begin
                                Result := 0.035864763885337728;
                            end;
                        end
                        else
                        begin
                            Result := 0.017314938943636848;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_supported_ratio <= -52.499999999999993 then
                    begin
                        Result := -0.0036934454522165256;
                    end
                    else
                    begin
                        Result := 0.039966474641667318;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_67(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022674282145174585;
        end
        else
        begin
            Result := -0.011824870568267358;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            Result := -0.0038437173133315482;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.delta_complete_dictionary <= -1.0000000180025095E-35 then
                    begin
                        if features.candidate_local_lm_r1 <= -5628.4999999999991 then
                        begin
                            Result := 0.0062470586874933051;
                        end
                        else
                        begin
                            if features.delta_candidate_score <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.059184405086619429;
                            end
                            else
                            begin
                                Result := 0.013850146688163227;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.candidate_word_lm_zero_count <= 6.5000000000000009 then
                        begin
                            if features.same_suffix_units <= 1.0000000180025095E-35 then
                            begin
                                if features.candidate_local_lm_r1 <= -10503.499999999998 then
                                begin
                                    Result := 0.039097224614614762;
                                end
                                else
                                begin
                                    Result := -0.0056092466866706353;
                                end;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -7882.4999999999991 then
                                begin
                                    Result := -0.00062921930232387718;
                                end
                                else
                                begin
                                    if features.top_local_lm_r0 <= -5816.9999999999991 then
                                    begin
                                        Result := 0.011536711237718142;
                                    end
                                    else
                                    begin
                                        Result := 0.0026358467186146958;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0057420307927120405;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -185.49999999999997 then
                    begin
                        Result := -0.0088427202182314747;
                    end
                    else
                    begin
                        Result := 0.0099407377355096374;
                    end;
                end;
            end
            else
            begin
                Result := -0.011005786440197854;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_68(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022615843146463813;
        end
        else
        begin
            Result := -0.011667963229702996;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0084184000242327594;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -57678217.499999993 then
                begin
                    Result := -0.0090082112340397445;
                end
                else
                begin
                    Result := 0.0048643618670574009;
                end;
            end
            else
            begin
                if features.delta_path_max_segment_units <= 5.5000000000000009 then
                begin
                    if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                    begin
                        if features.candidate_ranker_score <= 185268400.50000003 then
                        begin
                            Result := -0.0030537950000373271;
                        end
                        else
                        begin
                            Result := 0.0050783266562257345;
                        end;
                    end
                    else
                    begin
                        if features.ranker_score_gap <= 1.0000000180025095E-35 then
                        begin
                            if features.delta_score_per_unit <= -25.499999999999996 then
                            begin
                                Result := 0.0;
                            end
                            else
                            begin
                                Result := 0.0055717041474361755;
                            end;
                        end
                        else
                        begin
                            if features.delta_dict_weight <= -77131.499999999985 then
                            begin
                                if features.candidate_ranker_score <= 77649086.000000015 then
                                begin
                                    Result := 0.013696779937020703;
                                end
                                else
                                begin
                                    Result := 0.051687893843977088;
                                end;
                            end
                            else
                            begin
                                if features.candidate_word_lm_boundary_count <= 3.5000000000000004 then
                                begin
                                    Result := 0.03782842012483853;
                                end
                                else
                                begin
                                    Result := 0.0040475346151943644;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_supported_ratio <= -52.499999999999993 then
                    begin
                        Result := -0.0036873987105487736;
                    end
                    else
                    begin
                        Result := 0.03772457418311867;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_69(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.022556403390534663;
        end
        else
        begin
            Result := -0.011511413526182238;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0082778217094098133;
        end
        else
        begin
            if features.baseline_abstain_score <= 71515347.000000015 then
            begin
                if features.delta_path_max_segment_units <= 5.5000000000000009 then
                begin
                    if features.ranker_score_gap <= -154834619.99999997 then
                    begin
                        if features.delta_chain_second_stage_score <= -197269258.99999997 then
                        begin
                            Result := 0.011685048026224935;
                        end
                        else
                        begin
                            Result := -0.0027245957245667137;
                        end;
                    end
                    else
                    begin
                        if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                        begin
                            Result := 0.00068773309948592194;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                            begin
                                if features.candidate_complete_pool_signature_support <= 2.5000000000000004 then
                                begin
                                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                                    begin
                                        Result := 0.013768945107626315;
                                    end
                                    else
                                    begin
                                        Result := -1.5627674409414685E-05;
                                    end;
                                end
                                else
                                begin
                                    if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
                                    begin
                                        Result := 0.00042234991184311629;
                                    end
                                    else
                                    begin
                                        if features.ranker_score_gap <= -75646450.999999985 then
                                        begin
                                            Result := 0.0052537272360847868;
                                        end
                                        else
                                        begin
                                            Result := 0.024406931727320526;
                                        end;
                                    end;
                                end;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r1 <= -8528.4999999999982 then
                                begin
                                    Result := 0.042460360766186478;
                                end
                                else
                                begin
                                    Result := 0.010640681124045981;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.023515346517597832;
                end;
            end
            else
            begin
                Result := -0.010020060938662008;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_70(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.018551147625211512;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_local_lm_r3 <= -5328.4999999999991 then
            begin
                Result := -0.0059404329098000155;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -917.49999999999989 then
                begin
                    Result := -0.0081377359734236474;
                end
                else
                begin
                    Result := 0.022200177188292224;
                end;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r2 <= -4097.4999999999991 then
                begin
                    if features.delta_complete_dictionary <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= -732.49999999999989 then
                        begin
                            Result := 0.0031295236230849005;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= 1371.5000000000002 then
                            begin
                                if features.delta_word_lm_boundary_last <= -1558.4999999999998 then
                                begin
                                    Result := 0.045872152436713901;
                                end
                                else
                                begin
                                    Result := 0.012861320715438735;
                                end;
                            end
                            else
                            begin
                                Result := 0.00082757840642883919;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                        begin
                            if features.same_suffix_units <= 1.0000000180025095E-35 then
                            begin
                                if features.candidate_local_lm_r1 <= -10072.499999999998 then
                                begin
                                    Result := 0.032983314873500168;
                                end
                                else
                                begin
                                    Result := -0.0066723973782727474;
                                end;
                            end
                            else
                            begin
                                if features.delta_local_lm_r1 <= -2233.4999999999995 then
                                begin
                                    Result := -0.010250139443431346;
                                end
                                else
                                begin
                                    Result := 0.0064314022643710963;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0045255945622001094;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0074991610251141042;
                end;
            end
            else
            begin
                Result := -0.010807419418610078;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_71(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.018427184022328274;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.delta_chain_score_gap <= -240352822.99999997 then
            begin
                Result := 0.037785408043343301;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3429.4999999999995 then
                begin
                    Result := -0.0063229428165138823;
                end
                else
                begin
                    Result := 0.0093139594795691276;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.016157309382100523;
            end
            else
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.top_local_lm_r0 <= -8125.4999999999991 then
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := -0.0032608312856296389;
                        end
                        else
                        begin
                            Result := 0.0067473394890587004;
                        end;
                    end
                    else
                    begin
                        if features.candidate_chain_score_gap <= -155565508.99999997 then
                        begin
                            Result := 0.039623391129919645;
                        end
                        else
                        begin
                            if features.top_local_lm_r0 <= -6066.4999999999991 then
                            begin
                                if features.top_local_lm_r0 <= -6437.4999999999991 then
                                begin
                                    Result := 0.0052447109284555317;
                                end
                                else
                                begin
                                    if features.top_local_lm_r0 <= -6280.4999999999991 then
                                    begin
                                        Result := 0.032680551857931887;
                                    end
                                    else
                                    begin
                                        if features.candidate_local_lm_r0 <= -6828.4999999999991 then
                                        begin
                                            Result := -0.006389536389088373;
                                        end
                                        else
                                        begin
                                            Result := 0.021472767684176448;
                                        end;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.0022129330837154819;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -185.49999999999997 then
                    begin
                        Result := -0.0087758025848209548;
                    end
                    else
                    begin
                        Result := 0.0096213315190691925;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_72(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.018301894457025496;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_chain_score_gap <= -209488814.49999997 then
            begin
                Result := 0.021086543050211189;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3429.4999999999995 then
                begin
                    Result := -0.0066896325106495366;
                end
                else
                begin
                    Result := 0.0091444980231622421;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.016018599808920998;
            end
            else
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.top_local_lm_r0 <= -8125.4999999999991 then
                    begin
                        Result := 6.7468291380090139E-05;
                    end
                    else
                    begin
                        if features.candidate_chain_score_gap <= -155565508.99999997 then
                        begin
                            Result := 0.037692506352462171;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= -2001.4999999999998 then
                            begin
                                if features.top_local_lm_r1 <= -8620.4999999999982 then
                                begin
                                    Result := -0.010686203328475308;
                                end
                                else
                                begin
                                    if features.delta_path_max_segment_units <= -1.4999999999999998 then
                                    begin
                                        if features.candidate_ranker_score <= 192430479.00000003 then
                                        begin
                                            Result := 0.0076661155966562759;
                                        end
                                        else
                                        begin
                                            Result := 0.053938132102825956;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.0013212106379434372;
                                    end;
                                end;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r0 <= -8960.4999999999982 then
                                begin
                                    Result := 0.027623336185181258;
                                end
                                else
                                begin
                                    Result := 0.0056573616250668417;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -108.49999999999999 then
                    begin
                        Result := -0.0076162495269279668;
                    end
                    else
                    begin
                        Result := 0.01217842134682675;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_73(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.018175290403890793;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_local_lm_r3 <= -5328.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
                begin
                    Result := -0.0023202325079196284;
                end
                else
                begin
                    Result := -0.012893074789804337;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -917.49999999999989 then
                begin
                    Result := -0.0081019861936604091;
                end
                else
                begin
                    Result := 0.021148496653459033;
                end;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= -23397226.499999996 then
            begin
                if features.delta_complete_pool_consensus_nearest_distance <= 1.0000000180025095E-35 then
                begin
                    Result := -0.0066684830817353271;
                end
                else
                begin
                    if features.delta_complete_pool_signature_support <= -11.499999999999998 then
                    begin
                        Result := -0.00056319915198561974;
                    end
                    else
                    begin
                        if features.delta_local_lm_r2 <= -222.49999999999997 then
                        begin
                            if features.top_local_lm_r1 <= -5508.4999999999991 then
                            begin
                                if features.candidate_complete_pool_consensus_unanimous_units <= 5.5000000000000009 then
                                begin
                                    if features.candidate_local_lm_r0 <= -5783.4999999999991 then
                                    begin
                                        Result := 0.013350790566882152;
                                    end
                                    else
                                    begin
                                        Result := 0.034811668609226118;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0052433507074459186;
                                end;
                            end
                            else
                            begin
                                Result := -0.0016514772743358456;
                            end;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= -732.49999999999989 then
                            begin
                                Result := -0.0023435058844117757;
                            end
                            else
                            begin
                                Result := 0.0053346039963965732;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.candidate_chain_first_stage_score <= 151593.50000000003 then
                begin
                    Result := 0.006525437556783982;
                end
                else
                begin
                    Result := 0.037629517539765317;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_74(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.018047385917892275;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_chain_score_gap <= -209488814.49999997 then
            begin
                Result := 0.020382278664216075;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3429.4999999999995 then
                begin
                    Result := -0.0064785104891720586;
                end
                else
                begin
                    Result := 0.0087688610180306718;
                end;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r2 <= -4097.4999999999991 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= -732.49999999999989 then
                        begin
                            Result := 0.0028731721704871455;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= 1371.5000000000002 then
                            begin
                                if features.candidate_complete_pool_consensus_support <= 899.50000000000011 then
                                begin
                                    Result := 0.0097694342175225352;
                                end
                                else
                                begin
                                    Result := 0.025879750690041278;
                                end;
                            end
                            else
                            begin
                                Result := 0.00056239000959373386;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                        begin
                            if features.same_suffix_units <= 1.0000000180025095E-35 then
                            begin
                                if features.candidate_local_lm_r1 <= -10072.499999999998 then
                                begin
                                    Result := 0.03129004483946745;
                                end
                                else
                                begin
                                    Result := -0.006770559814231661;
                                end;
                            end
                            else
                            begin
                                if features.candidate_ranker_score <= 102045798.00000001 then
                                begin
                                    Result := 0.0013445454056938847;
                                end
                                else
                                begin
                                    Result := 0.008712716548869558;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0045937531315934626;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0073692443558462497;
                end;
            end
            else
            begin
                Result := -0.010725224705862652;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_75(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.0179181962266701;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.delta_chain_score_gap <= -240352822.99999997 then
            begin
                Result := 0.034947393132202881;
            end
            else
            begin
                Result := -0.0043523823988610216;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 159419056.50000003 then
            begin
                if features.delta_complete_pool_consensus_support_min <= -126.49999999999999 then
                begin
                    if features.delta_local_lm_r3 <= -141.49999999999997 then
                    begin
                        if features.ranker_score_gap <= -107767783.49999999 then
                        begin
                            Result := 0.0025790438448142026;
                        end
                        else
                        begin
                            Result := 0.014997073926014801;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 110.25000000000001 then
                        begin
                            if features.delta_path_max_segment_units <= 4.5000000000000009 then
                            begin
                                Result := -0.0034467784430065995;
                            end
                            else
                            begin
                                Result := 0.032583735240122744;
                            end;
                        end
                        else
                        begin
                            if features.delta_dict_weight_per_unit <= -4654.4999999999991 then
                            begin
                                if features.top_local_lm_r1 <= -6869.4999999999991 then
                                begin
                                    Result := 0.0051881890338378788;
                                end
                                else
                                begin
                                    if features.top_local_lm_r3 <= -5604.4999999999991 then
                                    begin
                                        Result := 0.038909000521785586;
                                    end
                                    else
                                    begin
                                        Result := -0.006975914327532271;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.0027824204434441506;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.ranker_score_gap <= -82728720.499999985 then
                    begin
                        Result := -0.00911082774069185;
                    end
                    else
                    begin
                        Result := 0.0013167659929142828;
                    end;
                end;
            end
            else
            begin
                if features.top_ranker_score <= 169338120.00000003 then
                begin
                    Result := 0.033365089706869966;
                end
                else
                begin
                    Result := 0.0049602431963204109;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_76(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.01778773763444929;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_local_lm_r3 <= -5328.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
                begin
                    Result := -0.0020805680781358629;
                end
                else
                begin
                    Result := -0.012612999444914858;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -917.49999999999989 then
                begin
                    Result := -0.0079611840157252766;
                end
                else
                begin
                    Result := 0.020375001385279118;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.015901529460241433;
            end
            else
            begin
                if features.top_local_lm_r2 <= -4097.4999999999991 then
                begin
                    if features.candidate_ranker_score <= 159419056.50000003 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= -126.49999999999999 then
                        begin
                            if features.delta_local_lm_r3 <= -124.49999999999999 then
                            begin
                                if features.ranker_score_gap <= -107767783.49999999 then
                                begin
                                    Result := 0.0038906317722265621;
                                end
                                else
                                begin
                                    if features.top_local_lm_r3 <= -6343.4999999999991 then
                                    begin
                                        Result := 0.020391920796588105;
                                    end
                                    else
                                    begin
                                        Result := 0.0033632076875585726;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.00093239893024931505;
                            end;
                        end
                        else
                        begin
                            if features.ranker_score_gap <= -82728720.499999985 then
                            begin
                                Result := -0.0088179178087424964;
                            end
                            else
                            begin
                                Result := 0.0019480092443155796;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 169338120.00000003 then
                        begin
                            Result := 0.032061196326693978;
                        end
                        else
                        begin
                            Result := 0.0054274841591346948;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0073129937328918456;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_77(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.017656027326389025;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.candidate_chain_score_gap <= -209488814.49999997 then
            begin
                Result := 0.019456654069324439;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3429.4999999999995 then
                begin
                    Result := -0.0061919324580462067;
                end
                else
                begin
                    Result := 0.0085434999112175402;
                end;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.delta_word_lm_boundary_count <= -2.4999999999999996 then
                    begin
                        Result := -0.0060986731432946771;
                    end
                    else
                    begin
                        if features.top_local_lm_r1 <= -7543.4999999999991 then
                        begin
                            if features.delta_word_lm_boundary_last <= -1558.4999999999998 then
                            begin
                                if features.delta_local_lm_r0 <= -1058.4999999999998 then
                                begin
                                    Result := -0.0015392054770480782;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_consensus_mean_distance <= 3937.5000000000005 then
                                    begin
                                        Result := 0.061687208220324266;
                                    end
                                    else
                                    begin
                                        Result := 0.0078632274492906572;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.0012700031425925886;
                            end;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= 191.50000000000003 then
                            begin
                                Result := 0.0050117834484208782;
                            end
                            else
                            begin
                                Result := 0.016304468587107625;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -185.49999999999997 then
                    begin
                        Result := -0.0085824421023350684;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= -8.8749999999999982 then
                        begin
                            Result := -0.0016512349924291993;
                        end
                        else
                        begin
                            Result := 0.02243127398567284;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.010562109623663538;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_78(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.017523083770836251;
    end
    else
    begin
        if features.ranker_score_gap <= -84935356.999999985 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.010702376869349358;
            end
            else
            begin
                if features.delta_complete_pool_signature_support <= -10.499999999999998 then
                begin
                    if features.delta_complete_pool_consensus_support <= -53.499999999999993 then
                    begin
                        Result := 0.0027244247786001353;
                    end
                    else
                    begin
                        if features.delta_word_lm_boundary_count <= 3.5000000000000004 then
                        begin
                            Result := -0.0078693600457969536;
                        end
                        else
                        begin
                            if features.delta_char_lm_suffix_score <= -32.499999999999993 then
                            begin
                                Result := -0.0092686571716236749;
                            end
                            else
                            begin
                                Result := 0.026475242874583079;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_nearest_distance <= 1.5000000000000002 then
                    begin
                        Result := 0.0051525794876495709;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= 1369.5000000000002 then
                        begin
                            if features.candidate_complete_pool_signature_support <= 11.500000000000002 then
                            begin
                                Result := -0.0075333105176191503;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -5202.4999999999991 then
                                begin
                                    if features.candidate_word_lm_boundary_count <= 5.5000000000000009 then
                                    begin
                                        Result := 0.027609037794140263;
                                    end
                                    else
                                    begin
                                        Result := 0.0039059166329962198;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0091214532805897804;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.same_suffix_units <= 1.5000000000000002 then
                            begin
                                Result := -0.0055391248987302329;
                            end
                            else
                            begin
                                Result := 0.048407981392908014;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_complete_pool_signature_support <= 28.500000000000004 then
            begin
                Result := 0.005277044393720072;
            end
            else
            begin
                Result := -0.0039087399479568975;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_79(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.017388927983578127;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            Result := -0.0076647812471177974;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := -0.0047252153661984054;
            end
            else
            begin
                if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                begin
                    Result := -0.00059139923891739178;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -3355.4999999999995 then
                    begin
                        Result := -0.0087673800876474743;
                    end
                    else
                    begin
                        if features.delta_path_max_segment_units <= 4.5000000000000009 then
                        begin
                            if features.ranker_score_gap <= 1.0000000180025095E-35 then
                            begin
                                if features.delta_local_lm_r2 <= -244.49999999999997 then
                                begin
                                    if features.ranker_score_gap <= -119618426.99999999 then
                                    begin
                                        if features.delta_complete_pool_consensus_mean_distance <= 2535.5000000000005 then
                                        begin
                                            if features.delta_path_single_segments <= 3.5000000000000004 then
                                            begin
                                                Result := 0.0030707799623703211;
                                            end
                                            else
                                            begin
                                                if features.candidate_local_lm_r1 <= -7293.4999999999991 then
                                                begin
                                                    Result := 0.044290780306673432;
                                                end
                                                else
                                                begin
                                                    Result := 0.0075040513380225981;
                                                end;
                                            end;
                                        end
                                        else
                                        begin
                                            Result := -0.0087078768988865535;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.014686587298849148;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0015318424759101891;
                                end;
                            end
                            else
                            begin
                                if features.delta_dict_weight <= -77131.499999999985 then
                                begin
                                    Result := 0.025338918914157061;
                                end
                                else
                                begin
                                    if features.candidate_path_segments <= 4.5000000000000009 then
                                    begin
                                        Result := 0.031107853610033789;
                                    end
                                    else
                                    begin
                                        Result := 0.0028732383807624755;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.023126772387935719;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_80(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.017253580052108693;
    end
    else
    begin
        if features.ranker_score_gap <= -180752811.49999997 then
        begin
            if features.delta_chain_score_gap <= -240352822.99999997 then
            begin
                Result := 0.033015559705299458;
            end
            else
            begin
                if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
                begin
                    if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                    begin
                        Result := -0.016788299004640555;
                    end
                    else
                    begin
                        Result := 0.0009005503259412722;
                    end;
                end
                else
                begin
                    Result := -0.010846668780663482;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.01569399558233233;
            end
            else
            begin
                if features.top_local_lm_r2 <= -4097.4999999999991 then
                begin
                    if features.candidate_ranker_score <= 159419056.50000003 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= -126.49999999999999 then
                        begin
                            if features.delta_local_lm_r3 <= -124.49999999999999 then
                            begin
                                if features.candidate_word_lm_boundary_count <= 8.5000000000000018 then
                                begin
                                    if features.candidate_local_lm_r3 <= -7086.4999999999991 then
                                    begin
                                        Result := 0.01487366855914005;
                                    end
                                    else
                                    begin
                                        Result := 0.0028503491708928132;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0068802930574196472;
                                end;
                            end
                            else
                            begin
                                Result := 0.00069422620262152073;
                            end;
                        end
                        else
                        begin
                            if features.ranker_score_gap <= -82728720.499999985 then
                            begin
                                Result := -0.0086479075223746919;
                            end
                            else
                            begin
                                Result := 0.0017149279847479258;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 186873174.50000003 then
                        begin
                            Result := 0.025708933829240568;
                        end
                        else
                        begin
                            Result := 0.0049471577470605252;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0072585296875634824;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_81(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        Result := -0.017117062858702837;
    end
    else
    begin
        if features.ranker_score_gap <= -63822726.499999993 then
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := -0.0092539125631540663;
            end
            else
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    Result := -0.0099014543990778962;
                end
                else
                begin
                    if features.delta_chain_score_gap <= -233528645.99999997 then
                    begin
                        Result := 0.035960386040872143;
                    end
                    else
                    begin
                        if features.delta_score_per_unit <= -29.499999999999996 then
                        begin
                            if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                            begin
                                Result := -0.0068011755656792018;
                            end
                            else
                            begin
                                if features.delta_char_lm_score <= 362.50000000000006 then
                                begin
                                    Result := 0.0025484544427186616;
                                end
                                else
                                begin
                                    Result := 0.038537787917791333;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_dict_weight <= 48135.500000000007 then
                            begin
                                if features.candidate_local_lm_r2 <= -8162.4999999999991 then
                                begin
                                    if features.top_local_lm_r0 <= -8037.4999999999991 then
                                    begin
                                        Result := -0.00040624639948501546;
                                    end
                                    else
                                    begin
                                        if features.delta_complete_pool_consensus_support_min <= -179.49999999999997 then
                                        begin
                                            if features.delta_char_suffix_lm_per_difference <= -536.83333333333314 then
                                            begin
                                                Result := 0.05801666720987099;
                                            end
                                            else
                                            begin
                                                Result := 0.017872584998185399;
                                            end;
                                        end
                                        else
                                        begin
                                            Result := -0.0038768472362847232;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_consensus_support <= 733.50000000000011 then
                                    begin
                                        Result := -0.013504172195210457;
                                    end
                                    else
                                    begin
                                        Result := 0.0035126615616816585;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.0039505472989600143;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.0047878854356917721;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_82(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -295020042.99999994 then
    begin
        if features.ranker_score_gap <= -380833732.99999994 then
        begin
            Result := -0.021857799921225385;
        end
        else
        begin
            Result := -0.0099656269007132522;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -187996593.49999997 then
        begin
            if features.candidate_chain_score_gap <= -209488814.49999997 then
            begin
                Result := 0.018177087483102466;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -5522.4999999999991 then
                begin
                    Result := -0.0061557952516678588;
                end
                else
                begin
                    Result := 0.011169376387272795;
                end;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.015909608093679344;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                begin
                    Result := 0.0019511872325415104;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8655.4999999999982 then
                    begin
                        if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                        begin
                            if features.delta_word_lm_bonus <= 80.500000000000014 then
                            begin
                                Result := 0.048620493923425913;
                            end
                            else
                            begin
                                Result := -0.0022083645785343684;
                            end;
                        end
                        else
                        begin
                            Result := -0.01044465610035122;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -5202.4999999999991 then
                        begin
                            Result := 0.016451113435913503;
                        end
                        else
                        begin
                            if features.delta_dict_weight_per_unit <= -20.499999999999996 then
                            begin
                                if features.top_local_lm_r1 <= -7543.4999999999991 then
                                begin
                                    Result := -0.0011944153405130948;
                                end
                                else
                                begin
                                    if features.ranker_score_gap <= -63822726.499999993 then
                                    begin
                                        Result := 0.0086392833364038867;
                                    end
                                    else
                                    begin
                                        Result := 0.053033676399549305;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.0052104271262812911;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_83(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -300941054.49999994 then
    begin
        Result := -0.01721641567927713;
    end
    else
    begin
        if features.ranker_score_gap <= -187996593.49999997 then
        begin
            if features.delta_chain_score_gap <= -240352822.99999997 then
            begin
                Result := 0.031419812516510874;
            end
            else
            begin
                Result := -0.0043914842082388638;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.candidate_word_lm_zero_count <= 9.5000000000000018 then
                    begin
                        if features.ranker_score_gap <= 12371962.500000002 then
                        begin
                            if features.top_local_lm_r1 <= -7586.4999999999991 then
                            begin
                                if features.candidate_local_lm_r0 <= -6124.4999999999991 then
                                begin
                                    Result := -0.0010297579984340859;
                                end
                                else
                                begin
                                    if features.same_prefix_units <= 3.5000000000000004 then
                                    begin
                                        Result := 0.017152076359814295;
                                    end
                                    else
                                    begin
                                        Result := -0.0029492204581992158;
                                    end;
                                end;
                            end
                            else
                            begin
                                if features.delta_word_lm_boundary_count <= -2.4999999999999996 then
                                begin
                                    Result := -0.0077785609886818529;
                                end
                                else
                                begin
                                    if features.delta_char_lm_per_difference <= 426.37500000000006 then
                                    begin
                                        Result := 0.0054375474810438272;
                                    end
                                    else
                                    begin
                                        Result := 0.030092896301426593;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.011073924382689702;
                        end;
                    end
                    else
                    begin
                        Result := -0.0047298759976909391;
                    end;
                end
                else
                begin
                    if features.delta_char_lm_per_difference <= 73.125000000000014 then
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := 0.0027017110162547101;
                        end
                        else
                        begin
                            Result := -0.010950993883194439;
                        end;
                    end
                    else
                    begin
                        Result := 0.019300279802173755;
                    end;
                end;
            end
            else
            begin
                Result := -0.010684160141636747;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_84(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -300941054.49999994 then
    begin
        Result := -0.017079887209832677;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.ranker_score_gap <= -75646450.999999985 then
            begin
                if features.candidate_word_lm_boundary_count <= 8.5000000000000018 then
                begin
                    if features.delta_complete_pool_consensus_support_min <= -173.49999999999997 then
                    begin
                        if features.candidate_complete_pool_signature_support <= 11.500000000000002 then
                        begin
                            Result := -0.0015448461789730511;
                        end
                        else
                        begin
                            Result := 0.0084895154460418905;
                        end;
                    end
                    else
                    begin
                        Result := -0.007514312773646079;
                    end;
                end
                else
                begin
                    Result := -0.012698664124934301;
                end;
            end
            else
            begin
                if features.candidate_complete_pool_signature_support <= 18.500000000000004 then
                begin
                    if features.delta_complete_pool_signature_support <= -14.499999999999998 then
                    begin
                        Result := -0.0027598577620749376;
                    end
                    else
                    begin
                        if features.candidate_complete_pool_consensus_support <= 681.50000000000011 then
                        begin
                            Result := -0.01042549410820634;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_pair_evidence <= 1312.5000000000002 then
                            begin
                                Result := 0.0076654258620117328;
                            end
                            else
                            begin
                                if features.candidate_complete_pool_consensus_support <= 889.50000000000011 then
                                begin
                                    if features.candidate_path_segments <= 8.5000000000000018 then
                                    begin
                                        Result := 0.050286799033654343;
                                    end
                                    else
                                    begin
                                        Result := 0.00093595196254425217;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0080865762238257199;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0058297086683280867;
                end;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_support_min <= 423.50000000000006 then
                begin
                    Result := 0.037871556965818315;
                end
                else
                begin
                    Result := -0.0034898842006864856;
                end;
            end
            else
            begin
                Result := 0.0031855555762782817;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_85(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -313895743.49999994 then
    begin
        Result := -0.017737266839702889;
    end
    else
    begin
        if features.ranker_score_gap <= -207318351.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5522.4999999999991 then
            begin
                Result := -0.0064352991134595632;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -653.49999999999989 then
                begin
                    Result := -0.0050034551808625155;
                end
                else
                begin
                    if features.same_suffix_units <= 1.5000000000000002 then
                    begin
                        Result := -0.0067317797881044613;
                    end
                    else
                    begin
                        Result := 0.052983984654396465;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -155565508.99999997 then
            begin
                Result := 0.019917792304279917;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.016987960659469632;
                end
                else
                begin
                    if features.ranker_score_gap <= -54642305.999999993 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= 274.50000000000006 then
                        begin
                            Result := 0.0014626468529698434;
                        end
                        else
                        begin
                            Result := -0.0094662361553288776;
                        end;
                    end
                    else
                    begin
                        if features.candidate_path_max_segment_units <= 2.5000000000000004 then
                        begin
                            if features.candidate_dict_weight <= 168319.50000000003 then
                            begin
                                Result := 0.0025972961860003495;
                            end
                            else
                            begin
                                Result := 0.036518113854174264;
                            end;
                        end
                        else
                        begin
                            if features.delta_source_rule_fallback <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.0070692711119084862;
                            end
                            else
                            begin
                                if features.delta_complete_pool_pair_evidence <= 1312.5000000000002 then
                                begin
                                    if features.delta_word_lm_supported_ratio <= -13.499999999999998 then
                                    begin
                                        Result := 0.0066579782873153262;
                                    end
                                    else
                                    begin
                                        Result := 0.0521217124703936;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0030392518399336051;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_86(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -313895743.49999994 then
    begin
        Result := -0.017606083195715744;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                Result := -0.0064424197692162666;
            end
            else
            begin
                Result := 0.01906780779845289;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -170087355.49999997 then
            begin
                if features.candidate_local_lm_r1 <= -6852.4999999999991 then
                begin
                    Result := 0.0079513784976161534;
                end
                else
                begin
                    Result := 0.048482006943299627;
                end;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.017239214622670727;
                end
                else
                begin
                    if features.top_local_lm_r1 <= -4542.4999999999991 then
                    begin
                        if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                        begin
                            if features.candidate_local_lm_r1 <= -5628.4999999999991 then
                            begin
                                Result := 0.003688245812808741;
                            end
                            else
                            begin
                                if features.delta_score_per_unit <= -1.0000000180025095E-35 then
                                begin
                                    Result := 0.054255659513418458;
                                end
                                else
                                begin
                                    Result := 0.0096097001798579867;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_local_lm_r3 <= 109.50000000000001 then
                            begin
                                if features.candidate_word_lm_boundary_count <= 8.5000000000000018 then
                                begin
                                    if features.delta_char_lm_per_difference <= -468.83333333333331 then
                                    begin
                                        Result := -0.002477544785443164;
                                    end
                                    else
                                    begin
                                        Result := 0.005472120839966268;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0068229988273092734;
                                end;
                            end
                            else
                            begin
                                Result := -0.004236963165951668;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -786.49999999999989 then
                        begin
                            Result := -0.014946277129563946;
                        end
                        else
                        begin
                            Result := 0.0033759247315629606;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_87(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -313895743.49999994 then
    begin
        Result := -0.017473674141275573;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.ranker_score_gap <= -75646450.999999985 then
            begin
                if features.candidate_text_units <= 8.5000000000000018 then
                begin
                    if features.top_local_lm_r0 <= -8073.4999999999991 then
                    begin
                        Result := -0.0068866793206964656;
                    end
                    else
                    begin
                        Result := 0.0040202800043083941;
                    end;
                end
                else
                begin
                    Result := -0.0061889343521963928;
                end;
            end
            else
            begin
                if features.candidate_complete_pool_pair_evidence <= 1348.5000000000002 then
                begin
                    Result := 0.00098115255168242273;
                end
                else
                begin
                    if features.top_local_lm_r0 <= -5470.4999999999991 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= -275.49999999999994 then
                        begin
                            Result := 0.029270268599225102;
                        end
                        else
                        begin
                            Result := 0.0077575254895575017;
                        end;
                    end
                    else
                    begin
                        Result := -0.0070996613575406049;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6154.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_support_min <= 445.50000000000006 then
                begin
                    if features.delta_local_lm_r0 <= -2215.4999999999995 then
                    begin
                        Result := 0.0;
                    end
                    else
                    begin
                        if features.candidate_word_lm_boundary_first <= 1339.5000000000002 then
                        begin
                            Result := 0.046536520850238614;
                        end
                        else
                        begin
                            Result := 0.0010898839062740528;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0054801309378146746;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -2233.4999999999995 then
                begin
                    if features.top_local_lm_r1 <= -6350.4999999999991 then
                    begin
                        Result := 0.017133997740223707;
                    end
                    else
                    begin
                        Result := -0.017330268697958291;
                    end;
                end
                else
                begin
                    Result := 0.0034335181457856717;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_88(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_local_lm_r1 <= -2233.4999999999995 then
    begin
        if features.top_local_lm_r1 <= -5885.4999999999991 then
        begin
            if features.candidate_local_lm_r1 <= -10674.499999999998 then
            begin
                if features.same_prefix_units <= 4.5000000000000009 then
                begin
                    Result := -0.0059435498216283238;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -2886.4999999999995 then
                    begin
                        Result := 0.051352678344569441;
                    end
                    else
                    begin
                        Result := -0.011432669843274859;
                    end;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.010446450740195451;
                end
                else
                begin
                    Result := 0.013994584696982795;
                end;
            end;
        end
        else
        begin
            Result := -0.01982055568835614;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.difference_span_units <= 2.5000000000000004 then
            begin
                if features.top_ranker_score <= 260257748.50000003 then
                begin
                    if features.candidate_char_lm_suffix_score <= -5505.4999999999991 then
                    begin
                        if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                        begin
                            if features.delta_char_lm_per_difference <= -343.91666666666657 then
                            begin
                                Result := -0.0034703541905961007;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r0 <= -7236.4999999999991 then
                                begin
                                    Result := -0.00045385868630942717;
                                end
                                else
                                begin
                                    Result := 0.0086952188615054236;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0027045049646599048;
                        end;
                    end
                    else
                    begin
                        Result := 0.040140228710272341;
                    end;
                end
                else
                begin
                    Result := -0.00982046789204917;
                end;
            end
            else
            begin
                Result := -0.011145313691973122;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6105.4999999999991 then
            begin
                Result := 0.01848592845129866;
            end
            else
            begin
                Result := 0.0032264239962262742;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_89(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -313895743.49999994 then
    begin
        Result := -0.017250907612131768;
    end
    else
    begin
        if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
        begin
            Result := -0.0052568595621649353;
        end
        else
        begin
            if features.candidate_ranker_score <= -427882151.99999994 then
            begin
                Result := -0.017831045446116658;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -3355.4999999999995 then
                begin
                    Result := -0.0078265029234101755;
                end
                else
                begin
                    if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                    begin
                        Result := -0.00077156245124409585;
                    end
                    else
                    begin
                        if features.ranker_score_gap <= 1.0000000180025095E-35 then
                        begin
                            if features.top_local_lm_r2 <= -8404.4999999999982 then
                            begin
                                Result := -0.0031018378017955289;
                            end
                            else
                            begin
                                if features.delta_complete_pool_consensus_mean_distance <= 2535.5000000000005 then
                                begin
                                    if features.candidate_local_lm_r2 <= -8162.4999999999991 then
                                    begin
                                        if features.delta_chain_second_stage_score <= -154230565.49999997 then
                                        begin
                                            Result := 0.044649525227381893;
                                        end
                                        else
                                        begin
                                            if features.delta_local_lm_r2 <= -2090.4999999999995 then
                                            begin
                                                Result := 0.042884320146624376;
                                            end
                                            else
                                            begin
                                                Result := 0.0071661584945491297;
                                            end;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.0040589062279171844;
                                    end;
                                end
                                else
                                begin
                                    if features.delta_local_lm_r1 <= 1813.5000000000002 then
                                    begin
                                        Result := -0.0029826967348912689;
                                    end
                                    else
                                    begin
                                        Result := 0.043808844682102402;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_dict_weight <= -77131.499999999985 then
                            begin
                                if features.candidate_word_lm_bonus <= 188.50000000000003 then
                                begin
                                    Result := 0.011835052540045321;
                                end
                                else
                                begin
                                    Result := 0.044071294051996959;
                                end;
                            end
                            else
                            begin
                                Result := 0.0053125327144454455;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_90(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -356037548.99999994 then
    begin
        Result := -0.019684936012027209;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                Result := -0.006649865637853739;
            end
            else
            begin
                Result := 0.01816062091996468;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -170087355.49999997 then
            begin
                Result := 0.02271558797980508;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.016923925734396029;
                end
                else
                begin
                    if features.top_local_lm_r1 <= -4542.4999999999991 then
                    begin
                        if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                        begin
                            if features.candidate_local_lm_r1 <= -5628.4999999999991 then
                            begin
                                Result := 0.0034288597837439394;
                            end
                            else
                            begin
                                if features.delta_score_per_unit <= -1.0000000180025095E-35 then
                                begin
                                    Result := 0.05100507802261528;
                                end
                                else
                                begin
                                    Result := 0.0090450032311430398;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                            begin
                                if features.same_suffix_units <= 1.0000000180025095E-35 then
                                begin
                                    if features.candidate_local_lm_r1 <= -10250.499999999998 then
                                    begin
                                        Result := 0.032684329293989969;
                                    end
                                    else
                                    begin
                                        Result := -0.0069478171676981854;
                                    end;
                                end
                                else
                                begin
                                    if features.delta_local_lm_r1 <= -2233.4999999999995 then
                                    begin
                                        Result := -0.0097180591432442093;
                                    end
                                    else
                                    begin
                                        Result := 0.0049891066525343773;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.00638179920400243;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -786.49999999999989 then
                        begin
                            Result := -0.014748357042348267;
                        end
                        else
                        begin
                            Result := 0.0030707594502630935;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_91(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -356037548.99999994 then
    begin
        Result := -0.019578100129954572;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                Result := -0.0065275631758950244;
            end
            else
            begin
                Result := 0.017521771850307746;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -170087355.49999997 then
            begin
                if features.candidate_local_lm_r1 <= -6852.4999999999991 then
                begin
                    Result := 0.0070902153809850243;
                end
                else
                begin
                    Result := 0.044669885787225833;
                end;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.016791468233289353;
                end
                else
                begin
                    if features.ranker_score_gap <= -23397226.499999996 then
                    begin
                        if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                        begin
                            Result := -0.0056221421964191545;
                        end
                        else
                        begin
                            if features.delta_path_max_segment_units <= 4.5000000000000009 then
                            begin
                                Result := 0.0012925575285332161;
                            end
                            else
                            begin
                                if features.delta_char_suffix_lm_per_difference <= 96.142857142857153 then
                                begin
                                    if features.candidate_local_lm_r0 <= -4422.4999999999991 then
                                    begin
                                        if features.top_local_lm_r0 <= -5880.4999999999991 then
                                        begin
                                            Result := 0.050531760494162151;
                                        end
                                        else
                                        begin
                                            Result := -0.0002243509466644807;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := -0.010199243054816164;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0054256034253145485;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.candidate_chain_first_stage_score <= 151593.50000000003 then
                        begin
                            if features.delta_local_lm_r1 <= 548.50000000000011 then
                            begin
                                Result := 0.0091888602564995075;
                            end
                            else
                            begin
                                Result := 0.00053829846120174627;
                            end;
                        end
                        else
                        begin
                            Result := 0.03658333740471173;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_92(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -356037548.99999994 then
    begin
        Result := -0.01946988492751911;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5522.4999999999991 then
            begin
                Result := -0.0067228629037425838;
            end
            else
            begin
                Result := 0.012274010840586986;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -170087355.49999997 then
            begin
                Result := 0.021043599643860888;
            end
            else
            begin
                if features.difference_span_units <= 3.5000000000000004 then
                begin
                    if features.top_local_lm_r1 <= -4542.4999999999991 then
                    begin
                        if features.delta_local_lm_r0 <= -3355.4999999999995 then
                        begin
                            Result := -0.0067501805206401479;
                        end
                        else
                        begin
                            if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                            begin
                                Result := 0.0048892561465605708;
                            end
                            else
                            begin
                                if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                                begin
                                    if features.same_suffix_units <= 1.0000000180025095E-35 then
                                    begin
                                        if features.candidate_local_lm_r1 <= -10072.499999999998 then
                                        begin
                                            Result := 0.021839104186862288;
                                        end
                                        else
                                        begin
                                            Result := -0.0072698020286323401;
                                        end;
                                    end
                                    else
                                    begin
                                        if features.candidate_ranker_score <= -37322218.999999993 then
                                        begin
                                            Result := -0.0018790830111110508;
                                        end
                                        else
                                        begin
                                            Result := 0.0061153879625860256;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0056449711213779497;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -786.49999999999989 then
                        begin
                            Result := -0.014595364434079217;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 65.125000000000014 then
                            begin
                                Result := -0.00038641523145130043;
                            end
                            else
                            begin
                                Result := 0.028839751179315677;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.011324582315366535;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_93(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.021146699555172885;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                if features.candidate_score_per_unit <= 12736.000000000002 then
                begin
                    Result := -0.0092654531180352481;
                end
                else
                begin
                    if features.delta_path_single_segments <= 2.5000000000000004 then
                    begin
                        if features.candidate_local_lm_r0 <= -8794.4999999999982 then
                        begin
                            Result := 0.016173404081937928;
                        end
                        else
                        begin
                            Result := -0.0078926183413736452;
                        end;
                    end
                    else
                    begin
                        Result := 0.04579541307572358;
                    end;
                end;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3587.4999999999995 then
                begin
                    Result := -0.0031358668737292653;
                end
                else
                begin
                    Result := 0.040288449916851765;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -170087355.49999997 then
            begin
                Result := 0.020205990282669277;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.0166273556529795;
                end
                else
                begin
                    if features.ranker_score_gap <= -54642305.999999993 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= 274.50000000000006 then
                        begin
                            if features.delta_local_lm_r3 <= 17.500000000000004 then
                            begin
                                Result := 0.0026941391658266739;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r1 <= -6243.4999999999991 then
                                begin
                                    Result := -0.0047170099471131304;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_consensus_support_min <= 234.50000000000003 then
                                    begin
                                        Result := 0.020463845394278243;
                                    end
                                    else
                                    begin
                                        Result := -0.0012175057865184363;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0093580284970712566;
                        end;
                    end
                    else
                    begin
                        Result := 0.0042217826166222865;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_94(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_local_lm_r1 <= -2233.4999999999995 then
    begin
        if features.top_local_lm_r1 <= -5508.4999999999991 then
        begin
            if features.candidate_local_lm_r1 <= -10674.499999999998 then
            begin
                if features.same_prefix_units <= 4.5000000000000009 then
                begin
                    Result := -0.0057301715039340239;
                end
                else
                begin
                    if features.delta_local_lm_r2 <= -2090.4999999999995 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= -475.49999999999994 then
                        begin
                            Result := -0.0016470535418708872;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
                            begin
                                Result := 0.083352393159831117;
                            end
                            else
                            begin
                                Result := -0.001958258199329029;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.0086037710208300561;
                    end;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -458.49999999999994 then
                begin
                    Result := -0.010561538318951149;
                end
                else
                begin
                    Result := 0.013514098712640372;
                end;
            end;
        end
        else
        begin
            Result := -0.020821056611630265;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.difference_span_units <= 2.5000000000000004 then
            begin
                if features.top_ranker_score <= 260257748.50000003 then
                begin
                    if features.candidate_char_lm_suffix_score <= -5505.4999999999991 then
                    begin
                        if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                        begin
                            Result := 0.0022970691547785464;
                        end
                        else
                        begin
                            Result := -0.0028029371412072262;
                        end;
                    end
                    else
                    begin
                        Result := 0.038598930986773437;
                    end;
                end
                else
                begin
                    Result := -0.0091735399965261356;
                end;
            end
            else
            begin
                Result := -0.010726455499904699;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6105.4999999999991 then
            begin
                Result := 0.017531911930412161;
            end
            else
            begin
                Result := 0.0029300178082428434;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_95(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.021011207595413351;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_char_lm_score <= -4544.4999999999991 then
            begin
                Result := -0.0091580465891192772;
            end
            else
            begin
                if features.candidate_word_lm_boundary_max <= 1558.5000000000002 then
                begin
                    Result := 0.0078001131646767089;
                end
                else
                begin
                    Result := -0.0091471261334870584;
                end;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.top_local_lm_r1 <= -4542.4999999999991 then
                begin
                    if features.delta_local_lm_r0 <= -3355.4999999999995 then
                    begin
                        Result := -0.0063964607219738154;
                    end
                    else
                    begin
                        if features.candidate_word_lm_zero_count <= 9.5000000000000018 then
                        begin
                            if features.ranker_score_gap <= 12371962.500000002 then
                            begin
                                if features.top_local_lm_r0 <= -8037.4999999999991 then
                                begin
                                    if features.same_prefix_units <= 2.5000000000000004 then
                                    begin
                                        Result := 0.005198635374787491;
                                    end
                                    else
                                    begin
                                        if features.candidate_local_lm_r1 <= -10886.499999999998 then
                                        begin
                                            Result := 0.031429603259288695;
                                        end
                                        else
                                        begin
                                            Result := -0.0046308277088375873;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0037523582376876642;
                                end;
                            end
                            else
                            begin
                                Result := 0.010045198910594019;
                            end;
                        end
                        else
                        begin
                            Result := -0.0047287610839172106;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -622.49999999999989 then
                    begin
                        Result := -0.013768566345782166;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 65.125000000000014 then
                        begin
                            Result := 0.00023639397166267439;
                        end
                        else
                        begin
                            Result := 0.03040348002313888;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.010846332029736505;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_96(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020925439392557331;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                if features.candidate_score_per_unit <= 12736.000000000002 then
                begin
                    Result := -0.008955561740692437;
                end
                else
                begin
                    if features.delta_path_single_segments <= 2.5000000000000004 then
                    begin
                        if features.candidate_local_lm_r0 <= -8794.4999999999982 then
                        begin
                            Result := 0.016009281744800302;
                        end
                        else
                        begin
                            Result := -0.0076305710988386101;
                        end;
                    end
                    else
                    begin
                        Result := 0.043666186872909032;
                    end;
                end;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3587.4999999999995 then
                begin
                    Result := -0.0030375570200884944;
                end
                else
                begin
                    Result := 0.038408090027182762;
                end;
            end;
        end
        else
        begin
            if features.delta_chain_score_gap <= -169703275.49999997 then
            begin
                Result := 0.019212440659220006;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.016501869845798763;
                end
                else
                begin
                    if features.top_local_lm_r1 <= -4542.4999999999991 then
                    begin
                        if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                        begin
                            Result := 0.0039778761590814806;
                        end
                        else
                        begin
                            if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                            begin
                                Result := 0.002178545672054011;
                            end
                            else
                            begin
                                Result := -0.0061732888496127177;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -786.49999999999989 then
                        begin
                            Result := -0.014273909601367743;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 73.125000000000014 then
                            begin
                                Result := -0.00063408482392198536;
                            end
                            else
                            begin
                                Result := 0.03333027653451133;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_97(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020838365284562024;
    end
    else
    begin
        if features.delta_local_lm_r1 <= -2233.4999999999995 then
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r1 <= -10503.499999999998 then
                begin
                    if features.delta_complete_pool_consensus_support_min <= -475.49999999999994 then
                    begin
                        Result := 0.0;
                    end
                    else
                    begin
                        Result := 0.072307668639612785;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -9302.4999999999982 then
                    begin
                        Result := 0.015091231869502099;
                    end
                    else
                    begin
                        Result := -0.013803132598885458;
                    end;
                end;
            end
            else
            begin
                Result := -0.013287722694949903;
            end;
        end
        else
        begin
            if features.candidate_ranker_score <= 111801836.50000001 then
            begin
                if features.difference_span_units <= 2.5000000000000004 then
                begin
                    if features.ranker_score_gap <= -211365280.49999997 then
                    begin
                        Result := -0.0064357281625403925;
                    end
                    else
                    begin
                        if features.candidate_chain_score_gap <= -155565508.99999997 then
                        begin
                            if features.candidate_path_segments <= 4.5000000000000009 then
                            begin
                                Result := -0.0054131751390203136;
                            end
                            else
                            begin
                                Result := 0.035338364671449435;
                            end;
                        end
                        else
                        begin
                            if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                            begin
                                Result := 0.0025903912156598542;
                            end
                            else
                            begin
                                Result := -0.0026063592991853136;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0099761486827659399;
                end;
            end
            else
            begin
                if features.candidate_char_lm_suffix_score <= -6105.4999999999991 then
                begin
                    if features.candidate_complete_pool_consensus_support_min <= 445.50000000000006 then
                    begin
                        Result := 0.022858638248010113;
                    end
                    else
                    begin
                        Result := -0.0037675299381899232;
                    end;
                end
                else
                begin
                    Result := 0.0028872606163950778;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_98(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020749979566379612;
    end
    else
    begin
        if features.ranker_score_gap <= -207318351.99999997 then
        begin
            if features.candidate_text_units <= 9.5000000000000018 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.018290510085610626;
                end
                else
                begin
                    if features.delta_candidate_score <= -1.0000000180025095E-35 then
                    begin
                        if features.candidate_local_lm_r2 <= -5339.9999999999991 then
                        begin
                            if features.candidate_complete_pool_signature_support <= 3.5000000000000004 then
                            begin
                                Result := -0.0096371996902576001;
                            end
                            else
                            begin
                                Result := 0.008265684876121315;
                            end;
                        end
                        else
                        begin
                            Result := 0.033387271751350429;
                        end;
                    end
                    else
                    begin
                        if features.delta_dict_weight_per_unit <= -4195.4999999999991 then
                        begin
                            if features.candidate_local_lm_r1 <= -7532.4999999999991 then
                            begin
                                Result := 0.062623989941936478;
                            end
                            else
                            begin
                                Result := 0.0033708748607480295;
                            end;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r0 <= -8092.4999999999991 then
                            begin
                                if features.top_local_lm_r0 <= -6113.4999999999991 then
                                begin
                                    Result := 0.027218818182619876;
                                end
                                else
                                begin
                                    Result := -0.011235009686140596;
                                end;
                            end
                            else
                            begin
                                Result := -0.0056785217594186458;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r3 <= -6093.4999999999991 then
                begin
                    Result := -0.014973275990234248;
                end
                else
                begin
                    Result := 0.0022611555674211547;
                end;
            end;
        end
        else
        begin
            if features.different_units <= 2.5000000000000004 then
            begin
                if features.candidate_chain_score_gap <= -155565508.99999997 then
                begin
                    Result := 0.017505733008893517;
                end
                else
                begin
                    Result := 0.0016646729636792146;
                end;
            end
            else
            begin
                Result := -0.0075005723387687132;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_99(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020660275722600235;
    end
    else
    begin
        if features.delta_local_lm_r1 <= -2233.4999999999995 then
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r1 <= -10503.499999999998 then
                begin
                    if features.delta_complete_pool_consensus_support_min <= -475.49999999999994 then
                    begin
                        Result := 0.0;
                    end
                    else
                    begin
                        Result := 0.067285690097038497;
                    end;
                end
                else
                begin
                    Result := 0.00074956165755996908;
                end;
            end
            else
            begin
                Result := -0.013101021479641076;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= 1515.5000000000002 then
                        begin
                            Result := 0.0084866585871588678;
                        end
                        else
                        begin
                            Result := -0.012759646537989805;
                        end;
                    end
                    else
                    begin
                        Result := -0.0076499519945805094;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -3355.4999999999995 then
                    begin
                        Result := -0.0081934038737986898;
                    end
                    else
                    begin
                        if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
                        begin
                            if features.delta_char_lm_per_difference <= 122.10000000000001 then
                            begin
                                Result := 0.00037227243189698578;
                            end
                            else
                            begin
                                if features.candidate_complete_pool_consensus_nearest_distance <= 4.5000000000000009 then
                                begin
                                    Result := 0.003984879140536089;
                                end
                                else
                                begin
                                    if features.same_suffix_units <= 4.5000000000000009 then
                                    begin
                                        Result := 0.0085360907905816259;
                                    end
                                    else
                                    begin
                                        Result := 0.048540392172147458;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.0069922307734417493;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.0118260694083481;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_100(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_local_lm_r1 <= -2233.4999999999995 then
    begin
        if features.same_suffix_units <= 1.0000000180025095E-35 then
        begin
            if features.top_local_lm_r1 <= -6630.4999999999991 then
            begin
                if features.top_local_lm_r0 <= -7640.9999999999991 then
                begin
                    Result := 0.003549795657737229;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_support_min <= -475.49999999999994 then
                    begin
                        Result := -0.00011962934690412739;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -5951.4999999999991 then
                        begin
                            if features.candidate_dict_weight <= 122114.00000000001 then
                            begin
                                Result := 0.099413161662314953;
                            end
                            else
                            begin
                                Result := 0.0080749258330700038;
                            end;
                        end
                        else
                        begin
                            Result := -0.00093722048412232654;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.009739146315537156;
            end;
        end
        else
        begin
            Result := -0.0155866844464305;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.difference_span_units <= 2.5000000000000004 then
            begin
                if features.delta_char_lm_per_difference <= -343.91666666666657 then
                begin
                    Result := -0.0049225463953483668;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -6015.4999999999991 then
                    begin
                        Result := -0.00068605179027592231;
                    end
                    else
                    begin
                        if features.candidate_complete_pool_consensus_majority_units <= 8.5000000000000018 then
                        begin
                            if features.delta_local_lm_r3 <= -378.49999999999994 then
                            begin
                                Result := 0.037723913994490946;
                            end
                            else
                            begin
                                Result := 0.0095012920208356489;
                            end;
                        end
                        else
                        begin
                            Result := 5.4571455964197297E-05;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.010084169109674766;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6105.4999999999991 then
            begin
                Result := 0.016045934372894293;
            end
            else
            begin
                Result := 0.0026279397965765956;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_101(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020521330770029114;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_char_lm_score <= -4544.4999999999991 then
            begin
                Result := -0.0085703118840184406;
            end
            else
            begin
                if features.candidate_word_lm_boundary_max <= 1558.5000000000002 then
                begin
                    Result := 0.0078435606577712345;
                end
                else
                begin
                    Result := -0.0088032832112550068;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -170087355.49999997 then
            begin
                if features.candidate_local_lm_r1 <= -6852.4999999999991 then
                begin
                    Result := 0.004742830594061883;
                end
                else
                begin
                    Result := 0.038604979567744425;
                end;
            end
            else
            begin
                if features.candidate_ranker_score <= -427882151.99999994 then
                begin
                    Result := -0.016205109708456157;
                end
                else
                begin
                    if features.top_local_lm_r1 <= -4542.4999999999991 then
                    begin
                        if features.candidate_word_lm_zero_count <= 9.5000000000000018 then
                        begin
                            if features.ranker_score_gap <= 12371962.500000002 then
                            begin
                                if features.top_local_lm_r1 <= -8017.4999999999991 then
                                begin
                                    Result := -0.0010025262609396721;
                                end
                                else
                                begin
                                    Result := 0.0030865169852832171;
                                end;
                            end
                            else
                            begin
                                Result := 0.0086265480323844089;
                            end;
                        end
                        else
                        begin
                            Result := -0.0047108369160021061;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -210.49999999999997 then
                        begin
                            Result := -0.010511486558338827;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= -61.499999999999993 then
                            begin
                                Result := -0.0070472765492411247;
                            end
                            else
                            begin
                                if features.candidate_path_segments <= 6.5000000000000009 then
                                begin
                                    Result := 0.035100675277172665;
                                end
                                else
                                begin
                                    Result := 0.0010656807210929276;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_102(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020428278700082573;
    end
    else
    begin
        if features.ranker_score_gap <= -207318351.99999997 then
        begin
            if features.candidate_text_units <= 9.5000000000000018 then
            begin
                if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
                begin
                    Result := -0.018093548230555982;
                end
                else
                begin
                    if features.delta_candidate_score <= -1.0000000180025095E-35 then
                    begin
                        if features.candidate_complete_pool_signature_support <= 3.5000000000000004 then
                        begin
                            Result := -0.0080990959904530518;
                        end
                        else
                        begin
                            Result := 0.013071218630252368;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -8794.4999999999982 then
                        begin
                            if features.top_local_lm_r0 <= -6113.4999999999991 then
                            begin
                                if features.top_local_lm_r0 <= -8037.4999999999991 then
                                begin
                                    Result := 0.0035412537050772833;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_consensus_support_min <= 168.50000000000003 then
                                    begin
                                        Result := -0.0021397668389164601;
                                    end
                                    else
                                    begin
                                        Result := 0.077566493586211982;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.014843379344940628;
                            end;
                        end
                        else
                        begin
                            if features.delta_dict_weight_per_unit <= -4195.4999999999991 then
                            begin
                                if features.candidate_local_lm_r1 <= -7532.4999999999991 then
                                begin
                                    Result := 0.045075121598618914;
                                end
                                else
                                begin
                                    Result := 0.0014209623297595771;
                                end;
                            end
                            else
                            begin
                                Result := -0.0034384043016601044;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r2 <= -6955.4999999999991 then
                begin
                    Result := -0.01583588414927279;
                end
                else
                begin
                    Result := -4.9984983083343194E-05;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_score_gap <= -155565508.99999997 then
            begin
                Result := 0.014699020797241169;
            end
            else
            begin
                Result := 0.0012500813959081111;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_103(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020333890205297769;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.ranker_score_gap <= -154834619.99999997 then
            begin
                if features.candidate_text_units <= 8.5000000000000018 then
                begin
                    Result := -0.00028063514087222209;
                end
                else
                begin
                    Result := -0.010497138918949571;
                end;
            end
            else
            begin
                if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                begin
                    if features.candidate_local_lm_r0 <= -6015.4999999999991 then
                    begin
                        if features.ranker_score_gap <= -73349824.499999985 then
                        begin
                            Result := -0.0030832333278307074;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_pair_evidence <= 1387.5000000000002 then
                            begin
                                Result := 0.0022192439039977209;
                            end
                            else
                            begin
                                if features.candidate_score_per_unit <= 9586.5000000000018 then
                                begin
                                    Result := 0.0062435617481630601;
                                end
                                else
                                begin
                                    Result := 0.041262840606237076;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_dict_weight <= 48135.500000000007 then
                        begin
                            if features.delta_local_lm_r3 <= -174.49999999999997 then
                            begin
                                Result := 0.031312048023999443;
                            end
                            else
                            begin
                                Result := 0.0063763949738440424;
                            end;
                        end
                        else
                        begin
                            Result := -0.0079689752560936702;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0027410835469821922;
                end;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_support_min <= 423.50000000000006 then
                begin
                    Result := 0.030502890798262003;
                end
                else
                begin
                    Result := -0.0040092599993441303;
                end;
            end
            else
            begin
                if features.baseline_abstain_score <= 158552100.50000003 then
                begin
                    Result := 0.0025899291434119467;
                end
                else
                begin
                    Result := -0.016945100623700193;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_104(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020238162953049949;
    end
    else
    begin
        if features.candidate_ranker_score <= -214297594.49999997 then
        begin
            if features.delta_source_chain <= -1.0000000180025095E-35 then
            begin
                Result := 0.0161819688409468;
            end
            else
            begin
                Result := -0.0093934912504893709;
            end;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -119618426.99999999 then
                begin
                    Result := -0.012682489019692454;
                end
                else
                begin
                    Result := -0.00037269034222324758;
                end;
            end
            else
            begin
                if features.delta_path_max_segment_units <= 5.5000000000000009 then
                begin
                    if features.delta_local_lm_r0 <= -3496.4999999999995 then
                    begin
                        Result := -0.00815228218316821;
                    end
                    else
                    begin
                        if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                        begin
                            if features.candidate_char_lm_score <= -3929.4999999999995 then
                            begin
                                if features.delta_candidate_score <= 1.5000000000000002 then
                                begin
                                    Result := -0.0042044239965544584;
                                end
                                else
                                begin
                                    Result := 0.008731186694103877;
                                end;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -6990.4999999999991 then
                                begin
                                    Result := -0.0053396981873201771;
                                end
                                else
                                begin
                                    if features.candidate_word_lm_boundary_last <= 1030.5000000000002 then
                                    begin
                                        if features.delta_complete_pool_pair_evidence <= -1540.4999999999998 then
                                        begin
                                            Result := -0.0025626412888606247;
                                        end
                                        else
                                        begin
                                            Result := 0.024432645378642693;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := -0.0030963032132382703;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.0028666068525188709;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_supported_ratio <= -52.499999999999993 then
                    begin
                        Result := -0.0075200682300829358;
                    end
                    else
                    begin
                        Result := 0.028588259341461267;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_105(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020141094321218883;
    end
    else
    begin
        if features.delta_local_lm_r1 <= -2233.4999999999995 then
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r1 <= -9302.4999999999982 then
                begin
                    if features.delta_local_lm_r0 <= -959.49999999999989 then
                    begin
                        if features.top_local_lm_r0 <= -6280.4999999999991 then
                        begin
                            if features.delta_complete_pool_consensus_support_min <= -475.49999999999994 then
                            begin
                                Result := 0.0015157002458695409;
                            end
                            else
                            begin
                                Result := 0.080218606193351194;
                            end;
                        end
                        else
                        begin
                            Result := -0.00065253647976971875;
                        end;
                    end
                    else
                    begin
                        Result := -0.00084151499119356616;
                    end;
                end
                else
                begin
                    Result := -0.013493628485680174;
                end;
            end
            else
            begin
                Result := -0.012635609772997323;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= 1515.5000000000002 then
                        begin
                            if features.delta_local_lm_r0 <= -1912.4999999999998 then
                            begin
                                Result := -0.0068131591565944952;
                            end
                            else
                            begin
                                Result := 0.011208334448088041;
                            end;
                        end
                        else
                        begin
                            Result := -0.012676334594186746;
                        end;
                    end
                    else
                    begin
                        Result := -0.0076274848144622185;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -3355.4999999999995 then
                    begin
                        if features.top_local_lm_r1 <= -8479.4999999999982 then
                        begin
                            Result := -0.018378263765701074;
                        end
                        else
                        begin
                            Result := 0.00088643502529250255;
                        end;
                    end
                    else
                    begin
                        Result := 0.0025531305645906562;
                    end;
                end;
            end
            else
            begin
                Result := -0.011481612506408251;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_106(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.020042683714950268;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.01688031704790741;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -57678217.499999993 then
                begin
                    Result := -0.0090298548207323921;
                end
                else
                begin
                    if features.delta_word_lm_boundary_max <= -1060.4999999999998 then
                    begin
                        if features.delta_complete_pool_pair_evidence <= -1354.4999999999998 then
                        begin
                            Result := -0.0032929687189376632;
                        end
                        else
                        begin
                            Result := 0.047891667449766279;
                        end;
                    end
                    else
                    begin
                        Result := -0.00074791834703731054;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -3355.4999999999995 then
                begin
                    Result := -0.007230915889015351;
                end
                else
                begin
                    if features.top_local_lm_r0 <= -8037.4999999999991 then
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := -0.0046131271481334125;
                        end
                        else
                        begin
                            Result := 0.0041798522905962133;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -9177.4999999999982 then
                        begin
                            if features.delta_score_per_unit <= -25.499999999999996 then
                            begin
                                Result := -0.011013612291482115;
                            end
                            else
                            begin
                                if features.delta_chain_first_stage_score <= 5306.5000000000009 then
                                begin
                                    Result := 0.034670424599916698;
                                end
                                else
                                begin
                                    Result := -0.00167772539387645;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_score_per_unit <= -22357.499999999996 then
                            begin
                                if features.candidate_word_lm_boundary_max <= 1441.5000000000002 then
                                begin
                                    Result := 0.028585696343196618;
                                end
                                else
                                begin
                                    Result := -0.0012443257512524588;
                                end;
                            end
                            else
                            begin
                                Result := 0.0016184038620801389;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_107(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019942929100221055;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.ranker_score_gap <= -154834619.99999997 then
            begin
                if features.candidate_text_units <= 8.5000000000000018 then
                begin
                    Result := -0.00024390320697487838;
                end
                else
                begin
                    Result := -0.010309535154216488;
                end;
            end
            else
            begin
                if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                begin
                    if features.candidate_local_lm_r0 <= -6015.4999999999991 then
                    begin
                        if features.ranker_score_gap <= -73349824.499999985 then
                        begin
                            Result := -0.0030259037649063973;
                        end
                        else
                        begin
                            Result := 0.0047661472234508942;
                        end;
                    end
                    else
                    begin
                        if features.delta_dict_weight <= 48135.500000000007 then
                        begin
                            if features.delta_local_lm_r3 <= -174.49999999999997 then
                            begin
                                if features.candidate_local_lm_r1 <= -8318.4999999999982 then
                                begin
                                    Result := 0.051222539567970599;
                                end
                                else
                                begin
                                    Result := 0.014073809344217475;
                                end;
                            end
                            else
                            begin
                                if features.candidate_complete_pool_consensus_mean_distance <= 3464.5000000000005 then
                                begin
                                    Result := 0.018319698559909753;
                                end
                                else
                                begin
                                    Result := -0.0021613688257771818;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0078021601259371208;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0027187780188129007;
                end;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6154.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_support_min <= 445.50000000000006 then
                begin
                    Result := 0.022779599852728233;
                end
                else
                begin
                    Result := -0.005876603083108012;
                end;
            end
            else
            begin
                if features.baseline_abstain_score <= 158552100.50000003 then
                begin
                    Result := 0.0022889020700873528;
                end
                else
                begin
                    Result := -0.01650596431384788;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_108(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019841831389355719;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.016714135289242781;
        end
        else
        begin
            if features.top_local_lm_r1 <= -4757.4999999999991 then
            begin
                if features.top_local_lm_r0 <= -8037.4999999999991 then
                begin
                    if features.same_suffix_units <= 4.5000000000000009 then
                    begin
                        Result := -0.0044939551052134638;
                    end
                    else
                    begin
                        if features.delta_local_lm_r0 <= -698.49999999999989 then
                        begin
                            Result := -0.012835018467437224;
                        end
                        else
                        begin
                            Result := 0.0059546531103401943;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_majority_units <= 7.5000000000000009 then
                    begin
                        if features.candidate_local_lm_r2 <= -8281.4999999999982 then
                        begin
                            Result := 0.011867923293181599;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= -1255.4999999999998 then
                            begin
                                if features.candidate_local_lm_r1 <= -8457.4999999999982 then
                                begin
                                    Result := -0.012627005991390002;
                                end
                                else
                                begin
                                    Result := 0.002465621444675159;
                                end;
                            end
                            else
                            begin
                                if features.delta_candidate_score <= 5623.5000000000009 then
                                begin
                                    Result := 0.0045499913102573786;
                                end
                                else
                                begin
                                    if features.top_local_lm_r1 <= -6510.4999999999991 then
                                    begin
                                        Result := 0.045711937684471259;
                                    end
                                    else
                                    begin
                                        Result := 0.0037970291539326222;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := 0.00053458272687525793;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -786.49999999999989 then
                begin
                    Result := -0.012426889986406189;
                end
                else
                begin
                    if features.delta_candidate_score <= -22466.999999999996 then
                    begin
                        Result := 0.033417220268556931;
                    end
                    else
                    begin
                        Result := 0.0011147146466095764;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_109(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.01973939187920213;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.016579767056919239;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -163813990.99999997 then
                begin
                    Result := -0.015817708799436923;
                end
                else
                begin
                    Result := -0.0020266992160991289;
                end;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -3355.4999999999995 then
                begin
                    Result := -0.0070889134702160185;
                end
                else
                begin
                    if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                    begin
                        Result := -0.0012138234036545596;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -8968.9999999999982 then
                        begin
                            Result := -0.0030901465982742671;
                        end
                        else
                        begin
                            if features.top_local_lm_r1 <= -5262.4999999999991 then
                            begin
                                if features.delta_local_lm_r3 <= -1465.4999999999998 then
                                begin
                                    if features.delta_complete_pool_consensus_support_min <= -119.49999999999999 then
                                    begin
                                        if features.delta_local_lm_r0 <= -314.49999999999994 then
                                        begin
                                            Result := 0.058175488937033538;
                                        end
                                        else
                                        begin
                                            Result := 0.0;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := -0.0097393133208115937;
                                    end;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_consensus_mean_distance <= 3866.0000000000005 then
                                    begin
                                        Result := 0.0064766807427499981;
                                    end
                                    else
                                    begin
                                        if features.delta_local_lm_r0 <= 699.50000000000011 then
                                        begin
                                            Result := -0.001540158447211386;
                                        end
                                        else
                                        begin
                                            if features.top_local_lm_r0 <= -6478.4999999999991 then
                                            begin
                                                Result := 0.002952413181077597;
                                            end
                                            else
                                            begin
                                                Result := 0.027207054606725553;
                                            end;
                                        end;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.0020699481020092303;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_110(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019635611796562508;
    end
    else
    begin
        if features.delta_local_lm_r1 <= -2233.4999999999995 then
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r1 <= -9302.4999999999982 then
                begin
                    if features.delta_local_lm_r0 <= -959.49999999999989 then
                    begin
                        if features.top_local_lm_r0 <= -6280.4999999999991 then
                        begin
                            if features.candidate_complete_pool_consensus_support_min <= 165.50000000000003 then
                            begin
                                Result := 0.0026599753655147298;
                            end
                            else
                            begin
                                Result := 0.073848212434243457;
                            end;
                        end
                        else
                        begin
                            Result := -0.00067798285331009515;
                        end;
                    end
                    else
                    begin
                        Result := -0.0007807124366981216;
                    end;
                end
                else
                begin
                    Result := -0.01328150779001314;
                end;
            end
            else
            begin
                Result := -0.012377828781360709;
            end;
        end
        else
        begin
            if features.difference_span_units <= 3.5000000000000004 then
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= 1515.5000000000002 then
                        begin
                            Result := 0.0075926202954609626;
                        end
                        else
                        begin
                            Result := -0.012469799094942774;
                        end;
                    end
                    else
                    begin
                        Result := -0.0075369379929331919;
                    end;
                end
                else
                begin
                    if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
                    begin
                        if features.candidate_dict_weight <= 85672.500000000015 then
                        begin
                            if features.delta_local_lm_r0 <= -1114.4999999999998 then
                            begin
                                Result := -0.0015279258272849424;
                            end
                            else
                            begin
                                Result := 0.0033574946108552253;
                            end;
                        end
                        else
                        begin
                            Result := -0.0047531421401855456;
                        end;
                    end
                    else
                    begin
                        Result := 0.0060859613311373189;
                    end;
                end;
            end
            else
            begin
                Result := -0.011202905746186995;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_111(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_local_lm_r1 <= -2233.4999999999995 then
    begin
        if features.top_local_lm_r1 <= -5508.4999999999991 then
        begin
            if features.candidate_ranker_score <= 153036746.50000003 then
            begin
                Result := -0.0052345363281451748;
            end
            else
            begin
                if features.candidate_complete_pool_consensus_mean_distance <= 3866.0000000000005 then
                begin
                    if features.candidate_complete_pool_consensus_mean_distance <= 2690.5000000000005 then
                    begin
                        Result := 0.0057834581896416054;
                    end
                    else
                    begin
                        Result := 0.058379031134979387;
                    end;
                end
                else
                begin
                    Result := -0.0098337831404984241;
                end;
            end;
        end
        else
        begin
            Result := -0.019853559281633175;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.different_units <= 2.5000000000000004 then
            begin
                Result := -0.00026865062542909832;
            end
            else
            begin
                Result := -0.010159581535877401;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6105.4999999999991 then
            begin
                if features.top_local_lm_r1 <= -7543.4999999999991 then
                begin
                    if features.top_local_lm_r3 <= -7352.4999999999991 then
                    begin
                        Result := 0.019911656521646098;
                    end
                    else
                    begin
                        Result := -0.0095370035696997878;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_support_min <= 419.50000000000006 then
                    begin
                        if features.delta_local_lm_r0 <= -1167.4999999999998 then
                        begin
                            Result := 0.0044193571412590544;
                        end
                        else
                        begin
                            Result := 0.051886667517521003;
                        end;
                    end
                    else
                    begin
                        Result := -0.0017732951845561913;
                    end;
                end;
            end
            else
            begin
                if features.delta_word_lm_boundary_count <= 3.5000000000000004 then
                begin
                    if features.candidate_path_single_segments <= 8.5000000000000018 then
                    begin
                        Result := 0.0021681898801786709;
                    end
                    else
                    begin
                        Result := -0.0096430817589854331;
                    end;
                end
                else
                begin
                    Result := 0.010561945112584589;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_112(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019476389244351012;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.01638653279056259;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -57678217.499999993 then
                begin
                    Result := -0.0087335440234036135;
                end
                else
                begin
                    if features.delta_word_lm_boundary_max <= -1060.4999999999998 then
                    begin
                        if features.delta_complete_pool_pair_evidence <= -1354.4999999999998 then
                        begin
                            Result := -0.0032150194928298411;
                        end
                        else
                        begin
                            Result := 0.045962116570272757;
                        end;
                    end
                    else
                    begin
                        Result := -0.00077610595129518631;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -3355.4999999999995 then
                begin
                    Result := -0.0069002976654335682;
                end
                else
                begin
                    if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                    begin
                        if features.delta_complete_pool_consensus_support <= -54.499999999999993 then
                        begin
                            Result := 0.0040575987099248428;
                        end
                        else
                        begin
                            Result := -0.0032128129283421694;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -8968.9999999999982 then
                        begin
                            Result := -0.003041958041462229;
                        end
                        else
                        begin
                            if features.top_local_lm_r1 <= -5262.4999999999991 then
                            begin
                                if features.delta_local_lm_r3 <= -1465.4999999999998 then
                                begin
                                    if features.delta_complete_pool_consensus_support_min <= -119.49999999999999 then
                                    begin
                                        Result := 0.042059545102407329;
                                    end
                                    else
                                    begin
                                        Result := -0.0095702217730300153;
                                    end;
                                end
                                else
                                begin
                                    if features.delta_complete_pool_consensus_mean_distance <= 583.00000000000011 then
                                    begin
                                        Result := 0.011564990068651044;
                                    end
                                    else
                                    begin
                                        Result := 0.0028421962255880686;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.0020311826391500374;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_113(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019369258078363399;
    end
    else
    begin
        if features.ranker_score_gap <= -105509623.49999999 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.01086516817721456;
            end
            else
            begin
                if features.same_prefix_units <= 9.5000000000000018 then
                begin
                    if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                    begin
                        if features.candidate_local_lm_r0 <= -6495.4999999999991 then
                        begin
                            if features.same_prefix_units <= 1.0000000180025095E-35 then
                            begin
                                Result := -0.0083477169815885568;
                            end
                            else
                            begin
                                if features.candidate_complete_pool_signature_support <= 4.5000000000000009 then
                                begin
                                    if features.delta_candidate_score <= -1.0000000180025095E-35 then
                                    begin
                                        Result := -0.0078566738729097512;
                                    end
                                    else
                                    begin
                                        if features.delta_complete_pool_signature_support <= -10.499999999999998 then
                                        begin
                                            Result := -0.0029249625774735678;
                                        end
                                        else
                                        begin
                                            if features.delta_local_lm_r2 <= -1042.4999999999998 then
                                            begin
                                                if features.delta_candidate_score <= 129.50000000000003 then
                                                begin
                                                    Result := 0.068888127774971233;
                                                end
                                                else
                                                begin
                                                    Result := 0.006280440235124498;
                                                end;
                                            end
                                            else
                                            begin
                                                Result := 0.0050240060417880896;
                                            end;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.008277208948377919;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.012142690820878864;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r1 <= -8683.4999999999982 then
                        begin
                            if features.same_prefix_units <= 5.5000000000000009 then
                            begin
                                Result := 0.032363965107445401;
                            end
                            else
                            begin
                                Result := -0.001413908260697222;
                            end;
                        end
                        else
                        begin
                            Result := 0.0012716373374047781;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0088823665709116244;
                end;
            end;
        end
        else
        begin
            Result := 0.002157318823562683;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_114(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019260801100757105;
    end
    else
    begin
        if features.ranker_score_gap <= -215623245.99999997 then
        begin
            if features.candidate_local_lm_r1 <= -5047.4999999999991 then
            begin
                if features.candidate_score_per_unit <= 12736.000000000002 then
                begin
                    Result := -0.0080144817916995119;
                end
                else
                begin
                    if features.delta_path_single_segments <= 2.5000000000000004 then
                    begin
                        if features.candidate_local_lm_r0 <= -8794.4999999999982 then
                        begin
                            Result := 0.016011974927185646;
                        end
                        else
                        begin
                            Result := -0.0071119369244008043;
                        end;
                    end
                    else
                    begin
                        Result := 0.039350308566527881;
                    end;
                end;
            end
            else
            begin
                if features.candidate_char_lm_score <= -3587.4999999999995 then
                begin
                    Result := -0.0029217179424047075;
                end
                else
                begin
                    Result := 0.035887033097292957;
                end;
            end;
        end
        else
        begin
            if features.delta_chain_score_gap <= -169703275.49999997 then
            begin
                Result := 0.016539566036675515;
            end
            else
            begin
                if features.ranker_score_gap <= -23397226.499999996 then
                begin
                    if features.candidate_complete_pool_consensus_majority_units <= 11.500000000000002 then
                    begin
                        if features.candidate_local_lm_r0 <= -5295.4999999999991 then
                        begin
                            Result := 0.00028867137864174638;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -8655.4999999999982 then
                            begin
                                Result := 0.026942214752507479;
                            end
                            else
                            begin
                                Result := 0.0039023362909492128;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_dict_weight_per_unit <= 1255.5000000000002 then
                        begin
                            Result := -0.00099661247125714791;
                        end
                        else
                        begin
                            Result := -0.013568898936627464;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_chain_first_stage_score <= 151593.50000000003 then
                    begin
                        Result := 0.0035107972293897914;
                    end
                    else
                    begin
                        Result := 0.03334768029763046;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_115(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019151023389545475;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.016232919443073108;
        end
        else
        begin
            if features.baseline_abstain_score <= 158552100.50000003 then
            begin
                if features.candidate_ranker_score <= 117676590.00000001 then
                begin
                    if features.top_local_lm_r1 <= -5262.4999999999991 then
                    begin
                        if features.candidate_text_units <= 18.500000000000004 then
                        begin
                            if features.top_local_lm_r0 <= -8806.4999999999982 then
                            begin
                                Result := -0.0052070107362072182;
                            end
                            else
                            begin
                                Result := 0.0017956966819989404;
                            end;
                        end
                        else
                        begin
                            Result := -0.010137908816948149;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -83.499999999999986 then
                        begin
                            Result := -0.012061753388652476;
                        end
                        else
                        begin
                            Result := 0.012749442092256098;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
                    begin
                        if features.delta_complete_pool_consensus_support_min <= -119.49999999999999 then
                        begin
                            Result := 0.032179398613430693;
                        end
                        else
                        begin
                            Result := -0.00023343937295400896;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_boundary_count <= 3.5000000000000004 then
                        begin
                            if features.candidate_word_lm_zero_count <= 9.5000000000000018 then
                            begin
                                Result := 0.0020469260368652631;
                            end
                            else
                            begin
                                Result := -0.013592496471007728;
                            end;
                        end
                        else
                        begin
                            if features.delta_complete_pool_consensus_support_min <= -580.49999999999989 then
                            begin
                                Result := -0.0063199285127125693;
                            end
                            else
                            begin
                                if features.delta_word_lm_boundary_max <= -1096.4999999999998 then
                                begin
                                    Result := -0.00072119177918599593;
                                end
                                else
                                begin
                                    Result := 0.02578368592064012;
                                end;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.015147211000051581;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_116(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.019039932831911157;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.016096428152515909;
        end
        else
        begin
            if features.baseline_abstain_score <= 158552100.50000003 then
            begin
                if features.candidate_ranker_score <= 117676590.00000001 then
                begin
                    if features.ranker_score_gap <= -154834619.99999997 then
                    begin
                        if features.candidate_input_syllable_count <= 8.5000000000000018 then
                        begin
                            Result := -0.00017379033883959281;
                        end
                        else
                        begin
                            Result := -0.0088073047525088956;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -6066.4999999999991 then
                        begin
                            Result := -0.00060659991950274346;
                        end
                        else
                        begin
                            if features.delta_dict_weight <= 48135.500000000007 then
                            begin
                                if features.same_prefix_units <= 4.5000000000000009 then
                                begin
                                    if features.candidate_local_lm_r1 <= -8318.4999999999982 then
                                    begin
                                        if features.top_local_lm_r3 <= -8944.4999999999982 then
                                        begin
                                            Result := -0.013406539618969121;
                                        end
                                        else
                                        begin
                                            Result := 0.035407477873488601;
                                        end;
                                    end
                                    else
                                    begin
                                        if features.delta_local_lm_r1 <= 422.50000000000006 then
                                        begin
                                            Result := -0.0021028184790521254;
                                        end
                                        else
                                        begin
                                            if features.candidate_char_lm_score <= -4971.4999999999991 then
                                            begin
                                                Result := 0.0091995121731167275;
                                            end
                                            else
                                            begin
                                                Result := 0.045788488420613747;
                                            end;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0014066332349341234;
                                end;
                            end
                            else
                            begin
                                Result := -0.0083577239968772987;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
                    begin
                        Result := 0.019604814324950249;
                    end
                    else
                    begin
                        Result := 0.0021670880795652205;
                    end;
                end;
            end
            else
            begin
                Result := -0.015004335370380525;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_117(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.018927537231357594;
    end
    else
    begin
        if features.ranker_score_gap <= -84935356.999999985 then
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                Result := -0.009025556777333547;
            end
            else
            begin
                if features.candidate_complete_pool_signature_support <= 3.5000000000000004 then
                begin
                    if features.delta_path_single_segments <= 5.5000000000000009 then
                    begin
                        if features.candidate_text_units <= 12.500000000000002 then
                        begin
                            if features.delta_chain_second_stage_score <= 232770622.50000003 then
                            begin
                                Result := -0.0020185075996410561;
                            end
                            else
                            begin
                                Result := 0.025538478985854388;
                            end;
                        end
                        else
                        begin
                            Result := -0.011845321124064528;
                        end;
                    end
                    else
                    begin
                        Result := 0.0085515952306798194;
                    end;
                end
                else
                begin
                    if features.delta_score_per_unit <= -6564.4999999999991 then
                    begin
                        if features.candidate_word_lm_boundary_max <= 1216.5000000000002 then
                        begin
                            if features.top_local_lm_r2 <= -7292.4999999999991 then
                            begin
                                Result := 0.0065472952653103118;
                            end
                            else
                            begin
                                if features.candidate_dict_weight_per_unit <= 3064.5000000000005 then
                                begin
                                    Result := 0.078299313320135386;
                                end
                                else
                                begin
                                    Result := 0.0028181325357071563;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.0019085345652847662;
                        end;
                    end
                    else
                    begin
                        if features.candidate_path_segments <= 1.5000000000000002 then
                        begin
                            if features.candidate_local_lm_r2 <= -7598.4999999999991 then
                            begin
                                Result := -0.0061419930203515877;
                            end
                            else
                            begin
                                Result := 0.024554729846061839;
                            end;
                        end
                        else
                        begin
                            Result := 0.00056598115896668662;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_complete_pool_signature_support <= 28.500000000000004 then
            begin
                Result := 0.0031804696417535301;
            end
            else
            begin
                Result := -0.0050568192504737612;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_118(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.018813845731629978;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.015948914107556691;
        end
        else
        begin
            if features.top_local_lm_r1 <= -4757.4999999999991 then
            begin
                if features.top_local_lm_r0 <= -8037.4999999999991 then
                begin
                    if features.same_suffix_units <= 4.5000000000000009 then
                    begin
                        Result := -0.0044350557662580278;
                    end
                    else
                    begin
                        if features.delta_local_lm_r0 <= -698.49999999999989 then
                        begin
                            Result := -0.012640836855201065;
                        end
                        else
                        begin
                            Result := 0.005759400095713036;
                        end;
                    end;
                end
                else
                begin
                    if features.top_local_lm_r0 <= -6066.4999999999991 then
                    begin
                        if features.top_local_lm_r0 <= -6437.4999999999991 then
                        begin
                            Result := 0.0021586751145449136;
                        end
                        else
                        begin
                            if features.top_local_lm_r0 <= -6280.4999999999991 then
                            begin
                                Result := 0.027037843802322544;
                            end
                            else
                            begin
                                if features.delta_local_lm_r0 <= -605.49999999999989 then
                                begin
                                    Result := -0.0083857221490682299;
                                end
                                else
                                begin
                                    if features.delta_complete_pool_consensus_support <= -48.499999999999993 then
                                    begin
                                        Result := -0.0099744294753421683;
                                    end
                                    else
                                    begin
                                        Result := 0.025157502326339506;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -8.1117215799541651E-05;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -786.49999999999989 then
                begin
                    if features.delta_local_lm_r0 <= 1751.5000000000002 then
                    begin
                        Result := -0.01383048678047813;
                    end
                    else
                    begin
                        Result := 0.017138923839523722;
                    end;
                end
                else
                begin
                    if features.delta_candidate_score <= -22466.999999999996 then
                    begin
                        Result := 0.031778787448557923;
                    end
                    else
                    begin
                        Result := 0.00092602764792811768;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_119(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.018698868304726023;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.015811363381148812;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.ranker_score_gap <= -163813990.99999997 then
                begin
                    Result := -0.015229278784865236;
                end
                else
                begin
                    Result := -0.0018494714335274436;
                end;
            end
            else
            begin
                if features.delta_local_lm_r0 <= -3355.4999999999995 then
                begin
                    Result := -0.006752066139129805;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= 1371.5000000000002 then
                    begin
                        if features.candidate_local_lm_r0 <= -5375.4999999999991 then
                        begin
                            Result := 0.0015780798865608497;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= 567.50000000000011 then
                            begin
                                Result := -0.0013681298646559547;
                            end
                            else
                            begin
                                if features.same_suffix_units <= 1.0000000180025095E-35 then
                                begin
                                    Result := -0.0032042646172577602;
                                end
                                else
                                begin
                                    if features.same_suffix_units <= 7.5000000000000009 then
                                    begin
                                        Result := 0.035096980906698078;
                                    end
                                    else
                                    begin
                                        Result := 0.0015702509840395873;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := -0.0060925464883618422;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -8683.4999999999982 then
                            begin
                                if features.top_local_lm_r2 <= -8656.4999999999982 then
                                begin
                                    Result := -0.005654888868410278;
                                end
                                else
                                begin
                                    if features.delta_complete_pool_signature_support <= -26.499999999999996 then
                                    begin
                                        Result := -0.0058718999985221121;
                                    end
                                    else
                                    begin
                                        Result := 0.050936065697707235;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := -0.00013507395114073305;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_120(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.018582616434674577;
    end
    else
    begin
        if features.candidate_ranker_score <= 111801836.50000001 then
        begin
            if features.ranker_score_gap <= -154834619.99999997 then
            begin
                if features.candidate_text_units <= 8.5000000000000018 then
                begin
                    if features.delta_chain_second_stage_score <= -208209279.49999997 then
                    begin
                        Result := 0.01792401710249146;
                    end
                    else
                    begin
                        Result := -0.0018148994605170405;
                    end;
                end
                else
                begin
                    Result := -0.0097211806736650277;
                end;
            end
            else
            begin
                if features.candidate_word_lm_zero_count <= 5.5000000000000009 then
                begin
                    if features.top_local_lm_r1 <= -4915.4999999999991 then
                    begin
                        if features.candidate_local_lm_r0 <= -7236.4999999999991 then
                        begin
                            if features.same_prefix_units <= 1.0000000180025095E-35 then
                            begin
                                Result := -0.011398619570542662;
                            end
                            else
                            begin
                                if features.delta_local_lm_r0 <= -1582.4999999999998 then
                                begin
                                    if features.delta_word_lm_boundary_count <= -1.0000000180025095E-35 then
                                    begin
                                        if features.delta_complete_pool_consensus_support_min <= -199.49999999999997 then
                                        begin
                                            Result := 0.053707988584478977;
                                        end
                                        else
                                        begin
                                            Result := 0.0023057426950865221;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.0033297858668712324;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0013595095730764444;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := 0.0063448740157983248;
                        end;
                    end
                    else
                    begin
                        Result := -0.0096976048143042424;
                    end;
                end
                else
                begin
                    Result := -0.0027422557981934643;
                end;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6154.4999999999991 then
            begin
                if features.candidate_complete_pool_consensus_support_min <= 445.50000000000006 then
                begin
                    Result := 0.019805756778959054;
                end
                else
                begin
                    Result := -0.0058466643099768711;
                end;
            end
            else
            begin
                Result := 0.0016435831144261757;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_121(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.01846510225751288;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.01563917687611914;
        end
        else
        begin
            if features.top_local_lm_r1 <= -4757.4999999999991 then
            begin
                if features.top_local_lm_r0 <= -8037.4999999999991 then
                begin
                    Result := -0.0017760252630870726;
                end
                else
                begin
                    if features.delta_path_max_segment_units <= 5.5000000000000009 then
                    begin
                        if features.top_local_lm_r1 <= -8152.4999999999991 then
                        begin
                            if features.top_local_lm_r0 <= -7063.4999999999991 then
                            begin
                                Result := 0.00460228860592492;
                            end
                            else
                            begin
                                if features.delta_local_lm_r0 <= -959.49999999999989 then
                                begin
                                    Result := -0.0095787640446772411;
                                end
                                else
                                begin
                                    Result := 0.001708026815463869;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= 191.50000000000003 then
                            begin
                                if features.candidate_local_lm_r1 <= -7572.4999999999991 then
                                begin
                                    Result := 0.005740167956575633;
                                end
                                else
                                begin
                                    Result := -0.00012793182558573944;
                                end;
                            end
                            else
                            begin
                                Result := 0.011892195456428072;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_bonus <= -77.499999999999986 then
                        begin
                            Result := -0.0088222308512793165;
                        end
                        else
                        begin
                            Result := 0.029986645860617833;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -786.49999999999989 then
                begin
                    if features.delta_local_lm_r0 <= 1592.0000000000002 then
                    begin
                        Result := -0.013755586217330029;
                    end
                    else
                    begin
                        Result := 0.015591812681999332;
                    end;
                end
                else
                begin
                    if features.delta_candidate_score <= -22466.999999999996 then
                    begin
                        Result := 0.030546376196113612;
                    end
                    else
                    begin
                        Result := 0.00084561604303109549;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_122(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.018346338841864505;
    end
    else
    begin
        if features.delta_local_lm_r1 <= -2233.4999999999995 then
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r1 <= -9302.4999999999982 then
                begin
                    if features.delta_local_lm_r0 <= -959.49999999999989 then
                    begin
                        if features.top_local_lm_r0 <= -6280.4999999999991 then
                        begin
                            if features.candidate_complete_pool_consensus_support_min <= 165.50000000000003 then
                            begin
                                Result := 0.0021396341478587843;
                            end
                            else
                            begin
                                Result := 0.067171122112518453;
                            end;
                        end
                        else
                        begin
                            Result := -0.00055560695733734269;
                        end;
                    end
                    else
                    begin
                        Result := -0.00061298678334231727;
                    end;
                end
                else
                begin
                    Result := -0.012806679508312799;
                end;
            end
            else
            begin
                Result := -0.011873518003301435;
            end;
        end
        else
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                if features.delta_dict_weight_per_unit <= -4023.4999999999995 then
                begin
                    if features.delta_local_lm_r0 <= 1515.5000000000002 then
                    begin
                        Result := 0.0068603510011081966;
                    end
                    else
                    begin
                        Result := -0.012399222100857704;
                    end;
                end
                else
                begin
                    Result := -0.0074257254735380536;
                end;
            end
            else
            begin
                if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
                begin
                    if features.candidate_char_lm_score <= -6127.4999999999991 then
                    begin
                        Result := -0.0061817681265308559;
                    end
                    else
                    begin
                        Result := 0.0013631709292990886;
                    end;
                end
                else
                begin
                    if features.top_local_lm_r0 <= -5816.9999999999991 then
                    begin
                        if features.delta_local_lm_r0 <= -2080.4999999999995 then
                        begin
                            Result := 0.028509430219122917;
                        end
                        else
                        begin
                            Result := 0.0065146261548820325;
                        end;
                    end
                    else
                    begin
                        Result := -0.00098722970868676645;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_123(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.018226340078230992;
    end
    else
    begin
        if features.ranker_score_gap <= -63822726.499999993 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.008481309669678333;
            end
            else
            begin
                if features.candidate_ranker_score <= -214297594.49999997 then
                begin
                    if features.delta_chain_rank <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.019408302506182876;
                    end
                    else
                    begin
                        Result := -0.01148942519952441;
                    end;
                end
                else
                begin
                    if features.candidate_word_lm_supported_ratio <= 511.50000000000006 then
                    begin
                        if features.delta_local_lm_r3 <= 17.500000000000004 then
                        begin
                            if features.top_local_lm_r1 <= -4542.4999999999991 then
                            begin
                                if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                                begin
                                    if features.same_prefix_units <= 1.0000000180025095E-35 then
                                    begin
                                        Result := -0.0094348737642812128;
                                    end
                                    else
                                    begin
                                        Result := 0.0029715797480724046;
                                    end;
                                end
                                else
                                begin
                                    if features.candidate_local_lm_r1 <= -8949.4999999999982 then
                                    begin
                                        Result := 0.024058283172091799;
                                    end
                                    else
                                    begin
                                        Result := 0.0045386403252539419;
                                    end;
                                end;
                            end
                            else
                            begin
                                if features.delta_local_lm_r1 <= -786.49999999999989 then
                                begin
                                    Result := -0.012928865075957306;
                                end
                                else
                                begin
                                    if features.candidate_local_lm_r0 <= -6536.4999999999991 then
                                    begin
                                        Result := 0.030802984713170934;
                                    end
                                    else
                                    begin
                                        Result := -0.0016329315911809729;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_dict_weight <= -143187.49999999997 then
                            begin
                                Result := 0.0053157081930599922;
                            end
                            else
                            begin
                                Result := -0.0048211961868942117;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.0077853026705732298;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.0026877602367271561;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_124(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.0181051218229022;
    end
    else
    begin
        if features.candidate_ranker_score <= 117676590.00000001 then
        begin
            if features.ranker_score_gap <= -211365280.49999997 then
            begin
                Result := -0.006852081207299042;
            end
            else
            begin
                if features.candidate_word_lm_boundary_count <= 11.500000000000002 then
                begin
                    Result := 0.00042468911423629367;
                end
                else
                begin
                    Result := -0.011146980352357488;
                end;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
            begin
                Result := 0.017271134014824562;
            end
            else
            begin
                if features.delta_word_lm_boundary_count <= 3.5000000000000004 then
                begin
                    if features.candidate_word_lm_zero_count <= 9.5000000000000018 then
                    begin
                        if features.ranker_score_gap <= -4991225.9999999991 then
                        begin
                            if features.delta_local_lm_r0 <= -1255.4999999999998 then
                            begin
                                Result := -0.0031262097823861489;
                            end
                            else
                            begin
                                Result := 0.0024444155220206716;
                            end;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -8142.4999999999991 then
                            begin
                                Result := 0.036490552007683884;
                            end
                            else
                            begin
                                if features.delta_local_lm_r0 <= -314.49999999999994 then
                                begin
                                    Result := 0.022147825373067125;
                                end
                                else
                                begin
                                    if features.top_local_lm_r3 <= -5842.4999999999991 then
                                    begin
                                        Result := -0.0116865047904581;
                                    end
                                    else
                                    begin
                                        Result := 0.014348726139105037;
                                    end;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.013557602506178877;
                    end;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_support_min <= -580.49999999999989 then
                    begin
                        Result := -0.0064617012945083502;
                    end
                    else
                    begin
                        if features.delta_word_lm_boundary_max <= -1096.4999999999998 then
                        begin
                            Result := -0.0010678522405705212;
                        end
                        else
                        begin
                            Result := 0.024063572047389792;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_125(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.017982700948635983;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.delta_local_lm_r1 <= -2233.4999999999995 then
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.top_local_lm_r1 <= -6630.4999999999991 then
                    begin
                        if features.top_local_lm_r0 <= -7640.9999999999991 then
                        begin
                            Result := 0.00459663220640452;
                        end
                        else
                        begin
                            if features.delta_complete_pool_consensus_support_min <= -475.49999999999994 then
                            begin
                                Result := 5.4150467493526273E-06;
                            end
                            else
                            begin
                                Result := 0.057135985599022436;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.0039549125797084606;
                    end;
                end
                else
                begin
                    Result := -0.01150637932942713;
                end;
            end
            else
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r0 <= 1515.5000000000002 then
                        begin
                            Result := 0.0068366704329141303;
                        end
                        else
                        begin
                            Result := -0.012106863030338059;
                        end;
                    end
                    else
                    begin
                        Result := -0.0074031040833054413;
                    end;
                end
                else
                begin
                    if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
                    begin
                        Result := 0.00086451969018752064;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -5816.9999999999991 then
                        begin
                            if features.delta_score_per_unit <= -22.499999999999996 then
                            begin
                                Result := -0.0027861779747524154;
                            end
                            else
                            begin
                                if features.delta_local_lm_r0 <= -2080.4999999999995 then
                                begin
                                    Result := 0.036103758254761809;
                                end
                                else
                                begin
                                    Result := 0.0088932754633474359;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0010085240760847782;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.010480365644485705;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_126(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.020214694264397107;
        end
        else
        begin
            Result := 0.015339613153607471;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.015370110301953999;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.delta_local_lm_r1 <= -1427.4999999999998 then
                begin
                    if features.candidate_local_lm_r1 <= -10886.499999999998 then
                    begin
                        Result := 0.023215005723626156;
                    end
                    else
                    begin
                        Result := -0.013497254616614435;
                    end;
                end
                else
                begin
                    if features.top_local_lm_r2 <= -5797.4999999999991 then
                    begin
                        if features.candidate_complete_pool_consensus_support <= 958.50000000000011 then
                        begin
                            Result := -0.0055061895900799206;
                        end
                        else
                        begin
                            Result := 0.019428977707173268;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r2 <= -4889.4999999999991 then
                        begin
                            if features.top_local_lm_r0 <= -5517.4999999999991 then
                            begin
                                Result := 0.040582765943034477;
                            end
                            else
                            begin
                                Result := 0.0;
                            end;
                        end
                        else
                        begin
                            Result := -0.0087288346873554187;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_dict_weight <= 51449.500000000007 then
                begin
                    Result := 0.0015510246992823645;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -8794.4999999999982 then
                    begin
                        if features.delta_dict_weight_per_unit <= 11723.000000000002 then
                        begin
                            Result := -0.0051797505430685288;
                        end
                        else
                        begin
                            Result := 0.026710673304551902;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r3 <= -5075.4999999999991 then
                        begin
                            Result := -0.0077262556465842016;
                        end
                        else
                        begin
                            Result := 0.0045881995395394065;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_127(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.017730255535830988;
    end
    else
    begin
        if features.baseline_abstain_score <= 158552100.50000003 then
        begin
            if features.candidate_ranker_score <= 159419056.50000003 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.different_units <= 2.5000000000000004 then
                    begin
                        if features.candidate_local_lm_r1 <= -4862.4999999999991 then
                        begin
                            Result := 4.7737364570742045E-05;
                        end
                        else
                        begin
                            Result := 0.017211125035347975;
                        end;
                    end
                    else
                    begin
                        Result := -0.0088424604716573641;
                    end;
                end
                else
                begin
                    Result := -0.0091195218830293998;
                end;
            end
            else
            begin
                if features.candidate_char_lm_suffix_score <= -5441.4999999999991 then
                begin
                    if features.delta_local_lm_r2 <= -2038.4999999999998 then
                    begin
                        if features.candidate_score_per_unit <= 12310.500000000002 then
                        begin
                            Result := -0.0011886787789558793;
                        end
                        else
                        begin
                            Result := 0.06302413288428188;
                        end;
                    end
                    else
                    begin
                        if features.ranker_score_gap <= -9372398.4999999981 then
                        begin
                            if features.delta_word_lm_boundary_first <= -97.499999999999986 then
                            begin
                                Result := -0.013626095162453106;
                            end
                            else
                            begin
                                Result := 0.006177004825345115;
                            end;
                        end
                        else
                        begin
                            if features.delta_complete_pool_signature_support <= -16.499999999999996 then
                            begin
                                Result := -0.00089370425949792569;
                            end
                            else
                            begin
                                Result := 0.034491442308457285;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_signature_support <= 43.500000000000007 then
                    begin
                        if features.delta_char_lm_score <= -812.49999999999989 then
                        begin
                            Result := -0.011630995226230269;
                        end
                        else
                        begin
                            Result := 0.0022247429293722697;
                        end;
                    end
                    else
                    begin
                        Result := -0.017418269572364243;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.01458286321456892;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_128(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.020034631768431933;
        end
        else
        begin
            Result := 0.015392518955561173;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.015207241864888095;
        end
        else
        begin
            if features.baseline_abstain_score <= 158552100.50000003 then
            begin
                if features.candidate_ranker_score <= 159419056.50000003 then
                begin
                    if features.top_local_lm_r1 <= -5262.4999999999991 then
                    begin
                        if features.delta_word_lm_boundary_count <= -2.4999999999999996 then
                        begin
                            Result := -0.010578618151987127;
                        end
                        else
                        begin
                            if features.top_local_lm_r0 <= -8538.4999999999982 then
                            begin
                                Result := -0.0038858878127576157;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -6066.4999999999991 then
                                begin
                                    if features.candidate_local_lm_r3 <= -7912.4999999999991 then
                                    begin
                                        if features.candidate_local_lm_r1 <= -11045.999999999998 then
                                        begin
                                            Result := 0.041464473026149834;
                                        end
                                        else
                                        begin
                                            Result := 0.0086977738101272559;
                                        end;
                                    end
                                    else
                                    begin
                                        if features.candidate_complete_pool_consensus_support_min <= 273.50000000000006 then
                                        begin
                                            Result := -0.0029306698803634058;
                                        end
                                        else
                                        begin
                                            Result := 0.0048904057762966455;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0016594663669799983;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 73.125000000000014 then
                        begin
                            Result := -0.0090042589490001608;
                        end
                        else
                        begin
                            Result := 0.014818113787391668;
                        end;
                    end;
                end
                else
                begin
                    if features.top_ranker_score <= 169338120.00000003 then
                    begin
                        Result := 0.023805063512778731;
                    end
                    else
                    begin
                        Result := 0.0021525339093725186;
                    end;
                end;
            end
            else
            begin
                Result := -0.014412580198637753;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_129(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.017472865514899384;
    end
    else
    begin
        if features.ranker_score_gap <= -63822726.499999993 then
        begin
            if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
            begin
                Result := -0.0081693787219388574;
            end
            else
            begin
                if features.top_local_lm_r2 <= -8957.4999999999982 then
                begin
                    Result := -0.0088335477565109049;
                end
                else
                begin
                    if features.candidate_text_units <= 12.500000000000002 then
                    begin
                        if features.candidate_local_lm_r2 <= -9128.4999999999982 then
                        begin
                            if features.candidate_local_lm_r0 <= -8595.4999999999982 then
                            begin
                                Result := 0.025754455009390678;
                            end
                            else
                            begin
                                Result := -0.003400711082244795;
                            end;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                            begin
                                if features.same_prefix_units <= 1.0000000180025095E-35 then
                                begin
                                    if features.candidate_local_lm_r0 <= -7272.4999999999991 then
                                    begin
                                        Result := -0.01358850202119645;
                                    end
                                    else
                                    begin
                                        Result := 0.0032066346950536811;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.00074969201458187807;
                                end;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r1 <= -8683.4999999999982 then
                                begin
                                    if features.candidate_candidate_score <= 73174.500000000015 then
                                    begin
                                        if features.candidate_dict_weight_per_unit <= 4617.0000000000009 then
                                        begin
                                            Result := 0.019884700978900247;
                                        end
                                        else
                                        begin
                                            Result := 0.074344715860221747;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.0097587983549598505;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.0019963371116527504;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.candidate_score_per_unit <= 7827.5000000000009 then
                        begin
                            Result := -0.0097406797744089037;
                        end
                        else
                        begin
                            Result := 3.2229719733929403E-05;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := 0.0025166166812202696;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_130(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.019850515628231771;
        end
        else
        begin
            Result := 0.015438568664670693;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.015045698010199206;
        end
        else
        begin
            if features.top_local_lm_r1 <= -4757.4999999999991 then
            begin
                if features.top_local_lm_r0 <= -8037.4999999999991 then
                begin
                    Result := -0.0017658744741105171;
                end
                else
                begin
                    if features.top_local_lm_r1 <= -8152.4999999999991 then
                    begin
                        if features.top_local_lm_r0 <= -7063.4999999999991 then
                        begin
                            Result := 0.0045188452007512304;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= -959.49999999999989 then
                            begin
                                Result := -0.0095221207406558841;
                            end
                            else
                            begin
                                Result := 0.0012496483500386889;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_score <= 191.50000000000003 then
                        begin
                            Result := 0.0021693091566857194;
                        end
                        else
                        begin
                            Result := 0.011206984736789397;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -2233.4999999999995 then
                begin
                    Result := -0.021784834046963769;
                end
                else
                begin
                    if features.same_suffix_units <= 4.5000000000000009 then
                    begin
                        if features.delta_local_lm_r1 <= -108.49999999999999 then
                        begin
                            if features.delta_local_lm_r0 <= 1101.5000000000002 then
                            begin
                                Result := -0.0031347825964835765;
                            end
                            else
                            begin
                                Result := 0.025738394861033603;
                            end;
                        end
                        else
                        begin
                            Result := 0.017755413963112473;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 73.125000000000014 then
                        begin
                            Result := -0.0083013816096120744;
                        end
                        else
                        begin
                            Result := 0.018975040425805684;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_131(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.017210686902300428;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.delta_local_lm_r0 <= -3355.4999999999995 then
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    Result := 0.012757501886227436;
                end
                else
                begin
                    Result := -0.0095603739841906149;
                end;
            end
            else
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.delta_local_lm_r0 <= 1304.5000000000002 then
                    begin
                        Result := 0.0021730569516269236;
                    end
                    else
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := -0.0057596963036735593;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -8683.4999999999982 then
                            begin
                                if features.candidate_local_lm_r2 <= -7913.4999999999991 then
                                begin
                                    Result := 0.0;
                                end
                                else
                                begin
                                    if features.top_local_lm_r1 <= -9883.4999999999982 then
                                    begin
                                        Result := 0.0;
                                    end
                                    else
                                    begin
                                        Result := 0.061108069966901518;
                                    end;
                                end;
                            end
                            else
                            begin
                                Result := 0.00021701585425019671;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -786.49999999999989 then
                    begin
                        if features.delta_local_lm_r0 <= 1592.0000000000002 then
                        begin
                            Result := -0.013151432924369483;
                        end
                        else
                        begin
                            Result := 0.015767416515684498;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_suffix_score <= -254.49999999999997 then
                        begin
                            Result := 0.02264531470552603;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= -61.499999999999993 then
                            begin
                                Result := -0.010654778655581544;
                            end
                            else
                            begin
                                Result := 0.0059891130525314522;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.010152574621048398;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_132(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.019662410906838294;
        end
        else
        begin
            Result := 0.015477802253276555;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.014884692243582227;
        end
        else
        begin
            if features.baseline_abstain_score <= 158552100.50000003 then
            begin
                if features.candidate_legacy_rank <= 7.5000000000000009 then
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        Result := 0.00011619791438800486;
                    end
                    else
                    begin
                        if features.candidate_chain_first_stage_score <= 64919.000000000007 then
                        begin
                            if features.delta_complete_pool_signature_support <= -15.499999999999998 then
                            begin
                                Result := -0.0044387516622864751;
                            end
                            else
                            begin
                                if features.delta_dict_weight_per_unit <= -5246.4999999999991 then
                                begin
                                    if features.candidate_word_lm_boundary_max <= 1204.5000000000002 then
                                    begin
                                        if features.top_local_lm_r3 <= -8668.4999999999982 then
                                        begin
                                            Result := 0.024906330552021322;
                                        end
                                        else
                                        begin
                                            Result := 0.0;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.034077759253158584;
                                    end;
                                end
                                else
                                begin
                                    if features.candidate_ranker_score <= 159419056.50000003 then
                                    begin
                                        Result := -0.0034670070517048529;
                                    end
                                    else
                                    begin
                                        Result := 0.02016183515948575;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= 2216.5000000000005 then
                            begin
                                Result := 0.03555725281563523;
                            end
                            else
                            begin
                                Result := -0.0051872469688832848;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_char_lm_context_score <= -125.49999999999999 then
                    begin
                        Result := -0.0055011791746490471;
                    end
                    else
                    begin
                        Result := 0.034776378478129637;
                    end;
                end;
            end
            else
            begin
                Result := -0.014201055262618931;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_133(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.016943895219804089;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.delta_local_lm_r1 <= -2233.4999999999995 then
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.candidate_local_lm_r1 <= -9302.4999999999982 then
                    begin
                        if features.candidate_complete_pool_consensus_majority_units <= 9.5000000000000018 then
                        begin
                            if features.candidate_local_lm_r0 <= -7692.4999999999991 then
                            begin
                                if features.candidate_complete_pool_consensus_support_min <= 168.50000000000003 then
                                begin
                                    Result := 0.00025630564924874978;
                                end
                                else
                                begin
                                    Result := 0.047405004042960851;
                                end;
                            end
                            else
                            begin
                                Result := -0.0030281624886586839;
                            end;
                        end
                        else
                        begin
                            Result := -0.005375506525487345;
                        end;
                    end
                    else
                    begin
                        Result := -0.012294113031311898;
                    end;
                end
                else
                begin
                    Result := -0.011149773303335019;
                end;
            end
            else
            begin
                if features.same_suffix_units <= 1.0000000180025095E-35 then
                begin
                    if features.delta_has_dict_weight <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_local_lm_r1 <= 924.50000000000011 then
                        begin
                            if features.delta_complete_pool_consensus_support_min <= -511.49999999999994 then
                            begin
                                Result := -0.0028344403680220756;
                            end
                            else
                            begin
                                Result := 0.012084845828644181;
                            end;
                        end
                        else
                        begin
                            Result := -0.0091259912745815363;
                        end;
                    end
                    else
                    begin
                        Result := -0.0073463077862184079;
                    end;
                end
                else
                begin
                    if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
                    begin
                        if features.candidate_local_lm_r1 <= -6101.4999999999991 then
                        begin
                            Result := -0.00021660737542319509;
                        end
                        else
                        begin
                            Result := 0.0046274244892609588;
                        end;
                    end
                    else
                    begin
                        Result := 0.0051691645175224385;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.0099948774828955804;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_134(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.019470396297688611;
        end
        else
        begin
            Result := 0.015510265524734657;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= -23397226.499999996 then
        begin
            if features.candidate_complete_pool_consensus_majority_units <= 11.500000000000002 then
            begin
                if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                begin
                    if features.same_prefix_units <= 1.0000000180025095E-35 then
                    begin
                        if features.delta_char_lm_suffix_score <= 1.0000000180025095E-35 then
                        begin
                            Result := -0.011599647332133431;
                        end
                        else
                        begin
                            Result := 0.0048717045814686217;
                        end;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r0 <= -6495.4999999999991 then
                        begin
                            if features.delta_local_lm_r0 <= 922.50000000000011 then
                            begin
                                if features.top_local_lm_r0 <= -6280.4999999999991 then
                                begin
                                    if features.delta_local_lm_r2 <= -2090.4999999999995 then
                                    begin
                                        Result := 0.033869886670336621;
                                    end
                                    else
                                    begin
                                        Result := 0.0044126092230271068;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0016443794286053596;
                                end;
                            end
                            else
                            begin
                                Result := -0.0058301908866908404;
                            end;
                        end
                        else
                        begin
                            Result := -0.0094709287528741189;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8949.4999999999982 then
                    begin
                        Result := 0.019529008319653148;
                    end
                    else
                    begin
                        Result := 0.0015738006003106599;
                    end;
                end;
            end
            else
            begin
                if features.delta_char_lm_score <= -246.49999999999997 then
                begin
                    Result := -0.01117595356750598;
                end
                else
                begin
                    Result := -0.0014950254807033921;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_first_stage_score <= 151593.50000000003 then
            begin
                Result := 0.0028346203799204414;
            end
            else
            begin
                Result := 0.031459181975779682;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_135(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -333612172.49999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.014854899843327911;
        end
        else
        begin
            if features.candidate_complete_pool_consensus_support_min <= 332.50000000000006 then
            begin
                Result := -0.012765476251295316;
            end
            else
            begin
                Result := 0.04019597614573088;
            end;
        end;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.delta_path_max_segment_units <= 5.5000000000000009 then
            begin
                if features.delta_chain_score_gap <= -240352822.99999997 then
                begin
                    Result := 0.02383674972624384;
                end
                else
                begin
                    if features.ranker_score_gap <= -187996593.49999997 then
                    begin
                        Result := -0.0035037674807979397;
                    end
                    else
                    begin
                        if features.delta_complete_pool_consensus_nearest_distance <= 4.5000000000000009 then
                        begin
                            Result := 0.00058274774740356102;
                        end
                        else
                        begin
                            if features.delta_local_lm_r1 <= 924.50000000000011 then
                            begin
                                Result := 0.0025013064131570728;
                            end
                            else
                            begin
                                if features.candidate_candidate_score <= 25193.000000000004 then
                                begin
                                    Result := 0.002456542596017409;
                                end
                                else
                                begin
                                    if features.candidate_complete_pool_consensus_support <= 856.50000000000011 then
                                    begin
                                        Result := 0.057996505684947623;
                                    end
                                    else
                                    begin
                                        Result := 0.0082918240557498697;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.top_local_lm_r2 <= -7806.4999999999991 then
                begin
                    Result := -0.010369498096966813;
                end
                else
                begin
                    if features.delta_word_lm_boundary_max <= -25.499999999999996 then
                    begin
                        Result := -0.006558129722787933;
                    end
                    else
                    begin
                        if features.delta_char_lm_suffix_score <= -55.499999999999993 then
                        begin
                            Result := 0.0096165097658268018;
                        end
                        else
                        begin
                            Result := 0.052740266686290851;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.0098380649145517786;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_136(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.016565387173935766;
    end
    else
    begin
        if features.candidate_ranker_score <= 117676590.00000001 then
        begin
            if features.candidate_text_units <= 18.500000000000004 then
            begin
                if features.top_local_lm_r1 <= -4915.4999999999991 then
                begin
                    if features.candidate_local_lm_r1 <= -4862.4999999999991 then
                    begin
                        if features.top_local_lm_r0 <= -8538.4999999999982 then
                        begin
                            Result := -0.0045986704007366193;
                        end
                        else
                        begin
                            Result := 0.00088877870503815861;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r0 <= -514.49999999999989 then
                        begin
                            Result := -0.0085369716734672411;
                        end
                        else
                        begin
                            Result := 0.036208085489365271;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0094299551123385155;
                end;
            end
            else
            begin
                Result := -0.010567769482078529;
            end;
        end
        else
        begin
            if features.candidate_char_lm_suffix_score <= -6298.4999999999991 then
            begin
                if features.delta_complete_pool_consensus_support_min <= -119.49999999999999 then
                begin
                    Result := 0.02748806231878655;
                end
                else
                begin
                    Result := -0.0023227138822712106;
                end;
            end
            else
            begin
                if features.delta_word_lm_boundary_count <= 3.5000000000000004 then
                begin
                    if features.candidate_word_lm_zero_count <= 9.5000000000000018 then
                    begin
                        Result := 0.0013129270998079772;
                    end
                    else
                    begin
                        Result := -0.013462462932216349;
                    end;
                end
                else
                begin
                    if features.delta_complete_pool_consensus_support_min <= -580.49999999999989 then
                    begin
                        Result := -0.0064715924406493312;
                    end
                    else
                    begin
                        if features.delta_chain_first_stage_score <= -171252.99999999997 then
                        begin
                            Result := 0.038638740304514974;
                        end
                        else
                        begin
                            if features.delta_word_lm_boundary_max <= -1096.4999999999998 then
                            begin
                                Result := -0.0082698578554642691;
                            end
                            else
                            begin
                                Result := 0.0183426417486868;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_137(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.01919282745391682;
        end
        else
        begin
            Result := 0.015287357851422184;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.014667737117787467;
        end
        else
        begin
            if features.delta_path_max_segment_units <= 5.5000000000000009 then
            begin
                if features.ranker_score_gap <= -23397226.499999996 then
                begin
                    if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
                    begin
                        Result := -0.0065508630135863071;
                    end
                    else
                    begin
                        Result := 0.00014254016181673197;
                    end;
                end
                else
                begin
                    if features.candidate_complete_pool_consensus_support <= 905.50000000000011 then
                    begin
                        if features.delta_local_lm_r1 <= 422.50000000000006 then
                        begin
                            if features.delta_dict_weight_per_unit <= -23.499999999999996 then
                            begin
                                Result := 0.014890547284252209;
                            end
                            else
                            begin
                                Result := -0.00018272665618993149;
                            end;
                        end
                        else
                        begin
                            Result := -0.0022113926788714924;
                        end;
                    end
                    else
                    begin
                        if features.candidate_path_single_segments <= 4.5000000000000009 then
                        begin
                            if features.candidate_local_lm_r1 <= -9381.4999999999982 then
                            begin
                                Result := -0.0018505835482554929;
                            end
                            else
                            begin
                                Result := 0.037538299611667839;
                            end;
                        end
                        else
                        begin
                            Result := 0.0024078265248216406;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.candidate_score_per_unit <= 21475.500000000004 then
                begin
                    Result := 0.0011555833633354869;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= 1651.0000000000002 then
                    begin
                        if features.candidate_ranker_score <= 185268400.50000003 then
                        begin
                            Result := 0.054302841646623017;
                        end
                        else
                        begin
                            Result := 0.0012868721255988272;
                        end;
                    end
                    else
                    begin
                        Result := -0.0038458165721104946;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_138(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_local_lm_r1 <= -2233.4999999999995 then
    begin
        if features.top_local_lm_r1 <= -5508.4999999999991 then
        begin
            if features.delta_chain_first_stage_score <= -242.49999999999997 then
            begin
                if features.top_local_lm_r1 <= -6672.4999999999991 then
                begin
                    if features.top_local_lm_r0 <= -7689.4999999999991 then
                    begin
                        Result := -0.0020644458191691598;
                    end
                    else
                    begin
                        Result := 0.046744700477784611;
                    end;
                end
                else
                begin
                    Result := -0.0045292822217637314;
                end;
            end
            else
            begin
                if features.candidate_ranker_score <= 129273348.00000001 then
                begin
                    if features.candidate_local_lm_r2 <= -10129.499999999998 then
                    begin
                        if features.top_local_lm_r2 <= -8404.4999999999982 then
                        begin
                            Result := -0.0098183946321520627;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_consensus_mean_distance <= 2268.0000000000005 then
                            begin
                                Result := 0.051336761625727971;
                            end
                            else
                            begin
                                Result := -0.0037955726921172469;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.010149598708628305;
                    end;
                end
                else
                begin
                    if features.candidate_dict_weight_per_unit <= 11376.500000000002 then
                    begin
                        Result := -0.002508616500428845;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -6478.4999999999991 then
                        begin
                            Result := 0.043462526589828757;
                        end
                        else
                        begin
                            Result := -0.0020970110083331456;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.018445338140118287;
        end;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.delta_local_lm_r3 <= -1810.4999999999998 then
            begin
                if features.top_local_lm_r1 <= -5939.4999999999991 then
                begin
                    Result := 0.03980088040619837;
                end
                else
                begin
                    Result := -0.0097627565003703277;
                end;
            end
            else
            begin
                Result := 0.000664099163584864;
            end;
        end
        else
        begin
            Result := -0.0099729782530282828;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_139(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.candidate_char_lm_score <= -3716.4999999999995 then
        begin
            Result := -0.011400141914776602;
        end
        else
        begin
            if features.delta_char_lm_score <= -980.49999999999989 then
            begin
                Result := -0.010707265501184306;
            end
            else
            begin
                Result := 0.018609710892596828;
            end;
        end;
    end
    else
    begin
        if features.candidate_chain_score_gap <= -170087355.49999997 then
        begin
            if features.delta_dict_weight <= -198.49999999999997 then
            begin
                if features.delta_chain_second_stage_score <= -238848328.49999997 then
                begin
                    Result := 0.034698730277868892;
                end
                else
                begin
                    Result := -0.00046549708706940132;
                end;
            end
            else
            begin
                if features.delta_word_lm_per_boundary <= -23.309523809523807 then
                begin
                    Result := -0.0045604565515371008;
                end
                else
                begin
                    if features.candidate_dict_weight <= 96751.500000000015 then
                    begin
                        Result := 0.066264170347472409;
                    end
                    else
                    begin
                        Result := 0.0049704246405732067;
                    end;
                end;
            end;
        end
        else
        begin
            if features.baseline_abstain_score <= 130437264.50000001 then
            begin
                if features.candidate_legacy_rank <= 7.5000000000000009 then
                begin
                    if features.ranker_score_gap <= 12371962.500000002 then
                    begin
                        Result := 2.2244100931527922E-05;
                    end
                    else
                    begin
                        if features.candidate_chain_first_stage_score <= 64919.000000000007 then
                        begin
                            Result := 0.0030263588393958309;
                        end
                        else
                        begin
                            Result := 0.021643625390683579;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r3 <= -7287.4999999999991 then
                    begin
                        Result := -0.0066884144163164988;
                    end
                    else
                    begin
                        if features.candidate_candidate_score <= 41189.500000000007 then
                        begin
                            Result := 0.0;
                        end
                        else
                        begin
                            Result := 0.052041672587044563;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.012257248863065994;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_140(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        Result := -0.016131500144277288;
    end
    else
    begin
        if features.baseline_abstain_score <= 158552100.50000003 then
        begin
            if features.candidate_ranker_score <= 159419056.50000003 then
            begin
                if features.top_local_lm_r0 <= -6066.4999999999991 then
                begin
                    if features.top_local_lm_r0 <= -6437.4999999999991 then
                    begin
                        Result := -0.00030758828829334831;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -6280.4999999999991 then
                        begin
                            if features.candidate_complete_pool_pair_evidence <= 1372.0000000000002 then
                            begin
                                Result := 0.029271197128319066;
                            end
                            else
                            begin
                                Result := -0.002366383048853496;
                            end;
                        end
                        else
                        begin
                            Result := 0.00022079474087838323;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0033863235098542731;
                end;
            end
            else
            begin
                if features.candidate_char_lm_suffix_score <= -5563.4999999999991 then
                begin
                    if features.delta_char_lm_score <= 59.500000000000007 then
                    begin
                        if features.delta_local_lm_r3 <= -787.49999999999989 then
                        begin
                            if features.delta_candidate_score <= -201.49999999999997 then
                            begin
                                Result := -0.013302149197269653;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -8037.4999999999991 then
                                begin
                                    Result := -0.0024141756774524389;
                                end
                                else
                                begin
                                    if features.top_local_lm_r2 <= -5434.4999999999991 then
                                    begin
                                        Result := 0.044418635064182629;
                                    end
                                    else
                                    begin
                                        Result := 0.00042584605170669704;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.0022327585279232906;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r2 <= -8184.4999999999991 then
                        begin
                            Result := -0.0042845342413851198;
                        end
                        else
                        begin
                            Result := 0.044438573992077318;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.0013719529775496227;
                end;
            end;
        end
        else
        begin
            Result := -0.013870790736490741;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_141(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018884491166723527;
        end
        else
        begin
            Result := 0.015721859264001985;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.014500604086182398;
        end
        else
        begin
            if features.baseline_abstain_score <= 158552100.50000003 then
            begin
                if features.candidate_legacy_rank <= 7.5000000000000009 then
                begin
                    if features.delta_path_max_segment_units <= 5.5000000000000009 then
                    begin
                        if features.candidate_ranker_score <= 159419056.50000003 then
                        begin
                            Result := -0.00083174959819982378;
                        end
                        else
                        begin
                            if features.candidate_char_lm_suffix_score <= -5441.4999999999991 then
                            begin
                                if features.delta_char_lm_suffix_score <= -939.49999999999989 then
                                begin
                                    Result := 0.030529812865808456;
                                end
                                else
                                begin
                                    Result := 0.0057865137784468869;
                                end;
                            end
                            else
                            begin
                                Result := 0.00080167726899251597;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_word_lm_bonus <= -77.499999999999986 then
                        begin
                            Result := -0.0080932914363840286;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r2 <= -7809.4999999999991 then
                            begin
                                Result := -0.00030832616140186148;
                            end
                            else
                            begin
                                if features.top_ranker_score <= 291947979.50000006 then
                                begin
                                    if features.delta_char_suffix_lm_per_difference <= -452.83333333333331 then
                                    begin
                                        Result := -0.0011200030948015306;
                                    end
                                    else
                                    begin
                                        Result := 0.058478545084147342;
                                    end;
                                end
                                else
                                begin
                                    Result := 0.004228359197472535;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_char_lm_suffix_score <= -47.499999999999993 then
                    begin
                        Result := -0.0020062987435851103;
                    end
                    else
                    begin
                        Result := 0.035730032653390212;
                    end;
                end;
            end
            else
            begin
                Result := -0.013699408392289484;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_142(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018773050600724841;
        end
        else
        begin
            Result := 0.01537365102148204;
        end;
    end
    else
    begin
        if features.delta_local_lm_r0 <= -3355.4999999999995 then
        begin
            if features.same_suffix_units <= 1.0000000180025095E-35 then
            begin
                Result := 0.013130906987502284;
            end
            else
            begin
                Result := -0.0094015609421398728;
            end;
        end
        else
        begin
            if features.different_runs <= 1.5000000000000002 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.delta_local_lm_r0 <= 1304.5000000000002 then
                    begin
                        Result := 0.0020399722152250961;
                    end
                    else
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := -0.0057986747729986748;
                        end
                        else
                        begin
                            if features.candidate_local_lm_r1 <= -8683.4999999999982 then
                            begin
                                if features.candidate_local_lm_r2 <= -7913.4999999999991 then
                                begin
                                    Result := 2.1379319552989142E-05;
                                end
                                else
                                begin
                                    Result := 0.041264975959890843;
                                end;
                            end
                            else
                            begin
                                Result := -1.6225650648479153E-08;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -786.49999999999989 then
                    begin
                        if features.delta_local_lm_r0 <= 1592.0000000000002 then
                        begin
                            Result := -0.012844478003794577;
                        end
                        else
                        begin
                            Result := 0.015773930740313625;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_suffix_score <= -254.49999999999997 then
                        begin
                            Result := 0.021712252015613116;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= -61.499999999999993 then
                            begin
                                Result := -0.010577399633512107;
                            end
                            else
                            begin
                                Result := 0.0056137035498508925;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.010653018065682378;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_143(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.candidate_ranker_score <= 117676590.00000001 then
        begin
            Result := -0.012427104827535821;
        end
        else
        begin
            if features.candidate_complete_pool_consensus_unanimous_units <= 4.5000000000000009 then
            begin
                if features.delta_word_lm_per_boundary <= -66.944444444444429 then
                begin
                    Result := -0.0080304866287913227;
                end
                else
                begin
                    Result := 0.031007165251254083;
                end;
            end
            else
            begin
                Result := -0.0041269827095981948;
            end;
        end;
    end
    else
    begin
        if features.candidate_chain_score_gap <= -170087355.49999997 then
        begin
            if features.delta_dict_weight <= -198.49999999999997 then
            begin
                if features.delta_char_lm_score <= -590.49999999999989 then
                begin
                    Result := 0.032907471774410155;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -6852.4999999999991 then
                    begin
                        Result := -0.010627355016366217;
                    end
                    else
                    begin
                        if features.delta_char_lm_score <= -52.499999999999993 then
                        begin
                            Result := -0.0014648775080471697;
                        end
                        else
                        begin
                            Result := 0.037851927654039386;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_word_lm_per_boundary <= -23.309523809523807 then
                begin
                    Result := -0.004452091241447409;
                end
                else
                begin
                    if features.candidate_dict_weight <= 96751.500000000015 then
                    begin
                        Result := 0.063065612650132427;
                    end
                    else
                    begin
                        Result := 0.0049222309709065319;
                    end;
                end;
            end;
        end
        else
        begin
            if features.baseline_abstain_score <= 130437264.50000001 then
            begin
                if features.candidate_legacy_rank <= 7.5000000000000009 then
                begin
                    Result := 0.00040394483976948772;
                end
                else
                begin
                    if features.candidate_local_lm_r3 <= -7287.4999999999991 then
                    begin
                        Result := -0.0067257054735181112;
                    end
                    else
                    begin
                        Result := 0.034015425176557409;
                    end;
                end;
            end
            else
            begin
                Result := -0.011900083762419219;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_144(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018600325993728292;
        end
        else
        begin
            Result := 0.015248955121396738;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.014330538429082582;
        end
        else
        begin
            if features.delta_path_max_segment_units <= 5.5000000000000009 then
            begin
                if features.baseline_abstain_score <= 158552100.50000003 then
                begin
                    if features.candidate_ranker_score <= 159419056.50000003 then
                    begin
                        if features.top_local_lm_r1 <= -5262.4999999999991 then
                        begin
                            if features.delta_word_lm_boundary_count <= -2.4999999999999996 then
                            begin
                                Result := -0.0104259573639464;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r1 <= -5628.4999999999991 then
                                begin
                                    Result := -0.00012469894394584379;
                                end
                                else
                                begin
                                    Result := 0.01045232118668369;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 73.125000000000014 then
                            begin
                                Result := -0.008790702569977207;
                            end
                            else
                            begin
                                Result := 0.011982079069555458;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 186873174.50000003 then
                        begin
                            Result := 0.017811771014467438;
                        end
                        else
                        begin
                            Result := 0.0017231831013972442;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.014163403974977474;
                end;
            end
            else
            begin
                if features.candidate_score_per_unit <= 21475.500000000004 then
                begin
                    Result := 0.0011672718362590161;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= 1651.0000000000002 then
                    begin
                        if features.candidate_ranker_score <= 185268400.50000003 then
                        begin
                            Result := 0.050776731326147698;
                        end
                        else
                        begin
                            Result := 0.0011922600914310117;
                        end;
                    end
                    else
                    begin
                        Result := -0.0039352232875872663;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_145(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018485875363509856;
        end
        else
        begin
            Result := 0.01491193695053887;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.014189420897162611;
        end
        else
        begin
            if features.delta_path_max_segment_units <= 5.5000000000000009 then
            begin
                if features.baseline_abstain_score <= 158552100.50000003 then
                begin
                    if features.candidate_ranker_score <= 159419056.50000003 then
                    begin
                        if features.top_local_lm_r1 <= -5262.4999999999991 then
                        begin
                            if features.delta_word_lm_boundary_count <= -2.4999999999999996 then
                            begin
                                Result := -0.010271461900750893;
                            end
                            else
                            begin
                                Result := 0.00021455594829985952;
                            end;
                        end
                        else
                        begin
                            if features.candidate_path_max_segment_units <= 1.5000000000000002 then
                            begin
                                Result := 0.013734286932418502;
                            end
                            else
                            begin
                                Result := -0.0083980197370688674;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 169338120.00000003 then
                        begin
                            Result := 0.020809000565738534;
                        end
                        else
                        begin
                            Result := 0.0017434641298264509;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.014020397311150103;
                end;
            end
            else
            begin
                if features.delta_word_lm_bonus <= -77.499999999999986 then
                begin
                    Result := -0.0069602951891513032;
                end
                else
                begin
                    if features.candidate_local_lm_r2 <= -7809.4999999999991 then
                    begin
                        Result := -0.00044288815068921214;
                    end
                    else
                    begin
                        if features.top_ranker_score <= 291947979.50000006 then
                        begin
                            if features.delta_char_suffix_lm_per_difference <= -452.83333333333331 then
                            begin
                                Result := -0.0012261801349458688;
                            end
                            else
                            begin
                                Result := 0.054409231094763935;
                            end;
                        end
                        else
                        begin
                            Result := 0.004047295935113028;
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_146(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.delta_local_lm_r1 <= -2233.4999999999995 then
    begin
        if features.same_suffix_units <= 1.0000000180025095E-35 then
        begin
            if features.candidate_local_lm_r1 <= -9302.4999999999982 then
            begin
                if features.candidate_complete_pool_consensus_support_min <= 165.50000000000003 then
                begin
                    Result := -0.0061644765153135977;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -959.49999999999989 then
                    begin
                        Result := 0.042548646435245835;
                    end
                    else
                    begin
                        Result := 0.0;
                    end;
                end;
            end
            else
            begin
                Result := -0.013944859213382198;
            end;
        end
        else
        begin
            Result := -0.01212509670043265;
        end;
    end
    else
    begin
        if features.same_suffix_units <= 1.0000000180025095E-35 then
        begin
            if features.delta_dict_weight_per_unit <= -4023.4999999999995 then
            begin
                if features.delta_local_lm_r1 <= -12.499999999999998 then
                begin
                    if features.delta_local_lm_r0 <= -2211.4999999999995 then
                    begin
                        Result := -0.0088193336461045973;
                    end
                    else
                    begin
                        Result := 0.013051855766385316;
                    end;
                end
                else
                begin
                    if features.delta_word_lm_zero_count <= -1.0000000180025095E-35 then
                    begin
                        Result := 0.024133530328492348;
                    end
                    else
                    begin
                        Result := -0.0079512282873692719;
                    end;
                end;
            end
            else
            begin
                Result := -0.0072707127917380461;
            end;
        end
        else
        begin
            if features.candidate_dict_weight_per_unit <= 10600.500000000002 then
            begin
                if features.candidate_char_lm_score <= -6127.4999999999991 then
                begin
                    if features.delta_chain_second_stage_score <= 111509446.00000001 then
                    begin
                        Result := -0.0084403651869126;
                    end
                    else
                    begin
                        Result := 0.0091792822028214215;
                    end;
                end
                else
                begin
                    if features.candidate_legacy_rank <= 7.5000000000000009 then
                    begin
                        Result := 0.00081808323866197218;
                    end
                    else
                    begin
                        Result := 0.02449639322820478;
                    end;
                end;
            end
            else
            begin
                Result := 0.0048087431484697823;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_147(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018326123179478491;
        end
        else
        begin
            Result := 0.014699449009292175;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= 12371962.500000002 then
        begin
            if features.candidate_ranker_score <= -362383435.49999994 then
            begin
                Result := -0.011522284478034443;
            end
            else
            begin
                if features.delta_path_max_segment_units <= 5.5000000000000009 then
                begin
                    Result := -0.00011653333522452211;
                end
                else
                begin
                    if features.delta_word_lm_bonus <= -77.499999999999986 then
                    begin
                        Result := -0.0065944785808920939;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r2 <= -7809.4999999999991 then
                        begin
                            Result := 0.0;
                        end
                        else
                        begin
                            if features.top_ranker_score <= 291947979.50000006 then
                            begin
                                Result := 0.042874353775724391;
                            end
                            else
                            begin
                                Result := 0.0039613721578007268;
                            end;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            if features.candidate_chain_first_stage_score <= 1.0000000180025095E-35 then
            begin
                if features.candidate_local_lm_r1 <= -7376.4999999999991 then
                begin
                    if features.candidate_complete_pool_signature_support <= 32.500000000000007 then
                    begin
                        if features.candidate_word_lm_boundary_max <= 1273.5000000000002 then
                        begin
                            Result := 0.003908808392778614;
                        end
                        else
                        begin
                            if features.candidate_word_lm_zero_count <= 8.5000000000000018 then
                            begin
                                Result := 0.032509481194658706;
                            end
                            else
                            begin
                                Result := 0.00062464247984710727;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.010302037595964137;
                    end;
                end
                else
                begin
                    Result := -0.0030949533279974024;
                end;
            end
            else
            begin
                if features.candidate_score_per_unit <= 11841.500000000002 then
                begin
                    Result := 0.0078098322195463603;
                end
                else
                begin
                    Result := 0.042756225089653099;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_148(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.candidate_ranker_score <= 117676590.00000001 then
        begin
            Result := -0.012013816256880467;
        end
        else
        begin
            if features.candidate_complete_pool_consensus_unanimous_units <= 4.5000000000000009 then
            begin
                if features.delta_word_lm_per_boundary <= -66.944444444444429 then
                begin
                    Result := -0.0077936788655495973;
                end
                else
                begin
                    Result := 0.030090270394164689;
                end;
            end
            else
            begin
                Result := -0.0038133498341361115;
            end;
        end;
    end
    else
    begin
        if features.candidate_chain_score_gap <= -170087355.49999997 then
        begin
            if features.delta_dict_weight <= -198.49999999999997 then
            begin
                if features.delta_chain_second_stage_score <= -238848328.49999997 then
                begin
                    Result := 0.033416863458441345;
                end
                else
                begin
                    Result := -0.00039353122444314048;
                end;
            end
            else
            begin
                if features.delta_word_lm_per_boundary <= -23.309523809523807 then
                begin
                    Result := -0.004369793126640111;
                end
                else
                begin
                    Result := 0.044371460554112119;
                end;
            end;
        end
        else
        begin
            if features.delta_path_max_segment_units <= 5.5000000000000009 then
            begin
                Result := 0.00013920577292969471;
            end
            else
            begin
                if features.top_local_lm_r2 <= -7874.4999999999991 then
                begin
                    Result := -0.010605478933720698;
                end
                else
                begin
                    if features.candidate_complete_pool_pair_evidence <= 1492.5000000000002 then
                    begin
                        if features.candidate_local_lm_r0 <= -4603.9999999999991 then
                        begin
                            if features.delta_chain_second_stage_score <= -33125041.499999996 then
                            begin
                                Result := -0.0087040847205005958;
                            end
                            else
                            begin
                                if features.delta_char_lm_suffix_score <= -220.49999999999997 then
                                begin
                                    Result := 0.013592655521009606;
                                end
                                else
                                begin
                                    Result := 0.054844874810946999;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.012967345829030552;
                        end;
                    end
                    else
                    begin
                        Result := -0.003251512899905331;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_149(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018147579293886405;
        end
        else
        begin
            Result := 0.014580935580896596;
        end;
    end
    else
    begin
        if features.delta_local_lm_r0 <= -3496.4999999999995 then
        begin
            if features.top_local_lm_r0 <= -5816.9999999999991 then
            begin
                if features.delta_char_lm_score <= -951.49999999999989 then
                begin
                    Result := 0.029334843263883872;
                end
                else
                begin
                    if features.ranker_score_gap <= -19014267.499999996 then
                    begin
                        Result := -0.0086422208022013253;
                    end
                    else
                    begin
                        Result := 0.028229170180563368;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -8457.4999999999982 then
                begin
                    Result := -0.020034355731829052;
                end
                else
                begin
                    if features.delta_path_segments <= 2.5000000000000004 then
                    begin
                        Result := -0.0076221943420705946;
                    end
                    else
                    begin
                        Result := 0.02765308625010604;
                    end;
                end;
            end;
        end
        else
        begin
            if features.different_runs <= 1.5000000000000002 then
            begin
                if features.top_local_lm_r1 <= -4757.4999999999991 then
                begin
                    if features.delta_local_lm_r0 <= 1304.5000000000002 then
                    begin
                        Result := 0.0019184448964738876;
                    end
                    else
                    begin
                        Result := -0.0019837530441450769;
                    end;
                end
                else
                begin
                    if features.delta_local_lm_r1 <= -2233.4999999999995 then
                    begin
                        Result := -0.020999018902484044;
                    end
                    else
                    begin
                        if features.same_suffix_units <= 4.5000000000000009 then
                        begin
                            Result := 0.0050544537310163121;
                        end
                        else
                        begin
                            if features.delta_char_lm_per_difference <= 73.125000000000014 then
                            begin
                                Result := -0.007919284570939886;
                            end
                            else
                            begin
                                Result := 0.018974544607360262;
                            end;
                        end;
                    end;
                end;
            end
            else
            begin
                Result := -0.010434731234576547;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_150(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.018028671841656543;
        end
        else
        begin
            Result := 0.01425976936789806;
        end;
    end
    else
    begin
        if features.ranker_score_gap <= 12371962.500000002 then
        begin
            if features.top_local_lm_r0 <= -8037.4999999999991 then
            begin
                Result := -0.0028269306597568868;
            end
            else
            begin
                if features.top_local_lm_r0 <= -6066.4999999999991 then
                begin
                    if features.top_local_lm_r0 <= -6437.4999999999991 then
                    begin
                        if features.candidate_local_lm_r2 <= -7677.4999999999991 then
                        begin
                            Result := 0.0058089568789052026;
                        end
                        else
                        begin
                            Result := -0.0017740576674602126;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -6280.4999999999991 then
                        begin
                            if features.top_local_lm_r1 <= -5131.4999999999991 then
                            begin
                                if features.delta_local_lm_r3 <= -247.49999999999997 then
                                begin
                                    Result := 0.039856893102272598;
                                end
                                else
                                begin
                                    Result := 0.010552187201829148;
                                end;
                            end
                            else
                            begin
                                Result := -0.0077079965637215954;
                            end;
                        end
                        else
                        begin
                            if features.delta_local_lm_r0 <= 311.50000000000006 then
                            begin
                                Result := -0.0067446717458833133;
                            end
                            else
                            begin
                                Result := 0.015295570649047199;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r2 <= -6955.4999999999991 then
                    begin
                        Result := -0.0050805035217483408;
                    end
                    else
                    begin
                        Result := 0.0015493375599947522;
                    end;
                end;
            end;
        end
        else
        begin
            if features.delta_chain_second_stage_score <= -33125041.499999996 then
            begin
                if features.delta_local_lm_r2 <= 1360.0000000000002 then
                begin
                    Result := 0.027698321150751527;
                end
                else
                begin
                    Result := -0.010413620546829936;
                end;
            end
            else
            begin
                Result := 0.0024836968623974387;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_151(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.candidate_char_lm_score <= -3716.4999999999995 then
        begin
            Result := -0.010334167872527084;
        end
        else
        begin
            if features.top_local_lm_r3 <= -4212.4999999999991 then
            begin
                Result := 0.021772992387199402;
            end
            else
            begin
                Result := -0.010533116362402962;
            end;
        end;
    end
    else
    begin
        if features.delta_chain_score_gap <= -169703275.49999997 then
        begin
            if features.delta_local_lm_r1 <= -1751.4999999999998 then
            begin
                Result := 0.035585864942350012;
            end
            else
            begin
                Result := 0.0056234168502233449;
            end;
        end
        else
        begin
            if features.baseline_abstain_score <= 130437264.50000001 then
            begin
                if features.candidate_legacy_rank <= 7.5000000000000009 then
                begin
                    if features.delta_path_max_segment_units <= 5.5000000000000009 then
                    begin
                        Result := 0.00017176539279770757;
                    end
                    else
                    begin
                        if features.top_local_lm_r2 <= -7874.4999999999991 then
                        begin
                            Result := -0.010394577837851365;
                        end
                        else
                        begin
                            if features.candidate_complete_pool_pair_evidence <= 1492.5000000000002 then
                            begin
                                if features.candidate_local_lm_r0 <= -4603.9999999999991 then
                                begin
                                    if features.delta_chain_second_stage_score <= -33125041.499999996 then
                                    begin
                                        Result := -0.0086040384113738703;
                                    end
                                    else
                                    begin
                                        if features.delta_complete_pool_pair_evidence <= -1387.4999999999998 then
                                        begin
                                            Result := 0.00054388252306745673;
                                        end
                                        else
                                        begin
                                            Result := 0.046430192471849922;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.012859550315626696;
                                end;
                            end
                            else
                            begin
                                Result := -0.0029766388708879032;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r3 <= -7287.4999999999991 then
                    begin
                        Result := -0.0066796541663581566;
                    end
                    else
                    begin
                        Result := 0.031969367415079185;
                    end;
                end;
            end
            else
            begin
                Result := -0.011544773540090203;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_152(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.017848693858551496;
        end
        else
        begin
            Result := 0.014134767669406932;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.013859544260942078;
        end
        else
        begin
            if features.delta_source_chain <= 1.0000000180025095E-35 then
            begin
                if features.top_local_lm_r0 <= -5816.9999999999991 then
                begin
                    if features.top_local_lm_r0 <= -8037.4999999999991 then
                    begin
                        Result := -0.0016016018976508476;
                    end
                    else
                    begin
                        if features.candidate_local_lm_r2 <= -7677.4999999999991 then
                        begin
                            if features.candidate_complete_pool_consensus_support_min <= 163.50000000000003 then
                            begin
                                Result := -0.0039761315362970345;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r0 <= -9177.4999999999982 then
                                begin
                                    if features.delta_score_per_unit <= -25.499999999999996 then
                                    begin
                                        Result := -0.0029767547028194891;
                                    end
                                    else
                                    begin
                                        if features.delta_chain_first_stage_score <= 243.50000000000003 then
                                        begin
                                            Result := 0.03996660036284496;
                                        end
                                        else
                                        begin
                                            Result := -0.0044462085588411792;
                                        end;
                                    end;
                                end
                                else
                                begin
                                    if features.delta_local_lm_r0 <= -1114.4999999999998 then
                                    begin
                                        Result := -0.0028515402374523196;
                                    end
                                    else
                                    begin
                                        Result := 0.011037487344695177;
                                    end;
                                end;
                            end;
                        end
                        else
                        begin
                            if features.delta_path_max_segment_units <= 4.5000000000000009 then
                            begin
                                Result := 0.0004707610698663236;
                            end
                            else
                            begin
                                Result := 0.020914870991217801;
                            end;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r0 <= -7057.4999999999991 then
                    begin
                        Result := -0.0074658696283828128;
                    end
                    else
                    begin
                        Result := 0.00056199188788162539;
                    end;
                end;
            end
            else
            begin
                Result := -0.004510296847839902;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_153(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.017727072217858908;
        end
        else
        begin
            Result := 0.013824209234175877;
        end;
    end
    else
    begin
        if features.candidate_complete_pool_seed_rank <= 1.5000000000000002 then
        begin
            if features.ranker_score_gap <= -54642305.999999993 then
            begin
                Result := -0.0078653852968141817;
            end
            else
            begin
                Result := 0.0028601023014601223;
            end;
        end
        else
        begin
            if features.delta_dict_weight <= 51449.500000000007 then
            begin
                if features.delta_word_lm_zero_count <= -1.0000000180025095E-35 then
                begin
                    Result := 0.0062184302664158959;
                end
                else
                begin
                    if features.delta_local_lm_r0 <= -3224.4999999999995 then
                    begin
                        Result := -0.010309649290410297;
                    end
                    else
                    begin
                        Result := 0.0010523909573594845;
                    end;
                end;
            end
            else
            begin
                if features.candidate_local_lm_r0 <= -8714.4999999999982 then
                begin
                    if features.delta_dict_weight_per_unit <= 13639.500000000002 then
                    begin
                        Result := -0.0047563815622698553;
                    end
                    else
                    begin
                        Result := 0.023611478291194341;
                    end;
                end
                else
                begin
                    if features.top_ranker_score <= 483182649.50000006 then
                    begin
                        if features.delta_local_lm_r0 <= -376.49999999999994 then
                        begin
                            if features.candidate_ranker_score <= 117676590.00000001 then
                            begin
                                if features.top_local_lm_r2 <= -6621.4999999999991 then
                                begin
                                    Result := 0.0045972377408135673;
                                end
                                else
                                begin
                                    Result := -0.017625966140733435;
                                end;
                            end
                            else
                            begin
                                if features.candidate_local_lm_r2 <= -7356.4999999999991 then
                                begin
                                    Result := 0.031251365784321049;
                                end
                                else
                                begin
                                    Result := -0.0010458339538794621;
                                end;
                            end;
                        end
                        else
                        begin
                            Result := -0.010435917629770097;
                        end;
                    end
                    else
                    begin
                        Result := 0.006247401405592959;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_154(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -272844600.99999994 then
    begin
        if features.candidate_char_lm_score <= -3716.4999999999995 then
        begin
            Result := -0.010061801605501864;
        end
        else
        begin
            if features.top_local_lm_r3 <= -4212.4999999999991 then
            begin
                if features.delta_local_lm_r3 <= -787.49999999999989 then
                begin
                    if features.candidate_input_syllable_count <= 9.5000000000000018 then
                    begin
                        Result := 0.044742298806401216;
                    end
                    else
                    begin
                        Result := -0.0049901537841628837;
                    end;
                end
                else
                begin
                    Result := -0.00030576852775660924;
                end;
            end
            else
            begin
                Result := -0.010349095917987744;
            end;
        end;
    end
    else
    begin
        if features.candidate_chain_score_gap <= -170087355.49999997 then
        begin
            if features.delta_dict_weight_per_unit <= -28.499999999999996 then
            begin
                if features.delta_chain_second_stage_score <= -238848328.49999997 then
                begin
                    Result := 0.034252931142200869;
                end
                else
                begin
                    Result := -0.0029359061852449169;
                end;
            end
            else
            begin
                if features.candidate_complete_pool_consensus_unanimous_units <= 3.5000000000000004 then
                begin
                    Result := 0.052541213649485434;
                end
                else
                begin
                    Result := 0.0049217573889430016;
                end;
            end;
        end
        else
        begin
            if features.baseline_abstain_score <= 130437264.50000001 then
            begin
                if features.delta_chain_score_gap <= -51757549.499999993 then
                begin
                    if features.baseline_abstain_score <= -39989252.999999993 then
                    begin
                        Result := 0.03040136260170578;
                    end
                    else
                    begin
                        Result := -0.0033291918021437182;
                    end;
                end
                else
                begin
                    if features.delta_complete_pool_signature_support <= -13.499999999999998 then
                    begin
                        if features.delta_chain_score_gap <= -10342612.499999998 then
                        begin
                            Result := 0.012096441964592461;
                        end
                        else
                        begin
                            Result := -0.0020855262401527374;
                        end;
                    end
                    else
                    begin
                        Result := 0.0019378526972837478;
                    end;
                end;
            end
            else
            begin
                Result := -0.011316989486362236;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_155(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.017547797246541583;
        end
        else
        begin
            Result := 0.013684603732355964;
        end;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.delta_local_lm_r0 <= -3496.4999999999995 then
            begin
                if features.top_local_lm_r0 <= -5816.9999999999991 then
                begin
                    if features.delta_char_lm_score <= -951.49999999999989 then
                    begin
                        Result := 0.028246924047393998;
                    end
                    else
                    begin
                        if features.ranker_score_gap <= -19014267.499999996 then
                        begin
                            Result := -0.0084537544082859805;
                        end
                        else
                        begin
                            Result := 0.027438726971228608;
                        end;
                    end;
                end
                else
                begin
                    if features.candidate_local_lm_r1 <= -8457.4999999999982 then
                    begin
                        Result := -0.019765590029521839;
                    end
                    else
                    begin
                        if features.delta_path_segments <= 2.5000000000000004 then
                        begin
                            Result := -0.0072311025355542751;
                        end
                        else
                        begin
                            Result := 0.027491074555619083;
                        end;
                    end;
                end;
            end
            else
            begin
                if features.delta_dict_weight_per_unit <= -8302.4999999999982 then
                begin
                    Result := 0.0026051067586762748;
                end
                else
                begin
                    if features.same_suffix_units <= 1.0000000180025095E-35 then
                    begin
                        if features.candidate_local_lm_r1 <= -10434.499999999998 then
                        begin
                            if features.delta_complete_pool_consensus_support_mean <= -67.499999999999986 then
                            begin
                                Result := -0.0093873018713080594;
                            end
                            else
                            begin
                                Result := 0.039568976163799931;
                            end;
                        end
                        else
                        begin
                            Result := -0.005837745428252333;
                        end;
                    end
                    else
                    begin
                        if features.delta_local_lm_r1 <= -2233.4999999999995 then
                        begin
                            Result := -0.0084148773683129004;
                        end
                        else
                        begin
                            Result := 0.0011341751926788953;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.0091292049917073206;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_156(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_score_per_unit <= 3677.0000000000005 then
        begin
            Result := -0.01742362594635993;
        end
        else
        begin
            Result := 0.013384758126801602;
        end;
    end
    else
    begin
        if features.candidate_ranker_score <= -427882151.99999994 then
        begin
            Result := -0.013692104482310239;
        end
        else
        begin
            if features.delta_complete_pool_seed_rank <= 1.0000000180025095E-35 then
            begin
                if features.delta_path_segments <= 1.0000000180025095E-35 then
                begin
                    if features.top_local_lm_r0 <= -5561.4999999999991 then
                    begin
                        if features.candidate_ranker_score <= 200299497.50000003 then
                        begin
                            Result := -0.00050092625013844539;
                        end
                        else
                        begin
                            if features.delta_local_lm_r1 <= -1973.4999999999998 then
                            begin
                                Result := -0.0091762545785977721;
                            end
                            else
                            begin
                                Result := 0.028302643255845129;
                            end;
                        end;
                    end
                    else
                    begin
                        Result := -0.010871340750888877;
                    end;
                end
                else
                begin
                    if features.delta_char_lm_per_difference <= 426.37500000000006 then
                    begin
                        Result := -0.011335578593835341;
                    end
                    else
                    begin
                        Result := 0.016193487198114264;
                    end;
                end;
            end
            else
            begin
                if features.delta_score_per_unit <= -22357.499999999996 then
                begin
                    if features.delta_local_lm_r1 <= 746.50000000000011 then
                    begin
                        if features.candidate_local_lm_r2 <= -6824.4999999999991 then
                        begin
                            Result := -0.0047524858828706107;
                        end
                        else
                        begin
                            if features.candidate_word_lm_boundary_max <= 1387.5000000000002 then
                            begin
                                Result := 0.028610562907532913;
                            end
                            else
                            begin
                                Result := -0.0027768225444267554;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.top_local_lm_r0 <= -7529.4999999999991 then
                        begin
                            Result := 0.0063240860447074752;
                        end
                        else
                        begin
                            Result := 0.052000518741808832;
                        end;
                    end;
                end
                else
                begin
                    Result := 0.00045269647614344709;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_157(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -313895743.49999994 then
    begin
        if features.candidate_ranker_score <= 117676590.00000001 then
        begin
            Result := -0.013331778859383121;
        end
        else
        begin
            if features.candidate_complete_pool_pair_evidence <= 1336.5000000000002 then
            begin
                if features.delta_char_lm_per_difference <= -961.74999999999989 then
                begin
                    Result := -0.0041508066889349047;
                end
                else
                begin
                    if features.delta_word_lm_boundary_count <= 1.0000000180025095E-35 then
                    begin
                        Result := 0.047775264866201018;
                    end
                    else
                    begin
                        Result := -0.00022800558098825608;
                    end;
                end;
            end
            else
            begin
                Result := -0.011352218988893268;
            end;
        end;
    end
    else
    begin
        if features.delta_chain_score_gap <= -240352822.99999997 then
        begin
            if features.delta_local_lm_r0 <= -376.49999999999994 then
            begin
                Result := 0.044078051863035456;
            end
            else
            begin
                Result := -0.0024031244489775717;
            end;
        end
        else
        begin
            if features.ranker_score_gap <= -63822726.499999993 then
            begin
                if features.candidate_complete_pool_consensus_majority_units <= 11.500000000000002 then
                begin
                    if features.delta_local_lm_r3 <= -5.4999999999999991 then
                    begin
                        if features.candidate_local_lm_r0 <= -6084.4999999999991 then
                        begin
                            Result := -0.0002224455650783205;
                        end
                        else
                        begin
                            Result := 0.005599661896730385;
                        end;
                    end
                    else
                    begin
                        if features.same_suffix_units <= 2.5000000000000004 then
                        begin
                            Result := -0.0091045398368689249;
                        end
                        else
                        begin
                            if features.delta_char_lm_score <= 394.50000000000006 then
                            begin
                                Result := -0.0012384904927728465;
                            end
                            else
                            begin
                                if features.candidate_candidate_score <= 50083.500000000007 then
                                begin
                                    Result := 0.040621057916324067;
                                end
                                else
                                begin
                                    Result := -0.0041127994984848561;
                                end;
                            end;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.0042146680644225779;
                end;
            end
            else
            begin
                Result := 0.0019981578836009194;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_158(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -242531249.49999997 then
    begin
        if features.candidate_local_lm_r1 <= -5047.4999999999991 then
        begin
            if features.candidate_local_lm_r0 <= -4259.4999999999991 then
            begin
                if features.top_local_lm_r1 <= -5131.4999999999991 then
                begin
                    if features.delta_candidate_score <= -1.0000000180025095E-35 then
                    begin
                        if features.delta_word_lm_zero_count <= 1.0000000180025095E-35 then
                        begin
                            Result := 0.0024511682782455946;
                        end
                        else
                        begin
                            Result := -0.014114781779444384;
                        end;
                    end
                    else
                    begin
                        if features.delta_dict_weight_per_unit <= -12459.499999999998 then
                        begin
                            if features.top_local_lm_r3 <= -6711.4999999999991 then
                            begin
                                Result := 0.0;
                            end
                            else
                            begin
                                Result := 0.061931860952155575;
                            end;
                        end
                        else
                        begin
                            Result := -0.0032529844641871184;
                        end;
                    end;
                end
                else
                begin
                    Result := -0.015714896210728586;
                end;
            end
            else
            begin
                Result := 0.026729305619777391;
            end;
        end
        else
        begin
            Result := 0.021242204803808128;
        end;
    end
    else
    begin
        if features.candidate_chain_score_gap <= -170087355.49999997 then
        begin
            if features.candidate_local_lm_r1 <= -6597.4999999999991 then
            begin
                Result := 0.0030848607369574257;
            end
            else
            begin
                if features.candidate_local_lm_r1 <= -5379.4999999999991 then
                begin
                    Result := 0.055573043811164007;
                end
                else
                begin
                    Result := -5.3798638938923981E-05;
                end;
            end;
        end
        else
        begin
            if features.top_local_lm_r1 <= -4542.4999999999991 then
            begin
                Result := 0.00069812495149510888;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -210.49999999999997 then
                begin
                    Result := -0.010201179545007447;
                end
                else
                begin
                    if features.delta_char_lm_score <= -61.499999999999993 then
                    begin
                        Result := -0.0072498307839542865;
                    end
                    else
                    begin
                        Result := 0.014158903027367942;
                    end;
                end;
            end;
        end;
    end;
end;

function long_top2_pairwise_swap_tree_159(
    const features: TncLongTop2PairwiseSwapFeatures): Double;
begin
    if features.ranker_score_gap <= -380833732.99999994 then
    begin
        if features.delta_candidate_score <= 47976.000000000007 then
        begin
            Result := -0.016407471237509727;
        end
        else
        begin
            Result := 0.018333320013090623;
        end;
    end
    else
    begin
        if features.difference_span_units <= 3.5000000000000004 then
        begin
            if features.top_local_lm_r1 <= -4757.4999999999991 then
            begin
                Result := 0.00077869676007062238;
            end
            else
            begin
                if features.delta_local_lm_r1 <= -2233.4999999999995 then
                begin
                    Result := -0.021231938727704677;
                end
                else
                begin
                    if features.same_suffix_units <= 4.5000000000000009 then
                    begin
                        if features.candidate_local_lm_r3 <= -7028.4999999999991 then
                        begin
                            if features.candidate_char_lm_suffix_score <= -6686.4999999999991 then
                            begin
                                Result := -0.0032863036152142667;
                            end
                            else
                            begin
                                Result := 0.048411244759220665;
                            end;
                        end
                        else
                        begin
                            if features.candidate_ranker_score <= 140744724.00000003 then
                            begin
                                Result := -0.01041842432288876;
                            end
                            else
                            begin
                                if features.top_local_lm_r0 <= -5202.4999999999991 then
                                begin
                                    if features.candidate_local_lm_r0 <= -5375.4999999999991 then
                                    begin
                                        if features.delta_chain_second_stage_score <= -130562680.49999999 then
                                        begin
                                            Result := 0.029359448400479174;
                                        end
                                        else
                                        begin
                                            Result := 0.0010852457095485225;
                                        end;
                                    end
                                    else
                                    begin
                                        Result := 0.031391947727312068;
                                    end;
                                end
                                else
                                begin
                                    Result := -0.0071636249271372771;
                                end;
                            end;
                        end;
                    end
                    else
                    begin
                        if features.delta_char_lm_per_difference <= 73.125000000000014 then
                        begin
                            if features.top_local_lm_r3 <= -3686.4999999999995 then
                            begin
                                Result := -0.010796272845997108;
                            end
                            else
                            begin
                                Result := 0.0068450834705294592;
                            end;
                        end
                        else
                        begin
                            Result := 0.017209773569982927;
                        end;
                    end;
                end;
            end;
        end
        else
        begin
            Result := -0.008929215784501468;
        end;
    end;
end;
function long_top2_pairwise_swap_score(
    const features: TncLongTop2PairwiseSwapFeatures): Int64;
var
    score: Double;
begin
    score := 0.0;
    score := score + long_top2_pairwise_swap_tree_0(features);
    score := score + long_top2_pairwise_swap_tree_1(features);
    score := score + long_top2_pairwise_swap_tree_2(features);
    score := score + long_top2_pairwise_swap_tree_3(features);
    score := score + long_top2_pairwise_swap_tree_4(features);
    score := score + long_top2_pairwise_swap_tree_5(features);
    score := score + long_top2_pairwise_swap_tree_6(features);
    score := score + long_top2_pairwise_swap_tree_7(features);
    score := score + long_top2_pairwise_swap_tree_8(features);
    score := score + long_top2_pairwise_swap_tree_9(features);
    score := score + long_top2_pairwise_swap_tree_10(features);
    score := score + long_top2_pairwise_swap_tree_11(features);
    score := score + long_top2_pairwise_swap_tree_12(features);
    score := score + long_top2_pairwise_swap_tree_13(features);
    score := score + long_top2_pairwise_swap_tree_14(features);
    score := score + long_top2_pairwise_swap_tree_15(features);
    score := score + long_top2_pairwise_swap_tree_16(features);
    score := score + long_top2_pairwise_swap_tree_17(features);
    score := score + long_top2_pairwise_swap_tree_18(features);
    score := score + long_top2_pairwise_swap_tree_19(features);
    score := score + long_top2_pairwise_swap_tree_20(features);
    score := score + long_top2_pairwise_swap_tree_21(features);
    score := score + long_top2_pairwise_swap_tree_22(features);
    score := score + long_top2_pairwise_swap_tree_23(features);
    score := score + long_top2_pairwise_swap_tree_24(features);
    score := score + long_top2_pairwise_swap_tree_25(features);
    score := score + long_top2_pairwise_swap_tree_26(features);
    score := score + long_top2_pairwise_swap_tree_27(features);
    score := score + long_top2_pairwise_swap_tree_28(features);
    score := score + long_top2_pairwise_swap_tree_29(features);
    score := score + long_top2_pairwise_swap_tree_30(features);
    score := score + long_top2_pairwise_swap_tree_31(features);
    score := score + long_top2_pairwise_swap_tree_32(features);
    score := score + long_top2_pairwise_swap_tree_33(features);
    score := score + long_top2_pairwise_swap_tree_34(features);
    score := score + long_top2_pairwise_swap_tree_35(features);
    score := score + long_top2_pairwise_swap_tree_36(features);
    score := score + long_top2_pairwise_swap_tree_37(features);
    score := score + long_top2_pairwise_swap_tree_38(features);
    score := score + long_top2_pairwise_swap_tree_39(features);
    score := score + long_top2_pairwise_swap_tree_40(features);
    score := score + long_top2_pairwise_swap_tree_41(features);
    score := score + long_top2_pairwise_swap_tree_42(features);
    score := score + long_top2_pairwise_swap_tree_43(features);
    score := score + long_top2_pairwise_swap_tree_44(features);
    score := score + long_top2_pairwise_swap_tree_45(features);
    score := score + long_top2_pairwise_swap_tree_46(features);
    score := score + long_top2_pairwise_swap_tree_47(features);
    score := score + long_top2_pairwise_swap_tree_48(features);
    score := score + long_top2_pairwise_swap_tree_49(features);
    score := score + long_top2_pairwise_swap_tree_50(features);
    score := score + long_top2_pairwise_swap_tree_51(features);
    score := score + long_top2_pairwise_swap_tree_52(features);
    score := score + long_top2_pairwise_swap_tree_53(features);
    score := score + long_top2_pairwise_swap_tree_54(features);
    score := score + long_top2_pairwise_swap_tree_55(features);
    score := score + long_top2_pairwise_swap_tree_56(features);
    score := score + long_top2_pairwise_swap_tree_57(features);
    score := score + long_top2_pairwise_swap_tree_58(features);
    score := score + long_top2_pairwise_swap_tree_59(features);
    score := score + long_top2_pairwise_swap_tree_60(features);
    score := score + long_top2_pairwise_swap_tree_61(features);
    score := score + long_top2_pairwise_swap_tree_62(features);
    score := score + long_top2_pairwise_swap_tree_63(features);
    score := score + long_top2_pairwise_swap_tree_64(features);
    score := score + long_top2_pairwise_swap_tree_65(features);
    score := score + long_top2_pairwise_swap_tree_66(features);
    score := score + long_top2_pairwise_swap_tree_67(features);
    score := score + long_top2_pairwise_swap_tree_68(features);
    score := score + long_top2_pairwise_swap_tree_69(features);
    score := score + long_top2_pairwise_swap_tree_70(features);
    score := score + long_top2_pairwise_swap_tree_71(features);
    score := score + long_top2_pairwise_swap_tree_72(features);
    score := score + long_top2_pairwise_swap_tree_73(features);
    score := score + long_top2_pairwise_swap_tree_74(features);
    score := score + long_top2_pairwise_swap_tree_75(features);
    score := score + long_top2_pairwise_swap_tree_76(features);
    score := score + long_top2_pairwise_swap_tree_77(features);
    score := score + long_top2_pairwise_swap_tree_78(features);
    score := score + long_top2_pairwise_swap_tree_79(features);
    score := score + long_top2_pairwise_swap_tree_80(features);
    score := score + long_top2_pairwise_swap_tree_81(features);
    score := score + long_top2_pairwise_swap_tree_82(features);
    score := score + long_top2_pairwise_swap_tree_83(features);
    score := score + long_top2_pairwise_swap_tree_84(features);
    score := score + long_top2_pairwise_swap_tree_85(features);
    score := score + long_top2_pairwise_swap_tree_86(features);
    score := score + long_top2_pairwise_swap_tree_87(features);
    score := score + long_top2_pairwise_swap_tree_88(features);
    score := score + long_top2_pairwise_swap_tree_89(features);
    score := score + long_top2_pairwise_swap_tree_90(features);
    score := score + long_top2_pairwise_swap_tree_91(features);
    score := score + long_top2_pairwise_swap_tree_92(features);
    score := score + long_top2_pairwise_swap_tree_93(features);
    score := score + long_top2_pairwise_swap_tree_94(features);
    score := score + long_top2_pairwise_swap_tree_95(features);
    score := score + long_top2_pairwise_swap_tree_96(features);
    score := score + long_top2_pairwise_swap_tree_97(features);
    score := score + long_top2_pairwise_swap_tree_98(features);
    score := score + long_top2_pairwise_swap_tree_99(features);
    score := score + long_top2_pairwise_swap_tree_100(features);
    score := score + long_top2_pairwise_swap_tree_101(features);
    score := score + long_top2_pairwise_swap_tree_102(features);
    score := score + long_top2_pairwise_swap_tree_103(features);
    score := score + long_top2_pairwise_swap_tree_104(features);
    score := score + long_top2_pairwise_swap_tree_105(features);
    score := score + long_top2_pairwise_swap_tree_106(features);
    score := score + long_top2_pairwise_swap_tree_107(features);
    score := score + long_top2_pairwise_swap_tree_108(features);
    score := score + long_top2_pairwise_swap_tree_109(features);
    score := score + long_top2_pairwise_swap_tree_110(features);
    score := score + long_top2_pairwise_swap_tree_111(features);
    score := score + long_top2_pairwise_swap_tree_112(features);
    score := score + long_top2_pairwise_swap_tree_113(features);
    score := score + long_top2_pairwise_swap_tree_114(features);
    score := score + long_top2_pairwise_swap_tree_115(features);
    score := score + long_top2_pairwise_swap_tree_116(features);
    score := score + long_top2_pairwise_swap_tree_117(features);
    score := score + long_top2_pairwise_swap_tree_118(features);
    score := score + long_top2_pairwise_swap_tree_119(features);
    score := score + long_top2_pairwise_swap_tree_120(features);
    score := score + long_top2_pairwise_swap_tree_121(features);
    score := score + long_top2_pairwise_swap_tree_122(features);
    score := score + long_top2_pairwise_swap_tree_123(features);
    score := score + long_top2_pairwise_swap_tree_124(features);
    score := score + long_top2_pairwise_swap_tree_125(features);
    score := score + long_top2_pairwise_swap_tree_126(features);
    score := score + long_top2_pairwise_swap_tree_127(features);
    score := score + long_top2_pairwise_swap_tree_128(features);
    score := score + long_top2_pairwise_swap_tree_129(features);
    score := score + long_top2_pairwise_swap_tree_130(features);
    score := score + long_top2_pairwise_swap_tree_131(features);
    score := score + long_top2_pairwise_swap_tree_132(features);
    score := score + long_top2_pairwise_swap_tree_133(features);
    score := score + long_top2_pairwise_swap_tree_134(features);
    score := score + long_top2_pairwise_swap_tree_135(features);
    score := score + long_top2_pairwise_swap_tree_136(features);
    score := score + long_top2_pairwise_swap_tree_137(features);
    score := score + long_top2_pairwise_swap_tree_138(features);
    score := score + long_top2_pairwise_swap_tree_139(features);
    score := score + long_top2_pairwise_swap_tree_140(features);
    score := score + long_top2_pairwise_swap_tree_141(features);
    score := score + long_top2_pairwise_swap_tree_142(features);
    score := score + long_top2_pairwise_swap_tree_143(features);
    score := score + long_top2_pairwise_swap_tree_144(features);
    score := score + long_top2_pairwise_swap_tree_145(features);
    score := score + long_top2_pairwise_swap_tree_146(features);
    score := score + long_top2_pairwise_swap_tree_147(features);
    score := score + long_top2_pairwise_swap_tree_148(features);
    score := score + long_top2_pairwise_swap_tree_149(features);
    score := score + long_top2_pairwise_swap_tree_150(features);
    score := score + long_top2_pairwise_swap_tree_151(features);
    score := score + long_top2_pairwise_swap_tree_152(features);
    score := score + long_top2_pairwise_swap_tree_153(features);
    score := score + long_top2_pairwise_swap_tree_154(features);
    score := score + long_top2_pairwise_swap_tree_155(features);
    score := score + long_top2_pairwise_swap_tree_156(features);
    score := score + long_top2_pairwise_swap_tree_157(features);
    score := score + long_top2_pairwise_swap_tree_158(features);
    score := score + long_top2_pairwise_swap_tree_159(features);
    Result := Trunc(score * c_long_top2_pairwise_swap_score_scale);
end;

function long_top2_pairwise_swap_self_test: Boolean;
var
    features: TncLongTop2PairwiseSwapFeatures;
begin
    FillChar(features, SizeOf(features), 0);
    if long_top2_pairwise_swap_score(features) <>
        c_long_top2_pairwise_swap_reference_score then Exit(False);
    features.candidate_candidate_score := -1000000;
    features.candidate_dict_weight := -1000000;
    features.candidate_has_dict_weight := -1000000;
    features.candidate_source_user := -1000000;
    features.candidate_source_chain := -1000000;
    features.candidate_source_pattern := -1000000;
    features.candidate_source_redup := -1000000;
    features.candidate_source_local_rerank := -1000000;
    features.candidate_source_rule_fallback := -1000000;
    features.candidate_legacy_rank := -1000000;
    features.candidate_legacy_top := -1000000;
    features.candidate_chain_rank := -1000000;
    features.candidate_chain_present := -1000000;
    features.candidate_chain_first_stage_score := -1000000;
    features.candidate_chain_second_stage_score := -1000000;
    features.candidate_chain_score_gap := -1000000;
    features.candidate_complete_match := -1000000;
    features.candidate_partial_match := -1000000;
    features.candidate_text_units := -1000000;
    features.candidate_comment_length := -1000000;
    features.candidate_unit_delta := -1000000;
    features.candidate_path_available := -1000000;
    features.candidate_path_confidence_score := -1000000;
    features.candidate_path_confidence_tier := -1000000;
    features.candidate_path_segments := -1000000;
    features.candidate_path_single_segments := -1000000;
    features.candidate_path_max_segment_units := -1000000;
    features.candidate_char_lm_score := -1000000;
    features.candidate_char_lm_suffix_score := -1000000;
    features.candidate_char_lm_context_score := -1000000;
    features.candidate_char_lm_context_gain := -1000000;
    features.candidate_has_left_context := -1000000;
    features.candidate_query_choice_bonus := -1000000;
    features.candidate_latest_query_choice := -1000000;
    features.candidate_query_path_bonus := -1000000;
    features.candidate_query_path_penalty := -1000000;
    features.candidate_word_lm_bonus := -1000000;
    features.candidate_word_lm_boundary_count := -1000000;
    features.candidate_word_lm_boundary_min := -1000000;
    features.candidate_word_lm_boundary_max := -1000000;
    features.candidate_word_lm_boundary_first := -1000000;
    features.candidate_word_lm_boundary_last := -1000000;
    features.candidate_word_lm_supported_ratio := -1000000;
    features.candidate_word_lm_strong_ratio := -1000000;
    features.candidate_word_lm_trigram_ratio := -1000000;
    features.candidate_word_lm_zero_count := -1000000;
    features.candidate_input_syllable_count := -1000000;
    features.candidate_score_per_unit := -1000000;
    features.candidate_dict_weight_per_unit := -1000000;
    features.candidate_complete_user := -1000000;
    features.candidate_complete_dictionary := -1000000;
    features.candidate_complete_chain := -1000000;
    features.candidate_complete_pool_present := -1000000;
    features.candidate_complete_pool_source_kind := -1000000;
    features.candidate_complete_pool_rank := -1000000;
    features.candidate_complete_pool_seed_rank := -1000000;
    features.candidate_complete_pool_original := -1000000;
    features.candidate_complete_pool_substitutions := -1000000;
    features.candidate_complete_pool_changed_position := -1000000;
    features.candidate_complete_pool_pair_evidence := -1000000;
    features.candidate_complete_pool_proper_name_confidence := -1000000;
    features.candidate_complete_pool_signature_support := -1000000;
    features.candidate_complete_pool_consensus_support := -1000000;
    features.candidate_complete_pool_consensus_seed_count := -1000000;
    features.candidate_complete_pool_consensus_support_mean := -1000000;
    features.candidate_complete_pool_consensus_support_min := -1000000;
    features.candidate_complete_pool_consensus_majority_units := -1000000;
    features.candidate_complete_pool_consensus_unanimous_units := -1000000;
    features.candidate_complete_pool_consensus_nearest_distance := -1000000;
    features.candidate_complete_pool_consensus_mean_distance := -1000000;
    features.candidate_complete_pool_consensus_changed_support := -1000000;
    features.candidate_complete_pool_consensus_changed_top_match := -1000000;
    features.candidate_complete_pool_local_pairwise_score := -1000000;
    features.delta_candidate_score := -1000000;
    features.delta_dict_weight := -1000000;
    features.delta_has_dict_weight := -1000000;
    features.delta_source_user := -1000000;
    features.delta_source_chain := -1000000;
    features.delta_source_pattern := -1000000;
    features.delta_source_redup := -1000000;
    features.delta_source_local_rerank := -1000000;
    features.delta_source_rule_fallback := -1000000;
    features.delta_legacy_rank := -1000000;
    features.delta_legacy_top := -1000000;
    features.delta_chain_rank := -1000000;
    features.delta_chain_present := -1000000;
    features.delta_chain_first_stage_score := -1000000;
    features.delta_chain_second_stage_score := -1000000;
    features.delta_chain_score_gap := -1000000;
    features.delta_complete_match := -1000000;
    features.delta_partial_match := -1000000;
    features.delta_text_units := -1000000;
    features.delta_comment_length := -1000000;
    features.delta_unit_delta := -1000000;
    features.delta_path_available := -1000000;
    features.delta_path_confidence_score := -1000000;
    features.delta_path_confidence_tier := -1000000;
    features.delta_path_segments := -1000000;
    features.delta_path_single_segments := -1000000;
    features.delta_path_max_segment_units := -1000000;
    features.delta_char_lm_score := -1000000;
    features.delta_char_lm_suffix_score := -1000000;
    features.delta_char_lm_context_score := -1000000;
    features.delta_char_lm_context_gain := -1000000;
    features.delta_has_left_context := -1000000;
    features.delta_query_choice_bonus := -1000000;
    features.delta_latest_query_choice := -1000000;
    features.delta_query_path_bonus := -1000000;
    features.delta_query_path_penalty := -1000000;
    features.delta_word_lm_bonus := -1000000;
    features.delta_word_lm_boundary_count := -1000000;
    features.delta_word_lm_boundary_min := -1000000;
    features.delta_word_lm_boundary_max := -1000000;
    features.delta_word_lm_boundary_first := -1000000;
    features.delta_word_lm_boundary_last := -1000000;
    features.delta_word_lm_supported_ratio := -1000000;
    features.delta_word_lm_strong_ratio := -1000000;
    features.delta_word_lm_trigram_ratio := -1000000;
    features.delta_word_lm_zero_count := -1000000;
    features.delta_input_syllable_count := -1000000;
    features.delta_score_per_unit := -1000000;
    features.delta_dict_weight_per_unit := -1000000;
    features.delta_complete_user := -1000000;
    features.delta_complete_dictionary := -1000000;
    features.delta_complete_chain := -1000000;
    features.delta_complete_pool_present := -1000000;
    features.delta_complete_pool_source_kind := -1000000;
    features.delta_complete_pool_rank := -1000000;
    features.delta_complete_pool_seed_rank := -1000000;
    features.delta_complete_pool_original := -1000000;
    features.delta_complete_pool_substitutions := -1000000;
    features.delta_complete_pool_changed_position := -1000000;
    features.delta_complete_pool_pair_evidence := -1000000;
    features.delta_complete_pool_proper_name_confidence := -1000000;
    features.delta_complete_pool_signature_support := -1000000;
    features.delta_complete_pool_consensus_support := -1000000;
    features.delta_complete_pool_consensus_seed_count := -1000000;
    features.delta_complete_pool_consensus_support_mean := -1000000;
    features.delta_complete_pool_consensus_support_min := -1000000;
    features.delta_complete_pool_consensus_majority_units := -1000000;
    features.delta_complete_pool_consensus_unanimous_units := -1000000;
    features.delta_complete_pool_consensus_nearest_distance := -1000000;
    features.delta_complete_pool_consensus_mean_distance := -1000000;
    features.delta_complete_pool_consensus_changed_support := -1000000;
    features.delta_complete_pool_consensus_changed_top_match := -1000000;
    features.delta_complete_pool_local_pairwise_score := -1000000;
    features.candidate_ranker_score := -1000000;
    features.top_ranker_score := -1000000;
    features.ranker_score_gap := -1000000;
    features.baseline_ranker_applied := -1000000;
    features.baseline_abstain_score := -1000000;
    features.different_units := -1000000;
    features.different_runs := -1000000;
    features.max_different_run := -1000000;
    features.same_prefix_units := -1000000;
    features.same_suffix_units := -1000000;
    features.difference_span_units := -1000000;
    features.same_segment_path := -1000000;
    features.top_local_lm_r0 := -1000000;
    features.candidate_local_lm_r0 := -1000000;
    features.delta_local_lm_r0 := -1000000;
    features.top_local_lm_r1 := -1000000;
    features.candidate_local_lm_r1 := -1000000;
    features.delta_local_lm_r1 := -1000000;
    features.top_local_lm_r2 := -1000000;
    features.candidate_local_lm_r2 := -1000000;
    features.delta_local_lm_r2 := -1000000;
    features.top_local_lm_r3 := -1000000;
    features.candidate_local_lm_r3 := -1000000;
    features.delta_local_lm_r3 := -1000000;
    features.delta_char_lm_per_difference := -1000000;
    features.delta_char_suffix_lm_per_difference := -1000000;
    features.delta_word_lm_per_boundary := -1000000;
    if long_top2_pairwise_swap_score(features) <>
        c_long_top2_pairwise_swap_reference_score_low then Exit(False);
    features.candidate_candidate_score := 1000000;
    features.candidate_dict_weight := 1000000;
    features.candidate_has_dict_weight := 1000000;
    features.candidate_source_user := 1000000;
    features.candidate_source_chain := 1000000;
    features.candidate_source_pattern := 1000000;
    features.candidate_source_redup := 1000000;
    features.candidate_source_local_rerank := 1000000;
    features.candidate_source_rule_fallback := 1000000;
    features.candidate_legacy_rank := 1000000;
    features.candidate_legacy_top := 1000000;
    features.candidate_chain_rank := 1000000;
    features.candidate_chain_present := 1000000;
    features.candidate_chain_first_stage_score := 1000000;
    features.candidate_chain_second_stage_score := 1000000;
    features.candidate_chain_score_gap := 1000000;
    features.candidate_complete_match := 1000000;
    features.candidate_partial_match := 1000000;
    features.candidate_text_units := 1000000;
    features.candidate_comment_length := 1000000;
    features.candidate_unit_delta := 1000000;
    features.candidate_path_available := 1000000;
    features.candidate_path_confidence_score := 1000000;
    features.candidate_path_confidence_tier := 1000000;
    features.candidate_path_segments := 1000000;
    features.candidate_path_single_segments := 1000000;
    features.candidate_path_max_segment_units := 1000000;
    features.candidate_char_lm_score := 1000000;
    features.candidate_char_lm_suffix_score := 1000000;
    features.candidate_char_lm_context_score := 1000000;
    features.candidate_char_lm_context_gain := 1000000;
    features.candidate_has_left_context := 1000000;
    features.candidate_query_choice_bonus := 1000000;
    features.candidate_latest_query_choice := 1000000;
    features.candidate_query_path_bonus := 1000000;
    features.candidate_query_path_penalty := 1000000;
    features.candidate_word_lm_bonus := 1000000;
    features.candidate_word_lm_boundary_count := 1000000;
    features.candidate_word_lm_boundary_min := 1000000;
    features.candidate_word_lm_boundary_max := 1000000;
    features.candidate_word_lm_boundary_first := 1000000;
    features.candidate_word_lm_boundary_last := 1000000;
    features.candidate_word_lm_supported_ratio := 1000000;
    features.candidate_word_lm_strong_ratio := 1000000;
    features.candidate_word_lm_trigram_ratio := 1000000;
    features.candidate_word_lm_zero_count := 1000000;
    features.candidate_input_syllable_count := 1000000;
    features.candidate_score_per_unit := 1000000;
    features.candidate_dict_weight_per_unit := 1000000;
    features.candidate_complete_user := 1000000;
    features.candidate_complete_dictionary := 1000000;
    features.candidate_complete_chain := 1000000;
    features.candidate_complete_pool_present := 1000000;
    features.candidate_complete_pool_source_kind := 1000000;
    features.candidate_complete_pool_rank := 1000000;
    features.candidate_complete_pool_seed_rank := 1000000;
    features.candidate_complete_pool_original := 1000000;
    features.candidate_complete_pool_substitutions := 1000000;
    features.candidate_complete_pool_changed_position := 1000000;
    features.candidate_complete_pool_pair_evidence := 1000000;
    features.candidate_complete_pool_proper_name_confidence := 1000000;
    features.candidate_complete_pool_signature_support := 1000000;
    features.candidate_complete_pool_consensus_support := 1000000;
    features.candidate_complete_pool_consensus_seed_count := 1000000;
    features.candidate_complete_pool_consensus_support_mean := 1000000;
    features.candidate_complete_pool_consensus_support_min := 1000000;
    features.candidate_complete_pool_consensus_majority_units := 1000000;
    features.candidate_complete_pool_consensus_unanimous_units := 1000000;
    features.candidate_complete_pool_consensus_nearest_distance := 1000000;
    features.candidate_complete_pool_consensus_mean_distance := 1000000;
    features.candidate_complete_pool_consensus_changed_support := 1000000;
    features.candidate_complete_pool_consensus_changed_top_match := 1000000;
    features.candidate_complete_pool_local_pairwise_score := 1000000;
    features.delta_candidate_score := 1000000;
    features.delta_dict_weight := 1000000;
    features.delta_has_dict_weight := 1000000;
    features.delta_source_user := 1000000;
    features.delta_source_chain := 1000000;
    features.delta_source_pattern := 1000000;
    features.delta_source_redup := 1000000;
    features.delta_source_local_rerank := 1000000;
    features.delta_source_rule_fallback := 1000000;
    features.delta_legacy_rank := 1000000;
    features.delta_legacy_top := 1000000;
    features.delta_chain_rank := 1000000;
    features.delta_chain_present := 1000000;
    features.delta_chain_first_stage_score := 1000000;
    features.delta_chain_second_stage_score := 1000000;
    features.delta_chain_score_gap := 1000000;
    features.delta_complete_match := 1000000;
    features.delta_partial_match := 1000000;
    features.delta_text_units := 1000000;
    features.delta_comment_length := 1000000;
    features.delta_unit_delta := 1000000;
    features.delta_path_available := 1000000;
    features.delta_path_confidence_score := 1000000;
    features.delta_path_confidence_tier := 1000000;
    features.delta_path_segments := 1000000;
    features.delta_path_single_segments := 1000000;
    features.delta_path_max_segment_units := 1000000;
    features.delta_char_lm_score := 1000000;
    features.delta_char_lm_suffix_score := 1000000;
    features.delta_char_lm_context_score := 1000000;
    features.delta_char_lm_context_gain := 1000000;
    features.delta_has_left_context := 1000000;
    features.delta_query_choice_bonus := 1000000;
    features.delta_latest_query_choice := 1000000;
    features.delta_query_path_bonus := 1000000;
    features.delta_query_path_penalty := 1000000;
    features.delta_word_lm_bonus := 1000000;
    features.delta_word_lm_boundary_count := 1000000;
    features.delta_word_lm_boundary_min := 1000000;
    features.delta_word_lm_boundary_max := 1000000;
    features.delta_word_lm_boundary_first := 1000000;
    features.delta_word_lm_boundary_last := 1000000;
    features.delta_word_lm_supported_ratio := 1000000;
    features.delta_word_lm_strong_ratio := 1000000;
    features.delta_word_lm_trigram_ratio := 1000000;
    features.delta_word_lm_zero_count := 1000000;
    features.delta_input_syllable_count := 1000000;
    features.delta_score_per_unit := 1000000;
    features.delta_dict_weight_per_unit := 1000000;
    features.delta_complete_user := 1000000;
    features.delta_complete_dictionary := 1000000;
    features.delta_complete_chain := 1000000;
    features.delta_complete_pool_present := 1000000;
    features.delta_complete_pool_source_kind := 1000000;
    features.delta_complete_pool_rank := 1000000;
    features.delta_complete_pool_seed_rank := 1000000;
    features.delta_complete_pool_original := 1000000;
    features.delta_complete_pool_substitutions := 1000000;
    features.delta_complete_pool_changed_position := 1000000;
    features.delta_complete_pool_pair_evidence := 1000000;
    features.delta_complete_pool_proper_name_confidence := 1000000;
    features.delta_complete_pool_signature_support := 1000000;
    features.delta_complete_pool_consensus_support := 1000000;
    features.delta_complete_pool_consensus_seed_count := 1000000;
    features.delta_complete_pool_consensus_support_mean := 1000000;
    features.delta_complete_pool_consensus_support_min := 1000000;
    features.delta_complete_pool_consensus_majority_units := 1000000;
    features.delta_complete_pool_consensus_unanimous_units := 1000000;
    features.delta_complete_pool_consensus_nearest_distance := 1000000;
    features.delta_complete_pool_consensus_mean_distance := 1000000;
    features.delta_complete_pool_consensus_changed_support := 1000000;
    features.delta_complete_pool_consensus_changed_top_match := 1000000;
    features.delta_complete_pool_local_pairwise_score := 1000000;
    features.candidate_ranker_score := 1000000;
    features.top_ranker_score := 1000000;
    features.ranker_score_gap := 1000000;
    features.baseline_ranker_applied := 1000000;
    features.baseline_abstain_score := 1000000;
    features.different_units := 1000000;
    features.different_runs := 1000000;
    features.max_different_run := 1000000;
    features.same_prefix_units := 1000000;
    features.same_suffix_units := 1000000;
    features.difference_span_units := 1000000;
    features.same_segment_path := 1000000;
    features.top_local_lm_r0 := 1000000;
    features.candidate_local_lm_r0 := 1000000;
    features.delta_local_lm_r0 := 1000000;
    features.top_local_lm_r1 := 1000000;
    features.candidate_local_lm_r1 := 1000000;
    features.delta_local_lm_r1 := 1000000;
    features.top_local_lm_r2 := 1000000;
    features.candidate_local_lm_r2 := 1000000;
    features.delta_local_lm_r2 := 1000000;
    features.top_local_lm_r3 := 1000000;
    features.candidate_local_lm_r3 := 1000000;
    features.delta_local_lm_r3 := 1000000;
    features.delta_char_lm_per_difference := 1000000;
    features.delta_char_suffix_lm_per_difference := 1000000;
    features.delta_word_lm_per_boundary := 1000000;
    if long_top2_pairwise_swap_score(features) <>
        c_long_top2_pairwise_swap_reference_score_high then Exit(False);
    features.candidate_candidate_score := 137;
    features.candidate_dict_weight := -274;
    features.candidate_has_dict_weight := 411;
    features.candidate_source_user := -548;
    features.candidate_source_chain := 685;
    features.candidate_source_pattern := -822;
    features.candidate_source_redup := 959;
    features.candidate_source_local_rerank := -1096;
    features.candidate_source_rule_fallback := 1233;
    features.candidate_legacy_rank := -1370;
    features.candidate_legacy_top := 1507;
    features.candidate_chain_rank := -1644;
    features.candidate_chain_present := 1781;
    features.candidate_chain_first_stage_score := -1918;
    features.candidate_chain_second_stage_score := 2055;
    features.candidate_chain_score_gap := -2192;
    features.candidate_complete_match := 2329;
    features.candidate_partial_match := -2466;
    features.candidate_text_units := 2603;
    features.candidate_comment_length := -2740;
    features.candidate_unit_delta := 2877;
    features.candidate_path_available := -3014;
    features.candidate_path_confidence_score := 3151;
    features.candidate_path_confidence_tier := -3288;
    features.candidate_path_segments := 3425;
    features.candidate_path_single_segments := -3562;
    features.candidate_path_max_segment_units := 3699;
    features.candidate_char_lm_score := -3836;
    features.candidate_char_lm_suffix_score := 3973;
    features.candidate_char_lm_context_score := -4110;
    features.candidate_char_lm_context_gain := 4247;
    features.candidate_has_left_context := -4384;
    features.candidate_query_choice_bonus := 4521;
    features.candidate_latest_query_choice := -4658;
    features.candidate_query_path_bonus := 4795;
    features.candidate_query_path_penalty := -4932;
    features.candidate_word_lm_bonus := 5069;
    features.candidate_word_lm_boundary_count := -5206;
    features.candidate_word_lm_boundary_min := 5343;
    features.candidate_word_lm_boundary_max := -5480;
    features.candidate_word_lm_boundary_first := 5617;
    features.candidate_word_lm_boundary_last := -5754;
    features.candidate_word_lm_supported_ratio := 5891;
    features.candidate_word_lm_strong_ratio := -6028;
    features.candidate_word_lm_trigram_ratio := 6165;
    features.candidate_word_lm_zero_count := -6302;
    features.candidate_input_syllable_count := 6439;
    features.candidate_score_per_unit := -6576;
    features.candidate_dict_weight_per_unit := 6713;
    features.candidate_complete_user := -6850;
    features.candidate_complete_dictionary := 6987;
    features.candidate_complete_chain := -7124;
    features.candidate_complete_pool_present := 7261;
    features.candidate_complete_pool_source_kind := -7398;
    features.candidate_complete_pool_rank := 7535;
    features.candidate_complete_pool_seed_rank := -7672;
    features.candidate_complete_pool_original := 7809;
    features.candidate_complete_pool_substitutions := -7946;
    features.candidate_complete_pool_changed_position := 8083;
    features.candidate_complete_pool_pair_evidence := -8220;
    features.candidate_complete_pool_proper_name_confidence := 8357;
    features.candidate_complete_pool_signature_support := -8494;
    features.candidate_complete_pool_consensus_support := 8631;
    features.candidate_complete_pool_consensus_seed_count := -8768;
    features.candidate_complete_pool_consensus_support_mean := 8905;
    features.candidate_complete_pool_consensus_support_min := -9042;
    features.candidate_complete_pool_consensus_majority_units := 9179;
    features.candidate_complete_pool_consensus_unanimous_units := -9316;
    features.candidate_complete_pool_consensus_nearest_distance := 9453;
    features.candidate_complete_pool_consensus_mean_distance := -9590;
    features.candidate_complete_pool_consensus_changed_support := 9727;
    features.candidate_complete_pool_consensus_changed_top_match := -9864;
    features.candidate_complete_pool_local_pairwise_score := 10001;
    features.delta_candidate_score := -10138;
    features.delta_dict_weight := 10275;
    features.delta_has_dict_weight := -10412;
    features.delta_source_user := 10549;
    features.delta_source_chain := -10686;
    features.delta_source_pattern := 10823;
    features.delta_source_redup := -10960;
    features.delta_source_local_rerank := 11097;
    features.delta_source_rule_fallback := -11234;
    features.delta_legacy_rank := 11371;
    features.delta_legacy_top := -11508;
    features.delta_chain_rank := 11645;
    features.delta_chain_present := -11782;
    features.delta_chain_first_stage_score := 11919;
    features.delta_chain_second_stage_score := -12056;
    features.delta_chain_score_gap := 12193;
    features.delta_complete_match := -12330;
    features.delta_partial_match := 12467;
    features.delta_text_units := -12604;
    features.delta_comment_length := 12741;
    features.delta_unit_delta := -12878;
    features.delta_path_available := 13015;
    features.delta_path_confidence_score := -13152;
    features.delta_path_confidence_tier := 13289;
    features.delta_path_segments := -13426;
    features.delta_path_single_segments := 13563;
    features.delta_path_max_segment_units := -13700;
    features.delta_char_lm_score := 13837;
    features.delta_char_lm_suffix_score := -13974;
    features.delta_char_lm_context_score := 14111;
    features.delta_char_lm_context_gain := -14248;
    features.delta_has_left_context := 14385;
    features.delta_query_choice_bonus := -14522;
    features.delta_latest_query_choice := 14659;
    features.delta_query_path_bonus := -14796;
    features.delta_query_path_penalty := 14933;
    features.delta_word_lm_bonus := -15070;
    features.delta_word_lm_boundary_count := 15207;
    features.delta_word_lm_boundary_min := -15344;
    features.delta_word_lm_boundary_max := 15481;
    features.delta_word_lm_boundary_first := -15618;
    features.delta_word_lm_boundary_last := 15755;
    features.delta_word_lm_supported_ratio := -15892;
    features.delta_word_lm_strong_ratio := 16029;
    features.delta_word_lm_trigram_ratio := -16166;
    features.delta_word_lm_zero_count := 16303;
    features.delta_input_syllable_count := -16440;
    features.delta_score_per_unit := 16577;
    features.delta_dict_weight_per_unit := -16714;
    features.delta_complete_user := 16851;
    features.delta_complete_dictionary := -16988;
    features.delta_complete_chain := 17125;
    features.delta_complete_pool_present := -17262;
    features.delta_complete_pool_source_kind := 17399;
    features.delta_complete_pool_rank := -17536;
    features.delta_complete_pool_seed_rank := 17673;
    features.delta_complete_pool_original := -17810;
    features.delta_complete_pool_substitutions := 17947;
    features.delta_complete_pool_changed_position := -18084;
    features.delta_complete_pool_pair_evidence := 18221;
    features.delta_complete_pool_proper_name_confidence := -18358;
    features.delta_complete_pool_signature_support := 18495;
    features.delta_complete_pool_consensus_support := -18632;
    features.delta_complete_pool_consensus_seed_count := 18769;
    features.delta_complete_pool_consensus_support_mean := -18906;
    features.delta_complete_pool_consensus_support_min := 19043;
    features.delta_complete_pool_consensus_majority_units := -19180;
    features.delta_complete_pool_consensus_unanimous_units := 19317;
    features.delta_complete_pool_consensus_nearest_distance := -19454;
    features.delta_complete_pool_consensus_mean_distance := 19591;
    features.delta_complete_pool_consensus_changed_support := -19728;
    features.delta_complete_pool_consensus_changed_top_match := 19865;
    features.delta_complete_pool_local_pairwise_score := -20002;
    features.candidate_ranker_score := 20139;
    features.top_ranker_score := -20276;
    features.ranker_score_gap := 20413;
    features.baseline_ranker_applied := -20550;
    features.baseline_abstain_score := 20687;
    features.different_units := -20824;
    features.different_runs := 20961;
    features.max_different_run := -21098;
    features.same_prefix_units := 21235;
    features.same_suffix_units := -21372;
    features.difference_span_units := 21509;
    features.same_segment_path := -21646;
    features.top_local_lm_r0 := 21783;
    features.candidate_local_lm_r0 := -21920;
    features.delta_local_lm_r0 := 22057;
    features.top_local_lm_r1 := -22194;
    features.candidate_local_lm_r1 := 22331;
    features.delta_local_lm_r1 := -22468;
    features.top_local_lm_r2 := 22605;
    features.candidate_local_lm_r2 := -22742;
    features.delta_local_lm_r2 := 22879;
    features.top_local_lm_r3 := -23016;
    features.candidate_local_lm_r3 := 23153;
    features.delta_local_lm_r3 := -23290;
    features.delta_char_lm_per_difference := 23427;
    features.delta_char_suffix_lm_per_difference := -23564;
    features.delta_word_lm_per_boundary := 23701;
    Result := long_top2_pairwise_swap_score(features) =
        c_long_top2_pairwise_swap_reference_score_mixed;
end;

end.
