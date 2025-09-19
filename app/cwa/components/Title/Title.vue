<template>
  <h1 class="text-primary text-4xl font-bold">
    {{ resource?.data?.title || 'No Title' }}
  </h1>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'
import {
  useCwaResource
} from '#imports'

const props = defineProps<IriProp>()

const { getResource, exposeMeta } =
  useCwaResource(toRef(props, 'iri'))

const resource = getResource()

defineExpose(exposeMeta)
</script>
