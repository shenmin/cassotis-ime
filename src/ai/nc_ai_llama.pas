unit nc_ai_llama;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    System.SyncObjs,
    System.Math,
    nc_types,
    nc_ai_intf,
    nc_llama_bridge,
    nc_ai_text_utils,
    nc_config,
    nc_log;

type
    TncAiLlamaProvider = class;

    TncAiLlamaWorkerThread = class(TThread)
    private
        m_owner: TncAiLlamaProvider;
    protected
        procedure Execute; override;
    public
        constructor create(const owner: TncAiLlamaProvider);
    end;

    TncAiLlamaProvider = class(TncAiProvider)
    private
        m_bridge: TncLlamaBridge;
        m_ready: Boolean;
        m_last_error: string;
        m_lock: TCriticalSection;
        m_log_lock: TCriticalSection;
        m_logger: TncLogger;
        m_log_enabled: Boolean;
        m_stop_event: TEvent;
        m_worker: TncAiLlamaWorkerThread;
        m_debounce_ms: Integer;
        m_pending_request: TncAiRequest;
        m_pending_signature: string;
        m_pending_version: Int64;
        m_pending_tick: UInt64;
        m_has_pending: Boolean;
        m_cached_signature: string;
        m_cached_candidates: TncCandidateList;
        m_cached_success: Boolean;
        m_last_failed_signature: string;
        m_last_failed_tick: UInt64;
        m_last_suppressed_signature: string;
        m_last_suppressed_tick: UInt64;
        procedure init_logger;
        procedure free_logger;
        procedure log_message(const level: TncLogLevel; const msg: string; const force_debug_output: Boolean = False);
        procedure log_debug(const msg: string);
        procedure log_info(const msg: string);
        procedure log_warn(const msg: string);
        procedure log_error(const msg: string);
        procedure clear_pending_locked;
        function effective_timeout_ms(const request_timeout_ms: Integer): Integer;
        function build_request_signature(const request: TncAiRequest): string;
        procedure schedule_request(const request: TncAiRequest; const signature: string);
        function try_get_cached_response(const signature: string; out response: TncAiResponse): Boolean;
        function try_get_stable_request(out request: TncAiRequest; out signature: string; out version: Int64): Boolean;
        function is_current_version(const version: Int64): Boolean;
        procedure store_result(const signature: string; const candidates: TncCandidateList; const success: Boolean;
            const version: Int64; const error_text: string);
        procedure run_worker_once;
        function get_last_error: string;
    public
        constructor create(const config: TncEngineConfig);
        destructor Destroy; override;
        function request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean; override;
        property ready: Boolean read m_ready;
        property last_error: string read get_last_error;
    end;

implementation

const
    c_default_ai_debounce_ms = 400;
    c_worker_poll_ms = 20;
    c_default_ai_timeout_ms = 1200;
    c_worker_shutdown_timeout_ms = 3000;
    c_suppressed_log_interval_ms = 3000;
    c_failed_retry_cooldown_ms = 1500;
    c_large_model_size_threshold = Int64(16) * 1024 * 1024 * 1024;
    c_huge_model_size_threshold = Int64(24) * 1024 * 1024 * 1024;
    c_ai_temperature = 0.0;

procedure copy_candidate_list(const source: TncCandidateList; out dest: TncCandidateList);
var
    i: Integer;
begin
    SetLength(dest, Length(source));
    for i := 0 to High(source) do
    begin
        dest[i] := source[i];
    end;
end;

function try_get_file_size_bytes(const path: string; out size_bytes: Int64): Boolean;
var
    stream: TFileStream;
begin
    size_bytes := 0;
    Result := False;

    if (path = '') or (not FileExists(path)) then
    begin
        Exit;
    end;

    try
        stream := TFileStream.Create(path, fmOpenRead or fmShareDenyNone);
        try
            size_bytes := stream.Size;
            Result := True;
        finally
            stream.Free;
        end;
    except
        Result := False;
    end;
end;

constructor TncAiLlamaWorkerThread.create(const owner: TncAiLlamaProvider);
begin
    inherited create(False);
    FreeOnTerminate := False;
    m_owner := owner;
end;

procedure TncAiLlamaWorkerThread.Execute;
begin
    while WaitForSingleObject(m_owner.m_stop_event.Handle, c_worker_poll_ms) = WAIT_TIMEOUT do
    begin
        m_owner.run_worker_once;
    end;
end;

constructor TncAiLlamaProvider.create(const config: TncEngineConfig);
var
    saved_mask: TFPUExceptionMask;
begin
    inherited create;
    m_lock := TCriticalSection.Create;
    m_log_lock := TCriticalSection.Create;
    m_stop_event := TEvent.Create(nil, True, False, '');
    m_worker := nil;
    m_debounce_ms := c_default_ai_debounce_ms;
    m_pending_version := 0;
    m_pending_tick := 0;
    m_has_pending := False;
    m_cached_signature := '';
    SetLength(m_cached_candidates, 0);
    m_cached_success := False;
    m_last_failed_signature := '';
    m_last_failed_tick := 0;
    m_last_suppressed_signature := '';
    m_last_suppressed_tick := 0;

    init_logger;
    log_info('AI llama provider create start');

    m_bridge := TncLlamaBridge.create;
    saved_mask := GetExceptionMask;
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
    try
        try
            m_ready := m_bridge.initialize(config, m_last_error);
            if m_ready then
            begin
                m_ready := m_bridge.load_model(config.ai_llama_model_path, m_last_error);
            end;
        except
            on e: Exception do
            begin
                m_ready := False;
                m_last_error := Format('AI initialize exception %s: %s', [e.ClassName, e.Message]);
            end;
        end;
    finally
        SetExceptionMask(saved_mask);
    end;

    if (not m_ready) and (m_last_error = '') then
    begin
        m_last_error := 'llama provider initialize failed';
    end;

    if m_ready then
    begin
        log_info(Format('AI llama ready backend=%s runtime=%s model=%s',
            [llama_backend_to_text(m_bridge.resolved_backend), m_bridge.runtime_dir, m_bridge.loaded_model_path]));
        m_worker := TncAiLlamaWorkerThread.create(Self);
    end
    else
    begin
        log_error('AI llama initialize failed: ' + m_last_error);
    end;
end;

destructor TncAiLlamaProvider.Destroy;
var
    wait_result: DWORD;
begin
    if m_stop_event <> nil then
    begin
        m_stop_event.SetEvent;
    end;

    if m_bridge <> nil then
    begin
        m_bridge.request_abort;
    end;

    if m_worker <> nil then
    begin
        m_worker.Terminate;
        wait_result := WaitForSingleObject(m_worker.Handle, c_worker_shutdown_timeout_ms);
        if wait_result <> WAIT_OBJECT_0 then
        begin
            log_error(Format('AI worker shutdown timeout (%dms), force terminating thread',
                [c_worker_shutdown_timeout_ms]));
            TerminateThread(m_worker.Handle, 1);
            WaitForSingleObject(m_worker.Handle, 200);
        end;
        m_worker.Free;
        m_worker := nil;
    end;

    if m_bridge <> nil then
    begin
        m_bridge.Free;
        m_bridge := nil;
    end;

    if m_stop_event <> nil then
    begin
        m_stop_event.Free;
        m_stop_event := nil;
    end;

    if m_lock <> nil then
    begin
        m_lock.Free;
        m_lock := nil;
    end;

    log_info('AI llama provider destroyed');
    free_logger;

    if m_log_lock <> nil then
    begin
        m_log_lock.Free;
        m_log_lock := nil;
    end;

    inherited Destroy;
end;

procedure TncAiLlamaProvider.init_logger;
var
    config_manager: TncConfigManager;
    log_config: TncLogConfig;
begin
    m_logger := nil;
    m_log_enabled := False;
    try
        config_manager := TncConfigManager.create(get_default_config_path);
        try
            log_config := config_manager.load_log_config;
        finally
            config_manager.Free;
        end;

        if log_config.log_path = '' then
        begin
            log_config.log_path := get_default_log_path;
        end;

        m_logger := TncLogger.create(log_config.log_path, log_config.max_size_kb);
        m_logger.set_level(log_config.level);
        m_log_enabled := log_config.enabled;
    except
        on e: Exception do
        begin
            OutputDebugString(PChar('[ai_llama] init_logger failed: ' + e.Message));
        end;
    end;
end;

procedure TncAiLlamaProvider.free_logger;
begin
    if m_logger <> nil then
    begin
        m_logger.Free;
        m_logger := nil;
    end;
end;

procedure TncAiLlamaProvider.log_message(const level: TncLogLevel; const msg: string; const force_debug_output: Boolean);
begin
    if m_log_lock = nil then
    begin
        Exit;
    end;

    m_log_lock.Acquire;
    try
        try
            if m_logger <> nil then
            begin
                if m_log_enabled then
                begin
                    case level of
                        ll_debug:
                            m_logger.debug(msg);
                        ll_info:
                            m_logger.info(msg);
                        ll_warn:
                            m_logger.warn(msg);
                        ll_error:
                            m_logger.error(msg);
                    end;
                end;
            end;
        except
        end;

        if force_debug_output then
        begin
            OutputDebugString(PChar('[ai_llama] ' + msg));
        end;
    finally
        m_log_lock.Release;
    end;
end;

procedure TncAiLlamaProvider.log_debug(const msg: string);
begin
    log_message(ll_debug, msg, False);
end;

procedure TncAiLlamaProvider.log_info(const msg: string);
begin
    log_message(ll_info, msg, False);
end;

procedure TncAiLlamaProvider.log_warn(const msg: string);
begin
    log_message(ll_warn, msg, True);
end;

procedure TncAiLlamaProvider.log_error(const msg: string);
begin
    log_message(ll_error, msg, True);
end;

procedure TncAiLlamaProvider.clear_pending_locked;
begin
    m_has_pending := False;
    m_pending_signature := '';
    m_pending_tick := 0;
end;

function TncAiLlamaProvider.effective_timeout_ms(const request_timeout_ms: Integer): Integer;
begin
    Result := request_timeout_ms;
    if Result <= 0 then
    begin
        Result := c_default_ai_timeout_ms;
    end;
end;

function TncAiLlamaProvider.build_request_signature(const request: TncAiRequest): string;
begin
    Result := nc_ai_build_request_signature(request);
end;

procedure TncAiLlamaProvider.schedule_request(const request: TncAiRequest; const signature: string);
var
    should_abort: Boolean;
    should_exit: Boolean;
    readable_signature: string;
    readable_pending_signature: string;
    now_tick: UInt64;
begin
    should_abort := False;
    should_exit := False;
    readable_signature := StringReplace(signature, #1, '|', [rfReplaceAll]);
    m_lock.Acquire;
    try
        now_tick := GetTickCount64;
        if (m_last_failed_signature <> '') and SameText(m_last_failed_signature, signature) then
        begin
            if (m_last_failed_tick <> 0) and ((now_tick - m_last_failed_tick) >= UInt64(c_failed_retry_cooldown_ms)) then
            begin
                m_last_failed_signature := '';
                m_last_failed_tick := 0;
            end;
        end;

        if (m_last_failed_signature <> '') and SameText(m_last_failed_signature, signature) then
        begin
            // Suppress immediate retries for a known-bad signature.
            // Crucially, clear/abort any older pending request to avoid stale
            // generations (for example: pending "wenjia" running after current
            // input already became "wenjian").
            if m_has_pending then
            begin
                should_abort := True;
                clear_pending_locked;
            end;
            if (not SameText(m_last_suppressed_signature, signature)) or
                ((now_tick - m_last_suppressed_tick) >= UInt64(c_suppressed_log_interval_ms)) then
            begin
                log_debug('AI schedule suppressed recent-failure signature=' + readable_signature);
                m_last_suppressed_signature := signature;
                m_last_suppressed_tick := now_tick;
            end;
            should_exit := True;
        end
        else
        begin
            if m_has_pending and SameText(m_pending_signature, signature) then
            begin
                should_exit := True;
            end
            else
            begin
                m_last_suppressed_signature := '';
                m_last_suppressed_tick := 0;

                if m_has_pending then
                begin
                    // Replace the in-flight request with a newer one; abort current generation asap.
                    should_abort := True;
                    readable_pending_signature := StringReplace(m_pending_signature, #1, '|', [rfReplaceAll]);
                    log_debug('AI schedule replace old=' + readable_pending_signature + ' new=' + readable_signature);
                end
                else
                begin
                    log_debug('AI schedule new signature=' + readable_signature);
                end;

                m_pending_request := request;
                m_pending_signature := signature;
                Inc(m_pending_version);
                m_pending_tick := GetTickCount64;
                m_has_pending := True;
            end;
        end;
    finally
        m_lock.Release;
    end;

    if should_abort and (m_bridge <> nil) then
    begin
        m_bridge.request_abort;
    end;
    if should_exit then
    begin
        Exit;
    end;
end;

function TncAiLlamaProvider.try_get_cached_response(const signature: string; out response: TncAiResponse): Boolean;
begin
    response.success := False;
    SetLength(response.candidates, 0);

    m_lock.Acquire;
    try
        if m_cached_success and SameText(m_cached_signature, signature) and (Length(m_cached_candidates) > 0) then
        begin
            copy_candidate_list(m_cached_candidates, response.candidates);
            response.success := True;
            Result := True;
            Exit;
        end;
    finally
        m_lock.Release;
    end;

    Result := False;
end;

function TncAiLlamaProvider.try_get_stable_request(out request: TncAiRequest; out signature: string;
    out version: Int64): Boolean;
var
    elapsed_ms: UInt64;
begin
    Result := False;
    signature := '';
    version := 0;
    request.context.composition_text := '';
    request.context.left_context := '';
    request.max_suggestions := 0;
    request.timeout_ms := 0;

    m_lock.Acquire;
    try
        if not m_has_pending then
        begin
            Exit;
        end;

        elapsed_ms := GetTickCount64 - m_pending_tick;
        if elapsed_ms < UInt64(m_debounce_ms) then
        begin
            Exit;
        end;

        request := m_pending_request;
        signature := m_pending_signature;
        version := m_pending_version;
        Result := True;
    finally
        m_lock.Release;
    end;
end;

function TncAiLlamaProvider.is_current_version(const version: Int64): Boolean;
begin
    m_lock.Acquire;
    try
        Result := m_has_pending and (m_pending_version = version);
    finally
        m_lock.Release;
    end;
end;

procedure TncAiLlamaProvider.store_result(const signature: string; const candidates: TncCandidateList;
    const success: Boolean; const version: Int64; const error_text: string);
begin
    m_lock.Acquire;
    try
        if (not m_has_pending) or (version <> m_pending_version) then
        begin
            Exit;
        end;

        if success and (Length(candidates) > 0) then
        begin
            m_cached_signature := signature;
            copy_candidate_list(candidates, m_cached_candidates);
            m_cached_success := True;
            if SameText(m_last_failed_signature, signature) then
            begin
                m_last_failed_signature := '';
                m_last_failed_tick := 0;
            end;
        end
        else
        begin
            if SameText(m_cached_signature, signature) then
            begin
                m_cached_signature := '';
                SetLength(m_cached_candidates, 0);
                m_cached_success := False;
            end;
            if error_text <> '' then
            begin
                m_last_error := error_text;
            end;
            m_last_failed_signature := signature;
            m_last_failed_tick := GetTickCount64;
        end;

        clear_pending_locked;
    finally
        m_lock.Release;
    end;
end;

procedure TncAiLlamaProvider.run_worker_once;
var
    request: TncAiRequest;
    signature: string;
    version: Int64;
    generated_text: string;
    error_text: string;
    prompt: string;
    max_suggestions: Integer;
    generation_tokens: Integer;
    timeout_ms: Integer;
    composition_len: Integer;
    model_size_bytes: Int64;
    model_path_lower: string;
    is_gpt_oss: Boolean;
    retry_prompt: string;
    retry_generated_text: string;
    retry_error_text: string;
    retry_tokens: Integer;
    retry_timeout_ms: Integer;
    candidates: TncCandidateList;
    success: Boolean;
    saved_mask: TFPUExceptionMask;
    raw_tail: string;
    request_pinyin: string;
    use_left_context: Boolean;
    request_signature_log: string;
    needs_retry_due_length: Boolean;
begin
    if not m_ready then
    begin
        Exit;
    end;

    if not try_get_stable_request(request, signature, version) then
    begin
        Exit;
    end;

    if not is_current_version(version) then
    begin
        Exit;
    end;

    max_suggestions := nc_ai_clamp_int(request.max_suggestions, 1, 15);
    generation_tokens := nc_ai_get_generation_tokens(max_suggestions);
    composition_len := Length(nc_ai_sanitize_single_line(request.context.composition_text));
    model_size_bytes := 0;
    if not try_get_file_size_bytes(m_bridge.loaded_model_path, model_size_bytes) then
    begin
        model_size_bytes := 0;
    end;
    model_path_lower := LowerCase(m_bridge.loaded_model_path);
    is_gpt_oss := Pos('gpt-oss', model_path_lower) > 0;
    if composition_len >= 10 then
    begin
        generation_tokens := Max(generation_tokens, 128);
    end;
    if composition_len >= 14 then
    begin
        generation_tokens := Max(generation_tokens, 160);
    end;
    if is_gpt_oss and (composition_len >= 10) then
    begin
        generation_tokens := Max(generation_tokens, 160);
    end;
    if is_gpt_oss and (composition_len >= 14) then
    begin
        generation_tokens := Max(generation_tokens, 192);
    end;
    generation_tokens := nc_ai_clamp_int(generation_tokens, 16, 192);
    timeout_ms := effective_timeout_ms(request.timeout_ms);
    if is_gpt_oss then
    begin
        timeout_ms := Max(timeout_ms, 1800);
    end;
    if composition_len >= 10 then
    begin
        timeout_ms := Max(timeout_ms, 2400);
    end;
    if composition_len >= 14 then
    begin
        timeout_ms := Max(timeout_ms, 3200);
    end;
    if is_gpt_oss and (composition_len >= 10) then
    begin
        timeout_ms := Max(timeout_ms, 3000);
    end;
    if is_gpt_oss and (composition_len >= 14) then
    begin
        timeout_ms := Max(timeout_ms, 3800);
    end;
    if model_size_bytes >= c_large_model_size_threshold then
    begin
        timeout_ms := Max(timeout_ms, 5200);
    end;
    if model_size_bytes >= c_huge_model_size_threshold then
    begin
        timeout_ms := Max(timeout_ms, 7000);
    end;
    request_pinyin := nc_ai_sanitize_single_line(request.context.composition_text);
    request_signature_log := StringReplace(signature, #1, '|', [rfReplaceAll]);
    use_left_context := nc_ai_should_use_left_context(request_pinyin) and
        (nc_ai_sanitize_single_line(request.context.left_context) <> '');
    log_debug(Format('AI request signature=%s pinyin=%s len=%d left_ctx_used=%d temp=%.1f',
        [request_signature_log, request_pinyin, Length(request_pinyin), Ord(use_left_context), c_ai_temperature]));

    prompt := nc_ai_build_prompt(request);
    success := False;
    generated_text := '';
    error_text := '';
    SetLength(candidates, 0);
    needs_retry_due_length := False;

    saved_mask := GetExceptionMask;
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
    try
        try
            if m_bridge.generate_text(prompt, generation_tokens, timeout_ms, c_ai_temperature, generated_text,
                error_text) then
            begin
                nc_ai_parse_generated_candidates(generated_text, request.context.composition_text, max_suggestions,
                    candidates);
                success := Length(candidates) > 0;
                if success and (not nc_ai_has_syllable_length_match(request.context.composition_text, candidates)) then
                begin
                    success := False;
                    needs_retry_due_length := True;
                    SetLength(candidates, 0);
                end;
                if not success then
                begin
                    // Retry once when model output is likely invalid:
                    // - non-Chinese text (for example pinyin-only lines)
                    // - Chinese output that cannot match pinyin syllable length
                    if (generated_text <> '') and ((not nc_ai_contains_cjk(generated_text)) or needs_retry_due_length) then
                    begin
                        if needs_retry_due_length then
                        begin
                            log_debug('AI retry triggered (syllable-length mismatch), signature=' + request_signature_log);
                        end
                        else
                        begin
                            log_debug('AI retry triggered (non-cjk output), signature=' + request_signature_log);
                        end;
                        retry_prompt := nc_ai_build_retry_prompt(request);
                        retry_tokens := Max(generation_tokens, 160);
                        retry_timeout_ms := Max(timeout_ms, 2600);
                        retry_generated_text := '';
                        retry_error_text := '';
                        if m_bridge.generate_text(retry_prompt, retry_tokens, retry_timeout_ms, c_ai_temperature,
                            retry_generated_text, retry_error_text) then
                        begin
                            // Keep the last successful decode output for logging/diagnosis.
                            generated_text := retry_generated_text;
                            nc_ai_parse_generated_candidates(retry_generated_text, request.context.composition_text,
                                max_suggestions, candidates);
                            success := (Length(candidates) > 0) and
                                nc_ai_has_syllable_length_match(request.context.composition_text, candidates);
                            if success then
                            begin
                                // generated_text already updated above
                            end
                            else
                            begin
                                error_text := 'llama output has no usable candidates';
                            end;
                        end
                        else
                        begin
                            error_text := retry_error_text;
                        end;
                    end
                    else
                    begin
                        error_text := 'llama output has no usable candidates';
                    end;
                end;
            end;
        except
            on e: Exception do
            begin
                error_text := Format('AI generate exception %s: %s', [e.ClassName, e.Message]);
            end;
        end;
    finally
        SetExceptionMask(saved_mask);
    end;

    if not is_current_version(version) then
    begin
        log_debug('AI generation discarded: stale request');
        Exit;
    end;

    if not success then
    begin
        if generated_text <> '' then
        begin
            raw_tail := StringReplace(generated_text, #13, '', [rfReplaceAll]);
            raw_tail := StringReplace(raw_tail, #10, '\n', [rfReplaceAll]);
            raw_tail := nc_ai_tail_text(raw_tail, 300);
            log_warn('AI raw output tail: ' + raw_tail);
        end;
        log_warn('AI generation failed: ' + error_text);
    end
    else
    begin
        log_debug(Format('AI generation success signature=%s count=%d top=%s',
            [request_signature_log, Length(candidates), nc_ai_tail_text(candidates[0].text, 64)]));
        raw_tail := StringReplace(generated_text, #13, '', [rfReplaceAll]);
        raw_tail := StringReplace(raw_tail, #10, '\n', [rfReplaceAll]);
        raw_tail := nc_ai_tail_text(raw_tail, 180);
        log_debug('AI raw output tail: ' + raw_tail);
    end;

    store_result(signature, candidates, success, version, error_text);
end;

function TncAiLlamaProvider.get_last_error: string;
begin
    m_lock.Acquire;
    try
        Result := m_last_error;
    finally
        m_lock.Release;
    end;
end;

function TncAiLlamaProvider.request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean;
var
    signature: string;
    should_abort: Boolean;
    readable_signature: string;
    readable_pending_signature: string;
begin
    response.success := False;
    SetLength(response.candidates, 0);
    Result := False;
    should_abort := False;

    if not m_ready then
    begin
        Exit;
    end;

    if request.context.composition_text = '' then
    begin
        m_lock.Acquire;
        try
            should_abort := m_has_pending;
            clear_pending_locked;
            m_last_failed_signature := '';
            m_last_failed_tick := 0;
            m_last_suppressed_signature := '';
            m_last_suppressed_tick := 0;
        finally
            m_lock.Release;
        end;
        if should_abort and (m_bridge <> nil) then
        begin
            m_bridge.request_abort;
        end;
        Exit;
    end;

    signature := build_request_signature(request);
    if try_get_cached_response(signature, response) then
    begin
        // Cache hit can happen while an older request is still pending.
        // Clear stale pending work to avoid late, mismatched generations
        // (for example: pending "wenjia" after current input is "wenjian").
        m_lock.Acquire;
        try
            if m_has_pending and (not SameText(m_pending_signature, signature)) then
            begin
                should_abort := True;
                readable_signature := StringReplace(signature, #1, '|', [rfReplaceAll]);
                readable_pending_signature := StringReplace(m_pending_signature, #1, '|', [rfReplaceAll]);
                log_debug('AI cache hit clear stale pending old=' + readable_pending_signature + ' keep=' +
                    readable_signature);
                clear_pending_locked;
            end;
        finally
            m_lock.Release;
        end;
        if should_abort and (m_bridge <> nil) then
        begin
            m_bridge.request_abort;
        end;
        Result := True;
        Exit;
    end;

    schedule_request(request, signature);
end;

end.
