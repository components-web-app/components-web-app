ARG NODE_VERSION=16
ARG PNPM_VERSION=8.4.0

FROM node:${NODE_VERSION}-alpine AS cwa_app_builder

WORKDIR /usr/src/app

RUN apk update && \
    apk add --no-cache libc6-compat
RUN corepack enable && \
    corepack prepare pnpm@8.5.1 --activate

# Files required by pnpm install
COPY .npmrc package.json pnpm-*.yaml ./

# If you patched any package, include patches before install too
#COPY patches patches

RUN pnpm install

COPY . .

RUN pnpm build

RUN pnpm install --frozen-lockfile --prod

FROM node:${NODE_VERSION}-alpine AS cwa_app

WORKDIR /usr/src/app

COPY --from=cwa_app_builder /usr/src/app  .

ENV HOST 0.0.0.0
EXPOSE 3000
EXPOSE 24678

COPY _docker/start.sh /usr/local/bin/start
RUN chmod +x /usr/local/bin/start
CMD ["start"]
