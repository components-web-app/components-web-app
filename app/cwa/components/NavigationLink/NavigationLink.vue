<template>
  <div>
    <nuxt-link
      :target="isExternal ? '_blank' : undefined"
      :to="resource?.data?.url || '#'"
      exact-active-class="text-white!"
      class="md:text-sm font-medium text-white/80 transition no-underline tracking-wide hover:opacity-100 hover:text-gurkha-200"
      @click="handleClick"
    >
      {{ resource?.data?.label || 'No Link Label' }}
    </nuxt-link>
  </div>
</template>

<script setup lang="ts">
import { computed, toRef } from 'vue'
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaResource } from '#imports'

const props = defineProps<IriProp>()

const { getResource, exposeMeta, $cwa } = useCwaResource(toRef(props, 'iri'))
const resource = getResource()
defineExpose(exposeMeta)

const isExternal = computed(() => {
  return !!resource.value?.data?.rawPath
})

function handleClick(e: MouseEvent) {
  if (!isExternal.value) {
    return
  }

  $cwa.navigationDisabled && e.preventDefault()
}
</script>
