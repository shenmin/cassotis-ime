param(
    [ValidateSet('all', 'win32', 'win64')]
    [string]$arch = 'all',
    [ValidateSet('cpu', 'cuda')]
    [string]$backend = 'cpu',
    [ValidateSet('Release', 'Debug')]
    [string]$config = 'Release',
    [string]$tag = 'b7951',
    [string]$cuda_root = '',
    [switch]$force_clone,
    [switch]$force_reconfigure
)

$ErrorActionPreference = 'Stop'

function resolve_path([string]$path_value)
{
    return [System.IO.Path]::GetFullPath($path_value)
}

function to_cmake_path([string]$path_value)
{
    return $path_value.Replace('\', '/')
}

function ensure_directory([string]$path_value)
{
    if (-not (Test-Path -LiteralPath $path_value))
    {
        New-Item -ItemType Directory -Path $path_value | Out-Null
    }
}

function run_cmd([string]$workdir, [string]$command_line)
{
    Push-Location $workdir
    try
    {
        cmd.exe /c $command_line
        if ($LASTEXITCODE -ne 0)
        {
            throw "Command failed (exit=$LASTEXITCODE): $command_line"
        }
    }
    finally
    {
        Pop-Location
    }
}

function resolve_vs_paths
{
    $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere))
    {
        throw "vswhere.exe not found: $vswhere"
    }

    $install_path = (& $vswhere -latest -products * -property installationPath).Trim()
    if ($install_path -eq '')
    {
        throw 'Visual Studio installation not found via vswhere.'
    }

    $devcmd = Join-Path $install_path 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $devcmd))
    {
        throw "VsDevCmd.bat not found: $devcmd"
    }

    $cmake = Join-Path $install_path 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
    if (-not (Test-Path -LiteralPath $cmake))
    {
        $cmake_cmd = Get-Command cmake -ErrorAction SilentlyContinue
        if ($cmake_cmd -eq $null)
        {
            throw 'cmake.exe not found in Visual Studio or PATH.'
        }

        $cmake = $cmake_cmd.Source
    }

    return [PSCustomObject]@{
        devcmd = $devcmd
        cmake = $cmake
    }
}

function clone_or_update_llama([string]$repo_root, [string]$tag_name, [bool]$reclone)
{
    $src_dir = Join-Path $repo_root 'third_party\llama.cpp'
    if ($reclone -and (Test-Path -LiteralPath $src_dir))
    {
        Remove-Item -LiteralPath $src_dir -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $src_dir))
    {
        ensure_directory (Join-Path $repo_root 'third_party')
        run_cmd $repo_root "git clone --branch $tag_name --depth 1 https://github.com/ggml-org/llama.cpp.git `"$src_dir`""
    }

    return $src_dir
}

function resolve_cuda_root([string]$requested_cuda_root)
{
    if ($requested_cuda_root -ne '')
    {
        $resolved = resolve_path $requested_cuda_root
        if (-not (Test-Path -LiteralPath (Join-Path $resolved 'bin\nvcc.exe')))
        {
            throw "CUDA toolkit not found at: $resolved"
        }
        return $resolved
    }

    if ($env:CUDA_PATH -and (Test-Path -LiteralPath (Join-Path $env:CUDA_PATH 'bin\nvcc.exe')))
    {
        return (resolve_path $env:CUDA_PATH)
    }

    $cuda_root_base = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA'
    if (Test-Path -LiteralPath $cuda_root_base)
    {
        $candidates = Get-ChildItem -LiteralPath $cuda_root_base -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($item in $candidates)
        {
            $nvcc = Join-Path $item.FullName 'bin\nvcc.exe'
            if (Test-Path -LiteralPath $nvcc)
            {
                return $item.FullName
            }
        }
    }

    throw 'CUDA toolkit not found. Install CUDA 12.x or pass -cuda_root <path>.'
}

function write_build_info(
    [string]$src_dir,
    [string]$target_dir,
    [string]$arch_name,
    [string]$backend_name,
    [string]$cfg,
    [string]$resolved_cuda_root
)
{
    $commit = (git -C $src_dir rev-parse HEAD).Trim()
    $branch = (git -C $src_dir rev-parse --abbrev-ref HEAD).Trim()
    $now = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $lines = @(
        "source=$src_dir"
        "commit=$commit"
        "branch=$branch"
        "arch=$arch_name"
        "backend=$backend_name"
        "config=$cfg"
        "time=$now"
    )
    if ($backend_name -eq 'cuda')
    {
        $lines += "cuda_root=$resolved_cuda_root"
    }
    $text = $lines -join [Environment]::NewLine
    Set-Content -LiteralPath (Join-Path $target_dir 'build_info.txt') -Value $text -Encoding UTF8
}

function build_one_arch(
    [string]$repo_root,
    [string]$src_dir,
    [string]$cmake_path,
    [string]$devcmd_path,
    [string]$target_arch,
    [string]$backend_name,
    [string]$cfg,
    [bool]$reconfigure,
    [string]$resolved_cuda_root
)
{
    $nvcc_path = ''
    $cmake_cuda_root = ''
    if ($target_arch -eq 'win64')
    {
        $vs_arch = 'x64'
        if ($backend_name -eq 'cuda')
        {
            $build_dir_name = 'build-win64-cuda'
            $out_dir_name = 'win64-cuda'
        }
        else
        {
            $build_dir_name = 'build-win64'
            $out_dir_name = 'win64'
        }
    }
    else
    {
        if ($backend_name -eq 'cuda')
        {
            throw 'CUDA backend only supports Win64 on Windows.'
        }
        $vs_arch = 'x86'
        $build_dir_name = 'build-win32'
        $out_dir_name = 'win32'
    }

    $build_dir = Join-Path $src_dir $build_dir_name
    if ($reconfigure -and (Test-Path -LiteralPath $build_dir))
    {
        Remove-Item -LiteralPath $build_dir -Recurse -Force
    }

    $cmake_defs = @(
        "-DCMAKE_BUILD_TYPE=$cfg"
        '-DBUILD_SHARED_LIBS=ON'
        '-DLLAMA_BUILD_TESTS=OFF'
        '-DLLAMA_BUILD_TOOLS=OFF'
        '-DLLAMA_BUILD_EXAMPLES=OFF'
        '-DLLAMA_BUILD_SERVER=OFF'
    )
    if ($backend_name -eq 'cuda')
    {
        $nvcc_path = Join-Path $resolved_cuda_root 'bin\nvcc.exe'
        if (-not (Test-Path -LiteralPath $nvcc_path))
        {
            throw "nvcc not found: $nvcc_path"
        }
        $nvcc_path = to_cmake_path $nvcc_path
        $cmake_cuda_root = to_cmake_path $resolved_cuda_root
        $cmake_defs += '-DGGML_CUDA=ON'
        $cmake_defs += "-DCMAKE_CUDA_COMPILER=`"$nvcc_path`""
        $cmake_defs += "-DCUDAToolkit_ROOT=`"$cmake_cuda_root`""
    }
    else
    {
        $cmake_defs += '-DGGML_CUDA=OFF'
    }
    $cmake_def_text = $cmake_defs -join ' '

    $cfg_cmd = @(
        "`"$devcmd_path`" -arch=$vs_arch -host_arch=x64",
        "`"$cmake_path`" -S . -B $build_dir_name -G Ninja $cmake_def_text"
    ) -join ' && '
    run_cmd $src_dir $cfg_cmd

    $build_cmd = @(
        "`"$devcmd_path`" -arch=$vs_arch -host_arch=x64",
        "`"$cmake_path`" --build $build_dir_name --config $cfg -j 12"
    ) -join ' && '
    run_cmd $src_dir $build_cmd

    $out_root = Join-Path $repo_root "out\llama\$out_dir_name"
    $out_bin = Join-Path $out_root 'bin'
    $out_lib = Join-Path $out_root 'lib'
    $out_inc = Join-Path $out_root 'include'
    ensure_directory $out_bin
    ensure_directory $out_lib
    ensure_directory $out_inc

    $dll_names = @('llama.dll', 'ggml.dll', 'ggml-base.dll', 'ggml-cpu.dll', 'mtmd.dll')
    if ($backend_name -eq 'cuda')
    {
        $dll_names += 'ggml-cuda.dll'
    }
    foreach ($name in $dll_names)
    {
        $src_file = Join-Path $build_dir "bin\$name"
        if (Test-Path -LiteralPath $src_file)
        {
            Copy-Item -LiteralPath $src_file -Destination (Join-Path $out_bin $name) -Force
        }
    }

    if ($backend_name -eq 'cuda')
    {
        $cuda_bin = Join-Path $resolved_cuda_root 'bin'
        $cuda_runtime_dlls = @(
            'cudart64_12.dll',
            'cublas64_12.dll',
            'cublasLt64_12.dll'
        )
        foreach ($name in $cuda_runtime_dlls)
        {
            $src_file = Join-Path $cuda_bin $name
            if (Test-Path -LiteralPath $src_file)
            {
                Copy-Item -LiteralPath $src_file -Destination (Join-Path $out_bin $name) -Force
            }
            else
            {
                Write-Warning "CUDA runtime dll not found: $src_file"
            }
        }

        $nvrtc_file = Get-ChildItem -LiteralPath $cuda_bin -Filter 'nvrtc64_*.dll' -File -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($null -ne $nvrtc_file)
        {
            Copy-Item -LiteralPath $nvrtc_file.FullName -Destination (Join-Path $out_bin $nvrtc_file.Name) -Force
        }
    }

    $lib_paths = @(
        'src\llama.lib',
        'ggml\src\ggml.lib',
        'ggml\src\ggml-base.lib',
        'ggml\src\ggml-cpu.lib',
        'tools\mtmd\mtmd.lib'
    )
    if ($backend_name -eq 'cuda')
    {
        $lib_paths += 'ggml\src\ggml-cuda\ggml-cuda.lib'
    }
    foreach ($rel_path in $lib_paths)
    {
        $src_file = Join-Path $build_dir $rel_path
        if (Test-Path -LiteralPath $src_file)
        {
            Copy-Item -LiteralPath $src_file -Destination (Join-Path $out_lib ([System.IO.Path]::GetFileName($src_file))) -Force
        }
    }

    $header_paths = @(
        'include\llama.h',
        'ggml\include\ggml.h',
        'ggml\include\ggml-backend.h',
        'ggml\include\ggml-cpu.h'
    )
    foreach ($rel_path in $header_paths)
    {
        $src_file = Join-Path $src_dir $rel_path
        if (Test-Path -LiteralPath $src_file)
        {
            Copy-Item -LiteralPath $src_file -Destination (Join-Path $out_inc ([System.IO.Path]::GetFileName($src_file))) -Force
        }
    }

    write_build_info $src_dir $out_root $target_arch $backend_name $cfg $resolved_cuda_root
}

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = resolve_path (Join-Path $script_dir '..')
$vs_paths = resolve_vs_paths
$src = clone_or_update_llama $repo_root $tag $force_clone.IsPresent

$targets = @()
if ($arch -eq 'all')
{
    if ($backend -eq 'cuda')
    {
        $targets = @('win64')
    }
    else
    {
        $targets = @('win64', 'win32')
    }
}
else
{
    if (($backend -eq 'cuda') -and ($arch -eq 'win32'))
    {
        throw 'CUDA backend does not support Win32.'
    }
    $targets = @($arch)
}

$resolved_cuda_root = ''
if ($backend -eq 'cuda')
{
    $resolved_cuda_root = resolve_cuda_root $cuda_root
}

foreach ($target in $targets)
{
    build_one_arch $repo_root $src $vs_paths.cmake $vs_paths.devcmd $target $backend $config $force_reconfigure.IsPresent $resolved_cuda_root
}

Write-Host "llama.cpp build done."
Write-Host "Artifacts:"
foreach ($target in $targets)
{
    if ($backend -eq 'cuda')
    {
        Write-Host "  $repo_root\\out\\llama\\$target-cuda"
    }
    else
    {
        Write-Host "  $repo_root\\out\\llama\\$target"
    }
}
