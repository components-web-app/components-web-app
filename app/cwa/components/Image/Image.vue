<template>
  <div class="w-full relative my-5">
    <div v-if="displayMedia" class="relative flex overflow-hidden max-w-[300px]" :style="{ 'aspect-ratio': `${displayMedia.width} / ${displayMedia.height}` }">
      <NuxtImg
        v-if="displayMedia"
        ref="image"
        :src="contentUrl"
        :width="displayMedia?.width"
        :height="displayMedia?.height"
        class="object-contain object-left-top"
        @load="handleLoad"
      />
      <div data-placeholder="true" class="absolute top-0 left-0 w-full h-full overflow-hidden bg-gray-200 pointer-events-none cwa-transition-opacity" :class="{ 'opacity-0': loaded }" />
    </div>
    <div v-else>
      <div data-placeholder="true" class="relative w-40 h-40 overflow-hidden bg-gray-200 pointer-events-none flex items-center justify-center text-gray-500 font-bold">
        No Image
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import { useCwaImage, type IriProp } from '#imports'

const props = defineProps<IriProp>()
const iri = toRef(props, 'iri')

const { exposeMeta, contentUrl, displayMedia, handleLoad, loaded } = useCwaImage(iri, 'thumbnail')
defineExpose(exposeMeta)
</script>
