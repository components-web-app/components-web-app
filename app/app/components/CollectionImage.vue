<template>
  <div>
    <Transition
      enter-from-class="transform opacity-0"
      enter-active-class="duration-300 ease-out"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-active-class="duration-300 ease-in"
      leave-to-class="transform opacity-0"
    >
      <NuxtImg
        v-if="loaded"
        ref="image"
        :src="contentUrl"
        :width="displayMedia?.width"
        :height="displayMedia?.height"
        class="object-contain object-left-top"
        @load="handleLoad"
      />
    </Transition>
    <div data-placeholder="true" class="absolute top-0 left-0 w-full h-full overflow-hidden bg-gray-200 pointer-events-none cwa-transition-opacity" :class="{ 'opacity-0': loaded }" />
  </div>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import { useCwa } from '#imports'

const props = defineProps<{
  iri: string
}>()

const $cwa = useCwa()

await $cwa.fetchResource({
  path: props.iri
})

const {  contentUrl, displayMedia, handleLoad, loaded } = useCwaImageResource(toRef(props, 'iri'), { imagineFilterName: 'thumbnail' })
</script>
