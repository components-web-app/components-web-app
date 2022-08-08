<template>
  <div class="collection-tab">
    <div class="columns tab-row">
      <div class="column is-narrow">
        <cm-text
          :id="inputId('perpage')"
          :iri="resource['@id']"
          field="perPage"
          type="number"
          label="Items per page"
        />
      </div>
      <div class="column is-narrow">
        <info
          :id="inputId('resourceIri')"
          label="Resource"
          :value="resource.resourceIri || 'Unset'"
        />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import ComponentManagerTabMixin from '@cwa/nuxt-module/core/mixins/ComponentManagerTabMixin'
import CmText from '@cwa/nuxt-module/core/templates/components/admin/cwa-component-manager/input/cm-text.vue'
import Info from '@cwa/nuxt-module/core/templates/components/admin/cwa-component-manager/input/info.vue'

export default Vue.extend({
  components: { Info, CmText },
  mixins: [ComponentManagerTabMixin]
})
</script>
