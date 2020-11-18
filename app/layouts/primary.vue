<template>
  <div class="primary-layout">
    <div class="top">
      <cwa-admin-bar />
      <div>
        <component-collection
          location="top"
          v-bind="componentCollectionProps"
        />
      </div>

      <div v-if="$cwa.resourcesOutdated" class="container refresh-bar">
        <span>The content on this page is outdated.</span>
        <button class="is-warning" @click="$cwa.mergeNewResources()">
          Update page
        </button>
      </div>

      <div class="container loading-message">
        <p v-if="$cwa.$state.error" class="error">
          {{ $cwa.$state.error }}
        </p>
      </div>

      <nuxt />
    </div>
    <div class="bottom">
      <component-collection
        location="bottom"
        v-bind="componentCollectionProps"
      />
    </div>
  </div>
</template>

<script>
import LayoutMixin from '@cwa/nuxt-module/core/mixins/LayoutMixin'

export default {
  mixins: [LayoutMixin],
}
</script>

<style lang="sass" scoped>
.primary-layout
  display: flex
  min-height: 100vh
  flex-direction: column
  > .top
    flex-grow: 1
.loading-message
  .error
    color: $color-danger
.refresh-bar
  display: flex
  justify-content: center
  align-items: center
  button
    margin: 0 0 0 1rem
</style>
