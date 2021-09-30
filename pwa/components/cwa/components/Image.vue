<template>
  <div class="cwa-image">
    <div v-if="!mediaObjects" class="placeholder">No Image</div>
    <img v-else-if="showImage" :src="imageSrc" alt="Image" />
  </div>
</template>
<script lang="ts">
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'
export default {
  mixins: [ComponentMixin],
  data() {
    return {
      showImage: true
    }
  },
  computed: {
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        {
          label: 'Image',
          component: () => import('../admin-dialog/Image.vue'),
          priority: 2
        }
      ]
    },
    mediaObjects() {
      return this.resource._metadata?.media_objects
    },
    imageSrc() {
      const postfix = this.published ? '?published=true' : ''
      return (
        this.resource._metadata?.media_objects?.file?.[0]?.contentUrl + postfix
      )
    },
    imageId() {
      return this.resource._metadata?.media_objects?.file?.[0]?.['@id']
    }
  },
  watch: {
    imageId: {
      handler() {
        this.refreshImage()
      }
    }
  },
  methods: {
    refreshImage() {
      this.showImage = false
      this.$nextTick(() => {
        this.showImage = true
      })
    }
  }
}
</script>

<style lang="sass">
.cwa-image
  .placeholder
    padding: 2rem
    background: $cwa-background-dark
    color: $cwa-color-text-light
    display: inline-block
  img
    max-width: 100%
    display: block
</style>
