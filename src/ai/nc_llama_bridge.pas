unit nc_llama_bridge;

interface

uses
    Winapi.Windows,
    System.SysUtils,
    System.Classes,
    System.IOUtils,
    nc_types;

type
    TncLlamaBridge = class
    private type
        TllamaToken = Int32;
        PllamaToken = ^TllamaToken;
        PllamaInt32 = ^Int32;
        PllamaInt8 = ^Int8;
        Tllama_abort_callback = function(abort_data: Pointer): ByteBool; cdecl;

        TllamaBatch = record
            n_tokens: Int32;
            token: PllamaToken;
            embd: PSingle;
            pos: PllamaInt32;
            n_seq_id: PllamaInt32;
            seq_id: PPointer;
            logits: PllamaInt8;
        end;

        TllamaModelParams = record
            devices: PPointer;
            tensor_buft_overrides: Pointer;
            n_gpu_layers: Int32;
            split_mode: Int32;
            main_gpu: Int32;
            tensor_split: PSingle;
            progress_callback: Pointer;
            progress_callback_user_data: Pointer;
            kv_overrides: Pointer;
            vocab_only: ByteBool;
            use_mmap: ByteBool;
            use_direct_io: ByteBool;
            use_mlock: ByteBool;
            check_tensors: ByteBool;
            use_extra_bufts: ByteBool;
            no_host: ByteBool;
            no_alloc: ByteBool;
        end;

        TllamaContextParams = record
            n_ctx: UInt32;
            n_batch: UInt32;
            n_ubatch: UInt32;
            n_seq_max: UInt32;
            n_threads: Int32;
            n_threads_batch: Int32;
            rope_scaling_type: Int32;
            pooling_type: Int32;
            attention_type: Int32;
            flash_attn_type: Int32;
            rope_freq_base: Single;
            rope_freq_scale: Single;
            yarn_ext_factor: Single;
            yarn_attn_factor: Single;
            yarn_beta_fast: Single;
            yarn_beta_slow: Single;
            yarn_orig_ctx: UInt32;
            defrag_thold: Single;
            cb_eval: Pointer;
            cb_eval_user_data: Pointer;
            type_k: Int32;
            type_v: Int32;
            abort_callback: Pointer;
            abort_callback_data: Pointer;
            embeddings: ByteBool;
            offload_kqv: ByteBool;
            no_perf: ByteBool;
            op_offload: ByteBool;
            swa_full: ByteBool;
            kv_unified: ByteBool;
            samplers: Pointer;
            n_samplers: NativeUInt;
        end;

        Tllama_backend_init = procedure; cdecl;
        Tllama_backend_free = procedure; cdecl;
        Tllama_model_default_params = function: TllamaModelParams; cdecl;
        Tllama_context_default_params = function: TllamaContextParams; cdecl;
        Tllama_model_load_from_file = function(path_model: PAnsiChar; params: TllamaModelParams): Pointer; cdecl;
        Tllama_model_free = procedure(model: Pointer); cdecl;
        Tllama_init_from_model = function(model: Pointer; params: TllamaContextParams): Pointer; cdecl;
        Tllama_new_context_with_model = function(model: Pointer; params: TllamaContextParams): Pointer; cdecl;
        Tllama_free = procedure(ctx: Pointer); cdecl;
        Tllama_get_memory = function(ctx: Pointer): Pointer; cdecl;
        Tllama_memory_clear = procedure(mem: Pointer; data: ByteBool); cdecl;
        Tllama_model_get_vocab = function(model: Pointer): Pointer; cdecl;
        Tllama_vocab_n_tokens = function(vocab: Pointer): Int32; cdecl;
        Tllama_vocab_is_eog = function(vocab: Pointer; token: TllamaToken): ByteBool; cdecl;
        Tllama_tokenize = function(vocab: Pointer; text: PAnsiChar; text_len: Int32; tokens: PllamaToken;
            n_tokens_max: Int32; add_special: ByteBool; parse_special: ByteBool): Int32; cdecl;
        Tllama_token_to_piece = function(vocab: Pointer; token: TllamaToken; buf: PAnsiChar; length: Int32;
            lstrip: Int32; special: ByteBool): Int32; cdecl;
        Tllama_batch_get_one = function(tokens: PllamaToken; n_tokens: Int32): TllamaBatch; cdecl;
        Tllama_decode = function(ctx: Pointer; batch: TllamaBatch): Int32; cdecl;
        Tllama_set_n_threads = procedure(ctx: Pointer; n_threads: Int32; n_threads_batch: Int32); cdecl;
        Tllama_set_abort_callback = procedure(ctx: Pointer; abort_callback: Tllama_abort_callback;
            abort_callback_data: Pointer); cdecl;
        Tllama_sampler_init_greedy = function: Pointer; cdecl;
        Tllama_sampler_sample = function(smpl: Pointer; ctx: Pointer; idx: Int32): TllamaToken; cdecl;
        Tllama_sampler_accept = procedure(smpl: Pointer; token: TllamaToken); cdecl;
        Tllama_sampler_free = procedure(smpl: Pointer); cdecl;
    private
        m_dll_handle: HMODULE;
        m_backend_init: Tllama_backend_init;
        m_backend_free: Tllama_backend_free;
        m_model_default_params: Tllama_model_default_params;
        m_context_default_params: Tllama_context_default_params;
        m_model_load_from_file: Tllama_model_load_from_file;
        m_model_free: Tllama_model_free;
        m_init_from_model: Tllama_init_from_model;
        m_new_context_with_model: Tllama_new_context_with_model;
        m_free: Tllama_free;
        m_get_memory: Tllama_get_memory;
        m_memory_clear: Tllama_memory_clear;
        m_model_get_vocab: Tllama_model_get_vocab;
        m_vocab_n_tokens: Tllama_vocab_n_tokens;
        m_vocab_is_eog: Tllama_vocab_is_eog;
        m_tokenize: Tllama_tokenize;
        m_token_to_piece: Tllama_token_to_piece;
        m_batch_get_one: Tllama_batch_get_one;
        m_decode: Tllama_decode;
        m_set_n_threads: Tllama_set_n_threads;
        m_set_abort_callback: Tllama_set_abort_callback;
        m_sampler_init_greedy: Tllama_sampler_init_greedy;
        m_sampler_sample: Tllama_sampler_sample;
        m_sampler_accept: Tllama_sampler_accept;
        m_sampler_free: Tllama_sampler_free;
        m_resolved_backend: TncLlamaBackend;
        m_runtime_dir: string;
        m_model_path: string;
        m_model_handle: Pointer;
        m_context_handle: Pointer;
        m_vocab_handle: Pointer;
        m_vocab_size: Integer;
        m_abort_requested: Integer;
        function resolve_path(const value: string): string;
        function resolve_runtime_dir(const value: string): string;
        function require_runtime_export(const handle: HMODULE; const export_name: AnsiString; out out_ptr: Pointer;
            out error_text: string): Boolean;
        function bind_runtime_exports(const handle: HMODULE; out error_text: string): Boolean;
        procedure clear_runtime_exports;
        procedure unload_model_handles;
        function tokenize_prompt(const prompt: string; out tokens: TArray<TllamaToken>; out error_text: string): Boolean;
        function utf8_bytes_to_string_lossy(const buffer: TBytes; const count: Integer): string;
        function token_to_piece_text(const token: TllamaToken; out piece_bytes: TBytes;
            out error_text: string): Boolean;
        procedure initialize_context_threads;
        procedure reset_abort_flag;
        function is_abort_requested: Boolean;
        function try_load_runtime(const runtime_dir: string; const backend: TncLlamaBackend;
            out error_text: string): Boolean;
    public
        constructor create;
        destructor Destroy; override;
        procedure unload;
        function initialize(const config: TncEngineConfig; out error_text: string): Boolean;
        function load_model(const model_path: string; out error_text: string): Boolean;
        function generate_text(const prompt: string; const max_tokens: Integer; const timeout_ms: Integer;
            const temperature: Double;
            out generated_text: string; out error_text: string): Boolean;
        procedure request_abort;
        function is_model_ready: Boolean;
        property resolved_backend: TncLlamaBackend read m_resolved_backend;
        property runtime_dir: string read m_runtime_dir;
        property loaded_model_path: string read m_model_path;
    end;

function llama_backend_to_text(const backend: TncLlamaBackend): string;

implementation

procedure bridge_debug(const msg: string);
begin
    OutputDebugString(PChar('[llama_bridge] ' + msg));
end;

function llama_backend_to_text(const backend: TncLlamaBackend): string;
begin
    case backend of
        lb_cpu:
            Result := 'cpu';
        lb_cuda:
            Result := 'cuda';
    else
        Result := 'auto';
    end;
end;

function get_module_directory: string;
var
    path_buffer: array[0..MAX_PATH - 1] of Char;
    path_len: DWORD;
begin
    path_len := GetModuleFileName(HInstance, path_buffer, Length(path_buffer));
    if path_len = 0 then
    begin
        Result := '';
        Exit;
    end;

    Result := ExtractFileDir(path_buffer);
end;

function llama_abort_callback(abort_data: Pointer): ByteBool; cdecl;
var
    bridge: TncLlamaBridge;
begin
    Result := False;
    if abort_data = nil then
    begin
        Exit;
    end;

    bridge := TncLlamaBridge(abort_data);
    Result := bridge.is_abort_requested;
end;

constructor TncLlamaBridge.create;
begin
    inherited create;
    m_dll_handle := 0;
    m_resolved_backend := lb_auto;
    m_runtime_dir := '';
    m_model_path := '';
    m_model_handle := nil;
    m_context_handle := nil;
    m_vocab_handle := nil;
    m_vocab_size := 0;
    m_abort_requested := 0;
    clear_runtime_exports;
end;

destructor TncLlamaBridge.Destroy;
begin
    unload;
    inherited Destroy;
end;

procedure TncLlamaBridge.unload;
begin
    request_abort;
    unload_model_handles;

    if Assigned(m_backend_free) then
    begin
        try
            m_backend_free;
        except
        end;
    end;

    if m_dll_handle <> 0 then
    begin
        FreeLibrary(m_dll_handle);
    end;

    m_dll_handle := 0;
    m_resolved_backend := lb_auto;
    m_runtime_dir := '';
    m_abort_requested := 0;
    clear_runtime_exports;
end;

procedure TncLlamaBridge.clear_runtime_exports;
begin
    m_backend_init := nil;
    m_backend_free := nil;
    m_model_default_params := nil;
    m_context_default_params := nil;
    m_model_load_from_file := nil;
    m_model_free := nil;
    m_init_from_model := nil;
    m_new_context_with_model := nil;
    m_free := nil;
    m_get_memory := nil;
    m_memory_clear := nil;
    m_model_get_vocab := nil;
    m_vocab_n_tokens := nil;
    m_vocab_is_eog := nil;
    m_tokenize := nil;
    m_token_to_piece := nil;
    m_batch_get_one := nil;
    m_decode := nil;
    m_set_n_threads := nil;
    m_set_abort_callback := nil;
    m_sampler_init_greedy := nil;
    m_sampler_sample := nil;
    m_sampler_accept := nil;
    m_sampler_free := nil;
end;

procedure TncLlamaBridge.reset_abort_flag;
begin
    InterlockedExchange(m_abort_requested, 0);
end;

procedure TncLlamaBridge.request_abort;
begin
    InterlockedExchange(m_abort_requested, 1);
end;

function TncLlamaBridge.is_abort_requested: Boolean;
begin
    Result := InterlockedCompareExchange(m_abort_requested, 0, 0) <> 0;
end;

procedure TncLlamaBridge.unload_model_handles;
begin
    if (m_context_handle <> nil) and Assigned(m_free) then
    begin
        m_free(m_context_handle);
    end;

    if (m_model_handle <> nil) and Assigned(m_model_free) then
    begin
        m_model_free(m_model_handle);
    end;

    m_context_handle := nil;
    m_model_handle := nil;
    m_vocab_handle := nil;
    m_vocab_size := 0;
    m_model_path := '';
end;

function TncLlamaBridge.resolve_path(const value: string): string;
var
    module_dir: string;
begin
    if value = '' then
    begin
        Result := '';
        Exit;
    end;

    if TPath.IsPathRooted(value) then
    begin
        Result := ExpandFileName(value);
        Exit;
    end;

    module_dir := get_module_directory;
    if module_dir = '' then
    begin
        Result := ExpandFileName(value);
    end
    else
    begin
        Result := ExpandFileName(IncludeTrailingPathDelimiter(module_dir) + value);
    end;
end;

function TncLlamaBridge.resolve_runtime_dir(const value: string): string;
begin
    Result := resolve_path(value);
end;

function TncLlamaBridge.require_runtime_export(const handle: HMODULE; const export_name: AnsiString;
    out out_ptr: Pointer; out error_text: string): Boolean;
begin
    out_ptr := GetProcAddress(handle, PAnsiChar(export_name));
    Result := out_ptr <> nil;
    if not Result then
    begin
        error_text := Format('required export missing: %s', [string(export_name)]);
    end;
end;

function TncLlamaBridge.bind_runtime_exports(const handle: HMODULE; out error_text: string): Boolean;
var
    proc_ptr: Pointer;
begin
    error_text := '';
    if not require_runtime_export(handle, 'llama_backend_init', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_backend_init := Tllama_backend_init(proc_ptr);

    m_backend_free := Tllama_backend_free(GetProcAddress(handle, 'llama_backend_free'));

    if not require_runtime_export(handle, 'llama_model_default_params', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_model_default_params := Tllama_model_default_params(proc_ptr);

    if not require_runtime_export(handle, 'llama_context_default_params', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_context_default_params := Tllama_context_default_params(proc_ptr);

    if not require_runtime_export(handle, 'llama_model_load_from_file', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_model_load_from_file := Tllama_model_load_from_file(proc_ptr);

    if not require_runtime_export(handle, 'llama_model_free', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_model_free := Tllama_model_free(proc_ptr);

    m_init_from_model := Tllama_init_from_model(GetProcAddress(handle, 'llama_init_from_model'));
    m_new_context_with_model := Tllama_new_context_with_model(GetProcAddress(handle, 'llama_new_context_with_model'));
    if (not Assigned(m_init_from_model)) and (not Assigned(m_new_context_with_model)) then
    begin
        error_text := 'required export missing: llama_init_from_model/llama_new_context_with_model';
        Result := False;
        Exit;
    end;

    if not require_runtime_export(handle, 'llama_free', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_free := Tllama_free(proc_ptr);

    if not require_runtime_export(handle, 'llama_get_memory', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_get_memory := Tllama_get_memory(proc_ptr);

    if not require_runtime_export(handle, 'llama_memory_clear', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_memory_clear := Tllama_memory_clear(proc_ptr);

    if not require_runtime_export(handle, 'llama_model_get_vocab', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_model_get_vocab := Tllama_model_get_vocab(proc_ptr);

    if not require_runtime_export(handle, 'llama_vocab_n_tokens', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_vocab_n_tokens := Tllama_vocab_n_tokens(proc_ptr);

    if not require_runtime_export(handle, 'llama_vocab_is_eog', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_vocab_is_eog := Tllama_vocab_is_eog(proc_ptr);

    if not require_runtime_export(handle, 'llama_tokenize', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_tokenize := Tllama_tokenize(proc_ptr);

    if not require_runtime_export(handle, 'llama_token_to_piece', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_token_to_piece := Tllama_token_to_piece(proc_ptr);

    if not require_runtime_export(handle, 'llama_batch_get_one', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_batch_get_one := Tllama_batch_get_one(proc_ptr);

    if not require_runtime_export(handle, 'llama_decode', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_decode := Tllama_decode(proc_ptr);

    if not require_runtime_export(handle, 'llama_set_n_threads', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_set_n_threads := Tllama_set_n_threads(proc_ptr);
    m_set_abort_callback := Tllama_set_abort_callback(GetProcAddress(handle, 'llama_set_abort_callback'));

    if not require_runtime_export(handle, 'llama_sampler_init_greedy', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_sampler_init_greedy := Tllama_sampler_init_greedy(proc_ptr);

    if not require_runtime_export(handle, 'llama_sampler_sample', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_sampler_sample := Tllama_sampler_sample(proc_ptr);

    if not require_runtime_export(handle, 'llama_sampler_accept', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_sampler_accept := Tllama_sampler_accept(proc_ptr);

    if not require_runtime_export(handle, 'llama_sampler_free', proc_ptr, error_text) then
    begin
        Result := False;
        Exit;
    end;
    m_sampler_free := Tllama_sampler_free(proc_ptr);

    Result := True;
end;

procedure TncLlamaBridge.initialize_context_threads;
var
    n_threads: Integer;
begin
    if (m_context_handle = nil) or (not Assigned(m_set_n_threads)) then
    begin
        Exit;
    end;

    n_threads := TThread.ProcessorCount;
    if n_threads <= 0 then
    begin
        n_threads := 4;
    end;
    if n_threads > 16 then
    begin
        n_threads := 16;
    end;

    m_set_n_threads(m_context_handle, n_threads, n_threads);
end;

function TncLlamaBridge.try_load_runtime(const runtime_dir: string; const backend: TncLlamaBackend;
    out error_text: string): Boolean;
var
    dll_path: string;
    dep_path: string;
    dep_missing: string;
    handle: HMODULE;
    cuda_driver_handle: HMODULE;
    runtime_bin_dir: string;
begin
    Result := False;
    error_text := '';
    bridge_debug(Format('try_load_runtime backend=%s dir=%s', [llama_backend_to_text(backend), runtime_dir]));
    runtime_bin_dir := runtime_dir;
    if runtime_dir = '' then
    begin
        error_text := 'runtime dir is empty';
        Exit;
    end;

    if not DirectoryExists(runtime_dir) then
    begin
        error_text := Format('runtime dir does not exist: %s', [runtime_dir]);
        Exit;
    end;

    if (not FileExists(IncludeTrailingPathDelimiter(runtime_bin_dir) + 'llama.dll')) and
        DirectoryExists(IncludeTrailingPathDelimiter(runtime_dir) + 'bin') and
        FileExists(IncludeTrailingPathDelimiter(runtime_dir) + 'bin\llama.dll') then
    begin
        runtime_bin_dir := IncludeTrailingPathDelimiter(runtime_dir) + 'bin';
    end;

    dep_missing := '';

    dep_path := IncludeTrailingPathDelimiter(runtime_bin_dir) + 'llama.dll';
    if not FileExists(dep_path) then
    begin
        dep_missing := dep_missing + ' llama.dll';
    end;

    dep_path := IncludeTrailingPathDelimiter(runtime_bin_dir) + 'ggml.dll';
    if not FileExists(dep_path) then
    begin
        dep_missing := dep_missing + ' ggml.dll';
    end;

    dep_path := IncludeTrailingPathDelimiter(runtime_bin_dir) + 'ggml-base.dll';
    if not FileExists(dep_path) then
    begin
        dep_missing := dep_missing + ' ggml-base.dll';
    end;

    dep_path := IncludeTrailingPathDelimiter(runtime_bin_dir) + 'ggml-cpu.dll';
    if not FileExists(dep_path) then
    begin
        dep_missing := dep_missing + ' ggml-cpu.dll';
    end;

    if backend = lb_cuda then
    begin
        dep_path := IncludeTrailingPathDelimiter(runtime_bin_dir) + 'ggml-cuda.dll';
        if not FileExists(dep_path) then
        begin
            dep_missing := dep_missing + ' ggml-cuda.dll';
        end;

        cuda_driver_handle := LoadLibrary('nvcuda.dll');
        if cuda_driver_handle = 0 then
        begin
            error_text := 'CUDA driver not available (nvcuda.dll not found)';
            Exit;
        end;
        FreeLibrary(cuda_driver_handle);
    end;

    if dep_missing <> '' then
    begin
        error_text := Format('runtime files missing in %s:%s', [runtime_bin_dir, dep_missing]);
        Exit;
    end;

    dll_path := IncludeTrailingPathDelimiter(runtime_bin_dir) + 'llama.dll';
    handle := LoadLibraryEx(PChar(dll_path), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
    if handle = 0 then
    begin
        error_text := Format('LoadLibraryEx failed err=%d path=%s', [GetLastError, dll_path]);
        Exit;
    end;

    if not bind_runtime_exports(handle, error_text) then
    begin
        FreeLibrary(handle);
        clear_runtime_exports;
        Exit;
    end;

    try
        m_backend_init;
    except
        on e: Exception do
        begin
            FreeLibrary(handle);
            clear_runtime_exports;
            error_text := Format('llama_backend_init failed: %s', [e.Message]);
            Exit;
        end;
    end;

    m_dll_handle := handle;
    m_runtime_dir := runtime_bin_dir;
    m_resolved_backend := backend;
    bridge_debug(Format('runtime loaded backend=%s dir=%s', [llama_backend_to_text(backend), runtime_bin_dir]));
    Result := True;
end;

function TncLlamaBridge.initialize(const config: TncEngineConfig; out error_text: string): Boolean;
var
    runtime_cpu: string;
    runtime_cuda: string;
    err_cuda: string;
    err_cpu: string;
begin
    unload;
    error_text := '';
    runtime_cpu := resolve_runtime_dir(config.ai_llama_runtime_dir_cpu);
    runtime_cuda := resolve_runtime_dir(config.ai_llama_runtime_dir_cuda);
    case config.ai_llama_backend of
        lb_cpu:
            Result := try_load_runtime(runtime_cpu, lb_cpu, error_text);
        lb_cuda:
            Result := try_load_runtime(runtime_cuda, lb_cuda, error_text);
    else
        begin
            if try_load_runtime(runtime_cuda, lb_cuda, err_cuda) then
            begin
                Result := True;
                Exit;
            end;

            if try_load_runtime(runtime_cpu, lb_cpu, err_cpu) then
            begin
                Result := True;
                Exit;
            end;

            error_text := Format('auto backend failed; cuda=%s; cpu=%s', [err_cuda, err_cpu]);
            Result := False;
        end;
    end;
end;

function TncLlamaBridge.load_model(const model_path: string; out error_text: string): Boolean;
var
    resolved_path: string;
    model_params: TllamaModelParams;
    context_params: TllamaContextParams;
    model_ptr: Pointer;
    context_ptr: Pointer;
    vocab_ptr: Pointer;
    model_path_utf8: UTF8String;
begin
    Result := False;
    error_text := '';
    bridge_debug('load_model start');

    if m_dll_handle = 0 then
    begin
        error_text := 'llama runtime is not initialized';
        bridge_debug(error_text);
        Exit;
    end;

    resolved_path := resolve_path(model_path);
    if resolved_path = '' then
    begin
        error_text := 'model path is empty';
        bridge_debug(error_text);
        Exit;
    end;

    if not FileExists(resolved_path) then
    begin
        error_text := Format('model file does not exist: %s', [resolved_path]);
        bridge_debug(error_text);
        Exit;
    end;

    if (m_model_handle <> nil) and SameText(resolved_path, m_model_path) then
    begin
        Result := True;
        Exit;
    end;

    unload_model_handles;

    model_params := m_model_default_params;
    if m_resolved_backend = lb_cuda then
    begin
        model_params.n_gpu_layers := -1;
    end
    else
    begin
        model_params.n_gpu_layers := 0;
    end;

    model_path_utf8 := UTF8String(resolved_path);
    model_ptr := m_model_load_from_file(PAnsiChar(model_path_utf8), model_params);
    if model_ptr = nil then
    begin
        error_text := Format('llama_model_load_from_file failed: %s', [resolved_path]);
        bridge_debug(error_text);
        Exit;
    end;

    context_params := m_context_default_params;
    if context_params.n_ctx = 0 then
    begin
        context_params.n_ctx := 1024;
    end;
    if context_params.n_batch = 0 then
    begin
        context_params.n_batch := 512;
    end;
    if context_params.n_ubatch = 0 then
    begin
        context_params.n_ubatch := context_params.n_batch;
    end;
    if context_params.n_seq_max = 0 then
    begin
        context_params.n_seq_max := 1;
    end;

    if Assigned(m_init_from_model) then
    begin
        context_ptr := m_init_from_model(model_ptr, context_params);
    end
    else
    begin
        context_ptr := m_new_context_with_model(model_ptr, context_params);
    end;

    if context_ptr = nil then
    begin
        m_model_free(model_ptr);
        error_text := 'llama context create failed';
        bridge_debug(error_text);
        Exit;
    end;

    m_model_handle := model_ptr;
    m_context_handle := context_ptr;
    reset_abort_flag;
    if Assigned(m_set_abort_callback) then
    begin
        m_set_abort_callback(m_context_handle, llama_abort_callback, Self);
    end;
    initialize_context_threads;

    vocab_ptr := m_model_get_vocab(m_model_handle);
    if vocab_ptr = nil then
    begin
        unload_model_handles;
        error_text := 'llama_model_get_vocab returned nil';
        bridge_debug(error_text);
        Exit;
    end;

    m_vocab_size := m_vocab_n_tokens(vocab_ptr);
    if m_vocab_size <= 0 then
    begin
        unload_model_handles;
        error_text := 'llama_vocab_n_tokens returned invalid value';
        bridge_debug(error_text);
        Exit;
    end;

    m_vocab_handle := vocab_ptr;
    m_model_path := resolved_path;
    bridge_debug('load_model success');
    Result := True;
end;

function TncLlamaBridge.tokenize_prompt(const prompt: string; out tokens: TArray<TllamaToken>;
    out error_text: string): Boolean;
var
    prompt_utf8: UTF8String;
    token_count: Int32;
    token_capacity: Integer;
begin
    Result := False;
    error_text := '';
    SetLength(tokens, 0);

    prompt_utf8 := UTF8String(prompt);
    if prompt_utf8 = '' then
    begin
        error_text := 'prompt is empty';
        Exit;
    end;

    token_capacity := Length(prompt_utf8) * 2 + 32;
    if token_capacity < 128 then
    begin
        token_capacity := 128;
    end;

    SetLength(tokens, token_capacity);
    token_count := m_tokenize(m_vocab_handle, PAnsiChar(prompt_utf8), Length(prompt_utf8), @tokens[0], token_capacity,
        True, False);
    if token_count < 0 then
    begin
        if token_count = Low(Int32) then
        begin
            error_text := 'llama_tokenize overflow';
            Exit;
        end;

        token_capacity := -token_count;
        if token_capacity <= 0 then
        begin
            error_text := 'llama_tokenize returned invalid required size';
            Exit;
        end;

        SetLength(tokens, token_capacity);
        token_count := m_tokenize(m_vocab_handle, PAnsiChar(prompt_utf8), Length(prompt_utf8), @tokens[0], token_capacity,
            True, False);
    end;

    if token_count <= 0 then
    begin
        error_text := Format('llama_tokenize failed: %d', [token_count]);
        SetLength(tokens, 0);
        Exit;
    end;

    SetLength(tokens, token_count);
    Result := True;
end;

function TncLlamaBridge.utf8_bytes_to_string_lossy(const buffer: TBytes; const count: Integer): string;
var
    required_chars: Integer;
    written_chars: Integer;
begin
    Result := '';
    if count <= 0 then
    begin
        Exit;
    end;

    required_chars := MultiByteToWideChar(CP_UTF8, 0, PAnsiChar(@buffer[0]), count, nil, 0);
    if required_chars > 0 then
    begin
        SetLength(Result, required_chars);
        written_chars := MultiByteToWideChar(CP_UTF8, 0, PAnsiChar(@buffer[0]), count, PWideChar(Result), required_chars);
        if written_chars <= 0 then
        begin
            Result := '';
        end
        else if written_chars <> required_chars then
        begin
            SetLength(Result, written_chars);
        end;
        Exit;
    end;

    // Avoid ANSI fallback to prevent mojibake (for example UTF-8 punctuation becoming CJK garbage).
    Result := '';
end;

function TncLlamaBridge.token_to_piece_text(const token: TllamaToken; out piece_bytes: TBytes;
    out error_text: string): Boolean;
var
    buffer: TBytes;
    required_len: Integer;
    written_len: Int32;
begin
    Result := False;
    error_text := '';
    SetLength(piece_bytes, 0);

    required_len := 64;
    SetLength(buffer, required_len);

    written_len := m_token_to_piece(m_vocab_handle, token, PAnsiChar(@buffer[0]), required_len, 0, False);
    if written_len < 0 then
    begin
        required_len := -written_len;
        if required_len <= 0 then
        begin
            error_text := Format('llama_token_to_piece invalid required size: %d', [written_len]);
            Exit;
        end;

        SetLength(buffer, required_len);
        written_len := m_token_to_piece(m_vocab_handle, token, PAnsiChar(@buffer[0]), required_len, 0, False);
    end;

    if written_len < 0 then
    begin
        error_text := Format('llama_token_to_piece failed: %d', [written_len]);
        Exit;
    end;

    if written_len = 0 then
    begin
        Result := True;
        Exit;
    end;

    SetLength(piece_bytes, written_len);
    Move(buffer[0], piece_bytes[0], written_len);
    Result := True;
end;

function TncLlamaBridge.generate_text(const prompt: string; const max_tokens: Integer; const timeout_ms: Integer;
    const temperature: Double; out generated_text: string; out error_text: string): Boolean;
var
    prompt_tokens: TArray<TllamaToken>;
    prompt_batch: TllamaBatch;
    decode_result: Int32;
    sampler: Pointer;
    i: Integer;
    sampled_token: TllamaToken;
    token_piece_bytes: TBytes;
    generated_bytes: TBytes;
    generated_len: Integer;
    piece_len: Integer;
    next_token: TllamaToken;
    next_batch: TllamaBatch;
    start_tick: UInt64;
    timed_out: Boolean;
    mem_handle: Pointer;
begin
    Result := False;
    generated_text := '';
    SetLength(generated_bytes, 0);
    error_text := '';
    reset_abort_flag;

    if not is_model_ready then
    begin
        error_text := 'llama model is not loaded';
        bridge_debug(error_text);
        Exit;
    end;

    if max_tokens <= 0 then
    begin
        error_text := 'max_tokens must be > 0';
        bridge_debug(error_text);
        Exit;
    end;

    if not tokenize_prompt(prompt, prompt_tokens, error_text) then
    begin
        bridge_debug(error_text);
        Exit;
    end;

    if Assigned(m_get_memory) and Assigned(m_memory_clear) then
    begin
        mem_handle := m_get_memory(m_context_handle);
        if mem_handle <> nil then
        begin
            m_memory_clear(mem_handle, True);
        end;
    end;

    prompt_batch := m_batch_get_one(@prompt_tokens[0], Length(prompt_tokens));
    decode_result := m_decode(m_context_handle, prompt_batch);
    if decode_result < 0 then
    begin
        error_text := Format('llama_decode(prompt) failed: %d', [decode_result]);
        bridge_debug(error_text);
        Exit;
    end;

    // Temperature <= 0 means deterministic decoding (equivalent to temp=0).
    // Current bridge path uses greedy sampler for this mode.
    if temperature <= 0 then
    begin
        sampler := m_sampler_init_greedy;
    end
    else
    begin
        // Non-zero temperature is not enabled in this bridge path yet.
        // Fall back to deterministic decoding to keep IME behavior stable.
        sampler := m_sampler_init_greedy;
    end;
    if sampler = nil then
    begin
        error_text := 'llama_sampler_init_greedy failed';
        bridge_debug(error_text);
        Exit;
    end;

    start_tick := GetTickCount64;
    timed_out := False;

    try
        for i := 0 to max_tokens - 1 do
        begin
            if is_abort_requested then
            begin
                error_text := 'generation aborted';
                Exit(False);
            end;

            if (timeout_ms > 0) and ((GetTickCount64 - start_tick) >= UInt64(timeout_ms)) then
            begin
                timed_out := True;
                Break;
            end;

            sampled_token := m_sampler_sample(sampler, m_context_handle, -1);
            if sampled_token < 0 then
            begin
                error_text := Format('llama_sampler_sample failed: %d', [sampled_token]);
                bridge_debug(error_text);
                Exit(False);
            end;

            if m_vocab_is_eog(m_vocab_handle, sampled_token) then
            begin
                Break;
            end;

            m_sampler_accept(sampler, sampled_token);

            if not token_to_piece_text(sampled_token, token_piece_bytes, error_text) then
            begin
                bridge_debug(error_text);
                Exit(False);
            end;

            piece_len := Length(token_piece_bytes);
            if piece_len > 0 then
            begin
                generated_len := Length(generated_bytes);
                SetLength(generated_bytes, generated_len + piece_len);
                Move(token_piece_bytes[0], generated_bytes[generated_len], piece_len);
            end;

            next_token := sampled_token;
            next_batch := m_batch_get_one(@next_token, 1);
            decode_result := m_decode(m_context_handle, next_batch);
            if decode_result < 0 then
            begin
                error_text := Format('llama_decode(step=%d) failed: %d', [i, decode_result]);
                bridge_debug(error_text);
                Exit(False);
            end;
        end;
    finally
        m_sampler_free(sampler);
    end;

    if Length(generated_bytes) > 0 then
    begin
        generated_text := utf8_bytes_to_string_lossy(generated_bytes, Length(generated_bytes));
        if generated_text <> '' then
        begin
            Result := True;
            Exit;
        end;
    end;

    if timed_out then
    begin
        error_text := 'generation timeout';
        bridge_debug(error_text);
    end
    else
    begin
        error_text := 'generation produced empty output';
        bridge_debug(error_text);
    end;
end;

function TncLlamaBridge.is_model_ready: Boolean;
begin
    Result := (m_model_handle <> nil) and (m_context_handle <> nil) and (m_vocab_handle <> nil);
end;

end.
