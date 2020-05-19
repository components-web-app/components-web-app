import fs from 'fs'
import path from 'path'

const https = process.env.NODE_ENV === 'production' ? {} : {
  key: fs.readFileSync(path.resolve('/certs/localhost.key')),
  cert: fs.readFileSync(path.resolve('/certs/localhost.crt'))
}

export default {
  mode: 'universal',
  buildModules: [
    '@nuxt/typescript-build'
  ],
  modules: [
    '@nuxtjs/axios',
    '@nuxtjs/auth-next',
    '@cwamodules/cwa-next'
  ],
  router: {
    middleware: ['routeLoader']
  },
  typescript: {
    typeCheck: {
      eslint: true
    }
  },
  server: {
    host: '0.0.0.0',
    https
  }
}
