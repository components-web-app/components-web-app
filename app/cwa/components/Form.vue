<template>
  <div>
    Cwa Component for Form {{ props.iri }}
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup>
import { useCwaResource, iri } from '#imports'

const props = defineProps({
  ...iri
})

const resource = useCwaResource(props.iri)
</script>
