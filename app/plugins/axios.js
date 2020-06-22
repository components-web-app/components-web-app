import https from 'https'
import fs from 'fs'

export default function ({ $axios }) {
  const caCrt = fs.readFileSync('/certs/rootCA.pem')
  const httpsAgent = new https.Agent({ ca: caCrt, keepAlive: false })

  $axios.onRequest(config => {
    config.httpsAgent = httpsAgent
  })
}
