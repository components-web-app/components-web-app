# The browser-test runner (#157). Keep the image tag and @playwright/test in package.json on the same version.
FROM mcr.microsoft.com/playwright:v1.64.1-noble

WORKDIR /e2e
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .

# forward.mjs makes http://localhost the site, as the browser must see it (a secure context).
# Playwright strips types without checking them, so tsc and ESLint run first.
CMD ["node", "forward.mjs", "npx tsc && npx eslint . && npx playwright test && node check-all-ran.mjs"]
