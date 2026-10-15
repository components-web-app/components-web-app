import { expect, isHydrated, test } from './fixtures'

// Every page the sitemap lists, as an anonymous visitor would see it.
async function sitemapPaths(request: import('@playwright/test').APIRequestContext) {
  const index = await (await request.get('/sitemap.xml')).text()
  const sitemaps = [...index.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1])
  const urls: string[] = []
  for (const sitemap of sitemaps.filter(url => url.endsWith('.xml'))) {
    const xml = await (await request.get(new URL(sitemap).pathname)).text()
    urls.push(...[...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1]))
  }
  urls.push(...sitemaps.filter(url => !url.endsWith('.xml')))
  return [...new Set(urls.map(url => new URL(url).pathname))]
}

test('every sitemap page renders and hydrates', async ({ page, request }) => {
  const paths = await sitemapPaths(request)
  expect(paths.length, 'pages in the sitemap').toBeGreaterThan(3)
  for (const path of paths) {
    const response = await page.goto(path)
    expect(response?.status(), path).toBe(200)
    await isHydrated(page)
    await expect(page.locator('main, #__nuxt').first(), path).not.toBeEmpty()
  }
})

test('a public page is served from the cache on its second request', async ({ request }) => {
  const headers = { Accept: 'text/html', 'Accept-Encoding': 'gzip' }
  await request.get('/blog-articles', { headers })
  const second = await request.get('/blog-articles', { headers })
  expect(second.status()).toBe(200)
  expect(second.headers()['cache-status'] ?? '').toContain('hit')
})

test('a redirecting route answers with a 308 before rendering its target', async ({ request }) => {
  const response = await request.get('/topic-1', { maxRedirects: 0, headers: { Accept: 'text/html' } })
  expect(response.status()).toBe(308)
  expect(response.headers().location).toMatch(/\/topic-1\/chapter-one$/)
})

test('the loading bar shows while a CWA page loads after a client-side navigation', async ({ page }) => {
  await page.goto('/')
  await isHydrated(page)
  // Nuxt ignores the indicator until hydration has finished, which is after the app mounts.
  await page.waitForFunction(() => (document.querySelector('#__nuxt') as HTMLElement & { __vue_app__?: { $nuxt: { isHydrating?: boolean } } })
    .__vue_app__?.$nuxt.isHydrating === false)
  // Slows the API so the CWA page load outlasts the indicator's throttle (cwa-nuxt-module#396).
  await page.route('**/_api/**', async (route) => {
    await new Promise(resolve => setTimeout(resolve, 800))
    await route.continue()
  })
  await page.locator('header a[href="/blog-articles"]').first().click()
  await page.waitForFunction(() => {
    const bar = document.querySelector<HTMLElement>('.nuxt-loading-indicator')
    return !!bar && getComputedStyle(bar).opacity === '1'
  })
  await page.waitForURL('**/blog-articles')
  await page.waitForFunction(() => getComputedStyle(document.querySelector<HTMLElement>('.nuxt-loading-indicator')!).opacity === '0')
})

test('a page\'s OG image renders', async ({ request }) => {
  const html = await (await request.get('/blog-articles', { headers: { Accept: 'text/html' } })).text()
  const url = html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/)?.[1]?.replaceAll('&amp;', '&')
  expect(url, 'og:image').toBeTruthy()
  // Signed URLs fail with a 500 when NUXT_APP_SECRET is missing (nuxt-og-image 7).
  const image = await request.get(new URL(url!).pathname)
  expect(image.status()).toBe(200)
  expect(image.headers()['content-type']).toContain('image/png')
})
