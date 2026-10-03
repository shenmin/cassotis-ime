unit nc_local_completion_host;

{ Tab continuation of long input, off the keystroke path. The engine prepares a
  request: the decoded top1/top2 with its tail words (completing the word cut
  by the input end) and next words. A worker thread weighs them with the shared
  character LM, which also proposes its own next characters
  (nc_char_lm_choose_continuation), and hands an accepted continuation back on
  the caller's thread. Without an LM there is nothing to weigh and no result. }

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
        request: TncLongNeuralCompletionRequest;
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
    private
        m_lock: TCriticalSection;
        m_wakeup: TEvent;
        m_worker: TncLocalCompletionWorker;
        m_pending_task: TncLocalCompletionTask;
        m_has_pending_task: Boolean;
        m_result_event: TncLocalCompletionResultEvent;
        m_finished_event: TncLocalCompletionFinishedEvent;
        m_result_timeout_ms: UInt64;
        m_char_lm: IncCharLm;
        procedure worker_execute;
        function pop_task(out task: TncLocalCompletionTask): Boolean;
        function run_task(const task: TncLocalCompletionTask;
            out completion_result: TncLongNeuralCompletionResult): Boolean;
        procedure queue_finished(const task: TncLocalCompletionTask;
            const accepted: Boolean;
            const completion_result: TncLongNeuralCompletionResult);
        procedure deliver_finished(const task: TncLocalCompletionTask;
            const accepted: Boolean;
            const completion_result: TncLongNeuralCompletionResult);
    public
        { finished_event also sees abstentions (benchmark bridges); a
          deterministic benchmark never drops a late result. }
        constructor create(const result_event: TncLocalCompletionResultEvent;
            const finished_event: TncLocalCompletionFinishedEvent = nil;
            const deterministic_benchmark: Boolean = False);
        destructor Destroy; override;
        procedure enqueue(const task: TncLocalCompletionTask);
        { Pass TncCharLmHost.background_view; nil turns Tab continuation off. }
        procedure set_char_lm(const model: IncCharLm);
    end;

implementation

uses
    nc_pinyin_parser;

const
    // A later result is dropped. The session also drops results for an input
    // that has moved on, so this only bounds how late a hint may appear: room
    // for a loaded machine while still ahead of a typical next keystroke.
    c_result_timeout_ms = 80;

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

constructor TncLocalCompletionHost.create(
    const result_event: TncLocalCompletionResultEvent;
    const finished_event: TncLocalCompletionFinishedEvent;
    const deterministic_benchmark: Boolean);
begin
    inherited create;
    m_lock := TCriticalSection.Create;
    m_wakeup := TEvent.Create(nil, False, False, '');
    m_pending_task := Default(TncLocalCompletionTask);
    m_has_pending_task := False;
    m_result_event := result_event;
    m_finished_event := finished_event;
    if deterministic_benchmark then
        m_result_timeout_ms := 0
    else
        m_result_timeout_ms := c_result_timeout_ms;
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
    m_wakeup.Free;
    m_wakeup := nil;
    m_lock.Free;
    m_lock := nil;
    inherited Destroy;
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

function TncLocalCompletionHost.run_task(const task: TncLocalCompletionTask;
    out completion_result: TncLongNeuralCompletionResult): Boolean;
var
    started_at: UInt64;
    char_lm: IncCharLm;
    candidates: TArray<TncCharLmContinuation>;
    sources: TArray<Integer>;
    item, chosen: TncCharLmContinuation;
    base, next_char: string;
    idx, best: Integer;
    probability: Double;
begin
    Result := False;
    completion_result := Default(TncLongNeuralCompletionResult);
    m_lock.Acquire;
    try
        char_lm := m_char_lm;
    finally
        m_lock.Release;
    end;
    if char_lm = nil then
        Exit;
    started_at := GetTickCount64;
    // The engine's tail and next words stay on the result, so reports see
    // them and the chosen one can be returned with its reading.
    completion_result.candidates := Copy(task.request.tail_candidates);
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
        item.tail_rank := completion_result.candidates[idx].tail_rank;
        item.exact_reread := tail_reread_is_exact(task.request.query_syllables,
            completion_result.candidates[idx].suffix_pinyin_path,
            item.suffix_text, item.replace_units);
        candidates := candidates + [item];
        sources := sources + [idx];
    end;
    if ((Length(candidates) = 0) and (task.request.top1_text = '')) or
        not nc_char_lm_choose_continuation(char_lm, task.request.context_text,
        candidates, task.request.phonetic_only,
        [task.request.top1_text, task.request.top2_text], chosen, best, probability) then
        Exit;
    completion_result.confidence := probability;
    if probability < c_char_lm_tab_min_probability then
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
    else
    begin
        idx := sources[best];
        completion_result.suffix_text := completion_result.candidates[idx].suffix_text;
        completion_result.suffix_pinyin_path := completion_result.candidates[idx].suffix_pinyin_path;
        completion_result.suffix_path := completion_result.candidates[idx].suffix_path;
        completion_result.base_rank := completion_result.candidates[idx].base_rank;
        completion_result.replace_units := completion_result.candidates[idx].replace_units;
    end;
    // The LM's confident continuation follows, so that a word is not cut after
    // its first character; the engine reads it from the dictionary.
    if chosen.lm_next then
        completion_result.extension := nc_char_lm_extend_continuation(char_lm,
            task.request.context_text, chosen.base_text + chosen.suffix_text,
            c_char_lm_tab_extend_lm_next_probability)
    else
        completion_result.extension := nc_char_lm_extend_continuation(char_lm,
            task.request.context_text, chosen.base_text + chosen.suffix_text,
            c_char_lm_tab_extend_word_probability);
    Result := (m_result_timeout_ms = 0) or
        (GetTickCount64 - started_at <= m_result_timeout_ms);
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
    accepted: Boolean;
begin
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
        accepted := run_task(task, completion_result);
        // Production only needs accepted results. The optional finished event
        // lets synchronous benchmark bridges observe abstentions without
        // adding no-op main-thread callbacks to the normal Host path.
        if accepted or Assigned(m_finished_event) then
        begin
            queue_finished(task, accepted, completion_result);
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
        m_pending_task := task;
        m_has_pending_task := True;
    finally
        m_lock.Release;
    end;
    m_wakeup.SetEvent;
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

end.
