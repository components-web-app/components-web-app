<template>
  <UFormField
    :label="nameField.vars.value?.label || 'Name'"
    :error="nameField.displayErrors.value ? nameField.errors.value[0] : undefined"
  >
    <div class="flex items-center gap-2">
      <UInput class="flex-1" v-model="nameField.value.value" @blur="nameField.onBlur" @input="nameField.onInput" />
      <UButton color="error" variant="soft" icon="i-lucide-trash-2" @click.prevent="$emit('remove')" />
    </div>
  </UFormField>
</template>

<script setup lang="ts">
import { toRef } from 'vue'

const props = defineProps<{ iri: string | undefined, entryFullName: string }>()
defineEmits<{ remove: [] }>()

const iriRef = toRef(props, 'iri')
const nameField = useCwaFormInput(iriRef, `${props.entryFullName}[name]`)
</script>
