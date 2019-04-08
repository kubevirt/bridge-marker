// Copyright 2019 Red Hat, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package tests_test

import (
	"crypto/rand"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/kubevirt/bridge-marker/tests"
	core_api "k8s.io/api/core/v1"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

func getAllSchedulableNodes(clientset *kubernetes.Clientset) *core_api.NodeList {
	nodes, err := clientset.CoreV1().Nodes().List(v1.ListOptions{})
	Expect(err).ToNot(HaveOccurred(), "Should list compute nodes")
	return nodes
}

var _ = Describe("bridge-marker", func() {
	Describe("bridge resource reporting", func() {
		It("should be reported only when available on node", func() {

			brId := make([]byte, 6)
			rand.Read(brId)
			uniqueBridgeName := fmt.Sprintf("br_%x", brId)
			resourceName := core_api.ResourceName(fmt.Sprintf("%s/%s", "bridge.network.kubevirt.io", uniqueBridgeName))

			nodes := getAllSchedulableNodes(clientset)
			Expect(nodes.Items).ToNot(BeEmpty(), "No schedulable nodes found")
			node := nodes.Items[0].Name

			out, err := tests.RunOnNode(node, fmt.Sprintf("sudo ip link add %s type bridge", uniqueBridgeName))
			if err != nil {
				panic(fmt.Errorf("%v: %s", err, out))
			}

			Eventually(func() bool {
				node, err := clientset.CoreV1().Nodes().Get(node, v1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())

				capacity, reported := node.Status.Capacity[resourceName]

				if !reported {
					return false
				}
				capacityInt, _ := capacity.AsInt64()
				if capacityInt != int64(1000) {
					return false
				}
				return true
			}, 20*time.Second, 5*time.Second).Should(Equal(true))

			out, err = tests.RunOnNode(node, fmt.Sprintf("sudo ip link del %s", uniqueBridgeName))
			if err != nil {
				panic(fmt.Errorf("%v: %s", err, out))
			}

			Eventually(func() bool {
				node, err := clientset.CoreV1().Nodes().Get(node, v1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())
				_, reported := node.Status.Capacity["bridge.network.kubevirt.io/br-test"]
				return reported

			}, 20*time.Second, 5*time.Second).Should(Equal(false))
		})
	})
})
