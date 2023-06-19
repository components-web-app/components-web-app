<template>
  <div>
    <CwaUtilsProgressBar :show="$cwa.resources.pageLoadProgress.value.percent < 100" :percent="$cwa.resources.pageLoadProgress.value.percent || 3" class="page-progress-bar" />
    <CwaUtilsSpinner :show="$cwa.resources.isLoading.value === true" class="page-spinner" />
    <header>
      <Popover class="relative bg-white">
        <div class="mx-auto flex max-w-7xl items-center p-6 justify-start space-x-10 lg:px-8">
          <PopoverGroup as="nav" class="space-x-5 flex">
            <CwaComponentGroup reference="top" :location="$cwa.resources.layoutIri.value" :allowed-components="['/component/navigation_links']" />
            <nuxt-link v-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_OUT" to="/login" class="text-base font-medium text-gray-500 hover:text-gray-900">
              Sign In
            </nuxt-link>
            <a v-else-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_IN" href="#" class="text-base font-medium text-gray-500 hover:text-gray-900" @click.prevent="signOut">
              Sign Out
            </a>
          </PopoverGroup>
        </div>
      </Popover>
    </header>
    <div>
      <slot />
    </div>
    <div>
      <CwaComponentGroup reference="bottom" :location="$cwa.resources.layoutIri.value" />
    </div>
  </div>
</template>

<script setup>
import { useCwa } from '#imports'
import { Popover, PopoverGroup } from '@headlessui/vue'
import { CwaAuthStatus } from '#cwa/runtime/api/auth'

async function signOut () {
  await useCwa().auth.signOut()
}
</script>

<style>
.page-spinner {
  position: absolute;
  top: 1rem;
  right: 1rem;
  z-index: 1000;
}
.page-progress-bar {
  position: absolute;
  top: 0;
  left: 0;
  z-index: 1000;
}
</style>
