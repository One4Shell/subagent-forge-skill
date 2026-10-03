#!/usr/bin/env bash
# init.sh — scaffold a pi-subagents agent directory.
#
# Creates <base>/.pi/agents/<name>/agent.md (project scope) or
# <base>/.pi/agent/agents/<name>/agent.md (user scope), optionally with a
# helper script under scripts/.
#
# YAML-safety: the description is rendered as a single-quoted YAML scalar with
# inner single quotes doubled. When python3 is available it is used for the
# substitution; otherwise a bash fallback handles the same escaping.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SKILL_DIR="$(dirname -- "$SCRIPT_DIR")"
ASSETS_DIR="${SKILL_DIR}/assets"

NAME=""
DESCRIPTION=""
SCOPE="project"
BASE_DIR=""
TOOLS="read, grep, find, ls"
THINKING="high"
CONTEXT="fresh"
SYSTEM_PROMPT_MODE="replace"
ALIASES="[]"
WITH_SCRIPT=""
FORCE=0

usage() {
  cat <<'EOF'
Usage: init.sh --name <agent-name> [options]

Required:
  --name <name>                Agent name (lowercase, hyphens, [a-z0-9-], <=64)

Common options:
  --description <text>         What the agent does and when to use it
  --scope project|user         Install scope (default: project)
  --dir <path>                 Base directory (default: cwd for project, $HOME for user)
  --tools <list>               Tool allowlist (default: "read, grep, find, ls")
  --thinking low|medium|high   (default: high)
  --context fresh|fork         (default: fresh)
  --system-prompt-mode replace|append   (default: replace)
  --aliases <list>             Alternative names (default: none)
  --with-script sh|py          Also create a helper script stub
  --force                      Overwrite an existing agent directory
  -h, --help                   Show this help
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --description) DESCRIPTION="${2:-}"; shift 2 ;;
    --scope) SCOPE="${2:-}"; shift 2 ;;
    --dir) BASE_DIR="${2:-}"; shift 2 ;;
    --tools) TOOLS="${2:-}"; shift 2 ;;
    --thinking) THINKING="${2:-}"; shift 2 ;;
    --context) CONTEXT="${2:-}"; shift 2 ;;
    --system-prompt-mode) SYSTEM_PROMPT_MODE="${2:-}"; shift 2 ;;
    --aliases) ALIASES="${2:-}"; shift 2 ;;
    --with-script) WITH_SCRIPT="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[[ -n "$NAME" ]] || die "--name is required"
[[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "invalid --name '$NAME': use lowercase letters, digits and single hyphens"
[[ ${#NAME} -le 64 ]] || die "--name must be <=64 characters"
[[ -n "$DESCRIPTION" ]] || DESCRIPTION="TODO: describe what this agent does and when to use it."
[[ "$SCOPE" == "project" || "$SCOPE" == "user" ]] || die "--scope must be 'project' or 'user'"
[[ "$THINKING" =~ ^(low|medium|high)$ ]] || die "--thinking must be low, medium or high"
[[ "$CONTEXT" =~ ^(fresh|fork)$ ]] || die "--context must be 'fresh' or 'fork'"
[[ "$SYSTEM_PROMPT_MODE" =~ ^(replace|append)$ ]] || die "--system-prompt-mode must be 'replace' or 'append'"
case "$WITH_SCRIPT" in ""|sh|py) ;; *) die "--with-script must be 'sh' or 'py'" ;; esac

# --- resolve destination -----------------------------------------------------
if [[ -z "$BASE_DIR" ]]; then
  if [[ "$SCOPE" == "project" ]]; then
    BASE_DIR="$(pwd)"
  else
    BASE_DIR="$HOME"
  fi
fi
[[ -d "$BASE_DIR" ]] || die "--dir '$BASE_DIR' is not a directory"

if [[ "$SCOPE" == "project" ]]; then
  DEST="${BASE_DIR%/}/.pi/agents/${NAME}"
  DISCOVERY_ROOT=".pi/agents"
else
  DEST="${BASE_DIR%/}/.pi/agent/agents/${NAME}"
  DISCOVERY_ROOT="~/.pi/agent/agents"
fi

if [[ -e "$DEST" && $FORCE -eq 0 ]]; then
  die "destination already exists: $DEST (use --force to overwrite)"
fi
mkdir -p "$DEST"

# --- derived body values -----------------------------------------------------
ROLE="$DESCRIPTION"
DIRECTIVE_1="Segui il compito assegnato dal parent e resta nel tuo scope."
DIRECTIVE_2="Prima di dichiarare completato, verifica il risultato e riporta le evidenze (comandi ed exit code)."
DIRECTIVE_3="Se il compito è ambiguo o fuori scope, fermati e riporta il blocker."
if [[ "$WITH_SCRIPT" == "sh" ]]; then
  DIRECTIVE_3="Per la verifica, esegui \`bash scripts/check.sh <arg>\` (exit code 0 = successo) e riporta l'evidenza."
elif [[ "$WITH_SCRIPT" == "py" ]]; then
  DIRECTIVE_3="Per la verifica, esegui \`python3 scripts/check.py <arg>\` (exit code 0 = successo) e riporta l'evidenza."
fi
if [[ "$TOOLS" == *edit* || "$TOOLS" == *write* ]]; then
  BOUNDARY_1="Scrivi solo nella superficie concordata; se ti serve scrivere altro, escala al parent."
else
  BOUNDARY_1="Sei READ-ONLY: non modificare file; esegui solo comandi non distruttivi."
fi

TEMPLATE="${ASSETS_DIR}/agent-template.md.tmpl"
[[ -f "$TEMPLATE" ]] || die "template not found: $TEMPLATE"

OUT="${DEST}/agent.md"

# --- render ------------------------------------------------------------------
TMP_TEMPLATE="$(mktemp)"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_TEMPLATE" "$TMP_OUT"' EXIT
cp "$TEMPLATE" "$TMP_TEMPLATE"

render() {
  # $1=file, then K=V pairs for KEY VALUE substitution
  local file="$1"; shift
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$@" <<'PY'
import sys

path = sys.argv[1]
pairs = {}
for arg in sys.argv[2:]:
    key, _, value = arg.partition("=")
    pairs[key] = value

with open(path, encoding="utf-8") as fh:
    text = fh.read()

for key, value in pairs.items():
    if key == "__DESCRIPTION__":
        value = value.replace("'", "''")
    text = text.replace(key, value)

sys.stdout.write(text)
PY
  else
    local text
    text="$(cat "$file")"
    local pair key value
    for pair in "$@"; do
      key="${pair%%=*}"
      value="${pair#*=}"
      if [[ "$key" == "__DESCRIPTION__" ]]; then
        value="${value//\'/\'\'}"
      fi
      text="${text//"$key"/$value}"
    done
    printf '%s' "$text"
  fi
}

render "$TMP_TEMPLATE" \
  "__NAME__=$NAME" \
  "__DESCRIPTION__=$DESCRIPTION" \
  "__ALIASES__=$ALIASES" \
  "__THINKING__=$THINKING" \
  "__CONTEXT__=$CONTEXT" \
  "__SYSTEM_PROMPT_MODE__=$SYSTEM_PROMPT_MODE" \
  "__TOOLS__=$TOOLS" \
  "__ROLE__=$ROLE" \
  "__DIRECTIVE_1__=$DIRECTIVE_1" \
  "__DIRECTIVE_2__=$DIRECTIVE_2" \
  "__DIRECTIVE_3__=$DIRECTIVE_3" \
  "__BOUNDARY_1__=$BOUNDARY_1" > "$OUT"

echo "created: $OUT"

# --- optional helper script --------------------------------------------------
if [[ -n "$WITH_SCRIPT" ]]; then
  mkdir -p "${DEST}/scripts"
  if [[ "$WITH_SCRIPT" == "sh" ]]; then
    SRC="${ASSETS_DIR}/helper-script.sh.tmpl"
    DST="${DEST}/scripts/check.sh"
    SCRIPT_NAME="check.sh"
  else
    SRC="${ASSETS_DIR}/helper-script.py.tmpl"
    DST="${DEST}/scripts/check.py"
    SCRIPT_NAME="check.py"
  fi
  [[ -f "$SRC" ]] || die "helper template not found: $SRC"
  cp "$SRC" "$DST"
  render "$DST" \
    "__DESCRIPTION__=Helper script for the ${NAME} agent." \
    "__SCRIPT_NAME__=${SCRIPT_NAME}" > "${DST}.rendered"
  mv "${DST}.rendered" "$DST"
  chmod +x "$DST"
  echo "created: $DST"
fi

# --- next steps --------------------------------------------------------------
cat <<EOF

Agent scaffolded at: $DEST
Discovery root:      ${DISCOVERY_ROOT}/**

Next steps:
  1. Fill in the body of agent.md (directives, output contract, boundaries).
  2. Validate:  python3 "${SCRIPT_DIR}/validate.py" "$DEST"
  3. Verify discovery:  subagent({ action: "list" })
EOF

if [[ "$SCOPE" == "project" ]]; then
  cat <<EOF

Optional model override in .pi/settings.json:
  {
    "subagents": {
      "agentOverrides": {
        "${NAME}": { "model": "inherit" }
      }
    }
  }
EOF
fi
