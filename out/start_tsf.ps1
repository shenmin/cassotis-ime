param(
    [switch]$restart
)

$ErrorActionPreference = 'Stop'

$profile_reg = Join-Path $PSScriptRoot 'cassotis_ime_profile_reg.exe'
if (-not (Test-Path -LiteralPath $profile_reg)) {
    throw "Missing required file: $profile_reg"
}

$args = @('start')
if ($restart) {
    $args += '-restart'
}

& $profile_reg @args
exit $LASTEXITCODE
