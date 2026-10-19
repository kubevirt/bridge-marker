# Bridge marker

Bridge marker is a daemon which marks network bridges available on nodes as node resources.

When a bridge named `testBridge` is created by:

```ip link add testBridge type bridge```

the marker will mark the node with the following resources:

```yaml
...
status:
  allocatable:
    bridge.network.kubevirt.io/testBridge: 1k
    ...
  capacity:
    bridge.network.kubevirt.io/testBridge: 1k
    ...
```

Node capacity is published by patching `Node.status.capacity`. The
`bridge-marker-node-restriction` ValidatingAdmissionPolicy limits the
`bridge-marker` service account to:

- the node named in its bound service-account token (`authentication.kubernetes.io/node-name`)
- `status.capacity` keys under `bridge.network.kubevirt.io/`

That account cannot change spec, labels, annotations, or any other status field.

## Kubernetes prerequisite

The node-restriction `ValidatingAdmissionPolicy` requires Kubernetes v1.32 or
later. Although `ValidatingAdmissionPolicy` became generally available in
Kubernetes v1.30, this policy depends on the
`authentication.kubernetes.io/node-name` extra user information provided by
`ServiceAccountTokenPodNodeInfo`, which became generally available in
Kubernetes v1.32.
