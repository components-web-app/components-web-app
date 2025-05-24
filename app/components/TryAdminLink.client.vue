<script setup lang="ts">
import { CwaAuthStatus } from '#cwa/runtime/api/auth'
</script>

<template>
  <nuxt-link
    v-if="$cwa.auth.status.value === CwaAuthStatus.SIGNED_OUT"
    to="/login"
    class="text-primary brightness-150 transition justify-self-end py-1 rounded text-sm font-semibold opacity-90 hover:opacity-100 text-nowrap"
  >
    Try Admin
  </nuxt-link>
</template>
