param(
    [string]$dll_path = (Join-Path $PSScriptRoot "cassotis_ime_svr.dll"),
    [switch]$force_kill
)

function get_processes_using_dll([string]$dll_name)
{
    $lines = & tasklist /m $dll_name /fo csv /nh 2>$null
    if ($lines -eq $null)
    {
        return @()
    }

    $csv_lines = @()
    foreach ($line in $lines)
    {
        if ($line -match '"')
        {
            $csv_lines += $line
        }
    }

    if ($csv_lines.Count -eq 0)
    {
        return @()
    }

    $rows = $csv_lines | ConvertFrom-Csv
    $result = @()
    foreach ($row in $rows)
    {
        $props = $row.PSObject.Properties
        if ($props.Count -lt 2)
        {
            continue
        }

        $name_value = $props[0].Value
        $pid_value = $null
        foreach ($prop in $props)
        {
            if ($prop.Name -match 'PID')
            {
                $pid_value = $prop.Value
                break
            }
        }

        if ($pid_value -eq $null -or $pid_value -eq '')
        {
            $pid_value = $props[1].Value
        }

        if ($pid_value -ne $null -and $pid_value -ne '' -and $pid_value -match '^\d+$')
        {
            $result += [PSCustomObject]@{
                name = $name_value
                pid = [int]$pid_value
            }
        }
    }

    return $result
}

Write-Host "Stopping ctfmon..."
Stop-Process -Name ctfmon -Force -ErrorAction SilentlyContinue

$dll_names = @()
$dll_name = [System.IO.Path]::GetFileName($dll_path)
if ($dll_name -ne $null -and $dll_name -ne '')
{
    $dll_names += $dll_name
}

$dll_dir = Split-Path -Parent $dll_path
if ($dll_dir -eq $null -or $dll_dir -eq '')
{
    $dll_dir = $PSScriptRoot
}

$peer_name = ''
if ($dll_name -ieq 'cassotis_ime_svr.dll')
{
    $peer_name = 'cassotis_ime_svr32.dll'
}
elseif ($dll_name -ieq 'cassotis_ime_svr32.dll')
{
    $peer_name = 'cassotis_ime_svr.dll'
}

if ($peer_name -ne '')
{
    $peer_path = Join-Path $dll_dir $peer_name
    if (Test-Path -LiteralPath $peer_path)
    {
        $dll_names += $peer_name
    }
}

$dll_names = $dll_names | Select-Object -Unique
if ($dll_names.Count -eq 0)
{
    Write-Host "DLL name not provided. Skip module scan."
    exit 0
}

$processes = @()
foreach ($name in $dll_names)
{
    $processes += get_processes_using_dll $name
}
$processes = $processes | Sort-Object pid -Unique
if ($processes.Count -eq 0)
{
    Write-Host ("No processes using {0}." -f ($dll_names -join ', '))
    exit 0
}

Write-Host ("Processes using {0}:" -f ($dll_names -join ', '))
$processes | Format-Table -AutoSize

if (-not $force_kill)
{
    $answer = Read-Host "Terminate these processes? (y/N)"
    if ($answer -notin @('y', 'Y', 'yes', 'YES'))
    {
        Write-Host "Skip terminating processes."
        exit 1
    }
}

foreach ($process in $processes)
{
    try
    {
        Stop-Process -Id $process.pid -Force -ErrorAction Stop
        Write-Host ("Stopped {0} (PID {1})" -f $process.name, $process.pid)
    }
    catch
    {
        Write-Host ("Failed to stop {0} (PID {1})" -f $process.name, $process.pid)
    }
}

Start-Sleep -Milliseconds 500
$remaining = @()
foreach ($name in $dll_names)
{
    $remaining += get_processes_using_dll $name
}
$remaining = $remaining | Sort-Object pid -Unique
if ($remaining.Count -eq 0)
{
    Write-Host "DLL unlocked."
    exit 0
}

Write-Host ("Still using {0}:" -f ($dll_names -join ', '))
$remaining | Format-Table -AutoSize
exit 1
