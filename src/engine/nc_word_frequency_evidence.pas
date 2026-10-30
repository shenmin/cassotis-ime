unit nc_word_frequency_evidence;

interface

type
    TncWordFrequencyLookup = reference to function(const text: string): Integer;
    TncWordFrequencyEvidence = array[0..5] of Double;

// Corpus support for non-overlapping words, independent of how a lattice
// happened to segment a candidate. Lookup returns 100 * log10(1 + count).
function nc_build_word_frequency_evidence(const text: string;
    const lookup: TncWordFrequencyLookup): TncWordFrequencyEvidence;

implementation

uses System.SysUtils, System.Math;

function nc_build_word_frequency_evidence(const text: string;
    const lookup: TncWordFrequencyLookup): TncWordFrequencyEvidence;
var
    offsets, value, covered, segments, minimum: TArray<Integer>;
    idx, count, finish, size, score, proposal, pair_sum, longest: Integer;
begin
    Result := Default(TncWordFrequencyEvidence);
    if (text = '') or not Assigned(lookup) then
        Exit;
    SetLength(offsets, Length(text) + 1);
    count := 0;
    idx := 1;
    while idx <= Length(text) do
    begin
        offsets[count] := idx;
        Inc(count);
        if (text[idx] >= #$D800) and (text[idx] <= #$DBFF) and
            (idx < Length(text)) and (text[idx + 1] >= #$DC00) and
            (text[idx + 1] <= #$DFFF) then
            Inc(idx);
        Inc(idx);
    end;
    offsets[count] := Length(text) + 1;
    SetLength(value, count + 1);
    SetLength(covered, count + 1);
    SetLength(segments, count + 1);
    SetLength(minimum, count + 1);
    pair_sum := 0;
    longest := 0;
    for finish := 1 to count do
    begin
        value[finish] := value[finish - 1];
        covered[finish] := covered[finish - 1];
        segments[finish] := segments[finish - 1];
        minimum[finish] := minimum[finish - 1];
        for size := Min(4, finish) downto 2 do
        begin
            score := Max(0, lookup(Copy(text, offsets[finish - size],
                offsets[finish] - offsets[finish - size])));
            if size = 2 then
                Inc(pair_sum, score);
            if score > 0 then
                longest := Max(longest, size);
            proposal := value[finish - size] + score * size;
            if (score > 0) and (proposal > value[finish]) then
            begin
                value[finish] := proposal;
                covered[finish] := covered[finish - size] + size;
                segments[finish] := segments[finish - size] + 1;
                if segments[finish - size] > 0 then
                    minimum[finish] := Min(minimum[finish - size], score)
                else
                    minimum[finish] := score;
            end;
        end;
    end;
    Result[0] := value[count] / count;
    Result[1] := covered[count] / count;
    Result[2] := minimum[count];
    Result[3] := segments[count] / count;
    Result[4] := longest;
    Result[5] := pair_sum / Max(1, count - 1);
end;

end.
