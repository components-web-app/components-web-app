<template>
  <div>
    <resource-component-loader v-bind="resourceComponentLoaderProps" />
    <client-only>
      <context-menu />
    </client-only>
  </div>
</template>

<script>
  // if you want to use nuxt functions specific to pages such
  // as asyncData and middleware extend the page template
  import Page from '@cwa/nuxt-module/core/templates/page'

  export default {
    extends: Page
  }
</script>
