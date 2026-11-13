#!/usr/bin/env python3
"""Hold this library and the reference implementation to the same answers.

Three questions are asked of every directory in the corpus, and the two
implementations have to answer each one the same way:

1. does it pass, and if not, how many problems does it have;
2. which sentences does it report, in the order it reports them;
3. what are the fields of its header.

The fourth question is about the corpus as a whole: the `<available_skills>`
block, byte for byte. That block is the one artifact that leaves this library and
enters a client, so it is the one worth comparing as text rather than as a list
of fields.

The corpus is written by `gen_corpus.py` next to this file; the reference is
`skills-ref` from `agentskills/agentskills`, pinned by commit in the workflow.
Run this with it on PATH. The numbers this prints are the ones the README states,
and a README that has drifted from the run is a failure too.
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
CORPUS = REPO / "scripts" / "conformance" / "skills"
OWN_SKILL = REPO / "docs" / "skills" / "moonskill"
README = REPO / "README.md"

# The reference reads its YAML with one library and this one with another, and the
# two explain a syntax error in their own words. What a caller matches on is the
# sentence before the explanation, so that is what is compared.
YAML_PREFIX = "Invalid YAML in frontmatter: "


def run(argv: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, cwd=str(cwd), capture_output=True, text=True)


def ours(command: list[str], arguments: list[str], what: str) -> str:
    """One run of this library's command line, and its stdout."""
    result = run(
        ["moon", "run", "src/cmd/skillcheck", "--target", "native", "--", *command]
        + arguments,
        REPO,
    )
    if result.returncode not in (0, 1):
        print(
            f"the command line could not {what} (exit {result.returncode}):\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    return result.stdout


def our_verdicts(directories: list[Path]) -> dict[str, dict]:
    """One record per directory, keyed by its resolved path."""
    records: dict[str, dict] = {}
    stdout = ours(["validate", "--json"], [str(d) for d in directories], "judge")
    for line in stdout.splitlines():
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
            "the command line reported nothing for: " + ", ".join(missing),
            file=sys.stderr,
        )
        raise SystemExit(2)
    return records


def our_properties(directories: list[Path]) -> list[dict]:
    """The header of each directory, in the order the command line was given them."""
    stdout = ours(["read-properties"], [str(d) for d in directories], "read a header")
    lines = [line for line in stdout.splitlines() if line.strip().startswith("{")]
    if len(lines) != len(directories):
        print(
            f"asked for {len(directories)} headers, got {len(lines)}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    return [json.loads(line) for line in lines]


def reference_verdict(directory: Path, command: list[str]) -> tuple[bool, list[str]]:
    """Whether the reference accepts the directory, and the problems it lists."""
    result = run([*command, "validate", str(directory)], REPO)
    if result.returncode == 0:
        return True, []
    if result.returncode == 1:
        problems = [
            line[4:] for line in result.stderr.splitlines() if line.startswith("  - ")
        ]
        return False, problems or ["<refused without a reason>"]
    print(
        f"the reference could not judge {directory} (exit {result.returncode}):\n"
        f"{result.stderr}",
        file=sys.stderr,
    )
    raise SystemExit(2)


def reference_properties(directory: Path, command: list[str]) -> dict | None:
    result = run([*command, "read-properties", str(directory)], REPO)
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def reference_prompt(directories: list[Path], command: list[str]) -> str:
    result = run([*command, "to-prompt", *[str(d) for d in directories]], REPO)
    if result.returncode != 0:
        print(
            f"the reference could not build the block (exit {result.returncode}):\n"
            f"{result.stderr}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    return result.stdout.rstrip("\n")


def comparable(message: str) -> str:
    if message.startswith(YAML_PREFIX):
        return YAML_PREFIX + "<the reader's own explanation>"
    return message


def readme_faults(cases: int, accepted: int, refused: int) -> list[str]:
    """The numbers the README states, held to the numbers this run produced."""
    text = README.read_text(encoding="utf-8")
    faults = []
    counted = re.search(r"holds (\d+) skill directories", text)
    if not counted:
        faults.append("the README no longer says how many directories the corpus holds")
    elif int(counted.group(1)) != cases:
        faults.append(
            f"the README says the corpus holds {counted.group(1)} directories, "
            f"it holds {cases}"
        )
    judged = re.search(r"(\d+) accepted and (\d+) refused", text)
    if not judged:
        faults.append("the README no longer says how many were accepted and refused")
    elif (int(judged.group(1)), int(judged.group(2))) != (accepted, refused):
        faults.append(
            f"the README says {judged.group(1)} accepted and {judged.group(2)} refused, "
            f"this run says {accepted} accepted and {refused} refused"
        )
    return faults


def compare_block(mine: str, theirs: str) -> str | None:
    if mine == theirs:
        return None
    my_lines, their_lines = mine.splitlines(), theirs.splitlines()
    index = next(
        (
            index
            for index, (a, b) in enumerate(zip(my_lines, their_lines))
            if a != b
        ),
        min(len(my_lines), len(their_lines)),
    )
    where = index + 1
    their_line = their_lines[index] if index < len(their_lines) else "<nothing>"
    my_line = my_lines[index] if index < len(my_lines) else "<nothing>"
    return (
        f"the offered block differs at line {where}: "
        f"reference {their_line!r}, we {my_line!r}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skills-ref",
        default="skills-ref",
        help="the reference validator, as a command line (default: skills-ref)",
    )
    args = parser.parse_args()
    reference = shlex.split(args.skills_ref)

    cases = sorted(entry for entry in CORPUS.iterdir() if entry.is_dir())
    if not cases:
        print("the corpus is empty", file=sys.stderr)
        return 2
    directories = cases + ([OWN_SKILL] if OWN_SKILL.is_dir() else [])

    ours_by_path = our_verdicts(directories)
    verdicts: list[tuple[Path, bool, list[str], bool, list[str]]] = []
    refused_ours: list[str] = []
    for directory in directories:
        accepted, problems = reference_verdict(directory, reference)
        record = ours_by_path[str(directory.resolve())]
        our_problems = [fault["message"] for fault in record["faults"]]
        verdicts.append(
            (directory, accepted, problems, bool(record["valid"]), our_problems)
        )

    width = max(len(row[0].name) for row in verdicts)
    for directory, accepted, problems, our_valid, our_problems in verdicts:
        flagged = accepted != our_valid or len(problems) != len(our_problems)
        print(
            f"{directory.name:<{width}}  reference {'ok  ' if accepted else 'fail'} "
            f"{len(problems):>2}   we {'ok  ' if our_valid else 'fail'} "
            f"{len(our_problems):>2}{'   <-- differs' if flagged else ''}"
        )
        if not flagged:
            for theirs, mine in zip(problems, our_problems):
                if comparable(theirs) != comparable(mine):
                    refused_ours.append(
                        f"{directory.name}: reference says {theirs!r}, we say {mine!r}"
                    )

    disagreements: list[str] = []
    for directory, accepted, problems, our_valid, our_problems in verdicts:
        if accepted != our_valid:
            disagreements.append(
                f"{directory.name}: reference "
                f"{'accepts' if accepted else 'refuses'}, we "
                f"{'accept' if our_valid else 'refuse'}"
            )
        elif len(problems) != len(our_problems):
            disagreements.append(
                f"{directory.name}: reference lists {len(problems)} problems, "
                f"we list {len(our_problems)}"
            )
    disagreements.extend(refused_ours)

    accepted_paths = [row[0] for row in verdicts if row[1]]
    header_disagreements: list[str] = []
    for directory, our_header in zip(accepted_paths, our_properties(accepted_paths)):
        theirs = reference_properties(directory, reference)
        if theirs is None:
            header_disagreements.append(
                f"{directory.name}: the reference read no header, we read "
                f"{json.dumps(our_header, ensure_ascii=False)}"
            )
        elif theirs != our_header:
            header_disagreements.append(
                f"{directory.name}: reference header "
                f"{json.dumps(theirs, ensure_ascii=False)} != ours "
                f"{json.dumps(our_header, ensure_ascii=False)}"
            )

    our_block = ours(
        ["to-prompt"], [str(path) for path in accepted_paths], "build the block"
    ).rstrip("\n")
    block_disagreement = compare_block(
        our_block, reference_prompt(accepted_paths, reference)
    )

    total = len(verdicts)
    accepted = len(accepted_paths)
    refused = total - accepted
    readme = readme_faults(len(cases), accepted, refused)

    print(
        f"\n{total} documents judged: {accepted} accepted, {refused} refused — "
        f"{total - len(disagreements)} agree on the verdict"
    )
    print(
        f"{accepted} headers compared, "
        f"{accepted - len(header_disagreements)} equal"
    )
    print(
        f"the offered block, {len(our_block.splitlines())} lines: "
        f"{'identical' if block_disagreement is None else 'differs'}"
    )

    problems = disagreements + header_disagreements + readme
    if block_disagreement:
        problems.append(block_disagreement)
    if problems:
        print("\ndisagreements:", file=sys.stderr)
        for line in problems:
            print(f"  {line}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
