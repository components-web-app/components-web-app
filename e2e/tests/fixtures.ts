import { expect, test as base, type Page } from '@playwright/test'

// Statuses that mean the front end and API disagree about a write (method, Accept or Content-Type).
const BROKEN_WRITE_STATUSES = [405, 406, 415]

// What a test reads from the Nuxt app the page mounted on #__nuxt.
type NuxtRoot = HTMLElement & { __vue_app__?: { $nuxt: { isHydrating?: boolean } } }

// Fails a page's test on an API write the API refused as mismatched, or on an uncaught error (#157).
async function watchPage(page: Page, use: (page: Page) => Promise<void>) {
  const brokenWrites: string[] = []
  page.on('response', (response) => {
    const request = response.request()
    if (request.method() !== 'GET' && request.method() !== 'HEAD' && new URL(response.url()).pathname.startsWith('/_api')
      && BROKEN_WRITE_STATUSES.includes(response.status())) {
      brokenWrites.push(`${request.method()} ${response.url()} → ${response.status()}`)
    }
  })
  const pageErrors: string[] = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await use(page)
  expect(brokenWrites, 'API writes the API refused as a mismatched request').toEqual([])
  expect(pageErrors, 'uncaught errors in the page').toEqual([])
}

export const test = base.extend<{ page: Page, visitor: Page }>({
  page: async ({ page }, use) => watchPage(page, use),
  // An anonymous visitor in its own browser context, beside a signed-in `page`; closed after the test.
  visitor: async ({ browser }, use) => {
    const context = await browser.newContext()
    await watchPage(await context.newPage(), use)
    await context.close()
  },
})

export { expect }

export const adminPassword = () => {
  const password = process.env.E2E_ADMIN_PASSWORD
  if (!password) throw new Error('E2E_ADMIN_PASSWORD is not set')
  return password
}

export async function logIn(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Username or Email').fill('admin')
  await page.getByLabel('Password', { exact: true }).fill(adminPassword())
  await Promise.all([
    page.waitForURL(url => !url.pathname.startsWith('/login')),
    page.getByRole('button', { name: 'Sign In' }).click(),
  ])
  await expect(page.getByRole('button', { name: 'Edit' })).toBeVisible()
}

export async function isHydrated(page: Page) {
  await page.waitForFunction(() => !!document.querySelector<NuxtRoot>('#__nuxt')?.__vue_app__)
}

// Nuxt ignores the loading indicator until hydration has finished, which is after the app mounts.
export async function hydrationFinished(page: Page) {
  await page.waitForFunction(() => document.querySelector<NuxtRoot>('#__nuxt')?.__vue_app__?.$nuxt.isHydrating === false)
}
