#!/usr/bin/env bash
# Remove files installed by install.sh.
set -euo pipefail

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site"
PACK_NAME="offline"
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [options]

Options:
  --prefix DIR       Same prefix used during install
  --pack-name NAME   Same pack name used during install (default: offline)
  --dry-run          Print actions without deleting files
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --pack-name) PACK_NAME="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

remove_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] rm -rf %s\n' "$path"
    else
      printf 'Removing %s\n' "$path"
      rm -rf "$path"
    fi
  else
    printf 'Skip (not found): %s\n' "$path"
  fi
}

START="$PREFIX/pack/$PACK_NAME/start"
remove_path "$START/opencode.nvim"
remove_path "$START/snacks.nvim"
remove_path "$NVIM_CONFIG_DIR/plugin/opencode-keymaps.lua"

if [[ -d "$START" ]] && [[ -z "$(ls -A "$START" 2>/dev/null || true)" ]]; then
  remove_path "$START"
fi
PACK_DIR="$PREFIX/pack/$PACK_NAME"
if [[ -d "$PACK_DIR" ]] && [[ -z "$(ls -A "$PACK_DIR" 2>/dev/null || true)" ]]; then
  remove_path "$PACK_DIR"
fi

printf 'Done.\n'
