unit nc_engine_intf;

interface

uses
    System.SysUtils,
    System.Math,
    System.Classes,
    System.IOUtils,
    System.Generics.Collections,
    System.Generics.Defaults,
    Winapi.Windows,
    nc_types,
    nc_dictionary_intf,
    nc_dictionary_sqlite,
    nc_pinyin_parser,
    nc_config;

type
    TncInMemoryDictionary = class(TncDictionaryProvider)
    private
        m_map: TDictionary<string, TArray<string>>;
        procedure add_entry(const pinyin: string; const items: array of string);
    public
        constructor create;
        destructor Destroy; override;
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; override;
    end;

    TncConfirmedSegment = record
        text: string;
        pinyin: string;
    end;

    TncEngine = class
    private
        m_config: TncEngineConfig;
        m_composition_text: string;
        m_composition_display_text: string;
        m_candidates: TncCandidateList;
        m_dictionary: TncDictionaryProvider;
        m_cached_dictionary_simplified: TncDictionaryProvider;
        m_cached_dictionary_traditional: TncDictionaryProvider;
        m_dictionary_path: string;
        m_dictionary_write_time: TDateTime;
        m_user_dictionary_path: string;
        m_user_dictionary_write_time: TDateTime;
        m_last_dictionary_reload_check_tick: UInt64;
        m_left_context: string;
        m_external_left_context: string;
        m_segment_left_context: string;
        m_context_pairs: TDictionary<string, Integer>;
        m_context_order: TQueue<string>;
        m_phrase_context_pairs: TDictionary<string, Integer>;
        m_phrase_context_order: TQueue<string>;
        m_phrase_context_last_seen: TDictionary<string, Int64>;
        m_session_text_counts: TDictionary<string, Integer>;
        m_session_text_last_seen: TDictionary<string, Int64>;
        m_session_text_order: TQueue<string>;
        m_session_query_choice_counts: TDictionary<string, Integer>;
        m_session_query_choice_last_seen: TDictionary<string, Int64>;
        m_session_query_choice_order: TQueue<string>;
        m_session_query_latest_text: TDictionary<string, string>;
        m_session_query_path_choice_counts: TDictionary<string, Integer>;
        m_session_query_path_choice_last_seen: TDictionary<string, Int64>;
        m_session_query_path_choice_order: TQueue<string>;
        m_session_query_path_penalty_counts: TDictionary<string, Integer>;
        m_session_query_path_penalty_last_seen: TDictionary<string, Int64>;
        m_session_query_path_penalty_order: TQueue<string>;
        m_session_ranked_query_paths: TDictionary<string, string>;
        m_session_ranked_query_path_scores: TDictionary<string, Integer>;
        m_session_ranked_query_path_order: TQueue<string>;
        m_session_context_query_choice_counts: TDictionary<string, Integer>;
        m_session_context_query_choice_last_seen: TDictionary<string, Int64>;
        m_session_context_query_choice_order: TQueue<string>;
        m_session_context_query_latest_text: TDictionary<string, string>;
        m_session_commit_serial: Int64;
        m_last_output_commit_text: string;
        m_prev_output_commit_text: string;
        m_context_db_bonus_cache_key: string;
        m_context_db_bonus_cache: TDictionary<string, Integer>;
        m_lookup_text_unit_count_cache: TDictionary<string, Integer>;
        m_lookup_session_bonus_cache: TDictionary<string, Integer>;
        m_lookup_query_bonus_cache: TDictionary<string, Integer>;
        m_lookup_query_latest_text_cache: TDictionary<string, string>;
        m_lookup_query_path_bonus_cache: TDictionary<string, Integer>;
        m_lookup_context_query_bonus_cache: TDictionary<string, Integer>;
        m_lookup_context_query_latest_bonus_cache: TDictionary<string, Integer>;
        m_lookup_phrase_context_bonus_cache: TDictionary<string, Integer>;
        m_lookup_text_context_bonus_cache: TDictionary<string, Integer>;
        m_lookup_context_bonus_cache: TDictionary<string, Integer>;
        m_lookup_segment_path_context_bonus_cache: TDictionary<string, Integer>;
        m_lookup_segment_path_preference_cache: TDictionary<string, Integer>;
        m_lookup_candidate_path_confidence_cache: TDictionary<string, Integer>;
        m_current_segment_path_map: TDictionary<string, string>;
        m_current_segment_path_score_map: TDictionary<string, Integer>;
        m_current_segment_path_query_prefix_map: TDictionary<string, string>;
        m_candidate_segment_paths: TArray<string>;
        m_pending_commit_text: string;
        m_pending_commit_remaining: string;
        m_has_pending_commit: Boolean;
        m_pending_commit_allow_learning: Boolean;
        m_pending_commit_segment_path: string;
        m_pending_commit_query_key: string;
        m_last_debug_commit_segment_path: string;
        m_last_lookup_key: string;
        m_last_lookup_normalized_from: string;
        m_last_lookup_syllable_count: Integer;
        m_last_three_syllable_partial_preference_kind: Integer;
        m_last_three_syllable_head_exact_text: string;
        m_last_three_syllable_head_strength: Integer;
        m_last_three_syllable_tail_strength: Integer;
        m_last_three_syllable_first_single_strength: Integer;
        m_last_three_syllable_last_single_strength: Integer;
        m_last_three_syllable_head_path_bonus: Integer;
        m_last_three_syllable_tail_path_bonus: Integer;
        m_last_three_syllable_partial_debug_info: string;
        m_last_full_path_debug_info: string;
        m_last_lookup_debug_extra: string;
        m_last_lookup_timing_info: string;
        m_last_ranked_query_key: string;
        m_last_ranked_top_path: string;
        m_runtime_chain_text: string;
        m_runtime_common_pattern_text: string;
        m_runtime_redup_text: string;
        m_single_quote_open: Boolean;
        m_double_quote_open: Boolean;
        m_page_index: Integer;
        m_selected_index: Integer;
        m_confirmed_text: string;
        m_recent_partial_prefix_text: string;
        m_confirmed_segments: TList<TncConfirmedSegment>;
        function is_alpha_key(const key_code: Word; const key_state: TncKeyState; out normalized_char: Char;
            out display_char: Char): Boolean;
        function get_candidate_limit: Integer;
        function get_total_candidate_limit: Integer;
        function create_dictionary_from_config: TncDictionaryProvider;
        function take_cached_dictionary_provider(const variant: TncDictionaryVariant;
            const base_path: string; const user_path: string): TncDictionaryProvider;
        procedure store_current_dictionary_provider(const previous_config: TncEngineConfig);
        procedure clear_cached_dictionary_providers;
        procedure free_dictionary_provider(var provider: TncDictionaryProvider);
        function get_active_dictionary_path: string;
        function get_dictionary_write_time(const path: string): TDateTime;
        function get_page_count_internal(const page_size: Integer): Integer;
        procedure normalize_page_and_selection;
        function get_source_rank(const source: TncCandidateSource): Integer;
        function get_context_variants(const context_text: string): TArray<string>;
        function get_session_text_bonus(const candidate_text: string): Integer;
        function build_session_query_choice_key(const query_key: string; const candidate_text: string): string;
        function build_session_query_path_choice_key(const query_key: string; const encoded_path: string): string;
        function build_context_query_scope_key(const context_text: string; const query_key: string): string;
        function build_context_query_choice_key(const context_text: string; const query_key: string;
            const candidate_text: string): string;
        function get_session_query_bonus(const candidate_text: string): Integer;
        function get_session_query_path_bonus(const query_key: string; const encoded_path: string): Integer;
        function get_session_query_path_penalty(const query_key: string; const encoded_path: string): Integer;
        function get_session_query_path_prefix_bonus(const query_key: string; const encoded_path: string): Integer;
        function get_session_query_path_prefix_penalty(const query_key: string; const encoded_path: string): Integer;
        function get_session_ranked_query_path_bonus(const encoded_path: string): Integer;
        function get_persistent_query_path_prefix_support(const encoded_path: string): Integer;
        function get_context_query_bonus(const candidate_text: string): Integer;
        function get_context_query_latest_bonus(const candidate_text: string): Integer;
        function is_latest_session_query_choice(const candidate_text: string): Boolean;
        function get_phrase_context_bonus(const candidate_text: string): Integer;
        function get_text_context_bonus(const candidate_text: string): Integer;
        function get_context_bonus(const candidate_text: string): Integer;
        function get_segment_path_preference_score(const encoded_path: string): Integer;
        function get_incremental_path_stability_bonus_for_path(const encoded_path: string): Integer;
        function get_incremental_path_stability_bonus(const candidate: TncCandidate): Integer;
        function get_segment_path_support_score(const candidate: TncCandidate): Integer;
        procedure get_recent_path_context_seed(out prev_prev_text: string; out prev_text: string);
        function get_segment_path_context_bonus(const candidate: TncCandidate): Integer;
        function get_candidate_debug_summary(const candidate: TncCandidate): string;
        function get_punctuation_char(const key_code: Word; const key_state: TncKeyState; out out_char: Char): Boolean;
        function get_effective_punctuation_full_width: Boolean;
        function map_full_width_char(const input_char: Char): string;
        function map_punctuation_char(const input_char: Char): string;
        function get_direct_ascii_commit_text(const key_code: Word; const key_state: TncKeyState;
            out out_text: string): Boolean;
        function get_raw_composition_commit_text: string;
        function get_candidate_text_unit_count(const text: string): Integer;
        function is_runtime_chain_candidate(const candidate: TncCandidate): Boolean;
        function is_runtime_common_pattern_candidate(const candidate: TncCandidate): Boolean;
        function is_runtime_redup_candidate(const candidate: TncCandidate): Boolean;
        function get_runtime_candidate_kind(const candidate: TncCandidate): string;
        function get_candidate_path_confidence_score(const candidate: TncCandidate): Integer;
        function get_candidate_path_confidence_tier(const candidate: TncCandidate): Integer;
        function get_candidate_confidence_rank(const candidate: TncCandidate): Integer;
        function get_front_row_confidence_bonus(const candidate: TncCandidate): Integer;
        function get_multi_syllable_intent_layer(const candidate: TncCandidate): Integer;
        function get_candidate_segment_path_score_hint(const candidate: TncCandidate): Integer;
        function match_single_char_candidate_for_syllable(const syllable_text: string;
            const unit_text: string; out out_preferred: Boolean): Boolean;
        function is_weak_single_char_chain_candidate_for_query(const query_key: string;
            const candidate: TncCandidate): Boolean;
        function is_problematic_single_char_chain_candidate_for_query(const query_key: string;
            const candidate: TncCandidate): Boolean;
        function has_competing_exact_phrase_candidate(const selected_text: string): Boolean;
        function is_runtime_constructed_phrase_friendly(const text: string): Boolean;
        function get_rank_score(const candidate: TncCandidate): Integer;
        procedure sort_candidates(var candidates: TncCandidateList);
        procedure clear_lookup_bonus_caches;
        function build_candidate_identity_key(const candidate_text: string; const comment_text: string): string;
        procedure clear_segment_path_tracking;
        procedure remember_segment_path_for_candidate(const candidate_text: string; const comment_text: string;
            const encoded_path: string; const path_score_hint: Integer = Low(Integer));
        procedure remember_segment_path_score_hint_for_candidate(const candidate_text: string;
            const comment_text: string; const path_score_hint: Integer);
        procedure remember_segment_path_query_prefix(const encoded_path: string; const query_prefix: string);
        function get_query_prefix_for_segment_path(const encoded_path: string): string;
        function get_segment_path_for_candidate(const candidate: TncCandidate;
            const candidate_index: Integer = -1): string;
        function infer_segment_path_for_selected_text(const selected_text: string): string;
        procedure refresh_candidate_segment_paths;
        procedure note_ranked_top_candidate;
        function normalize_pinyin_text(const input_text: string): string;
        function is_valid_pinyin_syllable(const syllable: string): Boolean;
        function is_full_pinyin_key(const value: string): Boolean;
        function get_effective_compact_pinyin_syllables(const input_text: string;
            const allow_relaxed_split: Boolean = False): TncPinyinParseResult;
        function get_effective_compact_pinyin_unit_count(const input_text: string;
            const allow_relaxed_split: Boolean = False): Integer;
        function normalize_adjacent_swap_typo(const value: string): string;
        function split_text_units(const input_text: string): TArray<string>;
        function is_common_surname_text(const value: string): Boolean;
        function merge_candidate_lists(const primary_candidates: TncCandidateList;
            const secondary_candidates: TncCandidateList; const max_candidates: Integer): TncCandidateList;
        procedure build_candidates;
        function build_segment_candidates(out out_candidates: TncCandidateList;
            const include_full_path: Boolean; out out_path_search_elapsed_ms: Int64;
            const allow_relaxed_missing_apostrophe: Boolean = False): Boolean;
        function build_pinyin_comment(const input_text: string;
            const allow_relaxed_missing_apostrophe: Boolean = False): string;
        procedure update_segment_left_context;
        procedure push_confirmed_segment(const text: string; const pinyin: string);
        function pop_confirmed_segment(out out_segment: TncConfirmedSegment): Boolean;
        procedure rebuild_confirmed_text;
        function rollback_last_segment: Boolean;
        procedure apply_partial_commit(const selected_text: string; const remaining_pinyin: string;
            const segment_path: string = '');
        procedure update_left_context(const committed_text: string);
        procedure record_context_pair(const left_text: string; const committed_text: string);
        procedure note_session_commit(const text: string);
        procedure note_session_query_choice(const query_key: string; const text: string);
        procedure note_session_query_path_choice(const query_key: string; const encoded_path: string);
        procedure note_session_query_path_penalty(const query_key: string; const encoded_path: string);
        procedure note_session_ranked_query_path(const query_key: string; const encoded_path: string;
            const path_confidence_score: Integer);
        procedure note_session_context_query_choice(const context_text: string; const query_key: string;
            const text: string);
        procedure track_phrase_context_key(const phrase_key: string; const current_serial: Int64);
        procedure note_output_phrase_context(const committed_text: string);
        procedure note_segment_path_context(const encoded_path: string);
        procedure set_pending_commit(const text: string; const remaining_pinyin: string = '';
            const allow_learning: Boolean = True; const segment_path: string = '');
        procedure clear_pending_commit;
        procedure update_dictionary_state;
        procedure toggle_input_mode;
    public
        constructor create(const config: TncEngineConfig);
        destructor Destroy; override;
        procedure reset;
        procedure update_config(const config: TncEngineConfig);
        procedure set_dictionary_provider(const dictionary: TncDictionaryProvider);
        procedure reload_dictionary_if_needed;
        procedure prewarm_dictionary_caches;
        procedure set_external_left_context(const left_context: string);
        function process_key(const key_code: Word; const key_state: TncKeyState): Boolean;
        function get_candidates: TncCandidateList;
        function get_page_index: Integer;
        function get_page_count: Integer;
        function get_selected_index: Integer;
        function next_page: Boolean;
        function prev_page: Boolean;
        function get_composition_text: string;
        function get_display_text: string;
        function get_confirmed_length: Integer;
        function get_lookup_perf_info: string;
        function get_lookup_debug_info: string;
        function get_debug_last_output_commit_text: string;
        function get_debug_phrase_context_pair_count(const left_text: string; const candidate_text: string): Integer;
        function get_debug_last_commit_segment_path: string;
        function get_debug_candidate_segment_path(const candidate_index: Integer): string;
        function get_debug_pending_commit_segment_path: string;
        function get_dictionary_debug_info: string;
        function should_handle_key(const key_code: Word; const key_state: TncKeyState): Boolean;
        function commit_text(out out_text: string): Boolean;
        function remove_user_candidate(const pinyin: string; const text: string): Boolean;
        property config: TncEngineConfig read m_config write update_config;
    end;

implementation

const
    c_suppress_nonlexicon_complete_long_candidates = True;

type
    TncSegmentPathState = record
        text: string;
        score: Integer;
        path_preference_score: Integer;
        path_confidence_score: Integer;
        source: TncCandidateSource;
        has_multi_segment: Boolean;
        prev_text: string;
        prev_pinyin_text: string;
        prev_prev_text: string;
        path_text: string;
    end;

const
    c_default_page_size = 9;
    c_default_total_limit = 30;
    c_candidate_total_expand_factor = 16;
    c_candidate_total_limit_max = 256;
    c_user_score_bonus = 1000;
    c_partial_candidate_score_penalty = 260;
    c_left_context_max_len = 20;
    c_context_history_limit = 200;
    c_phrase_context_history_limit = 256;
    c_segment_path_separator = #3;
    c_context_score_bonus = 80;
    c_context_score_bonus_max = 400;
    c_session_text_history_limit = 256;
    c_session_query_history_limit = 320;
    c_session_query_path_history_limit = 384;
    c_session_ranked_query_path_history_limit = 192;
    c_session_context_query_history_limit = 384;
    c_long_sentence_full_path_min_syllables = 5;
    c_long_sentence_head_only_bypass_min_syllables = 8;
    c_full_width_offset = $FEE0;
    c_segment_surname_bonus = 110;
    c_session_query_path_separator = #4;

function get_encoded_path_segment_count_local(const encoded_path: string): Integer;
var
    idx: Integer;
    trimmed_path: string;
begin
    trimmed_path := Trim(encoded_path);
    if trimmed_path = '' then
    begin
        Exit(0);
    end;

    Result := 1;
    for idx := 1 to Length(trimmed_path) do
    begin
        if trimmed_path[idx] = c_segment_path_separator then
        begin
            Inc(Result);
        end;
    end;
end;

constructor TncInMemoryDictionary.create;
begin
    inherited create;
    m_map := TDictionary<string, TArray<string>>.Create;

    add_entry('ni', ['ni']);
    add_entry('hao', ['hao']);
    add_entry('nihao', ['ni_hao']);
end;

destructor TncInMemoryDictionary.Destroy;
begin
    m_map.Free;
    inherited Destroy;
end;

procedure TncInMemoryDictionary.add_entry(const pinyin: string; const items: array of string);
var
    values: TArray<string>;
    i: Integer;
begin
    SetLength(values, Length(items));
    for i := 0 to High(items) do
    begin
        values[i] := items[i];
    end;

    m_map.AddOrSetValue(pinyin, values);
end;

function TncInMemoryDictionary.lookup(const pinyin: string; out results: TncCandidateList): Boolean;
var
    values: TArray<string>;
    i: Integer;
    score_base: Integer;
begin
    SetLength(results, 0);
    Result := m_map.TryGetValue(pinyin, values);
    if not Result then
    begin
        Exit(False);
    end;

    SetLength(results, Length(values));
    score_base := Length(values);
    for i := 0 to High(values) do
    begin
        results[i].text := values[i];
        results[i].comment := '';
        results[i].score := score_base - i;
        results[i].source := cs_rule;
        results[i].has_dict_weight := True;
        results[i].dict_weight := results[i].score;
    end;
end;

constructor TncEngine.create(const config: TncEngineConfig);
begin
    inherited create;
    m_config := config;
    m_composition_text := '';
    m_composition_display_text := '';
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_pending_commit_query_key := '';
    m_last_lookup_key := '';
    m_last_lookup_normalized_from := '';
    m_last_lookup_syllable_count := 0;
    m_last_three_syllable_partial_preference_kind := 0;
    m_last_three_syllable_head_exact_text := '';
    m_last_three_syllable_head_strength := 0;
    m_last_three_syllable_tail_strength := 0;
    m_last_three_syllable_first_single_strength := 0;
    m_last_three_syllable_last_single_strength := 0;
    m_last_three_syllable_head_path_bonus := 0;
    m_last_three_syllable_tail_path_bonus := 0;
    m_last_three_syllable_partial_debug_info := '';
    m_last_full_path_debug_info := '';
    m_last_lookup_debug_extra := '';
    m_last_lookup_timing_info := '';
    m_last_ranked_query_key := '';
    m_last_ranked_top_path := '';
    m_runtime_chain_text := '';
    m_runtime_common_pattern_text := '';
    m_runtime_redup_text := '';
    m_single_quote_open := False;
    m_double_quote_open := False;
    m_page_index := 0;
    m_selected_index := 0;
    m_confirmed_text := '';
    m_recent_partial_prefix_text := '';
    m_dictionary := nil;
    m_cached_dictionary_simplified := nil;
    m_cached_dictionary_traditional := nil;
    m_dictionary_path := '';
    m_dictionary_write_time := 0;
    m_user_dictionary_path := '';
    m_user_dictionary_write_time := 0;
    m_last_dictionary_reload_check_tick := 0;
    m_left_context := '';
    m_segment_left_context := '';
    m_confirmed_segments := TList<TncConfirmedSegment>.Create;
    m_context_pairs := TDictionary<string, Integer>.Create;
    m_context_order := TQueue<string>.Create;
    m_phrase_context_pairs := TDictionary<string, Integer>.Create;
    m_phrase_context_order := TQueue<string>.Create;
    m_phrase_context_last_seen := TDictionary<string, Int64>.Create;
    m_session_text_counts := TDictionary<string, Integer>.Create;
    m_session_text_last_seen := TDictionary<string, Int64>.Create;
    m_session_text_order := TQueue<string>.Create;
    m_session_query_choice_counts := TDictionary<string, Integer>.Create;
    m_session_query_choice_last_seen := TDictionary<string, Int64>.Create;
    m_session_query_choice_order := TQueue<string>.Create;
    m_session_query_latest_text := TDictionary<string, string>.Create;
    m_session_query_path_choice_counts := TDictionary<string, Integer>.Create;
    m_session_query_path_choice_last_seen := TDictionary<string, Int64>.Create;
    m_session_query_path_choice_order := TQueue<string>.Create;
    m_session_query_path_penalty_counts := TDictionary<string, Integer>.Create;
    m_session_query_path_penalty_last_seen := TDictionary<string, Int64>.Create;
    m_session_query_path_penalty_order := TQueue<string>.Create;
    m_session_ranked_query_paths := TDictionary<string, string>.Create;
    m_session_ranked_query_path_scores := TDictionary<string, Integer>.Create;
    m_session_ranked_query_path_order := TQueue<string>.Create;
    m_session_context_query_choice_counts := TDictionary<string, Integer>.Create;
    m_session_context_query_choice_last_seen := TDictionary<string, Int64>.Create;
    m_session_context_query_choice_order := TQueue<string>.Create;
    m_session_context_query_latest_text := TDictionary<string, string>.Create;
    m_session_commit_serial := 0;
    m_last_output_commit_text := '';
    m_prev_output_commit_text := '';
    m_context_db_bonus_cache_key := '';
    m_context_db_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_text_unit_count_cache := TDictionary<string, Integer>.Create;
    m_lookup_session_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_query_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_query_latest_text_cache := TDictionary<string, string>.Create;
    m_lookup_query_path_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_context_query_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_context_query_latest_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_phrase_context_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_text_context_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_context_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_segment_path_context_bonus_cache := TDictionary<string, Integer>.Create;
    m_lookup_segment_path_preference_cache := TDictionary<string, Integer>.Create;
    m_lookup_candidate_path_confidence_cache := TDictionary<string, Integer>.Create;
    m_current_segment_path_map := TDictionary<string, string>.Create;
    m_current_segment_path_score_map := TDictionary<string, Integer>.Create;
    m_current_segment_path_query_prefix_map := TDictionary<string, string>.Create;
    SetLength(m_candidate_segment_paths, 0);
    m_pending_commit_segment_path := '';
    m_pending_commit_query_key := '';
    SetLength(m_candidates, 0);
    set_dictionary_provider(create_dictionary_from_config);
end;

destructor TncEngine.Destroy;
begin
    if m_dictionary <> nil then
    begin
        m_dictionary.Free;
        m_dictionary := nil;
    end;
    clear_cached_dictionary_providers;

    if m_context_order <> nil then
    begin
        m_context_order.Free;
        m_context_order := nil;
    end;

    if m_phrase_context_order <> nil then
    begin
        m_phrase_context_order.Free;
        m_phrase_context_order := nil;
    end;

    if m_phrase_context_last_seen <> nil then
    begin
        m_phrase_context_last_seen.Free;
        m_phrase_context_last_seen := nil;
    end;

    if m_session_text_order <> nil then
    begin
        m_session_text_order.Free;
        m_session_text_order := nil;
    end;
    if m_session_query_choice_order <> nil then
    begin
        m_session_query_choice_order.Free;
        m_session_query_choice_order := nil;
    end;
    if m_session_query_path_choice_order <> nil then
    begin
        m_session_query_path_choice_order.Free;
        m_session_query_path_choice_order := nil;
    end;
    if m_session_query_path_penalty_order <> nil then
    begin
        m_session_query_path_penalty_order.Free;
        m_session_query_path_penalty_order := nil;
    end;
    if m_session_ranked_query_path_order <> nil then
    begin
        m_session_ranked_query_path_order.Free;
        m_session_ranked_query_path_order := nil;
    end;

    if m_session_text_last_seen <> nil then
    begin
        m_session_text_last_seen.Free;
        m_session_text_last_seen := nil;
    end;
    if m_session_query_choice_last_seen <> nil then
    begin
        m_session_query_choice_last_seen.Free;
        m_session_query_choice_last_seen := nil;
    end;
    if m_session_query_latest_text <> nil then
    begin
        m_session_query_latest_text.Free;
        m_session_query_latest_text := nil;
    end;
    if m_session_query_path_choice_last_seen <> nil then
    begin
        m_session_query_path_choice_last_seen.Free;
        m_session_query_path_choice_last_seen := nil;
    end;
    if m_session_query_path_penalty_last_seen <> nil then
    begin
        m_session_query_path_penalty_last_seen.Free;
        m_session_query_path_penalty_last_seen := nil;
    end;
    if m_session_ranked_query_path_scores <> nil then
    begin
        m_session_ranked_query_path_scores.Free;
        m_session_ranked_query_path_scores := nil;
    end;
    if m_session_ranked_query_paths <> nil then
    begin
        m_session_ranked_query_paths.Free;
        m_session_ranked_query_paths := nil;
    end;
    if m_session_context_query_choice_order <> nil then
    begin
        m_session_context_query_choice_order.Free;
        m_session_context_query_choice_order := nil;
    end;
    if m_session_context_query_latest_text <> nil then
    begin
        m_session_context_query_latest_text.Free;
        m_session_context_query_latest_text := nil;
    end;
    if m_session_context_query_choice_last_seen <> nil then
    begin
        m_session_context_query_choice_last_seen.Free;
        m_session_context_query_choice_last_seen := nil;
    end;
    if m_session_context_query_choice_counts <> nil then
    begin
        m_session_context_query_choice_counts.Free;
        m_session_context_query_choice_counts := nil;
    end;

    if m_context_db_bonus_cache <> nil then
    begin
        m_context_db_bonus_cache.Free;
        m_context_db_bonus_cache := nil;
    end;
    m_context_db_bonus_cache_key := '';

    if m_lookup_text_unit_count_cache <> nil then
    begin
        m_lookup_text_unit_count_cache.Free;
        m_lookup_text_unit_count_cache := nil;
    end;
    if m_lookup_session_bonus_cache <> nil then
    begin
        m_lookup_session_bonus_cache.Free;
        m_lookup_session_bonus_cache := nil;
    end;
    if m_lookup_query_bonus_cache <> nil then
    begin
        m_lookup_query_bonus_cache.Free;
        m_lookup_query_bonus_cache := nil;
    end;
    if m_lookup_query_latest_text_cache <> nil then
    begin
        m_lookup_query_latest_text_cache.Free;
        m_lookup_query_latest_text_cache := nil;
    end;
    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.Free;
        m_lookup_query_path_bonus_cache := nil;
    end;
    if m_lookup_context_query_bonus_cache <> nil then
    begin
        m_lookup_context_query_bonus_cache.Free;
        m_lookup_context_query_bonus_cache := nil;
    end;
    if m_lookup_context_query_latest_bonus_cache <> nil then
    begin
        m_lookup_context_query_latest_bonus_cache.Free;
        m_lookup_context_query_latest_bonus_cache := nil;
    end;
    if m_lookup_phrase_context_bonus_cache <> nil then
    begin
        m_lookup_phrase_context_bonus_cache.Free;
        m_lookup_phrase_context_bonus_cache := nil;
    end;
    if m_lookup_text_context_bonus_cache <> nil then
    begin
        m_lookup_text_context_bonus_cache.Free;
        m_lookup_text_context_bonus_cache := nil;
    end;
    if m_lookup_context_bonus_cache <> nil then
    begin
        m_lookup_context_bonus_cache.Free;
        m_lookup_context_bonus_cache := nil;
    end;
    if m_lookup_segment_path_context_bonus_cache <> nil then
    begin
        m_lookup_segment_path_context_bonus_cache.Free;
        m_lookup_segment_path_context_bonus_cache := nil;
    end;
    if m_lookup_segment_path_preference_cache <> nil then
    begin
        m_lookup_segment_path_preference_cache.Free;
        m_lookup_segment_path_preference_cache := nil;
    end;
    if m_lookup_candidate_path_confidence_cache <> nil then
    begin
        m_lookup_candidate_path_confidence_cache.Free;
        m_lookup_candidate_path_confidence_cache := nil;
    end;
    if m_current_segment_path_map <> nil then
    begin
        m_current_segment_path_map.Free;
        m_current_segment_path_map := nil;
    end;
    if m_current_segment_path_score_map <> nil then
    begin
        m_current_segment_path_score_map.Free;
        m_current_segment_path_score_map := nil;
    end;
    if m_current_segment_path_query_prefix_map <> nil then
    begin
        m_current_segment_path_query_prefix_map.Free;
        m_current_segment_path_query_prefix_map := nil;
    end;
    SetLength(m_candidate_segment_paths, 0);

    if m_confirmed_segments <> nil then
    begin
        m_confirmed_segments.Free;
        m_confirmed_segments := nil;
    end;

    if m_context_pairs <> nil then
    begin
        m_context_pairs.Free;
        m_context_pairs := nil;
    end;

    if m_phrase_context_pairs <> nil then
    begin
        m_phrase_context_pairs.Free;
        m_phrase_context_pairs := nil;
    end;

    if m_session_text_counts <> nil then
    begin
        m_session_text_counts.Free;
        m_session_text_counts := nil;
    end;
    if m_session_query_choice_counts <> nil then
    begin
        m_session_query_choice_counts.Free;
        m_session_query_choice_counts := nil;
    end;
    if m_session_query_path_choice_counts <> nil then
    begin
        m_session_query_path_choice_counts.Free;
        m_session_query_path_choice_counts := nil;
    end;
    if m_session_query_path_penalty_counts <> nil then
    begin
        m_session_query_path_penalty_counts.Free;
        m_session_query_path_penalty_counts := nil;
    end;

    inherited Destroy;
end;

procedure TncEngine.clear_lookup_bonus_caches;
begin
    if m_lookup_text_unit_count_cache <> nil then
    begin
        m_lookup_text_unit_count_cache.Clear;
    end;
    if m_lookup_session_bonus_cache <> nil then
    begin
        m_lookup_session_bonus_cache.Clear;
    end;
    if m_lookup_query_bonus_cache <> nil then
    begin
        m_lookup_query_bonus_cache.Clear;
    end;
    if m_lookup_query_latest_text_cache <> nil then
    begin
        m_lookup_query_latest_text_cache.Clear;
    end;
    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.Clear;
    end;
    if m_lookup_context_query_bonus_cache <> nil then
    begin
        m_lookup_context_query_bonus_cache.Clear;
    end;
    if m_lookup_context_query_latest_bonus_cache <> nil then
    begin
        m_lookup_context_query_latest_bonus_cache.Clear;
    end;
    if m_lookup_phrase_context_bonus_cache <> nil then
    begin
        m_lookup_phrase_context_bonus_cache.Clear;
    end;
    if m_lookup_text_context_bonus_cache <> nil then
    begin
        m_lookup_text_context_bonus_cache.Clear;
    end;
    if m_lookup_context_bonus_cache <> nil then
    begin
        m_lookup_context_bonus_cache.Clear;
    end;
    if m_lookup_segment_path_context_bonus_cache <> nil then
    begin
        m_lookup_segment_path_context_bonus_cache.Clear;
    end;
    if m_lookup_segment_path_preference_cache <> nil then
    begin
        m_lookup_segment_path_preference_cache.Clear;
    end;
    if m_lookup_candidate_path_confidence_cache <> nil then
    begin
        m_lookup_candidate_path_confidence_cache.Clear;
    end;
end;

function TncEngine.build_candidate_identity_key(const candidate_text: string; const comment_text: string): string;
begin
    Result := LowerCase(Trim(candidate_text)) + #1 + Trim(comment_text);
end;

procedure TncEngine.clear_segment_path_tracking;
begin
    m_pending_commit_segment_path := '';
    m_pending_commit_query_key := '';
    SetLength(m_candidate_segment_paths, 0);
    if m_current_segment_path_map <> nil then
    begin
        m_current_segment_path_map.Clear;
    end;
    if m_current_segment_path_score_map <> nil then
    begin
        m_current_segment_path_score_map.Clear;
    end;
    if m_current_segment_path_query_prefix_map <> nil then
    begin
        m_current_segment_path_query_prefix_map.Clear;
    end;
end;

procedure TncEngine.remember_segment_path_for_candidate(const candidate_text: string; const comment_text: string;
    const encoded_path: string; const path_score_hint: Integer = Low(Integer));
var
    key: string;
    existing_path: string;
    existing_preference: Integer;
    existing_score_hint: Integer;
    new_preference: Integer;
begin
    if (encoded_path = '') or (m_current_segment_path_map = nil) then
    begin
        Exit;
    end;

    key := build_candidate_identity_key(candidate_text, comment_text);
    if key = '' then
    begin
        Exit;
    end;

    if m_current_segment_path_map.TryGetValue(key, existing_path) then
    begin
        remember_segment_path_score_hint_for_candidate(candidate_text, comment_text, path_score_hint);

        // The same visible candidate text can be reached through multiple segment paths.
        // Keep the path with fewer segments so phrase-context learning records the more
        // natural chunk boundary (e.g. "有点|奇怪" instead of "有|点|奇怪").
        existing_preference := get_segment_path_preference_score(existing_path) +
            get_incremental_path_stability_bonus_for_path(existing_path);
        new_preference := get_segment_path_preference_score(encoded_path) +
            get_incremental_path_stability_bonus_for_path(encoded_path);
        if (new_preference > existing_preference + 24) or
            ((Abs(new_preference - existing_preference) <= 24) and
            (path_score_hint > Low(Integer)) and
            (m_current_segment_path_score_map <> nil) and
            m_current_segment_path_score_map.TryGetValue(key, existing_score_hint) and
            (path_score_hint > existing_score_hint + 48)) or
            ((new_preference = existing_preference) and
            (get_encoded_path_segment_count_local(encoded_path) < get_encoded_path_segment_count_local(existing_path))) or
            ((new_preference = existing_preference) and
            (get_encoded_path_segment_count_local(encoded_path) = get_encoded_path_segment_count_local(existing_path)) and
            (Length(encoded_path) < Length(existing_path))) then
        begin
            m_current_segment_path_map.AddOrSetValue(key, encoded_path);
            remember_segment_path_score_hint_for_candidate(candidate_text, comment_text, path_score_hint);
        end;
        Exit;
    end;

    m_current_segment_path_map.Add(key, encoded_path);
    remember_segment_path_score_hint_for_candidate(candidate_text, comment_text, path_score_hint);
end;

procedure TncEngine.remember_segment_path_score_hint_for_candidate(const candidate_text: string;
    const comment_text: string; const path_score_hint: Integer);
var
    existing_score_hint: Integer;
    key: string;
begin
    if (m_current_segment_path_score_map = nil) or (path_score_hint <= Low(Integer)) then
    begin
        Exit;
    end;

    key := build_candidate_identity_key(candidate_text, comment_text);
    if key = '' then
    begin
        Exit;
    end;

    if (not m_current_segment_path_score_map.TryGetValue(key, existing_score_hint)) or
        (path_score_hint > existing_score_hint) then
    begin
        m_current_segment_path_score_map.AddOrSetValue(key, path_score_hint);
    end;
end;

procedure TncEngine.remember_segment_path_query_prefix(const encoded_path: string; const query_prefix: string);
var
    normalized_path: string;
    normalized_query: string;
    existing_query: string;
begin
    normalized_path := Trim(encoded_path);
    normalized_query := normalize_pinyin_text(query_prefix);
    if (normalized_path = '') or (normalized_query = '') or
        (get_encoded_path_segment_count_local(normalized_path) <= 1) or
        (m_current_segment_path_query_prefix_map = nil) then
    begin
        Exit;
    end;

    if m_current_segment_path_query_prefix_map.TryGetValue(normalized_path, existing_query) then
    begin
        if (existing_query = '') or (Length(normalized_query) > Length(existing_query)) then
        begin
            m_current_segment_path_query_prefix_map.AddOrSetValue(normalized_path, normalized_query);
        end;
        Exit;
    end;

    m_current_segment_path_query_prefix_map.Add(normalized_path, normalized_query);
end;

function TncEngine.get_query_prefix_for_segment_path(const encoded_path: string): string;
var
    normalized_path: string;
begin
    Result := '';
    normalized_path := Trim(encoded_path);
    if (normalized_path = '') or (m_current_segment_path_query_prefix_map = nil) then
    begin
        Exit;
    end;

    if not m_current_segment_path_query_prefix_map.TryGetValue(normalized_path, Result) then
    begin
        Result := '';
    end;
end;

function TncEngine.get_segment_path_for_candidate(const candidate: TncCandidate;
    const candidate_index: Integer = -1): string;
var
    key: string;
begin
    Result := '';
    if (candidate_index >= 0) and (candidate_index < Length(m_candidate_segment_paths)) then
    begin
        Result := m_candidate_segment_paths[candidate_index];
        if Result <> '' then
        begin
            Exit;
        end;
    end;

    if m_current_segment_path_map = nil then
    begin
        Exit;
    end;

    key := build_candidate_identity_key(candidate.text, candidate.comment);
    if (key = '') or (not m_current_segment_path_map.TryGetValue(key, Result)) then
    begin
        Result := '';
    end;
end;

function TncEngine.infer_segment_path_for_selected_text(const selected_text: string): string;
type
    TncInferredPathState = record
        valid: Boolean;
        score: Integer;
        segment_count: Integer;
        path_text: string;
    end;
const
    c_infer_segment_max_syllables = 24;
    c_infer_segment_word_max_syllables = 4;
var
    syllables: TncPinyinParseResult;
    target_units: TArray<string>;
    lookup_cache: TDictionary<string, TncCandidateList>;
    memo: TDictionary<string, TncInferredPathState>;
    function build_syllable_key(const start_index: Integer; const syllable_count: Integer): string;
    var
        idx: Integer;
        end_index: Integer;
    begin
        Result := '';
        if (syllable_count <= 0) or (start_index < 0) or (start_index > High(syllables)) then
        begin
            Exit;
        end;

        end_index := start_index + syllable_count - 1;
        if end_index > High(syllables) then
        begin
            end_index := High(syllables);
        end;

        for idx := start_index to end_index do
        begin
            Result := Result + syllables[idx].text;
        end;
    end;

    function lookup_cached(const pinyin_key: string; out out_results: TncCandidateList): Boolean;
    begin
        SetLength(out_results, 0);
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit(False);
        end;

        if lookup_cache.TryGetValue(pinyin_key, out_results) then
        begin
            Exit(Length(out_results) > 0);
        end;

        if not m_dictionary.lookup(pinyin_key, out_results) then
        begin
            SetLength(out_results, 0);
        end;
        lookup_cache.AddOrSetValue(pinyin_key, out_results);
        Result := Length(out_results) > 0;
    end;

    function is_better_state(const candidate_state: TncInferredPathState;
        const current_state: TncInferredPathState): Boolean;
    var
        candidate_multi: Boolean;
        current_multi: Boolean;
    begin
        if not candidate_state.valid then
        begin
            Exit(False);
        end;
        if not current_state.valid then
        begin
            Exit(True);
        end;

        candidate_multi := candidate_state.segment_count > 1;
        current_multi := current_state.segment_count > 1;
        if candidate_multi <> current_multi then
        begin
            Exit(candidate_multi);
        end;

        if candidate_state.segment_count <> current_state.segment_count then
        begin
            Exit(candidate_state.segment_count < current_state.segment_count);
        end;

        if candidate_state.score <> current_state.score then
        begin
            Exit(candidate_state.score > current_state.score);
        end;

        Result := Length(candidate_state.path_text) < Length(current_state.path_text);
    end;

    function matches_target_units(const candidate_text: string; const unit_index: Integer;
        out matched_units: Integer): Boolean;
    var
        candidate_units: TArray<string>;
        idx: Integer;
    begin
        Result := False;
        matched_units := 0;
        if candidate_text = '' then
        begin
            Exit;
        end;

        candidate_units := split_text_units(candidate_text);
        matched_units := Length(candidate_units);
        if (matched_units <= 0) or (unit_index + matched_units > Length(target_units)) then
        begin
            matched_units := 0;
            Exit;
        end;

        for idx := 0 to matched_units - 1 do
        begin
            if candidate_units[idx] <> target_units[unit_index + idx] then
            begin
                matched_units := 0;
                Exit(False);
            end;
        end;

        Result := True;
    end;

    function solve(const syllable_index: Integer; const unit_index: Integer): TncInferredPathState;
    var
        cache_key: string;
        segment_len: Integer;
        next_syllable_index: Integer;
        pinyin_key: string;
        lookup_results: TncCandidateList;
        candidate_index: Integer;
        candidate: TncCandidate;
        matched_units: Integer;
        tail_state: TncInferredPathState;
        candidate_state: TncInferredPathState;
    begin
        Result.valid := False;
        Result.score := 0;
        Result.segment_count := 0;
        Result.path_text := '';

        if (syllable_index = Length(syllables)) and (unit_index = Length(target_units)) then
        begin
            Result.valid := True;
            Exit;
        end;

        if (syllable_index >= Length(syllables)) or (unit_index >= Length(target_units)) then
        begin
            Exit;
        end;

        cache_key := IntToStr(syllable_index) + '#' + IntToStr(unit_index);
        if memo.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        for segment_len := 1 to c_infer_segment_word_max_syllables do
        begin
            next_syllable_index := syllable_index + segment_len;
            if next_syllable_index > Length(syllables) then
            begin
                Break;
            end;

            pinyin_key := build_syllable_key(syllable_index, segment_len);
            if not lookup_cached(pinyin_key, lookup_results) then
            begin
                Continue;
            end;

            for candidate_index := 0 to High(lookup_results) do
            begin
                candidate := lookup_results[candidate_index];
                if candidate.comment <> '' then
                begin
                    Continue;
                end;

                if not matches_target_units(candidate.text, unit_index, matched_units) then
                begin
                    Continue;
                end;

                tail_state := solve(next_syllable_index, unit_index + matched_units);
                if not tail_state.valid then
                begin
                    Continue;
                end;

                candidate_state.valid := True;
                candidate_state.score := candidate.score + tail_state.score;
                candidate_state.segment_count := tail_state.segment_count + 1;
                candidate_state.path_text := candidate.text;
                if tail_state.path_text <> '' then
                begin
                    candidate_state.path_text := candidate_state.path_text + c_segment_path_separator +
                        tail_state.path_text;
                end;

                if is_better_state(candidate_state, Result) then
                begin
                    Result := candidate_state;
                end;
            end;
        end;

        memo.AddOrSetValue(cache_key, Result);
    end;
var
    inferred_state: TncInferredPathState;
begin
    Result := '';
    if (m_dictionary = nil) or (selected_text = '') or (m_composition_text = '') then
    begin
        Exit;
    end;

    lookup_cache := TDictionary<string, TncCandidateList>.Create;
    memo := TDictionary<string, TncInferredPathState>.Create;
    try
        syllables := get_effective_compact_pinyin_syllables(m_composition_text);
        if (Length(syllables) <= 1) or (Length(syllables) > c_infer_segment_max_syllables) then
        begin
            Exit;
        end;

        target_units := split_text_units(selected_text);
        if Length(target_units) <= 1 then
        begin
            Exit;
        end;

        inferred_state := solve(0, 0);
        if inferred_state.valid and (inferred_state.segment_count > 1) then
        begin
            Result := inferred_state.path_text;
        end;
    finally
        memo.Free;
        lookup_cache.Free;
    end;
end;

procedure TncEngine.refresh_candidate_segment_paths;
var
    idx: Integer;
    key: string;
begin
    SetLength(m_candidate_segment_paths, Length(m_candidates));
    if (Length(m_candidates) = 0) or (m_current_segment_path_map = nil) or
        (m_current_segment_path_map.Count <= 0) then
    begin
        Exit;
    end;

    for idx := 0 to High(m_candidates) do
    begin
        key := build_candidate_identity_key(m_candidates[idx].text, m_candidates[idx].comment);
        if (key <> '') and m_current_segment_path_map.TryGetValue(key, m_candidate_segment_paths[idx]) then
        begin
            Continue;
        end;
        m_candidate_segment_paths[idx] := '';
    end;
end;

procedure TncEngine.note_ranked_top_candidate;
var
    path_confidence_score: Integer;
    previous_query: string;
    normalized_query: string;
    top_path: string;
begin
    previous_query := normalize_pinyin_text(m_last_ranked_query_key);
    normalized_query := normalize_pinyin_text(m_last_lookup_key);

    if normalized_query = '' then
    begin
        m_last_ranked_query_key := '';
        m_last_ranked_top_path := '';
        Exit;
    end;

    m_last_ranked_query_key := normalized_query;

    if Length(m_candidates) = 0 then
    begin
        if (previous_query = '') or
            (Copy(normalized_query, 1, Length(previous_query)) <> previous_query) then
        begin
            m_last_ranked_top_path := '';
        end;
        Exit;
    end;

    top_path := '';
    if m_candidates[0].comment = '' then
    begin
        top_path := get_segment_path_for_candidate(m_candidates[0], 0);
    end;

    if get_encoded_path_segment_count_local(top_path) <= 1 then
    begin
        if (previous_query = '') or
            (Copy(normalized_query, 1, Length(previous_query)) <> previous_query) then
        begin
            m_last_ranked_top_path := '';
        end;
        Exit;
    end;

    m_last_ranked_top_path := top_path;
    path_confidence_score := get_candidate_path_confidence_score(m_candidates[0]);
    if path_confidence_score >= 180 then
    begin
        note_session_ranked_query_path(normalized_query, top_path, path_confidence_score);
    end;
end;

procedure TncEngine.reset;
begin
    m_composition_text := '';
    m_composition_display_text := '';
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_pending_commit_segment_path := '';
    m_pending_commit_query_key := '';
    m_last_lookup_key := '';
    m_last_lookup_normalized_from := '';
    m_last_lookup_syllable_count := 0;
    m_last_three_syllable_partial_preference_kind := 0;
    m_last_three_syllable_head_exact_text := '';
    m_last_three_syllable_head_strength := 0;
    m_last_three_syllable_tail_strength := 0;
    m_last_three_syllable_first_single_strength := 0;
    m_last_three_syllable_last_single_strength := 0;
    m_last_three_syllable_head_path_bonus := 0;
    m_last_three_syllable_tail_path_bonus := 0;
    m_last_three_syllable_partial_debug_info := '';
    m_last_full_path_debug_info := '';
    m_last_lookup_debug_extra := '';
    m_last_lookup_timing_info := '';
    m_last_ranked_query_key := '';
    m_last_ranked_top_path := '';
    m_runtime_chain_text := '';
    m_runtime_common_pattern_text := '';
    m_runtime_redup_text := '';
    m_page_index := 0;
    m_selected_index := 0;
    m_confirmed_text := '';
    m_recent_partial_prefix_text := '';
    m_external_left_context := '';
    m_segment_left_context := '';
    m_context_db_bonus_cache_key := '';
    SetLength(m_candidates, 0);
    if m_confirmed_segments <> nil then
    begin
        m_confirmed_segments.Clear;
    end;
    if m_context_db_bonus_cache <> nil then
    begin
        m_context_db_bonus_cache.Clear;
    end;
    clear_segment_path_tracking;
    clear_lookup_bonus_caches;
end;

procedure TncEngine.update_config(const config: TncEngineConfig);
var
    previous_config: TncEngineConfig;
    dictionary_changed: Boolean;
begin
    previous_config := m_config;
    dictionary_changed := m_config.dictionary_variant <> config.dictionary_variant;
    m_config := config;
    if m_dictionary <> nil then
    begin
        m_dictionary.set_debug_mode(m_config.debug_mode);
    end;
    if dictionary_changed then
    begin
        store_current_dictionary_provider(previous_config);
        set_dictionary_provider(create_dictionary_from_config);
    end;
end;

procedure TncEngine.set_dictionary_provider(const dictionary: TncDictionaryProvider);
begin
    if m_dictionary = dictionary then
    begin
        Exit;
    end;

    if m_dictionary <> nil then
    begin
        m_dictionary.Free;
    end;

    m_dictionary := dictionary;
    if m_dictionary <> nil then
    begin
        m_dictionary.set_debug_mode(m_config.debug_mode);
    end;
    m_context_db_bonus_cache_key := '';
    if m_context_db_bonus_cache <> nil then
    begin
        m_context_db_bonus_cache.Clear;
    end;
    clear_lookup_bonus_caches;
    m_last_dictionary_reload_check_tick := 0;
    update_dictionary_state;
end;

procedure TncEngine.free_dictionary_provider(var provider: TncDictionaryProvider);
begin
    if provider <> nil then
    begin
        provider.Free;
        provider := nil;
    end;
end;

procedure TncEngine.clear_cached_dictionary_providers;
begin
    free_dictionary_provider(m_cached_dictionary_simplified);
    free_dictionary_provider(m_cached_dictionary_traditional);
end;

function TncEngine.take_cached_dictionary_provider(const variant: TncDictionaryVariant;
    const base_path: string; const user_path: string): TncDictionaryProvider;
var
    cached_provider: TncDictionaryProvider;
    sqlite_dict: TncSqliteDictionary;
begin
    Result := nil;
    if variant = dv_traditional then
    begin
        cached_provider := m_cached_dictionary_traditional;
    end
    else
    begin
        cached_provider := m_cached_dictionary_simplified;
    end;

    if cached_provider = nil then
    begin
        Exit;
    end;

    if not (cached_provider is TncSqliteDictionary) then
    begin
        if variant = dv_traditional then
        begin
            free_dictionary_provider(m_cached_dictionary_traditional);
        end
        else
        begin
            free_dictionary_provider(m_cached_dictionary_simplified);
        end;
        Exit;
    end;

    sqlite_dict := TncSqliteDictionary(cached_provider);
    if SameText(sqlite_dict.db_path, base_path) and SameText(sqlite_dict.user_db_path, user_path) then
    begin
        Result := cached_provider;
        if variant = dv_traditional then
        begin
            m_cached_dictionary_traditional := nil;
        end
        else
        begin
            m_cached_dictionary_simplified := nil;
        end;
        Exit;
    end;

    if variant = dv_traditional then
    begin
        free_dictionary_provider(m_cached_dictionary_traditional);
    end
    else
    begin
        free_dictionary_provider(m_cached_dictionary_simplified);
    end;
end;

procedure TncEngine.store_current_dictionary_provider(const previous_config: TncEngineConfig);
var
    cache_target: ^TncDictionaryProvider;
    sqlite_dict: TncSqliteDictionary;
    expected_base_path: string;
begin
    if m_dictionary = nil then
    begin
        Exit;
    end;

    if previous_config.dictionary_variant = dv_traditional then
    begin
        cache_target := @m_cached_dictionary_traditional;
        expected_base_path := get_default_dictionary_path_traditional;
    end
    else
    begin
        cache_target := @m_cached_dictionary_simplified;
        expected_base_path := get_default_dictionary_path_simplified;
    end;

    if not (m_dictionary is TncSqliteDictionary) then
    begin
        free_dictionary_provider(m_dictionary);
        Exit;
    end;

    sqlite_dict := TncSqliteDictionary(m_dictionary);
    if (not SameText(sqlite_dict.db_path, expected_base_path)) or
        (not SameText(sqlite_dict.user_db_path, get_default_user_dictionary_path)) then
    begin
        free_dictionary_provider(m_dictionary);
        Exit;
    end;

    if cache_target^ <> nil then
    begin
        free_dictionary_provider(cache_target^);
    end;
    cache_target^ := m_dictionary;
    m_dictionary := nil;
end;

function TncEngine.is_alpha_key(const key_code: Word; const key_state: TncKeyState; out normalized_char: Char;
    out display_char: Char): Boolean;
begin
    if (key_code >= Ord('A')) and (key_code <= Ord('Z')) then
    begin
        normalized_char := Char(key_code + Ord('a') - Ord('A'));
        if key_state.shift_down xor key_state.caps_lock then
        begin
            display_char := Char(key_code);
        end
        else
        begin
            display_char := normalized_char;
        end;
        Result := True;
        Exit;
    end;

    Result := False;
end;

function TncEngine.get_candidate_limit: Integer;
begin
    Result := c_default_page_size;
end;

function TncEngine.get_total_candidate_limit: Integer;
begin
    Result := c_default_total_limit;
    if get_candidate_limit > Result then
    begin
        Result := get_candidate_limit;
    end;
end;

function TncEngine.create_dictionary_from_config: TncDictionaryProvider;
var
    sqlite_dict: TncSqliteDictionary;
    base_path: string;
    user_path: string;
begin
    base_path := get_active_dictionary_path;
    user_path := get_default_user_dictionary_path;
    if base_path <> '' then
    begin
        Result := take_cached_dictionary_provider(m_config.dictionary_variant, base_path, user_path);
        if Result <> nil then
        begin
            Result.set_debug_mode(m_config.debug_mode);
            Exit;
        end;

        sqlite_dict := TncSqliteDictionary.create(base_path, user_path);
        if sqlite_dict.open then
        begin
            sqlite_dict.set_debug_mode(m_config.debug_mode);
            Result := sqlite_dict;
            Exit;
        end;

        sqlite_dict.Free;
    end;

    Result := TncInMemoryDictionary.create;
end;

function TncEngine.get_active_dictionary_path: string;
begin
    if m_config.dictionary_variant = dv_traditional then
    begin
        Result := get_default_dictionary_path_traditional;
    end
    else
    begin
        Result := get_default_dictionary_path_simplified;
    end;
end;

function TncEngine.get_dictionary_write_time(const path: string): TDateTime;
begin
    if (path <> '') and FileExists(path) then
    begin
        Result := TFile.GetLastWriteTime(path);
    end
    else
    begin
        Result := 0;
    end;
end;

procedure TncEngine.update_dictionary_state;
var
    base_path: string;
begin
    base_path := get_active_dictionary_path;
    if (m_dictionary is TncSqliteDictionary) and (base_path <> '') then
    begin
        m_dictionary_path := base_path;
        m_dictionary_write_time := get_dictionary_write_time(m_dictionary_path);
        m_user_dictionary_path := get_default_user_dictionary_path;
        m_user_dictionary_write_time := get_dictionary_write_time(m_user_dictionary_path);
    end
    else
    begin
        m_dictionary_path := '';
        m_dictionary_write_time := 0;
        m_user_dictionary_path := '';
        m_user_dictionary_write_time := 0;
    end;
end;

procedure TncEngine.reload_dictionary_if_needed;
const
    c_dictionary_reload_check_interval_ms = 1500;
var
    current_write_time: TDateTime;
    user_write_time: TDateTime;
    now_tick: UInt64;
begin
    if (m_dictionary_path = '') and (m_user_dictionary_path = '') then
    begin
        Exit;
    end;

    now_tick := GetTickCount64;
    if (m_last_dictionary_reload_check_tick <> 0) and
        ((now_tick - m_last_dictionary_reload_check_tick) < c_dictionary_reload_check_interval_ms) then
    begin
        Exit;
    end;
    m_last_dictionary_reload_check_tick := now_tick;

    if m_dictionary_path <> '' then
    begin
        current_write_time := get_dictionary_write_time(m_dictionary_path);
    end
    else
    begin
        current_write_time := 0;
    end;

    if m_user_dictionary_path <> '' then
    begin
        user_write_time := get_dictionary_write_time(m_user_dictionary_path);
    end
    else
    begin
        user_write_time := 0;
    end;

    if (current_write_time <= m_dictionary_write_time) and (user_write_time <= m_user_dictionary_write_time) then
    begin
        Exit;
    end;

    set_dictionary_provider(create_dictionary_from_config);
end;

procedure TncEngine.prewarm_dictionary_caches;
var
    sqlite_dict: TncSqliteDictionary;
    alt_variant: TncDictionaryVariant;
    alt_base_path: string;
    alt_dict: TncSqliteDictionary;
begin
    if not (m_dictionary is TncSqliteDictionary) then
    begin
        Exit;
    end;

    sqlite_dict := TncSqliteDictionary(m_dictionary);
    sqlite_dict.prewarm_short_lookup_caches;

    if m_config.dictionary_variant = dv_traditional then
    begin
        alt_variant := dv_simplified;
        alt_base_path := get_default_dictionary_path_simplified;
        if (m_cached_dictionary_simplified <> nil) or (alt_base_path = '') then
        begin
            Exit;
        end;
    end
    else
    begin
        alt_variant := dv_traditional;
        alt_base_path := get_default_dictionary_path_traditional;
        if (m_cached_dictionary_traditional <> nil) or (alt_base_path = '') then
        begin
            Exit;
        end;
    end;

    alt_dict := TncSqliteDictionary.Create(alt_base_path, get_default_user_dictionary_path);
    if alt_dict.open then
    begin
        alt_dict.set_debug_mode(m_config.debug_mode);
        alt_dict.prewarm_short_lookup_caches;
        if alt_variant = dv_traditional then
        begin
            free_dictionary_provider(m_cached_dictionary_traditional);
            m_cached_dictionary_traditional := alt_dict;
        end
        else
        begin
            free_dictionary_provider(m_cached_dictionary_simplified);
            m_cached_dictionary_simplified := alt_dict;
        end;
    end
    else
    begin
        alt_dict.Free;
    end;
end;

procedure TncEngine.set_external_left_context(const left_context: string);
var
    next_context: string;
begin
    next_context := left_context;
    if Length(next_context) > c_left_context_max_len then
    begin
        next_context := Copy(next_context, Length(next_context) - c_left_context_max_len + 1, c_left_context_max_len);
    end;
    m_external_left_context := next_context;
end;

function is_relaxed_no_initial_syllable_text(const token_text: string): Boolean;
begin
    Result :=
        SameText(token_text, 'ang') or
        SameText(token_text, 'eng') or
        SameText(token_text, 'ai') or
        SameText(token_text, 'an') or
        SameText(token_text, 'ao') or
        SameText(token_text, 'ei') or
        SameText(token_text, 'en') or
        SameText(token_text, 'er') or
        SameText(token_text, 'ou') or
        SameText(token_text, 'a') or
        SameText(token_text, 'e') or
        SameText(token_text, 'o');
end;

function try_split_relaxed_missing_apostrophe_token(const parser: TncPinyinParser; const token_text: string;
    out out_left: string; out out_right: string): Boolean;
var
    split_idx: Integer;
    left_text: string;
    right_text: string;
    left_parts: TncPinyinParseResult;
    right_parts: TncPinyinParseResult;
begin
    Result := False;
    out_left := '';
    out_right := '';
    if (parser = nil) or (token_text = '') or (Length(token_text) < 4) or
        (Pos('''', token_text) > 0) then
    begin
        Exit;
    end;

    for split_idx := 2 to Length(token_text) - 2 do
    begin
        left_text := Copy(token_text, 1, split_idx);
        right_text := Copy(token_text, split_idx + 1, MaxInt);
        if not is_relaxed_no_initial_syllable_text(right_text) then
        begin
            Continue;
        end;

        left_parts := parser.parse(left_text);
        right_parts := parser.parse(right_text);
        if (Length(left_parts) = 1) and (Length(right_parts) = 1) and
            SameText(left_parts[0].text, left_text) and
            SameText(right_parts[0].text, right_text) then
        begin
            out_left := left_text;
            out_right := right_text;
            Result := True;
            Exit;
        end;
    end;
end;

function detect_relaxed_missing_apostrophe_boundary_shift(const input_text: string): Boolean;
var
    parser: TncPinyinParser;
    primary_parts: TncPinyinParseResult;
    part_idx: Integer;
    left_text: string;
    right_text: string;
    combined_text: string;
begin
    Result := False;
    if (input_text = '') or (Pos('''', input_text) > 0) then
    begin
        Exit;
    end;

    parser := TncPinyinParser.Create;
    try
        primary_parts := parser.parse(input_text);
        if Length(primary_parts) < 2 then
        begin
            Exit;
        end;

        for part_idx := 0 to High(primary_parts) - 1 do
        begin
            combined_text := primary_parts[part_idx].text + primary_parts[part_idx + 1].text;
            if try_split_relaxed_missing_apostrophe_token(parser, combined_text, left_text, right_text) and
                (Length(left_text) > Length(primary_parts[part_idx].text)) then
            begin
                Exit(True);
            end;
        end;
    finally
        parser.Free;
    end;
end;

function parse_pinyin_with_relaxed_missing_apostrophe(const input_text: string): TncPinyinParseResult;
var
    parser: TncPinyinParser;
    primary_parts: TncPinyinParseResult;
    expanded_parts: TncPinyinParseResult;
    part_idx: Integer;
    out_idx: Integer;
    left_text: string;
    right_text: string;
    combined_text: string;
    changed: Boolean;

    procedure append_part(const text: string; const start_index: Integer);
    begin
        if text = '' then
        begin
            Exit;
        end;
        SetLength(expanded_parts, out_idx + 1);
        expanded_parts[out_idx].text := text;
        expanded_parts[out_idx].start_index := start_index;
        expanded_parts[out_idx].length := Length(text);
        Inc(out_idx);
    end;
begin
    parser := TncPinyinParser.Create;
    try
        primary_parts := parser.parse(input_text);
        if (Length(primary_parts) = 0) or (Pos('''', input_text) > 0) then
        begin
            Result := primary_parts;
            Exit;
        end;

        SetLength(expanded_parts, 0);
        out_idx := 0;
        changed := False;
        part_idx := 0;
        while part_idx <= High(primary_parts) do
        begin
            if try_split_relaxed_missing_apostrophe_token(parser, primary_parts[part_idx].text, left_text, right_text) then
            begin
                append_part(left_text, primary_parts[part_idx].start_index);
                append_part(right_text, primary_parts[part_idx].start_index + Length(left_text));
                changed := True;
                Inc(part_idx);
                Continue;
            end;

            if part_idx < High(primary_parts) then
            begin
                combined_text := primary_parts[part_idx].text + primary_parts[part_idx + 1].text;
                if try_split_relaxed_missing_apostrophe_token(parser, combined_text, left_text, right_text) and
                    (Length(left_text) > Length(primary_parts[part_idx].text)) then
                begin
                    append_part(left_text, primary_parts[part_idx].start_index);
                    append_part(right_text, primary_parts[part_idx].start_index + Length(left_text));
                    changed := True;
                    Inc(part_idx, 2);
                    Continue;
                end;
            end;

            append_part(primary_parts[part_idx].text, primary_parts[part_idx].start_index);
            Inc(part_idx);
        end;

        if changed or (Length(expanded_parts) > Length(primary_parts)) then
        begin
            Result := expanded_parts;
        end
        else
        begin
            Result := primary_parts;
        end;
    finally
        parser.Free;
    end;
end;

procedure TncEngine.build_candidates;
var
    raw_candidates: TncCandidateList;
    segment_candidates: TncCandidateList;
    full_lookup_candidates: TncCandidateList;
    lookup_cache: TDictionary<string, TncCandidateList>;
    limit: Integer;
    i: Integer;
    fallback_comment: string;
    has_raw_candidates: Boolean;
    has_segment_candidates: Boolean;
    raw_from_dictionary: Boolean;
    trailing_prefix_rescue_applied: Boolean;
    lookup_text: string;
    has_multi_syllable_input: Boolean;
    has_internal_dangling_initial: Boolean;
    has_safe_trailing_initial_typing_state: Boolean;
    all_initial_compact_query: Boolean;
    head_only_multi_syllable: Boolean;
    input_syllable_count: Integer;
    multi_syllable_cap_limit: Integer;
    normalized_lookup_text: string;
    repeated_two_syllable_query: Boolean;
    single_char_partial_min_count: Integer;
    runtime_phrase_added: Boolean;
    runtime_redup_added: Boolean;
    raw_candidates_seeded_from_runtime_only: Boolean;
    relaxed_missing_apostrophe_comment: string;
    has_relaxed_missing_apostrophe_partial: Boolean;
    has_relaxed_missing_apostrophe_boundary_shift: Boolean;
    lookup_cache_hits: Integer;
    lookup_cache_misses: Integer;
    lookup_elapsed_ms: Int64;
    segment_elapsed_ms: Int64;
    runtime_elapsed_ms: Int64;
    post_elapsed_ms: Int64;
    sort_elapsed_ms: Int64;
    path_search_elapsed_ms: Int64;
    total_start_tick: UInt64;
    phase_start_tick: UInt64;
    allow_relaxed_missing_apostrophe: Boolean;
    compact_runtime_candidate: TncCandidate;
    compact_runtime_candidates: TncCandidateList;
    relaxed_segment_candidates: TncCandidateList;
    explicit_apostrophe_aligned_candidates: TncCandidateList;
    has_explicit_apostrophe_input: Boolean;
    confirmed_prefix_boundary_partial_preferred: Boolean;
    explicit_apostrophe_query_syllables: TncPinyinParseResult;
    explicit_apostrophe_query_parsed: Boolean;

    procedure clear_candidate_comments(var candidates: TncCandidateList);
    var
        idx: Integer;
    begin
        for idx := 0 to High(candidates) do
        begin
            candidates[idx].comment := '';
        end;
    end;

    function has_multi_char_dictionary_anchor(const candidates: TncCandidateList): Boolean;
    var
        idx: Integer;
    begin
        Result := False;
        for idx := 0 to High(candidates) do
        begin
            if Length(candidates[idx].text) > 1 then
            begin
                Exit(True);
            end;
        end;
    end;

    procedure sort_candidates_lightweight(var candidates: TncCandidateList);
    var
        left_idx: Integer;
        right_idx: Integer;
        left_units: Integer;
        right_units: Integer;
        left_score: Integer;
        right_score: Integer;
        tmp: TncCandidate;

        function get_lightweight_rank(const candidate: TncCandidate;
            const text_units: Integer): Integer;
        begin
            Result := candidate.score;
            if candidate.source = cs_user then
            begin
                Inc(Result, 1200);
            end;
            if candidate.comment = '' then
            begin
                Inc(Result, 320);
                if (input_syllable_count >= 4) and (text_units = input_syllable_count) then
                begin
                    Inc(Result, 1400);
                end
                else if text_units >= 2 then
                begin
                    Inc(Result, 220);
                end;
            end
            else if text_units >= 2 then
            begin
                Inc(Result, 80);
            end;

            if candidate.has_dict_weight then
            begin
                Inc(Result, Min(360, candidate.dict_weight div 3));
            end;
        end;
    begin
        if Length(candidates) <= 1 then
        begin
            Exit;
        end;

        for left_idx := 0 to High(candidates) - 1 do
        begin
            left_units := get_candidate_text_unit_count(Trim(candidates[left_idx].text));
            left_score := get_lightweight_rank(candidates[left_idx], left_units);
            for right_idx := left_idx + 1 to High(candidates) do
            begin
                right_units := get_candidate_text_unit_count(Trim(candidates[right_idx].text));
                right_score := get_lightweight_rank(candidates[right_idx], right_units);
                if right_score > left_score then
                begin
                    tmp := candidates[left_idx];
                    candidates[left_idx] := candidates[right_idx];
                    candidates[right_idx] := tmp;
                    left_units := right_units;
                    left_score := right_score;
                    Continue;
                end;

                if right_score = left_score then
                begin
                    if right_units > left_units then
                    begin
                        tmp := candidates[left_idx];
                        candidates[left_idx] := candidates[right_idx];
                        candidates[right_idx] := tmp;
                        left_units := right_units;
                        Continue;
                    end;

                    if (right_units = left_units) and
                        (CompareText(candidates[right_idx].text, candidates[left_idx].text) < 0) then
                    begin
                        tmp := candidates[left_idx];
                        candidates[left_idx] := candidates[right_idx];
                        candidates[right_idx] := tmp;
                        Continue;
                    end;
                end;
            end;
        end;
    end;

    procedure filter_short_dictionary_hits_for_explicit_apostrophe(var candidates: TncCandidateList;
        const min_char_count: Integer);
    var
        idx: Integer;
        out_idx: Integer;
        text_units: TArray<string>;
    begin
        if min_char_count <= 1 then
        begin
            Exit;
        end;

        out_idx := 0;
        for idx := 0 to High(candidates) do
        begin
            text_units := split_text_units(Trim(candidates[idx].text));
            if Length(text_units) >= min_char_count then
            begin
                if out_idx <> idx then
                begin
                    candidates[out_idx] := candidates[idx];
                end;
                Inc(out_idx);
            end;
        end;
        SetLength(candidates, out_idx);
    end;

    procedure filter_explicit_apostrophe_single_char_complete_candidates(var candidates: TncCandidateList);
    var
        idx: Integer;
        out_idx: Integer;
        text_units: TArray<string>;
    begin
        out_idx := 0;
        for idx := 0 to High(candidates) do
        begin
            text_units := split_text_units(Trim(candidates[idx].text));
            if (candidates[idx].comment = '') and (Length(text_units) = 1) then
            begin
                Continue;
            end;

            if out_idx <> idx then
            begin
                candidates[out_idx] := candidates[idx];
            end;
            Inc(out_idx);
        end;
        SetLength(candidates, out_idx);
    end;

    function matches_explicit_apostrophe_unit_alignment(const candidate_text: string): Boolean;
    var
        parser_local: TncPinyinParser;
        text_units: TArray<string>;
        idx: Integer;
        is_preferred: Boolean;
    begin
        Result := False;
        if (not has_explicit_apostrophe_input) or (input_syllable_count <= 1) then
        begin
            Exit;
        end;

        text_units := split_text_units(Trim(candidate_text));
        if Length(text_units) <> input_syllable_count then
        begin
            Exit;
        end;

        if not explicit_apostrophe_query_parsed then
        begin
            explicit_apostrophe_query_parsed := True;
            parser_local := TncPinyinParser.Create;
            try
                explicit_apostrophe_query_syllables := parser_local.parse(m_composition_text);
            finally
                parser_local.Free;
            end;
        end;

        if Length(explicit_apostrophe_query_syllables) <> input_syllable_count then
        begin
            Exit;
        end;

        for idx := 0 to input_syllable_count - 1 do
        begin
            if not match_single_char_candidate_for_syllable(
                Trim(explicit_apostrophe_query_syllables[idx].text),
                text_units[idx],
                is_preferred) then
            begin
                Exit(False);
            end;
        end;

        Result := True;
    end;

    procedure filter_complete_candidates_for_explicit_apostrophe_boundary(
        var candidates: TncCandidateList; const aligned_candidates: TncCandidateList);
    var
        allowed_complete_texts: TDictionary<string, Byte>;
        idx: Integer;
        out_idx: Integer;
        key: string;
        candidate_text_units: Integer;
        encoded_path: string;
        has_aligned_boundary_candidate: Boolean;
        function contains_non_ascii_text(const value: string): Boolean;
        var
            ch: Char;
        begin
            Result := False;
            for ch in value do
            begin
                if Ord(ch) > $7F then
                begin
                    Exit(True);
                end;
            end;
        end;
    begin
        allowed_complete_texts := TDictionary<string, Byte>.Create;
        try
            has_aligned_boundary_candidate := False;
            for idx := 0 to High(aligned_candidates) do
            begin
                if aligned_candidates[idx].comment <> '' then
                begin
                    if contains_non_ascii_text(Trim(aligned_candidates[idx].text)) then
                    begin
                        has_aligned_boundary_candidate := True;
                    end;
                    Continue;
                end;

                candidate_text_units := get_candidate_text_unit_count(Trim(aligned_candidates[idx].text));
                if candidate_text_units < 2 then
                begin
                    Continue;
                end;

                encoded_path := get_segment_path_for_candidate(aligned_candidates[idx]);
                if get_encoded_path_segment_count_local(encoded_path) < input_syllable_count then
                begin
                    Continue;
                end;

                has_aligned_boundary_candidate := True;
                key := LowerCase(Trim(aligned_candidates[idx].text));
                if (key <> '') and (not allowed_complete_texts.ContainsKey(key)) then
                begin
                    allowed_complete_texts.Add(key, 1);
                end;
            end;

            if not has_aligned_boundary_candidate then
            begin
                Exit;
            end;

            out_idx := 0;
            for idx := 0 to High(candidates) do
            begin
                if candidates[idx].comment <> '' then
                begin
                    if out_idx <> idx then
                    begin
                        candidates[out_idx] := candidates[idx];
                    end;
                    Inc(out_idx);
                    Continue;
                end;

                candidate_text_units := get_candidate_text_unit_count(Trim(candidates[idx].text));
                if candidate_text_units < 2 then
                begin
                    if out_idx <> idx then
                    begin
                        candidates[out_idx] := candidates[idx];
                    end;
                    Inc(out_idx);
                    Continue;
                end;

                key := LowerCase(Trim(candidates[idx].text));
                if (key <> '') and allowed_complete_texts.ContainsKey(key) then
                begin
                    if out_idx <> idx then
                    begin
                        candidates[out_idx] := candidates[idx];
                    end;
                    Inc(out_idx);
                    Continue;
                end;

                if matches_explicit_apostrophe_unit_alignment(candidates[idx].text) then
                begin
                    if out_idx <> idx then
                    begin
                        candidates[out_idx] := candidates[idx];
                    end;
                    Inc(out_idx);
                end;
            end;
            SetLength(candidates, out_idx);
        finally
            allowed_complete_texts.Free;
        end;
    end;

    procedure prefer_relaxed_missing_apostrophe_boundary_partial(var candidates: TncCandidateList);
    var
        preferred_index: Integer;
        target_index: Integer;
        idx: Integer;
        preferred_candidate: TncCandidate;
        preferred_comment: string;
        primary_comment: string;

        function build_partial_tail_comment(const input_text: string;
            const allow_relaxed_split: Boolean): string;
        var
            parser: TncPinyinParser;
            parts: TncPinyinParseResult;
            part_idx: Integer;
        begin
            Result := '';
            if input_text = '' then
            begin
                Exit;
            end;

            parser := TncPinyinParser.Create;
            try
                if allow_relaxed_split then
                begin
                    parts := parse_pinyin_with_relaxed_missing_apostrophe(input_text);
                end
                else
                begin
                    parts := parser.parse(input_text);
                end;
            finally
                parser.Free;
            end;

            if Length(parts) <= 1 then
            begin
                Exit;
            end;

            for part_idx := 1 to High(parts) do
            begin
                Result := Result + parts[part_idx].text;
            end;
        end;

        function is_complete_multi_char_anchor(const candidate: TncCandidate): Boolean;
        var
            candidate_text_units: Integer;
        begin
            Result := False;
            if candidate.comment <> '' then
            begin
                Exit;
            end;

            candidate_text_units := get_candidate_text_unit_count(Trim(candidate.text));
            if candidate_text_units < 2 then
            begin
                Exit;
            end;

            if candidate.has_dict_weight or (candidate.source = cs_user) then
            begin
                Exit(True);
            end;

            Result := (candidate.source = cs_rule) and
                (not is_runtime_chain_candidate(candidate)) and
                (not is_runtime_common_pattern_candidate(candidate)) and
                (not is_runtime_redup_candidate(candidate));
        end;
    begin
        if (not has_relaxed_missing_apostrophe_partial) or
            (not has_relaxed_missing_apostrophe_boundary_shift) or
            (Length(candidates) <= 1) then
        begin
            Exit;
        end;

        preferred_comment := build_partial_tail_comment(m_composition_text, True);
        if preferred_comment = '' then
        begin
            preferred_comment := build_partial_tail_comment(lookup_text, True);
        end;
        primary_comment := build_partial_tail_comment(m_composition_text, False);
        if primary_comment = '' then
        begin
            primary_comment := build_partial_tail_comment(lookup_text, False);
        end;

        if (preferred_comment = '') or SameText(preferred_comment, primary_comment) then
        begin
            Exit;
        end;

        preferred_index := -1;
        for idx := 0 to High(candidates) do
        begin
            if SameText(candidates[idx].comment, preferred_comment) then
            begin
                preferred_index := idx;
                Break;
            end;
        end;

        if preferred_index < 0 then
        begin
            Exit;
        end;

        target_index := 0;
        while (target_index <= High(candidates)) and
            is_complete_multi_char_anchor(candidates[target_index]) do
        begin
            Inc(target_index);
        end;

        if (target_index > High(candidates)) or (preferred_index <= target_index) then
        begin
            Exit;
        end;

        preferred_candidate := candidates[preferred_index];
        for idx := preferred_index downto target_index + 1 do
        begin
            candidates[idx] := candidates[idx - 1];
        end;
        candidates[target_index] := preferred_candidate;
    end;

    procedure filter_long_query_nonlexicon_complete_candidates(var candidates: TncCandidateList);
    var
        idx: Integer;
        out_idx: Integer;
        candidate_text_units: Integer;
        segment_path: string;
    begin
        if (input_syllable_count < 2) or
            (not c_suppress_nonlexicon_complete_long_candidates) then
        begin
            Exit;
        end;

        out_idx := 0;
        for idx := 0 to High(candidates) do
        begin
            candidate_text_units := get_candidate_text_unit_count(Trim(candidates[idx].text));
            if (candidates[idx].comment <> '') or (candidate_text_units < 2) then
            begin
                if out_idx <> idx then
                begin
                    candidates[out_idx] := candidates[idx];
                end;
                Inc(out_idx);
                Continue;
            end;

            if candidates[idx].has_dict_weight or (candidates[idx].source = cs_user) then
            begin
                if out_idx <> idx then
                begin
                    candidates[out_idx] := candidates[idx];
                end;
                Inc(out_idx);
                Continue;
            end;

            if input_syllable_count >= c_long_sentence_full_path_min_syllables then
            begin
                segment_path := get_segment_path_for_candidate(candidates[idx]);
                if (get_encoded_path_segment_count_local(segment_path) > 1) and
                    (not is_runtime_chain_candidate(candidates[idx])) and
                    (not is_runtime_common_pattern_candidate(candidates[idx])) and
                    (not is_runtime_redup_candidate(candidates[idx])) then
                begin
                    if out_idx <> idx then
                    begin
                        candidates[out_idx] := candidates[idx];
                    end;
                    Inc(out_idx);
                    Continue;
                end;
            end;
        end;
        SetLength(candidates, out_idx);
    end;

    function should_enable_long_sentence_full_path_search_local: Boolean;
    begin
        Result := m_config.enable_segment_candidates and has_multi_syllable_input and
            (input_syllable_count >= c_long_sentence_full_path_min_syllables) and
            (not all_initial_compact_query) and
            (not has_internal_dangling_initial);
    end;

    function is_single_initial_token_local(const token_text: string): Boolean;
    var
        ch: Char;
    begin
        Result := False;
        if Length(token_text) <> 1 then
        begin
            Exit;
        end;

        ch := token_text[1];
        if (ch >= 'A') and (ch <= 'Z') then
        begin
            ch := Chr(Ord(ch) + 32);
        end;
        Result := CharInSet(ch, ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x',
            'r', 'z', 'c', 's', 'y', 'w']);
    end;

    function detect_internal_dangling_initial(const text: string): Boolean;
    var
        parser: TncPinyinParser;
        parts: TncPinyinParseResult;
        idx: Integer;
    begin
        Result := False;
        if text = '' then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            parts := parser.parse(text);
        finally
            parser.Free;
        end;

        if Length(parts) <= 1 then
        begin
            Exit;
        end;

        // Pattern like "cha + g + n" usually means malformed/typo input.
        // In this case segment fusion is often noisy and should not override
        // direct lookup/typo recovery results.
        for idx := 0 to High(parts) - 1 do
        begin
            if is_single_initial_token_local(parts[idx].text) then
            begin
                Result := True;
                Exit;
            end;
        end;
    end;

    function detect_safe_trailing_initial_typing_state(const text: string): Boolean;
    var
        normalized_text: string;
        parser: TncPinyinParser;
        parts: TncPinyinParseResult;
        prefix_text: string;
        suffix_start: Integer;
        suffix_count: Integer;
        idx: Integer;
        tail_cluster: string;
    begin
        Result := False;
        if text = '' then
        begin
            Exit;
        end;

        normalized_text := normalize_pinyin_text(text);
        if Length(normalized_text) >= 3 then
        begin
            prefix_text := Copy(normalized_text, 1, Length(normalized_text) - 1);
            if is_single_initial_token_local(Copy(normalized_text, Length(normalized_text), 1)) and
                is_full_pinyin_key(prefix_text) then
            begin
                Exit(True);
            end;
        end;
        if Length(normalized_text) >= 4 then
        begin
            tail_cluster := Copy(normalized_text, Length(normalized_text) - 1, 2);
            prefix_text := Copy(normalized_text, 1, Length(normalized_text) - 2);
            if ((tail_cluster = 'zh') or (tail_cluster = 'ch') or (tail_cluster = 'sh')) and
                is_full_pinyin_key(prefix_text) then
            begin
                Exit(True);
            end;
        end;

        parser := TncPinyinParser.create;
        try
            parts := parser.parse(text);
        finally
            parser.Free;
        end;

        if Length(parts) <= 1 then
        begin
            Exit;
        end;

        suffix_start := Length(parts);
        while (suffix_start > 0) and is_single_initial_token_local(parts[suffix_start - 1].text) do
        begin
            Dec(suffix_start);
        end;

        suffix_count := Length(parts) - suffix_start;
        if (suffix_count <= 0) or (suffix_count > 2) or (suffix_start <= 0) then
        begin
            Exit;
        end;

        for idx := 0 to suffix_start - 1 do
        begin
            if is_single_initial_token_local(parts[idx].text) then
            begin
                Exit;
            end;
        end;

        if suffix_count = 1 then
        begin
            Result := True;
            Exit;
        end;

        tail_cluster := LowerCase(parts[High(parts) - 1].text + parts[High(parts)].text);
        Result := (tail_cluster = 'zh') or (tail_cluster = 'ch') or (tail_cluster = 'sh');
    end;

    function detect_all_initial_compact_query(const text: string): Boolean;
    const
        c_all_initial_compact_query_syllable_min = 5;
    var
        parser: TncPinyinParser;
        parts: TncPinyinParseResult;
        idx: Integer;
    begin
        Result := False;
        if text = '' then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            parts := parser.parse(text);
        finally
            parser.Free;
        end;

        if Length(parts) < c_all_initial_compact_query_syllable_min then
        begin
            Exit;
        end;

        for idx := 0 to High(parts) do
        begin
            if not is_single_initial_token_local(parts[idx].text) then
            begin
                Exit;
            end;
        end;

        Result := True;
    end;

    procedure ensure_partial_fallback_visible(var candidates: TncCandidateList; const visible_limit: Integer);
    var
        idx: Integer;
        partial_index: Integer;
        partial_candidate: TncCandidate;
    begin
        if (visible_limit <= 0) or (Length(candidates) <= visible_limit) then
        begin
            Exit;
        end;

        for idx := 0 to visible_limit - 1 do
        begin
            if candidates[idx].comment <> '' then
            begin
                Exit;
            end;
        end;

        partial_index := -1;
        for idx := visible_limit to High(candidates) do
        begin
            if candidates[idx].comment <> '' then
            begin
                partial_index := idx;
                Break;
            end;
        end;

        if partial_index < 0 then
        begin
            Exit;
        end;

        partial_candidate := candidates[partial_index];
        for idx := partial_index downto visible_limit do
        begin
            candidates[idx] := candidates[idx - 1];
        end;
        candidates[visible_limit - 1] := partial_candidate;
    end;

    function is_strong_exact_partial_candidate_for_visibility(
        const candidate: TncCandidate): Boolean;
    begin
        Result := (candidate.comment <> '') and
            (get_candidate_text_unit_count(Trim(candidate.text)) >= 2) and
            (candidate.has_dict_weight or (candidate.source = cs_user) or
            ((candidate.source = cs_rule) and
            (not is_runtime_chain_candidate(candidate)) and
            (not is_runtime_common_pattern_candidate(candidate)) and
            (not is_runtime_redup_candidate(candidate))));
    end;

    function is_supported_head_phrase_partial_for_visibility(
        const candidate: TncCandidate): Boolean;
    const
        c_supported_head_phrase_first_single_margin_local = 180;
        c_supported_head_phrase_tail_ratio_pct_local = 80;
    var
        candidate_text: string;
        partial_comment_syllables: Integer;
    begin
        Result := False;
        if (m_last_lookup_syllable_count <> 3) or (candidate.comment = '') then
        begin
            Exit;
        end;

        candidate_text := Trim(candidate.text);
        if (candidate_text = '') or
            (get_candidate_text_unit_count(candidate_text) < 2) then
        begin
            Exit;
        end;

        partial_comment_syllables := get_effective_compact_pinyin_unit_count(
            normalize_pinyin_text(candidate.comment));
        if partial_comment_syllables <> 1 then
        begin
            Exit;
        end;

        if (m_last_three_syllable_head_exact_text = '') or
            (candidate_text <> m_last_three_syllable_head_exact_text) then
        begin
            Exit;
        end;

        if not is_strong_exact_partial_candidate_for_visibility(candidate) then
        begin
            Exit;
        end;

        if m_last_three_syllable_head_strength <= 0 then
        begin
            Exit;
        end;
        if m_last_three_syllable_head_strength >=
            (m_last_three_syllable_first_single_strength +
            c_supported_head_phrase_first_single_margin_local) then
        begin
            Exit(True);
        end;

        if m_last_three_syllable_head_path_bonus > 0 then
        begin
            Exit(True);
        end;

        if m_last_three_syllable_tail_strength <= 0 then
        begin
            Exit(True);
        end;

        Result := (m_last_three_syllable_head_strength * 100) >=
            (m_last_three_syllable_tail_strength *
            c_supported_head_phrase_tail_ratio_pct_local);
    end;

    procedure ensure_strong_two_plus_one_partial_visible(var candidates: TncCandidateList;
        const visible_limit: Integer);
    var
        idx: Integer;
        partial_index: Integer;
        fallback_partial_index: Integer;
        target_index: Integer;
        partial_candidate: TncCandidate;
    begin
        if (m_last_lookup_syllable_count <> 3) or
            (visible_limit <= 0) or (Length(candidates) = 0) then
        begin
            Exit;
        end;

        for idx := 0 to Min(visible_limit - 1, High(candidates)) do
        begin
            if is_supported_head_phrase_partial_for_visibility(candidates[idx]) then
            begin
                Exit;
            end;
            if (m_last_three_syllable_partial_preference_kind = 1) and
                is_strong_exact_partial_candidate_for_visibility(candidates[idx]) then
            begin
                Exit;
            end;
        end;

        partial_index := -1;
        fallback_partial_index := -1;
        for idx := 0 to High(candidates) do
        begin
            if is_supported_head_phrase_partial_for_visibility(candidates[idx]) then
            begin
                partial_index := idx;
                Break;
            end;
            if (fallback_partial_index < 0) and
                (m_last_three_syllable_partial_preference_kind = 1) and
                is_strong_exact_partial_candidate_for_visibility(candidates[idx]) then
            begin
                fallback_partial_index := idx;
            end;
        end;

        if partial_index < 0 then
        begin
            partial_index := fallback_partial_index;
        end;

        if partial_index < 0 then
        begin
            Exit;
        end;

        target_index := 2;
        if target_index >= visible_limit then
        begin
            target_index := visible_limit - 1;
        end;
        if target_index >= Length(candidates) then
        begin
            target_index := Length(candidates) - 1;
        end;
        if (target_index < 0) or (partial_index <= target_index) then
        begin
            Exit;
        end;

        partial_candidate := candidates[partial_index];
        for idx := partial_index downto target_index + 1 do
        begin
            candidates[idx] := candidates[idx - 1];
        end;
        candidates[target_index] := partial_candidate;
    end;

    function is_single_text_unit(const value: string): Boolean;
    begin
        if Length(value) = 1 then
        begin
            Result := True;
            Exit;
        end;

        Result := (Length(value) = 2) and
            (Ord(value[1]) >= $D800) and (Ord(value[1]) <= $DBFF) and
            (Ord(value[2]) >= $DC00) and (Ord(value[2]) <= $DFFF);
    end;

    function try_get_single_text_unit_codepoint(const value: string; out codepoint: Integer): Boolean;
    begin
        Result := False;
        codepoint := 0;
        if Length(value) = 1 then
        begin
            codepoint := Ord(value[1]);
            Result := True;
            Exit;
        end;

        if (Length(value) = 2) and
            (Ord(value[1]) >= $D800) and (Ord(value[1]) <= $DBFF) and
            (Ord(value[2]) >= $DC00) and (Ord(value[2]) <= $DFFF) then
        begin
            codepoint := ((Ord(value[1]) - $D800) shl 10) + (Ord(value[2]) - $DC00) + $10000;
            Result := True;
        end;
    end;

    function dictionary_lookup_cached(const pinyin_key: string; out out_results: TncCandidateList): Boolean;
    var
        phase_start_tick: UInt64;
    begin
        SetLength(out_results, 0);
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit(False);
        end;

        if lookup_cache.TryGetValue(pinyin_key, out_results) then
        begin
            Inc(lookup_cache_hits);
            Exit(Length(out_results) > 0);
        end;

        Inc(lookup_cache_misses);
        phase_start_tick := GetTickCount64;
        if not m_dictionary.lookup(pinyin_key, out_results) then
        begin
            SetLength(out_results, 0);
        end;
        Inc(lookup_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
        lookup_cache.AddOrSetValue(pinyin_key, out_results);
        Result := Length(out_results) > 0;
    end;

    function dictionary_exact_lookup_cached(const pinyin_key: string;
        out out_results: TncCandidateList): Boolean;
    var
        cache_key: string;
        phase_start_tick: UInt64;
    begin
        SetLength(out_results, 0);
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit(False);
        end;

        cache_key := '#exact#' + pinyin_key;
        if lookup_cache.TryGetValue(cache_key, out_results) then
        begin
            Inc(lookup_cache_hits);
            Exit(Length(out_results) > 0);
        end;

        Inc(lookup_cache_misses);
        phase_start_tick := GetTickCount64;
        if not m_dictionary.lookup_exact_full_pinyin(pinyin_key, out_results) then
        begin
            SetLength(out_results, 0);
        end;
        Inc(lookup_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
        lookup_cache.AddOrSetValue(cache_key, out_results);
        Result := Length(out_results) > 0;
    end;

    function dictionary_prefix_lookup_cached(const pinyin_key: string;
        out out_results: TncCandidateList): Boolean;
    var
        cache_key: string;
        phase_start_tick: UInt64;
    begin
        SetLength(out_results, 0);
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit(False);
        end;

        cache_key := '#prefix#' + pinyin_key;
        if lookup_cache.TryGetValue(cache_key, out_results) then
        begin
            Inc(lookup_cache_hits);
            Exit(Length(out_results) > 0);
        end;

        Inc(lookup_cache_misses);
        phase_start_tick := GetTickCount64;
        if not m_dictionary.lookup_full_pinyin_prefix(pinyin_key, out_results) then
        begin
            SetLength(out_results, 0);
        end;
        Inc(lookup_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
        lookup_cache.AddOrSetValue(cache_key, out_results);
        Result := Length(out_results) > 0;
    end;

    function build_segment_candidates_timed(out out_candidates: TncCandidateList;
        const include_full_path: Boolean = True;
        const allow_relaxed_split: Boolean = False): Boolean;
    var
        phase_start_tick: UInt64;
        local_path_search_elapsed_ms: Int64;
    begin
        phase_start_tick := GetTickCount64;
        local_path_search_elapsed_ms := 0;
        Result := build_segment_candidates(out_candidates, include_full_path, local_path_search_elapsed_ms,
            allow_relaxed_split);
        Inc(segment_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
        Inc(path_search_elapsed_ms, local_path_search_elapsed_ms);
    end;

    procedure sort_candidates_timed(var candidates: TncCandidateList);
    var
        phase_start_tick: UInt64;
    begin
        phase_start_tick := GetTickCount64;
        sort_candidates(candidates);
        Inc(sort_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
    end;

    procedure note_post_phase_elapsed(const phase_start_tick: UInt64);
    begin
        Inc(post_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
    end;

    function has_complete_phrase_candidate_for_syllable_count(
        const candidates: TncCandidateList; const expected_syllables: Integer): Boolean;
    var
        candidate_idx: Integer;
    begin
        Result := False;
        if expected_syllables <= 0 then
        begin
            Exit;
        end;

        for candidate_idx := 0 to High(candidates) do
        begin
            if candidates[candidate_idx].comment <> '' then
            begin
                Continue;
            end;
            if get_candidate_text_unit_count(Trim(candidates[candidate_idx].text)) <>
                expected_syllables then
            begin
                Continue;
            end;
            Exit(True);
        end;
    end;

    function has_extendable_trailing_prefix_query_text(const pinyin_key: string): Boolean;
    var
        effective_syllables: TncPinyinParseResult;
        local_syllable_count: Integer;
        last_syllable_text: string;
        suffix_ch: Char;
        extended_key: string;
    begin
        Result := False;
        if pinyin_key = '' then
        begin
            Exit;
        end;

        effective_syllables := get_effective_compact_pinyin_syllables(pinyin_key);
        local_syllable_count := Length(effective_syllables);
        if local_syllable_count < 4 then
        begin
            Exit;
        end;

        last_syllable_text := Trim(effective_syllables[High(effective_syllables)].text);
        if last_syllable_text = '' then
        begin
            Exit;
        end;

        for suffix_ch := 'a' to 'z' do
        begin
            extended_key := pinyin_key + suffix_ch;
            if get_effective_compact_pinyin_unit_count(extended_key) = local_syllable_count then
            begin
                Exit(True);
            end;
        end;
    end;

    procedure finalize_lookup_timing_info;
    var
        total_elapsed_ms: Int64;
    begin
        total_elapsed_ms := Int64(GetTickCount64 - total_start_tick);
        m_last_lookup_timing_info := Format(
            'perf=[lk=%d seg=%d path=%d rt=%d post=%d sort=%d cache=%d/%d total=%d]',
            [lookup_elapsed_ms, segment_elapsed_ms, path_search_elapsed_ms, runtime_elapsed_ms, post_elapsed_ms, sort_elapsed_ms,
            lookup_cache_hits, lookup_cache_misses, total_elapsed_ms]);
    end;

    function is_common_surname_text(const value: string): Boolean;
    var
        codepoint: Integer;
    begin
        Result := False;
        if not try_get_single_text_unit_codepoint(value, codepoint) then
        begin
            Exit;
        end;

        case codepoint of
            $8D75, $94B1, $5B59, $674E, $5468, $5434, $90D1, $738B, $51AF, $9648,
            $891A, $536B, $848B, $6C88, $97E9, $6768, $6731, $79E6, $8BB8, $4F55,
            $5415, $65BD, $5F20, $5B54, $66F9, $4E25, $534E, $91D1, $9B4F, $9676,
            $59DC, $621A, $8C22, $90B9, $55BB, $82CF, $6F58, $845B, $8303, $5F6D,
            $90CE, $9C81, $97E6, $9A6C, $82D7, $51E4, $65B9, $4FDE, $4EFB, $8881,
            $67F3, $9C8D, $53F2, $5510, $8D39, $5EC9, $5C91, $859B, $96F7, $8D3A,
            $502A, $6C64, $6ED5, $6BB7, $7F57, $6BD5, $90DD, $90AC, $5B89, $5E38,
            $4E50, $4E8E, $5085, $76AE, $9F50, $5EB7, $4F0D, $4F59, $5143, $987E,
            $5B5F, $5E73, $9EC4, $548C, $7A46, $8427, $5C39, $59DA, $90B5, $6E5B,
            $6C6A, $7941, $6BDB, $79B9, $72C4, $7C73, $660E, $81E7, $8BA1, $4F0F,
            $6210, $6234, $5B8B, $8305, $5E9E, $718A, $7EAA, $8212, $5C48, $9879,
            $795D, $8463, $6881, $675C, $962E, $84DD, $95F5, $5E2D, $5B63, $9EBB,
            $5F3A, $8D3E, $8DEF, $5A04, $5371, $6C5F, $7AE5, $989C, $90ED, $6885,
            $76DB, $6797, $949F, $5F90, $90B1, $9A86, $9AD8, $590F, $8521, $7530,
            $6A0A, $80E1, $51CC, $970D, $865E, $4E07, $67EF, $5362, $83AB, $623F,
            $7F2A, $89E3, $5E94, $4E01, $9093, $90C1, $5D14, $9F9A, $7A0B, $90A2,
            $88F4, $9646, $8363, $7FC1, $8340, $7F8A, $60E0, $7504, $5C01, $82AE,
            $50A8, $9773, $6BB5, $7126, $5DF4, $5F13, $7267, $8F66, $4FAF, $5B93,
            $84EC, $5168:
                Result := True;
        end;
    end;

    function is_preferred_partial_single_char_candidate(const candidate: TncCandidate): Boolean;
    const
        c_partial_preferred_min_weight = 120;
    var
        unit_text: string;
        codepoint: Integer;
        weight_value: Integer;
    begin
        Result := False;
        unit_text := Trim(candidate.text);
        if not try_get_single_text_unit_codepoint(unit_text, codepoint) then
        begin
            Exit;
        end;

        // Keep partial-leading single chars in common BMP CJK range to avoid
        // surfacing extremely rare code points as first choice for long input.
        if (codepoint < $4E00) or (codepoint > $9FFF) then
        begin
            Exit;
        end;

        if candidate.has_dict_weight then
        begin
            weight_value := candidate.dict_weight;
        end
        else
        begin
            weight_value := candidate.score;
        end;
        Result := weight_value >= c_partial_preferred_min_weight;
    end;

    function is_bmp_cjk_single_char_candidate(const candidate: TncCandidate): Boolean;
    var
        unit_text: string;
        codepoint: Integer;
    begin
        Result := False;
        unit_text := Trim(candidate.text);
        if not try_get_single_text_unit_codepoint(unit_text, codepoint) then
        begin
            Exit;
        end;

        Result := (codepoint >= $4E00) and (codepoint <= $9FFF);
    end;

    function get_text_unit_count(const text: string): Integer;
    var
        idx: Integer;
        codepoint: Integer;
    begin
        Result := 0;
        if text = '' then
        begin
            Exit;
        end;

        idx := 1;
        while idx <= Length(text) do
        begin
            codepoint := Ord(text[idx]);
            if (codepoint >= $D800) and (codepoint <= $DBFF) and (idx < Length(text)) then
            begin
                if (Ord(text[idx + 1]) >= $DC00) and (Ord(text[idx + 1]) <= $DFFF) then
                begin
                    Inc(idx);
                end;
            end;
            Inc(Result);
            Inc(idx);
        end;
    end;

    function get_input_syllable_count_for_text(const pinyin_text: string;
        const allow_relaxed_split: Boolean = False): Integer;
    begin
        Result := get_effective_compact_pinyin_unit_count(pinyin_text, allow_relaxed_split);
    end;

    function get_input_syllable_count: Integer;
    begin
        Result := get_input_syllable_count_for_text(m_composition_text);
    end;

    function is_repeated_two_syllable_query_text(const pinyin_text: string): Boolean;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        reconstructed: string;
    begin
        Result := False;
        if pinyin_text = '' then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(pinyin_text);
        finally
            parser.Free;
        end;

        if Length(syllables) <> 2 then
        begin
            Exit;
        end;

        if (syllables[0].text = '') or (syllables[1].text = '') then
        begin
            Exit;
        end;
        if not is_valid_pinyin_syllable(syllables[0].text) or
            (not is_valid_pinyin_syllable(syllables[1].text)) then
        begin
            Exit;
        end;

        reconstructed := syllables[0].text + syllables[1].text;
        Result := SameText(reconstructed, pinyin_text) and SameText(syllables[0].text, syllables[1].text);
    end;

    function is_two_unit_redup_text(const value: string): Boolean;
    var
        units: TArray<string>;
        trimmed: string;
    begin
        Result := False;
        trimmed := Trim(value);
        if trimmed = '' then
        begin
            Exit;
        end;

        units := split_text_units(trimmed);
        if Length(units) <> 2 then
        begin
            Exit;
        end;

        Result := units[0] = units[1];
    end;

    function is_runtime_constructed_tail_friendly(const tail_text: string): Boolean;
    var
        tail_codepoint: Integer;
    begin
        Result := False;
        if not try_get_single_text_unit_codepoint(Trim(tail_text), tail_codepoint) then
        begin
            Exit;
        end;

        case tail_codepoint of
            $4E2A, // 个
            $4F4D, // 位
            $6B21, // 次
            $70B9, // 点
            $4E9B, // 些
            $79CD, // 种
            $5929, // 天
            $5E74, // 年
            $6708, // 月
            $91CC, // 里
            $4E0B, // 下
            $56DE, // 回
            $904D, // 遍
            $58F0, // 声
            $9762, // 面
            $773C, // 眼
            $8FB9: // 边
                Result := True;
        end;
    end;

        function try_get_runtime_function_head_expected_text(
            const syllable_text: string;
            out out_text: string
        ): Boolean;
    begin
        out_text := '';
        if SameText(syllable_text, 'zhe') then
        begin
            out_text := string(Char($8FD9));
        end
        else if SameText(syllable_text, 'na') or SameText(syllable_text, 'nei') then
        begin
            out_text := string(Char($90A3));
        end
        else if SameText(syllable_text, 'yi') then
        begin
            out_text := string(Char($4E00));
        end
        else if SameText(syllable_text, 'liang') then
        begin
            out_text := string(Char($4E24));
        end
        else if SameText(syllable_text, 'ji') then
        begin
            out_text := string(Char($51E0));
        end
        else if SameText(syllable_text, 'mei') then
        begin
            out_text := string(Char($6BCF));
        end;
        Result := out_text <> '';
    end;

        function try_get_interrogative_location_tail_expected_text(
            const syllable_text: string;
            out out_text: string
        ): Boolean;
        begin
            out_text := '';
            if SameText(syllable_text, 'li') then
            begin
                out_text := string(Char($91CC));
            end
            else if SameText(syllable_text, 'er') then
            begin
                out_text := string(Char($513F));
            end;
            Result := out_text <> '';
        end;

        function is_runtime_constructed_phrase_friendly(const text: string): Boolean;
        var
            units: TArray<string>;
            tail_codepoint: Integer;
    begin
        Result := False;
        units := split_text_units(Trim(text));
        if Length(units) <> 2 then
        begin
            Exit;
        end;

        if units[0] = units[1] then
        begin
            Result := True;
            Exit;
        end;

        if is_runtime_constructed_tail_friendly(units[1]) then
        begin
            Result := True;
            Exit;
        end;

        if (units[1] = string(Char($5427))) or // 吧
            (units[1] = string(Char($5417))) or // 吗
            (units[1] = string(Char($5462))) then // 呢
        begin
            Result := True;
            Exit;
        end;

        if not try_get_single_text_unit_codepoint(units[1], tail_codepoint) then
        begin
            Exit;
        end;

        case tail_codepoint of
            $4E2A, // 涓?
            $4F4D, // 浣?
            $6B21, // 娆?
            $70B9, // 鐐?
            $4E9B, // 浜?
            $79CD, // 绉?
            $5929, // 澶?
            $5E74, // 骞?
            $6708, // 鏈?
            $91CC, // 閲?
            $4E0B, // 涓?
            $56DE, // 鍥?
            $904D, // 閬?
            $58F0, // 澹?
            $9762, // 闈?
            $773C: // 鐪?
                Result := True;
        end;
    end;

    procedure ensure_redup_complete_candidate_visible(var candidates: TncCandidateList; const boundary_limit: Integer);
    var
        idx: Integer;
        best_index: Integer;
        best_score: Integer;
        target_index: Integer;
        effective_boundary: Integer;
        picked: TncCandidate;
    begin
        if (not repeated_two_syllable_query) or (Length(candidates) = 0) then
        begin
            Exit;
        end;

        effective_boundary := boundary_limit;
        if (effective_boundary <= 0) or (effective_boundary > Length(candidates)) then
        begin
            effective_boundary := Length(candidates);
        end;
        if effective_boundary <= 0 then
        begin
            Exit;
        end;

        best_index := -1;
        best_score := Low(Integer);
        for idx := 0 to High(candidates) do
        begin
            if candidates[idx].comment <> '' then
            begin
                Continue;
            end;
            if not is_two_unit_redup_text(candidates[idx].text) then
            begin
                Continue;
            end;

            if (best_index < 0) or (candidates[idx].score > best_score) then
            begin
                best_index := idx;
                best_score := candidates[idx].score;
            end;
        end;

        if best_index < 0 then
        begin
            Exit;
        end;

        target_index := 4;
        if target_index >= effective_boundary then
        begin
            target_index := effective_boundary - 1;
        end;
        if target_index < 0 then
        begin
            Exit;
        end;

        if best_index <= target_index then
        begin
            Exit;
        end;

        picked := candidates[best_index];
        for idx := best_index downto target_index + 1 do
        begin
            candidates[idx] := candidates[idx - 1];
        end;
        candidates[target_index] := picked;
    end;

    procedure merge_head_only_full_lookup_candidates(var candidates: TncCandidateList;
        const pinyin_key: string);
    const
        c_head_only_full_non_user_limit = 4;
        c_head_only_full_non_user_penalty = 220;
        c_head_only_full_exact_long_bonus = 520;
    var
        candidate_text: string;
        filtered: TncCandidateList;
        text_units: Integer;
        non_user_count: Integer;
        input_syllables: Integer;
        idx: Integer;
        is_exact_long_full_match: Boolean;
    begin
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit;
        end;

        input_syllables := get_input_syllable_count_for_text(pinyin_key);
        if (input_syllables >= 4) and is_full_pinyin_key(pinyin_key) then
        begin
            if not dictionary_exact_lookup_cached(pinyin_key, full_lookup_candidates) then
            begin
                Exit;
            end;
        end
        else if not dictionary_lookup_cached(pinyin_key, full_lookup_candidates) then
        begin
            Exit;
        end;

        if Length(full_lookup_candidates) = 0 then
        begin
            Exit;
        end;

        clear_candidate_comments(full_lookup_candidates);
        SetLength(filtered, 0);
        non_user_count := 0;
        for idx := 0 to High(full_lookup_candidates) do
        begin
            candidate_text := Trim(full_lookup_candidates[idx].text);
            if candidate_text = '' then
            begin
                Continue;
            end;

            text_units := get_text_unit_count(candidate_text);
            if text_units < 2 then
            begin
                Continue;
            end;

            is_exact_long_full_match := (input_syllables >= 4) and
                (text_units = input_syllables);

            if is_exact_long_full_match then
            begin
                if (full_lookup_candidates[idx].source <> cs_user) and
                    (not full_lookup_candidates[idx].has_dict_weight) then
                begin
                    full_lookup_candidates[idx].has_dict_weight := True;
                    full_lookup_candidates[idx].dict_weight := full_lookup_candidates[idx].score;
                end;
                Inc(full_lookup_candidates[idx].score, c_head_only_full_exact_long_bonus);
                SetLength(filtered, Length(filtered) + 1);
                filtered[High(filtered)] := full_lookup_candidates[idx];
                Continue;
            end;

            if full_lookup_candidates[idx].source = cs_user then
            begin
                SetLength(filtered, Length(filtered) + 1);
                filtered[High(filtered)] := full_lookup_candidates[idx];
                Continue;
            end;

            // Keep only phrase-shaped full matches near input syllable length.
            if (input_syllables > 0) and ((text_units < input_syllables - 1) or (text_units > input_syllables + 1)) then
            begin
                Continue;
            end;

            if non_user_count >= c_head_only_full_non_user_limit then
            begin
                Continue;
            end;
            Inc(non_user_count);
            Dec(full_lookup_candidates[idx].score, c_head_only_full_non_user_penalty);
            SetLength(filtered, Length(filtered) + 1);
            filtered[High(filtered)] := full_lookup_candidates[idx];
        end;

        if Length(filtered) = 0 then
        begin
            Exit;
        end;

        candidates := merge_candidate_lists(candidates, filtered, 0);
    end;

    procedure merge_exact_long_full_lookup_candidates(var candidates: TncCandidateList;
        const pinyin_key: string);
    const
        c_exact_long_full_visible_bonus = 840;
    var
        exact_matches: TncCandidateList;
        lookup_results: TncCandidateList;
        input_syllables: Integer;
        text_units: Integer;
        idx: Integer;
        candidate_text: string;
    begin
        if (m_dictionary = nil) or (pinyin_key = '') or
            (not c_suppress_nonlexicon_complete_long_candidates) then
        begin
            Exit;
        end;

        input_syllables := get_input_syllable_count_for_text(pinyin_key);
        if input_syllables < 4 then
        begin
            Exit;
        end;

        if is_full_pinyin_key(pinyin_key) then
        begin
            if not dictionary_exact_lookup_cached(pinyin_key, lookup_results) then
            begin
                Exit;
            end;
        end
        else if not dictionary_lookup_cached(pinyin_key, lookup_results) then
        begin
            Exit;
        end;

        SetLength(exact_matches, 0);
        for idx := 0 to High(lookup_results) do
        begin
            candidate_text := Trim(lookup_results[idx].text);
            if (candidate_text = '') or (lookup_results[idx].comment <> '') then
            begin
                Continue;
            end;

            text_units := get_text_unit_count(candidate_text);
            if (text_units <> input_syllables) or (text_units < 2) then
            begin
                Continue;
            end;

            if (lookup_results[idx].source <> cs_user) and
                (not lookup_results[idx].has_dict_weight) then
            begin
                lookup_results[idx].has_dict_weight := True;
                lookup_results[idx].dict_weight := lookup_results[idx].score;
            end;
            Inc(lookup_results[idx].score, c_exact_long_full_visible_bonus);
            SetLength(exact_matches, Length(exact_matches) + 1);
            exact_matches[High(exact_matches)] := lookup_results[idx];
        end;

        if Length(exact_matches) = 0 then
        begin
            Exit;
        end;

        clear_candidate_comments(exact_matches);
        candidates := merge_candidate_lists(candidates, exact_matches, 0);
    end;

    procedure merge_long_sentence_exact_candidates(var candidates: TncCandidateList;
        const pinyin_key: string);
    const
        c_long_sentence_state_limit = 48;
        c_long_sentence_single_top_n = 1;
        c_long_sentence_multi_top_n = 3;
        c_long_sentence_complete_non_user_limit = 4;
        c_long_sentence_max_segment_len = 3;
        c_long_sentence_single_penalty = 120;
        c_long_sentence_multi_bonus = 260;
        c_long_sentence_completion_bonus = 420;
        c_long_sentence_continuation_bonus = 40;
        c_long_sentence_candidate_visible_bonus = 1320;
        c_long_sentence_top_exact_bonus = 220;
        c_long_sentence_exact_rank_step = 52;
        c_long_sentence_bridge_bonus_low = 120;
        c_long_sentence_bridge_bonus_mid = 220;
        c_long_sentence_bridge_bonus_high = 340;
        c_long_sentence_bridge_bonus_top = 520;
        c_long_sentence_phrase_query_latest_bonus = 420;
        c_long_sentence_single_query_latest_bonus = 180;
    var
        exact_states: TArray<TList<TncSegmentPathState>>;
        exact_dedup: TArray<TDictionary<string, Integer>>;
        exact_sorted_states: TArray<TncSegmentPathState>;
        exact_bridge_bonus_cache: TDictionary<string, Integer>;
        exact_syllables: TncPinyinParseResult;
        seed_prev_prev_text: string;
        seed_prev_text: string;
        exact_state: TncSegmentPathState;
        exact_new_state: TncSegmentPathState;
        exact_existing_state: TncSegmentPathState;
        exact_lookup_results: TncCandidateList;
        exact_matches: TncCandidateList;
        exact_candidate: TncCandidate;
        exact_segment_text: string;
        exact_candidate_text: string;
        exact_key: string;
        exact_state_pos: Integer;
        exact_segment_len: Integer;
        exact_next_pos: Integer;
        exact_state_index: Integer;
        exact_candidate_index: Integer;
        exact_existing_state_index: Integer;
        exact_keep_count: Integer;
        exact_non_user_added: Integer;
        exact_candidate_limit: Integer;
        exact_units: Integer;
        exact_segment_count: Integer;
        exact_multi_char_segment_count: Integer;
        exact_effective_weight: Integer;
        exact_transition_bonus: Integer;
        exact_pair_bonus: Integer;
        exact_bridge_bonus: Integer;
        exact_rank_bonus: Integer;
        exact_path_bonus: Integer;
        exact_path_confidence: Integer;
        exact_idx: Integer;
        exact_debug_path: string;
        exact_is_preferred: Boolean;

        function merge_source_rank(const left: TncCandidateSource;
            const right: TncCandidateSource): TncCandidateSource;
        begin
            if (left = cs_user) or (right = cs_user) then
            begin
                Result := cs_user;
            end
            else
            begin
                Result := cs_rule;
            end;
        end;

        function build_state_key(const value: TncSegmentPathState): string;
        begin
            Result := LowerCase(Trim(value.text)) + #1 + LowerCase(Trim(value.prev_text)) +
                #1 + LowerCase(Trim(value.prev_pinyin_text)) + #1 +
                LowerCase(Trim(value.prev_prev_text)) + #1 +
                IntToStr(Ord(value.has_multi_segment));
        end;

        function get_encoded_path_segment_count_local(const encoded_path: string): Integer;
        var
            local_idx: Integer;
        begin
            Result := 0;
            if Trim(encoded_path) = '' then
            begin
                Exit;
            end;

            Result := 1;
            for local_idx := 1 to Length(encoded_path) do
            begin
                if encoded_path[local_idx] = c_segment_path_separator then
                begin
                    Inc(Result);
                end;
            end;
        end;

        function get_multi_char_segment_count(const encoded_path: string): Integer;
        var
            segment_parts: TArray<string>;
            part: string;
        begin
            Result := 0;
            if Trim(encoded_path) = '' then
            begin
                Exit;
            end;

            segment_parts := encoded_path.Split([c_segment_path_separator]);
            for part in segment_parts do
            begin
                if get_candidate_text_unit_count(Trim(part)) >= 2 then
                begin
                    Inc(Result);
                end;
            end;
        end;

        function is_long_sentence_allowed_single_char_text_local(const value: string): Boolean;
        begin
            Result := (value = '我') or (value = '你') or (value = '他') or (value = '她') or
                (value = '它') or (value = '们') or (value = '和') or (value = '跟') or
                (value = '与') or (value = '同') or (value = '去') or (value = '来') or
                (value = '在') or (value = '是') or (value = '有') or (value = '要') or
                (value = '想') or (value = '会') or (value = '能') or (value = '把') or
                (value = '被') or (value = '让') or (value = '给') or (value = '向') or
                (value = '到') or (value = '对') or (value = '从') or (value = '比') or
                (value = '就') or (value = '还') or (value = '再') or (value = '也') or
                (value = '都') or (value = '很') or (value = '不') or (value = '的') or
                (value = '了') or (value = '着') or (value = '过') or (value = '将') or
                (value = '为') or (value = '于') or (value = '中');
        end;

        function is_long_sentence_allowed_single_char_text_codepoint_local(
            const value: string): Boolean;
        begin
            Result := False;
            if Length(value) <> 1 then
            begin
                Exit;
            end;

            case Ord(value[1]) of
                $6211, $4F60, $4ED6, $5979, $5B83, $548C, $53BB, $6765, $5728,
                $662F, $6709, $8981, $60F3, $4F1A, $80FD, $628A, $88AB, $8BA9,
                $7ED9, $5411, $5BF9, $4E8E, $8DDF, $540C, $4ECE, $4E0E, $5C31,
                $4E5F, $90FD, $8FD8, $53C8, $518D, $4E0D, $5F88, $592A, $6700,
                $5DF2, $5C06, $5230, $7740, $8FC7, $4E86:
                    Result := True;
            end;
        end;

        function get_candidate_effective_weight_local(const local_candidate: TncCandidate): Integer;
        begin
            Result := local_candidate.score;
            if Result <= 0 then
            begin
                if local_candidate.has_dict_weight then
                begin
                    Result := local_candidate.dict_weight;
                end
                else
                begin
                    Result := 0;
                end;
            end
            else if local_candidate.has_dict_weight then
            begin
                Result := Max(Result, local_candidate.dict_weight div 2);
            end;
        end;

        function get_exact_phrase_bridge_bonus_local(const left_pinyin: string;
            const left_text: string; const right_pinyin: string;
            const right_text: string): Integer;
        var
            cache_key: string;
            combined_pinyin: string;
            combined_text: string;
            bridge_results: TncCandidateList;
            bridge_idx: Integer;
            bridge_effective_weight: Integer;
        begin
            Result := 0;
            if (Trim(left_pinyin) = '') or (Trim(left_text) = '') or
                (Trim(right_pinyin) = '') or (Trim(right_text) = '') then
            begin
                Exit;
            end;

            combined_pinyin := normalize_pinyin_text(left_pinyin + right_pinyin);
            combined_text := Trim(left_text) + Trim(right_text);
            if (combined_pinyin = '') or (combined_text = '') then
            begin
                Exit;
            end;

            cache_key := combined_pinyin + #1 + combined_text;
            if (exact_bridge_bonus_cache <> nil) and
                exact_bridge_bonus_cache.TryGetValue(cache_key, Result) then
            begin
                Exit;
            end;

            if dictionary_exact_lookup_cached(combined_pinyin, bridge_results) then
            begin
                for bridge_idx := 0 to High(bridge_results) do
                begin
                    if bridge_results[bridge_idx].comment <> '' then
                    begin
                        Continue;
                    end;
                    if not SameText(Trim(bridge_results[bridge_idx].text), combined_text) then
                    begin
                        Continue;
                    end;

                    if bridge_results[bridge_idx].source = cs_user then
                    begin
                        Result := c_long_sentence_bridge_bonus_top;
                    end
                    else
                    begin
                        bridge_effective_weight := get_candidate_effective_weight_local(
                            bridge_results[bridge_idx]);
                        if bridge_effective_weight >= 760 then
                        begin
                            Result := c_long_sentence_bridge_bonus_top;
                        end
                        else if bridge_effective_weight >= 560 then
                        begin
                            Result := c_long_sentence_bridge_bonus_high;
                        end
                        else if bridge_effective_weight >= 360 then
                        begin
                            Result := c_long_sentence_bridge_bonus_mid;
                        end
                        else
                        begin
                            Result := c_long_sentence_bridge_bonus_low;
                        end;
                    end;
                    Break;
                end;
            end;

            if exact_bridge_bonus_cache <> nil then
            begin
                exact_bridge_bonus_cache.AddOrSetValue(cache_key, Result);
            end;
        end;

        function get_exact_query_choice_bonus_local(const query_key: string;
            const candidate_text: string): Integer;
        const
            c_single_query_base = 44;
            c_single_query_step = 34;
            c_single_query_cap = 176;
            c_multi_query_base = 96;
            c_multi_query_step = 56;
            c_multi_query_cap = 980;
            c_query_recent_latest = 900;
            c_query_recent_top = 180;
            c_query_recent_mid = 96;
            c_query_recent_tail = 52;
        var
            key: string;
            count: Integer;
            last_seen_serial: Int64;
            recent_bonus: Integer;
            serial_gap: Int64;
            text_units: Integer;
        begin
            Result := 0;
            key := build_session_query_choice_key(normalize_pinyin_text(query_key), candidate_text);
            if (key = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            count := 0;
            last_seen_serial := 0;
            serial_gap := High(Int64);
            if (m_session_query_choice_counts <> nil) and
                m_session_query_choice_counts.TryGetValue(key, count) and (count > 0) then
            begin
                if (m_session_query_choice_last_seen <> nil) and
                    m_session_query_choice_last_seen.TryGetValue(key, last_seen_serial) and
                    (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
                begin
                    serial_gap := m_session_commit_serial - last_seen_serial;
                end;

                recent_bonus := 0;
                if serial_gap = 0 then
                begin
                    recent_bonus := c_query_recent_latest;
                end
                else if serial_gap <= 1 then
                begin
                    recent_bonus := c_query_recent_top;
                end
                else if serial_gap <= 3 then
                begin
                    recent_bonus := c_query_recent_mid;
                end
                else if serial_gap <= 6 then
                begin
                    recent_bonus := c_query_recent_tail;
                end;

                text_units := get_candidate_text_unit_count(Trim(candidate_text));
                if text_units <= 1 then
                begin
                    Result := c_single_query_base + ((count - 1) * c_single_query_step) +
                        (recent_bonus div 3);
                    if count >= 3 then
                    begin
                        Inc(Result, 18);
                    end;
                    if Result > c_single_query_cap then
                    begin
                        Result := c_single_query_cap;
                    end;
                end
                else
                begin
                    Result := c_multi_query_base + ((count - 1) * c_multi_query_step) +
                        recent_bonus;
                    if (count >= 2) and (serial_gap <= 2) then
                    begin
                        Inc(Result, 56);
                    end;
                    if (count >= 3) and (serial_gap <= 4) then
                    begin
                        Inc(Result, 32);
                    end;
                    if Result > c_multi_query_cap then
                    begin
                        Result := c_multi_query_cap;
                    end;
                end;
                Exit;
            end;

            if m_dictionary <> nil then
            begin
                Result := m_dictionary.get_query_choice_bonus(normalize_pinyin_text(query_key),
                    candidate_text);
            end;
        end;

        function is_exact_latest_query_choice_local(const query_key: string;
            const candidate_text: string): Boolean;
        var
            latest_text: string;
            normalized_query: string;
        begin
            Result := False;
            normalized_query := normalize_pinyin_text(query_key);
            if (normalized_query = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            latest_text := '';
            if (m_session_query_latest_text <> nil) and
                m_session_query_latest_text.TryGetValue(normalized_query, latest_text) then
            begin
                Result := SameText(Trim(candidate_text), Trim(latest_text));
                if Result then
                begin
                    Exit;
                end;
            end;

            if m_dictionary <> nil then
            begin
                latest_text := Trim(m_dictionary.get_query_latest_choice_text(normalized_query));
                Result := SameText(Trim(candidate_text), latest_text);
            end;
        end;

        function get_exact_context_pair_bonus(const left_text: string;
            const candidate_text: string): Integer;
        const
            c_segment_pair_context_cap = 520;
            c_segment_pair_bonus_scale = 75;
        var
            pair_key: string;
            local_bonus: Integer;
            persistent_bonus: Integer;
            secondary_bonus: Integer;
            count: Integer;
        begin
            Result := 0;
            if (left_text = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            local_bonus := 0;
            persistent_bonus := 0;
            if m_context_pairs <> nil then
            begin
                pair_key := left_text + #1 + candidate_text;
                if m_context_pairs.TryGetValue(pair_key, count) and (count > 0) then
                begin
                    local_bonus := count * c_context_score_bonus;
                    if local_bonus > c_context_score_bonus_max then
                    begin
                        local_bonus := c_context_score_bonus_max;
                    end;
                end;
            end;

            if m_dictionary <> nil then
            begin
                persistent_bonus := m_dictionary.get_context_bonus(left_text, candidate_text);
            end;

            if local_bonus >= persistent_bonus then
            begin
                Result := local_bonus;
                secondary_bonus := persistent_bonus;
            end
            else
            begin
                Result := persistent_bonus;
                secondary_bonus := local_bonus;
            end;

            if secondary_bonus > 0 then
            begin
                Inc(Result, secondary_bonus div 2);
            end;
            if Result > c_segment_pair_context_cap then
            begin
                Result := c_segment_pair_context_cap;
            end;
            Result := (Result * c_segment_pair_bonus_scale) div 100;
        end;

        function get_phrase_trigram_transition_bonus(const prev_prev_text: string;
            const prev_text: string; const candidate_text: string): Integer;
        const
            c_segment_trigram_step = 96;
            c_segment_trigram_cap = 300;
            c_segment_trigram_recent_top = 140;
            c_segment_trigram_recent_mid = 84;
            c_segment_trigram_recent_tail = 40;
        var
            trigram_key: string;
            trigram_count: Integer;
            last_seen_serial: Int64;
            serial_gap: Int64;
        begin
            Result := 0;
            if (prev_prev_text = '') or (prev_text = '') or (candidate_text = '') or
                (m_phrase_context_pairs = nil) then
            begin
                Exit;
            end;

            trigram_key := prev_prev_text + #2 + prev_text + #1 + candidate_text;
            if (not m_phrase_context_pairs.TryGetValue(trigram_key, trigram_count)) or
                (trigram_count <= 0) then
            begin
                Exit;
            end;

            Result := trigram_count * c_segment_trigram_step;
            if Result > c_segment_trigram_cap then
            begin
                Result := c_segment_trigram_cap;
            end;

            if (m_phrase_context_last_seen <> nil) and
                m_phrase_context_last_seen.TryGetValue(trigram_key, last_seen_serial) and
                (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
            begin
                serial_gap := m_session_commit_serial - last_seen_serial;
                if serial_gap <= 1 then
                begin
                    Inc(Result, c_segment_trigram_recent_top);
                end
                else if serial_gap <= 3 then
                begin
                    Inc(Result, c_segment_trigram_recent_mid);
                end
                else if serial_gap <= 6 then
                begin
                    Inc(Result, c_segment_trigram_recent_tail);
                end;
            end;
        end;

        function get_compound_prev_trigram_bonus(const combined_prev_text: string;
            const candidate_text: string): Integer;
        var
            combined_units: TArray<string>;
            split_idx: Integer;
            unit_idx: Integer;
            left_part: string;
            right_part: string;
            local_session_bonus: Integer;
            local_persistent_bonus: Integer;
            local_secondary_bonus: Integer;
            local_bonus: Integer;
        begin
            Result := 0;
            if (combined_prev_text = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            combined_units := split_text_units(combined_prev_text);
            if Length(combined_units) < 2 then
            begin
                Exit;
            end;

            for split_idx := 1 to High(combined_units) do
            begin
                left_part := '';
                for unit_idx := 0 to split_idx - 1 do
                begin
                    left_part := left_part + combined_units[unit_idx];
                end;

                right_part := '';
                for unit_idx := split_idx to High(combined_units) do
                begin
                    right_part := right_part + combined_units[unit_idx];
                end;

                if (left_part = '') or (right_part = '') then
                begin
                    Continue;
                end;

                local_session_bonus := get_phrase_trigram_transition_bonus(
                    left_part, right_part, candidate_text);
                local_persistent_bonus := 0;
                if m_dictionary <> nil then
                begin
                    local_persistent_bonus := m_dictionary.get_context_trigram_bonus(
                        left_part, right_part, candidate_text);
                end;

                if local_session_bonus >= local_persistent_bonus then
                begin
                    local_bonus := local_session_bonus;
                    local_secondary_bonus := local_persistent_bonus;
                end
                else
                begin
                    local_bonus := local_persistent_bonus;
                    local_secondary_bonus := local_session_bonus;
                end;

                if local_secondary_bonus > 0 then
                begin
                    Inc(local_bonus, local_secondary_bonus div 2);
                end;

                if local_bonus > Result then
                begin
                    Result := local_bonus;
                end;
            end;
        end;

        function get_path_transition_bonus(const prev_prev_text: string;
            const prev_text: string; const candidate_text: string): Integer;
        var
            pair_bonus: Integer;
            trigram_bonus: Integer;
            persistent_trigram_bonus: Integer;
            compound_prev_trigram_bonus: Integer;
            secondary_bonus: Integer;
        begin
            Result := 0;
            if (prev_text = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            pair_bonus := get_exact_context_pair_bonus(prev_text, candidate_text);
            trigram_bonus := get_phrase_trigram_transition_bonus(prev_prev_text, prev_text,
                candidate_text);
            persistent_trigram_bonus := 0;
            if (prev_prev_text <> '') and (m_dictionary <> nil) then
            begin
                persistent_trigram_bonus := m_dictionary.get_context_trigram_bonus(
                    prev_prev_text, prev_text, candidate_text);
            end;
            compound_prev_trigram_bonus := 0;
            if prev_prev_text = '' then
            begin
                compound_prev_trigram_bonus := get_compound_prev_trigram_bonus(
                    prev_text, candidate_text);
            end;

            if trigram_bonus >= persistent_trigram_bonus then
            begin
                Result := trigram_bonus;
                secondary_bonus := persistent_trigram_bonus;
            end
            else
            begin
                Result := persistent_trigram_bonus;
                secondary_bonus := trigram_bonus;
            end;

            if secondary_bonus > 0 then
            begin
                Inc(Result, secondary_bonus div 2);
            end;
            if compound_prev_trigram_bonus > Result then
            begin
                Result := compound_prev_trigram_bonus;
            end;

            if Result > 0 then
            begin
                Inc(Result, pair_bonus div 2);
            end
            else
            begin
                Result := pair_bonus;
            end;
        end;

        function compare_state(const left: TncSegmentPathState; const right: TncSegmentPathState): Integer;
        var
            left_segment_count: Integer;
            right_segment_count: Integer;
            text_compare: Integer;
        begin
            if left.score <> right.score then
            begin
                Result := right.score - left.score;
                Exit;
            end;

            if left.path_confidence_score <> right.path_confidence_score then
            begin
                Result := right.path_confidence_score - left.path_confidence_score;
                Exit;
            end;

            left_segment_count := get_encoded_path_segment_count_local(left.path_text);
            right_segment_count := get_encoded_path_segment_count_local(right.path_text);
            if left_segment_count <> right_segment_count then
            begin
                Result := left_segment_count - right_segment_count;
                Exit;
            end;

            if left.source <> right.source then
            begin
                if left.source = cs_user then
                begin
                    Exit(-1);
                end;
                if right.source = cs_user then
                begin
                    Exit(1);
                end;
            end;

            text_compare := CompareText(left.text, right.text);
            if text_compare <> 0 then
            begin
                Result := text_compare;
                Exit;
            end;

            Result := CompareText(left.path_text, right.path_text);
        end;

        procedure sort_state_array(var values: TArray<TncSegmentPathState>);
        var
            left_idx: Integer;
            right_idx: Integer;
            temp_state: TncSegmentPathState;
        begin
            if Length(values) <= 1 then
            begin
                Exit;
            end;

            for left_idx := 0 to High(values) - 1 do
            begin
                for right_idx := left_idx + 1 to High(values) do
                begin
                    if compare_state(values[left_idx], values[right_idx]) > 0 then
                    begin
                        temp_state := values[left_idx];
                        values[left_idx] := values[right_idx];
                        values[right_idx] := temp_state;
                    end;
                end;
            end;
        end;

        procedure append_exact_state(const position: Integer; const value: TncSegmentPathState);
        begin
            exact_key := build_state_key(value);
            if exact_dedup[position].TryGetValue(exact_key, exact_existing_state_index) then
            begin
                if (exact_existing_state_index >= 0) and
                    (exact_existing_state_index < exact_states[position].Count) then
                begin
                    exact_existing_state := exact_states[position][exact_existing_state_index];
                    if compare_state(value, exact_existing_state) < 0 then
                    begin
                        exact_existing_state := value;
                    end;
                    exact_existing_state.source := merge_source_rank(
                        exact_existing_state.source, value.source);
                    exact_states[position][exact_existing_state_index] := exact_existing_state;
                end;
                Exit;
            end;

            exact_states[position].Add(value);
            exact_dedup[position].Add(exact_key, exact_states[position].Count - 1);
        end;

        procedure trim_exact_state(const position: Integer);
        var
            idx: Integer;
        begin
            if exact_states[position].Count <= c_long_sentence_state_limit then
            begin
                Exit;
            end;

            SetLength(exact_sorted_states, exact_states[position].Count);
            for idx := 0 to exact_states[position].Count - 1 do
            begin
                exact_sorted_states[idx] := exact_states[position][idx];
            end;
            sort_state_array(exact_sorted_states);
            exact_keep_count := c_long_sentence_state_limit;

            exact_states[position].Clear;
            exact_dedup[position].Clear;
            for idx := 0 to exact_keep_count - 1 do
            begin
                exact_states[position].Add(exact_sorted_states[idx]);
                exact_dedup[position].Add(build_state_key(exact_sorted_states[idx]), idx);
            end;
        end;

    begin
        if (m_dictionary = nil) or (pinyin_key = '') or
            (not c_suppress_nonlexicon_complete_long_candidates) or
            (not is_full_pinyin_key(pinyin_key)) or
            all_initial_compact_query or has_internal_dangling_initial then
        begin
            Exit;
        end;

        exact_syllables := get_effective_compact_pinyin_syllables(pinyin_key,
            allow_relaxed_missing_apostrophe);
        if Length(exact_syllables) < c_long_sentence_head_only_bypass_min_syllables then
        begin
            Exit;
        end;

        exact_bridge_bonus_cache := TDictionary<string, Integer>.Create;
        SetLength(exact_states, Length(exact_syllables) + 1);
        SetLength(exact_dedup, Length(exact_syllables) + 1);
        try
            for exact_state_pos := 0 to High(exact_states) do
            begin
                exact_states[exact_state_pos] := TList<TncSegmentPathState>.Create;
                exact_dedup[exact_state_pos] := TDictionary<string, Integer>.Create;
            end;

            exact_state.text := '';
            exact_state.score := 0;
            exact_state.path_preference_score := 0;
            exact_state.path_confidence_score := 0;
            exact_state.source := cs_rule;
            exact_state.has_multi_segment := False;
            get_recent_path_context_seed(seed_prev_prev_text, seed_prev_text);
            exact_state.prev_prev_text := seed_prev_prev_text;
            exact_state.prev_text := seed_prev_text;
            exact_state.prev_pinyin_text := '';
            exact_state.path_text := '';
            exact_states[0].Add(exact_state);
            exact_dedup[0].Add(build_state_key(exact_state), 0);

            for exact_state_pos := 0 to High(exact_syllables) do
            begin
                if exact_states[exact_state_pos].Count = 0 then
                begin
                    Continue;
                end;

                for exact_segment_len := 1 to c_long_sentence_max_segment_len do
                begin
                    if (exact_state_pos = 0) and (exact_segment_len = 1) then
                    begin
                        Continue;
                    end;

                    exact_next_pos := exact_state_pos + exact_segment_len;
                    if exact_next_pos > Length(exact_syllables) then
                    begin
                        Break;
                    end;

                    exact_segment_text := '';
                    for exact_idx := exact_state_pos to exact_next_pos - 1 do
                    begin
                        exact_segment_text := exact_segment_text + exact_syllables[exact_idx].text;
                    end;
                    if exact_segment_text = '' then
                    begin
                        Continue;
                    end;

                    if exact_segment_len = 1 then
                    begin
                        if not dictionary_exact_lookup_cached(exact_segment_text,
                            exact_lookup_results) then
                        begin
                            Continue;
                        end;
                    end
                    else if exact_segment_len = 2 then
                    begin
                        if not dictionary_lookup_cached(exact_segment_text,
                            exact_lookup_results) then
                        begin
                            Continue;
                        end;
                    end
                    else if not dictionary_exact_lookup_cached(exact_segment_text,
                        exact_lookup_results) then
                    begin
                        Continue;
                    end;

                    if exact_segment_len = 1 then
                    begin
                        exact_candidate_limit := c_long_sentence_single_top_n;
                    end
                    else if exact_segment_len >= 3 then
                    begin
                        exact_candidate_limit := Max(2, c_long_sentence_multi_top_n - 1);
                    end
                    else
                    begin
                        exact_candidate_limit := c_long_sentence_multi_top_n;
                    end;

                    for exact_state_index := 0 to exact_states[exact_state_pos].Count - 1 do
                    begin
                        exact_state := exact_states[exact_state_pos][exact_state_index];
                        for exact_candidate_index := 0 to High(exact_lookup_results) do
                        begin
                            if exact_candidate_index >= exact_candidate_limit then
                            begin
                                Break;
                            end;

                            exact_candidate := exact_lookup_results[exact_candidate_index];
                            exact_candidate_text := Trim(exact_candidate.text);
                            if (exact_candidate.comment <> '') or (exact_candidate_text = '') then
                            begin
                                Continue;
                            end;

                            exact_units := get_candidate_text_unit_count(exact_candidate_text);
                            if exact_units <= 0 then
                            begin
                                Continue;
                            end;

                            if exact_segment_len = 1 then
                            begin
                                if (exact_units <> 1) or
                                    (not is_long_sentence_allowed_single_char_text_codepoint_local(
                                    exact_candidate_text)) or
                                    (not match_single_char_candidate_for_syllable(
                                    exact_syllables[exact_state_pos].text, exact_candidate_text,
                                    exact_is_preferred)) or
                                    (not exact_is_preferred) then
                                begin
                                    Continue;
                                end;
                            end
                            else
                            begin
                                if exact_units <> exact_segment_len then
                                begin
                                    Continue;
                                end;
                            end;

                            exact_new_state.text := exact_state.text + exact_candidate_text;
                            exact_new_state.score := exact_state.score;
                            exact_effective_weight := get_candidate_effective_weight_local(exact_candidate);
                            Inc(exact_new_state.score, exact_effective_weight);

                            exact_rank_bonus := c_long_sentence_top_exact_bonus -
                                (exact_candidate_index * c_long_sentence_exact_rank_step);
                            if exact_rank_bonus > 0 then
                            begin
                                Inc(exact_new_state.score, exact_rank_bonus);
                            end;

                            exact_path_bonus := get_exact_query_choice_bonus_local(
                                exact_segment_text, exact_candidate_text);
                            if exact_path_bonus <> 0 then
                            begin
                                Inc(exact_new_state.score, exact_path_bonus);
                            end;

                            if is_exact_latest_query_choice_local(exact_segment_text,
                                exact_candidate_text) then
                            begin
                                if exact_segment_len = 1 then
                                begin
                                    Inc(exact_new_state.score,
                                        c_long_sentence_single_query_latest_bonus);
                                end
                                else
                                begin
                                    Inc(exact_new_state.score,
                                        c_long_sentence_phrase_query_latest_bonus);
                                end;
                            end;

                            exact_transition_bonus := 0;
                            exact_pair_bonus := 0;
                            exact_bridge_bonus := 0;

                            if exact_state.prev_pinyin_text <> '' then
                            begin
                                exact_bridge_bonus := get_exact_phrase_bridge_bonus_local(
                                    exact_state.prev_pinyin_text, exact_state.prev_text,
                                    exact_segment_text, exact_candidate_text);
                                if exact_bridge_bonus <> 0 then
                                begin
                                    Inc(exact_new_state.score, exact_bridge_bonus);
                                end;
                            end;

                            if exact_segment_len = 1 then
                            begin
                                Dec(exact_new_state.score, c_long_sentence_single_penalty);
                            end
                            else
                            begin
                                Inc(exact_new_state.score,
                                    c_long_sentence_multi_bonus + (exact_segment_len * 24));
                            end;

                            if exact_next_pos = Length(exact_syllables) then
                            begin
                                Inc(exact_new_state.score, c_long_sentence_completion_bonus);
                            end
                            else
                            begin
                                Inc(exact_new_state.score, c_long_sentence_continuation_bonus);
                            end;

                            exact_new_state.source := merge_source_rank(exact_state.source,
                                exact_candidate.source);
                            exact_new_state.prev_prev_text := exact_state.prev_text;
                            exact_new_state.prev_text := exact_candidate_text;
                            exact_new_state.prev_pinyin_text := exact_segment_text;
                            exact_new_state.path_text := exact_state.path_text;
                            if exact_new_state.path_text <> '' then
                            begin
                                exact_new_state.path_text := exact_new_state.path_text +
                                    c_segment_path_separator;
                            end;
                            exact_new_state.path_text := exact_new_state.path_text +
                                exact_candidate_text;
                            exact_new_state.has_multi_segment :=
                                get_encoded_path_segment_count_local(exact_new_state.path_text) > 1;

                            exact_path_bonus := exact_transition_bonus + exact_pair_bonus +
                                exact_bridge_bonus + exact_rank_bonus;

                            exact_new_state.path_preference_score :=
                                exact_state.path_preference_score + exact_path_bonus;
                            exact_path_confidence := exact_new_state.path_preference_score;
                            if exact_path_confidence < 0 then
                            begin
                                exact_path_confidence := 0;
                            end;
                            exact_new_state.path_confidence_score := exact_path_confidence;
                            append_exact_state(exact_next_pos, exact_new_state);
                        end;
                    end;

                    trim_exact_state(exact_next_pos);
                end;

            end;
            if exact_states[Length(exact_syllables)].Count <= 0 then
            begin
                Exit;
            end;

            SetLength(exact_sorted_states, exact_states[Length(exact_syllables)].Count);
            for exact_state_pos := 0 to exact_states[Length(exact_syllables)].Count - 1 do
            begin
                exact_sorted_states[exact_state_pos] :=
                    exact_states[Length(exact_syllables)][exact_state_pos];
                exact_path_bonus := get_session_query_path_bonus(pinyin_key,
                    exact_sorted_states[exact_state_pos].path_text);
                if m_dictionary <> nil then
                begin
                    Inc(exact_path_bonus, m_dictionary.get_query_segment_path_bonus(pinyin_key,
                        exact_sorted_states[exact_state_pos].path_text));
                    Dec(exact_path_bonus, m_dictionary.get_query_segment_path_penalty(
                        pinyin_key, exact_sorted_states[exact_state_pos].path_text));
                end;
                Inc(exact_path_bonus, get_persistent_query_path_prefix_support(
                    exact_sorted_states[exact_state_pos].path_text));
                if exact_path_bonus <> 0 then
                begin
                    Inc(exact_sorted_states[exact_state_pos].score, exact_path_bonus);
                    Inc(exact_sorted_states[exact_state_pos].path_preference_score,
                        exact_path_bonus);
                    exact_path_confidence := exact_sorted_states[exact_state_pos].path_confidence_score +
                        exact_path_bonus;
                    if exact_path_confidence < 0 then
                    begin
                        exact_path_confidence := 0;
                    end;
                    exact_sorted_states[exact_state_pos].path_confidence_score :=
                        exact_path_confidence;
                end;
            end;
            sort_state_array(exact_sorted_states);

            SetLength(exact_matches, 0);
            exact_non_user_added := 0;
            for exact_state_pos := 0 to High(exact_sorted_states) do
            begin
                exact_state := exact_sorted_states[exact_state_pos];
                exact_segment_count := get_encoded_path_segment_count_local(exact_state.path_text);
                exact_multi_char_segment_count := get_multi_char_segment_count(exact_state.path_text);
                if (exact_segment_count <= 1) or
                    (get_candidate_text_unit_count(exact_state.text) <> Length(exact_syllables)) then
                begin
                    Continue;
                end;
                if (Length(exact_syllables) >= 8) and (exact_segment_count < 4) then
                begin
                    Continue;
                end;
                if exact_multi_char_segment_count < 3 then
                begin
                    Continue;
                end;
                if (exact_multi_char_segment_count * 2) < exact_segment_count then
                begin
                    Continue;
                end;
                if (exact_state.source <> cs_user) and
                    (exact_non_user_added >= c_long_sentence_complete_non_user_limit) then
                begin
                    Continue;
                end;

                SetLength(exact_matches, Length(exact_matches) + 1);
                exact_matches[High(exact_matches)].text := exact_state.text;
                exact_matches[High(exact_matches)].comment := '';
                exact_matches[High(exact_matches)].score :=
                    exact_state.score + c_long_sentence_candidate_visible_bonus;
                exact_matches[High(exact_matches)].source := exact_state.source;
                exact_matches[High(exact_matches)].has_dict_weight := False;
                exact_matches[High(exact_matches)].dict_weight := 0;
                remember_segment_path_for_candidate(exact_state.text, '',
                    exact_state.path_text, exact_matches[High(exact_matches)].score);
                if exact_state.source <> cs_user then
                begin
                    Inc(exact_non_user_added);
                end;
            end;

            if Length(exact_matches) > 0 then
            begin
                candidates := merge_candidate_lists(candidates, exact_matches, 0);
                if m_config.debug_mode then
                begin
                    exact_debug_path := get_segment_path_for_candidate(exact_matches[0]);
                    m_last_full_path_debug_info := Format(
                        ' longmerge=[n=%d top=%s path=%s]',
                        [Length(exact_matches), exact_matches[0].text,
                        Copy(exact_debug_path, 1, 120)]);
                end;
            end;
        finally
            exact_bridge_bonus_cache.Free;
            for exact_state_pos := 0 to High(exact_states) do
            begin
                if exact_states[exact_state_pos] <> nil then
                begin
                    exact_states[exact_state_pos].Free;
                end;
                if exact_dedup[exact_state_pos] <> nil then
                begin
                    exact_dedup[exact_state_pos].Free;
                end;
            end;
        end;
    end;

    function merge_incomplete_trailing_prefix_full_lookup_candidates(
        var candidates: TncCandidateList; const pinyin_key: string): Boolean;
    const
        c_incomplete_trailing_prefix_visible_bonus = 780;
    var
        effective_syllables: TncPinyinParseResult;
        lookup_results: TncCandidateList;
        exact_matches: TncCandidateList;
        probe_key: string;
        shortest_tail_probe_key: string;
        input_syllables: Integer;
        probe_syllables: Integer;
        text_units: Integer;
        candidate_text: string;
        last_syllable_text: string;
        tail_trim_chars: Integer;

        function has_exact_long_complete_candidate: Boolean;
        var
            candidate_idx: Integer;
        begin
            Result := False;
            for candidate_idx := 0 to High(candidates) do
            begin
                if candidates[candidate_idx].comment <> '' then
                begin
                    Continue;
                end;
                if get_candidate_text_unit_count(Trim(candidates[candidate_idx].text)) <>
                    input_syllables then
                begin
                    Continue;
                end;
                Exit(True);
            end;
        end;

        function is_extendable_trailing_prefix_local: Boolean;
        var
            suffix_ch: Char;
            extended_key: string;
        begin
            Result := False;
            for suffix_ch := 'a' to 'z' do
            begin
                extended_key := pinyin_key + suffix_ch;
                if get_effective_compact_pinyin_unit_count(extended_key) = input_syllables then
                begin
                    Exit(True);
                end;
            end;
        end;

        function try_merge_probe_key(const value: string): Boolean;
        var
            candidate_idx: Integer;
        begin
            Result := False;
            if value = '' then
            begin
                Exit;
            end;

            if not dictionary_exact_lookup_cached(value, lookup_results) then
            begin
                Exit;
            end;

            SetLength(exact_matches, 0);
            for candidate_idx := 0 to High(lookup_results) do
            begin
                candidate_text := Trim(lookup_results[candidate_idx].text);
                if (candidate_text = '') or (lookup_results[candidate_idx].comment <> '') then
                begin
                    Continue;
                end;

                text_units := get_text_unit_count(candidate_text);
                if (text_units <> input_syllables) or (text_units < 2) then
                begin
                    Continue;
                end;

                if (lookup_results[candidate_idx].source <> cs_user) and
                    (not lookup_results[candidate_idx].has_dict_weight) then
                begin
                    lookup_results[candidate_idx].has_dict_weight := True;
                    lookup_results[candidate_idx].dict_weight := lookup_results[candidate_idx].score;
                end;
                Inc(lookup_results[candidate_idx].score,
                    c_incomplete_trailing_prefix_visible_bonus);
                SetLength(exact_matches, Length(exact_matches) + 1);
                exact_matches[High(exact_matches)] := lookup_results[candidate_idx];
            end;

            if Length(exact_matches) = 0 then
            begin
                Exit;
            end;

            clear_candidate_comments(exact_matches);
            candidates := merge_candidate_lists(candidates, exact_matches, 0);
            Result := True;
        end;

        function try_merge_prefix_probe_key(const value: string): Boolean;
        var
            candidate_idx: Integer;
        begin
            Result := False;
            if value = '' then
            begin
                Exit;
            end;

            if not dictionary_prefix_lookup_cached(value, lookup_results) then
            begin
                Exit;
            end;

            SetLength(exact_matches, 0);
            for candidate_idx := 0 to High(lookup_results) do
            begin
                candidate_text := Trim(lookup_results[candidate_idx].text);
                if (candidate_text = '') or (lookup_results[candidate_idx].comment <> '') then
                begin
                    Continue;
                end;

                text_units := get_text_unit_count(candidate_text);
                if (text_units <> input_syllables) or (text_units < 2) then
                begin
                    Continue;
                end;

                if (lookup_results[candidate_idx].source <> cs_user) and
                    (not lookup_results[candidate_idx].has_dict_weight) then
                begin
                    lookup_results[candidate_idx].has_dict_weight := True;
                    lookup_results[candidate_idx].dict_weight := lookup_results[candidate_idx].score;
                end;
                Inc(lookup_results[candidate_idx].score,
                    c_incomplete_trailing_prefix_visible_bonus);
                SetLength(exact_matches, Length(exact_matches) + 1);
                exact_matches[High(exact_matches)] := lookup_results[candidate_idx];
            end;

            if Length(exact_matches) = 0 then
            begin
                Exit;
            end;

            clear_candidate_comments(exact_matches);
            candidates := merge_candidate_lists(candidates, exact_matches, 0);
            Result := True;
        end;
    begin
        Result := False;
        if (m_dictionary = nil) or (pinyin_key = '') or
            (not c_suppress_nonlexicon_complete_long_candidates) then
        begin
            Exit;
        end;

        effective_syllables := get_effective_compact_pinyin_syllables(pinyin_key);
        input_syllables := Length(effective_syllables);
        if input_syllables < 4 then
        begin
            Exit;
        end;
        if Length(effective_syllables) = 0 then
        begin
            Exit;
        end;

        last_syllable_text := Trim(effective_syllables[High(effective_syllables)].text);
        if (last_syllable_text = '') or (not is_extendable_trailing_prefix_local) then
        begin
            Exit;
        end;

        if has_exact_long_complete_candidate then
        begin
            Exit;
        end;

        if try_merge_prefix_probe_key(pinyin_key) then
        begin
            Exit(True);
        end;

        probe_key := pinyin_key;
        shortest_tail_probe_key := '';
        if Length(probe_key) > 1 then
        begin
            SetLength(probe_key, Length(probe_key) - 1);
            probe_syllables := get_effective_compact_pinyin_unit_count(probe_key);
            if probe_syllables = input_syllables then
            begin
                if try_merge_probe_key(probe_key) then
                begin
                    Exit(True);
                end;
            end;
        end;

        tail_trim_chars := Length(last_syllable_text) - 1;
        if tail_trim_chars <= 0 then
        begin
            Exit;
        end;

        if Length(pinyin_key) <= tail_trim_chars then
        begin
            Exit;
        end;

        shortest_tail_probe_key := Copy(pinyin_key, 1, Length(pinyin_key) - tail_trim_chars);
        if shortest_tail_probe_key = probe_key then
        begin
            Exit;
        end;

        probe_syllables := get_effective_compact_pinyin_unit_count(shortest_tail_probe_key);
        if probe_syllables <> input_syllables then
        begin
            Exit;
        end;

        Result := try_merge_probe_key(shortest_tail_probe_key);
    end;

    function try_build_best_single_char_chain(out out_candidate: TncCandidate): Boolean;
    const
        c_chain_min_syllables = 2;
        c_chain_bonus = 160;
        c_chain_penalty_per_syllable = 28;
    var
        syllables: TncPinyinParseResult;
        syllable_text: string;
        local_lookup: TncCandidateList;
        idx: Integer;
        candidate_idx: Integer;
        pass_idx: Integer;
        best_idx: Integer;
        best_rank: Integer;
        rank_score: Integer;
        chosen: TncCandidate;
        chain_text: string;
        total_score: Integer;
        syllable_count: Integer;
        prefer_common_single_char: Boolean;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;

        if m_dictionary = nil then
        begin
            Exit;
        end;

        syllables := get_effective_compact_pinyin_syllables(m_composition_text,
            allow_relaxed_missing_apostrophe);

        syllable_count := Length(syllables);
        if syllable_count < c_chain_min_syllables then
        begin
            Exit;
        end;

        chain_text := '';
        total_score := 0;
        for idx := 0 to syllable_count - 1 do
        begin
            syllable_text := syllables[idx].text;
            if syllable_text = '' then
            begin
                Exit;
            end;

            if not dictionary_lookup_cached(syllable_text, local_lookup) then
            begin
                Exit;
            end;

            for pass_idx := 0 to 1 do
            begin
                prefer_common_single_char := pass_idx = 0;
                best_idx := -1;
                best_rank := Low(Integer);
                for candidate_idx := 0 to High(local_lookup) do
                begin
                    chosen := local_lookup[candidate_idx];
                    if not is_single_text_unit(Trim(chosen.text)) then
                    begin
                        Continue;
                    end;
                    if prefer_common_single_char and
                        (not is_preferred_partial_single_char_candidate(chosen)) then
                    begin
                        Continue;
                    end;
                    if (not prefer_common_single_char) and
                        (not is_bmp_cjk_single_char_candidate(chosen)) then
                    begin
                        Continue;
                    end;

                    rank_score := chosen.score;
                    if chosen.source = cs_user then
                    begin
                        Inc(rank_score, c_user_score_bonus);
                    end;
                    if rank_score > best_rank then
                    begin
                        best_rank := rank_score;
                        best_idx := candidate_idx;
                    end;
                end;
                if best_idx >= 0 then
                begin
                    Break;
                end;
            end;

            if best_idx < 0 then
            begin
                Exit;
            end;

            chosen := local_lookup[best_idx];
            chain_text := chain_text + chosen.text;
            Inc(total_score, chosen.score);
        end;

        if chain_text = '' then
        begin
            Exit;
        end;

        out_candidate.text := chain_text;
        out_candidate.comment := '';
        out_candidate.source := cs_rule;
        out_candidate.score := ((total_score div syllable_count) * 2) + c_chain_bonus -
            (syllable_count * c_chain_penalty_per_syllable);
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;
        Result := True;
    end;

    function try_build_runtime_chain_candidate(out out_candidate: TncCandidate): Boolean;
    const
        c_runtime_phrase_bonus = 220;
        c_runtime_phrase_per_syllable = 24;
        c_runtime_phrase_friendly_bonus = 150;
        c_runtime_phrase_long_bonus = 80;
    begin
        Result := try_build_best_single_char_chain(out_candidate);
        if not Result then
        begin
            Exit;
        end;

        if get_text_unit_count(out_candidate.text) <> input_syllable_count then
        begin
            Result := False;
            Exit;
        end;

        Inc(out_candidate.score, c_runtime_phrase_bonus + (input_syllable_count * c_runtime_phrase_per_syllable));
        if input_syllable_count >= 3 then
        begin
            Inc(out_candidate.score, c_runtime_phrase_long_bonus);
        end;
        if is_runtime_constructed_phrase_friendly(out_candidate.text) then
        begin
            Inc(out_candidate.score, c_runtime_phrase_friendly_bonus);
        end;
        out_candidate.comment := '';
        out_candidate.source := cs_rule;
    end;

    function try_build_runtime_redup_candidate(out out_candidate: TncCandidate): Boolean;
    const
        c_runtime_redup_bonus = 420;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        local_lookup: TncCandidateList;
        idx: Integer;
        best_index: Integer;
        best_rank: Integer;
        rank_score: Integer;
        chosen: TncCandidate;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;

        if (not repeated_two_syllable_query) or (m_dictionary = nil) then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(lookup_text);
        finally
            parser.Free;
        end;

        if Length(syllables) <> 2 then
        begin
            Exit;
        end;

        if not dictionary_lookup_cached(syllables[0].text, local_lookup) then
        begin
            Exit;
        end;

        best_index := -1;
        best_rank := Low(Integer);
        for idx := 0 to High(local_lookup) do
        begin
            chosen := local_lookup[idx];
            if not is_single_text_unit(Trim(chosen.text)) then
            begin
                Continue;
            end;

            rank_score := chosen.score;
            if chosen.source = cs_user then
            begin
                Inc(rank_score, c_user_score_bonus);
            end;
            if is_preferred_partial_single_char_candidate(chosen) then
            begin
                Inc(rank_score, 80);
            end;
            if rank_score > best_rank then
            begin
                best_rank := rank_score;
                best_index := idx;
            end;
        end;

        if best_index < 0 then
        begin
            Exit;
        end;

        chosen := local_lookup[best_index];
        out_candidate.text := chosen.text + chosen.text;
        out_candidate.comment := '';
        out_candidate.score := (chosen.score * 2) + c_runtime_redup_bonus;
        out_candidate.source := cs_rule;
        Result := True;
    end;

    function try_build_runtime_common_pattern_candidate(out out_candidate: TncCandidate): Boolean;
    const
        c_runtime_common_pattern_bonus = 560;
        c_runtime_common_pattern_step = 40;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        expected_units: TArray<string>;
        local_lookup: TncCandidateList;
        chosen: TncCandidate;
        unit_idx: Integer;
        best_rank: Integer;
        total_score: Integer;

        function syllable_equals(const left_value: string; const right_value: string): Boolean;
        begin
            Result := SameText(left_value, right_value);
        end;

        function pick_expected_single_char(
            const syllable_text: string;
            const expected_text: string;
            out out_single: TncCandidate
        ): Boolean;
        var
            candidate_idx: Integer;
            rank_score: Integer;
        begin
            Result := False;
            out_single.text := '';
            out_single.comment := '';
            out_single.score := 0;
            out_single.source := cs_rule;
            out_single.has_dict_weight := False;
            out_single.dict_weight := 0;

            if (syllable_text = '') or (expected_text = '') then
            begin
                Exit;
            end;
            if not dictionary_lookup_cached(syllable_text, local_lookup) then
            begin
                Exit;
            end;

            best_rank := Low(Integer);
            for candidate_idx := 0 to High(local_lookup) do
            begin
                if Trim(local_lookup[candidate_idx].text) <> expected_text then
                begin
                    Continue;
                end;
                if not is_single_text_unit(expected_text) then
                begin
                    Continue;
                end;

                rank_score := local_lookup[candidate_idx].score;
                if local_lookup[candidate_idx].source = cs_user then
                begin
                    Inc(rank_score, c_user_score_bonus);
                end;
                if rank_score > best_rank then
                begin
                    best_rank := rank_score;
                    out_single := local_lookup[candidate_idx];
                    Result := True;
                end;
            end;
        end;

        function pick_best_single_char(
            const syllable_text: string;
            out out_single: TncCandidate
        ): Boolean;
        var
            candidate_idx: Integer;
            pass_idx: Integer;
            best_idx: Integer;
            rank_score: Integer;
            prefer_common_single_char: Boolean;
        begin
            Result := False;
            out_single.text := '';
            out_single.comment := '';
            out_single.score := 0;
            out_single.source := cs_rule;
            out_single.has_dict_weight := False;
            out_single.dict_weight := 0;

            if syllable_text = '' then
            begin
                Exit;
            end;
            if not dictionary_lookup_cached(syllable_text, local_lookup) then
            begin
                Exit;
            end;

            for pass_idx := 0 to 1 do
            begin
                prefer_common_single_char := pass_idx = 0;
                best_idx := -1;
                best_rank := Low(Integer);
                for candidate_idx := 0 to High(local_lookup) do
                begin
                    if not is_single_text_unit(Trim(local_lookup[candidate_idx].text)) then
                    begin
                        Continue;
                    end;
                    if prefer_common_single_char and
                        (not is_preferred_partial_single_char_candidate(local_lookup[candidate_idx])) then
                    begin
                        Continue;
                    end;
                    if (not prefer_common_single_char) and
                        (not is_bmp_cjk_single_char_candidate(local_lookup[candidate_idx])) then
                    begin
                        Continue;
                    end;

                    rank_score := local_lookup[candidate_idx].score;
                    if local_lookup[candidate_idx].source = cs_user then
                    begin
                        Inc(rank_score, c_user_score_bonus);
                    end;
                    if rank_score > best_rank then
                    begin
                        best_rank := rank_score;
                        best_idx := candidate_idx;
                    end;
                end;
                if best_idx >= 0 then
                begin
                    out_single := local_lookup[best_idx];
                    Exit(True);
                end;
            end;
        end;

        function pick_best_constructed_phrase_head_single_char(
            const syllable_text: string;
            out out_single: TncCandidate
        ): Boolean;
        var
            candidate_idx: Integer;
            pass_idx: Integer;
            best_idx: Integer;
            best_rank: Integer;
            rank_score: Integer;
            prefer_common_single_char: Boolean;
            prefer_non_user: Boolean;
        begin
            Result := False;
            out_single.text := '';
            out_single.comment := '';
            out_single.score := 0;
            out_single.source := cs_rule;
            out_single.has_dict_weight := False;
            out_single.dict_weight := 0;

            if syllable_text = '' then
            begin
                Exit;
            end;
            if not dictionary_lookup_cached(syllable_text, local_lookup) then
            begin
                Exit;
            end;

            for pass_idx := 0 to 3 do
            begin
                prefer_non_user := pass_idx < 2;
                prefer_common_single_char := (pass_idx mod 2) = 0;
                best_idx := -1;
                best_rank := Low(Integer);
                for candidate_idx := 0 to High(local_lookup) do
                begin
                    if not is_single_text_unit(Trim(local_lookup[candidate_idx].text)) then
                    begin
                        Continue;
                    end;
                    if prefer_non_user and (local_lookup[candidate_idx].source = cs_user) then
                    begin
                        Continue;
                    end;
                    if prefer_common_single_char and
                        (not is_preferred_partial_single_char_candidate(local_lookup[candidate_idx])) then
                    begin
                        Continue;
                    end;
                    if (not prefer_common_single_char) and
                        (not is_bmp_cjk_single_char_candidate(local_lookup[candidate_idx])) then
                    begin
                        Continue;
                    end;

                    rank_score := local_lookup[candidate_idx].score;
                    if (not prefer_non_user) and (local_lookup[candidate_idx].source = cs_user) then
                    begin
                        Inc(rank_score, c_user_score_bonus);
                    end;
                    if rank_score > best_rank then
                    begin
                        best_rank := rank_score;
                        best_idx := candidate_idx;
                    end;
                end;
                if best_idx >= 0 then
                begin
                    out_single := local_lookup[best_idx];
                    Exit(True);
                end;
            end;
        end;

        function try_get_modal_particle_expected_text(
            const syllable_text: string;
            out out_text: string
        ): Boolean;
        begin
            out_text := '';
            if syllable_equals(syllable_text, 'ba') then
            begin
                out_text := string(Char($5427));
            end
            else if syllable_equals(syllable_text, 'ma') then
            begin
                out_text := string(Char($5417));
            end
            else if syllable_equals(syllable_text, 'ne') then
            begin
                out_text := string(Char($5462));
            end;
            Result := out_text <> '';
        end;

        function try_match_modal_particle_units(out out_units: TArray<string>): Boolean;
        var
            head_single: TncCandidate;
            particle_single: TncCandidate;
            particle_text: string;
        begin
            SetLength(out_units, 0);
            if Length(syllables) <> 2 then
            begin
                Exit(False);
            end;
            if not try_get_modal_particle_expected_text(syllables[1].text, particle_text) then
            begin
                Exit(False);
            end;
            if not pick_best_constructed_phrase_head_single_char(syllables[0].text, head_single) then
            begin
                Exit(False);
            end;
            if not pick_expected_single_char(syllables[1].text, particle_text, particle_single) then
            begin
                Exit(False);
            end;

            out_units := TArray<string>.Create(Trim(head_single.text), particle_text);
            Result := Length(out_units) = Length(syllables);
        end;

        function try_match_function_head_friendly_tail_units(out out_units: TArray<string>): Boolean;
        var
            head_text: string;
            head_single: TncCandidate;
            tail_single: TncCandidate;
        begin
            SetLength(out_units, 0);
            if Length(syllables) <> 2 then
            begin
                Exit(False);
            end;
            if not try_get_runtime_function_head_expected_text(syllables[0].text, head_text) then
            begin
                Exit(False);
            end;
            if not pick_expected_single_char(syllables[0].text, head_text, head_single) then
            begin
                Exit(False);
            end;
            if not pick_best_single_char(syllables[1].text, tail_single) then
            begin
                Exit(False);
            end;
            if not is_runtime_constructed_tail_friendly(tail_single.text) then
            begin
                Exit(False);
            end;

            out_units := TArray<string>.Create(head_text, Trim(tail_single.text));
            Result := Length(out_units) = Length(syllables);
        end;

        function try_match_expected_units(out out_units: TArray<string>): Boolean;
        var
            location_tail_text: string;
        begin
            SetLength(out_units, 0);
            if (Length(syllables) <> 2) and (Length(syllables) <> 3) then
            begin
                Exit(False);
            end;

            if try_match_function_head_friendly_tail_units(out_units) then
            begin
                Exit(True);
            end;

            if (Length(syllables) = 2) and
                (syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                try_get_interrogative_location_tail_expected_text(syllables[1].text, location_tail_text) then
            begin
                out_units := TArray<string>.Create(string(Char($54EA)), location_tail_text);
            end
            else if (Length(syllables) = 3) and syllable_equals(syllables[0].text, 'qu') and
                (syllable_equals(syllables[1].text, 'na') or syllable_equals(syllables[1].text, 'nei')) and
                try_get_interrogative_location_tail_expected_text(syllables[2].text, location_tail_text) then
            begin
                out_units := TArray<string>.Create(
                    string(Char($53BB)), string(Char($54EA)), location_tail_text);
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zhe') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and
                ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'ge')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'yi') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E00)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'liang') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E24)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'ji') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($51E0)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'mei') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($6BCF)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'san') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E09)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'si') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($56DB)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'wu') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E94)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'liu') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($516D)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'qi') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E03)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'ba') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($516B)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'jiu') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E5D)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'shi') and
                syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($5341)), string(Char($4E2A)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zhe') and
                syllable_equals(syllables[1].text, 'xie') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($4E9B)));
            end
            else if (Length(syllables) = 2) and
                ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'xie')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($4E9B)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'yi') and
                syllable_equals(syllables[1].text, 'xie') then
            begin
                out_units := TArray<string>.Create(string(Char($4E00)), string(Char($4E9B)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'yi') and
                syllable_equals(syllables[1].text, 'dian') then
            begin
                out_units := TArray<string>.Create(string(Char($4E00)), string(Char($70B9)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'yi') and
                syllable_equals(syllables[1].text, 'xia') then
            begin
                out_units := TArray<string>.Create(string(Char($4E00)), string(Char($4E0B)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zhe') and
                syllable_equals(syllables[1].text, 'yang') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($6837)));
            end
            else if (Length(syllables) = 2) and
                ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'yang')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($6837)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zhe') and
                syllable_equals(syllables[1].text, 'me') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($4E48)));
            end
            else if (Length(syllables) = 2) and
                ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'me')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($4E48)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zen') and
                syllable_equals(syllables[1].text, 'me') then
            begin
                out_units := TArray<string>.Create(string(Char($600E)), string(Char($4E48)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'you') and
                syllable_equals(syllables[1].text, 'dian') then
            begin
                out_units := TArray<string>.Create(string(Char($6709)), string(Char($70B9)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'shen') and
                syllable_equals(syllables[1].text, 'me') then
            begin
                out_units := TArray<string>.Create(string(Char($4EC0)), string(Char($4E48)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zhe') and
                syllable_equals(syllables[1].text, 'zhong') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($79CD)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'zhe') and
                syllable_equals(syllables[1].text, 'li') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($91CC)));
            end
            else if (Length(syllables) = 2) and syllable_equals(syllables[0].text, 'yi') and
                syllable_equals(syllables[1].text, 'hou') then
            begin
                out_units := TArray<string>.Create(string(Char($4EE5)), string(Char($540E)));
            end
            else if (Length(syllables) = 2) and
                ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'zhong')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($79CD)));
            end
            else if (Length(syllables) = 3) and syllable_equals(syllables[0].text, 'wei') and
                syllable_equals(syllables[1].text, 'shen') and syllable_equals(syllables[2].text, 'me') then
            begin
                out_units := TArray<string>.Create(
                    string(Char($4E3A)), string(Char($4EC0)), string(Char($4E48)));
            end
            else if (Length(syllables) = 3) and syllable_equals(syllables[0].text, 'zen') and
                syllable_equals(syllables[1].text, 'me') and syllable_equals(syllables[2].text, 'yang') then
            begin
                out_units := TArray<string>.Create(
                    string(Char($600E)), string(Char($4E48)), string(Char($6837)));
            end
            else
            begin
                Exit(False);
            end;

            Result := Length(out_units) = Length(syllables);
        end;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;

        if (m_dictionary = nil) or repeated_two_syllable_query then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(lookup_text);
        finally
            parser.Free;
        end;

        if not try_match_expected_units(expected_units) then
        begin
            if not try_match_modal_particle_units(expected_units) then
            begin
                Exit;
            end;
        end;

        total_score := 0;
        for unit_idx := 0 to High(expected_units) do
        begin
            if not pick_expected_single_char(syllables[unit_idx].text, expected_units[unit_idx], chosen) then
            begin
                Exit;
            end;

            out_candidate.text := out_candidate.text + expected_units[unit_idx];
            Inc(total_score, chosen.score);
        end;

        out_candidate.score := (total_score * 2) + c_runtime_common_pattern_bonus +
            (Length(expected_units) * c_runtime_common_pattern_step);
        out_candidate.comment := '';
        out_candidate.source := cs_rule;
        Result := True;
    end;

    function try_build_compact_interrogative_location_candidate(out out_candidate: TncCandidate): Boolean;
    const
        c_runtime_common_pattern_bonus = 560;
        c_runtime_common_pattern_step = 40;
    var
        expected_units: TArray<string>;
        expected_syllables: TArray<string>;
        local_lookup: TncCandidateList;
        chosen: TncCandidate;
        compact_unit_idx: Integer;
        best_rank_local: Integer;
        total_score: Integer;
        normalized_query: string;

        function try_pick_expected_single_char(const syllable_text: string;
            const expected_text: string; out out_single: TncCandidate): Boolean;
        var
            local_candidate_idx: Integer;
            local_rank_score: Integer;
        begin
            Result := False;
            out_single.text := '';
            out_single.comment := '';
            out_single.score := 0;
            out_single.source := cs_rule;
            out_single.has_dict_weight := False;
            out_single.dict_weight := 0;

            if (syllable_text = '') or (expected_text = '') then
            begin
                Exit;
            end;
            if not dictionary_lookup_cached(syllable_text, local_lookup) then
            begin
                Exit;
            end;

            best_rank_local := Low(Integer);
            for local_candidate_idx := 0 to High(local_lookup) do
            begin
                if Trim(local_lookup[local_candidate_idx].text) <> expected_text then
                begin
                    Continue;
                end;
                if not is_single_text_unit(expected_text) then
                begin
                    Continue;
                end;

                local_rank_score := local_lookup[local_candidate_idx].score;
                if local_lookup[local_candidate_idx].source = cs_user then
                begin
                    Inc(local_rank_score, c_user_score_bonus);
                end;
                if local_rank_score > best_rank_local then
                begin
                    best_rank_local := local_rank_score;
                    out_single := local_lookup[local_candidate_idx];
                    Result := True;
                end;
            end;
        end;

    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;

        if m_dictionary = nil then
        begin
            Exit;
        end;

        normalized_query := LowerCase(Trim(lookup_text));
        if normalized_query = 'ner' then
        begin
            expected_syllables := TArray<string>.Create('na', 'er');
            expected_units := TArray<string>.Create(string(Char($54EA)), string(Char($513F)));
        end
        else if normalized_query = 'naer' then
        begin
            expected_syllables := TArray<string>.Create('na', 'er');
            expected_units := TArray<string>.Create(string(Char($54EA)), string(Char($513F)));
        end
        else if normalized_query = 'qner' then
        begin
            expected_syllables := TArray<string>.Create('qu', 'na', 'er');
            expected_units := TArray<string>.Create(
                string(Char($53BB)), string(Char($54EA)), string(Char($513F)));
        end
        else if normalized_query = 'qunaer' then
        begin
            expected_syllables := TArray<string>.Create('qu', 'na', 'er');
            expected_units := TArray<string>.Create(
                string(Char($53BB)), string(Char($54EA)), string(Char($513F)));
        end
        else if normalized_query = 'nli' then
        begin
            expected_syllables := TArray<string>.Create('na', 'li');
            expected_units := TArray<string>.Create(string(Char($54EA)), string(Char($91CC)));
        end
        else if normalized_query = 'qnli' then
        begin
            expected_syllables := TArray<string>.Create('qu', 'na', 'li');
            expected_units := TArray<string>.Create(
                string(Char($53BB)), string(Char($54EA)), string(Char($91CC)));
        end
        else
        begin
            Exit;
        end;

        total_score := 0;
        for compact_unit_idx := 0 to High(expected_units) do
        begin
            if not try_pick_expected_single_char(expected_syllables[compact_unit_idx],
                expected_units[compact_unit_idx], chosen) then
            begin
                Exit(False);
            end;
            out_candidate.text := out_candidate.text + expected_units[compact_unit_idx];
            Inc(total_score, chosen.score);
        end;

        out_candidate.score := (total_score * 2) + c_runtime_common_pattern_bonus +
            (Length(expected_units) * c_runtime_common_pattern_step);
        out_candidate.comment := '';
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := True;
        out_candidate.dict_weight := total_score div Max(1, Length(expected_units));
        Result := True;
    end;

    procedure merge_runtime_constructed_candidates(var candidates: TncCandidateList;
        const allow_generic_chain: Boolean = True);
        function has_complete_bmp_cjk_phrase_candidate(const source_candidates: TncCandidateList): Boolean;
        var
            candidate_idx: Integer;
            units: TArray<string>;
            unit_idx: Integer;
            codepoint: Integer;
            valid_phrase: Boolean;
        begin
            Result := False;
            for candidate_idx := 0 to High(source_candidates) do
            begin
                if source_candidates[candidate_idx].comment <> '' then
                begin
                    Continue;
                end;

                units := split_text_units(Trim(source_candidates[candidate_idx].text));
                if Length(units) <> input_syllable_count then
                begin
                    Continue;
                end;
                if Length(units) < 2 then
                begin
                    Continue;
                end;

                valid_phrase := True;
                for unit_idx := 0 to High(units) do
                begin
                    if (not try_get_single_text_unit_codepoint(units[unit_idx], codepoint)) or
                        (codepoint < $4E00) or (codepoint > $9FFF) then
                    begin
                        valid_phrase := False;
                        Break;
                    end;
                end;

                if valid_phrase then
                begin
                    Result := True;
                    Exit;
                end;
            end;
        end;

        function has_weighted_complete_phrase_candidate(const source_candidates: TncCandidateList): Boolean;
        var
            candidate_idx: Integer;
            units: TArray<string>;
            unit_idx: Integer;
            codepoint: Integer;
            valid_phrase: Boolean;
        begin
            Result := False;
            for candidate_idx := 0 to High(source_candidates) do
            begin
                if (source_candidates[candidate_idx].comment <> '') or
                    (not source_candidates[candidate_idx].has_dict_weight) then
                begin
                    Continue;
                end;

                units := split_text_units(Trim(source_candidates[candidate_idx].text));
                if Length(units) <> input_syllable_count then
                begin
                    Continue;
                end;
                if Length(units) < 2 then
                begin
                    Continue;
                end;

                valid_phrase := True;
                for unit_idx := 0 to High(units) do
                begin
                    if (not try_get_single_text_unit_codepoint(units[unit_idx], codepoint)) or
                        (codepoint < $4E00) or (codepoint > $9FFF) then
                    begin
                        valid_phrase := False;
                        Break;
                    end;
                end;

                if valid_phrase then
                begin
                    Result := True;
                    Exit;
                end;
            end;
        end;

    var
        runtime_candidates: TncCandidateList;
        runtime_item: TncCandidate;
        runtime_count: Integer;
    begin
        runtime_phrase_added := False;
        runtime_redup_added := False;
        m_runtime_chain_text := '';
        m_runtime_common_pattern_text := '';
        m_runtime_redup_text := '';
        if (not has_multi_syllable_input) or (input_syllable_count < 2) or (input_syllable_count > 4) then
        begin
            Exit;
        end;

        // Multi-syllable complete candidates now come only from the lexicon,
        // user lexicon, or explicit preserved special forms handled outside
        // this generic runtime path. Keep only partial/path fallbacks for
        // 2+ syllable input and stop producing ad-hoc complete phrases here.
        Exit;

        runtime_count := 0;
        SetLength(runtime_candidates, 0);

        if allow_generic_chain and
            (input_syllable_count = 2) and
            (not has_complete_bmp_cjk_phrase_candidate(candidates)) and
            try_build_runtime_chain_candidate(runtime_item) then
        begin
            SetLength(runtime_candidates, runtime_count + 1);
            runtime_candidates[runtime_count] := runtime_item;
            Inc(runtime_count);
            runtime_phrase_added := True;
            m_runtime_chain_text := runtime_item.text;
        end;

        if (not has_weighted_complete_phrase_candidate(candidates)) and
            try_build_runtime_common_pattern_candidate(runtime_item) then
        begin
            SetLength(runtime_candidates, runtime_count + 1);
            runtime_candidates[runtime_count] := runtime_item;
            Inc(runtime_count);
            runtime_phrase_added := True;
            m_runtime_common_pattern_text := runtime_item.text;
        end;

        if try_build_runtime_redup_candidate(runtime_item) then
        begin
            SetLength(runtime_candidates, runtime_count + 1);
            runtime_candidates[runtime_count] := runtime_item;
            Inc(runtime_count);
            runtime_phrase_added := True;
            runtime_redup_added := True;
            m_runtime_redup_text := runtime_item.text;
        end;

        if runtime_count <= 0 then
        begin
            Exit;
        end;

        candidates := merge_candidate_lists(candidates, runtime_candidates, 0);
    end;

    procedure ensure_best_single_char_chain_visible(var candidates: TncCandidateList);
    var
        chain_candidate: TncCandidate;
        idx: Integer;
        chain_index: Integer;
        target_index: Integer;
        visible_limit: Integer;
    begin
        if not has_multi_syllable_input then
        begin
            Exit;
        end;

        if not try_build_best_single_char_chain(chain_candidate) then
        begin
            Exit;
        end;

        chain_index := -1;
        for idx := 0 to High(candidates) do
        begin
            if (candidates[idx].comment = '') and (candidates[idx].text = chain_candidate.text) then
            begin
                chain_index := idx;
                Break;
            end;
        end;

        if chain_index < 0 then
        begin
            SetLength(candidates, Length(candidates) + 1);
            candidates[High(candidates)] := chain_candidate;
        end;

        sort_candidates(candidates);

        chain_index := -1;
        for idx := 0 to High(candidates) do
        begin
            if (candidates[idx].comment = '') and (candidates[idx].text = chain_candidate.text) then
            begin
                chain_index := idx;
                Break;
            end;
        end;

        if chain_index < 0 then
        begin
            Exit;
        end;

        visible_limit := get_candidate_limit;
        if visible_limit <= 0 then
        begin
            Exit;
        end;

        if input_syllable_count <= 2 then
        begin
            if is_runtime_constructed_phrase_friendly(chain_candidate.text) then
            begin
                target_index := 2;
            end
            else
            begin
                target_index := 4;
            end;
        end
        else if input_syllable_count = 3 then
        begin
            target_index := 3;
        end
        else
        begin
            target_index := 2;
        end;
        if target_index >= visible_limit then
        begin
            target_index := visible_limit - 1;
        end;
        if target_index >= Length(candidates) then
        begin
            target_index := Length(candidates) - 1;
        end;
        if target_index < 0 then
        begin
            Exit;
        end;

        if chain_index > target_index then
        begin
            chain_candidate := candidates[chain_index];
            for idx := chain_index downto target_index + 1 do
            begin
                candidates[idx] := candidates[idx - 1];
            end;
            candidates[target_index] := chain_candidate;
        end;
    end;

    procedure ensure_single_char_partial_visible(var candidates: TncCandidateList; const visible_limit: Integer;
        const minimum_count: Integer);
    var
        idx: Integer;
        current_visible: Integer;
        need_count: Integer;
        partial_index: Integer;
        target_index: Integer;
        moved_count: Integer;
        partial_candidate: TncCandidate;
        scan_limit: Integer;
    begin
        if (minimum_count <= 0) or (visible_limit <= 0) or (Length(candidates) = 0) then
        begin
            Exit;
        end;

        scan_limit := visible_limit;
        if scan_limit > Length(candidates) then
        begin
            scan_limit := Length(candidates);
        end;

        current_visible := 0;
        for idx := 0 to scan_limit - 1 do
        begin
            if (candidates[idx].comment <> '') and is_single_text_unit(Trim(candidates[idx].text)) then
            begin
                Inc(current_visible);
            end;
        end;

        if current_visible >= minimum_count then
        begin
            Exit;
        end;

        if Length(candidates) <= visible_limit then
        begin
            Exit;
        end;

        need_count := minimum_count - current_visible;
        moved_count := 0;
        while moved_count < need_count do
        begin
            partial_index := -1;
            for idx := visible_limit to High(candidates) do
            begin
                if (candidates[idx].comment <> '') and is_single_text_unit(Trim(candidates[idx].text)) then
                begin
                    partial_index := idx;
                    Break;
                end;
            end;

            if partial_index < 0 then
            begin
                Break;
            end;

            target_index := visible_limit - moved_count - 1;
            if target_index < 0 then
            begin
                Break;
            end;

            partial_candidate := candidates[partial_index];
            for idx := partial_index downto target_index + 1 do
            begin
                candidates[idx] := candidates[idx - 1];
            end;
            candidates[target_index] := partial_candidate;
            Inc(moved_count);
        end;
    end;

    function try_get_single_char_candidate_for_pinyin_key_local(const pinyin_key: string;
        const text_value: string; out out_candidate: TncCandidate;
        out out_strength: Integer): Boolean;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
        normalized_text_value: string;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;
        out_strength := 0;
        normalized_text_value := Trim(text_value);
        if (Trim(pinyin_key) = '') or (normalized_text_value = '') then
        begin
            Exit;
        end;

        if not dictionary_lookup_cached(Trim(pinyin_key), local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units <> 1 then
            begin
                Continue;
            end;

            if Trim(local_results[local_idx].text) <> normalized_text_value then
            begin
                Continue;
            end;

            if local_results[local_idx].has_dict_weight then
            begin
                local_weight := local_results[local_idx].dict_weight;
            end
            else
            begin
                local_weight := local_results[local_idx].score;
            end;
            if local_weight > out_strength then
            begin
                out_candidate := local_results[local_idx];
                out_strength := local_weight;
                Result := True;
            end;
        end;
    end;

    function try_get_demonstrative_head_expected_text_local(const syllable_text: string;
        out out_text: string): Boolean;
    begin
        out_text := '';
        if SameText(syllable_text, 'zhe') then
        begin
            out_text := string(Char($8FD9));
        end
        else if SameText(syllable_text, 'na') or SameText(syllable_text, 'nei') then
        begin
            out_text := string(Char($90A3));
        end;
        Result := out_text <> '';
    end;

    function is_demonstrative_function_head_syllable_local(const syllable_text: string): Boolean;
    begin
        Result := SameText(syllable_text, 'zhe') or
            SameText(syllable_text, 'na') or
            SameText(syllable_text, 'nei');
    end;

    function try_get_demonstrative_tail_expected_text_local(const syllable_text: string;
        out out_text: string): Boolean;
    begin
        out_text := '';
        if SameText(syllable_text, 'ge') then
        begin
            out_text := string(Char($4E2A));
        end
        else if SameText(syllable_text, 'xie') then
        begin
            out_text := string(Char($4E9B));
        end
        else if SameText(syllable_text, 'zhong') then
        begin
            out_text := string(Char($79CD));
        end
        else if SameText(syllable_text, 'li') then
        begin
            out_text := string(Char($91CC));
        end
        else if SameText(syllable_text, 'yang') then
        begin
            out_text := string(Char($6837));
        end
        else if SameText(syllable_text, 'me') then
        begin
            out_text := string(Char($4E48));
        end
        else if SameText(syllable_text, 'ci') then
        begin
            out_text := string(Char($6B21));
        end
        else if SameText(syllable_text, 'hui') then
        begin
            out_text := string(Char($56DE));
        end
        else if SameText(syllable_text, 'lun') then
        begin
            out_text := string(Char($8F6E));
        end
        else if SameText(syllable_text, 'lei') then
        begin
            out_text := string(Char($7C7B));
        end
        else if SameText(syllable_text, 'bian') then
        begin
            out_text := string(Char($8FB9));
        end
        else if SameText(syllable_text, 'mian') then
        begin
            out_text := string(Char($9762));
        end
        else if SameText(syllable_text, 'yan') then
        begin
            out_text := string(Char($773C));
        end
        else if SameText(syllable_text, 'tian') then
        begin
            out_text := string(Char($5929));
        end
        else if SameText(syllable_text, 'nian') then
        begin
            out_text := string(Char($5E74));
        end
        else if SameText(syllable_text, 'yue') then
        begin
            out_text := string(Char($6708));
        end
        else if SameText(syllable_text, 'xia') then
        begin
            out_text := string(Char($4E0B));
        end
        else if SameText(syllable_text, 'sheng') then
        begin
            out_text := string(Char($58F0));
        end
        else if SameText(syllable_text, 'dian') then
        begin
            out_text := string(Char($70B9));
        end
        else if SameText(syllable_text, 'wei') then
        begin
            out_text := string(Char($4F4D));
        end;
        Result := out_text <> '';
    end;

    function is_demonstrative_head_friendly_remaining_local(
        const parsed_syllables: TncPinyinParseResult; const start_idx: Integer
    ): Boolean;
    var
        dummy_text: string;
    begin
        Result := False;
        if (start_idx < 0) or (start_idx > High(parsed_syllables)) then
        begin
            Exit;
        end;

        if try_get_demonstrative_tail_expected_text_local(
            parsed_syllables[start_idx].text, dummy_text) then
        begin
            Exit(True);
        end;

        if (start_idx < High(parsed_syllables)) and
            SameText(parsed_syllables[start_idx].text, 'yi') and
            try_get_demonstrative_tail_expected_text_local(
            parsed_syllables[start_idx + 1].text, dummy_text) then
        begin
            Exit(True);
        end;
    end;

    function try_get_preferred_demonstrative_head_single_char_local(
        const parsed_syllables: TncPinyinParseResult; const start_idx: Integer;
        out out_candidate: TncCandidate; out out_strength: Integer
    ): Boolean;
    var
        expected_head_text: string;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;
        out_strength := 0;

        if (Length(parsed_syllables) <= 0) or
            (start_idx <= 0) or (start_idx > High(parsed_syllables)) or
            (not is_demonstrative_function_head_syllable_local(parsed_syllables[0].text)) or
            (not is_demonstrative_head_friendly_remaining_local(parsed_syllables, start_idx)) or
            (not try_get_demonstrative_head_expected_text_local(
            parsed_syllables[0].text, expected_head_text)) then
        begin
            Exit;
        end;

        Result := try_get_single_char_candidate_for_pinyin_key_local(
            parsed_syllables[0].text, expected_head_text, out_candidate, out_strength);
    end;

    function get_demonstrative_head_partial_score_adjustment_local(
        const parsed_syllables: TncPinyinParseResult; const candidate_text: string;
        const start_idx: Integer
    ): Integer;
    const
        c_demonstrative_head_partial_bonus_single_tail_local = 760;
        c_demonstrative_head_partial_bonus_yi_bridge_local = 680;
        c_demonstrative_wrong_head_partial_penalty_local = 160;
    var
        expected_head_text: string;
        normalized_candidate_text: string;
    begin
        Result := 0;
        normalized_candidate_text := Trim(candidate_text);
        if (Length(parsed_syllables) <= 0) or
            (start_idx <= 0) or (start_idx > High(parsed_syllables)) or
            (normalized_candidate_text = '') or
            (not is_demonstrative_function_head_syllable_local(parsed_syllables[0].text)) or
            (not is_demonstrative_head_friendly_remaining_local(parsed_syllables, start_idx)) or
            (not try_get_demonstrative_head_expected_text_local(
            parsed_syllables[0].text, expected_head_text)) then
        begin
            Exit;
        end;

        if normalized_candidate_text = expected_head_text then
        begin
            if (start_idx < High(parsed_syllables)) and
                SameText(parsed_syllables[start_idx].text, 'yi') then
            begin
                Result := c_demonstrative_head_partial_bonus_yi_bridge_local;
            end
            else
            begin
                Result := c_demonstrative_head_partial_bonus_single_tail_local;
            end;
        end
        else if is_single_text_unit(normalized_candidate_text) then
        begin
            Result := -c_demonstrative_wrong_head_partial_penalty_local;
        end;
    end;

    procedure ensure_forced_single_char_partial(var candidates: TncCandidateList);
    const
        c_forced_partial_penalty_per_syllable = 120;
        c_forced_partial_prefix_bonus = 80;
        // Keep a broader single-char fallback pool so medium-rank common chars
        // (e.g. "鐠? under "shi") are not dropped too early.
        c_forced_partial_max_candidates = c_candidate_total_limit_max;
    var
        syllables: TncPinyinParseResult;
        first_syllable: string;
        remaining_pinyin: string;
        fallback_lookup: TncCandidateList;
        forced_list: TncCandidateList;
        forced_count: Integer;
        idx: Integer;
        pass_idx: Integer;
        source_item: TncCandidate;
        forced_item: TncCandidate;
        trailing_count: Integer;
        prefer_common_single_char: Boolean;
    begin
        if m_dictionary = nil then
        begin
            Exit;
        end;

        syllables := get_effective_compact_pinyin_syllables(m_composition_text,
            allow_relaxed_missing_apostrophe);

        if Length(syllables) <= 1 then
        begin
            Exit;
        end;

        first_syllable := syllables[0].text;
        if first_syllable = '' then
        begin
            Exit;
        end;

        remaining_pinyin := '';
        for idx := 1 to High(syllables) do
        begin
            remaining_pinyin := remaining_pinyin + syllables[idx].text;
        end;
        if remaining_pinyin = '' then
        begin
            Exit;
        end;

        if not dictionary_lookup_cached(first_syllable, fallback_lookup) then
        begin
            Exit;
        end;

        trailing_count := Length(syllables) - 1;
        SetLength(forced_list, 0);
        forced_count := 0;
        for pass_idx := 0 to 1 do
        begin
            prefer_common_single_char := pass_idx = 0;
            for idx := 0 to High(fallback_lookup) do
            begin
                source_item := fallback_lookup[idx];
                if not is_single_text_unit(Trim(source_item.text)) then
                begin
                    Continue;
                end;
                if not is_bmp_cjk_single_char_candidate(source_item) then
                begin
                    Continue;
                end;
                if prefer_common_single_char then
                begin
                    if not is_preferred_partial_single_char_candidate(source_item) then
                    begin
                        Continue;
                    end;
                end
                else if is_preferred_partial_single_char_candidate(source_item) then
                begin
                    Continue;
                end;

                forced_item := source_item;
                forced_item.comment := remaining_pinyin;
                forced_item.score := source_item.score + c_forced_partial_prefix_bonus -
                    (trailing_count * c_forced_partial_penalty_per_syllable);
                Inc(forced_item.score, get_demonstrative_head_partial_score_adjustment_local(
                    syllables, forced_item.text, 1));

                SetLength(forced_list, forced_count + 1);
                forced_list[forced_count] := forced_item;
                Inc(forced_count);
                if forced_count >= c_forced_partial_max_candidates then
                begin
                    Break;
                end;
            end;

            if forced_count >= c_forced_partial_max_candidates then
            begin
                Break;
            end;
        end;

        if forced_count <= 0 then
        begin
            Exit;
        end;

        candidates := merge_candidate_lists(candidates, forced_list, 0);
    end;

    function is_backward_attaching_boundary_unit_for_partial(const text_value: string): Boolean;
    var
        normalized_text_value: string;
    begin
        Result := False;
        normalized_text_value := Trim(text_value);
        if get_text_unit_count(normalized_text_value) <> 1 then
        begin
            Exit;
        end;

        Result :=
            (normalized_text_value = string(Char($4E2A))) or
            (normalized_text_value = string(Char($4F4D))) or
            (normalized_text_value = string(Char($6B21))) or
            (normalized_text_value = string(Char($70B9))) or
            (normalized_text_value = string(Char($4E9B))) or
            (normalized_text_value = string(Char($79CD))) or
            (normalized_text_value = string(Char($5929))) or
            (normalized_text_value = string(Char($5E74))) or
            (normalized_text_value = string(Char($6708))) or
            (normalized_text_value = string(Char($91CC))) or
            (normalized_text_value = string(Char($4E0B))) or
            (normalized_text_value = string(Char($56DE))) or
            (normalized_text_value = string(Char($904D))) or
            (normalized_text_value = string(Char($58F0))) or
            (normalized_text_value = string(Char($9762))) or
            (normalized_text_value = string(Char($773C))) or
            (normalized_text_value = string(Char($8FB9)));
    end;

    function is_quantity_like_prefix_for_boundary_unit_partial(const text_value: string): Boolean;
    var
        normalized_text_value: string;
    begin
        Result := False;
        normalized_text_value := Trim(text_value);
        if get_text_unit_count(normalized_text_value) <> 1 then
        begin
            Exit;
        end;

        Result :=
            (normalized_text_value = string(Char($4E00))) or
            (normalized_text_value = string(Char($4E8C))) or
            (normalized_text_value = string(Char($4E09))) or
            (normalized_text_value = string(Char($56DB))) or
            (normalized_text_value = string(Char($4E94))) or
            (normalized_text_value = string(Char($516D))) or
            (normalized_text_value = string(Char($4E03))) or
            (normalized_text_value = string(Char($516B))) or
            (normalized_text_value = string(Char($4E5D))) or
            (normalized_text_value = string(Char($5341))) or
            (normalized_text_value = string(Char($767E))) or
            (normalized_text_value = string(Char($5343))) or
            (normalized_text_value = string(Char($4E07))) or
            (normalized_text_value = string(Char($4E24))) or
            (normalized_text_value = string(Char($51E0))) or
            (normalized_text_value = string(Char($8FD9))) or
            (normalized_text_value = string(Char($90A3))) or
            (normalized_text_value = string(Char($54EA))) or
            (normalized_text_value = string(Char($6BCF))) or
            (normalized_text_value = string(Char($5404))) or
            (normalized_text_value = string(Char($534A))) or
            (normalized_text_value = string(Char($591A))) or
            (normalized_text_value = string(Char($6574))) or
            (normalized_text_value = string(Char($5355))) or
            (normalized_text_value = string(Char($53CC))) or
            (normalized_text_value = string(Char($4FE9))) or
            (normalized_text_value = string(Char($4EE8)));
    end;

    function count_single_char_partial_candidates(const candidates: TncCandidateList): Integer;
    var
        idx: Integer;
    begin
        Result := 0;
        for idx := 0 to High(candidates) do
        begin
            if (candidates[idx].comment <> '') and is_bmp_cjk_single_char_candidate(candidates[idx]) then
            begin
                Inc(Result);
            end;
        end;
    end;

    procedure filter_non_bmp_single_char_candidates(var candidates: TncCandidateList);
    var
        idx: Integer;
        out_idx: Integer;
        trimmed_text: string;
    begin
        out_idx := 0;
        for idx := 0 to High(candidates) do
        begin
            trimmed_text := Trim(candidates[idx].text);
            if (Length(trimmed_text) = 2) and
                (Ord(trimmed_text[1]) >= $D800) and (Ord(trimmed_text[1]) <= $DBFF) and
                (Ord(trimmed_text[2]) >= $DC00) and (Ord(trimmed_text[2]) <= $DFFF) then
            begin
                Continue;
            end;

            if out_idx <> idx then
            begin
                candidates[out_idx] := candidates[idx];
            end;
            Inc(out_idx);
        end;
        SetLength(candidates, out_idx);
    end;

    function try_build_primary_single_char_partial(out out_candidate: TncCandidate): Boolean;
    const
        c_forced_partial_penalty_per_syllable = 120;
        c_forced_partial_prefix_bonus = 80;
    var
        syllables: TncPinyinParseResult;
        first_syllable: string;
        remaining_pinyin: string;
        fallback_lookup: TncCandidateList;
        source_item: TncCandidate;
        idx: Integer;
        pass_idx: Integer;
        best_index: Integer;
        best_rank: Integer;
        rank_score: Integer;
        trailing_count: Integer;
        prefer_common_single_char: Boolean;
        preferred_item: TncCandidate;
        preferred_strength: Integer;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;

        if m_dictionary = nil then
        begin
            Exit;
        end;

        syllables := get_effective_compact_pinyin_syllables(m_composition_text);

        if Length(syllables) <= 1 then
        begin
            Exit;
        end;

        first_syllable := syllables[0].text;
        if first_syllable = '' then
        begin
            Exit;
        end;

        remaining_pinyin := '';
        for idx := 1 to High(syllables) do
        begin
            remaining_pinyin := remaining_pinyin + syllables[idx].text;
        end;
        if remaining_pinyin = '' then
        begin
            Exit;
        end;

        if not dictionary_lookup_cached(first_syllable, fallback_lookup) then
        begin
            Exit;
        end;

        if try_get_preferred_demonstrative_head_single_char_local(
            syllables, 1, preferred_item, preferred_strength) then
        begin
            trailing_count := Length(syllables) - 1;
            out_candidate := preferred_item;
            out_candidate.comment := remaining_pinyin;
            out_candidate.score := preferred_item.score + c_forced_partial_prefix_bonus -
                (trailing_count * c_forced_partial_penalty_per_syllable);
            Inc(out_candidate.score, get_demonstrative_head_partial_score_adjustment_local(
                syllables, out_candidate.text, 1));
            Exit(True);
        end;

        for pass_idx := 0 to 1 do
        begin
            prefer_common_single_char := pass_idx = 0;
            best_index := -1;
            best_rank := Low(Integer);
            for idx := 0 to High(fallback_lookup) do
            begin
                source_item := fallback_lookup[idx];
                if not is_single_text_unit(Trim(source_item.text)) then
                begin
                    Continue;
                end;
                if not is_bmp_cjk_single_char_candidate(source_item) then
                begin
                    Continue;
                end;
                if prefer_common_single_char and
                    (not is_preferred_partial_single_char_candidate(source_item)) then
                begin
                    Continue;
                end;

                rank_score := source_item.score;
                if source_item.source = cs_user then
                begin
                    Inc(rank_score, c_user_score_bonus);
                end;
                if rank_score > best_rank then
                begin
                    best_rank := rank_score;
                    best_index := idx;
                end;
            end;

            if best_index >= 0 then
            begin
                Break;
            end;
        end;

        if best_index < 0 then
        begin
            Exit;
        end;

        trailing_count := Length(syllables) - 1;
        out_candidate := fallback_lookup[best_index];
        out_candidate.comment := remaining_pinyin;
        out_candidate.score := fallback_lookup[best_index].score + c_forced_partial_prefix_bonus -
            (trailing_count * c_forced_partial_penalty_per_syllable);
        Inc(out_candidate.score, get_demonstrative_head_partial_score_adjustment_local(
            syllables, out_candidate.text, 1));
        Result := True;
    end;

    function try_build_phrase_anchored_single_char_partial(const candidates: TncCandidateList;
        out out_candidate: TncCandidate): Boolean;
    const
        c_phrase_anchor_follow_penalty = 48;
        c_phrase_anchor_redup_bonus = 4096;
        c_forced_partial_penalty_per_syllable = 120;
        c_forced_partial_prefix_bonus = 80;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        first_syllable: string;
        remaining_pinyin: string;
        fallback_lookup: TncCandidateList;
        visible_partials: TDictionary<string, Byte>;
        fallback_idx: Integer;
        candidate_idx: Integer;
        leading_units: TArray<string>;
        leading_text: string;
        source_item: TncCandidate;
        trailing_count: Integer;
        fallback_item: TncCandidate;
        best_source_item: TncCandidate;
        best_fallback_item: TncCandidate;
        preferred_item: TncCandidate;
        preferred_strength: Integer;
        anchor_rank: Integer;
        best_anchor_rank: Integer;
        has_redup_anchor: Boolean;
        visible_limit: Integer;
        best_anchor_uses_confirmed_boundary: Boolean;
        confirmed_boundary_support: Integer;
        boundary_unit_idx: Integer;
        best_boundary_unit_idx: Integer;
        best_boundary_unit_score: Integer;
        confirmed_prefix_tail_text: string;

        function try_get_confirmed_prefix_tail_text(out out_text: string): Boolean;
        var
            confirmed_units: TArray<string>;
        begin
            out_text := '';
            if is_single_text_unit(Trim(m_recent_partial_prefix_text)) then
            begin
                out_text := Trim(m_recent_partial_prefix_text);
                Exit(True);
            end;
            if (m_confirmed_segments <> nil) and (m_confirmed_segments.Count > 0) then
            begin
                out_text := Trim(m_confirmed_segments[m_confirmed_segments.Count - 1].text);
                if is_single_text_unit(out_text) then
                begin
                    Exit(True);
                end;
            end;

            if Trim(m_confirmed_text) = '' then
            begin
                Exit(False);
            end;

            confirmed_units := split_text_units(Trim(m_confirmed_text));
            if Length(confirmed_units) <= 0 then
            begin
                Exit(False);
            end;

            out_text := Trim(confirmed_units[High(confirmed_units)]);
            Result := is_single_text_unit(out_text);
        end;

        function get_confirmed_prefix_boundary_support(const leading_text: string): Integer;
        var
            prefix_lookup_key: string;
            prefix_lookup: TncCandidateList;
            prefix_idx: Integer;
            prefix_candidate: TncCandidate;
            prefix_units: TArray<string>;
            confirmed_segment: TncConfirmedSegment;
            best_match_score: Integer;
            confirmed_text_for_boundary: string;
        begin
            Result := 0;
            if not try_get_confirmed_prefix_tail_text(confirmed_text_for_boundary) then
            begin
                Exit;
            end;
            if not is_backward_attaching_boundary_unit_for_partial(leading_text) then
            begin
                Exit;
            end;

            if (m_confirmed_segments = nil) or (m_confirmed_segments.Count <= 0) then
            begin
                confirmed_segment.text := confirmed_text_for_boundary;
                confirmed_segment.pinyin := '';
            end
            else
            begin
                confirmed_segment := m_confirmed_segments[m_confirmed_segments.Count - 1];
            end;

            if (Trim(confirmed_segment.text) = '') or
                (not is_single_text_unit(Trim(confirmed_segment.text))) then
            begin
                Exit;
            end;

            prefix_lookup_key := normalize_pinyin_text(confirmed_segment.pinyin) + first_syllable;
            if (confirmed_segment.pinyin <> '') and (prefix_lookup_key = '') then
            begin
                Exit;
            end;

            if (confirmed_segment.pinyin <> '') and
                (not dictionary_lookup_cached(prefix_lookup_key, prefix_lookup)) then
            begin
                Exit;
            end;

            for prefix_idx := 0 to High(prefix_lookup) do
            begin
                prefix_candidate := prefix_lookup[prefix_idx];
                if prefix_candidate.comment <> '' then
                begin
                    Continue;
                end;
                prefix_units := split_text_units(Trim(prefix_candidate.text));
                if Length(prefix_units) <> 2 then
                begin
                    Continue;
                end;
                if (not SameText(prefix_units[0], Trim(confirmed_segment.text))) or
                    (not SameText(prefix_units[1], Trim(leading_text))) then
                begin
                    Continue;
                end;
                if (prefix_candidate.source <> cs_user) and (not prefix_candidate.has_dict_weight) then
                begin
                    Continue;
                end;

                best_match_score := prefix_candidate.score;
                if prefix_candidate.has_dict_weight and (prefix_candidate.dict_weight > best_match_score) then
                begin
                    best_match_score := prefix_candidate.dict_weight;
                end;
                if prefix_candidate.source = cs_user then
                begin
                    Inc(best_match_score, c_user_score_bonus);
                end;
                if best_match_score > Result then
                begin
                    Result := best_match_score;
                end;
            end;

            if Result >= 720 then
            begin
                Result := 520;
            end
            else if Result >= 560 then
            begin
                Result := 420;
            end
            else if Result >= 420 then
            begin
                Result := 320;
            end
            else if Result > 0 then
            begin
                Result := 220;
            end;

            if (Result <= 0) and
                is_quantity_like_prefix_for_boundary_unit_partial(confirmed_text_for_boundary) then
            begin
                Result := 260;
            end;
        end;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;
        confirmed_prefix_boundary_partial_preferred := False;

        if m_dictionary = nil then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            syllables := get_effective_compact_pinyin_syllables(m_composition_text);
        finally
            parser.Free;
        end;

        if Length(syllables) <= 1 then
        begin
            Exit;
        end;

        first_syllable := syllables[0].text;
        if first_syllable = '' then
        begin
            Exit;
        end;

        remaining_pinyin := '';
        for candidate_idx := 1 to High(syllables) do
        begin
            remaining_pinyin := remaining_pinyin + syllables[candidate_idx].text;
        end;
        if remaining_pinyin = '' then
        begin
            Exit;
        end;

        if not dictionary_lookup_cached(first_syllable, fallback_lookup) then
        begin
            Exit;
        end;

        trailing_count := Length(syllables) - 1;

        confirmed_prefix_tail_text := '';
        if try_get_confirmed_prefix_tail_text(confirmed_prefix_tail_text) and
            is_quantity_like_prefix_for_boundary_unit_partial(confirmed_prefix_tail_text) then
        begin
            best_boundary_unit_idx := -1;
            best_boundary_unit_score := Low(Integer);
            for boundary_unit_idx := 0 to High(fallback_lookup) do
            begin
                if (not is_bmp_cjk_single_char_candidate(fallback_lookup[boundary_unit_idx])) or
                    (not is_backward_attaching_boundary_unit_for_partial(
                    Trim(fallback_lookup[boundary_unit_idx].text))) then
                begin
                    Continue;
                end;

                if (best_boundary_unit_idx < 0) or
                    (fallback_lookup[boundary_unit_idx].score > best_boundary_unit_score) then
                begin
                    best_boundary_unit_idx := boundary_unit_idx;
                    best_boundary_unit_score := fallback_lookup[boundary_unit_idx].score;
                end;
            end;

            if best_boundary_unit_idx >= 0 then
            begin
                out_candidate := fallback_lookup[best_boundary_unit_idx];
                out_candidate.comment := remaining_pinyin;
                out_candidate.score := fallback_lookup[best_boundary_unit_idx].score +
                    c_forced_partial_prefix_bonus + 200;
                confirmed_prefix_boundary_partial_preferred := True;
                Result := True;
                Exit;
            end;
        end;

        visible_partials := TDictionary<string, Byte>.Create;
        try
            best_anchor_rank := Low(Integer);
            best_anchor_uses_confirmed_boundary := False;
            visible_limit := get_candidate_limit;
            if (visible_limit <= 0) or (visible_limit > Length(candidates)) then
            begin
                visible_limit := Length(candidates);
            end;
            for candidate_idx := 0 to visible_limit - 1 do
            begin
                if (candidates[candidate_idx].comment = remaining_pinyin) and
                    is_single_text_unit(Trim(candidates[candidate_idx].text)) then
                begin
                    visible_partials.AddOrSetValue(Trim(candidates[candidate_idx].text), 1);
                end;
            end;

            for candidate_idx := 0 to High(candidates) do
            begin
                source_item := candidates[candidate_idx];
                if source_item.comment <> '' then
                begin
                    Continue;
                end;
                leading_units := split_text_units(Trim(source_item.text));
                if Length(leading_units) < 2 then
                begin
                    Continue;
                end;

                leading_text := leading_units[0];
                if not is_single_text_unit(leading_text) then
                begin
                    Continue;
                end;
                confirmed_boundary_support := get_confirmed_prefix_boundary_support(leading_text);
                if visible_partials.ContainsKey(leading_text) and (confirmed_boundary_support <= 0) then
                begin
                    Continue;
                end;
                has_redup_anchor := repeated_two_syllable_query and
                    is_two_unit_redup_text(source_item.text);
                if (source_item.source <> cs_user) and
                    (not has_redup_anchor) and
                    (not is_runtime_chain_candidate(source_item)) and
                    (not is_runtime_common_pattern_candidate(source_item)) and
                    (not is_runtime_redup_candidate(source_item)) and
                    (confirmed_boundary_support <= 0) then
                begin
                    Continue;
                end;

                for fallback_idx := 0 to High(fallback_lookup) do
                begin
                    fallback_item := fallback_lookup[fallback_idx];
                    if not SameText(Trim(fallback_item.text), leading_text) then
                    begin
                        Continue;
                    end;
                    if not is_bmp_cjk_single_char_candidate(fallback_item) then
                    begin
                        Continue;
                    end;
                    anchor_rank := source_item.score;
                    if source_item.source = cs_user then
                    begin
                        Inc(anchor_rank, c_user_score_bonus);
                    end;
                    Inc(anchor_rank, confirmed_boundary_support);
                    if has_redup_anchor then
                    begin
                        Inc(anchor_rank, c_phrase_anchor_redup_bonus);
                    end;

                    if anchor_rank > best_anchor_rank then
                    begin
                        best_anchor_rank := anchor_rank;
                        best_anchor_uses_confirmed_boundary := confirmed_boundary_support > 0;
                        best_source_item := source_item;
                        best_fallback_item := fallback_item;
                    end;
                    Break;
                end;
            end;

            if best_anchor_rank <= Low(Integer) then
            begin
                Exit;
            end;

            out_candidate := best_fallback_item;
            if try_get_preferred_demonstrative_head_single_char_local(
                syllables, 1, preferred_item, preferred_strength) then
            begin
                out_candidate := preferred_item;
            end;
            out_candidate.comment := remaining_pinyin;
            out_candidate.score := Max(
                best_fallback_item.score + c_forced_partial_prefix_bonus -
                    (trailing_count * c_forced_partial_penalty_per_syllable),
                best_source_item.score - c_phrase_anchor_follow_penalty -
                    (trailing_count * c_forced_partial_penalty_per_syllable));
            Inc(out_candidate.score, get_demonstrative_head_partial_score_adjustment_local(
                syllables, out_candidate.text, 1));
            if best_anchor_uses_confirmed_boundary then
            begin
                Inc(out_candidate.score, 180);
                confirmed_prefix_boundary_partial_preferred := True;
            end;
            Result := True;
        finally
            visible_partials.Free;
        end;
    end;

    procedure ensure_hard_single_char_partial_visible(var candidates: TncCandidateList);
    var
        visible_limit: Integer;
        i: Integer;
        partial_index: Integer;
        target_index: Integer;
        partial_candidate: TncCandidate;
        phrase_anchored_candidate: TncCandidate;
        best_score: Integer;
        best_index: Integer;
        has_complete_phrase: Boolean;
    begin
        if not has_multi_syllable_input then
        begin
            Exit;
        end;

        has_complete_phrase := False;
        if input_syllable_count >= 3 then
        begin
            for i := 0 to High(candidates) do
            begin
                if (candidates[i].comment = '') and
                    (get_text_unit_count(Trim(candidates[i].text)) >= 2) then
                begin
                    has_complete_phrase := True;
                    Break;
                end;
            end;
        end;

        visible_limit := get_candidate_limit;
        if (visible_limit <= 0) or (Length(candidates) = 0) then
        begin
            Exit;
        end;

        if try_build_phrase_anchored_single_char_partial(candidates, phrase_anchored_candidate) then
        begin
            partial_index := -1;
            for i := 0 to High(candidates) do
            begin
                if (candidates[i].comment = phrase_anchored_candidate.comment) and
                    SameText(Trim(candidates[i].text), Trim(phrase_anchored_candidate.text)) then
                begin
                    partial_index := i;
                    Break;
                end;
            end;
            if partial_index < 0 then
            begin
                SetLength(candidates, Length(candidates) + 1);
                candidates[High(candidates)] := phrase_anchored_candidate;
                partial_index := High(candidates);
            end
            else
            begin
                candidates[partial_index] := phrase_anchored_candidate;
            end;
        end
        else
        begin
        best_index := -1;
        best_score := Low(Integer);
        for i := 0 to High(candidates) do
        begin
            if (candidates[i].comment <> '') and is_bmp_cjk_single_char_candidate(candidates[i]) then
            begin
                if (best_index < 0) or (candidates[i].score > best_score) then
                begin
                    best_index := i;
                    best_score := candidates[i].score;
                end;
            end;
        end;

        partial_index := best_index;
        if partial_index < 0 then
        begin
            if not try_build_primary_single_char_partial(partial_candidate) then
            begin
                Exit;
            end;

            SetLength(candidates, Length(candidates) + 1);
            candidates[High(candidates)] := partial_candidate;
            partial_index := High(candidates);
        end;

        if partial_index < 0 then
        begin
            Exit;
        end;
        end;

        // Keep a practical single-char continuation visible, but avoid occupying
        // the very front on longer queries where phrase intent is stronger.
        if confirmed_prefix_boundary_partial_preferred and (input_syllable_count = 2) then
        begin
            target_index := 0;
        end
        else if input_syllable_count >= 4 then
        begin
            target_index := 2;
        end
        else if input_syllable_count >= 3 then
        begin
            target_index := 4;
        end
        else
        begin
            target_index := 2;
        end;
        if (input_syllable_count >= 3) and (not has_complete_phrase) and (target_index > 2) then
        begin
            target_index := 2;
        end;
        if target_index >= visible_limit then
        begin
            target_index := visible_limit - 1;
        end;
        if target_index >= Length(candidates) then
        begin
            target_index := Length(candidates) - 1;
        end;
        if target_index < 0 then
        begin
            Exit;
        end;

        if partial_index > target_index then
        begin
            partial_candidate := candidates[partial_index];
            for i := partial_index downto target_index + 1 do
            begin
                candidates[i] := candidates[i - 1];
            end;
            candidates[target_index] := partial_candidate;
        end;
    end;

    procedure ensure_two_syllable_exact_phrase_precedes_matching_single_char_partial(
        var candidates: TncCandidateList);
    var
        idx: Integer;
        partial_index: Integer;
        exact_index: Integer;
        partial_text: string;
        exact_units: TArray<string>;
        exact_candidate: TncCandidate;
    begin
        if (input_syllable_count <> 2) or (Length(candidates) <= 1) then
        begin
            Exit;
        end;

        partial_index := -1;
        partial_text := '';
        for idx := 0 to High(candidates) do
        begin
            if (candidates[idx].comment <> '') and is_single_text_unit(Trim(candidates[idx].text)) then
            begin
                partial_index := idx;
                partial_text := Trim(candidates[idx].text);
                Break;
            end;
        end;
        if (partial_index < 0) or (partial_text = '') then
        begin
            Exit;
        end;

        exact_index := -1;
        for idx := 0 to High(candidates) do
        begin
            if (candidates[idx].comment <> '') or
                (not (candidates[idx].has_dict_weight or (candidates[idx].source = cs_user))) then
            begin
                Continue;
            end;

            exact_units := split_text_units(Trim(candidates[idx].text));
            if (Length(exact_units) < 2) or (exact_units[0] <> partial_text) then
            begin
                Continue;
            end;

            exact_index := idx;
            Break;
        end;

        if (exact_index < 0) or (exact_index < partial_index) then
        begin
            Exit;
        end;

        exact_candidate := candidates[exact_index];
        for idx := exact_index downto partial_index + 1 do
        begin
            candidates[idx] := candidates[idx - 1];
        end;
        candidates[partial_index] := exact_candidate;
    end;

    procedure apply_user_penalties(const pinyin_key: string; var candidates: TncCandidateList);
    var
        idx: Integer;
        penalty: Integer;
    begin
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit;
        end;

        for idx := 0 to High(candidates) do
        begin
            if candidates[idx].text = '' then
            begin
                Continue;
            end;

            penalty := m_dictionary.get_candidate_penalty(pinyin_key, candidates[idx].text);
            if penalty > 0 then
            begin
                Dec(candidates[idx].score, penalty);
            end;
        end;
    end;

    procedure merge_confirmed_prefix_user_extensions(var candidates: TncCandidateList);
    const
        c_confirmed_user_extension_bonus = 480;
    var
        normalized_current: string;
        confirmed_pinyin: string;
        full_query: string;
        full_candidates: TncCandidateList;
        confirmed_prefix_text: string;
        idx: Integer;
        seg_idx: Integer;
        existing_idx: Integer;
        candidate: TncCandidate;
        extension_text: string;
    begin
        if (m_dictionary = nil) or (m_composition_text = '') then
        begin
            Exit;
        end;
        if (m_confirmed_text = '') or (m_confirmed_segments = nil) or (m_confirmed_segments.Count = 0) then
        begin
            Exit;
        end;

        normalized_current := normalize_pinyin_text(m_composition_text);
        if normalized_current = '' then
        begin
            Exit;
        end;

        confirmed_pinyin := '';
        for seg_idx := 0 to m_confirmed_segments.Count - 1 do
        begin
            if m_confirmed_segments[seg_idx].pinyin <> '' then
            begin
                confirmed_pinyin := confirmed_pinyin + normalize_pinyin_text(m_confirmed_segments[seg_idx].pinyin);
            end;
        end;
        if confirmed_pinyin = '' then
        begin
            Exit;
        end;

        full_query := confirmed_pinyin + normalized_current;
        if not dictionary_lookup_cached(full_query, full_candidates) then
        begin
            Exit;
        end;
        if Length(full_candidates) = 0 then
        begin
            Exit;
        end;

        confirmed_prefix_text := m_confirmed_text;
        for idx := 0 to High(full_candidates) do
        begin
            candidate := full_candidates[idx];
            if candidate.source <> cs_user then
            begin
                Continue;
            end;

            if (candidate.text = '') or (Length(candidate.text) <= Length(confirmed_prefix_text)) then
            begin
                Continue;
            end;
            if Copy(candidate.text, 1, Length(confirmed_prefix_text)) <> confirmed_prefix_text then
            begin
                Continue;
            end;

            extension_text := Copy(candidate.text, Length(confirmed_prefix_text) + 1, Length(candidate.text));
            extension_text := Trim(extension_text);
            if extension_text = '' then
            begin
                Continue;
            end;

            existing_idx := -1;
            for seg_idx := 0 to High(candidates) do
            begin
                if SameText(candidates[seg_idx].text, extension_text) then
                begin
                    existing_idx := seg_idx;
                    Break;
                end;
            end;

            if existing_idx >= 0 then
            begin
                if candidates[existing_idx].comment <> '' then
                begin
                    candidates[existing_idx].comment := '';
                end;
                if candidates[existing_idx].score < candidate.score + c_confirmed_user_extension_bonus then
                begin
                    candidates[existing_idx].score := candidate.score + c_confirmed_user_extension_bonus;
                end;
                candidates[existing_idx].source := cs_user;
                candidates[existing_idx].has_dict_weight := False;
                candidates[existing_idx].dict_weight := 0;
            end
            else
            begin
                candidate.text := extension_text;
                candidate.comment := '';
                candidate.source := cs_user;
                candidate.has_dict_weight := False;
                candidate.dict_weight := 0;
                Inc(candidate.score, c_confirmed_user_extension_bonus);
                SetLength(candidates, Length(candidates) + 1);
                candidates[High(candidates)] := candidate;
            end;
        end;
    end;

    procedure prioritize_complete_phrase_matches(var candidates: TncCandidateList);
    const
        c_complete_phrase_bonus = 220;
        c_complete_phrase_unit_bonus = 36;
        c_partial_with_complete_penalty = 620;
        c_exact_length_bonus = 260;
        c_near_length_bonus = 80;
        c_exact_dict_complete_bonus = 220;
        c_near_dict_complete_bonus = 96;
        c_non_dict_complete_with_exact_dict_penalty = 160;
        c_partial_with_exact_dict_penalty = 120;
        c_short_complete_gap_penalty = 180;
        c_single_char_complete_penalty = 520;
        c_short_partial_penalty = 180;
        c_single_char_partial_penalty = 360;
    var
        idx: Integer;
        input_syllables: Integer;
        text_units: Integer;
        effective_units: Integer;
        has_complete_phrase: Boolean;
        has_exact_dict_complete: Boolean;
        has_near_dict_complete: Boolean;
        syllable_gap: Integer;
        function get_dict_complete_confidence_bonus(const candidate: TncCandidate): Integer;
        var
            dict_weight_value: Integer;
            candidate_units: Integer;
        begin
            Result := 0;
            if (not candidate.has_dict_weight) or (input_syllables < 3) then
            begin
                Exit;
            end;

            candidate_units := get_text_unit_count(Trim(candidate.text));
            if candidate_units < 3 then
            begin
                Exit;
            end;

            dict_weight_value := candidate.dict_weight;
            if candidate_units = input_syllables then
            begin
                if dict_weight_value >= 760 then
                begin
                    Result := 180;
                end
                else if dict_weight_value >= 620 then
                begin
                    Result := 128;
                end
                else if dict_weight_value >= 480 then
                begin
                    Result := 84;
                end
                else if dict_weight_value >= 360 then
                begin
                    Result := 40;
                end;
            end
            else if (input_syllables >= 4) and (candidate_units + 1 = input_syllables) then
            begin
                if dict_weight_value >= 720 then
                begin
                    Result := 72;
                end
                else if dict_weight_value >= 560 then
                begin
                    Result := 48;
                end
                else if dict_weight_value >= 420 then
                begin
                    Result := 24;
                end;
            end;
        end;
    begin
        if (not has_multi_syllable_input) or (Length(candidates) = 0) then
        begin
            Exit;
        end;

        input_syllables := get_input_syllable_count;
        if input_syllables < 2 then
        begin
            Exit;
        end;

        has_complete_phrase := False;
        has_exact_dict_complete := False;
        has_near_dict_complete := False;
        for idx := 0 to High(candidates) do
        begin
            if candidates[idx].comment <> '' then
            begin
                Continue;
            end;

            text_units := get_text_unit_count(Trim(candidates[idx].text));
            if text_units >= 2 then
            begin
                has_complete_phrase := True;
                if candidates[idx].has_dict_weight then
                begin
                    syllable_gap := input_syllables - text_units;
                    if syllable_gap = 0 then
                    begin
                        has_exact_dict_complete := True;
                    end
                    else if (input_syllables >= 4) and (syllable_gap = 1) then
                    begin
                        has_near_dict_complete := True;
                    end;
                end;
            end;
        end;

        if not has_complete_phrase then
        begin
            Exit;
        end;

        for idx := 0 to High(candidates) do
        begin
            text_units := get_text_unit_count(Trim(candidates[idx].text));
            if text_units <= 0 then
            begin
                Continue;
            end;

            if (candidates[idx].comment = '') and (text_units >= 2) then
            begin
                effective_units := text_units;
                if effective_units > input_syllables then
                begin
                    effective_units := input_syllables;
                end;
                Inc(candidates[idx].score,
                    c_complete_phrase_bonus + (effective_units * c_complete_phrase_unit_bonus));
                if input_syllables >= 3 then
                begin
                    syllable_gap := input_syllables - text_units;
                    if syllable_gap = 0 then
                    begin
                        Inc(candidates[idx].score, c_exact_length_bonus);
                    end
                    else if syllable_gap = 1 then
                    begin
                        Inc(candidates[idx].score, c_near_length_bonus);
                    end
                    else if syllable_gap > 1 then
                    begin
                        Dec(candidates[idx].score, syllable_gap * c_short_complete_gap_penalty);
                    end
                    else
                    begin
                        Dec(candidates[idx].score, Abs(syllable_gap) * (c_short_complete_gap_penalty div 2));
                    end;
                end;

                if input_syllables >= 3 then
                begin
                    if candidates[idx].has_dict_weight then
                    begin
                        if text_units = input_syllables then
                    begin
                        Inc(candidates[idx].score, c_exact_dict_complete_bonus);
                    end
                    else if (input_syllables >= 4) and (text_units + 1 = input_syllables) then
                    begin
                        Inc(candidates[idx].score, c_near_dict_complete_bonus);
                    end;
                    Inc(candidates[idx].score, get_dict_complete_confidence_bonus(candidates[idx]));
                end
                else if has_exact_dict_complete then
                begin
                    if text_units = input_syllables then
                    begin
                            Dec(candidates[idx].score, c_non_dict_complete_with_exact_dict_penalty);
                        end
                        else if (input_syllables >= 4) and (text_units + 1 = input_syllables) then
                        begin
                            Dec(candidates[idx].score,
                                c_non_dict_complete_with_exact_dict_penalty div 2);
                        end;
                    end
                    else if has_near_dict_complete and (input_syllables >= 4) and
                        (text_units + 1 >= input_syllables) then
                    begin
                        Dec(candidates[idx].score, c_near_dict_complete_bonus div 2);
                    end;
                end;
            end
            else if (candidates[idx].comment = '') and (input_syllables >= 3) and (text_units = 1) then
            begin
                Dec(candidates[idx].score, c_single_char_complete_penalty);
            end
            else if candidates[idx].comment <> '' then
            begin
                Dec(candidates[idx].score, c_partial_with_complete_penalty);
                if has_exact_dict_complete and (input_syllables >= 3) then
                begin
                    Dec(candidates[idx].score, c_partial_with_exact_dict_penalty);
                end;
                if input_syllables >= 3 then
                begin
                    if text_units <= 1 then
                    begin
                        Dec(candidates[idx].score, c_single_char_partial_penalty);
                    end
                    else if text_units + 1 < input_syllables then
                    begin
                        Dec(candidates[idx].score, c_short_partial_penalty);
                    end;
                end;
            end;
        end;
    end;

    procedure apply_syllable_single_char_alignment_bonus(var candidates: TncCandidateList);
    const
        c_rank_window = 10;
        c_rank_step = 10;
        c_missing_rank_penalty = 48;
        c_alignment_average_divisor = 1;
        c_alignment_adjust_cap = 120;
        c_alignment_score_gap_limit = 140;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        unit_rank_maps: TArray<TDictionary<string, Integer>>;
        lookup_results: TncCandidateList;
        candidate_units: TArray<string>;
        candidate_text: string;
        unit_text: string;
        syllable_idx: Integer;
        idx: Integer;
        rank_idx: Integer;
        found_rank: Integer;
        adjustment: Integer;
        rank_data_count: Integer;
        applied_count: Integer;
        top_complete_score: Integer;
        has_top_complete: Boolean;

        function is_valid_full_syllable(const syllable: string): Boolean;
        var
            ch: Char;
        begin
            Result := False;
            if syllable = '' then
            begin
                Exit;
            end;

            if Length(syllable) = 1 then
            begin
                Result := CharInSet(syllable[1], ['a', 'e', 'o']);
                Exit;
            end;

            for ch in syllable do
            begin
                if CharInSet(ch, ['a', 'e', 'i', 'o', 'u', 'v']) then
                begin
                    Result := True;
                    Exit;
                end;
            end;
        end;
    begin
        if (not has_multi_syllable_input) or (m_dictionary = nil) or (Length(candidates) = 0) then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            syllables := get_effective_compact_pinyin_syllables(m_composition_text);
        finally
            parser.Free;
        end;

        if Length(syllables) < 2 then
        begin
            Exit;
        end;
        if Length(syllables) > 2 then
        begin
            // Keep long phrases governed by phrase weight; use this only for
            // short same-pinyin disambiguation where common single-char choice matters.
            Exit;
        end;

        // Only apply this calibration to complete full-syllable queries.
        for idx := 0 to High(syllables) do
        begin
            if not is_valid_full_syllable(syllables[idx].text) then
            begin
                Exit;
            end;
        end;

        SetLength(unit_rank_maps, Length(syllables));
        try
            rank_data_count := 0;
            for syllable_idx := 0 to High(syllables) do
            begin
                unit_rank_maps[syllable_idx] := TDictionary<string, Integer>.Create;

                if not dictionary_lookup_cached(syllables[syllable_idx].text, lookup_results) then
                begin
                    unit_rank_maps[syllable_idx].Free;
                    unit_rank_maps[syllable_idx] := nil;
                    Continue;
                end;

                rank_idx := 0;
                for idx := 0 to High(lookup_results) do
                begin
                    unit_text := Trim(lookup_results[idx].text);
                    if not is_single_text_unit(unit_text) then
                    begin
                        Continue;
                    end;

                    if not unit_rank_maps[syllable_idx].ContainsKey(unit_text) then
                    begin
                        unit_rank_maps[syllable_idx].Add(unit_text, rank_idx);
                        Inc(rank_idx);
                        if rank_idx >= c_rank_window then
                        begin
                            Break;
                        end;
                    end;
                end;

                if unit_rank_maps[syllable_idx].Count = 0 then
                begin
                    unit_rank_maps[syllable_idx].Free;
                    unit_rank_maps[syllable_idx] := nil;
                    Continue;
                end;

                Inc(rank_data_count);
            end;

            if rank_data_count <= 0 then
            begin
                Exit;
            end;

            has_top_complete := False;
            top_complete_score := 0;
            for idx := 0 to High(candidates) do
            begin
                if candidates[idx].comment <> '' then
                begin
                    Continue;
                end;

                if (not has_top_complete) or (candidates[idx].score > top_complete_score) then
                begin
                    top_complete_score := candidates[idx].score;
                    has_top_complete := True;
                end;
            end;

            for idx := 0 to High(candidates) do
            begin
                if candidates[idx].comment <> '' then
                begin
                    Continue;
                end;
                if candidates[idx].source = cs_user then
                begin
                    Continue;
                end;
                if has_top_complete and
                    (candidates[idx].score < (top_complete_score - c_alignment_score_gap_limit)) then
                begin
                    // Keep lexical phrase weight as the primary signal; alignment only
                    // acts as a mild tie-breaker among near-head same-pinyin candidates.
                    Continue;
                end;

                candidate_text := Trim(candidates[idx].text);
                if candidate_text = '' then
                begin
                    Continue;
                end;

                candidate_units := split_text_units(candidate_text);
                if Length(candidate_units) <> Length(syllables) then
                begin
                    Continue;
                end;

                adjustment := 0;
                applied_count := 0;
                for syllable_idx := 0 to High(syllables) do
                begin
                    if unit_rank_maps[syllable_idx] = nil then
                    begin
                        Continue;
                    end;

                    Inc(applied_count);
                    if unit_rank_maps[syllable_idx].TryGetValue(candidate_units[syllable_idx], found_rank) then
                    begin
                        Inc(adjustment, (c_rank_window - found_rank) * c_rank_step);
                    end
                    else
                    begin
                        Dec(adjustment, c_missing_rank_penalty);
                    end;
                end;

                if applied_count <= 0 then
                begin
                    Continue;
                end;

                adjustment := adjustment div applied_count;
                adjustment := adjustment div c_alignment_average_divisor;
                if adjustment > c_alignment_adjust_cap then
                begin
                    adjustment := c_alignment_adjust_cap;
                end
                else if adjustment < -c_alignment_adjust_cap then
                begin
                    adjustment := -c_alignment_adjust_cap;
                end;

                Inc(candidates[idx].score, adjustment);
            end;
        finally
            for syllable_idx := 0 to High(unit_rank_maps) do
            begin
                if unit_rank_maps[syllable_idx] <> nil then
                begin
                    unit_rank_maps[syllable_idx].Free;
                end;
            end;
        end;
    end;
begin
    lookup_cache := TDictionary<string, TncCandidateList>.Create;
    try
        total_start_tick := GetTickCount64;
        lookup_cache_hits := 0;
        lookup_cache_misses := 0;
        lookup_elapsed_ms := 0;
        segment_elapsed_ms := 0;
        runtime_elapsed_ms := 0;
        post_elapsed_ms := 0;
        sort_elapsed_ms := 0;
        path_search_elapsed_ms := 0;
        SetLength(explicit_apostrophe_query_syllables, 0);
        explicit_apostrophe_query_parsed := False;
        SetLength(m_candidates, 0);
        confirmed_prefix_boundary_partial_preferred := False;
        m_last_lookup_key := '';
        m_last_lookup_normalized_from := '';
        m_last_lookup_syllable_count := 0;
        m_last_three_syllable_partial_preference_kind := 0;
        m_last_three_syllable_head_exact_text := '';
        m_last_three_syllable_head_strength := 0;
        m_last_three_syllable_tail_strength := 0;
        m_last_three_syllable_first_single_strength := 0;
        m_last_three_syllable_last_single_strength := 0;
        m_last_three_syllable_head_path_bonus := 0;
        m_last_three_syllable_tail_path_bonus := 0;
        m_last_three_syllable_partial_debug_info := '';
        m_last_full_path_debug_info := '';
        m_last_lookup_debug_extra := '';
        m_last_lookup_timing_info := '';
        m_runtime_chain_text := '';
        m_runtime_common_pattern_text := '';
        m_runtime_redup_text := '';
        clear_segment_path_tracking;
        clear_lookup_bonus_caches;
        if m_composition_text = '' then
        begin
            Exit;
        end;

        has_raw_candidates := False;
        has_segment_candidates := False;
        raw_from_dictionary := False;
        lookup_text := normalize_pinyin_text(m_composition_text);
        has_safe_trailing_initial_typing_state :=
            detect_safe_trailing_initial_typing_state(m_composition_text);
        if (not has_safe_trailing_initial_typing_state) and (not is_full_pinyin_key(lookup_text)) then
        begin
            normalized_lookup_text := normalize_adjacent_swap_typo(lookup_text);
            if (normalized_lookup_text <> '') and (not SameText(normalized_lookup_text, lookup_text)) then
            begin
                m_last_lookup_normalized_from := lookup_text;
                lookup_text := normalized_lookup_text;
            end;
        end;
        m_last_lookup_key := lookup_text;
        has_explicit_apostrophe_input := Pos('''', m_composition_text) > 0;
        fallback_comment := build_pinyin_comment(m_composition_text);
        if fallback_comment = '' then
        begin
            fallback_comment := build_pinyin_comment(lookup_text);
        end;
        allow_relaxed_missing_apostrophe := False;
        has_multi_syllable_input := fallback_comment <> '';
        relaxed_missing_apostrophe_comment := build_pinyin_comment(m_composition_text, True);
        if relaxed_missing_apostrophe_comment = '' then
        begin
            relaxed_missing_apostrophe_comment := build_pinyin_comment(lookup_text, True);
        end;
        has_relaxed_missing_apostrophe_partial :=
            (relaxed_missing_apostrophe_comment <> '') and
            (not SameText(relaxed_missing_apostrophe_comment, fallback_comment));
        has_relaxed_missing_apostrophe_boundary_shift := False;
        if has_relaxed_missing_apostrophe_partial then
        begin
            has_relaxed_missing_apostrophe_boundary_shift :=
                detect_relaxed_missing_apostrophe_boundary_shift(m_composition_text);
            if (not has_relaxed_missing_apostrophe_boundary_shift) and
                (lookup_text <> m_composition_text) then
            begin
                has_relaxed_missing_apostrophe_boundary_shift :=
                    detect_relaxed_missing_apostrophe_boundary_shift(lookup_text);
            end;
        end;
        has_internal_dangling_initial := detect_internal_dangling_initial(m_composition_text);
        if has_safe_trailing_initial_typing_state then
        begin
            has_internal_dangling_initial := False;
        end;
        all_initial_compact_query := detect_all_initial_compact_query(m_composition_text);
        if m_last_lookup_normalized_from <> '' then
        begin
            // If lookup key is typo-normalized (e.g. chagn->chang), segmenting by raw input
            // is usually noisy; force dangling-initial guard to suppress that path.
            if not has_safe_trailing_initial_typing_state then
            begin
                has_internal_dangling_initial := True;
            end;
        end;
        input_syllable_count := get_input_syllable_count_for_text(m_composition_text);
        if input_syllable_count <= 0 then
        begin
            input_syllable_count := get_input_syllable_count_for_text(lookup_text);
        end;
        if (m_last_lookup_normalized_from <> '') and (not has_safe_trailing_initial_typing_state) and
            is_full_pinyin_key(lookup_text) then
        begin
            // For malformed compact typos like "chagn" -> "chang", prefer the
            // normalized full-pinyin lookup intent over raw pseudo-segmentation.
            input_syllable_count := get_input_syllable_count_for_text(lookup_text);
            if input_syllable_count <= 1 then
            begin
                has_multi_syllable_input := False;
                fallback_comment := '';
                relaxed_missing_apostrophe_comment := '';
            end;
        end;
        m_last_lookup_syllable_count := input_syllable_count;
        repeated_two_syllable_query := is_repeated_two_syllable_query_text(lookup_text);
        single_char_partial_min_count := 1;
        if repeated_two_syllable_query then
        begin
            // For repeated two-syllable input like "shishi", keep extra single-char
            // continuation options visible to reduce phrase-only crowding.
            single_char_partial_min_count := 2;
        end;
        runtime_phrase_added := False;
        runtime_redup_added := False;
        raw_candidates_seeded_from_runtime_only := False;
        trailing_prefix_rescue_applied := False;
        SetLength(relaxed_segment_candidates, 0);
        SetLength(explicit_apostrophe_aligned_candidates, 0);
        head_only_multi_syllable := m_config.enable_segment_candidates and
            has_multi_syllable_input and
            (all_initial_compact_query or
                (m_config.segment_head_only_multi_syllable and
                    (not has_internal_dangling_initial) and
                    ((input_syllable_count < c_long_sentence_head_only_bypass_min_syllables) or
                    should_enable_long_sentence_full_path_search_local)));
        if m_dictionary <> nil then
        begin
            if head_only_multi_syllable then
            begin
                if build_segment_candidates_timed(segment_candidates, False) then
                begin
                    has_raw_candidates := True;
                    has_segment_candidates := True;
                    raw_candidates := segment_candidates;
                end;

                if has_relaxed_missing_apostrophe_partial and
                    has_relaxed_missing_apostrophe_boundary_shift and
                    build_segment_candidates_timed(relaxed_segment_candidates, False, True) then
                begin
                    has_raw_candidates := True;
                    has_segment_candidates := True;
                    if Length(raw_candidates) > 0 then
                    begin
                        raw_candidates := merge_candidate_lists(raw_candidates, relaxed_segment_candidates, 0);
                    end
                    else
                    begin
                        raw_candidates := relaxed_segment_candidates;
                    end;
                end;

                if has_raw_candidates then
                begin
                    merge_head_only_full_lookup_candidates(raw_candidates, lookup_text);
                end;
            end
            else if has_multi_syllable_input and
                merge_incomplete_trailing_prefix_full_lookup_candidates(raw_candidates,
                    lookup_text) then
            begin
                has_raw_candidates := True;
                raw_from_dictionary := True;
                trailing_prefix_rescue_applied := True;
            end
            else if dictionary_lookup_cached(lookup_text, raw_candidates) then
            begin
                has_raw_candidates := True;
                raw_from_dictionary := True;
            end
            else
            begin
                if has_relaxed_missing_apostrophe_partial and
                    ((not has_multi_syllable_input) or has_relaxed_missing_apostrophe_boundary_shift) then
                begin
                    fallback_comment := relaxed_missing_apostrophe_comment;
                    has_multi_syllable_input := True;
                    allow_relaxed_missing_apostrophe := True;
                    input_syllable_count := get_input_syllable_count_for_text(m_composition_text, True);
                    if input_syllable_count <= 1 then
                    begin
                        input_syllable_count := get_input_syllable_count_for_text(lookup_text, True);
                    end;
                    if input_syllable_count <= 1 then
                    begin
                        input_syllable_count := 2;
                    end;
                    m_last_lookup_syllable_count := input_syllable_count;
                end;

                SetLength(raw_candidates, 0);
                if has_multi_syllable_input and
                    merge_incomplete_trailing_prefix_full_lookup_candidates(raw_candidates,
                        lookup_text) then
                begin
                    has_raw_candidates := True;
                    raw_from_dictionary := True;
                    trailing_prefix_rescue_applied := True;
                end
                else if m_config.enable_segment_candidates and
                    build_segment_candidates_timed(segment_candidates,
                        (not all_initial_compact_query) and
                        ((not c_suppress_nonlexicon_complete_long_candidates) or
                        should_enable_long_sentence_full_path_search_local),
                        allow_relaxed_missing_apostrophe) then
                begin
                    has_raw_candidates := True;
                    has_segment_candidates := True;
                    raw_candidates := segment_candidates;
                end;
            end;
        end;

        if try_build_compact_interrogative_location_candidate(compact_runtime_candidate) then
        begin
            SetLength(compact_runtime_candidates, 1);
            compact_runtime_candidates[0] := compact_runtime_candidate;
            if has_raw_candidates then
            begin
                raw_candidates := merge_candidate_lists(raw_candidates, compact_runtime_candidates, 0);
            end
            else
            begin
                raw_candidates := compact_runtime_candidates;
                has_raw_candidates := True;
                raw_candidates_seeded_from_runtime_only := True;
            end;
            runtime_phrase_added := True;
            m_runtime_common_pattern_text := compact_runtime_candidate.text;
        end;

        if (not has_raw_candidates) and has_multi_syllable_input then
        begin
            SetLength(raw_candidates, 0);
            ensure_forced_single_char_partial(raw_candidates);
            phase_start_tick := GetTickCount64;
            merge_runtime_constructed_candidates(raw_candidates, False);
            Inc(runtime_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
            if Length(raw_candidates) > 0 then
            begin
                has_raw_candidates := True;
            end;
            if all_initial_compact_query and (Length(raw_candidates) > 0) then
            begin
                // All-initial queries already prefer lightweight prefix fallbacks.
            end
            else if (Length(raw_candidates) > 0) and (runtime_phrase_added or runtime_redup_added) then
            begin
                has_raw_candidates := True;
                raw_candidates_seeded_from_runtime_only := True;
            end;
        end;

        if has_raw_candidates then
        begin
            if raw_from_dictionary and has_explicit_apostrophe_input and (input_syllable_count > 1) then
            begin
                if m_config.enable_segment_candidates then
                begin
                    build_segment_candidates_timed(explicit_apostrophe_aligned_candidates,
                        (not c_suppress_nonlexicon_complete_long_candidates) or
                        should_enable_long_sentence_full_path_search_local);
                end;
                filter_complete_candidates_for_explicit_apostrophe_boundary(raw_candidates,
                    explicit_apostrophe_aligned_candidates);
                filter_short_dictionary_hits_for_explicit_apostrophe(raw_candidates,
                    input_syllable_count);
                has_raw_candidates := Length(raw_candidates) > 0;
            end;

            if not has_raw_candidates then
            begin
                raw_from_dictionary := False;
            end;

        if has_raw_candidates then
        begin
            if raw_from_dictionary then
            begin
                clear_candidate_comments(raw_candidates);
            end;

            sort_candidates_timed(raw_candidates);
            if raw_from_dictionary and has_relaxed_missing_apostrophe_partial and
                has_multi_char_dictionary_anchor(raw_candidates) then
            begin
                allow_relaxed_missing_apostrophe := True;
                ensure_forced_single_char_partial(raw_candidates);
                sort_candidates_timed(raw_candidates);
                ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
                ensure_single_char_partial_visible(raw_candidates, get_candidate_limit,
                    single_char_partial_min_count);
                allow_relaxed_missing_apostrophe := False;
            end;
            if m_config.enable_segment_candidates and raw_from_dictionary and
                (not has_internal_dangling_initial) and (not all_initial_compact_query) then
            begin
                if trailing_prefix_rescue_applied then
                begin
                    has_segment_candidates := False;
                end
                else if (input_syllable_count >= 4) and
                    has_complete_phrase_candidate_for_syllable_count(raw_candidates,
                        input_syllable_count) then
                begin
                    has_segment_candidates := False;
                end
                else if not has_segment_candidates then
                begin
                    // When exact lexicon hits already exist, keep the extra segment pass cheap.
                    // The current product strategy prefers direct lexicon matches and only needs
                    // lightweight partial/anchor assistance here, not a second full-path search.
                    if c_suppress_nonlexicon_complete_long_candidates and
                        (not should_enable_long_sentence_full_path_search_local) then
                    begin
                        has_segment_candidates := build_segment_candidates_timed(segment_candidates, False);
                    end
                    else
                    begin
                        has_segment_candidates := build_segment_candidates_timed(segment_candidates, True);
                    end;
                end;

                if has_segment_candidates then
                begin
                    raw_candidates := merge_candidate_lists(raw_candidates, segment_candidates, 0);
                    ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
                    ensure_single_char_partial_visible(raw_candidates, get_candidate_limit,
                        single_char_partial_min_count);
                    ensure_strong_two_plus_one_partial_visible(raw_candidates,
                        get_candidate_limit);
                end;
            end;
        end;

        // Even when segment candidates are disabled or fail to build, multi-syllable input
        // must keep a single-char partial fallback (e.g. "hai" + "budaxing").
        if has_multi_syllable_input then
        begin
            if not raw_candidates_seeded_from_runtime_only then
            begin
                ensure_forced_single_char_partial(raw_candidates);
                phase_start_tick := GetTickCount64;
                merge_runtime_constructed_candidates(raw_candidates);
                Inc(runtime_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
            end;
            if should_enable_long_sentence_full_path_search_local then
            begin
                phase_start_tick := GetTickCount64;
                merge_long_sentence_exact_candidates(raw_candidates, lookup_text);
                Inc(path_search_elapsed_ms, Int64(GetTickCount64 - phase_start_tick));
            end;
            filter_long_query_nonlexicon_complete_candidates(raw_candidates);
            merge_exact_long_full_lookup_candidates(raw_candidates, lookup_text);
            merge_incomplete_trailing_prefix_full_lookup_candidates(raw_candidates,
                lookup_text);
            if input_syllable_count >= c_long_sentence_full_path_min_syllables then
            begin
                sort_candidates_lightweight(raw_candidates);
            end
            else
            begin
                sort_candidates_timed(raw_candidates);
            end;
            ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
            ensure_single_char_partial_visible(raw_candidates, get_candidate_limit,
                single_char_partial_min_count);
            ensure_strong_two_plus_one_partial_visible(raw_candidates,
                get_candidate_limit);
            prefer_relaxed_missing_apostrophe_boundary_partial(raw_candidates);
        end;

        if has_explicit_apostrophe_input and (input_syllable_count > 1) then
        begin
            filter_explicit_apostrophe_single_char_complete_candidates(raw_candidates);
        end;
        filter_non_bmp_single_char_candidates(raw_candidates);

        limit := get_total_candidate_limit;
        if m_config.enable_segment_candidates then
        begin
            if get_candidate_limit * c_candidate_total_expand_factor > limit then
            begin
                limit := get_candidate_limit * c_candidate_total_expand_factor;
            end;
            if limit > c_candidate_total_limit_max then
            begin
                limit := c_candidate_total_limit_max;
            end;
        end;
        if raw_from_dictionary and has_multi_syllable_input then
        begin
            multi_syllable_cap_limit := get_candidate_limit * 3;
            if count_single_char_partial_candidates(raw_candidates) + get_candidate_limit >
                multi_syllable_cap_limit then
            begin
                multi_syllable_cap_limit :=
                    count_single_char_partial_candidates(raw_candidates) + get_candidate_limit;
            end;
            if multi_syllable_cap_limit > c_candidate_total_limit_max then
            begin
                multi_syllable_cap_limit := c_candidate_total_limit_max;
            end;
            if (multi_syllable_cap_limit > 0) and (limit > multi_syllable_cap_limit) then
            begin
                limit := multi_syllable_cap_limit;
            end;
        end;

        ensure_redup_complete_candidate_visible(raw_candidates, limit);

        if Length(raw_candidates) > limit then
        begin
            SetLength(m_candidates, limit);
            for i := 0 to limit - 1 do
            begin
                m_candidates[i] := raw_candidates[i];
            end
        end
        else
        begin
            m_candidates := raw_candidates;
        end;

        merge_confirmed_prefix_user_extensions(m_candidates);
        merge_exact_long_full_lookup_candidates(m_candidates, lookup_text);
        merge_incomplete_trailing_prefix_full_lookup_candidates(m_candidates,
            lookup_text);
        apply_user_penalties(lookup_text, m_candidates);
        prioritize_complete_phrase_matches(m_candidates);
        phase_start_tick := GetTickCount64;
        apply_syllable_single_char_alignment_bonus(m_candidates);
        note_post_phase_elapsed(phase_start_tick);
        sort_candidates_timed(m_candidates);
        if has_explicit_apostrophe_input and (input_syllable_count > 1) then
        begin
            filter_complete_candidates_for_explicit_apostrophe_boundary(m_candidates, m_candidates);
        end;
        ensure_partial_fallback_visible(m_candidates, get_candidate_limit);
        ensure_single_char_partial_visible(m_candidates, get_candidate_limit, single_char_partial_min_count);
        ensure_strong_two_plus_one_partial_visible(m_candidates, get_candidate_limit);
        ensure_redup_complete_candidate_visible(m_candidates, get_candidate_limit);
        ensure_hard_single_char_partial_visible(m_candidates);
        prefer_relaxed_missing_apostrophe_boundary_partial(m_candidates);
        ensure_two_syllable_exact_phrase_precedes_matching_single_char_partial(m_candidates);
        finalize_lookup_timing_info;
        if m_config.debug_mode then
        begin
            m_last_lookup_debug_extra := Format('multi=%d seg=%d dangling=%d head_only=%d runtime=%d redup=%d',
                [Ord(has_multi_syllable_input), Ord(has_segment_candidates), Ord(has_internal_dangling_initial),
                Ord(head_only_multi_syllable), Ord(runtime_phrase_added), Ord(runtime_redup_added)]) +
                Format(' allinit=%d', [Ord(all_initial_compact_query)]);
            if m_last_three_syllable_partial_preference_kind > 0 then
            begin
                m_last_lookup_debug_extra := m_last_lookup_debug_extra +
                    Format(' b3pref=%d', [m_last_three_syllable_partial_preference_kind]);
            end;
            if m_last_three_syllable_partial_debug_info <> '' then
            begin
                m_last_lookup_debug_extra := m_last_lookup_debug_extra +
                    m_last_three_syllable_partial_debug_info;
            end;
            if m_last_full_path_debug_info <> '' then
            begin
                m_last_lookup_debug_extra := m_last_lookup_debug_extra +
                    m_last_full_path_debug_info;
            end;
            if Length(m_candidates) > 0 then
            begin
                m_last_lookup_debug_extra := m_last_lookup_debug_extra + ' ' +
                    get_candidate_debug_summary(m_candidates[0]);
            end;
        end;
        refresh_candidate_segment_paths;
        note_ranked_top_candidate;
        m_page_index := 0;
        m_selected_index := 0;
        Exit;
    end;

        SetLength(m_candidates, 1);
        if m_composition_display_text <> '' then
        begin
            m_candidates[0].text := m_composition_display_text;
        end
        else
        begin
            m_candidates[0].text := m_composition_text;
        end;
        m_candidates[0].comment := fallback_comment;
        m_candidates[0].score := 0;
        m_candidates[0].source := cs_rule;
        m_candidates[0].has_dict_weight := False;
        m_candidates[0].dict_weight := 0;
        finalize_lookup_timing_info;
        if m_config.debug_mode then
        begin
            m_last_lookup_debug_extra := Format('multi=%d seg=0 dangling=%d head_only=%d runtime=%d redup=%d fallback=1',
                [Ord(has_multi_syllable_input), Ord(has_internal_dangling_initial), Ord(head_only_multi_syllable),
                Ord(runtime_phrase_added), Ord(runtime_redup_added)]) +
                Format(' allinit=%d', [Ord(all_initial_compact_query)]);
            if m_last_full_path_debug_info <> '' then
            begin
                m_last_lookup_debug_extra := m_last_lookup_debug_extra +
                    m_last_full_path_debug_info;
            end;
            if Length(m_candidates) > 0 then
            begin
                m_last_lookup_debug_extra := m_last_lookup_debug_extra + ' ' +
                    get_candidate_debug_summary(m_candidates[0]);
            end;
        end;
        refresh_candidate_segment_paths;
        note_ranked_top_candidate;
        m_page_index := 0;
        m_selected_index := 0;
    finally
        lookup_cache.Free;
    end;
end;

procedure TncEngine.normalize_page_and_selection;
var
    page_size: Integer;
    page_count: Integer;
    page_offset: Integer;
    page_items: Integer;
begin
    page_size := get_candidate_limit;
    page_count := get_page_count_internal(page_size);
    if page_count <= 0 then
    begin
        m_page_index := 0;
        m_selected_index := 0;
        Exit;
    end;

    if m_page_index < 0 then
    begin
        m_page_index := 0;
    end
    else if m_page_index >= page_count then
    begin
        m_page_index := page_count - 1;
    end;

    page_offset := m_page_index * page_size;
    page_items := Length(m_candidates) - page_offset;
    if page_items > page_size then
    begin
        page_items := page_size;
    end;

    if page_items <= 0 then
    begin
        m_selected_index := 0;
        Exit;
    end;

    if m_selected_index < 0 then
    begin
        m_selected_index := 0;
    end
    else if m_selected_index >= page_items then
    begin
        m_selected_index := page_items - 1;
    end;
end;

function TncEngine.get_source_rank(const source: TncCandidateSource): Integer;
begin
    case source of
        cs_user:
            Result := 0;
        cs_rule:
            Result := 1;
    else
        Result := 1;
    end;
end;

function TncEngine.get_context_variants(const context_text: string): TArray<string>;
var
    context_units: TArray<string>;
    seen: TDictionary<string, Boolean>;
    variant_text: string;
    idx: Integer;
    start_idx: Integer;
    min_start_idx: Integer;
begin
    SetLength(Result, 0);
    variant_text := Trim(context_text);
    if variant_text = '' then
    begin
        Exit;
    end;

    seen := TDictionary<string, Boolean>.Create;
    try
        SetLength(Result, 1);
        Result[0] := variant_text;
        seen.Add(variant_text, True);

        context_units := split_text_units(variant_text);
        if Length(context_units) <= 1 then
        begin
            Exit;
        end;

        min_start_idx := Length(context_units) - 4;
        if min_start_idx < 0 then
        begin
            min_start_idx := 0;
        end;

        for start_idx := min_start_idx to Length(context_units) - 1 do
        begin
            if start_idx < 0 then
            begin
                Continue;
            end;
            variant_text := '';
            for idx := start_idx to High(context_units) do
            begin
                variant_text := variant_text + context_units[idx];
            end;
            variant_text := Trim(variant_text);
            if (variant_text = '') or seen.ContainsKey(variant_text) then
            begin
                Continue;
            end;
            seen.Add(variant_text, True);
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := variant_text;
        end;
    finally
        seen.Free;
    end;
end;

function TncEngine.get_session_text_bonus(const candidate_text: string): Integer;
const
    c_multi_text_step = 110;
    c_multi_text_base = 70;
    c_multi_text_cap = 640;
    c_single_text_step = 48;
    c_single_text_base = 24;
    c_single_text_cap = 220;
    c_recent_phrase_bonus_top = 240;
    c_recent_phrase_bonus_mid = 150;
    c_recent_phrase_bonus_tail = 70;
    c_recent_single_bonus_top = 90;
    c_recent_single_bonus_mid = 56;
    c_recent_single_bonus_tail = 28;
var
    unit_count: Integer;
    count: Integer;
    last_seen_serial: Int64;
    serial_gap: Int64;
    recent_bonus: Integer;
    text_key: string;
begin
    text_key := Trim(candidate_text);
    if (text_key <> '') and (m_lookup_session_bonus_cache <> nil) and
        m_lookup_session_bonus_cache.TryGetValue(text_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if m_session_text_counts = nil then
    begin
        Exit;
    end;

    if (text_key = '') or (not m_session_text_counts.TryGetValue(text_key, count)) or
        (count <= 0) then
    begin
        Exit;
    end;

    unit_count := get_candidate_text_unit_count(text_key);
    last_seen_serial := 0;
    serial_gap := High(Int64);
    if (m_session_text_last_seen <> nil) and
        m_session_text_last_seen.TryGetValue(text_key, last_seen_serial) and
        (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
    begin
        serial_gap := m_session_commit_serial - last_seen_serial;
    end;

    if unit_count <= 1 then
    begin
        Result := c_single_text_base + ((count - 1) * c_single_text_step);
        recent_bonus := 0;
        if serial_gap <= 1 then
        begin
            recent_bonus := c_recent_single_bonus_top;
        end
        else if serial_gap <= 3 then
        begin
            recent_bonus := c_recent_single_bonus_mid;
        end
        else if serial_gap <= 6 then
        begin
            recent_bonus := c_recent_single_bonus_tail;
        end;
        Inc(Result, recent_bonus);
        if (count >= 3) and (serial_gap <= 2) then
        begin
            Inc(Result, 24);
        end;
        if Result > c_single_text_cap then
        begin
            Result := c_single_text_cap;
        end;
        Exit;
    end;

    Result := c_multi_text_base + ((count - 1) * c_multi_text_step);
    if count >= 3 then
    begin
        Inc(Result, 40);
    end;
    recent_bonus := 0;
    if serial_gap <= 1 then
    begin
        recent_bonus := c_recent_phrase_bonus_top;
    end
    else if serial_gap <= 3 then
    begin
        recent_bonus := c_recent_phrase_bonus_mid;
    end
    else if serial_gap <= 6 then
    begin
        recent_bonus := c_recent_phrase_bonus_tail;
    end;
    Inc(Result, recent_bonus);
    if (count >= 2) and (serial_gap <= 2) then
    begin
        Inc(Result, 96);
    end;
    if (count >= 3) and (serial_gap <= 4) then
    begin
        Inc(Result, 72);
    end;
    if Result > c_multi_text_cap then
    begin
        Result := c_multi_text_cap;
    end;

    if (text_key <> '') and (m_lookup_session_bonus_cache <> nil) then
    begin
        m_lookup_session_bonus_cache.AddOrSetValue(text_key, Result);
    end;
end;

function TncEngine.build_session_query_choice_key(const query_key: string; const candidate_text: string): string;
var
    text_key: string;
begin
    text_key := Trim(candidate_text);
    if (query_key = '') or (text_key = '') then
    begin
        Result := '';
        Exit;
    end;

    Result := query_key + #1 + text_key;
end;

function TncEngine.build_session_query_path_choice_key(const query_key: string; const encoded_path: string): string;
var
    path_key: string;
begin
    path_key := Trim(encoded_path);
    if (query_key = '') or (path_key = '') or (get_encoded_path_segment_count_local(path_key) <= 1) then
    begin
        Result := '';
        Exit;
    end;

    Result := query_key + c_session_query_path_separator + path_key;
end;

function TncEngine.build_context_query_scope_key(const context_text: string; const query_key: string): string;
var
    context_key: string;
begin
    context_key := Trim(context_text);
    if (context_key = '') or (query_key = '') then
    begin
        Result := '';
        Exit;
    end;

    Result := context_key + #2 + query_key;
end;

function TncEngine.build_context_query_choice_key(const context_text: string; const query_key: string;
    const candidate_text: string): string;
var
    context_key: string;
    text_key: string;
begin
    context_key := Trim(context_text);
    text_key := Trim(candidate_text);
    if (context_key = '') or (query_key = '') or (text_key = '') then
    begin
        Result := '';
        Exit;
    end;

    Result := context_key + #2 + query_key + #1 + text_key;
end;

function TncEngine.get_session_query_bonus(const candidate_text: string): Integer;
const
    c_single_query_base = 44;
    c_single_query_step = 34;
    c_single_query_cap = 176;
    c_multi_query_base = 96;
    c_multi_query_step = 56;
    c_multi_query_cap = 980;
    c_query_recent_latest = 900;
    c_query_recent_top = 180;
    c_query_recent_mid = 96;
    c_query_recent_tail = 52;
var
    key: string;
    count: Integer;
    last_seen_serial: Int64;
    serial_gap: Int64;
    text_units: Integer;
    recent_bonus: Integer;
begin
    key := build_session_query_choice_key(m_last_lookup_key, candidate_text);
    if (key <> '') and (m_lookup_query_bonus_cache <> nil) and
        m_lookup_query_bonus_cache.TryGetValue(key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (key = '') or (m_session_query_choice_counts = nil) then
    begin
        if (m_dictionary <> nil) and (m_last_lookup_key <> '') then
        begin
            Result := m_dictionary.get_query_choice_bonus(m_last_lookup_key, candidate_text);
            if (key <> '') and (m_lookup_query_bonus_cache <> nil) then
            begin
                m_lookup_query_bonus_cache.AddOrSetValue(key, Result);
            end;
        end;
        Exit;
    end;
    if (not m_session_query_choice_counts.TryGetValue(key, count)) or (count <= 0) then
    begin
        if m_dictionary <> nil then
        begin
            Result := m_dictionary.get_query_choice_bonus(m_last_lookup_key, candidate_text);
            if (key <> '') and (m_lookup_query_bonus_cache <> nil) then
            begin
                m_lookup_query_bonus_cache.AddOrSetValue(key, Result);
            end;
        end;
        Exit;
    end;

    last_seen_serial := 0;
    serial_gap := High(Int64);
    if (m_session_query_choice_last_seen <> nil) and
        m_session_query_choice_last_seen.TryGetValue(key, last_seen_serial) and
        (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
    begin
        serial_gap := m_session_commit_serial - last_seen_serial;
    end;

    recent_bonus := 0;
    if serial_gap = 0 then
    begin
        recent_bonus := c_query_recent_latest;
    end
    else if serial_gap <= 1 then
    begin
        recent_bonus := c_query_recent_top;
    end
    else if serial_gap <= 3 then
    begin
        recent_bonus := c_query_recent_mid;
    end
    else if serial_gap <= 6 then
    begin
        recent_bonus := c_query_recent_tail;
    end;

    text_units := get_candidate_text_unit_count(Trim(candidate_text));
    if text_units <= 1 then
    begin
        Result := c_single_query_base + ((count - 1) * c_single_query_step) + (recent_bonus div 3);
        if count >= 3 then
        begin
            Inc(Result, 18);
        end;
        if Result > c_single_query_cap then
        begin
            Result := c_single_query_cap;
        end;
    end
    else
    begin
        Result := c_multi_query_base + ((count - 1) * c_multi_query_step) + recent_bonus;
        if (count >= 2) and (serial_gap <= 2) then
        begin
            Inc(Result, 56);
        end;
        if (count >= 3) and (serial_gap <= 4) then
        begin
            Inc(Result, 32);
        end;
        if Result > c_multi_query_cap then
        begin
            Result := c_multi_query_cap;
        end;
    end;

    if (key <> '') and (m_lookup_query_bonus_cache <> nil) then
    begin
        m_lookup_query_bonus_cache.AddOrSetValue(key, Result);
    end;
end;

function TncEngine.get_session_query_path_bonus(const query_key: string; const encoded_path: string): Integer;
const
    c_query_path_base = 88;
    c_query_path_step = 72;
    c_query_path_cap = 760;
    c_query_path_recent_latest = 168;
    c_query_path_recent_top = 112;
    c_query_path_recent_mid = 68;
    c_query_path_recent_tail = 36;
var
    cache_key: string;
    count: Integer;
    key: string;
    last_seen_serial: Int64;
    normalized_query: string;
    normalized_path: string;
    recent_bonus: Integer;
    serial_gap: Int64;
begin
    normalized_query := normalize_pinyin_text(query_key);
    normalized_path := Trim(encoded_path);
    key := build_session_query_path_choice_key(normalized_query, normalized_path);
    cache_key := 'E' + #1 + key;
    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) and
        m_lookup_query_path_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (key = '') or (m_session_query_path_choice_counts = nil) then
    begin
        Exit;
    end;
    if (not m_session_query_path_choice_counts.TryGetValue(key, count)) or (count <= 0) then
    begin
        Exit;
    end;

    last_seen_serial := 0;
    serial_gap := High(Int64);
    if (m_session_query_path_choice_last_seen <> nil) and
        m_session_query_path_choice_last_seen.TryGetValue(key, last_seen_serial) and
        (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
    begin
        serial_gap := m_session_commit_serial - last_seen_serial;
    end;

    recent_bonus := 0;
    if serial_gap = 0 then
    begin
        recent_bonus := c_query_path_recent_latest;
    end
    else if serial_gap <= 1 then
    begin
        recent_bonus := c_query_path_recent_top;
    end
    else if serial_gap <= 3 then
    begin
        recent_bonus := c_query_path_recent_mid;
    end
    else if serial_gap <= 6 then
    begin
        recent_bonus := c_query_path_recent_tail;
    end;

    Result := c_query_path_base + (count * c_query_path_step) + recent_bonus;
    if count >= 2 then
    begin
        Inc(Result, 52);
    end;
    if count >= 4 then
    begin
        Inc(Result, 36);
    end;

    if Result > c_query_path_cap then
    begin
        Result := c_query_path_cap;
    end;

    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) then
    begin
        m_lookup_query_path_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_session_query_path_penalty(const query_key: string; const encoded_path: string): Integer;
const
    c_query_path_penalty_base = 68;
    c_query_path_penalty_step = 52;
    c_query_path_penalty_cap = 520;
    c_query_path_penalty_recent_latest = 132;
    c_query_path_penalty_recent_top = 88;
    c_query_path_penalty_recent_mid = 52;
    c_query_path_penalty_recent_tail = 24;
var
    cache_key: string;
    count: Integer;
    key: string;
    last_seen_serial: Int64;
    normalized_query: string;
    normalized_path: string;
    recent_bonus: Integer;
    serial_gap: Int64;
begin
    normalized_query := normalize_pinyin_text(query_key);
    normalized_path := Trim(encoded_path);
    key := build_session_query_path_choice_key(normalized_query, normalized_path);
    cache_key := 'EN' + #1 + key;
    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) and
        m_lookup_query_path_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (key = '') or (m_session_query_path_penalty_counts = nil) then
    begin
        Exit;
    end;
    if (not m_session_query_path_penalty_counts.TryGetValue(key, count)) or (count <= 0) then
    begin
        Exit;
    end;

    last_seen_serial := 0;
    serial_gap := High(Int64);
    if (m_session_query_path_penalty_last_seen <> nil) and
        m_session_query_path_penalty_last_seen.TryGetValue(key, last_seen_serial) and
        (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
    begin
        serial_gap := m_session_commit_serial - last_seen_serial;
    end;

    recent_bonus := 0;
    if serial_gap = 0 then
    begin
        recent_bonus := c_query_path_penalty_recent_latest;
    end
    else if serial_gap <= 1 then
    begin
        recent_bonus := c_query_path_penalty_recent_top;
    end
    else if serial_gap <= 3 then
    begin
        recent_bonus := c_query_path_penalty_recent_mid;
    end
    else if serial_gap <= 6 then
    begin
        recent_bonus := c_query_path_penalty_recent_tail;
    end;

    Result := c_query_path_penalty_base + (count * c_query_path_penalty_step) + recent_bonus;
    if count >= 2 then
    begin
        Inc(Result, 44);
    end;
    if count >= 4 then
    begin
        Inc(Result, 28);
    end;

    if Result > c_query_path_penalty_cap then
    begin
        Result := c_query_path_penalty_cap;
    end;

    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) then
    begin
        m_lookup_query_path_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_session_query_path_prefix_bonus(const query_key: string; const encoded_path: string): Integer;
const
    c_query_path_prefix_base = 44;
    c_query_path_prefix_step = 36;
    c_query_path_prefix_cap = 260;
    c_query_path_prefix_recent_top = 54;
    c_query_path_prefix_recent_mid = 28;
    c_query_path_prefix_recent_tail = 12;
var
    cache_key: string;
    count: Integer;
    current_key: string;
    current_serial: Int64;
    key_pair: TPair<string, Integer>;
    last_seen_serial: Int64;
    local_bonus: Integer;
    normalized_query: string;
    normalized_path: string;
    prefix_with_separator: string;
    recent_bonus: Integer;
    serial_gap: Int64;
    session_query_prefix: string;
    stored_path: string;
begin
    normalized_query := normalize_pinyin_text(query_key);
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count_local(normalized_path) <= 1) then
    begin
        Exit(0);
    end;

    cache_key := 'P' + #1 + build_session_query_path_choice_key(normalized_query, normalized_path);
    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) and
        m_lookup_query_path_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (m_session_query_path_choice_counts = nil) or (m_session_query_path_choice_counts.Count <= 0) then
    begin
        Exit;
    end;

    prefix_with_separator := normalized_path + c_segment_path_separator;
    session_query_prefix := normalized_query + c_session_query_path_separator;
    current_serial := m_session_commit_serial;
    for key_pair in m_session_query_path_choice_counts do
    begin
        current_key := key_pair.Key;
        if (Length(current_key) <= Length(session_query_prefix)) or
            (Copy(current_key, 1, Length(session_query_prefix)) <> session_query_prefix) then
        begin
            Continue;
        end;

        stored_path := Copy(current_key, Length(session_query_prefix) + 1, MaxInt);
        if (stored_path <> normalized_path) and
            (Copy(stored_path, 1, Length(prefix_with_separator)) <> prefix_with_separator) then
        begin
            Continue;
        end;

        count := key_pair.Value;
        if count <= 0 then
        begin
            Continue;
        end;

        last_seen_serial := 0;
        serial_gap := High(Int64);
        if (m_session_query_path_choice_last_seen <> nil) and
            m_session_query_path_choice_last_seen.TryGetValue(current_key, last_seen_serial) and
            (last_seen_serial > 0) and (current_serial >= last_seen_serial) then
        begin
            serial_gap := current_serial - last_seen_serial;
        end;

        recent_bonus := 0;
        if serial_gap <= 1 then
        begin
            recent_bonus := c_query_path_prefix_recent_top;
        end
        else if serial_gap <= 3 then
        begin
            recent_bonus := c_query_path_prefix_recent_mid;
        end
        else if serial_gap <= 6 then
        begin
            recent_bonus := c_query_path_prefix_recent_tail;
        end;

        local_bonus := c_query_path_prefix_base + (count * c_query_path_prefix_step) + recent_bonus +
            ((get_encoded_path_segment_count_local(stored_path) -
            get_encoded_path_segment_count_local(normalized_path)) * 12);
        if local_bonus > c_query_path_prefix_cap then
        begin
            local_bonus := c_query_path_prefix_cap;
        end;
        if local_bonus > Result then
        begin
            Result := local_bonus;
        end;
    end;

    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) then
    begin
        m_lookup_query_path_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_session_query_path_prefix_penalty(const query_key: string;
    const encoded_path: string): Integer;
const
    c_query_path_prefix_penalty_base = 30;
    c_query_path_prefix_penalty_step = 24;
    c_query_path_prefix_penalty_cap = 220;
    c_query_path_prefix_penalty_recent_top = 40;
    c_query_path_prefix_penalty_recent_mid = 20;
    c_query_path_prefix_penalty_recent_tail = 8;
var
    cache_key: string;
    count: Integer;
    current_key: string;
    current_serial: Int64;
    key_pair: TPair<string, Integer>;
    last_seen_serial: Int64;
    local_penalty: Integer;
    normalized_query: string;
    normalized_path: string;
    prefix_with_separator: string;
    recent_bonus: Integer;
    serial_gap: Int64;
    session_query_prefix: string;
    stored_path: string;
begin
    normalized_query := normalize_pinyin_text(query_key);
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count_local(normalized_path) <= 1) then
    begin
        Exit(0);
    end;

    cache_key := 'PN' + #1 + build_session_query_path_choice_key(normalized_query, normalized_path);
    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) and
        m_lookup_query_path_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (m_session_query_path_penalty_counts = nil) or
        (m_session_query_path_penalty_counts.Count <= 0) then
    begin
        Exit;
    end;

    prefix_with_separator := normalized_path + c_segment_path_separator;
    session_query_prefix := normalized_query + c_session_query_path_separator;
    current_serial := m_session_commit_serial;
    for key_pair in m_session_query_path_penalty_counts do
    begin
        current_key := key_pair.Key;
        if (Length(current_key) <= Length(session_query_prefix)) or
            (Copy(current_key, 1, Length(session_query_prefix)) <> session_query_prefix) then
        begin
            Continue;
        end;

        stored_path := Copy(current_key, Length(session_query_prefix) + 1, MaxInt);
        if (stored_path <> normalized_path) and
            (Copy(stored_path, 1, Length(prefix_with_separator)) <> prefix_with_separator) then
        begin
            Continue;
        end;

        count := key_pair.Value;
        if count <= 0 then
        begin
            Continue;
        end;

        last_seen_serial := 0;
        serial_gap := High(Int64);
        if (m_session_query_path_penalty_last_seen <> nil) and
            m_session_query_path_penalty_last_seen.TryGetValue(current_key, last_seen_serial) and
            (last_seen_serial > 0) and (current_serial >= last_seen_serial) then
        begin
            serial_gap := current_serial - last_seen_serial;
        end;

        recent_bonus := 0;
        if serial_gap <= 1 then
        begin
            recent_bonus := c_query_path_prefix_penalty_recent_top;
        end
        else if serial_gap <= 3 then
        begin
            recent_bonus := c_query_path_prefix_penalty_recent_mid;
        end
        else if serial_gap <= 6 then
        begin
            recent_bonus := c_query_path_prefix_penalty_recent_tail;
        end;

        local_penalty := c_query_path_prefix_penalty_base +
            (count * c_query_path_prefix_penalty_step) + recent_bonus +
            ((get_encoded_path_segment_count_local(stored_path) -
            get_encoded_path_segment_count_local(normalized_path)) * 8);
        if local_penalty > c_query_path_prefix_penalty_cap then
        begin
            local_penalty := c_query_path_prefix_penalty_cap;
        end;
        if local_penalty > Result then
        begin
            Result := local_penalty;
        end;
    end;

    if (cache_key <> '') and (m_lookup_query_path_bonus_cache <> nil) then
    begin
        m_lookup_query_path_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_session_ranked_query_path_bonus(const encoded_path: string): Integer;
const
    c_recent_ranked_same_path_base = 86;
    c_recent_ranked_extended_path_base = 168;
    c_recent_ranked_same_query_extra = 36;
    c_recent_ranked_long_prefix_step = 18;
    c_recent_ranked_bonus_cap = 320;
var
    best_bonus: Integer;
    cache_key: string;
    current_query: string;
    current_score: Integer;
    current_stored_path: string;
    key_pair: TPair<string, string>;
    local_bonus: Integer;
    normalized_path: string;
    prefix_query: string;
begin
    Result := 0;
    normalized_path := Trim(encoded_path);
    current_query := normalize_pinyin_text(m_last_lookup_key);
    if (normalized_path = '') or (current_query = '') or
        (get_encoded_path_segment_count_local(normalized_path) <= 1) or
        (m_session_ranked_query_paths = nil) or
        (m_session_ranked_query_paths.Count <= 0) then
    begin
        Exit;
    end;

    cache_key := 'SR' + #1 + current_query + #1 + normalized_path;
    if (m_lookup_query_path_bonus_cache <> nil) and
        m_lookup_query_path_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    best_bonus := 0;
    for key_pair in m_session_ranked_query_paths do
    begin
        prefix_query := key_pair.Key;
        current_stored_path := Trim(key_pair.Value);
        if (prefix_query = '') or (current_stored_path = '') then
        begin
            Continue;
        end;
        if (Length(prefix_query) > Length(current_query)) or
            (Copy(current_query, 1, Length(prefix_query)) <> prefix_query) then
        begin
            Continue;
        end;

        if not m_session_ranked_query_path_scores.TryGetValue(prefix_query, current_score) then
        begin
            current_score := 0;
        end;

        local_bonus := 0;
        if normalized_path = current_stored_path then
        begin
            local_bonus := c_recent_ranked_same_path_base;
        end
        else if Copy(normalized_path, 1, Length(current_stored_path) + 1) =
            (current_stored_path + c_segment_path_separator) then
        begin
            local_bonus := c_recent_ranked_extended_path_base;
        end;

        if local_bonus <= 0 then
        begin
            Continue;
        end;

        if SameText(prefix_query, current_query) then
        begin
            Inc(local_bonus, c_recent_ranked_same_query_extra);
        end;

        if Length(prefix_query) >= 4 then
        begin
            Inc(local_bonus, Min(72, (Length(prefix_query) - 3) * c_recent_ranked_long_prefix_step));
        end;

        if current_score > 0 then
        begin
            Inc(local_bonus, Min(84, current_score div 8));
        end;

        if local_bonus > best_bonus then
        begin
            best_bonus := local_bonus;
        end;
    end;

    if best_bonus > c_recent_ranked_bonus_cap then
    begin
        best_bonus := c_recent_ranked_bonus_cap;
    end;
    Result := best_bonus;

    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_persistent_query_path_prefix_support(const encoded_path: string): Integer;
const
    c_query_path_prefix_support_cap = 420;
    c_query_path_prefix_penalty_cap = 260;
var
    cache_key: string;
    normalized_path: string;
    segment_text: string;
    prefix_path: string;
    prefix_query: string;
    normalized_lookup_query: string;
    bonus_value: Integer;
    penalty_value: Integer;
    positive_total: Integer;
    negative_total: Integer;
    idx: Integer;
    path_start: Integer;
begin
    Result := 0;
    normalized_path := Trim(encoded_path);
    if (normalized_path = '') or (get_encoded_path_segment_count_local(normalized_path) <= 1) or
        (m_dictionary = nil) then
    begin
        Exit;
    end;

    normalized_lookup_query := normalize_pinyin_text(m_last_lookup_key);
    if normalized_lookup_query = '' then
    begin
        Exit;
    end;

    cache_key := 'DP' + #1 + normalized_path;
    if (m_lookup_query_path_bonus_cache <> nil) and
        m_lookup_query_path_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    prefix_path := '';
    positive_total := 0;
    negative_total := 0;
    path_start := 1;
    for idx := 1 to Length(normalized_path) + 1 do
    begin
        if (idx <= Length(normalized_path)) and (normalized_path[idx] <> c_segment_path_separator) then
        begin
            Continue;
        end;

        segment_text := Trim(Copy(normalized_path, path_start, idx - path_start));
        path_start := idx + 1;
        if segment_text = '' then
        begin
            Continue;
        end;

        if prefix_path <> '' then
        begin
            prefix_path := prefix_path + c_segment_path_separator;
        end;
        prefix_path := prefix_path + segment_text;

        if (prefix_path = normalized_path) or
            (get_encoded_path_segment_count_local(prefix_path) <= 1) then
        begin
            Continue;
        end;

        prefix_query := get_query_prefix_for_segment_path(prefix_path);
        if (prefix_query = '') or (prefix_query = normalized_lookup_query) then
        begin
            Continue;
        end;

        bonus_value := m_dictionary.get_query_segment_path_bonus(prefix_query, prefix_path);
        penalty_value := m_dictionary.get_query_segment_path_penalty(prefix_query, prefix_path);
        if bonus_value > 0 then
        begin
            Inc(positive_total, bonus_value);
        end;
        if penalty_value > 0 then
        begin
            Inc(negative_total, penalty_value);
        end;
    end;

    if positive_total > c_query_path_prefix_support_cap then
    begin
        positive_total := c_query_path_prefix_support_cap;
    end;
    if negative_total > c_query_path_prefix_penalty_cap then
    begin
        negative_total := c_query_path_prefix_penalty_cap;
    end;
    Result := positive_total - negative_total;

    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_context_query_bonus(const candidate_text: string): Integer;
const
    c_context_combined_cap = 720;
    c_multi_context_query_base = 118;
    c_multi_context_query_step = 62;
    c_multi_context_query_cap = 520;
    c_single_context_query_base = 40;
    c_single_context_query_step = 26;
    c_single_context_query_cap = 180;
    c_recent_top = 150;
    c_recent_mid = 88;
    c_recent_tail = 46;
var
    context_value: string;
    context_variants: TArray<string>;
    variant_idx: Integer;
    variant_weight: Integer;
    key: string;
    text_key: string;
    count: Integer;
    last_seen_serial: Int64;
    serial_gap: Int64;
    text_units: Integer;
    variant_bonus: Integer;

    function get_variant_weight(const variant_index: Integer): Integer;
    begin
        case variant_index of
            0:
                Result := 100;
            1:
                Result := 88;
            2:
                Result := 72;
            3:
                Result := 58;
        else
            Result := 42;
        end;
    end;

    function merge_variant_bonus(const current_bonus: Integer; const weighted_bonus: Integer): Integer;
    begin
        Result := current_bonus;
        if weighted_bonus <= 0 then
        begin
            Exit;
        end;

        if Result <= 0 then
        begin
            Result := weighted_bonus;
            Exit;
        end;

        if weighted_bonus > Result then
        begin
            Result := weighted_bonus + (Result div 3);
        end
        else
        begin
            Result := Result + (weighted_bonus div 3);
        end;

        if Result > c_context_combined_cap then
        begin
            Result := c_context_combined_cap;
        end;
    end;
begin
    text_key := Trim(candidate_text);
    if (text_key <> '') and (m_lookup_context_query_bonus_cache <> nil) and
        m_lookup_context_query_bonus_cache.TryGetValue(text_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (text_key = '') or (m_last_lookup_key = '') or (m_session_context_query_choice_counts = nil) then
    begin
        Exit;
    end;

    context_value := m_left_context;
    if m_segment_left_context <> '' then
    begin
        context_value := m_segment_left_context;
    end;
    if (m_segment_left_context = '') and (m_external_left_context <> '') then
    begin
        context_value := m_external_left_context;
    end;
    if context_value = '' then
    begin
        Exit;
    end;

    context_variants := get_context_variants(context_value);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    text_units := get_candidate_text_unit_count(text_key);
    for variant_idx := 0 to High(context_variants) do
    begin
        key := build_context_query_choice_key(context_variants[variant_idx], m_last_lookup_key, text_key);
        if (key = '') or (not m_session_context_query_choice_counts.TryGetValue(key, count)) or (count <= 0) then
        begin
            Continue;
        end;

        if text_units <= 1 then
        begin
            variant_bonus := c_single_context_query_base + ((count - 1) * c_single_context_query_step);
            if variant_bonus > c_single_context_query_cap then
            begin
                variant_bonus := c_single_context_query_cap;
            end;
        end
        else
        begin
            variant_bonus := c_multi_context_query_base + ((count - 1) * c_multi_context_query_step);
            if count >= 3 then
            begin
                Inc(variant_bonus, 36);
            end;
            if variant_bonus > c_multi_context_query_cap then
            begin
                variant_bonus := c_multi_context_query_cap;
            end;
        end;

        if (m_session_context_query_choice_last_seen <> nil) and
            m_session_context_query_choice_last_seen.TryGetValue(key, last_seen_serial) and
            (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
        begin
            serial_gap := m_session_commit_serial - last_seen_serial;
            if serial_gap <= 1 then
            begin
                Inc(variant_bonus, c_recent_top);
            end
            else if serial_gap <= 3 then
            begin
                Inc(variant_bonus, c_recent_mid);
            end
            else if serial_gap <= 6 then
            begin
                Inc(variant_bonus, c_recent_tail);
            end;
        end;

        variant_weight := get_variant_weight(variant_idx);
        variant_bonus := (variant_bonus * variant_weight) div 100;
        Result := merge_variant_bonus(Result, variant_bonus);
    end;

    if (text_key <> '') and (m_lookup_context_query_bonus_cache <> nil) then
    begin
        m_lookup_context_query_bonus_cache.AddOrSetValue(text_key, Result);
    end;
end;

function TncEngine.get_context_query_latest_bonus(const candidate_text: string): Integer;
const
    c_context_latest_cap = 320;
    c_phrase_latest_bonus = 228;
    c_single_latest_bonus = 92;
var
    context_value: string;
    context_variants: TArray<string>;
    variant_idx: Integer;
    variant_weight: Integer;
    key: string;
    text_key: string;
    latest_text: string;
    text_units: Integer;
    variant_bonus: Integer;

    function get_variant_weight(const variant_index: Integer): Integer;
    begin
        case variant_index of
            0:
                Result := 100;
            1:
                Result := 88;
            2:
                Result := 72;
            3:
                Result := 58;
        else
            Result := 42;
        end;
    end;

    function merge_variant_bonus(const current_bonus: Integer; const weighted_bonus: Integer): Integer;
    begin
        Result := current_bonus;
        if weighted_bonus <= 0 then
        begin
            Exit;
        end;

        if Result <= 0 then
        begin
            Result := weighted_bonus;
            Exit;
        end;

        if weighted_bonus > Result then
        begin
            Result := weighted_bonus + (Result div 3);
        end
        else
        begin
            Result := Result + (weighted_bonus div 3);
        end;

        if Result > c_context_latest_cap then
        begin
            Result := c_context_latest_cap;
        end;
    end;
begin
    text_key := Trim(candidate_text);
    if (text_key <> '') and (m_lookup_context_query_latest_bonus_cache <> nil) and
        m_lookup_context_query_latest_bonus_cache.TryGetValue(text_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if (text_key = '') or (m_last_lookup_key = '') or (m_session_context_query_latest_text = nil) then
    begin
        Exit;
    end;

    context_value := m_left_context;
    if m_segment_left_context <> '' then
    begin
        context_value := m_segment_left_context;
    end;
    if (m_segment_left_context = '') and (m_external_left_context <> '') then
    begin
        context_value := m_external_left_context;
    end;
    if context_value = '' then
    begin
        Exit;
    end;

    context_variants := get_context_variants(context_value);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    text_units := get_candidate_text_unit_count(text_key);
    for variant_idx := 0 to High(context_variants) do
    begin
        key := build_context_query_scope_key(context_variants[variant_idx], m_last_lookup_key);
        if (key = '') or (not m_session_context_query_latest_text.TryGetValue(key, latest_text)) then
        begin
            Continue;
        end;
        if not SameText(text_key, latest_text) then
        begin
            Continue;
        end;
        key := build_context_query_choice_key(context_variants[variant_idx], m_last_lookup_key, text_key);
        if (key = '') or ((m_session_context_query_choice_last_seen <> nil) and
            (not m_session_context_query_choice_last_seen.ContainsKey(key))) then
        begin
            Continue;
        end;

        if text_units <= 1 then
        begin
            variant_bonus := c_single_latest_bonus;
        end
        else
        begin
            variant_bonus := c_phrase_latest_bonus;
            if (m_last_lookup_syllable_count >= 3) and (text_units + 1 >= m_last_lookup_syllable_count) then
            begin
                Inc(variant_bonus, 32);
            end;
        end;

        variant_weight := get_variant_weight(variant_idx);
        variant_bonus := (variant_bonus * variant_weight) div 100;
        Result := merge_variant_bonus(Result, variant_bonus);
    end;

    if (text_key <> '') and (m_lookup_context_query_latest_bonus_cache <> nil) then
    begin
        m_lookup_context_query_latest_bonus_cache.AddOrSetValue(text_key, Result);
    end;
end;

function TncEngine.is_latest_session_query_choice(const candidate_text: string): Boolean;
var
    cached_latest_text: string;
    latest_text: string;
    text_key: string;
begin
    Result := False;
    text_key := Trim(candidate_text);
    if (m_last_lookup_key = '') or (text_key = '') then
    begin
        Exit;
    end;

    if (m_session_query_latest_text <> nil) and
        m_session_query_latest_text.TryGetValue(m_last_lookup_key, latest_text) then
    begin
        Exit(SameText(text_key, latest_text));
    end;

    if m_dictionary = nil then
    begin
        Exit(False);
    end;

    latest_text := '';
    if (m_lookup_query_latest_text_cache <> nil) and
        m_lookup_query_latest_text_cache.TryGetValue(m_last_lookup_key, cached_latest_text) then
    begin
        latest_text := cached_latest_text;
    end
    else
    begin
        latest_text := Trim(m_dictionary.get_query_latest_choice_text(m_last_lookup_key));
        if m_lookup_query_latest_text_cache <> nil then
        begin
            m_lookup_query_latest_text_cache.AddOrSetValue(m_last_lookup_key, latest_text);
        end;
    end;

    Result := SameText(text_key, latest_text);
end;

function TncEngine.get_phrase_context_bonus(const candidate_text: string): Integer;
const
    c_phrase_pair_step = 120;
    c_phrase_pair_cap = 360;
    c_phrase_trigram_step = 150;
    c_phrase_trigram_cap = 460;
    c_phrase_context_cap = 620;
    c_phrase_pair_recent_top = 160;
    c_phrase_pair_recent_mid = 92;
    c_phrase_pair_recent_tail = 44;
    c_phrase_trigram_recent_top = 220;
    c_phrase_trigram_recent_mid = 132;
    c_phrase_trigram_recent_tail = 64;
    c_context_variant_pair_cap = 420;
var
    pair_count: Integer;
    pair_bonus: Integer;
    trigram_count: Integer;
    trigram_bonus: Integer;
    key: string;
    text_key: string;
    last_seen_serial: Int64;
    serial_gap: Int64;
    pair_recent_bonus: Integer;
    trigram_recent_bonus: Integer;
    context_value: string;
    context_variants: TArray<string>;
    variant_idx: Integer;
    variant_weight: Integer;
    variant_bonus: Integer;

    function get_variant_weight(const variant_index: Integer): Integer;
    begin
        case variant_index of
            0:
                Result := 100;
            1:
                Result := 88;
            2:
                Result := 72;
            3:
                Result := 58;
        else
            Result := 42;
        end;
    end;

    function merge_bonus(const current_bonus: Integer; const next_bonus: Integer): Integer;
    begin
        Result := current_bonus;
        if next_bonus <= 0 then
        begin
            Exit;
        end;

        if Result <= 0 then
        begin
            Result := next_bonus;
            Exit;
        end;

        if next_bonus > Result then
        begin
            Result := next_bonus + (Result div 3);
        end
        else
        begin
            Result := Result + (next_bonus div 3);
        end;

        if Result > c_phrase_context_cap then
        begin
            Result := c_phrase_context_cap;
        end;
    end;

    function get_recent_phrase_bonus(
        const phrase_key: string;
        const top_bonus: Integer;
        const mid_bonus: Integer;
        const tail_bonus: Integer
    ): Integer;
    begin
        Result := 0;
        if (phrase_key = '') or (m_phrase_context_last_seen = nil) then
        begin
            Exit;
        end;
        if (not m_phrase_context_last_seen.TryGetValue(phrase_key, last_seen_serial)) or
            (last_seen_serial <= 0) or (m_session_commit_serial < last_seen_serial) then
        begin
            Exit;
        end;

        serial_gap := m_session_commit_serial - last_seen_serial;
        if serial_gap <= 1 then
        begin
            Result := top_bonus;
        end
        else if serial_gap <= 3 then
        begin
            Result := mid_bonus;
        end
        else if serial_gap <= 6 then
        begin
            Result := tail_bonus;
        end;
    end;
begin
    text_key := Trim(candidate_text);
    if (text_key <> '') and (m_lookup_phrase_context_bonus_cache <> nil) and
        m_lookup_phrase_context_bonus_cache.TryGetValue(text_key, Result) then
    begin
        Exit;
    end;

    Result := 0;
    if m_phrase_context_pairs = nil then
    begin
        Exit;
    end;

    if (text_key = '') or (m_last_output_commit_text = '') then
    begin
        Exit;
    end;

    pair_bonus := 0;
    trigram_bonus := 0;
    pair_recent_bonus := 0;
    trigram_recent_bonus := 0;

    key := m_last_output_commit_text + #1 + text_key;
    if m_phrase_context_pairs.TryGetValue(key, pair_count) and (pair_count > 0) then
    begin
        pair_bonus := pair_count * c_phrase_pair_step;
        if pair_bonus > c_phrase_pair_cap then
        begin
            pair_bonus := c_phrase_pair_cap;
        end;
        pair_recent_bonus := get_recent_phrase_bonus(
            key,
            c_phrase_pair_recent_top,
            c_phrase_pair_recent_mid,
            c_phrase_pair_recent_tail);
    end;

    if m_prev_output_commit_text <> '' then
    begin
        key := m_prev_output_commit_text + #2 + m_last_output_commit_text + #1 + text_key;
        if m_phrase_context_pairs.TryGetValue(key, trigram_count) and (trigram_count > 0) then
        begin
            trigram_bonus := trigram_count * c_phrase_trigram_step;
            if trigram_bonus > c_phrase_trigram_cap then
            begin
                trigram_bonus := c_phrase_trigram_cap;
            end;
            trigram_recent_bonus := get_recent_phrase_bonus(
                key,
                c_phrase_trigram_recent_top,
                c_phrase_trigram_recent_mid,
                c_phrase_trigram_recent_tail);
        end;
    end;

    if trigram_bonus > 0 then
    begin
        Result := trigram_bonus + (pair_bonus div 2) + trigram_recent_bonus + (pair_recent_bonus div 2);
    end
    else
    begin
        Result := pair_bonus + pair_recent_bonus;
    end;

    if Result > c_phrase_context_cap then
    begin
        Result := c_phrase_context_cap;
    end;

    context_value := m_left_context;
    if m_segment_left_context <> '' then
    begin
        context_value := m_segment_left_context;
    end;
    if (m_segment_left_context = '') and (m_external_left_context <> '') then
    begin
        context_value := m_external_left_context;
    end;
    if context_value <> '' then
    begin
        context_variants := get_context_variants(context_value);
        for variant_idx := 0 to High(context_variants) do
        begin
            key := Trim(context_variants[variant_idx]) + #1 + text_key;
            if (key = '') or (not m_phrase_context_pairs.TryGetValue(key, pair_count)) or (pair_count <= 0) then
            begin
                Continue;
            end;

            variant_bonus := pair_count * c_phrase_pair_step;
            if variant_bonus > c_context_variant_pair_cap then
            begin
                variant_bonus := c_context_variant_pair_cap;
            end;
            Inc(variant_bonus, get_recent_phrase_bonus(
                key,
                c_phrase_pair_recent_top,
                c_phrase_pair_recent_mid,
                c_phrase_pair_recent_tail));

            variant_weight := get_variant_weight(variant_idx);
            variant_bonus := (variant_bonus * variant_weight) div 100;
            Result := merge_bonus(Result, variant_bonus);
        end;
    end;

    if (text_key <> '') and (m_lookup_phrase_context_bonus_cache <> nil) then
    begin
        m_lookup_phrase_context_bonus_cache.AddOrSetValue(text_key, Result);
    end;
end;

function TncEngine.get_candidate_text_unit_count(const text: string): Integer;
begin
    if (text <> '') and (m_lookup_text_unit_count_cache <> nil) and
        m_lookup_text_unit_count_cache.TryGetValue(text, Result) then
    begin
        Exit;
    end;

    Result := Length(split_text_units(text));
    if (text <> '') and (m_lookup_text_unit_count_cache <> nil) then
    begin
        m_lookup_text_unit_count_cache.AddOrSetValue(text, Result);
    end;
end;

function TncEngine.is_runtime_chain_candidate(const candidate: TncCandidate): Boolean;
begin
    Result := (m_runtime_chain_text <> '') and (candidate.source = cs_rule) and
        (candidate.comment = '') and (not candidate.has_dict_weight) and
        SameText(candidate.text, m_runtime_chain_text);
end;

function TncEngine.is_runtime_common_pattern_candidate(const candidate: TncCandidate): Boolean;
begin
    Result := (m_runtime_common_pattern_text <> '') and (candidate.source = cs_rule) and
        (candidate.comment = '') and (not candidate.has_dict_weight) and
        SameText(candidate.text, m_runtime_common_pattern_text);
end;

function TncEngine.is_runtime_redup_candidate(const candidate: TncCandidate): Boolean;
begin
    Result := (m_runtime_redup_text <> '') and (candidate.source = cs_rule) and
        (candidate.comment = '') and (not candidate.has_dict_weight) and
        SameText(candidate.text, m_runtime_redup_text);
end;

function TncEngine.get_runtime_candidate_kind(const candidate: TncCandidate): string;
begin
    Result := '';
    if is_runtime_chain_candidate(candidate) then
    begin
        Result := 'chain';
    end
    else if is_runtime_common_pattern_candidate(candidate) then
    begin
        Result := 'pattern';
    end
    else if is_runtime_redup_candidate(candidate) then
    begin
        Result := 'redup';
    end;
end;

function TncEngine.is_runtime_constructed_phrase_friendly(const text: string): Boolean;
var
    units: TArray<string>;
    tail_text: string;
begin
    Result := False;
    units := split_text_units(Trim(text));
    if Length(units) <> 2 then
    begin
        Exit;
    end;

    if units[0] = units[1] then
    begin
        Result := True;
        Exit;
    end;

    tail_text := units[1];
    if tail_text = '' then
    begin
        Exit;
    end;

    case Ord(tail_text[1]) of
        $5427, // 吧
        $5417, // 吗
        $5462, // 呢
        $4E2A, // 个
        $4F4D, // 位
        $6B21, // 次
        $70B9, // 点
        $4E9B, // 些
        $79CD, // 种
        $5929, // 天
        $5E74, // 年
        $6708, // 月
        $91CC, // 里
        $4E0B, // 下
        $56DE, // 回
        $904D, // 遍
        $58F0, // 声
        $9762, // 面
        $773C, // 眼
        $8FB9: // 边
            Result := True;
    end;
end;

function TncEngine.get_candidate_path_confidence_score(const candidate: TncCandidate): Integer;
var
    encoded_path: string;
    text_units: Integer;
    cache_key: string;
begin
    Result := 0;
    encoded_path := get_segment_path_for_candidate(candidate);
    if get_encoded_path_segment_count_local(encoded_path) <= 1 then
    begin
        Exit;
    end;

    cache_key := build_candidate_identity_key(candidate.text, candidate.comment) + #1 + encoded_path;
    if (m_lookup_candidate_path_confidence_cache <> nil) and
        m_lookup_candidate_path_confidence_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    Result := get_segment_path_support_score(candidate);
    if Result < 0 then
    begin
        Result := 0;
    end;

    if (Result > 0) and (candidate.comment <> '') then
    begin
        text_units := get_candidate_text_unit_count(candidate.text);
        if is_runtime_chain_candidate(candidate) then
        begin
            Result := Result div 4;
        end
        else
        begin
            Result := (Result * 3) div 5;
            if (text_units >= 2) and (m_last_lookup_syllable_count >= 3) then
            begin
                Inc(Result, Min(88, Result div 6));
            end;
        end;
    end;

    if m_lookup_candidate_path_confidence_cache <> nil then
    begin
        m_lookup_candidate_path_confidence_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_candidate_path_confidence_tier(const candidate: TncCandidate): Integer;
var
    path_confidence_score: Integer;
begin
    Result := 0;
    path_confidence_score := get_candidate_path_confidence_score(candidate);
    if path_confidence_score >= 880 then
    begin
        Result := 2;
    end
    else if path_confidence_score >= 420 then
    begin
        Result := 1;
    end;
end;

function TncEngine.get_candidate_segment_path_score_hint(const candidate: TncCandidate): Integer;
var
    key: string;
begin
    Result := Low(Integer);
    if m_current_segment_path_score_map = nil then
    begin
        Exit;
    end;

    key := build_candidate_identity_key(candidate.text, candidate.comment);
    if key = '' then
    begin
        Exit;
    end;

    if not m_current_segment_path_score_map.TryGetValue(key, Result) then
    begin
        Result := Low(Integer);
    end;
end;

function TncEngine.get_candidate_confidence_rank(const candidate: TncCandidate): Integer;
var
    layer_value: Integer;
    text_units: Integer;
    context_bonus: Integer;
    query_bonus: Integer;
    session_bonus: Integer;
    path_confidence_tier: Integer;
    path_confidence_score: Integer;
begin
    layer_value := get_multi_syllable_intent_layer(candidate);
    text_units := get_candidate_text_unit_count(candidate.text);
    path_confidence_score := get_candidate_path_confidence_score(candidate);
    path_confidence_tier := get_candidate_path_confidence_tier(candidate);

    if candidate.comment <> '' then
    begin
        if (text_units >= 2) and (path_confidence_score >= 720) and
            (not is_runtime_chain_candidate(candidate)) then
        begin
            Result := 5;
        end
        else if text_units >= 2 then
        begin
            Result := 6;
        end
        else
        begin
            Result := 8;
        end;
        Exit;
    end;

    if candidate.source = cs_user then
    begin
        Result := 0;
        Exit;
    end;

    if candidate.has_dict_weight then
    begin
        if layer_value = 0 then
        begin
            Result := 0;
        end
        else if layer_value = 1 then
        begin
            Result := 1;
        end
        else
        begin
            Result := 2;
        end;
    end
    else if is_runtime_common_pattern_candidate(candidate) then
    begin
        Result := 3;
    end
    else if is_runtime_redup_candidate(candidate) then
    begin
        Result := 4;
    end
    else if is_runtime_chain_candidate(candidate) then
    begin
        Result := 8;
    end
    else if (candidate.source = cs_rule) and (text_units >= 2) then
    begin
        Result := 5;
    end
    else
    begin
        Result := 7;
    end;

    if Result <= 0 then
    begin
        Exit;
    end;

    context_bonus := get_context_bonus(candidate.text);
    query_bonus := get_session_query_bonus(candidate.text);
    session_bonus := get_session_text_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        query_bonus := query_bonus div 2;
        session_bonus := session_bonus div 2;
    end;

    if (text_units >= 2) and ((context_bonus >= 320) or (query_bonus >= 320) or (session_bonus >= 320)) then
    begin
        Dec(Result);
    end;
    if path_confidence_tier >= 2 then
    begin
        Dec(Result, 2);
    end
    else if path_confidence_tier = 1 then
    begin
        Dec(Result);
    end;
    if path_confidence_score >= 1280 then
    begin
        Dec(Result);
    end;
    if Result < 0 then
    begin
        Result := 0;
    end;
end;

function TncEngine.get_front_row_confidence_bonus(const candidate: TncCandidate): Integer;
var
    text_units: Integer;
    layer_value: Integer;
    path_confidence_tier: Integer;
    path_confidence_score: Integer;
begin
    Result := 0;
    text_units := get_candidate_text_unit_count(candidate.text);
    layer_value := get_multi_syllable_intent_layer(candidate);
    path_confidence_score := get_candidate_path_confidence_score(candidate);
    path_confidence_tier := get_candidate_path_confidence_tier(candidate);

    if candidate.comment <> '' then
    begin
        if m_last_lookup_syllable_count >= 3 then
        begin
            Dec(Result, 60 + (layer_value * 18));
        end;
        if (text_units >= 2) and (path_confidence_score > 0) and
            (not is_runtime_chain_candidate(candidate)) then
        begin
            case path_confidence_tier of
                1: Inc(Result, 24);
                2: Inc(Result, 56);
            end;
            Inc(Result, Min(84, path_confidence_score div 18));
        end;
        Exit;
    end;

    if candidate.has_dict_weight then
    begin
        if layer_value = 0 then
        begin
            Inc(Result, 140);
            if (m_last_lookup_syllable_count >= 4) and (text_units >= 3) then
            begin
                Inc(Result, 36);
            end;
        end
        else if layer_value = 1 then
        begin
            Inc(Result, 68);
        end;
    end;
    if (not candidate.has_dict_weight) and is_runtime_common_pattern_candidate(candidate) then
    begin
        Inc(Result, 96);
    end;
    if (not candidate.has_dict_weight) and is_runtime_redup_candidate(candidate) then
    begin
        Inc(Result, 72);
    end;

    if is_runtime_chain_candidate(candidate) then
    begin
        Dec(Result, 320);
        Exit;
    end;

    if (candidate.source = cs_rule) and (text_units >= 2) then
    begin
        Dec(Result, 120);
    end;

    case path_confidence_tier of
        1: Inc(Result, 28);
        2: Inc(Result, 72);
    end;
    if path_confidence_score > 0 then
    begin
        Inc(Result, Min(48, path_confidence_score div 40));
    end;
end;

function TncEngine.get_multi_syllable_intent_layer(const candidate: TncCandidate): Integer;
var
    text_units: Integer;
    syllable_gap: Integer;
begin
    Result := 0;
    if m_last_lookup_syllable_count < 3 then
    begin
        Exit;
    end;

    text_units := get_candidate_text_unit_count(candidate.text);
    syllable_gap := m_last_lookup_syllable_count - text_units;

    if candidate.comment = '' then
    begin
        if text_units <= 0 then
        begin
            Result := 8;
        end
        else if text_units = 1 then
        begin
            Result := 6;
        end
        else if syllable_gap = 0 then
        begin
            Result := 0;
        end
        else if syllable_gap = 1 then
        begin
            Result := 1;
        end
        else if syllable_gap > 1 then
        begin
            Result := 2;
        end
        else
        begin
            Result := 5;
        end;
        Exit;
    end;

    if text_units <= 0 then
    begin
        Result := 9;
    end
    else if text_units = 1 then
    begin
        Result := 7;
    end
    else if text_units + 1 >= m_last_lookup_syllable_count then
    begin
        Result := 3;
    end
    else
    begin
        Result := 4;
    end;
end;

function TncEngine.get_text_context_bonus(const candidate_text: string): Integer;
const
    c_context_combined_cap = 620;
var
    context_value: string;
    count: Integer;
    local_bonus: Integer;
    persistent_bonus: Integer;
    context_variants: TArray<string>;
    variant_idx: Integer;
    variant_weight: Integer;
    variant_key: string;
    variant_bonus: Integer;
    secondary_bonus: Integer;

    function get_variant_weight(const variant_index: Integer): Integer;
    begin
        case variant_index of
            0:
                Result := 100;
            1:
                Result := 88;
            2:
                Result := 72;
            3:
                Result := 58;
        else
            Result := 42;
        end;
    end;

    function merge_variant_bonus(const current_bonus: Integer; const weighted_bonus: Integer): Integer;
    begin
        Result := current_bonus;
        if weighted_bonus <= 0 then
        begin
            Exit;
        end;

        if Result <= 0 then
        begin
            Result := weighted_bonus;
            Exit;
        end;

        if weighted_bonus > Result then
        begin
            Result := weighted_bonus + (Result div 3);
        end
        else
        begin
            Result := Result + (weighted_bonus div 3);
        end;

        if Result > c_context_combined_cap then
        begin
            Result := c_context_combined_cap;
        end;
    end;
begin
    if (candidate_text <> '') and (m_lookup_text_context_bonus_cache <> nil) and
        m_lookup_text_context_bonus_cache.TryGetValue(candidate_text, Result) then
    begin
        Exit;
    end;

    Result := 0;
    local_bonus := 0;
    persistent_bonus := 0;
    context_value := m_left_context;
    if m_segment_left_context <> '' then
    begin
        context_value := m_segment_left_context;
    end;
    if (m_segment_left_context = '') and (m_external_left_context <> '') then
    begin
        context_value := m_external_left_context;
    end;

    if (candidate_text = '') or (context_value = '') then
    begin
        Exit;
    end;

    context_variants := get_context_variants(context_value);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    if m_context_pairs <> nil then
    begin
        for variant_idx := 0 to High(context_variants) do
        begin
            variant_weight := get_variant_weight(variant_idx);

            variant_key := context_variants[variant_idx] + #1 + candidate_text;
            if not m_context_pairs.TryGetValue(variant_key, count) then
            begin
                Continue;
            end;

            variant_bonus := count * c_context_score_bonus;
            if variant_bonus > c_context_score_bonus_max then
            begin
                variant_bonus := c_context_score_bonus_max;
            end;
            variant_bonus := (variant_bonus * variant_weight) div 100;
            local_bonus := merge_variant_bonus(local_bonus, variant_bonus);
        end;
    end;

    if (m_dictionary <> nil) and (m_context_db_bonus_cache <> nil) then
    begin
        if m_context_db_bonus_cache_key <> context_value then
        begin
            m_context_db_bonus_cache.Clear;
            m_context_db_bonus_cache_key := context_value;
        end;

        for variant_idx := 0 to High(context_variants) do
        begin
            variant_weight := get_variant_weight(variant_idx);

            variant_key := context_variants[variant_idx] + #1 + candidate_text;
            if not m_context_db_bonus_cache.TryGetValue(variant_key, variant_bonus) then
            begin
                variant_bonus := m_dictionary.get_context_bonus(context_variants[variant_idx], candidate_text);
                m_context_db_bonus_cache.AddOrSetValue(variant_key, variant_bonus);
            end;

            variant_bonus := (variant_bonus * variant_weight) div 100;
            persistent_bonus := merge_variant_bonus(persistent_bonus, variant_bonus);
        end;
    end;

    if local_bonus >= persistent_bonus then
    begin
        Result := local_bonus;
        secondary_bonus := persistent_bonus;
    end
    else
    begin
        Result := persistent_bonus;
        secondary_bonus := local_bonus;
    end;

    if secondary_bonus > 0 then
    begin
        Inc(Result, secondary_bonus div 2);
    end;
    if Result > c_context_combined_cap then
    begin
        Result := c_context_combined_cap;
    end;

    if (candidate_text <> '') and (m_lookup_text_context_bonus_cache <> nil) then
    begin
        m_lookup_text_context_bonus_cache.AddOrSetValue(candidate_text, Result);
    end;
end;

function TncEngine.get_context_bonus(const candidate_text: string): Integer;
const
    c_context_total_cap = 760;
var
    text_context_bonus: Integer;
    phrase_context_bonus: Integer;
    context_query_bonus: Integer;
    context_query_latest_bonus: Integer;
    text_units: Integer;
begin
    if (candidate_text <> '') and (m_lookup_context_bonus_cache <> nil) and
        m_lookup_context_bonus_cache.TryGetValue(candidate_text, Result) then
    begin
        Exit;
    end;

    text_context_bonus := get_text_context_bonus(candidate_text);
    phrase_context_bonus := get_phrase_context_bonus(candidate_text);
    context_query_bonus := get_context_query_bonus(candidate_text);
    context_query_latest_bonus := get_context_query_latest_bonus(candidate_text);

    if text_context_bonus >= phrase_context_bonus then
    begin
        Result := text_context_bonus;
        if phrase_context_bonus > 0 then
        begin
            Inc(Result, phrase_context_bonus div 2);
        end;
    end
    else
    begin
        Result := phrase_context_bonus;
        if text_context_bonus > 0 then
        begin
            Inc(Result, text_context_bonus div 2);
        end;
    end;

    if context_query_bonus > 0 then
    begin
        Inc(Result, context_query_bonus);
        text_units := get_candidate_text_unit_count(candidate_text);
        if (m_last_lookup_syllable_count >= 2) and (text_units >= 2) then
        begin
            Inc(Result, Min(160, context_query_bonus div 3));
        end;
    end;
    if context_query_latest_bonus > 0 then
    begin
        Inc(Result, context_query_latest_bonus);
        if context_query_bonus > 0 then
        begin
            Inc(Result, Min(96, context_query_latest_bonus div 4));
        end;
    end;

    if Result > c_context_total_cap then
    begin
        Result := c_context_total_cap;
    end;

    if (candidate_text <> '') and (m_lookup_context_bonus_cache <> nil) then
    begin
        m_lookup_context_bonus_cache.AddOrSetValue(candidate_text, Result);
    end;
end;

function TncEngine.get_segment_path_preference_score(const encoded_path: string): Integer;
var
    normalized_path: string;
    path_penalty: Integer;
    prefix_penalty: Integer;
    recent_ranked_bonus: Integer;
    session_path_penalty: Integer;
    prefix_support: Integer;
    session_prefix_support: Integer;
    cached_result: Integer;
begin
    normalized_path := Trim(encoded_path);
    if get_encoded_path_segment_count_local(normalized_path) <= 1 then
    begin
        Exit(0);
    end;

    if (m_lookup_segment_path_preference_cache <> nil) and
        m_lookup_segment_path_preference_cache.TryGetValue(normalized_path, cached_result) then
    begin
        Exit(cached_result);
    end;

    Result := -(get_encoded_path_segment_count_local(normalized_path) * 18);
    if m_last_lookup_key <> '' then
    begin
        Inc(Result, get_session_query_path_bonus(m_last_lookup_key, normalized_path));
        session_path_penalty := get_session_query_path_penalty(m_last_lookup_key, normalized_path);
        if session_path_penalty > 0 then
        begin
            Dec(Result, session_path_penalty);
        end;
        session_prefix_support := get_session_query_path_prefix_bonus(m_last_lookup_key, normalized_path);
        if session_prefix_support > 0 then
        begin
            Inc(Result, session_prefix_support);
        end;
        recent_ranked_bonus := get_session_ranked_query_path_bonus(normalized_path);
        if recent_ranked_bonus > 0 then
        begin
            Inc(Result, recent_ranked_bonus);
        end;
        prefix_penalty := get_session_query_path_prefix_penalty(m_last_lookup_key, normalized_path);
        if prefix_penalty > 0 then
        begin
            Dec(Result, prefix_penalty);
        end;
        if m_dictionary <> nil then
        begin
            Inc(Result, m_dictionary.get_query_segment_path_bonus(m_last_lookup_key, normalized_path));
            path_penalty := m_dictionary.get_query_segment_path_penalty(m_last_lookup_key, normalized_path);
            if path_penalty > 0 then
            begin
                Dec(Result, path_penalty);
            end;
        end;
        prefix_support := get_persistent_query_path_prefix_support(normalized_path);
        if prefix_support <> 0 then
        begin
            Inc(Result, prefix_support);
        end;
    end;

    if m_lookup_segment_path_preference_cache <> nil then
    begin
        m_lookup_segment_path_preference_cache.AddOrSetValue(normalized_path, Result);
    end;
end;

function TncEngine.get_incremental_path_stability_bonus_for_path(const encoded_path: string): Integer;
const
    c_same_path_bonus = 96;
    c_extended_path_bonus = 240;
    c_single_step_extension_bonus = 40;
var
    current_query: string;
    previous_query: string;
begin
    Result := 0;
    current_query := normalize_pinyin_text(m_last_lookup_key);
    previous_query := normalize_pinyin_text(m_last_ranked_query_key);
    if (current_query = '') or (previous_query = '') or
        (current_query = previous_query) or
        (Length(current_query) <= Length(previous_query)) or
        (m_last_ranked_top_path = '') then
    begin
        Exit;
    end;

    if Copy(current_query, 1, Length(previous_query)) <> previous_query then
    begin
        Exit;
    end;

    if Length(current_query) - Length(previous_query) > 8 then
    begin
        Exit;
    end;

    if get_encoded_path_segment_count_local(encoded_path) <= 1 then
    begin
        Exit;
    end;

    if encoded_path = m_last_ranked_top_path then
    begin
        Result := c_same_path_bonus;
    end
    else if Copy(encoded_path, 1, Length(m_last_ranked_top_path) + 1) =
        (m_last_ranked_top_path + c_segment_path_separator) then
    begin
        Result := c_extended_path_bonus;
    end;

    if (Result > 0) and (Length(current_query) = Length(previous_query) + 1) then
    begin
        Inc(Result, c_single_step_extension_bonus);
    end;
end;

function TncEngine.get_incremental_path_stability_bonus(const candidate: TncCandidate): Integer;
var
    candidate_path: string;
begin
    Result := 0;
    if candidate.comment <> '' then
    begin
        Exit;
    end;

    candidate_path := get_segment_path_for_candidate(candidate);
    Result := get_incremental_path_stability_bonus_for_path(candidate_path);
end;

function TncEngine.get_segment_path_support_score(const candidate: TncCandidate): Integer;
var
    encoded_path: string;
    preference_score: Integer;
    stability_bonus: Integer;
begin
    Result := get_segment_path_context_bonus(candidate);
    encoded_path := get_segment_path_for_candidate(candidate);
    if encoded_path = '' then
    begin
        Exit;
    end;

    preference_score := get_segment_path_preference_score(encoded_path);
    if preference_score > 0 then
    begin
        Inc(Result, Min(260, preference_score div 2));
    end
    else if preference_score < 0 then
    begin
        Dec(Result, Min(180, Abs(preference_score) div 3));
    end;

    stability_bonus := get_incremental_path_stability_bonus(candidate);
    if stability_bonus > 0 then
    begin
        Inc(Result, stability_bonus);
    end;
end;

procedure TncEngine.get_recent_path_context_seed(out prev_prev_text: string; out prev_text: string);
var
    context_value: string;
    segment_count: Integer;
begin
    prev_prev_text := '';
    prev_text := '';

    context_value := Trim(m_segment_left_context);
    if context_value = '' then
    begin
        context_value := Trim(m_external_left_context);
    end;
    if context_value = '' then
    begin
        context_value := Trim(m_left_context);
    end;

    if (m_confirmed_segments <> nil) and (m_confirmed_segments.Count > 0) then
    begin
        segment_count := m_confirmed_segments.Count;
        prev_text := Trim(m_confirmed_segments[segment_count - 1].text);
        if segment_count >= 2 then
        begin
            prev_prev_text := Trim(m_confirmed_segments[segment_count - 2].text);
        end
        else if context_value <> '' then
        begin
            prev_prev_text := context_value;
        end;
        Exit;
    end;

    if context_value <> '' then
    begin
        prev_text := context_value;
    end;
end;

function TncEngine.get_segment_path_context_bonus(const candidate: TncCandidate): Integer;
var
    cache_key: string;
    encoded_path: string;
    path_segments: TArray<string>;
    segment_start: Integer;
    idx: Integer;
    segment_count: Integer;
    seed_prev_prev_text: string;
    seed_prev_text: string;
    current_prev_prev_text: string;
    current_prev_text: string;
    transition_bonus: Integer;
    path_penalty: Integer;
    session_path_penalty: Integer;
    prefix_support: Integer;
    session_prefix_support: Integer;
    session_prefix_penalty: Integer;

    function get_exact_context_pair_bonus(const left_text: string; const candidate_text: string): Integer;
    const
        c_segment_pair_context_cap = 520;
        c_segment_pair_bonus_scale = 75;
    var
        pair_key: string;
        local_bonus: Integer;
        persistent_bonus: Integer;
        count: Integer;
        secondary_bonus: Integer;
    begin
        Result := 0;
        if (left_text = '') or (candidate_text = '') then
        begin
            Exit;
        end;

        local_bonus := 0;
        persistent_bonus := 0;
        if m_context_pairs <> nil then
        begin
            pair_key := left_text + #1 + candidate_text;
            if m_context_pairs.TryGetValue(pair_key, count) and (count > 0) then
            begin
                local_bonus := count * c_context_score_bonus;
                if local_bonus > c_context_score_bonus_max then
                begin
                    local_bonus := c_context_score_bonus_max;
                end;
            end;
        end;

        if m_dictionary <> nil then
        begin
            persistent_bonus := m_dictionary.get_context_bonus(left_text, candidate_text);
        end;

        if local_bonus >= persistent_bonus then
        begin
            Result := local_bonus;
            secondary_bonus := persistent_bonus;
        end
        else
        begin
            Result := persistent_bonus;
            secondary_bonus := local_bonus;
        end;

        if secondary_bonus > 0 then
        begin
            Inc(Result, secondary_bonus div 2);
        end;
        if Result > c_segment_pair_context_cap then
        begin
            Result := c_segment_pair_context_cap;
        end;
        Result := (Result * c_segment_pair_bonus_scale) div 100;
    end;

    function get_phrase_trigram_transition_bonus(const prev_prev_text: string;
        const prev_text: string; const candidate_text: string): Integer;
    const
        c_segment_trigram_step = 96;
        c_segment_trigram_cap = 300;
        c_segment_trigram_recent_top = 140;
        c_segment_trigram_recent_mid = 84;
        c_segment_trigram_recent_tail = 40;
    var
        trigram_key: string;
        trigram_count: Integer;
        last_seen_serial: Int64;
        serial_gap: Int64;
    begin
        Result := 0;
        if (prev_prev_text = '') or (prev_text = '') or (candidate_text = '') or
            (m_phrase_context_pairs = nil) then
        begin
            Exit;
        end;

        trigram_key := prev_prev_text + #2 + prev_text + #1 + candidate_text;
        if (not m_phrase_context_pairs.TryGetValue(trigram_key, trigram_count)) or (trigram_count <= 0) then
        begin
            Exit;
        end;

        Result := trigram_count * c_segment_trigram_step;
        if Result > c_segment_trigram_cap then
        begin
            Result := c_segment_trigram_cap;
        end;

        if (m_phrase_context_last_seen <> nil) and
            m_phrase_context_last_seen.TryGetValue(trigram_key, last_seen_serial) and
            (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
        begin
            serial_gap := m_session_commit_serial - last_seen_serial;
            if serial_gap <= 1 then
            begin
                Inc(Result, c_segment_trigram_recent_top);
            end
            else if serial_gap <= 3 then
            begin
                Inc(Result, c_segment_trigram_recent_mid);
            end
            else if serial_gap <= 6 then
            begin
                Inc(Result, c_segment_trigram_recent_tail);
            end;
        end;
    end;

    function get_compound_prev_trigram_bonus(const combined_prev_text: string;
        const candidate_text: string): Integer;
    var
        combined_units: TArray<string>;
        split_idx: Integer;
        unit_idx: Integer;
        left_part: string;
        right_part: string;
        local_session_bonus: Integer;
        local_persistent_bonus: Integer;
        local_secondary_bonus: Integer;
        local_bonus: Integer;
    begin
        Result := 0;
        if (combined_prev_text = '') or (candidate_text = '') then
        begin
            Exit;
        end;

        combined_units := split_text_units(combined_prev_text);
        if Length(combined_units) < 2 then
        begin
            Exit;
        end;

        for split_idx := 1 to High(combined_units) do
        begin
            left_part := '';
            for unit_idx := 0 to split_idx - 1 do
            begin
                left_part := left_part + combined_units[unit_idx];
            end;

            right_part := '';
            for unit_idx := split_idx to High(combined_units) do
            begin
                right_part := right_part + combined_units[unit_idx];
            end;

            if (left_part = '') or (right_part = '') then
            begin
                Continue;
            end;

            local_session_bonus := get_phrase_trigram_transition_bonus(
                left_part, right_part, candidate_text);
            local_persistent_bonus := 0;
            if m_dictionary <> nil then
            begin
                local_persistent_bonus := m_dictionary.get_context_trigram_bonus(
                    left_part, right_part, candidate_text);
            end;

            if local_session_bonus >= local_persistent_bonus then
            begin
                local_bonus := local_session_bonus;
                local_secondary_bonus := local_persistent_bonus;
            end
            else
            begin
                local_bonus := local_persistent_bonus;
                local_secondary_bonus := local_session_bonus;
            end;

            if local_secondary_bonus > 0 then
            begin
                Inc(local_bonus, local_secondary_bonus div 2);
            end;

            if local_bonus > Result then
            begin
                Result := local_bonus;
            end;
        end;
    end;

    function get_path_transition_bonus(const prev_prev_text: string; const prev_text: string;
        const candidate_text: string): Integer;
    var
        pair_bonus: Integer;
        trigram_bonus: Integer;
        persistent_trigram_bonus: Integer;
        compound_prev_trigram_bonus: Integer;
        secondary_bonus: Integer;
    begin
        Result := 0;
        if (prev_text = '') or (candidate_text = '') then
        begin
            Exit;
        end;

        pair_bonus := get_exact_context_pair_bonus(prev_text, candidate_text);
        trigram_bonus := get_phrase_trigram_transition_bonus(prev_prev_text, prev_text, candidate_text);
        persistent_trigram_bonus := 0;
        if (prev_prev_text <> '') and (m_dictionary <> nil) then
        begin
            persistent_trigram_bonus := m_dictionary.get_context_trigram_bonus(
                prev_prev_text, prev_text, candidate_text);
        end;
        compound_prev_trigram_bonus := 0;
        if prev_prev_text = '' then
        begin
            compound_prev_trigram_bonus := get_compound_prev_trigram_bonus(prev_text, candidate_text);
        end;

        if trigram_bonus >= persistent_trigram_bonus then
        begin
            Result := trigram_bonus;
            secondary_bonus := persistent_trigram_bonus;
        end
        else
        begin
            Result := persistent_trigram_bonus;
            secondary_bonus := trigram_bonus;
        end;

        if secondary_bonus > 0 then
        begin
            Inc(Result, secondary_bonus div 2);
        end;
        if compound_prev_trigram_bonus > Result then
        begin
            Result := compound_prev_trigram_bonus;
        end;

        if Result > 0 then
        begin
            Inc(Result, pair_bonus div 2);
        end
        else
        begin
            Result := pair_bonus;
        end;
    end;
begin
    Result := 0;
    if m_dictionary = nil then
    begin
        Exit;
    end;

    encoded_path := get_segment_path_for_candidate(candidate);
    if (encoded_path = '') or (get_encoded_path_segment_count_local(encoded_path) <= 1) then
    begin
        Exit;
    end;

    cache_key := encoded_path;
    if candidate.comment <> '' then
    begin
        cache_key := 'P' + #1 + cache_key;
        if is_runtime_chain_candidate(candidate) then
        begin
            cache_key := cache_key + #1 + 'C';
        end;
    end;

    if (m_lookup_segment_path_context_bonus_cache <> nil) and
        m_lookup_segment_path_context_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    SetLength(path_segments, 0);
    segment_start := 1;
    for idx := 1 to Length(encoded_path) + 1 do
    begin
        if (idx <= Length(encoded_path)) and (encoded_path[idx] <> c_segment_path_separator) then
        begin
            Continue;
        end;

        if idx > segment_start then
        begin
            segment_count := Length(path_segments);
            SetLength(path_segments, segment_count + 1);
            path_segments[segment_count] := Copy(encoded_path, segment_start, idx - segment_start);
        end;
        segment_start := idx + 1;
    end;

    if Length(path_segments) <= 0 then
    begin
        Exit;
    end;

    get_recent_path_context_seed(seed_prev_prev_text, seed_prev_text);
    current_prev_prev_text := seed_prev_prev_text;
    current_prev_text := seed_prev_text;

    for idx := 0 to High(path_segments) do
    begin
        transition_bonus := get_path_transition_bonus(current_prev_prev_text, current_prev_text, path_segments[idx]);
        if transition_bonus > 0 then
        begin
            Inc(Result, transition_bonus);
        end;
        current_prev_prev_text := current_prev_text;
        current_prev_text := path_segments[idx];
    end;

    if m_last_lookup_key <> '' then
    begin
        transition_bonus := get_session_query_path_bonus(m_last_lookup_key, encoded_path);
        if transition_bonus > 0 then
        begin
            Inc(Result, transition_bonus);
        end;
        session_path_penalty := get_session_query_path_penalty(m_last_lookup_key, encoded_path);
        if session_path_penalty > 0 then
        begin
            Dec(Result, session_path_penalty);
        end;
        session_prefix_support := get_session_query_path_prefix_bonus(m_last_lookup_key, encoded_path);
        if session_prefix_support > 0 then
        begin
            Inc(Result, session_prefix_support);
        end;
        session_prefix_penalty := get_session_query_path_prefix_penalty(m_last_lookup_key, encoded_path);
        if session_prefix_penalty > 0 then
        begin
            Dec(Result, session_prefix_penalty);
        end;
        if m_dictionary <> nil then
        begin
            transition_bonus := m_dictionary.get_query_segment_path_bonus(m_last_lookup_key, encoded_path);
            if transition_bonus > 0 then
            begin
                Inc(Result, transition_bonus);
            end;
            path_penalty := m_dictionary.get_query_segment_path_penalty(m_last_lookup_key, encoded_path);
            if path_penalty > 0 then
            begin
                Dec(Result, path_penalty);
            end;
        end;
    end;
        prefix_support := get_persistent_query_path_prefix_support(encoded_path);
        if prefix_support <> 0 then
        begin
            Inc(Result, prefix_support);
        end;

    if candidate.comment <> '' then
    begin
        if is_runtime_chain_candidate(candidate) then
        begin
            Result := Result div 4;
        end
        else
        begin
            Result := (Result * 5) div 8;
            if get_candidate_text_unit_count(candidate.text) >= 2 then
            begin
                Inc(Result, Min(72, Result div 7));
            end;
        end;
    end;

    if m_lookup_segment_path_context_bonus_cache <> nil then
    begin
        m_lookup_segment_path_context_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncEngine.get_punctuation_char(const key_code: Word; const key_state: TncKeyState; out out_char: Char): Boolean;
begin
    Result := True;
    case key_code of
        Ord('1'):
            if key_state.shift_down then
            begin
                out_char := '!';
            end
            else
            begin
                Result := False;
            end;
        Ord('2'):
            if key_state.shift_down then
            begin
                out_char := '@';
            end
            else
            begin
                Result := False;
            end;
        Ord('3'):
            if key_state.shift_down then
            begin
                out_char := '#';
            end
            else
            begin
                Result := False;
            end;
        Ord('4'):
            if key_state.shift_down then
            begin
                out_char := '$';
            end
            else
            begin
                Result := False;
            end;
        Ord('5'):
            if key_state.shift_down then
            begin
                out_char := '%';
            end
            else
            begin
                Result := False;
            end;
        Ord('6'):
            if key_state.shift_down then
            begin
                out_char := '^';
            end
            else
            begin
                Result := False;
            end;
        Ord('7'):
            if key_state.shift_down then
            begin
                out_char := '&';
            end
            else
            begin
                Result := False;
            end;
        Ord('8'):
            if key_state.shift_down then
            begin
                out_char := '*';
            end
            else
            begin
                Result := False;
            end;
        Ord('9'):
            if key_state.shift_down then
            begin
                out_char := '(';
            end
            else
            begin
                Result := False;
            end;
        Ord('0'):
            if key_state.shift_down then
            begin
                out_char := ')';
            end
            else
            begin
                Result := False;
            end;
        VK_OEM_COMMA:
            if key_state.shift_down then
            begin
                out_char := '<';
            end
            else
            begin
                out_char := ',';
            end;
        VK_OEM_PERIOD:
            if key_state.shift_down then
            begin
                out_char := '>';
            end
            else
            begin
                out_char := '.';
            end;
        VK_OEM_1:
            if key_state.shift_down then
            begin
                out_char := ':';
            end
            else
            begin
                out_char := ';';
            end;
        VK_OEM_2:
            if key_state.shift_down then
            begin
                out_char := '?';
            end
            else
            begin
                out_char := '/';
            end;
        VK_OEM_3:
            if key_state.shift_down then
            begin
                out_char := '~';
            end
            else
            begin
                out_char := '`';
            end;
        VK_OEM_4:
            if key_state.shift_down then
            begin
                out_char := '{';
            end
            else
            begin
                out_char := '[';
            end;
        VK_OEM_5:
            if key_state.shift_down then
            begin
                out_char := '|';
            end
            else
            begin
                out_char := '\';
            end;
        VK_OEM_6:
            if key_state.shift_down then
            begin
                out_char := '}';
            end
            else
            begin
                out_char := ']';
            end;
        VK_OEM_7:
            if key_state.shift_down then
            begin
                out_char := '"';
            end
            else
            begin
                out_char := '''';
            end;
        VK_OEM_MINUS:
            if key_state.shift_down then
            begin
                out_char := '_';
            end
            else
            begin
                out_char := '-';
            end;
        VK_OEM_PLUS:
            if key_state.shift_down then
            begin
                out_char := '+';
            end
            else
            begin
                out_char := '=';
            end;
    else
        Result := False;
    end;
end;

function TncEngine.map_full_width_char(const input_char: Char): string;
begin
    if input_char = ' ' then
    begin
        Result := Char($3000);
        Exit;
    end;

    if (input_char >= '!') and (input_char <= '~') then
    begin
        Result := Char(Ord(input_char) + c_full_width_offset);
        Exit;
    end;

    Result := input_char;
end;

function TncEngine.map_punctuation_char(const input_char: Char): string;
begin
    if get_effective_punctuation_full_width then
    begin
        case input_char of
            ',':
                Result := Char($FF0C);
            '.':
                Result := Char($3002);
            '?':
                Result := Char($FF1F);
            '!':
                Result := Char($FF01);
            '@':
                Result := Char($FF20);
            '#':
                Result := Char($FF03);
            '$':
                Result := Char($FFE5);
            '%':
                Result := Char($FF05);
            '&':
                Result := Char($FF06);
            '*':
                Result := Char($FF0A);
            ':':
                Result := Char($FF1A);
            ';':
                Result := Char($FF1B);
            '/':
                Result := input_char;
            '\':
                Result := Char($3001);
            '(':
                Result := Char($FF08);
            ')':
                Result := Char($FF09);
            '[':
                Result := Char($3010);
            ']':
                Result := Char($3011);
            '{':
                Result := Char($300E);
            '}':
                Result := Char($300F);
            '<':
                Result := Char($300A);
            '>':
                Result := Char($300B);
            '''':
                begin
                    if m_single_quote_open then
                    begin
                        Result := Char($2019);
                    end
                    else
                    begin
                        Result := Char($2018);
                    end;
                    m_single_quote_open := not m_single_quote_open;
                end;
            '"':
                begin
                    if m_double_quote_open then
                    begin
                        Result := Char($201D);
                    end
                    else
                    begin
                        Result := Char($201C);
                    end;
                    m_double_quote_open := not m_double_quote_open;
                end;
            '`':
                Result := Char($00B7);
            '~':
                Result := Char($FF5E);
            '^':
                Result := Char($2026) + Char($2026);
            '-':
                Result := Char($FF0D);
            '_':
                Result := Char($2014) + Char($2014);
            '=':
                Result := Char($FF1D);
            '+':
                Result := Char($FF0B);
        else
            if m_config.full_width_mode then
            begin
                Result := map_full_width_char(input_char);
            end
            else
            begin
                Result := input_char;
            end;
        end;
        Exit;
    end;

    if m_config.full_width_mode then
    begin
        Result := map_full_width_char(input_char);
        Exit;
    end;

    Result := input_char;
end;

function TncEngine.get_effective_punctuation_full_width: Boolean;
begin
    Result := (m_config.input_mode <> im_english) and m_config.punctuation_full_width;
end;

function TncEngine.get_direct_ascii_commit_text(const key_code: Word; const key_state: TncKeyState;
    out out_text: string): Boolean;
var
    key_char: Char;
    display_key_char: Char;
    punct_char: Char;
begin
    out_text := '';

    if m_config.full_width_mode and is_alpha_key(key_code, key_state, key_char, display_key_char) then
    begin
        out_text := map_full_width_char(display_key_char);
        Exit(True);
    end;

    if m_config.full_width_mode and (key_code >= Ord('0')) and (key_code <= Ord('9')) and
        (not key_state.shift_down) then
    begin
        out_text := map_full_width_char(Char(key_code));
        Exit(True);
    end;

    if m_config.full_width_mode and (key_code = VK_SPACE) then
    begin
        out_text := map_full_width_char(' ');
        Exit(True);
    end;

    if (get_effective_punctuation_full_width or m_config.full_width_mode) and
        get_punctuation_char(key_code, key_state, punct_char) then
    begin
        out_text := map_punctuation_char(punct_char);
        Exit(True);
    end;

    Result := False;
end;

function TncEngine.get_raw_composition_commit_text: string;
var
    source_text: string;
    idx: Integer;
begin
    if m_composition_display_text <> '' then
    begin
        source_text := m_composition_display_text;
    end
    else
    begin
        source_text := m_composition_text;
    end;

    if (not m_config.full_width_mode) or (source_text = '') then
    begin
        Exit(source_text);
    end;

    Result := '';
    SetLength(Result, 0);
    for idx := 1 to Length(source_text) do
    begin
        Result := Result + map_full_width_char(source_text[idx]);
    end;
end;

function TncEngine.get_rank_score(const candidate: TncCandidate): Integer;
var
    context_bonus: Integer;
    segment_path_context_bonus: Integer;
    session_bonus: Integer;
    query_bonus: Integer;
    text_units: Integer;
    syllable_gap: Integer;
    is_single_syllable_single_char_lookup: Boolean;
begin
    Result := candidate.score;
    text_units := get_candidate_text_unit_count(candidate.text);
    is_single_syllable_single_char_lookup := (m_last_lookup_syllable_count = 1) and
        (candidate.comment = '') and (text_units = 1);
    context_bonus := get_context_bonus(candidate.text);
    if m_last_lookup_normalized_from <> '' then
    begin
        // When we auto-correct a likely adjacent-swap typo (e.g. chagn->chang),
        // reduce context influence so lexical score dominates.
        context_bonus := context_bonus div 4;
    end;
    if is_single_syllable_single_char_lookup then
    begin
        context_bonus := 0;
    end;
    Inc(Result, context_bonus);
    segment_path_context_bonus := get_segment_path_context_bonus(candidate);
    if is_single_syllable_single_char_lookup then
    begin
        segment_path_context_bonus := 0;
    end;
    Inc(Result, segment_path_context_bonus);
    query_bonus := get_session_query_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        query_bonus := query_bonus div 2;
    end;
    Inc(Result, query_bonus);
    session_bonus := get_session_text_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        session_bonus := session_bonus div 2;
    end;
    if is_single_syllable_single_char_lookup then
    begin
        session_bonus := 0;
    end;
    Inc(Result, session_bonus);

    // For one-syllable full-pinyin lookups, keep single-char candidates ahead.
    if (m_last_lookup_syllable_count = 1) and (candidate.comment = '') then
    begin
        if text_units > 1 then
        begin
            Dec(Result, (text_units - 1) * 180);
        end;
    end;

    // For multi-syllable lookups, rank candidates by intent layers:
    // complete phrases > near-complete phrase chunks > shorter chunks >
    // single-char fallbacks. This keeps long input usable even when the raw
    // lexicon contains high-weight noisy short heads.
    if (m_last_lookup_syllable_count >= 3) and (candidate.comment = '') then
    begin
        text_units := get_candidate_text_unit_count(candidate.text);
        if text_units >= 2 then
        begin
            syllable_gap := m_last_lookup_syllable_count - text_units;
            if syllable_gap = 0 then
            begin
                Inc(Result, 520 + (text_units * 24));
            end;
            if syllable_gap = 1 then
            begin
                Inc(Result, 260);
            end
            else if syllable_gap < 0 then
            begin
                Dec(Result, Abs(syllable_gap) * 120);
            end
            else
            begin
                Dec(Result, syllable_gap * 220);
            end;

            if (m_last_lookup_syllable_count >= 4) and (text_units >= 3) and
                (text_units + 1 >= m_last_lookup_syllable_count) then
            begin
                Inc(Result, 80);
            end;
        end
        else
        begin
            Dec(Result, 620);
        end;

        if is_runtime_chain_candidate(candidate) then
        begin
            if (context_bonus + session_bonus) <= 0 then
            begin
                Dec(Result, 160);
            end;
            if m_last_lookup_syllable_count >= 4 then
            begin
                Dec(Result, (m_last_lookup_syllable_count - 3) * 90);
            end;
        end
        else if (candidate.source = cs_rule) and (not candidate.has_dict_weight) and
            (not is_runtime_common_pattern_candidate(candidate)) and
            (not is_runtime_redup_candidate(candidate)) then
        begin
            if (context_bonus + session_bonus) <= 0 then
            begin
                Dec(Result, 120);
            end;
            if text_units <= 2 then
            begin
                Dec(Result, 160);
            end;
        end;
    end;

    if candidate.comment <> '' then
    begin
        if m_last_lookup_syllable_count >= 3 then
        begin
            text_units := get_candidate_text_unit_count(candidate.text);
            if text_units >= 2 then
            begin
                if text_units + 1 >= m_last_lookup_syllable_count then
                begin
                    Inc(Result, 340);
                end
                else if text_units + 2 >= m_last_lookup_syllable_count then
                begin
                    Inc(Result, 120);
                end
                else
                begin
                    Dec(Result, 180 + ((m_last_lookup_syllable_count - text_units - 2) * 140));
                end;
            end
            else
            begin
                Dec(Result, 760);
            end;
        end;

        // Segment fallback candidates with remaining pinyin (e.g. "... ti")
        // should stay available but rank below complete phrase candidates.
        Dec(Result, c_partial_candidate_score_penalty);
    end;

    // Generic runtime chains with productive/friendly tails (e.g. ...吗/个/点) are
    // useful fallback phrases, but when an exact lexicon phrase already competes for
    // the same query they should stop behaving like the default top result.
    Inc(Result, get_front_row_confidence_bonus(candidate));

    case candidate.source of
        cs_user:
            Inc(Result, c_user_score_bonus);
    end;
end;

function TncEngine.match_single_char_candidate_for_syllable(const syllable_text: string;
    const unit_text: string; out out_preferred: Boolean): Boolean;
const
    c_partial_preferred_min_weight = 120;
    c_partial_preferred_max_rank = 4;
    c_partial_preferred_top_ratio_pct = 85;
var
    results: TncCandidateList;
    idx: Integer;
    candidate_text: string;
    normalized_syllable: string;
    normalized_unit: string;
    weight_value: Integer;
    top_weight_value: Integer;
    match_rank: Integer;
    single_char_rank: Integer;
begin
    Result := False;
    out_preferred := False;
    normalized_syllable := Trim(syllable_text);
    normalized_unit := Trim(unit_text);
    if (m_dictionary = nil) or (normalized_syllable = '') or (normalized_unit = '') then
    begin
        Exit;
    end;
    if get_candidate_text_unit_count(unit_text) <> 1 then
    begin
        Exit;
    end;

    // For explicit apostrophe alignment, exact single-char existence must not
    // depend on whether the char happens to appear inside the short lookup
    // shortlist for this syllable. Queries like "ji'an"/"ji'e" should still
    // preserve complete phrases such as "季胺/吉安/饥饿" even when "季/饥/胺/饿"
    // are not near the top of the bare single-char bucket.
    if not m_dictionary.single_char_matches_pinyin(normalized_syllable, normalized_unit) then
    begin
        Exit;
    end;

    if not m_dictionary.lookup(normalized_syllable, results) then
    begin
        Result := True;
        Exit;
    end;

    top_weight_value := 0;
    match_rank := 0;
    single_char_rank := 0;
    for idx := 0 to High(results) do
    begin
        candidate_text := Trim(results[idx].text);
        if (candidate_text = '') or (get_candidate_text_unit_count(candidate_text) <> 1) then
        begin
            Continue;
        end;

        Inc(single_char_rank);
        if results[idx].has_dict_weight then
        begin
            weight_value := results[idx].dict_weight;
        end
        else
        begin
            weight_value := results[idx].score;
        end;
        if top_weight_value <= 0 then
        begin
            top_weight_value := weight_value;
        end;
        if not SameText(candidate_text, normalized_unit) then
        begin
            Continue;
        end;

        if match_rank = 0 then
        begin
            match_rank := single_char_rank;
        end;
        out_preferred := (weight_value >= c_partial_preferred_min_weight) and
            ((match_rank <= c_partial_preferred_max_rank) or
            (top_weight_value <= 0) or
            ((weight_value * 100) >= (top_weight_value * c_partial_preferred_top_ratio_pct)));
        Result := True;
        Exit;
    end;

    Result := True;
end;

function TncEngine.is_weak_single_char_chain_candidate_for_query(const query_key: string;
    const candidate: TncCandidate): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    text_units: TArray<string>;
    normalized_query: string;
    idx: Integer;
    is_preferred: Boolean;
    has_weak_unit: Boolean;
begin
    Result := False;
    if candidate.comment <> '' then
    begin
        Exit;
    end;

    normalized_query := normalize_pinyin_text(query_key);
    if normalized_query = '' then
    begin
        normalized_query := normalize_pinyin_text(m_composition_text);
    end;
    if normalized_query = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.Create;
    try
        syllables := parser.parse(normalized_query);
    finally
        parser.Free;
    end;

    if Length(syllables) < 2 then
    begin
        Exit;
    end;

    text_units := split_text_units(Trim(candidate.text));
    if Length(text_units) <> Length(syllables) then
    begin
        Exit;
    end;

    has_weak_unit := False;
    for idx := 0 to High(text_units) do
    begin
        if not match_single_char_candidate_for_syllable(syllables[idx].text, text_units[idx], is_preferred) then
        begin
            Exit(False);
        end;
        if not is_preferred then
        begin
            has_weak_unit := True;
        end;
    end;

    Result := has_weak_unit;
end;

function TncEngine.is_problematic_single_char_chain_candidate_for_query(const query_key: string;
    const candidate: TncCandidate): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    text_units: TArray<string>;
    normalized_query: string;
    idx: Integer;
    is_preferred: Boolean;
begin
    Result := False;
    if candidate.comment <> '' then
    begin
        Exit;
    end;

    // Only suppress low-evidence user chains and runtime-composed single-char
    // chains. Exact lexicon phrases like "好吧/有点" must not be treated as
    // problematic just because they also align with per-syllable single chars.
    if (not is_runtime_chain_candidate(candidate)) and
        (candidate.source <> cs_user) then
    begin
        Exit;
    end;

    normalized_query := normalize_pinyin_text(query_key);
    if normalized_query = '' then
    begin
        normalized_query := normalize_pinyin_text(m_composition_text);
    end;
    if normalized_query = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.Create;
    try
        syllables := parser.parse(normalized_query);
    finally
        parser.Free;
    end;

    if Length(syllables) < 2 then
    begin
        Exit;
    end;

    for idx := 0 to High(syllables) do
    begin
        // Skip all-initial / dangling-initial queries; weak-chain heuristics are
        // only meaningful for fully specified multi-syllable input.
        if Length(Trim(syllables[idx].text)) <= 1 then
        begin
            Exit(False);
        end;
    end;

    if is_weak_single_char_chain_candidate_for_query(normalized_query, candidate) then
    begin
        Exit(True);
    end;

    if not is_runtime_chain_candidate(candidate) then
    begin
        Exit(False);
    end;

    text_units := split_text_units(Trim(candidate.text));
    if Length(text_units) <> Length(syllables) then
    begin
        Exit;
    end;

    for idx := 0 to High(text_units) do
    begin
        if not match_single_char_candidate_for_syllable(syllables[idx].text, text_units[idx], is_preferred) then
        begin
            Exit(False);
        end;
    end;

    Result := is_runtime_constructed_phrase_friendly(candidate.text);
end;

function TncEngine.has_competing_exact_phrase_candidate(const selected_text: string): Boolean;
var
    idx: Integer;
    candidate: TncCandidate;
begin
    Result := False;
    for idx := 0 to High(m_candidates) do
    begin
        candidate := m_candidates[idx];
        if (candidate.comment <> '') or (candidate.text = '') or SameText(candidate.text, selected_text) then
        begin
            Continue;
        end;
        if get_candidate_text_unit_count(candidate.text) < 2 then
        begin
            Continue;
        end;
        if candidate.has_dict_weight or
            ((candidate.source = cs_rule) and
            (not is_runtime_chain_candidate(candidate)) and
            (not is_runtime_common_pattern_candidate(candidate)) and
            (not is_runtime_redup_candidate(candidate))) then
        begin
            Exit(True);
        end;
    end;
end;

function TncEngine.get_candidate_debug_summary(const candidate: TncCandidate): string;
var
    text_context_bonus: Integer;
    phrase_context_bonus: Integer;
    context_query_bonus: Integer;
    context_query_latest_bonus: Integer;
    context_bonus: Integer;
    segment_path_context_bonus: Integer;
    query_bonus: Integer;
    session_bonus: Integer;
    rank_score: Integer;
    layer_value: Integer;
    runtime_kind: string;
    path_confidence_tier: Integer;
    path_confidence_score: Integer;
begin
    text_context_bonus := get_text_context_bonus(candidate.text);
    phrase_context_bonus := get_phrase_context_bonus(candidate.text);
    context_query_bonus := get_context_query_bonus(candidate.text);
    context_query_latest_bonus := get_context_query_latest_bonus(candidate.text);
    context_bonus := get_context_bonus(candidate.text);
    segment_path_context_bonus := get_segment_path_context_bonus(candidate);
    query_bonus := get_session_query_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        query_bonus := query_bonus div 2;
    end;
    session_bonus := get_session_text_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        session_bonus := session_bonus div 2;
    end;
    rank_score := get_rank_score(candidate);
    layer_value := get_multi_syllable_intent_layer(candidate);
    runtime_kind := get_runtime_candidate_kind(candidate);
    path_confidence_score := get_candidate_path_confidence_score(candidate);
    path_confidence_tier := get_candidate_path_confidence_tier(candidate);

    Result := Format(
        'top=[%s src=%d rank=%d ctx=%d text_ctx=%d phr_ctx=%d spath_ctx=%d qctx=%d qctxl=%d qsess=%d sess=%d layer=%d path_conf=%d path_score=%d partial=%d dw=%d rt=%s]',
        [candidate.text, Ord(candidate.source), rank_score, context_bonus, text_context_bonus,
        phrase_context_bonus, segment_path_context_bonus, context_query_bonus, context_query_latest_bonus, query_bonus,
        session_bonus, layer_value, path_confidence_tier, path_confidence_score,
        Ord(candidate.comment <> ''), candidate.dict_weight, runtime_kind]);
end;

procedure TncEngine.sort_candidates(var candidates: TncCandidateList);
type
    TncCandidateSortItem = record
        candidate: TncCandidate;
        rank_score: Integer;
        layer: Integer;
        confidence_rank: Integer;
        path_confidence_score: Integer;
        conservative_margin: Integer;
        source_rank: Integer;
        text_length: Integer;
        text_units: Integer;
        is_latest_context_query_choice: Boolean;
        is_latest_query_choice: Boolean;
        is_weak_single_char_chain: Boolean;
        is_problematic_single_char_chain: Boolean;
        is_weighted_complete_phrase: Boolean;
        is_runtime_constructed_complete_phrase: Boolean;
        is_prioritized_user_phrase: Boolean;
        is_boundary_anchor_partial: Boolean;
        is_weighted_partial_phrase: Boolean;
        is_complete_phrase_prefix_partial: Boolean;
        is_supported_head_phrase_partial: Boolean;
        partial_comment_syllables: Integer;
        is_one_plus_two_partial: Boolean;
        is_two_plus_one_partial: Boolean;
        is_demonstrative_head_friendly_partial: Boolean;
        is_fixed_top_single_char: Boolean;
    end;
var
    list: TList<TncCandidateSortItem>;
    item: TncCandidateSortItem;
    i: Integer;
    use_intent_layers: Boolean;
    has_strong_complete_phrase: Boolean;
    has_competing_exact_phrase: Boolean;
    has_weighted_complete_phrase: Boolean;
    weak_chain_query_syllables: TncPinyinParseResult;
    weak_chain_preference_maps: TArray<TDictionary<string, Byte>>;
    weak_chain_query_prepared: Boolean;
    weak_chain_normalized_query: string;
    candidate_path_score_hint: Integer;
    partial_comment_syllable_cache: TDictionary<string, Integer>;
    best_one_plus_two_partial_score: Integer;
    best_two_plus_one_partial_score: Integer;
    has_boundary_anchor_one_plus_two: Boolean;
    has_boundary_anchor_two_plus_one: Boolean;
    preferred_three_syllable_partial_kind: Integer;
    fixed_top_single_char_text: string;
const
    c_boundary_anchor_partial_score_hint_flag = 1000000;
    c_boundary_anchor_partial_shape_kind_scale = 10000;
    c_boundary_anchor_partial_shape_one_plus_two = 1;
    c_boundary_anchor_partial_shape_two_plus_one = 2;
    c_three_syllable_boundary_ratio_pct = 100;
    c_three_syllable_partial_shape_margin = 24;
    c_demonstrative_head_friendly_partial_rank_bonus = 220;
    c_strong_exact_partial_shape_penalty = 240;
    c_complete_phrase_prefix_partial_rank_bonus = 420;
    c_complete_phrase_prefix_partial_override_gap = 120;
    c_supported_head_phrase_partial_rank_bonus = 420;
    c_supported_head_phrase_partial_override_gap = 0;
    c_supported_head_phrase_first_single_margin = 180;
    c_supported_head_phrase_tail_ratio_pct = 80;
    function get_fixed_top_single_char_for_query_local: string;
    var
        normalized_query: string;
    begin
        Result := '';
        if m_last_lookup_syllable_count <> 1 then
        begin
            Exit;
        end;

        normalized_query := normalize_pinyin_text(m_last_lookup_key);
        if normalized_query = 'en' then
        begin
            Result := string(Char($55EF));
        end
        else if normalized_query = 'ba' then
        begin
            Result := string(Char($5427));
        end
        else if normalized_query = 'e' then
        begin
            Result := string(Char($5443));
        end
        else if normalized_query = 'o' then
        begin
            Result := string(Char($54E6));
        end
        else if normalized_query = 'ha' then
        begin
            Result := string(Char($54C8));
        end
        else if normalized_query = 'xi' then
        begin
            Result := string(Char($563B));
        end
        else if normalized_query = 'xing' then
        begin
            Result := string(Char($884C));
        end
        else if normalized_query = 'hao' then
        begin
            Result := string(Char($597D));
        end
        else if normalized_query = 'ku' then
        begin
            Result := string(Char($9177));
        end
        else if normalized_query = 'bang' then
        begin
            Result := string(Char($68D2));
        end
        else if normalized_query = 'ya' then
        begin
            Result := string(Char($5440));
        end
        else if normalized_query = 'qie' then
        begin
            Result := string(Char($5207));
        end
        else if normalized_query = 'ca' then
        begin
            Result := string(Char($64E6));
        end
        else if normalized_query = 'gun' then
        begin
            Result := string(Char($6EDA));
        end
        else if normalized_query = 'hei' then
        begin
            Result := string(Char($563F));
        end
        else if normalized_query = 'pi' then
        begin
            Result := string(Char($5C41));
        end
        else if normalized_query = 'de' then
        begin
            Result := string(Char($7684));
        end
        else if normalized_query = 'zhe' then
        begin
            Result := string(Char($8FD9));
        end
        else if normalized_query = 'er' then
        begin
            Result := string(Char($800C));
        end
        else if normalized_query = 'he' then
        begin
            Result := string(Char($548C));
        end
        else if normalized_query = 'qing' then
        begin
            Result := string(Char($8BF7));
        end
    end;
    function get_partial_comment_syllable_count(const comment_text: string): Integer;
    var
        normalized_comment: string;
    begin
        Result := 0;
        normalized_comment := normalize_pinyin_text(comment_text);
        if normalized_comment = '' then
        begin
            Exit;
        end;
        if partial_comment_syllable_cache.TryGetValue(normalized_comment, Result) then
        begin
            Exit;
        end;
        Result := get_effective_compact_pinyin_unit_count(normalized_comment);
        partial_comment_syllable_cache.AddOrSetValue(normalized_comment, Result);
    end;
    function is_exact_phrase_candidate_for_ranking(const candidate: TncCandidate): Boolean;
    begin
        Result := (candidate.comment = '') and
            (get_candidate_text_unit_count(candidate.text) >= 2) and
            (candidate.has_dict_weight or (candidate.source = cs_user) or
            ((candidate.source = cs_rule) and
            (not is_runtime_chain_candidate(candidate)) and
            (not is_runtime_common_pattern_candidate(candidate)) and
            (not is_runtime_redup_candidate(candidate))));
    end;
    function is_complete_phrase_prefix_partial_candidate(const partial_candidate: TncCandidate;
        const partial_units: Integer; const partial_comment_syllables: Integer): Boolean;
    var
        idx: Integer;
        unit_idx: Integer;
        partial_text_units: TArray<string>;
        complete_text_units: TArray<string>;
        matches_prefix: Boolean;
    begin
        Result := False;
        if (partial_candidate.comment = '') or (partial_units < 2) or
            (partial_comment_syllables <= 0) or
            (partial_units + partial_comment_syllables <> m_last_lookup_syllable_count) then
        begin
            Exit;
        end;

        partial_text_units := split_text_units(Trim(partial_candidate.text));
        if Length(partial_text_units) <> partial_units then
        begin
            Exit;
        end;

        for idx := 0 to High(candidates) do
        begin
            if not is_exact_phrase_candidate_for_ranking(candidates[idx]) then
            begin
                Continue;
            end;
            if get_candidate_text_unit_count(candidates[idx].text) <>
                m_last_lookup_syllable_count then
            begin
                Continue;
            end;

            complete_text_units := split_text_units(Trim(candidates[idx].text));
            if Length(complete_text_units) <> m_last_lookup_syllable_count then
            begin
                Continue;
            end;

            matches_prefix := True;
            for unit_idx := 0 to partial_units - 1 do
            begin
                if complete_text_units[unit_idx] <> partial_text_units[unit_idx] then
                begin
                    matches_prefix := False;
                    Break;
                end;
            end;
            if matches_prefix then
            begin
                Exit(True);
            end;
        end;
    end;
    function is_supported_head_phrase_partial_candidate(const sort_item: TncCandidateSortItem): Boolean;
    begin
        Result := False;
        if (m_last_lookup_syllable_count <> 3) or
            (preferred_three_syllable_partial_kind <> 1) or
            (not sort_item.is_two_plus_one_partial) then
        begin
            Exit;
        end;
        if (m_last_three_syllable_head_exact_text = '') or
            (Trim(sort_item.candidate.text) <> m_last_three_syllable_head_exact_text) then
        begin
            Exit;
        end;

        if m_last_three_syllable_head_strength <= 0 then
        begin
            Exit;
        end;
        if m_last_three_syllable_head_strength <
            (m_last_three_syllable_first_single_strength +
            c_supported_head_phrase_first_single_margin) then
        begin
            Exit;
        end;

        if m_last_three_syllable_head_path_bonus > 0 then
        begin
            Exit(True);
        end;

        if m_last_three_syllable_tail_strength <= 0 then
        begin
            Exit(True);
        end;

        Result := (m_last_three_syllable_head_strength * 100) >=
            (m_last_three_syllable_tail_strength *
            c_supported_head_phrase_tail_ratio_pct);
    end;
    function get_cached_single_char_preference(const syllable_index: Integer;
        const unit_text: string; out out_matched: Boolean): Boolean;
    const
        c_partial_preferred_min_weight = 120;
        c_partial_preferred_max_rank = 4;
        c_partial_preferred_top_ratio_pct = 85;
    var
        cache_map: TDictionary<string, Byte>;
        results: TncCandidateList;
        idx: Integer;
        candidate_text: string;
        trimmed_unit_text: string;
        stored_state: Byte;
        weight_value: Integer;
        top_weight_value: Integer;
        single_char_rank: Integer;
        preferred: Boolean;
    begin
        Result := False;
        out_matched := False;
        if (syllable_index < 0) or (syllable_index > High(weak_chain_query_syllables)) then
        begin
            Exit;
        end;

        trimmed_unit_text := Trim(unit_text);
        if trimmed_unit_text = '' then
        begin
            Exit;
        end;

        cache_map := weak_chain_preference_maps[syllable_index];
        if cache_map = nil then
        begin
            cache_map := TDictionary<string, Byte>.Create;
            weak_chain_preference_maps[syllable_index] := cache_map;
            if (m_dictionary <> nil) and m_dictionary.lookup(Trim(weak_chain_query_syllables[syllable_index].text), results) then
            begin
                top_weight_value := 0;
                single_char_rank := 0;
                for idx := 0 to High(results) do
                begin
                    candidate_text := Trim(results[idx].text);
                    if (candidate_text = '') or (get_candidate_text_unit_count(candidate_text) <> 1) then
                    begin
                        Continue;
                    end;

                    Inc(single_char_rank);
                    if results[idx].has_dict_weight then
                    begin
                        weight_value := results[idx].dict_weight;
                    end
                    else
                    begin
                        weight_value := results[idx].score;
                    end;
                    if top_weight_value <= 0 then
                    begin
                        top_weight_value := weight_value;
                    end;

                    preferred := (weight_value >= c_partial_preferred_min_weight) and
                        ((single_char_rank <= c_partial_preferred_max_rank) or
                        (top_weight_value <= 0) or
                        ((weight_value * 100) >= (top_weight_value * c_partial_preferred_top_ratio_pct)));
                    if preferred then
                    begin
                        stored_state := 2;
                    end
                    else
                    begin
                        stored_state := 1;
                    end;
                    if not cache_map.ContainsKey(candidate_text) then
                    begin
                        cache_map.Add(candidate_text, stored_state);
                    end;
                end;
            end;
        end;

        if cache_map.TryGetValue(trimmed_unit_text, stored_state) then
        begin
            out_matched := True;
            Result := stored_state = 2;
        end;
    end;
    procedure prepare_weak_chain_query_cache;
    var
        parser: TncPinyinParser;
        idx: Integer;
    begin
        if weak_chain_query_prepared then
        begin
            Exit;
        end;

        weak_chain_query_prepared := True;
        weak_chain_normalized_query := normalize_pinyin_text(m_last_lookup_key);
        if weak_chain_normalized_query = '' then
        begin
            weak_chain_normalized_query := normalize_pinyin_text(m_composition_text);
        end;
        if weak_chain_normalized_query = '' then
        begin
            Exit;
        end;

        parser := TncPinyinParser.Create;
        try
            weak_chain_query_syllables := parser.parse(weak_chain_normalized_query);
        finally
            parser.Free;
        end;

        if Length(weak_chain_query_syllables) < 2 then
        begin
            SetLength(weak_chain_query_syllables, 0);
            Exit;
        end;

        for idx := 0 to High(weak_chain_query_syllables) do
        begin
            if Length(Trim(weak_chain_query_syllables[idx].text)) <= 1 then
            begin
                SetLength(weak_chain_query_syllables, 0);
                Exit;
            end;
        end;

        SetLength(weak_chain_preference_maps, Length(weak_chain_query_syllables));
    end;
    function is_weighted_complete_phrase_candidate(const candidate: TncCandidate): Boolean;
    var
        encoded_path: string;
    begin
        Result := (candidate.comment = '') and candidate.has_dict_weight and
            (get_candidate_text_unit_count(candidate.text) >= 2);
        if Result then
        begin
            Exit;
        end;

        if (candidate.comment <> '') or
            (m_last_lookup_syllable_count < c_long_sentence_full_path_min_syllables) or
            (get_candidate_text_unit_count(candidate.text) < 2) or
            is_runtime_chain_candidate(candidate) or
            is_runtime_common_pattern_candidate(candidate) or
            is_runtime_redup_candidate(candidate) then
        begin
            Exit(False);
        end;

        encoded_path := get_segment_path_for_candidate(candidate);
        Result := get_encoded_path_segment_count_local(encoded_path) > 1;
    end;
    function is_runtime_constructed_complete_phrase_candidate(const candidate: TncCandidate): Boolean;
    begin
        Result := (candidate.comment = '') and (get_candidate_text_unit_count(candidate.text) >= 2) and
            (is_runtime_chain_candidate(candidate) or
            is_runtime_common_pattern_candidate(candidate) or
            is_runtime_redup_candidate(candidate));
    end;
    function is_weak_single_char_chain_candidate_cached(const candidate: TncCandidate): Boolean;
    var
        text_units: TArray<string>;
        idx: Integer;
        is_preferred: Boolean;
        is_matched: Boolean;
        has_weak_unit: Boolean;
    begin
        Result := False;
        if candidate.comment <> '' then
        begin
            Exit;
        end;

        prepare_weak_chain_query_cache;
        if Length(weak_chain_query_syllables) < 2 then
        begin
            Exit;
        end;

        text_units := split_text_units(Trim(candidate.text));
        if Length(text_units) <> Length(weak_chain_query_syllables) then
        begin
            Exit;
        end;

        has_weak_unit := False;
        for idx := 0 to High(text_units) do
        begin
            is_preferred := get_cached_single_char_preference(idx, text_units[idx], is_matched);
            if not is_matched then
            begin
                Exit(False);
            end;
            if not is_preferred then
            begin
                has_weak_unit := True;
            end;
        end;

        Result := has_weak_unit;
    end;
    function is_problematic_single_char_chain_candidate_cached(const candidate: TncCandidate): Boolean;
    var
        text_units: TArray<string>;
        idx: Integer;
        is_matched: Boolean;
    begin
        Result := False;
        if candidate.comment <> '' then
        begin
            Exit;
        end;

        if (not is_runtime_chain_candidate(candidate)) and
            (candidate.source <> cs_user) then
        begin
            Exit;
        end;

        prepare_weak_chain_query_cache;
        if Length(weak_chain_query_syllables) < 2 then
        begin
            Exit;
        end;

        if is_weak_single_char_chain_candidate_cached(candidate) then
        begin
            Exit(True);
        end;

        if not is_runtime_chain_candidate(candidate) then
        begin
            Exit(False);
        end;

        text_units := split_text_units(Trim(candidate.text));
        if Length(text_units) <> Length(weak_chain_query_syllables) then
        begin
            Exit;
        end;

        for idx := 0 to High(text_units) do
        begin
            get_cached_single_char_preference(idx, text_units[idx], is_matched);
            if not is_matched then
            begin
                Exit(False);
            end;
        end;

        Result := is_runtime_constructed_phrase_friendly(candidate.text);
    end;

    function is_demonstrative_head_friendly_partial_candidate_cached(
        const candidate: TncCandidate): Boolean;
    var
        expected_head_text: string;
        normalized_comment: string;
        expected_comment: string;
        tail_syllable_text: string;
    begin
        Result := False;
        if candidate.comment = '' then
        begin
            Exit;
        end;

        prepare_weak_chain_query_cache;
        if Length(weak_chain_query_syllables) < 2 then
        begin
            Exit;
        end;

        expected_head_text := '';
        if SameText(weak_chain_query_syllables[0].text, 'zhe') then
        begin
            expected_head_text := string(Char($8FD9));
        end
        else if SameText(weak_chain_query_syllables[0].text, 'na') or
            SameText(weak_chain_query_syllables[0].text, 'nei') then
        begin
            expected_head_text := string(Char($90A3));
        end;
        if expected_head_text = '' then
        begin
            Exit;
        end;
        if Trim(candidate.text) <> expected_head_text then
        begin
            Exit;
        end;

        if Length(weak_chain_query_syllables) = 2 then
        begin
            tail_syllable_text := weak_chain_query_syllables[1].text;
        end
        else if (Length(weak_chain_query_syllables) = 3) and
            SameText(weak_chain_query_syllables[1].text, 'yi') then
        begin
            tail_syllable_text := weak_chain_query_syllables[2].text;
        end
        else
        begin
            tail_syllable_text := '';
        end;
        if (tail_syllable_text = '') or
            (not SameText(tail_syllable_text, 'ge')) and
            (not SameText(tail_syllable_text, 'xie')) and
            (not SameText(tail_syllable_text, 'zhong')) and
            (not SameText(tail_syllable_text, 'li')) and
            (not SameText(tail_syllable_text, 'yang')) and
            (not SameText(tail_syllable_text, 'me')) and
            (not SameText(tail_syllable_text, 'ci')) and
            (not SameText(tail_syllable_text, 'hui')) and
            (not SameText(tail_syllable_text, 'lun')) and
            (not SameText(tail_syllable_text, 'lei')) and
            (not SameText(tail_syllable_text, 'bian')) and
            (not SameText(tail_syllable_text, 'mian')) and
            (not SameText(tail_syllable_text, 'yan')) and
            (not SameText(tail_syllable_text, 'tian')) and
            (not SameText(tail_syllable_text, 'nian')) and
            (not SameText(tail_syllable_text, 'yue')) and
            (not SameText(tail_syllable_text, 'xia')) and
            (not SameText(tail_syllable_text, 'sheng')) and
            (not SameText(tail_syllable_text, 'dian')) and
            (not SameText(tail_syllable_text, 'wei')) then
        begin
            Exit;
        end;

        normalized_comment := normalize_pinyin_text(candidate.comment);
        expected_comment := '';
        if Length(weak_chain_query_syllables) >= 2 then
        begin
            expected_comment := Trim(weak_chain_query_syllables[1].text);
            if Length(weak_chain_query_syllables) >= 3 then
            begin
                expected_comment := expected_comment + Trim(weak_chain_query_syllables[2].text);
            end;
        end;
        Result := (normalized_comment <> '') and (normalized_comment = expected_comment);
    end;

    procedure swap_items(const left_index: Integer; const right_index: Integer);
    var
        tmp: TncCandidateSortItem;
    begin
        tmp := list[left_index];
        list[left_index] := list[right_index];
        list[right_index] := tmp;
    end;

    procedure apply_front_row_conservative_guard;
    var
        top_item: TncCandidateSortItem;
        alt_item: TncCandidateSortItem;
        alt_idx: Integer;
        margin: Integer;
        score_gap: Integer;
        path_gap: Integer;
    begin
        if list.Count < 2 then
        begin
            Exit;
        end;

        top_item := list[0];
        if top_item.is_latest_context_query_choice or top_item.is_latest_query_choice or
            (top_item.candidate.comment <> '') or
            (top_item.confidence_rank <= 1) then
        begin
            Exit;
        end;

        for alt_idx := 1 to Min(list.Count - 1, 4) do
        begin
            alt_item := list[alt_idx];
            if alt_item.candidate.comment <> '' then
            begin
                Continue;
            end;
            if alt_item.confidence_rank > top_item.confidence_rank then
            begin
                Continue;
            end;
            if (alt_item.confidence_rank = top_item.confidence_rank) and
                (alt_item.path_confidence_score <= top_item.path_confidence_score + 160) then
            begin
                Continue;
            end;
            if use_intent_layers and (alt_item.layer > top_item.layer + 1) then
            begin
                Continue;
            end;

            score_gap := top_item.rank_score - alt_item.rank_score;
            margin := Max(top_item.conservative_margin, alt_item.conservative_margin);
            path_gap := alt_item.path_confidence_score - top_item.path_confidence_score;
            if path_gap > 0 then
            begin
                Inc(margin, Min(96, path_gap div 3));
            end;
            if score_gap <= margin then
            begin
                swap_items(0, alt_idx);
                Break;
            end;
        end;
    end;
begin
    if Length(candidates) <= 1 then
    begin
        Exit;
    end;

    use_intent_layers := m_last_lookup_syllable_count >= 3;
    has_strong_complete_phrase := False;
    has_competing_exact_phrase := False;
    has_weighted_complete_phrase := False;
    weak_chain_query_prepared := False;
    SetLength(weak_chain_query_syllables, 0);
    SetLength(weak_chain_preference_maps, 0);
    partial_comment_syllable_cache := TDictionary<string, Integer>.Create;
    best_one_plus_two_partial_score := Low(Integer);
    best_two_plus_one_partial_score := Low(Integer);
    has_boundary_anchor_one_plus_two := False;
    has_boundary_anchor_two_plus_one := False;
    preferred_three_syllable_partial_kind := m_last_three_syllable_partial_preference_kind;
    fixed_top_single_char_text := get_fixed_top_single_char_for_query_local;

    list := TList<TncCandidateSortItem>.Create;
    try
        list.Capacity := Length(candidates);
        for i := 0 to High(candidates) do
        begin
            item.candidate := candidates[i];
            item.rank_score := get_rank_score(candidates[i]);
            if use_intent_layers then
            begin
                item.layer := get_multi_syllable_intent_layer(candidates[i]);
            end
            else
            begin
                item.layer := 0;
            end;
            item.confidence_rank := get_candidate_confidence_rank(candidates[i]);
            item.path_confidence_score := get_candidate_path_confidence_score(candidates[i]);
            if is_runtime_chain_candidate(candidates[i]) then
            begin
                item.conservative_margin := 280;
            end
            else if is_runtime_common_pattern_candidate(candidates[i]) then
            begin
                item.conservative_margin := 190;
            end
            else if is_runtime_redup_candidate(candidates[i]) then
            begin
                item.conservative_margin := 160;
            end
            else if (candidates[i].source = cs_rule) and (not candidates[i].has_dict_weight) then
            begin
                item.conservative_margin := 140;
            end
            else
            begin
                item.conservative_margin := 96;
            end;
            item.source_rank := get_source_rank(candidates[i].source);
            item.text_length := Length(candidates[i].text);
            item.text_units := get_candidate_text_unit_count(candidates[i].text);
            item.is_latest_context_query_choice := get_context_query_latest_bonus(candidates[i].text) > 0;
            item.is_latest_query_choice := is_latest_session_query_choice(candidates[i].text);
            item.is_weak_single_char_chain := is_weak_single_char_chain_candidate_cached(candidates[i]);
            item.is_problematic_single_char_chain :=
                is_problematic_single_char_chain_candidate_cached(candidates[i]);
            item.is_weighted_complete_phrase := is_weighted_complete_phrase_candidate(candidates[i]);
            item.is_runtime_constructed_complete_phrase :=
                is_runtime_constructed_complete_phrase_candidate(candidates[i]);
            item.is_prioritized_user_phrase := (candidates[i].comment = '') and
                (candidates[i].source = cs_user) and (item.text_units >= 2);
            item.is_one_plus_two_partial := False;
            item.is_two_plus_one_partial := False;
            item.is_weighted_partial_phrase := False;
            item.is_complete_phrase_prefix_partial := False;
            item.is_supported_head_phrase_partial := False;
            candidate_path_score_hint := get_candidate_segment_path_score_hint(candidates[i]);
            item.is_boundary_anchor_partial := (candidates[i].comment <> '') and
                (candidate_path_score_hint >= c_boundary_anchor_partial_score_hint_flag);
            if item.is_boundary_anchor_partial then
            begin
                case ((candidate_path_score_hint - c_boundary_anchor_partial_score_hint_flag) div
                    c_boundary_anchor_partial_shape_kind_scale) of
                    c_boundary_anchor_partial_shape_one_plus_two:
                    begin
                        item.is_one_plus_two_partial := True;
                        item.is_two_plus_one_partial := False;
                    end;
                    c_boundary_anchor_partial_shape_two_plus_one:
                    begin
                        item.is_one_plus_two_partial := False;
                        item.is_two_plus_one_partial := True;
                    end;
                end;
            end;
            if candidates[i].comment <> '' then
            begin
                item.partial_comment_syllables := get_partial_comment_syllable_count(candidates[i].comment);
            end
            else
            begin
                item.partial_comment_syllables := 0;
            end;
            item.is_one_plus_two_partial := item.is_one_plus_two_partial or
                ((m_last_lookup_syllable_count = 3) and
                (item.partial_comment_syllables = 2) and (item.text_units = 1));
            item.is_two_plus_one_partial := item.is_two_plus_one_partial or
                ((m_last_lookup_syllable_count = 3) and
                (item.partial_comment_syllables = 1) and (item.text_units >= 2));
            item.is_weighted_partial_phrase := (candidates[i].comment <> '') and
                (item.text_units >= 2) and
                (candidates[i].has_dict_weight or (candidates[i].source = cs_user) or
                ((candidates[i].source = cs_rule) and
                (not is_runtime_chain_candidate(candidates[i])) and
                (not is_runtime_common_pattern_candidate(candidates[i])) and
                (not is_runtime_redup_candidate(candidates[i]))));
            item.is_complete_phrase_prefix_partial := False;
            item.is_supported_head_phrase_partial :=
                is_supported_head_phrase_partial_candidate(item);
            if item.is_supported_head_phrase_partial then
            begin
                Inc(item.rank_score, c_supported_head_phrase_partial_rank_bonus);
            end;
            item.is_demonstrative_head_friendly_partial :=
                is_demonstrative_head_friendly_partial_candidate_cached(candidates[i]);
            if item.is_demonstrative_head_friendly_partial then
            begin
                Inc(item.rank_score, c_demonstrative_head_friendly_partial_rank_bonus);
            end;
            item.is_fixed_top_single_char := (fixed_top_single_char_text <> '') and
                (item.candidate.comment = '') and (item.text_units = 1) and
                (Trim(item.candidate.text) = fixed_top_single_char_text);
            if use_intent_layers and (item.candidate.comment = '') and
                (item.layer <= 1) and (get_candidate_text_unit_count(item.candidate.text) >= 2) and
                (item.candidate.has_dict_weight or (item.candidate.source = cs_user) or
                ((item.candidate.source = cs_rule) and
                (not is_runtime_chain_candidate(item.candidate)) and
                (not is_runtime_common_pattern_candidate(item.candidate)) and
                (not is_runtime_redup_candidate(item.candidate)))) then
            begin
                has_strong_complete_phrase := True;
            end;
            if (item.candidate.comment = '') and (get_candidate_text_unit_count(item.candidate.text) >= 2) and
                (item.candidate.has_dict_weight or
                ((item.candidate.source = cs_rule) and
                (not is_runtime_chain_candidate(item.candidate)) and
                (not is_runtime_common_pattern_candidate(item.candidate)) and
                (not is_runtime_redup_candidate(item.candidate)))) then
            begin
                has_competing_exact_phrase := True;
            end;
            if item.is_weighted_complete_phrase then
            begin
                has_weighted_complete_phrase := True;
            end;
            if item.is_one_plus_two_partial and (item.rank_score > best_one_plus_two_partial_score) then
            begin
                best_one_plus_two_partial_score := item.rank_score;
            end;
            if item.is_two_plus_one_partial and (item.rank_score > best_two_plus_one_partial_score) then
            begin
                best_two_plus_one_partial_score := item.rank_score;
            end;
            if item.is_boundary_anchor_partial and item.is_one_plus_two_partial then
            begin
                has_boundary_anchor_one_plus_two := True;
            end;
            if item.is_boundary_anchor_partial and item.is_two_plus_one_partial then
            begin
                has_boundary_anchor_two_plus_one := True;
            end;
            list.Add(item);
        end;

        if (preferred_three_syllable_partial_kind = 0) and
            c_suppress_nonlexicon_complete_long_candidates and
            (m_last_lookup_syllable_count >= 3) then
        begin
            if has_boundary_anchor_one_plus_two and (not has_boundary_anchor_two_plus_one) then
            begin
                preferred_three_syllable_partial_kind := 1;
            end
            else if has_boundary_anchor_two_plus_one and (not has_boundary_anchor_one_plus_two) then
            begin
                preferred_three_syllable_partial_kind := 2;
            end;
        end;

        if (preferred_three_syllable_partial_kind = 0) and
            c_suppress_nonlexicon_complete_long_candidates and
            (m_last_lookup_syllable_count >= 3) then
        begin
            if (best_one_plus_two_partial_score > Low(Integer)) and
                ((best_two_plus_one_partial_score <= Low(Integer)) or
                ((best_two_plus_one_partial_score * 100) <=
                (best_one_plus_two_partial_score * c_three_syllable_boundary_ratio_pct))) then
            begin
                preferred_three_syllable_partial_kind := 1;
            end
            else if best_two_plus_one_partial_score > Low(Integer) then
            begin
                preferred_three_syllable_partial_kind := 2;
            end;
        end;

        if c_suppress_nonlexicon_complete_long_candidates and
            (m_last_lookup_syllable_count >= 3) and
            (preferred_three_syllable_partial_kind <> 0) then
        begin
            for i := 0 to list.Count - 1 do
            begin
                item := list[i];
                if (preferred_three_syllable_partial_kind = 1) and item.is_two_plus_one_partial then
                begin
                    if item.is_complete_phrase_prefix_partial then
                    begin
                    end
                    else if item.is_weighted_partial_phrase then
                    begin
                        Dec(item.rank_score, c_strong_exact_partial_shape_penalty);
                    end
                    else
                    begin
                        Dec(item.rank_score, 880);
                    end;
                end
                else if (preferred_three_syllable_partial_kind = 2) and item.is_one_plus_two_partial then
                begin
                    Dec(item.rank_score, 880);
                end;
                list[i] := item;
            end;
        end;

        if use_intent_layers and has_strong_complete_phrase then
        begin
            for i := 0 to list.Count - 1 do
            begin
                item := list[i];
                if is_runtime_chain_candidate(item.candidate) then
                begin
                    Dec(item.rank_score, 220);
                end
                else if is_runtime_common_pattern_candidate(item.candidate) then
                begin
                    Dec(item.rank_score, 140);
                end
                else if is_runtime_redup_candidate(item.candidate) then
                begin
                    Dec(item.rank_score, 96);
                end;
                list[i] := item;
            end;
        end;

        if has_competing_exact_phrase then
        begin
            for i := 0 to list.Count - 1 do
            begin
                item := list[i];
                if item.is_weak_single_char_chain then
                begin
                    if (item.candidate.source = cs_user) and (item.candidate.score <= 1) then
                    begin
                        Dec(item.rank_score, c_user_score_bonus + 240);
                    end
                    else if is_runtime_chain_candidate(item.candidate) then
                    begin
                        Dec(item.rank_score, 520);
                    end
                    else
                    begin
                        Dec(item.rank_score, 360);
                    end;
                    item.path_confidence_score := 0;
                end
                else if item.is_problematic_single_char_chain then
                begin
                    Dec(item.rank_score, 680);
                    item.path_confidence_score := 0;
                end;
                list[i] := item;
            end;
        end;

        // Precompute heavy ranking keys once per candidate to avoid repeatedly
        // recomputing context/session bonuses during every comparison.
        list.Sort(TComparer<TncCandidateSortItem>.Construct(
            function(const left, right: TncCandidateSortItem): Integer
            var
                left_protected_complete: Boolean;
                right_protected_complete: Boolean;
                left_exact_long_complete: Boolean;
                right_exact_long_complete: Boolean;
            begin
                if left.is_fixed_top_single_char and (not right.is_fixed_top_single_char) then
                begin
                    Result := -1;
                    Exit;
                end;
                if right.is_fixed_top_single_char and (not left.is_fixed_top_single_char) then
                begin
                    Result := 1;
                    Exit;
                end;

                left_protected_complete := (left.candidate.comment = '') and
                    ((left.candidate.source = cs_user) or left.is_weighted_complete_phrase);
                right_protected_complete := (right.candidate.comment = '') and
                    ((right.candidate.source = cs_user) or right.is_weighted_complete_phrase);
                left_exact_long_complete := (m_last_lookup_syllable_count >= 4) and
                    (left.candidate.comment = '') and
                    (left.text_units = m_last_lookup_syllable_count) and
                    ((left.candidate.source = cs_user) or left.is_weighted_complete_phrase);
                right_exact_long_complete := (m_last_lookup_syllable_count >= 4) and
                    (right.candidate.comment = '') and
                    (right.text_units = m_last_lookup_syllable_count) and
                    ((right.candidate.source = cs_user) or right.is_weighted_complete_phrase);

                if c_suppress_nonlexicon_complete_long_candidates and
                    (m_last_lookup_syllable_count >= 4) then
                begin
                    if left_exact_long_complete and
                        ((right.candidate.comment <> '') or (not right_exact_long_complete)) then
                    begin
                        Result := -1;
                        Exit;
                    end;
                    if right_exact_long_complete and
                        ((left.candidate.comment <> '') or (not left_exact_long_complete)) then
                    begin
                        Result := 1;
                        Exit;
                    end;

                    if (left.candidate.comment <> '') and (right.candidate.comment <> '') then
                    begin
                        if (left.text_units >= 2) and (left.partial_comment_syllables > 0) and
                            (left.text_units + left.partial_comment_syllables =
                            m_last_lookup_syllable_count) and
                            (right.text_units = 1) and
                            (right.partial_comment_syllables = m_last_lookup_syllable_count - 1) then
                        begin
                            Result := -1;
                            Exit;
                        end;
                        if (right.text_units >= 2) and (right.partial_comment_syllables > 0) and
                            (right.text_units + right.partial_comment_syllables =
                            m_last_lookup_syllable_count) and
                            (left.text_units = 1) and
                            (left.partial_comment_syllables = m_last_lookup_syllable_count - 1) then
                        begin
                            Result := 1;
                            Exit;
                        end;
                    end;
                end;

                if (left.candidate.comment = '') and (right.candidate.comment = '') then
                begin
                    if not ((m_last_lookup_syllable_count = 1) and
                        (left.text_units = 1) and (right.text_units = 1)) then
                    begin
                        if left.is_latest_context_query_choice and
                            (not right.is_latest_context_query_choice) then
                        begin
                            Result := -1;
                            Exit;
                        end;
                        if right.is_latest_context_query_choice and
                            (not left.is_latest_context_query_choice) then
                        begin
                            Result := 1;
                            Exit;
                        end;
                    end;
                    if left.is_latest_query_choice and (not right.is_latest_query_choice) then
                    begin
                        Result := -1;
                        Exit;
                    end;
                    if right.is_latest_query_choice and (not left.is_latest_query_choice) then
                    begin
                        Result := 1;
                        Exit;
                    end;
                end;

                if left.is_prioritized_user_phrase and (not right.is_prioritized_user_phrase) and
                    (not (has_competing_exact_phrase and left.is_problematic_single_char_chain)) then
                begin
                    Result := -1;
                    Exit;
                end;
                if right.is_prioritized_user_phrase and (not left.is_prioritized_user_phrase) and
                    (not (has_competing_exact_phrase and right.is_problematic_single_char_chain)) then
                begin
                    Result := 1;
                    Exit;
                end;

                if left.is_demonstrative_head_friendly_partial and
                    right.is_weighted_complete_phrase and
                    (left.rank_score >= right.rank_score + 80) then
                begin
                    Result := -1;
                    Exit;
                end;
                if right.is_demonstrative_head_friendly_partial and
                    left.is_weighted_complete_phrase and
                    (right.rank_score >= left.rank_score + 80) then
                begin
                    Result := 1;
                    Exit;
                end;

                if c_suppress_nonlexicon_complete_long_candidates and
                    (m_last_lookup_syllable_count >= 3) then
                begin
                    if preferred_three_syllable_partial_kind = 1 then
                    begin
                        if left.is_one_plus_two_partial and
                            right.is_supported_head_phrase_partial and
                            right.is_two_plus_one_partial and
                            (right.rank_score >= left.rank_score +
                            c_supported_head_phrase_partial_override_gap) then
                        begin
                            Result := 1;
                            Exit;
                        end;
                        if right.is_one_plus_two_partial and
                            left.is_supported_head_phrase_partial and
                            left.is_two_plus_one_partial and
                            (left.rank_score >= right.rank_score +
                            c_supported_head_phrase_partial_override_gap) then
                        begin
                            Result := -1;
                            Exit;
                        end;

                        if left.is_one_plus_two_partial and
                            (((not right.is_one_plus_two_partial) and
                            (not right_protected_complete)) or
                            ((right.is_one_plus_two_partial) and
                            (left.rank_score > right.rank_score + c_three_syllable_partial_shape_margin))) then
                        begin
                            Result := -1;
                            Exit;
                        end;
                        if right.is_one_plus_two_partial and
                            (((not left.is_one_plus_two_partial) and
                            (not left_protected_complete)) or
                            ((left.is_one_plus_two_partial) and
                            (right.rank_score > left.rank_score + c_three_syllable_partial_shape_margin))) then
                        begin
                            Result := 1;
                            Exit;
                        end;
                    end
                    else if preferred_three_syllable_partial_kind = 2 then
                    begin
                        if left.is_two_plus_one_partial and
                            (((not right.is_two_plus_one_partial) and
                            (not right_protected_complete)) or
                            ((right.is_two_plus_one_partial) and
                            (left.rank_score > right.rank_score + c_three_syllable_partial_shape_margin))) then
                        begin
                            Result := -1;
                            Exit;
                        end;
                        if right.is_two_plus_one_partial and
                            (((not left.is_two_plus_one_partial) and
                            (not left_protected_complete)) or
                            ((left.is_two_plus_one_partial) and
                            (right.rank_score > left.rank_score + c_three_syllable_partial_shape_margin))) then
                        begin
                            Result := 1;
                            Exit;
                        end;
                    end;

                    if left.is_boundary_anchor_partial and (not right.is_boundary_anchor_partial) and
                        (((right.candidate.comment <> '')) or
                        ((right.candidate.comment = '') and
                        (right.candidate.source <> cs_user) and
                        (not right.is_weighted_complete_phrase))) then
                    begin
                        Result := -1;
                        Exit;
                    end;
                    if right.is_boundary_anchor_partial and (not left.is_boundary_anchor_partial) and
                        (((left.candidate.comment <> '')) or
                        ((left.candidate.comment = '') and
                        (left.candidate.source <> cs_user) and
                        (not left.is_weighted_complete_phrase))) then
                    begin
                        Result := 1;
                        Exit;
                    end;
                end;

                // Learned user candidates should take priority over rule
                // candidates when both are complete commit candidates.
                if (left.candidate.comment = '') and (right.candidate.comment = '') then
                begin
                if (left.candidate.source = cs_user) and (right.candidate.source <> cs_user) and
                    (not (has_competing_exact_phrase and left.is_problematic_single_char_chain)) then
                begin
                    Result := -1;
                    Exit;
                end;
                if (right.candidate.source = cs_user) and (left.candidate.source <> cs_user) and
                    (not (has_competing_exact_phrase and right.is_problematic_single_char_chain)) then
                begin
                    Result := 1;
                    Exit;
                end;
            end;

                if has_weighted_complete_phrase and
                    (left.candidate.comment = '') and (right.candidate.comment = '') then
                begin
                    if left.is_weighted_complete_phrase and right.is_problematic_single_char_chain then
                    begin
                        Result := -1;
                        Exit;
                    end;
                    if right.is_weighted_complete_phrase and left.is_problematic_single_char_chain then
                    begin
                        Result := 1;
                        Exit;
                    end;
                end;

                if use_intent_layers then
                begin
                    Result := left.layer - right.layer;
                    if Result <> 0 then
                    begin
                        Exit;
                    end;
                end;

                if (left.candidate.comment = '') and (right.candidate.comment = '') and
                    (left.confidence_rank <> right.confidence_rank) and
                    (Abs(left.rank_score - right.rank_score) <=
                    Max(left.conservative_margin, right.conservative_margin)) then
                begin
                    Result := left.confidence_rank - right.confidence_rank;
                    if Result <> 0 then
                    begin
                        Exit;
                    end;
                end;
                if (left.candidate.comment = '') and (right.candidate.comment = '') and
                    (left.path_confidence_score <> right.path_confidence_score) and
                    (Abs(left.rank_score - right.rank_score) <=
                    Max(left.conservative_margin, right.conservative_margin)) and
                    (Abs(left.path_confidence_score - right.path_confidence_score) >= 120) then
                begin
                    Result := right.path_confidence_score - left.path_confidence_score;
                    if Result <> 0 then
                    begin
                        Exit;
                    end;
                end;

                Result := right.rank_score - left.rank_score;
                if Result = 0 then
                begin
                    Result := left.source_rank - right.source_rank;
                    if Result = 0 then
                    begin
                        Result := left.text_length - right.text_length;
                        if Result = 0 then
                        begin
                            Result := CompareText(left.candidate.text, right.candidate.text);
                        end;
                    end;
                end;
            end));

        apply_front_row_conservative_guard;

        for i := 0 to High(candidates) do
        begin
            candidates[i] := list[i].candidate;
        end;
    finally
        for i := 0 to High(weak_chain_preference_maps) do
        begin
            if weak_chain_preference_maps[i] <> nil then
            begin
                weak_chain_preference_maps[i].Free;
                weak_chain_preference_maps[i] := nil;
            end;
        end;
        partial_comment_syllable_cache.Free;
        list.Free;
    end;
end;

function TncEngine.normalize_pinyin_text(const input_text: string): string;
var
    i: Integer;
    ch: Char;
begin
    Result := '';
    if input_text = '' then
    begin
        Exit;
    end;

    SetLength(Result, Length(input_text));
    for i := 1 to Length(input_text) do
    begin
        ch := input_text[i];
        if ch = '''' then
        begin
            Result[i] := #0;
        end
        else if (ch >= 'A') and (ch <= 'Z') then
        begin
            Result[i] := Char(Ord(ch) + Ord('a') - Ord('A'));
        end
        else
        begin
            Result[i] := ch;
        end;
    end;

    Result := Result.Replace(#0, '');
end;

function TncEngine.is_valid_pinyin_syllable(const syllable: string): Boolean;
var
    ch: Char;
begin
    Result := False;
    if syllable = '' then
    begin
        Exit;
    end;

    // Single-letter syllables are only valid for standalone finals.
    if Length(syllable) = 1 then
    begin
        Result := CharInSet(syllable[1], ['a', 'e', 'o']);
        Exit;
    end;

    for ch in syllable do
    begin
        if CharInSet(ch, ['a', 'e', 'i', 'o', 'u', 'v']) then
        begin
            Result := True;
            Exit;
        end;
    end;
end;

function TncEngine.is_full_pinyin_key(const value: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    reconstructed: string;
begin
    Result := False;
    if value = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(value);
    finally
        parser.Free;
    end;

    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    reconstructed := '';
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_pinyin_syllable(syllables[idx].text) then
        begin
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
    end;

    Result := SameText(reconstructed, value);
end;

function TncEngine.get_effective_compact_pinyin_syllables(const input_text: string;
    const allow_relaxed_split: Boolean): TncPinyinParseResult;
const
    c_initials_local: array[0..22] of string = (
        'zh', 'ch', 'sh',
        'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h',
        'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w'
    );
    c_finals_local: array[0..35] of string = (
        'iang', 'iong', 'uang',
        'uai', 'uan', 'iao', 'ian', 'ing', 'ang', 'eng', 'ong',
        'ai', 'an', 'ao', 'ei', 'en', 'er', 'ou',
        'ia', 'ie', 'in', 'iu', 'ua', 'ui', 'un', 'uo',
        've', 'van', 'vn', 'ue',
        'a', 'e', 'i', 'o', 'u', 'v'
    );
    c_finals_no_initial_local: array[0..11] of string = (
        'ang', 'eng',
        'ai', 'an', 'ao', 'ei', 'en', 'er', 'ou',
        'a', 'e', 'o'
    );
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    tail_text: string;
    merged_count: Integer;
    tail_idx: Integer;

    function is_initial_final_compatible_local(const initial_value: string;
        const final_value: string): Boolean;
    begin
        if (initial_value = 'zh') or (initial_value = 'ch') or (initial_value = 'sh') or
            (initial_value = 'r') or (initial_value = 'z') or (initial_value = 'c') or
            (initial_value = 's') then
        begin
            if (final_value = 'in') or (final_value = 'ing') or (final_value = 'iu') or
                (final_value = 'ie') or (final_value = 'ian') or (final_value = 'iang') or
                (final_value = 'iao') or (final_value = 'iong') or
                (final_value = 'ue') or (final_value = 've') or (final_value = 'van') or
                (final_value = 'vn') then
            begin
                Exit(False);
            end;
        end;

        Result := True;
    end;

    function is_single_syllable_prefix_text(const value: string): Boolean;
    var
        lower_value: string;
        initial_idx: Integer;
        final_idx: Integer;
        full_syllable: string;
    begin
        Result := False;
        lower_value := LowerCase(Trim(value));
        if lower_value = '' then
        begin
            Exit;
        end;

        for initial_idx := Low(c_initials_local) to High(c_initials_local) do
        begin
            for final_idx := Low(c_finals_local) to High(c_finals_local) do
            begin
                if not is_initial_final_compatible_local(c_initials_local[initial_idx],
                    c_finals_local[final_idx]) then
                begin
                    Continue;
                end;

                full_syllable := c_initials_local[initial_idx] + c_finals_local[final_idx];
                if Copy(full_syllable, 1, Length(lower_value)) = lower_value then
                begin
                    Exit(True);
                end;
            end;
        end;

        for final_idx := Low(c_finals_no_initial_local) to High(c_finals_no_initial_local) do
        begin
            full_syllable := c_finals_no_initial_local[final_idx];
            if Copy(full_syllable, 1, Length(lower_value)) = lower_value then
            begin
                Exit(True);
            end;
        end;
    end;

    function build_tail_text(const start_index: Integer): string;
    var
        tail_idx: Integer;
    begin
        Result := '';
        if (start_index < 0) or (start_index > High(syllables)) then
        begin
            Exit;
        end;

        for tail_idx := start_index to High(syllables) do
        begin
            Result := Result + syllables[tail_idx].text;
        end;
    end;
begin
    SetLength(Result, 0);
    if input_text = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        if allow_relaxed_split then
        begin
            syllables := parse_pinyin_with_relaxed_missing_apostrophe(input_text);
        end
        else
        begin
            syllables := parser.parse(input_text);
        end;
    finally
        parser.Free;
    end;

    Result := syllables;
    // Explicit apostrophe input must preserve the user's syllable boundary.
    // Queries like "ji'an" / "ji'e" should stay two-syllable here instead of
    // being merged back into compact forms such as "jian" / "jie".
    if Pos('''', input_text) > 0 then
    begin
        Exit;
    end;

    if Length(syllables) <= 1 then
    begin
        Exit;
    end;

    for idx := 0 to High(syllables) do
    begin
        tail_text := build_tail_text(idx);
        if is_single_syllable_prefix_text(tail_text) then
        begin
            if idx = High(syllables) then
            begin
                Exit;
            end;

            merged_count := idx + 1;
            SetLength(Result, merged_count);
            for tail_idx := 0 to idx - 1 do
            begin
                Result[tail_idx] := syllables[tail_idx];
            end;

            Result[idx].text := tail_text;
            Result[idx].start_index := syllables[idx].start_index;
            Result[idx].length := 0;
            for tail_idx := idx to High(syllables) do
            begin
                Inc(Result[idx].length, syllables[tail_idx].length);
            end;
            Exit;
        end;
    end;
end;

function TncEngine.get_effective_compact_pinyin_unit_count(const input_text: string;
    const allow_relaxed_split: Boolean): Integer;
var
    syllables: TncPinyinParseResult;
begin
    syllables := get_effective_compact_pinyin_syllables(input_text, allow_relaxed_split);
    Result := Length(syllables);
end;

function TncEngine.normalize_adjacent_swap_typo(const value: string): string;
const
    c_adjacent_swap_typo_min_query_len = 5;
var
    swap_idx: Integer;
    swap_value: string;
    swap_char: Char;
begin
    Result := '';
    if (value = '') or (Length(value) < c_adjacent_swap_typo_min_query_len) then
    begin
        Exit;
    end;

    // Prefer right-most swaps first: tail typos like "...gn" -> "...ng" are common.
    for swap_idx := Length(value) - 1 downto 1 do
    begin
        if value[swap_idx] = value[swap_idx + 1] then
        begin
            Continue;
        end;

        swap_value := value;
        swap_char := swap_value[swap_idx];
        swap_value[swap_idx] := swap_value[swap_idx + 1];
        swap_value[swap_idx + 1] := swap_char;
        if is_full_pinyin_key(swap_value) then
        begin
            Result := swap_value;
            Exit;
        end;
    end;
end;

function TncEngine.split_text_units(const input_text: string): TArray<string>;
var
    list: TList<string>;
    i: Integer;
    ch: Char;
begin
    SetLength(Result, 0);
    if input_text = '' then
    begin
        Exit;
    end;

    list := TList<string>.Create;
    try
        i := 1;
        while i <= Length(input_text) do
        begin
            ch := input_text[i];
            if (Ord(ch) >= $D800) and (Ord(ch) <= $DBFF) and (i < Length(input_text)) and
                (Ord(input_text[i + 1]) >= $DC00) and (Ord(input_text[i + 1]) <= $DFFF) then
            begin
                list.Add(Copy(input_text, i, 2));
                Inc(i, 2);
            end
            else
            begin
                list.Add(Copy(input_text, i, 1));
                Inc(i);
            end;
        end;

        Result := list.ToArray;
    finally
        list.Free;
    end;
end;

function TncEngine.is_common_surname_text(const value: string): Boolean;
var
    trimmed: string;
    codepoint: Integer;
begin
    Result := False;
    trimmed := Trim(value);
    if trimmed = '' then
    begin
        Exit;
    end;

    if Length(trimmed) = 1 then
    begin
        codepoint := Ord(trimmed[1]);
    end
    else if (Length(trimmed) = 2) and
        (Ord(trimmed[1]) >= $D800) and (Ord(trimmed[1]) <= $DBFF) and
        (Ord(trimmed[2]) >= $DC00) and (Ord(trimmed[2]) <= $DFFF) then
    begin
        codepoint := ((Ord(trimmed[1]) - $D800) shl 10) + (Ord(trimmed[2]) - $DC00) + $10000;
    end
    else
    begin
        Exit;
    end;

    case codepoint of
        $8D75, $94B1, $5B59, $674E, $5468, $5434, $90D1, $738B, $51AF, $9648,
        $891A, $536B, $848B, $6C88, $97E9, $6768, $6731, $79E6, $8BB8, $4F55,
        $5415, $65BD, $5F20, $5B54, $66F9, $4E25, $534E, $91D1, $9B4F, $9676,
        $59DC, $621A, $8C22, $90B9, $55BB, $82CF, $6F58, $845B, $8303, $5F6D,
        $90CE, $9C81, $97E6, $9A6C, $82D7, $51E4, $65B9, $4FDE, $4EFB, $8881,
        $67F3, $9C8D, $53F2, $5510, $8D39, $5EC9, $5C91, $859B, $96F7, $8D3A,
        $502A, $6C64, $6ED5, $6BB7, $7F57, $6BD5, $90DD, $90AC, $5B89, $5E38,
        $4E50, $4E8E, $5085, $76AE, $9F50, $5EB7, $4F0D, $4F59, $5143, $987E,
        $5B5F, $5E73, $9EC4, $548C, $7A46, $8427, $5C39, $59DA, $90B5, $6E5B,
        $6C6A, $7941, $6BDB, $79B9, $72C4, $7C73, $660E, $81E7, $8BA1, $4F0F,
        $6210, $6234, $5B8B, $8305, $5E9E, $718A, $7EAA, $8212, $5C48, $9879,
        $795D, $8463, $6881, $675C, $962E, $84DD, $95F5, $5E2D, $5B63, $9EBB,
        $5F3A, $8D3E, $8DEF, $5A04, $5371, $6C5F, $7AE5, $989C, $90ED, $6885,
        $76DB, $6797, $949F, $5F90, $90B1, $9A86, $9AD8, $590F, $8521, $7530,
        $6A0A, $80E1, $51CC, $970D, $865E, $4E07, $67EF, $5362, $83AB, $623F,
        $7F2A, $89E3, $5E94, $4E01, $9093, $90C1, $5D14, $9F9A, $7A0B, $90A2,
        $88F4, $9646, $8363, $7FC1, $8340, $7F8A, $60E0, $7504, $5C01, $82AE,
        $50A8, $9773, $6BB5, $7126, $5DF4, $5F13, $7267, $8F66, $4FAF, $5B93,
        $84EC, $5168:
            Result := True;
    end;
end;

function TncEngine.merge_candidate_lists(const primary_candidates: TncCandidateList;
    const secondary_candidates: TncCandidateList; const max_candidates: Integer): TncCandidateList;
var
    seen: TDictionary<string, Integer>;
    list: TList<TncCandidate>;
    i: Integer;
    existing_index: Integer;
    key: string;
    limit: Integer;
    candidate: TncCandidate;
begin
    seen := TDictionary<string, Integer>.Create;
    list := TList<TncCandidate>.Create;
    try
        for i := 0 to High(primary_candidates) do
        begin
            key := LowerCase(Trim(primary_candidates[i].text));
            if not seen.ContainsKey(key) then
            begin
                list.Add(primary_candidates[i]);
                seen.Add(key, list.Count - 1);
            end;
        end;

        for i := 0 to High(secondary_candidates) do
        begin
            key := LowerCase(Trim(secondary_candidates[i].text));
            if not seen.TryGetValue(key, existing_index) then
            begin
                list.Add(secondary_candidates[i]);
                seen.Add(key, list.Count - 1);
            end
            else
            begin
                if (existing_index >= 0) and (existing_index < list.Count) then
                begin
                    candidate := list[existing_index];
                    if secondary_candidates[i].score > candidate.score then
                    begin
                        candidate.score := secondary_candidates[i].score;
                    end;

                    if (candidate.comment <> '') and (secondary_candidates[i].comment = '') then
                    begin
                        candidate.comment := '';
                    end
                    else if (secondary_candidates[i].comment <> '') and (candidate.comment = '') then
                    begin
                        candidate.comment := secondary_candidates[i].comment;
                    end;

                    if (secondary_candidates[i].comment = candidate.comment) and
                        (get_source_rank(secondary_candidates[i].source) < get_source_rank(candidate.source)) then
                    begin
                        candidate.source := secondary_candidates[i].source;
                    end;

                    if (secondary_candidates[i].comment <> '') and (candidate.comment = '') then
                    begin
                        candidate.comment := secondary_candidates[i].comment;
                    end;

                    // Preserve raw lexicon weight for debug rendering when duplicates collapse by text.
                    if secondary_candidates[i].has_dict_weight then
                    begin
                        if (not candidate.has_dict_weight) or
                            (secondary_candidates[i].dict_weight > candidate.dict_weight) then
                        begin
                            candidate.has_dict_weight := True;
                            candidate.dict_weight := secondary_candidates[i].dict_weight;
                        end;
                    end;

                    list[existing_index] := candidate;
                end;
            end;
        end;

        limit := list.Count;
        if (max_candidates > 0) and (limit > max_candidates) then
        begin
            limit := max_candidates;
        end;

        SetLength(Result, limit);
        for i := 0 to limit - 1 do
        begin
            Result[i] := list[i];
        end;
    finally
        list.Free;
        seen.Free;
    end;
end;

function TncEngine.build_segment_candidates(out out_candidates: TncCandidateList;
    const include_full_path: Boolean; out out_path_search_elapsed_ms: Int64;
    const allow_relaxed_missing_apostrophe: Boolean): Boolean;
const
    c_segment_max_per_segment = 256;
    c_segment_max_syllables = 24;
    c_segment_word_max_syllables = 4;
    c_segment_partial_penalty = 180;
    c_segment_partial_quadratic_penalty = 160;
    c_segment_prefix_bonus = 80;
    c_segment_long_prefix_bonus = 220;
    c_segment_page_expand_factor = 16;
    c_segment_full_state_limit = 128;
    c_segment_full_completion_bonus = 160;
    c_segment_full_transition_penalty = 6;
    c_segment_full_leading_single_bonus = 36;
    c_segment_full_single_top_n = 1;
    c_segment_full_non_leading_single_penalty = 72;
    c_segment_full_preferred_single_penalty = 24;
    c_segment_full_leading_multi_penalty = 42;
    c_segment_full_path_budget_ms = 18;
    c_segment_full_path_budget_ms_long = 280;
    c_segment_full_path_budget_probe_interval = 64;
    c_segment_full_path_non_user_limit = 4;
    c_segment_full_path_non_user_limit_long = 6;
    c_segment_full_state_limit_long = 768;
    c_segment_full_partial_remaining_limit = 2;
    c_segment_full_partial_non_user_limit = 3;
    c_segment_full_partial_penalty = 90;
    c_segment_full_partial_quadratic_penalty = 80;
    c_segment_partial_single_top_n = 6;
    c_segment_text_unit_mismatch_penalty = 100;
    c_segment_text_unit_overflow_penalty = 60;
    c_segment_alignment_rank_window = 6;
    c_segment_alignment_rank_step = 24;
    c_segment_alignment_missing_penalty = 60;
    c_segment_alignment_adjust_cap = 140;
var
    syllables: TncPinyinParseResult;
    lookup_cache: TDictionary<string, TncCandidateList>;
    list: TList<TncCandidate>;
    dedup: TDictionary<string, Integer>;
    total_limit: Integer;
    per_limit: Integer;
    max_word_len: Integer;
    segment_len: Integer;
    segment_text: string;
    remaining_syllables: Integer;
    remaining_pinyin: string;
    i: Integer;
    lookup_results: TncCandidateList;
    candidate: TncCandidate;
    item: TncCandidate;
    score_value: Integer;
    dedup_key: string;
    existing_index: Integer;
    is_first_overall_segment: Boolean;
    candidate_text_units: Integer;
    path_search_start_tick: UInt64;

    function is_single_text_unit(const value: string): Boolean;
    begin
        if Length(value) = 1 then
        begin
            Result := True;
            Exit;
        end;

        Result := (Length(value) = 2) and
            (Ord(value[1]) >= $D800) and (Ord(value[1]) <= $DBFF) and
            (Ord(value[2]) >= $DC00) and (Ord(value[2]) <= $DFFF);
    end;

    function is_multi_char_word(const text: string): Boolean;
    var
        trimmed_text: string;
    begin
        trimmed_text := Trim(text);
        Result := (trimmed_text <> '') and (not is_single_text_unit(trimmed_text));
    end;

    function contains_non_ascii(const text: string): Boolean;
    var
        ch: Char;
    begin
        Result := False;
        for ch in text do
        begin
            if Ord(ch) > $7F then
            begin
                Result := True;
                Exit;
            end;
        end;
    end;

    function is_single_initial_token(const token_text: string): Boolean;
    var
        ch: Char;
    begin
        Result := False;
        if Length(token_text) <> 1 then
        begin
            Exit;
        end;

        ch := token_text[1];
        if (ch >= 'A') and (ch <= 'Z') then
        begin
            ch := Chr(Ord(ch) + 32);
        end;
        Result := CharInSet(ch, ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x',
            'r', 'z', 'c', 's', 'y', 'w']);
    end;

    function get_text_unit_count(const text: string): Integer;
    var
        idx: Integer;
        codepoint: Integer;
    begin
        Result := 0;
        if text = '' then
        begin
            Exit;
        end;

        idx := 1;
        while idx <= Length(text) do
        begin
            codepoint := Ord(text[idx]);
            if (codepoint >= $D800) and (codepoint <= $DBFF) and (idx < Length(text)) then
            begin
                if (Ord(text[idx + 1]) >= $DC00) and (Ord(text[idx + 1]) <= $DFFF) then
                begin
                    Inc(idx);
                end;
            end;
            Inc(Result);
            Inc(idx);
        end;
    end;

    function build_syllable_text(const start_index: Integer; const syllable_count: Integer): string;
    var
        idx: Integer;
        end_index: Integer;
    begin
        Result := '';
        if (syllable_count <= 0) or (start_index < 0) or (start_index > High(syllables)) then
        begin
            Exit;
        end;

        end_index := start_index + syllable_count - 1;
        if end_index > High(syllables) then
        begin
            end_index := High(syllables);
        end;

        for idx := start_index to end_index do
        begin
            Result := Result + syllables[idx].text;
        end;
    end;

    function dictionary_lookup_cached(const pinyin_key: string; out out_results: TncCandidateList): Boolean;
    begin
        SetLength(out_results, 0);
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit(False);
        end;

        if lookup_cache.TryGetValue(pinyin_key, out_results) then
        begin
            Exit(Length(out_results) > 0);
        end;

        if not m_dictionary.lookup(pinyin_key, out_results) then
        begin
            SetLength(out_results, 0);
        end;
        lookup_cache.AddOrSetValue(pinyin_key, out_results);
        Result := Length(out_results) > 0;
    end;

    function get_candidate_effective_weight_local(const local_candidate: TncCandidate): Integer;
    begin
        if local_candidate.has_dict_weight then
        begin
            Result := local_candidate.dict_weight;
        end
        else
        begin
            Result := local_candidate.score;
        end;
    end;

    function get_best_exact_phrase_strength_local(const pinyin_key: string): Integer;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
    begin
        Result := 0;
        if not dictionary_lookup_cached(pinyin_key, local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units < 2 then
            begin
                Continue;
            end;

            local_weight := get_candidate_effective_weight_local(local_results[local_idx]);
            if local_weight > Result then
            begin
                Result := local_weight;
            end;
        end;
    end;

    function get_best_single_char_strength_for_syllable_local(const syllable_index: Integer): Integer;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
        local_key: string;
    begin
        Result := 0;
        if (syllable_index < 0) or (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        local_key := syllables[syllable_index].text;
        if not dictionary_lookup_cached(local_key, local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units <> 1 then
            begin
                Continue;
            end;

            local_weight := get_candidate_effective_weight_local(local_results[local_idx]);
            if local_weight > Result then
            begin
                Result := local_weight;
            end;
        end;
    end;

    function try_get_best_single_char_candidate_for_syllable_local(const syllable_index: Integer;
        out out_text: string; out out_strength: Integer): Boolean;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
        local_key: string;
    begin
        Result := False;
        out_text := '';
        out_strength := 0;
        if (syllable_index < 0) or (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        local_key := syllables[syllable_index].text;
        if not dictionary_lookup_cached(local_key, local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units <> 1 then
            begin
                Continue;
            end;

            local_weight := get_candidate_effective_weight_local(local_results[local_idx]);
            if local_weight > out_strength then
            begin
                out_text := local_results[local_idx].text;
                out_strength := local_weight;
                Result := True;
            end;
        end;
    end;

    function is_boundary_unit_single_char_text_local(const text_value: string): Boolean;
    var
        normalized_text_value: string;
    begin
        Result := False;
        normalized_text_value := Trim(text_value);
        if get_text_unit_count(normalized_text_value) <> 1 then
        begin
            Exit;
        end;

        Result :=
            (normalized_text_value = string(Char($4E2A))) or
            (normalized_text_value = string(Char($4F4D))) or
            (normalized_text_value = string(Char($6B21))) or
            (normalized_text_value = string(Char($70B9))) or
            (normalized_text_value = string(Char($4E9B))) or
            (normalized_text_value = string(Char($79CD))) or
            (normalized_text_value = string(Char($5929))) or
            (normalized_text_value = string(Char($5E74))) or
            (normalized_text_value = string(Char($6708))) or
            (normalized_text_value = string(Char($91CC))) or
            (normalized_text_value = string(Char($4E0B))) or
            (normalized_text_value = string(Char($56DE))) or
            (normalized_text_value = string(Char($904D))) or
            (normalized_text_value = string(Char($58F0))) or
            (normalized_text_value = string(Char($9762))) or
            (normalized_text_value = string(Char($773C))) or
            (normalized_text_value = string(Char($8FB9)));
    end;

    function try_get_best_boundary_unit_single_char_for_pinyin_key_local(const pinyin_key: string;
        out out_text: string; out out_strength: Integer): Boolean;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
        local_text: string;
    begin
        Result := False;
        out_text := '';
        out_strength := 0;
        if not dictionary_lookup_cached(Trim(pinyin_key), local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units <> 1 then
            begin
                Continue;
            end;

            local_text := Trim(local_results[local_idx].text);
            if not is_boundary_unit_single_char_text_local(local_text) then
            begin
                Continue;
            end;

            local_weight := get_candidate_effective_weight_local(local_results[local_idx]);
            if local_weight > out_strength then
            begin
                out_text := local_text;
                out_strength := local_weight;
                Result := True;
            end;
        end;
    end;

    function try_get_shifted_boundary_unit_split_local(out out_head_two_key: string;
        out out_shifted_middle_key: string; out out_shifted_tail_key: string;
        out out_boundary_unit_text: string; out out_boundary_unit_strength: Integer): Boolean;
    var
        middle_key: string;
        tail_key: string;
        shifted_char: string;
    begin
        Result := False;
        out_head_two_key := '';
        out_shifted_middle_key := '';
        out_shifted_tail_key := '';
        out_boundary_unit_text := '';
        out_boundary_unit_strength := 0;
        if Length(syllables) < 3 then
        begin
            Exit;
        end;

        middle_key := Trim(syllables[1].text);
        tail_key := Trim(syllables[2].text);
        if (middle_key = '') or (tail_key = '') or (Length(middle_key) <= 1) then
        begin
            Exit;
        end;

        shifted_char := Copy(middle_key, Length(middle_key), 1);
        out_shifted_middle_key := Copy(middle_key, 1, Length(middle_key) - 1);
        out_shifted_tail_key := shifted_char + tail_key;
        if (out_shifted_middle_key = '') or (out_shifted_tail_key = '') then
        begin
            Exit;
        end;

        if (not is_full_pinyin_key(out_shifted_middle_key)) or
            (not is_full_pinyin_key(out_shifted_tail_key)) then
        begin
            Exit;
        end;

        if not try_get_best_boundary_unit_single_char_for_pinyin_key_local(
            out_shifted_middle_key, out_boundary_unit_text, out_boundary_unit_strength) then
        begin
            Exit;
        end;

        out_head_two_key := Trim(syllables[0].text) + out_shifted_middle_key;
        Result := out_head_two_key <> '';
    end;

    function is_quantity_like_prefix_text_local(const text_value: string): Boolean;
    var
        normalized_text_value: string;
    begin
        Result := False;
        normalized_text_value := Trim(text_value);
        if get_text_unit_count(normalized_text_value) <> 1 then
        begin
            Exit;
        end;

        Result :=
            (normalized_text_value = string(Char($4E00))) or
            (normalized_text_value = string(Char($4E8C))) or
            (normalized_text_value = string(Char($4E09))) or
            (normalized_text_value = string(Char($56DB))) or
            (normalized_text_value = string(Char($4E94))) or
            (normalized_text_value = string(Char($516D))) or
            (normalized_text_value = string(Char($4E03))) or
            (normalized_text_value = string(Char($516B))) or
            (normalized_text_value = string(Char($4E5D))) or
            (normalized_text_value = string(Char($5341))) or
            (normalized_text_value = string(Char($767E))) or
            (normalized_text_value = string(Char($5343))) or
            (normalized_text_value = string(Char($4E07))) or
            (normalized_text_value = string(Char($4E24))) or
            (normalized_text_value = string(Char($51E0))) or
            (normalized_text_value = string(Char($8FD9))) or
            (normalized_text_value = string(Char($90A3))) or
            (normalized_text_value = string(Char($54EA))) or
            (normalized_text_value = string(Char($6BCF))) or
            (normalized_text_value = string(Char($5404))) or
            (normalized_text_value = string(Char($534A))) or
            (normalized_text_value = string(Char($591A))) or
            (normalized_text_value = string(Char($6574))) or
            (normalized_text_value = string(Char($5355))) or
            (normalized_text_value = string(Char($53CC))) or
            (normalized_text_value = string(Char($4FE9))) or
            (normalized_text_value = string(Char($4EE8)));
    end;

    function try_get_best_boundary_unit_single_char_for_syllable_local(const syllable_index: Integer;
        out out_text: string; out out_strength: Integer): Boolean;
    begin
        Result := False;
        out_text := '';
        out_strength := 0;
        if (syllable_index < 0) or (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        Result := try_get_best_boundary_unit_single_char_for_pinyin_key_local(
            syllables[syllable_index].text, out_text, out_strength);
    end;

    function get_single_char_strength_for_text_at_syllable_local(const syllable_index: Integer;
        const text_value: string): Integer;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
        local_key: string;
        normalized_text_value: string;
    begin
        Result := 0;
        normalized_text_value := Trim(text_value);
        if (normalized_text_value = '') or (syllable_index < 0) or
            (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        local_key := syllables[syllable_index].text;
        if not dictionary_lookup_cached(local_key, local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units <> 1 then
            begin
                Continue;
            end;

            if Trim(local_results[local_idx].text) <> normalized_text_value then
            begin
                Continue;
            end;

            local_weight := get_candidate_effective_weight_local(local_results[local_idx]);
            if local_weight > Result then
            begin
                Result := local_weight;
            end;
        end;
    end;

    function get_single_char_rank_for_text_at_syllable_local(const syllable_index: Integer;
        const text_value: string): Integer;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_rank: Integer;
        local_key: string;
        normalized_text_value: string;
    begin
        Result := 0;
        normalized_text_value := Trim(text_value);
        if (normalized_text_value = '') or (syllable_index < 0) or
            (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        local_key := syllables[syllable_index].text;
        if not dictionary_lookup_cached(local_key, local_results) then
        begin
            Exit;
        end;

        local_rank := 0;
        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units <> 1 then
            begin
                Continue;
            end;

            Inc(local_rank);
            if Trim(local_results[local_idx].text) = normalized_text_value then
            begin
                Result := local_rank;
                Exit;
            end;
        end;
    end;

    function get_suffix_tail_bias_base_for_pinyin_key_local(const pinyin_key: string): Integer;
    var
        normalized_pinyin_key: string;
    begin
        Result := 0;
        normalized_pinyin_key := LowerCase(Trim(pinyin_key));
        if normalized_pinyin_key = '' then
        begin
            Exit;
        end;

        if normalized_pinyin_key = 'de' then
        begin
            Exit(520);
        end;

        if (normalized_pinyin_key = 'le') or (normalized_pinyin_key = 'zhe') or
            (normalized_pinyin_key = 'guo') then
        begin
            Exit(420);
        end;

        if (normalized_pinyin_key = 'ma') or (normalized_pinyin_key = 'ne') or
            (normalized_pinyin_key = 'ba') then
        begin
            Exit(360);
        end;

        if (normalized_pinyin_key = 'la') or (normalized_pinyin_key = 'a') or
            (normalized_pinyin_key = 'ya') or (normalized_pinyin_key = 'wa') or
            (normalized_pinyin_key = 'ha') then
        begin
            Exit(300);
        end;
    end;

    function get_suffix_tail_head_preference_ratio_pct_local(
        const pinyin_key: string): Integer;
    var
        normalized_pinyin_key: string;
    begin
        Result := 100;
        normalized_pinyin_key := LowerCase(Trim(pinyin_key));
        if normalized_pinyin_key = 'de' then
        begin
            Exit(170);
        end;

        if (normalized_pinyin_key = 'le') or (normalized_pinyin_key = 'zhe') or
            (normalized_pinyin_key = 'guo') then
        begin
            Exit(118);
        end;

        if (normalized_pinyin_key = 'ma') or (normalized_pinyin_key = 'ne') or
            (normalized_pinyin_key = 'ba') or (normalized_pinyin_key = 'la') or
            (normalized_pinyin_key = 'a') or (normalized_pinyin_key = 'ya') or
            (normalized_pinyin_key = 'wa') or (normalized_pinyin_key = 'ha') then
        begin
            Exit(112);
        end;
    end;

    function get_suffix_tail_head_retention_bonus_local(
        const pinyin_key: string): Integer;
    var
        normalized_pinyin_key: string;
    begin
        Result := 0;
        normalized_pinyin_key := LowerCase(Trim(pinyin_key));
        if normalized_pinyin_key = 'de' then
        begin
            Exit(420);
        end;

        if (normalized_pinyin_key = 'le') or (normalized_pinyin_key = 'zhe') or
            (normalized_pinyin_key = 'guo') then
        begin
            Exit(200);
        end;

        if (normalized_pinyin_key = 'ma') or (normalized_pinyin_key = 'ne') or
            (normalized_pinyin_key = 'ba') or (normalized_pinyin_key = 'la') or
            (normalized_pinyin_key = 'a') or (normalized_pinyin_key = 'ya') or
            (normalized_pinyin_key = 'wa') or (normalized_pinyin_key = 'ha') then
        begin
            Exit(120);
        end;
    end;

    function is_suffix_tail_expected_text_local(const pinyin_key: string;
        const text_value: string): Boolean;
    var
        normalized_pinyin_key: string;
        normalized_text_value: string;
    begin
        Result := False;
        normalized_pinyin_key := LowerCase(Trim(pinyin_key));
        normalized_text_value := Trim(text_value);
        if (normalized_pinyin_key = '') or (normalized_text_value = '') or
            (get_text_unit_count(normalized_text_value) <> 1) then
        begin
            Exit;
        end;

        if normalized_pinyin_key = 'de' then
        begin
            Result := (normalized_text_value = string(Char($7684))) or
                (normalized_text_value = string(Char($5F97))) or
                (normalized_text_value = string(Char($5730)));
            Exit;
        end;

        if normalized_pinyin_key = 'le' then
        begin
            Result := normalized_text_value = string(Char($4E86));
            Exit;
        end;

        if normalized_pinyin_key = 'zhe' then
        begin
            Result := (normalized_text_value = string(Char($7740))) or
                (normalized_text_value = string(Char($8457)));
            Exit;
        end;

        if normalized_pinyin_key = 'guo' then
        begin
            Result := normalized_text_value = string(Char($8FC7));
            Exit;
        end;

        if normalized_pinyin_key = 'ma' then
        begin
            Result := (normalized_text_value = string(Char($5417))) or
                (normalized_text_value = string(Char($561B)));
            Exit;
        end;

        if normalized_pinyin_key = 'ne' then
        begin
            Result := normalized_text_value = string(Char($5462));
            Exit;
        end;

        if normalized_pinyin_key = 'ba' then
        begin
            Result := (normalized_text_value = string(Char($5427))) or
                (normalized_text_value = string(Char($7F62)));
            Exit;
        end;

        if normalized_pinyin_key = 'la' then
        begin
            Result := normalized_text_value = string(Char($5566));
            Exit;
        end;

        if normalized_pinyin_key = 'a' then
        begin
            Result := normalized_text_value = string(Char($554A));
            Exit;
        end;

        if normalized_pinyin_key = 'ya' then
        begin
            Result := normalized_text_value = string(Char($5440));
            Exit;
        end;

        if normalized_pinyin_key = 'wa' then
        begin
            Result := normalized_text_value = string(Char($54C7));
            Exit;
        end;

        if normalized_pinyin_key = 'ha' then
        begin
            Result := normalized_text_value = string(Char($54C8));
            Exit;
        end;
    end;

    function get_suffix_tail_expected_text_support_strength_local(
        const syllable_index: Integer; const pinyin_key: string;
        const best_single_text: string; const best_single_strength: Integer;
        out out_matched_text: string): Integer;
    var
        normalized_best_single_text: string;

        procedure consider_expected_text_local(const expected_text: string);
        var
            local_strength: Integer;
        begin
            if expected_text = '' then
            begin
                Exit;
            end;

            if (normalized_best_single_text <> '') and
                SameText(normalized_best_single_text, expected_text) and
                (best_single_strength > 0) then
            begin
                local_strength := best_single_strength;
            end
            else
            begin
                local_strength := get_single_char_strength_for_text_at_syllable_local(
                    syllable_index, expected_text);
            end;

            if local_strength > Result then
            begin
                Result := local_strength;
                out_matched_text := expected_text;
            end;
        end;
    begin
        Result := 0;
        out_matched_text := '';
        if (syllable_index < 0) or (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        normalized_best_single_text := Trim(best_single_text);
        if not is_full_pinyin_key(Trim(syllables[syllable_index].text)) then
        begin
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'de') then
        begin
            consider_expected_text_local(string(Char($7684)));
            consider_expected_text_local(string(Char($5F97)));
            consider_expected_text_local(string(Char($5730)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'le') then
        begin
            consider_expected_text_local(string(Char($4E86)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'zhe') then
        begin
            consider_expected_text_local(string(Char($7740)));
            consider_expected_text_local(string(Char($8457)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'guo') then
        begin
            consider_expected_text_local(string(Char($8FC7)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'ma') then
        begin
            consider_expected_text_local(string(Char($5417)));
            consider_expected_text_local(string(Char($561B)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'ne') then
        begin
            consider_expected_text_local(string(Char($5462)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'ba') then
        begin
            consider_expected_text_local(string(Char($5427)));
            consider_expected_text_local(string(Char($7F62)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'la') then
        begin
            consider_expected_text_local(string(Char($5566)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'a') then
        begin
            consider_expected_text_local(string(Char($554A)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'ya') then
        begin
            consider_expected_text_local(string(Char($5440)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'wa') then
        begin
            consider_expected_text_local(string(Char($54C7)));
            Exit;
        end;

        if SameText(Trim(pinyin_key), 'ha') then
        begin
            consider_expected_text_local(string(Char($54C8)));
            Exit;
        end;
    end;

    function get_suffix_tail_bias_adjustment_for_syllable_local(
        const syllable_index: Integer; const best_single_text: string;
        const best_single_strength: Integer; out out_matched_text: string;
        out out_support_strength: Integer): Integer;
    var
        base_bias: Integer;
        pinyin_key: string;
    begin
        Result := 0;
        out_matched_text := '';
        out_support_strength := 0;
        if (syllable_index < 0) or (syllable_index > High(syllables)) then
        begin
            Exit;
        end;

        pinyin_key := Trim(syllables[syllable_index].text);
        base_bias := get_suffix_tail_bias_base_for_pinyin_key_local(pinyin_key);
        if base_bias <= 0 then
        begin
            Exit;
        end;

        out_support_strength := get_suffix_tail_expected_text_support_strength_local(
            syllable_index, pinyin_key, best_single_text, best_single_strength, out_matched_text);
        if out_support_strength <= 0 then
        begin
            Exit;
        end;

        Result := base_bias + Min(base_bias div 2, out_support_strength div 2);
    end;

    function try_get_best_exact_phrase_candidate_local(const pinyin_key: string;
        out out_text: string; out out_strength: Integer; out out_source: TncCandidateSource;
        out out_has_dict_weight: Boolean; out out_dict_weight: Integer): Boolean;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_weight: Integer;
    begin
        Result := False;
        out_text := '';
        out_strength := 0;
        out_source := cs_rule;
        out_has_dict_weight := False;
        out_dict_weight := 0;
        if not dictionary_lookup_cached(pinyin_key, local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units < 2 then
            begin
                Continue;
            end;

            local_weight := get_candidate_effective_weight_local(local_results[local_idx]);
            if local_weight > out_strength then
            begin
                out_text := local_results[local_idx].text;
                out_strength := local_weight;
                out_source := local_results[local_idx].source;
                out_has_dict_weight := local_results[local_idx].has_dict_weight;
                out_dict_weight := local_results[local_idx].dict_weight;
                Result := True;
            end;
        end;
    end;

    function try_get_best_scored_exact_phrase_candidate_local(const pinyin_key: string;
        out out_text: string; out out_strength: Integer; out out_source: TncCandidateSource;
        out out_has_dict_weight: Boolean; out out_dict_weight: Integer): Boolean;
    var
        local_results: TncCandidateList;
        local_idx: Integer;
        local_units: Integer;
        local_score: Integer;
        local_dict_weight: Integer;
    begin
        Result := False;
        out_text := '';
        out_strength := 0;
        out_source := cs_rule;
        out_has_dict_weight := False;
        out_dict_weight := 0;
        if not dictionary_lookup_cached(pinyin_key, local_results) then
        begin
            Exit;
        end;

        for local_idx := 0 to High(local_results) do
        begin
            if local_results[local_idx].comment <> '' then
            begin
                Continue;
            end;

            local_units := get_text_unit_count(Trim(local_results[local_idx].text));
            if local_units < 2 then
            begin
                Continue;
            end;

            // Once ab|c or a|bc is already decided, pick the phrase that would
            // win as a standalone two-syllable query. Provider score reflects
            // lexicon rerank and user recency better than raw dict weight.
            local_score := local_results[local_idx].score;
            local_dict_weight := 0;
            if local_results[local_idx].has_dict_weight then
            begin
                local_dict_weight := local_results[local_idx].dict_weight;
                if local_score <= 0 then
                begin
                    local_score := local_dict_weight;
                end;
            end;

            if (local_score > out_strength) or
                ((local_score = out_strength) and (local_dict_weight > out_dict_weight)) then
            begin
                out_text := local_results[local_idx].text;
                out_strength := local_score;
                out_source := local_results[local_idx].source;
                out_has_dict_weight := local_results[local_idx].has_dict_weight;
                out_dict_weight := local_results[local_idx].dict_weight;
                Result := True;
            end;
        end;
    end;

    procedure update_three_syllable_partial_preference_kind_local;
    const
        c_three_syllable_boundary_ratio_pct_local = 100;
        c_first_single_tail_bias_cap_local = 520;
        c_last_single_head_bias_cap_local = 620;
        c_boundary_alignment_bonus_cap_local = 620;
        c_boundary_alignment_penalty_cap_local = 260;
        c_boundary_alignment_unique_best_bonus_local = 260;
        c_boundary_alignment_mismatch_penalty_base_local = 120;
        c_boundary_alignment_mismatch_penalty_cap_local = 480;
        c_shared_tail_friendly_boundary_base_bias_local = 360;
        c_shared_tail_friendly_boundary_bonus_cap_local = 360;
        c_quantity_boundary_head_bias_base_local = 960;
        c_quantity_boundary_head_bias_cap_local = 420;
        c_quantity_boundary_tail_penalty_local = 280;
        c_suffix_tail_conflict_penalty_cap_local = 480;
        c_segmented_prefix_strength_penalty_local = 520;
        c_head_phrase_first_unit_mismatch_penalty_local = 560;
        c_head_phrase_first_unit_near_top_ratio_pct_local = 88;
        c_head_phrase_first_unit_near_top_gap_local = 64;
        c_head_phrase_first_unit_top_rank_window_local = 5;
        c_safe_trailing_initial_head_margin_local = 700;
    var
        first_single_text: string;
        first_single_strength: Integer;
        middle_single_text: string;
        middle_single_strength: Integer;
        last_single_text: string;
        last_single_strength: Integer;
        head_two_key: string;
        tail_two_key: string;
        head_two_exact_text: string;
        head_two_exact_strength: Integer;
        head_two_strength: Integer;
        head_two_source: TncCandidateSource;
        head_two_has_dict_weight: Boolean;
        head_two_dict_weight: Integer;
        tail_two_exact_text: string;
        tail_two_exact_strength: Integer;
        tail_two_source: TncCandidateSource;
        tail_two_has_dict_weight: Boolean;
        tail_two_dict_weight: Integer;
        tail_two_strength: Integer;
        segmented_head_strength: Integer;
        head_two_units: TArray<string>;
        tail_two_units: TArray<string>;
        head_two_first_unit_strength: Integer;
        head_two_first_unit_rank: Integer;
        head_two_first_unit_near_top: Boolean;
        head_two_first_unit_matches_best: Boolean;
        head_two_boundary_unit_strength: Integer;
        head_two_boundary_unit_rank: Integer;
        head_two_boundary_unit_near_top: Boolean;
        head_two_boundary_unit_matches_best: Boolean;
        tail_two_boundary_unit_strength: Integer;
        tail_two_boundary_unit_rank: Integer;
        tail_two_boundary_unit_near_top: Boolean;
        tail_two_boundary_unit_matches_best: Boolean;
        shared_tail_friendly_boundary_bias: Integer;
        shared_tail_friendly_unit_strength: Integer;
        preferred_boundary_unit_text: string;
        preferred_boundary_unit_strength: Integer;
        head_two_query_path_bonus: Integer;
        tail_two_query_path_bonus: Integer;
        head_two_lookup_results: TncCandidateList;
        head_two_lookup_idx: Integer;
        has_quantity_boundary_head_partial: Boolean;
        has_safe_trailing_initial_state: Boolean;
        normalized_text_local: string;
        prefix_text_local: string;
        tail_cluster_local: string;
        shifted_head_two_key_local: string;
        shifted_middle_key_local: string;
        shifted_tail_key_local: string;
        shifted_boundary_unit_text_local: string;
        shifted_boundary_unit_strength_local: Integer;
        suffix_tail_matched_text_local: string;
        suffix_tail_support_strength_local: Integer;
        suffix_tail_bias_local: Integer;
        suffix_tail_boundary_ratio_pct_local: Integer;
        suffix_tail_head_retention_bonus_local: Integer;
        tail_two_suffix_conflict_penalty_local: Integer;
        head_two_first_unit_penalty_local: Integer;

        function is_backward_attaching_boundary_unit_local(const text_value: string): Boolean;
        var
            normalized_text_value: string;
        begin
            Result := False;
            normalized_text_value := Trim(text_value);
            if get_text_unit_count(normalized_text_value) <> 1 then
            begin
                Exit;
            end;
            Result :=
                (normalized_text_value = string(Char($4E2A))) or // 个
                (normalized_text_value = string(Char($4F4D))) or // 位
                (normalized_text_value = string(Char($6B21))) or // 次
                (normalized_text_value = string(Char($70B9))) or // 点
                (normalized_text_value = string(Char($4E9B))) or // 些
                (normalized_text_value = string(Char($79CD))) or // 种
                (normalized_text_value = string(Char($5929))) or // 天
                (normalized_text_value = string(Char($5E74))) or // 年
                (normalized_text_value = string(Char($6708))) or // 月
                (normalized_text_value = string(Char($91CC))) or // 里
                (normalized_text_value = string(Char($4E0B))) or // 下
                (normalized_text_value = string(Char($56DE))) or // 回
                (normalized_text_value = string(Char($904D))) or // 遍
                (normalized_text_value = string(Char($58F0))) or // 声
                (normalized_text_value = string(Char($9762))) or // 面
                (normalized_text_value = string(Char($773C))) or // 眼
                (normalized_text_value = string(Char($8FB9)));   // 边
        end;
        function get_query_path_support_adjustment_local(const left_text: string;
            const right_text: string): Integer;
        var
            encoded_path: string;
            bonus_value: Integer;
            penalty_value: Integer;
        begin
            Result := 0;
            if (m_dictionary = nil) or (Trim(left_text) = '') or (Trim(right_text) = '') or
                (Trim(m_last_lookup_key) = '') then
            begin
                Exit;
            end;

            encoded_path := Trim(left_text) + c_segment_path_separator + Trim(right_text);
            bonus_value := m_dictionary.get_query_segment_path_bonus(m_last_lookup_key, encoded_path);
            penalty_value := m_dictionary.get_query_segment_path_penalty(m_last_lookup_key, encoded_path);
            Result := bonus_value - penalty_value;
        end;
    begin
        m_last_three_syllable_partial_preference_kind := 0;
        m_last_three_syllable_partial_debug_info := '';
        m_last_three_syllable_head_exact_text := '';
        m_last_three_syllable_head_strength := 0;
        m_last_three_syllable_tail_strength := 0;
        m_last_three_syllable_first_single_strength := 0;
        m_last_three_syllable_last_single_strength := 0;
        m_last_three_syllable_head_path_bonus := 0;
        m_last_three_syllable_tail_path_bonus := 0;
        if (not c_suppress_nonlexicon_complete_long_candidates) or
            (Length(syllables) < 3) then
        begin
            Exit;
        end;

        head_two_key := build_syllable_text(0, 2);
        tail_two_key := build_syllable_text(1, 2);
        head_two_exact_text := '';
        head_two_exact_strength := 0;
        head_two_source := cs_rule;
        head_two_has_dict_weight := False;
        head_two_dict_weight := 0;
        if not try_get_best_exact_phrase_candidate_local(head_two_key, head_two_exact_text,
            head_two_exact_strength, head_two_source, head_two_has_dict_weight,
            head_two_dict_weight) then
        begin
            head_two_exact_text := '';
            head_two_exact_strength := 0;
        end;
        head_two_strength := head_two_exact_strength;
        tail_two_exact_text := '';
        tail_two_exact_strength := 0;
        tail_two_source := cs_rule;
        tail_two_has_dict_weight := False;
        tail_two_dict_weight := 0;
        if not try_get_best_exact_phrase_candidate_local(tail_two_key, tail_two_exact_text,
            tail_two_exact_strength, tail_two_source, tail_two_has_dict_weight,
            tail_two_dict_weight) then
        begin
            tail_two_exact_text := '';
            tail_two_exact_strength := 0;
        end;
        tail_two_strength := tail_two_exact_strength;
        first_single_text := '';
        first_single_strength := 0;
        middle_single_text := '';
        middle_single_strength := 0;
        last_single_text := '';
        last_single_strength := 0;
        head_two_first_unit_near_top := False;
        head_two_first_unit_matches_best := False;
        head_two_boundary_unit_strength := 0;
        head_two_boundary_unit_near_top := False;
        head_two_boundary_unit_matches_best := False;
        tail_two_boundary_unit_strength := 0;
        tail_two_boundary_unit_rank := 0;
        tail_two_boundary_unit_near_top := False;
        tail_two_boundary_unit_matches_best := False;
        shared_tail_friendly_boundary_bias := 0;
        shared_tail_friendly_unit_strength := 0;
        preferred_boundary_unit_text := '';
        preferred_boundary_unit_strength := 0;
        head_two_query_path_bonus := 0;
        tail_two_query_path_bonus := 0;
        has_quantity_boundary_head_partial := False;
        shifted_head_two_key_local := '';
        shifted_middle_key_local := '';
        shifted_tail_key_local := '';
        shifted_boundary_unit_text_local := '';
        shifted_boundary_unit_strength_local := 0;
        suffix_tail_matched_text_local := '';
        suffix_tail_support_strength_local := 0;
        tail_two_suffix_conflict_penalty_local := 0;
        try_get_best_single_char_candidate_for_syllable_local(0, first_single_text,
            first_single_strength);
        try_get_best_single_char_candidate_for_syllable_local(1, middle_single_text,
            middle_single_strength);
        try_get_best_single_char_candidate_for_syllable_local(2, last_single_text,
            last_single_strength);
        suffix_tail_bias_local := get_suffix_tail_bias_adjustment_for_syllable_local(
            2, last_single_text, last_single_strength, suffix_tail_matched_text_local,
            suffix_tail_support_strength_local);
        suffix_tail_boundary_ratio_pct_local := c_three_syllable_boundary_ratio_pct_local;
        suffix_tail_head_retention_bonus_local := 0;
        if (suffix_tail_bias_local > 0) and (suffix_tail_support_strength_local > 0) and
            (suffix_tail_matched_text_local <> '') and (head_two_exact_strength > 0) then
        begin
            suffix_tail_boundary_ratio_pct_local :=
                get_suffix_tail_head_preference_ratio_pct_local(syllables[2].text);
            suffix_tail_head_retention_bonus_local :=
                get_suffix_tail_head_retention_bonus_local(syllables[2].text);
        end;
        try_get_best_boundary_unit_single_char_for_syllable_local(1, preferred_boundary_unit_text,
            preferred_boundary_unit_strength);
        if (preferred_boundary_unit_strength <= 0) and
            is_quantity_like_prefix_text_local(first_single_text) and
            try_get_shifted_boundary_unit_split_local(shifted_head_two_key_local,
            shifted_middle_key_local, shifted_tail_key_local,
            shifted_boundary_unit_text_local, shifted_boundary_unit_strength_local) then
        begin
            preferred_boundary_unit_text := shifted_boundary_unit_text_local;
            preferred_boundary_unit_strength := shifted_boundary_unit_strength_local;
            head_two_key := shifted_head_two_key_local;
            head_two_exact_text := '';
            head_two_exact_strength := 0;
            head_two_source := cs_rule;
            head_two_has_dict_weight := False;
            head_two_dict_weight := 0;
            if not try_get_best_exact_phrase_candidate_local(head_two_key, head_two_exact_text,
                head_two_exact_strength, head_two_source, head_two_has_dict_weight,
                head_two_dict_weight) then
            begin
                head_two_exact_text := '';
                head_two_exact_strength := 0;
            end;
            head_two_strength := head_two_exact_strength;
        end;
        if is_quantity_like_prefix_text_local(first_single_text) and
            (preferred_boundary_unit_strength > 0) then
        begin
            has_quantity_boundary_head_partial := True;
        end;
        if dictionary_lookup_cached(head_two_key, head_two_lookup_results) then
        begin
            for head_two_lookup_idx := 0 to High(head_two_lookup_results) do
            begin
                if (Trim(head_two_lookup_results[head_two_lookup_idx].comment) <> syllables[1].text) or
                    (not is_single_text_unit(Trim(head_two_lookup_results[head_two_lookup_idx].text))) or
                    (not is_quantity_like_prefix_text_local(
                    Trim(head_two_lookup_results[head_two_lookup_idx].text))) then
                begin
                    Continue;
                end;

                has_quantity_boundary_head_partial := True;
                Break;
            end;
        end;
        has_safe_trailing_initial_state := False;
        normalized_text_local := normalize_pinyin_text(m_composition_text);
        if Length(normalized_text_local) >= 3 then
        begin
            prefix_text_local := Copy(normalized_text_local, 1, Length(normalized_text_local) - 1);
            if is_single_initial_token(Copy(normalized_text_local, Length(normalized_text_local), 1)) and
                is_full_pinyin_key(prefix_text_local) then
            begin
                has_safe_trailing_initial_state := True;
            end;
        end;
        if (not has_safe_trailing_initial_state) and (Length(normalized_text_local) >= 4) then
        begin
            tail_cluster_local := Copy(normalized_text_local, Length(normalized_text_local) - 1, 2);
            prefix_text_local := Copy(normalized_text_local, 1, Length(normalized_text_local) - 2);
            if ((tail_cluster_local = 'zh') or (tail_cluster_local = 'ch') or
                (tail_cluster_local = 'sh')) and is_full_pinyin_key(prefix_text_local) then
            begin
                has_safe_trailing_initial_state := True;
            end;
        end;

        if head_two_exact_text <> '' then
        begin
            head_two_units := split_text_units(head_two_exact_text);
            if Length(head_two_units) > 0 then
            begin
                head_two_first_unit_strength := get_single_char_strength_for_text_at_syllable_local(0,
                    head_two_units[0]);
                head_two_first_unit_rank := get_single_char_rank_for_text_at_syllable_local(0,
                    head_two_units[0]);
                head_two_first_unit_matches_best := SameText(head_two_units[0], first_single_text);
                if (first_single_strength > 0) and (head_two_first_unit_strength > 0) then
                begin
                    head_two_first_unit_near_top :=
                        ((head_two_first_unit_strength * 100) >=
                        (first_single_strength * c_head_phrase_first_unit_near_top_ratio_pct_local)) or
                        ((first_single_strength - head_two_first_unit_strength) <=
                        c_head_phrase_first_unit_near_top_gap_local) or
                        ((head_two_first_unit_rank > 0) and
                        (head_two_first_unit_rank <= c_head_phrase_first_unit_top_rank_window_local));
                end;
            end;
            if Length(head_two_units) > 1 then
            begin
                head_two_boundary_unit_strength :=
                    get_single_char_strength_for_text_at_syllable_local(1, head_two_units[1]);
                head_two_boundary_unit_rank :=
                    get_single_char_rank_for_text_at_syllable_local(1, head_two_units[1]);
                head_two_boundary_unit_matches_best := SameText(head_two_units[1], middle_single_text);
                if (middle_single_strength > 0) and (head_two_boundary_unit_strength > 0) then
                begin
                    head_two_boundary_unit_near_top :=
                        ((head_two_boundary_unit_strength * 100) >=
                        (middle_single_strength * c_head_phrase_first_unit_near_top_ratio_pct_local)) or
                        ((middle_single_strength - head_two_boundary_unit_strength) <=
                        c_head_phrase_first_unit_near_top_gap_local) or
                        ((head_two_boundary_unit_rank > 0) and
                        (head_two_boundary_unit_rank <= c_head_phrase_first_unit_top_rank_window_local));
                end;
            end;
        end;

        if tail_two_exact_text <> '' then
        begin
            tail_two_units := split_text_units(tail_two_exact_text);
            if Length(tail_two_units) > 0 then
            begin
                tail_two_boundary_unit_strength :=
                    get_single_char_strength_for_text_at_syllable_local(1, tail_two_units[0]);
                tail_two_boundary_unit_rank :=
                    get_single_char_rank_for_text_at_syllable_local(1, tail_two_units[0]);
                tail_two_boundary_unit_matches_best := SameText(tail_two_units[0], middle_single_text);
                if (middle_single_strength > 0) and (tail_two_boundary_unit_strength > 0) then
                begin
                    tail_two_boundary_unit_near_top :=
                        ((tail_two_boundary_unit_strength * 100) >=
                        (middle_single_strength * c_head_phrase_first_unit_near_top_ratio_pct_local)) or
                        ((middle_single_strength - tail_two_boundary_unit_strength) <=
                        c_head_phrase_first_unit_near_top_gap_local) or
                        ((tail_two_boundary_unit_rank > 0) and
                        (tail_two_boundary_unit_rank <= c_head_phrase_first_unit_top_rank_window_local));
                end;
            end;
        end;

        if (tail_two_strength > 0) and (first_single_strength > 0) and
            (not head_two_first_unit_matches_best) then
        begin
            if not head_two_first_unit_near_top then
            begin
                Inc(tail_two_strength, Min(c_first_single_tail_bias_cap_local, first_single_strength));
            end;
        end;

        if (head_two_strength > 0) and (first_single_text <> '') then
        begin
            if (Length(head_two_units) > 0) and (head_two_units[0] <> first_single_text) then
            begin
                if not head_two_first_unit_near_top then
                begin
                    head_two_first_unit_penalty_local :=
                        c_head_phrase_first_unit_mismatch_penalty_local +
                        Min(180, first_single_strength div 2);
                    if suffix_tail_head_retention_bonus_local > 0 then
                    begin
                        head_two_first_unit_penalty_local := Min(
                            head_two_first_unit_penalty_local,
                            220 + Min(120, first_single_strength div 4));
                    end;
                    Dec(head_two_strength, head_two_first_unit_penalty_local);
                    if head_two_strength < 0 then
                    begin
                        head_two_strength := 0;
                    end;
                end;
            end;
        end;

        segmented_head_strength := get_best_single_char_strength_for_syllable_local(0) +
            get_best_single_char_strength_for_syllable_local(1);
        if (segmented_head_strength > 0) and (head_two_exact_strength <= 0) then
        begin
            Dec(segmented_head_strength, c_segmented_prefix_strength_penalty_local);
            if segmented_head_strength > head_two_strength then
            begin
                head_two_strength := segmented_head_strength;
            end;
        end;

        if (head_two_exact_strength > 0) and (last_single_strength > 0) then
        begin
            Inc(head_two_strength, Min(c_last_single_head_bias_cap_local,
                last_single_strength + Min(160, last_single_strength div 2)));
        end;

        if (head_two_exact_text <> '') and (last_single_text <> '') then
        begin
            head_two_query_path_bonus := get_query_path_support_adjustment_local(
                head_two_exact_text, last_single_text);
            if head_two_query_path_bonus <> 0 then
            begin
                Inc(head_two_strength, head_two_query_path_bonus);
            end;
        end;

        if (tail_two_exact_text <> '') and (first_single_text <> '') then
        begin
            tail_two_query_path_bonus := get_query_path_support_adjustment_local(
                first_single_text, tail_two_exact_text);
            if tail_two_query_path_bonus <> 0 then
            begin
                Inc(tail_two_strength, tail_two_query_path_bonus);
            end;
        end;

        if (suffix_tail_bias_local > 0) and (suffix_tail_support_strength_local > 0) and
            (suffix_tail_matched_text_local <> '') and (head_two_exact_strength > 0) then
        begin
            if (tail_two_exact_strength <= 0) or
                ((head_two_exact_strength * 100) >= (tail_two_exact_strength * 55)) then
            begin
                Inc(head_two_strength, suffix_tail_bias_local);
            end
            else
            begin
                Inc(head_two_strength, Max(180, suffix_tail_bias_local div 2));
            end;
            if suffix_tail_head_retention_bonus_local > 0 then
            begin
                Inc(head_two_strength, suffix_tail_head_retention_bonus_local);
            end;

            if (tail_two_exact_text <> '') and (Length(tail_two_units) > 1) and
                (not is_suffix_tail_expected_text_local(syllables[2].text, tail_two_units[1])) then
            begin
                tail_two_suffix_conflict_penalty_local := Min(
                    c_suffix_tail_conflict_penalty_cap_local,
                    Max(suffix_tail_support_strength_local div 2,
                    (suffix_tail_bias_local * 2) div 3));
                Dec(tail_two_strength, tail_two_suffix_conflict_penalty_local);
                if tail_two_strength < 0 then
                begin
                    tail_two_strength := 0;
                end;
            end;
        end;

        if (head_two_exact_strength > 0) and (tail_two_exact_strength <= 0) and
            (not has_quantity_boundary_head_partial) then
        begin
            m_last_three_syllable_partial_preference_kind := 2;
            m_last_three_syllable_head_exact_text := Trim(head_two_exact_text);
            m_last_three_syllable_head_strength := head_two_strength;
            m_last_three_syllable_tail_strength := tail_two_strength;
            m_last_three_syllable_first_single_strength := first_single_strength;
            m_last_three_syllable_last_single_strength := last_single_strength;
            m_last_three_syllable_head_path_bonus := head_two_query_path_bonus;
            m_last_three_syllable_tail_path_bonus := tail_two_query_path_bonus;
            Exit;
        end;

        if (tail_two_exact_strength > 0) and (head_two_exact_strength <= 0) and
            (not has_quantity_boundary_head_partial) then
        begin
            m_last_three_syllable_partial_preference_kind := 1;
            m_last_three_syllable_head_exact_text := Trim(head_two_exact_text);
            m_last_three_syllable_head_strength := head_two_strength;
            m_last_three_syllable_tail_strength := tail_two_strength;
            m_last_three_syllable_first_single_strength := first_single_strength;
            m_last_three_syllable_last_single_strength := last_single_strength;
            m_last_three_syllable_head_path_bonus := head_two_query_path_bonus;
            m_last_three_syllable_tail_path_bonus := tail_two_query_path_bonus;
            Exit;
        end;

        if (head_two_exact_strength > 0) and (tail_two_exact_strength > 0) then
        begin
            if (head_two_query_path_bonus <= 0) and
                ((suffix_tail_bias_local <= 0) or (suffix_tail_support_strength_local <= 0) or
                (suffix_tail_matched_text_local = '')) and
                ((tail_two_exact_strength - head_two_exact_strength) >= 220) then
            begin
                m_last_three_syllable_partial_preference_kind := 1;
                m_last_three_syllable_head_exact_text := Trim(head_two_exact_text);
                m_last_three_syllable_head_strength := head_two_strength;
                m_last_three_syllable_tail_strength := tail_two_strength;
                m_last_three_syllable_first_single_strength := first_single_strength;
                m_last_three_syllable_last_single_strength := last_single_strength;
                m_last_three_syllable_head_path_bonus := head_two_query_path_bonus;
                m_last_three_syllable_tail_path_bonus := tail_two_query_path_bonus;
                Exit;
            end;
        end;

        if has_quantity_boundary_head_partial and (preferred_boundary_unit_strength > 0) then
        begin
            Inc(head_two_strength, c_quantity_boundary_head_bias_base_local +
                Min(c_quantity_boundary_head_bias_cap_local,
                (first_single_strength + preferred_boundary_unit_strength) div 2));
            if tail_two_strength > 0 then
            begin
                Dec(tail_two_strength, c_quantity_boundary_tail_penalty_local);
                if tail_two_strength < 0 then
                begin
                    tail_two_strength := 0;
                end;
            end;
        end;

        if (head_two_exact_strength > 0) and head_two_boundary_unit_matches_best then
        begin
            Inc(head_two_strength, Min(c_boundary_alignment_bonus_cap_local, middle_single_strength));
            if (tail_two_exact_strength > 0) and (not tail_two_boundary_unit_near_top) then
            begin
                Dec(tail_two_strength, Min(c_boundary_alignment_penalty_cap_local,
                    middle_single_strength div 2));
                if tail_two_strength < 0 then
                begin
                    tail_two_strength := 0;
                end;
            end;
        end
        else if (tail_two_exact_strength > 0) and tail_two_boundary_unit_matches_best then
        begin
            Inc(tail_two_strength, Min(c_boundary_alignment_bonus_cap_local, middle_single_strength));
            if (head_two_exact_strength > 0) and (not head_two_boundary_unit_near_top) then
            begin
                Dec(head_two_strength, Min(c_boundary_alignment_penalty_cap_local,
                    middle_single_strength div 2));
                if head_two_strength < 0 then
                begin
                    head_two_strength := 0;
                end;
            end;
        end;

        if (head_two_exact_strength > 0) and head_two_boundary_unit_matches_best and
            (tail_two_exact_strength > 0) and (not tail_two_boundary_unit_matches_best) then
        begin
            Inc(head_two_strength, c_boundary_alignment_unique_best_bonus_local);
        end
        else if (tail_two_exact_strength > 0) and tail_two_boundary_unit_matches_best and
            (head_two_exact_strength > 0) and (not head_two_boundary_unit_matches_best) then
        begin
            Inc(tail_two_strength, c_boundary_alignment_unique_best_bonus_local);
        end;

        if (head_two_exact_strength > 0) and (middle_single_text <> '') and
            (Length(head_two_units) > 1) and (head_two_units[1] <> middle_single_text) and
            (not head_two_boundary_unit_near_top) then
        begin
            Dec(head_two_strength, Min(c_boundary_alignment_mismatch_penalty_cap_local,
                c_boundary_alignment_mismatch_penalty_base_local +
                Max(0, middle_single_strength - head_two_boundary_unit_strength)));
            if head_two_strength < 0 then
            begin
                head_two_strength := 0;
            end;
        end;

        if (tail_two_exact_strength > 0) and (middle_single_text <> '') and
            (Length(tail_two_units) > 0) and (tail_two_units[0] <> middle_single_text) and
            (not tail_two_boundary_unit_near_top) then
        begin
            Dec(tail_two_strength, Min(c_boundary_alignment_mismatch_penalty_cap_local,
                c_boundary_alignment_mismatch_penalty_base_local +
                Max(0, middle_single_strength - tail_two_boundary_unit_strength)));
            if tail_two_strength < 0 then
            begin
                tail_two_strength := 0;
            end;
        end;

        if (head_two_exact_text <> '') and (tail_two_exact_text <> '') then
        begin
            head_two_units := split_text_units(head_two_exact_text);
            tail_two_units := split_text_units(tail_two_exact_text);
            if (Length(head_two_units) = 2) and (Length(tail_two_units) = 2) and
                (head_two_units[1] = tail_two_units[0]) and
                is_backward_attaching_boundary_unit_local(head_two_units[1]) then
            begin
                shared_tail_friendly_unit_strength :=
                    get_single_char_strength_for_text_at_syllable_local(1, head_two_units[1]);
                shared_tail_friendly_boundary_bias :=
                    c_shared_tail_friendly_boundary_base_bias_local +
                    Min(c_shared_tail_friendly_boundary_bonus_cap_local,
                    shared_tail_friendly_unit_strength);
                Inc(head_two_strength, shared_tail_friendly_boundary_bias);
                Dec(tail_two_strength, shared_tail_friendly_boundary_bias div 2);
                if tail_two_strength < 0 then
                begin
                    tail_two_strength := 0;
                end;
            end;
        end;

        m_last_three_syllable_head_exact_text := Trim(head_two_exact_text);
        m_last_three_syllable_head_strength := head_two_strength;
        m_last_three_syllable_tail_strength := tail_two_strength;
        m_last_three_syllable_first_single_strength := first_single_strength;
        m_last_three_syllable_last_single_strength := last_single_strength;
        m_last_three_syllable_head_path_bonus := head_two_query_path_bonus;
        m_last_three_syllable_tail_path_bonus := tail_two_query_path_bonus;

        if m_config.debug_mode then
        begin
            m_last_three_syllable_partial_debug_info := Format(
                ' b3head=%d b3tail=%d b3first=%d b3last=%d b3link=%d b3qty=%d b3unit=%d b3sfx=%d b3hpath=%d b3tpath=%d headkey=%s tailkey=%s',
                [head_two_strength, tail_two_strength, first_single_strength, last_single_strength,
                shared_tail_friendly_boundary_bias, Ord(has_quantity_boundary_head_partial),
                preferred_boundary_unit_strength, suffix_tail_bias_local, head_two_query_path_bonus,
                tail_two_query_path_bonus, head_two_key, tail_two_key]);
        end;

        if has_quantity_boundary_head_partial and (preferred_boundary_unit_strength > 0) then
        begin
            m_last_three_syllable_partial_preference_kind := 2;
            Exit;
        end;

        if has_safe_trailing_initial_state and (tail_two_strength <= 0) and
            (first_single_strength > 0) then
        begin
            if (head_two_strength <= 0) or
                ((head_two_strength - first_single_strength) <=
                c_safe_trailing_initial_head_margin_local) then
            begin
                m_last_three_syllable_partial_preference_kind := 1;
            end
            else
            begin
                m_last_three_syllable_partial_preference_kind := 2;
            end;
            Exit;
        end;

        if (tail_two_strength > 0) and
            ((head_two_strength <= 0) or
            ((tail_two_strength * 100) >=
            (head_two_strength * suffix_tail_boundary_ratio_pct_local))) then
        begin
            m_last_three_syllable_partial_preference_kind := 1;
        end
        else if head_two_strength > 0 then
        begin
            m_last_three_syllable_partial_preference_kind := 2;
        end;
    end;

    procedure append_three_syllable_head_only_anchor_partial_candidates; forward;

    function merge_source_rank(const left: TncCandidateSource; const right: TncCandidateSource): TncCandidateSource;
    begin
        if (left = cs_user) or (right = cs_user) then
        begin
            Result := cs_user;
        end
        else
        begin
            Result := cs_rule;
        end;
    end;

    procedure append_candidate(const text: string; const score: Integer;
        const source: TncCandidateSource;
        const comment_override: string;
        const has_dict_weight: Boolean = False;
        const dict_weight: Integer = 0);
    begin
        if text = '' then
        begin
            Exit;
        end;

        dedup_key := LowerCase(Trim(text)) + #1 + comment_override;
        if dedup.TryGetValue(dedup_key, existing_index) then
        begin
            if (existing_index >= 0) and (existing_index < list.Count) then
            begin
                item := list[existing_index];
                if score > item.score then
                begin
                    item.score := score;
                end;
                item.source := merge_source_rank(item.source, source);
                if has_dict_weight then
                begin
                    if (not item.has_dict_weight) or (dict_weight > item.dict_weight) then
                    begin
                        item.has_dict_weight := True;
                        item.dict_weight := dict_weight;
                    end;
                end;
                list[existing_index] := item;
            end;
            Exit;
        end;

        item.text := text;
        item.comment := comment_override;
        item.score := score;
        item.source := source;
        item.has_dict_weight := (source = cs_rule) and has_dict_weight;
        if item.has_dict_weight then
        begin
            item.dict_weight := dict_weight;
        end
        else
        begin
            item.dict_weight := 0;
        end;
        list.Add(item);
        dedup.Add(dedup_key, list.Count - 1);
    end;

    procedure append_three_syllable_head_only_anchor_partial_candidates;
    const
        c_anchor_partial_bonus_local = 420;
        c_anchor_partial_hint_kind_scale_local = 10000;
        c_anchor_partial_hint_one_plus_two_local = 1;
        c_anchor_partial_hint_two_plus_one_local = 2;
        c_anchor_partial_tail_bonus_scale_local = 4;
        c_anchor_partial_remaining_penalty_local = 36;
        c_anchor_partial_non_preferred_penalty_local = 220;
        c_anchor_partial_non_preferred_gap_local = 48;
        c_boundary_anchor_partial_score_hint_flag_local = 1000000;
        c_segmented_prefix_strength_penalty_local = 520;
    var
        anchor_hint_local: Integer;
        remaining_pinyin: string;
        boundary_tail_key: string;
        anchor_text: string;
        anchor_strength: Integer;
        anchor_source: TncCandidateSource;
        anchor_has_dict_weight: Boolean;
        anchor_dict_weight: Integer;
        tail_strength: Integer;
        first_unit_text: string;
        first_unit_strength: Integer;
        second_unit_text: string;
        second_unit_strength: Integer;
        exact_head_key: string;
        score_value_local: Integer;
        remaining_single_text_local: string;
        remaining_single_strength_local: Integer;
        shifted_head_two_key_local: string;
        shifted_middle_key_local: string;
        shifted_tail_key_local: string;
        shifted_boundary_unit_text_local: string;
        shifted_boundary_unit_strength_local: Integer;
        use_shifted_boundary_local: Boolean;

        procedure append_exact_head_fallback_candidate(
            const preferred_score_value_local: Integer;
            const tail_support_strength_local: Integer);
        var
            fallback_text_local: string;
            fallback_strength_local: Integer;
            fallback_source_local: TncCandidateSource;
            fallback_has_dict_weight_local: Boolean;
            fallback_dict_weight_local: Integer;
            fallback_remaining_pinyin_local: string;
            fallback_last_single_text_local: string;
            fallback_last_single_strength_local: Integer;
            fallback_gap_penalty_local: Integer;
            fallback_score_local: Integer;
            fallback_hint_local: Integer;
        begin
            fallback_remaining_pinyin_local := build_syllable_text(2, Length(syllables) - 2);
            if fallback_remaining_pinyin_local = '' then
            begin
                Exit;
            end;

            if not try_get_best_scored_exact_phrase_candidate_local(build_syllable_text(0, 2),
                fallback_text_local, fallback_strength_local, fallback_source_local,
                fallback_has_dict_weight_local, fallback_dict_weight_local) then
            begin
                Exit;
            end;

            if get_candidate_text_unit_count(fallback_text_local) < 2 then
            begin
                Exit;
            end;

            fallback_last_single_text_local := '';
            fallback_last_single_strength_local := 0;
            try_get_best_single_char_candidate_for_syllable_local(2,
                fallback_last_single_text_local, fallback_last_single_strength_local);

            fallback_gap_penalty_local := 0;
            if tail_support_strength_local > fallback_strength_local then
            begin
                fallback_gap_penalty_local := Min(220,
                    (tail_support_strength_local - fallback_strength_local) div 3);
            end;

            fallback_score_local := fallback_strength_local + c_anchor_partial_bonus_local +
                Min(220, (fallback_strength_local + fallback_last_single_strength_local) div
                c_anchor_partial_tail_bonus_scale_local) -
                c_anchor_partial_remaining_penalty_local -
                c_anchor_partial_non_preferred_penalty_local -
                fallback_gap_penalty_local;
            if (preferred_score_value_local > 0) and
                (fallback_score_local >= preferred_score_value_local) then
            begin
                fallback_score_local := preferred_score_value_local -
                    c_anchor_partial_non_preferred_gap_local;
            end;

            if fallback_score_local <= 0 then
            begin
                Exit;
            end;

            append_candidate(fallback_text_local, fallback_score_local, fallback_source_local,
                fallback_remaining_pinyin_local, fallback_has_dict_weight_local,
                fallback_dict_weight_local);
            fallback_hint_local := c_boundary_anchor_partial_score_hint_flag_local +
                (c_anchor_partial_hint_two_plus_one_local *
                c_anchor_partial_hint_kind_scale_local) + fallback_score_local;
            remember_segment_path_score_hint_for_candidate(fallback_text_local,
                fallback_remaining_pinyin_local, fallback_hint_local);
        end;
    begin
        if include_full_path or (Length(syllables) < 3) or
            (not c_suppress_nonlexicon_complete_long_candidates) then
        begin
            Exit;
        end;

        if m_last_three_syllable_partial_preference_kind = 1 then
        begin
            score_value_local := 0;
            remaining_pinyin := build_syllable_text(1, Length(syllables) - 1);
            boundary_tail_key := build_syllable_text(1, 2);
            tail_strength := get_best_exact_phrase_strength_local(boundary_tail_key);
            if (remaining_pinyin <> '') and
                (not try_get_best_single_char_candidate_for_syllable_local(0, anchor_text,
                anchor_strength)) then
            begin
                anchor_text := '';
                anchor_strength := 0;
            end;
            if (remaining_pinyin <> '') and (anchor_text <> '') then
            begin
                score_value_local := anchor_strength + c_anchor_partial_bonus_local +
                    Min(220, tail_strength div c_anchor_partial_tail_bonus_scale_local) -
                    (2 * c_anchor_partial_remaining_penalty_local);
                append_candidate(anchor_text, score_value_local, cs_rule, remaining_pinyin);
                anchor_hint_local := c_boundary_anchor_partial_score_hint_flag_local +
                    (c_anchor_partial_hint_one_plus_two_local * c_anchor_partial_hint_kind_scale_local) +
                    score_value_local;
                remember_segment_path_score_hint_for_candidate(anchor_text, remaining_pinyin,
                    anchor_hint_local);
            end;

            append_exact_head_fallback_candidate(score_value_local, tail_strength);
        end
        else if m_last_three_syllable_partial_preference_kind = 2 then
        begin
            shifted_head_two_key_local := '';
            shifted_middle_key_local := '';
            shifted_tail_key_local := '';
            shifted_boundary_unit_text_local := '';
            shifted_boundary_unit_strength_local := 0;
            use_shifted_boundary_local := False;
            first_unit_text := '';
            first_unit_strength := 0;
            try_get_best_single_char_candidate_for_syllable_local(0, first_unit_text,
                first_unit_strength);
            if is_quantity_like_prefix_text_local(first_unit_text) and
                try_get_shifted_boundary_unit_split_local(shifted_head_two_key_local,
                shifted_middle_key_local, shifted_tail_key_local,
                shifted_boundary_unit_text_local, shifted_boundary_unit_strength_local) then
            begin
                use_shifted_boundary_local := True;
                remaining_pinyin := shifted_tail_key_local;
                exact_head_key := shifted_head_two_key_local;
            end
            else
            begin
                remaining_pinyin := build_syllable_text(2, Length(syllables) - 2);
                exact_head_key := build_syllable_text(0, 2);
            end;
            anchor_text := '';
            anchor_strength := 0;
            anchor_source := cs_rule;
            anchor_has_dict_weight := False;
            anchor_dict_weight := 0;
            if not try_get_best_scored_exact_phrase_candidate_local(exact_head_key, anchor_text, anchor_strength,
                anchor_source, anchor_has_dict_weight, anchor_dict_weight) then
            begin
                if (first_unit_text <> '') and
                    (((is_quantity_like_prefix_text_local(first_unit_text) and
                    (use_shifted_boundary_local or
                    try_get_best_boundary_unit_single_char_for_syllable_local(1, second_unit_text,
                    second_unit_strength))) or
                    try_get_best_single_char_candidate_for_syllable_local(1, second_unit_text,
                    second_unit_strength))) then
                begin
                    if use_shifted_boundary_local then
                    begin
                        second_unit_text := shifted_boundary_unit_text_local;
                        second_unit_strength := shifted_boundary_unit_strength_local;
                    end;
                    anchor_text := first_unit_text + second_unit_text;
                    anchor_strength := first_unit_strength + second_unit_strength -
                        c_segmented_prefix_strength_penalty_local;
                    if anchor_strength < 0 then
                    begin
                        anchor_strength := 0;
                    end;
                    anchor_source := cs_rule;
                    anchor_has_dict_weight := False;
                    anchor_dict_weight := 0;
                end;
            end;

            if (remaining_pinyin <> '') and (anchor_text <> '') then
            begin
                remaining_single_text_local := '';
                remaining_single_strength_local := 0;
                try_get_best_single_char_candidate_for_syllable_local(2, remaining_single_text_local,
                    remaining_single_strength_local);
                score_value_local := anchor_strength + c_anchor_partial_bonus_local +
                    Min(220, (anchor_strength + remaining_single_strength_local) div
                    c_anchor_partial_tail_bonus_scale_local) -
                    c_anchor_partial_remaining_penalty_local;
                append_candidate(anchor_text, score_value_local, anchor_source, remaining_pinyin,
                    anchor_has_dict_weight, anchor_dict_weight);
                anchor_hint_local := c_boundary_anchor_partial_score_hint_flag_local +
                    (c_anchor_partial_hint_two_plus_one_local * c_anchor_partial_hint_kind_scale_local) +
                    score_value_local;
                remember_segment_path_score_hint_for_candidate(anchor_text, remaining_pinyin,
                    anchor_hint_local);
            end;
        end;
    end;

    procedure append_long_prefix_phrase_anchor_partial_candidates;
    const
        c_long_prefix_anchor_bonus_local = 560;
        c_long_prefix_strength_scale_local = 4;
        c_long_prefix_remaining_penalty_local = 64;
    var
        prefix_key: string;
        remaining_pinyin: string;
        anchor_text: string;
        anchor_strength: Integer;
        anchor_source: TncCandidateSource;
        anchor_has_dict_weight: Boolean;
        anchor_dict_weight: Integer;
        remaining_syllables_local: Integer;
        score_value_local: Integer;
    begin
        if include_full_path or (Length(syllables) < 4) or
            (not c_suppress_nonlexicon_complete_long_candidates) then
        begin
            Exit;
        end;

        prefix_key := build_syllable_text(0, 3);
        remaining_syllables_local := Length(syllables) - 3;
        if remaining_syllables_local <= 0 then
        begin
            Exit;
        end;
        remaining_pinyin := build_syllable_text(3, remaining_syllables_local);
        if remaining_pinyin = '' then
        begin
            Exit;
        end;

        anchor_text := '';
        anchor_strength := 0;
        anchor_source := cs_rule;
        anchor_has_dict_weight := False;
        anchor_dict_weight := 0;
        if not try_get_best_scored_exact_phrase_candidate_local(prefix_key, anchor_text, anchor_strength,
            anchor_source, anchor_has_dict_weight, anchor_dict_weight) then
        begin
            Exit;
        end;

        if get_candidate_text_unit_count(anchor_text) < 2 then
        begin
            Exit;
        end;

        score_value_local := anchor_strength + c_long_prefix_anchor_bonus_local +
            Min(220, anchor_strength div c_long_prefix_strength_scale_local) -
            (remaining_syllables_local * c_long_prefix_remaining_penalty_local);
        append_candidate(anchor_text, score_value_local, anchor_source, remaining_pinyin,
            anchor_has_dict_weight, anchor_dict_weight);
    end;

    procedure append_full_path_candidates;
    var
        states: TArray<TList<TncSegmentPathState>>;
        state_dedup: TArray<TDictionary<string, Integer>>;
        transition_bonus_cache: TDictionary<string, Integer>;
        state_pos: Integer;
        next_pos: Integer;
        local_segment_len: Integer;
        local_segment_text: string;
        local_lookup_results: TncCandidateList;
        state_index: Integer;
        candidate_index: Integer;
        final_index: Integer;
        existing_state_index: Integer;
        keep_count: Integer;
        full_non_user_added: Integer;
        full_head_top_n: Integer;
        full_path_non_user_limit: Integer;
        full_path_budget_ms_limit: Integer;
        full_state_limit_limit: Integer;
        long_sentence_full_path_mode: Boolean;
        local_state: TncSegmentPathState;
        local_candidate: TncCandidate;
        local_new_state: TncSegmentPathState;
        local_existing_state: TncSegmentPathState;
        sorted_states: TArray<TncSegmentPathState>;
        local_key: string;
        allow_leading_single_char: Boolean;
        allow_single_char_path: Boolean;
        preferred_phrase_flags: TArray<Boolean>;
        preferred_phrase_max_len: TArray<Integer>;
        preferred_phrase_strength: TArray<Integer>;
        preferred_two_syllable_phrase_strength: TArray<Integer>;
        preferred_single_strength: TArray<Integer>;
        single_char_rank_maps: TArray<TDictionary<string, Integer>>;
        segment_units: TArray<string>;
        text_unit_mismatch: Integer;
        candidate_has_non_ascii: Boolean;
        local_candidate_text: string;
        local_incremental_path_bonus: Integer;
        local_rank_map: TDictionary<string, Integer>;
        local_rank: Integer;
        local_path_confidence_score: Integer;
        local_path_penalty_value: Integer;
        local_path_preference_score: Integer;
        local_recent_ranked_bonus: Integer;
        local_path_transition_bonus: Integer;
        local_query_path_bonus: Integer;
        local_segment_count: Integer;
        local_segment_quality_bonus: Integer;
        local_chain_shape_bonus: Integer;
        full_path_budget_start_tick: UInt64;
        full_path_budget_work_counter: Integer;
        full_path_budget_exhausted: Boolean;
        final_complete_state_count: Integer;
        final_complete_multiseg_state_count: Integer;
        final_complete_debug_paths: string;
        final_position_debug_counts: string;

        function build_state_key(const value: TncSegmentPathState): string;
        begin
            Result := LowerCase(Trim(value.text)) + #1 + LowerCase(Trim(value.prev_text)) +
                #1 + LowerCase(Trim(value.prev_pinyin_text)) + #1 +
                LowerCase(Trim(value.prev_prev_text)) + #1 +
                IntToStr(Ord(value.has_multi_segment));
        end;

        function compare_state(const left: TncSegmentPathState; const right: TncSegmentPathState): Integer;
        const
            c_state_path_preference_margin = 72;
            c_state_path_confidence_margin = 96;
            c_state_score_close_gap = 144;
        var
            score_gap: Integer;
            left_units: Integer;
            left_segment_count: Integer;
            path_confidence_gap: Integer;
            path_preference_gap: Integer;
            right_units: Integer;
            right_segment_count: Integer;
            source_compare: Integer;
            text_compare: Integer;
            function get_segment_count(const encoded_path: string): Integer;
            var
                idx: Integer;
            begin
                Result := 0;
                if Trim(encoded_path) = '' then
                begin
                    Exit;
                end;

                Result := 1;
                for idx := 1 to Length(encoded_path) do
                begin
                    if encoded_path[idx] = c_segment_path_separator then
                    begin
                        Inc(Result);
                    end;
                end;
            end;
        begin
            text_compare := CompareText(left.text, right.text);
            if text_compare = 0 then
            begin
                path_confidence_gap := left.path_confidence_score - right.path_confidence_score;
                if Abs(path_confidence_gap) >= c_state_path_confidence_margin then
                begin
                    if path_confidence_gap > 0 then
                    begin
                        Result := -1;
                    end
                    else
                    begin
                        Result := 1;
                    end;
                    Exit;
                end;

                path_preference_gap := left.path_preference_score - right.path_preference_score;
                if Abs(path_preference_gap) >= c_state_path_preference_margin then
                begin
                    if path_preference_gap > 0 then
                    begin
                        Result := -1;
                    end
                    else
                    begin
                        Result := 1;
                    end;
                    Exit;
                end;

                left_segment_count := get_segment_count(left.path_text);
                right_segment_count := get_segment_count(right.path_text);
                if left_segment_count < right_segment_count then
                begin
                    Result := -1;
                    Exit;
                end;
                if left_segment_count > right_segment_count then
                begin
                    Result := 1;
                    Exit;
                end;
            end;

            score_gap := Abs(left.score - right.score);
            if score_gap <= c_state_score_close_gap then
            begin
                path_confidence_gap := left.path_confidence_score - right.path_confidence_score;
                if Abs(path_confidence_gap) >= c_state_path_confidence_margin then
                begin
                    if path_confidence_gap > 0 then
                    begin
                        Result := -1;
                    end
                    else
                    begin
                        Result := 1;
                    end;
                    Exit;
                end;

                path_preference_gap := left.path_preference_score - right.path_preference_score;
                if Abs(path_preference_gap) >= c_state_path_preference_margin then
                begin
                    if path_preference_gap > 0 then
                    begin
                        Result := -1;
                    end
                    else
                    begin
                        Result := 1;
                    end;
                    Exit;
                end;
            end;

            if left.score > right.score then
            begin
                Result := -1;
                Exit;
            end;
            if left.score < right.score then
            begin
                Result := 1;
                Exit;
            end;

            source_compare := get_source_rank(left.source) - get_source_rank(right.source);
            if source_compare <> 0 then
            begin
                Result := source_compare;
                Exit;
            end;

            if left.has_multi_segment <> right.has_multi_segment then
            begin
                if left.has_multi_segment then
                begin
                    Result := -1;
                end
                else
                begin
                    Result := 1;
                end;
                Exit;
            end;

            left_units := get_text_unit_count(Trim(left.text));
            right_units := get_text_unit_count(Trim(right.text));
            if left_units > right_units then
            begin
                Result := -1;
                Exit;
            end;
            if left_units < right_units then
            begin
                Result := 1;
                Exit;
            end;

            Result := text_compare;
        end;

        procedure sort_state_array(var values: TArray<TncSegmentPathState>);
        var
            left_idx: Integer;
            right_idx: Integer;
            temp_state: TncSegmentPathState;
        begin
            if Length(values) <= 1 then
            begin
                Exit;
            end;

            for left_idx := 0 to High(values) - 1 do
            begin
                for right_idx := left_idx + 1 to High(values) do
                begin
                    if compare_state(values[left_idx], values[right_idx]) > 0 then
                    begin
                        temp_state := values[left_idx];
                        values[left_idx] := values[right_idx];
                        values[right_idx] := temp_state;
                    end;
                end;
            end;
        end;

        function get_exact_context_pair_bonus(const left_text: string; const candidate_text: string): Integer;
        const
            c_segment_pair_context_cap = 520;
            c_segment_pair_bonus_scale = 75;
        var
            pair_key: string;
            local_bonus: Integer;
            persistent_bonus: Integer;
            count: Integer;
            secondary_bonus: Integer;
        begin
            Result := 0;
            if (left_text = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            local_bonus := 0;
            persistent_bonus := 0;
            if m_context_pairs <> nil then
            begin
                pair_key := left_text + #1 + candidate_text;
                if m_context_pairs.TryGetValue(pair_key, count) and (count > 0) then
                begin
                    local_bonus := count * c_context_score_bonus;
                    if local_bonus > c_context_score_bonus_max then
                    begin
                        local_bonus := c_context_score_bonus_max;
                    end;
                end;
            end;

            if m_dictionary <> nil then
            begin
                persistent_bonus := m_dictionary.get_context_bonus(left_text, candidate_text);
            end;

            if local_bonus >= persistent_bonus then
            begin
                Result := local_bonus;
                secondary_bonus := persistent_bonus;
            end
            else
            begin
                Result := persistent_bonus;
                secondary_bonus := local_bonus;
            end;

            if secondary_bonus > 0 then
            begin
                Inc(Result, secondary_bonus div 2);
            end;
            if Result > c_segment_pair_context_cap then
            begin
                Result := c_segment_pair_context_cap;
            end;
            Result := (Result * c_segment_pair_bonus_scale) div 100;
        end;

        function get_phrase_trigram_transition_bonus(const prev_prev_text: string;
            const prev_text: string; const candidate_text: string): Integer;
        const
            c_segment_trigram_step = 96;
            c_segment_trigram_cap = 300;
            c_segment_trigram_recent_top = 140;
            c_segment_trigram_recent_mid = 84;
            c_segment_trigram_recent_tail = 40;
        var
            trigram_key: string;
            trigram_count: Integer;
            last_seen_serial: Int64;
            serial_gap: Int64;
        begin
            Result := 0;
            if (prev_prev_text = '') or (prev_text = '') or (candidate_text = '') or
                (m_phrase_context_pairs = nil) then
            begin
                Exit;
            end;

            trigram_key := prev_prev_text + #2 + prev_text + #1 + candidate_text;
            if (not m_phrase_context_pairs.TryGetValue(trigram_key, trigram_count)) or (trigram_count <= 0) then
            begin
                Exit;
            end;

            Result := trigram_count * c_segment_trigram_step;
            if Result > c_segment_trigram_cap then
            begin
                Result := c_segment_trigram_cap;
            end;

            if (m_phrase_context_last_seen <> nil) and
                m_phrase_context_last_seen.TryGetValue(trigram_key, last_seen_serial) and
                (last_seen_serial > 0) and (m_session_commit_serial >= last_seen_serial) then
            begin
                serial_gap := m_session_commit_serial - last_seen_serial;
                if serial_gap <= 1 then
                begin
                    Inc(Result, c_segment_trigram_recent_top);
                end
                else if serial_gap <= 3 then
                begin
                    Inc(Result, c_segment_trigram_recent_mid);
                end
                else if serial_gap <= 6 then
                begin
                    Inc(Result, c_segment_trigram_recent_tail);
                end;
            end;
        end;

        function get_compound_prev_trigram_bonus(const combined_prev_text: string;
            const candidate_text: string): Integer;
        var
            combined_units: TArray<string>;
            split_idx: Integer;
            unit_idx: Integer;
            left_part: string;
            right_part: string;
            local_session_bonus: Integer;
            local_persistent_bonus: Integer;
            local_secondary_bonus: Integer;
            local_bonus: Integer;
        begin
            Result := 0;
            if (combined_prev_text = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            combined_units := split_text_units(combined_prev_text);
            if Length(combined_units) < 2 then
            begin
                Exit;
            end;

            for split_idx := 1 to High(combined_units) do
            begin
                left_part := '';
                for unit_idx := 0 to split_idx - 1 do
                begin
                    left_part := left_part + combined_units[unit_idx];
                end;

                right_part := '';
                for unit_idx := split_idx to High(combined_units) do
                begin
                    right_part := right_part + combined_units[unit_idx];
                end;

                if (left_part = '') or (right_part = '') then
                begin
                    Continue;
                end;

                local_session_bonus := get_phrase_trigram_transition_bonus(
                    left_part, right_part, candidate_text);
                local_persistent_bonus := 0;
                if m_dictionary <> nil then
                begin
                    local_persistent_bonus := m_dictionary.get_context_trigram_bonus(
                        left_part, right_part, candidate_text);
                end;

                if local_session_bonus >= local_persistent_bonus then
                begin
                    local_bonus := local_session_bonus;
                    local_secondary_bonus := local_persistent_bonus;
                end
                else
                begin
                    local_bonus := local_persistent_bonus;
                    local_secondary_bonus := local_session_bonus;
                end;

                if local_secondary_bonus > 0 then
                begin
                    Inc(local_bonus, local_secondary_bonus div 2);
                end;

                if local_bonus > Result then
                begin
                    Result := local_bonus;
                end;
            end;
        end;

        function get_path_transition_bonus(const prev_prev_text: string; const prev_text: string;
            const candidate_text: string): Integer;
        var
            cache_key: string;
            pair_bonus: Integer;
            trigram_bonus: Integer;
            persistent_trigram_bonus: Integer;
            compound_prev_trigram_bonus: Integer;
            secondary_bonus: Integer;
        begin
            Result := 0;
            if (prev_text = '') or (candidate_text = '') then
            begin
                Exit;
            end;

            cache_key := prev_prev_text + #2 + prev_text + #1 + candidate_text;
            if (transition_bonus_cache <> nil) and transition_bonus_cache.TryGetValue(cache_key, Result) then
            begin
                Exit;
            end;

            pair_bonus := get_exact_context_pair_bonus(prev_text, candidate_text);
            trigram_bonus := get_phrase_trigram_transition_bonus(prev_prev_text, prev_text, candidate_text);
            persistent_trigram_bonus := 0;
            if (prev_prev_text <> '') and (m_dictionary <> nil) then
            begin
                persistent_trigram_bonus := m_dictionary.get_context_trigram_bonus(
                    prev_prev_text, prev_text, candidate_text);
            end;
            compound_prev_trigram_bonus := 0;
            if prev_prev_text = '' then
            begin
                compound_prev_trigram_bonus := get_compound_prev_trigram_bonus(
                    prev_text, candidate_text);
            end;

            if trigram_bonus >= persistent_trigram_bonus then
            begin
                Result := trigram_bonus;
                secondary_bonus := persistent_trigram_bonus;
            end
            else
            begin
                Result := persistent_trigram_bonus;
                secondary_bonus := trigram_bonus;
            end;

            if secondary_bonus > 0 then
            begin
                Inc(Result, secondary_bonus div 2);
            end;
            if compound_prev_trigram_bonus > Result then
            begin
                Result := compound_prev_trigram_bonus;
            end;

            if Result > 0 then
            begin
                Inc(Result, pair_bonus div 2);
            end
            else
            begin
                Result := pair_bonus;
            end;

            if transition_bonus_cache <> nil then
            begin
                transition_bonus_cache.AddOrSetValue(cache_key, Result);
            end;
        end;

        function get_segment_lexical_quality_bonus(const candidate: TncCandidate;
            const segment_len: Integer; const state_pos: Integer; const next_pos: Integer): Integer;
        var
            dict_weight_value: Integer;
            remaining_syllables: Integer;
            text_units: Integer;
        begin
            Result := 0;
            text_units := get_text_unit_count(Trim(candidate.text));
            if text_units <= 0 then
            begin
                Exit;
            end;

            remaining_syllables := Length(syllables) - next_pos;
            if candidate.source = cs_user then
            begin
                if (text_units = segment_len) and (segment_len >= 2) then
                begin
                    Result := 84 + (segment_len * 12);
                end;
                Exit;
            end;

            if candidate.has_dict_weight then
            begin
                dict_weight_value := candidate.dict_weight;
            end
            else
            begin
                dict_weight_value := candidate.score;
            end;

            if (text_units = segment_len) and (segment_len >= 2) then
            begin
                if dict_weight_value >= 760 then
                begin
                    Inc(Result, 180);
                end
                else if dict_weight_value >= 620 then
                begin
                    Inc(Result, 128);
                end
                else if dict_weight_value >= 480 then
                begin
                    Inc(Result, 84);
                end
                else if dict_weight_value >= 340 then
                begin
                    Inc(Result, 40);
                end;

                if (segment_len >= 3) and (dict_weight_value >= 420) then
                begin
                    Inc(Result, 28 + ((segment_len - 3) * 10));
                end;

                if next_pos = Length(syllables) then
                begin
                    if state_pos = 0 then
                    begin
                        Inc(Result, 96);
                    end
                    else
                    begin
                        Inc(Result, 44);
                    end;
                end
                else if remaining_syllables <= 2 then
                begin
                    Inc(Result, 20);
                end;
                Exit;
            end;

            if (segment_len = 1) and (remaining_syllables > 0) then
            begin
                if dict_weight_value < 260 then
                begin
                    Dec(Result, 72);
                end
                else if dict_weight_value < 360 then
                begin
                    Dec(Result, 44);
                end
                else
                begin
                    Dec(Result, 18);
                end;
                Exit;
            end;

            if text_units <> segment_len then
            begin
                Dec(Result, Abs(text_units - segment_len) * 36);
            end;
        end;

        function get_segment_chain_shape_bonus(const current_state: TncSegmentPathState;
            const segment_text_units: Integer; const segment_len: Integer;
            const state_pos: Integer; const next_pos: Integer): Integer;
        var
            previous_segment_count: Integer;
            previous_text_units: Integer;
            remaining_syllables: Integer;
        begin
            Result := 0;
            if segment_text_units <= 0 then
            begin
                Exit;
            end;

            previous_segment_count := get_encoded_path_segment_count_local(current_state.path_text);
            if Trim(current_state.path_text) = '' then
            begin
                previous_segment_count := 0;
            end;
            previous_text_units := get_text_unit_count(Trim(current_state.text));
            remaining_syllables := Length(syllables) - next_pos;

            if segment_text_units = segment_len then
            begin
                if segment_len >= 2 then
                begin
                    if previous_segment_count >= 1 then
                    begin
                        Inc(Result, 54);
                    end;
                    if (segment_len = 2) and (remaining_syllables = 2) then
                    begin
                        Inc(Result, 86);
                    end;
                    if (state_pos = 0) and (remaining_syllables >= 1) and (remaining_syllables <= 3) then
                    begin
                        Inc(Result, 44);
                    end;
                    if (remaining_syllables = 0) and (previous_text_units >= 2) then
                    begin
                        Inc(Result, 112);
                    end;
                end
                else if (segment_len = 1) and (previous_segment_count >= 1) then
                begin
                    if remaining_syllables > 0 then
                    begin
                        Dec(Result, 72);
                    end
                    else if previous_text_units >= 2 then
                    begin
                        Dec(Result, 36);
                    end;
                end;
                Exit;
            end;

            if (segment_len >= 2) and (Abs(segment_text_units - segment_len) = 1) and
                (previous_segment_count >= 1) then
            begin
                Dec(Result, 24);
            end;
        end;

        procedure append_state(const position: Integer; const value: TncSegmentPathState);
        begin
            local_key := build_state_key(value);
            if state_dedup[position].TryGetValue(local_key, existing_state_index) then
            begin
                if (existing_state_index >= 0) and (existing_state_index < states[position].Count) then
                begin
                    local_existing_state := states[position][existing_state_index];
                    if compare_state(value, local_existing_state) < 0 then
                    begin
                        local_existing_state := value;
                    end;
                    local_existing_state.source := merge_source_rank(local_existing_state.source, value.source);
                    states[position][existing_state_index] := local_existing_state;
                end;
                Exit;
            end;

            states[position].Add(value);
            state_dedup[position].Add(local_key, states[position].Count - 1);
        end;

        function full_path_budget_reached(const force_tick_check: Boolean = False): Boolean;
        begin
            Result := full_path_budget_exhausted;
            if Result then
            begin
                Exit;
            end;

            if not force_tick_check then
            begin
                Inc(full_path_budget_work_counter);
                if full_path_budget_work_counter < c_segment_full_path_budget_probe_interval then
                begin
                    Exit(False);
                end;
            end;

            full_path_budget_work_counter := 0;
            full_path_budget_exhausted :=
                Int64(GetTickCount64 - full_path_budget_start_tick) >= full_path_budget_ms_limit;
            Result := full_path_budget_exhausted;
        end;

        procedure record_final_debug_path(const value: string);
        begin
            if Trim(value) = '' then
            begin
                Exit;
            end;

            if final_complete_debug_paths = '' then
            begin
                final_complete_debug_paths := value;
            end
            else if Pos(value, final_complete_debug_paths) <= 0 then
            begin
                final_complete_debug_paths := final_complete_debug_paths + ' || ' + value;
            end;
        end;

        procedure append_position_debug_count(const position: Integer; const count: Integer);
        begin
            if final_position_debug_counts <> '' then
            begin
                final_position_debug_counts := final_position_debug_counts + ',';
            end;
            final_position_debug_counts := final_position_debug_counts + IntToStr(position) + ':' + IntToStr(count);
        end;

        procedure trim_state(const position: Integer);
        const
            c_segment_full_state_confidence_gap_limit = 320;
            c_segment_full_state_min_keep = 48;
            c_segment_full_state_score_gap_limit = 720;
        var
            best_path_confidence: Integer;
            best_score: Integer;
            dynamic_keep_count: Integer;
            idx: Integer;
        begin
            if states[position].Count <= full_state_limit_limit then
            begin
                Exit;
            end;

            SetLength(sorted_states, states[position].Count);
            for idx := 0 to states[position].Count - 1 do
            begin
                sorted_states[idx] := states[position][idx];
            end;
            sort_state_array(sorted_states);
            keep_count := full_state_limit_limit;
            if (not long_sentence_full_path_mode) and (keep_count > c_segment_full_state_min_keep) then
            begin
                best_score := sorted_states[0].score;
                best_path_confidence := sorted_states[0].path_confidence_score;
                dynamic_keep_count := c_segment_full_state_min_keep;
                for idx := c_segment_full_state_min_keep to keep_count - 1 do
                begin
                    if ((best_score - sorted_states[idx].score) > c_segment_full_state_score_gap_limit) and
                        ((best_path_confidence - sorted_states[idx].path_confidence_score) >
                        c_segment_full_state_confidence_gap_limit) then
                    begin
                        Break;
                    end;
                    dynamic_keep_count := idx + 1;
                end;
                keep_count := dynamic_keep_count;
            end;

            states[position].Clear;
            state_dedup[position].Clear;
            for idx := 0 to keep_count - 1 do
            begin
                states[position].Add(sorted_states[idx]);
                state_dedup[position].Add(build_state_key(sorted_states[idx]), idx);
            end;
        end;

        procedure append_long_sentence_exact_aligned_complete_candidates;
        const
            c_exact_state_limit = 64;
            c_exact_single_top_n = 2;
            c_exact_multi_top_n = 4;
            c_exact_complete_non_user_limit = 6;
            c_exact_single_penalty = 220;
            c_exact_multi_bonus = 260;
            c_exact_completion_bonus = 420;
            c_exact_continuation_bonus = 24;
        var
            exact_states: TArray<TList<TncSegmentPathState>>;
            exact_dedup: TArray<TDictionary<string, Integer>>;
            exact_sorted_states: TArray<TncSegmentPathState>;
            exact_state: TncSegmentPathState;
            exact_new_state: TncSegmentPathState;
            exact_existing_state: TncSegmentPathState;
            exact_candidate: TncCandidate;
            exact_lookup_results: TncCandidateList;
            exact_state_pos: Integer;
            exact_next_pos: Integer;
            exact_segment_len: Integer;
            exact_state_index: Integer;
            exact_candidate_index: Integer;
            exact_existing_state_index: Integer;
            exact_keep_count: Integer;
            exact_non_user_added: Integer;
            exact_segment_text: string;
            exact_candidate_text: string;
            exact_key: string;
            exact_units: Integer;
            exact_segment_count: Integer;
            exact_effective_weight: Integer;
            exact_transition_bonus: Integer;
            exact_pair_bonus: Integer;
            exact_candidate_limit: Integer;
            exact_is_preferred: Boolean;
            exact_multi_char_segment_count: Integer;

            function get_multi_char_segment_count(const encoded_path: string): Integer;
            var
                segment_parts: TArray<string>;
                part: string;
            begin
                Result := 0;
                if Trim(encoded_path) = '' then
                begin
                    Exit;
                end;

                segment_parts := encoded_path.Split([c_segment_path_separator]);
                for part in segment_parts do
                begin
                    if get_text_unit_count(Trim(part)) >= 2 then
                    begin
                        Inc(Result);
                    end;
                end;
            end;

            function is_long_sentence_allowed_single_char_text(const value: string): Boolean;
            begin
                Result := (value = '我') or (value = '你') or (value = '他') or (value = '她') or
                    (value = '它') or (value = '们') or (value = '和') or (value = '跟') or
                    (value = '与') or (value = '同') or (value = '去') or (value = '来') or
                    (value = '在') or (value = '是') or (value = '有') or (value = '要') or
                    (value = '想') or (value = '会') or (value = '能') or (value = '把') or
                    (value = '被') or (value = '让') or (value = '给') or (value = '向') or
                    (value = '到') or (value = '对') or (value = '从') or (value = '比') or
                    (value = '就') or (value = '还') or (value = '再') or (value = '也') or
                    (value = '都') or (value = '很') or (value = '不') or (value = '的') or
                    (value = '了') or (value = '着') or (value = '过') or (value = '将') or
                    (value = '为') or (value = '于') or (value = '中');
            end;

            procedure append_exact_state(const position: Integer; const value: TncSegmentPathState);
            begin
                exact_key := build_state_key(value);
                if exact_dedup[position].TryGetValue(exact_key, exact_existing_state_index) then
                begin
                    if (exact_existing_state_index >= 0) and
                        (exact_existing_state_index < exact_states[position].Count) then
                    begin
                        exact_existing_state := exact_states[position][exact_existing_state_index];
                        if compare_state(value, exact_existing_state) < 0 then
                        begin
                            exact_existing_state := value;
                        end;
                        exact_existing_state.source := merge_source_rank(
                            exact_existing_state.source, value.source);
                        exact_states[position][exact_existing_state_index] := exact_existing_state;
                    end;
                    Exit;
                end;

                exact_states[position].Add(value);
                exact_dedup[position].Add(exact_key, exact_states[position].Count - 1);
            end;

            procedure trim_exact_state(const position: Integer);
            var
                idx: Integer;
            begin
                if exact_states[position].Count <= c_exact_state_limit then
                begin
                    Exit;
                end;

                SetLength(exact_sorted_states, exact_states[position].Count);
                for idx := 0 to exact_states[position].Count - 1 do
                begin
                    exact_sorted_states[idx] := exact_states[position][idx];
                end;
                sort_state_array(exact_sorted_states);
                exact_keep_count := c_exact_state_limit;

                exact_states[position].Clear;
                exact_dedup[position].Clear;
                for idx := 0 to exact_keep_count - 1 do
                begin
                    exact_states[position].Add(exact_sorted_states[idx]);
                    exact_dedup[position].Add(build_state_key(exact_sorted_states[idx]), idx);
                end;
            end;
        begin
            SetLength(exact_states, Length(syllables) + 1);
            SetLength(exact_dedup, Length(syllables) + 1);
            try
                for exact_state_pos := 0 to High(exact_states) do
                begin
                    exact_states[exact_state_pos] := TList<TncSegmentPathState>.Create;
                    exact_dedup[exact_state_pos] := TDictionary<string, Integer>.Create;
                end;

                exact_state.text := '';
                exact_state.score := 0;
                exact_state.path_preference_score := 0;
                exact_state.path_confidence_score := 0;
                exact_state.source := cs_rule;
                exact_state.has_multi_segment := False;
                get_recent_path_context_seed(exact_state.prev_prev_text, exact_state.prev_text);
                exact_state.prev_pinyin_text := '';
                exact_state.path_text := '';
                exact_states[0].Add(exact_state);
                exact_dedup[0].Add(build_state_key(exact_state), 0);

                for exact_state_pos := 0 to High(syllables) do
                begin
                    if exact_states[exact_state_pos].Count = 0 then
                    begin
                        Continue;
                    end;

                    for exact_segment_len := 1 to Min(4, max_word_len) do
                    begin
                        if (exact_state_pos = 0) and (exact_segment_len = 1) then
                        begin
                            Continue;
                        end;
                        exact_next_pos := exact_state_pos + exact_segment_len;
                        if exact_next_pos > Length(syllables) then
                        begin
                            Break;
                        end;

                        exact_segment_text := build_syllable_text(exact_state_pos, exact_segment_len);
                        if (exact_segment_text = '') or
                            (not dictionary_lookup_cached(exact_segment_text, exact_lookup_results)) then
                        begin
                            Continue;
                        end;

                        if exact_segment_len = 1 then
                        begin
                            exact_candidate_limit := c_exact_single_top_n;
                        end
                        else
                        begin
                            exact_candidate_limit := c_exact_multi_top_n;
                        end;

                        for exact_state_index := 0 to exact_states[exact_state_pos].Count - 1 do
                        begin
                            exact_state := exact_states[exact_state_pos][exact_state_index];
                            for exact_candidate_index := 0 to High(exact_lookup_results) do
                            begin
                                if exact_candidate_index >= exact_candidate_limit then
                                begin
                                    Break;
                                end;

                                exact_candidate := exact_lookup_results[exact_candidate_index];
                                exact_candidate_text := Trim(exact_candidate.text);
                                if (exact_candidate_text = '') or
                                    (not contains_non_ascii(exact_candidate_text)) then
                                begin
                                    Continue;
                                end;

                                exact_units := get_text_unit_count(exact_candidate_text);
                                if exact_units <= 0 then
                                begin
                                    Continue;
                                end;

                                if exact_segment_len = 1 then
                                begin
                                    if (not is_single_text_unit(exact_candidate_text)) or
                                        (not is_long_sentence_allowed_single_char_text(exact_candidate_text)) or
                                        (not match_single_char_candidate_for_syllable(
                                        syllables[exact_state_pos].text, exact_candidate_text,
                                        exact_is_preferred)) or
                                        (not exact_is_preferred) then
                                    begin
                                        Continue;
                                    end;
                                end
                                else
                                begin
                                    if (not is_multi_char_word(exact_candidate_text)) or
                                        (exact_units <> exact_segment_len) then
                                    begin
                                        Continue;
                                    end;
                                end;

                                exact_new_state.text := exact_state.text + exact_candidate_text;
                                exact_new_state.score := exact_state.score;
                                exact_effective_weight := get_candidate_effective_weight_local(exact_candidate);
                                Inc(exact_new_state.score, exact_effective_weight);
                                exact_transition_bonus := get_path_transition_bonus(
                                    exact_state.prev_prev_text, exact_state.prev_text,
                                    exact_candidate_text);
                                if exact_transition_bonus <> 0 then
                                begin
                                    Inc(exact_new_state.score, exact_transition_bonus);
                                end;
                                exact_pair_bonus := get_exact_context_pair_bonus(
                                    exact_state.prev_text, exact_candidate_text);
                                if exact_pair_bonus <> 0 then
                                begin
                                    Inc(exact_new_state.score, exact_pair_bonus);
                                end;

                                if exact_segment_len = 1 then
                                begin
                                    Dec(exact_new_state.score, c_exact_single_penalty);
                                end
                                else
                                begin
                                    Inc(exact_new_state.score,
                                        c_exact_multi_bonus + (exact_segment_len * 24));
                                end;

                                if exact_next_pos = Length(syllables) then
                                begin
                                    Inc(exact_new_state.score, c_exact_completion_bonus);
                                end
                                else
                                begin
                                    Inc(exact_new_state.score, c_exact_continuation_bonus);
                                end;

                                exact_new_state.source := merge_source_rank(
                                    exact_state.source, exact_candidate.source);
                                exact_new_state.prev_prev_text := exact_state.prev_text;
                                exact_new_state.prev_text := exact_candidate_text;
                                exact_new_state.prev_pinyin_text := exact_segment_text;
                                exact_new_state.path_text := exact_state.path_text;
                                if exact_new_state.path_text <> '' then
                                begin
                                    exact_new_state.path_text := exact_new_state.path_text +
                                        c_segment_path_separator;
                                end;
                                exact_new_state.path_text := exact_new_state.path_text +
                                    exact_candidate_text;
                                exact_new_state.has_multi_segment :=
                                    get_encoded_path_segment_count_local(exact_new_state.path_text) > 1;
                                exact_new_state.path_preference_score := exact_transition_bonus + exact_pair_bonus;
                                exact_new_state.path_confidence_score := exact_new_state.path_preference_score;
                                if exact_new_state.path_confidence_score < 0 then
                                begin
                                    exact_new_state.path_confidence_score := 0;
                                end;
                                append_exact_state(exact_next_pos, exact_new_state);
                            end;
                        end;

                        trim_exact_state(exact_next_pos);
                    end;
                end;

                if exact_states[Length(syllables)].Count <= 0 then
                begin
                    Exit;
                end;

                SetLength(exact_sorted_states, exact_states[Length(syllables)].Count);
                for exact_state_pos := 0 to exact_states[Length(syllables)].Count - 1 do
                begin
                    exact_sorted_states[exact_state_pos] := exact_states[Length(syllables)][exact_state_pos];
                end;
                sort_state_array(exact_sorted_states);

                exact_non_user_added := 0;
                for exact_state_pos := 0 to High(exact_sorted_states) do
                begin
                    exact_state := exact_sorted_states[exact_state_pos];
                    exact_segment_count := get_encoded_path_segment_count_local(exact_state.path_text);
                    exact_multi_char_segment_count :=
                        get_multi_char_segment_count(exact_state.path_text);
                    if (exact_segment_count <= 1) or
                        (get_candidate_text_unit_count(exact_state.text) < 4) then
                    begin
                        Continue;
                    end;
                    if exact_multi_char_segment_count < 3 then
                    begin
                        Continue;
                    end;
                    if (exact_multi_char_segment_count * 2) < exact_segment_count then
                    begin
                        Continue;
                    end;
                    if (exact_state.source <> cs_user) and
                        (exact_non_user_added >= c_exact_complete_non_user_limit) then
                    begin
                        Continue;
                    end;

                    append_candidate(exact_state.text, exact_state.score + 1200,
                        exact_state.source, '');
                    remember_segment_path_for_candidate(exact_state.text, '',
                        exact_state.path_text, exact_state.score + 1200);
                    if exact_state.source <> cs_user then
                    begin
                        Inc(exact_non_user_added);
                    end;
                end;
            finally
                for exact_state_pos := 0 to High(exact_states) do
                begin
                    if exact_states[exact_state_pos] <> nil then
                    begin
                        exact_states[exact_state_pos].Free;
                    end;
                    if exact_dedup[exact_state_pos] <> nil then
                    begin
                        exact_dedup[exact_state_pos].Free;
                    end;
                end;
            end;
        end;

        procedure append_long_sentence_best_exact_candidate;
        type
            TLongSentenceOption = record
                text: string;
                path_text: string;
                score: Integer;
                source: TncCandidateSource;
                segment_count: Integer;
                multi_segment_count: Integer;
                found: Boolean;
            end;
        const
            c_search_multi_top_n = 3;
            c_search_single_top_n = 1;
            c_search_max_segment_len = 4;
            c_search_single_penalty = 120;
            c_search_multi_bonus = 260;
            c_search_completion_bonus = 420;
        var
            result_cache: TDictionary<string, TLongSentenceOption>;
            seed_prev_prev_text: string;
            seed_prev_text: string;

            function is_long_sentence_allowed_single_char_text_local(const value: string): Boolean;
            begin
                Result := (value = '我') or (value = '你') or (value = '他') or (value = '她') or
                    (value = '它') or (value = '们') or (value = '和') or (value = '跟') or
                    (value = '与') or (value = '同') or (value = '去') or (value = '来') or
                    (value = '在') or (value = '是') or (value = '有') or (value = '要') or
                    (value = '想') or (value = '会') or (value = '能') or (value = '把') or
                    (value = '被') or (value = '让') or (value = '给') or (value = '向') or
                    (value = '到') or (value = '对') or (value = '从') or (value = '比') or
                    (value = '就') or (value = '还') or (value = '再') or (value = '也') or
                    (value = '都') or (value = '很') or (value = '不') or (value = '的') or
                    (value = '了') or (value = '着') or (value = '过') or (value = '将') or
                    (value = '为') or (value = '于') or (value = '中');
            end;

            function is_better_long_sentence_option(const left: TLongSentenceOption;
                const right: TLongSentenceOption): Boolean;
            begin
                if not right.found then
                begin
                    Result := left.found;
                    Exit;
                end;
                if not left.found then
                begin
                    Result := False;
                    Exit;
                end;

                if left.score <> right.score then
                begin
                    Result := left.score > right.score;
                    Exit;
                end;
                if left.multi_segment_count <> right.multi_segment_count then
                begin
                    Result := left.multi_segment_count > right.multi_segment_count;
                    Exit;
                end;
                if left.segment_count <> right.segment_count then
                begin
                    Result := left.segment_count < right.segment_count;
                    Exit;
                end;
                Result := Length(left.text) > Length(right.text);
            end;

            function solve_long_sentence(const position: Integer; const prev_prev_text: string;
                const prev_text: string): TLongSentenceOption;
            var
                cache_key: string;
                best_option: TLongSentenceOption;
                suffix_option: TLongSentenceOption;
                candidate_option: TLongSentenceOption;
                lookup_results_local: TncCandidateList;
                candidate_local: TncCandidate;
                candidate_text_local: string;
                segment_text_local: string;
                segment_len_local: Integer;
                next_pos_local: Integer;
                candidate_index_local: Integer;
                candidate_limit_local: Integer;
                candidate_units_local: Integer;
                is_preferred_local: Boolean;
                candidate_weight_local: Integer;
                transition_bonus_local: Integer;
                pair_bonus_local: Integer;
            begin
                cache_key := IntToStr(position) + #1 + prev_prev_text + #1 + prev_text;
                if result_cache.TryGetValue(cache_key, Result) then
                begin
                    Exit;
                end;

                FillChar(best_option, SizeOf(best_option), 0);
                best_option.found := False;

                if position >= Length(syllables) then
                begin
                    best_option.found := True;
                    result_cache.AddOrSetValue(cache_key, best_option);
                    Result := best_option;
                    Exit;
                end;

                for segment_len_local := 1 to Min(c_search_max_segment_len, max_word_len) do
                begin
                    if (position = 0) and (segment_len_local = 1) then
                    begin
                        Continue;
                    end;

                    next_pos_local := position + segment_len_local;
                    if next_pos_local > Length(syllables) then
                    begin
                        Break;
                    end;

                    segment_text_local := build_syllable_text(position, segment_len_local);
                    if (segment_text_local = '') or
                        (not dictionary_lookup_cached(segment_text_local, lookup_results_local)) then
                    begin
                        Continue;
                    end;

                    if segment_len_local = 1 then
                    begin
                        candidate_limit_local := c_search_single_top_n;
                    end
                    else
                    begin
                        candidate_limit_local := c_search_multi_top_n;
                    end;

                    for candidate_index_local := 0 to High(lookup_results_local) do
                    begin
                        if candidate_index_local >= candidate_limit_local then
                        begin
                            Break;
                        end;

                        candidate_local := lookup_results_local[candidate_index_local];
                        candidate_text_local := Trim(candidate_local.text);
                        if (candidate_text_local = '') or
                            (not contains_non_ascii(candidate_text_local)) then
                        begin
                            Continue;
                        end;

                        candidate_units_local := get_text_unit_count(candidate_text_local);
                        if candidate_units_local <= 0 then
                        begin
                            Continue;
                        end;

                        if segment_len_local = 1 then
                        begin
                            if (not is_single_text_unit(candidate_text_local)) or
                                (not is_long_sentence_allowed_single_char_text_local(candidate_text_local)) or
                                (not match_single_char_candidate_for_syllable(
                                syllables[position].text, candidate_text_local, is_preferred_local)) or
                                (not is_preferred_local) then
                            begin
                                Continue;
                            end;
                        end
                        else
                        begin
                            if (not is_multi_char_word(candidate_text_local)) or
                                (candidate_units_local <> segment_len_local) then
                            begin
                                Continue;
                            end;
                        end;

                        suffix_option := solve_long_sentence(next_pos_local, prev_text, candidate_text_local);
                        if not suffix_option.found then
                        begin
                            Continue;
                        end;

                        candidate_option.found := True;
                        candidate_option.text := candidate_text_local + suffix_option.text;
                        candidate_option.path_text := candidate_text_local;
                        if suffix_option.path_text <> '' then
                        begin
                            candidate_option.path_text := candidate_option.path_text +
                                c_segment_path_separator + suffix_option.path_text;
                        end;
                        candidate_option.source := merge_source_rank(candidate_local.source,
                            suffix_option.source);
                        candidate_option.segment_count := suffix_option.segment_count + 1;
                        candidate_option.multi_segment_count := suffix_option.multi_segment_count;
                        if segment_len_local >= 2 then
                        begin
                            Inc(candidate_option.multi_segment_count);
                        end;

                        candidate_weight_local := get_candidate_effective_weight_local(candidate_local);
                        transition_bonus_local := get_path_transition_bonus(prev_prev_text, prev_text,
                            candidate_text_local);
                        pair_bonus_local := get_exact_context_pair_bonus(prev_text, candidate_text_local);

                        candidate_option.score := suffix_option.score + candidate_weight_local +
                            transition_bonus_local + pair_bonus_local;
                        if segment_len_local = 1 then
                        begin
                            Dec(candidate_option.score, c_search_single_penalty);
                        end
                        else
                        begin
                            Inc(candidate_option.score, c_search_multi_bonus + (segment_len_local * 24));
                        end;
                        if next_pos_local = Length(syllables) then
                        begin
                            Inc(candidate_option.score, c_search_completion_bonus);
                        end;

                        if is_better_long_sentence_option(candidate_option, best_option) then
                        begin
                            best_option := candidate_option;
                        end;
                    end;
                end;

                result_cache.AddOrSetValue(cache_key, best_option);
                Result := best_option;
            end;
        var
            best_option: TLongSentenceOption;
        begin
            result_cache := TDictionary<string, TLongSentenceOption>.Create;
            try
                get_recent_path_context_seed(seed_prev_prev_text, seed_prev_text);
                best_option := solve_long_sentence(0, seed_prev_prev_text, seed_prev_text);
                m_last_full_path_debug_info := Format(
                    ' longsent_best=[found=%d score=%d seg=%d multi=%d path=%s text=%s]',
                    [Ord(best_option.found), best_option.score, best_option.segment_count,
                    best_option.multi_segment_count, best_option.path_text, best_option.text]);
                if (not best_option.found) or
                    (best_option.multi_segment_count < 3) or
                    ((best_option.multi_segment_count * 2) < best_option.segment_count) or
                    (Trim(best_option.text) = '') then
                begin
                    Exit;
                end;

                append_candidate(best_option.text, best_option.score + 1200, best_option.source, '');
                remember_segment_path_for_candidate(best_option.text, '', best_option.path_text,
                    best_option.score + 1200);
            finally
                result_cache.Free;
            end;
        end;

        function detect_preferred_phrase_at_position(const start_pos: Integer): Boolean;
        var
            probe_segment_len: Integer;
            probe_segment_text: string;
            probe_lookup_results: TncCandidateList;
            probe_idx: Integer;
            probe_text: string;
            local_rank: Integer;
        begin
            Result := False;
            if (Length(syllables) <= 1) or (start_pos < 0) or (start_pos >= Length(syllables)) then
            begin
                Exit;
            end;

            for probe_segment_len := 2 to max_word_len do
            begin
                if start_pos + probe_segment_len > Length(syllables) then
                begin
                    Break;
                end;

                probe_segment_text := build_syllable_text(start_pos, probe_segment_len);
                if probe_segment_text = '' then
                begin
                    Continue;
                end;

                if not dictionary_lookup_cached(probe_segment_text, probe_lookup_results) then
                begin
                    Continue;
                end;

                if (per_limit > 0) and (Length(probe_lookup_results) > per_limit) then
                begin
                    SetLength(probe_lookup_results, per_limit);
                end;

                for probe_idx := 0 to High(probe_lookup_results) do
                begin
                    probe_text := Trim(probe_lookup_results[probe_idx].text);
                    if (probe_text = '') or (not contains_non_ascii(probe_text)) then
                    begin
                        Continue;
                    end;

                    if get_text_unit_count(probe_text) > 1 then
                    begin
                        if probe_lookup_results[probe_idx].has_dict_weight then
                        begin
                            local_rank := probe_lookup_results[probe_idx].dict_weight;
                        end
                        else
                        begin
                            local_rank := probe_lookup_results[probe_idx].score;
                        end;
                        if local_rank > preferred_phrase_strength[start_pos] then
                        begin
                            preferred_phrase_strength[start_pos] := local_rank;
                        end;
                        if (probe_segment_len = 2) and
                            (local_rank > preferred_two_syllable_phrase_strength[start_pos]) then
                        begin
                            preferred_two_syllable_phrase_strength[start_pos] := local_rank;
                        end;
                        if probe_segment_len > preferred_phrase_max_len[start_pos] then
                        begin
                            preferred_phrase_max_len[start_pos] := probe_segment_len;
                        end;
                        Result := True;
                        Exit;
                    end;
                end;
            end;
        end;

        function detect_preferred_single_strength_at_position(const start_pos: Integer): Integer;
        var
            probe_lookup_results: TncCandidateList;
            probe_idx: Integer;
            probe_text: string;
            probe_rank: Integer;
            is_preferred: Boolean;
        begin
            Result := 0;
            if (start_pos < 0) or (start_pos >= Length(syllables)) then
            begin
                Exit;
            end;

            if not dictionary_lookup_cached(syllables[start_pos].text, probe_lookup_results) then
            begin
                Exit;
            end;

            if (per_limit > 0) and (Length(probe_lookup_results) > per_limit) then
            begin
                SetLength(probe_lookup_results, per_limit);
            end;

            for probe_idx := 0 to High(probe_lookup_results) do
            begin
                probe_text := Trim(probe_lookup_results[probe_idx].text);
                if (probe_text = '') or
                    (not is_single_text_unit(probe_text)) or
                    (not contains_non_ascii(probe_text)) then
                begin
                    Continue;
                end;
                if not match_single_char_candidate_for_syllable(
                    syllables[start_pos].text, probe_text, is_preferred) or
                    (not is_preferred) then
                begin
                    Continue;
                end;

                if probe_lookup_results[probe_idx].has_dict_weight then
                begin
                    probe_rank := probe_lookup_results[probe_idx].dict_weight;
                end
                else
                begin
                    probe_rank := probe_lookup_results[probe_idx].score;
                end;
                if probe_rank > Result then
                begin
                    Result := probe_rank;
                end;
            end;
        end;

        function get_segment_boundary_cohesion_bonus(const current_state: TncSegmentPathState;
            const candidate: TncCandidate; const segment_text_units: Integer;
            const segment_len: Integer; const state_pos: Integer; const next_pos: Integer): Integer;
        const
            c_boundary_strength_bonus_cap = 132;
            c_boundary_follow_scale = 7;
            c_boundary_prefix_scale = 6;
            c_boundary_weak_single_penalty = 24;
            c_boundary_gap_penalty = 42;
            c_three_syllable_tail_phrase_bonus = 132;
            c_three_syllable_tail_phrase_penalty = 284;
            c_three_syllable_tail_phrase_soft_penalty = 112;
            c_three_syllable_weak_tail_phrase_penalty = 420;
            c_suffix_tail_phrase_bonus_cap = 420;
        var
            remaining_syllables: Integer;
            current_phrase_strength: Integer;
            next_phrase_strength: Integer;
            next_single_chain_strength: Integer;
            overlapping_phrase_strength: Integer;
            previous_text_units: Integer;
            suffix_tail_matched_text: string;
            suffix_tail_support_strength: Integer;
            suffix_tail_bias: Integer;
        begin
            Result := 0;
            if not c_suppress_nonlexicon_complete_long_candidates then
            begin
                Exit;
            end;

            remaining_syllables := Length(syllables) - next_pos;
            previous_text_units := get_text_unit_count(Trim(current_state.text));

            current_phrase_strength := 0;
            if (segment_text_units = segment_len) and (segment_len >= 2) and
                contains_non_ascii(Trim(candidate.text)) then
            begin
                if candidate.has_dict_weight then
                begin
                    current_phrase_strength := candidate.dict_weight;
                end
                else
                begin
                    current_phrase_strength := candidate.score;
                end;
            end;

            next_phrase_strength := 0;
            if (next_pos >= 0) and (next_pos < Length(preferred_phrase_strength)) then
            begin
                next_phrase_strength := preferred_phrase_strength[next_pos];
            end;

            overlapping_phrase_strength := 0;
            if (state_pos = 0) and (Length(syllables) = 3) and
                (Length(preferred_phrase_strength) > 1) then
            begin
                overlapping_phrase_strength := preferred_phrase_strength[1];
            end;

            next_single_chain_strength := 0;
            if (state_pos = 0) and (segment_len = 1) and (remaining_syllables = 2) and
                (next_pos >= 0) and (next_pos + 1 < Length(preferred_single_strength)) then
            begin
                next_single_chain_strength := preferred_single_strength[next_pos] +
                    preferred_single_strength[next_pos + 1];
            end;

            suffix_tail_matched_text := '';
            suffix_tail_support_strength := 0;
            suffix_tail_bias := 0;
            if (segment_len >= 2) and (remaining_syllables = 1) and
                (next_pos >= 0) and (next_pos < Length(syllables)) then
            begin
                suffix_tail_bias := get_suffix_tail_bias_adjustment_for_syllable_local(
                    next_pos, '', 0, suffix_tail_matched_text,
                    suffix_tail_support_strength);
            end;

            if (state_pos = 0) and (remaining_syllables > 0) then
            begin
                if segment_len = 1 then
                begin
                    if next_phrase_strength > 0 then
                    begin
                        Inc(Result, Min(c_boundary_strength_bonus_cap,
                            next_phrase_strength div c_boundary_follow_scale));
                    end
                    else if remaining_syllables >= 2 then
                    begin
                        Dec(Result, c_boundary_weak_single_penalty);
                    end;
                    if (Length(syllables) = 3) and (remaining_syllables = 2) and
                        (next_phrase_strength > 0) then
                    begin
                        if (next_single_chain_strength > 0) and
                            ((next_phrase_strength * 100) < (next_single_chain_strength * 85)) then
                        begin
                            Dec(Result, c_three_syllable_weak_tail_phrase_penalty +
                                Min(180, (next_single_chain_strength - next_phrase_strength) div 2));
                        end
                        else
                        begin
                            Inc(Result, c_three_syllable_tail_phrase_bonus +
                                Min(164, next_phrase_strength div 4));
                        end;
                    end;
                end
                else if current_phrase_strength > 0 then
                begin
                    if remaining_syllables = 1 then
                    begin
                        Inc(Result, Min(c_boundary_strength_bonus_cap,
                            current_phrase_strength div c_boundary_prefix_scale));
                        if (Length(syllables) = 3) and (overlapping_phrase_strength > 0) then
                        begin
                            if (current_phrase_strength * 100) <=
                                (overlapping_phrase_strength * 230) then
                            begin
                                Dec(Result, c_three_syllable_tail_phrase_penalty +
                                    Min(156, overlapping_phrase_strength div 6));
                            end
                            else if (current_phrase_strength * 100) <=
                                (overlapping_phrase_strength * 280) then
                            begin
                                Dec(Result, c_three_syllable_tail_phrase_soft_penalty +
                                    Min(92, overlapping_phrase_strength div 10));
                            end;
                        end;
                        if (suffix_tail_bias > 0) and (suffix_tail_support_strength > 0) and
                            (suffix_tail_matched_text <> '') then
                        begin
                            Inc(Result, Min(c_suffix_tail_phrase_bonus_cap,
                                (suffix_tail_bias * 2) div 3));
                        end;
                    end
                    else if next_phrase_strength > current_phrase_strength + 120 then
                    begin
                        Dec(Result, c_boundary_gap_penalty);
                    end;
                end;
            end
            else if (remaining_syllables = 0) and (previous_text_units = 1) and
                (current_phrase_strength > 0) then
            begin
                Inc(Result, Min(64, current_phrase_strength div 10));
            end;
        end;

        function try_get_best_anchor_state(const position: Integer;
            const minimum_text_units: Integer; out out_state: TncSegmentPathState): Boolean;
        var
            local_sorted_states: TArray<TncSegmentPathState>;
            local_idx: Integer;
            local_units: Integer;
        begin
            Result := False;
            out_state.text := '';
            out_state.score := 0;
            out_state.path_preference_score := 0;
            out_state.path_confidence_score := 0;
            out_state.source := cs_rule;
            out_state.has_multi_segment := False;
            out_state.prev_prev_text := '';
            out_state.prev_text := '';
            out_state.prev_pinyin_text := '';
            out_state.path_text := '';
            if (position < 0) or (position > High(states)) or (states[position].Count <= 0) then
            begin
                Exit;
            end;

            SetLength(local_sorted_states, states[position].Count);
            for local_idx := 0 to states[position].Count - 1 do
            begin
                local_sorted_states[local_idx] := states[position][local_idx];
            end;
            sort_state_array(local_sorted_states);

            for local_idx := 0 to High(local_sorted_states) do
            begin
                if Trim(local_sorted_states[local_idx].text) = '' then
                begin
                    Continue;
                end;
                local_units := get_candidate_text_unit_count(local_sorted_states[local_idx].text);
                if local_units < minimum_text_units then
                begin
                    Continue;
                end;
                if (minimum_text_units = 1) and
                    (not is_single_text_unit(Trim(local_sorted_states[local_idx].text))) then
                begin
                    Continue;
                end;
                out_state := local_sorted_states[local_idx];
                Result := True;
                Break;
            end;
        end;

        procedure append_three_syllable_anchor_partial_candidates;
        const
            c_three_syllable_boundary_ratio_pct = 100;
            c_anchor_partial_bonus = 420;
            c_anchor_partial_tail_bonus_scale = 4;
            c_anchor_partial_remaining_penalty = 36;
            c_anchor_partial_non_preferred_penalty = 220;
            c_anchor_partial_non_preferred_gap = 48;
            c_anchor_partial_score_hint_flag = 1000000;
            c_anchor_partial_hint_kind_scale = 10000;
            c_anchor_partial_hint_one_plus_two = 1;
            c_anchor_partial_hint_two_plus_one = 2;
            c_segmented_prefix_strength_penalty = 520;
            c_first_single_tail_bias_cap = 520;
            c_last_single_head_bias_cap = 620;
        var
            head_two_strength: Integer;
            head_two_effective_strength: Integer;
            head_two_supported_strength: Integer;
            tail_two_strength: Integer;
            tail_two_supported_strength: Integer;
            first_single_strength: Integer;
            last_single_text: string;
            last_single_strength: Integer;
            detected_last_single_strength: Integer;
            suffix_tail_matched_text: string;
            suffix_tail_support_strength: Integer;
            suffix_tail_bias: Integer;
            boundary_ratio_pct: Integer;
            head_retention_bonus: Integer;
            remaining_pinyin: string;
            anchor_state: TncSegmentPathState;
            prefix_two_state: TncSegmentPathState;
            anchor_score: Integer;
            local_units: Integer;
            is_preferred: Boolean;
            anchor_hint: Integer;
            derived_head_strength: Integer;
            preferred_one_plus_two_score: Integer;

            procedure append_non_preferred_head_two_anchor_candidate(
                const preferred_score_value: Integer;
                const tail_support_strength_value: Integer);
            var
                fallback_state: TncSegmentPathState;
                fallback_score: Integer;
                fallback_hint: Integer;
                fallback_remaining_pinyin: string;
                fallback_units: Integer;
                fallback_gap_penalty: Integer;
            begin
                fallback_remaining_pinyin := build_syllable_text(2, Length(syllables) - 2);
                if fallback_remaining_pinyin = '' then
                begin
                    Exit;
                end;

                if not try_get_best_anchor_state(2, 2, fallback_state) then
                begin
                    Exit;
                end;

                fallback_units := get_candidate_text_unit_count(fallback_state.text);
                if fallback_units < 2 then
                begin
                    Exit;
                end;

                fallback_gap_penalty := 0;
                if tail_support_strength_value > head_two_supported_strength then
                begin
                    fallback_gap_penalty := Min(220,
                        (tail_support_strength_value - head_two_supported_strength) div 3);
                end;

                fallback_score := fallback_state.score + c_anchor_partial_bonus +
                    Min(220, head_two_supported_strength div
                    c_anchor_partial_tail_bonus_scale) -
                    c_anchor_partial_remaining_penalty -
                    c_anchor_partial_non_preferred_penalty -
                    fallback_gap_penalty;
                if (preferred_score_value > 0) and
                    (fallback_score >= preferred_score_value) then
                begin
                    fallback_score := preferred_score_value -
                        c_anchor_partial_non_preferred_gap;
                end;

                if fallback_score <= 0 then
                begin
                    Exit;
                end;

                append_candidate(fallback_state.text, fallback_score,
                    fallback_state.source, fallback_remaining_pinyin);
                fallback_hint := c_anchor_partial_score_hint_flag +
                    (c_anchor_partial_hint_two_plus_one *
                    c_anchor_partial_hint_kind_scale) + fallback_score;
                remember_segment_path_for_candidate(fallback_state.text,
                    fallback_remaining_pinyin, fallback_state.path_text, fallback_hint);
            end;
        begin
            if (not c_suppress_nonlexicon_complete_long_candidates) or
                (Length(syllables) < 3) then
            begin
                Exit;
            end;

            head_two_strength := 0;
            if Length(preferred_two_syllable_phrase_strength) > 0 then
            begin
                head_two_strength := preferred_two_syllable_phrase_strength[0];
            end;
            tail_two_strength := 0;
            if Length(preferred_two_syllable_phrase_strength) > 1 then
            begin
                tail_two_strength := preferred_two_syllable_phrase_strength[1];
            end;
            first_single_strength := 0;
            if Length(preferred_single_strength) > 0 then
            begin
                first_single_strength := preferred_single_strength[0];
            end;
            last_single_text := '';
            last_single_strength := 0;
            detected_last_single_strength := 0;
            if Length(preferred_single_strength) > 2 then
            begin
                last_single_strength := preferred_single_strength[2];
            end;
            try_get_best_single_char_candidate_for_syllable_local(2, last_single_text,
                detected_last_single_strength);
            if last_single_strength <= 0 then
            begin
                last_single_strength := detected_last_single_strength;
            end;
            suffix_tail_matched_text := '';
            suffix_tail_support_strength := 0;
            suffix_tail_bias := get_suffix_tail_bias_adjustment_for_syllable_local(
                2, last_single_text, last_single_strength, suffix_tail_matched_text,
                suffix_tail_support_strength);
            boundary_ratio_pct := c_three_syllable_boundary_ratio_pct;
            head_retention_bonus := 0;
            if (suffix_tail_bias > 0) and (suffix_tail_support_strength > 0) and
                (suffix_tail_matched_text <> '') and (head_two_strength > 0) then
            begin
                boundary_ratio_pct :=
                    get_suffix_tail_head_preference_ratio_pct_local(syllables[2].text);
                head_retention_bonus :=
                    get_suffix_tail_head_retention_bonus_local(syllables[2].text);
            end;

            head_two_effective_strength := head_two_strength;
            if try_get_best_anchor_state(2, 2, prefix_two_state) then
            begin
                derived_head_strength := prefix_two_state.score;
                if prefix_two_state.has_multi_segment then
                begin
                    Dec(derived_head_strength, c_segmented_prefix_strength_penalty);
                end;
                if derived_head_strength > head_two_effective_strength then
                begin
                    head_two_effective_strength := derived_head_strength;
                end;
            end;

            head_two_supported_strength := head_two_effective_strength;
            if (head_two_effective_strength > 0) and (last_single_strength > 0) then
            begin
                Inc(head_two_supported_strength, Min(c_last_single_head_bias_cap,
                    last_single_strength + Min(160, last_single_strength div 2)));
            end;
            if (head_two_effective_strength > 0) and (suffix_tail_bias > 0) and
                (suffix_tail_support_strength > 0) and (suffix_tail_matched_text <> '') then
            begin
                Inc(head_two_supported_strength, suffix_tail_bias);
                if head_retention_bonus > 0 then
                begin
                    Inc(head_two_supported_strength, head_retention_bonus);
                end;
            end;

            tail_two_supported_strength := tail_two_strength;
            if (tail_two_strength > 0) and (first_single_strength > 0) then
            begin
                Inc(tail_two_supported_strength, Min(c_first_single_tail_bias_cap, first_single_strength));
            end;

            if (head_two_supported_strength <= 0) and (tail_two_supported_strength <= 0) then
            begin
                Exit;
            end;

            preferred_one_plus_two_score := 0;
            if (tail_two_supported_strength > 0) and
                ((head_two_supported_strength <= 0) or
                ((tail_two_supported_strength * 100) >=
                (head_two_supported_strength * boundary_ratio_pct))) then
            begin
                remaining_pinyin := build_syllable_text(1, Length(syllables) - 1);
                if (remaining_pinyin <> '') and
                    try_get_best_anchor_state(1, 1, anchor_state) then
                begin
                    if match_single_char_candidate_for_syllable(
                        syllables[0].text, anchor_state.text, is_preferred) and is_preferred then
                    begin
                        anchor_score := anchor_state.score + c_anchor_partial_bonus +
                            Min(220, tail_two_supported_strength div c_anchor_partial_tail_bonus_scale) -
                            (2 * c_anchor_partial_remaining_penalty);
                        preferred_one_plus_two_score := anchor_score;
                        append_candidate(anchor_state.text, anchor_score, anchor_state.source, remaining_pinyin);
                        anchor_hint := c_anchor_partial_score_hint_flag +
                            (c_anchor_partial_hint_one_plus_two * c_anchor_partial_hint_kind_scale) +
                            anchor_score;
                        remember_segment_path_for_candidate(anchor_state.text, remaining_pinyin,
                            anchor_state.path_text, anchor_hint);
                    end;
                end;

                append_non_preferred_head_two_anchor_candidate(
                    preferred_one_plus_two_score, tail_two_supported_strength);
            end;

            if (head_two_supported_strength > 0) and
                ((tail_two_supported_strength <= 0) or
                ((tail_two_supported_strength * 100) <
                (head_two_supported_strength * boundary_ratio_pct))) then
            begin
                remaining_pinyin := build_syllable_text(2, Length(syllables) - 2);
                if (remaining_pinyin <> '') and
                    try_get_best_anchor_state(2, 2, anchor_state) then
                begin
                    local_units := get_candidate_text_unit_count(anchor_state.text);
                    if local_units >= 2 then
                    begin
                        anchor_score := anchor_state.score + c_anchor_partial_bonus +
                            Min(220, head_two_supported_strength div c_anchor_partial_tail_bonus_scale) -
                            c_anchor_partial_remaining_penalty;
                        append_candidate(anchor_state.text, anchor_score, anchor_state.source,
                            remaining_pinyin);
                        anchor_hint := c_anchor_partial_score_hint_flag +
                            (c_anchor_partial_hint_two_plus_one * c_anchor_partial_hint_kind_scale) +
                            anchor_score;
                        remember_segment_path_for_candidate(anchor_state.text, remaining_pinyin,
                            anchor_state.path_text, anchor_hint);
                    end;
                end;
            end;
        end;

        function get_segment_alignment_adjustment(const start_pos: Integer; const syllable_count: Integer;
            const candidate_text_value: string): Integer;
        var
            unit_idx: Integer;
            local_adjustment: Integer;
            local_applied_count: Integer;
            unit_text: string;
        begin
            Result := 0;
            if (start_pos < 0) or (syllable_count <= 0) then
            begin
                Exit;
            end;

            segment_units := split_text_units(candidate_text_value);
            if Length(segment_units) <> syllable_count then
            begin
                Exit;
            end;

            local_adjustment := 0;
            local_applied_count := 0;
            for unit_idx := 0 to syllable_count - 1 do
            begin
                if (start_pos + unit_idx < 0) or (start_pos + unit_idx >= Length(single_char_rank_maps)) then
                begin
                    Continue;
                end;

                local_rank_map := single_char_rank_maps[start_pos + unit_idx];
                if (local_rank_map = nil) or (local_rank_map.Count = 0) then
                begin
                    Continue;
                end;

                Inc(local_applied_count);
                unit_text := segment_units[unit_idx];
                if local_rank_map.TryGetValue(unit_text, local_rank) then
                begin
                    Inc(local_adjustment, (c_segment_alignment_rank_window - local_rank) *
                        c_segment_alignment_rank_step);
                end
                else
                begin
                    Dec(local_adjustment, c_segment_alignment_missing_penalty);
                end;
            end;

            if local_applied_count <= 0 then
            begin
                Exit;
            end;

            Result := local_adjustment div local_applied_count;
            if Result > c_segment_alignment_adjust_cap then
            begin
                Result := c_segment_alignment_adjust_cap;
            end
            else if Result < -c_segment_alignment_adjust_cap then
            begin
                Result := -c_segment_alignment_adjust_cap;
            end;
        end;
        begin
            if Length(syllables) <= 1 then
            begin
                Exit;
            end;

        long_sentence_full_path_mode := Length(syllables) >= c_long_sentence_full_path_min_syllables;
        full_path_budget_ms_limit := c_segment_full_path_budget_ms;
        full_state_limit_limit := c_segment_full_state_limit;
        if long_sentence_full_path_mode then
        begin
            full_head_top_n := 4;
            full_path_non_user_limit := c_segment_full_path_non_user_limit_long;
            full_path_budget_ms_limit := c_segment_full_path_budget_ms_long;
            full_state_limit_limit := c_segment_full_state_limit_long;
        end
        else if Length(syllables) >= 6 then
        begin
            full_head_top_n := 2;
            full_path_non_user_limit := 3;
        end
        else if Length(syllables) >= 4 then
        begin
            full_head_top_n := 3;
            full_path_non_user_limit := 4;
        end
        else
        begin
            full_head_top_n := 4;
            full_path_non_user_limit := c_segment_full_path_non_user_limit;
        end;

        SetLength(states, Length(syllables) + 1);
        SetLength(state_dedup, Length(syllables) + 1);
        transition_bonus_cache := TDictionary<string, Integer>.Create;
        for state_pos := 0 to High(states) do
        begin
            states[state_pos] := TList<TncSegmentPathState>.Create;
            state_dedup[state_pos] := TDictionary<string, Integer>.Create;
        end;

        try
            local_state.text := '';
            local_state.score := 0;
            local_state.path_preference_score := 0;
            local_state.path_confidence_score := 0;
            local_state.source := cs_rule;
            local_state.has_multi_segment := False;
            get_recent_path_context_seed(local_state.prev_prev_text, local_state.prev_text);
            local_state.prev_pinyin_text := '';
            local_state.path_text := '';
            states[0].Add(local_state);
            state_dedup[0].Add(build_state_key(local_state), 0);
            SetLength(preferred_phrase_flags, Length(syllables));
            SetLength(preferred_phrase_max_len, Length(syllables));
            SetLength(preferred_phrase_strength, Length(syllables));
            SetLength(preferred_two_syllable_phrase_strength, Length(syllables));
            SetLength(preferred_single_strength, Length(syllables));
            SetLength(single_char_rank_maps, Length(syllables));
            full_path_budget_start_tick := GetTickCount64;
            full_path_budget_work_counter := 0;
            full_path_budget_exhausted := False;
            final_complete_state_count := 0;
            final_complete_multiseg_state_count := 0;
            final_complete_debug_paths := '';
            final_position_debug_counts := '';
            if Length(syllables) >= c_long_sentence_head_only_bypass_min_syllables then
            begin
                m_last_full_path_debug_info := ' longsent_skip_legacy=1';
                Exit;
            end;
            for state_pos := 0 to High(syllables) do
            begin
                if full_path_budget_reached(True) then
                begin
                    Break;
                end;

                single_char_rank_maps[state_pos] := TDictionary<string, Integer>.Create;
                if dictionary_lookup_cached(syllables[state_pos].text, local_lookup_results) then
                begin
                    local_rank := 0;
                    for candidate_index := 0 to High(local_lookup_results) do
                    begin
                        if full_path_budget_reached(False) then
                        begin
                            Break;
                        end;

                        local_candidate_text := Trim(local_lookup_results[candidate_index].text);
                        if (local_candidate_text = '') or
                            (not is_single_text_unit(local_candidate_text)) or
                            (not contains_non_ascii(local_candidate_text)) then
                        begin
                            Continue;
                        end;

                        if not single_char_rank_maps[state_pos].ContainsKey(local_candidate_text) then
                        begin
                            single_char_rank_maps[state_pos].Add(local_candidate_text, local_rank);
                            Inc(local_rank);
                            if local_rank >= c_segment_alignment_rank_window then
                            begin
                                Break;
                            end;
                        end;
                    end;
                end;
                preferred_phrase_flags[state_pos] := detect_preferred_phrase_at_position(state_pos);
                preferred_single_strength[state_pos] := detect_preferred_single_strength_at_position(state_pos);
            end;

            for state_pos := 0 to High(syllables) do
            begin
                if full_path_budget_reached(True) then
                begin
                    Break;
                end;

                if states[state_pos].Count = 0 then
                begin
                    Continue;
                end;

                for local_segment_len := 1 to max_word_len do
                begin
                    if full_path_budget_exhausted then
                    begin
                        Break;
                    end;

                    if state_pos + local_segment_len > Length(syllables) then
                    begin
                        Break;
                    end;

                    local_segment_text := build_syllable_text(state_pos, local_segment_len);
                    if local_segment_text = '' then
                    begin
                        Continue;
                    end;

                    if not dictionary_lookup_cached(local_segment_text, local_lookup_results) then
                    begin
                        Continue;
                    end;

                    if (per_limit > 0) and (Length(local_lookup_results) > per_limit) then
                    begin
                        SetLength(local_lookup_results, per_limit);
                    end;

                    next_pos := state_pos + local_segment_len;
                    for state_index := 0 to states[state_pos].Count - 1 do
                    begin
                        if full_path_budget_reached(False) then
                        begin
                            Break;
                        end;

                        local_state := states[state_pos][state_index];
                        for candidate_index := 0 to High(local_lookup_results) do
                        begin
                            if full_path_budget_reached(False) then
                            begin
                                Break;
                            end;

                            // Keep full-path expansion anchored by high-confidence head chunks.
                            // Low-ranked leading chunks (for example rare/unnatural head words)
                            // should not keep expanding into long noisy phrases.
                            if (state_pos = 0) and (local_segment_len > 1) and
                                (next_pos < Length(syllables)) and
                                (candidate_index >= full_head_top_n) then
                            begin
                                Continue;
                            end;

                            local_candidate := local_lookup_results[candidate_index];
                            local_candidate_text := Trim(local_candidate.text);
                            candidate_has_non_ascii := contains_non_ascii(local_candidate_text);
                            candidate_text_units := get_text_unit_count(local_candidate_text);
                            if candidate_text_units <= 0 then
                            begin
                                Continue;
                            end;
                            if not candidate_has_non_ascii then
                            begin
                                Continue;
                            end;
                            // For one-syllable segment expansion, multi-char words are typically noisy bridges
                            // (e.g. "xian" -> "鐟楀灝鐣?) and hurt full-path quality.
                            if candidate_has_non_ascii and (local_segment_len = 1) and
                                (candidate_text_units > 1) then
                            begin
                                Continue;
                            end;
                            allow_leading_single_char := False;
                            allow_single_char_path := False;
                            local_path_transition_bonus := 0;
                            if not is_multi_char_word(local_candidate.text) then
                            begin
                                // Allow only the top leading single-char candidate so cases like
                                // "wo + faxian" can become "閹存垵褰傞悳?, while still blocking noisy
                                // single-char full-path combinations in general.
                                if candidate_has_non_ascii and (local_segment_len = 1) and
                                    ((candidate_index < c_segment_full_single_top_n) or
                                    ((local_state.prev_text <> '') and
                                    (get_path_transition_bonus(
                                        local_state.prev_prev_text,
                                        local_state.prev_text,
                                        local_candidate_text) > 0))) then
                                begin
                                    if (candidate_index >= c_segment_full_single_top_n) and
                                        (local_state.prev_text <> '') then
                                    begin
                                        local_path_transition_bonus := get_path_transition_bonus(
                                            local_state.prev_prev_text,
                                            local_state.prev_text,
                                            local_candidate_text);
                                    end;
                                    allow_single_char_path := True;
                                    allow_leading_single_char := state_pos = 0;
                                    if (not allow_leading_single_char) and (Length(local_candidate.text) = 2) and
                                        (Ord(local_candidate.text[1]) >= $D800) and (Ord(local_candidate.text[1]) <= $DBFF) and
                                        (Ord(local_candidate.text[2]) >= $DC00) and (Ord(local_candidate.text[2]) <= $DFFF) then
                                    begin
                                        Continue;
                                    end;
                                end
                                else
                                begin
                                    Continue;
                                end;
                            end;

                            local_new_state.text := local_state.text + local_candidate.text;
                            local_new_state.score := local_state.score + local_candidate.score +
                                (local_segment_len * c_segment_prefix_bonus);
                            if local_path_transition_bonus = 0 then
                            begin
                                local_path_transition_bonus := get_path_transition_bonus(
                                    local_state.prev_prev_text,
                                    local_state.prev_text,
                                    local_candidate_text);
                            end;
                            Inc(local_new_state.score, local_path_transition_bonus);
                            local_segment_quality_bonus := get_segment_lexical_quality_bonus(
                                local_candidate, local_segment_len, state_pos, next_pos);
                            Inc(local_new_state.score, local_segment_quality_bonus);
                            local_chain_shape_bonus := get_segment_chain_shape_bonus(
                                local_state, candidate_text_units, local_segment_len, state_pos, next_pos);
                            if local_chain_shape_bonus <> 0 then
                            begin
                                Inc(local_new_state.score, local_chain_shape_bonus);
                            end;
                            Inc(local_new_state.score, get_segment_boundary_cohesion_bonus(
                                local_state, local_candidate, candidate_text_units,
                                local_segment_len, state_pos, next_pos));
                            if (state_pos = 0) and (local_segment_len > 1) and
                                (next_pos < Length(syllables)) then
                            begin
                                Dec(local_new_state.score, c_segment_full_leading_multi_penalty);
                            end;
                            if allow_single_char_path then
                            begin
                                if allow_leading_single_char and (next_pos < Length(syllables)) and
                                    (state_pos >= 0) and (state_pos < Length(preferred_phrase_max_len)) and
                                    (preferred_phrase_max_len[state_pos] >= 3) then
                                begin
                                    Continue;
                                end;
                                if (next_pos < Length(syllables)) and (state_pos >= 0) and
                                    (state_pos < Length(preferred_phrase_flags)) and
                                    preferred_phrase_flags[state_pos] then
                                begin
                                    if not allow_leading_single_char then
                                    begin
                                        Continue;
                                    end;
                                    Dec(local_new_state.score, c_segment_full_preferred_single_penalty);
                                end;
                                if allow_leading_single_char then
                                begin
                                    if Length(syllables) >= 3 then
                                    begin
                                        Inc(local_new_state.score, c_segment_full_leading_single_bonus);
                                    end
                                    else
                                    begin
                                        Dec(local_new_state.score, c_segment_full_preferred_single_penalty);
                                    end;
                                end
                                else
                                begin
                                    Dec(local_new_state.score, c_segment_full_non_leading_single_penalty);
                                end;
                            end;
                            if (next_pos = Length(syllables)) then
                            begin
                                Inc(local_new_state.score, c_segment_full_completion_bonus);
                            end
                            else
                            begin
                                Dec(local_new_state.score, c_segment_full_transition_penalty);
                            end;

                            if candidate_has_non_ascii and (candidate_text_units <> local_segment_len) then
                            begin
                                text_unit_mismatch := Abs(candidate_text_units - local_segment_len);
                                Dec(local_new_state.score, text_unit_mismatch * c_segment_text_unit_mismatch_penalty);
                                if candidate_text_units > local_segment_len then
                                begin
                                    Dec(local_new_state.score,
                                        (candidate_text_units - local_segment_len) * c_segment_text_unit_overflow_penalty);
                                end;
                            end;
                            if (Length(syllables) >= 4) and (state_pos = 1) and
                                (next_pos = Length(syllables)) and
                                (local_segment_len >= Length(syllables) - 1) and
                                (get_text_unit_count(local_state.text) = 1) then
                            begin
                                Dec(local_new_state.score, 140);
                            end;
                            if candidate_has_non_ascii and (candidate_text_units = local_segment_len) and
                                (local_segment_len >= 2) then
                            begin
                                Inc(local_new_state.score,
                                    get_segment_alignment_adjustment(state_pos, local_segment_len, local_candidate_text));
                            end;

                            if is_first_overall_segment and (state_pos = 0) and (local_segment_len = 1) and
                                (next_pos < Length(syllables)) and (Length(local_candidate.text) = 1) and
                                is_common_surname_text(local_candidate.text) then
                            begin
                                Inc(local_new_state.score, c_segment_surname_bonus);
                            end;

                            local_new_state.source := merge_source_rank(local_state.source, local_candidate.source);
                            local_new_state.prev_prev_text := local_state.prev_text;
                            local_new_state.prev_text := local_candidate_text;
                            local_new_state.prev_pinyin_text := local_segment_text;
                            local_new_state.path_text := local_state.path_text;
                            if local_candidate_text <> '' then
                            begin
                                if local_new_state.path_text <> '' then
                                begin
                                    local_new_state.path_text := local_new_state.path_text + c_segment_path_separator;
                                end;
                                local_new_state.path_text := local_new_state.path_text + local_candidate_text;
                            end;
                            local_new_state.has_multi_segment :=
                                get_encoded_path_segment_count_local(local_new_state.path_text) > 1;
                            local_new_state.path_preference_score := 0;
                            local_new_state.path_confidence_score := 0;
                            if get_encoded_path_segment_count_local(local_new_state.path_text) > 1 then
                            begin
                                local_segment_count := get_encoded_path_segment_count_local(local_new_state.path_text);
                                local_path_preference_score := -(local_segment_count * 18);
                                if local_segment_quality_bonus <> 0 then
                                begin
                                    Inc(local_path_preference_score, local_segment_quality_bonus div 2);
                                end;
                                if local_chain_shape_bonus <> 0 then
                                begin
                                    Inc(local_path_preference_score, local_chain_shape_bonus div 2);
                                end;
                                if local_path_transition_bonus > 0 then
                                begin
                                    Inc(local_path_preference_score, Min(220, local_path_transition_bonus div 2));
                                end;
                                local_incremental_path_bonus := get_incremental_path_stability_bonus_for_path(
                                    local_new_state.path_text);
                                if local_incremental_path_bonus > 0 then
                                begin
                                    Inc(local_path_preference_score, local_incremental_path_bonus);
                                end;
                                remember_segment_path_query_prefix(
                                    local_new_state.path_text,
                                    build_syllable_text(0, next_pos));
                                if m_last_lookup_key <> '' then
                                begin
                                    local_query_path_bonus := get_session_query_path_prefix_bonus(
                                        m_last_lookup_key, local_new_state.path_text);
                                    if local_query_path_bonus > 0 then
                                    begin
                                        Inc(local_new_state.score, local_query_path_bonus);
                                        Inc(local_path_preference_score, local_query_path_bonus);
                                    end;
                                    local_recent_ranked_bonus := get_session_ranked_query_path_bonus(
                                        local_new_state.path_text);
                                    if local_recent_ranked_bonus > 0 then
                                    begin
                                        Inc(local_new_state.score, local_recent_ranked_bonus);
                                        Inc(local_path_preference_score, local_recent_ranked_bonus);
                                    end;
                                    local_path_penalty_value := get_session_query_path_prefix_penalty(
                                        m_last_lookup_key, local_new_state.path_text);
                                    if local_path_penalty_value > 0 then
                                    begin
                                        Dec(local_new_state.score, local_path_penalty_value);
                                        Dec(local_path_preference_score, local_path_penalty_value);
                                    end;
                                    local_query_path_bonus := get_persistent_query_path_prefix_support(
                                        local_new_state.path_text);
                                    if local_query_path_bonus <> 0 then
                                    begin
                                        Inc(local_new_state.score, local_query_path_bonus);
                                        Inc(local_path_preference_score, local_query_path_bonus);
                                    end;

                                    if next_pos = Length(syllables) then
                                    begin
                                        local_query_path_bonus := get_session_query_path_bonus(
                                            m_last_lookup_key, local_new_state.path_text);
                                        if local_query_path_bonus > 0 then
                                        begin
                                            Inc(local_new_state.score, local_query_path_bonus div 2);
                                            Inc(local_path_preference_score, local_query_path_bonus);
                                        end;
                                        local_path_penalty_value := get_session_query_path_penalty(
                                            m_last_lookup_key, local_new_state.path_text);
                                        if local_path_penalty_value > 0 then
                                        begin
                                            Dec(local_new_state.score, local_path_penalty_value);
                                            Dec(local_path_preference_score, local_path_penalty_value);
                                        end;
                                        if m_dictionary <> nil then
                                        begin
                                            local_query_path_bonus := m_dictionary.get_query_segment_path_bonus(
                                                m_last_lookup_key, local_new_state.path_text);
                                            if local_query_path_bonus > 0 then
                                            begin
                                                Inc(local_new_state.score, local_query_path_bonus div 2);
                                                Inc(local_path_preference_score, local_query_path_bonus);
                                            end;
                                            local_path_penalty_value := m_dictionary.get_query_segment_path_penalty(
                                                m_last_lookup_key, local_new_state.path_text);
                                            if local_path_penalty_value > 0 then
                                            begin
                                                Dec(local_new_state.score, local_path_penalty_value);
                                                Dec(local_path_preference_score, local_path_penalty_value);
                                            end;
                                        end;
                                    end;
                                end;
                                local_new_state.path_preference_score := local_path_preference_score;
                                local_path_confidence_score := local_path_preference_score;
                                if local_path_confidence_score < 0 then
                                begin
                                    local_path_confidence_score := 0;
                                end;
                                local_new_state.path_confidence_score := local_path_confidence_score;
                            end;
                            append_state(next_pos, local_new_state);
                        end;

                        if full_path_budget_exhausted then
                        begin
                            Break;
                        end;
                    end;

                    if full_path_budget_exhausted then
                    begin
                        Break;
                    end;

                    trim_state(next_pos);
                end;
                if long_sentence_full_path_mode then
                begin
                    append_position_debug_count(state_pos, states[state_pos].Count);
                end;
            end;

            if states[Length(syllables)].Count > 0 then
            begin
                final_complete_state_count := states[Length(syllables)].Count;
                SetLength(sorted_states, states[Length(syllables)].Count);
                for final_index := 0 to states[Length(syllables)].Count - 1 do
                begin
                    sorted_states[final_index] := states[Length(syllables)][final_index];
                end;
                sort_state_array(sorted_states);

                for final_index := 0 to High(sorted_states) do
                begin
                    if get_encoded_path_segment_count_local(sorted_states[final_index].path_text) > 1 then
                    begin
                        Inc(final_complete_multiseg_state_count);
                        if final_complete_multiseg_state_count <= 5 then
                        begin
                            record_final_debug_path(sorted_states[final_index].path_text);
                        end;
                    end;
                end;

                full_non_user_added := 0;
                for final_index := 0 to High(sorted_states) do
                begin
                    local_state := sorted_states[final_index];
                    if (not local_state.has_multi_segment) and
                        (not ((Pos('''', m_composition_text) > 0) and
                        (get_encoded_path_segment_count_local(local_state.path_text) > 1))) then
                    begin
                        Continue;
                    end;
                    if (local_state.source <> cs_user) and (full_non_user_added >= full_path_non_user_limit) then
                    begin
                        Continue;
                    end;
                    append_candidate(local_state.text, local_state.score, local_state.source, '');
                    remember_segment_path_for_candidate(local_state.text, '', local_state.path_text,
                        local_state.score);
                    if local_state.source <> cs_user then
                    begin
                        Inc(full_non_user_added);
                    end;
                end;
            end;

            // Surface high-quality multi-segment prefix paths as partial candidates,
            // e.g. "womenjintianquz" => "我们今天去|z". This keeps multi-word
            // prefixes visible before the tail is fully typed, even when the
            // consumed prefix itself is not a monolithic dictionary phrase.
            for state_pos := Length(syllables) - 1 downto 2 do
            begin
                remaining_syllables := Length(syllables) - state_pos;
                if (remaining_syllables <= 0) or
                    (remaining_syllables > c_segment_full_partial_remaining_limit) or
                    (states[state_pos].Count = 0) then
                begin
                    Continue;
                end;

                remaining_pinyin := build_syllable_text(state_pos, remaining_syllables);
                if remaining_pinyin = '' then
                begin
                    Continue;
                end;

                SetLength(sorted_states, states[state_pos].Count);
                for final_index := 0 to states[state_pos].Count - 1 do
                begin
                    sorted_states[final_index] := states[state_pos][final_index];
                end;
                sort_state_array(sorted_states);

                full_non_user_added := 0;
                for final_index := 0 to High(sorted_states) do
                begin
                    local_state := sorted_states[final_index];
                    if not local_state.has_multi_segment then
                    begin
                        Continue;
                    end;
                    if get_encoded_path_segment_count_local(local_state.path_text) <= 1 then
                    begin
                        Continue;
                    end;
                    if get_candidate_text_unit_count(local_state.text) < 2 then
                    begin
                        Continue;
                    end;
                    if (local_state.source <> cs_user) and
                        (full_non_user_added >= c_segment_full_partial_non_user_limit) then
                    begin
                        Continue;
                    end;

                    score_value := local_state.score;
                    Dec(score_value, c_segment_full_partial_penalty * remaining_syllables);
                    Dec(score_value, c_segment_full_partial_quadratic_penalty *
                        remaining_syllables * (remaining_syllables - 1));
                    append_candidate(local_state.text, score_value, local_state.source, remaining_pinyin);
                    remember_segment_path_for_candidate(local_state.text, remaining_pinyin,
                        local_state.path_text, score_value);

                    if local_state.source <> cs_user then
                    begin
                        Inc(full_non_user_added);
                    end;
                end;
            end;

            append_three_syllable_anchor_partial_candidates;
        finally
            if final_complete_state_count > 0 then
            begin
                m_last_full_path_debug_info := Format(
                    ' fullpath_end=[states=%d multiseg=%d pos=%s sample=%s]',
                    [final_complete_state_count, final_complete_multiseg_state_count,
                    Copy(final_position_debug_counts, 1, 180),
                    Copy(Trim(final_complete_debug_paths), 1, 180)]);
            end
            else
            begin
                m_last_full_path_debug_info := Format(' fullpath_end=[states=0 multiseg=0 pos=%s]',
                    [Copy(final_position_debug_counts, 1, 180)]);
            end;
            for state_pos := 0 to High(states) do
            begin
                if states[state_pos] <> nil then
                begin
                    states[state_pos].Free;
                    states[state_pos] := nil;
                end;
                if state_dedup[state_pos] <> nil then
                begin
                    state_dedup[state_pos].Free;
                    state_dedup[state_pos] := nil;
                end;
                if (state_pos <= High(single_char_rank_maps)) and (single_char_rank_maps[state_pos] <> nil) then
                begin
                    single_char_rank_maps[state_pos].Free;
                    single_char_rank_maps[state_pos] := nil;
                end;
            end;
            if transition_bonus_cache <> nil then
            begin
                transition_bonus_cache.Free;
            end;
        end;
    end;
begin
    SetLength(out_candidates, 0);
    out_path_search_elapsed_ms := 0;
    Result := False;
    if (m_dictionary = nil) or (m_composition_text = '') then
    begin
        Exit;
    end;

    lookup_cache := TDictionary<string, TncCandidateList>.Create;
    try
        syllables := get_effective_compact_pinyin_syllables(m_composition_text,
            allow_relaxed_missing_apostrophe);
        if Length(syllables) <= 1 then
        begin
            Exit;
        end;

        if Length(syllables) > c_segment_max_syllables then
        begin
            Exit;
        end;

        is_first_overall_segment := (m_confirmed_segments = nil) or (m_confirmed_segments.Count = 0);

        max_word_len := c_segment_word_max_syllables;
        if (not include_full_path) and
            (Length(syllables) >= c_long_sentence_head_only_bypass_min_syllables) then
        begin
            max_word_len := Min(max_word_len, 2);
        end;
        if max_word_len > Length(syllables) then
        begin
            max_word_len := Length(syllables);
        end;

        total_limit := get_total_candidate_limit;
        if total_limit <= 0 then
        begin
            Exit;
        end;

        per_limit := total_limit;
        if get_candidate_limit > 0 then
        begin
            if get_candidate_limit * c_segment_page_expand_factor > per_limit then
            begin
                per_limit := get_candidate_limit * c_segment_page_expand_factor;
            end;
        end;
        if per_limit > c_segment_max_per_segment then
        begin
            per_limit := c_segment_max_per_segment;
        end;

        list := TList<TncCandidate>.Create;
        dedup := TDictionary<string, Integer>.Create;
        try
            if include_full_path then
            begin
                // First, build full-path phrase candidates (for example women+jintian -> full phrase).
                path_search_start_tick := GetTickCount64;
                append_full_path_candidates;
                Inc(out_path_search_elapsed_ms, Int64(GetTickCount64 - path_search_start_tick));
            end;

            // Keep prefix segment candidates as fallback/partial-commit choices.
            for segment_len := 1 to max_word_len do
            begin
                // In head-only mode, keep chunk conversion behavior for long input:
                // only expose prefix chunks and leave remaining pinyin for next commit.
                if (not include_full_path) and (Length(syllables) >= 3) and
                    (segment_len >= Length(syllables)) then
                begin
                    Break;
                end;

                segment_text := build_syllable_text(0, segment_len);
                if segment_text = '' then
                begin
                    Continue;
                end;

                if not dictionary_lookup_cached(segment_text, lookup_results) then
                begin
                    Continue;
                end;

                // Keep one-syllable segment lookups untrimmed here: we filter to single-char
                // candidates below, and early truncation can starve useful fallbacks.
                if (segment_len > 1) and (per_limit > 0) and (Length(lookup_results) > per_limit) then
                begin
                    SetLength(lookup_results, per_limit);
                end;

                remaining_syllables := Length(syllables) - segment_len;
                if remaining_syllables > 0 then
                begin
                    remaining_pinyin := build_syllable_text(segment_len, remaining_syllables);
                end
                else
                begin
                    remaining_pinyin := '';
                end;

                for i := 0 to High(lookup_results) do
                begin
                    candidate := lookup_results[i];
                    candidate_text_units := get_text_unit_count(Trim(candidate.text));
                    if candidate_text_units <= 0 then
                    begin
                        Continue;
                    end;
                    // Avoid over-complete long phrase suggestions on incomplete trailing initials,
                    // e.g. "jibuzh" => "鐠侀绗夋担? + dangling "h".
                    if (segment_len >= 3) and (remaining_syllables = 1) and
                        (High(syllables) >= 0) and
                        is_single_initial_token(syllables[High(syllables)].text) and
                        (candidate_text_units > 1) and (candidate_text_units >= segment_len) then
                    begin
                        Continue;
                    end;
                    if (segment_len = 1) and (candidate_text_units > 1) then
                    begin
                        Continue;
                    end;
                    if (Length(syllables) >= 3) and (segment_len = 1) and
                        (remaining_syllables >= 2) and (i >= c_segment_partial_single_top_n) then
                    begin
                        Continue;
                    end;
                    score_value := candidate.score + (segment_len * c_segment_prefix_bonus);
                    if (remaining_syllables > 0) and (segment_len > 1) then
                    begin
                        Inc(score_value, (segment_len - 1) * c_segment_long_prefix_bonus);
                    end;
                    if remaining_syllables > 0 then
                    begin
                        Dec(score_value, c_segment_partial_penalty * remaining_syllables);
                        Dec(score_value, c_segment_partial_quadratic_penalty *
                            remaining_syllables * remaining_syllables);
                    end;

                    if candidate_text_units <> segment_len then
                    begin
                        Dec(score_value, Abs(candidate_text_units - segment_len) * c_segment_text_unit_mismatch_penalty);
                        if candidate_text_units > segment_len then
                        begin
                            Dec(score_value,
                                (candidate_text_units - segment_len) * c_segment_text_unit_overflow_penalty);
                        end;
                    end;

                    if is_first_overall_segment and (segment_len = 1) and (remaining_syllables > 0) and
                        (Length(candidate.text) = 1) and is_common_surname_text(candidate.text) then
                    begin
                        Inc(score_value, c_segment_surname_bonus);
                    end;

                    append_candidate(candidate.text, score_value, candidate.source, remaining_pinyin,
                        candidate.has_dict_weight, candidate.dict_weight);
                end;
            end;

            if Length(syllables) < c_long_sentence_head_only_bypass_min_syllables then
            begin
                update_three_syllable_partial_preference_kind_local;
                append_three_syllable_head_only_anchor_partial_candidates;
                append_long_prefix_phrase_anchor_partial_candidates;
            end;

            if list.Count = 0 then
            begin
                Exit;
            end;

            SetLength(out_candidates, list.Count);
            for i := 0 to list.Count - 1 do
            begin
                out_candidates[i] := list[i];
            end;

            sort_candidates(out_candidates);
            // Guarantee at least one partial-commit fallback candidate is visible after truncation.
            if (total_limit > 0) and (Length(out_candidates) > total_limit) then
            begin
                existing_index := -1;
                for i := 0 to High(out_candidates) do
                begin
                    if out_candidates[i].comment <> '' then
                    begin
                        existing_index := i;
                        Break;
                    end;
                end;

                if existing_index >= total_limit then
                begin
                    candidate := out_candidates[existing_index];
                    for i := existing_index downto total_limit do
                    begin
                        out_candidates[i] := out_candidates[i - 1];
                    end;
                    out_candidates[total_limit - 1] := candidate;
                end;
            end;

            if Length(out_candidates) > total_limit then
            begin
                SetLength(out_candidates, total_limit);
            end;
            Result := Length(out_candidates) > 0;
        finally
            dedup.Free;
            list.Free;
        end;
    finally
        lookup_cache.Free;
    end;
end;

function TncEngine.build_pinyin_comment(const input_text: string;
    const allow_relaxed_missing_apostrophe: Boolean): string;
var
    parser: TncPinyinParser;
    parts: TncPinyinParseResult;
    i: Integer;
begin
    Result := '';
    if input_text = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        if allow_relaxed_missing_apostrophe then
        begin
            parts := parse_pinyin_with_relaxed_missing_apostrophe(input_text);
        end
        else
        begin
            parts := parser.parse(input_text);
        end;
        if Length(parts) <= 1 then
        begin
            Exit;
        end;

        for i := 0 to High(parts) do
        begin
            if Result <> '' then
            begin
                Result := Result + ' ';
            end;
            Result := Result + parts[i].text;
        end;
    finally
        parser.Free;
    end;
end;

procedure TncEngine.update_segment_left_context;
var
    segment_context: string;
begin
    segment_context := m_confirmed_text;
    if Length(segment_context) > c_left_context_max_len then
    begin
        segment_context := Copy(segment_context, Length(segment_context) - c_left_context_max_len + 1,
            c_left_context_max_len);
    end;
    m_segment_left_context := segment_context;
end;

procedure TncEngine.push_confirmed_segment(const text: string; const pinyin: string);
var
    item: TncConfirmedSegment;
begin
    if (text = '') or (pinyin = '') then
    begin
        Exit;
    end;

    if m_confirmed_segments = nil then
    begin
        Exit;
    end;

    item.text := text;
    item.pinyin := pinyin;
    m_confirmed_segments.Add(item);
    m_confirmed_text := m_confirmed_text + text;
    if Length(split_text_units(Trim(text))) = 1 then
    begin
        m_recent_partial_prefix_text := Trim(text);
    end
    else
    begin
        m_recent_partial_prefix_text := '';
    end;
    update_segment_left_context;
end;

procedure TncEngine.rebuild_confirmed_text;
var
    i: Integer;
begin
    m_confirmed_text := '';
    m_recent_partial_prefix_text := '';
    if m_confirmed_segments = nil then
    begin
        Exit;
    end;

    for i := 0 to m_confirmed_segments.Count - 1 do
    begin
        m_confirmed_text := m_confirmed_text + m_confirmed_segments[i].text;
    end;
    if (m_confirmed_segments.Count > 0) and
        (Length(split_text_units(Trim(m_confirmed_segments[m_confirmed_segments.Count - 1].text))) = 1) then
    begin
        m_recent_partial_prefix_text := Trim(m_confirmed_segments[m_confirmed_segments.Count - 1].text);
    end;
end;

function TncEngine.pop_confirmed_segment(out out_segment: TncConfirmedSegment): Boolean;
begin
    Result := False;
    if (m_confirmed_segments = nil) or (m_confirmed_segments.Count = 0) then
    begin
        Exit;
    end;

    out_segment := m_confirmed_segments[m_confirmed_segments.Count - 1];
    m_confirmed_segments.Delete(m_confirmed_segments.Count - 1);
    rebuild_confirmed_text;
    update_segment_left_context;
    Result := True;
end;

function TncEngine.rollback_last_segment: Boolean;
var
    segment: TncConfirmedSegment;
begin
    Result := False;
    if not pop_confirmed_segment(segment) then
    begin
        Exit;
    end;

    m_composition_text := segment.pinyin + m_composition_text;
    if m_composition_display_text <> '' then
    begin
        m_composition_display_text := segment.pinyin + m_composition_display_text;
    end
    else
    begin
        m_composition_display_text := m_composition_text;
    end;
    clear_pending_commit;
    m_page_index := 0;
    build_candidates;
    Result := True;
end;

procedure TncEngine.apply_partial_commit(const selected_text: string; const remaining_pinyin: string;
    const segment_path: string = '');
var
    normalized_pinyin: string;
    prefix_pinyin: string;
    effective_segment_path: string;
    prev_left_context: string;

    procedure record_query_path_prefixes(const tail_full_path: string; const final_query: string);
    var
        idx: Integer;
        prefix_start: Integer;
        segment_piece: string;
        prefix_path: string;
        prefix_query: string;
    begin
        if (m_dictionary = nil) or (tail_full_path = '') then
        begin
            Exit;
        end;

        prefix_path := '';
        prefix_start := 1;
        for idx := 1 to Length(tail_full_path) + 1 do
        begin
            if (idx <= Length(tail_full_path)) and (tail_full_path[idx] <> c_segment_path_separator) then
            begin
                Continue;
            end;

            segment_piece := Trim(Copy(tail_full_path, prefix_start, idx - prefix_start));
            prefix_start := idx + 1;
            if segment_piece = '' then
            begin
                Continue;
            end;

            if prefix_path <> '' then
            begin
                prefix_path := prefix_path + c_segment_path_separator;
            end;
            prefix_path := prefix_path + segment_piece;
            if get_encoded_path_segment_count_local(prefix_path) <= 1 then
            begin
                Continue;
            end;

            prefix_query := get_query_prefix_for_segment_path(prefix_path);
            if (prefix_query = '') or (prefix_query = final_query) then
            begin
                Continue;
            end;

            m_dictionary.record_query_segment_path(prefix_query, prefix_path);
        end;
    end;

    procedure note_session_query_path_prefixes(const tail_full_path: string; const final_query: string);
    var
        idx: Integer;
        prefix_start: Integer;
        segment_piece: string;
        prefix_path: string;
        prefix_query: string;
    begin
        if tail_full_path = '' then
        begin
            Exit;
        end;

        prefix_path := '';
        prefix_start := 1;
        for idx := 1 to Length(tail_full_path) + 1 do
        begin
            if (idx <= Length(tail_full_path)) and (tail_full_path[idx] <> c_segment_path_separator) then
            begin
                Continue;
            end;

            segment_piece := Trim(Copy(tail_full_path, prefix_start, idx - prefix_start));
            prefix_start := idx + 1;
            if segment_piece = '' then
            begin
                Continue;
            end;

            if prefix_path <> '' then
            begin
                prefix_path := prefix_path + c_segment_path_separator;
            end;
            prefix_path := prefix_path + segment_piece;
            if get_encoded_path_segment_count_local(prefix_path) <= 1 then
            begin
                Continue;
            end;

            prefix_query := get_query_prefix_for_segment_path(prefix_path);
            if (prefix_query = '') or (prefix_query = final_query) then
            begin
                Continue;
            end;

            note_session_query_path_choice(prefix_query, prefix_path);
        end;
    end;
begin
    if (selected_text = '') or (remaining_pinyin = '') then
    begin
        Exit;
    end;

    normalized_pinyin := normalize_pinyin_text(m_composition_text);
    prefix_pinyin := normalized_pinyin;
    if (remaining_pinyin <> '') and (Length(remaining_pinyin) <= Length(prefix_pinyin)) then
    begin
        if Copy(prefix_pinyin, Length(prefix_pinyin) - Length(remaining_pinyin) + 1,
            Length(remaining_pinyin)) = remaining_pinyin then
        begin
            prefix_pinyin := Copy(prefix_pinyin, 1, Length(prefix_pinyin) - Length(remaining_pinyin));
        end;
    end;

    if prefix_pinyin = '' then
    begin
        prefix_pinyin := normalized_pinyin;
    end;

    effective_segment_path := Trim(segment_path);
    if (effective_segment_path = '') and (selected_text <> '') and (prefix_pinyin <> '') then
    begin
        effective_segment_path := infer_segment_path_for_selected_text(selected_text);
    end;

    prev_left_context := m_left_context;
    if m_segment_left_context <> '' then
    begin
        prev_left_context := m_segment_left_context;
    end
    else if (prev_left_context = '') and (m_external_left_context <> '') then
    begin
        prev_left_context := m_external_left_context;
    end;

    if (m_dictionary <> nil) and (prefix_pinyin <> '') then
    begin
        m_dictionary.begin_learning_batch;
        try
            m_dictionary.record_commit(prefix_pinyin, selected_text);
            if get_encoded_path_segment_count_local(effective_segment_path) > 1 then
            begin
                record_query_path_prefixes(effective_segment_path, prefix_pinyin);
                m_dictionary.record_query_segment_path(prefix_pinyin, effective_segment_path);
            end;
            m_dictionary.commit_learning_batch;
        except
            m_dictionary.rollback_learning_batch;
            raise;
        end;
    end;
    note_session_commit(selected_text);
    if prefix_pinyin <> '' then
    begin
        note_session_query_choice(prefix_pinyin, selected_text);
        note_session_context_query_choice(prev_left_context, prefix_pinyin, selected_text);
        if get_encoded_path_segment_count_local(effective_segment_path) > 1 then
        begin
            note_session_query_path_prefixes(effective_segment_path, prefix_pinyin);
            note_session_query_path_choice(prefix_pinyin, effective_segment_path);
        end;
    end;

    if Length(split_text_units(Trim(selected_text))) = 1 then
    begin
        m_recent_partial_prefix_text := Trim(selected_text);
    end
    else
    begin
        m_recent_partial_prefix_text := '';
    end;
    push_confirmed_segment(selected_text, prefix_pinyin);

    m_composition_text := remaining_pinyin;
    m_composition_display_text := remaining_pinyin;
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_pending_commit_segment_path := '';
    m_page_index := 0;
    build_candidates;
end;

procedure TncEngine.set_pending_commit(const text: string; const remaining_pinyin: string = '';
    const allow_learning: Boolean = True; const segment_path: string = '');
var
    query_key: string;
begin
    m_pending_commit_text := text;
    m_pending_commit_remaining := remaining_pinyin;
    m_has_pending_commit := True;
    m_pending_commit_allow_learning := allow_learning;
    m_pending_commit_segment_path := segment_path;
    query_key := normalize_pinyin_text(m_last_lookup_key);
    if query_key = '' then
    begin
        query_key := normalize_pinyin_text(m_composition_text);
    end;
    m_pending_commit_query_key := query_key;
end;

procedure TncEngine.clear_pending_commit;
begin
    if not m_has_pending_commit then
    begin
        Exit;
    end;

    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_pending_commit_segment_path := '';
    m_pending_commit_query_key := '';
end;

procedure TncEngine.update_left_context(const committed_text: string);
var
    context_units: TArray<string>;
    idx: Integer;
    min_idx: Integer;
    next_context: string;
begin
    next_context := Trim(m_left_context + committed_text);
    if next_context = '' then
    begin
        m_left_context := '';
        Exit;
    end;

    context_units := split_text_units(next_context);
    if Length(context_units) > c_left_context_max_len then
    begin
        min_idx := Length(context_units) - c_left_context_max_len;
        next_context := '';
        for idx := min_idx to High(context_units) do
        begin
            next_context := next_context + context_units[idx];
        end;
    end;
    m_left_context := next_context;
end;

procedure TncEngine.note_session_commit(const text: string);
var
    count: Integer;
    evict_text: string;
    text_key: string;
begin
    text_key := Trim(text);
    if (text_key = '') or (m_session_text_counts = nil) or (m_session_text_order = nil) then
    begin
        Exit;
    end;

    Inc(m_session_commit_serial);

    if m_session_text_counts.TryGetValue(text_key, count) then
    begin
        Inc(count);
        m_session_text_counts.AddOrSetValue(text_key, count);
    end
    else
    begin
        m_session_text_counts.Add(text_key, 1);
    end;
    if m_session_text_last_seen <> nil then
    begin
        m_session_text_last_seen.AddOrSetValue(text_key, m_session_commit_serial);
    end;

    m_session_text_order.Enqueue(text_key);
    while m_session_text_order.Count > c_session_text_history_limit do
    begin
        evict_text := m_session_text_order.Dequeue;
        if not m_session_text_counts.TryGetValue(evict_text, count) then
        begin
            Continue;
        end;
        Dec(count);
        if count <= 0 then
        begin
            m_session_text_counts.Remove(evict_text);
            if m_session_text_last_seen <> nil then
            begin
                m_session_text_last_seen.Remove(evict_text);
            end;
        end
        else
        begin
            m_session_text_counts.AddOrSetValue(evict_text, count);
        end;
    end;
end;

procedure TncEngine.note_session_query_choice(const query_key: string; const text: string);
var
    count: Integer;
    evict_key: string;
    key: string;
    current_serial: Int64;
begin
    key := build_session_query_choice_key(normalize_pinyin_text(query_key), text);
    if (key = '') or (m_session_query_choice_counts = nil) or (m_session_query_choice_order = nil) then
    begin
        Exit;
    end;

    current_serial := m_session_commit_serial;
    if current_serial <= 0 then
    begin
        current_serial := 1;
    end;

    if m_session_query_choice_counts.TryGetValue(key, count) then
    begin
        Inc(count);
        m_session_query_choice_counts.AddOrSetValue(key, count);
    end
    else
    begin
        m_session_query_choice_counts.Add(key, 1);
    end;
    if m_session_query_choice_last_seen <> nil then
    begin
        m_session_query_choice_last_seen.AddOrSetValue(key, current_serial);
    end;
    if m_session_query_latest_text <> nil then
    begin
        m_session_query_latest_text.AddOrSetValue(normalize_pinyin_text(query_key), Trim(text));
    end;

    m_session_query_choice_order.Enqueue(key);
    while m_session_query_choice_order.Count > c_session_query_history_limit do
    begin
        evict_key := m_session_query_choice_order.Dequeue;
        if not m_session_query_choice_counts.TryGetValue(evict_key, count) then
        begin
            Continue;
        end;

        Dec(count);
        if count <= 0 then
        begin
            m_session_query_choice_counts.Remove(evict_key);
            if m_session_query_choice_last_seen <> nil then
            begin
                m_session_query_choice_last_seen.Remove(evict_key);
            end;
        end
        else
        begin
            m_session_query_choice_counts.AddOrSetValue(evict_key, count);
        end;
    end;
end;

procedure TncEngine.note_session_query_path_choice(const query_key: string; const encoded_path: string);
var
    count: Integer;
    current_serial: Int64;
    evict_key: string;
    key: string;
begin
    key := build_session_query_path_choice_key(normalize_pinyin_text(query_key), encoded_path);
    if (key = '') or (m_session_query_path_choice_counts = nil) or
        (m_session_query_path_choice_order = nil) then
    begin
        Exit;
    end;

    current_serial := m_session_commit_serial;
    if current_serial <= 0 then
    begin
        current_serial := 1;
    end;

    if m_session_query_path_choice_counts.TryGetValue(key, count) then
    begin
        Inc(count);
        m_session_query_path_choice_counts.AddOrSetValue(key, count);
    end
    else
    begin
        m_session_query_path_choice_counts.Add(key, 1);
    end;

    if m_session_query_path_choice_last_seen <> nil then
    begin
        m_session_query_path_choice_last_seen.AddOrSetValue(key, current_serial);
    end;

    // Keep immediate follow-up lookups in sync with the just-recorded choice.
    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.Clear;
    end;

    m_session_query_path_choice_order.Enqueue(key);
    while m_session_query_path_choice_order.Count > c_session_query_path_history_limit do
    begin
        evict_key := m_session_query_path_choice_order.Dequeue;
        if not m_session_query_path_choice_counts.TryGetValue(evict_key, count) then
        begin
            Continue;
        end;

        Dec(count);
        if count <= 0 then
        begin
            m_session_query_path_choice_counts.Remove(evict_key);
            if m_session_query_path_choice_last_seen <> nil then
            begin
                m_session_query_path_choice_last_seen.Remove(evict_key);
            end;
        end
        else
        begin
            m_session_query_path_choice_counts.AddOrSetValue(evict_key, count);
        end;
    end;
end;

procedure TncEngine.note_session_query_path_penalty(const query_key: string; const encoded_path: string);
var
    count: Integer;
    current_serial: Int64;
    evict_key: string;
    key: string;
begin
    key := build_session_query_path_choice_key(normalize_pinyin_text(query_key), encoded_path);
    if (key = '') or (m_session_query_path_penalty_counts = nil) or
        (m_session_query_path_penalty_order = nil) then
    begin
        Exit;
    end;

    current_serial := m_session_commit_serial;
    if current_serial <= 0 then
    begin
        current_serial := 1;
    end;

    if m_session_query_path_penalty_counts.TryGetValue(key, count) then
    begin
        Inc(count);
        m_session_query_path_penalty_counts.AddOrSetValue(key, count);
    end
    else
    begin
        m_session_query_path_penalty_counts.Add(key, 1);
    end;

    if m_session_query_path_penalty_last_seen <> nil then
    begin
        m_session_query_path_penalty_last_seen.AddOrSetValue(key, current_serial);
    end;

    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.Clear;
    end;

    m_session_query_path_penalty_order.Enqueue(key);
    while m_session_query_path_penalty_order.Count > c_session_query_path_history_limit do
    begin
        evict_key := m_session_query_path_penalty_order.Dequeue;
        if not m_session_query_path_penalty_counts.TryGetValue(evict_key, count) then
        begin
            Continue;
        end;

        Dec(count);
        if count <= 0 then
        begin
            m_session_query_path_penalty_counts.Remove(evict_key);
            if m_session_query_path_penalty_last_seen <> nil then
            begin
                m_session_query_path_penalty_last_seen.Remove(evict_key);
            end;
        end
        else
        begin
            m_session_query_path_penalty_counts.AddOrSetValue(evict_key, count);
        end;
    end;
end;

procedure TncEngine.note_session_ranked_query_path(const query_key: string; const encoded_path: string;
    const path_confidence_score: Integer);
var
    normalized_query: string;
    normalized_path: string;
    evict_key: string;
begin
    normalized_query := normalize_pinyin_text(query_key);
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count_local(normalized_path) <= 1) or
        (m_session_ranked_query_paths = nil) or (m_session_ranked_query_path_scores = nil) or
        (m_session_ranked_query_path_order = nil) then
    begin
        Exit;
    end;

    if not m_session_ranked_query_paths.ContainsKey(normalized_query) then
    begin
        m_session_ranked_query_path_order.Enqueue(normalized_query);
    end;
    m_session_ranked_query_paths.AddOrSetValue(normalized_query, normalized_path);
    m_session_ranked_query_path_scores.AddOrSetValue(normalized_query,
        Max(0, path_confidence_score));

    if m_lookup_query_path_bonus_cache <> nil then
    begin
        m_lookup_query_path_bonus_cache.Clear;
    end;

    while m_session_ranked_query_path_order.Count > c_session_ranked_query_path_history_limit do
    begin
        evict_key := m_session_ranked_query_path_order.Dequeue;
        m_session_ranked_query_paths.Remove(evict_key);
        m_session_ranked_query_path_scores.Remove(evict_key);
    end;
end;

procedure TncEngine.note_session_context_query_choice(const context_text: string; const query_key: string;
    const text: string);
var
    context_variants: TArray<string>;
    variant_idx: Integer;
    key: string;
    count: Integer;
    evict_key: string;
    current_serial: Int64;
begin
    if (Trim(context_text) = '') or (Trim(query_key) = '') or (Trim(text) = '') or
        (m_session_context_query_choice_counts = nil) or (m_session_context_query_choice_order = nil) then
    begin
        Exit;
    end;

    context_variants := get_context_variants(context_text);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    current_serial := m_session_commit_serial;
    if current_serial <= 0 then
    begin
        current_serial := 1;
    end;

    for variant_idx := 0 to High(context_variants) do
    begin
        key := build_context_query_choice_key(context_variants[variant_idx], normalize_pinyin_text(query_key), text);
        if key = '' then
        begin
            Continue;
        end;

        if m_session_context_query_choice_counts.TryGetValue(key, count) then
        begin
            Inc(count);
            m_session_context_query_choice_counts.AddOrSetValue(key, count);
        end
        else
        begin
            m_session_context_query_choice_counts.Add(key, 1);
        end;

        if m_session_context_query_choice_last_seen <> nil then
        begin
            m_session_context_query_choice_last_seen.AddOrSetValue(key, current_serial);
        end;
        if m_session_context_query_latest_text <> nil then
        begin
            m_session_context_query_latest_text.AddOrSetValue(
                build_context_query_scope_key(context_variants[variant_idx], normalize_pinyin_text(query_key)),
                Trim(text));
        end;

        m_session_context_query_choice_order.Enqueue(key);
    end;

    while m_session_context_query_choice_order.Count > c_session_context_query_history_limit do
    begin
        evict_key := m_session_context_query_choice_order.Dequeue;
        if not m_session_context_query_choice_counts.TryGetValue(evict_key, count) then
        begin
            Continue;
        end;

        Dec(count);
        if count <= 0 then
        begin
            m_session_context_query_choice_counts.Remove(evict_key);
            if m_session_context_query_choice_last_seen <> nil then
            begin
                m_session_context_query_choice_last_seen.Remove(evict_key);
            end;
        end
        else
        begin
            m_session_context_query_choice_counts.AddOrSetValue(evict_key, count);
        end;
    end;
end;

procedure TncEngine.track_phrase_context_key(const phrase_key: string; const current_serial: Int64);
var
    count: Integer;
    evict_key: string;
begin
    if (phrase_key = '') or (m_phrase_context_pairs = nil) or (m_phrase_context_order = nil) then
    begin
        Exit;
    end;

    if m_phrase_context_pairs.TryGetValue(phrase_key, count) then
    begin
        Inc(count);
        m_phrase_context_pairs.AddOrSetValue(phrase_key, count);
    end
    else
    begin
        m_phrase_context_pairs.Add(phrase_key, 1);
    end;
    m_phrase_context_order.Enqueue(phrase_key);
    if m_phrase_context_last_seen <> nil then
    begin
        m_phrase_context_last_seen.AddOrSetValue(phrase_key, current_serial);
    end;

    while m_phrase_context_order.Count > c_phrase_context_history_limit do
    begin
        evict_key := m_phrase_context_order.Dequeue;
        if not m_phrase_context_pairs.TryGetValue(evict_key, count) then
        begin
            Continue;
        end;

        Dec(count);
        if count <= 0 then
        begin
            m_phrase_context_pairs.Remove(evict_key);
            if m_phrase_context_last_seen <> nil then
            begin
                m_phrase_context_last_seen.Remove(evict_key);
            end;
        end
        else
        begin
            m_phrase_context_pairs.AddOrSetValue(evict_key, count);
        end;
    end;
end;

procedure TncEngine.note_output_phrase_context(const committed_text: string);
var
    text_key: string;
    current_serial: Int64;
begin
    text_key := Trim(committed_text);
    if text_key = '' then
    begin
        Exit;
    end;

    current_serial := m_session_commit_serial;
    if current_serial <= 0 then
    begin
        current_serial := 1;
    end;

    if m_last_output_commit_text <> '' then
    begin
        track_phrase_context_key(m_last_output_commit_text + #1 + text_key, current_serial);
    end;

    if (m_prev_output_commit_text <> '') and (m_last_output_commit_text <> '') then
    begin
        track_phrase_context_key(
            m_prev_output_commit_text + #2 + m_last_output_commit_text + #1 + text_key,
            current_serial);
    end;

    m_prev_output_commit_text := m_last_output_commit_text;
    m_last_output_commit_text := text_key;
end;

procedure TncEngine.note_segment_path_context(const encoded_path: string);
var
    segments: TArray<string>;
    segment_text: string;
    current_serial: Int64;
    idx: Integer;
    segment_start: Integer;
    segment_idx: Integer;
begin
    if (encoded_path = '') or (m_phrase_context_pairs = nil) or (m_phrase_context_order = nil) then
    begin
        Exit;
    end;

    current_serial := m_session_commit_serial;
    if current_serial <= 0 then
    begin
        current_serial := 1;
    end;

    SetLength(segments, 0);
    segment_start := 1;
    for idx := 1 to Length(encoded_path) + 1 do
    begin
        if (idx <= Length(encoded_path)) and (encoded_path[idx] <> c_segment_path_separator) then
        begin
            Continue;
        end;

        segment_text := Copy(encoded_path, segment_start, idx - segment_start);
        segment_text := Trim(segment_text);
        if segment_text <> '' then
        begin
            segment_idx := Length(segments);
            SetLength(segments, segment_idx + 1);
            segments[segment_idx] := segment_text;
        end;
        segment_start := idx + 1;
    end;

    if Length(segments) <= 1 then
    begin
        Exit;
    end;

    for idx := 1 to High(segments) do
    begin
        track_phrase_context_key(segments[idx - 1] + #1 + segments[idx], current_serial);
        if idx >= 2 then
        begin
            track_phrase_context_key(
                segments[idx - 2] + #2 + segments[idx - 1] + #1 + segments[idx],
                current_serial);
        end;
    end;
end;

procedure TncEngine.record_context_pair(const left_text: string; const committed_text: string);
var
    context_variants: TArray<string>;
    evict_key: string;
    count: Integer;
    key: string;
    variant_idx: Integer;
begin
    if (left_text = '') or (committed_text = '') then
    begin
        Exit;
    end;

    context_variants := get_context_variants(left_text);
    if Length(context_variants) = 0 then
    begin
        Exit;
    end;

    if m_dictionary <> nil then
    begin
        m_dictionary.record_context_pair(left_text, committed_text);
    end;

    if m_context_db_bonus_cache <> nil then
    begin
        m_context_db_bonus_cache.Clear;
        m_context_db_bonus_cache_key := '';
    end;

    if m_context_pairs = nil then
    begin
        Exit;
    end;

    if m_context_order = nil then
    begin
        Exit;
    end;

    for variant_idx := 0 to High(context_variants) do
    begin
        key := context_variants[variant_idx] + #1 + committed_text;
        if m_context_pairs.TryGetValue(key, count) then
        begin
            Inc(count);
            m_context_pairs.AddOrSetValue(key, count);
        end
        else
        begin
            m_context_pairs.Add(key, 1);
        end;

        m_context_order.Enqueue(key);
        while m_context_order.Count > c_context_history_limit do
        begin
            evict_key := m_context_order.Dequeue;
            if m_context_pairs.TryGetValue(evict_key, count) then
            begin
                Dec(count);
                if count <= 0 then
                begin
                    m_context_pairs.Remove(evict_key);
                end
                else
                begin
                    m_context_pairs.AddOrSetValue(evict_key, count);
                end;
            end;
        end;
    end;
end;

procedure TncEngine.toggle_input_mode;
begin
    if m_config.input_mode = im_chinese then
    begin
        m_config.input_mode := im_english;
    end
    else
    begin
        m_config.input_mode := im_chinese;
    end;

    reset;
end;

function TncEngine.process_key(const key_code: Word; const key_state: TncKeyState): Boolean;
var
    key_char: Char;
    display_key_char: Char;
    index: Integer;
    commit_text: string;
    page_size: Integer;
    page_offset: Integer;
    punct_char: Char;
    punct_text: string;
    candidate: TncCandidate;

    function get_selected_candidate(out out_candidate: TncCandidate): Boolean;
    begin
        normalize_page_and_selection;
        page_size := get_candidate_limit;
        page_offset := m_page_index * page_size;
        index := page_offset + m_selected_index;
        if (index >= 0) and (index < Length(m_candidates)) then
        begin
            out_candidate := m_candidates[index];
            Result := True;
            Exit;
        end;

        if m_composition_display_text <> '' then
        begin
            out_candidate.text := m_composition_display_text;
        end
        else
        begin
            out_candidate.text := m_composition_text;
        end;
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;
        out_candidate.has_dict_weight := False;
        out_candidate.dict_weight := 0;
        Result := True;
    end;

    function is_generic_runtime_chain_selection(const selected: TncCandidate): Boolean;
    begin
        Result := False;
        if (m_runtime_chain_text = '') or selected.has_dict_weight or
            (selected.source <> cs_rule) or (selected.comment <> '') then
        begin
            Exit;
        end;
        Result := SameText(m_runtime_chain_text, selected.text);
    end;

    function is_nonlearnable_runtime_chain_selection(const selected: TncCandidate): Boolean;
    var
        text_units: Integer;
        idx: Integer;
        full_text: string;
        segment_path: string;
        unit_text: string;
        units: TArray<string>;
    begin
        Result := False;
        if not is_generic_runtime_chain_selection(selected) then
        begin
            Exit;
        end;

        segment_path := get_segment_path_for_candidate(selected);
        if segment_path <> '' then
        begin
            Exit(False);
        end;

        full_text := selected.text;
        if m_confirmed_text <> '' then
        begin
            full_text := m_confirmed_text + full_text;
        end;

        text_units := get_candidate_text_unit_count(full_text);
        if text_units >= 4 then
        begin
            units := split_text_units(full_text);
            Result := Length(units) = text_units;
            if Result then
            begin
                for idx := 0 to High(units) do
                begin
                    unit_text := Trim(units[idx]);
                    if (unit_text = '') or (Length(unit_text) <> 1) or (Ord(unit_text[1]) <= $7F) then
                    begin
                        Result := False;
                        Break;
                    end;
                end;
            end;
            if Result then
            begin
                Exit(False);
            end;
        end;

        Result := True;
    end;

    function is_compact_ascii_pinyin(const value: string): Boolean;
    var
        idx: Integer;
        ch: Char;
    begin
        Result := value <> '';
        if not Result then
        begin
            Exit;
        end;

        for idx := 1 to Length(value) do
        begin
            ch := value[idx];
            if not (((ch >= 'a') and (ch <= 'z')) or ((ch >= 'A') and (ch <= 'Z'))) then
            begin
                Result := False;
                Exit;
            end;
        end;
    end;

    function try_apply_trailing_pinyin_candidate(const candidate_text: string): Boolean;
    var
        head_text: string;
        tail_pinyin: string;
        normalized_pinyin: string;
        idx: Integer;
        tail_len: Integer;
        ch: Char;
        head_has_non_ascii: Boolean;
        function is_ascii_letter(const value: Char): Boolean;
        begin
            Result := (value >= 'a') and (value <= 'z') or (value >= 'A') and (value <= 'Z');
        end;
    begin
        Result := False;
        head_text := '';
        tail_pinyin := '';
        if candidate_text = '' then
        begin
            Exit;
        end;

        idx := Length(candidate_text);
        while idx > 0 do
        begin
            ch := candidate_text[idx];
            if not is_ascii_letter(ch) then
            begin
                Break;
            end;
            Dec(idx);
        end;

        if idx = Length(candidate_text) then
        begin
            Exit;
        end;

        head_text := Copy(candidate_text, 1, idx);
        tail_pinyin := Copy(candidate_text, idx + 1, Length(candidate_text) - idx);
        if (head_text = '') or (tail_pinyin = '') then
        begin
            Exit;
        end;

        head_has_non_ascii := False;
        for idx := 1 to Length(head_text) do
        begin
            if Ord(head_text[idx]) > $7F then
            begin
                head_has_non_ascii := True;
                Break;
            end;
        end;
        if not head_has_non_ascii then
        begin
            Exit;
        end;

        normalized_pinyin := normalize_pinyin_text(m_composition_text);
        tail_len := Length(tail_pinyin);
        if (tail_len > 0) and (tail_len <= Length(normalized_pinyin)) then
        begin
            if SameText(Copy(normalized_pinyin, Length(normalized_pinyin) - tail_len + 1, tail_len), tail_pinyin) then
            begin
                apply_partial_commit(head_text, tail_pinyin);
                Result := True;
            end;
        end;
    end;

    function apply_candidate_selection(const selected: TncCandidate;
        const selected_candidate_index: Integer = -1): Boolean;
    var
        allow_learning: Boolean;
        segment_path: string;
        top_candidate: TncCandidate;
        top_score: Integer;
        selected_score: Integer;
        top_confidence_rank: Integer;
        selected_confidence_rank: Integer;
        top_segment_path: string;

        function split_encoded_path(const encoded_path: string): TArray<string>;
        var
            idx: Integer;
            start_idx: Integer;
            segment_text: string;
            count: Integer;
        begin
            SetLength(Result, 0);
            start_idx := 1;
            for idx := 1 to Length(encoded_path) + 1 do
            begin
                if (idx <= Length(encoded_path)) and (encoded_path[idx] <> c_segment_path_separator) then
                begin
                    Continue;
                end;

                segment_text := Trim(Copy(encoded_path, start_idx, idx - start_idx));
                if segment_text <> '' then
                begin
                    count := Length(Result);
                    SetLength(Result, count + 1);
                    Result[count] := segment_text;
                end;
                start_idx := idx + 1;
            end;
        end;

        procedure record_divergent_query_path_prefix_penalties(const selected_path: string;
            const wrong_path: string);
        var
            selected_segments: TArray<string>;
            wrong_segments: TArray<string>;
            shared_count: Integer;
            prefix_idx: Integer;
            prefix_path: string;
            prefix_query: string;
        begin
            if (m_dictionary = nil) or (selected_path = '') or (wrong_path = '') then
            begin
                Exit;
            end;
            if (get_encoded_path_segment_count_local(selected_path) <= 1) or
                (get_encoded_path_segment_count_local(wrong_path) <= 1) then
            begin
                Exit;
            end;

            selected_segments := split_encoded_path(selected_path);
            wrong_segments := split_encoded_path(wrong_path);
            if (Length(selected_segments) = 0) or (Length(wrong_segments) <= 2) then
            begin
                Exit;
            end;

            shared_count := 0;
            while (shared_count < Length(selected_segments)) and (shared_count < Length(wrong_segments)) and
                SameText(Trim(selected_segments[shared_count]), Trim(wrong_segments[shared_count])) do
            begin
                Inc(shared_count);
            end;

            prefix_path := '';
            for prefix_idx := 0 to High(wrong_segments) - 1 do
            begin
                if prefix_path <> '' then
                begin
                    prefix_path := prefix_path + c_segment_path_separator;
                end;
                prefix_path := prefix_path + wrong_segments[prefix_idx];
                if (prefix_idx + 1 < 2) or (prefix_idx + 1 <= shared_count) then
                begin
                    Continue;
                end;

                prefix_query := get_query_prefix_for_segment_path(prefix_path);
                if prefix_query <> '' then
                begin
                    note_session_query_path_penalty(prefix_query, prefix_path);
                    m_dictionary.record_query_segment_path_penalty(prefix_query, prefix_path);
                end;
            end;
        end;
    begin
        segment_path := get_segment_path_for_candidate(selected, selected_candidate_index);
        if (selected.comment <> '') and is_compact_ascii_pinyin(selected.comment) then
        begin
            if segment_path = '' then
            begin
                segment_path := infer_segment_path_for_selected_text(selected.text);
            end;
            apply_partial_commit(selected.text, selected.comment, segment_path);
            Result := True;
            Exit;
        end;

        if try_apply_trailing_pinyin_candidate(selected.text) then
        begin
            Result := True;
            Exit;
        end;

        if (segment_path = '') and (selected.comment = '') then
        begin
            segment_path := infer_segment_path_for_selected_text(selected.text);
        end;

        allow_learning := not is_nonlearnable_runtime_chain_selection(selected);
        if allow_learning and has_competing_exact_phrase_candidate(selected.text) and
            is_problematic_single_char_chain_candidate_for_query(m_last_lookup_key, selected) then
        begin
            allow_learning := False;
        end;

        if (m_last_lookup_key <> '') and (selected_candidate_index > 0) and
            (Length(m_candidates) > 0) then
        begin
            top_candidate := m_candidates[0];
            if (top_candidate.comment = '') and (selected.comment = '') and
                (top_candidate.text <> '') and (selected.text <> '') and
                (top_candidate.text <> selected.text) and
                (not is_nonlearnable_runtime_chain_selection(selected)) then
            begin
                top_score := get_rank_score(top_candidate);
                selected_score := get_rank_score(selected);
                top_confidence_rank := get_candidate_confidence_rank(top_candidate);
                selected_confidence_rank := get_candidate_confidence_rank(selected);
                if (selected_confidence_rank < top_confidence_rank) or
                    ((top_score - selected_score) <= 160) or
                    is_runtime_chain_candidate(top_candidate) or
                    ((top_candidate.source = cs_rule) and (not top_candidate.has_dict_weight) and
                    (not is_runtime_common_pattern_candidate(top_candidate)) and
                    (not is_runtime_redup_candidate(top_candidate))) then
                begin
                    if m_dictionary <> nil then
                    begin
                        m_dictionary.record_candidate_penalty(m_last_lookup_key, top_candidate.text);
                        top_segment_path := get_segment_path_for_candidate(top_candidate, 0);
                        if (top_segment_path = '') and (top_candidate.comment = '') then
                        begin
                            top_segment_path := infer_segment_path_for_selected_text(top_candidate.text);
                        end;
                        if (segment_path <> '') and (top_segment_path <> '') and
                            (segment_path <> top_segment_path) and
                            (get_encoded_path_segment_count_local(segment_path) > 1) and
                            (get_encoded_path_segment_count_local(top_segment_path) > 1) then
                        begin
                            record_divergent_query_path_prefix_penalties(segment_path, top_segment_path);
                            note_session_query_path_penalty(m_last_lookup_key, top_segment_path);
                            m_dictionary.record_query_segment_path_penalty(m_last_lookup_key, top_segment_path);
                        end;
                    end;
                end;
            end;
        end;

        set_pending_commit(selected.text, '', allow_learning,
            segment_path);
        Result := True;
    end;
begin
    Result := False;
    if key_state.ctrl_down and (key_code = VK_SPACE) then
    begin
        if m_config.enable_ctrl_space_toggle then
        begin
            toggle_input_mode;
            Result := True;
        end
        else
        begin
            Result := False;
        end;
        Exit;
    end;

    if key_state.shift_down and (key_code = VK_SPACE) then
    begin
        if m_config.enable_shift_space_full_width_toggle then
        begin
            m_config.full_width_mode := not m_config.full_width_mode;
            Result := True;
        end
        else
        begin
            Result := False;
        end;
        Exit;
    end;

    if key_state.ctrl_down and (key_code = VK_OEM_PERIOD) then
    begin
        if m_config.enable_ctrl_period_punct_toggle then
        begin
            m_config.punctuation_full_width := not m_config.punctuation_full_width;
            Result := True;
        end
        else
        begin
            Result := False;
        end;
        Exit;
    end;

    if key_state.ctrl_down or key_state.alt_down then
    begin
        Exit(False);
    end;

    if m_config.input_mode = im_english then
    begin
        if get_direct_ascii_commit_text(key_code, key_state, commit_text) then
        begin
            set_pending_commit(commit_text);
            Exit(True);
        end;
        Exit(False);
    end;

    if m_composition_text <> '' then
    begin
        normalize_page_and_selection;
    end;

    if is_alpha_key(key_code, key_state, key_char, display_key_char) then
    begin
        clear_pending_commit;
        m_composition_text := m_composition_text + key_char;
        m_composition_display_text := m_composition_display_text + display_key_char;
        build_candidates;
        Result := True;
        Exit;
    end;

    if (key_code = VK_OEM_3) and (m_composition_text <> '') and (not key_state.shift_down) and
        (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        reset;
        Result := True;
        Exit;
    end;

    if ((m_composition_text <> '') or (m_confirmed_text <> '')) and (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        if (key_code = VK_ADD) or (key_code = VK_OEM_PLUS) then
        begin
            next_page;
            Result := True;
            Exit;
        end;

        if (key_code = VK_SUBTRACT) or ((key_code = VK_OEM_MINUS) and (not key_state.shift_down)) then
        begin
            prev_page;
            Result := True;
            Exit;
        end;
    end;

    if get_punctuation_char(key_code, key_state, punct_char) then
    begin
        if (key_code <> VK_OEM_7) or (m_composition_text = '') then
        begin
            punct_text := map_punctuation_char(punct_char);
            if (m_composition_text <> '') or (m_confirmed_text <> '') then
            begin
                commit_text := punct_text;
                if m_composition_text <> '' then
                begin
                    get_selected_candidate(candidate);
                    commit_text := candidate.text + punct_text;
                    set_pending_commit(commit_text, '', not is_nonlearnable_runtime_chain_selection(candidate));
                    Result := True;
                    Exit;
                end;

                set_pending_commit(commit_text);
                Result := True;
                Exit;
            end;

            if get_effective_punctuation_full_width or m_config.full_width_mode then
            begin
                set_pending_commit(punct_text);
                Result := True;
                Exit;
            end;

            Exit(False);
        end;
    end;

    case key_code of
        VK_BACK:
            begin
                // When there is confirmed segmented prefix, Backspace should first
                // rollback that prefix to pinyin so users can reselect without
                // deleting the entire remaining tail.
                if (m_confirmed_segments <> nil) and (m_confirmed_segments.Count > 0) then
                begin
                    Result := rollback_last_segment;
                end;
                if (not Result) and (m_composition_text <> '') then
                begin
                    clear_pending_commit;
                    Delete(m_composition_text, Length(m_composition_text), 1);
                    if m_composition_display_text <> '' then
                    begin
                        Delete(m_composition_display_text, Length(m_composition_display_text), 1);
                    end;
                    build_candidates;
                    Result := True;
                end;
            end;
        VK_OEM_7:
            begin
                if m_composition_text <> '' then
                begin
                    clear_pending_commit;
                    if m_composition_text[Length(m_composition_text)] <> '''' then
                    begin
                        m_composition_text := m_composition_text + '''';
                        m_composition_display_text := m_composition_display_text + '''';
                        build_candidates;
                    end;

                    Result := True;
                end;
            end;
        VK_ESCAPE:
            begin
                if (m_composition_text <> '') or (m_confirmed_text <> '') or (Length(m_candidates) > 0) or
                    m_has_pending_commit then
                begin
                    reset;
                    Result := True;
                end;
            end;
        VK_SPACE:
            begin
                if m_composition_text <> '' then
                begin
                    if get_selected_candidate(candidate) then
                    begin
                        Result := apply_candidate_selection(candidate, index);
                    end;
                end
                else if m_confirmed_text <> '' then
                begin
                    set_pending_commit('');
                    Result := True;
                end;
            end;
        VK_RETURN:
            begin
                if m_composition_text <> '' then
                begin
                    // Enter should commit raw input text instead of selecting candidate.
                    set_pending_commit(get_raw_composition_commit_text);
                    Result := True;
                end
                else if m_confirmed_text <> '' then
                begin
                    set_pending_commit('');
                    Result := True;
                end;
            end;
        VK_PRIOR:
            begin
                if (m_composition_text <> '') or (m_confirmed_text <> '') then
                begin
                    if m_composition_text <> '' then
                    begin
                        prev_page;
                    end;
                    Result := True;
                end;
            end;
        VK_NEXT:
            begin
                if (m_composition_text <> '') or (m_confirmed_text <> '') then
                begin
                    if m_composition_text <> '' then
                    begin
                        next_page;
                    end;
                    Result := True;
                end;
            end;
        VK_LEFT, VK_UP:
            begin
                if (m_composition_text <> '') and (not key_state.shift_down) and (not key_state.ctrl_down) and
                    (not key_state.alt_down) then
                begin
                    page_size := get_candidate_limit;
                    if page_size <= 0 then
                    begin
                        page_size := c_default_page_size;
                    end;

                    normalize_page_and_selection;
                    if m_selected_index > 0 then
                    begin
                        Dec(m_selected_index);
                    end
                    else if m_page_index > 0 then
                    begin
                        Dec(m_page_index);
                        page_offset := m_page_index * page_size;
                        index := Length(m_candidates) - page_offset;
                        if index > page_size then
                        begin
                            index := page_size;
                        end;
                        if index > 0 then
                        begin
                            m_selected_index := index - 1;
                        end
                        else
                        begin
                            m_selected_index := 0;
                        end;
                    end;
                    normalize_page_and_selection;
                    Result := True;
                end;
            end;
        VK_RIGHT, VK_DOWN:
            begin
                if (m_composition_text <> '') and (not key_state.shift_down) and (not key_state.ctrl_down) and
                    (not key_state.alt_down) then
                begin
                    page_size := get_candidate_limit;
                    if page_size <= 0 then
                    begin
                        page_size := c_default_page_size;
                    end;

                    normalize_page_and_selection;
                    page_offset := m_page_index * page_size;
                    index := Length(m_candidates) - page_offset;
                    if index > page_size then
                    begin
                        index := page_size;
                    end;

                    if (index > 0) and (m_selected_index < index - 1) then
                    begin
                        Inc(m_selected_index);
                    end
                    else if m_page_index < get_page_count_internal(page_size) - 1 then
                    begin
                        Inc(m_page_index);
                        m_selected_index := 0;
                        normalize_page_and_selection;
                    end;
                    Result := True;
                end;
            end;
        Ord('1')..Ord('9'):
            begin
                if m_composition_text <> '' then
                begin
                    page_size := get_candidate_limit;
                    page_offset := m_page_index * page_size;
                    index := page_offset + (key_code - Ord('1'));
                    if (index >= 0) and (index < Length(m_candidates)) then
                    begin
                        Result := apply_candidate_selection(m_candidates[index], index);
                    end
                    else
                    begin
                        set_pending_commit(get_raw_composition_commit_text);
                        Result := True;
                    end;
                end
                else if m_confirmed_text <> '' then
                begin
                    set_pending_commit(Char(key_code));
                    Result := True;
                end;
            end;
    end;
end;

function TncEngine.get_candidates: TncCandidateList;
var
    page_size: Integer;
    page_count: Integer;
    start_index: Integer;
    end_index: Integer;
    count: Integer;
    i: Integer;
    normalized_pinyin: string;
    candidate: TncCandidate;
    head_text: string;
    tail_pinyin: string;
    function is_ascii_letter(const value: Char): Boolean;
    begin
        Result := (value >= 'a') and (value <= 'z') or (value >= 'A') and (value <= 'Z');
    end;
    function split_trailing_ascii_candidate(const candidate_text: string; out head: string; out tail: string): Boolean;
    var
        idx: Integer;
        ch: Char;
        tail_len: Integer;
    begin
        Result := False;
        head := '';
        tail := '';
        if candidate_text = '' then
        begin
            Exit;
        end;

        idx := Length(candidate_text);
        while idx > 0 do
        begin
            ch := candidate_text[idx];
            if not is_ascii_letter(ch) then
            begin
                Break;
            end;
            Dec(idx);
        end;

        if idx = Length(candidate_text) then
        begin
            Exit;
        end;

        head := Copy(candidate_text, 1, idx);
        tail := Copy(candidate_text, idx + 1, Length(candidate_text) - idx);
        if (head = '') or (tail = '') then
        begin
            Exit;
        end;

        tail_len := Length(tail);
        if (tail_len <= 0) or (tail_len > Length(normalized_pinyin)) then
        begin
            Exit;
        end;

        if not SameText(Copy(normalized_pinyin, Length(normalized_pinyin) - tail_len + 1, tail_len), tail) then
        begin
            Exit;
        end;

        Result := True;
    end;
begin
    SetLength(Result, 0);
    page_size := get_candidate_limit;
    page_count := get_page_count_internal(page_size);
    if page_count = 0 then
    begin
        Exit;
    end;

    normalize_page_and_selection;

    normalized_pinyin := normalize_pinyin_text(m_composition_text);
    start_index := m_page_index * page_size;
    end_index := start_index + page_size - 1;
    if end_index > High(m_candidates) then
    begin
        end_index := High(m_candidates);
    end;

    count := end_index - start_index + 1;
    if count <= 0 then
    begin
        Exit;
    end;

    SetLength(Result, count);
    for i := 0 to count - 1 do
    begin
        candidate := m_candidates[start_index + i];
        if (candidate.comment = '') and split_trailing_ascii_candidate(candidate.text, head_text, tail_pinyin) then
        begin
            candidate.text := head_text;
            candidate.comment := tail_pinyin;
        end;
        Result[i] := candidate;
    end;
end;

function TncEngine.get_page_count_internal(const page_size: Integer): Integer;
var
    total_count: Integer;
begin
    total_count := Length(m_candidates);
    if (page_size <= 0) or (total_count = 0) then
    begin
        Result := 0;
        Exit;
    end;

    Result := (total_count + page_size - 1) div page_size;
end;

function TncEngine.get_page_index: Integer;
begin
    if get_page_count_internal(get_candidate_limit) = 0 then
    begin
        Result := 0;
        Exit;
    end;

    Result := m_page_index;
end;

function TncEngine.get_page_count: Integer;
begin
    Result := get_page_count_internal(get_candidate_limit);
end;

function TncEngine.next_page: Boolean;
var
    page_count: Integer;
begin
    page_count := get_page_count;
    if page_count = 0 then
    begin
        Result := False;
        Exit;
    end;

    if m_page_index < page_count - 1 then
    begin
        Inc(m_page_index);
        m_selected_index := 0;
        Result := True;
    end
    else
    begin
        Result := False;
    end;
end;

function TncEngine.prev_page: Boolean;
begin
    if m_page_index > 0 then
    begin
        Dec(m_page_index);
        m_selected_index := 0;
        Result := True;
    end
    else
    begin
        Result := False;
    end;
end;

function TncEngine.get_composition_text: string;
begin
    if m_composition_display_text <> '' then
    begin
        Result := m_composition_display_text;
    end
    else
    begin
        Result := m_composition_text;
    end;
end;

function TncEngine.get_display_text: string;
var
    page_size: Integer;
    page_offset: Integer;
    selected: Integer;
    display_text: string;
begin
    if (m_composition_text = '') and (m_confirmed_text = '') then
    begin
        Result := '';
        Exit;
    end;

    display_text := '';
    if m_composition_text <> '' then
    begin
        normalize_page_and_selection;
        page_size := get_candidate_limit;
        page_offset := m_page_index * page_size;
        selected := page_offset + m_selected_index;
        if (selected >= 0) and (selected < Length(m_candidates)) then
        begin
            display_text := m_candidates[selected].text;
        end
        else
        begin
            if m_composition_display_text <> '' then
            begin
                display_text := m_composition_display_text;
            end
            else
            begin
                display_text := m_composition_text;
            end;
        end;
    end;

    Result := m_confirmed_text + display_text;
end;

function TncEngine.get_confirmed_length: Integer;
begin
    Result := Length(m_confirmed_text);
end;

function TncEngine.get_lookup_perf_info: string;
var
    perf_parts: TStringList;
begin
    if m_last_lookup_key = '' then
    begin
        Result := '';
        Exit;
    end;

    perf_parts := TStringList.Create;
    try
        perf_parts.Delimiter := ' ';
        perf_parts.StrictDelimiter := True;
        if m_last_lookup_normalized_from <> '' then
        begin
            perf_parts.Add(Format('query_norm=[%s->%s]', [m_last_lookup_normalized_from, m_last_lookup_key]));
        end
        else
        begin
            perf_parts.Add(Format('query=[%s]', [m_last_lookup_key]));
        end;

        if m_last_lookup_syllable_count > 0 then
        begin
            perf_parts.Add(Format('syll=%d', [m_last_lookup_syllable_count]));
        end;

        if m_last_lookup_timing_info <> '' then
        begin
            perf_parts.Add(m_last_lookup_timing_info);
        end;

        Result := Trim(StringReplace(perf_parts.DelimitedText, '"', '', [rfReplaceAll]));
    finally
        perf_parts.Free;
    end;
end;

function TncEngine.get_lookup_debug_info: string;
var
    debug_parts: TStringList;
    sqlite_dict: TncSqliteDictionary;
    context_preview: string;
begin
    if m_last_lookup_key = '' then
    begin
        Result := '';
        Exit;
    end;

    debug_parts := TStringList.Create;
    try
        debug_parts.Delimiter := ' ';
        debug_parts.StrictDelimiter := True;
        if m_last_lookup_normalized_from <> '' then
        begin
            debug_parts.Add(Format('query_norm=[%s->%s]', [m_last_lookup_normalized_from, m_last_lookup_key]));
        end
        else
        begin
            debug_parts.Add(Format('query=[%s]', [m_last_lookup_key]));
        end;

        if not m_config.debug_mode then
        begin
            Result := Trim(StringReplace(debug_parts.DelimitedText, '"', '', [rfReplaceAll]));
            Exit;
        end;

        if m_last_lookup_syllable_count > 0 then
        begin
            debug_parts.Add(Format('syll=%d', [m_last_lookup_syllable_count]));
        end;

        context_preview := Trim(m_left_context);
        if context_preview <> '' then
        begin
            debug_parts.Add(Format('ctx=[%s]', [context_preview]));
        end;

        if m_last_lookup_debug_extra <> '' then
        begin
            debug_parts.Add(m_last_lookup_debug_extra);
        end;
        if m_last_lookup_timing_info <> '' then
        begin
            debug_parts.Add(m_last_lookup_timing_info);
        end;

        if m_dictionary is TncSqliteDictionary then
        begin
            sqlite_dict := TncSqliteDictionary(m_dictionary);
            if sqlite_dict.get_last_lookup_debug_hint <> '' then
            begin
                debug_parts.Add(sqlite_dict.get_last_lookup_debug_hint);
            end;
        end;

        Result := Trim(StringReplace(debug_parts.DelimitedText, '"', '', [rfReplaceAll]));
    finally
        debug_parts.Free;
    end;
end;

function TncEngine.get_selected_index: Integer;
begin
    if Length(m_candidates) = 0 then
    begin
        Result := 0;
        Exit;
    end;

    normalize_page_and_selection;
    Result := m_selected_index;
end;

function TncEngine.get_debug_last_output_commit_text: string;
begin
    Result := m_last_output_commit_text;
end;

function TncEngine.get_debug_phrase_context_pair_count(const left_text: string;
    const candidate_text: string): Integer;
var
    key: string;
begin
    Result := 0;
    if m_phrase_context_pairs = nil then
    begin
        Exit;
    end;

    if (Trim(left_text) = '') or (Trim(candidate_text) = '') then
    begin
        Exit;
    end;

    key := Trim(left_text) + #1 + Trim(candidate_text);
    if not m_phrase_context_pairs.TryGetValue(key, Result) then
    begin
        Result := 0;
    end;
end;

function TncEngine.get_debug_last_commit_segment_path: string;
begin
    Result := m_last_debug_commit_segment_path;
end;

function TncEngine.get_debug_candidate_segment_path(const candidate_index: Integer): string;
begin
    Result := '';
    if (candidate_index >= 0) and (candidate_index < Length(m_candidate_segment_paths)) then
    begin
        Result := m_candidate_segment_paths[candidate_index];
    end;
end;

function TncEngine.get_debug_pending_commit_segment_path: string;
begin
    Result := m_pending_commit_segment_path;
end;

function TncEngine.get_dictionary_debug_info: string;
var
    sqlite_dict: TncSqliteDictionary;
    provider_name: string;
    ready_value: Integer;
    base_ready_value: Integer;
    user_ready_value: Integer;
    path_value: string;
    path_exists: Integer;
    sc_path_value: string;
    sc_path_exists: Integer;
    tc_path_value: string;
    tc_path_exists: Integer;
    user_path_value: string;
    user_path_exists: Integer;
    variant_text: string;
    active_path: string;
begin
    provider_name := 'none';
    ready_value := 0;
    base_ready_value := 0;
    user_ready_value := 0;
    path_value := '';
    path_exists := 0;
    sc_path_value := '';
    sc_path_exists := 0;
    tc_path_value := '';
    tc_path_exists := 0;
    user_path_value := '';
    user_path_exists := 0;
    active_path := get_active_dictionary_path;
    if m_config.dictionary_variant = dv_traditional then
    begin
        variant_text := 'traditional';
    end
    else
    begin
        variant_text := 'simplified';
    end;

    if m_dictionary is TncSqliteDictionary then
    begin
        sqlite_dict := TncSqliteDictionary(m_dictionary);
        provider_name := 'sqlite';
        ready_value := Ord(sqlite_dict.ready);
        base_ready_value := Ord(sqlite_dict.base_ready);
        user_ready_value := Ord(sqlite_dict.user_ready);
        path_value := sqlite_dict.db_path;
        user_path_value := sqlite_dict.user_db_path;
    end
    else if m_dictionary is TncInMemoryDictionary then
    begin
        provider_name := 'memory';
    end;

    if (active_path <> '') and FileExists(active_path) then
    begin
        path_exists := 1;
        if path_value = '' then
        begin
            path_value := active_path;
        end;
    end;

    sc_path_value := get_default_dictionary_path_simplified;
    if (sc_path_value <> '') and FileExists(sc_path_value) then
    begin
        sc_path_exists := 1;
    end;

    tc_path_value := get_default_dictionary_path_traditional;
    if (tc_path_value <> '') and FileExists(tc_path_value) then
    begin
        tc_path_exists := 1;
    end;

    user_path_value := get_default_user_dictionary_path;
    if (user_path_value <> '') and FileExists(user_path_value) then
    begin
        user_path_exists := 1;
    end;

    Result := Format('provider=%s ready=%d base_ready=%d user_ready=%d variant=%s dict_path=%s exists=%d dict_sc=%s sc_exists=%d dict_tc=%s tc_exists=%d user_path=%s user_exists=%d',
        [provider_name, ready_value, base_ready_value, user_ready_value, variant_text, path_value, path_exists,
        sc_path_value, sc_path_exists, tc_path_value, tc_path_exists, user_path_value, user_path_exists]);
end;

function TncEngine.should_handle_key(const key_code: Word; const key_state: TncKeyState): Boolean;
var
    key_char: Char;
    display_key_char: Char;
    punct_char: Char;
    has_candidates: Boolean;
    direct_commit_text: string;
begin
    Result := False;
    if key_state.ctrl_down and (key_code = VK_SPACE) then
    begin
        Result := m_config.enable_ctrl_space_toggle;
        Exit;
    end;

    if key_state.shift_down and (key_code = VK_SPACE) then
    begin
        Result := m_config.enable_shift_space_full_width_toggle;
        Exit;
    end;

    if key_state.ctrl_down and (key_code = VK_OEM_PERIOD) then
    begin
        Result := m_config.enable_ctrl_period_punct_toggle;
        Exit;
    end;

    if key_state.ctrl_down or key_state.alt_down then
    begin
        Exit(False);
    end;

    if m_config.input_mode = im_english then
    begin
        Result := get_direct_ascii_commit_text(key_code, key_state, direct_commit_text);
        Exit;
    end;

    if is_alpha_key(key_code, key_state, key_char, display_key_char) then
    begin
        Result := True;
        Exit;
    end;

    if get_punctuation_char(key_code, key_state, punct_char) then
    begin
        if m_composition_text <> '' then
        begin
            Result := True;
        end
        else
        begin
            Result := get_effective_punctuation_full_width or m_config.full_width_mode;
        end;
        Exit;
    end;

    has_candidates := Length(m_candidates) > 0;
    if (m_composition_text = '') and (m_confirmed_text = '') and (not has_candidates) and (not m_has_pending_commit) then
    begin
        Exit(False);
    end;

    if (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        if (key_code = VK_ADD) or (key_code = VK_SUBTRACT) or (key_code = VK_OEM_PLUS) or (key_code = VK_OEM_MINUS) then
        begin
            if (m_composition_text <> '') or (m_confirmed_text <> '') then
            begin
                Result := True;
                Exit;
            end;
        end;
    end;

    if (m_composition_text <> '') and (not key_state.shift_down) and (not key_state.ctrl_down) and (not key_state.alt_down) then
    begin
        case key_code of
            VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN:
                begin
                    Result := True;
                    Exit;
                end;
        end;
    end;

    case key_code of
        VK_BACK,
        VK_OEM_7,
        VK_ESCAPE,
        VK_SPACE,
        VK_RETURN,
        VK_PRIOR,
        VK_NEXT:
            Result := True;
        Ord('1')..Ord('9'):
            Result := True;
    end;
end;

function TncEngine.commit_text(out out_text: string): Boolean;
var
    normalized_pinyin: string;
    full_pinyin: string;
    segment: TncConfirmedSegment;
    prev_left_context: string;
    commit_text: string;
    commit_segment_text: string;
    commit_segment_path: string;
    effective_segment_path: string;
    inferred_segment_path: string;
    allow_learning: Boolean;
    path_segments: TArray<string>;
    path_idx: Integer;
    path_start: Integer;
    path_text: string;
    combined_segment_path: string;
    confirmed_pinyin_prefix: string;
    confirmed_segment_path_prefix: string;

    function get_path_segment_count(const encoded_path: string): Integer;
    var
        idx: Integer;
        trimmed_path: string;
    begin
        trimmed_path := Trim(encoded_path);
        if trimmed_path = '' then
        begin
            Exit(0);
        end;

        Result := 1;
        for idx := 1 to Length(trimmed_path) do
        begin
            if trimmed_path[idx] = c_segment_path_separator then
            begin
                Inc(Result);
            end;
        end;
    end;

    function is_high_confidence_segment_path(const encoded_path: string): Boolean;
    var
        idx: Integer;
        segment_start: Integer;
        segment_text: string;
        has_multi_char_segment: Boolean;
    begin
        Result := False;
        if get_path_segment_count(encoded_path) <= 1 then
        begin
            Exit;
        end;

        has_multi_char_segment := False;
        segment_start := 1;
        for idx := 1 to Length(encoded_path) + 1 do
        begin
            if (idx <= Length(encoded_path)) and (encoded_path[idx] <> c_segment_path_separator) then
            begin
                Continue;
            end;

            segment_text := Trim(Copy(encoded_path, segment_start, idx - segment_start));
            if segment_text <> '' then
            begin
                if get_candidate_text_unit_count(segment_text) >= 2 then
                begin
                    has_multi_char_segment := True;
                    Break;
                end;
            end;
            segment_start := idx + 1;
        end;

        Result := has_multi_char_segment;
    end;

    procedure append_path_segment(const segment_text: string);
    var
        segment_index: Integer;
    begin
        path_text := Trim(segment_text);
        if path_text = '' then
        begin
            Exit;
        end;
        segment_index := Length(path_segments);
        SetLength(path_segments, segment_index + 1);
        path_segments[segment_index] := path_text;
        if combined_segment_path <> '' then
        begin
            combined_segment_path := combined_segment_path + c_segment_path_separator;
        end;
        combined_segment_path := combined_segment_path + path_text;
    end;

    procedure record_query_path_prefixes(const base_query_prefix: string; const base_path_prefix: string;
        const tail_full_path: string; const final_query: string; const final_path: string);
    var
        idx: Integer;
        prefix_start: Integer;
        segment_piece: string;
        prefix_path: string;
        prefix_query: string;
        combined_query: string;
        combined_path: string;
    begin
        if (m_dictionary = nil) or (tail_full_path = '') then
        begin
            Exit;
        end;

        prefix_path := '';
        prefix_start := 1;
        for idx := 1 to Length(tail_full_path) + 1 do
        begin
            if (idx <= Length(tail_full_path)) and (tail_full_path[idx] <> c_segment_path_separator) then
            begin
                Continue;
            end;

            segment_piece := Trim(Copy(tail_full_path, prefix_start, idx - prefix_start));
            prefix_start := idx + 1;
            if segment_piece = '' then
            begin
                Continue;
            end;

            if prefix_path <> '' then
            begin
                prefix_path := prefix_path + c_segment_path_separator;
            end;
            prefix_path := prefix_path + segment_piece;

            if get_path_segment_count(prefix_path) <= 1 then
            begin
                Continue;
            end;

            prefix_query := get_query_prefix_for_segment_path(prefix_path);
            if prefix_query = '' then
            begin
                Continue;
            end;

            combined_query := base_query_prefix + prefix_query;
            combined_path := prefix_path;
            if base_path_prefix <> '' then
            begin
                combined_path := base_path_prefix + c_segment_path_separator + combined_path;
            end;

            if (combined_query = '') or (combined_path = '') or
                ((combined_query = final_query) and (combined_path = final_path)) then
            begin
                Continue;
            end;

            m_dictionary.record_query_segment_path(combined_query, combined_path);
        end;
    end;

    procedure note_session_query_path_prefixes(const base_query_prefix: string; const base_path_prefix: string;
        const tail_full_path: string; const final_query: string; const final_path: string);
    var
        idx: Integer;
        prefix_start: Integer;
        segment_piece: string;
        prefix_path: string;
        prefix_query: string;
        combined_query: string;
        combined_path: string;
    begin
        if tail_full_path = '' then
        begin
            Exit;
        end;

        prefix_path := '';
        prefix_start := 1;
        for idx := 1 to Length(tail_full_path) + 1 do
        begin
            if (idx <= Length(tail_full_path)) and (tail_full_path[idx] <> c_segment_path_separator) then
            begin
                Continue;
            end;

            segment_piece := Trim(Copy(tail_full_path, prefix_start, idx - prefix_start));
            prefix_start := idx + 1;
            if segment_piece = '' then
            begin
                Continue;
            end;

            if prefix_path <> '' then
            begin
                prefix_path := prefix_path + c_segment_path_separator;
            end;
            prefix_path := prefix_path + segment_piece;

            if get_path_segment_count(prefix_path) <= 1 then
            begin
                Continue;
            end;

            prefix_query := get_query_prefix_for_segment_path(prefix_path);
            if prefix_query = '' then
            begin
                Continue;
            end;

            combined_query := base_query_prefix + prefix_query;
            combined_path := prefix_path;
            if base_path_prefix <> '' then
            begin
                combined_path := base_path_prefix + c_segment_path_separator + combined_path;
            end;

            if (combined_query = '') or (combined_path = '') or
                ((combined_query = final_query) and (combined_path = final_path)) then
            begin
                Continue;
            end;

            note_session_query_path_choice(combined_query, combined_path);
        end;
    end;
begin
    out_text := '';
    if not m_has_pending_commit then
    begin
        Result := False;
        Exit;
    end;

    commit_segment_text := m_pending_commit_text;
    commit_segment_path := m_pending_commit_segment_path;
    commit_text := commit_segment_text;
    if m_confirmed_text <> '' then
    begin
        commit_text := m_confirmed_text + commit_text;
    end;

    out_text := commit_text;
    allow_learning := m_pending_commit_allow_learning;
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_pending_commit_segment_path := '';
    normalized_pinyin := m_pending_commit_query_key;
    m_pending_commit_query_key := '';
    prev_left_context := m_left_context;
    if m_segment_left_context <> '' then
    begin
        prev_left_context := m_segment_left_context;
    end
    else if (prev_left_context = '') and (m_external_left_context <> '') then
    begin
        prev_left_context := m_external_left_context;
    end;
    update_left_context(out_text);
    if normalized_pinyin = '' then
    begin
        normalized_pinyin := normalize_pinyin_text(m_last_lookup_key);
    end;
    if normalized_pinyin = '' then
    begin
        normalized_pinyin := normalize_pinyin_text(m_composition_text);
    end;
    full_pinyin := '';
    effective_segment_path := commit_segment_path;
    if allow_learning and (commit_segment_text <> '') and (normalized_pinyin <> '') then
    begin
        inferred_segment_path := infer_segment_path_for_selected_text(commit_segment_text);
        if inferred_segment_path <> '' then
        begin
            if (effective_segment_path = '') or
                ((get_path_segment_count(inferred_segment_path) > 1) and
                ((get_path_segment_count(effective_segment_path) <= 1) or
                (get_path_segment_count(inferred_segment_path) < get_path_segment_count(effective_segment_path)))) then
            begin
                effective_segment_path := inferred_segment_path;
            end;
        end;
    end;
    if (not allow_learning) and (commit_segment_text <> '') and
        (get_candidate_text_unit_count(commit_segment_text) >= 4) and
        is_high_confidence_segment_path(effective_segment_path) then
    begin
        // Segment-decoded multi-phrase commits should still participate in learning
        // when the inferred path contains at least one real multi-char chunk.
        allow_learning := True;
    end;
    if m_confirmed_segments <> nil then
    begin
        for segment in m_confirmed_segments do
        begin
            full_pinyin := full_pinyin + segment.pinyin;
            append_path_segment(segment.text);
        end;
    end;
    confirmed_pinyin_prefix := full_pinyin;
    confirmed_segment_path_prefix := combined_segment_path;
    full_pinyin := full_pinyin + normalized_pinyin;
    if effective_segment_path <> '' then
    begin
        path_start := 1;
        for path_idx := 1 to Length(effective_segment_path) + 1 do
        begin
            if (path_idx <= Length(effective_segment_path)) and
                (effective_segment_path[path_idx] <> c_segment_path_separator) then
            begin
                Continue;
            end;

            append_path_segment(Copy(effective_segment_path, path_start, path_idx - path_start));
            path_start := path_idx + 1;
        end;
    end
    else if commit_segment_text <> '' then
    begin
        append_path_segment(commit_segment_text);
    end;
    if m_dictionary <> nil then
    begin
        m_dictionary.begin_learning_batch;
        try
            record_context_pair(prev_left_context, out_text);
            if allow_learning then
            begin
                if Length(path_segments) > 1 then
                begin
                    for path_idx := 1 to High(path_segments) do
                    begin
                        record_context_pair(path_segments[path_idx - 1], path_segments[path_idx]);
                    end;
                    if Length(path_segments) > 2 then
                    begin
                        for path_idx := 2 to High(path_segments) do
                        begin
                            m_dictionary.record_context_trigram(
                                path_segments[path_idx - 2],
                                path_segments[path_idx - 1],
                                path_segments[path_idx]);
                        end;
                    end;
                end;

                if (normalized_pinyin <> '') and (commit_segment_text <> '') then
                begin
                    m_dictionary.record_commit(normalized_pinyin, commit_segment_text);
                    if get_path_segment_count(effective_segment_path) > 1 then
                    begin
                        record_query_path_prefixes('', '', effective_segment_path,
                            normalized_pinyin, effective_segment_path);
                        m_dictionary.record_query_segment_path(normalized_pinyin, effective_segment_path);
                    end;
                end;

                if commit_text <> '' then
                begin
                    if (full_pinyin <> '') and
                        ((full_pinyin <> normalized_pinyin) or (commit_text <> commit_segment_text)) then
                    begin
                        m_dictionary.record_commit(full_pinyin, commit_text);
                        if get_path_segment_count(combined_segment_path) > 1 then
                        begin
                            record_query_path_prefixes(
                                confirmed_pinyin_prefix,
                                confirmed_segment_path_prefix,
                                effective_segment_path,
                                full_pinyin,
                                combined_segment_path);
                            m_dictionary.record_query_segment_path(full_pinyin, combined_segment_path);
                        end;
                    end;
                end;
            end;
            m_dictionary.commit_learning_batch;
        except
            m_dictionary.rollback_learning_batch;
            raise;
        end;
    end
    else
    begin
        record_context_pair(prev_left_context, out_text);
    end;
    if commit_segment_text <> '' then
    begin
        note_session_commit(commit_segment_text);
    end;
    if (commit_text <> '') and (commit_text <> commit_segment_text) then
    begin
        note_session_commit(commit_text);
    end;
    if allow_learning then
    begin
        if (normalized_pinyin <> '') and (commit_segment_text <> '') then
        begin
            note_session_query_choice(normalized_pinyin, commit_segment_text);
            note_session_context_query_choice(prev_left_context, normalized_pinyin, commit_segment_text);
            if get_path_segment_count(effective_segment_path) > 1 then
            begin
                note_session_query_path_prefixes('', '', effective_segment_path,
                    normalized_pinyin, effective_segment_path);
                note_session_query_path_choice(normalized_pinyin, effective_segment_path);
            end;
        end;
        if (full_pinyin <> '') and ((full_pinyin <> normalized_pinyin) or (commit_text <> commit_segment_text)) and
            (commit_text <> '') then
        begin
            note_session_query_choice(full_pinyin, commit_text);
            note_session_context_query_choice(prev_left_context, full_pinyin, commit_text);
            if get_path_segment_count(combined_segment_path) > 1 then
            begin
                note_session_query_path_prefixes(
                    confirmed_pinyin_prefix,
                    confirmed_segment_path_prefix,
                    effective_segment_path,
                    full_pinyin,
                    combined_segment_path);
                note_session_query_path_choice(full_pinyin, combined_segment_path);
            end;
        end;
    end;
    if commit_text <> '' then
    begin
        note_output_phrase_context(commit_text);
    end;
    if allow_learning and (Length(path_segments) > 1) then
    begin
        note_segment_path_context(combined_segment_path);
    end;
    m_last_debug_commit_segment_path := combined_segment_path;
    m_confirmed_text := '';
    m_recent_partial_prefix_text := '';
    m_segment_left_context := '';
    if m_confirmed_segments <> nil then
    begin
        m_confirmed_segments.Clear;
    end;
    reset;
    Result := True;
end;

function TncEngine.remove_user_candidate(const pinyin: string; const text: string): Boolean;
var
    pinyin_key: string;
    candidate_text: string;
    confirmed_pinyin: string;
    full_query: string;
    full_candidates: TncCandidateList;
    full_text: string;
    extension_text: string;
    idx: Integer;
    seg_idx: Integer;
    removed_confirmed_extension: Boolean;
begin
    Result := False;
    candidate_text := Trim(text);
    pinyin_key := normalize_pinyin_text(pinyin);
    if pinyin_key = '' then
    begin
        pinyin_key := normalize_pinyin_text(m_composition_text);
    end;

    if (m_dictionary = nil) or (candidate_text = '') then
    begin
        Exit;
    end;

    removed_confirmed_extension := False;
    if (m_confirmed_text <> '') and (m_confirmed_segments <> nil) and (m_confirmed_segments.Count > 0) and
        (m_composition_text <> '') then
    begin
        confirmed_pinyin := '';
        for seg_idx := 0 to m_confirmed_segments.Count - 1 do
        begin
            if m_confirmed_segments[seg_idx].pinyin <> '' then
            begin
                confirmed_pinyin := confirmed_pinyin + normalize_pinyin_text(m_confirmed_segments[seg_idx].pinyin);
            end;
        end;

        if confirmed_pinyin <> '' then
        begin
            full_query := confirmed_pinyin + normalize_pinyin_text(m_composition_text);
            if (full_query <> '') and m_dictionary.lookup(full_query, full_candidates) then
            begin
                for idx := 0 to High(full_candidates) do
                begin
                    if full_candidates[idx].source <> cs_user then
                    begin
                        Continue;
                    end;

                    full_text := Trim(full_candidates[idx].text);
                    if (full_text = '') or (Length(full_text) <= Length(m_confirmed_text)) then
                    begin
                        Continue;
                    end;
                    if Copy(full_text, 1, Length(m_confirmed_text)) <> m_confirmed_text then
                    begin
                        Continue;
                    end;

                    extension_text := Trim(Copy(full_text, Length(m_confirmed_text) + 1, MaxInt));
                    if not SameText(extension_text, candidate_text) then
                    begin
                        Continue;
                    end;

                    m_dictionary.remove_user_entry(full_query, full_text);
                    removed_confirmed_extension := True;
                end;
            end;
        end;
    end;

    if not removed_confirmed_extension then
    begin
        m_dictionary.remove_user_entry(pinyin_key, candidate_text);
    end;

    if m_composition_text <> '' then
    begin
        build_candidates;
    end;

    Result := True;
end;

end.
