# 配置说明（`cassotis_ime.ini`）

[English](CONFIGURE.md) | 简体中文

本文档说明 `cassotis_ime.ini` 的全部配置项含义、可取值、默认值和示例。
配置解析代码来源：`src/common/nc_config.pas`、`src/common/nc_types.pas`。

## 配置文件位置

默认路径：

```
%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini
```

说明：

- 首次运行时按默认值自动创建。
- 若在旧位置（host 可执行文件同目录，或 `config\` 子目录）发现旧配置文件，会自动迁移。
- `[log]` 段的 `log_path` 字段不按 host 可执行文件目录解析，建议写绝对路径或保留默认值。

---

## `[meta]` 段

| 键 | 含义 | 可取值 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `version` | 配置结构版本号 | 整数 | `16` | 内部升级标记，保存时自动更新，无需手工修改。 |

---

## `[engine]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `input_mode` | 初始输入模式 | `0`=中文, `1`=英文 | `0` | `input_mode=0` | 非 `1` 的值均回退为中文模式。运行时可按 Shift 键切换。 |
| `pinyin_scheme` | 拼音输入方案 | `full-pinyin` / `microsoft-shuangpin` / `xiaohe-shuangpin` / `ziranma-shuangpin` / `sogou-shuangpin` / `ziguang-shuangpin` / `pinyinjiajia-shuangpin` | `full-pinyin` | `pinyin_scheme=microsoft-shuangpin` | 可选择全拼或六种双拼方案，无法识别的值回退为全拼。 |
| `full_width_mode` | 全角输出模式 | `true` / `false` | `false` | `full_width_mode=false` | 开启后 ASCII 字符映射为全角形式。运行时可按 Shift+Space 切换。 |
| `punctuation_full_width` | 中文标点风格 | `true` / `false` | `true` | `punctuation_full_width=true` | 开启后标点键输出中文全角符号。运行时可按 Ctrl+句号 切换。 |
| `debug` | 调试模式 | `0` / `1` | `0` | `debug=1` | 开启后候选窗显示得分与分词路径信息。 |

> **说明：** 候选数量、候选外观和快捷键均可通过设置界面修改；快捷键统一保存在 `[shortcuts]` 段。

双拼输入遵循以下规则：

- 修改方案后立即生效，并清空未上屏内容，避免混用新旧键位。
- 候选查询和用户学习统一使用解码后的标准全拼，因此所有拼音方案共享候选排序和用户数据。
- 单引号可显式分隔音节。微软、搜狗和紫光双拼中的分号仅在作为双拼码第二键时表示 `ing`，其他位置仍作为标点。
- 状态浮窗以 `拼`、`微`、`鹤`、`自`、`搜`、`紫`、`加` 分别表示全拼、微软、小鹤、自然码、搜狗、紫光和拼音加加。

---

## `[pinyin]` 段

| 键 | 含义 | 可取值 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `fuzzy_enabled` | 模糊拼音总开关 | `true` / `false` | `false` | 开启后仅应用 `fuzzy_rules` 中列出的规则。 |
| `fuzzy_rules` | 模糊拼音规则 | 逗号分隔的规则名 | 空 | 支持 `z-zh`、`c-ch`、`s-sh`、`l-n`、`f-h`、`r-l`、`an-ang`、`en-eng`、`in-ing`、`ian-iang`、`uan-uang`。 |

---

## `[appearance]` 段

| 键 | 含义 | 可取值 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `candidate_font_name` | 候选字体 | 已安装字体名称 | `Microsoft YaHei UI` | 也可在设置界面选择。 |
| `candidate_font_size` | 候选字号 | `7` 至 `18` | `12` | 设置界面使用预设档位；INI 中的值会限制到有效范围。 |
| `candidate_page_size` | 每页候选数 | `3` 至 `9` | `9` | 只改变每页显示数量，不改变候选池总数。 |
| `candidate_expand_on_paging` | 翻页时展开多行候选 | `true` / `false` | `false` | 按上下箭头或向后翻页即可展开，最多同时显示三页；上下箭头和翻页键切换行并保留选中编号，目标行不足时选中最后一项，左右箭头仍逐项移动。第一页按上箭头也会展开，但不循环到末页。仅当前行显示数字，其他行保留数字占位，切换行时字词位置不变。数字选词只作用于当前行，Tab 区保持不变。 |
| `candidate_color_scheme` | 候选窗配色 | `clear-white` / `moon-white` / `celadon` / `clear-blue` / `pine-ink` / `indigo-night` | `clear-white` | 对应六套内置浅色及深色主题。 |

---

## `[shortcuts]` 段

| 键 | 含义 | 可取值 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `input_mode_toggle` | 中英文模式切换 | 快捷键文本 | `Shift` | 单独按下 Shift 时切换。 |
| `punctuation_toggle` | 中英文标点切换 | 快捷键文本 | `Ctrl+.` | 切换中文全角标点与英文标点。 |
| `dictionary_variant_toggle` | 简繁词库切换 | 快捷键文本 | `Ctrl+Shift+T` | 在简体与繁体词库之间切换。 |
| `full_width_toggle` | 全角模式切换 | 快捷键文本 | `Shift+Space` | 切换 ASCII 半角与全角输出。 |
| `open_settings` | 打开设置 | 快捷键文本 | `Ctrl+Shift+F10` | 打开设置窗口。 |
| `candidate_page_keys` | 候选翻页按键方案 | `minus-plus` / `brackets` / `comma-period` / `shift-tab` | `minus-plus` | 分别表示 `-/=`、`[/]`、`,/.`、`Shift+Tab/Tab`。 |
| `one_key_completion_key` | 一键补全触发按键 | `tab` / `backtick` | `tab` | 输入至少两个完整音节后，接受候选窗底部的唯一补全。补全依次取自用户词、基础词库和离线生成的强转移证据；语言模型随后在后台重新排序，可能替换已显示的补全，长句中的续写也由它给出。强转移补全使用主题强调色，接受后不写入普通用户词；`backtick` 表示反引号键 `` ` ``。 |

当 `one_key_completion_key=tab` 时，`candidate_page_keys=shift-tab` 会与一键补全冲突，因此该翻页方案在设置界面不可选；若 INI 中同时配置这两个值，翻页方案会自动规范化为 `minus-plus`。

---

## `[dictionary]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `variant` | 词库变体（简/繁） | `simplified` / `traditional` / `tc` | `simplified` | `variant=simplified` | `traditional` 与 `tc` 等价。运行时可按 Ctrl+Shift+T 切换。 |

运行时词库文件存储在固定运行时路径，不可在配置文件中修改：

| 文件 | 路径 |
| --- | --- |
| 简体基础词库文件 | `%LOCALAPPDATA%\CassotisIme\data\dict_sc.db` |
| 繁体基础词库文件 | `%LOCALAPPDATA%\CassotisIme\data\dict_tc.db` |
| 用户词库文件 | `%LOCALAPPDATA%\CassotisIme\data\user_dict.db` |

---

## `[log]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `enabled` | 是否启用日志 | `true` / `false` | `false` | `enabled=true` | 关闭时不写日志文件。 |
| `level` | 日志级别 | `0`=DEBUG, `1`=INFO, `2`=WARN, `3`=ERROR | `1` | `level=1` | 超出范围回退为 INFO。 |
| `max_size_kb` | 日志轮转阈值（KB） | 整数 | `1024` | `max_size_kb=2048` | `>0` 时超限轮转到 `.1`；`<=0` 不轮转。 |
| `log_path` | 日志文件路径 | 文件路径 | `<host 可执行文件目录>\logs\cassotis_ime.log` | `log_path=D:\logs\cassotis_ime.log` | 建议使用绝对路径。 |

---

## 完整示例

```ini
[meta]
version=16

[engine]
input_mode=0
pinyin_scheme=full-pinyin
full_width_mode=false
punctuation_full_width=true
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

## 常见场景模板

### 启用调试日志

```ini
[log]
enabled=true
level=0
max_size_kb=4096
log_path=D:\logs\cassotis_ime.log
```

### 使用繁体词库

```ini
[dictionary]
variant=traditional
```

### 启动时默认英文模式

```ini
[engine]
input_mode=1
```

### 使用紫光双拼

```ini
[engine]
pinyin_scheme=ziguang-shuangpin
```

### 使用拼音加加

```ini
[engine]
pinyin_scheme=pinyinjiajia-shuangpin
```
