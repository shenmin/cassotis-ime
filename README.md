# Cassotis IME

<p align="center">
  <img src="cassotis_ime_yanquan.png" alt="Cassotis IME logo" width="280">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
</p>

English | [简体中文](README.CN.md)

> **Status:** Early stage — not yet practical for daily use. Prebuilt binaries are not provided.

Cassotis IME (言泉输入法) is an experimental Chinese Pinyin input method for Windows 10/11, built primarily with Delphi on top of TSF (Text Services Framework).

<p align="center">
  <img src="snapshot.png" alt="Cassotis IME status widget snapshot" width="420">
</p>

## Name Origin

The English name **Cassotis** comes from the sacred spring inside the Temple of Delphi. Before delivering oracles, the priestess Pythia was said to drink from this spring to enter a prophetic state — the spring was regarded as the true source of prophecy and inspiration, resonating with the path from Delphi to human language.

The Chinese name **言泉** (Yanquan, "Spring of Words") matches Cassotis as a prophetic spring, while also evoking **言如泉涌** ("words flowing like a spring") — reflecting the goal of a fluent and intelligent input experience.

Project focus:

- Build a stable TSF-based IME foundation
- Keep the architecture modular (TSF DLL + host process + tools)
- Continuously improve candidate ranking quality and phrase coverage

## Current Status

- TSF text service pipeline is working (registration, activation, composition lifecycle).
- TSF DLL supports Win64 and Win32 (`svr.dll` / `svr32.dll`); host process is Win64 only.
- Candidate window with paging, selection, commit, and DPI-aware rendering is implemented.
- Surrounding text context and key state are synchronized from the focused application.
- DP-based pinyin syllable segmentation with scored disambiguation.
- Multi-dimensional candidate ranking: session frequency, bigram/trigram context learning, segment path preference/penalty, and path confidence scoring.
- User learning persisted in SQLite: commit statistics, n-gram context, query path preference, and per-candidate penalty.
- Separate simplified and traditional base dictionaries; hot-swap without restart.
- Multi-source candidate window anchor fusion (TSF coordinates, GUI messages, `GetCaretPos`, cursor position) with heuristic scoring for terminal-like hosts.

## Architecture

| Module | Path | Description |
|--------|------|-------------|
| TSF COM server | `src/tsf/` | In-proc text service; handles composition lifecycle (Win64 + Win32) |
| Input engine | `src/engine/` | Pinyin parsing, candidate generation, ranking, user learning |
| Host process | `src/host/` | Win64 process for engine/UI orchestration over Named Pipe IPC |
| UI | `src/ui/` | Candidate window and tray integration |
| Common | `src/common/` | Config, logging, IPC, SQLite wrapper, shared types |
| Tools | `tools/` | Registration, runtime dictionary build/import/diagnostics executables |

## Repository Layout

```
src/          source code
tools/        utility projects (registration, runtime dictionary build, diagnostics)
data/         database schema and sample runtime dictionary import data
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

# 3. Build runtime dictionaries
.\rebuild_dict.ps1

# 4. Start TSF
.\start_tsf.ps1
```

For the complete build guide — including incremental updates, manual IDE builds, script parameters, and troubleshooting — see [BUILD.md](BUILD.md).

## Lexicon and Runtime Dictionaries

The runtime dictionary build pipeline imports generated lexicon artifacts from a sibling lexicon repository
located at `..\cassotis-lexicon`:

The lexicon source repository is published separately at [cassotis-lexicon](https://github.com/shenmin/cassotis-lexicon).

- Lexicon inputs: `dict_unihan_sc.txt`, `dict_unihan_tc.txt`, `dict_clean_sc.txt`, `dict_clean_tc.txt`
- Generated runtime dictionaries: `out/data/dict_sc.db` (simplified), `out/data/dict_tc.db` (traditional)
- User dictionary: `out/data/user_dict.db`

Main rebuild entry:

```powershell
.\rebuild_dict.ps1
```

## Configuration

Config file: `%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini` (auto-created with defaults on first run).

Detailed option reference: [CONFIGURE.md](CONFIGURE.md)

Key options:

- Simplified/traditional variant (`dictionary.variant`)
- Initial input mode, full-width, and punctuation style
- File logging (path, level, rotation size)

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
