<template>
  <div>
    <div v-if="!editing" @dblclick="showEditView" v-html="displayHtml" />
    <text-input v-else :iri="iri" field="html" @hide="editing = false" />
    published: {{ published }}
  </div>
</template>

<script>
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
import TextInput from '~/components/TextInput'
export default {
  components: { TextInput },
  mixins: [ComponentMixin],
  data () {
    return {
      editing: false
    }
  },
  computed: {
    contextMenuData () {
      return {
        Edit: {
          callback: this.showEditView
        }
      }
    },
    displayHtml () {
      return this.resource.html || (this.$cwa.isAdmin ? '<p style="font-style: italic">No content</p>' : '')
    }
  },
  methods: {
    showEditView () {
      this.editing = true
    }
  }
}
</script>
