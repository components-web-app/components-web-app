import * as Y from 'yjs'
import { createDocument } from '@tiptap/core'
import type { ParseOptions, Schema } from '@tiptap/pm/model'
import { yXmlFragmentToProseMirrorRootNode } from '@tiptap/y-tiptap'
import { createYSync, decodeUpdate } from './y-sync'
import type { YSyncData } from './y-sync'
import { FIELD, seedUpdate } from './y-seed'
import { htmlHash } from './y-state'
import type { StoredCollaborationState } from './y-state'

export type YSessionStart = 'joined' | 'current' | 'ahead' | 'stale'

export interface YSessionState {
  load: () => Promise<StoredCollaborationState | undefined>
  create: (update: Uint8Array, html: string | null | undefined) => Promise<'created' | 'exists' | 'failed'>
  save: (html: string | null | undefined) => Promise<boolean>
}

interface Session {
  doc: Y.Doc
  sync: ReturnType<typeof createYSync>
  state: YSessionState
  ready: Promise<YSessionStart>
  refs: number
  closed: boolean
  started: boolean
  claimed: boolean
  saves: (string | null)[]
  start: YSessionStart
  closing?: ReturnType<typeof setTimeout>
}

export interface YSessionOptions {
  send: (data: YSyncData) => boolean
  others: () => boolean
  html: () => string | null | undefined
  schema: Schema
  parseOptions?: ParseOptions
  state: (doc: Y.Doc) => YSessionState
  joinMs?: number
}

const STORED = Symbol('y-session-stored')
const LINGER_MS = 3000
const tabs = new WeakMap<object, Map<string, Session>>()

function decoded(stored: StoredCollaborationState | undefined) {
  return stored && { update: decodeUpdate(stored.state), htmlHash: stored.htmlHash }
}

async function startingState(session: Session, loaded: string | null | undefined, { schema, parseOptions }: YSessionOptions) {
  const stored = await session.state.load()
  if (stored || session.closed) {
    return decoded(stored)
  }
  const update = seedUpdate(loaded, schema, undefined, parseOptions)
  const created = await session.state.create(update, loaded)
  const winner = created === 'exists' && !session.closed ? await session.state.load() : undefined
  return decoded(winner) ?? { update, htmlHash: htmlHash(loaded) }
}

async function begin(session: Session, options: YSessionOptions): Promise<YSessionStart> {
  const { others, html, schema, parseOptions } = options
  const start = await startingState(session, html(), options)
  if (session.closed || !start) {
    return 'current'
  }
  Y.applyUpdate(session.doc, start.update, STORED)
  const started = Y.encodeStateVector(session.doc).join()
  const brought = () => Y.encodeStateVector(session.doc).join() !== started
  const joined = session.sync.start()
  const waited = others()
  if (waited && await joined && brought()) {
    return 'joined'
  }
  const now = html()
  if (yXmlFragmentToProseMirrorRootNode(session.doc.getXmlFragment(FIELD), schema).eq(createDocument(now || '', schema, parseOptions))) {
    return 'current'
  }
  if (start.htmlHash === htmlHash(now)) {
    return 'ahead'
  }
  if (!waited && await joined && brought()) {
    return 'joined'
  }
  return session.sync.isSaver(session.sync.peers().map(peer => peer.clientId)) ? 'stale' : 'joined'
}

export function acquireYSession(tab: object, key: string, options: YSessionOptions) {
  const sessions = tabs.get(tab) ?? new Map<string, Session>()
  tabs.set(tab, sessions)
  let session = sessions.get(key)
  if (!session) {
    const doc = new Y.Doc()
    const state = options.state(doc)
    const sync = createYSync(doc, {
      send: options.send,
      joinMs: options.joinMs,
      store: () => state.save(options.html()),
      load: async () => {
        const stored = await state.load()
        return stored && decodeUpdate(stored.state)
      },
    })
    const created: Session = { doc, sync, state, refs: 0, closed: false, started: false, claimed: false, saves: [], start: 'current', ready: Promise.resolve('current') }
    created.ready = begin(created, options).then((start) => {
      created.started = true
      created.start = start
      return start
    })
    session = created
    sessions.set(key, session)
  }
  const held = session
  clearTimeout(held.closing)
  held.refs++
  let released = false
  return {
    doc: held.doc,
    sync: held.sync,
    state: held.state,
    saves: held.saves,
    ready: held.ready,
    claim(): YSessionStart {
      if (held.claimed) {
        return 'joined'
      }
      held.claimed = true
      return held.start
    },
    release() {
      if (released) {
        return
      }
      released = true
      held.refs--
      if (held.refs) {
        return
      }
      const close = () => {
        held.closed = true
        sessions.delete(key)
        held.sync.stop()
        held.doc.destroy()
      }
      held.started ? held.closing = setTimeout(close, LINGER_MS) : close()
    },
  }
}
