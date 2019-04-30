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
	"fmt"
	"os"
	"os/exec"
	"strings"

	coreapi "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

const (
	TestBridgeName = "br_test"
)

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

func GenerateResourceName() coreapi.ResourceName {
	resourceName := coreapi.ResourceName(fmt.Sprintf("%s/%s", "bridge.network.kubevirt.io", TestBridgeName))

	return resourceName
}

func getAllSchedulableNodes(clientset *kubernetes.Clientset) (*coreapi.NodeList, error) {
	nodes, err := clientset.CoreV1().Nodes().List(metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list compute nodes: %v", err)
	}

	return nodes, nil
}

func AddBridgeOnSchedulableNode(clientset *kubernetes.Clientset, bridgename string) (string, error) {
	nodes, err := getAllSchedulableNodes(clientset)
	if err != nil {
		return "", err
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
		return fmt.Errorf("%v: %s", err, out)
	}

	out, err = RunOnNode(node, fmt.Sprintf("sudo ip link set %s up", bridgename))
	if err != nil {
		return fmt.Errorf("%v: %s", err, out)
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
