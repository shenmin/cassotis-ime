param(
    [string]$new_path = '.\cassotis_ime_svr32.new.dll',
    [string]$target_path = '.\cassotis_ime_svr32.dll'
)

$ErrorActionPreference = 'Stop'

function resolve_full_path([string]$path)
{
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
}

function set_normal_attr([string]$path)
{
    if (-not (Test-Path -LiteralPath $path))
    {
        return
    }

    try
    {
        [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
    }
    catch
    {
    }
}

function ensure_take_ownership([string]$path)
{
    if (-not (Test-Path -LiteralPath $path))
    {
        return
    }

    try
    {
        & takeown /f $path | Out-Null
    }
    catch
    {
    }

    try
    {
        & icacls $path /grant "$env:USERNAME`:(F)" /inheritance:e | Out-Null
    }
    catch
    {
    }
}

function try_rename_old([string]$path)
{
    if (-not (Test-Path -LiteralPath $path))
    {
        return $null
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Split-Path -Parent $path
    $name = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $ext = [System.IO.Path]::GetExtension($path)
    $backup = Join-Path $dir ("{0}.old.{1}{2}" -f $name, $stamp, $ext)

    set_normal_attr $path
    try
    {
        Move-Item -Force -LiteralPath $path -Destination $backup
        return $backup
    }
    catch
    {
    }

    ensure_take_ownership $path
    set_normal_attr $path
    Move-Item -Force -LiteralPath $path -Destination $backup
    return $backup
}

$new_full = resolve_full_path $new_path
$target_full = resolve_full_path $target_path

if (-not (Test-Path -LiteralPath $new_full))
{
    throw "New file not found: $new_full"
}

$backup_path = try_rename_old $target_full

set_normal_attr $new_full
Move-Item -Force -LiteralPath $new_full -Destination $target_full

Write-Host "Replaced: $target_full"
if ($backup_path -ne $null)
{
    Write-Host "Backup:   $backup_path"
}
