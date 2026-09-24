import tailwindcss from '@tailwindcss/vite'

// Chunks only admins need: the TipTap editor and the /_cwa admin pages. `isAdminOnlySource`
// is for the service worker's precache only (`pwa.workbox.manifestTransforms`), which would
// otherwise fetch them all in the background after a visitor's first page load. The module
// already keeps admin chunks out of the prefetch hints (cwa-nuxt-module#329, #336), but it
// ships no service worker, so this precache rule stays here. The editor is template code,
// so its prefetch filter (below) stays too. Chunk files are named by hash, so `globIgnores`
// can't select them; the build manifest maps them to sources.
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
  // Dev-only workaround for #95, a bug in @unhead/bundler 3.4.1. nuxt-seo-utils
  // registers unhead's Vite plugin, and its DevTools part adds a runtime import in
  // `configResolved` with no de-duplication. Nuxt's dev server calls that twice
  // (separate client and SSR Vite servers sharing one plugin instance), so
  // `unhead.client.js` declares `__unhead_devtoolsPlugin` twice and the app
  // never hydrates. This turns off
  // only unhead's own DevTools panel; Nuxt DevTools, the useSeoMeta transform and
  // the production build are unchanged (the plugin is `apply: 'serve'`). Remove
  // once an unhead release de-duplicates the registration.
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
    // HtmlContent loads the TipTap editor only when an admin starts editing
    // (cwa-nuxt-module#332). Nuxt would still send a prefetch hint for that chunk
    // (about 400 KB of TipTap and ProseMirror) on every page with body text, so
    // visitors would download it anyway. Leaving it out of `dynamicImports` drops
    // only the hint: the editor still loads on demand when it is first shown.
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
  pwa: {
    // 'prompt', not 'autoUpdate': CWA admins edit inline, and an auto-updating SW
    // can swap assets mid-edit. With 'prompt' a new worker waits, and
    // app/plugins/pwa-update.client.ts applies it silently on the next page
    // navigation, holding it back while $cwa.admin.isEditing is true. There is
    // no notice for visitors to act on (#73).
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
      // Required for the update prompt to finish. Applying an update posts
      // SKIP_WAITING, and the page reloads only when the new worker takes
      // control. A page the old worker controlled is handed over automatically,
      // but a page with no controller (the first load that registered the worker,
      // or a Shift-reload) is never claimed without this, so Reload spun forever.
      // Safe with registerType 'prompt': clientsClaim runs on activation, and
      // activation still waits for the user (#73).
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
            // 4 hours, deliberately short. The no-store gate above is what keeps
            // authenticated data out of this cache. The one window it cannot close,
            // a cache filled while signed in outliving the session on a shared
            // device, is closed by @cwa/nuxt: when a session ends (sign-out, or a
            // 401 while signed in) it deletes this cache, because
            // cwa.auth.clearCachesOnSessionEnd defaults to ['cwa-api'] whenever
            // @vite-pwa/nuxt is installed (cwa-nuxt-module#293). Rename this cache
            // and that option has to follow. The short expiry is now only a
            // backstop for that purge.
            expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 4 },
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
  site: {
    url: import.meta.dev ? 'https://localhost' : undefined,
  }
})
