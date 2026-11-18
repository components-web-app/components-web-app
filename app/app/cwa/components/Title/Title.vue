<template>
  <h1 class="text-primary text-4xl font-bold">
    <LazyCwaUiInlineEdit
      v-if="$cwa.admin.isEditing"
      :model="title"
      label="Title"
      placeholder="Add a title"
    />
    <template v-else>
      {{ resource?.data?.title || 'No Title' }}
    </template>
  </h1>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'
import { useCwaComponent, useCwaResourceModel } from '#imports'

const props = defineProps<IriProp>()
const { resource, exposeMeta, $cwa } = useCwaComponent(props)
const title = useCwaResourceModel<string>(toRef(props, 'iri'), 'title')
defineExpose(exposeMeta)
</script>
