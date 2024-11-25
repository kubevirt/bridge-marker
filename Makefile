REGISTRY ?= quay.io/kubevirt
IMAGE_TAG ?= latest
IMAGE_GIT_TAG ?= $(shell git describe --abbrev=8 --tags)
PLATFORM_LIST ?= linux/amd64,linux/s390x,linux/arm64
ARCH := $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
PLATFORMS ?= linux/${ARCH}
PLATFORMS := $(if $(filter all,$(PLATFORMS)),$(PLATFORM_LIST),$(PLATFORMS))
# Set the platforms for building a multi-platform supported image.
# Example:
# PLATFORMS ?= linux/amd64,linux/arm64,linux/s390x
# Alternatively, you can export the PLATFORMS variable like this:
# export PLATFORMS=linux/arm64,linux/s390x,linux/amd64
# or export PLATFORMS=all to automatically include all supported platforms.
DOCKER_BUILDER ?= marker-docker-builder
MARKER_IMAGE_TAGGED := ${REGISTRY}/bridge-marker:${IMAGE_TAG}
MARKER_IMAGE_GIT_TAGGED := ${REGISTRY}/bridge-marker:${IMAGE_GIT_TAG}

BIN_DIR = $(CURDIR)/build/_output/bin/
export GOPROXY=direct
export GOFLAGS=-mod=vendor
export GOROOT=$(BIN_DIR)/go/
export GOBIN=$(GOROOT)/bin/
export PATH := $(GOROOT)/bin:$(PATH)
export GO := $(GOBIN)/go
OCI_BIN ?= $(shell if hash podman 2>/dev/null; then echo podman; elif hash docker 2>/dev/null; then echo docker; fi)
TLS_SETTING := $(if $(filter $(OCI_BIN),podman),"--tls-verify=false",)

GINKGO ?= $(GOBIN)/ginkgo

COMPONENTS = $(sort \
			 $(subst /,-,\
			 $(patsubst cmd/%/,%,\
			 $(dir \
			 $(shell find cmd/ -type f -name '*.go')))))

all: build

$(GO):
	hack/install-go.sh $(BIN_DIR)

$(GINKGO): go.mod
	$(MAKE) tools

build: marker manifests format

format: $(GO)
	$(GO) fmt ./pkg/... ./cmd/... ./tests/...
	$(GO) vet ./pkg/... ./cmd/... ./tests/...

functest: $(GINKGO)
	GINKGO=$(GINKGO) hack/build-func-tests.sh
	GINKGO=$(GINKGO) hack/functests.sh

marker: $(GO)
	hack/version.sh > $(BIN_DIR)/.version

docker-build: marker
ifeq ($(OCI_BIN),podman)
	$(MAKE) build-multiarch-marker-podman
else ifeq ($(OCI_BIN),docker)
	$(MAKE) build-multiarch-marker-docker
else
	$(error Unsupported OCI_BIN value: $(OCI_BIN))
endif

docker-push:
ifeq ($(OCI_BIN),podman)
	podman manifest push ${TLS_SETTING} ${MARKER_IMAGE_TAGGED} ${MARKER_IMAGE_TAGGED}
	podman tag ${MARKER_IMAGE_TAGGED} ${MARKER_IMAGE_GIT_TAGGED}
	podman manifest push ${TLS_SETTING} ${MARKER_IMAGE_GIT_TAGGED} ${MARKER_IMAGE_GIT_TAGGED}
endif

manifests:
	./hack/build-manifests.sh

cluster-up:
	./cluster/up.sh

cluster-down:
	./cluster/down.sh

cluster-sync: build
	./cluster/sync.sh

vendor: $(GO)
	$(GO) mod tidy
	$(GO) mod vendor

tools: $(GO)
	./hack/install-tools.sh

build-multiarch-marker-docker:
	ARCH=$(ARCH) PLATFORMS=$(PLATFORMS) MARKER_IMAGE_TAGGED=$(MARKER_IMAGE_TAGGED) MARKER_IMAGE_GIT_TAGGED=$(MARKER_IMAGE_GIT_TAGGED) DOCKER_BUILDER=$(DOCKER_BUILDER) ./hack/build-marker-docker.sh

build-multiarch-marker-podman:
	ARCH=$(ARCH) PLATFORMS=$(PLATFORMS) MARKER_IMAGE_TAGGED=$(MARKER_IMAGE_TAGGED) MARKER_IMAGE_GIT_TAGGED=$(MARKER_IMAGE_GIT_TAGGED) ./hack/build-marker-podman.sh

.PHONY: \
	build \
	build-multiarch-marker-docker \
	build-multiarch-marker-podman \
	format \
	docker-build \
	docker-push \
	manifests \
	cluster-up \
	cluster-down \
	cluster-sync \
	vendor \
	marker \
	tools
