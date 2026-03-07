unit nc_dictionary_intf;

interface

uses
    nc_types;

type
    TncDictionaryProvider = class
    public
        function lookup(const pinyin: string; out results: TncCandidateList): Boolean; virtual; abstract;
        procedure begin_learning_batch; virtual;
        procedure commit_learning_batch; virtual;
        procedure rollback_learning_batch; virtual;
        procedure set_debug_mode(const enabled: Boolean); virtual;
        procedure record_commit(const pinyin: string; const text: string); virtual;
        procedure record_context_pair(const left_text: string; const committed_text: string); virtual;
        procedure record_context_trigram(const prev_prev_text: string; const prev_text: string;
            const committed_text: string); virtual;
        procedure record_query_segment_path(const query_key: string; const encoded_path: string); virtual;
        function get_context_bonus(const left_text: string; const candidate_text: string): Integer; virtual;
        function get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
            const candidate_text: string): Integer; virtual;
        function get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer; virtual;
        procedure remove_user_entry(const pinyin: string; const text: string); virtual;
        function get_candidate_penalty(const pinyin: string; const text: string): Integer; virtual;
    end;

implementation

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

procedure TncDictionaryProvider.record_commit(const pinyin: string; const text: string);
begin
end;

procedure TncDictionaryProvider.record_context_pair(const left_text: string; const committed_text: string);
begin
end;

procedure TncDictionaryProvider.record_context_trigram(const prev_prev_text: string; const prev_text: string;
    const committed_text: string);
begin
end;

procedure TncDictionaryProvider.record_query_segment_path(const query_key: string; const encoded_path: string);
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

function TncDictionaryProvider.get_query_segment_path_bonus(const query_key: string;
    const encoded_path: string): Integer;
begin
    Result := 0;
end;

procedure TncDictionaryProvider.remove_user_entry(const pinyin: string; const text: string);
begin
end;

function TncDictionaryProvider.get_candidate_penalty(const pinyin: string; const text: string): Integer;
begin
    Result := 0;
end;

end.
