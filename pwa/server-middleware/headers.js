// I want this to be typescript really - but with vercel deployments it either doe not find the ts path
// or if added to serverMiddleware config we get syntax issues

const headersMiddleware = function (_, res, next) {
  res.setHeader('Cache-Control', 's-maxage=1, stale-while-revalidate')
  next()
}

export default headersMiddleware
