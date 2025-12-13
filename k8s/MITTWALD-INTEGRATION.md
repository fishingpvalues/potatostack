# Mittwald Tools Integration

## ✅ All Mittwald Tools Implemented

### 1. kubernetes-secret-generator
**Status**: ✅ Fully Integrated

**Location**: `k8s/base/operators/secret-generator.yaml`

**Image**: `quay.io/mittwald/kubernetes-secret-generator:v3.4.0`

**Usage in Secrets** (`k8s/base/secrets/generated-secrets.yaml`):
```yaml
annotations:
  secret-generator.v1.mittwald.de/autogenerate: password
  secret-generator.v1.mittwald.de/encoding: base64
  secret-generator.v1.mittwald.de/length: "32"
```

**Secrets Auto-Generated**:
- Postgres credentials (POSTGRES_SUPER_PASSWORD, GITEA_DB_PASSWORD, IMMICH_DB_PASSWORD, SEAFILE_DB_PASSWORD)
- Redis credentials
- Authelia secrets (JWT, session, storage, OIDC HMAC)
- Vaultwarden admin token
- Grafana OIDC secret
- Kopia passwords
- Seafile admin password
- FileServer password
- slskd password
- Grafana admin password

**Total**: 15+ auto-generated secrets

### 2. kubernetes-replicator
**Status**: ✅ Fully Integrated

**Location**: `k8s/base/operators/replicator.yaml`

**Image**: `quay.io/mittwald/kubernetes-replicator:v2.9.2`

**Usage**:
```yaml
annotations:
  replicator.v1.mittwald.de/replicate-to: "potatostack-monitoring"
```

**Secrets Replicated Across Namespaces**:
- `postgres-credentials`: potatostack → potatostack-monitoring
- `email-credentials`: potatostack → potatostack-monitoring

**Use Case**: Email credentials needed in both main namespace and monitoring namespace for alerts

### 3. mittnite (Process Supervisor)
**Status**: ⚠️ Not Required

**Reason**: Kubernetes handles process supervision natively:
- **Liveness probes** restart unhealthy containers
- **Init containers** for setup tasks
- **Sidecars** for multi-process patterns
- **DaemonSets** for node-level agents

**Alternative Used**:
- Gluetun pod uses **sidecar pattern** for qBittorrent + slskd
- Monitoring uses **DaemonSets** for node-exporter + smartctl
- Init containers handle swap setup

**Mittnite Would Be Useful For**:
- Running multiple processes in single container (not K8s best practice)
- Signal handling in legacy apps (K8s handles this)
- Process dependencies (K8s init containers do this)

**Conclusion**: Mittnite is designed for Docker/non-orchestrated environments. In Kubernetes, native primitives (sidecars, init containers, liveness probes) are superior.

## Verification

### Check Secret Generator Deployment
```bash
kubectl get deployment -n potatostack-operators secret-generator
kubectl get pods -n potatostack-operators -l app=secret-generator
```

### Check Replicator Deployment
```bash
kubectl get deployment -n potatostack-operators replicator
kubectl get pods -n potatostack-operators -l app=replicator
```

### Verify Secret Auto-Generation
```bash
# Watch secret-generator create secrets
kubectl logs -n potatostack-operators deployment/secret-generator -f

# Check generated secrets
kubectl get secrets -n potatostack
kubectl describe secret postgres-credentials -n potatostack
```

### Verify Secret Replication
```bash
# Check replicated secrets
kubectl get secret postgres-credentials -n potatostack -o yaml
kubectl get secret postgres-credentials -n potatostack-monitoring -o yaml

# Both should have same data (replicated by replicator)
```

## How It Works

### Secret Generator Flow
1. You create Secret with empty `stringData` fields
2. Add annotation: `secret-generator.v1.mittwald.de/autogenerate: password`
3. Secret-generator operator watches for new Secrets
4. Generates random values based on annotations
5. Updates Secret with generated values
6. Secret is now ready to use

### Replicator Flow
1. Create Secret in source namespace with annotation
2. Add annotation: `replicator.v1.mittwald.de/replicate-to: "target-namespace"`
3. Replicator operator watches for changes
4. Copies Secret to target namespace
5. Keeps both in sync (updates propagate)

## Example: Adding New Auto-Generated Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-credentials
  namespace: potatostack
  annotations:
    # Auto-generate password field
    secret-generator.v1.mittwald.de/autogenerate: password
    # Use 64 character length
    secret-generator.v1.mittwald.de/length: "64"
    # Replicate to monitoring namespace
    replicator.v1.mittwald.de/replicate-to: "potatostack-monitoring"
type: Opaque
stringData:
  password: ""  # Will be auto-filled by secret-generator
  username: "myapp"  # Static value
```

After applying:
1. Secret-generator fills `password` with 64-char random string
2. Replicator copies entire Secret to `potatostack-monitoring` namespace
3. Both namespaces can use the same credentials

## Benefits Over Manual Secrets

### Before (Docker Compose)
- ❌ Secrets in `.env` file (plain text)
- ❌ Manual password generation
- ❌ Secrets committed to Git (risk)
- ❌ Same password reused across services
- ❌ Hard to rotate secrets

### After (Kubernetes + Mittwald)
- ✅ Secrets auto-generated with crypto-random values
- ✅ Never committed to Git (generated on first apply)
- ✅ Unique passwords per service
- ✅ Easy rotation (delete secret, reapply)
- ✅ Cross-namespace replication for shared secrets
- ✅ Encrypted at rest in etcd
- ✅ RBAC controls who can read secrets

## Security Best Practices

1. **Never commit generated secrets to Git**
   - Only commit Secret manifests with empty `stringData`
   - Let secret-generator fill values on first deployment

2. **Use appropriate lengths**
   - Passwords: 32-64 characters
   - Tokens: 64+ characters
   - HMAC secrets: 64+ characters

3. **Rotate secrets regularly**
   ```bash
   # Delete secret
   kubectl delete secret postgres-credentials -n potatostack

   # Reapply manifest (secret-generator creates new values)
   kubectl apply -f k8s/base/secrets/generated-secrets.yaml

   # Restart pods to pick up new values
   kubectl rollout restart statefulset/postgres -n potatostack
   ```

4. **Use replicator sparingly**
   - Only replicate secrets that truly need cross-namespace access
   - Prefer service-to-service communication over shared secrets

## Monitoring

### Secret-Generator Metrics
```bash
# Check if secret-generator is working
kubectl logs -n potatostack-operators deployment/secret-generator

# Should see logs like:
# [INFO] Generated secret: postgres-credentials
# [INFO] Updated secret with random values
```

### Replicator Metrics
```bash
# Check if replicator is working
kubectl logs -n potatostack-operators deployment/replicator

# Should see logs like:
# [INFO] Replicated secret: email-credentials → potatostack-monitoring
```

## Troubleshooting

### Secret Not Auto-Generated
1. Check secret-generator is running:
   ```bash
   kubectl get pods -n potatostack-operators
   ```

2. Check annotations are correct:
   ```bash
   kubectl get secret <name> -o yaml
   ```

3. Check secret-generator logs:
   ```bash
   kubectl logs -n potatostack-operators deployment/secret-generator
   ```

### Secret Not Replicated
1. Check replicator is running:
   ```bash
   kubectl get pods -n potatostack-operators
   ```

2. Check target namespace exists:
   ```bash
   kubectl get namespace potatostack-monitoring
   ```

3. Check replicator logs:
   ```bash
   kubectl logs -n potatostack-operators deployment/replicator
   ```

## Summary

✅ **kubernetes-secret-generator**: Fully integrated, 15+ secrets auto-generated
✅ **kubernetes-replicator**: Fully integrated, 2 secrets replicated across namespaces
⚠️ **mittnite**: Not needed (Kubernetes native primitives used instead)

All Mittwald tools that are beneficial for Kubernetes are fully integrated!
