#!/usr/bin/env bash

performance() {
  export CI_ENVIRONMENT_URL=$(cat environment_url.txt)

  mkdir gitlab-exporter
  wget -O gitlab-exporter/index.js https://gitlab.com/gitlab-org/gl-performance/raw/10-5/index.js

  mkdir sitespeed-results

  if [[ -f .gitlab-urls.txt ]]; then
    sed -i -e 's@^@'"$CI_ENVIRONMENT_URL"'@' .gitlab-urls.txt
    docker run --shm-size=1g --rm -v "$(pwd)":/sitespeed.io sitespeedio/sitespeed.io:6.3.1 --plugins.add ./gitlab-exporter --outputFolder sitespeed-results .gitlab-urls.txt
  else
    docker run --shm-size=1g --rm -v "$(pwd)":/sitespeed.io sitespeedio/sitespeed.io:6.3.1 --plugins.add ./gitlab-exporter --outputFolder sitespeed-results "$CI_ENVIRONMENT_URL"
  fi

  mv sitespeed-results/data/performance.json performance.json
}
