unit nc_char_lm_host;

{ Host side of the shared character LM:
  IncCharLm over nc_lm_* in cassotis_pinyin_transformer_ort.dll. The model
  lives in <runtime>\char_lm (tools/export_char_lm.py output); any load failure
  leaves the model unavailable and every ranking unchanged.

  One session serves the engine thread (long and short rerank, latency
  sensitive) and the Tab continuation worker. Engine calls wait at most
  c_foreground_wait_ms for a running call; worker calls go through
  background_view, wait for the model and step aside while an engine call is
  waiting. }

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs, nc_char_lm;

type
    TncCharLmHost = class(TInterfacedObject, IncCharLm, IncCharLmNext, IncCharLmContinue)
    private type
        TCreateModel = function(directory: PWideChar; intra_threads: Integer;
            error_text: PWideChar; capacity: Integer): Pointer; cdecl;
        TScoreTexts = function(handle: Pointer; context: PWideChar; texts: PPWideChar;
            count, min_count, max_nodes: Integer; out_logp: PSingle; timeout_ms: Integer;
            error_text: PWideChar; capacity: Integer): Integer; cdecl;
        TScoreTextsNext = function(handle: Pointer; context: PWideChar; texts: PPWideChar;
            count, min_count, max_nodes: Integer; out_logp: PSingle; next_indices: PInteger;
            next_count, top_k: Integer; out_next_code_points: PCardinal; out_next_logp: PSingle;
            timeout_ms: Integer; error_text: PWideChar; capacity: Integer): Integer; cdecl;
        TContinueText = function(handle: Pointer; context, prefix: PWideChar;
            max_chars: Integer; out_text: PWideChar; out_capacity: Integer; out_logp: PSingle;
            timeout_ms: Integer; error_text: PWideChar; capacity: Integer): Integer; cdecl;
        TDestroyModel = procedure(handle: Pointer); cdecl;
    private
        m_directory, m_error: string;
        m_threads, m_timeout_ms: Integer;
        m_loader: TThread;
        m_signal: TEvent;
        m_ready, m_stopping: Integer;
        m_module, m_ort, m_provider: HMODULE;
        m_handle: Pointer;
        m_score: TScoreTexts;
        m_score_next: TScoreTextsNext;
        m_continue: TContinueText;
        m_destroy: TDestroyModel;
        m_gate: TObject;
        m_foreground_waiting: Integer;
        procedure load;
        function run_score(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        function run_continue(const context, text: string; const max_chars: Integer;
            out chars: TArray<string>; out logp: TArray<Single>): Integer;
    public
        constructor Create(const directory: string; background: Boolean;
            intra_threads: Integer = 4; timeout_ms: Integer = 100);
        destructor Destroy; override;
        function char_lm_ready: Boolean;
        function score_texts(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_background(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_next(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        function score_texts_next_background(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        function continue_text(const context, text: string; const max_chars: Integer;
            out chars: TArray<string>; out logp: TArray<Single>): Integer;
        function continue_text_background(const context, text: string;
            const max_chars: Integer; out chars: TArray<string>;
            out logp: TArray<Single>): Integer;
        { The same model for a background worker (see the unit comment). }
        function background_view: IncCharLm;
        property last_error: string read m_error;
    end;

implementation

uses System.IOUtils, System.JSON, System.Hash, System.Character, nc_log;

const
    c_foreground_wait_ms = 60;

type
    TncCharLmBackgroundView = class(TInterfacedObject, IncCharLm, IncCharLmNext,
        IncCharLmContinue)
    private
        m_host: TncCharLmHost;
        m_keep: IncCharLm;
    public
        constructor Create(const host: TncCharLmHost);
        function char_lm_ready: Boolean;
        function score_texts(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_next(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        function continue_text(const context, text: string; const max_chars: Integer;
            out chars: TArray<string>; out logp: TArray<Single>): Integer;
    end;

constructor TncCharLmBackgroundView.Create(const host: TncCharLmHost);
begin
    inherited Create;
    m_host := host;
    m_keep := host;
end;

function TncCharLmBackgroundView.char_lm_ready: Boolean;
begin
    Result := m_host.char_lm_ready;
end;

function TncCharLmBackgroundView.score_texts(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
begin
    Result := m_host.score_texts_background(context, texts, min_count, max_nodes, logp);
end;

function TncCharLmBackgroundView.score_texts_next(const context: string;
    const texts: TArray<string>; const min_count, max_nodes: Integer;
    const next_texts: TArray<Integer>; const top_k: Integer; out logp: TArray<Single>;
    out next_chars: TArray<string>; out next_logp: TArray<Single>): Integer;
begin
    Result := m_host.score_texts_next_background(context, texts, min_count, max_nodes,
        next_texts, top_k, logp, next_chars, next_logp);
end;

function TncCharLmBackgroundView.continue_text(const context, text: string;
    const max_chars: Integer; out chars: TArray<string>; out logp: TArray<Single>): Integer;
begin
    Result := m_host.continue_text_background(context, text, max_chars, chars, logp);
end;

procedure log_model_state(const message_text: string);
begin
    try
        append_log_line_shared(get_default_log_path,
            FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            ' [INFO] char-lm ' + message_text + sLineBreak);
    except
        // Diagnostic I/O must not affect model availability or host stability.
    end;
end;

constructor TncCharLmHost.Create(const directory: string; background: Boolean;
    intra_threads: Integer; timeout_ms: Integer);
begin
    inherited Create;
    m_directory := ExpandFileName(directory);
    m_threads := intra_threads;
    m_timeout_ms := timeout_ms;
    m_gate := TObject.Create;
    m_signal := TEvent.Create(nil, True, False, '');
    if background then
    begin
        // Load on first use so dictionary and long-model cold start come first.
        m_loader := TThread.CreateAnonymousThread(procedure
            begin
                m_signal.WaitFor(INFINITE);
                if TInterlocked.CompareExchange(m_stopping, 0, 0) = 0 then load;
            end);
        m_loader.FreeOnTerminate := False;
        m_loader.Priority := tpLower;
        m_loader.Start;
    end
    else
        load;
end;

destructor TncCharLmHost.Destroy;
begin
    TInterlocked.Exchange(m_stopping, 1);
    if m_signal <> nil then m_signal.SetEvent;
    if m_loader <> nil then begin m_loader.WaitFor; m_loader.Free; end;
    if Assigned(m_destroy) and (m_handle <> nil) then m_destroy(m_handle);
    if m_module <> 0 then FreeLibrary(m_module);
    if m_ort <> 0 then FreeLibrary(m_ort);
    if m_provider <> 0 then FreeLibrary(m_provider);
    m_signal.Free;
    m_gate.Free;
    inherited;
end;

procedure TncCharLmHost.load;
const
    required_files: array[0..1] of string = ('char_lm.onnx', 'char_lm_vocab.bin');
var
    root, hash_value: TJSONValue;
    manifest, files: TJSONObject;
    folder, name: string;
    create_model: TCreateModel;
    error_text: array[0..1023] of WideChar;
begin
    root := nil;
    try
        folder := TPath.Combine(m_directory, 'char_lm');
        root := TJSONObject.ParseJSONValue(TFile.ReadAllText(
            TPath.Combine(folder, 'runtime_manifest.json'), TEncoding.UTF8));
        if not (root is TJSONObject) then
            raise EInvalidOp.Create('Invalid character LM manifest');
        manifest := TJSONObject(root);
        if manifest.GetValue<Integer>('format', 0) <> 1 then
            raise EInvalidOp.Create('Unsupported character LM manifest');
        files := manifest.GetValue('files') as TJSONObject;
        if (files = nil) or (files.Count <> Length(required_files)) then
            raise EInvalidOp.Create('Incomplete character LM manifest');
        for name in required_files do
        begin
            hash_value := files.GetValue(name);
            if not (hash_value is TJSONString) then
                raise EInvalidOp.Create('Missing character LM asset hash');
            if not SameText(THashSHA2.GetHashStringFromFile(TPath.Combine(folder, name)),
                hash_value.Value) then
                raise EInvalidOp.Create('Character LM asset hash mismatch');
        end;
        m_provider := LoadLibraryEx(PChar(TPath.Combine(m_directory,
            'onnxruntime_providers_shared.dll')), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
        m_ort := LoadLibraryEx(PChar(TPath.Combine(m_directory,
            'onnxruntime.dll')), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
        m_module := LoadLibraryEx(PChar(TPath.Combine(m_directory,
            'cassotis_pinyin_transformer_ort.dll')), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
        if (m_provider = 0) or (m_ort = 0) or (m_module = 0) then
            raise EInvalidOp.Create('Character LM runtime DLL unavailable');
        create_model := TCreateModel(GetProcAddress(m_module, 'nc_lm_create'));
        m_score := TScoreTexts(GetProcAddress(m_module, 'nc_lm_score'));
        // Optional: an older runtime scores without next characters.
        m_score_next := TScoreTextsNext(GetProcAddress(m_module, 'nc_lm_score_next'));
        m_continue := TContinueText(GetProcAddress(m_module, 'nc_lm_continue'));
        m_destroy := TDestroyModel(GetProcAddress(m_module, 'nc_lm_destroy'));
        if not Assigned(create_model) or not Assigned(m_score) or not Assigned(m_destroy) then
            raise EInvalidOp.Create('Character LM runtime must be rebuilt');
        m_handle := create_model(PChar(folder), m_threads, @error_text[0], Length(error_text));
        if m_handle = nil then raise EInvalidOp.Create(string(PChar(@error_text[0])));
        TInterlocked.Exchange(m_ready, 1);
        log_model_state(Format('ready; quantization=%s; threads=%d; deadline_ms=%d',
            [manifest.GetValue<string>('quantization', '?'), m_threads, m_timeout_ms]));
    except
        on E: Exception do
        begin
            m_error := E.Message;
            log_model_state('unavailable; keeping baseline: ' + m_error);
        end;
    end;
    root.Free;
end;

function TncCharLmHost.char_lm_ready: Boolean;
begin
    Result := TInterlocked.CompareExchange(m_ready, 0, 0) = 1;
    if not Result then m_signal.SetEvent;
end;

function TncCharLmHost.score_texts(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
var
    next_chars: TArray<string>;
    next_logp: TArray<Single>;
begin
    Result := score_texts_next(context, texts, min_count, max_nodes, nil, 0, logp,
        next_chars, next_logp);
end;

function TncCharLmHost.score_texts_background(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
var
    next_chars: TArray<string>;
    next_logp: TArray<Single>;
begin
    Result := score_texts_next_background(context, texts, min_count, max_nodes, nil, 0, logp,
        next_chars, next_logp);
end;

function TncCharLmHost.score_texts_next(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
    const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
    out next_logp: TArray<Single>): Integer;
begin
    Result := -1;
    SetLength(logp, 0);
    SetLength(next_chars, 0);
    SetLength(next_logp, 0);
    if not char_lm_ready then Exit;
    TInterlocked.Increment(m_foreground_waiting);
    try
        if not TMonitor.Enter(m_gate, c_foreground_wait_ms) then Exit;
    finally
        TInterlocked.Decrement(m_foreground_waiting);
    end;
    try
        Result := run_score(context, texts, min_count, max_nodes, next_texts, top_k, logp,
            next_chars, next_logp);
    finally
        TMonitor.Exit(m_gate);
    end;
end;

function TncCharLmHost.score_texts_next_background(const context: string;
    const texts: TArray<string>; const min_count, max_nodes: Integer;
    const next_texts: TArray<Integer>; const top_k: Integer; out logp: TArray<Single>;
    out next_chars: TArray<string>; out next_logp: TArray<Single>): Integer;
begin
    Result := -1;
    SetLength(logp, 0);
    SetLength(next_chars, 0);
    SetLength(next_logp, 0);
    if not char_lm_ready then Exit;
    while TInterlocked.CompareExchange(m_foreground_waiting, 0, 0) > 0 do
        Sleep(1);
    TMonitor.Enter(m_gate);
    try
        Result := run_score(context, texts, min_count, max_nodes, next_texts, top_k, logp,
            next_chars, next_logp);
    finally
        TMonitor.Exit(m_gate);
    end;
end;

function TncCharLmHost.background_view: IncCharLm;
begin
    Result := TncCharLmBackgroundView.Create(Self);
end;

function TncCharLmHost.run_score(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
    const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
    out next_logp: TArray<Single>): Integer;
var
    pointers: TArray<PWideChar>;
    code_points: TArray<Cardinal>;
    idx: Integer;
    error_text: array[0..1023] of WideChar;
begin
    Result := -1;
    SetLength(logp, 0);
    SetLength(next_chars, 0);
    SetLength(next_logp, 0);
    if (Length(texts) = 0) or (min_count < 1) or (min_count > Length(texts)) then Exit;
    if (Length(next_texts) > 0) and ((top_k < 1) or (top_k > 32) or
        (Length(next_texts) > Length(texts))) then Exit;
    // The native ABI uses terminated UTF-16 strings; never silently truncate.
    if Pos(#0, context) > 0 then Exit;
    SetLength(pointers, Length(texts));
    for idx := 0 to High(texts) do
    begin
        if (texts[idx] = '') or (Pos(#0, texts[idx]) > 0) then Exit;
        pointers[idx] := PWideChar(texts[idx]);
    end;
    SetLength(logp, Length(texts));
    SetLength(next_chars, Length(next_texts) * top_k);
    SetLength(next_logp, Length(next_texts) * top_k);
    if (Length(next_texts) > 0) and Assigned(m_score_next) then
    begin
        SetLength(code_points, Length(next_texts) * top_k);
        Result := m_score_next(m_handle, PWideChar(context), @pointers[0], Length(texts),
            min_count, max_nodes, @logp[0], @next_texts[0], Length(next_texts), top_k,
            @code_points[0], @next_logp[0], m_timeout_ms, @error_text[0], Length(error_text));
        for idx := 0 to High(code_points) do
            if code_points[idx] <> 0 then
                next_chars[idx] := Char.ConvertFromUtf32(code_points[idx]);
    end
    else
        Result := m_score(m_handle, PWideChar(context), @pointers[0], Length(texts),
            min_count, max_nodes, @logp[0], m_timeout_ms, @error_text[0], Length(error_text));
    if Result < min_count then
    begin
        Result := -1;
        SetLength(logp, 0);
        SetLength(next_chars, 0);
        SetLength(next_logp, 0);
    end
    else
        SetLength(logp, Result);
end;

function TncCharLmHost.run_continue(const context, text: string; const max_chars: Integer;
    out chars: TArray<string>; out logp: TArray<Single>): Integer;
var
    buffer: TArray<WideChar>;
    error_text: array[0..1023] of WideChar;
    value: string;
    produced, idx, position: Integer;
begin
    Result := -1;
    SetLength(chars, 0);
    SetLength(logp, 0);
    if (not Assigned(m_continue)) or (text = '') or (max_chars < 1) or (max_chars > 32) or
        (Pos(#0, context) > 0) or (Pos(#0, text) > 0) then Exit;
    SetLength(buffer, 2 * max_chars + 1);
    SetLength(logp, max_chars);
    produced := m_continue(m_handle, PWideChar(context), PWideChar(text), max_chars,
        @buffer[0], Length(buffer), @logp[0], m_timeout_ms, @error_text[0], Length(error_text));
    if produced < 0 then
    begin
        SetLength(logp, 0);
        Exit;
    end;
    // One element per character; a supplementary character is a surrogate pair.
    value := PWideChar(@buffer[0]);
    position := 1;
    for idx := 0 to produced - 1 do
    begin
        if position > Length(value) then Break;
        if (position < Length(value)) and value[position].IsHighSurrogate then
        begin
            chars := chars + [Copy(value, position, 2)];
            Inc(position, 2);
        end
        else
        begin
            chars := chars + [value[position]];
            Inc(position);
        end;
    end;
    SetLength(logp, Length(chars));
    Result := Length(chars);
end;

function TncCharLmHost.continue_text(const context, text: string; const max_chars: Integer;
    out chars: TArray<string>; out logp: TArray<Single>): Integer;
begin
    Result := -1;
    SetLength(chars, 0);
    SetLength(logp, 0);
    if not char_lm_ready then Exit;
    TInterlocked.Increment(m_foreground_waiting);
    try
        if not TMonitor.Enter(m_gate, c_foreground_wait_ms) then Exit;
    finally
        TInterlocked.Decrement(m_foreground_waiting);
    end;
    try
        Result := run_continue(context, text, max_chars, chars, logp);
    finally
        TMonitor.Exit(m_gate);
    end;
end;

function TncCharLmHost.continue_text_background(const context, text: string;
    const max_chars: Integer; out chars: TArray<string>; out logp: TArray<Single>): Integer;
begin
    Result := -1;
    SetLength(chars, 0);
    SetLength(logp, 0);
    if not char_lm_ready then Exit;
    while TInterlocked.CompareExchange(m_foreground_waiting, 0, 0) > 0 do
        Sleep(1);
    TMonitor.Enter(m_gate);
    try
        Result := run_continue(context, text, max_chars, chars, logp);
    finally
        TMonitor.Exit(m_gate);
    end;
end;

end.
