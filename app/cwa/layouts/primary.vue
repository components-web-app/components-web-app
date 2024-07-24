<template>
  <div class="relative">
    <VitePwaManifest />
    <CwaUiProgressBar :show="showPageLoadBar" :percent="percent" class="page-progress-bar fixed left-0 top-0 z-[200]" />
    <Spinner :show="$cwa.resources.isLoading.value" class="absolute top-4 right-4 z-50" />
    <header v-if="$cwa.resources.layoutIri.value">
      <Popover class="relative">
        <div class="mx-auto flex max-w-7xl items-center p-6 justify-start space-x-10 lg:px-8">
          <PopoverGroup as="nav" class="space-x-5 flex">
            <CwaComponentGroup reference="top" :location="$cwa.resources.layoutIri.value" :allowed-components="['/component/navigation_links']" />
            <ClientOnly>
              <nuxt-link v-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_OUT" to="/login" class="text-base font-medium text-gray-500 hover:text-gray-900">
                Sign In
              </nuxt-link>
              <a v-else-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_IN" href="#" class="text-base font-medium text-gray-500 hover:text-gray-900" @click.prevent="signOut">
                Sign Out
              </a>
            </ClientOnly>
          </PopoverGroup>
        </div>
      </Popover>
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
import { Popover, PopoverGroup } from '@headlessui/vue'
import { computed } from 'vue'
import { CwaAuthStatus } from '#cwa/runtime/api/auth'
import Spinner from '#cwa/runtime/templates/components/utils/Spinner.vue'
import { useCwa } from '#imports'

const $cwa = useCwa()

const percent = computed(() => $cwa.resources.pageLoadProgress.value.percent || 3)
const showPageLoadBar = computed(() => percent.value < 100)

async function signOut () {
  if ($cwa.navigationDisabled) {
    return
  }
  await $cwa.auth.signOut()
}
</script>
