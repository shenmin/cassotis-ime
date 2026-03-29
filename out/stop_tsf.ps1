param(
    [string]$dll_path = (Join-Path $PSScriptRoot "cassotis_ime_svr.dll"),
    [switch]$force_kill
)

$ErrorActionPreference = 'Stop'

$profile_reg = Join-Path $PSScriptRoot 'cassotis_ime_profile_reg.exe'
if (-not (Test-Path -LiteralPath $profile_reg)) {
    throw "Missing required file: $profile_reg"
}

$args = @('stop', '-dll_path', $dll_path)
if ($force_kill) {
    $args += '-force_kill'
}

& $profile_reg @args
exit $LASTEXITCODE
