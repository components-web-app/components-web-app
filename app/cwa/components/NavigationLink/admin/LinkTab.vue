<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({
  name: 'Link'
})

defineExpose(exposeMeta)
</script>

<template>
  <div>
    My link tab
  </div>
</template>
