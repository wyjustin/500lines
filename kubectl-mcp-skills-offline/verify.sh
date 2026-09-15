#!/usr/bin/env bash
# Verify the kubectl-mcp-skills-offline package (no cluster, no network).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'OK   %s\n' "$*"; }

[[ -f catalog.txt ]] || fail "catalog.txt missing"
[[ -f catalog.json ]] || fail "catalog.json missing"
[[ -d vendor/kubernetes-skills/claude ]] || fail "vendor skills missing"
[[ -f overlay/k8s-safety/SKILL.md ]] || fail "k8s-safety overlay missing"
[[ -f overlay/k8s-safety/scripts/classify-op.py ]] || fail "classify-op.py missing"

python3 - <<'PY' || fail "catalog.json is not valid JSON"
import json
json.load(open("catalog.json", encoding="utf-8"))
print("json-ok")
PY
pass "catalog.json parses"

# Exactly 25 default skills.
default_count="$(awk -F '\t' '$3=="1" {c++} END {print c+0}' catalog.txt)"
[[ "$default_count" -eq 25 ]] || fail "expected 25 default skills, got $default_count"
pass "catalog.txt has 25 default skills"

# 9 categories in json
python3 - <<'PY' || fail "catalog.json category count"
import json
data = json.load(open("catalog.json", encoding="utf-8"))
cats = data["categories"]
assert len(cats) == 9, len(cats)
names = []
for c in cats:
    names.extend(c["skills"])
assert len(names) == 25, len(names)
assert len(set(names)) == 25
print("categories=9 skills=25")
PY
pass "9 categories, 25 unique skills"

missing=0
while IFS=$'\t' read -r name category flag || [[ -n "${name:-}" ]]; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  if [[ "$flag" == "overlay" ]]; then
    f="overlay/$name/SKILL.md"
  else
    f="vendor/kubernetes-skills/claude/$name/SKILL.md"
  fi
  if [[ ! -f "$f" ]]; then
    printf 'missing %s\n' "$f" >&2
    missing=$((missing + 1))
    continue
  fi
  grep -q '^name:' "$f" || fail "$f missing name frontmatter"
  grep -q '^description:' "$f" || fail "$f missing description frontmatter"
done < catalog.txt
[[ "$missing" -eq 0 ]] || fail "$missing SKILL.md files missing"
pass "every catalog entry has SKILL.md with name+description"

# Overlay references
for f in overlay/k8s-safety/references/SAFETY-MODES.md \
         overlay/k8s-safety/references/SRE-PLAYBOOK.md \
         overlay/k8s-safety/references/DANGEROUS-OPS.md; do
  [[ -f "$f" ]] || fail "missing $f"
done
grep -q 'OOMKilled' overlay/k8s-safety/references/SRE-PLAYBOOK.md \
  || fail "playbook missing OOMKilled"
grep -q 'CrashLoopBackOff' overlay/k8s-safety/references/SRE-PLAYBOOK.md \
  || fail "playbook missing CrashLoopBackOff"
grep -q 'ReplicaSet' overlay/k8s-safety/references/SRE-PLAYBOOK.md \
  || fail "playbook missing ReplicaSet diff"
pass "SRE playbook covers OOM / CrashLoop / rollout"

chmod +x overlay/k8s-safety/scripts/classify-op.py install.sh uninstall.sh pack-dist.sh

python3 overlay/k8s-safety/scripts/classify-op.py get_pods --mode read_only >/dev/null \
  || fail "get_pods should be allowed in read_only"

expect_block() {
  local rc=0
  set +e
  python3 overlay/k8s-safety/scripts/classify-op.py "$@" >/dev/null
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || fail "expected BLOCK (exit 2) for: $*"
}

expect_block delete_namespace --mode read_only
python3 overlay/k8s-safety/scripts/classify-op.py scale_deployment --mode disable_destructive >/dev/null \
  || fail "scale_deployment should be allowed in disable_destructive"
expect_block uninstall_helm_chart --mode disable_destructive
pass "classify-op.py safety modes"

if [[ -f dist/checksums.sha256 ]]; then
  (cd dist && sha256sum -c checksums.sha256)
  pass "dist/checksums.sha256"
else
  warn_missing=1
  printf 'WARN dist/checksums.sha256 not built yet (run pack-dist.sh)\n'
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

chmod +x install.sh uninstall.sh
./install.sh --dry-run --prefix "$tmp/canon" >/dev/null
pass "install.sh --dry-run"

./install.sh --prefix "$tmp/canon" --project "$tmp/repo" --mode link --force >/dev/null
[[ -f "$tmp/canon/skills/k8s-core/SKILL.md" ]] || fail "canonical k8s-core missing"
[[ -f "$tmp/canon/skills/k8s-safety/SKILL.md" ]] || fail "canonical k8s-safety missing"
[[ ! -e "$tmp/canon/skills/k8s-kind" ]] || fail "k8s-kind should not install by default"
[[ -L "$tmp/repo/.claude/skills/k8s-core" ]] || fail "claude project link missing"
[[ -L "$tmp/repo/.cursor/skills/k8s-safety" ]] || fail "cursor project link missing"
[[ -L "$tmp/repo/.opencode/skills/k8s-troubleshoot" ]] || fail "opencode project link missing"
count="$(ls -1 "$tmp/canon/skills" | wc -l)"
[[ "$count" -eq 26 ]] || fail "expected 25+safety=26 staged, got $count"
pass "install.sh project link (26 = 25 + k8s-safety)"

./install.sh --prefix "$tmp/canon-all" --project "$tmp/repo-all" --mode copy --skills all --force >/dev/null
[[ -d "$tmp/canon-all/skills/k8s-kind" ]] || fail "--skills all did not install k8s-kind"
pass "install.sh --skills all includes k8s-kind"

./uninstall.sh --prefix "$tmp/canon" --project "$tmp/repo" >/dev/null
[[ ! -e "$tmp/repo/.claude/skills/k8s-core" ]] || fail "uninstall left claude skill"
[[ ! -e "$tmp/canon/.kubectl-mcp-skills-offline-stamp" ]] || fail "uninstall left prefix stamp"
pass "uninstall.sh"

./install.sh --prefix "$tmp/nosafety" --project "$tmp/repo-ns" --mode copy --no-safety --force >/dev/null
[[ ! -e "$tmp/nosafety/skills/k8s-safety" ]] || fail "--no-safety still staged overlay"
[[ -f "$tmp/nosafety/skills/k8s-core/SKILL.md" ]] || fail "--no-safety dropped core skills"
pass "install.sh --no-safety"

# Overlay must stay a skill wrapper: no MCP server implementation.
if grep -RIn --include='*.py' -E '^(from|import) mcp|FastMCP|def serve_stdio' overlay >/dev/null 2>&1; then
  fail "overlay looks like a new MCP server"
fi
pass "overlay is skills-only (not a new MCP server)"

printf '\nAll package checks passed.\n'
