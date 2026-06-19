# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

## Docs

Any change made to this template application must be reflected in the docs project at `/Users/danielwest/Documents/GitHub/_CWA/docs`. After completing work here, always check whether the docs need updating and flag it if so.

## Planned Features

### GitHub Actions CI/CD

The template currently ships GitLab CI only (`.gitlab-ci.yml`). GitHub Actions support is planned. The shell functions in `bin/devops/` are the reusable CI primitives — a GitHub Actions implementation would write workflow YAML files (`.github/workflows/`) that call the same functions. This would allow teams on GitHub to get the same build/test/deploy pipeline without rewriting the logic.