# Understanding Nodes vs Instances in OVH Kubernetes

## Quick Answer

**Yes! 2 nodes = 2 running b3-8 instances**

Each Kubernetes node is a separate compute instance that you pay for.

## Your Current Setup

### Kubernetes Cluster
- **2 worker nodes** = **2 × b3-8 instances**
- Each b3-8: 2 vCPUs, 8 GB RAM
- Cost: 2 × €0.05/hour = **€0.10/hour ≈ €73/month**

### Instance Details

| Node Name | Instance Type | IP Address | Status |
|-----------|--------------|------------|--------|
| pool1-node-024973 | b3-8 | 51.91.145.145 | ✅ Running |
| pool1-node-a1d1ab | b3-8 | 51.91.146.211 | ✅ Running |

## Cost Breakdown

### Current Monthly Cost (2 nodes)
```
2 nodes × b3-8 × €0.05/hour × 730 hours/month = €73/month
```

### With Autoscaling (2-10 nodes)
```
Minimum (always): 2 nodes = €73/month
Maximum (if needed): 10 nodes = €365/month
Average (depends on usage): Variable
```

## How Cluster Autoscaler Works

### Scenario 1: Low Traffic (2 nodes)
- You deploy 3 apps
- All fit on 2 nodes
- **Cost**: €73/month

### Scenario 2: Medium Traffic (4 nodes)
- You deploy 10 apps
- Cluster Autoscaler adds 2 more nodes
- Now running 4 nodes
- **Cost**: €146/month (4 × €0.05 × 730)

### Scenario 3: High Traffic (6 nodes)
- Traffic spikes, apps scale to 5 replicas each
- Cluster Autoscaler adds 4 more nodes
- Now running 6 nodes
- **Cost**: €219/month (6 × €0.05 × 730)

### Scenario 4: Traffic Drops (back to 2 nodes)
- Traffic decreases
- Cluster Autoscaler removes unused nodes after 10 minutes
- Back to 2 nodes
- **Cost**: €73/month

## Important Notes

1. **Each node = One billable instance**
   - When you see "2 nodes", you're paying for 2 instances
   - When autoscaler adds a node, you're paying for another instance

2. **Control plane is free**
   - The Kubernetes control plane (master) is managed by OVH
   - You don't pay for it or see it as an instance

3. **Node pool = Group of nodes**
   - Your "pool1" contains your 2 b3-8 nodes
   - All nodes in a pool have the same instance type (b3-8)

4. **Autoscaling adds/removes instances**
   - When autoscaler adds a node, it creates a new b3-8 instance
   - When it removes a node, it deletes that instance
   - You only pay for instances while they exist

## Verification Commands

### Check your nodes
```bash
kubectl get nodes -o wide
```

### Check node details
```bash
kubectl describe nodes
```

### Check current cost (OVH Console)
- Go to: OVH Manager → Public Cloud → Billing
- Filter by: Kubernetes nodes or instance type b3-8

## Cost Optimization Tips

1. **Set appropriate min/max nodes**
   - Min: 2 (for availability)
   - Max: 10 (for capacity, adjust based on needs)

2. **Monitor actual usage**
   - Check how many nodes you actually use
   - Adjust max nodes if you never reach it

3. **Consider reserved instances**
   - If you always need 2 nodes, reserved instances might be cheaper
   - Check OVH pricing for reserved vs on-demand

4. **Use smaller instances for dev/test**
   - Consider separate node pool with smaller instances for non-production
   - Use node selectors to route workloads appropriately




