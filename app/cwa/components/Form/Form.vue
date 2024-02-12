<template>
  <div>
    Cwa Component for Form {{ iri }}
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
