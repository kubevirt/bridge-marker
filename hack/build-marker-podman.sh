#!/usr/bin/env bash

if [ -z "$ARCH" ] || [ -z "$PLATFORMS" ] || [ -z "$MARKER_IMAGE_TAGGED" ]; then
    echo "Error: ARCH, PLATFORMS, and MARKER_IMAGE_TAGGED must be set."
    exit 1
fi

IFS=',' read -r -a PLATFORM_LIST <<< "$PLATFORMS"

podman manifest rm "${MARKER_IMAGE_TAGGED}" 2>/dev/null || true
podman manifest rm "${MARKER_IMAGE_GIT_TAGGED}" 2>/dev/null || true
podman rmi "${MARKER_IMAGE_TAGGED}" 2>/dev/null || true
podman rmi "${MARKER_IMAGE_GIT_TAGGED}" 2>/dev/null || true

podman manifest create "${MARKER_IMAGE_TAGGED}"

for platform in "${PLATFORM_LIST[@]}"; do
    podman build \
        --build-arg BUILD_ARCH="$ARCH" \
        --platform "$platform" \
        --manifest "${MARKER_IMAGE_TAGGED}" \
        -f build/Dockerfile .
done
