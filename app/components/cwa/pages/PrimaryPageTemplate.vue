<template>
  <div class="container">
    <div class="row">
      <div class="column">
        <component-collection
          location="primary"
          v-bind="componentCollectionProps"
        />
      </div>
      <div class="column column-20">
        <component-collection
          location="secondary"
          v-bind="componentCollectionProps"
        />
      </div>
    </div>
  </div>
</template>

<script>
import PageMixin from '@cwa/nuxt-module/core/mixins/PageMixin'

export default {
  mixins: [PageMixin],
}
</script>
