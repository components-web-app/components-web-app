<template>
  <div>
    <input
      v-model="inputValue"
      :class="{ 'has-error': !!error }"
      @dblclick="$emit('hide')"
    />
    <div v-if="outdated && !error">
      <span>saving...</span>
    </div>
  </div>
</template>

<script>
import ApiInputMixin from '@cwa/nuxt-module/core/mixins/ApiInputMixin'

export default {
  mixins: [ApiInputMixin]
}
</script>
