#!/usr/bin/env bash
# Offline installer for opencode.nvim (and optionally snacks.nvim).
# Does not require network access.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$ROOT/vendor"
DIST="$ROOT/dist"

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site"
PACK_NAME="offline"
WITH_SNACKS=0
USE_BUNDLE=0
DRY_RUN=0
DEST_OVERRIDE=""
INSTALL_KEYMAPS=0
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Install opencode.nvim from this offline package into Neovim's packpath
so it loads on startup without a plugin manager.

Options:
  --prefix DIR       Neovim site prefix
                     (default: $XDG_DATA_HOME/nvim/site or ~/.local/share/nvim/site)
  --pack-name NAME   pack/<NAME>/start pack name (default: offline)
  --dest DIR         Install the plugin into DIR instead of packpath
  --with-snacks      Also install snacks.nvim (optional UI enhancement)
  --with-keymaps     Copy example keymaps into ~/.config/nvim/plugin/
  --bundle           Clone from dist/*.gitbundle (keeps git metadata)
  --dry-run          Print actions without writing files
  -h, --help         Show this help

Examples:
  ./install.sh
  ./install.sh --with-snacks --with-keymaps
  ./install.sh --dest ~/.local/share/nvim/lazy/opencode.nvim
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
    --prefix) PREFIX="$2"; shift 2 ;;
    --pack-name) PACK_NAME="$2"; shift 2 ;;
    --dest) DEST_OVERRIDE="$2"; shift 2 ;;
    --with-snacks) WITH_SNACKS=1; shift ;;
    --with-keymaps) INSTALL_KEYMAPS=1; shift ;;
    --bundle) USE_BUNDLE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

pack_start() {
  printf '%s/pack/%s/start' "$PREFIX" "$PACK_NAME"
}

plugin_dest() {
  if [[ -n "$DEST_OVERRIDE" ]]; then
    printf '%s' "$DEST_OVERRIDE"
  else
    printf '%s/opencode.nvim' "$(pack_start)"
  fi
}

snacks_dest() {
  printf '%s/snacks.nvim' "$(pack_start)"
}

extract_or_copy() {
  local name="$1"
  local dest="$2"
  local tarball="$3"

  if [[ -d "$VENDOR/$name" ]]; then
    log "Copy $name from vendor/"
    run mkdir -p "$(dirname "$dest")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] rm -rf %s && cp -a %s %s\n' "$dest" "$VENDOR/$name" "$dest"
    else
      rm -rf "$dest"
      mkdir -p "$(dirname "$dest")"
      cp -a "$VENDOR/$name" "$dest"
    fi
    return
  fi

  if [[ -f "$tarball" ]]; then
    log "Extract $name from $(basename "$tarball")"
    run mkdir -p "$(dirname "$dest")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] tar -xzf %s -C %s\n' "$tarball" "$(dirname "$dest")"
    else
      rm -rf "$dest"
      local tmp
      tmp="$(mktemp -d)"
      tar -xzf "$tarball" -C "$tmp"
      mkdir -p "$(dirname "$dest")"
      mv "$tmp/$name" "$dest"
      rm -rf "$tmp"
    fi
    return
  fi

  printf 'error: missing %s (looked in vendor/ and dist/)\n' "$name" >&2
  exit 1
}

install_from_bundle() {
  local dest
  dest="$(plugin_dest)"
  local bundle="$DIST/opencode.nvim-v1.0.0.gitbundle"
  if [[ ! -f "$bundle" ]]; then
    printf 'error: git bundle not found: %s\n' "$bundle" >&2
    exit 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    printf 'error: git is required for --bundle\n' >&2
    exit 1
  fi
  log "Clone opencode.nvim from git bundle (tag v1.0.0)"
  run mkdir -p "$(dirname "$dest")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] git clone %s %s && git -C %s checkout -B v1.0.0-local v1.0.0\n' "$bundle" "$dest" "$dest"
  else
    rm -rf "$dest"
    git -c advice.detachedHead=false clone --quiet "$bundle" "$dest"
    git -C "$dest" checkout -q -B v1.0.0-local v1.0.0
  fi
}

install_plugin() {
  if [[ "$USE_BUNDLE" -eq 1 ]]; then
    install_from_bundle
  else
    extract_or_copy "opencode.nvim" "$(plugin_dest)" "$DIST/opencode.nvim-v1.0.0.tar.gz"
  fi
}

install_snacks() {
  extract_or_copy "snacks.nvim" "$(snacks_dest)" "$DIST/snacks.nvim-optional.tar.gz"
}

install_keymaps() {
  local src="$ROOT/examples/init.lua"
  local dest="$NVIM_CONFIG_DIR/plugin/opencode-keymaps.lua"
  log "Install example keymaps -> $dest"
  run mkdir -p "$(dirname "$dest")"
  run cp "$src" "$dest"
}

verify_layout() {
  local dest
  dest="$(plugin_dest)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return
  fi
  if [[ ! -f "$dest/lua/opencode.lua" ]]; then
    printf 'error: lua/opencode.lua missing under %s\n' "$dest" >&2
    exit 1
  fi
  if [[ ! -d "$dest/plugin" ]]; then
    printf 'error: plugin/ missing under %s\n' "$dest" >&2
    exit 1
  fi
}

print_next_steps() {
  local dest
  dest="$(plugin_dest)"
  cat <<EOF

Installed:
  opencode.nvim -> $dest
EOF
  if [[ "$WITH_SNACKS" -eq 1 ]]; then
    printf '  snacks.nvim    -> %s\n' "$(snacks_dest)"
  fi
  cat <<'EOF'

Runtime requirements (not bundled — install on the target machine):
  - Neovim 0.11+ recommended (plugin uses vim.pack-era APIs / vim.uv)
  - opencode CLI >= 1.17  (must be in $PATH)
  - curl
  - pgrep and lsof (Unix, unless vim.g.opencode_opts.server.url is set)

Add this to your Neovim config (or use --with-keymaps):

  vim.g.opencode_opts = {}
  vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ") end)
  vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end)

If you also installed snacks.nvim, enable its input/picker:

  require("snacks").setup({
    input = { enabled = true },
    picker = { enabled = true },
  })

Verify after launching Neovim:
  :checkhealth opencode
EOF
}

log "opencode.nvim offline installer"
install_plugin
if [[ "$WITH_SNACKS" -eq 1 ]]; then
  if [[ -n "$DEST_OVERRIDE" ]]; then
    printf 'error: --with-snacks cannot be combined with --dest (snacks uses packpath)\n' >&2
    printf 'Install snacks separately: omit --dest, or copy vendor/snacks.nvim yourself.\n' >&2
    exit 2
  fi
  install_snacks
fi
if [[ "$INSTALL_KEYMAPS" -eq 1 ]]; then
  install_keymaps
fi
verify_layout
print_next_steps
