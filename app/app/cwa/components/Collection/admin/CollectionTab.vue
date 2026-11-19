<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useCwaResourceManagerTab } from '#imports'
import { collectionSourceOptions } from '~/collection/collection-sources'

const { exposeMeta, $cwa } = useCwaResourceManagerTab({
  name: 'Collection',
})

const categoryOptions = ref<{ label: string, value: string }[]>([])

onMounted(async () => {
  categoryOptions.value = collectionSourceOptions(await $cwa.getApiDocumentation(), $cwa.pageDataConfig)
})

defineExpose(exposeMeta)
</script>

<template>
  <CwaUiManagerTab>
    <CwaUiSelect
      field="resourceIri"
      label="Data category"
      placeholder="Please select"
      :options="categoryOptions"
    />
    <CwaUiSelect
      field="defaultQueryParameters"
      label="Filter"
      nullable
      :options="[]"
    />
    <CwaUiNumber
      field="perPage"
      label="Items per page"
      :min="1"
      noun="item"
    />
  </CwaUiManagerTab>
</template>
