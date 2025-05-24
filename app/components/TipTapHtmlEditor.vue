<template>
  <div v-if="editor">
    <bubble-menu
      class="bg-stone-700 text-stone-100 rounded overflow-hidden text-sm"
      :tippy-options="{ duration: 150, animation: 'fade' }"
      :editor="editor"
      :update-delay="0"
      @contextmenu.stop
    >
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 1 }])">
        H1
      </BubbleMenuButton>
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 2 }])">
        H2
      </BubbleMenuButton>
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleBold', 'bold')">
        Bold
      </BubbleMenuButton>
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleItalic', 'italic')">
        Italic
      </BubbleMenuButton>
      <button
        class="px-1.5 py-1 content-center items-center"
        :class="[editor.isActive('link') ? 'bg-black text-white' : null]"
        @click="showLinkManager"
      >
        Link
      </button>
    </bubble-menu>

    <floating-menu
      class="floating-menu bg-stone-200 text-stone-700 rounded overflow-hidden"
      :tippy-options="{ duration: 150, animation: 'fade' }"
      :editor="editor"
      :update-delay="0"
      @contextmenu.stop
    >
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 1 }])">
        H1
      </BubbleMenuButton>
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 2 }])">
        H2
      </BubbleMenuButton>
      <BubbleMenuButton v-bind="buttonBubbleMenuProps('toggleBulletList', 'bulletList')">
        Bullet List
      </BubbleMenuButton>
    </floating-menu>
    <editor-content :editor="editor" />
  </div>
</template>

<script lang="ts" setup>
import { StarterKit } from '@tiptap/starter-kit'
import { Placeholder } from '@tiptap/extension-placeholder'
import { Link } from '@tiptap/extension-link'
import {
  BubbleMenu,
  useEditor,
  EditorContent,
  FloatingMenu,
} from '@tiptap/vue-3'
import { computed, toRef, watch } from 'vue'
import type { Editor, ChainedCommands } from '@tiptap/core'
import BubbleMenuButton from '~/components/TipTap/BubbleMenuButton.vue'

const props = defineProps<{
  modelValue: string | null | undefined
  disabled?: boolean
  editorClasses?: string
}>()

const emit = defineEmits(['update:modelValue'])

// reactive updating of the model
const value = computed({
  get() {
    return props.modelValue
  },
  set(value) {
    emit('update:modelValue', value)
  },
})

// create the editor
const editor = useEditor({
  content: value.value,
  editorProps: {
    attributes: {
      class: props.editorClasses || '',
    },
  },
  extensions: [
    StarterKit,
    Placeholder.configure({
      placeholder: 'Write something …',
      emptyEditorClass: 'is-editor-empty text-inherit opacity-50',
    }),
    Link.configure({
      openOnClick: false,
      defaultProtocol: 'https',
    }),
  ],
  onUpdate: () => {
    // HTML
    value.value = editor.value?.isEmpty ? null : editor.value?.getHTML()

    // JSON
    // this.$emit('update:modelValue', this.editor.getJSON())
  },
  editable: !props.disabled,
})

function showLinkManager() {
  if (!editor.value) return
  const previousUrl = editor.value.getAttributes('link').href
  const url = window.prompt('URL', previousUrl)

  // cancelled
  if (url === null) {
    return
  }

  // empty
  if (url === '') {
    editor.value
      .chain()
      .focus()
      .extendMarkRange('link')
      .unsetLink()
      .run()

    return
  }

  // update link
  editor.value
    .chain()
    .focus()
    .extendMarkRange('link')
    .setLink({ href: url })
    .run()
}

// match the editor value to the modelValue prop
watch(value, (newValue) => {
  if (!editor.value) {
    return
  }
  // HTML
  const isSame = editor.value.getHTML() === newValue

  // JSON
  // const isSame = JSON.stringify(this.editor.getJSON()) === JSON.stringify(value)
  if (isSame) {
    return
  }

  editor.value.commands.setContent(newValue || null, false)
})

// Toggle disabled prop and focus when enabled
const disabledRef = toRef(props, 'disabled')
watch(disabledRef, () => {
  if (!editor.value) {
    return
  }
  const editable = !disabledRef.value
  editor.value.setEditable(editable)
  if (editable) {
    editor.value.chain().focus(null, { scrollIntoView: false }).run()
  }
})

// Common menu item props
const buttonBubbleMenuProps = computed(() => (call: keyof ChainedCommands, isActiveName: string, editorArgs?: (string | number | object)[]) => {
  return {
    editor: editor.value as Editor,
    editorFn: {
      call,
      arguments: editorArgs,
    },
    isActiveName,
  }
})

defineExpose({
  editor,
})
</script>

<style>
.ProseMirror:focus {
  outline: none;
}
.ProseMirror {
  white-space: pre-wrap !important;
}
</style>
