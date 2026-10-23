import { Extension } from '@tiptap/core'
import { yCursorPlugin } from '@tiptap/y-tiptap'
import type { CursorUser } from '@tiptap/y-tiptap'
import type { YCursor } from './y-sync'

export interface YRemoteCursor {
  clientId: string
  id: number
  name: string
  colour: string
  cursor: YCursor
}

type Awareness = Parameters<typeof yCursorPlugin>[0]

export function createCursorChannel(onLocal: (cursor: YCursor) => void) {
  const listeners = new Set<() => void>()
  let local: Record<string, unknown> = {}
  let remote = new Map<number, Record<string, unknown>>()
  const awareness = {
    getStates: () => remote,
    getLocalState: () => local,
    setLocalStateField(field: string, value: { anchor: unknown, head: unknown } | null) {
      local = { ...local, [field]: value }
      onLocal(value)
    },
    on: (_event: 'change', listener: () => void) => listeners.add(listener),
    off: (_event: 'change', listener: () => void) => listeners.delete(listener),
  }
  return {
    awareness: awareness as unknown as Awareness,
    setRemote(cursors: YRemoteCursor[]) {
      remote = new Map(cursors.map(({ id, clientId, name, colour, cursor }) => [id, { user: { name, color: colour, clientId }, cursor }]))
      listeners.forEach(listener => listener())
    },
  }
}

function caret(user: CursorUser) {
  const element = document.createElement('span')
  element.dataset.remoteCursor = String(user.clientId)
  element.style.cssText = 'position: relative; margin: 0 -1px; border-left: 2px solid; pointer-events: none'
  element.style.borderLeftColor = user.color
  const label = document.createElement('span')
  label.textContent = user.name
  label.style.cssText = 'position: absolute; bottom: 100%; left: -2px; padding: 1px 4px; border-radius: 2px 2px 2px 0; font: 500 11px/1.2 sans-serif; white-space: nowrap; color: #1c1917; user-select: none'
  label.style.backgroundColor = user.color
  element.append(label)
  return element
}

export const YRemoteCursors = Extension.create<{ channel?: ReturnType<typeof createCursorChannel> }>({
  name: 'yRemoteCursors',
  addProseMirrorPlugins() {
    const channel = this.options.channel
    return channel
      ? [yCursorPlugin(channel.awareness, {
          cursorBuilder: caret,
          selectionBuilder: user => ({ 'data-remote-selection': String(user.clientId), 'style': `background-color: ${user.color}40` }),
        })]
      : []
  },
})
