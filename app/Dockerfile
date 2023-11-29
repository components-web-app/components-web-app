ARG NODE_VERSION=18
FROM node:${NODE_VERSION}-alpine AS cwa_app

WORKDIR /usr/src/app

ARG PNPM_VERSION=8.11.0

RUN apk update && \
    apk add --no-cache libc6-compat
RUN corepack enable && \
    corepack prepare pnpm@${PNPM_VERSION} --activate

# Files required by pnpm install
COPY .npmrc package.json pnpm-*.yaml ./

# If you patched any package, include patches before install too
#COPY patches patches

RUN pnpm install --frozen-lockfile

COPY . .

RUN pnpm run build

ENV HOST 0.0.0.0
EXPOSE 3000
EXPOSE 24678

RUN find . ! -name '.output' -type f -exec rm -f {} +

COPY _docker/start.sh /usr/local/bin/start
RUN chmod +x /usr/local/bin/start
CMD ["start"]
