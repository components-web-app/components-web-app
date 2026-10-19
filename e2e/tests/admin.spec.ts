import { expect, logIn, test } from './fixtures'

test('an admin can log in and out', async ({ page }) => {
  await logIn(page)
  await page.locator('a', { hasText: 'Menu' }).first().click()
  await page.getByRole('link', { name: 'Sign out' }).click()
  await expect(page.getByRole('button', { name: 'Edit' })).toHaveCount(0)
  await page.goto('/login')
  await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible()
})
