// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a page shows after one document goes through the checker: the header it
/// read, the line a model would see, and every fault the run reported.
#derive(ToJson)
struct Screening {
  name : String
  description : String
  summary : String
  location : String
  body_lines : Int32
  faults : Array[Verdict]
}

///|
pub extend Screening with @json.ToJson::{to_json}

///|
/// One fault as the page files it: a tag that does not change with the wording,
/// and the sentence a person reads.
#derive(ToJson)
struct Verdict {
  kind : String
  message : String
}

///|
pub extend Verdict with @json.ToJson::{to_json}

///|
/// Judge one document, for a page that has no MoonBit runtime of its own.
///
/// `text` is what the reader typed and `root` is the directory it would sit in.
/// The answer is JSON rather than a record because this is the edge of the
/// language: the caller is JavaScript, and a string crosses that edge in one
/// piece. Every field is the library's own wording — a page that reworded a
/// message would be reporting something the checker does not say.
pub fn screen(text : String, root : String) -> String {
  let screening = match
    (Ok(@moonskill.parse(text, root~)) catch { error => Err(error) }) {
    Ok(skill) =>
      Screening::{
        name: skill.name,
        description: skill.description,
        summary: skill.summary(),
        location: skill.location(),
        body_lines: line_count(skill.body),
        faults: @moonskill.validate(skill).map(fault => Verdict::{
          kind: fault.kind(),
          message: fault.message(),
        }),
      }
    // A document that does not parse is one fault, not an error the page has to
    // turn into a fault of its own.
    Err(refused) =>
      Screening::{
        name: "",
        description: "",
        summary: "",
        location: "",
        body_lines: 0,
        faults: [Verdict::{ kind: "malformed", message: refused.message(), }],
      }
  }
  @json.to_json(screening).stringify()
}

///|
/// Lines of Markdown an agent would read once it chose the skill.
fn line_count(body : String) -> Int32 {
  if body == "" {
    return 0
  }
  let mut count = 1
  for c in body {
    if c == '\n' {
      count = count + 1
    }
  }
  count
}
