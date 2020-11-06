<template>
  <div>
    <cwa-admin-bar />
    <div class="navbar">
      <div class="container">
        <ul class="row">
          <li class="column">
            <button v-if="$auth.loggedIn" @click="$auth.logout('local')">
              Logout
            </button>
            <nuxt-link v-else to="/login" tag="button"> Login </nuxt-link>
          </li>
        </ul>
      </div>
    </div>

    <div v-if="$cwa.resourcesOutdated" class="container refresh-bar">
      <span>The content on this page is outdated.</span>
      <button class="is-warning" @click="$cwa.mergeNewResources()">
        Update page
      </button>
    </div>

    <div class="container loading-message">
      <p v-if="$cwa.$state.error" class="error">
        {{ $cwa.$state.error }}
      </p>
    </div>
    <nuxt />
    <cwa-api-notifications class="cwa-notifications" />
  </div>
</template>

<script>
import CwaApiNotifications from '@cwa/nuxt-module/core/templates/components/cwa-api-notifications/cwa-api-notifications.vue'
import CwaAdminBar from '@cwa/nuxt-module/core/templates/components/cwa-admin-bar.vue'

export default {
  components: { CwaAdminBar, CwaApiNotifications },
  methods: {
    dynamicSort(property) {
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
    },
  },
}
</script>

<style lang="sass" scoped>
.loading-message
  .error
    color: $color-danger
.refresh-bar
  display: flex
  justify-content: center
  align-items: center
  button
    margin: 0 0 0 1rem
.navbar
  margin-bottom: 1.25rem
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
          background-color: $cwa-color-primary
      button
        display: block
        margin: 0 0 0 1rem
        &:hover
          border: 1px solid $cwa-color-primary
          background: $cwa-color-initial
          color: $cwa-color-primary
.cwa-notifications
  position: absolute
  bottom: 1rem
  right: 1rem
  width: 70vw
  max-width: 500px
</style>
