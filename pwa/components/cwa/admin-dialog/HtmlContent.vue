<template>
  <div class="html-content-tab">
    <div class="row tab-row">
      <div class="column is-narrow">
        <cwa-admin-toggle
          :id="`component-toggle-html-${iri}`"
          v-model="showEditor"
          :notifications="fieldErrors.notifications['html']"
          label="Edit HTML"
          error-label="HTML"
        />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import ComponentManagerTabMixin from '@cwa/nuxt-module/core/mixins/ComponentManagerTabMixin'
import CwaAdminToggle from '@cwa/nuxt-module/core/templates/components/admin/input/cwa-admin-toggle.vue'
import {
  COMPONENT_MANAGER_EVENTS,
  PublishableToggledEvent
} from '@cwa/nuxt-module/core/events'

export default Vue.extend({
  components: { CwaAdminToggle },
  mixins: [ComponentManagerTabMixin],
  computed: {
    showEditor: {
      get() {
        return this.cmValue('showEditor')
      },
      set(value) {
        this.saveCmValue('showEditor', value)
      }
    }
  },
  mounted() {
    this.$cwa.$eventBus.$on(
      COMPONENT_MANAGER_EVENTS.publishableToggled,
      this.handlePublishableToggled
    )
  },
  beforeDestroy() {
    this.$cwa.$eventBus.$off(
      COMPONENT_MANAGER_EVENTS.publishableToggled,
      this.handlePublishableToggled
    )
  },
  methods: {
    handlePublishableToggled(event: PublishableToggledEvent) {
      if ([event.draftIri, event.publishedIri].includes(this.iri)) {
        this.showEditor = null
      }
    }
  }
})
</script>
