import type { APIRequestContext, Page } from '@playwright/test'
import { expect, hydrationFinished, isHydrated, test } from './fixtures'

const locs = (xml: string) => [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(([, loc]) => loc!)

// Every page the sitemap lists, as an anonymous visitor would see it.
async function sitemapPaths(request: APIRequestContext) {
  const sitemaps = locs(await (await request.get('/sitemap.xml')).text())
  const urls: string[] = []
  for (const sitemap of sitemaps.filter(url => url.endsWith('.xml'))) {
    urls.push(...locs(await (await request.get(new URL(sitemap).pathname)).text()))
  }
  urls.push(...sitemaps.filter(url => !url.endsWith('.xml')))
  return [...new Set(urls.map(url => new URL(url).pathname))]
}

// Sends the Nuxt app's router to a path, as a click on a link to it would.
async function navigateInApp(page: Page, path: string) {
  await page.evaluate(async (to) => {
    const root = document.querySelector<HTMLElement & { __vue_app__?: { config: { globalProperties: { $router: { push: (to: string) => Promise<unknown> } } } } }>('#__nuxt')
    await root?.__vue_app__?.config.globalProperties.$router.push(to)
  }, path)
}

test('every sitemap page renders and hydrates', async ({ page, request }) => {
  const paths = await sitemapPaths(request)
  expect(paths.length, 'pages in the sitemap').toBeGreaterThan(0)
  for (const path of paths) {
    const response = await page.goto(path)
    expect(response?.status(), path).toBe(200)
    await isHydrated(page)
    await expect(page.locator('main, #__nuxt').first(), path).not.toBeEmpty()
  }
})

test('a public page is served from the cache on its second request', async ({ request }) => {
  const [path] = await sitemapPaths(request)
  const headers = { 'Accept': 'text/html', 'Accept-Encoding': 'gzip' }
  await request.get(path!, { headers })
  const second = await request.get(path!, { headers })
  expect(second.status()).toBe(200)
  expect(second.headers()['cache-status'] ?? '').toContain('hit')
})

test('the loading bar shows while a CWA page loads after a client-side navigation', async ({ page, request }) => {
  const [from, to] = await sitemapPaths(request)
  expect(to, 'a second page in the sitemap').toBeTruthy()
  await page.goto(from!)
  await hydrationFinished(page)
  // Slows the API so the CWA page load outlasts the indicator's throttle (cwa-nuxt-module#396).
  await page.route('**/_api/**', async (route) => {
    await new Promise(resolve => setTimeout(resolve, 800))
    await route.continue()
  })
  const bar = page.locator('.nuxt-loading-indicator')
  const navigated = navigateInApp(page, to!)
  await expect(bar).toHaveCSS('opacity', '1')
  await navigated
  await expect(bar).toHaveCSS('opacity', '0')
})

test('a page\'s OG image renders', async ({ request }) => {
  const [path] = await sitemapPaths(request)
  const html = await (await request.get(path!, { headers: { Accept: 'text/html' } })).text()
  const url = html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/)?.[1]?.replaceAll('&amp;', '&')
  expect(url, 'og:image').toBeTruthy()
  // Signed URLs fail with a 500 when NUXT_APP_SECRET is missing (nuxt-og-image 7).
  const image = await request.get(new URL(url!).pathname)
  expect(image.status()).toBe(200)
  expect(image.headers()['content-type']).toContain('image/png')
})
