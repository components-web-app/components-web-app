<template>
  <div>
    <!-- eslint-disable-next-line vue/no-v-html -->
    <div ref="quill" v-html="quillModel" />
  </div>
</template>

<script lang="ts">
import Vue from 'vue'
import InputMixin from '@cwa/nuxt-module/core/mixins/InputMixin'

export default Vue.extend({
  mixins: [InputMixin],
  data() {
    return {
      editor: null,
      editorOptions: {
        modules: {
          toolbar: {
            container: [
              [
                { header: [false, 1, 2, 3, 4] },
                { size: [false, '7'] },
                {
                  'theme-color': [false, 'primary', 'success']
                }
              ],
              ['bold', 'italic', 'underline'],
              [
                { align: '' },
                { align: 'center' },
                { align: 'justify' },
                { align: 'right' }
              ],
              [{ list: 'ordered' }, { list: 'bullet' }],
              ['link'],
              ['clean']
            ]
          }
        },
        theme: 'snow'
      },
      quillModel: null
    }
  },
  computed: {
    cleanedInputValue() {
      return this.inputValue ? this.inputValue.trim() : this.inputValue
    }
  },
  watch: {
    // when published becomes a draft...
    iri() {
      this.$nextTick(() => {
        const selection = this.editor.getSelection()
        this.editor.root.innerHTML = this.cleanedInputValue
        if (selection) {
          this.$nextTick(() => {
            this.editor.setSelection(selection.index, selection.length)
          })
        }
      })
    }
  },
  async mounted() {
    this.quillModel = this.cleanedInputValue
    const { default: Quill } = await import('quill')
    this.editor = new Quill(this.$refs.quill, this.editorOptions)

    this.editor.enable(false)

    this.$nextTick(() => {
      // https://github.com/quilljs/quill/issues/1184#issuecomment-384935594
      this.editor.clipboard.addMatcher(Node.ELEMENT_NODE, (_, delta) => {
        const ops = []
        delta.ops.forEach((op) => {
          if (op.insert && typeof op.insert === 'string') {
            ops.push({
              insert: op.insert
            })
          }
        })
        delta.ops = ops
        return delta
      })

      // We will add the update event here
      this.editor.on('text-change', () => {
        this.inputValue = this.editor.root.innerHTML
      })

      this.editor.enable(true)
    })
  }
})
</script>

<!--<style lang="stylus" src="quill/assets/snow.styl" />-->
<style lang="sass" src="assets/sass/quill.sass" />
<style lang="sass">
.ql-container
  font-size: inherit
  height: auto
  .ql-editor
    text-align: inherit
.ql-snow
  .ql-picker
    &.ql-theme-color
      width: 100px
      .ql-picker-item,
      .ql-picker-label
        &::before
          content: 'Color'
          color: inherit
        &[data-value='primary']::before
          content: 'Primary'
          color: $color-primary
        &[data-value='success']::before
          content: 'Success'
          color: $color-success
    &.ql-size
      .ql-picker-item,
      .ql-picker-label
        &::before
          content: 'Font size'
        &[data-value='7']::before
          content: 'Small'
          font-size: .7rem
//&.ql-font
//  .ql-picker-item,
//  .ql-picker-label
//    ::before
//      content: 'Font'
//    &[data-value='monda']::before
//      content: 'Monda'
//      font-family: 'Monda'
</style>
