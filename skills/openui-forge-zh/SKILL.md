---
name: openui-forge-zh
description: 使用 OpenUI 构建生成式 UI 应用 — 支持任意 LLM 提供商、任意后端语言。脚手架、集成、验证。
version: 1.0.0
author: OthmanAdi
---

# OpenUI Forge

使用 OpenUI 构建生产级生成式 UI 应用。任意大模型，任意后端，一个技能搞定。

OpenUI 是一个流式优先的生成式 UI 框架。大模型输出紧凑的 DSL（OpenUI Lang）而非 JSON 或 HTML，相比传统方案 Token 消耗减少 67%，支持 Token 到达即渐进渲染，并能优雅处理模型幻觉生成的组件。React 运行时负责实时解析和渲染交互式组件。

## 激活触发词

当用户消息中出现以下关键词时自动激活：

- "openui"、"open ui"、"生成式UI"、"genui"、"gen ui"
- "AI生成界面"、"用AI构建UI"、"大模型渲染UI"
- "openui lang"、"openui 组件"、"@openuidev"
- "流式UI"、"copilot UI"、"带组件的聊天界面"
- "thesys"、"openui-forge"

## 架构概览

```
组件库              系统提示词           LLM 后端
(Zod + React)  --> (自动生成)      --> (任意提供商)
                                           |
                                           | 流式输出 (OpenUI Lang)
                                           v
实时 UI         <-- 解析器          <-- 流式适配器
(React)             (react-lang)       (按提供商适配)
```

**数据流：** 用 Zod Schema + React 渲染器定义组件 --> 组装为组件库 --> 生成系统提示词 --> 大模型输出 OpenUI Lang --> 适配器 (Streaming Adapter) 统一流格式 --> 解析器渐进渲染 React 组件。

**NPM 包说明：**

| 包名 | 用途 |
|------|------|
| `@openuidev/react-lang` | 核心：defineComponent、createLibrary、Renderer、提示词生成 |
| `@openuidev/react-headless` | 状态管理：ChatProvider、流式适配器、消息格式（基于 Zustand） |
| `@openuidev/react-ui` | UI 层：FullScreen / Copilot / BottomTray 布局、30+ 内置组件、主题定制 |
| `@openuidev/cli` | 命令行工具：项目脚手架、系统提示词生成 |

## 前置要求

- Node.js >= 18
- React >= 19（所有 @openuidev 包的 peer dependency）
- 至少配置一个 LLM 提供商（OpenAI、Anthropic 或其他）
- 非 JS 后端需通过 `npx @openuidev/cli` 预生成系统提示词为 .txt 文件

---

## 命令

### /openui

智能检测。分析当前项目状态，推荐下一步操作。

**工作流程：**

1. 执行 `scripts/detect-stack.sh`（或 `.ps1`）识别项目状态
2. 检测项目中是否存在：含 OpenUI 依赖的 package.json、createLibrary 调用、system-prompt.txt、聊天路由/端点
3. 输出状态表：

```
OpenUI 状态
-------------------------------------------
依赖包         [已安装 / 缺失]
组件库         [找到于 path / 未找到]
系统提示词     [已生成 / 未找到]
后端路由       [找到于 path / 未找到]
前端页面       [找到于 path / 未找到]
CSS 导入       [已配置 / 缺失]
-------------------------------------------
建议下一步: /openui:scaffold (或其他合适的命令)
```

### /openui:scaffold

交互式项目脚手架。创建新项目或为现有项目添加 OpenUI 支持。

**决策树：**

```
检测到现有项目?
|
+-- 否 --> npx @openuidev/cli@latest create --name ${PROJECT_NAME}
|          完成。接下来执行 /openui:integrate。
|
+-- 是 --> 使用什么框架?
    |
    +-- Next.js
    |   1. npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod
    |   2. 在根布局中添加 CSS 导入:
    |      import "@openuidev/react-ui/components.css";
    |      import "@openuidev/react-ui/styles/index.css";
    |   3. 创建组件库文件（或使用内置的 openuiLibrary）
    |   4. 执行 /openui:integrate 接入后端
    |
    +-- Vite + React
    |   依赖与 Next.js 相同。在 vite.config.ts 中配置代理指向后端。
    |
    +-- 非 JS 后端 (Python / Go / Rust)
        1. 创建 React 前端（Next.js 或 Vite）并安装 OpenUI 依赖
        2. npx @openuidev/cli generate ./src/lib/library.ts --out system-prompt.txt
        3. 将 system-prompt.txt 复制到后端服务
        4. 使用 templates/handler-{python|go|rust} 中的模板构建后端
        5. 配置前端 apiUrl 指向后端地址
```

### /openui:component

创建带有 Zod Schema 和 React 渲染器的新组件。

**工作流程：**

1. 询问：该组件展示什么内容？需要哪些 props？
2. 阅读 `references/component-patterns.md` 获取匹配的示例
3. 使用 `@openuidev/react-lang` 的 `defineComponent` 创建组件：

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const ${NAME} = defineComponent({
  name: "${NAME}",
  description: "${DESCRIPTION}",
  props: z.object({
    // 在此定义 props — 每个字段都必须调用 .describe()
  }),
  component: ({ props }) => (
    // JSX
  ),
});
```

4. 将组件添加到 createLibrary 调用中
5. 执行 /openui:prompt 重新生成系统提示词

**组件设计规则（直接影响大模型生成质量）：**

- 每个 Zod 属性都必须调用 `.describe()` — 这是大模型理解组件的唯一文档
- Schema 保持扁平 — 嵌套不超过 2 层
- 使用具体类型 — 优先 `z.enum(["sm","md","lg"])` 而非 `z.string()`
- 单个组件库不超过 30 个组件 — 组件越多，提示词 Token 越多，输出质量越差
- 使用 `componentGroups` 对相关组件分组，帮助大模型更好地组织选择
- 组件名称要清晰且唯一 — 大模型仅凭名称 + 描述选择组件
- 使用 `ref` 引用其他 DefinedComponent 实现嵌套组件引用

**完整的生产示例请参考 `references/component-patterns.md`。**

### /openui:integrate

**核心命令。** 接入 LLM 后端。

**第一步 — 检测或询问技术栈：**

你的后端语言和 LLM 提供商是什么？

**第二步 — 按集成矩阵执行：**

```
TypeScript / JavaScript 后端
================================

OpenAI SDK (Chat Completions)
  前端适配器:   openAIReadableStreamAdapter()
  消息格式:     openAIMessageFormat
  模板:         templates/api-route-openai.ts.template
  安装:         npm install openai
  流格式:       NDJSON (response.toReadableStream())

Anthropic SDK (Claude)
  前端适配器:   openAIReadableStreamAdapter()
  消息格式:     openAIMessageFormat
  模板:         templates/api-route-anthropic.ts.template
  安装:         npm install @anthropic-ai/sdk
  备注:         后端将 Anthropic 事件转换为 OpenAI NDJSON 格式

Vercel AI SDK
  前端适配器:   (原生 — 使用 useChat 或 processMessage)
  消息格式:     (原生)
  模板:         templates/api-route-vercel-ai.ts.template
  安装:         npm install ai @ai-sdk/openai
  备注:         使用 streamText + toUIMessageStreamResponse()

LangChain / LangGraph
  前端适配器:   openAIReadableStreamAdapter()
  消息格式:     openAIMessageFormat
  模板:         templates/api-route-langchain.ts.template
  安装:         npm install @langchain/openai @langchain/core
  备注:         将 LangChain 流式块转换为 OpenAI NDJSON 格式


非 JavaScript 后端
=======================
前端统一使用 React + openAIReadableStreamAdapter()。
后端加载 system-prompt.txt（由 CLI 生成）并流式返回大模型响应。

Python (FastAPI)
  模板:   templates/handler-python.py.template
  安装:   pip install fastapi uvicorn openai
  备注:   同时支持 OpenAI 和 Anthropic SDK

Go
  模板:   templates/handler-go.go.template
  备注:   使用 net/http + OpenAI API，SSE 直通转发

Rust (Axum)
  模板:   templates/handler-rust.rs.template
  依赖:   axum, tokio, reqwest, serde_json, async-stream, futures
  备注:   基于 Axum 的异步 SSE 流式传输
```

**第三步 — 生成集成代码：**

1. 安装缺失的依赖
2. 读取对应技术栈的模板文件
3. 适配模板：替换 ${VARIABLES}、调整路径、设置模型名称
4. 创建后端路由/处理器
5. 创建或更新前端页面，配置正确的适配器 (Adapter) 和消息格式 (Format)
6. 使用 `templates/page-fullscreen.tsx.template` 作为前端页面模板

**第四步 — 验证：**

执行 /openui:validate 验证完整集成。

**关键规则：** 所有非 OpenAI 的后端，必须输出 OpenAI 兼容的 NDJSON 格式。前端的 openAIReadableStreamAdapter() 要求每行格式为：

```json
{"id":"...","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"token text"},"finish_reason":null}]}
```

最后一个数据块必须包含 `"finish_reason":"stop"` 且 delta 为空。

**适配器内部机制请参考 `references/adapter-matrix.md`。**
**Python/Go/Rust 完整示例请参考 `references/backend-patterns.md`。**

### /openui:prompt

生成或重新生成组件库的系统提示词。

**方式一 — CLI 生成（推荐，非 JS 后端必须使用此方式）：**

```bash
npx @openuidev/cli generate ./src/lib/library.ts --out src/generated/system-prompt.txt
```

生成 JSON Schema 格式（适用于结构化生成场景）：
```bash
npx @openuidev/cli generate ./src/lib/library.ts --json-schema --out src/generated/schema.json
```

**方式二 — 运行时生成（适用于直接导入组件库的 JS 后端）：**

```typescript
import { myLibrary } from "./lib/library";

const systemPrompt = myLibrary.prompt({
  preamble: "You are a helpful assistant that generates interactive UIs.",
  additionalRules: [
    "Always use Stack as root when combining multiple components.",
    "Prefer existing components over generating raw text.",
  ],
  examples: [
    'root = Stack([title, chart])\ntitle = Header("Sales")\nchart = BarChart(labels, [s1])\nlabels = ["Q1","Q2"]\ns1 = Series("Rev", [100, 200])',
  ],
});
```

**需要重新生成的时机：**

- 添加、删除或修改任何组件之后
- 修改组件描述或 Zod Schema 之后
- 修改提示词选项（preamble、规则、示例）之后

### /openui:validate

完整验证流水线。

**检查项（按顺序执行）：**

| # | 检查项 | 检查方式 | 修复方法 |
|---|--------|----------|----------|
| 1 | 依赖已安装 | `npm ls @openuidev/react-lang` | `npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang` |
| 2 | React >= 19 | `npm ls react` | `npm install react@latest react-dom@latest` |
| 3 | 组件库存在 | 搜索 `createLibrary` 调用 | 执行 /openui:component |
| 4 | 所有属性都有 .describe() | AST 检查或文本搜索 | 为每个 Zod 字段添加 `.describe("...")` |
| 5 | 系统提示词存在 | 查找 `**/system-prompt.txt` | 执行 /openui:prompt |
| 6 | 后端路由存在 | 查找 `**/api/chat/route.ts` 或类似文件 | 执行 /openui:integrate |
| 7 | 前端页面存在 | 查找 FullScreen/Copilot/ChatProvider 引用 | 使用页面模板 |
| 8 | CSS 导入已配置 | 搜索 `@openuidev/react-ui/components.css` | 在根布局中添加 CSS 导入 |
| 9 | 适配器与后端匹配 | 验证适配器类型与后端响应格式是否一致 | 参考集成矩阵 |
| 10 | CORS 头（跨域场景） | 检查后端响应头 | 添加 CORS 中间件 |

**输出：** 每项检查的 PASS/FAIL 清单，失败项附带修复建议。

执行 `scripts/validate.sh`（或 `.ps1`）进行自动化检查。

---

## OpenUI Lang 快速参考

大模型生成的 DSL 语法。每行一条语句，天然适配流式传输。

```
root = Stack([header, content])        # 首行必须赋值 root
header = Header("Dashboard", "2024")   # 位置参数 = Zod Schema 的键序
content = BarChart(labels, [s1])       # 引用其他标识符
labels = ["Jan", "Feb", "Mar"]         # 数组
s1 = Series("Revenue", [10, 20, 30])  # 支持前向引用（自动提升）
```

**支持的类型：** 字符串 `"..."`、数字 `42`、布尔值 `true/false`、null、数组 `[...]`、对象 `{key: value}`、组件调用 `Name(args)`、引用 `identifier`。

**完整语法规范请参考 `references/openui-lang-spec.md`。**

---

## 错误模式

| 错误 | 原因 | 修复方法 |
|------|------|----------|
| React 19 peer dependency | OpenUI 要求 React >= 19 | `npm i react@latest react-dom@latest` |
| Components not rendering | 缺少 CSS 导入 | 在根布局中添加两个 CSS import |
| Stream hangs / no output | 适配器与后端流格式不匹配 | 根据集成矩阵选择正确的适配器 |
| Hallucinated components | 大模型输出了组件库中不存在的组件 | 减少组件数量，完善组件描述。渲染器会优雅降级处理 |
| Props type mismatch | 大模型传入了错误的属性类型 | 为 `.describe()` 添加明确的类型提示 |
| CORS blocked | 后端与前端不同源 | 在后端添加 CORS 响应头 |
| Blank screen | 系统提示词未加载 | 检查文件路径，确认 API 路由正确加载了提示词 |
| Partial renders then stop | NDJSON 格式不正确 | 确保每行是合法 JSON，最后一个块包含 finish_reason:stop |
| Components render as text | 渲染器未连接组件库 | 为 FullScreen/ChatProvider 传入 componentLibrary 属性 |
| Prompt too large | 组件数量过多 | 控制在 30 个以内，移除不再使用的组件 |

---

## 操作原则

1. **先检测，再创建** — 始终先执行 /openui 了解项目现状
2. **从模板出发，再定制** — 严格使用对应技术栈的模板作为起点
3. **组件变更后必须重新生成提示词** — 系统提示词与组件库必须保持同步
4. **一个集成对应一个适配器** — 不要混用适配器
5. **每次修改后都要验证** — 集成有任何改动就执行 /openui:validate
6. **系统提示词仅限服务端** — 绝不暴露给前端客户端
7. **写代码前先读参考文档** — 动手前先查阅对应的 reference 文件获取完整示例
8. **NDJSON 是通用格式** — 拿不准的时候，后端就输出 OpenAI 兼容的 NDJSON
