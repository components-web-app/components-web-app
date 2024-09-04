<template>
  <div>
    <nuxt-link :target="isExternal ? '_blank' : undefined" :to="resource?.data?.url || '#'" exact-active-class="!text-gray-900 underline" class="text-base font-medium text-gray-500 hover:text-gray-900 no-underline" @click="handleClick">
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
