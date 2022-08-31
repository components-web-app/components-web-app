module.exports = {
  root: true,
  env: {
    browser: true,
    node: true
  },
  extends: [
    '@nuxtjs/eslint-config-typescript',
    'prettier',
    'plugin:vue/recommended',
    'plugin:prettier/recommended',
    'plugin:nuxt/recommended'
  ],
  plugins: [],
  // add your custom rules here
  rules: {
    'vue/multi-word-component-names': 0
  }
}
