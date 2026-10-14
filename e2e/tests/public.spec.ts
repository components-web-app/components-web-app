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
