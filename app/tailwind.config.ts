import { fileURLToPath } from 'url'

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    fileURLToPath(new URL('./cwa/**/*.{js,vue,ts}', import.meta.url))
  ],
  plugins: [
    require('@tailwindcss/forms')
  ],
  corePlugins: {
    preflight: false
  }
}
