# OVH Infrastructure Analysis

## Your Current Instances

### 1. **b2-7-sbg5** (12c5286d-8692-4ce5-ba54-fbdeaa26c82c)
- **Type**: b2-7 (2 vCPUs, 7 GB RAM)
- **OS**: Debian 12 - Docker (deprecated)
- **Status**: ✅ Activée
- **IP**: 57.128.111.134 (public), 10.22.0.90 (private)
- **Billing**: Monthly plan
- **⚠️ NOT part of Kubernetes cluster** - This is a standalone Docker host
- **Question**: Are you still using this? If not, you can delete it to save costs.

### 2. **d2-2-sbg5-work** (2a341148-737e-4c90-9cf9-9403563e9a16) ⏸️ PAUSED
- **Type**: d2-2 (2 vCPUs, 4 GB RAM) - "Discovery" instance (testing/development)
- **OS**: Ubuntu 24.04 (deprecated)
- **Status**: ⏸️ Paused (not consuming resources)
- **IP**: 51.91.150.231 (public), 10.22.0.64 (private)
- **Billing**: No cost while paused ✅
- **⚠️ NOT part of Kubernetes cluster** - This was a standalone VM for testing
- **❌ NOT the Kubernetes control plane** - OVH manages the control plane separately (not visible to you)
- **Action taken**: ✅ Paused (good cost-saving move!)

### 3. **pool1-node-024973** (881135a6-58e3-4e08-9458-87769cb5bcde)
- **Type**: b3-8 (2 vCPUs, 8 GB RAM)
- **OS**: Kubernetes node (standard-1.32.6)
- **Status**: ✅ Activée
- **IP**: 51.91.145.145 (public), 10.22.0.97 (private)
- **Billing**: Hourly consumption
- **✅ PART OF KUBERNETES CLUSTER** - This is a worker node

### 4. **pool1-node-a1d1ab** (1c9af95a-ab61-4a90-a168-2ce51a17078f)
- **Type**: b3-8 (2 vCPUs, 8 GB RAM)
- **OS**: Kubernetes node (standard-1.32.6)
- **Status**: ✅ Activée
- **IP**: 51.91.146.211 (public), 10.22.0.45 (private)
- **Billing**: Hourly consumption
- **✅ PART OF KUBERNETES CLUSTER** - This is a worker node

## Kubernetes Cluster Architecture

### Control Plane (Master)
- **✅ Fully managed by OVH** - Not visible as a customer instance
- You don't pay for or manage the control plane
- It's automatically provisioned and maintained by OVH

### Active Kubernetes Worker Nodes
- **2 × b3-8 nodes** (pool1-node-024973, pool1-node-a1d1ab)
- **Total resources**:
  - CPU: 4 vCPUs (2 per node)
  - RAM: 16 GB (8 GB per node)

### Available Resources (after Kubernetes overhead)
- **CPU**: ~3.86 vCPUs (1.93 per node)
- **RAM**: ~12.4 GB (6.2 GB per node)

### Application Capacity

Based on your `candia-doc-builder` deployment:
- **Per application**: 500m CPU, 512Mi RAM (minimum with 2 replicas)
- **Maximum applications**: **~7 applications** (CPU-limited: 3.86 / 0.5 = 7.72)

**Note**: With HPA scaling to 5 replicas max, each app could use up to 2.5 vCPU and 2.5 GB RAM under load.

## Cost Analysis

### Monthly Costs (estimated)
- **b2-7** (monthly): ~€15-20/month (fixed)
- **d2-2** (hourly): ~€0.03/hour = ~€22/month (if running 24/7)
- **b3-8** × 2 (hourly): ~€0.05/hour × 2 = ~€0.10/hour = ~€73/month (if running 24/7)

**Total estimated**: ~€73/month (b2-7 monthly + 2×b3-8 hourly)
**Note**: d2-2-sbg5-work is paused (no cost) ✅

## Recommendations

### 1. **Verify Usage of Non-Kubernetes Instances**

Check if `b2-7-sbg5` and `d2-2-sbg5-work` are still needed:

```bash
# SSH into b2-7-sbg5 and check running containers
ssh root@57.128.111.134
docker ps -a
docker stats

# SSH into d2-2-sbg5-work and check what's running
ssh root@51.91.150.231
ps aux
systemctl list-units --type=service --state=running
```

### 2. **Check Kubernetes Cluster Status**

Run the provided script:
```bash
chmod +x check-cluster-status.sh
./check-cluster-status.sh
```

Or manually:
```bash
# Check nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods --all-namespaces

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check deployments
kubectl get deployments --all-namespaces
```

### 3. **Optimize Costs**

**Option A: If b2-7-sbg5 is unused**
- Delete the instance to save ~€15-20/month
- Migrate any Docker containers to Kubernetes if needed

**Option B: If d2-2-sbg5-work is unused**
- Delete the instance to save ~€22/month
- Total savings: ~€37-42/month

**Option C: Consolidate to Kubernetes**
- Move all workloads to Kubernetes cluster
- Delete standalone instances
- Better resource utilization and management

### 4. **Monitor Actual Usage**

Install metrics server if not already installed:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Then monitor:
```bash
watch kubectl top nodes
watch kubectl top pods --all-namespaces
```

## Next Steps

1. ✅ **Verify** what's running on b2-7-sbg5 (d2-2-sbg5-work is paused ✅)
2. ✅ **Check** your Kubernetes cluster status
3. ✅ **Enable Cluster Autoscaler** to guarantee capacity for multiple apps (see `AUTOSCALING_GUIDE.md`)
4. ✅ **Monitor** resource usage to plan for scaling
5. ✅ **Consider** deleting b2-7-sbg5 if not needed (save ~€15-20/month)

## Questions to Answer

- [ ] Is `b2-7-sbg5` still hosting Docker containers? Which ones?
- [ ] What is `d2-2-sbg5-work` used for? (The name suggests a work/development instance)
- [ ] How many applications are currently deployed on your Kubernetes cluster?
- [ ] Are you planning to migrate everything to Kubernetes?

