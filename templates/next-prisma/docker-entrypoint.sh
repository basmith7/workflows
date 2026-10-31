#!/bin/sh
# Canonical Next+Prisma entrypoint: basmith7/workflows templates/next-prisma. Keep this file a
# copy of the template; mark app-only lines with `# app:` and check with `check-drift <repo-dir>`.
set -e

# Run the app's own binaries (prisma, and tsx for a seed) rather than npx, which can fall back
# to a network install. So `prisma` must be a runtime dependency.
export PATH="/app/node_modules/.bin:$PATH"

# Idempotent: safe on every container start.
prisma migrate deploy
# SEED_ON_START=1 (an app's Dockerfile or compose) also runs the seed configured in
# prisma.config.ts on every start, so that seed must be idempotent.
if [ "${SEED_ON_START:-0}" = 1 ]; then prisma db seed; fi

exec "$@"
