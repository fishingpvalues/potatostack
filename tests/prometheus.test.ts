/**
 * Tests for Prometheus configuration files.
 * Validates prometheus.yml and alerts.yml configurations.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

interface PrometheusConfig {
  global: {
    scrape_interval: string;
    evaluation_interval: string;
    external_labels?: Record<string, string>;
  };
  alerting?: {
    alertmanagers: Array<{
      static_configs: Array<{
        targets: string[];
      }>;
    }>;
  };
  rule_files?: string[];
  scrape_configs: Array<{
    job_name: string;
    static_configs?: Array<{
      targets: string[];
      labels?: Record<string, string>;
    }>;
    docker_sd_configs?: Array<{
      host: string;
    }>;
    relabel_configs?: Array<{
      source_labels?: string[];
      target_label?: string;
      regex?: string;
    }>;
  }>;
}

interface AlertsConfig {
  groups: Array<{
    name: string;
    interval?: string;
    rules: Array<{
      alert: string;
      expr: string;
      for?: string;
      labels?: Record<string, string>;
      annotations?: Record<string, string>;
    }>;
  }>;
}

describe('Prometheus Configuration', () => {
  let prometheusConfig: PrometheusConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'prometheus', 'prometheus.yml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    prometheusConfig = yaml.load(fileContent) as PrometheusConfig;
  });

  describe('Global Settings', () => {
    test('should have scrape_interval defined', () => {
      expect(prometheusConfig.global.scrape_interval).toBeDefined();
    });

    test('should have scrape_interval of 15s', () => {
      expect(prometheusConfig.global.scrape_interval).toBe('15s');
    });

    test('should have evaluation_interval defined', () => {
      expect(prometheusConfig.global.evaluation_interval).toBeDefined();
    });

    test('should have external_labels for cluster identification', () => {
      expect(prometheusConfig.global.external_labels).toBeDefined();
      expect(prometheusConfig.global.external_labels?.cluster).toBe('potatostack');
    });
  });

  describe('Alerting Configuration', () => {
    test('should have alertmanagers configured', () => {
      expect(prometheusConfig.alerting).toBeDefined();
      expect(prometheusConfig.alerting?.alertmanagers).toBeDefined();
      expect(prometheusConfig.alerting?.alertmanagers.length).toBeGreaterThan(0);
    });

    test('should point to alertmanager:9093', () => {
      const targets = prometheusConfig.alerting?.alertmanagers[0].static_configs[0].targets;
      expect(targets).toContain('alertmanager:9093');
    });
  });

  describe('Rule Files', () => {
    test('should have rule_files defined', () => {
      expect(prometheusConfig.rule_files).toBeDefined();
    });

    test('should include alerts.yml', () => {
      expect(prometheusConfig.rule_files).toContain('alerts.yml');
    });
  });

  describe('Scrape Configs', () => {
    test('should have scrape_configs defined', () => {
      expect(prometheusConfig.scrape_configs).toBeDefined();
      expect(prometheusConfig.scrape_configs.length).toBeGreaterThan(0);
    });

    const expectedJobs = [
      'prometheus',
      'node-exporter',
      'cadvisor',
      'smartctl',
      'kopia',
    ];

    test.each(expectedJobs)('should have %s job configured', (jobName) => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === jobName);
      expect(job).toBeDefined();
    });

    test('prometheus job should scrape localhost:9090', () => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === 'prometheus');
      const targets = job?.static_configs?.[0].targets;
      expect(targets).toContain('localhost:9090');
    });

    test('node-exporter job should scrape node-exporter:9100', () => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === 'node-exporter');
      const targets = job?.static_configs?.[0].targets;
      expect(targets).toContain('node-exporter:9100');
    });

    test('cadvisor job should scrape cadvisor:8080', () => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === 'cadvisor');
      const targets = job?.static_configs?.[0].targets;
      expect(targets).toContain('cadvisor:8080');
    });

    test('smartctl job should scrape smartctl-exporter:9633', () => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === 'smartctl');
      const targets = job?.static_configs?.[0].targets;
      expect(targets).toContain('smartctl-exporter:9633');
    });

    test('kopia job should scrape kopia:51516', () => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === 'kopia');
      const targets = job?.static_configs?.[0].targets;
      expect(targets).toContain('kopia:51516');
    });

    test('should have docker-containers job with docker_sd_configs', () => {
      const job = prometheusConfig.scrape_configs.find(j => j.job_name === 'docker-containers');
      expect(job).toBeDefined();
      expect(job?.docker_sd_configs).toBeDefined();
    });
  });
});

describe('Prometheus Alerts Configuration', () => {
  let alertsConfig: AlertsConfig;

  beforeAll(() => {
    const configPath = path.join(__dirname, '..', 'config', 'prometheus', 'alerts.yml');
    const fileContent = fs.readFileSync(configPath, 'utf8');
    alertsConfig = yaml.load(fileContent) as AlertsConfig;
  });

  describe('Alert Groups', () => {
    test('should have groups defined', () => {
      expect(alertsConfig.groups).toBeDefined();
      expect(alertsConfig.groups.length).toBeGreaterThan(0);
    });

    const expectedGroups = [
      'system_alerts',
      'smart_alerts',
      'kopia_alerts',
      'vpn_alerts',
      'container_alerts',
    ];

    test.each(expectedGroups)('should have %s group', (groupName) => {
      const group = alertsConfig.groups.find(g => g.name === groupName);
      expect(group).toBeDefined();
    });
  });

  describe('System Alerts', () => {
    let systemAlerts: AlertsConfig['groups'][0];

    beforeAll(() => {
      systemAlerts = alertsConfig.groups.find(g => g.name === 'system_alerts')!;
    });

    test('should have HighMemoryUsage alert', () => {
      const alert = systemAlerts.rules.find(r => r.alert === 'HighMemoryUsage');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('warning');
    });

    test('should have HighCPUUsage alert', () => {
      const alert = systemAlerts.rules.find(r => r.alert === 'HighCPUUsage');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('warning');
    });

    test('should have DiskSpaceLow alert', () => {
      const alert = systemAlerts.rules.find(r => r.alert === 'DiskSpaceLow');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('critical');
    });

    test('should have HighDiskIO alert', () => {
      const alert = systemAlerts.rules.find(r => r.alert === 'HighDiskIO');
      expect(alert).toBeDefined();
    });

    test('HighMemoryUsage should trigger at 85%', () => {
      const alert = systemAlerts.rules.find(r => r.alert === 'HighMemoryUsage');
      expect(alert?.expr).toContain('85');
    });

    test('DiskSpaceLow should trigger at 10%', () => {
      const alert = systemAlerts.rules.find(r => r.alert === 'DiskSpaceLow');
      expect(alert?.expr).toContain('10');
    });
  });

  describe('SMART Alerts', () => {
    let smartAlerts: AlertsConfig['groups'][0];

    beforeAll(() => {
      smartAlerts = alertsConfig.groups.find(g => g.name === 'smart_alerts')!;
    });

    test('should have SMARTFailure alert', () => {
      const alert = smartAlerts.rules.find(r => r.alert === 'SMARTFailure');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('critical');
    });

    test('should have HighDiskTemperature alert', () => {
      const alert = smartAlerts.rules.find(r => r.alert === 'HighDiskTemperature');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('warning');
    });

    test('should have ReallocatedSectors alert', () => {
      const alert = smartAlerts.rules.find(r => r.alert === 'ReallocatedSectors');
      expect(alert).toBeDefined();
    });

    test('HighDiskTemperature should trigger at 45°C', () => {
      const alert = smartAlerts.rules.find(r => r.alert === 'HighDiskTemperature');
      expect(alert?.expr).toContain('45');
    });
  });

  describe('Kopia Alerts', () => {
    let kopiaAlerts: AlertsConfig['groups'][0];

    beforeAll(() => {
      kopiaAlerts = alertsConfig.groups.find(g => g.name === 'kopia_alerts')!;
    });

    test('should have KopiaBackupFailed alert', () => {
      const alert = kopiaAlerts.rules.find(r => r.alert === 'KopiaBackupFailed');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('critical');
    });

    test('should have KopiaNoRecentSnapshot alert', () => {
      const alert = kopiaAlerts.rules.find(r => r.alert === 'KopiaNoRecentSnapshot');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('warning');
    });

    test('KopiaNoRecentSnapshot should trigger after 24 hours', () => {
      const alert = kopiaAlerts.rules.find(r => r.alert === 'KopiaNoRecentSnapshot');
      expect(alert?.expr).toContain('86400');
    });
  });

  describe('VPN Alerts', () => {
    let vpnAlerts: AlertsConfig['groups'][0];

    beforeAll(() => {
      vpnAlerts = alertsConfig.groups.find(g => g.name === 'vpn_alerts')!;
    });

    test('should have SurfsharkVPNDown alert', () => {
      const alert = vpnAlerts.rules.find(r => r.alert === 'SurfsharkVPNDown');
      expect(alert).toBeDefined();
      expect(alert?.labels?.severity).toBe('critical');
    });
  });

  describe('Container Alerts', () => {
    let containerAlerts: AlertsConfig['groups'][0];

    beforeAll(() => {
      containerAlerts = alertsConfig.groups.find(g => g.name === 'container_alerts')!;
    });

    test('should have ContainerDown alert', () => {
      const alert = containerAlerts.rules.find(r => r.alert === 'ContainerDown');
      expect(alert).toBeDefined();
    });

    test('should have ContainerHighMemory alert', () => {
      const alert = containerAlerts.rules.find(r => r.alert === 'ContainerHighMemory');
      expect(alert).toBeDefined();
    });

    test('ContainerHighMemory should trigger at 90%', () => {
      const alert = containerAlerts.rules.find(r => r.alert === 'ContainerHighMemory');
      expect(alert?.expr).toContain('90');
    });
  });

  describe('Alert Annotations', () => {
    test('all alerts should have summary annotation', () => {
      alertsConfig.groups.forEach(group => {
        group.rules.forEach(rule => {
          expect(rule.annotations?.summary).toBeDefined();
        });
      });
    });

    test('all alerts should have description annotation', () => {
      alertsConfig.groups.forEach(group => {
        group.rules.forEach(rule => {
          expect(rule.annotations?.description).toBeDefined();
        });
      });
    });
  });

  describe('Alert Severity Labels', () => {
    test('all alerts should have severity label', () => {
      alertsConfig.groups.forEach(group => {
        group.rules.forEach(rule => {
          expect(rule.labels?.severity).toBeDefined();
          expect(['critical', 'warning', 'info']).toContain(rule.labels?.severity);
        });
      });
    });
  });
});
