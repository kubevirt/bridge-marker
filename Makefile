REGISTRY ?= quay.io/kubevirt
IMAGE_TAG ?= latest
IMAGE_GIT_TAG ?= $(shell git describe --abbrev=8 --tags)

BIN_DIR = $(CURDIR)/build/_output/bin/
export GOPROXY=direct
export GOSUMDB=off
export GOFLAGS=-mod=vendor
export GOROOT=$(BIN_DIR)/go/
export GOBIN=$(GOROOT)/bin/
export PATH := $(GOROOT)/bin:$(PATH)
export GO := $(GOBIN)/go

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
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build -o $(BIN_DIR)/marker github.com/kubevirt/bridge-marker/cmd/marker

docker-build: marker
	docker build -t ${REGISTRY}/bridge-marker:${IMAGE_TAG} ./build

docker-push:
	docker push ${REGISTRY}/bridge-marker:${IMAGE_TAG}
	docker tag ${REGISTRY}/bridge-marker:${IMAGE_TAG} ${REGISTRY}/bridge-marker:${IMAGE_GIT_TAG}
	docker push ${REGISTRY}/bridge-marker:${IMAGE_GIT_TAG}

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

.PHONY: build format docker-build docker-push manifests cluster-up cluster-down cluster-sync vendor marker tools
