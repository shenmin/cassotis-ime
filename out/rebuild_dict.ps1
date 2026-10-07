param(
    [switch]$NoRestartHost,
    [switch]$NoExternalLexicon,
    # The short promotion tables are rebuilt when the files a dictionary is
    # built from changed; these force that or leave the tables as they are.
    [switch]$RefreshShortPromotion,
    [switch]$SkipShortPromotionRefresh
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
$lexicon_lm_transition_sc = Join-Path $lexicon_root 'data\generated\dict_lm_transition_sc.txt'
$lexicon_lm_transition_tc = Join-Path $lexicon_root 'data\generated\dict_lm_transition_tc.txt'
$lexicon_transition_completion_sc = Join-Path $lexicon_root 'data\generated\dict_transition_completion_sc.txt'
$lexicon_transition_completion_tc = Join-Path $lexicon_root 'data\generated\dict_transition_completion_tc.txt'
$lexicon_long_completion_sc = Join-Path $lexicon_root 'data\generated\dict_long_completion_sc.txt'
$lexicon_long_completion_tc = Join-Path $lexicon_root 'data\generated\dict_long_completion_tc.txt'
$lexicon_completion_prior_sc = Join-Path $lexicon_root 'data\generated\dict_completion_prior_sc.txt'
$lexicon_completion_prior_tc = Join-Path $lexicon_root 'data\generated\dict_completion_prior_tc.txt'
$lexicon_completion_lookup_sc = Join-Path $lexicon_root 'data\generated\dict_completion_lookup_sc.txt'
$lexicon_completion_lookup_tc = Join-Path $lexicon_root 'data\generated\dict_completion_lookup_tc.txt'
$lexicon_completion_competition_sc = Join-Path $lexicon_root 'data\generated\dict_completion_competition_sc.txt'
$lexicon_completion_competition_tc = Join-Path $lexicon_root 'data\generated\dict_completion_competition_tc.txt'
$lexicon_completion_pair_audit_sc = Join-Path $lexicon_root 'data\generated\dict_completion_pair_audit_sc.txt'
$lexicon_completion_pair_audit_tc = Join-Path $lexicon_root 'data\generated\dict_completion_pair_audit_tc.txt'
$lexicon_short_promotion_sc = Join-Path $lexicon_root 'data\generated\dict_short_promotion_sc.txt'
$lexicon_short_promotion_tc = Join-Path $lexicon_root 'data\generated\dict_short_promotion_tc.txt'
$lexicon_char_lm_sc = Join-Path $lexicon_root 'data\generated\dict_char_lm_sc.txt'
$lexicon_char_lm_tc = Join-Path $lexicon_root 'data\generated\dict_char_lm_tc.txt'
$lexicon_char_reverse_lm_sc = Join-Path $lexicon_root 'data\generated\dict_char_reverse_lm_sc.txt'
$lexicon_char_reverse_lm_tc = Join-Path $lexicon_root 'data\generated\dict_char_reverse_lm_tc.txt'
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

        if ((Test-Path -LiteralPath $lexicon_lm_transition_sc) -and
            (Test-Path -LiteralPath $lexicon_lm_transition_tc)) {
            Write-Host ("Importing lexicon LM transitions from: " + $lexicon_lm_transition_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon LM transition sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_lm_transition_sc, 'lm_transition')

            Write-Host ("Importing lexicon LM transitions from: " + $lexicon_lm_transition_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon LM transition tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_lm_transition_tc, 'lm_transition')
        }
        else {
            Write-Warning "LM transition files not found under lexicon data/generated; skipping LM transition import."
        }

        if ((Test-Path -LiteralPath $lexicon_transition_completion_sc) -and
            (Test-Path -LiteralPath $lexicon_transition_completion_tc)) {
            Write-Host ("Importing lexicon transition completions from: " + $lexicon_transition_completion_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon transition completion sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_transition_completion_sc, 'transition_completion')

            Write-Host ("Importing lexicon transition completions from: " + $lexicon_transition_completion_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon transition completion tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_transition_completion_tc, 'transition_completion')
        }
        else {
            Write-Warning "Transition completion files not found under lexicon data/generated; skipping transition completion import."
        }

        if ((Test-Path -LiteralPath $lexicon_long_completion_sc) -and
            (Test-Path -LiteralPath $lexicon_long_completion_tc)) {
            Write-Host ("Importing lexicon long-sentence completions from: " + $lexicon_long_completion_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon long completion sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_long_completion_sc, 'long_completion')

            Write-Host ("Importing lexicon long-sentence completions from: " + $lexicon_long_completion_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon long completion tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_long_completion_tc, 'long_completion')
        }
        else {
            Write-Warning "Long-sentence completion files not found under lexicon data/generated; skipping import."
        }

        if ((Test-Path -LiteralPath $lexicon_completion_prior_sc) -and
            (Test-Path -LiteralPath $lexicon_completion_prior_tc)) {
            Write-Host ("Importing lexicon completion popularity priors from: " + $lexicon_completion_prior_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon completion prior sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_completion_prior_sc, 'completion_prior')

            Write-Host ("Importing lexicon completion popularity priors from: " + $lexicon_completion_prior_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon completion prior tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_completion_prior_tc, 'completion_prior')
        }
        else {
            Write-Warning "Completion popularity prior files not found under lexicon data/generated; skipping import."
        }

        if ((Test-Path -LiteralPath $lexicon_completion_lookup_sc) -and
            (Test-Path -LiteralPath $lexicon_completion_lookup_tc)) {
            Write-Host ("Importing lexicon exact completion lookup from: " + $lexicon_completion_lookup_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon completion lookup sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_completion_lookup_sc, 'completion_lookup')

            Write-Host ("Importing lexicon exact completion lookup from: " + $lexicon_completion_lookup_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon completion lookup tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_completion_lookup_tc, 'completion_lookup')
        }
        else {
            Write-Warning "Exact completion lookup files not found under lexicon data/generated; skipping import."
        }

        if ((Test-Path -LiteralPath $lexicon_completion_competition_sc) -and
            (Test-Path -LiteralPath $lexicon_completion_competition_tc)) {
            Write-Host ("Importing lexicon completion competition evidence from: " + $lexicon_completion_competition_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon completion competition sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_completion_competition_sc, 'completion_competition')

            Write-Host ("Importing lexicon completion competition evidence from: " + $lexicon_completion_competition_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon completion competition tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_completion_competition_tc, 'completion_competition')
        }
        else {
            Write-Warning "Completion competition evidence files not found under lexicon data/generated; skipping import."
        }

        if ((Test-Path -LiteralPath $lexicon_completion_pair_audit_sc) -and
            (Test-Path -LiteralPath $lexicon_completion_pair_audit_tc)) {
            Write-Host ("Importing completion pair audit evidence from: " + $lexicon_completion_pair_audit_sc)
            invoke_tool 'cassotis_ime_dict_init (completion pair audit sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_completion_pair_audit_sc, 'completion_pair_audit')

            Write-Host ("Importing completion pair audit evidence from: " + $lexicon_completion_pair_audit_tc)
            invoke_tool 'cassotis_ime_dict_init (completion pair audit tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_completion_pair_audit_tc, 'completion_pair_audit')
        }
        else {
            Write-Warning "Completion pair audit evidence files not found under lexicon data/generated; skipping import."
        }

        if (Test-Path -LiteralPath $lexicon_char_lm_sc) {
            Write-Host ("Importing lexicon character LM from: " + $lexicon_char_lm_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon character LM sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_char_lm_sc, 'char_lm')
        }
        else {
            Write-Warning "Simplified character LM file not found under lexicon data/generated; skipping import."
        }

        if (Test-Path -LiteralPath $lexicon_char_lm_tc) {
            Write-Host ("Importing lexicon character LM from: " + $lexicon_char_lm_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon character LM tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_char_lm_tc, 'char_lm')
        }
        else {
            Write-Warning "Traditional character LM file not found under lexicon data/generated; skipping import."
        }

        if (Test-Path -LiteralPath $lexicon_char_reverse_lm_sc) {
            Write-Host ("Importing lexicon reverse character LM from: " + $lexicon_char_reverse_lm_sc)
            invoke_tool 'cassotis_ime_dict_init (lexicon reverse character LM sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_char_reverse_lm_sc, 'char_reverse_lm')
        }
        else {
            Write-Warning "Simplified reverse character LM file not found under lexicon data/generated; skipping import."
        }

        if (Test-Path -LiteralPath $lexicon_char_reverse_lm_tc) {
            Write-Host ("Importing lexicon reverse character LM from: " + $lexicon_char_reverse_lm_tc)
            invoke_tool 'cassotis_ime_dict_init (lexicon reverse character LM tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_char_reverse_lm_tc, 'char_reverse_lm')
        }
        else {
            Write-Warning "Traditional reverse character LM file not found under lexicon data/generated; skipping import."
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

    invoke_tool 'cassotis_ime_dict_init (contains index sc)' $dict_init @(
        $base_db_sc_path, $schema_path, '--build-contains-index')
    invoke_tool 'cassotis_ime_dict_init (contains index tc)' $dict_init @(
        $base_db_tc_path, $schema_path, '--build-contains-index')

    # The short promotions: among a short query's exact words, the one to put
    # above the first when nothing but the dictionary decides. They are choices
    # made from the finished dictionary, so they come last. Where the builder's
    # project is at hand, the tables are rebuilt first if their inputs changed.
    if (-not $NoExternalLexicon) {
        $short_promotion_script = Join-Path $script_dir 'rebuild_short_promotion.ps1'
        $short_promotion_project = Join-Path $repo_root 'tools\cassotis_ime_short_promotion_builder.dproj'
        if ((-not $SkipShortPromotionRefresh) -and
            (Test-Path -LiteralPath $short_promotion_script) -and
            (Test-Path -LiteralPath $short_promotion_project)) {
            & $short_promotion_script -DictScPath $base_db_sc_path -DictTcPath $base_db_tc_path `
                -OutputDir (Split-Path -Parent $lexicon_short_promotion_sc) `
                -OnlyIfChanged:(-not $RefreshShortPromotion)
        }

        if ((Test-Path -LiteralPath $lexicon_short_promotion_sc) -and
            (Test-Path -LiteralPath $lexicon_short_promotion_tc)) {
            Write-Host ("Importing short promotions from: " + $lexicon_short_promotion_sc)
            invoke_tool 'cassotis_ime_dict_init (short promotion sc)' $dict_init @(
                $base_db_sc_path, $schema_path, $lexicon_short_promotion_sc, 'short_promotion')

            Write-Host ("Importing short promotions from: " + $lexicon_short_promotion_tc)
            invoke_tool 'cassotis_ime_dict_init (short promotion tc)' $dict_init @(
                $base_db_tc_path, $schema_path, $lexicon_short_promotion_tc, 'short_promotion')
        }
        else {
            Write-Warning "Short promotion files not found under lexicon data/generated; skipping import."
        }
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
