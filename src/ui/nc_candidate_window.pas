unit nc_candidate_window;

interface

uses
    System.SysUtils,
    System.Types,
    Classes,
    Vcl.Forms,
    Vcl.StdCtrls,
    Vcl.Controls,
    Vcl.Graphics,
    Winapi.Windows,
    Winapi.MultiMon,
    nc_types;

type
    TncCandidateWindow = class(TForm)
    private
        m_candidate_lines: TStringList;
        m_candidate_widths: TArray<Integer>;
        m_candidate_offsets: TArray<Integer>;
        m_selected_index: Integer;
        m_list_font: TFont;
        m_page_label: TLabel;
        m_preedit_label: TLabel;
        m_border_color: TColor;
        m_base_item_height: Integer;
        m_base_list_font_size: Integer;
        m_base_label_font_size: Integer;
        m_base_label_height: Integer;
        m_base_preedit_font_size: Integer;
        m_base_preedit_height: Integer;
        m_base_item_gap: Integer;
        m_item_gap: Integer;
        m_base_list_padding: Integer;
        m_current_dpi: Integer;
        m_list_item_height: Integer;
        m_list_rect: TRect;
        m_list_padding: Integer;
        procedure configure_form;
        procedure configure_page_label;
        procedure configure_preedit_label;
        procedure apply_current_dpi;
        procedure apply_dpi(const dpi: Integer);
        function get_target_dpi(const anchor: TPoint): Integer;
        function get_work_area(const anchor: TPoint; out work_area: TRect): Boolean;
        function format_candidate_line(const index: Integer; const candidate: TncCandidate): string;
        function format_page_text(const page_index: Integer; const page_count: Integer): string;
        procedure update_size;
    protected
        procedure Paint; override;
    public
        constructor create; reintroduce;
        destructor Destroy; override;
        procedure update_candidates(const candidates: TncCandidateList; const page_index: Integer; const page_count: Integer;
            const selected_index: Integer; const preedit_text: string);
        procedure show_at(const x: Integer; const y: Integer);
        procedure hide_window;
    end;

implementation

var
    g_vcl_initialized: Boolean = False;

procedure ensure_vcl_initialized;
begin
    if g_vcl_initialized then
    begin
        Exit;
    end;

    if Application.Handle <> 0 then
    begin
        g_vcl_initialized := True;
        Exit;
    end;

    Application.Initialize;
    Application.ShowMainForm := False;
    g_vcl_initialized := True;
end;

constructor TncCandidateWindow.create;
begin
    ensure_vcl_initialized;
    inherited CreateNew(nil);
    m_candidate_lines := TStringList.Create;
    m_list_font := TFont.Create;
    m_border_color := clSilver;
    m_base_item_height := 20;
    m_base_list_font_size := 9;
    m_base_label_font_size := 8;
    m_base_label_height := 18;
    m_base_preedit_font_size := 9;
    m_base_preedit_height := 20;
    m_base_item_gap := 12;
    m_item_gap := m_base_item_gap;
    m_base_list_padding := 6;
    m_current_dpi := 0;
    m_list_item_height := m_base_item_height;
    m_list_rect := Rect(0, 0, 0, 0);
    m_list_padding := m_base_list_padding;
    m_selected_index := 0;
    SetLength(m_candidate_widths, 0);
    SetLength(m_candidate_offsets, 0);
    configure_form;
    configure_preedit_label;
    configure_page_label;

    m_list_font.Name := 'Segoe UI';
    m_list_font.Size := m_base_list_font_size;
    m_list_font.Color := clBlack;
end;

destructor TncCandidateWindow.Destroy;
begin
    if m_candidate_lines <> nil then
    begin
        m_candidate_lines.Free;
        m_candidate_lines := nil;
    end;

    if m_list_font <> nil then
    begin
        m_list_font.Free;
        m_list_font := nil;
    end;

    inherited Destroy;
end;

procedure TncCandidateWindow.configure_form;
begin
    BorderStyle := bsNone;
    FormStyle := fsStayOnTop;
    Position := poDesigned;
    Color := clWhite;
    Padding.Left := 1;
    Padding.Top := 1;
    Padding.Right := 1;
    Padding.Bottom := 1;
    Visible := False;
end;

procedure TncCandidateWindow.configure_preedit_label;
begin
    m_preedit_label := TLabel.Create(Self);
    m_preedit_label.Parent := Self;
    m_preedit_label.Align := alNone;
    m_preedit_label.AutoSize := False;
    m_preedit_label.Height := m_base_preedit_height;
    m_preedit_label.Alignment := taLeftJustify;
    m_preedit_label.Layout := tlCenter;
    m_preedit_label.Font.Name := 'Segoe UI';
    m_preedit_label.Font.Size := m_base_preedit_font_size;
    m_preedit_label.Font.Color := clGrayText;
    m_preedit_label.Transparent := False;
    m_preedit_label.Color := clWhite;
    m_preedit_label.Visible := False;
end;

procedure TncCandidateWindow.configure_page_label;
begin
    m_page_label := TLabel.Create(Self);
    m_page_label.Parent := Self;
    m_page_label.Align := alNone;
    m_page_label.AutoSize := False;
    m_page_label.Height := m_base_label_height;
    m_page_label.Alignment := taRightJustify;
    m_page_label.Layout := tlCenter;
    m_page_label.Font.Name := 'Segoe UI';
    m_page_label.Font.Size := m_base_label_font_size;
    m_page_label.Font.Color := clGrayText;
    m_page_label.Transparent := False;
    m_page_label.Color := clWhite;
    m_page_label.Visible := False;
end;

procedure TncCandidateWindow.apply_current_dpi;
var
    dpi: Integer;
begin
    HandleNeeded;
    dpi := GetDpiForWindow(Handle);
    if dpi <= 0 then
    begin
        dpi := 96;
    end;

    apply_dpi(dpi);
end;

procedure TncCandidateWindow.apply_dpi(const dpi: Integer);
begin
    if dpi <= 0 then
    begin
        Exit;
    end;

    m_current_dpi := dpi;
    m_list_font.Size := MulDiv(m_base_list_font_size, dpi, 96);
    m_list_item_height := MulDiv(m_base_item_height, dpi, 96);
    m_page_label.Font.Size := MulDiv(m_base_label_font_size, dpi, 96);
    m_page_label.Height := MulDiv(m_base_label_height, dpi, 96);
    m_preedit_label.Font.Size := MulDiv(m_base_preedit_font_size, dpi, 96);
    m_preedit_label.Height := MulDiv(m_base_preedit_height, dpi, 96);
    m_item_gap := MulDiv(m_base_item_gap, dpi, 96);
    m_list_padding := MulDiv(m_base_list_padding, dpi, 96);
end;

function TncCandidateWindow.get_target_dpi(const anchor: TPoint): Integer;
type
    TGetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer; out dpiX: UINT;
        out dpiY: UINT): HRESULT; stdcall;
const
    MDT_EFFECTIVE_DPI = 0;
var
    monitor: HMONITOR;
    module: HMODULE;
    get_dpi: TGetDpiForMonitor;
    dpi_x: UINT;
    dpi_y: UINT;
begin
    Result := 0;
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor <> 0 then
    begin
        module := GetModuleHandle('Shcore.dll');
        if module = 0 then
        begin
            module := LoadLibrary('Shcore.dll');
        end;
        if module <> 0 then
        begin
            get_dpi := TGetDpiForMonitor(GetProcAddress(module, 'GetDpiForMonitor'));
            if Assigned(get_dpi) and (get_dpi(monitor, MDT_EFFECTIVE_DPI, dpi_x, dpi_y) = S_OK) then
            begin
                Result := dpi_x;
            end;
        end;
    end;

    if Result <= 0 then
    begin
        Result := GetDpiForWindow(Handle);
    end;
    if Result <= 0 then
    begin
        Result := 96;
    end;
end;

function TncCandidateWindow.get_work_area(const anchor: TPoint; out work_area: TRect): Boolean;
var
    monitor: HMONITOR;
    info: TMonitorInfo;
begin
    monitor := MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
    if monitor <> 0 then
    begin
        info.cbSize := SizeOf(info);
        if GetMonitorInfo(monitor, @info) then
        begin
            work_area := info.rcWork;
            Result := True;
            Exit;
        end;
    end;

    Result := SystemParametersInfo(SPI_GETWORKAREA, 0, @work_area, 0);
end;

function TncCandidateWindow.format_candidate_line(const index: Integer; const candidate: TncCandidate): string;
var
    suffix: string;
begin
    suffix := candidate.text;
    if candidate.comment <> '' then
    begin
        suffix := suffix + '  ' + candidate.comment;
    end;

    Result := IntToStr(index + 1) + '. ' + suffix;
end;

function TncCandidateWindow.format_page_text(const page_index: Integer; const page_count: Integer): string;
var
    current_page: Integer;
begin
    if page_count <= 0 then
    begin
        Result := '';
        Exit;
    end;

    current_page := page_index + 1;
    Result := 'Page ' + IntToStr(current_page) + '/' + IntToStr(page_count);
end;

procedure TncCandidateWindow.update_size;
var
    i: Integer;
    text_width: Integer;
    max_width: Integer;
    item_count: Integer;
    label_height: Integer;
    preedit_height: Integer;
    list_height: Integer;
    row_width: Integer;
    inner_left: Integer;
    inner_top: Integer;
    inner_width: Integer;
    current_top: Integer;
begin
    item_count := m_candidate_lines.Count;
    if item_count = 0 then
    begin
        Exit;
    end;

    Canvas.Font.Assign(m_list_font);
    row_width := 0;
    SetLength(m_candidate_widths, item_count);
    SetLength(m_candidate_offsets, item_count);
    for i := 0 to item_count - 1 do
    begin
        text_width := Canvas.TextWidth(m_candidate_lines[i]) + (m_list_padding * 2);
        m_candidate_widths[i] := text_width;
        if i = 0 then
        begin
            m_candidate_offsets[i] := 0;
        end
        else
        begin
            m_candidate_offsets[i] := m_candidate_offsets[i - 1] + m_candidate_widths[i - 1] + m_item_gap;
        end;
    end;
    if item_count > 0 then
    begin
        row_width := m_candidate_offsets[item_count - 1] + m_candidate_widths[item_count - 1];
    end;
    if row_width < 120 then
    begin
        row_width := 120;
    end;
    max_width := row_width;

    label_height := 0;
    if m_page_label.Visible then
    begin
        Canvas.Font.Assign(m_page_label.Font);
        text_width := Canvas.TextWidth(m_page_label.Caption) + 16;
        if text_width > max_width then
        begin
            max_width := text_width;
        end;
        label_height := m_page_label.Height;
    end;

    preedit_height := 0;
    if m_preedit_label.Visible then
    begin
        Canvas.Font.Assign(m_preedit_label.Font);
        text_width := Canvas.TextWidth(m_preedit_label.Caption) + 16;
        if text_width > max_width then
        begin
            max_width := text_width;
        end;
        preedit_height := m_preedit_label.Height;
    end;

    list_height := m_list_item_height;
    ClientWidth := max_width;
    ClientHeight := preedit_height + list_height + label_height;

    inner_left := Padding.Left;
    inner_top := Padding.Top;
    inner_width := ClientWidth - Padding.Left - Padding.Right;
    current_top := inner_top;

    if m_preedit_label.Visible then
    begin
        m_preedit_label.SetBounds(inner_left, current_top, inner_width, preedit_height);
        current_top := current_top + preedit_height;
    end;

    m_list_rect := Rect(inner_left, current_top, inner_left + inner_width, current_top + list_height);
    current_top := current_top + list_height;

    if m_page_label.Visible then
    begin
        m_page_label.SetBounds(inner_left, current_top, inner_width, label_height);
    end;
end;

procedure TncCandidateWindow.Paint;
var
    i: Integer;
    line_height: Integer;
    text_height: Integer;
    offset_y: Integer;
    y: Integer;
    x: Integer;
    item_left: Integer;
    item_right: Integer;
    line_rect: TRect;
begin
    inherited;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(ClientRect);

    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := m_border_color;
    Canvas.Rectangle(0, 0, Width, Height);

    if (m_candidate_lines = nil) or (m_candidate_lines.Count = 0) then
    begin
        Exit;
    end;

    Canvas.Font.Assign(m_list_font);
    SetBkMode(Canvas.Handle, TRANSPARENT);
    line_height := m_list_item_height;
    text_height := Canvas.TextHeight('Hg');
    offset_y := 0;
    if line_height > text_height then
    begin
        offset_y := (line_height - text_height) div 2;
    end;
    y := m_list_rect.Top;
    for i := 0 to m_candidate_lines.Count - 1 do
    begin
        if (i >= Length(m_candidate_offsets)) or (i >= Length(m_candidate_widths)) then
        begin
            Continue;
        end;

        item_left := m_list_rect.Left + m_candidate_offsets[i];
        item_right := item_left + m_candidate_widths[i];
        x := item_left + m_list_padding;
        line_rect := Rect(item_left, y, item_right, y + line_height);
        Canvas.Brush.Style := bsSolid;
        if i = m_selected_index then
        begin
            Canvas.Brush.Color := clHighlight;
            Canvas.Font.Color := clHighlightText;
            SetTextColor(Canvas.Handle, ColorToRGB(clHighlightText));
            SetBkColor(Canvas.Handle, ColorToRGB(clHighlight));
        end
        else
        begin
            Canvas.Brush.Color := Color;
            Canvas.Font.Color := m_list_font.Color;
            SetTextColor(Canvas.Handle, ColorToRGB(m_list_font.Color));
            SetBkColor(Canvas.Handle, ColorToRGB(Color));
        end;
        ExtTextOut(Canvas.Handle, x, y + offset_y, ETO_OPAQUE, @line_rect,
            PChar(m_candidate_lines[i]), Length(m_candidate_lines[i]), nil);
    end;
end;

procedure TncCandidateWindow.update_candidates(const candidates: TncCandidateList; const page_index: Integer;
    const page_count: Integer; const selected_index: Integer; const preedit_text: string);
var
    i: Integer;
    count: Integer;
begin
    m_candidate_lines.BeginUpdate;
    try
        m_candidate_lines.Clear;
        count := Length(candidates);

        for i := 0 to count - 1 do
        begin
            m_candidate_lines.Add(format_candidate_line(i, candidates[i]));
        end;
    finally
        m_candidate_lines.EndUpdate;
    end;

    if page_count > 1 then
    begin
        m_page_label.Caption := format_page_text(page_index, page_count);
        m_page_label.Visible := True;
    end
    else
    begin
        m_page_label.Caption := '';
        m_page_label.Visible := False;
    end;

    if preedit_text <> '' then
    begin
        m_preedit_label.Caption := preedit_text;
        m_preedit_label.Visible := True;
    end
    else
    begin
        m_preedit_label.Caption := '';
        m_preedit_label.Visible := False;
    end;

    if m_candidate_lines.Count = 0 then
    begin
        hide_window;
        Exit;
    end;

    m_selected_index := selected_index;
    if m_selected_index < 0 then
    begin
        m_selected_index := 0;
    end
    else if m_selected_index >= m_candidate_lines.Count then
    begin
        m_selected_index := m_candidate_lines.Count - 1;
    end;

    apply_current_dpi;
    update_size;
    Invalidate;
end;

procedure TncCandidateWindow.show_at(const x: Integer; const y: Integer);
var
    flags: UINT;
    anchor: TPoint;
    work_area: TRect;
    target_x: Integer;
    target_y: Integer;
    dpi: Integer;
    gap: Integer;
begin
    HandleNeeded;
    anchor := Point(x, y);
    dpi := get_target_dpi(anchor);
    if dpi <> m_current_dpi then
    begin
        apply_dpi(dpi);
        update_size;
    end;

    target_x := x;
    target_y := y;
    if not get_work_area(anchor, work_area) then
    begin
        work_area := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
    end;

    gap := MulDiv(4, m_current_dpi, 96);
    if (target_y + Height > work_area.Bottom) then
    begin
        target_y := y - Height - gap;
    end;

    if target_y < work_area.Top then
    begin
        target_y := work_area.Top;
    end
    else if target_y + Height > work_area.Bottom then
    begin
        target_y := work_area.Bottom - Height;
    end;

    if target_x + Width > work_area.Right then
    begin
        target_x := work_area.Right - Width;
    end;
    if target_x < work_area.Left then
    begin
        target_x := work_area.Left;
    end;

    Left := target_x;
    Top := target_y;
    flags := SWP_NOACTIVATE or SWP_NOSIZE or SWP_SHOWWINDOW;
    SetWindowPos(Handle, HWND_TOPMOST, Left, Top, 0, 0, flags);
    ShowWindow(Handle, SW_SHOWNOACTIVATE);
end;

procedure TncCandidateWindow.hide_window;
begin
    if HandleAllocated then
    begin
        ShowWindow(Handle, SW_HIDE);
        Exit;
    end;

    if Visible then
    begin
        Hide;
    end;
end;

end.
