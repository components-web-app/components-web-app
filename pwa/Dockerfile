ARG NODE_VERSION=14.4

FROM node:${NODE_VERSION}-alpine AS cwa_pwa

# Cookie Secret environment required to build nuxt application
# Other environment variables needed but are fine to include as build args as they would not be secret.

RUN apk add --no-cache \
  git \
  python \
  make \
  g++

WORKDIR /usr/src/pwa

COPY package.json yarn.* ./
RUN yarn install --network-timeout 60000

COPY . ./

EXPOSE 3000

COPY _docker/start.sh /usr/local/bin/start
RUN chmod +x /usr/local/bin/start
CMD ["start"]
