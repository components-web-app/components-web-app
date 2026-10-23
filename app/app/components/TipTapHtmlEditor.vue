<template>
  <CwaUiFieldPresence
    v-if="editor"
    :model="model"
    v-bind="focusListeners"
  >
    <bubble-menu
      class="bg-stone-700 text-stone-100 rounded overflow-hidden text-sm"
      style="z-index: 760"
      :append-to="appendToBody"
      :options="{ strategy: 'fixed' }"
      :editor="editor"
      :update-delay="0"
      @mousedown.prevent
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
      @mousedown.prevent
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
    <CwaUiRemoteChangeConflict
      v-if="remoteChange"
      :change="remoteChange"
      class="mt-2"
    />
  </CwaUiFieldPresence>
</template>

<script lang="ts" setup>
import { StarterKit } from '@tiptap/starter-kit'
import { Placeholder } from '@tiptap/extension-placeholder'
import { Link } from '@tiptap/extension-link'
import { Collaboration } from '@tiptap/extension-collaboration'
import { ySyncPluginKey } from '@tiptap/y-tiptap'
import {
  Editor,
  EditorContent,
} from '@tiptap/vue-3'
import { BubbleMenu, FloatingMenu } from '@tiptap/vue-3/menus'
import { getSchema } from '@tiptap/core'
import type { ChainedCommands, Editor as CoreEditor } from '@tiptap/core'
import type { Transaction } from '@tiptap/pm/state'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import * as Y from 'yjs'
import BubbleMenuButton from '~/components/TipTap/BubbleMenuButton.vue'
import { applyRemoteContent, sameContent } from '~/tiptap/co-editing'
import { createCursorChannel, YRemoteCursors } from '~/tiptap/y-cursors'
import { acquireYSession } from '~/tiptap/y-session'
import { createCollaborationState } from '~/tiptap/y-state'
import type { YSyncData } from '~/tiptap/y-sync'
import { useCwa, useCwaRealtime } from '#imports'
import type { useCwaResourceModel } from '#imports'

// The menu buttons. Hiding one only removes it from the menus: the extension stays registered (pastes, shortcuts).
type EditorStyle = 'h1' | 'h2' | 'bold' | 'italic' | 'underline' | 'link' | 'bulletList'

const props = defineProps<{
  model: ReturnType<typeof useCwaResourceModel<string>>
  iri: string
  field: string
  disabled?: boolean
  editorClasses?: string
  // Every button shows by default. Set a style to `false` to hide its button, for
  // example `:config="{ h1: false, bulletList: false }"`. The floating menu (shown
  // on an empty line) is hidden when h1, h2 and bulletList are all hidden.
  config?: Partial<Record<EditorStyle, boolean>>
}>()

const show = (style: EditorStyle) => props.config?.[style] !== false

// Render the menus at the top level so they escape the editor's stacking context and clear the CWA
// page overlay. `document` isn't available in the template expression scope, so define it here.
const appendToBody = () => document.body

const parseOptions = { preserveWhitespace: true } as const
const SETTLE_MS = 1500
const OWN_SAVES = 20

const { model: html, remoteChange, focusedBy, focusListeners, states } = props.model
const $cwa = useCwa()
const event = `yjs:${props.field}`
const { send, on, peers } = useCwaRealtime<Record<string, YSyncData>>(() => props.iri)

type Shared = { doc: Y.Doc, channel: ReturnType<typeof createCursorChannel> }
type Caret = { from: number, to: number } | undefined

const editor = shallowRef<Editor>()
const session = shallowRef<ReturnType<typeof acquireYSession>>()
const ready = ref(false)
const heard = ref(0)
const senders = new Map<string, { name: string, colour: string }>()
let cursorChannel: Shared['channel'] | undefined
let stopHearing: (() => void) | undefined
let settleTimer: ReturnType<typeof setTimeout> | undefined

const live = computed(() => peers.value.map(peer => peer.clientId))
const inField = computed(() => focusedBy.value.flatMap(peer => peer.clientIds))
const company = computed(() => heard.value >= 0 && !!session.value?.sync.peers().some(peer => live.value.includes(peer.clientId)))
const saver = computed(() => heard.value >= 0 && (!session.value || session.value.sync.isSaver(live.value)))

on(event, ({ clientId, name, colour, data }) => {
  senders.set(clientId, { name, colour })
  session.value?.sync.receive(clientId, data)
})

function extensions(shared?: Shared) {
  return [
    StarterKit.configure({
      // TipTap v3 StarterKit includes Link by default — disable it here and
      // register it explicitly below so we can apply custom configuration.
      link: false,
      ...(shared ? { undoRedo: false as const } : {}),
    }),
    Placeholder.configure({
      placeholder: 'Write something …',
      emptyEditorClass: 'is-editor-empty text-inherit opacity-50',
    }),
    Link.configure({
      openOnClick: false,
      defaultProtocol: 'https',
    }),
    ...(shared ? [Collaboration.configure({ document: shared.doc }), YRemoteCursors.configure({ channel: shared.channel })] : []),
  ]
}

const schema = getSchema(extensions())

function storedHtml(): string | null | undefined {
  return $cwa.resources.getResource(props.iri).value?.data?.[props.field]
}

function save(current: CoreEditor) {
  const value = current.isEmpty ? null : current.getHTML()
  const saves = session.value?.saves
  saves?.push(value)
  saves?.splice(0, saves.length - OWN_SAVES)
  html.value = value
}

function isLocal(transaction: Transaction) {
  const sync = transaction.getMeta(ySyncPluginKey)
  return !sync?.isChangeOrigin || !!sync.isUndoRedoOperation
}

function settle() {
  const current = editor.value
  if (!ready.value || !saver.value || !current) {
    return
  }
  sameContent(current, html.value) || save(current)
  session.value?.state.save(storedHtml())
}

function settleSoon() {
  clearTimeout(settleTimer)
  settleTimer = setTimeout(settle, SETTLE_MS)
}

function isOutside(value: string | null | undefined) {
  const writer = $cwa.resources.getResource(props.iri).value?.data?._metadata?.lastWrite?.clientId
  return !session.value?.saves.includes(value ?? null) && !session.value?.sync.peers().some(peer => peer.clientId === writer)
}

function caretIn(previous: Editor | undefined): Caret {
  const selection = document.getSelection()
  if (!previous || !selection?.anchorNode || !selection.focusNode || !previous.view.dom.contains(selection.anchorNode)) {
    return
  }
  try {
    return { from: previous.view.posAtDOM(selection.anchorNode, selection.anchorOffset), to: previous.view.posAtDOM(selection.focusNode, selection.focusOffset) }
  }
  catch {
    return
  }
}

function focusTaken() {
  return !!document.activeElement && document.activeElement !== document.body
}

function build(shared?: Shared, wantsFocus = false) {
  const previous = editor.value
  const focus = wantsFocus && !focusTaken()
  const caret = focus ? caretIn(previous) : undefined
  let rendered = !shared
  cursorChannel = shared?.channel
  editor.value = new Editor({
    ...(shared ? {} : { content: html.value }),
    parseOptions,
    editorProps: {
      attributes: {
        class: props.editorClasses || '',
      },
    },
    extensions: extensions(shared),
    onCreate: ({ editor: created }) => {
      rendered = true
      focus && created.chain().setTextSelection(caret ?? created.state.selection).focus(null, { scrollIntoView: false }).run()
    },
    onUpdate: ({ editor: changed, transaction }) => {
      if (!rendered || !shared) {
        return
      }
      isLocal(transaction) && save(changed)
      saver.value && settleSoon()
    },
    editable: !!shared && !props.disabled,
  })
  previous && nextTick(() => previous.destroy())
}

function showRemoteCursors() {
  cursorChannel?.setRemote((session.value?.sync.peers() ?? []).filter(peer => inField.value.includes(peer.clientId)).map(peer => ({
    ...peer,
    name: senders.get(peer.clientId)?.name ?? 'Someone',
    colour: senders.get(peer.clientId)?.colour ?? '#a8a29e',
  })))
}

function endSession() {
  stopHearing?.()
  stopHearing = undefined
  clearTimeout(settleTimer)
  session.value?.release()
  session.value = undefined
  ready.value = false
}

async function startSession(focus: boolean) {
  endSession()
  const published = $cwa.resources.findPublishedComponentIri(props.iri).value ?? props.iri
  const held = acquireYSession($cwa, `${published}#${props.field}`, {
    send: data => send(event, data),
    others: () => live.value.length > 0,
    html: () => html.value,
    schema,
    parseOptions,
    state: doc => createCollaborationState($cwa.cwaFetch.fetch, { iri: () => published, field: props.field, encode: () => Y.encodeStateAsUpdate(doc) }),
  })
  session.value = held
  const stop = held.sync.onChange(() => heard.value++)
  await held.ready
  if (session.value !== held) {
    stop()
    return
  }
  const start = held.claim()
  stopHearing = stop
  build({ doc: held.doc, channel: createCursorChannel(cursor => held.sync.setCursor(cursor)) }, focus)
  ready.value = true
  showRemoteCursors()
  const built = editor.value!
  start === 'stale' && applyRemoteContent(built, html.value)
  start === 'ahead' && save(built)
  settleSoon()
}

onMounted(() => {
  build()
  props.disabled || startSession(false)
})

onBeforeUnmount(() => {
  endSession()
  editor.value?.destroy()
})

watch(live, (now, before) => {
  before.filter(clientId => !now.includes(clientId)).forEach(clientId => session.value?.sync.forget(clientId))
})

watch(saver, isSaver => isSaver && settleSoon())

watch([heard, inField], showRemoteCursors)

watch(() => states.submitting.value, (submitting, before) => {
  before && !submitting && saver.value && settleSoon()
})

watch(remoteChange, (change) => {
  const current = editor.value
  if (!change || !company.value || !current) {
    return
  }
  if (sameContent(current, change.value as string | null | undefined)) {
    change.accept()
    return
  }
  save(current)
  change.keep()
})

watch([html, () => props.iri], ([value, iri], [, before]) => {
  const current = editor.value
  if (!current || iri !== before || sameContent(current, value)) {
    return
  }
  if (!company.value || (ready.value && saver.value && isOutside(value))) {
    applyRemoteContent(current, value)
  }
})

watch(() => props.disabled, (disabled) => {
  if (disabled) {
    endSession()
    build()
    return
  }
  startSession(true)
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
