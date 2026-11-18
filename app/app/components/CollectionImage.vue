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
        v-show="loaded"
        ref="file"
        :src="contentUrl"
        :width="displayMedia?.width"
        :height="displayMedia?.height"
        class="object-contain object-left-top"
        @load="handleLoad"
      />
    </Transition>
    <div
      data-placeholder="true"
      class="absolute top-0 left-0 w-full h-full overflow-hidden bg-gray-200 pointer-events-none cwa:transition-opacity"
      :class="{ 'opacity-0': loaded }"
    />
  </div>
</template>

<script setup lang="ts">
import { useTemplateRef } from 'vue'
import { useCwa, useCwaFileField } from '#imports'

const props = defineProps<{
  iri: string
}>()

const $cwa = useCwa()

await $cwa.fetchResource({
  path: props.iri,
})

// v-show, not v-if: only this element's @load sets `loaded`; imageRef catches a cached image that loaded first (#267).
const imageRef = useTemplateRef<unknown>('file')
const { contentUrl, displayMedia, handleLoad, loaded } = useCwaFileField(props, { imagineFilterName: 'thumbnail', imageRef })
</script>
