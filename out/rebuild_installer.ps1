param(
    [string]$Version = '',
    [string]$SourceRoot = '..',
    [string]$ScriptPath = '..\installer\cassotis_ime.iss'
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

function get-shared-version {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionPropsPath
    )

    require-path $VersionPropsPath

    [xml]$xml = Get-Content -LiteralPath $VersionPropsPath -Raw -Encoding UTF8
    $versionText = [string]($xml.Project.PropertyGroup.CassotisVersion | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($versionText)) {
        throw "CassotisVersion not found in $VersionPropsPath"
    }

    return $versionText.Trim()
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedScriptPath = Resolve-Path -LiteralPath (Join-Path $scriptDir $ScriptPath)
$resolvedSourceRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir $SourceRoot)
$versionPropsPath = Join-Path $resolvedSourceRoot 'version.props'
$localAppData = $env:LOCALAPPDATA
if ([string]::IsNullOrWhiteSpace($localAppData)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
}
$runtimeDataSourceDir = Join-Path $localAppData 'CassotisIme\data'
$iscc = resolve-iscc

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = get-shared-version -VersionPropsPath $versionPropsPath
}

$requiredFiles = @(
    'cassotis_ime_yanquan.ico',
    'version.props',
    'out\cassotis_ime_host.exe',
    'out\cassotis_ime_tray_host.exe',
    'out\cassotis_ime_svr.dll',
    'out\cassotis_ime_svr32.dll',
    'out\cassotis_ime_profile_reg.exe',
    'out\sqlite3_64.dll'
)

foreach ($relativePath in $requiredFiles) {
    require-path (Join-Path $resolvedSourceRoot $relativePath)
}

require-path (Join-Path $runtimeDataSourceDir 'dict_sc.db')
require-path (Join-Path $runtimeDataSourceDir 'dict_tc.db')

& $iscc ("/DAppVersion=$Version") ("/DSourceRoot=$resolvedSourceRoot") ("/DRuntimeDataSourceDir=$runtimeDataSourceDir") $resolvedScriptPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}
