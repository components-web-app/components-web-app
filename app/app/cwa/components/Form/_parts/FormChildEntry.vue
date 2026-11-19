<template>
  <UFormField
    :label="name.vars.value?.label || 'Name'"
    :error="name.displayErrors.value ? name.errors.value[0] : undefined"
  >
    <div class="flex items-center gap-2">
      <UInput
        v-model="name.value.value"
        class="flex-1"
        :trailing-icon="trailingIcon(name)"
        :ui="{ trailingIcon: trailingIconClass(name) }"
        @blur="name.onBlur"
        @input="name.onInput"
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
const name = useCwaFormInput(iriRef, `${props.entryFullName}[name]`)

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
