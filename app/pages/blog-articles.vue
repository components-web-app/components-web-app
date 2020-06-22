<template>
  <div>
    <h4>Home route loaded in asyncData:</h4>
    <pre>{{ homeRoute }}</pre>
    <resource-component-loader v-bind="resourceComponentLoaderProps" />
  </div>
</template>

<script>
// if you want to use nuxt functions specific to pages such
// as asyncData and middleware extend the page template
import Page from '@cwa/nuxt-module/core/templates/page'

export default {
  extends: Page,
  async asyncData ({ $axios }) {
    const { data } = await $axios.get('/_/routes//')
    return {
      homeRoute: data
    }
  }
}
</script>
