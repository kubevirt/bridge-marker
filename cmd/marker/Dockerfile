FROM golang:1.10 AS builder
ENV GOPATH=/go
WORKDIR /go/src/github.com/kubevirt/bridge-marker/
COPY . .
RUN hack/version.sh > ./cmd/marker/.version
WORKDIR /go/src/github.com/kubevirt/bridge-marker/cmd/marker
RUN go build

FROM centos:centos7
RUN yum update -y && yum install iproute bridge-utils -y && yum clean all
COPY --from=builder /go/src/github.com/kubevirt/bridge-marker/cmd/marker/marker /marker
COPY --from=builder /go/src/github.com/kubevirt/bridge-marker/cmd/marker/.version /.version
COPY --from=builder /go/src/github.com/kubevirt/bridge-marker/cmd/marker/bridge-marker-gather /bridge-marker-gather
ENTRYPOINT [ "/marker"]
LABEL diagnostics="/bridge-marker-gather"

