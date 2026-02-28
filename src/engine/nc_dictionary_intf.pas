unit nc_dictionary_intf;

interface

uses
    nc_types;

type
    TncDictionaryProvider = class
    public
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; virtual; abstract;
        procedure record_commit(const pinyin: string; const text: string); virtual;
        procedure remove_user_entry(const pinyin: string; const text: string); virtual;
        function get_candidate_penalty(const pinyin: string; const text: string): Integer; virtual;
    end;

implementation

procedure TncDictionaryProvider.record_commit(const pinyin: string; const text: string);
begin
end;

procedure TncDictionaryProvider.remove_user_entry(const pinyin: string; const text: string);
begin
end;

function TncDictionaryProvider.get_candidate_penalty(const pinyin: string; const text: string): Integer;
begin
    Result := 0;
end;

end.
