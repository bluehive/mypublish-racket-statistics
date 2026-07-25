#!/usr/bin/env python3
"""Build horizontal and vertical EPUB from combined manuscript."""
import io
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import (  # noqa: E402
    APPENDIX_C_MARKER,
    ASSETS,
    AUTHOR,
    BOOK_MD,
    COVER,
    EPUB_BASENAME,
    OUT_DIR,
    ROOT,
    SUBTITLE,
    TITLE,
)

SRC = BOOK_MD
TOOLS = ROOT / "tools"
PANDOC_BIN = TOOLS / "pandoc-3.6.4/bin/pandoc"
PANDOC_URL = (
    "https://github.com/jgm/pandoc/releases/download/3.6.4/"
    "pandoc-3.6.4-linux-amd64.tar.gz"
)

# 2桁以上の数字列（年号・年範囲）を縦中横化。見出し番号 0.1 等は対象外。
TCY_PATTERN = re.compile(r"\d{2,}(?:[–\-－—／/][0-9]{1,4})?")


def wrap_tcy_spans(text: str) -> str:
    def replacer(match: re.Match[str]) -> str:
        return f'<span class="tcy">{match.group(0)}</span>'

    return TCY_PATTERN.sub(replacer, text)


def inject_tcy_spans(html: str) -> str:
    body_match = re.search(r"(<body[^>]*>)(.*?)(</body>)", html, flags=re.DOTALL)
    if not body_match:
        return html
    open_tag, body, close_tag = body_match.groups()
    parts = re.split(r"(<[^>]+>)", body)
    processed_body = "".join(
        part if part.startswith("<") else wrap_tcy_spans(part) for part in parts
    )
    return (
        html[: body_match.start()]
        + open_tag
        + processed_body
        + close_tag
        + html[body_match.end() :]
    )


def post_process_vertical_epub(path: Path) -> int:
    """Wrap multi-digit numbers for tatechuyoko in vertical EPUB chapters."""
    changed = 0
    with zipfile.ZipFile(path, "r") as zin:
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename.startswith("EPUB/text/ch") and item.filename.endswith(
                    ".xhtml"
                ):
                    html = data.decode("utf-8")
                    updated = inject_tcy_spans(html)
                    if updated != html:
                        changed += 1
                        data = updated.encode("utf-8")
                compress_type = (
                    zipfile.ZIP_STORED
                    if item.filename == "mimetype"
                    else item.compress_type
                )
                new_info = zipfile.ZipInfo(item.filename, item.date_time)
                new_info.compress_type = compress_type
                new_info.external_attr = item.external_attr
                zout.writestr(new_info, data, compress_type=compress_type)
        buf.seek(0)
        path.write_bytes(buf.read())
    print(f"TCY spans injected in {changed} chapter(s)")
    return changed


def ensure_pandoc() -> Path:
    if shutil.which("pandoc"):
        return Path(shutil.which("pandoc"))
    if PANDOC_BIN.exists():
        return PANDOC_BIN
    TOOLS.mkdir(parents=True, exist_ok=True)
    archive = TOOLS / "pandoc.tar.gz"
    print(f"Downloading pandoc from {PANDOC_URL}")
    urllib.request.urlretrieve(PANDOC_URL, archive)
    with tarfile.open(archive, "r:gz") as tf:
        tf.extractall(TOOLS)
    archive.unlink(missing_ok=True)
    if not PANDOC_BIN.exists():
        sys.exit("pandoc binary not found after download")
    return PANDOC_BIN


def build(
    pandoc: Path,
    css: Path,
    out: Path,
    src: Path,
    cover: Optional[Path] = None,
) -> None:
    cmd = [
        str(pandoc),
        str(src),
        "-o",
        str(out),
        "--from",
        "markdown+yaml_metadata_block",
        "--to",
        "epub3",
        "--toc",
        "--toc-depth=2",
        "--css",
        str(css),
        "--metadata",
        f"title={TITLE}",
        "--metadata",
        f"subtitle={SUBTITLE}",
        "--metadata",
        f"author={AUTHOR}",
        "--metadata",
        "lang=ja",
    ]
    if cover:
        cmd.extend(["--epub-cover-image", str(cover)])
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, check=True, cwd=ROOT)


def verify_epub(path: Path, css_path: Path, *, require_cover: bool = True) -> None:
    subprocess.run(["unzip", "-t", str(path)], check=True, capture_output=True)
    is_vertical = "vertical" in css_path.name
    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
        assert "mimetype" in names, "missing mimetype"
        assert any(n.endswith(".opf") for n in names), "missing OPF"
        assert any("style" in n for n in names), "missing CSS in EPUB"
        opf = next(n for n in names if n.endswith(".opf"))
        content = zf.read(opf).decode("utf-8")
        assert TITLE in content, f"title missing in OPF: {TITLE}"
        assert AUTHOR in content, f"author missing in OPF: {AUTHOR}"
        title_page = next(n for n in names if n.endswith("title_page.xhtml"))
        title_html = zf.read(title_page).decode("utf-8")
        assert SUBTITLE in title_html, f"subtitle missing in title page: {SUBTITLE}"
        nav = next(n for n in names if n.endswith("nav.xhtml"))
        nav_html = zf.read(nav).decode("utf-8")
        assert 'epub:type="toc"' in nav_html, "EPUB nav TOC missing"
        assert "序章" in nav_html, "nav entries missing"
        nav_link_count = nav_html.count("<a href=")
        assert nav_link_count >= 10, f"nav TOC links too few: {nav_link_count}"

        body_xhtml = sorted(
            n for n in names if n.startswith("EPUB/text/ch") and n.endswith(".xhtml")
        )
        bodies = "".join(zf.read(n).decode("utf-8") for n in body_xhtml)
        assert "序章" in bodies, "body chapters missing"

        toc_chapter = next(
            (n for n in body_xhtml if "目次" in zf.read(n).decode("utf-8")), None
        )
        assert toc_chapter, "body 目次 page missing"
        toc_html = zf.read(toc_chapter).decode("utf-8")
        assert "<h1>目次</h1>" in toc_html or ">目次</h1>" in toc_html, "目次 heading missing"
        toc_body_links = toc_html.count('<a href="')
        assert toc_body_links >= 10, f"body 目次 links too few: {toc_body_links}"
        assert "<ul>" in toc_html and "<li>" in toc_html, "目次 list structure missing"
        # 旧来のリンクなし目次（プレーン li のみ）を検出
        assert "<a href=" in toc_html, "body 目次 must contain anchor links"

        # 付録A/B/C は独立章（h1）として spine に含める
        chapter_html = {n: zf.read(n).decode("utf-8") for n in body_xhtml}
        def has_appendix_h1(html: str, label: str) -> bool:
            return f"<h1>{label}" in html or f'<h1 id="{label.lower()}' in html

        appendix_a = [n for n, h in chapter_html.items() if has_appendix_h1(h, "付録A")]
        appendix_b = [n for n, h in chapter_html.items() if has_appendix_h1(h, "付録B")]
        appendix_c_files = [n for n, h in chapter_html.items() if has_appendix_h1(h, "付録C")]
        assert len(appendix_a) == 1, f"付録A chapter missing: {appendix_a}"
        assert len(appendix_b) == 1, f"付録B chapter missing: {appendix_b}"
        assert len(appendix_c_files) == 1, f"付録C chapter missing: {appendix_c_files}"
        appendix_c = appendix_c_files[0]
        appendix_c_html = zf.read(appendix_c).decode("utf-8")
        assert "<table>" in appendix_c_html, "付録C table missing"
        assert APPENDIX_C_MARKER in appendix_c_html, "付録C person index incomplete"
        assert "付録A" in nav_html and "付録B" in nav_html and "付録C" in nav_html, (
            "appendix entries missing in nav TOC"
        )

        css_name = next(n for n in names if n.endswith(".css"))
        css_text = zf.read(css_name).decode("utf-8")
        if is_vertical:
            assert "vertical-rl" in css_text, "vertical writing-mode missing"
            assert "text-align: left" in css_text, "vertical top-align (left) missing"
            assert "text-orientation: upright" in css_text, "vertical upright orientation missing"
            assert "font-feature-settings" in css_text and "palt" in css_text, (
                "proportional punctuation (palt) missing"
            )
            assert "text-align: justify" not in css_text, (
                "vertical CSS must not use justify (causes bottom alignment)"
            )
            assert ".tcy" in css_text and "-webkit-text-combine" in css_text, (
                "tcy tatechuyoko styles missing"
            )
            assert 'class="tcy"' in bodies, "tcy spans missing in body chapters"
            assert 'title>ch<span class="tcy">' not in bodies, (
                "tcy spans must not be injected into <title>"
            )
            assert "text-combine-upright:" not in re.sub(
                r"/\*.*?\*/", "", css_text, flags=re.DOTALL
            ).split(".tcy", 1)[0], (
                "text-combine-upright must only be used on .tcy spans"
            )
        else:
            assert "vertical-rl" not in css_text.replace("/*", ""), (
                "horizontal CSS must not set vertical-rl"
            )

        if require_cover:
            assert 'properties="cover-image"' in content or "cover-image" in content, (
                "cover image missing in OPF"
            )
        else:
            assert "cover-image" not in content, "cover must not be embedded when disabled"
            assert not any("media/file" in n and n.endswith(".JPG") for n in names), (
                "cover image file must not be bundled"
            )
    size_kb = path.stat().st_size / 1024
    print(f"OK: {path.name} ({size_kb:.1f} KB, {len(names)} entries)")


def main() -> None:
    if not SRC.exists():
        sys.exit(f"Source not found: {SRC}. Run combine_drafts.py first.")

    pandoc = ensure_pandoc()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    cover = COVER if COVER.exists() else None
    if cover:
        print(f"Using cover image: {cover.relative_to(ROOT)}")
    else:
        print("No cover image found; building without cover.")

    # 縦書き EPUB は字ずれ問題のため配布停止（横書きのみ）
    builds = [
        (ASSETS / "style-horizontal.css", OUT_DIR / f"{EPUB_BASENAME}-横書き.epub"),
    ]
    for css, out in builds:
        if not css.exists():
            sys.exit(f"CSS not found: {css}")
        build(pandoc, css, out, src=SRC, cover=cover)
        verify_epub(out, css, require_cover=cover is not None)

    vertical_epub = OUT_DIR / f"{EPUB_BASENAME}-縦書き.epub"
    if vertical_epub.exists():
        vertical_epub.unlink()
        print(f"Removed discontinued: {vertical_epub.name}")

    print(f"\nEPUB files written to {OUT_DIR}")


if __name__ == "__main__":
    main()