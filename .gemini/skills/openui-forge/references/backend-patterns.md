# Backend Patterns

Complete, production-ready backend examples for Python, Go, and Rust. Every example streams OpenAI-compatible NDJSON that `openAIReadableStreamAdapter()` consumes on the React frontend.

---

## NDJSON Format Reference

All backends in this document output the same NDJSON format. Each line is a complete JSON object:

**Content chunk:**
```json
{"id":"chatcmpl-abc123","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"token text"},"finish_reason":null}]}
```

**Final chunk (signals end of stream):**
```json
{"id":"chatcmpl-abc123","object":"chat.completion.chunk","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
```

Lines are separated by `\n`. No `data:` prefix. No blank lines required.

---

## Python (FastAPI) — OpenAI Variant

Uses the `openai` Python package with streaming, converts to NDJSON via `StreamingResponse`.

### requirements.txt

```
fastapi==0.115.6
uvicorn[standard]==0.34.0
openai==1.59.3
python-dotenv==1.0.1
```

### main.py

```python
import os
import json
import uuid
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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

SYSTEM_PROMPT_PATH = Path(__file__).parent / "system-prompt.txt"
system_prompt = SYSTEM_PROMPT_PATH.read_text(encoding="utf-8")


@app.post("/api/chat")
async def chat(request: Request):
    body = await request.json()
    messages = body.get("messages", [])

    api_messages = [{"role": "system", "content": system_prompt}]
    for msg in messages:
        api_messages.append({
            "role": msg.get("role", "user"),
            "content": msg.get("content", ""),
        })

    stream = client.chat.completions.create(
        model="gpt-4o",
        messages=api_messages,
        stream=True,
    )

    def generate():
        completion_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"
        for chunk in stream:
            delta = chunk.choices[0].delta if chunk.choices else None
            finish_reason = chunk.choices[0].finish_reason if chunk.choices else None

            if delta and delta.content:
                line = json.dumps({
                    "id": completion_id,
                    "object": "chat.completion.chunk",
                    "choices": [{
                        "index": 0,
                        "delta": {"content": delta.content},
                        "finish_reason": None,
                    }],
                })
                yield line + "\n"

            if finish_reason == "stop":
                line = json.dumps({
                    "id": completion_id,
                    "object": "chat.completion.chunk",
                    "choices": [{
                        "index": 0,
                        "delta": {},
                        "finish_reason": "stop",
                    }],
                })
                yield line + "\n"

    return StreamingResponse(generate(), media_type="text/plain")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Run

```bash
pip install -r requirements.txt
python main.py
```

---

## Python (FastAPI) — Anthropic Variant

Uses the `anthropic` Python package. Converts Anthropic streaming events to OpenAI-compatible NDJSON.

### requirements.txt

```
fastapi==0.115.6
uvicorn[standard]==0.34.0
anthropic==0.42.0
python-dotenv==1.0.1
```

### main.py

```python
import os
import json
import uuid
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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

SYSTEM_PROMPT_PATH = Path(__file__).parent / "system-prompt.txt"
system_prompt = SYSTEM_PROMPT_PATH.read_text(encoding="utf-8")


@app.post("/api/chat")
async def chat(request: Request):
    body = await request.json()
    messages = body.get("messages", [])

    api_messages = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if role == "system":
            continue
        api_messages.append({"role": role, "content": content})

    def generate():
        completion_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"

        with client.messages.stream(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=system_prompt,
            messages=api_messages,
        ) as stream:
            for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, "text"):
                        line = json.dumps({
                            "id": completion_id,
                            "object": "chat.completion.chunk",
                            "choices": [{
                                "index": 0,
                                "delta": {"content": event.delta.text},
                                "finish_reason": None,
                            }],
                        })
                        yield line + "\n"

                elif event.type == "message_stop":
                    line = json.dumps({
                        "id": completion_id,
                        "object": "chat.completion.chunk",
                        "choices": [{
                            "index": 0,
                            "delta": {},
                            "finish_reason": "stop",
                        }],
                    })
                    yield line + "\n"

    return StreamingResponse(generate(), media_type="text/plain")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Run

```bash
pip install -r requirements.txt
python main.py
```

---

## Go (net/http)

Uses `net/http` with direct HTTP calls to the OpenAI API. Reads `system-prompt.txt` at startup. Streams SSE from OpenAI and converts to NDJSON passthrough.

### go.mod

```
module openui-backend

go 1.22

require (
	github.com/joho/godotenv v1.5.1
)
```

### main.go

```go
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

var systemPrompt string

func init() {
	_ = godotenv.Load()

	data, err := os.ReadFile("system-prompt.txt")
	if err != nil {
		log.Fatalf("Failed to read system-prompt.txt: %v", err)
	}
	systemPrompt = string(data)
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	Messages []Message `json:"messages"`
}

type OpenAIRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
	Stream   bool      `json:"stream"`
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next(w, r)
	}
}

func chatHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var chatReq ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&chatReq); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	apiMessages := []Message{
		{Role: "system", Content: systemPrompt},
	}
	for _, msg := range chatReq.Messages {
		apiMessages = append(apiMessages, Message{
			Role:    msg.Role,
			Content: msg.Content,
		})
	}

	openaiReq := OpenAIRequest{
		Model:    "gpt-4o",
		Messages: apiMessages,
		Stream:   true,
	}

	reqBody, err := json.Marshal(openaiReq)
	if err != nil {
		http.Error(w, "Failed to marshal request", http.StatusInternalServerError)
		return
	}

	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		http.Error(w, "OPENAI_API_KEY not set", http.StatusInternalServerError)
		return
	}

	httpReq, err := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(reqBody))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		http.Error(w, fmt.Sprintf("OpenAI API error: %v", err), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("OpenAI API returned %d: %s", resp.StatusCode, string(body)), http.StatusBadGateway)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Content-Type-Options", "nosniff")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()

		if !strings.HasPrefix(line, "data: ") {
			continue
		}

		data := strings.TrimPrefix(line, "data: ")

		if data == "[DONE]" {
			break
		}

		// Write the raw JSON (without the "data: " prefix) as NDJSON
		fmt.Fprintf(w, "%s\n", data)
		flusher.Flush()
	}

	if err := scanner.Err(); err != nil {
		log.Printf("Error reading stream: %v", err)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	http.HandleFunc("/api/chat", corsMiddleware(chatHandler))

	log.Printf("Server starting on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
```

### Run

```bash
go mod tidy
go run main.go
```

---

## Rust (Axum)

Uses axum with tokio, reqwest for the OpenAI HTTP call, and async-stream for SSE streaming.

### Cargo.toml

```toml
[package]
name = "openui-backend"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.8"
tokio = { version = "1", features = ["full"] }
reqwest = { version = "0.12", features = ["json", "stream"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
async-stream = "0.3"
futures = "0.3"
tower-http = { version = "0.6", features = ["cors"] }
dotenvy = "0.15"
```

### src/main.rs

```rust
use std::fs;
use std::net::SocketAddr;

use axum::{
    body::Body,
    extract::Json,
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    routing::post,
    Router,
};
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use tower_http::cors::{Any, CorsLayer};

#[derive(Deserialize)]
struct ChatRequest {
    messages: Vec<ChatMessage>,
}

#[derive(Deserialize, Serialize, Clone)]
struct ChatMessage {
    role: String,
    content: String,
}

#[derive(Serialize)]
struct OpenAIRequest {
    model: String,
    messages: Vec<ChatMessage>,
    stream: bool,
}

#[derive(Serialize)]
struct NdjsonChunk {
    id: String,
    object: String,
    choices: Vec<NdjsonChoice>,
}

#[derive(Serialize)]
struct NdjsonChoice {
    index: u32,
    delta: NdjsonDelta,
    finish_reason: Option<String>,
}

#[derive(Serialize)]
struct NdjsonDelta {
    #[serde(skip_serializing_if = "Option::is_none")]
    content: Option<String>,
}

static mut SYSTEM_PROMPT: Option<String> = None;

fn get_system_prompt() -> &'static str {
    unsafe { SYSTEM_PROMPT.as_deref().expect("System prompt not loaded") }
}

async fn chat_handler(Json(body): Json<ChatRequest>) -> impl IntoResponse {
    let api_key = std::env::var("OPENAI_API_KEY").unwrap_or_default();
    if api_key.is_empty() {
        return Response::builder()
            .status(StatusCode::INTERNAL_SERVER_ERROR)
            .body(Body::from("OPENAI_API_KEY not set"))
            .unwrap();
    }

    let mut api_messages = vec![ChatMessage {
        role: "system".to_string(),
        content: get_system_prompt().to_string(),
    }];
    for msg in &body.messages {
        api_messages.push(msg.clone());
    }

    let openai_req = OpenAIRequest {
        model: "gpt-4o".to_string(),
        messages: api_messages,
        stream: true,
    };

    let client = reqwest::Client::new();
    let resp = match client
        .post("https://api.openai.com/v1/chat/completions")
        .header("Authorization", format!("Bearer {}", api_key))
        .header("Content-Type", "application/json")
        .json(&openai_req)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(Body::from(format!("OpenAI API error: {}", e)))
                .unwrap();
        }
    };

    if !resp.status().is_success() {
        let status = resp.status().as_u16();
        let text = resp.text().await.unwrap_or_default();
        return Response::builder()
            .status(StatusCode::BAD_GATEWAY)
            .body(Body::from(format!("OpenAI returned {}: {}", status, text)))
            .unwrap();
    }

    let byte_stream = resp.bytes_stream();

    let ndjson_stream = async_stream::stream! {
        let mut buffer = String::new();

        futures::pin_mut!(byte_stream);

        while let Some(chunk_result) = byte_stream.next().await {
            match chunk_result {
                Ok(bytes) => {
                    buffer.push_str(&String::from_utf8_lossy(&bytes));

                    while let Some(newline_pos) = buffer.find('\n') {
                        let line = buffer[..newline_pos].trim().to_string();
                        buffer = buffer[newline_pos + 1..].to_string();

                        if line.is_empty() {
                            continue;
                        }

                        if !line.starts_with("data: ") {
                            continue;
                        }

                        let data = &line[6..];

                        if data == "[DONE]" {
                            break;
                        }

                        // Pass through the JSON as NDJSON (strip the "data: " prefix)
                        let ndjson_line = format!("{}\n", data);
                        yield Ok::<_, std::io::Error>(ndjson_line);
                    }
                }
                Err(e) => {
                    eprintln!("Stream read error: {}", e);
                    break;
                }
            }
        }
    };

    let body = Body::from_stream(ndjson_stream);

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "text/plain")
        .header(header::CACHE_CONTROL, "no-cache")
        .header("X-Content-Type-Options", "nosniff")
        .body(body)
        .unwrap()
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let prompt = fs::read_to_string("system-prompt.txt")
        .expect("Failed to read system-prompt.txt");
    unsafe {
        SYSTEM_PROMPT = Some(prompt);
    }

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/chat", post(chat_handler))
        .layer(cors);

    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "8000".to_string())
        .parse()
        .unwrap_or(8000);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("Server starting on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

### Run

```bash
cargo run
```

---

## System Prompt Loading

All backends load `system-prompt.txt` at startup. This file is generated by the CLI:

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out system-prompt.txt
```

Place `system-prompt.txt` in the backend's working directory (next to `main.py`, `main.go`, or `src/main.rs`).

The system prompt contains:
- The OpenUI Lang specification (subset relevant to the component library)
- All component definitions with their Zod schemas serialized as instructions
- Component group organization
- Example outputs
- Rules and constraints

**Never expose the system prompt to the frontend.** It is always loaded and injected server-side.

---

## React Frontend Page

This frontend page works with ALL of the backends above. It uses `openAIReadableStreamAdapter()` and `openAIMessageFormat`, which is the universal combination for custom backends.

```tsx
"use client";

import {
  ChatProvider,
  openAIReadableStreamAdapter,
  openAIMessageFormat,
} from "@openuidev/react-headless";
import { FullScreen } from "@openuidev/react-ui";
import { myLibrary } from "@/lib/library";

// Required CSS imports — add these to your root layout.tsx if not already present:
// import "@openuidev/react-ui/components.css";
// import "@openuidev/react-ui/styles/index.css";

export default function ChatPage() {
  return (
    <ChatProvider
      apiUrl={process.env.NEXT_PUBLIC_CHAT_API_URL || "http://localhost:8000/api/chat"}
      adapter={openAIReadableStreamAdapter()}
      messageFormat={openAIMessageFormat}
      componentLibrary={myLibrary}
    >
      <FullScreen />
    </ChatProvider>
  );
}
```

### Layout with CSS (Next.js)

The root `layout.tsx` must include the OpenUI CSS:

```tsx
import "@openuidev/react-ui/components.css";
import "@openuidev/react-ui/styles/index.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

### Alternative: Copilot Layout

For a sidebar copilot instead of full-screen chat:

```tsx
"use client";

import {
  ChatProvider,
  openAIReadableStreamAdapter,
  openAIMessageFormat,
} from "@openuidev/react-headless";
import { Copilot } from "@openuidev/react-ui";
import { myLibrary } from "@/lib/library";

export default function AppPage() {
  return (
    <ChatProvider
      apiUrl={process.env.NEXT_PUBLIC_CHAT_API_URL || "http://localhost:8000/api/chat"}
      adapter={openAIReadableStreamAdapter()}
      messageFormat={openAIMessageFormat}
      componentLibrary={myLibrary}
    >
      <div style={{ display: "flex", height: "100vh" }}>
        <main style={{ flex: 1, padding: "2rem" }}>
          {/* Your app content here */}
          <h1>My Application</h1>
        </main>
        <Copilot />
      </div>
    </ChatProvider>
  );
}
```

---

## Environment Variables

All backends expect these environment variables (set via `.env` file or system environment):

| Variable | Required For | Description |
|----------|-------------|-------------|
| `OPENAI_API_KEY` | OpenAI variants (Python, Go, Rust) | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic variant (Python) | Anthropic API key |
| `PORT` | All (optional) | Server port. Defaults to `8000`. |
| `NEXT_PUBLIC_CHAT_API_URL` | React frontend (optional) | Backend URL. Defaults to `http://localhost:8000/api/chat`. |

### .env example

```
OPENAI_API_KEY=sk-proj-...
ANTHROPIC_API_KEY=sk-ant-...
PORT=8000
```

**Never commit `.env` files to version control.** Add `.env` to `.gitignore`.

---

## Error Handling Checklist

When debugging a backend integration:

1. **Backend starts but stream hangs:** Check that the API key is set and valid. Check that `system-prompt.txt` exists and is readable.
2. **Frontend receives data but components do not render:** Verify the NDJSON format. Each line must be a complete JSON object. Check that `delta.content` contains the actual token text.
3. **CORS errors in browser console:** Verify the CORS middleware is applied. The `Access-Control-Allow-Origin` header must be present on the response.
4. **Partial render then stops:** Ensure the final chunk has `"finish_reason": "stop"`. Without it, the frontend keeps waiting for more data.
5. **Garbled output:** Ensure the response `Content-Type` is `text/plain` (not `text/event-stream` or `application/json`). The `openAIReadableStreamAdapter()` expects plain NDJSON, not SSE.
6. **Stream works but components show as raw text:** Verify that `componentLibrary` is passed to `ChatProvider` and that the system prompt was generated from the same library.
