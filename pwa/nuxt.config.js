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
        cert: fs.readFileSync(path.resolve(CERT_DIR + '/localhost.crt'))
      }

const cwaNuxtModuleName = 'nuxt-module-next'

export default {
  server: {
    host: '0.0.0.0',
    https
  },
  publicRuntimeConfig: {
    API_URL,
    API_URL_BROWSER
  },
  typescript: {
    typeCheck: {
      eslint: true
    }
  },
  head: {
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' }
    ]
  },
  css: ['~/assets/sass/main.sass'],
  buildModules: [
    '@nuxt/typescript-build'
    // Doc: https://github.com/nuxt-community/stylelint-module
    // too many issues and not the nicest style lint handling. Many issues with the quill sass and with multiple style blocks and differing languages in a SFC
    // '@nuxtjs/stylelint-module',
  ],
  modules: ['@nuxtjs/pwa', `@cwa/${cwaNuxtModuleName}`],
  plugins: [
    { src: '~/plugins/axios', mode: 'server' },
    { src: '~/plugins/quill', mode: 'client' }
  ],
  serverMiddleware: ['~/server-middleware/headers'],
  router: {
    middleware: ['auth', 'routeLoader']
  },
  render: {
    csp: {
      reportOnly: false,
      hashAlgorithm: 'sha256',
      policies: {
        'default-src': ["'self'"],
        'img-src': ['https:', '*.google-analytics.com', 'data:'],
        'worker-src': ["'self'", `blob:`],
        'style-src': ["'self'", "'unsafe-inline'"],
        'script-src': [
          "'self'",
          "'unsafe-inline'",
          // for realtime compiling of html component ... is this a security concern?
          // the content should only be editable by admin... but what if the admin is hacked...
          // do we need to consider this as a weakness?
          "'unsafe-eval'",
          '*.google-analytics.com'
        ],
        'connect-src': [
          "'self'",
          API_URL_BROWSER,
          MERCURE_SUBSCRIBE_URL,
          '*.google-analytics.com'
        ],
        'form-action': ["'self'"],
        'frame-ancestors': ["'none'"],
        'object-src': ["'none'"],
        'base-uri': []
      }
    }
  },
  // we are not using the correct node module name yet, awaiting resolution to cwa namespace being available or not
  alias: {
    '@cwa/nuxt-module': join(
      __dirname,
      `node_modules/@cwa/${cwaNuxtModuleName}/dist`
    )
  },
  styleResources: {
    sass: ['~/assets/sass/vars/*.sass']
  },
  cwa: {
    websiteName: 'CWA Demo Site'
  },
  loading: {
    color: '#E30A6C'
  },
  build: {
    extend(config) {
      // required for HTML component to convert anchor links to cwa-nuxt-link components
      // enables runtime compiler
      config.resolve.alias.vue = 'vue/dist/vue.common'
    }
  }
}
