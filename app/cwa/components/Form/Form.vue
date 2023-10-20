<template>
  <div>
    Cwa Component for Form {{ iri }}
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup lang="ts">
import { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { toRef } from 'vue'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const resource = useCwaResource(toRef(props, 'iri')).getResource()
</script>
