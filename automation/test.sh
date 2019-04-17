#!/bin/bash
#
# This file is part of the KubeVirt project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright 2018 Red Hat, Inc.
#

# CI considerations: $TARGET is used by the jenkins build, to distinguish what to test
# Currently considered $TARGET values:
#     kubernetes-release: Runs all functional tests on a release kubernetes setup
#     openshift-release: Runs all functional tests on a release openshift setup

set -ex

export WORKSPACE="${WORKSPACE:-$PWD}"
readonly ARTIFACTS_PATH="$WORKSPACE/exported-artifacts"

if [[ $TARGET =~ openshift-.* ]]; then
  export KUBEVIRT_PROVIDER="os-3.11.0-multus"
else
  export KUBEVIRT_PROVIDER="k8s-multus-1.12.2"
fi

kubectl() { cluster/kubectl.sh "$@"; }

# Make sure that the VM is properly shut down on exit
trap '{ make cluster-down; }' EXIT SIGINT SIGTERM SIGSTOP

make cluster-down
make cluster-up

# Run cluster-sync to deploy bridge-marker on the nodes
make cluster-sync

# Wait for daemon set to be scheduled on all nodes
timeout=300
sample=30
current_time=0
while true; do
  describe_result=$(kubectl describe  daemonset bridge-marker -n kube-system)
  desired_nodes=$(echo "$describe_result" | grep "Desired Number of Nodes Scheduled"| awk -F ':'  '{print $2}')
  current_nodes=$(echo "$describe_result" | grep "Number of Nodes Scheduled with Up-to-date Pods"| awk -F ':'  '{print $2}')
  if [ $desired_nodes -eq $current_nodes ]; then
      break
  fi
  current_time=$((current_time + sample))
  if [ $current_time -gt $timeout ]; then
    exit 1
  fi
done 

kubectl version

mkdir -p "$ARTIFACTS_PATH"
ginko_params="--ginkgo.noColor --junit-output=$ARTIFACTS_PATH/tests.junit.xml"
# Run functional tests
FUNC_TEST_ARGS=$ginko_params make functest
