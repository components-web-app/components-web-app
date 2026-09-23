<template>
  <UApp>
    <NuxtLayout>
      <NuxtRouteAnnouncer />
      <VitePwaManifest />
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>

<script setup lang="ts">
// This must be app/app/app.vue: Nuxt 4 reads app.vue from the source directory
// (app/app/), not the project root. A copy at app/app.vue was silently ignored
// from June to September 2026, so the site had no <UApp> and no manifest link.
// - <UApp> provides Nuxt UI's toast, tooltip and overlay context.
// - <VitePwaManifest /> renders the manifest <link> the PWA needs to be
//   installable (production builds only; the PWA is disabled in dev).
// - <NuxtRouteAnnouncer /> is kept from Nuxt's default app.vue.
// Comments go here, not in the template: template comments are rendered into
// every page's HTML.
</script>
