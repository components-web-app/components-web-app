<template>
  <UApp>
    <CwaLoadingIndicator />
    <NuxtLayout>
      <NuxtRouteAnnouncer />
      <VitePwaManifest />
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>

<script setup lang="ts">
// Must be app/app/app.vue (Nuxt 4's source dir). <UApp>: Nuxt UI's toast, tooltip and overlay context;
// <CwaLoadingIndicator />: Nuxt's loading bar with CWA's page load progress (cwa-nuxt-module#396);
// <VitePwaManifest />: the manifest link (prod only). Comments go here: template comments render into every page.
</script>
