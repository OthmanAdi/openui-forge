---
name: openui-forge-openai
description: OpenUI generative UI with OpenAI SDK backend. Streaming chat completions with gpt-4o.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — OpenAI

Build generative UI apps with OpenUI + OpenAI SDK. One backend, one adapter, streaming out of the box.

## Activation Triggers

- "openui openai", "openui gpt", "openui chatgpt"
- "generative ui openai", "openai streaming ui"

## Prerequisites

- Node.js >= 18, React >= 19
- `OPENAI_API_KEY` environment variable set
- Next.js project (App Router recommended)

## Quick Start

1. Install dependencies:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang @modelcontextprotocol/sdk lucide-react zod openai
```
2. Add the CSS import to `app/layout.tsx`:
```tsx
import "@openuidev/react-ui/components.css";
```
3. Create the API route (Step 4 below)
4. Create the frontend page (Step 5 below)
5. Run `npm run dev` and test

## Full Code

### Backend: `app/api/chat/route.ts`

```typescript
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import OpenAI from "openai";

const client = new OpenAI();

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiChatLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs.",
    additionalRules: ["Always use Stack as root when combining multiple components."],
  });

  const response = await client.chat.completions.create({
    model: "gpt-4o",
    stream: true,
    messages: [{ role: "system", content: systemPrompt }, ...messages],
  });

  // response.toReadableStream() produces NDJSON (one JSON object per line, no SSE `data:` prefix).
  // Pair with openAIReadableStreamAdapter() on the frontend.
  return new Response(response.toReadableStream(), {
    headers: { "Content-Type": "application/x-ndjson" },
  });
}
```

### Frontend: `app/chat/page.tsx`

```tsx
"use client";
import { FullScreen } from "@openuidev/react-ui";
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import {
  openAIReadableStreamAdapter,
  openAIMessageFormat,
} from "@openuidev/react-headless";

export default function ChatPage() {
  return (
    <FullScreen
      componentLibrary={openuiChatLibrary}
      streamProtocol={openAIReadableStreamAdapter()}
      messageFormat={openAIMessageFormat}
      apiUrl="/api/chat"
    />
  );
}
```

## Component Creation

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const MyCard = defineComponent({
  name: "MyCard",
  description: "A card displaying a title and body text",
  props: z.object({
    title: z.string().describe("The card heading"),
    body: z.string().describe("The card body content"),
  }),
  component: ({ props }) => (
    <div style={{ border: "1px solid #ddd", borderRadius: 8, padding: 16 }}>
      <h3>{props.title}</h3>
      <p>{props.body}</p>
    </div>
  ),
});
```

Add to a custom library with `createLibrary([MyCard, ...others])` or use the built-in `openuiLibrary`.

## System Prompt Generation

For runtime generation (used in the route above), call `library.prompt()`. For a static file:

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out src/generated/system-prompt.txt
```

## Validation Checklist

- [ ] `OPENAI_API_KEY` is set in `.env.local`
- [ ] CSS import present in root layout
- [ ] API route returns `response.toReadableStream()` with `application/x-ndjson` content type
- [ ] Frontend uses `streamProtocol={openAIReadableStreamAdapter()}` and `openAIMessageFormat`
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] React >= 19 installed

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| 401 from OpenAI | Missing or invalid API key | Set `OPENAI_API_KEY` in `.env.local` |
| Stream hangs | Missing `toReadableStream()` call | Ensure `stream: true` and return `response.toReadableStream()` |
| Components render as text | Library not passed to FullScreen | Add `componentLibrary={openuiChatLibrary}` prop |
| Blank screen | CSS not imported | Add `@openuidev/react-ui/components.css` to root layout |
| Nothing renders, no error | Wrong prop name (`adapter` is silently ignored) | Rename to `streamProtocol` and call the adapter as a function: `streamProtocol={openAIReadableStreamAdapter()}` |
| Partial render then stop | Model finished mid-output | Check token limits, increase `max_tokens` if needed |
