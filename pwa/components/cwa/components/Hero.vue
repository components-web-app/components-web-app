<template>
  <div
    :class="[
      'hero',
      resource.uiClassNames,
      { 'has-error': !!fieldNotifications.html.length }
    ]"
    :style="{ backgroundImage: `url('${imageSrc}')` }"
  >
    <div class="page-padding">
      <div class="container">
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
      resourceName: 'Hero'
    }
  },
  computed: {
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        this.createCMTab(
          `${this.resourceName} Content`,
          () => import('../admin-dialog/hero/HeroContent.vue'),
          0,
          ['html']
        ),
        this.createCMTab(
          `${this.resourceName} Image`,
          () => import('../admin-dialog/hero/HeroImage.vue'),
          0,
          ['file']
        )
      ]
    },
    htmlComponent() {
      return this.getHtmlAsComponent(this.resource.html)
    },
    imageObject() {
      return this.getMediaObject('file', 0)
    },
    imageSrc() {
      return this.getMediaObjectContentUrl(this.imageObject)
    },
    imageId() {
      return this.imageObject?.['@id']
    }
  },
  created() {
    this.addFieldNotificationListener('html', this.iri)
    this.addFieldNotificationListener('file', this.iri)
  }
})
</script>

<style lang="sass">
.hero
  position: relative
  background: 50% 100% no-repeat $cwa-blue
  background-size: cover
  min-height: 400px
  .content
    color: $white
    padding: 3rem 45% 10rem 0
  h1,h2,h3
    font-weight: $weight-normal
  h1,h2,h3,strong
    color: inherit
</style>
