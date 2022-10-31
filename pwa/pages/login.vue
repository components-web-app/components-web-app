<template>
  <login-page>
    <template slot="login-message">
      <div class="notification is-dark">
        Please use the username and password 'admin' to login.
      </div>
    </template>
  </login-page>
</template>

<script>
import LoginPage from '@cwa/nuxt-module/core/templates/pages/login.vue'
export default {
  name: 'CwaDemoPageLogin',
  cwa: false,
  components: { LoginPage },
  layout: 'cwa-empty'
}
</script>
