# Configuration Guide (`cassotis_ime.ini`)

English | [简体中文](CONFIGURE.CN.md)

This document explains all `cassotis_ime.ini` options: meaning, valid values, defaults, and examples.
Source of truth in code: `src/common/nc_config.pas`, `src/common/nc_types.pas`.

## Config File Location

Default path:

```
%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini
```

Notes:

- The file is created automatically with defaults on first run.
- If an older config is found at legacy locations (next to the host executable, or under `config\`), it is migrated automatically.
- The `[log]` section's `log_path` field is the only path that is not resolved relative to the host executable directory — use an absolute path or leave it as the default.

---

## `[meta]`

| Key | Meaning | Allowed values | Default | Notes |
| --- | --- | --- | --- | --- |
| `version` | Config schema version | Integer | `8` | Internal migration marker. Updated automatically on save. Do not edit manually. |

---

## `[engine]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `input_mode` | Initial input mode | `0` = Chinese, `1` = English | `0` | `input_mode=0` | Any value other than `1` defaults to Chinese. Can be toggled at runtime with the Shift key. |
| `full_width_mode` | Full-width output | `true` / `false` | `false` | `full_width_mode=false` | When enabled, ASCII characters are mapped to full-width forms. Toggle at runtime with Shift+Space. |
| `punctuation_full_width` | Chinese punctuation style | `true` / `false` | `true` | `punctuation_full_width=true` | When enabled, punctuation keys produce Chinese full-width symbols. Toggle at runtime with Ctrl+Period. |
| `debug` | Debug mode | `0` / `1` | `0` | `debug=1` | Shows candidate scores and path info in the candidate window. |

> **Note:** Candidates per page (9), segment candidate enhancement, and keyboard shortcut toggles are fixed at runtime and are not configurable via the INI file.

---

## `[dictionary]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `variant` | Dictionary variant | `simplified` / `traditional` / `tc` | `simplified` | `variant=simplified` | `traditional` and `tc` are equivalent. Toggle at runtime with Ctrl+Shift+T. |

Runtime dictionary files are stored at a fixed runtime location and are not configurable:

| File | Path |
| --- | --- |
| Simplified base dictionary file | `%LOCALAPPDATA%\CassotisIme\data\dict_sc.db` |
| Traditional base dictionary file | `%LOCALAPPDATA%\CassotisIme\data\dict_tc.db` |
| User dictionary file | `%LOCALAPPDATA%\CassotisIme\data\user_dict.db` |

---

## `[log]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `enabled` | Enable file logging | `true` / `false` | `false` | `enabled=true` | When `false`, no log file is written. |
| `level` | Log verbosity | `0`=DEBUG, `1`=INFO, `2`=WARN, `3`=ERROR | `1` | `level=1` | Out-of-range values fall back to INFO. |
| `max_size_kb` | Rotation threshold (KB) | Integer | `1024` | `max_size_kb=2048` | When `>0`, the log rotates to `.1` at the size limit. `<=0` disables rotation. |
| `log_path` | Log file path | File path | `<host_exe_dir>\logs\cassotis_ime.log` | `log_path=D:\logs\cassotis_ime.log` | Absolute path recommended. |

---

## Full Example

```ini
[meta]
version=8

[engine]
input_mode=0
full_width_mode=false
punctuation_full_width=true
debug=0

[dictionary]
variant=simplified

[log]
enabled=false
level=1
max_size_kb=1024
```

---

## Common Templates

### Enable debug logging

```ini
[log]
enabled=true
level=0
max_size_kb=4096
log_path=D:\logs\cassotis_ime.log
```

### Use traditional Chinese dictionary

```ini
[dictionary]
variant=traditional
```

### Start in English mode

```ini
[engine]
input_mode=1
```
