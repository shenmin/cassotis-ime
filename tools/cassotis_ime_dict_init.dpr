program cassotis_ime_dict_init;

{$APPTYPE CONSOLE}
{$R 'cassotis_ime_dict_init.res'}

uses
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    System.Generics.Collections,
    nc_types in '..\src\common\nc_types.pas',
    nc_pinyin_parser in '..\src\engine\nc_pinyin_parser.pas',
    nc_sqlite in '..\src\common\nc_sqlite.pas';

type
    TncImportMode = (imBaseDict, imQueryPathPrior, imLmTransition, imCharLm,
        imCharReverseLm, imTransitionCompletion, imCompletionPrior,
        imCompletionLookup, imCompletionCompetition, imCompletionPairAudit,
        imLongCompletion, imShortPromotion);

const
    c_segment_path_separator = #3;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_dict_init <db_path> <schema_path> [import_path] [base|query_path|lm_transition|char_lm|char_reverse_lm|transition_completion|completion_prior|completion_lookup|' +
        'completion_competition|completion_pair_audit|long_completion|short_promotion]');
    Writeln('       cassotis_ime_dict_init <db_path> <schema_path> --build-contains-index');
    Writeln('       cassotis_ime_dict_init <db_path> <schema_path> --require-short-promotion');
end;

{ The runtime reads a short query's promotions from the dictionary instead of
  a model, so a dictionary without them is quietly worse. Exit code 0 when
  the dictionary has such rows in the current format; the file is only read. }
function require_short_promotion(const db_path: string): Integer;
var
    conn: TncSqliteConnection;
    stmt: Psqlite3_stmt;
    rows: Integer;
begin
    rows := 0;
    conn := TncSqliteConnection.Create(db_path);
    try
        stmt := nil;
        if conn.open(SQLITE_OPEN_READONLY) and conn.prepare(
            'SELECT COUNT(*) FROM dict_base_short_promotion ' +
            'WHERE candidates <> ''''', stmt) then
        begin
            try
                if conn.step(stmt) = SQLITE_ROW then
                begin
                    rows := conn.column_int(stmt, 0);
                end;
            finally
                conn.finalize(stmt);
            end;
        end;
    finally
        conn.Free;
    end;
    if rows > 0 then
    begin
        Writeln(Format('Short promotion rows: %d', [rows]));
        Result := 0;
    end
    else
    begin
        Writeln('No short promotion rows in ' + db_path +
            ': import dict_short_promotion_*.txt (out\rebuild_dict.ps1).');
        Result := 4;
    end;
end;

function load_schema(const schema_path: string; out schema_text: string): Boolean;
begin
    schema_text := '';
    if not FileExists(schema_path) then
    begin
        Result := False;
        Exit;
    end;

    schema_text := TFile.ReadAllText(schema_path, TEncoding.ASCII);
    Result := schema_text <> '';
end;

function table_has_column(const conn: TncSqliteConnection;
    const table_name, column_name: string): Boolean;
var
    stmt: Psqlite3_stmt;
    step_result: Integer;
begin
    Result := False;
    stmt := nil;
    try
        if not conn.prepare('PRAGMA table_info(' + table_name + ')', stmt) then
        begin
            Exit;
        end;
        step_result := conn.step(stmt);
        while step_result = SQLITE_ROW do
        begin
            if SameText(conn.column_text(stmt, 1), column_name) then
            begin
                Result := True;
                Exit;
            end;
            step_result := conn.step(stmt);
        end;
    finally
        if stmt <> nil then
        begin
            conn.finalize(stmt);
        end;
    end;
end;

function ensure_base_scope_schema(const conn: TncSqliteConnection): Boolean;
begin
    Result := table_has_column(conn, 'dict_base',
        'contains_popularity_eligible') or conn.exec(
        'ALTER TABLE dict_base ADD COLUMN ' +
        'contains_popularity_eligible INTEGER NOT NULL DEFAULT 1;');
    if Result then
    begin
        Result := conn.exec(
            'INSERT OR REPLACE INTO meta(key, value) ' +
            'VALUES(''schema_version'', ''24'');');
    end;
end;

function split_line(const line: string; out pinyin: string; out text: string;
    out weight: Integer; out contains_popularity_eligible: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    pinyin := '';
    text := '';
    weight := 0;
    contains_popularity_eligible := 1;

    parts := line.Split([#9]);
    if Length(parts) < 2 then
    begin
        parts := line.Split([' ']);
    end;

    if Length(parts) < 2 then
    begin
        Exit;
    end;

    pinyin := Trim(parts[0]);
    text := Trim(parts[1]);
    if Length(parts) >= 3 then
    begin
        weight := StrToIntDef(Trim(parts[2]), 0);
    end;
    if (Length(parts) >= 4) and
        (SameText(Trim(parts[3]), 'no_contains') or
        SameText(Trim(parts[3]), '0')) then
    begin
        contains_popularity_eligible := 0;
    end;

    Result := (pinyin <> '') and (text <> '');
end;

function split_query_path_line(const line: string; out query_pinyin: string;
    out path_text: string; out weight: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    query_pinyin := '';
    path_text := '';
    weight := 0;

    parts := line.Split([#9]);
    if Length(parts) < 2 then
    begin
        Exit;
    end;

    query_pinyin := Trim(parts[0]);
    path_text := Trim(parts[1]);
    if Length(parts) >= 3 then
    begin
        weight := StrToIntDef(Trim(parts[2]), 0);
    end;

    Result := (query_pinyin <> '') and (path_text <> '');
end;

function split_transition_completion_line(const line: string;
    out typed_prefix: string; out full_pinyin: string; out text: string;
    out path_text: string; out evidence: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    typed_prefix := '';
    full_pinyin := '';
    text := '';
    path_text := '';
    evidence := 0;
    parts := line.Split([#9]);
    if Length(parts) <> 5 then
    begin
        Exit;
    end;
    typed_prefix := Trim(parts[0]);
    full_pinyin := Trim(parts[1]);
    text := Trim(parts[2]);
    path_text := Trim(parts[3]);
    evidence := StrToIntDef(Trim(parts[4]), 0);
    Result := (typed_prefix <> '') and (full_pinyin <> '') and
        (text <> '') and (path_text <> '') and (evidence > 0);
end;

function split_long_completion_line(const line: string;
    out anchor_path: string; out suffix_pinyin: string;
    out suffix_text: string; out suffix_path: string;
    out evidence: Integer; out source_count: Integer;
    out visible: Boolean): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    anchor_path := '';
    suffix_pinyin := '';
    suffix_text := '';
    suffix_path := '';
    evidence := 0;
    source_count := 0;
    visible := True;
    parts := line.Split([#9]);
    if (Length(parts) <> 6) and (Length(parts) <> 7) then
    begin
        Exit;
    end;
    anchor_path := Trim(parts[0]);
    suffix_pinyin := Trim(parts[1]);
    suffix_text := Trim(parts[2]);
    suffix_path := Trim(parts[3]);
    evidence := StrToIntDef(Trim(parts[4]), 0);
    source_count := StrToIntDef(Trim(parts[5]), 0);
    if Length(parts) = 7 then
    begin
        if (Trim(parts[6]) <> '0') and (Trim(parts[6]) <> '1') then
        begin
            Exit;
        end;
        visible := Trim(parts[6]) = '1';
    end;
    Result := (anchor_path <> '') and (suffix_pinyin <> '') and
        (suffix_text <> '') and (suffix_path <> '') and (evidence > 0) and
        (source_count >= 1);
end;

function split_completion_prior_line(const line: string;
    out pinyin: string; out text: string; out popularity_prior: Integer;
    out corpus_score: Integer; out document_score: Integer;
    out source_count: Integer; out vertical_penalty: Integer;
    out layer_kind: Integer; out path_score: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    pinyin := '';
    text := '';
    popularity_prior := 0;
    corpus_score := 0;
    document_score := 0;
    source_count := 0;
    vertical_penalty := 0;
    layer_kind := 0;
    path_score := 0;
    parts := line.Split([#9]);
    if Length(parts) <> 9 then
    begin
        Exit;
    end;
    pinyin := Trim(parts[0]);
    text := Trim(parts[1]);
    popularity_prior := StrToIntDef(Trim(parts[2]), -1);
    corpus_score := StrToIntDef(Trim(parts[3]), -1);
    document_score := StrToIntDef(Trim(parts[4]), -1);
    source_count := StrToIntDef(Trim(parts[5]), -1);
    vertical_penalty := StrToIntDef(Trim(parts[6]), -1);
    layer_kind := StrToIntDef(Trim(parts[7]), -1);
    path_score := StrToIntDef(Trim(parts[8]), -1);
    Result := (pinyin <> '') and (text <> '') and
        (popularity_prior >= 0) and (popularity_prior <= 1000) and
        (corpus_score >= 0) and (corpus_score <= 1000) and
        (document_score >= 0) and (document_score <= 1000) and
        (source_count >= 0) and (source_count <= 8) and
        (vertical_penalty >= 0) and (vertical_penalty <= 1000) and
        (layer_kind >= 0) and (layer_kind <= c_completion_layer_exact_only_specialist) and
        (path_score >= 0) and (path_score <= 1000);
end;

function split_completion_lookup_line(const line: string;
    out typed_prefix: string; out full_pinyin: string; out text: string;
    out weight: Integer; out popularity_prior: Integer;
    out corpus_score: Integer; out document_score: Integer;
    out source_count: Integer; out path_score: Integer;
    out vertical_penalty: Integer; out layer_kind: Integer;
    out prefix_anchored: Integer; out rank_order: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    typed_prefix := '';
    full_pinyin := '';
    text := '';
    weight := 0;
    popularity_prior := 0;
    corpus_score := 0;
    document_score := 0;
    source_count := 0;
    path_score := 0;
    vertical_penalty := 0;
    layer_kind := 0;
    prefix_anchored := 0;
    rank_order := 0;
    parts := line.Split([#9]);
    if Length(parts) <> 13 then
    begin
        Exit;
    end;
    typed_prefix := Trim(parts[0]);
    full_pinyin := Trim(parts[1]);
    text := Trim(parts[2]);
    weight := StrToIntDef(Trim(parts[3]), -1);
    popularity_prior := StrToIntDef(Trim(parts[4]), -1);
    corpus_score := StrToIntDef(Trim(parts[5]), -1);
    document_score := StrToIntDef(Trim(parts[6]), -1);
    source_count := StrToIntDef(Trim(parts[7]), -1);
    path_score := StrToIntDef(Trim(parts[8]), -1);
    vertical_penalty := StrToIntDef(Trim(parts[9]), -1);
    layer_kind := StrToIntDef(Trim(parts[10]), -1);
    prefix_anchored := StrToIntDef(Trim(parts[11]), -1);
    rank_order := StrToIntDef(Trim(parts[12]), -1);
    Result := (typed_prefix <> '') and (full_pinyin <> '') and
        (text <> '') and (weight > 0) and
        (popularity_prior >= 0) and (popularity_prior <= 1000) and
        (corpus_score >= 0) and (corpus_score <= 1000) and
        (document_score >= 0) and (document_score <= 1000) and
        (source_count >= 0) and (source_count <= 8) and
        (path_score >= 0) and (path_score <= 1000) and
        (vertical_penalty >= 0) and (vertical_penalty <= 1000) and
        (layer_kind >= 0) and (layer_kind <= c_completion_layer_exact_only_specialist) and
        (prefix_anchored in [0, 1]) and
        (rank_order >= 0) and (rank_order < 32);
end;

function split_completion_competition_line(const line: string;
    out context_width: Integer; out context_suffix: string;
    out typed_prefix: string; out full_pinyin: string; out text: string;
    out evidence_score: Integer; out occurrence_count: Integer;
    out source_count: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    context_width := -1;
    context_suffix := '';
    typed_prefix := '';
    full_pinyin := '';
    text := '';
    evidence_score := 0;
    occurrence_count := 0;
    source_count := 0;
    parts := line.Split([#9]);
    if Length(parts) <> 8 then
    begin
        Exit;
    end;
    context_width := StrToIntDef(Trim(parts[0]), -1);
    context_suffix := Trim(parts[1]);
    typed_prefix := Trim(parts[2]);
    full_pinyin := Trim(parts[3]);
    text := Trim(parts[4]);
    evidence_score := StrToIntDef(Trim(parts[5]), 0);
    occurrence_count := StrToIntDef(Trim(parts[6]), 0);
    source_count := StrToIntDef(Trim(parts[7]), 0);
    Result := (context_width >= 0) and (context_width <= 4) and
        (((context_width = 0) and (context_suffix = '')) or
        ((context_width > 0) and (context_suffix <> ''))) and
        (typed_prefix <> '') and (full_pinyin <> '') and (text <> '') and
        (evidence_score > 0) and (occurrence_count > 0) and
        (source_count > 0) and (source_count <= 16);
end;

function split_completion_pair_audit_line(const line: string;
    out context_width: Integer; out context_suffix: string;
    out typed_prefix: string; out baseline_full_pinyin: string;
    out baseline_text: string; out challenger_full_pinyin: string;
    out challenger_text: string; out pair_decision: Integer;
    out keep_count: Integer; out switch_count: Integer;
    out keep_source_count: Integer; out switch_source_count: Integer;
    out confidence_milli: Integer): Boolean;
var
    parts: TArray<string>;
begin
    Result := False;
    context_width := -1;
    context_suffix := '';
    typed_prefix := '';
    baseline_full_pinyin := '';
    baseline_text := '';
    challenger_full_pinyin := '';
    challenger_text := '';
    pair_decision := -2;
    keep_count := -1;
    switch_count := -1;
    keep_source_count := -1;
    switch_source_count := -1;
    confidence_milli := -1;
    parts := line.Split([#9]);
    if Length(parts) <> 13 then
    begin
        Exit;
    end;
    context_width := StrToIntDef(Trim(parts[0]), -1);
    context_suffix := Trim(parts[1]);
    typed_prefix := Trim(parts[2]);
    baseline_full_pinyin := Trim(parts[3]);
    baseline_text := Trim(parts[4]);
    challenger_full_pinyin := Trim(parts[5]);
    challenger_text := Trim(parts[6]);
    pair_decision := StrToIntDef(Trim(parts[7]), -2);
    keep_count := StrToIntDef(Trim(parts[8]), -1);
    switch_count := StrToIntDef(Trim(parts[9]), -1);
    keep_source_count := StrToIntDef(Trim(parts[10]), -1);
    switch_source_count := StrToIntDef(Trim(parts[11]), -1);
    confidence_milli := StrToIntDef(Trim(parts[12]), -1);
    Result := (context_width >= 0) and (context_width <= 4) and
        (((context_width = 0) and (context_suffix = '')) or
        ((context_width > 0) and (context_suffix <> ''))) and
        (typed_prefix <> '') and (baseline_full_pinyin <> '') and
        (baseline_text <> '') and (challenger_full_pinyin <> '') and
        (challenger_text <> '') and (pair_decision >= -1) and
        (pair_decision <= 1) and
        (keep_count >= 0) and (switch_count >= 0) and
        (keep_count + switch_count > 0) and
        (keep_source_count >= 0) and (keep_source_count <= 16) and
        (switch_source_count >= 0) and (switch_source_count <= 16) and
        (confidence_milli >= 0) and (confidence_milli <= 1000);
end;

function split_char_lm_line(const line: string; out ngram: string;
    out score: Integer; out backoff: Integer): Boolean;
var
    first_tab: Integer;
    second_tab: Integer;
    remainder: string;
begin
    Result := False;
    ngram := '';
    score := 0;
    backoff := 0;
    first_tab := Pos(#9, line);
    if first_tab <= 1 then
    begin
        Exit;
    end;
    remainder := Copy(line, first_tab + 1, MaxInt);
    second_tab := Pos(#9, remainder);
    if second_tab <= 1 then
    begin
        Exit;
    end;
    ngram := Copy(line, 1, first_tab - 1);
    if (ngram = '') or
        (not TryStrToInt(Trim(Copy(remainder, 1, second_tab - 1)), score)) or
        (not TryStrToInt(Trim(Copy(remainder, second_tab + 1, MaxInt)), backoff)) then
    begin
        Exit;
    end;
    Result := True;
end;

function normalize_pinyin_key(const value: string): string;
begin
    Result := LowerCase(Trim(value));
    Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
{$IF FALSE}
    Result := StringReplace(Result, '’', '', [rfReplaceAll]);
end;
{$ENDIF}
end;

function normalize_compact_pinyin_key(const value: string): string;
begin
    Result := normalize_pinyin_key(value);
    Result := StringReplace(Result, '''', '', [rfReplaceAll]);
end;

function normalize_query_path_text(const value: string): string;
var
    idx: Integer;
    ch: Char;
    builder: TStringBuilder;
    last_was_separator: Boolean;
begin
    builder := TStringBuilder.Create;
    try
        last_was_separator := False;
        for idx := 1 to Length(value) do
        begin
            ch := value[idx];
            if CharInSet(ch, ['|', '/', #3]) then
            begin
                if not last_was_separator then
                begin
                    builder.Append(c_segment_path_separator);
                    last_was_separator := True;
                end;
                Continue;
            end;

            if not CharInSet(ch, [#9, #10, #13, ' ']) then
            begin
                builder.Append(ch);
                last_was_separator := False;
            end;
        end;

        Result := builder.ToString;
        while (Result <> '') and (Result[1] = c_segment_path_separator) do
        begin
            Delete(Result, 1, 1);
        end;
        while (Result <> '') and (Result[Length(Result)] = c_segment_path_separator) do
        begin
            Delete(Result, Length(Result), 1);
        end;
    finally
        builder.Free;
    end;
end;

function get_query_path_segment_count(const encoded_path: string): Integer;
var
    idx: Integer;
begin
    Result := 0;
    if encoded_path = '' then
    begin
        Exit;
    end;

    Result := 1;
    for idx := 1 to Length(encoded_path) do
    begin
        if encoded_path[idx] = c_segment_path_separator then
        begin
            Inc(Result);
        end;
    end;
end;

function get_query_path_plain_text(const encoded_path: string): string;
begin
    Result := StringReplace(encoded_path, c_segment_path_separator, '',
        [rfReplaceAll]);
end;

function transition_completion_boundary_valid(const parser: TncPinyinParser;
    const typed_prefix: string; const full_pinyin: string): Boolean;
var
    prefix_parts: TncPinyinParseResult;
    full_parts: TncPinyinParseResult;
    index: Integer;
    rebuilt_prefix: string;
    rebuilt_full: string;
begin
    Result := False;
    if parser = nil then
    begin
        Exit;
    end;
    prefix_parts := parser.parse(typed_prefix);
    full_parts := parser.parse(full_pinyin);
    if (Length(prefix_parts) < 2) or
        (Length(full_parts) <= Length(prefix_parts)) or
        (Length(full_parts) - Length(prefix_parts) > 3) then
    begin
        Exit;
    end;
    rebuilt_prefix := '';
    for index := 0 to High(prefix_parts) do
    begin
        rebuilt_prefix := rebuilt_prefix + prefix_parts[index].text;
        if not SameText(prefix_parts[index].text, full_parts[index].text) then
        begin
            Exit;
        end;
    end;
    rebuilt_full := '';
    for index := 0 to High(full_parts) do
    begin
        rebuilt_full := rebuilt_full + full_parts[index].text;
    end;
    Result := SameText(rebuilt_prefix, typed_prefix) and
        SameText(rebuilt_full, normalize_compact_pinyin_key(full_pinyin));
end;

function parse_import_mode(const value: string; const import_path: string): TncImportMode;
var
    normalized: string;
begin
    normalized := LowerCase(Trim(value));
    if normalized = '' then
    begin
        normalized := LowerCase(ExtractFileName(import_path));
        if Pos('query_path', normalized) > 0 then
        begin
            Exit(imQueryPathPrior);
        end;
        if Pos('lm_transition', normalized) > 0 then
        begin
            Exit(imLmTransition);
        end;
        if Pos('transition_completion', normalized) > 0 then
        begin
            Exit(imTransitionCompletion);
        end;
        if Pos('long_completion', normalized) > 0 then
        begin
            Exit(imLongCompletion);
        end;
        if Pos('completion_prior', normalized) > 0 then
        begin
            Exit(imCompletionPrior);
        end;
        if Pos('completion_lookup', normalized) > 0 then
        begin
            Exit(imCompletionLookup);
        end;
        if Pos('completion_competition', normalized) > 0 then
        begin
            Exit(imCompletionCompetition);
        end;
        if Pos('completion_pair_audit', normalized) > 0 then
        begin
            Exit(imCompletionPairAudit);
        end;
        if Pos('short_promotion', normalized) > 0 then
        begin
            Exit(imShortPromotion);
        end;
        if Pos('char_reverse_lm', normalized) > 0 then
        begin
            Exit(imCharReverseLm);
        end;
        if Pos('char_lm', normalized) > 0 then
        begin
            Exit(imCharLm);
        end;
        Exit(imBaseDict);
    end;

    if (normalized = 'query_path') or (normalized = 'query-path') or
        (normalized = 'path') or (normalized = 'querypath') then
    begin
        Exit(imQueryPathPrior);
    end;

    if (normalized = 'lm_transition') or (normalized = 'lm-transition') or
        (normalized = 'lm') or (normalized = 'transition') then
    begin
        Exit(imLmTransition);
    end;

    if (normalized = 'transition_completion') or
        (normalized = 'transition-completion') or
        (normalized = 'completion') then
    begin
        Exit(imTransitionCompletion);
    end;

    if (normalized = 'long_completion') or
        (normalized = 'long-completion') then
    begin
        Exit(imLongCompletion);
    end;

    if (normalized = 'completion_prior') or
        (normalized = 'completion-prior') or
        (normalized = 'popularity_prior') then
    begin
        Exit(imCompletionPrior);
    end;

    if (normalized = 'completion_lookup') or
        (normalized = 'completion-lookup') then
    begin
        Exit(imCompletionLookup);
    end;

    if (normalized = 'completion_competition') or
        (normalized = 'completion-competition') then
    begin
        Exit(imCompletionCompetition);
    end;

    if (normalized = 'completion_pair_audit') or
        (normalized = 'completion-pair-audit') then
    begin
        Exit(imCompletionPairAudit);
    end;

    if (normalized = 'short_promotion') or
        (normalized = 'short-promotion') then
    begin
        Exit(imShortPromotion);
    end;

    if (normalized = 'char_lm') or (normalized = 'char-lm') or
        (normalized = 'character_lm') or (normalized = 'character-lm') then
    begin
        Exit(imCharLm);
    end;

    if (normalized = 'char_reverse_lm') or
        (normalized = 'char-reverse-lm') or
        (normalized = 'character_reverse_lm') or
        (normalized = 'character-reverse-lm') then
    begin
        Exit(imCharReverseLm);
    end;

    Result := imBaseDict;
end;

function is_ascii_lower_text(const value: string): Boolean;
var
    i: Integer;
    ch: Char;
begin
    Result := value <> '';
    if not Result then
    begin
        Exit;
    end;

    for i := 1 to Length(value) do
    begin
        ch := value[i];
        if (ch < 'a') or (ch > 'z') then
        begin
            Result := False;
            Exit;
        end;
    end;
end;

function is_valid_parsed_syllable(const syllable: string): Boolean;
begin
    if not is_ascii_lower_text(syllable) then
    begin
        Result := False;
        Exit;
    end;

    if Length(syllable) = 1 then
    begin
        Result := (syllable = 'a') or (syllable = 'e') or (syllable = 'o');
        Exit;
    end;

    Result := True;
end;

function build_jianpin_variants(const pinyin: string; out variants: TArray<string>): Boolean;
const
    c_jianpin_variant_limit = 64;
type
    TncJianpinPart = record
        short_key: string;
        full_key: string;
    end;
var
    parser: TncPinyinParser;
    parsed: TncPinyinParseResult;
    normalized: string;
    parts: TArray<TncJianpinPart>;
    variant_list: TList<string>;
    dedup: TDictionary<string, Boolean>;
    i: Integer;
    syllable: string;
    part: TncJianpinPart;

    procedure append_unique_variant(const value: string);
    begin
        if (value = '') or dedup.ContainsKey(value) then
        begin
            Exit;
        end;

        dedup.Add(value, True);
        variant_list.Add(value);
    end;

    procedure expand_variants(const index: Integer; const prefix: string);
    begin
        if variant_list.Count >= c_jianpin_variant_limit then
        begin
            Exit;
        end;

        if index >= Length(parts) then
        begin
            append_unique_variant(prefix);
            Exit;
        end;

        expand_variants(index + 1, prefix + parts[index].short_key);
        if (parts[index].full_key <> parts[index].short_key) and
            (variant_list.Count < c_jianpin_variant_limit) then
        begin
            expand_variants(index + 1, prefix + parts[index].full_key);
        end;
    end;
begin
    SetLength(variants, 0);
    normalized := normalize_pinyin_key(pinyin);
    if normalized = '' then
    begin
        Result := False;
        Exit;
    end;

    parser := TncPinyinParser.Create;
    try
        parsed := parser.parse(normalized);
    finally
        parser.Free;
    end;

    if Length(parsed) < 2 then
    begin
        Result := False;
        Exit;
    end;

    SetLength(parts, Length(parsed));
    for i := 0 to High(parsed) do
    begin
        syllable := parsed[i].text;
        if not is_valid_parsed_syllable(syllable) then
        begin
            Result := False;
            Exit;
        end;

        part.short_key := Copy(syllable, 1, 1);
        part.full_key := part.short_key;
        if syllable.StartsWith('zh') then
        begin
            part.full_key := 'zh';
        end
        else if syllable.StartsWith('ch') then
        begin
            part.full_key := 'ch';
        end
        else if syllable.StartsWith('sh') then
        begin
            part.full_key := 'sh';
        end;
        parts[i] := part;
    end;

    variant_list := TList<string>.Create;
    dedup := TDictionary<string, Boolean>.Create;
    try
        expand_variants(0, '');
        if variant_list.Count <= 0 then
        begin
            Result := False;
            Exit;
        end;

        SetLength(variants, variant_list.Count);
        for i := 0 to variant_list.Count - 1 do
        begin
            variants[i] := variant_list[i];
        end;
    finally
        variant_list.Free;
        dedup.Free;
    end;

    Result := Length(variants) > 0;
end;

function import_data(const conn: TncSqliteConnection; const import_path: string;
    const import_mode: TncImportMode): Boolean;
const
    insert_base_sql =
        'INSERT INTO dict_base(pinyin, text, weight, contains_popularity_eligible) ' +
        'VALUES (?1, ?2, ?3, ?4);';
    insert_jianpin_sql = 'INSERT OR IGNORE INTO dict_jianpin(word_id, jianpin, weight) VALUES (?1, ?2, ?3);';
    insert_alias_sql =
        'INSERT OR IGNORE INTO dict_base_pinyin_alias(compact_pinyin, word_id) VALUES (?1, ?2);';
    select_last_rowid_sql = 'SELECT last_insert_rowid()';
    insert_query_path_sql =
        'INSERT OR REPLACE INTO dict_base_query_path(query_pinyin, path_text, weight) VALUES (?1, ?2, ?3);';
    insert_lm_transition_sql =
        'INSERT OR REPLACE INTO dict_base_lm_transition(query_pinyin, path_text, weight) VALUES (?1, ?2, ?3);';
    insert_transition_completion_sql =
        'INSERT OR REPLACE INTO dict_base_transition_completion' +
        '(typed_prefix, full_pinyin, text, path_text, evidence) ' +
        'VALUES (?1, ?2, ?3, ?4, ?5);';
    insert_long_completion_sql =
        'INSERT OR REPLACE INTO dict_base_long_completion' +
        '(anchor_path, suffix_pinyin, suffix_text, suffix_path, evidence, ' +
        'source_count) VALUES (?1, ?2, ?3, ?4, ?5, ?6);';
    insert_long_completion_text_sql =
        'INSERT OR REPLACE INTO dict_base_long_completion_text' +
        '(anchor_text, anchor_path, suffix_pinyin, suffix_text, suffix_path, ' +
        'evidence, source_count) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7);';
    insert_completion_prior_sql =
        'INSERT OR REPLACE INTO dict_base_completion_prior' +
        '(pinyin, text, popularity_prior, corpus_score, document_score, ' +
        'source_count, vertical_penalty, layer_kind, path_score) ' +
        'VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9);';
    insert_completion_lookup_sql =
        'INSERT OR REPLACE INTO dict_base_completion_lookup' +
        '(typed_prefix, full_pinyin, text, weight, popularity_prior, ' +
        'corpus_score, document_score, source_count, path_score, ' +
        'vertical_penalty, layer_kind, prefix_anchored, rank_order) ' +
        'VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13);';
    insert_completion_competition_sql =
        'INSERT OR REPLACE INTO dict_base_completion_competition' +
        '(context_width, context_suffix, typed_prefix, full_pinyin, text, ' +
        'evidence_score, occurrence_count, source_count) ' +
        'VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8);';
    insert_completion_pair_audit_sql =
        'INSERT OR REPLACE INTO dict_base_completion_pair_audit' +
        '(context_width, context_suffix, typed_prefix, ' +
        'baseline_full_pinyin, baseline_text, challenger_full_pinyin, ' +
        'challenger_text, decision, keep_count, switch_count, ' +
        'keep_source_count, switch_source_count, confidence_milli) ' +
        'VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13);';
    insert_short_promotion_sql =
        'INSERT OR REPLACE INTO dict_base_short_promotion' +
        '(pinyin, baseline_text, promoted_text, lead, candidates) ' +
        'VALUES (?1, ?2, ?3, ?4, ?5);';
    insert_char_lm_sql =
        'INSERT OR REPLACE INTO dict_base_char_lm(ngram, score, backoff) VALUES (?1, ?2, ?3);';
    insert_char_reverse_lm_sql =
        'INSERT OR REPLACE INTO dict_base_char_reverse_lm(ngram, score, backoff) VALUES (?1, ?2, ?3);';
var
    reader: TStreamReader;
    stmt_base: Psqlite3_stmt;
    stmt_jianpin: Psqlite3_stmt;
    stmt_alias: Psqlite3_stmt;
    stmt_last_rowid: Psqlite3_stmt;
    stmt_query_path: Psqlite3_stmt;
    stmt_long_completion_text: Psqlite3_stmt;
    line: string;
    pinyin: string;
    full_pinyin: string;
    baseline_full_pinyin: string;
    baseline_text: string;
    challenger_full_pinyin: string;
    challenger_text: string;
    text: string;
    path_text: string;
    context_suffix: string;
    anchor_path: string;
    anchor_text: string;
    suffix_pinyin: string;
    suffix_text: string;
    suffix_path: string;
    weight: Integer;
    contains_popularity_eligible: Integer;
    backoff: Integer;
    corpus_score: Integer;
    document_score: Integer;
    source_count: Integer;
    long_completion_visible: Boolean;
    vertical_penalty: Integer;
    layer_kind: Integer;
    path_score: Integer;
    popularity_prior: Integer;
    prefix_anchored: Integer;
    rank_order: Integer;
    context_width: Integer;
    occurrence_count: Integer;
    pair_decision: Integer;
    keep_count: Integer;
    switch_count: Integer;
    keep_source_count: Integer;
    switch_source_count: Integer;
    confidence_milli: Integer;
    word_id: Integer;
    rc: Integer;
    has_error: Boolean;
    line_count: Integer;
    inserted: Integer;
    inserted_jianpin: Integer;
    inserted_aliases: Integer;
    inserted_query_paths: Integer;
    inserted_char_lm: Integer;
    inserted_transition_completions: Integer;
    inserted_long_completions: Integer;
    inserted_long_completion_recall: Integer;
    inserted_completion_priors: Integer;
    inserted_completion_lookups: Integer;
    inserted_completion_competitions: Integer;
    inserted_completion_pair_audits: Integer;
    inserted_short_promotions: Integer;
    promotion_parts: TArray<string>;
    completion_parser: TncPinyinParser;
    jianpin_variants: TArray<string>;
    jianpin_value: string;
    compact_pinyin: string;
    compact_full_pinyin: string;
begin
    Result := False;
    if not FileExists(import_path) then
    begin
        Exit;
    end;

    if not conn.exec('BEGIN IMMEDIATE;') then
    begin
        Exit;
    end;

    reader := TStreamReader.Create(import_path, TEncoding.UTF8);
    stmt_base := nil;
    stmt_jianpin := nil;
    stmt_alias := nil;
    stmt_last_rowid := nil;
    stmt_query_path := nil;
    stmt_long_completion_text := nil;
    completion_parser := nil;
    has_error := False;
    line_count := 0;
    inserted := 0;
    inserted_jianpin := 0;
    inserted_aliases := 0;
    inserted_query_paths := 0;
    inserted_char_lm := 0;
    inserted_transition_completions := 0;
    inserted_long_completions := 0;
    inserted_long_completion_recall := 0;
    inserted_completion_priors := 0;
    inserted_completion_lookups := 0;
    inserted_completion_competitions := 0;
    inserted_completion_pair_audits := 0;
    inserted_short_promotions := 0;
    try
        if import_mode = imQueryPathPrior then
        begin
            if not conn.prepare(insert_query_path_sql, stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imLmTransition then
        begin
            if not conn.prepare(insert_lm_transition_sql, stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imCharLm then
        begin
            if not conn.prepare(insert_char_lm_sql, stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imCharReverseLm then
        begin
            if not conn.prepare(insert_char_reverse_lm_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imTransitionCompletion then
        begin
            completion_parser := TncPinyinParser.Create;
            // This generated table is rebuilt atomically. Recreating it also
            // migrates databases whose legacy schema allowed one row per
            // prefix to the Top-K composite key.
            if (not conn.exec('DROP TABLE IF EXISTS dict_base_transition_completion;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_transition_completion (' +
                'typed_prefix TEXT NOT NULL,' +
                'full_pinyin TEXT NOT NULL,' +
                'text TEXT NOT NULL,' +
                'path_text TEXT NOT NULL,' +
                'evidence INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(typed_prefix, full_pinyin, text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_transition_completion_prefix ' +
                'ON dict_base_transition_completion(typed_prefix, evidence DESC);')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_transition_completion_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imLongCompletion then
        begin
            completion_parser := TncPinyinParser.Create;
            if (not conn.exec('DROP TABLE IF EXISTS dict_base_long_completion;')) or
                (not conn.exec('DROP TABLE IF EXISTS dict_base_long_completion_text;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_long_completion (' +
                'anchor_path TEXT NOT NULL,' +
                'suffix_pinyin TEXT NOT NULL,' +
                'suffix_text TEXT NOT NULL,' +
                'suffix_path TEXT NOT NULL,' +
                'evidence INTEGER NOT NULL DEFAULT 0,' +
                'source_count INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(anchor_path, suffix_pinyin, suffix_text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_long_completion_anchor ' +
                'ON dict_base_long_completion(anchor_path, evidence DESC, ' +
                'source_count DESC);')) or
                (not conn.exec(
                'CREATE TABLE dict_base_long_completion_text (' +
                'anchor_text TEXT NOT NULL,' +
                'anchor_path TEXT NOT NULL,' +
                'suffix_pinyin TEXT NOT NULL,' +
                'suffix_text TEXT NOT NULL,' +
                'suffix_path TEXT NOT NULL,' +
                'evidence INTEGER NOT NULL DEFAULT 0,' +
                'source_count INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(anchor_text, anchor_path, suffix_pinyin, suffix_text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_long_completion_text_anchor ' +
                'ON dict_base_long_completion_text(anchor_text, evidence DESC, ' +
                'source_count DESC);')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_long_completion_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_long_completion_text_sql,
                stmt_long_completion_text) then
            begin
                Exit;
            end;
        end
        else if import_mode = imCompletionPrior then
        begin
            if (not conn.exec(
                'DROP TABLE IF EXISTS dict_base_completion_prior;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_completion_prior (' +
                'pinyin TEXT NOT NULL,' +
                'text TEXT NOT NULL,' +
                'popularity_prior INTEGER NOT NULL DEFAULT 0,' +
                'corpus_score INTEGER NOT NULL DEFAULT 0,' +
                'document_score INTEGER NOT NULL DEFAULT 0,' +
                'source_count INTEGER NOT NULL DEFAULT 0,' +
                'path_score INTEGER NOT NULL DEFAULT 0,' +
                'vertical_penalty INTEGER NOT NULL DEFAULT 0,' +
                'layer_kind INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(pinyin, text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_completion_prior_pinyin ' +
                'ON dict_base_completion_prior' +
                '(pinyin, popularity_prior DESC);')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_completion_prior_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imCompletionLookup then
        begin
            if (not conn.exec(
                'DROP TABLE IF EXISTS dict_base_completion_lookup;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_completion_lookup (' +
                'typed_prefix TEXT NOT NULL,' +
                'full_pinyin TEXT NOT NULL,' +
                'text TEXT NOT NULL,' +
                'weight INTEGER NOT NULL DEFAULT 0,' +
                'popularity_prior INTEGER NOT NULL DEFAULT 0,' +
                'corpus_score INTEGER NOT NULL DEFAULT 0,' +
                'document_score INTEGER NOT NULL DEFAULT 0,' +
                'source_count INTEGER NOT NULL DEFAULT 0,' +
                'path_score INTEGER NOT NULL DEFAULT 0,' +
                'vertical_penalty INTEGER NOT NULL DEFAULT 0,' +
                'layer_kind INTEGER NOT NULL DEFAULT 0,' +
                'prefix_anchored INTEGER NOT NULL DEFAULT 0,' +
                'rank_order INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(typed_prefix, full_pinyin, text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_completion_lookup_prefix ' +
                'ON dict_base_completion_lookup' +
                '(typed_prefix, rank_order);')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_completion_lookup_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imCompletionCompetition then
        begin
            if (not conn.exec(
                'DROP TABLE IF EXISTS dict_base_completion_competition;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_completion_competition (' +
                'context_width INTEGER NOT NULL,' +
                'context_suffix TEXT NOT NULL,' +
                'typed_prefix TEXT NOT NULL,' +
                'full_pinyin TEXT NOT NULL,' +
                'text TEXT NOT NULL,' +
                'evidence_score INTEGER NOT NULL DEFAULT 0,' +
                'occurrence_count INTEGER NOT NULL DEFAULT 0,' +
                'source_count INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(context_width, context_suffix, typed_prefix, ' +
                'full_pinyin, text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_completion_competition_query ' +
                'ON dict_base_completion_competition(typed_prefix, ' +
                'context_width, context_suffix, evidence_score DESC);')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_completion_competition_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imCompletionPairAudit then
        begin
            if (not conn.exec(
                'DROP TABLE IF EXISTS dict_base_completion_pair_audit;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_completion_pair_audit (' +
                'context_width INTEGER NOT NULL,' +
                'context_suffix TEXT NOT NULL,' +
                'typed_prefix TEXT NOT NULL,' +
                'baseline_full_pinyin TEXT NOT NULL,' +
                'baseline_text TEXT NOT NULL,' +
                'challenger_full_pinyin TEXT NOT NULL,' +
                'challenger_text TEXT NOT NULL,' +
                'decision INTEGER NOT NULL DEFAULT 0,' +
                'keep_count INTEGER NOT NULL DEFAULT 0,' +
                'switch_count INTEGER NOT NULL DEFAULT 0,' +
                'keep_source_count INTEGER NOT NULL DEFAULT 0,' +
                'switch_source_count INTEGER NOT NULL DEFAULT 0,' +
                'confidence_milli INTEGER NOT NULL DEFAULT 0,' +
                'PRIMARY KEY(context_width, context_suffix, typed_prefix, ' +
                'baseline_full_pinyin, baseline_text, ' +
                'challenger_full_pinyin, challenger_text)' +
                ') WITHOUT ROWID;')) or
                (not conn.exec(
                'CREATE INDEX idx_dict_base_completion_pair_audit_query ' +
                'ON dict_base_completion_pair_audit(typed_prefix, ' +
                'baseline_full_pinyin, baseline_text, ' +
                'challenger_full_pinyin, challenger_text, ' +
                'context_width DESC, context_suffix);')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_completion_pair_audit_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if import_mode = imShortPromotion then
        begin
            if (not conn.exec(
                'DROP TABLE IF EXISTS dict_base_short_promotion;')) or
                (not conn.exec(
                'CREATE TABLE dict_base_short_promotion (' +
                'pinyin TEXT NOT NULL,' +
                'baseline_text TEXT NOT NULL,' +
                'promoted_text TEXT NOT NULL,' +
                'lead INTEGER NOT NULL DEFAULT 0,' +
                'candidates TEXT NOT NULL DEFAULT '''',' +
                'PRIMARY KEY(pinyin, baseline_text)' +
                ') WITHOUT ROWID;')) then
            begin
                Exit;
            end;
            if not conn.prepare(insert_short_promotion_sql,
                stmt_query_path) then
            begin
                Exit;
            end;
        end
        else if not conn.prepare(insert_base_sql, stmt_base) or
            (not conn.prepare(insert_jianpin_sql, stmt_jianpin)) or
            (not conn.prepare(insert_alias_sql, stmt_alias)) or
            (not conn.prepare(select_last_rowid_sql, stmt_last_rowid)) then
        begin
            Exit;
        end;

        while not reader.EndOfStream do
        begin
            line := reader.ReadLine;
            Inc(line_count);
            if not (import_mode in [imCharLm, imCharReverseLm]) then
            begin
                line := Trim(line);
            end;
            if line = '' then
            begin
                Continue;
            end;

            if (not (import_mode in [imCharLm, imCharReverseLm])) and
                (line[1] = '#') then
            begin
                Continue;
            end;

            if import_mode in [imCharLm, imCharReverseLm] then
            begin
                if not split_char_lm_line(line, text, weight, backoff) then
                begin
                    Continue;
                end;
                if (not conn.bind_text(stmt_query_path, 1, text)) or
                    (not conn.bind_int(stmt_query_path, 2, weight)) or
                    (not conn.bind_int(stmt_query_path, 3, backoff)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_char_lm);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imTransitionCompletion then
            begin
                if not split_transition_completion_line(line, pinyin,
                    full_pinyin, text, path_text, weight) then
                begin
                    Continue;
                end;
                pinyin := normalize_compact_pinyin_key(pinyin);
                full_pinyin := normalize_pinyin_key(full_pinyin);
                compact_full_pinyin := normalize_compact_pinyin_key(
                    full_pinyin);
                path_text := normalize_query_path_text(path_text);
                if (pinyin = '') or (full_pinyin = '') or
                    (Length(compact_full_pinyin) <= Length(pinyin)) or
                    (not compact_full_pinyin.StartsWith(pinyin, True)) or
                    (not transition_completion_boundary_valid(
                    completion_parser, pinyin, full_pinyin)) or
                    (text = '') or
                    (get_query_path_segment_count(path_text) <> 2) or
                    (get_query_path_plain_text(path_text) <> text) or
                    (weight <= 0) then
                begin
                    Continue;
                end;
                if (not conn.bind_text(stmt_query_path, 1, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 2, full_pinyin)) or
                    (not conn.bind_text(stmt_query_path, 3, text)) or
                    (not conn.bind_text(stmt_query_path, 4, path_text)) or
                    (not conn.bind_int(stmt_query_path, 5, weight)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_transition_completions);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imLongCompletion then
            begin
                if not split_long_completion_line(line, anchor_path,
                    suffix_pinyin, suffix_text, suffix_path, weight,
                    source_count, long_completion_visible) then
                begin
                    Continue;
                end;
                anchor_path := normalize_query_path_text(anchor_path);
                anchor_text := get_query_path_plain_text(anchor_path);
                suffix_path := normalize_query_path_text(suffix_path);
                suffix_pinyin := normalize_pinyin_key(suffix_pinyin);
                if (anchor_text = '') or
                    (get_query_path_segment_count(anchor_path) < 1) or
                    (get_query_path_segment_count(anchor_path) > 3) or
                    (get_query_path_segment_count(suffix_path) < 1) or
                    (get_query_path_segment_count(suffix_path) > 3) or
                    (get_query_path_plain_text(suffix_path) <> suffix_text) or
                    (Length(completion_parser.parse(suffix_pinyin)) > 6) or
                    (Length(completion_parser.parse(suffix_pinyin)) < 1) or
                    (Length(completion_parser.parse(suffix_pinyin)) <>
                    Length(suffix_text)) then
                begin
                    Continue;
                end;
                if long_completion_visible then
                begin
                    if (not conn.bind_text(stmt_query_path, 1,
                        anchor_path)) or
                        (not conn.bind_text(stmt_query_path, 2,
                        suffix_pinyin)) or
                        (not conn.bind_text(stmt_query_path, 3,
                        suffix_text)) or
                        (not conn.bind_text(stmt_query_path, 4,
                        suffix_path)) or
                        (not conn.bind_int(stmt_query_path, 5, weight)) or
                        (not conn.bind_int(stmt_query_path, 6,
                        source_count)) then
                    begin
                        has_error := True;
                        Break;
                    end;
                    rc := conn.step(stmt_query_path);
                    if rc <> SQLITE_DONE then
                    begin
                        has_error := True;
                        Break;
                    end;
                    Inc(inserted_long_completions);
                    if (not conn.reset(stmt_query_path)) or
                        (not conn.clear_bindings(stmt_query_path)) then
                    begin
                        has_error := True;
                        Break;
                    end;
                end;
                if (not conn.bind_text(stmt_long_completion_text, 1,
                    anchor_text)) or
                    (not conn.bind_text(stmt_long_completion_text, 2,
                    anchor_path)) or
                    (not conn.bind_text(stmt_long_completion_text, 3,
                    suffix_pinyin)) or
                    (not conn.bind_text(stmt_long_completion_text, 4,
                    suffix_text)) or
                    (not conn.bind_text(stmt_long_completion_text, 5,
                    suffix_path)) or
                    (not conn.bind_int(stmt_long_completion_text, 6,
                    weight)) or
                    (not conn.bind_int(stmt_long_completion_text, 7,
                    source_count)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_long_completion_text);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_long_completion_recall);
                if (not conn.reset(stmt_long_completion_text)) or
                    (not conn.clear_bindings(stmt_long_completion_text)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imCompletionPrior then
            begin
                if not split_completion_prior_line(line, pinyin, text,
                    weight, corpus_score, document_score, source_count,
                    vertical_penalty, layer_kind, path_score) then
                begin
                    Continue;
                end;
                pinyin := normalize_pinyin_key(pinyin);
                if (pinyin = '') or (text = '') then
                begin
                    Continue;
                end;
                if (not conn.bind_text(stmt_query_path, 1, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 2, text)) or
                    (not conn.bind_int(stmt_query_path, 3, weight)) or
                    (not conn.bind_int(stmt_query_path, 4, corpus_score)) or
                    (not conn.bind_int(stmt_query_path, 5, document_score)) or
                    (not conn.bind_int(stmt_query_path, 6, source_count)) or
                    (not conn.bind_int(stmt_query_path, 7, vertical_penalty)) or
                    (not conn.bind_int(stmt_query_path, 8, layer_kind)) or
                    (not conn.bind_int(stmt_query_path, 9, path_score)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_completion_priors);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imCompletionLookup then
            begin
                if not split_completion_lookup_line(line, pinyin,
                    full_pinyin, text, weight, popularity_prior,
                    corpus_score, document_score, source_count, path_score,
                    vertical_penalty, layer_kind, prefix_anchored,
                    rank_order) then
                begin
                    Continue;
                end;
                pinyin := normalize_compact_pinyin_key(pinyin);
                full_pinyin := normalize_pinyin_key(full_pinyin);
                compact_full_pinyin := normalize_compact_pinyin_key(
                    full_pinyin);
                if (pinyin = '') or (full_pinyin = '') or (text = '') or
                    (Length(compact_full_pinyin) <= Length(pinyin)) or
                    (not compact_full_pinyin.StartsWith(pinyin, True)) then
                begin
                    Continue;
                end;
                if (not conn.bind_text(stmt_query_path, 1, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 2, full_pinyin)) or
                    (not conn.bind_text(stmt_query_path, 3, text)) or
                    (not conn.bind_int(stmt_query_path, 4, weight)) or
                    (not conn.bind_int(stmt_query_path, 5,
                    popularity_prior)) or
                    (not conn.bind_int(stmt_query_path, 6, corpus_score)) or
                    (not conn.bind_int(stmt_query_path, 7, document_score)) or
                    (not conn.bind_int(stmt_query_path, 8, source_count)) or
                    (not conn.bind_int(stmt_query_path, 9, path_score)) or
                    (not conn.bind_int(stmt_query_path, 10,
                    vertical_penalty)) or
                    (not conn.bind_int(stmt_query_path, 11, layer_kind)) or
                    (not conn.bind_int(stmt_query_path, 12,
                    prefix_anchored)) or
                    (not conn.bind_int(stmt_query_path, 13, rank_order)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_completion_lookups);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imCompletionCompetition then
            begin
                if not split_completion_competition_line(line, context_width,
                    context_suffix, pinyin, full_pinyin, text, weight,
                    occurrence_count, source_count) then
                begin
                    Continue;
                end;
                pinyin := normalize_compact_pinyin_key(pinyin);
                full_pinyin := normalize_pinyin_key(full_pinyin);
                compact_full_pinyin := normalize_compact_pinyin_key(
                    full_pinyin);
                if (pinyin = '') or (full_pinyin = '') or (text = '') or
                    (Length(compact_full_pinyin) <= Length(pinyin)) or
                    (not compact_full_pinyin.StartsWith(pinyin, True)) then
                begin
                    Continue;
                end;
                if (not conn.bind_int(stmt_query_path, 1, context_width)) or
                    (not conn.bind_text(stmt_query_path, 2,
                    context_suffix)) or
                    (not conn.bind_text(stmt_query_path, 3, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 4, full_pinyin)) or
                    (not conn.bind_text(stmt_query_path, 5, text)) or
                    (not conn.bind_int(stmt_query_path, 6, weight)) or
                    (not conn.bind_int(stmt_query_path, 7,
                    occurrence_count)) or
                    (not conn.bind_int(stmt_query_path, 8,
                    source_count)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_completion_competitions);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imShortPromotion then
            begin
                // The key is the engine's own normalized query, kept as written;
                // the last field names the words and weights of the choice.
                promotion_parts := line.Split([#9]);
                if Length(promotion_parts) <> 5 then
                begin
                    Continue;
                end;
                pinyin := LowerCase(Trim(promotion_parts[0]));
                baseline_text := Trim(promotion_parts[1]);
                challenger_text := Trim(promotion_parts[2]);
                if (pinyin = '') or (baseline_text = '') or
                    (challenger_text = '') or
                    (baseline_text = challenger_text) or
                    (Trim(promotion_parts[4]) = '') then
                begin
                    Continue;
                end;
                if (not conn.bind_text(stmt_query_path, 1, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 2, baseline_text)) or
                    (not conn.bind_text(stmt_query_path, 3,
                    challenger_text)) or
                    (not conn.bind_int(stmt_query_path, 4,
                    StrToIntDef(Trim(promotion_parts[3]), 0))) or
                    (not conn.bind_text(stmt_query_path, 5,
                    Trim(promotion_parts[4]))) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_short_promotions);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode = imCompletionPairAudit then
            begin
                if not split_completion_pair_audit_line(line, context_width,
                    context_suffix, pinyin, baseline_full_pinyin,
                    baseline_text, challenger_full_pinyin, challenger_text,
                    pair_decision, keep_count, switch_count,
                    keep_source_count, switch_source_count,
                    confidence_milli) then
                begin
                    Continue;
                end;
                pinyin := normalize_compact_pinyin_key(pinyin);
                baseline_full_pinyin := normalize_compact_pinyin_key(
                    baseline_full_pinyin);
                challenger_full_pinyin := normalize_compact_pinyin_key(
                    challenger_full_pinyin);
                if (pinyin = '') or (baseline_full_pinyin = '') or
                    (challenger_full_pinyin = '') or
                    (not baseline_full_pinyin.StartsWith(pinyin, True)) or
                    (not challenger_full_pinyin.StartsWith(pinyin, True)) or
                    (Length(baseline_full_pinyin) <= Length(pinyin)) or
                    (Length(challenger_full_pinyin) <= Length(pinyin)) then
                begin
                    Continue;
                end;
                if (not conn.bind_int(stmt_query_path, 1,
                    context_width)) or
                    (not conn.bind_text(stmt_query_path, 2,
                    context_suffix)) or
                    (not conn.bind_text(stmt_query_path, 3, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 4,
                    baseline_full_pinyin)) or
                    (not conn.bind_text(stmt_query_path, 5,
                    baseline_text)) or
                    (not conn.bind_text(stmt_query_path, 6,
                    challenger_full_pinyin)) or
                    (not conn.bind_text(stmt_query_path, 7,
                    challenger_text)) or
                    (not conn.bind_int(stmt_query_path, 8,
                    pair_decision)) or
                    (not conn.bind_int(stmt_query_path, 9, keep_count)) or
                    (not conn.bind_int(stmt_query_path, 10,
                    switch_count)) or
                    (not conn.bind_int(stmt_query_path, 11,
                    keep_source_count)) or
                    (not conn.bind_int(stmt_query_path, 12,
                    switch_source_count)) or
                    (not conn.bind_int(stmt_query_path, 13,
                    confidence_milli)) then
                begin
                    has_error := True;
                    Break;
                end;
                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;
                Inc(inserted_completion_pair_audits);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if import_mode in [imQueryPathPrior, imLmTransition] then
            begin
                if not split_query_path_line(line, pinyin, text, weight) then
                begin
                    Continue;
                end;

                pinyin := normalize_compact_pinyin_key(pinyin);
                text := normalize_query_path_text(text);
                if (pinyin = '') or (text = '') or
                    (get_query_path_segment_count(text) <= 1) or (weight <= 0) then
                begin
                    Continue;
                end;

                if (not conn.bind_text(stmt_query_path, 1, pinyin)) or
                    (not conn.bind_text(stmt_query_path, 2, text)) or
                    (not conn.bind_int(stmt_query_path, 3, weight)) then
                begin
                    has_error := True;
                    Break;
                end;

                rc := conn.step(stmt_query_path);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;

                Inc(inserted_query_paths);
                if (not conn.reset(stmt_query_path)) or
                    (not conn.clear_bindings(stmt_query_path)) then
                begin
                    has_error := True;
                    Break;
                end;
                Continue;
            end;

            if not split_line(line, pinyin, text, weight,
                contains_popularity_eligible) then
            begin
                Continue;
            end;

            pinyin := normalize_pinyin_key(pinyin);
            if pinyin = '' then
            begin
                Continue;
            end;

            if not conn.bind_text(stmt_base, 1, pinyin) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_text(stmt_base, 2, text) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_int(stmt_base, 3, weight) then
            begin
                has_error := True;
                Break;
            end;

            if not conn.bind_int(stmt_base, 4,
                contains_popularity_eligible) then
            begin
                has_error := True;
                Break;
            end;

            rc := conn.step(stmt_base);
            if rc <> SQLITE_DONE then
            begin
                has_error := True;
                Break;
            end;

            if (not conn.reset(stmt_base)) or (not conn.clear_bindings(stmt_base)) then
            begin
                has_error := True;
                Break;
            end;

            rc := conn.step(stmt_last_rowid);
            if rc <> SQLITE_ROW then
            begin
                has_error := True;
                Break;
            end;
            word_id := conn.column_int(stmt_last_rowid, 0);
            if (not conn.reset(stmt_last_rowid)) or (not conn.clear_bindings(stmt_last_rowid)) then
            begin
                has_error := True;
                Break;
            end;
            if word_id <= 0 then
            begin
                has_error := True;
                Break;
            end;

            compact_pinyin := normalize_compact_pinyin_key(pinyin);
            if (compact_pinyin <> '') and (compact_pinyin <> pinyin) then
            begin
                if (not conn.bind_text(stmt_alias, 1, compact_pinyin)) or
                    (not conn.bind_int(stmt_alias, 2, word_id)) then
                begin
                    has_error := True;
                    Break;
                end;

                rc := conn.step(stmt_alias);
                if rc <> SQLITE_DONE then
                begin
                    has_error := True;
                    Break;
                end;

                Inc(inserted_aliases);
                if (not conn.reset(stmt_alias)) or (not conn.clear_bindings(stmt_alias)) then
                begin
                    has_error := True;
                    Break;
                end;
            end;

            if build_jianpin_variants(pinyin, jianpin_variants) then
            begin
                for jianpin_value in jianpin_variants do
                begin
                    if (not conn.bind_int(stmt_jianpin, 1, word_id)) or
                        (not conn.bind_text(stmt_jianpin, 2, jianpin_value)) or
                        (not conn.bind_int(stmt_jianpin, 3, weight)) then
                    begin
                        has_error := True;
                        Break;
                    end;

                    rc := conn.step(stmt_jianpin);
                    if rc <> SQLITE_DONE then
                    begin
                        has_error := True;
                        Break;
                    end;

                    Inc(inserted_jianpin);
                    if (not conn.reset(stmt_jianpin)) or (not conn.clear_bindings(stmt_jianpin)) then
                    begin
                        has_error := True;
                        Break;
                    end;
                end;
            end;
            if has_error then
            begin
                Break;
            end;

            Inc(inserted);
        end;
    finally
        if stmt_base <> nil then
        begin
            conn.finalize(stmt_base);
        end;
        if stmt_jianpin <> nil then
        begin
            conn.finalize(stmt_jianpin);
        end;
        if stmt_alias <> nil then
        begin
            conn.finalize(stmt_alias);
        end;
        if stmt_last_rowid <> nil then
        begin
            conn.finalize(stmt_last_rowid);
        end;
        if stmt_query_path <> nil then
        begin
            conn.finalize(stmt_query_path);
        end;
        if stmt_long_completion_text <> nil then
        begin
            conn.finalize(stmt_long_completion_text);
        end;
        completion_parser.Free;
        reader.Free;
    end;

    if has_error then
    begin
        conn.exec('ROLLBACK;');
        Exit(False);
    end;

    if conn.exec('COMMIT;') then
    begin
        if import_mode = imQueryPathPrior then
        begin
            Writeln(Format('Imported %d query-path prior rows from %d lines.',
                [inserted_query_paths, line_count]));
        end
        else if import_mode = imLmTransition then
        begin
            Writeln(Format('Imported %d LM transition rows from %d lines.',
                [inserted_query_paths, line_count]));
        end
        else if import_mode = imCharLm then
        begin
            Writeln(Format('Imported %d character LM rows from %d lines.',
                [inserted_char_lm, line_count]));
        end
        else if import_mode = imCharReverseLm then
        begin
            Writeln(Format(
                'Imported %d reverse character LM rows from %d lines.',
                [inserted_char_lm, line_count]));
        end
        else if import_mode = imTransitionCompletion then
        begin
            Writeln(Format(
                'Imported %d transition completion rows from %d lines.',
                [inserted_transition_completions, line_count]));
        end
        else if import_mode = imLongCompletion then
        begin
            Writeln(Format(
                'Imported %d visible and %d recall-only long completion ' +
                'rows from %d lines.',
                [inserted_long_completions,
                inserted_long_completion_recall - inserted_long_completions,
                line_count]));
        end
        else if import_mode = imCompletionPrior then
        begin
            Writeln(Format(
                'Imported %d completion popularity priors from %d lines.',
                [inserted_completion_priors, line_count]));
        end
        else if import_mode = imCompletionLookup then
        begin
            Writeln(Format(
                'Imported %d exact completion lookup rows from %d lines.',
                [inserted_completion_lookups, line_count]));
        end
        else if import_mode = imCompletionCompetition then
        begin
            Writeln(Format(
                'Imported %d completion competition rows from %d lines.',
                [inserted_completion_competitions, line_count]));
        end
        else if import_mode = imCompletionPairAudit then
        begin
            Writeln(Format(
                'Imported %d completion pair audit rows from %d lines.',
                [inserted_completion_pair_audits, line_count]));
        end
        else if import_mode = imShortPromotion then
        begin
            Writeln(Format(
                'Imported %d short promotion rows from %d lines.',
                [inserted_short_promotions, line_count]));
        end
        else
        begin
            Writeln(Format('Imported %d entries (%d jianpin rows, %d compact aliases) from %d lines.',
                [inserted, inserted_jianpin, inserted_aliases, line_count]));
        end;
        Result := True;
    end
    else
    begin
        conn.exec('ROLLBACK;');
    end;
end;

function rebuild_contains_popularity_index(
    const conn: TncSqliteConnection): Boolean;
const
    rebuild_sql =
        'PRAGMA temp_store=MEMORY;' +
        'DROP TABLE IF EXISTS dict_base_contains_popularity;' +
        'CREATE TABLE dict_base_contains_popularity(' +
        'token TEXT PRIMARY KEY, weight INTEGER NOT NULL) WITHOUT ROWID;' +
        'WITH RECURSIVE nums(n) AS (' +
        'VALUES(1) UNION ALL SELECT n + 1 FROM nums ' +
        'WHERE n < (SELECT COALESCE(MAX(length(text)), 1) FROM dict_base)' +
        '), spans AS (' +
        'SELECT DISTINCT b.id AS id, substr(b.text, pos.n, len.n) AS token, ' +
        'b.weight AS weight FROM dict_base b, nums pos, nums len ' +
        'WHERE b.contains_popularity_eligible <> 0 ' +
        'AND len.n BETWEEN 2 AND 6 ' +
        'AND pos.n + len.n - 1 <= length(b.text)' +
        ') INSERT INTO dict_base_contains_popularity(token, weight) ' +
        'SELECT token, SUM(weight) FROM spans GROUP BY token;' +
        'ANALYZE dict_base_contains_popularity;' +
        'VACUUM;';
begin
    Writeln('Building text-contains popularity index...');
    Result := conn.exec(rebuild_sql);
    if Result then
    begin
        Writeln('Text-contains popularity index built.');
    end;
end;

var
    db_path: string;
    schema_path: string;
    import_path: string;
    import_mode: TncImportMode;
    build_contains_index: Boolean;
    schema_text: string;
    conn: TncSqliteConnection;
begin
    if ParamCount < 2 then
    begin
        print_usage;
        Halt(1);
    end;

    db_path := ParamStr(1);
    schema_path := ParamStr(2);
    if (ParamCount >= 3) and
        SameText(Trim(ParamStr(3)), '--require-short-promotion') then
    begin
        Halt(require_short_promotion(db_path));
    end;
    build_contains_index := (ParamCount >= 3) and
        SameText(Trim(ParamStr(3)), '--build-contains-index');
    if build_contains_index then
    begin
        import_path := '';
    end
    else if ParamCount >= 3 then
    begin
        import_path := ParamStr(3);
    end
    else
    begin
        import_path := '';
    end;
    if ParamCount >= 4 then
    begin
        import_mode := parse_import_mode(ParamStr(4), import_path);
    end
    else
    begin
        import_mode := parse_import_mode('', import_path);
    end;

    if not load_schema(schema_path, schema_text) then
    begin
        Writeln('Schema not found or empty.');
        Halt(1);
    end;

    conn := TncSqliteConnection.Create(db_path);
    try
        if not conn.open then
        begin
            Writeln('Open db failed.');
            Halt(1);
        end;

        if not conn.exec(schema_text) then
        begin
            Writeln('Apply schema failed: ' + conn.errmsg);
            Halt(1);
        end;

        if not ensure_base_scope_schema(conn) then
        begin
            Writeln('Migrate base dictionary schema failed: ' + conn.errmsg);
            Halt(1);
        end;

        if import_path <> '' then
        begin
            if not import_data(conn, import_path, import_mode) then
            begin
                Writeln('Import failed: ' + conn.errmsg);
                Halt(1);
            end;
        end;
        if build_contains_index and
            (not rebuild_contains_popularity_index(conn)) then
        begin
            Writeln('Build text-contains popularity index failed: ' + conn.errmsg);
            Halt(1);
        end;
    finally
        conn.Free;
    end;
end.
