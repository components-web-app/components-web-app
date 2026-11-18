<script setup lang="ts">
import { useCwaResourceManagerTab } from '#imports'

const { exposeMeta } = useCwaResourceManagerTab({
  name: 'Collection',
})

const categoryOptions = [
  {
    label: 'Blog Articles',
    value: '/page_data/blog_article_datas',
  },
]

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
