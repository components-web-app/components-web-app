<template>
  <div v-if="editor">
    <bubble-menu
      class="bg-stone-700 text-stone-100 rounded overflow-hidden text-sm"
      style="z-index: 760"
      :append-to="appendToBody"
      :options="{ strategy: 'fixed' }"
      :editor="editor"
      :update-delay="0"
      @contextmenu.stop
    >
      <BubbleMenuButton
        v-if="show('h1')"
        v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 1 }])"
      >
        H1
      </BubbleMenuButton>
      <BubbleMenuButton
        v-if="show('h2')"
        v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 2 }])"
      >
        H2
      </BubbleMenuButton>
      <BubbleMenuButton
        v-if="show('bold')"
        v-bind="buttonBubbleMenuProps('toggleBold', 'bold')"
      >
        Bold
      </BubbleMenuButton>
      <BubbleMenuButton
        v-if="show('italic')"
        v-bind="buttonBubbleMenuProps('toggleItalic', 'italic')"
      >
        Italic
      </BubbleMenuButton>
      <BubbleMenuButton
        v-if="show('underline')"
        v-bind="buttonBubbleMenuProps('toggleUnderline', 'underline')"
      >
        Underline
      </BubbleMenuButton>
      <button
        v-if="show('link')"
        class="px-1.5 py-1 content-center items-center"
        :class="[editor.isActive('link') ? 'bg-black text-white' : null]"
        @click="showLinkManager"
      >
        Link
      </button>
    </bubble-menu>

    <floating-menu
      v-if="show('h1') || show('h2') || show('bulletList')"
      class="floating-menu bg-stone-200 text-stone-700 rounded overflow-hidden"
      style="z-index: 760"
      :append-to="appendToBody"
      :options="{ strategy: 'fixed' }"
      :editor="editor"
      :update-delay="0"
      @contextmenu.stop
    >
      <BubbleMenuButton
        v-if="show('h1')"
        v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 1 }])"
      >
        H1
      </BubbleMenuButton>
      <BubbleMenuButton
        v-if="show('h2')"
        v-bind="buttonBubbleMenuProps('toggleHeading', 'heading', [{ level: 2 }])"
      >
        H2
      </BubbleMenuButton>
      <BubbleMenuButton
        v-if="show('bulletList')"
        v-bind="buttonBubbleMenuProps('toggleBulletList', 'bulletList')"
      >
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
  useEditor,
  EditorContent,
} from '@tiptap/vue-3'
import { BubbleMenu, FloatingMenu } from '@tiptap/vue-3/menus'
import { computed, toRef, watch } from 'vue'
import type { Editor, ChainedCommands } from '@tiptap/core'
import BubbleMenuButton from '~/components/TipTap/BubbleMenuButton.vue'

// The formatting buttons the menus can offer. Hiding a button only removes it from
// the menus: the extension stays registered (Underline comes with StarterKit, Link
// is registered below), so pasted content and keyboard shortcuts can still apply
// that style.
type EditorStyle = 'h1' | 'h2' | 'bold' | 'italic' | 'underline' | 'link' | 'bulletList'

const props = defineProps<{
  modelValue: string | null | undefined
  disabled?: boolean
  editorClasses?: string
  // Every button shows by default. Set a style to `false` to hide its button, for
  // example `:config="{ h1: false, bulletList: false }"`. The floating menu (shown
  // on an empty line) is hidden when h1, h2 and bulletList are all hidden.
  config?: Partial<Record<EditorStyle, boolean>>
}>()

const show = (style: EditorStyle) => props.config?.[style] !== false

const emit = defineEmits(['update:modelValue'])

// Render the menus at the top level so they escape the editor's stacking context and clear the CWA
// page overlay. `document` isn't available in the template expression scope, so define it here.
const appendToBody = () => document.body

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
    StarterKit.configure({
      // TipTap v3 StarterKit includes Link by default — disable it here and
      // register it explicitly below so we can apply custom configuration.
      link: false,
    }),
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
  // Anything the model changed while the editor had focus was held back (see
  // syncFromModel), so apply it now that nobody is typing.
  onBlur: () => syncFromModel(),
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

// Match the editor to the modelValue prop - but never while someone is typing.
//
// setContent replaces the whole document, which puts the caret at the end. While
// the editor has focus it is the source of truth: everything the model holds came
// from this editor, so a value that differs is an older one on its way back (the
// resource model briefly falls back to the stored value, for example while a first
// edit creates a draft under a new IRI). Replacing the document with it moved the
// caret to the end mid-sentence and dropped what had been typed since. The change
// is applied on blur instead.
//
// emitUpdate: false, because TipTap v3's setContent fires onUpdate by default,
// which sent the value straight back out through the model as another save.
function syncFromModel() {
  if (!editor.value || editor.value.isFocused) {
    return
  }
  const newValue = value.value
  // HTML
  const isSame = editor.value.isEmpty ? !newValue : editor.value.getHTML() === newValue

  // JSON
  // const isSame = JSON.stringify(this.editor.getJSON()) === JSON.stringify(value)
  if (isSame) {
    return
  }

  editor.value.commands.setContent(newValue || null, { emitUpdate: false })
}
watch(value, syncFromModel)

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
