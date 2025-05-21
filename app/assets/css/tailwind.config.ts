import type { Config } from 'tailwindcss'

export default {
  theme: {
    extend: {
      typography: () => ({
        primary: {
          css: {
            '--tw-prose-body': 'var(--color-stone-700)',
            '--tw-prose-headings': 'var(--color-stone-900)',
            '--tw-prose-lead': 'var(--color-stone-600)',
            '--tw-prose-links': 'var(--color-stone-900)',
            '--tw-prose-bold': 'var(--color-stone-900)',
            '--tw-prose-counters': 'var(--color-stone-500)',
            '--tw-prose-bullets': 'var(--color-stone-300)',
            '--tw-prose-hr': 'var(--color-stone-200)',
            '--tw-prose-quotes': 'var(--color-stone-900)',
            '--tw-prose-quote-borders': 'var(--color-stone-200)',
            '--tw-prose-captions': 'var(--color-stone-500)',
            '--tw-prose-code': 'var(--color-stone-900)',
            '--tw-prose-pre-code': 'var(--color-stone-200)',
            '--tw-prose-pre-bg': 'var(--color-stone-800)',
            '--tw-prose-th-borders': 'var(--color-stone-300)',
            '--tw-prose-td-borders': 'var(--color-stone-200)',
            '--tw-prose-invert-body': 'var(--color-text-default)',
            '--tw-prose-invert-headings': 'var(--color-primary)',
            '--tw-prose-invert-lead': 'var(--color-stone-400)',
            '--tw-prose-invert-links': 'var(--color-primary)',
            '--tw-prose-invert-bold': 'var(--color-white)',
            '--tw-prose-invert-counters': 'var(--color-stone-400)',
            '--tw-prose-invert-bullets': 'var(--color-stone-600)',
            '--tw-prose-invert-hr': 'var(--color-primary)',
            '--tw-prose-invert-quotes': 'var(--color-stone-100)',
            '--tw-prose-invert-quote-borders': 'var(--color-stone-700)',
            '--tw-prose-invert-captions': 'var(--color-stone-400)',
            '--tw-prose-invert-code': 'var(--color-white)',
            '--tw-prose-invert-pre-code': 'var(--color-stone-300)',
            '--tw-prose-invert-pre-bg': 'rgb(0 0 0 / 50%)',
            '--tw-prose-invert-th-borders': 'var(--color-stone-600)',
            '--tw-prose-invert-td-borders': 'var(--color-stone-700)',
          },
        },
      }),
    },
  },
} as Config
