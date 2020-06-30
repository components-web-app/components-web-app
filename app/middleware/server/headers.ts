import { ServerMiddleware } from '@nuxt/types'

const myServerMiddleware: ServerMiddleware = function (_, res, next) {
  res.setHeader('Cache-Control', 's-maxage=1, stale-while-revalidate')
  next()
}

export default myServerMiddleware
