/*
 * This file is part of the KubeVirt project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Copyright 2019 Red Hat, Inc.
 *
 */

package tests

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	. "github.com/onsi/gomega"

	coreapi "k8s.io/api/core/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

const (
	TestBridgeName    = "br_test"
	TestPodBridgeName = "br_podtest"
	TestPodName       = "bridge-marker-test"
)

type evaluate func(*v1.Pod) bool

func RunOnNode(node string, command string) (string, error) {
	provider, ok := os.LookupEnv("KUBEVIRT_PROVIDER")
	if !ok {
		panic("KUBEVIRT_PROVIDER environment variable must be specified")
	}

	out, err := exec.Command("docker", "exec", provider+"-"+node, "ssh.sh", command).CombinedOutput()
	outString := string(out)
	outLines := strings.Split(outString, "\n")
	// first two lines of output indicate that connection was successful
	outStripped := outLines[2:]
	outStrippedString := strings.Join(outStripped, "\n")

	return outStrippedString, err
}

func GenerateResourceName(bridgeName string) coreapi.ResourceName {
	resourceName := coreapi.ResourceName(fmt.Sprintf("%s/%s", "bridge.network.kubevirt.io", bridgeName))
	return resourceName
}

func getAllSchedulableNodes(clientset *kubernetes.Clientset) (*coreapi.NodeList, error) {
	nodes, err := clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list compute nodes: %v", err)
	}

	return nodes, nil
}

func AddBridgeOnSchedulableNode(clientset *kubernetes.Clientset, bridgename string) (string, error) {
	nodes, err := getAllSchedulableNodes(clientset)
	if err != nil {
		return "", fmt.Errorf("failed getting all schedulable nodes: %w", err)
	}

	if len(nodes.Items) == 0 {
		return "", fmt.Errorf("no schedulable nodes found")
	}
	node := nodes.Items[0].Name

	return node, AddBridgeOnNode(node, bridgename)
}

func AddBridgeOnNode(node, bridgename string) error {
	out, err := RunOnNode(node, fmt.Sprintf("sudo ip link add %s type bridge", bridgename))
	if err != nil {
		return fmt.Errorf("failed adding bridge at node node cmd: %s, err: %w", out, err)
	}

	out, err = RunOnNode(node, fmt.Sprintf("sudo ip link set %s up", bridgename))
	if err != nil {
		return fmt.Errorf("failed to set bridge up at node cmd: %s, err: %w", out, err)
	}

	return nil
}

func RemoveBridgeFromNode(node, bridgename string) error {
	out, err := RunOnNode(node, fmt.Sprintf("sudo ip link del %s", bridgename))
	if err != nil {
		return fmt.Errorf("%v: %s", err, out)
	}

	return nil
}

func PodSpec(name string, resourceRequirements v1.ResourceList) *v1.Pod {
	req := &v1.Pod{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Pod",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: name,
		},
		Spec: v1.PodSpec{
			Containers: []v1.Container{
				{
					Name:  name,
					Image: "centos",
					Resources: v1.ResourceRequirements{
						Limits:   resourceRequirements,
						Requests: resourceRequirements,
					},
					Command: []string{"/bin/bash", "-c", "sleep INF"},
				},
			},
		},
	}
	return req
}

func CheckPodStatus(clientset *kubernetes.Clientset, timeout time.Duration, evaluate evaluate) {
	Eventually(func() bool {
		pod, err := clientset.CoreV1().Pods("default").Get(context.TODO(), TestPodName, metav1.GetOptions{})
		Expect(err).ToNot(HaveOccurred())
		return evaluate(pod)
	}, timeout*time.Second, 5*time.Second).Should(Equal(true))
}
