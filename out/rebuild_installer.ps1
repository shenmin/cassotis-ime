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

$runtimePayloadFiles = @(
    'out\cassotis_ime_host.exe',
    'out\cassotis_ime_tray_host.exe',
    'out\cassotis_ime_svr.dll',
    'out\cassotis_ime_svr32.dll',
    'out\cassotis_ime_profile_reg.exe',
    'out\sqlite3_64.dll',
    'out\cassotis_pinyin_transformer_ort.dll',
    'out\onnxruntime.dll',
    'out\onnxruntime_providers_shared.dll',
    'out\char_lm\char_lm.onnx',
    'out\char_lm\char_lm_vocab.bin',
    'out\char_lm\runtime_manifest.json',
    'out\pinyin_lm\char_lm.onnx',
    'out\pinyin_lm\char_lm_vocab.bin',
    'out\pinyin_lm\pinyin_readings.json',
    'out\pinyin_lm\runtime_manifest.json'
)

$requiredFiles = @(
    'cassotis_ime_yanquan.ico',
    'version.props'
) + $runtimePayloadFiles + @(
    'third_party\onnxruntime\LICENSE',
    'third_party\onnxruntime\ThirdPartyNotices.txt'
)

foreach ($relativePath in $requiredFiles) {
    require-path (Join-Path $resolvedSourceRoot $relativePath)
}

$runtimeFingerprintFiles = $runtimePayloadFiles
$fingerprintSource = ($runtimeFingerprintFiles | ForEach-Object {
    (Get-FileHash -LiteralPath (Join-Path $resolvedSourceRoot $_) -Algorithm SHA256).Hash
}) -join "`n"
$fingerprintHasher = [Security.Cryptography.SHA256]::Create()
try {
    $fingerprintBytes = [Text.Encoding]::UTF8.GetBytes($fingerprintSource)
    $runtimeBuildId = ([BitConverter]::ToString(
        $fingerprintHasher.ComputeHash($fingerprintBytes)
    )).Replace('-', '').Substring(0, 12).ToLowerInvariant()
}
finally {
    $fingerprintHasher.Dispose()
}

require-path (Join-Path $runtimeDataSourceDir 'dict_sc.db')
require-path (Join-Path $runtimeDataSourceDir 'dict_tc.db')

Write-Host "[installer] runtime_build_id=$runtimeBuildId"
& $iscc ("/DAppVersion=$Version") ("/DRuntimeBuildId=$runtimeBuildId") ("/DSourceRoot=$resolvedSourceRoot") ("/DRuntimeDataSourceDir=$runtimeDataSourceDir") $resolvedScriptPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}
