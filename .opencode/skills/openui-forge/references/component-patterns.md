# Component Patterns

Production-ready component examples with Zod schemas and React renderers. Use these as templates when building components with `/openui:component`.

All imports come from `@openuidev/react-lang` and `zod`.

---

## 1. DataTable

Tabular data display with headers and rows.

**When to use:** The LLM should choose DataTable whenever the user asks for structured data display, lists of records, spreadsheet-like views, or any request involving rows and columns.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const DataTable = defineComponent({
  name: "DataTable",
  description:
    "Renders a data table with column headers and rows. Use for any structured, tabular data.",
  props: z.object({
    columns: z
      .array(z.string())
      .describe("Column header labels in display order"),
    rows: z
      .array(z.array(z.any()))
      .describe(
        "Array of rows. Each row is an array of cell values matching column order. Cells can be strings, numbers, or component references."
      ),
  }),
  component: ({ props }) => (
    <div style={{ overflowX: "auto" }}>
      <table
        style={{
          width: "100%",
          borderCollapse: "collapse",
          fontSize: "0.875rem",
        }}
      >
        <thead>
          <tr>
            {props.columns.map((col, i) => (
              <th
                key={i}
                style={{
                  textAlign: "left",
                  padding: "0.75rem 1rem",
                  borderBottom: "2px solid #e2e8f0",
                  fontWeight: 600,
                  color: "#475569",
                }}
              >
                {col}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {props.rows.map((row, ri) => (
            <tr key={ri}>
              {row.map((cell, ci) => (
                <td
                  key={ci}
                  style={{
                    padding: "0.75rem 1rem",
                    borderBottom: "1px solid #e2e8f0",
                  }}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = DataTable(columns, rows)
columns = ["Name", "Role", "Department"]
rows = [["Alice", "Engineer", "Platform"], ["Bob", "Designer", "Product"]]
```

---

## 2. BarChart

Bar chart visualization with labeled categories and multiple series.

**When to use:** The LLM should choose BarChart for comparing quantities across categories, showing trends over time periods, revenue breakdowns, survey results, or any data that benefits from visual bar comparison.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

const Series = z.object({
  label: z.string().describe("Name of this data series for the legend"),
  values: z
    .array(z.number())
    .describe("Numeric values, one per category label"),
});

export const BarChart = defineComponent({
  name: "BarChart",
  description:
    "Renders a bar chart with category labels and one or more data series. Use for visual comparison of quantities across categories.",
  props: z.object({
    title: z.string().describe("Chart title displayed above the chart"),
    labels: z
      .array(z.string())
      .describe("Category labels for the x-axis"),
    series: z
      .array(Series)
      .describe("One or more data series to plot as bar groups"),
  }),
  component: ({ props }) => {
    const maxVal = Math.max(
      ...props.series.flatMap((s) => s.values)
    );
    const colors = ["#3b82f6", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6"];
    return (
      <div style={{ padding: "1rem" }}>
        <h3 style={{ margin: "0 0 1rem", fontSize: "1.125rem", fontWeight: 600 }}>
          {props.title}
        </h3>
        <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
          {props.labels.map((label, li) => (
            <div key={li}>
              <div style={{ fontSize: "0.75rem", color: "#64748b", marginBottom: "0.25rem" }}>
                {label}
              </div>
              {props.series.map((s, si) => (
                <div
                  key={si}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "0.5rem",
                    marginBottom: "0.125rem",
                  }}
                >
                  <div
                    style={{
                      height: "1.25rem",
                      width: `${(s.values[li] / maxVal) * 100}%`,
                      backgroundColor: colors[si % colors.length],
                      borderRadius: "0.25rem",
                      minWidth: "2rem",
                    }}
                  />
                  <span style={{ fontSize: "0.75rem", color: "#475569" }}>
                    {s.label}: {s.values[li]}
                  </span>
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
    );
  },
});
```

**Example OpenUI Lang:**
```
root = BarChart("Quarterly Revenue", labels, [s1, s2])
labels = ["Q1", "Q2", "Q3", "Q4"]
s1 = {label: "Online", values: [120, 150, 180, 200]}
s2 = {label: "Retail", values: [80, 90, 110, 130]}
```

---

## 3. MetricCard

KPI/metric display card showing a value with trend indicator.

**When to use:** The LLM should choose MetricCard for key performance indicators, summary statistics, dashboard top-line numbers, or any single-value metric the user wants to highlight.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const MetricCard = defineComponent({
  name: "MetricCard",
  description:
    "Displays a single KPI metric with a label, value, trend direction, and change percentage. Use for dashboard summary cards.",
  props: z.object({
    label: z.string().describe("Short metric name, e.g. 'Revenue' or 'Active Users'"),
    value: z.string().describe("Formatted display value, e.g. '$1.2M' or '8,432'"),
    trend: z
      .enum(["up", "down", "flat"])
      .describe("Trend direction arrow: up (green), down (red), flat (gray)"),
    change: z
      .string()
      .optional()
      .describe("Percentage change text, e.g. '+12.5%' or '-3.1%'"),
  }),
  component: ({ props }) => {
    const trendColor =
      props.trend === "up" ? "#16a34a" : props.trend === "down" ? "#dc2626" : "#6b7280";
    const trendIcon =
      props.trend === "up" ? "\u2191" : props.trend === "down" ? "\u2193" : "\u2192";
    return (
      <div
        style={{
          padding: "1.5rem",
          borderRadius: "0.75rem",
          border: "1px solid #e2e8f0",
          backgroundColor: "#ffffff",
          minWidth: "12rem",
        }}
      >
        <div style={{ fontSize: "0.875rem", color: "#64748b", marginBottom: "0.25rem" }}>
          {props.label}
        </div>
        <div style={{ fontSize: "1.875rem", fontWeight: 700, color: "#0f172a" }}>
          {props.value}
        </div>
        {props.change && (
          <div
            style={{
              fontSize: "0.875rem",
              color: trendColor,
              marginTop: "0.5rem",
              fontWeight: 500,
            }}
          >
            {trendIcon} {props.change}
          </div>
        )}
      </div>
    );
  },
});
```

**Example OpenUI Lang:**
```
root = MetricCard("Monthly Revenue", "$1.2M", "up", "+12.5%")
```

---

## 4. UserProfile

User information card with avatar, name, role, and links.

**When to use:** The LLM should choose UserProfile for displaying user/person information, team member cards, author bios, or contact cards.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const UserProfile = defineComponent({
  name: "UserProfile",
  description:
    "Displays a user profile card with name, email, role, avatar URL, and optional social links. Use for people/team member displays.",
  props: z.object({
    name: z.string().describe("Full name of the person"),
    email: z.string().describe("Email address"),
    role: z.string().describe("Job title or role"),
    avatarUrl: z
      .string()
      .optional()
      .describe("URL to the avatar image. Omit for a default placeholder."),
    socials: z
      .record(z.string())
      .optional()
      .describe(
        "Key-value pairs of social platform name to handle/URL, e.g. {github: 'user', twitter: '@user'}"
      ),
  }),
  component: ({ props }) => (
    <div
      style={{
        display: "flex",
        gap: "1rem",
        padding: "1.5rem",
        borderRadius: "0.75rem",
        border: "1px solid #e2e8f0",
        backgroundColor: "#ffffff",
        alignItems: "center",
      }}
    >
      <div
        style={{
          width: "4rem",
          height: "4rem",
          borderRadius: "50%",
          backgroundColor: "#e2e8f0",
          backgroundImage: props.avatarUrl ? `url(${props.avatarUrl})` : "none",
          backgroundSize: "cover",
          flexShrink: 0,
        }}
      />
      <div>
        <div style={{ fontWeight: 600, fontSize: "1.125rem", color: "#0f172a" }}>
          {props.name}
        </div>
        <div style={{ color: "#64748b", fontSize: "0.875rem" }}>{props.role}</div>
        <div style={{ color: "#3b82f6", fontSize: "0.875rem" }}>{props.email}</div>
        {props.socials && (
          <div
            style={{
              display: "flex",
              gap: "0.75rem",
              marginTop: "0.5rem",
              fontSize: "0.75rem",
              color: "#64748b",
            }}
          >
            {Object.entries(props.socials).map(([platform, handle]) => (
              <span key={platform}>
                {platform}: {handle}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = UserProfile("Jane Smith", "jane@example.com", "Senior Engineer", "https://example.com/avatar.jpg", {github: "janesmith", twitter: "@jane"})
```

---

## 5. PricingTier

Pricing plan card with features list and highlight option.

**When to use:** The LLM should choose PricingTier for pricing pages, plan comparisons, subscription tier displays, or any offer-based card.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const PricingTier = defineComponent({
  name: "PricingTier",
  description:
    "Renders a pricing plan card with name, price, billing period, feature list, and optional highlight. Use for pricing page tiers.",
  props: z.object({
    name: z.string().describe("Plan name, e.g. 'Pro' or 'Enterprise'"),
    price: z.string().describe("Formatted price, e.g. '$29' or '$0'"),
    period: z
      .enum(["month", "year", "one-time"])
      .describe("Billing period shown after the price"),
    features: z
      .array(z.string())
      .describe("List of features included in this plan"),
    highlighted: z
      .boolean()
      .describe("If true, this tier is visually emphasized as the recommended option"),
  }),
  component: ({ props }) => (
    <div
      style={{
        padding: "2rem",
        borderRadius: "0.75rem",
        border: props.highlighted ? "2px solid #3b82f6" : "1px solid #e2e8f0",
        backgroundColor: props.highlighted ? "#eff6ff" : "#ffffff",
        minWidth: "16rem",
        position: "relative",
      }}
    >
      {props.highlighted && (
        <div
          style={{
            position: "absolute",
            top: "-0.75rem",
            left: "50%",
            transform: "translateX(-50%)",
            backgroundColor: "#3b82f6",
            color: "#ffffff",
            padding: "0.125rem 0.75rem",
            borderRadius: "1rem",
            fontSize: "0.75rem",
            fontWeight: 600,
          }}
        >
          Recommended
        </div>
      )}
      <div style={{ fontWeight: 600, fontSize: "1.25rem", marginBottom: "0.5rem" }}>
        {props.name}
      </div>
      <div style={{ marginBottom: "1.5rem" }}>
        <span style={{ fontSize: "2.25rem", fontWeight: 700 }}>{props.price}</span>
        <span style={{ color: "#64748b", fontSize: "0.875rem" }}>/{props.period}</span>
      </div>
      <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
        {props.features.map((feature, i) => (
          <li
            key={i}
            style={{
              padding: "0.5rem 0",
              borderTop: i > 0 ? "1px solid #f1f5f9" : "none",
              fontSize: "0.875rem",
              color: "#334155",
            }}
          >
            {feature}
          </li>
        ))}
      </ul>
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = PricingTier("Pro", "$29", "month", features, true)
features = ["Unlimited projects", "50GB storage", "Priority support", "API access"]
```

---

## 6. StatusBadge

Colored status indicator pill/badge.

**When to use:** The LLM should choose StatusBadge for inline status indicators within tables, lists, or cards. Commonly used as cell values inside DataTable.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const StatusBadge = defineComponent({
  name: "StatusBadge",
  description:
    "Renders a small colored pill/badge showing a status label. Use inline within tables or cards to indicate item status.",
  props: z.object({
    label: z.string().describe("Status text, e.g. 'Active', 'Pending', 'Error'"),
    color: z
      .enum(["green", "yellow", "red", "blue", "gray", "purple"])
      .describe("Badge color. green=success, yellow=warning, red=error, blue=info, gray=neutral, purple=special"),
  }),
  component: ({ props }) => {
    const colorMap: Record<string, { bg: string; text: string }> = {
      green: { bg: "#dcfce7", text: "#166534" },
      yellow: { bg: "#fef9c3", text: "#854d0e" },
      red: { bg: "#fee2e2", text: "#991b1b" },
      blue: { bg: "#dbeafe", text: "#1e40af" },
      gray: { bg: "#f1f5f9", text: "#475569" },
      purple: { bg: "#f3e8ff", text: "#6b21a8" },
    };
    const c = colorMap[props.color] || colorMap.gray;
    return (
      <span
        style={{
          display: "inline-block",
          padding: "0.125rem 0.625rem",
          borderRadius: "9999px",
          fontSize: "0.75rem",
          fontWeight: 600,
          backgroundColor: c.bg,
          color: c.text,
        }}
      >
        {props.label}
      </span>
    );
  },
});
```

**Example OpenUI Lang:**
```
root = StatusBadge("Active", "green")
```

---

## 7. Timeline

Vertical event timeline with dates, titles, and descriptions.

**When to use:** The LLM should choose Timeline for project milestones, event histories, changelog displays, order tracking, or any sequential list of dated events.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

const TimelineEvent = z.object({
  date: z.string().describe("Date string, e.g. '2024-03-15' or 'March 2024'"),
  title: z.string().describe("Event title"),
  description: z.string().describe("Brief description of the event"),
  status: z
    .enum(["completed", "current", "upcoming"])
    .describe("Event status: completed (grayed), current (highlighted), upcoming (faded)"),
});

export const Timeline = defineComponent({
  name: "Timeline",
  description:
    "Renders a vertical timeline of events with dates, titles, descriptions, and status indicators. Use for project milestones, history, or sequential events.",
  props: z.object({
    events: z
      .array(TimelineEvent)
      .describe("Array of timeline events in chronological order"),
  }),
  component: ({ props }) => (
    <div style={{ padding: "1rem" }}>
      {props.events.map((event, i) => {
        const dotColor =
          event.status === "completed"
            ? "#10b981"
            : event.status === "current"
            ? "#3b82f6"
            : "#d1d5db";
        const opacity = event.status === "upcoming" ? 0.5 : 1;
        return (
          <div
            key={i}
            style={{
              display: "flex",
              gap: "1rem",
              opacity,
              paddingBottom: "1.5rem",
              position: "relative",
            }}
          >
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                flexShrink: 0,
              }}
            >
              <div
                style={{
                  width: "0.75rem",
                  height: "0.75rem",
                  borderRadius: "50%",
                  backgroundColor: dotColor,
                  border: event.status === "current" ? "2px solid #93c5fd" : "none",
                }}
              />
              {i < props.events.length - 1 && (
                <div
                  style={{
                    width: "2px",
                    flex: 1,
                    backgroundColor: "#e2e8f0",
                    marginTop: "0.25rem",
                  }}
                />
              )}
            </div>
            <div>
              <div style={{ fontSize: "0.75rem", color: "#64748b" }}>{event.date}</div>
              <div style={{ fontWeight: 600, color: "#0f172a" }}>{event.title}</div>
              <div style={{ fontSize: "0.875rem", color: "#475569", marginTop: "0.25rem" }}>
                {event.description}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = Timeline(events)
events = [e1, e2, e3]
e1 = {date: "2024-01-15", title: "Project Kickoff", description: "Team assembled and requirements gathered", status: "completed"}
e2 = {date: "2024-03-01", title: "Beta Launch", description: "Public beta with early adopters", status: "current"}
e3 = {date: "2024-06-01", title: "GA Release", description: "General availability", status: "upcoming"}
```

---

## 8. ComparisonTable

Side-by-side feature comparison table.

**When to use:** The LLM should choose ComparisonTable for product comparisons, feature matrices, plan comparisons, or any side-by-side evaluation of options.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const ComparisonTable = defineComponent({
  name: "ComparisonTable",
  description:
    "Renders a side-by-side comparison table. First column in each row is the feature name, remaining columns are the compared items. Use for product/plan/option comparisons.",
  props: z.object({
    columns: z
      .array(z.string())
      .describe("Column headers. First is typically 'Feature', rest are the items being compared"),
    features: z
      .array(z.array(z.string()))
      .describe(
        "Array of rows. Each row has values matching column order: [feature_name, item1_value, item2_value, ...]"
      ),
  }),
  component: ({ props }) => (
    <div style={{ overflowX: "auto" }}>
      <table
        style={{
          width: "100%",
          borderCollapse: "collapse",
          fontSize: "0.875rem",
        }}
      >
        <thead>
          <tr>
            {props.columns.map((col, i) => (
              <th
                key={i}
                style={{
                  textAlign: i === 0 ? "left" : "center",
                  padding: "0.75rem 1rem",
                  borderBottom: "2px solid #e2e8f0",
                  fontWeight: 600,
                  color: "#0f172a",
                  backgroundColor: i > 0 ? "#f8fafc" : "transparent",
                }}
              >
                {col}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {props.features.map((row, ri) => (
            <tr key={ri}>
              {row.map((cell, ci) => (
                <td
                  key={ci}
                  style={{
                    textAlign: ci === 0 ? "left" : "center",
                    padding: "0.75rem 1rem",
                    borderBottom: "1px solid #e2e8f0",
                    fontWeight: ci === 0 ? 500 : 400,
                    color: ci === 0 ? "#0f172a" : "#475569",
                  }}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = ComparisonTable(columns, features)
columns = ["Feature", "Basic", "Pro", "Enterprise"]
features = [f1, f2, f3]
f1 = ["Storage", "5 GB", "100 GB", "Unlimited"]
f2 = ["Users", "1", "10", "Unlimited"]
f3 = ["Support", "Community", "Email", "24/7 Phone"]
```

---

## 9. CodeBlock

Syntax-highlighted code display with language label and copy affordance.

**When to use:** The LLM should choose CodeBlock for displaying code snippets, configuration examples, API responses, terminal output, or any monospace preformatted text.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const CodeBlock = defineComponent({
  name: "CodeBlock",
  description:
    "Renders a code block with language label and monospace formatting. Use for code snippets, config files, or terminal output.",
  props: z.object({
    language: z
      .string()
      .describe("Programming language for the label, e.g. 'typescript', 'python', 'bash'"),
    code: z
      .string()
      .describe("The code content. Use \\n for newlines within the code."),
    title: z
      .string()
      .optional()
      .describe("Optional title shown above the code block, e.g. a filename"),
  }),
  component: ({ props }) => (
    <div
      style={{
        borderRadius: "0.5rem",
        overflow: "hidden",
        border: "1px solid #e2e8f0",
        backgroundColor: "#1e293b",
        fontSize: "0.875rem",
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          padding: "0.5rem 1rem",
          backgroundColor: "#334155",
          color: "#94a3b8",
          fontSize: "0.75rem",
        }}
      >
        <span>{props.title || props.language}</span>
        <span style={{ textTransform: "uppercase", letterSpacing: "0.05em" }}>
          {props.language}
        </span>
      </div>
      <pre
        style={{
          margin: 0,
          padding: "1rem",
          color: "#e2e8f0",
          overflowX: "auto",
          fontFamily: "'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace",
          lineHeight: 1.6,
        }}
      >
        <code>{props.code}</code>
      </pre>
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = CodeBlock("typescript", "import { z } from 'zod';\n\nconst schema = z.object({\n  name: z.string(),\n  age: z.number(),\n});", "schema.ts")
```

---

## 10. FAQ

Expandable FAQ section with question-answer pairs.

**When to use:** The LLM should choose FAQ for help pages, documentation sections, frequently asked questions, or any list of questions with answers that benefit from expandable display.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

const FAQItem = z.object({
  question: z.string().describe("The question text"),
  answer: z.string().describe("The answer text"),
});

export const FAQ = defineComponent({
  name: "FAQ",
  description:
    "Renders an expandable FAQ section with question-answer pairs. Use for help pages, documentation, or knowledge base displays.",
  props: z.object({
    items: z
      .array(FAQItem)
      .describe("Array of FAQ entries, each with a question and answer"),
  }),
  component: ({ props }) => (
    <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
      {props.items.map((item, i) => (
        <details
          key={i}
          style={{
            border: "1px solid #e2e8f0",
            borderRadius: "0.5rem",
            overflow: "hidden",
          }}
        >
          <summary
            style={{
              padding: "1rem",
              cursor: "pointer",
              fontWeight: 600,
              color: "#0f172a",
              backgroundColor: "#f8fafc",
              listStyle: "none",
            }}
          >
            {item.question}
          </summary>
          <div style={{ padding: "1rem", color: "#475569", fontSize: "0.875rem", lineHeight: 1.6 }}>
            {item.answer}
          </div>
        </details>
      ))}
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = FAQ(items)
items = [q1, q2]
q1 = {question: "How do I get started?", answer: "Install the package with npm install @openuidev/react-ui and follow the scaffold guide."}
q2 = {question: "Which LLMs are supported?", answer: "Any LLM that can generate text output, including OpenAI, Anthropic, Google, Mistral, and local models."}
```

---

## 11. ContactForm

Form with labeled input fields and a submit button.

**When to use:** The LLM should choose ContactForm for contact forms, feedback forms, sign-up forms, or any data collection UI with labeled inputs.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

const FormField = z.object({
  label: z.string().describe("Field label shown above the input"),
  type: z
    .enum(["text", "email", "textarea", "select", "number", "tel"])
    .describe("Input type"),
  placeholder: z.string().optional().describe("Placeholder text inside the input"),
  required: z.boolean().optional().describe("Whether this field is required"),
  options: z
    .array(z.string())
    .optional()
    .describe("Options for select type fields"),
});

export const ContactForm = defineComponent({
  name: "ContactForm",
  description:
    "Renders a form with labeled input fields and a submit button. Use for contact forms, feedback forms, or any data collection interface.",
  props: z.object({
    title: z.string().describe("Form heading"),
    description: z.string().optional().describe("Subtitle text below the form heading"),
    fields: z.array(FormField).describe("Array of form fields to render"),
    submitLabel: z
      .string()
      .optional()
      .describe("Text for the submit button. Defaults to 'Submit'."),
  }),
  component: ({ props }) => (
    <div
      style={{
        padding: "2rem",
        borderRadius: "0.75rem",
        border: "1px solid #e2e8f0",
        backgroundColor: "#ffffff",
        maxWidth: "32rem",
      }}
    >
      <h3 style={{ margin: "0 0 0.25rem", fontSize: "1.25rem", fontWeight: 600 }}>
        {props.title}
      </h3>
      {props.description && (
        <p style={{ margin: "0 0 1.5rem", color: "#64748b", fontSize: "0.875rem" }}>
          {props.description}
        </p>
      )}
      <form
        onSubmit={(e) => e.preventDefault()}
        style={{ display: "flex", flexDirection: "column", gap: "1rem" }}
      >
        {props.fields.map((field, i) => (
          <div key={i}>
            <label
              style={{
                display: "block",
                fontSize: "0.875rem",
                fontWeight: 500,
                color: "#0f172a",
                marginBottom: "0.375rem",
              }}
            >
              {field.label}
              {field.required && <span style={{ color: "#ef4444" }}> *</span>}
            </label>
            {field.type === "textarea" ? (
              <textarea
                placeholder={field.placeholder}
                required={field.required}
                rows={4}
                style={{
                  width: "100%",
                  padding: "0.5rem 0.75rem",
                  borderRadius: "0.375rem",
                  border: "1px solid #d1d5db",
                  fontSize: "0.875rem",
                  resize: "vertical",
                  boxSizing: "border-box",
                }}
              />
            ) : field.type === "select" ? (
              <select
                required={field.required}
                style={{
                  width: "100%",
                  padding: "0.5rem 0.75rem",
                  borderRadius: "0.375rem",
                  border: "1px solid #d1d5db",
                  fontSize: "0.875rem",
                  boxSizing: "border-box",
                }}
              >
                <option value="">{field.placeholder || "Select..."}</option>
                {field.options?.map((opt, oi) => (
                  <option key={oi} value={opt}>
                    {opt}
                  </option>
                ))}
              </select>
            ) : (
              <input
                type={field.type}
                placeholder={field.placeholder}
                required={field.required}
                style={{
                  width: "100%",
                  padding: "0.5rem 0.75rem",
                  borderRadius: "0.375rem",
                  border: "1px solid #d1d5db",
                  fontSize: "0.875rem",
                  boxSizing: "border-box",
                }}
              />
            )}
          </div>
        ))}
        <button
          type="submit"
          style={{
            padding: "0.625rem 1.25rem",
            borderRadius: "0.375rem",
            border: "none",
            backgroundColor: "#3b82f6",
            color: "#ffffff",
            fontWeight: 600,
            fontSize: "0.875rem",
            cursor: "pointer",
            marginTop: "0.5rem",
          }}
        >
          {props.submitLabel || "Submit"}
        </button>
      </form>
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = ContactForm("Get in Touch", "We'll respond within 24 hours.", fields, "Send Message")
fields = [f1, f2, f3, f4]
f1 = {label: "Name", type: "text", placeholder: "Your full name", required: true}
f2 = {label: "Email", type: "email", placeholder: "you@example.com", required: true}
f3 = {label: "Subject", type: "select", placeholder: "Choose a topic", required: true, options: ["General", "Support", "Sales", "Partnership"]}
f4 = {label: "Message", type: "textarea", placeholder: "How can we help?", required: true}
```

---

## 12. ProgressTracker

Multi-step progress indicator showing sequential steps with status.

**When to use:** The LLM should choose ProgressTracker for onboarding flows, order status, wizard progress, setup guides, or any multi-step process where the user needs to see their position.

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

const ProgressStep = z.object({
  label: z.string().describe("Step name"),
  description: z.string().optional().describe("Brief description of this step"),
  status: z
    .enum(["completed", "current", "upcoming"])
    .describe("Step status: completed (checkmark), current (highlighted), upcoming (grayed)"),
});

export const ProgressTracker = defineComponent({
  name: "ProgressTracker",
  description:
    "Renders a horizontal multi-step progress indicator. Use for onboarding, order status, setup wizards, or any sequential process.",
  props: z.object({
    steps: z
      .array(ProgressStep)
      .describe("Array of steps in order from first to last"),
  }),
  component: ({ props }) => (
    <div
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: "0",
        padding: "1rem",
      }}
    >
      {props.steps.map((step, i) => {
        const isCompleted = step.status === "completed";
        const isCurrent = step.status === "current";
        const dotColor = isCompleted
          ? "#10b981"
          : isCurrent
          ? "#3b82f6"
          : "#d1d5db";
        const textColor = step.status === "upcoming" ? "#94a3b8" : "#0f172a";
        return (
          <div
            key={i}
            style={{
              display: "flex",
              alignItems: "center",
              flex: i < props.steps.length - 1 ? 1 : "none",
            }}
          >
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
              <div
                style={{
                  width: "2rem",
                  height: "2rem",
                  borderRadius: "50%",
                  backgroundColor: dotColor,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#ffffff",
                  fontSize: "0.75rem",
                  fontWeight: 700,
                }}
              >
                {isCompleted ? "\u2713" : i + 1}
              </div>
              <div
                style={{
                  fontSize: "0.75rem",
                  fontWeight: isCurrent ? 600 : 400,
                  color: textColor,
                  marginTop: "0.5rem",
                  textAlign: "center",
                  maxWidth: "5rem",
                }}
              >
                {step.label}
              </div>
              {step.description && (
                <div
                  style={{
                    fontSize: "0.625rem",
                    color: "#94a3b8",
                    textAlign: "center",
                    maxWidth: "6rem",
                    marginTop: "0.125rem",
                  }}
                >
                  {step.description}
                </div>
              )}
            </div>
            {i < props.steps.length - 1 && (
              <div
                style={{
                  flex: 1,
                  height: "2px",
                  backgroundColor: isCompleted ? "#10b981" : "#e2e8f0",
                  margin: "0 0.5rem",
                  marginBottom: "auto",
                  marginTop: "1rem",
                }}
              />
            )}
          </div>
        );
      })}
    </div>
  ),
});
```

**Example OpenUI Lang:**
```
root = ProgressTracker(steps)
steps = [s1, s2, s3, s4]
s1 = {label: "Account", description: "Create account", status: "completed"}
s2 = {label: "Profile", description: "Set up profile", status: "completed"}
s3 = {label: "Settings", description: "Configure preferences", status: "current"}
s4 = {label: "Done", description: "Ready to go", status: "upcoming"}
```

---

## Library Assembly

After defining individual components, assemble them into a library using `createLibrary`. The library is what generates the system prompt and connects to the renderer.

```tsx
import { createLibrary } from "@openuidev/react-lang";

import { DataTable } from "./components/DataTable";
import { BarChart } from "./components/BarChart";
import { MetricCard } from "./components/MetricCard";
import { UserProfile } from "./components/UserProfile";
import { PricingTier } from "./components/PricingTier";
import { StatusBadge } from "./components/StatusBadge";
import { Timeline } from "./components/Timeline";
import { ComparisonTable } from "./components/ComparisonTable";
import { CodeBlock } from "./components/CodeBlock";
import { FAQ } from "./components/FAQ";
import { ContactForm } from "./components/ContactForm";
import { ProgressTracker } from "./components/ProgressTracker";

export const myLibrary = createLibrary({
  name: "my-app",
  description: "Full-featured UI component library for dashboard and content applications",
  components: [
    DataTable,
    BarChart,
    MetricCard,
    UserProfile,
    PricingTier,
    StatusBadge,
    Timeline,
    ComparisonTable,
    CodeBlock,
    FAQ,
    ContactForm,
    ProgressTracker,
  ],
  componentGroups: [
    {
      name: "Data Display",
      description: "Components for showing data in tables and charts",
      components: ["DataTable", "BarChart", "ComparisonTable"],
    },
    {
      name: "Cards",
      description: "Self-contained information cards",
      components: ["MetricCard", "UserProfile", "PricingTier"],
    },
    {
      name: "Status & Progress",
      description: "Status indicators and progress tracking",
      components: ["StatusBadge", "Timeline", "ProgressTracker"],
    },
    {
      name: "Content",
      description: "Content display components",
      components: ["CodeBlock", "FAQ"],
    },
    {
      name: "Forms",
      description: "User input and data collection",
      components: ["ContactForm"],
    },
  ],
});
```

**Key points about `createLibrary`:**

- `componentGroups` is optional but strongly recommended. It organizes the system prompt so the LLM can find relevant components faster.
- Keep the total component count under 30. More components means a larger system prompt, which means more tokens and worse LLM selection accuracy.
- The `description` on both the library and each group helps the LLM understand when to use each category.
- The library object exposes `.prompt()` for runtime system prompt generation and is passed to the renderer/ChatProvider as `componentLibrary`.

**Generating the system prompt from the library:**

```typescript
const systemPrompt = myLibrary.prompt({
  preamble: "You are a helpful assistant that generates interactive UIs for a dashboard application.",
  additionalRules: [
    "Always use Stack as the root when combining multiple components.",
    "Use MetricCard for any single KPI value.",
    "Use DataTable for any structured data with more than 3 rows.",
    "Prefer BarChart over raw numbers when comparing quantities.",
  ],
  examples: [
    'root = Stack([metric, chart])\nmetric = MetricCard("Users", "12,345", "up", "+8%")\nchart = BarChart("Signups", ["Mon","Tue","Wed"], [{label: "Count", values: [50,80,65]}])',
  ],
});
```
