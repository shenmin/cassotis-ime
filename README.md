# Cassotis IME

<p align="center">
  <img src="cassotis_ime_yanquan.png" alt="Cassotis IME logo" width="280">
</p>

English | [简体中文](README.CN.md)

> **Status:** Early stage — not yet practical for daily use. Prebuilt binaries are not provided.

Cassotis IME (言泉输入法) is an experimental Chinese Pinyin input method for Windows 10/11, built primarily with Delphi on top of TSF (Text Services Framework).

## Name Origin

The English name **Cassotis** comes from the sacred spring inside the Temple of Delphi. Before delivering oracles, the priestess Pythia was said to drink from this spring to enter a prophetic state — the spring was regarded as the true source of prophecy and inspiration, resonating with the path from Delphi to human language.

The Chinese name **言泉** (Yanquan, "Spring of Words") matches Cassotis as a prophetic spring, while also evoking **言如泉涌** ("words flowing like a spring") — reflecting the goal of a fluent and intelligent input experience.

Project focus:

- Build a stable TSF-based IME foundation
- Keep the architecture modular (TSF DLL + host process + tools)
- Explore AI/LLM-assisted input in later stages

## Current Status

- TSF text service pipeline is available (registration, activation, composition lifecycle).
- TSF binaries support Win64 and Win32 (`svr.dll` / `svr32.dll`); host process is Win64 only.
- Candidate window, paging, selection, and commit flow are implemented.
- Dictionary split is supported: simplified base DB, traditional base DB, and user DB.
- Surrounding-text/context synchronization and key state synchronization are implemented.

## Architecture

| Module | Path | Description |
|--------|------|-------------|
| TSF COM server | `src/tsf/` | In-proc text service; handles composition lifecycle (Win64 + Win32) |
| Input engine | `src/engine/` | Pinyin parsing, candidate generation, ranking, user learning |
| Host process | `src/host/` | Win64 process for engine/UI orchestration over Named Pipe IPC |
| UI | `src/ui/` | Candidate window and tray integration |
| Common | `src/common/` | Config, logging, IPC, SQLite wrapper, shared types |
| Tools | `tools/` | Registration, dictionary build/import/diagnostics executables |

## Repository Layout

```
src/          source code
tools/        utility projects (registration, dictionary build, diagnostics)
data/         database schema and lexicon source data
out/          compiled binaries and build/management scripts
third_party/  vendored dependencies (SQLite runtime)
```

## Key Binaries

All binaries are produced under `out/`:

| Binary | Description |
|--------|-------------|
| `cassotis_ime_svr.dll` | Win64 TSF in-proc COM server |
| `cassotis_ime_svr32.dll` | Win32 TSF in-proc COM server |
| `cassotis_ime_host.exe` | Win64 host process |
| `cassotis_ime_profile_reg.exe` | TSF profile/category registration utility |

Both the TSF DLL and the host process must be present for the IME to work.

## Quick Start

Prerequisites: Windows 10/11, Delphi 10.4, an administrator PowerShell session.

Run the following from `out/` in order:

```powershell
# 1. Build all binaries
.\rebuild_all.ps1

# 2. Register TSF with Windows (requires administrator)
.\register_tsf.ps1

# 3. Build dictionaries
.\rebuild_dict.ps1

# 4. Start TSF
.\start_tsf.ps1
```

For the complete build guide — including incremental updates, manual IDE builds, script parameters, and troubleshooting — see [BUILD.md](BUILD.md).

## Dictionary

The base dictionary is derived from Unicode Unihan data:

- Source files: `data/lexicon/unihan/`
- Generated databases: `out/data/dict_sc.db` (simplified), `out/data/dict_tc.db` (traditional)
- User dictionary: `out/config/user_dict.db`

If the required Unihan source files are missing, `rebuild_dict.ps1` downloads them automatically from Unicode. Pass `-NoAutoDownloadUnihan` for offline-only execution.

## Configuration

Config file: `out/config/cassotis_ime.ini`

Key options:

- Simplified/traditional variant (`db_path_sc` / `db_path_tc`)
- User dictionary path (`user_db_path`)
- Logging and engine behavior toggles

## Documentation

- Build guide: [BUILD.md](BUILD.md)
- Third-party notices: [THIRD_PARTY.md](THIRD_PARTY.md)

## License

This project is licensed under GPL-3.0. See [LICENSE](LICENSE) for the full license text.

Keep third-party notices consistent with [THIRD_PARTY.md](THIRD_PARTY.md).

## Roadmap

- Improve candidate ranking quality and practical phrase coverage
- Improve user-dictionary quality control and tooling
- Extend compatibility across editors, browsers, and IDEs
- Evaluate local LLM (GGUF) assisted suggestion workflow
