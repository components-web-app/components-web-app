<template>
  <div class="mt-8 border-t border-white/20 pt-8">
    <CwaComponentGroup reference="primary" :location="props.iri" />
  </div>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/composables/cwa-resource'
import { defineCwaConfig } from '#imports'

defineCwaConfig({
  name: 'Nested Sub-Page',
})

const props = defineProps<IriProp>()
</script>
