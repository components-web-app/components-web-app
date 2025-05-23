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
    <header>
      <div class="relative">
        <div class="mx-auto flex max-w-7xl items-center p-6 md:justify-start lg:px-8">
          <nav class="space-x-5 flex w-full items-center">
            <div class="space-x-5 md:space-x-5 flex items-center grow w-auto">
              <div>
                <LazySvgoLogo
                  :font-controlled="false"
                  class="text-white h-6 md:h-8 opacity-80"
                />
              </div>
              <div class="grow w-auto flex space-x-3 md:space-x-5 justify-end md:justify-start">
                <CwaComponentGroup
                  v-if="$cwa.resources.layoutIri.value"
                  reference="top"
                  :location="$cwa.resources.layoutIri.value"
                  :allowed-components="['/component/navigation_links']"
                />
              </div>
            </div>
            <ClientOnly>
              <nuxt-link
                v-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_OUT"
                to="/login"
                class="transition justify-self-end px-2.5 py-1 bg-white rounded text-base font-semibold text-background opacity-90 hover:opacity-100 text-nowrap"
              >
                Sign In
              </nuxt-link>
            </ClientOnly>
          </nav>
        </div>
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
        <div>
          <CwaComponentGroup
            reference="bottom"
            :location="$cwa.resources.layoutIri.value"
            :allowed-components="['/component/navigation_links']"
          />
        </div>
      </div>
      <div class="text-white/50 text-xs flex justify-between">
        <div>
          &copy; {{ (new Date()).getFullYear() }}
        </div>
        <div>
          <NuxtLink to="https://silverbackwebapps.com">site by Silverback Web Apps</NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { CwaAuthStatus } from '#cwa/runtime/api/auth'
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
