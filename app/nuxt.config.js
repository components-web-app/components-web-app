import fs from 'fs'
import path, { join } from 'path'

const API_URL_BROWSER = process.env.API_URL_BROWSER || 'https://localhost:8443'
const API_URL = process.env.API_URL || API_URL_BROWSER
const CERT_DIR = process.env.CERT_DIR || '/certs'
const MERCURE_SUBSCRIBE_URL =
  process.env.MERCURE_SUBSCRIBE_URL || 'https://localhost:1337'

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
  css: ['~/assets/sass/main.sass'],
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
    // too many issues and not the nicest style lint handling. Many issues with the quill sass and with multiple style blocks and differing languages in a SFC
    // '@nuxtjs/stylelint-module',
  ],
  modules: [
    '@nuxtjs/style-resources',
    '@nuxtjs/axios',
    '@nuxtjs/auth-next',
    '@nuxtjs/pwa',
    '@cwa/nuxt-module-next',
  ],
  plugins: [
    { src: '~/plugins/axios', mode: 'server' },
    { src: '~/plugins/quill', ssr: false },
  ],
  router: {
    middleware: ['auth', 'routeLoader'],
  },
  render: {
    csp: {
      reportOnly: false,
      hashAlgorithm: 'sha256',
      policies: {
        'default-src': ["'self'"],
        'img-src': ['https:', '*.google-analytics.com'],
        'worker-src': ["'self'", `blob:`],
        'style-src': ["'self'", "'unsafe-inline'"],
        'script-src': ["'self'", "'unsafe-inline'", '*.google-analytics.com'],
        'connect-src': [
          "'self'",
          API_URL_BROWSER,
          MERCURE_SUBSCRIBE_URL,
          '*.google-analytics.com',
        ],
        'form-action': ["'self'"],
        'frame-ancestors': ["'none'"],
        'object-src': ["'none'"],
        'base-uri': [],
      },
    },
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
      'node_modules/@cwa/nuxt-module-next/dist'
    ),
  },
  styleResources: {
    sass: ['~/assets/sass/vars/*.sass'],
  },
}
