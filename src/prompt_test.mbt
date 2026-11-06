// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "no skills is an empty block" {
  assert_eq(@moonskill.prompt([]), "<available_skills>\n</available_skills>")
}

///|
test "one skill is one entry, name and description and where it lives" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
    root="skills/my-skill",
  )
  let expected = "<available_skills>\n<skill>\n<name>\nmy-skill\n</name>\n<description>\nA test skill\n</description>\n<location>\nskills/my-skill/SKILL.md\n</location>\n</skill>\n</available_skills>"
  assert_eq(@moonskill.prompt([skill]), expected)
}

///|
test "the block keeps the order the caller gave" {
  let first = @moonskill.parse(
    "---\nname: first\ndescription: The first.\n---\nBody\n",
  )
  let second = @moonskill.parse(
    "---\nname: second\ndescription: The second.\n---\nBody\n",
  )
  let block = @moonskill.prompt([first, second])
  assert_true(
    block.find("first") is Some(i1) &&
    block.find("second") is Some(i2) &&
    i1 < i2,
  )
}

///|
test "a description may quote markup without closing the element" {
  let skill = @moonskill.parse(
    "---\nname: my-skill\ndescription: \"Use when the task needs <table> & other tags, or 'quotes'\"\n---\nBody\n",
  )
  let block = @moonskill.prompt([skill])
  assert_true(block.contains("&lt;table&gt;"))
  assert_true(block.contains("&amp; other tags"))
  assert_true(block.contains("&#x27;quotes&#x27;"))
  assert_false(block.contains("<table>"))
}
