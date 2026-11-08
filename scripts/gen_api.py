"""Render docs/api.html from the interfaces this module publishes.

The page is generated rather than written so that a signature cannot drift from the source: every
item in `pkg.generated.mbti` appears here, in the order the interface file lists it, with the `///`
comment above it in the source. Run it after changing an interface; CI runs it again and fails when
`docs/api.html` is not what it would have written.

The native backend's interface is preferred when it exists, because a package whose files are all
`.native.mbt` has an empty interface on the other backends and its whole surface lives only there.

Usage: python scripts/gen_api.py [--check]
"""

import argparse
import html
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "docs" / "api.html"
BUILD = ROOT / "_build" / "native" / "debug" / "check"

SKIP = {"examples", "cmd", "snippet_probe", "snippet_check"}

TYPE_KINDS = ("struct", "enum", "suberror", "trait")
DECL = re.compile(
    r"^(?P<attrs>#\[?[a-z_]+.*)?\s*(?:(?P<vis>pub(?:\([a-z]+\))?)\s+)?(?P<kw>async\s+fn|fn|let|struct|enum|suberror|trait|impl|typealias|type)\b(?P<rest>.*)$"
)


def write_native_interfaces():
    """Ask the toolchain for each backend's interface.

    `moon check` only type-checks; the per-backend interface file is written by `moon info`. That
    command also rewrites the committed `pkg.generated.mbti` when the backends disagree, so the
    committed files are put back afterwards — this script reads the build, it does not change the tree.
    """
    committed = {path: path.read_bytes() for path in SRC.rglob("pkg.generated.mbti")}
    run = subprocess.run(["moon", "info", "--target", "native"], cwd=ROOT, capture_output=True, text=True)
    for path, before in committed.items():
        if path.read_bytes() != before:
            path.write_bytes(before)
    if run.returncode != 0:
        print(run.stdout + run.stderr)
        raise SystemExit("moon info --target native failed; the interfaces are not available")


def write_native_interfaces():
    """Ask the toolchain for each backend's interface.

    `moon check` only type-checks; the per-backend interface file is written by `moon info`. That
    command also rewrites the committed `pkg.generated.mbti` when the backends disagree, so the
    committed files are put back afterwards — this script reads the build, it does not change the tree.
    """
    committed = {path: path.read_bytes() for path in SRC.rglob("pkg.generated.mbti")}
    run = subprocess.run(["moon", "info", "--target", "native"], cwd=ROOT, capture_output=True, text=True)
    for path, before in committed.items():
        if path.read_bytes() != before:
            path.write_bytes(before)
    if run.returncode != 0:
        print(run.stdout + run.stderr)
        raise SystemExit("moon info --target native failed; the interfaces are not available")


def packages():
    """Every package of this module that is part of the library, deepest last."""
    found = []
    for pkg in sorted(SRC.rglob("moon.pkg")):
        rel = pkg.parent.relative_to(SRC).as_posix()
        if rel != "." and SKIP & set(rel.split("/")):
            continue
        found.append(rel)
    return sorted(found, key=lambda rel: (rel != ".", rel))


def native_interface(rel):
    """The interface the native backend produced for a package, wherever the build put it."""
    module = "moonbitstack/moonskill" + ("" if rel == "." else "/" + rel)
    root = ROOT / "_build" / "native"
    for path in sorted(root.rglob("*.mbti")) if root.is_dir() else []:
        text = path.read_text(encoding="utf-8", errors="replace")
        if f'package "{module}"' in text:
            return text
    return None


def interface(rel):  # noqa: D401 - returns the text, not the path
    """The interface a package publishes, preferring the native backend's file.

    A package whose files are all `.native.mbt` has an empty interface on the other backends, so the
    committed file — the one `moon info --target all` writes — says nothing about it. The build's own
    file does.
    """
    built = native_interface(rel)
    if built is not None:
        return built
    committed = SRC / rel / "pkg.generated.mbti"
    if committed.exists():
        print(f"{rel or '.'}: using the committed interface, which has no native half")
        return committed.read_text(encoding="utf-8")
    raise SystemExit(f"no interface for {rel}: run `moon check --target native` first")


def doc_comments():
    """`///` comments keyed by what they document: `name`, `Type.field`, `Type::Variant`."""
    docs = {}
    for path in sorted(SRC.rglob("*.mbt")):
        if SKIP & set(path.relative_to(SRC).parts):
            continue
        pending = []
        owner = None
        depth = 0
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if line.startswith("///"):
                body = line[3:]
                # `///|` separates the summary from the rest of a comment.
                pending.append("" if body.strip() == "|" else body.lstrip())
                continue
            if not line:
                if depth == 0:
                    pending = []
                continue
            text = "\n".join(pending)
            pending = []
            if depth == 0:
                m = re.match(
                    r"^(?:#\[?[a-z_]+.*)?\s*(?:pub(?:\([a-z]+\))?\s+)?(?:async\s+)?(?:fn|let)\s+"
                    r"([A-Za-z_][\w]*(?:::[A-Za-z_]\w*)?)",
                    line,
                )
                if m:
                    put(docs, m.group(1), text)
                    continue
                m = re.match(
                    r"^(?:#\[?[a-z_]+.*)?\s*(?:pub(?:\([a-z]+\))?\s+)?"
                    r"(?:struct|enum|suberror|trait|typealias|type)\s+([A-Za-z_]\w*)",
                    line,
                )
                if m:
                    owner = m.group(1)
                    put(docs, owner, text)
                    depth = line.count("{") - line.count("}")
                    continue
            elif owner:
                m = re.match(r"(?:async\s+)?fn\s+([A-Za-z_]\w*)", line)
                if m:
                    put(docs, f"{owner}::{m.group(1)}", text)
                else:
                    m = re.match(r"([A-Za-z_]\w*)\s*(?:\(|:|$)", line)
                    if m:
                        put(docs, f"{owner}.{m.group(1)}", text)
                        put(docs, f"{owner}::{m.group(1)}", text)
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                depth = 0
                owner = None
    return docs


def put(docs, key, text):
    if text.strip() and key not in docs:
        docs[key] = text


def sections(text):
    """The interface file's groups, each a list of declarations."""
    out = []
    title = None
    body = []
    for line in text.splitlines():
        if line.startswith("// ") and not line.startswith("// Generated"):
            if title:
                out.append((title, body))
            title = line[3:].strip()
            body = []
            continue
        if line.startswith("package "):
            continue
        body.append(line)
    if title:
        out.append((title, body))
    return out


def declarations(lines):
    """Split a group into whole declarations: attributes travel with what they modify.

    An interface file puts no blank line between a type and the methods under it, so a declaration
    also ends where the next one begins.
    """
    items = []
    buf = []
    depth = 0
    for line in lines:
        text = line.strip()
        if not text:
            if buf and depth == 0:
                items.append(buf)
                buf = []
            continue
        starts = depth == 0 and buf and (
            text.startswith("pub") or (text.startswith("#") and buf[-1].strip() == "}")
        )
        if starts:
            items.append(buf)
            buf = []
        buf.append(line)
        depth = max(0, depth + line.count("{") - line.count("}"))
    if buf:
        items.append(buf)
    return items


def classify(block):
    head = next((line for line in block if not line.strip().startswith("#")), "")
    text = head.strip()
    m = DECL.match(text)
    if not m:
        return None
    kw = m.group("kw").split()[-1]
    rest = m.group("rest").strip()
    if kw in ("fn", "let"):
        found = re.match(r"([A-Za-z_]\w*(?:::[A-Za-z_]\w*)?)", rest)
        name = found.group(1) if found else ""
        if not name:
            return None
        return {"kind": kw, "name": name, "head": text, "block": block}
    if kw in TYPE_KINDS:
        name = re.split(r"[\[({\s]", rest, maxsplit=1)[0]
        return {"kind": kw, "name": name, "head": text, "block": block}
    if kw == "impl":
        target = re.search(r"\bfor\s+([A-Za-z_]\w*)", rest)
        trait = re.split(r"\s+for\s+", rest, maxsplit=1)[0]
        return {"kind": "impl", "name": trait, "for": target.group(1) if target else None, "head": text, "block": block}
    return None


def signature(item):
    """The declaration a reader would write: a function whole, a type by its head."""
    head = item["head"]
    if "{" in head:
        head = head.split("{", 1)[0].rstrip()
    if item["kind"] in TYPE_KINDS + ("impl",):
        return head
    for line in item["block"][1:]:
        if line.strip().startswith("}"):
            break
        if line.strip().startswith("#"):
            continue
        head += "\n" + line.rstrip()
    head = re.sub(r"^pub(?:\([a-z]+\))?\s+", "", head)
    return head


def members(item):
    """The shape inside a type: a field and its type, a variant and its payload, a method."""
    out = []
    for line in item["block"][1:]:
        text = line.strip()
        if text.startswith("}"):
            break
        if not text or text.startswith("#"):
            continue
        if item["kind"] == "trait":
            named = re.match(r"((?:async\s+)?fn\s+[A-Za-z_]\w*)", text)
            if named:
                out.append((named.group(1).split()[-1], re.sub(r"^(?:async\s+)?fn\s+", "", text)))
            continue
        named = re.match(r"([A-Za-z_]\w*)\s*(.*)", text)
        if not named:
            continue
        name, rest = named.group(1), named.group(2).strip()
        if item["kind"] == "struct":
            rest = rest.lstrip(":").strip()
        elif rest.startswith("(") and rest.endswith(")"):
            rest = rest[1:-1]
        out.append((name, rest))
    return out


def inline(text):
    """Escaped prose: `code` spans, and the [`link`] form the source comments use."""
    text = html.escape(text)
    text = re.sub(r"\[`([^`]+)`\]", r"<code>\1</code>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    return text


def prose(text):
    if not text or not text.strip():
        return ""
    paragraphs = [block.strip() for block in re.split(r"\n\s*\n", text) if block.strip()]
    return "".join(f"<p>{inline(' '.join(p.split()))}</p>" for p in paragraphs)


def note(kind):
    return {
        "fn": "function",
        "let": "value",
        "struct": "struct",
        "enum": "enum",
        "suberror": "error",
        "trait": "trait",
    }.get(kind, kind)


def render_item(item, docs, depth="item"):
    name = item["name"]
    doc = docs.get(name, "")
    sig = signature(item)
    parts = [
        f'<div class="api-{depth}" id="{anchor(name)}">',
        '<div class="api-head">',
        f'<code class="api-name">{html.escape(name)}</code>',
        f'<span class="api-kind">{note(item["kind"])}</span>',
        "</div>",
        f'<pre class="api-sig">{html.escape(sig)}</pre>',
    ]
    body = prose(doc)
    if body:
        parts.append(f'<div class="api-doc">{body}</div>')
    if item["kind"] in ("struct", "enum", "suberror", "trait"):
        headers = {
            "struct": ("Field", "Type", "Meaning"),
            "enum": ("Variant", "Payload", "Meaning"),
            "suberror": ("Variant", "Payload", "Meaning"),
            "trait": ("Method", "Signature", "Meaning"),
        }[item["kind"]]
        rows = []
        for member, rest in members(item):
            key = f"{name}::{member}" if item["kind"] != "struct" else f"{name}.{member}"
            text = docs.get(key, "")
            rows.append(
                "<tr>"
                f"<td><code>{html.escape(member)}</code></td>"
                f"<td>{html.escape(rest) or '&mdash;'}</td>"
                f"<td>{inline(' '.join(text.split()))}</td>"
                "</tr>"
            )
        if rows:
            parts.append(
                '<table class="api-members"><thead><tr>'
                + "".join(f'<th scope="col">{h}</th>' for h in headers)
                + "</tr></thead><tbody>"
                + "".join(rows)
                + "</tbody></table>"
            )
    parts.append("</div>")
    return "\n".join(parts)


def anchor(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def render_package(rel, text, docs, index):
    number = f"{index:02d}"
    module = "moonbitstack/moonskill" + ("" if rel == "." else "/" + rel)
    label = {".": "document", "fs": "directory"}.get(rel, rel)
    blurb = {
        ".": "The document: what a SKILL.md may say, how it is judged, and how a client reads the three tiers.",
        "fs": "The directory: a tree of skills read from disk, as a source the document package can walk.",
    }.get(rel, "A package of this module.")

    groups = []
    rendered = 0
    for title, lines in sections(text):
        items = [classify(block) for block in declarations(lines)]
        items = [item for item in items if item]
        if not items:
            continue
        values = [item for item in items if item["kind"] in ("fn", "let") and "::" not in item["name"]]
        types = [item for item in items if item["kind"] in TYPE_KINDS]
        methods = [item for item in items if item["kind"] in ("fn", "let") and "::" in item["name"]]
        impls = [item for item in items if item["kind"] == "impl"]

        chunk = [f'<h3 class="api-group">{html.escape(title)}</h3>']
        if values:
            chunk.append('<div class="api-list">')
            for item in values:
                chunk.append(render_item(item, docs))
                rendered += 1
            chunk.append("</div>")
        for type_item in types:
            chunk.append(render_item(type_item, docs, depth="type"))
            rendered += 1
            own = [
                item
                for item in methods
                if item["name"].startswith(type_item["name"] + "::")
            ]
            if own:
                chunk.append('<div class="api-list api-methods">')
                for item in own:
                    chunk.append(render_item(item, docs))
                    rendered += 1
                chunk.append("</div>")
            related = [item for item in impls if item.get("for") == type_item["name"]]
            for item in related:
                chunk.append(
                    f'<p class="api-impl">implements <code>{html.escape(item["name"])}</code></p>'
                )
                rendered += 1
        loose = [
            item
            for item in methods
            if not any(item["name"].startswith(t["name"] + "::") for t in types)
        ]
        if loose:
            chunk.append('<div class="api-list">')
            for item in loose:
                chunk.append(render_item(item, docs))
                rendered += 1
            chunk.append("</div>")
        groups.append("\n".join(chunk))

    body = f"""
  <section class="section" id="pkg-{anchor('root' if rel == '.' else rel)}" data-section data-label="{html.escape(label)}">
    <h2 class="sec"><span class="n">{number}</span><span class="t">{html.escape(module)}</span><span class="of">of 02</span></h2>
    <p class="lede">{html.escape(blurb)}</p>
{chr(10).join(groups)}
  </section>"""
    return body, rendered


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>API — moonskill</title>
<meta name="description" content="Every public item of moonskill, generated from the module's interfaces.">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<script>
  try {{
    const saved = sessionStorage.getItem("moonskill:theme");
    const type = (performance.getEntriesByType("navigation")[0] || {{}}).type;
    if (saved && type !== "reload") document.documentElement.dataset.theme = saved;
    else sessionStorage.removeItem("moonskill:theme");
  }} catch (error) {{}}
</script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Caveat:wght@400;500&family=IBM+Plex+Mono:wght@400;500&display=swap">
<link rel="preload" href="fonts/harmonyos-sans-sc-regular.woff" as="font" type="font/woff" crossorigin>
<link rel="preload" href="fonts/harmonyos-sans-sc-bold.woff" as="font" type="font/woff" crossorigin>
<link rel="stylesheet" href="style.css">
</head>
<body id="top">

<a class="skip" href="#main">skip to the sheet</a>

<main class="sheet" id="main" tabindex="-1">

  <nav class="tabs" aria-label="Pages">
    <a class="tab" href="index.html">home</a>
    <a class="tab" href="guide.html">guide</a>
    <a class="tab" href="api.html" aria-current="page">api</a>
    <a class="tab" href="screening.html">screening</a>
  </nav>

  <div class="docline">
    <span class="ref">moonbitstack</span>
    <span>appendix</span>
    <span>{count} public items</span>
    <span class="right">
      <span>ap&ndash;04</span>
      <a href="https://github.com/moonbitstack/moonskill">github</a>
      <button class="theme" type="button" data-theme-toggle>paper</button>
    </span>
  </div>

  <div class="masthead masthead--sub">
    <div>
      <h1>the interface</h1>
      <p class="role">Every public item, in the order the interface files list it. A signature here is the one the compiler sees.</p>
    </div>
  </div>
{body}

  <footer class="foot">
    <span class="signature">moonskill</span>
    <span class="small">
      appendix &middot; generated from the interfaces<br>
      <a href="index.html">back to the sheet</a>
    </span>
  </footer>

</main>

<nav class="index" aria-label="Sections"></nav>

<a class="totop" href="#top" aria-label="Back to the top of the page"><span class="arrow" aria-hidden="true">&uarr;</span><span class="label">top</span></a>

<script type="module" src="site.js"></script>
</body>
</html>
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail when the page is not up to date")
    args = parser.parse_args()

    write_native_interfaces()
    docs = doc_comments()

    parts = []
    total = 0
    for index, rel in enumerate(packages(), start=1):
        text = interface(rel)
        if not any(line.startswith("pub ") for line in text.splitlines()):
            raise SystemExit(f"{rel} publishes nothing; its interface was not written for this backend")
        print(f"{rel or '.'}: {sum(1 for line in text.splitlines() if line.startswith('pub '))} declarations")
        chunk, count = render_package(rel, text, docs, index)
        parts.append(chunk)
        total += count

    page = PAGE.format(count=total, body="\n".join(parts))
    page = page.replace("\r\n", "\n")
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != page:
            print("docs/api.html is out of date: run python scripts/gen_api.py")
            return 1
        print(f"docs/api.html: {total} public items, up to date")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page, encoding="utf-8", newline="\n")
    print(f"docs/api.html: {total} public items")
    return 0


if __name__ == "__main__":
    sys.exit(main())
