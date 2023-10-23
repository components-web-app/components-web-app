<template>
  <div ref="htmlContainer" class="html-content" v-html="htmlContent" />
</template>

<script setup lang="ts">
import { computed, ref, toRef } from 'vue'
import { useCwaResource, useHtmlContent } from '#imports'
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'

const props = defineProps<IriProp>()
const { getResource, exposeMeta } = useCwaResource(toRef(props, 'iri'))
const resource = getResource()
defineExpose(exposeMeta)

const htmlContainer = ref<null|HTMLElement>(null)
const htmlContent = computed<string>(() => (resource.value.data?.html || '<div></div>'))
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
