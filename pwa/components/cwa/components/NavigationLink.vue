<template>
  <div class="navigation-link">
    <cwa-nuxt-link :to="resource.url" class="button button-outline">{{
      resource.label
    }}</cwa-nuxt-link>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import CwaNuxtLink from '@cwa/nuxt-module/core/templates/components/utils/cwa-nuxt-link.vue'
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'

export default Vue.extend({
  components: { CwaNuxtLink },
  mixins: [ComponentMixin],
  data() {
    return {
      resourceName: 'Navigation Link'
    }
  },
  computed: {
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        this.createCMTab(
          'Link',
          () => import('../admin-dialog/NavigationLink.vue'),
          2,
          ['label', 'route']
        )
      ]
    }
  }
})
</script>

<style lang="sass">
.component-navigation-link:not(:last-child)
  .navigation-link
    padding-right: .5rem
.navigation-link
  font-weight: $weight-bold
  padding: .25rem 0
  a.button
    margin-bottom: 0
</style>
