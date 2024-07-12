const {createResolver} = require("@nuxt/kit");

const { resolve } = createResolver(import.meta.url)

/** @type {import('tailwindcss').Config} */
module.exports = {
  config: {
    content: [
      resolve('nuxt.config.ts'),
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
}
