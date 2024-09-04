const {createResolver} = require("@nuxt/kit");

const { resolve } = createResolver(import.meta.url)

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    resolve('nuxt.config.ts'),
    resolve('components/**/*.{js,vue,ts}'),
    resolve('cwa/**/*.{js,vue,ts}')
  ],
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography')
  ],
  corePlugins: {
    preflight: false
  }
}
