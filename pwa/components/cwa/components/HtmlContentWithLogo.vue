<template>
  <div
    :class="[
      'html-component',
      resource.uiClassNames,
      { 'has-error': !!fieldNotifications.html.length }
    ]"
  >
    <cwa-logo class="cwa-logo" />
    <div class="content">
      <div v-if="!cmValue('showEditor')" class="cwa-html-content">
        <component
          :is="htmlComponent"
          v-bind="$props"
          class="cwa-html-content"
        ></component>
      </div>
      <quill-input
        v-else
        :iri="iri"
        field="html"
        notification-category="components-manager"
      />
    </div>
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
  .content
    margin: 0
  .cwa-logo
    max-width: 100%
</style>
