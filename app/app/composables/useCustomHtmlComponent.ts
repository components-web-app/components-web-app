import { computed, nextTick, watch } from 'vue'
import type { Ref } from 'vue'
import { useCwaResourceModel, useCwa } from '#imports'

export const useCustomHtmlComponent = (iriRef: Ref<string>) => {
  const $cwa = useCwa()

  const resourceModel = useCwaResourceModel<string>(iriRef, 'html')
  const disableEditor = computed(() => !$cwa.admin.isEditing || $cwa.admin.resourceStackManager.currentIri.value !== iriRef.value)

  // instantly update focus when the UI sze changes
  watch([disableEditor, resourceModel.model], async () => {
    await nextTick()
    $cwa.admin.resourceStackManager.redrawFocus()
  }, {
    flush: 'post'
  })

  return {
    resourceModel,
    disableEditor
  }
}
