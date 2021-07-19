<template>
  <div :class="['html-component', resource.uiClassNames]">
    <!-- eslint-disable-next-line vue/no-v-html -->
    <div v-if="!cmValue('showEditor')" v-html="displayHtml" />
    <quill-input
      v-else
      :iri="iri"
      field="html"
      notification-category="components-manager"
    />
  </div>
</template>

<script lang="ts">
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import QuillInput from '~/components/QuillInput.vue'
export default {
  components: { QuillInput },
  mixins: [ComponentMixin],
  data() {
    return {
      componentManagerContext: {
        componentTab: {
          UiClassNames: ['is-feature', 'has-cwa-color'],
          UiComponents: [{ label: 'Logo Layout', value: 'HtmlContentWithLogo' }]
        }
      }
    }
  },
  computed: {
    componentManagerTabs() {
      return [
        {
          label: 'HTML Content',
          component: () => import('../admin-dialog/HtmlContent.vue'),
          priority: 2
        }
      ]
    },
    displayHtml() {
      return (
        this.resource.html ||
        (this.$cwa.isAdmin
          ? '<p style="font-style: italic">No content</p>'
          : '')
      )
    }
  }
}
</script>

<style lang="sass">
.html-component
  padding: .5rem
  &.is-feature
    padding: 1rem .5rem
    font-size: 2.1rem
    text-align: center
  &.has-cwa-color
    color: $cwa-color-primary
</style>
