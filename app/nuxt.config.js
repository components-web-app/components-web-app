import fs from 'fs'
import path, {join} from 'path'
import TsconfigPathsPlugin from 'tsconfig-paths-webpack-plugin'

const API_URL_BROWSER = process.env.API_URL_BROWSER || 'https://localhost:8443'
const API_URL = process.env.API_URL || API_URL_BROWSER

const https = process.env.NODE_ENV === 'production' ? {} : {
  key: fs.readFileSync(path.resolve('/certs/localhost.key')),
  cert: fs.readFileSync(path.resolve('/certs/localhost.crt'))
}

export default {
  mode: 'universal',
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
  buildModules: [
    '@nuxt/typescript-build'
  ],
  modules: [
    '@nuxtjs/axios',
    '@nuxtjs/auth-next',
    '@cwamodules/cwa-next'
  ],
  plugins: [
    '~/plugins/axios'
  ],
  router: {
    middleware: ['auth', 'routeLoader']
  },
  axios: {
    credentials: true,
    progress: false
  },
  auth: {
    redirect: {
      login: '/login',
      logout: '/login',
      home: '/',
      callback: false
    },
    strategies: {
      local: {
        user: {
          autoFetch: true,
          property: ''
        },
        endpoints: {
          login: { url: '/login', method: 'post' },
          logout: { url: '/logout', method: 'post' },
          user: { url: '/me', method: 'get' }
        },
        token: {
          global: false,
          required: false
        }
      }
    }
  },
  build: {
    extend (config, _) {
      if (!config.resolve) {
        config.resolve = {}
      }
      if (!config.resolve.plugins) {
        config.resolve.plugins = []
      }

      // fix for alias in tsconfig.js
      config.resolve.plugins.push(new TsconfigPathsPlugin({ configFile: `${__dirname}/tsconfig.json` }))

      // fix for using fs import in axios plugin
      if (!config.node) {
        config.node = {}
      }
      config.node.fs = "empty"
    }
  },
  // we are not using the correct node module name yet, awaiting resolution to cwa namespace being available or not
  alias: {
    '@cwa/nuxt-module': join(__dirname, 'node_modules/@cwamodules/cwa-next/dist')
  }
}
