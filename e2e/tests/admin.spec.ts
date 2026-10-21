import { expect, logIn, test } from './fixtures'

test('an admin can log in and out', async ({ page }) => {
  await logIn(page)
  await page.locator('a', { hasText: 'Menu' }).first().click()
  await page.getByRole('link', { name: 'Sign out' }).click()
  await expect(page.getByRole('button', { name: 'Edit' })).toHaveCount(0)
  await page.goto('/login')
  await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible()
})

// The login cookie is SameSite=Strict: a link from another site loads the page without it, then the app signs in again.
test('an admin arriving from another site is still signed in', async ({ page, baseURL }) => {
  await logIn(page)
  const loginCookie = (await page.context().cookies()).find(cookie => cookie.name === 'api_component')
  expect(loginCookie?.sameSite, 'the login cookie').toBe('Strict')
  const site = new URL(baseURL!)
  await page.route('https://elsewhere.test/', route => route.fulfill({
    contentType: 'text/html',
    body: `<a href="${site.origin}/">Back to the site</a>`,
  }))
  await page.goto('https://elsewhere.test/')
  await Promise.all([
    page.waitForURL(url => url.origin === site.origin),
    page.getByRole('link', { name: 'Back to the site' }).click(),
  ])
  await expect(page.getByRole('button', { name: 'Edit' })).toBeVisible()
})
