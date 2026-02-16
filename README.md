# Cassotis IME

English | [简体中文](README.CN.md)

> Project status: This project is still in a very early stage and is not yet practical for daily use. Prebuilt binaries are not provided at this time.

Cassotis IME (言泉输入法) is an experimental Chinese Pinyin input method for Windows 10/11, built primarily with Delphi on top of TSF (Text Services Framework).

The project focus is:
- build a stable TSF-based IME foundation,
- keep the architecture modular (TSF DLL + host process + tools),
- and explore AI/LLM-assisted input in later stages.

## Current Status
- TSF text service pipeline is available (registration, activation, composition lifecycle).
- Win64 and Win32 TSF binaries are both supported.
- Candidate window, paging, selection, and commit flow are implemented.
- Dictionary split is supported: simplified base DB, traditional base DB, and user DB.
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
- `data/` schema and lexicon sources
- `out/` scripts for build/register/rebuild/test
- `tests/` unit/perf test projects
- `third_party/` vendored third-party binaries/sources (for example sqlite runtime package files)

## Key Binaries
- `cassotis_ime_svr.dll` (Win64 TSF in-proc COM server)
- `cassotis_ime_svr32.dll` (Win32 TSF in-proc COM server)
- `cassotis_ime_host.exe` (Win64 host process)
- `cassotis_ime_host32.exe` (Win32 host process)
- `cassotis_ime_profile_reg.exe` (TSF profile/category registration utility)

Without TSF DLL + host process, IME input will not work.

## Build and Run (Quick Start)
Prerequisites:
- Windows 10/11
- Delphi 10.4
- SQLite runtime DLLs (`sqlite3_64.dll`, `sqlite3_32.dll`)

From `out/`:

```powershell
.\rebuild_all.ps1
.\register_tsf.ps1 -dll_path .\cassotis_ime_svr.dll
.\rebuild_dict.ps1
```

Optional health check:

```powershell
.\smoke_tsf.ps1
```

For full build details, see `BUILD.md`.

## Dictionary Workflow
Current base dictionary pipeline is Unihan-based:
- source files under `data/lexicon/unihan/`
- generated DB files under `out/data/` (for example `dict_sc.db`, `dict_tc.db`)
- user dictionary defaults to `out/config/user_dict.db`

Main rebuild entry:

```powershell
.\rebuild_dict.ps1
```

## Configuration
Default config file:
- `out/config/cassotis_ime.ini`

Important options include:
- simplified/traditional variant switching
- base DB paths (`db_path_sc`, `db_path_tc`)
- user DB path (`user_db_path`)
- logging and engine behavior toggles

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
