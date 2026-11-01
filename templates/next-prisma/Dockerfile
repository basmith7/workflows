# syntax=docker/dockerfile:1
# Canonical Next+Prisma image: basmith7/workflows templates/next-prisma. Keep this file a copy
# of the template; mark app-only lines with `# app:` and check with `check-drift <repo-dir>`.
FROM node:24-alpine AS base
WORKDIR /app
# python3/make/g++ compile better-sqlite3's native addon for this image's
# platform - it can't be reused from a host build.
RUN apk add --no-cache python3 make g++
COPY package*.json .npmrc ./

# Both installs read @basmith7 packages from GitHub Packages with the optional npm_token
# secret (build-image.yml's `npm-token: true`); the token never reaches a layer. Without the
# secret the token is empty, which npm ignores for public packages.
# Production-only install: this is what actually ships in the runtime image.
# Keeps typescript/eslint/tailwindcss out of it.
FROM base AS deps
RUN --mount=type=secret,id=npm_token,env=NPM_TOKEN \
    echo "//npm.pkg.github.com/:_authToken=$NPM_TOKEN" > /root/.npmrc && npm ci --omit=dev && rm /root/.npmrc

# Full install (needs typescript etc. for `next build`'s type-checking).
FROM base AS builder
RUN --mount=type=secret,id=npm_token,env=NPM_TOKEN \
    echo "//npm.pkg.github.com/:_authToken=$NPM_TOKEN" > /root/.npmrc && npm ci && rm /root/.npmrc
COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:24-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/src ./src
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
COPY --from=builder /app/tsconfig.json ./tsconfig.json

COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["npx", "next", "start", "-H", "0.0.0.0"]
