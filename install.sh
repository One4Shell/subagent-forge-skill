#!/usr/bin/env bash
# install.sh — installs the subagent-forge skill without requiring npm.
#
# Usage:
#   ./install.sh [--dir <path>] [--path <path>] [--global] [--claude] [--force]
#   curl -fsSL https://raw.githubusercontent.com/One4Shell/subagent-forge-skill/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/One4Shell/subagent-forge-skill/main/install.sh | bash -s -- --global
set -euo pipefail

SUBAGENT_FORGE_REPO="${SUBAGENT_FORGE_REPO:-<your-org>/subagent-forge-skill}"
SUBAGENT_FORGE_BRANCH="${SUBAGENT_FORGE_BRANCH:-main}"

TARGET_DIR="$(pwd)"
INSTALL_PATH=".agents/skills/subagent-forge"
FORCE=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --dir <path>     Project root to install into (default: current directory)
  --path <path>    Custom install path, relative to --dir
                    (default: .agents/skills/subagent-forge)
  --global         Install into ~/.agents/skills/subagent-forge instead
  --claude         Shorthand for --path .claude/skills/subagent-forge
  --force          Overwrite existing files (default: skip files that already exist)
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --path) INSTALL_PATH="$2"; shift 2 ;;
    --global) TARGET_DIR="$HOME"; INSTALL_PATH=".agents/skills/subagent-forge"; shift ;;
    --claude) INSTALL_PATH=".claude/skills/subagent-forge"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

DEST="${TARGET_DIR%/}/${INSTALL_PATH}"
mkdir -p "$DEST"

copy_tree() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  while IFS= read -r -d '' file; do
    local rel="${file#"$src"/}"
    case "$rel" in
      *__pycache__*|*.pyc|*.pyo|*.rendered|.DS_Store|.gitkeep) continue ;;
    esac
    local out="$dst/$rel"
    mkdir -p "$(dirname "$out")"
    if [[ -e "$out" && $FORCE -eq 0 ]]; then
      echo "skip (exists): $rel"
    else
      cp "$file" "$out"
      echo "install: $rel"
    fi
  done < <(find "$src" -type f -print0)
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
LOCAL_SRC="${SCRIPT_DIR}/skills/subagent-forge"

if [[ -d "$LOCAL_SRC" ]]; then
  # Running from a local checkout — no network needed.
  copy_tree "$LOCAL_SRC" "$DEST"
else
  # Running via curl | bash — fetch a tarball of just this subtree.
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Fetching ${SUBAGENT_FORGE_REPO}@${SUBAGENT_FORGE_BRANCH}..."
  curl -fsSL "https://codeload.github.com/${SUBAGENT_FORGE_REPO}/tar.gz/refs/heads/${SUBAGENT_FORGE_BRANCH}" \
    -o "$TMP/subagent-forge.tar.gz"
  tar -xzf "$TMP/subagent-forge.tar.gz" -C "$TMP"
  REPO_ROOT="$(find "$TMP" -maxdepth 1 -type d -name '*-*' | head -n1)"
  copy_tree "${REPO_ROOT}/skills/subagent-forge" "$DEST"
fi

echo
echo "subagent-forge installed to: $DEST"
echo "Point pi at this project and ask it to create or refine a specialized subagent."
