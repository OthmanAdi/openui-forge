# OpenUI Forge

Build production generative UI applications with OpenUI. Any LLM provider. Any backend language. One skill.

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/OthmanAdi/openui-forge)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![skills.sh weekly downloads](https://img.shields.io/badge/skills.sh-weekly%20downloads-orange)](https://skills.sh/OthmanAdi/openui-forge)
[![GitHub stars](https://img.shields.io/github/stars/OthmanAdi/openui-forge)](https://github.com/OthmanAdi/openui-forge/stargazers)
[![Skill Validation](https://github.com/OthmanAdi/openui-forge/actions/workflows/skill-validation.yml/badge.svg)](https://github.com/OthmanAdi/openui-forge/actions/workflows/skill-validation.yml)

---

## What is this?

OpenUI Forge is an agent skill that helps you build generative UI applications using [OpenUI](https://docs.openui.dev/), a streaming-first framework where LLMs output a compact DSL (OpenUI Lang) instead of JSON or HTML. The result: 67% fewer tokens, progressive rendering as tokens arrive, and graceful handling of hallucinated components.

This skill covers the full development lifecycle: scaffolding new projects, creating components with Zod schemas, integrating any LLM backend (OpenAI, Anthropic, LangChain, Vercel AI), supporting non-JS backends (Python, Go, Rust), and validating the entire stack.

---

## Install

```bash
# Full skill (all stacks)
npx skills add OthmanAdi/openui-forge --skill openui-forge -g

# Stack-specific
npx skills add OthmanAdi/openui-forge --skill openui-forge-openai -g
npx skills add OthmanAdi/openui-forge --skill openui-forge-anthropic -g
npx skills add OthmanAdi/openui-forge --skill openui-forge-langchain -g
npx skills add OthmanAdi/openui-forge --skill openui-forge-python -g
npx skills add OthmanAdi/openui-forge --skill openui-forge-go -g
npx skills add OthmanAdi/openui-forge --skill openui-forge-rust -g
npx skills add OthmanAdi/openui-forge --skill openui-forge-vercel -g

# Chinese localization
npx skills add OthmanAdi/openui-forge --skill openui-forge-zh -g
```

---

## Supported Stacks

| Stack | Language | LLM Provider | Frontend Adapter |
|-------|----------|-------------|-----------------|
| OpenAI SDK | TypeScript | OpenAI | `openAIReadableStreamAdapter()` |
| Anthropic SDK | TypeScript | Anthropic (Claude) | `openAIReadableStreamAdapter()` |
| LangChain / LangGraph | TypeScript | Any (via LangChain) | `openAIReadableStreamAdapter()` |
| Vercel AI SDK | TypeScript | Any (via AI SDK) | Native (`useChat`) |
| Python (FastAPI) | Python | OpenAI / Anthropic | `openAIReadableStreamAdapter()` |
| Go (net/http) | Go | OpenAI | `openAIReadableStreamAdapter()` |
| Rust (Axum) | Rust | OpenAI | `openAIReadableStreamAdapter()` |

---

## Commands

| Command | Description |
|---------|-------------|
| `/openui` | Smart detection. Analyzes the project and recommends the next action. |
| `/openui:scaffold` | Interactive scaffolding. Creates or adds OpenUI to an existing project. |
| `/openui:component` | Create a new component with Zod schema and React renderer. |
| `/openui:integrate` | Wire up the LLM backend for any supported stack. |
| `/openui:prompt` | Generate or regenerate the system prompt from the component library. |
| `/openui:validate` | Full validation pipeline with 10 automated checks. |

---

## Architecture

```
Component Library    System Prompt       LLM Backend
(Zod + React)   --> (generated)     --> (any provider)
                                            |
                                            | stream (OpenUI Lang)
                                            v
Live UI          <-- Parser          <-- Adapter
(React)              (react-lang)        (per provider)
```

**Flow:** Define components with Zod schemas and React renderers, assemble into a library, generate a system prompt, the LLM outputs OpenUI Lang, the adapter normalizes the stream, and the parser renders React components progressively.

**NPM Packages:**

| Package | Purpose |
|---------|---------|
| `@openuidev/react-lang` | Core: defineComponent, createLibrary, Renderer, prompt generation |
| `@openuidev/react-headless` | State: ChatProvider, streaming adapters, message formats (Zustand) |
| `@openuidev/react-ui` | UI: FullScreen/Copilot/BottomTray layouts, 30+ built-in components, theming |
| `@openuidev/cli` | CLI: scaffold apps, generate system prompts |

---

## Supported Platforms

- Claude Code
- Cursor
- Gemini CLI
- Kiro
- Codex CLI
- CodeBuddy
- Continue
- Factory
- OpenCode
- Pi
- Mastra

---

## Links

- [OpenUI Documentation](https://docs.openui.dev/)
- [OpenUI GitHub](https://github.com/openuidev)
- [skills.sh](https://skills.sh/)
- [Author Portfolio](https://othmanadi.com)

---

Made by [OthmanAdi](https://github.com/OthmanAdi)
