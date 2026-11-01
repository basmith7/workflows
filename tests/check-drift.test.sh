#!/usr/bin/env bash
# shellcheck disable=SC2016  # the fixture lines are literal shell, not expanded here
# Test for templates/next-prisma/check-drift: fixture app dirs built from the live template, so
# the fixtures follow the template as it changes.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
TPL=$root/templates/next-prisma
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

# app <name>: a fresh fixture dir holding exact copies of the template's two files
app() {
  mkdir "$T/$1"
  cp "$TPL/Dockerfile" "$TPL/docker-entrypoint.sh" "$T/$1/"
  echo "$T/$1"
}

# fail <name> <why> <output>: count a failure and show check-drift's output indented
fail() {
  echo "FAIL $1: $2"
  while IFS= read -r l; do echo "  | $l"; done <<<"$3"
  fails=$((fails + 1))
}

# expect <exit> <name> [grep pattern the output must contain]
expect() {
  local out rc
  out=$("$TPL/check-drift" "$T/$2" 2>&1)
  rc=$?
  if [ "$rc" -ne "$1" ]; then
    fail "$2" "exit $rc, want $1" "$out"
  elif [ -n "${3:-}" ] && ! grep -qF -- "$3" <<<"$out"; then
    fail "$2" "output lacks '$3'" "$out"
  else
    echo "PASS $2"
  fi
}

# insert_before <file> <existing line> <text>: put <text> (may be multi-line) before that line
insert_before() {
  awk -v at="$2" -v text="$3" '$0 == at && !done { print text; done = 1 } { print }
    END { exit !done }' "$1" >"$1.new" || { echo "FAIL fixture: no line '$2' in $1"; exit 1; }
  mv "$1.new" "$1"
}

app copy >/dev/null
expect 0 copy

d=$(app marked)
insert_before "$d/Dockerfile" 'EXPOSE 3000' $'# app: curl for the entrypoint loops\nRUN apk add --no-cache curl\n'
insert_before "$d/docker-entrypoint.sh" 'exec "$@"' $'# app: refresh loop\n(\n  while true; do sleep 900; done\n) &\n'
insert_before "$d/docker-entrypoint.sh" 'exec "$@"' $'  # app: an indented marker works too\n  export FOO=1\n'
expect 0 marked

d=$(app dropped)
grep -vxF 'COPY --from=builder /app/public ./public' "$TPL/Dockerfile" >"$d/Dockerfile"
insert_before "$d/Dockerfile" 'COPY docker-entrypoint.sh ./' '# app: -COPY --from=builder /app/public ./public'
expect 0 dropped

d=$(app unmarked)
insert_before "$d/Dockerfile" 'EXPOSE 3000' 'RUN apk add --no-cache curl'
expect 1 unmarked '+RUN apk add --no-cache curl'

d=$(app changed)
sed -i -E 's/^FROM node:[0-9]+-alpine AS runner$/FROM node:0-alpine AS runner/' "$d/Dockerfile"
expect 1 changed '+FROM node:0-alpine AS runner'

d=$(app missing-line)
grep -vxF 'COPY --from=builder /app/public ./public' "$TPL/Dockerfile" >"$d/Dockerfile"
expect 1 missing-line '-COPY --from=builder /app/public ./public'

d=$(app stale-drop)
insert_before "$d/Dockerfile" 'EXPOSE 3000' '# app: -COPY --from=builder /app/nope ./nope'
expect 1 stale-drop "drops lines the template doesn't have"

d=$(app swallowing) # a block with no blank line after it eats template lines: drift, never a pass
insert_before "$d/Dockerfile" 'COPY --from=builder /app/src ./src' '# app: scripts'
expect 1 swallowing '-COPY --from=builder /app/src ./src'

d=$(app no-entrypoint)
mv "$d/docker-entrypoint.sh" "$d/entrypoint.sh"
expect 1 no-entrypoint 'docker-entrypoint.sh is missing'

"$TPL/check-drift" "$T/does-not-exist" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then echo "PASS bad-dir"; else fail bad-dir "exit $rc, want 2" ""; fi

if [ "$fails" -ne 0 ]; then echo "$fails failed"; exit 1; fi
echo "all passed"
