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
        function lookup_full_pinyin_prefix(const pinyin_prefix: string;
            out results: TncCandidateList): Boolean; virtual;
        function single_char_matches_pinyin(const pinyin: string; const text_unit: string): Boolean; virtual;
        procedure begin_learning_batch; virtual;
        procedure commit_learning_batch; virtual;
        procedure rollback_learning_batch; virtual;
        procedure set_debug_mode(const enabled: Boolean); virtual;
        procedure record_commit(const pinyin: string; const text: string); virtual;
        procedure record_context_pair(const left_text: string; const committed_text: string); virtual;
        procedure record_context_trigram(const prev_prev_text: string; const prev_text: string;
            const committed_text: string); virtual;
        procedure record_query_segment_path(const query_key: string; const encoded_path: string); virtual;
        procedure record_query_segment_path_penalty(const query_key: string; const encoded_path: string); virtual;
        procedure record_candidate_penalty(const pinyin: string; const text: string); virtual;
        function get_context_bonus(const left_text: string; const candidate_text: string): Integer; virtual;
        function get_context_trigram_bonus(const prev_prev_text: string; const prev_text: string;
            const candidate_text: string): Integer; virtual;
        function get_query_choice_bonus(const query_key: string; const candidate_text: string): Integer; virtual;
        function get_query_latest_choice_text(const query_key: string): string; virtual;
        function get_query_segment_path_bonus(const query_key: string; const encoded_path: string): Integer; virtual;
        function get_query_segment_path_penalty(const query_key: string; const encoded_path: string): Integer; virtual;
        function should_suppress_exact_query_learning(const pinyin: string; const text: string): Boolean; virtual;
        procedure remove_user_entry(const pinyin: string; const text: string); virtual;
        function get_candidate_penalty(const pinyin: string; const text: string): Integer; virtual;
    end;

implementation

function TncDictionaryProvider.lookup_exact_full_pinyin(const pinyin: string;
    out results: TncCandidateList): Boolean;
begin
    Result := lookup(pinyin, results);
end;

function TncDictionaryProvider.lookup_full_pinyin_prefix(const pinyin_prefix: string;
    out results: TncCandidateList): Boolean;
begin
    SetLength(results, 0);
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

function TncDictionaryProvider.get_query_segment_path_penalty(const query_key: string;
    const encoded_path: string): Integer;
begin
    Result := 0;
end;

function TncDictionaryProvider.should_suppress_exact_query_learning(const pinyin: string;
    const text: string): Boolean;
begin
    Result := False;
end;

procedure TncDictionaryProvider.remove_user_entry(const pinyin: string; const text: string);
begin
end;

function TncDictionaryProvider.get_candidate_penalty(const pinyin: string; const text: string): Integer;
begin
    Result := 0;
end;

end.
