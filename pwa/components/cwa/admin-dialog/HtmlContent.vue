<template>
  <div class="cwa-admin-dialog-form">
    <div class="cwa-input">
      <label for="ui-classes">Style Classes</label>
      <input id="ui-classes" v-model="uiClassNames" type="text" />
    </div>
    <div class="cwa-input">
      <button
        class="is-size-6 submit-button"
        :disabled="submitting"
        @click="submitRequest"
      >
        {{ submitButtonLabel }}
      </button>
    </div>
    <div v-if="resource" class="cwa-input">
      <button
        class="is-size-6 submit-button"
        :disabled="submitting"
        @click="deleteResource"
      >
        Delete
      </button>
    </div>
  </div>
</template>

<script>
import ApiRequestMixin from '@cwa/nuxt-module/core/mixins/ApiRequestMixin'
import CommaDelimitedArrayBuilder from '@cwa/nuxt-module/core/utils/CommaDelimitedArrayBuilder'

export default {
  mixins: [ApiRequestMixin],
  props: {
    resource: {
      type: Object,
      required: false,
      default: null
    },
    componentCollection: {
      type: String,
      required: false,
      default: null
    }
  },
  data() {
    return {
      uiClassNames: this.resource?.uiClassNames?.join(', '),
      submitting: false
    }
  },
  computed: {
    submitButtonLabel() {
      return this.resource ? 'Update' : 'Create'
    }
  },
  methods: {
    async deleteResource() {
      this.submitting = true
      try {
        await this.$cwa.deleteResource(this.resource['@id'])
      } catch (error) {
        this.handleApiError(error)
      } finally {
        this.submitting = false
      }
    },
    async submitRequest() {
      this.submitting = true
      try {
        const uiClassNames = CommaDelimitedArrayBuilder(this.uiClassNames)
        const updateData = {
          uiClassNames
        }
        if (this.resource) {
          await this.$cwa.updateResource(this.resource['@id'], updateData)
        } else {
          const createData = Object.assign(
            {
              componentPositions: [
                {
                  componentCollection: this.componentCollection
                }
              ]
            },
            updateData
          )
          await this.$cwa.createResource(
            this.resource?.['@id'] || '/component/html_contents',
            createData
          )
        }
      } catch (error) {
        this.handleApiError(error)
      } finally {
        this.submitting = false
      }
    }
  }
}
</script>

<style lang="sass">
.cwa-admin-dialog-form
  .submit-button
    width: 100%
    margin: 1rem 0 0
</style>
