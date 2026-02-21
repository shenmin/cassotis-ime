param(
    [switch]$restart
)

$ctfmon_path = Join-Path $env:WINDIR "System32\\ctfmon.exe"

if ($restart)
{
    Stop-Process -Name ctfmon -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}

Write-Host "Starting ctfmon..."
Start-Process -FilePath $ctfmon_path

$host_path = Join-Path $PSScriptRoot "cassotis_ime_host.exe"
if (Test-Path -LiteralPath $host_path)
{
    $host_proc = Get-Process -Name "cassotis_ime_host" -ErrorAction SilentlyContinue
    if ($host_proc -eq $null)
    {
        Write-Host "Starting host..."
        Start-Process -FilePath $host_path -WorkingDirectory $PSScriptRoot
    }
}

$tray_host_path = Join-Path $PSScriptRoot "cassotis_ime_tray_host.exe"
if (Test-Path -LiteralPath $tray_host_path)
{
    $tray_proc = Get-Process -Name "cassotis_ime_tray_host" -ErrorAction SilentlyContinue
    if ($tray_proc -eq $null)
    {
        Write-Host "Starting tray host..."
        Start-Process -FilePath $tray_host_path -WorkingDirectory $PSScriptRoot
    }
}
