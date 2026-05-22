# Agent C — security and code-quality (completed 2026-05-22)

## Critical (fix before broader distribution)

1. **Python SKILL.md uses sync OpenAI in async handler** — `skills/openui-forge-python/SKILL.md:68,76`
   - `client = OpenAI()` then `client.chat.completions.create(stream=True ...)` inside `async def chat()`. Blocks the event loop.
   - The template at `handler-python.py.template:16,31` correctly uses `AsyncOpenAI`. The SKILL.md contradicts its own template.
   - Fix: `from openai import AsyncOpenAI; client = AsyncOpenAI()`, `await` the call, `async for chunk in response`.

2. **Rust template ships wide-open CORS** — `skills/openui-forge/templates/handler-rust.rs.template:187`
   - `.allow_origin(Any)`. SKILL.md is locked to `http://localhost:3000` but the template anyone scaffolds from is open to all origins.
   - Fix: `.allow_origin("${FRONTEND_ORIGIN}".parse::<HeaderValue>().unwrap())`.

3. **Rust SKILL.md uses unsafe `static mut`** — `skills/openui-forge-rust/SKILL.md:79,86,106`
   - `static mut SYSTEM_PROMPT: String = String::new();` + `unsafe { ... }`. Rust 2024 deprecates this; data race on multi-threaded runtimes.
   - Fix: Replace with the template's `State<Arc<AppState>>` pattern (already correct at `handler-rust.rs.template:66-70`).

4. **Go SKILL.md `io.Copy` defeats streaming** — `skills/openui-forge-go/SKILL.md:137`
   - `io.Copy(w, resp.Body)` blocks until upstream EOF; `flusher.Flush()` runs once. User sees nothing until generation ends.
   - Fix: Replace with `bufio.Scanner` per-line + flush, matching `handler-go.go.template:168-190`.

## Medium

5. **No rate-limit / auth / body-size guidance** in any backend SKILL.md. Unauthenticated `/api/chat` lets any caller burn the deployed key. Add a "Hardening" section per backend.
6. **CI runs unpinned `npx -y skills`** — `.github/workflows/skill-validation.yml:197`. Auto-installs latest with full lifecycle scripts under `GITHUB_TOKEN`. Pin a version + `--ignore-scripts`.
7. **`detect-stack.sh` JSON-escape bug on Windows paths** — `skills/openui-forge/scripts/detect-stack.sh:65,75,85`. Backslashes break JSON.
8. **`validate.sh:162-164` has dead code** — bare `true` makes the conditional a no-op.

## Style / best-practice

9. First-party GitHub actions not SHA-pinned (`@v4`).
10. `validate.sh` uses `set -uo pipefail` without `-e` (intentional but inconsistent with `detect-stack.sh` which uses `-euo`). Add comment.
11. `validate.ps1` `$ErrorActionPreference = "SilentlyContinue"` masks real bugs.

## Came up clean (don't redo)

- No `eval` / `new Function` / `innerHTML` / `dangerouslySetInnerHTML` anywhere in `skills/`.
- We do NOT replicate the thesys upstream `calculate` tool's `new Function(...)` RCE pattern (we ship no tool implementations).
- No hardcoded keys/secrets. All providers read from env.
- `scripts/sync-platforms.sh` is correctly hardened (`set -euo pipefail`, quoted expansions).
- All TS route templates validate `Array.isArray(messages)`.
- Semgrep `--config=auto` (51 rules, 27 files): **0 findings.**
