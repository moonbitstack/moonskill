"""Fill the numbers the site states from the source that decides them.

A page must not carry a version or a count typed by hand: the version lives in `moon.mod`, the
header fields in `validate.mbt`, the fault tags in `fault.mbt`. This rewrites the marked span and
the marked counts in `docs/*.html` in place; CI runs it again and fails on a difference.

Usage: python scripts/gen_site_data.py [--check]
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
SRC = ROOT / "src"


def version():
    text = (ROOT / "moon.mod").read_text(encoding="utf-8")
    return re.search(r'version\s*=\s*"([^"]+)"', text).group(1)


def packages():
    count = 0
    for pkg in sorted(SRC.rglob("moon.pkg")):
        rel = pkg.parent.relative_to(SRC).as_posix()
        if rel != "." and {"examples", "cmd", "snippet_check", "snippet_probe"} & set(rel.split("/")):
            continue
        count += 1
    return count


def header_fields():
    text = (SRC / "validate.mbt").read_text(encoding="utf-8")
    body = text.split("fn is_allowed_field", 1)[1]
    return len(re.findall(r'key\s*==\s*"([^"]+)"', body.split("\nfn ", 1)[0]))


def fault_tags():
    text = (SRC / "fault.mbt").read_text(encoding="utf-8")
    body = text.split("pub fn Fault::kind", 1)[1].split("\n}", 1)[0]
    return len(re.findall(r'=>\s*"[a-z-]+"', body))


COUNTS = {
    "packages": packages,
    "fields": header_fields,
    "faults": fault_tags,
}


def rewrite(text, values):
    text = re.sub(
        r'(<span data-version>)[^<]*(</span>)',
        lambda m: f"{m.group(1)}{values['version']}{m.group(2)}",
        text,
    )
    for key, number in values.items():
        if key == "version":
            continue
        text = re.sub(
            rf'(<span class="n" data-count="{key}">)[^<]*(</span>)',
            lambda m, n=number: f"{m.group(1)}{n}{m.group(2)}",
            text,
        )
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    values = {"version": version()}
    for key, read in COUNTS.items():
        values[key] = read()

    stale = []
    for page in sorted(DOCS.glob("*.html")):
        before = page.read_text(encoding="utf-8")
        after = rewrite(before, values)
        if before == after:
            continue
        if args.check:
            stale.append(page.name)
        else:
            page.write_text(after, encoding="utf-8", newline="\n")
    if args.check:
        if stale:
            print("out of date: " + ", ".join(stale) + " — run python scripts/gen_site_data.py")
            return 1
        print("docs: " + ", ".join(f"{k} {v}" for k, v in values.items()) + " — up to date")
        return 0
    print("docs: " + ", ".join(f"{k} {v}" for k, v in values.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
