// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A source over a map of path to bytes: the smallest thing that satisfies the
/// contract, which is the point of the contract — a client that keeps skills
/// anywhere at all gets discovery, parsing and the three tiers unchanged.
struct Memory {
  files : Map[String, Bytes]
}

///|
impl @moonskill.Source for Memory with fn list(self) {
  // A skill root is a directory that holds a document; a file next to the
  // document is not a skill of its own.
  let roots = []
  for path, _ in self.files {
    let root = match path.rev_find("/") {
      Some(index) => path[:index].to_owned()
      None => ""
    }
    if root == "" || roots.contains(root) {
      continue
    }
    if self.files.contains("\{root}/SKILL.md") ||
      self.files.contains("\{root}/skill.md") {
      roots.push(root)
    }
  }
  roots.sort()
  roots
}

///|
impl @moonskill.Source for Memory with fn read(self, path) {
  match self.files.get(path) {
    Some(bytes) => bytes
    None => fail("no such file: \{path}")
  }
}

///|
fn memory(entries : Array[(String, String)]) -> Memory {
  let files = Map([])
  for entry in entries {
    files[entry.0] = @utf8.encode(entry.1)
  }
  { files, }
}

///|
async test "discovery reads every skill a source offers" {
  let source = memory([
    (
      "skills/first/SKILL.md", "---\nname: first\ndescription: The first.\n---\nBody one.\n",
    ),
    (
      "skills/second/SKILL.md", "---\nname: second\ndescription: The second.\n---\nBody two.\n",
    ),
  ])
  let skills = @moonskill.discover(source)
  assert_eq(skills.length(), 2)
  assert_eq(skills[0].name, "first")
  assert_eq(skills[0].root, "skills/first")
  assert_eq(skills[1].body, "Body two.")
}

///|
async test "a lowercase document is read like an uppercase one" {
  let source = memory([
    (
      "skills/lower/skill.md", "---\nname: lower\ndescription: Written on a folding system.\n---\nBody\n",
    ),
  ])
  let skills = @moonskill.discover(source)
  assert_eq(skills[0].name, "lower")
}

///|
async test "a skill directory without a document is refused, not skipped" {
  let source = memory([("skills/empty/README.md", "# nothing\n")])
  let refused = try {
    let _ = @moonskill.load(source, root="skills/empty")
    false
  } catch {
    @moonskill.Refused::NoDocument => true
    _ => false
  }
  assert_true(refused)
}

///|
async test "bytes that are not UTF-8 are refused with the offset" {
  let source = {
    files: Map([
      (
        "skills/broken/SKILL.md",
        Bytes::from_array([0x2d, 0x2d, 0x2d, 0x0a, 0xff]),
      ),
    ]),
  }
  let refusal = try {
    let _ = @moonskill.load(source, root="skills/broken")
    None
  } catch {
    @moonskill.Refused::NotUtf8(at) => Some(at)
    _ => None
  }
  assert_eq(refusal, Some(4))
}

///|
async test "the third tier is a file read on demand" {
  let source = memory([
    (
      "skills/deep/SKILL.md", "---\nname: deep\ndescription: A skill with a reference.\n---\nSee references/REFERENCE.md.\n",
    ),
    ("skills/deep/references/REFERENCE.md", "# Reference\n"),
  ])
  let skills = @moonskill.discover(source)
  let skill = skills[0]
  // The first tier is what a model sees before it chooses.
  assert_eq(skill.summary(), "deep: A skill with a reference.")
  // The second tier is the body, which names a file rather than containing it.
  assert_true(skill.body.contains("references/REFERENCE.md"))
  let path = skill.resolve("references/REFERENCE.md").unwrap()
  let text = @utf8.decode(@moonskill.Source::read(source, path))
  assert_eq(text, "# Reference\n")
}

///|
async test "discovery over an empty source is empty" {
  let source = memory([])
  assert_eq(@moonskill.discover(source).length(), 0)
}

///|
/// The document a skill was read from is part of the skill, because the path a
/// client hands a model has to name a file that is there. A source keyed by path
/// is where the two names stay apart: on a filesystem that folds case they are
/// one file and no reader can tell them apart.
async test "a skill remembers the document it was read under" {
  let lower = memory([
    (
      "skills/lower/skill.md", "---\nname: lower\ndescription: Written on a folding system.\n---\nBody\n",
    ),
  ])
  let skill = @moonskill.load(lower, root="skills/lower")
  assert_eq(skill.document, "skill.md")
  assert_eq(skill.location(), "skills/lower/skill.md")
}

///|
/// Both names in one directory is one skill read from the capital one, which is
/// the order the specification prefers.
async test "the capital name wins when a source offers both" {
  let both = memory([
    (
      "skills/both/SKILL.md", "---\nname: both\ndescription: The capital one.\n---\nBody\n",
    ),
    (
      "skills/both/skill.md", "---\nname: both\ndescription: The lower one.\n---\nBody\n",
    ),
  ])
  let skill = @moonskill.load(both, root="skills/both")
  assert_eq(skill.description, "The capital one.")
  assert_eq(skill.document, "SKILL.md")
}
