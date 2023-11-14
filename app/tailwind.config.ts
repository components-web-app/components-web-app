import type { Config } from 'tailwindcss'

export default {
  content: [
    'cwa/**/*.{js,vue,ts}'
  ],
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography')
  ],
  corePlugins: {
    preflight: false
  }
} as Config
