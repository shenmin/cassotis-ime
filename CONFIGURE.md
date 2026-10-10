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
| `version` | Config schema version | Integer | `16` | Internal migration marker. Updated automatically on save. Do not edit manually. |

---

## `[engine]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `input_mode` | Initial input mode | `0` = Chinese, `1` = English | `0` | `input_mode=0` | Any value other than `1` defaults to Chinese. Can be toggled at runtime with the Shift key. |
| `pinyin_scheme` | Pinyin input scheme | `full-pinyin` / `microsoft-shuangpin` / `xiaohe-shuangpin` / `ziranma-shuangpin` / `sogou-shuangpin` / `ziguang-shuangpin` / `pinyinjiajia-shuangpin` | `full-pinyin` | `pinyin_scheme=microsoft-shuangpin` | Selects Full Pinyin or one of six Double Pinyin layouts. Unknown values fall back to Full Pinyin. |
| `full_width_mode` | Full-width output | `true` / `false` | `false` | `full_width_mode=false` | When enabled, ASCII characters are mapped to full-width forms. Toggle at runtime with Shift+Space. |
| `punctuation_full_width` | Chinese punctuation style | `true` / `false` | `true` | `punctuation_full_width=true` | When enabled, punctuation keys produce Chinese full-width symbols. Toggle at runtime with Ctrl+Period. |
| `decimal_period_after_digit` | Decimal point after consecutively typed digits | `true` / `false` | `true` | `decimal_period_after_digit=true` | In Chinese punctuation mode, pressing the period key immediately after typing a digit produces `.` rather than `。`. Existing or pasted text is not considered; moving the caret or pressing another key cancels the conversion. The checkbox is disabled in English punctuation mode without clearing the saved preference. |
| `debug` | Debug mode | `0` / `1` | `0` | `debug=1` | Shows candidate scores and path info in the candidate window. |

> **Note:** Candidate count, candidate appearance, and shortcuts can be changed in Settings. Shortcut values are stored in `[shortcuts]`.

Double Pinyin follows these rules:

- Changing the scheme takes effect immediately and clears any active composition to avoid mixing layouts.
- Candidate lookup and user learning use decoded canonical Full Pinyin, so all Pinyin schemes share ranking and user data.
- An apostrophe explicitly separates syllables. In Microsoft, Sogou, and Ziguang Double Pinyin, semicolon represents the `ing` final only as the second key of a pair; elsewhere it remains punctuation.
- The status widget uses `拼`, `微`, `鹤`, `自`, `搜`, `紫`, and `加` for Full Pinyin, Microsoft, Xiaohe, Ziranma, Sogou, Ziguang, and Pinyin Jiajia respectively.

---

## `[pinyin]`

| Key | Meaning | Allowed values | Default | Notes |
| --- | --- | --- | --- | --- |
| `fuzzy_enabled` | Master fuzzy-Pinyin switch | `true` / `false` | `false` | When enabled, only rules listed in `fuzzy_rules` are applied. |
| `fuzzy_rules` | Enabled fuzzy-Pinyin rules | Comma-separated rule names | Empty | Supports `z-zh`, `c-ch`, `s-sh`, `l-n`, `f-h`, `r-l`, `an-ang`, `en-eng`, `in-ing`, `ian-iang`, and `uan-uang`. |

---

## `[appearance]`

| Key | Meaning | Allowed values | Default | Notes |
| --- | --- | --- | --- | --- |
| `candidate_font_name` | Candidate font | Installed font family | `Microsoft YaHei UI` | Can also be selected in Settings. |
| `candidate_font_size` | Candidate font size | `7` through `18` | `12` | Settings uses predefined levels; INI values are clamped to the valid range. |
| `candidate_page_size` | Candidates per page | `3` through `9` | `9` | Changes page size without reducing the total candidate pool. |
| `candidate_expand_on_paging` | Expand candidate rows when paging | `true` / `false` | `false` | Press Up/Down or page forward to expand up to three pages. Up/Down and page keys move between rows while keeping the selected number, or selecting the last item if the target row is shorter. Up on the first row expands without wrapping to the last page. Left/Right still move by one item. Only the active row shows numbers; other rows reserve the same space so words do not shift when switching rows. Number keys select from the active row only; the Tab area is unchanged. |
| `candidate_color_scheme` | Candidate window theme | `clear-white` / `moon-white` / `celadon` / `clear-blue` / `pine-ink` / `indigo-night` | `clear-white` | Corresponds to the six built-in light and dark themes. |

---

## `[shortcuts]`

| Key | Meaning | Allowed values | Default | Notes |
| --- | --- | --- | --- | --- |
| `input_mode_toggle` | Chinese/English mode toggle | Shortcut text | `Shift` | Press Shift alone to toggle. |
| `punctuation_toggle` | Chinese/English punctuation toggle | Shortcut text | `Ctrl+.` | Toggles full-width Chinese and English punctuation. |
| `dictionary_variant_toggle` | Simplified/Traditional dictionary toggle | Shortcut text | `Ctrl+Shift+T` | Switches between simplified and traditional dictionaries. |
| `full_width_toggle` | Full-width mode toggle | Shortcut text | `Shift+Space` | Toggles half-width and full-width ASCII output. |
| `open_settings` | Open Settings | Shortcut text | `Ctrl+Shift+F10` | Opens the Settings window. |
| `candidate_page_keys` | Candidate paging key scheme | `minus-plus` / `brackets` / `comma-period` / `shift-tab` | `minus-plus` | Represents `-/=`, `[/]`, `,/.`, or `Shift+Tab/Tab`. |
| `one_key_completion_key` | One-key completion trigger | `tab` / `backtick` | `tab` | After at least two complete syllables, accepts the single completion shown at the bottom of the candidate window. Sources are checked in order: user lexicon, base lexicon, then the offline-generated strong-transition index; the language model then reranks the completion in the background and may replace it, and in a long sentence it supplies the continuation. Transition completions use the theme accent and are not learned as ordinary user words. `backtick` means the `` ` `` key. |

When `one_key_completion_key=tab`, `candidate_page_keys=shift-tab` conflicts with completion. Settings therefore hides that paging option, and an INI file containing both values is normalized to `minus-plus`.

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
version=16

[engine]
input_mode=0
pinyin_scheme=full-pinyin
full_width_mode=false
punctuation_full_width=true
decimal_period_after_digit=true
debug=0

[pinyin]
fuzzy_enabled=false
fuzzy_rules=

[appearance]
candidate_font_name=Microsoft YaHei UI
candidate_font_size=12
candidate_page_size=9
candidate_expand_on_paging=false
candidate_color_scheme=clear-white

[dictionary]
variant=simplified

[shortcuts]
input_mode_toggle=Shift
punctuation_toggle=Ctrl+.
dictionary_variant_toggle=Ctrl+Shift+T
full_width_toggle=Shift+Space
open_settings=Ctrl+Shift+F10
candidate_page_keys=minus-plus
one_key_completion_key=tab

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

### Use Ziguang Double Pinyin

```ini
[engine]
pinyin_scheme=ziguang-shuangpin
```

### Use Pinyin Jiajia

```ini
[engine]
pinyin_scheme=pinyinjiajia-shuangpin
```
