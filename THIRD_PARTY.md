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
  - local artifacts under `data/lexicon/unihan/` (for example: `Unihan_Readings.txt`, `Unihan_DictionaryLikeData.txt`, `Unihan_Variants.txt`)
- License/terms:
  - Unicode Terms of Use: https://www.unicode.org/terms_of_use.html
- Compliance notes:
  - Keep Unicode copyright/trademark/license notices when redistributing original Unicode data files.
  - Keep attribution for derived dictionary artifacts generated from Unicode data.

## 3) Proprietary Build Toolchain (Not Redistributed)

- Embarcadero Delphi 10.4 is required to build this project.
- Delphi itself is not bundled in this repository and is licensed separately by Embarcadero.

## 4) Not Bundled by Default

- No local LLM runtime/model binaries are bundled by default in this repository.
- If additional third-party models/runtimes are distributed in the future, add their licenses and notices here before release.

## GPL-3.0 Notice

This project is licensed under GPL-3.0. The two third-party items listed above are generally GPL-compatible:
- SQLite (public domain)
- Unicode data used under Unicode terms with required notices

This file is engineering documentation and not legal advice.
