<template>
  <div class="flex items-start gap-2">
    <UFormField
      class="flex-1"
      :label="nameField.vars.value?.label"
      :error="nameField.displayErrors.value ? nameField.errors.value[0] : undefined"
    >
      <UInput
        v-model="nameField.value.value"
        @blur="nameField.onBlur"
        @input="nameField.onInput"
      />
    </UFormField>
    <UButton
      color="error"
      variant="soft"
      class="mt-6"
      @click="$emit('remove')"
    >
      Remove
    </UButton>
  </div>
</template>

<script setup lang="ts">
import { toRef } from 'vue'

const props = defineProps<{ iri: string | undefined, entryFullName: string }>()
defineEmits<{ remove: [] }>()

const iriRef = toRef(props, 'iri')
const nameField = useCwaFormInput(iriRef, `${props.entryFullName}[name]`)
</script>
