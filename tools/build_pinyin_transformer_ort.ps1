param(
    [string]$Configuration = 'Release',
    [string]$VcVarsPath = '',
    [string]$OutputDirectory = '',
    [string]$SourceRoot = '',
    [switch]$EnableExperimentalContextualRecall,
    [switch]$EnableExperimentalTop32CrossRanker,
    [switch]$StopLockingRuntime
)

$ErrorActionPreference = 'Stop'

function get_processes_loading_module([string]$module_path) {
    $full_module_path = [System.IO.Path]::GetFullPath($module_path)
    $result = @()
    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
        try {
            foreach ($module in @($process.Modules)) {
                if ([string]::Equals(
                    [System.IO.Path]::GetFullPath($module.FileName),
                    $full_module_path,
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                    $executable_path = ''
                    try {
                        $executable_path = $process.Path
                    }
                    catch {
                    }
                    $result += [PSCustomObject]@{
                        name = $process.ProcessName
                        pid = $process.Id
                        path = $executable_path
                    }
                    break
                }
            }
        }
        catch {
        }
    }
    return @($result)
}

function format_locking_processes([object[]]$processes) {
    if ($processes.Count -eq 0) {
        return 'none detected'
    }
    return (($processes | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_.path)) {
            '{0} (PID {1})' -f $_.name, $_.pid
        }
        else {
            '{0} (PID {1}, {2})' -f $_.name, $_.pid, $_.path
        }
    }) -join '; ')
}

function stop_locking_runtime_processes([string]$target_path, [object[]]$processes) {
    $allowed_names = @(
        'cassotis_ime_host',
        'cassotis_ime_host32',
        'cassotis_ime_tray_host',
        'cassotis_ime_tray_host32'
    )
    $unsupported = @($processes | Where-Object { $_.name -notin $allowed_names })
    if ($unsupported.Count -gt 0) {
        throw ('Cannot replace {0}; stop the process loading it and retry: {1}' -f
            $target_path, (format_locking_processes $unsupported))
    }

    foreach ($process in $processes) {
        Write-Host ('[pinyin-transformer] stopping lock holder: {0} (PID {1})' -f
            $process.name, $process.pid)
        Stop-Process -Id $process.pid -Force -ErrorAction SilentlyContinue
    }
    foreach ($process in $processes) {
        try {
            Wait-Process -Id $process.pid -Timeout 3 -ErrorAction SilentlyContinue
        }
        catch {
        }
    }
}

function publish_runtime_dll(
    [string]$staged_path,
    [string]$target_path,
    [bool]$stop_locking_runtime
) {
    $target_directory = Split-Path -Parent $target_path
    $publish_id = '{0}.{1}' -f $PID, [Guid]::NewGuid().ToString('N')
    $pending_path = Join-Path $target_directory (
        '.cassotis_pinyin_transformer_ort.{0}.pending' -f $publish_id)
    $backup_path = Join-Path $target_directory (
        '.cassotis_pinyin_transformer_ort.{0}.backup' -f $publish_id)
    Copy-Item -LiteralPath $staged_path -Destination $pending_path -Force

    try {
        $last_error = ''
        for ($attempt = 1; $attempt -le 20; $attempt++) {
            $lockers = @(get_processes_loading_module $target_path)
            if ($lockers.Count -gt 0) {
                if (-not $stop_locking_runtime) {
                    throw (('Cannot replace {0}; it is loaded by: {1}. ' +
                        'Stop that process or use -StopLockingRuntime.') -f
                        $target_path, (format_locking_processes $lockers))
                }
                stop_locking_runtime_processes $target_path $lockers
            }

            try {
                if (Test-Path -LiteralPath $target_path) {
                    [System.IO.File]::Replace($pending_path, $target_path, $backup_path)
                    Remove-Item -LiteralPath $backup_path -Force -ErrorAction SilentlyContinue
                }
                else {
                    [System.IO.File]::Move($pending_path, $target_path)
                }
                return
            }
            catch {
                $last_error = $_.Exception.Message
                if ($attempt -lt 20) {
                    Start-Sleep -Milliseconds 200
                }
            }
        }

        $remaining_lockers = @(get_processes_loading_module $target_path)
        throw (('Cannot publish {0} after 20 attempts. Last error: {1}. ' +
            'Detected lock holders: {2}') -f $target_path, $last_error,
            (format_locking_processes $remaining_lockers))
    }
    finally {
        if (Test-Path -LiteralPath $pending_path) {
            Remove-Item -LiteralPath $pending_path -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $backup_path) {
            Remove-Item -LiteralPath $backup_path -Force -ErrorAction SilentlyContinue
        }
    }
}

$root = Split-Path -Parent $PSScriptRoot
if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
    $root = (Resolve-Path -LiteralPath $SourceRoot).Path
}
$source = Join-Path $root 'src\host\native\nc_pinyin_transformer_ort.cpp'
# The attention operator's AVX2 code is compiled on its own, so that only this
# file uses AVX2 instructions (the caller checks the processor). Sources from
# before the operator do not have it.
$vectorSource = Join-Path $root 'src\host\native\nc_trie_attention_avx2.cpp'
$include = Join-Path $root 'third_party\onnxruntime\include'
$onnxLibrary = Join-Path $root 'third_party\onnxruntime\win64\onnxruntime.lib'
$versionProps = Join-Path $root 'version.props'
$outRoot = [IO.Path]::GetFullPath((Join-Path $root 'out'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = $outRoot }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
# Historical benchmarks compile a worktree's sources into a run directory of
# the repository that hosts this script; both out directories are allowed.
$allowedOutRoots = @($outRoot, [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $PSScriptRoot) 'out')))
$insideOut = @($allowedOutRoots | Where-Object {
    ($OutputDirectory -ieq $_) -or $OutputDirectory.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) })
if ($insideOut.Count -eq 0) {
    throw 'Native runtime output must remain inside this repository out directory.'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$output = Join-Path $OutputDirectory 'cassotis_pinyin_transformer_ort.dll'
$build_id = '{0}_{1}' -f $PID, [Guid]::NewGuid().ToString('N')
$intermediateDir = Join-Path $root ('out\_tmp_build\pinyin_transformer_ort\' + $build_id)
$stagedOutput = Join-Path $intermediateDir 'cassotis_pinyin_transformer_ort.dll'
$object = Join-Path $intermediateDir 'cassotis_pinyin_transformer_ort.obj'
$vectorObject = Join-Path $intermediateDir 'nc_trie_attention_avx2.obj'
$importLibrary = Join-Path $intermediateDir 'cassotis_pinyin_transformer_ort.lib'
$pdb = Join-Path $intermediateDir 'cassotis_pinyin_transformer_ort.pdb'
$resourceScript = Join-Path $intermediateDir 'cassotis_pinyin_transformer_ort.rc'
$resource = Join-Path $intermediateDir 'cassotis_pinyin_transformer_ort.res'
$vcvars = $VcVarsPath
if ($vcvars.Trim() -eq '') {
    $vcvars = @(
        'C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat',
        'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($vcvars)) {
    throw 'Cannot find Visual Studio 2022 C++ vcvars64.bat. Use -VcVarsPath to specify it.'
}
$vcvars = (Resolve-Path -LiteralPath $vcvars).Path

foreach ($path in @($source, $include, $onnxLibrary, $versionProps, $vcvars)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing native build dependency: $path"
    }
}

New-Item -ItemType Directory -Path $intermediateDir -Force | Out-Null

[xml]$versionDocument = Get-Content -LiteralPath $versionProps -Encoding UTF8 -Raw
$versionNode = $versionDocument.SelectSingleNode(
    "/*[local-name()='Project']/*[local-name()='PropertyGroup']/*[local-name()='CassotisVersionQuad']")
if ($null -eq $versionNode) {
    throw "CassotisVersionQuad is missing from $versionProps"
}
$versionQuad = $versionNode.InnerText.Trim()
$versionParts = @($versionQuad.Split('.'))
if (($versionParts.Count -ne 4) -or
    ($versionParts | Where-Object {
        ($_ -notmatch '^\d+$') -or ([int64]$_ -gt 65535)
    })) {
    throw "Invalid CassotisVersionQuad in ${versionProps}: $versionQuad"
}
$versionComma = $versionParts -join ','
$resourceContent = @"
#include <windows.h>

1 VERSIONINFO
 FILEVERSION $versionComma
 PRODUCTVERSION $versionComma
 FILEFLAGSMASK 0x3fL
 FILEFLAGS 0x0L
 FILEOS VOS_NT_WINDOWS32
 FILETYPE VFT_DLL
 FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904B0"
        BEGIN
            VALUE "CompanyName", "Cassotis IME\0"
            VALUE "FileDescription", "Cassotis Pinyin Transformer ONNX Runtime Bridge\0"
            VALUE "FileVersion", "$versionQuad\0"
            VALUE "InternalName", "cassotis_pinyin_transformer_ort\0"
            VALUE "OriginalFilename", "cassotis_pinyin_transformer_ort.dll\0"
            VALUE "ProductName", "Cassotis IME\0"
            VALUE "ProductVersion", "$versionQuad\0"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x0409, 1200
    END
END
"@
[System.IO.File]::WriteAllText($resourceScript, $resourceContent,
    (New-Object System.Text.UTF8Encoding($false)))

$optimization = if ($Configuration -ieq 'Debug') { '/Od /Zi' } else { '/O2 /GL' }
$experimentalDefines = @()
if ($EnableExperimentalContextualRecall) {
    $experimentalDefines += '/DCASSOTIS_EXPERIMENTAL_CONTEXTUAL_RECALL'
}
if ($EnableExperimentalTop32CrossRanker) {
    $experimentalDefines += '/DCASSOTIS_EXPERIMENTAL_TOP32_CROSS_RANKER'
}
$experimentalDefine = $experimentalDefines -join ' '
$vectorCompile = ''
$vectorLink = ''
if (Test-Path -LiteralPath $vectorSource) {
    # No /GL here: link-time code generation must not move this code into
    # functions compiled for the baseline instruction set.
    $vectorOptimization = if ($Configuration -ieq 'Debug') { '/Od /Zi' } else { '/O2' }
    $vectorCompile = 'cl.exe /nologo /std:c++17 /EHsc /MD /c {0} /arch:AVX2 "{1}" /Fo"{2}" && ' -f
        $vectorOptimization, $vectorSource, $vectorObject
    $vectorLink = '"{0}" ' -f $vectorObject
}
$command = 'call "{0}" >nul && rc.exe /nologo /fo"{9}" "{10}" && {12}' +
    'cl.exe /nologo /std:c++17 /EHsc /MD /LD {1} {11} ' +
    '/I"{2}" "{3}" {13}/Fo"{4}" /link /LTCG /OUT:"{5}" ' +
    '/IMPLIB:"{6}" /PDB:"{7}" "{8}" "{9}"'
$command = $command -f $vcvars, $optimization, $include, $source, $object,
    $stagedOutput, $importLibrary, $pdb, $onnxLibrary, $resource, $resourceScript,
    $experimentalDefine, $vectorCompile, $vectorLink

try {
    & cmd.exe /d /s /c $command
    if ($LASTEXITCODE -ne 0) {
        throw "Native ONNX wrapper build failed with exit code $LASTEXITCODE"
    }

    $builtVersionInfo = (Get-Item -LiteralPath $stagedOutput).VersionInfo
    if (($builtVersionInfo.FileVersion.Trim() -ne $versionQuad) -or
        ($builtVersionInfo.ProductVersion.Trim() -ne $versionQuad)) {
        throw "Native ONNX wrapper version resource mismatch: expected $versionQuad, " +
            "got file=$($builtVersionInfo.FileVersion) product=$($builtVersionInfo.ProductVersion)"
    }

    publish_runtime_dll $stagedOutput $output $StopLockingRuntime.IsPresent

    $publishedVersionInfo = (Get-Item -LiteralPath $output).VersionInfo
    if (($publishedVersionInfo.FileVersion.Trim() -ne $versionQuad) -or
        ($publishedVersionInfo.ProductVersion.Trim() -ne $versionQuad)) {
        throw "Published native ONNX wrapper version resource mismatch: expected $versionQuad, " +
            "got file=$($publishedVersionInfo.FileVersion) product=$($publishedVersionInfo.ProductVersion)"
    }

    # Keep only the runtime DLL in out; linker artifacts are not release inputs.
    $staleReleaseArtifacts = @(
        (Join-Path $OutputDirectory 'cassotis_pinyin_transformer_ort.exp'),
        (Join-Path $OutputDirectory 'cassotis_pinyin_transformer_ort.lib'),
        (Join-Path $OutputDirectory 'cassotis_pinyin_transformer_ort.obj')
    )
    foreach ($artifact in $staleReleaseArtifacts) {
        if (Test-Path -LiteralPath $artifact) {
            Remove-Item -LiteralPath $artifact -Force
        }
    }
}
finally {
    if (Test-Path -LiteralPath $intermediateDir) {
        $resolvedIntermediate = [IO.Path]::GetFullPath($intermediateDir)
        $allowedIntermediate = [IO.Path]::GetFullPath((Join-Path $root 'out\_tmp_build\pinyin_transformer_ort')) + '\'
        if (-not $resolvedIntermediate.StartsWith($allowedIntermediate, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove an intermediate directory outside the native build workspace.'
        }
        Remove-Item -LiteralPath $intermediateDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[pinyin-transformer] built $output version=$versionQuad"
