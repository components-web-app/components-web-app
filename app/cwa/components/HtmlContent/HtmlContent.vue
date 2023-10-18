<template>
  <div ref="htmlContainer" class="html-content" v-html="htmlContent" />
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useCwaResource, useHtmlContent } from '#imports'
import { IriProp } from '#cwa/runtime/composables/cwa-resource'

const props = defineProps<IriProp>()

const { getResource, exposeMeta } = useCwaResource(props.iri)
const resource = getResource()
defineExpose(exposeMeta)

const htmlContainer = ref<null|HTMLElement>(null)
const htmlContent = ref<string>(resource.value.data?.html || '<div></div>')
useHtmlContent(htmlContainer)
</script>

<style>
.html-content {
  a {
    @apply underline
  }
  p:not(:last-child) {
    margin-bottom: 1rem
  }
}
</style>
