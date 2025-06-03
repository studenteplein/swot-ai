#!/bin/bash

# Fast deployment to Docker Hub with multi-platform support

# Enable BuildKit for faster builds and better caching
export DOCKER_BUILDKIT=1

# Load environment
if [ -f ".env" ]; then
    source .env
fi

IMAGE_NAME="librechat"
TAG="${1:-latest}"
FULL_IMAGE="$DOCKER_HUB_USERNAME/$IMAGE_NAME:$TAG"

# Platform configuration - DEFAULT TO AMD64 ONLY
PLATFORMS="${2:-linux/amd64}"  # Default to AMD64 only for faster builds

echo "=== Docker Hub Deployment ==="
echo "Target: $FULL_IMAGE"
echo "Platform: $PLATFORMS"
echo "Using BuildKit: $DOCKER_BUILDKIT"
echo ""

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "❌ Docker Buildx is not available. Please update Docker."
    exit 1
fi

# Create/use buildx builder
BUILDER_NAME="multiplatform-builder"
if ! docker buildx ls | grep -q $BUILDER_NAME; then
    echo "Creating buildx builder..."
    docker buildx create --name $BUILDER_NAME --use
    docker buildx inspect --bootstrap
else
    echo "Using existing buildx builder..."
    docker buildx use $BUILDER_NAME
fi

# Change to parent directory for build context
cd ..

# Login to Docker Hub first (required for buildx push)
echo "Logging in to Docker Hub..."
if [ -n "$DOCKER_HUB_TOKEN" ]; then
    echo "$DOCKER_HUB_TOKEN" | docker login --username "$DOCKER_HUB_USERNAME" --password-stdin
else
    echo "Please login to Docker Hub:"
    docker login
fi

if [ $? -ne 0 ]; then
    echo "❌ Login failed"
    exit 1
fi

# Build and push multi-platform image in one step
echo "Building and pushing multi-platform image..."
docker buildx build \
  -f Dockerfile.multi \
  --platform $PLATFORMS \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --tag $FULL_IMAGE \
  --push \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully deployed multi-platform image to Docker Hub!"
    echo "📦 Image: $FULL_IMAGE"
    echo "🏗️  Platforms: $PLATFORMS"
    echo ""
    echo "Pull commands:"
    echo "  docker pull $FULL_IMAGE          # Auto-selects correct platform"
    echo "  docker pull --platform linux/amd64 $FULL_IMAGE  # Force AMD64"
    echo "  docker pull --platform linux/arm64 $FULL_IMAGE  # Force ARM64"
    echo ""
    echo "💡 Tips:"
    echo "  - The image will automatically use the correct platform when pulled"
    echo "  - To build for AMD64 only: ./deploy-docker.sh $TAG linux/amd64"
    echo "  - To build for ARM64 only: ./deploy-docker.sh $TAG linux/arm64"
else
    echo "❌ Build/push failed"
    exit 1
fi 