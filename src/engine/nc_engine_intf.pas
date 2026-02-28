unit nc_engine_intf;

interface

uses
    System.SysUtils,
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
        m_context_db_bonus_cache_key: string;
        m_context_db_bonus_cache: TDictionary<string, Integer>;
        m_pending_commit_text: string;
        m_pending_commit_remaining: string;
        m_has_pending_commit: Boolean;
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
        function get_context_bonus(const candidate_text: string): Integer;
        function get_punctuation_char(const key_code: Word; const key_state: TncKeyState; out out_char: Char): Boolean;
        function map_full_width_char(const input_char: Char): string;
        function map_punctuation_char(const input_char: Char): string;
        function get_rank_score(const candidate: TncCandidate): Integer;
        function compare_candidates(const left: TncCandidate; const right: TncCandidate): Integer;
        procedure sort_candidates(var candidates: TncCandidateList);
        function normalize_pinyin_text(const input_text: string): string;
        function split_text_units(const input_text: string): TArray<string>;
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
        procedure set_pending_commit(const text: string; const remaining_pinyin: string = '');
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
    c_context_score_bonus = 80;
    c_context_score_bonus_max = 400;
    c_full_width_offset = $FEE0;
    c_segment_surname_bonus = 110;
    c_common_surname_chars =
        '赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦许何吕施张孔曹严华金魏陶姜戚谢邹喻苏潘葛范彭郎鲁韦马苗凤方俞任袁柳鲍史唐费' +
        '薛雷贺倪汤殷罗毕郝邬安常乐于傅皮齐康伍余元顾孟平黄和穆萧尹姚邵湛汪祁毛禹狄米明臧计伏成戴' +
        '宋茅庞熊纪舒屈项祝董梁杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林' +
        '钟徐邱骆高夏蔡田樊胡凌霍虞万柯卢莫房缪解应丁邓郁崔龚程邢裴陆荣翁荀羊惠甄封芮储靳段巫焦巴弓牧车侯宓蓬全';

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
begin
    SetLength(out_candidates, 0);
    if (m_ai_provider = nil) or (m_composition_text = '') then
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
    filter_ai_candidates_by_pinyin(out_candidates, ai_request.context.composition_text);
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
    multi_syllable_cap_limit: Integer;

    procedure clear_candidate_comments(var candidates: TncCandidateList);
    var
        idx: Integer;
    begin
        for idx := 0 to High(candidates) do
        begin
            candidates[idx].comment := '';
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

    function try_build_best_single_char_chain(out out_candidate: TncCandidate): Boolean;
    const
        c_chain_min_syllables = 3;
        c_chain_bonus = 160;
        c_chain_penalty_per_syllable = 28;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        syllable_text: string;
        local_lookup: TncCandidateList;
        idx: Integer;
        candidate_idx: Integer;
        best_idx: Integer;
        best_rank: Integer;
        rank_score: Integer;
        chosen: TncCandidate;
        chain_text: string;
        total_score: Integer;
        syllable_count: Integer;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;

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

            best_idx := -1;
            best_rank := Low(Integer);
            for candidate_idx := 0 to High(local_lookup) do
            begin
                chosen := local_lookup[candidate_idx];
                if not is_single_text_unit(Trim(chosen.text)) then
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
        Result := True;
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

        target_index := 2;
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
        c_forced_partial_max_candidates = 16;
    var
        parser: TncPinyinParser;
        syllables: TncPinyinParseResult;
        first_syllable: string;
        remaining_pinyin: string;
        fallback_lookup: TncCandidateList;
        forced_list: TncCandidateList;
        forced_count: Integer;
        idx: Integer;
        source_item: TncCandidate;
        forced_item: TncCandidate;
        trailing_count: Integer;
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

        SetLength(forced_list, 0);
        forced_count := 0;
        trailing_count := Length(syllables) - 1;
        for idx := 0 to High(fallback_lookup) do
        begin
            source_item := fallback_lookup[idx];
            if not is_single_text_unit(Trim(source_item.text)) then
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
        best_index: Integer;
        best_rank: Integer;
        rank_score: Integer;
        trailing_count: Integer;
    begin
        Result := False;
        out_candidate.text := '';
        out_candidate.comment := '';
        out_candidate.score := 0;
        out_candidate.source := cs_rule;

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

        best_index := -1;
        best_rank := Low(Integer);
        for idx := 0 to High(fallback_lookup) do
        begin
            source_item := fallback_lookup[idx];
            if not is_single_text_unit(Trim(source_item.text)) then
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
    begin
        if not has_multi_syllable_input then
        begin
            Exit;
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

        // Always keep a practical single-char continuation in top-3 for long/noisy queries.
        target_index := 2;
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
begin
    SetLength(m_candidates, 0);
    if m_composition_text = '' then
    begin
        Exit;
    end;

    has_raw_candidates := False;
    has_segment_candidates := False;
    raw_from_dictionary := False;
    lookup_text := normalize_pinyin_text(m_composition_text);
    fallback_comment := build_pinyin_comment(m_composition_text);
    has_multi_syllable_input := fallback_comment <> '';
    if m_dictionary <> nil then
    begin
        if m_dictionary.lookup(lookup_text, raw_candidates) then
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
        if m_config.enable_segment_candidates and raw_from_dictionary then
        begin
            if not has_segment_candidates then
            begin
                has_segment_candidates := build_segment_candidates(segment_candidates, False);
            end;

            if has_segment_candidates then
            begin
                raw_candidates := merge_candidate_lists(raw_candidates, segment_candidates, 0);
                ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
                ensure_single_char_partial_visible(raw_candidates, get_candidate_limit, 1);
            end;
        end;

        // Even when segment candidates are disabled or fail to build, multi-syllable input
        // must keep a single-char partial fallback (e.g. "hai" + "budaxing").
        if has_multi_syllable_input then
        begin
            ensure_forced_single_char_partial(raw_candidates);
            sort_candidates(raw_candidates);
            ensure_partial_fallback_visible(raw_candidates, get_candidate_limit);
            ensure_single_char_partial_visible(raw_candidates, get_candidate_limit, 1);
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
            ensure_single_char_partial_visible(m_candidates, get_candidate_limit, 1);
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

        apply_user_penalties(lookup_text, m_candidates);
        sort_candidates(m_candidates);
        ensure_partial_fallback_visible(m_candidates, get_candidate_limit);
        ensure_single_char_partial_visible(m_candidates, get_candidate_limit, 1);
        ensure_hard_single_char_partial_visible(m_candidates);
        ensure_best_single_char_chain_visible(m_candidates);
        ensure_non_ai_first(m_candidates);
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
        m_page_index := 0;
        m_selected_index := 0;
        Exit;
    end;

    SetLength(m_candidates, 1);
    m_candidates[0].text := m_composition_text;
    m_candidates[0].comment := fallback_comment;
    m_candidates[0].score := 0;
    m_candidates[0].source := cs_rule;
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

function TncEngine.get_context_bonus(const candidate_text: string): Integer;
var
    key: string;
    context_value: string;
    count: Integer;
    local_bonus: Integer;
    persistent_bonus: Integer;
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

    if m_context_pairs <> nil then
    begin
        key := context_value + #1 + candidate_text;
        if m_context_pairs.TryGetValue(key, count) then
        begin
            local_bonus := count * c_context_score_bonus;
            if local_bonus > c_context_score_bonus_max then
            begin
                local_bonus := c_context_score_bonus_max;
            end;
        end;
    end;

    if (m_dictionary <> nil) and (m_context_db_bonus_cache <> nil) then
    begin
        if m_context_db_bonus_cache_key <> context_value then
        begin
            m_context_db_bonus_cache.Clear;
            m_context_db_bonus_cache_key := context_value;
        end;

        if not m_context_db_bonus_cache.TryGetValue(candidate_text, persistent_bonus) then
        begin
            persistent_bonus := m_dictionary.get_context_bonus(context_value, candidate_text);
            m_context_db_bonus_cache.AddOrSetValue(candidate_text, persistent_bonus);
        end;
    end;

    if local_bonus >= persistent_bonus then
    begin
        Result := local_bonus;
    end
    else
    begin
        Result := persistent_bonus;
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
begin
    Result := candidate.score;
    Inc(Result, get_context_bonus(candidate.text));
    if candidate.comment <> '' then
    begin
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

function TncEngine.compare_candidates(const left: TncCandidate; const right: TncCandidate): Integer;
var
    left_score: Integer;
    right_score: Integer;
begin
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
                if (secondary_candidates[i].comment <> '') and (existing_index >= 0)
                    and (existing_index < list.Count) then
                begin
                    candidate := list[existing_index];
                    if candidate.comment = '' then
                    begin
                        candidate.comment := secondary_candidates[i].comment;
                        list[existing_index] := candidate;
                    end;
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
    c_segment_partial_penalty = 120;
    c_segment_prefix_bonus = 80;
    c_segment_page_expand_factor = 16;
    c_segment_full_state_limit = 128;
    c_segment_full_completion_bonus = 160;
    c_segment_full_transition_penalty = 6;
    c_segment_full_leading_single_penalty = 24;
    c_segment_full_single_top_n = 1;
    c_segment_full_non_leading_single_penalty = 72;
    c_segment_text_unit_mismatch_penalty = 100;
    c_segment_text_unit_overflow_penalty = 60;
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
        const comment_override: string);
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
                list[existing_index] := item;
            end;
            Exit;
        end;

        item.text := text;
        item.comment := comment_override;
        item.score := score;
        item.source := source;
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
        local_state: TncCandidate;
        local_candidate: TncCandidate;
        local_new_state: TncCandidate;
        local_existing_state: TncCandidate;
        sorted_states: TncCandidateList;
        local_key: string;
        allow_leading_single_char: Boolean;
        allow_single_char_path: Boolean;
        preferred_phrase_flags: TArray<Boolean>;
        text_unit_mismatch: Integer;
        candidate_has_non_ascii: Boolean;
        local_candidate_text: string;

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
                        Result := True;
                        Exit;
                    end;
                end;
            end;
        end;
    begin
        if Length(syllables) <= 1 then
        begin
            Exit;
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
            states[0].Add(local_state);
            state_dedup[0].Add('', 0);
            SetLength(preferred_phrase_flags, Length(syllables));
            for state_pos := 0 to High(syllables) do
            begin
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
                            local_candidate := local_lookup_results[candidate_index];
                            local_candidate_text := Trim(local_candidate.text);
                            candidate_has_non_ascii := contains_non_ascii(local_candidate_text);
                            candidate_text_units := get_text_unit_count(local_candidate_text);
                            if candidate_text_units <= 0 then
                            begin
                                Continue;
                            end;
                            // For one-syllable segment expansion, multi-char words are typically noisy bridges
                            // (e.g. "xian" -> "西安") and hurt full-path quality.
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
                                // "wo + faxian" can become "我发现", while still blocking noisy
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
                            if allow_single_char_path then
                            begin
                                if (next_pos < Length(syllables)) and (state_pos >= 0) and
                                    (state_pos < Length(preferred_phrase_flags)) and
                                    preferred_phrase_flags[state_pos] then
                                begin
                                    Continue;
                                end;
                                if allow_leading_single_char then
                                begin
                                    Dec(local_new_state.score, c_segment_full_leading_single_penalty);
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

                            if is_first_overall_segment and (state_pos = 0) and (local_segment_len = 1) and
                                (next_pos < Length(syllables)) and (Length(local_candidate.text) = 1) and
                                (Pos(local_candidate.text, c_common_surname_chars) > 0) then
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

            for final_index := 0 to states[Length(syllables)].Count - 1 do
            begin
                local_state := states[Length(syllables)][final_index];
                if local_state.comment <> '1' then
                begin
                    Continue;
                end;
                append_candidate(local_state.text, local_state.score, local_state.source, '');
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
                    if (segment_len = 1) and (candidate_text_units > 1) then
                    begin
                        Continue;
                    end;
                    score_value := candidate.score + (segment_len * c_segment_prefix_bonus);
                    if remaining_syllables > 0 then
                    begin
                        Dec(score_value, c_segment_partial_penalty * remaining_syllables);
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
                        (Length(candidate.text) = 1) and (Pos(candidate.text, c_common_surname_chars) > 0) then
                    begin
                        Inc(score_value, c_segment_surname_bonus);
                    end;

                    append_candidate(candidate.text, score_value, candidate.source, remaining_pinyin);
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

    push_confirmed_segment(selected_text, prefix_pinyin);

    m_composition_text := remaining_pinyin;
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    m_page_index := 0;
    build_candidates;
end;

procedure TncEngine.set_pending_commit(const text: string; const remaining_pinyin: string = '');
begin
    m_pending_commit_text := text;
    m_pending_commit_remaining := remaining_pinyin;
    m_has_pending_commit := True;
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
end;

procedure TncEngine.update_left_context(const committed_text: string);
var
    next_context: string;
begin
    next_context := committed_text;
    if Length(next_context) > c_left_context_max_len then
    begin
        next_context := Copy(next_context, Length(next_context) - c_left_context_max_len + 1, c_left_context_max_len);
    end;
    m_left_context := next_context;
end;

procedure TncEngine.record_context_pair(const left_text: string; const committed_text: string);
var
    key: string;
    evict_key: string;
    count: Integer;
begin
    if (left_text = '') or (committed_text = '') then
    begin
        Exit;
    end;

    if m_dictionary <> nil then
    begin
        m_dictionary.record_context_pair(left_text, committed_text);
    end;

    if (m_context_db_bonus_cache <> nil) and (m_context_db_bonus_cache_key = left_text) then
    begin
        m_context_db_bonus_cache.Remove(committed_text);
    end;

    if m_context_pairs = nil then
    begin
        Exit;
    end;

    key := left_text + #1 + committed_text;
    if m_context_pairs.TryGetValue(key, count) then
    begin
        Inc(count);
        m_context_pairs.AddOrSetValue(key, count);
    end
    else
    begin
        m_context_pairs.Add(key, 1);
    end;

    if m_context_order = nil then
    begin
        Exit;
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

        set_pending_commit(selected.text);
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
                if m_composition_text <> '' then
                begin
                    clear_pending_commit;
                    Delete(m_composition_text, Length(m_composition_text), 1);
                    build_candidates;
                    Result := True;
                end;
                if (not Result) and (m_confirmed_segments <> nil) and (m_confirmed_segments.Count > 0) then
                begin
                    Result := rollback_last_segment;
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
    m_pending_commit_text := '';
    m_pending_commit_remaining := '';
    m_has_pending_commit := False;
    prev_left_context := m_left_context;
    update_left_context(out_text);
    record_context_pair(prev_left_context, out_text);
    normalized_pinyin := normalize_pinyin_text(m_composition_text);
    if m_dictionary <> nil then
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
