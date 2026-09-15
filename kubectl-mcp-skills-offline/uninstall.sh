#!/usr/bin/env bash
# Remove kubectl-mcp-skills-offline installs from agent skill dirs and --prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$ROOT/catalog.txt"

TARGETS="all"
PROJECT=""
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/kubectl-mcp-skills"
DRY_RUN=0
KEEP_PREFIX=0

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [options]

Remove k8s-* skills installed by install.sh.

Options:
  --target LIST      claude,cursor,opencode,agents,all  (default: all)
  --project DIR      Project-local dirs to clean
  --prefix DIR       Canonical store to remove
                     (default: ~/.local/share/kubectl-mcp-skills)
  --keep-prefix      Only unlink agent dirs; keep the canonical store
  --dry-run          Print actions without deleting
  -h, --help
EOF
}

log() { printf '==> %s\n' "$*"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGETS="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --keep-prefix) KEEP_PREFIX=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

wants_target() {
  local name="$1"
  if [[ "$TARGETS" == "all" ]]; then
    return 0
  fi
  case ",$TARGETS," in
    *",$name,"*) return 0 ;;
    *) return 1 ;;
  esac
}

agent_dirs() {
  if [[ -n "$PROJECT" ]]; then
    local base
    if [[ ! -d "$PROJECT" ]]; then
      return 0
    fi
    base="$(cd "$PROJECT" && pwd)"
    wants_target claude && printf '%s\n' "$base/.claude/skills"
    wants_target cursor && printf '%s\n' "$base/.cursor/skills"
    wants_target agents && printf '%s\n' "$base/.agents/skills"
    wants_target opencode && printf '%s\n' "$base/.opencode/skills"
    return 0
  fi
  wants_target claude && printf '%s\n' "${HOME}/.claude/skills"
  wants_target cursor && printf '%s\n' "${HOME}/.cursor/skills"
  wants_target agents && printf '%s\n' "${HOME}/.agents/skills"
  wants_target opencode && printf '%s\n' "${HOME}/.config/opencode/skills"
}

skill_names() {
  if [[ -f "$PREFIX/installed-skills.txt" ]]; then
    cat "$PREFIX/installed-skills.txt"
    return 0
  fi
  awk -F '\t' '/^[^#]/ && NF>=1 {print $1}' "$CATALOG"
}

while IFS= read -r dest_root; do
  [[ -z "$dest_root" || ! -d "$dest_root" ]] && continue
  log "clean $dest_root"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    dest="$dest_root/$name"
    if [[ -e "$dest" || -L "$dest" ]]; then
      run rm -rf "$dest"
    fi
  done < <(skill_names)
done < <(agent_dirs)

if [[ "$KEEP_PREFIX" -eq 0 ]]; then
  if [[ -e "$PREFIX/.kubectl-mcp-skills-offline-stamp" || -d "$PREFIX/skills" ]]; then
    log "remove canonical store $PREFIX"
    run rm -rf "$PREFIX"
  fi
fi

log "uninstall complete"
