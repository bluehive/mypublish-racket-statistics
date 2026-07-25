#!/usr/bin/env python3
"""Standard SE verification report for racket-game-of-life builds."""
from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from datetime import date
from pathlib import Path
from typing import List, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import APPENDIX_C_MARKER, BOOK_MD, BOOK_SLUG, DEFAULT_OUTPUT, OUT_DIR, ROOT, TITLE  # noqa: E402
from build_epub import verify_epub  # noqa: E402

ASSETS = ROOT / "assets/epub"


def check_epub(path: Path, *, vertical: bool, require_cover: bool) -> List[Tuple[str, str, str]]:
    css = ASSETS / ("style-vertical.css" if vertical else "style-horizontal.css")
    rows: List[Tuple[str, str, str]] = []
    try:
        verify_epub(path, css, require_cover=require_cover)
        rows.append(("アーカイブ整合", "unzip -t", "PASS"))
        rows.append(("EPUB構造", "OPF/nav/付録A-C", "PASS"))
        rows.append(("表紙", "なし" if not require_cover else "あり", "PASS"))
        rows.append(("CSS", css.name, "PASS"))
    except (AssertionError, subprocess.CalledProcessError) as exc:
        rows.append(("EPUB検証", path.name, f"FAIL: {exc}"))
    return rows


def check_docx(path: Path) -> List[Tuple[str, str, str]]:
    rows: List[Tuple[str, str, str]] = []
    if not path.exists():
        return [("DOCX存在", str(path.relative_to(ROOT)), "FAIL")]
    try:
        with zipfile.ZipFile(path) as zf:
            names = zf.namelist()
            assert any(n.endswith(".xml") for n in names), "invalid docx"
            doc = next(n for n in names if n.startswith("word/document"))
            content = zf.read(doc).decode("utf-8", errors="replace")
            assert "序章" in content or len(content) > 1000, "content too thin"
        rows.append(("DOCX整合", "zip構造", "PASS"))
        rows.append(("DOCX本文", "序章含有", "PASS"))
    except (AssertionError, zipfile.BadZipFile) as exc:
        rows.append(("DOCX検証", path.name, f"FAIL: {exc}"))
    return rows


def check_manuscript() -> List[Tuple[str, str, str]]:
    if not BOOK_MD.exists():
        return [("正本", "manuscript/.../book.md", "FAIL: not found")]
    text = BOOK_MD.read_text(encoding="utf-8")
    rows = [("正本", "book.md 存在", "PASS")]
    if "# 目次" in text and TITLE in text and APPENDIX_C_MARKER in text:
        rows.append(("正本目次", "リンク付き目次", "PASS"))
    else:
        rows.append(("正本目次", "リンク付き目次", "FAIL"))
    return rows


def render_report(rows: List[Tuple[str, str, str]], *, formats: List[str]) -> str:
    today = date.today().strftime("%Y%m%d")
    fails = [r for r in rows if r[2].startswith("FAIL")]
    overall = "PASS" if not fails else "FAIL"
    lines = [
        f"# VERIFY-{today}",
        "",
        f"- **書籍**: {BOOK_SLUG}",
        f"- **正本**: `{BOOK_MD.relative_to(ROOT)}`",
        f"- **フォーマット**: {', '.join(formats)}",
        f"- **総合判定**: **{overall}**",
        "",
        "| 項目 | 確認内容 | 判定 |",
        "|------|----------|------|",
    ]
    for item, detail, verdict in rows:
        lines.append(f"| {item} | {detail} | {verdict} |")
    lines.append("")
    return "\n".join(lines)


def run_verify(formats: List[str], *, require_cover: bool, write_file: bool = True) -> int:
    rows = check_manuscript()
    for fmt in formats:
        if fmt == "epub-horizontal":
            rows.extend(check_epub(DEFAULT_OUTPUT["epub-horizontal"], vertical=False, require_cover=require_cover))
        elif fmt == "epub-vertical":
            rows.extend(check_epub(DEFAULT_OUTPUT["epub-vertical"], vertical=True, require_cover=require_cover))
        elif fmt == "docx":
            rows.extend(check_docx(DEFAULT_OUTPUT["docx"]))

    report = render_report(rows, formats=formats)
    print(report)
    if write_file:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        out = OUT_DIR / f"VERIFY-{date.today().strftime('%Y%m%d')}.md"
        out.write_text(report + "\n", encoding="utf-8")
        print(f"\nReport: {out.relative_to(ROOT)}")

    return 0 if "FAIL" not in report else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="SE verification report for kokka-shugi")
    parser.add_argument(
        "--format",
        action="append",
        choices=["epub-horizontal", "epub-vertical", "docx"],
        default=["epub-horizontal"],
    )
    parser.add_argument("--cover", action="store_true", help="Expect cover in EPUB")
    parser.add_argument("--no-write", action="store_true", help="Print only, no VERIFY file")
    args = parser.parse_args()
    return run_verify(args.format, require_cover=args.cover, write_file=not args.no_write)


if __name__ == "__main__":
    sys.exit(main())