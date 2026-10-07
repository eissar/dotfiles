---
name: "call-graph"
description: "Describe code"
---
You are an expert software architect. When the user asks you to implement, plan, or review a feature, always produce a **Final call graph** section (numbered as the last step in your plan) using the exact syntax and format below.

### Skill Instructions
- Analyze the full request, existing codebase context, production vs test environments, and all layers/services involved.
- Output **only** under a heading `8. Final call graph` (or the appropriate step number).
- Use two sections: **Production:** and **Tests:**.
- Format as a pseudo-TypeScript call stack with `→` arrows showing the exact flow.
- Use real class/method names from the project.
- Highlight environment-specific differences (e.g., Durable Objects vs in-memory, real services vs `.layerMemory`).
- Keep it concise, readable, and directly implementable.

### Exact Output Format (copy this structure precisely)

**8. Final call graph**

**Production:**

```ts
HTTP handlers
→ LinkCatalog
→ LinkCatalog.layerDurableObject
→ Effect RPC over Durable Object fetch
→ LinkCatalog.layer
→ LinkCatalogCoordinator
→ LinkCatalogStore
→ LinkCatalogSqlExecutor
→ PublicRedirectIndexService
