# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

## Docs

Any change made to this template application must be reflected in the docs project at `/Users/danielwest/Documents/GitHub/_CWA/docs`. After completing work here, always check whether the docs need updating and flag it if so.

## Planned Features

### Form Composables Demo Component (#172)

The `@cwa/nuxt` module now ships `useCwaFormInput`, `useCwaForm`, and `useCwaFormRepeated` (composables-only; no built-in input components). A playground demo component is being built at `playground/app/cwa/components/ContactForm/ContactForm.vue`. Once the playground component is complete, the template should get a matching `app/cwa/components/ContactForm/ContactForm.vue` so users have a working example of forms out of the box.

**How the composables work (brief for template implementation):**

```vue
<script setup lang="ts">
const props = defineProps<IriProp>()
const { getResource, exposeMeta } = useCwaResource(toRef(props, 'iri'))
defineExpose(exposeMeta)

const form = useCwaForm(toRef(props, 'iri'))
const name = useCwaFormInput(toRef(props, 'iri'), 'contact_form[name]')
const email = useCwaFormInput(toRef(props, 'iri'), 'contact_form[email]')
const message = useCwaFormInput(toRef(props, 'iri'), 'contact_form[message]')
</script>

<template>
  <form @submit.prevent="form.submit()">
    <label>{{ name.vars.value?.label }}</label>
    <input v-model="name.value.value" @blur="name.onBlur" @input="name.onInput" />
    <p v-if="name.displayErrors.value">{{ name.errors.value[0] }}</p>
    <button type="submit" :disabled="form.submitting.value">Send</button>
    <p v-if="form.success.value">Thank you!</p>
    <p v-if="form.formErrors.value.length">{{ form.formErrors.value[0] }}</p>
  </form>
</template>
```

For a `RepeatedType` field (e.g. new password + confirm):
```ts
const password = useCwaFormRepeated(toRef(props, 'iri'), 'reset_password[password]')
// password.first and password.second each have: value, vars, errors, displayErrors, onBlur, onInput
```

**Key rules:**
- `value.value` is the field's local reactive value (bind to `v-model`)
- `onBlur` / `onInput` trigger validation; `displayErrors` gates when errors are shown
- POST forms: realtime per-field validation is disabled; errors only appear on submit
- PATCH forms: each field PATCHes on blur/input; errors show progressively
- `form.formErrors` reads root-level form errors reactively from the store

### GitHub Actions CI/CD

The template currently ships GitLab CI only (`.gitlab-ci.yml`). GitHub Actions support is planned. The shell functions in `bin/devops/` are the reusable CI primitives — a GitHub Actions implementation would write workflow YAML files (`.github/workflows/`) that call the same functions. This would allow teams on GitHub to get the same build/test/deploy pipeline without rewriting the logic.