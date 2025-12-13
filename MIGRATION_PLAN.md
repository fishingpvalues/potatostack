# Complete Kubernetes Migration & Modernization Plan

## Analysis Summary

The initial migration from Docker Compose to Kubernetes has established a solid foundation using modern GitOps principles. The use of Kustomize, ArgoCD, and specialized operators from Mittwald for secret management (`secret-generator`, `replicator`) demonstrates a commitment to a declarative, secure, and maintainable infrastructure.

A significant portion of the services defined in `docker-compose.yml` have been successfully migrated to Kubernetes manifests under the `k8s/base` directory. However, a gap analysis reveals that several key components are either missing, partially implemented, or require adjustments to align with Kubernetes best practices.

## Key Findings & Gaps

*   **Partially Migrated Services:** Many services (`cadvisor`, `diun`, `dozzle`, etc.) have been consolidated into `monitoring-exporters.yaml` and `management-tools.yaml`. This is a good optimization, but these manifests need to be reviewed to ensure full feature parity with their Docker Compose counterparts.
*   **Missing Core Components:**
    *   **Ingress:** `Nginx Proxy Manager` has not been migrated. The `MIGRATION.md` file correctly identifies that a Kubernetes-native Ingress Controller (`ingress-nginx`) should be used instead.
    *   **Monitoring:** While many exporters are present, the core `Prometheus` server and `Alertmanager` services are missing. The plan is to use the Prometheus Operator, which is a best practice but not yet implemented.
*   **Incorrect Service Architecture:**
    *   **VPN-bound Services:** `qbittorrent` and `slskd` are missing. The documentation indicates they should be implemented as **sidecars** within the `gluetun` VPN pod to ensure their traffic is correctly routed. This has not been done yet.
*   **Other Missing Services:** `netdata`, `homepage`, and `portainer` are missing from the Kubernetes configuration.
*   **GitOps Configuration:** The ArgoCD `application.yaml` contains a placeholder repository URL and has a complex structure for deploying the monitoring stack, which can be simplified.

---

## Complete Migration & Modernization Plan

The following steps will complete the migration, address the identified gaps, and ensure the entire stack is production-ready, secure, and manageable via GitOps.

### 1. Implement Production-Grade Ingress

*   **Action:** Replace the legacy `Nginx Proxy Manager` with the `ingress-nginx` controller, as planned in the migration documents.
*   **Steps:**
    1.  Create a manifest to deploy `ingress-nginx` using the official Helm chart, managed via ArgoCD.
    2.  Migrate the proxy rules from `nginx-proxy-manager` to Kubernetes `Ingress` resources.
    3.  Integrate with `cert-manager` (which is already planned) to automate TLS certificate acquisition and renewal for all exposed services.
*   **Outcome:** A robust, scalable, and automated way to manage external access to services, following Kubernetes standards.

### 2. Deploy the Prometheus Operator

*   **Action:** Implement the full Prometheus monitoring stack using the `prometheus-operator`.
*   **Steps:**
    1.  Add the official `kube-prometheus-stack` Helm chart as an ArgoCD application. This will deploy Prometheus, Grafana, Alertmanager, and the necessary operator.
    2.  Configure the operator to discover `ServiceMonitor` and `PodMonitor` resources, which will be created for all other services in the cluster. This automates metric scraping.
    3.  Deploy a manifest for `Alertmanager` and configure its routing rules.
*   **Outcome:** A powerful, Kubernetes-native monitoring system that automatically scales and adapts as services are added or changed.

### 3. Re-architect VPN Services as Sidecars

*   **Action:** Add `qbittorrent` and `slskd` to the `gluetun-vpn` deployment.
*   **Steps:**
    1.  Modify the `k8s/base/deployments/gluetun-vpn.yaml` manifest.
    2.  Add `qbittorrent` and `slskd` as additional containers (sidecars) in the same `PodSpec`.
    3.  Configure the pod's networking to ensure the sidecars' traffic is routed through the primary `gluetun` container.
*   **Outcome:** `qbittorrent` and `slskd` will run securely, with all traffic forced through the VPN, as intended in the original `docker-compose` setup.

### 4. Migrate Remaining Services

*   **Action:** Create Kubernetes manifests for the services that are still missing.
*   **Steps:**
    1.  Create `Deployment` and `Service` manifests for `netdata` and `homepage`.
    2.  Evaluate the need for `Portainer`. In a GitOps workflow, Portainer is often omitted as all management should go through Git. We can add it if desired, but it's not essential for a pure GitOps stack.
*   **Outcome:** All services from the original stack will be present and running in Kubernetes.

### 5. Refine ArgoCD Configuration

*   **Action:** Clean up and correct the ArgoCD application definitions.
*   **Steps:**
    1.  Update the `repoURL` in `k8s/argocd/application.yaml` to point to the correct Git repository.
    2.  Restructure the ArgoCD applications for better clarity. Instead of complex include rules, we can have a main "app-of-apps" that manages other applications for `workloads`, `monitoring`, `ingress`, etc.
*   **Outcome:** A clean, maintainable GitOps structure that is easy to understand and manage.

### 6. Final Report & Handover

*   **Action:** Once all technical steps are complete, provide a final summary.
*   **Steps:**
    1.  Create a `FINAL-SUMMARY.md` documenting the final architecture, key manifest locations, and instructions for managing the stack (e.g., adding a new service, viewing logs, monitoring alerts).
*   **Outcome:** Clear documentation for the user to confidently take ownership of their new production-ready Kubernetes stack.
