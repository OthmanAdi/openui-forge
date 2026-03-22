---
name: openui-forge-go
description: OpenUI generative UI with Go (net/http) backend. Direct OpenAI API streaming via HTTP.
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge — Go

Build generative UI apps with a React frontend + Go backend. Streams OpenAI API responses directly via net/http.

## Activation Triggers

- "openui go", "openui golang", "openui go backend"
- "generative ui go", "go streaming ui backend"

## Prerequisites

- Node.js >= 18 + React >= 19 (frontend)
- Go >= 1.21 (backend)
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
3. Create the Go backend (see Full Code below)
4. Run: `go run main.go` on `:8080`, frontend on `:3000`

## Full Code

### Backend: `backend/go.mod`

```
module openui-backend

go 1.21

require (
    github.com/joho/godotenv v1.5.1
)
```

### Backend: `backend/main.go`

```go
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	_ "github.com/joho/godotenv/autoload"
)

var systemPrompt string

func init() {
	data, err := os.ReadFile("system-prompt.txt")
	if err != nil {
		log.Fatal("system-prompt.txt not found: ", err)
	}
	systemPrompt = string(data)
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "http://localhost:3000")
		w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(204)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	Messages []Message `json:"messages"`
}

func chatHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Bad request", 400)
		return
	}

	messages := append([]Message{{Role: "system", Content: systemPrompt}}, req.Messages...)
	body, _ := json.Marshal(map[string]interface{}{
		"model": "gpt-4o", "stream": true, "messages": messages,
	})

	apiReq, _ := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(body))
	apiReq.Header.Set("Content-Type", "application/json")
	apiReq.Header.Set("Authorization", "Bearer "+os.Getenv("OPENAI_API_KEY"))

	resp, err := http.DefaultClient.Do(apiReq)
	if err != nil {
		http.Error(w, "OpenAI request failed", 502)
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", 500)
		return
	}

	io.Copy(w, resp.Body)
	flusher.Flush()
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/chat", chatHandler)

	fmt.Println("Go backend listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", corsMiddleware(mux)))
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
      apiUrl="http://localhost:8080/api/chat"
    />
  );
}
```

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/system-prompt.txt
```

## Validation Checklist

- [ ] `system-prompt.txt` exists in the Go backend directory
- [ ] `OPENAI_API_KEY` is set in environment or `.env`
- [ ] CORS middleware allows the frontend origin
- [ ] Response streams SSE directly from OpenAI API (passthrough)
- [ ] Frontend `apiUrl` points to `http://localhost:8080/api/chat`
- [ ] Frontend uses `openAIReadableStreamAdapter` and `openAIMessageFormat`
- [ ] CSS imports in root layout

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Origin mismatch | Update `Access-Control-Allow-Origin` in middleware |
| `system-prompt.txt not found` | File missing from backend dir | Run CLI generate command |
| 502 Bad Gateway | OpenAI API unreachable or key invalid | Check `OPENAI_API_KEY` and network |
| Stream not flushing | Missing `http.Flusher` | Ensure handler calls `flusher.Flush()` |
| Empty response | Body not forwarded | Verify `io.Copy` pipes OpenAI response to client |
