<template>
  <UAlert
    v-if="show"
    class="fixed bottom-4 left-1/2 z-200 w-[calc(100%-2rem)] max-w-sm -translate-x-1/2 shadow-lg"
    color="primary"
    variant="subtle"
    icon="i-lucide-refresh-cw"
    title="Update available"
    description="A new version of this site has been downloaded."
    close
    @update:open="dismissed = true"
  >
    <template #actions>
      <UButton
        size="xs"
        :loading="updating"
        @click="update"
      >
        Reload
      </UButton>
    </template>
  </UAlert>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { usePWA, useCwa } from '#imports'

// `nuxt.config.ts` sets `pwa.registerType: 'prompt'`, so a new service worker
// installs but then waits — this component is the UI that lets a visitor apply it.
// Without it a waiting worker never activates and users stay on stale assets.
const $pwa = usePWA()
const $cwa = useCwa()

const dismissed = ref(false)
const updating = ref(false)

// Two non-obvious things here:
//
// 1. `usePWA()` returns `UnwrapNestedRefs<PwaInjection>` — a `reactive()` object —
//    so `needRefresh` is a PLAIN BOOLEAN, not a ref. Never write `.value` on it.
//    It is also client-only and may be `undefined` (e.g. no service worker
//    registered), hence the optional chaining; this component is `.client.vue`
//    so it never renders during SSR.
//
// 2. The prompt is HELD, not discarded, while a CWA admin is editing inline.
//    Applying the waiting worker swaps the app's assets and reloads the page,
//    which would throw away unsaved edits. `$cwa.admin.isEditing` is a getter
//    over reactive store state (not a ref — again no `.value`), so reading it
//    inside a computed tracks it, and the prompt reappears on its own the moment
//    edit mode is switched off.
const show = computed(() => !!$pwa?.needRefresh && !$cwa.admin.isEditing && !dismissed.value)

async function update() {
  updating.value = true
  // `true` activates the waiting worker and then reloads the page onto the new assets.
  await $pwa?.updateServiceWorker(true)
}
</script>
