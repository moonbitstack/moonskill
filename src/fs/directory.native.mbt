// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A directory of skills on disk, seen as a [`Source`](moonbitstack/moonskill).
///
/// The tree the specification describes is one directory per skill, each with a
/// `SKILL.md`; a directory of skills — `docs/skills` in a repository — is
/// therefore a `Dir` whose children are the skills. Paths handed back by
/// [`Dir::list`] are built with `/` on every platform, so a report of a tree
/// reads the same on all three systems the tests run on.
pub(all) struct Dir {
  dir : String
}

///|
/// The tree rooted at `path`.
pub fn Dir::at(path : StringView) -> Dir {
  { dir: path.to_owned(), }
}

///|
/// The root this tree was opened at.
pub fn Dir::path(self : Dir) -> String {
  self.dir
}

///|
pub impl @moonskill.Source for Dir with fn list(self) {
  let roots = []
  for name in @aiofs.readdir(self.dir) {
    let path = join(self.dir, name)
    if @aiofs.kind(path) == @aiofs.Directory && document_of(path) is Some(_) {
      roots.push(path)
    }
  }
  // Path order, not the shortlex order `Compare` gives strings: a report of a
  // tree reads in the order a person reads a directory listing.
  roots.sort_by((a, b) => a.lexical_compare(b))
  roots
}

///|
pub impl @moonskill.Source for Dir with fn read(_self, path) {
  // The path already names the file: `list` joins the root, and a reference
  // inside a skill goes through `Skill::resolve`, which joins it too. Joining
  // again here would read `docs/skills/docs/skills/...`.
  (@aiofs.read_file(path) : &@aio.Data).binary()
}

///|
/// The two methods as methods, so a value of this type reads as the tree it is.
pub extend Dir with @moonskill.Source::{list, read}

///|
/// One skill from a directory.
///
/// Raises when the directory holds no document, or when the document is not
/// readable as one: a caller that wants to carry on past a broken skill uses
/// [`check`], which reports the same trouble as a fault.
pub async fn load(path : StringView) -> @moonskill.Skill {
  let tree = Dir::at(path)
  @moonskill.load(tree, root=tree.dir)
}

///|
/// Every fault in the skill at `path`, judged as a directory rather than as a
/// document that already parsed.
///
/// This is the check a repository runs over `docs/skills/` in CI: it covers the
/// three things that can go wrong before a document is read — nothing at the
/// path, a file where a directory should be, no document inside — and then the
/// specification's rules about what the document says.
pub async fn check(path : StringView) -> Array[@moonskill.Fault] {
  let root = path.to_owned()
  if !@aiofs.exists(root) {
    return [@moonskill.MissingPath(root)]
  }
  if @aiofs.kind(root) != @aiofs.Directory {
    return [@moonskill.NotADirectory(root)]
  }
  let document = match document_of(root) {
    Some(document) => document
    None => return [@moonskill.MissingDocument]
  }
  let bytes = (@aiofs.read_file(document) : &@aio.Data).binary()
  let text = @utf8.decode(bytes, ignore_bom=false) catch {
    @utf8.Malformed(rest) =>
      return [
        @moonskill.Malformed(@moonskill.NotUtf8(bytes.length() - rest.length())),
      ]
  }
  @moonskill.faults(text, root~)
}

///|
/// The document inside a skill directory: `SKILL.md`, or `skill.md` for a
/// directory written on a system that folds case.
async fn document_of(root : String) -> String? {
  let upper = join(root, "SKILL.md")
  if @aiofs.exists(upper) {
    return Some(upper)
  }
  let lower = join(root, "skill.md")
  if @aiofs.exists(lower) {
    return Some(lower)
  }
  None
}

///|
fn join(a : StringView, b : StringView) -> String {
  @moonskill.join_path(a, b)
}
