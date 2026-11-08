// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Three things the pages share: the theme switch, the reading edge on the
// right, and copy buttons. Nothing here knows what a skill is.

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
  for (const button of document.querySelectorAll("[data-theme-toggle]")) {
    const now = currentTheme();
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

function startEdge() {
  const edge = document.querySelector(".edge");
  if (!edge) {
    return;
  }
  const marks = edge.querySelector(".edge-marks");
  const thumb = edge.querySelector(".edge-thumb");
  const sections = [...document.querySelectorAll("[data-section]")];
  const root = document.documentElement;

  for (const section of sections) {
    const mark = document.createElement("button");
    mark.type = "button";
    mark.className = "edge-mark";
    mark.dataset.label = section.dataset.label || section.id;
    mark.setAttribute("aria-label", `Go to ${mark.dataset.label}`);
    mark.addEventListener("click", () => {
      section.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    marks.append(mark);
  }

  let frame = 0;
  const draw = () => {
    frame = 0;
    const height = edge.clientHeight - 36;
    const scrollable = root.scrollHeight - innerHeight;
    const ratio = scrollable > 0 ? Math.min(1, Math.max(0, scrollY / scrollable)) : 0;
    const size = Math.max(28, Math.round((innerHeight / root.scrollHeight) * height));
    thumb.style.height = `${size}px`;
    thumb.style.transform = `translateY(${Math.round(ratio * (height - size))}px)`;
    sections.forEach((section, index) => {
      const top = section.getBoundingClientRect().top + scrollY;
      const at = Math.min(1, top / Math.max(1, root.scrollHeight));
      marks.children[index].style.top = `${Math.round(at * height)}px`;
    });
    root.classList.toggle("at-top", scrollY < 4);
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
      const text = code.textContent;
      try {
        await navigator.clipboard.writeText(text);
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
startEdge();
startCopy();
