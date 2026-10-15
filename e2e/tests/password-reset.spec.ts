import type { APIRequestContext } from '@playwright/test'
import { adminPassword, expect, logIn, test } from './fixtures'

const mailpit = process.env.E2E_MAILPIT_URL ?? 'http://mailpit:8025'

// The parts of Mailpit's API responses the test reads.
type MailpitSearch = { messages?: { ID: string }[] }
type MailpitMessage = { HTML?: string, Text?: string }

// Waits for the newest email to `to` and returns the first link to `path` in it.
async function linkInEmail(request: APIRequestContext, to: string, path: string) {
  let link: string | undefined
  await expect.poll(async () => {
    const { messages }: MailpitSearch = await (await request.get(`${mailpit}/api/v1/search?query=${encodeURIComponent(`to:${to}`)}`)).json()
    const newest = messages?.[0]
    if (!newest) return undefined
    const message: MailpitMessage = await (await request.get(`${mailpit}/api/v1/message/${newest.ID}`)).json()
    link = `${message.HTML ?? ''} ${message.Text ?? ''}`.match(new RegExp(`https?://[^"'\\s<>]+${path}[^"'\\s<>]*`))?.[0]
    return link
  }, { message: `an email to ${to} linking to ${path}`, timeout: 30_000 }).toBeTruthy()
  return link!.replace(/&amp;/g, '&')
}

test('a password reset email links to a working reset page', async ({ page, request }) => {
  await page.goto('/forgot-password')
  await page.getByLabel('Username or Email').fill('admin')
  await page.getByRole('button', { name: 'Reset Password' }).click()

  const link = await linkInEmail(request, 'admin@cwa.test', '/reset-password/')
  const response = await page.goto(new URL(link).pathname + new URL(link).search)
  expect(response?.status()).toBe(200)

  // Set the same password again, so the rest of the run can still log in, then log in with it.
  await page.getByLabel('Enter new password').fill(adminPassword())
  await page.getByLabel('Repeat new password').fill(adminPassword())
  const reset = page.waitForResponse(r => r.request().method() !== 'GET' && r.url().includes('/_api/') && r.status() < 500)
  await page.getByRole('button', { name: 'Reset Password' }).click()
  expect((await reset).ok()).toBe(true)
  await logIn(page)
})
