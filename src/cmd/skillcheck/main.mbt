// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Check the skill directories named on the command line.
///
/// One line per directory on success, one line and the faults on failure, and a
/// non-zero exit when anything failed — which is what a repository's CI step
/// reads. `--json` prints one object per line instead, for a program that wants
/// the fault kinds rather than the sentences.
async fn main {
  let args = @env.args()
  let mut json = false
  let targets = []
  for index in 1..<args.length() {
    let arg = args[index]
    if arg == "--json" {
      json = true
    } else if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else {
      targets.push(arg)
    }
  }
  if targets.length() == 0 {
    print_usage()
    return
  }
  let mut failed = 0
  for target in targets {
    let (path, valid, faults) = check(target)
    if json {
      print_json(path, valid, faults)
    } else {
      print_human(path, valid, faults)
    }
    if !valid {
      failed = failed + 1
    }
  }
  if failed > 0 {
    fail("\{failed} of \{targets.length()} skill directories did not pass")
  }
}

///|
async fn check(path : String) -> (String, Bool, Array[@moonskill.Fault]) {
  let dir = if is_document(path) { parent_of(path) } else { path }
  let faults = @fs.check(dir)
  (dir, faults.length() == 0, faults)
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
fn print_json(
  path : String,
  valid : Bool,
  faults : Array[@moonskill.Fault],
) -> Unit {
  let reported = []
  for fault in faults {
    reported.push(
      Json::object(
        Map([("kind", Json(fault.kind())), ("message", Json(fault.message()))]),
      ),
    )
  }
  let line = Json::object(
    Map([
      ("path", Json(path)),
      ("valid", Json(valid)),
      ("faults", Json::array(reported)),
    ]),
  )
  println(line.stringify())
}

///|
fn print_usage() -> Unit {
  println("usage: moonskill <skill-directory>... [--json]")
  println("")
  println("  Checks each directory against the Agent Skills specification.")
  println("  A path to a SKILL.md checks the directory that holds it.")
  println("  --json  one JSON object per directory, for a program")
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
