<template>
  <form
    class="space-y-5 max-w-xl mx-auto py-8"
    @submit.prevent="form.submit()"
  >
    <h2 class="text-2xl font-bold">
      Example Form
    </h2>

    <UAlert
      v-if="form.success.value"
      color="success"
      icon="i-lucide-circle-check"
      title="Submitted!"
      description="Your form was submitted successfully."
    />
    <template v-else-if="form.formErrors.value.length || form.unregisteredFieldErrors.value.length">
      <UAlert
        v-if="form.formErrors.value.length"
        color="error"
        icon="i-lucide-circle-x"
        :description="form.formErrors.value[0]"
      />
      <UAlert
        v-if="form.unregisteredFieldErrors.value.length"
        color="error"
        icon="i-lucide-triangle-alert"
        title="Additional errors"
        :description="form.unregisteredFieldErrors.value.join(' · ')"
      />
    </template>

    <!-- text (TextType) -->
    <UFormField
      :label="text.vars.value?.label || 'Text'"
      :error="text.displayErrors.value ? text.errors.value[0] : undefined"
      :required="text.vars.value?.required"
    >
      <UInput
        v-model="text.value.value"
        class="w-full"
        @blur="text.onBlur"
        @input="text.onInput"
      />
    </UFormField>

    <!-- plainPassword (RepeatedType) -->
    <UFormField
      :label="password.first.vars.value?.label || 'Create Password'"
      :error="password.first.displayErrors.value ? password.first.errors.value[0] : undefined"
      required
    >
      <UInput
        v-model="password.first.value.value"
        type="password"
        class="w-full"
        autocomplete="new-password"
        @blur="password.first.onBlur"
        @input="password.first.onInput"
      />
    </UFormField>
    <UFormField
      :label="password.second.vars.value?.label || 'Repeat Password'"
      :error="password.second.displayErrors.value ? password.second.errors.value[0] : undefined"
      required
    >
      <UInput
        v-model="password.second.value.value"
        type="password"
        class="w-full"
        autocomplete="new-password"
        @blur="password.second.onBlur"
        @input="password.second.onInput"
      />
    </UFormField>

    <!-- subject (ChoiceType — collapsed select) -->
    <UFormField
      :label="subject.vars.value?.label || 'Regarding'"
      :error="subject.displayErrors.value ? subject.errors.value[0] : undefined"
      :required="subject.vars.value?.required"
    >
      <USelect
        v-model="subject.value.value"
        :items="subject.vars.value?.choices || []"
        class="w-full"
        @update:model-value="subject.onInput()"
        @blur="subject.onBlur"
      />
    </UFormField>

    <!-- email (EmailType) -->
    <UFormField
      :label="email.vars.value?.label || 'Email'"
      :error="email.displayErrors.value ? email.errors.value[0] : undefined"
      :required="email.vars.value?.required"
    >
      <UInput
        v-model="email.value.value"
        type="email"
        class="w-full"
        @blur="email.onBlur"
        @input="email.onInput"
      />
    </UFormField>

    <!-- message (TextareaType) -->
    <UFormField
      :label="message.vars.value?.label || 'Message'"
      :error="message.displayErrors.value ? message.errors.value[0] : undefined"
      :required="message.vars.value?.required"
    >
      <UTextarea
        v-model="message.value.value"
        class="w-full"
        @blur="message.onBlur"
        @input="message.onInput"
      />
    </UFormField>

    <!-- developer (ChoiceType — expanded, single = radio group) -->
    <UFormField
      :label="developer.vars.value?.label || 'Are you a developer?'"
      :error="developer.displayErrors.value ? developer.errors.value[0] : undefined"
      :required="developer.vars.value?.required"
    >
      <URadioGroup
        v-model="developer.value.value"
        :items="developer.vars.value?.choices || []"
        @change="developer.onInput()"
      />
    </UFormField>

    <!-- randomCheckbox (CheckboxType) -->
    <UFormField :error="checkbox.displayErrors.value ? checkbox.errors.value[0] : undefined">
      <UCheckbox
        v-model="isChecked"
        :label="checkbox.vars.value?.label || 'Check this box'"
        @change="checkbox.onInput()"
      />
    </UFormField>

    <!-- interests (ChoiceType — expanded, multiple = checkbox group) -->
    <UFormField
      :label="interests.vars.value?.label || 'Interests'"
      :error="interests.displayErrors.value ? interests.errors.value[0] : undefined"
      :required="interests.vars.value?.required"
    >
      <UCheckboxGroup
        v-model="interests.value.value"
        :items="interests.vars.value?.choices || []"
        @change="interests.onInput()"
      />
    </UFormField>

    <!-- other_interests (ChoiceType — collapsed, multiple = SelectMenu) -->
    <UFormField
      :label="otherInterests.vars.value?.label || 'Other Interests'"
      :error="otherInterests.displayErrors.value ? otherInterests.errors.value[0] : undefined"
      :required="otherInterests.vars.value?.required"
    >
      <USelectMenu
        v-model="otherInterests.value.value"
        :items="otherInterests.vars.value?.choices || []"
        :multiple="true"
        class="w-full"
        @update:model-value="otherInterests.onInput()"
      />
    </UFormField>

    <!-- children (CollectionType — compound ChildType with 'name' sub-field) -->
    <div class="space-y-3">
      <p class="text-sm font-medium">
        {{ children.vars.value?.label || 'Children' }}
      </p>
      <FormChildEntry
        v-for="entry in children.entries.value"
        :key="entry"
        :iri="props.iri"
        :entry-full-name="entry"
        @remove="children.removeEntry(entry)"
      />
      <p
        v-if="children.vars.value?.errors?.[0]"
        class="text-sm text-red-500"
      >
        {{ children.vars.value.errors[0] }}
      </p>
      <UButton
        v-if="children.vars.value?.allow_add"
        variant="soft"
        @click.prevent="children.addEntry()"
      >
        Add Child
      </UButton>
    </div>

    <!-- text_children (CollectionType — simple TextType entries) -->
    <div class="space-y-3">
      <p class="text-sm font-medium">
        {{ textChildren.vars.value?.label || 'Text Children' }}
      </p>
      <FormTextEntry
        v-for="entry in textChildren.entries.value"
        :key="entry"
        :iri="props.iri"
        :entry-full-name="entry"
        @remove="textChildren.removeEntry(entry)"
      />
      <UButton
        v-if="textChildren.vars.value?.allow_add"
        variant="soft"
        @click.prevent="textChildren.addEntry()"
      >
        Add Entry
      </UButton>
    </div>

    <UButton
      type="submit"
      :loading="form.submitting.value"
      :disabled="form.success.value"
    >
      Submit Form
    </UButton>
  </form>
</template>

<script setup lang="ts">
import { computed, toRef } from 'vue'
import type { IriProp } from '#cwa/composables/cwa-resource'

const props = defineProps<IriProp>()
const iriRef = toRef(props, 'iri')

const { exposeMeta } = useCwaResource(iriRef)
defineExpose(exposeMeta)

const form = useCwaForm(iriRef)

const text = useCwaFormInput(iriRef, 'example_form[text]')
const email = useCwaFormInput(iriRef, 'example_form[email]')
const message = useCwaFormInput(iriRef, 'example_form[message]')
const password = useCwaFormRepeated(iriRef, 'example_form[plainPassword]')
const subject = useCwaFormInput(iriRef, 'example_form[subject]')
const developer = useCwaFormInput(iriRef, 'example_form[developer]')

const checkbox = useCwaFormInput(iriRef, 'example_form[randomCheckbox]')
const isChecked = computed({
  get: () => checkbox.vars.value?.checked ?? false,
  set: (v: boolean) => {
    checkbox.value.value = v ? '1' : ''
    checkbox.onInput()
  },
})

const interests = useCwaFormInput(iriRef, 'example_form[interests]')
const otherInterests = useCwaFormInput(iriRef, 'example_form[other_interests]')
const children = useCwaFormCollection(iriRef, 'example_form[children]')
const textChildren = useCwaFormCollection(iriRef, 'example_form[text_children]')
</script>
