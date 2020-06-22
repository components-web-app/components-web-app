<template>
  <div>
    <div class="navbar">
      <div class="container">
        <ul v-if="routes" class="row">
          <li v-for="route of sortedRoutes" :key="route['@id']" class="column">
            <nuxt-link :to="route.path" :class="{ selected: route.path === $route.path }">
              {{ route.name }}
            </nuxt-link>
          </li>
          <li class="column">
            <button v-if="$auth.loggedIn" @click="$auth.logout('local')">
              Logout
            </button>
            <nuxt-link v-else to="/login" tag="button">
              Login
            </nuxt-link>
          </li>
        </ul>
        <ul v-else>
          <li>
            <span>Loading routes</span>
          </li>
        </ul>
      </div>
    </div>
    <div v-if="$cwa.resourcesOutdated" class="container refresh-bar">
      <span>The content on this page is outdated.</span> <button class="is-warning" @click="$cwa.mergeNewResources()">
        Update page
      </button>
    </div>
    <div class="container loading-message">
      <p v-if="$cwa.$state.loadingRoute" class="loading">
        Loading Route
      </p>
      <p v-else-if="$cwa.$state.error" class="error">
        {{ $cwa.$resources.error }}
      </p>
      <p v-else class="loaded">
        Route Loaded
      </p>
    </div>
    <nuxt />
  </div>
</template>

<script>
import consola from 'consola'

export default {
  computed: {
    sortedRoutes () {
      return [...this.routes].sort(this.dynamicSort('path'))
    },
    routes () {
      return this.$cwa.$storage.getState('routes')
    }
  },
  methods: {
    dynamicSort (property) {
      let sortOrder = 1

      if (property[0] === '-') {
        sortOrder = -1
        property = property.substr(1)
      }

      return function (a, b) {
        if (sortOrder === -1) {
          return b[property].localeCompare(a[property])
        } else {
          return a[property].localeCompare(b[property])
        }
      }
    }
  },
  async middleware ({ $axios, $cwa }) {
    if ($cwa.$storage.getState('routes')) { return }
    try {
      const { data } = await $axios.get('/_/routes')
      $cwa.$storage.setState('routes', data['hydra:member'])
    } catch (err) {
      consola.error(err)
    }
  }
}
</script>

<style lang="sass" scoped>
  .loading-message
    .loading
      color: $color-warning
    .error
      color: $color-danger
    .loaded
      color: $color-success
  .refresh-bar
    display: flex
    justify-content: center
    align-items: center
    button
      margin: 0 0 0 1rem
  .navbar
    margin-bottom: 1.25rem
    background-color: $color-secondary
    padding: 0 .75rem
    ul.row
      list-style-type: none
      margin: 0
      padding: 0
      overflow: hidden
      display: flex
      height: 100%
      li.column
        margin-bottom: 0
        display: flex
        align-items: center
        width: auto
        flex-grow: 0
        padding: 0
        &:last-child
          margin-left: auto
          justify-self: flex-end
        a,
        span
          display: block
          text-decoration: none
          padding: 1.25rem 2rem
          color: white
          text-align: center
        a
          &:hover,
          &.selected
            background-color: $color-primary
        button
          display: block
          margin: 0 0 0 1rem
          &:hover
            border: 1px solid $color-primary
            background: $color-initial
            color: $color-primary
</style>
