# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

---

## Nested page templates — `pageDataIri` inject (complete)

**Status: Done.**

`NestedTopicTemplate.vue` and `NestedSubPageTemplate.vue` both inject `'cwa-page-data-iri'` and use it as the `CwaComponentGroup` location (falling back to `props.iri` when undefined). Fixtures create per-PageData component groups with `reference="primary_<pagedata-iri>"` and `location=<pagedata-iri>`, associated with the template page so they are fetched for unauthenticated users via the page's `componentGroups` chain. Fixtures have been reloaded.

---

## Layout component groups: not an IRI-string issue

The API returns `componentGroups` on a `Layout` resource as **embedded JSON-LD objects**, not IRI strings. This was a module-side bug (now fixed in `fetcher.ts`) — no fixture changes needed. Nav links in the layout now render correctly for unauthenticated users.
