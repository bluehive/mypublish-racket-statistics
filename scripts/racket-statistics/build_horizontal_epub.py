#!/usr/bin/env python3
"""Build horizontal EPUB (no cover) from 国家主義者の系譜.md for Issue #21."""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import build_epub_horizontal  # noqa: E402


def main() -> None:
    build_epub_horizontal(cover=None, refresh=True)


if __name__ == "__main__":
    main()