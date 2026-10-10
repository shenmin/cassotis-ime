unit nc_quick_input;

interface

uses
    System.SysUtils, nc_types;

type
    TncQuickInputKind = (qik_none, qik_symbols, qik_number, qik_date_alias,
        qik_symbol_prefix, qik_literal);
    TncQuickInputState = record
        // Retain the Shift entry while editing an invalid command back to valid.
        explicit_entry: Boolean;
        explicit_mode: Boolean;
        kind: TncQuickInputKind;
        generated: TncCandidateList;
        pending_commit: Boolean;
        procedure clear;
        function exclusive: Boolean;
    end;

const
    c_quick_input_max_length = 40;

function nc_quick_input_kind(const text: string; const scheme: TncPinyinInputScheme;
    const explicit_mode: Boolean = False): TncQuickInputKind;
function nc_quick_input_candidates(const text: string; const traditional: Boolean;
    const timestamp: TDateTime): TncCandidateList;
function nc_quick_number_key(const key_code: Word; const state: TncKeyState;
    out ch: Char): Boolean;
function nc_quick_input_command(const text: string): string;
function nc_quick_input_commit(const query: string; const candidate: TncCandidate;
    const previous: TncCandidateList; const traditional: Boolean;
    const timestamp: TDateTime): string;
procedure nc_insert_quick_candidates(var candidates: TncCandidateList;
    var sources: TArray<Integer>; const additions: TncCandidateList);

implementation

uses
    System.Math, Winapi.Windows;

procedure TncQuickInputState.clear;
begin
    Self := Default(TncQuickInputState);
end;

function TncQuickInputState.exclusive: Boolean;
begin
    Result := kind in [qik_symbols, qik_number, qik_symbol_prefix, qik_literal];
end;

function nc_quick_input_command(const text: string): string;
begin
    Result := LowerCase(text);
    if (Result <> '') and (Result[1] = 'u') then Delete(Result, 1, 1);
    if (Result <> '') and (Result[1] = 'u') then Delete(Result, 1, 1);
end;

function nc_quick_input_kind(const text: string; const scheme: TncPinyinInputScheme;
    const explicit_mode: Boolean): TncQuickInputKind;
var key: string; idx: Integer;
begin
    Result := qik_none;
    if (text = '') or ((scheme <> pis_full_pinyin) and not explicit_mode) then Exit;
    case text[1] of
        'u', 'U':
            begin
                key := nc_quick_input_command(text);
                if (key = '') or (key = 'fh') or (key = 'xh') or
                    (key = 'sx') or (key = 'jt') or (key = 'dw') or
                    (key = 'bd') or (key = 'rq') or (key = 'sj') or
                    (key = 'xq') then Exit(qik_symbols);
                if (scheme = pis_full_pinyin) and (Length(key) = 1) and
                    CharInSet(key[1], ['f', 'x', 's',
                    'j', 'd', 'b', 'r']) then Exit(qik_symbol_prefix);
            end;
        'i', 'I', 'v', 'V':
            begin
                // Partial numeric input must still accept digits, but ordinary
                // English abbreviations such as id/vip use the normal fallback.
                for idx := 2 to Length(text) do
                    if not CharInSet(text[idx], ['0'..'9', '.', '-']) then Exit;
                Exit(qik_number);
            end;
    end;
    if (scheme = pis_full_pinyin) and
        ((text = 'rq') or (text = 'sj') or (text = 'xq')) then
        Result := qik_date_alias;
end;

function nc_quick_number_key(const key_code: Word; const state: TncKeyState;
    out ch: Char): Boolean;
begin
    ch := #0;
    Result := False;
    if state.ctrl_down or state.alt_down or state.shift_down then Exit;
    case key_code of
        Ord('0')..Ord('9'): ch := Char(key_code);
        VK_NUMPAD0..VK_NUMPAD9: ch := Char(Ord('0') + key_code - VK_NUMPAD0);
        VK_OEM_PERIOD, VK_DECIMAL: ch := '.';
        VK_OEM_MINUS, VK_SUBTRACT: ch := '-';
    end;
    Result := ch <> #0;
end;

function chinese_integer(const digits: string; const financial,
    traditional: Boolean): string;
var
    alphabet, units: string;
    groups: array[0..3] of string;
    group, idx, n, power, group_index, group_count: Integer;
    pending_zero: Boolean;
    piece, significant: string;
begin
    alphabet := '零一二三四五六七八九';
    units := '十百千';
    groups[0] := ''; groups[1] := '万'; groups[2] := '亿'; groups[3] := '万';
    if traditional then
    begin
        groups[1] := '萬'; groups[2] := '億'; groups[3] := '兆';
    end;
    if financial then
    begin
        alphabet := '零壹贰叁肆伍陆柒捌玖';
        if traditional then alphabet := '零壹貳參肆伍陸柒捌玖';
        units := '拾佰仟';
    end;
    significant := digits;
    while (Length(significant) > 1) and (significant[1] = '0') do
        Delete(significant, 1, 1);
    if significant = '0' then Exit(alphabet[1]);
    Result := '';
    pending_zero := False;
    group_count := (Length(significant) + 3) div 4;
    for group_index := group_count - 1 downto 0 do
    begin
        idx := Length(significant) - group_index * 4;
        piece := Copy(significant, Max(1, idx - 3), Min(4, idx));
        group := StrToInt(piece);
        if group = 0 then
        begin
            // The upper two groups share one yi, even when its lower group is zero.
            if not traditional and (group_index = 2) and (group_count = 4) then
                Result := Result + groups[2];
            pending_zero := Result <> '';
            Continue;
        end;
        if (Result <> '') and (pending_zero or (group < 1000)) then
            Result := Result + alphabet[1];
        pending_zero := False;
        for idx := 1 to Length(piece) do
        begin
            n := Ord(piece[idx]) - Ord('0');
            power := Length(piece) - idx;
            if n = 0 then
            begin
                pending_zero := Result <> '';
                Continue;
            end;
            if pending_zero and (Result <> '') and (Result[Length(Result)] <> alphabet[1]) then
                Result := Result + alphabet[1];
            pending_zero := False;
            if not ((not financial) and (Result = '') and (n = 1) and (power = 1)) then
                Result := Result + alphabet[n + 1];
            if power > 0 then Result := Result + units[power];
        end;
        Result := Result + groups[group_index];
        pending_zero := False;
    end;
end;

function nc_quick_input_candidates(const text: string; const traditional: Boolean;
    const timestamp: TDateTime): TncCandidateList;
var
    key, body, integer_part, fraction, lower_text, upper_text, money,
        negative, upper_digits, lower_digits, decimal_point, digit_text: string;
    idx, dot, digit, jiao, fen: Integer;
    year, month, day: Word;
    all_zero, negative_input: Boolean;

    procedure add(const value: string);
    var item: TncCandidate; existing: TncCandidate;
    begin
        if value = '' then Exit;
        for existing in Result do
            if existing.text = value then Exit;
        item := Default(TncCandidate);
        item.text := value;
        item.source := cs_quick_input;
        Result := Result + [item];
    end;

    procedure symbols(const values: string);
    var value: string;
    begin
        for value in values.Split(['|']) do add(value);
    end;

begin
    Result := nil;
    if (text = '') or (Length(text) > c_quick_input_max_length) then Exit;
    key := nc_quick_input_command(text);
    if key = '' then
    begin
        for body in ['fh', 'xh', 'sx', 'jt', 'dw', 'bd', 'rq', 'sj', 'xq'] do
            add('u' + body);
        Result[0].comment := '特殊符号'; Result[1].comment := '数字序号';
        Result[2].comment := '数学符号'; Result[3].comment := '箭头';
        Result[4].comment := '单位'; Result[5].comment := '标点';
        Result[6].comment := '日期'; Result[7].comment := '时间';
        Result[8].comment := '星期';
        if traditional then
        begin
            Result[0].comment := '特殊符號'; Result[1].comment := '數字序號';
            Result[2].comment := '數學符號'; Result[3].comment := '箭頭';
            Result[4].comment := '單位'; Result[5].comment := '標點';
            Result[7].comment := '時間';
        end;
    end
    else if key = 'fh' then
        symbols('★|☆|●|○|◆|◇|■|□|▲|△|▼|▽|✓|✗|√|×|※|∞|©|®|™|…|§|¶|·|◎|⊙|⊕|⊗')
    else if key = 'xh' then
        symbols('①|②|③|④|⑤|⑥|⑦|⑧|⑨|⑩|⑪|⑫|⑬|⑭|⑮|⑯|⑰|⑱|⑲|⑳|一、|二、|三、|四、|五、|六、|七、|八、|九、|十、|Ⅰ|Ⅱ|Ⅲ|Ⅳ|Ⅴ|Ⅵ|Ⅶ|Ⅷ|Ⅸ|Ⅹ')
    else if key = 'sx' then
        symbols('±|×|÷|≠|≈|≡|≤|≥|∞|√|∑|∏|∫|∂|∆|∇|∈|∉|⊂|⊆|∪|∩|∅|∀|∃|∴|∵|∠|⊥|∥|°|π|²|³')
    else if key = 'jt' then
        symbols('←|→|↑|↓|↔|↕|↖|↗|↙|↘|⇐|⇒|⇔|⇑|⇓|↩|↪')
    else if key = 'dw' then
        symbols('℃|℉|°|‰|％|㎡|㎥|㎜|㎝|㎞|㎎|㎏|μm|mL|kWh|Ω|μ|￥|€|£|¢')
    else if key = 'bd' then
        symbols('，|。|、|；|：|？|！|“|”|‘|’|（|）|《|》|〈|〉|【|】|〔|〕|「|」|『|』|…|—|·')
    else if key = 'rq' then
    begin
        DecodeDate(timestamp, year, month, day);
        add(Format('%d年%d月%d日', [year, month, day]));
        add(FormatDateTime('yyyy-mm-dd', timestamp));
        add(FormatDateTime('yyyy"/"mm"/"dd', timestamp));
    end
    else if key = 'sj' then
    begin
        add(FormatDateTime('hh":"nn":"ss', timestamp));
        add(FormatDateTime('yyyy-mm-dd hh":"nn":"ss', timestamp));
    end
    else if key = 'xq' then
    begin
        key := '日一二三四五六';
        add('星期' + key[DayOfWeek(timestamp)]);
        if traditional then add('週' + key[DayOfWeek(timestamp)])
        else add('周' + key[DayOfWeek(timestamp)]);
    end
    else if CharInSet(text[1], ['i', 'I', 'v', 'V']) then
    begin
        body := Copy(text, 2, MaxInt);
        if body = '' then
        begin
            add(text);
            Result[0].comment := '输入数字；a/b/c/d 选词';
            if traditional then Result[0].comment := '輸入數字；a/b/c/d 選詞';
            Exit;
        end;
        negative_input := body[1] = '-';
        if negative_input then Delete(body, 1, 1);
        if body = '' then Exit;
        dot := 0;
        all_zero := True;
        for idx := 1 to Length(body) do
            if body[idx] = '.' then
            begin
                if dot <> 0 then Exit;
                dot := idx;
            end
            else
            begin
                if not CharInSet(body[idx], ['0'..'9']) then Exit;
                all_zero := all_zero and (body[idx] = '0');
            end;
        if dot = 0 then
        begin
            integer_part := body;
            fraction := '';
        end
        else
        begin
            if (dot = 1) or (dot = Length(body)) then Exit;
            integer_part := Copy(body, 1, dot - 1);
            fraction := Copy(body, dot + 1, MaxInt);
        end;
        // String arithmetic: never round money or pass it through floating point.
        if (Length(integer_part) > 16) or (Length(fraction) > 8) then Exit;
        negative := '';
        if negative_input and not all_zero then
            if traditional then negative := '負' else negative := '负';
        lower_digits := '零一二三四五六七八九';
        upper_digits := '零壹贰叁肆伍陆柒捌玖';
        decimal_point := '点';
        if traditional then
        begin
            upper_digits := '零壹貳參肆伍陸柒捌玖';
            decimal_point := '點';
        end;
        lower_text := negative + chinese_integer(integer_part, False, traditional);
        upper_text := negative + chinese_integer(integer_part, True, traditional);
        money := upper_text + '元';
        if fraction <> '' then
        begin
            lower_text := lower_text + decimal_point;
            upper_text := upper_text + decimal_point;
            for idx := 1 to Length(fraction) do
            begin
                digit := Ord(fraction[idx]) - Ord('0');
                lower_text := lower_text + lower_digits[digit + 1];
                upper_text := upper_text + upper_digits[digit + 1];
            end;
        end;
        add(lower_text);
        add(upper_text);
        if Length(fraction) <= 2 then
        begin
            jiao := 0; fen := 0;
            if Length(fraction) >= 1 then jiao := Ord(fraction[1]) - Ord('0');
            if Length(fraction) = 2 then fen := Ord(fraction[2]) - Ord('0');
            if (jiao = 0) and (fen = 0) then money := money + '整'
            else
            begin
                if chinese_integer(integer_part, True, traditional) = '零' then
                    money := negative;
                if jiao > 0 then money := money + upper_digits[jiao + 1] + '角'
                else if (money <> '') and (money <> negative) then money := money + '零';
                if fen > 0 then money := money + upper_digits[fen + 1] + '分'
                else money := money + '整';
            end;
            add(money);
        end;
        if fraction = '' then
        begin
            digit_text := negative;
            lower_digits := '〇一二三四五六七八九';
            for idx := 1 to Length(integer_part) do
                digit_text := digit_text + lower_digits[Ord(integer_part[idx]) - Ord('0') + 1];
            add(digit_text);
        end;
    end;
end;

function nc_quick_input_commit(const query: string; const candidate: TncCandidate;
    const previous: TncCandidateList; const traditional: Boolean;
    const timestamp: TDateTime): string;
var key: string; idx: Integer; refreshed: TncCandidateList;
begin
    Result := candidate.text;
    if candidate.source <> cs_quick_input then Exit;
    key := nc_quick_input_command(query);
    if (key <> 'rq') and (key <> 'sj') and (key <> 'xq') then Exit;
    refreshed := nc_quick_input_candidates(query, traditional, timestamp);
    for idx := 0 to Min(High(previous), High(refreshed)) do
        if previous[idx].text = candidate.text then Exit(refreshed[idx].text);
end;

procedure nc_insert_quick_candidates(var candidates: TncCandidateList;
    var sources: TArray<Integer>; const additions: TncCandidateList);
var idx, at: Integer;
begin
    if Length(additions) = 0 then Exit;
    for idx := 0 to High(candidates) do
        if candidates[idx].source = cs_quick_input then Exit;
    at := Min(2, Length(candidates));
    Insert(additions, candidates, at);
    for idx := 0 to High(additions) do Insert(-1, sources, at);
end;

end.
