unit nc_dictionary_intf;

interface

uses
    System.SysUtils,
    nc_types;

type
    TncDictionaryProvider = class
    public
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; virtual; abstract;
        function lookup_exact_full_pinyin(const pinyin: string;
            out results: TncCandidateList): Boolean; virtual;
        function lookup_isolated_exact_component(const pinyin: string;
            out results: TncCandidateList): Boolean; virtual;
        function lookup_full_pinyin_prefix(const pinyin_prefix: string;
            out results: TncCandidateList): Boolean; virtual;
        { Words whose syllables match a mixed full/abbreviated input exactly,
          e.g. "xiannrou" (xian + n + rou), user words first, then by weight. }
        function lookup_mixed_abbreviation_words(const pinyin: string;
            out results: TncCandidateList): Boolean; virtual;
        function lookup_candidate_prefix_completions(const pinyin_prefix: string;
            out results: TncOneKeyCompletionList): Boolean; virtual;
        { Base words whose leading syllables are exactly the given complete
          syllables and that continue with at least one more, up to
          max_syllables in all; highest weight first, at most limit. Completes
          the word cut by the end of a long input. }
        function lookup_word_completions(const syllables: TArray<string>;
            const max_syllables, limit: Integer;
            out results: TncOneKeyCompletionList): Boolean; virtual;
        { The characters that most often follow tail in the character n-gram
          table, best first, at most limit. }
        function lookup_next_characters(const tail: string; const limit: Integer;
            out characters: TArray<string>): Boolean; virtual;
        { The heaviest base words of min_length..max_length characters that
          start with prefix (the prefix alone when min_length is 1), with
          their pinyin, at most limit. }
        function lookup_words_starting_with(const prefix: string;
            const min_length, max_length, limit: Integer;
            out results: TncOneKeyCompletionList): Boolean; virtual;
        function lookup_one_key_completions(const pinyin_prefix: string;
            out results: TncOneKeyCompletionList): Boolean; virtual;
        function lookup_long_one_key_completions(const anchor_path: string;
            out results: TncLongOneKeyCompletionList): Boolean; virtual;
        function lookup_long_one_key_completions_by_text(
            const anchor_text: string;
            out results: TncLongOneKeyCompletionList): Boolean; virtual;
        function lookup_one_key_completion_competition(
            const pinyin_prefix: string; const left_context: string;
            out results: TncOneKeyCompletionCompetitionEvidenceList): Boolean; virtual;
        function lookup_one_key_completion_pair_audit(
            const pinyin_prefix, left_context: string;
            const baseline_full_pinyin, baseline_text: string;
            const challenger_full_pinyin, challenger_text: string;
            out audit: TncOneKeyCompletionPairAudit): Boolean; virtual;
        { The base dictionary's own choice among the exact words of a short
          query when no context, user word or earlier choice decides: with
          baseline_text first, promoted_text goes above it. lead is the
          margin of that choice. }
        function lookup_short_promotion(const pinyin, baseline_text: string;
            out promoted_text: string; out lead: Integer): Boolean; virtual;
        function resolve_exact_text_prefix(const text: string;
            const max_segments, max_units: Integer;
            out resolved: TncExactTextPath): Boolean; virtual;
        procedure record_one_key_completion_accept(const typed_prefix: string;
            const full_pinyin: string; const text: string); virtual;
        procedure record_one_key_completion_reject(const typed_prefix: string;
            const full_pinyin: string; const text: string); virtual;
        procedure record_long_one_key_completion_accept(
            const anchor_path, suffix_text: string); virtual;
        procedure record_long_one_key_completion_reject(
            const anchor_path, suffix_text: string); virtual;
        function lookup_fuzzy_full_pinyin(const pinyin: string;
            out results: TncCandidateList): Boolean; virtual;
        function lookup_fuzzy_full_pinyin_bounded(const pinyin: string;
            out results: TncCandidateList; const max_cost: Integer;
            const max_variants: Integer;
            const max_syllables: Integer;
            const max_candidates_per_variant: Integer = 0): Boolean; virtual;
        function lookup_literal_user_words(const query: string;
            out results: TncCandidateList): Boolean; virtual;
        function resolve_literal_user_word_pinyin(const query: string;
            const text: string; out full_pinyin: string): Boolean; virtual;
        function record_literal_user_word(const full_pinyin: string;
            const text: string): Boolean; virtual;
        function single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean; virtual;
        procedure begin_learning_batch; virtual;
        procedure commit_learning_batch; virtual;
        procedure rollback_learning_batch; virtual;
        procedure set_debug_mode(const enabled: Boolean); virtual;
        procedure set_fuzzy_pinyin_config(const enabled: Boolean;
            const rules: TncFuzzyPinyinRules); virtual;
        procedure record_fuzzy_choice(const pinyin: string;
            const text: string); virtual;
        procedure record_commit(const pinyin: string; const text: string;
            const explicit_choice: Boolean = False); virtual;
        procedure record_context_pair(const left_text: string; const committed_text: string); virtual;
        procedure record_context_trigram(const prev_prev_text: string; const prev_text: string;
            const committed_text: string); virtual;
        procedure record_context_query_choice(const context_suffix: string;
            const query_key: string; const candidate_text: string); virtual;
        procedure record_query_segment_path(const query_key: string; const encoded_path: string); virtual;
        procedure record_query_segment_path_penalty(const query_key: string; const encoded_path: string); virtual;
        procedure record_candidate_penalty(const pinyin: string; const text: string); virtual;
        function get_context_bonus(const left_text: string; const candidate_text: string): Integer; virtual;
        function get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
            const candidate_text: string): Integer; virtual;
        function get_context_query_choice_bonus(const context_suffix: string;
            const query_key: string; const candidate_text: string): Integer; virtual;
        function get_query_choice_bonus(const query_key: string; const candidate_text: string): Integer; virtual;
        function get_query_latest_choice_text(const query_key: string): string; virtual;
        function get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer; virtual;
        function get_long_query_segment_path_bonus(const query_key: string;
            const encoded_path: string): Integer; virtual;
        function get_lm_transition_bonus(const query_key: string; const encoded_path: string): Integer; virtual;
        function get_exact_pair_path_evidence(const query_key: string;
            out results: TncPairPathEvidenceList): Boolean; virtual;
        function get_char_lm_text_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; virtual;
        function get_char_lm_suffix_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; virtual;
        // Direct model entries only. Missing entries are Low(Integer), never
        // backoff estimates; callers must not mistake them for observations.
        function get_char_lm_attested_scores(const ngrams: TArray<string>;
            out scores: TArray<Integer>): Boolean; virtual;
        function get_char_lm_parameters(const ngrams: TArray<string>;
            out scores, backoffs: TArray<Integer>;
            const reverse_model: Boolean = False): Boolean; virtual;
        function get_char_reverse_lm_suffix_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; virtual;
        function get_char_lm_cached_span_scores(const texts: TArray<string>;
            out scores: TArray<Integer>): Boolean; virtual;
        function get_char_lm_continuation_scores(const left_context: string;
            const texts: TArray<string>; out scores: TArray<Integer>): Boolean; virtual;
        function get_char_lm_short_context_scores(const left_context: string;
            const texts: TArray<string>; out scores: TArray<Integer>): Boolean; virtual;
        function get_query_segment_path_penalty(const query_key: string; const encoded_path: string): Integer; virtual;
        function get_compound_tail_support(const tail_text: string): Integer; virtual;
        function get_base_text_prefix_bonus(const prefix_text: string): Integer; virtual;
        function is_base_entry(const pinyin: string; const text: string): Boolean; virtual;
        function is_user_entry(const pinyin: string; const text: string): Boolean; virtual;
        function is_literal_user_entry(const query: string;
            const text: string): Boolean; virtual;
        function is_low_evidence_admin_place_alias_user_entry(const pinyin: string;
            const text: string; const latest_choice_text: string = '';
            const user_weight: Integer = -1; const commit_count: Integer = -1): Boolean; virtual;
        function should_suppress_exact_query_learning(const pinyin: string; const text: string): Boolean; virtual;
        procedure remove_user_entry(const pinyin: string; const text: string); virtual;
        function clear_user_dictionary: Boolean; virtual;
        function get_candidate_penalty(const pinyin: string; const text: string): Integer; virtual;
    end;

function nc_get_char_lm_span_scores(const dictionary: TncDictionaryProvider;
    const texts: TArray<string>; out scores: TArray<Integer>): Boolean;

implementation

function nc_get_char_lm_span_scores(const dictionary: TncDictionaryProvider;
    const texts: TArray<string>; out scores: TArray<Integer>): Boolean;
var text: string;
begin
    Result := False;
    scores := nil;
    if (dictionary = nil) or (Length(texts) = 0) then Exit;
    if dictionary.get_char_lm_cached_span_scores(texts, scores) and
        (Length(scores) = Length(texts)) then Exit(True);
    // Final local comparisons must not depend on earlier queries warming the
    // FIFO cache. Load only their bounded windows, with identical BOS/EOS policy.
    if Length(texts) > 64 then Exit;
    for text in texts do if Length(text) > 40 then Exit;
    Result := dictionary.get_char_lm_continuation_scores('', texts, scores) and
        (Length(scores) = Length(texts));
end;

function TncDictionaryProvider.lookup_exact_full_pinyin(const pinyin: string;
    out results: TncCandidateList): Boolean;
begin
    Result := lookup(pinyin, results);
end;

function TncDictionaryProvider.lookup_isolated_exact_component(
    const pinyin: string; out results: TncCandidateList): Boolean;
begin
    Result := lookup_exact_full_pinyin(pinyin, results);
end;

function TncDictionaryProvider.lookup_full_pinyin_prefix(const pinyin_prefix: string;
    out results: TncCandidateList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_mixed_abbreviation_words(const pinyin: string;
    out results: TncCandidateList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_one_key_completions(
    const pinyin_prefix: string;
    out results: TncOneKeyCompletionList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_word_completions(const syllables: TArray<string>;
    const max_syllables, limit: Integer; out results: TncOneKeyCompletionList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_next_characters(const tail: string;
    const limit: Integer; out characters: TArray<string>): Boolean;
begin
    SetLength(characters, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_words_starting_with(const prefix: string;
    const min_length, max_length, limit: Integer;
    out results: TncOneKeyCompletionList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_candidate_prefix_completions(
    const pinyin_prefix: string; out results: TncOneKeyCompletionList): Boolean;
var
    prefixes: TncCandidateList;
    evidence: TncOneKeyCompletionList;
    idx, evidence_idx: Integer;
begin
    SetLength(results, 0);
    if not lookup_full_pinyin_prefix(pinyin_prefix, prefixes) then Exit(False);
    lookup_one_key_completions(pinyin_prefix, evidence);
    SetLength(results, Length(prefixes));
    for idx := 0 to High(prefixes) do
    begin
        if Trim(prefixes[idx].comment) <> '' then Continue;
        for evidence_idx := 0 to High(evidence) do
            if (evidence[evidence_idx].source = okcs_base_exact) and
                SameText(evidence[evidence_idx].text, prefixes[idx].text) then
            begin
                results[idx] := evidence[evidence_idx];
                Break;
            end;
        results[idx].text := prefixes[idx].text;
        results[idx].weight := prefixes[idx].score;
        if prefixes[idx].has_dict_weight then
            results[idx].weight := prefixes[idx].dict_weight;
        results[idx].source := okcs_base_exact;
        if prefixes[idx].source = cs_user then
            results[idx].source := okcs_user_exact;
    end;
    Result := Length(results) > 0;
end;

function TncDictionaryProvider.lookup_long_one_key_completions(
    const anchor_path: string;
    out results: TncLongOneKeyCompletionList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_long_one_key_completions_by_text(
    const anchor_text: string;
    out results: TncLongOneKeyCompletionList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_one_key_completion_competition(
    const pinyin_prefix: string; const left_context: string;
    out results: TncOneKeyCompletionCompetitionEvidenceList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_one_key_completion_pair_audit(
    const pinyin_prefix, left_context: string;
    const baseline_full_pinyin, baseline_text: string;
    const challenger_full_pinyin, challenger_text: string;
    out audit: TncOneKeyCompletionPairAudit): Boolean;
begin
    audit := Default(TncOneKeyCompletionPairAudit);
    Result := False;
end;

function TncDictionaryProvider.lookup_short_promotion(const pinyin,
    baseline_text: string; out promoted_text: string; out lead: Integer): Boolean;
begin
    promoted_text := '';
    lead := 0;
    Result := False;
end;

function TncDictionaryProvider.resolve_exact_text_prefix(
    const text: string; const max_segments, max_units: Integer;
    out resolved: TncExactTextPath): Boolean;
begin
    resolved := Default(TncExactTextPath);
    Result := False;
end;

procedure TncDictionaryProvider.record_one_key_completion_accept(
    const typed_prefix: string; const full_pinyin: string; const text: string);
begin
end;

procedure TncDictionaryProvider.record_one_key_completion_reject(
    const typed_prefix: string; const full_pinyin: string; const text: string);
begin
end;

procedure TncDictionaryProvider.record_long_one_key_completion_accept(
    const anchor_path, suffix_text: string);
begin
end;

procedure TncDictionaryProvider.record_long_one_key_completion_reject(
    const anchor_path, suffix_text: string);
begin
end;

function TncDictionaryProvider.lookup_fuzzy_full_pinyin(const pinyin: string;
    out results: TncCandidateList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.lookup_fuzzy_full_pinyin_bounded(
    const pinyin: string; out results: TncCandidateList;
    const max_cost: Integer; const max_variants: Integer;
    const max_syllables: Integer;
    const max_candidates_per_variant: Integer): Boolean;
begin
    Result := lookup_fuzzy_full_pinyin(pinyin, results);
end;

function TncDictionaryProvider.lookup_literal_user_words(const query: string;
    out results: TncCandidateList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.resolve_literal_user_word_pinyin(
    const query: string; const text: string; out full_pinyin: string): Boolean;
begin
    full_pinyin := '';
    Result := False;
end;

function TncDictionaryProvider.record_literal_user_word(
    const full_pinyin: string; const text: string): Boolean;
begin
    Result := False;
end;

function TncDictionaryProvider.single_char_matches_pinyin(const pinyin: string;
    const text_unit: string): Boolean;
var
    results: TncCandidateList;
    idx: Integer;
    candidate_text: string;
begin
    Result := False;
    if (Trim(pinyin) = '') or (Trim(text_unit) = '') or (Length(Trim(text_unit)) <> 1) then
    begin
        Exit;
    end;

    if not lookup(pinyin, results) then
    begin
        Exit;
    end;

    for idx := 0 to High(results) do
    begin
        candidate_text := Trim(results[idx].text);
        if (candidate_text <> '') and (Length(candidate_text) = 1) and
            SameText(candidate_text, Trim(text_unit)) then
        begin
            Exit(True);
        end;
    end;
end;

procedure TncDictionaryProvider.begin_learning_batch;
begin
end;

procedure TncDictionaryProvider.commit_learning_batch;
begin
end;

procedure TncDictionaryProvider.rollback_learning_batch;
begin
end;

procedure TncDictionaryProvider.set_debug_mode(const enabled: Boolean);
begin
end;

procedure TncDictionaryProvider.set_fuzzy_pinyin_config(
    const enabled: Boolean; const rules: TncFuzzyPinyinRules);
begin
end;

procedure TncDictionaryProvider.record_fuzzy_choice(const pinyin: string;
    const text: string);
begin
end;

procedure TncDictionaryProvider.record_commit(const pinyin: string; const text: string;
    const explicit_choice: Boolean = False);
begin
end;

procedure TncDictionaryProvider.record_context_pair(const left_text: string; const committed_text: string);
begin
end;

procedure TncDictionaryProvider.record_context_trigram(const prev_prev_text: string; const prev_text: string;
    const committed_text: string);
begin
end;

procedure TncDictionaryProvider.record_context_query_choice(
    const context_suffix: string; const query_key: string;
    const candidate_text: string);
begin
end;

procedure TncDictionaryProvider.record_query_segment_path(const query_key: string; const encoded_path: string);
begin
end;

procedure TncDictionaryProvider.record_query_segment_path_penalty(const query_key: string;
    const encoded_path: string);
begin
end;

procedure TncDictionaryProvider.record_candidate_penalty(const pinyin: string; const text: string);
begin
end;

function TncDictionaryProvider.get_context_bonus(const left_text: string; const candidate_text: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
    const candidate_text: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_context_query_choice_bonus(
    const context_suffix: string; const query_key: string;
    const candidate_text: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_query_choice_bonus(const query_key: string;
    const candidate_text: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_query_latest_choice_text(const query_key: string): string;
begin
    Result := '';
end;

function TncDictionaryProvider.get_query_segment_path_bonus(const query_key: string;
    const encoded_path: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_long_query_segment_path_bonus(
    const query_key: string; const encoded_path: string): Integer;
begin
    Result := get_query_segment_path_bonus(query_key, encoded_path);
end;

function TncDictionaryProvider.get_lm_transition_bonus(const query_key: string;
    const encoded_path: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_exact_pair_path_evidence(
    const query_key: string; out results: TncPairPathEvidenceList): Boolean;
begin
    SetLength(results, 0);
    Result := False;
end;

function TncDictionaryProvider.get_char_lm_text_scores(const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    SetLength(scores, 0);
    Result := False;
end;

function TncDictionaryProvider.get_char_lm_suffix_scores(const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    { Test and alternate providers can keep implementing the sentence scorer.
      SQLite overrides this to omit the false sentence-start context. }
    Result := get_char_lm_text_scores(texts, scores);
end;

function TncDictionaryProvider.get_char_lm_parameters(const ngrams: TArray<string>;
    out scores, backoffs: TArray<Integer>;
    const reverse_model: Boolean): Boolean;
begin
    scores := nil;
    backoffs := nil;
    Result := False;
end;

function TncDictionaryProvider.get_char_lm_attested_scores(
    const ngrams: TArray<string>; out scores: TArray<Integer>): Boolean;
var idx: Integer;
begin
    SetLength(scores, Length(ngrams));
    for idx := 0 to High(scores) do scores[idx] := Low(Integer);
    Result := False;
end;

function TncDictionaryProvider.get_char_reverse_lm_suffix_scores(
    const texts: TArray<string>; out scores: TArray<Integer>): Boolean;
begin
    SetLength(scores, 0);
    Result := False;
end;

function TncDictionaryProvider.get_char_lm_cached_span_scores(
    const texts: TArray<string>; out scores: TArray<Integer>): Boolean;
begin
    SetLength(scores, 0);
    Result := False;
end;

function TncDictionaryProvider.get_char_lm_continuation_scores(
    const left_context: string; const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
var
    combined_texts: TArray<string>;
    idx: Integer;
begin
    SetLength(combined_texts, Length(texts));
    for idx := 0 to High(texts) do
    begin
        combined_texts[idx] := Trim(left_context) + Trim(texts[idx]);
    end;
    Result := get_char_lm_suffix_scores(combined_texts, scores);
end;

function TncDictionaryProvider.get_char_lm_short_context_scores(
    const left_context: string; const texts: TArray<string>;
    out scores: TArray<Integer>): Boolean;
begin
    Result := get_char_lm_continuation_scores(left_context, texts, scores);
end;

function TncDictionaryProvider.get_query_segment_path_penalty(const query_key: string;
    const encoded_path: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_compound_tail_support(const tail_text: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.get_base_text_prefix_bonus(const prefix_text: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.is_base_entry(const pinyin: string; const text: string): Boolean;
begin
    Result := False;
end;

function TncDictionaryProvider.is_user_entry(const pinyin: string; const text: string): Boolean;
begin
    Result := False;
end;

function TncDictionaryProvider.is_literal_user_entry(const query: string;
    const text: string): Boolean;
begin
    Result := False;
end;

function TncDictionaryProvider.is_low_evidence_admin_place_alias_user_entry(
    const pinyin: string; const text: string; const latest_choice_text: string;
    const user_weight: Integer; const commit_count: Integer): Boolean;
begin
    Result := False;
end;

function TncDictionaryProvider.should_suppress_exact_query_learning(const pinyin: string;
    const text: string): Boolean;
begin
    Result := False;
end;

procedure TncDictionaryProvider.remove_user_entry(const pinyin: string; const text: string);
begin
end;

function TncDictionaryProvider.clear_user_dictionary: Boolean;
begin
    Result := False;
end;

function TncDictionaryProvider.get_candidate_penalty(const pinyin: string; const text: string): Integer;
begin
    Result := 0;
end;

end.
