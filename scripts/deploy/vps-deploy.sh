#!/bin/bash
# VPS Deployment Script for Candia Doc Builder
# Usage: ./vps-deploy.sh [tag]

set -e

IMAGE_NAME="ghcr.io/alex-elia/candia-doc-builder"
TAG="${1:-staging-latest}"
CONTAINER_NAME="candia-doc-builder"
PORT="${PORT:-8000}"

echo "🚀 Deploying Candia Doc Builder to VPS"
echo "Image: ${IMAGE_NAME}:${TAG}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Login to GHCR (if not already logged in)
if ! docker info | grep -q "ghcr.io"; then
    echo "📦 Logging in to GitHub Container Registry..."
    echo "Please enter your GitHub Personal Access Token:"
    read -s GITHUB_TOKEN
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$(git config user.name)" --password-stdin
fi

# Pull latest image
echo "📥 Pulling image ${IMAGE_NAME}:${TAG}..."
docker pull "${IMAGE_NAME}:${TAG}"

# Stop and remove existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🛑 Stopping existing container..."
    docker stop "${CONTAINER_NAME}" || true
    docker rm "${CONTAINER_NAME}" || true
fi

# Check for environment file
ENV_FILE=".env.production"
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: $ENV_FILE not found. Using environment variables from current shell."
    echo "   Create $ENV_FILE with required environment variables."
fi

# Run new container
echo "🚀 Starting new container..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${PORT}:8000" \
    $(if [ -f "$ENV_FILE" ]; then echo "--env-file $ENV_FILE"; fi) \
    -e SUPABASE_URL="${SUPABASE_URL}" \
    -e SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}" \
    -e OVH_STORAGE_ENDPOINT="${OVH_STORAGE_ENDPOINT}" \
    -e OVH_STORAGE_ACCESS_KEY="${OVH_STORAGE_ACCESS_KEY}" \
    -e OVH_STORAGE_SECRET_KEY="${OVH_STORAGE_SECRET_KEY}" \
    "${IMAGE_NAME}:${TAG}"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Check container status
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "✅ Container started successfully!"
    echo ""
    echo "📊 Container status:"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "📋 View logs:"
    echo "   docker logs -f ${CONTAINER_NAME}"
    echo ""
    echo "🔍 Health check:"
    echo "   curl http://localhost:${PORT}/health"
else
    echo "❌ Container failed to start. Check logs:"
    echo "   docker logs ${CONTAINER_NAME}"
    exit 1
fi



