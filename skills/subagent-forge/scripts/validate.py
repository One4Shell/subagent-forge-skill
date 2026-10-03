#!/usr/bin/env python3
"""validate.py — lint pi-subagents agent definitions.

Checks the frontmatter, enums, tool allowlist, discovery path and referenced
helper scripts of one or more `agent.md` files. Exits non-zero when errors are
found.

Usage:
    python3 validate.py <path>            # agent dir or agent.md file
    python3 validate.py --all <dir>       # every agent.md under <dir> (recursive)
    python3 validate.py --strict <path>   # warnings also fail
    python3 validate.py --json <path>     # machine-readable output
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - fallback path
    yaml = None

NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SCRIPT_REF_RE = re.compile(r"scripts/([A-Za-z0-9._-]+)")

KNOWN_TOOLS = {
    "read", "grep", "find", "ls", "bash", "edit", "write",
    "subagent", "contact_supervisor",
}
VALID_THINKING = {"low", "medium", "high"}
VALID_PROMPT_MODE = {"replace", "append"}
VALID_CONTEXT = {"fresh", "fork"}
DISCOVERY_MARKERS = (".pi/agents", ".pi/agent/agents", ".agents/agents", ".agents/skills", ".claude")
PLACEHOLDER_MARKERS = ("TODO:", "describe what this agent does")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.notes: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def note(self, msg: str) -> None:
        self.notes.append(msg)

    @property
    def ok(self) -> bool:
        return not self.errors


def fallback_parse(text: str) -> dict:
    """Very small YAML subset parser used only when PyYAML is unavailable."""
    result: dict = {}
    stack: list[tuple[int, dict]] = [(-1, result)]
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        line = raw.strip()
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        if not value:
            child: dict = {}
            stack[-1][1][key] = child
            stack.append((indent, child))
            continue
        if value.startswith("'") and value.endswith("'") and len(value) >= 2:
            value = value[1:-1].replace("''", "'")
        elif value.startswith('"') and value.endswith('"') and len(value) >= 2:
            value = value[1:-1]
        elif value.lower() in ("true", "false"):
            value = value.lower() == "true"
        stack[-1][1][key] = value
    return result


def split_frontmatter(text: str) -> tuple[str | None, str]:
    """Return (frontmatter_text, body). frontmatter_text is None if absent."""
    if not text.startswith("---"):
        return None, text
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, text
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return None, text
    return "\n".join(lines[1:end]), "\n".join(lines[end + 1:]).lstrip("\n")


def as_list(value) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value]
    return [part.strip() for part in str(value).split(",") if part.strip()]


def validate_agent(path: Path, report: Report) -> None:
    label = str(path)
    if not path.is_file():
        report.error(f"{label}: file not found")
        return

    text = path.read_text(encoding="utf-8")
    fm_text, body = split_frontmatter(text)
    if fm_text is None:
        report.error(f"{label}: missing or malformed YAML frontmatter (--- ... ---)")
        return

    if yaml is not None:
        try:
            data = yaml.safe_load(fm_text) or {}
        except yaml.YAMLError as exc:  # type: ignore[attr-defined]
            report.error(f"{label}: YAML parse error: {exc}")
            return
        if not isinstance(data, dict):
            report.error(f"{label}: frontmatter must be a YAML mapping")
            return
    else:
        data = fallback_parse(fm_text)

    # --- name ---
    name = data.get("name")
    if not name:
        report.error(f"{label}: missing required field 'name'")
    else:
        name = str(name)
        if not NAME_RE.match(name):
            report.error(f"{label}: invalid name '{name}' (use [a-z0-9-], no leading/trailing/double hyphens)")
        if len(name) > 64:
            report.error(f"{label}: name exceeds 64 characters")
        expected = path.parent.name if path.name == "agent.md" else path.stem
        if expected and name != expected:
            report.warn(f"{label}: name '{name}' does not match directory/file '{expected}'")

    # --- description ---
    description = data.get("description")
    if not description:
        report.error(f"{label}: missing required field 'description'")
    else:
        description = str(description).strip()
        if len(description) > 1024:
            report.error(f"{label}: description exceeds 1024 characters")
        if len(description) < 20:
            report.warn(f"{label}: description is very short; it drives agent routing")
        low = description.lower()
        if any(marker.lower() in low for marker in PLACEHOLDER_MARKERS):
            report.warn(f"{label}: description still looks like a placeholder")

    # --- enums ---
    thinking = data.get("thinking")
    if thinking is not None and str(thinking) not in VALID_THINKING:
        report.warn(f"{label}: unknown thinking '{thinking}' (expected one of {sorted(VALID_THINKING)})")

    mode = data.get("systemPromptMode")
    if mode is None:
        report.warn(f"{label}: 'systemPromptMode' not set (recommended: replace for specialized agents)")
    elif str(mode) not in VALID_PROMPT_MODE:
        report.error(f"{label}: invalid systemPromptMode '{mode}' (expected replace|append)")

    context = data.get("defaultContext")
    if context is not None and str(context) not in VALID_CONTEXT:
        report.error(f"{label}: invalid defaultContext '{context}' (expected fresh|fork)")

    # --- tools ---
    tools = as_list(data.get("tools"))
    if not tools:
        report.warn(f"{label}: no 'tools' allowlist set")
    for tool in tools:
        if tool not in KNOWN_TOOLS:
            report.warn(f"{label}: unknown tool '{tool}' (known: {', '.join(sorted(KNOWN_TOOLS))})")
    if any(t in tools for t in ("edit", "write")):
        report.note(f"{label}: writer agent (edit/write enabled) — ensure the body declares write boundaries")

    # --- model ---
    model = data.get("model")
    if model is not None and not str(model).strip():
        report.error(f"{label}: 'model' is empty; omit it or use 'inherit'")

    # --- runner ---
    runner = data.get("runner")
    if isinstance(runner, dict):
        rtype = runner.get("type")
        if rtype != "external-cli":
            report.warn(f"{label}: unknown runner.type '{rtype}'")
        else:
            if not runner.get("command"):
                report.error(f"{label}: external-cli runner requires 'command'")
            if data.get("async") is not True:
                report.error(f"{label}: external-cli runner requires 'async: true'")
            native = {"tools", "model", "thinking", "defaultContext", "defaultReads"}
            unsupported = sorted(native & set(data))
            if unsupported:
                report.warn(f"{label}: external-cli runner ignores native Pi fields: {', '.join(unsupported)}")

    # --- body ---
    if not body.strip():
        report.error(f"{label}: empty system prompt body")
    else:
        if "### " not in body:
            report.warn(f"{label}: body has no '### ' sections (recommended: Operational Directives / Output Contract / Boundary Rules)")
        if "json" not in body.lower():
            report.warn(f"{label}: body does not mention a JSON output contract")

    # --- referenced helper scripts ---
    refs = sorted(set(SCRIPT_REF_RE.findall(body + "\n" + fm_text)))
    scripts_dir = path.parent / "scripts"
    for ref in refs:
        script = scripts_dir / ref
        if not script.is_file():
            report.error(f"{label}: referenced script missing: scripts/{ref}")
        elif not os.access(script, os.X_OK):
            report.warn(f"{label}: script not executable: scripts/{ref} (run chmod +x)")

    # --- discovery path ---
    posix = path.as_posix()
    if not any(marker in posix for marker in DISCOVERY_MARKERS):
        report.warn(
            f"{label}: not under a known discovery root "
            "(.pi/agents/<name>/agent.md or ~/.pi/agent/agents/<name>/agent.md)"
        )


def discover(path: Path, all_flag: bool) -> list[Path]:
    if all_flag:
        if not path.is_dir():
            return []
        return sorted(path.rglob("agent.md"))
    if path.is_dir():
        direct = path / "agent.md"
        if direct.is_file():
            return [direct]
        return sorted(path.glob("*.md"))
    return [path]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="validate.py", description="Validate pi-subagents agent definitions.")
    parser.add_argument("path", help="agent directory, agent.md file, or directory with --all")
    parser.add_argument("--all", action="store_true", help="validate every agent.md under path (recursive)")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = parser.parse_args(argv[1:])

    target = Path(args.path)
    if not target.exists():
        print(f"error: path not found: {target}", file=sys.stderr)
        return 2

    targets = discover(target, args.all)
    if not targets:
        print(f"error: no agent definitions found under {target}", file=sys.stderr)
        return 2

    results = []
    failed = 0
    for agent in targets:
        report = Report()
        validate_agent(agent, report)
        if not report.ok or (args.strict and report.warnings):
            failed += 1
        results.append((agent, report))

    if args.json:
        payload = {
            "agents": [
                {
                    "path": str(agent),
                    "ok": report.ok and not (args.strict and report.warnings),
                    "errors": report.errors,
                    "warnings": report.warnings,
                    "notes": report.notes,
                }
                for agent, report in results
            ],
            "failed": failed,
            "total": len(results),
        }
        print(json.dumps(payload, indent=2))
    else:
        for agent, report in results:
            status = "FAIL" if (not report.ok or (args.strict and report.warnings)) else "PASS"
            print(f"[{status}] {agent}")
            for note in report.notes:
                print(f"  note: {note}")
            for warning in report.warnings:
                print(f"  warn: {warning}")
            for error in report.errors:
                print(f"  ERROR: {error}")
        print()
        print(f"{len(results) - failed}/{len(results)} agent(s) passed")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
