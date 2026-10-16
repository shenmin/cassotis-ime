function Get-CassotisRuntimeBuildId {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string[]]$RuntimePayloadFiles,
        [Parameter(Mandatory = $true)][string]$RuntimeDataSourceDir
    )

    $lines = @($RuntimePayloadFiles | ForEach-Object {
        $_ + ':' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot $_) -Algorithm SHA256 -ErrorAction Stop).Hash
    })
    foreach ($name in @('dict_sc.db', 'dict_tc.db')) {
        $lines += 'base_dict\' + $name + ':' + (Get-FileHash -LiteralPath (Join-Path $RuntimeDataSourceDir $name) -Algorithm SHA256 -ErrorAction Stop).Hash
    }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($lines -join "`n")
        return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').Substring(0, 12).ToLowerInvariant()
    }
    finally {
        $hasher.Dispose()
    }
}
