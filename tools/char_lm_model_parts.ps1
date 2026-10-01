# The shared character LM (data\models\char_lm\char_lm.onnx) is larger than
# GitHub's 100 MiB file limit, so the repository stores it as numbered parts
# (char_lm.onnx.000, char_lm.onnx.001, ...) below the 50 MiB warning size.
# Build scripts join the parts back into char_lm.onnx, which is ignored by git
# and verified against runtime_manifest.json before anything is published.

$script:CharLmPartBytes = 50MB

function Split-CharLmModel {
    param([Parameter(Mandatory = $true)][string]$Directory)
    $model = Join-Path $Directory 'char_lm.onnx'
    if (-not (Test-Path -LiteralPath $model -PathType Leaf)) { throw "Missing character LM model: $model" }
    Get-ChildItem -LiteralPath $Directory -File |
        Where-Object { $_.Name -match '^char_lm\.onnx\.\d{3}$' } |
        Remove-Item -Force
    $buffer = New-Object byte[] (1MB)
    $reader = [IO.File]::OpenRead($model)
    try {
        $index = 0
        while ($reader.Position -lt $reader.Length) {
            $part = Join-Path $Directory ('char_lm.onnx.{0:D3}' -f $index)
            $writer = [IO.File]::Create($part)
            try {
                $remaining = [Math]::Min($script:CharLmPartBytes, $reader.Length - $reader.Position)
                while ($remaining -gt 0) {
                    $read = $reader.Read($buffer, 0, [int][Math]::Min($buffer.Length, $remaining))
                    if ($read -le 0) { throw "Unexpected end of $model" }
                    $writer.Write($buffer, 0, $read)
                    $remaining -= $read
                }
            }
            finally { $writer.Dispose() }
            $index++
        }
    }
    finally { $reader.Dispose() }
}

function Restore-CharLmModel {
    param([Parameter(Mandatory = $true)][string]$Directory)
    # A tree without parts (an older revision, or a test fixture) keeps its
    # model as it is; the manifest check downstream reports any mismatch.
    $parts = @(Get-ChildItem -LiteralPath $Directory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^char_lm\.onnx\.\d{3}$' } | Sort-Object Name)
    if ($parts.Count -eq 0) { return }
    $manifest = Get-Content -LiteralPath (Join-Path $Directory 'runtime_manifest.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $expected = [string]$manifest.files.'char_lm.onnx'
    if ([string]::IsNullOrWhiteSpace($expected)) { throw "The character LM manifest has no char_lm.onnx hash: $Directory" }
    for ($index = 0; $index -lt $parts.Count; $index++) {
        if ($parts[$index].Name -ne ('char_lm.onnx.{0:D3}' -f $index)) {
            throw "Character LM model parts are not contiguous: $($parts[$index].FullName)"
        }
    }
    $model = Join-Path $Directory 'char_lm.onnx'
    if ((Test-Path -LiteralPath $model -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash -ieq $expected)) {
        return
    }
    $joining = $model + '.joining'
    $writer = [IO.File]::Create($joining)
    try {
        foreach ($part in $parts) {
            $reader = [IO.File]::OpenRead($part.FullName)
            try { $reader.CopyTo($writer) }
            finally { $reader.Dispose() }
        }
    }
    finally { $writer.Dispose() }
    if ((Get-FileHash -LiteralPath $joining -Algorithm SHA256).Hash -ine $expected) {
        Remove-Item -LiteralPath $joining -Force
        throw "Joined character LM model does not match runtime_manifest.json: $Directory"
    }
    Move-Item -LiteralPath $joining -Destination $model -Force
}
