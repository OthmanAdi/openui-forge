# Changelog

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
