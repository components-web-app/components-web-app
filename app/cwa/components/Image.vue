<template>
  <div>
    <div data-placeholder class="h-40 w-40 overflow-hidden relative bg-gray-200" />
    <nuxt-img src="/logo.svg" placeholder />
    <CodeBlock>{{ resource }}</CodeBlock>
  </div>
</template>

<script setup>
import { useCwaResource, iri } from '#imports'

const props = defineProps({
  ...iri
})

const resource = useCwaResource(props.iri)
</script>

<style>
[data-placeholder]::after {
  content: " ";
  box-shadow: 0 0 50px 9px rgba(254,254,254);
  position: absolute;
  top: 0;
  left: -100%;
  height: 100%;
  animation: load 1s infinite;
}
@keyframes load {
  0%{ left: -100%}
  100%{ left: 150%}
}
</style>
