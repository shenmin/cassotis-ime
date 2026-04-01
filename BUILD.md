# Build Guide

This document describes the current build prerequisites, runtime dictionary pipeline, and TSF registration/startup flow for Cassotis IME.

## Prerequisites

- Windows 10/11
- Embarcadero Delphi 10.4 (Studio 21.0)
- Windows SDK
- SQLite runtime DLL
  - source artifact: `third_party/sqlite/win64/sqlite3.dll`
  - copied to: `out/sqlite3_64.dll`

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

1. Stops the host process and processes holding the TSF DLLs
2. Builds `cassotis_ime_svr.dproj` for Win64 and Win32
3. Builds Win64 tool executables: host, profile_reg, tray_host, dict_init
4. Copies `sqlite3_64.dll`

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

This script imports generated lexicon artifacts from a sibling `cassotis_lexicon` / `cassotis_lexicon_public` repository and rebuilds the runtime dictionaries:

1. Locates the lexicon repository
2. Imports `dict_unihan_sc.txt` / `dict_unihan_tc.txt`
3. Imports `dict_clean_sc.txt` / `dict_clean_tc.txt`
4. Rebuilds:
   - `%LOCALAPPDATA%\CassotisIme\data\dict_sc.db`
   - `%LOCALAPPDATA%\CassotisIme\data\dict_tc.db`
5. Restarts the host if it was stopped at the beginning

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

## Installer (Optional)

If Inno Setup is installed, you can build the installer from `out/`:

```powershell
.\rebuild_installer.ps1
```

Installer script:

- `installer/cassotis_ime.iss`

## Runtime Paths

Default runtime paths:

- config file: `%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini`
- simplified base dictionary: `%LOCALAPPDATA%\CassotisIme\data\dict_sc.db`
- traditional base dictionary: `%LOCALAPPDATA%\CassotisIme\data\dict_tc.db`
- user dictionary: `%LOCALAPPDATA%\CassotisIme\data\user_dict.db`

Notes:

- Legacy files next to the executable or under `config\` are migrated automatically
- The default log file remains under `<host_exe_dir>\logs\cassotis_ime.log`

## Troubleshooting

**Registration fails with "access denied"**

Run PowerShell as Administrator.

**`rsvars.bat` not found**

Make sure Delphi 10.4 (Studio 21.0) is installed and the build toolchain is available to `rebuild_all.ps1`.

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
