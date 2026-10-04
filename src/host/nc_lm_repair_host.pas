unit nc_lm_repair_host;

{ Long-sentence repair with the pinyin-conditioned character LM (model
  consolidation, steps 3 and 4). The shared LM in <runtime>\char_lm is also
  trained to rewrite engine drafts: given the typed syllables and the draft it
  returns a corrected text (nc_lm_correct in the ORT bridge DLL). Both hosts
  open the same model file, so the bridge keeps one session for them. It took
  over from the local repair encoders and the pinyin parallel generator.

  Pinyin tokens are private-use characters listed in pinyin_readings.json with
  each character's readings and each syllable's homophones. }

interface

uses
    Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs,
    System.Generics.Collections, nc_engine_intf;

type
    TncLmRepairHost = class(TInterfacedObject, IncLongLocalRepair)
    private type
        TCreateModel = function(directory: PWideChar; intra_threads: Integer;
            error_text: PWideChar; capacity: Integer): Pointer; cdecl;
        TCorrect = function(handle: Pointer; context, draft: PWideChar;
            allowed_code_points: PCardinal; allowed_offsets: PInteger; width: Integer;
            out_text: PWideChar; out_capacity: Integer; out_gain: PSingle;
            timeout_ms: Integer; error_text: PWideChar; capacity: Integer): Integer; cdecl;
        TDestroyModel = procedure(handle: Pointer); cdecl;
    private
        m_directory, m_error: string;
        m_module, m_ort, m_provider: HMODULE;
        m_handle: Pointer;
        m_correct: TCorrect;
        m_destroy: TDestroyModel;
        m_readings: TDictionary<string, TArray<string>>;
        m_homophones: TDictionary<string, TArray<Cardinal>>;
        m_syllable_index: TDictionary<string, Integer>;
        m_syllable_base, m_sep, m_draft: Cardinal;
        // Characters of preceding text the model was trained to read (0: none).
        m_context_chars: Integer;
        m_ready: Boolean;
        m_loaded: TEvent;
        m_loader: TThread;
        // One correction at a time: the native handle rejects concurrent calls.
        m_run_lock: TCriticalSection;
        procedure load;
        function align(const query_text, draft_text: string;
            out syllables: TArray<string>): Boolean;
    public
        { background_load loads on a lower-priority thread so the dictionary
          starts first; repairs are skipped until the model is ready. }
        constructor Create(const base_directory: string; const background_load: Boolean = True);
        destructor Destroy; override;
        function ready: Boolean;
        function wait_until_ready(const timeout_ms: Cardinal): Boolean;
        function last_error: string;
        procedure set_document_context(const document_key, preceding_text: string);
        { The corrected draft when the model prefers another text by at least
          c_lm_repair_min_gain; aligned_pinyin is set whenever the draft aligns.
          preceding_text is the text before the input; a model whose manifest
          sets correction_context_chars reads the end of its last paragraph. }
        function try_repair(const query_text, draft_text: string;
            const document_key, preceding_text: string;
            out repaired_text, aligned_pinyin: string;
            out minimum_word_ratio: Double): Boolean;
    end;

implementation

uses System.IOUtils, System.JSON, System.Character, System.Hash, nc_log, nc_char_lm_host;

const
    // Beam width and the whole-sentence log-probability margin over the draft,
    // chosen on the 8,000-sentence fiction long dev set.
    c_lm_repair_width = 2;
    c_lm_repair_min_gain = 1.0;
    // The dictionary path check accepts any segmentation, as for local repair.
    c_lm_repair_word_ratio = 0.01;

constructor TncLmRepairHost.Create(const base_directory: string; const background_load: Boolean);
begin
    inherited Create;
    m_directory := ExcludeTrailingPathDelimiter(ExpandFileName(base_directory));
    m_readings := TDictionary<string, TArray<string>>.Create;
    m_homophones := TDictionary<string, TArray<Cardinal>>.Create;
    m_syllable_index := TDictionary<string, Integer>.Create;
    m_loaded := TEvent.Create(nil, True, False, '');
    m_run_lock := TCriticalSection.Create;
    if background_load then
    begin
        m_loader := TThread.CreateAnonymousThread(load);
        m_loader.FreeOnTerminate := False;
        m_loader.Priority := tpLower;
        m_loader.Start;
    end
    else
        load;
end;

destructor TncLmRepairHost.Destroy;
begin
    if m_loader <> nil then
    begin
        m_loader.WaitFor;
        m_loader.Free;
    end;
    if Assigned(m_destroy) and (m_handle <> nil) then m_destroy(m_handle);
    if m_module <> 0 then FreeLibrary(m_module);
    if m_ort <> 0 then FreeLibrary(m_ort);
    if m_provider <> 0 then FreeLibrary(m_provider);
    m_readings.Free;
    m_homophones.Free;
    m_syllable_index.Free;
    m_loaded.Free;
    m_run_lock.Free;
    inherited;
end;

procedure TncLmRepairHost.load;
const
    required_files: array[0..2] of string = ('char_lm.onnx', 'char_lm_vocab.bin',
        'pinyin_readings.json');
var
    root, manifest_root, value: TJSONValue;
    table, readings, homophones, tokens, files: TJSONObject;
    syllables, list: TJSONArray;
    pair: TJSONPair;
    folder, name: string;
    items: TArray<string>;
    points: TArray<Cardinal>;
    create_model: TCreateModel;
    error_text: array[0..1023] of WideChar;
    i: Integer;
begin
    root := nil;
    manifest_root := nil;
    try
        folder := TPath.Combine(m_directory, 'char_lm');
        manifest_root := TJSONObject.ParseJSONValue(TFile.ReadAllText(
            TPath.Combine(folder, 'runtime_manifest.json'), TEncoding.UTF8));
        if not (manifest_root is TJSONObject) or
            (TJSONObject(manifest_root).GetValue<Integer>('format', 0) <> 1) then
            raise EInvalidOp.Create('Unsupported pinyin LM manifest');
        m_context_chars := TJSONObject(manifest_root).GetValue<Integer>('correction_context_chars', 0);
        files := TJSONObject(manifest_root).GetValue('files') as TJSONObject;
        if (files = nil) or (files.Count <> Length(required_files)) then
            raise EInvalidOp.Create('Incomplete pinyin LM manifest');
        for name in required_files do
        begin
            value := files.GetValue(name);
            if not (value is TJSONString) then
                raise EInvalidOp.Create('Missing pinyin LM asset hash');
            if not SameText(THashSHA2.GetHashStringFromFile(TPath.Combine(folder, name)),
                value.Value) then
                raise EInvalidOp.Create('Pinyin LM asset hash mismatch');
        end;
        root := TJSONObject.ParseJSONValue(TFile.ReadAllText(
            TPath.Combine(folder, 'pinyin_readings.json'), TEncoding.UTF8));
        if not (root is TJSONObject) then
            raise EInvalidOp.Create('Invalid pinyin LM readings');
        table := TJSONObject(root);
        syllables := table.GetValue('syllables') as TJSONArray;
        for i := 0 to syllables.Count - 1 do
            m_syllable_index.AddOrSetValue(syllables.Items[i].Value, i);
        tokens := table.GetValue('tokens') as TJSONObject;
        m_syllable_base := tokens.GetValue<Cardinal>('syllable_base');
        m_sep := tokens.GetValue<Cardinal>('sep');
        m_draft := tokens.GetValue<Cardinal>('draft');
        readings := table.GetValue('readings') as TJSONObject;
        for pair in readings do
        begin
            list := pair.JsonValue as TJSONArray;
            SetLength(items, list.Count);
            for i := 0 to list.Count - 1 do items[i] := list.Items[i].Value;
            m_readings.AddOrSetValue(pair.JsonString.Value, items);
        end;
        homophones := table.GetValue('homophones') as TJSONObject;
        for pair in homophones do
        begin
            list := pair.JsonValue as TJSONArray;
            SetLength(points, list.Count);
            for i := 0 to list.Count - 1 do
            begin
                value := list.Items[i];
                points[i] := Char.ConvertToUtf32(value.Value, 0);
            end;
            m_homophones.AddOrSetValue(pair.JsonString.Value, points);
        end;
        m_provider := LoadLibraryEx(PChar(TPath.Combine(m_directory,
            'onnxruntime_providers_shared.dll')), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
        m_ort := LoadLibraryEx(PChar(TPath.Combine(m_directory, 'onnxruntime.dll')), 0,
            LOAD_WITH_ALTERED_SEARCH_PATH);
        m_module := LoadLibraryEx(PChar(TPath.Combine(m_directory,
            'cassotis_pinyin_transformer_ort.dll')), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
        if (m_provider = 0) or (m_ort = 0) or (m_module = 0) then
            raise EInvalidOp.Create('Pinyin LM runtime DLL unavailable');
        create_model := TCreateModel(GetProcAddress(m_module, 'nc_lm_create'));
        m_correct := TCorrect(GetProcAddress(m_module, 'nc_lm_correct'));
        m_destroy := TDestroyModel(GetProcAddress(m_module, 'nc_lm_destroy'));
        if not Assigned(create_model) or not Assigned(m_correct) or not Assigned(m_destroy) then
            raise EInvalidOp.Create('Pinyin LM runtime must be rebuilt');
        m_handle := create_model(PChar(folder), nc_shared_lm_threads, @error_text[0],
            Length(error_text));
        if m_handle = nil then raise EInvalidOp.Create(string(PChar(@error_text[0])));
        m_ready := True;
    except
        on E: Exception do
        begin
            m_error := E.Message;
            append_log_line_shared(get_default_log_path,
                '[INFO] pinyin-lm repair unavailable: ' + m_error + sLineBreak);
        end;
    end;
    root.Free;
    manifest_root.Free;
    m_loaded.SetEvent;
end;

function TncLmRepairHost.ready: Boolean;
begin
    Result := (m_loaded.WaitFor(0) = wrSignaled) and m_ready;
end;

function TncLmRepairHost.wait_until_ready(const timeout_ms: Cardinal): Boolean;
begin
    Result := (m_loaded.WaitFor(timeout_ms) = wrSignaled) and m_ready;
end;

function TncLmRepairHost.last_error: string;
begin
    if m_loaded.WaitFor(0) = wrSignaled then Result := m_error
    else Result := '';
end;

procedure TncLmRepairHost.set_document_context(const document_key, preceding_text: string);
begin
end;

// The draft's syllables in the typed pinyin; apostrophes are boundaries a
// syllable may not cross. Ambiguous or impossible alignments are rejected.
function TncLmRepairHost.align(const query_text, draft_text: string;
    out syllables: TArray<string>): Boolean;
type TGrid = TArray<TArray<Integer>>;
var
    raw, compact, reading: string;
    readings: TArray<string>;
    boundary: TArray<Boolean>;
    counts, previous_offset: TGrid;
    previous_reading: TArray<TArray<string>>;
    i, j, k, finish: Integer;
    valid: Boolean;
begin
    Result := False;
    SetLength(syllables, 0);
    raw := LowerCase(query_text);
    SetLength(boundary, Length(raw) + 1);
    compact := '';
    for i := 1 to Length(raw) do
    begin
        if raw[i] = '''' then boundary[Length(compact)] := True
        else if CharInSet(raw[i], ['a'..'z']) then compact := compact + raw[i]
        else Exit;
    end;
    SetLength(counts, Length(draft_text) + 1);
    SetLength(previous_offset, Length(counts));
    SetLength(previous_reading, Length(counts));
    for i := 0 to High(counts) do
    begin
        SetLength(counts[i], Length(compact) + 1);
        SetLength(previous_offset[i], Length(compact) + 1);
        SetLength(previous_reading[i], Length(compact) + 1);
    end;
    counts[0][0] := 1;
    for i := 0 to Length(draft_text) - 1 do
    begin
        if not m_readings.TryGetValue(draft_text[i + 1], readings) then Exit;
        for j := 0 to Length(compact) - 1 do
        begin
            if counts[i][j] = 0 then Continue;
            for reading in readings do
            begin
                finish := j + Length(reading);
                if (finish > Length(compact)) or
                    (Copy(compact, j + 1, Length(reading)) <> reading) then Continue;
                valid := True;
                for k := j + 1 to finish - 1 do
                    if boundary[k] then valid := False;
                if not valid then Continue;
                if counts[i + 1][finish] = 0 then
                begin
                    previous_offset[i + 1][finish] := j;
                    previous_reading[i + 1][finish] := reading;
                end;
                counts[i + 1][finish] := counts[i + 1][finish] + counts[i][j];
                if counts[i + 1][finish] > 2 then counts[i + 1][finish] := 2;
            end;
        end;
    end;
    j := Length(compact);
    if counts[Length(draft_text)][j] <> 1 then Exit;
    SetLength(syllables, Length(draft_text));
    for i := Length(draft_text) downto 1 do
    begin
        syllables[i - 1] := previous_reading[i][j];
        j := previous_offset[i][j];
    end;
    Result := True;
end;

function TncLmRepairHost.try_repair(const query_text, draft_text: string;
    const document_key, preceding_text: string;
    out repaired_text, aligned_pinyin: string; out minimum_word_ratio: Double): Boolean;
var
    syllables: TArray<string>;
    homophones: TArray<Cardinal>;
    allowed: TArray<Cardinal>;
    offsets: TArray<Integer>;
    context, syllable, prefix: string;
    buffer: array[0..255] of WideChar;
    error_text: array[0..1023] of WideChar;
    gain: Single;
    draft_point, point: Cardinal;
    i, index, rc: Integer;
    present: Boolean;
begin
    Result := False;
    repaired_text := '';
    aligned_pinyin := '';
    minimum_word_ratio := 1;
    if not ready or (Length(draft_text) < 6) or (Length(draft_text) > 40) then Exit;
    // Only BMP drafts: one UTF-16 unit per character, as the engine counts units.
    for i := 1 to Length(draft_text) do
        if draft_text[i].IsSurrogate then Exit;
    if not align(query_text, draft_text, syllables) then Exit;
    // Training contexts are the text before the span in its paragraph.
    prefix := '';
    if m_context_chars > 0 then
    begin
        prefix := preceding_text;
        i := LastDelimiter(#10#13, prefix);
        if i > 0 then prefix := Copy(prefix, i + 1, MaxInt);
        prefix := Trim(prefix);
        if Length(prefix) > m_context_chars then
            prefix := Copy(prefix, Length(prefix) - m_context_chars + 1, MaxInt);
        if (prefix <> '') and prefix[1].IsLowSurrogate then Delete(prefix, 1, 1);
    end;
    context := prefix + Char.ConvertFromUtf32(m_sep);
    SetLength(offsets, Length(syllables) + 1);
    SetLength(allowed, 0);
    for i := 0 to High(syllables) do
    begin
        syllable := syllables[i];
        if not m_syllable_index.TryGetValue(syllable, index) then Exit;
        context := context + Char.ConvertFromUtf32(m_syllable_base + Cardinal(index));
        if aligned_pinyin <> '' then aligned_pinyin := aligned_pinyin + #3;
        aligned_pinyin := aligned_pinyin + syllable;
        offsets[i] := Length(allowed);
        draft_point := Ord(draft_text[i + 1]);
        present := False;
        if m_homophones.TryGetValue(syllable, homophones) then
            for point in homophones do
            begin
                allowed := allowed + [point];
                present := present or (point = draft_point);
            end;
        if not present then allowed := allowed + [draft_point];
    end;
    offsets[Length(syllables)] := Length(allowed);
    context := context + Char.ConvertFromUtf32(m_draft) + draft_text + Char.ConvertFromUtf32(m_sep);
    m_run_lock.Acquire;
    try
        rc := m_correct(m_handle, PWideChar(context), PWideChar(draft_text), @allowed[0],
            @offsets[0], c_lm_repair_width, @buffer[0], Length(buffer), @gain, 0,
            @error_text[0], Length(error_text));
    finally
        m_run_lock.Release;
    end;
    if (rc <> 1) or (gain < c_lm_repair_min_gain) then Exit;
    repaired_text := string(PWideChar(@buffer[0]));
    if Length(repaired_text) <> Length(draft_text) then
    begin
        repaired_text := '';
        Exit;
    end;
    minimum_word_ratio := c_lm_repair_word_ratio;
    Result := True;
end;

end.
