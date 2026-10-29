# workflows

Reusable GitHub Actions workflows for basmith7's own apps. Public so that public and private
repos can both call them; there is nothing secret here. Not accepting contributions.

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
