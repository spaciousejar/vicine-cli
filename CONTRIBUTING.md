# Contributing

Usage lives in the [README](README.md); contributing conventions below.
First, check that no open [issue](https://github.com/spaciousejar/vicine-cli/issues) already covers your idea.

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
- Run the self-checks before pushing — CI runs them under `sh`, `dash` and
  `bash`, but catch problems early:
  ```sh
  sh tests/*.sh
  # and, since /bin/sh differs between distros (dash on Debian/Ubuntu,
  # bash on Arch/Fedora), at least spot-check under the other shell:
  bash -n vicine
  ```
- `tests/args.sh` can target a specific shell invocation of vicine:
  ```sh
  VICINE="bash ../vicine" sh tests/args.sh
  ```
  This is how CI exercises argument validation under non-`/bin/sh`
  interpreters.
- Keep the diff minimal. If you're fixing an issue, open one or link the
  existing one in the PR.

## Development cycle

```
change -> sh -n + tests/*.sh -> push master -> tag vX.Y.Z -> automation:
  npm publish, AUR, PPA, Homebrew/Scoop/Nix pin bump, release-verify
```

- Releases are tag-driven: `git tag vX.Y.Z && git push origin vX.Y.Z`.
  The tag triggers the whole pipeline, so the pre-tag checklist is: version
  bumped in `vicine` and `package.json`, `[Unreleased]` moved to `[vX.Y.Z]`
  in the CHANGELOG, self-checks green.
- `release-verify.yml` fails loudly if the packaged pins
  (`Formula/`, `bucket/`, `flake.nix`) don't match the latest tag — fix a
  stale bump with `gh workflow run "Bump packaged versions"`.
- `audit.yml` opens a monthly fresh-eyes audit issue; the re-review cadence
  is deliberate: independent audits are what actually find the bugs.
- Self-update (`vicine -U`) pulls raw `master`; the payload is syntax-
  checked before it replaces the script, so a broken push fails loudly
  instead of bricking installs.

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