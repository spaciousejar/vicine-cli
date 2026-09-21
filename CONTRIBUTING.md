# Contributing

## Pull requests

- The script must stay POSIX `sh` (`#!/bin/sh`): no bashisms, no new
  dependencies unless the feature genuinely needs one.
- Check the script before opening a PR:
  ```sh
  sh -n vicine
  shellcheck -s sh vicine        # if shellcheck is available
  ```
- Update the docs with your change: the README if user-facing behaviour
  changes, and the CHANGELOG (`[Unreleased]` section, Keep a Changelog
  style) for every functional change.
- Run the parser self-check if you touched anime variant handling:
  ```sh
  sh tests/m3u8_variants.sh
  ```
- Keep the diff minimal. If you're fixing an issue, open one or link the
  existing one in the PR.

## Issues

- Use the issue templates (bug report / feature request).
- Search existing issues before filing — duplicates get closed.
- For bug reports: confirm you're on the latest version (`vicine -V` vs
  `vicine -U`), and include the version, OS, shell (`readlink /bin/sh`),
  the exact command you ran, and the output.

## Testing

vicine is a scraping tool — worst case an API changes shape. When a
provider regresses, capture the raw API response and note the endpoint so
the parsers can be fixed against something real.