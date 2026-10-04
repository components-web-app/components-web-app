# CWA Helm chart

Deploys the API (FrankenPHP with Souin and Mercure) and the Nuxt front end to Kubernetes. The template's CI deploys it with `bin/devops/k8s.sh`, which sets the values (`deploy` in that script).

See https://cwa.rocks/deployment/kubernetes for the variables, sizing and what each deploy step does.
