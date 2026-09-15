#!/usr/bin/env bash
# Offline installer for kubectl-mcp-server Agent Skills (Kylin V10 SP3 x86_64).
# No network. Does not install the MCP server itself — skills wrapper only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$ROOT/catalog.txt"
VENDOR_SKILLS="$ROOT/vendor/kubernetes-skills/claude"
OVERLAY="$ROOT/overlay"

TARGETS="all"
PROJECT=""
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/kubectl-mcp-skills"
MODE="link"
WITH_KIND=0
WITH_SAFETY=1
SKILLS_SET="25"
DRY_RUN=0
FORCE=0
INSTALL_MCP_EXAMPLES=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Install 25 Kubernetes Agent Skills (9 categories) plus the k8s-safety
overlay into Claude Code / Cursor / OpenCode skill directories.
This package is a skill wrapper, not a new MCP server.

Options:
  --target LIST      claude,cursor,opencode,agents,all  (default: all)
  --project DIR      Project-local install (.claude/skills, .cursor/skills, …)
  --prefix DIR       Canonical skill store
                     (default: $XDG_DATA_HOME/kubectl-mcp-skills
                      or ~/.local/share/kubectl-mcp-skills)
  --mode copy|link   Copy files or symlink agent dirs to --prefix (default: link)
  --with-kind        Also install upstream k8s-kind (26th skill)
  --no-safety        Skip the k8s-safety overlay (not recommended)
  --skills 25|all    25 = advertised catalog; all = include k8s-kind
  --mcp-examples     Copy example MCP client configs into --prefix/examples
  --force            Replace existing skill directories
  --dry-run          Print actions without writing
  -h, --help         Show this help

Examples:
  ./install.sh
  ./install.sh --target claude,cursor
  ./install.sh --project /opt/apps/my-repo
  ./install.sh --prefix /opt/kubectl-mcp-skills --mode copy
EOF
}

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*" >&2; }

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
    --mode)
      MODE="$2"
      shift 2
      ;;
    --with-kind) WITH_KIND=1; SKILLS_SET="all"; shift ;;
    --no-safety) WITH_SAFETY=0; shift ;;
    --skills) SKILLS_SET="$2"; shift 2 ;;
    --mcp-examples) INSTALL_MCP_EXAMPLES=1; shift ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$MODE" != "copy" && "$MODE" != "link" ]]; then
  printf 'Invalid --mode %s (copy|link)\n' "$MODE" >&2
  exit 2
fi

if [[ "$SKILLS_SET" == "all" ]]; then
  WITH_KIND=1
fi

[[ -f "$CATALOG" ]] || { printf 'Missing %s\n' "$CATALOG" >&2; exit 1; }
[[ -d "$VENDOR_SKILLS" ]] || { printf 'Missing %s\n' "$VENDOR_SKILLS" >&2; exit 1; }

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
  # Prints dest skill-root directories (parent of k8s-*/SKILL.md).
  if [[ -n "$PROJECT" ]]; then
    local base
    mkdir -p "$PROJECT"
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

should_install_skill() {
  local name="$1" flag="$2"
  if [[ "$flag" == "overlay" ]]; then
    [[ "$WITH_SAFETY" -eq 1 ]]
    return $?
  fi
  if [[ "$flag" == "0" ]]; then
    [[ "$WITH_KIND" -eq 1 ]]
    return $?
  fi
  return 0
}

skill_source() {
  local name="$1" flag="$2"
  if [[ "$flag" == "overlay" ]]; then
    printf '%s/%s' "$OVERLAY" "$name"
  else
    printf '%s/%s' "$VENDOR_SKILLS" "$name"
  fi
}

install_one() {
  local src="$1" dest="$2"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      run rm -rf "$dest"
    else
      warn "exists, skip (use --force): $dest"
      return 0
    fi
  fi
  if [[ "$MODE" == "link" ]]; then
    run ln -sfn "$src" "$dest"
  else
    run cp -a "$src" "$dest"
  fi
}

log "canonical store: $PREFIX"
run mkdir -p "$PREFIX/skills"

# Stage selected skills into the canonical store (always copy so prefix is complete).
installed=0
skipped=0
while IFS=$'\t' read -r name category flag || [[ -n "${name:-}" ]]; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  if ! should_install_skill "$name" "$flag"; then
    skipped=$((skipped + 1))
    continue
  fi
  src="$(skill_source "$name" "$flag")"
  if [[ ! -f "$src/SKILL.md" ]]; then
    printf 'Missing SKILL.md: %s\n' "$src" >&2
    exit 1
  fi
  dest="$PREFIX/skills/$name"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] stage %s (%s) -> %s\n' "$name" "$category" "$dest"
  else
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi
  installed=$((installed + 1))
done < "$CATALOG"

log "staged $installed skills into $PREFIX/skills (skipped optional: $skipped)"

if [[ "$INSTALL_MCP_EXAMPLES" -eq 1 ]]; then
  log "MCP example configs -> $PREFIX/examples"
  run mkdir -p "$PREFIX/examples"
  run cp -a "$ROOT/examples/." "$PREFIX/examples/"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  {
    echo "package=kubectl-mcp-skills-offline"
    echo "installed_at=$(date -Iseconds 2>/dev/null || date)"
    echo "prefix=$PREFIX"
    echo "skills_set=$SKILLS_SET"
    echo "with_kind=$WITH_KIND"
    echo "with_safety=$WITH_SAFETY"
    echo "mode=$MODE"
  } > "$PREFIX/.kubectl-mcp-skills-offline-stamp"
  # List staged skill names for uninstall.
  (cd "$PREFIX/skills" && ls -1) > "$PREFIX/installed-skills.txt"
fi

# Link or copy into agent-specific directories.
n_agent=0
while IFS= read -r dest_root; do
  [[ -z "$dest_root" ]] && continue
  log "agent skills dir: $dest_root"
  run mkdir -p "$dest_root"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    n_agent=$((n_agent + 1))
    continue
  fi
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    install_one "$PREFIX/skills/$name" "$dest_root/$name"
  done < "$PREFIX/installed-skills.txt"
  n_agent=$((n_agent + 1))
done < <(agent_dirs)

log "updated $n_agent agent skill directories (mode=$MODE)"
log "done. This did not install kubectl-mcp-server; only Agent Skills."
log "MCP examples: $ROOT/examples/mcp/  (use --read-only for investigation)"
