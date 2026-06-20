# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

## Docs

Any change made to this template application must be reflected in the docs project at `/Users/danielwest/Documents/GitHub/_CWA/docs`. After completing work here, always check whether the docs need updating and flag it if so.

## Planned Features

### Project Installer / Scaffolder CLI

Rather than maintaining a separate skeleton branch, the plan is to build a `create-cwa-app` CLI installer that scaffolds a new CWA project interactively. This is a better long-term approach because it keeps `main` as the single source of truth and eliminates branch drift.

**What it would do:**
- Prompt: GitLab CI or GitHub Actions?
- Prompt: which components to include? (nav, forms, blog, collections, etc.)
- Output a ready-to-run project with only what was selected

**Minimal skeleton component (for installer default):**
- One custom entity with a single plain `text: string` field (e.g. `TextBlock`) — no rich-text editor dependencies, no opinionated UI libraries
- One page template (`PrimaryPageTemplate`) with a single component group
- One fixture that creates the page and adds a `TextBlock` to it
- No `HtmlContent`, `Image`, `BlogArticleData`, `NestedPageData`, `NavigationLink`, or collection components in the default output

**Dependency philosophy:** The skeleton/default output should have minimal, unopinionated dependencies. `HtmlContent` is excluded from the default because it requires a rich-text editor (Tiptap etc.) which is an opinionated choice.

**GitHub issue:** [#56](https://github.com/components-web-app/components-web-app/issues/56)

**Docs:** The docs will need a new "Install" section documenting the CLI and the available prompts. Flag to docs CLAUDE.md when this is implemented.

---

### Form Composables Demo Component (#172)

The `@cwa/nuxt` module ships four form composables. The playground demo is at `playground/app/cwa/components/ExampleForm/ExampleForm.vue` in the module repo. Mirror it here so new projects start with a working example.

> **Naming**: The component directory was renamed from `Form/` → `ExampleForm/` to avoid IDE confusion between the `Form` Vue component and the native `<form>` HTML element. Use `ExampleForm` throughout.

**Files to create/update:**

1. **`app/cwa/components/ExampleForm/ExampleForm.vue`** — the main CWA component (auto-imported as `CwaComponentExampleForm`) using `ExampleFormType` field names. Replace any current stub.

2. **`app/cwa/components/ExampleForm/FormChildEntry.vue`** — sub-component for compound `ChildType` collection entries (one `name` sub-field). Called via `v-for` over `children.entries.value`. Calls `useCwaFormInput(toRef(props, 'iri'), entryFullName + '[name]')`. Import it directly in `ExampleForm.vue` (it is not itself a CWA component): `import FormChildEntry from './FormChildEntry.vue'`.

3. **`app/cwa/components/ExampleForm/FormTextEntry.vue`** — sub-component for simple `TextType` collection entries. Calls `useCwaFormInput(toRef(props, 'iri'), entryFullName)`. Import directly: `import FormTextEntry from './FormTextEntry.vue'`.

**Also install `@nuxt/ui` and add `<UApp>` to `app/app.vue`.**

**Composable quick reference:**

| Composable | Use for |
|---|---|
| `useCwaFormInput(iri, fullName)` | Any single field |
| `useCwaFormRepeated(iri, fullName)` | Symfony `RepeatedType` — returns `{ first, second }` |
| `useCwaFormCollection(iri, fullName)` | Symfony `CollectionType` — returns `{ entries, addEntry, removeEntry, vars }` |
| `useCwaForm(iri)` | Form lifecycle — returns `{ submit, submitting, success, formErrors, unregisteredFieldErrors }` |

**Key implementation rules:**
- `field.value.value` = reactive field value → bind with `v-model="field.value.value"`
- `field.vars.value?.choices` = Symfony ChoiceView array `[{ value, label }]` → pass as `:items` to `USelect` / `URadioGroup` / `UCheckboxGroup` / `USelectMenu`
- `field.displayErrors.value` gates when to show `field.errors.value[0]` — triggered by blur, having-been-valid, or submit attempt; automatically suppressed while `field.validating.value` is true so stale errors do not flash during a pending PATCH
- `form.formErrors.value` = root-level Symfony errors
- `form.unregisteredFieldErrors.value` = API errors for fields not bound to any `useCwaFormInput` — show in a fallback block, never alongside registered field errors
- **CheckboxType pattern**: `useCwaFormInput` initialises `value` as `'1'` (checked) or `null` (unchecked), derived from `vars.checked`. Bind to an app-level computed: `get: () => !!checkbox.value.value`, `set: (v) => { checkbox.value.value = v ? '1' : null; checkbox.onInput() }`. Do NOT read `vars.value?.checked` — that snaps back before the PATCH returns. Sending `null` for unchecked is required: Symfony's `BooleanToStringTransformer` only treats `null` as `false`; `""` is silently treated as `true`.
- **ChoiceType (expanded, single = radio group)**: children in the `formView` tree share the same `full_name` as the parent. `useCwaFormInput` reads from the parent entry (which has `choices`, `label`). Use `vars.value?.choices` as `:items` for `URadioGroup`.
- **ChoiceType (not-expanded, multiple = multi-select)**: Symfony appends `[]` to `full_name` (e.g. `example_form[other_interests][]`). The module normalises this — use the key WITHOUT `[]` when calling `useCwaFormInput` (e.g. `'example_form[other_interests]'`).

**TipTap v3 — StarterKit includes Link by default:**

TipTap v3's `StarterKit` includes `Link` as a built-in extension. Adding `Link.configure()` explicitly alongside `StarterKit.configure()` results in "Duplicate extension names: ['link']" warning and potential conflicts. Fix: disable Link inside StarterKit and register it explicitly to apply custom config:

```ts
extensions: [
  StarterKit.configure({ link: false }),
  Link.configure({ openOnClick: false, defaultProtocol: 'https' }),
]
```

**Nuxt UI event bindings and `:value-key` / `:label-key`:**

Symfony `ChoiceView` items are objects with extra fields (`data`, `attr`, `labelTranslationParameters`) beyond `{ label, value }`. Nuxt UI components bind the **entire item** by default unless told which field to use. Always pass `:value-key="'value'"` and `:label-key="'label'"` to all choice-based components:

```vue
<!-- USelect (collapsed, single) -->
<USelect v-model="field.value.value" :items="choices" value-key="value" label-key="label"
  @update:model-value="field.onInput()" @blur="field.onBlur" />

<!-- USelectMenu (collapsed, multiple) -->
<USelectMenu v-model="field.value.value" :items="choices" :multiple="true"
  value-key="value" label-key="label" @update:model-value="field.onInput()" />

<!-- URadioGroup (expanded, single) -->
<URadioGroup v-model="field.value.value" :items="choices"
  value-key="value" label-key="label" @change="field.onInput()" />

<!-- UCheckboxGroup (expanded, multiple) -->
<UCheckboxGroup v-model="field.value.value" :items="choices"
  value-key="value" label-key="label" @change="field.onInput()" />
```

Without these keys, `USelectMenu` (confirmed) and potentially others bind the full `ChoiceView` object to v-model. Symfony then rejects the value with 422 "The option selected is invalid" because the full object is not in the allowed choices list.

Reminder for filtering: filter out the placeholder empty choice (`c.value !== ''`) when not using a `:placeholder` on `USelect` / `USelectMenu`.

- `UInput` / `UTextarea`: `@blur="field.onBlur"` + `@input="field.onInput"`

**Error display pattern:**
```vue
<UAlert v-if="form.success.value" color="success" title="Submitted!" />
<template v-else-if="form.formErrors.value.length || form.unregisteredFieldErrors.value.length">
  <UAlert v-if="form.formErrors.value.length" color="error" :description="form.formErrors.value[0]" />
  <UAlert v-if="form.unregisteredFieldErrors.value.length" color="error"
    title="Additional errors" :description="form.unregisteredFieldErrors.value.join(' · ')" />
</template>

<!-- Per-field (for each registered field): -->
<UFormField :error="field.displayErrors.value ? field.errors.value[0] : undefined">
  <UInput v-model="field.value.value" @blur="field.onBlur" @input="field.onInput" />
</UFormField>
```

**Collection entry child component pattern:**

Put the remove button **inside** the `UFormField` default slot alongside the input, wrapped in `flex items-center`. This keeps the button pinned next to the input even when a validation error expands the field height below.

```vue
<!-- FormChildEntry.vue — for compound ChildType entries; import directly, not a CWA component -->
<script setup lang="ts">
const props = defineProps<{ iri: string; entryFullName: string }>()
defineEmits<{ remove: [] }>()
const nameField = useCwaFormInput(toRef(props, 'iri'), `${props.entryFullName}[name]`)
</script>
<template>
  <UFormField
    :label="nameField.vars.value?.label || 'Name'"
    :error="nameField.displayErrors.value ? nameField.errors.value[0] : undefined"
  >
    <div class="flex items-center gap-2">
      <UInput class="flex-1" v-model="nameField.value.value" @blur="nameField.onBlur" @input="nameField.onInput" />
      <UButton color="error" variant="soft" icon="i-lucide-trash-2" @click.prevent="$emit('remove')" />
    </div>
  </UFormField>
</template>
```

**Same layout for `FormTextEntry.vue`** (simple TextType entries):

```vue
<!-- FormTextEntry.vue -->
<template>
  <UFormField
    :label="entryField.vars.value?.label || 'Text'"
    :error="entryField.displayErrors.value ? entryField.errors.value[0] : undefined"
  >
    <div class="flex items-center gap-2">
      <UInput class="flex-1" v-model="entryField.value.value" @blur="entryField.onBlur" @input="entryField.onInput" />
      <UButton color="error" variant="soft" icon="i-lucide-trash-2" @click.prevent="$emit('remove')" />
    </div>
  </UFormField>
</template>
```

**Labels for new collection entries** — `useCwaFormCollection.addEntry()` registers the cloned prototype in `$cwa.forms` so `useCwaFormInput.vars` is populated immediately (enabling realtime validation before first submit). Symfony's `"__name__label__"` sentinel label is automatically cleared during cloning, so the `|| 'Name'` / `|| 'Text'` fallbacks take effect for entries without explicit labels. Explicit sub-field labels (e.g. `"Child object text label"` on `[name]`) are preserved.

**Parent iterates entries and manages collection:**
```vue
<FormChildEntry
  v-for="entry in children.entries.value"
  :key="entry"
  :iri="props.iri"
  :entry-full-name="entry"
  @remove="children.removeEntry(entry)"
/>
<UButton v-if="children.vars.value?.allow_add" @click.prevent="children.addEntry()">
  Add Child
</UButton>
```

---

### API Fixture: ExampleFormType scaffold ✅

`AppScaffold.php` has a `/form` page with a `Form` entity wired to `ExampleFormType`. `uiComponent` is set to `'ExampleForm'` so the module resolves `CwaComponentExampleForm`. A "Form Demo" nav link points to the page.

**`ExampleFormType` covers every Symfony form field type:**
- `TextType` — plain text, no validation
- `RepeatedType` + `PasswordType` — password + confirm (use `useCwaFormRepeated`)
- `ChoiceType` (select, not expanded) — "Regarding" subject dropdown
- `EmailType` — email with NotBlank + Email constraints
- `TextareaType` — message with NotBlank constraint
- `ChoiceType` (expanded, single = radio) — yes/no developer question
- `CheckboxType` — single boolean checkbox with `IsTrue` (`NotBlank` does not fire on `false`; see checkbox bug in module CLAUDE.md)
- `ChoiceType` (expanded, multiple = checkbox group) — food interests
- `ChoiceType` (not expanded, multiple = multi-select) — other interests
- `CollectionType` + `ChildType` (compound — `name` sub-field) — use `useCwaFormCollection` with `FormChildEntry`
- `CollectionType` + `TextType` (simple text entries) — use `useCwaFormCollection` with `FormTextEntry`
- `SubmitType` — handled by `useCwaForm.submit()`, no composable needed

**Implementation notes:**

- **Timestamp workaround:** `Form` uses `TimestampedTrait`. Until the `CwaFixtureBuilder::createPositions()` timestamp bug is fixed in the API bundle, `createdAt` and `modifiedAt` are set manually in the fixture before adding to the group.

- **`choices` shape and placeholders:** Symfony `ChoiceType` emits placeholder entries as `{ value: '', label: 'Choose…' }`. These are filtered in the template (`c.value !== ''`) and the label is passed as `:placeholder`. Always add `value-key="value"` and `label-key="label"` to all choice components — without them Nuxt UI binds the full `ChoiceView` object and Symfony rejects it with 422.

- **Checkbox v-model:** The template currently uses `checkbox.vars.value?.checked ?? false` as getter. This has a known snap-back issue — waiting for the module to expose `booleanValue` from `useCwaFormInput`. See module CLAUDE.md "Known Bug: Unchecked checkbox submits `""` instead of `null`".

- **Checkbox label HTML:** The `randomCheckbox` label may contain HTML. The template renders it via `v-html` in a `#label` slot.

---

### GitHub Actions CI/CD

The template currently ships GitLab CI only (`.gitlab-ci.yml`). GitHub Actions support is planned. The shell functions in `bin/devops/` are the reusable CI primitives — a GitHub Actions implementation would write workflow YAML files (`.github/workflows/`) that call the same functions. This would allow teams on GitHub to get the same build/test/deploy pipeline without rewriting the logic.

**GitHub issue:** [#55](https://github.com/components-web-app/components-web-app/issues/55)