<template>
  <div class="primary-layout">
    <div class="top">
      <cwa-admin-bar />
      <div class="refresh-bar-holder">
        <cwa-refresh-bar />
      </div>

      <div v-if="$cwa.$state.error" class="container loading-message">
        <p class="error">
          {{ $cwa.$state.error }}
        </p>
      </div>

      <div class="navigation">
        <div class="container">
          <div class="columns is-vcentered">
            <div class="column is-narrow">
              <img src="/logo.svg" alt="CWA Logo" />
            </div>
            <div class="column">
              <component-group
                location="top"
                v-bind="componentGroupProps"
                :allowed-components="['/component/navigation_links']"
              />
            </div>
          </div>
        </div>
      </div>

      <nuxt class="cwa-page" />
    </div>
    <div class="bottom">
      <component-group location="bottom" v-bind="componentGroupProps" />
    </div>
    <cwa-component-manager />
  </div>
</template>

<script>
import LayoutMixin from '@cwa/nuxt-module/core/mixins/LayoutMixin'
import CwaRefreshBar from '@cwa/nuxt-module/core/templates/components/admin/cwa-refresh-bar.vue'
import CwaComponentManager from '@cwa/nuxt-module/core/templates/components/admin/cwa-component-manager.vue'

export default {
  components: { CwaComponentManager, CwaRefreshBar },
  mixins: [LayoutMixin]
}
</script>

<style lang="sass">
.primary-layout
  display: flex
  min-height: 100vh
  flex-direction: column
  > .top
    flex-grow: 1
    .refresh-bar-holder
      position: relative
    .navigation
      padding: 2rem 1rem
    .component-group.cwa-group-top_main-layout
      .positions-container
        display: flex
        +tablet
          justify-content: flex-end
  .loading-message
    .error
      color: $color-danger
</style>
