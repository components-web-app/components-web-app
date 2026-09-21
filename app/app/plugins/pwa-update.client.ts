// Applies a waiting service worker silently, on the next page navigation, rather
// than asking the visitor (#73).
//
// registerType stays 'prompt' in nuxt.config.ts, so a new worker installs and then
// waits until something asks for it. updateServiceWorker() only posts SKIP_WAITING;
// @vite-pwa/nuxt then reloads the page itself once the new worker takes control,
// which is why workbox.clientsClaim has to stay on.
//
// This runs in afterEach, not beforeEach, because of that reload. By afterEach the
// URL is already the destination, so the reload lands where the visitor was going.
// Starting the update in beforeEach and navigating with location.assign() races
// the plugin's own reload, which can cancel the navigation and leave the visitor
// on the page they were leaving.
//
// Only a change of path counts, so an in-page anchor or a query change never
// triggers a reload. The update is held while an admin is editing, because the
// reload would throw away unsaved inline edits; it applies on the first
// navigation after edit mode ends.
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
