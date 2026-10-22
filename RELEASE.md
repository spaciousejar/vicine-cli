# Releasing vicine

Short answer: release when there's something worth shipping, never on a
dirty tree or red CI; the tag does the rest.

## When to release

| bump | what triggers it |
|------|------------------|
| patch (`x.y.Z`) | fixes only — most releases; also **emergency releases**: any provider outage or download-path break ships immediately after the fix lands |
| minor (`x.Y.0`) | a user-facing feature without breaking changes |
| major (`X.0.0`) | breaking changes (flag removal, provider removal) |

No fixed calendar. The monthly `audit.yml` issue is the natural checkpoint:
close an audit round with one patch release, then tag.

Never release when:
- the tree is dirty (uncommitted changes can race the tag automation —
  the file can be read mid-write, which has happened and broke a run)
- master's CI is red (Tests workflow failing)

## How to release

All on `master`, CI green:

1. **Bump the version** in exactly three places:
   - `version_number="X.Y.Z"` in `vicine` (user-visible via `vicine -V`)
   - `"version": "X.Y.Z"` in `package.json`
   - CHANGELOG: move `[Unreleased]` to `[X.Y.Z] - <date>`, leave a fresh
     `[Unreleased]` header on top
2. **Check** `sh -n vicine` + `sh tests/*.sh` (the CI matrix covers
   `bash`/`dash`; local `sh`/`bash` check catches most).
3. **Commit**: `release: vX.Y.Z`.
4. **Tag and push**:
   ```sh
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
   (push `master` first if the release commit only went there.)

## What the tag triggers (automation)

| workflow | does |
|----------|------|
| `publish.yml` | npm publish + GitHub Release (notes = commit log since previous tag) |
| `aur.yml` | bumps `pkgver`, recomputes sums, pushes the AUR package |
| `ppa.yml` | builds + uploads the Launchpad PPA source package |
| `pkg-bump.yml` | rewrites Homebrew/Scoop/Nix pins (runs on `master`, so its auto-commit can push) |
| `tests.yml` | self-checks under `sh`, `dash`, `bash` |
| `release-verify.yml` | fails loudly if the packaged pins didn't advance to the tag |

## Post-tag (5 minutes)

1. Watch Actions; if `release-verify` fails:
   `gh workflow run "Bump packaged versions"` — a stale bump is a manual fix.
2. **Verify the channels.** A workflow can be green while a channel holds
   nothing. The Ubuntu PPA did exactly that for months. One command probes
   every artifact (npm, GitHub Release, AUR, Homebrew tap, Scoop bucket, Nix
   flake, the PPA):
   ```sh
   sh scripts/verify-channels.sh 1.7.3 --wait 20
   ```
   CI runs the same check on the tag (`verify-channels.yml`). The build fails
   if a channel still does not serve the release after 20 minutes.
3. Spot-check the headline channels:
   ```sh
   npm view vicine version
   # AUR answers JSON-RPC and the arg[] form is required — a bare ?vicine
   # returns "No request type/data specified". The version carries a pkgrel
   # suffix (1.6.0-2), not the bare tag version.
   curl -s 'https://aur.archlinux.org/rpc/v5/info?arg[]=vicine' | jq -r '.results[0].Version'
   ```
4. Done — the monthly audit covers everything else.

### The PPA needs one manual step

`ppa.yml` uploads to Launchpad. Launchpad accepts an upload only when the
signature comes from a key **registered on the Launchpad account**. It rejects
the upload silently otherwise. That is why the workflow stayed green for
months while nothing was published. The job now waits for the source to appear
in Launchpad's API and fails if it does not. A rejected upload is red, not
silent.

To fix a rejected upload, export the public half of the key that the workflow
signs with. Register it at <https://launchpad.net/~spaciousejar/+gpgkeys>.
Make sure the address in `DEBEMAIL` is confirmed on the account. Set the repo
variable `PPA_GPG_FINGERPRINT` to the registered fingerprint. The workflow then
fails fast if the secret's key ever differs from it.

## Versioning model

vicine's version lives in the script (`version_number`, shown by `vicine -V`)
and `package.json`; the tag triggers publishing. This is deliberately the
opposite of registry-derived versioning (e.g. opencode computes the next
version from npm's `latest` at publish time): vicine is a single-file tool
whose version is part of the artifact, so bumping it in the file keeps
`vicine -V`, npm, AUR, Homebrew, Scoop and Nix all reading one source.
Registry-derived bumping would add an env flag for zero benefit here.