# localca-injector-package

This package provides localca-injector functionality. It does inject a local CA provided from your host into the cluster
and configures your containerd to use trust that CA. It also provides a ClusterIssuer for you to use this CA.

It uses code from [this blog](http://hypernephelist.com/2021/03/23/kubernetes-containerd-certificate.html)

## Components

* localca-injector

## Configuration

The following configuration values can be set to customize the localca-injector installation.

### Global

| Value | Required/Optional | Default     | Description |
|-------|-------------------|-------------|-------------|
| `namespace` | Optional | localca-injector | The namespace in which to deploy localca-injector |
| `create_namespace` | Optional | True | Should the namespace be created? |
| `local_ca.crt` | Required | <EMPTY> | The local Certificate Authority certificate (in pem format) |
| `local_ca.key` | Required | <EMPTY> | The local Certificate Authority Private Key (in pem format) |
| `cluster_issuer.name` | Optional | local-ca | The name of the generated cluster issuer |


## Usage Example

This walkthrough guides you through using localca-injector.

First, you need to have cert-manager installed. On a TCE cluster, you can install it with this command:
```
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version 1.5.3
```

Configure your CA in the values file. (In this example we use the one provided in minikube.yaml):
```
ytt -f src/bundle/config --data-values-file src/example-values/minikube.yaml | kapp deploy -a injector -n default -y -f -
```

When configured, there's a clusterIssuer named `wildcard` that should provide certs for you.

__NOTE__: `develop` version of the package needs to comply with semver, hence the package will be versioned as `0.0.0+develop`

## Test in minikube

Start minikube:
```
minikube start
```

Install kapp-controller 0.20+
```
kubectl apply -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
```

Install the Package Metadata:
```
kubectl apply -f target/k8s
```

Install the Required RBAC for the package install (create the control NS):
```
kubectl apply -f target/test/packageinstall-ns-rbac.yaml
```

Create the configuration file for your cluster:
```
kubectl create secret generic localca-injector -n localca-injector-package --from-file=values.yaml=src/examples-values/minikube.yaml -o yaml --dry-run=client | kubectl apply -f -
```

Create the package:
```
kubectl apply -f target/test/packageinstall.yaml
```

Verify the installation:
```
watch kubectl get packageinstall -A
```

If there's an issue, you can verify the problem with:

```
kubectl get packageinstall localca-injector -n localca-injector-package -o yaml
```

## Develop checklist

1. Update your [config.json](./config.json) with the package info
2. Add [overlays](./src/bundle/config/overlays/) and [values](./src/bundle/config/values.yaml)
3. Test your bundle: `ytt --data-values-file src/example-values/minikube.yaml  -f target/bundle/config` providing a sample values file from [example-values](./src/examples-values/)
4. Build your bundle `./hack/build.sh`
5. Add it to the [failk8s-repo](https://github.com/failk8s-packages/failk8s-repo) and publish the new repo and test the package from there, or [test with local files](./target/test)

**NOTE**: `develop` versions will not be image locked and will have a version of 0.0.0+develop to comply with semver.