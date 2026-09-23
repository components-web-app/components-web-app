import type { ObjectDirective } from 'vue'

/**
 * A hydration-safe replacement for `v-html`.
 *
 * Since Vue 3.5.39, hydration force-patches dynamic props, so `v-html` re-assigns
 * `innerHTML` on every page load even when the server HTML is identical. The
 * browser then throws away the server-rendered body text and parses it again, and
 * because that paragraph is usually the LCP element, the LCP moves from first
 * paint to after hydration. See cwa-nuxt-module#333.
 *
 * - On the server, `getSSRProps` renders the HTML exactly as `v-html` would.
 * - On hydration, `beforeMount` leaves the server DOM alone when it already matches.
 * - On a client-side mount or a content change it sets `innerHTML`, as `v-html` does.
 *
 * The client hooks are `beforeMount`/`beforeUpdate`, not `mounted`/`updated`, so
 * the HTML is in place during the render, as it is with `v-html`. The post-flush
 * `watch` in `useHtmlContent` then converts the anchors in the new HTML. With
 * `updated` that watch can run first, convert the old anchors, and have them
 * overwritten.
 *
 * Temporary: replace it with the module's binding once cwa-nuxt-module#333 ships one.
 */
export const vCwaHtml: ObjectDirective<HTMLElement, string | null | undefined> = {
  getSSRProps: binding => ({ innerHTML: binding.value ?? '' }),
  beforeMount(el, binding) {
    const html = binding.value ?? ''
    if (el.innerHTML !== html) {
      el.innerHTML = html
    }
  },
  beforeUpdate(el, binding) {
    if (binding.value !== binding.oldValue) {
      el.innerHTML = binding.value ?? ''
    }
  },
}
