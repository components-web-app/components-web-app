<script lang="ts" setup>
import { useCwaResourceManagerTab } from '#cwa/runtime/composables/cwa-resource-manager-tab'

const { exposeMeta } = useCwaResourceManagerTab({
  name: 'HTML Content'
})

defineExpose(exposeMeta)
</script>

<template>
  <div>
    HTML Content Tab content
  </div>
</template>
