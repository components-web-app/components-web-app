<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({
  name: 'Upload',
})

defineExpose(exposeMeta)
</script>

<template>
  <CwaUiManagerTab>
    <CwaUiFileUpload
      field="file"
      label="Image"
      accept="image/*"
    />
  </CwaUiManagerTab>
</template>
