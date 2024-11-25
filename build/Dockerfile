ARG BUILD_ARCH=amd64
FROM --platform=linux/${BUILD_ARCH} quay.io/centos/centos:stream9 AS builder
ARG TARGETOS
ARG TARGETARCH
ENV TARGETOS=${TARGETOS:-linux}
ENV TARGETARCH=${TARGETARCH:-amd64}

ARG BUILDOS
ARG BUILDARCH
ENV BUILDOS=${BUILDOS:-linux}
ENV BUILDARCH=${BUILDARCH:-amd64}

WORKDIR /go/src/bridge-marker
RUN dnf install -y wget && dnf clean all
COPY go.mod .
COPY go.sum .
RUN GO_VERSION=$(sed -En 's/^go +(.*)$/\1/p' go.mod) && \
    wget https://dl.google.com/go/go${GO_VERSION}.${BUILDOS}-${BUILDARCH}.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.${BUILDOS}-${BUILDARCH}.tar.gz && \
    rm go${GO_VERSION}.${BUILDOS}-${BUILDARCH}.tar.gz

ENV PATH=$PATH:/usr/local/go/bin
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o build/_output/bin/marker github.com/kubevirt/bridge-marker/cmd/marker

FROM --platform=linux/${TARGETARCH} registry.access.redhat.com/ubi8/ubi-minimal
COPY --from=builder /go/src/bridge-marker/build/_output/bin/marker /marker
COPY --from=builder /go/src/bridge-marker/build/_output/bin/.version /.version
ENTRYPOINT [ "/marker"]
