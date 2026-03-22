---
description: Wire up the LLM backend — the core integration command
---

This is the core command. It connects the component library to an LLM backend and creates the streaming pipeline.

Read `references/adapter-matrix.md` before starting — it contains the full adapter internals and compatibility details.

---

## Step 1 — Detect or ask the stack

Check the project for clues about the backend:
- Look for existing API routes (app/api/*, pages/api/*, server/*)
- Check package.json for `openai`, `@anthropic-ai/sdk`, `ai` (Vercel AI SDK), `@langchain/openai`
- Check for non-JS backends: requirements.txt (Python), go.mod (Go), Cargo.toml (Rust)

If the stack cannot be determined automatically, ask the user:
1. What is your backend language? (TypeScript/JavaScript, Python, Go, Rust)
2. What LLM provider or SDK? (OpenAI, Anthropic, Vercel AI SDK, LangChain, other)

---

## Step 2 — Follow the integration matrix

Read `references/adapter-matrix.md` for the full adapter details.

### TypeScript / JavaScript backends

**OpenAI SDK (Chat Completions):**
- Frontend adapter: `openAIReadableStreamAdapter()`
- Frontend format: `openAIMessageFormat`
- Read and adapt: `templates/api-route-openai.ts.template`
- Install: `npm install openai`

**Anthropic SDK (Claude):**
- Frontend adapter: `openAIReadableStreamAdapter()`
- Frontend format: `openAIMessageFormat`
- Read and adapt: `templates/api-route-anthropic.ts.template`
- Install: `npm install @anthropic-ai/sdk`
- Note: The backend converts Anthropic streaming events into OpenAI-compatible NDJSON

**Vercel AI SDK:**
- Frontend: native (uses `useChat` or `processMessage`)
- Read and adapt: `templates/api-route-vercel-ai.ts.template`
- Install: `npm install ai @ai-sdk/openai`
- Note: Uses `streamText` + `toUIMessageStreamResponse()`

**LangChain / LangGraph:**
- Frontend adapter: `openAIReadableStreamAdapter()`
- Frontend format: `openAIMessageFormat`
- Read and adapt: `templates/api-route-langchain.ts.template`
- Install: `npm install @langchain/openai @langchain/core`

### Non-JavaScript backends

Frontend is always React with `openAIReadableStreamAdapter()`. Backend loads system-prompt.txt and streams the LLM response.

Read `references/backend-patterns.md` for complete examples.

**Python (FastAPI):**
- Read and adapt: `templates/handler-python.py.template`
- Install: `pip install fastapi uvicorn openai`

**Go:**
- Read and adapt: `templates/handler-go.go.template`
- Uses net/http + OpenAI API with SSE passthrough

**Rust (Axum):**
- Read and adapt: `templates/handler-rust.rs.template`
- Dependencies: axum, tokio, reqwest, serde_json, async-stream, futures

---

## Step 3 — Generate the integration

1. **Install missing dependencies** for the detected stack
2. **Read the correct template file** from the templates/ directory for this stack
3. **Adapt the template:**
   - Replace all `${VARIABLES}` with actual values (model name, paths, API key env var)
   - Adjust import paths to match the project structure
   - Set the system prompt loading path (file path for non-JS, import for JS)
4. **Create the backend route/handler** in the appropriate location:
   - Next.js: `app/api/chat/route.ts`
   - Vite: `server/chat.ts` or `api/chat.ts`
   - Python: `main.py` or `app/routes/chat.py`
   - Go: `cmd/server/main.go` or `handlers/chat.go`
   - Rust: `src/handlers/chat.rs`
5. **Create or update the frontend page** with the correct adapter and format:
   - Use `templates/page-fullscreen.tsx.template` as the base
   - Set the correct adapter import based on the backend
   - Set `apiUrl` to the backend route path
   - Pass `componentLibrary` to `FullScreen` or `ChatProvider`

---

## Step 4 — Validate

Run `/openui:validate` to verify the full integration works.

---

## CRITICAL RULES

- **NDJSON is the universal format.** For ALL non-OpenAI backends, the backend MUST output OpenAI-compatible NDJSON. Each line must be:
  ```json
  {"id":"...","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"token text"},"finish_reason":null}]}
  ```
  Final chunk must have `"finish_reason":"stop"` and empty delta.

- **One adapter per integration.** Never mix adapters. The frontend adapter must match the backend's output format exactly.

- **System prompt stays server-side.** Never send it to the frontend client. Load it in the API route or backend handler.

- **Always pass componentLibrary.** The `FullScreen`, `Copilot`, or `ChatProvider` component must receive the library so the renderer knows which components to render.
