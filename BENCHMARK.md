# Cassotis Corpus Benchmarks

Cassotis publishes four fixed corpus benchmarks: the Long Sentence Benchmark-16300, the Short-word Context Benchmark-65000, the One-key Completion Context Benchmark-12831, and the Long-sentence One-key Completion Benchmark-16300. They track decoding quality and engine performance across releases as reproducible measurements instead of relying only on hand-picked examples.

## Shared Corpus Source

All four benchmarks are derived from the developer's own novel, [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)).

Benchmark-16300 fixes 16,300 eligible sentences, while Benchmark-65000 fixes 65,000 short-word occurrences. The short-word completion benchmark derives 12,831 incremental completion opportunities from the same short-word cases. The long-sentence completion benchmark reuses the long-sentence corpus to derive 16,300 near-tail opportunities. Benchmark cases are kept separate from the corresponding model-training data.

## Shared Accuracy Equivalence Rule

The following rule applies to visible-candidate accuracy metrics in the long-sentence and short-word context suites, including `Top1`, `Top2`, other reported `TopN` values, and the short-word `Contested` metrics. Starting with `v1.30.0`, it also applies to the Long-sentence One-key Completion Benchmark-16300 hit, whole-sentence hit, and visible-prefix metrics:

- `他` and `她` are treated as equivalent only when they occur at the same character positions, because the benchmark Pinyin query cannot distinguish them.
- `它`, all other homophones, missing or additional characters, and every other textual difference remain distinct.
- The rule changes only offline pass/fail scoring. It does not rewrite candidate text or alter candidate generation, ranking, latency, or user-dictionary behavior.
- Raw-pool and Oracle recall scoring retains strict character equality so that the target label cannot influence search behavior. It is therefore not directly comparable with equivalence-aware visible `TopN` metrics.

This equivalence rule applies to benchmark results starting with `v1.11.0`. Results for `v1.10.0` and earlier releases used strict character equality and should be rescored before direct comparison with `v1.11.0` or later results.

For the Long-sentence One-key Completion Benchmark-16300, the rule starts with `v1.30.0`, recorded as completion scope `predictive_continuations_v2`. Results for `v1.29.0` and earlier used strict equality (`predictive_continuations_v1`). Scoring does not affect which completion is displayed, so saved result rows can be rescored exactly with `tools/rescore_long_completion_predictions.py`.

## Shared Model Configuration

Starting with `v1.30.0`, all four suites load the same model set that the Host deploys, so the results match the input method users actually run:

- the long-sentence Transformer reranker and its local-repair models;
- the shared character-level language model, which reranks long-sentence and short-word candidates and takes part in choosing long-sentence one-key continuations; releases after `v1.30.0` also use it to choose short-word one-key completions; in long-sentence one-key completion they use it to score candidates that complete the word cut by the end of the input, to propose next characters, and to choose the tail word of the exact-tail fallback;
- the short-word context reranker has been replaced by the shared character-level language model and is no longer shipped from `v1.30.0`.

In `v1.29.0` and earlier, the Short-word Context Benchmark loaded only the short-word context reranker, and the One-key Completion Context Benchmark loaded no neural model. Keep this change in mind when comparing across versions.

## Long Sentence Benchmark-16300

### Corpus Scale and Case Construction

Benchmark-16300 contains 16,300 eligible sentences extracted from the novel in a fixed order. Its cases are constructed as follows:

- Split the novel text by punctuation and line breaks.
- Ignore sentences containing English letters.
- Ignore sentences shorter than the configured minimum CJK length.
- Convert each complete sentence to Pinyin with the benchmark reverse-Pinyin builder.
- Feed the complete Pinyin query to the engine and dictionary version under test.

### Accuracy Scoring

- A case is a `Top1` pass when the first complete candidate matches the original sentence under the shared scoring rule above.
- A case is a `Top2` pass when either of the first two complete candidates matches the original sentence under the shared scoring rule above.

### Accuracy and Latency Modes

- Accuracy runs use deterministic-work mode: normal search paths do not stop on wall-clock time and remain bounded by fixed beam, state, edge, candidate, and work limits. Changes in machine load therefore do not change normal candidate generation.
- Latency runs use production mode: fixed work limits are the primary boundary, with wider emergency wall-clock ceilings retained to prevent unacceptable stalls on malformed long Pinyin or slower machines.
- Both modes load the same deployed long-sentence Transformer reranker as the Host. A missing or incomplete runtime is an error rather than a silent fallback; disabling it is reserved for explicitly labelled diagnostic runs.
- The two measurements are run separately. The eight-slice runner accelerates accuracy evaluation and is not used for latency measurement.

### Latency Protocol

Long-sentence latency values measure engine-only full-query decoding:

- Process the fixed 16,300 cases serially in one runner process and in corpus order.
- Use a snapshot of the simplified base dictionary selected for the tested release and disable the user dictionary by default.
- Reset the engine composition state before each case while retaining the same dictionary connection and runtime caches for the complete run.
- Assign the complete Pinyin query in one operation, then generate and read the candidate list.
- Measure from immediately before query assignment until candidate retrieval finishes.
- Exclude process startup, dictionary opening, reverse-Pinyin conversion, report writing, TSF integration, candidate-window rendering, real keystrokes, and inter-key timing.

## Short-word Context Benchmark-65000

### Corpus Scale and Case Construction

Benchmark-65000 measures word-by-word input with preceding text and uses the same novel text as the long-sentence benchmark as its source:

- Deterministically segment each sentence and normalize the result into two- to four-character units that represent ordinary short-word input habits.
- Admit only manually reviewed lexical units and exclude novel-specific proper nouns, so the benchmark measures general input behavior rather than memorization of story-specific names.
- Treat each eligible occurrence as one case and preserve the sentence prefix that a user would already have committed before typing that unit.
- Convert the target unit to Pinyin independently, with reviewed overrides for ambiguous readings.
- Keep cases in source-text order and freeze the first 65,000 eligible occurrences as Benchmark-65000.
- Evaluate with a snapshot of the selected simplified dictionary; user-dictionary ranking is disabled by default.

The frozen set contains 55,712 cases with usable left context and 9,288 sentence-initial cases without left context.

### Accuracy and Contested Scoring

- A case is a `Top1` pass when the first exact candidate matches the target unit under the shared scoring rule above.
- A case is a `Top2` pass when either of the first two exact candidates matches the target unit under the shared scoring rule above.
- `Contested` is the 11,728-case subset in which the same Pinyin query maps to at least two target words in the corpus. `Contested Top1` and `Contested Top2` isolate the cases where left context is most useful for disambiguation.
- Short-word results use the context-enabled benchmark.

### Latency Protocol

Short-word latency values measure engine-only candidate retrieval for the context-enabled track:

- Process all 65,000 cases serially in one runner process and in fixed corpus order.
- Reset the engine before each query while retaining the same dictionary connection and runtime caches.
- Install the already committed sentence prefix before timing, assign the complete target Pinyin query, and stop timing after candidate retrieval.
- Exclude corpus segmentation, Pinyin generation, process startup, dictionary opening, report writing, TSF integration, candidate-window rendering, real keystrokes, and inter-key timing.

## One-key Completion Context Benchmark-12831

### Case Construction and Scoring

The completion benchmark reuses the frozen Benchmark-65000 cases and their left context to measure one-key continuation before the target word has been fully typed:

- Evaluate only targets containing at least three complete Pinyin syllables.
- Starting after two syllables, advance one syllable at a time and stop before the complete Pinyin. Each intermediate state is one completion opportunity.
- For example, the target `往常一样` is queried at both `wangchang` and `wangchangyi`.
- The complete 65,000-source corpus deterministically produces 12,831 opportunities, hence the name One-key Completion Context Benchmark-12831.
- Use the simplified base-dictionary snapshot for the tested release, disable the user dictionary, and enable left context.
- Read only the single completion that the UI would display. It is a hit only when it strictly equals the corpus target; the `他`/`她` equivalence rule is not applied.

The benchmark records five metrics that are straightforward to interpret across releases:

- `Completion Hit`: correct completions divided by all 12,831 opportunities; this is the primary quality metric.
- `Avg Keys Saved`: average net keystrokes saved by each correct completion, after charging one keystroke for accepting it.
- `Stability`: when the previous completion remains compatible after another syllable is typed, the proportion for which the displayed completion remains unchanged.
- `Keystroke P95`: 95% of keystrokes return their completion within this many milliseconds; this is what typing waits for.
- `Final P95`: 95% of opportunities show their final completion within this many milliseconds, including an asynchronous language-model rerank that changes the displayed completion.

Because each corpus position has only one reference target, a different but linguistically valid completion is still scored as a miss.

### Latency Protocol

Latency covers dictionary lookup, context/language-model scoring, completion selection, and hysteresis only. It excludes process and dictionary cold start, TSF/host communication, candidate-window rendering, real inter-key timing, and learning writes after acceptance. The engine is reset before each source case; adjacent prefixes of the same target are processed consecutively, while the dictionary connection and runtime caches remain open for the complete run.

From `v1.31.0`, the language-model rerank of the completion runs asynchronously in the Host, off the keystroke path: the completion chosen by dictionary ranking is shown on the keystroke, and the rerank may replace it shortly afterwards. `Keystroke P95` excludes the rerank. `Final P95` adds the rerank time to an opportunity only when the rerank changes the displayed completion. Releases before `v1.31.0` have no asynchronous rerank, so both values are the same.

## Long-sentence One-key Completion Benchmark-16300

### Case Construction and Scoring

This benchmark measures whether one-key completion can extend a partially decoded long sentence, instead of inferring completion quality from the unrelated long-sentence candidate-ranking score:

- Reuse all 16,300 fixed long-sentence cases and their reviewed full Pinyin queries.
- Leave the final four complete Pinyin syllables untyped while retaining at least the first four syllables as the visible composition prefix.
- Decode that prefix in deterministic-work mode with the same long-sentence Transformer reranker used by the Host.
- Run the same constrained local-completion model when the static layer requests asynchronous refinement, apply the same confidence, timeout, and exact-path validation, then read only the single settled completion that the UI would display.
- Count a local-continuation hit when the displayed result extends the intended typed prefix and the whole displayed text remains a prefix of the reference sentence, both under the shared `他`/`她` rule from `v1.30.0`. The completion may stop after the next one to three local words; it does not have to reproduce the rest of the sentence in one step.
- Disable the user dictionary and external document context, and use a snapshot of the simplified base dictionary selected for the tested release.
- Query the immediately preceding syllable boundary before the scored query to measure whether a compatible completion remains stable as typing continues.

The public report uses four metrics suited to direct cross-version comparison under the current protocol:

- `Local Completion Hit`: correct local continuations divided by all 16,300 opportunities.
- `Predictive Prompt Coverage`: opportunities where a predictive completion was displayed, divided by all opportunities. Exact-word joins that only convert already typed Pinyin are excluded from prediction coverage and prediction misses.
- `Total Keys Saved`: net keys saved across all correct local-continuation hits after charging one key for each acceptance.
- `P95`: 95% of visible completion queries finish within this many milliseconds.

The detailed report additionally retains average keys saved per hit, incremental stability, wrong-prompt counts, whole-sentence hits, and internal-pool Oracle ranks for attribution. Oracle ranks keep strict character equality. Incremental stability is not published as a primary comparison because its eligible denominator depends on the prompts produced by each version and can be very small. Because the corpus supplies one reference, a plausible continuation with different wording still counts as a miss.

### Latency Protocol

The dictionary and runtime models are loaded and warmed before scored cases begin. Latency starts immediately before assigning the scored Pinyin prefix and includes long-sentence decoding, exact/transition lookup, language-model scoring, hysteresis, local correction during final candidate readback, and accepted continuation-model refinement. Continuation-model work that abstains or times out is asynchronous and does not delay the visible static result, so it is not added to visible latency. The measurement excludes process and model cold start, the preceding stability probe, report output, TSF-to-Host IPC, rendering, real inter-key timing, and learning writes. The engine is reset before every source sentence while dictionary connections, model sessions, and runtime caches remain open for the complete run.

## Latency Statistics

Latency columns are reported in milliseconds:

- `Mean`: arithmetic mean of all per-query decode times.
- `P50`: nearest-rank median; 50% of measured queries complete at or below this value.
- `P95`: nearest-rank 95th percentile; 95% of measured queries complete at or below this value.
- `Max`: largest per-query decode time in the run.

These values quantify complete-query engine performance and long-tail cost. They are not incremental keystroke-to-display latency and must not be presented as end-to-end typing latency. Comparisons are meaningful only when the machine, operating system, power profile, release build settings, corpus order, and dictionary snapshot are controlled.

## Result Publication

Version-specific results for the four benchmarks appear in [README.md](README.md). The short-word completion benchmark begins with `v1.15.0`. Long-sentence completion results through `v1.17.0` used the legacy whole-sentence exact criterion; the local-continuation criterion starts with the next formally evaluated release and is not backfilled. This document defines their shared source, case construction, accuracy scoring, and latency protocols.

## Notes

The benchmarks are expected to evolve with the IME. Future benchmark variants may use larger or differently distributed corpora, but their names should include the case count or another clear suffix. Every published result should record the engine and dictionary versions, runner behavior, latency mode, and scoring method so comparisons remain interpretable.
