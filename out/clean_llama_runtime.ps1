param(
    [ValidateSet('all', 'win32', 'win64', 'win64-cuda')]
    [string]$target = 'all',
    [switch]$remove_build_info,
    [switch]$dry_run
)

$ErrorActionPreference = 'Stop'

function resolve_path([string]$path_value)
{
    return [System.IO.Path]::GetFullPath($path_value)
}

function remove_path([string]$path_value, [bool]$is_file)
{
    if (-not (Test-Path -LiteralPath $path_value))
    {
        return
    }

    if ($dry_run)
    {
        Write-Host "DRY-RUN remove: $path_value"
        return
    }

    if ($is_file)
    {
        Remove-Item -LiteralPath $path_value -Force
    }
    else
    {
        Remove-Item -LiteralPath $path_value -Recurse -Force
    }
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = resolve_path (Join-Path $script_dir '..')
$llama_root = Join-Path $repo_root 'out\llama'

if (-not (Test-Path -LiteralPath $llama_root))
{
    Write-Host "No llama output directory: $llama_root"
    exit 0
}

$targets = @()
if ($target -eq 'all')
{
    $targets = @('win32', 'win64', 'win64-cuda')
}
else
{
    $targets = @($target)
}

foreach ($name in $targets)
{
    $base_dir = Join-Path $llama_root $name
    if (-not (Test-Path -LiteralPath $base_dir))
    {
        Write-Host "Skip missing target: $base_dir"
        continue
    }

    remove_path (Join-Path $base_dir 'include') $false
    remove_path (Join-Path $base_dir 'lib') $false

    if ($remove_build_info)
    {
        remove_path (Join-Path $base_dir 'build_info.txt') $true
    }
}

if ($dry_run)
{
    Write-Host 'Done (dry-run).'
}
else
{
    Write-Host 'Done.'
}
