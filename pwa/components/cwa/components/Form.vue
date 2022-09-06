<template>
  <div v-if="isNew">Your form will be added here</div>
  <form-view v-else class="cwa-form" :form-id="resource['@id']" />
</template>

<script lang="ts">
import Vue from 'vue'
import FormMixin from '@cwa/nuxt-module/core/mixins/FormMixin'

export default Vue.extend({
  name: 'CwaComponentForm',
  mixins: [FormMixin],
  data() {
    return {
      formType: 'App\\Form\\ExampleFormType'
    }
  }
})
</script>

<style lang="sass">
.cwa-form
  .is-validating:not(div):not(span)
    border: 1px solid $cwa-warning !important
  .is-valid:not(div):not(span)
    border: 1px solid $cwa-success !important
  .has-errors:not(div):not(span)
    border: 1px solid $cwa-danger !important
</style>
