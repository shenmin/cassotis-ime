unit nc_one_key_rerank_host;

{ Runs the LM one-key completion rerank off the keystroke path. The engine
  shows its lexical choice at once (the incumbent); this worker scores the
  request with the shared LM (background view, yielding to engine calls) and
  hands a different choice back on the main thread, where the session applies
  it only while the input and the visible completion are unchanged. }

interface

uses System.SysUtils, System.Classes, System.SyncObjs, nc_char_lm, nc_engine_intf;

type
    TncOneKeyRerankTask = record
        session_id: string;
        session_instance_id: UInt64;
        candidate_generation: UInt64;
        request: TncOneKeyRerankRequest;
    end;

    TncOneKeyRerankResultEvent = reference to procedure(const task: TncOneKeyRerankTask;
        const chosen: Integer);

    TncOneKeyRerankHost = class
    private
        m_lock: TCriticalSection;
        m_wakeup: TEvent;
        m_worker: TThread;
        m_pending: TncOneKeyRerankTask;
        m_has_pending: Boolean;
        m_stopping: Boolean;
        m_char_lm: IncCharLm;
        m_result_event: TncOneKeyRerankResultEvent;
        procedure execute;
        function pop(out task: TncOneKeyRerankTask; out model: IncCharLm): Boolean;
        function stopping: Boolean;
        procedure deliver(const task: TncOneKeyRerankTask; const chosen: Integer);
    public
        constructor create(const result_event: TncOneKeyRerankResultEvent);
        destructor Destroy; override;
        procedure set_char_lm(const model: IncCharLm);
        { Keeps only the latest task: an older one is stale by construction. }
        procedure enqueue(const task: TncOneKeyRerankTask);
    end;

implementation

constructor TncOneKeyRerankHost.create(const result_event: TncOneKeyRerankResultEvent);
begin
    inherited Create;
    m_lock := TCriticalSection.Create;
    m_wakeup := TEvent.Create(nil, False, False, '');
    m_result_event := result_event;
    m_worker := TThread.CreateAnonymousThread(execute);
    m_worker.FreeOnTerminate := False;
    m_worker.Priority := tpLower;
    m_worker.Start;
end;

destructor TncOneKeyRerankHost.Destroy;
begin
    m_lock.Acquire;
    try
        m_stopping := True;
        m_char_lm := nil;
        m_has_pending := False;
    finally
        m_lock.Release;
    end;
    m_wakeup.SetEvent;
    if m_worker <> nil then
    begin
        m_worker.WaitFor;
        // Results queued to the main thread must not outlive this object.
        TThread.RemoveQueuedEvents(m_worker);
        m_worker.Free;
    end;
    m_wakeup.Free;
    m_lock.Free;
    inherited;
end;

procedure TncOneKeyRerankHost.set_char_lm(const model: IncCharLm);
begin
    m_lock.Acquire;
    try
        m_char_lm := model;
    finally
        m_lock.Release;
    end;
end;

procedure TncOneKeyRerankHost.enqueue(const task: TncOneKeyRerankTask);
begin
    if (task.session_id = '') or (Length(task.request.candidates) < 2) then
        Exit;
    m_lock.Acquire;
    try
        if m_stopping then
            Exit;
        m_pending := task;
        m_has_pending := True;
    finally
        m_lock.Release;
    end;
    m_wakeup.SetEvent;
end;

function TncOneKeyRerankHost.pop(out task: TncOneKeyRerankTask; out model: IncCharLm): Boolean;
begin
    task := Default(TncOneKeyRerankTask);
    model := nil;
    m_lock.Acquire;
    try
        Result := m_has_pending and not m_stopping;
        if Result then
        begin
            task := m_pending;
            model := m_char_lm;
            m_pending := Default(TncOneKeyRerankTask);
            m_has_pending := False;
        end;
    finally
        m_lock.Release;
    end;
end;

function TncOneKeyRerankHost.stopping: Boolean;
begin
    m_lock.Acquire;
    try
        Result := m_stopping;
    finally
        m_lock.Release;
    end;
end;

procedure TncOneKeyRerankHost.deliver(const task: TncOneKeyRerankTask; const chosen: Integer);
begin
    // A separate frame per result: the closure captures these parameters.
    TThread.Queue(TThread.Current,
        procedure
        begin
            if Assigned(m_result_event) then
                m_result_event(task, chosen);
        end);
end;

procedure TncOneKeyRerankHost.execute;
var
    task: TncOneKeyRerankTask;
    model: IncCharLm;
    chosen: Integer;
begin
    while not stopping do
    begin
        m_wakeup.WaitFor(INFINITE);
        while pop(task, model) do
        begin
            if (model <> nil) and nc_char_lm_choose_completion(model, task.request.context,
                task.request.candidates, task.request.incumbent, task.request.typed_units,
                chosen) and (chosen <> task.request.incumbent) then
                deliver(task, chosen);
        end;
        model := nil;
    end;
end;

end.
