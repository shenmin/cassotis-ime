param(
    [switch]$NoRestartHost,
    [switch]$NoAutoDownloadUnihan,
    [switch]$NoExternalLexicon
)

$ErrorActionPreference = 'Stop'
$unihan_zip_url = 'https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip'

function require_path {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path,
        [string]$label = ''
    )

    if (-not (Test-Path -Path $path)) {
        if ($label -ne '') {
            throw "Missing ${label}: $path"
        }
        else {
            throw "Missing path: $path"
        }
    }
}

function invoke_tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$label,
        [Parameter(Mandatory = $true)]
        [string]$exe,
        [Parameter(Mandatory = $true)]
        [string[]]$args
    )

    & $exe @args
    if ($LASTEXITCODE -ne 0) {
        throw "$label failed with exit code $LASTEXITCODE"
    }
}

function get_running_ime_processes {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$process_names
    )

    $running = @()
    foreach ($name in $process_names) {
        $items = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($items) {
            $running += $items
        }
    }

    return $running
}

function wait_for_processes_to_exit {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$process_names,
        [int]$poll_ms = 500
    )

    $last_print = Get-Date
    while ($true) {
        $alive = get_running_ime_processes $process_names
        if ($alive.Count -eq 0) {
            return
        }

        if (((Get-Date) - $last_print).TotalSeconds -ge 2) {
            $alive_desc = ($alive |
                Sort-Object ProcessName, Id |
                ForEach-Object { "{0}(PID={1})" -f $_.ProcessName, $_.Id }) -join ', '
            Write-Host ("Waiting for process exit: " + $alive_desc)
            $last_print = Get-Date
        }

        Start-Sleep -Milliseconds $poll_ms
    }
}

function stop_ime_processes {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$process_names
    )

    $running = get_running_ime_processes $process_names

    if ($running.Count -eq 0) {
        return @()
    }

    $unique_names = $running | Select-Object -ExpandProperty ProcessName -Unique
    Write-Host ("Stopping processes: " + ($unique_names -join ', '))
    $stop_failures = @()
    foreach ($proc in $running) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        }
        catch {
            $stop_failures += ("{0}(PID={1})" -f $proc.ProcessName, $proc.Id)
        }
    }

    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        $alive = get_running_ime_processes $unique_names

        if ($alive.Count -eq 0) {
            return $unique_names
        }

        Start-Sleep -Milliseconds 150
    }

    if ($stop_failures.Count -gt 0) {
        Write-Warning ("Some process(es) could not be stopped automatically: {0}" -f ($stop_failures -join ', '))
        Write-Host "Please close the process(es) manually, then press Enter to continue."
        [void](Read-Host)
    }

    wait_for_processes_to_exit $unique_names
    return $unique_names
}

function restart_ime_processes {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$process_names,
        [Parameter(Mandatory = $true)]
        [string]$base_dir
    )

    foreach ($name in $process_names) {
        $exe_path = Join-Path $base_dir ($name + '.exe')
        if (Test-Path -Path $exe_path) {
            Write-Host ("Restarting " + $name + "...")
            Start-Process -FilePath $exe_path -WorkingDirectory $base_dir | Out-Null
        }
        else {
            Write-Warning ("Skip restart, executable not found: " + $exe_path)
        }
    }
}

function remove_file_with_retry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path,
        [int]$max_retry = 12,
        [int]$sleep_ms = 200
    )

    for ($i = 0; $i -lt $max_retry; $i++) {
        try {
            Remove-Item -Force $path
            return
        }
        catch {
            if ($i -ge ($max_retry - 1)) {
                throw
            }
            Start-Sleep -Milliseconds $sleep_ms
        }
    }
}

function ensure_directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function download_file {
    param(
        [Parameter(Mandatory = $true)]
        [string]$url,
        [Parameter(Mandatory = $true)]
        [string]$output_path
    )

    try {
        $tls12 = [System.Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor $tls12
    }
    catch {
    }

    try {
        Invoke-WebRequest -Uri $url -OutFile $output_path -MaximumRedirection 5 -TimeoutSec 180
        return
    }
    catch {
        $curl = Get-Command -Name 'curl.exe' -ErrorAction SilentlyContinue
        if ($null -eq $curl) {
            throw
        }

        & $curl.Source '-L' '--fail' '--silent' '--show-error' $url '-o' $output_path
        if ($LASTEXITCODE -ne 0) {
            throw "curl download failed with exit code $LASTEXITCODE"
        }
    }
}

function resolve_unihan_entry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$extract_dir,
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    $item = Get-ChildItem -LiteralPath $extract_dir -Recurse -File -Filter $name | Select-Object -First 1
    if ($null -eq $item) {
        return $null
    }

    return $item.FullName
}

function ensure_unihan_sources {
    param(
        [Parameter(Mandatory = $true)]
        [string]$unihan_dir,
        [Parameter(Mandatory = $true)]
        [string]$unihan_readings,
        [Parameter(Mandatory = $true)]
        [string]$unihan_variants,
        [Parameter(Mandatory = $true)]
        [string]$unihan_dictlike,
        [Parameter(Mandatory = $true)]
        [string]$tmp_root,
        [switch]$no_auto_download
    )

    $missing_required = @()
    if (-not (Test-Path -LiteralPath $unihan_readings)) {
        $missing_required += 'Unihan_Readings.txt'
    }
    if (-not (Test-Path -LiteralPath $unihan_variants)) {
        $missing_required += 'Unihan_Variants.txt'
    }

    if ($missing_required.Count -eq 0) {
        return
    }

    if ($no_auto_download) {
        throw ("Missing Unihan source file(s): {0}`nExpected under: {1}`nAuto download is disabled by -NoAutoDownloadUnihan." -f
            ($missing_required -join ', '), $unihan_dir)
    }

    ensure_directory $unihan_dir
    ensure_directory $tmp_root
    $download_dir = Join-Path $tmp_root 'unihan_download'
    $extract_dir = Join-Path $tmp_root 'unihan_extract'
    ensure_directory $download_dir
    if (Test-Path -LiteralPath $extract_dir) {
        Remove-Item -LiteralPath $extract_dir -Recurse -Force
    }
    ensure_directory $extract_dir

    $zip_path = Join-Path $download_dir 'Unihan.zip'
    Write-Host ("Unihan source files missing, downloading from {0}" -f $unihan_zip_url)
    download_file -url $unihan_zip_url -output_path $zip_path

    Write-Host ("Extracting Unihan package: {0}" -f $zip_path)
    Expand-Archive -LiteralPath $zip_path -DestinationPath $extract_dir -Force

    $required_names = @('Unihan_Readings.txt', 'Unihan_Variants.txt')
    $optional_names = @('Unihan_DictionaryLikeData.txt')
    foreach ($name in $required_names + $optional_names) {
        $src = resolve_unihan_entry -extract_dir $extract_dir -name $name
        if ($null -eq $src) {
            if ($required_names -contains $name) {
                throw "Downloaded Unihan package does not contain required file: $name"
            }
            continue
        }

        $dest = Join-Path $unihan_dir $name
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }

    Write-Host ("Unihan sources prepared under: {0}" -f $unihan_dir)
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir
$repo_root = Split-Path -Parent $script_dir

$dict_init = Join-Path $script_dir 'cassotis_ime_dict_init.exe'
$unihan_import = Join-Path $script_dir 'cassotis_ime_unihan_import.exe'
$variant_convert = Join-Path $script_dir 'cassotis_ime_variant_convert.exe'
$check_unihan_readings = Join-Path $script_dir 'check_unihan_readings.ps1'

$schema_path = Join-Path $repo_root 'data\schema.sql'
$base_db_sc_path = Join-Path $script_dir 'data\dict_sc.db'
$base_db_tc_path = Join-Path $script_dir 'data\dict_tc.db'

$unihan_readings = Join-Path $repo_root 'data\lexicon\unihan\Unihan_Readings.txt'
$unihan_variants = Join-Path $repo_root 'data\lexicon\unihan\Unihan_Variants.txt'
$unihan_dictlike = Join-Path $repo_root 'data\lexicon\unihan\Unihan_DictionaryLikeData.txt'
$unihan_output_all = Join-Path $repo_root 'data\lexicon\unihan\dict_unihan_all.txt'
$unihan_output_sc = Join-Path $repo_root 'data\lexicon\unihan\dict_unihan.txt'
$unihan_output_tc = Join-Path $repo_root 'data\lexicon\unihan\dict_unihan_tc.txt'
$tmp_build_root = Join-Path $script_dir '_tmp_build'

$external_lexicon_root = Join-Path $repo_root '..\cassotis_lexicon'
$external_dict_sc = Join-Path $external_lexicon_root 'data\generated\dict_clean_sc.txt'
$external_dict_tc = Join-Path $external_lexicon_root 'data\generated\dict_clean_tc.txt'

require_path $dict_init 'cassotis_ime_dict_init.exe'
require_path $unihan_import 'cassotis_ime_unihan_import.exe'
require_path $variant_convert 'cassotis_ime_variant_convert.exe'
require_path $check_unihan_readings 'check_unihan_readings.ps1'
require_path $schema_path 'schema.sql'

ensure_directory $tmp_build_root
ensure_directory (Split-Path -Parent $base_db_sc_path)
ensure_directory (Split-Path -Parent $base_db_tc_path)
ensure_directory (Split-Path -Parent $unihan_output_all)
ensure_unihan_sources `
    -unihan_dir (Split-Path -Parent $unihan_readings) `
    -unihan_readings $unihan_readings `
    -unihan_variants $unihan_variants `
    -unihan_dictlike $unihan_dictlike `
    -tmp_root $tmp_build_root `
    -no_auto_download:$NoAutoDownloadUnihan

require_path $unihan_readings 'Unihan_Readings.txt'
require_path $unihan_variants 'Unihan_Variants.txt'

$ime_process_names = @('cassotis_ime_host', 'cassotis_ime_host32')
$stopped_processes = @()

try {
    $stopped_processes = stop_ime_processes $ime_process_names

    if (Test-Path -Path $base_db_sc_path) {
        Write-Host "Removing old db: $base_db_sc_path"
        remove_file_with_retry $base_db_sc_path
    }

    if (Test-Path -Path $base_db_tc_path) {
        Write-Host "Removing old db: $base_db_tc_path"
        remove_file_with_retry $base_db_tc_path
    }

    Write-Host 'Building Unihan base dict (raw)...'
    if (Test-Path -Path $unihan_dictlike) {
        invoke_tool 'cassotis_ime_unihan_import' $unihan_import @($unihan_readings, $unihan_output_all, $unihan_dictlike)
    }
    else {
        invoke_tool 'cassotis_ime_unihan_import' $unihan_import @($unihan_readings, $unihan_output_all)
    }

    Write-Host 'Validating Unihan reading coverage...'
    & $check_unihan_readings -readings_path $unihan_readings -output_path $unihan_output_all
    if ($LASTEXITCODE -ne 0) {
        throw "check_unihan_readings failed with exit code $LASTEXITCODE"
    }

    Write-Host 'Filtering Unihan dict (simplified only)...'
    invoke_tool 'cassotis_ime_variant_convert (unihan filter sc)' $variant_convert @($unihan_variants, $unihan_output_all, $unihan_output_sc, 'filter_sc')

    Write-Host 'Converting Unihan dict to traditional...'
    invoke_tool 'cassotis_ime_variant_convert (unihan s2t)' $variant_convert @($unihan_variants, $unihan_output_sc, $unihan_output_tc, 's2t')

    Write-Host 'Importing simplified dict...'
    invoke_tool 'cassotis_ime_dict_init (unihan sc)' $dict_init @($base_db_sc_path, $schema_path, $unihan_output_sc)

    Write-Host 'Importing traditional dict...'
    invoke_tool 'cassotis_ime_dict_init (unihan tc)' $dict_init @($base_db_tc_path, $schema_path, $unihan_output_tc)

    if (-not $NoExternalLexicon) {
        if (Test-Path -LiteralPath $external_lexicon_root) {
            require_path $external_dict_sc 'external dict_clean_sc.txt'
            require_path $external_dict_tc 'external dict_clean_tc.txt'

            Write-Host ("Importing external simplified dict from: " + $external_dict_sc)
            invoke_tool 'cassotis_ime_dict_init (external sc)' $dict_init @($base_db_sc_path, $schema_path, $external_dict_sc)

            Write-Host ("Importing external traditional dict from: " + $external_dict_tc)
            invoke_tool 'cassotis_ime_dict_init (external tc)' $dict_init @($base_db_tc_path, $schema_path, $external_dict_tc)
        }
        else {
            Write-Host ("External lexicon directory not found, skipping: " + $external_lexicon_root)
        }
    }
    else {
        Write-Host 'Skipping external lexicon import (-NoExternalLexicon).'
    }

    Write-Host 'Rebuild completed.'
}
finally {
    if ((-not $NoRestartHost) -and ($stopped_processes.Count -gt 0)) {
        $restart_targets = $stopped_processes | Where-Object { $_ -ieq 'cassotis_ime_host' }
        if ($restart_targets.Count -gt 0) {
            restart_ime_processes $restart_targets $script_dir
        }
    }
}
