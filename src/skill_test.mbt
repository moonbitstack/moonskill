// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The metadata tier degrades to whichever half exists. A document can parse
/// with neither field, and the line a model reads should still be one line
/// rather than the punctuation between two empty strings.
test "the summary is whichever half the document has" {
  let description_only = @moonskill.parse(
    "---\ndescription: A skill with no name.\n---\nBody\n",
  )
  assert_eq(description_only.summary(), "A skill with no name.")
  let name_only = @moonskill.parse("---\nname: my-skill\n---\nBody\n")
  assert_eq(name_only.summary(), "my-skill")
  let neither = @moonskill.parse("---\ndescription: \"\"\n---\nBody\n")
  assert_eq(neither.summary(), "")
}

///|
/// A document parsed from text has no directory, so the location is the
/// document's own name; the third tier resolves against the empty root instead
/// of producing a leading slash.
test "a skill with no root still has a location and a reference" {
  let skill = @moonskill.parse("---\nname: my-skill\n---\nBody\n")
  assert_eq(skill.location(), "SKILL.md")
  assert_eq(
    skill.resolve("references/REFERENCE.md"),
    Some("references/REFERENCE.md"),
  )
}

///|
/// A field the specification says is text is only text when it is text. A list
/// of allowed tools written as a YAML list, a metadata block written as a
/// string, a compatibility note written as a number: each reads as absent,
/// because the alternative is a caller matching on JSON shape.
test "a field of the wrong shape reads as absent" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A skill.\nallowed-tools:\n  - Read\n  - Write\nmetadata: not-a-mapping\ncompatibility:\n  - native\n---\nBody\n",
  )
  assert_eq(skill.allowed_tools(), None)
  assert_eq(skill.metadata(), None)
  assert_eq(skill.compatibility(), None)
}

///|
/// Paths are joined for a report, not for a platform: the same root with a
/// trailing slash, a backslash or neither produces one key.
test "joining a path leaves exactly one separator, whatever the root carries" {
  assert_eq(@moonskill.join_path("skills/a", "SKILL.md"), "skills/a/SKILL.md")
  assert_eq(@moonskill.join_path("skills/a/", "SKILL.md"), "skills/a/SKILL.md")
  assert_eq(@moonskill.join_path("skills/a\\", "SKILL.md"), "skills/a/SKILL.md")
  assert_eq(@moonskill.join_path("", "SKILL.md"), "SKILL.md")
  assert_eq(@moonskill.join_path("/", "SKILL.md"), "SKILL.md")
}

///|
/// The directory name a skill is compared against is the last segment, and a
/// trailing separator does not make it empty.
test "the base name is the last segment, with or without a trailing slash" {
  assert_eq(@moonskill.base_name("skills/pdf-tools"), "pdf-tools")
  assert_eq(@moonskill.base_name("skills/pdf-tools/"), "pdf-tools")
  assert_eq(@moonskill.base_name("skills\\pdf-tools\\"), "pdf-tools")
  assert_eq(@moonskill.base_name("pdf-tools"), "pdf-tools")
}

///|
/// `Debug` is what a test snapshot and a debugger print, so a skill is a value
/// that has one, document included.
test "a skill prints its fields, including the document it came from" {
  let skill = @moonskill.parse(
    "---\nname: pdf-tools\ndescription: Extract text.\n---\nBody\n",
  )
  let printed = skill.to_repr().to_string()
  assert_true(printed.contains("pdf-tools"))
  assert_true(printed.contains("SKILL.md"))
}

///|
/// A limit set is a value a test reads the boundary from, so it prints too.
test "a limit set prints its three numbers" {
  let printed = @moonskill.limits.to_repr().to_string()
  assert_true(printed.contains("64"))
  assert_true(printed.contains("1024"))
}
