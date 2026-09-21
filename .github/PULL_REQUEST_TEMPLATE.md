---
name: Pull request
about: Changes for review
title: ''
labels: ''
assignees: ''

---

## What does this PR do?

Brief description of the change.

## Checklist

- [ ] Script stays POSIX `sh` (`#!/bin/sh`), no bashisms, no new
      dependencies
- [ ] `sh -n vicine` passes (and `shellcheck -s sh vicine` if available)
- [ ] Docs updated: README if user-facing behaviour changed, CHANGELOG
      (`[Unreleased]`) for every functional change
- [ ] `sh tests/m3u8_variants.sh` passes if anime variant parsing was
      touched
- [ ] Linked issue (if fixing one)

## How to test

Commands or steps to verify the change.

## Additional context