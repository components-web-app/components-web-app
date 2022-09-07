<template>
  <div class="primary-page-template">
    <component-group
      location="main-hero"
      v-bind="componentGroupProps"
      :allowed-components="['/component/heroes']"
    />
    <div class="page-padding">
      <div class="container">
        <div class="columns is-gapless">
          <div class="column">
            <component-group location="primary" v-bind="componentGroupProps" />
          </div>
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
  .page-padding
    padding: 2rem 1rem 0
</style>
