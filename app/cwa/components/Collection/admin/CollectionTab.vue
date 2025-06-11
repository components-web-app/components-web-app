<script setup lang="ts">
import { useCwaResourceManagerTab, useCwaResourceModel, useCwaSelect } from '#imports'
import type {SelectOption} from "#cwa/runtime/composables/cwa-select-input";

const { exposeMeta, iri } = useCwaResourceManagerTab({
  name: 'Collection'
})

const perPageModel = useCwaResourceModel<string|null>(iri, 'perPage')
const resourceIriModel = useCwaResourceModel<string|null>(iri, 'resourceIri', {
  debounceTime: 0
})
const defaultQueryParametersModel = useCwaResourceModel<string|null>(iri, 'defaultQueryParameters', {
  debounceTime: 0
})

const categoryOptions: SelectOption[] = [
  {
    label: 'Blog Articles',
    value: '/page_data/blog_article_datas',
  },
]
if (!resourceIriModel.model.value) {
  categoryOptions.unshift({
    label: 'Please select',
    value: undefined,
  })
}
const resourceIriSelect = useCwaSelect(resourceIriModel.model, categoryOptions)

const defaultQueryParametersSelect = useCwaSelect(defaultQueryParametersModel.model, [
  {
    label: 'None',
    value: ''
  }
])

defineExpose(exposeMeta)
</script>

<template>
  <div class="flex space-x-4">
    <CwaUiFormLabelWrapper label="Data Category">
      <CwaUiFormSelect v-model="resourceIriSelect.model.value" :options="resourceIriSelect.options.value" />
    </CwaUiFormLabelWrapper>
    <CwaUiFormLabelWrapper label="Filter">
      <CwaUiFormSelect v-model="defaultQueryParametersSelect.model.value" :options="defaultQueryParametersSelect.options.value" />
    </CwaUiFormLabelWrapper>
    <CwaUiFormLabelWrapper label="Items Per Page">
      <CwaUiFormInput v-model.number="perPageModel.model.value" />
    </CwaUiFormLabelWrapper>
  </div>
</template>
