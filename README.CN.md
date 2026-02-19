# Cassotis IME（言泉输入法）

<p align="center">
  <img src="cassotis_ime_yanquan.png" alt="Cassotis IME logo" width="280">
</p>

[English](README.md) | 简体中文

> **状态说明：** 项目仍处于非常早期阶段，暂不具备实际可用性；当前不提供预编译二进制文件。

Cassotis IME（言泉输入法）是一个面向 Windows 10/11 的实验性中文拼音输入法项目，主要使用 Delphi，并基于 TSF（Text Services Framework）实现。

## 名称来源

英文名 **Cassotis** 源自 Delphi 神庙内的一眼圣泉。传说女祭司皮媞亚（Pythia）在发布神谕前会饮用此泉水以进入通灵状态——这眼泉被视为预言与灵感的真正源头，与从 Delphi 到人类语言的路径恰好呼应。

中文名**言泉**既契合 Cassotis 作为预言之泉的意象，也取"言如泉涌"之意，寄托了对流畅、智能输入体验的期许。

项目当前重点：

- 建立稳定的 TSF 输入法基础
- 保持模块化架构（TSF DLL + host 进程 + 工具链）
- 在后续阶段探索 AI/LLM 辅助输入能力

## 当前状态

- TSF 文本服务主流程已可用（注册、激活、组合生命周期）。
- TSF DLL 同时支持 Win64 与 Win32（`svr.dll` / `svr32.dll`），host 进程仅保留 Win64。
- 已实现候选窗、翻页、选词与上屏流程。
- 支持词库分离：简体基础库、繁体基础库、用户词库。
- 已实现上下文同步（surrounding text）与按键状态同步。

## 架构

| 模块 | 路径 | 说明 |
|------|------|------|
| TSF COM 服务 | `src/tsf/` | 进程内文本服务，负责组合生命周期（Win64 + Win32）|
| 输入引擎 | `src/engine/` | 拼音解析、候选生成、排序与用户学习 |
| Host 进程 | `src/host/` | Win64 进程，通过 Named Pipe IPC 协调引擎与 UI |
| UI | `src/ui/` | 候选窗与托盘集成 |
| 公共工具 | `src/common/` | 配置、日志、IPC、SQLite 封装、共享类型 |
| 工具链 | `tools/` | 注册、词库构建/导入/诊断等可执行程序 |

## 仓库结构

```
src/          源码
tools/        工具工程（注册、词库构建、诊断）
data/         数据库 schema 与词表源数据
out/          编译产物与构建/管理脚本
third_party/  第三方依赖（SQLite 运行库）
```

## 关键二进制

所有二进制产物位于 `out/` 目录：

| 文件 | 说明 |
|------|------|
| `cassotis_ime_svr.dll` | Win64 TSF 进程内 COM 服务 |
| `cassotis_ime_svr32.dll` | Win32 TSF 进程内 COM 服务 |
| `cassotis_ime_host.exe` | Win64 host 进程 |
| `cassotis_ime_profile_reg.exe` | TSF profile/category 注册工具 |

TSF DLL 与 host 进程均须存在，输入法才能正常工作。

## 快速开始

前置要求：Windows 10/11、Delphi 10.4、以管理员身份打开的 PowerShell 终端。

在 `out/` 目录下依次执行：

```powershell
# 1. 编译所有二进制
.\rebuild_all.ps1

# 2. 向 Windows 注册 TSF（需管理员权限）
.\register_tsf.ps1

# 3. 构建词库
.\rebuild_dict.ps1

# 4. 启动 TSF
.\start_tsf.ps1
```

完整的构建说明（包括增量更新、手动 IDE 构建、脚本参数及问题排查）请参阅 [BUILD.md](BUILD.md)。

## 词库

基础词库来源于 Unicode Unihan 数据：

- 源数据：`data/lexicon/unihan/`
- 生成数据库：`out/data/dict_sc.db`（简体）、`out/data/dict_tc.db`（繁体）
- 用户词库：`out/config/user_dict.db`

若必要的 Unihan 源文件缺失，`rebuild_dict.ps1` 默认会自动从 Unicode 下载。如需纯离线运行，可传入 `-NoAutoDownloadUnihan` 参数。

## 配置

配置文件：`out/config/cassotis_ime.ini`

详细配置项说明：[CONFIGURE.md](CONFIGURE.md)

重点配置项：

- 简/繁体切换（`db_path_sc` / `db_path_tc`）
- 用户词库路径（`user_db_path`）
- 日志与引擎行为开关

## 文档

- 构建说明：[BUILD.md](BUILD.md)
- 第三方组件说明：[THIRD_PARTY.md](THIRD_PARTY.md)

## 许可

本项目采用 GPL-3.0 许可证，完整文本见 [LICENSE](LICENSE)。

请确保第三方声明与 [THIRD_PARTY.md](THIRD_PARTY.md) 保持一致。

## 路线图

- 提升候选排序质量与常用词覆盖
- 强化用户词库质量控制与工具链
- 扩展编辑器/浏览器/IDE 兼容性
- 评估本地 LLM（GGUF）辅助候选方案
