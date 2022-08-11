<template>
  <div class="primary-page-template">
    <div class="container">
      <div class="columns is-gapless">
        <div class="column">
          <component-collection
            location="primary"
            v-bind="componentCollectionProps"
            :restricted-resources="['']"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import PageMixin from '@cwa/nuxt-module/core/mixins/PageMixin'

export default {
  mixins: [PageMixin]
}
</script>

<style lang="sass">
.primary-page-template
  padding: 0 1rem
</style>
