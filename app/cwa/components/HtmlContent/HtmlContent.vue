<template>
  <article class="prose prose-stone max-w-none">
    <TipTapHtmlEditor
      v-if="$cwa.admin.isEditing"
      ref="editorComponent"
      v-model="resourceModel.model.value"
      :disabled="disableEditor"
      data-placeholder="[Empty HTML Content Area]"
      :class="{ 'is-empty opacity-50 text-inherit': disableEditor && !htmlContent }"
    />
    <div v-else ref="htmlContainer" v-html="htmlContent" />
  </article>
</template>

<script setup lang="ts">
import { computed, ref, toRef } from 'vue'
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaResource, useHtmlContent } from '#imports'
import TipTapHtmlEditor from '~/components/TipTapHtmlEditor.vue'
import { useCustomHtmlComponent } from '~/composables/useCustomHtmlComponent'

// Set up the resource
const props = defineProps<IriProp>()
const iriRef = toRef(props, 'iri')
const { getResource, exposeMeta, $cwa } = useCwaResource(iriRef, {
  styles: {
    multiple: true,
    classes: {
      'Big Text': ['text-2xl']
    }
  }
})
defineExpose(exposeMeta)

const resource = getResource()

// HTML Content composable, converting anchors to nuxt link and link enable/disable with editable status
const htmlContainer = ref<null|HTMLElement>(null)

const htmlContent = computed<string>(() => resource.value?.data?.html)
useHtmlContent(htmlContainer)

// This deals with the HTML editor
const { editorComponent, resourceModel, disableEditor } = useCustomHtmlComponent(iriRef)
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
