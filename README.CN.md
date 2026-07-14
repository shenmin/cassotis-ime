# Cassotis IME（言泉输入法）

<p align="center">
  <img src="cassotis_ime_yanquan.png" alt="Cassotis IME logo" width="280">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
</p>
<p align="center">
  <img src="snapshot.png" alt="Cassotis IME snapshot" width="810">
</p>

[English](README.md) | 简体中文

Cassotis IME（言泉输入法）是一个面向 Windows 10/11 的实验性中文拼音输入法项目，主要使用 Delphi，并基于 TSF（Text Services Framework）实现。

## 名称来源
英文名 **Cassotis** 源自 Delphi 神庙内的一眼圣泉。传说女祭司皮媞亚（Pythia）在发布神谕前会饮用此泉水，以进入通灵状态。这眼泉水被视为预言与灵感的真正源头，也是神谕诞生之地，呼应了从 Delphi 到人类语言的路径。

中文名 **言泉** 既契合 Cassotis 作为预言之泉的意象，也取“言如泉涌”的寓意，寄托了对流畅、智能输入体验的期许。

项目当前重点：
- 建立稳定的 TSF 输入法基础；
- 保持模块化架构（TSF DLL + host 进程 + 工具链）；
- 在后续阶段探索 AI/LLM 辅助输入能力。

## 当前状态
- TSF 文本服务主流程已可用（注册、激活、组合生命周期）。
- TSF DLL 同时支持 Win64 与 Win32（`svr.dll` / `svr32.dll`），host 进程仅保留 Win64。
- 已实现候选窗、翻页、选词与上屏流程。
- 支持词库分离：简体基础库、繁体基础库、用户词库。
- 已实现上下文同步（surrounding text）与按键状态同步。

## 架构
- `src/tsf`：TSF COM 进程内服务（文本服务接入层）。
- `src/engine`：拼音解析、候选生成、排序与用户学习。
- `src/host`：外部 host 进程，负责引擎/UI 协同。
- `src/ui`：候选窗与托盘 UI。
- `src/common`：配置、日志、IPC、sqlite 封装与公共工具。
- `tools`：注册、词库构建/导入/诊断等工具程序。

## 仓库结构
- `src/` 源码
- `tools/` 工具工程与辅助可执行程序
- `data/` schema 与词表源数据
- `out/` 构建/注册/重建/测试脚本
- `third_party/` 第三方二进制/源码（例如 sqlite 运行库包）

## 关键二进制
- `cassotis_ime_svr.dll`（Win64 TSF 进程内 COM 服务）
- `cassotis_ime_svr32.dll`（Win32 TSF 进程内 COM 服务）
- `cassotis_ime_host.exe`（Win64 host 进程）
- `cassotis_ime_tray_host.exe`（Win64 托盘/状态宿主，负责托盘菜单、浮动状态窗口和输入状态显示）
- `cassotis_ime_profile_reg.exe`（TSF profile/category 注册工具）

若缺少 TSF DLL 或主 host 进程，输入法无法正常工作。若缺少托盘/状态宿主，核心输入路径可能仍可运行，但托盘菜单、浮动状态窗口和状态显示不可用。

## 构建与运行（快速开始）
前置要求：
- Windows 10/11
- Delphi 10.4
- SQLite 运行库（`sqlite3_64.dll`）

在 `out/` 目录执行：

```powershell
.\rebuild_all.ps1
.\cassotis_ime_profile_reg.exe register_tsf -dll_path .\cassotis_ime_svr.dll
.\rebuild_dict.ps1
```

完整构建说明见 `BUILD.md`。

## 词库流程
当前基础词库流程从 [cassotis-lexicon](https://github.com/shenmin/cassotis-lexicon) 项目导入生成产物：
- 导入输入文件：`dict_unihan_sc.txt`、`dict_unihan_tc.txt`、`dict_clean_sc.txt`、`dict_clean_tc.txt`
- 运行时数据库重建到 `%LOCALAPPDATA%\CassotisIme\data\`（如 `dict_sc.db`、`dict_tc.db`）
- 用户词库默认位于 `%LOCALAPPDATA%\CassotisIme\data\user_dict.db`

词库重建入口：

```powershell
.\rebuild_dict.ps1
```

## 长句基准测试结果
测试方法、语料来源和评分规则见 [BENCHMARK.CN.md](BENCHMARK.CN.md)。

语料：开发者自己的小说著作 [**《永恒的舞动》**](https://www.qidian.com/book/1037259117/) 中 16,300 条符合条件的中文句子。

| 版本 | Top1 | Top2 | Mean (ms) | P95 (ms) | Max (ms) |
|---|---:|---:|---:|---:|---:|
| `v1.0.0` | 6106/16300 (37.46%) | 6857/16300 (42.07%) | 71.49 | 219 | 5344 |
| `v0.8.5` | 6097/16300 (37.40%) | 6847/16300 (42.01%) | 520.05 | 1203 | 13297 |
| `v0.7.0` | 5368/16300 (32.93%) | 6110/16300 (37.48%) | — | — | — |
| `v0.6.0` | 4905/16300 (30.09%) | 5378/16300 (32.99%) | — | — | — |
| `v0.5.0` | 4834/16300 (29.66%) | 5243/16300 (32.17%) | — | — | — |
| `v0.4.0` | 4371/16300 (26.82%) | 4744/16300 (29.10%) | — | — | — |
| `v0.3.1` | 3845/16300 (23.59%) | 4651/16300 (28.53%) | — | — | — |
| `v0.2.0` | 2671/16300 (16.39%) | 2863/16300 (17.56%) | — | — | — |

延迟数据为引擎整句直设解码耗时：一次性设置完整拼音并读取候选，不代表逐键输入到候选窗口显示的端到端延迟。`—` 表示该版本没有按此延迟口径进行测试。完整方法见 [BENCHMARK.CN.md](BENCHMARK.CN.md)。

## 配置
默认配置文件：
- `%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini`

重点配置项包括：
- 简/繁体切换（`variant`）
- 全角 / 标点模式
- 调试日志与日志路径

运行时词库路径固定在 `%LOCALAPPDATA%\CassotisIme\data\` 下，不再通过 INI 配置。

## 文档
- 英文主文档：`README.md`
- 构建说明：`BUILD.md`
- 第三方组件说明：`THIRD_PARTY.md`

## 许可
本项目采用 GPL-3.0 许可证，完整文本见 `LICENSE`。

请确保第三方声明与归属信息与 `THIRD_PARTY.md` 保持一致。

## 路线图
- 提升候选排序质量与常用词覆盖
- 强化用户词库质量控制与工具链
- 扩展编辑器/浏览器/IDE 兼容性矩阵
- 评估本地 LLM（GGUF）辅助候选方案
