<template>
  <div class="components-collection">
    <div class="columns filters">
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
    <client-only>
      <div v-if="$cwa.isAdmin">
        <button class="button" @click="showNewResourceModal = true">Add</button>
      </div>
    </client-only>
    <div class="collection-items">
      <div v-if="fetching" class="loading-overlay">&nbsp;</div>
      <div class="columns is-multiline">
        <div v-if="!items.length" class="column title is-size-5 has-text-grey">
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
    <cwa-add-dynamic-page-modal
      v-if="showNewResourceModal"
      :default-data="{}"
      :endpoint="resourceIri"
      resource-name="Blog Article"
      @close="showNewResourceModal = false"
      @refresh="refreshCollection"
    />
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import CollectionComponentMixin from '@cwa/nuxt-module/core/mixins/CollectionComponentMixin'
import { ComponentManagerTab } from '@cwa/nuxt-module/core/mixins/ComponentManagerMixin'
import CwaAddDynamicPageModal from '@cwa/nuxt-module/core/templates/components/admin/cwa-add-dynamic-page-modal.vue'
import BlogArticleCollectionItem from '~/components/collection/BlogArticleCollectionItem.vue'
import CollectionPagination from '~/components/collection/CollectionPagination.vue'
import CollectionSearchInput from '~/components/collection/CollectionSearchInput.vue'
import CollectionSelectInput from '~/components/collection/CollectionSelectInput.vue'

export default Vue.extend({
  components: {
    CwaAddDynamicPageModal,
    CollectionSelectInput,
    CollectionSearchInput,
    CollectionPagination,
    BlogArticleCollectionItem
  },
  mixins: [CollectionComponentMixin],
  data() {
    const resourceIri = '/page_data/blog_article_datas'
    return {
      // we can ask the front-end to dynamically load iris and save them in storage
      // ideally we get the API to return serialized objects
      collectionSubResourceKeys: [],
      componentManagerContext: {
        componentTab: {
          UiClassNames: [],
          UiComponents: []
        }
      },
      collectionResourceData: {},
      showNewResourceModal: false,
      resourceIri,
      defaultData: {
        resourceIri: '/page_data/blog_article_datas'
      },
      resourceName: 'Components Collection'
    }
  },
  computed: {
    pageOptions() {
      const ops = [
        {
          value: 6
        },
        {
          value: 12
        },
        {
          value: 24
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
        this.createCMTab(
          'Collection',
          () => import('../admin-dialog/ComponentsCollection.vue'),
          2,
          ['resourceIri', 'perPage', 'defaultQueryParameters']
        )
      ]
    }
  },
  created() {
    this.$emit('initialData', this.defaultData)
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
      background: rgba($body-background-color, .4)
      top: 0
      left: 0
      width: 100%
      height: 100%
      z-index: 10
</style>
