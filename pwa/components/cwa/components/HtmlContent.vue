<template>
  <div>
    <!-- eslint-disable-next-line vue/no-v-html -->
    <div v-if="!editing" v-html="displayHtml" />
    <quill-input
      v-else
      :iri="displayIri"
      field="html"
      @hide="editing = false"
    />
  </div>
</template>

<script>
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import QuillInput from '~/components/QuillInput'
export default {
  components: { QuillInput },
  mixins: [ComponentMixin],
  data() {
    return {
      editing: false,
      componentManager: {
        name: 'HTML Content',
        tabs: [
          {
            label: 'Tab label',
            component: () => import('../admin-dialog/HtmlContent.vue')
          }
        ]
      }
    }
  },
  computed: {
    displayHtml() {
      return (
        this.resource.html ||
        (this.$cwa.isAdmin
          ? '<p style="font-style: italic">No content</p>'
          : '')
      )
    }
  },
  methods: {
    showEditView() {
      this.editing = true
    }
  }
}
</script>
