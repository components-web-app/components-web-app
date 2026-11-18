<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({ name: 'Title' })

defineExpose(exposeMeta)
</script>

<template>
  <CwaUiManagerTab>
    <CwaUiInput
      field="title"
      label="Title"
      width="lg"
    />
  </CwaUiManagerTab>
</template>
