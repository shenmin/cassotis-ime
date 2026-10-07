unit nc_dictionary_sqlite;

interface

uses
    System.SysUtils,
    System.Math,
    System.DateUtils,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.Character,
    System.IOUtils,
    Winapi.Windows,
    nc_types,
    nc_dictionary_intf,
    nc_fuzzy_pinyin,
    nc_pinyin_parser,
    nc_exact_component_sort,
    nc_sqlite;

type
    TncCharLmCacheEntry = record
        found: Boolean;
        score: Integer;
        backoff: Integer;
    end;

    TncSqliteDictionary = class(TncDictionaryProvider)
    private
        m_base_db_path: string;
        m_user_db_path: string;
        m_ready: Boolean;
        m_base_ready: Boolean;
        m_base_connection_read_only: Boolean;
        m_user_ready: Boolean;
        m_user_initialization_deferred: Boolean;
        m_defer_optional_model_loads: Boolean;
        m_prune_user_entries_on_open: Boolean;
        m_limit: Integer;
        m_bigram_prune_countdown: Integer;
        m_trigram_prune_countdown: Integer;
        m_query_path_prune_countdown: Integer;
        m_query_path_penalty_prune_countdown: Integer;
        m_context_query_choice_prune_countdown: Integer;
        m_write_batch_depth: Integer;
        m_base_connection: TncSqliteConnection;
        m_user_connection: TncSqliteConnection;
        m_user_script_enabled: Boolean;
        m_user_script_variant: TncDictionaryVariant;
        m_user_script_cache: TDictionary<string, string>;
        m_user_storage_text_cache: TDictionary<string, string>;
        m_contains_popularity_cache: TDictionary<string, Integer>;
        m_prefix_popularity_cache: TDictionary<string, Integer>;
        m_pinyin_followup_popularity_cache: TDictionary<string, Integer>;
        m_base_text_prefix_bonus_cache: TDictionary<string, Integer>;
        m_single_char_weight_cache: TDictionary<string, Integer>;
        m_context_bonus_cache: TDictionary<string, Integer>;
        m_query_choice_bonus_cache: TDictionary<string, Integer>;
        m_context_query_choice_bonus_cache: TDictionary<string, Integer>;
        m_query_latest_choice_text_cache: TDictionary<string, string>;
        m_query_path_bonus_cache: TDictionary<string, Integer>;
        m_query_path_bonus_cache_loaded: Boolean;
        m_base_query_path_pinyin_cache: TDictionary<string, Boolean>;
        m_base_query_path_pinyin_cache_loaded: Boolean;
        m_lm_transition_bonus_cache: TDictionary<string, Integer>;
        m_exact_pair_path_evidence_cache:
            TDictionary<string, TncPairPathEvidenceList>;
        m_lm_transition_cache_loaded: Boolean;
        m_char_lm_entry_cache: TDictionary<string, TncCharLmCacheEntry>;
        m_char_lm_cache_order: TQueue<string>;
        m_char_lm_text_score_cache: TDictionary<string, Integer>;
        m_char_lm_text_score_cache_order: TQueue<string>;
        m_char_lm_short_context_text_score_cache:
            TDictionary<string, Integer>;
        m_char_lm_short_context_text_score_cache_order: TQueue<string>;
        m_char_lm_available: Integer;
        m_stmt_char_lm_entries_1: Psqlite3_stmt;
        m_stmt_char_lm_entries_8: Psqlite3_stmt;
        m_stmt_char_lm_entries_16: Psqlite3_stmt;
        m_stmt_char_lm_entries_32: Psqlite3_stmt;
        m_stmt_char_lm_entries_64: Psqlite3_stmt;
        m_stmt_char_lm_entries_128: Psqlite3_stmt;
        m_stmt_char_lm_entries_256: Psqlite3_stmt;
        m_stmt_char_lm_entries_400: Psqlite3_stmt;
        m_char_reverse_lm_entry_cache: TDictionary<string, TncCharLmCacheEntry>;
        m_char_reverse_lm_cache_order: TQueue<string>;
        m_char_reverse_lm_text_score_cache: TDictionary<string, Integer>;
        m_char_reverse_lm_text_score_cache_order: TQueue<string>;
        m_char_reverse_lm_available: Integer;
        m_stmt_char_reverse_lm_entries_1: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_8: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_16: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_32: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_64: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_128: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_256: Psqlite3_stmt;
        m_stmt_char_reverse_lm_entries_400: Psqlite3_stmt;
        m_compound_tail_support_cache: TDictionary<string, Integer>;
        m_stmt_context_bonus: Psqlite3_stmt;
        m_stmt_context_trigram_bonus: Psqlite3_stmt;
        m_stmt_base_query_path_bonus: Psqlite3_stmt;
        m_stmt_exact_pair_path_evidence: Psqlite3_stmt;
        m_stmt_compound_tail_support: Psqlite3_stmt;
        m_stmt_compound_tail_prefix_support: Psqlite3_stmt;
        m_stmt_compound_tail_prefix_range_support: Psqlite3_stmt;
        m_stmt_prefix_popularity: Psqlite3_stmt;
        m_stmt_pinyin_followup_popularity: Psqlite3_stmt;
        m_stmt_contains_popularity: Psqlite3_stmt;
        m_stmt_base_text_prefix_bonus: Psqlite3_stmt;
        m_stmt_single_char_exact_weight: Psqlite3_stmt;
        m_stmt_query_choice_bonus: Psqlite3_stmt;
        m_stmt_context_query_choice_bonus: Psqlite3_stmt;
        m_stmt_query_latest_choice_text: Psqlite3_stmt;
        m_stmt_query_path_bonus: Psqlite3_stmt;
        m_stmt_query_path_penalty: Psqlite3_stmt;
        m_stmt_candidate_penalty: Psqlite3_stmt;
        m_stmt_exact_base: Psqlite3_stmt;
        m_stmt_exact_base_alias: Psqlite3_stmt;
        m_stmt_exact_user: Psqlite3_stmt;
        m_stmt_exact_component_base: Psqlite3_stmt;
        m_stmt_exact_component_base_alias: Psqlite3_stmt;
        m_stmt_exact_component_user: Psqlite3_stmt;
        m_stmt_exact_admin_prefix: Psqlite3_stmt;
        m_stmt_lookup_base: Psqlite3_stmt;
        m_stmt_lookup_single_char_exact: Psqlite3_stmt;
        m_stmt_record_context_pair_update: Psqlite3_stmt;
        m_stmt_record_context_pair_insert: Psqlite3_stmt;
        m_stmt_record_context_trigram_update: Psqlite3_stmt;
        m_stmt_record_context_trigram_insert: Psqlite3_stmt;
        m_stmt_record_query_path_update: Psqlite3_stmt;
        m_stmt_record_query_path_insert: Psqlite3_stmt;
        m_query_path_penalty_cache: TDictionary<string, Integer>;
        m_candidate_penalty_cache: TDictionary<string, Integer>;
        m_candidate_penalty_pinyin_loaded_cache: TDictionary<string, Boolean>;
        m_lookup_result_cache: TDictionary<string, TncCandidateList>;
        m_mixed_abbreviation_cache: TDictionary<string, TncCandidateList>;
        m_word_completion_cache: TDictionary<string, TncOneKeyCompletionList>;
        m_next_character_cache: TDictionary<string, TArray<string>>;
        m_lookup_result_cache_order: TQueue<string>;
        m_exact_lookup_result_cache: TDictionary<string, TncCandidateList>;
        m_exact_lookup_result_cache_order: TQueue<string>;
        m_exact_component_lookup_cache: TDictionary<string, TncCandidateList>;
        m_exact_component_lookup_cache_order: TQueue<string>;
        m_base_exact_pinyin_bloom: TBytes;
        m_base_exact_pinyin_bloom_ready: Boolean;
        m_prefix_lookup_result_cache: TDictionary<string, TncCandidateList>;
        m_candidate_prefix_completion_cache:
            TDictionary<string, TncOneKeyCompletionList>;
        m_one_key_completion_cache:
            TDictionary<string, TncOneKeyCompletionList>;
        m_long_one_key_completion_cache:
            TDictionary<string, TncLongOneKeyCompletionList>;
        m_one_key_completion_competition_cache:
            TDictionary<string, TncOneKeyCompletionCompetitionEvidenceList>;
        m_one_key_completion_pair_audit_cache:
            TDictionary<string, TncOneKeyCompletionPairAudit>;
        // pinyin, baseline text -> promoted text, lead ('' when there is none).
        m_short_promotion_cache: TDictionary<string, string>;
        m_exact_text_prefix_cache: TDictionary<string, TncExactTextPath>;
        m_literal_lookup_result_cache: TDictionary<string, TncCandidateList>;
        m_literal_user_words_available: Integer;
        m_exact_base_entry_cache: TDictionary<string, Boolean>;
        m_normalized_base_entry_cache: TDictionary<string, Boolean>;
        m_explicit_user_entry_cache: TDictionary<string, Boolean>;
        m_literal_user_entry_cache: TDictionary<string, Boolean>;
        m_admin_place_longer_prefix_cache: TDictionary<string, TArray<string>>;
        m_admin_place_query_syllable_count_cache: TDictionary<string, Integer>;
        m_fuzzy_pinyin_enabled: Boolean;
        m_fuzzy_pinyin_rules: TncFuzzyPinyinRules;
        m_fuzzy_lookup_result_cache: TDictionary<string, TncCandidateList>;
        m_fuzzy_lookup_result_cache_order: TQueue<string>;
        m_fuzzy_choice_bonus_cache: TDictionary<string, Integer>;
        m_fuzzy_choice_query_loaded_cache: TDictionary<string, Boolean>;
        m_debug_mode: Boolean;
        m_last_lookup_debug_hint: string;
        m_short_lookup_cache_prewarmed: Boolean;
        m_user_data_version: Integer;
        m_last_user_data_version_check_tick: UInt64;
        m_process_user_data_generation: Integer;
        m_contains_popularity_index_checked: Boolean;
        m_contains_popularity_index_ready: Boolean;
        function user_text_for_script(const pinyin, text: string): string;
        function user_storage_text(const table_name, pinyin, text: string): string;
        function ensure_open: Boolean;
        function open_internal(const defer_optional_model_loads: Boolean): Boolean;
        procedure open_user_connection;
        function get_module_dir: string;
        function find_schema_path: string;
        function load_schema_text(out schema_text: string): Boolean;
        function ensure_schema(const connection: TncSqliteConnection): Boolean;
        function get_schema_version(const connection: TncSqliteConnection; out version: Integer): Boolean;
        procedure set_schema_version(const connection: TncSqliteConnection; const version: Integer);
        function get_valid_cjk_codepoint_count(const text: string): Integer;
        function is_valid_learning_text(const text: string): Boolean;
        function is_valid_user_text(const text: string): Boolean;
        function is_valid_learning_path(const encoded_path: string): Boolean;
        function get_contains_popularity_score(const token: string): Integer;
        function get_prefix_popularity_score(const prefix: string): Integer;
        function get_pinyin_followup_popularity_score(const pinyin: string): Integer;
        procedure populate_prefix_popularity_scores(const prefixes: TArray<string>;
            const target_scores: TDictionary<string, Integer>);
        procedure populate_pinyin_followup_popularity_scores(const pinyin_keys: TArray<string>;
            const target_scores: TDictionary<string, Integer>);
        function get_single_char_exact_weight(const pinyin: string; const text_unit: string): Integer;
        function get_top_single_char_exact_weight(const pinyin: string): Integer;
        function should_ignore_weak_single_char_query_choice(const pinyin: string;
            const text_unit: string; const commit_count: Integer): Boolean;
        function get_user_entry_count(const connection: TncSqliteConnection; out count: Integer): Boolean;
        procedure migrate_user_entries;
        function exact_base_entry_exists(const pinyin: string; const text: string): Boolean;
        function normalized_base_entry_exists(const pinyin: string; const text: string): Boolean;
        function try_get_single_char_full_pinyin_for_prefix(const prefix_pinyin: string;
            const text: string; out full_pinyin: string): Boolean;
        function has_any_base_phrase_for_pinyin(const pinyin: string): Boolean;
        function explicit_user_entry_exists(const pinyin: string; const text: string): Boolean;
        function split_full_pinyin_syllables(const pinyin: string): TArray<string>;
        function strict_full_pinyin_text_alignment_valid(const pinyin: string;
            const text: string): Boolean;
        function full_pinyin_text_alignment_valid(const pinyin: string;
            const text: string): Boolean;
        function is_whitelisted_constructed_phrase(const pinyin: string; const text: string): Boolean;
        function is_nonbase_multiword_composed_exact_phrase(const pinyin: string;
            const text: string): Boolean;
        function is_nonbase_multi_segment_composed_exact_phrase(const pinyin: string;
            const text: string): Boolean;
        function is_nonbase_structured_rule_exact_phrase(const pinyin: string;
            const text: string): Boolean;
        function is_suppressible_nonbase_exact_phrase(const pinyin: string; const text: string): Boolean;
        function is_likely_noisy_constructed_phrase(const pinyin: string; const text: string;
            const commit_count: Integer = 0; const user_weight: Integer = 0): Boolean;
        function should_suppress_constructed_user_phrase(const pinyin: string; const text: string;
            const commit_count: Integer = 0; const user_weight: Integer = 0): Boolean;
        procedure configure_base_connection;
        procedure configure_user_connection;
        procedure load_base_exact_pinyin_bloom;
        function base_exact_pinyin_may_exist(const pinyin: string): Boolean;
        procedure load_base_query_path_pinyin_cache;
        procedure load_query_path_bonus_cache;
        function base_query_path_pinyin_may_exist(
            const query_key: string): Boolean;
        procedure load_lm_transition_bonus_cache;
        function ensure_char_lm_available(
            const reverse_model: Boolean = False): Boolean;
        procedure cache_char_lm_entry(const ngram: string;
            const entry: TncCharLmCacheEntry;
            const reverse_model: Boolean = False);
        procedure cache_char_lm_text_score(const cache_key: string;
            const score: Integer; const reverse_model: Boolean = False;
            const short_context_cache: Boolean = False);
        function load_char_lm_entries(const ngrams: TArray<string>;
            const entries: TDictionary<string, TncCharLmCacheEntry>;
            const reverse_model: Boolean = False): Boolean;
        function get_char_lm_text_scores_internal(const texts: TArray<string>;
            out scores: TArray<Integer>; const include_begin_marker: Boolean;
            const left_context: string; const include_end_marker: Boolean;
            const cache_only: Boolean = False;
            const reverse_model: Boolean = False;
            const short_context_cache: Boolean = False): Boolean;
        function get_char_lm_cached_scores_internal(
            const texts: TArray<string>; out scores: TArray<Integer>;
            const include_end_marker: Boolean;
            const reverse_model: Boolean): Boolean;
        procedure purge_user_entry_internal(const pinyin: string; const text: string;
            const apply_penalty: Boolean; const purge_all_by_text: Boolean);
        procedure prune_user_entries_existing_in_base;
        procedure prune_suspicious_user_entries;
        procedure prune_bigram_rows_if_needed(const force: Boolean);
        procedure prune_trigram_rows_if_needed(const force: Boolean);
        procedure prune_query_path_rows_if_needed(const force: Boolean);
        procedure prune_query_path_penalty_rows_if_needed(const force: Boolean);
        procedure prune_context_query_choice_rows_if_needed(
            const force: Boolean);
        procedure clear_cached_user_statements;
        procedure clear_user_read_caches;
        procedure clear_dictionary_lookup_caches;
        procedure note_user_data_changed;
        function read_user_data_version(out version: Integer): Boolean;
        procedure refresh_user_data_version_if_changed(const force: Boolean);
        procedure populate_candidate_penalty_cache_for_pinyin(const pinyin_key: string;
            const compact_pinyin_key: string);
        function lookup_exact_full_pinyin_internal(const pinyin: string;
            out results: TncCandidateList;
            const preserve_explicit_boundaries: Boolean): Boolean;
        function lookup_isolated_exact_component_internal(
            const pinyin: string; out results: TncCandidateList;
            const use_base_preflight: Boolean): Boolean;
        procedure load_fuzzy_choice_bonuses(const pinyin: string);
        function get_fuzzy_choice_bonus(const pinyin: string;
            const text: string): Integer;
    public
        constructor create(const base_db_path: string; const user_db_path: string;
            const prune_user_entries_on_open: Boolean = True);
        destructor Destroy; override;
        function open: Boolean;
        function open_deferred: Boolean;
        function reload_user_dictionary: Boolean;
        procedure set_user_dictionary_variant(const variant: TncDictionaryVariant);
        procedure close;
        procedure prewarm_short_lookup_caches;
        function get_prefix_popularity_hint(const prefix: string): Integer;
        function get_base_text_prefix_bonus(const prefix_text: string): Integer; override;
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; override;
        function lookup_exact_full_pinyin(const pinyin: string;
            out results: TncCandidateList): Boolean; override;
        function lookup_isolated_exact_component(const pinyin: string;
            out results: TncCandidateList): Boolean; override;
        function lookup_full_pinyin_prefix(const pinyin_prefix: string;
            out results: TncCandidateList): Boolean; override;
        function lookup_mixed_abbreviation_words(const pinyin: string;
            out results: TncCandidateList): Boolean; override;
        function lookup_word_completions(const syllables: TArray<string>;
            const max_syllables, limit: Integer;
            out results: TncOneKeyCompletionList): Boolean; override;
        function lookup_next_characters(const tail: string; const limit: Integer;
            out characters: TArray<string>): Boolean; override;
        function lookup_words_starting_with(const prefix: string;
            const min_length, max_length, limit: Integer;
            out results: TncOneKeyCompletionList): Boolean; override;
        function lookup_candidate_prefix_completions(const pinyin_prefix: string;
            out results: TncOneKeyCompletionList): Boolean; override;
        function lookup_one_key_completions(const pinyin_prefix: string;
            out results: TncOneKeyCompletionList): Boolean; override;
        function lookup_long_one_key_completions(const anchor_path: string;
            out results: TncLongOneKeyCompletionList): Boolean; override;
        function lookup_long_one_key_completions_by_text(
            const anchor_text: string;
            out results: TncLongOneKeyCompletionList): Boolean; override;
        function lookup_one_key_completion_competition(
            const pinyin_prefix: string; const left_context: string;
            out results: TncOneKeyCompletionCompetitionEvidenceList): Boolean; override;
        function lookup_one_key_completion_pair_audit(
            const pinyin_prefix, left_context: string;
            const baseline_full_pinyin, baseline_text: string;
            const challenger_full_pinyin, challenger_text: string;
            out audit: TncOneKeyCompletionPairAudit): Boolean; override;
        function lookup_short_promotion(const pinyin, baseline_text: string;
            out promoted_text: string; out lead: Integer): Boolean; override;
        function resolve_exact_text_prefix(const text: string;
            const max_segments, max_units: Integer;
            out resolved: TncExactTextPath): Boolean; override;
        procedure record_one_key_completion_accept(const typed_prefix: string;
            const full_pinyin: string; const text: string); override;
        procedure record_one_key_completion_reject(const typed_prefix: string;
            const full_pinyin: string; const text: string); override;
        procedure record_long_one_key_completion_accept(
            const anchor_path, suffix_text: string); override;
        procedure record_long_one_key_completion_reject(
            const anchor_path, suffix_text: string); override;
        function lookup_fuzzy_full_pinyin(const pinyin: string;
            out results: TncCandidateList): Boolean; override;
        function lookup_fuzzy_full_pinyin_bounded(const pinyin: string;
            out results: TncCandidateList; const max_cost: Integer;
            const max_variants: Integer;
            const max_syllables: Integer;
            const max_candidates_per_variant: Integer = 0): Boolean; override;
        function lookup_literal_user_words(const query: string;
            out results: TncCandidateList): Boolean; override;
        function resolve_literal_user_word_pinyin(const query: string;
            const text: string; out full_pinyin: string): Boolean; override;
        function record_literal_user_word(const full_pinyin: string;
            const text: string): Boolean; override;
        function single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean; override;
        function is_low_evidence_admin_place_alias_user_entry(const pinyin: string;
            const text: string; const latest_choice_text: string = '';
            const user_weight: Integer = -1; const commit_count: Integer = -1): Boolean; override;
        procedure begin_learning_batch; override;
        procedure commit_learning_batch; override;
        procedure rollback_learning_batch; override;
        procedure set_debug_mode(const enabled: Boolean); override;
        procedure set_fuzzy_pinyin_config(const enabled: Boolean;
            const rules: TncFuzzyPinyinRules); override;
        procedure record_fuzzy_choice(const pinyin: string;
            const text: string); override;
        procedure record_commit(const pinyin: string; const text: string;
            const explicit_choice: Boolean = False); override;
        procedure record_context_pair(const left_text: string; const committed_text: string); override;
        procedure record_context_trigram(const prev_prev_text: string; const prev_text: string;
            const committed_text: string); override;
        procedure record_context_query_choice(const context_suffix: string;
            const query_key: string; const candidate_text: string); override;
        procedure record_query_segment_path(const query_key: string; const encoded_path: string); override;
        procedure record_query_segment_path_penalty(const query_key: string; const encoded_path: string); override;
        procedure record_candidate_penalty(const pinyin: string; const text: string); override;
        function get_context_bonus(const left_text: string; const candidate_text: string): Integer; override;
        function get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
            const candidate_text: string): Integer; override;
        function get_context_query_choice_bonus(const context_suffix: string;
            const query_key: string; const candidate_text: string): Integer; override;
        function get_query_choice_bonus(const query_key: string; const candidate_text: string): Integer; override;
        function get_query_latest_choice_text(const query_key: string): string; override;
        function get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer; override;
        function get_long_query_segment_path_bonus(const query_key: string;
            const encoded_path: string): Integer; override;
        function get_lm_transition_bonus(const query_key: string; const encoded_path: string): Integer; override;
        function get_exact_pair_path_evidence(const query_key: string;
            out results: TncPairPathEvidenceList): Boolean; override;
        function get_char_lm_text_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; override;
        function get_char_lm_suffix_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; override;
        function get_char_lm_attested_scores(const ngrams: TArray<string>;
            out scores: TArray<Integer>): Boolean; override;
        function get_char_lm_parameters(const ngrams: TArray<string>;
            out scores, backoffs: TArray<Integer>;
            const reverse_model: Boolean = False): Boolean; override;
        function get_char_reverse_lm_suffix_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; override;
        function get_char_lm_cached_span_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; override;
        function get_char_lm_continuation_scores(const left_context: string;
            const texts: TArray<string>; out scores: TArray<Integer>): Boolean; override;
        function get_char_lm_short_context_scores(const left_context: string;
            const texts: TArray<string>; out scores: TArray<Integer>): Boolean; override;
        function get_query_segment_path_penalty(const query_key: string; const encoded_path: string): Integer; override;
        function get_compound_tail_support(const tail_text: string): Integer; override;
        function is_base_entry(const pinyin: string; const text: string): Boolean; override;
        function is_user_entry(const pinyin: string; const text: string): Boolean; override;
        function is_literal_user_entry(const query: string;
            const text: string): Boolean; override;
        function should_suppress_exact_query_learning(const pinyin: string; const text: string): Boolean; override;
        procedure remove_user_entry(const pinyin: string; const text: string); override;
        function clear_user_dictionary: Boolean; override;
        function get_candidate_penalty(const pinyin: string; const text: string): Integer; override;
        function get_last_lookup_debug_hint: string;
        property db_path: string read m_base_db_path;
        property user_db_path: string read m_user_db_path;
        property base_ready: Boolean read m_base_ready;
        property user_ready: Boolean read m_user_ready;
        property ready: Boolean read m_ready;
    end;

implementation

uses nc_chinese_script;

var
    g_user_data_generation: Integer;

const
    c_recent_explicit_user_choice_bonus = 1200;
    c_recent_explicit_user_choice_bonus_min = 200;

    // An additive reading is selectable, but is not another observation of the
    // same text. With no counted reading, retain one strongest curated row.
    c_base_text_evidence_scope_sql =
        '(b.contains_popularity_eligible <> 0 OR NOT EXISTS (' +
        'SELECT 1 FROM dict_base AS counted WHERE counted.text = b.text ' +
        'AND (counted.contains_popularity_eligible <> 0 ' +
        'OR counted.weight > b.weight ' +
        'OR (counted.weight = b.weight AND counted.id < b.id))))';

    default_schema_sql =
        'CREATE TABLE IF NOT EXISTS meta (' + sLineBreak +
        '    key TEXT PRIMARY KEY,' + sLineBreak +
        '    value TEXT NOT NULL' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'INSERT OR IGNORE INTO meta(key, value) VALUES(''schema_version'', ''24'');' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    comment TEXT DEFAULT '''',' + sLineBreak +
        '    contains_popularity_eligible INTEGER NOT NULL DEFAULT 1' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin ON dict_base(pinyin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_weight ON dict_base(pinyin, weight);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_text_weight ON dict_base(text, weight);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_completion_prior (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    popularity_prior INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    corpus_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    document_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    path_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    vertical_penalty INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    layer_kind INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_prior_pinyin ' +
        'ON dict_base_completion_prior(pinyin, popularity_prior DESC);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_completion_lookup (' + sLineBreak +
        '    typed_prefix TEXT NOT NULL,' + sLineBreak +
        '    full_pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    popularity_prior INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    corpus_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    document_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    path_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    vertical_penalty INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    layer_kind INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    prefix_anchored INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    rank_order INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(typed_prefix, full_pinyin, text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_lookup_prefix ' +
        'ON dict_base_completion_lookup(typed_prefix, rank_order);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_completion_competition (' + sLineBreak +
        '    context_width INTEGER NOT NULL,' + sLineBreak +
        '    context_suffix TEXT NOT NULL,' + sLineBreak +
        '    typed_prefix TEXT NOT NULL,' + sLineBreak +
        '    full_pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    evidence_score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    occurrence_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(context_width, context_suffix, typed_prefix, ' +
        'full_pinyin, text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_competition_query ' +
        'ON dict_base_completion_competition(typed_prefix, context_width, ' +
        'context_suffix, evidence_score DESC);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_completion_pair_audit (' + sLineBreak +
        '    context_width INTEGER NOT NULL,' + sLineBreak +
        '    context_suffix TEXT NOT NULL,' + sLineBreak +
        '    typed_prefix TEXT NOT NULL,' + sLineBreak +
        '    baseline_full_pinyin TEXT NOT NULL,' + sLineBreak +
        '    baseline_text TEXT NOT NULL,' + sLineBreak +
        '    challenger_full_pinyin TEXT NOT NULL,' + sLineBreak +
        '    challenger_text TEXT NOT NULL,' + sLineBreak +
        '    decision INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    keep_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    switch_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    keep_source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    switch_source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    confidence_milli INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(context_width, context_suffix, typed_prefix, ' +
        'baseline_full_pinyin, baseline_text, challenger_full_pinyin, ' +
        'challenger_text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_pair_audit_query ' +
        'ON dict_base_completion_pair_audit(typed_prefix, ' +
        'baseline_full_pinyin, baseline_text, challenger_full_pinyin, ' +
        'challenger_text, context_width DESC, context_suffix);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_short_promotion (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    baseline_text TEXT NOT NULL,' + sLineBreak +
        '    promoted_text TEXT NOT NULL,' + sLineBreak +
        '    lead INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, baseline_text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_pinyin_alias (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    compact_pinyin TEXT NOT NULL,' + sLineBreak +
        '    word_id INTEGER NOT NULL,' + sLineBreak +
        '    UNIQUE(compact_pinyin, word_id),' + sLineBreak +
        '    FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_alias_compact ' +
        'ON dict_base_pinyin_alias(compact_pinyin);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_jianpin (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    word_id INTEGER NOT NULL,' + sLineBreak +
        '    jianpin TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    UNIQUE(word_id, jianpin),' + sLineBreak +
        '    FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key ON dict_jianpin(jianpin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key_weight_word ON dict_jianpin(jianpin, weight DESC, word_id);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user (' + sLineBreak +
        '    id INTEGER PRIMARY KEY AUTOINCREMENT,' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    UNIQUE(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_pinyin ON dict_user(pinyin);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_literal (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    jianpin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    created_at INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_pinyin ON dict_user_literal(pinyin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_compact_pinyin ' +
        'ON dict_user_literal(REPLACE(pinyin, char(39), substr(pinyin, 1, 0)));' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_jianpin ON dict_user_literal(jianpin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_text ON dict_user_literal(text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_stats (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_stats_text ON dict_user_stats(text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_fuzzy_choice (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_fuzzy_choice_pinyin ' +
        'ON dict_user_fuzzy_choice(pinyin);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_query_latest (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL PRIMARY KEY,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_latest_text ON dict_user_query_latest(text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_context_query_choice (' + sLineBreak +
        '    context_suffix TEXT NOT NULL,' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(context_suffix, query_pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_context_query_choice_lookup ' +
        'ON dict_user_context_query_choice(context_suffix, query_pinyin);' + sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_context_query_choice_last_used ' +
        'ON dict_user_context_query_choice(last_used);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_completion_feedback (' + sLineBreak +
        '    typed_prefix TEXT NOT NULL,' + sLineBreak +
        '    full_pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    accept_count INTEGER DEFAULT 0,' + sLineBreak +
        '    reject_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(typed_prefix, full_pinyin, text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_completion_feedback_prefix ' +
        'ON dict_user_completion_feedback(typed_prefix, accept_count DESC, last_used DESC);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_long_completion_feedback (' + sLineBreak +
        '    anchor_path TEXT NOT NULL,' + sLineBreak +
        '    suffix_text TEXT NOT NULL,' + sLineBreak +
        '    accept_count INTEGER DEFAULT 0,' + sLineBreak +
        '    reject_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(anchor_path, suffix_text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_long_completion_feedback_anchor ' +
        'ON dict_user_long_completion_feedback(anchor_path, accept_count DESC, last_used DESC);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_penalty (' + sLineBreak +
        '    pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    penalty INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(pinyin, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_penalty_pinyin ON dict_user_penalty(pinyin);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_bigram (' + sLineBreak +
        '    left_text TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(left_text, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_bigram_left_text ON dict_user_bigram(left_text);' + sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_trigram (' + sLineBreak +
        '    prev_prev_text TEXT NOT NULL,' + sLineBreak +
        '    prev_text TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(prev_prev_text, prev_text, text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_trigram_prev_pair ON dict_user_trigram(prev_prev_text, prev_text);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_query_path (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    commit_count INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_query ON dict_user_query_path(query_pinyin);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_user_query_path_penalty (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    penalty INTEGER DEFAULT 0,' + sLineBreak +
        '    last_used INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_penalty_query ON dict_user_query_path_penalty(query_pinyin);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_query_path (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_query_path_query ON dict_base_query_path(query_pinyin);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_lm_transition (' + sLineBreak +
        '    query_pinyin TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    weight INTEGER DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(query_pinyin, path_text)' + sLineBreak +
        ');' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_lm_transition_query ' +
        'ON dict_base_lm_transition(query_pinyin);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_transition_completion (' + sLineBreak +
        '    typed_prefix TEXT NOT NULL,' + sLineBreak +
        '    full_pinyin TEXT NOT NULL,' + sLineBreak +
        '    text TEXT NOT NULL,' + sLineBreak +
        '    path_text TEXT NOT NULL,' + sLineBreak +
        '    evidence INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(typed_prefix, full_pinyin, text)' + sLineBreak +
        ') WITHOUT ROWID;' +
        sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_transition_completion_prefix ' +
        'ON dict_base_transition_completion(typed_prefix, evidence DESC);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_long_completion (' + sLineBreak +
        '    anchor_path TEXT NOT NULL,' + sLineBreak +
        '    suffix_pinyin TEXT NOT NULL,' + sLineBreak +
        '    suffix_text TEXT NOT NULL,' + sLineBreak +
        '    suffix_path TEXT NOT NULL,' + sLineBreak +
        '    evidence INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(anchor_path, suffix_pinyin, suffix_text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_long_completion_anchor ' +
        'ON dict_base_long_completion(anchor_path, evidence DESC, source_count DESC);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_long_completion_text (' + sLineBreak +
        '    anchor_text TEXT NOT NULL,' + sLineBreak +
        '    anchor_path TEXT NOT NULL,' + sLineBreak +
        '    suffix_pinyin TEXT NOT NULL,' + sLineBreak +
        '    suffix_text TEXT NOT NULL,' + sLineBreak +
        '    suffix_path TEXT NOT NULL,' + sLineBreak +
        '    evidence INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    source_count INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    PRIMARY KEY(anchor_text, anchor_path, suffix_pinyin, suffix_text)' + sLineBreak +
        ') WITHOUT ROWID;' + sLineBreak +
        sLineBreak +
        'CREATE INDEX IF NOT EXISTS idx_dict_base_long_completion_text_anchor ' +
        'ON dict_base_long_completion_text(anchor_text, evidence DESC, source_count DESC);' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_char_lm (' + sLineBreak +
        '    ngram TEXT NOT NULL PRIMARY KEY,' + sLineBreak +
        '    score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    backoff INTEGER NOT NULL DEFAULT 0' + sLineBreak +
        ') WITHOUT ROWID;' +
        sLineBreak +
        sLineBreak +
        'CREATE TABLE IF NOT EXISTS dict_base_char_reverse_lm (' + sLineBreak +
        '    ngram TEXT NOT NULL PRIMARY KEY,' + sLineBreak +
        '    score INTEGER NOT NULL DEFAULT 0,' + sLineBreak +
        '    backoff INTEGER NOT NULL DEFAULT 0' + sLineBreak +
        ') WITHOUT ROWID;' +
        sLineBreak;

type
    TncMixedQueryTokenKind = (mqt_full, mqt_initial);
    TncMixedQueryToken = record
        kind: TncMixedQueryTokenKind;
        text: string;
    end;
    TncMixedQueryTokenList = array of TncMixedQueryToken;

function should_try_jianpin_lookup(const value: string): Boolean;
const
    c_jianpin_query_len_min = 2;
    c_jianpin_query_len_max = 16;
var
    i: Integer;
    ch: Char;
begin
    Result := False;
    if (Length(value) < c_jianpin_query_len_min) or (Length(value) > c_jianpin_query_len_max) then
    begin
        Exit;
    end;

    for i := 1 to Length(value) do
    begin
        ch := value[i];
        if (ch < 'a') or (ch > 'z') then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function is_initial_letter(const ch: Char): Boolean;
begin
    Result := CharInSet(ch, ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x',
        'r', 'z', 'c', 's', 'y', 'w']);
end;

function is_jianpin_key_letter(const ch: Char): Boolean;
begin
    Result := is_initial_letter(ch) or CharInSet(ch, ['a', 'e', 'o']);
end;

function extract_syllable_initial(const syllable: string): string; forward;
function is_valid_candidate_syllable(const syllable: string): Boolean; forward;

function get_unix_time_now: Int64;
begin
    Result := DateTimeToUnix(Now, False);
end;

function build_prefix_upper_bound(const prefix: string): string;
begin
    if prefix = '' then
    begin
        Result := '';
        Exit;
    end;
    Result := prefix + WideChar($FFFF);
end;

function get_text_unit_count_local(const text: string): Integer;
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

function copy_first_text_units(const text: string; const max_units: Integer): string;
var
    idx: Integer;
    unit_count: Integer;
    codepoint: Integer;
begin
    Result := '';
    if (text = '') or (max_units <= 0) then
    begin
        Exit;
    end;

    idx := 1;
    unit_count := 0;
    while idx <= Length(text) do
    begin
        if unit_count >= max_units then
        begin
            Break;
        end;

        codepoint := Ord(text[idx]);
        if (codepoint >= $D800) and (codepoint <= $DBFF) and (idx < Length(text)) and
            (Ord(text[idx + 1]) >= $DC00) and (Ord(text[idx + 1]) <= $DFFF) then
        begin
            Result := Result + text[idx] + text[idx + 1];
            Inc(idx, 2);
        end
        else
        begin
            Result := Result + text[idx];
            Inc(idx);
        end;

        Inc(unit_count);
    end;
end;

function calc_learning_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_freq_bonus_factor = 136.0;
    c_freq_bonus_max = 820;
    c_recent_bonus_1d = 260;
    c_recent_bonus_3d = 190;
    c_recent_bonus_7d = 135;
    c_recent_bonus_30d = 72;
    c_recent_bonus_90d = 28;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_week = 7 * c_sec_per_day;
    c_sec_per_14_days = 14 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
    c_recent_burst_bonus_1d = 88;
    c_recent_burst_bonus_3d = 52;
    c_recent_stable_bonus_7d = 46;
    c_recent_stable_bonus_30d = 28;
    c_stale_once_penalty_14d = 96;
    c_stale_once_penalty_30d = 168;
    c_stale_twice_penalty_90d = 84;
    c_stale_light_penalty_180d = 52;
var
    freq_bonus: Integer;
    recency_bonus: Integer;
    quick_bonus: Integer;
    maturity_bonus: Integer;
    age_seconds: Int64;
    stale_penalty: Integer;
begin
    if commit_count <= 0 then
    begin
        Result := 0;
        Exit;
    end;

    freq_bonus := Round(Ln(1.0 + commit_count) * c_freq_bonus_factor);
    if freq_bonus > c_freq_bonus_max then
    begin
        freq_bonus := c_freq_bonus_max;
    end;

    quick_bonus := 0;
    if commit_count >= 2 then
    begin
        quick_bonus := 120;
        if commit_count >= 3 then
        begin
            quick_bonus := 220;
        end;
        if commit_count >= 4 then
        begin
            quick_bonus := 300;
        end;
        if commit_count >= 5 then
        begin
            quick_bonus := 360 + Min(180, (commit_count - 5) * 24);
        end;
    end;

    maturity_bonus := 0;
    if commit_count >= 8 then
    begin
        maturity_bonus := 72;
        if commit_count >= 12 then
        begin
            maturity_bonus := 128;
        end;
        if commit_count >= 20 then
        begin
            maturity_bonus := 196;
        end;
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix > 0) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds < 0 then
        begin
            age_seconds := 0;
        end;

        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := c_recent_bonus_1d;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := c_recent_bonus_3d;
        end
        else if age_seconds <= c_sec_per_week then
        begin
            recency_bonus := c_recent_bonus_7d;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := c_recent_bonus_30d;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := c_recent_bonus_90d;
        end;

        if commit_count = 1 then
        begin
            recency_bonus := recency_bonus div 2;
        end
        else if commit_count >= 4 then
        begin
            Inc(recency_bonus, recency_bonus div 5);
        end;

        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(recency_bonus, c_recent_burst_bonus_1d);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(recency_bonus, c_recent_burst_bonus_3d);
            end;
        end;

        if commit_count >= 6 then
        begin
            if age_seconds <= c_sec_per_week then
            begin
                Inc(maturity_bonus, c_recent_stable_bonus_7d);
            end
            else if age_seconds <= c_sec_per_30_days then
            begin
                Inc(maturity_bonus, c_recent_stable_bonus_30d);
            end;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end
            else if age_seconds > c_sec_per_14_days then
            begin
                stale_penalty := c_stale_once_penalty_14d;
            end;
        end
        else if commit_count = 2 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_twice_penalty_90d;
            end;
        end
        else if (commit_count <= 4) and (age_seconds > c_sec_per_180_days) then
        begin
            stale_penalty := c_stale_light_penalty_180d;
        end;
    end;

    Result := freq_bonus + quick_bonus + maturity_bonus + recency_bonus;
    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;
end;

function calc_text_learning_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_text_bonus_max = 700;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
var
    age_seconds: Int64;
begin
    Result := (calc_learning_bonus(commit_count, last_used_unix, now_unix) * 2) div 3;
    if commit_count >= 2 then
    begin
        Inc(Result, 80);
    end;
    if commit_count >= 3 then
    begin
        Inc(Result, 68);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 56);
    end;
    if commit_count >= 6 then
    begin
        Inc(Result, 40);
    end;
    if (last_used_unix > 0) and (now_unix > 0) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds < 0 then
        begin
            age_seconds := 0;
        end;
        if age_seconds <= c_sec_per_day then
        begin
            Inc(Result, 54);
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            Inc(Result, 28);
        end;
        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(Result, 42);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(Result, 20);
            end;
        end;
    end;
    if Result > c_text_bonus_max then
    begin
        Result := c_text_bonus_max;
    end;
end;

function calc_context_bigram_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_bigram_bonus_cap = 620;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
    c_recent_pair_bonus_1d = 56;
    c_recent_pair_bonus_3d = 28;
    c_stale_once_penalty_30d = 88;
    c_stale_once_penalty_90d = 132;
    c_stale_twice_penalty_90d = 82;
    c_stale_light_penalty_180d = 52;
var
    recency_bonus: Integer;
    age_seconds: Int64;
    stale_penalty: Integer;
begin
    Result := 0;
    if commit_count <= 0 then
    begin
        Exit;
    end;

    Result := commit_count * 96;
    if commit_count >= 2 then
    begin
        Inc(Result, 46);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 38);
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := 90;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := 74;
        end
        else if age_seconds <= c_sec_per_7_days then
        begin
            recency_bonus := 60;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := 30;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := 14;
        end;

        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(recency_bonus, c_recent_pair_bonus_1d);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(recency_bonus, c_recent_pair_bonus_3d);
            end;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_once_penalty_90d;
            end
            else if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end;
        end
        else if (commit_count = 2) and (age_seconds > c_sec_per_90_days) then
        begin
            stale_penalty := c_stale_twice_penalty_90d;
        end
        else if (commit_count <= 4) and (age_seconds > c_sec_per_180_days) then
        begin
            stale_penalty := c_stale_light_penalty_180d;
        end;
    end;
    Inc(Result, recency_bonus);

    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;

    if Result > c_bigram_bonus_cap then
    begin
        Result := c_bigram_bonus_cap;
    end;
end;

function calc_context_trigram_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_trigram_bonus_cap = 480;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_recent_bonus_1d = 84;
    c_recent_bonus_3d = 52;
    c_stale_once_penalty_30d = 64;
    c_stale_once_penalty_90d = 96;
    c_stale_twice_penalty_90d = 58;
var
    recency_bonus: Integer;
    stale_penalty: Integer;
    age_seconds: Int64;
begin
    Result := 0;
    if commit_count <= 0 then
    begin
        Exit;
    end;

    Result := commit_count * 78;
    if commit_count >= 2 then
    begin
        Inc(Result, 40);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 30);
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := 92;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := 72;
        end
        else if age_seconds <= c_sec_per_7_days then
        begin
            recency_bonus := 48;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := 22;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := 8;
        end;

        if commit_count >= 2 then
        begin
            if age_seconds <= c_sec_per_day then
            begin
                Inc(recency_bonus, c_recent_bonus_1d);
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                Inc(recency_bonus, c_recent_bonus_3d);
            end;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_once_penalty_90d;
            end
            else if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end;
        end
        else if (commit_count = 2) and (age_seconds > c_sec_per_90_days) then
        begin
            stale_penalty := c_stale_twice_penalty_90d;
        end;
    end;

    Inc(Result, recency_bonus);
    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;

    if Result > c_trigram_bonus_cap then
    begin
        Result := c_trigram_bonus_cap;
    end;
end;

function calc_query_segment_path_bonus(const commit_count: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_query_path_bonus_cap = 760;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_recent_bonus_1d = 108;
    c_recent_bonus_3d = 72;
    c_recent_bonus_7d = 44;
    c_stale_once_penalty_30d = 86;
    c_stale_once_penalty_90d = 136;
    c_stale_twice_penalty_90d = 74;
var
    recency_bonus: Integer;
    stale_penalty: Integer;
    age_seconds: Int64;
begin
    Result := 0;
    if commit_count <= 0 then
    begin
        Exit;
    end;

    Result := commit_count * 112;
    if commit_count >= 2 then
    begin
        Inc(Result, 64);
    end;
    if commit_count >= 4 then
    begin
        Inc(Result, 44);
    end;

    recency_bonus := 0;
    stale_penalty := 0;
    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds <= c_sec_per_day then
        begin
            recency_bonus := c_recent_bonus_1d;
        end
        else if age_seconds <= c_sec_per_3_days then
        begin
            recency_bonus := c_recent_bonus_3d;
        end
        else if age_seconds <= c_sec_per_7_days then
        begin
            recency_bonus := c_recent_bonus_7d;
        end
        else if age_seconds <= c_sec_per_30_days then
        begin
            recency_bonus := 18;
        end
        else if age_seconds <= c_sec_per_90_days then
        begin
            recency_bonus := 6;
        end;

        if commit_count = 1 then
        begin
            if age_seconds > c_sec_per_90_days then
            begin
                stale_penalty := c_stale_once_penalty_90d;
            end
            else if age_seconds > c_sec_per_30_days then
            begin
                stale_penalty := c_stale_once_penalty_30d;
            end;
        end
        else if (commit_count = 2) and (age_seconds > c_sec_per_90_days) then
        begin
            stale_penalty := c_stale_twice_penalty_90d;
        end;
    end;

    Inc(Result, recency_bonus);
    if stale_penalty > 0 then
    begin
        Dec(Result, stale_penalty);
        if Result < 0 then
        begin
            Result := 0;
        end;
    end;

    if Result > c_query_path_bonus_cap then
    begin
        Result := c_query_path_bonus_cap;
    end;
end;

function calc_base_query_segment_path_bonus(const weight: Integer): Integer;
const
    c_base_query_path_bonus_cap = 420;
begin
    Result := 0;
    if weight <= 0 then
    begin
        Exit;
    end;

    Result := (weight * 3) div 5;
    if weight >= 420 then
    begin
        Inc(Result, 28);
    end;
    if weight >= 620 then
    begin
        Inc(Result, 42);
    end;
    if weight >= 820 then
    begin
        Inc(Result, 54);
    end;

    if Result > c_base_query_path_bonus_cap then
    begin
        Result := c_base_query_path_bonus_cap;
    end;
end;

function calc_lm_transition_bonus(const weight: Integer): Integer;
const
    c_lm_transition_bonus_cap = 1560;
begin
    Result := 0;
    if weight <= 0 then
    begin
        Exit;
    end;

    // LM weights are already pinyin-bucket-normalized by the trainer. Keep
    // their range separate from legacy query-path weights so final long-
    // sentence reranking can require a clear statistical lead.
    Result := weight * 3;
    if Result > c_lm_transition_bonus_cap then
    begin
        Result := c_lm_transition_bonus_cap;
    end;
end;

// SQLite's default LIKE folds ASCII case, treats % and _ as wildcards and
// stops at NUL, so it cannot use the BINARY text index. For other literals,
// "text LIKE value || '%'" selects exactly the texts in [value, upper_bound),
// where upper_bound increments the last code point: UTF-8 byte order is code
// point order. Returns False when the rewrite would not be exact.
function try_get_like_prefix_upper_bound(const value: string;
    out upper_bound: string): Boolean;
var
    idx: Integer;
    ch: Char;
begin
    Result := False;
    upper_bound := '';
    if value = '' then
    begin
        Exit;
    end;

    for idx := 1 to Length(value) do
    begin
        ch := value[idx];
        if ((ch >= 'A') and (ch <= 'Z')) or ((ch >= 'a') and (ch <= 'z')) or
            (ch = '%') or (ch = '_') or (ch = #0) then
        begin
            Exit;
        end;
        if (ch >= #$D800) and (ch <= #$DBFF) then
        begin
            if (idx = Length(value)) or (value[idx + 1] < #$DC00) or
                (value[idx + 1] > #$DFFF) then
            begin
                Exit;
            end;
        end
        else if (ch >= #$DC00) and (ch <= #$DFFF) then
        begin
            if (idx = 1) or (value[idx - 1] < #$D800) or
                (value[idx - 1] > #$DBFF) then
            begin
                Exit;
            end;
        end;
    end;

    ch := value[Length(value)];
    if ((ch >= #$D7FF) and (ch <= #$DFFF)) or (ch = #$FFFF) then
    begin
        Exit;
    end;
    upper_bound := Copy(value, 1, Length(value) - 1) + Char(Ord(ch) + 1);
    Result := True;
end;

function calc_compound_tail_support_value(const path_count: Integer;
    const total_weight: Integer; const max_weight: Integer): Integer;
const
    c_support_cap = 3200;
begin
    Result := 0;
    if (path_count <= 0) or (total_weight <= 0) then
    begin
        Exit;
    end;

    Result := Min(1600, path_count * 220) +
        Min(1200, total_weight div 2) + Min(700, max_weight);
    if path_count >= 4 then
    begin
        Inc(Result, 360);
    end;
    if max_weight >= 420 then
    begin
        Inc(Result, 220);
    end;

    if Result > c_support_cap then
    begin
        Result := c_support_cap;
    end;
end;

function calc_query_segment_path_penalty_value(const penalty_value: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
var
    age_seconds: Int64;
begin
    Result := penalty_value;
    if Result <= 0 then
    begin
        Exit(0);
    end;

    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds > c_sec_per_180_days then
        begin
            Result := (Result * 20) div 100;
        end
        else if age_seconds > c_sec_per_90_days then
        begin
            Result := (Result * 40) div 100;
        end
        else if age_seconds > c_sec_per_30_days then
        begin
            Result := (Result * 65) div 100;
        end
        else if age_seconds > c_sec_per_7_days then
        begin
            Result := (Result * 85) div 100;
        end;
    end;

    if Result < 0 then
    begin
        Result := 0;
    end;
end;

function calc_candidate_penalty_value(const penalty_value: Integer; const last_used_unix: Int64;
    const now_unix: Int64): Integer;
const
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_7_days = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
    c_sec_per_90_days = 90 * c_sec_per_day;
    c_sec_per_180_days = 180 * c_sec_per_day;
var
    age_seconds: Int64;
begin
    Result := penalty_value;
    if Result <= 0 then
    begin
        Exit(0);
    end;

    if (last_used_unix > 0) and (now_unix >= last_used_unix) then
    begin
        age_seconds := now_unix - last_used_unix;
        if age_seconds > c_sec_per_180_days then
        begin
            Result := (Result * 20) div 100;
        end
        else if age_seconds > c_sec_per_90_days then
        begin
            Result := (Result * 40) div 100;
        end
        else if age_seconds > c_sec_per_30_days then
        begin
            Result := (Result * 65) div 100;
        end
        else if age_seconds > c_sec_per_7_days then
        begin
            Result := (Result * 85) div 100;
        end;
    end;

    if Result < 0 then
    begin
        Result := 0;
    end;
end;

function get_encoded_path_segment_count(const encoded_path: string): Integer;
var
    idx: Integer;
    normalized_path: string;
const
    c_segment_path_separator = #3;
begin
    normalized_path := Trim(encoded_path);
    if normalized_path = '' then
    begin
        Exit(0);
    end;

    Result := 1;
    for idx := 1 to Length(normalized_path) do
    begin
        if normalized_path[idx] = c_segment_path_separator then
        begin
            Inc(Result);
        end;
    end;
end;

function is_single_pair_lm_transition_path(const encoded_path: string): Boolean;
var
    normalized_path: string;
    separator_idx: Integer;
    left_text: string;
    right_text: string;
const
    c_segment_path_separator = #3;
begin
    Result := False;
    normalized_path := Trim(encoded_path);
    separator_idx := Pos(c_segment_path_separator, normalized_path);
    if (separator_idx <= 1) or (separator_idx >= Length(normalized_path)) then
    begin
        Exit;
    end;
    if Pos(c_segment_path_separator,
        Copy(normalized_path, separator_idx + 1, MaxInt)) > 0 then
    begin
        Exit;
    end;

    left_text := Trim(Copy(normalized_path, 1, separator_idx - 1));
    right_text := Trim(Copy(normalized_path, separator_idx + 1, MaxInt));
    Result := (get_text_unit_count_local(left_text) = 1) and
        (get_text_unit_count_local(right_text) = 1);
end;

function calc_single_pair_lm_transition_bonus(const weight: Integer): Integer;
const
    c_single_pair_weight_floor = 410;
    c_single_pair_bonus_cap = 48;
begin
    // The raw 1+1 weight is a strict short-word generation threshold. In a
    // long sentence it should only break close path ties, not act like the
    // much broader word-path LM weights that are scaled by calc_lm_transition_bonus.
    Result := weight - c_single_pair_weight_floor;
    if Result < 0 then
    begin
        Result := 0;
    end;
    if Result > c_single_pair_bonus_cap then
    begin
        Result := c_single_pair_bonus_cap;
    end;
end;

function split_text_units_local(const input_text: string): TArray<string>;
var
    idx: Integer;
    unit_count: Integer;
    unit_text: string;
begin
    SetLength(Result, Length(input_text));
    unit_count := 0;
    idx := 1;
    while idx <= Length(input_text) do
    begin
        if (Ord(input_text[idx]) >= $D800) and (Ord(input_text[idx]) <= $DBFF) and
            (idx < Length(input_text)) and
            (Ord(input_text[idx + 1]) >= $DC00) and (Ord(input_text[idx + 1]) <= $DFFF) then
        begin
            unit_text := input_text[idx] + input_text[idx + 1];
            Inc(idx, 2);
        end
        else
        begin
            unit_text := input_text[idx];
            Inc(idx);
        end;

        Result[unit_count] := unit_text;
        Inc(unit_count);
    end;
    SetLength(Result, unit_count);
end;

function build_context_variants_local(const context_text: string): TArray<string>;
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

        context_units := split_text_units_local(variant_text);
        if Length(context_units) <= 1 then
        begin
            Exit;
        end;

        min_start_idx := Max(0, Length(context_units) - 4);
        for start_idx := min_start_idx to Length(context_units) - 1 do
        begin
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

function parse_mixed_jianpin_query(const query_key: string; out full_prefix: string; out jianpin_key: string;
    out tokens: TncMixedQueryTokenList): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    has_full: Boolean;
    has_initial: Boolean;
    reconstructed: string;
    initial_value: string;
    syllable_text: string;
    prefix_closed: Boolean;
begin
    Result := False;
    full_prefix := '';
    jianpin_key := '';
    SetLength(tokens, 0);
    if query_key = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(query_key);
    finally
        parser.Free;
    end;

    nc_merge_abbreviated_retroflex_initials(syllables);

    if Length(syllables) < 2 then
    begin
        Exit;
    end;

    SetLength(tokens, Length(syllables));
    reconstructed := '';
    has_full := False;
    has_initial := False;
    prefix_closed := False;
    for idx := 0 to High(syllables) do
    begin
        syllable_text := syllables[idx].text;
        reconstructed := reconstructed + syllable_text;

        if is_valid_candidate_syllable(syllable_text) then
        begin
            tokens[idx].kind := mqt_full;
            tokens[idx].text := syllable_text;
            has_full := True;
            if not prefix_closed then
            begin
                full_prefix := full_prefix + syllable_text;
            end;
            Continue;
        end;

        if ((Length(syllable_text) = 1) and is_initial_letter(syllable_text[1])) or
            (syllable_text = 'zh') or (syllable_text = 'ch') or
            (syllable_text = 'sh') then
        begin
            tokens[idx].kind := mqt_initial;
            tokens[idx].text := syllable_text;
            has_initial := True;
            prefix_closed := True;
            Continue;
        end;

        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    if not SameText(reconstructed, query_key) then
    begin
        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    // Mixed mode requires at least one full syllable and at least one initial.
    if (not has_full) or (not has_initial) then
    begin
        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    jianpin_key := '';
    for idx := 0 to High(tokens) do
    begin
        if tokens[idx].kind = mqt_full then
        begin
            initial_value := extract_syllable_initial(tokens[idx].text);
            if initial_value <> '' then
            begin
                jianpin_key := jianpin_key + initial_value[1];
            end
            else
            begin
                jianpin_key := jianpin_key + tokens[idx].text[1];
            end;
        end
        else
        begin
            jianpin_key := jianpin_key + tokens[idx].text[1];
        end;
    end;

    if jianpin_key = '' then
    begin
        SetLength(tokens, 0);
        full_prefix := '';
        Exit;
    end;

    Result := True;
end;

function extract_syllable_initial(const syllable: string): string;
var
    head2: string;
    head1: Char;
begin
    Result := '';
    if syllable = '' then
    begin
        Exit;
    end;

    if Length(syllable) >= 2 then
    begin
        head2 := Copy(syllable, 1, 2);
        if (head2 = 'zh') or (head2 = 'ch') or (head2 = 'sh') then
        begin
            Result := head2;
            Exit;
        end;
    end;

    head1 := syllable[1];
    if CharInSet(head1, ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x',
        'r', 'z', 'c', 's', 'y', 'w']) then
    begin
        Result := head1;
    end;
end;

function is_valid_candidate_syllable(const syllable: string): Boolean;
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

function is_full_pinyin_key(const value: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    reconstructed: string;
    compact_value: string;
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
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
    end;

    compact_value := LowerCase(Trim(value));
    compact_value := StringReplace(compact_value, '''', '', [rfReplaceAll]);
    Result := SameText(reconstructed, compact_value);
end;

function normalize_compact_pinyin_key(const value: string): string;
var
    i: Integer;
    ch: Char;
    spelling: string;
begin
    spelling := nc_normalize_umlaut_spelling(value);
    Result := '';
    for i := 1 to Length(spelling) do
    begin
        ch := spelling[i];
        if CharInSet(ch, ['A' .. 'Z']) then
        begin
            ch := Chr(Ord(ch) + 32);
        end;
        if CharInSet(ch, ['a' .. 'z']) then
        begin
            Result := Result + ch;
        end;
    end;
end;

function normalize_canonical_pinyin_key(const value: string): string;
var
    i: Integer;
    ch: Char;
    spelling: string;
begin
    spelling := nc_normalize_umlaut_spelling(value);
    Result := '';
    for i := 1 to Length(spelling) do
    begin
        ch := spelling[i];
        if CharInSet(ch, ['A' .. 'Z']) then
        begin
            ch := Chr(Ord(ch) + 32);
        end;
        if CharInSet(ch, ['a' .. 'z']) then
        begin
            Result := Result + ch;
        end
        else if (ch = '''') and (Result <> '') and
            (Result[Length(Result)] <> '''') then
        begin
            Result := Result + ch;
        end;
    end;

    if (Result <> '') and (Result[Length(Result)] = '''') then
    begin
        Delete(Result, Length(Result), 1);
    end;
end;

function same_normalized_pinyin_key(const left_value: string; const right_value: string): Boolean;
begin
    Result := SameText(normalize_compact_pinyin_key(left_value), normalize_compact_pinyin_key(right_value));
end;

function build_jianpin_key_from_full_pinyin(const value: string): string;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
    reconstructed: string;
begin
    Result := '';
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
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Result := '';
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
        initial_value := extract_syllable_initial(syllables[idx].text);
        if initial_value <> '' then
        begin
            // Keep jianpin key shape aligned with dict_jianpin schema:
            // one letter per syllable (zh/ch/sh collapse to z/c/s).
            Result := Result + initial_value[1];
        end
        else if syllables[idx].text <> '' then
        begin
            Result := Result + syllables[idx].text[1];
        end;
    end;

    if not SameText(reconstructed, normalize_compact_pinyin_key(value)) then
    begin
        Result := '';
    end;
end;

function is_single_syllable_full_pinyin_key(const value: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
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

    if Length(syllables) <> 1 then
    begin
        Exit;
    end;

    if not is_valid_candidate_syllable(syllables[0].text) then
    begin
        Exit;
    end;

    Result := SameText(syllables[0].text, value);
end;

function mixed_initial_matches(const query_initial: Char; const syllable_initial: string): Boolean;
begin
    if syllable_initial = '' then
    begin
        Result := False;
        Exit;
    end;

    case query_initial of
        'z':
            Result := (syllable_initial = 'z') or (syllable_initial = 'zh');
        'c':
            Result := (syllable_initial = 'c') or (syllable_initial = 'ch');
        's':
            Result := (syllable_initial = 's') or (syllable_initial = 'sh');
    else
        Result := syllable_initial = query_initial;
    end;
end;

function candidate_matches_mixed_jianpin(const parser: TncPinyinParser; const candidate_pinyin: string;
    const query_tokens: TncMixedQueryTokenList): Boolean;
var
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (Length(query_tokens) = 0) then
    begin
        Exit;
    end;

    syllables := parser.parse(candidate_pinyin);
    if Length(syllables) <> Length(query_tokens) then
    begin
        Exit;
    end;

    for idx := 0 to High(query_tokens) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;

        if query_tokens[idx].kind = mqt_full then
        begin
            if not SameText(syllables[idx].text, query_tokens[idx].text) then
            begin
                Exit;
            end;
            Continue;
        end;

        if query_tokens[idx].text = '' then
        begin
            Exit;
        end;

        initial_value := extract_syllable_initial(syllables[idx].text);
        if (initial_value = '') and (syllables[idx].text <> '') then
        begin
            initial_value := LowerCase(Copy(syllables[idx].text, 1, 1));
        end;
        if ((Length(query_tokens[idx].text) = 2) and
            (query_tokens[idx].text <> initial_value)) or
            ((Length(query_tokens[idx].text) = 1) and
            (not mixed_initial_matches(query_tokens[idx].text[1], initial_value))) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function candidate_matches_jianpin_key(const parser: TncPinyinParser; const candidate_pinyin: string;
    const query_jianpin_key: string): Boolean;
var
    syllables: TncPinyinParseResult;
    idx: Integer;
    initial_value: string;
    candidate_key: string;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (query_jianpin_key = '') then
    begin
        Exit;
    end;

    syllables := parser.parse(candidate_pinyin);
    if Length(syllables) <> Length(query_jianpin_key) then
    begin
        Exit;
    end;

    candidate_key := '';
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            Exit;
        end;

        initial_value := extract_syllable_initial(syllables[idx].text);
        if (initial_value = '') and (syllables[idx].text <> '') then
        begin
            initial_value := LowerCase(Copy(syllables[idx].text, 1, 1));
        end;
        if initial_value = '' then
        begin
            Exit;
        end;

        candidate_key := candidate_key + initial_value[1];
    end;

    Result := SameText(candidate_key, query_jianpin_key);
end;

function candidate_matches_any_jianpin_key(const parser: TncPinyinParser; const candidate_pinyin: string;
    const query_jianpin_keys: TArray<string>): Boolean;
var
    idx: Integer;
begin
    Result := False;
    if (parser = nil) or (candidate_pinyin = '') or (Length(query_jianpin_keys) = 0) then
    begin
        Exit;
    end;

    for idx := 0 to High(query_jianpin_keys) do
    begin
        if (query_jianpin_keys[idx] <> '') and
            candidate_matches_jianpin_key(parser, candidate_pinyin, query_jianpin_keys[idx]) then
        begin
            Result := True;
            Exit;
        end;
    end;
end;

function build_jianpin_query_variants(const value: string): TArray<string>;
var
    list: TList<string>;
    seen: TDictionary<string, Boolean>;
    normalized_value: string;
    i: Integer;

    procedure add_variant(const variant_value: string);
    begin
        if variant_value = '' then
        begin
            Exit;
        end;
        if seen.ContainsKey(variant_value) then
        begin
            Exit;
        end;

        seen.Add(variant_value, True);
        list.Add(variant_value);
    end;

    procedure expand_variants(const rest_value: string; const prefix_value: string);
    var
        pair_value: string;
    begin
        if rest_value = '' then
        begin
            add_variant(prefix_value);
            Exit;
        end;

        if Length(rest_value) >= 2 then
        begin
            pair_value := Copy(rest_value, 1, 2);
            if (pair_value = 'zh') or (pair_value = 'ch') or (pair_value = 'sh') then
            begin
                // Keep both interpretations:
                // - pair as two initials (z+h / c+h / s+h)
                // - pair collapsed as one retroflex initial (zh/ch/sh -> z/c/s)
                expand_variants(Copy(rest_value, 3, MaxInt), prefix_value + pair_value);
                expand_variants(Copy(rest_value, 3, MaxInt), prefix_value + pair_value[1]);
                Exit;
            end;
        end;

        expand_variants(Copy(rest_value, 2, MaxInt), prefix_value + rest_value[1]);
    end;
begin
    SetLength(Result, 0);
    if value = '' then
    begin
        Exit;
    end;

    normalized_value := LowerCase(value);
    list := TList<string>.Create;
    seen := TDictionary<string, Boolean>.Create;
    try
        expand_variants(normalized_value, '');
        if list.Count = 0 then
        begin
            add_variant(normalized_value);
        end;

        SetLength(Result, list.Count);
        for i := 0 to list.Count - 1 do
        begin
            Result[i] := list[i];
        end;
    finally
        seen.Free;
        list.Free;
    end;
end;

function literal_query_matches_full_pinyin(const query_value: string;
    const full_pinyin_value: string): Boolean;
var
    query_key: string;
    full_pinyin_key: string;
    compact_full_pinyin_key: string;
    full_prefix: string;
    jianpin_key: string;
    mixed_tokens: TncMixedQueryTokenList;
    jianpin_variants: TArray<string>;
    parser: TncPinyinParser;
    idx: Integer;
    all_initials: Boolean;
begin
    Result := False;
    query_key := normalize_compact_pinyin_key(query_value);
    full_pinyin_key := normalize_canonical_pinyin_key(full_pinyin_value);
    compact_full_pinyin_key := normalize_compact_pinyin_key(full_pinyin_key);
    if (query_key = '') or (full_pinyin_key = '') or
        (not is_full_pinyin_key(full_pinyin_key)) then
    begin
        Exit;
    end;

    if SameText(query_key, compact_full_pinyin_key) then
    begin
        Exit(True);
    end;

    parser := TncPinyinParser.Create;
    try
        if parse_mixed_jianpin_query(query_key, full_prefix, jianpin_key,
            mixed_tokens) then
        begin
            if candidate_matches_mixed_jianpin(parser, full_pinyin_key,
                mixed_tokens) then
            begin
                Exit(True);
            end;
        end;

        all_initials := True;
        for idx := 1 to Length(query_key) do
        begin
            if not is_jianpin_key_letter(query_key[idx]) then
            begin
                all_initials := False;
                Break;
            end;
        end;
        if not all_initials then
        begin
            Exit;
        end;

        jianpin_variants := build_jianpin_query_variants(query_key);
        Result := candidate_matches_any_jianpin_key(parser, full_pinyin_key,
            jianpin_variants);
    finally
        parser.Free;
    end;
end;

function count_retroflex_pairs_in_compact_key(const value: string): Integer;
var
    idx: Integer;
    pair_value: string;
begin
    Result := 0;
    idx := 1;
    while idx < Length(value) do
    begin
        pair_value := Copy(value, idx, 2);
        if (pair_value = 'zh') or (pair_value = 'ch') or (pair_value = 'sh') then
        begin
            Inc(Result);
            Inc(idx, 2);
        end
        else
        begin
            Inc(idx);
        end;
    end;
end;

function collapse_retroflex_pairs_in_compact_key(const value: string): string;
var
    idx: Integer;
    pair_value: string;
begin
    Result := '';
    idx := 1;
    while idx <= Length(value) do
    begin
        if idx < Length(value) then
        begin
            pair_value := Copy(value, idx, 2);
            if (pair_value = 'zh') or (pair_value = 'ch') or (pair_value = 'sh') then
            begin
                Result := Result + pair_value[1];
                Inc(idx, 2);
                Continue;
            end;
        end;

        Result := Result + value[idx];
        Inc(idx);
    end;
end;

function is_retroflex_collapsed_fallback_key(const original_key: string; const variant_key: string): Boolean;
var
    collapsed_key: string;
begin
    Result := False;
    if (original_key = '') or (variant_key = '') then
    begin
        Exit;
    end;

    collapsed_key := collapse_retroflex_pairs_in_compact_key(original_key);
    Result := (collapsed_key <> '') and (not SameText(collapsed_key, original_key)) and SameText(collapsed_key, variant_key);
end;

function is_bare_retroflex_pair_key(const value: string): Boolean;
begin
    Result := (Length(value) = 2) and CharInSet(value[1], ['z', 'c', 's']) and (value[2] = 'h');
end;

constructor TncSqliteDictionary.create(const base_db_path: string; const user_db_path: string;
    const prune_user_entries_on_open: Boolean = True);
begin
    inherited create;
    m_base_db_path := base_db_path;
    m_user_db_path := user_db_path;
    m_user_script_cache := TDictionary<string, string>.Create;
    m_user_storage_text_cache := TDictionary<string, string>.Create;
    m_ready := False;
    m_base_ready := False;
    m_base_connection_read_only := False;
    m_user_ready := False;
    m_user_initialization_deferred := False;
    m_defer_optional_model_loads := False;
    m_prune_user_entries_on_open := prune_user_entries_on_open;
    m_limit := 256;
    m_bigram_prune_countdown := 64;
    m_trigram_prune_countdown := 64;
    m_query_path_prune_countdown := 64;
    m_query_path_penalty_prune_countdown := 64;
    m_context_query_choice_prune_countdown := 64;
    m_write_batch_depth := 0;
    m_stmt_context_bonus := nil;
    m_stmt_context_trigram_bonus := nil;
    m_stmt_base_query_path_bonus := nil;
    m_stmt_exact_pair_path_evidence := nil;
    m_stmt_compound_tail_support := nil;
    m_stmt_compound_tail_prefix_support := nil;
    m_stmt_compound_tail_prefix_range_support := nil;
    m_stmt_prefix_popularity := nil;
    m_stmt_pinyin_followup_popularity := nil;
    m_stmt_contains_popularity := nil;
    m_stmt_base_text_prefix_bonus := nil;
    m_stmt_single_char_exact_weight := nil;
    m_stmt_query_choice_bonus := nil;
    m_stmt_context_query_choice_bonus := nil;
    m_stmt_query_latest_choice_text := nil;
    m_stmt_query_path_bonus := nil;
    m_stmt_query_path_penalty := nil;
    m_stmt_candidate_penalty := nil;
    m_stmt_exact_base := nil;
    m_stmt_exact_base_alias := nil;
    m_stmt_exact_user := nil;
    m_stmt_exact_component_base := nil;
    m_stmt_exact_component_base_alias := nil;
    m_stmt_exact_component_user := nil;
    m_stmt_exact_admin_prefix := nil;
    m_stmt_lookup_base := nil;
    m_stmt_lookup_single_char_exact := nil;
    m_stmt_record_context_pair_update := nil;
    m_stmt_record_context_pair_insert := nil;
    m_stmt_record_context_trigram_update := nil;
    m_stmt_record_context_trigram_insert := nil;
    m_stmt_record_query_path_update := nil;
    m_stmt_record_query_path_insert := nil;
    m_base_connection := nil;
    m_user_connection := nil;
    m_contains_popularity_cache := TDictionary<string, Integer>.Create;
    m_prefix_popularity_cache := TDictionary<string, Integer>.Create;
    m_pinyin_followup_popularity_cache := TDictionary<string, Integer>.Create;
    m_base_text_prefix_bonus_cache := TDictionary<string, Integer>.Create;
    m_single_char_weight_cache := TDictionary<string, Integer>.Create;
    m_context_bonus_cache := TDictionary<string, Integer>.Create;
    m_query_choice_bonus_cache := TDictionary<string, Integer>.Create;
    m_context_query_choice_bonus_cache := TDictionary<string, Integer>.Create;
    m_query_latest_choice_text_cache := TDictionary<string, string>.Create;
    m_query_path_bonus_cache := TDictionary<string, Integer>.Create;
    m_query_path_bonus_cache_loaded := False;
    m_base_query_path_pinyin_cache := TDictionary<string, Boolean>.Create;
    m_base_query_path_pinyin_cache_loaded := False;
    m_lm_transition_bonus_cache := TDictionary<string, Integer>.Create;
    m_exact_pair_path_evidence_cache :=
        TDictionary<string, TncPairPathEvidenceList>.Create;
    m_lm_transition_cache_loaded := False;
    m_char_lm_entry_cache := TDictionary<string, TncCharLmCacheEntry>.Create;
    m_char_lm_cache_order := TQueue<string>.Create;
    m_char_lm_text_score_cache := TDictionary<string, Integer>.Create;
    m_char_lm_text_score_cache_order := TQueue<string>.Create;
    m_char_lm_short_context_text_score_cache :=
        TDictionary<string, Integer>.Create;
    m_char_lm_short_context_text_score_cache_order := TQueue<string>.Create;
    m_char_lm_available := -1;
    m_stmt_char_lm_entries_1 := nil;
    m_stmt_char_lm_entries_8 := nil;
    m_stmt_char_lm_entries_16 := nil;
    m_stmt_char_lm_entries_32 := nil;
    m_stmt_char_lm_entries_64 := nil;
    m_stmt_char_lm_entries_128 := nil;
    m_stmt_char_lm_entries_256 := nil;
    m_stmt_char_lm_entries_400 := nil;
    m_char_reverse_lm_entry_cache :=
        TDictionary<string, TncCharLmCacheEntry>.Create;
    m_char_reverse_lm_cache_order := TQueue<string>.Create;
    m_char_reverse_lm_text_score_cache :=
        TDictionary<string, Integer>.Create;
    m_char_reverse_lm_text_score_cache_order := TQueue<string>.Create;
    m_char_reverse_lm_available := -1;
    m_stmt_char_reverse_lm_entries_1 := nil;
    m_stmt_char_reverse_lm_entries_8 := nil;
    m_stmt_char_reverse_lm_entries_16 := nil;
    m_stmt_char_reverse_lm_entries_32 := nil;
    m_stmt_char_reverse_lm_entries_64 := nil;
    m_stmt_char_reverse_lm_entries_128 := nil;
    m_stmt_char_reverse_lm_entries_256 := nil;
    m_stmt_char_reverse_lm_entries_400 := nil;
    m_compound_tail_support_cache := TDictionary<string, Integer>.Create;
    m_query_path_penalty_cache := TDictionary<string, Integer>.Create;
    m_candidate_penalty_cache := TDictionary<string, Integer>.Create;
    m_candidate_penalty_pinyin_loaded_cache := TDictionary<string, Boolean>.Create;
    m_lookup_result_cache := TDictionary<string, TncCandidateList>.Create;
    m_mixed_abbreviation_cache := TDictionary<string, TncCandidateList>.Create;
    m_word_completion_cache := TDictionary<string, TncOneKeyCompletionList>.Create;
    m_next_character_cache := TDictionary<string, TArray<string>>.Create;
    m_lookup_result_cache_order := TQueue<string>.Create;
    m_exact_lookup_result_cache := TDictionary<string, TncCandidateList>.Create;
    m_exact_lookup_result_cache_order := TQueue<string>.Create;
    m_exact_component_lookup_cache := TDictionary<string, TncCandidateList>.Create;
    m_exact_component_lookup_cache_order := TQueue<string>.Create;
    SetLength(m_base_exact_pinyin_bloom, 0);
    m_base_exact_pinyin_bloom_ready := False;
    m_prefix_lookup_result_cache := TDictionary<string, TncCandidateList>.Create;
    m_candidate_prefix_completion_cache :=
        TDictionary<string, TncOneKeyCompletionList>.Create;
    m_one_key_completion_cache :=
        TDictionary<string, TncOneKeyCompletionList>.Create;
    m_long_one_key_completion_cache :=
        TDictionary<string, TncLongOneKeyCompletionList>.Create;
    m_one_key_completion_competition_cache :=
        TDictionary<string, TncOneKeyCompletionCompetitionEvidenceList>.Create;
    m_one_key_completion_pair_audit_cache :=
        TDictionary<string, TncOneKeyCompletionPairAudit>.Create;
    m_short_promotion_cache := TDictionary<string, string>.Create;
    m_exact_text_prefix_cache :=
        TDictionary<string, TncExactTextPath>.Create;
    m_literal_lookup_result_cache := TDictionary<string, TncCandidateList>.Create;
    m_literal_user_words_available := -1;
    m_exact_base_entry_cache := TDictionary<string, Boolean>.Create;
    m_normalized_base_entry_cache := TDictionary<string, Boolean>.Create;
    m_explicit_user_entry_cache := TDictionary<string, Boolean>.Create;
    m_literal_user_entry_cache := TDictionary<string, Boolean>.Create;
    m_admin_place_longer_prefix_cache :=
        TDictionary<string, TArray<string>>.Create;
    m_admin_place_query_syllable_count_cache :=
        TDictionary<string, Integer>.Create;
    m_fuzzy_pinyin_enabled := False;
    m_fuzzy_pinyin_rules := [];
    m_fuzzy_lookup_result_cache :=
        TDictionary<string, TncCandidateList>.Create;
    m_fuzzy_lookup_result_cache_order := TQueue<string>.Create;
    m_fuzzy_choice_bonus_cache := TDictionary<string, Integer>.Create;
    m_fuzzy_choice_query_loaded_cache := TDictionary<string, Boolean>.Create;
    m_debug_mode := False;
    m_last_lookup_debug_hint := '';
    m_short_lookup_cache_prewarmed := False;
    m_process_user_data_generation := InterlockedCompareExchange(
        g_user_data_generation, 0, 0);
    m_user_data_version := 0;
    m_last_user_data_version_check_tick := 0;
    m_contains_popularity_index_checked := False;
    m_contains_popularity_index_ready := False;
end;

destructor TncSqliteDictionary.Destroy;
begin
    close;
    m_user_script_cache.Free;
    m_user_storage_text_cache.Free;
    if m_fuzzy_lookup_result_cache_order <> nil then
    begin
        m_fuzzy_lookup_result_cache_order.Free;
        m_fuzzy_lookup_result_cache_order := nil;
    end;
    if m_fuzzy_lookup_result_cache <> nil then
    begin
        m_fuzzy_lookup_result_cache.Free;
        m_fuzzy_lookup_result_cache := nil;
    end;
    if m_fuzzy_choice_query_loaded_cache <> nil then
    begin
        m_fuzzy_choice_query_loaded_cache.Free;
        m_fuzzy_choice_query_loaded_cache := nil;
    end;
    if m_fuzzy_choice_bonus_cache <> nil then
    begin
        m_fuzzy_choice_bonus_cache.Free;
        m_fuzzy_choice_bonus_cache := nil;
    end;
    if m_base_connection <> nil then
    begin
        m_base_connection.Free;
        m_base_connection := nil;
    end;
    if m_user_connection <> nil then
    begin
        m_user_connection.Free;
        m_user_connection := nil;
    end;
    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.Free;
        m_contains_popularity_cache := nil;
    end;
    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.Free;
        m_prefix_popularity_cache := nil;
    end;
    if m_pinyin_followup_popularity_cache <> nil then
    begin
        m_pinyin_followup_popularity_cache.Free;
        m_pinyin_followup_popularity_cache := nil;
    end;
    if m_base_text_prefix_bonus_cache <> nil then
    begin
        m_base_text_prefix_bonus_cache.Free;
        m_base_text_prefix_bonus_cache := nil;
    end;
    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.Free;
        m_single_char_weight_cache := nil;
    end;
    if m_context_bonus_cache <> nil then
    begin
        m_context_bonus_cache.Free;
        m_context_bonus_cache := nil;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Free;
        m_query_choice_bonus_cache := nil;
    end;
    if m_context_query_choice_bonus_cache <> nil then
    begin
        m_context_query_choice_bonus_cache.Free;
        m_context_query_choice_bonus_cache := nil;
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Free;
        m_query_latest_choice_text_cache := nil;
    end;
    if m_query_path_bonus_cache <> nil then
    begin
        m_query_path_bonus_cache.Free;
        m_query_path_bonus_cache := nil;
    end;
    if m_base_query_path_pinyin_cache <> nil then
    begin
        m_base_query_path_pinyin_cache.Free;
        m_base_query_path_pinyin_cache := nil;
    end;
    if m_lm_transition_bonus_cache <> nil then
    begin
        m_lm_transition_bonus_cache.Free;
        m_lm_transition_bonus_cache := nil;
    end;
    if m_exact_pair_path_evidence_cache <> nil then
    begin
        m_exact_pair_path_evidence_cache.Free;
        m_exact_pair_path_evidence_cache := nil;
    end;
    if m_char_lm_entry_cache <> nil then
    begin
        m_char_lm_entry_cache.Free;
        m_char_lm_entry_cache := nil;
    end;
    if m_char_lm_cache_order <> nil then
    begin
        m_char_lm_cache_order.Free;
        m_char_lm_cache_order := nil;
    end;
    if m_char_lm_text_score_cache <> nil then
    begin
        m_char_lm_text_score_cache.Free;
        m_char_lm_text_score_cache := nil;
    end;
    if m_char_lm_text_score_cache_order <> nil then
    begin
        m_char_lm_text_score_cache_order.Free;
        m_char_lm_text_score_cache_order := nil;
    end;
    if m_char_lm_short_context_text_score_cache <> nil then
    begin
        m_char_lm_short_context_text_score_cache.Free;
        m_char_lm_short_context_text_score_cache := nil;
    end;
    if m_char_lm_short_context_text_score_cache_order <> nil then
    begin
        m_char_lm_short_context_text_score_cache_order.Free;
        m_char_lm_short_context_text_score_cache_order := nil;
    end;
    if m_char_reverse_lm_entry_cache <> nil then
    begin
        m_char_reverse_lm_entry_cache.Free;
        m_char_reverse_lm_entry_cache := nil;
    end;
    if m_char_reverse_lm_cache_order <> nil then
    begin
        m_char_reverse_lm_cache_order.Free;
        m_char_reverse_lm_cache_order := nil;
    end;
    if m_char_reverse_lm_text_score_cache <> nil then
    begin
        m_char_reverse_lm_text_score_cache.Free;
        m_char_reverse_lm_text_score_cache := nil;
    end;
    if m_char_reverse_lm_text_score_cache_order <> nil then
    begin
        m_char_reverse_lm_text_score_cache_order.Free;
        m_char_reverse_lm_text_score_cache_order := nil;
    end;
    if m_compound_tail_support_cache <> nil then
    begin
        m_compound_tail_support_cache.Free;
        m_compound_tail_support_cache := nil;
    end;
    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Free;
        m_candidate_penalty_cache := nil;
    end;
    if m_candidate_penalty_pinyin_loaded_cache <> nil then
    begin
        m_candidate_penalty_pinyin_loaded_cache.Free;
        m_candidate_penalty_pinyin_loaded_cache := nil;
    end;
    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Free;
        m_query_path_penalty_cache := nil;
    end;
    if m_lookup_result_cache <> nil then
    begin
        m_lookup_result_cache.Free;
        m_lookup_result_cache := nil;
    end;
    if m_mixed_abbreviation_cache <> nil then
    begin
        m_mixed_abbreviation_cache.Free;
        m_mixed_abbreviation_cache := nil;
    end;
    if m_word_completion_cache <> nil then
    begin
        m_word_completion_cache.Free;
        m_word_completion_cache := nil;
    end;
    if m_next_character_cache <> nil then
    begin
        m_next_character_cache.Free;
        m_next_character_cache := nil;
    end;
    if m_lookup_result_cache_order <> nil then
    begin
        m_lookup_result_cache_order.Free;
        m_lookup_result_cache_order := nil;
    end;
    if m_exact_lookup_result_cache <> nil then
    begin
        m_exact_lookup_result_cache.Free;
        m_exact_lookup_result_cache := nil;
    end;
    if m_exact_lookup_result_cache_order <> nil then
    begin
        m_exact_lookup_result_cache_order.Free;
        m_exact_lookup_result_cache_order := nil;
    end;
    if m_exact_component_lookup_cache <> nil then
    begin
        m_exact_component_lookup_cache.Free;
        m_exact_component_lookup_cache := nil;
    end;
    if m_exact_component_lookup_cache_order <> nil then
    begin
        m_exact_component_lookup_cache_order.Free;
        m_exact_component_lookup_cache_order := nil;
    end;
    if m_prefix_lookup_result_cache <> nil then
    begin
        m_prefix_lookup_result_cache.Free;
        m_prefix_lookup_result_cache := nil;
    end;
    if m_one_key_completion_cache <> nil then
    begin
        m_one_key_completion_cache.Free;
        m_one_key_completion_cache := nil;
    end;
    FreeAndNil(m_candidate_prefix_completion_cache);
    if m_long_one_key_completion_cache <> nil then
    begin
        m_long_one_key_completion_cache.Free;
        m_long_one_key_completion_cache := nil;
    end;
    if m_one_key_completion_competition_cache <> nil then
    begin
        m_one_key_completion_competition_cache.Free;
        m_one_key_completion_competition_cache := nil;
    end;
    if m_one_key_completion_pair_audit_cache <> nil then
    begin
        m_one_key_completion_pair_audit_cache.Free;
        m_one_key_completion_pair_audit_cache := nil;
    end;
    FreeAndNil(m_short_promotion_cache);
    if m_exact_text_prefix_cache <> nil then
    begin
        m_exact_text_prefix_cache.Free;
        m_exact_text_prefix_cache := nil;
    end;
    if m_literal_lookup_result_cache <> nil then
    begin
        m_literal_lookup_result_cache.Free;
        m_literal_lookup_result_cache := nil;
    end;
    if m_exact_base_entry_cache <> nil then
    begin
        m_exact_base_entry_cache.Free;
        m_exact_base_entry_cache := nil;
    end;
    if m_normalized_base_entry_cache <> nil then
    begin
        m_normalized_base_entry_cache.Free;
        m_normalized_base_entry_cache := nil;
    end;
    if m_explicit_user_entry_cache <> nil then
    begin
        m_explicit_user_entry_cache.Free;
        m_explicit_user_entry_cache := nil;
    end;
    if m_literal_user_entry_cache <> nil then
    begin
        m_literal_user_entry_cache.Free;
        m_literal_user_entry_cache := nil;
    end;
    if m_admin_place_longer_prefix_cache <> nil then
    begin
        m_admin_place_longer_prefix_cache.Free;
        m_admin_place_longer_prefix_cache := nil;
    end;
    if m_admin_place_query_syllable_count_cache <> nil then
    begin
        m_admin_place_query_syllable_count_cache.Free;
        m_admin_place_query_syllable_count_cache := nil;
    end;

    inherited Destroy;
end;

function TncSqliteDictionary.get_last_lookup_debug_hint: string;
begin
    Result := m_last_lookup_debug_hint;
end;

function TncSqliteDictionary.get_prefix_popularity_hint(const prefix: string): Integer;
begin
    Result := get_prefix_popularity_score(Trim(prefix));
end;

function TncSqliteDictionary.get_base_text_prefix_bonus(const prefix_text: string): Integer;
var
    normalized_prefix: string;
    prefix_score: Integer;
    contains_score: Integer;
begin
    Result := 0;
    normalized_prefix := Trim(prefix_text);
    if (normalized_prefix = '') or (Length(normalized_prefix) < 2) or
        (Length(normalized_prefix) > 6) or (not ensure_open) or
        (not m_base_ready) then
    begin
        Exit;
    end;

    prefix_score := get_prefix_popularity_score(normalized_prefix);
    contains_score := get_contains_popularity_score(normalized_prefix);
    Result := Min(6400, (prefix_score div 16) + (contains_score div 32));
end;

procedure TncSqliteDictionary.set_fuzzy_pinyin_config(
    const enabled: Boolean; const rules: TncFuzzyPinyinRules);
begin
    if (m_fuzzy_pinyin_enabled = enabled) and
        (m_fuzzy_pinyin_rules = rules) then
    begin
        Exit;
    end;

    m_fuzzy_pinyin_enabled := enabled;
    m_fuzzy_pinyin_rules := rules;
    if m_fuzzy_lookup_result_cache <> nil then
    begin
        m_fuzzy_lookup_result_cache.Clear;
    end;
    if m_fuzzy_lookup_result_cache_order <> nil then
    begin
        m_fuzzy_lookup_result_cache_order.Clear;
    end;
end;

procedure TncSqliteDictionary.load_fuzzy_choice_bonuses(
    const pinyin: string);
const
    query_sql =
        'SELECT text, commit_count FROM dict_user_fuzzy_choice ' +
        'WHERE pinyin = ?1';
    c_choice_bonus_per_commit = 160;
    c_choice_bonus_cap = 640;
var
    query_key: string;
    cache_key: string;
    text_value: string;
    commit_count: Integer;
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    query_key := normalize_canonical_pinyin_key(pinyin);
    if (query_key = '') or (m_fuzzy_choice_query_loaded_cache = nil) or
        m_fuzzy_choice_query_loaded_cache.ContainsKey(query_key) then
    begin
        Exit;
    end;

    m_fuzzy_choice_query_loaded_cache.Add(query_key, True);
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if (not m_user_connection.prepare(query_sql, stmt)) or
            (not m_user_connection.bind_text(stmt, 1, query_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            text_value := Trim(m_user_connection.column_text(stmt, 0));
            commit_count := m_user_connection.column_int(stmt, 1);
            if (text_value <> '') and (commit_count > 0) and
                (m_fuzzy_choice_bonus_cache <> nil) then
            begin
                cache_key := query_key + #1 + text_value;
                m_fuzzy_choice_bonus_cache.AddOrSetValue(cache_key,
                    Min(c_choice_bonus_cap,
                    commit_count * c_choice_bonus_per_commit));
            end;
            step_result := m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.get_fuzzy_choice_bonus(const pinyin: string;
    const text: string): Integer;
var
    query_key: string;
    cache_key: string;
begin
    Result := 0;
    query_key := normalize_canonical_pinyin_key(pinyin);
    if (query_key = '') or (Trim(text) = '') then
    begin
        Exit;
    end;

    load_fuzzy_choice_bonuses(query_key);
    cache_key := query_key + #1 + Trim(text);
    if m_fuzzy_choice_bonus_cache <> nil then
    begin
        m_fuzzy_choice_bonus_cache.TryGetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.lookup_fuzzy_full_pinyin(const pinyin: string;
    out results: TncCandidateList): Boolean;
begin
    Result := lookup_fuzzy_full_pinyin_bounded(pinyin, results, 4, 16, 4, 0);
end;

function TncSqliteDictionary.lookup_fuzzy_full_pinyin_bounded(
    const pinyin: string; out results: TncCandidateList;
    const max_cost: Integer; const max_variants: Integer;
    const max_syllables: Integer;
    const max_candidates_per_variant: Integer): Boolean;
const
    c_fuzzy_result_cache_limit = 4096;
var
    query_key: string;
    cache_key: string;
    variants: TncFuzzyPinyinQueryVariants;
    variant_results: TncCandidateList;
    expected_units: Integer;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Integer>;
    variant: TncFuzzyPinyinQueryVariant;
    candidate: TncCandidate;
    existing: TncCandidate;
    candidate_idx: Integer;
    candidate_high: Integer;
    existing_idx: Integer;
    output_idx: Integer;
    key: string;
    preserve_boundaries: Boolean;

    procedure cache_results(const values: TncCandidateList);
    var
        evicted_cache_key: string;
    begin
        if m_fuzzy_lookup_result_cache = nil then
        begin
            Exit;
        end;

        while m_fuzzy_lookup_result_cache.Count >=
            c_fuzzy_result_cache_limit do
        begin
            if (m_fuzzy_lookup_result_cache_order = nil) or
                (m_fuzzy_lookup_result_cache_order.Count = 0) then
            begin
                m_fuzzy_lookup_result_cache.Clear;
                Break;
            end;
            evicted_cache_key := m_fuzzy_lookup_result_cache_order.Dequeue;
            m_fuzzy_lookup_result_cache.Remove(evicted_cache_key);
        end;
        m_fuzzy_lookup_result_cache.AddOrSetValue(cache_key,
            Copy(values, 0, Length(values)));
        if m_fuzzy_lookup_result_cache_order <> nil then
        begin
            m_fuzzy_lookup_result_cache_order.Enqueue(cache_key);
        end;
    end;

begin
    SetLength(results, 0);
    Result := False;
    if (not m_fuzzy_pinyin_enabled) or (m_fuzzy_pinyin_rules = []) then
    begin
        Exit;
    end;
    if (max_cost <= 0) or (max_variants <= 0) or
        (max_syllables <= 0) then
    begin
        Exit;
    end;

    query_key := normalize_canonical_pinyin_key(pinyin);
    if (query_key = '') or (not ensure_open) then
    begin
        Exit;
    end;
    cache_key := query_key + #1 + IntToStr(max_cost) + #1 +
        IntToStr(max_variants) + #1 + IntToStr(max_syllables) + #1 +
        IntToStr(max_candidates_per_variant);
    if (m_fuzzy_lookup_result_cache <> nil) and
        m_fuzzy_lookup_result_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    variants := nc_build_fuzzy_query_variants(query_key,
        m_fuzzy_pinyin_rules, max_cost, max_variants, max_syllables);
    if Length(variants) = 0 then
    begin
        cache_results(results);
        Exit;
    end;

    expected_units := variants[0].syllable_count;
    if expected_units <= 0 then
    begin
        Exit;
    end;

    preserve_boundaries := Pos('''', query_key) > 0;
    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Integer>.Create;
    try
        for variant in variants do
        begin
            if preserve_boundaries then
            begin
                if not lookup_exact_full_pinyin_internal(variant.text,
                    variant_results, True) then
                begin
                    Continue;
                end;
            end
            else if not lookup_isolated_exact_component_internal(
                variant.text, variant_results, True) then
            begin
                Continue;
            end;

            candidate_high := High(variant_results);
            if (max_candidates_per_variant > 0) and
                (candidate_high >= max_candidates_per_variant) then
            begin
                candidate_high := max_candidates_per_variant - 1;
            end;
            for candidate_idx := 0 to candidate_high do
            begin
                candidate := variant_results[candidate_idx];
                candidate.text := Trim(candidate.text);
                if (candidate.text = '') or
                    (Trim(candidate.comment) <> '') or
                    (get_valid_cjk_codepoint_count(candidate.text) <>
                    expected_units) then
                begin
                    Continue;
                end;
                if preserve_boundaries and
                    (not strict_full_pinyin_text_alignment_valid(
                    variant.text, candidate.text)) then
                begin
                    Continue;
                end;

                candidate.score := candidate.score -
                    variant.cost * c_fuzzy_lookup_penalty_per_cost +
                    get_fuzzy_choice_bonus(query_key, candidate.text);
                candidate.source := cs_rule;
                candidate.fuzzy_cost := variant.cost;
                candidate.fuzzy_rules := variant.rules;
                key := LowerCase(candidate.text) + #1 +
                    LowerCase(Trim(candidate.comment));
                if seen.TryGetValue(key, existing_idx) then
                begin
                    existing := list[existing_idx];
                    if (candidate.fuzzy_cost < existing.fuzzy_cost) or
                        ((candidate.fuzzy_cost = existing.fuzzy_cost) and
                        (candidate.score > existing.score)) then
                    begin
                        list[existing_idx] := candidate;
                    end;
                    Continue;
                end;

                seen.Add(key, list.Count);
                list.Add(candidate);
            end;
        end;

        list.Sort(TComparer<TncCandidate>.Construct(
            function(const left, right: TncCandidate): Integer
            begin
                Result := right.score - left.score;
                if Result = 0 then
                begin
                    Result := left.fuzzy_cost - right.fuzzy_cost;
                end;
                if Result = 0 then
                begin
                    Result := CompareText(left.text, right.text);
                end;
            end));

        SetLength(results, list.Count);
        for output_idx := 0 to list.Count - 1 do
        begin
            results[output_idx] := list[output_idx];
        end;
    finally
        seen.Free;
        list.Free;
    end;

    Result := Length(results) > 0;
    cache_results(results);
end;

procedure TncSqliteDictionary.record_fuzzy_choice(const pinyin: string;
    const text: string);
const
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_fuzzy_choice' +
        '(pinyin, text, commit_count, last_used) ' +
        'VALUES(?1, ?2, 0, strftime(''%s'',''now''))';
    update_sql =
        'UPDATE dict_user_fuzzy_choice SET ' +
        'commit_count = MIN(commit_count + 1, 1000000), ' +
        'last_used = strftime(''%s'',''now'') ' +
        'WHERE pinyin = ?1 AND text = ?2';
var
    query_key: string;
    text_value: string;
    stmt: Psqlite3_stmt;
    write_ok: Boolean;

    function execute_statement(const sql_text: string): Boolean;
    begin
        Result := False;
        stmt := nil;
        try
            if (not m_user_connection.prepare(sql_text, stmt)) or
                (not m_user_connection.bind_text(stmt, 1, query_key)) or
                (not m_user_connection.bind_text(stmt, 2, text_value)) then
            begin
                Exit;
            end;
            Result := m_user_connection.step(stmt) = SQLITE_DONE;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    query_key := normalize_canonical_pinyin_key(pinyin);
    text_value := Trim(text);
    if (query_key = '') or (text_value = '') or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    write_ok := execute_statement(insert_sql);
    if write_ok then
    begin
        write_ok := execute_statement(update_sql);
    end;
    if write_ok then
    begin
        note_user_data_changed;
    end;
end;

function TncSqliteDictionary.lookup_full_pinyin_prefix(const pinyin_prefix: string;
    out results: TncCandidateList): Boolean;
const
    c_result_cache_limit = 4096;
    base_prefix_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND weight > 0 ' +
        'ORDER BY pinyin ASC, weight DESC, text ASC LIMIT ?3';
    user_prefix_sql =
        'SELECT pinyin, text, weight, last_used FROM dict_user ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?3';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    item: TncCandidate;
    limit_value: Integer;
    normalized_prefix: string;
    upper_bound: string;
    seen: TDictionary<string, Boolean>;
    candidate_pinyin: string;
    candidate_text: string;
    candidate_comment: string;
    seen_key: string;
begin
    SetLength(results, 0);
    Result := False;
    if pinyin_prefix = '' then
    begin
        Exit;
    end;
    if not ensure_open or (not m_base_ready) then
    begin
        Exit;
    end;

    normalized_prefix := LowerCase(Trim(pinyin_prefix));
    if normalized_prefix = '' then
    begin
        Exit;
    end;

    if (m_prefix_lookup_result_cache <> nil) and
        m_prefix_lookup_result_cache.TryGetValue(normalized_prefix, results) then
    begin
        results := Copy(results, 0, Length(results));
        if m_debug_mode then
        begin
            m_last_lookup_debug_hint := Format('dict=[prefix_cache=1 n=%d]',
                [Length(results)]);
        end;
        Exit(Length(results) > 0);
    end;

    if Length(normalized_prefix) >= 12 then
    begin
        limit_value := 16;
    end
    else if Length(normalized_prefix) >= 8 then
    begin
        limit_value := 24;
    end
    else
    begin
        limit_value := Max(m_limit * 2, 16);
        if limit_value > 48 then
        begin
            limit_value := 48;
        end;
    end;

    upper_bound := build_prefix_upper_bound(normalized_prefix);
    if upper_bound = '' then
    begin
        Exit;
    end;

    stmt := nil;
    seen := TDictionary<string, Boolean>.Create;
    try
        try
            if not m_base_connection.prepare(base_prefix_sql, stmt) or
                (not m_base_connection.bind_text(stmt, 1, normalized_prefix)) or
                (not m_base_connection.bind_text(stmt, 2, upper_bound)) or
                (not m_base_connection.bind_int(stmt, 3, limit_value)) then
            begin
                Exit;
            end;

            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                candidate_text := m_base_connection.column_text(stmt, 1);
                candidate_comment := m_base_connection.column_text(stmt, 2);
                seen_key := candidate_pinyin + #0 + candidate_text + #0 + candidate_comment;
                if seen.ContainsKey(seen_key) then
                begin
                    step_result := m_base_connection.step(stmt);
                    Continue;
                end;
                seen.Add(seen_key, True);
                item := Default(TncCandidate);
                item.text := candidate_text;
                item.comment := candidate_comment;
                item.dict_weight := m_base_connection.column_int(stmt, 3);
                item.score := item.dict_weight;
                item.source := cs_rule;
                item.has_dict_weight := True;
                item.fuzzy_cost := 0;
                item.fuzzy_rules := [];
                SetLength(results, Length(results) + 1);
                results[High(results)] := item;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
            stmt := nil;
        end;

        if m_user_ready then
        begin
            try
                if m_user_connection.prepare(user_prefix_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, normalized_prefix) and
                    m_user_connection.bind_text(stmt, 2, upper_bound) and
                    m_user_connection.bind_int(stmt, 3, limit_value) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_user_connection.column_text(stmt, 0);
                        candidate_text := user_text_for_script(candidate_pinyin,
                            m_user_connection.column_text(stmt, 1));
                        seen_key := candidate_pinyin + #0 + candidate_text + #0;
                        if seen.ContainsKey(seen_key) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        seen.Add(seen_key, True);
                        item := Default(TncCandidate);
                        item.text := candidate_text;
                        item.comment := '';
                        item.dict_weight := m_user_connection.column_int(stmt, 2);
                        item.score := item.dict_weight;
                        item.source := cs_user;
                        item.has_dict_weight := False;
                        item.fuzzy_cost := 0;
                        item.fuzzy_rules := [];
                        SetLength(results, Length(results) + 1);
                        results[High(results)] := item;
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;
    finally
        seen.Free;
    end;

    Result := Length(results) > 0;
    if m_prefix_lookup_result_cache <> nil then
    begin
        if m_prefix_lookup_result_cache.Count >= c_result_cache_limit then
        begin
            m_prefix_lookup_result_cache.Clear;
        end;
        m_prefix_lookup_result_cache.AddOrSetValue(normalized_prefix,
            Copy(results, 0, Length(results)));
    end;
end;

function TncSqliteDictionary.lookup_word_completions(const syllables: TArray<string>;
    const max_syllables, limit: Integer; out results: TncOneKeyCompletionList): Boolean;
const
    c_cache_limit = 4096;
    // Heavier words sharing the leading letters (e.g. "xiang..." for "xian")
    // fail the syllable check, so read more rows than are returned.
    c_scan_limit = 400;
    base_sql =
        'SELECT pinyin, text, weight FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND weight > 0 AND ' +
        '(comment IS NULL OR comment = '''') ' +
        'ORDER BY weight DESC, text ASC LIMIT ?3';
var
    cache_key, prefix, upper_bound, stored_pinyin, text_value, remainder: string;
    parser: TncPinyinParser;
    list: TList<TncOneKeyCompletion>;
    seen: TDictionary<string, Boolean>;
    item: TncOneKeyCompletion;
    stmt: Psqlite3_stmt;
    step_result, idx, unit_idx, units, weight: Integer;
    aligned: Boolean;
begin
    SetLength(results, 0);
    Result := False;
    if (Length(syllables) = 0) or (limit <= 0) or (max_syllables <= Length(syllables)) then
        Exit;
    prefix := '';
    for idx := 0 to High(syllables) do
    begin
        if not nc_is_canonical_pinyin_syllable(LowerCase(Trim(syllables[idx]))) then
            Exit;
        prefix := prefix + LowerCase(Trim(syllables[idx]));
    end;
    cache_key := string.Join('''', syllables).ToLower + '|' + IntToStr(max_syllables) + '|' +
        IntToStr(limit);
    if (m_word_completion_cache <> nil) and
        m_word_completion_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;
    if (not ensure_open) or (not m_base_ready) then
        Exit;
    upper_bound := Copy(prefix, 1, Length(prefix) - 1) + Chr(Ord(prefix[Length(prefix)]) + 1);

    parser := TncPinyinParser.create;
    list := TList<TncOneKeyCompletion>.Create;
    seen := TDictionary<string, Boolean>.Create;
    stmt := nil;
    try
        if m_base_connection.prepare(base_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, prefix) and
            m_base_connection.bind_text(stmt, 2, upper_bound) and
            m_base_connection.bind_int(stmt, 3, c_scan_limit) then
        begin
            step_result := m_base_connection.step(stmt);
            while (step_result = SQLITE_ROW) and (list.Count < limit) do
            begin
                stored_pinyin := LowerCase(m_base_connection.column_text(stmt, 0));
                text_value := Trim(m_base_connection.column_text(stmt, 1));
                weight := m_base_connection.column_int(stmt, 2);
                step_result := m_base_connection.step(stmt);
                units := 0;
                idx := 1;
                while idx <= Length(text_value) do
                begin
                    if (Ord(text_value[idx]) >= $D800) and (Ord(text_value[idx]) <= $DBFF) then
                        Inc(idx);
                    Inc(idx);
                    Inc(units);
                end;
                if (text_value = '') or seen.ContainsKey(text_value) or
                    (units <= Length(syllables)) or (units > max_syllables) then
                    Continue;
                // The typed syllables must end at a syllable boundary: the rest
                // parses into exactly the word's remaining characters (e.g.
                // "xiangfa" leaves "gfa" after "xian"). An apostrophe after the
                // prefix marks the boundary; one inside it moves the boundary.
                remainder := Copy(stored_pinyin, Length(prefix) + 1, MaxInt);
                if (Pos('''', Copy(stored_pinyin, 1, Length(prefix))) > 0) then
                    Continue;
                remainder := StringReplace(remainder, '''', '', [rfReplaceAll]);
                if not nc_word_completion_remainder_fits(parser, remainder,
                    units - Length(syllables)) then
                    Continue;
                // The letters alone do not fix the boundaries: "xi'nan" and
                // 新安县 (xin'an'xian) share "xinan". Each typed syllable must be
                // a reading of its own character.
                aligned := True;
                for unit_idx := 0 to High(syllables) do
                    if not single_char_matches_pinyin(LowerCase(Trim(syllables[unit_idx])),
                        Copy(text_value, unit_idx + 1, 1)) then
                    begin
                        aligned := False;
                        Break;
                    end;
                if not aligned then
                    Continue;
                seen.Add(text_value, True);
                item := Default(TncOneKeyCompletion);
                item.text := text_value;
                item.full_pinyin := prefix + remainder;
                item.weight := weight;
                item.source := okcs_base_exact;
                list.Add(item);
            end;
        end;
    finally
        if stmt <> nil then
            m_base_connection.finalize(stmt);
        seen.Free;
        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
            results[idx] := list[idx];
        list.Free;
        parser.Free;
    end;
    if m_word_completion_cache <> nil then
    begin
        if m_word_completion_cache.Count >= c_cache_limit then
            m_word_completion_cache.Clear;
        m_word_completion_cache.AddOrSetValue(cache_key, Copy(results, 0, Length(results)));
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_next_characters(const tail: string;
    const limit: Integer; out characters: TArray<string>): Boolean;
const
    c_cache_limit = 8192;
    next_sql =
        'SELECT ngram FROM dict_base_char_lm WHERE ngram > ?1 AND ngram < ?2 AND ' +
        'length(ngram) = ?3 ORDER BY score DESC, ngram ASC LIMIT ?4';
var
    cache_key, ngram, ch: string;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    list: TList<string>;
begin
    SetLength(characters, 0);
    Result := False;
    if (tail = '') or (limit <= 0) then
        Exit;
    cache_key := tail + #1 + IntToStr(limit);
    if (m_next_character_cache <> nil) and
        m_next_character_cache.TryGetValue(cache_key, characters) then
    begin
        characters := Copy(characters, 0, Length(characters));
        Exit(Length(characters) > 0);
    end;
    if (not ensure_open) or (not m_base_ready) then
        Exit;
    list := TList<string>.Create;
    stmt := nil;
    try
        // Read a few extra rows: sentence markers are not characters to type.
        if m_base_connection.prepare(next_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, tail) and
            m_base_connection.bind_text(stmt, 2, tail + #$FFFF) and
            m_base_connection.bind_int(stmt, 3, Length(tail) + 1) and
            m_base_connection.bind_int(stmt, 4, limit + 2) then
        begin
            step_result := m_base_connection.step(stmt);
            while (step_result = SQLITE_ROW) and (list.Count < limit) do
            begin
                ngram := m_base_connection.column_text(stmt, 0);
                step_result := m_base_connection.step(stmt);
                if Length(ngram) <> Length(tail) + 1 then
                    Continue;
                ch := Copy(ngram, Length(ngram), 1);
                if (ch < #$4E00) or list.Contains(ch) then
                    Continue;
                list.Add(ch);
            end;
        end;
    finally
        if stmt <> nil then
            m_base_connection.finalize(stmt);
        characters := list.ToArray;
        list.Free;
    end;
    if m_next_character_cache <> nil then
    begin
        if m_next_character_cache.Count >= c_cache_limit then
            m_next_character_cache.Clear;
        m_next_character_cache.AddOrSetValue(cache_key, Copy(characters, 0, Length(characters)));
    end;
    Result := Length(characters) > 0;
end;

function TncSqliteDictionary.lookup_words_starting_with(const prefix: string;
    const min_length, max_length, limit: Integer;
    out results: TncOneKeyCompletionList): Boolean;
const
    c_cache_limit = 8192;
    words_sql =
        'SELECT pinyin, text, weight FROM dict_base WHERE text >= ?1 AND text < ?2 AND ' +
        'weight > 0 AND (comment IS NULL OR comment = '''') AND ' +
        'length(text) BETWEEN ?3 AND ?4 ORDER BY weight DESC, text ASC LIMIT ?5';
var
    cache_key, text_value: string;
    stmt: Psqlite3_stmt;
    step_result, idx: Integer;
    list: TList<TncOneKeyCompletion>;
    item: TncOneKeyCompletion;
begin
    SetLength(results, 0);
    Result := False;
    if (prefix = '') or (limit <= 0) or (min_length < 1) or (max_length < min_length) then
        Exit;
    cache_key := #2 + prefix + #1 + IntToStr(min_length) + #1 + IntToStr(max_length) + #1 +
        IntToStr(limit);
    if (m_word_completion_cache <> nil) and
        m_word_completion_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;
    if (not ensure_open) or (not m_base_ready) then
        Exit;
    list := TList<TncOneKeyCompletion>.Create;
    stmt := nil;
    try
        if m_base_connection.prepare(words_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, prefix) and
            m_base_connection.bind_text(stmt, 2, prefix + #$FFFF) and
            m_base_connection.bind_int(stmt, 3, min_length) and
            m_base_connection.bind_int(stmt, 4, max_length) and
            m_base_connection.bind_int(stmt, 5, limit * 2) then
        begin
            step_result := m_base_connection.step(stmt);
            while (step_result = SQLITE_ROW) and (list.Count < limit) do
            begin
                text_value := Trim(m_base_connection.column_text(stmt, 1));
                item := Default(TncOneKeyCompletion);
                item.full_pinyin := StringReplace(LowerCase(m_base_connection.column_text(stmt, 0)),
                    '''', '', [rfReplaceAll]);
                item.weight := m_base_connection.column_int(stmt, 2);
                step_result := m_base_connection.step(stmt);
                if (text_value = '') or (item.full_pinyin = '') then
                    Continue;
                // The first (heaviest) reading of each text.
                idx := 0;
                while (idx < list.Count) and (list[idx].text <> text_value) do
                    Inc(idx);
                if idx < list.Count then
                    Continue;
                item.text := text_value;
                item.source := okcs_base_exact;
                list.Add(item);
            end;
        end;
    finally
        if stmt <> nil then
            m_base_connection.finalize(stmt);
        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
            results[idx] := list[idx];
        list.Free;
    end;
    if m_word_completion_cache <> nil then
    begin
        if m_word_completion_cache.Count >= c_cache_limit then
            m_word_completion_cache.Clear;
        m_word_completion_cache.AddOrSetValue(cache_key, Copy(results, 0, Length(results)));
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_mixed_abbreviation_words(const pinyin: string;
    out results: TncCandidateList): Boolean;
const
    c_cache_limit = 4096;
    c_word_limit = 8;
    base_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_jianpin j INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE j.jianpin = ?1 ORDER BY b.weight DESC, b.text ASC LIMIT 512';
    user_sql =
        'SELECT pinyin, text, weight FROM dict_user WHERE pinyin LIKE ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT 256';
var
    query_key, like_pattern, jianpin_key, initial_value, candidate_pinyin, text_value: string;
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    tokens: TncMixedQueryTokenList;
    reconstructed: string;
    has_full, has_initial: Boolean;
    idx, merge_pass: Integer;
    ch: Char;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Boolean>;
    item: TncCandidate;

    function text_units(const value: string): Integer;
    var
        position: Integer;
    begin
        Result := 0;
        position := 1;
        while position <= Length(value) do
        begin
            if (Ord(value[position]) >= $D800) and (Ord(value[position]) <= $DBFF) and
                (position < Length(value)) then
                Inc(position);
            Inc(position);
            Inc(Result);
        end;
    end;

    procedure add_word(const value, word_pinyin, comment: string; const weight: Integer;
        const source: TncCandidateSource);
    begin
        if (value = '') or (comment <> '') or seen.ContainsKey(value) or
            (list.Count >= c_word_limit) or (text_units(value) <> Length(tokens)) or
            (not candidate_matches_mixed_jianpin(parser, word_pinyin, tokens)) then
            Exit;
        seen.Add(value, True);
        item := Default(TncCandidate);
        item.text := value;
        item.source := source;
        item.score := weight;
        item.has_dict_weight := True;
        item.dict_weight := weight;
        list.Add(item);
    end;

begin
    SetLength(results, 0);
    Result := False;
    query_key := LowerCase(Trim(pinyin));
    if (query_key = '') or (Length(query_key) > 48) then
        Exit;
    for ch in query_key do
        if not CharInSet(ch, ['a' .. 'z']) then
            Exit;
    if (m_mixed_abbreviation_cache <> nil) and
        m_mixed_abbreviation_cache.TryGetValue(query_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;
    if not ensure_open then
        Exit;

    // A mixed reading keeps valid syllables and treats every lone consonant
    // (including n, m and r, which are also syllables) as an abbreviation.
    parser := TncPinyinParser.create;
    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Boolean>.Create;
    try
      // "zh" typed as abbreviations may be z+h (two words) or zh (one word).
      for merge_pass := 0 to 1 do
      begin
        if list.Count > 0 then
            Break;
        syllables := parser.parse(query_key);
        if merge_pass = 0 then
            nc_merge_abbreviated_retroflex_initials(syllables)
        else if not (query_key.Contains('zh') or query_key.Contains('ch') or query_key.Contains('sh')) then
            Break;
        SetLength(tokens, Length(syllables));
        reconstructed := '';
        has_full := False;
        has_initial := False;
        jianpin_key := '';
        like_pattern := '';
        for idx := 0 to High(syllables) do
        begin
            reconstructed := reconstructed + syllables[idx].text;
            if ((Length(syllables[idx].text) = 1) and is_initial_letter(syllables[idx].text[1])) or
                (syllables[idx].text = 'zh') or (syllables[idx].text = 'ch') or
                (syllables[idx].text = 'sh') then
            begin
                tokens[idx].kind := mqt_initial;
                tokens[idx].text := syllables[idx].text;
                has_initial := True;
                like_pattern := like_pattern + syllables[idx].text + '%';
            end
            else if is_valid_candidate_syllable(syllables[idx].text) then
            begin
                tokens[idx].kind := mqt_full;
                tokens[idx].text := syllables[idx].text;
                has_full := True;
                like_pattern := like_pattern + syllables[idx].text;
            end
            else
            begin
                SetLength(tokens, 0);
                Break;
            end;
            initial_value := extract_syllable_initial(syllables[idx].text);
            if initial_value = '' then
                initial_value := syllables[idx].text;
            jianpin_key := jianpin_key + initial_value[1];
        end;
        if (Length(tokens) >= 2) and has_full and has_initial and
            SameText(reconstructed, query_key) then
        begin
            if m_user_ready then
            begin
                stmt := nil;
                try
                    if m_user_connection.prepare(user_sql, stmt) and
                        m_user_connection.bind_text(stmt, 1, like_pattern) then
                    begin
                        step_result := m_user_connection.step(stmt);
                        while step_result = SQLITE_ROW do
                        begin
                            candidate_pinyin := m_user_connection.column_text(stmt, 0);
                            text_value := m_user_connection.column_text(stmt, 1);
                            add_word(text_value, StringReplace(candidate_pinyin, '''', '', [rfReplaceAll]),
                                '', m_user_connection.column_int(stmt, 2), cs_user);
                            step_result := m_user_connection.step(stmt);
                        end;
                    end;
                finally
                    if stmt <> nil then
                        m_user_connection.finalize(stmt);
                end;
            end;
            if m_base_ready then
            begin
                stmt := nil;
                try
                    if m_base_connection.prepare(base_sql, stmt) and
                        m_base_connection.bind_text(stmt, 1, jianpin_key) then
                    begin
                        step_result := m_base_connection.step(stmt);
                        while (step_result = SQLITE_ROW) and (list.Count < c_word_limit) do
                        begin
                            candidate_pinyin := m_base_connection.column_text(stmt, 0);
                            text_value := m_base_connection.column_text(stmt, 1);
                            add_word(text_value, StringReplace(candidate_pinyin, '''', '', [rfReplaceAll]),
                                m_base_connection.column_text(stmt, 2),
                                m_base_connection.column_int(stmt, 3), cs_rule);
                            step_result := m_base_connection.step(stmt);
                        end;
                    end;
                finally
                    if stmt <> nil then
                        m_base_connection.finalize(stmt);
                end;
            end;
        end;
      end;
        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
            results[idx] := list[idx];
    finally
        seen.Free;
        list.Free;
        parser.Free;
    end;
    if m_mixed_abbreviation_cache <> nil then
    begin
        if m_mixed_abbreviation_cache.Count >= c_cache_limit then
            m_mixed_abbreviation_cache.Clear;
        m_mixed_abbreviation_cache.AddOrSetValue(query_key, Copy(results, 0, Length(results)));
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_candidate_prefix_completions(
    const pinyin_prefix: string; out results: TncOneKeyCompletionList): Boolean;
const
    c_probe_limit = 96;
    c_cache_limit = 128;
    select_sql =
        'SELECT b.pinyin, b.text, b.weight, ' +
        'COALESCE(p.popularity_prior, -1), COALESCE(p.corpus_score, 0), ' +
        'COALESCE(p.document_score, 0), COALESCE(p.source_count, 0), ' +
        'COALESCE(p.path_score, 0), COALESCE(p.vertical_penalty, 0), ' +
        'COALESCE(p.layer_kind, 0) FROM dict_base b ' +
        'LEFT JOIN dict_base_completion_prior p ON p.pinyin=b.pinyin AND p.text=b.text ';
    query_sql = 'WITH prefix_probe AS (' + select_sql +
        'WHERE b.pinyin > ?1 AND b.pinyin < ?2 AND b.weight > 0 AND b.comment='''' ' +
        'AND COALESCE(p.layer_kind, 0) <> 4 ' +
        'ORDER BY CASE WHEN p.corpus_score > 0 OR p.path_score >= 120 ' +
        'THEN 1 ELSE 0 END DESC, ' +
        '(COALESCE(p.popularity_prior,0) + b.weight) DESC, b.pinyin, b.text LIMIT ?3) ' +
        select_sql + 'WHERE b.pinyin = ?1 AND b.comment='''' ' +
        'UNION ALL SELECT * FROM prefix_probe';
var
    key, upper: string;
    stmt: Psqlite3_stmt;
    item: TncOneKeyCompletion;
    step_result: Integer;
begin
    Result := False;
    SetLength(results, 0);
    key := LowerCase(Trim(pinyin_prefix));
    if (Length(key) < 2) or (not ensure_open) or (not m_base_ready) then Exit;
    if m_candidate_prefix_completion_cache.TryGetValue(key, results) then
    begin
        results := Copy(results);
        Exit(Length(results) > 0);
    end;
    upper := build_prefix_upper_bound(key);
    if upper = '' then Exit;
    stmt := nil;
    try
        // This display-only probe is independent of Tab's Top-K and of the
        // unrestricted exact lookup. Rank before LIMIT, not by pinyin spelling.
        if not m_base_connection.prepare(query_sql, stmt) then
            Exit(inherited lookup_candidate_prefix_completions(key, results));
        if (not m_base_connection.bind_text(stmt, 1, key)) or
            (not m_base_connection.bind_text(stmt, 2, upper)) or
            (not m_base_connection.bind_int(stmt, 3, c_probe_limit)) then Exit;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            item := Default(TncOneKeyCompletion);
            item.full_pinyin := m_base_connection.column_text(stmt, 0);
            item.text := m_base_connection.column_text(stmt, 1);
            item.weight := m_base_connection.column_int(stmt, 2);
            item.popularity_prior := m_base_connection.column_int(stmt, 3);
            item.has_popularity_prior := item.popularity_prior >= 0;
            item.corpus_score := m_base_connection.column_int(stmt, 4);
            item.document_score := m_base_connection.column_int(stmt, 5);
            item.source_count := m_base_connection.column_int(stmt, 6);
            item.path_score := m_base_connection.column_int(stmt, 7);
            item.vertical_penalty := m_base_connection.column_int(stmt, 8);
            item.vertical_layer_kind := m_base_connection.column_int(stmt, 9);
            item.source := okcs_base_exact;
            SetLength(results, Length(results) + 1);
            results[High(results)] := item;
            step_result := m_base_connection.step(stmt);
        end;
        if step_result <> SQLITE_DONE then
        begin
            SetLength(results, 0);
            Exit;
        end;
    finally
        if stmt <> nil then m_base_connection.finalize(stmt);
    end;
    if m_candidate_prefix_completion_cache.Count >= c_cache_limit then
        m_candidate_prefix_completion_cache.Clear;
    m_candidate_prefix_completion_cache.AddOrSetValue(key, Copy(results));
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_one_key_completions(
    const pinyin_prefix: string;
    out results: TncOneKeyCompletionList): Boolean;
const
    c_result_cache_limit = 4096;
    c_result_limit = 32;
    c_query_limit = 256;
    c_source_result_limit = 8;
    c_base_exact_prefix_anchor_bonus = 80;
    base_completion_popularity_sql =
        'SELECT b.pinyin, b.text, b.weight, ' +
        'COALESCE(p.popularity_prior, -1), COALESCE(p.corpus_score, 0), ' +
        'COALESCE(p.document_score, 0), COALESCE(p.source_count, 0), ' +
        'COALESCE(p.path_score, 0), COALESCE(p.vertical_penalty, 0), ' +
        'COALESCE(p.layer_kind, 0) ' +
        'FROM dict_base b LEFT JOIN dict_base_completion_prior p ' +
        'ON p.pinyin = b.pinyin AND p.text = b.text ' +
        'WHERE b.pinyin >= ?1 AND b.pinyin < ?2 ' +
        'AND b.weight > 0 AND COALESCE(b.comment, '''') = '''' ' +
        'AND COALESCE(p.layer_kind, 0) <> 4 ' +
        'ORDER BY COALESCE(p.popularity_prior, -1) DESC, b.weight DESC, ' +
        'length(b.text) ASC, b.text ASC LIMIT ?3';
    base_completion_weight_sql =
        'SELECT b.pinyin, b.text, b.weight, ' +
        'COALESCE(p.popularity_prior, -1), COALESCE(p.corpus_score, 0), ' +
        'COALESCE(p.document_score, 0), COALESCE(p.source_count, 0), ' +
        'COALESCE(p.path_score, 0), COALESCE(p.vertical_penalty, 0), ' +
        'COALESCE(p.layer_kind, 0) ' +
        'FROM dict_base b LEFT JOIN dict_base_completion_prior p ' +
        'ON p.pinyin = b.pinyin AND p.text = b.text ' +
        'WHERE b.pinyin >= ?1 AND b.pinyin < ?2 ' +
        'AND b.weight > 0 AND COALESCE(b.comment, '''') = '''' ' +
        'AND COALESCE(p.layer_kind, 0) <> 4 ' +
        'ORDER BY b.weight DESC, length(b.text) ASC, b.text ASC LIMIT ?3';
    base_completion_lookup_sql =
        'SELECT full_pinyin, text, weight, popularity_prior, ' +
        'corpus_score, document_score, source_count, path_score, ' +
        'vertical_penalty, layer_kind, prefix_anchored ' +
        'FROM dict_base_completion_lookup WHERE typed_prefix = ?1 ' +
        'AND layer_kind <> 4 ' +
        'ORDER BY rank_order ASC LIMIT 16';
    user_completion_sql =
        'SELECT pinyin, text, weight, last_used FROM dict_user ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?3';
    literal_completion_sql =
        'SELECT pinyin, text, created_at FROM dict_user_literal ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY created_at DESC, text ASC LIMIT ?3';
    transition_completion_sql =
        'SELECT full_pinyin, text, path_text, evidence ' +
        'FROM dict_base_transition_completion ' +
        'WHERE typed_prefix = ?1 AND evidence > 0 ' +
        'ORDER BY evidence DESC, length(text) ASC, text ASC LIMIT ?2';
    transition_completion_partial_sql =
        'SELECT full_pinyin, text, path_text, evidence ' +
        'FROM dict_base_transition_completion ' +
        'WHERE typed_prefix >= ?1 AND typed_prefix < ?2 AND evidence > 0 ' +
        'ORDER BY evidence DESC, length(text) ASC, text ASC LIMIT ?3';
    feedback_sql =
        'SELECT full_pinyin, text, accept_count, reject_count ' +
        'FROM dict_user_completion_feedback WHERE typed_prefix = ?1';
type
    TncRankedCompletion = record
        item: TncOneKeyCompletion;
        primary: Integer;
        secondary: Int64;
    end;
    TncRankedCompletionList = array of TncRankedCompletion;
var
    canonical_prefix: string;
    compact_prefix: string;
    lookup_prefix: string;
    explicit_prefix: string;
    cache_key: string;
    prefix_syllables: TArray<string>;
    prefix_idx: Integer;
    exact_prefix_texts: TDictionary<string, Boolean>;
    user_items: TncRankedCompletionList;
    base_items: TncRankedCompletionList;
    base_weight_items: TncRankedCompletionList;
    transition_items: TncRankedCompletionList;

    function resolve_lookup_prefix: Boolean;
    var
        trial_prefix: string;
        trial_compact: string;
        trial_syllables: TArray<string>;
        trial_length: Integer;
    begin
        Result := False;
        prefix_syllables := split_full_pinyin_syllables(canonical_prefix);
        if Length(prefix_syllables) >= 2 then
        begin
            lookup_prefix := compact_prefix;
            Exit(True);
        end;

        // The offline lookup is indexed at completed syllable boundaries.
        // While the user types the next syllable, reuse the nearest completed
        // prefix and filter every returned row by the full raw key below.
        for trial_length := Length(canonical_prefix) - 1 downto 1 do
        begin
            trial_prefix := Copy(canonical_prefix, 1, trial_length);
            while (trial_prefix <> '') and
                (trial_prefix[Length(trial_prefix)] = '''') do
            begin
                Delete(trial_prefix, Length(trial_prefix), 1);
            end;
            if trial_prefix = '' then
            begin
                Continue;
            end;
            trial_syllables := split_full_pinyin_syllables(trial_prefix);
            if Length(trial_syllables) < 2 then
            begin
                Continue;
            end;
            trial_compact := normalize_compact_pinyin_key(trial_prefix);
            if (Length(trial_compact) >= Length(compact_prefix)) or
                (not compact_prefix.StartsWith(trial_compact, True)) then
            begin
                Continue;
            end;
            prefix_syllables := trial_syllables;
            lookup_prefix := trial_compact;
            Exit(True);
        end;
    end;

    function ranked_better(const left_item: TncRankedCompletion;
        const right_item: TncRankedCompletion): Boolean;
    begin
        if left_item.primary <> right_item.primary then
        begin
            Exit(left_item.primary > right_item.primary);
        end;
        if left_item.secondary <> right_item.secondary then
        begin
            Exit(left_item.secondary > right_item.secondary);
        end;
        Result := CompareText(left_item.item.text, right_item.item.text) < 0;
    end;

    procedure sort_ranked(var items: TncRankedCompletionList);
    var
        left_idx: Integer;
        right_idx: Integer;
        best_idx: Integer;
        swap_item: TncRankedCompletion;
    begin
        for left_idx := 0 to High(items) - 1 do
        begin
            best_idx := left_idx;
            for right_idx := left_idx + 1 to High(items) do
            begin
                if ranked_better(items[right_idx], items[best_idx]) then
                begin
                    best_idx := right_idx;
                end;
            end;
            if best_idx <> left_idx then
            begin
                swap_item := items[left_idx];
                items[left_idx] := items[best_idx];
                items[best_idx] := swap_item;
            end;
        end;
    end;

    function minimum_primary(
        const items: TncRankedCompletionList): Integer;
    var
        item_idx: Integer;
    begin
        Result := MaxInt;
        for item_idx := 0 to High(items) do
        begin
            if items[item_idx].primary < Result then
            begin
                Result := items[item_idx].primary;
            end;
        end;
    end;

    procedure load_exact_prefix_texts;
    const
        exact_prefix_sql =
            'SELECT pinyin, text FROM dict_base ' +
            'WHERE pinyin = ?1 OR pinyin = ?2';
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        stored_pinyin: string;
        stored_text: string;
    begin
        stmt := nil;
        try
            if (not m_base_connection.prepare(exact_prefix_sql, stmt)) or
                (not m_base_connection.bind_text(stmt, 1,
                lookup_prefix)) or
                (not m_base_connection.bind_text(stmt, 2,
                explicit_prefix)) then
            begin
                Exit;
            end;
            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                stored_pinyin := m_base_connection.column_text(stmt, 0);
                stored_text := Trim(m_base_connection.column_text(stmt, 1));
                if (stored_text <> '') and same_normalized_pinyin_key(
                    stored_pinyin, lookup_prefix) then
                begin
                    exact_prefix_texts.AddOrSetValue(stored_text, True);
                end;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;
    end;

    function candidate_matches_prefix(const candidate_pinyin: string;
        const candidate_text: string; out candidate_compact_pinyin: string): Boolean;
    var
        candidate_syllables: TArray<string>;
        syllable_idx: Integer;
        tail_idx: Integer;
        tail_fragment: string;
    begin
        candidate_compact_pinyin := normalize_compact_pinyin_key(
            candidate_pinyin);
        candidate_syllables := split_full_pinyin_syllables(
            normalize_canonical_pinyin_key(candidate_pinyin));
        Result :=
            (Length(candidate_syllables) > 0) and
            (Length(candidate_compact_pinyin) > Length(compact_prefix)) and
            candidate_compact_pinyin.StartsWith(compact_prefix, True) and
            (get_text_unit_count_local(candidate_text) =
            Length(candidate_syllables));
        if not Result then
        begin
            Exit;
        end;
        for syllable_idx := 0 to High(prefix_syllables) do
        begin
            if (syllable_idx <= High(candidate_syllables)) and
                SameText(prefix_syllables[syllable_idx],
                candidate_syllables[syllable_idx]) then
            begin
                Continue;
            end;

            // The parser may interpret an unfinished tail as another valid
            // syllable (li) or as two short syllables (li/a), although the
            // user is still typing liao. Rejoin only a short final fragment;
            // longer complete syllables such as xian remain strict boundaries.
            tail_fragment := '';
            for tail_idx := syllable_idx to High(prefix_syllables) do
            begin
                tail_fragment := tail_fragment + prefix_syllables[tail_idx];
            end;
            Result := (syllable_idx <= High(candidate_syllables)) and
                (Length(tail_fragment) >= 1) and
                (Length(tail_fragment) <= 3) and
                (Length(tail_fragment) <
                Length(candidate_syllables[syllable_idx])) and
                candidate_syllables[syllable_idx].StartsWith(tail_fragment,
                True);
            Exit;
        end;
        Result := Length(candidate_syllables) > Length(prefix_syllables);
    end;

    function transition_prefix_is_exact_boundary(
        const candidate_path: string): Boolean;
    var
        separator_idx: Integer;
        left_text: string;
    begin
        separator_idx := Pos(#3, candidate_path);
        if separator_idx <= 1 then
        begin
            Exit(False);
        end;
        left_text := Copy(candidate_path, 1, separator_idx - 1);
        Result := get_text_unit_count_local(left_text) =
            Length(prefix_syllables);
    end;

    function query_precomputed_base: Boolean;
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        item: TncOneKeyCompletion;
        candidate_pinyin: string;
        candidate_text: string;
        candidate_compact_pinyin: string;
        result_idx: Integer;
        duplicate: Boolean;
    begin
        Result := False;
        stmt := nil;
        try
            if (not m_base_connection.prepare(base_completion_lookup_sql,
                stmt)) or
                (not m_base_connection.bind_text(stmt, 1, lookup_prefix)) then
            begin
                Exit;
            end;
            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                candidate_text := Trim(m_base_connection.column_text(stmt, 1));
                if not candidate_matches_prefix(candidate_pinyin,
                    candidate_text, candidate_compact_pinyin) then
                begin
                    step_result := m_base_connection.step(stmt);
                    Continue;
                end;
                duplicate := False;
                for result_idx := 0 to High(results) do
                begin
                    if SameText(results[result_idx].full_pinyin,
                        candidate_compact_pinyin) and
                        SameText(results[result_idx].text,
                        candidate_text) then
                    begin
                        duplicate := True;
                        Break;
                    end;
                end;
                if duplicate then
                begin
                    step_result := m_base_connection.step(stmt);
                    Continue;
                end;
                if Length(results) >= c_result_limit then
                begin
                    Break;
                end;
                item := Default(TncOneKeyCompletion);
                item.text := candidate_text;
                item.full_pinyin := candidate_compact_pinyin;
                item.path_text := '';
                item.weight := m_base_connection.column_int(stmt, 2);
                item.popularity_prior :=
                    m_base_connection.column_int(stmt, 3);
                item.corpus_score := m_base_connection.column_int(stmt, 4);
                item.document_score := m_base_connection.column_int(stmt, 5);
                item.source_count := m_base_connection.column_int(stmt, 6);
                item.path_score := m_base_connection.column_int(stmt, 7);
                item.vertical_penalty :=
                    m_base_connection.column_int(stmt, 8);
                item.vertical_layer_kind :=
                    m_base_connection.column_int(stmt, 9);
                item.has_popularity_prior := True;
                item.feedback_count := 0;
                item.prefix_anchored :=
                    m_base_connection.column_int(stmt, 10) <> 0;
                item.source := okcs_base_exact;
                SetLength(results, Length(results) + 1);
                results[High(results)] := item;
                Result := True;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;
    end;

    procedure consider_candidate(var target: TncRankedCompletionList;
        const candidate_pinyin: string;
        const candidate_text: string; const candidate_weight: Integer;
        const candidate_source: TncOneKeyCompletionSource;
        const candidate_path: string; const candidate_anchored: Boolean;
        const rank_primary: Integer; const rank_secondary: Int64;
        const popularity_prior: Integer; const corpus_score: Integer;
        const document_score: Integer; const source_count: Integer;
        const path_score: Integer; const vertical_penalty: Integer;
        const vertical_layer_kind: Integer;
        const has_popularity_prior: Boolean);
    var
        candidate_compact_pinyin: string;
        ranked_item: TncRankedCompletion;
        item_idx: Integer;
        worst_idx: Integer;
    begin
        if (candidate_source = okcs_base_exact) and
            (vertical_layer_kind = c_completion_layer_exact_only_specialist) then Exit;
        if (Trim(candidate_text) = '') or
            (not candidate_matches_prefix(candidate_pinyin, candidate_text,
            candidate_compact_pinyin)) then
        begin
            Exit;
        end;

        ranked_item := Default(TncRankedCompletion);
        ranked_item.item.text := Trim(candidate_text);
        ranked_item.item.full_pinyin := candidate_compact_pinyin;
        ranked_item.item.path_text := Trim(candidate_path);
        ranked_item.item.weight := candidate_weight;
        ranked_item.item.popularity_prior := popularity_prior;
        ranked_item.item.corpus_score := corpus_score;
        ranked_item.item.document_score := document_score;
        ranked_item.item.source_count := source_count;
        ranked_item.item.path_score := path_score;
        ranked_item.item.vertical_penalty := vertical_penalty;
        ranked_item.item.vertical_layer_kind := vertical_layer_kind;
        ranked_item.item.has_popularity_prior := has_popularity_prior;
        ranked_item.item.feedback_count := 0;
        ranked_item.item.prefix_anchored := candidate_anchored;
        ranked_item.item.source := candidate_source;
        ranked_item.primary := rank_primary;
        ranked_item.secondary := rank_secondary;

        for item_idx := 0 to High(target) do
        begin
            if SameText(target[item_idx].item.full_pinyin,
                ranked_item.item.full_pinyin) and
                SameText(target[item_idx].item.text,
                ranked_item.item.text) then
            begin
                if ranked_better(ranked_item, target[item_idx]) then
                begin
                    target[item_idx] := ranked_item;
                end;
                Exit;
            end;
        end;

        if Length(target) < c_source_result_limit then
        begin
            SetLength(target, Length(target) + 1);
            target[High(target)] := ranked_item;
            Exit;
        end;

        worst_idx := 0;
        for item_idx := 1 to High(target) do
        begin
            if ranked_better(target[worst_idx], target[item_idx]) then
            begin
                worst_idx := item_idx;
            end;
        end;
        if ranked_better(ranked_item, target[worst_idx]) then
        begin
            target[worst_idx] := ranked_item;
        end;
    end;

    procedure query_base_stored_prefix(const stored_prefix: string;
        var target_items: TncRankedCompletionList;
        const rank_by_popularity: Boolean);
    var
        upper_bound: string;
        candidate_pinyin: string;
        candidate_text: string;
        candidate_weight: Integer;
        candidate_rank: Integer;
        candidate_popularity_prior: Integer;
        candidate_corpus_score: Integer;
        candidate_document_score: Integer;
        candidate_source_count: Integer;
        candidate_path_score: Integer;
        candidate_vertical_penalty: Integer;
        candidate_layer_kind: Integer;
        candidate_has_prior: Boolean;
        candidate_prefix_text: string;
        candidate_anchored: Boolean;
        stmt: Psqlite3_stmt;
        step_result: Integer;
        sql_text: string;
    begin
        upper_bound := build_prefix_upper_bound(stored_prefix);
        if (stored_prefix = '') or (upper_bound = '') then
        begin
            Exit;
        end;

        stmt := nil;
        try
            if rank_by_popularity then
            begin
                sql_text := base_completion_popularity_sql;
            end
            else
            begin
                sql_text := base_completion_weight_sql;
            end;
            if (not m_base_connection.prepare(sql_text, stmt)) or
                (not m_base_connection.bind_text(stmt, 1, stored_prefix)) or
                (not m_base_connection.bind_text(stmt, 2, upper_bound)) or
                (not m_base_connection.bind_int(stmt, 3, c_query_limit)) then
            begin
                Exit;
            end;

            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                candidate_text := Trim(m_base_connection.column_text(stmt, 1));
                candidate_weight := m_base_connection.column_int(stmt, 2);
                candidate_popularity_prior := m_base_connection.column_int(stmt, 3);
                candidate_corpus_score := m_base_connection.column_int(stmt, 4);
                candidate_document_score := m_base_connection.column_int(stmt, 5);
                candidate_source_count := m_base_connection.column_int(stmt, 6);
                candidate_path_score := m_base_connection.column_int(stmt, 7);
                candidate_vertical_penalty := m_base_connection.column_int(stmt, 8);
                candidate_layer_kind := m_base_connection.column_int(stmt, 9);
                candidate_has_prior := candidate_popularity_prior >= 0;
                if rank_by_popularity and candidate_has_prior then
                begin
                    candidate_rank := candidate_popularity_prior;
                end
                else
                begin
                    candidate_rank := candidate_weight;
                end;
                candidate_prefix_text := copy_first_text_units(candidate_text,
                    Length(prefix_syllables));
                candidate_anchored := (candidate_prefix_text <> '') and
                    exact_prefix_texts.ContainsKey(candidate_prefix_text);
                if candidate_anchored then
                begin
                    // A completed exact word at the typed boundary is stronger
                    // evidence than an accidental prefix through another word.
                    Inc(candidate_rank, c_base_exact_prefix_anchor_bonus);
                end;
                consider_candidate(target_items, candidate_pinyin,
                    candidate_text, candidate_weight, okcs_base_exact, '',
                    candidate_anchored, candidate_rank,
                    -get_text_unit_count_local(candidate_text),
                    candidate_popularity_prior, candidate_corpus_score,
                    candidate_document_score, candidate_source_count,
                    candidate_path_score, candidate_vertical_penalty,
                    candidate_layer_kind,
                    candidate_has_prior);
                if (Length(target_items) >= c_source_result_limit) and
                    (candidate_rank + c_base_exact_prefix_anchor_bonus <
                    minimum_primary(target_items)) then
                begin
                    Break;
                end;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;
    end;

    procedure query_user_stored_prefix(const stored_prefix: string;
        const literal_words: Boolean);
    var
        upper_bound: string;
        candidate_pinyin: string;
        candidate_text: string;
        candidate_weight: Integer;
        candidate_last_used: Int64;
        stmt: Psqlite3_stmt;
        step_result: Integer;
        sql_text: string;
    begin
        if (not m_user_ready) or (m_user_connection = nil) then
        begin
            Exit;
        end;
        upper_bound := build_prefix_upper_bound(stored_prefix);
        if (stored_prefix = '') or (upper_bound = '') then
        begin
            Exit;
        end;
        if literal_words then
        begin
            sql_text := literal_completion_sql;
        end
        else
        begin
            sql_text := user_completion_sql;
        end;
        stmt := nil;
        try
            if (not m_user_connection.prepare(sql_text, stmt)) or
                (not m_user_connection.bind_text(stmt, 1, stored_prefix)) or
                (not m_user_connection.bind_text(stmt, 2, upper_bound)) or
                (not m_user_connection.bind_int(stmt, 3, c_query_limit)) then
            begin
                Exit;
            end;
            step_result := m_user_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := m_user_connection.column_text(stmt, 0);
                candidate_text := user_text_for_script(candidate_pinyin,
                    Trim(m_user_connection.column_text(stmt, 1)));
                if literal_words then
                begin
                    candidate_weight := 0;
                    candidate_last_used := m_user_connection.column_int(stmt, 2);
                    consider_candidate(user_items, candidate_pinyin,
                        candidate_text, candidate_weight, okcs_user_exact, '',
                        True, MaxInt, candidate_last_used, 0, 0, 0, 0, 0, 0,
                        0, False);
                end
                else
                begin
                    candidate_weight := m_user_connection.column_int(stmt, 2);
                    candidate_last_used := m_user_connection.column_int(stmt, 3);
                    consider_candidate(user_items, candidate_pinyin,
                        candidate_text, candidate_weight, okcs_user_exact, '',
                        True, candidate_weight, candidate_last_used, 0, 0, 0,
                        0, 0, 0, 0, False);
                end;
                step_result := m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    procedure query_transition_completion;
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        candidate_pinyin: string;
        candidate_text: string;
        candidate_path: string;
        evidence: Integer;
        partial_upper_bound: string;
        previous_boundary_prefix: string;
        prefix_idx: Integer;
        current_boundary_found: Boolean;

        procedure append_query_results(const sql_text: string;
            const prefix_value, upper_bound_value: string;
            const range_query: Boolean);
        begin
            stmt := nil;
            try
                if not m_base_connection.prepare(sql_text, stmt) or
                    (not m_base_connection.bind_text(stmt, 1,
                    prefix_value)) then
                begin
                    Exit;
                end;
                if range_query then
                begin
                    if (upper_bound_value = '') or
                        (not m_base_connection.bind_text(stmt, 2,
                        upper_bound_value)) or
                        (not m_base_connection.bind_int(stmt, 3,
                        c_source_result_limit)) then
                    begin
                        Exit;
                    end;
                end
                else if not m_base_connection.bind_int(stmt, 2,
                    c_source_result_limit) then
                begin
                    Exit;
                end;

                step_result := m_base_connection.step(stmt);
                while step_result = SQLITE_ROW do
                begin
                    candidate_pinyin := m_base_connection.column_text(stmt, 0);
                    candidate_text := Trim(
                        m_base_connection.column_text(stmt, 1));
                    candidate_path := m_base_connection.column_text(stmt, 2);
                    evidence := m_base_connection.column_int(stmt, 3);
                    consider_candidate(transition_items, candidate_pinyin,
                        candidate_text, evidence, okcs_transition,
                        candidate_path,
                        transition_prefix_is_exact_boundary(candidate_path),
                        evidence,
                        -get_text_unit_count_local(candidate_text), 0, 0, 0,
                        0, 0, 0, 0, False);
                    step_result := m_base_connection.step(stmt);
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;
    begin
        append_query_results(transition_completion_sql, lookup_prefix, '',
            False);
        current_boundary_found := Length(transition_items) > 0;
        // Transition rows are indexed at completed syllable boundaries. If
        // a short tail can itself be parsed as a complete syllable (ji), the
        // intended completion may still be anchored at the preceding boundary
        // (liao + jie). Query that one boundary before looking forward.
        if (not current_boundary_found) and
            SameText(lookup_prefix, compact_prefix) and
            (Length(prefix_syllables) > 1) then
        begin
            previous_boundary_prefix := '';
            for prefix_idx := 0 to High(prefix_syllables) - 1 do
            begin
                previous_boundary_prefix := previous_boundary_prefix +
                    prefix_syllables[prefix_idx];
            end;
            if (previous_boundary_prefix <> '') and
                (not SameText(previous_boundary_prefix, lookup_prefix)) then
            begin
                append_query_results(transition_completion_sql,
                    previous_boundary_prefix, '', False);
            end;
        end;
        // Also inspect the next indexed boundary for an unfinished tail such
        // as l, li, or lia. Every returned row is still filtered against the
        // complete raw key and exact syllable alignment above.
        if Length(transition_items) = 0 then
        begin
            partial_upper_bound := build_prefix_upper_bound(compact_prefix);
            append_query_results(transition_completion_partial_sql,
                compact_prefix, partial_upper_bound, True);
        end;
    end;

    procedure cache_results;
    begin
        if m_one_key_completion_cache = nil then
        begin
            Exit;
        end;
        if m_one_key_completion_cache.Count >= c_result_cache_limit then
        begin
            m_one_key_completion_cache.Clear;
        end;
        m_one_key_completion_cache.AddOrSetValue(cache_key,
            Copy(results, 0, Length(results)));
    end;

    procedure append_ranked_items(const items: TncRankedCompletionList);
    var
        item_idx: Integer;
        result_idx: Integer;
        duplicate: Boolean;
    begin
        for item_idx := 0 to High(items) do
        begin
            if Length(results) >= c_result_limit then
            begin
                Exit;
            end;
            duplicate := False;
            for result_idx := 0 to High(results) do
            begin
                if SameText(results[result_idx].full_pinyin,
                    items[item_idx].item.full_pinyin) and
                    SameText(results[result_idx].text,
                    items[item_idx].item.text) then
                begin
                    duplicate := True;
                    Break;
                end;
            end;
            if duplicate then
            begin
                Continue;
            end;
            SetLength(results, Length(results) + 1);
            results[High(results)] := items[item_idx].item;
        end;
    end;

    procedure load_feedback_counts;
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        feedback_pinyin: string;
        feedback_text: string;
        feedback_count: Integer;
        feedback_reject_count: Integer;
        result_idx: Integer;
    begin
        if (Length(results) = 0) or (not m_user_ready) or
            (m_user_connection = nil) then
        begin
            Exit;
        end;
        stmt := nil;
        try
            if (not m_user_connection.prepare(feedback_sql, stmt)) or
                (not m_user_connection.bind_text(stmt, 1,
                compact_prefix)) then
            begin
                Exit;
            end;
            step_result := m_user_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                feedback_pinyin := normalize_compact_pinyin_key(
                    m_user_connection.column_text(stmt, 0));
                feedback_text := Trim(m_user_connection.column_text(stmt, 1));
                feedback_count := m_user_connection.column_int(stmt, 2);
                feedback_reject_count := m_user_connection.column_int(stmt, 3);
                for result_idx := 0 to High(results) do
                begin
                    if SameText(results[result_idx].full_pinyin,
                        feedback_pinyin) and
                        SameText(results[result_idx].text,
                        feedback_text) then
                    begin
                        results[result_idx].feedback_count := feedback_count;
                        results[result_idx].feedback_reject_count :=
                            feedback_reject_count;
                        Break;
                    end;
                end;
                step_result := m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    SetLength(results, 0);
    Result := False;
    canonical_prefix := normalize_canonical_pinyin_key(pinyin_prefix);
    compact_prefix := normalize_compact_pinyin_key(canonical_prefix);
    if compact_prefix = '' then
    begin
        Exit;
    end;

    lookup_prefix := '';
    if not resolve_lookup_prefix then
    begin
        Exit;
    end;
    explicit_prefix := '';
    for prefix_idx := 0 to High(prefix_syllables) do
    begin
        if explicit_prefix <> '' then
        begin
            explicit_prefix := explicit_prefix + '''';
        end;
        explicit_prefix := explicit_prefix + prefix_syllables[prefix_idx];
    end;
    cache_key := canonical_prefix;

    if not ensure_open or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);
    if (m_one_key_completion_cache <> nil) and
        m_one_key_completion_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    exact_prefix_texts := TDictionary<string, Boolean>.Create;
    try
        // Keep all reliable sources in one bounded pool. User completions are
        // appended first and remain an absolute priority in the engine, but
        // they no longer hide exact and transition alternatives from the
        // unified scorer, diagnostics, or incremental hysteresis.
        SetLength(user_items, 0);
        SetLength(base_items, 0);
        SetLength(base_weight_items, 0);
        SetLength(transition_items, 0);
        query_user_stored_prefix(compact_prefix, False);
        query_user_stored_prefix(compact_prefix, True);
        if not SameText(explicit_prefix, compact_prefix) then
        begin
            query_user_stored_prefix(explicit_prefix, False);
            query_user_stored_prefix(explicit_prefix, True);
        end;
        sort_ranked(user_items);
        append_ranked_items(user_items);

        // New dictionaries provide a bounded offline Top-K exact lookup.
        // Empty legacy tables fall back to the range scans below so upgrades
        // remain usable while their replacement dictionary is installed.
        if not query_precomputed_base then
        begin
            load_exact_prefix_texts;
            query_base_stored_prefix(compact_prefix, base_items, True);
            query_base_stored_prefix(compact_prefix, base_weight_items,
                False);
            if not SameText(explicit_prefix, compact_prefix) then
            begin
                query_base_stored_prefix(explicit_prefix, base_items, True);
                query_base_stored_prefix(explicit_prefix, base_weight_items,
                    False);
            end;
            sort_ranked(base_items);
            sort_ranked(base_weight_items);
            append_ranked_items(base_weight_items);
            append_ranked_items(base_items);
        end;
        query_transition_completion;
        sort_ranked(transition_items);
        append_ranked_items(transition_items);
        load_feedback_counts;
        cache_results;
        Result := Length(results) > 0;
    finally
        exact_prefix_texts.Free;
    end;
end;

function TncSqliteDictionary.lookup_long_one_key_completions(
    const anchor_path: string;
    out results: TncLongOneKeyCompletionList): Boolean;
const
    c_result_cache_limit = 2048;
    c_query_limit = 8;
    completion_sql =
        'SELECT suffix_pinyin, suffix_text, suffix_path, evidence, ' +
        'source_count FROM dict_base_long_completion ' +
        'WHERE anchor_path = ?1 AND evidence > 0 ' +
        'ORDER BY evidence DESC, source_count DESC, length(suffix_text), ' +
        'suffix_text LIMIT ?2';
    feedback_sql =
        'SELECT suffix_text, accept_count, reject_count ' +
        'FROM dict_user_long_completion_feedback WHERE anchor_path = ?1';
var
    anchor_key: string;
    cache_key: string;
    item: TncLongOneKeyCompletion;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    feedback_text: string;
    feedback_accept_count: Integer;
    feedback_reject_count: Integer;
    result_idx: Integer;
begin
    SetLength(results, 0);
    Result := False;
    anchor_key := Trim(anchor_path);
    if (anchor_key = '') or (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;
    cache_key := 'path' + #1 + anchor_key;
    refresh_user_data_version_if_changed(False);
    if (m_long_one_key_completion_cache <> nil) and
        m_long_one_key_completion_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    stmt := nil;
    try
        if (not m_base_connection.prepare(completion_sql, stmt)) or
            (not m_base_connection.bind_text(stmt, 1, anchor_key)) or
            (not m_base_connection.bind_int(stmt, 2, c_query_limit)) then
        begin
            Exit;
        end;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            item := Default(TncLongOneKeyCompletion);
            item.anchor_text := StringReplace(anchor_key, #3, '',
                [rfReplaceAll]);
            item.anchor_path := anchor_key;
            item.suffix_pinyin := m_base_connection.column_text(stmt, 0);
            item.suffix_text := Trim(m_base_connection.column_text(stmt, 1));
            item.suffix_path := m_base_connection.column_text(stmt, 2);
            item.evidence := m_base_connection.column_int(stmt, 3);
            item.source_count := m_base_connection.column_int(stmt, 4);
            if (item.suffix_pinyin <> '') and (item.suffix_text <> '') and
                (item.suffix_path <> '') then
            begin
                SetLength(results, Length(results) + 1);
                results[High(results)] := item;
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if (Length(results) > 0) and m_user_ready and
        (m_user_connection <> nil) then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(feedback_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, anchor_key) then
            begin
                step_result := m_user_connection.step(stmt);
                while step_result = SQLITE_ROW do
                begin
                    feedback_text := Trim(
                        m_user_connection.column_text(stmt, 0));
                    feedback_accept_count :=
                        m_user_connection.column_int(stmt, 1);
                    feedback_reject_count :=
                        m_user_connection.column_int(stmt, 2);
                    for result_idx := 0 to High(results) do
                    begin
                        if SameText(results[result_idx].suffix_text,
                            feedback_text) then
                        begin
                            results[result_idx].feedback_count :=
                                feedback_accept_count;
                            results[result_idx].feedback_reject_count :=
                                feedback_reject_count;
                            Break;
                        end;
                    end;
                    step_result := m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if m_long_one_key_completion_cache <> nil then
    begin
        if m_long_one_key_completion_cache.Count >= c_result_cache_limit then
        begin
            m_long_one_key_completion_cache.Clear;
        end;
        m_long_one_key_completion_cache.AddOrSetValue(cache_key,
            Copy(results, 0, Length(results)));
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_long_one_key_completions_by_text(
    const anchor_text: string;
    out results: TncLongOneKeyCompletionList): Boolean;
const
    c_result_cache_limit = 2048;
    c_query_limit = 64;
    completion_sql =
        'SELECT anchor_path, suffix_pinyin, suffix_text, suffix_path, ' +
        'evidence, source_count FROM dict_base_long_completion_text ' +
        'WHERE anchor_text = ?1 AND evidence > 0 ' +
        'ORDER BY evidence DESC, source_count DESC, length(suffix_text), ' +
        'suffix_text LIMIT ?2';
var
    anchor_key: string;
    cache_key: string;
    item: TncLongOneKeyCompletion;
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    SetLength(results, 0);
    Result := False;
    anchor_key := Trim(anchor_text);
    if (anchor_key = '') or (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;
    cache_key := 'text' + #1 + anchor_key;
    if (m_long_one_key_completion_cache <> nil) and
        m_long_one_key_completion_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    stmt := nil;
    try
        if (not m_base_connection.prepare(completion_sql, stmt)) or
            (not m_base_connection.bind_text(stmt, 1, anchor_key)) or
            (not m_base_connection.bind_int(stmt, 2, c_query_limit)) then
        begin
            Exit;
        end;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            item := Default(TncLongOneKeyCompletion);
            item.anchor_text := anchor_key;
            item.anchor_path := m_base_connection.column_text(stmt, 0);
            item.suffix_pinyin := m_base_connection.column_text(stmt, 1);
            item.suffix_text := Trim(m_base_connection.column_text(stmt, 2));
            item.suffix_path := m_base_connection.column_text(stmt, 3);
            item.evidence := m_base_connection.column_int(stmt, 4);
            item.source_count := m_base_connection.column_int(stmt, 5);
            if (item.anchor_path <> '') and (item.suffix_pinyin <> '') and
                (item.suffix_text <> '') and (item.suffix_path <> '') then
            begin
                SetLength(results, Length(results) + 1);
                results[High(results)] := item;
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_long_one_key_completion_cache <> nil then
    begin
        if m_long_one_key_completion_cache.Count >= c_result_cache_limit then
        begin
            m_long_one_key_completion_cache.Clear;
        end;
        m_long_one_key_completion_cache.AddOrSetValue(cache_key,
            Copy(results, 0, Length(results)));
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_one_key_completion_competition(
    const pinyin_prefix: string; const left_context: string;
    out results: TncOneKeyCompletionCompetitionEvidenceList): Boolean;
const
    c_result_cache_limit = 4096;
    c_query_limit = 96;
    competition_sql =
        'SELECT context_width, full_pinyin, text, evidence_score, ' +
        'occurrence_count, source_count ' +
        'FROM dict_base_completion_competition ' +
        'WHERE typed_prefix = ?1 AND (' +
        'context_width = 0 OR ' +
        '(context_width = 1 AND context_suffix = ?2) OR ' +
        '(context_width = 2 AND context_suffix = ?3) OR ' +
        '(context_width = 3 AND context_suffix = ?4) OR ' +
        '(context_width = 4 AND context_suffix = ?5)) ' +
        'ORDER BY context_width DESC, evidence_score DESC, text ASC ' +
        'LIMIT ?6';
var
    prefix_key: string;
    context_units: TArray<string>;
    suffix1: string;
    suffix2: string;
    suffix3: string;
    suffix4: string;
    cache_key: string;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    item: TncOneKeyCompletionCompetitionEvidence;
begin
    SetLength(results, 0);
    Result := False;
    prefix_key := normalize_compact_pinyin_key(pinyin_prefix);
    if prefix_key = '' then
    begin
        Exit;
    end;

    context_units := split_text_units_local(left_context);
    suffix1 := '';
    suffix2 := '';
    suffix3 := '';
    suffix4 := '';
    if Length(context_units) > 0 then
    begin
        suffix1 := context_units[High(context_units)];
        suffix2 := suffix1;
        suffix3 := suffix2;
        suffix4 := suffix3;
        if Length(context_units) > 1 then
        begin
            suffix2 := context_units[High(context_units) - 1] + suffix1;
            suffix3 := suffix2;
            suffix4 := suffix3;
        end;
        if Length(context_units) > 2 then
        begin
            suffix3 := context_units[High(context_units) - 2] + suffix2;
            suffix4 := suffix3;
        end;
        if Length(context_units) > 3 then
        begin
            suffix4 := context_units[High(context_units) - 3] + suffix3;
        end;
    end;
    cache_key := prefix_key + #1 + suffix4;

    if (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;
    if (m_one_key_completion_competition_cache <> nil) and
        m_one_key_completion_competition_cache.TryGetValue(
        cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    stmt := nil;
    try
        if (not m_base_connection.prepare(competition_sql, stmt)) or
            (not m_base_connection.bind_text(stmt, 1, prefix_key)) or
            (not m_base_connection.bind_text(stmt, 2, suffix1)) or
            (not m_base_connection.bind_text(stmt, 3, suffix2)) or
            (not m_base_connection.bind_text(stmt, 4, suffix3)) or
            (not m_base_connection.bind_text(stmt, 5, suffix4)) or
            (not m_base_connection.bind_int(stmt, 6, c_query_limit)) then
        begin
            Exit;
        end;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            item := Default(TncOneKeyCompletionCompetitionEvidence);
            item.context_width := m_base_connection.column_int(stmt, 0);
            item.full_pinyin := m_base_connection.column_text(stmt, 1);
            item.text := m_base_connection.column_text(stmt, 2);
            item.evidence_score := m_base_connection.column_int(stmt, 3);
            item.occurrence_count := m_base_connection.column_int(stmt, 4);
            item.source_count := m_base_connection.column_int(stmt, 5);
            SetLength(results, Length(results) + 1);
            results[High(results)] := item;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_one_key_completion_competition_cache <> nil then
    begin
        if m_one_key_completion_competition_cache.Count >=
            c_result_cache_limit then
        begin
            m_one_key_completion_competition_cache.Clear;
        end;
        m_one_key_completion_competition_cache.AddOrSetValue(cache_key,
            Copy(results, 0, Length(results)));
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.lookup_one_key_completion_pair_audit(
    const pinyin_prefix, left_context: string;
    const baseline_full_pinyin, baseline_text: string;
    const challenger_full_pinyin, challenger_text: string;
    out audit: TncOneKeyCompletionPairAudit): Boolean;
const
    c_result_cache_limit = 4096;
    audit_sql =
        'SELECT context_width, decision, keep_count, switch_count, ' +
        'confidence_milli ' +
        'FROM dict_base_completion_pair_audit ' +
        'WHERE typed_prefix = ?1 AND baseline_full_pinyin = ?2 AND ' +
        'baseline_text = ?3 AND challenger_full_pinyin = ?4 AND ' +
        'challenger_text = ?5 AND (' +
        'context_width = 0 OR ' +
        '(context_width = 1 AND context_suffix = ?6) OR ' +
        '(context_width = 2 AND context_suffix = ?7) OR ' +
        '(context_width = 3 AND context_suffix = ?8) OR ' +
        '(context_width = 4 AND context_suffix = ?9)) ' +
        'ORDER BY context_width DESC LIMIT 1';
var
    prefix_key: string;
    baseline_pinyin_key: string;
    baseline_text_key: string;
    challenger_pinyin_key: string;
    challenger_text_key: string;
    context_units: TArray<string>;
    suffix1: string;
    suffix2: string;
    suffix3: string;
    suffix4: string;
    cache_key: string;
    stmt: Psqlite3_stmt;
begin
    audit := Default(TncOneKeyCompletionPairAudit);
    Result := False;
    prefix_key := normalize_compact_pinyin_key(pinyin_prefix);
    baseline_pinyin_key := normalize_compact_pinyin_key(
        baseline_full_pinyin);
    baseline_text_key := Trim(baseline_text);
    challenger_pinyin_key := normalize_compact_pinyin_key(
        challenger_full_pinyin);
    challenger_text_key := Trim(challenger_text);
    if (prefix_key = '') or (baseline_pinyin_key = '') or
        (baseline_text_key = '') or (challenger_pinyin_key = '') or
        (challenger_text_key = '') or
        ((baseline_pinyin_key = challenger_pinyin_key) and
        SameText(baseline_text_key, challenger_text_key)) then
    begin
        Exit;
    end;

    context_units := split_text_units_local(left_context);
    suffix1 := '';
    suffix2 := '';
    suffix3 := '';
    suffix4 := '';
    if Length(context_units) > 0 then
    begin
        suffix1 := context_units[High(context_units)];
        suffix2 := suffix1;
        suffix3 := suffix2;
        suffix4 := suffix3;
        if Length(context_units) > 1 then
        begin
            suffix2 := context_units[High(context_units) - 1] + suffix1;
            suffix3 := suffix2;
            suffix4 := suffix3;
        end;
        if Length(context_units) > 2 then
        begin
            suffix3 := context_units[High(context_units) - 2] + suffix2;
            suffix4 := suffix3;
        end;
        if Length(context_units) > 3 then
        begin
            suffix4 := context_units[High(context_units) - 3] + suffix3;
        end;
    end;
    cache_key := prefix_key + #1 + suffix4 + #1 + baseline_pinyin_key +
        #1 + baseline_text_key + #1 + challenger_pinyin_key + #1 +
        challenger_text_key;

    if (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;
    if (m_one_key_completion_pair_audit_cache <> nil) and
        m_one_key_completion_pair_audit_cache.TryGetValue(cache_key,
        audit) then
    begin
        Exit(audit.available);
    end;

    stmt := nil;
    try
        if (not m_base_connection.prepare(audit_sql, stmt)) or
            (not m_base_connection.bind_text(stmt, 1, prefix_key)) or
            (not m_base_connection.bind_text(stmt, 2,
            baseline_pinyin_key)) or
            (not m_base_connection.bind_text(stmt, 3,
            baseline_text_key)) or
            (not m_base_connection.bind_text(stmt, 4,
            challenger_pinyin_key)) or
            (not m_base_connection.bind_text(stmt, 5,
            challenger_text_key)) or
            (not m_base_connection.bind_text(stmt, 6, suffix1)) or
            (not m_base_connection.bind_text(stmt, 7, suffix2)) or
            (not m_base_connection.bind_text(stmt, 8, suffix3)) or
            (not m_base_connection.bind_text(stmt, 9, suffix4)) then
        begin
            Exit;
        end;
        if m_base_connection.step(stmt) = SQLITE_ROW then
        begin
            audit.available := True;
            audit.context_width := m_base_connection.column_int(stmt, 0);
            audit.decision := m_base_connection.column_int(stmt, 1);
            audit.keep_count := m_base_connection.column_int(stmt, 2);
            audit.switch_count := m_base_connection.column_int(stmt, 3);
            audit.confidence_milli :=
                m_base_connection.column_int(stmt, 4);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_one_key_completion_pair_audit_cache <> nil then
    begin
        if m_one_key_completion_pair_audit_cache.Count >=
            c_result_cache_limit then
        begin
            m_one_key_completion_pair_audit_cache.Clear;
        end;
        m_one_key_completion_pair_audit_cache.AddOrSetValue(cache_key,
            audit);
    end;
    Result := audit.available;
end;

function TncSqliteDictionary.lookup_short_promotion(const pinyin,
    baseline_text: string; out promoted_text: string; out lead: Integer): Boolean;
const
    c_result_cache_limit = 4096;
    promotion_sql =
        'SELECT promoted_text, lead FROM dict_base_short_promotion ' +
        'WHERE pinyin = ?1 AND baseline_text = ?2';
var
    stmt: Psqlite3_stmt;
    cache_key, cached: string;
    separator: Integer;
begin
    promoted_text := '';
    lead := 0;
    Result := False;
    if (pinyin = '') or (baseline_text = '') or (not ensure_open) or
        (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;
    cache_key := pinyin + #1 + baseline_text;
    if (m_short_promotion_cache <> nil) and
        m_short_promotion_cache.TryGetValue(cache_key, cached) then
    begin
        separator := Pos(#1, cached);
        if separator > 1 then
        begin
            promoted_text := Copy(cached, 1, separator - 1);
            lead := StrToIntDef(Copy(cached, separator + 1, MaxInt), 0);
            Result := True;
        end;
        Exit;
    end;

    stmt := nil;
    try
        // A dictionary built before this table has no rows to offer.
        if (not m_base_connection.prepare(promotion_sql, stmt)) or
            (not m_base_connection.bind_text(stmt, 1, pinyin)) or
            (not m_base_connection.bind_text(stmt, 2, baseline_text)) then
        begin
            Exit;
        end;
        if m_base_connection.step(stmt) = SQLITE_ROW then
        begin
            promoted_text := m_base_connection.column_text(stmt, 0);
            lead := m_base_connection.column_int(stmt, 1);
            Result := promoted_text <> '';
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_short_promotion_cache <> nil then
    begin
        if m_short_promotion_cache.Count >= c_result_cache_limit then
        begin
            m_short_promotion_cache.Clear;
        end;
        if Result then
            m_short_promotion_cache.AddOrSetValue(cache_key,
                promoted_text + #1 + IntToStr(lead))
        else
            m_short_promotion_cache.AddOrSetValue(cache_key, '');
    end;
end;

function TncSqliteDictionary.resolve_exact_text_prefix(
    const text: string; const max_segments, max_units: Integer;
    out resolved: TncExactTextPath): Boolean;
const
    c_cache_limit = 4096;
    c_max_word_units = 6;
    select_sql =
        'SELECT pinyin, weight FROM dict_base WHERE text = ?1 ' +
        'ORDER BY weight DESC LIMIT 16';
type
    TSearchBest = record
        score: Int64;
        total_weight: Integer;
        single_count: Integer;
        value: TncExactTextPath;
    end;
var
    text_key: string;
    cache_key: string;
    text_units: TArray<string>;
    search_limit: Integer;
    stmt: Psqlite3_stmt;
    segment_cache: TDictionary<string, TncExactTextPath>;
    best: TSearchBest;

    function join_units(const start_idx, end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + text_units[idx];
        end;
    end;

    function lookup_segment(const segment_text: string;
        const unit_count: Integer; out segment: TncExactTextPath): Boolean;
    var
        step_result: Integer;
        pinyin_value: string;
        syllables: TArray<string>;
    begin
        if segment_cache.TryGetValue(segment_text, segment) then
        begin
            Exit(segment.valid);
        end;
        segment := Default(TncExactTextPath);
        if (stmt = nil) or (segment_text = '') or
            (not m_base_connection.reset(stmt)) or
            (not m_base_connection.clear_bindings(stmt)) or
            (not m_base_connection.bind_text(stmt, 1, segment_text)) then
        begin
            segment_cache.AddOrSetValue(segment_text, segment);
            Exit(False);
        end;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := LowerCase(Trim(
                m_base_connection.column_text(stmt, 0)));
            syllables := split_full_pinyin_syllables(pinyin_value);
            if (Length(syllables) = unit_count) and
                is_full_pinyin_key(pinyin_value) then
            begin
                segment.valid := True;
                segment.text := segment_text;
                segment.full_pinyin := normalize_compact_pinyin_key(
                    pinyin_value);
                segment.path_text := segment_text;
                segment.weight := m_base_connection.column_int(stmt, 1);
                segment.segment_count := 1;
                segment.unit_count := unit_count;
                Break;
            end;
            step_result := m_base_connection.step(stmt);
        end;
        segment_cache.AddOrSetValue(segment_text, segment);
        Result := segment.valid;
    end;

    procedure search(const start_idx, segment_count, total_weight,
        single_count: Integer; const pinyin_path, text_path: string);
    var
        end_idx: Integer;
        segment_units: Integer;
        segment_text: string;
        segment: TncExactTextPath;
        next_pinyin: string;
        next_path: string;
        consumed_units: Integer;
        next_weight: Integer;
        next_single_count: Integer;
        score: Int64;
    begin
        if (start_idx >= search_limit) or
            (segment_count >= max_segments) then
        begin
            Exit;
        end;
        for end_idx := start_idx to Min(search_limit - 1,
            start_idx + c_max_word_units - 1) do
        begin
            segment_units := end_idx - start_idx + 1;
            segment_text := join_units(start_idx, end_idx);
            if not lookup_segment(segment_text, segment_units, segment) then
            begin
                Continue;
            end;
            if pinyin_path = '' then
            begin
                next_pinyin := segment.full_pinyin;
                next_path := segment.text;
            end
            else
            begin
                next_pinyin := pinyin_path + segment.full_pinyin;
                next_path := text_path + #3 + segment.text;
            end;
            consumed_units := end_idx + 1;
            next_weight := total_weight + segment.weight;
            next_single_count := single_count + Ord(segment_units = 1);
            // A one-character prompt is too easy to trigger accidentally.
            // Single-character exact words remain legal inside a longer path.
            if consumed_units >= 2 then
            begin
                score := Int64(consumed_units) * 100000 +
                    Int64(next_weight) -
                    Int64(segment_count + 1) * 900 -
                    Int64(next_single_count) * 1400;
                if (not best.value.valid) or (score > best.score) or
                    ((score = best.score) and
                    (segment_count + 1 < best.value.segment_count)) then
                begin
                    best.score := score;
                    best.total_weight := next_weight;
                    best.single_count := next_single_count;
                    best.value.valid := True;
                    best.value.text := join_units(0, end_idx);
                    best.value.full_pinyin := next_pinyin;
                    best.value.path_text := next_path;
                    best.value.segment_count := segment_count + 1;
                    best.value.unit_count := consumed_units;
                    best.value.weight := next_weight div
                        (segment_count + 1);
                end;
            end;
            search(end_idx + 1, segment_count + 1, next_weight,
                next_single_count, next_pinyin, next_path);
        end;
    end;

begin
    resolved := Default(TncExactTextPath);
    Result := False;
    text_key := Trim(text);
    if (text_key = '') or (max_segments < 1) or (max_segments > 3) or
        (max_units < 2) then
    begin
        Exit;
    end;
    cache_key := text_key + #1 + IntToStr(max_segments) + #1 +
        IntToStr(max_units);
    if (m_exact_text_prefix_cache <> nil) and
        m_exact_text_prefix_cache.TryGetValue(cache_key, resolved) then
    begin
        Exit(resolved.valid);
    end;
    if (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;
    text_units := split_text_units_local(text_key);
    search_limit := Min(Length(text_units), max_units);
    if search_limit < 2 then
    begin
        Exit;
    end;

    stmt := nil;
    segment_cache := TDictionary<string, TncExactTextPath>.Create;
    try
        if not m_base_connection.prepare(select_sql, stmt) then
        begin
            Exit;
        end;
        best := Default(TSearchBest);
        best.score := Low(Int64);
        search(0, 0, 0, 0, '', '');
        resolved := best.value;
    finally
        segment_cache.Free;
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_exact_text_prefix_cache <> nil then
    begin
        if m_exact_text_prefix_cache.Count >= c_cache_limit then
        begin
            m_exact_text_prefix_cache.Clear;
        end;
        m_exact_text_prefix_cache.AddOrSetValue(cache_key, resolved);
    end;
    Result := resolved.valid;
end;

procedure TncSqliteDictionary.record_one_key_completion_accept(
    const typed_prefix: string; const full_pinyin: string; const text: string);
const
    update_sql =
        'UPDATE dict_user_completion_feedback SET ' +
        'accept_count = MIN(accept_count + 1, 1000000), ' +
        'reject_count = MAX(reject_count - 1, 0), ' +
        'last_used = strftime(''%s'',''now'') ' +
        'WHERE typed_prefix = ?1 AND full_pinyin = ?2 AND text = ?3';
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_completion_feedback' +
        '(typed_prefix, full_pinyin, text, accept_count, reject_count, last_used) ' +
        'VALUES (?1, ?2, ?3, 1, 0, strftime(''%s'',''now''))';
var
    prefix_key: string;
    full_key: string;
    text_key: string;
    stmt: Psqlite3_stmt;

    procedure execute_feedback_sql(const sql_text: string);
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(sql_text, stmt) and
                m_user_connection.bind_text(stmt, 1, prefix_key) and
                m_user_connection.bind_text(stmt, 2, full_key) and
                m_user_connection.bind_text(stmt, 3, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    prefix_key := normalize_compact_pinyin_key(typed_prefix);
    full_key := normalize_compact_pinyin_key(full_pinyin);
    text_key := Trim(text);
    if (prefix_key = '') or (full_key = '') or (text_key = '') or
        (not ensure_open) or (not m_user_ready) or
        (m_user_connection = nil) then
    begin
        Exit;
    end;
    if (Length(full_key) <= Length(prefix_key)) or
        (not full_key.StartsWith(prefix_key, True)) then
    begin
        Exit;
    end;

    execute_feedback_sql(update_sql);
    execute_feedback_sql(insert_sql);
    note_user_data_changed;
end;

procedure TncSqliteDictionary.record_one_key_completion_reject(
    const typed_prefix: string; const full_pinyin: string; const text: string);
const
    update_sql =
        'UPDATE dict_user_completion_feedback SET ' +
        'reject_count = MIN(reject_count + 1, 1000000), ' +
        'last_used = strftime(''%s'',''now'') ' +
        'WHERE typed_prefix = ?1 AND full_pinyin = ?2 AND text = ?3';
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_completion_feedback' +
        '(typed_prefix, full_pinyin, text, accept_count, reject_count, last_used) ' +
        'VALUES (?1, ?2, ?3, 0, 1, strftime(''%s'',''now''))';
var
    prefix_key: string;
    full_key: string;
    text_key: string;
    stmt: Psqlite3_stmt;

    procedure execute_feedback_sql(const sql_text: string);
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(sql_text, stmt) and
                m_user_connection.bind_text(stmt, 1, prefix_key) and
                m_user_connection.bind_text(stmt, 2, full_key) and
                m_user_connection.bind_text(stmt, 3, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    prefix_key := normalize_compact_pinyin_key(typed_prefix);
    full_key := normalize_compact_pinyin_key(full_pinyin);
    text_key := Trim(text);
    if (prefix_key = '') or (full_key = '') or (text_key = '') or
        (not ensure_open) or (not m_user_ready) or
        (m_user_connection = nil) then
    begin
        Exit;
    end;
    if (Length(full_key) <= Length(prefix_key)) or
        (not full_key.StartsWith(prefix_key, True)) then
    begin
        Exit;
    end;

    execute_feedback_sql(update_sql);
    execute_feedback_sql(insert_sql);
    note_user_data_changed;
end;

procedure TncSqliteDictionary.record_long_one_key_completion_accept(
    const anchor_path, suffix_text: string);
const
    update_sql =
        'UPDATE dict_user_long_completion_feedback SET ' +
        'accept_count = MIN(accept_count + 1, 1000000), ' +
        'reject_count = MAX(reject_count - 1, 0), ' +
        'last_used = strftime(''%s'',''now'') ' +
        'WHERE anchor_path = ?1 AND suffix_text = ?2';
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_long_completion_feedback' +
        '(anchor_path, suffix_text, accept_count, reject_count, last_used) ' +
        'VALUES (?1, ?2, 1, 0, strftime(''%s'',''now''))';
var
    anchor_key: string;
    suffix_key: string;
    stmt: Psqlite3_stmt;

    procedure execute_feedback_sql(const sql_text: string);
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(sql_text, stmt) and
                m_user_connection.bind_text(stmt, 1, anchor_key) and
                m_user_connection.bind_text(stmt, 2, suffix_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    anchor_key := Trim(anchor_path);
    suffix_key := Trim(suffix_text);
    if (anchor_key = '') or (suffix_key = '') or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;
    execute_feedback_sql(update_sql);
    execute_feedback_sql(insert_sql);
    note_user_data_changed;
end;

procedure TncSqliteDictionary.record_long_one_key_completion_reject(
    const anchor_path, suffix_text: string);
const
    update_sql =
        'UPDATE dict_user_long_completion_feedback SET ' +
        'reject_count = MIN(reject_count + 1, 1000000), ' +
        'last_used = strftime(''%s'',''now'') ' +
        'WHERE anchor_path = ?1 AND suffix_text = ?2';
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_long_completion_feedback' +
        '(anchor_path, suffix_text, accept_count, reject_count, last_used) ' +
        'VALUES (?1, ?2, 0, 1, strftime(''%s'',''now''))';
var
    anchor_key: string;
    suffix_key: string;
    stmt: Psqlite3_stmt;

    procedure execute_feedback_sql(const sql_text: string);
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(sql_text, stmt) and
                m_user_connection.bind_text(stmt, 1, anchor_key) and
                m_user_connection.bind_text(stmt, 2, suffix_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    anchor_key := Trim(anchor_path);
    suffix_key := Trim(suffix_text);
    if (anchor_key = '') or (suffix_key = '') or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;
    execute_feedback_sql(update_sql);
    execute_feedback_sql(insert_sql);
    note_user_data_changed;
end;

procedure TncSqliteDictionary.set_debug_mode(const enabled: Boolean);
begin
    m_debug_mode := enabled;
    if not m_debug_mode then
    begin
        m_last_lookup_debug_hint := '';
    end;
end;

function TncSqliteDictionary.ensure_open: Boolean;
begin
    if m_ready then
    begin
        if ((m_base_db_path = '') or m_base_ready) and
            ((m_user_db_path = '') or m_user_ready or
            m_user_initialization_deferred) then
        begin
            refresh_user_data_version_if_changed(False);
            Result := True;
            Exit;
        end;
    end;

    Result := open_internal(m_defer_optional_model_loads);
end;

procedure TncSqliteDictionary.configure_user_connection;
begin
    if m_user_connection = nil then
    begin
        Exit;
    end;

    m_user_connection.exec('PRAGMA journal_mode=WAL;');
    m_user_connection.exec('PRAGMA synchronous=NORMAL;');
    m_user_connection.exec('PRAGMA temp_store=MEMORY;');
    m_user_connection.exec('PRAGMA busy_timeout=1000;');
end;

procedure TncSqliteDictionary.configure_base_connection;
begin
    if m_base_connection = nil then
    begin
        Exit;
    end;

    // Long-sentence search performs many small indexed reads. Mapping the
    // immutable base dictionary avoids repeatedly copying those pages through
    // SQLite's small default page cache while the OS can share mapped pages.
    m_base_connection.exec('PRAGMA mmap_size=134217728;');
    m_base_connection.exec('PRAGMA cache_size=-8192;');
    m_base_connection.exec('PRAGMA temp_store=MEMORY;');
end;

procedure TncSqliteDictionary.load_base_query_path_pinyin_cache;
const
    query_sql = 'SELECT DISTINCT query_pinyin FROM dict_base_query_path';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    query_key: string;
begin
    if m_base_query_path_pinyin_cache_loaded then
    begin
        Exit;
    end;

    m_base_query_path_pinyin_cache_loaded := True;
    if m_base_query_path_pinyin_cache <> nil then
    begin
        m_base_query_path_pinyin_cache.Clear;
    end;
    if (not m_base_ready) or (m_base_connection = nil) or
        (m_base_query_path_pinyin_cache = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        // The table is optional for compatibility with older dictionaries.
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            query_key := m_base_connection.column_text(stmt, 0);
            if query_key <> '' then
            begin
                m_base_query_path_pinyin_cache.AddOrSetValue(query_key, True);
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.load_query_path_bonus_cache;
const
    query_sql =
        'SELECT query_pinyin, path_text, weight FROM dict_base_query_path';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    normalized_query: string;
    normalized_path: string;
    cache_key: string;
    weight: Integer;
begin
    if m_query_path_bonus_cache_loaded then
    begin
        Exit;
    end;

    m_query_path_bonus_cache_loaded := True;
    if m_query_path_bonus_cache <> nil then
    begin
        m_query_path_bonus_cache.Clear;
    end;
    if m_base_query_path_pinyin_cache <> nil then
    begin
        m_base_query_path_pinyin_cache.Clear;
    end;
    m_base_query_path_pinyin_cache_loaded := True;
    if (not m_base_ready) or (m_base_connection = nil) or
        (m_query_path_bonus_cache = nil) or
        (m_base_query_path_pinyin_cache = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        // The table is optional for compatibility with older dictionaries.
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;
        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            normalized_query := LowerCase(Trim(
                m_base_connection.column_text(stmt, 0)));
            normalized_path := Trim(m_base_connection.column_text(stmt, 1));
            weight := m_base_connection.column_int(stmt, 2);
            if normalized_query <> '' then
            begin
                m_base_query_path_pinyin_cache.AddOrSetValue(
                    normalized_query, True);
            end;
            if (normalized_query <> '') and (normalized_path <> '') and
                (weight > 0) then
            begin
                cache_key := normalized_query + #1 + normalized_path;
                m_query_path_bonus_cache.AddOrSetValue(cache_key,
                    calc_base_query_segment_path_bonus(weight));
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.base_query_path_pinyin_may_exist(
    const query_key: string): Boolean;
var
    present: Boolean;
begin
    if m_defer_optional_model_loads and
        (not m_base_query_path_pinyin_cache_loaded) then
    begin
        Exit(False);
    end;
    if not m_base_query_path_pinyin_cache_loaded then
    begin
        load_base_query_path_pinyin_cache;
    end;
    Result := (m_base_query_path_pinyin_cache <> nil) and
        m_base_query_path_pinyin_cache.TryGetValue(query_key, present) and
        present;
end;

procedure TncSqliteDictionary.load_lm_transition_bonus_cache;
const
    query_sql =
        'SELECT query_pinyin, path_text, weight FROM dict_base_lm_transition';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    normalized_query: string;
    normalized_path: string;
    cache_key: string;
    weight: Integer;
    bonus_value: Integer;
begin
    if m_lm_transition_cache_loaded then
    begin
        Exit;
    end;

    m_lm_transition_cache_loaded := True;
    if m_lm_transition_bonus_cache <> nil then
    begin
        m_lm_transition_bonus_cache.Clear;
    end;
    if (not m_base_ready) or (m_base_connection = nil) or
        (m_lm_transition_bonus_cache = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        // Older dictionaries do not have this optional table. A failed prepare
        // therefore means an empty model, not a failed dictionary open.
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            normalized_query := LowerCase(Trim(m_base_connection.column_text(stmt, 0)));
            normalized_path := Trim(m_base_connection.column_text(stmt, 1));
            weight := m_base_connection.column_int(stmt, 2);
            if (normalized_query <> '') and (normalized_path <> '') and (weight > 0) then
            begin
                if is_single_pair_lm_transition_path(normalized_path) then
                begin
                    bonus_value := calc_single_pair_lm_transition_bonus(weight);
                end
                else
                begin
                    bonus_value := calc_lm_transition_bonus(weight);
                end;
                cache_key := normalized_query + #1 + normalized_path;
                m_lm_transition_bonus_cache.AddOrSetValue(
                    cache_key, bonus_value);
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.begin_learning_batch;
begin
    if (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    if m_write_batch_depth = 0 then
    begin
        if not m_user_connection.exec('BEGIN IMMEDIATE TRANSACTION;') then
        begin
            Exit;
        end;
    end;
    Inc(m_write_batch_depth);
end;

procedure TncSqliteDictionary.commit_learning_batch;
begin
    if m_write_batch_depth <= 0 then
    begin
        Exit;
    end;

    Dec(m_write_batch_depth);
    if m_write_batch_depth = 0 then
    begin
        if not m_user_connection.exec('COMMIT;') then
        begin
            m_user_connection.exec('ROLLBACK;');
            clear_user_read_caches;
        end;
        if m_write_batch_depth = 0 then
        begin
            note_user_data_changed;
        end;
    end;
end;

procedure TncSqliteDictionary.rollback_learning_batch;
begin
    if m_write_batch_depth <= 0 then
    begin
        Exit;
    end;

    m_write_batch_depth := 0;
    if m_user_connection <> nil then
    begin
        m_user_connection.exec('ROLLBACK;');
    end;
end;

function TncSqliteDictionary.get_module_dir: string;
var
    buffer: array[0..MAX_PATH] of Char;
    len: Cardinal;
begin
    Result := '';
    len := GetModuleFileName(HInstance, buffer, MAX_PATH);
    if len > 0 then
    begin
        Result := ExtractFilePath(buffer);
    end;
end;

function TncSqliteDictionary.find_schema_path: string;
var
    base_dir: string;
    candidate: string;
begin
    Result := '';
    base_dir := get_module_dir;

    if base_dir <> '' then
    begin
        candidate := IncludeTrailingPathDelimiter(base_dir) + 'schema.sql';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;

        candidate := IncludeTrailingPathDelimiter(base_dir) + 'data\\schema.sql';
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;

        candidate := ExpandFileName(IncludeTrailingPathDelimiter(base_dir) + '..\\data\\schema.sql');
        if FileExists(candidate) then
        begin
            Result := candidate;
            Exit;
        end;
    end;

    candidate := ExpandFileName('data\\schema.sql');
    if FileExists(candidate) then
    begin
        Result := candidate;
    end;
end;

function TncSqliteDictionary.load_schema_text(out schema_text: string): Boolean;
var
    schema_path: string;
begin
    schema_text := '';
    schema_path := find_schema_path;
    if schema_path = '' then
    begin
        Result := False;
        Exit;
    end;

    schema_text := TFile.ReadAllText(schema_path, TEncoding.ASCII);
    Result := schema_text <> '';
end;

function TncSqliteDictionary.ensure_schema(const connection: TncSqliteConnection): Boolean;
var
    schema_text: string;
    schema_version: Integer;

    function table_has_column(const table_name, column_name: string): Boolean;
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
    begin
        Result := False;
        stmt := nil;
        try
            if not connection.prepare('PRAGMA table_info(' + table_name + ')',
                stmt) then
            begin
                Exit;
            end;
            step_result := connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                if SameText(connection.column_text(stmt, 1), column_name) then
                begin
                    Result := True;
                    Exit;
                end;
                step_result := connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                connection.finalize(stmt);
            end;
        end;
    end;
begin
    if connection = nil then
    begin
        Result := False;
        Exit;
    end;

    if not load_schema_text(schema_text) then
    begin
        schema_text := default_schema_sql;
    end;

    if not connection.exec(schema_text) then
    begin
        Result := False;
        Exit;
    end;

    if (not table_has_column('dict_base',
        'contains_popularity_eligible')) and
        (not connection.exec(
        'ALTER TABLE dict_base ADD COLUMN ' +
        'contains_popularity_eligible INTEGER NOT NULL DEFAULT 1;')) then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_jianpin (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        'word_id INTEGER NOT NULL,' +
        'jianpin TEXT NOT NULL,' +
        'weight INTEGER DEFAULT 0,' +
        'UNIQUE(word_id, jianpin),' +
        'FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key ON dict_jianpin(jianpin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_weight ON dict_base(pinyin, weight);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_pinyin_alias (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        'compact_pinyin TEXT NOT NULL,' +
        'word_id INTEGER NOT NULL,' +
        'UNIQUE(compact_pinyin, word_id),' +
        'FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_alias_compact ' +
        'ON dict_base_pinyin_alias(compact_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_base_text_weight ON dict_base(text, weight);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_completion_prior (' +
        'pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'popularity_prior INTEGER NOT NULL DEFAULT 0,' +
        'corpus_score INTEGER NOT NULL DEFAULT 0,' +
        'document_score INTEGER NOT NULL DEFAULT 0,' +
        'source_count INTEGER NOT NULL DEFAULT 0,' +
        'path_score INTEGER NOT NULL DEFAULT 0,' +
        'vertical_penalty INTEGER NOT NULL DEFAULT 0,' +
        'layer_kind INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_prior_pinyin ' +
        'ON dict_base_completion_prior(pinyin, popularity_prior DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_completion_lookup (' +
        'typed_prefix TEXT NOT NULL,' +
        'full_pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'weight INTEGER NOT NULL DEFAULT 0,' +
        'popularity_prior INTEGER NOT NULL DEFAULT 0,' +
        'corpus_score INTEGER NOT NULL DEFAULT 0,' +
        'document_score INTEGER NOT NULL DEFAULT 0,' +
        'source_count INTEGER NOT NULL DEFAULT 0,' +
        'path_score INTEGER NOT NULL DEFAULT 0,' +
        'vertical_penalty INTEGER NOT NULL DEFAULT 0,' +
        'layer_kind INTEGER NOT NULL DEFAULT 0,' +
        'prefix_anchored INTEGER NOT NULL DEFAULT 0,' +
        'rank_order INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(typed_prefix, full_pinyin, text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_lookup_prefix ' +
        'ON dict_base_completion_lookup(typed_prefix, rank_order);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_completion_competition (' +
        'context_width INTEGER NOT NULL,' +
        'context_suffix TEXT NOT NULL,' +
        'typed_prefix TEXT NOT NULL,' +
        'full_pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'evidence_score INTEGER NOT NULL DEFAULT 0,' +
        'occurrence_count INTEGER NOT NULL DEFAULT 0,' +
        'source_count INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(context_width, context_suffix, typed_prefix, ' +
        'full_pinyin, text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_competition_query ' +
        'ON dict_base_completion_competition(typed_prefix, context_width, ' +
        'context_suffix, evidence_score DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_completion_pair_audit (' +
        'context_width INTEGER NOT NULL,' +
        'context_suffix TEXT NOT NULL,' +
        'typed_prefix TEXT NOT NULL,' +
        'baseline_full_pinyin TEXT NOT NULL,' +
        'baseline_text TEXT NOT NULL,' +
        'challenger_full_pinyin TEXT NOT NULL,' +
        'challenger_text TEXT NOT NULL,' +
        'decision INTEGER NOT NULL DEFAULT 0,' +
        'keep_count INTEGER NOT NULL DEFAULT 0,' +
        'switch_count INTEGER NOT NULL DEFAULT 0,' +
        'keep_source_count INTEGER NOT NULL DEFAULT 0,' +
        'switch_source_count INTEGER NOT NULL DEFAULT 0,' +
        'confidence_milli INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(context_width, context_suffix, typed_prefix, ' +
        'baseline_full_pinyin, baseline_text, challenger_full_pinyin, ' +
        'challenger_text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_completion_pair_audit_query ' +
        'ON dict_base_completion_pair_audit(typed_prefix, ' +
        'baseline_full_pinyin, baseline_text, challenger_full_pinyin, ' +
        'challenger_text, context_width DESC, context_suffix);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_short_promotion (' +
        'pinyin TEXT NOT NULL,' +
        'baseline_text TEXT NOT NULL,' +
        'promoted_text TEXT NOT NULL,' +
        'lead INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(pinyin, baseline_text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key_weight_word ' +
        'ON dict_jianpin(jianpin, weight DESC, word_id);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_stats (' +
        'pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_literal (' +
        'pinyin TEXT NOT NULL,' +
        'jianpin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'created_at INTEGER DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_pinyin ' +
        'ON dict_user_literal(pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_compact_pinyin ' +
        'ON dict_user_literal(REPLACE(pinyin, char(39), substr(pinyin, 1, 0)));') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_jianpin ' +
        'ON dict_user_literal(jianpin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_literal_text ' +
        'ON dict_user_literal(text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_stats_text ON dict_user_stats(text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_fuzzy_choice (' +
        'pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_fuzzy_choice_pinyin ' +
        'ON dict_user_fuzzy_choice(pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_query_latest (' +
        'query_pinyin TEXT NOT NULL PRIMARY KEY,' +
        'text TEXT NOT NULL,' +
        'last_used INTEGER DEFAULT 0' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_latest_text ON dict_user_query_latest(text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_completion_feedback (' +
        'typed_prefix TEXT NOT NULL,' +
        'full_pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'accept_count INTEGER DEFAULT 0,' +
        'reject_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(typed_prefix, full_pinyin, text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if (not table_has_column('dict_user_completion_feedback',
        'reject_count')) and
        (not connection.exec(
        'ALTER TABLE dict_user_completion_feedback ' +
        'ADD COLUMN reject_count INTEGER DEFAULT 0;')) then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_completion_feedback_prefix ' +
        'ON dict_user_completion_feedback(typed_prefix, accept_count DESC, last_used DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_long_completion_feedback (' +
        'anchor_path TEXT NOT NULL,' +
        'suffix_text TEXT NOT NULL,' +
        'accept_count INTEGER DEFAULT 0,' +
        'reject_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(anchor_path, suffix_text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_long_completion_feedback_anchor ' +
        'ON dict_user_long_completion_feedback(anchor_path, accept_count DESC, last_used DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_penalty (' +
        'pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'penalty INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(pinyin, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_penalty_pinyin ON dict_user_penalty(pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_bigram (' +
        'left_text TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(left_text, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec('CREATE INDEX IF NOT EXISTS idx_dict_user_bigram_left_text ON dict_user_bigram(left_text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_trigram (' +
        'prev_prev_text TEXT NOT NULL,' +
        'prev_text TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(prev_prev_text, prev_text, text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_trigram_prev_pair ON dict_user_trigram(prev_prev_text, prev_text);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_query_path (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'commit_count INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_query ON dict_user_query_path(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_user_query_path_penalty (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'penalty INTEGER DEFAULT 0,' +
        'last_used INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_penalty_query ' +
        'ON dict_user_query_path_penalty(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_query_path (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'weight INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_query_path_query ' +
        'ON dict_base_query_path(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_lm_transition (' +
        'query_pinyin TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'weight INTEGER DEFAULT 0,' +
        'PRIMARY KEY(query_pinyin, path_text)' +
        ');') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_lm_transition_query ' +
        'ON dict_base_lm_transition(query_pinyin);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_transition_completion (' +
        'typed_prefix TEXT NOT NULL,' +
        'full_pinyin TEXT NOT NULL,' +
        'text TEXT NOT NULL,' +
        'path_text TEXT NOT NULL,' +
        'evidence INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(typed_prefix, full_pinyin, text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_transition_completion_prefix ' +
        'ON dict_base_transition_completion(typed_prefix, evidence DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_long_completion (' +
        'anchor_path TEXT NOT NULL,' +
        'suffix_pinyin TEXT NOT NULL,' +
        'suffix_text TEXT NOT NULL,' +
        'suffix_path TEXT NOT NULL,' +
        'evidence INTEGER NOT NULL DEFAULT 0,' +
        'source_count INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(anchor_path, suffix_pinyin, suffix_text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_long_completion_anchor ' +
        'ON dict_base_long_completion(anchor_path, evidence DESC, source_count DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_long_completion_text (' +
        'anchor_text TEXT NOT NULL,' +
        'anchor_path TEXT NOT NULL,' +
        'suffix_pinyin TEXT NOT NULL,' +
        'suffix_text TEXT NOT NULL,' +
        'suffix_path TEXT NOT NULL,' +
        'evidence INTEGER NOT NULL DEFAULT 0,' +
        'source_count INTEGER NOT NULL DEFAULT 0,' +
        'PRIMARY KEY(anchor_text, anchor_path, suffix_pinyin, suffix_text)' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE INDEX IF NOT EXISTS idx_dict_base_long_completion_text_anchor ' +
        'ON dict_base_long_completion_text(anchor_text, evidence DESC, ' +
        'source_count DESC);') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_char_lm (' +
        'ngram TEXT NOT NULL PRIMARY KEY,' +
        'score INTEGER NOT NULL DEFAULT 0,' +
        'backoff INTEGER NOT NULL DEFAULT 0' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not connection.exec(
        'CREATE TABLE IF NOT EXISTS dict_base_char_reverse_lm (' +
        'ngram TEXT NOT NULL PRIMARY KEY,' +
        'score INTEGER NOT NULL DEFAULT 0,' +
        'backoff INTEGER NOT NULL DEFAULT 0' +
        ') WITHOUT ROWID;') then
    begin
        Result := False;
        Exit;
    end;

    if not get_schema_version(connection, schema_version) then
    begin
        set_schema_version(connection, 15);
        Result := True;
        Exit;
    end;

    if schema_version < 1 then
    begin
        set_schema_version(connection, 1);
    end;

    if schema_version < 2 then
    begin
        set_schema_version(connection, 2);
    end;

    if schema_version < 3 then
    begin
        set_schema_version(connection, 3);
    end;

    if schema_version < 4 then
    begin
        set_schema_version(connection, 4);
    end;

    if schema_version < 5 then
    begin
        set_schema_version(connection, 5);
    end;

    if schema_version < 6 then
    begin
        set_schema_version(connection, 6);
    end;

    if schema_version < 7 then
    begin
        set_schema_version(connection, 7);
    end;

    if schema_version < 8 then
    begin
        set_schema_version(connection, 8);
    end;

    if schema_version < 9 then
    begin
        set_schema_version(connection, 9);
    end;

    if schema_version < 10 then
    begin
        set_schema_version(connection, 10);
    end;

    if schema_version < 11 then
    begin
        set_schema_version(connection, 11);
    end;

    if schema_version < 12 then
    begin
        set_schema_version(connection, 12);
    end;

    if schema_version < 13 then
    begin
        set_schema_version(connection, 13);
    end;

    if schema_version < 14 then
    begin
        set_schema_version(connection, 14);
    end;

    if schema_version < 15 then
    begin
        // Path penalties written by older ranking models can suppress newly
        // introduced LM-backed paths. Preserve user words and usage stats,
        // but reset these model-specific negative signals once on upgrade.
        if not connection.exec('DELETE FROM dict_user_query_path_penalty;') then
        begin
            Result := False;
            Exit;
        end;
        set_schema_version(connection, 15);
    end;

    if schema_version < 16 then
    begin
        set_schema_version(connection, 16);
    end;

    if schema_version < 17 then
    begin
        set_schema_version(connection, 17);
    end;

    if schema_version < 18 then
    begin
        set_schema_version(connection, 18);
    end;

    if schema_version < 19 then
    begin
        set_schema_version(connection, 19);
    end;

    if schema_version < 20 then
    begin
        set_schema_version(connection, 20);
    end;

    if schema_version < 21 then
    begin
        set_schema_version(connection, 21);
    end;

    if schema_version < 22 then
    begin
        set_schema_version(connection, 22);
    end;

    if schema_version < 23 then
    begin
        set_schema_version(connection, 23);
    end;

    if schema_version < 24 then
    begin
        set_schema_version(connection, 24);
    end;

    Result := True;
end;

function TncSqliteDictionary.get_schema_version(const connection: TncSqliteConnection; out version: Integer): Boolean;
const
    sql_text = 'SELECT value FROM meta WHERE key = ''schema_version'' LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    value_text: string;
begin
    version := 0;
    if (connection = nil) or not connection.opened then
    begin
        Result := False;
        Exit;
    end;

    stmt := nil;
    try
        if not connection.prepare(sql_text, stmt) then
        begin
            Result := False;
            Exit;
        end;

        step_result := connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            value_text := connection.column_text(stmt, 0);
            version := StrToIntDef(value_text, 0);
            Result := True;
            Exit;
        end;
    finally
        if stmt <> nil then
        begin
            connection.finalize(stmt);
        end;
    end;

    Result := False;
end;

procedure TncSqliteDictionary.set_schema_version(const connection: TncSqliteConnection; const version: Integer);
const
    sql_text = 'INSERT OR REPLACE INTO meta(key, value) VALUES(''schema_version'', ?1)';
var
    stmt: Psqlite3_stmt;
begin
    if (connection = nil) or not connection.opened then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not connection.prepare(sql_text, stmt) then
        begin
            Exit;
        end;

        if connection.bind_text(stmt, 1, IntToStr(version)) then
        begin
            connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.get_valid_cjk_codepoint_count(const text: string): Integer;
var
    idx: Integer;
    codepoint_count: Integer;
    codepoint: Integer;
    high_surrogate: Integer;
    low_surrogate: Integer;

    function is_cjk_codepoint(const value: Integer): Boolean;
    begin
        Result :=
            ((value >= $4E00) and (value <= $9FFF)) or
            ((value >= $3400) and (value <= $4DBF)) or
            ((value >= $F900) and (value <= $FAFF)) or
            ((value >= $2F800) and (value <= $2FA1F)) or
            ((value >= $20000) and (value <= $2A6DF)) or
            ((value >= $2A700) and (value <= $2B73F)) or
            ((value >= $2B740) and (value <= $2B81F)) or
            ((value >= $2B820) and (value <= $2CEAF)) or
            ((value >= $2CEB0) and (value <= $2EBEF)) or
            ((value >= $30000) and (value <= $3134F));
    end;
begin
    Result := -1;
    if text = '' then
    begin
        Exit;
    end;

    if Pos('`', text) > 0 then
    begin
        Exit;
    end;

    idx := 1;
    codepoint_count := 0;
    while idx <= Length(text) do
    begin
        codepoint := Ord(text[idx]);
        if (codepoint >= $D800) and (codepoint <= $DBFF) then
        begin
            if idx >= Length(text) then
            begin
                Exit;
            end;

            high_surrogate := codepoint;
            low_surrogate := Ord(text[idx + 1]);
            if (low_surrogate < $DC00) or (low_surrogate > $DFFF) then
            begin
                Exit;
            end;

            codepoint := ((high_surrogate - $D800) shl 10) + (low_surrogate - $DC00) + $10000;
            Inc(idx);
        end;

        if not is_cjk_codepoint(codepoint) then
        begin
            Exit;
        end;

        Inc(codepoint_count);
        Inc(idx);
    end;

    Result := codepoint_count;
end;

function is_windows_supported_ime_text(const text: string): Boolean;
var
    idx: Integer;
    codepoint: Integer;
begin
    Result := False;
    if text = '' then
    begin
        Exit;
    end;

    idx := 1;
    while idx <= Length(text) do
    begin
        codepoint := Ord(text[idx]);
        // Reject supplementary-plane characters (surrogate pairs). A subset of
        // these Unihan codepoints still cannot be reliably committed/rendered
        // in common Windows text controls.
        if (codepoint >= $D800) and (codepoint <= $DFFF) then
        begin
            Exit;
        end;

        if not (
            ((codepoint >= $4E00) and (codepoint <= $9FFF)) or
            ((codepoint >= $3400) and (codepoint <= $4DBF)) or
            ((codepoint >= $F900) and (codepoint <= $FAFF))
            ) then
        begin
            Exit;
        end;

        Inc(idx);
    end;

    Result := True;
end;

function TncSqliteDictionary.is_valid_learning_text(const text: string): Boolean;
const
    c_learning_text_max_codepoints = 10;
var
    codepoint_count: Integer;
begin
    // Persistent learning should stay on pure CJK text and avoid sentence-like
    // long tails. Longer committed phrases still participate in immediate
    // session behavior, but should not be written into the user DB.
    codepoint_count := get_valid_cjk_codepoint_count(text);
    Result := (codepoint_count >= 1) and (codepoint_count <= c_learning_text_max_codepoints);
end;

function TncSqliteDictionary.is_valid_user_text(const text: string): Boolean;
const
    c_user_text_max_codepoints = 4;
var
    codepoint_count: Integer;
begin
    codepoint_count := get_valid_cjk_codepoint_count(text);
    // User dictionary should store phrase learning only, not single-character commits.
    Result := (codepoint_count >= 2) and (codepoint_count <= c_user_text_max_codepoints);
end;

function TncSqliteDictionary.is_valid_learning_path(const encoded_path: string): Boolean;
const
    c_learning_path_separator = #3;
var
    idx: Integer;
    segment_start: Integer;
    segment_text: string;
    total_count: Integer;
    segment_count: Integer;
begin
    Result := False;
    if Trim(encoded_path) = '' then
    begin
        Exit;
    end;

    total_count := 0;
    segment_count := 0;
    segment_start := 1;
    for idx := 1 to Length(encoded_path) + 1 do
    begin
        if (idx <= Length(encoded_path)) and (encoded_path[idx] <> c_learning_path_separator) then
        begin
            Continue;
        end;

        segment_text := Trim(Copy(encoded_path, segment_start, idx - segment_start));
        segment_start := idx + 1;
        if segment_text = '' then
        begin
            Continue;
        end;

        if not is_valid_learning_text(segment_text) then
        begin
            Exit;
        end;

        Inc(segment_count);
        Inc(total_count, get_valid_cjk_codepoint_count(segment_text));
        if total_count > 10 then
        begin
            Exit;
        end;
    end;

    Result := segment_count > 1;
end;

function TncSqliteDictionary.exact_base_entry_exists(const pinyin: string; const text: string): Boolean;
const
    base_exists_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    c_entry_cache_limit = 16384;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
    cache_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;
    cache_key := pinyin_key + #1 + text_key;
    if (m_exact_base_entry_cache <> nil) and
        m_exact_base_entry_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        stmt := nil;
        try
            if m_base_connection.prepare(base_exists_sql, stmt) and
                m_base_connection.bind_text(stmt, 1, pinyin_key) and
                m_base_connection.bind_text(stmt, 2, text_key) then
            begin
                step_result := m_base_connection.step(stmt);
                Result := step_result = SQLITE_ROW;
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;
    finally
        if m_exact_base_entry_cache <> nil then
        begin
            if m_exact_base_entry_cache.Count >= c_entry_cache_limit then
            begin
                m_exact_base_entry_cache.Clear;
            end;
            m_exact_base_entry_cache.AddOrSetValue(cache_key, Result);
        end;
    end;
end;

function TncSqliteDictionary.normalized_base_entry_exists(const pinyin: string; const text: string): Boolean;
const
    base_text_sql = 'SELECT pinyin FROM dict_base WHERE text = ?1 LIMIT 64';
    c_entry_cache_limit = 16384;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
    candidate_pinyin: string;
    cache_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;
    cache_key := pinyin_key + #1 + text_key;
    if (m_normalized_base_entry_cache <> nil) and
        m_normalized_base_entry_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if exact_base_entry_exists(pinyin_key, text_key) then
        begin
            Result := True;
            Exit;
        end;

        stmt := nil;
        try
            if not (m_base_connection.prepare(base_text_sql, stmt) and
                m_base_connection.bind_text(stmt, 1, text_key)) then
            begin
                Exit;
            end;

            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                if same_normalized_pinyin_key(candidate_pinyin, pinyin_key) then
                begin
                    Result := True;
                    Exit;
                end;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;
    finally
        if m_normalized_base_entry_cache <> nil then
        begin
            if m_normalized_base_entry_cache.Count >= c_entry_cache_limit then
            begin
                m_normalized_base_entry_cache.Clear;
            end;
            m_normalized_base_entry_cache.AddOrSetValue(cache_key, Result);
        end;
    end;
end;

function TncSqliteDictionary.try_get_single_char_full_pinyin_for_prefix(const prefix_pinyin: string;
    const text: string; out full_pinyin: string): Boolean;
const
    select_sql = 'SELECT pinyin FROM dict_base WHERE text = ?1 AND comment = '''' ' +
        'AND pinyin >= ?2 AND pinyin < ?3 ORDER BY weight DESC LIMIT 16';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    prefix_key: string;
    upper_bound: string;
    text_key: string;
    candidate_pinyin: string;
begin
    Result := False;
    full_pinyin := '';
    prefix_key := normalize_compact_pinyin_key(prefix_pinyin);
    text_key := Trim(text);
    if (prefix_key = '') or is_full_pinyin_key(prefix_key) or
        (get_valid_cjk_codepoint_count(text_key) <> 1) or
        (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    upper_bound := build_prefix_upper_bound(prefix_key);
    if upper_bound = '' then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not (m_base_connection.prepare(select_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, text_key) and
            m_base_connection.bind_text(stmt, 2, prefix_key) and
            m_base_connection.bind_text(stmt, 3, upper_bound)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            candidate_pinyin := normalize_compact_pinyin_key(
                m_base_connection.column_text(stmt, 0));
            if (Length(candidate_pinyin) > Length(prefix_key)) and
                is_full_pinyin_key(candidate_pinyin) then
            begin
                full_pinyin := candidate_pinyin;
                Result := True;
                Exit;
            end;
            step_result := m_base_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.has_any_base_phrase_for_pinyin(const pinyin: string): Boolean;
const
    base_phrase_sql = 'SELECT 1 FROM dict_base WHERE pinyin = ?1 AND length(text) >= 2 LIMIT 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    if (pinyin_key = '') or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_base_connection.prepare(base_phrase_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, pinyin_key) then
        begin
            step_result := m_base_connection.step(stmt);
            Result := step_result = SQLITE_ROW;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.set_user_dictionary_variant(
    const variant: TncDictionaryVariant);
begin
    if m_user_script_enabled and (m_user_script_variant = variant) then Exit;
    m_user_script_enabled := True;
    m_user_script_variant := variant;
    clear_user_read_caches;
end;

function TncSqliteDictionary.user_text_for_script(
    const pinyin, text: string): string;
const
    sql = 'SELECT text FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC';
var
    key, simplified, base_text: string;
    stmt: Psqlite3_stmt;
begin
    Result := text;
    if (not m_user_script_enabled) or (text = '') then Exit;
    key := pinyin + #1 + text;
    if m_user_script_cache.TryGetValue(key, Result) then Exit;
    Result := nc_convert_chinese_script(text, m_user_script_variant);
    // Prefer the active lexicon for ambiguous glyphs and names retaining an
    // unsimplified character; equivalence alone never admits a homophone.
    if (Result <> text) and m_base_ready and (m_base_connection <> nil) then
    begin
        simplified := nc_convert_chinese_script(text, dv_simplified);
        stmt := nil;
        try
            if m_base_connection.prepare(sql, stmt) and
                m_base_connection.bind_text(stmt, 1, pinyin) then
                while m_base_connection.step(stmt) = SQLITE_ROW do
                begin
                    base_text := m_base_connection.column_text(stmt, 0);
                    if nc_convert_chinese_script(base_text, dv_simplified) = simplified then
                    begin
                        Result := base_text;
                        Break;
                    end;
                end;
        finally
            if stmt <> nil then m_base_connection.finalize(stmt);
        end;
    end;
    if m_user_script_cache.Count >= 4096 then m_user_script_cache.Clear;
    m_user_script_cache.AddOrSetValue(key, Result);
end;

function TncSqliteDictionary.user_storage_text(
    const table_name, pinyin, text: string): string;
var
    key, stored: string;
    stmt: Psqlite3_stmt;
begin
    Result := text;
    if (not m_user_script_enabled) or (not m_user_ready) or
        (text = '') or (pinyin = '') then Exit;
    key := table_name + #1 + pinyin + #1 + text;
    if m_user_storage_text_cache.TryGetValue(key, Result) then Exit;
    // Keep the stored identity for learning/removal. Do not rewrite the shared
    // user database every time another session changes its display script.
    Result := text;
    stmt := nil;
    try
        if m_user_connection.prepare('SELECT text FROM ' + table_name +
            ' WHERE pinyin = ?1 ORDER BY (text = ?2) DESC, text ASC', stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin) and
            m_user_connection.bind_text(stmt, 2, text) then
            while m_user_connection.step(stmt) = SQLITE_ROW do
            begin
                stored := m_user_connection.column_text(stmt, 0);
                if (stored = text) or (user_text_for_script(pinyin, stored) = text) then
                begin
                    Result := stored;
                    Break;
                end;
            end;
    finally
        if stmt <> nil then m_user_connection.finalize(stmt);
    end;
    if m_user_storage_text_cache.Count >= 4096 then m_user_storage_text_cache.Clear;
    m_user_storage_text_cache.AddOrSetValue(key, Result);
end;

function TncSqliteDictionary.explicit_user_entry_exists(const pinyin: string; const text: string): Boolean;
const
    user_phrase_sql = 'SELECT 1 FROM dict_user WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    c_entry_cache_limit = 8192;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_key: string;
    text_key: string;
    cache_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;
    cache_key := pinyin_key + #1 + text_key;
    if (m_explicit_user_entry_cache <> nil) and
        m_explicit_user_entry_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        stmt := nil;
        try
            if m_user_connection.prepare(user_phrase_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2,
                user_storage_text('dict_user', pinyin_key, text_key)) then
            begin
                step_result := m_user_connection.step(stmt);
                Result := step_result = SQLITE_ROW;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    finally
        if m_explicit_user_entry_cache <> nil then
        begin
            if m_explicit_user_entry_cache.Count >= c_entry_cache_limit then
            begin
                m_explicit_user_entry_cache.Clear;
            end;
            m_explicit_user_entry_cache.AddOrSetValue(cache_key, Result);
        end;
    end;
end;

function TncSqliteDictionary.resolve_literal_user_word_pinyin(
    const query: string; const text: string; out full_pinyin: string): Boolean;
const
    base_sql = 'SELECT pinyin, weight FROM dict_base WHERE text = ?1 ' +
        'ORDER BY weight DESC, pinyin ASC LIMIT 64';
    user_sql = 'SELECT pinyin, text FROM dict_user WHERE text = ?1 ' +
        'ORDER BY weight DESC, pinyin ASC LIMIT 64';
    user_script_sql = 'SELECT pinyin, text FROM dict_user ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND length(text) = ?3 ' +
        'ORDER BY weight DESC, pinyin ASC';
var
    query_key: string;
    text_key: string;

    function find_matching_pinyin(const connection: TncSqliteConnection;
        const sql_text: string; out matched_pinyin: string): Boolean;
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        candidate_pinyin: string;
    begin
        Result := False;
        matched_pinyin := '';
        if (connection = nil) or (not connection.opened) then
        begin
            Exit;
        end;

        stmt := nil;
        try
            if not (connection.prepare(sql_text, stmt) and
                connection.bind_text(stmt, 1, text_key)) then
            begin
                Exit;
            end;
            if (connection = m_user_connection) and m_user_script_enabled then
            begin
                // Inverting NLS is lossy (e.g. hair vs. issue). Search the
                // indexed initial range and compare the actual stored spelling.
                if not (connection.bind_text(stmt, 1, Copy(query_key, 1, 1)) and
                    connection.bind_text(stmt, 2,
                    build_prefix_upper_bound(Copy(query_key, 1, 1))) and
                    connection.bind_int(stmt, 3,
                    get_valid_cjk_codepoint_count(text_key))) then Exit;
            end;

            step_result := connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := normalize_canonical_pinyin_key(
                    connection.column_text(stmt, 0));
                if (connection = m_user_connection) and
                    (user_text_for_script(candidate_pinyin,
                    connection.column_text(stmt, 1)) <> text_key) then
                begin
                    step_result := connection.step(stmt);
                    Continue;
                end;
                if literal_query_matches_full_pinyin(query_key,
                    candidate_pinyin) then
                begin
                    matched_pinyin := candidate_pinyin;
                    Exit(True);
                end;
                step_result := connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                connection.finalize(stmt);
            end;
        end;
    end;
begin
    Result := False;
    full_pinyin := '';
    query_key := normalize_compact_pinyin_key(query);
    text_key := Trim(text);
    if (query_key = '') or (text_key = '') or
        (get_valid_cjk_codepoint_count(text_key) <= 0) or
        (not ensure_open) then
    begin
        Exit;
    end;

    if m_base_ready and find_matching_pinyin(m_base_connection, base_sql,
        full_pinyin) then
    begin
        Exit(True);
    end;
    if m_user_ready and
        ((m_user_script_enabled and find_matching_pinyin(m_user_connection,
        user_script_sql, full_pinyin)) or
        ((not m_user_script_enabled) and find_matching_pinyin(m_user_connection,
        user_sql, full_pinyin))) then
    begin
        Exit(True);
    end;
end;

function TncSqliteDictionary.record_literal_user_word(
    const full_pinyin: string; const text: string): Boolean;
const
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_literal(pinyin, jianpin, text, created_at) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    jianpin_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := normalize_canonical_pinyin_key(full_pinyin);
    text_key := Trim(text);
    jianpin_key := build_jianpin_key_from_full_pinyin(pinyin_key);
    if (pinyin_key = '') or (jianpin_key = '') or
        (not is_full_pinyin_key(pinyin_key)) or
        (not is_valid_user_text(text_key)) or
        (not ensure_open) or (not m_user_ready) or
        (not full_pinyin_text_alignment_valid(pinyin_key, text_key)) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not (m_user_connection.prepare(insert_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, jianpin_key) and
            m_user_connection.bind_text(stmt, 3,
            user_storage_text('dict_user_literal', pinyin_key, text_key))) then
        begin
            Exit;
        end;
        Result := m_user_connection.step(stmt) = SQLITE_DONE;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if Result then
    begin
        note_user_data_changed;
        m_literal_user_words_available := 1;
    end;
end;

function TncSqliteDictionary.lookup_literal_user_words(const query: string;
    out results: TncCandidateList): Boolean;
const
    c_result_cache_limit = 2048;
    c_literal_candidate_score = 500000000;
    c_literal_query_length_max = 24;
    availability_sql = 'SELECT 1 FROM dict_user_literal LIMIT 1';
    exact_sql = 'SELECT pinyin, text FROM dict_user_literal ' +
        'WHERE REPLACE(pinyin, char(39), substr(pinyin, 1, 0)) = ?1 ' +
        'ORDER BY text ASC';
    jianpin_sql = 'SELECT pinyin, text FROM dict_user_literal ' +
        'WHERE jianpin = ?1 ORDER BY text ASC';
var
    query_key: string;
    full_prefix: string;
    jianpin_key: string;
    mixed_tokens: TncMixedQueryTokenList;
    jianpin_variants: TArray<string>;
    query_syllables: TArray<string>;
    all_initials: Boolean;
    full_query: Boolean;
    mixed_query: Boolean;
    query_can_match_literal: Boolean;
    idx: Integer;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Boolean>;

    function has_literal_user_words: Boolean;
    var
        stmt: Psqlite3_stmt;
    begin
        if m_literal_user_words_available >= 0 then
        begin
            Exit(m_literal_user_words_available > 0);
        end;

        Result := False;
        stmt := nil;
        try
            if not m_user_connection.prepare(availability_sql, stmt) then
            begin
                Exit;
            end;
            Result := m_user_connection.step(stmt) = SQLITE_ROW;
            m_literal_user_words_available := Ord(Result);
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    procedure append_matching_rows(const sql_text: string;
        const lookup_key: string);
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        candidate_pinyin: string;
        candidate_text: string;
        item: TncCandidate;
    begin
        if lookup_key = '' then
        begin
            Exit;
        end;

        stmt := nil;
        try
            if not (m_user_connection.prepare(sql_text, stmt) and
                m_user_connection.bind_text(stmt, 1, lookup_key)) then
            begin
                Exit;
            end;

            step_result := m_user_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := normalize_canonical_pinyin_key(
                    m_user_connection.column_text(stmt, 0));
                candidate_text := user_text_for_script(candidate_pinyin,
                    Trim(m_user_connection.column_text(stmt, 1)));
                if (candidate_text = '') or seen.ContainsKey(candidate_text) or
                    (not literal_query_matches_full_pinyin(query_key,
                    candidate_pinyin)) then
                begin
                    step_result := m_user_connection.step(stmt);
                    Continue;
                end;

                item := Default(TncCandidate);
                item.text := candidate_text;
                item.comment := '';
                item.score := c_literal_candidate_score;
                item.source := cs_user;
                item.has_dict_weight := False;
                item.dict_weight := 0;
                item.fuzzy_cost := 0;
                item.fuzzy_rules := [];
                seen.Add(candidate_text, True);
                list.Add(item);
                step_result := m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    SetLength(results, 0);
    Result := False;
    query_key := normalize_compact_pinyin_key(query);
    if (Length(query_key) < 2) or
        (Length(query_key) > c_literal_query_length_max) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);
    if not has_literal_user_words then
    begin
        Exit;
    end;

    if (m_literal_lookup_result_cache <> nil) and
        m_literal_lookup_result_cache.TryGetValue(query_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    full_query := is_full_pinyin_key(query_key);
    query_can_match_literal := False;
    if full_query then
    begin
        query_syllables := split_full_pinyin_syllables(query_key);
        // A compact key can hide a required boundary (xian -> xi'an), so a
        // one-syllable default parse can still address a multi-character word.
        query_can_match_literal := (Length(query_syllables) >= 1) and
            (Length(query_syllables) <= 4);
    end;

    mixed_query := parse_mixed_jianpin_query(query_key, full_prefix,
        jianpin_key, mixed_tokens);
    if mixed_query and (Length(mixed_tokens) >= 2) and
        (Length(mixed_tokens) <= 4) then
    begin
        query_can_match_literal := True;
    end;

    all_initials := True;
    for idx := 1 to Length(query_key) do
    begin
        if not is_jianpin_key_letter(query_key[idx]) then
        begin
            all_initials := False;
            Break;
        end;
    end;
    SetLength(jianpin_variants, 0);
    if all_initials then
    begin
        jianpin_variants := build_jianpin_query_variants(query_key);
        for idx := 0 to High(jianpin_variants) do
        begin
            if (Length(jianpin_variants[idx]) >= 2) and
                (Length(jianpin_variants[idx]) <= 4) then
            begin
                query_can_match_literal := True;
                Break;
            end;
        end;
    end;
    if not query_can_match_literal then
    begin
        Exit;
    end;

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Boolean>.Create;
    try
        if full_query then
        begin
            append_matching_rows(exact_sql, query_key);
        end;

        if mixed_query then
        begin
            append_matching_rows(jianpin_sql, jianpin_key);
        end;

        if all_initials then
        begin
            for idx := 0 to High(jianpin_variants) do
            begin
                if (Length(jianpin_variants[idx]) >= 2) and
                    (Length(jianpin_variants[idx]) <= 4) then
                begin
                    append_matching_rows(jianpin_sql,
                        jianpin_variants[idx]);
                end;
            end;
        end;

        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            results[idx] := list[idx];
        end;
        Result := Length(results) > 0;
    finally
        seen.Free;
        list.Free;
    end;

    if m_literal_lookup_result_cache <> nil then
    begin
        if m_literal_lookup_result_cache.Count >= c_result_cache_limit then
        begin
            m_literal_lookup_result_cache.Clear;
        end;
        m_literal_lookup_result_cache.AddOrSetValue(query_key,
            Copy(results, 0, Length(results)));
    end;
end;

function TncSqliteDictionary.is_literal_user_entry(const query: string;
    const text: string): Boolean;
const
    c_entry_cache_limit = 4096;
var
    query_key: string;
    text_key: string;
    cache_key: string;
    candidates: TncCandidateList;
    idx: Integer;
begin
    Result := False;
    query_key := normalize_compact_pinyin_key(query);
    text_key := Trim(text);
    if (query_key = '') or (text_key = '') or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    cache_key := query_key + #1 + text_key;
    if (m_literal_user_entry_cache <> nil) and
        m_literal_user_entry_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    if lookup_literal_user_words(query_key, candidates) then
    begin
        for idx := 0 to High(candidates) do
        begin
            if SameText(Trim(candidates[idx].text), text_key) then
            begin
                Result := True;
                Break;
            end;
        end;
    end;

    if m_literal_user_entry_cache <> nil then
    begin
        if m_literal_user_entry_cache.Count >= c_entry_cache_limit then
        begin
            m_literal_user_entry_cache.Clear;
        end;
        m_literal_user_entry_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.is_suppressible_nonbase_exact_phrase(const pinyin: string;
    const text: string): Boolean;
const
    c_suppressible_phrase_min_units = 2;
    c_suppressible_phrase_max_units = 4;
    c_suppressible_long_phrase_min_units = 5;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    idx: Integer;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if not is_full_pinyin_key(pinyin_key) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) then
    begin
        Exit;
    end;

    text_units := split_text_units_local(text_key);
    if (Length(text_units) < c_suppressible_phrase_min_units) then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    if Length(syllables) <> Length(text_units) then
    begin
        Exit;
    end;

    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;

    if Length(text_units) >= c_suppressible_long_phrase_min_units then
    begin
        for idx := 0 to High(text_units) do
        begin
            if not single_char_matches_pinyin(syllables[idx], text_units[idx]) then
            begin
                Exit;
            end;
        end;
        Exit(True);
    end;

    if Length(text_units) > c_suppressible_phrase_max_units then
    begin
        Exit;
    end;

    for idx := 0 to High(text_units) do
    begin
        if not single_char_matches_pinyin(syllables[idx], text_units[idx]) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function TncSqliteDictionary.split_full_pinyin_syllables(const pinyin: string): TArray<string>;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    idx: Integer;
    reconstructed: string;
    pinyin_key: string;
    compact_key: string;
begin
    SetLength(Result, 0);
    pinyin_key := LowerCase(Trim(pinyin));
    if pinyin_key = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(pinyin_key);
    finally
        parser.Free;
    end;

    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    reconstructed := '';
    SetLength(Result, Length(syllables));
    for idx := 0 to High(syllables) do
    begin
        if not is_valid_candidate_syllable(syllables[idx].text) then
        begin
            SetLength(Result, 0);
            Exit;
        end;
        reconstructed := reconstructed + syllables[idx].text;
        Result[idx] := syllables[idx].text;
    end;

    compact_key := StringReplace(pinyin_key, '''', '', [rfReplaceAll]);
    if not SameText(reconstructed, compact_key) then
    begin
        SetLength(Result, 0);
    end;
end;

function TncSqliteDictionary.strict_full_pinyin_text_alignment_valid(
    const pinyin: string; const text: string): Boolean;
const
    base_text_sql = 'SELECT pinyin FROM dict_base WHERE text = ?1 LIMIT 64';
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    idx: Integer;
    has_explicit_boundaries: Boolean;
    function text_unit_can_match_syllable(const syllable_text: string;
        const text_unit: string): Boolean;
    var
        stmt: Psqlite3_stmt;
        step_result: Integer;
        saw_known_reading: Boolean;
        candidate_pinyin: string;
    begin
        if single_char_matches_pinyin(syllable_text, text_unit) then
        begin
            Exit(True);
        end;

        // Missing per-character readings in a small test/user base are
        // unknown, not evidence of a bad alignment. Reject only when the base
        // has readings for the character and none match the syllable.
        if (not m_base_ready) or (m_base_connection = nil) then
        begin
            Exit(True);
        end;

        saw_known_reading := False;
        stmt := nil;
        try
            if not (m_base_connection.prepare(base_text_sql, stmt) and
                m_base_connection.bind_text(stmt, 1, text_unit)) then
            begin
                Exit(True);
            end;

            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                saw_known_reading := True;
                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                if same_normalized_pinyin_key(candidate_pinyin, syllable_text) then
                begin
                    Exit(True);
                end;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;

        Result := not saw_known_reading;
    end;

    function can_match_with_target_unit_count(const pinyin_pos: Integer;
        const unit_pos: Integer): Boolean;
    const
        c_max_syllable_len = 6;
    var
        remaining_units: Integer;
        remaining_chars: Integer;
        token_len: Integer;
        token_text: string;
    begin
        if (pinyin_pos > Length(pinyin_key)) and (unit_pos > High(text_units)) then
        begin
            Exit(True);
        end;
        if (pinyin_pos > Length(pinyin_key)) or (unit_pos > High(text_units)) then
        begin
            Exit(False);
        end;

        remaining_units := Length(text_units) - unit_pos;
        remaining_chars := Length(pinyin_key) - pinyin_pos + 1;
        if (remaining_chars < remaining_units) or
            (remaining_chars > remaining_units * c_max_syllable_len) then
        begin
            Exit(False);
        end;

        for token_len := 1 to Min(c_max_syllable_len, remaining_chars) do
        begin
            token_text := Copy(pinyin_key, pinyin_pos, token_len);
            if (not is_single_syllable_full_pinyin_key(token_text)) or
                (not text_unit_can_match_syllable(token_text, text_units[unit_pos])) then
            begin
                Continue;
            end;
            if can_match_with_target_unit_count(pinyin_pos + token_len, unit_pos + 1) then
            begin
                Exit(True);
            end;
        end;

        Result := False;
    end;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    has_explicit_boundaries := Pos('''', pinyin_key) > 0;
    if (pinyin_key = '') or (text_key = '') or
        (not (
            ((Length(pinyin_key) > 2) and (pinyin_key[Length(pinyin_key)] = 'r') and
                (Copy(pinyin_key, Length(pinyin_key) - 1, 2) <> 'er') and
                ((Copy(text_key, Length(text_key), 1) = '儿') or
                (Copy(text_key, Length(text_key), 1) = '兒')) and
                is_full_pinyin_key(Copy(pinyin_key, 1, Length(pinyin_key) - 1) + #39 + 'er')) or
            is_full_pinyin_key(pinyin_key))) then
    begin
        Exit;
    end;
    if (Length(pinyin_key) > 2) and (pinyin_key[Length(pinyin_key)] = 'r') and
        (Copy(pinyin_key, Length(pinyin_key) - 1, 2) <> 'er') and
        ((Copy(text_key, Length(text_key), 1) = '儿') or
        (Copy(text_key, Length(text_key), 1) = '兒')) and
        is_full_pinyin_key(Copy(pinyin_key, 1, Length(pinyin_key) - 1) + #39 + 'er') then
    begin
        pinyin_key := Copy(pinyin_key, 1, Length(pinyin_key) - 1) + #39 + 'er';
    end;

    if (has_explicit_boundaries and exact_base_entry_exists(pinyin_key,
        text_key)) or ((not has_explicit_boundaries) and
        normalized_base_entry_exists(pinyin_key, text_key)) then
    begin
        Exit(True);
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    text_units := split_text_units_local(text_key);
    if Length(syllables) <= 0 then
    begin
        Exit;
    end;
    if Length(text_units) <> Length(syllables) then
    begin
        if has_explicit_boundaries then
        begin
            Exit(False);
        end;
        // Compact pinyin can be segmented multiple ways without apostrophes.
        // Validate against the committed text length before rejecting learned
        // phrases such as yanquan -> 言泉.
        Result := can_match_with_target_unit_count(1, 0);
        Exit;
    end;

    for idx := 0 to High(text_units) do
    begin
        if (get_valid_cjk_codepoint_count(text_units[idx]) <> 1) or
            (not text_unit_can_match_syllable(syllables[idx], text_units[idx])) then
        begin
            if has_explicit_boundaries then
            begin
                Exit(False);
            end;
            // Compact pinyin can have an equally long but wrong default parse:
            // feichange may parse as fei/chan/ge, while the committed text is
            // fei/chang/e. Fall back to text-unit guided segmentation before
            // rejecting the learned choice.
            Result := can_match_with_target_unit_count(1, 0);
            Exit;
        end;
    end;

    Result := True;
end;

function TncSqliteDictionary.full_pinyin_text_alignment_valid(
    const pinyin: string; const text: string): Boolean;
var
    pinyin_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or
        (not is_full_pinyin_key(pinyin_key)) then
    begin
        Exit;
    end;

    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Result := True;
        Exit;
    end;

    Result := strict_full_pinyin_text_alignment_valid(pinyin_key, text_key);
end;

function TncSqliteDictionary.is_whitelisted_constructed_phrase(const pinyin: string; const text: string): Boolean;

    function matches_expected_phrase(const expected_pinyin: string; const expected_text: string): Boolean;
    begin
        Result := SameText(pinyin, expected_pinyin) and SameText(text, expected_text);
    end;

var
    syllables: TArray<string>;
    text_units: TArray<string>;
begin
    Result := False;
    if (pinyin = '') or (text = '') then
    begin
        Exit;
    end;

    if matches_expected_phrase('zhege', string(Char($8FD9)) + string(Char($4E2A))) or
        matches_expected_phrase('nage', string(Char($90A3)) + string(Char($4E2A))) or
        matches_expected_phrase('neige', string(Char($90A3)) + string(Char($4E2A))) or
        matches_expected_phrase('yige', string(Char($4E00)) + string(Char($4E2A))) or
        matches_expected_phrase('liangge', string(Char($4E24)) + string(Char($4E2A))) or
        matches_expected_phrase('jige', string(Char($51E0)) + string(Char($4E2A))) or
        matches_expected_phrase('meige', string(Char($6BCF)) + string(Char($4E2A))) or
        matches_expected_phrase('sange', string(Char($4E09)) + string(Char($4E2A))) or
        matches_expected_phrase('sige', string(Char($56DB)) + string(Char($4E2A))) or
        matches_expected_phrase('wuge', string(Char($4E94)) + string(Char($4E2A))) or
        matches_expected_phrase('liuge', string(Char($516D)) + string(Char($4E2A))) or
        matches_expected_phrase('qige', string(Char($4E03)) + string(Char($4E2A))) or
        matches_expected_phrase('bage', string(Char($516B)) + string(Char($4E2A))) or
        matches_expected_phrase('jiuge', string(Char($4E5D)) + string(Char($4E2A))) or
        matches_expected_phrase('shige', string(Char($5341)) + string(Char($4E2A))) or
        matches_expected_phrase('zhexie', string(Char($8FD9)) + string(Char($4E9B))) or
        matches_expected_phrase('naxie', string(Char($90A3)) + string(Char($4E9B))) or
        matches_expected_phrase('neixie', string(Char($90A3)) + string(Char($4E9B))) or
        matches_expected_phrase('yixie', string(Char($4E00)) + string(Char($4E9B))) or
        matches_expected_phrase('zheyang', string(Char($8FD9)) + string(Char($6837))) or
        matches_expected_phrase('nayang', string(Char($90A3)) + string(Char($6837))) or
        matches_expected_phrase('neiyang', string(Char($90A3)) + string(Char($6837))) or
        matches_expected_phrase('zheme', string(Char($8FD9)) + string(Char($4E48))) or
        matches_expected_phrase('name', string(Char($90A3)) + string(Char($4E48))) or
        matches_expected_phrase('neime', string(Char($90A3)) + string(Char($4E48))) or
        matches_expected_phrase('zenme', string(Char($600E)) + string(Char($4E48))) or
        matches_expected_phrase('youdian', string(Char($6709)) + string(Char($70B9))) then
    begin
        Result := True;
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin);
    text_units := split_text_units_local(Trim(text));
    if (Length(syllables) = 2) and (Length(text_units) = 2) and
        SameText(syllables[0], syllables[1]) and SameText(text_units[0], text_units[1]) then
    begin
        Result := True;
    end;
end;

function TncSqliteDictionary.is_nonbase_multiword_composed_exact_phrase(const pinyin: string;
    const text: string): Boolean;
const
    c_short_composed_min_units = 4;
    c_short_composed_min_segments = 2;
    c_short_composed_min_segment_units = 2;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    segment_exists_cache: TDictionary<string, Boolean>;
    compose_cache: TDictionary<string, Boolean>;

    function build_range_key(const start_syllable: Integer; const end_syllable: Integer;
        const start_unit: Integer; const end_unit: Integer): string;
    begin
        Result := IntToStr(start_syllable) + ':' + IntToStr(end_syllable) + '|' +
            IntToStr(start_unit) + ':' + IntToStr(end_unit);
    end;

    function build_compose_key(const start_syllable: Integer; const start_unit: Integer;
        const min_segments_remaining: Integer): string;
    begin
        Result := IntToStr(start_syllable) + '|' + IntToStr(start_unit) + '|' +
            IntToStr(min_segments_remaining);
    end;

    function join_syllable_slice(const start_idx: Integer; const end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + syllables[idx];
        end;
    end;

    function join_text_unit_slice(const start_idx: Integer; const end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + text_units[idx];
        end;
    end;

    function segment_exists(const start_syllable: Integer; const end_syllable: Integer;
        const start_unit: Integer; const end_unit: Integer): Boolean;
    var
        cache_key: string;
        segment_pinyin: string;
        segment_text: string;
    begin
        Result := False;
        if (start_syllable > end_syllable) or (start_unit > end_unit) or
            ((end_unit - start_unit + 1) < c_short_composed_min_segment_units) then
        begin
            Exit;
        end;

        cache_key := build_range_key(start_syllable, end_syllable, start_unit, end_unit);
        if segment_exists_cache.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        segment_pinyin := join_syllable_slice(start_syllable, end_syllable);
        segment_text := join_text_unit_slice(start_unit, end_unit);
        Result := normalized_base_entry_exists(segment_pinyin, segment_text);
        segment_exists_cache.AddOrSetValue(cache_key, Result);
    end;

    function can_compose_from(const start_syllable: Integer; const start_unit: Integer;
        const min_segments_remaining: Integer): Boolean;
    var
        cache_key: string;
        end_syllable: Integer;
        end_unit: Integer;
        next_required_segments: Integer;
    begin
        if (start_syllable = Length(syllables)) and (start_unit = Length(text_units)) then
        begin
            Exit(min_segments_remaining <= 0);
        end;
        if (start_syllable >= Length(syllables)) or (start_unit >= Length(text_units)) then
        begin
            Exit(False);
        end;

        cache_key := build_compose_key(start_syllable, start_unit, min_segments_remaining);
        if compose_cache.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        Result := False;
        for end_syllable := start_syllable to High(syllables) do
        begin
            for end_unit := start_unit to High(text_units) do
            begin
                if not segment_exists(start_syllable, end_syllable, start_unit, end_unit) then
                begin
                    Continue;
                end;

                next_required_segments := Max(min_segments_remaining - 1, 0);
                if can_compose_from(end_syllable + 1, end_unit + 1, next_required_segments) then
                begin
                    Result := True;
                    compose_cache.AddOrSetValue(cache_key, Result);
                    Exit;
                end;
            end;
        end;

        compose_cache.AddOrSetValue(cache_key, Result);
    end;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not is_full_pinyin_key(pinyin_key)) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) or
        normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;

    text_units := split_text_units_local(text_key);
    if Length(text_units) < c_short_composed_min_units then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    segment_exists_cache := TDictionary<string, Boolean>.Create;
    compose_cache := TDictionary<string, Boolean>.Create;
    try
        Result := can_compose_from(0, 0, c_short_composed_min_segments);
    finally
        compose_cache.Free;
        segment_exists_cache.Free;
    end;
end;

function TncSqliteDictionary.is_nonbase_multi_segment_composed_exact_phrase(const pinyin: string;
    const text: string): Boolean;
const
    c_composed_exact_phrase_min_units = 6;
    c_composed_exact_phrase_min_segments = 3;
    c_composed_exact_phrase_segment_max_syllables = 8;
    c_composed_exact_phrase_segment_max_units = 4;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    segment_exists_cache: TDictionary<string, Boolean>;
    compose_cache: TDictionary<string, Boolean>;

    function build_range_key(const start_syllable: Integer; const end_syllable: Integer;
        const start_unit: Integer; const end_unit: Integer): string;
    begin
        Result := IntToStr(start_syllable) + ':' + IntToStr(end_syllable) + '|' +
            IntToStr(start_unit) + ':' + IntToStr(end_unit);
    end;

    function build_compose_key(const start_syllable: Integer; const start_unit: Integer;
        const min_segments_remaining: Integer): string;
    begin
        Result := IntToStr(start_syllable) + '|' + IntToStr(start_unit) + '|' +
            IntToStr(min_segments_remaining);
    end;

    function join_syllable_slice(const start_idx: Integer; const end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + syllables[idx];
        end;
    end;

    function join_text_unit_slice(const start_idx: Integer; const end_idx: Integer): string;
    var
        idx: Integer;
    begin
        Result := '';
        for idx := start_idx to end_idx do
        begin
            Result := Result + text_units[idx];
        end;
    end;

    function segment_exists(const start_syllable: Integer; const end_syllable: Integer;
        const start_unit: Integer; const end_unit: Integer): Boolean;
    var
        cache_key: string;
        segment_pinyin: string;
        segment_text: string;
    begin
        Result := False;
        if (start_syllable > end_syllable) or (start_unit > end_unit) then
        begin
            Exit;
        end;

        cache_key := build_range_key(start_syllable, end_syllable, start_unit, end_unit);
        if segment_exists_cache.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        segment_pinyin := join_syllable_slice(start_syllable, end_syllable);
        segment_text := join_text_unit_slice(start_unit, end_unit);
        Result := normalized_base_entry_exists(segment_pinyin, segment_text);
        segment_exists_cache.AddOrSetValue(cache_key, Result);
    end;

    function can_compose_from(const start_syllable: Integer; const start_unit: Integer;
        const min_segments_remaining: Integer): Boolean;
    var
        cache_key: string;
        end_syllable: Integer;
        end_unit: Integer;
        max_end_syllable: Integer;
        max_end_unit: Integer;
        next_required_segments: Integer;
    begin
        if (start_syllable = Length(syllables)) and (start_unit = Length(text_units)) then
        begin
            Exit(min_segments_remaining <= 0);
        end;
        if (start_syllable >= Length(syllables)) or (start_unit >= Length(text_units)) then
        begin
            Exit(False);
        end;

        cache_key := build_compose_key(start_syllable, start_unit, min_segments_remaining);
        if compose_cache.TryGetValue(cache_key, Result) then
        begin
            Exit;
        end;

        Result := False;
        max_end_syllable := Min(High(syllables),
            start_syllable + c_composed_exact_phrase_segment_max_syllables - 1);
        max_end_unit := Min(High(text_units),
            start_unit + c_composed_exact_phrase_segment_max_units - 1);
        for end_syllable := start_syllable to max_end_syllable do
        begin
            for end_unit := start_unit to max_end_unit do
            begin
                if not segment_exists(start_syllable, end_syllable, start_unit, end_unit) then
                begin
                    Continue;
                end;

                next_required_segments := Max(min_segments_remaining - 1, 0);
                if can_compose_from(end_syllable + 1, end_unit + 1, next_required_segments) then
                begin
                    Result := True;
                    compose_cache.AddOrSetValue(cache_key, Result);
                    Exit;
                end;
            end;
        end;

        compose_cache.AddOrSetValue(cache_key, Result);
    end;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if not is_full_pinyin_key(pinyin_key) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) then
    begin
        Exit;
    end;
    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;

    text_units := split_text_units_local(text_key);
    if Length(text_units) < c_composed_exact_phrase_min_units then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    if Length(syllables) <= 0 then
    begin
        Exit;
    end;

    segment_exists_cache := TDictionary<string, Boolean>.Create;
    compose_cache := TDictionary<string, Boolean>.Create;
    try
        Result := can_compose_from(0, 0, c_composed_exact_phrase_min_segments);
    finally
        compose_cache.Free;
        segment_exists_cache.Free;
    end;
end;

function TncSqliteDictionary.should_suppress_exact_query_learning(const pinyin: string;
    const text: string): Boolean;
begin
    Result := is_nonbase_multiword_composed_exact_phrase(pinyin, text) or
        is_nonbase_multi_segment_composed_exact_phrase(pinyin, text);
end;

function TncSqliteDictionary.is_nonbase_structured_rule_exact_phrase(const pinyin: string;
    const text: string): Boolean;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    tail_pinyin: string;
    tail_text: string;

    function head_matches_local: Boolean;
    begin
        Result := ((SameText(syllables[0], 'wo')) and
            (text_units[0] = string(Char($6211)))) or
            ((SameText(syllables[0], 'ni')) and
            (text_units[0] = string(Char($4F60)))) or
            ((SameText(syllables[0], 'zui')) and
            (text_units[0] = string(Char($6700)))) or
            ((SameText(syllables[0], 'bu')) and
            (text_units[0] = string(Char($4E0D)))) or
            ((SameText(syllables[0], 'hen')) and
            (text_units[0] = string(Char($5F88)))) or
            ((SameText(syllables[0], 'jiu')) and
            (text_units[0] = string(Char($5C31)))) or
            ((SameText(syllables[0], 'qing')) and
            (text_units[0] = string(Char($8BF7))));
    end;

    function fixed_suffix_text_matches_local(const suffix_pinyin: string;
        const suffix_text: string): Boolean;
    begin
        Result := ((SameText(suffix_pinyin, 'de')) and
            (suffix_text = string(Char($7684)))) or
            ((SameText(suffix_pinyin, 'le')) and
            (suffix_text = string(Char($4E86)))) or
            ((SameText(suffix_pinyin, 'zhe')) and
            (suffix_text = string(Char($7740)))) or
            ((SameText(suffix_pinyin, 'ba')) and
            (suffix_text = string(Char($5427)))) or
            ((SameText(suffix_pinyin, 'ma')) and
            ((suffix_text = string(Char($5417))) or
            (suffix_text = string(Char($55CE))))) or
            ((SameText(suffix_pinyin, 'la')) and
            (suffix_text = string(Char($5566))));
    end;

    function closed_particle_combo_matches_local: Boolean;
    var
        de_text: string;
        le_text: string;
        ba_text: string;
        ma_sc_text: string;
        ma_tc_text: string;
    begin
        de_text := string(Char($7684));
        le_text := string(Char($4E86));
        ba_text := string(Char($5427));
        ma_sc_text := string(Char($5417));
        ma_tc_text := string(Char($55CE));

        Result := ((SameText(pinyin_key, 'dema')) and
            ((text_key = de_text + ma_sc_text) or
            (text_key = de_text + ma_tc_text))) or
            ((SameText(pinyin_key, 'deba')) and
            (text_key = de_text + ba_text)) or
            ((SameText(pinyin_key, 'dele')) and
            (text_key = de_text + le_text)) or
            ((SameText(pinyin_key, 'dehao')) and
            (text_key = string(Char($5F97)) + string(Char($597D)))) or
            ((SameText(pinyin_key, 'leba')) and
            (text_key = le_text + ba_text)) or
            ((SameText(pinyin_key, 'lema')) and
            ((text_key = le_text + ma_sc_text) or
            (text_key = le_text + ma_tc_text)));
    end;

    function has_exact_fixed_suffix_phrase_local: Boolean;
    var
        prefix_pinyin: string;
        prefix_text: string;
        prefix_idx: Integer;
        suffix_pinyin: string;
        suffix_text: string;

        function try_suffix_local(const value: string): Boolean;
        begin
            Result := False;
            if (Length(pinyin_key) <= Length(value)) or
                (Copy(pinyin_key, Length(pinyin_key) - Length(value) + 1,
                Length(value)) <> value) then
            begin
                Exit;
            end;
            suffix_pinyin := value;
            Result := fixed_suffix_text_matches_local(suffix_pinyin,
                suffix_text);
        end;
    begin
        Result := False;
        if Length(text_units) < 3 then
        begin
            Exit;
        end;

        if (Length(text_units) >= 3) and
            (Length(pinyin_key) > Length('dehao')) and
            SameText(Copy(pinyin_key, Length(pinyin_key) - Length('dehao') + 1,
            Length('dehao')), 'dehao') and
            (text_units[High(text_units) - 1] = string(Char($5F97))) and
            (text_units[High(text_units)] = string(Char($597D))) then
        begin
            prefix_pinyin := Copy(pinyin_key, 1, Length(pinyin_key) -
                Length('hao'));
            prefix_text := '';
            for prefix_idx := 0 to High(text_units) - 1 do
            begin
                prefix_text := prefix_text + text_units[prefix_idx];
            end;
            if (prefix_pinyin <> '') and (prefix_text <> '') then
            begin
                Exit(normalized_base_entry_exists(prefix_pinyin, prefix_text) or
                    explicit_user_entry_exists(prefix_pinyin, prefix_text));
            end;
        end;

        suffix_text := text_units[High(text_units)];
        suffix_pinyin := '';
        if not (try_suffix_local('de') or try_suffix_local('le') or
            try_suffix_local('zhe') or
            try_suffix_local('ba') or try_suffix_local('ma') or
            try_suffix_local('la')) then
        begin
            Exit;
        end;

        prefix_pinyin := '';
        prefix_pinyin := Copy(pinyin_key, 1, Length(pinyin_key) -
            Length(suffix_pinyin));
        prefix_text := '';
        for prefix_idx := 0 to High(text_units) - 1 do
        begin
            prefix_text := prefix_text + text_units[prefix_idx];
        end;
        if (prefix_pinyin = '') or (prefix_text = '') then
        begin
            Exit;
        end;

        Result := normalized_base_entry_exists(prefix_pinyin, prefix_text) or
            explicit_user_entry_exists(prefix_pinyin, prefix_text);
    end;

    function has_exact_tail_phrase_local: Boolean;
    var
        tail_idx: Integer;
    begin
        tail_pinyin := '';
        tail_text := '';
        for tail_idx := 1 to High(syllables) do
        begin
            tail_pinyin := tail_pinyin + syllables[tail_idx];
            tail_text := tail_text + text_units[tail_idx];
        end;
        if (tail_pinyin = '') or (tail_text = '') then
        begin
            Exit(False);
        end;

        Result := normalized_base_entry_exists(tail_pinyin, tail_text) or
            explicit_user_entry_exists(tail_pinyin, tail_text);
    end;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not is_full_pinyin_key(pinyin_key)) then
    begin
        Exit;
    end;
    if closed_particle_combo_matches_local then
    begin
        Exit(True);
    end;
    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;

    text_units := split_text_units_local(text_key);
    if has_exact_fixed_suffix_phrase_local then
    begin
        Exit(True);
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    if (Length(syllables) < 3) or (Length(syllables) > 4) or
        (Length(text_units) <> Length(syllables)) then
    begin
        Exit;
    end;
    if not head_matches_local then
    begin
        Exit;
    end;

    if head_matches_local and has_exact_tail_phrase_local then
    begin
        Exit(True);
    end;

    Result := False;
end;

function TncSqliteDictionary.is_base_entry(const pinyin: string; const text: string): Boolean;
begin
    Result := normalized_base_entry_exists(pinyin, text);
end;

function TncSqliteDictionary.is_user_entry(const pinyin: string; const text: string): Boolean;
var
    pinyin_key: string;
    normalized_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    normalized_key := normalize_compact_pinyin_key(pinyin_key);
    text_key := Trim(text);
    if (normalized_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);

    // Red-x/delete is only for explicit user entries. Stats/latest rows are
    // ranking signals and must not make lexicon candidates look user-owned.
    Result := explicit_user_entry_exists(pinyin_key, text_key) or
        ((not SameText(normalized_key, pinyin_key)) and
        explicit_user_entry_exists(normalized_key, text_key)) or
        is_literal_user_entry(normalized_key, text_key);
end;

function TncSqliteDictionary.is_likely_noisy_constructed_phrase(const pinyin: string; const text: string;
    const commit_count: Integer; const user_weight: Integer): Boolean;
var
    pinyin_key: string;
    text_key: string;
    syllables: TArray<string>;
    text_units: TArray<string>;
    idx: Integer;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if (not is_full_pinyin_key(pinyin_key)) or (not is_valid_user_text(text_key)) then
    begin
        Exit;
    end;
    if is_whitelisted_constructed_phrase(pinyin_key, text_key) then
    begin
        Exit;
    end;
    if not has_any_base_phrase_for_pinyin(pinyin_key) then
    begin
        Exit;
    end;
    if normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;
    if (commit_count > 1) or (user_weight > 1) then
    begin
        Exit;
    end;

    syllables := split_full_pinyin_syllables(pinyin_key);
    text_units := split_text_units_local(text_key);
    if (Length(syllables) <> Length(text_units)) or (Length(text_units) < 2) or (Length(text_units) > 4) then
    begin
        Exit;
    end;

    for idx := 0 to High(text_units) do
    begin
        if not single_char_matches_pinyin(syllables[idx], text_units[idx]) then
        begin
            Exit;
        end;
    end;

    Result := True;
end;

function TncSqliteDictionary.should_suppress_constructed_user_phrase(const pinyin: string;
    const text: string; const commit_count: Integer; const user_weight: Integer): Boolean;
const
    c_constructed_phrase_commit_trust_min = 3;
    c_constructed_phrase_weight_trust_min = 3;
var
    pinyin_key: string;
begin
    Result := False;

    if user_weight > 0 then
    begin
        // dict_user rows represent explicit user-word confirmations. Keep
        // them before generic noisy-phrase suppression.
        Exit(False);
    end;

    if should_suppress_exact_query_learning(pinyin, text) then
    begin
        Exit(True);
    end;

    if not is_suppressible_nonbase_exact_phrase(pinyin, text) then
    begin
        Exit;
    end;

    pinyin_key := LowerCase(Trim(pinyin));
    if has_any_base_phrase_for_pinyin(pinyin_key) then
    begin
        // A dictionary phrase for the same full pinyin is the normal candidate.
        // Do not let old runtime-composed pollution stored in dict_user compete.
        Exit(True);
    end;

    // Treat one-off or low-support non-base full-pinyin chains as polluted
    // user learning, but still allow genuinely repeated explicit selections
    // to surface after enough confirmations.
    if (commit_count >= c_constructed_phrase_commit_trust_min) or
        (user_weight >= c_constructed_phrase_weight_trust_min) then
    begin
        Exit(False);
    end;

    Result := True;
end;

function TncSqliteDictionary.is_low_evidence_admin_place_alias_user_entry(
    const pinyin: string; const text: string; const latest_choice_text: string;
    const user_weight: Integer; const commit_count: Integer): Boolean;
const
    base_longer_prefix_sql =
        'SELECT pinyin, text FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?3';
    user_weight_sql =
        'SELECT COALESCE(MAX(weight), 0) FROM dict_user WHERE pinyin = ?1 AND text = ?2';
    user_stats_sql =
        'SELECT COALESCE(MAX(commit_count), 0) FROM dict_user_stats WHERE pinyin = ?1 AND text = ?2';
    c_probe_limit = 64;
    c_prefix_cache_limit = 256;

    function is_administrative_place_suffix(const suffix_text: string): Boolean;
    begin
        Result := SameText(suffix_text, string(Char($533A))) or
            SameText(suffix_text, string(Char($5340))) or
            SameText(suffix_text, string(Char($53BF))) or
            SameText(suffix_text, string(Char($7E23))) or
            SameText(suffix_text, string(Char($5E02))) or
            SameText(suffix_text, string(Char($9547))) or
            SameText(suffix_text, string(Char($93AE))) or
            SameText(suffix_text, string(Char($4E61))) or
            SameText(suffix_text, string(Char($9109))) or
            SameText(suffix_text, string(Char($6751))) or
            SameText(suffix_text, string(Char($5DDE))) or
            SameText(suffix_text, string(Char($7701))) or
            SameText(suffix_text, string(Char($65D7))) or
            SameText(suffix_text, string(Char($76DF))) or
            SameText(suffix_text, string(Char($65B0)) + string(Char($533A))) or
            SameText(suffix_text, string(Char($65B0)) + string(Char($5340))) or
            SameText(suffix_text, string(Char($5730)) + string(Char($533A))) or
            SameText(suffix_text, string(Char($5730)) + string(Char($5340))) or
            SameText(suffix_text, string(Char($8857)) + string(Char($9053))) or
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($533A))) or
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($5340))) or
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($5DDE))) or
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($53BF))) or
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($7E23))) or
            SameText(suffix_text, string(Char($7279)) + string(Char($522B)) +
            string(Char($884C)) + string(Char($653F)) + string(Char($533A))) or
            SameText(suffix_text, string(Char($7279)) + string(Char($5225)) +
            string(Char($884C)) + string(Char($653F)) + string(Char($5340)));
    end;

var
    pinyin_key: string;
    text_key: string;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    candidate_pinyin: string;
    candidate_text: string;
    candidate_prefix: string;
    candidate_suffix: string;
    query_syllable_count: Integer;
    text_key_unit_count: Integer;
    effective_user_weight: Integer;
    effective_commit_count: Integer;
    cached_prefix_rows: TArray<string>;
    cached_prefix_row: string;
    cached_prefix_row_count: Integer;
    separator_pos: Integer;
    potential_admin_alias: Boolean;

    function read_max_int_value(const sql_text: string): Integer;
    var
        local_stmt: Psqlite3_stmt;
    begin
        Result := 0;
        if (not m_user_ready) or (m_user_connection = nil) then
        begin
            Exit;
        end;

        local_stmt := nil;
        try
            if m_user_connection.prepare(sql_text, local_stmt) and
                m_user_connection.bind_text(local_stmt, 1, pinyin_key) and
                m_user_connection.bind_text(local_stmt, 2, text_key) and
                (m_user_connection.step(local_stmt) = SQLITE_ROW) then
            begin
                Result := m_user_connection.column_int(local_stmt, 0);
            end;
        finally
            if local_stmt <> nil then
            begin
                m_user_connection.finalize(local_stmt);
            end;
        end;
    end;
begin
    Result := False;
    pinyin_key := normalize_compact_pinyin_key(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_base_ready) then
    begin
        Exit;
    end;
    if (user_weight > 1) or (commit_count > 1) then
    begin
        Exit;
    end;
    effective_user_weight := user_weight;
    if effective_user_weight < 0 then
    begin
        effective_user_weight := read_max_int_value(user_weight_sql);
    end;
    effective_commit_count := commit_count;
    if effective_commit_count < 0 then
    begin
        effective_commit_count := read_max_int_value(user_stats_sql);
    end;
    if (effective_user_weight > 1) or (effective_commit_count > 1) then
    begin
        Exit;
    end;
    if (latest_choice_text <> '') and SameText(Trim(latest_choice_text), text_key) then
    begin
        Exit;
    end;
    query_syllable_count := 0;
    if (m_admin_place_query_syllable_count_cache = nil) or
        (not m_admin_place_query_syllable_count_cache.TryGetValue(pinyin_key,
        query_syllable_count)) then
    begin
        if is_full_pinyin_key(pinyin_key) then
        begin
            query_syllable_count :=
                Length(split_full_pinyin_syllables(pinyin_key));
        end;
        if m_admin_place_query_syllable_count_cache <> nil then
        begin
            if m_admin_place_query_syllable_count_cache.Count >=
                c_prefix_cache_limit then
            begin
                m_admin_place_query_syllable_count_cache.Clear;
            end;
            m_admin_place_query_syllable_count_cache.AddOrSetValue(pinyin_key,
                query_syllable_count);
        end;
    end;
    if query_syllable_count <= 0 then
    begin
        Exit;
    end;
    text_key_unit_count := get_text_unit_count_local(text_key);

    if (m_admin_place_longer_prefix_cache = nil) or
        (not m_admin_place_longer_prefix_cache.TryGetValue(pinyin_key,
        cached_prefix_rows)) then
    begin
        SetLength(cached_prefix_rows, 0);
        stmt := nil;
        try
            if not m_base_connection.prepare(base_longer_prefix_sql, stmt) then
            begin
                Exit;
            end;
            if (not m_base_connection.bind_text(stmt, 1, pinyin_key)) or
                (not m_base_connection.bind_text(stmt, 2,
                build_prefix_upper_bound(pinyin_key))) or
                (not m_base_connection.bind_int(stmt, 3, c_probe_limit)) then
            begin
                Exit;
            end;

            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                candidate_pinyin := normalize_compact_pinyin_key(
                    m_base_connection.column_text(stmt, 0));
                candidate_text := Trim(m_base_connection.column_text(stmt, 1));
                cached_prefix_row_count := Length(cached_prefix_rows);
                SetLength(cached_prefix_rows, cached_prefix_row_count + 1);
                cached_prefix_rows[cached_prefix_row_count] :=
                    candidate_pinyin + #1 + candidate_text;
                step_result := m_base_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;

        if m_admin_place_longer_prefix_cache <> nil then
        begin
            if m_admin_place_longer_prefix_cache.Count >= c_prefix_cache_limit then
            begin
                m_admin_place_longer_prefix_cache.Clear;
            end;
            m_admin_place_longer_prefix_cache.AddOrSetValue(pinyin_key,
                cached_prefix_rows);
        end;
    end;

    if Length(cached_prefix_rows) = 0 then
    begin
        Exit;
    end;

    potential_admin_alias := False;
    for cached_prefix_row in cached_prefix_rows do
    begin
        separator_pos := Pos(#1, cached_prefix_row);
        if separator_pos <= 0 then
        begin
            Continue;
        end;
        candidate_pinyin := Copy(cached_prefix_row, 1, separator_pos - 1);
        candidate_text := Copy(cached_prefix_row, separator_pos + 1, MaxInt);
        if (candidate_pinyin <> pinyin_key) and
            (Copy(candidate_pinyin, 1, Length(pinyin_key)) = pinyin_key) and
            (Copy(candidate_text, 1, Length(text_key)) = text_key) and
            (get_text_unit_count_local(candidate_text) >
            text_key_unit_count) and
            (Length(split_full_pinyin_syllables(candidate_pinyin)) >
            query_syllable_count) then
        begin
            candidate_prefix := copy_first_text_units(candidate_text,
                text_key_unit_count);
            if candidate_prefix = text_key then
            begin
                candidate_suffix := Copy(candidate_text,
                    Length(candidate_prefix) + 1, MaxInt);
                if is_administrative_place_suffix(candidate_suffix) then
                begin
                    potential_admin_alias := True;
                    Break;
                end;
            end;
        end;
    end;
    if (not potential_admin_alias) or
        normalized_base_entry_exists(pinyin_key, text_key) then
    begin
        Exit;
    end;
    Result := True;
end;

function TncSqliteDictionary.get_contains_popularity_score(const token: string): Integer;
const
    indexed_query_sql =
        'SELECT weight FROM dict_base_contains_popularity WHERE token = ?1 LIMIT 1';
    query_sql = 'SELECT COALESCE(SUM(b.weight), 0) FROM dict_base AS b ' +
        'WHERE instr(b.text, ?1) > 0 AND ' + c_base_text_evidence_scope_sql;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    indexed_query_ok: Boolean;
begin
    Result := 0;
    if (token = '') or (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if (m_contains_popularity_cache <> nil) and m_contains_popularity_cache.TryGetValue(token, Result) then
    begin
        Exit;
    end;

    if not m_contains_popularity_index_checked then
    begin
        m_contains_popularity_index_checked := True;
        m_contains_popularity_index_ready :=
            m_base_connection.prepare(indexed_query_sql,
            m_stmt_contains_popularity);
    end;

    if m_contains_popularity_index_ready and
        (m_stmt_contains_popularity <> nil) then
    begin
        indexed_query_ok := False;
        try
            if m_base_connection.reset(m_stmt_contains_popularity) and
                m_base_connection.clear_bindings(m_stmt_contains_popularity) and
                m_base_connection.bind_text(m_stmt_contains_popularity, 1,
                token) then
            begin
                step_result := m_base_connection.step(
                    m_stmt_contains_popularity);
                indexed_query_ok := (step_result = SQLITE_ROW) or
                    (step_result = SQLITE_DONE);
                if step_result = SQLITE_ROW then
                begin
                    Result := m_base_connection.column_int(
                        m_stmt_contains_popularity, 0);
                    if Result < 0 then
                    begin
                        Result := 0;
                    end;
                end;
            end;
        finally
            m_base_connection.reset(m_stmt_contains_popularity);
            m_base_connection.clear_bindings(m_stmt_contains_popularity);
        end;

        if indexed_query_ok then
        begin
            if m_contains_popularity_cache <> nil then
            begin
                m_contains_popularity_cache.AddOrSetValue(token, Result);
            end;
            Exit;
        end;
    end;

    stmt := nil;
    try
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;
        if not m_base_connection.bind_text(stmt, 1, token) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(stmt, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.AddOrSetValue(token, Result);
    end;
end;

function TncSqliteDictionary.get_prefix_popularity_score(const prefix: string): Integer;
const
    query_sql = 'SELECT COALESCE(SUM(b.weight), 0) FROM dict_base AS b ' +
        'WHERE b.text >= ?1 AND b.text < ?2 AND ' + c_base_text_evidence_scope_sql;
var
    step_result: Integer;
    upper_bound: string;
begin
    Result := 0;
    if (prefix = '') or (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if (m_prefix_popularity_cache <> nil) and m_prefix_popularity_cache.TryGetValue(prefix, Result) then
    begin
        Exit;
    end;
    upper_bound := build_prefix_upper_bound(prefix);

    try
        if m_stmt_prefix_popularity = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_prefix_popularity) then
            begin
                Exit;
            end;
        end;
        if (not m_base_connection.reset(m_stmt_prefix_popularity)) or
            (not m_base_connection.clear_bindings(m_stmt_prefix_popularity)) or
            (not m_base_connection.bind_text(m_stmt_prefix_popularity, 1, prefix)) or
            (not m_base_connection.bind_text(m_stmt_prefix_popularity, 2, upper_bound)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_prefix_popularity);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(m_stmt_prefix_popularity, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if m_stmt_prefix_popularity <> nil then
        begin
            m_base_connection.reset(m_stmt_prefix_popularity);
            m_base_connection.clear_bindings(m_stmt_prefix_popularity);
        end;
    end;

    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.AddOrSetValue(prefix, Result);
    end;
end;

function TncSqliteDictionary.get_pinyin_followup_popularity_score(const pinyin: string): Integer;
const
    query_sql =
        'SELECT COALESCE(SUM(weight), 0) FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND pinyin <> ?1';
var
    step_result: Integer;
    normalized: string;
    upper_bound: string;
begin
    Result := 0;
    normalized := normalize_compact_pinyin_key(pinyin);
    if (normalized = '') or (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if (m_pinyin_followup_popularity_cache <> nil) and
        m_pinyin_followup_popularity_cache.TryGetValue(normalized, Result) then
    begin
        Exit;
    end;
    upper_bound := build_prefix_upper_bound(normalized);

    try
        if m_stmt_pinyin_followup_popularity = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_pinyin_followup_popularity) then
            begin
                Exit;
            end;
        end;
        if (not m_base_connection.reset(m_stmt_pinyin_followup_popularity)) or
            (not m_base_connection.clear_bindings(m_stmt_pinyin_followup_popularity)) or
            (not m_base_connection.bind_text(m_stmt_pinyin_followup_popularity, 1, normalized)) or
            (not m_base_connection.bind_text(m_stmt_pinyin_followup_popularity, 2, upper_bound)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_pinyin_followup_popularity);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(m_stmt_pinyin_followup_popularity, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if m_stmt_pinyin_followup_popularity <> nil then
        begin
            m_base_connection.reset(m_stmt_pinyin_followup_popularity);
            m_base_connection.clear_bindings(m_stmt_pinyin_followup_popularity);
        end;
    end;

    if m_pinyin_followup_popularity_cache <> nil then
    begin
        m_pinyin_followup_popularity_cache.AddOrSetValue(normalized, Result);
    end;
end;

procedure TncSqliteDictionary.populate_prefix_popularity_scores(const prefixes: TArray<string>;
    const target_scores: TDictionary<string, Integer>);
var
    pending_keys: TList<string>;
    prefix_value: string;
    cached_score: Integer;
    idx: Integer;
begin
    if target_scores = nil then
    begin
        Exit;
    end;

    pending_keys := TList<string>.Create;
    try
        for idx := 0 to High(prefixes) do
        begin
            prefix_value := Trim(prefixes[idx]);
            if prefix_value = '' then
            begin
                Continue;
            end;

            if target_scores.ContainsKey(prefix_value) then
            begin
                Continue;
            end;
            if (m_prefix_popularity_cache <> nil) and
                m_prefix_popularity_cache.TryGetValue(prefix_value, cached_score) then
            begin
                target_scores.AddOrSetValue(prefix_value, cached_score);
                Continue;
            end;
            if pending_keys.IndexOf(prefix_value) < 0 then
            begin
                pending_keys.Add(prefix_value);
            end;
        end;

        if (pending_keys.Count <= 0) or (not ensure_open) or (not m_base_ready) then
        begin
            Exit;
        end;
        for idx := 0 to pending_keys.Count - 1 do
        begin
            target_scores.AddOrSetValue(pending_keys[idx], get_prefix_popularity_score(pending_keys[idx]));
        end;
    finally
        pending_keys.Free;
    end;
end;

procedure TncSqliteDictionary.populate_pinyin_followup_popularity_scores(const pinyin_keys: TArray<string>;
    const target_scores: TDictionary<string, Integer>);
var
    pending_keys: TList<string>;
    normalized_value: string;
    cached_score: Integer;
    idx: Integer;
begin
    if target_scores = nil then
    begin
        Exit;
    end;

    pending_keys := TList<string>.Create;
    try
        for idx := 0 to High(pinyin_keys) do
        begin
            normalized_value := normalize_compact_pinyin_key(pinyin_keys[idx]);
            if normalized_value = '' then
            begin
                Continue;
            end;

            if target_scores.ContainsKey(normalized_value) then
            begin
                Continue;
            end;
            if (m_pinyin_followup_popularity_cache <> nil) and
                m_pinyin_followup_popularity_cache.TryGetValue(normalized_value, cached_score) then
            begin
                target_scores.AddOrSetValue(normalized_value, cached_score);
                Continue;
            end;
            if pending_keys.IndexOf(normalized_value) < 0 then
            begin
                pending_keys.Add(normalized_value);
            end;
        end;

        if (pending_keys.Count <= 0) or (not ensure_open) or (not m_base_ready) then
        begin
            Exit;
        end;
        for idx := 0 to pending_keys.Count - 1 do
        begin
            target_scores.AddOrSetValue(pending_keys[idx],
                get_pinyin_followup_popularity_score(pending_keys[idx]));
        end;
    finally
        pending_keys.Free;
    end;
end;

function TncSqliteDictionary.get_single_char_exact_weight(const pinyin: string; const text_unit: string): Integer;
const
    query_sql =
        'SELECT COALESCE(MAX(weight), 0) FROM dict_base ' +
        'WHERE pinyin = ?1 AND text = ?2 AND length(text) = 1';
var
    step_result: Integer;
    normalized_pinyin: string;
    cache_key: string;
begin
    Result := 0;
    normalized_pinyin := normalize_compact_pinyin_key(pinyin);
    if (normalized_pinyin = '') or (text_unit = '') or (Length(text_unit) <> 1) or
        (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    cache_key := normalized_pinyin + #9 + text_unit;
    if (m_single_char_weight_cache <> nil) and
        m_single_char_weight_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if m_stmt_single_char_exact_weight = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_single_char_exact_weight) then
            begin
                Exit;
            end;
        end;
        if (not m_base_connection.reset(m_stmt_single_char_exact_weight)) or
            (not m_base_connection.clear_bindings(m_stmt_single_char_exact_weight)) or
            (not m_base_connection.bind_text(m_stmt_single_char_exact_weight, 1, normalized_pinyin)) or
            (not m_base_connection.bind_text(m_stmt_single_char_exact_weight, 2, text_unit)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_single_char_exact_weight);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(m_stmt_single_char_exact_weight, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if m_stmt_single_char_exact_weight <> nil then
        begin
            m_base_connection.reset(m_stmt_single_char_exact_weight);
            m_base_connection.clear_bindings(m_stmt_single_char_exact_weight);
        end;
    end;

    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_top_single_char_exact_weight(const pinyin: string): Integer;
const
    query_sql =
        'SELECT COALESCE(MAX(weight), 0) FROM dict_base ' +
        'WHERE pinyin = ?1 AND length(text) = 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    normalized_pinyin: string;
    cache_key: string;
begin
    Result := 0;
    normalized_pinyin := normalize_compact_pinyin_key(pinyin);
    if (normalized_pinyin = '') or (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;

    cache_key := normalized_pinyin + #9 + '<top-single-char>';
    if (m_single_char_weight_cache <> nil) and
        m_single_char_weight_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not (m_base_connection.prepare(query_sql, stmt) and
            m_base_connection.bind_text(stmt, 1, normalized_pinyin)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            Result := m_base_connection.column_int(stmt, 0);
            if Result < 0 then
            begin
                Result := 0;
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;

    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.should_ignore_weak_single_char_query_choice(const pinyin: string;
    const text_unit: string; const commit_count: Integer): Boolean;
const
    c_reliable_commit_count = 2;
    c_rare_single_char_weight_max = 180;
    c_rare_single_char_gap_min = 240;
    c_rare_single_char_ratio_min = 3;
var
    pinyin_key: string;
    text_key: string;
    candidate_weight: Integer;
    top_weight: Integer;
begin
    Result := False;
    if commit_count >= c_reliable_commit_count then
    begin
        Exit;
    end;

    pinyin_key := normalize_compact_pinyin_key(pinyin);
    text_key := Trim(text_unit);
    if (pinyin_key = '') or (text_key = '') or (not is_full_pinyin_key(pinyin_key)) or
        (get_valid_cjk_codepoint_count(text_key) <> 1) then
    begin
        Exit;
    end;

    candidate_weight := get_single_char_exact_weight(pinyin_key, text_key);
    top_weight := get_top_single_char_exact_weight(pinyin_key);
    if (candidate_weight <= 0) or (top_weight <= 0) or (top_weight <= candidate_weight) then
    begin
        Exit;
    end;

    Result := (candidate_weight <= c_rare_single_char_weight_max) and
        ((top_weight - candidate_weight) >= c_rare_single_char_gap_min) and
        (top_weight >= candidate_weight * c_rare_single_char_ratio_min);
end;

function TncSqliteDictionary.get_user_entry_count(const connection: TncSqliteConnection; out count: Integer): Boolean;
const
    sql_text = 'SELECT COUNT(1) FROM dict_user';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    count := 0;
    if (connection = nil) or not connection.opened then
    begin
        Result := False;
        Exit;
    end;

    stmt := nil;
    try
        if not connection.prepare(sql_text, stmt) then
        begin
            Result := False;
            Exit;
        end;

        step_result := connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            count := connection.column_int(stmt, 0);
            Result := True;
            Exit;
        end;
    finally
        if stmt <> nil then
        begin
            connection.finalize(stmt);
        end;
    end;

    Result := False;
end;

procedure TncSqliteDictionary.migrate_user_entries;
const
    select_sql = 'SELECT pinyin, text, weight, last_used FROM dict_user';
    insert_sql = 'INSERT OR IGNORE INTO dict_user(pinyin, text, weight, last_used) VALUES (?1, ?2, ?3, ?4)';
var
    user_count: Integer;
    stmt_select: Psqlite3_stmt;
    stmt_insert: Psqlite3_stmt;
    step_result: Integer;
    pinyin: string;
    text_value: string;
    weight_value: Integer;
    last_used_value: Integer;
begin
    if (not m_base_ready) or (not m_user_ready) then
    begin
        Exit;
    end;

    if not get_user_entry_count(m_user_connection, user_count) then
    begin
        Exit;
    end;

    if user_count > 0 then
    begin
        Exit;
    end;

    stmt_select := nil;
    stmt_insert := nil;
    try
        if not m_base_connection.prepare(select_sql, stmt_select) then
        begin
            Exit;
        end;
        if not m_user_connection.prepare(insert_sql, stmt_insert) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt_select);
        while step_result = SQLITE_ROW do
        begin
            pinyin := m_base_connection.column_text(stmt_select, 0);
            text_value := m_base_connection.column_text(stmt_select, 1);
            if (pinyin <> '') and is_valid_user_text(text_value) then
            begin
                weight_value := m_base_connection.column_int(stmt_select, 2);
                last_used_value := m_base_connection.column_int(stmt_select, 3);
                m_user_connection.reset(stmt_insert);
                m_user_connection.clear_bindings(stmt_insert);
                if m_user_connection.bind_text(stmt_insert, 1, pinyin) and
                    m_user_connection.bind_text(stmt_insert, 2, text_value) and
                    m_user_connection.bind_int(stmt_insert, 3, weight_value) and
                    m_user_connection.bind_int(stmt_insert, 4, last_used_value) then
                begin
                    m_user_connection.step(stmt_insert);
                end;
            end;

            step_result := m_base_connection.step(stmt_select);
        end;
    finally
        if stmt_select <> nil then
        begin
            m_base_connection.finalize(stmt_select);
        end;
        if stmt_insert <> nil then
        begin
            m_user_connection.finalize(stmt_insert);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_user_entries_existing_in_base;
const
    select_user_sql = 'SELECT pinyin, text FROM dict_user';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
var
    stmt_select: Psqlite3_stmt;
    stmt_delete: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    keys_to_delete: TList<string>;
    key_value: string;
    sep_index: Integer;
begin
    if (not m_base_ready) or (not m_user_ready) then
    begin
        Exit;
    end;

    keys_to_delete := TList<string>.Create;
    stmt_select := nil;
    try
        if not m_user_connection.prepare(select_user_sql, stmt_select) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt_select);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := m_user_connection.column_text(stmt_select, 0);
            text_value := m_user_connection.column_text(stmt_select, 1);
            if (pinyin_value <> '') and (text_value <> '') then
            begin
                if normalized_base_entry_exists(pinyin_value, text_value) then
                begin
                    keys_to_delete.Add(pinyin_value + #1 + text_value);
                end;
            end;

            step_result := m_user_connection.step(stmt_select);
        end;
    finally
        if stmt_select <> nil then
        begin
            m_user_connection.finalize(stmt_select);
        end;
    end;

    if keys_to_delete.Count = 0 then
    begin
        keys_to_delete.Free;
        Exit;
    end;

    stmt_delete := nil;
    try
        if not m_user_connection.prepare(delete_user_sql, stmt_delete) then
        begin
            Exit;
        end;

        for key_value in keys_to_delete do
        begin
            sep_index := Pos(#1, key_value);
            if sep_index <= 0 then
            begin
                Continue;
            end;

            pinyin_value := Copy(key_value, 1, sep_index - 1);
            text_value := Copy(key_value, sep_index + 1, MaxInt);
            if (pinyin_value = '') or (text_value = '') then
            begin
                Continue;
            end;

            if m_user_connection.reset(stmt_delete) and
                m_user_connection.clear_bindings(stmt_delete) and
                m_user_connection.bind_text(stmt_delete, 1, pinyin_value) and
                m_user_connection.bind_text(stmt_delete, 2, text_value) then
            begin
                m_user_connection.step(stmt_delete);
            end;
        end;
    finally
        keys_to_delete.Free;
        if stmt_delete <> nil then
        begin
            m_user_connection.finalize(stmt_delete);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_bigram_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_bigram';
    delete_sql =
        'DELETE FROM dict_user_bigram WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_bigram ' +
        'ORDER BY last_used ASC, commit_count ASC, left_text ASC, text ASC LIMIT ?1)';
    c_bigram_prune_interval = 64;
    c_bigram_max_rows = 50000;
    c_bigram_target_rows = 45000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (m_user_connection = nil) or (not m_user_ready) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_bigram_prune_countdown);
        if m_bigram_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;
    m_bigram_prune_countdown := c_bigram_prune_interval;

    row_count := 0;
    stmt := nil;
    try
        if m_user_connection.prepare(count_sql, stmt) then
        begin
            step_result := m_user_connection.step(stmt);
            if step_result = SQLITE_ROW then
            begin
                row_count := m_user_connection.column_int(stmt, 0);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_bigram_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_bigram_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(delete_sql, stmt) and
            m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

end;

procedure TncSqliteDictionary.prune_trigram_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_trigram';
    delete_sql =
        'DELETE FROM dict_user_trigram WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_trigram ' +
        'ORDER BY last_used ASC, commit_count ASC, prev_prev_text ASC, prev_text ASC, text ASC LIMIT ?1)';
    c_trigram_prune_interval = 64;
    c_trigram_max_rows = 80000;
    c_trigram_target_rows = 70000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (m_user_connection = nil) or (not m_user_ready) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_trigram_prune_countdown);
        if m_trigram_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;
    m_trigram_prune_countdown := c_trigram_prune_interval;

    row_count := 0;
    stmt := nil;
    try
        if m_user_connection.prepare(count_sql, stmt) then
        begin
            step_result := m_user_connection.step(stmt);
            if step_result = SQLITE_ROW then
            begin
                row_count := m_user_connection.column_int(stmt, 0);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_trigram_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_trigram_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(delete_sql, stmt) and
            m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_query_path_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_query_path';
    delete_sql =
        'DELETE FROM dict_user_query_path WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_query_path ' +
        'ORDER BY last_used ASC, commit_count ASC LIMIT ?1)';
    c_query_path_prune_interval = 64;
    c_query_path_max_rows = 60000;
    c_query_path_target_rows = 52000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_query_path_prune_countdown);
        if m_query_path_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;

    m_query_path_prune_countdown := c_query_path_prune_interval;
    stmt := nil;
    row_count := 0;
    try
        if not m_user_connection.prepare(count_sql, stmt) then
        begin
            Exit;
        end;
        step_result := m_user_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            row_count := m_user_connection.column_int(stmt, 0);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_query_path_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_query_path_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(delete_sql, stmt) then
        begin
            Exit;
        end;
        if not m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            Exit;
        end;
        m_user_connection.step(stmt);
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_query_path_penalty_rows_if_needed(const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_query_path_penalty';
    delete_sql =
        'DELETE FROM dict_user_query_path_penalty WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_query_path_penalty ' +
        'ORDER BY last_used ASC, penalty ASC LIMIT ?1)';
    c_query_path_penalty_prune_interval = 64;
    c_query_path_penalty_max_rows = 60000;
    c_query_path_penalty_target_rows = 52000;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    row_count: Integer;
    delete_count: Integer;
begin
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if not force then
    begin
        Dec(m_query_path_penalty_prune_countdown);
        if m_query_path_penalty_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;

    m_query_path_penalty_prune_countdown := c_query_path_penalty_prune_interval;
    stmt := nil;
    row_count := 0;
    try
        if not m_user_connection.prepare(count_sql, stmt) then
        begin
            Exit;
        end;
        step_result := m_user_connection.step(stmt);
        if step_result = SQLITE_ROW then
        begin
            row_count := m_user_connection.column_int(stmt, 0);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if row_count <= c_query_path_penalty_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_query_path_penalty_target_rows;
    if delete_count <= 0 then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(delete_sql, stmt) then
        begin
            Exit;
        end;
        if not m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            Exit;
        end;
        m_user_connection.step(stmt);
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.prune_context_query_choice_rows_if_needed(
    const force: Boolean);
const
    count_sql = 'SELECT COUNT(1) FROM dict_user_context_query_choice';
    delete_sql =
        'DELETE FROM dict_user_context_query_choice WHERE rowid IN (' +
        'SELECT rowid FROM dict_user_context_query_choice ' +
        'ORDER BY last_used ASC, commit_count ASC LIMIT ?1)';
    c_prune_interval = 64;
    c_max_rows = 4096;
    c_target_rows = 3584;
var
    stmt: Psqlite3_stmt;
    row_count: Integer;
    delete_count: Integer;
begin
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;
    if not force then
    begin
        Dec(m_context_query_choice_prune_countdown);
        if m_context_query_choice_prune_countdown > 0 then
        begin
            Exit;
        end;
    end;
    m_context_query_choice_prune_countdown := c_prune_interval;

    row_count := 0;
    stmt := nil;
    try
        if m_user_connection.prepare(count_sql, stmt) and
            (m_user_connection.step(stmt) = SQLITE_ROW) then
        begin
            row_count := m_user_connection.column_int(stmt, 0);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
    if row_count <= c_max_rows then
    begin
        Exit;
    end;

    delete_count := row_count - c_target_rows;
    stmt := nil;
    try
        if m_user_connection.prepare(delete_sql, stmt) and
            m_user_connection.bind_int(stmt, 1, delete_count) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
    if m_context_query_choice_bonus_cache <> nil then
    begin
        m_context_query_choice_bonus_cache.Clear;
    end;
end;

procedure TncSqliteDictionary.load_base_exact_pinyin_bloom;
const
    c_bloom_byte_count = 1 shl 19;
    c_bloom_bit_mask = (c_bloom_byte_count * 8) - 1;
    c_bloom_probe_count = 4;
    base_pinyin_sql = 'SELECT pinyin FROM dict_base';
    alias_pinyin_sql = 'SELECT compact_pinyin FROM dict_base_pinyin_alias';
var
    stmt: Psqlite3_stmt;

    procedure add_key(const raw_key: string);
    var
        key_value: string;
        hash1: Cardinal;
        hash2: Cardinal;
        char_idx: Integer;
        probe_idx: Integer;
        bit_idx: Cardinal;
        byte_idx: Cardinal;
        bit_mask: Byte;
    begin
        key_value := normalize_compact_pinyin_key(raw_key);
        if key_value = '' then
        begin
            Exit;
        end;

        hash1 := 2166136261;
        hash2 := 5381;
        for char_idx := 1 to Length(key_value) do
        begin
            hash1 := (hash1 xor Ord(key_value[char_idx])) * 16777619;
            hash2 := ((hash2 shl 5) + hash2) xor Ord(key_value[char_idx]);
        end;
        hash2 := hash2 or 1;

        for probe_idx := 0 to c_bloom_probe_count - 1 do
        begin
            bit_idx := Cardinal((UInt64(hash1) + UInt64(probe_idx) *
                UInt64(hash2)) and UInt64(c_bloom_bit_mask));
            byte_idx := bit_idx shr 3;
            bit_mask := Byte(1 shl (bit_idx and 7));
            m_base_exact_pinyin_bloom[byte_idx] :=
                m_base_exact_pinyin_bloom[byte_idx] or bit_mask;
        end;
    end;

    function add_query(const sql: string): Boolean;
    var
        step_result: Integer;
    begin
        Result := False;
        stmt := nil;
        try
            if not m_base_connection.prepare(sql, stmt) then
            begin
                Exit;
            end;
            step_result := m_base_connection.step(stmt);
            while step_result = SQLITE_ROW do
            begin
                add_key(m_base_connection.column_text(stmt, 0));
                step_result := m_base_connection.step(stmt);
            end;
            Result := step_result = SQLITE_DONE;
        finally
            if stmt <> nil then
            begin
                m_base_connection.finalize(stmt);
            end;
        end;
    end;

begin
    m_base_exact_pinyin_bloom_ready := False;
    SetLength(m_base_exact_pinyin_bloom, 0);
    if (not m_base_ready) or (not m_base_connection_read_only) or
        (m_base_connection = nil) then
    begin
        Exit;
    end;

    SetLength(m_base_exact_pinyin_bloom, c_bloom_byte_count);
    FillChar(m_base_exact_pinyin_bloom[0], Length(m_base_exact_pinyin_bloom), 0);
    if (not add_query(base_pinyin_sql)) or (not add_query(alias_pinyin_sql)) then
    begin
        SetLength(m_base_exact_pinyin_bloom, 0);
        Exit;
    end;
    m_base_exact_pinyin_bloom_ready := True;
end;

function TncSqliteDictionary.base_exact_pinyin_may_exist(
    const pinyin: string): Boolean;
const
    c_bloom_bit_mask = ((1 shl 19) * 8) - 1;
    c_bloom_probe_count = 4;
var
    key_value: string;
    hash1: Cardinal;
    hash2: Cardinal;
    char_idx: Integer;
    probe_idx: Integer;
    bit_idx: Cardinal;
    byte_idx: Cardinal;
    bit_mask: Byte;
begin
    if (not m_base_exact_pinyin_bloom_ready) or
        (Length(m_base_exact_pinyin_bloom) = 0) then
    begin
        Exit(True);
    end;

    key_value := normalize_compact_pinyin_key(pinyin);
    if key_value = '' then
    begin
        Exit(False);
    end;

    hash1 := 2166136261;
    hash2 := 5381;
    for char_idx := 1 to Length(key_value) do
    begin
        hash1 := (hash1 xor Ord(key_value[char_idx])) * 16777619;
        hash2 := ((hash2 shl 5) + hash2) xor Ord(key_value[char_idx]);
    end;
    hash2 := hash2 or 1;

    for probe_idx := 0 to c_bloom_probe_count - 1 do
    begin
        bit_idx := Cardinal((UInt64(hash1) + UInt64(probe_idx) *
            UInt64(hash2)) and UInt64(c_bloom_bit_mask));
        byte_idx := bit_idx shr 3;
        bit_mask := Byte(1 shl (bit_idx and 7));
        if (m_base_exact_pinyin_bloom[byte_idx] and bit_mask) = 0 then
        begin
            Exit(False);
        end;
    end;
    Result := True;
end;

function TncSqliteDictionary.open_internal(
    const defer_optional_model_loads: Boolean): Boolean;
begin
    m_ready := False;
    m_base_ready := False;
    m_base_connection_read_only := False;
    m_user_ready := False;
    m_user_initialization_deferred := False;
    m_defer_optional_model_loads := defer_optional_model_loads;
    m_literal_user_words_available := -1;
    Result := False;

    if (m_base_db_path = '') and (m_user_db_path = '') then
    begin
        Exit;
    end;

    if m_base_db_path <> '' then
    begin
        if m_base_connection = nil then
        begin
            m_base_connection := TncSqliteConnection.create(m_base_db_path);
        end;

        m_base_ready := m_base_connection.open(SQLITE_OPEN_READONLY);
        m_base_connection_read_only := m_base_ready;
        if not m_base_ready then
        begin
            m_base_ready := m_base_connection.open(SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE);
            m_base_connection_read_only := False;
            if m_base_ready then
            begin
                ensure_schema(m_base_connection);
            end;
        end;
        if m_base_ready then
        begin
            configure_base_connection;
            if not m_defer_optional_model_loads then
            begin
                load_base_exact_pinyin_bloom;
                load_query_path_bonus_cache;
                load_lm_transition_bonus_cache;
            end;
        end;
    end;

    open_user_connection;

    if m_base_ready and m_user_ready and m_prune_user_entries_on_open and
        (not m_defer_optional_model_loads) then
    begin
        migrate_user_entries;
        prune_user_entries_existing_in_base;
        prune_suspicious_user_entries;
    end;

    if m_user_ready then
    begin
        m_user_data_version := 0;
        m_last_user_data_version_check_tick := 0;
        refresh_user_data_version_if_changed(True);
    end;

    m_ready := m_base_ready or m_user_ready;
    Result := m_ready;
end;

procedure TncSqliteDictionary.open_user_connection;
begin
    m_user_ready := False;
    m_user_initialization_deferred := False;
    if m_user_db_path <> '' then
    begin
        if m_defer_optional_model_loads and
            (not FileExists(m_user_db_path)) then
        begin
            // A first-run user database is empty by definition. Let the
            // background full provider create its schema instead of blocking
            // the first visible key on dozens of CREATE INDEX statements.
            m_user_initialization_deferred := True;
        end;
        if not m_user_initialization_deferred then
        begin
            if m_user_connection = nil then
            begin
                m_user_connection := TncSqliteConnection.create(m_user_db_path);
            end;

            m_user_ready := m_user_connection.open(
                SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE);
            if m_user_ready then
            begin
                m_user_ready := ensure_schema(m_user_connection);
                if m_user_ready then
                begin
                    configure_user_connection;
                    if not m_defer_optional_model_loads then
                    begin
                        prune_bigram_rows_if_needed(True);
                        prune_trigram_rows_if_needed(True);
                        prune_query_path_rows_if_needed(True);
                        prune_query_path_penalty_rows_if_needed(True);
                    end;
                end;
            end;
        end;
    end;
end;

function TncSqliteDictionary.open: Boolean;
begin
    Result := open_internal(False);
end;

function TncSqliteDictionary.open_deferred: Boolean;
begin
    Result := open_internal(True);
end;

function TncSqliteDictionary.reload_user_dictionary: Boolean;
begin
    Result := False;
    if m_write_batch_depth > 0 then
    begin
        Exit;
    end;

    // User learning/checkpoints must not discard the immutable base models.
    // Reopen only this connection, also supporting restored user databases.
    clear_cached_user_statements;
    m_user_ready := False;
    if m_user_connection <> nil then
    begin
        m_user_connection.close;
    end;
    clear_user_read_caches;
    m_literal_user_words_available := -1;
    m_user_data_version := 0;
    m_last_user_data_version_check_tick := 0;
    open_user_connection;
    refresh_user_data_version_if_changed(True);
    m_ready := m_base_ready or m_user_ready;
    Result := m_user_ready or m_user_initialization_deferred or
        (m_user_db_path = '');
end;

procedure TncSqliteDictionary.close;
begin
    clear_dictionary_lookup_caches;
    clear_cached_user_statements;
    if (m_stmt_base_query_path_bonus <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_base_query_path_bonus);
        m_stmt_base_query_path_bonus := nil;
    end;
    if (m_stmt_exact_pair_path_evidence <> nil) and
        (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_exact_pair_path_evidence);
        m_stmt_exact_pair_path_evidence := nil;
    end;
    if (m_stmt_compound_tail_support <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_compound_tail_support);
        m_stmt_compound_tail_support := nil;
    end;
    if (m_stmt_compound_tail_prefix_support <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_compound_tail_prefix_support);
        m_stmt_compound_tail_prefix_support := nil;
    end;
    if (m_stmt_compound_tail_prefix_range_support <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_compound_tail_prefix_range_support);
        m_stmt_compound_tail_prefix_range_support := nil;
    end;
    if (m_stmt_prefix_popularity <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_prefix_popularity);
        m_stmt_prefix_popularity := nil;
    end;
    if (m_stmt_pinyin_followup_popularity <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_pinyin_followup_popularity);
        m_stmt_pinyin_followup_popularity := nil;
    end;
    if (m_stmt_contains_popularity <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_contains_popularity);
        m_stmt_contains_popularity := nil;
    end;
    if (m_stmt_base_text_prefix_bonus <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_base_text_prefix_bonus);
        m_stmt_base_text_prefix_bonus := nil;
    end;
    if (m_stmt_single_char_exact_weight <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_single_char_exact_weight);
        m_stmt_single_char_exact_weight := nil;
    end;
    if (m_stmt_exact_base <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_exact_base);
        m_stmt_exact_base := nil;
    end;
    if (m_stmt_exact_base_alias <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_exact_base_alias);
        m_stmt_exact_base_alias := nil;
    end;
    if (m_stmt_exact_component_base <> nil) and
        (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_exact_component_base);
        m_stmt_exact_component_base := nil;
    end;
    if (m_stmt_exact_component_base_alias <> nil) and
        (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_exact_component_base_alias);
        m_stmt_exact_component_base_alias := nil;
    end;
    if (m_stmt_exact_admin_prefix <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_exact_admin_prefix);
        m_stmt_exact_admin_prefix := nil;
    end;
    if (m_stmt_lookup_base <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_lookup_base);
        m_stmt_lookup_base := nil;
    end;
    if (m_stmt_lookup_single_char_exact <> nil) and (m_base_connection <> nil) then
    begin
        m_base_connection.finalize(m_stmt_lookup_single_char_exact);
        m_stmt_lookup_single_char_exact := nil;
    end;
    if m_base_connection <> nil then
    begin
        if m_stmt_char_lm_entries_1 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_1);
            m_stmt_char_lm_entries_1 := nil;
        end;
        if m_stmt_char_lm_entries_8 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_8);
            m_stmt_char_lm_entries_8 := nil;
        end;
        if m_stmt_char_lm_entries_16 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_16);
            m_stmt_char_lm_entries_16 := nil;
        end;
        if m_stmt_char_lm_entries_32 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_32);
            m_stmt_char_lm_entries_32 := nil;
        end;
        if m_stmt_char_lm_entries_64 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_64);
            m_stmt_char_lm_entries_64 := nil;
        end;
        if m_stmt_char_lm_entries_128 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_128);
            m_stmt_char_lm_entries_128 := nil;
        end;
        if m_stmt_char_lm_entries_256 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_256);
            m_stmt_char_lm_entries_256 := nil;
        end;
        if m_stmt_char_lm_entries_400 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_lm_entries_400);
            m_stmt_char_lm_entries_400 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_1 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_1);
            m_stmt_char_reverse_lm_entries_1 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_8 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_8);
            m_stmt_char_reverse_lm_entries_8 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_16 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_16);
            m_stmt_char_reverse_lm_entries_16 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_32 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_32);
            m_stmt_char_reverse_lm_entries_32 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_64 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_64);
            m_stmt_char_reverse_lm_entries_64 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_128 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_128);
            m_stmt_char_reverse_lm_entries_128 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_256 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_256);
            m_stmt_char_reverse_lm_entries_256 := nil;
        end;
        if m_stmt_char_reverse_lm_entries_400 <> nil then
        begin
            m_base_connection.finalize(m_stmt_char_reverse_lm_entries_400);
            m_stmt_char_reverse_lm_entries_400 := nil;
        end;
    end;
    if m_base_connection <> nil then
    begin
        m_base_connection.close;
    end;
    if m_user_connection <> nil then
    begin
        m_user_connection.close;
    end;
    m_write_batch_depth := 0;

    m_ready := False;
    m_base_ready := False;
    m_base_connection_read_only := False;
    m_user_ready := False;
    m_user_initialization_deferred := False;
    m_base_exact_pinyin_bloom_ready := False;
    SetLength(m_base_exact_pinyin_bloom, 0);
    m_short_lookup_cache_prewarmed := False;
    m_contains_popularity_index_checked := False;
    m_contains_popularity_index_ready := False;
    if m_contains_popularity_cache <> nil then
    begin
        m_contains_popularity_cache.Clear;
    end;
    if m_prefix_popularity_cache <> nil then
    begin
        m_prefix_popularity_cache.Clear;
    end;
    if m_pinyin_followup_popularity_cache <> nil then
    begin
        m_pinyin_followup_popularity_cache.Clear;
    end;
    if m_base_text_prefix_bonus_cache <> nil then
    begin
        m_base_text_prefix_bonus_cache.Clear;
    end;
    if m_single_char_weight_cache <> nil then
    begin
        m_single_char_weight_cache.Clear;
    end;
    if m_context_bonus_cache <> nil then
    begin
        m_context_bonus_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Clear;
    end;
    if m_context_query_choice_bonus_cache <> nil then
    begin
        m_context_query_choice_bonus_cache.Clear;
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Clear;
    end;
    if m_query_path_bonus_cache <> nil then
    begin
        m_query_path_bonus_cache.Clear;
    end;
    m_query_path_bonus_cache_loaded := False;
    if m_base_query_path_pinyin_cache <> nil then
    begin
        m_base_query_path_pinyin_cache.Clear;
    end;
    m_base_query_path_pinyin_cache_loaded := False;
    if m_lm_transition_bonus_cache <> nil then
    begin
        m_lm_transition_bonus_cache.Clear;
    end;
    if m_exact_pair_path_evidence_cache <> nil then
    begin
        m_exact_pair_path_evidence_cache.Clear;
    end;
    m_lm_transition_cache_loaded := False;
    if m_char_lm_entry_cache <> nil then
    begin
        m_char_lm_entry_cache.Clear;
    end;
    if m_char_lm_cache_order <> nil then
    begin
        m_char_lm_cache_order.Clear;
    end;
    if m_char_lm_text_score_cache <> nil then
    begin
        m_char_lm_text_score_cache.Clear;
    end;
    if m_char_lm_text_score_cache_order <> nil then
    begin
        m_char_lm_text_score_cache_order.Clear;
    end;
    if m_char_lm_short_context_text_score_cache <> nil then
    begin
        m_char_lm_short_context_text_score_cache.Clear;
    end;
    if m_char_lm_short_context_text_score_cache_order <> nil then
    begin
        m_char_lm_short_context_text_score_cache_order.Clear;
    end;
    m_char_lm_available := -1;
    if m_char_reverse_lm_entry_cache <> nil then
    begin
        m_char_reverse_lm_entry_cache.Clear;
    end;
    if m_char_reverse_lm_cache_order <> nil then
    begin
        m_char_reverse_lm_cache_order.Clear;
    end;
    if m_char_reverse_lm_text_score_cache <> nil then
    begin
        m_char_reverse_lm_text_score_cache.Clear;
    end;
    if m_char_reverse_lm_text_score_cache_order <> nil then
    begin
        m_char_reverse_lm_text_score_cache_order.Clear;
    end;
    m_char_reverse_lm_available := -1;
    if m_compound_tail_support_cache <> nil then
    begin
        m_compound_tail_support_cache.Clear;
    end;
    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_candidate_penalty_pinyin_loaded_cache <> nil then
    begin
        m_candidate_penalty_pinyin_loaded_cache.Clear;
    end;
    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Clear;
    end;
    m_user_data_version := 0;
    m_last_user_data_version_check_tick := 0;
end;

procedure TncSqliteDictionary.clear_cached_user_statements;
begin
    if (m_stmt_query_choice_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_choice_bonus);
        m_stmt_query_choice_bonus := nil;
    end;
    if (m_stmt_context_query_choice_bonus <> nil) and
        (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_context_query_choice_bonus);
        m_stmt_context_query_choice_bonus := nil;
    end;
    if (m_stmt_query_latest_choice_text <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_latest_choice_text);
        m_stmt_query_latest_choice_text := nil;
    end;
    if (m_stmt_context_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_context_bonus);
        m_stmt_context_bonus := nil;
    end;
    if (m_stmt_context_trigram_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_context_trigram_bonus);
        m_stmt_context_trigram_bonus := nil;
    end;
    if (m_stmt_query_path_bonus <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_path_bonus);
        m_stmt_query_path_bonus := nil;
    end;
    if (m_stmt_query_path_penalty <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_query_path_penalty);
        m_stmt_query_path_penalty := nil;
    end;
    if (m_stmt_candidate_penalty <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_candidate_penalty);
        m_stmt_candidate_penalty := nil;
    end;
    if (m_stmt_exact_user <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_exact_user);
        m_stmt_exact_user := nil;
    end;
    if (m_stmt_exact_component_user <> nil) and
        (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_exact_component_user);
        m_stmt_exact_component_user := nil;
    end;
    if (m_stmt_record_context_pair_update <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_pair_update);
        m_stmt_record_context_pair_update := nil;
    end;
    if (m_stmt_record_context_pair_insert <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_pair_insert);
        m_stmt_record_context_pair_insert := nil;
    end;
    if (m_stmt_record_context_trigram_update <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_trigram_update);
        m_stmt_record_context_trigram_update := nil;
    end;
    if (m_stmt_record_context_trigram_insert <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_context_trigram_insert);
        m_stmt_record_context_trigram_insert := nil;
    end;
    if (m_stmt_record_query_path_update <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_query_path_update);
        m_stmt_record_query_path_update := nil;
    end;
    if (m_stmt_record_query_path_insert <> nil) and (m_user_connection <> nil) then
    begin
        m_user_connection.finalize(m_stmt_record_query_path_insert);
        m_stmt_record_query_path_insert := nil;
    end;
end;

procedure TncSqliteDictionary.clear_user_read_caches;
begin
    clear_dictionary_lookup_caches;
    if m_fuzzy_choice_bonus_cache <> nil then
    begin
        m_fuzzy_choice_bonus_cache.Clear;
    end;
    if m_fuzzy_choice_query_loaded_cache <> nil then
    begin
        m_fuzzy_choice_query_loaded_cache.Clear;
    end;
    if m_context_bonus_cache <> nil then
    begin
        m_context_bonus_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Clear;
    end;
    if m_context_query_choice_bonus_cache <> nil then
    begin
        m_context_query_choice_bonus_cache.Clear;
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Clear;
    end;
    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Clear;
    end;
    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_candidate_penalty_pinyin_loaded_cache <> nil then
    begin
        m_candidate_penalty_pinyin_loaded_cache.Clear;
    end;
end;

procedure TncSqliteDictionary.clear_dictionary_lookup_caches;
begin
    if m_user_script_cache <> nil then m_user_script_cache.Clear;
    if m_user_storage_text_cache <> nil then m_user_storage_text_cache.Clear;
    if m_fuzzy_lookup_result_cache <> nil then
    begin
        m_fuzzy_lookup_result_cache.Clear;
    end;
    if m_fuzzy_lookup_result_cache_order <> nil then
    begin
        m_fuzzy_lookup_result_cache_order.Clear;
    end;
    if m_lookup_result_cache <> nil then
    begin
        m_lookup_result_cache.Clear;
    end;
    if m_mixed_abbreviation_cache <> nil then
    begin
        m_mixed_abbreviation_cache.Clear;
    end;
    if m_word_completion_cache <> nil then
    begin
        m_word_completion_cache.Clear;
    end;
    if m_next_character_cache <> nil then
    begin
        m_next_character_cache.Clear;
    end;
    if m_lookup_result_cache_order <> nil then
    begin
        m_lookup_result_cache_order.Clear;
    end;
    if m_exact_lookup_result_cache <> nil then
    begin
        m_exact_lookup_result_cache.Clear;
    end;
    if m_exact_lookup_result_cache_order <> nil then
    begin
        m_exact_lookup_result_cache_order.Clear;
    end;
    if m_exact_component_lookup_cache <> nil then
    begin
        m_exact_component_lookup_cache.Clear;
    end;
    if m_exact_component_lookup_cache_order <> nil then
    begin
        m_exact_component_lookup_cache_order.Clear;
    end;
    if m_prefix_lookup_result_cache <> nil then
    begin
        m_prefix_lookup_result_cache.Clear;
    end;
    if m_candidate_prefix_completion_cache <> nil then
        m_candidate_prefix_completion_cache.Clear;
    if m_one_key_completion_cache <> nil then
    begin
        m_one_key_completion_cache.Clear;
    end;
    if m_long_one_key_completion_cache <> nil then
    begin
        m_long_one_key_completion_cache.Clear;
    end;
    if m_one_key_completion_competition_cache <> nil then
    begin
        m_one_key_completion_competition_cache.Clear;
    end;
    if m_one_key_completion_pair_audit_cache <> nil then
    begin
        m_one_key_completion_pair_audit_cache.Clear;
    end;
    if m_short_promotion_cache <> nil then
    begin
        m_short_promotion_cache.Clear;
    end;
    if m_exact_text_prefix_cache <> nil then
    begin
        m_exact_text_prefix_cache.Clear;
    end;
    if m_literal_lookup_result_cache <> nil then
    begin
        m_literal_lookup_result_cache.Clear;
    end;
    if m_exact_base_entry_cache <> nil then
    begin
        m_exact_base_entry_cache.Clear;
    end;
    if m_normalized_base_entry_cache <> nil then
    begin
        m_normalized_base_entry_cache.Clear;
    end;
    if m_explicit_user_entry_cache <> nil then
    begin
        m_explicit_user_entry_cache.Clear;
    end;
    if m_literal_user_entry_cache <> nil then
    begin
        m_literal_user_entry_cache.Clear;
    end;
    if m_admin_place_longer_prefix_cache <> nil then
    begin
        m_admin_place_longer_prefix_cache.Clear;
    end;
    if m_admin_place_query_syllable_count_cache <> nil then
    begin
        m_admin_place_query_syllable_count_cache.Clear;
    end;
end;

procedure TncSqliteDictionary.note_user_data_changed;
var
    current_version: Integer;
begin
    m_process_user_data_generation := InterlockedIncrement(
        g_user_data_generation);
    clear_user_read_caches;
    if read_user_data_version(current_version) then
    begin
        m_user_data_version := current_version;
        m_last_user_data_version_check_tick := GetTickCount64;
    end;
end;

function TncSqliteDictionary.read_user_data_version(out version: Integer): Boolean;
const
    query_sql = 'PRAGMA data_version';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    version := 0;
    Result := False;
    if (m_user_connection = nil) or (not m_user_ready) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(query_sql, stmt) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt);
        if step_result <> SQLITE_ROW then
        begin
            Exit;
        end;

        version := m_user_connection.column_int(stmt, 0);
        Result := True;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.refresh_user_data_version_if_changed(const force: Boolean);
const
    c_user_data_version_check_interval_ms = 200;
var
    now_tick: UInt64;
    current_version: Integer;
    process_generation: Integer;
begin
    if (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    process_generation := InterlockedCompareExchange(
        g_user_data_generation, 0, 0);
    if process_generation <> m_process_user_data_generation then
    begin
        m_process_user_data_generation := process_generation;
        m_literal_user_words_available := -1;
        clear_user_read_caches;
    end;

    now_tick := GetTickCount64;
    if (not force) and (m_last_user_data_version_check_tick <> 0) and
        (now_tick - m_last_user_data_version_check_tick < c_user_data_version_check_interval_ms) then
    begin
        Exit;
    end;
    m_last_user_data_version_check_tick := now_tick;

    if not read_user_data_version(current_version) then
    begin
        Exit;
    end;

    if m_user_data_version = 0 then
    begin
        m_user_data_version := current_version;
        Exit;
    end;

    if current_version <> m_user_data_version then
    begin
        m_user_data_version := current_version;
        m_literal_user_words_available := -1;
        clear_user_read_caches;
    end;
end;

procedure TncSqliteDictionary.prewarm_short_lookup_caches;
const
    single_char_sql =
        'SELECT pinyin, text, MAX(weight) FROM dict_base ' +
        'WHERE length(text) = 1 GROUP BY pinyin, text';
    followup_sql =
        'SELECT COALESCE(SUM(weight), 0) FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 AND pinyin <> ?1';
    prefix_sql =
        'SELECT COALESCE(SUM(b.weight), 0) FROM dict_base AS b ' +
        'WHERE b.text >= ?1 AND b.text < ?2 AND ' + c_base_text_evidence_scope_sql;
    exact_weight_sql =
        'SELECT COALESCE(MAX(weight), 0) FROM dict_base ' +
        'WHERE pinyin = ?1 AND text = ?2 AND length(text) = 1';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    cache_key: string;
    weight_value: Integer;
begin
    if m_short_lookup_cache_prewarmed then
    begin
        Exit;
    end;
    if (not ensure_open) or (not m_base_ready) then
    begin
        Exit;
    end;

    if m_stmt_prefix_popularity = nil then
    begin
        m_base_connection.prepare(prefix_sql, m_stmt_prefix_popularity);
    end;
    if m_stmt_pinyin_followup_popularity = nil then
    begin
        m_base_connection.prepare(followup_sql, m_stmt_pinyin_followup_popularity);
    end;
    if m_stmt_single_char_exact_weight = nil then
    begin
        m_base_connection.prepare(exact_weight_sql, m_stmt_single_char_exact_weight);
    end;

    stmt := nil;
    try
        if not m_base_connection.prepare(single_char_sql, stmt) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := normalize_compact_pinyin_key(m_base_connection.column_text(stmt, 0));
            text_value := Trim(m_base_connection.column_text(stmt, 1));
            weight_value := m_base_connection.column_int(stmt, 2);
            if weight_value < 0 then
            begin
                weight_value := 0;
            end;

            if (pinyin_value <> '') and (Length(text_value) = 1) and
                (m_single_char_weight_cache <> nil) then
            begin
                cache_key := pinyin_value + #9 + text_value;
                m_single_char_weight_cache.AddOrSetValue(cache_key, weight_value);
            end;
            step_result := m_base_connection.step(stmt);
        end;
        m_short_lookup_cache_prewarmed := True;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.lookup_exact_full_pinyin(const pinyin: string;
    out results: TncCandidateList): Boolean;
begin
    { Internal path scoring historically treats apostrophes as optional
      separators. Keep that stable; lookup() selects the strict user-input
      path when the composition contains an explicit separator. }
    Result := lookup_exact_full_pinyin_internal(pinyin, results, False);
end;

function TncSqliteDictionary.lookup_isolated_exact_component(
    const pinyin: string; out results: TncCandidateList): Boolean;
begin
    Result := lookup_isolated_exact_component_internal(pinyin, results,
        False);
end;

function TncSqliteDictionary.lookup_isolated_exact_component_internal(
    const pinyin: string; out results: TncCandidateList;
    const use_base_preflight: Boolean): Boolean;
const
    c_component_cache_limit = 8192;
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC';
    base_alias_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_base_pinyin_alias a INNER JOIN dict_base b ON b.id = a.word_id ' +
        'WHERE a.compact_pinyin = ?1 ' +
        'ORDER BY b.weight DESC, b.text ASC';
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC';
var
    cache_key: string;
    evicted_cache_key: string;
    stmt: Psqlite3_stmt;
    step_result: Integer;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Integer>;
    item: TncCandidate;
    existing: TncCandidate;
    text_value: string;
    comment_value: string;
    score_value: Integer;
    existing_idx: Integer;
    idx: Integer;
    base_candidates_before: Integer;
    base_may_exist: Boolean;

    procedure add_or_merge_local(const candidate_text: string;
        const candidate_comment: string; const candidate_weight: Integer;
        const candidate_source: TncCandidateSource);
    begin
        text_value := Trim(candidate_text);
        if text_value = '' then
        begin
            Exit;
        end;
        if seen.TryGetValue(text_value, existing_idx) then
        begin
            existing := list[existing_idx];
            if candidate_weight > existing.score then
            begin
                existing.score := candidate_weight;
            end;
            if candidate_weight > existing.dict_weight then
            begin
                existing.dict_weight := candidate_weight;
            end;
            if (candidate_source = cs_user) or
                (existing.source = cs_user) then
            begin
                existing.source := cs_user;
            end;
            list[existing_idx] := existing;
            Exit;
        end;

        item := Default(TncCandidate);
        item.text := text_value;
        item.comment := Trim(candidate_comment);
        item.score := candidate_weight;
        item.source := candidate_source;
        item.has_dict_weight := True;
        item.dict_weight := candidate_weight;
        seen.Add(text_value, list.Count);
        list.Add(item);
    end;

    procedure sort_local;
    begin
        nc_sort_exact_components(list);
    end;
begin
    SetLength(results, 0);
    Result := False;
    cache_key := normalize_compact_pinyin_key(Trim(pinyin));
    if cache_key = '' then
    begin
        Exit;
    end;
    if not ensure_open then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);
    if (m_exact_component_lookup_cache <> nil) and
        m_exact_component_lookup_cache.TryGetValue(cache_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        Exit(Length(results) > 0);
    end;

    if not is_full_pinyin_key(cache_key) then
    begin
        Exit;
    end;

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Integer>.Create;
    try
        if m_user_ready then
        begin
            if m_stmt_exact_component_user = nil then
            begin
                m_user_connection.prepare(user_sql,
                    m_stmt_exact_component_user);
            end;
            stmt := m_stmt_exact_component_user;
            if (stmt <> nil) and m_user_connection.reset(stmt) and
                m_user_connection.clear_bindings(stmt) and
                m_user_connection.bind_text(stmt, 1, cache_key) then
            begin
                repeat
                    step_result := m_user_connection.step(stmt);
                    if step_result = SQLITE_ROW then
                    begin
                        text_value := user_text_for_script(cache_key,
                            Trim(m_user_connection.column_text(stmt, 0)));
                        score_value := m_user_connection.column_int(stmt, 1);
                        add_or_merge_local(text_value, '', score_value,
                            cs_user);
                    end;
                until step_result <> SQLITE_ROW;
            end;
        end;

        base_may_exist := m_base_ready and
            ((not use_base_preflight) or
            base_exact_pinyin_may_exist(cache_key));
        if base_may_exist then
        begin
            base_candidates_before := list.Count;
            if m_stmt_exact_component_base = nil then
            begin
                m_base_connection.prepare(base_sql,
                    m_stmt_exact_component_base);
            end;
            stmt := m_stmt_exact_component_base;
            if (stmt <> nil) and m_base_connection.reset(stmt) and
                m_base_connection.clear_bindings(stmt) and
                m_base_connection.bind_text(stmt, 1, cache_key) then
            begin
                repeat
                    step_result := m_base_connection.step(stmt);
                    if step_result = SQLITE_ROW then
                    begin
                        text_value := Trim(m_base_connection.column_text(stmt, 1));
                        comment_value := Trim(m_base_connection.column_text(stmt, 2));
                        score_value := m_base_connection.column_int(stmt, 3);
                        add_or_merge_local(text_value, comment_value,
                            score_value, cs_rule);
                    end;
                until step_result <> SQLITE_ROW;
            end;

            if list.Count = base_candidates_before then
            begin
                if m_stmt_exact_component_base_alias = nil then
                begin
                    m_base_connection.prepare(base_alias_sql,
                        m_stmt_exact_component_base_alias);
                end;
                stmt := m_stmt_exact_component_base_alias;
                if (stmt <> nil) and m_base_connection.reset(stmt) and
                    m_base_connection.clear_bindings(stmt) and
                    m_base_connection.bind_text(stmt, 1, cache_key) then
                begin
                    repeat
                        step_result := m_base_connection.step(stmt);
                        if step_result = SQLITE_ROW then
                        begin
                            text_value := Trim(
                                m_base_connection.column_text(stmt, 1));
                            comment_value := Trim(
                                m_base_connection.column_text(stmt, 2));
                            score_value := m_base_connection.column_int(stmt, 3);
                            add_or_merge_local(text_value, comment_value,
                                score_value, cs_rule);
                        end;
                    until step_result <> SQLITE_ROW;
                end;
            end;
        end;

        sort_local;
        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            results[idx] := list[idx];
        end;
        Result := Length(results) > 0;
    finally
        seen.Free;
        list.Free;
    end;
    if m_exact_component_lookup_cache <> nil then
    begin
        while m_exact_component_lookup_cache.Count >= c_component_cache_limit do
        begin
            if (m_exact_component_lookup_cache_order = nil) or
                (m_exact_component_lookup_cache_order.Count = 0) then
            begin
                m_exact_component_lookup_cache.Clear;
                Break;
            end;
            evicted_cache_key := m_exact_component_lookup_cache_order.Dequeue;
            m_exact_component_lookup_cache.Remove(evicted_cache_key);
        end;
        m_exact_component_lookup_cache.AddOrSetValue(cache_key,
            Copy(results, 0, Length(results)));
        if m_exact_component_lookup_cache_order <> nil then
        begin
            m_exact_component_lookup_cache_order.Enqueue(cache_key);
        end;
    end;
end;

function TncSqliteDictionary.lookup_exact_full_pinyin_internal(const pinyin: string;
    out results: TncCandidateList;
    const preserve_explicit_boundaries: Boolean): Boolean;
const
    c_result_cache_limit = 16384;
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC';
    base_alias_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_base_pinyin_alias a INNER JOIN dict_base b ON b.id = a.word_id ' +
        'WHERE a.compact_pinyin = ?1 ' +
        'ORDER BY b.weight DESC, b.text ASC';
    base_longer_prefix_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base ' +
        'WHERE pinyin >= ?1 AND pinyin < ?2 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?3';
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC';
    c_exact_latest_choice_bonus = 1800;
    c_low_frequency_base_choice_bonus_weight_max = 220;
var
    stmt: Psqlite3_stmt;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Integer>;
    step_result: Integer;
    item: TncCandidate;
    query_key: string;
    canonical_query_key: string;
    cache_query_key: string;
    evicted_cache_key: string;
    idx: Integer;
    key: string;
    text_value: string;
    comment_value: string;
    pinyin_value: string;
    score_value: Integer;
    raw_full_pinyin_query: Boolean;
    full_pinyin_query: Boolean;
    exact_query_key: string;
    expanded_erhua_query_key: string;
    query_syllables: TArray<string>;
    query_syllable_count: Integer;
    base_candidates_before: Integer;
    latest_query_choice_text: string;

    function is_administrative_place_suffix_local(const suffix_text: string): Boolean;
    begin
        Result := SameText(suffix_text, string(Char($533A))) or       // 区
            SameText(suffix_text, string(Char($5340))) or             // 區
            SameText(suffix_text, string(Char($53BF))) or             // 县
            SameText(suffix_text, string(Char($7E23))) or             // 縣
            SameText(suffix_text, string(Char($5E02))) or             // 市
            SameText(suffix_text, string(Char($9547))) or             // 镇
            SameText(suffix_text, string(Char($93AE))) or             // 鎮
            SameText(suffix_text, string(Char($4E61))) or             // 乡
            SameText(suffix_text, string(Char($9109))) or             // 鄉
            SameText(suffix_text, string(Char($6751))) or             // 村
            SameText(suffix_text, string(Char($5DDE))) or             // 州
            SameText(suffix_text, string(Char($7701))) or             // 省
            SameText(suffix_text, string(Char($65D7))) or             // 旗
            SameText(suffix_text, string(Char($65B0)) + string(Char($533A))) or // 新区
            SameText(suffix_text, string(Char($65B0)) + string(Char($5340))) or // 新區
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($533A))) or                                  // 自治区
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($5340))) or                                  // 自治區
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($5DDE))) or                                  // 自治州
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($53BF))) or                                  // 自治县
            SameText(suffix_text, string(Char($81EA)) + string(Char($6CBB)) +
            string(Char($7E23)));                                    // 自治縣
    end;

    function suffix_after_prefix_units_local(const text_value: string;
        const prefix_units: Integer): string;
    var
        prefix_text: string;
    begin
        prefix_text := copy_first_text_units(text_value, prefix_units);
        if (prefix_text = '') or (Length(prefix_text) >= Length(text_value)) then
        begin
            Exit('');
        end;
        Result := Copy(text_value, Length(prefix_text) + 1, MaxInt);
    end;

    procedure add_or_merge_candidate(const candidate_text: string; const candidate_comment: string;
        const candidate_score: Integer; const candidate_source: TncCandidateSource);
    var
        local_idx: Integer;
        local_item: TncCandidate;
        effective_score: Integer;
        choice_bonus: Integer;
        low_evidence_admin_alias: Boolean;
    begin
        key := Trim(candidate_text);
        if key = '' then
        begin
            Exit;
        end;
        effective_score := candidate_score;
        if (candidate_comment = '') and full_pinyin_query and
            (not ((candidate_source = cs_rule) and
            (candidate_score <= c_low_frequency_base_choice_bonus_weight_max))) then
        begin
            low_evidence_admin_alias := False;
            choice_bonus := get_query_choice_bonus(query_key, key);
            if (choice_bonus >= c_recent_explicit_user_choice_bonus_min) or
                ((latest_query_choice_text <> '') and SameText(latest_query_choice_text, key)) then
            begin
                low_evidence_admin_alias :=
                    is_low_evidence_admin_place_alias_user_entry(query_key, key, '', 0, 0);
            end;
            if (not low_evidence_admin_alias) and
                (choice_bonus >= c_recent_explicit_user_choice_bonus_min) then
            begin
                Inc(effective_score, c_recent_explicit_user_choice_bonus);
            end;
            if (not low_evidence_admin_alias) and
                (latest_query_choice_text <> '') and SameText(latest_query_choice_text, key) then
            begin
                Inc(effective_score, c_exact_latest_choice_bonus);
            end;
        end;

        if seen.TryGetValue(key, local_idx) then
        begin
            local_item := list[local_idx];
            if candidate_comment <> '' then
            begin
                local_item.comment := candidate_comment;
            end;
            if effective_score > local_item.score then
            begin
                local_item.score := effective_score;
            end;
            if (candidate_source = cs_user) or (local_item.source = cs_user) then
            begin
                local_item.source := cs_user;
            end;
            if candidate_score > local_item.dict_weight then
            begin
                local_item.dict_weight := candidate_score;
            end;
            local_item.has_dict_weight := True;
            list[local_idx] := local_item;
            Exit;
        end;

        item := Default(TncCandidate);
        item.text := key;
        item.comment := candidate_comment;
        item.score := effective_score;
        item.source := candidate_source;
        item.has_dict_weight := True;
        item.dict_weight := candidate_score;
        item.fuzzy_cost := 0;
        item.fuzzy_rules := [];
        seen.Add(key, list.Count);
        list.Add(item);
    end;

    function compare_candidate(const left: TncCandidate; const right: TncCandidate): Integer;
    begin
        if left.score <> right.score then
        begin
            Exit(right.score - left.score);
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
        if left.dict_weight <> right.dict_weight then
        begin
            Exit(right.dict_weight - left.dict_weight);
        end;
        Result := CompareText(left.text, right.text);
    end;

    procedure sort_results;
    begin
        if Length(results) <= 1 then
        begin
            Exit;
        end;

        TArray.Sort<TncCandidate>(results,
            TComparer<TncCandidate>.Construct(
            function(const left, right: TncCandidate): Integer
            begin
                if left.score <> right.score then
                begin
                    Exit(right.score - left.score);
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
                if left.dict_weight <> right.dict_weight then
                begin
                    Exit(right.dict_weight - left.dict_weight);
                end;
                Result := CompareText(left.text, right.text);
            end));
    end;

    procedure add_administrative_place_prefix_candidates;
    var
        prefix_stmt: Psqlite3_stmt;
        prefix_step_result: Integer;
        prefix_candidate_pinyin: string;
        prefix_candidate_text: string;
        prefix_candidate_comment: string;
        prefix_candidate_weight: Integer;
        prefix_text: string;
        suffix_text: string;
        pinyin_syllables: TArray<string>;
        prefix_limit: Integer;
        prefix_score: Integer;

        function get_admin_place_prefix_score(const parent_weight: Integer): Integer;
        begin
            Result := (parent_weight * 45) div 100;
            if Result > 320 then
            begin
                Result := 320;
            end;
            if query_syllable_count <= 2 then
            begin
                Result := Min(Result, 180);
                if Result < 160 then
                begin
                    Result := 160;
                end;
            end;
            if Result < 1 then
            begin
                Result := 1;
            end;
        end;

        function admin_place_prefix_may_exist_local: Boolean;
        const
            c_admin_suffix_pinyin: array[0..12] of string = (
                'qu', 'xian', 'shi', 'zhen', 'xiang', 'cun', 'zhou',
                'sheng', 'qi', 'xinqu', 'zizhiqu', 'zizhizhou',
                'zizhixian');
        var
            compact_prefix_local: string;
            suffix_idx_local: Integer;
        begin
            compact_prefix_local := normalize_compact_pinyin_key(
                exact_query_key);
            if compact_prefix_local = '' then
            begin
                Exit(False);
            end;

            for suffix_idx_local := Low(c_admin_suffix_pinyin) to
                High(c_admin_suffix_pinyin) do
            begin
                if base_exact_pinyin_may_exist(compact_prefix_local +
                    c_admin_suffix_pinyin[suffix_idx_local]) then
                begin
                    Exit(True);
                end;
            end;
            Result := False;
        end;
    begin
        if (not full_pinyin_query) or (query_syllable_count < 2) or
            (not m_base_ready) or
            (not admin_place_prefix_may_exist_local) then
        begin
            Exit;
        end;

        prefix_limit := 32;
        if m_stmt_exact_admin_prefix = nil then
        begin
            if not m_base_connection.prepare(base_longer_prefix_sql,
                m_stmt_exact_admin_prefix) then
            begin
                Exit;
            end;
        end;
        prefix_stmt := m_stmt_exact_admin_prefix;
        if (prefix_stmt = nil) or
            (not m_base_connection.reset(prefix_stmt)) or
            (not m_base_connection.clear_bindings(prefix_stmt)) or
            (not m_base_connection.bind_text(prefix_stmt, 1, exact_query_key)) or
                (not m_base_connection.bind_text(prefix_stmt, 2,
                build_prefix_upper_bound(exact_query_key))) or
                (not m_base_connection.bind_int(prefix_stmt, 3, prefix_limit)) then
        begin
            Exit;
        end;

        prefix_step_result := m_base_connection.step(prefix_stmt);
        while prefix_step_result = SQLITE_ROW do
        begin
            prefix_candidate_pinyin := Trim(m_base_connection.column_text(prefix_stmt, 0));
            prefix_candidate_text := Trim(m_base_connection.column_text(prefix_stmt, 1));
            prefix_candidate_comment := Trim(m_base_connection.column_text(prefix_stmt, 2));
            prefix_candidate_weight := m_base_connection.column_int(prefix_stmt, 3);

            if (prefix_candidate_comment <> '') or
                (Copy(prefix_candidate_pinyin, 1, Length(exact_query_key)) <>
                exact_query_key) then
            begin
                prefix_step_result := m_base_connection.step(prefix_stmt);
                Continue;
            end;

            pinyin_syllables := split_full_pinyin_syllables(prefix_candidate_pinyin);
            if Length(pinyin_syllables) <= query_syllable_count then
            begin
                prefix_step_result := m_base_connection.step(prefix_stmt);
                Continue;
            end;
            if get_text_unit_count_local(prefix_candidate_text) <= query_syllable_count then
            begin
                prefix_step_result := m_base_connection.step(prefix_stmt);
                Continue;
            end;

            prefix_text := copy_first_text_units(prefix_candidate_text,
                query_syllable_count);
            suffix_text := suffix_after_prefix_units_local(prefix_candidate_text,
                query_syllable_count);
            if (prefix_text = '') or (suffix_text = '') or
                (not is_administrative_place_suffix_local(suffix_text)) then
            begin
                prefix_step_result := m_base_connection.step(prefix_stmt);
                Continue;
            end;

            prefix_score := get_admin_place_prefix_score(prefix_candidate_weight);
            add_or_merge_candidate(prefix_text, '', prefix_score, cs_rule);
            prefix_step_result := m_base_connection.step(prefix_stmt);
        end;
    end;

    procedure apply_short_exact_commonness_tiebreak;
    const
        c_min_syllables = 2;
        c_max_syllables = 3;
        c_close_weight_gap = 96;
        c_close_weight_ratio_pct = 90;
        c_commonness_factor = 8;
        c_commonness_bonus_cap = 960;
    var
        exact_indexes: TList<Integer>;
        local_idx, list_index: Integer;
        local_item: TncCandidate;
        best_weight: Integer;
        commonness_bonus: Integer;
        score_bonus: Integer;
    begin
        if (query_syllable_count < c_min_syllables) or
            (query_syllable_count > c_max_syllables) or (list.Count <= 1) then
        begin
            Exit;
        end;

        exact_indexes := TList<Integer>.Create;
        try
            best_weight := Low(Integer);
            for local_idx := 0 to list.Count - 1 do
            begin
                local_item := list[local_idx];
                if (local_item.source <> cs_rule) or (local_item.comment <> '') or
                    (not local_item.has_dict_weight) or (local_item.dict_weight <= 0) then
                begin
                    Continue;
                end;
                if get_text_unit_count_local(local_item.text) <> query_syllable_count then
                begin
                    Continue;
                end;

                exact_indexes.Add(local_idx);
                if local_item.dict_weight > best_weight then
                begin
                    best_weight := local_item.dict_weight;
                end;
            end;

            if exact_indexes.Count <= 1 then
            begin
                Exit;
            end;

            for list_index in exact_indexes do
            begin
                local_item := list[list_index];
                if (best_weight - local_item.dict_weight > c_close_weight_gap) and
                    (local_item.dict_weight * 100 < best_weight * c_close_weight_ratio_pct) then
                begin
                    Continue;
                end;

                commonness_bonus := get_base_text_prefix_bonus(local_item.text);
                if commonness_bonus <= 0 then
                begin
                    Continue;
                end;

                score_bonus := commonness_bonus * c_commonness_factor;
                if score_bonus > c_commonness_bonus_cap then
                begin
                    score_bonus := c_commonness_bonus_cap;
                end;

                Inc(local_item.score, score_bonus);
                list[list_index] := local_item;
            end;
        finally
            exact_indexes.Free;
        end;
    end;
begin
    SetLength(results, 0);
    Result := False;
    if preserve_explicit_boundaries then
    begin
        canonical_query_key := normalize_canonical_pinyin_key(Trim(pinyin));
        cache_query_key := #1 + canonical_query_key;
    end
    else
    begin
        canonical_query_key := normalize_compact_pinyin_key(Trim(pinyin));
        cache_query_key := canonical_query_key;
    end;
    query_key := normalize_compact_pinyin_key(canonical_query_key);
    if query_key = '' then
    begin
        Exit;
    end;
    if not ensure_open then
    begin
        Exit;
    end;
    // ensure_open already performs the throttled cross-process version check.
    // Forcing another PRAGMA data_version here made every exact probe hit the
    // user database, even when the candidate result itself was cached.
    refresh_user_data_version_if_changed(False);
    if (m_exact_lookup_result_cache <> nil) and
        m_exact_lookup_result_cache.TryGetValue(cache_query_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        if m_debug_mode then
        begin
            m_last_lookup_debug_hint := Format('dict=[exact_cache=1 n=%d]',
                [Length(results)]);
        end;
        Exit(Length(results) > 0);
    end;
    raw_full_pinyin_query := is_full_pinyin_key(canonical_query_key);
    expanded_erhua_query_key := '';
    if (Length(query_key) > 2) and
        (query_key[Length(query_key)] = 'r') and
        (Copy(query_key, Length(query_key) - 1, 2) <> 'er') then
    begin
        expanded_erhua_query_key := Copy(query_key, 1, Length(query_key) - 1) + #39 + 'er';
        if not is_full_pinyin_key(expanded_erhua_query_key) then
        begin
            expanded_erhua_query_key := '';
        end;
    end;
    exact_query_key := canonical_query_key;
    if expanded_erhua_query_key <> '' then
    begin
        exact_query_key := expanded_erhua_query_key;
    end;
    full_pinyin_query := raw_full_pinyin_query or (expanded_erhua_query_key <> '');
    latest_query_choice_text := '';
    if full_pinyin_query then
    begin
        query_syllables := split_full_pinyin_syllables(exact_query_key);
        query_syllable_count := Length(query_syllables);
        latest_query_choice_text := get_query_latest_choice_text(query_key);
    end
    else
    begin
        SetLength(query_syllables, 0);
        query_syllable_count := 0;
    end;

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Integer>.Create;
    try
        if m_user_ready and full_pinyin_query then
        begin
            if m_stmt_exact_user = nil then
            begin
                m_user_connection.prepare(user_sql, m_stmt_exact_user);
            end;
            stmt := m_stmt_exact_user;
            if (stmt <> nil) and
                m_user_connection.reset(stmt) and
                m_user_connection.clear_bindings(stmt) and
                m_user_connection.bind_text(stmt, 1, query_key) then
            begin
                repeat
                    step_result := m_user_connection.step(stmt);
                    if step_result = SQLITE_ROW then
                    begin
                        text_value := user_text_for_script(query_key,
                            Trim(m_user_connection.column_text(stmt, 0)));
                        score_value := m_user_connection.column_int(stmt, 1);
                        if not strict_full_pinyin_text_alignment_valid(exact_query_key,
                            text_value) then
                        begin
                            Continue;
                        end;
                        if should_suppress_constructed_user_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Continue;
                        end;
                        if normalized_base_entry_exists(query_key, text_value) then
                        begin
                            Continue;
                        end;
                        if is_low_evidence_admin_place_alias_user_entry(query_key,
                            text_value, '', 0, 0) then
                        begin
                            Continue;
                        end;
                        add_or_merge_candidate(text_value, '', score_value, cs_user);
                    end;
                until step_result <> SQLITE_ROW;
            end;
        end;
        if m_base_ready then
        begin
            base_candidates_before := list.Count;
            if full_pinyin_query and
                base_exact_pinyin_may_exist(exact_query_key) and
                (m_stmt_exact_base = nil) then
            begin
                m_base_connection.prepare(base_sql, m_stmt_exact_base);
            end;
            stmt := m_stmt_exact_base;
            if full_pinyin_query and
                base_exact_pinyin_may_exist(exact_query_key) and
                (stmt <> nil) and
                m_base_connection.reset(stmt) and
                m_base_connection.clear_bindings(stmt) and
                m_base_connection.bind_text(stmt, 1, exact_query_key) then
            begin
                repeat
                    step_result := m_base_connection.step(stmt);
                    if step_result = SQLITE_ROW then
                    begin
                        pinyin_value := Trim(m_base_connection.column_text(stmt, 0));
                        text_value := Trim(m_base_connection.column_text(stmt, 1));
                        comment_value := Trim(m_base_connection.column_text(stmt, 2));
                        score_value := m_base_connection.column_int(stmt, 3);
                        if not strict_full_pinyin_text_alignment_valid(pinyin_value,
                            text_value) then
                        begin
                            Continue;
                        end;
                        add_or_merge_candidate(text_value, comment_value, score_value, cs_rule);
                    end;
                until step_result <> SQLITE_ROW;
            end;
            if (list.Count = base_candidates_before) and
                base_exact_pinyin_may_exist(query_key) then
            begin
                if m_stmt_exact_base_alias = nil then
                begin
                    m_base_connection.prepare(base_alias_sql,
                        m_stmt_exact_base_alias);
                end;
                stmt := m_stmt_exact_base_alias;
                if (stmt <> nil) and
                    m_base_connection.reset(stmt) and
                    m_base_connection.clear_bindings(stmt) and
                    m_base_connection.bind_text(stmt, 1, query_key) then
                begin
                    repeat
                        step_result := m_base_connection.step(stmt);
                        if step_result = SQLITE_ROW then
                        begin
                            pinyin_value := Trim(m_base_connection.column_text(stmt, 0));
                            text_value := Trim(m_base_connection.column_text(stmt, 1));
                            comment_value := Trim(m_base_connection.column_text(stmt, 2));
                            score_value := m_base_connection.column_int(stmt, 3);
                            if not strict_full_pinyin_text_alignment_valid(pinyin_value,
                                text_value) then
                            begin
                                Continue;
                            end;
                            if full_pinyin_query and
                                (not strict_full_pinyin_text_alignment_valid(
                                exact_query_key, text_value)) then
                            begin
                                Continue;
                            end;
                            add_or_merge_candidate(text_value, comment_value,
                                score_value, cs_rule);
                        end;
                    until step_result <> SQLITE_ROW;
                end;
            end;
            add_administrative_place_prefix_candidates;
        end;

        apply_short_exact_commonness_tiebreak;
        SetLength(results, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            results[idx] := list[idx];
        end;
        sort_results;
        Result := Length(results) > 0;
    finally
        seen.Free;
        list.Free;
    end;
    if (not Result) and (not raw_full_pinyin_query) then
    begin
        Result := lookup(query_key, results);
    end;
    if m_exact_lookup_result_cache <> nil then
    begin
        while m_exact_lookup_result_cache.Count >= c_result_cache_limit do
        begin
            if (m_exact_lookup_result_cache_order = nil) or
                (m_exact_lookup_result_cache_order.Count = 0) then
            begin
                m_exact_lookup_result_cache.Clear;
                Break;
            end;
            evicted_cache_key := m_exact_lookup_result_cache_order.Dequeue;
            m_exact_lookup_result_cache.Remove(evicted_cache_key);
        end;
        m_exact_lookup_result_cache.AddOrSetValue(cache_query_key,
            Copy(results, 0, Length(results)));
        if m_exact_lookup_result_cache_order <> nil then
        begin
            m_exact_lookup_result_cache_order.Enqueue(cache_query_key);
        end;
    end;
end;

function TncSqliteDictionary.lookup(const pinyin: string; out results: TncCandidateList): Boolean;
const
    c_result_cache_limit = 8192;
    base_sql = 'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_exact_entry_normalized_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base ' +
        'WHERE text = ?2 AND (pinyin = ?1 OR replace(pinyin, ?3, ?4) = ?1) ' +
        'ORDER BY weight DESC LIMIT 64';
    base_typo_prefix_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin LIKE ?1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_single_char_exact_sql =
        'SELECT pinyin, text, comment, weight FROM dict_base WHERE pinyin = ?1 AND length(text) = 1 ' +
        'ORDER BY weight DESC, text ASC LIMIT ?2';
    base_jianpin_sql =
        'SELECT b.pinyin, b.text, b.comment, j.weight ' +
        'FROM (SELECT word_id, weight FROM dict_jianpin WHERE jianpin = ?1 ' +
        'ORDER BY weight DESC LIMIT ?2) j ' +
        'INNER JOIN dict_base b ON b.id = j.word_id ' +
        'ORDER BY j.weight DESC, b.weight DESC, b.text ASC LIMIT ?3';
    base_jianpin_prefixed_sql =
        'SELECT b.pinyin, b.text, b.comment, j.weight ' +
        'FROM (SELECT word_id, weight FROM dict_jianpin WHERE jianpin = ?1 ' +
        'ORDER BY weight DESC LIMIT ?2) j ' +
        'INNER JOIN dict_base b ON b.id = j.word_id ' +
        'WHERE b.pinyin LIKE ?3 ' +
        'ORDER BY j.weight DESC, b.weight DESC, b.text ASC LIMIT ?4';
    base_mixed_pattern_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_base b WHERE b.pinyin LIKE ?1 ' +
        'ORDER BY b.weight DESC, b.text ASC LIMIT ?2';
    base_initial_single_char_sql =
        'SELECT b.pinyin, b.text, b.comment, b.weight ' +
        'FROM dict_base b WHERE b.pinyin LIKE ?1 AND length(b.text) = 1 ' +
        'ORDER BY b.weight DESC, b.text ASC LIMIT ?2';
    user_sql = 'SELECT text, weight, last_used FROM dict_user WHERE pinyin = ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
    user_nonfull_sql = 'SELECT pinyin, text, weight, last_used FROM dict_user WHERE pinyin LIKE ?1 ' +
        'ORDER BY weight DESC, last_used DESC, text ASC LIMIT ?2';
    stats_normalized_sql =
        'SELECT pinyin, text, commit_count, last_used FROM dict_user_stats ' +
        'WHERE pinyin = ?1 OR replace(pinyin, ?2, ?3) = ?1';
    text_stats_sql =
        'SELECT COALESCE(SUM(commit_count), 0), COALESCE(MAX(last_used), 0) ' +
        'FROM dict_user_stats WHERE text = ?1';
    c_exact_latest_choice_bonus = 1800;
    c_low_frequency_base_choice_bonus_weight_max = 220;
    c_jianpin_score_penalty = 30;
    c_nonfull_exact_penalty = 100;
    c_initial_single_char_penalty = 120;
    c_single_letter_full_query_extra_penalty = 120;
    c_single_letter_full_query_cap_margin = 8;
    c_typo_transpose_penalty = 80;
    // For malformed non-full keys (e.g. "chagn"), adjacent-swap fallback
    // should stay conservative because earlier normalization already handles
    // the highest-value short typos.
    c_typo_min_query_len_nonfull = 6;
    // Full pinyin adjacent-swap probing is only worth trying on longer inputs;
    // keep short exact full keys strict to avoid polluting common lookups.
    c_typo_min_query_len_full = 7;
    c_typo_prefix_min_query_len_nonfull = 7;
    c_typo_prefix_min_query_len_full = 8;
    c_typo_probe_limit = 18;
    c_typo_max_added = 12;
    c_typo_prefix_probe_limit = 6;
    c_typo_prefix_extra_penalty = 120;
    c_full_query_dual_jianpin_len_min = 2;
    c_full_query_dual_jianpin_len_max = 4;
    c_full_query_dual_jianpin_penalty = 20;
    // Runtime homophone bonus currently relies on expensive full-table scans
    // (text contains/prefix aggregate), which can add noticeable input latency
    // on common keys like "shi"/"de". Keep this disabled by default.
    c_enable_runtime_homophone_bonus = False;
var
    stmt: Psqlite3_stmt;
    list: TList<TncCandidate>;
    seen: TDictionary<string, Boolean>;
    candidate_pinyin_map: TDictionary<string, string>;
    candidate_score_cap_map: TDictionary<string, Integer>;
    learning_bonus_map: TDictionary<string, Integer>;
    text_learning_bonus_cache: TDictionary<string, Integer>;
    step_result: Integer;
    item: TncCandidate;
    text_value: string;
    comment_value: string;
    score_value: Integer;
    dict_weight_value: Integer;
    score_with_bonus: Integer;
    penalty_value: Integer;
    commit_count: Integer;
    last_used_value: Int64;
    learning_bonus: Integer;
    now_unix: Int64;
    i: Integer;
    key: string;
    query_key: string;
    evicted_cache_key: string;
    candidate_pinyin: string;
    stat_pinyin_value: string;
    candidate_score_cap: Integer;
    mixed_full_prefix: string;
    mixed_jianpin_key: string;
    effective_jianpin_key: string;
    full_query_jianpin_key: string;
    jianpin_query_keys: TArray<string>;
    matching_jianpin_query_keys: TArray<string>;
    mixed_tokens: TncMixedQueryTokenList;
    mixed_mode: Boolean;
    full_pinyin_query: Boolean;
    base_exact_query_key: string;
    expanded_erhua_query_key: string;
    allow_full_query_jianpin_fallback: Boolean;
    full_query_dual_jianpin_mode: Boolean;
    single_letter_query: Boolean;
    mixed_parser: TncPinyinParser;
    mixed_like_pattern: string;
    jianpin_score_penalty: Integer;
    single_letter_cap_score: Integer;
    single_letter_has_cap: Boolean;
    single_syllable_full_query: Boolean;
    full_query_syllable_count: Integer;
    single_char_probe_limit: Integer;
    user_nonfull_lookup: Boolean;
    user_like_pattern: string;
    user_probe_limit: Integer;
    base_jianpin_probe_limit: Integer;
    query_key_idx: Integer;
    exact_base_hit: Boolean;
    typo_fallback_used: Boolean;
    force_noisy_reset_before_typo: Boolean;
    normalized_query_key: string;
    full_query_dual_jianpin_cap_score: Integer;
    full_query_dual_jianpin_has_cap: Boolean;
    disable_long_full_query_jianpin: Boolean;
    applied_learning_bonus_count: Integer;
    applied_text_learning_bonus_count: Integer;
    skipped_single_char_mismatch_count: Integer;
    skipped_noisy_user_count: Integer;
    skipped_base_dup_user_count: Integer;
    injected_learned_base_count: Integer;
    latest_query_choice_text: string;
    canonical_query_key: string;

    function build_mixed_like_pattern(const token_list: TncMixedQueryTokenList): string; forward;
    function is_compact_ascii_query(const value: string): Boolean; forward;
    procedure add_jianpin_query_key(var target_keys: TArray<string>; const key_value: string); forward;
    procedure append_jianpin_query_key_variants(var target_keys: TArray<string>; const key_value: string;
        const allow_short_retroflex_expansion: Boolean); forward;

    function mixed_query_has_internal_dangling_initial(const token_list: TncMixedQueryTokenList): Boolean;
    var
        token_idx: Integer;
    begin
        Result := False;
        if Length(token_list) <= 1 then
        begin
            Exit;
        end;

        // Pattern like "cha + g + n" often means a malformed compact input.
        // Prefer typo recovery over mixed/jianpin expansion in this case.
        for token_idx := 0 to High(token_list) - 1 do
        begin
            if token_list[token_idx].kind = mqt_initial then
            begin
                Result := True;
                Exit;
            end;
        end;
    end;

    function normalize_adjacent_swap_to_full_pinyin(const value: string): string;
    var
        swap_idx: Integer;
        swap_value: string;
        swap_char: Char;
    begin
        Result := '';
        if (Length(value) < c_typo_min_query_len_nonfull) or (not is_compact_ascii_query(value)) then
        begin
            Exit;
        end;

        // Prefer right-most swaps first: tail errors like "...gn" -> "...ng" are common.
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

    procedure add_jianpin_query_key(var target_keys: TArray<string>; const key_value: string);
    var
        idx: Integer;
    begin
        if key_value = '' then
        begin
            Exit;
        end;

        for idx := 0 to High(target_keys) do
        begin
            if SameText(target_keys[idx], key_value) then
            begin
                Exit;
            end;
        end;

        SetLength(target_keys, Length(target_keys) + 1);
        target_keys[High(target_keys)] := key_value;
    end;

    procedure append_jianpin_query_key_variants(var target_keys: TArray<string>; const key_value: string;
        const allow_short_retroflex_expansion: Boolean);
    const
        c_jianpin_variant_full_expand_pair_limit = 1;
        c_jianpin_variant_full_expand_len_max = 5;
        c_jianpin_collapsed_fallback_len_min = 5;
    var
        variants: TArray<string>;
        idx: Integer;
        retroflex_pair_count: Integer;
        collapsed_value: string;
    begin
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(key_value);
        if retroflex_pair_count <= 0 then
        begin
            add_jianpin_query_key(target_keys, key_value);
            Exit;
        end;

        add_jianpin_query_key(target_keys, key_value);
        if Length(key_value) >= c_jianpin_collapsed_fallback_len_min then
        begin
            collapsed_value := collapse_retroflex_pairs_in_compact_key(key_value);
            if collapsed_value <> '' then
            begin
                add_jianpin_query_key(target_keys, collapsed_value);
            end;
        end;

        if (not allow_short_retroflex_expansion) and (Length(key_value) <= 4) then
        begin
            Exit;
        end;

        if (retroflex_pair_count > c_jianpin_variant_full_expand_pair_limit) or
            (Length(key_value) > c_jianpin_variant_full_expand_len_max) then
        begin
            Exit;
        end;

        variants := build_jianpin_query_variants(key_value);
        for idx := 0 to High(variants) do
        begin
            add_jianpin_query_key(target_keys, variants[idx]);
        end;
    end;

    function get_jianpin_probe_limit_for_key(const base_key_value: string; const current_key_value: string): Integer;
    var
        retroflex_pair_count: Integer;
    begin
        Result := base_jianpin_probe_limit;
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(base_key_value);
        if SameText(base_key_value, current_key_value) and is_bare_retroflex_pair_key(base_key_value) then
        begin
            Result := Min(Result, 128);
        end
        else if SameText(base_key_value, current_key_value) and (retroflex_pair_count > 0) and
            (Length(base_key_value) <= 4) then
        begin
            if Length(base_key_value) <= 3 then
            begin
                Result := Min(Result, 96);
            end
            else
            begin
                Result := Min(Result, 128);
            end;
        end
        else if is_retroflex_collapsed_fallback_key(base_key_value, current_key_value) then
        begin
            if is_bare_retroflex_pair_key(base_key_value) then
            begin
                Result := Min(Result, 64);
            end
            else if (retroflex_pair_count > 0) and (Length(base_key_value) <= 4) then
            begin
                if Length(base_key_value) <= 3 then
                begin
                    Result := Min(Result, 32);
                end
                else
                begin
                    Result := Min(Result, 48);
                end;
            end
            else if Length(base_key_value) <= 2 then
            begin
                Result := Min(Result, 192);
            end
            else if Length(base_key_value) = 3 then
            begin
                Result := Min(Result, 160);
            end
            else
            begin
                Result := Min(Result, 128);
            end;
        end;
    end;

    function get_jianpin_inner_probe_limit_for_key(const base_key_value: string;
        const current_key_value: string; const prefixed_query: Boolean): Integer;
    var
        outer_limit: Integer;
        retroflex_pair_count: Integer;
    begin
        outer_limit := get_jianpin_probe_limit_for_key(base_key_value, current_key_value);
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(base_key_value);
        if SameText(base_key_value, current_key_value) and (retroflex_pair_count > 0) and
            (Length(base_key_value) <= 4) then
        begin
            if prefixed_query then
            begin
                Result := Min(Max(outer_limit * 2, 128), 192);
            end
            else
            begin
                Result := Min(Max(outer_limit * 2, 128), 160);
            end;
        end
        else if (retroflex_pair_count > 0) and (Length(base_key_value) <= 4) and
            is_retroflex_collapsed_fallback_key(base_key_value, current_key_value) then
        begin
            if prefixed_query then
            begin
                Result := Min(Max(outer_limit * 2, 64), 96);
            end
            else
            begin
                Result := Min(Max(outer_limit * 2, 64), 96);
            end;
        end
        else if prefixed_query then
        begin
            Result := Max(outer_limit * 4, 256);
        end
        else
        begin
            Result := Max(outer_limit * 3, 192);
        end;
    end;

    function should_skip_deferred_jianpin_variant(const base_key_value: string;
        const current_key_value: string; const current_result_count: Integer): Boolean;
    var
        retroflex_pair_count: Integer;
        min_results_before_fallback: Integer;
    begin
        Result := False;
        retroflex_pair_count := count_retroflex_pairs_in_compact_key(base_key_value);
        if retroflex_pair_count <= 0 then
        begin
            Exit;
        end;
        if not is_retroflex_collapsed_fallback_key(base_key_value, current_key_value) then
        begin
            Exit;
        end;
        if is_bare_retroflex_pair_key(base_key_value) then
        begin
            min_results_before_fallback := 8;
        end
        else if Length(base_key_value) <= 4 then
        begin
            min_results_before_fallback := 6;
        end
        else
        begin
            min_results_before_fallback := 12;
        end;
        Result := current_result_count >= min_results_before_fallback;
    end;

    function has_separator_normalized_base_variant(const normalized_key: string): Boolean; forward;

    procedure rebuild_query_mode_state;
    var
        query_parser: TncPinyinParser;
        query_syllables: TncPinyinParseResult;
    begin
        mixed_full_prefix := '';
        mixed_jianpin_key := query_key;
        SetLength(mixed_tokens, 0);
        mixed_mode := parse_mixed_jianpin_query(query_key, mixed_full_prefix, mixed_jianpin_key, mixed_tokens);
        if mixed_jianpin_key = '' then
        begin
            mixed_jianpin_key := query_key;
        end;

        effective_jianpin_key := mixed_jianpin_key;
        full_pinyin_query := is_full_pinyin_key(query_key);
        base_exact_query_key := query_key;
        expanded_erhua_query_key := '';
        if (Length(query_key) > 2) and
            (query_key[Length(query_key)] = 'r') and
            (Copy(query_key, Length(query_key) - 1, 2) <> 'er') then
        begin
            expanded_erhua_query_key :=
                Copy(query_key, 1, Length(query_key) - 1) + #39 + 'er';
            if is_full_pinyin_key(expanded_erhua_query_key) then
            begin
                base_exact_query_key := expanded_erhua_query_key;
                full_pinyin_query := True;
            end
            else
            begin
                expanded_erhua_query_key := '';
            end;
        end;
        full_query_jianpin_key := '';
        allow_full_query_jianpin_fallback := False;
        full_query_dual_jianpin_mode := False;
        single_syllable_full_query := False;
        full_query_syllable_count := 0;
        disable_long_full_query_jianpin := False;
        full_query_dual_jianpin_cap_score := 0;
        full_query_dual_jianpin_has_cap := False;
        if full_pinyin_query then
        begin
            single_syllable_full_query := is_single_syllable_full_pinyin_key(query_key);
            if single_syllable_full_query then
            begin
                full_query_syllable_count := 1;
            end
            else
            begin
                query_parser := TncPinyinParser.Create;
                try
                    query_syllables := query_parser.parse(base_exact_query_key);
                finally
                    query_parser.Free;
                end;
                full_query_syllable_count := Length(query_syllables);
                if full_query_syllable_count <= 0 then
                begin
                    full_query_syllable_count := 1;
                end;
            end;
            disable_long_full_query_jianpin := (full_query_syllable_count >= 3);
            full_query_jianpin_key := build_jianpin_key_from_full_pinyin(base_exact_query_key);
            if disable_long_full_query_jianpin and
                has_separator_normalized_base_variant(query_key) then
            begin
                disable_long_full_query_jianpin := False;
            end;
            if (not disable_long_full_query_jianpin) and
                (full_query_jianpin_key <> '') and
                (not SameText(full_query_jianpin_key, query_key)) then
            begin
                effective_jianpin_key := full_query_jianpin_key;
                allow_full_query_jianpin_fallback := True;
            end;

            if single_syllable_full_query and
                (Length(query_key) >= c_full_query_dual_jianpin_len_min) and
                (Length(query_key) <= c_full_query_dual_jianpin_len_max) and
                should_try_jianpin_lookup(query_key) then
            begin
                // For ambiguous keys like "en": keep full-pinyin hits, and also
                // surface common jianpin words under the same key.
                full_query_dual_jianpin_mode := True;
                effective_jianpin_key := query_key;
                allow_full_query_jianpin_fallback := True;
            end;
        end;

        SetLength(jianpin_query_keys, 0);
        append_jianpin_query_key_variants(jianpin_query_keys, effective_jianpin_key, False);
        if Length(jianpin_query_keys) = 0 then
        begin
            add_jianpin_query_key(jianpin_query_keys, effective_jianpin_key);
        end;

        SetLength(matching_jianpin_query_keys, 0);
        append_jianpin_query_key_variants(matching_jianpin_query_keys, effective_jianpin_key, True);
        if Length(matching_jianpin_query_keys) = 0 then
        begin
            add_jianpin_query_key(matching_jianpin_query_keys, effective_jianpin_key);
        end;

        jianpin_score_penalty := c_jianpin_score_penalty;
        if not full_pinyin_query then
        begin
            // For non-full inputs (especially jianpin), do not down-rank jianpin hits.
            jianpin_score_penalty := 0;
        end;

        mixed_like_pattern := '';
        if mixed_mode then
        begin
            mixed_like_pattern := build_mixed_like_pattern(mixed_tokens);
        end;

        force_noisy_reset_before_typo := mixed_mode and
            mixed_query_has_internal_dangling_initial(mixed_tokens);

        user_nonfull_lookup := m_user_ready and (not full_pinyin_query) and should_try_jianpin_lookup(query_key);
        user_like_pattern := '';
        if user_nonfull_lookup then
        begin
            if mixed_mode and (mixed_full_prefix <> '') then
            begin
                user_like_pattern := mixed_full_prefix + '%';
            end
            else
            begin
                user_like_pattern := query_key[1] + '%';
            end;
        end;

        base_jianpin_probe_limit := m_limit;
        if (not full_pinyin_query) and should_try_jianpin_lookup(query_key) then
        begin
            if Length(query_key) <= 2 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 6, 1024);
            end
            else if Length(query_key) = 3 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 4, 768);
            end
            else if Length(query_key) = 4 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 3, 512);
            end
            else if Length(query_key) <= 6 then
            begin
                base_jianpin_probe_limit := Max(m_limit * 2, 384);
            end;

            if (count_retroflex_pairs_in_compact_key(effective_jianpin_key) > 0) and
                (Length(effective_jianpin_key) <= 4) then
            begin
                if Length(effective_jianpin_key) <= 3 then
                begin
                    base_jianpin_probe_limit := Min(base_jianpin_probe_limit, 96);
                end
                else
                begin
                    base_jianpin_probe_limit := Min(base_jianpin_probe_limit, 128);
                end;
            end;
        end;
    end;

    function has_separator_normalized_base_variant(const normalized_key: string): Boolean;
    const
        base_separator_variant_sql =
            'SELECT 1 FROM dict_base_pinyin_alias WHERE compact_pinyin = ?1 LIMIT 1';
    var
        local_stmt: Psqlite3_stmt;
    begin
        Result := False;
        if (normalized_key = '') or (not m_base_ready) or (m_base_connection = nil) then
        begin
            Exit;
        end;

        local_stmt := nil;
        try
            if m_base_connection.prepare(base_separator_variant_sql, local_stmt) and
                m_base_connection.bind_text(local_stmt, 1, normalized_key) then
            begin
                Result := m_base_connection.step(local_stmt) = SQLITE_ROW;
            end;
        finally
            if local_stmt <> nil then
            begin
                m_base_connection.finalize(local_stmt);
            end;
        end;
    end;

    procedure append_candidate(const text: string; const comment: string; const score: Integer;
        const source: TncCandidateSource; const has_dict_weight: Boolean = False;
        const dict_weight: Integer = 0; const candidate_pinyin_key: string = '';
        const max_final_score: Integer = MaxInt);
    var
        effective_source: TncCandidateSource;
        effective_has_dict_weight: Boolean;
        effective_dict_weight: Integer;
        choice_bonus: Integer;
        allow_user_stat_bonus: Boolean;
    begin
        if text = '' then
        begin
            Exit;
        end;
        if is_single_syllable_full_pinyin_key(query_key) and
            (candidate_pinyin_key <> '') and
            (Pos('''', normalize_canonical_pinyin_key(candidate_pinyin_key)) > 0) and
            SameText(normalize_compact_pinyin_key(candidate_pinyin_key), query_key) and
            (not SameText(normalize_canonical_pinyin_key(candidate_pinyin_key),
            normalize_canonical_pinyin_key(query_key))) then
        begin
            { A complete single syllable such as luan must not inherit a
              separator-form exact word such as lu'an through compact jianpin
              aliases.  The explicit separator query remains available. }
            Exit;
        end;
        if not is_windows_supported_ime_text(text) then
        begin
            Exit;
        end;
        if (source = cs_user) and (not is_valid_user_text(text)) then
        begin
            Exit;
        end;

        key := text;
        if seen.ContainsKey(key) then
        begin
            Exit;
        end;

        score_with_bonus := score;
        allow_user_stat_bonus := not ((source = cs_rule) and has_dict_weight and
            (dict_weight <= c_low_frequency_base_choice_bonus_weight_max));
        if allow_user_stat_bonus and learning_bonus_map.TryGetValue(text,
            learning_bonus) then
        begin
            Inc(score_with_bonus, learning_bonus);
            Inc(applied_learning_bonus_count);
        end;
        if allow_user_stat_bonus and (comment = '') and (candidate_pinyin_key <> '') and
            same_normalized_pinyin_key(candidate_pinyin_key, query_key) then
        begin
            choice_bonus := get_query_choice_bonus(query_key, text);
            if choice_bonus >= c_recent_explicit_user_choice_bonus_min then
            begin
                Inc(score_with_bonus, c_recent_explicit_user_choice_bonus);
                if (latest_query_choice_text <> '') and SameText(latest_query_choice_text, text) then
                begin
                    Inc(score_with_bonus, c_exact_latest_choice_bonus);
                end;
            end;
        end;
        if (candidate_pinyin_key <> '') and (comment = '') then
        begin
            penalty_value := get_candidate_penalty(candidate_pinyin_key, text);
            if penalty_value > 0 then
            begin
                if source = cs_user then
                begin
                    Exit;
                end;
                Dec(score_with_bonus, Min(480, penalty_value * 4));
            end;
        end;
        if score_with_bonus > max_final_score then
        begin
            score_with_bonus := max_final_score;
        end;

        effective_source := source;

        effective_has_dict_weight := (effective_source = cs_rule) and has_dict_weight;
        effective_dict_weight := dict_weight;

        item := Default(TncCandidate);
        item.text := text;
        item.comment := comment;
        item.score := score_with_bonus;
        item.source := effective_source;
        item.has_dict_weight := effective_has_dict_weight;
        item.dict_weight := effective_dict_weight;
        item.fuzzy_cost := 0;
        item.fuzzy_rules := [];
        list.Add(item);
        seen.Add(key, True);
        if (candidate_pinyin_key <> '') and (candidate_pinyin_map <> nil) then
        begin
            candidate_pinyin_map.AddOrSetValue(key, candidate_pinyin_key);
        end;
        if (candidate_score_cap_map <> nil) and (max_final_score < MaxInt) then
        begin
            candidate_score_cap_map.AddOrSetValue(key, max_final_score);
        end;
    end;

    procedure apply_short_jianpin_commonness_rerank;
    const
        c_short_jianpin_query_len_max = 3;
        c_short_jianpin_expensive_rerank_limit = 160;
        c_short_jianpin_retroflex_expensive_rerank_limit = 24;
        c_len2_followup_rerank_limit = 40;
        c_len2_prefix_factor = 18.0;
        c_len2_prefix_bonus_cap = 220;
        c_len2_log_weight_factor = 68.0;
        c_len3_log_weight_factor = 88.0;
        c_len2_followup_factor = 20.0;
        c_len3_followup_factor = 28.0;
        c_len2_followup_bonus_cap = 180;
        c_len3_followup_bonus_cap = 200;
        c_exact_syllable_bonus = 18;
        c_len2_constituent_factor = 0.50;
        c_len3_constituent_factor = 0.32;
        c_len2_constituent_bonus_cap = 420;
        c_len3_constituent_bonus_cap = 300;
        c_len2_weak_unit_penalty_floor = 350;
        c_len2_weak_unit_penalty_factor = 3.0;
        c_len2_weak_unit_penalty_cap = 200;
        c_len2_prefix_ratio_penalty_threshold = 2.4;
        c_len2_prefix_ratio_penalty_factor = 92.0;
        c_len2_prefix_ratio_penalty_cap = 180;
        c_reduplicated_exact_bonus = 160;
        c_reduplicated_weight_factor = 0.85;
        c_reduplicated_tail_bonus = 700;
        c_reduplicated_tail_weight_factor = 0.60;
    var
        candidate_item: TncCandidate;
        candidate_pinyin_key: string;
        candidate_syllables: TArray<string>;
        candidate_text_units: TArray<string>;
        candidate_unit_count: Integer;
        query_unit_count: Integer;
        idx: Integer;
        followup_score: Integer;
        prefix_score: Integer;
        reranked_score: Integer;
        should_run_expensive_rerank: Boolean;
        len2_followup_indexes: TList<Integer>;
        len2_followup_texts: TArray<string>;
        len2_followup_pinyins: TArray<string>;
        len2_prefix_scores: TDictionary<string, Integer>;
        len2_followup_scores: TDictionary<string, Integer>;
        weight_factor: Double;
        followup_factor: Double;
        followup_bonus_cap: Integer;
        constituent_factor: Double;
        constituent_bonus_cap: Integer;
        constituent_weight_sum: Integer;
        min_constituent_weight: Integer;
        unit_weight_value: Integer;
        unit_idx: Integer;
        expensive_rerank_limit: Integer;
        retroflex_pair_count: Integer;
        prefix_productivity_ratio: Double;

        function get_reduplicated_exact_bonus_local: Integer;
        var
            idx_local: Integer;
            initial_value: string;
        begin
            Result := 0;
            if (query_unit_count < 2) or (query_unit_count > 3) or
                (Length(query_key) <> query_unit_count) then
            begin
                Exit;
            end;
            for idx_local := 2 to Length(query_key) do
            begin
                if query_key[idx_local] <> query_key[1] then
                begin
                    Exit;
                end;
            end;
            if (candidate_unit_count <> query_unit_count) or
                (Length(candidate_syllables) <> query_unit_count) or
                (Length(candidate_text_units) <> query_unit_count) then
            begin
                Exit;
            end;
            if (candidate_text_units[0] = '') or
                (candidate_syllables[0] = '') then
            begin
                Exit;
            end;
            for idx_local := 1 to query_unit_count - 1 do
            begin
                if (candidate_text_units[idx_local] <> candidate_text_units[0]) or
                    (candidate_syllables[idx_local] <> candidate_syllables[0]) then
                begin
                    Exit;
                end;
            end;
            initial_value := extract_syllable_initial(candidate_syllables[0]);
            if (initial_value = '') or (initial_value[1] <> query_key[1]) then
            begin
                Exit;
            end;
            for idx_local := 1 to query_unit_count - 1 do
            begin
                initial_value := extract_syllable_initial(candidate_syllables[idx_local]);
                if (initial_value = '') or (initial_value[1] <> query_key[idx_local]) then
                begin
                    Exit;
                end;
            end;
            Result := c_reduplicated_exact_bonus +
                Round(candidate_item.dict_weight * c_reduplicated_weight_factor);
        end;

        function get_reduplicated_tail_bonus_local: Integer;
        var
            idx_local: Integer;
            initial_value: string;
        begin
            Result := 0;
            if (query_unit_count <> 3) or
                (Length(query_key) <> query_unit_count) or
                (candidate_unit_count <> query_unit_count) or
                (Length(candidate_syllables) <> query_unit_count) or
                (Length(candidate_text_units) <> query_unit_count) then
            begin
                Exit;
            end;

            if (candidate_text_units[1] = '') or
                (candidate_syllables[1] = '') or
                (candidate_text_units[1] <> candidate_text_units[2]) or
                (candidate_syllables[1] <> candidate_syllables[2]) then
            begin
                Exit;
            end;

            for idx_local := 0 to query_unit_count - 1 do
            begin
                initial_value := extract_syllable_initial(candidate_syllables[idx_local]);
                if (initial_value = '') or (initial_value[1] <> query_key[idx_local + 1]) then
                begin
                    Exit;
                end;
            end;

            Result := c_reduplicated_tail_bonus +
                Round(candidate_item.dict_weight * c_reduplicated_tail_weight_factor);
        end;
    begin
        if full_pinyin_query or mixed_mode or
            (Length(query_key) < 2) or
            (Length(query_key) > c_short_jianpin_query_len_max) or
            (list.Count <= 1) then
        begin
            Exit;
        end;
        if not should_try_jianpin_lookup(query_key) then
        begin
            Exit;
        end;

        query_unit_count := Length(query_key);
        if query_unit_count <= 0 then
        begin
            Exit;
        end;

        if query_unit_count <= 2 then
        begin
            weight_factor := c_len2_log_weight_factor;
            followup_factor := c_len2_followup_factor;
            followup_bonus_cap := c_len2_followup_bonus_cap;
            constituent_factor := c_len2_constituent_factor;
            constituent_bonus_cap := c_len2_constituent_bonus_cap;
        end
        else
        begin
            weight_factor := c_len3_log_weight_factor;
            followup_factor := c_len3_followup_factor;
            followup_bonus_cap := c_len3_followup_bonus_cap;
            constituent_factor := c_len3_constituent_factor;
            constituent_bonus_cap := c_len3_constituent_bonus_cap;
        end;

        retroflex_pair_count := count_retroflex_pairs_in_compact_key(query_key);
        if retroflex_pair_count > 0 then
        begin
            expensive_rerank_limit := c_short_jianpin_retroflex_expensive_rerank_limit;
        end
        else
        begin
            expensive_rerank_limit := c_short_jianpin_expensive_rerank_limit;
        end;

        len2_followup_indexes := nil;
        if (retroflex_pair_count = 0) and (query_unit_count <= 2) then
        begin
            len2_followup_indexes := TList<Integer>.Create;
        end;
        try
            for idx := 0 to list.Count - 1 do
            begin
                candidate_item := list[idx];
                if (candidate_item.source <> cs_rule) or
                    (candidate_item.comment <> '') or
                    (not candidate_item.has_dict_weight) or
                    (candidate_item.dict_weight <= 0) then
                begin
                    Continue;
                end;

                if (candidate_pinyin_map = nil) or
                    (not candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) then
                begin
                    Continue;
                end;
                if (candidate_pinyin_key = '') or (not is_full_pinyin_key(candidate_pinyin_key)) then
                begin
                    Continue;
                end;

                candidate_unit_count := get_text_unit_count_local(candidate_item.text);
                if candidate_unit_count < 2 then
                begin
                    Continue;
                end;

                reranked_score := Round(Ln(1.0 + candidate_item.dict_weight) * weight_factor);
                candidate_syllables := split_full_pinyin_syllables(candidate_pinyin_key);
                if Length(candidate_syllables) <= 0 then
                begin
                    candidate_item.score := reranked_score;
                    list[idx] := candidate_item;
                    Continue;
                end;

                if Length(candidate_syllables) = query_unit_count then
                begin
                    Inc(reranked_score, c_exact_syllable_bonus);
                end;

                if (candidate_unit_count = query_unit_count) and
                    (Length(candidate_syllables) = candidate_unit_count) then
                begin
                    candidate_text_units := split_text_units_local(Trim(candidate_item.text));
                    if Length(candidate_text_units) = candidate_unit_count then
                    begin
                        constituent_weight_sum := 0;
                        min_constituent_weight := MaxInt;
                        for unit_idx := 0 to candidate_unit_count - 1 do
                        begin
                            unit_weight_value := get_single_char_exact_weight(candidate_syllables[unit_idx],
                                candidate_text_units[unit_idx]);
                            Inc(constituent_weight_sum, unit_weight_value);
                            if unit_weight_value < min_constituent_weight then
                            begin
                                min_constituent_weight := unit_weight_value;
                            end;
                        end;
                        if constituent_weight_sum > 0 then
                        begin
                            Inc(reranked_score, Min(constituent_bonus_cap,
                                Round(constituent_weight_sum * constituent_factor)));
                        end;
                        if (query_unit_count <= 2) and (min_constituent_weight <> MaxInt) and
                            (min_constituent_weight < c_len2_weak_unit_penalty_floor) then
                        begin
                            Dec(reranked_score, Min(c_len2_weak_unit_penalty_cap,
                                Round((c_len2_weak_unit_penalty_floor - min_constituent_weight) *
                                    c_len2_weak_unit_penalty_factor)));
                        end;
                        Inc(reranked_score, get_reduplicated_exact_bonus_local);
                        Inc(reranked_score, get_reduplicated_tail_bonus_local);
                    end;
                end;

                candidate_item.score := reranked_score;
                list[idx] := candidate_item;

                if len2_followup_indexes <> nil then
                begin
                    if Length(candidate_syllables) = query_unit_count then
                    begin
                        len2_followup_indexes.Add(idx);
                    end;
                    Continue;
                end;

                should_run_expensive_rerank := idx < expensive_rerank_limit;
                if not should_run_expensive_rerank then
                begin
                    Continue;
                end;

                followup_score := get_pinyin_followup_popularity_score(candidate_pinyin_key);
                if followup_score > 0 then
                begin
                    Inc(candidate_item.score, Min(followup_bonus_cap,
                        Round(Ln(1.0 + followup_score) * followup_factor)));
                    list[idx] := candidate_item;
                end;
            end;

            if (len2_followup_indexes <> nil) and (len2_followup_indexes.Count > 1) then
            begin
                len2_followup_indexes.Sort(TComparer<Integer>.Construct(
                    function(const left, right: Integer): Integer
                    begin
                        Result := list[right].score - list[left].score;
                        if Result <> 0 then
                        begin
                            Exit;
                        end;
                        Result := left - right;
                    end));
            end;

            if len2_followup_indexes <> nil then
            begin
                SetLength(len2_followup_texts, Min(c_len2_followup_rerank_limit, len2_followup_indexes.Count));
                SetLength(len2_followup_pinyins, Length(len2_followup_texts));
                for idx := 0 to High(len2_followup_texts) do
                begin
                    candidate_item := list[len2_followup_indexes[idx]];
                    len2_followup_texts[idx] := candidate_item.text;
                    if (candidate_pinyin_map <> nil) and
                        candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key) then
                    begin
                        len2_followup_pinyins[idx] := candidate_pinyin_key;
                    end
                    else
                    begin
                        len2_followup_pinyins[idx] := '';
                    end;
                end;

                len2_prefix_scores := TDictionary<string, Integer>.Create;
                len2_followup_scores := TDictionary<string, Integer>.Create;
                try
                    populate_prefix_popularity_scores(len2_followup_texts, len2_prefix_scores);
                    populate_pinyin_followup_popularity_scores(len2_followup_pinyins, len2_followup_scores);

                    for idx := 0 to High(len2_followup_texts) do
                    begin
                        candidate_item := list[len2_followup_indexes[idx]];
                        if len2_prefix_scores.TryGetValue(candidate_item.text, prefix_score) and
                            (prefix_score > 0) then
                        begin
                            Inc(candidate_item.score, Min(c_len2_prefix_bonus_cap,
                                Round(Ln(1.0 + prefix_score) * c_len2_prefix_factor)));
                            if candidate_item.dict_weight > 0 then
                            begin
                                prefix_productivity_ratio := prefix_score / candidate_item.dict_weight;
                                if prefix_productivity_ratio > c_len2_prefix_ratio_penalty_threshold then
                                begin
                                    Dec(candidate_item.score, Min(c_len2_prefix_ratio_penalty_cap,
                                        Round(Ln(prefix_productivity_ratio /
                                            c_len2_prefix_ratio_penalty_threshold) *
                                            c_len2_prefix_ratio_penalty_factor)));
                                end;
                            end;
                        end;

                        if len2_followup_scores.TryGetValue(len2_followup_pinyins[idx], followup_score) and
                            (followup_score > 0) then
                        begin
                            Inc(candidate_item.score, Min(followup_bonus_cap,
                                Round(Ln(1.0 + followup_score) * followup_factor)));
                        end;
                        list[len2_followup_indexes[idx]] := candidate_item;
                    end;
                finally
                    len2_followup_scores.Free;
                    len2_prefix_scores.Free;
                end;
            end;
        finally
            if len2_followup_indexes <> nil then
            begin
                len2_followup_indexes.Free;
            end;
        end;
    end;

    procedure sort_candidate_list_by_score;
    begin
        if list.Count <= 1 then
        begin
            Exit;
        end;

        list.Sort(TComparer<TncCandidate>.Construct(
            function(const left, right: TncCandidate): Integer
            begin
                Result := right.score - left.score;
                if Result <> 0 then
                begin
                    Exit;
                end;

                case left.source of
                    cs_user:
                        Result := 0;
                    cs_rule:
                        Result := 1;
                else
                    Result := 2;
                end;
                case right.source of
                    cs_user:
                        Dec(Result, 0);
                    cs_rule:
                        Dec(Result, 1);
                else
                    Dec(Result, 2);
                end;
                if Result <> 0 then
                begin
                    Exit;
                end;

                if (left.comment = '') and (right.comment <> '') then
                begin
                    Result := -1;
                    Exit;
                end;
                if (right.comment = '') and (left.comment <> '') then
                begin
                    Result := 1;
                    Exit;
                end;

                Result := Length(left.text) - Length(right.text);
                if Result <> 0 then
                begin
                    Exit;
                end;

                Result := CompareText(left.text, right.text);
                if Result <> 0 then
                begin
                    Exit;
                end;

                Result := CompareText(left.comment, right.comment);
            end));
    end;

    procedure apply_text_learning_bonus;
    var
        bonus_value: Integer;
        candidate_item: TncCandidate;
        idx: Integer;
        stmt_text_stats: Psqlite3_stmt;
        text_commit_count: Integer;
        text_last_used_value: Int64;
        text_step_result: Integer;
    begin
        if (not m_user_ready) or (list.Count <= 0) then
        begin
            Exit;
        end;

        stmt_text_stats := nil;
        try
            if not m_user_connection.prepare(text_stats_sql, stmt_text_stats) then
            begin
                Exit;
            end;

            for idx := 0 to list.Count - 1 do
            begin
                candidate_item := list[idx];
                if (candidate_item.text = '') or (candidate_item.source <> cs_rule) then
                begin
                    Continue;
                end;
                if learning_bonus_map.ContainsKey(candidate_item.text) then
                begin
                    Continue;
                end;
                if full_pinyin_query and (get_valid_cjk_codepoint_count(candidate_item.text) = 1) then
                begin
                    Continue;
                end;

                if not text_learning_bonus_cache.TryGetValue(candidate_item.text, bonus_value) then
                begin
                    bonus_value := 0;
                    if m_user_connection.bind_text(stmt_text_stats, 1, candidate_item.text) then
                    begin
                        text_step_result := m_user_connection.step(stmt_text_stats);
                        if text_step_result = SQLITE_ROW then
                        begin
                            text_commit_count := m_user_connection.column_int(stmt_text_stats, 0);
                            text_last_used_value := m_user_connection.column_int(stmt_text_stats, 1);
                            bonus_value := calc_text_learning_bonus(
                                text_commit_count,
                                text_last_used_value,
                                now_unix);
                        end;
                    end;
                    m_user_connection.reset(stmt_text_stats);
                    m_user_connection.clear_bindings(stmt_text_stats);
                    text_learning_bonus_cache.AddOrSetValue(candidate_item.text, bonus_value);
                end;

                if bonus_value <= 0 then
                begin
                    Continue;
                end;

                if candidate_item.comment <> '' then
                begin
                    bonus_value := bonus_value div 2;
                end;
                if bonus_value <= 0 then
                begin
                    Continue;
                end;

                candidate_item.score := candidate_item.score + bonus_value;
                if candidate_score_cap_map.TryGetValue(candidate_item.text, candidate_score_cap) and
                    (candidate_item.score > candidate_score_cap) then
                begin
                    candidate_item.score := candidate_score_cap;
                end;
                list[idx] := candidate_item;
                Inc(applied_text_learning_bonus_count);
            end;
    finally
        if stmt_text_stats <> nil then
        begin
            m_user_connection.finalize(stmt_text_stats);
        end;
    end;
  end;

    procedure apply_short_full_pinyin_commonness_tiebreak;
    const
        c_min_syllables = 2;
        c_max_syllables = 3;
        c_close_weight_gap = 96;
        c_close_weight_ratio_pct = 90;
        c_commonness_factor = 8;
        c_commonness_bonus_cap = 960;
    var
        exact_indexes: TList<Integer>;
        idx, list_index: Integer;
        candidate_item: TncCandidate;
        candidate_pinyin_key: string;
        best_weight: Integer;
        commonness_bonus: Integer;
        score_bonus: Integer;
    begin
        if (not full_pinyin_query) or mixed_mode then
        begin
            Exit;
        end;
        if (full_query_syllable_count < c_min_syllables) or
            (full_query_syllable_count > c_max_syllables) then
        begin
            Exit;
        end;
        if (list.Count <= 1) or (candidate_pinyin_map = nil) then
        begin
            Exit;
        end;

        exact_indexes := TList<Integer>.Create;
        try
            best_weight := Low(Integer);
            for idx := 0 to list.Count - 1 do
            begin
                candidate_item := list[idx];
                if (candidate_item.source <> cs_rule) or (candidate_item.comment <> '') or
                    (not candidate_item.has_dict_weight) or (candidate_item.dict_weight <= 0) then
                begin
                    Continue;
                end;
                if get_text_unit_count_local(candidate_item.text) <> full_query_syllable_count then
                begin
                    Continue;
                end;
                if (not candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) or
                    (candidate_pinyin_key <> query_key) then
                begin
                    Continue;
                end;

                exact_indexes.Add(idx);
                if candidate_item.dict_weight > best_weight then
                begin
                    best_weight := candidate_item.dict_weight;
                end;
            end;

            if exact_indexes.Count <= 1 then
            begin
                Exit;
            end;

            for list_index in exact_indexes do
            begin
                candidate_item := list[list_index];
                if (best_weight - candidate_item.dict_weight > c_close_weight_gap) and
                    (candidate_item.dict_weight * 100 < best_weight * c_close_weight_ratio_pct) then
                begin
                    Continue;
                end;

                commonness_bonus := get_base_text_prefix_bonus(candidate_item.text);
                if commonness_bonus <= 0 then
                begin
                    Continue;
                end;

                score_bonus := commonness_bonus * c_commonness_factor;
                if score_bonus > c_commonness_bonus_cap then
                begin
                    score_bonus := c_commonness_bonus_cap;
                end;

                Inc(candidate_item.score, score_bonus);
                list[list_index] := candidate_item;
            end;
        finally
            exact_indexes.Free;
        end;
    end;

    function get_single_letter_full_query_spoken_bonus(const text_value_local: string): Integer;
    begin
        Result := 0;
        if (not single_letter_query) or (Length(query_key) <> 1) or (text_value_local = '') then
        begin
            Exit;
        end;

        case query_key[1] of
            'a':
                begin
                    if text_value_local = string(Char($554A)) then      // 啊
                    begin
                        Result := 220;
                    end
                    else if text_value_local = string(Char($963F)) then // 阿
                    begin
                        Result := 80;
                    end
                    else if text_value_local = string(Char($5475)) then // 呵
                    begin
                        Result := 60;
                    end
                    else if text_value_local = string(Char($5416)) then // 吖
                    begin
                        Result := 40;
                    end;
                end;
            'e':
                begin
                    if text_value_local = string(Char($5443)) then      // 呃
                    begin
                        Result := 240;
                    end
                    else if text_value_local = string(Char($8BE6)) then // 诶
                    begin
                        Result := 180;
                    end
                    else if text_value_local = string(Char($6B38)) then // 欸
                    begin
                        Result := 160;
                    end
                    else if text_value_local = string(Char($997F)) then // 饿
                    begin
                        Result := 80;
                    end
                    else if text_value_local = string(Char($54E6)) then // 哦
                    begin
                        Result := 60;
                    end;
                end;
            'o':
                begin
                    if text_value_local = string(Char($54E6)) then      // 哦
                    begin
                        Result := 240;
                    end
                    else if text_value_local = string(Char($5662)) then // 噢
                    begin
                        Result := 220;
                    end
                    else if text_value_local = string(Char($5594)) then // 喔
                    begin
                        Result := 160;
                    end;
                end;
        end;
    end;

    procedure apply_single_letter_full_query_standalone_rerank;
    const
        c_prefix_penalty_factor = 20.0;
        c_prefix_penalty_cap = 140;
    var
        candidate_item: TncCandidate;
        idx: Integer;
        prefix_score: Integer;
        penalty_value: Integer;
        text_value_local: string;
    begin
        if (not full_pinyin_query) or (not single_letter_query) or (list.Count <= 1) then
        begin
            Exit;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if (candidate_item.source <> cs_rule) or (candidate_item.comment <> '') then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            prefix_score := get_prefix_popularity_score(text_value_local);
            if prefix_score <= 0 then
            begin
                Continue;
            end;

            penalty_value := Round(Ln(1.0 + prefix_score) * c_prefix_penalty_factor);
            if penalty_value > c_prefix_penalty_cap then
            begin
                penalty_value := c_prefix_penalty_cap;
            end;
            if penalty_value <= 0 then
            begin
                Continue;
            end;

            Dec(candidate_item.score, penalty_value);
            list[idx] := candidate_item;
        end;
    end;

    procedure apply_single_letter_full_query_spoken_bonus;
    var
        candidate_item: TncCandidate;
        idx: Integer;
        spoken_bonus: Integer;
        text_value_local: string;
    begin
        if (not full_pinyin_query) or (not single_letter_query) or (list.Count <= 1) then
        begin
            Exit;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if (candidate_item.source <> cs_rule) or (candidate_item.comment <> '') then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            spoken_bonus := get_single_letter_full_query_spoken_bonus(text_value_local);
            if spoken_bonus <= 0 then
            begin
                Continue;
            end;

            Inc(candidate_item.score, spoken_bonus);
            list[idx] := candidate_item;
        end;
    end;

    procedure enforce_single_letter_exact_group_priority;
    var
        candidate_item: TncCandidate;
        idx: Integer;
        exact_group_floor: Integer;
        candidate_pinyin_key: string;
        text_value_local: string;
        has_exact_group: Boolean;
    begin
        if (not full_pinyin_query) or (not single_letter_query) or (list.Count <= 1) or
            (candidate_pinyin_map = nil) then
        begin
            Exit;
        end;

        exact_group_floor := MaxInt;
        has_exact_group := False;
        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if candidate_item.comment <> '' then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            if (not candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) or
                (not SameText(candidate_pinyin_key, query_key)) then
            begin
                Continue;
            end;

            has_exact_group := True;
            if candidate_item.score < exact_group_floor then
            begin
                exact_group_floor := candidate_item.score;
            end;
        end;

        if (not has_exact_group) or (exact_group_floor = MaxInt) then
        begin
            Exit;
        end;

        Dec(exact_group_floor);
        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if candidate_item.comment <> '' then
            begin
                Continue;
            end;

            text_value_local := Trim(candidate_item.text);
            if (text_value_local = '') or (get_text_unit_count_local(text_value_local) <> 1) then
            begin
                Continue;
            end;

            if (candidate_pinyin_map.TryGetValue(candidate_item.text, candidate_pinyin_key)) and
                SameText(candidate_pinyin_key, query_key) then
            begin
                Continue;
            end;

            if candidate_item.score > exact_group_floor then
            begin
                candidate_item.score := exact_group_floor;
                list[idx] := candidate_item;
            end;
        end;
    end;

    procedure apply_candidate_score_caps;
    var
        candidate_item: TncCandidate;
        idx: Integer;
    begin
        if (candidate_score_cap_map = nil) or (candidate_score_cap_map.Count <= 0) then
        begin
            Exit;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            candidate_item := list[idx];
            if candidate_score_cap_map.TryGetValue(candidate_item.text, candidate_score_cap) and
                (candidate_item.score > candidate_score_cap) then
            begin
                candidate_item.score := candidate_score_cap;
                list[idx] := candidate_item;
            end;
        end;
    end;

    procedure append_learned_exact_base_candidates;
    var
        learned_stmt: Psqlite3_stmt;
        learned_pair: TPair<string, Integer>;
        learned_pinyin: string;
        learned_text: string;
        learned_comment: string;
        learned_weight: Integer;
        learned_step_result: Integer;
    begin
        if (not full_pinyin_query) or (not m_base_ready) or (learning_bonus_map.Count <= 0) then
        begin
            Exit;
        end;

        learned_stmt := nil;
        try
            if not m_base_connection.prepare(base_exact_entry_normalized_sql, learned_stmt) then
            begin
                Exit;
            end;

            for learned_pair in learning_bonus_map do
            begin
                if seen.ContainsKey(learned_pair.Key) then
                begin
                    Continue;
                end;

                if not m_base_connection.bind_text(learned_stmt, 1, query_key) or
                    not m_base_connection.bind_text(learned_stmt, 2, learned_pair.Key) or
                    not m_base_connection.bind_text(learned_stmt, 3, '''') or
                    not m_base_connection.bind_text(learned_stmt, 4, '') then
                begin
                    m_base_connection.reset(learned_stmt);
                    m_base_connection.clear_bindings(learned_stmt);
                    Continue;
                end;

                learned_step_result := m_base_connection.step(learned_stmt);
                while learned_step_result = SQLITE_ROW do
                begin
                    learned_pinyin := Trim(m_base_connection.column_text(learned_stmt, 0));
                    if not same_normalized_pinyin_key(learned_pinyin, query_key) then
                    begin
                        learned_step_result := m_base_connection.step(learned_stmt);
                        Continue;
                    end;
                    if full_query_dual_jianpin_mode and exact_base_hit and
                        (not SameText(learned_pinyin, base_exact_query_key)) then
                    begin
                        learned_step_result := m_base_connection.step(learned_stmt);
                        Continue;
                    end;
                    learned_text := m_base_connection.column_text(learned_stmt, 1);
                    learned_comment := m_base_connection.column_text(learned_stmt, 2);
                    learned_weight := m_base_connection.column_int(learned_stmt, 3);
                    append_candidate(learned_text, learned_comment, learned_weight, cs_rule, True,
                        learned_weight, learned_pinyin);
                    exact_base_hit := True;
                    Inc(injected_learned_base_count);
                    learned_step_result := m_base_connection.step(learned_stmt);
                end;

                m_base_connection.reset(learned_stmt);
                m_base_connection.clear_bindings(learned_stmt);
            end;
        finally
            if learned_stmt <> nil then
            begin
                m_base_connection.finalize(learned_stmt);
            end;
        end;
    end;

    procedure apply_homophone_commonness_bonus;
    const
        c_single_char_factor = 190.0;
        c_single_char_min_base_score = 260;
        c_single_prefix_metric_weight = 0.05;
        c_phrase_factor = 1400.0;
        c_phrase_bonus_cap = 2200;
    var
        metrics: TArray<Double>;
        unit_counts: TArray<Integer>;
        candidate_item: TncCandidate;
        has_single: Boolean;
        has_phrase: Boolean;
        min_single: Double;
        min_phrase: Double;
        metric: Double;
        delta: Double;
        bonus: Integer;
        text_value_local: string;
        idx: Integer;
        prefix_two_units: string;
    begin
        if (not full_pinyin_query) or (list.Count <= 1) then
        begin
            Exit;
        end;

        SetLength(metrics, list.Count);
        SetLength(unit_counts, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            metrics[idx] := -1.0;
            unit_counts[idx] := 0;
        end;

        has_single := False;
        has_phrase := False;
        min_single := 0.0;
        min_phrase := 0.0;

        for idx := 0 to list.Count - 1 do
        begin
            if list[idx].source <> cs_rule then
            begin
                Continue;
            end;
            if list[idx].comment <> '' then
            begin
                Continue;
            end;

            text_value_local := Trim(list[idx].text);
            if text_value_local = '' then
            begin
                Continue;
            end;

            unit_counts[idx] := get_text_unit_count_local(text_value_local);
            if unit_counts[idx] <= 0 then
            begin
                Continue;
            end;

            if unit_counts[idx] = 1 then
            begin
                if list[idx].score < c_single_char_min_base_score then
                begin
                    Continue;
                end;

                metric := Ln(1.0 + get_contains_popularity_score(text_value_local)) +
                    (Ln(1.0 + get_prefix_popularity_score(text_value_local)) *
                    c_single_prefix_metric_weight);
                metrics[idx] := metric;
                if not has_single or (metric < min_single) then
                begin
                    min_single := metric;
                    has_single := True;
                end;
            end
            else
            begin
                prefix_two_units := copy_first_text_units(text_value_local, 2);
                if prefix_two_units = '' then
                begin
                    Continue;
                end;

                metric := Ln(1.0 + get_prefix_popularity_score(prefix_two_units));
                metrics[idx] := metric;

                if not has_phrase or (metric < min_phrase) then
                begin
                    min_phrase := metric;
                    has_phrase := True;
                end;
            end;
        end;

        for idx := 0 to list.Count - 1 do
        begin
            if metrics[idx] < 0 then
            begin
                Continue;
            end;

            if unit_counts[idx] = 1 then
            begin
                if not has_single then
                begin
                    Continue;
                end;
                delta := metrics[idx] - min_single;
                if delta <= 0 then
                begin
                    Continue;
                end;
                bonus := Round(delta * c_single_char_factor);
            end
            else
            begin
                if not has_phrase then
                begin
                    Continue;
                end;
                delta := metrics[idx] - min_phrase;
                if delta <= 0 then
                begin
                    Continue;
                end;
                bonus := Round(delta * c_phrase_factor);
                if bonus > c_phrase_bonus_cap then
                begin
                    bonus := c_phrase_bonus_cap;
                end;
            end;

            candidate_item := list[idx];
            candidate_item.score := candidate_item.score + bonus;
            list[idx] := candidate_item;
        end;
    end;

    function build_mixed_like_pattern(const token_list: TncMixedQueryTokenList): string;
    var
        pattern_idx: Integer;
    begin
        Result := '';
        if Length(token_list) = 0 then
        begin
            Exit;
        end;

        for pattern_idx := 0 to High(token_list) do
        begin
            if token_list[pattern_idx].text = '' then
            begin
                Continue;
            end;

            if token_list[pattern_idx].kind = mqt_full then
            begin
                Result := Result + token_list[pattern_idx].text;
            end
            else
            begin
                Result := Result + token_list[pattern_idx].text + '%';
            end;
        end;

        if Result <> '' then
        begin
            Result := Result + '%';
        end;
    end;

    function is_compact_ascii_query(const value: string): Boolean;
    var
        value_idx: Integer;
    begin
        Result := value <> '';
        if not Result then
        begin
            Exit;
        end;

        for value_idx := 1 to Length(value) do
        begin
            if not CharInSet(value[value_idx], ['a' .. 'z']) then
            begin
                Result := False;
                Exit;
            end;
        end;
    end;

    function append_adjacent_transposition_typo_candidates: Boolean;
    var
        swap_idx: Integer;
        swap_key: string;
        typo_stmt: Psqlite3_stmt;
        prefix_stmt: Psqlite3_stmt;
        swap_seen: TDictionary<string, Boolean>;
        before_count: Integer;
        before_swap_added: Integer;
        typo_added: Integer;
        swap_char: Char;
        existing_idx: Integer;
        has_user_existing: Boolean;
        typo_min_query_len: Integer;
    begin
        Result := False;
        if not m_base_ready then
        begin
            Exit;
        end;
        // Keep strict exact-match priority only for full-pinyin queries.
        // Non-full inputs may still be user typos (e.g. "chagn" -> "chang").
        if exact_base_hit and full_pinyin_query then
        begin
            Exit;
        end;
        // Adjacent-swap typo recovery is intentionally limited to malformed/non-full
        // inputs. For valid full-pinyin keys like "zuoshen", forcing swapped exact
        // words such as "zoushen" is more harmful than helpful.
        if full_pinyin_query then
        begin
            Exit;
        end
        else
        begin
            typo_min_query_len := c_typo_min_query_len_nonfull;
        end;
        if Length(query_key) < typo_min_query_len then
        begin
            Exit;
        end;
        if not is_compact_ascii_query(query_key) then
        begin
            Exit;
        end;
        if (not full_pinyin_query) and (not mixed_mode) and (Length(query_key) <= 6) and
            (list.Count > 0) then
        begin
            // Keep short non-full inputs conservative: if they already produced
            // direct results, avoid over-eager adjacent-swap typo recovery.
            Exit;
        end;

        // Mixed/non-full probing may already have filled list with noisy rule candidates.
        // If no user hit is present, clear them so transposition recovery can surface.
        if (not full_pinyin_query) and (list.Count > 0) then
        begin
            if force_noisy_reset_before_typo then
            begin
                list.Clear;
                seen.Clear;
                candidate_pinyin_map.Clear;
            end
            else
            begin
                has_user_existing := False;
                for existing_idx := 0 to list.Count - 1 do
                begin
                    if list[existing_idx].source = cs_user then
                    begin
                        has_user_existing := True;
                        Break;
                    end;
                end;

                if not has_user_existing then
                begin
                    list.Clear;
                    seen.Clear;
                    candidate_pinyin_map.Clear;
                end;
            end;
        end;

        swap_seen := TDictionary<string, Boolean>.Create;
        try
            typo_added := 0;
            for swap_idx := 1 to Length(query_key) - 1 do
            begin
                if query_key[swap_idx] = query_key[swap_idx + 1] then
                begin
                    Continue;
                end;

                swap_key := query_key;
                swap_char := swap_key[swap_idx];
                swap_key[swap_idx] := swap_key[swap_idx + 1];
                swap_key[swap_idx + 1] := swap_char;

                if swap_seen.ContainsKey(swap_key) then
                begin
                    Continue;
                end;
                swap_seen.Add(swap_key, True);

                if not is_full_pinyin_key(swap_key) then
                begin
                    Continue;
                end;

                before_swap_added := typo_added;
                typo_stmt := nil;
                try
                    if m_base_connection.prepare(base_sql, typo_stmt) and
                        m_base_connection.bind_text(typo_stmt, 1, swap_key) and
                        m_base_connection.bind_int(typo_stmt, 2, c_typo_probe_limit) then
                    begin
                        step_result := m_base_connection.step(typo_stmt);
                        while step_result = SQLITE_ROW do
                        begin
                            text_value := m_base_connection.column_text(typo_stmt, 1);
                            comment_value := m_base_connection.column_text(typo_stmt, 2);
                            dict_weight_value := m_base_connection.column_int(typo_stmt, 3);
                            score_value := dict_weight_value - c_typo_transpose_penalty;
                            before_count := list.Count;
                            append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                dict_weight_value, swap_key);
                            if list.Count > before_count then
                            begin
                                Inc(typo_added);
                                if typo_added >= c_typo_max_added then
                                begin
                                    Break;
                                end;
                            end;
                            step_result := m_base_connection.step(typo_stmt);
                        end;
                    end;
                finally
                    if typo_stmt <> nil then
                    begin
                        m_base_connection.finalize(typo_stmt);
                    end;
                end;

                // If exact swapped-key rows are absent, probe a small prefix window
                // (e.g. "chang%") so typo correction still surfaces meaningful heads.
                if (((full_pinyin_query and (Length(swap_key) >= c_typo_prefix_min_query_len_full)) or
                    ((not full_pinyin_query) and (Length(swap_key) >= c_typo_prefix_min_query_len_nonfull))) and
                    (typo_added = before_swap_added)) then
                begin
                    prefix_stmt := nil;
                    try
                        if m_base_connection.prepare(base_typo_prefix_sql, prefix_stmt) and
                            m_base_connection.bind_text(prefix_stmt, 1, swap_key + '%') and
                            m_base_connection.bind_int(prefix_stmt, 2, c_typo_prefix_probe_limit) then
                        begin
                            step_result := m_base_connection.step(prefix_stmt);
                            while step_result = SQLITE_ROW do
                            begin
                                text_value := m_base_connection.column_text(prefix_stmt, 1);
                                comment_value := m_base_connection.column_text(prefix_stmt, 2);
                                dict_weight_value := m_base_connection.column_int(prefix_stmt, 3);
                                score_value := dict_weight_value -
                                    c_typo_transpose_penalty - c_typo_prefix_extra_penalty;
                                before_count := list.Count;
                                append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                    dict_weight_value, swap_key);
                                if list.Count > before_count then
                                begin
                                    Inc(typo_added);
                                    if typo_added >= c_typo_max_added then
                                    begin
                                        Break;
                                    end;
                                end;
                                step_result := m_base_connection.step(prefix_stmt);
                            end;
                        end;
                    finally
                        if prefix_stmt <> nil then
                        begin
                            m_base_connection.finalize(prefix_stmt);
                        end;
                    end;
                end;

                if typo_added >= c_typo_max_added then
                begin
                    Break;
                end;
            end;
            Result := typo_added > 0;
        finally
            swap_seen.Free;
        end;
    end;
begin
    SetLength(results, 0);
    m_last_lookup_debug_hint := '';
    applied_learning_bonus_count := 0;
    applied_text_learning_bonus_count := 0;
    skipped_single_char_mismatch_count := 0;
    skipped_noisy_user_count := 0;
    skipped_base_dup_user_count := 0;
    injected_learned_base_count := 0;
    single_letter_cap_score := 0;
    single_letter_has_cap := False;
    if (pinyin = '') or not ensure_open then
    begin
        Result := False;
        Exit;
    end;
    canonical_query_key := normalize_canonical_pinyin_key(pinyin);
    if Pos('''', canonical_query_key) > 0 then
    begin
        Exit(lookup_exact_full_pinyin_internal(canonical_query_key, results, True));
    end;
    // Same-process writes clear these caches synchronously. Cross-process
    // updates only need the bounded check performed by ensure_open.
    refresh_user_data_version_if_changed(False);
    query_key := LowerCase(nc_normalize_umlaut_spelling(pinyin));
    if (m_lookup_result_cache <> nil) and
        m_lookup_result_cache.TryGetValue(query_key, results) then
    begin
        results := Copy(results, 0, Length(results));
        if m_debug_mode then
        begin
            m_last_lookup_debug_hint := Format('dict=[lookup_cache=1 n=%d]',
                [Length(results)]);
        end;
        Exit(Length(results) > 0);
    end;
    if (Length(query_key) > 2) and (query_key[Length(query_key)] = 'r') and
        (Copy(query_key, Length(query_key) - 1, 2) <> 'er') then
    begin
        expanded_erhua_query_key := Copy(query_key, 1, Length(query_key) - 1) + #39 + 'er';
        if is_full_pinyin_key(expanded_erhua_query_key) and
            lookup(expanded_erhua_query_key, results) then
        begin
            Exit(True);
        end;
    end;
    now_unix := get_unix_time_now;
    rebuild_query_mode_state;

    // For compact malformed inputs like "chagn", prefer a deterministic
    // adjacent-swap normalization to full pinyin (e.g. "chang") before lookup.
    // Apply this to all non-full queries (not only mixed dangling-initial cases)
    // so common adjacent transposition typos are corrected earlier and stably.
    if not full_pinyin_query then
    begin
        normalized_query_key := normalize_adjacent_swap_to_full_pinyin(query_key);
        if (normalized_query_key <> '') and (not SameText(normalized_query_key, query_key)) then
        begin
            query_key := normalized_query_key;
            rebuild_query_mode_state;
        end;
    end;
    latest_query_choice_text := '';
    if full_pinyin_query then
    begin
        latest_query_choice_text := get_query_latest_choice_text(query_key);
    end;

    single_letter_query := (Length(query_key) = 1) and CharInSet(query_key[1], ['a' .. 'z']);

    if mixed_mode or user_nonfull_lookup then
    begin
        mixed_parser := TncPinyinParser.create;
    end
    else
    begin
        mixed_parser := nil;
    end;

    list := TList<TncCandidate>.Create;
    seen := TDictionary<string, Boolean>.Create;
    candidate_pinyin_map := TDictionary<string, string>.Create;
    candidate_score_cap_map := TDictionary<string, Integer>.Create;
    learning_bonus_map := TDictionary<string, Integer>.Create;
    text_learning_bonus_cache := TDictionary<string, Integer>.Create;
    exact_base_hit := False;
    typo_fallback_used := False;
    try
        if m_user_ready then
        begin
            stmt := nil;
            try
                if m_user_connection.prepare(stats_normalized_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, query_key) and
                    m_user_connection.bind_text(stmt, 2, '''') and
                    m_user_connection.bind_text(stmt, 3, '') then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        stat_pinyin_value := m_user_connection.column_text(stmt, 0);
                        if not same_normalized_pinyin_key(stat_pinyin_value, query_key) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        text_value := user_text_for_script(stat_pinyin_value,
                            m_user_connection.column_text(stmt, 1));
                        commit_count := m_user_connection.column_int(stmt, 2);
                        last_used_value := m_user_connection.column_int(stmt, 3);
                        if full_pinyin_query and
                            (not full_pinyin_text_alignment_valid(query_key,
                            text_value)) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if full_pinyin_query and
                            (get_valid_cjk_codepoint_count(text_value) = 1) and
                            (not single_char_matches_pinyin(query_key, text_value)) then
                        begin
                            Inc(skipped_single_char_mismatch_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if should_suppress_constructed_user_phrase(query_key, text_value, commit_count, 0) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if should_ignore_weak_single_char_query_choice(query_key, text_value, commit_count) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if is_likely_noisy_constructed_phrase(query_key, text_value, commit_count, 0) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        learning_bonus := calc_learning_bonus(commit_count, last_used_value, now_unix);
                        if (text_value <> '') and (learning_bonus > 0) then
                        begin
                            learning_bonus_map.AddOrSetValue(text_value, learning_bonus);
                        end;
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;
        if m_user_ready and full_pinyin_query then
        begin
            stmt := nil;
            try
                if m_user_connection.prepare(user_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, query_key) and
                    m_user_connection.bind_int(stmt, 2, m_limit) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        text_value := user_text_for_script(query_key,
                            m_user_connection.column_text(stmt, 0));
                        last_used_value := m_user_connection.column_int(stmt, 2);
                        if full_pinyin_query and
                            (not full_pinyin_text_alignment_valid(query_key,
                            text_value)) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if full_pinyin_query and
                            (get_valid_cjk_codepoint_count(text_value) = 1) and
                            (not single_char_matches_pinyin(query_key, text_value)) then
                        begin
                            Inc(skipped_single_char_mismatch_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if normalized_base_entry_exists(query_key, text_value) then
                        begin
                            Inc(skipped_base_dup_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        score_value := m_user_connection.column_int(stmt, 1);
                        if is_low_evidence_admin_place_alias_user_entry(query_key,
                            text_value, '', 0, 0) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if should_suppress_constructed_user_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if (last_used_value <= 0) and
                            is_likely_noisy_constructed_phrase(query_key, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        append_candidate(text_value, '', score_value, cs_user, False,
                            0, query_key);
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;

        if user_nonfull_lookup then
        begin
            user_probe_limit := Max(m_limit * 8, m_limit);
            stmt := nil;
            try
                if m_user_connection.prepare(user_nonfull_sql, stmt) and
                    m_user_connection.bind_text(stmt, 1, user_like_pattern) and
                    m_user_connection.bind_int(stmt, 2, user_probe_limit) then
                begin
                    step_result := m_user_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_user_connection.column_text(stmt, 0);
                        if mixed_mode then
                        begin
                            if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_tokens) then
                            begin
                                step_result := m_user_connection.step(stmt);
                                Continue;
                            end;
                        end
                        else if not candidate_matches_any_jianpin_key(mixed_parser, candidate_pinyin,
                            matching_jianpin_query_keys) then
                        begin
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;

                        text_value := user_text_for_script(candidate_pinyin,
                            m_user_connection.column_text(stmt, 1));
                        score_value := m_user_connection.column_int(stmt, 2);
                        last_used_value := m_user_connection.column_int(stmt, 3);
                        if normalized_base_entry_exists(candidate_pinyin, text_value) then
                        begin
                            Inc(skipped_base_dup_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if should_suppress_constructed_user_phrase(candidate_pinyin, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        if (last_used_value <= 0) and
                            is_likely_noisy_constructed_phrase(candidate_pinyin, text_value, 0, score_value) then
                        begin
                            Inc(skipped_noisy_user_count);
                            step_result := m_user_connection.step(stmt);
                            Continue;
                        end;
                        append_candidate(text_value, '', score_value, cs_user, False,
                            0, candidate_pinyin);
                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_user_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_user_connection.finalize(stmt);
                end;
            end;
        end;

        if m_base_ready then
        begin
            if m_stmt_lookup_base = nil then
            begin
                m_base_connection.prepare(base_sql, m_stmt_lookup_base);
            end;
            stmt := m_stmt_lookup_base;
            if (stmt <> nil) and
                m_base_connection.reset(stmt) and
                m_base_connection.clear_bindings(stmt) and
                m_base_connection.bind_text(stmt, 1, base_exact_query_key) and
                m_base_connection.bind_int(stmt, 2, m_limit) then
            begin
                step_result := m_base_connection.step(stmt);
                while step_result = SQLITE_ROW do
                begin
                    candidate_pinyin := m_base_connection.column_text(stmt, 0);
                    if mixed_mode and SameText(candidate_pinyin, query_key) then
                    begin
                        step_result := m_base_connection.step(stmt);
                        Continue;
                    end;

                    if mixed_mode and (not SameText(candidate_pinyin, base_exact_query_key)) and
                        (not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin,
                        mixed_tokens)) then
                    begin
                        step_result := m_base_connection.step(stmt);
                        Continue;
                    end;

                    text_value := m_base_connection.column_text(stmt, 1);
                    if full_pinyin_query and
                        (not strict_full_pinyin_text_alignment_valid(base_exact_query_key,
                        text_value)) then
                    begin
                        step_result := m_base_connection.step(stmt);
                        Continue;
                    end;
                    comment_value := m_base_connection.column_text(stmt, 2);
                    dict_weight_value := m_base_connection.column_int(stmt, 3);
                    score_value := dict_weight_value;
                    if not full_pinyin_query then
                    begin
                        // Non-full exact pinyin rows are often noisy; let jianpin candidates lead.
                        Dec(score_value, c_nonfull_exact_penalty);
                    end;
                    append_candidate(text_value, comment_value, score_value, cs_rule, True,
                        dict_weight_value, candidate_pinyin,
                        IfThen((full_pinyin_query and single_letter_has_cap), single_letter_cap_score, MaxInt));
                    exact_base_hit := True;
                    step_result := m_base_connection.step(stmt);
                end;
            end;

            // Single-syllable full pinyin queries (e.g. "hai") are used by segment fallback;
            // probe extra exact single-char rows so common characters are not dropped by strict LIMIT.
            if single_syllable_full_query then
            begin
                // Keep a wide probe window for one-syllable inputs so common single-char
                // fallbacks (for segment composition) are not starved by phrase-heavy rows.
                single_char_probe_limit := Max(m_limit * 24, 256);
                if single_char_probe_limit > 512 then
                begin
                    single_char_probe_limit := 512;
                end;

                if m_stmt_lookup_single_char_exact = nil then
                begin
                    m_base_connection.prepare(base_single_char_exact_sql,
                        m_stmt_lookup_single_char_exact);
                end;
                stmt := m_stmt_lookup_single_char_exact;
                if (stmt <> nil) and
                    m_base_connection.reset(stmt) and
                    m_base_connection.clear_bindings(stmt) and
                    m_base_connection.bind_text(stmt, 1, query_key) and
                    m_base_connection.bind_int(stmt, 2, single_char_probe_limit) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        text_value := m_base_connection.column_text(stmt, 1);
                        if not strict_full_pinyin_text_alignment_valid(query_key,
                            text_value) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, query_key);
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            end;
        end;

        append_learned_exact_base_candidates;

        if full_query_dual_jianpin_mode and (list.Count > 0) then
        begin
            full_query_dual_jianpin_cap_score := list[0].score - 1;
            for i := 1 to list.Count - 1 do
            begin
                if list[i].score - 1 < full_query_dual_jianpin_cap_score then
                begin
                    full_query_dual_jianpin_cap_score := list[i].score - 1;
                end;
            end;
            full_query_dual_jianpin_has_cap := True;
        end;

        if m_base_ready and should_try_jianpin_lookup(effective_jianpin_key) and
            ((not disable_long_full_query_jianpin) or allow_full_query_jianpin_fallback) and
            ((list.Count = 0) or mixed_mode or (not full_pinyin_query) or
            full_query_dual_jianpin_mode or
            allow_full_query_jianpin_fallback) then
        begin
            typo_fallback_used := append_adjacent_transposition_typo_candidates;
            if (not typo_fallback_used) and mixed_mode and (mixed_full_prefix <> '') then
            begin
                for query_key_idx := 0 to High(jianpin_query_keys) do
                begin
                    if jianpin_query_keys[query_key_idx] = '' then
                    begin
                        Continue;
                    end;
                    if should_skip_deferred_jianpin_variant(effective_jianpin_key,
                        jianpin_query_keys[query_key_idx], list.Count) then
                    begin
                        Continue;
                    end;
                    stmt := nil;
                    try
                        if m_base_connection.prepare(base_jianpin_prefixed_sql, stmt) and
                            m_base_connection.bind_text(stmt, 1, jianpin_query_keys[query_key_idx]) and
                            m_base_connection.bind_int(stmt, 2,
                                get_jianpin_inner_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx], True)) and
                            m_base_connection.bind_text(stmt, 3, mixed_full_prefix + '%') and
                            m_base_connection.bind_int(stmt, 4,
                                get_jianpin_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx])) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            while step_result = SQLITE_ROW do
                            begin
                                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                                if mixed_mode and SameText(candidate_pinyin, query_key) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_tokens) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;
                                if full_pinyin_query and (not full_query_dual_jianpin_mode) and
                                    (not same_normalized_pinyin_key(candidate_pinyin, query_key)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                text_value := m_base_connection.column_text(stmt, 1);
                                if full_pinyin_query and (not full_query_dual_jianpin_mode) and
                                    (not strict_full_pinyin_text_alignment_valid(
                                    query_key, text_value)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;
                                comment_value := m_base_connection.column_text(stmt, 2);
                                dict_weight_value := m_base_connection.column_int(stmt, 3);
                                score_value := dict_weight_value - jianpin_score_penalty;
                                if full_query_dual_jianpin_mode and
                                    (not SameText(Trim(candidate_pinyin), base_exact_query_key)) then
                                begin
                                    Dec(score_value, c_full_query_dual_jianpin_penalty);
                                    if full_query_dual_jianpin_has_cap and
                                        (score_value > full_query_dual_jianpin_cap_score) then
                                    begin
                                        score_value := full_query_dual_jianpin_cap_score;
                                    end;
                                end;
                                append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                    dict_weight_value, candidate_pinyin);
                                step_result := m_base_connection.step(stmt);
                            end;
                        end;
                    finally
                        if stmt <> nil then
                        begin
                            m_base_connection.finalize(stmt);
                        end;
                    end;
                end;
            end;

            if (not typo_fallback_used) and ((list.Count = 0) or (not full_pinyin_query) or
                allow_full_query_jianpin_fallback) then
            begin
                for query_key_idx := 0 to High(jianpin_query_keys) do
                begin
                    if jianpin_query_keys[query_key_idx] = '' then
                    begin
                        Continue;
                    end;
                    if should_skip_deferred_jianpin_variant(effective_jianpin_key,
                        jianpin_query_keys[query_key_idx], list.Count) then
                    begin
                        Continue;
                    end;
                    stmt := nil;
                    try
                        if m_base_connection.prepare(base_jianpin_sql, stmt) and
                            m_base_connection.bind_text(stmt, 1, jianpin_query_keys[query_key_idx]) and
                            m_base_connection.bind_int(stmt, 2,
                                get_jianpin_inner_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx], False)) and
                            m_base_connection.bind_int(stmt, 3,
                                get_jianpin_probe_limit_for_key(effective_jianpin_key,
                                    jianpin_query_keys[query_key_idx])) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            while step_result = SQLITE_ROW do
                            begin
                                candidate_pinyin := m_base_connection.column_text(stmt, 0);
                                if mixed_mode and SameText(candidate_pinyin, query_key) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                if mixed_mode and (not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin,
                                    mixed_tokens)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;
                                if full_pinyin_query and (not full_query_dual_jianpin_mode) and
                                    (not same_normalized_pinyin_key(candidate_pinyin, query_key)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;

                                text_value := m_base_connection.column_text(stmt, 1);
                                if full_pinyin_query and (not full_query_dual_jianpin_mode) and
                                    (not strict_full_pinyin_text_alignment_valid(
                                    query_key, text_value)) then
                                begin
                                    step_result := m_base_connection.step(stmt);
                                    Continue;
                                end;
                                comment_value := m_base_connection.column_text(stmt, 2);
                                dict_weight_value := m_base_connection.column_int(stmt, 3);
                                score_value := dict_weight_value - jianpin_score_penalty;
                                if full_query_dual_jianpin_mode and
                                    (not SameText(Trim(candidate_pinyin), base_exact_query_key)) then
                                begin
                                    Dec(score_value, c_full_query_dual_jianpin_penalty);
                                    if full_query_dual_jianpin_has_cap and
                                        (score_value > full_query_dual_jianpin_cap_score) then
                                    begin
                                        score_value := full_query_dual_jianpin_cap_score;
                                    end;
                                end;
                                append_candidate(text_value, comment_value, score_value, cs_rule, True,
                                    dict_weight_value, candidate_pinyin);
                                step_result := m_base_connection.step(stmt);
                            end;
                        end;
                    finally
                        if stmt <> nil then
                        begin
                            m_base_connection.finalize(stmt);
                        end;
                    end;
                end;
            end;
        end;

        if (not typo_fallback_used) and mixed_mode and m_base_ready and (mixed_like_pattern <> '') and
            (list.Count < m_limit) then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_mixed_pattern_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, mixed_like_pattern) and
                    m_base_connection.bind_int(stmt, 2, m_limit) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        if mixed_mode and SameText(candidate_pinyin, query_key) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        if not candidate_matches_mixed_jianpin(mixed_parser, candidate_pinyin, mixed_tokens) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - jianpin_score_penalty;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin);
                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        // Single-letter queries should still surface useful single-character candidates.
        // For full one-syllable queries (e.g. "e"), keep exact pinyin candidates ahead.
        if m_base_ready and single_letter_query and (list.Count < m_limit) then
        begin
            single_letter_cap_score := 0;
            single_letter_has_cap := False;
            if full_pinyin_query and (list.Count > 0) then
            begin
                single_letter_cap_score := list[0].score - c_single_letter_full_query_cap_margin;
                for i := 1 to list.Count - 1 do
                begin
                    if list[i].score - c_single_letter_full_query_cap_margin < single_letter_cap_score then
                    begin
                        single_letter_cap_score := list[i].score - c_single_letter_full_query_cap_margin;
                    end;
                end;
                single_letter_has_cap := True;
            end;

            stmt := nil;
            try
                if m_base_connection.prepare(base_initial_single_char_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, query_key + '%') and
                    m_base_connection.bind_int(stmt, 2, Min(24, m_limit)) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        if full_pinyin_query and SameText(candidate_pinyin, query_key) then
                        begin
                            step_result := m_base_connection.step(stmt);
                            Continue;
                        end;

                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - c_initial_single_char_penalty;
                        if full_pinyin_query then
                        begin
                            Dec(score_value, c_single_letter_full_query_extra_penalty);
                            if single_letter_has_cap and (score_value > single_letter_cap_score) then
                            begin
                                score_value := single_letter_cap_score;
                            end;
                        end;

                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin);
                        if full_pinyin_query and single_letter_has_cap then
                        begin
                            single_letter_cap_score := (single_letter_cap_score - 1);
                        end;

                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        // For mixed inputs like "hha", mainstream IMEs still show high-frequency
        // single-character candidates under the leading initial.
        if mixed_mode and m_base_ready and (Length(mixed_tokens) > 0) and
            (mixed_tokens[0].kind = mqt_initial) and (list.Count < m_limit) then
        begin
            stmt := nil;
            try
                if m_base_connection.prepare(base_initial_single_char_sql, stmt) and
                    m_base_connection.bind_text(stmt, 1, mixed_tokens[0].text + '%') and
                    m_base_connection.bind_int(stmt, 2, Min(24, m_limit)) then
                begin
                    step_result := m_base_connection.step(stmt);
                    while step_result = SQLITE_ROW do
                    begin
                        candidate_pinyin := m_base_connection.column_text(stmt, 0);
                        text_value := m_base_connection.column_text(stmt, 1);
                        comment_value := m_base_connection.column_text(stmt, 2);
                        dict_weight_value := m_base_connection.column_int(stmt, 3);
                        score_value := dict_weight_value - c_initial_single_char_penalty;
                        append_candidate(text_value, comment_value, score_value, cs_rule, True,
                            dict_weight_value, candidate_pinyin);
                        if list.Count >= m_limit then
                        begin
                            Break;
                        end;
                        step_result := m_base_connection.step(stmt);
                    end;
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.finalize(stmt);
                end;
            end;
        end;

        apply_short_jianpin_commonness_rerank;

        if c_enable_runtime_homophone_bonus then
        begin
            apply_homophone_commonness_bonus;
        end;

        apply_text_learning_bonus;
        apply_short_full_pinyin_commonness_tiebreak;
        apply_single_letter_full_query_spoken_bonus;
        enforce_single_letter_exact_group_priority;
        apply_candidate_score_caps;
        sort_candidate_list_by_score;

        if list.Count > 0 then
        begin
            SetLength(results, list.Count);
            for i := 0 to list.Count - 1 do
            begin
                results[i] := list[i];
            end;
        end;

        if m_debug_mode then
        begin
            m_last_lookup_debug_hint := Format(
                'dict=[full=%d mixed=%d user_nf=%d exact=%d typo=%d dual_jp=%d long_jp_off=%d learn=%d text=%d sc_bad=%d noise=%d dup=%d inj=%d n=%d]',
                [Ord(full_pinyin_query), Ord(mixed_mode), Ord(user_nonfull_lookup), Ord(exact_base_hit),
                Ord(typo_fallback_used), Ord(full_query_dual_jianpin_mode),
                Ord(disable_long_full_query_jianpin), applied_learning_bonus_count,
                applied_text_learning_bonus_count, skipped_single_char_mismatch_count,
                skipped_noisy_user_count, skipped_base_dup_user_count,
                injected_learned_base_count, list.Count]);
        end
        else
        begin
            m_last_lookup_debug_hint := '';
        end;
        Result := list.Count > 0;
    finally
        if mixed_parser <> nil then
        begin
            mixed_parser.Free;
        end;
        candidate_score_cap_map.Free;
        candidate_pinyin_map.Free;
        text_learning_bonus_cache.Free;
        learning_bonus_map.Free;
        list.Free;
        seen.Free;
    end;
    if m_lookup_result_cache <> nil then
    begin
        while m_lookup_result_cache.Count >= c_result_cache_limit do
        begin
            if (m_lookup_result_cache_order = nil) or
                (m_lookup_result_cache_order.Count = 0) then
            begin
                m_lookup_result_cache.Clear;
                Break;
            end;
            evicted_cache_key := m_lookup_result_cache_order.Dequeue;
            m_lookup_result_cache.Remove(evicted_cache_key);
        end;
        m_lookup_result_cache.AddOrSetValue(LowerCase(pinyin),
            Copy(results, 0, Length(results)));
        if m_lookup_result_cache_order <> nil then
        begin
            m_lookup_result_cache_order.Enqueue(LowerCase(pinyin));
        end;
    end;
end;

function TncSqliteDictionary.single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean;
var
    pinyin_key: string;
    text_key: string;
begin
    Result := False;
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text_unit);
    if (pinyin_key = '') or (text_key = '') then
    begin
        Exit;
    end;
    if not is_full_pinyin_key(pinyin_key) then
    begin
        Exit;
    end;
    if get_valid_cjk_codepoint_count(text_key) <> 1 then
    begin
        Exit;
    end;
    if (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    // Reuse the same normalized base-entry check as phrase validation. Some
    // single characters participate in exact lookup/ranking through normalized
    // pinyin aliases or merged lexicon rows, so an exact dict_base(pinyin,text)
    // probe is too narrow and can wrongly purge valid learned selections such
    // as "ci -> 词" across host restarts.
    Result := normalized_base_entry_exists(pinyin_key, text_key);
end;

procedure TncSqliteDictionary.prune_suspicious_user_entries;
const
    select_entries_sql =
        'SELECT pinyin, text, MAX(user_weight), MAX(commit_count), MAX(last_used) FROM (' +
        'SELECT pinyin, text, weight AS user_weight, 0 AS commit_count, last_used FROM dict_user ' +
        'UNION ALL ' +
        'SELECT pinyin, text, 0 AS user_weight, commit_count, last_used FROM dict_user_stats' +
        ') GROUP BY pinyin, text';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    pinyin_value: string;
    text_value: string;
    text_unit_count: Integer;
    user_weight: Integer;
    commit_count: Integer;
    last_used_value: Int64;

    procedure delete_explicit_user_entry_only(const local_pinyin: string; const local_text: string);
    var
        local_stmt: Psqlite3_stmt;
    begin
        if (local_pinyin = '') or (local_text = '') or (m_user_connection = nil) then
        begin
            Exit;
        end;

        local_stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, local_stmt) and
                m_user_connection.bind_text(local_stmt, 1, local_pinyin) and
                m_user_connection.bind_text(local_stmt, 2, local_text) then
            begin
                m_user_connection.step(local_stmt);
            end;
        finally
            if local_stmt <> nil then
            begin
                m_user_connection.finalize(local_stmt);
            end;
        end;
    end;
begin
    if not m_user_ready then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if not m_user_connection.prepare(select_entries_sql, stmt) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            pinyin_value := m_user_connection.column_text(stmt, 0);
            text_value := m_user_connection.column_text(stmt, 1);
            user_weight := m_user_connection.column_int(stmt, 2);
            commit_count := m_user_connection.column_int(stmt, 3);
            last_used_value := m_user_connection.column_int(stmt, 4);
            if user_text_for_script(pinyin_value, text_value) <> text_value then
            begin
                // A shared entry written in the other script is not invalid
                // just because this base dictionary uses different glyphs.
                step_result := m_user_connection.step(stmt);
                Continue;
            end;
            text_unit_count := get_valid_cjk_codepoint_count(text_value);

            if (pinyin_value <> '') and is_full_pinyin_key(pinyin_value) and
                (not full_pinyin_text_alignment_valid(pinyin_value, text_value)) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, False);
            end
            else if (pinyin_value <> '') and (text_unit_count = 1) and is_full_pinyin_key(pinyin_value) and
                (not single_char_matches_pinyin(pinyin_value, text_value)) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, False);
            end
            else if (last_used_value <= 0) and
                should_suppress_exact_query_learning(pinyin_value, text_value) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, False);
            end
            else if is_low_evidence_admin_place_alias_user_entry(pinyin_value,
                text_value, '', 0, 0) then
            begin
                // Keep stats/latest learning, but do not expose derived place
                // aliases such as "jintian -> 金田" as removable user words.
                delete_explicit_user_entry_only(pinyin_value, text_value);
            end
            else if should_suppress_constructed_user_phrase(pinyin_value, text_value,
                commit_count, user_weight) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, False);
            end
            else if (last_used_value <= 0) and
                is_likely_noisy_constructed_phrase(pinyin_value, text_value, commit_count, user_weight) then
            begin
                purge_user_entry_internal(pinyin_value, text_value, False, True);
            end;

            step_result := m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

procedure TncSqliteDictionary.record_commit(const pinyin: string; const text: string;
    const explicit_choice: Boolean = False);
const
    update_stats_sql = 'UPDATE dict_user_stats SET commit_count = commit_count + 1, ' +
        'last_used = strftime(''%s'',''now'') WHERE pinyin = ?1 AND text = ?2';
    insert_stats_sql = 'INSERT OR IGNORE INTO dict_user_stats(pinyin, text, commit_count, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
    update_latest_sql = 'UPDATE dict_user_query_latest SET text = ?2, ' +
        'last_used = strftime(''%s'',''now'') WHERE query_pinyin = ?1';
    insert_latest_sql = 'INSERT OR IGNORE INTO dict_user_query_latest(query_pinyin, text, last_used) ' +
        'VALUES (?1, ?2, strftime(''%s'',''now''))';
    update_sql = 'UPDATE dict_user SET weight = weight + 1, last_used = strftime(''%s'',''now'') ' +
        'WHERE pinyin = ?1 AND text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user(pinyin, text, weight, last_used) ' +
        'VALUES (?1, ?2, 1, strftime(''%s'',''now''))';
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
    delete_penalty_sql = 'DELETE FROM dict_user_penalty WHERE pinyin = ?1 AND text = ?2';
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    inferred_pinyin_key: string;
    full_pinyin_input: Boolean;
    invalid_full_pinyin_alignment: Boolean;
    base_entry_exists: Boolean;
    suppress_exact_query_user_row: Boolean;
    suppress_structured_rule_phrase_user_row: Boolean;
    suppress_admin_alias_user_row: Boolean;
    existing_user_entry: Boolean;
    stored_user_text: string;
    stored_stats_text: string;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    if (pinyin_key = '') or (text = '') or (not is_valid_learning_text(text)) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;
    if is_literal_user_entry(pinyin_key, text) then
    begin
        // Literal shorthand words are immutable vocabulary entries. Selecting
        // one must not create heat, latest-choice, context, or path signals.
        Exit;
    end;
    clear_user_read_caches;

    full_pinyin_input := is_full_pinyin_key(pinyin_key);
    if (not full_pinyin_input) and
        try_get_single_char_full_pinyin_for_prefix(pinyin_key, text, inferred_pinyin_key) then
    begin
        pinyin_key := inferred_pinyin_key;
        full_pinyin_input := True;
    end;
    invalid_full_pinyin_alignment := full_pinyin_input and
        (not full_pinyin_text_alignment_valid(pinyin_key, text));
    if invalid_full_pinyin_alignment then
    begin
        purge_user_entry_internal(pinyin_key, text, False, False);
        Exit;
    end;
    if full_pinyin_input and (get_valid_cjk_codepoint_count(text) = 1) and
        (not single_char_matches_pinyin(pinyin_key, text)) then
    begin
        // Ignore invalid single-char learning, but do not erase any existing
        // persisted choice here. Runtime lookup already filters mismatched
        // single-char rows, so destructive purge is unnecessary.
        Exit;
    end;

    base_entry_exists := normalized_base_entry_exists(pinyin_key, text);
    existing_user_entry := is_valid_user_text(text) and
        explicit_user_entry_exists(pinyin_key, text);
    suppress_structured_rule_phrase_user_row := full_pinyin_input and
        is_nonbase_structured_rule_exact_phrase(pinyin_key, text);
    suppress_admin_alias_user_row := full_pinyin_input and
        is_low_evidence_admin_place_alias_user_entry(pinyin_key, text, '', 0, 0);
    suppress_exact_query_user_row := invalid_full_pinyin_alignment or
        suppress_structured_rule_phrase_user_row or
        suppress_admin_alias_user_row or
        (full_pinyin_input and (not explicit_choice) and
        (not existing_user_entry) and
        should_suppress_exact_query_learning(pinyin_key, text));

    // A positive explicit selection for the same query/text pair should
    // cancel any earlier "remove candidate" feedback for that exact pair.
    stored_user_text := user_storage_text('dict_user', pinyin_key, text);
    stored_stats_text := user_storage_text('dict_user_stats', pinyin_key, text);
    stmt := nil;
    try
        if m_user_connection.prepare(delete_penalty_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_stats_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, stored_stats_text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_stats_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, stored_stats_text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_latest_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_latest_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    if (not is_valid_user_text(text)) or suppress_exact_query_user_row then
    begin
        // Keep query-level learning, but do not persist single chars or
        // automatic composed-query confirmations as standalone user words.
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) then
            begin
                if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, stored_user_text) then
                begin
                    m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
        note_user_data_changed;
        Exit;
    end;

    if not full_pinyin_input then
    begin
        // Keep stats learning, but do not keep dedicated user-word rows for
        // non-full-pinyin commits.
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) then
            begin
                if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, stored_user_text) then
                begin
                    m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
        note_user_data_changed;
        Exit;
    end;

    if base_entry_exists then
    begin
        // Base-dictionary entries should learn through stats-driven re-ranking,
        // not by duplicating the same entry into dict_user.
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) then
            begin
                if m_user_connection.bind_text(stmt, 1, pinyin_key) and
                    m_user_connection.bind_text(stmt, 2, stored_user_text) then
                begin
                    m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
        note_user_data_changed;
        Exit;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, stored_user_text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_sql, stmt) then
        begin
            if m_user_connection.bind_text(stmt, 1, pinyin_key) and m_user_connection.bind_text(stmt, 2, stored_user_text) then
            begin
                m_user_connection.step(stmt);
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
    note_user_data_changed;
end;

procedure TncSqliteDictionary.record_context_pair(const left_text: string; const committed_text: string);
begin
    // Persistent context learning is disabled; only explicit pinyin->text
    // vocabulary choices are written to the user dictionary.
end;

procedure TncSqliteDictionary.record_context_trigram(const prev_prev_text: string; const prev_text: string;
    const committed_text: string);
begin
    // Persistent context learning is disabled.
end;

procedure TncSqliteDictionary.record_context_query_choice(
    const context_suffix: string; const query_key: string;
    const candidate_text: string);
const
    insert_sql =
        'INSERT OR IGNORE INTO dict_user_context_query_choice' +
        '(context_suffix, query_pinyin, text, commit_count, last_used) ' +
        'VALUES(?1, ?2, ?3, 0, strftime(''%s'',''now''))';
    update_sql =
        'UPDATE dict_user_context_query_choice SET ' +
        'commit_count = MIN(commit_count + 1, 255), ' +
        'last_used = strftime(''%s'',''now'') ' +
        'WHERE context_suffix = ?1 AND query_pinyin = ?2 AND text = ?3';
var
    context_value: string;
    normalized_query: string;
    text_value: string;
    stmt: Psqlite3_stmt;

    function execute_statement(const sql_text: string): Boolean;
    begin
        Result := False;
        stmt := nil;
        try
            if (not m_user_connection.prepare(sql_text, stmt)) or
                (not m_user_connection.bind_text(stmt, 1, context_value)) or
                (not m_user_connection.bind_text(stmt, 2, normalized_query)) or
                (not m_user_connection.bind_text(stmt, 3, text_value)) then
            begin
                Exit;
            end;
            Result := m_user_connection.step(stmt) = SQLITE_DONE;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
begin
    context_value := Trim(context_suffix);
    normalized_query := LowerCase(Trim(query_key));
    text_value := Trim(candidate_text);
    if (context_value = '') or (Length(context_value) > 12) or
        (normalized_query = '') or (text_value = '') or
        (not is_valid_learning_text(text_value)) or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if execute_statement(insert_sql) and execute_statement(update_sql) then
    begin
        if m_context_query_choice_bonus_cache <> nil then
        begin
            m_context_query_choice_bonus_cache.Clear;
        end;
        prune_context_query_choice_rows_if_needed(False);
        note_user_data_changed;
    end;
end;

procedure TncSqliteDictionary.record_query_segment_path(const query_key: string; const encoded_path: string);
begin
    // User query-path persistence is disabled; base query paths can still
    // contribute through get_query_segment_path_bonus.
end;

procedure TncSqliteDictionary.record_query_segment_path_penalty(const query_key: string;
    const encoded_path: string);
const
    update_sql = 'UPDATE dict_user_query_path_penalty SET penalty = MIN(penalty + ?3, ?4), ' +
        'last_used = strftime(''%s'',''now'') WHERE query_pinyin = ?1 AND path_text = ?2';
    insert_sql = 'INSERT OR IGNORE INTO dict_user_query_path_penalty(query_pinyin, path_text, penalty, last_used) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
    c_penalty_step = 96;
    c_penalty_max = 480;
var
    stmt: Psqlite3_stmt;
    normalized_query: string;
    normalized_path: string;
begin
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not is_valid_learning_path(normalized_path)) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_query_path_penalty_cache <> nil then
    begin
        m_query_path_penalty_cache.Clear;
    end;
    stmt := nil;
    try
        if m_user_connection.prepare(update_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, normalized_query) and
            m_user_connection.bind_text(stmt, 2, normalized_path) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) and
            m_user_connection.bind_int(stmt, 4, c_penalty_max) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, normalized_query) and
            m_user_connection.bind_text(stmt, 2, normalized_path) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    prune_query_path_penalty_rows_if_needed(False);
end;

function TncSqliteDictionary.get_context_bonus(const left_text: string; const candidate_text: string): Integer;
begin
    Result := 0;
end;

function TncSqliteDictionary.get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
    const candidate_text: string): Integer;
begin
    Result := 0;
end;

function TncSqliteDictionary.get_context_query_choice_bonus(
    const context_suffix: string; const query_key: string;
    const candidate_text: string): Integer;
const
    query_sql =
        'SELECT commit_count, last_used FROM dict_user_context_query_choice ' +
        'WHERE context_suffix = ?1 AND query_pinyin = ?2 AND text = ?3 LIMIT 1';
    c_day_seconds = 24 * 60 * 60;
    c_week_seconds = 7 * c_day_seconds;
    c_month_seconds = 30 * c_day_seconds;
    c_expiry_seconds = 90 * c_day_seconds;
var
    context_value: string;
    normalized_query: string;
    text_value: string;
    cache_key: string;
    step_result: Integer;
    commit_count: Integer;
    last_used: Int64;
    now_value: Int64;
    age_seconds: Int64;
begin
    Result := 0;
    context_value := Trim(context_suffix);
    normalized_query := LowerCase(Trim(query_key));
    text_value := Trim(candidate_text);
    if (context_value = '') or (Length(context_value) > 12) or
        (normalized_query = '') or (text_value = '') or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);

    cache_key := context_value + #2 + normalized_query + #1 + text_value;
    if (m_context_query_choice_bonus_cache <> nil) and
        m_context_query_choice_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if m_stmt_context_query_choice_bonus = nil then
        begin
            if not m_user_connection.prepare(query_sql,
                m_stmt_context_query_choice_bonus) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_context_query_choice_bonus)) or
            (not m_user_connection.clear_bindings(
            m_stmt_context_query_choice_bonus)) or
            (not m_user_connection.bind_text(m_stmt_context_query_choice_bonus,
            1, context_value)) or
            (not m_user_connection.bind_text(m_stmt_context_query_choice_bonus,
            2, normalized_query)) or
            (not m_user_connection.bind_text(m_stmt_context_query_choice_bonus,
            3, text_value)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(
            m_stmt_context_query_choice_bonus);
        if step_result <> SQLITE_ROW then
        begin
            Exit;
        end;
        commit_count := m_user_connection.column_int(
            m_stmt_context_query_choice_bonus, 0);
        last_used := m_user_connection.column_int(
            m_stmt_context_query_choice_bonus, 1);
        if commit_count > 0 then
        begin
            Result := 72 + (Min(commit_count, 8) - 1) * 46;
            now_value := get_unix_time_now;
            if (last_used > 0) and (now_value > 0) then
            begin
                age_seconds := Max(Int64(0), now_value - last_used);
                if age_seconds > c_expiry_seconds then
                begin
                    Result := 0;
                end
                else if age_seconds > c_month_seconds then
                begin
                    Result := Result div 4;
                end
                else if age_seconds > c_week_seconds then
                begin
                    Result := Result div 2;
                end
                else if age_seconds > c_day_seconds then
                begin
                    Result := (Result * 3) div 4;
                end;
            end;
            if Result > 420 then
            begin
                Result := 420;
            end;
        end;
    finally
        if m_stmt_context_query_choice_bonus <> nil then
        begin
            m_user_connection.reset(m_stmt_context_query_choice_bonus);
            m_user_connection.clear_bindings(m_stmt_context_query_choice_bonus);
        end;
    end;

    if m_context_query_choice_bonus_cache <> nil then
    begin
        m_context_query_choice_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_query_choice_bonus(const query_key: string;
    const candidate_text: string): Integer;
const
    query_sql = 'SELECT commit_count, last_used FROM dict_user_stats WHERE pinyin = ?1 AND text = ?2 LIMIT 1';
    c_single_query_base = 44;
    c_single_query_step = 34;
    c_single_query_cap = 520;
    c_multi_query_base = 96;
    c_multi_query_step = 56;
    c_multi_query_cap = 640;
    c_latest_query_choice_bonus = 1800;
    c_recent_bonus_1d = 220;
    c_recent_bonus_3d = 120;
    c_recent_bonus_7d = 64;
    c_recent_bonus_30d = 28;
    c_sec_per_day = 24 * 60 * 60;
    c_sec_per_3_days = 3 * c_sec_per_day;
    c_sec_per_week = 7 * c_sec_per_day;
    c_sec_per_30_days = 30 * c_sec_per_day;
var
    step_result: Integer;
    normalized_query: string;
    text_key: string;
    cache_key: string;
    commit_count: Integer;
    last_used_unix: Int64;
    units: Integer;
    now_unix: Int64;
    age_seconds: Int64;
    recent_bonus: Integer;
    session_like_bonus: Integer;
    learning_floor_bonus: Integer;
    latest_choice_text: string;
    latest_bonus: Integer;
    has_latest_choice_match: Boolean;
begin
    Result := 0;
    normalized_query := LowerCase(Trim(query_key));
    text_key := Trim(candidate_text);
    if (normalized_query = '') or (text_key = '') or (not ensure_open) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);

    cache_key := normalized_query + #1 + text_key;
    if (m_query_choice_bonus_cache <> nil) and m_query_choice_bonus_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    if get_candidate_penalty(normalized_query, text_key) > 0 then
    begin
        Exit;
    end;
    if is_full_pinyin_key(normalized_query) and
        (get_valid_cjk_codepoint_count(text_key) = 1) and
        (not full_pinyin_text_alignment_valid(normalized_query, text_key)) then
    begin
        Exit;
    end;

    latest_bonus := 0;
    has_latest_choice_match := False;
    latest_choice_text := get_query_latest_choice_text(normalized_query);
    if (latest_choice_text <> '') and SameText(latest_choice_text, text_key) then
    begin
        has_latest_choice_match := True;
        latest_bonus := c_latest_query_choice_bonus;
    end;

    try
        if m_stmt_query_choice_bonus = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_query_choice_bonus) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_choice_bonus)) or
            (not m_user_connection.clear_bindings(m_stmt_query_choice_bonus)) or
            (not m_user_connection.bind_text(m_stmt_query_choice_bonus, 1, normalized_query)) or
            (not m_user_connection.bind_text(m_stmt_query_choice_bonus, 2,
            user_storage_text('dict_user_stats', normalized_query, text_key))) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_query_choice_bonus);
        if step_result <> SQLITE_ROW then
        begin
            // Latest explicit exact-query choice must work even when the stats
            // row is missing, otherwise single-character learning can disappear
            // on restart. When a stats row exists, use its decayed score instead
            // so stale one-off choices do not permanently override base entries.
            if has_latest_choice_match and
                (not should_ignore_weak_single_char_query_choice(normalized_query,
                text_key, 0)) then
            begin
                Result := latest_bonus;
            end;
            Exit;
        end;

        commit_count := m_user_connection.column_int(m_stmt_query_choice_bonus, 0);
        if commit_count <= 0 then
        begin
            Exit;
        end;
        if should_ignore_weak_single_char_query_choice(normalized_query, text_key, commit_count) then
        begin
            Exit;
        end;

        if should_suppress_exact_query_learning(normalized_query, text_key) and
            (not explicit_user_entry_exists(normalized_query, text_key)) then
        begin
            Exit;
        end;

        if should_suppress_constructed_user_phrase(normalized_query, text_key, commit_count, 0) and
            (not explicit_user_entry_exists(normalized_query, text_key)) then
        begin
            Exit;
        end;

        last_used_unix := m_user_connection.column_int(m_stmt_query_choice_bonus, 1);
        now_unix := get_unix_time_now;
        recent_bonus := 0;
        if (last_used_unix > 0) and (now_unix > 0) then
        begin
            age_seconds := now_unix - last_used_unix;
            if age_seconds < 0 then
            begin
                age_seconds := 0;
            end;

            if age_seconds <= c_sec_per_day then
            begin
                recent_bonus := c_recent_bonus_1d;
            end
            else if age_seconds <= c_sec_per_3_days then
            begin
                recent_bonus := c_recent_bonus_3d;
            end
            else if age_seconds <= c_sec_per_week then
            begin
                recent_bonus := c_recent_bonus_7d;
            end
            else if age_seconds <= c_sec_per_30_days then
            begin
                recent_bonus := c_recent_bonus_30d;
            end;
        end;

        units := get_valid_cjk_codepoint_count(text_key);
        if units <= 1 then
        begin
            session_like_bonus := c_single_query_base + ((commit_count - 1) * c_single_query_step) +
                recent_bonus;
            if commit_count >= 2 then
            begin
                Inc(session_like_bonus, 18);
            end;
            if commit_count >= 4 then
            begin
                Inc(session_like_bonus, 28);
            end;
            learning_floor_bonus := calc_learning_bonus(commit_count, last_used_unix, now_unix) div 2;
            Result := Max(session_like_bonus, learning_floor_bonus);
            if Result > c_single_query_cap then
            begin
                Result := c_single_query_cap;
            end;
        end
        else
        begin
            session_like_bonus := c_multi_query_base + ((commit_count - 1) * c_multi_query_step) +
                recent_bonus;
            if (commit_count >= 2) and (recent_bonus >= c_recent_bonus_3d) then
            begin
                Inc(session_like_bonus, 56);
            end;
            if (commit_count >= 3) and (recent_bonus >= c_recent_bonus_7d) then
            begin
                Inc(session_like_bonus, 32);
            end;
            learning_floor_bonus := calc_learning_bonus(commit_count, last_used_unix, now_unix) div 3;
            Result := Max(session_like_bonus, learning_floor_bonus);
            if Result > c_multi_query_cap then
            begin
                Result := c_multi_query_cap;
            end;
        end;

        if Result < 0 then
        begin
            Result := 0;
        end;

        // Do not add latest_bonus on top of a stats-backed score here. Exact
        // lookup applies an additional latest-choice promotion only while the
        // decayed stats score is still recent enough.
    finally
        if m_stmt_query_choice_bonus <> nil then
        begin
            m_user_connection.reset(m_stmt_query_choice_bonus);
            m_user_connection.clear_bindings(m_stmt_query_choice_bonus);
        end;
    end;

    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.AddOrSetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_query_latest_choice_text(const query_key: string): string;
const
    query_sql =
        'SELECT l.text, l.last_used, COALESCE(s.commit_count, 0) ' +
        'FROM dict_user_query_latest l ' +
        'LEFT JOIN dict_user_stats s ON s.pinyin = l.query_pinyin AND s.text = l.text ' +
        'WHERE l.query_pinyin = ?1 LIMIT 1';
    fallback_query_sql =
        'SELECT text, commit_count, last_used FROM dict_user_stats ' +
        'WHERE pinyin = ?1 ORDER BY last_used DESC, commit_count DESC LIMIT 16';
    c_sec_per_180_days = 180 * 24 * 60 * 60;
var
    normalized_query: string;
    step_result: Integer;
    stmt: Psqlite3_stmt;
    candidate_text: string;
    last_used_unix: Int64;
    now_unix: Int64;
    age_seconds: Int64;
    use_fallback_scan: Boolean;
    commit_count: Integer;
begin
    Result := '';
    normalized_query := LowerCase(Trim(query_key));
    if (normalized_query = '') or (not ensure_open) or (not m_user_ready) or
        (m_user_connection = nil) then
    begin
        Exit;
    end;
    refresh_user_data_version_if_changed(False);

    if (m_query_latest_choice_text_cache <> nil) and
        m_query_latest_choice_text_cache.TryGetValue(normalized_query, Result) then
    begin
        Exit;
    end;

    use_fallback_scan := False;

    try
        if m_stmt_query_latest_choice_text = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_query_latest_choice_text) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_latest_choice_text)) or
            (not m_user_connection.clear_bindings(m_stmt_query_latest_choice_text)) or
            (not m_user_connection.bind_text(m_stmt_query_latest_choice_text, 1, normalized_query)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_query_latest_choice_text);
        if step_result <> SQLITE_ROW then
        begin
            use_fallback_scan := True;
        end;
        if not use_fallback_scan then
        begin
            candidate_text := user_text_for_script(normalized_query,
                Trim(m_user_connection.column_text(m_stmt_query_latest_choice_text, 0)));
            last_used_unix := m_user_connection.column_int(m_stmt_query_latest_choice_text, 1);
            commit_count := m_user_connection.column_int(m_stmt_query_latest_choice_text, 2);
            if last_used_unix > 0 then
            begin
                now_unix := get_unix_time_now;
                if now_unix > 0 then
                begin
                    age_seconds := now_unix - last_used_unix;
                    if age_seconds < 0 then
                    begin
                        age_seconds := 0;
                    end;
                    if age_seconds > c_sec_per_180_days then
                    begin
                        use_fallback_scan := True;
                    end;
                end;
            end;

            if (not use_fallback_scan) and
                ((candidate_text = '') or
                (is_full_pinyin_key(normalized_query) and
                (not full_pinyin_text_alignment_valid(normalized_query,
                candidate_text))) or
                (get_candidate_penalty(normalized_query, candidate_text) > 0)) then
            begin
                use_fallback_scan := True;
            end;

            if (not use_fallback_scan) and
                should_ignore_weak_single_char_query_choice(normalized_query,
                candidate_text, commit_count) then
            begin
                use_fallback_scan := True;
            end;

            if not use_fallback_scan then
            begin
                Result := candidate_text;
            end;
        end;
    finally
        if m_stmt_query_latest_choice_text <> nil then
        begin
            m_user_connection.reset(m_stmt_query_latest_choice_text);
            m_user_connection.clear_bindings(m_stmt_query_latest_choice_text);
        end;
    end;

    if use_fallback_scan then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(fallback_query_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, normalized_query) then
            begin
                step_result := m_user_connection.step(stmt);
                while step_result = SQLITE_ROW do
                begin
                    candidate_text := user_text_for_script(normalized_query,
                        Trim(m_user_connection.column_text(stmt, 0)));
                    if candidate_text <> '' then
                    begin
                        commit_count := m_user_connection.column_int(stmt, 1);
                        last_used_unix := m_user_connection.column_int(stmt, 2);
                        if last_used_unix > 0 then
                        begin
                            now_unix := get_unix_time_now;
                            if now_unix > 0 then
                            begin
                                age_seconds := now_unix - last_used_unix;
                                if age_seconds < 0 then
                                begin
                                    age_seconds := 0;
                                end;
                                if age_seconds > c_sec_per_180_days then
                                begin
                                    Break;
                                end;
                            end;
                        end;

                        if ((not is_full_pinyin_key(normalized_query)) or
                            full_pinyin_text_alignment_valid(normalized_query,
                            candidate_text)) and
                            (get_candidate_penalty(normalized_query,
                            candidate_text) <= 0) and
                            (not should_ignore_weak_single_char_query_choice(
                            normalized_query, candidate_text, commit_count)) then
                        begin
                            Result := candidate_text;
                            Break;
                        end;
                    end;
                    step_result := m_user_connection.step(stmt);
                end;
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.AddOrSetValue(normalized_query, Result);
    end;
end;

function TncSqliteDictionary.get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer;
var
    normalized_query: string;
    normalized_path: string;
    cache_key: string;
begin
    Result := 0;
    if m_defer_optional_model_loads then
    begin
        Exit;
    end;
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not ensure_open) or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    cache_key := normalized_query + #1 + normalized_path;
    if not m_query_path_bonus_cache_loaded then
    begin
        load_query_path_bonus_cache;
    end;
    if m_query_path_bonus_cache <> nil then
    begin
        m_query_path_bonus_cache.TryGetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_long_query_segment_path_bonus(
    const query_key: string; const encoded_path: string): Integer;
var
    normalized_query: string;
begin
    Result := 0;
    normalized_query := LowerCase(Trim(query_key));
    if (normalized_query = '') or (Trim(encoded_path) = '') or
        (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) or
        (not base_query_path_pinyin_may_exist(normalized_query)) then
    begin
        Exit;
    end;
    Result := get_query_segment_path_bonus(normalized_query, encoded_path);
end;

function TncSqliteDictionary.get_lm_transition_bonus(const query_key: string;
    const encoded_path: string): Integer;
var
    normalized_query: string;
    normalized_path: string;
    cache_key: string;
begin
    Result := 0;
    if m_defer_optional_model_loads then
    begin
        Exit;
    end;
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not ensure_open) or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    if not m_lm_transition_cache_loaded then
    begin
        load_lm_transition_bonus_cache;
    end;
    cache_key := normalized_query + #1 + normalized_path;
    if m_lm_transition_bonus_cache <> nil then
    begin
        m_lm_transition_bonus_cache.TryGetValue(cache_key, Result);
    end;
end;

function TncSqliteDictionary.get_exact_pair_path_evidence(
    const query_key: string; out results: TncPairPathEvidenceList): Boolean;
const
    query_sql =
        'SELECT path_text, weight, 1 FROM dict_base_lm_transition ' +
        'WHERE query_pinyin = ?1 ' +
        'UNION ALL ' +
        'SELECT path_text, weight, 0 FROM dict_base_query_path ' +
        'WHERE query_pinyin = ?1';
var
    normalized_query: string;
    cached_results: TncPairPathEvidenceList;
    step_result: Integer;
    path_text: string;
    raw_weight: Integer;
    source_is_lm: Boolean;
    result_idx: Integer;
    scan_idx: Integer;
    item: TncPairPathEvidence;
begin
    SetLength(results, 0);
    if m_defer_optional_model_loads then
    begin
        Exit(False);
    end;
    normalized_query := LowerCase(Trim(query_key));
    if (normalized_query = '') or (not ensure_open) or
        (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit(False);
    end;

    if (m_exact_pair_path_evidence_cache <> nil) and
        m_exact_pair_path_evidence_cache.TryGetValue(normalized_query,
        cached_results) then
    begin
        // Cached evidence arrays are immutable after construction.
        results := cached_results;
        Exit(Length(results) > 0);
    end;

    if m_stmt_exact_pair_path_evidence = nil then
    begin
        if not m_base_connection.prepare(query_sql,
            m_stmt_exact_pair_path_evidence) then
        begin
            m_stmt_exact_pair_path_evidence := nil;
        end;
    end;
    try
        if (m_stmt_exact_pair_path_evidence = nil) or
            (not m_base_connection.reset(m_stmt_exact_pair_path_evidence)) or
            (not m_base_connection.clear_bindings(
            m_stmt_exact_pair_path_evidence)) or
            (not m_base_connection.bind_text(m_stmt_exact_pair_path_evidence,
            1, normalized_query)) then
        begin
            Exit(False);
        end;

        while True do
        begin
            step_result := m_base_connection.step(
                m_stmt_exact_pair_path_evidence);
            if step_result <> SQLITE_ROW then
            begin
                Break;
            end;
            path_text := Trim(m_base_connection.column_text(
                m_stmt_exact_pair_path_evidence, 0));
            raw_weight := Max(0, m_base_connection.column_int(
                m_stmt_exact_pair_path_evidence, 1));
            source_is_lm := m_base_connection.column_int(
                m_stmt_exact_pair_path_evidence, 2) <> 0;
            if (path_text = '') or (raw_weight <= 0) or
                (get_encoded_path_segment_count(path_text) <> 2) then
            begin
                Continue;
            end;

            result_idx := -1;
            for scan_idx := 0 to High(results) do
            begin
                if SameText(results[scan_idx].encoded_path, path_text) then
                begin
                    result_idx := scan_idx;
                    Break;
                end;
            end;
            if result_idx < 0 then
            begin
                FillChar(item, SizeOf(item), 0);
                item.encoded_path := path_text;
                SetLength(results, Length(results) + 1);
                result_idx := High(results);
            end
            else
            begin
                item := results[result_idx];
            end;
            if source_is_lm then
            begin
                item.lm_transition_weight := Max(
                    item.lm_transition_weight, raw_weight);
            end
            else
            begin
                item.query_path_weight := Max(item.query_path_weight,
                    raw_weight);
            end;
            results[result_idx] := item;
        end;
    finally
        if m_stmt_exact_pair_path_evidence <> nil then
        begin
            m_base_connection.reset(m_stmt_exact_pair_path_evidence);
            m_base_connection.clear_bindings(m_stmt_exact_pair_path_evidence);
        end;
    end;

    if m_exact_pair_path_evidence_cache <> nil then
    begin
        m_exact_pair_path_evidence_cache.AddOrSetValue(normalized_query,
            results);
    end;
    Result := Length(results) > 0;
end;

function TncSqliteDictionary.ensure_char_lm_available(
    const reverse_model: Boolean): Boolean;
var
    stmt: Psqlite3_stmt;
    query_sql: string;
begin
    if m_defer_optional_model_loads then
    begin
        Exit(False);
    end;
    if reverse_model and (m_char_reverse_lm_available >= 0) then
    begin
        Exit(m_char_reverse_lm_available > 0);
    end;
    if (not reverse_model) and (m_char_lm_available >= 0) then
    begin
        Exit(m_char_lm_available > 0);
    end;

    if reverse_model then
    begin
        m_char_reverse_lm_available := 0;
        query_sql := 'SELECT 1 FROM dict_base_char_reverse_lm LIMIT 1';
    end
    else
    begin
        m_char_lm_available := 0;
        query_sql := 'SELECT 1 FROM dict_base_char_lm LIMIT 1';
    end;
    if (not ensure_open) or (not m_base_ready) or
        (m_base_connection = nil) then
    begin
        Exit(False);
    end;

    stmt := nil;
    try
        if not m_base_connection.prepare(query_sql, stmt) then
        begin
            Exit(False);
        end;
        if m_base_connection.step(stmt) = SQLITE_ROW then
        begin
            if reverse_model then
            begin
                m_char_reverse_lm_available := 1;
            end
            else
            begin
                m_char_lm_available := 1;
            end;
        end;
    finally
        if stmt <> nil then
        begin
            m_base_connection.finalize(stmt);
        end;
    end;
    if reverse_model then
    begin
        Result := m_char_reverse_lm_available > 0;
    end
    else
    begin
        Result := m_char_lm_available > 0;
    end;
end;

procedure TncSqliteDictionary.cache_char_lm_entry(const ngram: string;
    const entry: TncCharLmCacheEntry; const reverse_model: Boolean);
const
    c_cache_max_entries = 65536;
var
    evicted_ngram: string;
    entry_cache: TDictionary<string, TncCharLmCacheEntry>;
    cache_order: TQueue<string>;
begin
    if reverse_model then
    begin
        entry_cache := m_char_reverse_lm_entry_cache;
        cache_order := m_char_reverse_lm_cache_order;
    end
    else
    begin
        entry_cache := m_char_lm_entry_cache;
        cache_order := m_char_lm_cache_order;
    end;
    if (ngram = '') or (entry_cache = nil) or (cache_order = nil) then
    begin
        Exit;
    end;

    if entry_cache.ContainsKey(ngram) then
    begin
        entry_cache.AddOrSetValue(ngram, entry);
        Exit;
    end;

    while entry_cache.Count >= c_cache_max_entries do
    begin
        if cache_order.Count <= 0 then
        begin
            Exit;
        end;
        evicted_ngram := cache_order.Dequeue;
        entry_cache.Remove(evicted_ngram);
    end;
    entry_cache.Add(ngram, entry);
    cache_order.Enqueue(ngram);
end;

procedure TncSqliteDictionary.cache_char_lm_text_score(const cache_key: string;
    const score: Integer; const reverse_model: Boolean;
    const short_context_cache: Boolean);
const
    c_cache_max_entries = 16384;
    // Short contextual candidates have a larger bounded working set than
    // general sentence scoring. Keep it separate so it cannot evict or alter
    // the established long-sentence cache behavior.
    c_short_context_cache_max_entries = 65536;
var
    evicted_key: string;
    score_cache: TDictionary<string, Integer>;
    cache_order: TQueue<string>;
    cache_max_entries: Integer;
begin
    cache_max_entries := c_cache_max_entries;
    if short_context_cache and (not reverse_model) then
    begin
        score_cache := m_char_lm_short_context_text_score_cache;
        cache_order := m_char_lm_short_context_text_score_cache_order;
        cache_max_entries := c_short_context_cache_max_entries;
    end
    else if reverse_model then
    begin
        score_cache := m_char_reverse_lm_text_score_cache;
        cache_order := m_char_reverse_lm_text_score_cache_order;
    end
    else
    begin
        score_cache := m_char_lm_text_score_cache;
        cache_order := m_char_lm_text_score_cache_order;
    end;
    if (cache_key = '') or (score_cache = nil) or (cache_order = nil) then
    begin
        Exit;
    end;
    if score_cache.ContainsKey(cache_key) then
    begin
        score_cache.AddOrSetValue(cache_key, score);
        Exit;
    end;
    while score_cache.Count >= cache_max_entries do
    begin
        if cache_order.Count <= 0 then
        begin
            Exit;
        end;
        evicted_key := cache_order.Dequeue;
        score_cache.Remove(evicted_key);
    end;
    score_cache.Add(cache_key, score);
    cache_order.Enqueue(cache_key);
end;

function TncSqliteDictionary.load_char_lm_entries(
    const ngrams: TArray<string>;
    const entries: TDictionary<string, TncCharLmCacheEntry>;
    const reverse_model: Boolean): Boolean;
const
    c_query_chunk_size = 400;
var
    missing: TList<string>;
    stmt: Psqlite3_stmt;
    entry: TncCharLmCacheEntry;
    ngram: string;
    row_ngram: string;
    chunk_start: Integer;
    chunk_count: Integer;
    chunk_idx: Integer;
    step_result: Integer;
    entry_cache: TDictionary<string, TncCharLmCacheEntry>;

    function get_query_capacity(const wanted_count: Integer): Integer;
    begin
        if wanted_count <= 1 then
        begin
            Result := 1;
        end
        else if wanted_count <= 8 then
        begin
            Result := 8;
        end
        else if wanted_count <= 16 then
        begin
            Result := 16;
        end
        else if wanted_count <= 32 then
        begin
            Result := 32;
        end
        else if wanted_count <= 64 then
        begin
            Result := 64;
        end
        else if wanted_count <= 128 then
        begin
            Result := 128;
        end
        else if wanted_count <= 256 then
        begin
            Result := 256;
        end
        else
        begin
            Result := c_query_chunk_size;
        end;
    end;

    function prepare_cached_statement(const capacity: Integer;
        out cached_stmt: Psqlite3_stmt): Boolean;
    var
        local_builder: TStringBuilder;
        local_idx: Integer;
    begin
        cached_stmt := nil;
        if reverse_model then
        begin
            case capacity of
                1: cached_stmt := m_stmt_char_reverse_lm_entries_1;
                8: cached_stmt := m_stmt_char_reverse_lm_entries_8;
                16: cached_stmt := m_stmt_char_reverse_lm_entries_16;
                32: cached_stmt := m_stmt_char_reverse_lm_entries_32;
                64: cached_stmt := m_stmt_char_reverse_lm_entries_64;
                128: cached_stmt := m_stmt_char_reverse_lm_entries_128;
                256: cached_stmt := m_stmt_char_reverse_lm_entries_256;
                400: cached_stmt := m_stmt_char_reverse_lm_entries_400;
            end;
        end
        else
        begin
            case capacity of
                1: cached_stmt := m_stmt_char_lm_entries_1;
                8: cached_stmt := m_stmt_char_lm_entries_8;
                16: cached_stmt := m_stmt_char_lm_entries_16;
                32: cached_stmt := m_stmt_char_lm_entries_32;
                64: cached_stmt := m_stmt_char_lm_entries_64;
                128: cached_stmt := m_stmt_char_lm_entries_128;
                256: cached_stmt := m_stmt_char_lm_entries_256;
                400: cached_stmt := m_stmt_char_lm_entries_400;
            end;
        end;
        if cached_stmt <> nil then
        begin
            Exit(True);
        end;

        local_builder := TStringBuilder.Create;
        try
            if reverse_model then
            begin
                local_builder.Append(
                    'SELECT ngram, score, backoff FROM dict_base_char_reverse_lm WHERE ngram IN (');
            end
            else
            begin
                local_builder.Append(
                    'SELECT ngram, score, backoff FROM dict_base_char_lm WHERE ngram IN (');
            end;
            for local_idx := 1 to capacity do
            begin
                if local_idx > 1 then
                begin
                    local_builder.Append(',');
                end;
                local_builder.Append('?');
                local_builder.Append(local_idx);
            end;
            local_builder.Append(')');
            if not m_base_connection.prepare(local_builder.ToString,
                cached_stmt) then
            begin
                cached_stmt := nil;
                Exit(False);
            end;
        finally
            local_builder.Free;
        end;

        if reverse_model then
        begin
            case capacity of
                1: m_stmt_char_reverse_lm_entries_1 := cached_stmt;
                8: m_stmt_char_reverse_lm_entries_8 := cached_stmt;
                16: m_stmt_char_reverse_lm_entries_16 := cached_stmt;
                32: m_stmt_char_reverse_lm_entries_32 := cached_stmt;
                64: m_stmt_char_reverse_lm_entries_64 := cached_stmt;
                128: m_stmt_char_reverse_lm_entries_128 := cached_stmt;
                256: m_stmt_char_reverse_lm_entries_256 := cached_stmt;
                400: m_stmt_char_reverse_lm_entries_400 := cached_stmt;
            end;
        end
        else
        begin
            case capacity of
                1: m_stmt_char_lm_entries_1 := cached_stmt;
                8: m_stmt_char_lm_entries_8 := cached_stmt;
                16: m_stmt_char_lm_entries_16 := cached_stmt;
                32: m_stmt_char_lm_entries_32 := cached_stmt;
                64: m_stmt_char_lm_entries_64 := cached_stmt;
                128: m_stmt_char_lm_entries_128 := cached_stmt;
                256: m_stmt_char_lm_entries_256 := cached_stmt;
                400: m_stmt_char_lm_entries_400 := cached_stmt;
            end;
        end;
        Result := True;
    end;
var
    query_capacity: Integer;
begin
    Result := False;
    if reverse_model then
    begin
        entry_cache := m_char_reverse_lm_entry_cache;
    end
    else
    begin
        entry_cache := m_char_lm_entry_cache;
    end;
    if (entries = nil) or (not ensure_char_lm_available(reverse_model)) then
    begin
        Exit;
    end;

    missing := TList<string>.Create;
    try
        missing.Capacity := Length(ngrams);
        for ngram in ngrams do
        begin
            if ngram = '' then
            begin
                Continue;
            end;
            if (entry_cache <> nil) and
                entry_cache.TryGetValue(ngram, entry) then
            begin
                entries.Add(ngram, entry);
            end
            else
            begin
                missing.Add(ngram);
            end;
        end;

        chunk_start := 0;
        while chunk_start < missing.Count do
        begin
            chunk_count := Min(c_query_chunk_size,
                missing.Count - chunk_start);
            query_capacity := get_query_capacity(chunk_count);
            stmt := nil;
            try
                if not prepare_cached_statement(query_capacity, stmt) then
                begin
                    Exit(False);
                end;
                if (not m_base_connection.reset(stmt)) or
                    (not m_base_connection.clear_bindings(stmt)) then
                begin
                    Exit(False);
                end;
                for chunk_idx := 0 to query_capacity - 1 do
                begin
                    if chunk_idx < chunk_count then
                    begin
                        ngram := missing[chunk_start + chunk_idx];
                    end
                    else
                    begin
                        ngram := '';
                    end;
                    if not m_base_connection.bind_text(stmt, chunk_idx + 1,
                        ngram) then
                    begin
                        Exit(False);
                    end;
                end;

                step_result := m_base_connection.step(stmt);
                while step_result = SQLITE_ROW do
                begin
                    row_ngram := m_base_connection.column_text(stmt, 0);
                    entry.found := True;
                    entry.score := m_base_connection.column_int(stmt, 1);
                    entry.backoff := m_base_connection.column_int(stmt, 2);
                    entries.Add(row_ngram, entry);
                    cache_char_lm_entry(row_ngram, entry, reverse_model);
                    step_result := m_base_connection.step(stmt);
                end;
                if step_result <> SQLITE_DONE then
                begin
                    Exit(False);
                end;
            finally
                if stmt <> nil then
                begin
                    m_base_connection.reset(stmt);
                    m_base_connection.clear_bindings(stmt);
                end;
            end;

            entry.found := False;
            entry.score := 0;
            entry.backoff := 0;
            for chunk_idx := 0 to chunk_count - 1 do
            begin
                ngram := missing[chunk_start + chunk_idx];
                if not entries.ContainsKey(ngram) then
                begin
                    entries.Add(ngram, entry);
                    cache_char_lm_entry(ngram, entry, reverse_model);
                end;
            end;
            Inc(chunk_start, chunk_count);
        end;
        Result := True;
    finally
        missing.Free;
    end;
end;

function TncSqliteDictionary.get_char_lm_text_scores_internal(
    const texts: TArray<string>; out scores: TArray<Integer>;
    const include_begin_marker: Boolean; const left_context: string;
    const include_end_marker: Boolean; const cache_only: Boolean;
    const reverse_model: Boolean; const short_context_cache: Boolean): Boolean;
const
    c_begin_marker = #2;
    c_end_marker = #3;
    c_unknown_score = -30000;
var
    wanted: TDictionary<string, Boolean>;
    loaded_entries: TDictionary<string, TncCharLmCacheEntry>;
    wanted_keys: TArray<string>;
    padded_units: TArray<string>;
    prepared_units: TArray<TArray<string>>;
    normalized_texts: TArray<string>;
    text_units: TArray<string>;
    context_units: TArray<string>;
    context_prefix_units: TArray<string>;
    text_idx: Integer;
    unit_idx: Integer;
    context_idx: Integer;
    context_start_idx: Integer;
    padded_idx: Integer;
    first_predicted_idx: Integer;
    prefix_count: Integer;
    end_marker_count: Integer;
    predicted: Integer;
    current_score: Integer;
    entry_score: Integer;
    entry_backoff: Integer;
    total_score: Int64;
    unigram: string;
    bigram: string;
    trigram: string;
    trigram_context: string;
    fourgram: string;
    fourgram_context: string;
    score_cached: TArray<Boolean>;
    cache_key: string;
    cache_prefix: string;
    normalized_text: string;
    normalized_context: string;
    all_scores_cached: Boolean;
    wanted_key: string;
    cached_entry: TncCharLmCacheEntry;
    entry_cache: TDictionary<string, TncCharLmCacheEntry>;
    score_cache: TDictionary<string, Integer>;
    use_short_context_score_cache: Boolean;

    function try_get_loaded_entry(const ngram: string;
        out score: Integer; out backoff: Integer): Boolean;
    var
        entry: TncCharLmCacheEntry;
    begin
        score := 0;
        backoff := 0;
        Result := (loaded_entries <> nil) and
            loaded_entries.TryGetValue(ngram, entry) and entry.found;
        if Result then
        begin
            score := entry.score;
            backoff := entry.backoff;
        end;
    end;
begin
    SetLength(scores, Length(texts));
    SetLength(score_cached, Length(texts));
    Result := False;
    if Length(texts) <= 0 then
    begin
        Exit;
    end;
    use_short_context_score_cache := short_context_cache and
        (not reverse_model) and
        (not include_begin_marker) and (not include_end_marker) and
        (Trim(left_context) <> '');
    if use_short_context_score_cache then
    begin
        for text_idx := 0 to High(texts) do
        begin
            if (get_text_unit_count_local(Trim(texts[text_idx])) <= 0) or
                (get_text_unit_count_local(Trim(texts[text_idx])) > 4) then
            begin
                use_short_context_score_cache := False;
                Break;
            end;
        end;
    end;
    if use_short_context_score_cache then
    begin
        entry_cache := m_char_lm_entry_cache;
        score_cache := m_char_lm_short_context_text_score_cache;
    end
    else if reverse_model then
    begin
        entry_cache := m_char_reverse_lm_entry_cache;
        score_cache := m_char_reverse_lm_text_score_cache;
    end
    else
    begin
        entry_cache := m_char_lm_entry_cache;
        score_cache := m_char_lm_text_score_cache;
    end;
    SetLength(context_prefix_units, 0);
    normalized_context := '';
    if include_begin_marker then
    begin
        cache_prefix := 'B' + #1;
    end
    else if Trim(left_context) <> '' then
    begin
        context_units := split_text_units_local(Trim(left_context));
        context_start_idx := Max(0, Length(context_units) - 3);
        SetLength(context_prefix_units,
            Length(context_units) - context_start_idx);
        for context_idx := context_start_idx to High(context_units) do
        begin
            context_prefix_units[context_idx - context_start_idx] :=
                context_units[context_idx];
            normalized_context := normalized_context + context_units[context_idx];
        end;
        cache_prefix := 'C' + #1 + normalized_context + #1;
    end
    else if include_end_marker then
    begin
        cache_prefix := 'S' + #1;
    end
    else
    begin
        cache_prefix := 'N' + #1;
    end;

    SetLength(normalized_texts, Length(texts));
    SetLength(prepared_units, Length(texts));
    all_scores_cached := True;
    for text_idx := 0 to High(texts) do
    begin
        normalized_texts[text_idx] := Trim(texts[text_idx]);
        cache_key := cache_prefix + normalized_texts[text_idx];
        if (score_cache <> nil) and
            score_cache.TryGetValue(cache_key,
                scores[text_idx]) then
        begin
            score_cached[text_idx] := True;
        end
        else
        begin
            all_scores_cached := False;
        end;
    end;
    if all_scores_cached then
    begin
        Exit(True);
    end;

    loaded_entries := TDictionary<string, TncCharLmCacheEntry>.Create;
    try
        wanted := TDictionary<string, Boolean>.Create;
        try
            wanted.Capacity := Min(16384, Max(64, Length(texts) * 32));
            for text_idx := 0 to High(texts) do
            begin
            if score_cached[text_idx] then
            begin
                Continue;
            end;
            normalized_text := normalized_texts[text_idx];
            text_units := split_text_units_local(normalized_text);
            if Length(text_units) <= 0 then
            begin
                Continue;
            end;
            if include_begin_marker then
            begin
                prefix_count := 3;
            end
            else
            begin
                prefix_count := Length(context_prefix_units);
            end;
            if include_end_marker then
            begin
                end_marker_count := 1;
            end
            else
            begin
                end_marker_count := 0;
            end;
            SetLength(padded_units, Length(text_units) + prefix_count +
                end_marker_count);
            if include_begin_marker then
            begin
                padded_units[0] := c_begin_marker;
                padded_units[1] := c_begin_marker;
                padded_units[2] := c_begin_marker;
            end;
            if (not include_begin_marker) and (prefix_count > 0) then
            begin
                for context_idx := 0 to prefix_count - 1 do
                begin
                    padded_units[context_idx] := context_prefix_units[context_idx];
                end;
            end;
            for unit_idx := 0 to High(text_units) do
            begin
                padded_units[unit_idx + prefix_count] := text_units[unit_idx];
            end;
            if include_end_marker then
            begin
                padded_units[High(padded_units)] := c_end_marker;
            end;
            prepared_units[text_idx] := padded_units;
            if include_begin_marker then
            begin
                wanted.AddOrSetValue(c_begin_marker, True);
                wanted.AddOrSetValue(c_begin_marker + c_begin_marker, True);
                wanted.AddOrSetValue(c_begin_marker + c_begin_marker +
                    c_begin_marker, True);
            end;
            first_predicted_idx := prefix_count;
            for padded_idx := first_predicted_idx to High(padded_units) do
            begin
                unigram := padded_units[padded_idx];
                wanted.AddOrSetValue(unigram, True);
                if padded_idx >= 1 then
                begin
                    bigram := padded_units[padded_idx - 1] + unigram;
                    wanted.AddOrSetValue(bigram, True);
                    if prefix_count > 0 then
                    begin
                        wanted.AddOrSetValue(padded_units[padded_idx - 1], True);
                    end;
                end;
                if padded_idx >= 2 then
                begin
                    trigram_context := padded_units[padded_idx - 2] +
                        padded_units[padded_idx - 1];
                    trigram := trigram_context + unigram;
                    wanted.AddOrSetValue(trigram, True);
                    if prefix_count > 0 then
                    begin
                        wanted.AddOrSetValue(trigram_context, True);
                    end;
                end;
                if padded_idx >= 3 then
                begin
                    fourgram_context := padded_units[padded_idx - 3] +
                        padded_units[padded_idx - 2] +
                        padded_units[padded_idx - 1];
                    fourgram := fourgram_context + unigram;
                    wanted.AddOrSetValue(fourgram, True);
                    if prefix_count > 0 then
                    begin
                        wanted.AddOrSetValue(fourgram_context, True);
                    end;
                end;
            end;
            end;

            wanted_keys := wanted.Keys.ToArray;
            loaded_entries.Capacity := Length(wanted_keys);
            if cache_only then
            begin
                if entry_cache = nil then
                begin
                    Exit;
                end;
                for wanted_key in wanted_keys do
                begin
                    if not entry_cache.TryGetValue(wanted_key,
                        cached_entry) then
                    begin
                        Exit;
                    end;
                    loaded_entries.AddOrSetValue(wanted_key, cached_entry);
                end;
            end
            else if (Length(wanted_keys) > 0) and
                (not load_char_lm_entries(wanted_keys, loaded_entries,
                reverse_model)) then
            begin
                Exit;
            end;
        finally
            wanted.Free;
        end;

        for text_idx := 0 to High(texts) do
        begin
            if score_cached[text_idx] then
            begin
                Continue;
            end;
        normalized_text := normalized_texts[text_idx];
        padded_units := prepared_units[text_idx];
        if include_begin_marker then
        begin
            prefix_count := 3;
        end
        else
        begin
            prefix_count := Length(context_prefix_units);
        end;
        total_score := 0;
        predicted := 0;
        first_predicted_idx := prefix_count;
        for padded_idx := first_predicted_idx to High(padded_units) do
        begin
                unigram := padded_units[padded_idx];
                if padded_idx >= 1 then
                begin
                    bigram := padded_units[padded_idx - 1] + unigram;
                end
                else
                begin
                    bigram := '';
                end;
                if padded_idx >= 2 then
                begin
                    trigram_context := padded_units[padded_idx - 2] +
                        padded_units[padded_idx - 1];
                    trigram := trigram_context + unigram;
                end
                else
                begin
                    trigram_context := '';
                    trigram := '';
                end;
                if padded_idx >= 3 then
                begin
                    fourgram_context := padded_units[padded_idx - 3] +
                        padded_units[padded_idx - 2] +
                        padded_units[padded_idx - 1];
                    fourgram := fourgram_context + unigram;
                end
                else
                begin
                    fourgram_context := '';
                    fourgram := '';
                end;
                if (fourgram <> '') and try_get_loaded_entry(fourgram, entry_score,
                    entry_backoff) then
                begin
                    current_score := entry_score;
                end
                else
                begin
                    if (trigram <> '') and try_get_loaded_entry(trigram, entry_score,
                        entry_backoff) then
                    begin
                        current_score := entry_score;
                    end
                    else
                    begin
                        if (bigram <> '') and try_get_loaded_entry(bigram, entry_score,
                            entry_backoff) then
                        begin
                            current_score := entry_score;
                        end
                        else
                        begin
                            if try_get_loaded_entry(unigram, entry_score,
                                entry_backoff) then
                            begin
                                current_score := entry_score;
                            end
                            else
                            begin
                                current_score := c_unknown_score;
                            end;
                            if (padded_idx >= 1) and try_get_loaded_entry(
                                padded_units[padded_idx - 1], entry_score,
                                entry_backoff) then
                            begin
                                Inc(current_score, entry_backoff);
                            end;
                        end;
                        if (trigram_context <> '') and try_get_loaded_entry(
                            trigram_context, entry_score,
                            entry_backoff) then
                        begin
                            Inc(current_score, entry_backoff);
                        end;
                    end;
                    if (fourgram_context <> '') and try_get_loaded_entry(
                        fourgram_context, entry_score,
                        entry_backoff) then
                    begin
                        Inc(current_score, entry_backoff);
                    end;
                end;
                Inc(total_score, current_score);
                Inc(predicted);
        end;
        if predicted <= 0 then
        begin
            scores[text_idx] := c_unknown_score;
        end
        else if total_score >= 0 then
        begin
            scores[text_idx] := total_score div predicted;
        end
        else
        begin
            scores[text_idx] :=
                -((-total_score + predicted - 1) div predicted);
        end;
        if not cache_only then
        begin
            cache_char_lm_text_score(cache_prefix + normalized_text,
                scores[text_idx], reverse_model,
                use_short_context_score_cache);
        end;
        end;
        Result := True;
    finally
        loaded_entries.Free;
    end;
end;

function TncSqliteDictionary.get_char_lm_text_scores(const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_text_scores_internal(texts, scores, True, '', True);
end;

function TncSqliteDictionary.get_char_lm_parameters(const ngrams: TArray<string>;
    out scores, backoffs: TArray<Integer>;
    const reverse_model: Boolean): Boolean;
var
    wanted: TDictionary<string, Boolean>;
    entries: TDictionary<string, TncCharLmCacheEntry>;
    entry: TncCharLmCacheEntry;
    idx: Integer;
begin
    Result := False;
    SetLength(scores, Length(ngrams));
    SetLength(backoffs, Length(ngrams));
    for idx := 0 to High(scores) do scores[idx] := Low(Integer);
    if (Length(ngrams) = 0) or (Length(ngrams) > 4096) or
        not ensure_char_lm_available(reverse_model) then Exit;
    wanted := TDictionary<string, Boolean>.Create;
    entries := TDictionary<string, TncCharLmCacheEntry>.Create;
    try
        for idx := 0 to High(ngrams) do
            if ngrams[idx] <> '' then
                wanted.AddOrSetValue(ngrams[idx], True);
        if not load_char_lm_entries(wanted.Keys.ToArray, entries, reverse_model) then Exit;
        for idx := 0 to High(ngrams) do
            if entries.TryGetValue(ngrams[idx], entry) and entry.found then
            begin
                scores[idx] := entry.score;
                backoffs[idx] := entry.backoff;
            end;
        Result := True;
    finally
        entries.Free;
        wanted.Free;
    end;
end;

function TncSqliteDictionary.get_char_lm_attested_scores(
    const ngrams: TArray<string>; out scores: TArray<Integer>): Boolean;
var
    wanted: TDictionary<string, Boolean>;
    entries: TDictionary<string, TncCharLmCacheEntry>;
    entry: TncCharLmCacheEntry;
    idx: Integer;
begin
    Result := False;
    SetLength(scores, Length(ngrams));
    for idx := 0 to High(scores) do scores[idx] := Low(Integer);
    if (Length(ngrams) = 0) or (not ensure_char_lm_available) then Exit;
    wanted := TDictionary<string, Boolean>.Create;
    entries := TDictionary<string, TncCharLmCacheEntry>.Create;
    try
        for idx := 0 to High(ngrams) do
            if Trim(ngrams[idx]) <> '' then
                wanted.AddOrSetValue(Trim(ngrams[idx]), True);
        if not load_char_lm_entries(wanted.Keys.ToArray, entries) then Exit;
        for idx := 0 to High(ngrams) do
            if entries.TryGetValue(Trim(ngrams[idx]), entry) and entry.found then
            begin
                scores[idx] := entry.score;
                Result := True;
            end;
    finally
        entries.Free;
        wanted.Free;
    end;
end;

function TncSqliteDictionary.get_char_lm_suffix_scores(const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_text_scores_internal(texts, scores, False, '', True);
end;

function TncSqliteDictionary.get_char_lm_cached_scores_internal(
    const texts: TArray<string>; out scores: TArray<Integer>;
    const include_end_marker: Boolean;
    const reverse_model: Boolean): Boolean;
const
    c_unknown_score = -30000;
    c_end_marker = #3;
var
    normalized_text: string;
    cache_key: string;
    cache_prefix: string;
    text_units: TArray<string>;
    text_idx: Integer;
    unit_idx: Integer;
    predicted: Integer;
    current_score: Integer;
    total_score: Int64;
    unigram: string;
    bigram: string;
    trigram: string;
    fourgram: string;
    unigram_entry: TncCharLmCacheEntry;
    bigram_entry: TncCharLmCacheEntry;
    trigram_entry: TncCharLmCacheEntry;
    fourgram_entry: TncCharLmCacheEntry;
    previous_unigram_entry: TncCharLmCacheEntry;
    previous_bigram_entry: TncCharLmCacheEntry;
    previous_trigram_entry: TncCharLmCacheEntry;
    entry_cache: TDictionary<string, TncCharLmCacheEntry>;
    score_cache: TDictionary<string, Integer>;

    function get_cached_entry(const ngram: string;
        out entry: TncCharLmCacheEntry): Boolean;
    begin
        entry := Default(TncCharLmCacheEntry);
        Result := (entry_cache <> nil) and
            entry_cache.TryGetValue(ngram, entry);
    end;
begin
    SetLength(scores, Length(texts));
    Result := False;
    if reverse_model then
    begin
        entry_cache := m_char_reverse_lm_entry_cache;
        score_cache := m_char_reverse_lm_text_score_cache;
    end
    else
    begin
        entry_cache := m_char_lm_entry_cache;
        score_cache := m_char_lm_text_score_cache;
    end;
    if include_end_marker then
    begin
        cache_prefix := 'S' + #1;
    end
    else
    begin
        cache_prefix := 'N' + #1;
    end;
    if (Length(texts) <= 0) or (entry_cache = nil) or
        (not ensure_char_lm_available(reverse_model)) then
    begin
        Exit;
    end;

    for text_idx := 0 to High(texts) do
    begin
        normalized_text := Trim(texts[text_idx]);
        cache_key := cache_prefix + normalized_text;
        if (score_cache <> nil) and score_cache.TryGetValue(cache_key,
            scores[text_idx]) then
        begin
            Continue;
        end;

        text_units := split_text_units_local(normalized_text);
        if Length(text_units) <= 0 then
        begin
            scores[text_idx] := c_unknown_score;
            Continue;
        end;
        if include_end_marker then
        begin
            SetLength(text_units, Length(text_units) + 1);
            text_units[High(text_units)] := c_end_marker;
        end;

        total_score := 0;
        predicted := 0;
        previous_unigram_entry := Default(TncCharLmCacheEntry);
        previous_bigram_entry := Default(TncCharLmCacheEntry);
        previous_trigram_entry := Default(TncCharLmCacheEntry);
        for unit_idx := 0 to High(text_units) do
        begin
            unigram := text_units[unit_idx];
            if not get_cached_entry(unigram, unigram_entry) then
            begin
                Exit;
            end;

            bigram := '';
            bigram_entry := Default(TncCharLmCacheEntry);
            if unit_idx >= 1 then
            begin
                bigram := text_units[unit_idx - 1] + unigram;
                if not get_cached_entry(bigram, bigram_entry) then
                begin
                    Exit;
                end;
            end;

            trigram := '';
            trigram_entry := Default(TncCharLmCacheEntry);
            if unit_idx >= 2 then
            begin
                trigram := text_units[unit_idx - 2] +
                    text_units[unit_idx - 1] + unigram;
                if not get_cached_entry(trigram, trigram_entry) then
                begin
                    Exit;
                end;
            end;

            fourgram := '';
            fourgram_entry := Default(TncCharLmCacheEntry);
            if unit_idx >= 3 then
            begin
                fourgram := text_units[unit_idx - 3] +
                    text_units[unit_idx - 2] +
                    text_units[unit_idx - 1] + unigram;
                if not get_cached_entry(fourgram, fourgram_entry) then
                begin
                    Exit;
                end;
            end;

            if (fourgram <> '') and fourgram_entry.found then
            begin
                current_score := fourgram_entry.score;
            end
            else
            begin
                if (trigram <> '') and trigram_entry.found then
                begin
                    current_score := trigram_entry.score;
                end
                else
                begin
                    if (bigram <> '') and bigram_entry.found then
                    begin
                        current_score := bigram_entry.score;
                    end
                    else
                    begin
                        if unigram_entry.found then
                        begin
                            current_score := unigram_entry.score;
                        end
                        else
                        begin
                            current_score := c_unknown_score;
                        end;
                        if (unit_idx >= 1) and
                            previous_unigram_entry.found then
                        begin
                            Inc(current_score,
                                previous_unigram_entry.backoff);
                        end;
                    end;
                    if (unit_idx >= 2) and previous_bigram_entry.found then
                    begin
                        Inc(current_score, previous_bigram_entry.backoff);
                    end;
                end;
                if (unit_idx >= 3) and previous_trigram_entry.found then
                begin
                    Inc(current_score, previous_trigram_entry.backoff);
                end;
            end;

            Inc(total_score, current_score);
            Inc(predicted);
            previous_unigram_entry := unigram_entry;
            previous_bigram_entry := bigram_entry;
            previous_trigram_entry := trigram_entry;
        end;

        if predicted <= 0 then
        begin
            scores[text_idx] := c_unknown_score;
        end
        else if total_score >= 0 then
        begin
            scores[text_idx] := total_score div predicted;
        end
        else
        begin
            scores[text_idx] :=
                -((-total_score + predicted - 1) div predicted);
        end;
    end;
    Result := True;
end;

function TncSqliteDictionary.get_char_lm_cached_span_scores(
    const texts: TArray<string>; out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_cached_scores_internal(texts, scores, False,
        False);
end;

function TncSqliteDictionary.get_char_lm_continuation_scores(
    const left_context: string; const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_text_scores_internal(texts, scores, False,
        left_context, False);
end;

function TncSqliteDictionary.get_char_lm_short_context_scores(
    const left_context: string; const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_text_scores_internal(texts, scores, False,
        left_context, False, False, False, True);
end;

function TncSqliteDictionary.get_char_reverse_lm_suffix_scores(
    const texts: TArray<string>; out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_text_scores_internal(texts, scores, False, '',
        True, False, True);
end;

function TncSqliteDictionary.get_compound_tail_support(const tail_text: string): Integer;
const
    query_sql =
        'SELECT COUNT(1), COALESCE(SUM(weight), 0), COALESCE(MAX(weight), 0) ' +
        'FROM dict_base_query_path WHERE path_text LIKE ?1';
    prefix_query_sql =
        'SELECT COUNT(1), COALESCE(SUM(b.weight), 0), COALESCE(MAX(b.weight), 0) ' +
        'FROM dict_base AS b WHERE b.comment = '''' AND b.text LIKE ?1 ' +
        'AND b.text <> ?2 AND ' + c_base_text_evidence_scope_sql;
    // Same rows as prefix_query_sql through idx_dict_base_text_weight; see
    // try_get_like_prefix_upper_bound.
    prefix_range_query_sql =
        'SELECT COUNT(1), COALESCE(SUM(b.weight), 0), COALESCE(MAX(b.weight), 0) ' +
        'FROM dict_base AS b WHERE b.comment = '''' AND b.text >= ?1 ' +
        'AND b.text < ?3 AND b.text <> ?2 AND ' + c_base_text_evidence_scope_sql;
    c_segment_path_separator = #3;
    c_prefix_productivity_support_cap = 1500;
var
    normalized_tail: string;
    pattern: string;
    prefix_pattern: string;
    step_result: Integer;
    path_count: Integer;
    total_weight: Integer;
    max_weight: Integer;
    prefix_support: Integer;
    prefix_upper_bound: string;
    prefix_stmt: Psqlite3_stmt;
    prefix_bound: Boolean;
begin
    Result := 0;
    if m_defer_optional_model_loads then
    begin
        Exit;
    end;
    normalized_tail := Trim(tail_text);
    if (normalized_tail = '') or (get_valid_cjk_codepoint_count(normalized_tail) < 2) or
        (not ensure_open) or (not m_base_ready) or (m_base_connection = nil) then
    begin
        Exit;
    end;

    if (m_compound_tail_support_cache <> nil) and
        m_compound_tail_support_cache.TryGetValue(normalized_tail, Result) then
    begin
        Exit;
    end;

    pattern := '%' + c_segment_path_separator + normalized_tail;
    try
        if m_stmt_compound_tail_support = nil then
        begin
            if not m_base_connection.prepare(query_sql, m_stmt_compound_tail_support) then
            begin
                m_stmt_compound_tail_support := nil;
                Exit;
            end;
        end;

        if (not m_base_connection.reset(m_stmt_compound_tail_support)) or
            (not m_base_connection.clear_bindings(m_stmt_compound_tail_support)) or
            (not m_base_connection.bind_text(m_stmt_compound_tail_support, 1, pattern)) then
        begin
            Exit;
        end;

        step_result := m_base_connection.step(m_stmt_compound_tail_support);
        if step_result = SQLITE_ROW then
        begin
            path_count := m_base_connection.column_int(m_stmt_compound_tail_support, 0);
            total_weight := m_base_connection.column_int(m_stmt_compound_tail_support, 1);
            max_weight := m_base_connection.column_int(m_stmt_compound_tail_support, 2);
            Result := calc_compound_tail_support_value(path_count, total_weight, max_weight);
        end;
    finally
        if m_stmt_compound_tail_support <> nil then
        begin
            m_base_connection.reset(m_stmt_compound_tail_support);
            m_base_connection.clear_bindings(m_stmt_compound_tail_support);
        end;
    end;

    if Result <= 0 then
    begin
        prefix_pattern := normalized_tail + '%';
        prefix_stmt := nil;
        try
            if try_get_like_prefix_upper_bound(normalized_tail, prefix_upper_bound) then
            begin
                if m_stmt_compound_tail_prefix_range_support = nil then
                begin
                    if not m_base_connection.prepare(prefix_range_query_sql,
                        m_stmt_compound_tail_prefix_range_support) then
                    begin
                        m_stmt_compound_tail_prefix_range_support := nil;
                        Exit;
                    end;
                end;
                prefix_stmt := m_stmt_compound_tail_prefix_range_support;
                prefix_bound := m_base_connection.reset(prefix_stmt) and
                    m_base_connection.clear_bindings(prefix_stmt) and
                    m_base_connection.bind_text(prefix_stmt, 1, normalized_tail) and
                    m_base_connection.bind_text(prefix_stmt, 2, normalized_tail) and
                    m_base_connection.bind_text(prefix_stmt, 3, prefix_upper_bound);
            end
            else
            begin
                if m_stmt_compound_tail_prefix_support = nil then
                begin
                    if not m_base_connection.prepare(prefix_query_sql,
                        m_stmt_compound_tail_prefix_support) then
                    begin
                        m_stmt_compound_tail_prefix_support := nil;
                        Exit;
                    end;
                end;
                prefix_stmt := m_stmt_compound_tail_prefix_support;
                prefix_bound := m_base_connection.reset(prefix_stmt) and
                    m_base_connection.clear_bindings(prefix_stmt) and
                    m_base_connection.bind_text(prefix_stmt, 1, prefix_pattern) and
                    m_base_connection.bind_text(prefix_stmt, 2, normalized_tail);
            end;
            if not prefix_bound then
            begin
                Exit;
            end;

            step_result := m_base_connection.step(prefix_stmt);
            if step_result = SQLITE_ROW then
            begin
                path_count := m_base_connection.column_int(prefix_stmt, 0);
                total_weight := m_base_connection.column_int(prefix_stmt, 1);
                max_weight := m_base_connection.column_int(prefix_stmt, 2);
                prefix_support := calc_compound_tail_support_value(path_count,
                    total_weight, max_weight);
                Result := Min(c_prefix_productivity_support_cap, prefix_support);
            end;
        finally
            if prefix_stmt <> nil then
            begin
                m_base_connection.reset(prefix_stmt);
                m_base_connection.clear_bindings(prefix_stmt);
            end;
        end;
    end;

    if m_compound_tail_support_cache <> nil then
    begin
        m_compound_tail_support_cache.AddOrSetValue(normalized_tail, Result);
    end;
end;

function TncSqliteDictionary.get_query_segment_path_penalty(const query_key: string;
    const encoded_path: string): Integer;
const
    query_sql =
        'SELECT penalty, last_used FROM dict_user_query_path_penalty ' +
        'WHERE query_pinyin = ?1 AND path_text = ?2 LIMIT 1';
var
    step_result: Integer;
    normalized_query: string;
    normalized_path: string;
    cache_key: string;
    last_used_unix: Int64;
begin
    Result := 0;
    normalized_query := LowerCase(Trim(query_key));
    normalized_path := Trim(encoded_path);
    if (normalized_query = '') or (normalized_path = '') or
        (get_encoded_path_segment_count(normalized_path) <= 1) or
        (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    cache_key := normalized_query + #1 + normalized_path;
    if (m_query_path_penalty_cache <> nil) and
        m_query_path_penalty_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    try
        if m_stmt_query_path_penalty = nil then
        begin
            if not m_user_connection.prepare(query_sql, m_stmt_query_path_penalty) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_query_path_penalty)) or
            (not m_user_connection.clear_bindings(m_stmt_query_path_penalty)) or
            (not m_user_connection.bind_text(m_stmt_query_path_penalty, 1, normalized_query)) or
            (not m_user_connection.bind_text(m_stmt_query_path_penalty, 2, normalized_path)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_query_path_penalty);
        if step_result = SQLITE_ROW then
        begin
            last_used_unix := m_user_connection.column_int(m_stmt_query_path_penalty, 1);
            Result := calc_query_segment_path_penalty_value(
                m_user_connection.column_int(m_stmt_query_path_penalty, 0),
                last_used_unix,
                get_unix_time_now);
        end;

        if m_query_path_penalty_cache <> nil then
        begin
            m_query_path_penalty_cache.AddOrSetValue(cache_key, Result);
        end;
    finally
        if m_stmt_query_path_penalty <> nil then
        begin
            m_user_connection.reset(m_stmt_query_path_penalty);
            m_user_connection.clear_bindings(m_stmt_query_path_penalty);
        end;
    end;
end;

procedure TncSqliteDictionary.populate_candidate_penalty_cache_for_pinyin(
    const pinyin_key: string; const compact_pinyin_key: string);
const
    query_penalties_sql =
        'SELECT text, penalty, last_used FROM dict_user_penalty ' +
        'WHERE pinyin = ?1 OR pinyin = ?2';
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
    text_key: string;
    cache_key: string;
    penalty_value: Integer;
    cached_penalty: Integer;
    last_used_unix: Int64;
    now_unix: Int64;
begin
    if (pinyin_key = '') or (m_candidate_penalty_cache = nil) or
        (m_candidate_penalty_pinyin_loaded_cache = nil) or
        (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_candidate_penalty_pinyin_loaded_cache.ContainsKey(pinyin_key) then
    begin
        Exit;
    end;

    stmt := nil;
    try
        if (not m_user_connection.prepare(query_penalties_sql, stmt)) or
            (not m_user_connection.bind_text(stmt, 1, pinyin_key)) or
            (not m_user_connection.bind_text(stmt, 2, compact_pinyin_key)) then
        begin
            Exit;
        end;

        now_unix := get_unix_time_now;
        while True do
        begin
            step_result := m_user_connection.step(stmt);
            if step_result <> SQLITE_ROW then
            begin
                Break;
            end;

            text_key := Trim(m_user_connection.column_text(stmt, 0));
            if text_key = '' then
            begin
                Continue;
            end;

            last_used_unix := m_user_connection.column_int(stmt, 2);
            penalty_value := calc_candidate_penalty_value(
                m_user_connection.column_int(stmt, 1), last_used_unix, now_unix);
            cache_key := pinyin_key + #1 + text_key;
            if m_candidate_penalty_cache.TryGetValue(cache_key, cached_penalty) and
                (cached_penalty >= penalty_value) then
            begin
                Continue;
            end;
            m_candidate_penalty_cache.AddOrSetValue(cache_key, penalty_value);
        end;

        m_candidate_penalty_pinyin_loaded_cache.AddOrSetValue(pinyin_key, True);
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
end;

function TncSqliteDictionary.get_candidate_penalty(const pinyin: string; const text: string): Integer;
const
    query_penalty_sql =
        'SELECT penalty, last_used FROM dict_user_penalty ' +
        'WHERE text = ?2 AND (pinyin = ?1 OR pinyin = ?3) ' +
        'ORDER BY penalty DESC, last_used DESC LIMIT 1';
var
    pinyin_key: string;
    compact_pinyin_key: string;
    text_key: string;
    cache_key: string;
    step_result: Integer;
    last_used_unix: Int64;
begin
    Result := 0;
    pinyin_key := LowerCase(Trim(pinyin));
    compact_pinyin_key := normalize_compact_pinyin_key(pinyin_key);
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not ensure_open) or (not m_user_ready) then
    begin
        Exit;
    end;

    cache_key := pinyin_key + #1 + text_key;
    if (m_candidate_penalty_cache <> nil) and
        m_candidate_penalty_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;

    populate_candidate_penalty_cache_for_pinyin(pinyin_key, compact_pinyin_key);
    if (m_candidate_penalty_cache <> nil) and
        m_candidate_penalty_cache.TryGetValue(cache_key, Result) then
    begin
        Exit;
    end;
    if (m_candidate_penalty_pinyin_loaded_cache <> nil) and
        m_candidate_penalty_pinyin_loaded_cache.ContainsKey(pinyin_key) then
    begin
        if m_candidate_penalty_cache <> nil then
        begin
            m_candidate_penalty_cache.AddOrSetValue(cache_key, 0);
        end;
        Exit;
    end;

    try
        if m_stmt_candidate_penalty = nil then
        begin
            if not m_user_connection.prepare(query_penalty_sql, m_stmt_candidate_penalty) then
            begin
                Exit;
            end;
        end;
        if (not m_user_connection.reset(m_stmt_candidate_penalty)) or
            (not m_user_connection.clear_bindings(m_stmt_candidate_penalty)) or
            (not m_user_connection.bind_text(m_stmt_candidate_penalty, 1, pinyin_key)) or
            (not m_user_connection.bind_text(m_stmt_candidate_penalty, 2, text_key)) or
            (not m_user_connection.bind_text(m_stmt_candidate_penalty, 3, compact_pinyin_key)) then
        begin
            Exit;
        end;

        step_result := m_user_connection.step(m_stmt_candidate_penalty);
        if step_result = SQLITE_ROW then
        begin
            last_used_unix := m_user_connection.column_int(m_stmt_candidate_penalty, 1);
            Result := calc_candidate_penalty_value(
                m_user_connection.column_int(m_stmt_candidate_penalty, 0),
                last_used_unix,
                get_unix_time_now);
        end;

        if m_candidate_penalty_cache <> nil then
        begin
            m_candidate_penalty_cache.AddOrSetValue(cache_key, Result);
        end;
    finally
        if m_stmt_candidate_penalty <> nil then
        begin
            m_user_connection.reset(m_stmt_candidate_penalty);
            m_user_connection.clear_bindings(m_stmt_candidate_penalty);
        end;
    end;
end;

procedure TncSqliteDictionary.record_candidate_penalty(const pinyin: string; const text: string);
const
    delete_latest_sql = 'DELETE FROM dict_user_query_latest WHERE query_pinyin = ?1 AND text = ?2';
    update_penalty_sql = 'UPDATE dict_user_penalty SET penalty = MIN(penalty + ?3, ?4), ' +
        'last_used = strftime(''%s'',''now'') WHERE pinyin = ?1 AND text = ?2';
    insert_penalty_sql = 'INSERT OR IGNORE INTO dict_user_penalty(pinyin, text, penalty, last_used) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
    c_penalty_step = 24;
    c_penalty_max = 120;
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    text_key: string;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (pinyin_key = '') or (text_key = '') or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_candidate_penalty_pinyin_loaded_cache <> nil then
    begin
        m_candidate_penalty_pinyin_loaded_cache.Clear;
    end;
    if m_context_bonus_cache <> nil then
    begin
        m_context_bonus_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        m_query_choice_bonus_cache.Remove(pinyin_key + #1 + text_key);
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        m_query_latest_choice_text_cache.Remove(pinyin_key);
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(delete_latest_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(update_penalty_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) and
            m_user_connection.bind_int(stmt, 4, c_penalty_max) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;

    stmt := nil;
    try
        if m_user_connection.prepare(insert_penalty_sql, stmt) and
            m_user_connection.bind_text(stmt, 1, pinyin_key) and
            m_user_connection.bind_text(stmt, 2, text_key) and
            m_user_connection.bind_int(stmt, 3, c_penalty_step) then
        begin
            m_user_connection.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            m_user_connection.finalize(stmt);
        end;
    end;
    note_user_data_changed;
end;

procedure TncSqliteDictionary.purge_user_entry_internal(const pinyin: string; const text: string;
    const apply_penalty: Boolean; const purge_all_by_text: Boolean);
const
    delete_user_sql = 'DELETE FROM dict_user WHERE pinyin = ?1 AND text = ?2';
    delete_stats_sql = 'DELETE FROM dict_user_stats WHERE pinyin = ?1 AND text = ?2';
    delete_latest_sql = 'DELETE FROM dict_user_query_latest WHERE query_pinyin = ?1 AND text = ?2';
    delete_query_path_sql =
        'DELETE FROM dict_user_query_path WHERE query_pinyin = ?1 AND replace(path_text, ?2, '''') = ?3';
    delete_user_by_text_sql = 'DELETE FROM dict_user WHERE text = ?1';
    delete_literal_by_text_sql = 'DELETE FROM dict_user_literal WHERE text = ?1';
    delete_stats_by_text_sql = 'DELETE FROM dict_user_stats WHERE text = ?1';
    delete_latest_by_text_sql = 'DELETE FROM dict_user_query_latest WHERE text = ?1';
    delete_query_path_by_text_sql =
        'DELETE FROM dict_user_query_path WHERE replace(path_text, ?1, '''') = ?2';
    delete_bigram_by_text_sql = 'DELETE FROM dict_user_bigram WHERE text = ?1';
    delete_bigram_by_left_sql = 'DELETE FROM dict_user_bigram WHERE left_text = ?1';
    delete_trigram_by_text_sql = 'DELETE FROM dict_user_trigram WHERE text = ?1';
    delete_trigram_by_prev_sql = 'DELETE FROM dict_user_trigram WHERE prev_text = ?1';
    delete_trigram_by_prev_prev_sql = 'DELETE FROM dict_user_trigram WHERE prev_prev_text = ?1';
    update_penalty_sql = 'UPDATE dict_user_penalty SET penalty = MIN(penalty + ?3, ?4), ' +
        'last_used = strftime(''%s'',''now'') WHERE pinyin = ?1 AND text = ?2';
    insert_penalty_sql = 'INSERT OR IGNORE INTO dict_user_penalty(pinyin, text, penalty, last_used) ' +
        'VALUES (?1, ?2, ?3, strftime(''%s'',''now''))';
    c_query_path_text_separator = #3;
    c_remove_penalty_step = 80;
    c_remove_penalty_max = 360;
var
    stmt: Psqlite3_stmt;
    pinyin_key: string;
    text_key: string;
begin
    pinyin_key := LowerCase(Trim(pinyin));
    text_key := Trim(text);
    if (text_key = '') or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_candidate_penalty_cache <> nil then
    begin
        m_candidate_penalty_cache.Clear;
    end;
    if m_candidate_penalty_pinyin_loaded_cache <> nil then
    begin
        m_candidate_penalty_pinyin_loaded_cache.Clear;
    end;
    if m_context_bonus_cache <> nil then
    begin
        m_context_bonus_cache.Clear;
    end;
    if m_query_choice_bonus_cache <> nil then
    begin
        if purge_all_by_text then
        begin
            m_query_choice_bonus_cache.Clear;
        end
        else if pinyin_key <> '' then
        begin
            m_query_choice_bonus_cache.Remove(pinyin_key + #1 + text_key);
        end
        else
        begin
            m_query_choice_bonus_cache.Clear;
        end;
    end;
    if m_query_latest_choice_text_cache <> nil then
    begin
        if purge_all_by_text then
        begin
            m_query_latest_choice_text_cache.Clear;
        end
        else if pinyin_key <> '' then
        begin
            m_query_latest_choice_text_cache.Remove(pinyin_key);
        end
        else
        begin
            m_query_latest_choice_text_cache.Clear;
        end;
    end;

    // Prefer exact pinyin+text removal when key is available, but do not require it.
    if pinyin_key <> '' then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_stats_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_latest_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_query_path_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, c_query_path_text_separator) and
                m_user_connection.bind_text(stmt, 3, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if purge_all_by_text then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(delete_literal_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_user_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_stats_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_latest_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_query_path_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, c_query_path_text_separator) and
                m_user_connection.bind_text(stmt, 2, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_bigram_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_bigram_by_left_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_trigram_by_text_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_trigram_by_prev_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(delete_trigram_by_prev_prev_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, text_key) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;

    if apply_penalty and (pinyin_key <> '') and is_valid_user_text(text_key) then
    begin
        stmt := nil;
        try
            if m_user_connection.prepare(update_penalty_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) and
                m_user_connection.bind_int(stmt, 3, c_remove_penalty_step) and
                m_user_connection.bind_int(stmt, 4, c_remove_penalty_max) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;

        stmt := nil;
        try
            if m_user_connection.prepare(insert_penalty_sql, stmt) and
                m_user_connection.bind_text(stmt, 1, pinyin_key) and
                m_user_connection.bind_text(stmt, 2, text_key) and
                m_user_connection.bind_int(stmt, 3, c_remove_penalty_step) then
            begin
                m_user_connection.step(stmt);
            end;
        finally
            if stmt <> nil then
            begin
                m_user_connection.finalize(stmt);
            end;
        end;
    end;
    note_user_data_changed;
    m_literal_user_words_available := -1;
end;

procedure TncSqliteDictionary.remove_user_entry(const pinyin: string; const text: string);
var
    aliases: TList<string>;
    stmt: Psqlite3_stmt;
    stored, stored_pinyin: string;
begin
    // Prefer exact pinyin+text removal when key is available, but also clear
    // all rows by phrase text so legacy polluted variants are removed together.
    if (text = '') or (not ensure_open) or (not m_user_ready) then Exit;
    aliases := TList<string>.Create;
    try
        aliases.Add(text);
        if m_user_script_enabled then
        begin
            stmt := nil;
            try
                if m_user_connection.prepare(
                    'SELECT pinyin, text FROM dict_user UNION ' +
                    'SELECT pinyin, text FROM dict_user_literal UNION ' +
                    'SELECT pinyin, text FROM dict_user_stats', stmt) then
                    while m_user_connection.step(stmt) = SQLITE_ROW do
                    begin
                        stored_pinyin := m_user_connection.column_text(stmt, 0);
                        stored := m_user_connection.column_text(stmt, 1);
                        if (not aliases.Contains(stored)) and
                            (user_text_for_script(stored_pinyin, stored) = text) then
                            aliases.Add(stored);
                    end;
            finally
                if stmt <> nil then m_user_connection.finalize(stmt);
            end;
        end;
        for stored in aliases do
            purge_user_entry_internal(pinyin, stored, True, True);
    finally
        aliases.Free;
    end;
end;

function TncSqliteDictionary.clear_user_dictionary: Boolean;
var
    transaction_active: Boolean;
begin
    Result := False;
    if (not ensure_open) or (not m_user_ready) or (m_user_connection = nil) then
    begin
        Exit;
    end;

    if m_write_batch_depth > 0 then
    begin
        rollback_learning_batch;
    end;
    clear_cached_user_statements;

    transaction_active := False;
    try
        if not m_user_connection.exec('BEGIN IMMEDIATE TRANSACTION;') then
        begin
            Exit;
        end;
        transaction_active := True;

        if (not m_user_connection.exec('DELETE FROM dict_user;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_literal;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_stats;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_fuzzy_choice;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_query_latest;')) or
            (not m_user_connection.exec(
                'DELETE FROM dict_user_context_query_choice;')) or
            (not m_user_connection.exec(
                'DELETE FROM dict_user_completion_feedback;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_penalty;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_bigram;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_trigram;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_query_path;')) or
            (not m_user_connection.exec('DELETE FROM dict_user_query_path_penalty;')) or
            (not m_user_connection.exec(
                'DELETE FROM sqlite_sequence WHERE name = ''dict_user'';')) then
        begin
            Exit;
        end;

        if not m_user_connection.exec('COMMIT;') then
        begin
            Exit;
        end;
        transaction_active := False;

        m_bigram_prune_countdown := 64;
        m_trigram_prune_countdown := 64;
        m_query_path_prune_countdown := 64;
        m_query_path_penalty_prune_countdown := 64;
        m_context_query_choice_prune_countdown := 64;
        note_user_data_changed;
        m_literal_user_words_available := 0;
        Result := True;
    finally
        if transaction_active then
        begin
            m_user_connection.exec('ROLLBACK;');
            clear_user_read_caches;
        end;
    end;
end;

end.
