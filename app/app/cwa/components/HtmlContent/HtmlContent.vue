<template>
  <article>
    <TipTapHtmlEditor
      v-if="$cwa.admin.isEditing"
      :model="resourceModel"
      :iri="iri"
      field="html"
      :disabled="disableEditor"
      data-placeholder="[Empty HTML Content Area]"
      :class="{ 'is-empty opacity-50 text-inherit': disableEditor && !htmlContent }"
      :editor-classes="proseClasses"
    />
    <div
      v-else
      ref="htmlContainer"
      :class="proseClasses"
      v-cwa-html="htmlContent"
    />
  </article>
</template>

<script setup lang="ts">
import { computed, defineAsyncComponent, ref, toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'
import { useCwaComponent, useHtmlContent, defineCwaConfig } from '#imports'
import { useCustomHtmlComponent } from '~/composables/useCustomHtmlComponent'

// Loaded only when an admin starts editing, so TipTap and ProseMirror (about 135 KB
// gzipped) are not preloaded for every visitor (cwa-nuxt-module#332).
const TipTapHtmlEditor = defineAsyncComponent(() => import('~/components/TipTapHtmlEditor.vue'))

defineCwaConfig({
  name: 'Body Text',
  description: 'Easily create a body of text with the ability to style and format the content using themes in-keeping with your website.',
  icon: 'rich-text',
  group: 'Text',
  allowMultiple: true,
  styles: {
    'black-bg': { label: 'Black Background', classes: 'bg-black border border-white p-2' },
  },
})

const props = defineProps<IriProp>()
const { resource, exposeMeta, $cwa } = useCwaComponent(props)
defineExpose(exposeMeta)

const htmlContainer = ref<null | HTMLElement>(null)
const htmlContent = computed<string>(() => resource.value?.data?.html)
// The module's hydration-safe `v-html` (cwa-nuxt-module#333), used as `v-cwa-html`.
const { vCwaHtml } = useHtmlContent(htmlContainer, htmlContent)

const { resourceModel, disableEditor } = useCustomHtmlComponent(toRef(props, 'iri'))

const proseClasses = 'prose prose-invert prose-primary max-w-none'
</script>

<style>
.prose
{
  p.is-editor-empty:first-child::before,
  > div.is-empty::before {
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
  }
}
</style>
