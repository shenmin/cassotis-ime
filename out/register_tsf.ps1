param(
    [string]$dll_path = (Join-Path $PSScriptRoot "cassotis_ime_svr.dll"),
    [switch]$single
)

function get_pe_machine([string]$path)
{
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
    catch
    {
        return $null
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

function test_expected_machine([string]$path, [UInt16]$machine)
{
    $name = [System.IO.Path]::GetFileName($path).ToLowerInvariant()
    if ($name -eq 'cassotis_ime_svr.dll')
    {
        return $machine -eq 0x8664
    }
    if ($name -eq 'cassotis_ime_svr32.dll')
    {
        return $machine -eq 0x014c
    }
    return $true
}

function get_regsvr32_path([string]$path)
{
    $machine = get_pe_machine $path
    $regsvr32_path = Join-Path $env:WINDIR "System32\\regsvr32.exe"
    if ($machine -eq 0x014c)
    {
        $candidate = Join-Path $env:WINDIR "SysWOW64\\regsvr32.exe"
        if (Test-Path $candidate)
        {
            $regsvr32_path = $candidate
        }
    }

    return @($regsvr32_path, $machine)
}

function invoke_regsvr32([string]$regsvr32_path, [string[]]$arguments)
{
    $arg_text = $arguments -join ' '
    $proc = Start-Process -FilePath $regsvr32_path -ArgumentList $arg_text -Wait -PassThru -WindowStyle Hidden
    if ($null -eq $proc)
    {
        return 1
    }

    return $proc.ExitCode
}

function get_inproc_server_path([string]$clsid, [Microsoft.Win32.RegistryView]$view, [Microsoft.Win32.RegistryHive]$hive)
{
    $base = $null
    $key = $null
    try
    {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
        $key_path = "Software\\Classes\\CLSID\\$clsid\\InprocServer32"
        if ($hive -eq [Microsoft.Win32.RegistryHive]::ClassesRoot)
        {
            $key_path = "CLSID\\$clsid\\InprocServer32"
        }

        $key = $base.OpenSubKey($key_path)
        if ($key -eq $null)
        {
            return $null
        }

        return $key.GetValue('')
    }
    finally
    {
        if ($key -ne $null)
        {
            $key.Close()
        }
        if ($base -ne $null)
        {
            $base.Close()
        }
    }
}

function get_com_registration_entries([string]$clsid, [Microsoft.Win32.RegistryView]$view)
{
    $entries = @()
    foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryHive]::ClassesRoot))
    {
        $actual = get_inproc_server_path $clsid $view $hive
        if ($actual -ne $null)
        {
            $entries += [PSCustomObject]@{
                hive = $hive.ToString()
                view = $view.ToString()
                path = $actual
            }
        }
    }

    return $entries
}

function is_com_registered([string]$clsid, [string]$expected_path, [Microsoft.Win32.RegistryView]$view, [ref]$entries_out)
{
    $expected = ([System.IO.Path]::GetFullPath($expected_path)).ToLowerInvariant()
    $expected_file = ([System.IO.Path]::GetFileName($expected_path)).ToLowerInvariant()
    $entries = get_com_registration_entries $clsid $view
    $entries_out.Value = $entries
    foreach ($entry in $entries)
    {
        $actual = $entry.path
        if ($actual -ne $null -and $actual -ne '')
        {
            $normalized = $actual.Trim('"')
            try
            {
                $normalized = ([System.IO.Path]::GetFullPath($normalized)).ToLowerInvariant()
            }
            catch
            {
                $normalized = $normalized.ToLowerInvariant()
            }

            if ($normalized -eq $expected)
            {
                return $true
            }

            $actual_file = ([System.IO.Path]::GetFileName($normalized)).ToLowerInvariant()
            if ($actual_file -eq $expected_file)
            {
                return $true
            }
        }
    }

    return $false
}

function is_com_registered_in_hive([string]$clsid, [string]$expected_path, [Microsoft.Win32.RegistryView]$view, [Microsoft.Win32.RegistryHive]$hive)
{
    $expected = ([System.IO.Path]::GetFullPath($expected_path)).ToLowerInvariant()
    $expected_file = ([System.IO.Path]::GetFileName($expected_path)).ToLowerInvariant()
    $actual = get_inproc_server_path $clsid $view $hive
    if ($null -eq $actual -or $actual -eq '')
    {
        return $false
    }

    $normalized = $actual.Trim('"')
    try
    {
        $normalized = ([System.IO.Path]::GetFullPath($normalized)).ToLowerInvariant()
    }
    catch
    {
        $normalized = $normalized.ToLowerInvariant()
    }

    if ($normalized -eq $expected)
    {
        return $true
    }

    $actual_file = ([System.IO.Path]::GetFileName($normalized)).ToLowerInvariant()
    return ($actual_file -eq $expected_file)
}

function remove_registry_subtree([Microsoft.Win32.RegistryHive]$hive, [Microsoft.Win32.RegistryView]$view, [string]$sub_key)
{
    $base = $null
    try
    {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
        try
        {
            $base.DeleteSubKeyTree($sub_key, $false)
            return $true
        }
        catch
        {
            return $false
        }
    }
    finally
    {
        if ($base -ne $null)
        {
            $base.Close()
        }
    }
}

function remove_per_user_com_registration([string]$clsid, [string]$progid)
{
    $removed_any = $false
    $views = @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)
    foreach ($view in $views)
    {
        if (remove_registry_subtree ([Microsoft.Win32.RegistryHive]::CurrentUser) $view ("Software\\Classes\\CLSID\\$clsid"))
        {
            $removed_any = $true
        }
        if ($progid -and (remove_registry_subtree ([Microsoft.Win32.RegistryHive]::CurrentUser) $view ("Software\\Classes\\$progid")))
        {
            $removed_any = $true
        }
    }
    return $removed_any
}

function resolve_target_paths([string]$input_path, [bool]$register_single)
{
    $resolved = (Get-Item -LiteralPath $input_path).FullName
    $targets = @($resolved)
    if ($register_single)
    {
        return $targets
    }

    $dir = Split-Path -Parent $resolved
    $name = [System.IO.Path]::GetFileName($resolved).ToLowerInvariant()
    if ($name -eq 'cassotis_ime_svr.dll')
    {
        $other = Join-Path $dir 'cassotis_ime_svr32.dll'
        if (Test-Path -LiteralPath $other)
        {
            $targets += (Get-Item -LiteralPath $other).FullName
        }
    }
    elseif ($name -eq 'cassotis_ime_svr32.dll')
    {
        $other = Join-Path $dir 'cassotis_ime_svr.dll'
        if (Test-Path -LiteralPath $other)
        {
            $targets += (Get-Item -LiteralPath $other).FullName
        }
    }

    return ($targets | Select-Object -Unique)
}

function register_one_dll([string]$target_path, [string]$clsid_text_service)
{
    $regsvr32_info = get_regsvr32_path $target_path
    $regsvr32_path = $regsvr32_info[0]
    $machine = $regsvr32_info[1]
    if ($null -eq $machine)
    {
        Write-Error ("Invalid PE file: {0}" -f $target_path)
        return $false
    }
    if (-not (test_expected_machine $target_path $machine))
    {
        Write-Error ("Architecture mismatch for file name: {0} (machine=0x{1:X4})" -f $target_path, $machine)
        return $false
    }
    $registry_view = [Microsoft.Win32.RegistryView]::Registry64
    if ($machine -eq 0x014c)
    {
        $registry_view = [Microsoft.Win32.RegistryView]::Registry32
    }

    if ($null -ne $machine)
    {
        Write-Host ("regsvr32: {0} (machine=0x{1:X4})" -f $regsvr32_path, $machine)
    }
    else
    {
        Write-Host "regsvr32: $regsvr32_path"
    }

    $reg_exit = invoke_regsvr32 $regsvr32_path @('/s', $target_path)
    if ($reg_exit -ne 0)
    {
        Write-Host "regsvr32 /s failed with exit code $reg_exit"
        Write-Host "Retrying regsvr32 without /s to show error dialog..."
        $reg_exit2 = invoke_regsvr32 $regsvr32_path @($target_path)
        if ($reg_exit2 -ne 0)
        {
            Write-Host "regsvr32 failed with exit code $reg_exit2"
        }
    }

    $entries = $null
    $registered = is_com_registered $clsid_text_service $target_path $registry_view ([ref]$entries)
    if (-not $registered)
    {
        if ($entries -ne $null -and $entries.Count -gt 0)
        {
            Write-Host "COM registry entries found but path mismatch:"
            $entries | ForEach-Object { Write-Host ("  {0} {1}: {2}" -f $_.hive, $_.view, $_.path) }
        }
        else
        {
            Write-Host "No COM registry entries found for CLSID."
        }
        Write-Error ("COM registration not found in registry after regsvr32: {0}" -f $target_path)
        return $false
    }

    Write-Host ("COM registered: {0}" -f $target_path)
    return $true
}

if (-not (Test-Path -LiteralPath $dll_path))
{
    Write-Error "DLL not found: $dll_path"
    exit 1
}

$is_admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $is_admin)
{
    Write-Host "Warning: not running as Administrator. Registration may fail with access denied."
    Write-Host "Note: admin/elevated apps may not use Cassotis IME until you run this script as Administrator."
}

$clsid_text_service = '{38D40A05-DCDB-49FB-81A4-C8745882DC21}'
$target_paths = resolve_target_paths $dll_path ([bool]$single)
Write-Host ("Register targets ({0}):" -f $target_paths.Count)
$target_paths | ForEach-Object { Write-Host ("  " + $_) }

$has_error = $false
foreach ($target_path in $target_paths)
{
    if (-not (register_one_dll $target_path $clsid_text_service))
    {
        $has_error = $true
    }
}

# Print final registry mapping in both views for quick diagnosis.
Write-Host "Final COM mapping (Registry64):"
$entries64 = get_com_registration_entries $clsid_text_service ([Microsoft.Win32.RegistryView]::Registry64)
if ($entries64.Count -gt 0)
{
    $entries64 | ForEach-Object { Write-Host ("  {0} {1}: {2}" -f $_.hive, $_.view, $_.path) }
}
else
{
    Write-Host "  missing"
}

Write-Host "Final COM mapping (Registry32):"
$entries32 = get_com_registration_entries $clsid_text_service ([Microsoft.Win32.RegistryView]::Registry32)
if ($entries32.Count -gt 0)
{
    $entries32 | ForEach-Object { Write-Host ("  {0} {1}: {2}" -f $_.hive, $_.view, $_.path) }
}
else
{
    Write-Host "  missing"
}

# Reconcile transient errors: if final mapping is correct, treat as success.
$final_ok = $true
foreach ($target_path in $target_paths)
{
    $machine = get_pe_machine $target_path
    if ($null -eq $machine)
    {
        $final_ok = $false
        continue
    }

    $registry_view = [Microsoft.Win32.RegistryView]::Registry64
    if ($machine -eq 0x014c)
    {
        $registry_view = [Microsoft.Win32.RegistryView]::Registry32
    }

    $entries_tmp = $null
    if (-not (is_com_registered $clsid_text_service $target_path $registry_view ([ref]$entries_tmp)))
    {
        $final_ok = $false
    }
}

if ($has_error -and $final_ok)
{
    Write-Host "Warning: regsvr32 reported errors, but final COM mapping is valid. Continue."
    $has_error = $false
}

if ($has_error)
{
    exit 1
}

# Elevated apps (administrator Terminal/PowerShell) require machine-wide COM registration.
$machine_ok = $true
foreach ($target_path in $target_paths)
{
    $machine = get_pe_machine $target_path
    if ($null -eq $machine)
    {
        $machine_ok = $false
        continue
    }

    $registry_view = [Microsoft.Win32.RegistryView]::Registry64
    if ($machine -eq 0x014c)
    {
        $registry_view = [Microsoft.Win32.RegistryView]::Registry32
    }

    if (-not (is_com_registered_in_hive $clsid_text_service $target_path $registry_view ([Microsoft.Win32.RegistryHive]::LocalMachine)))
    {
        $machine_ok = $false
    }
}

if (-not $machine_ok)
{
    if ($is_admin)
    {
        Write-Host "Machine-wide COM registration missing; trying to migrate from per-user registration..."
        $removed = remove_per_user_com_registration $clsid_text_service 'CassotisImeTextService'
        if ($removed)
        {
            Write-Host "Removed per-user COM registration keys under HKCU."
        }
        else
        {
            Write-Host "No removable per-user COM keys found under HKCU."
        }

        $retry_error = $false
        foreach ($target_path in $target_paths)
        {
            if (-not (register_one_dll $target_path $clsid_text_service))
            {
                $retry_error = $true
            }
        }
        if ($retry_error)
        {
            exit 1
        }

        $machine_ok = $true
        foreach ($target_path in $target_paths)
        {
            $machine = get_pe_machine $target_path
            if ($null -eq $machine)
            {
                $machine_ok = $false
                continue
            }

            $registry_view = [Microsoft.Win32.RegistryView]::Registry64
            if ($machine -eq 0x014c)
            {
                $registry_view = [Microsoft.Win32.RegistryView]::Registry32
            }

            if (-not (is_com_registered_in_hive $clsid_text_service $target_path $registry_view ([Microsoft.Win32.RegistryHive]::LocalMachine)))
            {
                $machine_ok = $false
            }
        }

        if (-not $machine_ok)
        {
            Write-Error "Machine-wide COM registration is still missing. Elevated apps may not load Cassotis IME."
            exit 1
        }
        else
        {
            Write-Host "Machine-wide COM registration is now valid."
        }
    }
    else
    {
        Write-Host "Warning: machine-wide COM registration missing. Elevated Terminal/PowerShell cannot use Cassotis IME."
        Write-Host "Please run this script once in an Administrator PowerShell."
    }
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root_dir = (Get-Item (Join-Path $script_dir "..")).FullName
$profile_tool_candidates = @(
    (Join-Path $script_dir "cassotis_ime_profile_reg.exe"),
    (Join-Path $script_dir "cassotis_ime_profile_reg32.exe"),
    (Join-Path $root_dir "out\\cassotis_ime_profile_reg.exe"),
    (Join-Path $root_dir "out\\cassotis_ime_profile_reg32.exe")
)
$profile_tools = $profile_tool_candidates |
    Where-Object { Test-Path $_ } |
    ForEach-Object { (Get-Item -LiteralPath $_).FullName } |
    Select-Object -Unique
if ($profile_tools -and $profile_tools.Count -gt 0)
{
    $profile_ok = $false
    foreach ($profile_tool in $profile_tools)
    {
        Write-Host ("Run profile tool: {0} register" -f $profile_tool)
        $profile_output = & $profile_tool register 2>&1
        if ($profile_output)
        {
            $profile_output | ForEach-Object { Write-Host $_ }
        }
        $profile_exit = $LASTEXITCODE
        if ($profile_exit -eq 0)
        {
            $profile_ok = $true
            break
        }
        else
        {
            Write-Host ("Profile tool failed: {0} (exit {1})" -f $profile_tool, $profile_exit)
        }
    }

    if (-not $profile_ok)
    {
        if (-not $is_admin)
        {
            Write-Host "Warning: all TIP profile register tools failed in non-admin mode."
        }
        else
        {
            Write-Error "TIP profile register failed in all tools."
            exit 1
        }
    }
}
else
{
    Write-Host "TIP profile tool not found. Tried: $($profile_tool_candidates -join '; ')"
}
