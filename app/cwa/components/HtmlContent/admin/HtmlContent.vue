<script lang="ts" setup>
import { useCwaResourceManagerTab } from '#cwa/runtime/composables/cwa-resource-manager-tab'
import { useCwaResourceModel } from '#cwa/runtime/composables/cwa-resource-model'

const { exposeMeta, iri } = useCwaResourceManagerTab({
  name: 'HTML Content'
})

const resourceModel = useCwaResourceModel<string>(iri, 'html')

defineExpose(exposeMeta)
</script>

<template>
  <div>
    <CwaUiFormInput v-model="resourceModel.model.value" />
  </div>
</template>
