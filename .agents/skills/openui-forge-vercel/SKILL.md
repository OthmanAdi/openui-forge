---
name: openui-forge-vercel
description: OpenUI generative UI with Vercel AI SDK. streamText, toUIMessageStreamResponse, and tools support.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — Vercel AI SDK

Build generative UI apps with OpenUI + Vercel AI SDK. Native streaming with `streamText` and `toUIMessageStreamResponse()`.

## Activation Triggers

- "openui vercel", "openui vercel ai", "openui ai sdk"
- "generative ui vercel", "vercel ai streaming ui"
- "useChat openui", "streamText openui"

## Prerequisites

- Node.js >= 18, React >= 19
- `OPENAI_API_KEY` environment variable set
- Next.js project (App Router)

## Quick Start

1. Install dependencies:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang @modelcontextprotocol/sdk lucide-react zod ai @ai-sdk/openai
```
2. Add the CSS import to `app/layout.tsx`:
```tsx
import "@openuidev/react-ui/components.css";
```
3. Create the API route and frontend page below
4. Run `npm run dev` and test

## Full Code

### Backend: `app/api/chat/route.ts`

```typescript
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import { streamText } from "ai";
import { openai } from "@ai-sdk/openai";

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiChatLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs.",
    additionalRules: ["Always use Stack as root when combining multiple components."],
  });

  const result = streamText({
    model: openai(process.env.OPENAI_MODEL ?? "gpt-5.5"),
    system: systemPrompt,
    messages,
  });

  return result.toUIMessageStreamResponse();
}
```

### Backend with Tools: `app/api/chat/route.ts`

```typescript
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import { streamText, tool, stepCountIs } from "ai";
import { openai } from "@ai-sdk/openai";
import { z } from "zod";

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiChatLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs. Use tools to fetch data before rendering.",
  });

  const result = streamText({
    model: openai(process.env.OPENAI_MODEL ?? "gpt-5.5"),
    system: systemPrompt,
    messages,
    tools: {
      getWeather: tool({
        description: "Get current weather for a city",
        inputSchema: z.object({
          city: z.string().describe("City name"),
        }),
        execute: async ({ city }) => {
          return { city, temp: 22, condition: "sunny" };
        },
      }),
    },
    // AI SDK v5+: stopWhen replaces the removed `maxSteps` option.
    stopWhen: stepCountIs(3),
  });

  return result.toUIMessageStreamResponse();
}
```

### Frontend (with processMessage): `app/chat/page.tsx`

```tsx
"use client";
import { FullScreen } from "@openuidev/react-ui";
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";

async function processMessage(messages: { role: string; content: string }[]) {
  const res = await fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ messages }),
  });
  if (!res.body) throw new Error("No response body");
  return res.body;
}

export default function ChatPage() {
  return (
    <FullScreen
      componentLibrary={openuiChatLibrary}
      processMessage={processMessage}
    />
  );
}
```

## Component Creation

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const WeatherCard = defineComponent({
  name: "WeatherCard",
  description: "Displays weather information for a location",
  props: z.object({
    city: z.string().describe("City name"),
    temp: z.number().describe("Temperature in Celsius"),
    condition: z.enum(["sunny", "cloudy", "rainy", "snowy"]).describe("Weather condition"),
  }),
  component: ({ props }) => (
    <div style={{ padding: 16, borderRadius: 12, background: "#f0f9ff" }}>
      <h3>{props.city}</h3>
      <div style={{ fontSize: 32 }}>{props.temp}C</div>
      <div>{props.condition}</div>
    </div>
  ),
});
```

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out src/generated/system-prompt.txt
```

Or at runtime via `openuiChatLibrary.prompt()` as shown in the route.

## Validation Checklist

- [ ] `OPENAI_API_KEY` is set in `.env.local`
- [ ] `ai` and `@ai-sdk/openai` packages installed
- [ ] Route uses `streamText` and returns `result.toUIMessageStreamResponse()`
- [ ] Frontend uses `processMessage` returning `response.body` (the Vercel AI SDK stream is consumed natively, no `streamProtocol` needed)
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] CSS import in root layout
- [ ] If using tools: `stopWhen: stepCountIs(n)` is set (AI SDK v5+ replacement for the removed `maxSteps`), tool results feed back to model
- [ ] Tools declared with `inputSchema:` (v5+ rename of `parameters:`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| `ai` module not found | Missing Vercel AI SDK | `npm install ai @ai-sdk/openai` |
| Stream format mismatch | Trying to use `openAIReadableStreamAdapter` with Vercel AI's UI message stream | Drop `streamProtocol`. Use `processMessage` returning `response.body` — the AI SDK stream is consumed natively |
| Type error on `maxSteps` | `maxSteps` removed in AI SDK v5+ | Import `stepCountIs` from `ai` and use `stopWhen: stepCountIs(3)` |
| Type error on tool `parameters` | Renamed to `inputSchema` in AI SDK v5+ | Rename `parameters:` to `inputSchema:` in every `tool({...})` definition |
| Blank response | Wrong export from `@ai-sdk/openai` | Use `openai("gpt-4o")` not `new OpenAI()` |
| Props silently ignored | Passing `messages`/`onSend`/`isLoading` props to `FullScreen` | `FullScreen` does not accept these — use `processMessage` instead |
