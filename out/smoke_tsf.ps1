param(
    [switch]$build,
    [switch]$register,
    [switch]$skip_host_checks
)

$ErrorActionPreference = 'Stop'
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir

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
        if ($key -ne $null) { $key.Close() }
        if ($base -ne $null) { $base.Close() }
    }
}

function get_com_entries([string]$clsid, [Microsoft.Win32.RegistryView]$view)
{
    $entries = @()
    foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryHive]::ClassesRoot))
    {
        $value = get_inproc_server_path $clsid $view $hive
        if ($value -ne $null)
        {
            $entries += [PSCustomObject]@{
                hive = $hive.ToString()
                view = $view.ToString()
                path = $value
            }
        }
    }
    return $entries
}

function stop_hosts
{
    $procs = Get-Process -Name cassotis_ime_host, cassotis_ime_host32 -ErrorAction SilentlyContinue
    if ($procs)
    {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }
}

function test_pipe_ready
{
    $pipes = Get-ChildItem \\.\pipe\ -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*cassotis_ime_engine_v2*' }
    return ($pipes -and $pipes.Count -gt 0)
}

function start_and_check_host([string]$exe_name)
{
    $exe_path = Join-Path $script_dir $exe_name
    if (-not (Test-Path -LiteralPath $exe_path))
    {
        Write-Host ("Skip {0}: file not found." -f $exe_name)
        return $false
    }

    stop_hosts
    Start-Process -FilePath $exe_path -WindowStyle Hidden | Out-Null

    $proc_name = [System.IO.Path]::GetFileNameWithoutExtension($exe_name)
    $ready = $false
    for ($i = 0; $i -lt 30; $i++)
    {
        $proc = Get-Process -Name $proc_name -ErrorAction SilentlyContinue
        if ($proc -and (test_pipe_ready))
        {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 200
    }

    if ($ready)
    {
        Write-Host ("Host ready: {0}" -f $exe_name)
    }
    else
    {
        Write-Host ("Host check failed: {0}" -f $exe_name)
    }

    stop_hosts
    return $ready
}

if ($build)
{
    Write-Host "Running rebuild_all.ps1 ..."
    & (Join-Path $script_dir 'rebuild_all.ps1')
}

if ($register)
{
    Write-Host "Running register_tsf.ps1 ..."
    & (Join-Path $script_dir 'register_tsf.ps1') -dll_path (Join-Path $script_dir 'cassotis_ime_svr.dll')
}

$clsid_text_service = '{38D40A05-DCDB-49FB-81A4-C8745882DC21}'
$entries64 = get_com_entries $clsid_text_service ([Microsoft.Win32.RegistryView]::Registry64)
$entries32 = get_com_entries $clsid_text_service ([Microsoft.Win32.RegistryView]::Registry32)

Write-Host "COM mapping (Registry64):"
if ($entries64.Count -gt 0)
{
    $entries64 | ForEach-Object { Write-Host ("  {0} {1}: {2}" -f $_.hive, $_.view, $_.path) }
}
else
{
    Write-Host "  missing"
}

Write-Host "COM mapping (Registry32):"
if ($entries32.Count -gt 0)
{
    $entries32 | ForEach-Object { Write-Host ("  {0} {1}: {2}" -f $_.hive, $_.view, $_.path) }
}
else
{
    Write-Host "  missing"
}

$ok = $true
if (-not $skip_host_checks)
{
    $ok64 = start_and_check_host 'cassotis_ime_host.exe'
    $ok32 = start_and_check_host 'cassotis_ime_host32.exe'
    if (-not $ok64) { $ok = $false }
    if (-not $ok32) { $ok = $false }
}

if (-not $ok)
{
    exit 1
}
