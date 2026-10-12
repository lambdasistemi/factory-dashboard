import { defineConfig } from '@playwright/test';

// The staging directory is prepared by the Nix check derivations:
//   staging/app/      the built artifact under test
//   staging/mutated/  harness copy with one seeded external request
// Set E2E_NO_WEBSERVER=1 to serve staging yourself during local runs.
export default defineConfig({
  testDir: '.',
  reporter: 'list',
  timeout: 30000,
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://127.0.0.1:4173',
  },
  webServer: process.env.E2E_NO_WEBSERVER
    ? undefined
    : {
        command: 'python3 -m http.server 4173 --bind 127.0.0.1 --directory ../staging',
        url: 'http://127.0.0.1:4173/app/index.html',
        reuseExistingServer: false,
        timeout: 20000,
      },
});
