<template>
  <nav class="flex items-center justify-between border-t border-primary px-4 sm:px-0">
    <div class="-mt-px flex w-0 flex-1">
      <button :disabled="currentPage === 1" :class="nextPreviousClass" @click="$emit('previous')">
        <ArrowLongLeftIcon class="mr-3 h-5 w-5 text-current-color" aria-hidden="true" />
        Previous
      </button>
    </div>
    <div class="hidden md:-mt-px md:flex">
      <button
        v-for="page of pages"
        :key="`page-${page}`"
        class="inline-flex items-center border-t-2 px-4 pt-4 text-sm font-medium"
        :class="[page === currentPage ? selectedPageClass : pageClass]"
        :aria-current="page === currentPage ? 'page' : undefined"
        @click="$emit('change', page)"
      >
        {{ page }}
      </button>
    </div>
    <div class="-mt-px flex w-0 flex-1 justify-end">
      <button :disabled="currentPage === totalPages" :class="nextPreviousClass" @click="$emit('next')">
        Next
        <ArrowLongRightIcon class="ml-3 h-5 w-5 text-current-color" aria-hidden="true" />
      </button>
    </div>
  </nav>
</template>

<script setup lang="ts">
import { ArrowLongLeftIcon, ArrowLongRightIcon } from '@heroicons/vue/20/solid'
import {
  type CwaPaginationEmits,
  type CwaPaginationProps,
  useCwaCollectionPagination
} from '#cwa/runtime/composables/cwa-collection-pagination'

const pageClass = 'border-transparent text-gray-300 hover:border-gray-300 hover:text-white transition'
const selectedPageClass = 'border-primary text-primary'
const nextPreviousClass = 'inline-flex items-center border-t-2 border-transparent px-1 pt-4 text-sm font-medium text-gray-300 enabled:hover:border-gray-300 enabled:hover:text-white disabled:opacity-50'

const props = defineProps<CwaPaginationProps>()
defineEmits<CwaPaginationEmits>()
const { pages } = useCwaCollectionPagination(props)
</script>
