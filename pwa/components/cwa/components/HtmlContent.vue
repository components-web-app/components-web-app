<template>
  <div :class="['html-component', resource.uiClassNames]">
    <!-- eslint-disable-next-line vue/no-v-html -->
    <div v-if="!editing" v-html="displayHtml" />
    <quill-input
      v-else
      :iri="displayIri"
      field="html"
      @hide="editing = false"
    />
  </div>
</template>

<script>
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import QuillInput from '~/components/QuillInput'
export default {
  components: { QuillInput },
  mixins: [ComponentMixin],
  data() {
    return {
      editing: false,
      componentManagerContext: {
        componentTab: {
          UiClassNames: ['is-feature', 'has-cwa-color'],
          UiComponents: [{ label: 'Logo Layout', value: 'HtmlContentWithLogo' }]
        }
      }
    }
  },
  computed: {
    displayHtml() {
      return (
        this.resource.html ||
        (this.$cwa.isAdmin
          ? '<p style="font-style: italic">No content</p>'
          : '')
      )
    }
  },
  methods: {
    showEditView() {
      this.editing = true
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
