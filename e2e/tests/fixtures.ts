import { expect, test as base, type Page } from '@playwright/test'

// Statuses that mean the front end and API disagree about a write (method, Accept or Content-Type).
const BROKEN_WRITE_STATUSES = [405, 406, 415]

export const test = base.extend<{ page: Page }>({
  // Fails any test whose API write gets a 405, 406 or 415, even if the UI hides it (#157).
  page: async ({ page }, use) => {
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
  await page.locator('input[name=username]').fill('admin')
  await page.locator('input[name=password]').fill(adminPassword())
  await Promise.all([
    page.waitForURL(url => !url.pathname.startsWith('/login')),
    page.getByRole('button', { name: 'Sign In' }).click(),
  ])
  await expect(page.getByRole('button', { name: 'Edit' })).toBeVisible()
}

export async function isHydrated(page: Page) {
  return page.waitForFunction(() => !!(document.querySelector('#__nuxt') as HTMLElement & { __vue_app__?: unknown })?.__vue_app__)
}
