<template>
  <CwaAuthLoginPage
    v-model="credentials"
    :error="error"
    :submitting="submitting"
    submit-button-text="Sign In"
    @submit="signIn"
  >
    <template #header>
      <div class="py-2 px-3 border border-slate-600 bg-slate-900 rounded text-sm font-bold">
        Use the username and password "admin" to log in to this preview version of CWA
      </div>
    </template>
  </CwaAuthLoginPage>
</template>

<script setup lang="ts">
import { useHead } from '#app'
import { CwaAuthLoginPage } from '#components'
import { definePageMeta, useLogin } from '#imports'

const { error, submitting, signIn, credentials } = useLogin()

definePageMeta({
  cwa: {
    disabled: true,
  }
})

useHead({
  title: 'Login',
  bodyAttrs: {
    class: 'cwa-h-full'
  },
  htmlAttrs: {
    class: 'cwa-h-full cwa-bg-neutral-900'
  }
})
</script>
