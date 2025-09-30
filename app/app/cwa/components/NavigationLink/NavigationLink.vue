<template>
  <CwaLink
    :to="resource?.data?.url || '#'"
    exact-active-class="text-white!"
    class="md:text-sm font-medium text-white/80 transition no-underline tracking-wide hover:opacity-100 hover:text-gurkha-200"
    :no-prefetch="undefined"
  >
    {{ resource?.data?.label || 'No Link Label' }}
  </CwaLink>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const { getResource, exposeMeta } = useCwaResource(toRef(props, 'iri'))
const resource = getResource()

defineExpose(exposeMeta)
</script>
