const { createResolver } = require('@nuxt/kit')

const { resolve } = createResolver(import.meta.url)

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    resolve('nuxt.config.ts'),
    resolve('components/**/*.{js,vue,ts}'),
    resolve('layouts/**/*.{js,vue,ts}'),
    resolve('pages/**/*.{js,vue,ts}'),
    resolve('cwa/**/*.{js,vue,ts}')
  ],
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography')
  ],
  corePlugins: {
    preflight: true
  },
  theme: {
    extend: {
      colors: {
        'primary': '#999A77',
        'background': '#12212B',
        'text-default': '#FFFFFF'
      },
      typography: (theme) => ({
        DEFAULT: {
          css: {
            color: theme('colors.white'),
            h1: {
              color: theme('colors.primary')
            },
            h2: {
              color: theme('colors.primary')
            },
            h3: {
              color: theme('colors.primary')
            },
            h4: {
              color: theme('colors.primary')
            },
            strong: {
              color: theme('colors.current')
            },
            a: {
              color: theme('colors.primary'),
              '&:hover': {
                color: theme('colors.white'),
              },
            },
          },
        },
      })
    }
  }
}
