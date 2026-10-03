unit nc_local_repair_guard;

interface

uses nc_dictionary_intf;

type
    TncValidatedRepairPath = record
        text, aligned_pinyin, segment_path: string;
        // Lexical/alignment validity, not a guarantee of sentence correctness.
        exact_path, boundary_repaired: Boolean;
        lm_gain: Integer;
    end;

{ The dictionary path of a whole-sentence repair that a model already judged
  against the draft (the pinyin-conditioned LM): every character must spell its
  syllable, and the text is segmented into dictionary entries of up to four
  characters, preferring longer and heavier entries. exact_path is False when
  no segmentation exists. }
function build_repair_path(const dictionary: TncDictionaryProvider;
    const proposal, aligned_pinyin: string): TncValidatedRepairPath;

implementation

uses System.SysUtils, System.Math, nc_types;

function build_repair_path(const dictionary: TncDictionaryProvider;
    const proposal, aligned_pinyin: string): TncValidatedRepairPath;
type
    TState = record
        valid: Boolean;
        score: Int64;
        previous: Integer;
    end;
var
    syllables: TArray<string>;
    states: TArray<TState>;
    items: TncCandidateList;
    item: TncCandidate;
    parts: TArray<string>;
    key, text: string;
    start_idx, end_idx, k, weight: Integer;
    found: Boolean;
    score: Int64;
begin
    Result := Default(TncValidatedRepairPath);
    Result.text := proposal;
    Result.aligned_pinyin := aligned_pinyin;
    syllables := aligned_pinyin.Split([#3], TStringSplitOptions.ExcludeEmpty);
    if (dictionary = nil) or (Length(syllables) <> Length(proposal)) then Exit;
    for k := 0 to High(syllables) do
        if not dictionary.single_char_matches_pinyin(syllables[k], proposal[k + 1]) then Exit;
    SetLength(states, Length(proposal) + 1);
    states[0].valid := True;
    for end_idx := 1 to Length(proposal) do
        for start_idx := Max(0, end_idx - 4) to end_idx - 1 do
        begin
            if not states[start_idx].valid then Continue;
            text := Copy(proposal, start_idx + 1, end_idx - start_idx);
            key := '';
            for k := start_idx to end_idx - 1 do key := key + syllables[k];
            found := False;
            weight := 0;
            if end_idx - start_idx = 1 then
                found := True
            else
            begin
                dictionary.lookup_isolated_exact_component(key, items);
                for item in items do
                    if (item.text = text) and (item.comment = '') and (item.source <> cs_user) then
                    begin
                        found := True;
                        if item.has_dict_weight then weight := Max(weight, item.dict_weight)
                        else weight := Max(weight, item.score);
                    end;
            end;
            if not found then Continue;
            score := states[start_idx].score + (end_idx - start_idx - 1) * 10000 + Min(9999, Max(0, weight));
            if states[end_idx].valid and (score <= states[end_idx].score) then Continue;
            states[end_idx].valid := True;
            states[end_idx].score := score;
            states[end_idx].previous := start_idx;
        end;
    if not states[Length(proposal)].valid then Exit;
    end_idx := Length(proposal);
    parts := nil;
    while end_idx > 0 do
    begin
        start_idx := states[end_idx].previous;
        parts := [Copy(proposal, start_idx + 1, end_idx - start_idx)] + parts;
        end_idx := start_idx;
    end;
    Result.segment_path := String.Join(#3, parts);
    Result.exact_path := True;
end;

end.
