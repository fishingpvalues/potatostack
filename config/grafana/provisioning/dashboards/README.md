This folder contains default dashboards provisioned by Grafana.

The Loki log monitoring dashboard has been removed by default because Loki/Promtail
are optional (profile: monitoring-extra). If you enable Loki, you can reintroduce a
Loki dashboard by importing one from Grafana.com or by restoring a JSON dashboard
that queries the `Loki` datasource.

