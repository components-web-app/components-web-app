<template>
  <div class="p-4">
    <CwaComponentGroup reference="primary" :location="props.iri" />
  </div>
</template>

<script setup lang="ts">
import { IriProp } from '#cwa/runtime/composables/cwa-resource'

const props = defineProps<IriProp>()
</script>
