<template>
  <div>
    <input v-model="searchModel" type="text" name="search" class="block w-full rounded-md border-0 py-1.5 text-white shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-primary sm:text-sm sm:leading-6 bg-white/5" placeholder="Search">
  </div>
</template>
<script setup lang="ts">
import { useQueryBoundModel } from '#cwa/runtime/composables/cwa-query-bound-model'

const { model: searchModel } = useQueryBoundModel(['title'], {
  delay: 250
})
</script>
