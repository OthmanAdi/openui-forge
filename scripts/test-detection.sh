#!/usr/bin/env bash
# Fixture-based tests for the skill's detection + validation scripts.
# No test framework: builds throwaway projects, runs the scripts, asserts output.
# Exit 0 = all pass, exit 1 = at least one failure. Used by CI and locally.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DETECT="$HERE/../skills/openui-forge/scripts/detect-stack.sh"
VALIDATE="$HERE/../skills/openui-forge/scripts/validate.sh"

# Pick a python that actually runs (skips the broken Windows Store 'python3' stub).
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import sys" >/dev/null 2>&1; then PY="$cand"; break; fi
done
if [[ -z "$PY" ]]; then echo "python3 (or python) is required to run these tests"; exit 2; fi

fails=0
pass() { echo "  ok   - $1"; }
fail() { echo "  FAIL - $1"; fails=$((fails + 1)); }
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 (want '$2', got '$3')"; fi
}

# Extract a detect-stack JSON field; booleans normalized to lower-case, null -> "".
field() {
  "$PY" -c "import json,sys; v=json.load(sys.stdin).get('$1'); print(str(v).lower() if isinstance(v,bool) else ('' if v is None else v))" 2>/dev/null
}

is_json() { "$PY" -m json.tool >/dev/null 2>&1 && echo yes || echo no; }

make_next_openai() { # dir
  mkdir -p "$1/src/lib" "$1/src/generated" "$1/app/api/chat" "$1/app/chat"
  printf '{"dependencies":{"@openuidev/react-ui":"^0.11.9","react":"^19.0.0"}}' > "$1/package.json"
  echo 'module.exports={}' > "$1/next.config.js"
  echo 'export const lib = createLibrary({name:"x"})' > "$1/src/lib/library.ts"
  echo 'system prompt body' > "$1/src/generated/system-prompt.txt"
  printf 'import OpenAI from "openai"\nexport async function POST(){}' > "$1/app/api/chat/route.ts"
  echo 'import { FullScreen } from "@openuidev/react-ui"' > "$1/app/chat/page.tsx"
  echo 'import "@openuidev/react-ui/index.css"' > "$1/app/layout.tsx"
}

echo "== detect-stack.sh: empty directory =="
t=$(mktemp -d); out=$(cd "$t" && bash "$DETECT"); ec=$?
check "exit 0 on empty" "0" "$ec"
check "valid JSON on empty" "yes" "$(printf '%s' "$out" | is_json)"
check "has_package_json=false" "false" "$(printf '%s' "$out" | field has_package_json)"
check "framework=unknown" "unknown" "$(printf '%s' "$out" | field framework)"
check "llm_provider=unknown" "unknown" "$(printf '%s' "$out" | field llm_provider)"
rm -rf "$t"

echo "== detect-stack.sh: Next.js + OpenAI fixture =="
t=$(mktemp -d); make_next_openai "$t"; out=$(cd "$t" && bash "$DETECT"); ec=$?
check "exit 0" "0" "$ec"
check "valid JSON" "yes" "$(printf '%s' "$out" | is_json)"
check "has_package_json=true" "true" "$(printf '%s' "$out" | field has_package_json)"
check "has_openui_deps=true" "true" "$(printf '%s' "$out" | field has_openui_deps)"
check "react_version=19.0.0" "19.0.0" "$(printf '%s' "$out" | field react_version)"
check "framework=nextjs" "nextjs" "$(printf '%s' "$out" | field framework)"
check "has_component_library=true" "true" "$(printf '%s' "$out" | field has_component_library)"
check "has_system_prompt=true" "true" "$(printf '%s' "$out" | field has_system_prompt)"
check "has_backend_route=true" "true" "$(printf '%s' "$out" | field has_backend_route)"
check "has_frontend_page=true" "true" "$(printf '%s' "$out" | field has_frontend_page)"
check "has_css_imports=true" "true" "$(printf '%s' "$out" | field has_css_imports)"
check "llm_provider=openai" "openai" "$(printf '%s' "$out" | field llm_provider)"
rm -rf "$t"

echo "== detect-stack.sh: Python backend fixture =="
t=$(mktemp -d)
printf 'from fastapi import FastAPI\nfrom anthropic import Anthropic\n' > "$t/main.py"
out=$(cd "$t" && bash "$DETECT"); ec=$?
check "exit 0" "0" "$ec"
check "backend_language=python" "python" "$(printf '%s' "$out" | field backend_language)"
rm -rf "$t"

echo "== validate.sh: React floor =="
react_line() { # version -> the [PASS]/[FAIL] React line
  local t; t=$(mktemp -d)
  printf '{"dependencies":{"@openuidev/react-lang":"^0.2.6","react":"%s"}}' "$1" > "$t/package.json"
  (cd "$t" && bash "$VALIDATE" 2>&1) | grep -i "React version" | head -n1
  rm -rf "$t"
}
case "$(react_line '^19.0.0')" in *"[PASS]"*) pass "react 19.0.0 passes" ;; *) fail "react 19.0.0 should pass" ;; esac
case "$(react_line '18.3.1')"  in *"[PASS]"*) pass "react 18.3.1 passes" ;; *) fail "react 18.3.1 should pass" ;; esac
case "$(react_line '18.2.0')"  in *"[FAIL]"*) pass "react 18.2.0 fails"  ;; *) fail "react 18.2.0 should fail" ;; esac

echo ""
if [[ "$fails" -eq 0 ]]; then
  echo "All detection/validation tests passed."
  exit 0
else
  echo "$fails test(s) failed."
  exit 1
fi
