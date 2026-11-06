---
name: moonskill
description: Read, validate and discover Agent Skills (SKILL.md directories) from MoonBit. Use when a MoonBit program must load skill documents, judge a SKILL.md against the Agent Skills specification, or put the skill names and descriptions in front of a model.
---

# moonskill

A skill is a directory holding a `SKILL.md`: YAML frontmatter with a `name` and a
`description`, then a Markdown body an agent reads only after it has chosen the
skill. This library reads that format. It does not know which agent is reading.

## Install

```
moon add moonbitstack/moonskill
```

## Check a document before shipping it

```mbt check
test {
  let text = "---\nname: pdf-tools\ndescription: Extract text from PDFs.\n---\nBody\n"
  let faults = @moonskill.faults(text, root="pdf-tools")
  inspect(faults.length(), content="0")
}
```

`faults` parses and judges in one call. `root` is the directory the document came
from: the specification wants the directory name to equal `name`, so a check
without it says less than it could. A document that does not parse comes back as
one fault of kind `malformed` rather than as an error, which is what lets a batch
be checked in one pass.

## Load every skill in a tree

```mbt check
async test {
  let tree = @fs.Dir::at("docs/skills")
  let skills = @moonskill.discover(tree)
  for skill in skills {
    println(skill.summary())
  }
}
```

## Put the names in front of a model

```mbt check
test {
  let skills : Array[@moonskill.Skill] = []
  inspect(@moonskill.prompt(skills), content="<available_skills>\n</available_skills>")
}
```

## Rules that are easy to get wrong

- `parse` does not enforce the field rules; `validate` does. Parsing refuses only
  a document that is not a skill document at all: no fence, YAML that does not
  read, a frontmatter that is not a mapping.
- Every scalar in the frontmatter is text, so `name: 42` is the name `42`.
  Quoting it changes nothing.
- A name is lowercase letters, digits and hyphens — in any script — with no two
  hyphens in a row and no hyphen at either end. The directory must match the name
  after Unicode composition, so `café` written either way is one name.
- `description` is capped at 1024 characters and `compatibility` at 500. Both are
  in `@moonskill.limits`; pass a `Limits` record to hold a skill to less.
- Nothing here opens a file by itself. `@fs.Dir` is the reader you get; implement
  `Source` to keep skills in a tarball, a database or a cache.
- In a package of your own, an `async test` that calls `discover` needs
  `import { "moonbitlang/async" } for "test"` as well.
