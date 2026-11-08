// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The screening desks. Every verdict on these pages comes from the library
// compiled to JavaScript; this file only moves text to and from it, and turns
// the answer into the mark a reviewer would leave.

const engine = await load("./engine/moonskill.js");
const cases = (await load("./engine/cases.js"))?.cases || [];

async function load(path) {
  try {
    return await import(path);
  } catch (error) {
    return null;
  }
}

function note(text) {
  const entry = document.createElement("li");
  entry.className = "empty";
  entry.textContent = text;
  return entry;
}

function mount(desk) {
  const textarea = desk.querySelector("textarea");
  const rootInput = desk.querySelector(".root");
  const list = desk.querySelector(".verdicts");
  const state = desk.querySelector(".state");

  const render = () => {
    if (!engine) {
      list.replaceChildren(note("the compiled library is not next to this page"));
      state.textContent = "no engine";
      return;
    }
    let answer;
    try {
      answer = JSON.parse(engine.screen(textarea.value, rootInput.value.trim()));
    } catch (error) {
      list.replaceChildren(note("the checker stopped on this input"));
      state.textContent = "stopped";
      return;
    }
    const faults = answer.faults;
    list.replaceChildren();
    if (faults.length === 0) {
      list.append(note("no faults — a client would offer this skill as it stands"));
      state.textContent = "accepted";
      state.dataset.clean = "true";
    } else {
      for (const fault of faults) {
        const entry = document.createElement("li");
        const kind = document.createElement("span");
        kind.className = "kind";
        kind.textContent = fault.kind;
        const message = document.createElement("span");
        message.className = "message";
        message.textContent = fault.message;
        entry.append(kind, message);
        list.append(entry);
      }
      state.textContent = faults.length === 1 ? "1 fault" : `${faults.length} faults`;
      state.dataset.clean = "false";
    }
  };

  let timer = 0;
  const later = () => {
    clearTimeout(timer);
    timer = setTimeout(render, 110);
  };

  const open = (one) => {
    textarea.value = one.text;
    rootInput.value = one.dir;
    render();
  };

  textarea.addEventListener("input", later);
  rootInput.addEventListener("input", later);

  for (const chip of desk.querySelectorAll("[data-case]")) {
    const chosen = cases.find((one) => one.dir === chip.dataset.case);
    if (!chosen) {
      chip.hidden = true;
      continue;
    }
    chip.addEventListener("click", () => open(chosen));
  }

  const reset = desk.querySelector("[data-reset]");
  if (reset) {
    reset.addEventListener("click", () => {
      textarea.value = textarea.defaultValue;
      rootInput.value = desk.dataset.root;
      render();
    });
  }

  render();
  return { open };
}

const desks = [...document.querySelectorAll("[data-screening]")].map(mount);
const first = desks[0];

// The corpus, judged by the library as the page loads: each case is one rule of
// the specification, in both directions.
const wall = document.querySelector("[data-corpus]");
if (wall) {
  if (!engine || cases.length === 0) {
    wall.append(note("the corpus is built with the engine; it is not next to this page"));
  } else {
    for (const one of cases) {
      const answer = JSON.parse(engine.screen(one.text, one.dir));
      const button = document.createElement("button");
      button.type = "button";
      button.className = "case";
      button.dataset.dir = one.dir;
      const dir = document.createElement("span");
      dir.className = "dir";
      dir.textContent = one.dir;
      const tag = document.createElement("span");
      tag.className = "tag";
      const count = answer.faults.length;
      tag.textContent = count === 0 ? "accepted" : String(count);
      tag.dataset.clean = String(count === 0);
      button.append(dir, tag);
      button.addEventListener("click", () => {
        if (first) {
          first.open(one);
          document.querySelector(".form").scrollIntoView({ behavior: "smooth", block: "center" });
        }
      });
      wall.append(button);
    }
  }
}
