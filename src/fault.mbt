// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Why a skill document was refused before it could become a [`Skill`].
///
/// A refusal is about the shape of the document — no frontmatter, YAML that
/// does not read, bytes that are not UTF-8. Whether the fields inside are
/// allowed is [`validate`]'s question, and it answers with a list rather than a
/// refusal so one run reports every fault.
#derive(Eq, @debug.Debug)
pub(all) suberror Refused {
  /// The text does not open with the `---` fence.
  MissingFrontmatter
  /// The opening fence has no closing `---`.
  UnclosedFrontmatter
  /// The frontmatter is not YAML the strict reader accepts. The text is the
  /// reader's complaint, which begins with the line and column.
  BadYaml(String)
  /// The frontmatter is YAML, but not a mapping.
  NotAMapping
  /// The bytes are not UTF-8; the offset is where decoding stopped.
  NotUtf8(Int32)
  /// A skill directory offered neither `SKILL.md` nor `skill.md`.
  NoDocument
}

///|
pub impl Show for Refused with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
pub extend Refused with Eq::{not_equal, equal}

///|
pub extend Refused with @debug.Debug::{to_repr}

///|
pub extend Refused with Show::{to_string, output}

///|
/// The refusal in one sentence, worded as the reference validator words it so a
/// report from either reads the same.
pub fn Refused::message(self : Refused) -> String {
  match self {
    MissingFrontmatter => "SKILL.md must start with YAML frontmatter (---)"
    UnclosedFrontmatter => "SKILL.md frontmatter not properly closed with ---"
    BadYaml(reason) => "Invalid YAML in frontmatter: \{reason}"
    NotAMapping => "SKILL.md frontmatter must be a YAML mapping"
    NotUtf8(at) => "SKILL.md is not UTF-8 at byte \{at}"
    NoDocument => "Missing required file: SKILL.md"
  }
}

///|
/// A rule of the Agent Skills specification that a skill does not meet.
///
/// [`validate`] reports every fault it finds, in the order a person reads the
/// frontmatter: keys that do not belong, the name, the description, then
/// `compatibility`. The last four only arise when a whole directory is checked:
/// they are about the tree, not about a document that already parsed.
#derive(Eq, @debug.Debug)
pub(all) enum Fault {
  /// Frontmatter keys the specification does not define, sorted.
  UnexpectedFields(Array[String])
  /// The frontmatter has no `name`.
  MissingName
  /// `name` is empty, blank, or not text.
  NameEmpty
  /// `name` is longer than the limit: the name, how long it is, and the limit.
  NameTooLong(String, Int32, Int32)
  /// `name` has an uppercase letter.
  NameNotLowercase(String)
  /// `name` starts or ends with a hyphen.
  NameEdgeHyphen
  /// `name` has two hyphens in a row.
  NameDoubleHyphen
  /// `name` has a character that is neither a letter, a digit, nor a hyphen.
  NameBadCharacter(String)
  /// The directory and the name differ: the directory name, then the name.
  NameMismatch(String, String)
  /// The frontmatter has no `description`.
  MissingDescription
  /// `description` is empty, blank, or not text.
  DescriptionEmpty
  /// `description` is longer than the limit: how long it is, then the limit.
  DescriptionTooLong(Int32, Int32)
  /// `compatibility` is present and is not text.
  CompatibilityNotText
  /// `compatibility` is longer than the limit: how long it is, then the limit.
  CompatibilityTooLong(Int32, Int32)
  /// The document could not be read as a skill at all.
  Malformed(Refused)
  /// There is nothing at the path.
  MissingPath(String)
  /// The path is a file, not a skill directory.
  NotADirectory(String)
  /// The directory has no `SKILL.md` or `skill.md`.
  MissingDocument
}

///|
/// The fault in one sentence, worded as the reference validator words it so a
/// report from either reads the same.
pub fn Fault::message(self : Fault) -> String {
  match self {
    UnexpectedFields(fields) => {
      let names = fields.join(", ")
      "Unexpected fields in frontmatter: \{names}. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed."
    }
    MissingName => "Missing required field in frontmatter: name"
    NameEmpty => "Field 'name' must be a non-empty string"
    NameTooLong(name, got, limit) =>
      "Skill name '\{name}' exceeds \{limit} character limit (\{got} chars)"
    NameNotLowercase(name) => "Skill name '\{name}' must be lowercase"
    NameEdgeHyphen => "Skill name cannot start or end with a hyphen"
    NameDoubleHyphen => "Skill name cannot contain consecutive hyphens"
    NameBadCharacter(name) =>
      "Skill name '\{name}' contains invalid characters. Only letters, digits, and hyphens are allowed."
    NameMismatch(dir, name) =>
      "Directory name '\{dir}' must match skill name '\{name}'"
    MissingDescription => "Missing required field in frontmatter: description"
    DescriptionEmpty => "Field 'description' must be a non-empty string"
    DescriptionTooLong(got, limit) =>
      "Description exceeds \{limit} character limit (\{got} chars)"
    CompatibilityNotText => "Field 'compatibility' must be a string"
    CompatibilityTooLong(got, limit) =>
      "Compatibility exceeds \{limit} character limit (\{got} chars)"
    Malformed(refused) => refused.message()
    MissingPath(path) => "Path does not exist: \{path}"
    NotADirectory(path) => "Not a directory: \{path}"
    MissingDocument => "Missing required file: SKILL.md"
  }
}

///|
pub impl Show for Fault with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
pub extend Fault with Eq::{not_equal, equal}

///|
pub extend Fault with @debug.Debug::{to_repr}

///|
pub extend Fault with Show::{to_string, output}

///|
/// A stable tag for the fault, for reports that are read by a program rather
/// than by a person. The wording of [`Fault::message`] may be rephrased; these
/// do not change.
pub fn Fault::kind(self : Fault) -> String {
  match self {
    UnexpectedFields(_) => "unexpected-fields"
    MissingName => "missing-name"
    NameEmpty => "name-empty"
    NameTooLong(_, _, _) => "name-too-long"
    NameNotLowercase(_) => "name-not-lowercase"
    NameEdgeHyphen => "name-edge-hyphen"
    NameDoubleHyphen => "name-double-hyphen"
    NameBadCharacter(_) => "name-bad-character"
    NameMismatch(_, _) => "name-mismatch"
    MissingDescription => "missing-description"
    DescriptionEmpty => "description-empty"
    DescriptionTooLong(_, _) => "description-too-long"
    CompatibilityNotText => "compatibility-not-text"
    CompatibilityTooLong(_, _) => "compatibility-too-long"
    Malformed(_) => "malformed"
    MissingPath(_) => "missing-path"
    NotADirectory(_) => "not-a-directory"
    MissingDocument => "missing-document"
  }
}
