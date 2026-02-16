# Build Guide

## Environment
- Windows 10/11
- Delphi 10.4
- SQLite runtime DLLs (32-bit and 64-bit) in `out/`

## Core Build (Typical)
Build these projects first:
- `src/tsf/cassotis_ime_svr.dproj` (Win64 + Win32)
- `tools/cassotis_ime_host.dproj` (Win64 + Win32)
- `tools/cassotis_ime_profile_reg.dproj`

Optional helper tools:
- `tools/cassotis_ime_dict_init.dproj`
- `tools/cassotis_ime_unihan_import.dproj`
- `tools/cassotis_ime_variant_convert.dproj`
- `tools/cassotis_ime_dict_probe.dproj`

## Register and Initialize
Run from `out/`:

1. Register TSF DLLs:
```powershell
.\register_tsf.ps1 -dll_path .\cassotis_ime_svr.dll
```

2. Rebuild dictionaries:
```powershell
.\rebuild_dict.ps1
```

3. (Optional) Unregister:
```powershell
.\unregister_tsf.ps1 -dll_path .\cassotis_ime_svr.dll
```

## Troubleshooting
- If DLL replacement fails, close processes using the DLL and rerun.
- If registration fails, use elevated PowerShell.
- If host process cannot be stopped automatically, stop it manually and rerun scripts.
