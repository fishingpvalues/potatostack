/**
 * Tests for Alertmanager, Loki, Promtail, and Grafana configurations.
 * Validates logging and alerting infrastructure.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

interface AlertmanagerConfig {
  global: {
    resolve_timeout: string;
    smtp_from?: string;
    smtp_smarthost?: string;
    smtp_auth_username?: string;
    smtp_auth_password?: string;
    smtp_require_tls?: boolean;
  };
  route: {
    group_by: string[];
    group_wait: string;
    group_interval: string;
    repeat_interval: string;
    receiver: string;
    routes?: Array<{
      match?: Record<string, string>;
      receiver: string;
      continue?: boolean;
    }>;
  };
  receivers: Array<{
    name: string;
    email_configs?: Array<{
      to: string;
      headers?: Record<string, string>;
      html?: string;
    }>;
  }>;
  inhibit_rules?: Array<{
    source_match: Record<string, string>;
    target_match: Record<string, string>;
    equal: string[];
  }>;
}

interface LokiConfig {
  auth_enabled: boolean;
  server: {
    http_listen_port: number;
    grpc_listen_port: number;
  };
  common: {
    path_prefix: string;
    storage: {
      filesystem: {
        chunks_directory: string;
        rules_directory: string;
      };
    };
    replication_factor: number;
  };
  schema_config: {
    configs: Array<{
      from: string;
      store: string;
      object_store: string;
      schema: string;
      index: {
        prefix: string;
        period: string;
      };
    }>;
  };
  limits_config: {
    retention_period: string;
    max_query_length?: string;
    max_query_parallelism?: number;
    max_entries_limit_per_query?: number;
  };
  compactor?: {
    working_directory: string;
    shared_store: string;
    retention_enabled: boolean;
  };
}

interface PromtailConfig {
  server: {
    http_listen_port: number;
    grpc_listen_port: number;
  };
  positions: {
    filename: string;
  };
  clients: Array<{
    url: string;
  }>;
  scrape_configs: Array<{
    job_name: string;
    static_configs?: Array<{
      targets: string[];
      labels: Record<string, string>;
    }>;
    docker_sd_configs?: Array<{
      host: string;
      refresh_interval?: string;
    }>;
    relabel_configs?: Array<{
      source_labels?: string[];
      target_label?: string;
      regex?: string;
    }>;
  }>;
}

interface GrafanaDatasourcesConfig {
  apiVersion: number;
  datasources: Array<{
    name: string;
    type: string;
    access: string;
    url: string;
    isDefault?: boolean;
    editable?: boolean;
    jsonData?: Record<string, unknown>;
  }>;
}

interface GrafanaDashboardsConfig {
  apiVersion: number;
  providers: Array<{
    name: string;
    orgId: number;
    folder: string;
    type: string;
    disableDeletion: boolean;
    updateIntervalSeconds: number;
    allowUiUpdates: boolean;
    options: {
      path: string;
      foldersFromFilesStructure?: boolean;
    };
  }>;
}

describe('Alertmanager Configuration', () => {
  let alertmanagerConfig: AlertmanagerConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'alertmanager', 'config.yml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    alertmanagerConfig = yaml.load(fileContent) as AlertmanagerConfig;
  });

  describe('Global Settings', () => {
    test('should have resolve_timeout defined', () => {
      expect(alertmanagerConfig.global.resolve_timeout).toBeDefined();
    });

    test('should have SMTP configuration for email alerts', () => {
      expect(alertmanagerConfig.global.smtp_smarthost).toBeDefined();
      expect(alertmanagerConfig.global.smtp_from).toBeDefined();
    });

    test('should require TLS for SMTP', () => {
      expect(alertmanagerConfig.global.smtp_require_tls).toBe(true);
    });
  });

  describe('Route Configuration', () => {
    test('should have default receiver defined', () => {
      expect(alertmanagerConfig.route.receiver).toBeDefined();
    });

    test('should group alerts by alertname, cluster, and service', () => {
      expect(alertmanagerConfig.route.group_by).toContain('alertname');
      expect(alertmanagerConfig.route.group_by).toContain('cluster');
      expect(alertmanagerConfig.route.group_by).toContain('service');
    });

    test('should have group_wait defined', () => {
      expect(alertmanagerConfig.route.group_wait).toBeDefined();
    });

    test('should have repeat_interval defined', () => {
      expect(alertmanagerConfig.route.repeat_interval).toBeDefined();
    });

    test('should have route for critical alerts', () => {
      const criticalRoute = alertmanagerConfig.route.routes?.find(
        r => r.match?.severity === 'critical'
      );
      expect(criticalRoute).toBeDefined();
      expect(criticalRoute?.receiver).toBe('critical');
    });

    test('should have route for warning alerts', () => {
      const warningRoute = alertmanagerConfig.route.routes?.find(
        r => r.match?.severity === 'warning'
      );
      expect(warningRoute).toBeDefined();
      expect(warningRoute?.receiver).toBe('warning');
    });
  });

  describe('Receivers', () => {
    test('should have receivers defined', () => {
      expect(alertmanagerConfig.receivers).toBeDefined();
      expect(alertmanagerConfig.receivers.length).toBeGreaterThan(0);
    });

    const expectedReceivers = ['default', 'critical', 'warning'];

    test.each(expectedReceivers)('should have %s receiver', (receiverName) => {
      const receiver = alertmanagerConfig.receivers.find(r => r.name === receiverName);
      expect(receiver).toBeDefined();
    });

    test('critical receiver should have email config', () => {
      const criticalReceiver = alertmanagerConfig.receivers.find(r => r.name === 'critical');
      expect(criticalReceiver?.email_configs).toBeDefined();
      expect(criticalReceiver?.email_configs?.length).toBeGreaterThan(0);
    });

    test('critical alerts should have CRITICAL in subject', () => {
      const criticalReceiver = alertmanagerConfig.receivers.find(r => r.name === 'critical');
      const subject = criticalReceiver?.email_configs?.[0].headers?.Subject;
      expect(subject).toContain('CRITICAL');
    });
  });

  describe('Inhibit Rules', () => {
    test('should have inhibit rules defined', () => {
      expect(alertmanagerConfig.inhibit_rules).toBeDefined();
    });

    test('critical alerts should inhibit warning alerts', () => {
      const rule = alertmanagerConfig.inhibit_rules?.find(
        r => r.source_match.severity === 'critical' && r.target_match.severity === 'warning'
      );
      expect(rule).toBeDefined();
      expect(rule?.equal).toContain('alertname');
      expect(rule?.equal).toContain('instance');
    });
  });
});

describe('Loki Configuration', () => {
  let lokiConfig: LokiConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'loki', 'local-config.yaml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    lokiConfig = yaml.load(fileContent) as LokiConfig;
  });

  describe('Server Settings', () => {
    test('should listen on port 3100', () => {
      expect(lokiConfig.server.http_listen_port).toBe(3100);
    });

    test('should have gRPC port configured', () => {
      expect(lokiConfig.server.grpc_listen_port).toBeDefined();
    });

    test('should have auth disabled for local use', () => {
      expect(lokiConfig.auth_enabled).toBe(false);
    });
  });

  describe('Storage Configuration', () => {
    test('should use filesystem storage', () => {
      expect(lokiConfig.common.storage.filesystem).toBeDefined();
    });

    test('should have chunks directory configured', () => {
      expect(lokiConfig.common.storage.filesystem.chunks_directory).toBeDefined();
    });

    test('should have rules directory configured', () => {
      expect(lokiConfig.common.storage.filesystem.rules_directory).toBeDefined();
    });

    test('should have replication factor of 1 for single node', () => {
      expect(lokiConfig.common.replication_factor).toBe(1);
    });
  });

  describe('Schema Configuration', () => {
    test('should have schema configs defined', () => {
      expect(lokiConfig.schema_config.configs).toBeDefined();
      expect(lokiConfig.schema_config.configs.length).toBeGreaterThan(0);
    });

    test('should use boltdb-shipper store', () => {
      const config = lokiConfig.schema_config.configs[0];
      expect(config.store).toBe('boltdb-shipper');
    });

    test('should use filesystem object store', () => {
      const config = lokiConfig.schema_config.configs[0];
      expect(config.object_store).toBe('filesystem');
    });
  });

  describe('Retention Configuration', () => {
    test('should have retention period defined', () => {
      expect(lokiConfig.limits_config.retention_period).toBeDefined();
    });

    test('should have 30 day retention period', () => {
      expect(lokiConfig.limits_config.retention_period).toBe('30d');
    });

    test('should have compactor with retention enabled', () => {
      expect(lokiConfig.compactor?.retention_enabled).toBe(true);
    });
  });

  describe('Query Limits', () => {
    test('should have max_query_length defined', () => {
      expect(lokiConfig.limits_config.max_query_length).toBeDefined();
    });

    test('should have max_entries_limit_per_query defined', () => {
      expect(lokiConfig.limits_config.max_entries_limit_per_query).toBeDefined();
    });
  });
});

describe('Promtail Configuration', () => {
  let promtailConfig: PromtailConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'promtail', 'config.yml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    promtailConfig = yaml.load(fileContent) as PromtailConfig;
  });

  describe('Server Settings', () => {
    test('should have HTTP listen port configured', () => {
      expect(promtailConfig.server.http_listen_port).toBeDefined();
    });
  });

  describe('Client Configuration', () => {
    test('should have Loki client configured', () => {
      expect(promtailConfig.clients).toBeDefined();
      expect(promtailConfig.clients.length).toBeGreaterThan(0);
    });

    test('should push to Loki at correct URL', () => {
      const lokiClient = promtailConfig.clients[0];
      expect(lokiClient.url).toBe('http://loki:3100/loki/api/v1/push');
    });
  });

  describe('Scrape Configs', () => {
    test('should have scrape configs defined', () => {
      expect(promtailConfig.scrape_configs).toBeDefined();
      expect(promtailConfig.scrape_configs.length).toBeGreaterThan(0);
    });

    const expectedJobs = ['system', 'docker', 'kopia', 'qbittorrent', 'slskd'];

    test.each(expectedJobs)('should have %s job configured', (jobName) => {
      const job = promtailConfig.scrape_configs.find(j => j.job_name === jobName);
      expect(job).toBeDefined();
    });

    test('system job should scrape /var/log', () => {
      const systemJob = promtailConfig.scrape_configs.find(j => j.job_name === 'system');
      const path = systemJob?.static_configs?.[0].labels.__path__;
      expect(path).toContain('/var/log');
    });

    test('docker job should use docker_sd_configs', () => {
      const dockerJob = promtailConfig.scrape_configs.find(j => j.job_name === 'docker');
      expect(dockerJob?.docker_sd_configs).toBeDefined();
    });

    test('docker job should connect to Docker socket', () => {
      const dockerJob = promtailConfig.scrape_configs.find(j => j.job_name === 'docker');
      const host = dockerJob?.docker_sd_configs?.[0].host;
      expect(host).toBe('unix:///var/run/docker.sock');
    });

    test('kopia job should scrape kopia logs', () => {
      const kopiaJob = promtailConfig.scrape_configs.find(j => j.job_name === 'kopia');
      const path = kopiaJob?.static_configs?.[0].labels.__path__;
      expect(path).toContain('kopia');
    });
  });

  describe('Labels', () => {
    test('all static jobs should have host label', () => {
      promtailConfig.scrape_configs
        .filter(j => j.static_configs)
        .forEach(job => {
          const labels = job.static_configs?.[0].labels;
          expect(labels?.host).toBe('lepotato');
        });
    });

    test('all static jobs should have job label', () => {
      promtailConfig.scrape_configs
        .filter(j => j.static_configs)
        .forEach(job => {
          const labels = job.static_configs?.[0].labels;
          expect(labels?.job).toBeDefined();
        });
    });
  });
});

describe('Grafana Datasources Configuration', () => {
  let datasourcesConfig: GrafanaDatasourcesConfig;

  beforeAll(() => {
    const configPath = path.join(
      __dirname, '..', 'config', 'grafana', 'provisioning', 'datasources', 'datasources.yml'
    );
    const fileContent = fs.readFileSync(configPath, 'utf8');
    datasourcesConfig = yaml.load(fileContent) as GrafanaDatasourcesConfig;
  });

  describe('API Version', () => {
    test('should have apiVersion 1', () => {
      expect(datasourcesConfig.apiVersion).toBe(1);
    });
  });

  describe('Datasources', () => {
    test('should have datasources defined', () => {
      expect(datasourcesConfig.datasources).toBeDefined();
      expect(datasourcesConfig.datasources.length).toBeGreaterThan(0);
    });

    const expectedDatasources = ['Prometheus', 'Loki', 'Thanos'];

    test.each(expectedDatasources)('should have %s datasource', (dsName) => {
      const ds = datasourcesConfig.datasources.find(d => d.name === dsName);
      expect(ds).toBeDefined();
    });

    test('Prometheus should be default datasource', () => {
      const prometheus = datasourcesConfig.datasources.find(d => d.name === 'Prometheus');
      expect(prometheus?.isDefault).toBe(true);
    });

    test('Prometheus should use proxy access', () => {
      const prometheus = datasourcesConfig.datasources.find(d => d.name === 'Prometheus');
      expect(prometheus?.access).toBe('proxy');
    });

    test('Prometheus should point to prometheus:9090', () => {
      const prometheus = datasourcesConfig.datasources.find(d => d.name === 'Prometheus');
      expect(prometheus?.url).toBe('http://prometheus:9090');
    });

    test('Loki should point to loki:3100', () => {
      const loki = datasourcesConfig.datasources.find(d => d.name === 'Loki');
      expect(loki?.url).toBe('http://loki:3100');
    });

    test('Thanos should point to thanos-query:10902', () => {
      const thanos = datasourcesConfig.datasources.find(d => d.name === 'Thanos');
      expect(thanos?.url).toBe('http://thanos-query:10902');
    });

    test('datasources should not be editable', () => {
      datasourcesConfig.datasources.forEach(ds => {
        expect(ds.editable).toBe(false);
      });
    });
  });
});

describe('Grafana Dashboards Configuration', () => {
  let dashboardsConfig: GrafanaDashboardsConfig;

  beforeAll(() => {
    const configPath = path.join(
      __dirname, '..', 'config', 'grafana', 'provisioning', 'dashboards', 'dashboards.yml'
    );
    const fileContent = fs.readFileSync(configPath, 'utf8');
    dashboardsConfig = yaml.load(fileContent) as GrafanaDashboardsConfig;
  });

  describe('API Version', () => {
    test('should have apiVersion 1', () => {
      expect(dashboardsConfig.apiVersion).toBe(1);
    });
  });

  describe('Providers', () => {
    test('should have providers defined', () => {
      expect(dashboardsConfig.providers).toBeDefined();
      expect(dashboardsConfig.providers.length).toBeGreaterThan(0);
    });

    test('should have PotatoStack provider', () => {
      const provider = dashboardsConfig.providers.find(p => p.name.includes('PotatoStack'));
      expect(provider).toBeDefined();
    });

    test('provider should use file type', () => {
      const provider = dashboardsConfig.providers[0];
      expect(provider.type).toBe('file');
    });

    test('provider should have correct path', () => {
      const provider = dashboardsConfig.providers[0];
      expect(provider.options.path).toContain('dashboards');
    });

    test('provider should allow UI updates', () => {
      const provider = dashboardsConfig.providers[0];
      expect(provider.allowUiUpdates).toBe(true);
    });

    test('provider should have update interval', () => {
      const provider = dashboardsConfig.providers[0];
      expect(provider.updateIntervalSeconds).toBeDefined();
      expect(provider.updateIntervalSeconds).toBeGreaterThan(0);
    });
  });
});
