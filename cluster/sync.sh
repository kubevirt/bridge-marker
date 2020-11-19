#!/bin/bash
#
# Copyright 2018-2019 Red Hat, Inc.
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

set -ex

source ./cluster/cluster.sh
cluster::install

if [[ "$KUBEVIRT_PROVIDER" == external ]]; then
    if [[ ! -v DEV_REGISTRY ]]; then
        echo "Missing DEV_REGISTRY variable"
        exit 1
    fi
    push_registry=$DEV_REGISTRY
    manifest_registry=$DEV_REGISTRY
    config_dir=./config/external
else
    registry_port=$(./cluster/cli.sh ports registry | tr -d '\r')
    push_registry=localhost:$registry_port
    manifest_registry=registry:5000
    config_dir=./config/test
fi

bridge_marker_manifest="./examples/bridge-marker.yml"

REGISTRY=$push_registry make docker-build
REGISTRY=$push_registry make docker-push
REGISTRY=$manifest_registry make manifests

./cluster/kubectl.sh delete --ignore-not-found -f $bridge_marker_manifest

# Delete daemon sets that were deprecated/renamed
./cluster/kubectl.sh -n kube-system delete --ignore-not-found ds bridge-marker

# Wait until all objects are deleted
until [[ $(./cluster/kubectl.sh get --ignore-not-found -f $bridge_marker_manifest 2>&1 | wc -l) -eq 0 ]]; do sleep 1; done
until [[ $(./cluster/kubectl.sh get --ignore-not-found ds bridge-marker 2>&1 | wc -l) -eq 0 ]]; do sleep 1; done

./cluster/kubectl.sh create -f $bridge_marker_manifest

# Wait for daemon set to be scheduled on all nodes
timeout=300
sample=30
current_time=0
while true; do
  describe_result=$(./cluster/kubectl.sh describe  daemonset bridge-marker -n kube-system)
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
