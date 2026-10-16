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
| `punctuation_full_width` | Chinese punctuation style | `true` / `false` | `true` | `punctuation_full_width=true` | Uses Chinese punctuation, except for the half-width symbols in `[punctuation]`. Toggle at runtime with Ctrl+Period. |
| `decimal_period_after_digit` | Decimal point after consecutively typed digits | `true` / `false` | `true` | `decimal_period_after_digit=true` | In Chinese punctuation mode, pressing the period key immediately after typing a digit produces `.` rather than `。`. Existing or pasted text is not considered; moving the caret or pressing another key cancels the conversion. The checkbox is disabled in English punctuation mode without clearing the saved preference. |
| `debug` | Debug mode | `0` / `1` | `0` | `debug=1` | Shows candidate scores and path info in the candidate window. |

> **Note:** Candidate count, candidate appearance, and shortcuts can be changed in Settings. Shortcut values are stored in `[shortcuts]`.

In Settings > General, edit **保持半角的符号** (symbols to keep in ASCII), or select **Markdown 预设** (Markdown preset) or **标准中文标点** (standard Chinese punctuation). The default preset keeps these symbols in ASCII while commas, periods, question marks, exclamation marks, parentheses and quotation marks retain their Chinese forms, and the backslash gives the enumeration comma `、`:

```text
-#*+_=`~[]<>|@
```

The list is inactive and cannot be edited in English punctuation or full-width input mode, but its saved value is preserved. Candidate paging, completion and Pinyin separator shortcuts still take precedence during composition.

Double Pinyin follows these rules:

- Changing the scheme takes effect immediately and clears any active composition to avoid mixing layouts.
- Candidate lookup and user learning use decoded canonical Full Pinyin, so all Pinyin schemes share ranking and user data.
- An apostrophe explicitly separates syllables. In Microsoft, Sogou, and Ziguang Double Pinyin, semicolon represents the `ing` final only as the second key of a pair; elsewhere it remains punctuation.
- The status widget uses `拼`, `微`, `鹤`, `自`, `搜`, `紫`, and `加` for Full Pinyin, Microsoft, Xiaohe, Ziranma, Sogou, Ziguang, and Pinyin Jiajia respectively.

---

## `[punctuation]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `ascii_symbols` | Symbols to keep in ASCII | ASCII punctuation list; may be empty | Markdown preset | `ascii_symbols=-#*` | Applies only with Chinese punctuation and half-width input. Clear the list for standard Chinese punctuation, or remove individual symbols: removing `#` restores `＃`. Older configurations without this key also use the Markdown preset. |

---

## `[input]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `auto_english` | English recognition in Chinese mode | `true` / `false` | `true` | `auto_english=false` | Applies only in Chinese mode with Full Pinyin and half-width input. English words and names, input typed with a capital, and letters committed as letters before can appear before the numbered candidates, and Space commits them as typed; when the input also has a Chinese reading, the language model weighs the two with the preceding text. When off, this candidate is not shown. It can also be cleared in Settings > General > 输入 (input) as **识别英文单词，空格直接上屏** (recognize English words, Space commits them). Double Pinyin is not affected. |

---

## `[custom_phrases]`

Manage shortcut codes and phrase text in **Settings > 自定义短语** (Custom phrases), immediately before the Advanced page. Add, edit, delete, reorder, or import/export a JSON file. Imports append to the existing list rather than replacing it.

An exact shortcut match takes priority in the **one-key completion area**, using the normal text color. Press the completion key (Tab by default) to insert the literal phrase. Numbered candidates, Space, and number-key selection are unchanged. Typing beyond the shortcut ends the match; automatic completion resumes when no custom phrase matches.

Codes contain 1–32 ASCII letters and are case-insensitive. Full Pinyin and Double Pinyin both match the actual typed letters, without fuzzy matching. Duplicate codes are allowed, but Settings warns that only the first listed phrase appears; use Move up/Move down to change that priority. Up to 1,024 phrases are supported, each up to 4,096 characters. These manually defined phrases are separate from learned user words and do not train ordinary word ranking. Long previews are shortened without truncating the inserted text.

| Key | Meaning | Default | Example |
| --- | --- | --- | --- |
| `items` | Ordered JSON array of `[shortcut, phrase text]` pairs | `[]` | `items=[["cx","春眠不觉晓，处处闻啼鸟"]]` |

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
| `one_key_completion_key` | One-key completion trigger | `tab` / `backtick` | `tab` | Accepts the single result in the one-key completion area. An exact custom-phrase match takes priority over automatic completion and has no syllable-count requirement. Otherwise, the existing predictive completion applies. `backtick` means the `` ` `` key. |

When `one_key_completion_key=tab`, `candidate_page_keys=shift-tab` conflicts with completion. Settings therefore hides that paging option, and an INI file containing both values is normalized to `minus-plus`.

---

## `[dictionary]`

| Key | Meaning | Allowed values | Default | Example | Notes |
| --- | --- | --- | --- | --- | --- |
| `variant` | Dictionary variant | `simplified` / `traditional` / `tc` | `simplified` | `variant=simplified` | `traditional` and `tc` are equivalent. Toggle at runtime with Ctrl+Shift+T. |

Installed base dictionaries ship with each runtime version and are read-only for all Windows accounts. Learned words remain private to each account. These paths are not configurable:

| File | Path |
| --- | --- |
| Simplified base dictionary file | `<current installed runtime>\base_dict\dict_sc.db` |
| Traditional base dictionary file | `<current installed runtime>\base_dict\dict_tc.db` |
| User dictionary file | `%LOCALAPPDATA%\CassotisIme\data\user_dict.db` |

Development builds, which have no `base_dict` beside the program, and earlier installed versions use `dict_sc.db` and `dict_tc.db` under `%LOCALAPPDATA%\CassotisIme\data`. Once a new version is installed, the copies of these two base dictionaries that earlier versions left there in each account are removed (except development dictionaries built by `out\rebuild_dict.ps1`); user dictionaries and learned data are neither removed nor shared between accounts.

---

## `[log]`

Logging options are in **Settings > 高级** (Advanced), below Debug and above Configuration tools.

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

[punctuation]
ascii_symbols=-#*+_=`~[]<>|@

[input]
auto_english=true

[custom_phrases]
items=[]

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
