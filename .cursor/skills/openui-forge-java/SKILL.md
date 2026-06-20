---
name: openui-forge-java
description: OpenUI generative UI with a Java Spring Boot (WebFlux) backend. Streams the OpenAI API directly via WebClient as SSE.
version: 1.2.0
author: OthmanAdi
---

# OpenUI Forge — Java

Build generative UI apps with a React frontend + Java Spring Boot (WebFlux) backend. The backend forwards OpenAI's SSE stream to the browser via a reactive `WebClient` and a `Flux<String>` controller, pairing with `openAIAdapter()` on the frontend.

## Activation Triggers

- "openui java", "openui spring", "openui spring boot backend"
- "generative ui java", "java streaming ui backend", "webflux openui"

## Prerequisites

- Node.js >= 22 (24 LTS recommended) + React >= 18.3.1 (19+ recommended) (frontend)
- Java 21 LTS recommended (Spring Boot 4.x requires Java 17+; it builds against Java up to 26)
- Maven 3.9+ (or Gradle 8+)
- Spring Boot 4.0.x (current stable line; 4.1.x is the latest). Boot 3.5.x also works but reached end of OSS support on 2026-06-30.
- `OPENAI_API_KEY` environment variable set

## Quick Start

1. Create the React frontend and install OpenUI deps:
```bash
npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
```
2. Generate the system prompt into the backend's resources:
```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/src/main/resources/system-prompt.txt
```
3. Create the Spring Boot backend (see Full Code below)
4. Run: `mvn spring-boot:run` on `:8080`, frontend on `:3000`

## Full Code

### Backend: `backend/pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>4.0.6</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>openui-backend</artifactId>
    <version>0.0.1-SNAPSHOT</version>

    <properties>
        <java.version>21</java.version>
    </properties>

    <dependencies>
        <!-- WebFlux pulls in the reactive web stack, WebClient, and Reactor Netty -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-webflux</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

### Backend: `backend/src/main/resources/application.properties`

```properties
# Server port (override with SERVER_PORT env var). Frontend expects 8080.
server.port=${SERVER_PORT:8080}
```

### Backend: `backend/src/main/java/com/example/openui/Application.java`

```java
package com.example.openui;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.reactive.config.CorsRegistry;
import org.springframework.web.reactive.config.WebFluxConfigurer;
import org.springframework.web.reactive.function.client.WebClient;

import reactor.core.publisher.Flux;

@SpringBootApplication
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    // CORS — lock to the configured frontend origin. Never use "*" here: the
    // endpoint is browser-callable and a wildcard lets any site burn your key.
    @Bean
    public WebFluxConfigurer corsConfigurer(
            @Value("${FRONTEND_ORIGIN:http://localhost:3000}") String frontendOrigin) {
        return new WebFluxConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**")
                        .allowedOrigins(frontendOrigin)
                        .allowedMethods("POST", "OPTIONS")
                        .allowedHeaders("Content-Type")
                        .allowCredentials(true);
            }
        };
    }

    // Shared non-blocking WebClient (Reactor Netty). Honors OPENAI_BASE_URL so
    // OpenAI-compatible providers (Azure, Groq, Together, Ollama, ...) work.
    @Bean
    public WebClient openAiWebClient(
            WebClient.Builder builder,
            @Value("${OPENAI_BASE_URL:https://api.openai.com/v1}") String baseUrl) {
        return builder.baseUrl(baseUrl).build();
    }
}

record ChatMessage(String role, String content) {}

record ChatRequest(List<ChatMessage> messages) {}

@RestController
class ChatController {

    private final WebClient openAiWebClient;
    private final String apiKey;
    private final String model;
    private final String systemPrompt;

    ChatController(
            WebClient openAiWebClient,
            @Value("${OPENAI_API_KEY:}") String apiKey,
            @Value("${OPENAI_MODEL:gpt-5.5}") String model,
            @Value("classpath:system-prompt.txt") Resource systemPromptResource) {
        this.openAiWebClient = openAiWebClient;
        this.apiKey = apiKey;
        this.model = model;
        try {
            // Loaded ONCE at startup from src/main/resources/system-prompt.txt.
            this.systemPrompt = systemPromptResource.getContentAsString(StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException(
                    "Failed to read system-prompt.txt from classpath. Generate it with: "
                    + "npx @openuidev/cli generate ./src/lib/library.ts "
                    + "--out src/main/resources/system-prompt.txt", e);
        }
    }

    // produces=text/event-stream + Flux<String>: Spring's SSE writer wraps each
    // emitted String as "data: <element>\n\n". We emit BARE JSON payloads (upstream
    // "data:" prefix already stripped by the SSE reader) so the wire output is
    // exactly "data: {chunk}\n\n" ... "data: [DONE]\n\n" — what openAIAdapter() expects.
    @PostMapping(value = "/api/chat", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    Flux<String> chat(@RequestBody ChatRequest request) {
        if (apiKey == null || apiKey.isBlank()) {
            return Flux.just("{\"error\":\"OPENAI_API_KEY not set\"}");
        }

        // Prepend the system prompt server-side; never trust a client system message.
        List<ChatMessage> messages = new ArrayList<>();
        messages.add(new ChatMessage("system", systemPrompt));
        if (request.messages() != null) {
            messages.addAll(request.messages());
        }

        Map<String, Object> upstreamBody = Map.of(
                "model", model,
                "stream", true,
                "messages", messages);

        // bodyToFlux(String.class) on a text/event-stream response makes Spring's
        // ServerSentEventHttpMessageReader parse upstream "data:" events and emit
        // each event's bare payload incrementally (buffered across TCP chunks).
        return openAiWebClient.post()
                .uri("/chat/completions")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.TEXT_EVENT_STREAM)
                .bodyValue(upstreamBody)
                .retrieve()
                .bodyToFlux(String.class);
    }
}
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
      apiUrl="http://localhost:8080/api/chat"
    />
  );
}
```

> The Spring Boot backend forwards OpenAI's SSE stream incrementally: `WebClient.bodyToFlux(String.class)` parses upstream `data:` events as they arrive, and the `Flux<String>` controller (`produces=text/event-stream`) re-frames each payload as `data: {chunk}\n\n`, ending with `data: [DONE]\n\n`. Reactor is fully non-blocking, so tokens flush to the client as they stream (no buffering of the whole response). Pair it with `openAIAdapter()` on the frontend. `openAIReadableStreamAdapter()` is for NDJSON (no `data:` prefix) and will silently produce no output here.
>
> Because the controller emits `Flux<String>` with `text/event-stream`, Spring's `ServerSentEventHttpMessageWriter` adds the `data:` prefix for you. Do **not** prepend `data:` to the strings yourself or you will get a doubled `data: data: {...}` frame that the adapter cannot parse.

## System Prompt Generation

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out backend/src/main/resources/system-prompt.txt
```

## Validation Checklist

- [ ] `system-prompt.txt` exists in `backend/src/main/resources/`
- [ ] `OPENAI_API_KEY` is set in the environment
- [ ] `OPENAI_BASE_URL` set if using an OpenAI-compatible provider (default `https://api.openai.com/v1`)
- [ ] CORS allows the frontend origin (`FRONTEND_ORIGIN`, default `http://localhost:3000`), not a wildcard
- [ ] Controller is `produces = MediaType.TEXT_EVENT_STREAM_VALUE` and returns `Flux<String>`
- [ ] Emitted strings are bare JSON (no manual `data:` prefix — Spring adds it)
- [ ] Frontend `apiUrl` points to `http://localhost:8080/api/chat`
- [ ] Frontend uses `streamProtocol={openAIAdapter()}` and `openAIMessageFormat`
- [ ] `componentLibrary={openuiChatLibrary}` prop passed to `FullScreen`
- [ ] CSS import in root layout (`@openuidev/react-ui/components.css`)

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| CORS blocked | Origin mismatch | Set `FRONTEND_ORIGIN` to the frontend URL; check `allowedOrigins` |
| `FileNotFoundException` / `UncheckedIOException` on startup | `system-prompt.txt` missing from `src/main/resources/` | Run the CLI generate command into that path, then rebuild |
| 401 from upstream | `OPENAI_API_KEY` unset or invalid | Export a valid key; verify `OPENAI_BASE_URL` matches the provider |
| `WebClientResponseException` 4xx/5xx | Bad model or provider error | Check `OPENAI_MODEL` and `OPENAI_BASE_URL`; inspect the exception body |
| Doubled `data: data:` frames | Manually prefixed strings with `data:` | Emit bare JSON; the SSE writer adds the prefix |
| Empty render / no output | Frontend used `openAIReadableStreamAdapter()` (NDJSON) | Use `openAIAdapter()` to match the SSE body |
| Response buffers then dumps at once | Returned `Mono`/collected the Flux | Return the `Flux<String>` directly so elements stream as they arrive |
