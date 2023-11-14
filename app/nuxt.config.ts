// https://nuxt.com/docs/api/configuration/nuxt-config
import { defineNuxtConfig } from 'nuxt/config'

const API_URL = process.env.API_URL || 'https://localhost:8443'
const API_URL_BROWSER = process.env.API_URL_BROWSER || API_URL

export default defineNuxtConfig({
  extends: [
    './node_modules/@cwa/nuxt3-next/dist/layer'
  ],
  modules: [
    '@cwa/nuxt3-next',
    '@nuxtjs/tailwindcss',
    '@nuxt/image'
  ],
  devtools: {
    enabled: true
  },
  cwa: {
    apiUrl: API_URL,
    apiUrlBrowser: API_URL_BROWSER,
    resources: {
      NavigationLink: {
        name: 'Link'
      },
      HtmlContent: {
        name: 'Body Text'
      }
    },
    tailwind: {
      base: false
    }
  },
  typescript: {
    tsConfig: {
      include: [
        '../src'
      ],
      exclude: [
        '../**/*.spec.ts',
        '../**/*.test.ts'
      ]
    }
  },
  alias: {
    'lodash/isEqual.js': 'lodash/isEqual.js'
  }
})
