# OpenUI Forge — Validation Pipeline (PowerShell)
# Runs 10 checks and outputs a human-readable pass/fail report.
# Exit 0 if all pass, exit 1 if any fail.

$ErrorActionPreference = "SilentlyContinue"

# ── state ────────────────────────────────────────────────────────────────────

$script:passed = 0
$script:failed = 0
$script:total  = 10
$script:results = @()

function Pass($msg) {
    $script:results += "[PASS] $msg"
    $script:passed++
}

function Fail($msg) {
    $script:results += "[FAIL] $msg"
    $script:failed++
}

function Warn($msg) {
    $script:results += "[WARN] $msg"
    # warnings count as pass — they don't block
    $script:passed++
}

function Safe-SelectString {
    param(
        [string]$Pattern,
        [string]$Path = ".",
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

function Relative-Path($fullPath) {
    $base = (Get-Location).Path + [IO.Path]::DirectorySeparatorChar
    $rel = $fullPath -replace [regex]::Escape($base), "./"
    return ($rel -replace '\\', '/')
}

# ── Check 1: @openuidev packages installed ──────────────────────────────────

if (Test-Path "node_modules/@openuidev") {
    $pkgDirs = Get-ChildItem "node_modules/@openuidev" -Directory -ErrorAction SilentlyContinue
    $pkgCount = if ($pkgDirs) { $pkgDirs.Count } else { 0 }
    Pass "Dependencies installed ($pkgCount @openuidev packages in node_modules)"
} else {
    if ((Test-Path "package.json") -and ((Get-Content "package.json" -Raw) -match '"@openuidev/')) {
        Fail "Dependencies declared in package.json but not installed (run npm install)"
    } else {
        Fail "No @openuidev packages found (not in package.json or node_modules)"
    }
}

# ── Check 2: React version >= 19 ────────────────────────────────────────────

$reactVer = $null

if (Test-Path "node_modules/react/package.json") {
    $reactPkgContent = Get-Content "node_modules/react/package.json" -Raw -ErrorAction SilentlyContinue
    if ($reactPkgContent -match '"version"\s*:\s*"([^"]+)"') {
        $reactVer = $Matches[1]
    }
}

if (-not $reactVer -and (Test-Path "package.json")) {
    $pkgContent = Get-Content "package.json" -Raw -ErrorAction SilentlyContinue
    if ($pkgContent -match '"react"\s*:\s*"[\^~]?([0-9][^"]*)"') {
        $reactVer = $Matches[1]
    }
}

if (-not $reactVer) {
    Fail "React version: not found"
} else {
    $major = ($reactVer -split '\.')[0] -as [int]
    if ($major -ge 19) {
        Pass "React version: $reactVer (>= 19)"
    } else {
        Fail "React version: found $reactVer, need >= 19.0.0"
    }
}

# ── Check 3: createLibrary call ─────────────────────────────────────────────

$libHits = Safe-SelectString -Pattern "createLibrary" -Path "."
$libFile = $null

if ($libHits) {
    $libFile = ($libHits | Select-Object -First 1).Path
    $libFileRel = Relative-Path $libFile
    Pass "Component library found at $libFileRel"
} else {
    Fail "No createLibrary call found in source files"
}

# ── Check 4: Zod .describe() usage ──────────────────────────────────────────

if ($libFile) {
    $zodHits = Safe-SelectString -Pattern "z\.(object|string|number|boolean|array|enum)" -Path "." -Include @("*.ts","*.tsx")
    if ($zodHits) {
        $zodFiles = $zodHits | ForEach-Object { $_.Path } | Sort-Object -Unique
        $hasDescribe = $false
        foreach ($f in $zodFiles) {
            $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
            if ($content -match '\.describe\(') {
                $hasDescribe = $true
                break
            }
        }
        if ($hasDescribe) {
            Pass "Zod .describe() usage found (component props have descriptions)"
        } else {
            Warn "Zod schemas found but no .describe() calls -- add descriptions to improve AI generation"
        }
    } else {
        Warn "No Zod schemas detected -- cannot verify .describe() usage"
    }
} else {
    Warn "No library file found -- skipping Zod .describe() check"
}

# ── Check 5: system-prompt.txt ──────────────────────────────────────────────

$promptFiles = Get-ChildItem -Path "." -Recurse -Filter "system-prompt.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' -and $_.FullName -notmatch '[\\\/]\.git[\\\/]' }

if ($promptFiles) {
    $promptFile = $promptFiles | Select-Object -First 1
    if ($promptFile.Length -gt 0) {
        $lineCount = (Get-Content $promptFile.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        $promptRel = Relative-Path $promptFile.FullName
        Pass "System prompt found at $promptRel ($lineCount lines)"
    } else {
        $promptRel = Relative-Path $promptFile.FullName
        Fail "System prompt exists at $promptRel but is empty"
    }
} else {
    Fail "No system-prompt.txt found"
}

# ── Check 6: Backend route ──────────────────────────────────────────────────

$routeFiles = Get-ChildItem -Path "." -Recurse -Include "route.ts","route.js" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '[\\\/]api[\\\/]chat[\\\/]' -and $_.FullName -notmatch '[\\\/]node_modules[\\\/]' }

if ($routeFiles) {
    $routeRel = Relative-Path ($routeFiles | Select-Object -First 1).FullName
    Pass "Backend route found at $routeRel"
} else {
    # Check for non-Next.js backends
    $altBackend = Safe-SelectString -Pattern "POST.*chat|/api/chat|chat.*endpoint" -Path "." -Include @("*.ts","*.js","*.py","*.go")
    if ($altBackend) {
        $altRel = Relative-Path ($altBackend | Select-Object -First 1).Path
        Pass "Backend endpoint found at $altRel (non-standard location)"
    } else {
        Fail "No backend chat route found (expected api/chat/route.ts or similar)"
    }
}

# ── Check 7: Frontend page ──────────────────────────────────────────────────

$pageHits = Safe-SelectString -Pattern "(FullScreen|Copilot|ChatProvider)" -Path "."

if ($pageHits) {
    $pageFile = ($pageHits | Select-Object -First 1).Path
    $pageRel = Relative-Path $pageFile
    $pageContent = Get-Content $pageFile -Raw -ErrorAction SilentlyContinue
    $comps = @()
    foreach ($comp in @("FullScreen","Copilot","ChatProvider")) {
        if ($pageContent -match $comp) { $comps += $comp }
    }
    $compStr = $comps -join ", "
    Pass "Frontend page found at $pageRel (uses: $compStr)"
} else {
    Fail "No frontend page with FullScreen, Copilot, or ChatProvider found"
}

# ── Check 8: CSS imports ────────────────────────────────────────────────────

$cssHits = Safe-SelectString -Pattern "@openuidev/react-ui" -Path "." -Include @("*.ts","*.tsx","*.js","*.jsx","*.css")

if ($cssHits) {
    $cssRel = Relative-Path ($cssHits | Select-Object -First 1).Path
    Pass "OpenUI CSS imports found in $cssRel"
} else {
    Fail "No @openuidev/react-ui CSS imports found in layout or root files"
}

# ── Check 9: Adapter consistency ────────────────────────────────────────────

$adapterCount = 0
$adapterNames = ""

$openaiRefs = Safe-SelectString -Pattern "from ['\x22]openai['\x22]" -Path "." -Include @("*.ts","*.js")
if ($openaiRefs) { $adapterCount++; $adapterNames += "openai " }

$anthropicRefs = Safe-SelectString -Pattern "@anthropic-ai/sdk" -Path "." -Include @("*.ts","*.js")
if ($anthropicRefs) { $adapterCount++; $adapterNames += "anthropic " }

$langchainRefs = Safe-SelectString -Pattern "@langchain/" -Path "." -Include @("*.ts","*.js")
if ($langchainRefs) { $adapterCount++; $adapterNames += "langchain " }

$vercelRefs = Safe-SelectString -Pattern "from ['\x22]ai['\x22]" -Path "." -Include @("*.ts","*.js")
if ($vercelRefs) { $adapterCount++; $adapterNames += "vercel-ai " }

if ($adapterCount -eq 0) {
    Warn "No LLM adapter detected -- cannot verify consistency"
} elseif ($adapterCount -eq 1) {
    Pass "Adapter consistency: using ${adapterNames}only"
} else {
    Warn "Multiple LLM adapters detected (${adapterNames}) -- verify this is intentional"
}

# ── Check 10: CORS headers ──────────────────────────────────────────────────

$corsHits = Safe-SelectString -Pattern "(Access-Control-Allow-Origin|cors|CORS)" -Path "." -Include @("*.ts","*.js","*.py","*.go")

$separateBackend = Get-ChildItem -Path "." -Recurse -Include "server.ts","server.js","main.py","main.go" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\\/]node_modules[\\\/]' } |
    Select-Object -First 1

if ($separateBackend) {
    $backendRel = Relative-Path $separateBackend.FullName
    if ($corsHits) {
        Pass "CORS headers configured (separate backend detected at $backendRel)"
    } else {
        Fail "Separate backend detected at $backendRel but no CORS configuration found"
    }
} else {
    Pass "CORS check: not needed (no separate backend detected)"
}

# ── Report ───────────────────────────────────────────────────────────────────

Write-Output ""
Write-Output "OpenUI Forge Validation"
Write-Output "========================"
foreach ($r in $script:results) {
    Write-Output $r
}
Write-Output "========================"
Write-Output "$($script:passed)/$($script:total) checks passed"

if ($script:failed -gt 0) {
    Write-Output ""
    Write-Output "Fix the failing checks above to complete your OpenUI setup."
    exit 1
} else {
    Write-Output ""
    Write-Output "All checks passed. Your OpenUI integration looks good!"
    exit 0
}
