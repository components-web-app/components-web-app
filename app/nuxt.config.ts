import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'node:path'
import { execSync } from 'node:child_process'

export default defineNuxtConfig({
  hooks: process.env.LOAD_FIXTURES === 'true' ? {
    listen() {
      const { existsSync } = require('node:fs')
      if (existsSync('/.dockerenv')) {
        console.log('[fixtures] Skipping — running inside Docker container')
        return
      }
      const root = resolve(__dirname, '..')
      console.log('[fixtures] Loading...')
      execSync('docker compose exec -T php bin/console doctrine:fixtures:load --no-interaction', { stdio: 'inherit', cwd: root })
      console.log('[fixtures] Purging Souin cache...')
      execSync('curl -sf -X DELETE http://localhost:2019/souin -H "Content-Type: application/json" -d \'{"regex":".*"}\' || true', { stdio: 'pipe', cwd: root })
      console.log('[fixtures] Done.')
    },
  } : {},
  compatibilityDate: '2025-06-18',
  app: {
    head: {
      charset: 'utf-8',
      htmlAttrs: {
        lang: 'en-GB',
        class: 'bg-black'
      }
    },
    pageTransition: { name: 'page', mode: 'out-in' },
  },
  css: [
    '~/assets/css/tailwind.css',
  ],
  cwa: {
    resources: {
      Title: {
        name: 'Title',
        description: '<p>A simple title component for page headings.</p>'
      },
      // @cwa-if:navigation
      NavigationLink: {
        name: 'Link',
        description: '<p>Use this component to display a link for a website user to click so they can visit another page or URL</p>'
      },
      // @cwa-end:navigation
      // @cwa-if:html-content
      HtmlContent: {
        name: 'Body Text',
        description: '<p>Easily create a body of text with the ability to style and format the content using themes in-keeping with your website.</p>'
      },
      // @cwa-end:html-content
      // @cwa-if:image
      Image: {
        instantAdd: true
      },
      // @cwa-end:image
      // @cwa-if:forms
      ExampleForm: {
        name: 'Example Form',
        description: '<p>Demonstrates all Symfony form field types using the CWA form composables.</p>'
      },
      // @cwa-end:forms
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
      },
      // @cwa-if:nested-pages
      NestedTopicTemplate: {
        name: 'Nested Topic Page'
      },
      NestedSubPageTemplate: {
        name: 'Nested Sub-Page'
      },
      // @cwa-end:nested-pages
    },
    pageData: {
      // @cwa-if:blog
      BlogArticleData: {
        name: 'Blog Articles',
        properties: {
          image: 'Hero Image',
          htmlContent: 'Article Body'
        }
      },
      // @cwa-end:blog
      // @cwa-if:nested-pages
      NestedPageData: {
        name: 'Nested Topics',
        properties: {
          introContent: 'Introduction Content'
        }
      },
      // @cwa-end:nested-pages
    },
    siteConfig: {
      siteName: 'CWA Preview Web App',
    }
  },
  devtools: {
    enabled: true
  },
  extends: [
    './node_modules/@cwa/nuxt/dist/layer'
  ],
  modules: [
    '@nuxt/ui',
    // @cwa-if:image
    '@nuxt/image',
    // @cwa-end:image
    '@vite-pwa/nuxt',
    'nuxt-svgo'
  ],
  runtimeConfig: {
    public: {
      cwa: {
        apiUrl: '',
        apiUrlBrowser: ''
      }
    }
  },
  typescript: {
    typeCheck: true,
    strict: false
  },
  pwa: {
    // 'prompt', not 'autoUpdate': CWA admins edit inline, and an auto-updating SW
    // can swap assets mid-edit. Applying the update needs a small UI wired to
    // usePWA() (gated on $cwa.admin.isEditing) — not built yet, tracked as a
    // follow-up. Until then updates simply wait rather than apply silently.
    registerType: 'prompt',
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
      // Presence of this key (not its value) disables navigation interception in
      // the PROD build, so SSR navigations are not served the app shell. Do not
      // remove it. (In dev the plugin coalesces null -> '/', but devOptions is
      // disabled below so the dev SW never runs.)
      navigateFallback: null,
      cleanupOutdatedCaches: true,
      sourcemap: true,
      globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2,webp,jpg,jpeg}'],
      runtimeCaching: [
        {
          // Anchored to the /_api content paths (see the module's resource-utils.ts
          // endpoint map). Must match every content endpoint or offline layout
          // breaks; must NOT be broadened to all of /_api or it swallows the
          // Mercure SSE stream and /me. If the module adds a resource type, add it.
          urlPattern: ({ url }) => /\/_api\/(?:_\/(?:routes|resource_manifest|pages|layouts|component_groups|component_positions)|page_data|component)\b/.test(url.pathname),
          // Cache is only ever read offline; online the network always wins.
          handler: 'NetworkFirst',
          options: {
            cacheName: 'cwa-api',
            networkTimeoutSeconds: 3,
            plugins: [{
              // The authoritative gate: api-components-bundle #200 marks an
              // authenticated GET of an affected resource `private, no-store`, so
              // the SW cache only ever holds public (published) data.
              cacheWillUpdate: async ({ response }) => {
                const cc = response.headers.get('cache-control') || ''
                if (/no-store|private/.test(cc)) return null
                return response.status === 200 ? response : null
              },
            }],
            expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 },
          },
        },
      ]
    },
    client: {
      installPrompt: true,
    },
    // Do not run the service worker in dev: a SW intercepting requests during
    // development is a common source of confusing issues (it was the reason PWA
    // was previously parked), and it avoids the dev-only navigateFallback coalesce.
    devOptions: {
      enabled: false,
    }
  },
  svgo: {
    autoImportPath: './assets/svg/',
  },
  vite: {
    plugins: [
      tailwindcss(),
    ],
    server: {
      watch: {
        ignored: ['!**/node_modules/@cwa/**'],
        followSymlinks: true
      }
    },
    optimizeDeps: {
      include: [
        '@vue/devtools-kit',
        '@vue/devtools-core',
        'workbox-window'
      ]
    }
  },
  vue: {
    compilerOptions: {
      comments: true,
    },
  },
  sitemap: {
    debug: true,
    sitemaps: {
      'test-static': {
        sources: [
          '/api/sitemap-urls',
        ]
      }
    }
  },
  site: {
    url: import.meta.dev ? 'https://localhost' : undefined,
  }
})
