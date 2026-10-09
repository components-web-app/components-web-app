import tailwindcss from '@tailwindcss/vite'

// Admin-only chunks (the TipTap editor, /_cwa pages), kept out of the SW precache by source via the build manifest,
// as hashed names defeat globIgnores. The module keeps them out of prefetch hints but ships no service worker.
const isEditorSource = (id: string) => id.endsWith('components/TipTapHtmlEditor.vue')
const isAdminOnlySource = (id: string) => isEditorSource(id) || id.includes('/pages/_cwa/')
const adminOnlyFiles = new Set<string>()
const basename = (path: string) => path.split('/').pop() ?? path
type ManifestChunk = { file: string, isEntry?: boolean, isDynamicEntry?: boolean, imports?: string[], css?: string[] }
const collectAdminOnlyFiles = (manifest: Record<string, ManifestChunk>) => {
  const reach = (roots: string[]) => {
    const seen = new Set<string>()
    const files = new Set<string>()
    const visit = (id: string) => {
      const chunk = manifest[id]
      if (!chunk || seen.has(id)) {
        return
      }
      seen.add(id)
      // Basenames: the manifest's paths and the precache URLs have different prefixes.
      files.add(basename(chunk.file))
      chunk.css?.forEach(file => files.add(basename(file)))
      chunk.imports?.forEach(visit)
    }
    roots.forEach(visit)
    return files
  }
  const roots = Object.keys(manifest).filter(id => manifest[id]?.isEntry || manifest[id]?.isDynamicEntry)
  // A file shared with anything a visitor can load stays precached.
  const shared = reach(roots.filter(id => !isAdminOnlySource(id)))
  adminOnlyFiles.clear()
  for (const file of reach(roots.filter(isAdminOnlySource))) {
    if (!shared.has(file)) {
      adminOnlyFiles.add(file)
    }
  }
}

export default defineNuxtConfig({
  compatibilityDate: '2025-06-18',
  app: {
    head: {
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
  // Dev-only workaround for #95: @unhead/bundler registers its DevTools plugin twice and the app never hydrates.
  // Remove once an unhead release de-duplicates the registration.
  unhead: {
    vite: {
      devtools: false
    }
  },
  extends: [
    // By package name, not a path into node_modules: Node resolves it through the real
    // path, so pnpm's symlink doesn't defeat Nuxt's page-prefetch filter (nuxt/nuxt#36401,
    // #92). Needs a @cwa/nuxt build with the `./layer` export (6c33a6e or later).
    '@cwa/nuxt/layer'
  ],
  modules: [
    '@nuxt/ui',
    // @cwa-if:image
    '@nuxt/image',
    // @cwa-end:image
    '@vite-pwa/nuxt',
    'nuxt-svgo',
    // Drops the lazy editor's prefetch hint from every page; it still loads on demand (cwa-nuxt-module#332).
    (_options, nuxt) => {
      nuxt.hook('build:manifest', (manifest) => {
        collectAdminOnlyFiles(manifest)
        for (const chunk of Object.values(manifest)) {
          chunk.dynamicImports = chunk.dynamicImports?.filter(id => !isEditorSource(id))
        }
      })
    },
  ],
  typescript: {
    typeCheck: true,
    strict: false
  },
  nitro: {
    // Precompressed .br/.gz for /_nuxt, served by Accept-Encoding; php's Caddy passes them through. Don't remove (#117).
    compressPublicAssets: { brotli: true, gzip: true },
  },
  pwa: {
    // 'prompt': a new worker waits, and plugins/pwa-update.client.ts applies it on the next navigation unless editing (#73).
    registerType: 'prompt',
    // Sends sw.js and the manifest `public, max-age=0, must-revalidate`, so a CDN never serves an old worker.
    registerWebManifestInRouteRules: true,
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
      // Must be present (even null), or the prod build serves the app shell for every SSR navigation. Don't remove.
      navigateFallback: null,
      // Required for updates: a page with no controller is otherwise never claimed and never reloads (#73).
      // Safe with 'prompt': activation still waits for SKIP_WAITING.
      clientsClaim: true,
      cleanupOutdatedCaches: true,
      // Leaves the admin-only chunks collected in `build:manifest` out of the precache.
      manifestTransforms: [
        async (entries) => ({
          manifest: entries.filter(entry => !adminOnlyFiles.has(basename(entry.url))),
          warnings: []
        })
      ],
      sourcemap: true,
      globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2,webp,jpg,jpeg}'],
      runtimeCaching: [
        {
          // Anchored and exhaustive: a missing content type breaks offline rendering, and all of /_api would swallow
          // the Mercure stream and /me. Add any new module resource type.
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
              cacheWillUpdate: async ({ response }) => /no-store|private/.test(response.headers.get('cache-control') || '') || response.status !== 200 ? null : response,
            }],
            // A backstop: the no-store gate keeps authenticated data out, and @cwa/nuxt deletes this cache when a session
            // ends (cwa-nuxt-module#293). Renaming it means setting cwa.auth.clearCachesOnSessionEnd to match.
            expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 4 },
          },
        },
      ]
    },
    client: {
      installPrompt: true,
    },
    // No service worker in dev: it confuses development, and dev coalesces navigateFallback to '/'.
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
  site: {
    url: import.meta.dev ? 'https://localhost' : undefined,
  }
})
