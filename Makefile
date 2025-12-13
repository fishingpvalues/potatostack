.PHONY: help env setup preflight pull up down restart ps logs validate health health-quick health-security vpn-test backup-verify conftest secrets-init secrets-edit secrets-list k8s-setup k8s-operators k8s-up k8s-down k8s-restart k8s-status k8s-logs k8s-describe k8s-port-forward-grafana k8s-port-forward-prometheus k8s-port-forward-argocd k8s-backup k8s-restore k8s-clean k8s-validate helm-repos helm-install-operators helm-install-monitoring helm-install-argocd helm-install-gitea helm-install-all helm-uninstall-all helm-list helm-upgrade-all stack-up stack-down stack-status

.DEFAULT_GOAL := help

## Detect docker compose binary or plugin
DC := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

help:
	@echo "PotatoStack Makefile Targets"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make env              Create .env from .env.example"
	@echo "  make preflight        Run pre-flight system checks"
	@echo "  make setup            Run full system setup (requires sudo)"
	@echo ""
	@echo "Docker Runtime:"
	@echo "  make up               Start all Docker services"
	@echo "  make down             Stop all Docker services"
	@echo "  make restart          Restart all Docker services"
	@echo "  make ps               List running containers"
	@echo "  make logs             Follow container logs"
	@echo "  make pull             Pull latest Docker images"
	@echo ""
	@echo "Kubernetes (SOTA 2025):"
	@echo "  make k8s-setup        Full k3s + operators setup"
	@echo "  make k8s-operators    Install cert-manager, ingress-nginx, operators"
	@echo "  make k8s-up           Deploy full stack to k8s"
	@echo "  make k8s-down         Delete all k8s resources"
	@echo "  make k8s-restart      Restart all deployments"
	@echo "  make k8s-status       Show all resources status"
	@echo "  make k8s-logs         Follow logs (all namespaces)"
	@echo "  make k8s-describe     Describe all resources"
	@echo "  make k8s-backup       Backup Postgres to backup.sql"
	@echo "  make k8s-restore      Restore Postgres from backup.sql"
	@echo "  make k8s-clean        Delete namespaces & cleanup"
	@echo "  make k8s-validate     Validate k8s manifests"
	@echo ""
	@echo "Kubernetes Port Forwards:"
	@echo "  make k8s-port-forward-grafana      Access Grafana at localhost:3000"
	@echo "  make k8s-port-forward-prometheus   Access Prometheus at localhost:9090"
	@echo "  make k8s-port-forward-argocd       Access ArgoCD at localhost:8080"
	@echo ""
	@echo "Helm Stack Management (SOTA 2025):"
	@echo "  make helm-repos                    Add all Helm repositories"
	@echo "  make helm-install-operators        Install cert-manager, ingress-nginx, kyverno"
	@echo "  make helm-install-monitoring       Install Prometheus, Grafana, Loki"
	@echo "  make helm-install-argocd           Install ArgoCD for GitOps"
	@echo "  make helm-install-all              Install complete stack via Helm"
	@echo "  make helm-uninstall-all            Uninstall all Helm releases"
	@echo "  make helm-list                     List all Helm releases"
	@echo "  make stack-up                      🚀 Full stack startup (Helm + K8s)"
	@echo "  make stack-down                    🛑 Full stack teardown"
	@echo "  make stack-status                  📊 Complete stack status"
	@echo ""
	@echo "Health & Monitoring:"
	@echo "  make health           Full system health check"
	@echo "  make health-quick     Quick status check"
	@echo "  make health-security  Security audit"
	@echo "  make vpn-test         Verify VPN kill switch"
	@echo "  make backup-verify    Verify Kopia backups"
	@echo ""
	@echo "Secrets Management:"
	@echo "  make secrets-init     Initialize secrets store"
	@echo "  make secrets-edit     Edit encrypted secrets"
	@echo "  make secrets-list     List all encrypted secrets"
	@echo ""
	@echo "Code Quality:"
	@echo "  make validate         Validate docker-compose.yml"
	@echo "  make conftest         Run OPA policy tests"
	@echo ""
	@echo "Profiles:"
	@echo "  make up-cache         Start with Redis cache profile"

env:
	@test -f .env || cp .env.example .env
	@echo ".env ready. Edit as needed."

preflight:
	@sudo ./setup.sh --preflight

setup:
	@sudo ./setup.sh --non-interactive

pull:
	@$(DC) pull

up:
	@$(DC) up -d

up-cache:
	@COMPOSE_PROFILES=cache $(DC) up -d



down:
	@$(DC) down

restart:
	@$(DC) restart

ps:
	@$(DC) ps

logs:
	@$(DC) logs -f

validate:
	@$(DC) -f docker-compose.yml config -q

health:
	@./scripts/health-check.sh

health-quick:
	@./scripts/health-check.sh --quick

health-security:
	@./scripts/health-check.sh --security

vpn-test:
	@./scripts/verify-vpn-killswitch.sh

backup-verify:
	@./scripts/verify-kopia-backups.sh

secrets-init:
	@./scripts/secrets.sh init

secrets-edit:
	@./scripts/secrets.sh edit

secrets-list:
	@./scripts/secrets.sh list

conftest:
	@conftest test -p policy docker-compose.yml

## ========================================
## Kubernetes Commands (SOTA 2025 Stack)
## ========================================

k8s-setup:
	@echo "Installing k3s..."
	@curl -sfL https://get.k3s.io | sh -
	@echo "Waiting for k3s to be ready..."
	@sleep 10
	@sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=120s
	@mkdir -p ~/.kube
	@sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
	@sudo chown $(shell id -u):$(shell id -g) ~/.kube/config
	@echo "k3s installed successfully!"
	@make k8s-operators

k8s-operators:
	@echo "Installing cert-manager..."
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
	@echo "Waiting for cert-manager..."
	@kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
	@echo ""
	@echo "Installing ingress-nginx..."
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
	@echo "Waiting for ingress-nginx..."
	@kubectl wait --for=condition=Available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx
	@echo ""
	@echo "Installing infrastructure operators..."
	@kubectl apply -f k8s/base/operators/
	@echo "Operators installed successfully!"

k8s-up:
	@echo "Deploying PotatoStack to Kubernetes..."
	@kubectl apply -k k8s/overlays/production
	@echo ""
	@echo "Deployment initiated! Check status with: make k8s-status"
	@echo "Get Ingress IP: kubectl get svc -n ingress-nginx ingress-nginx-controller"

k8s-down:
	@echo "Stopping all k8s resources..."
	@kubectl delete -k k8s/overlays/production --ignore-not-found=true
	@echo "Resources deleted!"

k8s-restart:
	@echo "Restarting all deployments..."
	@kubectl rollout restart deployment -n potatostack
	@kubectl rollout restart deployment -n potatostack-monitoring
	@kubectl rollout restart statefulset -n potatostack
	@echo "Restart initiated!"

k8s-status:
	@echo "=== Namespaces ==="
	@kubectl get namespaces | grep -E 'potatostack|argocd|cert-manager|ingress-nginx|NAME'
	@echo ""
	@echo "=== Pods (All Namespaces) ==="
	@kubectl get pods -A | grep -E 'potatostack|argocd|cert-manager|ingress-nginx|NAME'
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n potatostack
	@echo ""
	@echo "=== Ingress ==="
	@kubectl get ingress -A
	@echo ""
	@echo "=== PVCs ==="
	@kubectl get pvc -n potatostack

k8s-logs:
	@echo "Following logs from all potatostack pods..."
	@kubectl logs -f -n potatostack -l app.kubernetes.io/name --max-log-requests=10

k8s-describe:
	@echo "=== Deployments ==="
	@kubectl describe deployments -n potatostack
	@echo ""
	@echo "=== StatefulSets ==="
	@kubectl describe statefulsets -n potatostack
	@echo ""
	@echo "=== Services ==="
	@kubectl describe svc -n potatostack

k8s-port-forward-grafana:
	@echo "Forwarding Grafana to localhost:3000..."
	@kubectl port-forward -n potatostack-monitoring svc/grafana 3000:3000

k8s-port-forward-prometheus:
	@echo "Forwarding Prometheus to localhost:9090..."
	@kubectl port-forward -n potatostack-monitoring svc/prometheus-operated 9090:9090

k8s-port-forward-argocd:
	@echo "Forwarding ArgoCD to localhost:8080..."
	@echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	@kubectl port-forward -n argocd svc/argocd-server 8080:443

k8s-backup:
	@echo "Backing up Postgres to backup.sql..."
	@kubectl exec -n potatostack statefulset/postgres -- pg_dumpall -U postgres > backup.sql
	@echo "Backup complete: backup.sql"

k8s-restore:
	@echo "Restoring Postgres from backup.sql..."
	@cat backup.sql | kubectl exec -i -n potatostack statefulset/postgres -- psql -U postgres
	@echo "Restore complete!"

k8s-clean:
	@echo "Cleaning up all k8s resources..."
	@kubectl delete namespace potatostack --ignore-not-found=true
	@kubectl delete namespace potatostack-monitoring --ignore-not-found=true
	@kubectl delete namespace argocd --ignore-not-found=true
	@echo "Cleanup complete!"

k8s-validate:
	@echo "Validating Kubernetes manifests..."
	@kubectl apply -k k8s/overlays/production --dry-run=client
	@echo "Validation successful!"

## ========================================
## Helm Commands (SOTA 2025 Stack)
## ========================================

helm-repos:
	@echo "Adding Helm repositories..."
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add grafana https://grafana.github.io/helm-charts
	@helm repo add argo https://argoproj.github.io/argo-helm
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	@helm repo add kyverno https://kyverno.github.io/kyverno/
	@helm repo add mittwald https://helm.mittwald.de
	@helm repo add bitnami https://charts.bitnami.com/bitnami
	@helm repo add authelia https://charts.authelia.com
	@helm repo add netdata https://netdata.github.io/helmchart/
	@helm repo add bjw-s https://bjw-s.github.io/helm-charts
	@helm repo add gethomepage https://gethomepage.github.io/homepage/
	@helm repo add portainer https://portainer.github.io/k8s/
	@helm repo add dozzle https://amir20.github.io/dozzle/
	@helm repo update
	@echo "Helm repositories added and updated!"

helm-install-operators:
	@echo "Installing operators via Helm..."
	@helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
		--version v1.19.2 \
		--namespace cert-manager --create-namespace \
		--set crds.enabled=true \
		-f helm/values/cert-manager.yaml --wait
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		-f helm/values/ingress-nginx.yaml --wait
	@helm upgrade --install kyverno kyverno/kyverno \
		--namespace kyverno --create-namespace \
		-f helm/values/kyverno.yaml --wait
	@helm upgrade --install kubernetes-secret-generator mittwald/kubernetes-secret-generator \
		--namespace kube-system \
		--set secretLength=32 \
		--set watchNamespace="" --wait
	@helm upgrade --install kubernetes-replicator mittwald/kubernetes-replicator \
		--namespace kube-system --wait
	@echo "Operators installed successfully!"

helm-install-monitoring:
	@echo "Installing monitoring stack via Helm..."
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
		--namespace potatostack-monitoring --create-namespace \
		-f helm/values/kube-prometheus-stack.yaml --wait
	@helm upgrade --install loki grafana/loki-stack \
		--namespace potatostack-monitoring \
		-f helm/values/loki-stack.yaml --wait
	@helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter \
		--namespace potatostack-monitoring \
		-f helm/values/blackbox-exporter.yaml --wait
	@helm upgrade --install netdata netdata/netdata \
		--namespace potatostack-monitoring \
		-f helm/values/netdata.yaml --wait || true
	@echo "Monitoring stack installed successfully!"

helm-install-argocd:
	@echo "Installing ArgoCD via Helm..."
	@helm upgrade --install argocd argo/argo-cd \
		--namespace argocd --create-namespace \
		-f helm/values/argocd.yaml --wait
	@echo "ArgoCD installed successfully!"
	@echo "Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

helm-install-gitea:
	@echo "Installing Gitea via Helm..."
	@helm upgrade --install gitea oci://docker.gitea.com/charts/gitea \
		--namespace potatostack --create-namespace \
		-f helm/values/gitea.yaml --wait
	@echo "Gitea installed successfully!"

helm-install-all:
	@echo "Installing complete SOTA 2025 stack via Helm..."
	@make helm-repos
	@make helm-install-operators
	@make helm-install-monitoring
	@make helm-install-argocd
	@make helm-install-datastores
	@make helm-install-apps
	@echo "Waiting for operators to be ready..."
	@sleep 30
	@echo "Complete stack installed successfully!"

helm-uninstall-all:
	@echo "Uninstalling Helm releases..."
	@helm uninstall prometheus -n potatostack-monitoring --ignore-not-found
	@helm uninstall loki -n potatostack-monitoring --ignore-not-found
	@helm uninstall argocd -n argocd --ignore-not-found
	@helm uninstall gitea -n potatostack --ignore-not-found
	@helm uninstall kyverno -n kyverno --ignore-not-found
	@helm uninstall ingress-nginx -n ingress-nginx --ignore-not-found
	@helm uninstall cert-manager -n cert-manager --ignore-not-found
	@helm uninstall kubernetes-secret-generator -n kube-system --ignore-not-found
	@helm uninstall redis -n potatostack --ignore-not-found
	@helm uninstall vaultwarden -n potatostack --ignore-not-found
	@helm uninstall immich -n potatostack --ignore-not-found
	@helm uninstall seafile -n potatostack --ignore-not-found
	@helm uninstall kopia -n potatostack --ignore-not-found
	@helm uninstall gluetun-stack -n potatostack --ignore-not-found
	@helm uninstall uptime-kuma -n potatostack --ignore-not-found
	@helm uninstall homepage -n potatostack --ignore-not-found
	@helm uninstall portainer -n potatostack --ignore-not-found
	@helm uninstall dozzle -n potatostack --ignore-not-found
	@helm uninstall fileserver -n potatostack --ignore-not-found
	@helm uninstall speedtest-exporter -n potatostack-monitoring --ignore-not-found
	@helm uninstall fritzbox-exporter -n potatostack-monitoring --ignore-not-found
	@helm uninstall blackbox -n potatostack-monitoring --ignore-not-found
	@helm uninstall netdata -n potatostack-monitoring --ignore-not-found
	@echo "All Helm releases uninstalled!"

helm-list:
	@echo "=== Helm Releases ==="
	@helm list -A

helm-upgrade-all:
	@echo "Upgrading all Helm releases..."
	@make helm-install-all
	@echo "All Helm releases upgraded!"

## Complete stack management (Helm + Kustomize hybrid)
stack-up:
	@echo "🚀 Starting complete PotatoStack (Helm + K8s)..."
	@make helm-install-all
	@echo "✅ PotatoStack is ready!"
	@echo "📊 Access Grafana: make k8s-port-forward-grafana"
	@echo "🔧 Access ArgoCD: make k8s-port-forward-argocd"

## ========================================
## Additional Helm: Datastores & Apps
## ========================================

# Datastores first to satisfy dependencies
helm-install-datastores:
	@echo "Installing shared datastores via Helm..."
	@helm upgrade --install redis bitnami/redis \
		--namespace potatostack --create-namespace \
		-f helm/values/redis.yaml --wait
	@echo "Datastores installed!"

# App workloads via Helm (community charts)
helm-install-apps:
	@echo "Installing application workloads via Helm..."
	@helm upgrade --install vaultwarden bjw-s/app-template \
		--namespace potatostack --create-namespace \
		-f helm/values/vaultwarden.yaml --wait
	@helm upgrade --install immich bjw-s/app-template \
		--namespace potatostack \
		-f helm/values/immich.yaml --wait
	@helm upgrade --install seafile bjw-s/app-template \
		--namespace potatostack \
		-f helm/values/seafile.yaml --wait
	@helm upgrade --install kopia bjw-s/app-template \
		--namespace potatostack \
		-f helm/values/kopia.yaml --wait
	@helm upgrade --install gluetun-stack bjw-s/app-template \
		--namespace potatostack \
		-f helm/values/gluetun-stack.yaml --wait
	@helm upgrade --install uptime-kuma bjw-s/app-template \
		--namespace potatostack \
		-f helm/values/uptime-kuma.yaml --wait
	@helm upgrade --install fileserver bjw-s/app-template \
		--namespace potatostack \
		-f helm/values/fileserver.yaml --wait
	@helm upgrade --install speedtest-exporter bjw-s/app-template \
		--namespace potatostack-monitoring --create-namespace \
		-f helm/values/speedtest-exporter.yaml --wait
	@helm upgrade --install fritzbox-exporter bjw-s/app-template \
		--namespace potatostack-monitoring \
		-f helm/values/fritzbox-exporter.yaml --wait
	@helm upgrade --install homepage gethomepage/homepage \
		--namespace potatostack \
		-f helm/values/homepage.yaml --wait
	@helm upgrade --install portainer portainer/portainer \
		--namespace potatostack \
		-f helm/values/portainer.yaml --wait
	@helm upgrade --install dozzle dozzle/dozzle \
		--namespace potatostack \
		-f helm/values/dozzle.yaml --wait
	@echo "Application workloads installed!"

stack-down:
	@echo "🛑 Stopping complete PotatoStack..."
	@make helm-uninstall-all
	@make k8s-clean
	@echo "✅ PotatoStack stopped!"

stack-status:
	@echo "=== Stack Status ==="
	@make helm-list
	@echo ""
	@make k8s-status
