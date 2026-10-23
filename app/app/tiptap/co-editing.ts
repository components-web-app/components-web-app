import { createDocument } from '@tiptap/core'
import type { Editor } from '@tiptap/core'

export function applyRemoteContent(editor: Editor, html: string | null | undefined) {
  const { doc } = editor.state
  const next = createDocument(html || '', editor.schema, editor.options.parseOptions)
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
  editor.view.dispatch(tr)
}

export function sameContent(editor: Editor, html: string | null | undefined) {
  return createDocument(html || '', editor.schema, editor.options.parseOptions).eq(editor.state.doc)
}
