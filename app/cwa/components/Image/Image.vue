<template>
  <div>
    <div data-placeholder="true" class="h-40 w-40 overflow-hidden relative bg-gray-200" />
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { toRef } from 'vue'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const { getResource, exposeMeta } = useCwaResource(toRef(props, 'iri'))
const resource = getResource()
defineExpose(exposeMeta)
</script>
