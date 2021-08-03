<template>
  <div class="collection-search-input" @click.stop>
    <input
      v-model="inputValue"
      type="text"
      placeholder="Search..."
      @input="
        () => {
          updateQuery()
        }
      "
    />
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import QueryInputMixin from '@cwa/nuxt-module/core/mixins/QueryInputMixin'

export default Vue.extend({
  mixins: [QueryInputMixin],
  data() {
    return {
      defaultDelay: 250
    }
  }
})
</script>
