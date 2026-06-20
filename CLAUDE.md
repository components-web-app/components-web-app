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

The `@cwa/nuxt` module ships four form composables. The playground demo is at `playground/app/cwa/components/Form/Form.vue` in the module repo. Mirror it here so new projects start with a working example.

**Files to create/update:**

1. **`app/cwa/components/Form/Form.vue`** — the main CWA component using `ExampleFormType` field names. Replace the current stub.

2. **`app/components/FormChildEntry.vue`** — sub-component for compound `ChildType` collection entries (one `name` sub-field). Called via `v-for` over `children.entries.value`. Calls `useCwaFormInput(iriRef, entryFullName + '[name]')`.

3. **`app/components/FormTextEntry.vue`** — sub-component for simple `TextType` collection entries. Calls `useCwaFormInput(iriRef, entryFullName)`.

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
- `field.displayErrors.value` gates when to show `field.errors.value[0]` — triggered by blur, having-been-valid, or submit attempt
- `form.formErrors.value` = root-level Symfony errors
- `form.unregisteredFieldErrors.value` = API errors for fields not bound to any `useCwaFormInput` — show in a fallback block, never alongside registered field errors
- **CheckboxType quirk**: `vars.value` is always `'1'`; use `vars.checked` for initial boolean state; use a computed to map `true ↔ '1'` and `false ↔ ''`

**Nuxt UI event bindings:**
- `UInput` / `UTextarea`: `@blur="field.onBlur"` + `@input="field.onInput"`
- `USelect`: `@update:model-value="field.onInput()"`
- `URadioGroup` / `UCheckboxGroup`: `@change="field.onInput()"`
- `USelectMenu :multiple`: `@update:model-value="field.onInput()"`

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
```vue
<!-- FormChildEntry.vue — for compound ChildType entries -->
<script setup lang="ts">
const props = defineProps<{ iri: string | undefined; entryFullName: string }>()
defineEmits<{ remove: [] }>()
const nameField = useCwaFormInput(toRef(props, 'iri'), `${props.entryFullName}[name]`)
</script>
<template>
  <div class="flex gap-2">
    <UFormField :error="nameField.displayErrors.value ? nameField.errors.value[0] : undefined">
      <UInput v-model="nameField.value.value" @blur="nameField.onBlur" @input="nameField.onInput" />
    </UFormField>
    <UButton color="error" variant="soft" @click="$emit('remove')">Remove</UButton>
  </div>
</template>
```

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

### API Fixture: ExampleFormType scaffold

`AppScaffold.php` currently has no `Form` component. Add one wired to `ExampleFormType` so the demo page shows the full form.

**`ExampleFormType` covers every Symfony form field type:**
- `TextType` — plain text, no validation
- `RepeatedType` + `PasswordType` — password + confirm (use `useCwaFormRepeated`)
- `ChoiceType` (select, not expanded) — "Regarding" subject dropdown
- `EmailType` — email with NotBlank + Email constraints
- `TextareaType` — message with NotBlank constraint
- `ChoiceType` (expanded, single = radio) — yes/no developer question
- `CheckboxType` — single boolean checkbox with NotBlank
- `ChoiceType` (expanded, multiple = checkbox group) — food interests
- `ChoiceType` (not expanded, multiple = multi-select) — other interests
- `CollectionType` + `ChildType` (compound — `name` sub-field) — use `useCwaFormCollection` with `FormChildEntry`
- `CollectionType` + `TextType` (simple text entries) — use `useCwaFormCollection` with `FormTextEntry`
- `SubmitType` — handled by `useCwaForm.submit()`, no composable needed

**Fixture snippet (add to `AppScaffold.php`):**
```php
use App\Form\ExampleFormType;
use Silverback\ApiComponentsBundle\Entity\Component\Form;

// In load() — add Form component to an existing page's main component group:
$formComponent = (new Form())->setFormType(ExampleFormType::class);
// $cwa->component($formComponent, 'main-cg-reference', 'example-form');
// (Adjust the CwaFixtureBuilder API to match how other components are added)
```

**Known issues and requirements when wiring the fixture:**

- **Timestamp workaround:** `Form` uses `TimestampedTrait`. Until the `CwaFixtureBuilder::createPositions()` timestamp bug is fixed in the API bundle, set both fields manually before adding to the group:
  ```php
  $formComponent->createdAt = new \DateTimeImmutable();
  $formComponent->modifiedAt = new \DateTime();
  ```

- **`choices` shape and placeholders:** Symfony `ChoiceType` emits placeholder entries as `{ value: '', label: 'Choose…' }`. The Nuxt module's `USelect`/`USelectMenu` bindings filter these out and use `vars.placeholder` instead. No fixture change needed — handled in the template component.

- **`other_interests` field:** Verify that the `other_interests` field has at least one choice with a non-empty `value`. If all choices are empty strings the dropdown will appear blank after placeholder filtering.

- **CollectionType fields (`children`, `text_children`):** `allow_add`, `allow_delete`, and `prototype` are already exposed by the API bundle. After the module fix (2026-06-20), `getForm()` now preserves `prototype` on the `FormView` entry alongside `vars`. The `useCwaFormCollection` reads `formEntry.prototype` (not `vars.prototype`). Buttons appear when `vars.allow_add` is truthy and `prototype` is defined.

- **Checkbox v-model pattern:** `useCwaFormInput` now initialises `value` from `vars.checked ? '1' : ''` when `block_prefixes` includes `'checkbox'`. The correct v-model pattern in the consuming template is:
  ```ts
  const isChecked = computed({
    get: () => !!checkbox.value.value,   // reads local ref — immediate visual feedback
    set: (v: boolean) => {
      checkbox.value.value = v ? '1' : ''
      checkbox.onInput()
    },
  })
  ```
  Do NOT use `checkbox.vars.value?.checked` as the getter — it reads from the Pinia store (async) and causes the checkbox to snap back visually until the PATCH response arrives. `Form.vue` needs updating to use this pattern.

- **Checkbox label HTML:** The `randomCheckbox` label may contain HTML (e.g. `<b>bold</b>`). The template component renders it via `v-html` in a `#label` slot — intentional. The fixture label can safely include HTML markup.

---

### GitHub Actions CI/CD

The template currently ships GitLab CI only (`.gitlab-ci.yml`). GitHub Actions support is planned. The shell functions in `bin/devops/` are the reusable CI primitives — a GitHub Actions implementation would write workflow YAML files (`.github/workflows/`) that call the same functions. This would allow teams on GitHub to get the same build/test/deploy pipeline without rewriting the logic.

**GitHub issue:** [#55](https://github.com/components-web-app/components-web-app/issues/55)