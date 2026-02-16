program cassotis_ime_perf_bench;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Diagnostics,
  Winapi.Windows,
  nc_engine_intf in '..\src\engine\nc_engine_intf.pas',
  nc_ai_intf in '..\src\ai\nc_ai_intf.pas',
  nc_ai_null in '..\src\ai\nc_ai_null.pas',
  nc_candidate_fusion in '..\src\engine\nc_candidate_fusion.pas',
  nc_dictionary_intf in '..\src\engine\nc_dictionary_intf.pas',
  nc_dictionary_sqlite in '..\src\engine\nc_dictionary_sqlite.pas',
  nc_pinyin_parser in '..\src\engine\nc_pinyin_parser.pas',
  nc_config in '..\src\common\nc_config.pas',
  nc_log in '..\src\common\nc_log.pas',
  nc_sqlite in '..\src\common\nc_sqlite.pas',
  nc_types in '..\src\common\nc_types.pas';

function get_arg_value(const name: string): string;
var
    i: Integer;
    prefix: string;
    value: string;
begin
    Result := '';
    prefix := '--' + name + '=';
    for i := 1 to ParamCount do
    begin
        value := ParamStr(i);
        if SameText(Copy(value, 1, Length(prefix)), prefix) then
        begin
            Result := Copy(value, Length(prefix) + 1, Length(value));
            Exit;
        end;
    end;
end;

function split_inputs(const input_text: string): TArray<string>;
begin
    if input_text = '' then
    begin
        SetLength(Result, 0);
        Exit;
    end;

    Result := input_text.Split([',']);
end;

procedure init_key_state(out key_state: TncKeyState);
begin
    key_state.shift_down := False;
    key_state.ctrl_down := False;
    key_state.alt_down := False;
    key_state.caps_lock := False;
end;

function process_input(const engine: TncEngine; const text: string): Int64;
var
    i: Integer;
    key_state: TncKeyState;
    key_code: Word;
    ch: Char;
    stopwatch: TStopwatch;
begin
    engine.reset;
    init_key_state(key_state);
    stopwatch := TStopwatch.StartNew;
    for i := 1 to Length(text) do
    begin
        ch := text[i];
        if ch = '''' then
        begin
            key_code := VK_OEM_7;
        end
        else
        begin
            key_code := Ord(UpCase(ch));
        end;
        engine.process_key(key_code, key_state);
    end;
    engine.get_candidates;
    stopwatch.Stop;
    Result := stopwatch.ElapsedMilliseconds;
end;

procedure run_bench(const engine: TncEngine; const inputs: TArray<string>; const runs: Integer;
    out total_ms: Int64; out total_runs: Integer);
var
    run: Integer;
    i: Integer;
begin
    total_ms := 0;
    total_runs := 0;
    for run := 1 to runs do
    begin
        for i := 0 to High(inputs) do
        begin
            Inc(total_ms, process_input(engine, inputs[i]));
            Inc(total_runs);
        end;
    end;
end;

procedure print_usage;
begin
    Writeln('Usage: cassotis_ime_perf_bench --dict=PATH --dict_sc=PATH --dict_tc=PATH --variant=simplified --runs=50 --warmup=3 --input=nihao,zhongguo');
end;

var
    config_manager: TncConfigManager;
    config: TncEngineConfig;
    engine: TncEngine;
    inputs: TArray<string>;
    input_value: string;
    dict_path: string;
    dict_sc_path: string;
    dict_tc_path: string;
    variant_text: string;
    runs: Integer;
    warmup: Integer;
    total_ms: Int64;
    total_runs: Integer;
    avg_ms: Double;
    init_ms: Int64;
    first_ms: Int64;
    stopwatch: TStopwatch;
begin
    try
        input_value := get_arg_value('input');
        inputs := split_inputs(input_value);
        if Length(inputs) = 0 then
        begin
            inputs := TArray<string>.Create('nihao', 'zhongguo', 'shijie', 'zhongwen',
                'shuru', 'pingyin', 'xian''an', 'tianqi', 'beijing', 'shanghai');
        end;

        runs := StrToIntDef(get_arg_value('runs'), 50);
        warmup := StrToIntDef(get_arg_value('warmup'), 3);
        dict_path := get_arg_value('dict');
        dict_sc_path := get_arg_value('dict_sc');
        dict_tc_path := get_arg_value('dict_tc');
        variant_text := get_arg_value('variant');

        if runs <= 0 then
        begin
            print_usage;
            Exit;
        end;

        config_manager := TncConfigManager.create('');
        try
            config := config_manager.load_engine_config;
        finally
            config_manager.Free;
        end;

        if variant_text <> '' then
        begin
            if SameText(variant_text, 'traditional') or SameText(variant_text, 'tc') then
            begin
                config.dictionary_variant := dv_traditional;
            end
            else
            begin
                config.dictionary_variant := dv_simplified;
            end;
        end;

        if dict_sc_path <> '' then
        begin
            config.dictionary_path_simplified := dict_sc_path;
        end;

        if dict_tc_path <> '' then
        begin
            config.dictionary_path_traditional := dict_tc_path;
        end;

        if dict_path <> '' then
        begin
            config.dictionary_path_simplified := dict_path;
            if variant_text = '' then
            begin
                config.dictionary_variant := dv_simplified;
            end;
        end;

        stopwatch := TStopwatch.StartNew;
        engine := TncEngine.create(config);
        stopwatch.Stop;
        init_ms := stopwatch.ElapsedMilliseconds;
        try
            first_ms := process_input(engine, inputs[0]);

            run_bench(engine, inputs, warmup, total_ms, total_runs);
            run_bench(engine, inputs, runs, total_ms, total_runs);
        finally
            engine.Free;
        end;

        avg_ms := 0;
        if total_runs > 0 then
        begin
            avg_ms := total_ms / total_runs;
        end;

        Writeln('engine_init_ms=', init_ms);
        Writeln('first_input_ms=', first_ms);
        Writeln('avg_input_ms=', FormatFloat('0.00', avg_ms));
        Writeln('total_runs=', total_runs);
        Writeln('inputs=', Length(inputs));
    except
        on e: Exception do
        begin
            Writeln('error: ', e.Message);
        end;
    end;
end.
