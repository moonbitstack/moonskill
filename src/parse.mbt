// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Read a skill document.
///
/// The document opens with a `---` fence, then YAML, then a closing `---`, then
/// the Markdown body. The YAML is read as StrictYAML, the dialect the
/// specification was written against: every scalar is text, so `name: 42` is
/// the name forty-two rather than a number, and a frontmatter that means
/// something other than what it looks like is refused instead of guessed.
///
/// `root` is the directory the document came from. [`validate`] compares the
/// directory name with the skill name, and [`Skill::location`] needs it to
/// name the document; leave it out when the text has no directory yet.
///
/// Reading is lenient about the fields themselves: a document with no `name`
/// still parses, and [`validate`] says what is wrong with it. Only a document
/// that is not a skill document at all is refused.
pub fn parse(text : StringView, root? : String) -> Skill raise Refused {
  let root = root.unwrap_or("")
  guard text.length() >= 3 && text[0] == '-' && text[1] == '-' && text[2] == '-' else {
    raise Refused::MissingFrontmatter
  }
  let close = match find_fence(text, 3) {
    Some(index) => index
    None => raise Refused::UnclosedFrontmatter
  }
  let frontmatter = text[3:close]
  let body = text[close + 3:].trim().to_owned()
  let document = @strict.loads(frontmatter) catch {
    error => raise Refused::BadYaml(error.to_string())
  }
  let fields = match document {
    Object(fields) => fields
    _ => raise Refused::NotAMapping
  }
  {
    name: field_text(fields, "name"),
    description: field_text(fields, "description"),
    body,
    meta: fields,
    root,
    document: "SKILL.md",
  }
}

///|
/// The offset of the next `---`, searching from `from`.
///
/// The fence is three hyphens wherever they fall: the closing fence does not
/// have to start a line, which is what the reference reader does too, and a
/// body that mentions `---` further down cannot become the closing fence
/// because only the first one counts.
fn find_fence(text : StringView, from : Int32) -> Int32? {
  let last = text.length() - 3
  let mut index = from
  while index <= last {
    if text[index] == '-' && text[index + 1] == '-' && text[index + 2] == '-' {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
/// A frontmatter field as trimmed text. Anything that is not text reads as
/// empty, which [`validate`] then reports.
fn field_text(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(String(text)) => text.trim().to_owned()
    _ => ""
  }
}
