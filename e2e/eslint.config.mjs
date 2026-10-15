// Lints the browser tests (#157) in the module's style (@nuxt/eslint-config, stylistic), plus Playwright's rules.
import { createConfigForNuxt } from '@nuxt/eslint-config/flat'
import playwright from 'eslint-plugin-playwright'

export default createConfigForNuxt({ features: { stylistic: true } })
  .append(
    {
      ...playwright.configs['flat/recommended'],
      files: ['tests/**/*.ts'],
      rules: {
        ...playwright.configs['flat/recommended'].rules,
        // Recommended warns on these; a warning doesn't fail the job, so they're errors here.
        'playwright/expect-expect': 'error',
        'playwright/missing-playwright-await': 'error',
        'playwright/no-wait-for-timeout': 'error',
        'playwright/no-force-option': 'error',
        'playwright/no-focused-test': 'error',
        'playwright/no-skipped-test': 'error',
        'playwright/prefer-web-first-assertions': 'error',
        'playwright/no-element-handle': 'error',
        'playwright/no-eval': 'error',
        'playwright/no-page-pause': 'error',
        'playwright/no-useless-await': 'error',
        'playwright/prefer-to-have-count': 'error',
        'playwright/prefer-to-have-length': 'error',
      },
    },
    {
      // A missing await on our own helpers too (logIn, publish), which Playwright's rule can't see.
      files: ['**/*.ts'],
      languageOptions: { parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname } },
      rules: {
        '@typescript-eslint/no-floating-promises': 'error',
        '@typescript-eslint/no-misused-promises': 'error',
        '@typescript-eslint/await-thenable': 'error',
      },
    },
  )
