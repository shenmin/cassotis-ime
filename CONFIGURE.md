# Configuration Guide (`cassotis_ime.ini`)

English | [简体中文](CONFIGURE.CN.md)

This document explains all `cassotis_ime.ini` options, including meaning, valid values, defaults, and examples.
Source of truth in code: `src/common/nc_config.pas`, `src/common/nc_types.pas`.

## Config File Location

Default path:

- `<program_dir>\config\cassotis_ime.ini`

Notes:

- If the file does not exist, it is created with defaults.
- Path fields in `[dictionary]` and `[ai]` support relative paths; they are resolved against the module directory.
- `log.log_path` does not use the same normalization path helper. Prefer absolute paths if possible.

---

## `[meta]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `version` | Config schema version | Integer | `5` | `version=5` | Internal migration marker. Older versions may trigger rewrite on save. Usually do not edit manually. |

---

## `[engine]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `input_mode` | Initial input mode | `0`=Chinese, `1`=English | `0` | `input_mode=0` | Any value other than `1` falls back to Chinese mode. |
| `max_candidates` | Candidates per page | Integer | `9` | `max_candidates=9` | `<=0` falls back to runtime default page size `9`. |
| `enable_ai` | Enable AI candidates | `true`/`false` | `false` | `enable_ai=true` | Controls whether AI provider is enabled. |
| `enable_ctrl_space_toggle` | Allow `Ctrl+Space` to toggle CN/EN mode | `true`/`false` | `false` | `enable_ctrl_space_toggle=true` | If disabled, this shortcut does not toggle mode. |
| `enable_shift_space_full_width_toggle` | Allow `Shift+Space` to toggle full-width mode | `true`/`false` | `true` | `enable_shift_space_full_width_toggle=true` | Affects shortcut toggling for `full_width_mode`. |
| `enable_ctrl_period_punct_toggle` | Allow `Ctrl+.` to toggle punctuation width | `true`/`false` | `true` | `enable_ctrl_period_punct_toggle=true` | Affects shortcut toggling for `punctuation_full_width`. |
| `full_width_mode` | Full-width output mode | `true`/`false` | `false` | `full_width_mode=false` | When enabled, ASCII output can be converted to full-width forms. |
| `punctuation_full_width` | Chinese punctuation mode | `true`/`false` | `true` | `punctuation_full_width=true` | Controls punctuation output style (full-width vs half-width). |
| `enable_segment_candidates` | Enable segmented pinyin candidate enhancement | `true`/`false` | `true` | `enable_segment_candidates=true` | When enabled, segmented candidates are added and merged. |

---

## `[dictionary]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `variant` | Dictionary variant | `simplified` / `traditional` / `tc` | `simplified` | `variant=simplified` | `traditional` and `tc` are equivalent; other values fall back to `simplified`. |
| `db_path_sc` | Simplified base dictionary path | File path | `<program_dir>\data\dict_sc.db` | `db_path_sc=data\dict_sc.db` | Relative paths are supported. |
| `db_path_tc` | Traditional base dictionary path | File path | `<program_dir>\data\dict_tc.db` | `db_path_tc=data\dict_tc.db` | Relative paths are supported. |
| `user_db_path` | User dictionary path | File path | `<program_dir>\config\user_dict.db` | `user_db_path=config\user_dict.db` | Relative paths are supported. |
| `db_path` | Legacy compatibility key (simplified DB) | File path | None | `db_path=data\dict_sc.db` | Legacy only. If `db_path_sc` is missing, this key is used. Use `db_path_sc` in new configs. |

---

## `[ai]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `llama_backend` | Llama backend selection | `auto` / `cpu` / `cuda` / `gpu` | `auto` | `llama_backend=cuda` | `gpu` is treated as `cuda`; unknown values fall back to `auto`. |
| `llama_runtime_dir_cpu` | CPU runtime directory | Directory path | Win64: `<program_dir>\llama\win64` | `llama_runtime_dir_cpu=llama\win64` | Relative paths are supported. |
| `llama_runtime_dir_cuda` | CUDA runtime directory | Directory path | `<program_dir>\llama\win64-cuda` | `llama_runtime_dir_cuda=llama\win64-cuda` | Relative paths are supported. |
| `llama_model_path` | GGUF model file path | File path | `<program_dir>\models\llama.gguf` | `llama_model_path=models\gpt-oss-20b-Q5_K_M.gguf` | Relative paths are supported. The `models` directory is ensured by default path logic. |
| `request_timeout_ms` | AI request timeout (ms) | Positive integer | `1200` | `request_timeout_ms=1500` | `<=0` falls back to `1200`. |

---

## `[log]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `enabled` | Enable file logging | `true`/`false` | `false` | `enabled=true` | When `false`, file logging is disabled across TSF/host/AI modules. |
| `level` | Log level | `0`=DEBUG, `1`=INFO, `2`=WARN, `3`=ERROR | `1` | `level=1` | Out-of-range values fall back to default `INFO`. |
| `max_size_kb` | Rotation threshold (KB) | Integer | `1024` | `max_size_kb=2048` | If `>0`, file rotates to `.1` when size limit is exceeded; `<=0` behaves as no rotation. |
| `log_path` | Log file path | File path | `<program_dir>\logs\cassotis_ime.log` | `log_path=D:\cassotis_ime\out\logs\cassotis_ime.log` | Absolute path is recommended. |

---

## Full Example (Recommended Baseline)

```ini
[meta]
version=5

[engine]
input_mode=0
max_candidates=9
enable_ai=true
enable_ctrl_space_toggle=false
enable_shift_space_full_width_toggle=true
enable_ctrl_period_punct_toggle=true
full_width_mode=false
punctuation_full_width=true
enable_segment_candidates=true

[dictionary]
variant=simplified
db_path_sc=data\dict_sc.db
db_path_tc=data\dict_tc.db
user_db_path=config\user_dict.db

[ai]
llama_backend=auto
llama_runtime_dir_cpu=llama\win64
llama_runtime_dir_cuda=llama\win64-cuda
llama_model_path=models\llama.gguf
request_timeout_ms=1200

[log]
enabled=true
level=1
max_size_kb=1024
log_path=logs\cassotis_ime.log
```

---

## Common Templates

### 1. Dictionary-only (AI disabled)

```ini
[engine]
enable_ai=false
max_candidates=9
```

### 2. Force CUDA backend

```ini
[engine]
enable_ai=true

[ai]
llama_backend=cuda
llama_runtime_dir_cuda=llama\win64-cuda
llama_model_path=models\your-model.gguf
request_timeout_ms=1500
```

### 3. Debug logging

```ini
[log]
enabled=true
level=0
max_size_kb=4096
log_path=D:\cassotis_ime\out\logs\cassotis_ime.log
```
