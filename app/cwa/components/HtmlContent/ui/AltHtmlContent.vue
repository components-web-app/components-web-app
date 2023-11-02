<template>
  <div class="border-4 p-2 border-black">
    <div data-placeholder class="h-40 w-40 overflow-hidden relative bg-blue-600 p-4 text-center flex items-center text-white font-semibold">
      Html Content Static Image
    </div>
    <div ref="htmlContainer" class="html-content" v-html="htmlContent" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, toRef } from 'vue'
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaResource, useHtmlContent } from '#imports'

const props = defineProps<IriProp>()
const iriRef = toRef(props, 'iri')

const { getResource, exposeMeta } = useCwaResource(iriRef, { name: 'With ALT!! Header' })
const resource = getResource()

const htmlContainer = ref<null|HTMLElement>(null)
const htmlContent = computed<string>(() => (resource.value.data?.html || '<div></div>'))
useHtmlContent(htmlContainer)

defineExpose(exposeMeta)
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
