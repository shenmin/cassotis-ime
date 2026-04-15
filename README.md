# Cassotis IME

<p align="center">
  <img src="cassotis_ime_yanquan.png" alt="Cassotis IME logo" width="280">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
</p>
<p align="center">
  <img src="snapshot.png" alt="Cassotis IME snapshot" width="600">
</p>

English | [简体中文](README.CN.md)

Cassotis IME (言泉输入法) is an experimental Chinese Pinyin input method for Windows 10/11, built primarily with Delphi on top of TSF (Text Services Framework).

## Name Origin
The English name **Cassotis** comes from the sacred spring inside the Temple of Delphi. Before delivering oracles, the priestess Pythia was said to drink from this spring to enter a prophetic state. The spring was regarded as the true source of prophecy and inspiration, where oracles were born, which resonates with the path from Delphi to human language.

The Chinese name **言泉** (Yanquan, "Spring of Words") matches Cassotis as a prophetic spring, while also carrying the meaning of **言如泉涌** ("words flowing like a spring"), reflecting our expectation of a fluent and intelligent input experience.

The project focus is:
- build a stable TSF-based IME foundation,
- keep the architecture modular (TSF DLL + host process + tools),
- and explore AI/LLM-assisted input in later stages.

## Current Status
- TSF text service pipeline is available (registration, activation, composition lifecycle).
- TSF binaries support Win64 and Win32 (`svr.dll` / `svr32.dll`), while host process is Win64 only.
- Candidate window, paging, selection, and commit flow are implemented.
- Dictionary split is supported: simplified base DB, traditional base DB, and user DB.
- Base dictionary now includes `dict_jianpin` index entries for initial-letter abbreviations (for example `jt -> 今天`; retroflex variants like `zsjs/zhshjsh` are both generated).
- Full-path segmented phrase decoding is enabled (for example `womenjintian -> 我们今天`) while keeping prefix candidates for partial-commit fallback.
- Surrounding-text/context synchronization and key state synchronization are implemented.

## Architecture
- `src/tsf`: TSF COM in-proc server (text service integration).
- `src/engine`: Pinyin parsing, candidate generation, ranking, and user learning.
- `src/host`: external host process for engine/UI orchestration.
- `src/ui`: candidate window and tray UI.
- `src/common`: config, logging, IPC, sqlite wrapper, shared utilities.
- `tools`: registration, dictionary build/import/diagnostics, helper executables.

## Repository Layout
- `src/` source code
- `tools/` utility projects and helper executables
- `data/` schema and sample dictionary import data
- `out/` scripts for build/register/rebuild/test
- `third_party/` vendored third-party binaries/sources (for example sqlite runtime package files)

## Key Binaries
- `cassotis_ime_svr.dll` (Win64 TSF in-proc COM server)
- `cassotis_ime_svr32.dll` (Win32 TSF in-proc COM server)
- `cassotis_ime_host.exe` (Win64 host process)
- `cassotis_ime_profile_reg.exe` (TSF profile/category registration utility)

Without TSF DLL + host process, IME input will not work.

## Build and Run (Quick Start)
Prerequisites:
- Windows 10/11
- Delphi 10.4
- SQLite runtime DLL (`sqlite3_64.dll`)

From `out/`:

```powershell
.\rebuild_all.ps1
.\cassotis_ime_profile_reg.exe register_tsf -dll_path .\cassotis_ime_svr.dll
.\rebuild_dict.ps1
```

For full build details, see `BUILD.md`.

## Dictionary Workflow
Current base dictionary pipeline imports generated lexicon artifacts from sibling `cassotis_lexicon` / `cassotis_lexicon_public` repository:
- lexicon inputs: `dict_unihan_sc.txt`, `dict_unihan_tc.txt`, `dict_clean_sc.txt`, `dict_clean_tc.txt`
- runtime DB files are rebuilt under `%LOCALAPPDATA%\CassotisIme\data\` (for example `dict_sc.db`, `dict_tc.db`)
- user dictionary defaults to `%LOCALAPPDATA%\CassotisIme\data\user_dict.db`
- `rebuild_dict.ps1` imports `pinyin<TAB>text<TAB>weight` and auto-builds `dict_jianpin` (including `z/c/s` and `zh/ch/sh` abbreviation variants)

Main rebuild entry:

```powershell
.\rebuild_dict.ps1
```

## Configuration
Default config file:
- `%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini`

Important options include:
- simplified/traditional variant switching (`variant`)
- full-width / punctuation mode
- debug logging and log path

Runtime dictionary paths are fixed under `%LOCALAPPDATA%\CassotisIme\data\` and are no longer configured through the INI file.

## Documentation
- Chinese full documentation: `README.CN.md`
- Build details: `BUILD.md`
- Third-party notices: `THIRD_PARTY.md`

## License
This project is licensed under GPL-3.0. See `LICENSE` for the full license text.

Keep third-party notices and attribution files consistent with `THIRD_PARTY.md`.

## Roadmap
- improve candidate ranking quality and practical phrase coverage
- improve user-dictionary quality control and tooling
- extend compatibility matrix across editors/browsers/IDEs
- evaluate local LLM (GGUF) assisted suggestion workflow
