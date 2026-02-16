param(
    [switch]$NoRestartHost
)

$ErrorActionPreference = 'Stop'

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

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir

$dict_init = Join-Path $script_dir 'cassotis_ime_dict_init.exe'
$unihan_import = Join-Path $script_dir 'cassotis_ime_unihan_import.exe'
$variant_convert = Join-Path $script_dir 'cassotis_ime_variant_convert.exe'
$check_unihan_readings = Join-Path $script_dir 'check_unihan_readings.ps1'

$schema_path = Join-Path $script_dir '..\data\schema.sql'
$base_db_sc_path = Join-Path $script_dir 'data\dict_sc.db'
$base_db_tc_path = Join-Path $script_dir 'data\dict_tc.db'

$unihan_readings = Join-Path $script_dir '..\data\lexicon\unihan\Unihan_Readings.txt'
$unihan_variants = Join-Path $script_dir '..\data\lexicon\unihan\Unihan_Variants.txt'
$unihan_dictlike = Join-Path $script_dir '..\data\lexicon\unihan\Unihan_DictionaryLikeData.txt'
$unihan_output_all = Join-Path $script_dir '..\data\lexicon\unihan\dict_unihan_all.txt'
$unihan_output_sc = Join-Path $script_dir '..\data\lexicon\unihan\dict_unihan.txt'
$unihan_output_tc = Join-Path $script_dir '..\data\lexicon\unihan\dict_unihan_tc.txt'

require_path $dict_init 'cassotis_ime_dict_init.exe'
require_path $unihan_import 'cassotis_ime_unihan_import.exe'
require_path $variant_convert 'cassotis_ime_variant_convert.exe'
require_path $check_unihan_readings 'check_unihan_readings.ps1'
require_path $schema_path 'schema.sql'
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

    Write-Host 'Rebuild completed.'
}
finally {
    if ((-not $NoRestartHost) -and ($stopped_processes.Count -gt 0)) {
        restart_ime_processes $stopped_processes $script_dir
    }
}
