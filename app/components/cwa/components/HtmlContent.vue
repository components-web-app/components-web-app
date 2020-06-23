<template>
  <div>
    <div v-html="resource.html" />
  </div>
</template>

<script>
import ComponentMixin from '@cwa/nuxt-module/core/mixins/ComponentMixin'
export default {
  mixins: [ComponentMixin],
  computed: {
    contextMenuData () {
      return {
        Edit: {
          callback: this.showEditView
        }
      }
    }
  },
  methods: {
    showEditView () {
      alert('this will trigger edit view...')
    }
  }
}
</script>
