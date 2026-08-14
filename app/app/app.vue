<template>
  <!--
    Apart from <PwaUpdatePrompt />, this is Nuxt's own default app.vue verbatim —
    keep <NuxtRouteAnnouncer /> and the <NuxtLayout> wrapper in place. The file
    exists so the PWA update prompt is mounted on every page, including ones that
    do not use a CWA layout (e.g. /login). It sits outside <NuxtLayout> so the
    fixed-position notice is never nested inside a transitioned or transformed
    ancestor.
  -->
  <NuxtLayout>
    <NuxtRouteAnnouncer />
    <NuxtPage />
  </NuxtLayout>
  <PwaUpdatePrompt />
</template>
