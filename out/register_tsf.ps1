param(
    [string]$dll_path = (Join-Path $PSScriptRoot "cassotis_ime_svr.dll"),
    [switch]$single
)

$ErrorActionPreference = 'Stop'

$profile_reg = Join-Path $PSScriptRoot 'cassotis_ime_profile_reg.exe'
if (-not (Test-Path -LiteralPath $profile_reg)) {
    throw "Missing required file: $profile_reg"
}

$args = @('register_tsf', '-dll_path', $dll_path)
if ($single) {
    $args += '-single'
}

& $profile_reg @args
exit $LASTEXITCODE
