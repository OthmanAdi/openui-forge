#!/usr/bin/env bash
# OpenUI Forge — Stack Detection Script
# Outputs JSON with project state for the agent to consume
# Always exits 0; the JSON payload conveys the actual state.

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

json_bool()  { [[ "$1" == "true" ]] && echo "true" || echo "false"; }
json_str()   { printf '"%s"' "${1//\"/\\\"}"; }
json_null()  { echo "null"; }

# Safe grep: returns empty on failure, never errors out
sgrep() { grep -r "$@" 2>/dev/null || true; }

# ── 1. package.json ─────────────────────────────────────────────────────────

has_package_json=false
[[ -f "package.json" ]] && has_package_json=true

# ── 2. OpenUI dependencies ──────────────────────────────────────────────────

has_openui_deps=false
if [[ "$has_package_json" == "true" ]]; then
    if grep -qE '"@openuidev/' package.json 2>/dev/null; then
        has_openui_deps=true
    fi
fi

# ── 3. React version ────────────────────────────────────────────────────────

react_version="null"
if [[ "$has_package_json" == "true" ]]; then
    # Try node_modules first (actual installed version)
    if [[ -f "node_modules/react/package.json" ]]; then
        ver=$(grep -oP '"version"\s*:\s*"\K[^"]+' node_modules/react/package.json 2>/dev/null || true)
        [[ -n "$ver" ]] && react_version="\"$ver\""
    fi
    # Fall back to declared dependency
    if [[ "$react_version" == "null" ]]; then
        ver=$(grep -oP '"react"\s*:\s*"[\^~]?\K[0-9][^"]*' package.json 2>/dev/null || true)
        [[ -n "$ver" ]] && react_version="\"$ver\""
    fi
fi

# ── 4. Framework detection ──────────────────────────────────────────────────

framework="unknown"
if ls next.config.* 1>/dev/null 2>&1; then
    framework="nextjs"
elif ls vite.config.* 1>/dev/null 2>&1; then
    framework="vite"
elif [[ "$has_package_json" == "true" ]] && grep -q '"react-scripts"' package.json 2>/dev/null; then
    framework="cra"
fi

# ── 5 & 6. Component library (createLibrary) ────────────────────────────────

has_component_library=false
library_path="null"
lib_hit=$(sgrep -l "createLibrary" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . | head -n1)
if [[ -n "$lib_hit" ]]; then
    has_component_library=true
    library_path="\"$lib_hit\""
fi

# ── 7 & 8. System prompt ────────────────────────────────────────────────────

has_system_prompt=false
prompt_path="null"
prompt_hit=$(find . -name "system-prompt.txt" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -n1)
if [[ -n "$prompt_hit" && -s "$prompt_hit" ]]; then
    has_system_prompt=true
    prompt_path="\"$prompt_hit\""
fi

# ── 9 & 10. Backend route ───────────────────────────────────────────────────

has_backend_route=false
backend_path="null"
route_hit=$(find . -path "*/api/chat/route.*" -not -path "*/node_modules/*" 2>/dev/null | head -n1)
if [[ -n "$route_hit" ]]; then
    has_backend_route=true
    backend_path="\"$route_hit\""
fi

# ── 11. Frontend page with FullScreen / Copilot / ChatProvider ──────────────

has_frontend_page=false
page_hit=$(sgrep -lE "(FullScreen|Copilot|ChatProvider)" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" . \
    | grep -v node_modules | head -n1)
if [[ -n "$page_hit" ]]; then
    has_frontend_page=true
fi

# ── 12. CSS imports ─────────────────────────────────────────────────────────

has_css_imports=false
css_hit=$(sgrep -l "@openuidev/react-ui" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.css" . \
    | grep -v node_modules | head -n1)
if [[ -n "$css_hit" ]]; then
    has_css_imports=true
fi

# ── 13. Backend language ────────────────────────────────────────────────────

backend_language="typescript"  # default assumption for Node projects
if find . -maxdepth 3 -name "*.py" -not -path "*/node_modules/*" 2>/dev/null | grep -q .; then
    py_hit=$(sgrep -lE "(fastapi|flask|openai|anthropic|langchain)" --include="*.py" . | grep -v node_modules | head -n1)
    [[ -n "$py_hit" ]] && backend_language="python"
fi
if find . -maxdepth 3 -name "*.go" -not -path "*/node_modules/*" 2>/dev/null | grep -q .; then
    go_hit=$(sgrep -lE "(net/http|gin|echo|fiber)" --include="*.go" . | grep -v node_modules | head -n1)
    [[ -n "$go_hit" ]] && backend_language="go"
fi
if find . -maxdepth 3 -name "*.rs" -not -path "*/node_modules/*" 2>/dev/null | grep -q .; then
    rs_hit=$(sgrep -lE "(actix|axum|rocket|hyper)" --include="*.rs" . | grep -v node_modules | head -n1)
    [[ -n "$rs_hit" ]] && backend_language="rust"
fi

# ── 14. LLM provider ────────────────────────────────────────────────────────

llm_provider="unknown"
if sgrep -qE "from ['\"]openai['\"]|require\(['\"]openai['\"]" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" .; then
    llm_provider="openai"
elif sgrep -qE "@anthropic-ai/sdk" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" .; then
    llm_provider="anthropic"
elif sgrep -qE "@langchain/" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" .; then
    llm_provider="langchain"
elif sgrep -qE "from ['\"]ai['\"]|require\(['\"]ai['\"]" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" .; then
    llm_provider="vercel-ai"
fi

# ── Emit JSON ────────────────────────────────────────────────────────────────

cat <<EOJSON
{
  "has_package_json": $has_package_json,
  "has_openui_deps": $has_openui_deps,
  "react_version": $react_version,
  "framework": "$framework",
  "has_component_library": $has_component_library,
  "library_path": $library_path,
  "has_system_prompt": $has_system_prompt,
  "prompt_path": $prompt_path,
  "has_backend_route": $has_backend_route,
  "backend_path": $backend_path,
  "has_frontend_page": $has_frontend_page,
  "has_css_imports": $has_css_imports,
  "backend_language": "$backend_language",
  "llm_provider": "$llm_provider"
}
EOJSON

exit 0
