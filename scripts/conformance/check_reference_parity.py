#!/usr/bin/env python3
"""Compare this library's verdict with the reference validator's, case by case.

Two validators are only as good as their disagreements are rare, so the CI job
runs both over the same batch of skill directories and fails when one accepts a
directory the other refuses, or when they count a different number of problems.
The corpus is written by `gen_corpus.py` next to this file.

The reference is `skills-ref` from `agentskills/agentskills`, pinned by commit in
the workflow; run this with it on PATH.
"""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
CORPUS = REPO / "scripts" / "conformance" / "skills"
OWN_SKILL = REPO / "docs" / "skills" / "moonskill"


def run(argv: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, cwd=str(cwd), capture_output=True, text=True)


def our_verdicts(directories: list[Path]) -> dict[str, dict]:
    """One record per directory, from the command line this library ships."""
    result = run(
        [
            "moon",
            "run",
            "src/cmd/skillcheck",
            "--target",
            "native",
            "--",
            "--json",
        ]
        + [str(directory) for directory in directories],
        REPO,
    )
    records: dict[str, dict] = {}
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        record = json.loads(line)
        records[str(Path(record["path"]).resolve())] = record
    missing = [
        str(directory)
        for directory in directories
        if str(directory.resolve()) not in records
    ]
    if missing:
        print(
            "the command line reported nothing for: "
            + ", ".join(missing)
            + f"\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    return records


def reference_verdict(directory: Path, command: list[str]) -> tuple[bool, int]:
    """Whether the reference accepts the directory, and how many problems it lists."""
    result = run([*command, "validate", str(directory)], REPO)
    if result.returncode == 0:
        return True, 0
    if result.returncode == 1:
        problems = [
            line for line in result.stderr.splitlines() if line.startswith("  - ")
        ]
        return False, max(1, len(problems))
    print(
        f"the reference could not judge {directory} (exit {result.returncode}):\n"
        f"{result.stderr}",
        file=sys.stderr,
    )
    raise SystemExit(2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skills-ref",
        default="skills-ref",
        help="the reference validator, as a command line (default: skills-ref)",
    )
    args = parser.parse_args()
    reference = shlex.split(args.skills_ref)

    directories = sorted(entry for entry in CORPUS.iterdir() if entry.is_dir())
    if not directories:
        print("the corpus is empty", file=sys.stderr)
        return 2
    if OWN_SKILL.is_dir():
        directories = directories + [OWN_SKILL]

    ours = our_verdicts(directories)
    rows = []
    disagreements = []
    for directory in directories:
        reference_ok, reference_count = reference_verdict(directory, reference)
        record = ours[str(directory.resolve())]
        our_ok = bool(record["valid"])
        our_count = len(record["faults"])
        rows.append((directory.name, reference_ok, reference_count, our_ok, our_count))
        if reference_ok != our_ok or reference_count != our_count:
            disagreements.append(
                f"{directory.name}: reference "
                f"{'accepts' if reference_ok else 'refuses'} ({reference_count}), "
                f"we {'accept' if our_ok else 'refuse'} ({our_count})"
            )

    width = max(len(row[0]) for row in rows)
    for name, reference_ok, reference_count, our_ok, our_count in rows:
        print(
            f"{name:<{width}}  reference {'ok  ' if reference_ok else 'fail'} {reference_count:>2}"
            f"   we {'ok  ' if our_ok else 'fail'} {our_count:>2}"
            f"{'' if reference_ok == our_ok and reference_count == our_count else '   <-- differs'}"
        )

    accepted = sum(1 for row in rows if row[1])
    print(
        f"\n{len(rows)} cases, {len(rows) - len(disagreements)} agree "
        f"({accepted} accepted, {len(rows) - accepted} refused)"
    )
    if disagreements:
        print("\ndisagreements:", file=sys.stderr)
        for line in disagreements:
            print(f"  {line}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
