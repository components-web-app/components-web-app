import { fileURLToPath } from 'url'

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    'cwa/**/*.{js,vue,ts}'
  ],
  plugins: [
    require('@tailwindcss/forms')
  ],
  corePlugins: {
    preflight: false
  }
}
