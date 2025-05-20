<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useCwaResourceManagerTab, useCwaResourceModel } from '#imports'

const { exposeMeta, iri, resource } = useCwaResourceManagerTab({
  name: 'Link'
})

const showInternalRoute = ref(!resource.value?.data?.rawPath)
const toggleLabel = computed(() => {
  return showInternalRoute.value ? 'Internal' : 'External'
})

const routeModel = useCwaResourceModel<string>(iri, 'route', {
  debounceTime: 0
})

const rawPathModel = useCwaResourceModel<string|null>(iri, 'rawPath')

watch(showInternalRoute, (isInternal) => {
  if (isInternal) {
    rawPathModel.model.value = null
  }
})

watch(() => !resource.value?.data?.rawPath, (noRawPath: boolean) => {
  showInternalRoute.value = noRawPath
}, {
  immediate: true
})

defineExpose(exposeMeta)
</script>

<template>
  <div class="flex space-x-8">
    <CwaUiFormToggle v-model="showInternalRoute" :label="toggleLabel" />
    <CwaUiFormLabelWrapper v-if="showInternalRoute" label="Route">
      <CwaUiFormSearchResource v-model="routeModel.model.value" endpoint="/_/routes" property="path" />
    </CwaUiFormLabelWrapper>
    <CwaUiFormLabelWrapper v-else label="URL">
      <CwaUiFormInput v-model="rawPathModel.model.value" />
    </CwaUiFormLabelWrapper>
  </div>
</template>
