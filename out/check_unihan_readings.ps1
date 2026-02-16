param(
    [Parameter(Mandatory = $true)]
    [string]$readings_path,
    [Parameter(Mandatory = $true)]
    [string]$output_path,
    [int]$max_report = 20
)

$ErrorActionPreference = 'Stop'

function normalize_pinyin_token {
    param(
        [string]$token
    )

    if ([string]::IsNullOrWhiteSpace($token)) {
        return ''
    }

    $value = $token.Trim().ToLowerInvariant()
    $value = $value.Replace('u:', 'v')
    $value = $value.Replace([char]0x00FC, 'v')

    $diacritic_map = @{
        ([char]0x0101) = 'a'; ([char]0x00E1) = 'a'; ([char]0x01CE) = 'a'; ([char]0x00E0) = 'a'; ([char]0x0103) = 'a'; ([char]0x00E2) = 'a'
        ([char]0x0113) = 'e'; ([char]0x00E9) = 'e'; ([char]0x011B) = 'e'; ([char]0x00E8) = 'e'; ([char]0x00EA) = 'e'
        ([char]0x012B) = 'i'; ([char]0x00ED) = 'i'; ([char]0x01D0) = 'i'; ([char]0x00EC) = 'i'; ([char]0x00EE) = 'i'
        ([char]0x014D) = 'o'; ([char]0x00F3) = 'o'; ([char]0x01D2) = 'o'; ([char]0x00F2) = 'o'; ([char]0x00F4) = 'o'
        ([char]0x016B) = 'u'; ([char]0x00FA) = 'u'; ([char]0x01D4) = 'u'; ([char]0x00F9) = 'u'; ([char]0x00FB) = 'u'
        ([char]0x01D6) = 'v'; ([char]0x01D8) = 'v'; ([char]0x01DA) = 'v'; ([char]0x01DC) = 'v'
        ([char]0x0144) = 'n'; ([char]0x0148) = 'n'; ([char]0x01F9) = 'n'; ([char]0x1E3F) = 'm'
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($ch in $value.ToCharArray()) {
        if (($ch -ge '1') -and ($ch -le '5')) {
            continue
        }

        if ((($ch -ge 'a') -and ($ch -le 'z')) -or ($ch -eq 'v')) {
            [void]$builder.Append($ch)
            continue
        }

        if ($diacritic_map.ContainsKey($ch)) {
            [void]$builder.Append($diacritic_map[$ch])
        }
    }

    return $builder.ToString()
}

function parse_codepoint {
    param(
        [string]$codepoint_text,
        [ref]$codepoint
    )

    if ($codepoint_text -notmatch '^U\+([0-9A-Fa-f]{4,6})$') {
        return $false
    }

    $codepoint.Value = [Convert]::ToInt32($Matches[1], 16)
    return $true
}

function get_set {
    param(
        [hashtable]$map,
        [string]$key
    )

    if (-not $map.ContainsKey($key)) {
        $map[$key] = New-Object 'System.Collections.Generic.HashSet[string]'
    }

    return ,$map[$key]
}

function set_to_string {
    param(
        $set_obj
    )

    if ($null -eq $set_obj) {
        return ''
    }

    $arr = @($set_obj)
    if ($arr.Count -eq 0) {
        return ''
    }

    return (($arr | Sort-Object) -join ',')
}

if (-not (Test-Path -LiteralPath $readings_path)) {
    throw "Missing readings file: $readings_path"
}

if (-not (Test-Path -LiteralPath $output_path)) {
    throw "Missing output file: $output_path"
}

$pinlu_map = @{}
$hanyu_map = @{}
$output_map = @{}

Get-Content -LiteralPath $readings_path -Encoding UTF8 | ForEach-Object {
    if ($null -eq $_) {
        return
    }

    $line = $_.Trim()
    if (($line -eq '') -or $line.StartsWith('#')) {
        return
    }

    $parts = $line.Split([char]9)
    if ($parts.Length -lt 3) {
        return
    }

    $codepoint_value = 0
    if (-not (parse_codepoint $parts[0] ([ref]$codepoint_value))) {
        return
    }

    $tag = $parts[1]
    $value = $parts[2]
    $key = $codepoint_value.ToString()

    if ($tag -eq 'kHanyuPinlu') {
        $set = get_set $pinlu_map $key
        foreach ($token in ($value -split '\s+' | Where-Object { $_ -ne '' })) {
            $base = $token -replace '\(.*\)$', ''
            $normalized = normalize_pinyin_token $base
            if ($normalized -ne '') {
                [void]$set.Add($normalized)
            }
        }
    }
    elseif ($tag -eq 'kHanyuPinyin') {
        $set = get_set $hanyu_map $key
        $normalized_value = $value.Replace(';', ' ')
        foreach ($token in ($normalized_value -split '\s+' | Where-Object { $_ -ne '' })) {
            $rest = $token
            $idx = $token.LastIndexOf(':')
            if ($idx -ge 0) {
                $rest = $token.Substring($idx + 1)
            }

            foreach ($pinyin in ($rest -split ',' | Where-Object { $_ -ne '' })) {
                $normalized = normalize_pinyin_token $pinyin
                if ($normalized -ne '') {
                    [void]$set.Add($normalized)
                }
            }
        }
    }
}

Get-Content -LiteralPath $output_path -Encoding UTF8 | ForEach-Object {
    if ($null -eq $_) {
        return
    }

    $line = $_.Trim()
    if (($line -eq '') -or $line.StartsWith('#')) {
        return
    }

    $parts = $line.Split([char]9)
    if ($parts.Length -lt 2) {
        return
    }

    $pinyin = normalize_pinyin_token $parts[0]
    $text = $parts[1]
    if (($pinyin -eq '') -or ($text -eq '')) {
        return
    }

    $set = get_set $output_map $text
    [void]$set.Add($pinyin)
}

$codepoints_with_extra = 0
$extra_pairs_total = 0
$missing_pairs = 0
$samples = New-Object System.Collections.Generic.List[string]

foreach ($key in $hanyu_map.Keys) {
    if (-not $pinlu_map.ContainsKey($key)) {
        continue
    }

    $pinlu_set = $pinlu_map[$key]
    $hanyu_set = $hanyu_map[$key]
    $extras = @($hanyu_set | Where-Object { -not $pinlu_set.Contains($_) })
    if ($extras.Count -eq 0) {
        continue
    }

    $codepoints_with_extra++
    $codepoint_value = [int]$key
    $text = [char]::ConvertFromUtf32($codepoint_value)

    $actual_set = $null
    if ($output_map.ContainsKey($text)) {
        $actual_set = $output_map[$text]
    }

    foreach ($pinyin in $extras) {
        $extra_pairs_total++
        if (($null -eq $actual_set) -or (-not $actual_set.Contains($pinyin))) {
            $missing_pairs++
            if ($samples.Count -lt $max_report) {
                $samples.Add(
                    ("U+{0:X} '{1}' missing '{2}' pinlu=[{3}] hanyu=[{4}] actual=[{5}]" -f
                        $codepoint_value,
                        $text,
                        $pinyin,
                        (set_to_string $pinlu_set),
                        (set_to_string $hanyu_set),
                        (set_to_string $actual_set))
                )
            }
        }
    }
}

Write-Host ("Validation summary: codepoints_with_hanyu_extra={0}, extra_pairs={1}, missing_pairs={2}" -f
    $codepoints_with_extra, $extra_pairs_total, $missing_pairs)

if ($missing_pairs -gt 0) {
    Write-Host 'Missing samples:'
    foreach ($line in $samples) {
        Write-Host ("  " + $line)
    }
    throw "Found missing HanyuPinyin extra readings in output."
}

Write-Host 'Validation passed: all HanyuPinyin extra readings are present.'
