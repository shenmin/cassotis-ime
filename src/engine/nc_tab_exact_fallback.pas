unit nc_tab_exact_fallback;

interface

uses
    nc_types, nc_dictionary_intf, nc_char_lm;

{ Joins the visible head word with an exact dictionary word for the rest of the
  input. With a model, the shared LM weighs the homophone tails after the head
  (the dictionary's choice keeps a bonus); user words and learned choices keep
  their priority. }
function nc_try_exact_tail_completion(const dictionary: TncDictionaryProvider;
    const query: string; const visible: TncCandidateList;
    out completion: TncOneKeyCompletion; const model: IncCharLm = nil;
    const context: string = ''): Boolean;

{ Reads the rest of the input after the visible head word as several exact
  dictionary words when no single word covers it, and picks the reading with
  the shared LM (the dictionary's first reading without one). text is the
  whole reading and path_text its words separated by #3. Only a base for the
  Tab continuation; it is never shown by itself. }
function nc_decode_tail_reading(const dictionary: TncDictionaryProvider;
    const query: string; const visible: TncCandidateList; const model: IncCharLm;
    const context: string; out text, path_text: string): Boolean;

implementation

uses
    System.SysUtils, System.Math, nc_pinyin_parser;

const
    c_max_word_units = 4;
    c_max_exact_options = 64;

type
    // The visible head word and the typed rest after it.
    TncExactTailSplit = record
        head_raw, tail_raw, tail_key: string;
        head_syllables, tail_syllables: TncPinyinParseResult;
    end;

function compact_key(const value: string): string;
var ch: Char;
begin
    Result := '';
    for ch in LowerCase(value) do
        if ch <> #39 then
        begin
            if not CharInSet(ch, ['a'..'z']) then Exit('');
            Result := Result + ch;
        end;
end;

function parse_complete_word(const parser: TncPinyinParser; const value: string;
    out syllables: TncPinyinParseResult): Boolean;
var syllable: TncPinyinSyllable; reconstructed: string;
begin
    Result := False;
    if (value = '') or (value[1] = #39) or
        (value[Length(value)] = #39) or (Pos(#39#39, value) > 0) then Exit;
    syllables := parser.parse(value);
    if (Length(syllables) < 1) or (Length(syllables) > c_max_word_units) then Exit;
    reconstructed := '';
    for syllable in syllables do
    begin
        if not nc_is_canonical_pinyin_syllable(syllable.text) then Exit;
        reconstructed := reconstructed + syllable.text;
    end;
    Result := reconstructed = compact_key(value);
end;

function aligned_exact(const dictionary: TncDictionaryProvider; const value: TncCandidate;
    const syllables: TncPinyinParseResult; const first: Integer = 0;
    const count: Integer = -1): Boolean;
var unit_idx, units: Integer;
begin
    Result := False;
    units := count;
    if units < 0 then units := Length(syllables) - first;
    if (value.comment <> '') or (value.fuzzy_cost <> 0) or
        (not value.has_dict_weight) or (Length(value.text) <> units) then Exit;
    // Compact lookups can contain a different segmentation (he/ne vs hen/e).
    // Validate the fixed input boundaries instead of silently resegmenting.
    for unit_idx := 0 to units - 1 do
        if not dictionary.single_char_matches_pinyin(
            syllables[first + unit_idx].text, value.text[unit_idx + 1]) then Exit;
    Result := True;
end;

// The visible top is an exact head word whose comment is the typed rest; both
// parts are whole canonical syllables of at most c_max_word_units.
function split_after_visible_head(const dictionary: TncDictionaryProvider;
    const parser: TncPinyinParser; const query: string; const visible: TncCandidateList;
    out split: TncExactTailSplit): Boolean;
var
    raw, compact, head_key: string;
    heads: TncCandidateList;
    item: TncCandidate;
    idx, split_at, head_letters, letters_seen: Integer;
begin
    Result := False;
    split := Default(TncExactTailSplit);
    if (dictionary = nil) or (Length(visible) = 0) or
        (visible[0].text = '') or (visible[0].comment = '') or
        (visible[0].fuzzy_cost <> 0) then Exit;
    raw := LowerCase(Trim(query));
    compact := compact_key(raw);
    split.tail_key := compact_key(visible[0].comment);
    if (compact = '') or (Length(compact) > 48) or (split.tail_key = '') or
        (Length(split.tail_key) >= Length(compact)) or
        (not compact.EndsWith(split.tail_key)) then Exit;
    head_letters := Length(compact) - Length(split.tail_key);
    head_key := Copy(compact, 1, head_letters);
    split_at := 0;
    letters_seen := 0;
    for idx := 1 to Length(raw) do
        if raw[idx] <> #39 then
        begin
            Inc(letters_seen);
            if letters_seen = head_letters then
            begin
                split_at := idx;
                Break;
            end;
        end;
    split.head_raw := Copy(raw, 1, split_at);
    split.tail_raw := Copy(raw, split_at + 1, MaxInt);
    if (split.tail_raw <> '') and (split.tail_raw[1] = #39) then Delete(split.tail_raw, 1, 1);
    if (not parse_complete_word(parser, split.head_raw, split.head_syllables)) or
        (not parse_complete_word(parser, split.tail_raw, split.tail_syllables)) then Exit;
    if not dictionary.lookup_isolated_exact_component(head_key, heads) then Exit;
    for item in heads do
        if (item.text = visible[0].text) and
            aligned_exact(dictionary, item, split.head_syllables) then
            Exit(True);
end;

function nc_try_exact_tail_completion(const dictionary: TncDictionaryProvider;
    const query: string; const visible: TncCandidateList;
    out completion: TncOneKeyCompletion; const model: IncCharLm;
    const context: string): Boolean;
const
    c_repeated_choice_floor = 320;
    // LM tail choice, chosen on the 7,996-sentence fiction Tab dev set: the
    // heaviest tails weighed, and the dictionary choice's bonus in nats.
    c_lm_tail_limit = 16;
    c_lm_dictionary_bonus = 0.5;
var
    split: TncExactTailSplit;
    tails: TncCandidateList;
    parser: TncPinyinParser;
    idx, other, best, score, best_score, bonus: Integer;
    best_learned: Boolean;
    item: TncCandidate;
    options: TArray<Integer>;
    texts: TArray<string>;
    logp: TArray<Single>;
    value, best_value: Double;
begin
    Result := False;
    completion := Default(TncOneKeyCompletion);
    parser := TncPinyinParser.create;
    try
        if not split_after_visible_head(dictionary, parser, query, visible, split) then Exit;
        if not dictionary.lookup_isolated_exact_component(split.tail_key, tails) then Exit;
        best := -1;
        best_score := Low(Integer);
        best_learned := False;
        for idx := 0 to Min(High(tails), c_max_exact_options - 1) do
        begin
            if (tails[idx].comment <> '') or (tails[idx].fuzzy_cost <> 0) or
                (not tails[idx].has_dict_weight) then Continue;
            score := tails[idx].dict_weight;
            bonus := 0;
            if tails[idx].source <> cs_user then
            begin
                bonus := dictionary.get_query_choice_bonus(split.tail_key, tails[idx].text);
                if bonus >= c_repeated_choice_floor then Inc(score, bonus);
            end;
            if (best >= 0) and (tails[best].source = cs_user) and
                (tails[idx].source <> cs_user) then Continue;
            if (best < 0) or ((tails[idx].source = cs_user) and
                (tails[best].source <> cs_user)) or (score > best_score) then
            begin
                if not aligned_exact(dictionary, tails[idx], split.tail_syllables) then Continue;
                best := idx;
                best_score := score;
                best_learned := bonus >= c_repeated_choice_floor;
            end;
        end;
        if best < 0 then Exit;
        if (model <> nil) and (tails[best].source <> cs_user) and (not best_learned) then
        begin
            // The heaviest aligned dictionary tails, stably by weight.
            SetLength(options, 0);
            for idx := 0 to Min(High(tails), c_max_exact_options - 1) do
            begin
                if (tails[idx].comment <> '') or (tails[idx].fuzzy_cost <> 0) or
                    (not tails[idx].has_dict_weight) or (tails[idx].source = cs_user) or
                    (not aligned_exact(dictionary, tails[idx], split.tail_syllables)) then
                    Continue;
                other := Length(options);
                options := options + [idx];
                while (other > 0) and
                    (tails[options[other - 1]].dict_weight < tails[idx].dict_weight) do
                begin
                    options[other] := options[other - 1];
                    Dec(other);
                end;
                options[other] := idx;
            end;
            if Length(options) > c_lm_tail_limit then
                SetLength(options, c_lm_tail_limit);
            SetLength(texts, Length(options));
            for idx := 0 to High(options) do
                texts[idx] := visible[0].text + tails[options[idx]].text;
            if (Length(options) >= 2) and model.char_lm_ready and
                (model.score_texts(context, texts, Length(texts), 0, logp) = Length(texts)) then
            begin
                other := -1;
                best_value := 0.0;
                for idx := 0 to High(options) do
                begin
                    value := logp[idx];
                    if options[idx] = best then
                        value := value + c_lm_dictionary_bonus;
                    if (other < 0) or (value > best_value) then
                    begin
                        other := idx;
                        best_value := value;
                    end;
                end;
                best := options[other];
            end;
        end;
        for item in visible do
            if (item.comment = '') and (item.text = visible[0].text + tails[best].text) then Exit;
        completion.text := visible[0].text + tails[best].text;
        completion.full_pinyin := split.head_raw + #39 + split.tail_raw;
        completion.path_text := visible[0].text + #3 + tails[best].text;
        completion.prefix_anchored := True;
        completion.source := okcs_exact_tail_fallback;
        Result := True;
    finally
        parser.Free;
    end;
end;

function nc_decode_tail_reading(const dictionary: TncDictionaryProvider;
    const query: string; const visible: TncCandidateList; const model: IncCharLm;
    const context: string; out text, path_text: string): Boolean;
const
    // Chosen on the no-request short inputs of the 7,996-sentence fiction Tab
    // dev set: the heaviest words per span, the readings of the fewest-word
    // segmentations, and the most readings the LM weighs.
    c_words_per_span = 3;
    c_segmentations = 6;
    c_readings_per_segmentation = 4;
    c_max_readings = 24;
type
    TSegmentation = record
        spans: TArray<Integer>;   // span lengths in syllables
        weight: Integer;          // sum of each span's heaviest word
    end;
var
    split: TncExactTailSplit;
    parser: TncPinyinParser;
    span_words: array[0..c_max_word_units - 1, 1..c_max_word_units] of TArray<TncCandidate>;
    segmentations: TArray<TSegmentation>;
    segmentation: TSegmentation;
    readings, paths: TArray<string>;
    picks: TArray<Integer>;
    logp: TArray<Single>;
    units, start, len, mask, idx, other, span_idx, combo, combos, weight, best: Integer;
    reading, path: string;
    usable: Boolean;
    best_value: Double;

    // The heaviest aligned exact words for len syllables from start.
    function words_for(const first, count: Integer): TArray<TncCandidate>;
    var
        found: TncCandidateList;
        key: string;
        word_idx, slot: Integer;
    begin
        Result := nil;
        key := '';
        for word_idx := first to first + count - 1 do
            key := key + split.tail_syllables[word_idx].text;
        if not dictionary.lookup_isolated_exact_component(key, found) then Exit;
        for word_idx := 0 to Min(High(found), c_max_exact_options - 1) do
        begin
            if not aligned_exact(dictionary, found[word_idx], split.tail_syllables,
                first, count) then Continue;
            slot := 0;
            while (slot < Length(Result)) and (Result[slot].text <> found[word_idx].text) do
                Inc(slot);
            if slot < Length(Result) then Continue;
            // Stable insertion by weight, heaviest first.
            slot := Length(Result);
            Result := Result + [found[word_idx]];
            while (slot > 0) and (Result[slot - 1].dict_weight < found[word_idx].dict_weight) do
            begin
                Result[slot] := Result[slot - 1];
                Dec(slot);
            end;
            Result[slot] := found[word_idx];
        end;
        if Length(Result) > c_words_per_span then
            SetLength(Result, c_words_per_span);
    end;

begin
    Result := False;
    text := '';
    path_text := '';
    parser := TncPinyinParser.create;
    try
        if not split_after_visible_head(dictionary, parser, query, visible, split) then Exit;
        units := Length(split.tail_syllables);
        for start := 0 to units - 1 do
            for len := 1 to units - start do
                span_words[start, len] := words_for(start, len);
        // Every segmentation into words, fewest words then heaviest first.
        SetLength(segmentations, 0);
        for mask := 0 to (1 shl (units - 1)) - 1 do
        begin
            segmentation := Default(TSegmentation);
            start := 0;
            usable := True;
            for idx := 1 to units do
                if (idx = units) or ((mask and (1 shl (idx - 1))) <> 0) then
                begin
                    len := idx - start;
                    if Length(span_words[start, len]) = 0 then
                    begin
                        usable := False;
                        Break;
                    end;
                    segmentation.spans := segmentation.spans + [len];
                    Inc(segmentation.weight, span_words[start, len][0].dict_weight);
                    start := idx;
                end;
            if not usable then Continue;
            other := Length(segmentations);
            segmentations := segmentations + [segmentation];
            while (other > 0) and
                ((Length(segmentations[other - 1].spans) > Length(segmentation.spans)) or
                ((Length(segmentations[other - 1].spans) = Length(segmentation.spans)) and
                (segmentations[other - 1].weight < segmentation.weight))) do
            begin
                segmentations[other] := segmentations[other - 1];
                Dec(other);
            end;
            segmentations[other] := segmentation;
        end;
        // The heaviest word combinations of the leading segmentations.
        SetLength(readings, 0);
        SetLength(paths, 0);
        for idx := 0 to Min(c_segmentations, Length(segmentations)) - 1 do
        begin
            segmentation := segmentations[idx];
            combos := 1;
            for len in segmentation.spans do
                combos := combos * c_words_per_span;
            // Combinations in order of total weight: enumerate, then keep the
            // heaviest c_readings_per_segmentation.
            SetLength(picks, 0);
            for combo := 0 to combos - 1 do
            begin
                other := combo;
                start := 0;
                usable := True;
                weight := 0;
                for span_idx := 0 to High(segmentation.spans) do
                begin
                    len := segmentation.spans[span_idx];
                    if (other mod c_words_per_span) >= Length(span_words[start, len]) then
                    begin
                        usable := False;
                        Break;
                    end;
                    Inc(weight, span_words[start, len][other mod c_words_per_span].dict_weight);
                    other := other div c_words_per_span;
                    Inc(start, len);
                end;
                if not usable then Continue;
                // picks holds (combo, weight) pairs, stably by weight.
                span_idx := Length(picks);
                picks := picks + [combo, weight];
                while (span_idx > 0) and (picks[span_idx - 1] < weight) do
                begin
                    picks[span_idx] := picks[span_idx - 2];
                    picks[span_idx + 1] := picks[span_idx - 1];
                    Dec(span_idx, 2);
                end;
                picks[span_idx] := combo;
                picks[span_idx + 1] := weight;
            end;
            for combo := 0 to Min(c_readings_per_segmentation, Length(picks) div 2) - 1 do
            begin
                other := picks[combo * 2];
                start := 0;
                reading := visible[0].text;
                path := visible[0].text;
                for len in segmentation.spans do
                begin
                    reading := reading + span_words[start, len][other mod c_words_per_span].text;
                    path := path + #3 + span_words[start, len][other mod c_words_per_span].text;
                    other := other div c_words_per_span;
                    Inc(start, len);
                end;
                usable := Length(readings) < c_max_readings;
                for span_idx := 0 to High(readings) do
                    usable := usable and (readings[span_idx] <> reading);
                if usable then
                begin
                    readings := readings + [reading];
                    paths := paths + [path];
                end;
            end;
        end;
        if Length(readings) = 0 then Exit;
        best := 0;
        if (model <> nil) and (Length(readings) >= 2) and model.char_lm_ready and
            (model.score_texts(context, readings, Length(readings), 0, logp) = Length(readings)) then
        begin
            best_value := logp[0];
            for idx := 1 to High(readings) do
                if logp[idx] > best_value then
                begin
                    best := idx;
                    best_value := logp[idx];
                end;
        end;
        text := readings[best];
        path_text := paths[best];
        Result := True;
    finally
        parser.Free;
    end;
end;

end.
