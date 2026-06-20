---
name: openui-forge-elixir
description: OpenUI generative UI with Elixir Phoenix backend. Chunked SSE streaming via Plug.Conn and Req.
version: 1.2.0
author: OthmanAdi
---

# OpenUI Forge — Elixir

Build generative UI apps with a React frontend + Elixir Phoenix backend. Streams OpenAI API responses directly to the browser as SSE using `Plug.Conn.send_chunked/2` and the Req HTTP client's streaming `:into` collector.

## Activation Triggers

- "openui elixir", "openui phoenix", "openui elixir backend"
- "generative ui elixir", "elixir streaming ui backend", "phoenix sse openui"

## Prerequisites

- Node.js >= 22 (24 LTS recommended) + React >= 18.3.1 (19+ recommended) (frontend)
- Elixir >= 1.15 with Erlang/OTP 25+ (Phoenix 1.8 baseline)
- Phoenix ~> 1.8 (current stable; 1.8.8 as of June 2026)
- `OPENAI_API_KEY` environment variable set

## Quick Start

1. Create the React frontend and install OpenUI deps:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
```
2. Generate the system prompt into the Phoenix app's `priv/`:
```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/priv/system-prompt.txt
```
3. Create the Phoenix backend (see Full Code below)
4. Run: `mix deps.get && mix phx.server` on `:4000`, frontend on `:3000`

## Full Code

### Backend: `backend/mix.exs` (deps)

```elixir
defp deps do
  [
    {:phoenix, "~> 1.8.0"},
    {:bandit, "~> 1.0"},      # HTTP server (Phoenix 1.8 default)
    {:jason, "~> 1.4"},       # JSON encode/decode
    {:req, "~> 0.6"},         # HTTP client with streaming :into (v0.6.2+)
    {:cors_plug, "~> 3.0"}    # explicit-origin CORS
  ]
end
```

### Backend: load the system prompt once at startup

Read `priv/system-prompt.txt` a single time and cache it in `:persistent_term`. Call `OpenuiBackend.load_system_prompt!/0` from your `Application.start/2` callback **before** the endpoint child starts.

```elixir
# lib/openui_backend.ex
defmodule OpenuiBackend do
  @key {__MODULE__, :system_prompt}

  def load_system_prompt! do
    path = Application.app_dir(:openui_backend, "priv/system-prompt.txt")

    case File.read(path) do
      {:ok, contents} ->
        :persistent_term.put(@key, contents)
        :ok

      {:error, reason} ->
        raise "failed to read #{path}: #{:file.format_error(reason)}"
    end
  end

  def system_prompt, do: :persistent_term.get(@key)
end
```

```elixir
# lib/openui_backend/application.ex — inside start/2, before the children list
def start(_type, _args) do
  OpenuiBackend.load_system_prompt!()

  children = [
    OpenuiBackendWeb.Endpoint
    # ...
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: OpenuiBackend.Supervisor)
end
```

### Backend: `lib/openui_backend_web/controllers/chat_controller.ex`

```elixir
defmodule OpenuiBackendWeb.ChatController do
  use OpenuiBackendWeb, :controller

  require Logger

  @openai_chat_path "/chat/completions"

  # POST /api/chat
  def create(conn, %{"messages" => messages}) when is_list(messages) do
    case System.get_env("OPENAI_API_KEY") do
      key when is_binary(key) and key != "" -> stream_chat(conn, messages, key)
      _ -> send_error(conn, 500, "OPENAI_API_KEY not set")
    end
  end

  def create(conn, _params), do: send_error(conn, 400, "messages must be a non-empty array")

  defp stream_chat(conn, messages, api_key) do
    base_url = System.get_env("OPENAI_BASE_URL") || "https://api.openai.com/v1"
    model = System.get_env("OPENAI_MODEL") || "gpt-5.5"

    # Prepend the server-side system prompt; never trust the client to send it.
    system_message = %{"role" => "system", "content" => OpenuiBackend.system_prompt()}
    payload = %{"model" => model, "stream" => true, "messages" => [system_message | messages]}

    # Open the SSE response before the upstream call so the first byte flushes
    # to the browser as soon as OpenAI starts emitting tokens.
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    result =
      Req.post(
        url: base_url <> @openai_chat_path,
        json: payload,
        auth: {:bearer, api_key},
        receive_timeout: :infinity,
        # `:into` turns the response body into a stream: Req hands each upstream
        # SSE chunk to this 2-arity collector as {:data, data}. We forward it
        # verbatim with chunk/2 and halt the moment the client disconnects,
        # mirroring the Enum.reduce_while halt-on-{:error,_} pattern. Plug.Conn
        # is immutable, so we thread the latest conn through resp.private.
        into: fn {:data, data}, {req, resp} ->
          out_conn = resp.private[:openui_conn] || conn

          case Plug.Conn.chunk(out_conn, data) do
            {:ok, out_conn} ->
              {:cont, {req, Req.Response.put_private(resp, :openui_conn, out_conn)}}

            {:error, reason} ->
              Logger.debug("client disconnected mid-stream: #{inspect(reason)}")
              {:halt, {req, resp}}
          end
        end
      )

    case result do
      {:ok, %Req.Response{status: status} = resp} when status in 200..299 ->
        # OpenAI already sends a terminating `data: [DONE]` line (forwarded verbatim).
        resp.private[:openui_conn] || conn

      {:ok, %Req.Response{status: status}} ->
        Logger.error("OpenAI returned HTTP #{status}")
        push_error_frame(conn, "OpenAI returned HTTP #{status}")

      {:error, exception} ->
        Logger.error("OpenAI request failed: #{Exception.message(exception)}")
        push_error_frame(conn, "OpenAI request unreachable")
    end
  end

  defp push_error_frame(conn, message) do
    payload = Jason.encode!(%{error: message})
    _ = Plug.Conn.chunk(conn, "data: #{payload}\n\ndata: [DONE]\n\n")
    conn
  end

  defp send_error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
  end
end
```

### Backend: `lib/openui_backend_web/router.ex` (scope)

```elixir
defmodule OpenuiBackendWeb.Router do
  use OpenuiBackendWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", OpenuiBackendWeb do
    pipe_through :api

    post "/chat", ChatController, :create
  end
end
```

CORS lives in the endpoint, before the router, locked to the frontend origin (never a wildcard for the credentialed case):

```elixir
# lib/openui_backend_web/endpoint.ex — before `plug OpenuiBackendWeb.Router`
plug CORSPlug,
  origin: [System.get_env("FRONTEND_ORIGIN") || "http://localhost:3000"],
  methods: ["POST", "OPTIONS"]
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
      apiUrl="http://localhost:4000/api/chat"
    />
  );
}
```

> The Phoenix backend proxies OpenAI's native SSE stream verbatim: Req's `:into` collector receives each upstream `{:data, data}` chunk and re-emits it with `Plug.Conn.chunk/2` (incremental flush, no buffering), so the browser sees `data: {chunk}\n\n` lines and the terminating `data: [DONE]`. Pair it with `openAIAdapter()` on the frontend. `openAIReadableStreamAdapter()` is for NDJSON (no `data:` prefix) and will silently produce no output here.
>
> `req_llm` (built on Req + Finch) is a higher-level alternative that handles provider SSE adaptation if you later want typed multi-provider support. This skill keeps plain `Req` as the dependency-light default.

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/priv/system-prompt.txt
```

## Validation Checklist

- [ ] `priv/system-prompt.txt` exists in the Phoenix backend
- [ ] `OpenuiBackend.load_system_prompt!/0` is called in `Application.start/2` before the endpoint
- [ ] `OPENAI_API_KEY` is set in environment (honor `OPENAI_BASE_URL` for OpenAI-compatible providers)
- [ ] CORS plug allows the frontend origin explicitly (not `*`)
- [ ] Response streams SSE directly from OpenAI API (Req `:into` passthrough, `chunk/2` per chunk)
- [ ] Frontend `apiUrl` points to `http://localhost:4000/api/chat`
- [ ] Frontend uses `streamProtocol={openAIAdapter()}` and `openAIMessageFormat`
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] CSS import in root layout (`@openuidev/react-ui/components.css`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Origin mismatch | Set `FRONTEND_ORIGIN` and confirm `CORSPlug` runs before the router |
| `:persistent_term` key not found | Prompt not loaded at boot | Call `OpenuiBackend.load_system_prompt!/0` in `Application.start/2` |
| `(File.Error) could not read priv/system-prompt.txt` | File missing | Run the CLI generate command into `priv/` |
| 500 `OPENAI_API_KEY not set` | Env var missing | Export `OPENAI_API_KEY` before `mix phx.server` |
| Empty response | Wrong frontend adapter | Backend emits SSE; use `openAIAdapter()`, not `openAIReadableStreamAdapter()` |
| Stream stalls / cut at ~60s | Cowboy idle timeout | On Bandit (default) no cap; on Cowboy set `protocol_options: [idle_timeout: :infinity]` |
| `function send_chunked/2 undefined` | `Plug.Conn` not imported | Use `use OpenuiBackendWeb, :controller` (imports `Plug.Conn`) or call `Plug.Conn.send_chunked/2` |
