const path = require('path')
const { loadNuxt } = require('nuxt-edge')
const puppeteer = require('puppeteer')
const getPort = require('get-port')

const Vue = require('vue')
Vue.config.devtools = false
Vue.config.productionTip = false

describe('basic', () => {
  let browser, nuxt, url

  beforeAll(async () => {
    browser = await puppeteer.launch({
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
      executablePath: process.env.PUPPETEER_EXECUTABLE_PATH
    })

    nuxt = await loadNuxt({
      for: 'start',
      rootDir: path.resolve(__dirname, '../../fixture')
    })

    const port = await getPort()
    url = p => 'http://localhost:' + port + p
    await nuxt.listen(port)
  }, 60000)

  afterAll(async () => {
    await browser.close()
    await nuxt.close()
  })

  test('dummy_test', async () => {
    const page = await browser.newPage()
    await page.goto(url('/'))
    await page.waitForFunction('!!window.$nuxt')

    // const { response } = await page.evaluate(async () => {
    //   const response = window.$nuxt.$cwa.doSomething()
    //
    //   return {
    //     response
    //   }
    // })
    //
    // expect(response).toEqual('something')

    // const bodyHTML = await page.evaluate(() => document.body.innerHTML)
    // expect(bodyHTML).toContain('Hello test world')

    await page.close()
  })
})
