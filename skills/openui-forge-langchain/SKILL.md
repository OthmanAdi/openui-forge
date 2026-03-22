---
name: openui-forge-langchain
description: OpenUI generative UI with LangChain/LangGraph backend. Supports ChatOpenAI and ChatAnthropic.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — LangChain

Build generative UI apps with OpenUI + LangChain. Stream from ChatOpenAI or ChatAnthropic, convert to OpenAI NDJSON.

## Activation Triggers

- "openui langchain", "openui langgraph", "openui langsmith"
- "generative ui langchain", "langchain streaming ui"

## Prerequisites

- Node.js >= 18, React >= 19
- `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` set
- Next.js project (App Router recommended)

## Quick Start

1. Install dependencies (pick one or both LLM providers):
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod @langchain/openai @langchain/core
# For Anthropic: npm install @langchain/anthropic
```
2. Add CSS imports to `app/layout.tsx`:
```tsx
import "@openuidev/react-ui/components.css";
import "@openuidev/react-ui/styles/index.css";
```
3. Create the API route and frontend page below
4. Run `npm run dev` and test

## Full Code

### Backend (OpenAI): `app/api/chat/route.ts`

```typescript
import { openuiLibrary } from "@openuidev/react-ui";
import { ChatOpenAI } from "@langchain/openai";
import { HumanMessage, SystemMessage, AIMessage } from "@langchain/core/messages";

const model = new ChatOpenAI({ modelName: "gpt-4o", streaming: true });

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs.",
  });

  const lcMessages = [
    new SystemMessage(systemPrompt),
    ...messages.map((m: { role: string; content: string }) =>
      m.role === "user" ? new HumanMessage(m.content) : new AIMessage(m.content)
    ),
  ];

  const stream = await model.stream(lcMessages);
  const encoder = new TextEncoder();
  const id = `chatcmpl-${Date.now()}`;

  const readableStream = new ReadableStream({
    async start(controller) {
      for await (const chunk of stream) {
        const text = typeof chunk.content === "string" ? chunk.content : "";
        if (!text) continue;
        const payload = {
          id,
          object: "chat.completion.chunk",
          choices: [{ index: 0, delta: { content: text }, finish_reason: null }],
        };
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(payload)}\n\n`));
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

### Backend (Anthropic variant): `app/api/chat/route.ts`

Replace the model initialization and import:

```typescript
import { ChatAnthropic } from "@langchain/anthropic";

const model = new ChatAnthropic({
  modelName: "claude-sonnet-4-20250514",
  maxTokens: 4096,
  streaming: true,
});
```

Everything else (message mapping, stream conversion, response) stays identical.

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

export const MetricCard = defineComponent({
  name: "MetricCard",
  description: "Displays a metric with label, value, and optional trend",
  props: z.object({
    label: z.string().describe("Metric name"),
    value: z.number().describe("Current metric value"),
    trend: z.enum(["up", "down", "flat"]).optional().describe("Trend direction"),
  }),
  component: ({ props }) => (
    <div style={{ padding: 16, border: "1px solid #e5e7eb", borderRadius: 8 }}>
      <div style={{ fontSize: 14, color: "#6b7280" }}>{props.label}</div>
      <div style={{ fontSize: 24, fontWeight: 700 }}>{props.value}</div>
      {props.trend && <span>{props.trend === "up" ? "+" : props.trend === "down" ? "-" : "="}</span>}
    </div>
  ),
});
```

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out src/generated/system-prompt.txt
```

## Validation Checklist

- [ ] LLM provider API key is set
- [ ] `@langchain/openai` or `@langchain/anthropic` installed
- [ ] Messages correctly mapped to LangChain message types
- [ ] Stream chunks converted to OpenAI NDJSON with `data:` prefix
- [ ] Final chunk has `finish_reason: "stop"` and ends with `data: [DONE]`
- [ ] Frontend uses `openAIReadableStreamAdapter` and `openAIMessageFormat`
- [ ] CSS imports in root layout

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| Empty chunks in stream | LangChain AIMessageChunk content may be empty | Skip chunks where `text` is empty |
| Type error on messages | Wrong LangChain message class | Map `user` to `HumanMessage`, `assistant` to `AIMessage` |
| Module not found | Missing LangChain provider package | Install `@langchain/openai` or `@langchain/anthropic` |
| Stream hangs | Missing `[DONE]` sentinel | Always send final stop chunk and `[DONE]` |
| CORS error | Cross-origin frontend | Add CORS headers if frontend/backend are split |
