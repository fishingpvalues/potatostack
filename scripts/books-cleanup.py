#!/usr/bin/env python3
"""Clean books library for Kavita scanning.

Actions:
  1. Rename Anna's Archive files → "Author - Title.ext"
  2. Move non-book utility files in Science_Fiction → _utilities/
  3. Move root-level books into appropriate category folders
  4. Merge Fiction/Thriller → Fiction/Thrillers
"""

import re
import shutil
import sys
from pathlib import Path

BOOKS_ROOT = Path("/mnt/storage/media/books")

# Keyword → category for root-level book categorization
ROOT_CATEGORIES = {
    "tchaikovsky": "Fiction/Science_Fiction",
    "corey":       "Fiction/Science_Fiction",
    "quran":       "Non_Fiction",
    "aeneid":      "Fiction/Classics",
    "sokrates":    "Fiction/Classics",
    "bibel":       "Fiction/Classics",
    "gedichte":    "Fiction/Classics",
    "bible":       "Fiction/Classics",
    "mcfadden":    "Fiction/Thrillers",
    "moore":       "Fiction/Thrillers",
}

BOOK_EXTS = {".epub", ".pdf", ".mobi", ".lit", ".fb2", ".cbz", ".cbr", ".cb7"}
UTIL_EXTS = {".py", ".ps1", ".sh", ".exe", ".json", ".md", ".html", ".csv"}


# ── Anna's Archive parsing ──────────────────────────────────────────────────

def clean_underscores(s: str) -> str:
    """Decode Anna's Archive underscore escaping."""
    s = re.sub(r" _ ", ": ", s)                          # " _ " → ": "
    s = re.sub(r"_(?=\s|$|[,;])", "", s)                 # trailing underscore on words
    s = re.sub(r"(?<=[A-Z])_(?=[A-Z])", ".", s)          # C_H_ → C.H.
    s = s.replace("_", " ")
    return re.sub(r" +", " ", s).strip()


def fix_case(name: str) -> str:
    """Title-case an ALL-CAPS name."""
    letters = [c for c in name if c.isalpha()]
    if letters and sum(1 for c in letters if c.isupper()) / len(letters) > 0.75:
        return name.title()
    return name


def parse_author(field: str) -> str:
    """Extract and clean first author from Anna's Archive author field."""
    first = field.split(";")[0].strip()
    first = re.sub(r",\s*(editor-in-chief|ed\.|editor|compiler).*$", "", first, flags=re.I)
    first = re.sub(r"\s*-\s*undifferentiated.*$", "", first)
    first = clean_underscores(first)
    first = fix_case(first)
    # "Last, First" → "First Last"
    m = re.match(r"^([^,]+),\s+(.+)$", first)
    if m:
        first = f"{m.group(2).strip()} {m.group(1).strip()}"
    return first.strip()


def parse_title(field: str) -> str:
    """Clean title field from Anna's Archive."""
    title = clean_underscores(field)
    words = []
    for w in title.split():
        letters = [c for c in w if c.isalpha()]
        if letters and len(letters) > 2 and all(c.isupper() for c in letters):
            words.append(w.title())
        else:
            words.append(w)
    return " ".join(words).strip()


def safe_filename(s: str, max_len: int = 110) -> str:
    """Strip unsafe characters and limit length."""
    s = re.sub(r'[/\\:*?"<>|]', "", s)
    s = re.sub(r"\s+", " ", s).strip()
    if len(s) > max_len:
        s = s[:max_len].rsplit(" ", 1)[0].rstrip(" -,")
    return s


def is_anna_archive(name: str) -> bool:
    stem = Path(name).stem
    # Anna's Archive uses U+2019 curly apostrophe, not ASCII '
    return " -- " in stem and bool(re.search(r"Anna[\u2019']?s?\s+Archi", stem, re.I))


def parse_anna_archive(filepath: Path):
    """Return (author, title, ext) or None."""
    ext = filepath.suffix
    stem = filepath.stem
    stem = re.sub(r"\s*--\s*Anna[\u2019']?s?\s*Archi(?:ve)?$", "", stem, flags=re.I)
    stem = re.sub(r"\s*--\s*[0-9a-f]{32}$", "", stem, flags=re.I)

    parts = [p.strip() for p in stem.split(" -- ")]
    if len(parts) < 2:
        return None

    title = parse_title(parts[0])
    author = parse_author(parts[1])
    return author, title, ext


# ── Actions ─────────────────────────────────────────────────────────────────

def rename_anna_files(dry_run: bool) -> None:
    print("=== 1. Renaming Anna's Archive files ===")
    count = 0
    for f in sorted(BOOKS_ROOT.rglob("*")):
        if not f.is_file() or not is_anna_archive(f.name):
            continue
        result = parse_anna_archive(f)
        if not result:
            print(f"  SKIP (unparseable): {f.name[:80]}")
            continue
        author, title, ext = result
        new_stem = f"{author} - {title}" if author else title
        new_stem = safe_filename(new_stem)
        new_name = new_stem + ext
        new_path = f.parent / new_name

        if new_path == f:
            continue  # already clean

        if new_path.exists():
            new_path = f.parent / (new_stem + "_alt" + ext)

        rel = str(f.relative_to(BOOKS_ROOT))
        print(f"  {rel[:70]}")
        print(f"    → {new_name}")
        count += 1
        if not dry_run:
            f.rename(new_path)

    print(f"  Total: {count} renames\n")


def move_root_books(dry_run: bool) -> None:
    print("=== 2. Moving root-level books to category folders ===")
    count = 0
    for f in sorted(BOOKS_ROOT.iterdir()):
        if not f.is_file() or f.suffix.lower() not in BOOK_EXTS:
            continue
        name_lower = f.name.lower()
        dest_cat = None
        for kw, cat in ROOT_CATEGORIES.items():
            if kw in name_lower:
                dest_cat = cat
                break
        if not dest_cat:
            print(f"  LEAVE (no match): {f.name[:70]}")
            continue
        dest = BOOKS_ROOT / dest_cat / f.name
        print(f"  {f.name[:60]} → {dest_cat}/")
        count += 1
        if not dry_run:
            dest.parent.mkdir(parents=True, exist_ok=True)
            f.rename(dest)
    print(f"  Total: {count} moves\n")


def move_scifi_utilities(dry_run: bool) -> None:
    scifi = BOOKS_ROOT / "Fiction/Science_Fiction"
    utils = scifi / "_utilities"
    extracted = scifi / "Extracted_Text"

    util_files = [f for f in scifi.iterdir() if f.is_file() and f.suffix.lower() in UTIL_EXTS]

    if not util_files and not extracted.exists():
        return

    print("=== 3. Moving Science_Fiction utility files → _utilities/ ===")
    if not dry_run:
        utils.mkdir(exist_ok=True)

    for f in sorted(util_files):
        print(f"  {f.name}")
        if not dry_run:
            shutil.move(str(f), str(utils / f.name))

    if extracted.exists():
        n = len(list(extracted.rglob("*")))
        print(f"  Extracted_Text/ ({n} items)")
        if not dry_run:
            utils.mkdir(exist_ok=True)
            shutil.move(str(extracted), str(utils / "Extracted_Text"))

    print()


def merge_thriller(dry_run: bool) -> None:
    t1 = BOOKS_ROOT / "Fiction/Thriller"
    t2 = BOOKS_ROOT / "Fiction/Thrillers"
    if not (t1.exists() and t2.exists()):
        return

    print("=== 4. Merging Fiction/Thriller → Fiction/Thrillers ===")
    for f in sorted(t1.iterdir()):
        print(f"  {f.name}")
        if not dry_run:
            shutil.move(str(f), str(t2 / f.name))
    if not dry_run:
        t1.rmdir()
    print()


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    dry_run = "--apply" not in sys.argv
    mode = "[DRY RUN]" if dry_run else "[APPLYING]"
    print(f"{mode} Books library cleanup for Kavita")
    print(f"Root: {BOOKS_ROOT}\n")

    rename_anna_files(dry_run)
    move_root_books(dry_run)
    move_scifi_utilities(dry_run)
    merge_thriller(dry_run)

    if dry_run:
        print("Dry run complete. Run with --apply to execute all changes.")
    else:
        print("Done. Trigger a Kavita library scan to pick up changes.")


if __name__ == "__main__":
    main()
