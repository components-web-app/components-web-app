<template>
  <button
    class="px-1.5 py-1 content-center items-center"
    :class="[editor.isActive(isActiveName, args) ? bubbleMenuActiveClasses : null]"
    @click="doEditorChain"
  >
    <slot />
  </button>
</template>

<script lang="ts" setup>
import type { Editor, ChainedCommands } from '@tiptap/core'
import { computed } from 'vue'

type editorFnType = {
  call: keyof ChainedCommands
  arguments?: (object | string | number)[]
}

const props = defineProps<{
  editor: Editor
  editorFn: editorFnType
  isActiveName: string
}>()

const bubbleMenuActiveClasses = ['bg-black text-white']

const args = computed(() => {
  return props.editorFn.arguments || []
})

function doEditorChain() {
  // @ts-expect-error-next-line the function called could have many different requirements for arguments
  props.editor.chain().focus()[props.editorFn.call](...args.value).run()
}
</script>
