<template>
  <div class="components-collection">
    <div class="row filters">
      <div class="column">
        <collection-search-input
          :query-fields="['title']"
          :static-query-parameters="[{ key: 'page', value: 1 }]"
        />
      </div>
      <div class="column is-narrow">
        <collection-select-input
          :query-fields="['order']"
          :static-query-parameters="[{ key: 'page', value: 1 }]"
          :options="[
            {
              value: 'desc',
              label: 'Newest first',
              queryKey: 'createdAt'
            },
            {
              value: 'asc',
              label: 'Oldest first',
              queryKey: 'createdAt'
            },
            {
              value: 'asc',
              label: 'Title A-Z',
              queryKey: 'title'
            },
            {
              value: 'desc',
              label: 'Title Z-A',
              queryKey: 'title'
            }
          ]"
        />
      </div>
      <div class="column is-narrow">
        <collection-select-input
          :query-fields="['perPage']"
          :static-query-parameters="[{ key: 'page', value: 1 }]"
          :default-selected-option-index="defaultPageOptionIndex"
          :options="pageOptions"
        />
      </div>
    </div>
    <div class="collection-items">
      <div v-if="fetching" class="loading-overlay">&nbsp;</div>
      <div class="row row-wrap">
        <div v-if="!items.length">
          {{
            resource._metadata._isNew
              ? 'Items will load once the component has been added'
              : 'No items to display'
          }}
        </div>
        <blog-article-collection-item
          v-for="item of items"
          v-else
          :key="`blog-item-${item['@id']}`"
          :iri="item['@id']"
          class="column column-50"
        />
      </div>
    </div>
    <collection-pagination
      v-if="resource.collection"
      :collection="resource.collection"
    />
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import CollectionComponentMixin from '@cwa/nuxt-module/core/mixins/CollectionComponentMixin'
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'
import BlogArticleCollectionItem from '~/components/collection/BlogArticleCollectionItem.vue'
import CollectionPagination from '~/components/collection/CollectionPagination.vue'
import CollectionSearchInput from '~/components/collection/CollectionSearchInput.vue'
import CollectionSelectInput from '~/components/collection/CollectionSelectInput.vue'

export default Vue.extend({
  components: {
    CollectionSelectInput,
    CollectionSearchInput,
    CollectionPagination,
    BlogArticleCollectionItem
  },
  mixins: [CollectionComponentMixin],
  data() {
    return {
      // we can ask the front-end to dynamically load iris and save them in storage
      // ideally we get the API to return serialized objects
      collectionSubResourceKeys: [],
      componentManagerContext: {
        componentTab: {
          UiClassNames: [],
          UiComponents: []
        }
      }
    }
  },
  computed: {
    pageOptions() {
      const ops = [
        {
          value: 4
        },
        {
          value: 10
        },
        {
          value: 20
        }
      ]
      if (this.resource.perPage) {
        for (const { value } of ops) {
          if (value === this.resource.perPage) {
            return ops
          }
        }
        return [
          ...ops,
          {
            value: this.resource.perPage
          }
        ]
      }
      return ops
    },
    defaultPageOptionIndex() {
      if (this.resource.perPage) {
        for (const [index, { value }] of this.pageOptions.entries()) {
          if (value === this.resource.perPage) {
            return index
          }
        }
      }
      return 1
    },
    componentManagerTabs(): ComponentManagerTab[] {
      return [
        {
          label: 'Collection',
          component: () => import('../admin-dialog/ComponentsCollection.vue'),
          priority: 2,
          inputFieldsUsed: ['resourceIri', 'perPage', 'defaultQueryParameters']
        }
      ]
    }
  },
  created() {
    this.$emit('initial-data', {
      resourceIri: '/page_data/blog_article_datas'
    })
  }
})
</script>

<style lang="sass">
.components-collection
  .collection-items
    position: relative
    margin-top: 1.5rem
    .loading-overlay
      position: absolute
      background: rgba($white, .4)
      top: 0
      left: 0
      width: 100%
      height: 100%
      z-index: 10
</style>
