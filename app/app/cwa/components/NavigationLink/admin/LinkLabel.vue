<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({ name: 'Label' })

defineExpose(exposeMeta)
</script>

<template>
  <CwaUiManagerTab>
    <CwaUiInput
      field="label"
      label="Label"
      width="lg"
    />
  </CwaUiManagerTab>
</template>
