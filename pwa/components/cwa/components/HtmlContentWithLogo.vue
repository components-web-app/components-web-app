<template>
  <div :class="['html-component', resource.uiClassNames]">
    <cwa-logo class="cwa-logo" />
    <!-- eslint-disable-next-line vue/no-v-html -->
    <div v-if="!editing" v-html="displayHtml" />
    <quill-input
      v-else
      :iri="iri"
      field="html"
      notification-category="components-manager"
      @hide="editing = false"
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
