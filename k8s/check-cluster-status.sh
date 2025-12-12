#!/bin/bash
# Script to check OVH Kubernetes cluster status and resource usage

echo "=== KUBERNETES CLUSTER STATUS ==="
echo ""

echo "1. CLUSTER NODES:"
echo "-----------------"
kubectl get nodes -o wide
echo ""

echo "2. NODE RESOURCES:"
echo "------------------"
kubectl top nodes 2>/dev/null || echo "Metrics server not available. Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
echo ""

echo "3. ALL PODS (ALL NAMESPACES):"
echo "-----------------------------"
kubectl get pods --all-namespaces -o wide
echo ""

echo "4. DEPLOYMENTS (ALL NAMESPACES):"
echo "--------------------------------"
kubectl get deployments --all-namespaces
echo ""

echo "5. RESOURCE USAGE BY NAMESPACE:"
echo "-------------------------------"
kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics server not available"
echo ""

echo "6. NODE CAPACITY vs ALLOCATABLE:"
echo "---------------------------------"
kubectl describe nodes | grep -A 5 "Capacity:\|Allocatable:"
echo ""

echo "7. RESOURCE QUOTAS:"
echo "-------------------"
kubectl get resourcequotas --all-namespaces
echo ""

echo "8. PERSISTENT VOLUMES:"
echo "----------------------"
kubectl get pv
echo ""

echo "=== SUMMARY ==="
echo "Total nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Total pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
echo "Total deployments: $(kubectl get deployments --all-namespaces --no-headers | wc -l)"








