<template>
  <div class="image-tab">
    <div class="columns is-gapless tab-row">
      <div class="column is-narrow">
        <span v-if="isNew">
          Please add as a draft in order to upload a file
        </span>
        <template v-else>
          <cm-upload
            :id="inputId('image')"
            :iri="resource['@id']"
            field="file"
            label="Upload"
            accept="image/*"
          />
          <span class="help">max. 000px x 000px (0MB)</span>
        </template>
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
    font-size: .75rem
    opacity: .6
</style>
