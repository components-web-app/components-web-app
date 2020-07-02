import fs from 'fs'
import path, { join } from 'path'

const API_URL_BROWSER = process.env.API_URL_BROWSER || 'https://localhost:8443'
const API_URL = process.env.API_URL || API_URL_BROWSER
const CERT_DIR = process.env.CERT_DIR || '/certs'

const https =
  process.env.NODE_ENV === 'production' && process.env.LOCAL_TLS !== '1'
    ? {}
    : {
        key: fs.readFileSync(path.resolve(CERT_DIR + '/localhost.key')),
        cert: fs.readFileSync(path.resolve(CERT_DIR + '/localhost.crt')),
      }

export default {
  mode: 'universal',
  server: {
    host: '0.0.0.0',
    https,
  },
  serverMiddleware: ['~/server-middleware/headers'],
  publicRuntimeConfig: {
    API_URL,
    API_URL_BROWSER,
  },
  typescript: {
    typeCheck: {
      eslint: true,
    },
  },
  buildModules: [
    '@nuxt/typescript-build',
    // Doc: https://github.com/nuxt-community/stylelint-module
    '@nuxtjs/stylelint-module',
  ],
  modules: [
    '@nuxtjs/axios',
    '@nuxtjs/auth-next',
    '@nuxtjs/pwa',
    '@cwamodules/cwa-next',
  ],
  plugins: [{ src: '~/plugins/axios', mode: 'server' }],
  router: {
    middleware: ['auth', 'routeLoader'],
  },
  axios: {
    credentials: true,
    progress: false,
  },
  auth: {
    redirect: {
      login: '/login',
      logout: '/login',
      home: '/',
      callback: false,
    },
    strategies: {
      local: {
        user: {
          autoFetch: true,
          property: '',
        },
        endpoints: {
          login: { url: '/login', method: 'post' },
          logout: { url: '/logout', method: 'post' },
          user: { url: '/me', method: 'get' },
        },
        token: {
          global: false,
          required: false,
        },
      },
    },
  },
  // we are not using the correct node module name yet, awaiting resolution to cwa namespace being available or not
  alias: {
    '@cwa/nuxt-module': join(
      __dirname,
      'node_modules/@cwamodules/cwa-next/dist'
    ),
  },
}
