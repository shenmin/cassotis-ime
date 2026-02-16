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
