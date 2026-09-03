#!/usr/bin/env bash
# Offline installer for opencode.nvim (and optionally snacks.nvim).
# Does not require network access.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$ROOT/vendor"
DIST="$ROOT/dist"

NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
PREFIX="$NVIM_DATA/site"
PACK_NAME="offline"
LAZY_ROOT="$NVIM_DATA/offline-plugins"
WITH_SNACKS=0
USE_BUNDLE=0
DRY_RUN=0
DEST_OVERRIDE=""
INSTALL_KEYMAPS=0
FOR_LAZY=0
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Install opencode.nvim from this offline package.

Default: Neovim packpath (pack/*/start) — auto-loads, no plugin manager.

If you already use lazy.nvim, prefer --for-lazy so this plugin is NOT
also auto-loaded from packpath. Mixing packpath + lazy is fine for
*different* plugins; loading the *same* plugin twice is not.

Options:
  --prefix DIR       Neovim site prefix
                     (default: $XDG_DATA_HOME/nvim/site or ~/.local/share/nvim/site)
  --pack-name NAME   pack/<NAME>/start pack name (default: offline)
  --dest DIR         Install the plugin into DIR instead of packpath
  --for-lazy         Install outside packpath for lazy.nvim `dir =`
                     (default: ~/.local/share/nvim/offline-plugins/)
  --lazy-root DIR    Directory used by --for-lazy (contains opencode.nvim/)
  --with-snacks      Also install snacks.nvim (skip if lazy already has it)
  --with-keymaps     Copy example keymaps into ~/.config/nvim/plugin/
  --bundle           Clone from dist/*.gitbundle (keeps git metadata)
  --dry-run          Print actions without writing files
  -h, --help         Show this help

Examples:
  ./install.sh
  ./install.sh --for-lazy
  ./install.sh --for-lazy --with-snacks
  ./install.sh --with-snacks --with-keymaps
EOF
}

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
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
    --for-lazy) FOR_LAZY=1; shift ;;
    --lazy-root) LAZY_ROOT="$2"; shift 2 ;;
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

if [[ "$FOR_LAZY" -eq 1 && -n "$DEST_OVERRIDE" ]]; then
  printf 'error: use either --for-lazy or --dest, not both\n' >&2
  exit 2
fi

pack_start() {
  printf '%s/pack/%s/start' "$PREFIX" "$PACK_NAME"
}

plugin_dest() {
  if [[ -n "$DEST_OVERRIDE" ]]; then
    printf '%s' "$DEST_OVERRIDE"
  elif [[ "$FOR_LAZY" -eq 1 ]]; then
    printf '%s/opencode.nvim' "$LAZY_ROOT"
  else
    printf '%s/opencode.nvim' "$(pack_start)"
  fi
}

snacks_dest() {
  if [[ "$FOR_LAZY" -eq 1 ]]; then
    printf '%s/snacks.nvim' "$LAZY_ROOT"
  else
    printf '%s/snacks.nvim' "$(pack_start)"
  fi
}

packpath_plugin() {
  printf '%s/opencode.nvim' "$(pack_start)"
}

lazy_nvim_present() {
  [[ -d "$NVIM_DATA/lazy/lazy.nvim" ]]
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

warn_about_double_load() {
  local pack_copy
  pack_copy="$(packpath_plugin)"

  if [[ "$FOR_LAZY" -eq 1 && -d "$pack_copy" ]]; then
    warn "packpath copy also exists: $pack_copy"
    warn "Neovim will auto-load that copy AND lazy.nvim will load this one."
    warn "Run: ./uninstall.sh   then keep only the --for-lazy install."
  fi

  if [[ "$FOR_LAZY" -eq 0 && -z "$DEST_OVERRIDE" ]] && lazy_nvim_present; then
    warn "lazy.nvim detected at $NVIM_DATA/lazy/lazy.nvim"
    warn "Other plugins can stay on lazy; this packpath install is OK *if you do not"
    warn "also add opencode.nvim to lazy.setup()."
    warn "To let lazy manage this plugin instead, run: ./uninstall.sh && ./install.sh --for-lazy"
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
EOF

  if [[ "$FOR_LAZY" -eq 1 ]]; then
    cat <<EOF

Add this spec to lazy.nvim (do NOT also keep a pack/*/start copy):

  {
    "nickjvandyke/opencode.nvim",
    dir = "$dest",
    version = false,
    config = function()
      vim.g.opencode_opts = {}
      vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ") end)
      vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end)
    end,
  },
EOF
    if [[ "$WITH_SNACKS" -eq 1 ]]; then
      cat <<EOF

  {
    "folke/snacks.nvim",
    dir = "$(snacks_dest)",
    version = false,
    opts = { input = { enabled = true }, picker = { enabled = true } },
  },
EOF
    else
      cat <<'EOF'

If snacks.nvim is already in lazy.setup(), keep that spec and do not pass --with-snacks.
EOF
    fi
    cat <<'EOF'

See examples/lazy.lua for a full snippet.
EOF
  else
    cat <<'EOF'

Add this to your Neovim config (or use --with-keymaps):

  vim.g.opencode_opts = {}
  vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ") end)
  vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end)

If you also installed snacks.nvim, enable its input/picker:

  require("snacks").setup({
    input = { enabled = true },
    picker = { enabled = true },
  })

If you use lazy.nvim: do not add this plugin to lazy.setup() unless you
reinstall with ./install.sh --for-lazy (otherwise it loads twice).
EOF
  fi

  cat <<'EOF'

Verify after launching Neovim:
  :checkhealth opencode
EOF
}

log "opencode.nvim offline installer"
if [[ "$FOR_LAZY" -eq 1 ]]; then
  log "Mode: lazy.nvim (dir=), not packpath auto-load"
fi
warn_about_double_load
install_plugin
if [[ "$WITH_SNACKS" -eq 1 ]]; then
  if [[ -n "$DEST_OVERRIDE" ]]; then
    printf 'error: --with-snacks cannot be combined with --dest\n' >&2
    printf 'Install snacks with --for-lazy --with-snacks, or omit --dest.\n' >&2
    exit 2
  fi
  install_snacks
fi
if [[ "$INSTALL_KEYMAPS" -eq 1 ]]; then
  if [[ "$FOR_LAZY" -eq 1 ]]; then
    warn "--with-keymaps plus lazy config can bind the same keys twice; prefer examples/lazy.lua"
  fi
  install_keymaps
fi
verify_layout
print_next_steps
