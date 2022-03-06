<template>
  <div
    :class="[
      'html-component',
      resource.uiClassNames,
      { 'has-error': !!fieldNotifications.html.length }
    ]"
  >
    <cwa-logo class="cwa-logo" />
    <component
      :is="htmlComponent"
      v-if="!cmValue('showEditor')"
      v-bind="$props"
      class="cwa-html-content"
    ></component>
    <quill-input
      v-else
      :iri="iri"
      field="html"
      notification-category="components-manager"
    />
  </div>
</template>

<script>
import CwaLogo from '@cwa/nuxt-module/core/templates/components/utils/cwa-logo.vue'
import HtmlContent from './HtmlContent'
export default {
  components: { CwaLogo },
  mixins: [HtmlContent]
}
</script>

<style lang="sass">
.html-component
  .cwa-logo
    max-width: 100%
</style>
