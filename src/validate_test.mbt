// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A skill named `name`, in a directory of the same name.
fn skill_in(root : String, frontmatter : String) -> @moonskill.Skill raise {
  @moonskill.parse("\{frontmatter}", root~)
}

///|
fn faults_of(
  root : String,
  frontmatter : String,
) -> Array[@moonskill.Fault] raise {
  @moonskill.validate(skill_in(root, frontmatter))
}

///|
test "a skill that follows the specification has no faults" {
  let text = "---\nname: my-skill\ndescription: A test skill\nlicense: Apache-2.0\ncompatibility: Requires nothing\nmetadata:\n  author: moonbitstack\n---\nBody\n"
  assert_eq(faults_of("my-skill", text), [])
}

///|
test "a field the specification does not define is one fault, listing them all" {
  let faults = faults_of(
    "my-skill", "---\nname: my-skill\ndescription: A test skill\nversion: 1.0\nowner: someone\n---\nBody\n",
  )
  assert_eq(faults, [@moonskill.UnexpectedFields(["owner", "version"])])
  assert_eq(
    faults[0].message(),
    "Unexpected fields in frontmatter: owner, version. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed.",
  )
}

///|
test "a missing name is reported as missing, not as empty" {
  assert_eq(faults_of("my-skill", "---\ndescription: No name.\n---\nBody\n"), [
    @moonskill.MissingName,
  ])
}

///|
test "a blank name is reported as empty" {
  assert_eq(
    faults_of(
      "my-skill", "---\nname: \"  \"\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameEmpty],
  )
}

///|
test "a name of exactly the limit passes and one character more does not" {
  let longest = String::make(64, 'a')
  assert_eq(
    faults_of(
      longest,
      "---\nname: \{longest}\ndescription: A test skill\n---\nBody\n",
    ),
    [],
  )
  let longer = String::make(65, 'a')
  assert_eq(
    faults_of(
      longer,
      "---\nname: \{longer}\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameTooLong(longer, 65, 64)],
  )
}

///|
test "an uppercase name is a fault" {
  assert_eq(
    faults_of(
      "NameUpper", "---\nname: NameUpper\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameNotLowercase("NameUpper")],
  )
}

///|
test "a hyphen at either end is a fault" {
  assert_eq(
    faults_of(
      "-leading", "---\nname: -leading\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameEdgeHyphen],
  )
  assert_eq(
    faults_of(
      "trailing-", "---\nname: trailing-\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameEdgeHyphen],
  )
}

///|
test "two hyphens in a row are a fault" {
  assert_eq(
    faults_of(
      "two--hyphens", "---\nname: two--hyphens\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameDoubleHyphen],
  )
}

///|
test "a character that is neither letter, digit nor hyphen is a fault" {
  assert_eq(
    faults_of(
      "an_underscore", "---\nname: an_underscore\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameBadCharacter("an_underscore")],
  )
  assert_eq(
    faults_of(
      "a space", "---\nname: a space\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameBadCharacter("a space")],
  )
}

///|
test "a name in a script other than Latin is a name" {
  assert_eq(
    faults_of(
      "技能", "---\nname: 技能\ndescription: A test skill\n---\nBody\n",
    ),
    [],
  )
  assert_eq(
    faults_of(
      "навык", "---\nname: навык\ndescription: A test skill\n---\nBody\n",
    ),
    [],
  )
  assert_eq(
    faults_of(
      "НАВЫК", "---\nname: НАВЫК\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameNotLowercase("НАВЫК")],
  )
}

///|
test "the directory and the name must agree" {
  assert_eq(
    faults_of(
      "other-name", "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
    ),
    [@moonskill.NameMismatch("other-name", "my-skill")],
  )
}

///|
test "when there is no directory, there is nothing to disagree with" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
  )
  assert_eq(@moonskill.validate(skill), [])
}

///|
test "endings that compose to the same name are the same name" {
  // `cafe` plus a combining acute is `café` written the other way round. A
  // directory named with the composed form must still match.
  let decomposed = "cafe\u{0301}"
  let faults = faults_of(
    "café",
    "---\nname: \{decomposed}\ndescription: A test skill\n---\nBody\n",
  )
  assert_eq(faults, [])
}

///|
test "a missing description is reported as missing, not as empty" {
  assert_eq(faults_of("my-skill", "---\nname: my-skill\n---\nBody\n"), [
    @moonskill.MissingDescription,
  ])
}

///|
test "an empty description is a fault even when a name is fine" {
  assert_eq(
    faults_of("my-skill", "---\nname: my-skill\ndescription: \"\"\n---\nBody\n"),
    [@moonskill.DescriptionEmpty],
  )
}

///|
test "a description of exactly the limit passes and one character more does not" {
  let longest = String::make(1024, 'x')
  assert_eq(
    faults_of(
      "my-skill",
      "---\nname: my-skill\ndescription: \{longest}\n---\nBody\n",
    ),
    [],
  )
  let longer = String::make(1025, 'x')
  assert_eq(
    faults_of(
      "my-skill",
      "---\nname: my-skill\ndescription: \{longer}\n---\nBody\n",
    ),
    [@moonskill.DescriptionTooLong(1025, 1024)],
  )
}

///|
test "a compatibility note of exactly the limit passes and one character more does not" {
  let longest = String::make(500, 'x')
  assert_eq(
    faults_of(
      "my-skill",
      "---\nname: my-skill\ndescription: A test skill\ncompatibility: \{longest}\n---\nBody\n",
    ),
    [],
  )
  let longer = String::make(501, 'x')
  assert_eq(
    faults_of(
      "my-skill",
      "---\nname: my-skill\ndescription: A test skill\ncompatibility: \{longer}\n---\nBody\n",
    ),
    [@moonskill.CompatibilityTooLong(501, 500)],
  )
}

///|
test "a compatibility note that is not text is a fault" {
  assert_eq(
    faults_of(
      "my-skill", "---\nname: my-skill\ndescription: A test skill\ncompatibility:\n  - a\n---\nBody\n",
    ),
    [@moonskill.CompatibilityNotText],
  )
}

///|
test "every fault is reported, in the order the frontmatter is read" {
  let text = "---\nname: Bad_Name\ndescription: \"\"\ncompatibility: \{String::make(501, 'x')}\nversion: 1.0\n---\nBody\n"
  assert_eq(faults_of("bad-name", text), [
    @moonskill.UnexpectedFields(["version"]),
    @moonskill.NameNotLowercase("Bad_Name"),
    @moonskill.NameBadCharacter("Bad_Name"),
    @moonskill.NameMismatch("bad-name", "Bad_Name"),
    @moonskill.DescriptionEmpty,
    @moonskill.CompatibilityTooLong(501, 500),
  ])
}

///|
test "a client may hold a skill to a tighter budget" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
  )
  let tight : @moonskill.Limits = {
    name: 64,
    description: 4,
    compatibility: 500,
  }
  assert_eq(@moonskill.validate(skill, limits=tight), [
    @moonskill.DescriptionTooLong(12, 4),
  ])
  assert_eq(@moonskill.limits.description, 1024)
}

///|
test "the tag of a fault does not change with its wording" {
  assert_eq(@moonskill.MissingName.kind(), "missing-name")
  assert_eq(@moonskill.NameEdgeHyphen.kind(), "name-edge-hyphen")
  assert_eq(@moonskill.Fault::MissingDocument.kind(), "missing-document")
}

///|
/// Hyphens are allowed in any script: the rule is about the character, not about
/// the alphabet it belongs to, and a name that is two words in Russian joins them
/// the way a name in Latin does.
test "a name in another script may carry hyphens" {
  assert_eq(
    faults_of(
      "мой-навык", "---\nname: мой-навык\ndescription: A test skill\n---\nBody\n",
    ),
    [],
  )
}
