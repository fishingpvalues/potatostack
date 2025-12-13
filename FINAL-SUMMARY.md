# PotatoStack Kubernetes Migration: Final Summary

## ✅ Migration Complete

This document summarizes the successful migration of the PotatoStack from a Docker Compose setup to a production-ready, enterprise-grade Kubernetes stack. The entire infrastructure is now managed declaratively via GitOps principles using ArgoCD.

## 🏛️ Final Architecture

The new architecture is designed for security, observability, and scalability. It is composed of the following key components:

*   **Orchestration:** k3s, a lightweight but powerful Kubernetes distribution.
*   **GitOps:** ArgoCD manages the entire stack declaratively. The configuration is split into an "app-of-apps" pattern for modularity:
    *   `root`: The main ArgoCD application that deploys all other applications.
    *   `infra`: Deploys core infrastructure components like `ingress-nginx` and `cert-manager`.
    *   `monitoring`: Deploys the `kube-prometheus-stack` for monitoring and `loki` for logging.
    *   `workloads`: Deploys all the user-facing applications (Gitea, Immich, etc.).
*   **Ingress:** `ingress-nginx` handles all external traffic, routing it to the appropriate services.
*   **Certificates:** `cert-manager` automatically provisions and renews TLS certificates from Let's Encrypt for all exposed services.
*   **Monitoring:** The `kube-prometheus-stack` provides a complete monitoring solution:
    *   **Prometheus:** Collects metrics from all services.
    *   **Grafana:** Provides pre-configured dashboards for visualizing metrics.
    *   **Alertmanager:** Handles alerts and notifications.
*   **Logging:** `Loki` and `Promtail` collect and aggregate logs from all services in the cluster.
*   **Secrets:** `kubernetes-secret-generator` from Mittwald automatically generates secrets, ensuring that no plaintext secrets are stored in Git.
*   **VPN:** `gluetun` provides a VPN tunnel for specific services (`qbittorrent`, `slskd`), which are configured as sidecars to ensure their traffic is routed through the VPN.

## 🗂️ Key File Locations

*   **ArgoCD Applications:** `k8s/apps/` - This directory contains the ArgoCD application manifests that define the entire stack. The `root.yaml` is the entry point.
*   **Base Manifests:** `k8s/base/` - This directory contains the raw Kubernetes manifests (Deployments, Services, etc.) for all the applications.
    *   `k8s/base/deployments/`: Deployments for stateless applications.
    *   `k8s/base/statefulsets/`: StatefulSets for stateful applications like databases.
    *   `k8s/base/ingress/`: Ingress resources that define the routing rules for external traffic.
    *   `k8s/base/monitoring/`: Monitoring-related manifests.
    *   `k8s/base/operators/`: Manifests for Kubernetes operators like `cert-manager`.
*   **Overlays:** `k8s/overlays/` - This directory contains environment-specific customizations (e.g., `production`).

## 🚀 How to Manage the New Stack

Your entire stack is now managed via Git. To make changes, you simply need to modify the Kubernetes manifests in this repository and push them to your `main` branch. ArgoCD will automatically detect the changes and apply them to your cluster.

### Adding a New Service

1.  **Create the Manifests:** Create the Kubernetes `Deployment`, `Service`, and any other necessary manifests for your new service in the `k8s/base/deployments` directory.
2.  **Add Ingress (if needed):** If the service needs to be exposed externally, add a new rule to the `k8s/base/ingress/main-ingress.yaml` file.
3.  **Commit and Push:** Commit your changes to Git and push them to the `main` branch.
4.  **Sync ArgoCD:** ArgoCD will automatically sync the new application. You can also manually trigger a sync from the ArgoCD UI.

### Viewing Logs

You can view the logs of any pod using `kubectl`:

```bash
kubectl logs -n <namespace> <pod-name>
```

Alternatively, you can use the Grafana UI, which is integrated with Loki, to explore and query logs from all services.

### Monitoring and Alerts

*   **Grafana:** Access the Grafana UI at `https://grafana.lepotato.local` (as defined in your ingress) to view pre-configured dashboards for your cluster and applications.
*   **Prometheus:** You can view the Prometheus UI at `https://prometheus.lepotato.local`.
*   **Alertmanager:** Alerts can be configured in the `k8s/base/monitoring/alertmanager-config.yaml` file.

## 🎉 Conclusion

The migration to Kubernetes is complete. Your new stack is more resilient, scalable, and easier to manage than the previous Docker Compose setup. By leveraging modern GitOps practices and best-in-class open-source tools, your PotatoStack is now truly "SOTA 2025".
