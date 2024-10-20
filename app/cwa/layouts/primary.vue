<template>
  <div :class="['relative', 'flex-grow', 'flex', 'flex-col', ...($cwa.resources.layout?.value?.data?.uiClassNames || [])]">
    <VitePwaManifest />
    <CwaUiProgressBar :show="showPageLoadBar" :percent="percent" class="page-progress-bar fixed left-0 top-0 z-[200]" />
    <Spinner :show="$cwa.resources.isLoading.value" class="absolute top-4 right-4 z-50" />
    <header v-if="$cwa.resources.layoutIri.value">
      <div class="relative">
        <div class="mx-auto flex max-w-7xl items-center p-6 md:justify-start lg:px-8">
          <nav class="space-x-5 flex w-full items-center">
            <div class="space-x-5 md:space-x-5 flex items-center flex-grow w-auto">
              <div>
                <LazySvgoLogo :font-controlled="false" class="text-white h-6 md:h-8 opacity-80" />
              </div>
              <div class="flex-grow w-auto flex space-x-3 md:space-x-5 justify-end md:justify-start">
                <CwaComponentGroup reference="top" :location="$cwa.resources.layoutIri.value" :allowed-components="['/component/navigation_links']" />
              </div>
            </div>
            <ClientOnly>
              <nuxt-link v-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_OUT" to="/login" class="transition justify-self-end px-2.5 py-1 bg-white rounded text-base font-semibold text-background opacity-90 hover:opacity-100 text-nowrap">
                Sign In
              </nuxt-link>
            </ClientOnly>
          </nav>
        </div>
      </div>
    </header>
    <div class="bg-inherit">
      <slot />
    </div>
    <div v-if="$cwa.resources.layoutIri.value">
      <CwaComponentGroup reference="bottom" :location="$cwa.resources.layoutIri.value" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { CwaAuthStatus } from '#cwa/runtime/api/auth'
import Spinner from '#cwa/runtime/templates/components/utils/Spinner.vue'
import { useCwa } from '#imports'

const $cwa = useCwa()

const percent = computed(() => $cwa.resources.pageLoadProgress.value.percent || 3)
const showPageLoadBar = computed(() => percent.value < 100)
</script>
