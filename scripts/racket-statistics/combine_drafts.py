#!/usr/bin/env python3
"""Combine Zenn book chapters (books/) into manuscript book.md for EPUB.

Canonical source: books/racket-statistics/*.md
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import AUTHOR, BOOK_SLUG, ROOT, SUBTITLE, TITLE  # noqa: E402

BOOK_DIR = ROOT / f"books/{BOOK_SLUG}"
OUT_BOOK = ROOT / f"manuscript/{BOOK_SLUG}/book.md"
CONFIG = BOOK_DIR / "config.yaml"


def parse_chapters(config_text: str) -> list[str]:
    """Parse chapters list from config.yaml (simple, no full YAML dep)."""
    chapters: list[str] = []
    in_chapters = False
    for line in config_text.splitlines():
        if re.match(r"^chapters:\s*$", line):
            in_chapters = True
            continue
        if in_chapters:
            m = re.match(r"^\s+-\s+([A-Za-z0-9_-]+)\s*$", line)
            if m:
                chapters.append(m.group(1))
                continue
            if line.strip() and not line.startswith(" ") and not line.startswith("\t"):
                break
            if line.strip().startswith("#"):
                continue
            if not line.strip():
                continue
            # other indented keys end chapters
            if re.match(r"^\s+\w+:", line):
                break
    return chapters


def strip_front_matter(text: str) -> str:
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            return parts[2].lstrip("\n")
    return text


def chapter_title(text: str, slug: str) -> str:
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            for line in parts[1].splitlines():
                m = re.match(r'^title:\s*["\']?(.*?)["\']?\s*$', line)
                if m:
                    return m.group(1).strip()
    return slug


def main() -> int:
    if not CONFIG.exists():
        print(f"Missing {CONFIG}", file=sys.stderr)
        return 1
    chapters = parse_chapters(CONFIG.read_text(encoding="utf-8"))
    if not chapters:
        print("No chapters in config.yaml", file=sys.stderr)
        return 1

    blocks = [
        f"# {TITLE}\n\n",
        f"> **副題**: {SUBTITLE}  \n",
        f"> **著者**: {AUTHOR}  \n",
        f"> **正本**: `books/{BOOK_SLUG}/` (Zenn book)  \n\n",
        "---\n\n",
    ]
    for slug in chapters:
        path = BOOK_DIR / f"{slug}.md"
        if not path.exists():
            print(f"Missing chapter: {path}", file=sys.stderr)
            return 1
        raw = path.read_text(encoding="utf-8")
        title = chapter_title(raw, slug)
        body = strip_front_matter(raw).strip()
        blocks.append(f"## {title}\n\n{body}\n\n")

    OUT_BOOK.parent.mkdir(parents=True, exist_ok=True)
    OUT_BOOK.write_text("".join(blocks), encoding="utf-8")
    print(f"Wrote {OUT_BOOK.relative_to(ROOT)} from {len(chapters)} chapters")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
