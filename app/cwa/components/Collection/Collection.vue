<template>
  <div>
    Cwa Component for Collection {{ iri }}
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup lang="ts">
import { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const cwaUtils = useCwaResource(props.iri)
const resource = cwaUtils.getResource()
</script>
