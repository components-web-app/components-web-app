<template>
  <div class="mx-auto w-full max-w-7xl py-10 px-4 lg:px-8">
    <CwaComponentGroup reference="primary" :location="props.iri" />
    <CwaPage />
  </div>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/composables/cwa-resource'

const props = defineProps<IriProp>()
</script>
