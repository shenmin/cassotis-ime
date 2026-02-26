[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rebuild_all = Join-Path $script_dir 'rebuild_all.ps1'

if (-not (Test-Path -LiteralPath $rebuild_all))
{
    throw "Cannot find rebuild_all.ps1 at: $rebuild_all"
}

if ($null -eq $ExtraArgs)
{
    $ExtraArgs = @()
}

& $rebuild_all -SkipTsf @ExtraArgs
exit $LASTEXITCODE
