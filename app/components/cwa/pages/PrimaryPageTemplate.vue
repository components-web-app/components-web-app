<template>
  <div>
    <div>
      <component-collection
        location="primary"
        v-bind="componentCollectionProps"
      />
    </div>
    <div>
      <component-collection
        location="secondary"
        v-bind="componentCollectionProps"
      />
    </div>
  </div>
</template>

<script>
import PageMixin from '@cwa/nuxt-module/core/mixins/PageMixin'

export default {
  mixins: [PageMixin],
}
</script>
