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

source ./cluster/kubevirtci.sh
CNAO_VERSIOV=0.35.0
kubevirtci::install

if [[ "$KUBEVIRT_PROVIDER" != external ]]; then
    $(kubevirtci::path)/cluster-up/up.sh
fi

# Deploy Multus
./cluster/kubectl.sh create -f https://github.com/kubevirt/cluster-network-addons-operator/releases/download/${CNAO_VERSIOV}/namespace.yaml
./cluster/kubectl.sh create -f https://github.com/kubevirt/cluster-network-addons-operator/releases/download/${CNAO_VERSIOV}/network-addons-config.crd.yaml
./cluster/kubectl.sh create -f https://github.com/kubevirt/cluster-network-addons-operator/releases/download/${CNAO_VERSIOV}/operator.yaml
./cluster/kubectl.sh create -f ./hack/cna/cna-cr.yaml

# wait for cluster operator
./cluster/kubectl.sh wait networkaddonsconfig cluster --for condition=Available --timeout=800s

echo "Done"
