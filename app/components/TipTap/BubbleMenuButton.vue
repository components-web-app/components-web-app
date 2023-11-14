<template>
  <button class="px-1.5 py-1 content-center items-center" :class="[editor.isActive(isActiveName, attributes) ? bubbleMenuActiveClasses : null ]" @click="doEditorChain">
    <slot />
  </button>
</template>

<script lang="ts" setup>
import { Editor } from '@tiptap/core'
import type { UnionCommands } from '@tiptap/core/src/types'
import { computed } from 'vue'

type editorFnType = {
  call: UnionCommands
  attributes?: {}
}

const props = defineProps<{
  editor: Editor,
  editorFn: editorFnType,
  isActiveName: string
}>()

const bubbleMenuActiveClasses = ['bg-black text-white']

const attributes = computed(() => {
  return props.editorFn.attributes || []
})

function doEditorChain () {
  props.editor.chain().focus()[props.editorFn.call](attributes.value).run()
}
</script>
