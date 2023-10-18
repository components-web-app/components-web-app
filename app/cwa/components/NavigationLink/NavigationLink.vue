<template>
  <nuxt-link :to="resource.data.url" exact-active-class="!text-gray-900 underline" class="text-base font-medium text-gray-500 hover:text-gray-900">
    {{ resource.data.label }}
  </nuxt-link>
</template>

<script setup lang="ts">
import { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const resource = useCwaResource(props.iri).getResource()
</script>
