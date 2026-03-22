---
name: openui-forge-anthropic
description: OpenUI generative UI with Anthropic Claude SDK backend. Stream conversion to OpenAI NDJSON format.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — Anthropic

Build generative UI apps with OpenUI + Anthropic Claude. Converts Anthropic streaming events to OpenAI-compatible NDJSON.

## Activation Triggers

- "openui anthropic", "openui claude", "openui sonnet"
- "generative ui claude", "claude streaming ui"

## Prerequisites

- Node.js >= 18, React >= 19
- `ANTHROPIC_API_KEY` environment variable set
- Next.js project (App Router recommended)

## Quick Start

1. Install dependencies:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod @anthropic-ai/sdk
```
2. Add CSS imports to `app/layout.tsx`:
```tsx
import "@openuidev/react-ui/components.css";
import "@openuidev/react-ui/styles/index.css";
```
3. Create the API route and frontend page below
4. Run `npm run dev` and test

## Full Code

### Backend: `app/api/chat/route.ts`

The backend streams from Anthropic and converts each event into OpenAI-compatible NDJSON chunks that `openAIReadableStreamAdapter` expects.

```typescript
import { openuiLibrary } from "@openuidev/react-ui";
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs.",
    additionalRules: ["Always use Stack as root when combining multiple components."],
  });

  const stream = client.messages.stream({
    model: "claude-sonnet-4-20250514",
    max_tokens: 4096,
    system: systemPrompt,
    messages,
  });

  const encoder = new TextEncoder();
  const readableStream = new ReadableStream({
    async start(controller) {
      const id = `chatcmpl-${Date.now()}`;
      for await (const event of stream) {
        if (
          event.type === "content_block_delta" &&
          event.delta.type === "text_delta"
        ) {
          const chunk = {
            id,
            object: "chat.completion.chunk",
            choices: [
              {
                index: 0,
                delta: { content: event.delta.text },
                finish_reason: null,
              },
            ],
          };
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify(chunk)}\n\n`)
          );
        }
      }
      const done = {
        id,
        object: "chat.completion.chunk",
        choices: [{ index: 0, delta: {}, finish_reason: "stop" }],
      };
      controller.enqueue(encoder.encode(`data: ${JSON.stringify(done)}\n\n`));
      controller.enqueue(encoder.encode("data: [DONE]\n\n"));
      controller.close();
    },
  });

  return new Response(readableStream, {
    headers: { "Content-Type": "text/event-stream" },
  });
}
```

### Frontend: `app/chat/page.tsx`

```tsx
"use client";
import { FullScreen } from "@openuidev/react-ui";
import { openuiLibrary } from "@openuidev/react-ui";
import {
  openAIReadableStreamAdapter,
  openAIMessageFormat,
} from "@openuidev/react-headless";

export default function ChatPage() {
  return (
    <FullScreen
      componentLibrary={openuiLibrary}
      adapter={openAIReadableStreamAdapter}
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

export const StatusCard = defineComponent({
  name: "StatusCard",
  description: "Displays a status with label and color indicator",
  props: z.object({
    label: z.string().describe("Status label text"),
    status: z.enum(["ok", "warning", "error"]).describe("Current status level"),
  }),
  component: ({ props }) => {
    const colors = { ok: "#22c55e", warning: "#eab308", error: "#ef4444" };
    return (
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ width: 10, height: 10, borderRadius: "50%", background: colors[props.status] }} />
        <span>{props.label}</span>
      </div>
    );
  },
});
```

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out src/generated/system-prompt.txt
```

Or at runtime: `openuiLibrary.prompt({ preamble: "...", additionalRules: [...] })`.

## Validation Checklist

- [ ] `ANTHROPIC_API_KEY` is set in `.env.local`
- [ ] CSS imports present in root layout
- [ ] Backend converts Anthropic `content_block_delta` events to OpenAI NDJSON chunks
- [ ] Final chunk has `finish_reason: "stop"` and ends with `data: [DONE]`
- [ ] Frontend uses `openAIReadableStreamAdapter` and `openAIMessageFormat`
- [ ] `componentLibrary` prop passed to `FullScreen`

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| 401 from Anthropic | Missing or invalid API key | Set `ANTHROPIC_API_KEY` in `.env.local` |
| Stream hangs | Missing `[DONE]` sentinel or `controller.close()` | Ensure final chunk and `[DONE]` are sent |
| Garbled output | Not wrapping in `data: ...` SSE format | Each chunk must be `data: {json}\n\n` |
| Components render as text | Library not passed to FullScreen | Add `componentLibrary` prop |
| `max_tokens` required | Anthropic API requires explicit max_tokens | Always set `max_tokens` (e.g., 4096) |
