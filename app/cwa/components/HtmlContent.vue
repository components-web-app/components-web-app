<template>
  <div class="html-content" v-html="resource.data?.html" />
</template>

<script setup lang="ts">
import { IriProp } from '#cwa/runtime/composables/cwaResource'
import { useCwaResourceUtils } from '#imports'

const props = defineProps<IriProp>()

const resource = useCwaResourceUtils().getResource(props.iri)
</script>

<style>
.html-content p:not(:last-child) {
  margin-bottom: 1rem
}
</style>
