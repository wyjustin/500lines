#!/usr/bin/env bash
# Build dist tarballs and checksums (run on the packaging host).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
mkdir -p "$DIST"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Vendor skills only (upstream snapshot).
tar -C "$ROOT/vendor" -czf "$DIST/kubernetes-skills.tar.gz" kubernetes-skills

# Safety overlay.
tar -C "$ROOT/overlay" -czf "$DIST/k8s-safety-overlay.tar.gz" k8s-safety

# Full package tree without nested dist archives (avoid recursion).
mkdir -p "$tmp/kubectl-mcp-skills-offline"
cp "$ROOT/catalog.json" "$DIST/catalog.json"

# Checksums of the pieces that go inside the USB tarball.
(
  cd "$DIST"
  sha256sum kubernetes-skills.tar.gz k8s-safety-overlay.tar.gz catalog.json \
    > checksums.components.sha256
)

tar -C "$ROOT" --exclude='dist/*.tar.gz' --exclude='dist/checksums.sha256' \
  -cf - . | tar -C "$tmp/kubectl-mcp-skills-offline" -xf -
rm -rf "$tmp/kubectl-mcp-skills-offline/dist"
mkdir -p "$tmp/kubectl-mcp-skills-offline/dist"
cp "$DIST/kubernetes-skills.tar.gz" "$tmp/kubectl-mcp-skills-offline/dist/"
cp "$DIST/k8s-safety-overlay.tar.gz" "$tmp/kubectl-mcp-skills-offline/dist/"
cp "$DIST/catalog.json" "$tmp/kubectl-mcp-skills-offline/dist/"
cp "$DIST/checksums.components.sha256" "$tmp/kubectl-mcp-skills-offline/dist/"

tar -C "$tmp" -czf "$DIST/kubectl-mcp-skills-offline-kylin-v10-sp3-x64.tar.gz" \
  kubectl-mcp-skills-offline

(
  cd "$DIST"
  {
    cat checksums.components.sha256
    sha256sum kubectl-mcp-skills-offline-kylin-v10-sp3-x64.tar.gz
  } > checksums.sha256
)

printf 'Wrote:\n'
ls -lh "$DIST"
cat "$DIST/checksums.sha256"
