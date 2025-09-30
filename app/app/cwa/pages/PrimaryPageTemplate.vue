<template>
  <div class="mx-auto flex w-full max-w-7xl items-center py-10 px-4 justify-start space-x-10 lg:px-8">
    <div class="w-full">
      <CwaComponentGroup reference="primary" :location="props.iri" />
    </div>
  </div>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/composables/cwa-resource'

const props = defineProps<IriProp>()
</script>
