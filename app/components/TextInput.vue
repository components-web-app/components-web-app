<template>
  <div>
    <input v-model="inputValue" @dblclick="$emit('hide')" />
    <div v-if="outdated">
      <span v-if="!error">saving...</span>
      <div v-else class="notice is-danger">
        {{ error }}
      </div>
    </div>
  </div>
</template>

<script>
import InputMixin from '@cwa/nuxt-module/core/mixins/InputMixin'

export default {
  mixins: [InputMixin],
}
</script>
