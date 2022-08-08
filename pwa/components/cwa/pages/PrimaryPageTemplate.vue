<template>
  <div class="container">
    <div class="columns">
      <div class="column">
        <component-collection
          location="primary"
          v-bind="componentCollectionProps"
        />
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
