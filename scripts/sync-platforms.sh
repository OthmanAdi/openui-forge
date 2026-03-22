#!/usr/bin/env bash
# sync-platforms.sh — Copy openui-forge skill files to all supported agent platform directories
# Usage: bash scripts/sync-platforms.sh  (run from repo root)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN_SKILL="$REPO_ROOT/skills/openui-forge"

# All target platform directories (relative to repo root)
PLATFORMS=(
  .claude
  .cursor
  .agents
  .gemini
  .kiro
  .codex
  .codebuddy
  .continue
  .factory
  .opencode
  .pi
  .mastracode
)

# Variant skill suffixes (each has only a SKILL.md)
VARIANTS=(
  openui-forge-openai
  openui-forge-anthropic
  openui-forge-langchain
  openui-forge-python
  openui-forge-go
  openui-forge-rust
  openui-forge-vercel
  openui-forge-zh
)

echo "=== OpenUI Forge: Syncing skills to all agent platforms ==="
echo ""

# ── 1. Sync the main skill (full directory with refs, templates, scripts) ──
echo "--- Main skill: openui-forge ---"
for platform in "${PLATFORMS[@]}"; do
  dest="$REPO_ROOT/$platform/skills/openui-forge"
  mkdir -p "$dest"
  cp -r "$MAIN_SKILL/"* "$dest/"
  echo "  [OK] $platform/skills/openui-forge/"
done
echo ""

# ── 2. Sync each variant skill (SKILL.md only) ──
for variant in "${VARIANTS[@]}"; do
  src="$REPO_ROOT/skills/$variant/SKILL.md"
  if [ ! -f "$src" ]; then
    echo "--- Variant skill: $variant  [SKIPPED — no SKILL.md found] ---"
    continue
  fi
  echo "--- Variant skill: $variant ---"
  for platform in "${PLATFORMS[@]}"; do
    dest="$REPO_ROOT/$platform/skills/$variant"
    mkdir -p "$dest"
    cp "$src" "$dest/SKILL.md"
    echo "  [OK] $platform/skills/$variant/SKILL.md"
  done
  echo ""
done

echo "=== Sync complete. ==="
