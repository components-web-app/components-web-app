<template>
  <div class="html-content-tab">
    <div class="row">
      <div class="column is-narrow">
        <cwa-admin-toggle
          :id="`component-toggle-html-${iri}`"
          v-model="showEditor"
          label="Edit HTML"
        />
      </div>
    </div>
  </div>
</template>

<script>
import ComponentManagerTabMixin from '@cwa/nuxt-module/core/mixins/ComponentManagerTabMixin'
import CwaAdminToggle from '@cwa/nuxt-module/core/templates/components/admin/input/cwa-admin-toggle.vue'

export default {
  components: { CwaAdminToggle },
  mixins: [ComponentManagerTabMixin],
  data() {
    return {
      showEditor: false
    }
  },
  watch: {
    showEditor(show) {
      this.$cwa.$eventBus.$emit('show-html-editor', { iri: this.iri, show })
    }
  }
}
</script>
