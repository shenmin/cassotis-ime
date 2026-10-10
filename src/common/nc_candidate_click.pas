unit nc_candidate_click;

interface

type
    // A click is a command for one rendered snapshot, never an interpretation
    // of the next keyboard event. The host serializes access with its lock.
    TncCandidateClick = record
    private
        m_serial, m_pending: Cardinal;
        m_generation, m_epoch, m_tick: UInt64;
        m_page, m_slot: Integer;
    public
        function queue(const generation, epoch, tick: UInt64;
            const page, slot: Integer): Cardinal;
        procedure cancel;
        function consume(const token: Cardinal; const generation, epoch, tick: UInt64;
            out page, slot: Integer): Boolean;
    end;

function nc_try_candidate_click_token(const value: UInt64; out token: Cardinal): Boolean;

implementation

function nc_try_candidate_click_token(const value: UInt64; out token: Cardinal): Boolean;
begin
    token := 0;
    Result := (value > 0) and (value <= High(Cardinal));
    if Result then token := Cardinal(value);
end;

function TncCandidateClick.queue(const generation, epoch, tick: UInt64;
    const page, slot: Integer): Cardinal;
begin
    if m_serial = High(Cardinal) then m_serial := 0;
    Inc(m_serial);
    m_pending := m_serial;
    m_generation := generation;
    m_epoch := epoch;
    m_tick := tick;
    m_page := page;
    m_slot := slot;
    Result := m_pending;
end;

procedure TncCandidateClick.cancel;
begin
    m_pending := 0;
end;

function TncCandidateClick.consume(const token: Cardinal;
    const generation, epoch, tick: UInt64; out page, slot: Integer): Boolean;
begin
    page := -1;
    slot := -1;
    Result := (token <> 0) and (token = m_pending) and
        (generation = m_generation) and (epoch = m_epoch) and
        (tick >= m_tick) and (tick - m_tick <= 2000);
    if token = m_pending then cancel;
    if Result then
    begin
        page := m_page;
        slot := m_slot;
    end;
end;

end.
