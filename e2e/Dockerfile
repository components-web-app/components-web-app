# The browser-test runner (#157). Keep the image tag and @playwright/test in package.json on the same version.
FROM mcr.microsoft.com/playwright:v1.64.0-noble

WORKDIR /e2e
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .

# forward.mjs makes http://localhost the site, as the browser must see it (a secure context).
CMD ["node", "forward.mjs", "npx playwright test && node check-all-ran.mjs"]
