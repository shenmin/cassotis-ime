unit nc_engine_intf;

interface

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.SyncObjs,
    System.Generics.Collections,
    System.Generics.Defaults,
    Winapi.Windows,
    nc_types,
    nc_dictionary_intf,
    nc_dictionary_sqlite,
    nc_ai_intf,
    nc_ai_null,
    nc_ai_llama,
    nc_candidate_fusion,
    nc_pinyin_parser;

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
        m_candidates: TncCandidateList;
        m_dictionary: TncDictionaryProvider;
        m_ai_provider: TncAiProvider;
        m_dictionary_path: string;
        m_dictionary_write_time: TDateTime;
        m_user_dictionary_path: string;
        m_user_dictionary_write_time: TDateTime;
        m_left_context: string;
        m_external_left_context: string;
        m_segment_left_context: string;
        m_context_pairs: TDictionary<string, Integer>;
        m_context_order: TQueue<string>;
        m_phrase_context_pairs: TDictionary<string, Integer>;
        m_phrase_context_order: TQueue<string>;
        m_session_text_counts: TDictionary<string, Integer>;
        m_session_text_last_seen: TDictionary<string, Int64>;
        m_session_text_order: TQueue<string>;
        m_session_commit_serial: Int64;
        m_last_output_commit_text: string;
        m_prev_output_commit_text: string;
        m_context_db_bonus_cache_key: string;
        m_context_db_bonus_cache: TDictionary<string, Integer>;
        m_pending_commit_text: string;
        m_pending_commit_remaining: string;
        m_has_pending_commit: Boolean;
        m_pending_commit_allow_learning: Boolean;
        m_last_lookup_key: string;
        m_last_lookup_normalized_from: string;
        m_last_lookup_syllable_count: Integer;
        m_last_lookup_debug_extra: string;
        m_runtime_chain_text: string;
        m_single_quote_open: Boolean;
        m_double_quote_open: Boolean;
        m_page_index: Integer;
        m_selected_index: Integer;
        m_confirmed_text: string;
        m_confirmed_segments: TList<TncConfirmedSegment>;
        function is_alpha_key(const key_code: Word; out out_char: Char): Boolean;
        function get_candidate_limit: Integer;
        function get_total_candidate_limit: Integer;
        function create_dictionary_from_config: TncDictionaryProvider;
        function create_ai_provider_from_config: TncAiProvider;
        function get_active_dictionary_path: string;
        function get_dictionary_write_time(const path: string): TDateTime;
        function get_page_count_internal(const page_size: Integer): Integer;
        procedure normalize_page_and_selection;
        function get_source_rank(const source: TncCandidateSource): Integer;
        function get_context_variants(const context_text: string): TArray<string>;
        function get_session_text_bonus(const candidate_text: string): Integer;
        function get_phrase_context_bonus(const candidate_text: string): Integer;
        function get_text_context_bonus(const candidate_text: string): Integer;
        function get_context_bonus(const candidate_text: string): Integer;
        function get_candidate_debug_summary(const candidate: TncCandidate): string;
        function get_punctuation_char(const key_code: Word; const key_state: TncKeyState; out out_char: Char): Boolean;
        function map_full_width_char(const input_char: Char): string;
        function map_punctuation_char(const input_char: Char): string;
        function get_candidate_text_unit_count(const text: string): Integer;
        function get_multi_syllable_intent_layer(const candidate: TncCandidate): Integer;
        function get_rank_score(const candidate: TncCandidate): Integer;
        function compare_candidates(const left: TncCandidate; const right: TncCandidate): Integer;
        procedure sort_candidates(var candidates: TncCandidateList);
        function normalize_pinyin_text(const input_text: string): string;
        function is_valid_pinyin_syllable(const syllable: string): Boolean;
        function is_full_pinyin_key(const value: string): Boolean;
        function normalize_adjacent_swap_typo(const value: string): string;
        function split_text_units(const input_text: string): TArray<string>;
        function is_common_surname_text(const value: string): Boolean;
        function ai_candidate_matches_pinyin(const candidate_text: string; const pinyin_text: string): Boolean;
        procedure filter_ai_candidates_by_pinyin(var candidates: TncCandidateList; const pinyin_text: string);
        procedure ensure_non_ai_first(var candidates: TncCandidateList);
        function merge_candidate_lists(const primary_candidates: TncCandidateList;
            const secondary_candidates: TncCandidateList; const max_candidates: Integer): TncCandidateList;
        procedure build_candidates;
        function build_segment_candidates(out out_candidates: TncCandidateList;
            const include_full_path: Boolean = True): Boolean;
        function build_pinyin_comment(const input_text: string): string;
        procedure update_segment_left_context;
        procedure push_confirmed_segment(const text: string; const pinyin: string);
        function pop_confirmed_segment(out out_segment: TncConfirmedSegment): Boolean;
        procedure rebuild_confirmed_text;
        function rollback_last_segment: Boolean;
        procedure apply_partial_commit(const selected_text: string; const remaining_pinyin: string);
        procedure update_left_context(const committed_text: string);
        procedure record_context_pair(const left_text: string; const committed_text: string);
        procedure note_session_commit(const text: string);
        procedure note_output_phrase_context(const committed_text: string);
        procedure set_pending_commit(const text: string; const remaining_pinyin: string = '';
            const allow_learning: Boolean = True);
        procedure clear_pending_commit;
        procedure set_ai_provider(const provider: TncAiProvider);
        procedure update_dictionary_state;
        procedure toggle_input_mode;
        function get_ai_candidates(out out_candidates: TncCandidateList): Boolean;
    public
        constructor create(const config: TncEngineConfig);
        destructor Destroy; override;
        procedure reset;
        procedure update_config(const config: TncEngineConfig);
        procedure set_dictionary_provider(const dictionary: TncDictionaryProvider);
        procedure set_dictionary_path(const dictionary_path: string);
        procedure reload_dictionary_if_needed;
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
        function get_lookup_debug_info: string;
        function get_dictionary_debug_info: string;
        function refresh_ai_candidates_if_ready(out out_candidates: TncCandidateList; out page_index: Integer;
            out page_count: Integer; out selected_index: Integer; out preedit_text: string): Boolean;
        function should_handle_key(const key_code: Word; const key_state: TncKeyState): Boolean;
        function commit_text(out out_text: string): Boolean;
        function remove_user_candidate(const pinyin: string; const text: string): Boolean;
        property config: TncEngineConfig read m_config write update_config;
    end;

implementation

const
    c_default_page_size = 9;
    c_default_total_limit = 30;
    c_default_ai_timeout_ms = 1200;
    c_candidate_total_expand_factor = 16;
    c_candidate_total_limit_max = 256;
    c_user_score_bonus = 1000;
    c_ai_score_penalty = 20;
    c_partial_candidate_score_penalty = 260;
    c_left_context_max_len = 20;
    c_context_history_limit = 200;
    c_phrase_context_history_limit = 256;
    c_context_score_bonus = 80;
    c_context_score_bonus_max = 400;
    c_session_text_history_limit = 256;
    c_full_width_offset = $FEE0;
    c_segment_surname_bonus = 110;

type
    TncAiSharedProvider = class(TncAiProvider)
    private
        m_config: TncEngineConfig;
    public
        constructor create(const config: TncEngineConfig);
        function request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean; override;
    end;

var
    g_shared_ai_lock: TCriticalSection = nil;
    g_shared_ai_provider: TncAiProvider = nil;
    g_shared_ai_signature: string = '';
    g_shared_ai_retry_after_tick: UInt64 = 0;

const
    c_shared_ai_retry_interval_ms = 5000;

function build_ai_provider_signature(const config: TncEngineConfig): string;
begin
    Result := Format('%d|%s|%s|%s',
        [Ord(config.ai_llama_backend), LowerCase(Trim(config.ai_llama_runtime_dir_cpu)),
        LowerCase(Trim(config.ai_llama_runtime_dir_cuda)), LowerCase(Trim(config.ai_llama_model_path))]);
end;

function ensure_shared_ai_provider_locked(const config: TncEngineConfig): TncAiProvider;
var
    signature: string;
    now_tick: UInt64;
begin
    signature := build_ai_provider_signature(config);
    if (g_shared_ai_provider <> nil) and (g_shared_ai_signature = signature) and (g_shared_ai_provider is TncAiLlamaProvider) then
    begin
        if not TncAiLlamaProvider(g_shared_ai_provider).ready then
        begin
            now_tick := GetTickCount64;
            if now_tick >= g_shared_ai_retry_after_tick then
            begin
                g_shared_ai_provider.Free;
                g_shared_ai_provider := nil;
            end;
        end;
    end;

    if (g_shared_ai_provider = nil) or (g_shared_ai_signature <> signature) then
    begin
        if g_shared_ai_provider <> nil then
        begin
            g_shared_ai_provider.Free;
            g_shared_ai_provider := nil;
        end;

        g_shared_ai_signature := signature;
        try
            g_shared_ai_provider := TncAiLlamaProvider.create(config);
            if (g_shared_ai_provider is TncAiLlamaProvider) and (not TncAiLlamaProvider(g_shared_ai_provider).ready) then
            begin
                g_shared_ai_retry_after_tick := GetTickCount64 + c_shared_ai_retry_interval_ms;
            end
            else
            begin
                g_shared_ai_retry_after_tick := 0;
            end;
        except
            on e: Exception do
            begin
                OutputDebugString(PChar(Format('[engine] Shared AI provider create failed %s: %s, fallback to null provider',
                    [e.ClassName, e.Message])));
                g_shared_ai_provider := TncAiNullProvider.create;
                g_shared_ai_retry_after_tick := 0;
            end;
        end;
    end;

    Result := g_shared_ai_provider;
end;

constructor TncAiSharedProvider.create(const config: TncEngineConfig);
begin
    inherited create;
    m_config := config;
end;

function TncAiSharedProvider.request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean;
var
    provider: TncAiProvider;
begin
    SetLength(response.candidates, 0);
    response.success := False;
    Result := False;

    if g_shared_ai_lock = nil then
    begin
        Exit;
    end;

    g_shared_ai_lock.Acquire;
    try
        provider := ensure_shared_ai_provider_locked(m_config);
        if provider = nil then
        begin
            Exit;
        end;

        Result := provider.request_suggestions(request, response);
    finally
        g_shared_ai_lock.Release;
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
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_last_lookup_key := '';
    m_last_lookup_normalized_from := '';
    m_last_lookup_syllable_count := 0;
    m_last_lookup_debug_extra := '';
    m_runtime_chain_text := '';
    m_single_quote_open := False;
    m_double_quote_open := False;
    m_page_index := 0;
    m_selected_index := 0;
    m_confirmed_text := '';
    m_dictionary_path := '';
    m_dictionary_write_time := 0;
    m_user_dictionary_path := '';
    m_user_dictionary_write_time := 0;
    m_left_context := '';
    m_segment_left_context := '';
    m_confirmed_segments := TList<TncConfirmedSegment>.Create;
    m_context_pairs := TDictionary<string, Integer>.Create;
    m_context_order := TQueue<string>.Create;
    m_phrase_context_pairs := TDictionary<string, Integer>.Create;
    m_phrase_context_order := TQueue<string>.Create;
    m_session_text_counts := TDictionary<string, Integer>.Create;
    m_session_text_last_seen := TDictionary<string, Int64>.Create;
    m_session_text_order := TQueue<string>.Create;
    m_session_commit_serial := 0;
    m_last_output_commit_text := '';
    m_prev_output_commit_text := '';
    m_context_db_bonus_cache_key := '';
    m_context_db_bonus_cache := TDictionary<string, Integer>.Create;
    SetLength(m_candidates, 0);
    set_dictionary_provider(create_dictionary_from_config);
    set_ai_provider(create_ai_provider_from_config);
end;

destructor TncEngine.Destroy;
begin
    if m_ai_provider <> nil then
    begin
        m_ai_provider.Free;
        m_ai_provider := nil;
    end;

    if m_dictionary <> nil then
    begin
        m_dictionary.Free;
        m_dictionary := nil;
    end;

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

    if m_session_text_order <> nil then
    begin
        m_session_text_order.Free;
        m_session_text_order := nil;
    end;

    if m_session_text_last_seen <> nil then
    begin
        m_session_text_last_seen.Free;
        m_session_text_last_seen := nil;
    end;

    if m_context_db_bonus_cache <> nil then
    begin
        m_context_db_bonus_cache.Free;
        m_context_db_bonus_cache := nil;
    end;
    m_context_db_bonus_cache_key := '';

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

    inherited Destroy;
end;

procedure TncEngine.reset;
var
    ai_request: TncAiRequest;
    ai_response: TncAiResponse;
begin
    m_composition_text := '';
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_last_lookup_key := '';
    m_last_lookup_normalized_from := '';
    m_last_lookup_syllable_count := 0;
    m_last_lookup_debug_extra := '';
    m_runtime_chain_text := '';
    m_page_index := 0;
    m_selected_index := 0;
    m_confirmed_text := '';
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

    if m_ai_provider <> nil then
    begin
        ai_request.context.composition_text := '';
        ai_request.context.left_context := '';
        ai_request.max_suggestions := 0;
        ai_request.timeout_ms := 0;
        SetLength(ai_response.candidates, 0);
        ai_response.success := False;
        m_ai_provider.request_suggestions(ai_request, ai_response);
    end;
end;

procedure TncEngine.update_config(const config: TncEngineConfig);
var
    dictionary_changed: Boolean;
    ai_changed: Boolean;
begin
    dictionary_changed :=
        (m_config.dictionary_variant <> config.dictionary_variant) or
        (m_config.dictionary_path_simplified <> config.dictionary_path_simplified) or
        (m_config.dictionary_path_traditional <> config.dictionary_path_traditional) or
        (m_config.user_dictionary_path <> config.user_dictionary_path);
    ai_changed :=
        (m_config.enable_ai <> config.enable_ai) or
        (m_config.ai_llama_backend <> config.ai_llama_backend) or
        (m_config.ai_llama_runtime_dir_cpu <> config.ai_llama_runtime_dir_cpu) or
        (m_config.ai_llama_runtime_dir_cuda <> config.ai_llama_runtime_dir_cuda) or
        (m_config.ai_llama_model_path <> config.ai_llama_model_path) or
        (m_config.ai_request_timeout_ms <> config.ai_request_timeout_ms);
    m_config := config;
    if dictionary_changed then
    begin
        set_dictionary_provider(create_dictionary_from_config);
    end;
    if ai_changed then
    begin
        set_ai_provider(create_ai_provider_from_config);
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
    m_context_db_bonus_cache_key := '';
    if m_context_db_bonus_cache <> nil then
    begin
        m_context_db_bonus_cache.Clear;
    end;
    update_dictionary_state;
end;

procedure TncEngine.set_dictionary_path(const dictionary_path: string);
var
    next_config: TncEngineConfig;
begin
    next_config := m_config;
    if m_config.dictionary_variant = dv_traditional then
    begin
        next_config.dictionary_path_traditional := dictionary_path;
    end
    else
    begin
        next_config.dictionary_path_simplified := dictionary_path;
    end;
    update_config(next_config);
end;

procedure TncEngine.set_ai_provider(const provider: TncAiProvider);
begin
    if m_ai_provider = provider then
    begin
        Exit;
    end;

    if m_ai_provider <> nil then
    begin
        m_ai_provider.Free;
    end;

    m_ai_provider := provider;
end;

function TncEngine.get_ai_candidates(out out_candidates: TncCandidateList): Boolean;
var
    ai_request: TncAiRequest;
    ai_response: TncAiResponse;
    raw_count: Integer;
begin
    SetLength(out_candidates, 0);
    if (m_ai_provider = nil) or (m_composition_text = '') then
    begin
        Result := False;
        Exit;
    end;
    // AI candidate generation is most reliable on complete full-pinyin input.
    // Skip partial/abbreviated composition to reduce noisy asynchronous outputs.
    if not is_full_pinyin_key(m_composition_text) then
    begin
        Result := False;
        Exit;
    end;

    ai_request.context.composition_text := m_composition_text;
    ai_request.context.left_context := m_left_context;
    ai_request.max_suggestions := get_candidate_limit;
    ai_request.timeout_ms := m_config.ai_request_timeout_ms;
    if ai_request.timeout_ms <= 0 then
    begin
        ai_request.timeout_ms := c_default_ai_timeout_ms;
    end;

    Result := m_ai_provider.request_suggestions(ai_request, ai_response);
    if not Result or not ai_response.success then
    begin
        Result := False;
        Exit;
    end;

    out_candidates := ai_response.candidates;
    raw_count := Length(out_candidates);
    filter_ai_candidates_by_pinyin(out_candidates, ai_request.context.composition_text);
    if (raw_count > 0) and (Length(out_candidates) = 0) then
    begin
        OutputDebugString(PChar(Format('[engine] AI candidates filtered to zero query=%s raw=%d',
            [ai_request.context.composition_text, raw_count])));
    end;
    Result := Length(out_candidates) > 0;
end;

function TncEngine.is_alpha_key(const key_code: Word; out out_char: Char): Boolean;
begin
    if (key_code >= Ord('A')) and (key_code <= Ord('Z')) then
    begin
        out_char := Char(key_code + Ord('a') - Ord('A'));
        Result := True;
        Exit;
    end;

    Result := False;
end;

function TncEngine.get_candidate_limit: Integer;
begin
    if m_config.max_candidates > 0 then
    begin
        Result := m_config.max_candidates;
        Exit;
    end;

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
begin
    base_path := get_active_dictionary_path;
    if base_path <> '' then
    begin
        sqlite_dict := TncSqliteDictionary.create(base_path, m_config.user_dictionary_path);
        if sqlite_dict.open then
        begin
            Result := sqlite_dict;
            Exit;
        end;

        sqlite_dict.Free;
    end;

    Result := TncInMemoryDictionary.create;
end;

function TncEngine.create_ai_provider_from_config: TncAiProvider;
begin
    if not m_config.enable_ai then
    begin
        Result := TncAiNullProvider.create;
        Exit;
    end;

    try
        Result := TncAiSharedProvider.create(m_config);
    except
        on e: Exception do
        begin
            OutputDebugString(PChar(Format('[engine] AI provider create failed %s: %s, fallback to null provider',
                [e.ClassName, e.Message])));
            Result := TncAiNullProvider.create;
        end;
    end;
end;

function TncEngine.get_active_dictionary_path: string;
begin
    if m_config.dictionary_variant = dv_traditional then
    begin
        Result := m_config.dictionary_path_traditional;
    end
    else
    begin
        Result := m_config.dictionary_path_simplified;
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
        m_user_dictionary_path := m_config.user_dictionary_path;
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
var
    current_write_time: TDateTime;
    user_write_time: TDateTime;
begin
    if (m_dictionary_path = '') and (m_user_dictionary_path = '') then
    begin
        Exit;
    end;

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

procedure TncEngine.build_candidates;
var
    raw_candidates: TncCandidateList;
    segment_candidates: TncCandidateList;
    full_lookup_candidates: TncCandidateList;
    ai_candidates: TncCandidateList;
    fusion: TncCandidateFusion;
    limit: Integer;
    i: Integer;
    fallback_comment: string;
    has_raw_candidates: Boolean;
    has_segment_candidates: Boolean;
    raw_from_dictionary: Boolean;
    lookup_text: string;
    has_multi_syllable_input: Boolean;
    has_internal_dangling_initial: Boolean;
    head_only_multi_syllable: Boolean;
    input_syllable_count: Integer;
    multi_syllable_cap_limit: Integer;
    normalized_lookup_text: string;
    repeated_two_syllable_query: Boolean;
    single_char_partial_min_count: Integer;
    runtime_phrase_added: Boolean;
    runtime_redup_added: Boolean;

    procedure clear_candidate_comments(var candidates: TncCandidateList);
    var
        idx: Integer;
    begin
        for idx := 0 to High(candidates) do
        begin
            candidates[idx].comment := '';
        end;
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

    function get_input_syllable_count_for_text(const pinyin_text: string): Integer;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
    begin
        Result := 0;
        if pinyin_text = '' then
        begin
            Exit;
        end;

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(pinyin_text);
            Result := Length(syllables);
        finally
            parser.Free;
        end;
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
    var
        candidate_text: string;
        filtered: TncCandidateList;
        text_units: Integer;
        non_user_count: Integer;
        input_syllables: Integer;
        idx: Integer;
    begin
        if (m_dictionary = nil) or (pinyin_key = '') then
        begin
            Exit;
        end;

        if not m_dictionary.lookup(pinyin_key, full_lookup_candidates) then
        begin
            Exit;
        end;

        if Length(full_lookup_candidates) = 0 then
        begin
            Exit;
        end;

        clear_candidate_comments(full_lookup_candidates);
        input_syllables := get_input_syllable_count_for_text(pinyin_key);
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

    function try_build_best_single_char_chain(out out_candidate: TncCandidate): Boolean;
    const
        c_chain_min_syllables = 2;
        c_chain_bonus = 160;
        c_chain_penalty_per_syllable = 28;
    var
        parser: TncPinyinParser;
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

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(m_composition_text);
        finally
            parser.Free;
        end;

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

            if not m_dictionary.lookup(syllable_text, local_lookup) then
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

        if not m_dictionary.lookup(syllables[0].text, local_lookup) then
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
            if not m_dictionary.lookup(syllable_text, local_lookup) then
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

        function try_match_expected_units(out out_units: TArray<string>): Boolean;
        begin
            SetLength(out_units, 0);
            if Length(syllables) <> 2 then
            begin
                Exit(False);
            end;

            if syllable_equals(syllables[0].text, 'zhe') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($4E2A)));
            end
            else if ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'ge')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'yi') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E00)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'liang') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E24)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'ji') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($51E0)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'mei') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($6BCF)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'san') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E09)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'si') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($56DB)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'wu') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E94)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'liu') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($516D)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'qi') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E03)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'ba') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($516B)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'jiu') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($4E5D)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'shi') and syllable_equals(syllables[1].text, 'ge') then
            begin
                out_units := TArray<string>.Create(string(Char($5341)), string(Char($4E2A)));
            end
            else if syllable_equals(syllables[0].text, 'zhe') and syllable_equals(syllables[1].text, 'xie') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($4E9B)));
            end
            else if ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'xie')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($4E9B)));
            end
            else if syllable_equals(syllables[0].text, 'yi') and syllable_equals(syllables[1].text, 'xie') then
            begin
                out_units := TArray<string>.Create(string(Char($4E00)), string(Char($4E9B)));
            end
            else if syllable_equals(syllables[0].text, 'zhe') and syllable_equals(syllables[1].text, 'yang') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($6837)));
            end
            else if ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'yang')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($6837)));
            end
            else if syllable_equals(syllables[0].text, 'zhe') and syllable_equals(syllables[1].text, 'me') then
            begin
                out_units := TArray<string>.Create(string(Char($8FD9)), string(Char($4E48)));
            end
            else if ((syllable_equals(syllables[0].text, 'na') or syllable_equals(syllables[0].text, 'nei')) and
                syllable_equals(syllables[1].text, 'me')) then
            begin
                out_units := TArray<string>.Create(string(Char($90A3)), string(Char($4E48)));
            end
            else if syllable_equals(syllables[0].text, 'zen') and syllable_equals(syllables[1].text, 'me') then
            begin
                out_units := TArray<string>.Create(string(Char($600E)), string(Char($4E48)));
            end
            else if syllable_equals(syllables[0].text, 'you') and syllable_equals(syllables[1].text, 'dian') then
            begin
                out_units := TArray<string>.Create(string(Char($6709)), string(Char($70B9)));
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
            Exit;
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

    procedure merge_runtime_constructed_candidates(var candidates: TncCandidateList);
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

    var
        runtime_candidates: TncCandidateList;
        runtime_item: TncCandidate;
        runtime_count: Integer;
    begin
        runtime_phrase_added := False;
        runtime_redup_added := False;
        if (not has_multi_syllable_input) or (input_syllable_count < 2) or (input_syllable_count > 4) then
        begin
            Exit;
        end;

        runtime_count := 0;
        SetLength(runtime_candidates, 0);

        if (input_syllable_count = 2) and
            (not has_complete_bmp_cjk_phrase_candidate(candidates)) and
            try_build_runtime_chain_candidate(runtime_item) then
        begin
            SetLength(runtime_candidates, runtime_count + 1);
            runtime_candidates[runtime_count] := runtime_item;
            Inc(runtime_count);
            runtime_phrase_added := True;
            m_runtime_chain_text := runtime_item.text;
        end;

        if try_build_runtime_common_pattern_candidate(runtime_item) then
        begin
            SetLength(runtime_candidates, runtime_count + 1);
            runtime_candidates[runtime_count] := runtime_item;
            Inc(runtime_count);
            runtime_phrase_added := True;
        end;

        if try_build_runtime_redup_candidate(runtime_item) then
        begin
            SetLength(runtime_candidates, runtime_count + 1);
            runtime_candidates[runtime_count] := runtime_item;
            Inc(runtime_count);
            runtime_phrase_added := True;
            runtime_redup_added := True;
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

    procedure ensure_forced_single_char_partial(var candidates: TncCandidateList);
    const
        c_forced_partial_penalty_per_syllable = 120;
        c_forced_partial_prefix_bonus = 80;
        // Keep a broader single-char fallback pool so medium-rank common chars
        // (e.g. "鐠? under "shi") are not dropped too early.
        c_forced_partial_max_candidates = 64;
    var
        parser: TncPinyinParser;
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

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(m_composition_text);
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
        for idx := 1 to High(syllables) do
        begin
            remaining_pinyin := remaining_pinyin + syllables[idx].text;
        end;
        if remaining_pinyin = '' then
        begin
            Exit;
        end;

        if not m_dictionary.lookup(first_syllable, fallback_lookup) then
        begin
            Exit;
        end;

        trailing_count := Length(syllables) - 1;
        for pass_idx := 0 to 1 do
        begin
            prefer_common_single_char := pass_idx = 0;
            SetLength(forced_list, 0);
            forced_count := 0;
            for idx := 0 to High(fallback_lookup) do
            begin
                source_item := fallback_lookup[idx];
                if not is_single_text_unit(Trim(source_item.text)) then
                begin
                    Continue;
                end;
                if prefer_common_single_char and
                    (not is_preferred_partial_single_char_candidate(source_item)) then
                begin
                    Continue;
                end;

                forced_item := source_item;
                forced_item.comment := remaining_pinyin;
                forced_item.score := source_item.score + c_forced_partial_prefix_bonus -
                    (trailing_count * c_forced_partial_penalty_per_syllable);

                SetLength(forced_list, forced_count + 1);
                forced_list[forced_count] := forced_item;
                Inc(forced_count);
                if forced_count >= c_forced_partial_max_candidates then
                begin
                    Break;
                end;
            end;

            if forced_count > 0 then
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

    function try_build_primary_single_char_partial(out out_candidate: TncCandidate): Boolean;
    const
        c_forced_partial_penalty_per_syllable = 120;
        c_forced_partial_prefix_bonus = 80;
    var
        parser: TncPinyinParser;
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

        parser := TncPinyinParser.create;
        try
            syllables := parser.parse(m_composition_text);
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
        for idx := 1 to High(syllables) do
        begin
            remaining_pinyin := remaining_pinyin + syllables[idx].text;
        end;
        if remaining_pinyin = '' then
        begin
            Exit;
        end;

        if not m_dictionary.lookup(first_syllable, fallback_lookup) then
        begin
            Exit;
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
        Result := True;
    end;

    procedure ensure_hard_single_char_partial_visible(var candidates: TncCandidateList);
    var
        visible_limit: Integer;
        i: Integer;
        partial_index: Integer;
        target_index: Integer;
        partial_candidate: TncCandidate;
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

        best_index := -1;
        best_score := Low(Integer);
        for i := 0 to High(candidates) do
        begin
            if (candidates[i].comment <> '') and is_single_text_unit(Trim(candidates[i].text)) then
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

        // Keep a practical single-char continuation visible, but avoid occupying
        // the very front on longer queries where phrase intent is stronger.
        if input_syllable_count >= 4 then
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
        if not m_dictionary.lookup(full_query, full_candidates) then
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
        syllable_gap: Integer;
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
                Break;
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
            end
            else if (candidates[idx].comment = '') and (input_syllables >= 3) and (text_units = 1) then
            begin
                Dec(candidates[idx].score, c_single_char_complete_penalty);
            end
            else if candidates[idx].comment <> '' then
            begin
                Dec(candidates[idx].score, c_partial_with_complete_penalty);
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
            syllables := parser.parse(m_composition_text);
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

                if not m_dictionary.lookup(syllables[syllable_idx].text, lookup_results) then
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
    SetLength(m_candidates, 0);
    m_last_lookup_key := '';
    m_last_lookup_normalized_from := '';
    m_last_lookup_syllable_count := 0;
    m_last_lookup_debug_extra := '';
    m_runtime_chain_text := '';
    if m_composition_text = '' then
    begin
        Exit;
    end;

    has_raw_candidates := False;
    has_segment_candidates := False;
    raw_from_dictionary := False;
    lookup_text := normalize_pinyin_text(m_composition_text);
    if not is_full_pinyin_key(lookup_text) then
    begin
        normalized_lookup_text := normalize_adjacent_swap_typo(lookup_text);
        if (normalized_lookup_text <> '') and (not SameText(normalized_lookup_text, lookup_text)) then
        begin
            m_last_lookup_normalized_from := lookup_text;
            lookup_text := normalized_lookup_text;
        end;
    end;
    m_last_lookup_key := lookup_text;
    fallback_comment := build_pinyin_comment(m_composition_text);
    if fallback_comment = '' then
    begin
        fallback_comment := build_pinyin_comment(lookup_text);
    end;
    has_multi_syllable_input := fallback_comment <> '';
    has_internal_dangling_initial := detect_internal_dangling_initial(m_composition_text);
    if m_last_lookup_normalized_from <> '' then
    begin
        // If lookup key is typo-normalized (e.g. chagn->chang), segmenting by raw input
        // is usually noisy; force dangling-initial guard to suppress that path.
        has_internal_dangling_initial := True;
    end;
    input_syllable_count := get_input_syllable_count_for_text(m_composition_text);
    if input_syllable_count <= 0 then
    begin
        input_syllable_count := get_input_syllable_count_for_text(lookup_text);
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
    head_only_multi_syllable := m_config.enable_segment_candidates and
        has_multi_syllable_input and
        m_config.segment_head_only_multi_syllable and
        (not has_internal_dangling_initial);
    if m_dictionary <> nil then
    begin
        if head_only_multi_syllable and build_segment_candidates(segment_candidates, False) then
        begin
            has_raw_candidates := True;
            has_segment_candidates := True;
            raw_candidates := segment_candidates;
            merge_head_only_full_lookup_candidates(raw_candidates, lookup_text);
        end
        else if m_dictionary.lookup(lookup_text, raw_candidates) then
        begin
            has_raw_candidates := True;
            raw_from_dictionary := True;
        end
        else if m_config.enable_segment_candidates and build_segment_candidates(segment_candidates, True) then
        begin
            has_raw_candidates := True;
            has_segment_candidates := True;
            raw_candidates := segment_candidates;
        end;
    end;

    if has_raw_candidates then
    begin
        if raw_from_dictionary then
        begin
            clear_candidate_comments(raw_candidates);
        end;

        sort_candidates(raw_candidates);
        if m_config.enable_segment_candidates and raw_from_dictionary and (not has_internal_dangling_initial) then
        begin
            if not has_segment_candidates then
            begin
                // For dictionary-hit multi-syllable input, still build full-path segment candidates
                // so head-first constraints can suppress noisy direct lexicon matches.
                has_segment_candidates := build_segment_candidates(segment_candidates, True);
            end;

            if has_segment_candidates then
            begin
                raw_candidates := merge_candidate_lists(raw_candidates, segment_candidates, 0);
                ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
                ensure_single_char_partial_visible(raw_candidates, get_candidate_limit,
                    single_char_partial_min_count);
            end;
        end;

        // Even when segment candidates are disabled or fail to build, multi-syllable input
        // must keep a single-char partial fallback (e.g. "hai" + "budaxing").
        if has_multi_syllable_input then
        begin
            ensure_forced_single_char_partial(raw_candidates);
            merge_runtime_constructed_candidates(raw_candidates);
            sort_candidates(raw_candidates);
            ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
            ensure_single_char_partial_visible(raw_candidates, get_candidate_limit,
                single_char_partial_min_count);
        end;

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
            if (multi_syllable_cap_limit > 0) and (limit > multi_syllable_cap_limit) then
            begin
                limit := multi_syllable_cap_limit;
            end;
        end;

        ensure_redup_complete_candidate_visible(raw_candidates, limit);

        if m_config.enable_ai and get_ai_candidates(ai_candidates) then
        begin
            clear_candidate_comments(ai_candidates);
            fusion := TncCandidateFusion.create;
            try
                m_candidates := fusion.merge_candidates(raw_candidates, ai_candidates, 0);
            finally
                fusion.Free;
            end;
            sort_candidates(m_candidates);
            ensure_partial_fallback_visible(m_candidates, get_candidate_limit);
            ensure_single_char_partial_visible(m_candidates, get_candidate_limit,
                single_char_partial_min_count);
            ensure_redup_complete_candidate_visible(m_candidates, limit);
            if Length(m_candidates) > limit then
            begin
                SetLength(m_candidates, limit);
            end;
            ensure_non_ai_first(m_candidates);
        end
        else
        begin
            if Length(raw_candidates) > limit then
            begin
                SetLength(m_candidates, limit);
                for i := 0 to limit - 1 do
                begin
                    m_candidates[i] := raw_candidates[i];
                end;
            end
            else
            begin
                m_candidates := raw_candidates;
            end;
        end;

        merge_confirmed_prefix_user_extensions(m_candidates);
        apply_user_penalties(lookup_text, m_candidates);
        prioritize_complete_phrase_matches(m_candidates);
        apply_syllable_single_char_alignment_bonus(m_candidates);
        sort_candidates(m_candidates);
        ensure_partial_fallback_visible(m_candidates, get_candidate_limit);
        ensure_single_char_partial_visible(m_candidates, get_candidate_limit, single_char_partial_min_count);
        ensure_hard_single_char_partial_visible(m_candidates);
        ensure_redup_complete_candidate_visible(m_candidates, get_candidate_limit);
        ensure_non_ai_first(m_candidates);
        m_last_lookup_debug_extra := Format('multi=%d seg=%d dangling=%d head_only=%d runtime=%d redup=%d',
            [Ord(has_multi_syllable_input), Ord(has_segment_candidates), Ord(has_internal_dangling_initial),
            Ord(head_only_multi_syllable), Ord(runtime_phrase_added), Ord(runtime_redup_added)]);
        if Length(m_candidates) > 0 then
        begin
            m_last_lookup_debug_extra := m_last_lookup_debug_extra + ' ' +
                get_candidate_debug_summary(m_candidates[0]);
        end;
        m_page_index := 0;
        m_selected_index := 0;
        Exit;
    end;

    if m_config.enable_ai and get_ai_candidates(ai_candidates) then
    begin
        clear_candidate_comments(ai_candidates);
        sort_candidates(ai_candidates);
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
        if Length(ai_candidates) > limit then
        begin
            SetLength(ai_candidates, limit);
        end;

        m_candidates := ai_candidates;
        apply_user_penalties(lookup_text, m_candidates);
        sort_candidates(m_candidates);
        m_last_lookup_debug_extra := Format('multi=%d seg=%d dangling=%d head_only=%d runtime=%d redup=%d ai_only=1',
            [Ord(has_multi_syllable_input), 0, Ord(has_internal_dangling_initial),
            Ord(head_only_multi_syllable), Ord(runtime_phrase_added), Ord(runtime_redup_added)]);
        if Length(m_candidates) > 0 then
        begin
            m_last_lookup_debug_extra := m_last_lookup_debug_extra + ' ' +
                get_candidate_debug_summary(m_candidates[0]);
        end;
        m_page_index := 0;
        m_selected_index := 0;
        Exit;
    end;

    SetLength(m_candidates, 1);
    m_candidates[0].text := m_composition_text;
    m_candidates[0].comment := fallback_comment;
    m_candidates[0].score := 0;
    m_candidates[0].source := cs_rule;
    m_candidates[0].has_dict_weight := False;
    m_candidates[0].dict_weight := 0;
    m_last_lookup_debug_extra := Format('multi=%d seg=0 dangling=%d head_only=%d runtime=%d redup=%d fallback=1',
        [Ord(has_multi_syllable_input), Ord(has_internal_dangling_initial), Ord(head_only_multi_syllable),
        Ord(runtime_phrase_added), Ord(runtime_redup_added)]);
    if Length(m_candidates) > 0 then
    begin
        m_last_lookup_debug_extra := m_last_lookup_debug_extra + ' ' +
            get_candidate_debug_summary(m_candidates[0]);
    end;
    m_page_index := 0;
    m_selected_index := 0;
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
        cs_ai:
            Result := 2;
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
    Result := 0;
    if m_session_text_counts = nil then
    begin
        Exit;
    end;

    text_key := Trim(candidate_text);
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
end;

function TncEngine.get_phrase_context_bonus(const candidate_text: string): Integer;
const
    c_phrase_pair_step = 120;
    c_phrase_pair_cap = 360;
    c_phrase_trigram_step = 150;
    c_phrase_trigram_cap = 460;
    c_phrase_context_cap = 620;
var
    pair_count: Integer;
    pair_bonus: Integer;
    trigram_count: Integer;
    trigram_bonus: Integer;
    key: string;
    text_key: string;
begin
    Result := 0;
    if m_phrase_context_pairs = nil then
    begin
        Exit;
    end;

    text_key := Trim(candidate_text);
    if (text_key = '') or (m_last_output_commit_text = '') then
    begin
        Exit;
    end;

    pair_bonus := 0;
    trigram_bonus := 0;

    key := m_last_output_commit_text + #1 + text_key;
    if m_phrase_context_pairs.TryGetValue(key, pair_count) and (pair_count > 0) then
    begin
        pair_bonus := pair_count * c_phrase_pair_step;
        if pair_bonus > c_phrase_pair_cap then
        begin
            pair_bonus := c_phrase_pair_cap;
        end;
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
        end;
    end;

    if trigram_bonus > 0 then
    begin
        Result := trigram_bonus + (pair_bonus div 2);
    end
    else
    begin
        Result := pair_bonus;
    end;

    if Result > c_phrase_context_cap then
    begin
        Result := c_phrase_context_cap;
    end;
end;

function TncEngine.get_candidate_text_unit_count(const text: string): Integer;
begin
    Result := Length(split_text_units(text));
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
end;

function TncEngine.get_context_bonus(const candidate_text: string): Integer;
const
    c_context_total_cap = 760;
var
    text_context_bonus: Integer;
    phrase_context_bonus: Integer;
begin
    text_context_bonus := get_text_context_bonus(candidate_text);
    phrase_context_bonus := get_phrase_context_bonus(candidate_text);

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

    if Result > c_context_total_cap then
    begin
        Result := c_context_total_cap;
    end;
end;

function TncEngine.get_punctuation_char(const key_code: Word; const key_state: TncKeyState; out out_char: Char): Boolean;
begin
    Result := True;
    case key_code of
        Ord('6'):
            if key_state.shift_down then
            begin
                out_char := '^';
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
    if m_config.punctuation_full_width then
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
            ':':
                Result := Char($FF1A);
            ';':
                Result := Char($FF1B);
            '/':
                Result := Char($3001);
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

function TncEngine.get_rank_score(const candidate: TncCandidate): Integer;
var
    context_bonus: Integer;
    session_bonus: Integer;
    text_units: Integer;
    syllable_gap: Integer;
begin
    Result := candidate.score;
    context_bonus := get_context_bonus(candidate.text);
    if m_last_lookup_normalized_from <> '' then
    begin
        // When we auto-correct a likely adjacent-swap typo (e.g. chagn->chang),
        // reduce context influence so lexical score dominates.
        context_bonus := context_bonus div 4;
    end;
    Inc(Result, context_bonus);
    session_bonus := get_session_text_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        session_bonus := session_bonus div 2;
    end;
    Inc(Result, session_bonus);

    // For one-syllable full-pinyin lookups, keep single-char candidates ahead.
    if (m_last_lookup_syllable_count = 1) and (candidate.comment = '') then
    begin
        text_units := get_candidate_text_unit_count(candidate.text);
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
                if candidate.source = cs_ai then
                begin
                    Inc(Result, 180);
                end;
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
    case candidate.source of
        cs_user:
            Inc(Result, c_user_score_bonus);
        cs_ai:
            Dec(Result, c_ai_score_penalty);
    end;
end;

function TncEngine.get_candidate_debug_summary(const candidate: TncCandidate): string;
var
    text_context_bonus: Integer;
    phrase_context_bonus: Integer;
    context_bonus: Integer;
    session_bonus: Integer;
    rank_score: Integer;
    layer_value: Integer;
begin
    text_context_bonus := get_text_context_bonus(candidate.text);
    phrase_context_bonus := get_phrase_context_bonus(candidate.text);
    context_bonus := get_context_bonus(candidate.text);
    session_bonus := get_session_text_bonus(candidate.text);
    if candidate.comment <> '' then
    begin
        session_bonus := session_bonus div 2;
    end;
    rank_score := get_rank_score(candidate);
    layer_value := get_multi_syllable_intent_layer(candidate);

    Result := Format(
        'top=[%s src=%d rank=%d ctx=%d text_ctx=%d phr_ctx=%d sess=%d layer=%d partial=%d]',
        [candidate.text, Ord(candidate.source), rank_score, context_bonus, text_context_bonus,
        phrase_context_bonus, session_bonus, layer_value, Ord(candidate.comment <> '')]);
end;

function TncEngine.compare_candidates(const left: TncCandidate; const right: TncCandidate): Integer;
var
    left_score: Integer;
    right_score: Integer;
    left_layer: Integer;
    right_layer: Integer;
begin
    // Learned user candidates should take priority over rule candidates when
    // both are complete commit candidates for the same query.
    if (left.comment = '') and (right.comment = '') then
    begin
        if (left.source = cs_user) and (right.source <> cs_user) then
        begin
            Result := -1;
            Exit;
        end;
        if (right.source = cs_user) and (left.source <> cs_user) then
        begin
            Result := 1;
            Exit;
        end;
    end;

    if m_last_lookup_syllable_count >= 3 then
    begin
        left_layer := get_multi_syllable_intent_layer(left);
        right_layer := get_multi_syllable_intent_layer(right);
        Result := left_layer - right_layer;
        if Result <> 0 then
        begin
            Exit;
        end;
    end;

    left_score := get_rank_score(left);
    right_score := get_rank_score(right);
    Result := right_score - left_score;
    if Result = 0 then
    begin
        Result := get_source_rank(left.source) - get_source_rank(right.source);
        if Result = 0 then
        begin
            Result := Length(left.text) - Length(right.text);
            if Result = 0 then
            begin
                Result := CompareText(left.text, right.text);
            end;
        end;
    end;
end;

procedure TncEngine.sort_candidates(var candidates: TncCandidateList);
var
    list: TList<TncCandidate>;
    i: Integer;
begin
    if Length(candidates) <= 1 then
    begin
        Exit;
    end;

    list := TList<TncCandidate>.Create;
    try
        list.Capacity := Length(candidates);
        for i := 0 to High(candidates) do
        begin
            list.Add(candidates[i]);
        end;

        list.Sort(TComparer<TncCandidate>.Construct(
            function(const left, right: TncCandidate): Integer
            begin
                Result := compare_candidates(left, right);
            end));

        for i := 0 to High(candidates) do
        begin
            candidates[i] := list[i];
        end;
    finally
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

function TncEngine.ai_candidate_matches_pinyin(const candidate_text: string; const pinyin_text: string): Boolean;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
    text_units: TArray<string>;
    syllable_cache: TObjectDictionary<string, TDictionary<string, Boolean>>;
    allowed_chars: TDictionary<string, Boolean>;
    lookup_results: TncCandidateList;
    syllable_text: string;
    unit_text: string;
    i: Integer;
    j: Integer;
    normalized_pinyin: string;
    sqlite_dict: TncSqliteDictionary;

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
begin
    Result := False;
    if (candidate_text = '') or (pinyin_text = '') then
    begin
        Exit;
    end;

    normalized_pinyin := normalize_pinyin_text(pinyin_text);
    if normalized_pinyin = '' then
    begin
        Exit;
    end;

    parser := TncPinyinParser.Create;
    try
        syllables := parser.parse(normalized_pinyin);
    finally
        parser.Free;
    end;
    if Length(syllables) = 0 then
    begin
        Exit;
    end;

    text_units := split_text_units(candidate_text);
    if Length(text_units) <> Length(syllables) then
    begin
        Exit;
    end;

    if m_dictionary = nil then
    begin
        Result := True;
        Exit;
    end;

    sqlite_dict := nil;
    if m_dictionary is TncSqliteDictionary then
    begin
        sqlite_dict := TncSqliteDictionary(m_dictionary);
    end;
    if sqlite_dict <> nil then
    begin
        for i := 0 to High(syllables) do
        begin
            syllable_text := syllables[i].text;
            if (syllable_text = '') or (not sqlite_dict.single_char_matches_pinyin(syllable_text, text_units[i])) then
            begin
                Exit;
            end;
        end;
        Result := True;
        Exit;
    end;

    syllable_cache := TObjectDictionary<string, TDictionary<string, Boolean>>.Create([doOwnsValues]);
    try
        for i := 0 to High(syllables) do
        begin
            syllable_text := syllables[i].text;
            if syllable_text = '' then
            begin
                Exit;
            end;

            if not syllable_cache.TryGetValue(syllable_text, allowed_chars) then
            begin
                allowed_chars := TDictionary<string, Boolean>.Create;
                SetLength(lookup_results, 0);
                if not m_dictionary.lookup(syllable_text, lookup_results) then
                begin
                    allowed_chars.Free;
                    Exit;
                end;

                for j := 0 to High(lookup_results) do
                begin
                    unit_text := lookup_results[j].text;
                    if (unit_text <> '') and is_single_text_unit(unit_text) then
                    begin
                        allowed_chars.AddOrSetValue(unit_text, True);
                    end;
                end;
                syllable_cache.Add(syllable_text, allowed_chars);
            end;

            if not allowed_chars.ContainsKey(text_units[i]) then
            begin
                Exit;
            end;
        end;
    finally
        syllable_cache.Free;
    end;

    Result := True;
end;

procedure TncEngine.filter_ai_candidates_by_pinyin(var candidates: TncCandidateList; const pinyin_text: string);
var
    filtered: TList<TncCandidate>;
    i: Integer;
begin
    if Length(candidates) <= 0 then
    begin
        Exit;
    end;

    filtered := TList<TncCandidate>.Create;
    try
        for i := 0 to High(candidates) do
        begin
            if ai_candidate_matches_pinyin(candidates[i].text, pinyin_text) then
            begin
                filtered.Add(candidates[i]);
            end;
        end;
        SetLength(candidates, filtered.Count);
        for i := 0 to filtered.Count - 1 do
        begin
            candidates[i] := filtered[i];
        end;
    finally
        filtered.Free;
    end;
end;

procedure TncEngine.ensure_non_ai_first(var candidates: TncCandidateList);
var
    i: Integer;
    non_ai_index: Integer;
    non_ai_candidate: TncCandidate;
begin
    if Length(candidates) <= 1 then
    begin
        Exit;
    end;

    if candidates[0].source <> cs_ai then
    begin
        Exit;
    end;

    non_ai_index := -1;
    for i := 1 to High(candidates) do
    begin
        if candidates[i].source <> cs_ai then
        begin
            non_ai_index := i;
            Break;
        end;
    end;

    if non_ai_index <= 0 then
    begin
        Exit;
    end;

    non_ai_candidate := candidates[non_ai_index];
    for i := non_ai_index downto 1 do
    begin
        candidates[i] := candidates[i - 1];
    end;
    candidates[0] := non_ai_candidate;
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
    const include_full_path: Boolean): Boolean;
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
    c_segment_full_path_non_user_limit = 4;
    c_segment_partial_single_top_n = 6;
    c_segment_text_unit_mismatch_penalty = 100;
    c_segment_text_unit_overflow_penalty = 60;
    c_segment_alignment_rank_window = 6;
    c_segment_alignment_rank_step = 24;
    c_segment_alignment_missing_penalty = 60;
    c_segment_alignment_adjust_cap = 140;
var
    parser: TncPinyinParser;
    syllables: TncPinyinParseResult;
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

    function merge_source_rank(const left: TncCandidateSource; const right: TncCandidateSource): TncCandidateSource;
    begin
        if (left = cs_user) or (right = cs_user) then
        begin
            Result := cs_user;
        end
        else if (left = cs_rule) or (right = cs_rule) then
        begin
            Result := cs_rule;
        end
        else
        begin
            Result := cs_ai;
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

    procedure append_full_path_candidates;
    var
        states: TArray<TList<TncCandidate>>;
        state_dedup: TArray<TDictionary<string, Integer>>;
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
        local_state: TncCandidate;
        local_candidate: TncCandidate;
        local_new_state: TncCandidate;
        local_existing_state: TncCandidate;
        sorted_states: TncCandidateList;
        local_key: string;
        allow_leading_single_char: Boolean;
        allow_single_char_path: Boolean;
        preferred_phrase_flags: TArray<Boolean>;
        preferred_phrase_max_len: TArray<Integer>;
        single_char_rank_maps: TArray<TDictionary<string, Integer>>;
        segment_units: TArray<string>;
        text_unit_mismatch: Integer;
        candidate_has_non_ascii: Boolean;
        local_candidate_text: string;
        local_rank_map: TDictionary<string, Integer>;
        local_rank: Integer;

        function build_state_key(const text: string): string;
        begin
            Result := LowerCase(Trim(text));
        end;

        procedure append_state(const position: Integer; const value: TncCandidate);
        begin
            local_key := build_state_key(value.text);
            if state_dedup[position].TryGetValue(local_key, existing_state_index) then
            begin
                if (existing_state_index >= 0) and (existing_state_index < states[position].Count) then
                begin
                    local_existing_state := states[position][existing_state_index];
                    if value.score > local_existing_state.score then
                    begin
                        local_existing_state.score := value.score;
                    end;
                    if value.comment = '1' then
                    begin
                        local_existing_state.comment := '1';
                    end;
                    local_existing_state.source := merge_source_rank(local_existing_state.source, value.source);
                    states[position][existing_state_index] := local_existing_state;
                end;
                Exit;
            end;

            states[position].Add(value);
            state_dedup[position].Add(local_key, states[position].Count - 1);
        end;

        procedure trim_state(const position: Integer);
        var
            idx: Integer;
        begin
            if states[position].Count <= c_segment_full_state_limit then
            begin
                Exit;
            end;

            SetLength(sorted_states, states[position].Count);
            for idx := 0 to states[position].Count - 1 do
            begin
                sorted_states[idx] := states[position][idx];
            end;

            sort_candidates(sorted_states);
            keep_count := c_segment_full_state_limit;

            states[position].Clear;
            state_dedup[position].Clear;
            for idx := 0 to keep_count - 1 do
            begin
                states[position].Add(sorted_states[idx]);
                state_dedup[position].Add(build_state_key(sorted_states[idx].text), idx);
            end;
        end;

        function detect_preferred_phrase_at_position(const start_pos: Integer): Boolean;
        var
            probe_segment_len: Integer;
            probe_segment_text: string;
            probe_lookup_results: TncCandidateList;
            probe_idx: Integer;
            probe_text: string;
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

                if not m_dictionary.lookup(probe_segment_text, probe_lookup_results) then
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

        if Length(syllables) >= 6 then
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
        for state_pos := 0 to High(states) do
        begin
            states[state_pos] := TList<TncCandidate>.Create;
            state_dedup[state_pos] := TDictionary<string, Integer>.Create;
        end;

        try
            local_state.text := '';
            local_state.comment := '0';
            local_state.score := 0;
            local_state.source := cs_rule;
            local_state.has_dict_weight := False;
            local_state.dict_weight := 0;
            states[0].Add(local_state);
            state_dedup[0].Add('', 0);
            SetLength(preferred_phrase_flags, Length(syllables));
            SetLength(preferred_phrase_max_len, Length(syllables));
            SetLength(single_char_rank_maps, Length(syllables));
            for state_pos := 0 to High(syllables) do
            begin
                single_char_rank_maps[state_pos] := TDictionary<string, Integer>.Create;
                if m_dictionary.lookup(syllables[state_pos].text, local_lookup_results) then
                begin
                    local_rank := 0;
                    for candidate_index := 0 to High(local_lookup_results) do
                    begin
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
            end;

            for state_pos := 0 to High(syllables) do
            begin
                if states[state_pos].Count = 0 then
                begin
                    Continue;
                end;

                for local_segment_len := 1 to max_word_len do
                begin
                    if state_pos + local_segment_len > Length(syllables) then
                    begin
                        Break;
                    end;

                    local_segment_text := build_syllable_text(state_pos, local_segment_len);
                    if local_segment_text = '' then
                    begin
                        Continue;
                    end;

                    if not m_dictionary.lookup(local_segment_text, local_lookup_results) then
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
                        local_state := states[state_pos][state_index];
                        for candidate_index := 0 to High(local_lookup_results) do
                        begin
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
                            // For one-syllable segment expansion, multi-char words are typically noisy bridges
                            // (e.g. "xian" -> "鐟楀灝鐣?) and hurt full-path quality.
                            if candidate_has_non_ascii and (local_segment_len = 1) and
                                (candidate_text_units > 1) then
                            begin
                                Continue;
                            end;
                            allow_leading_single_char := False;
                            allow_single_char_path := False;
                            if not is_multi_char_word(local_candidate.text) then
                            begin
                                // Allow only the top leading single-char candidate so cases like
                                // "wo + faxian" can become "閹存垵褰傞悳?, while still blocking noisy
                                // single-char full-path combinations in general.
                                if candidate_has_non_ascii and (local_segment_len = 1) and
                                    (candidate_index < c_segment_full_single_top_n) then
                                begin
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
                            local_new_state.comment := local_state.comment;
                            if local_segment_len > 1 then
                            begin
                                local_new_state.comment := '1';
                            end;
                            local_new_state.score := local_state.score + local_candidate.score +
                                (local_segment_len * c_segment_prefix_bonus);
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
                            append_state(next_pos, local_new_state);
                        end;
                    end;

                    trim_state(next_pos);
                end;
            end;

            if states[Length(syllables)].Count = 0 then
            begin
                Exit;
            end;

            SetLength(sorted_states, states[Length(syllables)].Count);
            for final_index := 0 to states[Length(syllables)].Count - 1 do
            begin
                sorted_states[final_index] := states[Length(syllables)][final_index];
            end;
            sort_candidates(sorted_states);

            full_non_user_added := 0;
            for final_index := 0 to High(sorted_states) do
            begin
                local_state := sorted_states[final_index];
                if local_state.comment <> '1' then
                begin
                    Continue;
                end;
                if (local_state.source <> cs_user) and (full_non_user_added >= full_path_non_user_limit) then
                begin
                    Continue;
                end;
                append_candidate(local_state.text, local_state.score, local_state.source, '');
                if local_state.source <> cs_user then
                begin
                    Inc(full_non_user_added);
                end;
            end;
        finally
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
        end;
    end;
begin
    SetLength(out_candidates, 0);
    Result := False;
    if (m_dictionary = nil) or (m_composition_text = '') then
    begin
        Exit;
    end;

    parser := TncPinyinParser.create;
    try
        syllables := parser.parse(m_composition_text);
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
                append_full_path_candidates;
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

                if not m_dictionary.lookup(segment_text, lookup_results) then
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
        parser.Free;
    end;
end;

function TncEngine.build_pinyin_comment(const input_text: string): string;
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
        parts := parser.parse(input_text);
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
    update_segment_left_context;
end;

procedure TncEngine.rebuild_confirmed_text;
var
    i: Integer;
begin
    m_confirmed_text := '';
    if m_confirmed_segments = nil then
    begin
        Exit;
    end;

    for i := 0 to m_confirmed_segments.Count - 1 do
    begin
        m_confirmed_text := m_confirmed_text + m_confirmed_segments[i].text;
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
    clear_pending_commit;
    m_page_index := 0;
    build_candidates;
    Result := True;
end;

procedure TncEngine.apply_partial_commit(const selected_text: string; const remaining_pinyin: string);
var
    normalized_pinyin: string;
    prefix_pinyin: string;
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

    if (m_dictionary <> nil) and (prefix_pinyin <> '') then
    begin
        m_dictionary.record_commit(prefix_pinyin, selected_text);
    end;
    note_session_commit(selected_text);

    push_confirmed_segment(selected_text, prefix_pinyin);

    m_composition_text := remaining_pinyin;
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_pending_commit_allow_learning := True;
    m_page_index := 0;
    build_candidates;
end;

procedure TncEngine.set_pending_commit(const text: string; const remaining_pinyin: string = '';
    const allow_learning: Boolean = True);
begin
    m_pending_commit_text := text;
    m_pending_commit_remaining := remaining_pinyin;
    m_has_pending_commit := True;
    m_pending_commit_allow_learning := allow_learning;
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

procedure TncEngine.note_output_phrase_context(const committed_text: string);
var
    count: Integer;
    evict_key: string;
    text_key: string;
    phrase_key: string;
begin
    text_key := Trim(committed_text);
    if (text_key = '') or (m_phrase_context_pairs = nil) or (m_phrase_context_order = nil) then
    begin
        Exit;
    end;

    if m_last_output_commit_text <> '' then
    begin
        phrase_key := m_last_output_commit_text + #1 + text_key;
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
    end;

    if (m_prev_output_commit_text <> '') and (m_last_output_commit_text <> '') then
    begin
        phrase_key := m_prev_output_commit_text + #2 + m_last_output_commit_text + #1 + text_key;
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
        end
        else
        begin
            m_phrase_context_pairs.AddOrSetValue(evict_key, count);
        end;
    end;

    m_prev_output_commit_text := m_last_output_commit_text;
    m_last_output_commit_text := text_key;
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
        for variant_idx := 0 to High(context_variants) do
        begin
            m_dictionary.record_context_pair(context_variants[variant_idx], committed_text);
        end;
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

        out_candidate.text := m_composition_text;
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

    function apply_candidate_selection(const selected: TncCandidate): Boolean;
    begin
        if (selected.comment <> '') and is_compact_ascii_pinyin(selected.comment) then
        begin
            apply_partial_commit(selected.text, selected.comment);
            Result := True;
            Exit;
        end;

        if try_apply_trailing_pinyin_candidate(selected.text) then
        begin
            Result := True;
            Exit;
        end;

        set_pending_commit(selected.text, '', not is_generic_runtime_chain_selection(selected));
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
        Exit(False);
    end;

    if m_composition_text <> '' then
    begin
        normalize_page_and_selection;
    end;

    if is_alpha_key(key_code, key_char) then
    begin
        clear_pending_commit;
        m_composition_text := m_composition_text + key_char;
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
                    set_pending_commit(commit_text, '', not is_generic_runtime_chain_selection(candidate));
                    Result := True;
                    Exit;
                end;

                set_pending_commit(commit_text);
                Result := True;
                Exit;
            end;

            if m_config.punctuation_full_width or m_config.full_width_mode then
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
                        Result := apply_candidate_selection(candidate);
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
                    set_pending_commit(m_composition_text);
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
                        Result := apply_candidate_selection(m_candidates[index]);
                    end
                    else
                    begin
                        set_pending_commit(m_composition_text);
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
    Result := m_composition_text;
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
            display_text := m_composition_text;
        end;
    end;

    Result := m_confirmed_text + display_text;
end;

function TncEngine.get_confirmed_length: Integer;
begin
    Result := Length(m_confirmed_text);
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

    sc_path_value := m_config.dictionary_path_simplified;
    if (sc_path_value <> '') and FileExists(sc_path_value) then
    begin
        sc_path_exists := 1;
    end;

    tc_path_value := m_config.dictionary_path_traditional;
    if (tc_path_value <> '') and FileExists(tc_path_value) then
    begin
        tc_path_exists := 1;
    end;

    if (m_config.user_dictionary_path <> '') and FileExists(m_config.user_dictionary_path) then
    begin
        user_path_exists := 1;
        if user_path_value = '' then
        begin
            user_path_value := m_config.user_dictionary_path;
        end;
    end;

    Result := Format('provider=%s ready=%d base_ready=%d user_ready=%d variant=%s dict_path=%s exists=%d dict_sc=%s sc_exists=%d dict_tc=%s tc_exists=%d user_path=%s user_exists=%d',
        [provider_name, ready_value, base_ready_value, user_ready_value, variant_text, path_value, path_exists,
        sc_path_value, sc_path_exists, tc_path_value, tc_path_exists, user_path_value, user_path_exists]);
end;

function TncEngine.should_handle_key(const key_code: Word; const key_state: TncKeyState): Boolean;
var
    key_char: Char;
    punct_char: Char;
    has_candidates: Boolean;
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
        Exit(False);
    end;

    if is_alpha_key(key_code, key_char) then
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
            Result := m_config.punctuation_full_width or m_config.full_width_mode;
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
    allow_learning: Boolean;
begin
    out_text := '';
    if not m_has_pending_commit then
    begin
        Result := False;
        Exit;
    end;

    commit_segment_text := m_pending_commit_text;
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
    prev_left_context := m_left_context;
    update_left_context(out_text);
    record_context_pair(prev_left_context, out_text);
    normalized_pinyin := normalize_pinyin_text(m_composition_text);
    if allow_learning and (m_dictionary <> nil) then
    begin
        if (normalized_pinyin <> '') and (commit_segment_text <> '') then
        begin
            m_dictionary.record_commit(normalized_pinyin, commit_segment_text);
        end;

        if commit_text <> '' then
        begin
            full_pinyin := '';
            if m_confirmed_segments <> nil then
            begin
                for segment in m_confirmed_segments do
                begin
                    full_pinyin := full_pinyin + segment.pinyin;
                end;
            end;
            full_pinyin := full_pinyin + normalized_pinyin;

            if (full_pinyin <> '') and
                ((full_pinyin <> normalized_pinyin) or (commit_text <> commit_segment_text)) then
            begin
                m_dictionary.record_commit(full_pinyin, commit_text);
            end;
        end;
    end;
    if commit_segment_text <> '' then
    begin
        note_session_commit(commit_segment_text);
    end;
    if (commit_text <> '') and (commit_text <> commit_segment_text) then
    begin
        note_session_commit(commit_text);
    end;
    if commit_text <> '' then
    begin
        note_output_phrase_context(commit_text);
    end;
    m_confirmed_text := '';
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
begin
    Result := False;
    pinyin_key := normalize_pinyin_text(pinyin);
    if (m_dictionary = nil) or (Trim(text) = '') then
    begin
        Exit;
    end;

    m_dictionary.remove_user_entry(pinyin_key, text);

    if m_composition_text <> '' then
    begin
        build_candidates;
    end;

    Result := True;
end;

function TncEngine.refresh_ai_candidates_if_ready(out out_candidates: TncCandidateList; out page_index: Integer;
    out page_count: Integer; out selected_index: Integer; out preedit_text: string): Boolean;
var
    ai_candidates: TncCandidateList;
    base_candidates: TncCandidateList;
    merged_candidates: TncCandidateList;
    old_candidates: TncCandidateList;
    fusion: TncCandidateFusion;
    idx: Integer;
    limit: Integer;
    page_size: Integer;
    old_selected_abs: Integer;
    old_selected_idx: Integer;
    old_selected_text: string;
    primary_base_text: string;
    primary_base_idx: Integer;
    primary_candidate: TncCandidate;
    changed: Boolean;

    procedure clear_candidate_comments(var candidates: TncCandidateList);
    var
        idx: Integer;
    begin
        for idx := 0 to High(candidates) do
        begin
            candidates[idx].comment := '';
        end;
    end;

    procedure remove_ai_source(const input_candidates: TncCandidateList; out output_candidates: TncCandidateList);
    var
        idx: Integer;
        count: Integer;
    begin
        SetLength(output_candidates, Length(input_candidates));
        count := 0;
        for idx := 0 to High(input_candidates) do
        begin
            if input_candidates[idx].source <> cs_ai then
            begin
                output_candidates[count] := input_candidates[idx];
                Inc(count);
            end;
        end;
        SetLength(output_candidates, count);
    end;

    function same_candidates(const left: TncCandidateList; const right: TncCandidateList): Boolean;
    var
        idx: Integer;
    begin
        if Length(left) <> Length(right) then
        begin
            Exit(False);
        end;

        for idx := 0 to High(left) do
        begin
            if left[idx].text <> right[idx].text then
            begin
                Exit(False);
            end;
            if left[idx].comment <> right[idx].comment then
            begin
                Exit(False);
            end;
            if left[idx].score <> right[idx].score then
            begin
                Exit(False);
            end;
            if left[idx].source <> right[idx].source then
            begin
                Exit(False);
            end;
        end;

        Result := True;
    end;
begin
    SetLength(out_candidates, 0);
    page_index := 0;
    page_count := 0;
    selected_index := 0;
    preedit_text := '';
    Result := False;

    if not m_config.enable_ai then
    begin
        Exit;
    end;

    if m_composition_text = '' then
    begin
        Exit;
    end;

    if not get_ai_candidates(ai_candidates) then
    begin
        Exit;
    end;

    if Length(ai_candidates) = 0 then
    begin
        Exit;
    end;

    old_candidates := m_candidates;
    primary_base_text := '';
    old_selected_text := '';
    page_size := get_candidate_limit;
    if page_size <= 0 then
    begin
        page_size := 1;
    end;
    old_selected_abs := (m_page_index * page_size) + m_selected_index;
    if (old_selected_abs >= 0) and (old_selected_abs < Length(old_candidates)) then
    begin
        old_selected_text := old_candidates[old_selected_abs].text;
    end;
    remove_ai_source(old_candidates, base_candidates);
    if Length(base_candidates) = 0 then
    begin
        base_candidates := old_candidates;
    end;
    if Length(base_candidates) = 0 then
    begin
        Exit;
    end;
    primary_base_text := base_candidates[0].text;

    clear_candidate_comments(ai_candidates);
    fusion := TncCandidateFusion.create;
    try
        merged_candidates := fusion.merge_candidates(base_candidates, ai_candidates, 0);
    finally
        fusion.Free;
    end;

    sort_candidates(merged_candidates);
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
    if Length(merged_candidates) > limit then
    begin
        SetLength(merged_candidates, limit);
    end;
    ensure_non_ai_first(merged_candidates);

    if (primary_base_text <> '') and (Length(merged_candidates) > 0) and
        (not SameText(merged_candidates[0].text, primary_base_text)) then
    begin
        primary_base_idx := -1;
        for idx := 0 to High(merged_candidates) do
        begin
            if SameText(merged_candidates[idx].text, primary_base_text) then
            begin
                primary_base_idx := idx;
                Break;
            end;
        end;
        if primary_base_idx > 0 then
        begin
            primary_candidate := merged_candidates[primary_base_idx];
            for idx := primary_base_idx downto 1 do
            begin
                merged_candidates[idx] := merged_candidates[idx - 1];
            end;
            merged_candidates[0] := primary_candidate;
        end;
    end;

    changed := not same_candidates(old_candidates, merged_candidates);
    if not changed then
    begin
        Exit;
    end;

    m_candidates := merged_candidates;
    if old_selected_text <> '' then
    begin
        old_selected_idx := -1;
        for idx := 0 to High(m_candidates) do
        begin
            if SameText(m_candidates[idx].text, old_selected_text) then
            begin
                old_selected_idx := idx;
                Break;
            end;
        end;
        if old_selected_idx >= 0 then
        begin
            page_size := get_candidate_limit;
            if page_size <= 0 then
            begin
                page_size := 1;
            end;
            m_page_index := old_selected_idx div page_size;
            m_selected_index := old_selected_idx mod page_size;
        end;
    end;
    if m_page_index < 0 then
    begin
        m_page_index := 0;
    end;
    if m_selected_index < 0 then
    begin
        m_selected_index := 0;
    end;
    normalize_page_and_selection;

    out_candidates := get_candidates;
    page_index := get_page_index;
    page_count := get_page_count;
    selected_index := get_selected_index;
    preedit_text := m_composition_text;
    Result := True;
end;

initialization
    g_shared_ai_lock := TCriticalSection.Create;

finalization
    if g_shared_ai_provider <> nil then
    begin
        g_shared_ai_provider.Free;
        g_shared_ai_provider := nil;
    end;
    g_shared_ai_signature := '';
    g_shared_ai_retry_after_tick := 0;
    if g_shared_ai_lock <> nil then
    begin
        g_shared_ai_lock.Free;
        g_shared_ai_lock := nil;
    end;

end.
