unit nc_char_lm;

{ Shared character-level causal language model.
  The engine sees only IncCharLm; the host implements it over nc_lm_* in the
  native bridge DLL. A nil or not-ready model leaves every ranking unchanged. }

interface

uses System.SysUtils, System.Math, nc_one_key_completion_gbdt, nc_tab_continuation_gbdt,
    nc_short_context_gbdt, nc_long_choice_gbdt;

type
    IncCharLm = interface
        ['{6B0F3C2E-7A51-4D0B-9C1E-2F5D8A4B7E13}']
        function char_lm_ready: Boolean;
        { Sums log P(text | context) for texts in order while their packed
          prefix trie stays within max_nodes; the first min_count texts are
          always scored. Returns how many leading texts were scored, or -1. }
        function score_texts(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
    end;

    { Optional: score_texts plus, for each index in next_texts, the top_k Han
      characters that follow that text, best first, with their
      log-probabilities. next_chars/next_logp hold top_k entries per index
      ('' where the text was not scored or the model had fewer). }
    IncCharLmNext = interface
        ['{9D3A6E21-5B7C-4F08-A1E4-3C6B2D8F0A57}']
        function score_texts_next(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
    end;

    { Optional: the greedy continuation of text after context, at most
      max_chars Han characters (one per element of chars), each with its
      log-probability under the full distribution. Returns how many characters
      were produced, or -1. }
    IncCharLmContinue = interface
        ['{4E8B2D71-93C6-4A5F-B0E2-7D1C5A9F3E68}']
        function continue_text(const context, text: string; const max_chars: Integer;
            out chars: TArray<string>; out logp: TArray<Single>): Integer;
    end;

    { A continuation proposed for Tab: the kept base prefix (top1 or top2 minus
      replace_units characters) and a dictionary word as the suffix. With
      replace_units > 0 the word continues the last typed syllables (a tail
      word: the word cut by the input end); with 0 it follows the decoded text
      (a next word). tail_rank is its weight rank among those words. }
    TncCharLmContinuation = record
        base_text: string;
        suffix_text: string;
        // The decoded text the base was kept from (top1 or top2); with
        // replace_units it gives the re-read of the typed tail.
        full_base_text: string;
        base_rank: Integer;
        replace_units: Integer;
        tail_rank: Integer;
        // A tail word whose replaced characters spell the typed syllables
        // exactly (not a longer syllable the input may still be typing): its
        // re-read tail may be followed by LM next characters.
        exact_reread: Boolean;
        // Only in a choice: an LM next character after the decoded text
        // (replace_units 0) or after a re-read typed tail; the suffix is the
        // re-read characters and the next character.
        lm_next: Boolean;
    end;

    { A one-key completion (a dictionary word continuing the typed syllables)
      with the dictionary evidence the completion ranker already has. }
    TncCharLmCompletionCandidate = record
        text: string;
        pool_rank: Integer;
        weight: Integer;
        popularity_prior: Integer;
        corpus_score: Integer;
        engine_lm_score: Integer;
        source_count: Integer;
        prefix_anchored: Boolean;
        // The user's accept and reject records for this completion.
        feedback_count: Integer;
        feedback_reject_count: Integer;
    end;

    { Engine evidence for a long-sentence pool candidate, filled by the final
      ranking (TncEngine.fill_long_pool_evidence lists the order). }
    TncCharLmLongEvidence = array[0..c_long_gbdt_evidence_count - 1] of Double;

    { A candidate of the final long-sentence pool: its final rank and the
      engine evidence for it. }
    TncCharLmLongCandidate = record
        text: string;
        rank: Integer;
        has_evidence: Boolean;
        evidence: TncCharLmLongEvidence;
    end;

    { A visible exact entry for the short-word choice: its page position and
      the dictionary evidence the candidate list carries. }
    TncCharLmShortCandidate = record
        text: string;
        position: Integer;
        dict_weight: Integer;
        has_dict_weight: Boolean;
        display_score: Integer;
        user: Boolean;
    end;

const
    { Long-sentence choice over the final pool. The pool limit and the node
      budget were widened from 20 and 110 when the second-slot stages that
      lifted deep candidates into the scored pool were deleted; the rank
      weight and the visible bonus make the earlier score, one feature of
      nc_long_choice_gbdt. }
    c_char_lm_long_min_units = 6;
    c_char_lm_long_pool_limit = 32;
    c_char_lm_long_min_count = 2;
    c_char_lm_long_max_nodes = 176;
    c_char_lm_long_rank_weight = 0.25;
    c_char_lm_long_visible_bonus = 2.5;
    { Whole-word matches of mixed full and abbreviated input: the first this
      many, ordered by log P(text | context) - w * ln(position). }
    c_char_lm_short_limit = 5;
    c_char_lm_short_rank_weight = 1.0;
    { Short-word choice with left context: the visible exact entries for the
      input (prefix completions excluded), at most this many in page order. }
    c_char_lm_short_choice_limit = 8;
    { The choice looks at the context-free scores first, which the host keeps.
      When the ranker's best candidate leads the next by at least this on
      those alone, the call with the context is left out: the context
      overturned such a lead in 2 of 30,000 held-out fiction cases and in none
      of 56,886 chat cases, and it holds for a quarter of the calls. }
    c_char_lm_short_plain_lead = 5.0;
    { Tab continuation: show the most probable candidate when P(correct) is at
      least this. Chosen on the 7,996-sentence fiction Tab dev set (5-fold CV
      on the policy's own features) as the most hits whose prompt precision is
      not below the previous round's, and among equal hits the fewest prompts. }
    c_char_lm_tab_min_probability = 0.02;
    { The shown continuation is followed by the LM's greedy continuation while
      each character has at least this probability (after an LM next
      character, after a dictionary word), up to this many characters, so that
      a word is not cut after its first character. Chosen on the Tab dev set as
      the most saved characters while the hits lost stay within half of what
      the LM-only continuation gained there over v1.31.0. }
    c_char_lm_tab_extend_lm_next_probability = 0.7;
    c_char_lm_tab_extend_word_probability = 0.85;
    c_char_lm_tab_extend_max_chars = 3;
    { One-key completion rerank: the dictionary pool, then the rerank-only
      extras (lookup_one_key_completion_extras) up to this many, plus the
      incumbent choice. Twelve pool entries were the limit until the extras:
      in 7.5% of the opportunities of the fiction one-key dev set the target
      was a dictionary word outside the pool. }
    c_char_lm_completion_limit = 48;
    { The rerank scores the first entries, as it did before the extras, and
      the rest only when the ranker's best score leads the next by less than
      this: one rerank in twelve on held-out fiction. A wider gap finds more
      (2.5: one in five, 0.9 points more hits) for a second LM call each. }
    c_char_lm_completion_first = 12;
    c_char_lm_completion_wide_gap = 1.0;

{ Chooses the long-sentence top1 from the final complete pool and the visible
  top1. pool holds the final ranking's candidates in their original order with
  their final ranks and engine evidence. Candidates must cover expected_units
  characters; duplicates keep their first occurrence. The visible top1 goes
  first (and is appended to the pool when missing), then the pool's first
  c_char_lm_long_pool_limit entries by final rank, cut by the node budget.
  A gradient-boosted ranker (nc_long_choice_gbdt) scores each from log P(text |
  context), its pool position and final rank, the earlier score LM - w *
  ln(pool position) + bonus * [is visible] and the engine evidence; ties keep
  the earlier text. Returns True when the candidates were scored: chosen is
  the model's first (it can be the visible top1) and second its runner-up. }
function nc_char_lm_choose_long(const model: IncCharLm; const context: string;
    const pool: TArray<TncCharLmLongCandidate>; const visible: string;
    const expected_units: Integer; out chosen, second: string): Boolean;

{ Chooses among the first c_char_lm_short_limit distinct texts (the visible
  complete candidates in order) by log P(text | context) - w * ln(position).
  Ties keep the earlier text. Returns False when nothing was scored. }
function nc_char_lm_choose_short_top(const model: IncCharLm; const context: string;
    const texts: TArray<string>; out best_index: Integer): Boolean;

{ Chooses the short-word top with left context among the visible exact
  entries for the input (the first c_char_lm_short_choice_limit, page order)
  by a gradient-boosted ranker over log P(text | context), log P of its first
  one and two characters, log P(text) without context, the dictionary weight,
  the display score and the page position (nc_short_context_gbdt). Without
  a left context, and when the context-free scores alone give a lead of
  c_char_lm_short_plain_lead, the choice is made from those. Ties keep the
  earlier candidate. Returns False when nothing was scored. }
function nc_char_lm_choose_short(const model: IncCharLm; const context: string;
    const candidates: TArray<TncCharLmShortCandidate>; out best_index: Integer): Boolean;

{ Estimates P(the displayed continuation is correct) for each candidate from
  log P(base + suffix | context) - log P(base | context) and each candidate's
  standing in the pool, with a gradient-boosted classifier fit on the Tab dev
  set (nc_tab_continuation_gbdt). The decoded top1/top2 (decoded_texts) are
  always scored; candidates only while the scored texts fit
  c_tab_tail_node_budget, best ranks first, and the rest are ignored. When the
  model implements IncCharLmNext, the LM's next characters after the decoded
  texts (not for phonetic-only requests) and after the best re-read typed
  tails join the pool, so it works without any candidate. Returns False when
  nothing was scored; otherwise chosen is the most probable continuation (ties
  keep the earlier one), best_index its index in candidates (-1 for an LM next
  character) and probability its estimate. }
function nc_char_lm_choose_continuation(const model: IncCharLm; const context: string;
    const candidates: TArray<TncCharLmContinuation>; const phonetic_only: Boolean;
    const decoded_texts: TArray<string>; out chosen: TncCharLmContinuation;
    out best_index: Integer; out probability: Double): Boolean;

{ The characters that follow a shown continuation: the LM's greedy
  continuation of text (at most c_char_lm_tab_extend_max_chars), cut before
  the first character below min_probability ('' when the model cannot
  continue). }
function nc_char_lm_extend_continuation(const model: IncCharLm; const context,
    text: string; const min_probability: Double): string;

{ Chooses the one-key completion with a gradient-boosted ranker over
  log P(text | context), dictionary evidence, length and each candidate's
  standing in the group (nc_one_key_completion_gbdt): first among the leading
  c_char_lm_completion_first pool entries and the incumbent (the established
  ranker's choice), and when that leaves no clear lead, again among all
  c_char_lm_completion_limit entries, which costs a second LM call.
  typed_units is the number of typed syllables. As in the established ranker,
  a candidate accepted fewer times or rejected more often than the incumbent
  never replaces it (nc_char_lm_completion_may_replace). Returns False when the
  model cannot score, leaving the incumbent in place. }
function nc_char_lm_choose_completion(const model: IncCharLm; const context: string;
    const candidates: TArray<TncCharLmCompletionCandidate>; const incumbent_index,
    typed_units: Integer; out best_index: Integer): Boolean;

{ The user's records allow challenger to replace incumbent: accepted at least
  as often and rejected no more often. }
function nc_char_lm_completion_may_replace(const challenger,
    incumbent: TncCharLmCompletionCandidate): Boolean;

function nc_char_lm_code_point_count(const text: string): Integer;

var
    { Diagnostics only: when set, receives each scored Tab continuation (base,
      suffix, features and probability, tab-separated). }
    nc_char_lm_tab_trace: TProc<string>;
    { Diagnostics only: when set, receives each scored short-word candidate
      (text and features, tab-separated). }
    nc_char_lm_short_trace: TProc<string>;
    { Diagnostics only: when set, receives each scored long-sentence candidate
      (text and features, tab-separated). }
    nc_char_lm_long_trace: TProc<string>;

implementation

uses System.Generics.Collections, System.Generics.Defaults;

const
    // Tail and next words are scored in rank order while the packed trie of
    // the continuation texts stays within this many nodes beyond the context.
    c_tab_tail_node_budget = 96;
    // LM next characters: this many after each expanded text, for the decoded
    // top1/top2 and the best re-read typed tails by log-probability.
    c_tab_next_k = 5;
    c_tab_reread_prefixes = 3;


function nc_char_lm_code_point_count(const text: string): Integer;
var
    idx: Integer;
begin
    Result := 0;
    idx := 1;
    while idx <= Length(text) do
    begin
        if (Ord(text[idx]) >= $D800) and (Ord(text[idx]) <= $DBFF) and
            (idx < Length(text)) and (Ord(text[idx + 1]) >= $DC00) and
            (Ord(text[idx + 1]) <= $DFFF) then
            Inc(idx);
        Inc(idx);
        Inc(Result);
    end;
end;

function nc_char_lm_choose_continuation(const model: IncCharLm; const context: string;
    const candidates: TArray<TncCharLmContinuation>; const phonetic_only: Boolean;
    const decoded_texts: TArray<string>; out chosen: TncCharLmContinuation;
    out best_index: Integer; out probability: Double): Boolean;
type
    // A scored continuation: an input candidate (source >= 0) or an LM next
    // character (source -1).
    TScored = record
        item: TncCharLmContinuation;
        source: Integer;
        lm_rank: Integer;
        lp_full, lp_base, reread_gain: Double;
    end;
    // A text whose next characters are expanded.
    TPrefix = record
        text, base, full_base: string;
        replace_units, base_rank, slot: Integer;
        lp_prefix, lp_base, lp_full_base: Double;
        has_full_base: Boolean;
    end;
var
    texts: TArray<string>;

    function text_index(const value: string): Integer;
    begin
        Result := 0;
        while (Result < Length(texts)) and (texts[Result] <> value) do
            Inc(Result);
        if Result = Length(texts) then
            texts := texts + [value];
    end;

var
    next_model: IncCharLmNext;
    logp, next_logp: TArray<Single>;
    next_chars: TArray<string>;
    base_idx, full_idx, reread_idx, decoded_idx, tail_order, next_texts,
        next_slot: TArray<Integer>;
    scored_items: TArray<TScored>;
    prefixes, rereads: TArray<TPrefix>;
    prefix: TPrefix;
    entry: TScored;
    top_idx: array[0..1] of Integer;
    features: array[0..c_tab_gbdt_feature_count - 1] of Double;
    idx, other, units, required, scored, typed, rank, slot, lp_rank, best: Integer;
    best_base, lm_best, lp_max, suffix_lp, p, logit: Double;
    usable, duplicate: Boolean;
    text, suffix, ch: string;
begin
    Result := False;
    best_index := -1;
    chosen := Default(TncCharLmContinuation);
    probability := 0.0;
    if (model = nil) or (not model.char_lm_ready) or ((Length(candidates) = 0) and
        ((Length(decoded_texts) = 0) or (decoded_texts[0] = ''))) then
        Exit;
    // The decoded top1 and top2 are always scored: the readings every
    // continuation starts from. Candidates follow by rank (more replaced
    // syllables first) with their base, full text, re-read and decoded base
    // while the trie fits the node budget.
    SetLength(base_idx, Length(candidates));
    SetLength(full_idx, Length(candidates));
    SetLength(reread_idx, Length(candidates));
    SetLength(decoded_idx, Length(candidates));
    for idx := 0 to High(candidates) do
    begin
        if (candidates[idx].base_text = '') or (candidates[idx].suffix_text = '') then
            Exit;
        base_idx[idx] := -1;
        full_idx[idx] := -1;
        reread_idx[idx] := -1;
        decoded_idx[idx] := -1;
    end;
    for rank := 0 to 1 do
    begin
        top_idx[rank] := -1;
        if (rank < Length(decoded_texts)) and (decoded_texts[rank] <> '') then
            top_idx[rank] := text_index(decoded_texts[rank]);
    end;
    required := Length(texts);
    SetLength(tail_order, 0);
    for idx := 0 to High(candidates) do
    begin
        // Stable insertion by (tail rank, replaced units descending).
        other := Length(tail_order);
        tail_order := tail_order + [idx];
        while (other > 0) and ((candidates[tail_order[other - 1]].tail_rank >
            candidates[idx].tail_rank) or ((candidates[tail_order[other - 1]].tail_rank =
            candidates[idx].tail_rank) and (candidates[tail_order[other - 1]].replace_units <
            candidates[idx].replace_units))) do
        begin
            tail_order[other] := tail_order[other - 1];
            Dec(other);
        end;
        tail_order[other] := idx;
    end;
    for idx in tail_order do
    begin
        base_idx[idx] := text_index(candidates[idx].base_text);
        full_idx[idx] := text_index(candidates[idx].base_text + candidates[idx].suffix_text);
        if candidates[idx].full_base_text <> '' then
        begin
            reread_idx[idx] := text_index(candidates[idx].base_text +
                Copy(candidates[idx].suffix_text, 1, Max(0, candidates[idx].replace_units)));
            decoded_idx[idx] := text_index(candidates[idx].full_base_text);
        end;
    end;
    // Next characters may follow the decoded texts and the re-read tails.
    SetLength(next_slot, Length(texts));
    for idx := 0 to High(next_slot) do
        next_slot[idx] := -1;
    SetLength(next_texts, 0);
    for rank := 0 to 1 do
        if (top_idx[rank] >= 0) and (next_slot[top_idx[rank]] < 0) then
        begin
            next_slot[top_idx[rank]] := Length(next_texts);
            next_texts := next_texts + [top_idx[rank]];
        end;
    for idx := 0 to High(candidates) do
    begin
        other := -1;
        if (candidates[idx].replace_units > 0) and candidates[idx].exact_reread then
            other := reread_idx[idx];
        if (other >= 0) and (next_slot[other] < 0) then
        begin
            next_slot[other] := Length(next_texts);
            next_texts := next_texts + [other];
        end;
    end;
    // The native budget counts BOS and the context characters as well.
    // Without a decoded text at least the first candidate's base is required.
    required := Max(1, required);
    if (Length(next_texts) > 0) and Supports(model, IncCharLmNext, next_model) then
        scored := next_model.score_texts_next(context, texts, required,
            1 + nc_char_lm_code_point_count(context) + c_tab_tail_node_budget, next_texts,
            c_tab_next_k, logp, next_chars, next_logp)
    else
    begin
        scored := model.score_texts(context, texts, required,
            1 + nc_char_lm_code_point_count(context) + c_tab_tail_node_budget, logp);
        SetLength(next_texts, 0);
    end;
    if (scored < required) or (scored > Length(texts)) or (Length(logp) < scored) or
        (Length(next_chars) < Length(next_texts) * c_tab_next_k) or
        (Length(next_logp) < Length(next_texts) * c_tab_next_k) then
        Exit;

    // The usable input candidates in order.
    SetLength(scored_items, 0);
    typed := 0;
    for idx := 0 to High(candidates) do
    begin
        usable := (base_idx[idx] < scored) and (full_idx[idx] < scored) and
            (reread_idx[idx] < scored) and (decoded_idx[idx] < scored);
        if not usable then
            Continue;
        entry := Default(TScored);
        entry.item := candidates[idx];
        entry.source := idx;
        entry.lp_full := logp[full_idx[idx]];
        entry.lp_base := logp[base_idx[idx]];
        if reread_idx[idx] >= 0 then
            entry.reread_gain := logp[reread_idx[idx]] - logp[decoded_idx[idx]];
        scored_items := scored_items + [entry];
        if candidates[idx].full_base_text <> '' then
            typed := Max(typed, nc_char_lm_code_point_count(candidates[idx].full_base_text));
    end;
    if top_idx[0] >= 0 then
        typed := Max(typed, nc_char_lm_code_point_count(decoded_texts[0]));

    // Texts to expand: the decoded top1 and top2, then the re-read tails with
    // the best log-probability.
    SetLength(prefixes, 0);
    if (Length(next_texts) > 0) and (not phonetic_only) then
        for rank := 1 to 2 do
            if (top_idx[rank - 1] >= 0) and (top_idx[rank - 1] < scored) and
                (nc_char_lm_code_point_count(decoded_texts[rank - 1]) = typed) then
            begin
                prefix := Default(TPrefix);
                prefix.text := decoded_texts[rank - 1];
                prefix.base := prefix.text;
                prefix.full_base := prefix.text;
                prefix.base_rank := rank;
                prefix.slot := next_slot[top_idx[rank - 1]];
                prefix.lp_prefix := logp[top_idx[rank - 1]];
                prefix.lp_base := prefix.lp_prefix;
                prefix.lp_full_base := prefix.lp_prefix;
                prefix.has_full_base := True;
                prefixes := prefixes + [prefix];
            end;
    SetLength(rereads, 0);
    if Length(next_texts) > 0 then
        for entry in scored_items do
        begin
            if (entry.item.replace_units <= 0) or (not entry.item.exact_reread) or
                (reread_idx[entry.source] < 0) then
                Continue;
            text := entry.item.base_text + Copy(entry.item.suffix_text, 1,
                entry.item.replace_units);
            if nc_char_lm_code_point_count(text) <> typed then
                Continue;
            duplicate := False;
            for other := 0 to High(prefixes) do
                duplicate := duplicate or (prefixes[other].text = text);
            for other := 0 to High(rereads) do
                duplicate := duplicate or (rereads[other].text = text);
            if duplicate then
                Continue;
            prefix := Default(TPrefix);
            prefix.text := text;
            prefix.base := entry.item.base_text;
            prefix.full_base := entry.item.full_base_text;
            prefix.replace_units := entry.item.replace_units;
            prefix.base_rank := 1;
            prefix.slot := next_slot[reread_idx[entry.source]];
            prefix.lp_prefix := logp[reread_idx[entry.source]];
            prefix.lp_base := entry.lp_base;
            prefix.has_full_base := decoded_idx[entry.source] >= 0;
            if prefix.has_full_base then
                prefix.lp_full_base := logp[decoded_idx[entry.source]];
            // Stable insertion by log-probability, best first.
            other := Length(rereads);
            rereads := rereads + [prefix];
            while (other > 0) and (rereads[other - 1].lp_prefix < prefix.lp_prefix) do
            begin
                rereads[other] := rereads[other - 1];
                Dec(other);
            end;
            rereads[other] := prefix;
        end;
    for idx := 0 to Min(c_tab_reread_prefixes, Length(rereads)) - 1 do
        prefixes := prefixes + [rereads[idx]];

    // Each expanded text's next characters, skipping texts already offered.
    for prefix in prefixes do
    begin
        if prefix.slot < 0 then
            Continue;
        for rank := 1 to c_tab_next_k do
        begin
            slot := prefix.slot * c_tab_next_k + rank - 1;
            ch := next_chars[slot];
            if ch = '' then
                Break;
            suffix := Copy(prefix.text, Length(prefix.base) + 1, MaxInt) + ch;
            text := prefix.base + suffix;
            duplicate := False;
            for other := 0 to High(scored_items) do
                duplicate := duplicate or (scored_items[other].item.base_text +
                    scored_items[other].item.suffix_text = text);
            if duplicate then
                Continue;
            entry := Default(TScored);
            entry.item.base_text := prefix.base;
            entry.item.suffix_text := suffix;
            entry.item.full_base_text := prefix.full_base;
            entry.item.base_rank := prefix.base_rank;
            entry.item.replace_units := prefix.replace_units;
            entry.item.tail_rank := rank;
            entry.item.lm_next := True;
            entry.source := -1;
            entry.lm_rank := rank;
            entry.lp_full := prefix.lp_prefix + next_logp[slot];
            entry.lp_base := prefix.lp_base;
            if prefix.has_full_base then
                entry.reread_gain := prefix.lp_prefix - prefix.lp_full_base;
            scored_items := scored_items + [entry];
        end;
    end;
    if Length(scored_items) = 0 then
        Exit;

    best_base := -MaxDouble;
    lm_best := -MaxDouble;
    lp_max := -MaxDouble;
    for entry in scored_items do
    begin
        best_base := Max(best_base, entry.lp_base);
        lm_best := Max(lm_best, entry.lp_full - entry.lp_base);
        lp_max := Max(lp_max, entry.lp_full);
    end;

    best := -1;
    for idx := 0 to High(scored_items) do
    begin
        entry := scored_items[idx];
        suffix_lp := entry.lp_full - entry.lp_base;
        units := Max(1, nc_char_lm_code_point_count(entry.item.suffix_text));
        // Features 0-3, 10 and 11 described the retired local-completion
        // ranker and generator pool; the trained model keeps their slots.
        features[0] := 0.0;
        features[1] := 0.0;
        features[2] := 0.0;
        features[3] := 0.0;
        features[4] := suffix_lp;
        features[5] := suffix_lp / units;
        features[6] := units;
        features[7] := entry.lp_base - best_base;
        features[8] := suffix_lp - lm_best;
        features[9] := Ord(entry.item.base_rank = 2);
        features[10] := 0.0;
        features[11] := 1.0;
        features[12] := entry.item.replace_units;
        features[13] := Ln(Max(1, entry.item.tail_rank));
        features[14] := entry.reread_gain;
        features[15] := Ord(entry.item.replace_units = 0);
        features[16] := 0.0;
        features[17] := 0.0;
        if features[15] > 0 then
        begin
            features[16] := Ord(units = 1);
            features[17] := Ln(Max(1, entry.item.tail_rank));
        end;
        // Standing in the pool: rank by log P(base + suffix), earlier first on ties.
        lp_rank := 0;
        for other := 0 to High(scored_items) do
            if (scored_items[other].lp_full > entry.lp_full) or
                ((scored_items[other].lp_full = entry.lp_full) and (other < idx)) then
                Inc(lp_rank);
        features[18] := lp_rank;
        features[19] := Length(scored_items);
        features[20] := typed;
        features[21] := entry.lp_full - lp_max;
        features[22] := nc_char_lm_code_point_count(entry.item.base_text) - typed;
        features[23] := Ord(entry.item.lm_next);
        features[24] := 0.0;
        if entry.item.lm_next then
            features[24] := Ln(Max(1, entry.lm_rank));
        // Logistic of the logit, written so that Exp cannot overflow.
        logit := nc_tab_gbdt_logit(features);
        if logit >= 0.0 then
            p := 1.0 / (1.0 + Exp(-logit))
        else
            p := Exp(logit) / (1.0 + Exp(logit));
        if Assigned(nc_char_lm_tab_trace) then
        begin
            text := entry.item.base_text + #9 + entry.item.suffix_text + #9 +
                FloatToStr(entry.lp_full, TFormatSettings.Invariant) + #9 +
                FloatToStr(entry.lp_base, TFormatSettings.Invariant);
            for other := 0 to c_tab_gbdt_feature_count - 1 do
                text := text + #9 + FloatToStr(features[other], TFormatSettings.Invariant);
            nc_char_lm_tab_trace(text + #9 + FloatToStr(p, TFormatSettings.Invariant));
        end;
        if (best < 0) or (p > probability) then
        begin
            best := idx;
            probability := p;
        end;
    end;
    chosen := scored_items[best].item;
    best_index := scored_items[best].source;
    Result := True;
end;

function nc_char_lm_extend_continuation(const model: IncCharLm; const context,
    text: string; const min_probability: Double): string;
var
    continuer: IncCharLmContinue;
    chars: TArray<string>;
    logp: TArray<Single>;
    produced, idx: Integer;
begin
    Result := '';
    if (model = nil) or (text = '') or (not model.char_lm_ready) or
        (not Supports(model, IncCharLmContinue, continuer)) then
        Exit;
    produced := continuer.continue_text(context, text, c_char_lm_tab_extend_max_chars,
        chars, logp);
    for idx := 0 to Min(produced, Min(Length(chars), Length(logp))) - 1 do
    begin
        if (chars[idx] = '') or (Exp(logp[idx]) < min_probability) then
            Break;
        Result := Result + chars[idx];
    end;
end;

function nc_char_lm_choose_completion(const model: IncCharLm; const context: string;
    const candidates: TArray<TncCharLmCompletionCandidate>; const incumbent_index,
    typed_units: Integer; out best_index: Integer): Boolean;
var
    order: TArray<Integer>;
    scored: TArray<Double>;
    has_context, gap: Double;
    idx: Integer;
    more: TArray<Integer>;

    // One LM call for the listed candidates, appended to those scored so far.
    function score_more(const indices: TArray<Integer>): Boolean;
    var
        texts: TArray<string>;
        logp: TArray<Single>;
        at: Integer;
    begin
        Result := False;
        SetLength(texts, Length(indices));
        for at := 0 to High(indices) do
        begin
            texts[at] := candidates[indices[at]].text;
            if texts[at] = '' then
                Exit;
        end;
        if model.score_texts(context, texts, Length(texts), 0, logp) <> Length(texts) then
            Exit;
        for at := 0 to High(indices) do
        begin
            order := order + [indices[at]];
            scored := scored + [logp[at]];
        end;
        Result := True;
    end;

    // The ranker over everything scored so far. gap is the lead of the best
    // score over the next one, the user's records aside.
    procedure choose(out gap: Double);
    var
        features: array[0..c_one_key_gbdt_feature_count - 1] of Double;
        per_char: TArray<Double>;
        at, other, units, candidate, lm_rank: Integer;
        is_incumbent, lm_max, per_char_max, score, best_score, top, next: Double;
        found: Boolean;
    begin
        SetLength(per_char, Length(order));
        lm_max := -MaxDouble;
        per_char_max := -MaxDouble;
        for at := 0 to High(order) do
        begin
            per_char[at] := scored[at] /
                Max(1, nc_char_lm_code_point_count(candidates[order[at]].text));
            lm_max := Max(lm_max, scored[at]);
            per_char_max := Max(per_char_max, per_char[at]);
        end;
        best_index := incumbent_index;
        best_score := 0.0;
        found := False;
        top := -MaxDouble;
        next := -MaxDouble;
        for at := 0 to High(order) do
        begin
            candidate := order[at];
            units := Max(1, nc_char_lm_code_point_count(candidates[candidate].text));
            is_incumbent := Ord(candidate = incumbent_index);
            // Rank by LM within the group, earlier entries first on ties.
            lm_rank := 0;
            for other := 0 to High(order) do
                if (scored[other] > scored[at]) or ((scored[other] = scored[at]) and (other < at)) then
                    Inc(lm_rank);
            features[0] := scored[at];
            features[1] := per_char[at];
            features[2] := Ln(candidates[candidate].pool_rank);
            features[3] := is_incumbent;
            features[4] := Ln(1 + Max(0, candidates[candidate].weight));
            features[5] := Ln(1 + Max(0, candidates[candidate].popularity_prior));
            features[6] := candidates[candidate].corpus_score / 1000.0;
            features[7] := units;
            features[8] := units - typed_units;
            features[9] := candidates[candidate].engine_lm_score / 1000.0;
            features[10] := Ord(candidates[candidate].prefix_anchored);
            features[11] := Ln(1 + Max(0, candidates[candidate].source_count));
            features[12] := scored[at] * has_context;
            features[13] := is_incumbent * (1.0 - has_context);
            features[14] := scored[at] - lm_max;
            features[15] := per_char[at] - per_char_max;
            features[16] := lm_rank;
            features[17] := has_context;
            features[18] := Length(order);
            features[19] := typed_units;
            score := nc_one_key_gbdt_score(features);
            if score > top then
            begin
                next := top;
                top := score;
            end
            else if score > next then
                next := score;
            if (candidate <> incumbent_index) and (incumbent_index >= 0) and
                (incumbent_index < Length(candidates)) and
                not nc_char_lm_completion_may_replace(candidates[candidate],
                candidates[incumbent_index]) then
                Continue;
            if (not found) or (score > best_score) then
            begin
                found := True;
                best_index := candidate;
                best_score := score;
            end;
        end;
        gap := MaxDouble;
        if Length(order) > 1 then
            gap := top - next;
    end;

begin
    Result := False;
    best_index := incumbent_index;
    if (model = nil) or (Length(candidates) < 2) or (not model.char_lm_ready) then
        Exit;
    has_context := Ord(Trim(context) <> '');
    // First the leading pool entries, and the incumbent when it lies beyond.
    SetLength(more, 0);
    for idx := 0 to Min(c_char_lm_completion_first, Length(candidates)) - 1 do
        more := more + [idx];
    if (incumbent_index >= c_char_lm_completion_first) and
        (incumbent_index < Length(candidates)) then
        more := more + [incumbent_index];
    if not score_more(more) then
        Exit;
    choose(gap);
    Result := True;
    // A clear lead ends it there. Otherwise the rest of the pool and the
    // rerank-only extras are scored, and the choice is made again over all.
    if gap >= c_char_lm_completion_wide_gap then
        Exit;
    SetLength(more, 0);
    for idx := c_char_lm_completion_first to
        Min(c_char_lm_completion_limit, Length(candidates)) - 1 do
        if idx <> incumbent_index then
            more := more + [idx];
    if (Length(more) = 0) or not score_more(more) then
        Exit;
    choose(gap);
end;

function nc_char_lm_completion_may_replace(const challenger,
    incumbent: TncCharLmCompletionCandidate): Boolean;
begin
    Result := (challenger.feedback_count >= incumbent.feedback_count) and
        (challenger.feedback_reject_count <= incumbent.feedback_reject_count);
end;

function nc_char_lm_choose_short_top(const model: IncCharLm; const context: string;
    const texts: TArray<string>; out best_index: Integer): Boolean;
var
    logp: TArray<Single>;
    count, idx: Integer;
    score, best_score: Double;
begin
    Result := False;
    best_index := 0;
    count := Min(Length(texts), c_char_lm_short_limit);
    if (model = nil) or (count < 2) or (not model.char_lm_ready) then
        Exit;
    if model.score_texts(context, Copy(texts, 0, count), count, 0, logp) <> count then
        Exit;
    best_score := 0.0;
    for idx := 0 to count - 1 do
    begin
        score := logp[idx] - c_char_lm_short_rank_weight * Ln(idx + 1);
        if (idx = 0) or (score > best_score) then
        begin
            best_index := idx;
            best_score := score;
        end;
    end;
    Result := True;
end;

function code_points(const text: string): TArray<string>;
var
    idx, width: Integer;
begin
    Result := nil;
    idx := 1;
    while idx <= Length(text) do
    begin
        width := 1;
        if (Ord(text[idx]) >= $D800) and (Ord(text[idx]) <= $DBFF) and
            (idx < Length(text)) and (Ord(text[idx + 1]) >= $DC00) and
            (Ord(text[idx + 1]) <= $DFFF) then
            width := 2;
        Result := Result + [Copy(text, idx, width)];
        Inc(idx, width);
    end;
end;

function nc_char_lm_choose_short(const model: IncCharLm; const context: string;
    const candidates: TArray<TncCharLmShortCandidate>; out best_index: Integer): Boolean;
var
    count, idx, other, part: Integer;
    chars: TArray<string>;
    texts: TArray<string>;
    slots: array of array[0..2] of Integer;
    slot_of: TDictionary<string, Integer>;
    logp: TArray<Single>;
    sorted_texts: TArray<string>;
    plain, plain1, plain2, log_weight, log_display: TArray<Double>;
    prefix: string;
    plain_lead: Double;

    // The ranker over the group: from the scores after the context in logp
    // (with_context), or from the context-free scores alone, as for input
    // without a left context. lead is the best score's margin over the next.
    function choose(const with_context: Boolean; out lead: Double): Integer;
    var
        lp, lp1, lp2: TArray<Double>;
        features: array[0..c_short_gbdt_feature_count - 1] of Double;
        own_chars, first_chars: TArray<string>;
        at, against, units, shared, lp_rank, weight_rank, context_units: Integer;
        lp_max, lp1_max, gain_max, score, best_score, next_score: Double;
        line: string;
    begin
        SetLength(lp, count);
        SetLength(lp1, count);
        SetLength(lp2, count);
        lp_max := -MaxDouble;
        lp1_max := -MaxDouble;
        gain_max := -MaxDouble;
        for at := 0 to count - 1 do
        begin
            if with_context then
            begin
                lp[at] := logp[slots[at][0]];
                lp1[at] := logp[slots[at][1]];
                lp2[at] := logp[slots[at][2]];
            end
            else
            begin
                lp[at] := plain[at];
                lp1[at] := plain1[at];
                lp2[at] := plain2[at];
            end;
            lp_max := Max(lp_max, lp[at]);
            lp1_max := Max(lp1_max, lp1[at]);
            gain_max := Max(gain_max, lp[at] - plain[at]);
        end;
        context_units := 0;
        if with_context then
            context_units := nc_char_lm_code_point_count(context);
        first_chars := code_points(candidates[0].text);
        Result := 0;
        best_score := 0.0;
        next_score := -MaxDouble;
        for at := 0 to count - 1 do
        begin
            own_chars := code_points(candidates[at].text);
            units := Max(1, Length(own_chars));
            shared := 0;
            while (shared < Length(own_chars)) and (shared < Length(first_chars)) and
                (own_chars[shared] = first_chars[shared]) do
                Inc(shared);
            // Standing in the group by log P and by dictionary weight, earlier first on ties.
            lp_rank := 0;
            weight_rank := 0;
            for against := 0 to count - 1 do
            begin
                if (lp[against] > lp[at]) or ((lp[against] = lp[at]) and (against < at)) then
                    Inc(lp_rank);
                if (log_weight[against] > log_weight[at]) or
                    ((log_weight[against] = log_weight[at]) and (against < at)) then
                    Inc(weight_rank);
            end;
            features[0] := lp[at];
            features[1] := lp[at] / units;
            features[2] := lp[at] - lp_max;
            features[3] := lp[at] - lp[0];
            features[4] := lp_rank;
            features[5] := Ln(1.0 + Max(0, candidates[at].position));
            features[6] := at;
            features[7] := units;
            features[8] := count;
            features[9] := log_weight[at];
            features[10] := Ord(candidates[at].has_dict_weight);
            features[11] := log_weight[at] - log_weight[0];
            features[12] := log_display[at];
            features[13] := log_display[at] - log_display[0];
            features[14] := Ord(candidates[at].user);
            features[15] := lp1[at];
            features[16] := lp2[at];
            features[17] := lp[at] - lp1[at];
            features[18] := lp1[at] - lp1_max;
            features[19] := Min(context_units, 32);
            features[20] := shared;
            features[21] := weight_rank;
            features[22] := plain[at];
            features[23] := lp[at] - plain[at];
            features[24] := lp[at] - plain[at] - gain_max;
            score := nc_short_gbdt_score(features);
            // The trace holds the view the call is decided on with its context.
            if Assigned(nc_char_lm_short_trace) and (with_context = (context <> '')) then
            begin
                line := candidates[at].text;
                for against := 0 to c_short_gbdt_feature_count - 1 do
                    line := line + #9 + FloatToStr(features[against], TFormatSettings.Invariant);
                nc_char_lm_short_trace(line + #9 + FloatToStr(score, TFormatSettings.Invariant));
            end;
            if at = 0 then
                best_score := score
            else if score > best_score then
            begin
                next_score := best_score;
                best_score := score;
                Result := at;
            end
            else if score > next_score then
                next_score := score;
        end;
        lead := best_score - next_score;
    end;

begin
    Result := False;
    best_index := 0;
    count := Min(Length(candidates), c_char_lm_short_choice_limit);
    if (model = nil) or (count < 2) or (not model.char_lm_ready) then
        Exit;
    // Each text and its first one and two characters, scored once each.
    SetLength(slots, count);
    slot_of := TDictionary<string, Integer>.Create;
    try
        for idx := 0 to count - 1 do
        begin
            chars := code_points(candidates[idx].text);
            for part := 0 to 2 do
            begin
                if part = 0 then
                    prefix := candidates[idx].text
                else
                    prefix := string.Join('', Copy(chars, 0, part));
                if not slot_of.TryGetValue(prefix, other) then
                begin
                    other := Length(texts);
                    texts := texts + [prefix];
                    slot_of.Add(prefix, other);
                end;
                slots[idx][part] := other;
            end;
        end;
    finally
        slot_of.Free;
    end;
    // Without context, in the order of the texts themselves: the model's
    // scores depend on what else is in a call, so the call must not depend on
    // the order the candidates arrive in. The same group of words then always
    // gets the same scores, and the host keeps them.
    sorted_texts := Copy(texts);
    TArray.Sort<string>(sorted_texts, TStringComparer.Ordinal);
    if model.score_texts('', sorted_texts, Length(sorted_texts), 0, logp) <>
        Length(sorted_texts) then
        Exit;
    SetLength(plain, count);
    SetLength(plain1, count);
    SetLength(plain2, count);
    for idx := 0 to count - 1 do
    begin
        for part := 0 to 2 do
        begin
            TArray.BinarySearch<string>(sorted_texts, texts[slots[idx][part]], other,
                TStringComparer.Ordinal);
            case part of
                0: plain[idx] := logp[other];
                1: plain1[idx] := logp[other];
            else
                plain2[idx] := logp[other];
            end;
        end;
    end;
    SetLength(log_weight, count);
    SetLength(log_display, count);
    for idx := 0 to count - 1 do
    begin
        log_weight[idx] := 0.0;
        if candidates[idx].has_dict_weight then
            log_weight[idx] := Ln(1.0 + Max(0, candidates[idx].dict_weight));
        log_display[idx] := Ln(1.0 + Max(0, candidates[idx].display_score));
    end;
    best_index := choose(False, plain_lead);
    // A trace always takes the call with the context: it is what the ranker
    // is fit on.
    if (context = '') or ((plain_lead >= c_char_lm_short_plain_lead) and
        not Assigned(nc_char_lm_short_trace)) then
        Exit(True);
    best_index := 0;
    if model.score_texts(context, texts, Length(texts), 0, logp) <> Length(texts) then
        Exit;
    best_index := choose(True, plain_lead);
    Result := True;
end;

function nc_char_lm_choose_long(const model: IncCharLm; const context: string;
    const pool: TArray<TncCharLmLongCandidate>; const visible: string;
    const expected_units: Integer; out chosen, second: string): Boolean;
var
    complete: TArray<TncCharLmLongCandidate>;
    item: TncCharLmLongCandidate;
    order: TArray<Integer>;
    texts: TArray<string>;
    logp: TArray<Single>;
    formulas: TArray<Double>;
    features: array[0..c_long_gbdt_feature_count - 1] of Double;
    text, visible_text, line: string;
    idx, other, count, visible_index, scored, best, runner_up, lp_rank: Integer;
    lp_max, lp_visible, formula_max, score, best_score, runner_up_score: Double;
begin
    Result := False;
    chosen := '';
    second := '';
    if (model = nil) or (expected_units < c_char_lm_long_min_units) or
        (not model.char_lm_ready) then
        Exit;

    // Complete, distinct texts in original order, then stably by final rank.
    count := 0;
    SetLength(complete, Length(pool) + 1);
    for idx := 0 to High(pool) do
    begin
        text := Trim(pool[idx].text);
        if (text = '') or (nc_char_lm_code_point_count(text) <> expected_units) then
            Continue;
        other := 0;
        while (other < count) and (complete[other].text <> text) do
            Inc(other);
        if other < count then
            Continue;
        complete[count] := pool[idx];
        complete[count].text := text;
        Inc(count);
    end;
    for idx := 1 to count - 1 do
    begin
        item := complete[idx];
        best := idx - 1;
        while (best >= 0) and (complete[best].rank > item.rank) do
        begin
            complete[best + 1] := complete[best];
            Dec(best);
        end;
        complete[best + 1] := item;
    end;

    visible_text := Trim(visible);
    visible_index := -1;
    if (visible_text <> '') and
        (nc_char_lm_code_point_count(visible_text) = expected_units) then
    begin
        visible_index := 0;
        while (visible_index < count) and (complete[visible_index].text <> visible_text) do
            Inc(visible_index);
        if visible_index = count then
        begin
            complete[count] := Default(TncCharLmLongCandidate);
            complete[count].text := visible_text;
            Inc(count);
        end;
    end;

    SetLength(order, 0);
    if visible_index >= 0 then
        order := [visible_index];
    for idx := 0 to Min(c_char_lm_long_pool_limit, count) - 1 do
        if idx <> visible_index then
            order := order + [idx];
    if Length(order) < c_char_lm_long_min_count then
        Exit;

    SetLength(texts, Length(order));
    for idx := 0 to High(order) do
        texts[idx] := complete[order[idx]].text;
    scored := model.score_texts(context, texts, c_char_lm_long_min_count,
        c_char_lm_long_max_nodes, logp);
    if (scored < c_char_lm_long_min_count) or (scored > Length(order)) or
        (Length(logp) < scored) then
        Exit;

    // The earlier score: LM - w * ln(pool position) + bonus * [is visible].
    SetLength(formulas, scored);
    lp_max := -MaxDouble;
    formula_max := -MaxDouble;
    for idx := 0 to scored - 1 do
    begin
        formulas[idx] := logp[idx] - c_char_lm_long_rank_weight * Ln(order[idx] + 1);
        if order[idx] = visible_index then
            formulas[idx] := formulas[idx] + c_char_lm_long_visible_bonus;
        lp_max := Max(lp_max, logp[idx]);
        formula_max := Max(formula_max, formulas[idx]);
    end;
    lp_visible := 0.0;
    if visible_index >= 0 then
        lp_visible := logp[0];

    best := -1;
    best_score := 0.0;
    runner_up := -1;
    runner_up_score := 0.0;
    for idx := 0 to scored - 1 do
    begin
        item := complete[order[idx]];
        lp_rank := 0;
        for other := 0 to scored - 1 do
            if (logp[other] > logp[idx]) or ((logp[other] = logp[idx]) and (other < idx)) then
                Inc(lp_rank);
        features[0] := logp[idx];
        features[1] := logp[idx] / expected_units;
        features[2] := logp[idx] - lp_max;
        features[3] := 0.0;
        if visible_index >= 0 then
            features[3] := logp[idx] - lp_visible;
        features[4] := lp_rank;
        features[5] := idx;
        features[6] := Ln(1.0 + Max(0, item.rank));
        features[7] := Ord(order[idx] = visible_index);
        features[8] := scored;
        features[9] := Min(nc_char_lm_code_point_count(context), 32);
        features[10] := Ord(item.has_evidence);
        features[11] := formulas[idx];
        features[12] := formulas[idx] - formula_max;
        for other := 0 to c_long_gbdt_evidence_count - 1 do
            features[13 + other] := item.evidence[other];
        score := nc_long_gbdt_score(features);
        if Assigned(nc_char_lm_long_trace) then
        begin
            line := item.text;
            for other := 0 to c_long_gbdt_feature_count - 1 do
                line := line + #9 + FloatToStr(features[other], TFormatSettings.Invariant);
            nc_char_lm_long_trace(line + #9 + FloatToStr(score, TFormatSettings.Invariant));
        end;
        if (best < 0) or (score > best_score) then
        begin
            runner_up := best;
            runner_up_score := best_score;
            best := order[idx];
            best_score := score;
        end
        else if (runner_up < 0) or (score > runner_up_score) then
        begin
            runner_up := order[idx];
            runner_up_score := score;
        end;
    end;
    chosen := complete[best].text;
    if runner_up >= 0 then
        second := complete[runner_up].text;
    Result := True;
end;

end.
