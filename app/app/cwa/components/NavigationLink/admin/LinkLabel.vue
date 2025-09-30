<template>
  <CwaUiFormLabelWrapper label="Label">
    <CwaUiFormInput v-model="labelModel.model.value" />
  </CwaUiFormLabelWrapper>
</template>

<script setup lang="ts">
import {
  useCwaResourceManagerTab,
  useCwaResourceModel
} from '#imports'

const { exposeMeta, iri } =
  useCwaResourceManagerTab({ name: 'Label' })

const labelModel =
  useCwaResourceModel<string>(iri, 'label')

defineExpose(exposeMeta)
</script>
