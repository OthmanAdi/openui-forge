---
description: Run the full validation pipeline and output a pass/fail checklist
---

Validate the entire OpenUI integration. Run all 10 checks and output a clear pass/fail report.

---

## Validation checks

Run each check in order. For each one, output PASS or FAIL with details.

### Check 1 — Dependencies installed
**How:** Run `npm ls @openuidev/react-lang` (or check package.json for @openuidev packages)
**Pass:** All three core packages are installed (@openuidev/react-lang, @openuidev/react-headless, @openuidev/react-ui)
**Fix if FAIL:** `npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang`

### Check 2 — React >= 19
**How:** Run `npm ls react` and check the version
**Pass:** React version is 19.x or higher
**Fix if FAIL:** `npm install react@latest react-dom@latest`

### Check 3 — Component library exists
**How:** Search for `createLibrary` calls in the project
**Pass:** At least one createLibrary call found, file path identified
**Fix if FAIL:** Run `/openui:component` to create components, or `/openui:scaffold` to set up the library

### Check 4 — Zod .describe() on all props
**How:** In every file containing `defineComponent`, check that all `z.object` fields have `.describe()` calls. Search for Zod field definitions (z.string(), z.number(), z.enum(), z.array(), z.boolean(), z.object()) and verify each has a `.describe()` chained on it.
**Pass:** Every Zod prop field has a `.describe("...")` call
**Fix if FAIL:** Add `.describe("clear description of what this field contains")` to every Zod field. This is critical — it is the LLM's only documentation for each prop.

### Check 5 — System prompt exists
**How:** Search for files named `system-prompt.txt` in the project. Also check if `.prompt()` is called on a library instance in the backend.
**Pass:** Either a non-empty system-prompt.txt file exists, or `.prompt()` is called in the API route
**Fix if FAIL:** Run `/openui:prompt`

### Check 6 — Backend route exists
**How:** Search for API route files (app/api/chat/route.ts, pages/api/chat.ts, server/*.ts, main.py, cmd/server/main.go, src/main.rs, etc.)
**Pass:** A backend handler that processes chat requests is found
**Fix if FAIL:** Run `/openui:integrate`

### Check 7 — Frontend page exists
**How:** Search for imports of `FullScreen`, `Copilot`, `BottomTray`, or `ChatProvider` from `@openuidev/react-ui` or `@openuidev/react-headless`
**Pass:** At least one page or component uses an OpenUI layout component
**Fix if FAIL:** Create a page using `templates/page-fullscreen.tsx.template`

### Check 8 — CSS imports present
**How:** Search for `@openuidev/react-ui/components.css` in layout or entry files
**Pass:** Both CSS imports are present:
  - `@openuidev/react-ui/components.css`
  - `@openuidev/react-ui/styles/index.css`
**Fix if FAIL:** Add both imports to the root layout (Next.js: app/layout.tsx, Vite: main.tsx or App.tsx)

### Check 9 — Adapter matches backend
**How:** Identify which adapter the frontend uses (openAIReadableStreamAdapter, vercelAIAdapter, etc.) and verify it matches the backend's response format.
Read `references/adapter-matrix.md` for the full compatibility matrix.
**Pass:** The adapter type matches the backend's streaming format
**Fix if FAIL:** Change the frontend adapter to match the backend. See the integration matrix in SKILL.md.

### Check 10 — CORS headers (if cross-origin)
**How:** Check if the frontend and backend are on different origins (different ports count). If so, verify the backend sets Access-Control-Allow-Origin headers.
**Pass:** Same-origin setup, or CORS headers are properly configured on the backend
**Fix if FAIL:** Add CORS middleware to the backend (e.g., FastAPI: `add_middleware(CORSMiddleware, ...)`, Express: `cors()`, Go: manual header setting)

---

## Output format

Present results as a checklist:

```
OpenUI Validation Report
========================
[PASS] 1. Dependencies installed
[PASS] 2. React >= 19
[PASS] 3. Component library exists — src/lib/library.ts
[FAIL] 4. Zod .describe() on all props — 3 fields missing .describe() in WeatherCard
[PASS] 5. System prompt exists — src/generated/system-prompt.txt
[PASS] 6. Backend route exists — app/api/chat/route.ts
[PASS] 7. Frontend page exists — app/chat/page.tsx
[FAIL] 8. CSS imports present — missing styles/index.css import
[PASS] 9. Adapter matches backend
[PASS] 10. CORS headers (same-origin)

Result: 8/10 passed

Fixes needed:
- Check 4: Add .describe() to these fields in src/components/WeatherCard.tsx:
    - temperature (z.number)
    - condition (z.string)
    - humidity (z.number)
- Check 8: Add this import to app/layout.tsx:
    import "@openuidev/react-ui/styles/index.css";
```

If all 10 checks pass, confirm the integration is complete and ready for testing.

If any checks fail, provide the specific fix commands or code changes needed for each failure.
