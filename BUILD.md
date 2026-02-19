# Build Guide

## Prerequisites

- **Windows 10/11**
- **Embarcadero Delphi 10.4** (Studio 21.0), installed to the default path:
  `C:\Program Files (x86)\Embarcadero\Studio\21.0\`
- An **administrator PowerShell session** for the registration step

The SQLite runtime (`sqlite3_64.dll`) is copied automatically from `third_party/sqlite/win64/` by `rebuild_all.ps1` — no separate installation is needed.

---

## First-Time Setup

All scripts below are located in and must be run from the `out/` directory.

### Step 1 — Build all binaries

```powershell
.\rebuild_all.ps1
```

This script performs a full clean build:

1. Stops any running host process (`cassotis_ime_host.exe`) and processes holding the TSF DLLs
2. Builds `cassotis_ime_svr.dproj` for both Win32 and Win64, producing:
   - `cassotis_ime_svr32.dll` (Win32 TSF COM server)
   - `cassotis_ime_svr.dll` (Win64 TSF COM server)
3. Builds all tool executables (Win64): host, profile_reg, tray_host, dict_init, unihan_import, variant_convert
4. Copies `sqlite3_64.dll` from `third_party/sqlite/win64/`

The default build timeout is 1800 seconds. To override:

```powershell
$env:CASSOTIS_BUILD_TIMEOUT_SECONDS = '3600'
.\rebuild_all.ps1
```

### Step 2 — Register with Windows

> **Requires administrator.** Open PowerShell as Administrator before running this step.

```powershell
.\register_tsf.ps1
```

This script:

1. Registers both `cassotis_ime_svr.dll` (Win64) and `cassotis_ime_svr32.dll` (Win32) with the Windows COM registry using the appropriate `regsvr32.exe` for each architecture
2. Runs `cassotis_ime_profile_reg.exe register` to register the TSF input method profile and categories

Passing either DLL is sufficient; the script finds and registers its pair automatically. Options:

```powershell
# Register a DLL at a custom path (pair is still auto-detected)
.\register_tsf.ps1 -dll_path "C:\path\to\cassotis_ime_svr.dll"

# Register only the specified DLL, skip auto-pairing
.\register_tsf.ps1 -single
```

### Step 3 — Build dictionaries

```powershell
.\rebuild_dict.ps1
```

This script runs the full dictionary pipeline:

1. Checks for required Unihan source files under `data/lexicon/unihan/`; if missing, downloads `Unihan.zip` from Unicode automatically
2. Parses `Unihan_Readings.txt` (and optionally `Unihan_DictionaryLikeData.txt`) into a raw intermediate dictionary
3. Validates reading coverage with `check_unihan_readings.ps1`
4. Filters to simplified-only entries (`filter_sc`)
5. Derives a traditional variant using `Unihan_Variants.txt` (`s2t`)
6. Imports both dictionaries into `out/data/dict_sc.db` and `out/data/dict_tc.db`
7. Restarts the host process if it was stopped at the beginning

Options:

```powershell
# Offline mode — Unihan files must already exist under data/lexicon/unihan/
.\rebuild_dict.ps1 -NoAutoDownloadUnihan

# Skip restarting the host process after rebuild
.\rebuild_dict.ps1 -NoRestartHost
```

### Step 4 — Start TSF

```powershell
.\start_tsf.ps1
```

Starts `ctfmon.exe`, which activates Windows TSF input method services. The host process is launched by TSF as needed.

---

## Stopping and Restarting TSF

```powershell
.\stop_tsf.ps1
```

Stops `ctfmon.exe` and the host process. If processes holding the TSF DLLs are detected, the script lists them and prompts for confirmation before terminating.

```powershell
# Skip the confirmation prompt and force-kill DLL-holding processes
.\stop_tsf.ps1 -force_kill

# Stop and immediately restart ctfmon in one step
.\start_tsf.ps1 -restart
```

To unregister the TSF DLLs from Windows:

```powershell
.\unregister_tsf.ps1
```

---

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

### Rebuild all binaries

```powershell
.\rebuild_all.ps1
```

### Rebuild dictionaries only

```powershell
.\rebuild_dict.ps1
```

---

## Manual Build Order (IDE)

When building in the Delphi IDE instead of using `rebuild_all.ps1`, follow this order:

| # | Project | Platform |
|---|---------|----------|
| 1 | `src/tsf/cassotis_ime_svr.dproj` | Win64, then Win32 |
| 2 | `tools/cassotis_ime_host.dproj` | Win64 |
| 3 | `tools/cassotis_ime_profile_reg.dproj` | Win64 |
| 4 | `tools/cassotis_ime_tray_host.dproj` | Win64 |
| 5 | `tools/cassotis_ime_dict_init.dproj` | Win64 |
| 6 | `tools/cassotis_ime_unihan_import.dproj` | Win64 |
| 7 | `tools/cassotis_ime_variant_convert.dproj` | Win64 |

Configure IDE output directories to `out/`. The TSF server Win32 build output should be renamed to `cassotis_ime_svr32.dll`.

---

## Optional: Local LLM Runtime (llama.cpp)

To enable local GGUF model inference for AI-assisted candidate ranking:

1. Build the llama.cpp runtime DLLs:
   ```powershell
   .\build_llama_cpp.ps1
   ```
2. Place GGUF model files under `out/models/`
3. Configure the `[ai]` section in `out/config/cassotis_ime.ini`

---

## Troubleshooting

**Registration fails with "access denied"**
Run PowerShell as Administrator.

**`rsvars.bat` not found**
Ensure Delphi 10.4 (Studio 21.0) is installed at `C:\Program Files (x86)\Embarcadero\Studio\21.0\`. The build script uses a hardcoded path to `rsvars.bat`.

**Build times out**
Increase the timeout before running the script:
```powershell
$env:CASSOTIS_BUILD_TIMEOUT_SECONDS = '3600'
```

**DLL replacement fails (file locked)**
The TSF DLL is loaded in-process by applications that use IME. Run `.\stop_tsf.ps1 -force_kill` to release the lock, then retry.

**Host process cannot be stopped automatically**
Stop `cassotis_ime_host.exe` manually via Task Manager, then rerun the script.
