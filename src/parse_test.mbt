// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The refusal a document produces, or `None` when it parses.
fn refusal(text : StringView) -> @moonskill.Refused? {
  match @moonskill.faults(text) {
    [@moonskill.Fault::Malformed(refused)] => Some(refused)
    _ => None
  }
}

///|
test "the frontmatter and the body come apart at the fence" {
  let text = "---\nname: my-skill\ndescription: A test skill\n---\n# My Skill\n\nInstructions here.\n"
  let skill = @moonskill.parse(text, root="my-skill")
  assert_eq(skill.name, "my-skill")
  assert_eq(skill.description, "A test skill")
  assert_eq(skill.body, "# My Skill\n\nInstructions here.")
  assert_eq(skill.root, "my-skill")
}

///|
test "the body is trimmed the way the reference reader trims it" {
  let text = "---\nname: my-skill\ndescription: A test skill\n---\n\n\nBody\n\n\n"
  assert_eq(@moonskill.parse(text).body, "Body")
}

///|
test "every frontmatter field is kept" {
  let text = "---\nname: my-skill\ndescription: A test skill\nlicense: Apache-2.0\nmetadata:\n  author: moonbitstack\n  version: \"1.0\"\nallowed-tools: Bash(git:*) Read\n---\nBody\n"
  let skill = @moonskill.parse(text)
  assert_eq(skill.meta.length(), 5)
  assert_eq(skill.license(), Some("Apache-2.0"))
  assert_eq(skill.allowed_tools(), Some("Bash(git:*) Read"))
  assert_eq(
    skill.metadata(),
    Some(Map([("author", "moonbitstack"), ("version", "1.0")])),
  )
}

///|
test "a document without a fence is refused" {
  let message = match refusal("# No frontmatter here") {
    Some(refused) => refused.message()
    None => "<parsed>"
  }
  assert_eq(message, "SKILL.md must start with YAML frontmatter (---)")
}

///|
test "a fence that never closes is refused" {
  let message = match
    refusal("---\nname: my-skill\ndescription: A test skill\n") {
    Some(refused) => refused.message()
    None => "<parsed>"
  }
  assert_eq(message, "SKILL.md frontmatter not properly closed with ---")
}

///|
test "yaml that does not read is refused" {
  let text = "---\nname: [broken\ndescription: broken\n---\nBody\n"
  match refusal(text) {
    Some(@moonskill.BadYaml(reason)) => assert_true(reason.length() > 0)
    Some(other) => fail("expected a YAML refusal, got \{other.message()}")
    None => fail("expected a YAML refusal")
  }
}

///|
test "a frontmatter that is not a mapping is refused" {
  let message = match refusal("---\n- a\n- b\n---\nBody\n") {
    Some(refused) => refused.message()
    None => "<parsed>"
  }
  assert_eq(message, "SKILL.md frontmatter must be a YAML mapping")
}

///|
test "an empty frontmatter is not a mapping" {
  let message = match refusal("---\n---\nBody\n") {
    Some(refused) => refused.message()
    None => "<parsed>"
  }
  assert_eq(message, "SKILL.md frontmatter must be a YAML mapping")
}

///|
test "only the first closing fence counts" {
  let text = "---\nname: my-skill\ndescription: A test skill\n---\nAbove --- below\n"
  assert_eq(@moonskill.parse(text).body, "Above --- below")
}

///|
test "a missing name parses, and validation is what reports it" {
  let skill = @moonskill.parse("---\ndescription: No name.\n---\nBody\n")
  assert_eq(skill.name, "")
  assert_eq(skill.description, "No name.")
}

///|
test "a name that is not text reads as empty" {
  let text = "---\nname:\n  - a\n  - b\ndescription: A test skill\n---\nBody\n"
  assert_eq(@moonskill.parse(text).name, "")
}

///|
test "a name keeps its text whatever it looks like" {
  // StrictYAML reads every scalar as text, so a numeric name is the name
  // "42" rather than a number the specification has no rule for.
  let skill = @moonskill.parse(
    "---\nname: 42\ndescription: A test skill\n---\nBody\n",
    root="42",
  )
  assert_eq(skill.name, "42")
}

///|
test "a description keeps its colons" {
  let text = "---\nname: my-skill\ndescription: \"Use when: a thing happens\"\n---\nBody\n"
  assert_eq(@moonskill.parse(text).description, "Use when: a thing happens")
}

///|
test "a block scalar reads as one string" {
  let text = "---\nname: my-skill\ndescription: |\n  First line.\n  Second line.\n---\nBody\n"
  assert_eq(@moonskill.parse(text).description, "First line.\nSecond line.")
}

///|
test "a duplicate key is refused rather than the last one winning" {
  let text = "---\nname: dup\ndescription: A test skill\nname: dup\n---\nBody\n"
  match refusal(text) {
    Some(@moonskill.BadYaml(_)) => ()
    Some(other) => fail("expected a YAML refusal, got \{other.message()}")
    None => fail("expected a YAML refusal")
  }
}

///|
test "the root is optional" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
  )
  assert_eq(skill.root, "")
  assert_eq(skill.location(), "SKILL.md")
}

///|
test "the location is the document inside the root" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
    root="docs/skills/my-skill",
  )
  assert_eq(skill.location(), "docs/skills/my-skill/SKILL.md")
}

///|
test "the summary is the name and the description" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
  )
  assert_eq(skill.summary(), "my-skill: A test skill")
}

///|
test "a reference inside the skill resolves against its root" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
    root="docs/skills/my-skill",
  )
  assert_eq(
    skill.resolve("references/REFERENCE.md"),
    Some("docs/skills/my-skill/references/REFERENCE.md"),
  )
  assert_eq(
    skill.resolve("./scripts/extract.py"),
    Some("docs/skills/my-skill/scripts/extract.py"),
  )
  assert_eq(
    skill.resolve("assets\\logo.svg"),
    Some("docs/skills/my-skill/assets/logo.svg"),
  )
}

///|
test "a reference that leaves the skill is not a path" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
    root="docs/skills/my-skill",
  )
  assert_eq(skill.resolve("../other-skill/SKILL.md"), None)
  assert_eq(skill.resolve("/etc/passwd"), None)
  assert_eq(skill.resolve("https://agentskills.io"), None)
  assert_eq(skill.resolve("C:\\Windows\\system.ini"), None)
  assert_eq(skill.resolve("   "), None)
}
