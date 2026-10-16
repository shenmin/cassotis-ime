# Where the base dictionaries are, for the development scripts. An installed
# runtime reads its own read-only copy (<runtime>\base_dict, shared by every
# Windows account); a development layout (out\) reads the copy under
# %LOCALAPPDATA%\CassotisIme\data that out\rebuild_dict.ps1 writes, the
# benchmarks snapshot and out\rebuild_installer.ps1 packages.

# Setup removes the base dictionaries earlier versions left in a profile, but
# not from a data folder holding this file: rebuild_dict.ps1 writes it there.
$CassotisDevDictionaryMarker = 'development_dictionaries.txt'

function Get-CassotisRegisteredRuntimeDir {
    $key = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\CLSID\{38D40A05-DCDB-49FB-81A4-C8745882DC21}\InprocServer32'
    try {
        $dll = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).'(default)'
    }
    catch {
        return ''
    }
    if ([string]::IsNullOrWhiteSpace($dll)) {
        return ''
    }
    return Split-Path -Parent ($dll.Trim().Trim('"'))
}

# The base dictionary the registered input method reads when it is an
# installed runtime; empty for a development layout or no registration.
function Get-CassotisInstalledBaseDictionary {
    param([Parameter(Mandatory = $true)][string]$Name)
    $dir = Get-CassotisRegisteredRuntimeDir
    if ($dir -eq '') {
        return ''
    }
    $path = Join-Path (Join-Path $dir 'base_dict') $Name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return $path
    }
    return ''
}

function Write-CassotisDevDictionaryMarker {
    param([Parameter(Mandatory = $true)][string]$DataDir)
    $text = "Written by out\rebuild_dict.ps1: dict_sc.db and dict_tc.db in this folder are a`r`n" +
        "development build. Setup leaves them here while this file exists.`r`n"
    [IO.File]::WriteAllText((Join-Path $DataDir $CassotisDevDictionaryMarker), $text,
        (New-Object Text.UTF8Encoding $false))
}

# Every account reads the packaged copy without write access to its folder.
# SQLite opens a rollback-journal database read-only there; a WAL database
# needs its -shm file and would not open at all, and a leftover journal would
# have to be rolled back first. Either would leave every account without
# candidates.
function Assert-CassotisPackagedDictionary {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = New-Object byte[] 20
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $read = $stream.Read($bytes, 0, 20)
    }
    finally {
        $stream.Dispose()
    }
    if (($read -lt 20) -or ([Text.Encoding]::ASCII.GetString($bytes, 0, 15) -ne 'SQLite format 3')) {
        throw "$Path is no SQLite database."
    }
    if (($bytes[18] -ne 1) -or ($bytes[19] -ne 1)) {
        $message = "$Path is not in rollback-journal mode (file format $($bytes[18])/$($bytes[19])): " +
            'run PRAGMA journal_mode=DELETE on it before packaging.'
        throw $message
    }
    foreach ($suffix in @('-journal', '-wal', '-shm')) {
        if (Test-Path -LiteralPath ($Path + $suffix)) {
            throw "$Path$suffix exists: close the programs that write the dictionary before packaging."
        }
    }
}
