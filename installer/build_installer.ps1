param(
    [string]$Version = '0.1.0',
    [string]$SourceRoot = '..',
    [string]$ScriptPath = '.\CassotisIme.iss'
)

$ErrorActionPreference = 'Stop'

function resolve-iscc {
    $candidates = @(
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($cmd -ne $null) {
        return $cmd.Source
    }

    throw 'ISCC.exe not found. Please install Inno Setup 6.'
}

function require-path {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Path"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedScriptPath = Resolve-Path -LiteralPath (Join-Path $scriptDir $ScriptPath)
$resolvedSourceRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir $SourceRoot)
$iscc = resolve-iscc

$requiredFiles = @(
    'cassotis_ime_yanquan.ico',
    'out\cassotis_ime_host.exe',
    'out\cassotis_ime_tray_host.exe',
    'out\cassotis_ime_svr.dll',
    'out\cassotis_ime_svr32.dll',
    'out\cassotis_ime_profile_reg.exe',
    'out\cassotis_ime_dict_init.exe',
    'out\sqlite3_64.dll',
    'out\register_tsf.ps1',
    'out\unregister_tsf.ps1',
    'out\start_tsf.ps1',
    'out\stop_tsf.ps1',
    'out\data\dict_sc.db',
    'out\data\dict_tc.db'
)

foreach ($relativePath in $requiredFiles) {
    require-path (Join-Path $resolvedSourceRoot $relativePath)
}

& $iscc ("/DAppVersion=$Version") ("/DSourceRoot=$resolvedSourceRoot") $resolvedScriptPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

