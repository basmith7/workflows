# workflows

Reusable GitHub Actions workflows and shared app templates for basmith7's own apps. Public so
that public and private repos can both call them; there is nothing secret here. Not accepting
contributions.

## `build-image.yml`

Builds one Docker image from the calling repo, pushes it to `ghcr.io/<owner>/<image>` with the
OCI `source`/`revision`/`version`/`created` labels, and caches layers in the registry as `:buildcache`, so every trigger (tag, branch, dispatch) shares one cache.
Inputs and their defaults are documented at the top of the file. A repo that builds two images
calls it twice (a matrix); tests stay in the caller as a job the build `needs:`. A build that
mounts BuildKit secrets gets them through the `build-secrets` secret (`id=value` lines), which the
caller passes explicitly rather than with `secrets: inherit`.

```yaml
# .github/workflows/build.yml
name: Build
on:
  push:
    tags: ["v*"]
jobs:
  image:
    uses: basmith7/workflows/.github/workflows/build-image.yml@main
    permissions:
      contents: read
      packages: write
```

Tagging and deploying stay with the caller; this only builds and pushes.

## `templates/next-prisma/`

The one Next+Prisma `Dockerfile` and `docker-entrypoint.sh`. Each app keeps a copy rather than a
base image, so a per-app tweak stays one line. Anything app-only is marked with `# app:`.
`check-drift <repo-dir>` diffs an app's copy against the template, ignoring the marked lines, and
exits nonzero on drift. `check-drift --help` gives the marker rules.

- The image builds without the optional `npm_token` secret; pass it (`npm-token: true` in the
  caller of `build-image.yml`) when the app installs `@basmith7` packages from GitHub Packages.
  It copies `.npmrc`, so every app needs one, even if it only names the registry.
- The entrypoint runs `prisma migrate deploy` on every start. It also runs the seed when
  `SEED_ON_START=1`.
- The two `# TEMP: revert when nodejs/node#66871 ships` lines (and their marker) go from every
  app at once when the Node fix lands.

`tests/check-drift.test.sh` tests the checker against fixture apps made from the live template.
