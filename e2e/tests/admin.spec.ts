import type { Browser, Locator, Page } from '@playwright/test'
import { expect, isHydrated, logIn, test } from './fixtures'

async function visitorPage(browser: Browser, path: string) {
  const page = await (await browser.newContext({ ignoreHTTPSErrors: true })).newPage()
  await page.goto(path)
  await isHydrated(page)
  return page
}

// The element over a component takes the click that selects it; the component's own content may not.
async function selectComponent(page: Page, content: Locator) {
  await content.evaluate(element => element.scrollIntoView({ block: 'center' }))
  const box = await content.boundingBox()
  if (!box) throw new Error('component not visible')
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2)
}

// Resolves once no API write has been in flight for a second: typing saves on each pause.
// Tracks the requests themselves, so a write already in flight when it starts can't unbalance it.
async function savesSettled(page: Page) {
  const inFlight = new Set<import('@playwright/test').Request>()
  let last = Date.now()
  const isWrite = (r: import('@playwright/test').Request) => r.method() !== 'GET' && r.url().includes('/_api/')
  page.on('request', r => { if (isWrite(r)) { inFlight.add(r); last = Date.now() } })
  const done = (r: import('@playwright/test').Request) => { if (inFlight.delete(r)) last = Date.now() }
  page.on('requestfinished', done)
  page.on('requestfailed', done)
  return async () => expect.poll(() => inFlight.size === 0 && Date.now() - last > 1000, { timeout: 20_000 }).toBe(true)
}

async function publish(page: Page) {
  const published = page.waitForResponse(r => r.request().method() !== 'GET' && r.url().includes('/_api/') && r.ok())
  // The manager's action button, after its tab of the same name.
  await page.getByRole('button', { name: 'Publish' }).last().click()
  await published
}

test('an admin can log in and out', async ({ page }) => {
  await logIn(page)
  await page.locator('a', { hasText: 'Menu' }).first().click()
  await page.getByRole('link', { name: 'Sign out' }).click()
  await expect(page.getByRole('button', { name: 'Edit' })).toHaveCount(0)
  await page.goto('/login')
  await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible()
})

test('an admin can edit and publish a text component, and visitors see it', async ({ page, browser }) => {
  const marker = `E2E text ${Date.now()}`
  await logIn(page)
  await page.goto('/')
  await page.getByRole('button', { name: 'Edit' }).click()
  await page.locator('article').first().click()

  const editor = page.locator('[contenteditable=true]').first()
  await editor.click()
  await page.keyboard.press('Control+End')
  const settled = await savesSettled(page)
  const saved = page.waitForResponse(r => r.request().method() === 'PATCH' && r.url().includes('/_api/component/html_contents/') && r.ok())
  await page.keyboard.type(` ${marker}`)
  await saved
  await settled()
  await publish(page)

  const visitor = await visitorPage(browser, '/')
  await expect(visitor.getByText(marker).first()).toBeVisible()
})

test('an admin can upload and publish an image, and visitors see it', async ({ page, browser }) => {
  await logIn(page)
  await page.goto('/')
  await page.getByRole('button', { name: 'Edit' }).click()
  await selectComponent(page, page.getByText('No Image').first())

  const uploaded = page.waitForResponse(r => r.request().method() !== 'GET' && r.url().includes('/_api/component/images/') && r.ok())
  await page.locator('input[type=file]').setInputFiles('tests/assets/sample.png')
  await uploaded
  await expect(page.getByText('No Image')).toHaveCount(0)
  await publish(page)

  // The image loads from storage for a visitor: it has real pixels, not a broken or empty element.
  const visitor = await visitorPage(browser, '/')
  const image = visitor.locator('main img, article img, img[src*="cwa-e2e"]').first()
  await expect(image).toBeVisible()
  await expect.poll(() => image.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth)).toBeGreaterThan(0)
})
