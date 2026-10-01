unit nc_local_completion_host;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    System.SyncObjs,
    nc_engine_intf,
    nc_char_lm;

type
    TncLocalCompletionHost = class;

    TncLocalCompletionTask = record
        session_id: string;
        session_instance_id: UInt64;
        candidate_generation: UInt64;
        prefetch_only: Boolean;
        request: TncLongNeuralCompletionRequest;
    end;

    // The model stage of a task (ranked pool, direct result or fallback
    // generator), before the LM policy chooses what to show. A prefetch keeps
    // only this stage, so the LM policy never competes with the engine thread
    // for the model while the visible candidates are still being settled.
    TncLocalCompletionModelOutput = record
        accepted: Boolean;
        use_pool: Boolean;
        generated: Boolean;
        failed: Boolean;
        elapsed_ms: UInt64;
        result: TncLongNeuralCompletionResult;
        // Direct (non-pool) model or fallback generator output.
        suffix_text: string;
        suffix_pinyin: string;
        suffix_path: string;
        base_rank: Integer;
        replace_units: Integer;
        confidence: Single;
    end;

    TncLocalCompletionPrefetchCache = record
    private
        m_valid: Boolean;
        m_task: TncLocalCompletionTask;
        m_output: TncLocalCompletionModelOutput;
    public
        procedure clear;
        procedure remember(const task: TncLocalCompletionTask;
            const output: TncLocalCompletionModelOutput);
        function take(const task: TncLocalCompletionTask;
            out output: TncLocalCompletionModelOutput): Boolean;
    end;

    TncLocalCompletionResultEvent = reference to procedure(
        const task: TncLocalCompletionTask;
        const completion_result: TncLongNeuralCompletionResult);

    TncLocalCompletionFinishedEvent = reference to procedure(
        const task: TncLocalCompletionTask; const accepted: Boolean;
        const completion_result: TncLongNeuralCompletionResult);

    TncLocalCompletionWorker = class(TThread)
    private
        m_owner: TncLocalCompletionHost;
    protected
        procedure Execute; override;
    public
        constructor create(const owner: TncLocalCompletionHost);
        procedure detach_owner;
    end;

    TncLocalCompletionHost = class
    private type
        TncLcCreate = function(const model_path, index_path: PWideChar;
            const intra_threads: Integer; const error_text: PWideChar;
            const error_capacity: Integer): Pointer; cdecl;
        TncLcRun = function(const handle: Pointer;
            const context, query_syllables, top1_text, top1_path,
            top2_text, top2_path: PWideChar;
            const phonetic_only: Integer;
            const minimum_confidence: Single;
            const output_suffix_text: PWideChar;
            const output_suffix_text_capacity: Integer;
            const output_suffix_pinyin: PWideChar;
            const output_suffix_pinyin_capacity: Integer;
            const output_suffix_path: PWideChar;
            const output_suffix_path_capacity: Integer;
            const output_base_rank: PInteger;
            const output_replace_units: PInteger;
            const output_confidence: PSingle;
            const error_text: PWideChar;
            const error_capacity: Integer): Integer; cdecl;
        TncLcRunPool = function(const handle: Pointer;
            const context, query_syllables, top1_text, top1_path,
            top2_text, top2_path: PWideChar;
            const phonetic_only: Integer;
            const output_suffix_texts: PWideChar;
            const output_suffix_text_stride: Integer;
            const output_suffix_pinyins: PWideChar;
            const output_suffix_pinyin_stride: Integer;
            const output_suffix_paths: PWideChar;
            const output_suffix_path_stride: Integer;
            const output_base_ranks: PInteger;
            const output_replace_units: PInteger;
            const output_scores: PSingle;
            const output_capacity: Integer;
            const output_abstain_score: PSingle;
            const output_candidate_count: PInteger;
            const error_text: PWideChar;
            const error_capacity: Integer): Integer; cdecl;
        TncLcDestroy = procedure(const handle: Pointer); cdecl;
        TncLcgCreate = function(const model_path, index_path: PWideChar;
            const intra_threads: Integer; const error_text: PWideChar;
            const error_capacity: Integer): Pointer; cdecl;
        TncLcgRun = function(const handle: Pointer;
            const context, query_syllables, top1_text, top2_text: PWideChar;
            const minimum_confidence: Single;
            const output_suffix_text: PWideChar;
            const output_suffix_text_capacity: Integer;
            const output_suffix_pinyin: PWideChar;
            const output_suffix_pinyin_capacity: Integer;
            const output_suffix_path: PWideChar;
            const output_suffix_path_capacity: Integer;
            const output_confidence: PSingle;
            const error_text: PWideChar;
            const error_capacity: Integer): Integer; cdecl;
        TncLcgDestroy = procedure(const handle: Pointer); cdecl;
    private
        m_base_directory: string;
        m_lock: TCriticalSection;
        m_wakeup: TEvent;
        m_worker: TncLocalCompletionWorker;
        m_pending_task: TncLocalCompletionTask;
        m_has_pending_task: Boolean;
        m_prefetch_cache: TncLocalCompletionPrefetchCache;
        m_result_event: TncLocalCompletionResultEvent;
        m_finished_event: TncLocalCompletionFinishedEvent;
        m_module: HMODULE;
        m_onnx_runtime_module: HMODULE;
        m_onnx_provider_module: HMODULE;
        m_session: Pointer;
        m_generator_session: Pointer;
        m_run_function: TncLcRun;
        m_run_pool_function: TncLcRunPool;
        m_destroy_function: TncLcDestroy;
        m_generator_run_function: TncLcgRun;
        m_generator_destroy_function: TncLcgDestroy;
        m_minimum_confidence: Single;
        m_result_timeout_ms: UInt64;
        m_capture_candidate_pool: Boolean;
        m_char_lm: IncCharLm;
        m_ready: Boolean;
        m_last_error: string;
        procedure worker_execute;
        procedure load_runtime;
        function pop_task(out task: TncLocalCompletionTask): Boolean;
        function run_model(const task: TncLocalCompletionTask;
            out output: TncLocalCompletionModelOutput): Boolean;
        function finish_task(const task: TncLocalCompletionTask;
            const output: TncLocalCompletionModelOutput;
            out completion_result: TncLongNeuralCompletionResult): Boolean;
        procedure queue_finished(const task: TncLocalCompletionTask;
            const accepted: Boolean;
            const completion_result: TncLongNeuralCompletionResult);
        procedure deliver_finished(const task: TncLocalCompletionTask;
            const accepted: Boolean;
            const completion_result: TncLongNeuralCompletionResult);
        procedure disable(const error_text: string);
        procedure log_message(const level_text, message_text: string);
    public
        constructor create(const base_directory: string;
            const result_event: TncLocalCompletionResultEvent;
            const finished_event: TncLocalCompletionFinishedEvent = nil;
            const deterministic_benchmark: Boolean = False;
            const capture_candidate_pool: Boolean = False);
        destructor Destroy; override;
        procedure enqueue(const task: TncLocalCompletionTask);
        procedure prefetch(const task: TncLocalCompletionTask);
        { With a character LM the ranked pool is always requested and the LM
          policy picks the continuation among ranked and generated ones.
          Pass TncCharLmHost.background_view; nil turns the policy off. }
        procedure set_char_lm(const model: IncCharLm);
        function ready: Boolean;
        function last_error: string;
    end;

implementation

uses
    System.IOUtils,
    System.JSON,
    System.Hash,
    System.Math,
    nc_log,
    nc_pinyin_parser;

const
    c_model_threads = 4;
    // The model and the LM policy together; a later result is dropped. The
    // session also drops results for an input that has moved on, so this only
    // bounds how late a hint may appear: room for a loaded machine (about
    // twice the unloaded P95) while still ahead of a typical next keystroke.
    c_result_timeout_ms = 80;
    c_generator_minimum_confidence: Single = -2.8333864;
    c_completion_pool_capacity = 32;
    c_completion_text_stride = 128;
    c_completion_pinyin_stride = 256;
    c_completion_path_stride = 128;

procedure TncLocalCompletionPrefetchCache.clear;
begin
    m_valid := False;
    m_task := Default(TncLocalCompletionTask);
    m_output := Default(TncLocalCompletionModelOutput);
end;

procedure TncLocalCompletionPrefetchCache.remember(const task: TncLocalCompletionTask;
    const output: TncLocalCompletionModelOutput);
begin
    clear;
    if (not task.prefetch_only) or output.failed then Exit;
    m_task := task;
    m_output := output;
    m_valid := True;
end;

function TncLocalCompletionPrefetchCache.take(const task: TncLocalCompletionTask;
    out output: TncLocalCompletionModelOutput): Boolean;
begin
    Result := m_valid and not task.prefetch_only and
        (task.session_id = m_task.session_id) and
        (task.session_instance_id = m_task.session_instance_id) and
        (task.request.query_prefix = m_task.request.query_prefix) and
        (task.request.query_syllables = m_task.request.query_syllables) and
        (task.request.context_text = m_task.request.context_text) and
        (task.request.phonetic_only = m_task.request.phonetic_only) and
        (task.request.top1_text = m_task.request.top1_text) and
        (task.request.top1_path = m_task.request.top1_path) and
        (task.request.top1_anchor_path = m_task.request.top1_anchor_path) and
        (task.request.top2_text = m_task.request.top2_text) and
        (task.request.top2_path = m_task.request.top2_path) and
        (task.request.top2_anchor_path = m_task.request.top2_anchor_path);
    output := Default(TncLocalCompletionModelOutput);
    if Result then
        output := m_output;
    // A single-use worker-owned slot. Delivery uses the new task's generation,
    // never the speculative task's generation or callback.
    clear;
end;

constructor TncLocalCompletionWorker.create(
    const owner: TncLocalCompletionHost);
begin
    inherited create(True);
    FreeOnTerminate := False;
    Priority := tpLower;
    m_owner := owner;
end;

procedure TncLocalCompletionWorker.detach_owner;
begin
    m_owner := nil;
end;

procedure TncLocalCompletionWorker.Execute;
var
    owner: TncLocalCompletionHost;
begin
    owner := m_owner;
    if owner <> nil then
    begin
        owner.worker_execute;
    end;
end;

constructor TncLocalCompletionHost.create(const base_directory: string;
    const result_event: TncLocalCompletionResultEvent;
    const finished_event: TncLocalCompletionFinishedEvent;
    const deterministic_benchmark: Boolean;
    const capture_candidate_pool: Boolean);
begin
    inherited create;
    m_base_directory := base_directory;
    m_lock := TCriticalSection.Create;
    m_wakeup := TEvent.Create(nil, False, False, '');
    m_pending_task := Default(TncLocalCompletionTask);
    m_has_pending_task := False;
    m_result_event := result_event;
    m_finished_event := finished_event;
    m_module := 0;
    m_onnx_runtime_module := 0;
    m_onnx_provider_module := 0;
    m_session := nil;
    m_generator_session := nil;
    m_run_function := nil;
    m_run_pool_function := nil;
    m_destroy_function := nil;
    m_generator_run_function := nil;
    m_generator_destroy_function := nil;
    m_minimum_confidence := 0.0;
    m_capture_candidate_pool := capture_candidate_pool;
    if deterministic_benchmark then
    begin
        m_result_timeout_ms := 0;
    end
    else
    begin
        m_result_timeout_ms := c_result_timeout_ms;
    end;
    m_ready := False;
    m_last_error := '';
    m_worker := TncLocalCompletionWorker.create(Self);
    m_worker.Start;
end;

destructor TncLocalCompletionHost.Destroy;
begin
    m_result_event := nil;
    m_finished_event := nil;
    if m_worker <> nil then
    begin
        m_worker.Terminate;
        m_wakeup.SetEvent;
        m_worker.WaitFor;
        TThread.RemoveQueuedEvents(m_worker);
        m_worker.detach_owner;
        m_worker.Free;
        m_worker := nil;
    end;
    if (m_session <> nil) and Assigned(m_destroy_function) then
    begin
        m_destroy_function(m_session);
        m_session := nil;
    end;
    if (m_generator_session <> nil) and
        Assigned(m_generator_destroy_function) then
    begin
        m_generator_destroy_function(m_generator_session);
        m_generator_session := nil;
    end;
    if m_module <> 0 then
    begin
        FreeLibrary(m_module);
        m_module := 0;
    end;
    if m_onnx_runtime_module <> 0 then
    begin
        FreeLibrary(m_onnx_runtime_module);
        m_onnx_runtime_module := 0;
    end;
    if m_onnx_provider_module <> 0 then
    begin
        FreeLibrary(m_onnx_provider_module);
        m_onnx_provider_module := 0;
    end;
    m_wakeup.Free;
    m_wakeup := nil;
    m_lock.Free;
    m_lock := nil;
    inherited Destroy;
end;

procedure TncLocalCompletionHost.log_message(const level_text,
    message_text: string);
begin
    append_log_line_shared(get_default_log_path,
        FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [' + level_text +
        '] local-completion ' + message_text + sLineBreak);
end;

procedure TncLocalCompletionHost.disable(const error_text: string);
begin
    m_lock.Acquire;
    try
        m_ready := False;
        m_last_error := error_text;
    finally
        m_lock.Release;
    end;
    log_message('WARN', 'disabled: ' + error_text);
end;

procedure TncLocalCompletionHost.load_runtime;
var
    wrapper_path: string;
    runtime_path: string;
    provider_path: string;
    model_directory: string;
    model_path: string;
    generator_model_path: string;
    index_path: string;
    manifest_path: string;
    root_value: TJSONValue;
    root_object: TJSONObject;
    gate_object: TJSONObject;
    dev_object: TJSONObject;
    index_object: TJSONObject;
    generator_object: TJSONObject;
    threshold_value: TJSONValue;
    format_value: TJSONValue;
    model_file_value: TJSONValue;
    model_hash_value: TJSONValue;
    vocab_hash_value: TJSONValue;
    index_file_value: TJSONValue;
    index_hash_value: TJSONValue;
    index_vocab_hash_value: TJSONValue;
    generator_hash_value: TJSONValue;
    model_hash: string;
    vocab_hash: string;
    index_hash: string;
    index_vocab_hash: string;
    generator_hash: string;
    create_function: TncLcCreate;
    generator_create_function: TncLcgCreate;
    error_buffer: array[0..511] of WideChar;
begin
    wrapper_path := TPath.Combine(m_base_directory,
        'cassotis_pinyin_transformer_ort.dll');
    runtime_path := TPath.Combine(m_base_directory, 'onnxruntime.dll');
    provider_path := TPath.Combine(m_base_directory,
        'onnxruntime_providers_shared.dll');
    model_directory := TPath.Combine(m_base_directory, 'local_completion');
    model_path := TPath.Combine(model_directory,
        'local_completion_path_ranker_int8.onnx');
    generator_model_path := TPath.Combine(model_directory,
        'local_completion_generator_int8.onnx');
    index_path := TPath.Combine(model_directory,
        'local_completion_index.bin');
    manifest_path := TPath.Combine(model_directory, 'model_manifest.json');
    if not FileExists(wrapper_path) then
    begin
        raise EFileNotFoundException.Create(wrapper_path);
    end;
    if not FileExists(runtime_path) then
    begin
        raise EFileNotFoundException.Create(runtime_path);
    end;
    if not FileExists(provider_path) then
    begin
        raise EFileNotFoundException.Create(provider_path);
    end;
    if not FileExists(model_path) then
    begin
        raise EFileNotFoundException.Create(model_path);
    end;
    if not FileExists(index_path) then
    begin
        raise EFileNotFoundException.Create(index_path);
    end;
    if not FileExists(manifest_path) then
    begin
        raise EFileNotFoundException.Create(manifest_path);
    end;

    root_value := TJSONObject.ParseJSONValue(
        TFile.ReadAllText(manifest_path, TEncoding.UTF8));
    try
        if not (root_value is TJSONObject) then
        begin
            raise EInvalidOp.Create('invalid local-completion manifest');
        end;
        root_object := TJSONObject(root_value);
        format_value := root_object.GetValue('format');
        model_file_value := root_object.GetValue('model');
        if (not (format_value is TJSONNumber)) or
            (StrToIntDef(format_value.Value, 0) <> 1) or
            (not (model_file_value is TJSONString)) or
            (not SameText(model_file_value.Value,
            ExtractFileName(model_path))) then
        begin
            raise EInvalidOp.Create(
                'local-completion manifest format is invalid');
        end;
        gate_object := root_object.GetValue('gate') as TJSONObject;
        if gate_object = nil then
        begin
            raise EInvalidOp.Create('local-completion gate is absent');
        end;
        dev_object := gate_object.GetValue('dev') as TJSONObject;
        if dev_object = nil then
        begin
            raise EInvalidOp.Create('local-completion development gate is absent');
        end;
        threshold_value := dev_object.GetValue('threshold');
        if not (threshold_value is TJSONNumber) then
        begin
            raise EInvalidOp.Create('local-completion threshold is invalid');
        end;
        m_minimum_confidence := TJSONNumber(threshold_value).AsDouble;
        if IsNan(m_minimum_confidence) or IsInfinite(m_minimum_confidence) or
            (m_minimum_confidence < -1000.0) or
            (m_minimum_confidence > 1000.0) then
        begin
            raise EInvalidOp.Create('local-completion threshold is out of range');
        end;
        model_hash_value := root_object.GetValue('model_sha256');
        vocab_hash_value := root_object.GetValue('vocab_sha256');
        index_object := root_object.GetValue('runtime_index') as TJSONObject;
        if (not (model_hash_value is TJSONString)) or
            (not (vocab_hash_value is TJSONString)) or
            (index_object = nil) then
        begin
            raise EInvalidOp.Create(
                'local-completion asset identity is absent');
        end;
        index_file_value := index_object.GetValue('file');
        index_hash_value := index_object.GetValue('sha256');
        index_vocab_hash_value := index_object.GetValue('vocab_sha256');
        if (not (index_file_value is TJSONString)) or
            (not SameText(index_file_value.Value,
            ExtractFileName(index_path))) or
            (not (index_hash_value is TJSONString)) or
            (not (index_vocab_hash_value is TJSONString)) then
        begin
            raise EInvalidOp.Create(
                'local-completion index identity is invalid');
        end;
        model_hash := LowerCase(model_hash_value.Value);
        vocab_hash := LowerCase(vocab_hash_value.Value);
        index_hash := LowerCase(index_hash_value.Value);
        index_vocab_hash := LowerCase(index_vocab_hash_value.Value);
        generator_object := root_object.GetValue(
            'fallback_generator') as TJSONObject;
        generator_hash := '';
        if generator_object <> nil then
        begin
            generator_hash_value := generator_object.GetValue('model_sha256');
            if generator_hash_value is TJSONString then
            begin
                generator_hash := LowerCase(generator_hash_value.Value);
            end;
        end;
        if (Length(model_hash) <> 64) or (Length(vocab_hash) <> 64) or
            (Length(index_hash) <> 64) or
            (not SameText(vocab_hash, index_vocab_hash)) then
        begin
            raise EInvalidOp.Create(
                'local-completion vocabulary identity is inconsistent');
        end;
    finally
        root_value.Free;
    end;
    if not SameText(LowerCase(THashSHA2.GetHashStringFromFile(model_path)),
        model_hash) then
    begin
        raise EInvalidOp.Create('local-completion model checksum mismatch');
    end;
    if not SameText(LowerCase(THashSHA2.GetHashStringFromFile(index_path)),
        index_hash) then
    begin
        raise EInvalidOp.Create('local-completion index checksum mismatch');
    end;
    if FileExists(generator_model_path) and
        ((Length(generator_hash) <> 64) or
        (not SameText(LowerCase(THashSHA2.GetHashStringFromFile(
        generator_model_path)), generator_hash))) then
    begin
        raise EInvalidOp.Create(
            'local-completion generator checksum mismatch');
    end;

    m_onnx_provider_module := LoadLibraryEx(PChar(provider_path), 0,
        LOAD_WITH_ALTERED_SEARCH_PATH);
    if m_onnx_provider_module = 0 then
    begin
        raise EOSError.CreateFmt('LoadLibrary failed (%d): %s',
            [GetLastError, provider_path]);
    end;
    m_onnx_runtime_module := LoadLibraryEx(PChar(runtime_path), 0,
        LOAD_WITH_ALTERED_SEARCH_PATH);
    if m_onnx_runtime_module = 0 then
    begin
        raise EOSError.CreateFmt('LoadLibrary failed (%d): %s',
            [GetLastError, runtime_path]);
    end;
    m_module := LoadLibraryEx(PChar(wrapper_path), 0,
        LOAD_WITH_ALTERED_SEARCH_PATH);
    if m_module = 0 then
    begin
        raise EOSError.CreateFmt('LoadLibrary failed (%d): %s',
            [GetLastError, wrapper_path]);
    end;
    create_function := TncLcCreate(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lc_create'))));
    m_run_function := TncLcRun(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lc_run'))));
    m_run_pool_function := TncLcRunPool(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lc_run_pool'))));
    m_destroy_function := TncLcDestroy(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lc_destroy'))));
    generator_create_function := TncLcgCreate(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lcg_create'))));
    m_generator_run_function := TncLcgRun(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lcg_run'))));
    m_generator_destroy_function := TncLcgDestroy(GetProcAddress(m_module,
        PAnsiChar(AnsiString('nc_lcg_destroy'))));
    if (not Assigned(create_function)) or
        (not Assigned(m_run_function)) or
        (not Assigned(m_destroy_function)) then
    begin
        raise EInvalidOp.Create('invalid local-completion wrapper ABI');
    end;
    FillChar(error_buffer, SizeOf(error_buffer), 0);
    m_session := create_function(PChar(model_path), PChar(index_path),
        c_model_threads, @error_buffer[0], Length(error_buffer));
    if m_session = nil then
    begin
        raise EInvalidOp.Create(string(PWideChar(@error_buffer[0])));
    end;
    if FileExists(generator_model_path) and
        Assigned(generator_create_function) and
        Assigned(m_generator_run_function) and
        Assigned(m_generator_destroy_function) then
    begin
        FillChar(error_buffer, SizeOf(error_buffer), 0);
        m_generator_session := generator_create_function(
            PChar(generator_model_path), PChar(index_path), c_model_threads,
            @error_buffer[0], Length(error_buffer));
        if m_generator_session = nil then
        begin
            log_message('WARN', 'generator disabled: ' +
                string(PWideChar(@error_buffer[0])));
        end;
    end;
    m_lock.Acquire;
    try
        m_ready := True;
        m_last_error := '';
    finally
        m_lock.Release;
    end;
    log_message('INFO', Format(
        'weight-quantized model and mapped index loaded threshold=%.4f',
        [m_minimum_confidence]));
end;

function TncLocalCompletionHost.pop_task(
    out task: TncLocalCompletionTask): Boolean;
begin
    task := Default(TncLocalCompletionTask);
    m_lock.Acquire;
    try
        Result := m_has_pending_task;
        if Result then
        begin
            task := m_pending_task;
            m_pending_task := Default(TncLocalCompletionTask);
            m_has_pending_task := False;
        end;
    finally
        m_lock.Release;
    end;
end;

function TncLocalCompletionHost.run_model(const task: TncLocalCompletionTask;
    out output: TncLocalCompletionModelOutput): Boolean;
var
    suffix_text: array[0..127] of WideChar;
    suffix_pinyin: array[0..255] of WideChar;
    suffix_path: array[0..127] of WideChar;
    error_buffer: array[0..511] of WideChar;
    base_rank: Integer;
    replace_units: Integer;
    confidence: Single;
    pool_suffix_texts: array[0..
        c_completion_pool_capacity * c_completion_text_stride - 1] of WideChar;
    pool_suffix_pinyins: array[0..
        c_completion_pool_capacity * c_completion_pinyin_stride - 1] of WideChar;
    pool_suffix_paths: array[0..
        c_completion_pool_capacity * c_completion_path_stride - 1] of WideChar;
    pool_base_ranks: array[0..c_completion_pool_capacity - 1] of Integer;
    pool_replace_units: array[0..c_completion_pool_capacity - 1] of Integer;
    pool_scores: array[0..c_completion_pool_capacity - 1] of Single;
    pool_abstain_score: Single;
    pool_candidate_count: Integer;
    pool_idx: Integer;
    second_score: Single;
    started_at: UInt64;
    char_lm: IncCharLm;
    completion_result: TncLongNeuralCompletionResult;
begin
    output := Default(TncLocalCompletionModelOutput);
    completion_result := Default(TncLongNeuralCompletionResult);
    FillChar(suffix_text, SizeOf(suffix_text), 0);
    FillChar(suffix_pinyin, SizeOf(suffix_pinyin), 0);
    FillChar(suffix_path, SizeOf(suffix_path), 0);
    FillChar(error_buffer, SizeOf(error_buffer), 0);
    base_rank := 0;
    replace_units := 0;
    confidence := 0.0;
    pool_abstain_score := 0.0;
    pool_candidate_count := 0;
    started_at := GetTickCount64;
    // set_char_lm may swap the model on a configuration reload.
    m_lock.Acquire;
    try
        char_lm := m_char_lm;
    finally
        m_lock.Release;
    end;
    output.use_pool := (m_capture_candidate_pool or (char_lm <> nil)) and
        Assigned(m_run_pool_function);
    if output.use_pool then
    begin
        FillChar(pool_suffix_texts, SizeOf(pool_suffix_texts), 0);
        FillChar(pool_suffix_pinyins, SizeOf(pool_suffix_pinyins), 0);
        FillChar(pool_suffix_paths, SizeOf(pool_suffix_paths), 0);
        FillChar(pool_base_ranks, SizeOf(pool_base_ranks), 0);
        FillChar(pool_replace_units, SizeOf(pool_replace_units), 0);
        FillChar(pool_scores, SizeOf(pool_scores), 0);
        if m_run_pool_function(m_session,
            PChar(task.request.context_text),
            PChar(task.request.query_syllables),
            PChar(task.request.top1_text),
            PChar(task.request.top1_anchor_path),
            PChar(task.request.top2_text),
            PChar(task.request.top2_anchor_path),
            Ord(task.request.phonetic_only),
            @pool_suffix_texts[0], c_completion_text_stride,
            @pool_suffix_pinyins[0], c_completion_pinyin_stride,
            @pool_suffix_paths[0], c_completion_path_stride,
            @pool_base_ranks[0], @pool_replace_units[0], @pool_scores[0],
            c_completion_pool_capacity, @pool_abstain_score,
            @pool_candidate_count, @error_buffer[0],
            Length(error_buffer)) <> 0 then
        begin
            pool_candidate_count := EnsureRange(pool_candidate_count, 0,
                c_completion_pool_capacity);
            completion_result.abstain_score := pool_abstain_score;
            SetLength(completion_result.candidates, pool_candidate_count);
            for pool_idx := 0 to pool_candidate_count - 1 do
            begin
                completion_result.candidates[pool_idx].suffix_text :=
                    string(PWideChar(@pool_suffix_texts[
                    pool_idx * c_completion_text_stride]));
                completion_result.candidates[pool_idx].suffix_pinyin_path :=
                    string(PWideChar(@pool_suffix_pinyins[
                    pool_idx * c_completion_pinyin_stride]));
                completion_result.candidates[pool_idx].suffix_path :=
                    string(PWideChar(@pool_suffix_paths[
                    pool_idx * c_completion_path_stride]));
                completion_result.candidates[pool_idx].base_rank :=
                    pool_base_ranks[pool_idx];
                completion_result.candidates[pool_idx].replace_units :=
                    pool_replace_units[pool_idx];
                completion_result.candidates[pool_idx].score :=
                    pool_scores[pool_idx];
            end;
            Result := pool_candidate_count > 0;
            if Result then
            begin
                second_score := pool_abstain_score;
                if pool_candidate_count > 1 then
                begin
                    second_score := Max(second_score, pool_scores[1]);
                end;
                confidence := pool_scores[0] - second_score;
                // The calibrated threshold may be negative. In that case the
                // joint KEEP/SWITCH/ABSTAIN model intentionally permits a
                // candidate just below ABSTAIN when its development-set
                // evidence is strong enough. Do not add a second hard gate
                // that silently discards the learned calibration.
                Result := confidence >= m_minimum_confidence;
                if Result then
                begin
                    completion_result.suffix_text :=
                        completion_result.candidates[0].suffix_text;
                    completion_result.suffix_pinyin_path :=
                        completion_result.candidates[0].suffix_pinyin_path;
                    completion_result.suffix_path :=
                        completion_result.candidates[0].suffix_path;
                    completion_result.base_rank :=
                        completion_result.candidates[0].base_rank;
                    completion_result.replace_units :=
                        completion_result.candidates[0].replace_units;
                    completion_result.confidence := confidence;
                end;
            end;
        end
        else
        begin
            Result := False;
        end;
    end
    else
    begin
        Result := m_run_function(m_session,
            PChar(task.request.context_text),
            PChar(task.request.query_syllables),
            PChar(task.request.top1_text),
            PChar(task.request.top1_anchor_path),
            PChar(task.request.top2_text),
            PChar(task.request.top2_anchor_path),
            Ord(task.request.phonetic_only),
            m_minimum_confidence,
            @suffix_text[0], Length(suffix_text),
            @suffix_pinyin[0], Length(suffix_pinyin),
            @suffix_path[0], Length(suffix_path),
            @base_rank, @replace_units, @confidence, @error_buffer[0],
            Length(error_buffer)) <> 0;
    end;
    if (not Result) and (not task.request.phonetic_only) and
        (error_buffer[0] = #0) and
        (m_generator_session <> nil) and
        Assigned(m_generator_run_function) then
    begin
        FillChar(suffix_text, SizeOf(suffix_text), 0);
        FillChar(suffix_pinyin, SizeOf(suffix_pinyin), 0);
        FillChar(suffix_path, SizeOf(suffix_path), 0);
        confidence := 0.0;
        Result := m_generator_run_function(m_generator_session,
            PChar(task.request.context_text),
            PChar(task.request.query_syllables),
            PChar(task.request.top1_text),
            PChar(task.request.top2_text),
            c_generator_minimum_confidence,
            @suffix_text[0], Length(suffix_text),
            @suffix_pinyin[0], Length(suffix_pinyin),
            @suffix_path[0], Length(suffix_path),
            @confidence, @error_buffer[0], Length(error_buffer)) <> 0;
        if Result then
        begin
            base_rank := 1;
            replace_units := 0;
            output.generated := True;
        end;
    end;
    output.elapsed_ms := GetTickCount64 - started_at;
    if (not Result) and (error_buffer[0] <> #0) then
    begin
        output.failed := True;
        disable(string(PWideChar(@error_buffer[0])));
        Exit;
    end;
    output.accepted := Result;
    output.result := completion_result;
    output.suffix_text := string(PWideChar(@suffix_text[0]));
    output.suffix_pinyin := string(PWideChar(@suffix_pinyin[0]));
    output.suffix_path := string(PWideChar(@suffix_path[0]));
    output.base_rank := base_rank;
    output.replace_units := replace_units;
    output.confidence := confidence;
end;

// A tail word's first replace_units syllables are exactly the last typed
// syllables (the word does not lengthen a syllable that may still be typed).
function tail_reread_is_exact(const query_syllables, word_pinyin, word_text: string;
    const replace_units: Integer): Boolean;
var
    typed: TArray<string>;
    parsed: TncPinyinParseResult;
    parser: TncPinyinParser;
    idx: Integer;
begin
    Result := False;
    typed := query_syllables.Split([''''], TStringSplitOptions.ExcludeEmpty);
    if (replace_units < 1) or (replace_units > Length(typed)) then
        Exit;
    parser := TncPinyinParser.create;
    try
        parsed := parser.parse(LowerCase(word_pinyin.Replace(#3, '').Replace('''', '')));
    finally
        parser.Free;
    end;
    if Length(parsed) <> nc_char_lm_code_point_count(word_text) then
        Exit;
    for idx := 0 to replace_units - 1 do
        if not SameText(parsed[idx].text, typed[Length(typed) - replace_units + idx]) then
            Exit;
    Result := True;
end;

function TncLocalCompletionHost.finish_task(const task: TncLocalCompletionTask;
    const output: TncLocalCompletionModelOutput;
    out completion_result: TncLongNeuralCompletionResult): Boolean;
var
    started_at: UInt64;
    char_lm: IncCharLm;

    // Replaces the ranker/generator decision with the character LM policy.
    // Leaves the decision untouched when the LM cannot score (busy, not ready).
    procedure apply_char_lm_policy;
    var
        candidates: TArray<TncCharLmContinuation>;
        sources: TArray<Integer>;
        item, chosen: TncCharLmContinuation;
        base, next_char: string;
        idx, other, best: Integer;
        probability: Double;
    begin
        // Tail words from the engine join the pool after the model's ranked
        // candidates, so reports see them and results can refer to them.
        for idx := 0 to High(task.request.tail_candidates) do
        begin
            other := 0;
            while (other < Length(completion_result.candidates)) and
                ((completion_result.candidates[other].replace_units <>
                task.request.tail_candidates[idx].replace_units) or
                (completion_result.candidates[other].base_rank <> 1) or
                (completion_result.candidates[other].suffix_text <>
                task.request.tail_candidates[idx].suffix_text)) do
                Inc(other);
            if other = Length(completion_result.candidates) then
                completion_result.candidates := completion_result.candidates +
                    [task.request.tail_candidates[idx]];
        end;
        for idx := 0 to High(completion_result.candidates) do
        begin
            case completion_result.candidates[idx].base_rank of
                1: base := task.request.top1_text;
                2: base := task.request.top2_text;
            else
                Continue;
            end;
            if (base = '') or (completion_result.candidates[idx].suffix_text = '') or
                (completion_result.candidates[idx].replace_units < 0) or
                (completion_result.candidates[idx].replace_units >= Length(base)) then
                Continue;
            item := Default(TncCharLmContinuation);
            item.base_text := Copy(base, 1, Length(base) -
                completion_result.candidates[idx].replace_units);
            item.suffix_text := completion_result.candidates[idx].suffix_text;
            item.full_base_text := base;
            item.base_rank := completion_result.candidates[idx].base_rank;
            item.replace_units := completion_result.candidates[idx].replace_units;
            if completion_result.candidates[idx].tail_word then
            begin
                item.tail_word := True;
                item.tail_rank := completion_result.candidates[idx].tail_rank;
                item.exact_reread := tail_reread_is_exact(task.request.query_syllables,
                    completion_result.candidates[idx].suffix_pinyin_path,
                    item.suffix_text, item.replace_units);
            end
            else
            begin
                item.rank := idx + 1;
                item.score := completion_result.candidates[idx].score;
                item.abstain_score := completion_result.abstain_score;
            end;
            candidates := candidates + [item];
            sources := sources + [idx];
        end;
        if output.generated and (task.request.top1_text <> '') and (output.suffix_text <> '') then
        begin
            item := Default(TncCharLmContinuation);
            item.base_text := task.request.top1_text;
            item.suffix_text := output.suffix_text;
            item.full_base_text := task.request.top1_text;
            item.base_rank := 1;
            item.generator := True;
            idx := 0;
            while (idx < Length(candidates)) and (candidates[idx].base_text +
                candidates[idx].suffix_text <> item.base_text + item.suffix_text) do
                Inc(idx);
            if idx = Length(candidates) then
            begin
                candidates := candidates + [item];
                sources := sources + [-1];
            end;
        end;
        if (Length(candidates) = 0) or not nc_char_lm_choose_continuation(char_lm,
            task.request.context_text, candidates, task.request.phonetic_only, chosen, best,
            probability) then
            Exit;
        completion_result.suffix_text := '';
        completion_result.suffix_pinyin_path := '';
        completion_result.suffix_path := '';
        completion_result.base_rank := 0;
        completion_result.replace_units := 0;
        completion_result.lm_next := False;
        completion_result.confidence := probability;
        Result := probability >= c_char_lm_tab_min_probability;
        if not Result then
            Exit;
        if best < 0 then
        begin
            // An LM next character: the engine reads it and checks the re-read
            // typed tail before showing it.
            next_char := Copy(chosen.suffix_text, chosen.replace_units + 1, MaxInt);
            completion_result.suffix_text := chosen.suffix_text;
            completion_result.suffix_path := next_char;
            if chosen.replace_units > 0 then
                completion_result.suffix_path := Copy(chosen.suffix_text, 1,
                    chosen.replace_units) + #3 + next_char;
            completion_result.base_rank := chosen.base_rank;
            completion_result.replace_units := chosen.replace_units;
            completion_result.lm_next := True;
        end
        else if sources[best] >= 0 then
        begin
            completion_result.suffix_text := completion_result.candidates[sources[best]].suffix_text;
            completion_result.suffix_pinyin_path :=
                completion_result.candidates[sources[best]].suffix_pinyin_path;
            completion_result.suffix_path := completion_result.candidates[sources[best]].suffix_path;
            completion_result.base_rank := completion_result.candidates[sources[best]].base_rank;
            completion_result.replace_units := completion_result.candidates[sources[best]].replace_units;
        end
        else
        begin
            completion_result.suffix_text := output.suffix_text;
            completion_result.suffix_pinyin_path := output.suffix_pinyin;
            completion_result.suffix_path := output.suffix_path;
            completion_result.base_rank := 1;
        end;
    end;

begin
    Result := output.accepted;
    completion_result := output.result;
    if output.failed then
        Exit(False);
    started_at := GetTickCount64;
    m_lock.Acquire;
    try
        char_lm := m_char_lm;
    finally
        m_lock.Release;
    end;
    if output.use_pool and (char_lm <> nil) then
    begin
        apply_char_lm_policy;
    end;
    // The deadline covers the model and the policy, prefetched or not.
    if Result and (m_result_timeout_ms > 0) and
        (output.elapsed_ms + (GetTickCount64 - started_at) > m_result_timeout_ms) then
    begin
        Result := False;
        Exit;
    end;
    if Result and (completion_result.suffix_text = '') then
    begin
        completion_result.suffix_text := output.suffix_text;
        completion_result.suffix_pinyin_path := output.suffix_pinyin;
        completion_result.suffix_path := output.suffix_path;
        completion_result.base_rank := output.base_rank;
        completion_result.replace_units := output.replace_units;
        completion_result.confidence := output.confidence;
    end;
end;

procedure TncLocalCompletionHost.queue_finished(
    const task: TncLocalCompletionTask; const accepted: Boolean;
    const completion_result: TncLongNeuralCompletionResult);
var
    task_copy: TncLocalCompletionTask;
    accepted_copy: Boolean;
    result_copy: TncLongNeuralCompletionResult;
begin
    task_copy := task;
    accepted_copy := accepted;
    result_copy := completion_result;
    TThread.Queue(m_worker,
        procedure
        begin
            deliver_finished(task_copy, accepted_copy, result_copy);
        end);
end;

procedure TncLocalCompletionHost.deliver_finished(
    const task: TncLocalCompletionTask; const accepted: Boolean;
    const completion_result: TncLongNeuralCompletionResult);
var
    handler: TncLocalCompletionResultEvent;
    finished_handler: TncLocalCompletionFinishedEvent;
begin
    handler := m_result_event;
    if accepted and Assigned(handler) then
    begin
        handler(task, completion_result);
    end;
    finished_handler := m_finished_event;
    if Assigned(finished_handler) then
    begin
        finished_handler(task, accepted, completion_result);
    end;
end;

procedure TncLocalCompletionHost.worker_execute;
var
    task: TncLocalCompletionTask;
    completion_result: TncLongNeuralCompletionResult;
    model_output: TncLocalCompletionModelOutput;
    accepted: Boolean;
begin
    try
        load_runtime;
    except
        on e: Exception do
        begin
            disable(e.Message);
            Exit;
        end;
    end;
    while (m_worker <> nil) and (not m_worker.Terminated) do
    begin
        if not pop_task(task) then
        begin
            m_wakeup.WaitFor(250);
            if m_worker.Terminated then
            begin
                Break;
            end;
            if not pop_task(task) then
            begin
                Continue;
            end;
        end;
        if m_worker.Terminated then
        begin
            Break;
        end;
        if task.prefetch_only then
        begin
            m_prefetch_cache.clear;
            run_model(task, model_output);
            m_prefetch_cache.remember(task, model_output);
            if not ready then Break;
            Continue;
        end;
        if not m_prefetch_cache.take(task, model_output) then
            run_model(task, model_output);
        accepted := finish_task(task, model_output, completion_result);
        // Production only needs accepted results. The optional finished event
        // lets synchronous benchmark bridges observe abstentions without
        // adding no-op main-thread callbacks to the normal Host path.
        if accepted or Assigned(m_finished_event) then
        begin
            queue_finished(task, accepted, completion_result);
        end;
        if not ready then
        begin
            Break;
        end;
    end;
end;

procedure TncLocalCompletionHost.enqueue(
    const task: TncLocalCompletionTask);
begin
    if (task.session_id = '') or
        (task.request.query_prefix = '') or
        (task.request.top1_anchor_path = '') then
    begin
        Exit;
    end;
    m_lock.Acquire;
    try
        // Keep the latest task while the model is loading, but do not keep
        // feeding a runtime that has already failed closed.
        if (not m_ready) and (m_last_error <> '') then
        begin
            Exit;
        end;
        m_pending_task := task;
        m_has_pending_task := True;
    finally
        m_lock.Release;
    end;
    m_wakeup.SetEvent;
end;

procedure TncLocalCompletionHost.prefetch(const task: TncLocalCompletionTask);
var speculative: TncLocalCompletionTask;
begin
    speculative := task;
    speculative.prefetch_only := True;
    enqueue(speculative);
end;

procedure TncLocalCompletionHost.set_char_lm(const model: IncCharLm);
begin
    m_lock.Acquire;
    try
        m_char_lm := model;
    finally
        m_lock.Release;
    end;
end;

function TncLocalCompletionHost.ready: Boolean;
begin
    m_lock.Acquire;
    try
        Result := m_ready;
    finally
        m_lock.Release;
    end;
end;

function TncLocalCompletionHost.last_error: string;
begin
    m_lock.Acquire;
    try
        Result := m_last_error;
    finally
        m_lock.Release;
    end;
end;

end.
