<template>
  <div class="html-content-tab">
    <div class="row tab-row">
      <div class="column is-narrow">
        <cm-text :id="`label-${iri}`" :iri="iri" field="label" label="Label" />
      </div>
      <div class="column is-narrow">
        <cm-select
          :id="`route-${iri}`"
          :disabled="loadingRoutes"
          :iri="iri"
          field="route"
          label="Route"
          :options="routeOptions"
        />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import ComponentManagerTabMixin from '@cwa/nuxt-module/core/mixins/ComponentManagerTabMixin'
import CmText from '@cwa/nuxt-module/core/templates/components/admin/cwa-component-manager/input/cm-text.vue'
import CmSelect from '@cwa/nuxt-module/core/templates/components/admin/cwa-component-manager/input/cm-select.vue'

export default Vue.extend({
  components: { CmText, CmSelect },
  mixins: [ComponentManagerTabMixin],
  data() {
    return {
      showEditor: false,
      routeOptions: [],
      loadingRoutes: false
    }
  },
  watch: {
    showEditor(value) {
      this.saveCmValue('showEditor', value)
    }
  },
  async mounted() {
    await this.loadRoutes()
  },
  methods: {
    async loadRoutes() {
      this.loadingRoutes = true
      const routesResponse = await this.$axios.$get('/_/routes?perPage=1000')
      this.routeOptions = routesResponse['hydra:member'].map((route) => {
        return {
          value: route['@id'],
          label: route.path
        }
      })
      this.loadingRoutes = false
    }
  }
})
</script>
