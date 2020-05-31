FROM golang:1.13 AS builder
ENV GOPATH=/go
ENV GOFLAGS=-mod=vendor
ENV GO111MODULE=on
WORKDIR /go/src/github.com/kubevirt/bridge-marker/
COPY . .
RUN hack/version.sh > ./cmd/marker/.version
WORKDIR /go/src/github.com/kubevirt/bridge-marker/cmd/marker
RUN go build

FROM centos:centos7
COPY --from=builder /go/src/github.com/kubevirt/bridge-marker/cmd/marker/marker /marker
COPY --from=builder /go/src/github.com/kubevirt/bridge-marker/cmd/marker/.version /.version
ENTRYPOINT [ "/marker"]
