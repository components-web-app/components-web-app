<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({ name: 'Content' })

defineExpose(exposeMeta)
</script>

<template>
  <CwaUiManagerTab>
    <CwaUiInlineHandoff
      field="html"
      label="Content"
    />
  </CwaUiManagerTab>
</template>
