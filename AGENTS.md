# Global Agent Instructions

## Subagent delegation

The `subagent` tool delegates to specialized agents with isolated context windows. Use it proactively — do NOT try to do everything in the main conversation.

### Available agents

| Agent | Model | Use when |
|---|---|---|
| `search` | gemini-3-flash-agent | **Codebase exploration**: finding files/code by functionality or concept, locating usages, tracing call sites, pattern discovery. Prefer this over manual grep/find in the main thread. |
| `oracle` | gpt-5.6-sol | **Deep reasoning**: complex code review, architecture decisions, refactoring strategy, debugging subtle bugs, "second opinion" on non-trivial problems. |

### When to delegate

- **Always use `search`** when the user asks "where is X", "find all Y", "how does Z work", or any task requiring you to explore unfamiliar code. Run search early to ground yourself, then act.
- **Use `oracle`** when the problem is genuinely complex (cross-cutting refactor, ambiguous bug, design trade-offs), when you're about to make a non-trivial architectural decision, or when the user explicitly asks for a thorough review / second opinion.
- **Do NOT delegate** trivial lookups (single known file path), quick edits, or simple bash tasks. Use main-thread tools directly.

### How to call

```
subagent({ agent: "search", task: "Find all call sites of view_media and trace how images flow to the model" })
subagent({ agent: "oracle", task: "Review src/auth.ts for security issues and propose minimal fixes" })
```

For independent investigations, run multiple `search` tasks in parallel via `tasks: [...]`.

### After delegation

Trust the subagent's findings — it has its own context window and explored deeply. Summarize/act on its output; don't redo the search in the main thread.
