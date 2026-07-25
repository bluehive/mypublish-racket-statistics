#!/usr/bin/env python3
"""Build Kindle-submit DOCX from combined manuscript (with TOC, horizontal)."""
import hashlib
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import AUTHOR, BOOK_MD, OUT_DIR, SUBTITLE, TITLE  # noqa: E402

SRC = BOOK_MD
OUT_MD = OUT_DIR / "国家主義者の系譜.md"
OUT_DOCX = OUT_DIR / "国家主義者の系譜.docx"

from build_epub import ensure_pandoc  # noqa: E402


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy_manuscript() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC, OUT_MD)
    print(f"Copied: {OUT_MD.relative_to(ROOT)}")


def build_docx(pandoc: Path) -> None:
    cmd = [
        str(pandoc),
        str(SRC),
        "-o",
        str(OUT_DOCX),
        "--from",
        "markdown+yaml_metadata_block",
        "--to",
        "docx",
        "--toc",
        "--toc-depth=2",
        "--metadata",
        f"title={TITLE}",
        "--metadata",
        f"subtitle={SUBTITLE}",
        "--metadata",
        f"author={AUTHOR}",
        "--metadata",
        "lang=ja",
    ]
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, check=True, cwd=ROOT)


def verify_docx() -> None:
    assert SRC.exists(), f"source missing: {SRC}. Run: combine_drafts.py --kindle"
    assert OUT_MD.exists(), f"copied md missing: {OUT_MD}"
    assert OUT_DOCX.exists(), f"docx missing: {OUT_DOCX}"
    assert sha256(SRC) == sha256(OUT_MD), "output MD must match manuscript source"

    src_text = SRC.read_text(encoding="utf-8")
    assert "# 目次" in src_text, "manuscript must contain 目次 section"
    toc_links = src_text.count("](#")
    assert toc_links >= 10, f"linked TOC entries too few: {toc_links}"

    subprocess.run(["unzip", "-t", str(OUT_DOCX)], check=True, capture_output=True)

    with zipfile.ZipFile(OUT_DOCX) as zf:
        names = zf.namelist()
        assert "word/document.xml" in names, "word/document.xml missing"
        doc_xml = zf.read("word/document.xml").decode("utf-8")
        assert TITLE in doc_xml, f"title missing in DOCX: {TITLE}"
        assert AUTHOR in doc_xml, f"author missing in DOCX: {AUTHOR}"
        assert "目次" in doc_xml, "目次 missing in DOCX"
        assert "序章" in doc_xml, "序章 missing in DOCX body"
        assert "第二章" in doc_xml, "第二章 missing in DOCX body"
        assert "付録A" in doc_xml, "付録A missing in DOCX body"
        assert "付録B" in doc_xml, "付録B missing in DOCX body"
        assert "付録C" in doc_xml, "付録C missing in DOCX body"
        assert "マルクス" in doc_xml, "付録C person index incomplete"
        assert "東条英機" in doc_xml, "付録C tail entries missing"

        table_count = doc_xml.count("<w:tbl")
        assert table_count >= 1, f"付録C table missing in DOCX (w:tbl={table_count})"

        # pandoc --toc による自動目次フィールド
        assert "TOC" in doc_xml or "目次" in doc_xml, "DOCX TOC section missing"

        appendix_rows = len(re.findall(r"<w:tr", doc_xml))
        assert appendix_rows >= 55, f"appendix table rows too few: {appendix_rows}"

    md_chars = len(OUT_MD.read_text(encoding="utf-8"))
    docx_kb = OUT_DOCX.stat().st_size / 1024
    print(
        f"OK: {OUT_DOCX.name} ({docx_kb:.1f} KB, MD {md_chars:,} chars, "
        f"tables={table_count}, toc_links={toc_links})"
    )


def main() -> None:
    if not SRC.exists():
        sys.exit(f"Source not found: {SRC}. Run: python3 scripts/kokka-shugi/combine_drafts.py --kindle")

    pandoc = ensure_pandoc()
    copy_manuscript()
    build_docx(pandoc)
    verify_docx()
    print(f"\nKindle DOCX written to {OUT_DIR}")


if __name__ == "__main__":
    main()