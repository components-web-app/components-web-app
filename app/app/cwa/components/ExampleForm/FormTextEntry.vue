<template>
  <UFormField
    :label="entry.vars.value?.label || 'Text'"
    :error="entry.displayErrors.value ? entry.errors.value[0] : undefined"
  >
    <div class="flex items-center gap-2">
      <UInput
        v-model="entry.value.value"
        class="flex-1"
        :trailing-icon="trailingIcon(entry)"
        :ui="{ trailingIcon: trailingIconClass(entry) }"
        @blur="entry.onBlur"
        @input="entry.onInput"
      />
      <UButton
        color="error"
        variant="soft"
        icon="i-lucide-trash-2"
        @click.prevent="$emit('remove')"
      />
    </div>
  </UFormField>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import { useCwaFormInput } from '#imports'

const props = defineProps<{ iri: string, entryFullName: string }>()
defineEmits<{ remove: [] }>()

const iriRef = toRef(props, 'iri')
const entry = useCwaFormInput(iriRef, props.entryFullName)

function trailingIcon(field: { validating: { value: boolean }, valid: { value: boolean | null } }) {
  if (field.validating.value) return 'i-lucide-loader-circle'
  if (field.valid.value === true) return 'i-lucide-circle-check'
  return undefined
}

function trailingIconClass(field: { validating: { value: boolean }, valid: { value: boolean | null } }) {
  if (field.validating.value) return 'animate-spin text-gray-400'
  if (field.valid.value === true) return 'text-green-500'
  return undefined
}
</script>
