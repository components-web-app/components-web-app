<template>
  <div class="mt-8 border-t border-white/20 pt-8">
    <CwaComponentGroup reference="primary" :location="location" />
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
