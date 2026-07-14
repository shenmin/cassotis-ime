# Cassotis Long Sentence Corpus Benchmark-16300

The Cassotis Long Sentence Corpus Benchmark-16300 tracks long-sentence Pinyin decoding quality across releases. It is intended to make release quality measurable instead of relying only on hand-picked example sentences.

## Corpus Source

The corpus is derived from the developer's own novel, [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)):

The benchmark extracts eligible Chinese sentences from the corpus and converts each sentence to Pinyin before feeding it to the IME engine.

## Corpus Scale

Benchmark-16300 currently contains 16,300 eligible sentences.

Future benchmark variants may use larger or different corpus sets, but their names should include the corpus size or another clear suffix so results remain comparable.

## Method

- Split text by punctuation and line breaks.
- Ignore sentences containing English letters.
- Ignore sentences shorter than the configured minimum CJK length.
- Convert each sentence to Pinyin with the benchmark reverse-Pinyin builder.
- Generate IME candidates using the engine and dictionary under test.
- Count a sentence as `Top1` pass if the first candidate exactly matches the original sentence.
- Count a sentence as `Top2` pass if either of the first two candidates exactly matches the original sentence.

## Latency Method

The published latency values measure engine-only full-query decoding. They are collected with the following protocol:

- Process the canonical 16,300 cases serially in one runner process and in their fixed corpus order.
- Use a snapshot of the simplified base dictionary selected for the tested release; disable the user dictionary by default.
- Reset the engine composition state before each case while retaining the same dictionary connection and its runtime caches for the complete run.
- Assign the complete Pinyin query to the engine in one operation, then generate and read the candidate list.
- Measure from immediately before the complete query is assigned until candidate retrieval finishes.
- Exclude process startup, dictionary opening, reverse-Pinyin conversion, report writing, TSF integration, candidate-window rendering, real keystrokes, and inter-key timing.

The latency columns are reported in milliseconds:

- `Mean`: arithmetic mean of all per-sentence decode times.
- `P95`: nearest-rank 95th percentile; 95% of measured sentences complete at or below this value.
- `Max`: largest per-sentence decode time in the run.

These values quantify complete-query decoder performance and long-tail cost. They are not incremental keystroke-to-display latency and must not be presented as end-to-end typing latency. Latency comparisons are meaningful only when the machine, operating system, power profile, release build settings, corpus order, and dictionary snapshot are controlled.

## Result Publication

Version-specific Benchmark-16300 results are published in `README.md`. This document defines the corpus source, scale, accuracy scoring, and latency method.

## Notes

The benchmark is expected to evolve with the IME. Every published result should record the corpus size, engine and dictionary versions, test runner behavior, latency mode, and scoring method so future comparisons remain interpretable.
