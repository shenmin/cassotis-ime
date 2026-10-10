unit nc_pinyin_input_diagnostics;

interface

uses
    nc_types;

type
    TncPinyinDiagnosticKind = (pdk_invalid, pdk_repeated_vowel);
    TncPinyinDiagnosticSpan = record
        start_index: Integer; // Zero-based offsets in the original preedit text.
        length: Integer;
        kind: TncPinyinDiagnosticKind;
    end;
    TncPinyinDiagnosticSpans = TArray<TncPinyinDiagnosticSpan>;

    TncPinyinInputDiagnostics = class
    private
        m_cached: Boolean;
        m_quick_input_active: Boolean;
        m_text: string;
        m_scheme: TncPinyinInputScheme;
        m_spans: TncPinyinDiagnosticSpans;
    public
        function check(const raw_text: string;
            const scheme: TncPinyinInputScheme;
            const quick_input_active: Boolean = False): TncPinyinDiagnosticSpans;
    end;

function nc_check_pinyin_input(const raw_text: string;
    const scheme: TncPinyinInputScheme;
    const quick_input_active: Boolean = False): TncPinyinDiagnosticSpans;

implementation

uses
    System.SysUtils,
    System.Math,
    nc_shuangpin_decoder;

const
    c_max_diagnostic_length = 1024;
    c_repeated_vowel_length = 3;
    c_initial_letters = 'bpmfdtnlgkhjqxrzcsyw';

type
    TncSpellingNode = record
        next: array[0..25] of Integer;
        complete: Boolean;
    end;
    TncSpellingEdge = record
        finish: Integer;
        complete: Boolean;
    end;
    TncSpellingEdges = TArray<TArray<TncSpellingEdge>>;

var
    g_spelling: TArray<TncSpellingNode>;
    g_double_codes: array[TncPinyinInputScheme, 0..26, 0..26] of Boolean;

function key_index(const value: Char): Integer;
begin
    if (value >= 'a') and (value <= 'z') then
        Result := Ord(value) - Ord('a')
    else if value = ';' then
        Result := 26
    else
        Result := -1;
end;

procedure add_spelling(const value: string);
var
    node, key, idx, next_node: Integer;
begin
    node := 0;
    for idx := 1 to Length(value) do
    begin
        key := key_index(value[idx]);
        if (key < 0) or (key > 25) then Exit;
        next_node := g_spelling[node].next[key];
        if next_node = 0 then
        begin
            next_node := Length(g_spelling);
            SetLength(g_spelling, next_node + 1);
            g_spelling[node].next[key] := next_node;
        end;
        node := next_node;
    end;
    g_spelling[node].complete := True;
end;

procedure initialize_spellings;
var
    syllables, codes: TArray<string>;
    syllable, code: string;
    scheme: TncPinyinInputScheme;
    first, last: Integer;
begin
    SetLength(g_spelling, 1);
    syllables := nc_get_shuangpin_syllables;
    for syllable in syllables do
    begin
        add_spelling(syllable);
        // Same length-preserving aliases as the engine; nu and nv stay distinct.
        if (syllable = 'lve') or (syllable = 'nve') then
            add_spelling(syllable[1] + 'ue');
        if (Length(syllable) >= 2) and CharInSet(syllable[1], ['j', 'q', 'x']) and
            (syllable[2] = 'u') then
            add_spelling(syllable[1] + 'v' + Copy(syllable, 3, MaxInt));
        for scheme := pis_microsoft_shuangpin to pis_pinyinjiajia_shuangpin do
        begin
            codes := nc_get_shuangpin_codes(scheme, syllable);
            for code in codes do
                if Length(code) = 2 then
                begin
                    first := key_index(code[1]);
                    last := key_index(code[2]);
                    if (first >= 0) and (last >= 0) then
                        g_double_codes[scheme, first, last] := True;
                end;
        end;
    end;
end;

procedure add_edge(var edges: TncSpellingEdges; const start, finish: Integer;
    const complete: Boolean);
var
    idx: Integer;
begin
    for idx := 0 to High(edges[start]) do
        if edges[start][idx].finish = finish then
        begin
            edges[start][idx].complete := edges[start][idx].complete or complete;
            Exit;
        end;
    idx := Length(edges[start]);
    SetLength(edges[start], idx + 1);
    edges[start][idx].finish := finish;
    edges[start][idx].complete := complete;
end;

procedure check_full_pinyin(const text: string; var marks: TArray<Integer>);
var
    edges: TncSpellingEdges;
    forward_cost, backward_cost: TArray<Integer>;
    covered: TArray<Boolean>;
    edge: TncSpellingEdge;
    idx, finish, node, key, covered_idx, count, best_cost: Integer;
    segment_start, segment_end, initial_end, run_start, run_end,
        protected_end, scan: Integer;
begin
    count := Length(text);
    SetLength(edges, count);
    for idx := 0 to count - 1 do
    begin
        if text[idx + 1] = '''' then
        begin
            add_edge(edges, idx, idx + 1, False);
            Continue;
        end;
        if Pos(text[idx + 1], c_initial_letters) > 0 then
            add_edge(edges, idx, idx + 1, False);
        if (idx + 1 < count) and CharInSet(text[idx + 1], ['z', 'c', 's']) and
            (text[idx + 2] = 'h') then
            add_edge(edges, idx, idx + 2, False);
        node := 0;
        finish := idx;
        while finish < count do
        begin
            key := key_index(text[finish + 1]);
            if (key < 0) or (key > 25) then Break;
            node := g_spelling[node].next[key];
            if node = 0 then Break;
            Inc(finish);
            if g_spelling[node].complete then
                add_edge(edges, idx, finish, True)
            else if finish = count then
                add_edge(edges, idx, finish, False);
        end;
    end;

    SetLength(forward_cost, count + 1);
    SetLength(backward_cost, count + 1);
    for idx := 1 to count do forward_cost[idx] := count + 1;
    for idx := 0 to count - 1 do
    begin
        forward_cost[idx + 1] := Min(forward_cost[idx + 1], forward_cost[idx] + 1);
        for edge in edges[idx] do
            forward_cost[edge.finish] := Min(forward_cost[edge.finish], forward_cost[idx]);
    end;
    for idx := count - 1 downto 0 do
    begin
        backward_cost[idx] := backward_cost[idx + 1] + 1;
        for edge in edges[idx] do
            backward_cost[idx] := Min(backward_cost[idx], backward_cost[edge.finish]);
    end;
    best_cost := forward_cost[count];
    if best_cost > 0 then
    begin
        SetLength(covered, count);
        // Do not blame a letter which another equally good segmentation explains.
        for idx := 0 to count - 1 do
            for edge in edges[idx] do
                if forward_cost[idx] + backward_cost[edge.finish] = best_cost then
                    for covered_idx := idx to edge.finish - 1 do covered[covered_idx] := True;
        for idx := 0 to count - 1 do
            if not covered[idx] then marks[idx] := Ord(pdk_invalid) + 1;
    end;

    segment_start := 0;
    while segment_start < count do
    begin
        segment_end := segment_start;
        while (segment_end < count) and (text[segment_end + 1] <> '''') do
            Inc(segment_end);
        initial_end := count + 1;
        for idx := segment_start to segment_end - 1 do
            if (forward_cost[idx] = 0) and
                (Pos(text[idx + 1], c_initial_letters) > 0) then
            begin
                // An abbreviated initial must not hide an accidental vowel run.
                initial_end := idx + 1;
                Break;
            end;
        run_start := segment_start;
        while run_start < segment_end do
        begin
            run_end := run_start + 1;
            while (run_end < segment_end) and
                (text[run_end + 1] = text[run_start + 1]) do Inc(run_end);
            if CharInSet(text[run_start + 1], ['a', 'e', 'o']) and
                (run_end - run_start >= c_repeated_vowel_length) and
                (initial_end <= run_start) then
            begin
                protected_end := run_start;
                // Preserve the vowel already belonging to hao/huo/etc.
                for scan := Max(segment_start, run_start - 5) to run_start - 1 do
                    if forward_cost[scan] = 0 then
                        for edge in edges[scan] do
                            if edge.complete and (edge.finish > run_start) then
                                protected_end := Max(protected_end, edge.finish);
                for idx := protected_end to run_end - 1 do
                    if marks[idx] = 0 then marks[idx] := Ord(pdk_repeated_vowel) + 1;
            end;
            run_start := run_end;
        end;
        segment_start := segment_end + 1;
    end;
end;

procedure check_double_pinyin(const text: string; const scheme: TncPinyinInputScheme;
    var marks: TArray<Integer>);
var
    idx, first, last: Integer;
begin
    idx := 0;
    while idx < Length(text) do
    begin
        if text[idx + 1] = '''' then
        begin
            Inc(idx);
            Continue;
        end;
        first := key_index(text[idx + 1]);
        if (idx + 1 < Length(text)) and (text[idx + 2] <> '''') then
        begin
            last := key_index(text[idx + 2]);
            if (first < 0) or (last < 0) or
                (not g_double_codes[scheme, first, last]) then
            begin
                marks[idx] := Ord(pdk_invalid) + 1;
                marks[idx + 1] := Ord(pdk_invalid) + 1;
            end;
            Inc(idx, 2);
        end
        else
        begin
            // A single alphabetic key is a pending initial, including before '.
            if (first < 0) or (first = 26) then marks[idx] := Ord(pdk_invalid) + 1;
            Inc(idx);
        end;
    end;
end;

function nc_check_pinyin_input(const raw_text: string;
    const scheme: TncPinyinInputScheme;
    const quick_input_active: Boolean): TncPinyinDiagnosticSpans;
var
    text: string;
    marks: TArray<Integer>;
    ch: Char;
    idx, finish, span_count: Integer;
begin
    Result := nil;
    if (raw_text = '') or (Length(raw_text) > c_max_diagnostic_length) then Exit;
    if quick_input_active then Exit;
    text := LowerCase(raw_text);
    if not nc_is_shuangpin_scheme(scheme) then
        text := StringReplace(text, #$00FC, 'v', [rfReplaceAll]);
    // Non-pinyin/literal input belongs to its own input mode, not this checker.
    for ch in text do
        if not CharInSet(ch, ['a'..'z', '''']) and
            not (nc_is_shuangpin_scheme(scheme) and (ch = ';')) then Exit;
    SetLength(marks, Length(text));
    if nc_is_shuangpin_scheme(scheme) then
        check_double_pinyin(text, scheme, marks)
    else
        check_full_pinyin(text, marks);
    idx := 0;
    while idx < Length(marks) do
    begin
        if marks[idx] = 0 then
        begin
            Inc(idx);
            Continue;
        end;
        finish := idx + 1;
        while (finish < Length(marks)) and (marks[finish] = marks[idx]) do Inc(finish);
        span_count := Length(Result);
        SetLength(Result, span_count + 1);
        Result[span_count].start_index := idx;
        Result[span_count].length := finish - idx;
        Result[span_count].kind := TncPinyinDiagnosticKind(marks[idx] - 1);
        idx := finish;
    end;
end;

function TncPinyinInputDiagnostics.check(const raw_text: string;
    const scheme: TncPinyinInputScheme;
    const quick_input_active: Boolean): TncPinyinDiagnosticSpans;
begin
    if (not m_cached) or (m_text <> raw_text) or (m_scheme <> scheme) or
        (m_quick_input_active <> quick_input_active) then
    begin
        m_spans := nc_check_pinyin_input(raw_text, scheme, quick_input_active);
        m_quick_input_active := quick_input_active;
        m_text := raw_text;
        m_scheme := scheme;
        m_cached := True;
    end;
    Result := Copy(m_spans);
end;

initialization
    initialize_spellings;

end.
