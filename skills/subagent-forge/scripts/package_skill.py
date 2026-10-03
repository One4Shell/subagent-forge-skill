#!/usr/bin/env python3
"""package_skill.py — package the subagent-forge skill into a distributable archive.

Usage:
    python3 package_skill.py <path-to-skill-dir> [--out <output.zip>]

Produces a zip archive containing the skill's directory tree (SKILL.md plus
scripts/, references/ and assets/), rooted at the skill's own folder name, so
it can be unzipped straight into a .agents/skills/ or .claude/skills/ directory.
"""
from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

SKIP_NAMES = {".gitkeep", ".DS_Store", "__pycache__"}
SKIP_SUFFIXES = {".pyc", ".rendered"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("skill_dir", type=Path)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    skill_dir = args.skill_dir.resolve()
    if not (skill_dir / "SKILL.md").exists():
        print(f"Error: {skill_dir} has no SKILL.md", file=sys.stderr)
        return 1

    out_path = args.out or skill_dir.parent / f"{skill_dir.name}.skill"

    count = 0
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(skill_dir.rglob("*")):
            if f.is_dir() or f.name in SKIP_NAMES or f.suffix in SKIP_SUFFIXES:
                continue
            arcname = Path(skill_dir.name) / f.relative_to(skill_dir)
            zf.write(f, arcname)
            count += 1

    print(f"Wrote {out_path} ({count} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
