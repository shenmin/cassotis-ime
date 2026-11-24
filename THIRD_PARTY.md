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
- Used for: CPU inference for the host-side character language model
- Source: https://github.com/microsoft/onnxruntime/tree/v1.20.1
- Local artifacts: `third_party/onnxruntime/`
- License: MIT
- Compliance notes:
  - Redistributions retain `third_party/onnxruntime/LICENSE` and
    `third_party/onnxruntime/ThirdPartyNotices.txt`.
  - The model is loaded only by `cassotis_ime_host.exe`; it is not linked into
    the TSF DLL.

## 4) Cassotis Character Language Model

- Component: quantized character-level causal language model, with pinyin
  tokens for pinyin-conditioned correction
- Used for: scoring long-sentence and short-word candidates, reranking one-key
  completions, choosing long-sentence one-key continuations, and correcting
  long-sentence drafts against the typed syllables and the text before the
  input
- Local artifact: `data/models/char_lm/` (stored as numbered parts and joined
  during the build)
- Notes:
  - The model was trained by this project on separately licensed corpora, for
    both plain text and pinyin-conditioned correction; it does not contain or
    redistribute training documents.
  - Its architecture and training code come from nc-GPT
    (<https://github.com/shenmin/nc-gpt>, by the author of this project,
    Apache License 2.0), which is not redistributed here. nc-GPT's own 1.2B
    models served only as offline references while the size of this model
    was chosen; their weights are not published and are not part of the
    IME.
  - Its training continued on a selection of everyday dialogues from LCCC
    (Wang et al., "A Large-Scale Chinese Short-Text Conversation Dataset",
    NLPCC 2020; <https://github.com/thu-coai/CDial-GPT>), released under the
    MIT License, Copyright (c) 2020 lemon234071. The model does not contain
    or redistribute the dialogues.
  - From `v2.9.0` it also learned the preferences of Qwen3.5-9B-Base over
    whole sentences and continuations (item 8); the larger model is a
    training teacher only and is not shipped.
  - It is the only neural model shipped from `v2.0.0`. It replaces the
    RBT3-derived short-word context model (no longer shipped from `v1.30.0`),
    the pinyin parallel generator and the MacBERT-derived local correction
    model, none of which is shipped any more.
  - Its attention is computed by an operator written for this project
    (`src/host/native/nc_trie_attention.inc`) and registered with ONNX Runtime
    as a custom operator.
  - Inference and background loading run in the IME host process, not TSF;
    an unavailable model leaves the existing ranking unchanged.

## 5) Proprietary Build Toolchain (Not Redistributed)

- Embarcadero Delphi 10.4 is required to build this project.
- Delphi itself is not bundled in this repository and is licensed separately by Embarcadero.
- The native language-model bridge is built with the Microsoft Visual C++
  build tools (Visual Studio 2022), which are likewise not bundled and are
  licensed separately by Microsoft.

## 6) 12Dicts English Word List

- Component: a filtered subset of Alan Beale's 12Dicts `2of12full.txt`,
  packaged by Kevin Atkinson; public-domain word-list data.
- Used for: English-word recognition in Chinese mode, without network access.
- Source: https://github.com/en-wl/wordlist/tree/b22230cc5250887737fdefe9ca4c9d9d01230eaa/alt12dicts
- The source README states that all files in that directory are in the
  public domain. The generated `src/engine/nc_english_words.inc` retains the
  source URL and SHA-256. Only lowercase ASCII words supported by at least
  eight dictionaries are included, plus a small project-maintained list of
  computing terms. Compact letter-pair and letter-triple tables derived from
  these spellings also support conservative recognition of unlisted names;
  each sequence must occur in at least two different words.
- The same generated file lists the spellings of Latin-letter words that
  occur inside Chinese text (`app`, `ppt`), each with a frequency band. They
  were counted by this project in the corpora the character language model
  (item above) was trained on: a word is listed when it occurs 30 times or
  more in at least two of the corpora. The file holds the spellings and
  bands only; it does not contain or redistribute any text of the corpora.

## 7) OpenCC Character Tables

- Component: character tables derived from OpenCC's `TSCharacters.txt`,
  `STCharacters.txt`, `TWVariants.txt` and `TWVariantsRevPhrases.txt` (Open
  Chinese Convert, BYVoid and contributors).
- Used for: the traditional variant reads a text in simplified characters
  for the character language model, and writes the characters of its own
  tables and those the model writes in their Taiwan traditional forms.
- Source: https://github.com/BYVoid/OpenCC/tree/556ed22496d650bd0b13b6c163be9814637970ae/data/dictionary
  (ver.1.1.9)
- License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)
- Notes:
  - `src/engine/nc_traditional_chars.inc` is generated by
    `tools/build_traditional_chars.py`; it retains the source commit and the
    SHA-256 of the four files. It holds code-unit pairs of the Basic
    Multilingual Plane and the 27 words in which 著 keeps its form (著名,
    顯著), not OpenCC's other phrase tables or program code.
  - The license text is in `third_party/opencc/LICENSE`.

## 8) Qwen3.5-9B-Base (Training Teacher, Not Redistributed)

- Component: Qwen3.5-9B-Base, a subword-tokenized base language model by
  the Qwen team (Alibaba).
- Used for: offline training of the character language model (item 4) from
  `v2.9.0`. The teacher scored candidate sentences and continuations drawn
  from the project's training data (no benchmark cases), and the character
  model learned its preferences by cross-tokenizer sequence-level
  distillation; the first four positions of each text stayed anchored to
  the previous character model, and the result was averaged equally with
  that model.
- Source: https://huggingface.co/Qwen/Qwen3.5-9B-Base
- License: Apache License 2.0
  (https://huggingface.co/Qwen/Qwen3.5-9B-Base/blob/main/LICENSE)
- Notes:
  - Neither the teacher's weights nor its tokenizer is shipped or needed at
    run time; the IME contains only the character model trained with its
    scores.

## 9) SUN Haifeng's Wubi 86 Tables

- Component: the Wubi 86 character and word tables of SUN Haifeng
  (海峰五笔), `GBK.tab` and `Word.tab` as packaged by ibus-table-chinese.
- Used for: the code table of the Wubi/pinyin mixed scheme
  (`base_dict\wubi86_table.txt`), which the lexicon builds from them
  (`scripts/build_wubi86_table.py` of cassotis-lexicon) and the IME reads only
  in that scheme.
- Source: https://github.com/mike-fabian/ibus-table-chinese/tree/e0dd8bfdff9e0d2194c8e57f1ded606fb53e29c1/tables/wubi-haifeng
- License: BSD 3-Clause License, Copyright (c) 2010, SUN Haifeng
- Notes:
  - The table keeps the codes and the order of Haifeng's tables. Codes the
    tables leave empty take the characters' tolerant codes from the same
    tables and dictionary words of the lexicon, coded by the Wubi 86
    word-code rule.
  - The license text is in `third_party/wubi_haifeng/LICENSE`.

## GPL-3.0 Notice

This project is licensed under GPL-3.0. The redistributed third-party items listed above are generally GPL-compatible:
- SQLite (public domain)
- Unicode data used under Unicode terms with required notices
- ONNX Runtime (MIT)
- 12Dicts English word-list data (public domain)
- OpenCC character tables (Apache License 2.0, compatible with GPL-3.0)
- SUN Haifeng's Wubi 86 tables (BSD 3-Clause)

nc-GPT's training code and Qwen3.5-9B-Base were used only to train the
character language model and are not redistributed.

This file is engineering documentation and not legal advice.
