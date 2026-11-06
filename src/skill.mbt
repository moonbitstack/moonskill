// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A skill document: the frontmatter the specification defines, the Markdown
/// an agent reads when the skill is activated, and the directory it came from.
///
/// The specification loads a skill in three tiers, and the fields follow them:
/// [`Skill::summary`] is the tier a client reads for every skill it knows
/// about, `body` is the tier it reads once the skill is chosen, and the files
/// the body points at are read one at a time through [`reference`] when the
/// task reaches them.
pub(all) struct Skill {
  /// The `name` field, trimmed. Empty when the frontmatter has none, or when
  /// it is not text.
  name : String
  /// The `description` field, trimmed. Empty when the frontmatter has none.
  description : String
  /// The Markdown after the frontmatter, trimmed at both ends.
  body : String
  /// The whole frontmatter, so a client reads fields this library does not
  /// name — `license`, `metadata`, `allowed-tools` — and so [`validate`] can
  /// judge the text as written rather than as trimmed.
  meta : Map[String, Json]
  /// The skill directory as given to [`parse`], or as returned by a
  /// [`Source`]. Empty means there is no directory to check the name against.
  root : String
}

///|
/// The metadata tier: what a client puts in front of a model before the model
/// has chosen anything, which the specification budgets at about a hundred
/// tokens per skill. One line, so a list of them stays a list.
pub fn Skill::summary(self : Skill) -> String {
  if self.description == "" {
    self.name
  } else if self.name == "" {
    self.description
  } else {
    "\{self.name}: \{self.description}"
  }
}

///|
/// The path of the document, which is what a client hands back to the model so
/// it can open the skill if it wants the body.
pub fn Skill::location(self : Skill) -> String {
  if self.root == "" {
    "SKILL.md"
  } else {
    join_path(self.root, "SKILL.md")
  }
}

///|
/// The `license` field, or `None` when it is absent or not text.
pub fn Skill::license(self : Skill) -> String? {
  self.text_of("license")
}

///|
/// The `compatibility` field, or `None` when it is absent or not text.
pub fn Skill::compatibility(self : Skill) -> String? {
  self.text_of("compatibility")
}

///|
/// The experimental `allowed-tools` field, or `None`.
pub fn Skill::allowed_tools(self : Skill) -> String? {
  self.text_of("allowed-tools")
}

///|
/// The `metadata` mapping as text, or `None` when it is absent. The
/// specification defines it as string keys to string values; a value that is
/// not text is skipped rather than turned into JSON spelling.
pub fn Skill::metadata(self : Skill) -> Map[String, String]? {
  guard self.meta.get("metadata") is Some(Object(fields)) else { return None }
  let out = Map([])
  for key, value in fields {
    if value is String(text) {
      out[key] = text
    }
  }
  Some(out)
}

///|
fn Skill::text_of(self : Skill, key : String) -> String? {
  match self.meta.get(key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
/// The path of a file the body refers to, resolved against the skill root, or
/// `None` when the reference is not a file inside this skill.
///
/// This is how the third tier is read: the body says `references/REFERENCE.md`,
/// the model asks for that file, and the client fetches it from the same
/// [`Source`] the skill came from. A reference that climbs out of the directory
/// — `../other-skill/SKILL.md`, an absolute path, a URL — is `None` rather than
/// a path: a skill may point at its own files and nowhere else.
pub fn Skill::resolve(self : Skill, path : StringView) -> String? {
  let raw = path.trim()
  if raw == "" || raw.has_prefix("/") || raw.has_prefix("\\") {
    return None
  }
  let segments = []
  for segment in raw.replace_all(old="\\", new="/").split("/") {
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." || segment.contains(":") {
      return None
    }
    segments.push(segment)
  }
  if segments.length() == 0 {
    return None
  }
  Some(join_path(self.root, segments.join("/")))
}

///|
/// `a` and `b` with exactly one `/` between them, whichever slashes either
/// already carries.
///
/// Paths are joined here rather than with the platform's separator: a skill
/// root is a key in a [`Source`], and a key that reads the same on every system
/// is the one a report can be compared against.
pub fn join_path(a : StringView, b : StringView) -> String {
  let head = a.to_owned()
  let mut end = head.length()
  while end > 0 && (head[end - 1] == '/' || head[end - 1] == '\\') {
    end = end - 1
  }
  if end == 0 {
    return b.to_owned()
  }
  "\{head[:end]}/\{b}"
}

///|
/// The last segment of a path, which is the directory name the specification
/// compares a skill's `name` against.
pub fn base_name(path : StringView) -> String {
  let text = path.to_owned()
  let mut end = text.length()
  while end > 0 && (text[end - 1] == '/' || text[end - 1] == '\\') {
    end = end - 1
  }
  let mut start = end
  while start > 0 && text[start - 1] != '/' && text[start - 1] != '\\' {
    start = start - 1
  }
  text[start:end].to_owned()
}
