# PowerShell script to check autoscaling status on OVH Kubernetes

Write-Host "=== AUTOSCALING STATUS CHECK ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. CLUSTER NODES:" -ForegroundColor Yellow
Write-Host "-----------------" -ForegroundColor Yellow
kubectl get nodes -o wide
$nodeCount = (kubectl get nodes --no-headers 2>$null | Measure-Object -Line).Lines
Write-Host "Current node count: $nodeCount" -ForegroundColor Green
Write-Host ""

Write-Host "2. CLUSTER AUTOSCALER STATUS:" -ForegroundColor Yellow
Write-Host "-----------------------------" -ForegroundColor Yellow
$autoscaler = kubectl get pods -n kube-system -l app=cluster-autoscaler 2>&1
if ($LASTEXITCODE -eq 0 -and $autoscaler -match "cluster-autoscaler") {
    Write-Host "✅ Cluster Autoscaler is running" -ForegroundColor Green
    kubectl get pods -n kube-system -l app=cluster-autoscaler
} else {
    Write-Host "❌ Cluster Autoscaler not found" -ForegroundColor Red
    Write-Host "   Enable it in OVH Console: Kubernetes → Node Pools → Enable Autoscaling" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "3. HORIZONTAL POD AUTOSCALERS:" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
kubectl get hpa --all-namespaces
Write-Host ""

Write-Host "4. PENDING PODS (May trigger autoscaling):" -ForegroundColor Yellow
Write-Host "------------------------------------------" -ForegroundColor Yellow
$pendingPods = kubectl get pods --all-namespaces --field-selector=status.phase=Pending 2>&1
if ($pendingPods -match "No resources found") {
    Write-Host "✅ No pending pods" -ForegroundColor Green
} else {
    Write-Host "⚠️  Pending pods found (may need more nodes):" -ForegroundColor Yellow
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending
}
Write-Host ""

Write-Host "5. RESOURCE USAGE:" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow
$nodeMetrics = kubectl top nodes 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host $nodeMetrics
} else {
    Write-Host "Metrics server not available. Install with:" -ForegroundColor Red
    Write-Host "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "6. POD DISRUPTION BUDGETS:" -ForegroundColor Yellow
Write-Host "--------------------------" -ForegroundColor Yellow
kubectl get pdb --all-namespaces
Write-Host ""

Write-Host "=== RECOMMENDATIONS ===" -ForegroundColor Cyan
Write-Host ""
if ($nodeCount -lt 3) {
    Write-Host "⚠️  You have $nodeCount nodes. For multiple applications, consider:" -ForegroundColor Yellow
    Write-Host "   - Enable Cluster Autoscaler (2-10 nodes recommended)" -ForegroundColor White
    Write-Host "   - This allows automatic scaling when you deploy more apps" -ForegroundColor White
} else {
    Write-Host "✅ You have $nodeCount nodes" -ForegroundColor Green
}

Write-Host ""
Write-Host "To enable Cluster Autoscaler:" -ForegroundColor Yellow
Write-Host "1. Go to OVH Manager → Kubernetes → Your Cluster" -ForegroundColor White
Write-Host "2. Node Pools → Select 'pool1'" -ForegroundColor White
Write-Host "3. Enable Autoscaling: Min=2, Max=10" -ForegroundColor White
Write-Host ""








