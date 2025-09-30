import type { SitemapUrlInput } from '#sitemap/types'

export default defineSitemapEventHandler(() => {
  const sitemapUrls: SitemapUrlInput[] = []

  sitemapUrls.push(
    {
      loc: '/does-not-exist-just-a-test',
    }
  )

  return sitemapUrls
})
