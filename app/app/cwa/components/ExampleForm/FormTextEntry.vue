<template>
  <div class="flex items-start gap-2">
    <UFormField
      class="flex-1"
      :error="field.displayErrors.value ? field.errors.value[0] : undefined"
    >
      <UInput
        v-model="field.value.value"
        @blur="field.onBlur"
        @input="field.onInput"
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
const field = useCwaFormInput(iriRef, props.entryFullName)
</script>
