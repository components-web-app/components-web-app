<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({
  name: 'Upload'
})

defineExpose(exposeMeta)
</script>

<template>
  <div>
    My image tab
  </div>
</template>
