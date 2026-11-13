<div align="center">

# moonskill

**Agent Skills for MoonBit.** A skill is a directory with a `SKILL.md`: a name, a
description, and instructions a model reads only when it needs them. This library
reads that format, judges a document against the specification, and hands a model
the one line per skill it needs to choose.

[![mooncakes](https://img.shields.io/badge/mooncakes-moonbitstack%2Fmoonskill-2f6fd0)](https://mooncakes.io/docs/moonbitstack/moonskill)
[![license](https://img.shields.io/badge/license-Apache--2.0-2f6fd0)](LICENSE)

[home](https://moonbitstack.github.io/moonskill/) &middot;
[guide](https://moonbitstack.github.io/moonskill/guide.html) &middot;
[api](https://moonbitstack.github.io/moonskill/api.html) &middot;
[screening](https://moonbitstack.github.io/moonskill/screening.html) &middot;
[mooncakes](https://mooncakes.io/docs/moonbitstack/moonskill)

</div>

## Why

An agent that can be handed tools at runtime needs a way to find out what is
available without paying for all of it up front. Agent Skills answers that with
three tiers: the name and description of every skill, the body of the one skill
the model chose, and the files the body points at when the task reaches them.
`moonskill` is that format in MoonBit, with no opinion about which agent is using
it.

- **Parse** a document with StrictYAML frontmatter, so `name: 42` is the name
  forty-two and a frontmatter that means something other than what it looks like
  is refused rather than guessed.
- **Validate** against every rule the specification states: the length limits,
  the character rules, the directory match, the fields that may appear.
- **Discover** a tree of skills through a `Source` you implement, with a
  directory reader included.
- **Prompt** a model with the metadata tier as an `<available_skills>` block.

## Install

```
moon add moonbitstack/moonskill
```

```
import {
  "moonbitstack/moonskill",
  "moonbitstack/moonskill/fs",
}
```

## Read a document

<!-- nocheck -->
```markdown
---
name: pdf-tools
description: Extract text from PDFs. Use when a task hands you a PDF.
---

# PDF tools

Run `scripts/extract.py` on the file.
```
```mbt check
test {
  let text = "---\nname: pdf-tools\ndescription: Extract text from PDFs.\n---\n# PDF tools\n"
  let skill = @moonskill.parse(text, root="pdf-tools")
  inspect(skill.name, content="pdf-tools")
  inspect(skill.body, content="# PDF tools")
}
```

`parse` is lenient about the fields: a document with no `name` still parses, and
`validate` is what says so. Only a document that is not a skill document — no
fence, YAML that does not read, a frontmatter that is not a mapping — is refused.

## Judge a document

```mbt check
test {
  let text = "---\nname: PDF_Tools\ndescription: Extract text from PDFs.\n---\nBody\n"
  let faults = @moonskill.faults(text, root="pdf-tools")
  inspect(faults.length(), content="3")
  for fault in faults {
    println(fault.kind() + ": " + fault.message())
  }
}
```

```
name-not-lowercase: Skill name 'PDF_Tools' must be lowercase
name-bad-character: Skill name 'PDF_Tools' contains invalid characters. Only letters, digits, and hyphens are allowed.
name-mismatch: Directory name 'pdf-tools' must match skill name 'PDF_Tools'
```

Every fault is reported at once, because a person fixing a document wants the
list rather than the first line. `Fault::kind` returns a tag that does not change
with the wording, for a report read by a program.

## Discover a tree

`@fs` reads the disk, so it is there on the native target only.

```mbt check native
async test {
  let tree = @fs.Dir::at("docs/skills")
  let skills = @moonskill.discover(tree)
  for skill in skills {
    println(skill.summary())
  }
}
```

`discover` reads each skill's document once. A directory that is offered as a
skill but has no document raises rather than being skipped: a model that is told
about a skill it cannot open will use it anyway.

`Source` is the seam. Anything that can list skill roots and read a file can be
one — a tarball, a database, an HTTP cache:

```mbt check
test {
  let skills : Array[@moonskill.Skill] = []
  let block = @moonskill.prompt(skills)
  inspect(block, content="<available_skills>\n</available_skills>")
}
```

## The three tiers

| Tier | What it is | How to read it |
|:--|:--|:--|
| 1 | name and description of every skill | `Skill::summary`, `prompt` |
| 2 | the body of the chosen skill | `Skill::body` |
| 3 | a file the body refers to | `Skill::resolve` then `Source::read` |

```mbt check native
async test {
  let tree = @fs.Dir::at("docs/skills")
  let skills = @moonskill.discover(tree)
  guard skills.length() > 0 else { return }
  let skill = skills[0]
  if skill.resolve("SKILL.md") is Some(path) {
    let bytes = tree.read(path)
    println("\{bytes.length()} bytes")
  }
}
```

`resolve` joins the skill root and refuses a path that climbs out of it, so a
document can point at its own files and nowhere else. Every file inside the skill
is read the same way; the document itself is no exception.

## Check a directory from a command line

```
moon run src/cmd/skillcheck --target native -- docs/skills/moonskill
ok    docs/skills/moonskill
```

```
moon run src/cmd/skillcheck --target native -- docs/skills/broken
FAIL  docs/skills/broken
      - name-not-lowercase: Skill name 'Broken' must be lowercase
```

`--json` prints one object per directory for a program to read. The command exits
non-zero when anything failed, which is what a CI step wants.

## Interface

| Item | Signature |
|:--|:--|
| `parse` | `parse(text : StringView, root? : String) -> Skill raise Refused` |
| `validate` | `validate(skill : Skill, limits~ : Limits = limits) -> Array[Fault]` |
| `faults` | `faults(text : StringView, root? : String, limits~ : Limits = limits) -> Array[Fault]` |
| `discover` | `async discover(source : &Source) -> Array[Skill] raise` |
| `load` | `async load(source : &Source, root~ : String) -> Skill raise` |
| `prompt` | `prompt(skills : ArrayView[Skill]) -> String` |
| `Source` | `async list(Self) -> Array[String] raise`, `async read(Self, path : String) -> Bytes raise` |
| `Skill` | `name`, `description`, `body`, `meta : Map[String, Json]`, `root`, `document` |
| `Skill::summary` | `Skill::summary(Skill) -> String` |
| `Skill::location` | `Skill::location(Skill) -> String` |
| `Skill::resolve` | `Skill::resolve(Skill, StringView) -> String?` |
| `Skill::license` | `Skill::license(Skill) -> String?` |
| `Skill::compatibility` | `Skill::compatibility(Skill) -> String?` |
| `Skill::allowed_tools` | `Skill::allowed_tools(Skill) -> String?` |
| `Skill::metadata` | `Skill::metadata(Skill) -> Map[String, String]?` |
| `Fault` | `message`, `kind` |
| `Limits` | `name`, `description`, `compatibility`, with `limits` as the preset |
| `@fs.Dir` | `Dir::at(StringView) -> Dir`, `Dir::path(Dir) -> String` |
| `@fs.load` | `async load(StringView) -> Skill raise` |
| `@fs.check` | `async check(StringView) -> Array[Fault] raise` |

## Limits

The three lengths the specification fixes are a record, so a client with a smaller
context can hold a skill to a tighter budget:

```mbt check
test {
  let text = "---\nname: my-skill\ndescription: A description long enough to break.\n---\nBody\n"
  let tight : @moonskill.Limits = { name: 64, description: 8, compatibility: 500 }
  inspect(@moonskill.faults(text, root="my-skill", limits=tight).length(), content="1")
}
```

## Conformance

`scripts/conformance/skills/` holds 39 skill directories: one per rule the
specification states, in both directions, plus the shapes that make a document
refuse to parse. The reference validator — `skills-ref` from
[`agentskills/agentskills`](https://github.com/agentskills/agentskills), pinned by
commit — judges the same batch, and
`scripts/conformance/check_reference_parity.py` fails when the two disagree about a
directory, or count a different number of problems in it. The two agree on all 40
directories judged — the 39 cases and this library's own skill — 13 accepted and
27 refused.

The comparison runs in CI, together with `scripts/conformance/gen_corpus.py
--check`, so a case cannot be worded in one place and slide in the other.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
