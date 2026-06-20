---
name: openui-forge-php
description: OpenUI generative UI with a PHP (Laravel 13.x) backend. Forwards OpenAI's SSE stream verbatim via response()->stream().
version: 1.2.0
author: OthmanAdi
---

# OpenUI Forge — PHP

Build generative UI apps with a React frontend + Laravel backend. Streams the OpenAI API's native SSE response straight through `response()->stream()`.

## Activation Triggers

- "openui php", "openui laravel", "openui php backend"
- "generative ui php", "laravel streaming ui backend"

## Prerequisites

- Node.js >= 22 (24 LTS recommended) + React >= 18.3.1 (19+ recommended) (frontend)
- PHP >= 8.3 + Laravel 13.x (backend; Laravel 13 requires PHP 8.3 minimum and supports 8.3 through 8.5)
- Composer; `guzzlehttp/guzzle` ships with Laravel and backs the `Http` facade (no extra dependency to call OpenAI)
- `OPENAI_API_KEY` environment variable set

## Quick Start

1. Create the React frontend and install OpenUI deps:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
```
2. Generate the system prompt:
```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/storage/app/system-prompt.txt
```
3. Create the Laravel backend (see Full Code below). On a fresh app, enable API routes once with `php artisan install:api`.
4. Run: `php artisan serve` on `:8000`, frontend on `:3000`

## Full Code

### Backend: `composer.json` (require block)

```json
{
    "require": {
        "php": "^8.3",
        "laravel/framework": "^13.0"
    }
}
```

> Laravel bundles `guzzlehttp/guzzle`, so the `Http` facade can call OpenAI with no extra package. The OpenAI SSE passthrough below needs nothing beyond the framework.

### Backend: `routes/api.php`

```php
<?php

use App\Http\Controllers\ChatController;
use Illuminate\Support\Facades\Route;

// `php artisan install:api` creates this file and prefixes it with /api,
// so this route is reachable at POST /api/chat.
Route::post('/chat', [ChatController::class, 'chat']);
```

### Backend: `app/Http/Controllers/ChatController.php`

```php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ChatController extends Controller
{
    // Loaded once per worker process, then reused across requests.
    private static ?string $systemPrompt = null;

    private function systemPrompt(): string
    {
        if (self::$systemPrompt === null) {
            $path = storage_path('app/system-prompt.txt');
            if (! is_file($path)) {
                abort(500, 'system-prompt.txt not found at ' . $path);
            }
            self::$systemPrompt = (string) file_get_contents($path);
        }

        return self::$systemPrompt;
    }

    public function chat(Request $request): StreamedResponse
    {
        // Read config(), never env(), in a controller: after `php artisan
        // config:cache` (standard in production) env() returns null outside
        // config files. See the config/services.php block below.
        $apiKey = config('services.openai.key');
        if (! $apiKey) {
            abort(500, 'OPENAI_API_KEY not set');
        }

        $incoming = $request->validate([
            'messages'           => 'required|array|min:1',
            'messages.*.role'    => 'required|string',
            'messages.*.content' => 'required|string',
        ])['messages'];

        // Prepend the system prompt; never trust a client-sent system message.
        $messages = array_merge(
            [['role' => 'system', 'content' => $this->systemPrompt()]],
            array_map(
                fn (array $m) => ['role' => $m['role'], 'content' => $m['content']],
                $incoming,
            ),
        );

        $baseUrl = rtrim(config('services.openai.base_url'), '/');
        $model   = config('services.openai.model');

        // stream => true returns the Guzzle PSR-7 response with its body still
        // on the wire, so we read it chunk-by-chunk instead of buffering the
        // whole completion in memory.
        $upstream = Http::withToken($apiKey)
            ->withOptions(['stream' => true])
            ->acceptJson()
            ->post("{$baseUrl}/chat/completions", [
                'model'    => $model,
                'stream'   => true,
                'messages' => $messages,
            ]);

        if ($upstream->failed()) {
            abort($upstream->status(), 'OpenAI request failed: ' . $upstream->body());
        }

        $body = $upstream->toPsrResponse()->getBody();

        return response()->stream(function () use ($body): void {
            // Forward OpenAI's SSE bytes verbatim. OpenAI already emits
            // `data: {chunk}\n\n` frames plus a final `data: [DONE]`, which is
            // exactly what openAIAdapter() parses, so no re-framing is needed.
            while (! $body->eof()) {
                $chunk = $body->read(8192);
                if ($chunk === '') {
                    usleep(1000); // avoid a busy-wait if the stream momentarily has no data
                    continue;
                }
                echo $chunk;
                if (ob_get_level() > 0) {
                    @ob_flush();
                }
                flush();
            }
        }, 200, [
            'Content-Type'      => 'text/event-stream',
            'Cache-Control'     => 'no-cache',
            'Connection'        => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ]);
    }
}
```

### Backend: `config/services.php` (add an `openai` entry)

Read provider settings via `config()`, not `env()`, in the controller: after `php artisan config:cache` (standard in production) `env()` returns null outside config files. `env()` is only safe inside config files like this one.

```php
<?php

return [
    // ...existing services...
    'openai' => [
        'key'      => env('OPENAI_API_KEY'),
        'base_url' => env('OPENAI_BASE_URL', 'https://api.openai.com/v1'),
        'model'    => env('OPENAI_MODEL', 'gpt-5.5'),
    ],
];
```

### Backend: `config/cors.php` (publish once with `php artisan config:publish cors`)

```php
<?php

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['POST', 'OPTIONS'],
    // Pin the frontend origin, not a wildcard.
    'allowed_origins' => [env('FRONTEND_ORIGIN', 'http://localhost:3000')],
    'allowed_headers' => ['Content-Type', 'Authorization'],
    'exposed_headers' => [],
    'max_age' => 0,
    // Leave false unless you send cookies; with credentials a wildcard is illegal.
    'supports_credentials' => false,
];
```

> Laravel's built-in `HandleCors` middleware reads this config and answers the `OPTIONS` preflight automatically, so the controller never hand-writes `Access-Control-*` headers.

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
      apiUrl="http://localhost:8000/api/chat"
    />
  );
}
```

> The Laravel backend forwards OpenAI's SSE stream verbatim through `response()->stream()`, reading the Guzzle PSR-7 body in chunks and calling `flush()` after each one, so the client sees tokens as they arrive. Pair it with `openAIAdapter()` on the frontend. `openAIReadableStreamAdapter()` is for NDJSON (no `data:` prefix) and will silently produce no output here.
>
> Do **not** reach for Laravel's `response()->eventStream()` here: it wraps each yield as a named SSE event and appends a `</stream>` sentinel, which rewrites the bytes and breaks `openAIAdapter()`. Plain `response()->stream()` keeps OpenAI's `data: {chunk}` frames and the literal `data: [DONE]` intact.
>
> An official-style OpenAI PHP client exists (`openai-php/client`, requires PHP 8.2+) with a `createStreamed()` helper as an alternative to calling the HTTP endpoint directly. This skill keeps the bundled Guzzle-backed `Http` facade as the dependency-free default. A pure `ext-curl` + `CURLOPT_WRITEFUNCTION` variant (return the chunk's byte count from the callback, `echo`+`flush()` inside it) is shown in `templates/handler-php.php.template`.

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/storage/app/system-prompt.txt
```

## Validation Checklist

- [ ] `system-prompt.txt` exists at `storage/app/system-prompt.txt` in the Laravel backend
- [ ] `OPENAI_API_KEY` is set in `.env` (and `OPENAI_BASE_URL` / `OPENAI_MODEL` if overriding)
- [ ] `php artisan install:api` has been run so `POST /api/chat` exists
- [ ] `config/cors.php` `allowed_origins` lists the frontend origin (not `*`)
- [ ] Response streams SSE directly from OpenAI API (passthrough via `response()->stream()`)
- [ ] `X-Accel-Buffering: no` header is set so nginx/FastCGI does not buffer the stream
- [ ] Frontend `apiUrl` points to `http://localhost:8000/api/chat`
- [ ] Frontend uses `streamProtocol={openAIAdapter()}` and `openAIMessageFormat`
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] CSS import in root layout (`@openuidev/react-ui/components.css`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Origin mismatch | Set `allowed_origins` in `config/cors.php` to the frontend origin |
| 404 on `/api/chat` | API routes not installed | Run `php artisan install:api` and confirm `routes/api.php` exists |
| `system-prompt.txt not found` | File missing from `storage/app` | Run the CLI generate command into `storage/app/system-prompt.txt` |
| 500 `OPENAI_API_KEY not set` | Env var missing, or read via `env()` after `config:cache` | Set `OPENAI_API_KEY` in `.env` and read it through `config('services.openai.key')` (cache-safe) |
| Upstream error surfaced via `abort()` | OpenAI key invalid or model wrong | Check `OPENAI_API_KEY`, `OPENAI_MODEL`, `OPENAI_BASE_URL` |
| Response arrives all at once (no streaming) | Output buffered by server | Keep `X-Accel-Buffering: no`; ensure `flush()` runs and no full-page output buffer wraps it |
| Empty response | Wrong adapter | Use `openAIAdapter()` (SSE), not `openAIReadableStreamAdapter()` (NDJSON) |
