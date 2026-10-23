import * as Y from 'yjs'
import { createDocument } from '@tiptap/core'
import type { ParseOptions, Schema } from '@tiptap/pm/model'
import { prosemirrorToYXmlFragment } from '@tiptap/y-tiptap'

export const FIELD = 'default'
const SEED_VERSION = 'cwa-yjs-seed:1:'

export function seedClientId(html: string) {
  let hash = 0x811C9DC5
  for (const char of SEED_VERSION + html) {
    hash = Math.imul(hash ^ char.charCodeAt(0), 0x01000193) >>> 0
  }
  return hash || 1
}

export function seedUpdate(html: string | null | undefined, schema: Schema, clientId = seedClientId(html || ''), parseOptions?: ParseOptions) {
  const doc = new Y.Doc()
  doc.clientID = clientId
  prosemirrorToYXmlFragment(createDocument(html || '', schema, parseOptions), doc.getXmlFragment(FIELD))
  return Y.encodeStateAsUpdate(doc)
}
