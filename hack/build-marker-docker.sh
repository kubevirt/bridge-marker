#!/usr/bin/env bash

if [ -z "$ARCH" ] || [ -z "$PLATFORMS" ] || [ -z "$MARKER_IMAGE_TAGGED" ] || [ -z "$MARKER_IMAGE_GIT_TAGGED" ]; then
    echo "Error: ARCH, PLATFORMS, MARKER_IMAGE_TAGGED, and MARKER_IMAGE_GIT_TAGGED must be set."
    exit 1
fi

IFS=',' read -r -a PLATFORM_LIST <<< "$PLATFORMS"

BUILD_ARGS="--build-arg BUILD_ARCH=$ARCH -f build/Dockerfile -t $MARKER_IMAGE_TAGGED -t $MARKER_IMAGE_GIT_TAGGED . --push"

if [ ${#PLATFORM_LIST[@]} -eq 1 ]; then
    docker build --platform "$PLATFORMS" $BUILD_ARGS
else
    ./hack/init-buildx.sh "$DOCKER_BUILDER"
    docker buildx build --platform "$PLATFORMS" $BUILD_ARGS
    docker buildx rm "$DOCKER_BUILDER" 2>/dev/null || echo "Builder ${DOCKER_BUILDER} not found or already removed, skipping."
fi
