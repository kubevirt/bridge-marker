#!/bin/bash

set -xe

teardown() {
    make cluster-down
    cp $(find . -name "*junit*.xml") $ARTIFACTS || true
}

main() {

    export KUBEVIRT_PROVIDER=k8s-1.18
    source automation/check-patch.setup.sh
    cd ${TMP_PROJECT_PATH}


    # Let's fail fast if it's not compiling
    make docker-build

    make cluster-down
    make cluster-up
    trap teardown EXIT SIGINT SIGTERM SIGSTOP

    # Run cluster-sync to deploy bridge-marker on the nodes
    make cluster-sync

    ./cluster/kubectl.sh version

    if ! FUNC_TEST_ARGS="--ginkgo.noColor" make functest; then
        ./cluster/kubectl.sh logs -n kube-system -l app=bridge-marker
        return 1
    fi
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
