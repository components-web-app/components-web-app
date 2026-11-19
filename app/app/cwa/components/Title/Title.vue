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
    <span
      v-if="styleKeys.includes('underlined')"
      class="block mt-3 h-1 w-16 bg-primary"
      aria-hidden="true"
    />
  </h1>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'
import { useCwaComponent, useCwaResourceModel, defineCwaConfig } from '#imports'

defineCwaConfig({
  name: 'Title',
  description: 'A simple title component for page headings.',
  icon: 'heading',
  group: 'Text',
  styles: {
    centred: { label: 'Centred', classes: 'text-center' },
    underlined: { label: 'Underlined', classes: 'pb-1' },
  },
})

const props = defineProps<IriProp>()
const { resource, exposeMeta, $cwa, styleKeys } = useCwaComponent(props)
const title = useCwaResourceModel<string>(toRef(props, 'iri'), 'title')
defineExpose(exposeMeta)
</script>
