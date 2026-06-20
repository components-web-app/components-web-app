<template>
  <UFormField
    :label="field.vars.value?.label || 'Text'"
    :error="field.displayErrors.value ? field.errors.value[0] : undefined"
  >
    <div class="flex items-center gap-2">
      <UInput class="flex-1" v-model="field.value.value" @blur="field.onBlur" @input="field.onInput" />
      <UButton color="error" variant="soft" icon="i-lucide-trash-2" @click.prevent="$emit('remove')" />
    </div>
  </UFormField>
</template>

<script setup lang="ts">
import { toRef } from 'vue'

const props = defineProps<{ iri: string | undefined, entryFullName: string }>()
defineEmits<{ remove: [] }>()

const iriRef = toRef(props, 'iri')
const field = useCwaFormInput(iriRef, props.entryFullName)
</script>
