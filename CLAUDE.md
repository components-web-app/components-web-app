# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

---

## Nested page templates — `pageDataProperty` pattern (complete, pending module fix)

**Status: Fixtures done. Templates correct. Blocked on a module-side path header bug for the child-page case.**

Templates (`NestedTopicTemplate.vue`, `NestedSubPageTemplate.vue`) use `props.iri` as the `CwaComponentGroup` location. The template page's primary group has a `ComponentPosition` with `pageDataProperty='introContent'` (no direct component). Each `NestedPageData` instance has `introContent` set to its own `HtmlContent` entity. Fixtures reloaded 2026-06-16.

**What works now:**
- `/topic-1` → intro content shows ✓ (path header = `/topic-1`, resolves Topic 1's PageData, reads `introContent`)

**What is broken (module bug):**
- `/topic-1/chapter-one` → parent template's intro slot is empty ✗

Root cause: the module sends `path = <leaf URL>` as a single header applied to ALL requests in the manifest batch. `ComponentPositionNormalizer` uses that path to look up the current PageData via `PageDataProvider::getPageData()` → `route->getPageData()`. For route `/topic-1/chapter-one` the route resolves to a static `Page` (no PageData), so `getPageData()` returns `null` and `introContent` is not substituted.

**Fix needed in the module** — tracked in module CLAUDE.md. The fetcher must send depth-appropriate `path` headers: when fetching a resource that belongs to depth N, use the route path from depth N's manifest group, not the leaf (deepest) path.

---

## Layout component groups: not an IRI-string issue

The API returns `componentGroups` on a `Layout` resource as **embedded JSON-LD objects**, not IRI strings. This was a module-side bug (now fixed in `fetcher.ts`) — no fixture changes needed. Nav links in the layout now render correctly for unauthenticated users.
