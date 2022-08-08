<template>
  <nav class="pagination" role="navigation" aria-label="pagination">
    <button
      :disabled="page === 1"
      type="button"
      aria-label="Go to previous page"
      class="button pagination-previous"
      @click="goToPage(page - 1)"
    >
      Previous
    </button>
    <button
      :disabled="page === lastPage"
      type="button"
      aria-label="Go to next page"
      class="button pagination-next"
      @click.stop="goToPage(page + 1)"
    >
      Next
    </button>
    <ul class="pagination-list">
      <li v-if="forceFirstPageLink">
        <a
          :aria-label="`Go to page 1`"
          :class="['button', 'pagination-link']"
          @click.stop="goToPage(1)"
        >
          1 ..
        </a>
      </li>
      <li v-for="navPage in pageNavigation" :key="`page-link-${navPage}`">
        <a
          :aria-label="`Goto page ${navPage}`"
          :aria-current="page === navPage ? 'page' : null"
          :class="[
            'button',
            'pagination-link',
            { 'is-current': page === navPage }
          ]"
          @click.stop="goToPage(navPage)"
        >
          {{ navPage }}
        </a>
      </li>
      <li v-if="forceLastPageLink">
        <a
          :aria-label="`Go to page ${lastPage}`"
          :class="['button', 'pagination-link']"
          @click.stop="goToPage(lastPage)"
        >
          .. {{ lastPage }}
        </a>
      </li>
    </ul>
  </nav>
</template>

<script lang="ts">
import Vue from 'vue'
import CollectionPaginationMixin from '@cwa/nuxt-module/core/mixins/CollectionPaginationMixin'

export default Vue.extend({
  mixins: [CollectionPaginationMixin]
})
</script>

<style lang="sass">
.pagination
  margin: 2rem 0
</style>
