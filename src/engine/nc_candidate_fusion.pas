unit nc_candidate_fusion;

interface

uses
    System.SysUtils,
    System.Generics.Collections,
    nc_types;

type
    TncCandidateFusion = class
    private
        function build_key(const text: string): string;
    public
        function merge_candidates(const base_candidates: TncCandidateList; const ai_candidates: TncCandidateList;
            const max_candidates: Integer): TncCandidateList;
    end;

implementation

function TncCandidateFusion.build_key(const text: string): string;
begin
    Result := LowerCase(Trim(text));
end;

function TncCandidateFusion.merge_candidates(const base_candidates: TncCandidateList; const ai_candidates: TncCandidateList;
    const max_candidates: Integer): TncCandidateList;
var
    seen: TDictionary<string, Boolean>;
    list: TList<TncCandidate>;
    i: Integer;
    key: string;
    limit: Integer;
begin
    seen := TDictionary<string, Boolean>.Create;
    list := TList<TncCandidate>.Create;
    try
        for i := 0 to High(base_candidates) do
        begin
            key := build_key(base_candidates[i].text);
            if not seen.ContainsKey(key) then
            begin
                seen.Add(key, True);
                list.Add(base_candidates[i]);
            end;
        end;

        for i := 0 to High(ai_candidates) do
        begin
            key := build_key(ai_candidates[i].text);
            if not seen.ContainsKey(key) then
            begin
                seen.Add(key, True);
                list.Add(ai_candidates[i]);
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

end.
