<template>
  <CwaLink
    :to="resource?.data?.url"
    exact-active-class="text-white!"
    class="md:text-sm font-medium text-white/80 transition no-underline tracking-wide hover:opacity-100 hover:text-gurkha-200 cursor-pointer"
  >
    {{ resource?.data?.label || 'No Link Label' }}
  </CwaLink>
</template>

<script setup lang="ts">
import type { IriProp } from '#cwa/composables/cwa-resource'
import { useCwaComponent, defineCwaConfig } from '#imports'

defineCwaConfig({
  name: 'Link',
  description: 'Use this component to display a link for a website user to click so they can visit another page or URL',
  icon: 'link',
  group: 'Navigation',
})

const props = defineProps<IriProp>()
const { resource, exposeMeta } = useCwaComponent(props)
defineExpose(exposeMeta)
</script>
