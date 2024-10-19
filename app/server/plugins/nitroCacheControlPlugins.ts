import {H3Event} from "h3";

export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook("beforeResponse", async (event: H3Event, { body }) => {
    if (!event.headers.has('Cache-Control') || event.headers.get('Cache-Control') === '') {
      event.headers.set('Cache-Control', 'public, max-age=7200, stale-while-revalidate=604800, s-maxage=604800')
    }
  });
})
