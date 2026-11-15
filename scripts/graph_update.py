"""Refresh the Graphify knowledge graph with proper Luau support.

Graphify parses .luau files with the plain Lua tree-sitter grammar, which chokes on
Luau-only syntax (type annotations, `::` casts, `type` declarations, `+=`, `if`
expressions, backtick strings, `continue`) and silently drops the symbols after
the first error. This wrapper hands graphify a Lua-compatible copy of each .luau
file instead: the Luau-only parts are blanked out with spaces, so every line keeps
its number and the graph still points at the real file and line.

Usage (from the repo root):
    python scripts/graph_update.py          # incremental update (like `graphify update .`)
    python scripts/graph_update.py --full   # drop the AST cache first and re-extract everything
    python scripts/graph_update.py --check  # only report which .luau files still fail to parse
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Lua keywords that end a type expression when met at bracket depth 0.
_STOP_WORDS = {"and", "or", "then", "do", "else", "elseif", "end", "in", "not", "return", "local"}
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def _blank(text: str) -> str:
    """Replace every character except newlines with a space (keeps line/column layout)."""
    return "".join(c if c == "\n" else " " for c in text)


def _skip_string_or_comment(src: str, i: int) -> int:
    """If a string or comment starts at i, return the index just past it, else i."""
    if src.startswith("--", i):
        m = re.match(r"--\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            end = src.find(close, i + m.end())
            return len(src) if end < 0 else end + len(close)
        end = src.find("\n", i)
        return len(src) if end < 0 else end
    c = src[i]
    if c in "\"'":
        j = i + 1
        while j < len(src) and src[j] != c and src[j] != "\n":
            j += 2 if src[j] == "\\" else 1
        return j + 1
    m = re.match(r"\[(=*)\[", src[i:])
    if m:
        close = "]" + m.group(1) + "]"
        end = src.find(close, i + m.end())
        return len(src) if end < 0 else end + len(close)
    return i


def _type_end(src: str, i: int, multiline: bool = False) -> int:
    """Return the index where a type expression starting at i ends."""
    depth = 0
    j = i
    while j < len(src):
        c = src[j]
        if c == "\n" and depth == 0 and not multiline:
            return j
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            if src[j - 1 : j + 1] == "->":  # function type arrow, not a closing bracket
                j += 1
                continue
            if depth == 0:
                return j
            depth -= 1
            if depth == 0 and multiline and c == "}":
                return j + 1
        elif depth == 0 and c in ",=;" and src[j : j + 2] != "==":
            return j
        elif depth == 0 and src.startswith("..", j):
            return j
        elif depth == 0:
            m = _IDENT.match(src, j)
            if m:
                if m.group(0) in _STOP_WORDS and j > i:
                    return j
                j = m.end()
                continue
        j += 1
    return j


def luau_to_lua(text: str) -> str:
    """Blank out Luau-only syntax so the Lua grammar can parse the file."""
    src = text
    out = list(src)

    def blank_range(a: int, b: int) -> None:
        for k in range(a, min(b, len(out))):
            if out[k] != "\n":
                out[k] = " "

    i = 0
    paren_stack: list[str] = []  # "params" for a function parameter list, "" otherwise
    after_params = False  # just closed a function parameter list (return type may follow)
    in_local = False  # inside `local a, b` before `=` / end of line
    line_start = True
    while i < len(src):
        j = _skip_string_or_comment(src, i)
        if j != i:
            i = j
            line_start = False
            continue
        c = src[i]

        if c == "`":  # interpolated string -> plain empty string of the same width
            end = src.find("`", i + 1)
            end = len(src) - 1 if end < 0 else end
            blank_range(i, end + 1)
            out[i] = '"'
            out[i + 1] = '"'
            i = end + 1
            continue

        if c == "\n":
            in_local = False
            after_params = False
            line_start = True
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue

        # `type X = ...` / `export type X = ...` declarations at the start of a statement
        if line_start:
            m = re.match(r"(export\s+)?type\s+[A-Za-z_]", src[i:])
            if m:
                eq = src.find("=", i)
                end = _type_end(src, eq + 1, multiline=True)
                blank_range(i, end)
                i = end
                line_start = False
                continue
        line_start = False

        if src.startswith("::", i):  # cast
            end = _type_end(src, i + 2)
            blank_range(i, end)
            i = end
            continue

        m = _IDENT.match(src, i)
        if m:
            word = m.group(0)
            prev = src[i - 1] if i > 0 else ""
            if prev not in ".:":
                if word in ("local", "for"):
                    in_local = True  # names may carry `: Type` until `=` / `in`
                elif word == "in":
                    in_local = False
                elif word == "function":
                    nxt = src.find("(", m.end())
                    if nxt >= 0:
                        blank_range(m.end(), m.end())  # nothing to do; params handled at "("
                        paren_stack.append("pending_params")
                elif word == "continue" and re.match(r"\s*(end|\n|$)", src[m.end():]):
                    blank_range(i, m.end())
            i = m.end()
            continue

        if c == "(":
            if paren_stack and paren_stack[-1] == "pending_params":
                paren_stack[-1] = "params"
            else:
                paren_stack.append("")
            after_params = False
            i += 1
            continue
        if c == ")":
            kind = paren_stack.pop() if paren_stack else ""
            after_params = kind == "params"
            i += 1
            continue

        if c == ":" and src[i + 1 : i + 2] != ":":
            in_params = bool(paren_stack) and paren_stack[-1] == "params"
            if in_params or in_local or after_params:
                end = _type_end(src, i + 1)
                blank_range(i, end)
                after_params = False
                i = end
                continue

        if c == "=" and src[i + 1 : i + 2] != "=":
            in_local = False
        if c in "+-*/" and src[i + 1 : i + 2] == "=" and src[i - 1 : i] != "=":
            out[i] = " "  # `x += 1` -> `x  = 1` (structure only; the value does not matter)
        if c == "." and src[i : i + 3] == "..=":
            out[i] = out[i + 1] = " "
            i += 3
            continue
        after_params = False
        i += 1

    result = "".join(out)
    # if-expressions: `= if a then b else c` -> `= (a) and (b) or (c)` on one line
    result = re.sub(
        r"(=|\(|,|return)(\s*)if\b(.+?)\bthen\b(.+?)\belse\b(.+)",
        lambda mm: "{}{} ({}) and ({}) or {}".format(
            mm.group(1),
            mm.group(2),
            mm.group(3),
            re.sub(r"\belseif\b(.+?)\bthen\b", r") or (\1) and (", mm.group(4)),
            mm.group(5),
        ),
        result,
    )
    # Multi-line if-expressions:  `x = if a` / `then b` / `else c`  ->  `x = (a)` / `and b` / `or c`
    lines = result.split("\n")
    pending = False
    for idx, line in enumerate(lines):
        m = re.match(r"^(.*(?:=|\(|,|return)\s*)if\b(.*)$", line)
        if m and not re.search(r"\bthen\b", m.group(2)) and not re.match(r"^\s*(if|elseif)\b", line):
            lines[idx] = f"{m.group(1)}({m.group(2).rstrip()})"
            pending = True
        elif pending and re.match(r"^\s*then\b", line):
            lines[idx] = re.sub(r"^(\s*)then\b", r"\1and", line)
        elif pending and re.match(r"^\s*else\b", line):
            lines[idx] = re.sub(r"^(\s*)else\b", r"\1or", line)
            pending = False
    return "\n".join(lines)


def _luau_files() -> list[Path]:
    return sorted(p for p in (ROOT / "src").rglob("*.luau"))


def check() -> int:
    import tree_sitter
    import tree_sitter_lua

    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_lua.language()))
    bad = 0
    for path in _luau_files():
        text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
        converted = luau_to_lua(text)
        assert converted.count("\n") == text.count("\n"), f"line count changed in {path}"
        tree = parser.parse(converted.encode("utf-8"))
        if tree.root_node.has_error:
            bad += 1
            first = _first_error(tree.root_node)
            line = first.start_point[0] + 1 if first else "?"
            print(f"  still failing: {path.relative_to(ROOT)} (line {line})")
            if first is not None:
                print("    " + converted.split("\n")[first.start_point[0]].strip())
    print(f"{len(_luau_files()) - bad}/{len(_luau_files())} .luau files parse cleanly as Lua")
    return 1 if bad else 0


def _first_error(node):
    if node.type == "ERROR" or node.is_missing:
        return node
    for child in node.children:
        if child.has_error:
            found = _first_error(child)
            if found is not None:
                return found
    return None


def _install_luau_extractor() -> None:
    import graphify.extract as gx

    def extract_luau(path: Path, *args, **kwargs) -> dict:
        text = Path(path).read_text(encoding="utf-8").replace("\r\n", "\n")
        source = luau_to_lua(text).encode("utf-8")
        return gx._extract_generic(Path(path), gx._LUA_CONFIG, source_override=source)

    gx._DISPATCH[".luau"] = extract_luau


def main() -> int:
    args = sys.argv[1:]
    if "--check" in args:
        return check()

    # graphify re-launches itself with PYTHONHASHSEED=0 (stable clustering), which
    # would drop our patch. Start this script that way instead so it never needs to.
    if os.environ.get("PYTHONHASHSEED") != "0":
        import subprocess

        env = {**os.environ, "PYTHONHASHSEED": "0"}
        return subprocess.run([sys.executable, str(Path(__file__).resolve()), *args], env=env).returncode

    os.chdir(ROOT)
    # Patches don't reach spawned worker processes, so extract in this process.
    os.environ["GRAPHIFY_MAX_WORKERS"] = "1"
    if "--full" in args:
        # Forget what was extracted before so every file is re-parsed with the converter
        shutil.rmtree(ROOT / "graphify-out" / "cache" / "ast", ignore_errors=True)
        (ROOT / "graphify-out" / "manifest.json").unlink(missing_ok=True)
    _install_luau_extractor()

    from graphify.__main__ import main as graphify_main

    sys.argv = ["graphify", "update", "."]
    try:
        graphify_main()
    except SystemExit as exc:
        return int(exc.code or 0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
