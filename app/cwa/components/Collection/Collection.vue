<template>
  <div>
    Cwa Component for Collection {{ iri }}
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { toRef } from 'vue'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const cwaUtils = useCwaResource(toRef(props, 'iri'))
const resource = cwaUtils.getResource()
</script>
