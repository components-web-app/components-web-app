// Applies a waiting service worker silently on the next path change, held while an admin is editing (#73).
// afterEach, not beforeEach + location.assign: updateServiceWorker() posts SKIP_WAITING and the plugin reloads
// on `controlling`, so the URL must already be the destination. Needs workbox.clientsClaim.
export default defineNuxtPlugin((nuxtApp) => {
  useRouter().afterEach((to, from, failure) => {
    if (failure || to.path === from.path) {
      return
    }
    // Both injections are typed `unknown` on the plugin's nuxtApp, so type them
    // through the public composables. $pwa is undefined until the worker registers.
    const $pwa = nuxtApp.$pwa as ReturnType<typeof usePWA> | undefined
    const $cwa = nuxtApp.$cwa as ReturnType<typeof useCwa>
    if (!$pwa?.needRefresh || $cwa.admin.isEditing) {
      return
    }
    void $pwa.updateServiceWorker()
  })
})
