<template>
  <nuxt-link :to="resource.data.url" exact-active-class="!text-gray-900 underline" class="text-base font-medium text-gray-500 hover:text-gray-900">
    {{ resource.data.label }}
  </nuxt-link>
</template>

<script setup>
import { useCwaResource, iri } from '#imports'

const props = defineProps({
  ...iri
})

const resource = useCwaResource(props.iri)
</script>
