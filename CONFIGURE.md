# 配置说明（`cassotis_ime.ini`）

本文档说明 `cassotis_ime.ini` 的全部配置项含义、可取值、默认值和示例。  
配置解析代码来源：`src/common/nc_config.pas`、`src/common/nc_types.pas`。

## 配置文件位置

默认路径：

- `<程序目录>\config\cassotis_ime.ini`

说明：

- 若配置文件不存在，程序会按默认值自动创建。
- `dictionary` 与 `ai` 段中的路径字段支持相对路径；相对路径会按“程序目录”解析为绝对路径。
- `log.log_path` 不做同样的路径归一化，建议写绝对路径或确认工作目录。

---

## `[meta]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `version` | 配置结构版本号 | 整数 | `5` | `version=5` | 内部升级用。版本低于当前版本时会触发重写保存。通常不需要手工修改。 |

---

## `[engine]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `input_mode` | 初始输入模式 | `0`=中文, `1`=英文 | `0` | `input_mode=0` | 非 `1` 的值都会回退为中文模式。 |
| `max_candidates` | 每页候选数量 | 整数 | `9` | `max_candidates=9` | `<=0` 时运行时回退为默认页大小 `9`。 |
| `enable_ai` | 是否启用 AI 候选 | `true`/`false` | `false` | `enable_ai=true` | 仅控制是否启用 AI provider。 |
| `enable_ctrl_space_toggle` | 是否允许 `Ctrl+Space` 切换中英 | `true`/`false` | `false` | `enable_ctrl_space_toggle=true` | 关闭时 `Ctrl+Space` 不触发该切换逻辑。 |
| `enable_shift_space_full_width_toggle` | 是否允许 `Shift+Space` 切换全角模式 | `true`/`false` | `true` | `enable_shift_space_full_width_toggle=true` | 影响 `full_width_mode` 的快捷切换。 |
| `enable_ctrl_period_punct_toggle` | 是否允许 `Ctrl+.` 切换中英文标点 | `true`/`false` | `true` | `enable_ctrl_period_punct_toggle=true` | 影响 `punctuation_full_width` 的快捷切换。 |
| `full_width_mode` | 全角输入模式开关 | `true`/`false` | `false` | `full_width_mode=false` | 开启后，ASCII 可映射为全角字符输出。 |
| `punctuation_full_width` | 中文标点输出开关 | `true`/`false` | `true` | `punctuation_full_width=true` | 控制标点符号是全角还是半角。 |
| `enable_segment_candidates` | 是否启用拼音分段候选增强 | `true`/`false` | `true` | `enable_segment_candidates=true` | 开启后会做分段候选补充与融合。 |

---

## `[dictionary]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `variant` | 词库变体（简/繁） | `simplified` / `traditional` / `tc` | `simplified` | `variant=simplified` | `traditional` 与 `tc` 等价；其他值回退 `simplified`。 |
| `db_path_sc` | 简体基础词库路径 | 文件路径 | `<程序目录>\data\dict_sc.db` | `db_path_sc=data\dict_sc.db` | 支持相对路径。 |
| `db_path_tc` | 繁体基础词库路径 | 文件路径 | `<程序目录>\data\dict_tc.db` | `db_path_tc=data\dict_tc.db` | 支持相对路径。 |
| `user_db_path` | 用户词库路径 | 文件路径 | `<程序目录>\config\user_dict.db` | `user_db_path=config\user_dict.db` | 支持相对路径。 |
| `db_path` | 旧版兼容键（简体库） | 文件路径 | 无 | `db_path=data\dict_sc.db` | 仅兼容老配置；若 `db_path_sc` 缺失会读取它。新配置请使用 `db_path_sc`。 |

---

## `[ai]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `llama_backend` | Llama 后端选择 | `auto` / `cpu` / `cuda` / `gpu` | `auto` | `llama_backend=cuda` | `gpu` 会按 `cuda` 处理；其他值回退 `auto`。 |
| `llama_runtime_dir_cpu` | CPU 运行时目录 | 目录路径 | Win64: `<程序目录>\llama\win64` | `llama_runtime_dir_cpu=llama\win64` | 支持相对路径。 |
| `llama_runtime_dir_cuda` | CUDA 运行时目录 | 目录路径 | `<程序目录>\llama\win64-cuda` | `llama_runtime_dir_cuda=llama\win64-cuda` | 支持相对路径。 |
| `llama_model_path` | GGUF 模型文件路径 | 文件路径 | `<程序目录>\models\llama.gguf` | `llama_model_path=models\gpt-oss-20b-Q5_K_M.gguf` | 支持相对路径；默认会确保 `models` 目录存在。 |
| `request_timeout_ms` | 单次 AI 请求超时（毫秒） | 正整数 | `1200` | `request_timeout_ms=1500` | `<=0` 会回退到 `1200`。 |

---

## `[log]` 段

| 键 | 含义 | 可取值 | 默认值 | 示例 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `enabled` | 是否启用日志 | `true`/`false` | `false` | `enabled=true` | 关闭时不写日志文件。 |
| `level` | 日志级别 | `0`=DEBUG, `1`=INFO, `2`=WARN, `3`=ERROR | `1` | `level=1` | 超出范围会回退默认 `INFO`。 |
| `max_size_kb` | 日志轮转阈值（KB） | 整数 | `1024` | `max_size_kb=2048` | `>0` 时超限轮转到 `.1`；`<=0` 可视为不轮转。 |
| `log_path` | 日志文件路径 | 文件路径 | `<程序目录>\logs\cassotis_ime.log` | `log_path=D:\cassotis_ime\out\logs\cassotis_ime.log` | 建议使用绝对路径。 |

---

## 完整示例（推荐起点）

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

## 常见场景模板

### 1. 仅词库，不启用 AI

```ini
[engine]
enable_ai=false
max_candidates=9
```

### 2. 固定使用 CUDA 后端

```ini
[engine]
enable_ai=true

[ai]
llama_backend=cuda
llama_runtime_dir_cuda=llama\win64-cuda
llama_model_path=models\your-model.gguf
request_timeout_ms=1500
```

### 3. 调试日志

```ini
[log]
enabled=true
level=0
max_size_kb=4096
log_path=D:\cassotis_ime\out\logs\cassotis_ime.log
```

