<template>
  <div>
    Cwa Component for Collection {{ props.iri }}
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup lang="ts">
import { IriProp } from '#cwa/runtime/composables/cwaResource'
import { useCwaResourceUtils } from '#imports'

const props = defineProps<IriProp>()

const resource = useCwaResourceUtils().getResource(props.iri)
</script>
