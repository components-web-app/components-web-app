import { adminPassword, expect, logIn, test } from './fixtures'

const mailpit = process.env.E2E_MAILPIT_URL ?? 'http://mailpit:8025'

// Waits for the newest email to `to` and returns the first link to `path` in it.
async function linkInEmail(request: import('@playwright/test').APIRequestContext, to: string, path: string) {
  let link: string | undefined
  await expect.poll(async () => {
    const { messages } = await (await request.get(`${mailpit}/api/v1/search?query=${encodeURIComponent(`to:${to}`)}`)).json()
    if (!messages?.length) return undefined
    const message = await (await request.get(`${mailpit}/api/v1/message/${messages[0].ID}`)).json()
    link = `${message.HTML ?? ''} ${message.Text ?? ''}`.match(new RegExp(`https?://[^"'\\s<>]+${path}[^"'\\s<>]*`))?.[0]
    return link
  }, { message: `an email to ${to} linking to ${path}`, timeout: 30_000 }).toBeTruthy()
  return link!.replace(/&amp;/g, '&')
}

test('a password reset email links to a working reset page', async ({ page, request }) => {
  await page.goto('/forgot-password')
  await page.locator('input[name=username]').fill('admin')
  await page.getByRole('button', { name: 'Reset Password' }).click()

  const link = await linkInEmail(request, 'admin@cwa.test', '/reset-password/')
  const response = await page.goto(new URL(link).pathname + new URL(link).search)
  expect(response?.status()).toBe(200)

  // Set the same password again, so the rest of the run can still log in, then log in with it.
  const passwords = page.locator('input[type=password]')
  await expect(passwords).toHaveCount(2)
  await passwords.nth(0).fill(adminPassword())
  await passwords.nth(1).fill(adminPassword())
  const reset = page.waitForResponse(r => r.request().method() !== 'GET' && r.url().includes('/_api/') && r.status() < 500)
  await page.getByRole('button', { name: /reset|save|update|change/i }).first().click()
  expect((await reset).ok()).toBe(true)
  await logIn(page)
})
