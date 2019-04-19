REGISTRY ?= quay.io/kubevirt
IMAGE_TAG ?= latest

COMPONENTS = $(sort \
			 $(subst /,-,\
			 $(patsubst cmd/%/,%,\
			 $(dir \
			 $(shell find cmd/ -type f -name '*.go')))))

all: build

build: manifests
	hack/version.sh > ./cmd/marker/.version
	cd cmd/marker && go fmt && go vet && go build

format:
	go fmt ./pkg/...
	go vet ./pkg/...

functest:
	hack/dockerized "hack/build-func-tests.sh"
	hack/functests.sh

docker-build: build
	docker build -t ${REGISTRY}/bridge-marker:${IMAGE_TAG} ./cmd/marker

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
	dep ensure

.PHONY: build format docker-build docker-push manifests cluster-up cluster-down cluster-sync dep
