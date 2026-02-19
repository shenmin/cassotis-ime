$ErrorActionPreference = 'Stop'

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir

$root_dir = (Get-Item (Join-Path $script_dir '..')).FullName
$rsvars_path = 'C:\Program Files (x86)\Embarcadero\Studio\21.0\bin\rsvars.bat'
$is_admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$win32_stage_dir = Join-Path $script_dir '_win32_stage'
$win64_stage_dir = Join-Path $script_dir '_win64_stage'
$build_timeout_seconds = 1800
$process_timeout_seconds = 30
$enable_module_scan = $false
$enable_restart_manager_scan = $false

if ($env:CASSOTIS_BUILD_TIMEOUT_SECONDS)
{
    $tmp = 0
    if ([int]::TryParse($env:CASSOTIS_BUILD_TIMEOUT_SECONDS, [ref]$tmp) -and ($tmp -gt 0))
    {
        $build_timeout_seconds = $tmp
    }
}

if ($env:CASSOTIS_PROCESS_TIMEOUT_SECONDS)
{
    $tmp = 0
    if ([int]::TryParse($env:CASSOTIS_PROCESS_TIMEOUT_SECONDS, [ref]$tmp) -and ($tmp -gt 0))
    {
        $process_timeout_seconds = $tmp
    }
}

if ($env:CASSOTIS_ENABLE_MODULE_SCAN -and ($env:CASSOTIS_ENABLE_MODULE_SCAN -eq '1'))
{
    $enable_module_scan = $true
}

if ($env:CASSOTIS_ENABLE_RESTART_MANAGER_SCAN -and ($env:CASSOTIS_ENABLE_RESTART_MANAGER_SCAN -eq '1'))
{
    $enable_restart_manager_scan = $true
}

function invoke_process_with_timeout([string]$file_path, [string]$arguments, [int]$timeout_seconds, [string]$step_name)
{
    Write-Host ("[{0}] Start: {1}" -f (Get-Date -Format 'HH:mm:ss'), $step_name)
    $proc = Start-Process -FilePath $file_path -ArgumentList $arguments -PassThru -NoNewWindow
    if ($null -eq $proc)
    {
        throw "Failed to start process for step: $step_name"
    }

    $start_at = Get-Date
    $last_heartbeat = $start_at
    while (-not $proc.HasExited)
    {
        Start-Sleep -Milliseconds 500
        $now = Get-Date
        $elapsed = ($now - $start_at).TotalSeconds
        if (($now - $last_heartbeat).TotalSeconds -ge 20)
        {
            Write-Host ("[{0}] Running ({1}s): {2}" -f (Get-Date -Format 'HH:mm:ss'), [int]$elapsed, $step_name)
            $last_heartbeat = $now
        }

        if ($elapsed -ge $timeout_seconds)
        {
            Write-Host ("Timeout reached ({0}s), killing step: {1}" -f [int]$elapsed, $step_name)
            try
            {
                & taskkill /PID $proc.Id /F /T | Out-Null
            }
            catch
            {
            }
            try
            {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
            catch
            {
            }
            throw "Timeout in step: $step_name"
        }
    }

    $exit_code = 0
    try
    {
        if ($null -ne $proc.ExitCode)
        {
            $exit_code = [int]$proc.ExitCode
        }
    }
    catch
    {
        $exit_code = 0
    }

    if ($exit_code -ne 0)
    {
        throw ("Step failed: {0} (exit {1})" -f $step_name, $exit_code)
    }

    Write-Host ("[{0}] Done: {1}" -f (Get-Date -Format 'HH:mm:ss'), $step_name)
}

function remove_item_with_retry([string]$path, [bool]$recurse = $false, [bool]$strict = $false)
{
    if (-not (Test-Path -LiteralPath $path))
    {
        return $true
    }

    $last_error = $null
    for ($attempt = 1; $attempt -le 3; $attempt++)
    {
        try
        {
            if (-not $recurse)
            {
                try
                {
                    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
                }
                catch
                {
                }
            }

            if ($recurse)
            {
                Remove-Item -Recurse -Force -LiteralPath $path -ErrorAction Stop
            }
            else
            {
                Remove-Item -Force -LiteralPath $path -ErrorAction Stop
            }
            return $true
        }
        catch
        {
            $last_error = $_
            Start-Sleep -Milliseconds 300
        }
    }

    if ($strict)
    {
        throw "Failed to remove path: $path. $($last_error.Exception.Message)"
    }

    Write-Host "Warning: cannot remove $path, continue building. $($last_error.Exception.Message)"
    return $false
}

function move_item_with_retry([string]$source_path, [string]$target_path, [bool]$strict = $true)
{
    if (-not (Test-Path -LiteralPath $source_path))
    {
        if ($strict)
        {
            throw "Source file not found: $source_path"
        }
        return $false
    }

    $last_error = $null
    for ($attempt = 1; $attempt -le 3; $attempt++)
    {
        try
        {
            remove_item_with_retry $target_path $false $false | Out-Null
            Move-Item -Force -LiteralPath $source_path -Destination $target_path -ErrorAction Stop
            return $true
        }
        catch
        {
            $last_error = $_
            Start-Sleep -Milliseconds 300
        }
    }

    $target_dir = Split-Path -Parent $target_path
    $target_name = [System.IO.Path]::GetFileNameWithoutExtension($target_path)
    $target_ext = [System.IO.Path]::GetExtension($target_path)
    $target_alt = Join-Path $target_dir ("{0}.new{1}" -f $target_name, $target_ext)
    try
    {
        remove_item_with_retry $target_alt $false $false | Out-Null
        Move-Item -Force -LiteralPath $source_path -Destination $target_alt -ErrorAction Stop
        Write-Host "Warning: cannot replace '$target_path'. New output saved to '$target_alt'."
        return $true
    }
    catch
    {
        $last_error = $_
    }

    if ($strict)
    {
        throw "Failed to move '$source_path' to '$target_path'. $($last_error.Exception.Message)"
    }

    Write-Host "Warning: cannot move '$source_path' to '$target_path'. $($last_error.Exception.Message)"
    return $false
}

function get_pe_machine([string]$path)
{
    if (-not (Test-Path -LiteralPath $path))
    {
        return $null
    }

    $stream = $null
    $reader = $null
    try
    {
        $stream = [System.IO.File]::OpenRead($path)
        $reader = New-Object System.IO.BinaryReader $stream
        if ($reader.ReadUInt16() -ne 0x5A4D)
        {
            return $null
        }

        $stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $pe_offset = $reader.ReadInt32()
        $stream.Seek($pe_offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        if ($reader.ReadUInt32() -ne 0x00004550)
        {
            return $null
        }

        return $reader.ReadUInt16()
    }
    finally
    {
        if ($reader -ne $null)
        {
            $reader.Close()
        }
        elseif ($stream -ne $null)
        {
            $stream.Close()
        }
    }
}

function assert_expected_machine([string]$path, [UInt16]$expected_machine)
{
    $machine = get_pe_machine $path
    if ($null -eq $machine)
    {
        throw "Invalid PE output: $path"
    }
    if ($machine -ne $expected_machine)
    {
        throw ("Architecture mismatch: {0} machine=0x{1:X4}, expected=0x{2:X4}" -f $path, $machine, $expected_machine)
    }
}

remove_item_with_retry $win32_stage_dir $true $false | Out-Null
New-Item -ItemType Directory -Force -Path $win32_stage_dir | Out-Null
remove_item_with_retry $win64_stage_dir $true $false | Out-Null
New-Item -ItemType Directory -Force -Path $win64_stage_dir | Out-Null

if (-not (Test-Path -LiteralPath $rsvars_path))
{
    throw "rsvars.bat not found: $rsvars_path"
}

if (-not $is_admin)
{
    Write-Host "Warning: not running as Administrator. Killing DLL-holding processes may fail."
}

function ensure_restart_manager_api
{
    if (([System.Management.Automation.PSTypeName]'CassotisRestartManager.NativeMethods').Type -ne $null)
    {
        return
    }

    $source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Runtime.InteropServices.ComTypes;

namespace CassotisRestartManager
{
    public static class NativeMethods
    {
        public const int ERROR_MORE_DATA = 234;
        public const int CCH_RM_SESSION_KEY = 32;
        public const int CCH_RM_MAX_APP_NAME = 255;
        public const int CCH_RM_MAX_SVC_NAME = 63;

        [StructLayout(LayoutKind.Sequential)]
        public struct RM_UNIQUE_PROCESS
        {
            public int dwProcessId;
            public FILETIME ProcessStartTime;
        }

        public enum RM_APP_TYPE
        {
            RmUnknownApp = 0,
            RmMainWindow = 1,
            RmOtherWindow = 2,
            RmService = 3,
            RmExplorer = 4,
            RmConsole = 5,
            RmCritical = 1000
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct RM_PROCESS_INFO
        {
            public RM_UNIQUE_PROCESS Process;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_APP_NAME + 1)]
            public string strAppName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_SVC_NAME + 1)]
            public string strServiceShortName;
            public RM_APP_TYPE ApplicationType;
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
            [In] RM_UNIQUE_PROCESS[] rgApplications,
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

function get_processes_locking_path([string]$file_path)
{
    $result = @()
    if (-not (Test-Path -LiteralPath $file_path))
    {
        return $result
    }

    try
    {
        ensure_restart_manager_api
    }
    catch
    {
        return $result
    }

    $session_handle = [uint32]0
    $session_key = New-Object System.Text.StringBuilder([CassotisRestartManager.NativeMethods]::CCH_RM_SESSION_KEY + 1)
    $start_rc = [CassotisRestartManager.NativeMethods]::RmStartSession([ref]$session_handle, 0, $session_key)
    if ($start_rc -ne 0)
    {
        return $result
    }

    try
    {
        $files = @($file_path)
        $register_rc = [CassotisRestartManager.NativeMethods]::RmRegisterResources($session_handle, [uint32]$files.Count, $files, 0, $null, 0, $null)
        if ($register_rc -ne 0)
        {
            return $result
        }

        [uint32]$needed = 0
        [uint32]$count = 0
        [uint32]$reasons = 0
        $list_rc = [CassotisRestartManager.NativeMethods]::RmGetList($session_handle, [ref]$needed, [ref]$count, $null, [ref]$reasons)
        if (($list_rc -eq 0) -and ($needed -eq 0))
        {
            return $result
        }

        if (($list_rc -eq [CassotisRestartManager.NativeMethods]::ERROR_MORE_DATA) -or ($needed -gt 0))
        {
            $count = $needed
            $apps = New-Object 'CassotisRestartManager.NativeMethods+RM_PROCESS_INFO[]' $count
            $list_rc = [CassotisRestartManager.NativeMethods]::RmGetList($session_handle, [ref]$needed, [ref]$count, $apps, [ref]$reasons)
            if ($list_rc -eq 0)
            {
                for ($idx = 0; $idx -lt $count; $idx++)
                {
                    $pid_value = $apps[$idx].Process.dwProcessId
                    if ($pid_value -le 0)
                    {
                        continue
                    }

                    $name_value = ''
                    try
                    {
                        $name_value = (Get-Process -Id $pid_value -ErrorAction Stop).ProcessName + '.exe'
                    }
                    catch
                    {
                        $name_value = $apps[$idx].strAppName
                    }

                    $result += [PSCustomObject]@{
                        name = $name_value
                        pid = [int]$pid_value
                    }
                }
            }
        }
    }
    finally
    {
        [void][CassotisRestartManager.NativeMethods]::RmEndSession($session_handle)
    }

    return $result | Group-Object pid | ForEach-Object { $_.Group[0] }
}

function get_processes_using_dll_by_module_scan([string]$dll_name, [string]$dll_path)
{
    $result = @()
    $target_name = $dll_name.ToLowerInvariant()
    $target_path = ''
    if ($dll_path -ne '')
    {
        $target_path = $dll_path.ToLowerInvariant()
    }

    $procs = Get-Process -ErrorAction SilentlyContinue
    foreach ($proc in $procs)
    {
        try
        {
            foreach ($module in $proc.Modules)
            {
                $module_name = [System.IO.Path]::GetFileName($module.FileName).ToLowerInvariant()
                $module_path = $module.FileName.ToLowerInvariant()
                if (($module_name -eq $target_name) -or (($target_path -ne '') -and ($module_path -eq $target_path)))
                {
                    $result += [PSCustomObject]@{
                        name = $proc.ProcessName + '.exe'
                        pid = [int]$proc.Id
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

function test_file_locked([string]$file_path)
{
    if (-not (Test-Path -LiteralPath $file_path))
    {
        return $false
    }

    $stream = $null
    try
    {
        $stream = [System.IO.File]::Open($file_path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        return $false
    }
    catch
    {
        return $true
    }
    finally
    {
        if ($stream -ne $null)
        {
            $stream.Close()
        }
    }
}

function try_quarantine_locked_file([string]$file_path)
{
    if (-not (Test-Path -LiteralPath $file_path))
    {
        return $true
    }

    $dir = Split-Path -Parent $file_path
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file_path)
    $ext = [System.IO.Path]::GetExtension($file_path)

    for ($attempt = 1; $attempt -le 3; $attempt++)
    {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $backup = Join-Path $dir ("{0}.locked.{1}{2}" -f $name, $stamp, $ext)
        try
        {
            try
            {
                [System.IO.File]::SetAttributes($file_path, [System.IO.FileAttributes]::Normal)
            }
            catch
            {
            }

            Move-Item -Force -LiteralPath $file_path -Destination $backup -ErrorAction Stop
            Write-Host ("Quarantined locked file: {0} -> {1}" -f $file_path, $backup)
            return $true
        }
        catch
        {
            Start-Sleep -Milliseconds 250
        }
    }

    return $false
}

function get_tasklist_module_rows([string]$dll_name)
{
    $rows = @()
    $candidates = @(
        (Join-Path $env:windir 'System32\tasklist.exe'),
        'tasklist'
    ) | Select-Object -Unique

    foreach ($tasklist_cmd in $candidates)
    {
        if (($tasklist_cmd -ne 'tasklist') -and (-not (Test-Path -LiteralPath $tasklist_cmd)))
        {
            continue
        }

        try
        {
            $lines = & $tasklist_cmd /m $dll_name /fo csv /nh 2>$null
        }
        catch
        {
            continue
        }

        if ($lines -eq $null)
        {
            continue
        }

        foreach ($line in $lines)
        {
            if (-not $line -or ($line -notmatch '"'))
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

function get_processes_using_dll([string]$dll_name)
{
    $dll_path = Join-Path $script_dir $dll_name
    $result = @()

    $rows = get_tasklist_module_rows $dll_name
    foreach ($row in $rows)
    {
        if (-not $row.ImageName -or -not $row.PID)
        {
            continue
        }

        $pid_value = $row.PID
        if ($pid_value -eq $null -or $pid_value -eq '')
        {
            continue
        }

        if ($pid_value -match '^\d+$')
        {
            $result += [PSCustomObject]@{
                name = $row.ImageName
                pid = [int]$pid_value
            }
        }
    }

    if ($enable_module_scan)
    {
        $result += get_processes_using_dll_by_module_scan $dll_name $dll_path
    }

    if ($enable_restart_manager_scan -and (Test-Path -LiteralPath $dll_path))
    {
        $result += get_processes_locking_path $dll_path
    }

    $map = @{}
    foreach ($proc in $result)
    {
        if ($proc.pid -is [int])
        {
            $map[$proc.pid] = $proc
        }
    }

    return $map.Values | Sort-Object pid
}

function stop_engine_host
{
    $procs = Get-Process -Name cassotis_ime_host, cassotis_ime_host32 -ErrorAction SilentlyContinue
    if (-not $procs)
    {
        return
    }

    Write-Host "Stopping cassotis_ime_host.exe..."
    foreach ($proc in $procs)
    {
        try
        {
            if ($proc.MainWindowHandle -ne 0)
            {
                $null = $proc.CloseMainWindow()
            }
        }
        catch
        {
        }
    }

    foreach ($proc in $procs)
    {
        try
        {
            $null = $proc.WaitForExit(2000)
        }
        catch
        {
        }
    }

    $procs = Get-Process -Name cassotis_ime_host, cassotis_ime_host32 -ErrorAction SilentlyContinue
    foreach ($proc in $procs)
    {
        try
        {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
        catch
        {
        }
    }
}

function stop_processes_using_dll([string[]]$dll_names)
{
    Write-Host ("Scanning DLL usage (module_scan={0}, rm_scan={1})..." -f [int]$enable_module_scan, [int]$enable_restart_manager_scan)
    $process_map = @{}
    foreach ($dll_name in $dll_names)
    {
        Write-Host ("Scan: {0}" -f $dll_name)
        $processes = get_processes_using_dll $dll_name
        foreach ($proc in $processes)
        {
            $process_map[$proc.pid] = $proc
        }
    }

    if ($process_map.Count -eq 0)
    {
        Write-Host "No processes using TSF DLLs."
        return
    }

    $process_list = $process_map.Values | Sort-Object pid
    Write-Host "Processes using TSF DLLs:"
    $process_list | Format-Table -AutoSize

    $killed_explorer = $false
    foreach ($proc in $process_list)
    {
        $stopped = $false
        try
        {
            Stop-Process -Id $proc.pid -Force -ErrorAction Stop
            $stopped = $true
        }
        catch
        {
        }

        if (-not $stopped)
        {
            try
            {
                invoke_process_with_timeout 'taskkill.exe' ("/PID {0} /F /T" -f $proc.pid) $process_timeout_seconds ("taskkill PID {0}" -f $proc.pid)
                $stopped = $true
            }
            catch
            {
            }
        }

        if ($stopped)
        {
            Write-Host ("Stopped {0} (PID {1})" -f $proc.name, $proc.pid)
            if ($proc.name -ieq 'explorer.exe')
            {
                $killed_explorer = $true
            }
        }
        else
        {
            Write-Host ("Failed to stop {0} (PID {1})" -f $proc.name, $proc.pid)
        }
    }

    if ($killed_explorer)
    {
        Write-Host "Restarting explorer.exe..."
        Start-Process -FilePath explorer.exe
    }

    Start-Sleep -Milliseconds 500
    foreach ($dll_name in $dll_names)
    {
        $dll_path = Join-Path $script_dir $dll_name
        $remaining = get_processes_using_dll $dll_name
        if ($remaining.Count -gt 0)
        {
            Write-Host ("Still using {0}:" -f $dll_name)
            $remaining | Format-Table -AutoSize
            if (-not (try_quarantine_locked_file $dll_path))
            {
                throw "DLL still in use: $dll_name"
            }
            continue
        }

        if (test_file_locked $dll_path)
        {
            Write-Host ("File still locked: {0}" -f $dll_path)
            $locking = get_processes_locking_path $dll_path
            if ($locking.Count -gt 0)
            {
                $locking | Format-Table -AutoSize
                if (-not (try_quarantine_locked_file $dll_path))
                {
                    throw "DLL file is locked: $dll_name"
                }
                continue
            }

            if (-not (try_quarantine_locked_file $dll_path))
            {
                throw "DLL file is locked and cannot be quarantined: $dll_name"
            }
        }
    }
}

function invoke_build([string]$project_rel, [string]$platform, [string]$exe_output = '', [string]$expected_output = '')
{
    $project_path = Join-Path $root_dir $project_rel
    if (-not (Test-Path -LiteralPath $project_path))
    {
        throw "Project not found: $project_path"
    }

    Write-Host ("Building {0} ({1})..." -f $project_rel, $platform)
    $cmd = "`"$rsvars_path`" && msbuild `"$project_path`" /t:Build /p:Config=Release /p:Platform=$platform"
    if ($exe_output -ne '')
    {
        if (-not (Test-Path -LiteralPath $exe_output))
        {
            New-Item -ItemType Directory -Force -Path $exe_output | Out-Null
        }
        $cmd += " /p:DCC_ExeOutput=`"$exe_output`""
    }

    if ($expected_output -ne '')
    {
        if (Test-Path -LiteralPath $expected_output)
        {
            $removed = remove_item_with_retry $expected_output $false $false
            if ((-not $removed) -and (test_file_locked $expected_output))
            {
                if (-not (try_quarantine_locked_file $expected_output))
                {
                    Write-Host ("Warning: expected output is locked and cannot be quarantined: {0}" -f $expected_output)
                }
            }
        }
    }

    $cmd_args = "/d /s /c `"$cmd`""
    invoke_process_with_timeout $env:ComSpec $cmd_args $build_timeout_seconds ("build {0} ({1})" -f $project_rel, $platform)

    if ($expected_output -ne '')
    {
        if (-not (Test-Path -LiteralPath $expected_output))
        {
            throw "Expected output not found: $expected_output"
        }
    }
}

function copy_sqlite_binaries
{
    $sqlite64_source = Join-Path $root_dir 'third_party\sqlite\win64\sqlite3.dll'
    $sqlite64_target = Join-Path $script_dir 'sqlite3_64.dll'

    if (Test-Path -LiteralPath $sqlite64_source)
    {
        Copy-Item -Force -LiteralPath $sqlite64_source -Destination $sqlite64_target
    }
    else
    {
        Write-Host "Warning: sqlite Win64 binary not found: $sqlite64_source"
    }
}

stop_engine_host
Write-Host ("[{0}] Start rebuild_all.ps1" -f (Get-Date -Format 'HH:mm:ss'))
stop_processes_using_dll @('cassotis_ime_svr.dll', 'cassotis_ime_svr32.dll')

$tsf_project = 'src\tsf\cassotis_ime_svr.dproj'
$tsf_win32_stage = Join-Path $win32_stage_dir 'cassotis_ime_svr.dll'
$tsf_win64_stage = Join-Path $win64_stage_dir 'cassotis_ime_svr.dll'
$tsf_win32 = Join-Path $script_dir 'cassotis_ime_svr32.dll'
$tsf_win64 = Join-Path $script_dir 'cassotis_ime_svr.dll'

invoke_build $tsf_project 'Win32' $win32_stage_dir $tsf_win32_stage
move_item_with_retry $tsf_win32_stage $tsf_win32 $true | Out-Null
assert_expected_machine $tsf_win32 0x014c
invoke_build $tsf_project 'Win64' $win64_stage_dir $tsf_win64_stage
move_item_with_retry $tsf_win64_stage $tsf_win64 $true | Out-Null
assert_expected_machine $tsf_win64 0x8664

$build_list = @(
    @{ path = 'tools\cassotis_ime_host.dproj'; exe = 'cassotis_ime_host.exe' },
    @{ path = 'tools\cassotis_ime_profile_reg.dproj'; exe = 'cassotis_ime_profile_reg.exe' },
    @{ path = 'tools\cassotis_ime_tray_host.dproj'; exe = 'cassotis_ime_tray_host.exe' },
    @{ path = 'tools\cassotis_ime_dict_init.dproj'; exe = 'cassotis_ime_dict_init.exe' },
    @{ path = 'tools\cassotis_ime_unihan_import.dproj'; exe = 'cassotis_ime_unihan_import.exe' },
    @{ path = 'tools\cassotis_ime_variant_convert.dproj'; exe = 'cassotis_ime_variant_convert.exe' }
)

foreach ($item in $build_list)
{
    $win64_output = Join-Path $win64_stage_dir $item.exe
    $win64_final = Join-Path $script_dir $item.exe
    $exe_name = [System.IO.Path]::GetFileNameWithoutExtension($item.exe)
    $win32_legacy_final = Join-Path $script_dir ($exe_name + '32.exe')

    invoke_build $item.path 'Win64' $win64_stage_dir $win64_output

    stop_engine_host

    if (Test-Path -LiteralPath $win64_final)
    {
        remove_item_with_retry $win64_final $false $false | Out-Null
    }
    move_item_with_retry $win64_output $win64_final $true | Out-Null
    assert_expected_machine $win64_final 0x8664

    if (Test-Path -LiteralPath $win32_legacy_final)
    {
        remove_item_with_retry $win32_legacy_final $false $false | Out-Null
    }
}

if (Test-Path -LiteralPath $win32_stage_dir)
{
    remove_item_with_retry $win32_stage_dir $true $false | Out-Null
}
if (Test-Path -LiteralPath $win64_stage_dir)
{
    remove_item_with_retry $win64_stage_dir $true $false | Out-Null
}

copy_sqlite_binaries

Write-Host 'Rebuild completed.'
