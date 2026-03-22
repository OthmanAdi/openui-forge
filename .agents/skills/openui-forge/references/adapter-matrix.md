# Adapter Matrix

Detailed documentation of all streaming adapters and message formats in `@openuidev/react-headless`.

Adapters normalize different streaming protocols into a unified AG-UI event stream. Message formats convert between OpenUI's internal message structure and provider-specific message formats.

---

## Streaming Adapters

Every adapter implements the same interface: it receives a `Response` from `fetch()` and yields a stream of `AGUIEvent` objects that the renderer consumes.

### agUIAdapter()

**Import:** `import { agUIAdapter } from "@openuidev/react-headless";`

**Format consumed:** AG-UI Server-Sent Events (SSE)

```
data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"msg_1","delta":"Hello "}\n\n
data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"msg_1","delta":"world"}\n\n
data: {"type":"TEXT_MESSAGE_END","messageId":"msg_1"}\n\n
```

**When to use:** This is the default adapter. Use it when your backend emits the native AG-UI protocol events. This is common when using the AG-UI server SDK or when building a backend specifically for OpenUI.

**Usage:**
```tsx
import { agUIAdapter } from "@openuidev/react-headless";

<ChatProvider
  adapter={agUIAdapter()}
  // ...
/>
```

---

### openAIAdapter()

**Import:** `import { openAIAdapter } from "@openuidev/react-headless";`

**Format consumed:** OpenAI Chat Completions SSE

```
data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}

data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

**When to use:** Use when your backend proxies the raw OpenAI Chat Completions SSE stream without transformation. The response must have `Content-Type: text/event-stream` and follow the `data: {json}\n\n` SSE format with `data: [DONE]` as the terminator.

**Usage:**
```tsx
import { openAIAdapter } from "@openuidev/react-headless";

<ChatProvider
  adapter={openAIAdapter()}
  // ...
/>
```

---

### openAIResponsesAdapter()

**Import:** `import { openAIResponsesAdapter } from "@openuidev/react-headless";`

**Format consumed:** OpenAI Responses API SSE

```
event: response.output_item.added
data: {"type":"message","id":"msg_abc","role":"assistant","content":[]}

event: response.content_part.added
data: {"type":"output_text","text":""}

event: response.output_text.delta
data: {"delta":"Hello "}

event: response.output_text.delta
data: {"delta":"world"}

event: response.output_text.done
data: {"text":"Hello world"}

event: response.done
data: {"id":"resp_abc","status":"completed"}
```

**When to use:** Use when your backend uses the newer OpenAI Responses API (not Chat Completions). The Responses API uses named SSE events (`event: response.output_text.delta`) rather than generic `data:` lines.

**Usage:**
```tsx
import { openAIResponsesAdapter } from "@openuidev/react-headless";

<ChatProvider
  adapter={openAIResponsesAdapter()}
  // ...
/>
```

---

### openAIReadableStreamAdapter()

**Import:** `import { openAIReadableStreamAdapter } from "@openuidev/react-headless";`

**Format consumed:** Newline-Delimited JSON (NDJSON)

```
{"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
{"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}
{"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}
{"id":"chatcmpl-abc","object":"chat.completion.chunk","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
```

Each line is a complete JSON object. No `data:` prefix. No blank lines required between entries.

**When to use:** This is THE MOST COMMON adapter for custom backends. Use it when:
- Your backend calls the OpenAI SDK and uses `response.toReadableStream()` to pipe NDJSON
- Your backend is in Python, Go, Rust, or any non-JS language that constructs OpenAI-compatible NDJSON
- You want the simplest possible streaming format from your backend

This is the universal adapter for non-JavaScript backends. Every backend template in this skill uses this adapter.

**Usage:**
```tsx
import { openAIReadableStreamAdapter } from "@openuidev/react-headless";

<ChatProvider
  adapter={openAIReadableStreamAdapter()}
  // ...
/>
```

**NDJSON format reference:** Each line must be a valid JSON object matching the OpenAI Chat Completion chunk schema:

```json
{
  "id": "chatcmpl-unique-id",
  "object": "chat.completion.chunk",
  "choices": [
    {
      "index": 0,
      "delta": {
        "content": "token text here"
      },
      "finish_reason": null
    }
  ]
}
```

The final chunk must have `"finish_reason": "stop"` and an empty or missing `delta.content`:

```json
{
  "id": "chatcmpl-unique-id",
  "object": "chat.completion.chunk",
  "choices": [
    {
      "index": 0,
      "delta": {},
      "finish_reason": "stop"
    }
  ]
}
```

---

### Custom Adapter

If none of the built-in adapters match your protocol, implement the `StreamProtocolAdapter` interface:

```typescript
import type { StreamProtocolAdapter, AGUIEvent } from "@openuidev/react-headless";

const myCustomAdapter: StreamProtocolAdapter = {
  async *parse(response: Response): AsyncIterable<AGUIEvent> {
    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.trim()) continue;

        // Parse your custom format here
        const parsed = JSON.parse(line);

        // Yield AG-UI events
        yield {
          type: "TEXT_MESSAGE_CONTENT",
          messageId: parsed.id,
          delta: parsed.text,
        };
      }
    }

    // Signal end of message
    yield {
      type: "TEXT_MESSAGE_END",
      messageId: "final",
    };
  },
};
```

Pass the custom adapter to ChatProvider:

```tsx
<ChatProvider
  adapter={myCustomAdapter}
  // ...
/>
```

---

## Message Formats

Message formats handle the conversion between OpenUI's internal message representation and provider-specific API formats. They are used when sending conversation history to the backend.

### identityMessageFormat

**Import:** `import { identityMessageFormat } from "@openuidev/react-headless";`

The default. Passes messages through without transformation. Use when your backend expects the native AG-UI message format.

```typescript
// AG-UI native format
{
  id: "msg_1",
  role: "user",
  content: "Show me a sales dashboard"
}
```

---

### openAIMessageFormat

**Import:** `import { openAIMessageFormat } from "@openuidev/react-headless";`

Converts between OpenUI messages and OpenAI Chat Completions messages.

**Methods:**
- `.toApi(messages)` — converts OpenUI messages to OpenAI `{ role, content }` format for sending to the API
- `.fromApi(messages)` — converts OpenAI messages back to OpenUI format

```typescript
// OpenUI internal format
{ id: "msg_1", role: "user", content: "Hello" }

// Converted to OpenAI format by .toApi()
{ role: "user", content: "Hello" }
```

**Usage:**
```tsx
import { openAIMessageFormat } from "@openuidev/react-headless";

<ChatProvider
  messageFormat={openAIMessageFormat}
  // ...
/>
```

**When to use:** Use with any backend that expects OpenAI Chat Completions message format (the vast majority of backends).

---

### openAIConversationMessageFormat

**Import:** `import { openAIConversationMessageFormat } from "@openuidev/react-headless";`

Converts between OpenUI messages and OpenAI Responses API conversation items.

```typescript
// Converted to Responses API format
{
  type: "message",
  role: "user",
  content: [{ type: "input_text", text: "Hello" }]
}
```

**When to use:** Use only with backends that use the OpenAI Responses API (not Chat Completions).

---

### Custom Message Format

Implement the `MessageFormat` interface for custom message structures:

```typescript
import type { MessageFormat, UIMessage } from "@openuidev/react-headless";

const myMessageFormat: MessageFormat = {
  toApi(messages: UIMessage[]): unknown[] {
    return messages.map((msg) => ({
      sender: msg.role === "user" ? "human" : "ai",
      text: msg.content,
      timestamp: Date.now(),
    }));
  },

  fromApi(messages: unknown[]): UIMessage[] {
    return (messages as any[]).map((msg, i) => ({
      id: `msg_${i}`,
      role: msg.sender === "human" ? "user" : "assistant",
      content: msg.text,
    }));
  },
};
```

---

## Decision Matrix

Use this table to select the correct adapter and message format for your backend.

| Backend | Adapter | Message Format | Notes |
|---------|---------|----------------|-------|
| **OpenAI SDK (Node.js)** — `response.toReadableStream()` | `openAIReadableStreamAdapter()` | `openAIMessageFormat` | Most common JS integration. Stream is NDJSON from `.toReadableStream()`. |
| **OpenAI SDK (Node.js)** — raw SSE passthrough | `openAIAdapter()` | `openAIMessageFormat` | When piping the raw SSE response body directly. |
| **OpenAI Responses API** | `openAIResponsesAdapter()` | `openAIConversationMessageFormat` | Newer Responses API with named SSE events. |
| **Anthropic SDK (Node.js)** | `openAIReadableStreamAdapter()` | `openAIMessageFormat` | Backend converts Anthropic events to OpenAI NDJSON format. |
| **Vercel AI SDK** | Native (uses `useChat` or `processMessage`) | Native | Vercel AI SDK has built-in OpenUI support via `toUIMessageStreamResponse()`. |
| **LangChain / LangGraph (Node.js)** | `openAIReadableStreamAdapter()` | `openAIMessageFormat` | Backend converts LangChain stream chunks to OpenAI NDJSON. |
| **Python (FastAPI / Flask)** | `openAIReadableStreamAdapter()` | `openAIMessageFormat` | Backend streams NDJSON via StreamingResponse. See `backend-patterns.md`. |
| **Go (net/http)** | `openAIReadableStreamAdapter()` | `openAIMessageFormat` | Backend writes NDJSON lines to ResponseWriter. See `backend-patterns.md`. |
| **Rust (Axum)** | `openAIReadableStreamAdapter()` | `openAIMessageFormat` | Backend streams NDJSON via SSE/Body. See `backend-patterns.md`. |
| **Custom / AG-UI native** | `agUIAdapter()` | `identityMessageFormat` | When using the AG-UI server SDK or custom AG-UI backend. |

**Rule of thumb:** If you are not sure which adapter to use, use `openAIReadableStreamAdapter()` with `openAIMessageFormat`. This combination works with any backend that can emit OpenAI-compatible NDJSON, which covers the majority of real-world integrations.

---

## Full Frontend Wiring Example

Putting it all together with a custom Python backend:

```tsx
"use client";

import { ChatProvider, openAIReadableStreamAdapter, openAIMessageFormat } from "@openuidev/react-headless";
import { FullScreen } from "@openuidev/react-ui";
import { myLibrary } from "@/lib/library";

export default function ChatPage() {
  return (
    <ChatProvider
      apiUrl="http://localhost:8000/api/chat"
      adapter={openAIReadableStreamAdapter()}
      messageFormat={openAIMessageFormat}
      componentLibrary={myLibrary}
    >
      <FullScreen />
    </ChatProvider>
  );
}
```

Key properties on `ChatProvider`:

| Prop | Required | Description |
|------|----------|-------------|
| `apiUrl` | Yes | URL of the backend chat endpoint |
| `adapter` | Yes | Streaming protocol adapter to parse the response |
| `messageFormat` | Yes | Message format converter for conversation history |
| `componentLibrary` | Yes | The library created with `createLibrary` |
| `headers` | No | Additional HTTP headers (e.g., auth tokens) |
| `onError` | No | Error callback for stream failures |
