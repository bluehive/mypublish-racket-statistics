"""Shared paths for racket-statistics build scripts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOOK_SLUG = "racket-statistics"
BOOK_MD = ROOT / "manuscript/racket-statistics/book.md"
OUT_DIR = ROOT / "output/racket-statistics"
ASSETS = ROOT / "assets/epub"
COVER = ROOT / "images/cover.jpg"

TITLE = "ボートレース統計入門"
SUBTITLE = "Racketで学ぶデータ解析と統計フレームワーク"
AUTHOR = "陸機雑学ファクトリー"
EPUB_BASENAME = "ボートレース統計入門"

APPENDIX_C_MARKER = "RacketFrames"

DEFAULT_OUTPUT = {
    "epub-horizontal": OUT_DIR / f"{EPUB_BASENAME}-横書き.epub",
    "epub-vertical": OUT_DIR / f"{EPUB_BASENAME}-縦書き.epub",
    "docx": OUT_DIR / f"{EPUB_BASENAME}.docx",
}
