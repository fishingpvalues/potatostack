/**
 * Tests for Homepage dashboard configuration files.
 * Validates services, bookmarks, widgets, and settings.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

interface HomepageServicesConfig {
  [group: string]: Array<{
    [serviceName: string]: {
      icon?: string;
      href?: string;
      description?: string;
      widget?: {
        type: string;
        url?: string;
        [key: string]: unknown;
      };
    };
  }>;
}

interface HomepageBookmarksConfig {
  [category: string]: Array<{
    [bookmarkName: string]: Array<{
      abbr?: string;
      href: string;
    }>;
  }>;
}

interface HomepageWidgetsConfig {
  resources?: {
    cpu?: boolean;
    memory?: boolean;
    disk?: string | string[];
    cputemp?: boolean;
    uptime?: boolean;
    label?: string;
  };
  search?: {
    provider?: string;
    target?: string;
  };
  datetime?: {
    text_size?: string;
    format?: {
      dateStyle?: string;
      timeStyle?: string;
    };
  };
  openmeteo?: {
    label?: string;
    latitude?: number;
    longitude?: number;
    units?: string;
    cache?: number;
  };
}

interface HomepageSettingsConfig {
  title?: string;
  background?: {
    image?: string;
    blur?: string;
    saturate?: number;
    brightness?: number;
    opacity?: number;
  };
  theme?: string;
  color?: string;
  headerStyle?: string;
  layout?: {
    [group: string]: {
      style?: string;
      columns?: number;
    };
  };
}

describe('Homepage Services Configuration', () => {
  let servicesConfig: HomepageServicesConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'homepage', 'services.yaml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    servicesConfig = yaml.load(fileContent) as HomepageServicesConfig;
  });

  describe('Service Groups', () => {
    test('should have service groups defined', () => {
      expect(servicesConfig).toBeDefined();
      expect(Object.keys(servicesConfig).length).toBeGreaterThan(0);
    });

    test('should be an array of service groups', () => {
      expect(Array.isArray(servicesConfig)).toBe(true);
    });
  });
});

describe('Homepage Bookmarks Configuration', () => {
  let bookmarksConfig: HomepageBookmarksConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'homepage', 'bookmarks.yaml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    bookmarksConfig = yaml.load(fileContent) as HomepageBookmarksConfig;
  });

  describe('Bookmarks Structure', () => {
    test('should have bookmarks defined', () => {
      expect(bookmarksConfig).toBeDefined();
    });

    test('should be an array of bookmark categories', () => {
      expect(Array.isArray(bookmarksConfig)).toBe(true);
    });
  });
});

describe('Homepage Widgets Configuration', () => {
  let widgetsConfig: HomepageWidgetsConfig[];

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'homepage', 'widgets.yaml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    widgetsConfig = yaml.load(fileContent) as HomepageWidgetsConfig[];
  });

  describe('Widgets Structure', () => {
    test('should have widgets defined', () => {
      expect(widgetsConfig).toBeDefined();
      expect(Array.isArray(widgetsConfig)).toBe(true);
    });

    test('should have at least one widget', () => {
      expect(widgetsConfig.length).toBeGreaterThan(0);
    });
  });

  describe('Resource Widget', () => {
    test('should have resources widget', () => {
      const resourceWidget = widgetsConfig.find(w => 'resources' in w);
      expect(resourceWidget).toBeDefined();
    });
  });
});

describe('Homepage Settings Configuration', () => {
  let settingsConfig: HomepageSettingsConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'homepage', 'settings.yaml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    settingsConfig = yaml.load(fileContent) as HomepageSettingsConfig;
  });

  describe('Settings Structure', () => {
    test('should have settings defined', () => {
      expect(settingsConfig).toBeDefined();
    });
  });
});

describe('Homepage Docker Configuration', () => {
  let dockerConfig: unknown;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'homepage', 'docker.yaml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    dockerConfig = yaml.load(fileContent);
  });

  describe('Docker Integration', () => {
    test('should have docker configuration defined', () => {
      expect(dockerConfig).toBeDefined();
    });
  });
});
