import type { Locator, Page } from '@playwright/test'
import { expect, isHydrated, logIn, test } from './fixtures'

// The element over a component takes the click that selects it; the component's own content may not.
async function selectComponent(page: Page, content: Locator) {
  await content.evaluate(element => element.scrollIntoView({ block: 'center' }))
  const box = await content.boundingBox()
  if (!box) throw new Error('component not visible')
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2)
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

test('an admin can edit and publish a text component, and visitors see it', async ({ page, visitor }) => {
  const marker = `E2E text ${Date.now()}`
  await logIn(page)
  await page.goto('/')
  await page.getByRole('button', { name: 'Edit' }).click()
  await page.locator('article').first().click()

  const editor = page.locator('[contenteditable=true]').first()
  await editor.click()
  await page.keyboard.press('Control+End')
  // Publishes straight after the last keystroke: Publish must send the waiting save first (cwa-nuxt-module#394).
  await page.keyboard.type(` ${marker}`)
  await publish(page)

  await visitor.goto('/')
  await isHydrated(visitor)
  await expect(visitor.getByText(marker).first()).toBeVisible()
})

test('an admin can upload and publish an image, and visitors see it', async ({ page, visitor }) => {
  await logIn(page)
  await page.goto('/')
  await page.getByRole('button', { name: 'Edit' }).click()
  await selectComponent(page, page.getByText('No Image').first())

  const uploaded = page.waitForResponse(r => r.request().method() !== 'GET' && r.url().includes('/_api/component/images/') && r.ok())
  await page.locator('input[type=file]').setInputFiles('tests/assets/sample.png')
  await uploaded
  await expect(page.getByText('No Image')).toHaveCount(0)
  await publish(page)

  // The image loads from storage, under the app's path prefix (#166), with real pixels.
  await visitor.goto('/')
  await isHydrated(visitor)
  const image = visitor.locator('img[src*="/cwa-e2e/review/e2e/"]').first()
  await expect(image).toBeVisible()
  await expect.poll(() => image.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth)).toBeGreaterThan(0)
})
