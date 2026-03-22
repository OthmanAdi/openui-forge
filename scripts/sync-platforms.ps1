# sync-platforms.ps1 — Copy openui-forge skill files to all supported agent platform directories
# Usage: pwsh scripts/sync-platforms.ps1  (run from repo root)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$MainSkill = Join-Path $RepoRoot "skills\openui-forge"

# All target platform directories (relative to repo root)
$Platforms = @(
    ".claude"
    ".cursor"
    ".agents"
    ".gemini"
    ".kiro"
    ".codex"
    ".codebuddy"
    ".continue"
    ".factory"
    ".opencode"
    ".pi"
    ".mastracode"
)

# Variant skill suffixes (each has only a SKILL.md)
$Variants = @(
    "openui-forge-openai"
    "openui-forge-anthropic"
    "openui-forge-langchain"
    "openui-forge-python"
    "openui-forge-go"
    "openui-forge-rust"
    "openui-forge-vercel"
    "openui-forge-zh"
)

Write-Host "=== OpenUI Forge: Syncing skills to all agent platforms ==="
Write-Host ""

# -- 1. Sync the main skill (full directory with refs, templates, scripts) --
Write-Host "--- Main skill: openui-forge ---"
foreach ($platform in $Platforms) {
    $dest = Join-Path $RepoRoot "$platform\skills\openui-forge"
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $MainSkill "*") -Destination $dest -Recurse -Force
    Write-Host "  [OK] $platform\skills\openui-forge\"
}
Write-Host ""

# -- 2. Sync each variant skill (SKILL.md only) --
foreach ($variant in $Variants) {
    $src = Join-Path $RepoRoot "skills\$variant\SKILL.md"
    if (-not (Test-Path $src)) {
        Write-Host "--- Variant skill: $variant  [SKIPPED - no SKILL.md found] ---"
        continue
    }
    Write-Host "--- Variant skill: $variant ---"
    foreach ($platform in $Platforms) {
        $dest = Join-Path $RepoRoot "$platform\skills\$variant"
        if (-not (Test-Path $dest)) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        }
        Copy-Item -Path $src -Destination (Join-Path $dest "SKILL.md") -Force
        Write-Host "  [OK] $platform\skills\$variant\SKILL.md"
    }
    Write-Host ""
}

Write-Host "=== Sync complete. ==="
