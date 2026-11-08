// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The vocabulary a report is written in: one tag and one sentence per way a
/// document can be wrong. A tag is what a program matches on, so the list is
/// pinned here — adding a fault without a tag is a change a reader would not see.
test "each fault has its own tag, in the order the vocabulary grew" {
  let faults : Array[@moonskill.Fault] = [
    @moonskill.UnexpectedFields(["owner"]),
    @moonskill.MissingName,
    @moonskill.NameEmpty,
    @moonskill.NameTooLong("a", 65, 64),
    @moonskill.NameNotLowercase("A"),
    @moonskill.NameEdgeHyphen,
    @moonskill.NameDoubleHyphen,
    @moonskill.NameBadCharacter("a_b"),
    @moonskill.NameMismatch("dir", "name"),
    @moonskill.MissingDescription,
    @moonskill.DescriptionEmpty,
    @moonskill.DescriptionTooLong(1025, 1024),
    @moonskill.CompatibilityNotText,
    @moonskill.CompatibilityTooLong(501, 500),
    @moonskill.Malformed(@moonskill.MissingFrontmatter),
    @moonskill.MissingPath("gone"),
    @moonskill.NotADirectory("file.txt"),
    @moonskill.MissingDocument,
  ]
  let tags = faults.map(fault => fault.kind())
  assert_eq(tags, [
    "unexpected-fields", "missing-name", "name-empty", "name-too-long", "name-not-lowercase",
    "name-edge-hyphen", "name-double-hyphen", "name-bad-character", "name-mismatch",
    "missing-description", "description-empty", "description-too-long", "compatibility-not-text",
    "compatibility-too-long", "malformed", "missing-path", "not-a-directory", "missing-document",
  ])
}

///|
/// The sentence is the whole of what a person sees, so it names the value that
/// failed and the limit it failed against.
test "each sentence names what failed and what it failed against" {
  assert_eq(
    @moonskill.NameTooLong("a", 65, 64).message(),
    "Skill name 'a' exceeds 64 character limit (65 chars)",
  )
  assert_eq(
    @moonskill.DescriptionTooLong(1025, 1024).message(),
    "Description exceeds 1024 character limit (1025 chars)",
  )
  assert_eq(
    @moonskill.CompatibilityTooLong(501, 500).message(),
    "Compatibility exceeds 500 character limit (501 chars)",
  )
  assert_eq(
    @moonskill.NameMismatch("skill", "other").message(),
    "Directory name 'skill' must match skill name 'other'",
  )
  assert_eq(
    @moonskill.NameEdgeHyphen.message(),
    "Skill name cannot start or end with a hyphen",
  )
  assert_eq(
    @moonskill.MissingDocument.message(),
    "Missing required file: SKILL.md",
  )
}

///|
/// A malformed document is a fault like any other, and it carries the refusal
/// rather than restating it: a report from a batch and a report from one file
/// word the same cause the same way.
test "a malformed document speaks with the refusal's own sentence" {
  let refused = @moonskill.BadYaml("line 2, column 1: expected a mapping")
  assert_eq(@moonskill.Malformed(refused).message(), refused.message())
  assert_eq(@moonskill.Malformed(refused).kind(), "malformed")
}

///|
/// Fields that do not belong are one fault, sorted, with the six the
/// specification defines named in full.
test "unexpected fields are one fault, sorted, with the allowed six named" {
  let fault = @moonskill.UnexpectedFields(["version", "owner"])
  assert_eq(
    fault.message(),
    "Unexpected fields in frontmatter: version, owner. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed.",
  )
}
