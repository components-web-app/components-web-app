ARG NODE_VERSION=lts

FROM node:${NODE_VERSION}-alpine AS cwa_pwa_builder

# Cookie Secret environment required to build nuxt application
# Other environment variables needed but are fine to include as build args as they would not be secret.

RUN apk add --no-cache \
  git \
  python3 \
  make \
  g++

RUN ln -sf python3 /usr/bin/python

WORKDIR /usr/src/pwa

COPY . .

RUN yarn install \
  --prefer-offline \
  --frozen-lockfile \
  --non-interactive \
  --production=false \
  --network-timeout 60000

RUN yarn build

RUN rm -rf node_modules && \
  NODE_ENV=production yarn install \
  --prefer-offline \
  --pure-lockfile \
  --non-interactive \
  --production=true

FROM node:${NODE_VERSION}-alpine AS cwa_pwa

WORKDIR /usr/src/pwa

COPY --from=cwa_pwa_builder /usr/src/pwa  .

ENV HOST 0.0.0.0
EXPOSE 3000

COPY _docker/start.sh /usr/local/bin/start
RUN chmod +x /usr/local/bin/start
CMD ["start"]
