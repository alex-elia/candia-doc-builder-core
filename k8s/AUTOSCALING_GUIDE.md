# Kubernetes Autoscaling Guide for OVH

## Two Types of Autoscaling

### 1. **Horizontal Pod Autoscaler (HPA)** ✅ Already Configured
- **What it does**: Scales the number of **pods** (containers) for each application
- **Current setup**: Your `candia-doc-builder` already has HPA configured
- **Limitation**: Can only scale pods within existing node capacity

### 2. **Cluster Autoscaler** (Node Pool Autoscaling) 🎯 What You Need
- **What it does**: Automatically adds/removes **nodes** to your cluster
- **Benefit**: Guarantees capacity for multiple applications
- **How it works**: When pods can't be scheduled (no resources), it adds nodes

## Current Setup Analysis

### Your Current HPA Configuration
```yaml
minReplicas: 2
maxReplicas: 5
CPU target: 70%
Memory target: 80%
```

**This is good!** But it's limited by your 2 nodes (4 vCPUs total).

### The Problem
- With 2 nodes: ~3.86 vCPUs available
- Each app needs: 0.5 vCPU minimum (2 replicas × 250m)
- **Maximum**: ~7 apps (if all at minimum)
- **Under load**: If apps scale to 5 replicas each, you can only run ~1-2 apps

## Solution: Enable Cluster Autoscaler

### Option 1: OVH Console Configuration (Recommended)

1. **Go to OVH Manager** → Kubernetes → Your Cluster
2. **Node Pools** → Select your node pool (`pool1`)
3. **Enable Autoscaling**:
   - **Min nodes**: 2 (your current nodes)
   - **Max nodes**: 5-10 (depending on your needs)
   - **Instance type**: b3-8 (or larger if needed)

### Option 2: OVH CLI / API

If you have OVH CLI configured:

```bash
# List your node pools
ovh cloud project kube nodePool list --serviceName <your-project-id> --kubeId <your-cluster-id>

# Update node pool with autoscaling
ovh cloud project kube nodePool update \
  --serviceName <your-project-id> \
  --kubeId <your-cluster-id> \
  --name pool1 \
  --autoscale \
  --minNodes 2 \
  --maxNodes 10 \
  --flavor b3-8
```

### Option 3: Terraform (If Using IaC)

```hcl
resource "ovh_cloud_project_kube_nodepool" "pool1" {
  service_name  = var.ovh_project_id
  kube_id       = ovh_cloud_project_kube.cluster.id
  name          = "pool1"
  flavor_name   = "b3-8"
  autoscale     = true
  min_nodes     = 2
  max_nodes     = 10
  region        = "SBG5"
}
```

## Recommended Autoscaling Configuration

### For Running Multiple Applications

```yaml
Node Pool Autoscaling:
  Min nodes: 2        # Always have 2 nodes (current setup)
  Max nodes: 10       # Can scale up to 10 nodes if needed
  Instance type: b3-8  # 2 vCPU, 8 GB RAM per node
  
Per Application HPA:
  Min replicas: 2     # Always have 2 pods for availability
  Max replicas: 5     # Scale up to 5 pods under load
```

### Capacity Calculation

**With autoscaling enabled (2-10 nodes):**
- **Minimum capacity**: 2 nodes = ~3.86 vCPUs = ~7 apps
- **Maximum capacity**: 10 nodes = ~19.3 vCPUs = ~38 apps
- **Cost**: Only pay for nodes when they're running

**Example scenario:**
- Start with 2 nodes (€73/month)
- Deploy 5 apps → Still fits on 2 nodes
- Deploy 10 apps → Cluster Autoscaler adds 2 more nodes (now 4 nodes)
- Traffic spikes → HPA scales pods, Cluster Autoscaler adds more nodes if needed
- Traffic drops → Cluster Autoscaler removes unused nodes

## Cost Optimization with Autoscaling

### Without Autoscaling
- **Fixed cost**: 2 nodes × €0.05/hour = €0.10/hour = **€73/month**
- **Capacity**: Limited to ~7 apps
- **Problem**: Can't handle more apps or traffic spikes

### With Autoscaling (2-10 nodes)
- **Base cost**: 2 nodes = **€73/month** (minimum)
- **Scale-up cost**: Additional nodes only when needed
- **Example**: 4 nodes for 1 week = €73 + (2 nodes × €0.05 × 168 hours) = **€90/month**
- **Benefit**: Can handle 20+ apps when needed, pay only for what you use

## Verification Steps

### 1. Check if Autoscaling is Enabled

```bash
# Check node pool configuration
kubectl get nodes -o wide

# Check if Cluster Autoscaler is running
kubectl get pods -n kube-system | grep autoscaler

# Check node pool details (OVH specific)
# This might require OVH CLI or checking OVH console
```

### 2. Test Autoscaling

```bash
# Create a test deployment that requests more resources than available
kubectl apply -f test-autoscaling.yaml

# Watch nodes being added
watch kubectl get nodes

# Watch pods being scheduled
watch kubectl get pods -o wide
```

### 3. Monitor Autoscaling

```bash
# Watch node count
watch kubectl get nodes

# Watch resource usage
watch kubectl top nodes

# Check Cluster Autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

## Best Practices

### 1. Set Appropriate Resource Requests
✅ **Do**: Set realistic resource requests (you already do this)
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
```

❌ **Don't**: Set requests too high (wastes resources) or too low (causes scheduling issues)

### 2. Use Pod Disruption Budgets (PDB)
Protect your applications during node scaling:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: candia-doc-builder-pdb
  namespace: backend
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: candia-doc-builder
```

### 3. Set Node Affinity (Optional)
If you want certain apps on certain node types:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: In
            values:
            - b3-8
```

### 4. Monitor Costs
- Set up OVH billing alerts
- Review node usage weekly
- Consider reserved instances for base capacity if running 24/7

## Troubleshooting

### Autoscaling Not Working?

1. **Check Cluster Autoscaler is installed**:
   ```bash
   kubectl get pods -n kube-system | grep autoscaler
   ```

2. **Check node pool configuration in OVH console**

3. **Check for pending pods**:
   ```bash
   kubectl get pods --all-namespaces --field-selector=status.phase=Pending
   ```

4. **Check Cluster Autoscaler logs**:
   ```bash
   kubectl logs -n kube-system -l app=cluster-autoscaler --tail=100
   ```

### Nodes Not Scaling Down?

- Cluster Autoscaler waits 10 minutes before scaling down
- It won't remove nodes if pods can't be rescheduled elsewhere
- Check for pod disruption budgets or node selectors preventing movement

## Next Steps

1. ✅ **Enable Cluster Autoscaler** in OVH console (2-10 nodes)
2. ✅ **Verify** it's working with test deployment
3. ✅ **Monitor** costs and usage for first week
4. ✅ **Adjust** min/max nodes based on actual usage
5. ✅ **Add Pod Disruption Budgets** for production apps

## Example: Running 10 Applications

**Scenario**: You want to run 10 applications for clients

**Configuration**:
- Node pool: 2-10 nodes (b3-8)
- Each app: 2-5 replicas, 250m CPU request per pod

**Capacity**:
- 10 apps × 2 replicas = 20 pods
- 20 pods × 250m = 5 vCPUs needed
- **Requires**: 3 nodes minimum (3 × 1.93 = 5.79 vCPUs)
- **Cost**: ~€110/month (3 nodes × €0.05 × 730 hours)

**With traffic spikes**:
- Apps scale to 5 replicas = 50 pods = 12.5 vCPUs
- **Requires**: 7 nodes
- **Cost**: ~€255/month (temporary, only during spikes)








