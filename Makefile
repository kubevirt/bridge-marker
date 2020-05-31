REGISTRY ?= quay.io/kubevirt
IMAGE_TAG ?= latest

COMPONENTS = $(sort \
			 $(subst /,-,\
			 $(patsubst cmd/%/,%,\
			 $(dir \
			 $(shell find cmd/ -type f -name '*.go')))))

export GOFLAGS=-mod=vendor
export GO111MODULE=on

all: build

build: manifests format
	hack/version.sh > ./cmd/marker/.version
	cd cmd/marker && go build

format:
	go fmt ./pkg/... ./cmd/... ./tests/...
	go vet ./pkg/... ./cmd/... ./tests/...

functest:
	hack/dockerized "hack/build-func-tests.sh"
	hack/functests.sh

docker-build: 
	docker build -f cmd/marker/Dockerfile -t ${REGISTRY}/bridge-marker:${IMAGE_TAG} .

docker-push:
	docker push ${REGISTRY}/bridge-marker:${IMAGE_TAG}

manifests:
	./hack/build-manifests.sh

cluster-up:
	./cluster/up.sh

cluster-down:
	./cluster/down.sh

cluster-sync: build
	./cluster/sync.sh

dep:
	go mod tidy
	go mod vendor

.PHONY: build format docker-build docker-push manifests cluster-up cluster-down cluster-sync dep
