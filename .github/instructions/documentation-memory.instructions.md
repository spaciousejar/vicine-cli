---
description: Keep project documentation in sync with code changes.
applyTo:
  - "README.md"
  - "CHANGELOG.md"
  - "docs/**"
  - "*.md"
---

# Documentation Memory

Documentation changes ship with every code change — never code alone.

## Update docs with every change

When a task changes code or behavior, update the docs in the same change:

- **README.md** — update when features, options, install steps, usage, or
  examples change.
- **CHANGELOG.md** — add the change under `[Unreleased]` using the existing
  sections (`Added`, `Changed`, `Fixed`, `Removed`), Keep a Changelog style.
- Any other doc or `--help`/usage text the change touches.

Check what exists before writing: read the current docs, update in place, and
match the project's existing tone and formatting.