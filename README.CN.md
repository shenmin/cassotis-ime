# Cassotis IME（言泉输入法）

[English](README.md) | 简体中文

> 项目状态说明：本项目仍处于非常早期阶段，暂不具备实际可用性；当前不提供预编译二进制文件。

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
- `tests/` 单元与性能测试工程
- `third_party/` 第三方二进制/源码（例如 sqlite 运行库包）

## 关键二进制
- `cassotis_ime_svr.dll`（Win64 TSF 进程内 COM 服务）
- `cassotis_ime_svr32.dll`（Win32 TSF 进程内 COM 服务）
- `cassotis_ime_host.exe`（Win64 host 进程）
- `cassotis_ime_profile_reg.exe`（TSF profile/category 注册工具）

若缺少 TSF DLL 或 host 进程，输入法无法正常工作。

## 构建与运行（快速开始）
前置要求：
- Windows 10/11
- Delphi 10.4
- SQLite 运行库（`sqlite3_64.dll`）

在 `out/` 目录执行：

```powershell
.\rebuild_all.ps1
.\register_tsf.ps1 -dll_path .\cassotis_ime_svr.dll
.\rebuild_dict.ps1
```

完整构建说明见 `BUILD.md`。

## 词库流程
当前基础词库流程基于 Unihan：
- 源数据位于 `data/lexicon/unihan/`
- 生成数据库位于 `out/data/`（如 `dict_sc.db`、`dict_tc.db`）
- 用户词库默认位于 `out/config/user_dict.db`

词库重建入口：

```powershell
.\rebuild_dict.ps1
```

## 配置
默认配置文件：
- `out/config/cassotis_ime.ini`

重点配置项包括：
- 简/繁体切换
- 基础词库路径（`db_path_sc`、`db_path_tc`）
- 用户词库路径（`user_db_path`）
- 日志与引擎行为开关

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
