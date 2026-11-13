// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The three questions a shell asks about a skill directory.
///
/// `validate` is the one a repository's CI step runs: one line per directory, a
/// non-zero exit when anything failed. `read-properties` prints the header as
/// JSON for a program that wants the fields rather than the verdict, and
/// `to-prompt` prints the tier-1 block for a set of skills. Without a
/// subcommand every argument is a directory to validate, which is the form the
/// command had before the other two existed.
async fn main {
  let args = @env.args()
  let command = if args.length() > 1 { args[1] } else { "" }
  if command == "read-properties" {
    properties_command(args[2:])
  } else if command == "to-prompt" {
    prompt_command(args[2:])
  } else if command == "validate" {
    check_command(args[2:])
  } else {
    check_command(args[1:])
  }
}

///|
/// Judge each directory, printing one line for each and the faults under the
/// ones that failed.
async fn check_command(targets : ArrayView[String]) -> Unit {
  let (json, paths) = parse_flags(targets)
  if paths.length() == 0 {
    print_usage()
    return
  }
  let mut failed = 0
  for target in paths {
    let path = directory_of(target)
    let faults = @fs.check(path)
    let valid = faults.length() == 0
    if json {
      println(verdict_json(path, valid, faults).stringify())
    } else {
      print_human(path, valid, faults)
    }
    if !valid {
      failed = failed + 1
    }
  }
  if failed > 0 {
    fail("\{failed} of \{paths.length()} skill directories did not pass")
  }
}

///|
/// The header of each skill as JSON, one object per line.
///
/// A document that cannot be read at all is reported under the directory and
/// makes the run fail; a document that reads but is missing a required field
/// still prints, because what the header says is what was asked for.
async fn properties_command(targets : ArrayView[String]) -> Unit {
  if targets.length() == 0 {
    print_usage()
    return
  }
  let mut failed = 0
  for target in targets {
    let path = directory_of(target)
    match (Ok(@fs.load(path)) catch { e => Err(e) }) {
      Ok(skill) => println(properties_json(skill).stringify())
      Err(error) => {
        failed = failed + 1
        println("FAIL  \{path}")
        println("      - \{error.to_string()}")
      }
    }
  }
  if failed > 0 {
    fail("\{failed} of \{targets.length()} skill directories could not be read")
  }
}

///|
/// The tier-1 block for the directories, in the order they were given.
///
/// Nothing is printed when a directory cannot be read: a block missing a skill
/// is a block that tells a model a tool does not exist.
async fn prompt_command(targets : ArrayView[String]) -> Unit {
  if targets.length() == 0 {
    print_usage()
    return
  }
  let skills = []
  let mut failed = 0
  for target in targets {
    let path = directory_of(target)
    match (Ok(@fs.load(path)) catch { e => Err(e) }) {
      Ok(skill) => skills.push(skill)
      Err(error) => {
        failed = failed + 1
        println("FAIL  \{path}")
        println("      - \{error.to_string()}")
      }
    }
  }
  if failed > 0 {
    fail("\{failed} of \{targets.length()} skill directories could not be read")
  }
  println(@moonskill.prompt(skills))
}

///|
/// The flags a check takes, and the paths among the arguments.
fn parse_flags(args : ArrayView[String]) -> (Bool, Array[String]) {
  let mut json = false
  let paths = []
  for arg in args {
    if arg == "--json" {
      json = true
    } else if arg == "--help" || arg == "-h" {
      print_usage()
    } else {
      paths.push(arg)
    }
  }
  (json, paths)
}

///|
fn print_human(
  path : String,
  valid : Bool,
  faults : Array[@moonskill.Fault],
) -> Unit {
  if valid {
    println("ok    \{path}")
  } else {
    println("FAIL  \{path}")
    for fault in faults {
      println("      - \{fault.kind()}: \{fault.message()}")
    }
  }
}

///|
/// One verdict as a program reads it: the path, whether it passed, and the
/// faults with their tags and their sentences.
fn verdict_json(
  path : String,
  valid : Bool,
  faults : Array[@moonskill.Fault],
) -> Json {
  let reported = []
  for fault in faults {
    reported.push(
      Json::object(
        Map([("kind", Json(fault.kind())), ("message", Json(fault.message()))]),
      ),
    )
  }
  Json::object(
    Map([
      ("path", Json(path)),
      ("valid", Json(valid)),
      ("faults", Json::array(reported)),
    ]),
  )
}

///|
/// The fields the specification defines, with the optional ones present only
/// when the document has them.
fn properties_json(skill : @moonskill.Skill) -> Json {
  let fields : Map[String, Json] = Map([
    ("name", Json(skill.name)),
    ("description", Json(skill.description)),
  ])
  if skill.license() is Some(text) {
    fields["license"] = Json(text)
  }
  if skill.compatibility() is Some(text) {
    fields["compatibility"] = Json(text)
  }
  if skill.allowed_tools() is Some(text) {
    fields["allowed-tools"] = Json(text)
  }
  if skill.metadata() is Some(entries) && entries.length() > 0 {
    let text : Map[String, Json] = Map([])
    for key, value in entries {
      text[key] = Json(value)
    }
    fields["metadata"] = Json::object(text)
  }
  Json::object(fields)
}

///|
fn print_usage() -> Unit {
  println("usage: moonskill <skill-directory>... [--json]")
  println("       moonskill validate <skill-directory>... [--json]")
  println("       moonskill read-properties <skill-directory>...")
  println("       moonskill to-prompt <skill-directory>...")
  println("")
  println("  validate         Judge each directory against the Agent Skills")
  println(
    "                   specification: one line each, a non-zero exit when",
  )
  println("                   anything failed. --json prints one object per")
  println("                   directory for a program to read.")
  println("  read-properties  Print the frontmatter of each skill as JSON.")
  println("  to-prompt        Print the <available_skills> block they offer.")
  println("")
  println("  A path to a SKILL.md names the directory that holds it.")
}

///|
/// The directory a skill is in, given either the directory or its document.
fn directory_of(path : String) -> String {
  if is_document(path) {
    parent_of(path)
  } else {
    path
  }
}

///|
fn is_document(path : String) -> Bool {
  let name = @moonskill.base_name(path)
  name == "SKILL.md" || name == "skill.md"
}

///|
fn parent_of(path : String) -> String {
  let text = path
  let mut end = text.length()
  while end > 0 && (text[end - 1] == '/' || text[end - 1] == '\\') {
    end = end - 1
  }
  let mut start = end
  while start > 0 && text[start - 1] != '/' && text[start - 1] != '\\' {
    start = start - 1
  }
  if start == 0 {
    "."
  } else {
    text[:start - 1].to_owned()
  }
}
