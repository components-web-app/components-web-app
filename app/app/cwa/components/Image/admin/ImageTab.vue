<script setup lang="ts">
import { useCwaResourceManagerTab, useCwaResourceUpload } from '#imports'

const { exposeMeta, iri } = useCwaResourceManagerTab({
  name: 'Upload'
})

const { filenameInputModel, updating, fileExists, handleInputChangeFile, handleInputDeleteFile } = useCwaResourceUpload(iri)

defineExpose(exposeMeta)
</script>

<template>
  <div>
    <CwaUiFormFile
      v-model="filenameInputModel"
      label="Upload Image"
      :disabled="updating"
      :file-exists="fileExists"
      @change="handleInputChangeFile"
      @delete="handleInputDeleteFile"
    />
  </div>
</template>
