#!/usr/bin/env python3
"""Unified build entry for racket-game-of-life (default: EPUB horizontal)."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import BOOK_MD, BOOK_SLUG, COVER, DEFAULT_OUTPUT, OUT_DIR, ROOT  # noqa: E402
from build_epub import (  # noqa: E402
    build,
    ensure_pandoc,
    post_process_vertical_epub,
    verify_epub,
)
from verify import run_verify  # noqa: E402

ASSETS = ROOT / "assets/epub"


def refresh_manuscript() -> None:
    combine = ROOT / f"scripts/{BOOK_SLUG}/combine_drafts.py"
    print("Refreshing book.md via combine_drafts.py")
    subprocess.run([sys.executable, str(combine)], check=True, cwd=ROOT)


def build_epub_horizontal(*, cover: Optional[Path], refresh: bool) -> Path:
    if refresh:
        refresh_manuscript()
    if not BOOK_MD.exists():
        sys.exit(f"Source not found: {BOOK_MD}")
    pandoc = ensure_pandoc()
    css = ASSETS / "style-horizontal.css"
    out = DEFAULT_OUTPUT["epub-horizontal"]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build(pandoc, css, out, src=BOOK_MD, cover=cover)
    verify_epub(out, css, require_cover=cover is not None)
    print(f"Built {out.relative_to(ROOT)}")
    return out


def build_epub_vertical(*, cover: Optional[Path], refresh: bool) -> Path:
    if refresh:
        refresh_manuscript()
    if not BOOK_MD.exists():
        sys.exit(f"Source not found: {BOOK_MD}")
    pandoc = ensure_pandoc()
    css = ASSETS / "style-vertical.css"
    out = DEFAULT_OUTPUT["epub-vertical"]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build(pandoc, css, out, src=BOOK_MD, cover=cover)
    post_process_vertical_epub(out)
    verify_epub(out, css, require_cover=cover is not None)
    print(f"Built {out.relative_to(ROOT)}")
    return out


def build_docx(*, refresh: bool) -> Path:
    script = ROOT / f"scripts/{BOOK_SLUG}/build_kindle_docx.py"
    if refresh:
        refresh_manuscript()
    subprocess.run([sys.executable, str(script)], check=True, cwd=ROOT)
    return DEFAULT_OUTPUT["docx"]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Unified racket-game-of-life build (default: epub-horizontal, no cover)"
    )
    parser.add_argument(
        "--format",
        choices=["epub-horizontal", "epub-vertical", "docx"],
        default="epub-horizontal",
        help="Output format (次冊以降のデフォルト: epub-horizontal)",
    )
    cover_group = parser.add_mutually_exclusive_group()
    cover_group.add_argument("--cover", action="store_true", help="Include cover image")
    cover_group.add_argument("--no-cover", action="store_true", help="No cover (default)")
    parser.add_argument("--no-refresh", action="store_true", help="Skip combine_drafts.py")
    parser.add_argument("--verify", action="store_true", help="Write VERIFY-YYYYMMDD.md report")
    args = parser.parse_args()

    use_cover = args.cover
    if args.format.startswith("epub"):
        if args.format == "epub-horizontal":
            build_epub_horizontal(cover=COVER if use_cover else None, refresh=not args.no_refresh)
        else:
            build_epub_vertical(cover=COVER if use_cover else None, refresh=not args.no_refresh)
    else:
        build_docx(refresh=not args.no_refresh)

    if args.verify:
        return run_verify([args.format], require_cover=use_cover)
    return 0


if __name__ == "__main__":
    sys.exit(main())