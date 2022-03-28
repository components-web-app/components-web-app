const https = require('https')
const fs = require('fs')

export default function ({ $axios }) {
  if (process.env.NODE_ENV === 'production') return

  const files = fs.readdirSync('/ca-certs')
  if (!files.length) {
    return
  }
  const caCrt = fs.readFileSync(`/ca-certs/${files[0]}`).toString('utf8')
  const httpsAgent = new https.Agent({ ca: caCrt, keepAlive: false })

  $axios.onRequest((config) => {
    config.httpsAgent = httpsAgent
  })
}
