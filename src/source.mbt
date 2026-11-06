// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Where skill documents come from.
///
/// The specification says a skill is a directory, and this is that directory
/// seen as two questions: which skills are here, and what is in this file. A
/// client with skills in a tarball, a database, or an HTTP cache implements the
/// two methods and gets [`discover`], the three-tier loading, and everything
/// else unchanged — nothing above this trait knows what a filesystem is.
///
/// `list` returns skill roots: the directories that hold a document, in the
/// order the client wants them offered to a model. `read` returns the bytes of
/// a path. Both speak of paths with `/` between segments whatever the platform
/// uses, so the same report reads the same everywhere.
pub(open) trait Source {
  /// The skill roots this source offers.
  async fn list(Self) -> Array[String]
  /// The bytes of one file. The path is a skill root from `list` joined with a
  /// relative name, or a root the caller passed to [`load`].
  async fn read(Self, path : String) -> Bytes
}

///|
/// Every skill a source offers, read and parsed.
///
/// A source that lists a directory with no document is a broken source, not an
/// empty one, so `discover` refuses rather than skipping it: silently offering
/// a model a skill it cannot open is how an agent comes to invent a tool it
/// does not have.
pub async fn discover(source : &Source) -> Array[Skill] {
  let roots = source.list()
  let skills = []
  for root in roots {
    skills.push(load(source, root~))
  }
  skills
}

///|
/// One skill, read from the source.
///
/// The document is `SKILL.md`, or `skill.md` for a directory written on a
/// system that folds case, which the specification allows readers to accept.
pub async fn load(source : &Source, root~ : String) -> Skill {
  let bytes = match try_read(source, join_path(root, "SKILL.md")) {
    Some(bytes) => bytes
    None =>
      match try_read(source, join_path(root, "skill.md")) {
        Some(bytes) => bytes
        None => raise Refused::NoDocument
      }
  }
  let text = @utf8.decode(bytes, ignore_bom=false) catch {
    @utf8.Malformed(rest) =>
      raise Refused::NotUtf8(bytes.length() - rest.length())
  }
  parse(text, root~)
}

///|
/// `read` with the error kept as a value, so a caller can decide what a failure
/// means instead of guessing from a raised error it cannot inspect.
async fn try_read(source : &Source, path : String) -> Bytes? {
  match (Ok(source.read(path)) catch { error => Err(error) }) {
    Ok(bytes) => Some(bytes)
    Err(_) => None
  }
}
