---
name: openui-forge-vercel
description: OpenUI generative UI with Vercel AI SDK. streamText, toUIMessageStreamResponse, and tools support.
version: 1.2.0
author: OthmanAdi
---

# OpenUI Forge — Vercel AI SDK

Build generative UI apps with OpenUI + Vercel AI SDK. Native streaming with `streamText` and `toUIMessageStreamResponse()`.

## Activation Triggers

- "openui vercel", "openui vercel ai", "openui ai sdk"
- "generative ui vercel", "vercel ai streaming ui"
- "useChat openui", "streamText openui"

## Prerequisites

- Node.js >= 22 (24 LTS recommended), React >= 18.3.1 (19+ recommended)
- `OPENAI_API_KEY` environment variable set
- Next.js project (App Router)

## Quick Start

1. Install dependencies:
```bash
npm install @openuidev/react-ui @openuidev/react-lang lucide-react zod ai @ai-sdk/openai @ai-sdk/react
```
Pin to the AI SDK v6 line: `ai@^6`, `@ai-sdk/openai@^3`, `@ai-sdk/react@^3`.
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
import { convertToModelMessages, streamText } from "ai";
import { openai } from "@ai-sdk/openai";

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiChatLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs.",
    additionalRules: ["Always use Stack as root when combining multiple components."],
  });

  // AI SDK v6: convert the UI message stream into model messages before passing to the model.
  const modelMessages = await convertToModelMessages(messages);

  const result = streamText({
    model: openai(process.env.OPENAI_MODEL ?? "gpt-5.5"),
    system: systemPrompt,
    messages: modelMessages,
  });

  return result.toUIMessageStreamResponse();
}
```

### Backend with Tools: `app/api/chat/route.ts`

```typescript
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import { convertToModelMessages, streamText, tool, stepCountIs } from "ai";
import { openai } from "@ai-sdk/openai";
import { z } from "zod";

export async function POST(req: Request) {
  const { messages } = await req.json();

  const systemPrompt = openuiChatLibrary.prompt({
    preamble: "You are a helpful assistant that generates interactive UIs. Use tools to fetch data before rendering.",
  });

  // AI SDK v6: convert the UI message stream into model messages before passing to the model.
  const modelMessages = await convertToModelMessages(messages);

  const result = streamText({
    model: openai(process.env.OPENAI_MODEL ?? "gpt-5.5"),
    system: systemPrompt,
    messages: modelMessages,
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
    // AI SDK v6: stopWhen replaces the removed `maxSteps` option.
    stopWhen: stepCountIs(3),
  });

  return result.toUIMessageStreamResponse();
}
```

### Frontend (useChat + Renderer): `app/chat/page.tsx`

Drive the conversation with `useChat` from `@ai-sdk/react`, then render each assistant message with a per-message `<Renderer>` from `@openuidev/react-lang`. The Renderer takes the assistant text as `response`, the component library as `library` (NOT `componentLibrary`), an `isStreaming` flag for the in-flight message, and an `onAction` handler for built-in actions like continuing the conversation.

```tsx
"use client";
import { useChat } from "@ai-sdk/react";
import { Renderer, BuiltinActionType } from "@openuidev/react-lang";
import type { ActionEvent } from "@openuidev/react-lang";
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import { useState } from "react";

export default function ChatPage() {
  const [input, setInput] = useState("");
  const { messages, sendMessage, status } = useChat();
  const isLoading = status === "submitted" || status === "streaming";

  const handleSend = (text: string) => {
    const trimmed = text.trim();
    if (!trimmed || isLoading) return;
    setInput("");
    sendMessage({ text: trimmed });
  };

  const handleAction = (event: ActionEvent) => {
    if (event.type === BuiltinActionType.ContinueConversation && event.humanFriendlyMessage) {
      handleSend(event.humanFriendlyMessage);
    }
  };

  return (
    <div>
      {messages.map((message, i) => {
        const isLast = i === messages.length - 1;

        if (message.role === "user") {
          const text = message.parts
            .filter((p): p is { type: "text"; text: string } => p.type === "text")
            .map((p) => p.text)
            .join("");
          return <div key={message.id}>{text}</div>;
        }

        // assistant: render generative UI from the text parts
        const response = message.parts
          .filter((p): p is { type: "text"; text: string } => p.type === "text")
          .map((p) => p.text)
          .join("");

        return (
          <Renderer
            key={message.id}
            response={response}
            library={openuiChatLibrary}
            isStreaming={isLoading && isLast}
            onAction={handleAction}
          />
        );
      })}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          handleSend(input);
        }}
      >
        <input value={input} onChange={(e) => setInput(e.target.value)} />
        <button type="submit" disabled={isLoading}>Send</button>
      </form>
    </div>
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
- [ ] `ai`, `@ai-sdk/openai`, and `@ai-sdk/react` packages installed (v6 line: `ai@^6`, `@ai-sdk/openai@^3`, `@ai-sdk/react@^3`)
- [ ] Route converts UI messages with `convertToModelMessages(messages)` and passes `messages: modelMessages` to `streamText`
- [ ] Route uses `streamText` and returns `result.toUIMessageStreamResponse()`
- [ ] Frontend drives the chat with `useChat` from `@ai-sdk/react` (`messages`, `sendMessage`, `status`)
- [ ] Each assistant message is rendered with `<Renderer response={...} library={openuiChatLibrary} isStreaming={...} onAction={...} />` from `@openuidev/react-lang`
- [ ] Renderer prop is `library={openuiChatLibrary}` (NOT `componentLibrary`)
- [ ] CSS import in root layout
- [ ] If using tools: `stopWhen: stepCountIs(n)` is set (AI SDK v6 replacement for the removed `maxSteps`), tool results feed back to model
- [ ] Tools declared with `inputSchema:` (v6 rename of `parameters:`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| `ai` module not found | Missing Vercel AI SDK | `npm install ai @ai-sdk/openai @ai-sdk/react` |
| `useChat` is not exported / not found | Importing the hook from `ai` | Import `useChat` from `@ai-sdk/react` and install `@ai-sdk/react@^3` |
| Empty / mismatched model messages | Passing raw UI `messages` straight to `streamText` | `const modelMessages = await convertToModelMessages(messages)`, then pass `messages: modelMessages` |
| Type error on `maxSteps` | `maxSteps` removed in AI SDK v6 | Import `stepCountIs` from `ai` and use `stopWhen: stepCountIs(3)` |
| Type error on tool `parameters` | Renamed to `inputSchema` in AI SDK v6 | Rename `parameters:` to `inputSchema:` in every `tool({...})` definition |
| Blank response | Wrong export from `@ai-sdk/openai` | Use `openai("gpt-5.5")` not `new OpenAI()` |
| Generative UI does not render | `componentLibrary` prop passed to `Renderer`, or rendering `message.content` instead of joined text parts | Use `library={openuiChatLibrary}` and pass the joined `text` parts as `response={...}` |
