"""Write the corpus the screening page offers as one JavaScript module.

The page loads a case by name and hands its text to the compiled library, so the module only has to
carry the text. It is generated rather than typed so a page cannot quote a case the corpus no longer
holds; `docs/engine/` is ignored by git and built by the docs workflow.

Usage: python scripts/gen_demo_cases.py
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "scripts" / "conformance" / "skills"
OUT = ROOT / "docs" / "engine" / "cases.js"


def main():
    cases = []
    for directory in sorted(CORPUS.iterdir()):
        if not directory.is_dir():
            continue
        document = directory / "SKILL.md"
        if not document.exists():
            document = directory / "skill.md"
        if not document.exists():
            continue
        cases.append({"dir": directory.name, "text": document.read_text(encoding="utf-8")})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    body = json.dumps(cases, ensure_ascii=False, indent=0, separators=(",", ":"))
    OUT.write_text(f"export const cases = {body};\n", encoding="utf-8", newline="\n")
    print(f"docs/engine/cases.js: {len(cases)} cases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
