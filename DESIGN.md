# Gitlock Design System

> Style guide, component architecture, and frontend conventions for the Gitlock UI.

## Stack

| Layer         | Tool                        | Notes                                      |
| ------------- | --------------------------- | ------------------------------------------ |
| Styling       | Tailwind CSS v4             | Utility-first, `@plugin` syntax            |
| Components    | daisyUI v5                  | Semantic class names on top of Tailwind     |
| Interactivity | Svelte 5                    | Runes mode, compiled via esbuild-svelte    |
| Flow Editor   | @xyflow/svelte              | Node-based workflow canvas                 |
| Icons         | Heroicons (via Phoenix)     | `hero-*` classes in HEEx templates          |
| Icons (JS)    | Lucide Svelte (planned)     | For Svelte components needing inline icons |
| Bridge        | Phoenix LiveView Hooks      | `phx-hook` connects LiveView ↔ Svelte      |

---

## Color Palette

We use daisyUI semantic color tokens so the entire UI respects light/dark theme switching automatically. **Never hardcode hex/oklch values in components.**

### Semantic Tokens (use these)

| Token               | Purpose                                  | Example class            |
| -------------------- | ---------------------------------------- | ------------------------ |
| `base-100/200/300`   | Page backgrounds, cards, surfaces        | `bg-base-200`            |
| `base-content`       | Default text on base backgrounds         | `text-base-content`      |
| `primary`            | CTAs, active states, key actions         | `btn-primary`            |
| `secondary`          | Supporting actions, secondary nav        | `btn-secondary`          |
| `accent`             | Highlights, badges, attention-grabbers   | `badge-accent`           |
| `neutral`            | Borders, muted elements, dividers        | `border-neutral`         |
| `info`               | Informational alerts, tooltips           | `alert-info`             |
| `success`            | Completed runs, passing checks           | `badge-success`          |
| `warning`            | Caution states, degraded metrics         | `alert-warning`          |
| `error`              | Failed runs, validation errors           | `alert-error`            |

### Analysis-Specific Colors

For heatmaps, risk scores, and data visualization, define a consistent scale:

| Risk Level | Tailwind Class    | Usage                         |
| ---------- | ----------------- | ----------------------------- |
| Critical   | `text-error`      | Hotspot score > 0.8           |
| High       | `text-warning`    | Hotspot score 0.6–0.8         |
| Medium     | `text-info`       | Hotspot score 0.3–0.6         |
| Low        | `text-success`    | Hotspot score < 0.3           |
| None       | `text-base-content/50` | No data / not analyzed   |

---

## Typography

Use Tailwind's default font stack. No custom fonts unless we add them intentionally later.

| Element        | Classes                                           |
| -------------- | ------------------------------------------------- |
| Page title     | `text-2xl font-bold`                              |
| Section header | `text-lg font-semibold`                           |
| Card title     | `text-base font-medium`                           |
| Body text      | `text-sm` (default)                               |
| Small/caption  | `text-xs text-base-content/60`                    |
| Mono/code      | `font-mono text-sm`                               |
| File paths     | `font-mono text-xs truncate`                      |

---

## Spacing & Layout

### Page Shell

```
┌─────────────────────────────────────────────┐
│  Navbar (fixed top, h-16)                   │
├──────────┬──────────────────────────────────┤
│ Sidebar  │  Main Content                    │
│ (w-64)   │  (flex-1, p-6)                   │
│          │                                  │
│          │                                  │
└──────────┴──────────────────────────────────┘
```

- **Navbar**: `navbar bg-base-100 border-b border-base-300 h-16`
- **Sidebar**: `w-64 bg-base-200 border-r border-base-300 overflow-y-auto`
- **Main content**: `flex-1 overflow-y-auto p-6`
- **Full-bleed pages** (workflow canvas): skip padding, `h-[calc(100vh-4rem)]`

### Spacing Scale

Use Tailwind defaults. Prefer `gap-*` on flex/grid over margin:

| Context           | Spacing  |
| ----------------- | -------- |
| Between sections  | `gap-8`  |
| Between cards     | `gap-4`  |
| Inside cards      | `p-4`    |
| Between form rows | `gap-3`  |
| Inline elements   | `gap-2`  |
| Icon + text       | `gap-1.5`|

---

## Component Patterns

### daisyUI Components (use in HEEx & Svelte)

Prefer daisyUI class-based components over building from scratch:

| Need                | daisyUI Component          | Class Example                    |
| ------------------- | -------------------------- | -------------------------------- |
| Buttons             | `btn`                      | `btn btn-primary btn-sm`         |
| Cards               | `card`                     | `card bg-base-200 shadow-sm`     |
| Forms               | `input`, `select`, `label` | `input input-bordered input-sm`  |
| Navigation          | `menu`, `navbar`           | `menu menu-sm`                   |
| Feedback            | `alert`, `toast`           | `alert alert-info`               |
| Data display         | `badge`, `table`           | `badge badge-success badge-sm`   |
| Loading             | `loading`                  | `loading loading-spinner`        |
| Modals              | `modal`                    | `modal` + `dialog` element       |
| Tabs                | `tabs`                     | `tabs tabs-bordered`             |
| Dropdown            | `dropdown`                 | `dropdown dropdown-end`          |
| Tooltip             | `tooltip`                  | `tooltip` + `data-tip`           |
| Progress            | `progress`, `radial-progress` | `progress progress-primary`  |
| Toggle/checkbox     | `toggle`, `checkbox`       | `toggle toggle-primary toggle-sm`|
| Collapse/accordion  | `collapse`                 | `collapse collapse-arrow`        |

### Button Hierarchy

| Level     | Classes                          | When                               |
| --------- | -------------------------------- | ---------------------------------- |
| Primary   | `btn btn-primary`                | One per page/section, main CTA     |
| Secondary | `btn btn-secondary btn-outline`  | Supporting actions                 |
| Ghost     | `btn btn-ghost`                  | Navigation, toolbar, low emphasis  |
| Danger    | `btn btn-error btn-outline`      | Destructive actions                |
| Sizes     | `btn-xs`, `btn-sm`, `btn-md`     | `btn-sm` is default in app chrome  |

---

## Svelte Component Architecture

### Directory Structure

```
assets/svelte/
├── components/           # Reusable UI primitives
│   ├── Badge.svelte
│   ├── EmptyState.svelte
│   ├── MetricCard.svelte
│   ├── RiskBadge.svelte
│   └── FilePathDisplay.svelte
├── workflow/             # Workflow canvas & nodes
│   ├── WorkflowCanvas.svelte
│   ├── nodes/
│   │   ├── AnalysisNode.svelte
│   │   ├── SourceNode.svelte
│   │   ├── TransformNode.svelte
│   │   └── OutputNode.svelte
│   ├── panels/
│   │   ├── NodeConfigPanel.svelte
│   │   └── WorkflowToolbar.svelte
│   └── stores.js
├── analysis/             # Analysis result displays
│   ├── HotspotTable.svelte
│   ├── CouplingMatrix.svelte
│   ├── KnowledgeMap.svelte
│   └── ComplexityChart.svelte
├── dashboard/            # Dashboard widgets
│   ├── RepoHealthCard.svelte
│   ├── RecentRunsList.svelte
│   └── RiskOverview.svelte
└── shared/               # Cross-cutting utilities
    ├── stores.js         # Global Svelte stores
    └── utils.js          # Formatting, helpers
```

### Svelte ↔ LiveView Bridge Pattern

Every Svelte component that mounts from LiveView follows this pattern:

```javascript
// In assets/js/hooks/my_hook.js
import MyComponent from "../svelte/path/MyComponent.svelte";

export const MyHook = {
  mounted() {
    const props = JSON.parse(this.el.dataset.props || "{}");

    this.component = new MyComponent({
      target: this.el,
      props: {
        ...props,
        pushEvent: (event, payload) => this.pushEvent(event, payload),
      },
    });
  },

  updated() {
    const props = JSON.parse(this.el.dataset.props || "{}");
    // Update reactive props via Svelte 5 $set or re-mount
  },

  destroyed() {
    this.component?.$destroy();
  },
};
```

```elixir
# In LiveView template
<div id="my-component"
     phx-hook="MyHook"
     data-props={Jason.encode!(@component_data)}>
</div>
```

### Svelte Component Conventions

1. **Props interface**: Always define with `let { prop1, prop2 } = $props()` (Svelte 5 runes)
2. **Events to LiveView**: Use `pushEvent` prop, never direct WebSocket access
3. **Styling**: Use Tailwind/daisyUI classes. Scoped `<style>` only for complex animations or @xyflow overrides
4. **Size**: Keep components < 150 lines. Extract sub-components when exceeding
5. **State**: Local state with `$state()`. Shared state via stores in the same feature directory

---

## Page-Specific Patterns

### Dashboard

- Grid layout: `grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4`
- Each widget is a `card bg-base-200 shadow-sm`
- Empty states use `EmptyState.svelte` with icon + description + action

### Workflow Editor

- Full viewport height: `h-[calc(100vh-4rem)]`
- Canvas background: daisyUI `base-300`
- Node styling: `card bg-base-100 shadow-md border border-base-300`
- Selected node: `ring-2 ring-primary`
- Node header colors by type:
  - Source: `bg-info/10 text-info`
  - Analysis: `bg-primary/10 text-primary`
  - Transform: `bg-warning/10 text-warning`
  - Output: `bg-success/10 text-success`

### Analysis Results

- Tables: `table table-sm table-zebra`
- Sort indicators: `hero-chevron-up` / `hero-chevron-down`
- File paths: `font-mono text-xs` with truncation + tooltip on hover
- Metrics: Use `MetricCard` with label, value, trend indicator

### Pipeline Runs

- Status badges:
  - Running: `badge badge-info` + `loading loading-spinner loading-xs`
  - Success: `badge badge-success`
  - Failed: `badge badge-error`
  - Pending: `badge badge-ghost`
- Timeline: vertical `steps steps-vertical` from daisyUI

---

## Interaction Patterns

### Loading States

| Context           | Pattern                                           |
| ----------------- | ------------------------------------------------- |
| Page load         | Skeleton loader (daisyUI `skeleton` class)        |
| Button action     | `btn` with `loading loading-spinner loading-sm`   |
| Table refresh     | Subtle opacity: `opacity-60 pointer-events-none`  |
| Long operation    | `progress` bar + status text                      |

### Empty States

Always provide:
1. An icon (hero-* or inline SVG)
2. A clear message
3. An action to resolve (button or link)

```html
<div class="flex flex-col items-center justify-center gap-4 py-16 text-base-content/50">
  <span class="hero-folder-open h-12 w-12" />
  <p class="text-sm">No pipelines yet</p>
  <button class="btn btn-primary btn-sm">Create your first pipeline</button>
</div>
```

### Toasts & Notifications

Use Phoenix flash messages styled with daisyUI `alert`:

```html
<div class="toast toast-end">
  <div class="alert alert-success">
    <span>Pipeline saved successfully</span>
  </div>
</div>
```

---

## Dark Mode

Handled automatically by daisyUI theme switching. Rules:

1. **Never use `bg-white`, `bg-black`, `text-gray-*`** — always semantic tokens
2. **Borders**: `border-base-300` (not `border-gray-200`)
3. **Shadows**: `shadow-sm` or `shadow-md` (Tailwind adapts)
4. **Hover states**: Use `/10` or `/20` opacity variants: `hover:bg-primary/10`
5. **Theme toggle**: In navbar, use daisyUI `swap` or `toggle` with JS to flip `data-theme`

---

## Responsive Breakpoints

| Breakpoint | Usage                            |
| ---------- | -------------------------------- |
| `sm`       | Stack sidebar below content      |
| `md`       | 2-column grid for dashboard      |
| `lg`       | Sidebar visible by default       |
| `xl`       | 3-column dashboard, wider panels |

The workflow editor is **desktop-only** — show a message on mobile suggesting desktop use.

---

## Naming Conventions

| Thing              | Convention                    | Example                          |
| ------------------ | ----------------------------- | -------------------------------- |
| Svelte component   | PascalCase                    | `AnalysisNode.svelte`            |
| Svelte store file  | camelCase                     | `stores.js`                      |
| CSS file           | kebab-case                    | `workflow.css`                   |
| LiveView hook      | PascalCase (object key)       | `WorkflowHook`                   |
| Custom event       | kebab-case                    | `node-selected`, `run-pipeline`  |
| Data attribute     | kebab-case                    | `data-node-id`, `data-props`     |

---

## Do / Don't

### Do

- Use daisyUI component classes before building custom
- Keep Svelte components focused and < 150 lines
- Use semantic color tokens everywhere
- Pass data from LiveView via `data-*` attributes
- Use `gap-*` instead of margins between siblings
- Test with both light and dark themes

### Don't

- Don't hardcode colors (`#fff`, `oklch(...)`, `gray-200`)
- Don't use Svelte for things LiveView handles fine (forms, navigation)
- Don't fight daisyUI — if it doesn't have the component, build with Tailwind utilities
- Don't nest Svelte components more than 3 levels deep
- Don't put business logic in Svelte — keep it in LiveView/Elixir
- Don't use `@apply` in CSS files — inline Tailwind classes instead
