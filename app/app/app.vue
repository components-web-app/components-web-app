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
// Must be app/app/app.vue (Nuxt 4's source dir). <UApp>: Nuxt UI's toast, tooltip and overlay context;
// <VitePwaManifest />: the manifest link (prod only). Comments go here: template comments render into every page.
</script>
