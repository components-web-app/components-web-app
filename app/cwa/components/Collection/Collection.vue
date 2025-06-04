<template>
  <div class="pb-5 flex flex-col space-y-2">
    <CollectionSearch />
    <div
      v-if="collectionItems"
      class="relative pt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4 min-h-96"
    >
      <article
        v-for="post of collectionItems"
        :key="post['@id']"
        class="relative z-0 isolate flex flex-col justify-end bg-black/50 px-8 pb-8 pt-80 sm:pt-48 lg:pt-60"
      >
        <div
          v-if="!post.routePath"
          class="size-3 cwa:bg-orange rounded-full absolute top-0 left-0 -translate-1/2"
        >
          <span class="sr-only">Draft entry</span>
        </div>
        <div
          v-if="!post.image"
          class="absolute inset-0 -z-10 h-full w-full text-white flex justify-center items-center font-bold"
        >
          No Image
        </div>
        <CollectionImage
          v-else
          :iri="post.image"
          class="absolute inset-0 -z-10 h-full w-full object-cover"
        />
        <div class="absolute inset-0 -z-10 bg-linear-to-t from-black via-primary/10" />
        <div class="flex flex-wrap items-center gap-y-1 overflow-hidden text-sm leading-3 text-gray-300">
          <time
            :datetime="post.createdAt"
            class="mr-8"
          >{{ formatDate(post.createdAt) }}</time>
        </div>
        <h3 class="mt-3 text-lg font-semibold leading-6 text-white">
          <CwaLink :to="post.routePath || post['@id']">
            <span class="absolute inset-0" />
            {{ post.title }}
          </CwaLink>
        </h3>
      </article>
      <div
        v-if="!collectionItems.length"
        class="absolute top-0 left-0 right-0 bottom-0 flex justify-center items-center font-bold text-2xl text-primary"
      >
        No Results
      </div>
      <Transition
        enter-from-class="transform opacity-0"
        enter-active-class="duration-300 ease-out"
        enter-to-class="opacity-100"
        leave-from-class="opacity-100"
        leave-active-class="duration-300 ease-in"
        leave-to-class="transform opacity-0"
      >
        <div
          v-if="isLoadingCollection"
          class="absolute z-10 top-0 left-0 right-0 bottom-0 flex justify-center items-center"
        >
          <Spinner :show="true" />
        </div>
      </Transition>
    </div>
    <CollectionPagination
      class="w-full"
      :current-page="pageModel || 1"
      :total-pages="totalPages"
      :max-pages-to-display="7"
      @next="goToNextPage"
      @previous="goToPreviousPage"
      @change="changePage"
    />
  </div>
</template>

<script setup lang="ts">
import { toRef } from 'vue'
import dayjs from 'dayjs'
import Spinner from '#cwa/runtime/templates/components/utils/Spinner.vue'
import type { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaCollectionResource } from '#imports'

const props = defineProps<IriProp>()

const {
  exposeMeta,
  collectionItems,
  isLoadingCollection,
  pageModel,
  totalPages,
  goToNextPage,
  goToPreviousPage,
  changePage,
} = useCwaCollectionResource(toRef(props, 'iri'))

function formatDate(dateStr: string) {
  return dayjs(dateStr).format('DD/MM/YY')
}

defineExpose(exposeMeta)
</script>
