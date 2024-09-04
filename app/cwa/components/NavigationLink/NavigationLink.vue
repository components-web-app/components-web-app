<template>
  <div>
    <nuxt-link :target="isExternal ? '_blank' : undefined" :to="resource?.data?.url || '#'" exact-active-class="!underline !opacity-100" class="text-xl font-medium text-white opacity-80 transition hover:opacity-100 hover:underline no-underline underline-offset-8 decoration-2" @click="handleClick">
      {{ resource?.data?.label || 'No Link Label' }}
    </nuxt-link>
  </div>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { computed, toRef } from 'vue'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const { getResource, exposeMeta, $cwa } = useCwaResource(toRef(props, 'iri'))
const resource = getResource()
defineExpose(exposeMeta)

const isExternal = computed(() => {
  return !!resource.value?.data?.rawPath
})

function handleClick (e: MouseEvent) {
  if (!isExternal.value) {
    return
  }

  $cwa.navigationDisabled && e.preventDefault()
}
</script>
