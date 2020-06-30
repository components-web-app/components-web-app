export default function (req, res, next) {
  res.setHeader('Cache-Control', 's-maxage=1, stale-while-revalidate')
  next()
}
