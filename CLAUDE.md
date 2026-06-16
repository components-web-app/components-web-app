# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

---

## Nested page templates — `pageDataProperty` pattern (complete)

**Status: Done.**

`NestedTopicTemplate.vue` and `NestedSubPageTemplate.vue` use `props.iri` as the `CwaComponentGroup` location (the template page IRI). The template page's primary group has a position with `pageDataProperty='introContent'` (no direct component) — CWA resolves this dynamically from the current `NestedPageData` instance's `introContent` field at render time. Fixtures set `$pageData->introContent` per instance and have been reloaded.

---

## Layout component groups: not an IRI-string issue

The API returns `componentGroups` on a `Layout` resource as **embedded JSON-LD objects**, not IRI strings. This was a module-side bug (now fixed in `fetcher.ts`) — no fixture changes needed. Nav links in the layout now render correctly for unauthenticated users.
