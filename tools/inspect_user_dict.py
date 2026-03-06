#!/usr/bin/env python3
"""
Inspect Cassotis IME user dictionary rows and flag suspicious entries.

The script is intentionally conservative. It reports three categories:
1. single_char_mismatch: full-pinyin single-character rows whose reading does
   not exist in the base dictionary.
2. normalized_base_duplicate: user rows that already exist in the base
   dictionary under the same normalized pinyin/text pair.
3. low_conflict_phrase: low-confidence multi-character user rows whose pinyin
   bucket already has a base phrase, but the exact text does not exist in base.

Default paths match the standard build layout.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sqlite3
from collections import Counter
from typing import Iterable, List, Tuple


FULL_PINYIN_RE = re.compile(r"^[a-z]+(?:'[a-z]+)*$")
CJK_BMP_RE = re.compile(r"^[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]+$")


def normalize_pinyin(value: str) -> str:
    return value.strip().lower().replace("'", "")


def is_full_pinyin(value: str) -> bool:
    return bool(FULL_PINYIN_RE.fullmatch(value.strip().lower()))


def cjk_len(value: str) -> int:
    return len(value) if CJK_BMP_RE.fullmatch(value) else 0


def load_rows(conn: sqlite3.Connection) -> List[Tuple[str, str, int, int]]:
    sql = """
        SELECT pinyin, text, MAX(user_weight), MAX(commit_count)
        FROM (
            SELECT pinyin, text, weight AS user_weight, 0 AS commit_count FROM dict_user
            UNION ALL
            SELECT pinyin, text, 0 AS user_weight, commit_count FROM dict_user_stats
        )
        GROUP BY pinyin, text
        ORDER BY text, pinyin
    """
    return list(conn.execute(sql))


def exact_base_exists(base: sqlite3.Connection, pinyin: str, text: str) -> bool:
    row = base.execute(
        "SELECT 1 FROM dict_base WHERE pinyin = ? AND text = ? LIMIT 1",
        (pinyin, text),
    ).fetchone()
    return row is not None


def normalized_base_exists(base: sqlite3.Connection, pinyin: str, text: str) -> bool:
    if exact_base_exists(base, pinyin, text):
        return True
    target = normalize_pinyin(pinyin)
    for (candidate_pinyin,) in base.execute(
        "SELECT pinyin FROM dict_base WHERE text = ? LIMIT 64", (text,)
    ):
        if normalize_pinyin(candidate_pinyin) == target:
            return True
    return False


def has_any_base_phrase_for_pinyin(base: sqlite3.Connection, pinyin: str) -> bool:
    row = base.execute(
        "SELECT 1 FROM dict_base WHERE pinyin = ? AND length(text) >= 2 LIMIT 1",
        (pinyin,),
    ).fetchone()
    return row is not None


def classify_rows(
    base: sqlite3.Connection,
    rows: Iterable[Tuple[str, str, int, int]],
) -> List[Tuple[str, str, str, int, int]]:
    issues: List[Tuple[str, str, str, int, int]] = []
    for pinyin, text, user_weight, commit_count in rows:
        pinyin_key = (pinyin or "").strip().lower()
        text_value = (text or "").strip()
        if not pinyin_key or not text_value:
            continue

        text_units = cjk_len(text_value)
        if text_units == 1 and is_full_pinyin(pinyin_key) and not exact_base_exists(
            base, pinyin_key, text_value
        ):
            issues.append(
                ("single_char_mismatch", pinyin_key, text_value, user_weight, commit_count)
            )
            continue

        if normalized_base_exists(base, pinyin_key, text_value):
            issues.append(
                ("normalized_base_duplicate", pinyin_key, text_value, user_weight, commit_count)
            )
            continue

        if (
            text_units >= 2
            and is_full_pinyin(pinyin_key)
            and user_weight <= 1
            and commit_count <= 1
            and has_any_base_phrase_for_pinyin(base, pinyin_key)
        ):
            issues.append(
                ("low_conflict_phrase", pinyin_key, text_value, user_weight, commit_count)
            )

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect suspicious Cassotis user-dictionary rows.")
    parser.add_argument(
        "--base-db",
        default=r"D:\cassotis_ime_public\out\data\dict_sc.db",
        help="Path to base dictionary SQLite DB",
    )
    parser.add_argument(
        "--user-db",
        default=r"D:\cassotis_ime_public\out\data\user_dict.db",
        help="Path to user dictionary SQLite DB",
    )
    parser.add_argument("--limit", type=int, default=80, help="Max rows to print")
    args = parser.parse_args()

    base_path = pathlib.Path(args.base_db)
    user_path = pathlib.Path(args.user_db)
    if not base_path.exists():
        raise SystemExit(f"Base DB not found: {base_path}")
    if not user_path.exists():
        raise SystemExit(f"User DB not found: {user_path}")

    with sqlite3.connect(str(base_path)) as base_conn, sqlite3.connect(str(user_path)) as user_conn:
        rows = load_rows(user_conn)
        issues = classify_rows(base_conn, rows)

    counts = Counter(kind for kind, *_ in issues)
    print(f"user_rows={len(rows)} suspicious={len(issues)}")
    for key in ("single_char_mismatch", "normalized_base_duplicate", "low_conflict_phrase"):
        print(f"  {key}: {counts.get(key, 0)}")

    if not issues:
        return 0

    print("")
    print("kind\tpinyin\ttext\tuser_weight\tcommit_count")
    for kind, pinyin, text, user_weight, commit_count in issues[: max(0, args.limit)]:
        print(f"{kind}\t{pinyin}\t{text}\t{user_weight}\t{commit_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
