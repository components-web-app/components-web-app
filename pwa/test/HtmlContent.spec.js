import { mount } from '@vue/test-utils'
import Logo from '@/components/cwa/components/HtmlContent.vue'

describe('HtmlContent', () => {
  test('is a Vue instance', () => {
    const wrapper = mount(Logo)
    expect(wrapper.vm).toBeTruthy()
  })
})
