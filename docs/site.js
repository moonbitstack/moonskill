// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The sheet's three small behaviours: the theme switch, the section index that
// stands in for a scrollbar, and copy buttons. Nothing here knows what a skill
// is.

const THEME_KEY = "moonskill:theme";

function systemTheme() {
  return matchMedia("(prefers-color-scheme: dark)").matches ? "ink" : "paper";
}

function currentTheme() {
  return document.documentElement.dataset.theme || systemTheme();
}

function paintTheme(theme) {
  // No theme means the system decides: leave the attribute off so the media
  // query keeps answering.
  if (theme) {
    document.documentElement.dataset.theme = theme;
  } else {
    delete document.documentElement.dataset.theme;
  }
  const now = currentTheme();
  for (const button of document.querySelectorAll("[data-theme-toggle]")) {
    button.textContent = now;
    button.setAttribute("aria-label", `Theme: ${now}. Switch theme.`);
    button.setAttribute("aria-pressed", String(now === "ink"));
  }
}

function startTheme() {
  // A link carries the theme the reader chose on the page before; a reload
  // drops the choice and the system decides again.
  try {
    const saved = sessionStorage.getItem(THEME_KEY);
    const type = (performance.getEntriesByType("navigation")[0] || {}).type;
    if (saved && type !== "reload") {
      document.documentElement.dataset.theme = saved;
    } else {
      sessionStorage.removeItem(THEME_KEY);
    }
  } catch (error) {
    // Storage can be closed; the system palette is still right.
  }
  paintTheme(document.documentElement.dataset.theme);
  for (const button of document.querySelectorAll("[data-theme-toggle]")) {
    button.addEventListener("click", () => {
      const next = currentTheme() === "ink" ? "paper" : "ink";
      paintTheme(next);
      try {
        sessionStorage.setItem(THEME_KEY, next);
      } catch (error) {
        // Without storage the choice still lasts for this page.
      }
    });
  }
}

function startIndex() {
  const index = document.querySelector(".index");
  if (!index) {
    return;
  }
  const sections = [...document.querySelectorAll("[data-section]")];
  if (sections.length === 0) {
    return;
  }
  const links = sections.map((section, order) => {
    const link = document.createElement("a");
    link.href = `#${section.id}`;
    const label = document.createElement("span");
    label.textContent = section.dataset.label || section.id;
    const mark = document.createElement("span");
    mark.className = "mark";
    link.append(label, mark);
    if (order === 0) {
      link.setAttribute("aria-current", "true");
    }
    index.append(link);
    return link;
  });

  let frame = 0;
  const draw = () => {
    frame = 0;
    const line = innerHeight * 0.34;
    let active = 0;
    sections.forEach((section, order) => {
      if (section.getBoundingClientRect().top <= line) {
        active = order;
      }
    });
    links.forEach((link, order) => {
      if (order === active) {
        link.setAttribute("aria-current", "true");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  };
  const schedule = () => {
    if (!frame) {
      frame = requestAnimationFrame(draw);
    }
  };
  addEventListener("scroll", schedule, { passive: true });
  addEventListener("resize", schedule);
  draw();
}

function startCopy() {
  for (const head of document.querySelectorAll(".code-head")) {
    const button = head.querySelector(".copy");
    const code = head.parentElement.querySelector("pre");
    if (!button || !code) {
      continue;
    }
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        button.textContent = "copied";
      } catch (error) {
        button.textContent = "select all";
      }
      setTimeout(() => {
        button.textContent = "copy";
      }, 1400);
    });
  }
}

startTheme();
startIndex();
startCopy();
