<template>
  <div class="collection-select-input" @click.stop>
    <div class="select">
      <select v-model="selectedOption" @change="updateSelectedOption">
        <option
          v-for="op of options"
          :key="`select-option-${op.value}-${op.queryKey}`"
          :value="op"
        >
          {{ op.label || op.value }}
        </option>
      </select>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import QuerySelectMixin from '@cwa/nuxt-module/core/mixins/QuerySelectMixin'

export default Vue.extend({
  mixins: [QuerySelectMixin]
})
</script>

<style lang="sass">
.collection-select-input
  width: auto
  select
    width: auto
</style>
