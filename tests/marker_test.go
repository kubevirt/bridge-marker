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
	"context"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/kubevirt/bridge-marker/tests"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	DefaultNamespace = "default"
)

var _ = Describe("bridge-marker", func() {
	var (
		node string
	)
	Context("when bridge is created at node", func() {
		AfterEach(func() {
			tests.RemoveBridgeFromNode(node, tests.TestBridgeName)
		})

		It("should be reported only when available on node", func() {
			resourceName := tests.GenerateResourceName(tests.TestBridgeName)

			var err error
			node, err = tests.AddBridgeOnSchedulableNode(clientset, tests.TestBridgeName)
			Expect(err).ToNot(HaveOccurred())

			Eventually(func() (int64, error) {
				node, err := clientset.CoreV1().Nodes().Get(context.TODO(), node, v1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())

				capacity, reported := node.Status.Capacity[resourceName]

				if !reported {
					return 0, fmt.Errorf("Node has no capacity entry for %s", resourceName)
				}
				capacityInt, _ := capacity.AsInt64()
				return capacityInt, nil
			}, 180*time.Second, 5*time.Second).Should(Equal(int64(1000)), fmt.Sprintf("should has node with capacity 1000 for the resource %s after adding the bridge to the node", resourceName))

			err = tests.RemoveBridgeFromNode(node, tests.TestBridgeName)
			Expect(err).ToNot(HaveOccurred())

			Eventually(func() corev1.ResourceList {
				node, err := clientset.CoreV1().Nodes().Get(context.TODO(), node, v1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())
				return node.Status.Capacity
			}, 180*time.Second, 5*time.Second).ShouldNot(HaveKey(resourceName), fmt.Sprintf("should no has no capacity at node for resource %s after removing the bridge", resourceName))
		})
	})

	Describe("pod requiring bridge resource", func() {
		AfterEach(func() {
			tests.RemoveBridgeFromNode(node, tests.TestPodBridgeName)
			clientset.CoreV1().Pods(DefaultNamespace).Delete(context.TODO(), tests.TestPodName, v1.DeleteOptions{})
		})
		It("should be started only when bridge is available on node", func() {
			resourceName := tests.GenerateResourceName(tests.TestPodBridgeName)
			requiredResourceCount := "1"
			requiredResources := corev1.ResourceList{
				resourceName: resource.MustParse(requiredResourceCount),
			}

			podReq := tests.PodSpec(tests.TestPodName, requiredResources)
			_, err := clientset.CoreV1().Pods(DefaultNamespace).Create(context.TODO(), podReq, v1.CreateOptions{})
			Expect(err).ToNot(HaveOccurred())

			tests.CheckPodStatus(
				clientset, 60,
				func(pod *corev1.Pod) bool {
					return pod.Status.Phase == "Pending"
				},
			)

			tests.CheckPodStatus(
				clientset, 600,
				func(pod *corev1.Pod) bool {
					Expect(fmt.Sprint(pod.Status.Phase)).To(Equal("Pending"))
					for _, condition := range pod.Status.Conditions {
						if condition.Reason == "Unschedulable" {
							return true
						}
					}
					return false
				},
			)

			node, err := tests.AddBridgeOnSchedulableNode(clientset, tests.TestPodBridgeName)
			tests.CheckPodStatus(
				clientset, 240,
				func(pod *corev1.Pod) bool {
					if pod.Status.Phase == "Running" {
						Expect(pod.Spec.NodeName).To(Equal(node))
						return true
					}
					return false
				},
			)
		})
	})
})
