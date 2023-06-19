#!/bin/sh
set -e

if [ "$NODE_ENV" = 'production' ]; then
  node .output/server/index.mjs
else
  pnpm install
  pnpm run dev-ssl
fi
