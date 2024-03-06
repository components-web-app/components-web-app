// https://nuxt.com/docs/api/configuration/nuxt-config
import { defineNuxtConfig } from 'nuxt/config'
import escapeStringRegexp from "escape-string-regexp";
import {createResolver} from "@nuxt/kit";

const API_URL = process.env.API_URL || 'https://localhost:8443'
const API_URL_BROWSER = process.env.API_URL_BROWSER || API_URL

const { resolve } = createResolver(import.meta.url)

export default defineNuxtConfig({
  app: {
    head: {
      titleTemplate: '%s - CWA Preview',
      charset: 'utf-8',
      htmlAttrs: {
        lang: 'en-GB',
        class: 'bg-blue-400'
      },
      bodyAttrs: {
        class: 'bg-white'
      }
    }
  },
  extends: [
    './node_modules/@cwa/nuxt/dist/layer'
  ],
  modules: [
    '@cwa/nuxt',
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
        name: 'Link',
        description: '<p>Use this component to display a link for a website user to click so they can visit another page or URL</p>'
      },
      HtmlContent: {
        name: 'Body Text',
        description: '<p>Easily create a body of text with the ability to style and format the content using themes in-keeping with your website.</p>'
      },
      Image: {
        instantAdd: true
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
    'lodash/isEqual.js': 'lodash/isEqual.js',
    'lodash/isArray.js': 'lodash/isArray.js',
    'lodash/mergeWith.js': 'lodash/mergeWith.js'
  },
  routeRules: {
    // '/': { prerender: true },
    '/**': { isr: 300 }
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
      // navigateFallback: '/',
      globPatterns: ['**/*.{js,mjs,ts,json,css,html,png,svg,ico,jpg,jpeg,webp,woff2}'],
      runtimeCaching: [
        {
          urlPattern: new RegExp(`^${escapeStringRegexp(API_URL_BROWSER)}\/.*`, 'i'),
          handler: 'NetworkFirst',
          options: {
            cacheName: 'web-app-api',
            expiration: {
              maxEntries: 10000,
              maxAgeSeconds: 60 * 60 * 24 * 30 // <== 30 days
            },
            cacheableResponse: {
              statuses: [0, 200]
            }
          }
        },
        // {
        //   urlPattern: /^https:\/\/res.cloudinary\.com\/dxt7m8fqi\/image\/upload\/v1700228271\/.*/i,
        //   handler: 'StaleWhileRevalidate',
        //   options: {
        //     cacheName: 'cloudinary-uploads',
        //     expiration: {
        //       maxEntries: 100,
        //       maxAgeSeconds: 60 * 60 * 24 * 30 // <== 30 days
        //     },
        //     cacheableResponse: {
        //       statuses: [0, 200]
        //     }
        //   }
        // }
      ]
    },
    client: {
      installPrompt: true,
      // you don't need to include this: only for testing purposes
      // if enabling periodic sync for update use 1 hour or so (periodicSyncForUpdates: 3600)
      // periodicSyncForUpdates: 20,
    },
    devOptions: {
      enabled: true,
      suppressWarnings: true,
      // navigateFallbackAllowlist: [/^\/$/],
      type: 'module'
    }
  },
  tailwindcss: {
    config: {
      content: [
        resolve('nuxt.config.ts'),
        resolve('cwa/**/*.{js,vue,ts}')
      ],
      plugins: [
        require('@tailwindcss/forms'),
        require('@tailwindcss/typography')
      ],
      corePlugins: {
        preflight: false
      }
    }
  }
  // typescript: {
  //   typeCheck: true,
  //   strict: true
  // }
})
