param(
    [string]$Mode = 'stop',
    [string]$OutputPath = '',
    [string]$RuntimeDir = '',
    [string]$DataDir = ''
)

$ErrorActionPreference = 'SilentlyContinue'

function Ensure-RestartManagerApi
{
    if ('CassotisRestartManager.NativeMethods' -as [type])
    {
        return
    }

    $source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace CassotisRestartManager
{
    public static class NativeMethods
    {
        public const int CCH_RM_SESSION_KEY = 32;
        public const int ERROR_MORE_DATA = 234;

        [StructLayout(LayoutKind.Sequential)]
        public struct RM_UNIQUE_PROCESS
        {
            public int dwProcessId;
            public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct RM_PROCESS_INFO
        {
            public RM_UNIQUE_PROCESS Process;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
            public string strAppName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            public string strServiceShortName;
            public uint ApplicationType;
            public uint AppStatus;
            public uint TSSessionId;
            [MarshalAs(UnmanagedType.Bool)]
            public bool bRestartable;
        }

        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        public static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, StringBuilder strSessionKey);

        [DllImport("rstrtmgr.dll")]
        public static extern int RmEndSession(uint pSessionHandle);

        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        public static extern int RmRegisterResources(
            uint pSessionHandle,
            uint nFiles,
            string[] rgsFilenames,
            uint nApplications,
            RM_UNIQUE_PROCESS[] rgApplications,
            uint nServices,
            string[] rgsServiceNames);

        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        public static extern int RmGetList(
            uint dwSessionHandle,
            out uint pnProcInfoNeeded,
            ref uint pnProcInfo,
            [In, Out] RM_PROCESS_INFO[] rgAffectedApps,
            ref uint lpdwRebootReasons);
    }
}
"@

    Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
}

function Get-ProcessesLockingPath([string]$FilePath)
{
    $result = @()
    if ([string]::IsNullOrWhiteSpace($FilePath) -or (-not (Test-Path -LiteralPath $FilePath)))
    {
        return $result
    }

    try
    {
        Ensure-RestartManagerApi
    }
    catch
    {
        return $result
    }

    $sessionHandle = [uint32]0
    $sessionKey = New-Object System.Text.StringBuilder([CassotisRestartManager.NativeMethods]::CCH_RM_SESSION_KEY + 1)
    $startRc = [CassotisRestartManager.NativeMethods]::RmStartSession([ref]$sessionHandle, 0, $sessionKey)
    if ($startRc -ne 0)
    {
        return $result
    }

    try
    {
        $files = @($FilePath)
        $registerRc = [CassotisRestartManager.NativeMethods]::RmRegisterResources($sessionHandle, [uint32]$files.Count, $files, 0, $null, 0, $null)
        if ($registerRc -ne 0)
        {
            return $result
        }

        [uint32]$needed = 0
        [uint32]$count = 0
        [uint32]$reasons = 0
        $listRc = [CassotisRestartManager.NativeMethods]::RmGetList($sessionHandle, [ref]$needed, [ref]$count, $null, [ref]$reasons)
        if (($listRc -eq 0) -and ($needed -eq 0))
        {
            return $result
        }

        if (($listRc -eq [CassotisRestartManager.NativeMethods]::ERROR_MORE_DATA) -or ($needed -gt 0))
        {
            $count = $needed
            $apps = New-Object 'CassotisRestartManager.NativeMethods+RM_PROCESS_INFO[]' $count
            $listRc = [CassotisRestartManager.NativeMethods]::RmGetList($sessionHandle, [ref]$needed, [ref]$count, $apps, [ref]$reasons)
            if ($listRc -eq 0)
            {
                for ($idx = 0; $idx -lt $count; $idx++)
                {
                    $pidValue = $apps[$idx].Process.dwProcessId
                    if ($pidValue -le 0)
                    {
                        continue
                    }

                    $nameValue = ''
                    try
                    {
                        $nameValue = (Get-Process -Id $pidValue -ErrorAction Stop).ProcessName + '.exe'
                    }
                    catch
                    {
                        $nameValue = $apps[$idx].strAppName
                    }

                    $result += [PSCustomObject]@{
                        name = $nameValue
                        pid  = [int]$pidValue
                    }
                }
            }
        }
    }
    finally
    {
        [void][CassotisRestartManager.NativeMethods]::RmEndSession($sessionHandle)
    }

    return $result | Group-Object pid | ForEach-Object { $_.Group[0] }
}

function Get-ProcessesUsingDllByModuleScan([string]$DllName, [string]$DllPath)
{
    $result = @()
    if ([string]::IsNullOrWhiteSpace($DllName))
    {
        return $result
    }

    $targetName = $DllName.ToLowerInvariant()
    $targetPath = ''
    if (-not [string]::IsNullOrWhiteSpace($DllPath))
    {
        $targetPath = $DllPath.ToLowerInvariant()
    }

    $procs = Get-Process -ErrorAction SilentlyContinue
    foreach ($proc in $procs)
    {
        try
        {
            foreach ($module in $proc.Modules)
            {
                $moduleName = [System.IO.Path]::GetFileName($module.FileName).ToLowerInvariant()
                $modulePath = $module.FileName.ToLowerInvariant()
                if (($moduleName -eq $targetName) -or (($targetPath -ne '') -and ($modulePath -eq $targetPath)))
                {
                    $result += [PSCustomObject]@{
                        name = $proc.ProcessName + '.exe'
                        pid  = [int]$proc.Id
                    }
                    break
                }
            }
        }
        catch
        {
        }
    }

    return $result
}

function Get-TasklistModuleRows([string]$DllName)
{
    $rows = @()
    if ([string]::IsNullOrWhiteSpace($DllName))
    {
        return $rows
    }

    $candidates = @(
        (Join-Path $env:windir 'System32\tasklist.exe'),
        'tasklist'
    ) | Select-Object -Unique

    foreach ($tasklistCmd in $candidates)
    {
        if (($tasklistCmd -ne 'tasklist') -and (-not (Test-Path -LiteralPath $tasklistCmd)))
        {
            continue
        }

        try
        {
            $lines = & $tasklistCmd /m $DllName /fo csv /nh 2>$null
        }
        catch
        {
            continue
        }

        if ($null -eq $lines)
        {
            continue
        }

        foreach ($line in $lines)
        {
            if ([string]::IsNullOrWhiteSpace($line) -or ($line -notmatch '"'))
            {
                continue
            }

            $row = $line | ConvertFrom-Csv -Header 'ImageName', 'PID', 'Modules'
            if ($null -ne $row)
            {
                $rows += $row
            }
        }
    }

    return $rows
}

function Get-ProcessesUsingDll([string]$DllName, [string]$DllPath)
{
    $result = @()
    if ([string]::IsNullOrWhiteSpace($DllName))
    {
        return $result
    }

    foreach ($row in (Get-TasklistModuleRows -DllName $DllName))
    {
        if ([string]::IsNullOrWhiteSpace($row.ImageName) -or [string]::IsNullOrWhiteSpace($row.PID))
        {
            continue
        }

        if ($row.PID -match '^\d+$')
        {
            $result += [PSCustomObject]@{
                name = $row.ImageName
                pid  = [int]$row.PID
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($DllPath) -and (Test-Path -LiteralPath $DllPath))
    {
        $result += Get-ProcessesLockingPath -FilePath $DllPath
    }

    return $result | Group-Object pid | ForEach-Object { $_.Group[0] }
}

function Add-Target([hashtable]$Map, [string]$Name, [int]$TargetPid)
{
    if ([string]::IsNullOrWhiteSpace($Name) -or ($TargetPid -le 0))
    {
        return
    }
    if (-not $Map.ContainsKey($TargetPid))
    {
        $Map[$TargetPid] = "$Name (PID $TargetPid)"
    }
}

function Get-TargetFiles([string]$RuntimeDir, [string]$DataDir)
{
    $files = @()
    if (-not [string]::IsNullOrWhiteSpace($RuntimeDir))
    {
        $files += (Join-Path $RuntimeDir 'cassotis_ime_host.exe')
        $files += (Join-Path $RuntimeDir 'cassotis_ime_tray_host.exe')
        $files += (Join-Path $RuntimeDir 'cassotis_ime_svr.dll')
        $files += (Join-Path $RuntimeDir 'cassotis_ime_svr32.dll')
        $files += (Join-Path $RuntimeDir 'cassotis_ime_profile_reg.exe')
        $files += (Join-Path $RuntimeDir 'sqlite3_64.dll')
    }
    if (-not [string]::IsNullOrWhiteSpace($DataDir))
    {
        $files += (Join-Path $DataDir 'dict_sc.db')
        $files += (Join-Path $DataDir 'dict_tc.db')
    }
    return $files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$targets = @{}
$targetFiles = Get-TargetFiles -RuntimeDir $RuntimeDir -DataDir $DataDir
$imageNames = @('ctfmon.exe', 'cassotis_ime_host.exe', 'cassotis_ime_tray_host.exe')
$selfPid = $PID

foreach ($imageName in $imageNames)
{
    Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($imageName)) -ErrorAction SilentlyContinue | ForEach-Object {
        Add-Target -Map $targets -Name ($_.ProcessName + '.exe') -TargetPid ([int]$_.Id)
    }
}

foreach ($filePath in $targetFiles)
{
    foreach ($proc in (Get-ProcessesLockingPath -FilePath $filePath))
    {
        Add-Target -Map $targets -Name $proc.name -TargetPid $proc.pid
    }

    $fileName = [System.IO.Path]::GetFileName($filePath)
    if (($fileName -ieq 'cassotis_ime_svr.dll') -or ($fileName -ieq 'cassotis_ime_svr32.dll'))
    {
        foreach ($proc in (Get-ProcessesUsingDll -DllName $fileName -DllPath $filePath))
        {
            Add-Target -Map $targets -Name $proc.name -TargetPid $proc.pid
        }
    }
}

$lines = $targets.GetEnumerator() | Sort-Object Key | ForEach-Object { $_.Value }
if ($targets.ContainsKey($selfPid))
{
    $targets.Remove($selfPid)
    $lines = $targets.GetEnumerator() | Sort-Object Key | ForEach-Object { $_.Value }
}
if ($null -eq $lines)
{
    $lines = @()
}
if (-not [string]::IsNullOrWhiteSpace($OutputPath))
{
    [System.IO.File]::WriteAllLines($OutputPath, $lines)
}

if ($Mode -eq 'stop')
{
    foreach ($targetLine in ($targets.GetEnumerator() | Sort-Object Key))
    {
        & taskkill.exe /PID $targetLine.Key /F /T | Out-Null
    }

    Start-Sleep -Milliseconds 500

    $remaining = @{}
    foreach ($imageName in $imageNames)
    {
        Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($imageName)) -ErrorAction SilentlyContinue | ForEach-Object {
            Add-Target -Map $remaining -Name ($_.ProcessName + '.exe') -TargetPid ([int]$_.Id)
        }
    }

    foreach ($filePath in $targetFiles)
    {
        foreach ($proc in (Get-ProcessesLockingPath -FilePath $filePath))
        {
            Add-Target -Map $remaining -Name $proc.name -TargetPid $proc.pid
        }

        $fileName = [System.IO.Path]::GetFileName($filePath)
        if (($fileName -ieq 'cassotis_ime_svr.dll') -or ($fileName -ieq 'cassotis_ime_svr32.dll'))
        {
            foreach ($proc in (Get-ProcessesUsingDll -DllName $fileName -DllPath $filePath))
            {
                Add-Target -Map $remaining -Name $proc.name -TargetPid $proc.pid
            }
        }
    }

    if ($remaining.Count -gt 0)
    {
        exit 1
    }
}
