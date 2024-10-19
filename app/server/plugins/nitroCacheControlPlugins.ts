import {H3Event} from "h3";

export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook("beforeResponse", async (event: H3Event, { body }) => {
    if (!event.headers.has('cache-control')) {
      event.headers.set('cache-control', 'public, max-age=120, s-maxage=604800, must-revalidate')
    }
  });
})
