unit nc_dictionary_intf;

interface

uses
    nc_types;

type
    TncDictionaryProvider = class
    public
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; virtual; abstract;
        procedure record_commit(const pinyin: string; const text: string); virtual;
    end;

implementation

procedure TncDictionaryProvider.record_commit(const pinyin: string; const text: string);
begin
end;

end.
