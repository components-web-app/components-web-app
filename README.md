# Components Web App Template [WIP]

This repository provides a starting template which consists of `API Component Bundle` for the API, and a Nuxt application configured to use `cwa-nuxt-module` for the application.

This setup will include CI integration with GitLab by utilising a bash script file so that it is easier to switch between different CI tools.

The integration will assume deployment to a Kubernetes cluster for the API which will also include a Helm chart.

The primary API stack is as follows:
- PHP application
- Nginx
- Varnish
- Vulcain

This setup will also include Mercure for the front-end application to subscribe to updated resources.

We also want testing to be implemented by default. This means we will have both PHPUnit and Behat configured for the API and Jest for the front-end application.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="http://twitter.com/pborreli"><img src="https://avatars2.githubusercontent.com/u/77759?v=4" width="60px;" alt=""/><br /><sub><b>Pascal Borreli</b></sub></a><br /><a href="#ideas-pborreli" title="Ideas, Planning, & Feedback">🤔</a> <a href="#infra-pborreli" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
  </tr>
</table>

<!-- markdownlint-enable -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!

### See also contributors for:

- #### [API Component Bundle](https://github.com/components-web-app/api-components-bundle)
- #### [CWA Nuxt Module](https://github.com/components-web-app/cwa-nuxt-module)
