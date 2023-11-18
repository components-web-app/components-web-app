// https://nuxt.com/docs/api/configuration/nuxt-config
import { defineNuxtConfig } from 'nuxt/config'

const API_URL = process.env.API_URL || 'https://localhost:8443'
const API_URL_BROWSER = process.env.API_URL_BROWSER || API_URL

export default defineNuxtConfig({
  app: {
    head: {
      titleTemplate: '%s - CWA Demo',
      charset: 'utf-8',
      htmlAttrs: {
        lang: 'en-GB'
      }
    }
  },
  extends: [
    './node_modules/@cwa/nuxt3-next/dist/layer'
  ],
  modules: [
    '@cwa/nuxt3-next',
    '@nuxtjs/tailwindcss',
    '@nuxt/image',
    '@vite-pwa/nuxt'
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
      base: true
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
  },
  routeRules: {
    '/': { prerender: true },
    '/**': { isr: 30 }
  },
  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'CWA',
      short_name: 'CWA',
      theme_color: '#212121',
      icons: [
        {
          src: 'pwa-192x192.png',
          sizes: '192x192',
          type: 'image/png'
        },
        {
          src: 'pwa-512x512.png',
          sizes: '512x512',
          type: 'image/png'
        },
        {
          src: 'pwa-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'any maskable'
        }
      ]
    },
    workbox: {
      navigateFallback: null,
      globPatterns: ['**/*.{js,mjs,ts,json,css,html,png,svg,ico,jpg,jpeg,webp}']
    },
    client: {
      // installPrompt: true,
      // you don't need to include this: only for testing purposes
      // if enabling periodic sync for update use 1 hour or so (periodicSyncForUpdates: 3600)
      // periodicSyncForUpdates: 20,
    },
    devOptions: {
      enabled: true,
      suppressWarnings: true,
      navigateFallbackAllowlist: [/^\/$/],
      type: 'module'
    }
  }
  // typescript: {
  //   typeCheck: true,
  //   strict: true
  // }
})
