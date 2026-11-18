<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({
  name: 'Link',
})

defineExpose(exposeMeta)
</script>

<template>
  <CwaUiManagerTab>
    <CwaUiLinkInput info="Pick a page on this site, or switch to URL and type one." />
  </CwaUiManagerTab>
</template>
