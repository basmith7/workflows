# workflows

Reusable GitHub Actions workflows for basmith7's own apps, and the one copy of their CI and
their Next+Prisma Dockerfile. Public so that public and private repos can both call them; there
is nothing secret here. Not accepting contributions.

App repos hold only thin callers. Start from [`templates/`](templates): `ci.yml` runs the checks
on pull requests (skipped when only docs change) and holds the repo's one copy of its CI inputs
(its `with:`). `build.yml`'s `test` job calls that `ci.yml` (`uses: ./.github/workflows/ci.yml`)
on a `v*` tag before building the image, so a tag runs exactly the PR checks. A called run has
no path filter, and it takes its caller's `github` context (event `push`, the tag's ref), so it
never shares a concurrency group with a PR run and is never cancelled. Every workflow's inputs
and defaults are documented at the top of its file, and every one takes `runs-on` as JSON
(`'"ubuntu-latest"'` or a list of labels), so a repo can move to a self-hosted runner without
forking anything.

Callers pin `@main`, so a push here changes every app's CI and builds at once.

## `node-ci.yml`

`npm ci` (with the npm cache), then by default `npm run` lint, typecheck, test and build, each
only if `package.json` defines it, so most repos pass no `commands`. A repo that installs
`@basmith7/*` packages sets `packages-read` and its caller job grants `packages: read`.
`docker-template: <name>` runs `templates/<name>/check-drift` on the repo before anything else,
from the same commit of this repo as the workflow (see below).

## `python-ci.yml`

For uv projects: installs any `apt-packages`, then runs `uv run ruff check --config ruff.toml .`
and `uv run pytest -q` (override with `commands`). The project lists ruff and pytest as dev
dependencies.

Ruff can't extend a remote config, so the workflow copies this repo's [`ruff.toml`](ruff.toml),
from the commit being called, into the caller's checkout. That file is the one rule set: a repo
that carries its own `ruff.toml` fails CI. Locally, run
`uv run ruff check --config ~/Projects/workflows/ruff.toml .`.

## `build-image.yml`

Builds one Docker image from the calling repo, pushes it to `ghcr.io/<owner>/<image>` with the
OCI `source`/`revision`/`version`/`created` labels, and caches layers in the registry as
`:buildcache`, so every trigger (tag, branch, dispatch) shares one cache. A repo that builds two
images calls it twice (a matrix). A build that mounts BuildKit secrets gets them through the
`build-secrets` secret (`id=value` lines), which the caller passes explicitly rather than with
`secrets: inherit`. Tagging and deploying stay with the caller; this only builds and pushes.

## `templates/next-prisma/`

The one Next+Prisma `Dockerfile` and `docker-entrypoint.sh`. Each app keeps a copy rather than a
base image, so a per-app tweak stays one line. Anything app-only is marked with `# app:`.
`check-drift <repo-dir>` diffs an app's copy against the template, ignoring the marked lines, and
exits nonzero on drift. `check-drift --help` gives the marker rules.

Every app built from it is held to it in CI: its `ci.yml` passes `docker-template: next-prisma`
to `node-ci.yml`. A template change here therefore fails every app's next PR and tag build until
the app copies it in (run `~/Projects/workflows/templates/next-prisma/check-drift .` in the app to
see the diff). A Node major bump lands here first (the `FROM` lines, and `node-ci.yml`'s
`node-version` default), then in each app; an app that bumps first fails its drift check.

- The image builds without the optional `npm_token` secret; pass it (`npm-token: true` in the
  caller of `build-image.yml`) when the app installs `@basmith7` packages from GitHub Packages.
  It copies `.npmrc`, so every app needs one, even if it only names the registry.
- The entrypoint runs `prisma migrate deploy` on every start. It also runs the seed when
  `SEED_ON_START=1`.
- The two `# TEMP: revert when nodejs/node#66871 ships` lines (and their marker) go from every
  app at once when the Node fix lands.

`tests/check-drift.test.sh` tests the checker against fixture apps made from the live template.

## Renovate: `default.json`

The one dependency-update policy. A repo opts in with a `renovate.json` of
`{"extends": ["github>basmith7/workflows"]}` once its default branch runs shared CI (Renovate
merges only after CI passes, and a repo with no checks has nothing to wait for). Minor and patch
updates arrive as one grouped PR each Monday morning and merge themselves (`platformAutomerge` is
off because free private repos have no required checks, so GitHub's own auto-merge would not
wait for CI); majors open as PRs for a person. `basmith7/workflows@main` refs are never touched.

Renovate regenerates lockfiles with npm 11 (`constraints`). Its default npm 12 refuses the registry
tarball URLs in Tailwind's lockfile entries (`EALLOWREMOTE`, npm/cli#9800), and npm 10 fails on
`@vitejs/plugin-react`'s optional Babel 8 peer chain (`ERESOLVE`). CI's npm 10 installs npm 11
lockfiles; drop the pin once npm 12 fixes #9800.

`@basmith7/*` packages on GitHub Packages are read with the `GH_PACKAGES_TOKEN` credential (a
classic token with `read:packages`), stored in the Mend developer portal
(developer.mend.io → basmith7 → Settings → Credentials). The hosted app no longer reads
encrypted secrets from config files. Validate changes with
`npx --yes --package renovate@latest renovate-config-validator --strict default.json`.
