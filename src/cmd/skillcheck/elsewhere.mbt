// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The same command on the targets that have no filesystem: it says what this
/// one would need rather than failing to link.
fn main {
  println("moonskill: this command needs a native target")
  println(
    "run it with: moon run src/cmd/skillcheck --target native -- <skill-directory>...",
  )
}
