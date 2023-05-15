// https://nuxt.com/docs/api/configuration/nuxt-config
import { defineNuxtConfig } from 'nuxt/config'
import {fileURLToPath} from "url";

const API_URL = process.env.API_URL || 'https://localhost:8443'
const API_URL_BROWSER = process.env.API_URL_BROWSER || API_URL

export default defineNuxtConfig({
  extends: [
    fileURLToPath(new URL('./node_modules/@cwa/nuxt3-next/dist/layer/nuxt.config.ts', import.meta.url))
  ],
  modules: [
    '@nuxtjs/tailwindcss',
    '@kevinmarrec/nuxt-pwa',
    '@nuxt/image-edge',
    '@nuxt/devtools',
    'nuxt-vitest'
  ],
  cwa: {
    apiUrl: API_URL,
    apiUrlBrowser: API_URL_BROWSER
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
  pwa: {}
})
