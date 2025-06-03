#!/bin/bash

# Optimized build script for production - AMD64 Linux only
# Maximum performance for DigitalOcean Ubuntu server

# Set variables
IMAGE_NAME="studenteplein/swot-ai-dev"
VERSION="${1:-latest}"
DOCKERFILE="Dockerfile.multi"
PLATFORM="linux/amd64"  # Fixed to AMD64 for optimal performance

echo "🚀 Building optimized production image: ${IMAGE_NAME}:${VERSION}"
echo "📁 Using Dockerfile: ${DOCKERFILE}"
echo "🏗️  Target platform: ${PLATFORM}"

# Enable BuildKit with optimizations
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain
export DOCKER_CLI_EXPERIMENTAL=enabled

# Memory and CPU optimizations for build
export BUILDKIT_STEP_LOG_MAX_SIZE=50000000
export BUILDKIT_STEP_LOG_MAX_SPEED=100000000

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "❌ Docker Buildx is not available. Please update Docker."
    exit 1
fi

# Create optimized builder for AMD64
BUILDER_NAME="amd64-builder"
if ! docker buildx ls | grep -q $BUILDER_NAME; then
    echo "🔧 Creating optimized AMD64 builder..."
    docker buildx create \
        --name $BUILDER_NAME \
        --driver docker-container \
        --driver-opt network=host \
        --driver-opt image=moby/buildkit:v0.12.5 \
        --use
    docker buildx inspect --bootstrap
else
    echo "✅ Using existing optimized builder..."
    docker buildx use $BUILDER_NAME
fi

# Prune build cache older than 48h to free space but keep recent cache
echo "🧹 Cleaning old build cache..."
docker buildx prune --filter until=48h --force

# Build with maximum optimizations - FORCE AMD64
echo "⚡ Building with maximum performance optimizations..."
docker buildx build \
  --file "${DOCKERFILE}" \
  --platform "${PLATFORM}" \
  --tag "${IMAGE_NAME}:${VERSION}" \
  --tag "${IMAGE_NAME}:latest" \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache-new,mode=max \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --build-arg TARGETPLATFORM=linux/amd64 \
  --build-arg BUILDPLATFORM=linux/amd64 \
  --target production \
  --load \
  --progress plain \
  .

# Move cache to avoid ever-growing cache
rm -rf /tmp/.buildx-cache
mv /tmp/.buildx-cache-new /tmp/.buildx-cache

# Check if build was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "📦 Image tagged as:"
    echo "  - ${IMAGE_NAME}:${VERSION}"
    echo "  - ${IMAGE_NAME}:latest"
    echo "🏗️  Platforms: ${PLATFORMS}"
    echo ""
    
    # Show image info
    docker images "${IMAGE_NAME}:${VERSION}" --format "📏 Image size: {{.Size}}"
    echo ""
    echo "💡 Tips:"
    echo "  - To build for AMD64 only: ./build-production.sh ${VERSION} linux/amd64"
    echo "  - To build for ARM64 only: ./build-production.sh ${VERSION} linux/arm64"
    echo "  - To push to registry: docker push ${IMAGE_NAME}:${VERSION}"
else
    echo "❌ Build failed!"
    exit 1
fi 