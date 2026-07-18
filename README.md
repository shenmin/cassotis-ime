# Cassotis IME

<p align="center">
  <img src="cassotis_ime_yanquan.png" alt="Cassotis IME logo" width="280">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
</p>
<p align="center">
  <img src="snapshot.png" alt="Cassotis IME snapshot" width="810">
</p>

English | [简体中文](README.CN.md)

Cassotis IME (言泉输入法) is an experimental Chinese Pinyin input method for Windows 10/11, built primarily with Delphi on top of TSF (Text Services Framework).

## Name Origin
The English name **Cassotis** comes from the sacred spring inside the Temple of Delphi. Before delivering oracles, the priestess Pythia was said to drink from this spring to enter a prophetic state. The spring was regarded as the true source of prophecy and inspiration, where oracles were born, which resonates with the path from Delphi to human language.

The Chinese name **言泉** (Yanquan, "Spring of Words") matches Cassotis as a prophetic spring, while also carrying the meaning of **言如泉涌** ("words flowing like a spring"), reflecting our expectation of a fluent and intelligent input experience.

The project focus is:
- build a stable TSF-based IME foundation,
- keep the architecture modular (TSF DLL + host process + tools),
- improve corpus-trained local language models while continuing to explore optional LLM-assisted input.

## Current Status
- TSF text service pipeline is available (registration, activation, composition lifecycle).
- TSF binaries support Win64 and Win32 (`svr.dll` / `svr32.dll`), while host process is Win64 only.
- Candidate window, paging, selection, and commit flow are implemented.
- Dictionary split is supported: simplified base DB, traditional base DB, and user DB.
- Base dictionary now includes `dict_jianpin` index entries for initial-letter abbreviations (for example `jt -> 今天`; retroflex variants like `zsjs/zhshjsh` are both generated).
- Full-path segmented phrase decoding is enabled (for example `womenjintian -> 我们今天`) while keeping prefix candidates for partial-commit fallback.
- A deployable local neural residual reranker conservatively corrects complete long-sentence rankings without affecting short exact-query mode.
- Surrounding-text/context synchronization and key state synchronization are implemented.

## Architecture
- `src/tsf`: TSF COM in-proc server (text service integration).
- `src/engine`: Pinyin parsing, candidate generation, ranking, and user learning.
- `src/host`: external host process for engine/UI orchestration.
- `src/ui`: candidate window and tray UI.
- `src/common`: config, logging, IPC, sqlite wrapper, shared utilities.
- `tools`: registration, dictionary build/import/diagnostics, helper executables.

## Repository Layout
- `src/` source code
- `tools/` utility projects and helper executables
- `data/` schema and sample dictionary import data
- `out/` scripts for build/register/rebuild/test
- `third_party/` vendored third-party binaries/sources (for example sqlite runtime package files)

## Key Binaries
- `cassotis_ime_svr.dll` (Win64 TSF in-proc COM server)
- `cassotis_ime_svr32.dll` (Win32 TSF in-proc COM server)
- `cassotis_ime_host.exe` (Win64 host process)
- `cassotis_ime_tray_host.exe` (Win64 tray/status host for tray menu, floating status window, and input-state indicator)
- `cassotis_ime_profile_reg.exe` (TSF profile/category registration utility)

Without TSF DLL + main host process, IME input will not work. Without the tray/status host, the core input path may still run, but the tray menu, floating status window, and state indicator will be unavailable.

## Build and Run (Quick Start)
Prerequisites:
- Windows 10/11
- Delphi 10.4
- SQLite runtime DLL (`sqlite3_64.dll`)

From `out/`:

```powershell
.\rebuild_all.ps1
.\cassotis_ime_profile_reg.exe register_tsf -dll_path .\cassotis_ime_svr.dll
.\rebuild_dict.ps1
```

For full build details, see `BUILD.md`.

## Dictionary Workflow
Current base dictionary pipeline imports generated lexicon artifacts from the [cassotis-lexicon](https://github.com/shenmin/cassotis-lexicon) project:
- lexicon inputs: `dict_unihan_sc.txt`, `dict_unihan_tc.txt`, `dict_clean_sc.txt`, `dict_clean_tc.txt`
- runtime DB files are rebuilt under `%LOCALAPPDATA%\CassotisIme\data\` (for example `dict_sc.db`, `dict_tc.db`)
- user dictionary defaults to `%LOCALAPPDATA%\CassotisIme\data\user_dict.db`
- `rebuild_dict.ps1` imports `pinyin<TAB>text<TAB>weight` and auto-builds `dict_jianpin` (including `z/c/s` and `zh/ch/sh` abbreviation variants)

Main rebuild entry:

```powershell
.\rebuild_dict.ps1
```

## Corpus-Trained AI Ranking for Long Sentences
Cassotis v1.1.0 introduces an offline-trained local statistical language model for long-sentence path ranking. The training pipeline learns lexicon-constrained word bigram/trigram transition priors and a smoothed character trigram model from cleaned general Chinese and fiction corpora. The Benchmark-16300 corpus is kept separate and is not used for training.

Cassotis v1.3.0 adds the project's first deployable neural residual reranker. The compact feed-forward model is trained offline on lexicon-constrained N-best candidate comparisons and conservatively promotes better complete long-sentence candidates while retaining the original engine result as a fallback.

The statistical model is quantized into the local dictionary database, while the neural reranker is exported as deterministic native Pascal parameters. When a user enters a long sentence, the engine evaluates this compact feed-forward network directly while producing that query's candidates and conservatively reranks complete candidates. This is local inference, not training: it starts no PyTorch/ONNX runtime or external model service, requires no network connection or GPU, and is bypassed by short exact-query ranking.

## Long Sentence Benchmark Results
See [BENCHMARK.md](BENCHMARK.md) for the Benchmark-16300 methodology, corpus source, and scoring rules.

Corpus: 16,300 eligible Chinese sentences from the developer's own novel [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)).

| Version | Top1 | Top2 | Mean (ms) | P50 (ms) | P95 (ms) | Max (ms) |
|---|---:|---:|---:|---:|---:|---:|
| `v1.3.0` | 7155/16300 (43.90%) | 7601/16300 (46.63%) | 64.54 | 46 | 203 | 2188 |
| `v1.2.0` | 6895/16300 (42.30%) | 7303/16300 (44.80%) | 59.89 | 32 | 188 | 2078 |
| `v1.1.0` | 6677/16300 (40.96%) | 7067/16300 (43.36%) | 73.18 | 47 | 234 | 2750 |
| `v1.0.0` | 6106/16300 (37.46%) | 6857/16300 (42.07%) | 71.49 | 47 | 219 | 5344 |
| `v0.8.5` | 6097/16300 (37.40%) | 6847/16300 (42.01%) | 520.05 | 406 | 1203 | 13297 |
| `v0.7.0` | 5368/16300 (32.93%) | 6110/16300 (37.48%) | — | — | — | — |
| `v0.6.0` | 4905/16300 (30.09%) | 5378/16300 (32.99%) | — | — | — | — |
| `v0.5.0` | 4834/16300 (29.66%) | 5243/16300 (32.17%) | — | — | — | — |
| `v0.4.0` | 4371/16300 (26.82%) | 4744/16300 (29.10%) | — | — | — | — |
| `v0.3.1` | 3845/16300 (23.59%) | 4651/16300 (28.53%) | — | — | — | — |
| `v0.2.0` | 2671/16300 (16.39%) | 2863/16300 (17.56%) | — | — | — | — |

Latency values are engine-only full-query decode times. Each complete Pinyin query is assigned at once, so these values do not represent incremental keystroke-to-display latency. `—` means that the version was not measured under this latency protocol. See [BENCHMARK.md](BENCHMARK.md) for the complete methodology.

## Configuration
Default config file:
- `%LOCALAPPDATA%\CassotisIme\cassotis_ime.ini`

Important options include:
- simplified/traditional variant switching (`variant`)
- full-width / punctuation mode
- debug logging and log path

Runtime dictionary paths are fixed under `%LOCALAPPDATA%\CassotisIme\data\` and are no longer configured through the INI file.

## Documentation
- Chinese full documentation: `README.CN.md`
- Build details: `BUILD.md`
- Third-party notices: `THIRD_PARTY.md`

## License
This project is licensed under GPL-3.0. See `LICENSE` for the full license text.

Keep third-party notices and attribution files consistent with `THIRD_PARTY.md`.

## Roadmap
- improve candidate ranking quality and practical phrase coverage
- improve user-dictionary quality control and tooling
- extend compatibility matrix across editors/browsers/IDEs
- evaluate local LLM (GGUF) assisted suggestion workflow
