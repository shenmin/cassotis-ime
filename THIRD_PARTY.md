# Third-Party Notices

This file lists third-party software/data used by Cassotis IME and the related license terms.

## 1) SQLite

- Component: SQLite runtime library (`sqlite3.dll`)
- Used for: dictionary storage and query
- Source:
  - https://www.sqlite.org/download.html
  - local artifacts: `third_party/sqlite/`
- License: Public Domain
- Notes:
  - SQLite is in the public domain.
  - Reference: https://www.sqlite.org/copyright.html

## 2) Unicode Unihan Data (UCD)

- Component: Unicode Unihan data files
- Used for: generating base single-character Chinese dictionary data
- Source:
  - https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip
- License/terms:
  - Unicode Terms of Use: https://www.unicode.org/terms_of_use.html
- Compliance notes:
  - Keep Unicode copyright/trademark/license notices when redistributing original Unicode data files.
  - Keep attribution for derived dictionary artifacts generated from Unicode data.

## 3) ONNX Runtime

- Component: Microsoft ONNX Runtime 1.20.1 (`onnxruntime.dll`)
- Used for: CPU inference for the host-side character language models
- Source: https://github.com/microsoft/onnxruntime/tree/v1.20.1
- Local artifacts: `third_party/onnxruntime/`
- License: MIT
- Compliance notes:
  - Redistributions retain `third_party/onnxruntime/LICENSE` and
    `third_party/onnxruntime/ThirdPartyNotices.txt`.
  - The model is loaded only by `cassotis_ime_host.exe`; it is not linked into
    the TSF DLL.

## 4) Cassotis Pinyin-Conditioned Language Model

- Component: quantized character-level causal language model with pinyin tokens
- Used for: correcting long-sentence drafts against the typed syllables and
  the text before the input
- Local artifact: `data/models/char_lm/` (one model with section 6)
- Notes:
  - The model was trained by this project on separately licensed corpora for
    both plain text and pinyin-conditioned correction; it does not contain or
    redistribute training documents.
  - It replaces the pinyin parallel generator and the MacBERT-derived local
    correction model, which are no longer shipped.
  - Inference and background loading run in the IME host process, not TSF.

## 5) Proprietary Build Toolchain (Not Redistributed)

- Embarcadero Delphi 10.4 is required to build this project.
- Delphi itself is not bundled in this repository and is licensed separately by Embarcadero.

## 6) Cassotis Character Language Model

- Component: quantized character-level causal language model
- Used for: reranking long-sentence and short-word candidates, choosing
  long-sentence one-key continuations, and the draft correction in section 4
- Local artifact: `data/models/char_lm/`
- Notes:
  - The model was trained by this project from separately licensed corpora;
    it does not contain or redistribute training documents.
  - It replaces the RBT3-derived short-word context model, which is no longer
    shipped from `v1.30.0`.
  - Inference and background loading run in the IME host process, not TSF;
    an unavailable model leaves the existing ranking unchanged.

## GPL-3.0 Notice

This project is licensed under GPL-3.0. The redistributed third-party items listed above are generally GPL-compatible:
- SQLite (public domain)
- Unicode data used under Unicode terms with required notices
- ONNX Runtime (MIT)

This file is engineering documentation and not legal advice.
