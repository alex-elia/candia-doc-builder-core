# Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Candia Doc Builder to production.

## Prerequisites

1. Kubernetes cluster access
2. `kubectl` configured
3. Access to GHCR (image pull secrets)

## Setup

### 1. Create Image Pull Secret

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --namespace=backend
```

### 2. Create Application Secrets

```bash
kubectl create secret generic candia-secrets \
  --from-literal=supabase-url=$SUPABASE_URL \
  --from-literal=supabase-service-role-key=$SUPABASE_SERVICE_ROLE_KEY \
  --from-literal=ovh-storage-endpoint=$OVH_STORAGE_ENDPOINT \
  --from-literal=ovh-storage-access-key=$OVH_STORAGE_ACCESS_KEY \
  --from-literal=ovh-storage-secret-key=$OVH_STORAGE_SECRET_KEY \
  --namespace=backend
```

### 3. Update Image Version

Edit `deployment.yaml` and update:
- `metadata.labels.version`
- `spec.template.metadata.labels.version`
- `spec.template.spec.containers[0].image`

### 4. Deploy

```bash
kubectl apply -f deployment.yaml
```

### 5. Verify

```bash
# Check pods
kubectl get pods -n backend -l app=candia-doc-builder

# Check service
kubectl get svc -n backend candia-doc-builder

# View logs
kubectl logs -f -n backend -l app=candia-doc-builder

# Check HPA
kubectl get hpa -n backend candia-doc-builder
```

## Update Deployment

```bash
# Update image version
kubectl set image deployment/candia-doc-builder \
  candia-doc-builder=ghcr.io/alex-elia/candia-doc-builder:v1.1.0 \
  -n backend

# Monitor rollout
kubectl rollout status deployment/candia-doc-builder -n backend

# Rollback if needed
kubectl rollout undo deployment/candia-doc-builder -n backend
```

## Scaling

The deployment includes a HorizontalPodAutoscaler (HPA) that automatically scales based on CPU and memory usage:
- Min replicas: 2
- Max replicas: 5
- CPU target: 70%
- Memory target: 80%

Manual scaling:
```bash
kubectl scale deployment/candia-doc-builder --replicas=3 -n backend
```



