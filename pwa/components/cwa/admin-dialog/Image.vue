<template>
  <div class="image-tab">
    <div class="row">
      <div class="column is-narrow">
        <cm-upload
          :id="inputId('image')"
          :iri="resource['@id']"
          field="file"
          label="Upload"
          accept="image/*"
        />
        <span class="help">max. 2000px x 2000px (5MB)</span>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import ComponentManagerTabMixin from '@cwa/nuxt-module/core/mixins/ComponentManagerTabMixin'
import CmUpload from '@cwa/nuxt-module/core/templates/components/admin/cwa-component-manager/input/cm-upload.vue'

export default Vue.extend({
  components: { CmUpload },
  mixins: [ComponentManagerTabMixin]
})
</script>

<style lang="sass">
.image-tab
  .help
    font-size: 1.2rem
    opacity: .6
</style>
