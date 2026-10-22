import { Extension, createDocument } from '@tiptap/core'
import type { Editor } from '@tiptap/core'
import type { Node } from '@tiptap/pm/model'
import { Plugin, PluginKey, TextSelection } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

export interface RemoteCursor {
  id: string
  name: string
  colour: string
  from: number
  to: number
}

interface CursorsState {
  received: RemoteCursor[]
  drawn: RemoteCursor[]
  decorations: DecorationSet
}

type CursorsMeta = { cursors: RemoteCursor[] } | { remoteContent: true }

const key = new PluginKey<CursorsState>('remoteCursors')

export function applyRemoteContent(editor: Editor, html: string | null | undefined) {
  const { doc } = editor.state
  const next = createDocument(html || '', editor.schema)
  const start = doc.content.findDiffStart(next.content)
  if (start === null) {
    return
  }
  let { a: end, b: nextEnd } = doc.content.findDiffEnd(next.content)!
  const overlap = start - Math.min(end, nextEnd)
  if (overlap > 0) {
    end += overlap
    nextEnd += overlap
  }
  const tr = editor.state.tr
    .replace(start, end, next.slice(start, nextEnd))
    .setMeta('addToHistory', false)
    .setMeta('preventUpdate', true)
    .setMeta(key, { remoteContent: true } satisfies CursorsMeta)
  editor.view.dispatch(tr)
}

export function setRemoteCursors(editor: Editor, cursors: RemoteCursor[]) {
  editor.view.dispatch(editor.state.tr.setMeta(key, { cursors } satisfies CursorsMeta))
}

function caret(cursor: RemoteCursor) {
  const element = document.createElement('span')
  element.dataset.remoteCursor = cursor.id
  element.style.cssText = 'position: relative; margin: 0 -1px; border-left: 2px solid; pointer-events: none'
  element.style.borderLeftColor = cursor.colour
  const label = document.createElement('span')
  label.textContent = cursor.name
  label.style.cssText = 'position: absolute; bottom: 100%; left: -2px; padding: 1px 4px; border-radius: 2px 2px 2px 0; font: 500 11px/1.2 sans-serif; white-space: nowrap; color: #1c1917; user-select: none'
  label.style.backgroundColor = cursor.colour
  element.append(label)
  return element
}

function decorations(doc: Node, cursors: RemoteCursor[]) {
  const start = TextSelection.atStart(doc).from
  const end = TextSelection.atEnd(doc).to
  const clamp = (position: number) => Math.min(Math.max(position, start), end)
  return DecorationSet.create(doc, cursors.flatMap((cursor) => {
    const from = clamp(Math.min(cursor.from, cursor.to))
    const to = clamp(Math.max(cursor.from, cursor.to))
    return [
      Decoration.inline(from, to, { 'data-remote-selection': cursor.id, 'style': `background-color: ${cursor.colour}40` }),
      Decoration.widget(to, () => caret(cursor), { key: `${cursor.id}:${cursor.name}:${cursor.colour}`, side: 1 }),
    ]
  }))
}

function sameSpot(one: RemoteCursor, other: RemoteCursor | undefined) {
  return !!other && one.from === other.from && one.to === other.to
}

export const RemoteCursors = Extension.create({
  name: 'remoteCursors',
  addProseMirrorPlugins() {
    return [new Plugin<CursorsState>({
      key,
      state: {
        init: () => ({ received: [], drawn: [], decorations: DecorationSet.empty }),
        apply: (tr, state) => {
          const meta = tr.getMeta(key) as CursorsMeta | undefined
          let { received, drawn } = state
          if (meta && 'cursors' in meta) {
            drawn = meta.cursors.map((cursor) => {
              const before = state.drawn.find(({ id }) => id === cursor.id)
              return before && sameSpot(cursor, state.received.find(({ id }) => id === cursor.id)) ? { ...cursor, from: before.from, to: before.to } : cursor
            })
            received = meta.cursors
          }
          else if (meta && 'remoteContent' in meta) {
            drawn = received
          }
          else if (tr.docChanged) {
            drawn = drawn.map(cursor => ({ ...cursor, from: tr.mapping.map(cursor.from), to: tr.mapping.map(cursor.to) }))
          }
          else {
            return state
          }
          return { received, drawn, decorations: decorations(tr.doc, drawn) }
        },
      },
      props: {
        decorations: state => key.getState(state)?.decorations,
      },
    })]
  },
})
