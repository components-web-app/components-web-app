<template>
  <div :class="['relative', 'grow', 'flex', 'flex-col', ...($cwa.resources.layout?.value?.data?.uiClassNames || [])]">
    <VitePwaManifest />
    <CwaUiProgressBar
      :show="showPageLoadBar"
      :percent="percent"
      class="page-progress-bar fixed left-0 top-0 z-200"
    />
    <Spinner
      :show="$cwa.resources.isLoading.value"
      class="absolute top-4 right-4 z-50"
    />
    <header class="relative bg-stone-900 border-b border-b-stone-700">
      <div class="mx-auto flex max-w-7xl items-center p-6 md:justify-start lg:px-8">
        <nav class="space-x-5 flex w-full items-center">
          <div class="space-x-5 md:space-x-5 flex items-center grow w-auto">
            <div>
              <NuxtLink to="/">
                <LazySvgoLogo
                  :font-controlled="false"
                  class="text-white h-6 md:h-6"
                />
              </NuxtLink>
            </div>
            <div class="grow w-auto flex gap-x-3 md:gap-x-5 justify-center items-center">
              <CwaComponentGroup
                v-if="$cwa.resources.layoutIri.value"
                reference="top"
                :location="$cwa.resources.layoutIri.value"
                :allowed-components="['/component/navigation_links']"
              />
              <TryAdminLink />
            </div>
            <div class="leading-0">
              <NuxtLink
                to="https://silverbackwebapps.com"
                target="_blank"
                class="inline-block text-white/80 hover:text-white transition h-6.5 md:h-6.5"
              >
                <LazySvgoLogoSwa
                  :font-controlled="false"
                  class="h-full"
                />
              </NuxtLink>
            </div>
          </div>
        </nav>
      </div>
    </header>
    <div class="bg-inherit grow flex">
      <slot />
    </div>
    <div
      v-if="$cwa.resources.layoutIri.value"
      class="pt-12 pb-4 px-10 bg-black/40 flex flex-col gap-y-4"
    >
      <div class="flex justify-center">
        <div class="flex gap-x-4 items-center">
          <CwaComponentGroup
            reference="bottom"
            :location="$cwa.resources.layoutIri.value"
            :allowed-components="['/component/navigation_links']"
          />
          <TryAdminLink />
        </div>
      </div>
      <div class="text-white/50 text-xs flex justify-between">
        <div>
          &copy; {{ (new Date()).getFullYear() }}
        </div>
        <div>
          <CwaLink
            to="https://silverbackwebapps.com"
            target="_blank"
            :no-prefetch="undefined"
            :prefetch="false"
          >
            site by Silverback Web Apps
          </CwaLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import Spinner from '#cwa/runtime/templates/components/utils/Spinner.vue'
import { useCwa } from '#imports'
import { useHead } from '#app'

const $cwa = useCwa()

const percent = computed(() => $cwa.resources.pageLoadProgress.value.percent || 3)
const showPageLoadBar = computed(() => percent.value < 100)

useHead({
  htmlAttrs: {
    class: 'bg-black',
  },
  bodyAttrs: {
    class: 'bg-background',
  },
})
</script>
