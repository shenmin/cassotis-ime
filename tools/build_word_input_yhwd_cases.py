#!/usr/bin/env python3
"""Build fixed word-input benchmark cases from the YHWD sentence corpus.

This generator intentionally does not use the Cassotis IME dictionary or engine.
It uses an external Chinese word segmenter for semantic-ish word boundaries and
an external pinyin library for labels, then freezes the result into TSV cases.
"""

from __future__ import annotations

import argparse
import csv
import os
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


CJK_RE = re.compile(r"^[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]+$")
PINYIN_COMPACT_RE = re.compile(r"[^A-Za-z]")
SINGLE_CHAR_READING_OVERRIDES = {
    "\u7684": "de",
    "\u5730": "de",
    "\u5f97": "de",
    "\u4e86": "le",
    "\u7740": "zhe",
    "\u8bf4": "shuo",
}
SINGLE_TOKEN_DROP_CHARS = set(
    "\u7684\u4e86\u5730\u7740\u5417\u5462\u554a\u5427\u5566\u5440"
    "\u5728\u5bf9\u4ece\u5411\u7ed9\u4e3a\u4e8e\u4e0e\u548c\u8ddf\u7531"
    "\u88ab\u628a\u5c06\u8ba9\u4f7f\u4ee4\u5f53\u6bd4\u5982\u4ee5"
    "\u4f46\u800c\u5e76\u5374\u5219\u4e14\u6216\u82e5\u65e2"
    "\u4e5f\u90fd\u8fd8\u518d\u66f4\u6700\u5f88\u592a\u4ecd\u66fe\u5df2"
    "\u4ec5\u53ea\u5c31\u624d\u6b63\u53ef\u8be5\u6240\u5176\u6bcf"
    "\u4e0a\u4e0b\u4e2d\u91cc\u5185\u524d\u540e\u95f4\u8fb9"
    "\u4e00\u4e2a\u4e9b\u4eec\u7b2c\u6b64\u90a3\u8fd9"
    "\u4e0d\u6ca1\u80fd\u4f1a\u8981\u60f3\u6765\u53bb\u51fa\u8fc7\u5230"
    "\u662f\u6709\u65f6\u4fbf\u5f97\u50cf\u7528\u9053\u5e26\u7b49"
    "\u65b0\u53c8\u591a\u597d\u5927\u5c0f\u5148\u81ea\u521a\u9ad8\u8001"
    "\u53e6\u5f85\u672a\u7adf\u8fd1\u5feb\u672c\u5012\u8f83\u534a\u4e24"
    "\u56e0\u636e\u9760\u5916\u4e94\u8d8a\u65e9\u957f\u4f4e\u5404\u67d0"
    "\u500d\u79f0\u7a0d\u5e94\u539f\u8fdc\u6781\u5f3a\u5373\u5747\u6ee1"
    "\u6df1\u4f3c\u540c\u522b\u975e\u5171\u660e\u51ed\u5e38\u7686\u9887"
    "\u5c1a\u5c11\u751a\u867d\u4ea6\u5fc5\u51e0\u5c3d\u65e7\u5f31\u9042"
    "\u6682\u600e\u987b\u76f4\u4e13\u4f5c"
    "\u5f80\u671d\u79bb\u8d74\u62dc\u8d81\u4f9b\u5165\u903e"
    "\u8d77\u6210\u5b8c\u4e4b\u89c1\u822c\u8fde\u6708\u6761\u6bb5\u5c42"
    "\u90e8\u7ea7\u9700\u6b3e\u79d2\u7fa4\u5f20\u5f0f\u7248\u5316\u8005"
    "\u5904\u526f\u6027\u578b\u5b50\u7b14\u6ce2\u6b21\u53f0\u53f7\u7bc7"
    "\u4f4d\u79cd\u671f\u5468\u680b\u6001\u57df\u533a\u7aef\u9762\u4f53"
    "\u7387\u91cf\u503c\u5143\u754c"
    "\u6307\u81f3\u53ca\u7c7b\u4e3b\u611f\u7ae0\u603b\u771f\u8d35"
    "\u521d\u77ed\u8f7b\u4e09\u56db\u516d\u4e03\u516b\u4e5d\u5341"
    "\u96f6\u7565\u53d7\u66ff\u53cd\u8fbe\u4e45\u65c1\u7d27\u6697"
    "\u5047\u65e0\u4f4f"
    "\u51e1\u591f\u5168\u5fae\u633a\u9f50\u663e\u4f59\u72b6\u51c6"
    "\u4f17\u8d9f\u904d\u5206\u5c3e\u5348"
    "\u54ea\u968f\u561b\u4e48\u5e74\u5929"
    "\u4ebf"
)
CORPUS_USER_WORDS = (
    "\u6797\u6d69",
    "\u6c88\u8bed\u7199",
    "\u738b\u601d\u6db5",
    "\u827e\u5229\u65af",
    "\u5b8b\u5fd7\u660e",
    "\u738b\u4e91\u98de",
    "\u9648\u5929\u5b87",
    "\u5f20\u6653\u5cf0",
    "\u9648\u6cfd\u8f89",
    "\u8c22\u4f1f\u6797",
    "\u8d75\u660e\u8f69",
    "\u9646\u96c5\u5a77",
    "\u4f55\u601d\u5a55",
    "\u5c3c\u53e4\u62c9",
    "\u5c3c\u514b\u52b3\u65af",
    "\u57c3\u91cc\u514b",
    "\u987e\u6d77\u68ee",
    "\u5468\u534e",
    "\u6797\u6bc5",
    "\u97e9\u4e1c",
    "\u5b5f\u51e1",
    "\u738b\u9a81",
    "\u6c88\u851a",
    "\u674e\u6d2a\u6d9b",
    "\u4f55\u52a9\u7406",
    "\u5f90\u9752\u677e",
    "\u674e\u5175",
    "\u6731\u8fc5",
    "\u9648\u603b",
    "\u6797\u603b",
    "\u6731\u603b",
    "\u5b8b\u603b",
    "\u987e\u884c\u957f",
    "\u8001\u9648",
    "\u5c0f\u97e9",
    "\u6797\u54e5",
    "\u4e8c\u96c5",
    "\u8000\u8f89",
    "\u6c38\u6052\u667a\u80fd",
    "\u534e\u745e\u94f6\u884c",
    "\u661f\u5149\u79d1\u6280",
    "\u7384\u5149\u91cf\u5b50\u79d1\u6280\u6709\u9650\u516c\u53f8",
    "\u7384\u5149\u91cf\u5b50",
    "\u65b0\u6c5f\u6e7e\u57ce",
    "\u6bd4\u7279\u5e01",
    "\u6570\u636e\u96c6",
    "\u9006\u63a8",
    "\u7ea2\u6591\u75b9",
    "\u62ff\u94c1",
    "\u9884\u8fd0\u7b97",
    "\u8bdd\u75e8",
    "\u7a7f\u642d",
    "\u5578\u53eb\u58f0",
)
KNOWN_NAME_TOKENS = tuple(
    sorted(CORPUS_USER_WORDS, key=lambda value: (-len(value), value))
)
NAME_AFFIX_SPLIT_CHARS = set(
    "\u5982\u5728\u5bf9\u5f53\u4f46\u800c\u4ee4\u5411\u4ece\u4e3a\u5c06\u4f7f"
    "\u5219\u4fbf\u8fb9\u80fd\u7ed9\u4f1a\u70b9\u770b\u8bf4\u542c\u5e26\u6df1"
    "\u6240\u5148\u6b63\u624d\u5403\u53d1\u56de\u662f\u4ee5\u518d\u7ad9\u8d70"
    "\u5750\u65f6\u60f3\u95ee\u540e\u4e0b\u7565\u521a\u7b11"
)
EXPLICIT_TOKEN_SPLITS = {
    "\u5728\u6280\u672f\u4e0a": ("\u5728", "\u6280\u672f", "\u4e0a"),
    "\u4ece\u6280\u672f\u4e0a": ("\u4ece", "\u6280\u672f", "\u4e0a"),
    "\u5bf9\u6a21\u578b": ("\u5bf9", "\u6a21\u578b"),
    "\u5bf9\u7cfb\u7edf": ("\u5bf9", "\u7cfb\u7edf"),
    "\u5bf9\u5916\u90e8": ("\u5bf9", "\u5916\u90e8"),
    "\u4f46\u4ed6\u5374": ("\u4f46", "\u4ed6", "\u5374"),
    "\u53d1\u9001\u7ed9": ("\u53d1\u9001", "\u7ed9"),
    "\u89d2\u5ea6\u770b": ("\u89d2\u5ea6", "\u770b"),
    "\u4ea4\u4ed8\u7ed9": ("\u4ea4\u4ed8", "\u7ed9"),
    "\u9192\u6765\u65f6": ("\u9192\u6765", "\u65f6"),
    "\u8f6c\u53d1\u7ed9": ("\u8f6c\u53d1", "\u7ed9"),
    "\u542f\u52a8\u65f6": ("\u542f\u52a8", "\u65f6"),
    "\u501a\u9760\u5728": ("\u501a\u9760", "\u5728"),
    "\u5e2e\u5e2e\u6211": ("\u5e2e\u5e2e", "\u6211"),
    "\u4f20\u6388\u7ed9": ("\u4f20\u6388", "\u7ed9"),
    "\u4ece\u6587\u4ef6": ("\u4ece", "\u6587\u4ef6"),
    "\u5f53\u4e24\u4eba": ("\u5f53", "\u4e24\u4eba"),
    "\u5230\u4f1a\u5426": ("\u5230", "\u4f1a\u5426"),
    "\u5230\u5bb6\u65f6": ("\u5230\u5bb6", "\u65f6"),
    "\u800c\u5e7f\u53d7": ("\u800c", "\u5e7f\u53d7"),
    "\u7ed9\u4f60\u4e2a": ("\u7ed9", "\u4f60", "\u4e2a"),
    "\u7ed9\u6211\u53d1": ("\u7ed9", "\u6211", "\u53d1"),
    "\u5c06\u4f1a\u82b1": ("\u5c06\u4f1a", "\u82b1"),
    "\u5c06\u7b97\u529b": ("\u5c06", "\u7b97\u529b"),
    "\u6211\u68a6\u5230": ("\u6211", "\u68a6\u5230"),
    "\u7531\u4ed6\u53bb": ("\u7531", "\u4ed6", "\u53bb"),
    "\u795d\u4f60\u4eec": ("\u795d", "\u4f60\u4eec"),
    "\u7279\u522b\u662f\u5728": ("\u7279\u522b\u662f", "\u5728"),
    "\u6211\u548c\u6653\u5cf0": ("\u6211", "\u548c", "\u6653\u5cf0"),
    "\u8c22\u8c22\u4f60\u4eec": ("\u8c22\u8c22", "\u4f60\u4eec"),
    "\u4f60\u4f1a\u9009": ("\u4f60", "\u4f1a", "\u9009"),
    "\u8426\u7ed5\u5728": ("\u8426\u7ed5", "\u5728"),
    "\u6620\u7167\u5728": ("\u6620\u7167", "\u5728"),
    "\u53c8\u4f1a\u5728": ("\u53c8", "\u4f1a", "\u5728"),
    "\u627e\u627e\u770b": ("\u627e\u627e", "\u770b"),
    "\u6b63\u5de7\u5728": ("\u6b63\u5de7", "\u5728"),
    "\u670d\u52a1\u5668\u65f6": ("\u670d\u52a1\u5668", "\u65f6"),
    "\u4e00\u5207\u90fd\u5728": ("\u4e00\u5207", "\u90fd", "\u5728"),
    "\u5728\u77ed\u671f\u5185": ("\u5728", "\u77ed\u671f\u5185"),
    "\u5728\u5de5\u4f5c\u4e2d": ("\u5728", "\u5de5\u4f5c", "\u4e2d"),
    "\u5728\u5b9e\u8df5\u4e2d": ("\u5728", "\u5b9e\u8df5", "\u4e2d"),
}


@dataclass
class TokenOccurrence:
    target: str
    pinyin: str
    query_pinyin: str
    line_number: int
    token_number: int


@dataclass
class CaseStats:
    target: str
    pinyin: str
    query_pinyin: str
    count: int = 0
    first_line: int = 0
    first_token: int = 0


def compact_pinyin(value: str) -> str:
    return PINYIN_COMPACT_RE.sub("", value).lower()


def read_text_lines(path: Path) -> List[str]:
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return path.read_text(encoding=encoding).splitlines()
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def parse_args() -> argparse.Namespace:
    script_path = Path(__file__).resolve()
    repo_root = script_path.parents[1]
    parser = argparse.ArgumentParser(
        description="Build word-input cases with external segmentation and pinyin."
    )
    parser.add_argument("--repo-root", type=Path, default=repo_root)
    parser.add_argument(
        "--source",
        type=Path,
        default=repo_root / "tests" / "cases" / "long_sentence_16300.txt",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_root / "tests" / "cases" / "word_input_yhwd.tsv",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=repo_root / "tests" / "cases" / "word_input_yhwd.summary.txt",
    )
    parser.add_argument("--min-token-len", type=int, default=1)
    parser.add_argument("--max-token-len", type=int, default=8)
    parser.add_argument(
        "--no-hmm",
        action="store_true",
        help="Disable jieba HMM new-word discovery.",
    )
    return parser.parse_args()


def require_dependencies():
    try:
        import jieba  # type: ignore
        from pypinyin import Style, lazy_pinyin  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "Missing dependency. Install with: "
            "python -m pip install jieba==0.42.1 pypinyin==0.51.0"
        ) from exc
    return jieba, Style, lazy_pinyin


def normalize_segment_token(token: str) -> str:
    return "".join(ch for ch in token if CJK_RE.match(ch))


def configure_segmenter(jieba_module) -> None:
    for word in CORPUS_USER_WORDS:
        jieba_module.add_word(word, freq=2_000_000)


def split_known_name_affixes(token: str) -> List[str]:
    for name in KNOWN_NAME_TOKENS:
        start = token.find(name)
        if start < 0 or token == name:
            continue

        prefix = token[:start]
        suffix = token[start + len(name) :]
        if len(prefix) + len(suffix) > 2:
            continue
        if any(ch not in NAME_AFFIX_SPLIT_CHARS for ch in prefix + suffix):
            continue

        result: List[str] = []
        result.extend(prefix)
        result.append(name)
        result.extend(suffix)
        return [part for part in result if part]
    return [token]


def split_token_for_input_habit(token: str) -> List[str]:
    explicit = EXPLICIT_TOKEN_SPLITS.get(token)
    if explicit is not None:
        return list(explicit)
    return split_known_name_affixes(token)


def token_pinyin_from_sentence(
    token: str,
    sentence_syllables: Sequence[str],
    offset: int,
    length: int,
) -> Tuple[str, str]:
    if len(token) == 1 and token in SINGLE_CHAR_READING_OVERRIDES:
        syllables = [SINGLE_CHAR_READING_OVERRIDES[token]]
    else:
        syllables = [
            compact_pinyin(syllable)
            for syllable in sentence_syllables[offset : offset + length]
        ]
    syllables = [syllable for syllable in syllables if syllable]
    pinyin = "'".join(syllables)
    return pinyin, compact_pinyin(pinyin)


def iter_sentence_tokens(
    sentence: str,
    line_number: int,
    args: argparse.Namespace,
    jieba_module,
    style,
    lazy_pinyin_func,
) -> Iterable[TokenOccurrence]:
    if not sentence:
        return

    sentence_syllables = lazy_pinyin_func(sentence, style=style.NORMAL, strict=False)
    if len(sentence_syllables) != len(sentence):
        raise ValueError(
            f"pinyin alignment failed at line {line_number}: "
            f"{len(sentence_syllables)} syllables for {len(sentence)} chars"
        )

    offset = 0
    token_number = 0
    for raw_token in jieba_module.cut(sentence, cut_all=False, HMM=not args.no_hmm):
        token = normalize_segment_token(raw_token)
        if not token:
            offset += len(raw_token)
            continue

        start = sentence.find(token, offset)
        if start < 0:
            start = offset
        offset = start + len(token)

        part_offset = 0
        for part in split_token_for_input_habit(token):
            if len(part) < args.min_token_len or len(part) > args.max_token_len:
                part_offset += len(part)
                continue
            if len(part) == 1 and part in SINGLE_TOKEN_DROP_CHARS:
                part_offset += len(part)
                continue

            pinyin, query_pinyin = token_pinyin_from_sentence(
                part,
                sentence_syllables,
                start + part_offset,
                len(part),
            )
            part_offset += len(part)
            if not query_pinyin:
                continue

            token_number += 1
            yield TokenOccurrence(
                target=part,
                pinyin=pinyin,
                query_pinyin=query_pinyin,
                line_number=line_number,
                token_number=token_number,
            )


def length_bucket(length: int) -> str:
    if length <= 1:
        return "single"
    if length == 2:
        return "word2"
    if length == 3:
        return "word3"
    if length == 4:
        return "word4"
    return "word5plus"


def frequency_bucket(count: int) -> str:
    if count >= 100:
        return "high"
    if count >= 10:
        return "medium"
    return "low"


def ambiguity_bucket(ambiguity: int) -> str:
    if ambiguity >= 50:
        return "high"
    if ambiguity >= 10:
        return "medium"
    return "low"


def build_cases(
    sentences: Sequence[str],
    args: argparse.Namespace,
) -> Tuple[List[CaseStats], Counter, int]:
    jieba_module, style, lazy_pinyin_func = require_dependencies()
    cases: Dict[Tuple[str, str], CaseStats] = {}
    occurrence_length_counts: Counter = Counter()
    token_count = 0

    # Avoid verbose dictionary-loading messages in benchmark setup logs.
    try:
        jieba_module.setLogLevel(40)
    except AttributeError:
        pass
    configure_segmenter(jieba_module)

    for line_number, sentence in enumerate(sentences, 1):
        for occurrence in iter_sentence_tokens(
            sentence,
            line_number,
            args,
            jieba_module,
            style,
            lazy_pinyin_func,
        ):
            key = (occurrence.target, occurrence.query_pinyin)
            item = cases.get(key)
            if item is None:
                item = CaseStats(
                    target=occurrence.target,
                    pinyin=occurrence.pinyin,
                    query_pinyin=occurrence.query_pinyin,
                    first_line=occurrence.line_number,
                    first_token=occurrence.token_number,
                )
                cases[key] = item
            item.count += 1
            token_count += 1
            occurrence_length_counts[length_bucket(len(occurrence.target))] += 1

    sorted_cases = sorted(
        cases.values(),
        key=lambda item: (-item.count, len(item.target), item.query_pinyin, item.target),
    )
    return sorted_cases, occurrence_length_counts, token_count


def segmentation_label(args: argparse.Namespace) -> str:
    return "jieba_precise_nohmm" if args.no_hmm else "jieba_precise_hmm"


def write_cases(path: Path, cases: List[CaseStats], args: argparse.Namespace) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ambiguity_by_query = Counter(item.query_pinyin for item in cases)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "index",
                "target",
                "pinyin",
                "query_pinyin",
                "count",
                "token_len",
                "length_bucket",
                "frequency_bucket",
                "corpus_ambiguity",
                "ambiguity_bucket",
                "first_line",
                "first_token",
                "segmentation",
                "pinyin_method",
            ]
        )
        for index, item in enumerate(cases, 1):
            ambiguity = ambiguity_by_query[item.query_pinyin]
            writer.writerow(
                [
                    index,
                    item.target,
                    item.pinyin,
                    item.query_pinyin,
                    item.count,
                    len(item.target),
                    length_bucket(len(item.target)),
                    frequency_bucket(item.count),
                    ambiguity,
                    ambiguity_bucket(ambiguity),
                    item.first_line,
                    item.first_token,
                    segmentation_label(args),
                    "pypinyin_sentence_context",
                ]
            )


def write_summary(
    path: Path,
    args: argparse.Namespace,
    sentences: Sequence[str],
    cases: List[CaseStats],
    occurrence_length_counts: Counter,
    token_count: int,
) -> None:
    unique_length_counts = Counter(length_bucket(len(item.target)) for item in cases)
    frequency_counts = Counter(frequency_bucket(item.count) for item in cases)
    ambiguity_counts = Counter(
        ambiguity_bucket(value)
        for value in Counter(item.query_pinyin for item in cases).values()
    )
    jieba_module, _style, _lazy_pinyin_func = require_dependencies()
    try:
        import pypinyin  # type: ignore

        pypinyin_version = getattr(pypinyin, "__version__", "unknown")
    except ImportError:
        pypinyin_version = "unknown"
    jieba_version = getattr(jieba_module, "__version__", "unknown")

    lines = [
        "word_input_yhwd corpus source",
        f"source={args.source}",
        "segmentation=jieba precise mode",
        f"jieba_version={jieba_version}",
        f"jieba_hmm={not args.no_hmm}",
        "pinyin=pypinyin sentence-context normal style, compact query key",
        f"pypinyin_version={pypinyin_version}",
        "single_char_reading_overrides=U+7684:de,U+5730:de,U+5F97:de,U+4E86:le,U+7740:zhe,U+8BF4:shuo",
        "corpus_user_words=proper names and stable novel entities, used only for source tokenization",
        "input_habit_postsplit=known-name affixes plus a small explicit phrase split list",
        "single_token_policy=drop grammar particles, coverbs, conjunctions, locatives, degree adverbs, modals, and other high-context single-character tokens",
        "uses_cassotis_engine=false",
        "uses_cassotis_ime_dictionary=false",
        f"output={args.output}",
        f"sentences={len(sentences)}",
        f"token_occurrences={token_count}",
        f"unique_cases={len(cases)}",
        f"min_token_len={args.min_token_len}",
        f"max_token_len={args.max_token_len}",
        "",
        "unique_by_length_bucket:",
    ]
    for key in ("single", "word2", "word3", "word4", "word5plus"):
        lines.append(f"  {key}={unique_length_counts[key]}")

    lines.append("")
    lines.append("occurrences_by_length_bucket:")
    for key in ("single", "word2", "word3", "word4", "word5plus"):
        lines.append(f"  {key}={occurrence_length_counts[key]}")

    lines.append("")
    lines.append("unique_by_frequency_bucket:")
    for key in ("high", "medium", "low"):
        lines.append(f"  {key}={frequency_counts[key]}")

    lines.append("")
    lines.append("query_keys_by_ambiguity_bucket:")
    for key in ("high", "medium", "low"):
        lines.append(f"  {key}={ambiguity_counts[key]}")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    args.repo_root = args.repo_root.resolve()
    args.source = args.source.resolve()
    args.output = args.output.resolve()
    args.summary = args.summary.resolve()

    if args.min_token_len < 1:
        raise SystemExit("--min-token-len must be >= 1")
    if args.max_token_len < args.min_token_len:
        raise SystemExit("--max-token-len must be >= --min-token-len")

    sentences = read_text_lines(args.source)
    cases, occurrence_length_counts, token_count = build_cases(sentences, args)
    write_cases(args.output, cases, args)
    write_summary(args.summary, args, sentences, cases, occurrence_length_counts, token_count)

    print(f"source={args.source}")
    print(f"segmentation={segmentation_label(args)}")
    print("pinyin=pypinyin_sentence_context")
    print(f"output={args.output}")
    print(f"summary={args.summary}")
    print(f"sentences={len(sentences)}")
    print(f"token_occurrences={token_count}")
    print(f"unique_cases={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
