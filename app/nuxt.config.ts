// https://nuxt.com/docs/api/configuration/nuxt-config
import { defineNuxtConfig } from 'nuxt/config'

export default defineNuxtConfig({
  runtimeConfig: {
    public: {
      cwa: {
        apiUrl: '',
        apiUrlBrowser: ''
      }
    }
  },
  app: {
    head: {
      titleTemplate: '%s - CWA Preview',
      charset: 'utf-8',
      htmlAttrs: {
        lang: 'en-GB',
        class: 'bg-black'
      },
      bodyAttrs: {
        class: 'bg-background'
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
    '@vite-pwa/nuxt',
    'nuxt-svgo'
  ],
  devtools: {
    enabled: true
  },
  cwa: {
    appName: 'CWA Preview Web App',
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
    layouts: {
      Primary: {
        name: 'Primary Layout',
        classes: {
          'Blue Background': ['bg-blue-600']
        }
      }
    },
    pages: {
      PrimaryPageTemplate: {
        name: 'Primary Page',
        classes: {
          'Big Text': ['text-2xl']
        }
      }
    },
    pageData: {
      BlogArticleData: {
        name: 'Blog Articles'
      }
    },
    tailwind: {
      base: false
    }
  },
  typescript: {
    typeCheck: true,
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
  routeRules: {
    // '/': { prerender: true },
    // '/**': { isr: 30 }
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
        // {
        //   urlPattern: new RegExp(`^${escapeStringRegexp(API_URL_BROWSER)}\/.*`, 'i'),
        //   handler: 'NetworkFirst',
        //   options: {
        //     cacheName: 'web-app-api',
        //     expiration: {
        //       maxEntries: 10000,
        //       maxAgeSeconds: 60 * 60 * 24 * 30 // <== 30 days
        //     },
        //     cacheableResponse: {
        //       statuses: [0, 200]
        //     }
        //   }
        // },
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
  svgo: {
    autoImportPath: './assets/svg/',
  },
  // typescript: {
  //   typeCheck: true,
  //   strict: true
  // },
  // behind caddy so we have this so we can predictably forward hmr sockets
  vite: {
    server: {
      hmr: {
        protocol: "wss",
        clientPort: 443,
        path: "hmr/",
      },
    },
  },


})
