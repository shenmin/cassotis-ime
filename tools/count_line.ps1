param(
    [string]$root = (Resolve-Path "..").Path,
    [switch]$summary_only
)

$exclude_pattern = '\\third_party\\'
$files = Get-ChildItem -Path $root -Recurse -File -Include *.pas, *.dpr |
    Where-Object { $_.FullName -notmatch $exclude_pattern }

$total = 0
foreach ($file in $files)
{
    $count = (Get-Content -Path $file.FullName -ReadCount 0).Count
    $total += $count
    if (-not $summary_only)
    {
        "{0,8}  {1}" -f $count, $file.FullName
    }
}

"TOTAL: {0} lines, {1} files" -f $total, $files.Count
