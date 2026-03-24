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
| `version` | 配置结构版本号 | 整数 | `8` | 内部升级标记，保存时自动更新，无需手工修改。 |

---

## `[engine]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `input_mode` | 初始输入模式 | `0`=中文, `1`=英文 | `0` | `input_mode=0` | 非 `1` 的值均回退为中文模式。运行时可按 Shift 键切换。 |
| `full_width_mode` | 全角输出模式 | `true` / `false` | `false` | `full_width_mode=false` | 开启后 ASCII 字符映射为全角形式。运行时可按 Shift+Space 切换。 |
| `punctuation_full_width` | 中文标点风格 | `true` / `false` | `true` | `punctuation_full_width=true` | 开启后标点键输出中文全角符号。运行时可按 Ctrl+句号 切换。 |
| `debug` | 调试模式 | `0` / `1` | `0` | `debug=1` | 开启后候选窗显示得分与分词路径信息。 |

> **说明：** 每页候选数（固定为 9）、分段候选增强及键盘快捷键开关均为运行时固定值，不通过 INI 文件配置。

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
