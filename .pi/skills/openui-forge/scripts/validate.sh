#!/usr/bin/env bash
# OpenUI Forge — Validation Pipeline
# Runs 10 checks and outputs a human-readable pass/fail report.
# Exit 0 if all pass, exit 1 if any fail.

set -uo pipefail

# ── state ────────────────────────────────────────────────────────────────────

passed=0
failed=0
total=10
results=()

pass() {
    results+=("[PASS] $1")
    ((passed++))
}

fail() {
    results+=("[FAIL] $1")
    ((failed++))
}

warn() {
    results+=("[WARN] $1")
    # warnings don't affect pass/fail count — counted as pass
    ((passed++))
}

# Safe grep wrapper
sgrep() { grep -r "$@" 2>/dev/null || true; }

# ── Check 1: @openuidev packages installed ──────────────────────────────────

if [[ -d "node_modules/@openuidev" ]]; then
    pkg_count=$(ls -d node_modules/@openuidev/*/ 2>/dev/null | wc -l | tr -d ' ')
    pass "Dependencies installed ($pkg_count @openuidev packages in node_modules)"
else
    if [[ -f "package.json" ]] && grep -q '"@openuidev/' package.json 2>/dev/null; then
        fail "Dependencies declared in package.json but not installed (run npm install)"
    else
        fail "No @openuidev packages found (not in package.json or node_modules)"
    fi
fi

# ── Check 2: React version >= 19 ────────────────────────────────────────────

react_ver=""
if [[ -f "node_modules/react/package.json" ]]; then
    react_ver=$(grep -oP '"version"\s*:\s*"\K[^"]+' node_modules/react/package.json 2>/dev/null || true)
elif [[ -f "package.json" ]]; then
    react_ver=$(grep -oP '"react"\s*:\s*"[\^~]?\K[0-9][^"]*' package.json 2>/dev/null || true)
fi

if [[ -z "$react_ver" ]]; then
    fail "React version: not found"
else
    major=$(echo "$react_ver" | cut -d. -f1)
    if [[ "$major" -ge 19 ]] 2>/dev/null; then
        pass "React version: $react_ver (>= 19)"
    else
        fail "React version: found $react_ver, need >= 19.0.0"
    fi
fi

# ── Check 3: createLibrary call ─────────────────────────────────────────────

lib_file=$(sgrep -rl "createLibrary" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . \
    | grep -v node_modules | head -n1)

if [[ -n "$lib_file" ]]; then
    pass "Component library found at $lib_file"
else
    fail "No createLibrary call found in source files"
fi

# ── Check 4: Zod .describe() usage ──────────────────────────────────────────

if [[ -n "$lib_file" ]]; then
    # Look in the library file and nearby files for zod schemas
    zod_files=$(sgrep -rl "z\.\(object\|string\|number\|boolean\|array\|enum\)" --include="*.ts" --include="*.tsx" . \
        | grep -v node_modules || true)
    if [[ -n "$zod_files" ]]; then
        has_describe=$(echo "$zod_files" | while read -r f; do
            grep -l '\.describe(' "$f" 2>/dev/null
        done | head -n1)
        if [[ -n "$has_describe" ]]; then
            pass "Zod .describe() usage found (component props have descriptions)"
        else
            warn "Zod schemas found but no .describe() calls — add descriptions to improve AI generation"
        fi
    else
        warn "No Zod schemas detected — cannot verify .describe() usage"
    fi
else
    warn "No library file found — skipping Zod .describe() check"
fi

# ── Check 5: system-prompt.txt ──────────────────────────────────────────────

prompt_file=$(find . -name "system-prompt.txt" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -n1)

if [[ -n "$prompt_file" && -s "$prompt_file" ]]; then
    line_count=$(wc -l < "$prompt_file" | tr -d ' ')
    pass "System prompt found at $prompt_file ($line_count lines)"
elif [[ -n "$prompt_file" ]]; then
    fail "System prompt exists at $prompt_file but is empty"
else
    fail "No system-prompt.txt found"
fi

# ── Check 6: Backend route ──────────────────────────────────────────────────

route_file=$(find . -path "*/api/chat/route.*" -not -path "*/node_modules/*" 2>/dev/null | head -n1)

if [[ -n "$route_file" ]]; then
    pass "Backend route found at $route_file"
else
    # Also check for non-Next.js backends
    alt_backend=$(sgrep -rl "POST.*chat\|/api/chat\|chat.*endpoint" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" . \
        | grep -v node_modules | head -n1)
    if [[ -n "$alt_backend" ]]; then
        pass "Backend endpoint found at $alt_backend (non-standard location)"
    else
        fail "No backend chat route found (expected api/chat/route.ts or similar)"
    fi
fi

# ── Check 7: Frontend page ──────────────────────────────────────────────────

page_file=$(sgrep -rlE "(FullScreen|Copilot|ChatProvider)" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" . \
    | grep -v node_modules | head -n1)

if [[ -n "$page_file" ]]; then
    components_found=""
    for comp in FullScreen Copilot ChatProvider; do
        if grep -q "$comp" "$page_file" 2>/dev/null; then
            [[ -n "$components_found" ]] && components_found+=", "
            components_found+="$comp"
        fi
    done
    pass "Frontend page found at $page_file (uses: $components_found)"
else
    fail "No frontend page with FullScreen, Copilot, or ChatProvider found"
fi

# ── Check 8: CSS imports ────────────────────────────────────────────────────

css_file=$(sgrep -rl "@openuidev/react-ui" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.css" . \
    | grep -v node_modules | head -n1)

if [[ -n "$css_file" ]]; then
    pass "OpenUI CSS imports found in $css_file"
else
    fail "No @openuidev/react-ui CSS imports found in layout or root files"
fi

# ── Check 9: Adapter consistency ────────────────────────────────────────────

adapters_found=()
if sgrep -q "openai" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . 2>/dev/null | grep -v node_modules; then
    true  # openai found via grep
fi

# Detect which adapters are referenced
openai_refs=$(sgrep -c "from ['\"]openai['\"]" --include="*.ts" --include="*.js" . | grep -v node_modules | grep -v ":0$" | wc -l | tr -d ' ')
anthropic_refs=$(sgrep -c "@anthropic-ai/sdk" --include="*.ts" --include="*.js" . | grep -v node_modules | grep -v ":0$" | wc -l | tr -d ' ')
langchain_refs=$(sgrep -c "@langchain/" --include="*.ts" --include="*.js" . | grep -v node_modules | grep -v ":0$" | wc -l | tr -d ' ')
vercel_refs=$(sgrep -c "from ['\"]ai['\"]" --include="*.ts" --include="*.js" . | grep -v node_modules | grep -v ":0$" | wc -l | tr -d ' ')

adapter_count=0
adapter_names=""
[[ "$openai_refs" -gt 0 ]] 2>/dev/null && { ((adapter_count++)); adapter_names+="openai "; }
[[ "$anthropic_refs" -gt 0 ]] 2>/dev/null && { ((adapter_count++)); adapter_names+="anthropic "; }
[[ "$langchain_refs" -gt 0 ]] 2>/dev/null && { ((adapter_count++)); adapter_names+="langchain "; }
[[ "$vercel_refs" -gt 0 ]] 2>/dev/null && { ((adapter_count++)); adapter_names+="vercel-ai "; }

if [[ "$adapter_count" -eq 0 ]]; then
    warn "No LLM adapter detected — cannot verify consistency"
elif [[ "$adapter_count" -eq 1 ]]; then
    pass "Adapter consistency: using ${adapter_names}only"
else
    warn "Multiple LLM adapters detected (${adapter_names}) — verify this is intentional"
fi

# ── Check 10: CORS headers ──────────────────────────────────────────────────

# Only relevant when backend and frontend appear to be on different ports/origins
cors_hit=$(sgrep -rlE "(Access-Control-Allow-Origin|cors|CORS)" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" . \
    | grep -v node_modules | head -n1)

# Check if there's a separate backend config suggesting cross-origin setup
separate_backend=$(find . -name "server.ts" -o -name "server.js" -o -name "main.py" -o -name "main.go" 2>/dev/null \
    | grep -v node_modules | head -n1)

if [[ -n "$separate_backend" ]]; then
    if [[ -n "$cors_hit" ]]; then
        pass "CORS headers configured (separate backend detected at $separate_backend)"
    else
        fail "Separate backend detected at $separate_backend but no CORS configuration found"
    fi
else
    pass "CORS check: not needed (no separate backend detected)"
fi

# ── Report ───────────────────────────────────────────────────────────────────

echo ""
echo "OpenUI Forge Validation"
echo "========================"
for r in "${results[@]}"; do
    echo "$r"
done
echo "========================"
echo "$passed/$total checks passed"

if [[ "$failed" -gt 0 ]]; then
    echo ""
    echo "Fix the failing checks above to complete your OpenUI setup."
    exit 1
else
    echo ""
    echo "All checks passed. Your OpenUI integration looks good!"
    exit 0
fi
