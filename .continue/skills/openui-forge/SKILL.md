---
name: openui-forge
description: Build generative UI with OpenUI — any LLM provider, any backend language. Scaffold, integrate, validate.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge

Build production generative UI applications with OpenUI. Any LLM. Any backend. One skill.

OpenUI is a streaming-first generative UI framework. LLMs output a compact DSL (OpenUI Lang) instead of JSON or HTML — 67% fewer tokens, progressive rendering as tokens arrive, and graceful handling of hallucinated components. The React runtime parses and renders live interactive components.

## Activation Triggers

Auto-activate when any of these appear in the user's message:

- "openui", "open ui", "generative ui", "genui", "gen ui"
- "build ui with ai", "ai generated interface", "llm render ui"
- "openui lang", "openui component", "@openuidev"
- "streaming ui", "copilot ui", "chat ui with components"
- "thesys", "openui-forge"

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

**Flow:** Define components with Zod schemas + React renderers --> Assemble into library --> Generate system prompt --> LLM outputs OpenUI Lang --> Adapter normalizes stream --> Parser renders React components progressively.

**NPM Packages:**

| Package | Purpose |
|---------|---------|
| `@openuidev/react-lang` | Core: defineComponent, createLibrary, Renderer, prompt generation |
| `@openuidev/react-headless` | State: ChatProvider, streaming adapters, message formats (Zustand) |
| `@openuidev/react-ui` | UI: FullScreen/Copilot/BottomTray layouts, 30+ built-in components, theming |
| `@openuidev/cli` | CLI: scaffold apps, generate system prompts |

## Prerequisites

- Node.js >= 18
- React >= 19 (peer dependency of all @openuidev packages)
- One LLM provider configured (OpenAI, Anthropic, or other)
- For non-JS backends: `npx @openuidev/cli` to pre-generate system prompt as .txt file

---

## Commands

### /openui

Smart detection. Analyzes the current project and recommends the next action.

**Workflow:**

1. Run `scripts/detect-stack.sh` (or `.ps1`) to identify the project state
2. Check for: package.json with OpenUI deps, createLibrary calls, system-prompt.txt, chat route/endpoint
3. Output a status table:

```
OpenUI Status
-------------------------------------------
Dependencies     [installed / missing]
Component Lib    [found at path / not found]
System Prompt    [generated / not found]
Backend Route    [found at path / not found]
Frontend Page    [found at path / not found]
CSS Imports      [present / missing]
-------------------------------------------
Recommended: /openui:scaffold (or whichever is next)
```

### /openui:scaffold

Interactive project scaffolding. Creates or adds OpenUI to a project.

**Decision Tree:**

```
Existing project detected?
|
+-- NO --> npx @openuidev/cli@latest create --name ${PROJECT_NAME}
|          Done. Run /openui:integrate next.
|
+-- YES --> What framework?
    |
    +-- Next.js
    |   1. npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
    |   2. Add CSS imports to root layout:
    |      import "@openuidev/react-ui/components.css";
    |      import "@openuidev/react-ui/styles/index.css";
    |   3. Create component library file (or use built-in openuiLibrary)
    |   4. Run /openui:integrate to wire the backend
    |
    +-- Vite + React
    |   Same deps as Next.js. Create a proxy to backend in vite.config.ts.
    |
    +-- Non-JS backend (Python / Go / Rust)
        1. Create React frontend (Next.js or Vite) with OpenUI deps
        2. npx @openuidev/cli generate ./src/lib/library.ts --out system-prompt.txt
        3. Copy system-prompt.txt to backend service
        4. Use template from templates/handler-{python|go|rust} for backend
        5. Configure frontend apiUrl to point to backend
```

### /openui:component

Create a new component with Zod schema and React renderer.

**Workflow:**

1. Ask: What does this component display? What props does it need?
2. Read `references/component-patterns.md` for examples matching the use case
3. Create the component using `defineComponent` from `@openuidev/react-lang`:

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const ${NAME} = defineComponent({
  name: "${NAME}",
  description: "${DESCRIPTION}",
  props: z.object({
    // props here — use .describe() on EVERY field
  }),
  component: ({ props }) => (
    // JSX here
  ),
});
```

4. Add to library in the createLibrary call
5. Run /openui:prompt to regenerate the system prompt

**Component Design Rules (CRITICAL for LLM generation quality):**

- `.describe()` on EVERY Zod prop — this is the LLM's only documentation
- Flat schemas — avoid nesting deeper than 2 levels
- Specific types — `z.enum(["sm","md","lg"])` over `z.string()`
- Under 30 components in one library — more = more prompt tokens = worse output
- Group related components with `componentGroups` for LLM organization
- Clear, unique names — the LLM picks components by name + description alone
- Use `ref` from other DefinedComponents for nested component references

**Read `references/component-patterns.md` for 10+ production examples.**

### /openui:integrate

**THE CORE COMMAND.** Wire up the LLM backend.

**Step 1 — Detect or ask the stack:**

What is your backend language and LLM provider?

**Step 2 — Follow the integration matrix:**

```
TYPESCRIPT / JAVASCRIPT BACKENDS
================================

OpenAI SDK (Chat Completions)
  Frontend adapter: openAIReadableStreamAdapter()
  Frontend format:  openAIMessageFormat
  Template:         templates/api-route-openai.ts.template
  Install:          npm install openai
  Stream format:    NDJSON (response.toReadableStream())

Anthropic SDK (Claude)
  Frontend adapter: openAIReadableStreamAdapter()
  Frontend format:  openAIMessageFormat
  Template:         templates/api-route-anthropic.ts.template
  Install:          npm install @anthropic-ai/sdk
  Note:             Backend converts Anthropic events --> OpenAI NDJSON

Vercel AI SDK
  Frontend adapter: (native — uses useChat or processMessage)
  Frontend format:  (native)
  Template:         templates/api-route-vercel-ai.ts.template
  Install:          npm install ai @ai-sdk/openai
  Note:             Uses streamText + toUIMessageStreamResponse()

LangChain / LangGraph
  Frontend adapter: openAIReadableStreamAdapter()
  Frontend format:  openAIMessageFormat
  Template:         templates/api-route-langchain.ts.template
  Install:          npm install @langchain/openai @langchain/core
  Note:             Converts LangChain stream chunks --> OpenAI NDJSON


NON-JAVASCRIPT BACKENDS
=======================
Frontend is always React with openAIReadableStreamAdapter().
Backend loads system-prompt.txt (generated by CLI) and streams LLM response.

Python (FastAPI)
  Template:  templates/handler-python.py.template
  Install:   pip install fastapi uvicorn openai
  Note:      Supports both OpenAI and Anthropic SDK variants

Go
  Template:  templates/handler-go.go.template
  Note:      Uses net/http + OpenAI API. SSE passthrough.

Rust (Axum)
  Template:  templates/handler-rust.rs.template
  Deps:      axum, tokio, reqwest, serde_json, async-stream, futures
  Note:      Async SSE streaming with Axum.
```

**Step 3 — Generate the integration:**

1. Install any missing dependencies
2. Read the template file for the detected stack
3. Adapt template: replace ${VARIABLES}, adjust paths, set model name
4. Create the backend route/handler
5. Create or update the frontend page with correct adapter + format
6. Use `templates/page-fullscreen.tsx.template` for the frontend page

**Step 4 — Validate:**

Run /openui:validate to verify the full integration.

**CRITICAL RULE:** For ALL non-OpenAI backends, the backend MUST output OpenAI-compatible NDJSON. The frontend openAIReadableStreamAdapter() expects each line to be:

```json
{"id":"...","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"token text"},"finish_reason":null}]}
```

Final chunk must have `"finish_reason":"stop"` and empty delta.

**Read `references/adapter-matrix.md` for adapter internals.**
**Read `references/backend-patterns.md` for complete Python/Go/Rust examples.**

### /openui:prompt

Generate or regenerate the system prompt from the component library.

**Approach 1 — CLI (recommended, required for non-JS backends):**

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out src/generated/system-prompt.txt
```

For JSON Schema output (useful for structured generation):
```bash
npx @openuidev/cli generate ./src/lib/library.ts --json-schema --out src/generated/schema.json
```

**Approach 2 — Runtime (JS backends that import the library):**

```typescript
import { myLibrary } from "./lib/library";

const systemPrompt = myLibrary.prompt({
  preamble: "You are a helpful assistant that generates interactive UIs.",
  additionalRules: [
    "Always use Stack as root when combining multiple components.",
    "Prefer existing components over generating raw text.",
  ],
  examples: [
    'root = Stack([title, chart])\ntitle = Header("Sales")\nchart = BarChart(labels, [s1])\nlabels = ["Q1","Q2"]\ns1 = Series("Rev", [100, 200])',
  ],
});
```

**When to regenerate:**

- After adding, removing, or modifying any component
- After changing component descriptions or Zod schemas
- After modifying prompt options (preamble, rules, examples)

### /openui:validate

Full validation pipeline.

**Checks (in order):**

| # | Check | How | Fix |
|---|-------|-----|-----|
| 1 | Dependencies installed | `npm ls @openuidev/react-lang` | `npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang` |
| 2 | React >= 19 | `npm ls react` | `npm install react@latest react-dom@latest` |
| 3 | Component library exists | grep for `createLibrary` | Run /openui:component |
| 4 | Zod .describe() on all props | AST check or grep | Add `.describe("...")` to every Zod field |
| 5 | System prompt exists | find `**/system-prompt.txt` | Run /openui:prompt |
| 6 | Backend route exists | find `**/api/chat/route.ts` or similar | Run /openui:integrate |
| 7 | Frontend page exists | find FullScreen/Copilot/ChatProvider usage | Use page template |
| 8 | CSS imports present | grep for `@openuidev/react-ui/components.css` | Add imports to root layout |
| 9 | Adapter matches backend | verify adapter type vs backend response format | See integration matrix |
| 10 | CORS headers (if cross-origin) | check backend response headers | Add CORS middleware |

**Output:** Checklist with PASS/FAIL for each check. Fix suggestions for failures.

Run `scripts/validate.sh` (or `.ps1`) for automated checks.

---

## OpenUI Lang Quick Reference

The DSL that LLMs generate. One statement per line. Streaming-friendly.

```
root = Stack([header, content])        # First line MUST assign root
header = Header("Dashboard", "2024")   # Positional args = Zod schema key order
content = BarChart(labels, [s1])       # References to other identifiers
labels = ["Jan", "Feb", "Mar"]         # Arrays
s1 = Series("Revenue", [10, 20, 30])  # Forward references OK (hoisted)
```

**Types:** strings `"..."`, numbers `42`, booleans `true/false`, null, arrays `[...]`, objects `{key: value}`, component calls `Name(args)`, references `identifier`.

**Read `references/openui-lang-spec.md` for the full specification.**

---

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| React 19 peer dependency | OpenUI requires React >= 19 | `npm i react@latest react-dom@latest` |
| Components not rendering | Missing CSS imports | Add both CSS imports to root layout |
| Stream hangs / no output | Wrong adapter for backend format | Match adapter to response — see integration matrix |
| Hallucinated components | LLM outputs components not in library | Reduce count, improve descriptions. Renderer warns gracefully. |
| Props type mismatch | LLM sends wrong types | Add `.describe()` with clear type hints |
| CORS blocked | Backend on different origin | Add CORS headers to backend |
| Blank screen | System prompt not loaded | Verify path, check API route loads it |
| Partial renders then stop | NDJSON format mismatch | Ensure each line is valid JSON, final chunk has finish_reason:stop |
| Components render as text | Renderer not connected to library | Pass componentLibrary prop to FullScreen/ChatProvider |
| Prompt too large | Too many components | Keep under 30 components, remove unused ones |

---

## Operational Principles

1. **Detect before creating** — Always run /openui first to understand what exists
2. **Template then customize** — Start from the exact template for the user's stack
3. **Regenerate after component changes** — System prompt and library must stay in sync
4. **One adapter per integration** — Never mix adapters
5. **Validate after every change** — Run /openui:validate after any integration modification
6. **System prompt stays server-side** — Never expose to frontend client
7. **Read references before writing** — Check the relevant reference file for complete examples
8. **NDJSON is the universal format** — When in doubt, output OpenAI-compatible NDJSON from backend
