---
name: openui-forge-python
description: OpenUI generative UI with Python FastAPI backend. OpenAI and Anthropic SDK variants.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — Python

Build generative UI apps with a React frontend + Python FastAPI backend. Streams OpenAI-compatible NDJSON.

## Activation Triggers

- "openui python", "openui fastapi", "openui flask"
- "generative ui python", "python streaming ui backend"

## Prerequisites

- Node.js >= 18 + React >= 19 (frontend)
- Python >= 3.10 (backend)
- `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` set

## Quick Start

1. Create the React frontend and install OpenUI deps:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
```
2. Generate the system prompt from your component library:
```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/system-prompt.txt
```
3. Set up the Python backend (see Full Code below)
4. Run both: frontend on `:3000`, backend on `:8000`

## Full Code

### Backend: `backend/requirements.txt`

```
fastapi>=0.104.0
uvicorn>=0.24.0
openai>=1.6.0
anthropic>=0.40.0
python-dotenv>=1.0.0
```

### Backend (OpenAI): `backend/main.py`

```python
import os
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from openai import OpenAI

load_dotenv()
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["POST"],
    allow_headers=["*"],
)

client = OpenAI()
SYSTEM_PROMPT = Path("system-prompt.txt").read_text()

@app.post("/api/chat")
async def chat(request: Request):
    body = await request.json()
    messages = [{"role": "system", "content": SYSTEM_PROMPT}] + body["messages"]

    response = client.chat.completions.create(
        model="gpt-4o", stream=True, messages=messages
    )

    def generate():
        for chunk in response:
            data = chunk.model_dump_json()
            yield f"data: {data}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
```

### Backend (Anthropic variant): `backend/main_anthropic.py`

```python
import os, json, time
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from anthropic import Anthropic

load_dotenv()
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["POST"],
    allow_headers=["*"],
)

client = Anthropic()
SYSTEM_PROMPT = Path("system-prompt.txt").read_text()

@app.post("/api/chat")
async def chat(request: Request):
    body = await request.json()
    stream_id = f"chatcmpl-{int(time.time())}"

    def generate():
        with client.messages.stream(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            messages=body["messages"],
        ) as stream:
            for text in stream.text_stream:
                chunk = {"id": stream_id, "object": "chat.completion.chunk",
                         "choices": [{"index": 0, "delta": {"content": text}, "finish_reason": None}]}
                yield f"data: {json.dumps(chunk)}\n\n"
        done = {"id": stream_id, "object": "chat.completion.chunk",
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]}
        yield f"data: {json.dumps(done)}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
```

### Frontend: `app/chat/page.tsx` (or `src/Chat.tsx` for Vite)

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
      apiUrl="http://localhost:8000/api/chat"
    />
  );
}
```

## System Prompt Generation

Generate once, copy to backend directory:

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/system-prompt.txt
```

Regenerate after every component change.

## Validation Checklist

- [ ] `system-prompt.txt` exists in the backend directory
- [ ] CORS allows the frontend origin
- [ ] Backend streams `data: {json}\n\n` lines with OpenAI chunk format
- [ ] Final chunk has `finish_reason: "stop"` followed by `data: [DONE]`
- [ ] Frontend `apiUrl` points to the correct backend URL
- [ ] Frontend uses `openAIReadableStreamAdapter` and `openAIMessageFormat`
- [ ] CSS imports in root layout
- [ ] Run backend: `uvicorn main:app --reload --port 8000`

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Frontend origin not allowed | Add origin to `allow_origins` list |
| Connection refused | Backend not running | Start with `uvicorn main:app --port 8000` |
| FileNotFoundError | system-prompt.txt missing | Run the CLI generate command |
| Stream not rendering | Backend not sending SSE format | Ensure `data: ` prefix and `\n\n` after each chunk |
| 422 Unprocessable Entity | Request body missing `messages` | Check frontend sends `{ messages: [...] }` |
