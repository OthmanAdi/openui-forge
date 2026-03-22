# OpenUI Lang Specification

Complete specification of the OpenUI Lang DSL. This is what LLMs output and the parser in `@openuidev/react-lang` consumes.

---

## Overview

OpenUI Lang is a line-oriented domain-specific language designed for LLM output. Each line contains exactly one statement. The format is intentionally minimal to reduce token usage (67% fewer tokens than equivalent JSON) and to support progressive rendering as tokens stream in.

```
identifier = Expression
```

Every OpenUI Lang program is a flat list of assignments. The parser hoists all identifiers before resolving references, which means forward references work and streaming can begin rendering before all lines have arrived.

---

## Root Statement

The first assignment in every program MUST be `root`. This tells the renderer which component is the top-level entry point.

```
root = Stack([header, content, footer])
```

If `root` is missing, the renderer has nothing to display. The parser will emit a warning and render nothing.

---

## Identifiers

Identifiers appear on the left side of `=` and as bare references on the right side.

**Rules:**
- Alphanumeric characters and underscores only: `[a-zA-Z_][a-zA-Z0-9_]*`
- Case-sensitive: `myCard` and `MyCard` are different identifiers
- Cannot be a reserved keyword: `true`, `false`, `null`
- Convention: use `camelCase` for data identifiers, `PascalCase` is reserved for component names

**Valid identifiers:**
```
header
salesChart
data_row_1
_private
item2
```

**Invalid identifiers:**
```
my-card        (hyphens not allowed)
123start       (cannot start with digit)
my card        (spaces not allowed)
true           (reserved keyword)
```

---

## Expression Types

### Component Calls

```
identifier = ComponentName(arg1, arg2, arg3)
```

Component names MUST start with an uppercase letter (PascalCase). Arguments are positional and map to the component's Zod schema keys in declaration order.

For example, if a component's Zod schema is:
```typescript
z.object({
  title: z.string(),
  value: z.number(),
  trend: z.enum(["up", "down", "flat"]),
})
```

Then the OpenUI Lang call is:
```
card = MetricCard("Revenue", 42000, "up")
```

- First arg maps to `title`
- Second arg maps to `value`
- Third arg maps to `trend`

### Strings

Double-quoted strings with escape support.

```
name = "Hello World"
multiline_content = "Line one\nLine two"
escaped = "She said \"hello\""
path = "C:\\Users\\data"
```

**Supported escapes:**
| Escape | Meaning |
|--------|---------|
| `\n` | Newline |
| `\"` | Literal double quote |
| `\\` | Literal backslash |

Single quotes are NOT supported. The parser will reject `'string'`.

### Numbers

Integers and floating-point numbers. No special notation (no hex, no scientific notation).

```
count = 42
price = 19.99
negative = -7
zero = 0
```

### Booleans

Lowercase only.

```
enabled = true
disabled = false
```

### Null

Lowercase only. Used when a prop should be explicitly empty.

```
subtitle = null
```

### Arrays

Square-bracket delimited, comma-separated. Elements can be any expression type including nested arrays, references, and component calls.

```
labels = ["Q1", "Q2", "Q3", "Q4"]
numbers = [10, 20, 30, 40]
mixed = ["hello", 42, true, null]
nested = [[1, 2], [3, 4]]
refs = [card1, card2, card3]
```

### Objects

Curly-brace delimited, key-value pairs with colon separator. Keys are unquoted identifiers. Values can be any expression type.

```
config = {color: "blue", size: 12, enabled: true}
style = {background: "#f0f0f0", padding: 16}
```

### References

Bare identifiers that refer to other assignments. This is how components compose together.

```
root = Stack([header, body])
header = Header("Dashboard")
body = BarChart(labels, series)
labels = ["Jan", "Feb", "Mar"]
series = [s1, s2]
s1 = Series("Revenue", [100, 200, 300])
s2 = Series("Costs", [80, 150, 220])
```

In this example, `header` and `body` are references inside the `Stack` call. `labels`, `series`, `s1`, and `s2` are also references.

---

## Forward References and Hoisting

The parser hoists all identifier declarations before resolving references. This means you can reference an identifier before it is defined:

```
root = Stack([chart, legend])
chart = BarChart(labels, data)
labels = ["A", "B", "C"]
data = [s1]
s1 = Series("Sales", [10, 20, 30])
legend = Text("Figure 1: Sales by category")
```

This is critical for streaming. The LLM can emit `root = Stack([chart, legend])` as its first line, and the renderer can immediately set up the layout. As subsequent lines arrive, the referenced components materialize progressively.

**Unresolved references** render as placeholders (loading skeletons) until their definition arrives. If a reference never resolves (the LLM never defines it), the placeholder remains and a console warning is emitted.

---

## Comments

Comments are NOT supported. LLMs do not need them, and they would waste tokens. Any line beginning with `#` or `//` will cause a parse error.

---

## Whitespace

- Leading and trailing whitespace on each line is trimmed
- Blank lines are ignored
- Whitespace inside strings is preserved
- Whitespace between arguments in a component call is ignored

These are equivalent:
```
card = MetricCard("Revenue", 42000, "up")
card=MetricCard( "Revenue" , 42000 , "up" )
  card = MetricCard("Revenue", 42000, "up")
```

---

## Multi-line Statements

Multi-line statements are NOT supported. Each statement must fit on a single line. This simplifies streaming parsing: each newline boundary is a complete statement that can be immediately parsed and rendered.

If an LLM outputs a statement split across lines, only the first line is parsed and the remaining lines produce parse errors (which are silently ignored to maintain resilience).

---

## Examples

### Example 1: Sales Dashboard

A dashboard with a header, KPI cards, and a bar chart.

```
root = Stack([title, cards, chart])
title = Header("Q4 Sales Dashboard", "October - December 2024")
cards = Row([revenue, orders, conversion])
revenue = MetricCard("Total Revenue", "$1.2M", "up", "+12.5%")
orders = MetricCard("Orders", "8,432", "up", "+5.2%")
conversion = MetricCard("Conversion", "3.2%", "down", "-0.8%")
chart = BarChart("Monthly Revenue", labels, [s1, s2])
labels = ["Oct", "Nov", "Dec"]
s1 = Series("Online", [380000, 420000, 400000])
s2 = Series("In-Store", [120000, 135000, 145000])
```

### Example 2: User Profile Card

A single component with nested data.

```
root = UserProfile("Jane Smith", "jane@example.com", "Senior Engineer", "https://example.com/avatar.jpg", {github: "janesmith", twitter: "@jane"})
```

### Example 3: Pricing Page

Multiple pricing tiers laid out horizontally.

```
root = Stack([heading, tiers])
heading = Header("Choose Your Plan", "Simple, transparent pricing")
tiers = Row([free, pro, enterprise])
free = PricingTier("Free", "$0", "month", features_free, false)
pro = PricingTier("Pro", "$29", "month", features_pro, true)
enterprise = PricingTier("Enterprise", "$99", "month", features_ent, false)
features_free = ["5 projects", "1GB storage", "Community support"]
features_pro = ["Unlimited projects", "50GB storage", "Priority support", "API access"]
features_ent = ["Unlimited everything", "500GB storage", "24/7 support", "Custom integrations", "SLA"]
```

### Example 4: Data Table with Status Badges

A table showing order status using nested component references.

```
root = Stack([title, table])
title = Header("Recent Orders")
table = DataTable(columns, rows)
columns = ["Order ID", "Customer", "Amount", "Status"]
rows = [row1, row2, row3, row4]
row1 = ["#1001", "Alice Johnson", "$250.00", status_shipped]
row2 = ["#1002", "Bob Williams", "$189.50", status_pending]
row3 = ["#1003", "Carol Davis", "$432.00", status_delivered]
row4 = ["#1004", "Dan Miller", "$67.25", status_cancelled]
status_shipped = StatusBadge("Shipped", "blue")
status_pending = StatusBadge("Pending", "yellow")
status_delivered = StatusBadge("Delivered", "green")
status_cancelled = StatusBadge("Cancelled", "red")
```

### Example 5: FAQ Section

An expandable FAQ with multiple questions.

```
root = Stack([heading, faq])
heading = Header("Frequently Asked Questions")
faq = FAQ(items)
items = [q1, q2, q3, q4]
q1 = {question: "What is OpenUI?", answer: "OpenUI is a streaming-first generative UI framework that lets LLMs render interactive React components."}
q2 = {question: "Which LLM providers are supported?", answer: "Any provider that can output text: OpenAI, Anthropic, Google, Mistral, local models, and more."}
q3 = {question: "Do I need React 19?", answer: "Yes, OpenUI requires React 19 or later as a peer dependency."}
q4 = {question: "Can I use my own components?", answer: "Absolutely. Define components with Zod schemas and React renderers using defineComponent."}
```

### Example 6: Event Timeline

A timeline showing a sequence of events.

```
root = Stack([title, timeline])
title = Header("Project Milestones")
timeline = Timeline(events)
events = [e1, e2, e3, e4, e5]
e1 = {date: "2024-01-15", title: "Project Kickoff", description: "Initial planning and team assembly", status: "completed"}
e2 = {date: "2024-03-01", title: "Alpha Release", description: "First internal testing build", status: "completed"}
e3 = {date: "2024-05-15", title: "Beta Launch", description: "Public beta with select partners", status: "completed"}
e4 = {date: "2024-08-01", title: "GA Release", description: "General availability launch", status: "current"}
e5 = {date: "2024-10-01", title: "V2 Planning", description: "Next major version feature planning", status: "upcoming"}
```

### Example 7: Comparison Table

Side-by-side comparison of options.

```
root = Stack([heading, comparison])
heading = Header("Framework Comparison")
comparison = ComparisonTable(columns, features)
columns = ["Feature", "OpenUI", "Vercel AI SDK", "StreamUI"]
features = [f1, f2, f3, f4, f5]
f1 = ["Token Efficiency", "67% fewer tokens", "JSON overhead", "HTML overhead"]
f2 = ["Streaming", "Progressive render", "Partial JSON", "SSR chunks"]
f3 = ["LLM Agnostic", "Any provider", "Vercel providers", "OpenAI only"]
f4 = ["Backend Language", "Any language", "JavaScript only", "JavaScript only"]
f5 = ["Component DSL", "OpenUI Lang", "Tool calls", "JSX strings"]
```

---

## Parser Behavior

**Resilience:** The parser is designed to be fault-tolerant. If a line cannot be parsed, it is skipped and a console warning is emitted. This is critical because LLMs occasionally produce malformed output.

**Hallucinated components:** If the LLM references a component name not in the library, the renderer displays a graceful fallback (typically a warning card showing the component name and raw props) rather than crashing.

**Streaming parsing:** Each line is parsed independently as it arrives. The parser maintains a growing map of `identifier -> expression` and re-renders the component tree whenever a new identifier resolves a previously-pending reference.

**Type coercion:** The parser performs minimal type coercion guided by the Zod schema. If a Zod field expects a number but the LLM outputs a string like `"42"`, the parser attempts to coerce it. If coercion fails, the prop falls back to its Zod default or undefined.
