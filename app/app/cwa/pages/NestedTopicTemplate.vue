<template>
  <div class="mx-auto w-full max-w-7xl py-10 px-4 lg:px-8">
    <CwaComponentGroup reference="primary" :location="location" />
    <CwaPage />
  </div>
</template>

<script setup lang="ts">
import { computed, inject } from 'vue'
import type { ComputedRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'

const props = defineProps<IriProp>()
const pageDataIri = inject<ComputedRef<string | undefined>>('cwa-page-data-iri')
const location = computed(() => pageDataIri?.value ?? props.iri)
</script>
