<template>
  <nav class="row pagination" role="navigation" aria-label="pagination">
    <div class="column">
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
        <li v-for="navPage in pageNavigation" :key="`goto-page-${navPage}`">
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
    </div>
    <div class="column is-narrow page-next-previous-buttons">
      <a
        :disabled="page === 1"
        aria-label="Go to previous page"
        class="button pagination-previous"
        @click="goToPage(page - 1)"
        >Previous</a
      >
      <a
        :disabled="page === lastPage"
        aria-label="Go to next page"
        class="button pagination-next"
        @click.stop="goToPage(page + 1)"
        >Next</a
      >
    </div>
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
  .page-next-previous-buttons
    white-space: nowrap
  .pagination-list
    list-style: none
    flex-grow: 1
    flex-shrink: 1
    justify-content: flex-start
    order: 1
    flex-wrap: wrap
    align-items: center
    display: flex
    text-align: center
    li
      &:not(:last-child)
        margin-right: .5rem
      .pagination-link:not(.is-current):not(:hover)
        background: $cwa-background-light
        color: $cwa-color-primary
</style>
