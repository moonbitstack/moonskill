#!/usr/bin/env python3
"""Write the conformance corpus: one directory per case, each a skill on disk.

The corpus is the same batch of directories that `scripts/check_reference_parity.py`
hands to the reference validator and to this library, so a case that one of them
accepts and the other refuses is a case the CI job can name. The files are
committed; this script only exists so a case can be added or reworded in one
place, and so CI can prove the committed copy matches it.

Run with `--check` to compare instead of write.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "skills"

NO_DOCUMENT = None

# A case whose document is named in lower case, which the specification allows a
# reader to accept. Only one case needs it: the rest are `SKILL.md`, and a corpus
# written on a system that folds case would otherwise never contain the other
# spelling at all.
LOWERCASE_DOCUMENT = {"lower-document"}

# (directory name, document text or NO_DOCUMENT, what the case is about)
CASES: list[tuple[str, str | None, str]] = [
    (
        "valid-minimal",
        "---\nname: valid-minimal\ndescription: A minimal skill.\n---\n# Title\n\nBody.\n",
        "the two required fields and nothing else",
    ),
    (
        "valid-full",
        "---\nname: valid-full\ndescription: A full skill.\nlicense: Apache-2.0\n"
        "compatibility: Requires nothing\nmetadata:\n  author: moonbitstack\n  version: \"1.0\"\n"
        "allowed-tools: Bash(git:*) Read\n---\nBody\n",
        "every optional field the specification defines",
    ),
    (
        "no-document",
        NO_DOCUMENT,
        "a directory that is not a skill",
    ),
    (
        "lower-document",
        "---\nname: lower-document\ndescription: Written on a folding system.\n---\nBody\n",
        "the document named in lower case",
    ),
    (
        "name-upper",
        "---\nname: NameUpper\ndescription: An upper case name.\n---\nBody\n",
        "a name with an upper case letter",
    ),
    (
        "a" * 64,
        "---\nname: " + "a" * 64 + "\ndescription: Exactly the limit.\n---\nBody\n",
        "a name at the length limit",
    ),
    (
        "name-65",
        "---\nname: " + "a" * 65 + "\ndescription: One over the limit.\n---\nBody\n",
        "a name one character over the length limit",
    ),
    (
        "-name-leading",
        "---\nname: -name-leading\ndescription: A leading hyphen.\n---\nBody\n",
        "a name that starts with a hyphen",
    ),
    (
        "name-trailing-",
        "---\nname: name-trailing-\ndescription: A trailing hyphen.\n---\nBody\n",
        "a name that ends with a hyphen",
    ),
    (
        "name--double",
        "---\nname: name--double\ndescription: Consecutive hyphens.\n---\nBody\n",
        "a name with two hyphens in a row",
    ),
    (
        "name_underscore",
        "---\nname: name_underscore\ndescription: An underscore.\n---\nBody\n",
        "a name with an underscore",
    ),
    (
        "name space",
        "---\nname: name space\ndescription: A space.\n---\nBody\n",
        "a name with a space",
    ),
    (
        "dir-mismatch",
        "---\nname: other-name\ndescription: The directory disagrees.\n---\nBody\n",
        "a name that is not the directory name",
    ),
    (
        "extra-field",
        "---\nname: extra-field\ndescription: A key the specification does not define.\nversion: 1.0\n---\nBody\n",
        "a frontmatter key outside the specification",
    ),
    (
        "extra-fields",
        "---\nname: extra-fields\ndescription: Two keys outside the specification.\nowner: someone\nversion: 1.0\n---\nBody\n",
        "two such keys, reported together",
    ),
    (
        "name-missing",
        "---\ndescription: No name.\n---\nBody\n",
        "frontmatter with no name",
    ),
    (
        "name-blank",
        "---\nname: \"\"\ndescription: A blank name.\n---\nBody\n",
        "an empty name",
    ),
    (
        "name-spaces",
        "---\nname: \"   \"\ndescription: A name of spaces.\n---\nBody\n",
        "a name that is only spaces",
    ),
    (
        "desc-missing",
        "---\nname: desc-missing\n---\nBody\n",
        "frontmatter with no description",
    ),
    (
        "desc-empty",
        "---\nname: desc-empty\ndescription: \"\"\n---\nBody\n",
        "an empty description",
    ),
    (
        "desc-1024",
        "---\nname: desc-1024\ndescription: " + "x" * 1024 + "\n---\nBody\n",
        "a description at the length limit",
    ),
    (
        "desc-1025",
        "---\nname: desc-1025\ndescription: " + "x" * 1025 + "\n---\nBody\n",
        "a description one character over the limit",
    ),
    (
        "compat-500",
        "---\nname: compat-500\ndescription: A compatibility note at the limit.\ncompatibility: "
        + "x" * 500
        + "\n---\nBody\n",
        "a compatibility note at the length limit",
    ),
    (
        "compat-501",
        "---\nname: compat-501\ndescription: A compatibility note over the limit.\ncompatibility: "
        + "x" * 501
        + "\n---\nBody\n",
        "a compatibility note one character over the limit",
    ),
    (
        "compat-list",
        "---\nname: compat-list\ndescription: A compatibility note that is not text.\ncompatibility:\n  - one\n---\nBody\n",
        "a compatibility note written as a list",
    ),
    (
        "技能",
        "---\nname: 技能\ndescription: A name in Chinese.\n---\nBody\n",
        "a name in a script other than Latin",
    ),
    (
        "cjk-upper",
        "---\nname: 技能A\ndescription: A name with a Latin capital.\n---\nBody\n",
        "a Chinese name with an upper case letter",
    ),
    (
        "навык",
        "---\nname: навык\ndescription: A name in Cyrillic.\n---\nBody\n",
        "a Cyrillic name in lower case",
    ),
    (
        "ru-upper",
        "---\nname: НАВЫК\ndescription: A name in capitals.\n---\nBody\n",
        "a Cyrillic name in capitals",
    ),
    (
        "caf\u00e9",
        "---\nname: cafe\u0301\ndescription: The decomposed spelling.\n---\nBody\n",
        "a name whose characters compose to the directory name",
    ),
    (
        "no-frontmatter",
        "# Just Markdown\n\nNo fence, no frontmatter.\n",
        "a document that does not open with the fence",
    ),
    (
        "unclosed",
        "---\nname: unclosed\ndescription: Never closed.\n",
        "a fence that never closes",
    ),
    (
        "bad-yaml",
        "---\nname: [broken\ndescription: Not YAML.\n---\nBody\n",
        "frontmatter that is not YAML",
    ),
    (
        "list-frontmatter",
        "---\n- a\n- b\n---\nBody\n",
        "frontmatter that is a sequence",
    ),
    (
        "empty-frontmatter",
        "---\n---\nBody\n",
        "frontmatter that is empty",
    ),
    (
        "duplicate-key",
        "---\nname: duplicate-key\ndescription: A key written twice.\nname: duplicate-key\n---\nBody\n",
        "a key written twice",
    ),
    (
        "body-fence",
        "---\nname: body-fence\ndescription: The body mentions a fence.\n---\nAbove --- below\n",
        "a body that contains three hyphens",
    ),
    (
        "42",
        "---\nname: 42\ndescription: A name that looks like a number.\n---\nBody\n",
        "a name that reads as a number in a typed YAML",
    ),
    (
        "description-colon",
        "---\nname: description-colon\ndescription: \"Use when: a task needs it\"\n---\nBody\n",
        "a quoted description with a colon",
    ),
]


def expected_directories() -> dict[str, str | None]:
    return {name: document for name, document, _ in CASES}


def main() -> int:
    check = "--check" in sys.argv[1:]
    ROOT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name_case, document, _note in CASES:
        name = name_case
        directory = ROOT / name
        if document is NO_DOCUMENT:
            wanted = {directory / "README.md": "# Not a skill\n"}
        else:
            name = "skill.md" if name_case in LOWERCASE_DOCUMENT else "SKILL.md"
            wanted = {directory / name: document}
        for file, text in wanted.items():
            if check:
                if not file.exists() or file.read_text(encoding="utf-8") != text:
                    stale.append(str(file))
                continue
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(text, encoding="utf-8", newline="\n")
    known = expected_directories()
    present = sorted(entry.name for entry in ROOT.iterdir() if entry.is_dir())
    unknown = [name for name in present if name not in known]
    if unknown:
        print("corpus has directories no case describes: " + ", ".join(unknown), file=sys.stderr)
        return 1
    if check:
        if stale:
            print("corpus is out of date: " + ", ".join(stale), file=sys.stderr)
            return 1
        print(f"corpus is up to date: {len(CASES)} cases")
        return 0
    print(f"wrote {len(CASES)} cases under {ROOT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
