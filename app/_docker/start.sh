#!/bin/sh
set -e

if [ "$NODE_ENV" = 'production' ]; then
  node .output/server/index.mjs
else
  apk update && apk add --no-cache libc6-compat
  corepack enable && corepack prepare pnpm@8.5.1 --activate
  pnpm install
  pnpm run dev-ssl
fi
