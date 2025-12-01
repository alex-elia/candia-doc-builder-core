# VPS Deployment Script for Candia Doc Builder (PowerShell)
# Usage: .\vps-deploy.ps1 [-Tag "staging-latest"]

param(
    [string]$Tag = "staging-latest"
)

$ErrorActionPreference = "Stop"

$ImageName = "ghcr.io/alex-elia/candia-doc-builder"
$ContainerName = "candia-doc-builder"
$Port = if ($env:PORT) { $env:PORT } else { "8000" }

Write-Host "🚀 Deploying Candia Doc Builder to VPS" -ForegroundColor Cyan
Write-Host "Image: ${ImageName}:${Tag}" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is not installed. Please install Docker first." -ForegroundColor Red
    exit 1
}

# Login to GHCR (if not already logged in)
$ghcrLoggedIn = docker info 2>&1 | Select-String "ghcr.io"
if (-not $ghcrLoggedIn) {
    Write-Host "📦 Logging in to GitHub Container Registry..." -ForegroundColor Yellow
    $githubToken = Read-Host "Please enter your GitHub Personal Access Token" -AsSecureString
    $githubTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($githubToken)
    )
    $githubTokenPlain | docker login ghcr.io -u (git config user.name) --password-stdin
}

# Pull latest image
Write-Host "📥 Pulling image ${ImageName}:${Tag}..." -ForegroundColor Yellow
docker pull "${ImageName}:${Tag}"

# Stop and remove existing container
$existingContainer = docker ps -a --format '{{.Names}}' | Select-String "^${ContainerName}$"
if ($existingContainer) {
    Write-Host "🛑 Stopping existing container..." -ForegroundColor Yellow
    docker stop $ContainerName 2>&1 | Out-Null
    docker rm $ContainerName 2>&1 | Out-Null
}

# Check for environment file
$envFile = ".env.production"
$useEnvFile = Test-Path $envFile
if (-not $useEnvFile) {
    Write-Host "⚠️  Warning: $envFile not found. Using environment variables from current shell." -ForegroundColor Yellow
    Write-Host "   Create $envFile with required environment variables." -ForegroundColor Yellow
}

# Build docker run command
$dockerArgs = @(
    "run", "-d",
    "--name", $ContainerName,
    "--restart", "unless-stopped",
    "-p", "${Port}:8000"
)

if ($useEnvFile) {
    $dockerArgs += "--env-file", $envFile
}

# Add environment variables if set
if ($env:SUPABASE_URL) {
    $dockerArgs += "-e", "SUPABASE_URL=$env:SUPABASE_URL"
}
if ($env:SUPABASE_SERVICE_ROLE_KEY) {
    $dockerArgs += "-e", "SUPABASE_SERVICE_ROLE_KEY=$env:SUPABASE_SERVICE_ROLE_KEY"
}
if ($env:OVH_STORAGE_ENDPOINT) {
    $dockerArgs += "-e", "OVH_STORAGE_ENDPOINT=$env:OVH_STORAGE_ENDPOINT"
}
if ($env:OVH_STORAGE_ACCESS_KEY) {
    $dockerArgs += "-e", "OVH_STORAGE_ACCESS_KEY=$env:OVH_STORAGE_ACCESS_KEY"
}
if ($env:OVH_STORAGE_SECRET_KEY) {
    $dockerArgs += "-e", "OVH_STORAGE_SECRET_KEY=$env:OVH_STORAGE_SECRET_KEY"
}

$dockerArgs += "${ImageName}:${Tag}"

# Run new container
Write-Host "🚀 Starting new container..." -ForegroundColor Yellow
& docker $dockerArgs

# Wait for container to start
Write-Host "⏳ Waiting for container to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Check container status
$containerRunning = docker ps --format '{{.Names}}' | Select-String "^${ContainerName}$"
if ($containerRunning) {
    Write-Host "✅ Container started successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Container status:" -ForegroundColor Cyan
    docker ps --filter "name=${ContainerName}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Write-Host ""
    Write-Host "📋 View logs:" -ForegroundColor Cyan
    Write-Host "   docker logs -f ${ContainerName}" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔍 Health check:" -ForegroundColor Cyan
    Write-Host "   curl http://localhost:${Port}/health" -ForegroundColor Gray
} else {
    Write-Host "❌ Container failed to start. Check logs:" -ForegroundColor Red
    Write-Host "   docker logs ${ContainerName}" -ForegroundColor Gray
    exit 1
}



