// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The length limits the specification puts on a frontmatter field.
///
/// They are a record rather than three constants because a client may enforce
/// a tighter budget than the specification's — a model with a smaller context
/// wants shorter descriptions — and because a test that reads the boundary
/// should read it from one place.
pub(all) struct Limits {
  /// The longest `name`, in characters. The specification says 64.
  name : Int32
  /// The longest `description`, in characters. The specification says 1024.
  description : Int32
  /// The longest `compatibility`, in characters. The specification says 500.
  compatibility : Int32
}

///|
/// The limits of the Agent Skills specification.
pub let limits : Limits = { name: 64, description: 1024, compatibility: 500, }

///|
/// Every rule the specification states about the frontmatter, judged against
/// the skill's own text.
///
/// The list is empty when the skill is valid. It is not a refusal: a validator
/// reports all the faults at once, because a person fixing a document wants the
/// whole list rather than the first line.
///
/// Two things are deliberately not faults. The body length and the token budget
/// are recommendations — the specification asks for a `SKILL.md` under five
/// hundred lines and says nothing breaks when it is longer — and an unknown key
/// under `metadata` is the caller's business, since the specification reserves
/// that mapping for clients.
pub fn validate(skill : Skill, limits~ : Limits = limits) -> Array[Fault] {
  let faults = []
  let unexpected = []
  for key, _ in skill.meta {
    if !is_allowed_field(key) {
      unexpected.push(key)
    }
  }
  if unexpected.length() > 0 {
    unexpected.sort_by((a, b) => a.lexical_compare(b))
    faults.push(UnexpectedFields(unexpected))
  }
  match field_of(skill, "name", skill.name) {
    None => faults.push(MissingName)
    Some(raw) => judge_name(faults, raw, skill.root, limits)
  }
  match field_of(skill, "description", skill.description) {
    None => faults.push(MissingDescription)
    Some(raw) =>
      if raw.trim() == "" {
        faults.push(DescriptionEmpty)
      } else if raw.char_length() > limits.description {
        faults.push(DescriptionTooLong(raw.char_length(), limits.description))
      }
  }
  match skill.meta.get("compatibility") {
    None => ()
    Some(value) =>
      match value {
        String(text) =>
          if text.char_length() > limits.compatibility {
            faults.push(
              CompatibilityTooLong(text.char_length(), limits.compatibility),
            )
          }
        _ => faults.push(CompatibilityNotText)
      }
  }
  faults
}

///|
/// Every fault in a document, from the fence to the last rule.
///
/// This is the call a validator makes: a document that does not parse is one
/// fault of kind `malformed`, and the rest of the list is whatever
/// [`validate`] finds in the fields. It is the whole check of a `SKILL.md` in
/// one function, which is what a command line and a test both want.
pub fn faults(
  text : StringView,
  root? : String,
  limits~ : Limits = limits,
) -> Array[Fault] {
  let parsed : Result[Skill, Refused] = Ok(parse(text, root?)) catch {
    Refused::MissingFrontmatter => Err(MissingFrontmatter)
    Refused::UnclosedFrontmatter => Err(UnclosedFrontmatter)
    Refused::BadYaml(reason) => Err(BadYaml(reason))
    Refused::NotAMapping => Err(NotAMapping)
    Refused::NotUtf8(at) => Err(NotUtf8(at))
    Refused::NoDocument => Err(NoDocument)
  }
  match parsed {
    Ok(skill) => validate(skill, limits~)
    Err(refused) => [Malformed(refused)]
  }
}

///|
/// The frontmatter fields the specification defines. Anything else is a fault,
/// because a reader that ignores a key it does not know has silently thrown
/// away something the author meant.
fn is_allowed_field(key : StringView) -> Bool {
  key == "name" ||
  key == "description" ||
  key == "license" ||
  key == "compatibility" ||
  key == "metadata" ||
  key == "allowed-tools"
}

///|
/// The field as written, untrimmed, so the length rule counts what the author
/// wrote rather than what this library would store.
///
/// `None` means the frontmatter has no such key and the parsed field is empty
/// too — the case the specification calls a missing required field.
fn field_of(skill : Skill, key : String, parsed : String) -> String? {
  match skill.meta.get(key) {
    Some(String(text)) => Some(text)
    Some(_) => Some("")
    None => if parsed == "" { None } else { Some(parsed) }
  }
}

///|
fn judge_name(
  faults : Array[Fault],
  raw : String,
  root : String,
  limits : Limits,
) -> Unit {
  // The specification is about what a reader sees, so the checks run on the
  // composed form: `cafe` plus a combining acute and `café` are one name.
  let name = @normalize.normalize(@normalize.NFKC, raw.trim())
  if name == "" {
    faults.push(NameEmpty)
    return
  }
  if name.char_length() > limits.name {
    faults.push(NameTooLong(name, name.char_length(), limits.name))
  }
  if @moonucd.lower(name) != name {
    faults.push(NameNotLowercase(name))
  }
  if name.has_prefix("-") || name.has_suffix("-") {
    faults.push(NameEdgeHyphen)
  }
  if name.contains("--") {
    faults.push(NameDoubleHyphen)
  }
  if !name.all(is_name_char) {
    faults.push(NameBadCharacter(name))
  }
  if root != "" {
    let directory = @normalize.normalize(@normalize.NFKC, base_name(root))
    if directory != name {
      faults.push(NameMismatch(directory, name))
    }
  }
}

///|
/// Whether a character may appear in a name.
///
/// The specification says lowercase letters, digits and hyphens. "Letters" is
/// the Unicode sense — a skill named in Chinese or Russian is a skill whose
/// author writes Chinese or Russian — so the test is the one Python's
/// `isalnum` makes: any letter, any digit, any number.
fn is_name_char(c : Char) -> Bool {
  if c == '-' {
    return true
  }
  match @moonucd.category(c) {
    Lu | Ll | Lt | Lm | Lo | Nd | Nl | No => true
    _ => false
  }
}
