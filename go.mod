module github.com/kubevirt/bridge-marker

go 1.13

require (
	github.com/golang/glog v1.1.0
	github.com/imdario/mergo v0.3.7 // indirect
	github.com/onsi/ginkgo v1.14.1
	github.com/onsi/gomega v1.10.2
	github.com/vishvananda/netlink v1.1.0
	k8s.io/api v0.19.1
	k8s.io/apimachinery v0.19.1
	k8s.io/client-go v0.19.1
	kubevirt.io/qe-tools v0.1.6
)

replace (
	golang.org/x/crypto => golang.org/x/crypto v0.14.0
	golang.org/x/net => golang.org/x/net v0.17.0
	golang.org/x/oauth2 => golang.org/x/oauth2 v0.13.0
	golang.org/x/sys => golang.org/x/sys v0.13.0
	golang.org/x/term => golang.org/x/term v0.13.0
	golang.org/x/text => golang.org/x/text v0.13.0
	golang.org/x/time => golang.org/x/time v0.3.0
	golang.org/x/xerrors => golang.org/x/xerrors v0.0.0-20231012003039-104605ab7028
)
