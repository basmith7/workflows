# workflows

Reusable GitHub Actions workflows for basmith7's own apps, and the one copy of their CI. Public so
that public and private repos can both call them; there is nothing secret here. Not accepting
contributions.

App repos hold only thin callers. Start from [`templates/`](templates): `ci.yml` runs the checks
on pull requests (skipped when only docs change), and `build.yml` runs the same checks on a `v*`
tag before building the image. Every workflow's inputs and defaults are documented at the top of
its file, and every one takes `runs-on` as JSON (`'"ubuntu-latest"'` or a list of labels), so a
repo can move to a self-hosted runner without forking anything.

Callers pin `@main`, so a push here changes every app's CI and builds at once.

## `node-ci.yml`

`npm ci` (with the npm cache), then by default `npm run` lint, typecheck, test and build, each
only if `package.json` defines it, so most repos pass no `commands`. A repo that installs
`@basmith7/*` packages sets `packages-read` and its caller job grants `packages: read`.

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
