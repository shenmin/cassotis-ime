# Build Guide

This document describes the current build prerequisites, runtime dictionary pipeline, and TSF registration/startup flow for Cassotis IME.

## Prerequisites

- Windows 10/11
- Embarcadero Delphi 10.4 (Studio 21.0)
- Visual Studio 2022 with the C++ build tools for x64 (Community, Professional, Enterprise, or Build Tools), for the native language-model bridge
- Windows SDK
- A checkout of [cassotis-lexicon](https://github.com/shenmin/cassotis-lexicon) next to this repository (`..\cassotis-lexicon` or `..\cassotis_lexicon`), for the dictionaries

Included in this repository, nothing to install:

- SQLite runtime DLL
  - source artifact: `third_party/sqlite/win64/sqlite3.dll`
  - copied to: `out/sqlite3_64.dll`
- ONNX Runtime
  - source artifacts: `third_party/onnxruntime/` (headers and the `win64` DLLs)
  - copied to: `out/onnxruntime.dll`, `out/onnxruntime_providers_shared.dll`
- The character language model
  - source artifacts: `data/models/char_lm/`, with `char_lm.onnx` stored as numbered parts (`char_lm.onnx.000`, ...)
  - joined and copied to: `out/char_lm/`

## Optional Tools

- DUnitX
- Inno Setup
- Git

## First-Time Setup

All scripts below are located in and should be run from `out/`.

### Step 1 - Build all binaries

```powershell
.\rebuild_all.ps1
```

This script:

1. Stops the host process
2. Builds the native language-model bridge `cassotis_pinyin_transformer_ort.dll` with Visual C++ (`tools\build_pinyin_transformer_ort.ps1`), copies the ONNX Runtime DLLs, and stages the language model in `out\char_lm` (the numbered parts are joined and every file is checked against the model's manifest)
3. Stops the processes holding the TSF DLLs and builds `cassotis_ime_svr.dproj` for Win32 and Win64
4. Builds Win64 tool executables: host, profile_reg, tray_host, dict_init
5. Copies `sqlite3_64.dll`

The script looks for `vcvars64.bat` in the default Visual Studio 2022 locations.

To leave the TSF DLLs alone (they stay loaded in running applications):

```powershell
.\rebuild_all.ps1 -SkipTsf
```

To override the default build timeout:

```powershell
$env:CASSOTIS_BUILD_TIMEOUT_SECONDS = '3600'
.\rebuild_all.ps1
```

### Step 2 - Register with Windows

> Requires an elevated PowerShell session.

```powershell
.\register_tsf.ps1
```

This script:

1. Registers `cassotis_ime_svr.dll` (Win64) and `cassotis_ime_svr32.dll` (Win32)
2. Runs `cassotis_ime_profile_reg.exe register_tsf` to register the TSF profile and categories

Options:

```powershell
# Register a DLL at a custom path (its paired DLL is still auto-detected)
.\register_tsf.ps1 -dll_path "C:\path\to\cassotis_ime_svr.dll"

# Register only the specified DLL
.\register_tsf.ps1 -single
```

### Step 3 - Rebuild runtime dictionaries

```powershell
.\rebuild_dict.ps1
```

This script imports generated lexicon artifacts from the sibling [cassotis-lexicon](https://github.com/shenmin/cassotis-lexicon) repository and rebuilds the runtime dictionaries:

1. Locates the lexicon repository
2. Imports the word lists `dict_unihan_sc.txt` / `dict_unihan_tc.txt` and `dict_clean_sc.txt` / `dict_clean_tc.txt`
3. Imports the corpus-trained tables from the same directory: word-transition and query-path priors, the completion tables, and the short-word promotion tables `dict_short_promotion_sc.txt` / `dict_short_promotion_tc.txt`
4. Rebuilds:
   - `%LOCALAPPDATA%\CassotisIme\data\dict_sc.db`
   - `%LOCALAPPDATA%\CassotisIme\data\dict_tc.db`
5. Restarts the host if it was stopped at the beginning

The short-word promotion tables are part of a complete dictionary: `rebuild_installer.ps1` refuses a dictionary without them.

Options:

```powershell
# Import Unihan only
.\rebuild_dict.ps1 -NoExternalLexicon

# Rebuild dictionaries without restarting the host
.\rebuild_dict.ps1 -NoRestartHost
```

### Step 4 - Start TSF

```powershell
.\start_tsf.ps1
```

This starts `ctfmon.exe`. The host process is launched by TSF as needed.

## Stop and Restart TSF

```powershell
.\stop_tsf.ps1
```

Stops `ctfmon.exe` and the host. If processes are still holding the TSF DLLs, the script prompts before terminating them.

```powershell
# Skip the confirmation prompt and force-kill DLL-holding processes
.\stop_tsf.ps1 -force_kill

# Stop and immediately restart TSF
.\start_tsf.ps1 -restart
```

To unregister the TSF DLLs:

```powershell
.\unregister_tsf.ps1
```

## Incremental Updates

### Replace the Win64 DLL only

After rebuilding `src/tsf/cassotis_ime_svr.dproj` for Win64 in the IDE:

```powershell
.\replace_svr.ps1
```

### Replace the Win32 DLL only

After rebuilding `src/tsf/cassotis_ime_svr.dproj` for Win32 in the IDE:

```powershell
.\replace_svr32.ps1
```

### Rebuild dictionaries only

```powershell
.\rebuild_dict.ps1
```

## Manual Build Order (IDE)

When building in the Delphi IDE instead of using `rebuild_all.ps1`, use this order:

| # | Project | Platform |
| --- | --- | --- |
| 1 | `src/tsf/cassotis_ime_svr.dproj` | Win64, then Win32 |
| 2 | `tools/cassotis_ime_host.dproj` | Win64 |
| 3 | `tools/cassotis_ime_profile_reg.dproj` | Win64 |
| 4 | `tools/cassotis_ime_tray_host.dproj` | Win64 |
| 5 | `tools/cassotis_ime_dict_init.dproj` | Win64 |

IDE output directories should target `out/`. The Win32 TSF output should be named `cassotis_ime_svr32.dll`.

The language-model bridge is not a Delphi project. Run `rebuild_all.ps1` once so that `out/` holds `cassotis_pinyin_transformer_ort.dll`, the ONNX Runtime DLLs and `char_lm\`; without them the IME still runs, but ranks candidates without the language model.

## Installer (Optional)

If Inno Setup 6 is installed, you can build the installer from `out/` after `rebuild_all.ps1` and `rebuild_dict.ps1`:

```powershell
.\rebuild_installer.ps1
```

The version comes from `version.props`. The script checks that both runtime dictionaries under `%LOCALAPPDATA%\CassotisIme\data\` carry the short-word promotion table, then packages them with the binaries and the language model in `out/`.

Installer scripts:

- `installer/cassotis_ime.iss` and the `.iss` files it includes

Behavior of the package:

- An upgrade installs the new runtime beside the old one. When Windows Explorer still holds the old text service, Setup asks before restarting it and never asks to restart Windows.
- Uninstalling closes no application. Files that an application still has loaded are removed at the next restart, and only then does the uninstaller ask for one.

## Runtime Paths

Default runtime paths:

- config file: `%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini`
- simplified base dictionary: `%LOCALAPPDATA%\CassotisIme\data\dict_sc.db`
- traditional base dictionary: `%LOCALAPPDATA%\CassotisIme\data\dict_tc.db`
- user dictionary: `%LOCALAPPDATA%\CassotisIme\data\user_dict.db`
- language model: `<host_exe_dir>\char_lm\`, with `cassotis_pinyin_transformer_ort.dll` and the ONNX Runtime DLLs beside the host executable

Notes:

- Legacy files next to the executable or under `config\` are migrated automatically
- The default log file remains under `<host_exe_dir>\logs\cassotis_ime.log`

## Troubleshooting

**Registration fails with "access denied"**

Run PowerShell as Administrator.

**`rsvars.bat` not found**

Make sure Delphi 10.4 (Studio 21.0) is installed and the build toolchain is available to `rebuild_all.ps1`.

**`Cannot find Visual Studio 2022 C++ vcvars64.bat`**

Install the Visual Studio 2022 C++ build tools for x64 in the default location. `rebuild_all.ps1` needs them for the language-model bridge.

**The log says `char-lm unavailable`**

The language-model files in `out/` are missing or do not belong to this build. Run `rebuild_all.ps1` again. Until then the IME keeps working and ranks candidates without the language model.

**Build times out**

Increase the timeout before running the script:

```powershell
$env:CASSOTIS_BUILD_TIMEOUT_SECONDS = '3600'
```

**DLL replacement fails (file locked)**

Run:

```powershell
.\stop_tsf.ps1 -force_kill
```

then retry.

**Dictionary rebuild appears to have no effect**

Confirm that `rebuild_dict.ps1` completed successfully and that the runtime DB files under `%LOCALAPPDATA%\CassotisIme\data\` were updated.
