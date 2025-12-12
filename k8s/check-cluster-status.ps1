# PowerShell script to check OVH Kubernetes cluster status and resource usage

Write-Host "=== KUBERNETES CLUSTER STATUS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. CLUSTER NODES:" -ForegroundColor Yellow
Write-Host "-----------------" -ForegroundColor Yellow
kubectl get nodes -o wide
Write-Host ""

Write-Host "2. NODE RESOURCES:" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow
$metrics = kubectl top nodes 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Metrics server not available. Install with:" -ForegroundColor Red
    Write-Host "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml" -ForegroundColor Yellow
} else {
    Write-Host $metrics
}
Write-Host ""

Write-Host "3. ALL PODS (ALL NAMESPACES):" -ForegroundColor Yellow
Write-Host "-----------------------------" -ForegroundColor Yellow
kubectl get pods --all-namespaces -o wide
Write-Host ""

Write-Host "4. DEPLOYMENTS (ALL NAMESPACES):" -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow
kubectl get deployments --all-namespaces
Write-Host ""

Write-Host "5. RESOURCE USAGE BY NAMESPACE:" -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Yellow
$podMetrics = kubectl top pods --all-namespaces 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Metrics server not available" -ForegroundColor Red
} else {
    Write-Host $podMetrics
}
Write-Host ""

Write-Host "6. NODE CAPACITY vs ALLOCATABLE:" -ForegroundColor Yellow
Write-Host "---------------------------------" -ForegroundColor Yellow
kubectl describe nodes | Select-String -Pattern "Capacity:|Allocatable:" -Context 0,5
Write-Host ""

Write-Host "7. RESOURCE QUOTAS:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
kubectl get resourcequotas --all-namespaces
Write-Host ""

Write-Host "8. PERSISTENT VOLUMES:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow
kubectl get pv
Write-Host ""

Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$nodeCount = (kubectl get nodes --no-headers 2>$null | Measure-Object -Line).Lines
$podCount = (kubectl get pods --all-namespaces --no-headers 2>$null | Measure-Object -Line).Lines
$deploymentCount = (kubectl get deployments --all-namespaces --no-headers 2>$null | Measure-Object -Line).Lines

Write-Host "Total nodes: $nodeCount" -ForegroundColor Green
Write-Host "Total pods: $podCount" -ForegroundColor Green
Write-Host "Total deployments: $deploymentCount" -ForegroundColor Green
Write-Host ""

Write-Host "=== INSTANCE STATUS CHECK ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To check your non-Kubernetes instances:" -ForegroundColor Yellow
Write-Host "  b2-7-sbg5 (Docker): 57.128.111.134" -ForegroundColor White
Write-Host "  d2-2-sbg5-work: 51.91.150.231" -ForegroundColor White
Write-Host ""
Write-Host "Kubernetes nodes:" -ForegroundColor Yellow
Write-Host "  pool1-node-024973: 51.91.145.145" -ForegroundColor White
Write-Host "  pool1-node-a1d1ab: 51.91.146.211" -ForegroundColor White








