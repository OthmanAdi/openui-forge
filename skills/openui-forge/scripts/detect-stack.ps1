# OpenUI Forge — Stack Detection Script (PowerShell)
# Outputs JSON with project state for the agent to consume
# Always exits 0; the JSON payload conveys the actual state.

$ErrorActionPreference = "SilentlyContinue"

# ── helpers ──────────────────────────────────────────────────────────────────

function Safe-SelectString {
    param(
        [string]$Pattern,
        [string]$Path,
        [string[]]$Include = @("*.ts","*.tsx","*.js","*.jsx")
    )
    try {
        Get-ChildItem -Path $Path -Recurse -Include $Include -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' -and $_.FullName -notmatch '[\\\/]\.git[\\\/]' } |
            Select-String -Pattern $Pattern -ErrorAction SilentlyContinue
    } catch {
        $null
    }
}

# ── 1. package.json ─────────────────────────────────────────────────────────

$hasPackageJson = Test-Path "package.json"

# ── 2. OpenUI dependencies ──────────────────────────────────────────────────

$hasOpenUiDeps = $false
if ($hasPackageJson) {
    $pkgContent = Get-Content "package.json" -Raw -ErrorAction SilentlyContinue
    if ($pkgContent -match '"@openuidev/') {
        $hasOpenUiDeps = $true
    }
}

# ── 3. React version ────────────────────────────────────────────────────────

$reactVersion = $null
if ($hasPackageJson) {
    # Try node_modules first (actual installed version)
    $reactPkg = "node_modules/react/package.json"
    if (Test-Path $reactPkg) {
        $reactContent = Get-Content $reactPkg -Raw -ErrorAction SilentlyContinue
        if ($reactContent -match '"version"\s*:\s*"([^"]+)"') {
            $reactVersion = $Matches[1]
        }
    }
    # Fall back to declared dependency
    if (-not $reactVersion -and $pkgContent) {
        if ($pkgContent -match '"react"\s*:\s*"[\^~]?([0-9][^"]*)"') {
            $reactVersion = $Matches[1]
        }
    }
}

# ── 4. Framework detection ──────────────────────────────────────────────────

$framework = "unknown"
$nextConfigs = Get-ChildItem -Filter "next.config.*" -ErrorAction SilentlyContinue
$viteConfigs = Get-ChildItem -Filter "vite.config.*" -ErrorAction SilentlyContinue

if ($nextConfigs) {
    $framework = "nextjs"
} elseif ($viteConfigs) {
    $framework = "vite"
} elseif ($hasPackageJson -and $pkgContent -match '"react-scripts"') {
    $framework = "cra"
}

# ── 5 & 6. Component library (createLibrary) ────────────────────────────────

$hasComponentLibrary = $false
$libraryPath = $null
$libHits = Safe-SelectString -Pattern "createLibrary" -Path "."
if ($libHits) {
    $hasComponentLibrary = $true
    $libraryPath = ($libHits | Select-Object -First 1).Path
    # Normalize to relative path
    $libraryPath = $libraryPath -replace [regex]::Escape((Get-Location).Path + [IO.Path]::DirectorySeparatorChar), "./"
    $libraryPath = $libraryPath -replace '\\', '/'
}

# ── 7 & 8. System prompt ────────────────────────────────────────────────────

$hasSystemPrompt = $false
$promptPath = $null
$promptHits = Get-ChildItem -Path "." -Recurse -Filter "system-prompt.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' -and $_.FullName -notmatch '[\\\/]\.git[\\\/]' }

if ($promptHits) {
    $firstPrompt = $promptHits | Select-Object -First 1
    if ($firstPrompt.Length -gt 0) {
        $hasSystemPrompt = $true
        $promptPath = $firstPrompt.FullName -replace [regex]::Escape((Get-Location).Path + [IO.Path]::DirectorySeparatorChar), "./"
        $promptPath = $promptPath -replace '\\', '/'
    }
}

# ── 9 & 10. Backend route ───────────────────────────────────────────────────

$hasBackendRoute = $false
$backendPath = $null
$routeHits = Get-ChildItem -Path "." -Recurse -Include "route.ts","route.js" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '[\\\/]api[\\\/]chat[\\\/]' -and $_.FullName -notmatch '[\\\/]node_modules[\\\/]' }

if ($routeHits) {
    $hasBackendRoute = $true
    $backendPath = ($routeHits | Select-Object -First 1).FullName -replace [regex]::Escape((Get-Location).Path + [IO.Path]::DirectorySeparatorChar), "./"
    $backendPath = $backendPath -replace '\\', '/'
}

# ── 11. Frontend page with FullScreen / Copilot / ChatProvider ──────────────

$hasFrontendPage = $false
$pageHits = Safe-SelectString -Pattern "(FullScreen|Copilot|ChatProvider)" -Path "."
if ($pageHits) {
    $hasFrontendPage = $true
}

# ── 12. CSS imports ─────────────────────────────────────────────────────────

$hasCssImports = $false
$cssHits = Safe-SelectString -Pattern "@openuidev/react-ui" -Path "." -Include @("*.ts","*.tsx","*.js","*.jsx","*.css")
if ($cssHits) {
    $hasCssImports = $true
}

# ── 13. Backend language ────────────────────────────────────────────────────

$backendLanguage = "typescript"

$pyFiles = Get-ChildItem -Path "." -Recurse -Include "*.py" -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' }
if ($pyFiles) {
    $pyHits = $pyFiles | Select-String -Pattern "(fastapi|flask|openai|anthropic|langchain)" -ErrorAction SilentlyContinue
    if ($pyHits) { $backendLanguage = "python" }
}

$goFiles = Get-ChildItem -Path "." -Recurse -Include "*.go" -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' }
if ($goFiles) {
    $goHits = $goFiles | Select-String -Pattern "(net/http|gin|echo|fiber)" -ErrorAction SilentlyContinue
    if ($goHits) { $backendLanguage = "go" }
}

$rsFiles = Get-ChildItem -Path "." -Recurse -Include "*.rs" -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' }
if ($rsFiles) {
    $rsHits = $rsFiles | Select-String -Pattern "(actix|axum|rocket|hyper)" -ErrorAction SilentlyContinue
    if ($rsHits) { $backendLanguage = "rust" }
}

# ── 14. LLM provider ────────────────────────────────────────────────────────

$llmProvider = "unknown"

$openaiHits = Safe-SelectString -Pattern "from ['\x22]openai['\x22]|require\(['\x22]openai['\x22]\)" -Path "."
if ($openaiHits) {
    $llmProvider = "openai"
} else {
    $anthropicHits = Safe-SelectString -Pattern "@anthropic-ai/sdk" -Path "."
    if ($anthropicHits) {
        $llmProvider = "anthropic"
    } else {
        $langchainHits = Safe-SelectString -Pattern "@langchain/" -Path "."
        if ($langchainHits) {
            $llmProvider = "langchain"
        } else {
            $vercelHits = Safe-SelectString -Pattern "from ['\x22]ai['\x22]|require\(['\x22]ai['\x22]\)" -Path "."
            if ($vercelHits) {
                $llmProvider = "vercel-ai"
            }
        }
    }
}

# ── Emit JSON ────────────────────────────────────────────────────────────────

function To-JsonValue($val) {
    if ($null -eq $val) { return "null" }
    if ($val -is [bool]) { return if ($val) { "true" } else { "false" } }
    return "`"$($val -replace '\\', '\\\\' -replace '"', '\"')`""
}

$json = @"
{
  "has_package_json": $(To-JsonValue $hasPackageJson),
  "has_openui_deps": $(To-JsonValue $hasOpenUiDeps),
  "react_version": $(To-JsonValue $reactVersion),
  "framework": $(To-JsonValue $framework),
  "has_component_library": $(To-JsonValue $hasComponentLibrary),
  "library_path": $(To-JsonValue $libraryPath),
  "has_system_prompt": $(To-JsonValue $hasSystemPrompt),
  "prompt_path": $(To-JsonValue $promptPath),
  "has_backend_route": $(To-JsonValue $hasBackendRoute),
  "backend_path": $(To-JsonValue $backendPath),
  "has_frontend_page": $(To-JsonValue $hasFrontendPage),
  "has_css_imports": $(To-JsonValue $hasCssImports),
  "backend_language": $(To-JsonValue $backendLanguage),
  "llm_provider": $(To-JsonValue $llmProvider)
}
"@

Write-Output $json
exit 0
