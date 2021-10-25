<template>
  <div
    :class="[
      'html-component',
      resource.uiClassNames,
      { 'has-error': !!fieldNotifications.html.length }
    ]"
    @dblclick="toggleEditor"
  >
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

<script lang="ts">
import Vue from 'vue'
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'
import NotificationListenerMixin from '@cwa/nuxt-module/core/mixins/NotificationListenerMixin'
import QuillInput from '~/components/api-input/QuillInput.vue'
export default {
  components: { QuillInput },
  mixins: [ComponentMixin, NotificationListenerMixin],
  data() {
    return {
      isMounted: false,
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
    htmlComponent() {
      let html =
        this.resource.html ||
        (this.$cwa.isAdmin
          ? '<p style="font-style: italic">No content</p>'
          : '')
      if (this.isMounted) {
        const div = document.createElement('div')
        div.innerHTML = html
        const anchors = div.getElementsByTagName('a')
        Array.from(anchors).forEach((anchor) => {
          anchor.parentNode.replaceChild(this.convertAnchor(anchor), anchor)
        })
        html = div.innerHTML
      }
      return Vue.extend({
        components: {
          CwaNuxtLink: () =>
            import(
              '@cwa/nuxt-module/core/templates/components/utils/cwa-nuxt-link.vue'
            )
        },
        props: this.$options.props,
        template: '<div>' + html + '</div>'
      })
    }
  },
  mounted() {
    this.isMounted = true
  },
  created() {
    this.addFieldNotificationListener('html', this.iri)
  },
  methods: {
    toggleEditor() {
      this.saveCmValue('showEditor', !this.cmValue('showEditor'))
    },
    convertAnchor(anchor) {
      // console.log(anchor, anchor.attributes, anchor.innerHTML)
      const newLink = document.createElement('cwa-nuxt-link')
      newLink.setAttribute('to', anchor.getAttribute('href'))
      for (const attr of anchor.attributes) {
        if (!['href', 'target', 'rel'].includes(attr.name)) {
          newLink.setAttribute(attr.name, anchor[attr.name])
        }
      }
      newLink.innerHTML = anchor.innerHTML
      return newLink
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
  .cwa-html-content p:last-child
    margin: 0
</style>
