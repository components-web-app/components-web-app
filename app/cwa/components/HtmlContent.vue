<template>
  <div ref="htmlContainer" v-html="htmlContent" />
</template>

<script setup lang="ts">
// Todo: work on the nuxt link replacement so external links are not clickable during editing - make into composable for dynamically  changing anchor links into components for internal routing and easier manipulation of disabling
import { createApp, onMounted, ref } from 'vue'
import { IriProp } from '#cwa/runtime/composables/cwa-resource'
import { useCwaResource } from '#imports'
import { NuxtLink } from '#components'

const props = defineProps<IriProp>()

const resource = useCwaResource(props.iri, { manager: { options: { displayName: 'Body Text' } } }).getResource()

const htmlContainer = ref<null|HTMLElement>(null)
const htmlContent = ref<string>(resource.value.data?.html || '<div></div>')

function convertAnchor (anchor: HTMLElement) {
  const href = anchor.getAttribute('href')
  if (!href) {
    return
  }
  const props: any = {
    to: href,
    innerHTML: anchor.innerHTML,
    something: 'else'
  }
  for (const attr of anchor.attributes) {
    if (!['href'].includes(attr.name)) {
      const anchorAttr = anchor.getAttribute(attr.name)
      if (anchorAttr) {
        props[attr.name] = anchorAttr
      }
    }
  }
  return createApp(NuxtLink, props)
}

onMounted(() => {
  if (!htmlContainer.value) {
    return
  }
  // Loop through the anchor links
  const anchors = htmlContainer.value.getElementsByTagName('a')
  Array.from(anchors).forEach((anchor) => {
    // Attempt to create a NuxtLink from the anchor
    const nuxtLink = convertAnchor(anchor)
    if (nuxtLink) {
      // If successful replace the anchor with a span to act as the container for the component
      const parent = anchor.parentNode
      if (parent) {
        const linkContainer = document.createElement('span')
        parent.replaceChild(linkContainer, anchor)
        // mount the NuxtLink component in the span
        nuxtLink.mount(linkContainer)
      }
    }
  })
})
</script>

<style>
.html-content p:not(:last-child) {
  margin-bottom: 1rem
}
</style>
