<template>
  <div
    :class="[
      'html-component',
      resource.uiClassNames,
      { 'has-error': !!fieldNotifications.html.length }
    ]"
    @dblclick="toggleEditor"
  >
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
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'
import NotificationListenerMixin from '@cwa/nuxt-module/core/mixins/NotificationListenerMixin'
import QuillInput from '~/components/api-input/QuillInput.vue'
export default {
  components: { QuillInput },
  mixins: [ComponentMixin, NotificationListenerMixin],
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
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        {
          label: 'HTML Content',
          component: () => import('../admin-dialog/HtmlContent.vue'),
          priority: 2,
          inputFieldsUsed: ['html']
        }
      ]
    },
    displayHtml(): string {
      return (
        this.resource.html ||
        (this.$cwa.isAdmin
          ? '<p style="font-style: italic">No content</p>'
          : '')
      )
    }
  },
  created() {
    this.addFieldNotificationListener('html', this.iri)
  },
  methods: {
    toggleEditor() {
      this.saveCmValue('showEditor', !this.cmValue('showEditor'))
    }
  }
}
</script>

<style lang="sass">
.html-component
  padding: .5rem
  position: relative
  &.has-error::after
    content: ''
    position: absolute
    bottom: 100%
    right: 100%
    width: 16px
    height: 16px
    border-radius: 50%
    background: $cwa-danger
    transform: translate(8px, 8px)
  &.is-feature
    padding: 1rem .5rem
    font-size: 2.1rem
    text-align: center
  &.has-cwa-color
    color: $cwa-color-primary
</style>
