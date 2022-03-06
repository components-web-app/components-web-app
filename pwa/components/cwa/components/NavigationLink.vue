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
  computed: {
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        {
          label: 'Link',
          component: () => import('../admin-dialog/NavigationLink.vue'),
          priority: 2,
          inputFieldsUsed: ['label', 'route']
        }
      ]
    }
  }
})
</script>

<style lang="sass">
.component-navigation-link:last-child
  .navigation-link
    padding-right: 0
.navigation-link
  font-weight: $font-weight-bold
  padding: .25rem .5rem
  a.button
    margin-bottom: 0
</style>
