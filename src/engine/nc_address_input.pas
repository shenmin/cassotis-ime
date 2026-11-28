unit nc_address_input;

// An address typed in Chinese mode (issue #39): an e-mail address or a URL
// kept as typed while it is being written. Only a key that cannot begin
// Chinese text starts one: @ after letters, . after www, : after http, https,
// ftp or mailto. A period after an English word does not, since a Chinese
// sentence ends so after one as often as not. The input also goes on with an
// address the document holds before it (123456@ typed with the digits in the
// document, then gmail), which the engine reads from the text before the
// caret.

interface

uses
    System.SysUtils;

const
    c_address_input_max_length = 128;
    // Behind the address as typed, at most this many completions.
    c_address_input_max_completions = 8;

// Whether the key's character typed after the composition's keys begins an
// address.
function nc_address_input_begins(const keys: string; const ch: Char): Boolean;
// Whether a composition's text is an address being typed.
function nc_is_address_input(const text: string): Boolean;
// Whether the character goes into an address being typed.
function nc_is_address_char(const ch: Char): Boolean;
// Completions of an address being typed: common mail domains after @, common
// suffixes after a dot of a host name. The address itself is not among them.
function nc_address_input_completions(const text: string): TArray<string>;
// The address at the end of the text before the input that the input goes on
// with: a local part, its @ and as much of the domain as ends at a dot
// (123456@, zhangsan@163.). An @ with no local part before it (after a space,
// a Chinese character or at the start: a mention) is none, and so is a domain
// that does not end at its @ or a dot (zhangsan@qq.com with Chinese typed after it).
function nc_address_before_input(const left_text: string): string;
// Whether a composition's text goes on with such an address: the characters
// of addresses, and no @ of its own.
function nc_is_address_continuation(const text: string): Boolean;
// Completions of the text typed after such an address, as the text the input
// commits (gmail.com for gm after 123456@).
function nc_address_completions_after(const before, text: string): TArray<string>;

implementation

const
    c_address_heads: array[0..4] of string = ('www.', 'http:', 'https:', 'ftp:', 'mailto:');
    // The domains of the mail services most used in China first.
    c_mail_domains: array[0..13] of string = ('qq.com', '163.com', '126.com',
        'gmail.com', 'outlook.com', 'foxmail.com', 'sina.com', 'hotmail.com',
        'yeah.net', '139.com', 'aliyun.com', 'icloud.com', 'sohu.com', 'yahoo.com');
    c_host_suffixes: array[0..6] of string = ('com', 'cn', 'net', 'org', 'com.cn',
        'edu.cn', 'gov.cn');
    // A label that is itself a suffix takes only the country after it
    // (com.cn, edu.cn).
    c_second_level_labels: array[0..4] of string = ('com', 'net', 'org', 'edu', 'gov');

function is_ascii_letter(const ch: Char): Boolean;
begin
    Result := ((ch >= 'a') and (ch <= 'z')) or ((ch >= 'A') and (ch <= 'Z'));
end;

function nc_is_address_char(const ch: Char): Boolean;
begin
    Result := is_ascii_letter(ch) or ((ch >= '0') and (ch <= '9')) or
        CharInSet(ch, ['.', '@', '-', '_', '/', ':', '?', '=', '&', '%', '#', '+', '~']);
end;

function letters_only(const text: string): Boolean;
var
    ch: Char;
begin
    Result := text <> '';
    for ch in text do
        if not is_ascii_letter(ch) then
            Exit(False);
end;

function nc_address_input_begins(const keys: string; const ch: Char): Boolean;
var
    key: string;
begin
    Result := False;
    if not letters_only(keys) then
        Exit;
    key := LowerCase(keys);
    case ch of
        '@':
            Result := True;
        '.':
            Result := key = 'www';
        ':':
            Result := (key = 'http') or (key = 'https') or (key = 'ftp') or (key = 'mailto');
    end;
end;

function nc_is_address_input(const text: string): Boolean;
var
    ch: Char;
    lower_text: string;
    head: string;
begin
    Result := False;
    if (text = '') or (Length(text) > c_address_input_max_length) then
        Exit;
    for ch in text do
        if not nc_is_address_char(ch) then
            Exit;
    // Letters, then @: what nc_address_input_begins starts.
    if (Pos('@', text) > 1) and letters_only(Copy(text, 1, Pos('@', text) - 1)) then
        Exit(True);
    lower_text := LowerCase(text);
    for head in c_address_heads do
        if lower_text.StartsWith(head) then
            Exit(True);
end;

function in_list(const value: string; const list: array of string): Boolean;
var
    item: string;
begin
    Result := False;
    for item in list do
        if item = value then
            Exit(True);
end;

// The host name's suffixes that go on from its last label.
procedure add_host_suffixes(const text: string; const host_start: Integer;
    var completions: TArray<string>);
var
    host, rest, last_label, previous_label, base, suffix: string;
    dot, previous_dot: Integer;
begin
    host := LowerCase(Copy(text, host_start, MaxInt));
    rest := host;
    if rest.StartsWith('www.') then
        Delete(rest, 1, 4);
    dot := LastDelimiter('.', rest);
    if dot <= 1 then
        Exit;
    last_label := Copy(rest, dot + 1, MaxInt);
    // A suffix typed in full is the host's (qq.com has no qq.com.cn).
    if in_list(last_label, c_host_suffixes) then
        Exit;
    previous_dot := LastDelimiter('.', Copy(rest, 1, dot - 1));
    previous_label := Copy(rest, previous_dot + 1, dot - previous_dot - 1);
    base := Copy(text, 1, Length(text) - Length(last_label));
    for suffix in c_host_suffixes do
    begin
        if in_list(previous_label, c_second_level_labels) and (suffix <> 'cn') then
            Continue;
        // Right after the dot only the suffixes of one label.
        if (last_label = '') and (Pos('.', suffix) > 0) then
            Continue;
        if suffix.StartsWith(last_label) and (suffix <> last_label) then
            completions := completions + [base + suffix];
    end;
end;

function nc_address_input_completions(const text: string): TArray<string>;
var
    at, host_start, idx: Integer;
    domain, lower_text, item: string;
begin
    Result := nil;
    if not nc_is_address_input(text) then
        Exit;
    at := LastDelimiter('@', text);
    if at > 0 then
    begin
        domain := LowerCase(Copy(text, at + 1, MaxInt));
        if LastDelimiter('/?#:=&%+~', domain) > 0 then
            Exit;
        for item in c_mail_domains do
            if item.StartsWith(domain) and (item <> domain) then
                Result := Result + [Copy(text, 1, at) + item];
        if (Length(Result) = 0) and (Pos('.', domain) > 0) then
            add_host_suffixes(text, at + 1, Result);
    end
    else
    begin
        lower_text := LowerCase(text);
        host_start := 1;
        idx := Pos('://', lower_text);
        if idx > 0 then
            host_start := idx + 3
        else if not lower_text.StartsWith('www.') then
            Exit;
        domain := Copy(lower_text, host_start, MaxInt);
        // A path, a query, a port or a fragment: the host is complete.
        if LastDelimiter('/?#:=&%+~', domain) > 0 then
            Exit;
        add_host_suffixes(text, host_start, Result);
    end;
    if Length(Result) > c_address_input_max_completions then
        SetLength(Result, c_address_input_max_completions);
end;

function is_local_part_char(const ch: Char): Boolean;
begin
    Result := is_ascii_letter(ch) or ((ch >= '0') and (ch <= '9')) or
        CharInSet(ch, ['.', '_', '%', '+', '-']);
end;

function is_domain_char(const ch: Char): Boolean;
begin
    Result := is_ascii_letter(ch) or ((ch >= '0') and (ch <= '9')) or
        CharInSet(ch, ['.', '-']);
end;

function nc_address_before_input(const left_text: string): string;
var
    at, start: Integer;
begin
    Result := '';
    at := Length(left_text);
    while (at > 0) and is_domain_char(left_text[at]) do
        Dec(at);
    if (at = 0) or (left_text[at] <> '@') then
        Exit;
    // The domain so far: nothing, or labels each ended by its dot.
    if (at < Length(left_text)) and (left_text[Length(left_text)] <> '.') then
        Exit;
    start := at;
    while (start > 1) and is_local_part_char(left_text[start - 1]) do
        Dec(start);
    if start = at then
        Exit;
    Result := Copy(left_text, start, MaxInt);
end;

function nc_is_address_continuation(const text: string): Boolean;
var
    ch: Char;
begin
    Result := (text <> '') and (Length(text) <= c_address_input_max_length);
    if not Result then
        Exit;
    for ch in text do
        if (ch = '@') or not nc_is_address_char(ch) then
            Exit(False);
end;

function nc_address_completions_after(const before, text: string): TArray<string>;
var
    at: Integer;
    head, item: string;
begin
    Result := nil;
    at := LastDelimiter('@', before);
    if (at = 0) or not nc_is_address_continuation(text) then
        Exit;
    // A local part of its own: the completions do not depend on it.
    head := 'a' + Copy(before, at, MaxInt);
    for item in nc_address_input_completions(head + text) do
        Result := Result + [Copy(item, Length(head) + 1, MaxInt)];
end;

end.
