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
