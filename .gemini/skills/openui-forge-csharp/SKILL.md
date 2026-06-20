---
name: openui-forge-csharp
description: OpenUI generative UI with C# ASP.NET Core Minimal API backend. Direct OpenAI API SSE streaming via HttpClient on .NET 10.
version: 1.2.0
author: OthmanAdi
---

# OpenUI Forge — C#

Build generative UI apps with a React frontend + C# backend. Streams OpenAI API responses directly via an ASP.NET Core Minimal API (.NET 10 LTS) using `HttpClient`.

## Activation Triggers

- "openui csharp", "openui c#", "openui dotnet", "openui aspnet"
- "generative ui csharp", "c# streaming ui backend", "asp.net core openui"

## Prerequisites

- Node.js >= 22 (24 LTS recommended) + React >= 18.3.1 (19+ recommended) (frontend)
- .NET SDK 10.0 (backend; .NET 10 is the current LTS, supported until Nov 2028. .NET 8 LTS also works but reaches end of support Nov 2026.)
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
3. Create the C# backend (see Full Code below)
4. Run: `dotnet run` on `:5000`, frontend on `:3000`

## Full Code

### Backend: `backend/openui-backend.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
```

> No NuGet packages required. ASP.NET Core, `HttpClient`/`IHttpClientFactory`, and `System.Text.Json` all ship in the .NET 10 shared framework referenced by `Microsoft.NET.Sdk.Web`.

### Backend: `backend/Program.cs`

```csharp
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// Pooled, correctly-disposed HttpClient instances. Infinite timeout because
// this is a long-lived streaming proxy; client disconnects cancel the request.
builder.Services.AddHttpClient("openai", client =>
{
    client.Timeout = Timeout.InfiniteTimeSpan;
});

// CORS: lock to the configured frontend origin. Do NOT use AllowAnyOrigin —
// a wildcard would let any site call this backend and burn your API key.
var frontendOrigin =
    Environment.GetEnvironmentVariable("FRONTEND_ORIGIN") ?? "http://localhost:3000";

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.WithOrigins(frontendOrigin)
              .WithMethods("POST", "OPTIONS")
              .AllowAnyHeader());
});

var app = builder.Build();

app.UseCors();

// Load the generated system prompt ONCE at startup; fail fast if missing.
var promptPath = Path.Combine(Directory.GetCurrentDirectory(), "system-prompt.txt");
if (!File.Exists(promptPath))
{
    throw new FileNotFoundException(
        "system-prompt.txt not found. Generate it with: " +
        "npx @openuidev/cli generate ./src/lib/library.ts --out system-prompt.txt",
        promptPath);
}
var systemPrompt = await File.ReadAllTextAsync(promptPath);

var apiKey = Environment.GetEnvironmentVariable("OPENAI_API_KEY");
var baseUrl = (Environment.GetEnvironmentVariable("OPENAI_BASE_URL") ?? "https://api.openai.com/v1")
    .TrimEnd('/');
var model = Environment.GetEnvironmentVariable("OPENAI_MODEL") ?? "gpt-5.5";

app.MapPost("/api/chat", async (ChatRequest req, IHttpClientFactory httpClientFactory, HttpContext ctx) =>
{
    if (string.IsNullOrEmpty(apiKey))
        return Results.Json(new { error = "OPENAI_API_KEY not set" }, statusCode: 500);
    if (req.Messages is null || req.Messages.Length == 0)
        return Results.Json(new { error = "messages must be a non-empty array" }, statusCode: 400);

    // Prepend the server-side system prompt; never trust the client to supply it.
    var messages = new List<ChatMessage> { new("system", systemPrompt) };
    messages.AddRange(req.Messages);

    var payload = JsonSerializer.Serialize(new OpenAiRequest(model, true, messages));

    using var upstreamRequest = new HttpRequestMessage(
        HttpMethod.Post, $"{baseUrl}/chat/completions")
    {
        Content = new StringContent(payload, Encoding.UTF8, "application/json"),
    };
    upstreamRequest.Headers.Add("Authorization", $"Bearer {apiKey}");

    var client = httpClientFactory.CreateClient("openai");

    // ResponseHeadersRead returns as soon as headers arrive, so we read the
    // body incrementally off the socket instead of buffering it into memory.
    var upstream = await client.SendAsync(
        upstreamRequest, HttpCompletionOption.ResponseHeadersRead, ctx.RequestAborted);

    if (!upstream.IsSuccessStatusCode)
    {
        var errorBody = await upstream.Content.ReadAsStringAsync(ctx.RequestAborted);
        upstream.Dispose();
        return Results.Json(
            new { error = $"OpenAI returned {(int)upstream.StatusCode}: {errorBody}" },
            statusCode: (int)upstream.StatusCode);
    }

    return Results.Extensions.SseProxy(upstream);
});

app.Run();

// SSE passthrough: forward OpenAI's native `data: {chunk}\n\n` lines verbatim,
// flushing after each so tokens appear as they arrive. Pair with openAIAdapter().
//
// Idiomatic .NET 10 alternative: if you parse each chunk into a typed payload,
// return TypedResults.ServerSentEvents(IAsyncEnumerable<SseItem<T>>) from
// System.Net.ServerSentEvents — the framework writes the SSE framing for you.
// We keep the raw passthrough because the upstream is ALREADY valid SSE.
static class ResultExtensions
{
    public static IResult SseProxy(this IResultExtensions _, HttpResponseMessage upstream)
        => new SseProxyResult(upstream);
}

sealed class SseProxyResult(HttpResponseMessage upstream) : IResult
{
    public async Task ExecuteAsync(HttpContext httpContext)
    {
        var response = httpContext.Response;
        response.StatusCode = 200;
        response.ContentType = "text/event-stream";
        response.Headers.CacheControl = "no-cache";
        response.Headers.Connection = "keep-alive";
        response.Headers["X-Accel-Buffering"] = "no"; // defeat proxy buffering

        try
        {
            await using var upstreamStream =
                await upstream.Content.ReadAsStreamAsync(httpContext.RequestAborted);
            using var reader = new StreamReader(upstreamStream, Encoding.UTF8);

            while (await reader.ReadLineAsync(httpContext.RequestAborted) is { } line)
            {
                if (line.Length == 0) continue; // re-emit our own framing below

                await response.WriteAsync(line + "\n", httpContext.RequestAborted);
                if (line.StartsWith("data:", StringComparison.Ordinal))
                    await response.WriteAsync("\n", httpContext.RequestAborted);
                await response.Body.FlushAsync(httpContext.RequestAborted);

                if (line == "data: [DONE]") break;
            }
        }
        catch (OperationCanceledException)
        {
            // Client aborted — nothing to do.
        }
        finally
        {
            upstream.Dispose();
        }
    }
}

// JsonPropertyName pins wire names to lowercase: incoming binding is
// case-insensitive, but Serialize defaults to PascalCase and OpenAI needs
// lowercase role/content/model.
record ChatMessage(
    [property: JsonPropertyName("role")] string Role,
    [property: JsonPropertyName("content")] string Content);

record ChatRequest(
    [property: JsonPropertyName("messages")] ChatMessage[] Messages);

record OpenAiRequest(
    [property: JsonPropertyName("model")] string Model,
    [property: JsonPropertyName("stream")] bool Stream,
    [property: JsonPropertyName("messages")] List<ChatMessage> Messages);
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
      apiUrl="http://localhost:5000/api/chat"
    />
  );
}
```

> The C# backend forwards OpenAI's SSE stream line-by-line with a `StreamReader` loop, calling `Response.Body.FlushAsync()` after each line (no `CopyToAsync` buffering), so the client sees tokens as they arrive. Pair it with `openAIAdapter()` on the frontend. `openAIReadableStreamAdapter()` is for NDJSON (no `data:` prefix) and will silently produce no output here.
>
> `HttpCompletionOption.ResponseHeadersRead` is the key to incremental streaming: it returns control once the upstream headers arrive instead of buffering the whole response body into memory first.
>
> An official OpenAI .NET SDK exists (`OpenAI` on NuGet) as an alternative to hand-rolling the HTTP call. This skill keeps raw `HttpClient` as the dependency-free default (everything used here ships in the .NET 10 shared framework). .NET 10 also added a native typed SSE result, `TypedResults.ServerSentEvents` (from `System.Net.ServerSentEvents`), which writes the `data:` framing for you when you yield strongly-typed `SseItem<T>` values — use it if you want to parse and reshape chunks rather than pass them through.

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/system-prompt.txt
```

## Validation Checklist

- [ ] `system-prompt.txt` exists in the C# backend directory (next to the `.csproj`)
- [ ] `OPENAI_API_KEY` is set in environment (`.env` is not auto-loaded; export it or use `dotnet user-secrets`)
- [ ] `OPENAI_BASE_URL` honored for OpenAI-compatible providers (defaults to `https://api.openai.com/v1`)
- [ ] CORS policy allows the frontend origin via `WithOrigins(FRONTEND_ORIGIN)` (not `AllowAnyOrigin`)
- [ ] Response streams SSE directly from OpenAI API (passthrough), `Content-Type: text/event-stream`
- [ ] `HttpCompletionOption.ResponseHeadersRead` used so the body is not buffered
- [ ] `Response.Body.FlushAsync()` called after each line
- [ ] Frontend `apiUrl` points to `http://localhost:5000/api/chat`
- [ ] Frontend uses `streamProtocol={openAIAdapter()}` and `openAIMessageFormat`
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] CSS import in root layout (`@openuidev/react-ui/components.css`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Origin mismatch | Set `FRONTEND_ORIGIN` to match, ensure `app.UseCors()` runs before the endpoint |
| `FileNotFoundException: system-prompt.txt` | File missing from backend dir | Run the CLI generate command into the project directory |
| 500 `OPENAI_API_KEY not set` | Env var missing | Export `OPENAI_API_KEY` (or set it in `launchSettings.json` for local dev) |
| Upstream status forwarded (e.g. 401/429) | Key invalid or rate limited | Check `OPENAI_API_KEY`, model name, and provider quota |
| Empty response / components show as raw text | Frontend adapter mismatch | Backend emits SSE — use `openAIAdapter()`, not `openAIReadableStreamAdapter()` |
| Stream arrives all at once at the end | Buffering somewhere | Confirm `ResponseHeadersRead` + per-line `FlushAsync()`; keep `X-Accel-Buffering: no` |
| `role`/`content` rejected by API | PascalCase JSON | Keep the `[JsonPropertyName(...)]` attributes on the DTO records |
