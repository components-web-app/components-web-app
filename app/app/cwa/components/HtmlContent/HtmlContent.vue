<template>
  <article>
    <TipTapHtmlEditor
      v-if="$cwa.admin.isEditing"
      ref="editorComponent"
      v-model="resourceModel.model.value"
      :disabled="disableEditor"
      data-placeholder="[Empty HTML Content Area]"
      :class="{ 'is-empty opacity-50 text-inherit': disableEditor && !htmlContent }"
      :editor-classes="proseClasses"
    />
    <div
      v-else
      ref="htmlContainer"
      :class="proseClasses"
      v-html="htmlContent"
    />
  </article>
</template>

<script setup lang="ts">
import { computed, ref, toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'
import { useCwaComponent, useHtmlContent } from '#imports'
import TipTapHtmlEditor from '~/components/TipTapHtmlEditor.vue'
import { useCustomHtmlComponent } from '~/composables/useCustomHtmlComponent'

const props = defineProps<IriProp>()
const { resource, exposeMeta, $cwa } = useCwaComponent(props, undefined, {
  styles: {
    multiple: true,
    classes: {
      'Black Background': ['bg-black border border-white p-2'],
    },
  },
})
defineExpose(exposeMeta)

const htmlContainer = ref<null | HTMLElement>(null)
const htmlContent = computed<string>(() => resource.value?.data?.html)
useHtmlContent(htmlContainer)

const { editorComponent, resourceModel, disableEditor } = useCustomHtmlComponent(toRef(props, 'iri'))

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
