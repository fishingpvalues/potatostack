# Kubernetes Deployment Checklist

## Pre-Deployment

### 1. Install Kubernetes
- [ ] Install k3s on Le Potato SBC
```bash
curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### 2. Verify Cluster
- [ ] Check nodes are ready
```bash
kubectl get nodes
kubectl cluster-info
```

### 3. Install Core Operators
- [ ] Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

- [ ] Install NGINX Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

- [ ] Wait for operators to be ready
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=120s
```

### 4. Optional: Install Prometheus Operator
- [ ] Add Helm repo and install
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace potatostack-monitoring --create-namespace
```

### 5. Optional: Install ArgoCD
- [ ] Install ArgoCD for GitOps
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Configuration

### 6. Update Secrets
- [ ] Edit `k8s/base/secrets/generated-secrets.yaml`
- [ ] Replace `REPLACE_ME` values:
  - `SURFSHARK_USER` and `SURFSHARK_PASSWORD`
  - `ALERT_EMAIL_USER`, `ALERT_EMAIL_PASSWORD`, `ALERT_EMAIL_TO`
  - `admin-email` for Seafile (or leave default)

**Note**: All other secrets auto-generate via kubernetes-secret-generator!

### 7. Configure Storage (Optional)
- [ ] Review PVC sizes in `k8s/base/pvc/all-pvcs.yaml`
- [ ] Update storage class in `k8s/overlays/production/storage-class.yaml`
- [ ] Or use default dynamic provisioning

### 8. Update Domains (Optional)
- [ ] Edit `k8s/base/ingress/main-ingress.yaml`
- [ ] Replace `lepotato.local` with your domain
- [ ] Update `cert-manager.io/cluster-issuer` email

## Deployment

### 9. Deploy Infrastructure Operators
- [ ] Deploy Mittwald operators + cert-manager config
```bash
kubectl apply -f k8s/base/namespaces/
kubectl apply -f k8s/base/operators/
```

- [ ] Wait for operators to start
```bash
kubectl wait --for=condition=ready pod -l app=secret-generator -n potatostack-operators --timeout=120s
kubectl wait --for=condition=ready pod -l app=replicator -n potatostack-operators --timeout=120s
```

### 10. Deploy Secrets
- [ ] Apply secrets (auto-generation happens here)
```bash
kubectl apply -f k8s/base/secrets/
```

- [ ] Verify secrets were generated
```bash
kubectl get secrets -n potatostack
kubectl get secrets -n potatostack-vpn
kubectl get secrets -n potatostack-monitoring
```

### 11. Deploy Full Stack
- [ ] Deploy everything via Kustomize
```bash
kubectl apply -k k8s/overlays/production
```

- [ ] Watch deployment progress
```bash
kubectl get pods -n potatostack -w
kubectl get pods -n potatostack-monitoring -w
kubectl get pods -n potatostack-vpn -w
```

### 12. Verify Deployments
- [ ] Check all pods are running
```bash
kubectl get pods -A
```

- [ ] Check StatefulSets
```bash
kubectl get statefulsets -n potatostack
```

- [ ] Check Services
```bash
kubectl get svc -A
```

## Post-Deployment

### 13. Get Ingress IP
- [ ] Get LoadBalancer IP
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### 14. Configure DNS
- [ ] Add to `/etc/hosts` or DNS provider
```bash
<INGRESS_IP> git.lepotato.local photos.lepotato.local vault.lepotato.local
<INGRESS_IP> files.lepotato.local torrents.lepotato.local soulseek.lepotato.local
<INGRESS_IP> backup.lepotato.local authelia.lepotato.local portainer.lepotato.local
<INGRESS_IP> uptime.lepotato.local dashboard.lepotato.local grafana.lepotato.local
<INGRESS_IP> prometheus.lepotato.local logs.lepotato.local netdata.lepotato.local
```

### 15. Verify Services
- [ ] Test Gitea: `curl -k https://git.lepotato.local`
- [ ] Test Immich: `curl -k https://photos.lepotato.local`
- [ ] Test Grafana: `curl -k https://grafana.lepotato.local`
- [ ] Test Authelia: `curl -k https://authelia.lepotato.local`

### 16. Check Certificates
- [ ] Verify SSL certificates are issued
```bash
kubectl get certificates -A
kubectl describe certificate lepotato-tls -n potatostack
```

### 17. Configure Applications
- [ ] Access Gitea and complete setup
- [ ] Access Immich and create admin user
- [ ] Access Vaultwarden and create account
- [ ] Access Authelia and configure users
- [ ] Access Grafana and import dashboards
- [ ] Access Portainer and configure

### 18. Configure Monitoring
- [ ] Import Grafana dashboards
- [ ] Configure Prometheus scrape configs (if needed)
- [ ] Set up Alertmanager notifications
- [ ] Configure Uptime Kuma checks

### 19. Set Up Backups
- [ ] Verify CronJob is scheduled
```bash
kubectl get cronjob -n potatostack
```

- [ ] Configure Kopia repository
- [ ] Test backup manually
```bash
kubectl create job --from=cronjob/unified-backups manual-backup-1 -n potatostack
```

### 20. Optional: Set Up GitOps
- [ ] Update ArgoCD application with your Git repo
```bash
# Edit k8s/argocd/application.yaml
# Replace YOUR_USERNAME with your GitHub username
kubectl apply -f k8s/argocd/application.yaml
```

- [ ] Access ArgoCD UI
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Get password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Visit: https://localhost:8080
```

## Monitoring & Maintenance

### 21. Monitor Resources
- [ ] Check resource usage
```bash
kubectl top nodes
kubectl top pods -n potatostack
```

- [ ] Review pod logs
```bash
kubectl logs -n potatostack deployment/gitea
kubectl logs -n potatostack statefulset/postgres
```

### 22. Scale Services (Optional)
- [ ] Set up HPA for high-traffic services
```bash
kubectl autoscale deployment gitea --cpu-percent=80 --min=1 --max=3 -n potatostack
```

### 23. Security Audit
- [ ] Verify Network Policies are active
```bash
kubectl get networkpolicies -A
```

- [ ] Check Pod Security Standards
```bash
kubectl get namespaces -o json | jq '.items[] | {name:.metadata.name, labels:.metadata.labels}'
```

- [ ] Review secret access
```bash
kubectl auth can-i list secrets --namespace=potatostack --as=system:serviceaccount:potatostack:default
```

## Troubleshooting

### Common Issues

**Pods stuck in Pending**
```bash
kubectl describe pod <pod-name> -n potatostack
# Check PVC binding, resource limits, node capacity
```

**Ingress not working**
```bash
kubectl get ingress -A
kubectl describe ingress potatostack-ingress -n potatostack
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

**Certificates not issuing**
```bash
kubectl get certificates -A
kubectl describe certificate <cert-name>
kubectl get challenges -A
kubectl logs -n cert-manager deployment/cert-manager
```

**Secrets not generating**
```bash
kubectl logs -n potatostack-operators deployment/secret-generator
kubectl describe secret <secret-name> -n potatostack
```

**Database connection errors**
```bash
kubectl exec -it -n potatostack statefulset/postgres -- psql -U postgres -c '\l'
kubectl logs -n potatostack statefulset/postgres
```

## Rollback

### If Something Goes Wrong
```bash
# Delete everything
kubectl delete -k k8s/overlays/production

# Restore from backup or redeploy
kubectl apply -k k8s/overlays/production
```

## Summary

✅ **All 30 services** migrated from Docker Compose
✅ **Mittwald operators** (secret-generator + replicator) active
✅ **Auto-SSL** via cert-manager
✅ **GitOps ready** with ArgoCD
✅ **2025 SOTA** best practices

**Total deployment time**: ~10-15 minutes (after initial operator setup)
