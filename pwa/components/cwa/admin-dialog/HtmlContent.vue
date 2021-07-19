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

<script lang="ts">
import Vue from 'vue'
import ComponentManagerTabMixin from '@cwa/nuxt-module/core/mixins/ComponentManagerTabMixin'
import CwaAdminToggle from '@cwa/nuxt-module/core/templates/components/admin/input/cwa-admin-toggle.vue'
import {
  COMPONENT_MANAGER_EVENTS,
  PublishableToggledEvent,
  SaveStateEvent
} from '@cwa/nuxt-module/core/events'

export default Vue.extend({
  components: { CwaAdminToggle },
  mixins: [ComponentManagerTabMixin],
  data() {
    return {
      showEditor: false
    }
  },
  watch: {
    showEditor(value) {
      this.$cwa.$eventBus.$emit(COMPONENT_MANAGER_EVENTS.saveState, {
        iri: this.iri,
        name: 'showEditor',
        value
      } as SaveStateEvent)
    }
  },
  mounted() {
    this.showEditor = this.cmValue('showEditor')
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
