---
name: openui-forge-rust
description: OpenUI generative UI with Rust Axum backend. Async SSE streaming with reqwest and async-stream.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — Rust

Build generative UI apps with a React frontend + Rust Axum backend. Async SSE streaming to OpenAI-compatible NDJSON.

## Activation Triggers

- "openui rust", "openui axum", "openui rust backend"
- "generative ui rust", "rust streaming ui backend"

## Prerequisites

- Node.js >= 18 + React >= 19 (frontend)
- Rust >= 1.75 with Cargo (backend)
- `OPENAI_API_KEY` environment variable set

## Quick Start

1. Create the React frontend and install OpenUI deps:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
```
2. Generate the system prompt:
```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/system-prompt.txt
```
3. Create the Rust backend (see Full Code below)
4. Run: `cargo run` on `:3001`, frontend on `:3000`

## Full Code

### Backend: `backend/Cargo.toml`

```toml
[package]
name = "openui-backend"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
reqwest = { version = "0.12", features = ["stream"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
async-stream = "0.3"
futures = "0.3"
tower-http = { version = "0.5", features = ["cors"] }
dotenvy = "0.15"
```

### Backend: `backend/src/main.rs`

```rust
use axum::{extract::Json, response::sse::{Event, Sse}, routing::post, Router};
use futures::stream::Stream;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::{convert::Infallible, fs, net::SocketAddr};
use tower_http::cors::{Any, CorsLayer};

#[derive(Deserialize)]
struct ChatRequest {
    messages: Vec<Message>,
}

#[derive(Serialize, Deserialize, Clone)]
struct Message {
    role: String,
    content: String,
}

static mut SYSTEM_PROMPT: String = String::new();

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let prompt = fs::read_to_string("system-prompt.txt")
        .expect("system-prompt.txt not found");
    unsafe { SYSTEM_PROMPT = prompt; }

    let cors = CorsLayer::new()
        .allow_origin("http://localhost:3000".parse::<http::HeaderValue>().unwrap())
        .allow_methods([http::Method::POST])
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/chat", post(chat_handler))
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3001));
    println!("Rust backend listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn chat_handler(
    Json(req): Json<ChatRequest>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let system_prompt = unsafe { SYSTEM_PROMPT.clone() };
    let mut messages = vec![Message { role: "system".into(), content: system_prompt }];
    messages.extend(req.messages);

    let api_key = std::env::var("OPENAI_API_KEY").expect("OPENAI_API_KEY not set");
    let client = Client::new();

    let stream = async_stream::stream! {
        let resp = client
            .post("https://api.openai.com/v1/chat/completions")
            .bearer_auth(&api_key)
            .json(&serde_json::json!({
                "model": "gpt-4o",
                "stream": true,
                "messages": messages,
            }))
            .send()
            .await;

        if let Ok(resp) = resp {
            let mut bytes_stream = resp.bytes_stream();
            use futures::StreamExt;
            let mut buffer = String::new();
            while let Some(Ok(chunk)) = bytes_stream.next().await {
                buffer.push_str(&String::from_utf8_lossy(&chunk));
                while let Some(pos) = buffer.find("\n\n") {
                    let line = buffer[..pos].to_string();
                    buffer = buffer[pos + 2..].to_string();
                    if line.starts_with("data: ") {
                        yield Ok(Event::default().data(&line[6..]));
                    }
                }
            }
        }
    };

    Sse::new(stream)
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
      apiUrl="http://localhost:3001/api/chat"
    />
  );
}
```

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/system-prompt.txt
```

## Validation Checklist

- [ ] `system-prompt.txt` exists in the Rust backend directory
- [ ] `OPENAI_API_KEY` is set in environment or `.env`
- [ ] CORS layer allows the frontend origin
- [ ] SSE events forward OpenAI stream chunks correctly
- [ ] Buffer parsing handles partial SSE lines across chunk boundaries
- [ ] Frontend `apiUrl` points to `http://localhost:3001/api/chat`
- [ ] Frontend uses `openAIReadableStreamAdapter` and `openAIMessageFormat`
- [ ] CSS imports in root layout

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| `system-prompt.txt not found` | File missing | Run CLI generate command |
| CORS blocked | Origin not in CorsLayer | Update `.allow_origin()` |
| Partial SSE events | Chunk boundary splitting | Buffer and split on `\n\n` boundaries (handled in code) |
| Compile error on `http::HeaderValue` | Missing `http` crate | `tower-http` re-exports it, or add `http = "1"` to deps |
| Connection reset | Tokio runtime panic | Check `.await` on all async calls, verify `features = ["full"]` |
