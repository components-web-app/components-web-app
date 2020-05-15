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
