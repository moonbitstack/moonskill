// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A directory of skills built for one test. Everything it creates is under the
/// system temporary directory, so a test run leaves the repository alone.
struct Tree {
  root : String
}

///|
async fn Tree::new(name : String) -> Tree {
  let root = @aiofs.tmpdir(prefix="moonskill-\{name}")
  { root, }
}

///|
async fn Tree::close(self : Tree) -> Unit {
  @aiofs.rmdir(self.root, recursive=true)
}

///|
async fn Tree::write(self : Tree, path : String, text : String) -> Unit {
  let full = @moonskill.join_path(self.root, path)
  if full.rev_find("/") is Some(index) {
    @aiofs.mkdir(full[:index], recursive=true, allow_exist=true)
  }
  @aiofs.write_file(full, text)
}

///|
async fn Tree::dir(self : Tree, name : String) -> String {
  let full = @moonskill.join_path(self.root, name)
  @aiofs.mkdir(full, recursive=true, allow_exist=true)
  full
}

///|
async test "a tree offers the directories that hold a document" {
  let tree = Tree::new("list")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write(
    "alpha/SKILL.md", "---\nname: alpha\ndescription: The first.\n---\nBody\n",
  )
  tree.write(
    "beta/skill.md", "---\nname: beta\ndescription: The second.\n---\nBody\n",
  )
  tree.write("notes/README.md", "# not a skill\n")
  let _ = tree.dir("empty")
  let skills = @moonskill.discover(@fs.Dir::at(tree.root))
  assert_eq(skills.length(), 2)
  assert_eq(skills[0].name, "alpha")
  assert_eq(skills[1].name, "beta")
  assert_eq(skills[0].root, @moonskill.join_path(tree.root, "alpha"))
}

///|
async test "a skill on disk is read with its root set to its directory" {
  let tree = Tree::new("load")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write(
    "my-skill/SKILL.md", "---\nname: my-skill\ndescription: A test skill\n---\n# My Skill\n",
  )
  let skill = @fs.load(@moonskill.join_path(tree.root, "my-skill"))
  assert_eq(skill.name, "my-skill")
  assert_eq(skill.body, "# My Skill")
  assert_eq(@moonskill.validate(skill), [])
}

///|
async test "the third tier is read off the same tree" {
  let tree = Tree::new("reference")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write(
    "deep/SKILL.md", "---\nname: deep\ndescription: A test skill\n---\nSee references/REFERENCE.md.\n",
  )
  tree.write("deep/references/REFERENCE.md", "# Reference\n")
  let dir = @fs.Dir::at(tree.root)
  let skills = @moonskill.discover(dir)
  let path = skills[0].resolve("references/REFERENCE.md").unwrap()
  let bytes = @moonskill.Source::read(dir, path)
  assert_eq(@utf8.decode(bytes), "# Reference\n")
}

///|
async test "a path with nothing at it is one fault" {
  let tree = Tree::new("missing")
  defer @async.protect_from_cancel(() => tree.close())
  let absent = @moonskill.join_path(tree.root, "nowhere")
  assert_eq(@fs.check(absent), [@moonskill.MissingPath(absent)])
}

///|
async test "a file where a skill directory should be is one fault" {
  let tree = Tree::new("file")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write("file.txt", "text")
  let path = @moonskill.join_path(tree.root, "file.txt")
  assert_eq(@fs.check(path), [@moonskill.NotADirectory(path)])
}

///|
async test "a directory with no document is one fault" {
  let tree = Tree::new("nodoc")
  defer @async.protect_from_cancel(() => tree.close())
  let path = tree.dir("empty")
  assert_eq(@fs.check(path), [@moonskill.MissingDocument])
}

///|
async test "a document that does not parse is one fault" {
  let tree = Tree::new("broken")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write("broken/SKILL.md", "# no frontmatter\n")
  let path = @moonskill.join_path(tree.root, "broken")
  let faults = @fs.check(path)
  assert_eq(faults.length(), 1)
  assert_eq(faults[0].kind(), "malformed")
  assert_eq(
    faults[0].message(),
    "SKILL.md must start with YAML frontmatter (---)",
  )
}

///|
async test "a document that parses is judged against its directory" {
  let tree = Tree::new("judge")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write(
    "wrong-dir/SKILL.md", "---\nname: my-skill\ndescription: A test skill\n---\nBody\n",
  )
  let path = @moonskill.join_path(tree.root, "wrong-dir")
  assert_eq(@fs.check(path), [@moonskill.NameMismatch("wrong-dir", "my-skill")])
}

///|
async test "a skill that follows the specification has no faults, read from disk" {
  let tree = Tree::new("valid")
  defer @async.protect_from_cancel(() => tree.close())
  tree.write(
    "my-skill/SKILL.md", "---\nname: my-skill\ndescription: A test skill\nlicense: Apache-2.0\nmetadata:\n  author: moonbitstack\n---\n# My Skill\n",
  )
  let path = @moonskill.join_path(tree.root, "my-skill")
  assert_eq(@fs.check(path), [])
}
