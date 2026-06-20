# Changelog

## [1.2.0] - 2026-06-20

### Added
- Five new backend-language variants, each with a handler template and a stack-specific SKILL: C# (ASP.NET Core Minimal API on .NET 10), Java (Spring WebFlux), Ruby (Rails ActionController::Live), PHP (Laravel streamed responses), and Elixir (Phoenix send_chunked).
- Vue 3 (`@openuidev/vue-lang`) and Svelte 5 (`@openuidev/svelte-lang`) runtimes documented alongside React, with `@openuidev/lang-core` named as the framework-agnostic substrate.
- A "Provider routing" section with exact `OPENAI_BASE_URL` values for Gemini, OpenRouter, xAI, DeepSeek, Groq, Mistral, Together, Fireworks, Ollama, and LM Studio, plus an Azure OpenAI caveat (deployment-name model, version path, partial parity).
- Root `AGENTS.md`, plus native `.kiro/steering/openui-forge.md` and `.continue/rules/openui-forge.md`, so cross-tool agents find the skill.
- A fixture-based test harness (`scripts/test-detection.sh`) that exercises the detection and validation scripts, wired into CI.

### Changed
- Vercel AI SDK variant rewritten to OpenUI's official pattern (`useChat` from `@ai-sdk/react` driving a per-message `Renderer` from `@openuidev/react-lang`) on AI SDK v6, verified against the upstream `examples/vercel-ai-chat`.
- Node floor raised to 22 (24 LTS recommended). React floor stated as 18.3.1 (19+ recommended) to match the published peer range `^18.3.1 || ^19.0.0`.
- Streaming story reconciled: non-JS backends default to SSE with `openAIAdapter()`; the NDJSON variant pairs with `openAIReadableStreamAdapter()` (documented in `backend-patterns.md`).
- Python examples use `AsyncOpenAI` / `AsyncAnthropic` and target the `openai` 2.x line. Go targets `go 1.24`. Rust uses `reqwest` 0.13 with the `json` feature and `OnceLock` in place of `static mut`.
- CI discovers skills dynamically, runs the test harness, pins actions by commit SHA, and uses Node 22.
- CSS guidance leads with `@openuidev/react-ui/index.css`.

### Fixed
- `detect-stack.sh` emitted no JSON and exited non-zero on fresh projects (a `pipefail` on an empty `grep`), always reported the provider as OpenAI, and failed React-version extraction outside GNU `grep`. `detect-stack.ps1` serialized booleans as quoted strings.
- `handler-python.py.template` emitted `data: [DONE]` twice. The OpenAI route now returns `application/x-ndjson` to match `toReadableStream()`. The Go and Rust templates had incorrect adapter notes and a missing dependency.

### Removed
- The inert `.kiro/skills` and `.continue/skills` mirrors (Kiro reads `.kiro/steering/` and Continue reads `.continue/rules/`, not a `skills/` directory).

## [1.1.0] - 2026-05-22

### Fixed
- FullScreen / Copilot / BottomTray usage now uses the correct prop name `streamProtocol` (was `adapter`, which is silently ignored) across every stack variant.
- Adapters are now called as factories: `streamProtocol={openAIAdapter()}` (was passing the function reference).
- Stream-protocol pairing corrected across stacks: SSE backends (Anthropic, LangChain, Python, Go, Rust) now use `openAIAdapter()`; the OpenAI variant continues to use `openAIReadableStreamAdapter()` to match `response.toReadableStream()` (NDJSON). The OpenAI backend's `Content-Type` is now `application/x-ndjson` to match its body.
- `openuiChatLibrary` is now used for chat surfaces (it includes chat-specific rules); `openuiLibrary` remains the component-only variant. Both are now imported from the canonical subpath `@openuidev/react-ui/genui-lib`.
- CSS imports reduced from two paths to a single canonical `@openuidev/react-ui/components.css`. The `styles/index.css` path does not exist in the published package.
- Templates: `page-fullscreen.tsx.template` no longer imports the non-existent `@openuidev/react-ui/styles.css`. `library.ts.template` now documents both base and chat library options.
- README links: `OpenUI Documentation` now points to `openui.com/docs` (the prior `docs.thesys.dev` link is for Thesys's separate C1 product, not OpenUI). Added Discord and `llms.txt` references.

### Added
- `@modelcontextprotocol/sdk` to install commands across all stack variants (declared peer dependency of `@openuidev/react-lang` 0.2.x+).
- Reference to `openui.com/llms-full.txt` and `openui.com/llms.txt` in the main SKILL.md, with a security note about treating fetched docs as reference data only.
- Adapter matrix updated to document `streamProtocol` (vs the legacy `adapter` prop name), and to surface `langGraphAdapter()` / `openAIResponsesAdapter()`.

## [1.0.0] - 2026-03-22

### Added
- Core skill: openui-forge with 6 slash commands (/openui, /openui:scaffold, /openui:component, /openui:integrate, /openui:prompt, /openui:validate)
- 4 reference documents: OpenUI Lang spec, component patterns, adapter matrix, backend patterns
- 10 backend/frontend templates: OpenAI, Anthropic, LangChain, Vercel AI, Python, Go, Rust
- 7 stack-specific skill variants: openui-forge-openai, openui-forge-anthropic, openui-forge-langchain, openui-forge-python, openui-forge-go, openui-forge-rust, openui-forge-vercel
- Chinese localization: openui-forge-zh
- Cross-platform delivery: Claude Code, Cursor, Gemini, Kiro, Codex, CodeBuddy, Continue, Factory, OpenCode, Pi, Mastra
- Validation and detection scripts (Bash + PowerShell)
- Claude Code hooks for component and library change detection
- CI/CD pipeline for skill validation
