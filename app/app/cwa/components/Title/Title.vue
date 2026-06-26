<template>
  <h1 class="text-primary text-4xl font-bold">
    {{ resource?.data?.title || 'No Title' }}
  </h1>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/composables/cwa-resource'

const props = defineProps<IriProp>()
const { resource, exposeMeta } = useCwaComponent(props)
defineExpose(exposeMeta)
</script>
