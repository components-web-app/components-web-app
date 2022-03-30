#!/bin/sh
set -e

if [ "$NODE_ENV" = 'production' ]; then
  yarn run start
else
  apk add --no-cache \
    git \
    python3 \
    make \
    g++

  ln -sf python3 /usr/bin/python
  yarn install
  yarn run dev
fi
