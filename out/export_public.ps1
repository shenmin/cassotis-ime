param(
    [string]$Destination = 'D:\cassotis_ime_public',
    [switch]$InitGit
)

$ErrorActionPreference = 'Stop'

function invoke_robocopy {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$arguments
    )

    & robocopy @arguments | Out-Null
    $exit_code = $LASTEXITCODE
    if ($exit_code -ge 8) {
        throw "robocopy failed with exit code $exit_code"
    }
}

function ensure_gitignore_line {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path,
        [Parameter(Mandatory = $true)]
        [string]$line
    )

    if (-not (Test-Path -LiteralPath $path)) {
        Set-Content -LiteralPath $path -Value "" -Encoding UTF8
    }

    $content = Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -notcontains $line) {
        Add-Content -LiteralPath $path -Value $line -Encoding UTF8
    }
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source_root = (Get-Item (Join-Path $script_dir '..')).FullName

if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Host "Creating destination: $Destination"
    New-Item -ItemType Directory -Path $Destination | Out-Null
}
else {
    Write-Host "Cleaning destination (keeping .git and LICENSE): $Destination"
    $keep_names = @('.git', 'license')
    Get-ChildItem -LiteralPath $Destination -Force | ForEach-Object {
        $entry = $_
        if ($keep_names -contains $entry.Name.ToLowerInvariant()) {
            return
        }

        try {
            Remove-Item -LiteralPath $entry.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning ("Cannot remove path, keeping it: " + $entry.FullName + " (" + $_.Exception.Message + ")")
        }
    }
}

$exclude_dirs = @(
    '.git',
    '.claude',
    'docs',
    'tests',
    'dcu',
    'out\logs',
    'out\config',
    'out\data',
    'out\models',
    'out\_tmp_build'
)

$exclude_files = @(
    'DEVPROGRESS.md',
    'DEVPLAN.md',
    'AGENTS.md',
    '*.local.*'
)

$robo_args = @(
    $source_root,
    $Destination,
    '/E',
    '/R:1',
    '/W:1',
    '/NFL',
    '/NDL',
    '/NJH',
    '/NJS',
    '/NP'
)

foreach ($dir in $exclude_dirs) {
    $robo_args += '/XD'
    $robo_args += (Join-Path $source_root $dir)
}

foreach ($file in $exclude_files) {
    $robo_args += '/XF'
    $robo_args += $file
}

Write-Host "Copying files..."
invoke_robocopy -arguments $robo_args

# Keep out/ as script directory only in public export.
$public_out_dir = Join-Path $Destination 'out'
if (Test-Path -LiteralPath $public_out_dir) {
    Get-ChildItem -LiteralPath $public_out_dir -Recurse -File |
        Where-Object { $_.Extension -notin @('.ps1', '.md', '.txt') } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Ensure private docs are removed even if copied by mistake.
foreach ($rel in @('DEVPROGRESS.md', 'DEVPLAN.md', 'AGENTS.md')) {
    $p = Join-Path $Destination $rel
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Force
    }
}

$docs_dir = Join-Path $Destination 'docs'
if (Test-Path -LiteralPath $docs_dir) {
    Remove-Item -LiteralPath $docs_dir -Recurse -Force -ErrorAction SilentlyContinue
}

# Keep README files in sync with source repository.
$source_readme = Join-Path $source_root 'README.md'
if (Test-Path -LiteralPath $source_readme) {
    Copy-Item -LiteralPath $source_readme -Destination (Join-Path $Destination 'README.md') -Force
}

$source_readme_cn = Join-Path $source_root 'README.CN.md'
if (Test-Path -LiteralPath $source_readme_cn) {
    Copy-Item -LiteralPath $source_readme_cn -Destination (Join-Path $Destination 'README.CN.md') -Force
}

$public_build = @'
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
'@

$build_path = Join-Path $Destination 'BUILD.md'
Set-Content -LiteralPath $build_path -Value $public_build -Encoding UTF8

$gitignore_path = Join-Path $Destination '.gitignore'
ensure_gitignore_line -path $gitignore_path -line '# Public export guards'
ensure_gitignore_line -path $gitignore_path -line 'DEVPROGRESS.md'
ensure_gitignore_line -path $gitignore_path -line 'DEVPLAN.md'
ensure_gitignore_line -path $gitignore_path -line 'AGENTS.md'
ensure_gitignore_line -path $gitignore_path -line 'out/logs/'
ensure_gitignore_line -path $gitignore_path -line 'out/config/'
ensure_gitignore_line -path $gitignore_path -line 'out/data/'
ensure_gitignore_line -path $gitignore_path -line 'out/models/'
ensure_gitignore_line -path $gitignore_path -line 'out/_tmp_build/'

if ($InitGit) {
    Write-Host "Initializing new git repository..."
    Push-Location $Destination
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $Destination '.git'))) {
            git init -b main | Out-Null
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "Public export complete: $Destination"
