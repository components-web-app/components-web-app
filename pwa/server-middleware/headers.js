// I want this to be typescript really - but with Vercel deployments it either does not find the ts path
// or if added to serverMiddleware config we get syntax issues

const headersMiddleware = function (_, res, next) {
  res.setHeader(
    'Cache-Control',
    's-maxage=1, max-age=0, public, must-revalidate, stale-while-revalidate=30'
  )
  next()
}

export default headersMiddleware
