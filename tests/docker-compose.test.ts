/**
 * Tests for docker-compose.yml configuration validation.
 * Validates service definitions, network configurations, volume mounts, and resource limits.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

interface DockerComposeConfig {
  version: string;
  services: Record<string, ServiceConfig>;
  networks: Record<string, NetworkConfig>;
  volumes: Record<string, unknown>;
}

interface ServiceConfig {
  image?: string;
  container_name?: string;
  hostname?: string;
  restart?: string;
  network_mode?: string;
  networks?: string[];
  ports?: string[];
  volumes?: string[];
  environment?: string[];
  depends_on?: Record<string, { condition: string }> | string[];
  cap_add?: string[];
  devices?: string[];
  healthcheck?: {
    test: string[];
    interval?: string;
    timeout?: string;
    retries?: number;
    start_period?: string;
  };
  mem_limit?: string;
  mem_reservation?: string;
  cpus?: number;
  privileged?: boolean;
  labels?: string[];
  command?: string | string[];
}

interface NetworkConfig {
  driver: string;
  name: string;
}

describe('Docker Compose Configuration', () => {
  let dockerCompose: DockerComposeConfig;

  beforeAll(() => {
    const composePath = path.join(__dirname, '..', 'docker-compose.yml');
    const fileContent = fs.readFileSync(composePath, 'utf8');
    dockerCompose = yaml.load(fileContent) as DockerComposeConfig;
  });

  describe('Basic Structure', () => {
    test('should have version 3.8 specified', () => {
      expect(dockerCompose.version).toBe('3.8');
    });

    test('should have services section defined', () => {
      expect(dockerCompose.services).toBeDefined();
      expect(Object.keys(dockerCompose.services).length).toBeGreaterThan(0);
    });

    test('should have networks section defined', () => {
      expect(dockerCompose.networks).toBeDefined();
    });

    test('should have volumes section defined', () => {
      expect(dockerCompose.volumes).toBeDefined();
    });
  });

  describe('Network Configuration', () => {
    const expectedNetworks = ['vpn', 'monitoring', 'proxy', 'default'];

    test.each(expectedNetworks)('should have %s network defined', (network) => {
      expect(dockerCompose.networks[network]).toBeDefined();
    });

    test.each(expectedNetworks)('%s network should use bridge driver', (network) => {
      expect(dockerCompose.networks[network].driver).toBe('bridge');
    });

    test.each(expectedNetworks)('%s network should have potatostack prefix name', (network) => {
      expect(dockerCompose.networks[network].name).toBe(`potatostack_${network}`);
    });
  });

  describe('VPN Stack', () => {
    describe('Surfshark VPN', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.surfshark).toBeDefined();
      });

      test('should have NET_ADMIN capability', () => {
        const surfshark = dockerCompose.services.surfshark;
        expect(surfshark.cap_add).toContain('NET_ADMIN');
      });

      test('should have /dev/net/tun device', () => {
        const surfshark = dockerCompose.services.surfshark;
        expect(surfshark.devices).toContain('/dev/net/tun');
      });

      test('should have healthcheck configured', () => {
        const surfshark = dockerCompose.services.surfshark;
        expect(surfshark.healthcheck).toBeDefined();
        expect(surfshark.healthcheck?.test).toBeDefined();
      });

      test('should be on vpn and monitoring networks', () => {
        const surfshark = dockerCompose.services.surfshark;
        expect(surfshark.networks).toContain('vpn');
        expect(surfshark.networks).toContain('monitoring');
      });
    });

    describe('qBittorrent', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.qbittorrent).toBeDefined();
      });

      test('should route through Surfshark VPN', () => {
        const qbittorrent = dockerCompose.services.qbittorrent;
        expect(qbittorrent.network_mode).toBe('service:surfshark');
      });

      test('should depend on healthy Surfshark', () => {
        const qbittorrent = dockerCompose.services.qbittorrent;
        const dependsOn = qbittorrent.depends_on as Record<string, { condition: string }>;
        expect(dependsOn.surfshark).toBeDefined();
        expect(dependsOn.surfshark.condition).toBe('service_healthy');
      });

      test('should have download volumes mounted', () => {
        const qbittorrent = dockerCompose.services.qbittorrent;
        const hasDownloads = qbittorrent.volumes?.some(v => v.includes('/downloads'));
        expect(hasDownloads).toBe(true);
      });
    });

    describe('slskd (Soulseek)', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.slskd).toBeDefined();
      });

      test('should route through Surfshark VPN', () => {
        const slskd = dockerCompose.services.slskd;
        expect(slskd.network_mode).toBe('service:surfshark');
      });

      test('should depend on healthy Surfshark', () => {
        const slskd = dockerCompose.services.slskd;
        const dependsOn = slskd.depends_on as Record<string, { condition: string }>;
        expect(dependsOn.surfshark).toBeDefined();
        expect(dependsOn.surfshark.condition).toBe('service_healthy');
      });
    });
  });

  describe('Monitoring Stack', () => {
    const monitoringServices = ['prometheus', 'grafana', 'loki', 'promtail', 'alertmanager'];

    test.each(monitoringServices)('%s service should be defined', (service) => {
      expect(dockerCompose.services[service]).toBeDefined();
    });

    describe('Prometheus', () => {
      test('should have config volume mounted', () => {
        const prometheus = dockerCompose.services.prometheus;
        const hasConfig = prometheus.volumes?.some(v => 
          v.includes('prometheus') && v.includes('/etc/prometheus')
        );
        expect(hasConfig).toBe(true);
      });

      test('should have data volume mounted', () => {
        const prometheus = dockerCompose.services.prometheus;
        const hasData = prometheus.volumes?.some(v => v.includes('prometheus_data'));
        expect(hasData).toBe(true);
      });

      test('should expose port 9090', () => {
        const prometheus = dockerCompose.services.prometheus;
        const hasPort = prometheus.ports?.some(p => p.includes('9090'));
        expect(hasPort).toBe(true);
      });

      test('should depend on exporters', () => {
        const prometheus = dockerCompose.services.prometheus;
        const dependsOn = prometheus.depends_on as string[];
        expect(dependsOn).toContain('node-exporter');
        expect(dependsOn).toContain('cadvisor');
        expect(dependsOn).toContain('smartctl-exporter');
      });
    });

    describe('Grafana', () => {
      test('should have provisioning volume mounted', () => {
        const grafana = dockerCompose.services.grafana;
        const hasProvisioning = grafana.volumes?.some(v => v.includes('provisioning'));
        expect(hasProvisioning).toBe(true);
      });

      test('should expose port 3000', () => {
        const grafana = dockerCompose.services.grafana;
        const hasPort = grafana.ports?.some(p => p.includes('3000'));
        expect(hasPort).toBe(true);
      });

      test('should depend on Prometheus and Loki', () => {
        const grafana = dockerCompose.services.grafana;
        const dependsOn = grafana.depends_on as string[];
        expect(dependsOn).toContain('prometheus');
        expect(dependsOn).toContain('loki');
      });
    });

    describe('Loki', () => {
      test('should have config volume mounted', () => {
        const loki = dockerCompose.services.loki;
        const hasConfig = loki.volumes?.some(v => 
          v.includes('loki') && v.includes('/etc/loki')
        );
        expect(hasConfig).toBe(true);
      });

      test('should expose port 3100', () => {
        const loki = dockerCompose.services.loki;
        const hasPort = loki.ports?.some(p => p.includes('3100'));
        expect(hasPort).toBe(true);
      });
    });

    describe('Promtail', () => {
      test('should have /var/log mounted', () => {
        const promtail = dockerCompose.services.promtail;
        const hasVarLog = promtail.volumes?.some(v => v.includes('/var/log'));
        expect(hasVarLog).toBe(true);
      });

      test('should have Docker container logs mounted', () => {
        const promtail = dockerCompose.services.promtail;
        const hasDockerLogs = promtail.volumes?.some(v => v.includes('docker/containers'));
        expect(hasDockerLogs).toBe(true);
      });

      test('should depend on Loki', () => {
        const promtail = dockerCompose.services.promtail;
        const dependsOn = promtail.depends_on as string[];
        expect(dependsOn).toContain('loki');
      });
    });
  });

  describe('Metric Exporters', () => {
    describe('node-exporter', () => {
      test('should be defined', () => {
        expect(dockerCompose.services['node-exporter']).toBeDefined();
      });

      test('should have /proc mounted', () => {
        const nodeExporter = dockerCompose.services['node-exporter'];
        const hasProc = nodeExporter.volumes?.some(v => v.includes('/proc'));
        expect(hasProc).toBe(true);
      });

      test('should have /sys mounted', () => {
        const nodeExporter = dockerCompose.services['node-exporter'];
        const hasSys = nodeExporter.volumes?.some(v => v.includes('/sys'));
        expect(hasSys).toBe(true);
      });

      test('should expose port 9100', () => {
        const nodeExporter = dockerCompose.services['node-exporter'];
        const hasPort = nodeExporter.ports?.some(p => p.includes('9100'));
        expect(hasPort).toBe(true);
      });
    });

    describe('cAdvisor', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.cadvisor).toBeDefined();
      });

      test('should have Docker socket mounted', () => {
        const cadvisor = dockerCompose.services.cadvisor;
        const hasSocket = cadvisor.volumes?.some(v => v.includes('docker.sock'));
        expect(hasSocket).toBe(true);
      });

      test('should be privileged', () => {
        const cadvisor = dockerCompose.services.cadvisor;
        expect(cadvisor.privileged).toBe(true);
      });
    });

    describe('smartctl-exporter', () => {
      test('should be defined', () => {
        expect(dockerCompose.services['smartctl-exporter']).toBeDefined();
      });

      test('should be privileged for disk access', () => {
        const smartctl = dockerCompose.services['smartctl-exporter'];
        expect(smartctl.privileged).toBe(true);
      });

      test('should expose port 9633', () => {
        const smartctl = dockerCompose.services['smartctl-exporter'];
        const hasPort = smartctl.ports?.some(p => p.includes('9633'));
        expect(hasPort).toBe(true);
      });
    });
  });

  describe('Resource Limits', () => {
    const memoryLimits: Record<string, number> = {
      surfshark: 256,
      qbittorrent: 512,
      slskd: 384,
      kopia: 768,
      prometheus: 512,
      grafana: 384,
      loki: 256,
      promtail: 128,
      alertmanager: 128,
      nextcloud: 512,
      portainer: 128,
      watchtower: 64,
      'node-exporter': 64,
      cadvisor: 128,
      'smartctl-exporter': 64,
    };

    test.each(Object.entries(memoryLimits))(
      '%s should have memory limit of %dMB or less',
      (serviceName, expectedLimit) => {
        const service = dockerCompose.services[serviceName];
        if (service) {
          expect(service.mem_limit).toBeDefined();
          const limitValue = parseInt(service.mem_limit!.replace(/[mMgG]/g, ''));
          expect(limitValue).toBeLessThanOrEqual(expectedLimit * 2);
        }
      }
    );

    test.each(Object.keys(memoryLimits))(
      '%s should have CPU limit defined',
      (serviceName) => {
        const service = dockerCompose.services[serviceName];
        if (service) {
          expect(service.cpus).toBeDefined();
        }
      }
    );
  });

  describe('Kopia Backup', () => {
    test('should be defined', () => {
      expect(dockerCompose.services.kopia).toBeDefined();
    });

    test('should have repository volume mounted', () => {
      const kopia = dockerCompose.services.kopia;
      const hasRepo = kopia.volumes?.some(v => v.includes('repository'));
      expect(hasRepo).toBe(true);
    });

    test('should have Prometheus metrics enabled', () => {
      const kopia = dockerCompose.services.kopia;
      const hasMetrics = kopia.environment?.some(e => 
        e.includes('KOPIA_PROMETHEUS_ENABLED')
      );
      expect(hasMetrics).toBe(true);
    });

    test('should have healthcheck configured', () => {
      const kopia = dockerCompose.services.kopia;
      expect(kopia.healthcheck).toBeDefined();
    });

    test('should have SYS_ADMIN capability for FUSE', () => {
      const kopia = dockerCompose.services.kopia;
      expect(kopia.cap_add).toContain('SYS_ADMIN');
    });

    test('should have /dev/fuse device', () => {
      const kopia = dockerCompose.services.kopia;
      const hasFuse = kopia.devices?.some(d => d.includes('fuse'));
      expect(hasFuse).toBe(true);
    });
  });

  describe('Nextcloud', () => {
    test('should be defined', () => {
      expect(dockerCompose.services.nextcloud).toBeDefined();
    });

    test('database should be defined', () => {
      expect(dockerCompose.services['nextcloud-db']).toBeDefined();
    });

    test('should depend on database', () => {
      const nextcloud = dockerCompose.services.nextcloud;
      const dependsOn = nextcloud.depends_on as string[];
      expect(dependsOn).toContain('nextcloud-db');
    });

    test('should have external storage mounts for torrents', () => {
      const nextcloud = dockerCompose.services.nextcloud;
      const hasTorrents = nextcloud.volumes?.some(v => v.includes('torrents'));
      expect(hasTorrents).toBe(true);
    });

    test('should have external storage mounts for soulseek', () => {
      const nextcloud = dockerCompose.services.nextcloud;
      const hasSoulseek = nextcloud.volumes?.some(v => v.includes('soulseek'));
      expect(hasSoulseek).toBe(true);
    });
  });

  describe('Management Tools', () => {
    describe('Portainer', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.portainer).toBeDefined();
      });

      test('should have Docker socket mounted', () => {
        const portainer = dockerCompose.services.portainer;
        const hasSocket = portainer.volumes?.some(v => v.includes('docker.sock'));
        expect(hasSocket).toBe(true);
      });
    });

    describe('Watchtower', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.watchtower).toBeDefined();
      });

      test('should have cleanup enabled', () => {
        const watchtower = dockerCompose.services.watchtower;
        const hasCleanup = watchtower.environment?.some(e => 
          e.includes('WATCHTOWER_CLEANUP=true')
        );
        expect(hasCleanup).toBe(true);
      });
    });

    describe('Uptime Kuma', () => {
      test('should be defined', () => {
        expect(dockerCompose.services['uptime-kuma']).toBeDefined();
      });
    });

    describe('Dozzle', () => {
      test('should be defined', () => {
        expect(dockerCompose.services.dozzle).toBeDefined();
      });

      test('should have Docker socket mounted read-only', () => {
        const dozzle = dockerCompose.services.dozzle;
        const hasSocket = dozzle.volumes?.some(v => 
          v.includes('docker.sock') && v.includes(':ro')
        );
        expect(hasSocket).toBe(true);
      });
    });
  });

  describe('Reverse Proxy', () => {
    test('Nginx Proxy Manager should be defined', () => {
      expect(dockerCompose.services['nginx-proxy-manager']).toBeDefined();
    });

    test('should expose HTTP port 80', () => {
      const npm = dockerCompose.services['nginx-proxy-manager'];
      const hasPort = npm.ports?.some(p => p.includes('80:80'));
      expect(hasPort).toBe(true);
    });

    test('should expose HTTPS port 443', () => {
      const npm = dockerCompose.services['nginx-proxy-manager'];
      const hasPort = npm.ports?.some(p => p.includes('443:443'));
      expect(hasPort).toBe(true);
    });

    test('should expose admin port 81', () => {
      const npm = dockerCompose.services['nginx-proxy-manager'];
      const hasPort = npm.ports?.some(p => p.includes('81:81'));
      expect(hasPort).toBe(true);
    });
  });

  describe('Homepage Dashboard', () => {
    test('should be defined', () => {
      expect(dockerCompose.services.homepage).toBeDefined();
    });

    test('should have config directory mounted', () => {
      const homepage = dockerCompose.services.homepage;
      const hasConfig = homepage.volumes?.some(v => 
        v.includes('homepage') && v.includes('/app/config')
      );
      expect(hasConfig).toBe(true);
    });

    test('should have Docker socket mounted for container discovery', () => {
      const homepage = dockerCompose.services.homepage;
      const hasSocket = homepage.volumes?.some(v => v.includes('docker.sock'));
      expect(hasSocket).toBe(true);
    });
  });

  describe('Restart Policies', () => {
    test('all services should have restart policy', () => {
      Object.entries(dockerCompose.services).forEach(([name, config]) => {
        expect(config.restart).toBeDefined();
        expect(['always', 'unless-stopped', 'on-failure']).toContain(config.restart);
      });
    });

    const criticalServices = ['surfshark', 'prometheus', 'grafana', 'kopia', 'nextcloud'];
    
    test.each(criticalServices)(
      '%s should use unless-stopped restart policy',
      (serviceName) => {
        const service = dockerCompose.services[serviceName];
        expect(service.restart).toBe('unless-stopped');
      }
    );
  });
});
