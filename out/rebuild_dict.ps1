param(
    [switch]$NoRestartHost,
    [switch]$NoExternalLexicon
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

function ensure_directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function resolve_lexicon_root {
    param(
        [Parameter(Mandatory = $true)]
        [string]$repo_root
    )

    $candidates = @(
        (Join-Path $repo_root '..\cassotis-lexicon'),
        (Join-Path $repo_root '..\cassotis_lexicon')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Lexicon repository not found. Expected one of: $($candidates -join ', ')"
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir
$repo_root = Split-Path -Parent $script_dir
$local_app_data = $env:LOCALAPPDATA
if ([string]::IsNullOrWhiteSpace($local_app_data)) {
    $local_app_data = [Environment]::GetFolderPath('LocalApplicationData')
}
$runtime_data_dir = Join-Path $local_app_data 'CassotisIme\data'

$dict_init = Join-Path $script_dir 'cassotis_ime_dict_init.exe'
$schema_path = Join-Path $repo_root 'data\schema.sql'
$base_db_sc_path = Join-Path $runtime_data_dir 'dict_sc.db'
$base_db_tc_path = Join-Path $runtime_data_dir 'dict_tc.db'

$lexicon_root = resolve_lexicon_root $repo_root
$lexicon_unihan_sc = Join-Path $lexicon_root 'data\generated\dict_unihan_sc.txt'
$lexicon_unihan_tc = Join-Path $lexicon_root 'data\generated\dict_unihan_tc.txt'
$lexicon_clean_sc = Join-Path $lexicon_root 'data\generated\dict_clean_sc.txt'
$lexicon_clean_tc = Join-Path $lexicon_root 'data\generated\dict_clean_tc.txt'
$lexicon_query_path_sc = Join-Path $lexicon_root 'data\generated\dict_query_path_prior_sc.txt'
$lexicon_query_path_tc = Join-Path $lexicon_root 'data\generated\dict_query_path_prior_tc.txt'
$custom_dict_sc = Join-Path $repo_root 'data\custom_dict_sc.txt'
$custom_dict_tc = Join-Path $repo_root 'data\custom_dict_tc.txt'

require_path $dict_init 'cassotis_ime_dict_init.exe'
require_path $schema_path 'schema.sql'
require_path $lexicon_unihan_sc 'lexicon dict_unihan_sc.txt'
require_path $lexicon_unihan_tc 'lexicon dict_unihan_tc.txt'

if (-not $NoExternalLexicon) {
    require_path $lexicon_clean_sc 'lexicon dict_clean_sc.txt'
    require_path $lexicon_clean_tc 'lexicon dict_clean_tc.txt'
}
else {
    Write-Warning "-NoExternalLexicon enabled: only lexicon Unihan dictionaries will be imported."
}

ensure_directory (Split-Path -Parent $base_db_sc_path)
ensure_directory (Split-Path -Parent $base_db_tc_path)

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

    Write-Host ("Importing lexicon Unihan simplified dict from: " + $lexicon_unihan_sc)
    invoke_tool 'cassotis_ime_dict_init (lexicon unihan sc)' $dict_init @($base_db_sc_path, $schema_path, $lexicon_unihan_sc)

    Write-Host ("Importing lexicon Unihan traditional dict from: " + $lexicon_unihan_tc)
    invoke_tool 'cassotis_ime_dict_init (lexicon unihan tc)' $dict_init @($base_db_tc_path, $schema_path, $lexicon_unihan_tc)

    if (-not $NoExternalLexicon) {
        Write-Host ("Importing lexicon broad simplified dict from: " + $lexicon_clean_sc)
        invoke_tool 'cassotis_ime_dict_init (lexicon clean sc)' $dict_init @($base_db_sc_path, $schema_path, $lexicon_clean_sc)

        Write-Host ("Importing lexicon broad traditional dict from: " + $lexicon_clean_tc)
        invoke_tool 'cassotis_ime_dict_init (lexicon clean tc)' $dict_init @($base_db_tc_path, $schema_path, $lexicon_clean_tc)

        if ((Test-Path -LiteralPath $lexicon_query_path_sc) -and (Test-Path -LiteralPath $lexicon_query_path_tc)) {
            Write-Host ("Importing lexicon query-path priors from: " + $lexicon_query_path_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon query path sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_query_path_sc, 'query_path')

            Write-Host ("Importing lexicon query-path priors from: " + $lexicon_query_path_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon query path tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_query_path_tc, 'query_path')
        }
        else {
            Write-Warning "Query-path prior files not found under lexicon data/generated; skipping base path-prior import."
        }
    }

    if (Test-Path -LiteralPath $custom_dict_sc) {
        Write-Host ("Importing simplified custom dict from: " + $custom_dict_sc)
        invoke_tool 'cassotis_ime_dict_init (custom sc)' $dict_init @($base_db_sc_path, $schema_path, $custom_dict_sc)
    }

    if (Test-Path -LiteralPath $custom_dict_tc) {
        Write-Host ("Importing traditional custom dict from: " + $custom_dict_tc)
        invoke_tool 'cassotis_ime_dict_init (custom tc)' $dict_init @($base_db_tc_path, $schema_path, $custom_dict_tc)
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
