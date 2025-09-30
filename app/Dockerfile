ARG NODE_VERSION=22

# Versions
FROM node:${NODE_VERSION}-alpine AS node_upstream

# Base stage for dev and build
FROM node_upstream AS base

ARG PNPM_VERSION=10.17.1

# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
# hadolint ignore=DL3018
RUN apk update && \
    apk add --no-cache libc6-compat git

WORKDIR /srv/app

RUN corepack enable && \
    corepack prepare pnpm@${PNPM_VERSION} --activate && \
    pnpm config -g set store-dir /.pnpm-store

# Development image
FROM base AS dev

ENV HOST 0.0.0.0
ENV PORT 3000
EXPOSE 3000
EXPOSE 24678

CMD ["sh", "-c", "pnpm install; pnpm dev"]


FROM base AS builder

ARG CI

COPY --link .npmrc package.json pnpm-*.yaml ./
RUN pnpm fetch

COPY --link . .

RUN	pnpm install --frozen-lockfile --offline && \
    pnpm run build


# Production image, copy all the files and run next
FROM node_upstream AS prod

WORKDIR /srv/app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs; \
	adduser --system --uid 1001 nuxtjs

# Set the correct permission for prerender cache
RUN mkdir .output; \
	chown nuxtjs:nodejs .output

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --link --chown=1001:1001 /srv/app/.output ./

USER nuxtjs

EXPOSE 3000
ENV PORT=3000
ENV HOST="0.0.0.0"

CMD ["node", "server/index.mjs"]
