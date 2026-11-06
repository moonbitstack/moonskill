// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The block a client puts in a system prompt so a model knows which skills
/// exist, without putting their bodies in the context.
///
/// This is the first tier of the specification's progressive disclosure: one
/// entry per skill, the name and the description, and where the document is so
/// the model can ask for the rest. A skill with an empty description still gets
/// an entry — a model that cannot see the name cannot choose the skill, and the
/// description is what [`validate`] reports.
pub fn prompt(skills : ArrayView[Skill]) -> String {
  let lines = ["<available_skills>"]
  for skill in skills {
    lines.push("<skill>")
    lines.push("<name>")
    lines.push(escape_xml(skill.name))
    lines.push("</name>")
    lines.push("<description>")
    lines.push(escape_xml(skill.description))
    lines.push("</description>")
    lines.push("<location>")
    lines.push(escape_xml(skill.location()))
    lines.push("</location>")
    lines.push("</skill>")
  }
  lines.push("</available_skills>")
  lines.join("\n")
}

///|
/// Text that can sit inside an XML element without closing it early. A
/// description may quote an element — `Use when the task needs <table>` — and
/// that must read as text, not as markup.
fn escape_xml(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\'' => out.write_string("&#x27;")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}
