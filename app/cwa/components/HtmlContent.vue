<template>
  <div class="html-content" v-html="resource.data?.html" />
</template>

<script setup>
import { useCwaResource, iri } from '#imports'

const props = defineProps({
  ...iri
})

const resource = useCwaResource(props.iri)
</script>

<style>
.html-content p:not(:last-child) {
  margin-bottom: 1rem
}
</style>
