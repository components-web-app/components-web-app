<template>
  <div v-if="resource" class="column is-4">
    <div class="blog-collection-item">
      <div class="box">
        <h4 class="is-size-4">{{ resource.title }}</h4>
        <nuxt-link :to="routePath" class="button">{{
          routePath !== '#' ? 'View Article' : '...'
        }}</nuxt-link>
        <p class="created-date">
          {{ formatDate(parseDateString(resource.createdAt)) }}
        </p>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import ApiDateParserMixin from '@cwa/nuxt-module/core/mixins/ApiDateParserMixin'
import ResolveRoutePathMixin from '@cwa/nuxt-module/core/mixins/ResolveRoutePathMixin'

export default Vue.extend({
  mixins: [ComponentMixin, ApiDateParserMixin, ResolveRoutePathMixin],
  data() {
    return {
      componentManagerDisabled: true
    }
  },
  computed: {
    routePath() {
      return this.resolveRoutePath(this.resource.route)
    }
  }
})
</script>

<style lang="sass">
.blog-collection-item
  position: relative
  display: block
  .box
    border: 1px solid $cwa-grid-item-border-color
    background: $cwa-grid-item-background
    color: $white
    padding: 1.5rem
    overflow: auto
    font-size: $size-7
    .created-date
      margin: .5rem 0 0
    h4
      margin-bottom: .3rem
</style>
