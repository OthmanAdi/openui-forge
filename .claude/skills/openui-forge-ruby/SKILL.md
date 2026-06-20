---
name: openui-forge-ruby
description: OpenUI generative UI with a Ruby on Rails backend. SSE streaming via ActionController::Live, forwarding the OpenAI API stream with Net::HTTP.
version: 1.2.0
author: OthmanAdi
---

# OpenUI Forge — Ruby

Build generative UI apps with a React frontend + Ruby on Rails backend. Streams OpenAI API responses directly via `ActionController::Live`, forwarding OpenAI's native SSE with `Net::HTTP`.

## Activation Triggers

- "openui ruby", "openui rails", "openui ruby backend"
- "generative ui ruby", "rails streaming ui backend"

## Prerequisites

- Node.js >= 22 (24 LTS recommended) + React >= 18.3.1 (19+ recommended) (frontend)
- Ruby >= 3.2 + Rails 8.1.x (backend; run on Puma — `ActionController::Live` needs a threaded server, not WEBrick)
- `OPENAI_API_KEY` environment variable set

## Quick Start

1. Create the React frontend and install OpenUI deps:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
```
2. Generate the system prompt into the Rails app:
```bash
npx @openuidev/cli generate ./src/lib/library.ts --out config/system-prompt.txt
```
3. Create the Rails backend (see Full Code below)
4. Run: `bin/rails server -p 3001` on `:3001`, frontend on `:3000`

## Full Code

### Backend: `Gemfile`

```ruby
source "https://rubygems.org"

gem "rails", "~> 8.1"
gem "puma", ">= 6.0"
# Net::HTTP is in the standard library — no extra HTTP-client gem required.
# Optional: load OPENAI_API_KEY etc. from a .env file in development.
gem "dotenv-rails", groups: [:development, :test]
```

### Backend: `app/controllers/chat_controller.rb`

```ruby
require "net/http"
require "json"
require "uri"

class ChatController < ApplicationController
  include ActionController::Live

  skip_forgery_protection
  before_action :set_cors_headers
  before_action :handle_preflight, only: :create

  OPENAI_BASE_URL = ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com/v1").freeze
  OPENAI_MODEL    = ENV.fetch("OPENAI_MODEL", "gpt-5.5").freeze

  # Loaded once at boot.
  SYSTEM_PROMPT = Rails.root.join("config", "system-prompt.txt").read.freeze

  # POST /api/chat  { "messages": [{ "role": "...", "content": "..." }] }
  def create
    api_key = ENV["OPENAI_API_KEY"]
    if api_key.nil? || api_key.empty?
      render(json: { error: "OPENAI_API_KEY not set" }, status: :internal_server_error)
      return
    end

    body = JSON.parse(request.body.read) rescue {}
    incoming = body["messages"]
    unless incoming.is_a?(Array) && !incoming.empty?
      render(json: { error: "messages must be a non-empty array" }, status: :bad_request)
      return
    end

    # Prepend the server-side system prompt; never trust a client-sent one.
    messages = [{ "role" => "system", "content" => SYSTEM_PROMPT }]
    incoming.each do |m|
      next unless m.is_a?(Hash)
      messages << { "role" => m["role"].to_s, "content" => m["content"].to_s }
    end

    # Headers MUST be set before the first write (the response commits on write).
    response.headers["Content-Type"]  = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    # Rails inserts Rack::ETag, which buffers the whole body and breaks
    # streaming. Setting Last-Modified makes Rack::ETag pass the body through.
    response.headers["Last-Modified"] = Time.now.httpdate
    # Defeat proxy buffering (nginx) so chunks reach the browser immediately.
    response.headers["X-Accel-Buffering"] = "no"

    uri = URI.parse("#{OPENAI_BASE_URL}/chat/completions")
    payload = JSON.generate(
      model: OPENAI_MODEL,
      stream: true,
      messages: messages,
    )

    # read_timeout: nil disables the default 60s per-read timeout; a streaming
    # completion can pause longer than 60s between chunks and would otherwise
    # raise Net::ReadTimeout and cut the response off mid-stream.
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: nil) do |http|
      upstream = Net::HTTP::Post.new(uri)
      upstream["Content-Type"]  = "application/json"
      upstream["Authorization"] = "Bearer #{api_key}"
      upstream["Accept"]        = "text/event-stream"
      upstream.body = payload

      http.request(upstream) do |res|
        unless res.code.to_i == 200
          err = +""
          res.read_body { |c| err << c }
          response.stream.write("data: #{JSON.generate(error: "OpenAI returned #{res.code}: #{err}")}\n\n")
          response.stream.write("data: [DONE]\n\n")
          next
        end

        # Forward OpenAI's native SSE bytes verbatim. The upstream already emits
        # `data: {chunk}\n\n` frames terminated by `data: [DONE]`, so we just
        # write each chunk through and flush — no buffering, no reframing. This
        # avoids splitting a frame that straddles a TCP read boundary, because
        # the browser's adapter reassembles SSE frames itself.
        res.read_body do |chunk|
          response.stream.write(chunk)
        end
      end
    end
  rescue IOError, Errno::EPIPE
    # Client disconnected mid-stream — nothing more to send.
  rescue => e
    Rails.logger.error("[chat] stream error: #{e.class}: #{e.message}")
    begin
      response.stream.write("data: #{JSON.generate(error: e.message)}\n\n")
      response.stream.write("data: [DONE]\n\n")
    rescue IOError, Errno::EPIPE
      # client already gone
    end
  ensure
    # ALWAYS close, or the socket leaks for the lifetime of the worker.
    response.stream.close
  end

  private

  # Lock CORS to the single configured frontend origin (NOT "*"): the request
  # is credentialed-capable and a wildcard would let any site spend your key.
  def set_cors_headers
    response.headers["Access-Control-Allow-Origin"]  = ENV.fetch("FRONTEND_ORIGIN", "http://localhost:3000")
    response.headers["Vary"]                         = "Origin"
    response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
  end

  def handle_preflight
    head(:no_content) if request.method == "OPTIONS"
  end
end
```

### Backend: `config/routes.rb`

```ruby
Rails.application.routes.draw do
  post  "/api/chat", to: "chat#create"
  match "/api/chat", to: "chat#create", via: :options  # CORS preflight
end
```

### Frontend: `app/chat/page.tsx`

```tsx
"use client";
import { FullScreen } from "@openuidev/react-ui";
import { openuiChatLibrary } from "@openuidev/react-ui/genui-lib";
import {
  openAIAdapter,
  openAIMessageFormat,
} from "@openuidev/react-headless";

export default function ChatPage() {
  return (
    <FullScreen
      componentLibrary={openuiChatLibrary}
      streamProtocol={openAIAdapter()}
      messageFormat={openAIMessageFormat}
      apiUrl="http://localhost:3001/api/chat"
    />
  );
}
```

> The Rails backend forwards OpenAI's SSE stream verbatim through `ActionController::Live` (`response.stream.write(chunk)` per `Net::HTTP` `read_body` chunk), so the client sees tokens as they arrive. Pair it with `openAIAdapter()` on the frontend. `openAIReadableStreamAdapter()` is for NDJSON (no `data:` prefix) and will silently produce no output here.
>
> `Net::HTTP` (standard library) is the dependency-free default here. The `ruby-openai` / `openai` gems are alternatives if you want a typed client, but forwarding the raw SSE bytes needs no gem.

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out config/system-prompt.txt
```

## Validation Checklist

- [ ] `config/system-prompt.txt` exists in the Rails app
- [ ] `OPENAI_API_KEY` is set in environment or `.env`
- [ ] Controller `include ActionController::Live` and `skip_forgery_protection`
- [ ] CORS headers allow the frontend origin (not `*`)
- [ ] Response streams SSE directly from OpenAI API (verbatim passthrough)
- [ ] `response.stream.close` runs in an `ensure` block
- [ ] `Last-Modified` (or removed `Rack::ETag`) so the response is not buffered
- [ ] Running on Puma, not WEBrick
- [ ] Frontend `apiUrl` points to `http://localhost:3001/api/chat`
- [ ] Frontend uses `streamProtocol={openAIAdapter()}` and `openAIMessageFormat`
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] CSS import in root layout (`@openuidev/react-ui/components.css`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Origin mismatch | Set `FRONTEND_ORIGIN` to match the frontend |
| `system-prompt.txt` missing (`Errno::ENOENT` at boot) | File not generated | Run the CLI generate command into `config/` |
| Response arrives all at once, not streamed | `Rack::ETag` buffering | Keep the `Last-Modified` header (or remove `Rack::ETag`) |
| Stream hangs / never flushes | Running on WEBrick | Run on Puma (threaded server) |
| `ActionController::Live::ClientDisconnected` / `Errno::EPIPE` | Client closed the tab mid-stream | Rescue it; the `ensure` still closes the stream |
| Socket stays open after request | `response.stream.close` skipped | Close in an `ensure` block (as shown) |
| 422 Unprocessable Entity on POST | CSRF check | `skip_forgery_protection` in the controller |
| Empty response | Body not forwarded | Verify the `read_body do |chunk|` loop writes each chunk |
