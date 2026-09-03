#!/usr/bin/env bash
# Verify this offline package: checksums, layout, installer, git bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'OK   %s\n' "$*"; }

command -v tar >/dev/null || fail "tar is required"
command -v sha256sum >/dev/null || fail "sha256sum is required"

[[ -f vendor/opencode.nvim/lua/opencode.lua ]] || fail "vendor plugin lua missing"
[[ -d vendor/opencode.nvim/plugin ]] || fail "vendor plugin/ missing"
[[ -f vendor/opencode.nvim/VERSION ]] || fail "VERSION missing"
grep -q 'v1.0.0' vendor/opencode.nvim/VERSION || fail "VERSION is not v1.0.0"
pass "vendor/opencode.nvim layout"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

archive_has() {
  local archive="$1"
  local member="$2"
  local list="$tmp/$(basename "$archive").list"
  if [[ ! -f "$list" ]]; then
    tar -tzf "$archive" > "$list"
  fi
  grep -Fxq "$member" "$list" || grep -q "$member" "$list" || fail "$archive missing $member"
}

archive_has dist/snacks.nvim-optional.tar.gz "snacks.nvim/lua/snacks/init.lua"
archive_has dist/snacks.nvim-optional.tar.gz "snacks.nvim/plugin/snacks.lua"
pass "dist/snacks.nvim-optional.tar.gz layout"

(cd dist && sha256sum -c checksums.sha256)
pass "dist/checksums.sha256"

archive_has dist/opencode.nvim-v1.0.0.tar.gz "opencode.nvim/lua/opencode.lua"
pass "plugin tarball listing"

tar -xzf dist/opencode.nvim-v1.0.0.tar.gz -C "$tmp"
[[ -f "$tmp/opencode.nvim/lua/opencode.lua" ]] || fail "extract failed"
pass "plugin tarball extract"

if command -v git >/dev/null 2>&1; then
  git bundle verify dist/opencode.nvim-v1.0.0.gitbundle >/dev/null
  git -c advice.detachedHead=false clone --quiet --branch v1.0.0 \
    dist/opencode.nvim-v1.0.0.gitbundle "$tmp/from-bundle"
  hash="$(git -C "$tmp/from-bundle" rev-parse HEAD)"
  [[ "$hash" == "4576b372034495b8868e6cbe878e85c717998867" ]] \
    || fail "bundle HEAD is $hash, expected 4576b37..."
  pass "git bundle clone v1.0.0 ($hash)"
else
  printf 'WARN git not found; skipped bundle clone\n'
fi

chmod +x install.sh uninstall.sh
./install.sh --dry-run >/dev/null
pass "install.sh --dry-run"

prefix="$tmp/nvim-site"
./install.sh --prefix "$prefix" >/dev/null
[[ -f "$prefix/pack/offline/start/opencode.nvim/lua/opencode.lua" ]] \
  || fail "install.sh did not write plugin"
pass "install.sh --prefix"

./install.sh --prefix "$prefix" --with-snacks >/dev/null
[[ -f "$prefix/pack/offline/start/snacks.nvim/plugin/snacks.lua" ]] \
  || fail "install.sh --with-snacks did not write snacks"
pass "install.sh --with-snacks"

xdg="$tmp/xdg-lazy"
mkdir -p "$xdg"
XDG_DATA_HOME="$xdg" ./install.sh --for-lazy >/dev/null
[[ -f "$xdg/nvim/offline-plugins/opencode.nvim/lua/opencode.lua" ]] \
  || fail "--for-lazy did not write plugin"
[[ ! -e "$xdg/nvim/site/pack/offline/start/opencode.nvim" ]] \
  || fail "--for-lazy wrote packpath start (would double-load with lazy)"
pass "install.sh --for-lazy"

XDG_DATA_HOME="$xdg" ./install.sh --for-lazy --with-snacks >/dev/null
[[ -f "$xdg/nvim/offline-plugins/snacks.nvim/plugin/snacks.lua" ]] \
  || fail "--for-lazy --with-snacks did not write snacks"
pass "install.sh --for-lazy --with-snacks"

XDG_DATA_HOME="$xdg" ./uninstall.sh >/dev/null
[[ ! -e "$xdg/nvim/offline-plugins/opencode.nvim" ]] || fail "uninstall left lazy plugin"
[[ ! -e "$xdg/nvim/offline-plugins/snacks.nvim" ]] || fail "uninstall left lazy snacks"
pass "uninstall.sh --for-lazy"

./uninstall.sh --prefix "$prefix" >/dev/null
[[ ! -e "$prefix/pack/offline/start/opencode.nvim" ]] || fail "uninstall left plugin"
[[ ! -e "$prefix/pack/offline/start/snacks.nvim" ]] || fail "uninstall left snacks"
pass "uninstall.sh"

lua_count="$(find vendor/opencode.nvim/lua -name '*.lua' | wc -l)"
plugin_count="$(find vendor/opencode.nvim/plugin -name '*.lua' | wc -l)"
[[ "$lua_count" -ge 20 ]] || fail "too few lua modules: $lua_count"
[[ "$plugin_count" -ge 4 ]] || fail "too few plugin files: $plugin_count"
pass "lua modules=$lua_count plugin files=$plugin_count"

printf '\nAll package checks passed.\n'
