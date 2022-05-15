<template>
  <div v-if="resource" class="blog-collection-item">
    <div class="box">
      <h4>{{ resource.title }}</h4>
      <nuxt-link :to="routePath" class="button">{{
        routePath !== '#' ? 'View Article' : '...'
      }}</nuxt-link>
      <p class="created-date">
        {{ formatDate(parseDateString(resource.createdAt)) }}
      </p>
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
  .box
    border: 1px solid $cwa-grid-item-border-color
    background: $cwa-grid-item-background
    color: $white
    padding: 1.5rem
    overflow: auto
    margin-bottom: 1.5rem
    .created-date
      margin: 0
</style>
