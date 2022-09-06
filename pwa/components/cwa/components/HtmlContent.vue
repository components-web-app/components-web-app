<template>
  <div
    :class="[
      'html-component',
      resource.uiClassNames,
      { 'has-error': !!fieldNotifications.html.length }
    ]"
  >
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

<script lang="ts">
import Vue from 'vue'
import HtmlComponentMixin from '@cwa/nuxt-module/core/mixins/HtmlComponentMixin'
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'
import NotificationListenerMixin from '@cwa/nuxt-module/core/mixins/NotificationListenerMixin'
import QuillInput from '~/components/api-input/QuillInput.vue'
// eslint-disable-next-line vue/one-component-per-file
export default Vue.extend({
  components: { QuillInput },
  mixins: [HtmlComponentMixin, NotificationListenerMixin],
  data() {
    return {
      componentManagerContext: {
        componentTab: {
          UiClassNames: ['is-feature', 'has-cwa-color'],
          UiComponents: [{ label: 'Logo Layout', value: 'HtmlContentWithLogo' }]
        }
      },
      resourceName: 'HTML Content'
    }
  },
  computed: {
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        this.createCMTab(
          this.resourceName,
          () => import('../admin-dialog/HtmlContent.vue'),
          0,
          ['html']
        )
      ]
    },
    htmlComponent() {
      return this.getHtmlAsComponent(this.resource.html)
    }
  },
  created() {
    this.addFieldNotificationListener('html', this.iri)
  },
  methods: {
    toggleEditor() {
      this.toggleCmValue('showEditor')
    }
  }
})
</script>

<style lang="sass">
.html-component
  position: relative
  .content
    margin: 0
  &.is-feature
    padding: 1rem .5rem
    font-size: 2.1rem
    text-align: center
  &.has-cwa-color
    color: $cwa-color-primary
  .cwa-html-content p:last-child
    margin: 0
</style>
