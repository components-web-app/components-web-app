<script setup lang="ts">
import { useCwaResourceManagerTab, useCwaResourceUpload } from '#imports'

const { exposeMeta, iri } = useCwaResourceManagerTab({
  name: 'Upload',
})

const { bind } = useCwaResourceUpload(iri)

defineExpose(exposeMeta)
</script>

<template>
  <div>
    <CwaUiFormFile
      v-bind="bind"
      label="Upload Image"
    />
  </div>
</template>
