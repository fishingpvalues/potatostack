/**
 * Test Setup and Configuration Guide
 * 
 * This file documents how to set up and run the PotatoStack configuration tests.
 * 
 * INSTALLATION:
 * -------------
 * npm init -y
 * npm install --save-dev jest ts-jest typescript @types/jest @types/node js-yaml @types/js-yaml
 * 
 * CONFIGURATION FILES NEEDED:
 * ---------------------------
 * 
 * 1. tsconfig.json:
 * {
 *   "compilerOptions": {
 *     "target": "ES2020",
 *     "module": "commonjs",
 *     "lib": ["ES2020"],
 *     "strict": true,
 *     "esModuleInterop": true,
 *     "skipLibCheck": true,
 *     "forceConsistentCasingInFileNames": true,
 *     "resolveJsonModule": true,
 *     "outDir": "./dist",
 *     "rootDir": ".",
 *     "types": ["node", "jest"]
 *   },
 *   "include": ["tests/**\/*.ts"],
 *   "exclude": ["node_modules", "dist"]
 * }
 * 
 * 2. jest.config.js:
 * module.exports = {
 *   preset: 'ts-jest',
 *   testEnvironment: 'node',
 *   roots: ['<rootDir>/tests'],
 *   testMatch: ['**\/*.test.ts'],
 *   moduleFileExtensions: ['ts', 'js', 'json'],
 *   collectCoverage: true,
 *   coverageDirectory: 'coverage',
 *   coverageReporters: ['text', 'lcov', 'html'],
 *   verbose: true,
 *   testTimeout: 10000
 * };
 * 
 * 3. package.json scripts:
 * {
 *   "scripts": {
 *     "test": "jest",
 *     "test:watch": "jest --watch",
 *     "test:coverage": "jest --coverage"
 *   }
 * }
 * 
 * RUNNING TESTS:
 * --------------
 * npm test                    # Run all tests
 * npm test -- --watch         # Watch mode
 * npm test -- --coverage      # With coverage report
 * npm test -- docker-compose  # Run specific test file
 * 
 * TEST FILES:
 * -----------
 * - tests/docker-compose.test.ts  - Docker Compose configuration tests
 * - tests/prometheus.test.ts      - Prometheus and alerts configuration tests
 * - tests/monitoring-configs.test.ts - Alertmanager, Loki, Promtail, Grafana tests
 * - tests/homepage.test.ts        - Homepage dashboard configuration tests
 */

describe('Test Setup Verification', () => {
  test('Jest is properly configured', () => {
    expect(true).toBe(true);
  });

  test('TypeScript compilation works', () => {
    const testValue: string = 'PotatoStack';
    expect(testValue).toBe('PotatoStack');
  });

  test('can import yaml module', () => {
    // This test verifies js-yaml is available
    const yaml = require('js-yaml');
    expect(yaml).toBeDefined();
    expect(typeof yaml.load).toBe('function');
  });

  test('can read file system', () => {
    const fs = require('fs');
    const path = require('path');
    expect(fs).toBeDefined();
    expect(path).toBeDefined();
  });
});

describe('Configuration Files Existence', () => {
  const fs = require('fs');
  const path = require('path');

  const configFiles = [
    'docker-compose.yml',
    'config/prometheus/prometheus.yml',
    'config/prometheus/alerts.yml',
    'config/alertmanager/config.yml',
    'config/loki/local-config.yaml',
    'config/promtail/config.yml',
    'config/grafana/provisioning/datasources/datasources.yml',
    'config/grafana/provisioning/dashboards/dashboards.yml',
    'config/homepage/services.yaml',
    'config/homepage/bookmarks.yaml',
    'config/homepage/widgets.yaml',
    'config/homepage/settings.yaml',
    'config/homepage/docker.yaml',
  ];

  test.each(configFiles)('%s should exist', (configFile) => {
    const filePath = path.join(__dirname, '..', configFile);
    expect(fs.existsSync(filePath)).toBe(true);
  });
});

describe('YAML Syntax Validation', () => {
  const fs = require('fs');
  const path = require('path');
  const yaml = require('js-yaml');

  const yamlFiles = [
    'docker-compose.yml',
    'config/prometheus/prometheus.yml',
    'config/prometheus/alerts.yml',
    'config/alertmanager/config.yml',
    'config/loki/local-config.yaml',
    'config/promtail/config.yml',
    'config/grafana/provisioning/datasources/datasources.yml',
    'config/grafana/provisioning/dashboards/dashboards.yml',
    'config/homepage/services.yaml',
    'config/homepage/bookmarks.yaml',
    'config/homepage/widgets.yaml',
    'config/homepage/settings.yaml',
    'config/homepage/docker.yaml',
  ];

  test.each(yamlFiles)('%s should be valid YAML', (yamlFile) => {
    const filePath = path.join(__dirname, '..', yamlFile);
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf8');
      expect(() => yaml.load(content)).not.toThrow();
    }
  });
});
