# Build Guide

## Environment
- Windows 10/11
- Delphi 10.4
- SQLite runtime DLL: `out/sqlite3_64.dll`

## Build Outputs
The normal build flow produces these binaries under `out/`:
- `cassotis_ime_svr.dll` (Win64 TSF DLL)
- `cassotis_ime_svr32.dll` (Win32 TSF DLL)
- `cassotis_ime_host.exe` (Win64 host process)
- `cassotis_ime_profile_reg.exe`
- `cassotis_ime_tray_host.exe`
- `cassotis_ime_dict_init.exe`
- `cassotis_ime_unihan_import.exe`
- `cassotis_ime_variant_convert.exe`

## One-Command Build
Run from repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\out\rebuild_all.ps1
```

## Manual Build Order (IDE)
Build these projects:
- `src/tsf/cassotis_ime_svr.dproj` (Win64 + Win32)
- `tools/cassotis_ime_host.dproj` (Win64)
- `tools/cassotis_ime_profile_reg.dproj` (Win64)
- `tools/cassotis_ime_tray_host.dproj` (Win64)
- `tools/cassotis_ime_dict_init.dproj` (Win64)
- `tools/cassotis_ime_unihan_import.dproj` (Win64)
- `tools/cassotis_ime_variant_convert.dproj` (Win64)

## Dictionary Source Files
`rebuild_dict.ps1` requires Unihan source files under `data/lexicon/unihan/`:
- `Unihan_Readings.txt` (required)
- `Unihan_Variants.txt` (required)
- `Unihan_DictionaryLikeData.txt` (optional)

If the required files are missing, download Unihan data from Unicode and place them in that directory first.

## Register and Initialize
Run from `out/` after build:

1. Register TSF DLLs:
```powershell
.\register_tsf.ps1 -dll_path .\cassotis_ime_svr.dll
```

2. Build dictionaries:
```powershell
.\rebuild_dict.ps1
```
`rebuild_dict.ps1` runs `check_unihan_readings.ps1` automatically before dictionary import.

3. Restart TSF (optional but recommended after updates):
```powershell
.\stop_tsf.ps1 -force_kill
.\start_tsf.ps1
```

4. Unregister (optional):
```powershell
.\unregister_tsf.ps1 -dll_path .\cassotis_ime_svr.dll
```

## Local LLM Runtime (Optional)
If you plan to test local GGUF inference:
- Build runtime DLLs with `out/build_llama_cpp.ps1`
- Put model files under `out/models/`
- Configure `out/config/cassotis_ime.ini` `[ai]` section

## Troubleshooting
- If DLL replacement fails, close processes using the DLL and rerun.
- If registration fails, use elevated PowerShell.
- If host process cannot be stopped automatically, stop it manually and rerun scripts.
