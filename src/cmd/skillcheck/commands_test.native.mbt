// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The directory a skill is in, whichever of the two paths a person typed.
test "a document names the directory that holds it" {
  assert_eq(directory_of("skills/pdf-tools/SKILL.md"), "skills/pdf-tools")
  assert_eq(directory_of("skills/pdf-tools/skill.md"), "skills/pdf-tools")
  assert_eq(directory_of("skills/pdf-tools"), "skills/pdf-tools")
  assert_eq(directory_of("skills/pdf-tools/"), "skills/pdf-tools/")
  assert_eq(directory_of("SKILL.md"), ".")
  assert_eq(directory_of("dir\\SKILL.md"), "dir")
}

///|
/// The JSON a program reads: the path, whether it passed, and each fault with
/// the tag that does not change and the sentence that does.
test "a verdict carries the path, the pass and the faults" {
  let faults = @moonskill.faults(
    "---\nname: Bad_Name\ndescription: A test skill.\n---\nBody\n",
    root="bad-name",
  )
  let expected = @json.parse(
    "{\"path\":\"bad-name\",\"valid\":false,\"faults\":[{\"kind\":\"name-not-lowercase\",\"message\":\"Skill name 'Bad_Name' must be lowercase\"},{\"kind\":\"name-bad-character\",\"message\":\"Skill name 'Bad_Name' contains invalid characters. Only letters, digits, and hyphens are allowed.\"},{\"kind\":\"name-mismatch\",\"message\":\"Directory name 'bad-name' must match skill name 'Bad_Name'\"}]}",
  )
  assert_eq(verdict_json("bad-name", false, faults), expected)
  assert_eq(
    verdict_json("bad-name", true, []),
    @json.parse("{\"path\":\"bad-name\",\"valid\":true,\"faults\":[]}"),
  )
}

///|
/// A skill that carries every optional field: each one appears under the name
/// the specification gives it, `allowed-tools` with its hyphen.
test "the properties are the fields the specification defines" {
  let skill = @moonskill.parse(
    "---\nname: pdf-tools\ndescription: Extract text.\nlicense: Apache-2.0\ncompatibility: Needs nothing\nallowed-tools: Read\nmetadata:\n  author: moonbitstack\n---\nBody\n",
  )
  let expected = @json.parse(
    "{\"name\":\"pdf-tools\",\"description\":\"Extract text.\",\"license\":\"Apache-2.0\",\"compatibility\":\"Needs nothing\",\"allowed-tools\":\"Read\",\"metadata\":{\"author\":\"moonbitstack\"}}",
  )
  assert_eq(properties_json(skill), expected)
}

///|
/// A field the document does not have is not in the object: a reader that wants
/// to tell "absent" from "empty" asks the key.
test "an optional field the document lacks is left out" {
  let skill = @moonskill.parse(
    "---\nname: pdf-tools\ndescription: Extract text.\n---\nBody\n",
  )
  assert_eq(
    properties_json(skill),
    @json.parse("{\"name\":\"pdf-tools\",\"description\":\"Extract text.\"}"),
  )
}
