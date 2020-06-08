FROM registry.access.redhat.com/ubi8/ubi-minimal
COPY _output/bin/marker /marker
COPY _output/bin/.version /.version
ENTRYPOINT [ "/marker"]
